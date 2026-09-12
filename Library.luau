-- BEGIN GENERATED LIQUID GLASS
local LiquidGlass = (function()
--!nonstrict
-- Canonical source. tools/sync_liquid_glass.py embeds this in Library.luau.
-- No screen capture API is assumed. See docs/LiquidGlass.md for the source contract.
-- BEGIN GENERATED GUI BACKDROP
local GuiBackdrop = (function()
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

end)()
-- END GENERATED GUI BACKDROP
local LiquidGlass = {GuiBackdrop = GuiBackdrop}
local INTERNAL = 'ShardGlassInternal'
local clamp = math.clamp

local function finite(n)
    return type(n) == 'number' and n == n and math.abs(n) < math.huge
end

local function numberAttribute(object, name, default, minimum, maximum)
    local value = object:GetAttribute(name)
    return finite(value) and clamp(value, minimum, maximum) or default
end

-- Pure optical kernel; buffers use unpremultiplied RGBA, with alpha 255 required
-- for input. Source coordinates are in the owning ScreenGui's AbsolutePosition space.
function LiquidGlass.ValidateSource(source)
    if type(source) ~= 'table' then return false end
    local w, h = source.Width, source.Height
    return finite(w) and finite(h) and w >= 1 and h >= 1
        and w <= 4096 and h <= 4096 and w % 1 == 0 and h % 1 == 0
        and typeof(source.Pixels) == 'buffer' and buffer.len(source.Pixels) == w * h * 4
        and typeof(source.Origin) == 'Vector2' and typeof(source.Size) == 'Vector2'
        and finite(source.Origin.X) and finite(source.Origin.Y)
        and finite(source.Size.X) and finite(source.Size.Y)
        and source.Size.X > 0 and source.Size.Y > 0
        and source.ExcludesGlass == true and (source.Opaque == true
            or (source.KnownGuiOnly == true and typeof(source.Coverage) == 'buffer'
                and buffer.len(source.Coverage) == w * h))
end

local function sample(source, x, y, channel)
    local px = clamp((x - source.Origin.X) / source.Size.X * source.Width - 0.5, 0, source.Width - 1)
    local py = clamp((y - source.Origin.Y) / source.Size.Y * source.Height - 0.5, 0, source.Height - 1)
    local ix, iy = math.floor(px), math.floor(py)
    local jx, jy = math.min(ix + 1, source.Width - 1), math.min(iy + 1, source.Height - 1)
    local fx, fy = px - ix, py - iy
    local a = buffer.readu8(source.Pixels, (iy * source.Width + ix) * 4 + channel)
    local b = buffer.readu8(source.Pixels, (iy * source.Width + jx) * 4 + channel)
    local c = buffer.readu8(source.Pixels, (jy * source.Width + ix) * 4 + channel)
    local d = buffer.readu8(source.Pixels, (jy * source.Width + jx) * 4 + channel)
    return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy
end

-- A partially known background must cover all four bilinear taps. Clamping an
-- unknown edge would fabricate content, so reject out-of-range samples as well.
local function knownAt(source, x, y)
    if source.Opaque then return true end
    local px = (x-source.Origin.X)/source.Size.X*source.Width-.5
    local py = (y-source.Origin.Y)/source.Size.Y*source.Height-.5
    local ix, iy = math.floor(px), math.floor(py)
    if ix<0 or iy<0 or ix+1>=source.Width or iy+1>=source.Height then return false end
    for dy=0,1 do for dx=0,1 do
        if buffer.readu8(source.Coverage,(iy+dy)*source.Width+ix+dx)~=255 then return false end
    end end
    return true
end

-- Rounded rectangle signed distance and outward unit normal, in screen pixels.
function LiquidGlass.Distance(x, y, width, height, radius)
    radius = clamp(radius, 0, math.min(width, height) / 2)
    local px, py = x - width / 2, y - height / 2
    local qx, qy = math.abs(px) - width / 2 + radius, math.abs(py) - height / 2 + radius
    local ox, oy = math.max(qx, 0), math.max(qy, 0)
    local length = math.sqrt(ox * ox + oy * oy)
    local nx, ny
    if length > 0 then nx, ny = ox / length, oy / length
    elseif qx > qy then nx, ny = 1, 0
    else nx, ny = 0, 1 end
    return length + math.min(math.max(qx, qy), 0) - radius,
        nx * (px < 0 and -1 or 1), ny * (py < 0 and -1 or 1)
end

function LiquidGlass.Overlaps(a, b)
    return a.X < b.X + b.Width and b.X < a.X + a.Width
        and a.Y < b.Y + b.Height and b.Y < a.Y + a.Height
end

-- Writes one tile, leaving its transparent one-pixel gutter untouched.
-- This is a rounded-lens approximation, not Apple's proprietary shader.
function LiquidGlass.RenderTile(output, stride, tileX, tileY, tileSize, source, rect, style)
    local pixels = tileSize - 2
    local aa = math.max(rect.Width, rect.Height) / pixels
    for y = 0, pixels - 1 do
        for x = 0, pixels - 1 do
            local lx, ly = (x + 0.5) / pixels * rect.Width, (y + 0.5) / pixels * rect.Height
            local distance, nx, ny = LiquidGlass.Distance(lx, ly, rect.Width, rect.Height, style.Radius)
            local coverage = clamp(0.5 - distance / aa, 0, 1) * style.Opacity
            local offset = ((tileY + y + 1) * stride + tileX + x + 1) * 4
            if coverage > 0 then
                local edge = clamp(1 + distance / style.Bezel, 0, 1)
                local bend = style.Refraction * edge * edge
                local sx, sy = rect.X + lx - nx * bend, rect.Y + ly - ny * bend
                local b = style.Blur
                if not knownAt(source, rect.X+lx, rect.Y+ly) or not knownAt(source,sx,sy)
                    or (b>0 and (not knownAt(source,sx-b,sy) or not knownAt(source,sx+b,sy)
                        or not knownAt(source,sx,sy-b) or not knownAt(source,sx,sy+b))) then continue end
                local light = math.max(0, -nx * 0.6 - ny * 0.8) * edge * edge * 30
                for channel = 0, 2 do
                    local value = sample(source, sx, sy, channel)
                    if style.Blur > 0 then
                        local b = style.Blur
                        value = (value * 4 + sample(source, sx - b, sy, channel)
                            + sample(source, sx + b, sy, channel) + sample(source, sx, sy - b, channel)
                            + sample(source, sx, sy + b, channel)) / 8
                    end
                    local tint = channel == 0 and style.Tint.R or channel == 1 and style.Tint.G or style.Tint.B
                    value = value * (1 - style.TintStrength) + tint * 255 * style.TintStrength + light
                    buffer.writeu8(output, offset + channel, math.floor(clamp(value, 0, 255) + 0.5))
                end
                buffer.writeu8(output, offset + 3, math.floor(coverage * 255 + 0.5))
            end
        end
    end
end

local function create(class, properties, parent)
    local object = Instance.new(class)
    object.Archivable = false -- cloned controls must not copy a live atlas or owned modifiers
    object:SetAttribute(INTERNAL, true)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end

local Manager = {}
Manager.__index = Manager

function LiquidGlass.newManager(root, options)
    assert(root:IsA('ScreenGui'), 'LiquidGlass requires a ScreenGui')
    options = options or {}
    local tile = options.TileSize or 128
    local count = options.MaxSurfaces or 4
    local fps = options.UpdateHz or 20
    assert(finite(tile) and tile % 1 == 0 and tile >= 16 and tile <= 256, 'TileSize must be an integer in 16..256')
    assert(finite(count) and count % 1 == 0 and count >= 1 and count <= 16, 'MaxSurfaces must be an integer in 1..16')
    assert(finite(fps) and fps >= 1 and fps <= 60, 'UpdateHz must be in 1..60')
    assert(tile * tile * count <= 262144, 'LiquidGlass pixel budget exceeded')
    if options.AutoBackdrop == true then GuiBackdrop.ValidateOptions(options) end
    local self = setmetatable({Root = root, Records = {}, ByObject = {}, Connections = {},
        TileSize = tile, MaxSurfaces = count, Interval = 1 / fps, Elapsed = 0,
        Status = 'TranslucentFallback', LastError = nil, Destroyed = false,
        ReducedTransparency = options.ReducedTransparency == true,
        ReducedMotion = options.ReducedMotion == true, HighContrast = options.HighContrast == true,
        Serial = 0, Stats = {RenderedSurfaces = 0, OverlaySurfaces = 0, UpdateMilliseconds = 0}}, Manager)
    self.Columns = math.ceil(math.sqrt(count))
    self.AtlasSize = self.Columns * tile
    self.Connections[1] = game:GetService('RunService').Heartbeat:Connect(function(dt)
        self.Elapsed += dt
        if self.Elapsed < self.Interval or self.Destroyed then return end
        self.Elapsed = 0
        local start = os.clock()
        local ok, message = pcall(self.Step, self)
        if not ok then
            self.LastError = tostring(message)
            self.Status = 'RendererError'
            self.Provider = nil -- fail closed; never keep an old captured frame on screen
            if self.Backdrop then self.Backdrop:Destroy(); self.Backdrop = nil end
            self:HideImages()
        end
        self.Stats.UpdateMilliseconds = (os.clock() - start) * 1000
    end)
    self.Connections[2] = root.Destroying:Connect(function() self:Destroy() end)
    if options.AutoBackdrop == true then self:EnableAutoBackdrop(options) end
    return self
end

function Manager:HideImages()
    for _, record in ipairs(self.Records) do
        if record.Image then record.Image.Visible = false end
    end
end

function Manager:EnableAutoBackdrop(options)
    GuiBackdrop.ValidateOptions(options)
    self:SetSourceProvider(nil)
    self.Backdrop = GuiBackdrop.new(self.Root, options)
    self.Provider = function(request) return self.Backdrop:Build(request) end
    self.Status = 'WaitingForSource'
end

function Manager:SetSourceProvider(provider)
    assert(not self.Destroyed, 'LiquidGlass manager was destroyed')
    assert(provider == nil or type(provider) == 'function', 'Source provider must be a function or nil')
    if self.Backdrop then self.Backdrop:Destroy(); self.Backdrop = nil end
    self.Provider = provider
    self.LastError = nil
    self.FailedAllocation = false -- explicit retry, never allocate repeatedly on a failed client
    self.Status = provider and 'WaitingForSource' or 'TranslucentFallback'
    self:HideImages()
    self.Stats.RenderedSurfaces = 0
    if not provider and self.Atlas then
        for _, record in ipairs(self.Records) do
            if record.Image then record.Image:Destroy(); record.Image = nil end
        end
        self.Atlas:Destroy()
        self.Atlas, self.Content, self.Pixels = nil, nil, nil
    end
end

function Manager:GetStatus()
    return {Mode = self.Status, LastError = self.LastError,
        ScreenCaptureSupported = false, SourceRequired = self.Backdrop == nil,
        Backdrop = self.Backdrop and self.Backdrop:GetStatus() or nil,
        RenderedSurfaces = self.Stats.RenderedSurfaces, OverlaySurfaces = self.Stats.OverlaySurfaces,
        UpdateMilliseconds = self.Stats.UpdateMilliseconds,
        AtlasBytes = self.Pixels and buffer.len(self.Pixels) or 0}
end

function Manager:Attach(object)
    assert(not self.Destroyed, 'LiquidGlass manager was destroyed')
    assert(object:IsA('GuiObject'), 'LiquidGlass requires a GuiObject')
    if self.ByObject[object] then return object end
    self.Serial += 1
    local record = {Object = object, Serial = self.Serial, Decorations = {}, Connections = {},
        OriginalTransparency = object.BackgroundTransparency, OriginalBorder = object.BorderSizePixel}
    self.ByObject[object] = record
    table.insert(self.Records, record)
    object:SetAttribute('LiquidGlass', true)
    record.Connections[1] = object.Destroying:Connect(function() self:Detach(object, true) end)
    record.Connections[2] = object.MouseEnter:Connect(function() record.Hovered = true end)
    record.Connections[3] = object.MouseLeave:Connect(function() record.Hovered = false end)
    return object
end

-- Returns an actual native Frame. Native events, Parent, Clone and TweenService
-- work normally. Glass properties live in attributes, avoiding fake Instance fields.
function Manager:Create(properties)
    local frame = Instance.new('Frame')
    frame.Name = 'LiquidGlassFrame'
    frame.BorderSizePixel = 0
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    local parent = properties and properties.Parent
    local ok, message = pcall(function()
        for key, value in pairs(properties or {}) do
            if key ~= 'Parent' then frame[key] = value end
        end
    end)
    if not ok then frame:Destroy(); error(message, 2) end
    self:Attach(frame)
    frame.Parent = parent
    return frame
end

function Manager:Detach(object, destroying)
    local record = self.ByObject[object]
    if not record then return end
    self.ByObject[object] = nil
    local index = table.find(self.Records, record)
    if index then table.remove(self.Records, index) end
    for _, connection in ipairs(record.Connections) do connection:Disconnect() end
    if not destroying then
        if record.AppliedTransparency == object.BackgroundTransparency then
            object.BackgroundTransparency = record.OriginalTransparency
        end
        if object.BorderSizePixel == 0 then object.BorderSizePixel = record.OriginalBorder end
        object:SetAttribute('LiquidGlass', nil)
        object:SetAttribute('LiquidGlassMode', nil)
        for _, decoration in ipairs(record.Decorations) do decoration:Destroy() end
        if record.Image then record.Image:Destroy() end
    end
end

local function bounds(record, root)
    local object = record.Object
    if not object:IsDescendantOf(root) or not root.Enabled then return nil end
    local position, size = object.AbsolutePosition, object.AbsoluteSize
    if size.X <= 0 or size.Y <= 0 then return nil end
    local rect = {X = position.X, Y = position.Y, Width = size.X, Height = size.Y}
    local node = object
    local optical = root.ZIndexBehavior == Enum.ZIndexBehavior.Sibling
    while node and node ~= root do
        if node:IsA('GuiObject') then
            if not node.Visible then return nil end
            if node.AbsoluteRotation ~= 0 or node:IsA('CanvasGroup') then optical = false end
            if node ~= object and (node.ClipsDescendants or node:IsA('ScrollingFrame')) then
                local p, s = node.AbsolutePosition, node.AbsoluteSize
                if not LiquidGlass.Overlaps(rect, {X = p.X, Y = p.Y, Width = s.X, Height = s.Y}) then return nil end
                -- Native clipping still applies; we deliberately do not invent a new
                -- rounded corner at the intersection of a scroll viewport and the lens.
            end
        end
        node = node.Parent
    end
    return rect, optical
end

local function path(object, root)
    local result = {}
    while object and object ~= root do
        table.insert(result, 1, object)
        object = object.Parent
    end
    return result
end

local function before(a, b)
    local ap, bp = a.Path, b.Path
    for i = 1, math.min(#ap, #bp) do
        if ap[i] ~= bp[i] then
            local az = ap[i]:IsA('GuiObject') and ap[i].ZIndex or 0
            local bz = bp[i]:IsA('GuiObject') and bp[i].ZIndex or 0
            if az ~= bz then return az < bz end
            -- Equal-Z sibling ordering is intentionally not relied on for optics:
            -- any intersection is made a thin overlay, regardless of tie order.
            return a.Record.Serial < b.Record.Serial
        end
    end
    return #ap < #bp
end

function Manager:Decorate(record, overlay)
    local object = record.Object
    if not record.Stroke then
        record.AppliedTransparency = math.max(record.OriginalTransparency, overlay and 0.96 or 0.72)
        object.BackgroundTransparency = record.AppliedTransparency
        object.BorderSizePixel = 0
        if not object:IsA('ScrollingFrame') and not object:FindFirstChildOfClass('UICorner') then
            record.Corner = create('UICorner', {CornerRadius = UDim.new(0, 10)}, object)
            table.insert(record.Decorations, record.Corner)
        end
        record.Stroke = create('UIStroke', {ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Thickness = 1, Transparency = 0.55, Color = Color3.new(1, 1, 1)}, object)
        table.insert(record.Decorations, record.Stroke)
        create('UIGradient', {Rotation = 55, Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.5, 0.75),
            NumberSequenceKeypoint.new(1, 0.25)})}, record.Stroke)
        -- UIShadow is version/rollout dependent. A missing class is not fatal.
        local ok, shadow = pcall(create, 'UIShadow', {BlurRadius = UDim.new(0, 12),
            Offset = UDim2.fromOffset(0, 4), Color = Color3.new(0, 0, 0),
            Transparency = 0.75}, object)
        if ok then record.Shadow = shadow; table.insert(record.Decorations, shadow) end
    end
    local opacity = numberAttribute(object, 'GlassOpacity', 1, 0, 1)
    local radius = numberAttribute(object, 'GlassRadius', 10, 0, 512)
    if record.Corner then record.Corner.CornerRadius = UDim.new(0, radius) end
    local hover = record.Hovered and 1 or 0
    record.HoverLight = self.ReducedMotion and hover or (record.HoverLight or 0) + (hover - (record.HoverLight or 0)) * 0.35
    record.Stroke.Transparency = 1 - (self.HighContrast and 0.9 or 0.45 + 0.25 * record.HoverLight) * opacity
    local border = object.BorderColor3
    record.Stroke.Color = Color3.new(0.5 + border.R * 0.5, 0.5 + border.G * 0.5, 0.5 + border.B * 0.5)
    if record.Shadow then record.Shadow.Transparency = 1 - (overlay and 0.18 or 0.28) * opacity end
    local desired = self.ReducedTransparency and 0.08 or (overlay and 0.96 or 0.72)
    if object.BackgroundTransparency == record.AppliedTransparency then
        record.AppliedTransparency = math.max(record.OriginalTransparency, desired)
        object.BackgroundTransparency = record.AppliedTransparency
    end
