-- Manus ESP vLegendary (Alpha 2 - Optimized Build)
-- Интегрировано в ShardH@ck

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local isDrawingSupported = pcall(function() return Drawing.new end) and Drawing.new
local ESP_OBJECTS = {}
local MainESPConnection, PlayerAddedConn, PlayerRemovingConn

local SETTINGS = {
    ESP_Enabled = true,
    Chams_Enabled = true,
    Corners_Enabled = true,
    Boxes_Enabled = true,
    Tracers_Enabled = true,
    Anti_Invis_Enabled = true,

    Colors = {
        Default = Color3.fromRGB(10, 10, 122),
        Invisible = Color3.fromRGB(255, 255, 255)
    },
    Thickness = 1.5,
    Tracers_From = "Bottom",

    AntiInvis = {
        WAIT_TIMEOUT = 2,
        COLOR_SHIFT_DURATION = 0.3
    }
}

local function SetCharacterTransparency(character, transparencyValue)
    if not character then return end
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
            descendant.Transparency = transparencyValue
        end
    end
end

local function GetHeadTransparency(character)
    if not character then return nil end
    local head = character:FindFirstChild("Head")
    return head and head.Transparency
end

local function RestoreToDefaultInvisibility(container)
    local character = container.cached_char
    if not character then return end
    
    SetCharacterTransparency(character, 1)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.NameDisplayDistance = 0
    end
    container.isUnderAntiInvisControl = false
end

local function CleanupPlayer(player)
    if not ESP_OBJECTS[player] then return end
    local container = ESP_OBJECTS[player]
    
    if container.isUnderAntiInvisControl then
        RestoreToDefaultInvisibility(container)
    end

    if container.charAddedConn then container.charAddedConn:Disconnect() end
    if container.chams and container.chams.Parent then container.chams:Destroy() end
    
    if isDrawingSupported and container.drawings then
        if container.drawings.tracer then container.drawings.tracer:Destroy() end
        if container.drawings.box then
            for _, line in ipairs(container.drawings.box) do line:Destroy() end
        end
    end
    
    ESP_OBJECTS[player] = nil
end

local function FullCleanup()
    if MainESPConnection then MainESPConnection:Disconnect(); MainESPConnection = nil end
    if PlayerAddedConn then PlayerAddedConn:Disconnect(); PlayerAddedConn = nil end
    if PlayerRemovingConn then PlayerRemovingConn:Disconnect(); PlayerRemovingConn = nil end

    for player, _ in pairs(ESP_OBJECTS) do
        CleanupPlayer(player)
    end
    ESP_OBJECTS = {}
end

