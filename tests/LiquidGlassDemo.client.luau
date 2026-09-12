-- Studio: place addons/LiquidGlass as a ModuleScript named LiquidGlass beside
-- this LocalScript in StarterPlayerScripts. Enable Mesh/Image APIs if available.
-- This demo reads its OWN procedural background data, never screen pixels.
local Glass = require(script.Parent:WaitForChild('LiquidGlass'))
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local root = Instance.new('ScreenGui')
root.Name = 'ShardLiquidGlassDemo'
root.IgnoreGuiInset = true
root.ResetOnSpawn = false
root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
root.Parent = Players.LocalPlayer:WaitForChild('PlayerGui')
local background = Instance.new('Frame')
background.Size = UDim2.fromScale(1, 1)
background.BorderSizePixel = 0
background.ZIndex = 0
background.Parent = root
local stripes = {}
for i = 1, 24 do
    local stripe = Instance.new('Frame')
    stripe.BorderSizePixel = 0
    stripe.Size = UDim2.new(1 / 24, 1, 1, 0)
    stripe.Position = UDim2.fromScale((i - 1) / 24, 0)
    stripe.Parent = background
    stripes[i] = stripe
end
local manager = Glass.newManager(root, {TileSize = 128, MaxSurfaces = 4, UpdateHz = 20})
local lens = manager:Create({Name = 'MainLens', Position = UDim2.fromOffset(40, 110),
    Size = UDim2.fromOffset(320, 240), ZIndex = 2, Parent = root})
lens:SetAttribute('GlassRadius', 32)
lens:SetAttribute('GlassRefraction', 14)
local overlay = manager:Create({Name = 'NestedOverlay', Position = UDim2.fromOffset(25, 100),
    Size = UDim2.fromOffset(210, 65), ZIndex = 3, Parent = lens})
overlay:SetAttribute('GlassRadius', 22)
local second = manager:Create({Name = 'MovingLens', Position = UDim2.fromOffset(400, 140),
    Size = UDim2.fromOffset(190, 150), ZIndex = 4, Parent = root})
second:SetAttribute('GlassRadius', 28)
local function label(parent, text, size)
    local textLabel = Instance.new('TextLabel')
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextStrokeTransparency = 0.5
    textLabel.Font = Enum.Font.GothamMedium
    textLabel.TextSize = size or 18
    textLabel.TextWrapped = true
    textLabel.Size = UDim2.new(1, -20, 0, 70)
    textLabel.Position = UDim2.fromOffset(10, 8)
    textLabel.Text = text
    textLabel.Parent = parent
    return textLabel
end
label(lens, 'Source-driven lens\n(real GUI Instance)')
label(overlay, 'Thin overlay\nno second optical pass', 15)
label(second, 'Move / overlap')
local status = label(root, '', 16)
status.Size = UDim2.new(1, -20, 0, 90)
status.ZIndex = 10
local snapshot
local function updateBackground()
    local pixels = buffer.create(240 * 4)
    for i, stripe in ipairs(stripes) do
        local color = Color3.fromHSV((i / 24 + os.clock() * 0.04) % 1, 0.7, i % 2 == 0 and 0.8 or 0.4)
        stripe.BackgroundColor3 = color
        for x = (i - 1) * 10, i * 10 - 1 do
            buffer.writeu8(pixels, x * 4, math.floor(color.R * 255))
            buffer.writeu8(pixels, x * 4 + 1, math.floor(color.G * 255))
            buffer.writeu8(pixels, x * 4 + 2, math.floor(color.B * 255))
            buffer.writeu8(pixels, x * 4 + 3, 255)
        end
    end
    snapshot = {Pixels = pixels, Width = 240, Height = 1,
        Origin = background.AbsolutePosition, Size = background.AbsoluteSize,
        Opaque = true, ExcludesGlass = true}
end
manager:SetSourceProvider(function() return snapshot end)
local elapsed = 1
local connection = RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed >= 0.1 then
        elapsed = 0
        updateBackground()
        local state = manager:GetStatus()
        status.Text = 'Known procedural GUI background — NOT screen capture\n' .. state.Mode
            .. ' | surfaces: ' .. state.RenderedSurfaces .. ' | overlays: ' .. state.OverlaySurfaces
    end
end)
local tween = TweenService:Create(second, TweenInfo.new(4, Enum.EasingStyle.Sine,
    Enum.EasingDirection.InOut, -1, true), {Position = UDim2.fromOffset(280, 140)})
tween:Play()
root.Destroying:Connect(function() connection:Disconnect(); tween:Cancel(); manager:Destroy() end)