end

local function canHostImage(object)
    -- An extra GuiObject must not join a layout, alter AutomaticSize, cover native
    -- text/images, scroll with the canvas, or get recolored by the parent's gradient.
    if not object:IsA('Frame') or object.AutomaticSize ~= Enum.AutomaticSize.None then return false end
    for _, child in ipairs(object:GetChildren()) do
        if child:IsA('UILayout') or child:IsA('UIPadding') or child:IsA('UIGradient') then return false end
        if child:IsA('GuiObject') and not child:GetAttribute(INTERNAL) and child.ZIndex <= -10000 then return false end
    end
    return true
end

local function cornerRadius(object, rect)
    local corner = object:FindFirstChildOfClass('UICorner')
    if not corner then return 0 end
    -- Independent corners are a newer API. Use a conservative fallback if they
    -- differ; the shader must never contradict the native hit-test silhouette.
    local uniform = pcall(function()
        assert(corner.TopLeftRadius == corner.TopRightRadius
            and corner.TopLeftRadius == corner.BottomLeftRadius
            and corner.TopLeftRadius == corner.BottomRightRadius)
    end)
    local hasIndividual = pcall(function() return corner.TopLeftRadius end)
    if hasIndividual and not uniform then return nil end
    local scale, node = 1, object
    while node and not node:IsA('ScreenGui') do
        local uiScale = node:FindFirstChildOfClass('UIScale')
        if uiScale then scale *= uiScale.Scale end
        node = node.Parent
    end
    return math.min(rect.Width, rect.Height) * corner.CornerRadius.Scale + corner.CornerRadius.Offset * scale
