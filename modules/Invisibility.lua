-- Invisibility Script v13.37 by sigma_maslenok26
-- Интегрировано в ShardH@ck

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local PlatformSize = Vector3.new(50, 1, 50)
local ClonePlatformPosition = Vector3.new(0, -150, 0)
local UsePlayerGui = false
local InitialCloneTransparency = 0.7
local ToggleKeybind = Enum.KeyCode.LeftAlt
local GiveTpTool = false
local EnableNoclip = true
local Cooldown = 0
local SpeedBoost = 15
local MaxDistance = 500
local EnableTeleportOnMaxDistance = true
local LockYAxisOnTeleport = true
local SendTeleportNotification = true

local Player = Players.LocalPlayer
local IYMouse = Player:GetMouse()
local UniqueName = "InvisObjects_" .. tostring(Player.UserId)
local RealCharacter, FakeCharacter, Part, q_s, PseudoAnchor
local RealHRP, FakeHRP
local Noclipping, Clip, IsInvisible, Debounce = nil, true, false, false
local diedConnection
local distanceCheckLoopActive = true

local Module = {}

local function SafeSendNotification(params)
    pcall(function()
        StarterGui:SetCore("SendNotification", params)
    end)
end

local function SyncHumanoidStates(SourceHumanoid, TargetHumanoid)
    if not SourceHumanoid or not TargetHumanoid then return end
    TargetHumanoid.WalkSpeed = SourceHumanoid.WalkSpeed
    TargetHumanoid.JumpPower = SourceHumanoid.JumpPower
    TargetHumanoid.AutoRotate = SourceHumanoid.AutoRotate
    TargetHumanoid.PlatformStand = SourceHumanoid.PlatformStand
    
    local state = SourceHumanoid:GetState()
    if state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall then
        TargetHumanoid:ChangeState(state)
    end
end

local function Invisible()
    IsInvisible = not IsInvisible
    
    if IsInvisible then
        SyncHumanoidStates(RealCharacter.Humanoid, FakeCharacter.Humanoid)
        local StoredCF = RealHRP.CFrame
        RealHRP.CFrame = FakeHRP.CFrame
        FakeHRP.CFrame = StoredCF
        Player.Character = FakeCharacter
        workspace.CurrentCamera.CameraSubject = FakeCharacter.Humanoid
        PseudoAnchor = RealHRP
        for _, v in ipairs(FakeCharacter:GetChildren()) do
            if v:IsA("LocalScript") then v.Disabled = false end
        end
    else
        SyncHumanoidStates(FakeCharacter.Humanoid, RealCharacter.Humanoid)
        local StoredCF = FakeHRP.CFrame
        FakeHRP.CFrame = RealHRP.CFrame
        RealHRP.CFrame = StoredCF
        Player.Character = RealCharacter
        workspace.CurrentCamera.CameraSubject = RealCharacter.Humanoid
        PseudoAnchor = FakeCharacter.HumanoidRootPart
        for _, v in ipairs(FakeCharacter:GetChildren()) do
            if v:IsA("LocalScript") then v.Disabled = true end
        end
    end
end

local function UpdateClonePosition()
    if not Part or not Part.Parent then return end

    local masterHRP = IsInvisible and FakeHRP or RealHRP
    if not masterHRP then return end

    local masterPos = masterHRP.Position
    local newPlatformPos
    
    if LockYAxisOnTeleport then
        newPlatformPos = Vector3.new(masterPos.X, Part.Position.Y, masterPos.Z)
    else
        newPlatformPos = Vector3.new(masterPos.X, masterPos.Y + ClonePlatformPosition.Y, masterPos.Z)
    end
    
    Part.CFrame = CFrame.new(newPlatformPos)
    
    if SendTeleportNotification then
        SafeSendNotification({
            Title = "Invisibility Script",
            Text = "Неактивный клон перемещен под вас.",
            Icon = "rbxassetid://282242329",
            Duration = 3
        })
    end
end

local function OnDied()
    if IsInvisible then
        IsInvisible = false
        Player.Character = RealCharacter
        workspace.CurrentCamera.CameraSubject = RealCharacter.Humanoid
    end
end

local function Initialize(character)
    local oldPlatform = workspace:FindFirstChild(UniqueName .. "_Platform")
    if oldPlatform then oldPlatform:Destroy() end
    local oldClone = workspace:FindFirstChild(UniqueName .. "_Clone")
    if oldClone then oldClone:Destroy() end
    
    RealCharacter = character or Player.Character or Player.CharacterAdded:Wait()
    RealHRP = RealCharacter:WaitForChild("HumanoidRootPart")
    q_s = RealCharacter.Humanoid.WalkSpeed
    
    Part = Instance.new("Part", workspace)
    Part.Name = UniqueName .. "_Platform"
    Part.Anchored = true
    Part.Size = PlatformSize
    Part.CFrame = CFrame.new(ClonePlatformPosition)
    Part.CanCollide = true
    
    RealCharacter.Archivable = true
    FakeCharacter = RealCharacter:Clone()
    FakeHRP = FakeCharacter:WaitForChild("HumanoidRootPart")
    FakeCharacter.Name = UniqueName .. "_Clone"
    FakeCharacter.Parent = workspace
    FakeCharacter.HumanoidRootPart.CFrame = Part.CFrame * CFrame.new(0, 5, 0)
    PseudoAnchor = FakeCharacter.HumanoidRootPart
    
    local forceField = FakeCharacter:FindFirstChild("ForceField")
    if forceField then forceField:Destroy() end
    
    for _, v in ipairs(RealCharacter:GetChildren()) do
        if v:IsA("LocalScript") then
            local clone = v:Clone()
            clone.Disabled = true
            clone.Parent = FakeCharacter
        end
    end
    for _, v in ipairs(FakeCharacter:GetDescendants()) do
        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
            v.Transparency = InitialCloneTransparency
        end
    end
    
    if diedConnection then diedConnection:Disconnect() end
    diedConnection = RealCharacter.Humanoid.Died:Connect(OnDied)
