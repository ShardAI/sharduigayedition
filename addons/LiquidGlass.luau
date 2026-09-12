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