end

function Manager:EnsureAtlas()
    if self.Atlas then return true end
    if self.FailedAllocation then return false end
    local ok, result = pcall(function()
        return game:GetService('AssetService'):CreateEditableImage({Size = Vector2.new(self.AtlasSize, self.AtlasSize)})
    end)
    if not ok or not result then
        self.FailedAllocation = true
        self.LastError = ok and 'EditableImage memory budget exhausted' or tostring(result)
        self.Status = 'EditableImageUnavailable'
        return false
    end
    local linked, content, pixels = pcall(function()
        return Content.fromObject(result), buffer.create(self.AtlasSize * self.AtlasSize * 4)
    end)
    if not linked then
        result:Destroy()
        self.FailedAllocation, self.LastError, self.Status = true, tostring(content), 'EditableImageUnavailable'
        return false
    end
    self.Atlas, self.Content, self.Pixels = result, content, pixels
    return true
end

function Manager:Step()
    self:HideImages()
    self.Stats.RenderedSurfaces, self.Stats.OverlaySurfaces = 0, 0
    local visible = {}
    for _, record in ipairs(self.Records) do
        local rect, optical = bounds(record, self.Root)
        if rect then
            table.insert(visible, {Record = record, Rect = rect, Optical = optical, Path = path(record.Object, self.Root)})
        end
    end
    table.sort(visible, before)
    local bases, candidates = {}, {}
    for _, entry in ipairs(visible) do
        local overlay = false
        for _, base in ipairs(bases) do
            if LiquidGlass.Overlaps(entry.Rect, base.Rect) then overlay = true; break end
        end
        self:Decorate(entry.Record, overlay)
        if entry.Record.Image and not canHostImage(entry.Record.Object) then
            entry.Record.Image:Destroy()
            entry.Record.Image = nil
        end
        entry.Record.Object:SetAttribute('LiquidGlassMode', overlay and 'Overlay' or 'TranslucentFallback')
        if overlay then self.Stats.OverlaySurfaces += 1
        else
            table.insert(bases, entry)
            if entry.Optical and canHostImage(entry.Record.Object)
                and cornerRadius(entry.Record.Object, entry.Rect) ~= nil and #candidates < self.MaxSurfaces then
                table.insert(candidates, entry)
            end
        end
    end
    if not self.Provider or self.ReducedTransparency or #candidates == 0 then
        self.Status = self.Provider and 'NoEligibleSurfaces' or 'TranslucentFallback'
        return
    end
    -- Providers must return a ready immutable frame without yielding. A coroutine
    -- prevents a yielded provider from creating concurrent render loops.
    local co = coroutine.create(self.Provider)
    local ok, source = coroutine.resume(co, {Root = self.Root, Surfaces = candidates})
    if coroutine.status(co) ~= 'dead' then
        pcall(coroutine.close, co)
        error('LiquidGlass source provider must not yield')
    end
    if not ok then error(source) end
    if source == nil then self.Status = 'WaitingForSource'; return end
    local sources = type(source)=='table' and source.Sources
    if not sources and not LiquidGlass.ValidateSource(source) then error('Invalid LiquidGlass source frame') end
    if sources and type(sources)~='table' then error('Invalid LiquidGlass sources map') end
    if not self:EnsureAtlas() then return end
    buffer.fill(self.Pixels, 0, 0)
    local rendered = {}
    for _, entry in ipairs(candidates) do
        local rect, record = entry.Rect, entry.Record
        local object = record.Object
        local source = sources and sources[object] or source
        if sources and not sources[object] then continue end
        if not LiquidGlass.ValidateSource(source) then error('Invalid LiquidGlass surface source') end
        -- Do not extend an incomplete source over missing background content.
        if rect.X < source.Origin.X or rect.Y < source.Origin.Y
            or rect.X + rect.Width > source.Origin.X + source.Size.X
            or rect.Y + rect.Height > source.Origin.Y + source.Size.Y then continue end
        local index = #rendered
        local tx, ty = (index % self.Columns) * self.TileSize, math.floor(index / self.Columns) * self.TileSize
        local radius = cornerRadius(object, rect)
        -- A few background samples adapt material separation, never the actual
        -- color-picker values or the application's text-color registry.
        local darkest, brightest = 255, 0
        for point = 1, 5 do
            local px = rect.X + rect.Width * (point / 6)
            local py = rect.Y + rect.Height * ((point % 2 == 0) and 0.3 or 0.7)
            local luminance = sample(source, px, py, 0) * 0.2126 + sample(source, px, py, 1) * 0.7152
                + sample(source, px, py, 2) * 0.0722
            darkest, brightest = math.min(darkest, luminance), math.max(brightest, luminance)
        end
        local contrast = (brightest - darkest) / 255
        local style = {Radius = radius, Bezel = numberAttribute(object, 'GlassBezel', 16, 1, 128),
            Refraction = numberAttribute(object, 'GlassRefraction', 8, 0, 64),
            Blur = numberAttribute(object, 'GlassBlur', 1.5, 0, 16),
            Opacity = numberAttribute(object, 'GlassOpacity', 1, 0, 1), Tint = object.BackgroundColor3,
            TintStrength = numberAttribute(object, 'GlassTintStrength', 0.18 + contrast * 0.12, 0, 1)}
        if record.Shadow then record.Shadow.Transparency = 1 - (0.2 + contrast * 0.2) * style.Opacity end
        LiquidGlass.RenderTile(self.Pixels, self.AtlasSize, tx, ty, self.TileSize, source, rect, style)
        if not record.Image then
            record.Image = create('ImageLabel', {Name = 'LiquidGlassOptics', BackgroundTransparency = 1,
                BorderSizePixel = 0, ImageContent = self.Content, Size = UDim2.fromScale(1, 1),
                Active = false, Selectable = false, ZIndex = -10000, Visible = false}, object)
        end
        record.Image.ImageRectOffset = Vector2.new(tx + 1, ty + 1)
        record.Image.ImageRectSize = Vector2.new(self.TileSize - 2, self.TileSize - 2)
        table.insert(rendered, record)
    end
    if #rendered > 0 then
        self.Atlas:WritePixelsBuffer(Vector2.zero, Vector2.new(self.AtlasSize, self.AtlasSize), self.Pixels)
        for _, record in ipairs(rendered) do
            record.Image.Visible = true
            record.Object:SetAttribute('LiquidGlassMode', 'SourceRefraction')
        end
    end
    self.Stats.RenderedSurfaces = #rendered
    self.Status = #rendered > 0 and (self.Backdrop and 'GuiReconstruction' or 'SourceRefraction') or 'SourceOutOfBounds'
