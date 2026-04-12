-- Shard DLC v5 - FIXED VERSION
-- All bugs corrected and modules properly implemented

local repo = 'https://raw.githubusercontent.com/ShardAI/sharduigayedition/ui-scaling-refactor-391d3/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local ContextActionService = game:GetService("ContextActionService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Utility Functions
local function SafeWaitChild(parent, name, timeout)
    timeout = timeout or 5
    local startTime = tick()
    while tick() - startTime < timeout do
        local child = parent:FindFirstChild(name)
        if child then return child end
        RunService.Heartbeat:Wait()
    end
    return nil
end

local function SafeFindFirstChild(parent, name)
    local success, result = pcall(function()
        return parent:FindFirstChild(name)
    end)
    return success and result or nil
end

local function SafeDestroy(obj)
    if obj and obj.Parent then
        pcall(function() obj:Destroy() end)
    end
end

local function GetCharacter()
    return LocalPlayer.Character
end

local function GetHumanoid()
    local char = GetCharacter()
    if char then
        return SafeFindFirstChild(char, "Humanoid")
    end
    return nil
end

local function GetHRP()
    local char = GetCharacter()
    if char then
        return SafeFindFirstChild(char, "HumanoidRootPart")
    end
    return nil
end

local function GetAllPlayers()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(list, plr)
        end
    end
    return list
end

local function GetDistance(pos1, pos2)
    if not pos1 or not pos2 then return math.huge end
    return (pos1 - pos2).Magnitude
end

local function GetClosestPlayer(range)
    range = range or math.huge
    local closest = nil
    local minDist = range
    local localHRP = GetHRP()
    if not localHRP then return nil end
    
    for _, plr in ipairs(GetAllPlayers()) do
        local char = plr.Character
        if char then
            local hrp = SafeFindFirstChild(char, "HumanoidRootPart")
            if hrp then
                local dist = GetDistance(localHRP.Position, hrp.Position)
                if dist < minDist then
                    minDist = dist
                    closest = plr
                end
            end
        end
    end
    return closest
end

-- Module State Manager
local ModuleState = {
    connections = {},
    objects = {},
    espObjects = {}
}

function ModuleState:AddConnection(moduleName, connection)
    if not self.connections[moduleName] then
        self.connections[moduleName] = {}
    end
    table.insert(self.connections[moduleName], connection)
end

function ModuleState:AddObject(moduleName, object)
    if not self.objects[moduleName] then
        self.objects[moduleName] = {}
    end
    table.insert(self.objects[moduleName], object)
end

function ModuleState:AddESPObject(object)
    table.insert(self.espObjects, object)
end

function ModuleState:ClearModule(moduleName)
    if self.connections[moduleName] then
        for _, conn in ipairs(self.connections[moduleName]) do
            pcall(function() conn:Disconnect() end)
        end
        self.connections[moduleName] = {}
    end
    
    if self.objects[moduleName] then
        for _, obj in ipairs(self.objects[moduleName]) do
            pcall(function() obj:Destroy() end)
        end
        self.objects[moduleName] = {}
    end
end

function ModuleState:ClearAllESP()
    for _, obj in ipairs(self.espObjects) do
        pcall(function() obj:Destroy() end)
    end
    self.espObjects = {}
end

function ModuleState:ClearESPForPlayer(player)
    for i = #self.espObjects, 1, -1 do
        local obj = self.espObjects[i]
        if obj and obj.Parent then
            local parentChar = obj.Parent
            while parentChar and not parentChar:IsA("Model") do
                parentChar = parentChar.Parent
            end
            if parentChar then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr.Character == parentChar and plr == player then
                        pcall(function() obj:Destroy() end)
                        table.remove(self.espObjects, i)
                        break
                    end
                end
            end
        end
    end
end

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
    ModuleState:ClearESPForPlayer(player)
end)

