-- Deliberately small deterministic test double, NOT a Roblox rendering emulator.
local nativeTypeof = typeof
local function typeof(value)
    if type(value) == 'table' and value._type then return value._type end
    return nativeTypeof(value)
end
local Vector2 = {new = function(x, y) return {_type = 'Vector2', X = x, Y = y} end}
Vector2.zero = Vector2.new(0, 0)
local UDim = {new = function(s, o) return {Scale = s, Offset = o} end}
local UDim2 = {new = function(a, b, c, d) return {X = UDim.new(a, b), Y = UDim.new(c, d)} end}
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
local Color3 = {new = function(r, g, b) return {R = r, G = g, B = b} end}
Color3.fromRGB = function(r, g, b) return Color3.new(r/255, g/255, b/255) end
local NumberSequence = {new = function(...) return {...} end}
local NumberSequenceKeypoint = NumberSequence
local Enum = {ZIndexBehavior = {Sibling = 'Sibling', Global = 'Global'},
    ApplyStrokeMode = {Border = 'Border'}, AutomaticSize = {None = 'None'}}
local function signal()
    local event = {listeners = {}}
    function event:Connect(fn)
        local connection = {Connected = true, fn = fn}
        function connection:Disconnect() self.Connected = false end
        table.insert(self.listeners, connection)
        return connection
    end
    function event:Fire(...)
        for _, connection in ipairs(table.clone(self.listeners)) do
            if connection.Connected then connection.fn(...) end
        end
    end
    return event
end
local Instance = {}
local methods = {}
local guis = {Frame = true, TextButton = true, TextLabel = true, ImageLabel = true,
    ScrollingFrame = true, CanvasGroup = true}
function methods:IsA(class)
    return self.ClassName == class or class == 'GuiObject' and guis[self.ClassName] == true
        or class == 'UILayout' and self.ClassName == 'UIListLayout'
end
function methods:GetAttribute(name) return self._attrs[name] end
function methods:SetAttribute(name, value) self._attrs[name] = value end
function methods:GetChildren() return table.clone(self._children) end
function methods:FindFirstChildOfClass(class)
    for _, child in ipairs(self._children) do if child.ClassName == class then return child end end
end
function methods:IsDescendantOf(root)
    local node = self.Parent
    while node do if node == root then return true end; node = node.Parent end
    return false
end
function methods:Destroy()
    if self._destroyed then return end
    self.Destroying:Fire()
    self._destroyed = true
    for _, child in ipairs(self:GetChildren()) do child:Destroy() end
    self.Parent = nil
end
function Instance.new(class)
    if class == 'UIShadow' and Instance.NoShadow then error('Unknown class UIShadow') end
    local self = {_props = {ClassName = class, Name = class, Visible = true, Enabled = true,
        BackgroundTransparency = 0, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 1,
        BorderColor3 = Color3.new(0, 0, 0),
        AbsolutePosition = Vector2.zero, AbsoluteSize = Vector2.new(100, 100),
        AbsoluteRotation = 0, Rotation = 0, AutomaticSize = 'None', ZIndex = 1,
        ClipsDescendants = false, ZIndexBehavior = 'Sibling', Destroying = signal(),
        MouseEnter = signal(), MouseLeave = signal()},
        _attrs = {}, _children = {}}
    return setmetatable(self, {
        __index = function(t, k)
            -- Older engine: these properties must throw, not silently return nil.
            if k:match('^Top.*Radius$') or k:match('^Bottom.*Radius$') then error('Unknown member') end
            return methods[k] or t._props[k]
        end,
        __newindex = function(t, k, v)
            if k:sub(1, 1) == '_' then rawset(t, k, v); return end
            if k == 'Parent' then
                local old = t._props.Parent
                if old then table.remove(old._children, table.find(old._children, t)) end
                if v then table.insert(v._children, t) end
            end
            t._props[k] = v
        end,
    })
end
local heartbeat = signal()
local assets = {Allocations = 0, Writes = 0, Destroyed = 0, Deny = false}
function assets:CreateEditableImage(options)
    self.Allocations += 1
    if self.Deny then return nil end
    local img = {Size = options.Size}
    function img:WritePixelsBuffer(_, size, pixels)
        assert(size.X == self.Size.X and size.Y == self.Size.Y)
        assert(buffer.len(pixels) == size.X * size.Y * 4)
        assets.Writes += 1
        self.Pixels = buffer.create(buffer.len(pixels))
        buffer.copy(self.Pixels, 0, pixels)
    end
    function img:Destroy() assets.Destroyed += 1 end
    return img
end
local game = {GetService = function(_, name)
    if name == 'RunService' then return {Heartbeat = heartbeat} end
    if name == 'AssetService' then return assets end
    error('Unexpected service: ' .. name)
end}
local Content = {fromObject = function(object) return object end}