end

function Manager:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    if self.Backdrop then self.Backdrop:Destroy(); self.Backdrop = nil end
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    while #self.Records > 0 do self:Detach(self.Records[#self.Records].Object) end
    if self.Atlas then self.Atlas:Destroy() end
    self.Atlas, self.Content, self.Pixels, self.Provider = nil, nil, nil, nil
    self.Status = 'Destroyed'
end

return LiquidGlass

end)()
-- END GENERATED LIQUID GLASS

local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
if not pcall(function() ScreenGui.Parent = CoreGui end) then
    ScreenGui.Parent = LocalPlayer:WaitForChild('PlayerGui')
end
ScreenGui.ResetOnSpawn = false;

local TOPMOST_CHECKED_TYPES = {'TextButton'}

local function isTopmost(target: GuiObject, x: number, y: number): boolean
    local container = ScreenGui:FindFirstAncestorWhichIsA('BasePlayerGui')
    if not container then return false end
    -- The LayerCollector overload is restricted on some clients. Use BasePlayerGui.
    -- Mouse coordinates also avoid the MouseEnter/GuiInset mismatch reported on DevForum.
    x, y = Mouse.X, Mouse.Y
    local ok, objects = pcall(container.GetGuiObjectsAtPosition, container, x, y)
    if not ok then return false end
    for _, guiObject in ipairs(objects) do
        if not guiObject:IsDescendantOf(ScreenGui) then continue end
        if guiObject == target then return true end
        local ignored = true
        for _, checkedType in pairs(TOPMOST_CHECKED_TYPES) do
            if guiObject:IsA(checkedType) then
                ignored = false
                break
            end
        end
        if not ignored then return false end
    end
    return false -- A hidden/destroyed target can disappear between input and hit testing.
end

local function setHoveringBehaviour(
    target: GuiObject, onHovered: () -> (), onUnhovered: () -> ()
): ()
    local onHoveredCalled = false

    local function callOnHovered()
        onHovered()
        onHoveredCalled = true
    end

    local function callOnUnhovered()
        if not onHoveredCalled then return end
        onUnhovered()
        onHoveredCalled = false
    end

    target.MouseEnter:Connect(function(x, y)
        if not isTopmost(target, x, y) then return end
        callOnHovered()
    end)
    target.MouseMoved:Connect(function(x, y)
        if isTopmost(target, x, y) then
            if onHoveredCalled then return end
            callOnHovered()
        else callOnUnhovered()
        end
    end)
    target.MouseLeave:Connect(callOnUnhovered)
end

local Library = {
    liquidGlass = false; -- Configure before CreateWindow; captured for this library instance.
    LiquidGlassOptions = {};
    _CreatedGuiObjects = setmetatable({}, {__mode = 'k'});
    Registry = {};
    RegistryMap = {};

    HudRegistry = {};

    FontColor = Color3.fromRGB(255, 255, 255);
    MainColor = Color3.fromRGB(28, 28, 28);
    BackgroundColor = Color3.fromRGB(20, 20, 20);
    AccentColor = Color3.fromRGB(0, 85, 255);
    OutlineColor = Color3.fromRGB(50, 50, 50);
    RiskColor = Color3.fromRGB(255, 50, 50),

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,

    OpenedFrames = {};
    DependencyBoxes = {};

    Signals = {};
    ScreenGui = ScreenGui;
};
local Toggles = {}
local Options = {}

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta

    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400);

        if Hue > 1 then
            Hue = 0;
        end;

        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();

    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;

    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);

    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();

    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;

    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    
    return TeamList;
end;

function Library:SafeCallback(f, ...)
    if (not f) then
        return;
    end;

    if not Library.NotifyOnError then
        return f(...);
    end;

    local success, event = pcall(f, ...);

    if not success then
        local _, i = event:find(":%d+: ");

        if not i then
            return Library:Notify(event);
        end;

        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save();
    end;
end;

local function getGlassManager()
    if not Library.LiquidGlassManager then
        local options = table.clone(Library.LiquidGlassOptions or {})
        if options.AutoBackdrop == nil then options.AutoBackdrop = true end
        Library.LiquidGlassManager = LiquidGlass.newManager(ScreenGui, options)
    end
    return Library.LiquidGlassManager
end

function Library:SetLiquidGlass(Enabled, Options)
    assert(not Library._WindowCreated, 'Set liquidGlass before CreateWindow')
    assert(type(Enabled) == 'boolean', 'liquidGlass must be boolean')
    assert(not Library.LiquidGlassManager, 'Configure LiquidGlass before creating glass elements')
    Library.liquidGlass = Enabled
    Library.LiquidGlassOptions = Options or Library.LiquidGlassOptions
end

function Library:SetLiquidGlassSourceProvider(Provider)
    getGlassManager():SetSourceProvider(Provider)
end

function Library:GetLiquidGlassStatus()
    return getGlassManager():GetStatus()
end

function Library:GetContentChildren(Object)
    local Children = {}
    for _, Child in ipairs(Object:GetChildren()) do
        if Child:IsA('GuiObject') and not Child:GetAttribute('ShardGlassInternal') then
            table.insert(Children, Child)
        end
    end
    return Children
end

local function registerGlassObject(Object, Allowed)
    if not Object:IsA('GuiObject') then return end
    if Allowed ~= nil then Library._CreatedGuiObjects[Object] = Allowed end
    local enabled = Library._WindowCreated and Library._LiquidGlassEnabled or
        (not Library._WindowCreated and Library.liquidGlass)
    if enabled and Library._CreatedGuiObjects[Object] ~= false and Object.BackgroundTransparency < 1 then
        getGlassManager():Attach(Object)
    end
end

function Library:Create(Class, Properties)
    Properties = Properties or {}
    local IsGlass = Class == 'LiquidGlassFrame'
    local Object = type(Class) == 'string' and Instance.new(IsGlass and 'Frame' or Class) or Class
    -- Parent last: no partly configured objects are exposed to layouts/rendering.
    for Property, Value in next, Properties do
        if Property ~= 'Parent' and Property ~= 'LiquidGlass' then Object[Property] = Value end
    end
    if IsGlass then
        getGlassManager():Attach(Object)
    else
        local Allowed = Properties.LiquidGlass
        if Allowed == nil and type(Class) == 'string' then Allowed = true end
        registerGlassObject(Object, Allowed)
    end
    if Properties.LiquidGlass == false and Library.LiquidGlassManager then
        Library.LiquidGlassManager:Detach(Object)
    end
    if Properties.Parent ~= nil then Object.Parent = Properties.Parent end
    return Object
end

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;

    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    });
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 16;
        TextStrokeTransparency = 0;
    });

    Library:ApplyTextStroke(_Instance);

    Library:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    return Library:Create(_Instance, Properties);
end;