local function CreateESPElements(player)
    if player == LocalPlayer or ESP_OBJECTS[player] then return end
    local container = {
        chams = Instance.new("Highlight", CoreGui),
        drawings = isDrawingSupported and {tracer = Drawing.new("Line"), box = {Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line")}} or nil,
        charAddedConn = nil,
        isUnderAntiInvisControl = false,
        cached_char = nil,
        activeTween = nil
    }
    
    container.chams.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    container.chams.Enabled = false

    local function OnCharacter(character)
        container.cached_char = character
        container.chams.Adornee = character
    end

    container.charAddedConn = player.CharacterAdded:Connect(OnCharacter)
    if player.Character then OnCharacter(player.Character) end
    
    ESP_OBJECTS[player] = container
end

local function UpdateESP()
    if not SETTINGS.ESP_Enabled then
        for _, container in pairs(ESP_OBJECTS) do
            if container.isUnderAntiInvisControl then
                RestoreToDefaultInvisibility(container)
            end
            if container.chams.Enabled then container.chams.Enabled = false end
            if isDrawingSupported and container.drawings then
                container.drawings.tracer.Visible = false
                for _, line in ipairs(container.drawings.box) do line.Visible = false end
            end
        end
        return
    end

    local drawingsEnabled = isDrawingSupported and (SETTINGS.Boxes_Enabled or SETTINGS.Tracers_Enabled)

    for player, container in pairs(ESP_OBJECTS) do
        local character = player.Character
        
        if container.cached_char ~= character then
            container.cached_char = character
            container.chams.Adornee = character
        end

        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local rootPart = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
        
        if not (character and humanoid and rootPart and humanoid.Health > 0) then
            if container.chams.Enabled then container.chams.Enabled = false end
            if drawingsEnabled and container.drawings then
                container.drawings.tracer.Visible = false
                for _, line in ipairs(container.drawings.box) do line.Visible = false end
            end
            continue
        end

        local isInvisible = character:FindFirstChild("InvisibilityCloak")
        
        if SETTINGS.Anti_Invis_Enabled then
            if isInvisible and not container.isUnderAntiInvisControl then
                container.isUnderAntiInvisControl = true
                if humanoid then humanoid.NameDisplayDistance = 100 end

                spawn(function()
                    local startTime = tick()
                    while GetHeadTransparency(character) < 1 and tick() - startTime < SETTINGS.AntiInvis.WAIT_TIMEOUT do
                        if not player.Character or player.Character ~= character then return end
                        RunService.Heartbeat:Wait()
                    end
                    if GetHeadTransparency(character) >= 1 then SetCharacterTransparency(character, 0.99) end
                end)

                if container.activeTween then container.activeTween:Cancel() end
                local tweenInfo = TweenInfo.new(SETTINGS.AntiInvis.COLOR_SHIFT_DURATION, Enum.EasingStyle.Linear)
                container.activeTween = TweenService:Create(container.chams, tweenInfo, {FillColor = SETTINGS.Colors.Invisible, OutlineColor = SETTINGS.Colors.Invisible})
                container.activeTween:Play()

            elseif not isInvisible and container.isUnderAntiInvisControl then
                container.isUnderAntiInvisControl = false
                if container.activeTween then container.activeTween:Cancel() end
                local tweenInfo = TweenInfo.new(SETTINGS.AntiInvis.COLOR_SHIFT_DURATION, Enum.EasingStyle.Linear)
                container.activeTween = TweenService:Create(container.chams, tweenInfo, {FillColor = SETTINGS.Colors.Default, OutlineColor = SETTINGS.Colors.Default})
                container.activeTween:Play()
            end
        elseif container.isUnderAntiInvisControl then
             RestoreToDefaultInvisibility(container)
        end

        local chamsShouldBeEnabled = SETTINGS.Chams_Enabled or SETTINGS.Corners_Enabled
        if container.chams.Enabled ~= chamsShouldBeEnabled then
            container.chams.Enabled = chamsShouldBeEnabled
        end

        if container.chams.Enabled then
            if not container.activeTween or container.activeTween.PlaybackState == Enum.PlaybackState.Completed then
                local currentColor = (container.isUnderAntiInvisControl and SETTINGS.Colors.Invisible) or SETTINGS.Colors.Default
                container.chams.FillColor = currentColor
                container.chams.OutlineColor = currentColor
            end
            container.chams.FillTransparency = SETTINGS.Chams_Enabled and 0.6 or 1
            container.chams.OutlineTransparency = SETTINGS.Corners_Enabled and 0 or 1
        end

        if not drawingsEnabled then continue end

        local _, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
        local currentColor = container.chams.FillColor
        
        local useTracers = onScreen and SETTINGS.Tracers_Enabled
        container.drawings.tracer.Visible = useTracers
        if useTracers then
            local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            local rootPos2D = Camera:WorldToViewportPoint(rootPart.Position)
            container.drawings.tracer.From, container.drawings.tracer.To, container.drawings.tracer.Color, container.drawings.tracer.Thickness = origin, Vector2.new(rootPos2D.X, rootPos2D.Y), currentColor, SETTINGS.Thickness
        end

        local useBoxes = onScreen and SETTINGS.Boxes_Enabled
        for i=1,4 do container.drawings.box[i].Visible = false end
        
        if useBoxes then
            local cf, size = character:GetBoundingBox()
            local corners = {cf*CFrame.new(size.X/2,size.Y/2,0), cf*CFrame.new(-size.X/2,size.Y/2,0), cf*CFrame.new(-size.X/2,-size.Y/2,0), cf*CFrame.new(size.X/2,-size.Y/2,0)}
            local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
            local allOnScreen = true
            for _, corner in ipairs(corners) do local pos, vis = Camera:WorldToViewportPoint(corner.Position); if not vis then allOnScreen = false; break end; minX, minY, maxX, maxY = math.min(minX, pos.X), math.min(minY, pos.Y), math.max(maxX, pos.X), math.max(maxY, pos.Y) end
            if allOnScreen then
                for i=1,4 do container.drawings.box[i].Visible = true end
                local points = {Vector2.new(minX, minY), Vector2.new(maxX, minY), Vector2.new(maxX, maxY), Vector2.new(minX, maxY)}
                for i=1,4 do container.drawings.box[i].From, container.drawings.box[i].To, container.drawings.box[i].Color, container.drawings.box[i].Thickness = points[i], points[i % 4 + 1], currentColor, SETTINGS.Thickness end
            end
        end
    end
end

local Module = {}

function Module:SetupTab(Tab)
    Tab:AddToggle("ESP_Enabled", {Text = "ESP Enabled", Default = true}):AddCallback(function(Value)
        SETTINGS.ESP_Enabled = Value
    end)
    
    Tab:AddToggle("Chams_Enabled", {Text = "Chams", Default = true}):AddCallback(function(Value)
        SETTINGS.Chams_Enabled = Value
    end)
    
    Tab:AddToggle("Corners_Enabled", {Text = "Corners", Default = true}):AddCallback(function(Value)
        SETTINGS.Corners_Enabled = Value
    end)
    
    Tab:AddToggle("Boxes_Enabled", {Text = "Boxes", Default = true}):AddCallback(function(Value)
        SETTINGS.Boxes_Enabled = Value
    end)
    
    Tab:AddToggle("Tracers_Enabled", {Text = "Tracers", Default = true}):AddCallback(function(Value)
        SETTINGS.Tracers_Enabled = Value
    end)
    
    Tab:AddToggle("Anti_Invis_Enabled", {Text = "Anti-Invis", Default = true}):AddCallback(function(Value)
        SETTINGS.Anti_Invis_Enabled = Value
    end)
    
    Tab:AddColorPicker("ESP_Color", {Text = "ESP Color", Default = SETTINGS.Colors.Default}):AddCallback(function(Color)
        SETTINGS.Colors.Default = Color
    end)
end

function Module:Initialize()
    PlayerAddedConn = Players.PlayerAdded:Connect(CreateESPElements)
    PlayerRemovingConn = Players.PlayerRemoving:Connect(CleanupPlayer)
    MainESPConnection = RunService.RenderStepped:Connect(UpdateESP)

    for _, player in ipairs(Players:GetPlayers()) do
        CreateESPElements(player)
    end
    
    print("Manus ESP vLegendary Loaded.")
end

function Module:Unload()
    FullCleanup()
    print("Manus ESP Unloaded.")
end

return Module
