--!nonstrict
-- Cached GUI reconstruction, not framebuffer capture. Unknown pixels stay unknown.
local GuiBackdrop = {}
GuiBackdrop.__index = GuiBackdrop
local function read(o, k, default)
    local ok, value = pcall(function() return o[k] end)
    if ok and value ~= nil then return value end
    return default
end
local function children(o, stats)
    local ok, result = pcall(o.GetChildren, o)
    if not ok and stats then stats.ReadFailures+=1 end
    return ok and result or {}
end
local function internal(o)
    local ok,value=pcall(o.GetAttribute,o,'ShardGlassInternal')
    return ok and value==true
end
local function connect(list, event, fn)
    if event then table.insert(list, event:Connect(fn)) end
end
local function sequence(seq, t, color)
    local keys = seq and seq.Keypoints
    if not keys or #keys == 0 then return color and Color3.new(1, 1, 1) or 0 end
    local a, b = keys[1], keys[#keys]
    for i = 2, #keys do if t <= keys[i].Time then a, b = keys[i-1], keys[i]; break end end
    local f = math.clamp((t-a.Time) / math.max(b.Time-a.Time, 1e-9), 0, 1)
    if color then return Color3.new(a.Value.R+(b.Value.R-a.Value.R)*f,
        a.Value.G+(b.Value.G-a.Value.G)*f, a.Value.B+(b.Value.B-a.Value.B)*f) end
    return a.Value+(b.Value-a.Value)*f
end
local function layer(o)
    while o do
        if o:IsA('CoreGui') then return 1 end
        if o:IsA('PlayerGui') then return 0 end
        o=o.Parent
    end
    return 2 -- nonstandard executor container; ordering needs engine verification
end
local function inside(r, x, y)
    return x >= r.X and y >= r.Y and x < r.X+r.W and y < r.Y+r.H
end
function GuiBackdrop.ValidateOptions(options)
    options=options or {}
    for name,range in pairs({BackdropResolution={16,192},BackdropMaxLayers={1,2048}}) do
        local value=options[name]
        assert(value==nil or (type(value)=='number' and value==value and value%1==0
            and value>=range[1] and value<=range[2]),name..' must be an integer in '..range[1]..'..'..range[2])
    end
    assert(options.BackdropRoots==nil or type(options.BackdropRoots)=='table','BackdropRoots must be a table')
end
function GuiBackdrop.new(root, options)
    options = options or {}
    GuiBackdrop.ValidateOptions(options)
    local self = setmetatable({Root=root, Roots={}, Connections={}, Watches={}, Dirty=true,
        Revision=0, List={}, Cache={}, Size=math.clamp(options.BackdropResolution or 96, 16, 192),
        MaxLayers=math.clamp(options.BackdropMaxLayers or 256, 1, 2048),
        Stats={ScannedObjects=0, UnsupportedObjects=0, DeniedRoots=0, ReadFailures=0}}, GuiBackdrop)
    local function add(object)
        if not object or table.find(self.Roots, object) then return end
        table.insert(self.Roots, object)
        connect(self.Connections, read(object,'DescendantAdded'), function() self.Dirty=true end)
        connect(self.Connections, read(object,'DescendantRemoving'), function() self.Dirty=true end)
    end
    if options.BackdropRoots then
        for _, object in ipairs(options.BackdropRoots) do add(object) end
    else
        for _, service in ipairs({'Players','CoreGui'}) do
            local ok, object = pcall(function()
                local value=game:GetService(service)
                if service=='Players' then
                    return value.LocalPlayer and value.LocalPlayer:FindFirstChildOfClass('PlayerGui')
                end
                return value
            end)
            if ok and object then add(object) else self.Stats.DeniedRoots+=1 end
        end
    end
    -- Includes executor-specific GUI containers without depending on gethui().
    add(root.Parent or root)
    return self
end
function GuiBackdrop:Rebuild()
    for _, c in ipairs(self.Watches) do c:Disconnect() end
    table.clear(self.Watches)
    local screens, seen, serial = {}, {}, 0
    self.Stats.ScannedObjects, self.Stats.UnsupportedObjects, self.Stats.ReadFailures = 0, 0, 0
    local function walk(o, screen, path, hidden, clips, unsupported, scale)
        if seen[o] or internal(o) then return end
        seen[o]=true
        self.Stats.ScannedObjects+=1
        connect(self.Watches, read(o,'Changed'), function(property)
            -- Glass decoration mutates these itself, but has no reconstructed paint.
            if o:GetAttribute('LiquidGlass') and (property=='BackgroundTransparency' or property=='BorderSizePixel') then return end
            self.Dirty=true
        end)
        connect(self.Watches, read(o,'AttributeChanged'), function(name)
            if name~='LiquidGlassMode' then self.Dirty=true end
        end)
        if o:IsA('ScreenGui') then
            screen={Object=o, Order=read(o,'DisplayOrder',0), Serial=#screens+1, Entries={},
                Layer=layer(o), Enabled=o.Enabled, Global=o.ZIndexBehavior==Enum.ZIndexBehavior.Global}
            table.insert(screens,screen)
            path={}; hidden=not o.Enabled; clips={}; unsupported=false; scale=1
        end
        local nextPath=path
        if screen and o:IsA('GuiObject') then
            serial+=1
            nextPath=table.clone(path); table.insert(nextPath,{Z=o.ZIndex, Serial=serial})
            hidden=hidden or not o.Visible or (o:IsA('CanvasGroup') and read(o,'GroupTransparency',0)>=1)
            local p,z=o.AbsolutePosition,o.AbsoluteSize
            local rect={X=p.X,Y=p.Y,W=z.X,H=z.Y}
            local modifier=o:FindFirstChildOfClass('UIScale')
            scale*=modifier and modifier.Scale or 1
            unsupported=unsupported or o.AbsoluteRotation~=0 or o:IsA('CanvasGroup')
            local entry={Object=o,Rect=rect,Path=nextPath,Z=o.ZIndex,Serial=serial,Hidden=hidden,
                Clips=clips,Color=o.BackgroundColor3,Alpha=1-o.BackgroundTransparency,
                Glass=o:GetAttribute('LiquidGlass')==true,Unknown=unsupported,
                Border=read(o,'BorderSizePixel',0),BorderColor=read(o,'BorderColor3'),Radius=0,Extent=0}
            local ok,attributes=pcall(o.GetAttributes,o)
            entry.Attributes=ok and attributes or {}
            local angle=math.rad(o.AbsoluteRotation)
            local bw=math.abs(math.cos(angle))*z.X+math.abs(math.sin(angle))*z.Y
            local bh=math.abs(math.sin(angle))*z.X+math.abs(math.cos(angle))*z.Y
            entry.Mask={X=p.X+(z.X-bw)/2,Y=p.Y+(z.Y-bh)/2,W=bw,H=bh}
            local corner=o:FindFirstChildOfClass('UICorner')
            if corner and not o:IsA('ScrollingFrame') then
                entry.Radius=math.clamp(math.min(z.X,z.Y)*corner.CornerRadius.Scale+corner.CornerRadius.Offset*scale,0,math.min(z.X,z.Y)/2)
                local a=read(corner,'TopLeftRadius')
                if a and (a~=read(corner,'TopRightRadius') or a~=read(corner,'BottomLeftRadius') or a~=read(corner,'BottomRightRadius')) then entry.Unknown=true end
            end
            local gradient=o:FindFirstChildOfClass('UIGradient')
            if gradient and read(gradient,'Enabled',true) then
                entry.Gradient={Color=gradient.Color,Transparency=gradient.Transparency,
                    Offset=gradient.Offset,Rotation=gradient.Rotation}
            end
            local class=o.ClassName
            local content=read(o,'ImageContent')
            local contentType=content and read(content,'SourceType')
            local hasContent=content~=nil and (contentType==nil or read(contentType,'Value',1)~=0)
            entry.Unknown=entry.Unknown or (class~='Frame' and class~='ScrollingFrame'
                and class~='TextLabel' and class~='TextButton' and class~='TextBox'
                and class~='ImageLabel' and class~='ImageButton')
            -- Native glyphs and asset textures cannot be recovered from their color properties.
            entry.Unknown=entry.Unknown or (read(o,'Text','')~='' and read(o,'TextTransparency',0)<1)
                or ((read(o,'Image','')~='' or hasContent) and read(o,'ImageTransparency',0)<1)
                or (read(o,'AutoButtonColor',false)==true)
            for _, child in ipairs(children(o, self.Stats)) do
                if not internal(child) and (child:IsA('UIStroke') or child:IsA('UIShadow')) then
                    entry.Unknown=true
                    if child:IsA('UIStroke') then entry.Extent=math.max(entry.Extent,read(child,'Thickness',1)*scale+2)
                    else
                        -- Shadow APIs differ between client versions. If its footprint is unknown,
                        -- invalidate this snapshot rather than assume it stays inside its parent.
                        entry.Unbounded=true
                    end
                end
            end
            if entry.Unknown and not hidden then self.Stats.UnsupportedObjects+=1 end
            table.insert(screen.Entries,entry)
            if o.ClipsDescendants or o:IsA('ScrollingFrame') then
                clips=table.clone(clips); table.insert(clips,rect)
                if o.AbsoluteRotation~=0 then unsupported=true end
            end
            if o:IsA('ScrollingFrame') and read(o,'ScrollBarThickness',0)>0 then entry.Unknown=true end
        end
        for _, child in ipairs(children(o, self.Stats)) do walk(child,screen,nextPath,hidden,clips,unsupported,scale) end
    end
    -- Visit containing roots first; duplicate root references must not swallow their ScreenGui context.
    for _, root in ipairs(self.Roots) do
        local contained=false
        for _,other in ipairs(self.Roots) do
            if root~=other and root:IsDescendantOf(other) then contained=true; break end
        end
        if not contained then walk(root,nil,{},false,{},false,1) end
    end
    table.sort(screens,function(a,b)
        if a.Layer~=b.Layer then return a.Layer<b.Layer end
        if a.Order~=b.Order then return a.Order<b.Order end
        return a.Serial<b.Serial
    end)
    self.List={}
    for _, screen in ipairs(screens) do
        table.sort(screen.Entries,function(a,b)
            if screen.Global then return a.Z==b.Z and a.Serial<b.Serial or a.Z<b.Z end
            for i=1,math.min(#a.Path,#b.Path) do
                local x,y=a.Path[i],b.Path[i]
                if x.Serial~=y.Serial then return x.Z==y.Z and x.Serial<y.Serial or x.Z<y.Z end
            end
            return #a.Path<#b.Path
        end)
        for _, entry in ipairs(screen.Entries) do
            entry.Screen=screen.Object
            table.insert(self.List,entry)
        end
    end
    table.clear(self.Cache)
    self.Dirty=false; self.Revision+=1
end
function GuiBackdrop:Build(request)
    if self.Dirty then self:Rebuild() end
    local sources={}
    self.Stats.KnownPixels,self.Stats.TotalPixels,self.Stats.LayerBudgetExceeded=0,0,false
    for _, surface in ipairs(request.Surfaces) do
        local object,rect=surface.Record.Object,surface.Rect
        local cached=self.Cache[object]
        if cached and cached.X==rect.X and cached.Y==rect.Y and cached.W==rect.Width and cached.H==rect.Height then
            sources[object]=cached.Source
            self.Stats.KnownPixels+=cached.Known
            self.Stats.TotalPixels+=self.Size*self.Size
            continue
        end
        local knownCount=0
        local n=self.Size
        local source={Width=n,Height=n,Pixels=buffer.create(n*n*4),Coverage=buffer.create(n*n),
            Origin=Vector2.new(rect.X-80,rect.Y-80),Size=Vector2.new(rect.Width+160,rect.Height+160),
            ExcludesGlass=true,KnownGuiOnly=true,Opaque=false}
        local layers,found={},false
        for _, entry in ipairs(self.List) do
            if entry.Object==object then found=true; break end
            local r=entry.Unknown and entry.Mask or entry.Rect
            if entry.Unbounded and not entry.Hidden then layers={}; found=false; break end
            if not entry.Hidden and not entry.Glass and r.W>0 and r.H>0
                and r.X-entry.Extent<source.Origin.X+source.Size.X and r.X+r.W+entry.Extent>source.Origin.X
                and r.Y-entry.Extent<source.Origin.Y+source.Size.Y and r.Y+r.H+entry.Extent>source.Origin.Y then
                table.insert(layers,entry)
            end
        end
        if not found then continue end
        if #layers>self.MaxLayers then self.Stats.LayerBudgetExceeded=true; continue end
        -- Coarse spatial bins preserve draw order but avoid testing every GUI
        -- against every sample. A grid of small controls should scale with overlap.
        local bins,cell={},8
        local wide=math.ceil(n/cell)
        for _,e in ipairs(layers) do
            local r=e.Unknown and e.Mask or e.Rect
            local pad=e.Extent+e.Border+math.max(source.Size.X,source.Size.Y)/n
            local x0=math.clamp(math.floor((r.X-pad-source.Origin.X)/source.Size.X*n/cell),0,wide-1)
            local y0=math.clamp(math.floor((r.Y-pad-source.Origin.Y)/source.Size.Y*n/cell),0,wide-1)
            local x1=math.clamp(math.floor((r.X+r.W+pad-source.Origin.X)/source.Size.X*n/cell),0,wide-1)
            local y1=math.clamp(math.floor((r.Y+r.H+pad-source.Origin.Y)/source.Size.Y*n/cell),0,wide-1)
            for by=y0,y1 do for bx=x0,x1 do
                local key=by*wide+bx
                if not bins[key] then bins[key]={} end
                table.insert(bins[key],e)
            end end
        end
        for y=0,n-1 do for x=0,n-1 do
            local sx=source.Origin.X+(x+.5)/n*source.Size.X
            local sy=source.Origin.Y+(y+.5)/n*source.Size.Y
            local red,green,blue,known=0,0,0,false
            for _, e in ipairs(bins[math.floor(y/cell)*wide+math.floor(x/cell)] or {}) do
                local r=e.Rect
                local mask=e.Mask
                local ex,ey=source.Size.X/n/2+e.Extent,source.Size.Y/n/2+e.Extent
                if e.Unknown then
                    if sx>=mask.X-ex and sy>=mask.Y-ey and sx<mask.X+mask.W+ex and sy<mask.Y+mask.H+ey then known=false end
                    continue
                end
                -- Native borders can extend outside the fill, depending on BorderMode.
                if e.Border>0 and sx>=r.X-e.Border-ex and sy>=r.Y-e.Border-ey
                    and sx<r.X+r.W+e.Border+ex and sy<r.Y+r.H+e.Border+ey
                    and (not inside(r,sx,sy) or math.min(sx-r.X,sy-r.Y,r.X+r.W-sx,r.Y+r.H-sy)<e.Border+math.max(ex,ey)) then
                    known=false; continue
                end
                if not inside(r,sx,sy) then continue end
                local clipped=false
                for _, clip in ipairs(e.Clips) do if not inside(clip,sx,sy) then clipped=true; break end end
                if clipped then continue end
                local rad=e.Radius
                local dx=math.max(math.abs(sx-r.X-r.W/2)-r.W/2+rad,0)
                local dy=math.max(math.abs(sy-r.Y-r.H/2)-r.H/2+rad,0)
                if dx*dx+dy*dy>rad*rad then continue end
                if e.Unknown then known=false; continue end
                local c,a=e.Color,e.Alpha
                local grad=e.Gradient
                if grad then
                    local angle=math.rad(grad.Rotation)
                    local vx,vy=math.cos(angle),math.sin(angle)
                    local length=math.min(r.W/math.max(math.abs(vx),1e-9),r.H/math.max(math.abs(vy),1e-9))
                    local t=math.clamp(.5+((sx-r.X-r.W/2-grad.Offset.X*r.W)*vx
                        +(sy-r.Y-r.H/2-grad.Offset.Y*r.H)*vy)/math.max(length,1),0,1)
                    local g=sequence(grad.Color,t,true)
                    c=Color3.new(c.R*g.R,c.G*g.G,c.B*g.B)
                    a*=1-sequence(grad.Transparency,t,false)
                end
                -- Edge bands are conservative: native border modes and antialiasing vary.
                local edge=math.min(sx-r.X,sy-r.Y,r.X+r.W-sx,r.Y+r.H-sy)
                if e.Border>0 and edge<e.Border+1 then known=false; continue end
                red=red*(1-a)+c.R*255*a; green=green*(1-a)+c.G*255*a; blue=blue*(1-a)+c.B*255*a
                if a>=1 then known=true end
            end
            local i=y*n+x
            if known then
                buffer.writeu8(source.Coverage,i,255)
                buffer.writeu8(source.Pixels,i*4,math.clamp(math.floor(red+.5),0,255))
                buffer.writeu8(source.Pixels,i*4+1,math.clamp(math.floor(green+.5),0,255))
                buffer.writeu8(source.Pixels,i*4+2,math.clamp(math.floor(blue+.5),0,255))
                buffer.writeu8(source.Pixels,i*4+3,255)
                self.Stats.KnownPixels+=1
                knownCount+=1
            end
            self.Stats.TotalPixels+=1
        end end
        sources[object]=source
        self.Cache[object]={X=rect.X,Y=rect.Y,W=rect.Width,H=rect.Height,Source=source,Known=knownCount}
    end
    return {Sources=sources}
end
function GuiBackdrop:GetStatus()
    local stats=table.clone(self.Stats)
    stats.Revision=self.Revision
    stats.Mode='GuiReconstruction'
    return stats
end
function GuiBackdrop:Destroy()
    for _, c in ipairs(self.Connections) do c:Disconnect() end
    for _, c in ipairs(self.Watches) do c:Disconnect() end
    table.clear(self.Connections); table.clear(self.Watches); table.clear(self.List); table.clear(self.Roots); table.clear(self.Cache)
end
return GuiBackdrop