function Library:MakeDraggable(Instance)
    Instance.Active = true;

    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ObjPos = Vector2.new(
                Mouse.X - Instance.AbsolutePosition.X,
                Mouse.Y - Instance.AbsolutePosition.Y
            );

            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                Instance.Position = UDim2.new(
                    0,
                    Mouse.X - ObjPos.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                    0,
                    Mouse.Y - ObjPos.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y)
                );

                RenderStepped:Wait();
            end;
        end;
    end)
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,

        Size = UDim2.fromOffset(X + 5, Y + 4),
        ZIndex = 3,
        Parent = Library.ScreenGui,

        Visible = false,
    })

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1),
        Size = UDim2.fromOffset(X, Y);
        TextSize = 14;
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left;

        Parent = Tooltip;
    });

    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    Library:AddToRegistry(Label, {
        TextColor3 = 'FontColor',
    });

    setHoveringBehaviour(
        HoverInstance,
        function() Tooltip.Visible = true end,
        function() Tooltip.Visible = false end
    )
    Mouse.Move:Connect(function()
        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    local function highlightOn(): ()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end

    local function highlightOff(): ()
        local Reg = Library.RegistryMap[Instance];
        
        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end

    setHoveringBehaviour(HighlightInstance, highlightOn, highlightOff)
end

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

        return true;
    end;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };

    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;

    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end;
        end;

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end;
        end;

        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateColorsUsingRegistry()
    -- TODO: Could have an 'active' list of objects
    -- where the active list only contains Visible objects.

    -- IMPL: Could setup .Changed events on the AddToRegistry function
    -- that listens for the 'Visible' propert being changed.
    -- Visible: true => Add to active list, and call UpdateColors function
    -- Visible: false => Remove from active list.

    -- The above would be especially efficient for a rainbow menu color or live color-changing.

    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end;
    end;
end;

function Library:GiveSignal(Signal)
    -- Only used for signals not attached to library instances, as those should be cleaned up on object destruction by Roblox
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    -- Unload all of the signals
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end

     -- Call our unload callback, maybe to undo some hooks etc
    if Library.LiquidGlassManager then Library.LiquidGlassManager:Destroy() end
    if Library._OnUnloadCallback then
        Library._OnUnloadCallback()
    end

    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    Library._OnUnloadCallback = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
end))

local BaseAddons = {};

do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;
        -- local Container = self.Container;

        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);

            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;

        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        local frameSize = UDim2.new(0, 28, 0, 14)

        local frameContainer = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = frameSize,
            Parent = ToggleLabel
        })

        local DisplayFrame = Library:Create('Frame', {
            LiquidGlass = false;
            ZIndex = 2,
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            BorderMode = Enum.BorderMode.Inset;
            Size = frameSize;
            Parent = frameContainer;
        });

        -- Transparency image taken from https://github.com/matas3535/SplixPrivateDrawingLibrary/blob/main/Library.lua cus i'm lazy
        local CheckerFrame = Library:Create('ImageLabel', {
            LiquidGlass = false;
            ZIndex = 1,
            Size = frameSize;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = frameContainer;
        });

        -- 1/16/23
        -- Rewrote this to be placed inside the Library ScreenGui
        -- There was some issue which caused RelativeOffset to be way off
        -- Thus the color picker would never show

        local PickerFrameOuter = Library:Create('TextButton', {
            Text = '',
            AutoButtonColor = false,
            Name = 'Color';
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible = false;
            ZIndex = 2;
            Parent = ScreenGui,
        });

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            Parent = PickerFrameOuter;
        });

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            Parent = PickerFrameInner;
        });

        local SatVibMapOuter = Library:Create('Frame', {
            LiquidGlass = false;
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            Parent = PickerFrameInner;
        });

        local SatVibMapInner = Library:Create('Frame', {
            LiquidGlass = false;
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            Parent = SatVibMapOuter;
        });

        local SatVibMap = Library:Create('ImageLabel', {
            LiquidGlass = false;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapInner;
        });

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            Parent = SatVibMap;
        });

        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame', {
            LiquidGlass = false;
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            Parent = PickerFrameInner;
        });

        local HueSelectorInner = Library:Create('Frame', {
            LiquidGlass = false;
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            Parent = HueSelectorOuter;
        });

        local HueCursor = Library:Create('Frame', {
            LiquidGlass = false;
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner;
        });

        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            Parent = HueBoxOuter;
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            Parent = HueBoxInner;
        });

        Library:ApplyTextStroke(HueBox);

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        });

        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        
        if Info.Transparency then 
            TransparencyBoxOuter = Library:Create('Frame', {
            LiquidGlass = false;
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                Parent = PickerFrameInner;
            });

            TransparencyBoxInner = Library:Create('Frame', {
            LiquidGlass = false;
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                Parent = TransparencyBoxOuter;
            });

            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex = 1;
                Parent = TransparencyBoxInner;
            });

            TransparencyCursor = Library:Create('Frame', {
            LiquidGlass = false;
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 2;
                Parent = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title,--Info.Default;
            TextWrapped = false;
            Parent = PickerFrameInner;
        });


        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', {
                BorderColor3 = Color3.new(),
                ZIndex = 2,

                Visible = false,
                Parent = ScreenGui
            })

            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                Parent = ContextMenu.Container;
            });

            Library:Create('UIListLayout', {
                Name = 'Layout',
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            });

            Library:Create('UIPadding', {
                Name = 'Padding',
                PaddingLeft = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            });

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then
                        menuWidth = math.max(menuWidth, label.TextBounds.X)
                    end
                end

                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            function ContextMenu:Show()
                self.Container.Visible = true
            end

            function ContextMenu:Hide()
                self.Container.Visible = false
            end

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then
                    Callback = function() end
                end

                local Button = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, 0, 0, 15);
                    TextSize = 13;
                    Text = Str;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                });

                Library:OnHighlight(Button, Button, 
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = 'FontColor' }
                );

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    Callback()
                end)
            end

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify('Copied color!', 2)
            end)

            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then
                    return Library:Notify('You have not copied a color!', 2)
                end
                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)


            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify('Copied hex code to clipboard!', 2)
            end)

            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                Library:Notify('Copied RGB values to clipboard!', 2)
            end)

        end

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });

        local SequenceTable = {};

        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
        end;

        local HueSelectorGradient = Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end

            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end

            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            });

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);

            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value)
        end;

        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false;
                    Library.OpenedFrames[Frame] = nil;
                end;
            end;

            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = true;
        end;

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);

            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX = SatVibMap.AbsolutePosition.X;
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y;
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end;
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end);

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        local MinX = TransparencyBoxInner.AbsolutePosition.X;
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                        local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));

                        ColorPicker:Display();

                        RenderStepped:Wait();
                    end;

                    Library:AttemptSave();
                end;
            end);
        end;

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ColorPicker:Hide();
                end;

                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame

        Options[Idx] = ColorPicker;

        return self;
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        local Container = self.Container;

        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle'; -- Always, Toggle, Hold
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;

            SyncToggleState = Info.SyncToggleState or false;
        };

        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 28, 0, 15);
            Parent = ToggleLabel;
        });

        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            Parent = PickOuter;
        });

        Library:AddToRegistry(PickInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = Info.Default;
            TextWrapped = true;
            Parent = PickInner;
        });

        local ModeSelectOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
            Size = UDim2.new(0, 60, 0, 45 + 2);
            Visible = false;
            ZIndex = 2;
            Parent = ScreenGui;
        });

        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
        end);

        local ModeSelectInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            Parent = ModeSelectOuter;
        });

        Library:AddToRegistry(ModeSelectInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        });

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size = UDim2.new(1, 0, 0, 18);
            TextSize = 13;
            Visible = false;
            Parent = Library.KeybindContainer;
        },  true);

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for Idx, Mode in next, Modes do
            local ModeButton = {};

            local Label = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = Mode;
                Parent = ModeSelectInner;
            });

            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect();
                end;

                KeyPicker.Mode = Mode;

                Label.TextColor3 = Library.AccentColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';

                ModeSelectOuter.Visible = false;
            end;

            function ModeButton:Deselect()
                KeyPicker.Mode = nil;

                Label.TextColor3 = Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;

            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    ModeButton:Select();
                    Library:AttemptSave();
                end;
            end);

            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;

            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI then
                return;
            end;

            local State = KeyPicker:GetState();

            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode);

            ContainerLabel.Visible = true;
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;

            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';

            local YSize = 0
            local XSize = 0

            for _, Label in next, Library:GetContentChildren(Library.KeybindContainer) do
                if Label:IsA('TextLabel') and Label.Visible then
                    YSize = YSize + 18;
                    if (Label.TextBounds.X > XSize) then
                        XSize = Label.TextBounds.X
                    end
                end;
            end;

            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23)
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then
                    return false;
                end

                local Key = KeyPicker.Value;

                if Key == 'MB1' or Key == 'MB2' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
                end;
            else
                return KeyPicker.Toggled;
            end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            ModeButtons[Mode]:Select();
            KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false;

        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true;

                DisplayLabel.Text = '';

                local Break;
                local Text = '';

                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then
                            Text = '';
                        end;

                        Text = Text .. '.';
                        DisplayLabel.Text = Text;

                        wait(0.4);
                    end;
                end);

                wait(0.2);

                local Event;
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key;

                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        Key = Input.KeyCode.Name;
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2';
                    end;

                    Break = true;
                    Picking = false;

                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;

                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)

                    Library:AttemptSave();

                    Event:Disconnect();
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = true;
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;

                    if Key == 'MB1' or Key == 'MB2' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick()
                        end;
                    end;
                end;

                KeyPicker:Update();
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ModeSelectOuter.Visible = false;
                end;
            end;
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if (not Picking) then
                KeyPicker:Update();
            end;
        end))

        KeyPicker:Update();

        Options[Idx] = KeyPicker;

        return self;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