end

local function HandleToggle()
    if Debounce then return end
    if Cooldown > 0 then Debounce = true end

    local cameraCF = workspace.CurrentCamera.CFrame
    Invisible()
    RunService.RenderStepped:Wait()
    workspace.CurrentCamera.CFrame = cameraCF

    if EnableNoclip then
        Clip = not IsInvisible
        if not Clip then
            Noclipping = RunService.Stepped:Connect(function()
                if not Clip and Player.Character and Player.Character.HumanoidRootPart then
                    for _, child in ipairs(Player.Character:GetDescendants()) do
                        if child:IsA("BasePart") and child.CanCollide then child.CanCollide = false end
                    end
                end
            end)
        else
            if Noclipping then Noclipping:Disconnect(); Noclipping = nil end
        end
        task.wait(0)
        if Player.Character and Player.Character.Humanoid then
            Player.Character.Humanoid.WalkSpeed = not Clip and (q_s + SpeedBoost) or q_s
        end
    end
    if GiveTpTool then
        if IsInvisible then
            local TpTool = Instance.new("Tool", Player.Backpack)
            TpTool.Name = "TP tool"
            TpTool.RequiresHandle = false
            TpTool.Activated:Connect(function()
                local Char = Player.Character
                local HRP = Char and Char.HumanoidRootPart
                if not HRP then return end
                HRP.CFrame = CFrame.new(IYMouse.Hit.X, IYMouse.Hit.Y + 3, IYMouse.Hit.Z) * (HRP.CFrame - HRP.CFrame.p)
            end)
        else
            local tpTool = Player.Backpack:FindFirstChild("TP tool")
            if tpTool then tpTool:Destroy() end
        end
    end
    
    if Cooldown > 0 then
        task.wait(Cooldown)
        Debounce = false
    end
end

function Module:SetupTab(Tab)
    Tab:AddToggle("Invis_Enabled", {Text = "Invisibility Enabled", Default = false}):AddCallback(function(Value)
        if Value ~= IsInvisible then
            HandleToggle()
        end
    end)
    
    Tab:AddToggle("EnableNoclip", {Text = "Noclip", Default = true}):AddCallback(function(Value)
        EnableNoclip = Value
    end)
    
    Tab:AddToggle("GiveTpTool", {Text = "Give TP Tool", Default = false}):AddCallback(function(Value)
        GiveTpTool = Value
    end)
    
    Tab:AddSlider("SpeedBoost", {Text = "Speed Boost", Min = 0, Max = 50, Default = 15}):AddCallback(function(Value)
        SpeedBoost = Value
    end)
    
    Tab:AddSlider("MaxDistance", {Text = "Max Distance", Min = 100, Max = 1000, Default = 500}):AddCallback(function(Value)
        MaxDistance = Value
    end)
    
    Tab:AddKeyPicker("ToggleKeybind", {Text = "Toggle Keybind", Default = "LeftAlt"}):AddCallback(function(Value)
        ToggleKeybind = Value
    end)
end

function Module:Initialize()
    Initialize()
    
    RunService.RenderStepped:Connect(function()
        if PseudoAnchor and PseudoAnchor.Parent and Part and Part.Parent then
            PseudoAnchor.CFrame = Part.CFrame * CFrame.new(0, 5, 0)
        end
    end)
    
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end
        if input.KeyCode == ToggleKeybind then 
            HandleToggle() 
        end
    end)
    
    task.spawn(function()
        while distanceCheckLoopActive do
            task.wait(1)
            
            if EnableTeleportOnMaxDistance and RealHRP and FakeHRP and RealHRP.Parent and FakeHRP.Parent then
                local distance = (RealHRP.Position - FakeHRP.Position).Magnitude
                if distance > MaxDistance then
                    UpdateClonePosition()
                end
            end
        end
    end)
    
    print("Invisibility Script v13.37 Loaded.")
end

function Module:Unload()
    distanceCheckLoopActive = false
    if Noclipping then Noclipping:Disconnect() end
    if diedConnection then diedConnection:Disconnect() end
    
    if Part and Part.Parent then Part:Destroy() end
    if FakeCharacter and FakeCharacter.Parent then FakeCharacter:Destroy() end
    
    if IsInvisible then
        IsInvisible = false
        Player.Character = RealCharacter
        workspace.CurrentCamera.CameraSubject = RealCharacter.Humanoid
    end
    
    print("Invisibility Script Unloaded.")
end

return Module