-- Create Window
local Window = Library:CreateWindow({
    Title = 'Shard DLC v5',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

-- Tabs
local Tabs = {
    Invis = Window:AddTab('Invis'),
    Move = Window:AddTab('Move'),
    Player = Window:AddTab('Player'),
    Combat = Window:AddTab('Combat'),
    ESP = Window:AddTab('ESP'),
    Visuals = Window:AddTab('Visuals'),
    World = Window:AddTab('World'),
    TP = Window:AddTab('TP'),
    Utils = Window:AddTab('Utils'),
    GUIHUD = Window:AddTab('GUI/HUD'),
    Menu = Window:AddTab('Menu'),
}

-- ═══════════════════════════════════════════════════
-- TAB: GUI/HUD Settings
-- ═══════════════════════════════════════════════════

local GUIHUDLeft = Tabs.GUIHUD:AddLeftGroupbox('GUI Settings')
local GUIHUDRight = Tabs.GUIHUD:AddRightGroupbox('HUD Settings')

-- UI Scale (Window only)
GUIHUDLeft:AddSlider('UIScale', {
    Text = 'UI Scale',
    Default = 1,
    Min = 0.5,
    Max = 1.5,
    Rounding = 2,
    Callback = function(Value)
        Library.SetWindowScale(Value)
    end
})

-- HUD Scale (Watermark, Keybinds, Notifications)
GUIHUDLeft:AddSlider('HUDScale', {
    Text = 'HUD Scale',
    Default = 1,
    Min = 0.5,
    Max = 1.5,
    Rounding = 2,
    Callback = function(Value)
        Library.SetHudScale(Value)
    end
})

-- Watermark Settings
GUIHUDRight:AddToggle('WatermarkEnabled', {
    Text = 'Show Watermark',
    Default = true,
    Callback = function(Value)
        Library:SetWatermarkVisibility(Value)
    end
})

-- Keybind Display Settings
GUIHUDRight:AddToggle('KeybindDisplayEnabled', {
    Text = 'Show Keybinds',
    Default = true,
    Callback = function(Value)
        Library.KeybindFrame.Visible = Value
    end
})

-- ═══════════════════════════════════════════════════
-- TAB: INVIS
-- ═══════════════════════════════════════════════════

local InvisLeft = Tabs.Invis:AddLeftGroupbox('Invisibility')
local InvisRight = Tabs.Invis:AddRightGroupbox('Settings')

-- Bypass Invis
InvisLeft:AddToggle('BypassInvis', {
    Text = 'Bypass Invis',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("BypassInvis")
        
        if Value then
            local success, err = pcall(function()
                local uniqueName = "ShardInvis_" .. tostring(LocalPlayer.UserId)
                
                local oldPlatform = Workspace:FindFirstChild(uniqueName .. "_Platform")
                if oldPlatform then oldPlatform:Destroy() end
                local oldClone = Workspace:FindFirstChild(uniqueName .. "_Clone")
                if oldClone then oldClone:Destroy() end
                
                local realChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                local realHRP = realChar:WaitForChild("HumanoidRootPart")
                local originalWalkSpeed = realChar.Humanoid.WalkSpeed
                
                local platform = Instance.new("Part")
                platform.Name = uniqueName .. "_Platform"
                platform.Anchored = true
                platform.Size = Vector3.new(50, 1, 50)
                platform.CFrame = CFrame.new(0, -150, 0)
                platform.CanCollide = true
                platform.Transparency = 1
                platform.Parent = Workspace
                ModuleState:AddObject("BypassInvis", platform)
                
                realChar.Archivable = true
                local fakeChar = realChar:Clone()
                local fakeHRP = fakeChar:WaitForChild("HumanoidRootPart")
                fakeChar.Name = uniqueName .. "_Clone"
                fakeChar.Parent = Workspace
                fakeHRP.CFrame = platform.CFrame * CFrame.new(0, 5, 0)
                ModuleState:AddObject("BypassInvis", fakeChar)
                
                local forceField = fakeChar:FindFirstChild("ForceField")
                if forceField then forceField:Destroy() end
                
                for _, v in ipairs(fakeChar:GetDescendants()) do
                    if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
                        v.Transparency = 0.7
                    end
                end
                
                realHRP.CFrame = fakeHRP.CFrame
                LocalPlayer.Character = fakeChar
                Camera.CameraSubject = fakeChar.Humanoid
                
                local platformConn = RunService.RenderStepped:Connect(function()
                    if fakeHRP and fakeHRP.Parent and platform and platform.Parent then
                        fakeHRP.CFrame = platform.CFrame * CFrame.new(0, 5, 0)
                    end
                end)
                ModuleState:AddConnection("BypassInvis", platformConn)
            end)
            
            if success then
                Library:Notify("Bypass Invis", "Activated", 2)
            else
                Library:Notify("Bypass Invis", "Error: " .. tostring(err), 2)
            end
        else
            Library:Notify("Bypass Invis", "Deactivated", 2)
        end
    end
})

-- Advanced Invis
InvisLeft:AddToggle('AdvancedInvis', {
    Text = 'Advanced Invis',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("AdvancedInvis")
        
        if Value then
            local char = GetCharacter()
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.Transparency = 1
                    elseif v:IsA("Decal") then
                        v.Transparency = 1
                    end
                end
            end
            Library:Notify("Advanced Invis", "Activated", 2)
        else
            local char = GetCharacter()
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.Transparency = 0
                    elseif v:IsA("Decal") then
                        v.Transparency = 0
                    end
                end
            end
            Library:Notify("Advanced Invis", "Deactivated", 2)
        end
    end
})

-- Semi Invis
InvisLeft:AddToggle('SemiInvis', {
    Text = 'Semi Invis',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("SemiInvis")
        
        if Value then
            local transparency = Options.SemiInvis_Amount and Options.SemiInvis_Amount.Value or 0.7
            local char = GetCharacter()
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.Transparency = transparency
                    end
                end
            end
            Library:Notify("Semi Invis", "Activated", 2)
        else
            local char = GetCharacter()
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.Transparency = 0
                    end
                end
            end
            Library:Notify("Semi Invis", "Deactivated", 2)
        end
    end
})

InvisRight:AddSlider('SemiInvis_Amount', { Text = 'Transparency', Default = 0.7, Min = 0.1, Max = 0.95, Rounding = 2 })

-- ═══════════════════════════════════════════════════
-- TAB: MOVE
-- ═══════════════════════════════════════════════════

local MoveLeft = Tabs.Move:AddLeftGroupbox('Movement')
local MoveRight = Tabs.Move:AddRightGroupbox('Settings')

-- Fly
MoveLeft:AddToggle('Fly', {
    Text = 'Fly',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("Fly")
        
        if Value then
            local hrp = GetHRP()
            if hrp then
                local bv = Instance.new("BodyVelocity")
                bv.Name = "ShardFlyVel"
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Velocity = Vector3.new(0, 0, 0)
                bv.Parent = hrp
                ModuleState:AddObject("Fly", bv)
                
                local bg = Instance.new("BodyGyro")
                bg.Name = "ShardFlyGyro"
                bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bg.P = 10000
                bg.CFrame = hrp.CFrame
                bg.Parent = hrp
                ModuleState:AddObject("Fly", bg)
                
                local speed = Options.Fly_Speed and Options.Fly_Speed.Value or 100
                local connection = RunService.RenderStepped:Connect(function()
                    local char = GetCharacter()
                    local hum = GetHumanoid()
                    local hrp = GetHRP()
                    if hrp and hum then
                        local cf = Camera.CFrame
                        local moveVec = Vector3.new(0, 0, 0)
                        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + cf.LookVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - cf.LookVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - cf.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + cf.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + Vector3.new(0, 1, 0) end
                        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec = moveVec - Vector3.new(0, 1, 0) end
                        if moveVec.Magnitude > 0 then moveVec = moveVec.Unit * speed end
                        
                        local vel = hrp:FindFirstChild("ShardFlyVel")
                        local gyro = hrp:FindFirstChild("ShardFlyGyro")
                        if vel then vel.Velocity = moveVec end
                        if gyro then gyro.CFrame = cf end
                        hum:ChangeState(Enum.HumanoidStateType.Physics)
                    end
                end)
                ModuleState:AddConnection("Fly", connection)
            end
            Library:Notify("Fly", "Activated", 2)
        else
            local hrp = GetHRP()
            if hrp then
                local vel = hrp:FindFirstChild("ShardFlyVel")
                local gyro = hrp:FindFirstChild("ShardFlyGyro")
                if vel then vel:Destroy() end
                if gyro then gyro:Destroy() end
            end
            Library:Notify("Fly", "Deactivated", 2)
        end
    end
})

MoveRight:AddSlider('Fly_Speed', { Text = 'Speed', Default = 100, Min = 10, Max = 500, Rounding = 0 })

-- Speed
MoveLeft:AddToggle('Speed', {
    Text = 'Speed',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("Speed")
        
        if Value then
            local speed = Options.Speed_Speed and Options.Speed_Speed.Value or 50
            local hum = GetHumanoid()
            if hum then
                hum.WalkSpeed = speed
                local connection = RunService.Heartbeat:Connect(function()
                    local h = GetHumanoid()
                    if h and h.WalkSpeed ~= speed then
                        h.WalkSpeed = speed
                    end
                end)
                ModuleState:AddConnection("Speed", connection)
            end
            Library:Notify("Speed", "Activated", 2)
        else
            local hum = GetHumanoid()
            if hum then
                hum.WalkSpeed = 16
            end
            Library:Notify("Speed", "Deactivated", 2)
        end
    end
})

MoveRight:AddSlider('Speed_Speed', { Text = 'Speed', Default = 50, Min = 5, Max = 500, Rounding = 0 })

-- NoClip
MoveLeft:AddToggle('NoClip', {
    Text = 'NoClip',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("NoClip")
        
        if Value then
            local connection = RunService.Stepped:Connect(function()
                local char = GetCharacter()
                if char then
                    for _, p in ipairs(char:GetDescendants()) do
                        if p:IsA("BasePart") then
                            p.CanCollide = false
                        end
                    end
                end
            end)
            ModuleState:AddConnection("NoClip", connection)
            Library:Notify("NoClip", "Activated", 2)
        else
            local char = GetCharacter()
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.CanCollide = true
                    end
                end
            end
            Library:Notify("NoClip", "Deactivated", 2)
        end
    end
})

-- Infinite Jump
MoveLeft:AddToggle('InfiniteJump', {
    Text = 'Infinite Jump',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("InfiniteJump")
        
        if Value then
            local connection = UserInputService.JumpRequest:Connect(function()
                local hum = GetHumanoid()
                if hum then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
            ModuleState:AddConnection("InfiniteJump", connection)
            Library:Notify("Infinite Jump", "Activated", 2)
        else
            Library:Notify("Infinite Jump", "Deactivated", 2)
        end
    end
})

-- Super Jump
MoveLeft:AddToggle('SuperJump', {
    Text = 'Super Jump',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("SuperJump")
        
        if Value then
            local power = Options.SuperJump_Power and Options.SuperJump_Power.Value or 100
            local hum = GetHumanoid()
            if hum then
                hum.JumpPower = power
            end
            Library:Notify("Super Jump", "Activated", 2)
        else
            local hum = GetHumanoid()
            if hum then
                hum.JumpPower = 50
            end
            Library:Notify("Super Jump", "Deactivated", 2)
        end
    end
})

MoveRight:AddSlider('SuperJump_Power', { Text = 'Jump Power', Default = 100, Min = 50, Max = 500, Rounding = 0 })

-- Click TP
MoveLeft:AddToggle('ClickTP', {
    Text = 'Click TP',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("ClickTP")
        
        if Value then
            local mouse = LocalPlayer:GetMouse()
            local connection = mouse.Button1Down:Connect(function()
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    local hrp = GetHRP()
                    if hrp then
                        hrp.CFrame = CFrame.new(mouse.Hit.X, mouse.Hit.Y + 3, mouse.Hit.Z)
                    end
                end
            end)
            ModuleState:AddConnection("ClickTP", connection)
            Library:Notify("Click TP", "Activated (Ctrl+Click)", 2)
        else
            Library:Notify("Click TP", "Deactivated", 2)
        end
    end
})

-- Spin Bot
MoveLeft:AddToggle('SpinBot', {
    Text = 'Spin Bot',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("SpinBot")
        
        if Value then
            local angle = 0
            local speed = Options.SpinBot_Speed and Options.SpinBot_Speed.Value or 30
            local connection = RunService.RenderStepped:Connect(function()
                local hrp = GetHRP()
                if hrp then
                    angle = angle + speed
                    hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(angle), 0)
                end
            end)
            ModuleState:AddConnection("SpinBot", connection)
            Library:Notify("Spin Bot", "Activated", 2)
        else
            Library:Notify("Spin Bot", "Deactivated", 2)
        end
    end
})

MoveRight:AddSlider('SpinBot_Speed', { Text = 'Spin Speed', Default = 30, Min = 5, Max = 100, Rounding = 0 })

-- Bhop
MoveLeft:AddToggle('Bhop', {
    Text = 'Bhop',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("Bhop")
        
        if Value then
            local connection = RunService.Heartbeat:Connect(function()
                local hum = GetHumanoid()
                if hum then
                    local state = hum:GetState()
                    if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end
            end)
            ModuleState:AddConnection("Bhop", connection)
            Library:Notify("Bhop", "Activated", 2)
        else
            Library:Notify("Bhop", "Deactivated", 2)
        end
    end
})

-- Low Gravity
MoveLeft:AddToggle('LowGravity', {
    Text = 'Low Gravity',
    Default = false,
    Callback = function(Value)
        if Value then
            local gravity = Options.LowGravity_Gravity and Options.LowGravity_Gravity.Value or 50
            Workspace.Gravity = gravity
            Library:Notify("Low Gravity", "Activated", 2)
        else
            Workspace.Gravity = 196.2
            Library:Notify("Low Gravity", "Deactivated", 2)
        end
    end
})

MoveRight:AddSlider('LowGravity_Gravity', { Text = 'Gravity', Default = 50, Min = 10, Max = 300, Rounding = 0 })

-- ═══════════════════════════════════════════════════
-- TAB: PLAYER
-- ═══════════════════════════════════════════════════

local PlayerLeft = Tabs.Player:AddLeftGroupbox('Player Mods')
local PlayerRight = Tabs.Player:AddRightGroupbox('Settings')

-- God Mode
PlayerLeft:AddToggle('GodMode', {
    Text = 'God Mode',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("GodMode")
        
        if Value then
            local connection = RunService.Heartbeat:Connect(function()
                local hum = GetHumanoid()
                if hum then
                    hum.Health = 1e9
                end
            end)
            ModuleState:AddConnection("GodMode", connection)
            Library:Notify("God Mode", "Activated", 2)
        else
            local hum = GetHumanoid()
            if hum then
                hum.Health = hum.MaxHealth
            end
            Library:Notify("God Mode", "Deactivated", 2)
        end
    end
})

-- Anti AFK
PlayerLeft:AddToggle('AntiAFK', {
    Text = 'Anti AFK',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("AntiAFK")
        
        if Value then
            local connection = LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
            ModuleState:AddConnection("AntiAFK", connection)
            Library:Notify("Anti AFK", "Activated", 2)
        else
            Library:Notify("Anti AFK", "Deactivated", 2)
        end
    end
})

-- FullBright
PlayerLeft:AddToggle('FullBright', {
    Text = 'FullBright',
    Default = false,
    Callback = function(Value)
        if Value then
            Lighting.Brightness = 2
            Lighting.Ambient = Color3.new(1, 1, 1)
            Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
            Lighting.GlobalShadows = false
            Library:Notify("FullBright", "Activated", 2)
        else
            Lighting.Brightness = 1
            Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
            Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
            Lighting.GlobalShadows = true
            Library:Notify("FullBright", "Deactivated", 2)
        end
    end
})

-- FPS Boost
PlayerLeft:AddToggle('FPSBoost', {
    Text = 'FPS Boost',
    Default = false,
    Callback = function(Value)
        if Value then
            settings().Rendering.QualityLevel = 1
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("PostEffect") then
                    e.Enabled = false
                end
            end
            Library:Notify("FPS Boost", "Activated", 2)
        else
            settings().Rendering.QualityLevel = 7
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("PostEffect") then
                    e.Enabled = true
                end
            end
            Library:Notify("FPS Boost", "Deactivated", 2)
        end
    end
})

-- No Fall Damage
PlayerLeft:AddToggle('NoFallDamage', {
    Text = 'No Fall Damage',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("NoFallDamage")
        
        if Value then
            local connection = RunService.Heartbeat:Connect(function()
                local hum = GetHumanoid()
                if hum then
                    local state = hum:GetState()
                    if state == Enum.HumanoidStateType.Freefall then
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
            end)
            ModuleState:AddConnection("NoFallDamage", connection)
            Library:Notify("No Fall Damage", "Activated", 2)
        else
            Library:Notify("No Fall Damage", "Deactivated", 2)
        end
    end
})

-- Custom FOV
PlayerLeft:AddToggle('CustomFOV', {
    Text = 'Custom FOV',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("CustomFOV")
        
        if Value then
            local fov = Options.CustomFOV_FOV and Options.CustomFOV_FOV.Value or 70
            local connection = RunService.Heartbeat:Connect(function()
                Camera.FieldOfView = fov
            end)
            ModuleState:AddConnection("CustomFOV", connection)
            Library:Notify("Custom FOV", "Activated", 2)
        else
            Camera.FieldOfView = 70
            Library:Notify("Custom FOV", "Deactivated", 2)
        end
    end
})

PlayerRight:AddSlider('CustomFOV_FOV', { Text = 'FOV', Default = 70, Min = 30, Max = 120, Rounding = 0 })

-- ═══════════════════════════════════════════════════
-- TAB: COMBAT
-- ═══════════════════════════════════════════════════

local CombatLeft = Tabs.Combat:AddLeftGroupbox('Combat Mods')
local CombatRight = Tabs.Combat:AddRightGroupbox('Settings')

-- Hitbox Expander
CombatLeft:AddToggle('HitboxExpander', {
    Text = 'Hitbox Expander',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("HitboxExpander")
        
        if Value then
            local size = Options.HitboxExpander_Size and Options.HitboxExpander_Size.Value or 10
            local connection = RunService.Heartbeat:Connect(function()
                for _, player in ipairs(GetAllPlayers()) do
                    local char = player.Character
                    if char then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.Size = Vector3.new(size, size, size)
                            hrp.Transparency = 0.7
                        end
                    end
                end
            end)
            ModuleState:AddConnection("HitboxExpander", connection)
            Library:Notify("Hitbox Expander", "Activated", 2)
        else
            for _, player in ipairs(GetAllPlayers()) do
                local char = player.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.Size = Vector3.new(2, 2, 1)
                        hrp.Transparency = 1
                    end
                end
            end
            Library:Notify("Hitbox Expander", "Deactivated", 2)
        end
    end
})

CombatRight:AddSlider('HitboxExpander_Size', { Text = 'Size', Default = 10, Min = 1, Max = 50, Rounding = 0 })

-- Reach
CombatLeft:AddToggle('Reach', {
    Text = 'Reach',
    Default = false,
    Callback = function(Value)
        if Value then
            local char = GetCharacter()
            if char then
                local arm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
                if arm then
                    local distance = Options.Reach_Distance and Options.Reach_Distance.Value or 15
                    arm.Size = Vector3.new(distance, 1, distance)
                end
            end
            Library:Notify("Reach", "Activated", 2)
        else
            local char = GetCharacter()
            if char then
                local arm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
                if arm then
                    arm.Size = Vector3.new(1, 2, 1)
                end
            end
            Library:Notify("Reach", "Deactivated", 2)
        end
    end
})

CombatRight:AddSlider('Reach_Distance', { Text = 'Distance', Default = 15, Min = 1, Max = 50, Rounding = 0 })

-- Kill Aura
CombatLeft:AddToggle('KillAura', {
    Text = 'Kill Aura',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("KillAura")
        
        if Value then
            local lastAttack = 0
            local range = Options.KillAura_Range and Options.KillAura_Range.Value or 10
            local damage = Options.KillAura_Damage and Options.KillAura_Damage.Value or 25
            local cooldown = Options.KillAura_Cooldown and Options.KillAura_Cooldown.Value or 0.5
            
            local connection = RunService.Heartbeat:Connect(function()
                if tick() - lastAttack < cooldown then return end
                local hrp = GetHRP()
                if hrp then
                    for _, player in ipairs(GetAllPlayers()) do
                        local char = player.Character
                        if char then
                            local targetHRP = char:FindFirstChild("HumanoidRootPart")
                            local targetHum = char:FindFirstChild("Humanoid")
                            if targetHRP and targetHum then
                                local dist = (hrp.Position - targetHRP.Position).Magnitude
                                if dist < range then
                                    targetHum:TakeDamage(damage)
                                    lastAttack = tick()
                                end
                            end
                        end
                    end
                end
            end)
            ModuleState:AddConnection("KillAura", connection)
            Library:Notify("Kill Aura", "Activated", 2)
        else
            Library:Notify("Kill Aura", "Deactivated", 2)
        end
    end
})

CombatRight:AddSlider('KillAura_Range', { Text = 'Range', Default = 10, Min = 1, Max = 50, Rounding = 0 })
CombatRight:AddSlider('KillAura_Damage', { Text = 'Damage', Default = 25, Min = 1, Max = 100, Rounding = 0 })
CombatRight:AddSlider('KillAura_Cooldown', { Text = 'Cooldown', Default = 0.5, Min = 0.1, Max = 2, Rounding = 2 })

-- Aimbot
CombatLeft:AddToggle('Aimbot', {
    Text = 'Aimbot',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("Aimbot")
        
        if Value then
            local connection = RunService.RenderStepped:Connect(function()
                if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
                
                local closest = nil
                local minDist = math.huge
                local localHRP = GetHRP()
                if not localHRP then return end
                
                local fov = Options.Aimbot_FOV and Options.Aimbot_FOV.Value or 120
                local teamCheck = Options.Aimbot_TeamCheck and Options.Aimbot_TeamCheck.Value or true
                local smoothness = Options.Aimbot_Smoothness and Options.Aimbot_Smoothness.Value or 30
                local aimPart = Options.Aimbot_AimPart and Options.Aimbot_AimPart.Value or "Head"
                
                for _, player in ipairs(GetAllPlayers()) do
                    if teamCheck and player.Team == LocalPlayer.Team then continue end
                    local char = player.Character
                    if char then
                        local targetPart = char:FindFirstChild(aimPart)
                        if targetPart then
                            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                            if onScreen then
                                local mousePos = UserInputService:GetMouseLocation()
                                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                                if dist < fov * 3 and dist < minDist then
                                    minDist = dist
                                    closest = targetPart
                                end
                            end
                        end
                    end
                end
                
                if closest then
                    local targetCFrame = CFrame.new(Camera.CFrame.Position, closest.Position)
                    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothness / 100)
                end
            end)
            ModuleState:AddConnection("Aimbot", connection)
            Library:Notify("Aimbot", "Activated (Hold RMB)", 2)
        else
            Library:Notify("Aimbot", "Deactivated", 2)
        end
    end
})

CombatRight:AddSlider('Aimbot_FOV', { Text = 'FOV', Default = 120, Min = 30, Max = 180, Rounding = 0 })
CombatRight:AddToggle('Aimbot_TeamCheck', { Text = 'Team Check', Default = true })
CombatRight:AddSlider('Aimbot_Smoothness', { Text = 'Smoothness', Default = 30, Min = 1, Max = 100, Rounding = 0 })
CombatRight:AddDropdown('Aimbot_AimPart', { Text = 'Aim Part', Values = {'Head', 'Torso', 'HumanoidRootPart'}, Default = 'Head' })

-- Punch Aura
CombatLeft:AddToggle('PunchAura', {
    Text = 'Punch Aura',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("PunchAura")
        
        if Value then
            local range = Options.PunchAura_Range and Options.PunchAura_Range.Value or 5
            local connection = RunService.Heartbeat:Connect(function()
                local hrp = GetHRP()
                if hrp then
                    for _, player in ipairs(GetAllPlayers()) do
                        local char = player.Character
                        if char then
                            local targetHRP = char:FindFirstChild("HumanoidRootPart")
                            if targetHRP then
                                local dist = (hrp.Position - targetHRP.Position).Magnitude
                                if dist < range then
                                    local myChar = GetCharacter()
                                    if myChar then
                                        for _, v in ipairs(myChar:GetChildren()) do
                                            if v:IsA("Tool") then
                                                v:Activate()
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            ModuleState:AddConnection("PunchAura", connection)
            Library:Notify("Punch Aura", "Activated", 2)
        else
            Library:Notify("Punch Aura", "Deactivated", 2)
        end
    end
})

CombatRight:AddSlider('PunchAura_Range', { Text = 'Range', Default = 5, Min = 1, Max = 10, Rounding = 0 })

-- ═══════════════════════════════════════════════════
-- TAB: ESP (FIXED)
-- ═══════════════════════════════════════════════════

local ESPLeft = Tabs.ESP:AddLeftGroupbox('ESP Modules')
local ESPRight = Tabs.ESP:AddRightGroupbox('ESP Settings')

-- ESP Master
ESPLeft:AddToggle('ESPMaster', {
    Text = 'ESP Master',
    Default = false,
    Callback = function(Value)
        if Value then
            Toggles.BoxESP:SetValue(true)
            Toggles.NameESP:SetValue(true)
            Toggles.HealthESP:SetValue(true)
            Toggles.TracerESP:SetValue(true)
            Library:Notify("ESP Master", "All ESP enabled", 2)
        else
            Toggles.BoxESP:SetValue(false)
            Toggles.NameESP:SetValue(false)
            Toggles.HealthESP:SetValue(false)
            Toggles.TracerESP:SetValue(false)
            Library:Notify("ESP Master", "All ESP disabled", 2)
        end
    end
})

-- Box ESP (FIXED)
ESPLeft:AddToggle('BoxESP', {
    Text = 'Box ESP',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("BoxESP")
        
        if Value then
            local function UpdateBoxESP()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        if Options.BoxESP_TeamCheck and Options.BoxESP_TeamCheck.Value and player.Team == LocalPlayer.Team then
                            continue
                        end
                        
                        local char = player.Character
                        if char then
                            local existing = char:FindFirstChild("ShardESPBox")
                            if not existing then
                                local highlight = Instance.new("Highlight")
                                highlight.Name = "ShardESPBox"
                                highlight.Adornee = char
                                highlight.FillColor = Options.BoxESP_FillColor and Options.BoxESP_FillColor.Value or Color3.new(0, 0.78, 1)
                                highlight.OutlineColor = Options.BoxESP_FillColor and Options.BoxESP_FillColor.Value or Color3.new(0, 0.78, 1)
                                highlight.FillTransparency = Options.BoxESP_FillTransparency and Options.BoxESP_FillTransparency.Value or 0.5
                                highlight.OutlineTransparency = 0
                                highlight.Parent = char
                                ModuleState:AddESPObject(highlight)
                            end
                        end
                    end
                end
            end
            
            local connection = RunService.Heartbeat:Connect(UpdateBoxESP)
            ModuleState:AddConnection("BoxESP", connection)
            Library:Notify("Box ESP", "Activated", 2)
        else
            Library:Notify("Box ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('BoxESP_FillColor', { Default = Color3.new(0, 0.78, 1), Title = 'Fill Color' })
ESPRight:AddSlider('BoxESP_FillTransparency', { Text = 'Fill Transparency', Default = 0.5, Min = 0, Max = 1, Rounding = 2 })
ESPRight:AddToggle('BoxESP_TeamCheck', { Text = 'Team Check', Default = false })

-- Name ESP (FIXED)
ESPLeft:AddToggle('NameESP', {
    Text = 'Name ESP',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("NameESP")
        
        if Value then
            local function UpdateNameESP()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local char = player.Character
                        if char then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp and not hrp:FindFirstChild("ShardESPName") then
                                local billboard = Instance.new("BillboardGui")
                                billboard.Name = "ShardESPName"
                                billboard.Adornee = hrp
                                billboard.Size = UDim2.new(0, 100, 0, 20)
                                billboard.StudsOffset = Vector3.new(0, 3, 0)
                                billboard.AlwaysOnTop = true
                                billboard.Parent = hrp
                                ModuleState:AddESPObject(billboard)
                                
                                local label = Instance.new("TextLabel")
                                label.Size = UDim2.new(1, 0, 1, 0)
                                label.BackgroundTransparency = 1
                                label.Text = player.DisplayName or player.Name
                                label.TextColor3 = Options.NameESP_Color and Options.NameESP_Color.Value or Color3.new(1, 1, 1)
                                label.TextSize = Options.NameESP_FontSize and Options.NameESP_FontSize.Value or 12
                                label.Font = Enum.Font.GothamBold
                                label.Parent = billboard
                            end
                        end
                    end
                end
            end
            
            local connection = RunService.Heartbeat:Connect(UpdateNameESP)
            ModuleState:AddConnection("NameESP", connection)
            Library:Notify("Name ESP", "Activated", 2)
        else
            Library:Notify("Name ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('NameESP_Color', { Default = Color3.new(1, 1, 1), Title = 'Color' })
ESPRight:AddSlider('NameESP_FontSize', { Text = 'Font Size', Default = 12, Min = 10, Max = 24, Rounding = 0 })

-- Health ESP (FIXED)
ESPLeft:AddToggle('HealthESP', {
    Text = 'Health ESP',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("HealthESP")
        
        if Value then
            local function UpdateHealthESP()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local char = player.Character
                        if char then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            local humanoid = char:FindFirstChild("Humanoid")
                            if hrp and humanoid then
                                local existing = hrp:FindFirstChild("ShardESPHealth")
                                if not existing then
                                    local billboard = Instance.new("BillboardGui")
                                    billboard.Name = "ShardESPHealth"
                                    billboard.Adornee = hrp
                                    billboard.Size = UDim2.new(0, 50, 0, 6)
                                    billboard.StudsOffset = Vector3.new(0, 4, 0)
                                    billboard.AlwaysOnTop = true
                                    billboard.Parent = hrp
                                    ModuleState:AddESPObject(billboard)
                                    
                                    local bg = Instance.new("Frame")
                                    bg.Size = UDim2.new(1, 0, 1, 0)
                                    bg.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
                                    bg.BorderSizePixel = 0
                                    bg.Parent = billboard
                                    
                                    local fill = Instance.new("Frame")
                                    fill.Name = "Fill"
                                    fill.Size = UDim2.new(humanoid.Health / humanoid.MaxHealth, 0, 1, 0)
                                    fill.BackgroundColor3 = Options.HealthESP_Color and Options.HealthESP_Color.Value or Color3.new(0, 1, 0)
                                    fill.BorderSizePixel = 0
                                    fill.Parent = bg
                                else
                                    local fill = existing:FindFirstChild("Fill")
                                    if fill then
                                        fill.Size = UDim2.new(humanoid.Health / humanoid.MaxHealth, 0, 1, 0)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            local connection = RunService.Heartbeat:Connect(UpdateHealthESP)
            ModuleState:AddConnection("HealthESP", connection)
            Library:Notify("Health ESP", "Activated", 2)
        else
            Library:Notify("Health ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('HealthESP_Color', { Default = Color3.new(0, 1, 0), Title = 'Color' })

-- Distance ESP (FIXED)
ESPLeft:AddToggle('DistanceESP', {
    Text = 'Distance ESP',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("DistanceESP")
        
        if Value then
            local function UpdateDistanceESP()
                local localHRP = GetHRP()
                if not localHRP then return end
                
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local char = player.Character
                        if char then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local existing = hrp:FindFirstChild("ShardESPDistance")
                                if not existing then
                                    local billboard = Instance.new("BillboardGui")
                                    billboard.Name = "ShardESPDistance"
                                    billboard.Adornee = hrp
                                    billboard.Size = UDim2.new(0, 60, 0, 15)
                                    billboard.StudsOffset = Vector3.new(0, 5, 0)
                                    billboard.AlwaysOnTop = true
                                    billboard.Parent = hrp
                                    ModuleState:AddESPObject(billboard)
                                    
                                    local label = Instance.new("TextLabel")
                                    label.Name = "DistanceLabel"
                                    label.Size = UDim2.new(1, 0, 1, 0)
                                    label.BackgroundTransparency = 1
                                    local dist = (localHRP.Position - hrp.Position).Magnitude
                                    label.Text = math.floor(dist) .. " studs"
                                    label.TextColor3 = Options.DistanceESP_Color and Options.DistanceESP_Color.Value or Color3.new(1, 1, 0)
                                    label.TextSize = 10
                                    label.Font = Enum.Font.Gotham
                                    label.Parent = billboard
                                else
                                    local label = existing:FindFirstChild("DistanceLabel")
                                    if label then
                                        local dist = (localHRP.Position - hrp.Position).Magnitude
                                        label.Text = math.floor(dist) .. " studs"
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            local connection = RunService.Heartbeat:Connect(UpdateDistanceESP)
            ModuleState:AddConnection("DistanceESP", connection)
            Library:Notify("Distance ESP", "Activated", 2)
        else
            Library:Notify("Distance ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('DistanceESP_Color', { Default = Color3.new(1, 1, 0), Title = 'Color' })

-- Tracer ESP (FIXED)
ESPLeft:AddToggle('TracerESP', {
    Text = 'Tracer ESP',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("TracerESP")
        
        if Value then
            local function UpdateTracerESP()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local char = player.Character
                        if char then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp and not char:FindFirstChild("ShardESPTracer") then
                                local beam = Instance.new("Beam")
                                beam.Name = "ShardESPTracer"
                                beam.Color = ColorSequence.new(Options.TracerESP_Color and Options.TracerESP_Color.Value or Color3.new(1, 1, 1))
                                beam.Width0 = Options.TracerESP_Thickness and Options.TracerESP_Thickness.Value or 0.1
                                beam.Width1 = Options.TracerESP_Thickness and Options.TracerESP_Thickness.Value or 0.1
                                beam.FaceCamera = true
                                
                                local attach0 = Instance.new("Attachment")
                                attach0.Name = "ShardTracer0"
                                attach0.WorldPosition = Camera.CFrame.Position
                                attach0.Parent = workspace.Terrain
                                
                                local attach1 = Instance.new("Attachment")
                                attach1.Name = "ShardTracer1"
                                attach1.WorldPosition = hrp.Position
                                attach1.Parent = hrp
                                
                                beam.Attachment0 = attach0
                                beam.Attachment1 = attach1
                                beam.Parent = hrp
                                
                                ModuleState:AddESPObject(beam)
                                ModuleState:AddESPObject(attach0)
                                ModuleState:AddESPObject(attach1)
                            end
                        end
                    end
                end
            end
            
            local connection = RunService.Heartbeat:Connect(UpdateTracerESP)
            ModuleState:AddConnection("TracerESP", connection)
            Library:Notify("Tracer ESP", "Activated", 2)
        else
            Library:Notify("Tracer ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('TracerESP_Color', { Default = Color3.new(1, 1, 1), Title = 'Color' })
ESPRight:AddSlider('TracerESP_Thickness', { Text = 'Thickness', Default = 0.1, Min = 0.05, Max = 0.5, Rounding = 2 })

-- Skeleton ESP (FIXED)
ESPLeft:AddToggle('SkeletonESP', {
    Text = 'Skeleton ESP',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("SkeletonESP")
        
        if Value then
            local skeletonParts = {
                {"Head", "UpperTorso"},
                {"UpperTorso", "LowerTorso"},
                {"UpperTorso", "LeftUpperArm"},
                {"LeftUpperArm", "LeftLowerArm"},
                {"LeftLowerArm", "LeftHand"},
                {"UpperTorso", "RightUpperArm"},
                {"RightUpperArm", "RightLowerArm"},
                {"RightLowerArm", "RightHand"},
                {"LowerTorso", "LeftUpperLeg"},
                {"LeftUpperLeg", "LeftLowerLeg"},
                {"LeftLowerLeg", "LeftFoot"},
                {"LowerTorso", "RightUpperLeg"},
                {"RightUpperLeg", "RightLowerLeg"},
                {"RightLowerLeg", "RightFoot"}
            }
            
            local function UpdateSkeletonESP()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local char = player.Character
                        if char then
                            for _, pair in ipairs(skeletonParts) do
                                local part0 = char:FindFirstChild(pair[1])
                                local part1 = char:FindFirstChild(pair[2])
                                if part0 and part1 then
                                    local beamName = "ShardSkeleton_" .. pair[1] .. "_" .. pair[2]
                                    if not char:FindFirstChild(beamName) then
                                        local beam = Instance.new("Beam")
                                        beam.Name = beamName
                                        beam.Color = ColorSequence.new(Options.SkeletonESP_Color and Options.SkeletonESP_Color.Value or Color3.new(1, 1, 1))
                                        beam.Width0 = Options.SkeletonESP_Thickness and Options.SkeletonESP_Thickness.Value or 0.05
                                        beam.Width1 = Options.SkeletonESP_Thickness and Options.SkeletonESP_Thickness.Value or 0.05
                                        
                                        local attach0 = Instance.new("Attachment")
                                        attach0.Parent = part0
                                        
                                        local attach1 = Instance.new("Attachment")
                                        attach1.Parent = part1
                                        
                                        beam.Attachment0 = attach0
                                        beam.Attachment1 = attach1
                                        beam.Parent = char
                                        
                                        ModuleState:AddESPObject(beam)
                                        ModuleState:AddESPObject(attach0)
                                        ModuleState:AddESPObject(attach1)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            local connection = RunService.Heartbeat:Connect(UpdateSkeletonESP)
            ModuleState:AddConnection("SkeletonESP", connection)
            Library:Notify("Skeleton ESP", "Activated", 2)
        else
            Library:Notify("Skeleton ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('SkeletonESP_Color', { Default = Color3.new(1, 1, 1), Title = 'Color' })
ESPRight:AddSlider('SkeletonESP_Thickness', { Text = 'Thickness', Default = 0.05, Min = 0.02, Max = 0.2, Rounding = 2 })

-- Chams ESP (FIXED)
ESPLeft:AddToggle('ChamsESP', {
    Text = 'Chams ESP',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("ChamsESP")
        
        if Value then
            local function UpdateChamsESP()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local char = player.Character
                        if char then
                            for _, part in ipairs(char:GetDescendants()) do
                                if part:IsA("BasePart") and not part:FindFirstChild("ShardChams") then
                                    local highlight = Instance.new("Highlight")
                                    highlight.Name = "ShardChams"
                                    highlight.Adornee = part
                                    highlight.FillColor = Options.ChamsESP_Color and Options.ChamsESP_Color.Value or Color3.new(0, 1, 0)
                                    highlight.OutlineColor = Options.ChamsESP_Color and Options.ChamsESP_Color.Value or Color3.new(0, 1, 0)
                                    highlight.FillTransparency = 0.8
                                    highlight.OutlineTransparency = 0
                                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                    highlight.Parent = part
                                    ModuleState:AddESPObject(highlight)
                                end
                            end
                        end
                    end
                end
            end
            
            local connection = RunService.Heartbeat:Connect(UpdateChamsESP)
            ModuleState:AddConnection("ChamsESP", connection)
            Library:Notify("Chams ESP", "Activated", 2)
        else
            Library:Notify("Chams ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('ChamsESP_Color', { Default = Color3.new(0, 1, 0), Title = 'Color' })

-- FOV Circle (FIXED)
ESPLeft:AddToggle('FOVCircle', {
    Text = 'FOV Circle',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("FOVCircle")
        
        if Value then
            local screenGui = Instance.new("ScreenGui")
            screenGui.Name = "ShardFOVCircle"
            screenGui.Parent = game:GetService("CoreGui")
            ModuleState:AddObject("FOVCircle", screenGui)
            
            local radius = Options.FOVCircle_Radius and Options.FOVCircle_Radius.Value or 120
            local frame = Instance.new("Frame")
            frame.Name = "Circle"
            frame.Size = UDim2.new(0, radius * 2, 0, radius * 2)
            frame.Position = UDim2.new(0.5, -radius, 0.5, -radius)
            frame.BackgroundColor3 = Options.FOVCircle_Color and Options.FOVCircle_Color.Value or Color3.new(1, 1, 1)
            frame.BackgroundTransparency = (Options.FOVCircle_Filled and Options.FOVCircle_Filled.Value) and 0.9 or 1
            frame.BorderSizePixel = Options.FOVCircle_Thickness and Options.FOVCircle_Thickness.Value or 2
            frame.BorderColor3 = Options.FOVCircle_Color and Options.FOVCircle_Color.Value or Color3.new(1, 1, 1)
            frame.Parent = screenGui
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = frame
            
            Library:Notify("FOV Circle", "Activated", 2)
        else
            Library:Notify("FOV Circle", "Deactivated", 2)
        end
    end
})

ESPRight:AddSlider('FOVCircle_Radius', { Text = 'Radius', Default = 120, Min = 30, Max = 500, Rounding = 0 })
ESPRight:AddColorPicker('FOVCircle_Color', { Default = Color3.new(1, 1, 1), Title = 'Color' })
ESPRight:AddToggle('FOVCircle_Filled', { Text = 'Filled', Default = false })
ESPRight:AddSlider('FOVCircle_Thickness', { Text = 'Thickness', Default = 2, Min = 1, Max = 5, Rounding = 0 })

-- Head Dot ESP (FIXED)
ESPLeft:AddToggle('HeadDotESP', {
    Text = 'Head Dot ESP',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("HeadDotESP")
        
        if Value then
            local screenGui = Instance.new("ScreenGui")
            screenGui.Name = "ShardHeadDotESP"
            screenGui.Parent = game:GetService("CoreGui")
            ModuleState:AddObject("HeadDotESP", screenGui)
            
            local function UpdateHeadDotESP()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local char = player.Character
                        if char then
                            local head = char:FindFirstChild("Head")
                            if head then
                                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                                if onScreen then
                                    local dotName = "HeadDot_" .. player.Name
                                    local existing = screenGui:FindFirstChild(dotName)
                                    if not existing then
                                        local dot = Instance.new("Frame")
                                        dot.Name = dotName
                                        local size = Options.HeadDotESP_Size and Options.HeadDotESP_Size.Value or 4
                                        dot.Size = UDim2.new(0, size, 0, size)
                                        dot.Position = UDim2.new(0, screenPos.X - size/2, 0, screenPos.Y - size/2)
                                        dot.BackgroundColor3 = Options.HeadDotESP_Color and Options.HeadDotESP_Color.Value or Color3.new(1, 0, 0)
                                        dot.BorderSizePixel = 0
                                        dot.Parent = screenGui
                                        
                                        local corner = Instance.new("UICorner")
                                        corner.CornerRadius = UDim.new(1, 0)
                                        corner.Parent = dot
                                    else
                                        local size = Options.HeadDotESP_Size and Options.HeadDotESP_Size.Value or 4
                                        existing.Position = UDim2.new(0, screenPos.X - size/2, 0, screenPos.Y - size/2)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            local connection = RunService.Heartbeat:Connect(UpdateHeadDotESP)
            ModuleState:AddConnection("HeadDotESP", connection)
            Library:Notify("Head Dot ESP", "Activated", 2)
        else
            Library:Notify("Head Dot ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('HeadDotESP_Color', { Default = Color3.new(1, 0, 0), Title = 'Color' })
ESPRight:AddSlider('HeadDotESP_Size', { Text = 'Size', Default = 4, Min = 2, Max = 10, Rounding = 0 })

-- ═══════════════════════════════════════════════════
-- TAB: VISUALS (FIXED)
-- ═══════════════════════════════════════════════════

local VisualsLeft = Tabs.Visuals:AddLeftGroupbox('Visual Effects')
local VisualsRight = Tabs.Visuals:AddRightGroupbox('Effect Settings')

-- Trails (FIXED)
VisualsLeft:AddToggle('Trails', {
    Text = 'Trails',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("Trails")
        
        if Value then
            local char = GetCharacter()
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local a0 = Instance.new("Attachment")
                    a0.Name = "ShardTrailsA0"
                    a0.Position = Vector3.new(0, -1, 0.5)
                    a0.Parent = hrp
                    ModuleState:AddObject("Trails", a0)
                    
                    local a1 = Instance.new("Attachment")
                    a1.Name = "ShardTrailsA1"
                    a1.Position = Vector3.new(0, -1, -0.5)
                    a1.Parent = hrp
                    ModuleState:AddObject("Trails", a1)
                    
                    local trail = Instance.new("Trail")
                    trail.Name = "ShardTrail"
                    trail.Attachment0 = a0
                    trail.Attachment1 = a1
                    trail.Color = ColorSequence.new(Options.Trails_Color and Options.Trails_Color.Value or Color3.new(0, 1, 0))
                    trail.Lifetime = Options.Trails_Lifetime and Options.Trails_Lifetime.Value or 1
                    trail.WidthScale = NumberSequence.new(Options.Trails_Size and Options.Trails_Size.Value or 0.5)
                    trail.Parent = hrp
                    ModuleState:AddObject("Trails", trail)
                end
            end
            Library:Notify("Trails", "Activated", 2)
        else
            Library:Notify("Trails", "Deactivated", 2)
        end
    end
})

VisualsRight:AddColorPicker('Trails_Color', { Default = Color3.new(0, 1, 0), Title = 'Color' })
VisualsRight:AddSlider('Trails_Lifetime', { Text = 'Lifetime', Default = 1, Min = 0.1, Max = 3, Rounding = 1 })
VisualsRight:AddSlider('Trails_Size', { Text = 'Size', Default = 0.5, Min = 0.1, Max = 2, Rounding = 1 })

-- Crown (FIXED)
VisualsLeft:AddToggle('Crown', {
    Text = 'Crown',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("Crown")
        
        if Value then
            local char = GetCharacter()
            if char then
                local head = char:FindFirstChild("Head")
                if head then
                    local crown = Instance.new("Part")
                    crown.Name = "ShardCrown"
                    crown.Size = Vector3.new(1.5, 0.3, 1.5)
                    crown.Color = Color3.new(1, 0.84, 0)
                    crown.Material = Enum.Material.Neon
                    crown.Anchored = false
                    crown.CanCollide = false
                    crown.Parent = char
                    ModuleState:AddObject("Crown", crown)
                    
                    local weld = Instance.new("Weld")
                    weld.Part0 = head
                    weld.Part1 = crown
                    weld.C0 = CFrame.new(0, 1, 0)
                    weld.Parent = crown
                    
                    for i = 1, 5 do
                        local spike = Instance.new("Part")
                        spike.Size = Vector3.new(0.1, 0.4, 0.1)
                        spike.Color = Color3.new(1, 0.84, 0)
                        spike.Material = Enum.Material.Neon
                        spike.Anchored = false
                        spike.CanCollide = false
                        spike.Parent = crown
                        ModuleState:AddObject("Crown", spike)
                        
                        local angle = (i - 1) * (math.pi * 2 / 5)
                        local spikeWeld = Instance.new("Weld")
                        spikeWeld.Part0 = crown
                        spikeWeld.Part1 = spike
                        spikeWeld.C0 = CFrame.new(math.cos(angle) * 0.6, 0.3, math.sin(angle) * 0.6)
                        spikeWeld.Parent = spike
                    end
                end
            end
            Library:Notify("Crown", "Activated", 2)
        else
            Library:Notify("Crown", "Deactivated", 2)
        end
    end
})

-- Wings (FIXED)
VisualsLeft:AddToggle('Wings', {
    Text = 'Wings',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("Wings")
        
        if Value then
            local char = GetCharacter()
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local leftWing = Instance.new("Part")
                    leftWing.Name = "ShardLeftWing"
                    leftWing.Size = Vector3.new(1.5, 2, 0.1)
                    leftWing.Color = Options.Wings_Color and Options.Wings_Color.Value or Color3.new(1, 1, 1)
                    leftWing.Material = Enum.Material.Neon
                    leftWing.Transparency = Options.Wings_Transparency and Options.Wings_Transparency.Value or 0.3
                    leftWing.Anchored = false
                    leftWing.CanCollide = false
                    leftWing.Parent = char
                    ModuleState:AddObject("Wings", leftWing)
                    
                    local leftWeld = Instance.new("Weld")
                    leftWeld.Part0 = hrp
                    leftWeld.Part1 = leftWing
                    leftWeld.C0 = CFrame.new(-1.2, 0.5, -0.5) * CFrame.Angles(0, 0, math.rad(30))
                    leftWeld.Parent = leftWing
                    
                    local rightWing = Instance.new("Part")
                    rightWing.Name = "ShardRightWing"
                    rightWing.Size = Vector3.new(1.5, 2, 0.1)
                    rightWing.Color = Options.Wings_Color and Options.Wings_Color.Value or Color3.new(1, 1, 1)
                    rightWing.Material = Enum.Material.Neon
                    rightWing.Transparency = Options.Wings_Transparency and Options.Wings_Transparency.Value or 0.3
                    rightWing.Anchored = false
                    rightWing.CanCollide = false
                    rightWing.Parent = char
                    ModuleState:AddObject("Wings", rightWing)
                    
                    local rightWeld = Instance.new("Weld")
                    rightWeld.Part0 = hrp
                    rightWeld.Part1 = rightWing
                    rightWeld.C0 = CFrame.new(1.2, 0.5, -0.5) * CFrame.Angles(0, 0, math.rad(-30))
                    rightWeld.Parent = rightWing
                end
            end
            Library:Notify("Wings", "Activated", 2)
        else
            Library:Notify("Wings", "Deactivated", 2)
        end
    end
})

VisualsRight:AddColorPicker('Wings_Color', { Default = Color3.new(1, 1, 1), Title = 'Color' })
VisualsRight:AddSlider('Wings_Transparency', { Text = 'Transparency', Default = 0.3, Min = 0, Max = 1, Rounding = 2 })

-- Aura (FIXED)
VisualsLeft:AddToggle('Aura', {
    Text = 'Aura',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("Aura")
        
        if Value then
            local char = GetCharacter()
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local aura = Instance.new("Part")
                    aura.Name = "ShardAura"
                    aura.Shape = Enum.PartType.Ball
                    aura.Size = Vector3.new(4, 4, 4)
                    aura.Color = Options.Aura_Color and Options.Aura_Color.Value or Color3.new(0, 1, 0)
                    aura.Material = Enum.Material.ForceField
                    aura.Transparency = 0.7
                    aura.Anchored = false
                    aura.CanCollide = false
                    aura.Parent = char
                    ModuleState:AddObject("Aura", aura)
                    
                    local weld = Instance.new("Weld")
                    weld.Part0 = hrp
                    weld.Part1 = aura
                    weld.Parent = aura
                    
                    local particles = Instance.new("ParticleEmitter")
                    particles.Name = "ShardAuraParticles"
                    particles.Color = ColorSequence.new(Options.Aura_Color and Options.Aura_Color.Value or Color3.new(0, 1, 0))
                    particles.Size = NumberSequence.new(0.5, 0)
                    particles.Transparency = NumberSequence.new(0, 1)
                    particles.Lifetime = NumberRange.new(1, 2)
                    particles.Rate = 50
                    particles.Speed = NumberRange.new(0.5, 1)
                    particles.Parent = aura
                    ModuleState:AddObject("Aura", particles)
                    
                    local light = Instance.new("PointLight")
                    light.Name = "ShardAuraLight"
                    light.Color = Options.Aura_Color and Options.Aura_Color.Value or Color3.new(0, 1, 0)
                    light.Brightness = Options.Aura_Brightness and Options.Aura_Brightness.Value or 5
                    light.Range = 8
                    light.Parent = aura
                    ModuleState:AddObject("Aura", light)
                end
            end
            Library:Notify("Aura", "Activated", 2)
        else
            Library:Notify("Aura", "Deactivated", 2)
        end
    end
})

VisualsRight:AddColorPicker('Aura_Color', { Default = Color3.new(0, 1, 0), Title = 'Color' })
VisualsRight:AddSlider('Aura_Brightness', { Text = 'Brightness', Default = 5, Min = 0, Max = 10, Rounding = 0 })

-- Chams (FIXED)
VisualsLeft:AddToggle('Chams', {
    Text = 'Chams',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("Chams")
        
        if Value then
            local char = GetCharacter()
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.Material = Enum.Material.Neon
                        v.Color = Options.Chams_Color and Options.Chams_Color.Value or Color3.new(0, 1, 0)
                        v.Transparency = Options.Chams_Transparency and Options.Chams_Transparency.Value or 0
                    end
                end
            end
            Library:Notify("Chams", "Activated", 2)
        else
            local char = GetCharacter()
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.Material = Enum.Material.Plastic
                    end
                end
            end
            Library:Notify("Chams", "Deactivated", 2)
        end
    end
})

VisualsRight:AddColorPicker('Chams_Color', { Default = Color3.new(0, 1, 0), Title = 'Color' })
VisualsRight:AddSlider('Chams_Transparency', { Text = 'Transparency', Default = 0, Min = 0, Max = 1, Rounding = 2 })

-- Speed Lines (FIXED)
VisualsLeft:AddToggle('SpeedLines', {
    Text = 'Speed Lines',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("SpeedLines")
        
        if Value then
            local screenGui = Instance.new("ScreenGui")
            screenGui.Name = "ShardSpeedLines"
            screenGui.Parent = game:GetService("CoreGui")
            ModuleState:AddObject("SpeedLines", screenGui)
            
            local lines = {}
            for i = 1, 10 do
                local line = Instance.new("Frame")
                line.Name = "SpeedLine" .. i
                line.Size = UDim2.new(0, math.random(50, 200), 0, 2)
                line.Position = UDim2.new(math.random(), 0, math.random(), 0)
                line.BackgroundColor3 = Color3.new(0, 0.78, 1)
                line.BackgroundTransparency = 0.5
                line.BorderSizePixel = 0
                line.Visible = false
                line.Parent = screenGui
                table.insert(lines, line)
            end
            
            local connection = RunService.Heartbeat:Connect(function()
                local hrp = GetHRP()
                if hrp then
                    local velocity = hrp.Velocity.Magnitude
                    local showLines = velocity > 30
                    for _, line in ipairs(lines) do
                        line.Visible = showLines
                        if showLines then
                            line.Position = UDim2.new(line.Position.X.Scale - 0.02, 0, line.Position.Y.Scale, 0)
                            if line.Position.X.Scale < -0.3 then
                                line.Position = UDim2.new(1.1, 0, math.random(), 0)
                            end
                        end
                    end
                end
            end)
            ModuleState:AddConnection("SpeedLines", connection)
            Library:Notify("Speed Lines", "Activated", 2)
        else
            Library:Notify("Speed Lines", "Deactivated", 2)
        end
    end
})

-- Glow Body (FIXED)
VisualsLeft:AddToggle('GlowBody', {
    Text = 'Glow Body',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("GlowBody")
        
        if Value then
            local char = GetCharacter()
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.Material = Enum.Material.ForceField
                    end
                end
            end
            Library:Notify("Glow Body", "Activated", 2)
        else
            local char = GetCharacter()
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.Material = Enum.Material.Plastic
                    end
                end
            end
            Library:Notify("Glow Body", "Deactivated", 2)
        end
    end
})

-- Rainbow Body (FIXED)
VisualsLeft:AddToggle('RainbowBody', {
    Text = 'Rainbow Body',
    Default = false,
    Callback = function(Value)
        ModuleState:ClearModule("RainbowBody")
        
        if Value then
            local hue = 0
            local connection = RunService.RenderStepped:Connect(function()
                hue = hue + 0.01
                if hue > 1 then hue = 0 end
                local char = GetCharacter()
                if char then
                    local color = Color3.fromHSV(hue, 1, 1)
                    for _, v in ipairs(char:GetDescendants()) do
                        if v:IsA("BasePart") then
                            v.Color = color
                        end
                    end
                end
            end)
            ModuleState:AddConnection("RainbowBody", connection)
            Library:Notify("Rainbow Body", "Activated", 2)
        else
            Library:Notify("Rainbow Body", "Deactivated", 2)
        end
    end
})

-- ═══════════════════════════════════════════════════
-- TAB: MENU
-- ═══════════════════════════════════════════════════

local MenuLeft = Tabs.Menu:AddLeftGroupbox('Menu Settings')
local MenuRight = Tabs.Menu:AddRightGroupbox('Configuration')

-- Unload Button
MenuLeft:AddButton('Unload', function() Library:Unload() end)

-- UI Scale
MenuLeft:AddSlider('MenuWindowScale', {
    Text = 'Window Scale',
    Default = 1,
    Min = 0.5,
    Max = 1.5,
    Rounding = 2,
    Callback = function(Value)
        Library.SetWindowScale(Value)
    end
})

-- Menu Keybind
MenuLeft:AddLabel('Menu Keybind'):AddKeyPicker('MenuKeybind', {
    Default = 'End',
    NoUI = true,
    Text = 'Menu keybind'
})

Library.ToggleKeybind = Options.MenuKeybind

-- SaveManager Setup
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
SaveManager:SetFolder('ShardDLC')
SaveManager:BuildConfigSection(Tabs.Menu)

-- ThemeManager Setup
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder('ShardDLC')
ThemeManager:ApplyToTab(Tabs.Menu)

-- Load config
SaveManager:LoadAutoloadConfig()

-- Watermark
Library:SetWatermarkVisibility(true)

local FrameTimer = tick()
local FrameCounter = 0
local FPS = 60

local WatermarkConnection = game:GetService('RunService').RenderStepped:Connect(function()
    FrameCounter = FrameCounter + 1
    
    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter
        FrameTimer = tick()
        FrameCounter = 0
    end
    
    Library:SetWatermark(('Shard DLC v5 | %s fps | %s ms'):format(
        math.floor(FPS),
        math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
    ))
end)

Library.KeybindFrame.Visible = true

-- On Unload
Library:OnUnload(function()
    -- Disconnect all module connections
    for moduleName, connections in pairs(ModuleState.connections) do
        for _, conn in ipairs(connections) do
            pcall(function() conn:Disconnect() end)
        end
    end
    
    -- Destroy all objects
    for moduleName, objects in pairs(ModuleState.objects) do
        for _, obj in ipairs(objects) do
            pcall(function() obj:Destroy() end)
        end
    end
    
    -- Clear ESP
    ModuleState:ClearAllESP()
    
    -- Disconnect watermark
    if WatermarkConnection then
        WatermarkConnection:Disconnect()
    end
    
    print('Shard DLC Unloaded!')
    Library.Unloaded = true
end)

print('Shard DLC v5 - FIXED VERSION Loaded!')