local BaseGroupbox = {};

do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;

        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            Parent = Container;
        });
    end;

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};

        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Text;
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(Text)
            TextLabel.Text = Text

            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end

            Groupbox:Resize();
        end

        if (not DoesWrap) then
            setmetatable(Label, BaseAddons);
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Label;
    end;

    function Funcs:AddButton(...)
        -- TODO: Eventually redo this
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end

            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end

        ProcessButtonParams('Button', Button, ...)

        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 20);
            });

            local Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                Parent = Outer;
            });

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = 14;
                Text = Button.Text;
                Parent = Inner;
            });

            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Inner;
            });

            Library:AddToRegistry(Outer, {
                BorderColor3 = 'Black';
            });

            Library:AddToRegistry(Inner, {
                BackgroundColor3 = 'MainColor';
                BorderColor3 = 'OutlineColor';
            });

            Library:OnHighlight(Outer, Outer,
                { BorderColor3 = 'AccentColor' },
                { BorderColor3 = 'Black' }
            );

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...)

                    if type(validator) == 'function' and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then
                    return false
                end

                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                    return false
                end

                return true
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
                if Button.Locked then return end

                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })

                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true

                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })

                    Button.Label.TextColor3 = Library.FontColor
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, 'Locked', false)

                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    return
                end

                Library:SafeCallback(Button.Func);
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container

        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer)
            end
            return self
        end


        function Button:AddButton(...)
            local SubButton = {}

            ProcessButtonParams('SubButton', SubButton, ...)

            self.Outer.Size = UDim2.new(0.5, -4, 0, 20)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

            SubButton.Outer.Position = UDim2.new(1, 4, 0, 0)
            SubButton.Outer.Size = UDim2.new(1, 0, 1, 0)
            SubButton.Outer.Parent = self.Outer

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer)
                end
                return SubButton
            end

            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip)
            end

            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip)
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container

        local Divider = {
            Type = 'Divider',
        }

        Groupbox:AddBlank(2);
        local DividerOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 5);
            Parent = Container;
        });

        local DividerInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            Parent = DividerOuter;
        });

        Library:AddToRegistry(DividerOuter, {
            BorderColor3 = 'Black';
        });

        Library:AddToRegistry(DividerInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Groupbox:AddBlank(9);
        Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            Parent = Container;
        });

        Groupbox:AddBlank(1);

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            Parent = Container;
        });

        local TextBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            Parent = TextBoxOuter;
        });

        Library:AddToRegistry(TextBoxInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:OnHighlight(TextBoxOuter, TextBoxOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter)
        end

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = TextBoxInner;
        });

        local Container = Library:Create('Frame', {
            BackgroundTransparency = 1;
            ClipsDescendants = true;

            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);

            Parent = TextBoxInner;
        })

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;

            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1),

            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or '';

            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;

            Parent = Container;
        });

        Library:ApplyTextStroke(Box);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength);
            end;

            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then
                    Text = Textbox.Value
                end
            end

            Textbox.Value = Text;
            Box.Text = Text;

            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end

                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end

        -- https://devforum.roblox.com/t/how-to-make-textboxes-follow-current-cursor-position/1368429/6
        -- thank you nicemike40 :)

        local function Update()
            local PADDING = 2
            local reveal = Container.AbsoluteSize.X

            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                -- we aren't focused, or we fit so be normal
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                -- we are focused and don't fit, so adjust position
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    -- calculate pixel width of text from start to cursor
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X

                    -- check if we're inside the box with the cursor
                    local currentCursorPos = Box.Position.X.Offset + width

                    -- adjust if necessary
                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(Update)

        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update)
        Box.Focused:Connect(Update)

        Library:AddToRegistry(Box, {
            TextColor3 = 'FontColor';
        });

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        Options[Idx] = Textbox;

        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';

            Callback = Info.Callback or function(Value) end;
            Addons = {},
            Risky = Info.Risky,
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 13, 0, 13);
            Parent = Container;
        });

        Library:AddToRegistry(ToggleOuter, {
            BorderColor3 = 'Black';
        });

        local ToggleInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            Parent = ToggleOuter;
        });

        Library:AddToRegistry(ToggleInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0, 216, 1, 0);
            Position = UDim2.new(1, 6, 0, 0);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            Parent = ToggleInner;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });

        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 170, 1, 0);
            Parent = ToggleOuter;
        });

        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        function Toggle:UpdateColors()
            Toggle:Display();
        end;

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion)
        end

        function Toggle:Display()
            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor;
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor;

            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end;

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);

            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value) -- Why was it not like this from the start?
                Library:AttemptSave();
            end;
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or 5 + 2);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);

        Toggles[Idx] = Toggle;

        Library:UpdateDependencyBoxes();

        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 232;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        local SliderOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 13);
            Parent = Container;
        });

        Library:AddToRegistry(SliderOuter, {
            BorderColor3 = 'Black';
        });

        local SliderInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            Parent = SliderOuter;
        });

        Library:AddToRegistry(SliderInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderColor3 = Library.AccentColorDark;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 1;
            Parent = SliderInner;
        });

        Library:AddToRegistry(Fill, {
            BackgroundColor3 = 'AccentColor';
            BorderColor3 = 'AccentColorDark';
        });

        local HideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            Parent = Fill;
        });

        Library:AddToRegistry(HideBorderRight, {
            BackgroundColor3 = 'AccentColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text = 'Infinite';
            ZIndex = 2;
            Parent = SliderInner;
        });

        Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter)
        end

        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor;
            Fill.BorderColor3 = Library.AccentColorDark;
        end;

        function Slider:Display()
            local Suffix = Info.Suffix or '';

            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else
                DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix);
            end

            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            Fill.Size = UDim2.new(0, X, 1, 0);

            HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0);
        end;

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value);
            end;


            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end;

        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max));
        end;

        function Slider:SetValue(Str)
            local Num = tonumber(Str);

            if (not Num) then
                return;
            end;

            Num = math.clamp(Num, Slider.Min, Slider.Max);

            Slider.Value = Num;
            Slider:Display();

            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end;

        SliderInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                local mPos = Mouse.X;
                local gPos = Fill.Size.X.Offset;
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos);

                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos = Mouse.X;
                    local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize);

                    local nValue = Slider:GetValueFromXOffset(nX);
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;

                    Slider:Display();

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end;

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();

        Options[Idx] = Slider;

        return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end;

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

        if (not Info.Text) then
            Info.Compact = true;
        end;

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType; -- can be either 'Player' or 'Team'
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local RelativeOffset = 0;

        if not Info.Compact then
            local DropdownLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        for _, Element in next, Library:GetContentChildren(Container) do
            if not Element:IsA('UIListLayout') then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset;
            end;
        end;

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            Parent = Container;
        });

        Library:AddToRegistry(DropdownOuter, {
            BorderColor3 = 'Black';
        });

        local DropdownInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            Parent = DropdownOuter;
        });

        Library:AddToRegistry(DropdownInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        });

        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = 'http://www.roblox.com/asset/?id=6282522798';
            ZIndex = 2;
            Parent = DropdownInner;
        });

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = 14;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = true;
            ZIndex = 1;
            Parent = DropdownInner;
        });

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end

        local MAX_DROPDOWN_ITEMS = 8;

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 2;
            Visible = false;
            Parent = ScreenGui;
        });

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1);
        end;

        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end;

        RecalculateListPosition();
        RecalculateListSize();

        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);

        local ListInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            Parent = ListOuter;
        });

        Library:AddToRegistry(ListInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Parent = ListInner;

            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        });

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = 'AccentColor'
        })

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });

        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';

            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. Value .. ', ';
                    end;
                end;

                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end;

            ItemList.Text = (Str == '' and '--' or Str);
        end;

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value);
                end;

                return T;
            else
                return Dropdown.Value and 1 or 0;
            end;
        end;

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values;
            local Buttons = {};

            for _, Element in next, Library:GetContentChildren(Scrolling) do
                if not Element:IsA('UIListLayout') then
                    Element:Destroy();
                end;
            end;

            local Count = 0;

            for Idx, Value in next, Values do
                local Table = {};

                Count = Count + 1;

                local Button = Library:Create('TextButton', {
                    Text = '',
                    AutoButtonColor = false,
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20);
                    ZIndex = 1;
                    Parent = Scrolling;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                    BorderColor3 = 'OutlineColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14;
                    Text = Value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    Parent = Button;
                });

                Library:OnHighlight(Button, Button,
                    { BorderColor3 = 'AccentColor', ZIndex = 2 },
                    { BorderColor3 = 'OutlineColor', ZIndex = 1 }
                );

                local Selected;

                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value;
                end;

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end;

                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;

                Button.MouseButton1Click:Connect(function()
                    local Try = not Selected;

                    if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                    else
                        if Info.Multi then
                            Selected = Try;

                            if Selected then
                                Dropdown.Value[Value] = true;
                            else
                                Dropdown.Value[Value] = nil;
                            end;
                        else
                            Selected = Try;

                            if Selected then
                                Dropdown.Value = Value;
                            else
                                Dropdown.Value = nil;
                            end;

                            for _, OtherButton in next, Buttons do
                                OtherButton:UpdateButton();
                            end;
                        end;

                        Table:UpdateButton();
                        Dropdown:Display();

                        Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                        Library:SafeCallback(Dropdown.Changed, Dropdown.Value);

                        Library:AttemptSave();
                    end;
                end);

                Table:UpdateButton();
                Dropdown:Display();

                Buttons[Button] = Table;
            end;

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);

            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;

            Dropdown:BuildDropdownList();
        end;

        function Dropdown:OpenDropdown()
            ListOuter.Visible = true;
            Library.OpenedFrames[ListOuter] = true;
            DropdownArrow.Rotation = 180;
        end;

        function Dropdown:CloseDropdown()
            ListOuter.Visible = false;
            Library.OpenedFrames[ListOuter] = nil;
            DropdownArrow.Rotation = 0;
        end;

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};

                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then
                        nTable[Value] = true
                    end;
                end;

                Dropdown.Value = nTable;
            else
                if (not Val) then
                    Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then
                    Dropdown.Value = Val;
                end;
            end;

            Dropdown:BuildDropdownList();

            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then
                    Dropdown:CloseDropdown();
                else
                    Dropdown:OpenDropdown();
                end;
            end;
        end);

        InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    Dropdown:CloseDropdown();
                end;
            end;
        end);

        Dropdown:BuildDropdownList();
        Dropdown:Display();

        local Defaults = {}

        if type(Info.Default) == 'string' then
            local Idx = table.find(Dropdown.Values, Info.Default)
            if Idx then
                table.insert(Defaults, Idx)
            end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local Idx = table.find(Dropdown.Values, Value)
                if Idx then
                    table.insert(Defaults, Idx)
                end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index];
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end

        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();

        Options[Idx] = Dropdown;

        return Dropdown;
    end;

    function Funcs:AddDependencyBox()
        local Depbox = {
            Dependencies = {};
        };
        
        local Groupbox = self;
        local Container = Groupbox.Container;

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        });

        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        });

        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        });

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y);
            Groupbox:Resize();
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Depbox:Resize();
        end);

        Holder:GetPropertyChangedSignal('Visible'):Connect(function()
            Depbox:Resize();
        end);

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Value = Dependency[2];

                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end;
            end;

            Holder.Visible = true;
            Depbox:Resize();
        end;

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
            end;

            Depbox.Dependencies = Dependencies;
            Depbox:Update();
        end;

        Depbox.Container = Frame;

        setmetatable(Depbox, BaseGroupbox);

        table.insert(Library.DependencyBoxes, Depbox);

        return Depbox;
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

