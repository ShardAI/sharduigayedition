--!nonstrict
-- Canonical source. tools/sync_liquid_glass.py embeds this in Library.luau.
-- No screen capture API is assumed. See docs/LiquidGlass.md for the source contract.
local LiquidGlass = {}
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
        and source.ExcludesGlass == true and source.Opaque == true
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
            self:HideImages()
        end
        self.Stats.UpdateMilliseconds = (os.clock() - start) * 1000
    end)
    self.Connections[2] = root.Destroying:Connect(function() self:Destroy() end)
    return self
end

function Manager:HideImages()
    for _, record in ipairs(self.Records) do
        if record.Image then record.Image.Visible = false end
    end
end

function Manager:SetSourceProvider(provider)
    assert(not self.Destroyed, 'LiquidGlass manager was destroyed')
    assert(provider == nil or type(provider) == 'function', 'Source provider must be a function or nil')
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
        ScreenCaptureSupported = false, SourceRequired = true,
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
    if not LiquidGlass.ValidateSource(source) then error('Invalid LiquidGlass source frame') end
    if not self:EnsureAtlas() then return end
    buffer.fill(self.Pixels, 0, 0)
    local rendered = {}
    for _, entry in ipairs(candidates) do
        local rect, record = entry.Rect, entry.Record
        local object = record.Object
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
    self.Status = #rendered > 0 and 'SourceRefraction' or 'SourceOutOfBounds'
end

function Manager:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    while #self.Records > 0 do self:Detach(self.Records[#self.Records].Object) end
    if self.Atlas then self.Atlas:Destroy() end
    self.Atlas, self.Content, self.Pixels, self.Provider = nil, nil, nil, nil
    self.Status = 'Destroyed'
end

return LiquidGlass