-- < Create other UI elements >
do
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 40);
        Size = UDim2.new(0, 300, 0, 200);
        ZIndex = 6;
        Parent = ScreenGui;
    });

    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });

    local WatermarkOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, -25);
        Size = UDim2.new(0, 213, 0, 20);
        ZIndex = 5;
        Visible = false;
        Parent = ScreenGui;
    });

    local WatermarkInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        Parent = WatermarkOuter;
    });

    Library:AddToRegistry(WatermarkInner, {
        BorderColor3 = 'AccentColor';
    });

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        Parent = WatermarkInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 5, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        TextSize = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        Parent = InnerFrame;
    });

    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);



    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210, 0, 20);
        Visible = false;
        ZIndex = 4;
        Parent = ScreenGui;
    });

    local KeybindInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        Parent = KeybindOuter;
    });

    Library:AddToRegistry(KeybindInner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    }, true);

    local ColorFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        Parent = KeybindInner;
    });

    Library:AddToRegistry(ColorFrame, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    local KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 20);
        Position = UDim2.fromOffset(5, 2),
        TextXAlignment = Enum.TextXAlignment.Left,

        Text = 'Keybinds';
        Parent = KeybindInner;
    });

    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -20);
        Position = UDim2.new(0, 0, 0, 20);
        Parent = KeybindInner;
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    });

    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 5),
        Parent = KeybindContainer,
    })

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end;

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14);
    Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3);
    Library:SetWatermarkVisibility(true)

    Library.WatermarkText.Text = Text;
end;

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 14);

    YSize = YSize + 7

    local NotifyOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, 10);
        Size = UDim2.new(0, 0, 0, YSize);
        ClipsDescendants = true;
        Parent = Library.NotificationArea;
    });

    local NotifyInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(NotifyInner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    }, true);

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        Parent = NotifyInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, 4, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        Text = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = 14;
        Parent = InnerFrame;
    });

    local LeftColor = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, -1, 0, -1);
        Size = UDim2.new(0, 3, 1, 2);
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(LeftColor, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize + 8 + 4, 0, YSize), 'Out', 'Quad', 0.4, true);

    task.spawn(function()
        wait(Time or 5);

        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quad', 0.4, true);

        wait(0.4);

        NotifyOuter:Destroy();
    end);
end;

function Library:CreateWindow(...)
    if not Library._WindowCreated then
        assert(type(Library.liquidGlass) == 'boolean', 'liquidGlass must be boolean')
        Library._LiquidGlassEnabled = Library.liquidGlass
        Library._WindowCreated = true
        if Library._LiquidGlassEnabled then
            for Object, Allowed in pairs(Library._CreatedGuiObjects) do
                if Object.Parent then registerGlassObject(Object, Allowed) end
            end
        end
    end
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false;
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end

    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550, 600) end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    local Window = {
        Tabs = {};
    };

    local Outer = Library:Create('TextButton', {
        Text = '',
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        AnchorPoint = Config.AnchorPoint,
        BorderSizePixel = 0;
        Position = Config.Position,
        Size = Config.Size,
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
    });

    Library:MakeDraggable(Outer);

    local Inner = Library:Create(Library._LiquidGlassEnabled and 'Frame' or 'CanvasGroup', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.fromScale(1, 0),
        Parent = Outer;
    });

    if Library._LiquidGlassEnabled then Inner.ClipsDescendants = true
    else Inner.GroupTransparency = 1 end

    Library:AddToRegistry(Inner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'AccentColor';
    });

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 7, 0, 0);
        Size = UDim2.new(0, 0, 0, 25);
        Text = Config.Title or '';
        TextXAlignment = Enum.TextXAlignment.Left;
        Parent = Inner;
    });

    local MainSectionOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 25);
        Size = UDim2.new(1, -16, 1, -33);
        Parent = Inner;
    });

    Library:AddToRegistry(MainSectionOuter, {
        BackgroundColor3 = 'BackgroundColor';
        BorderColor3 = 'OutlineColor';
    });

    local MainSectionInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Color3.new(0, 0, 0);
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, 0);
        Parent = MainSectionOuter;
    });

    Library:AddToRegistry(MainSectionInner, {
        BackgroundColor3 = 'BackgroundColor';
    });

    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 8, 0, 8);
        Size = UDim2.new(1, -16, 0, 21);
        ZIndex = 2;
        Parent = MainSectionInner;
    });

    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabArea;
    });

    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 30);
        Size = UDim2.new(1, -16, 1, -38);
        ZIndex = 1;
        Parent = MainSectionInner;
    });
    

    Library:AddToRegistry(TabContainer, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    function Window:SetWindowTitle(Title)
        WindowLabel.Text = Title;
    end;

    function Window:AddTab(Name)
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
        };

        local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, 16);

        local TabButton = Library:Create('TextButton', {
            Text = '',
            AutoButtonColor = false,
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            Size = UDim2.new(0, TabButtonWidth + 8 + 4, 1, 0);
            Parent = TabArea;
        });

        Library:AddToRegistry(TabButton, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, -1);
            Text = Name;
            ZIndex = 2;
            Parent = TabButton;
        });

        local Blocker = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 0, 1, 0);
            Size = UDim2.new(1, 0, 0, 1);
            BackgroundTransparency = 1;
            ZIndex = 1;
            Parent = TabButton;
        });

        Library:AddToRegistry(Blocker, {
            BackgroundColor3 = 'MainColor';
        });

        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame',
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            Parent = TabContainer;
        });

        local SIDE_SPACING = 7
        local sideSize = UDim2.new(0.5, -SIDE_SPACING-SIDE_SPACING//2, 1, -SIDE_SPACING*2)

        local LeftSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0, SIDE_SPACING, 0, SIDE_SPACING);
            Size = sideSize;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            Parent = TabFrame;
        });

        local RightSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, SIDE_SPACING//2, 0, SIDE_SPACING);
            Size = sideSize;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            Parent = TabFrame;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = LeftSide;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = RightSide;
        });

        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y);
            end);
        end;

        function Tab:ShowTab()
            for _, Tab in next, Window.Tabs do
                Tab:HideTab();
            end;

            Blocker.BackgroundTransparency = 0;
            TabButton.BackgroundColor3 = Library.MainColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor';
            TabFrame.Visible = true;
        end;

        function Tab:HideTab()
            Blocker.BackgroundTransparency = 1;
            TabButton.BackgroundColor3 = Library.BackgroundColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor';
            TabFrame.Visible = false;
        end;

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position;
            TabListLayout:ApplyLayout();
        end;

        function Tab:AddGroupbox(Info)
            local Groupbox = {};

            local BoxOuter = Library:Create('TextButton', {
                Text = '',
                AutoButtonColor = false,
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 507 + 2);
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                -- BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local GroupboxLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18);
                Position = UDim2.new(0, 4, 0, 2);
                TextSize = 14;
                Text = Info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                Parent = BoxInner;
            });

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 4, 0, 20);
                Size = UDim2.new(1, -4, 1, -20);
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Container;
            });

            function Groupbox:Resize()
                local Size = 0;

                for _, Element in next, Library:GetContentChildren(Groupbox.Container) do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end;
                end;

                BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
            end;

            Groupbox.Container = Container;
            setmetatable(Groupbox, BaseGroupbox);

            Groupbox:AddBlank(3);
            Groupbox:Resize();

            Tab.Groupboxes[Info.Name] = Groupbox;

            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1; Name = Name; });
        end;

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = 2; Name = Name; });
        end;

        function Tab:AddTabbox(Info)
            local Tabbox = {
                Tabs = {};
            };

            local BoxOuter = Library:Create('TextButton', {
                Text = '',
                AutoButtonColor = false,
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 0);
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                -- BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 2;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 0, 1);
                Size = UDim2.new(1, 0, 0, 18);
                ZIndex = 1;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            });

            function Tabbox:AddTab(Name)
                local Tab = {};

                local Button = Library:Create('TextButton', {
                    Text = '',
                    AutoButtonColor = false,
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Color3.new(0, 0, 0);
                    Size = UDim2.new(0.5, 0, 1, 0);
                    Parent = TabboxButtons;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0);
                    TextSize = 14;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    ZIndex = 2;
                    Parent = Button;
                });

                local Block = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor;
                    BorderSizePixel = 0;
                    Position = UDim2.new(0, 0, 1, 0);
                    Size = UDim2.new(1, 0, 0, 1);
                    Visible = false;
                    ZIndex = 1;
                    Parent = Button;
                });

                Library:AddToRegistry(Block, {
                    BackgroundColor3 = 'BackgroundColor';
                });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 4, 0, 20);
                    Size = UDim2.new(1, -4, 1, -20);
                    Visible = false;
                    Parent = BoxInner;
                });

                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                });

                function Tab:Show()
                    for _, Tab in next, Tabbox.Tabs do
                        Tab:Hide();
                    end;

                    Container.Visible = true;
                    Block.Visible = true;

                    Button.BackgroundColor3 = Library.BackgroundColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor';

                    Tab:Resize();
                end;

                function Tab:Hide()
                    Container.Visible = false;
                    Block.Visible = false;

                    Button.BackgroundColor3 = Library.MainColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor';
                end;

                function Tab:Resize()
                    local TabCount = 0;

                    for _, Tab in next, Tabbox.Tabs do
                        TabCount = TabCount + 1;
                    end;

                    for _, Button in next, Library:GetContentChildren(TabboxButtons) do
                        if not Button:IsA('UIListLayout') then
                            Button.Size = UDim2.new(1 / TabCount, 0, 1, 0);
                        end;
                    end;

                    if (not Container.Visible) then
                        return;
                    end;

                    local Size = 0;

                    for _, Element in next, Library:GetContentChildren(Tab.Container) do
                        if (not Element:IsA('UIListLayout')) and Element.Visible then
                            Size = Size + Element.Size.Y.Offset;
                        end;
                    end;

                    BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
                end;

                Button.MouseButton1Click:Connect(function()
                    if not Library:MouseIsOverOpenedFrame() then
                        Tab:Show();
                        Tab:Resize();
                    end;
                end);

                Tab.Container = Container;
                Tabbox.Tabs[Name] = Tab;

                setmetatable(Tab, BaseGroupbox);

                Tab:AddBlank(3);
                Tab:Resize();

                -- Show the first content tab; decoration instances are not tabs.
                if #Library:GetContentChildren(TabboxButtons) == 1 then
                    Tab:Show();
                end;

                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;

            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1; });
        end;

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2; });
        end;

        TabButton.MouseButton1Click:Connect(function()
            Tab:ShowTab();
        end);

        -- This was the first tab added, so we show it by default.
        if #Library:GetContentChildren(TabContainer) == 1 then
            Tab:ShowTab();
        end;

        Window.Tabs[Name] = Tab;
        return Tab;
    end;

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 0, 0);
        Visible = true;
        Text = '';
        Modal = false;
        Parent = ScreenGui;
    });

    local Toggled = false;
    local Fading = false;

    function Library:Toggle()
        if Fading then
            return;
        end;

        local FadeTime = Config.MenuFadeTime;
        Fading = true;
        Toggled = (not Toggled);
        ModalElement.Modal = Toggled;

        if Toggled then
            -- A bit scuffed, but if we're going from not toggled -> toggled we want to show the frame immediately so that the fade is visible.
            Outer.Visible = true;
        end;

        local Goals = {Size = Toggled and UDim2.fromScale(1, 1) or UDim2.fromScale(1, 0)}
        if not Library._LiquidGlassEnabled then Goals.GroupTransparency = Toggled and 0 or 1 end
        if Library._LiquidGlassEnabled and Library.LiquidGlassOptions.ReducedMotion then FadeTime = 0 end
        local tween = TweenService:Create(Inner, TweenInfo.new(FadeTime, Enum.EasingStyle.Circular), Goals)
        tween:Play()
        tween.Completed:Wait()

        Outer.Visible = Toggled;

        Fading = false;
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer;

    return Window;
end;

local function OnPlayerChange()
    local PlayerList = GetPlayersString();

    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList);
        end;
    end;
end;

Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

local Environment = getgenv and getgenv() or _G
Environment.Toggles = Toggles
Environment.Options = Options
Library.Toggles = Toggles
Library.Options = Options
return Library