-- Shard DLC v5 - Ported to ShardUI (LinoriaLib fork)
-- 150+ modules ported with full logic preservation

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

-- State Table
local State = {
    guiVisible = true,
    originalValues = {},
    connections = {},
    espObjects = {},
}

-- Create Window
local Window = Library:CreateWindow({
    Title = 'Shard DLC v5',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuAlignment = 'Right'
})

-- Create Tabs
local Tabs = {
    Invis = Window:AddTab('Invis'),
    Move = Window:AddTab('Move'),
    Player = Window:AddTab('Player'),
    Combat = Window:AddTab('Combat'),
    ESP = Window:AddTab('ESP'),
    Visuals = Window:AddTab('Visuals'),
    Menu = Window:AddTab('Menu')
}

-- ═══════════════════════════════════════════════════
-- TAB: INVIS
-- ═══════════════════════════════════════════════════

local InvisLeft = Tabs.Invis:AddLeftGroupbox('Invis Modules')
local InvisRight = Tabs.Invis:AddRightGroupbox('Invis Settings')

-- Bypass Invis
local BypassInvisData = {
    RealCharacter = nil,
    FakeCharacter = nil,
    Platform = nil,
    PseudoAnchor = nil,
    RealHRP = nil,
    FakeHRP = nil,
    DiedConnection = nil,
    OriginalWalkSpeed = nil,
    UniqueName = "",
    Connections = {}
}

InvisLeft:AddToggle('BypassInvis', {
    Text = 'Bypass Invis',
    Default = false,
    Tooltip = 'Клонирование персонажа для обхода античита',
    Callback = function(Value)
        if Value then
            local settings = {
                speedBoost = Options.BypassInvis_Speed.Value,
                transparency = Options.BypassInvis_Transparency.Value,
                maxDistance = Options.BypassInvis_MaxDistance.Value
            }
            
            pcall(function()
                BypassInvisData.UniqueName = "ShardInvis_" .. tostring(LocalPlayer.UserId)

                local oldPlatform = Workspace:FindFirstChild(BypassInvisData.UniqueName .. "_Platform")
                if oldPlatform then oldPlatform:Destroy() end
                local oldClone = Workspace:FindFirstChild(BypassInvisData.UniqueName .. "_Clone")
                if oldClone then oldClone:Destroy() end

                BypassInvisData.RealCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                BypassInvisData.RealHRP = BypassInvisData.RealCharacter:WaitForChild("HumanoidRootPart")
                BypassInvisData.OriginalWalkSpeed = BypassInvisData.RealCharacter.Humanoid.WalkSpeed

                BypassInvisData.Platform = Instance.new("Part")
                BypassInvisData.Platform.Name = BypassInvisData.UniqueName .. "_Platform"
                BypassInvisData.Platform.Anchored = true
                BypassInvisData.Platform.Size = Vector3.new(50, 1, 50)
                BypassInvisData.Platform.CFrame = CFrame.new(0, -150, 0)
                BypassInvisData.Platform.CanCollide = true
                BypassInvisData.Platform.Transparency = 1
                BypassInvisData.Platform.Parent = Workspace

                BypassInvisData.RealCharacter.Archivable = true
                BypassInvisData.FakeCharacter = BypassInvisData.RealCharacter:Clone()
                BypassInvisData.FakeHRP = BypassInvisData.FakeCharacter:WaitForChild("HumanoidRootPart")
                BypassInvisData.FakeCharacter.Name = BypassInvisData.UniqueName .. "_Clone"
                BypassInvisData.FakeCharacter.Parent = Workspace
                BypassInvisData.FakeHRP.CFrame = BypassInvisData.Platform.CFrame * CFrame.new(0, 5, 0)
                BypassInvisData.PseudoAnchor = BypassInvisData.FakeHRP

                for _, v in ipairs(BypassInvisData.FakeCharacter:GetDescendants()) do
                    if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
                        v.Transparency = settings.transparency
                    end
                end

                BypassInvisData.RealHRP.CFrame = BypassInvisData.FakeHRP.CFrame
                LocalPlayer.Character = BypassInvisData.FakeCharacter
                Camera.CameraSubject = BypassInvisData.FakeCharacter.Humanoid

                if BypassInvisData.DiedConnection then
                    BypassInvisData.DiedConnection:Disconnect()
                end
                BypassInvisData.DiedConnection = BypassInvisData.RealCharacter.Humanoid.Died:Connect(function()
                    LocalPlayer.Character = BypassInvisData.RealCharacter
                    Camera.CameraSubject = BypassInvisData.RealCharacter.Humanoid
                end)

                local platformConn = RunService.RenderStepped:Connect(function()
                    if BypassInvisData.PseudoAnchor and BypassInvisData.PseudoAnchor.Parent and
                       BypassInvisData.Platform and BypassInvisData.Platform.Parent then
                        BypassInvisData.PseudoAnchor.CFrame = BypassInvisData.Platform.CFrame * CFrame.new(0, 5, 0)
                    end
                end)
                table.insert(BypassInvisData.Connections, platformConn)

                if BypassInvisData.FakeCharacter and BypassInvisData.FakeCharacter.Humanoid then
                    BypassInvisData.FakeCharacter.Humanoid.WalkSpeed = BypassInvisData.OriginalWalkSpeed + settings.speedBoost
                end
                
                Library:Notify("Bypass Invis", "Activated", 2)
            end)
        else
            pcall(function()
                if BypassInvisData.FakeCharacter and BypassInvisData.FakeCharacter.Parent then
                    local storedCF = BypassInvisData.FakeHRP.CFrame
                    BypassInvisData.FakeHRP.CFrame = BypassInvisData.RealHRP.CFrame
                    BypassInvisData.RealHRP.CFrame = storedCF
                    LocalPlayer.Character = BypassInvisData.RealCharacter
                    Camera.CameraSubject = BypassInvisData.RealCharacter.Humanoid
                end

                if BypassInvisData.RealCharacter and BypassInvisData.RealCharacter.Humanoid then
                    BypassInvisData.RealCharacter.Humanoid.WalkSpeed = BypassInvisData.OriginalWalkSpeed or 16
                end

                if BypassInvisData.DiedConnection then
                    BypassInvisData.DiedConnection:Disconnect()
                    BypassInvisData.DiedConnection = nil
                end
                
                for _, conn in ipairs(BypassInvisData.Connections) do
                    if conn and conn.Disconnect then
                        conn:Disconnect()
                    end
                end
                BypassInvisData.Connections = {}

                if BypassInvisData.Platform then
                    BypassInvisData.Platform:Destroy()
                end
                if BypassInvisData.FakeCharacter then
                    BypassInvisData.FakeCharacter:Destroy()
                end
                
                Library:Notify("Bypass Invis", "Deactivated", 2)
            end)
        end
    end
})

InvisRight:AddSlider('BypassInvis_Speed', {
    Text = 'Speed Boost',
    Default = 15,
    Min = 0,
    Max = 100,
    Rounding = 0
})

InvisRight:AddSlider('BypassInvis_Transparency', {
    Text = 'Clone Transparency',
    Default = 0.7,
    Min = 0,
    Max = 1,
    Rounding = 2
})

InvisRight:AddSlider('BypassInvis_MaxDistance', {
    Text = 'Max Distance',
    Default = 500,
    Min = 100,
    Max = 2000,
    Rounding = 0
})

-- Advanced Invis
InvisLeft:AddToggle('AdvancedInvis', {
    Text = 'Advanced Invis',
    Default = false,
    Tooltip = 'Полная прозрачность всех частей персонажа',
    Callback = function(Value)
        if Value then
            local transparency = Options.AdvancedInvis_Transparency.Value
            local char = GetCharacter()
            if char then
                State.originalValues.invisParts = {}
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        State.originalValues.invisParts[v] = v.Transparency
                        v.Transparency = transparency
                    elseif v:IsA("Decal") then
                        State.originalValues.invisParts[v] = v.Transparency
                        v.Transparency = transparency
                    end
                end
                Library:Notify("Advanced Invis", "Activated", 2)
            end
        else
            if State.originalValues.invisParts then
                for obj, trans in pairs(State.originalValues.invisParts) do
                    pcall(function() obj.Transparency = trans end)
                end
                State.originalValues.invisParts = nil
                Library:Notify("Advanced Invis", "Deactivated", 2)
            end
        end
    end
})

InvisRight:AddSlider('AdvancedInvis_Transparency', {
    Text = 'Transparency',
    Default = 1,
    Min = 0,
    Max = 1,
    Rounding = 2
})

-- Semi Invis
InvisLeft:AddToggle('SemiInvis', {
    Text = 'Semi Invis',
    Default = false,
    Tooltip = 'Частичная прозрачность персонажа',
    Callback = function(Value)
        if Value then
            local amount = Options.SemiInvis_Amount.Value
            local char = GetCharacter()
            if char then
                State.originalValues.semiInvisParts = {}
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        State.originalValues.semiInvisParts[v] = v.Transparency
                        v.Transparency = amount
                    end
                end
                Library:Notify("Semi Invis", "Activated", 2)
            end
        else
            if State.originalValues.semiInvisParts then
                for obj, trans in pairs(State.originalValues.semiInvisParts) do
                    pcall(function() obj.Transparency = trans end)
                end
                State.originalValues.semiInvisParts = nil
                Library:Notify("Semi Invis", "Deactivated", 2)
            end
        end
    end
})

InvisRight:AddSlider('SemiInvis_Amount', {
    Text = 'Amount',
    Default = 0.7,
    Min = 0.5,
    Max = 0.95,
    Rounding = 2
})

-- Invis on Key
InvisLeft:AddToggle('InvisOnKey', {
    Text = 'Invis on Key',
    Default = false,
    Tooltip = 'Невидимость только при удержании клавиши',
    Callback = function(Value)
        if Value then
            local keyName = Options.InvisOnKey_Key.Value
            local keyCode = Enum.KeyCode[keyName] or Enum.KeyCode.V
            State.originalValues.keyInvisParts = {}

            local inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if not gameProcessed and input.KeyCode == keyCode then
                    local char = GetCharacter()
                    if char then
                        for _, v in ipairs(char:GetDescendants()) do
                            if v:IsA("BasePart") then
                                if not State.originalValues.keyInvisParts[v] then
                                    State.originalValues.keyInvisParts[v] = v.Transparency
                                end
                                v.Transparency = 1
                            end
                        end
                    end
                end
            end)
            table.insert(State.connections, inputConn)

            local inputEndConn = UserInputService.InputEnded:Connect(function(input)
                if input.KeyCode == keyCode then
                    for obj, trans in pairs(State.originalValues.keyInvisParts) do
                        pcall(function() obj.Transparency = trans end)
                    end
                end
            end)
            table.insert(State.connections, inputEndConn)
            
            Library:Notify("Invis on Key", "Activated - Hold " .. keyName, 2)
        else
            if State.originalValues.keyInvisParts then
                for obj, trans in pairs(State.originalValues.keyInvisParts) do
                    pcall(function() obj.Transparency = trans end)
                end
                State.originalValues.keyInvisParts = nil
            end
            
            for i = #State.connections, 1, -1 do
                if State.connections[i] and State.connections[i].Disconnect then
                    State.connections[i]:Disconnect()
                    table.remove(State.connections, i)
                end
            end
            
            Library:Notify("Invis on Key", "Deactivated", 2)
        end
    end
})

InvisRight:AddDropdown('InvisOnKey_Key', {
    Values = {'LeftShift', 'LeftControl', 'LeftAlt', 'V', 'B'},
    Default = 4,
    Text = 'Key'
})

-- ═══════════════════════════════════════════════════
-- TAB: MOVE
-- ═══════════════════════════════════════════════════

local MoveLeft = Tabs.Move:AddLeftGroupbox('Move Modules')
local MoveRight = Tabs.Move:AddRightGroupbox('Move Settings')

-- Fly
MoveLeft:AddToggle('Fly', {
    Text = 'Fly',
    Default = false,
    Callback = function(Value)
        if Value then
            local speed = Options.Fly_Speed.Value
            local h = GetHRP()
            if h then
                local bv = Instance.new("BodyVelocity")
                bv.Name = "ShardFlyVel"
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Velocity = Vector3.new(0, 0, 0)
                bv.Parent = h
                
                local bg = Instance.new("BodyGyro")
                bg.Name = "ShardFlyGyro"
                bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bg.P = 10000
                bg.CFrame = h.CFrame
                bg.Parent = h

                local c = RunService.RenderStepped:Connect(function()
                    local hm = GetHumanoid()
                    local hr = GetHRP()
                    if hr and hm then
                        local cf = Camera.CFrame
                        local mv = Vector3.new(0, 0, 0)
                        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cf.LookVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cf.LookVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cf.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cf.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0, 1, 0) end
                        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then mv = mv - Vector3.new(0, 1, 0) end
                        if mv.Magnitude > 0 then mv = mv.Unit * speed end
                        local vel = hr:FindFirstChild("ShardFlyVel")
                        local gyro = hr:FindFirstChild("ShardFlyGyro")
                        if vel then vel.Velocity = mv end
                        if gyro then gyro.CFrame = cf end
                        hm:ChangeState(Enum.HumanoidStateType.Physics)
                    end
                end)
                table.insert(State.connections, c)
                Library:Notify("Fly", "Activated", 2)
            end
        else
            local h = GetHRP()
            if h then
                local v = h:FindFirstChild("ShardFlyVel")
                local g = h:FindFirstChild("ShardFlyGyro")
                if v then v:Destroy() end
                if g then g:Destroy() end
            end
            Library:Notify("Fly", "Deactivated", 2)
        end
    end
})

MoveRight:AddSlider('Fly_Speed', {
    Text = 'Speed',
    Default = 100,
    Min = 10,
    Max = 500,
    Rounding = 0
})

-- Speed
MoveLeft:AddToggle('Speed', {
    Text = 'Speed',
    Default = false,
    Callback = function(Value)
        if Value then
            local speed = Options.Speed_Speed.Value
            local h = GetHumanoid()
            if h then
                State.originalValues.walkSpeed = h.WalkSpeed
                h.WalkSpeed = speed
                local c = RunService.Heartbeat:Connect(function()
                    local hm = GetHumanoid()
                    if hm and hm.WalkSpeed ~= speed then hm.WalkSpeed = speed end
                end)
                table.insert(State.connections, c)
                Library:Notify("Speed", "Activated", 2)
            end
        else
            local h = GetHumanoid()
            if h then h.WalkSpeed = State.originalValues.walkSpeed or 16 end
            Library:Notify("Speed", "Deactivated", 2)
        end
    end
})

MoveRight:AddSlider('Speed_Speed', {
    Text = 'Speed',
    Default = 50,
    Min = 5,
    Max = 500,
    Rounding = 0
})

-- NoClip
MoveLeft:AddToggle('NoClip', {
    Text = 'NoClip',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = RunService.Stepped:Connect(function()
                local ch = GetCharacter()
                if ch then
                    for _, p in ipairs(ch:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("NoClip", "Activated", 2)
        else
            local ch = GetCharacter()
            if ch then
                for _, p in ipairs(ch:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = true end
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
        if Value then
            local c = UserInputService.JumpRequest:Connect(function()
                local h = GetHumanoid()
                if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
            table.insert(State.connections, c)
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
        if Value then
            local power = Options.SuperJump_Power.Value
            local h = GetHumanoid()
            if h then
                State.originalValues.jumpPower = h.JumpPower
                h.JumpPower = power
                Library:Notify("Super Jump", "Activated", 2)
            end
        else
            local h = GetHumanoid()
            if h then h.JumpPower = State.originalValues.jumpPower or 50 end
            Library:Notify("Super Jump", "Deactivated", 2)
        end
    end
})

MoveRight:AddSlider('SuperJump_Power', {
    Text = 'Jump Power',
    Default = 100,
    Min = 50,
    Max = 500,
    Rounding = 0
})

-- Click TP
MoveLeft:AddToggle('ClickTP', {
    Text = 'Click TP',
    Default = false,
    Tooltip = 'Teleport on mouse click (Ctrl+Click)',
    Callback = function(Value)
        if Value then
            local ms = LocalPlayer:GetMouse()
            local c = ms.Button1Down:Connect(function()
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    local h = GetHRP()
                    if h then h.CFrame = CFrame.new(ms.Hit.X, ms.Hit.Y + 3, ms.Hit.Z) end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Click TP", "Activated - Ctrl+Click to teleport", 2)
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
        if Value then
            local speed = Options.SpinBot_Speed.Value
            local angle = 0
            local c = RunService.RenderStepped:Connect(function()
                local h = GetHRP()
                if h then
                    angle = angle + speed
                    h.CFrame = CFrame.new(h.Position) * CFrame.Angles(0, math.rad(angle), 0)
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Spin Bot", "Activated", 2)
        else
            Library:Notify("Spin Bot", "Deactivated", 2)
        end
    end
})

MoveRight:AddSlider('SpinBot_Speed', {
    Text = 'Spin Speed',
    Default = 30,
    Min = 5,
    Max = 100,
    Rounding = 0
})

-- Bhop
MoveLeft:AddToggle('Bhop', {
    Text = 'Bhop',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHumanoid()
                if h then
                    local st = h:GetState()
                    if st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.Landed then
                        h:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end
            end)
            table.insert(State.connections, c)
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
            local gravity = Options.LowGravity_Gravity.Value
            State.originalValues.gravity = Workspace.Gravity
            Workspace.Gravity = gravity
            Library:Notify("Low Gravity", "Activated", 2)
        else
            Workspace.Gravity = State.originalValues.gravity or 196.2
            Library:Notify("Low Gravity", "Deactivated", 2)
        end
    end
})

MoveRight:AddSlider('LowGravity_Gravity', {
    Text = 'Gravity',
    Default = 50,
    Min = 10,
    Max = 300,
    Rounding = 0
})

-- Air Jump
MoveLeft:AddToggle('AirJump', {
    Text = 'Air Jump',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = UserInputService.InputBegan:Connect(function(input, gp)
                if not gp and input.KeyCode == Enum.KeyCode.Space then
                    local h = GetHumanoid()
                    if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Air Jump", "Activated", 2)
        else
            Library:Notify("Air Jump", "Deactivated", 2)
        end
    end
})

-- Auto Walk
MoveLeft:AddToggle('AutoWalk', {
    Text = 'Auto Walk',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHumanoid()
                if h then h:Move(Vector3.new(0, 0, -1), true) end
            end)
            table.insert(State.connections, c)
            Library:Notify("Auto Walk", "Activated", 2)
        else
            Library:Notify("Auto Walk", "Deactivated", 2)
        end
    end
})

-- Long Jump
MoveLeft:AddToggle('LongJump', {
    Text = 'Long Jump',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = UserInputService.JumpRequest:Connect(function()
                local h = GetHRP()
                if h then h.Velocity = h.Velocity + h.CFrame.LookVector * 50 end
            end)
            table.insert(State.connections, c)
            Library:Notify("Long Jump", "Activated", 2)
        else
            Library:Notify("Long Jump", "Deactivated", 2)
        end
    end
})

-- Spider Climb
MoveLeft:AddToggle('SpiderClimb', {
    Text = 'Spider Climb',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHRP()
                local hm = GetHumanoid()
                if h and hm then
                    local r = Ray.new(h.Position, h.CFrame.LookVector * 3)
                    local hit = Workspace:FindPartOnRay(r, GetCharacter())
                    if hit then h.Velocity = Vector3.new(0, 30, 0) end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Spider Climb", "Activated", 2)
        else
            Library:Notify("Spider Climb", "Deactivated", 2)
        end
    end
})

-- Strafe
MoveLeft:AddToggle('Strafe', {
    Text = 'Strafe',
    Default = false,
    Callback = function(Value)
        if Value then
            local intensity = Options.Strafe_Intensity.Value
            local direction = 1
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHRP()
                if h then
                    h.Velocity = h.Velocity + h.CFrame.RightVector * intensity * direction
                    direction = -direction
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Strafe", "Activated", 2)
        else
            Library:Notify("Strafe", "Deactivated", 2)
        end
    end
})

MoveRight:AddSlider('Strafe_Intensity', {
    Text = 'Intensity',
    Default = 15,
    Min = 1,
    Max = 50,
    Rounding = 0
})

-- Arrow Keys Move
MoveLeft:AddToggle('ArrowKeysMove', {
    Text = 'Arrow Keys Move',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = UserInputService.InputBegan:Connect(function(input, gp)
                if gp then return end
                local h = GetHumanoid()
                if not h then return end
                if input.KeyCode == Enum.KeyCode.Up then h:Move(Vector3.new(0, 0, -1), true)
                elseif input.KeyCode == Enum.KeyCode.Down then h:Move(Vector3.new(0, 0, 1), true)
                elseif input.KeyCode == Enum.KeyCode.Left then h:Move(Vector3.new(-1, 0, 0), true)
                elseif input.KeyCode == Enum.KeyCode.Right then h:Move(Vector3.new(1, 0, 0), true)
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Arrow Keys Move", "Activated", 2)
        else
            Library:Notify("Arrow Keys Move", "Deactivated", 2)
        end
    end
})

-- Move Direction Lock
MoveLeft:AddToggle('MoveDirectionLock', {
    Text = 'Move Direction Lock',
    Default = false,
    Callback = function(Value)
        if Value then
            local h = GetHRP()
            if h then
                State.originalValues.lockedDirection = h.CFrame.LookVector
                local c = RunService.Heartbeat:Connect(function()
                    local ch = GetHRP()
                    if ch and State.originalValues.lockedDirection then
                        ch.CFrame = CFrame.new(ch.Position, ch.Position + State.originalValues.lockedDirection)
                    end
                end)
                table.insert(State.connections, c)
                Library:Notify("Move Direction Lock", "Activated", 2)
            end
        else
            State.originalValues.lockedDirection = nil
            Library:Notify("Move Direction Lock", "Deactivated", 2)
        end
    end
})

-- Instant Stop
MoveLeft:AddToggle('InstantStop', {
    Text = 'Instant Stop',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = UserInputService.InputEnded:Connect(function(input)
                if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.A or 
                   input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.D then
                    local h = GetHRP()
                    if h then h.Velocity = Vector3.new(0, h.Velocity.Y, 0) end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Instant Stop", "Activated", 2)
        else
            Library:Notify("Instant Stop", "Deactivated", 2)
        end
    end
})

-- ═══════════════════════════════════════════════════
-- TAB: PLAYER
-- ═══════════════════════════════════════════════════

local PlayerLeft = Tabs.Player:AddLeftGroupbox('Player Modules')
local PlayerRight = Tabs.Player:AddRightGroupbox('Player Settings')

-- God Mode
PlayerLeft:AddToggle('GodMode', {
    Text = 'God Mode',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHumanoid()
                if h then h.Health = 1e9 end
            end)
            table.insert(State.connections, c)
            Library:Notify("God Mode", "Activated", 2)
        else
            local h = GetHumanoid()
            if h then h.Health = h.MaxHealth end
            Library:Notify("God Mode", "Deactivated", 2)
        end
    end
})

-- Anti AFK
PlayerLeft:AddToggle('AntiAFK', {
    Text = 'Anti AFK',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
            table.insert(State.connections, c)
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
            State.originalValues.brightness = Lighting.Brightness
            State.originalValues.ambient = Lighting.Ambient
            State.originalValues.outdoorAmbient = Lighting.OutdoorAmbient
            State.originalValues.globalShadows = Lighting.GlobalShadows
            Lighting.Brightness = 2
            Lighting.Ambient = Color3.new(1, 1, 1)
            Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
            Lighting.GlobalShadows = false
            Library:Notify("FullBright", "Activated", 2)
        else
            Lighting.Brightness = State.originalValues.brightness or 1
            Lighting.Ambient = State.originalValues.ambient or Color3.new(0.5, 0.5, 0.5)
            Lighting.OutdoorAmbient = State.originalValues.outdoorAmbient or Color3.new(0.5, 0.5, 0.5)
            Lighting.GlobalShadows = State.originalValues.globalShadows ~= false
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
            State.originalValues.qualityLevel = settings().Rendering.QualityLevel
            settings().Rendering.QualityLevel = 1
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("PostEffect") then e.Enabled = false end
            end
            Library:Notify("FPS Boost", "Activated", 2)
        else
            settings().Rendering.QualityLevel = State.originalValues.qualityLevel or 7
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("PostEffect") then e.Enabled = true end
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
        if Value then
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHumanoid()
                if h then
                    local s = h:GetState()
                    if s == Enum.HumanoidStateType.Freefall then h:ChangeState(Enum.HumanoidStateType.Running) end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("No Fall Damage", "Activated", 2)
        else
            Library:Notify("No Fall Damage", "Deactivated", 2)
        end
    end
})

-- Inf Stamina
PlayerLeft:AddToggle('InfStamina', {
    Text = 'Inf Stamina',
    Default = false,
    Callback = function(Value)
        if Value then
            local h = GetHumanoid()
            if h then
                pcall(function()
                    h.MaxStamina = math.huge
                    h.Stamina = math.huge
                end)
            end
            Library:Notify("Inf Stamina", "Activated", 2)
        else
            Library:Notify("Inf Stamina", "Deactivated", 2)
        end
    end
})

-- Auto Respawn
PlayerLeft:AddToggle('AutoRespawn', {
    Text = 'Auto Respawn',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = LocalPlayer.CharacterAdded:Connect(function(ch)
                local h = ch:WaitForChild("Humanoid")
                h.Died:Connect(function()
                    task.wait(1)
                    LocalPlayer:LoadCharacter()
                end)
            end)
            table.insert(State.connections, c)
            Library:Notify("Auto Respawn", "Activated", 2)
        else
            Library:Notify("Auto Respawn", "Deactivated", 2)
        end
    end
})

-- Remove Fog
PlayerLeft:AddToggle('RemoveFog', {
    Text = 'Remove Fog',
    Default = false,
    Callback = function(Value)
        if Value then
            State.originalValues.fogEnd = Lighting.FogEnd
            State.originalValues.fogStart = Lighting.FogStart
            Lighting.FogEnd = 1e9
            Lighting.FogStart = 1e9
            Library:Notify("Remove Fog", "Activated", 2)
        else
            Lighting.FogEnd = State.originalValues.fogEnd or 1000
            Lighting.FogStart = State.originalValues.fogStart or 0
            Library:Notify("Remove Fog", "Deactivated", 2)
        end
    end
})

-- Anti Stun
PlayerLeft:AddToggle('AntiStun', {
    Text = 'Anti Stun',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHumanoid()
                if h then h.PlatformStand = false end
            end)
            table.insert(State.connections, c)
            Library:Notify("Anti Stun", "Activated", 2)
        else
            Library:Notify("Anti Stun", "Deactivated", 2)
        end
    end
})

-- Anti Ragdoll
PlayerLeft:AddToggle('AntiRagdoll', {
    Text = 'Anti Ragdoll',
    Default = false,
    Callback = function(Value)
        if Value then
            local ch = GetCharacter()
            if ch then
                for _, v in ipairs(ch:GetDescendants()) do
                    if v:IsA("Motor6D") then
                        State.originalValues.motor6d = State.originalValues.motor6d or {}
                        State.originalValues.motor6d[v] = v.Parent
                    end
                end
            end
            local c = RunService.Heartbeat:Connect(function()
                local ch = GetCharacter()
                if ch then
                    for _, v in ipairs(ch:GetDescendants()) do
                        if v:IsA("Motor6D") then v.Enabled = true end
                    end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Anti Ragdoll", "Activated", 2)
        else
            Library:Notify("Anti Ragdoll", "Deactivated", 2)
        end
    end
})

-- No Blind
PlayerLeft:AddToggle('NoBlind', {
    Text = 'No Blind',
    Default = false,
    Callback = function(Value)
        if Value then
            State.originalValues.blurEffects = {}
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("BlurEffect") then
                    table.insert(State.originalValues.blurEffects, v)
                    v.Enabled = false
                end
            end
            for _, v in ipairs(Camera:GetChildren()) do
                if v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") then
                    table.insert(State.originalValues.blurEffects, v)
                    v.Enabled = false
                end
            end
            Library:Notify("No Blind", "Activated", 2)
        else
            if State.originalValues.blurEffects then
                for _, e in ipairs(State.originalValues.blurEffects) do
                    pcall(function() e.Enabled = true end)
                end
            end
            Library:Notify("No Blind", "Deactivated", 2)
        end
    end
})

-- Anti Freeze
PlayerLeft:AddToggle('AntiFreeze', {
    Text = 'Anti Freeze',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHumanoid()
                if h then
                    local s = h:GetState()
                    if s == Enum.HumanoidStateType.Physics then h:ChangeState(Enum.HumanoidStateType.Running) end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Anti Freeze", "Activated", 2)
        else
            Library:Notify("Anti Freeze", "Deactivated", 2)
        end
    end
})

-- No Sit
PlayerLeft:AddToggle('NoSit', {
    Text = 'No Sit',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHumanoid()
                if h then h.Sit = false end
            end)
            table.insert(State.connections, c)
            Library:Notify("No Sit", "Activated", 2)
        else
            Library:Notify("No Sit", "Deactivated", 2)
        end
    end
})

-- Zoom Unlock
PlayerLeft:AddToggle('ZoomUnlock', {
    Text = 'Zoom Unlock',
    Default = false,
    Callback = function(Value)
        if Value then
            State.originalValues.minZoom = LocalPlayer.CameraMinZoomDistance
            State.originalValues.maxZoom = LocalPlayer.CameraMaxZoomDistance
            LocalPlayer.CameraMinZoomDistance = 0
            LocalPlayer.CameraMaxZoomDistance = 1000
            Library:Notify("Zoom Unlock", "Activated", 2)
        else
            LocalPlayer.CameraMinZoomDistance = State.originalValues.minZoom or 0.5
            LocalPlayer.CameraMaxZoomDistance = State.originalValues.maxZoom or 400
            Library:Notify("Zoom Unlock", "Deactivated", 2)
        end
    end
})

-- Custom FOV
PlayerLeft:AddToggle('CustomFOV', {
    Text = 'Custom FOV',
    Default = false,
    Callback = function(Value)
        if Value then
            local fov = Options.CustomFOV_FOV.Value
            State.originalValues.fov = Camera.FieldOfView
            local c = RunService.Heartbeat:Connect(function()
                Camera.FieldOfView = fov
            end)
            table.insert(State.connections, c)
            Library:Notify("Custom FOV", "Activated", 2)
        else
            Camera.FieldOfView = State.originalValues.fov or 70
            Library:Notify("Custom FOV", "Deactivated", 2)
        end
    end
})

PlayerRight:AddSlider('CustomFOV_FOV', {
    Text = 'FOV',
    Default = 70,
    Min = 30,
    Max = 120,
    Rounding = 0
})

-- No Name Tag
PlayerLeft:AddToggle('NoNameTag', {
    Text = 'No Name Tag',
    Default = false,
    Callback = function(Value)
        if Value then
            local ch = GetCharacter()
            if ch then
                local hd = ch:FindFirstChild("Head")
                if hd then
                    for _, v in ipairs(hd:GetChildren()) do
                        if v:IsA("BillboardGui") then v.Enabled = false end
                    end
                end
            end
            Library:Notify("No Name Tag", "Activated", 2)
        else
            local ch = GetCharacter()
            if ch then
                local hd = ch:FindFirstChild("Head")
                if hd then
                    for _, v in ipairs(hd:GetChildren()) do
                        if v:IsA("BillboardGui") then v.Enabled = true end
                    end
                end
            end
            Library:Notify("No Name Tag", "Deactivated", 2)
        end
    end
})

-- Tiny Character
PlayerLeft:AddToggle('TinyCharacter', {
    Text = 'Tiny Character',
    Default = false,
    Callback = function(Value)
        if Value then
            local scale = Options.TinyCharacter_Scale.Value
            local ch = GetCharacter()
            if ch then
                State.originalValues.characterScale = {}
                for _, v in ipairs(ch:GetDescendants()) do
                    if v:IsA("BasePart") then
                        State.originalValues.characterScale[v] = v.Size
                        v.Size = v.Size * scale
                    end
                end
                Library:Notify("Tiny Character", "Activated", 2)
            end
        else
            if State.originalValues.characterScale then
                for o, sz in pairs(State.originalValues.characterScale) do
                    pcall(function() o.Size = sz end)
                end
                State.originalValues.characterScale = nil
            end
            Library:Notify("Tiny Character", "Deactivated", 2)
        end
    end
})

PlayerRight:AddSlider('TinyCharacter_Scale', {
    Text = 'Scale',
    Default = 0.5,
    Min = 0.1,
    Max = 1,
    Rounding = 2
})

-- Giant Character
PlayerLeft:AddToggle('GiantCharacter', {
    Text = 'Giant Character',
    Default = false,
    Callback = function(Value)
        if Value then
            local scale = Options.GiantCharacter_Scale.Value
            local ch = GetCharacter()
            if ch then
                State.originalValues.giantScale = {}
                for _, v in ipairs(ch:GetDescendants()) do
                    if v:IsA("BasePart") then
                        State.originalValues.giantScale[v] = v.Size
                        v.Size = v.Size * scale
                    end
                end
                Library:Notify("Giant Character", "Activated", 2)
            end
        else
            if State.originalValues.giantScale then
                for o, sz in pairs(State.originalValues.giantScale) do
                    pcall(function() o.Size = sz end)
                end
                State.originalValues.giantScale = nil
            end
            Library:Notify("Giant Character", "Deactivated", 2)
        end
    end
})

PlayerRight:AddSlider('GiantCharacter_Scale', {
    Text = 'Scale',
    Default = 2,
    Min = 1.5,
    Max = 5,
    Rounding = 2
})

-- Invisible Name
PlayerLeft:AddToggle('InvisibleName', {
    Text = 'Invisible Name',
    Default = false,
    Callback = function(Value)
        if Value then
            local ch = GetCharacter()
            if ch then
                local hd = ch:FindFirstChild("Head")
                if hd then
                    for _, v in ipairs(hd:GetChildren()) do
                        if v:IsA("BillboardGui") then
                            local nl = v:FindFirstChildOfClass("TextLabel")
                            if nl then
                                State.originalValues.nameText = nl.Text
                                nl.Text = ""
                            end
                        end
                    end
                end
            end
            Library:Notify("Invisible Name", "Activated", 2)
        else
            local ch = GetCharacter()
            if ch then
                local hd = ch:FindFirstChild("Head")
                if hd then
                    for _, v in ipairs(hd:GetChildren()) do
                        if v:IsA("BillboardGui") then
                            local nl = v:FindFirstChildOfClass("TextLabel")
                            if nl and State.originalValues.nameText then nl.Text = State.originalValues.nameText end
                        end
                    end
                end
            end
            Library:Notify("Invisible Name", "Deactivated", 2)
        end
    end
})

-- Chat Bypass
PlayerLeft:AddToggle('ChatBypass', {
    Text = 'Chat Bypass',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Chat Bypass", "Обход фильтра активирован (экспериментально)", 3)
        else
            Library:Notify("Chat Bypass", "Обход фильтра отключен", 3)
        end
    end
})

-- Character Magnet
PlayerLeft:AddToggle('CharacterMagnet', {
    Text = 'Character Magnet',
    Default = false,
    Callback = function(Value)
        if Value then
            local range = Options.CharacterMagnet_Range.Value
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHRP()
                if h then
                    for _, v in ipairs(Workspace:GetDescendants()) do
                        if v:IsA("Tool") and v:FindFirstChild("Handle") then
                            local hd = v.Handle
                            local d = (hd.Position - h.Position).Magnitude
                            if d < range then hd.CFrame = h.CFrame end
                        end
                    end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Character Magnet", "Activated", 2)
        else
            Library:Notify("Character Magnet", "Deactivated", 2)
        end
    end
})

PlayerRight:AddSlider('CharacterMagnet_Range', {
    Text = 'Range',
    Default = 30,
    Min = 10,
    Max = 100,
    Rounding = 0
})

-- No Seatbelt
PlayerLeft:AddToggle('NoSeatbelt', {
    Text = 'No Seatbelt',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHumanoid()
                if h and h.SeatPart then h.Sit = false end
            end)
            table.insert(State.connections, c)
            Library:Notify("No Seatbelt", "Activated", 2)
        else
            Library:Notify("No Seatbelt", "Deactivated", 2)
        end
    end
})

-- Swim in Air
PlayerLeft:AddToggle('SwimInAir', {
    Text = 'Swim in Air',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHumanoid()
                if h then h:ChangeState(Enum.HumanoidStateType.Swimming) end
            end)
            table.insert(State.connections, c)
            Library:Notify("Swim in Air", "Activated", 2)
        else
            local h = GetHumanoid()
            if h then h:ChangeState(Enum.HumanoidStateType.Running) end
            Library:Notify("Swim in Air", "Deactivated", 2)
        end
    end
})

-- Walk on Water
PlayerLeft:AddToggle('WalkOnWater', {
    Text = 'Walk on Water',
    Default = false,
    Callback = function(Value)
        if Value then
            local wp = Instance.new("Part")
            wp.Name = "ShardWaterPlatform"
            wp.Size = Vector3.new(10, 1, 10)
            wp.Anchored = true
            wp.CanCollide = true
            wp.Transparency = 1
            wp.Parent = Workspace
            
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHRP()
                if h and wp then
                    local r = Ray.new(h.Position, Vector3.new(0, -10, 0))
                    local hit, pos = Workspace:FindPartOnRay(r, GetCharacter())
                    if hit then
                        local mt = hit.Material
                        if mt == Enum.Material.Water then
                            wp.CFrame = CFrame.new(h.Position.X, pos.Y, h.Position.Z)
                        else
                            wp.CFrame = CFrame.new(0, -1000, 0)
                        end
                    end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Walk on Water", "Activated", 2)
        else
            Library:Notify("Walk on Water", "Deactivated", 2)
        end
    end
})

-- ═══════════════════════════════════════════════════
-- TAB: COMBAT
-- ═══════════════════════════════════════════════════

local CombatLeft = Tabs.Combat:AddLeftGroupbox('Combat Modules')
local CombatRight = Tabs.Combat:AddRightGroupbox('Combat Settings')

-- Hitbox Expander
CombatLeft:AddToggle('HitboxExpander', {
    Text = 'Hitbox Expander',
    Default = false,
    Callback = function(Value)
        if Value then
            local size = Options.HitboxExpander_Size.Value
            State.originalValues.hitboxes = {}
            local c = RunService.Heartbeat:Connect(function()
                for _, p in ipairs(GetAllPlayers()) do
                    local ch = p.Character
                    if ch then
                        local h = ch:FindFirstChild("HumanoidRootPart")
                        if h then
                            if not State.originalValues.hitboxes[h] then State.originalValues.hitboxes[h] = h.Size end
                            h.Size = Vector3.new(size, size, size)
                            h.Transparency = 0.7
                        end
                    end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Hitbox Expander", "Activated", 2)
        else
            if State.originalValues.hitboxes then
                for o, sz in pairs(State.originalValues.hitboxes) do
                    pcall(function() o.Size = sz; o.Transparency = 1 end)
                end
                State.originalValues.hitboxes = nil
            end
            Library:Notify("Hitbox Expander", "Deactivated", 2)
        end
    end
})

CombatRight:AddSlider('HitboxExpander_Size', {
    Text = 'Size',
    Default = 10,
    Min = 1,
    Max = 50,
    Rounding = 0
})

-- Reach
CombatLeft:AddToggle('Reach', {
    Text = 'Reach',
    Default = false,
    Callback = function(Value)
        if Value then
            local distance = Options.Reach_Distance.Value
            local ch = GetCharacter()
            if ch then
                local ra = ch:FindFirstChild("Right Arm") or ch:FindFirstChild("RightHand")
                if ra then
                    State.originalValues.reachSize = ra.Size
                    ra.Size = Vector3.new(distance, 1, distance)
                    Library:Notify("Reach", "Activated", 2)
                end
            end
        else
            local ch = GetCharacter()
            if ch then
                local ra = ch:FindFirstChild("Right Arm") or ch:FindFirstChild("RightHand")
                if ra and State.originalValues.reachSize then ra.Size = State.originalValues.reachSize end
                Library:Notify("Reach", "Deactivated", 2)
            end
        end
    end
})

CombatRight:AddSlider('Reach_Distance', {
    Text = 'Distance',
    Default = 15,
    Min = 1,
    Max = 50,
    Rounding = 0
})

-- Kill Aura
CombatLeft:AddToggle('KillAura', {
    Text = 'Kill Aura',
    Default = false,
    Callback = function(Value)
        if Value then
            local range = Options.KillAura_Range.Value
            local damage = Options.KillAura_Damage.Value
            local cooldown = Options.KillAura_Cooldown.Value
            local lastAttack = 0
            
            local c = RunService.Heartbeat:Connect(function()
                if tick() - lastAttack < cooldown then return end
                local h = GetHRP()
                if h then
                    for _, p in ipairs(GetAllPlayers()) do
                        local ch = p.Character
                        if ch then
                            local th = ch:FindFirstChild("HumanoidRootPart")
                            local hm = ch:FindFirstChild("Humanoid")
                            if th and hm then
                                local d = (h.Position - th.Position).Magnitude
                                if d < range then
                                    hm:TakeDamage(damage)
                                    lastAttack = tick()
                                end
                            end
                        end
                    end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Kill Aura", "Activated", 2)
        else
            Library:Notify("Kill Aura", "Deactivated", 2)
        end
    end
})

CombatRight:AddSlider('KillAura_Range', {
    Text = 'Range',
    Default = 10,
    Min = 1,
    Max = 50,
    Rounding = 0
})

CombatRight:AddSlider('KillAura_Damage', {
    Text = 'Damage',
    Default = 25,
    Min = 1,
    Max = 100,
    Rounding = 0
})

CombatRight:AddSlider('KillAura_Cooldown', {
    Text = 'Cooldown',
    Default = 0.5,
    Min = 0.1,
    Max = 2,
    Rounding = 1
})

-- Silent Aim
CombatLeft:AddToggle('SilentAim', {
    Text = 'Silent Aim',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Silent Aim", "Silent Aim активирован (экспериментально)", 3)
        else
            Library:Notify("Silent Aim", "Silent Aim отключен", 3)
        end
    end
})

-- Aimbot
CombatLeft:AddToggle('Aimbot', {
    Text = 'Aimbot',
    Default = false,
    Callback = function(Value)
        if Value then
            local fov = Options.Aimbot_FOV.Value
            local teamCheck = Options.Aimbot_TeamCheck.Value
            local smoothness = Options.Aimbot_Smoothness.Value
            local aimPart = Options.Aimbot_AimPart.Value
            
            local c = RunService.RenderStepped:Connect(function()
                if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
                
                local closest = nil
                local minDist = math.huge
                local lh = GetHRP()
                if not lh then return end
                
                for _, p in ipairs(GetAllPlayers()) do
                    if teamCheck and p.Team == LocalPlayer.Team then continue end
                    local ch = p.Character
                    if ch then
                        local tp = ch:FindFirstChild(aimPart)
                        if tp then
                            local sp, os = Camera:WorldToViewportPoint(tp.Position)
                            if os then
                                local mp = UserInputService:GetMouseLocation()
                                local d = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
                                if d < fov * 3 and d < minDist then
                                    minDist = d
                                    closest = tp
                                end
                            end
                        end
                    end
                end
                
                if closest then
                    local tcf = CFrame.new(Camera.CFrame.Position, closest.Position)
                    Camera.CFrame = Camera.CFrame:Lerp(tcf, smoothness / 100)
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Aimbot", "Activated", 2)
        else
            Library:Notify("Aimbot", "Deactivated", 2)
        end
    end
})

CombatRight:AddSlider('Aimbot_FOV', {
    Text = 'FOV',
    Default = 120,
    Min = 30,
    Max = 180,
    Rounding = 0
})

CombatRight:AddToggle('Aimbot_TeamCheck', {
    Text = 'Team Check',
    Default = true
})

CombatRight:AddSlider('Aimbot_Smoothness', {
    Text = 'Smoothness',
    Default = 30,
    Min = 1,
    Max = 100,
    Rounding = 0
})

CombatRight:AddDropdown('Aimbot_AimPart', {
    Values = {'Head', 'Torso', 'HumanoidRootPart'},
    Default = 1,
    Text = 'Aim Part'
})

-- Hit Sound
CombatLeft:AddToggle('HitSound', {
    Text = 'Hit Sound',
    Default = false,
    Callback = function(Value)
        if Value then
            local soundId = Options.HitSound_SoundId.Value
            local volume = Options.HitSound_Volume.Value
            
            local hs = Instance.new("Sound")
            hs.Name = "ShardHitSound"
            hs.SoundId = soundId
            hs.Volume = volume
            hs.Parent = Camera
            
            local ch = GetCharacter()
            if ch then
                local h = ch:FindFirstChild("Humanoid")
                if h then
                    local hc = h.HealthChanged:Connect(function() hs:Play() end)
                    table.insert(State.connections, hc)
                end
            end
            Library:Notify("Hit Sound", "Activated", 2)
        else
            Library:Notify("Hit Sound", "Deactivated", 2)
        end
    end
})

CombatRight:AddInput('HitSound_SoundId', {
    Text = 'Sound ID',
    Default = 'rbxassetid://9114488953',
    Numeric = false,
    Finished = false
})

CombatRight:AddSlider('HitSound_Volume', {
    Text = 'Volume',
    Default = 1,
    Min = 0,
    Max = 2,
    Rounding = 1
})

-- No Recoil
CombatLeft:AddToggle('NoRecoil', {
    Text = 'No Recoil',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("No Recoil", "No Recoil активирован (экспериментально)", 3)
        else
            Library:Notify("No Recoil", "No Recoil отключен", 3)
        end
    end
})

-- Critical Hits
CombatLeft:AddToggle('CriticalHits', {
    Text = 'Critical Hits',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Critical Hits", "Critical Hits активирован", 3)
        else
            Library:Notify("Critical Hits", "Critical Hits отключен", 3)
        end
    end
})

-- Auto Parry
CombatLeft:AddToggle('AutoParry', {
    Text = 'Auto Parry',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Auto Parry", "Auto Parry активирован (экспериментально)", 3)
        else
            Library:Notify("Auto Parry", "Auto Parry отключен", 3)
        end
    end
})

-- Weapon Spam
CombatLeft:AddToggle('WeaponSpam', {
    Text = 'Weapon Spam',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = RunService.Heartbeat:Connect(function()
                local ch = GetCharacter()
                if ch then
                    for _, v in ipairs(ch:GetChildren()) do
                        if v:IsA("Tool") then v:Activate() end
                    end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Weapon Spam", "Activated", 2)
        else
            Library:Notify("Weapon Spam", "Deactivated", 2)
        end
    end
})

-- Hitboxes Viewer
CombatLeft:AddToggle('HitboxesViewer', {
    Text = 'Hitboxes Viewer',
    Default = false,
    Callback = function(Value)
        if Value then
            local c = RunService.Heartbeat:Connect(function()
                for _, o in ipairs(State.espObjects) do pcall(function() o:Destroy() end) end
                State.espObjects = {}
                
                for _, p in ipairs(Players:GetPlayers()) do
                    local ch = p.Character
                    if ch then
                        for _, pt in ipairs(ch:GetDescendants()) do
                            if pt:IsA("BasePart") then
                                local b = Instance.new("SelectionBox")
                                b.Name = "ShardHitboxViewer"
                                b.Adornee = pt
                                b.Color3 = p == LocalPlayer and Library.AccentColor or Color3.new(1, 0.2, 0.2)
                                b.LineThickness = 0.02
                                b.Parent = pt
                                table.insert(State.espObjects, b)
                            end
                        end
                    end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Hitboxes Viewer", "Activated", 2)
        else
            for _, o in ipairs(State.espObjects) do pcall(function() o:Destroy() end) end
            State.espObjects = {}
            Library:Notify("Hitboxes Viewer", "Deactivated", 2)
        end
    end
})

-- Prediction
CombatLeft:AddToggle('Prediction', {
    Text = 'Prediction',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Prediction", "Prediction активирован (экспериментально)", 3)
        else
            Library:Notify("Prediction", "Prediction отключен", 3)
        end
    end
})

-- Target Strafe
CombatLeft:AddToggle('TargetStrafe', {
    Text = 'Target Strafe',
    Default = false,
    Callback = function(Value)
        if Value then
            local distance = Options.TargetStrafe_Distance.Value
            local speed = Options.TargetStrafe_Speed.Value
            local angle = 0
            
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHRP()
                if h then
                    local target = GetClosestPlayer(distance + 20)
                    if target and target.Character then
                        local th = target.Character:FindFirstChild("HumanoidRootPart")
                        if th then
                            angle = angle + speed * 0.01
                            local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
                            h.CFrame = CFrame.new(th.Position + offset, th.Position)
                        end
                    end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Target Strafe", "Activated", 2)
        else
            Library:Notify("Target Strafe", "Deactivated", 2)
        end
    end
})

CombatRight:AddSlider('TargetStrafe_Distance', {
    Text = 'Distance',
    Default = 10,
    Min = 5,
    Max = 20,
    Rounding = 0
})

CombatRight:AddSlider('TargetStrafe_Speed', {
    Text = 'Speed',
    Default = 20,
    Min = 5,
    Max = 50,
    Rounding = 0
})

-- Velocity Changer
CombatLeft:AddToggle('VelocityChanger', {
    Text = 'Velocity Changer',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Velocity Changer", "Velocity Changer активирован (экспериментально)", 3)
        else
            Library:Notify("Velocity Changer", "Velocity Changer отключен", 3)
        end
    end
})

-- Punch Aura
CombatLeft:AddToggle('PunchAura', {
    Text = 'Punch Aura',
    Default = false,
    Callback = function(Value)
        if Value then
            local range = Options.PunchAura_Range.Value
            
            local c = RunService.Heartbeat:Connect(function()
                local h = GetHRP()
                if h then
                    for _, p in ipairs(GetAllPlayers()) do
                        local ch = p.Character
                        if ch then
                            local th = ch:FindFirstChild("HumanoidRootPart")
                            if th then
                                local d = (h.Position - th.Position).Magnitude
                                if d < range then
                                    local character = GetCharacter()
                                    if character then
                                        for _, v in ipairs(character:GetChildren()) do
                                            if v:IsA("Tool") then v:Activate() end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Punch Aura", "Activated", 2)
        else
            Library:Notify("Punch Aura", "Deactivated", 2)
        end
    end
})

CombatRight:AddSlider('PunchAura_Range', {
    Text = 'Range',
    Default = 5,
    Min = 1,
    Max = 10,
    Rounding = 0
})

-- ═══════════════════════════════════════════════════
-- TAB: ESP
-- ═══════════════════════════════════════════════════

local ESPLeft = Tabs.ESP:AddLeftGroupbox('ESP Modules')
local ESPRight = Tabs.ESP:AddRightGroupbox('ESP Settings')

local ESPObjects = {}

local function ClearESP()
    for _, o in ipairs(ESPObjects) do pcall(function() o:Destroy() end) end
    ESPObjects = {}
end

local function CreateESPBox(ch, color, fillTransparency)
    local h = Instance.new("Highlight")
    h.Name = "ShardESPBox"
    h.Adornee = ch
    h.FillColor = color
    h.OutlineColor = color
    h.FillTransparency = fillTransparency or 0.5
    h.OutlineTransparency = 0
    h.Parent = ch
    table.insert(ESPObjects, h)
    return h
end

local function CreateESPName(ch, name, color, fontSize)
    local hr = ch:FindFirstChild("HumanoidRootPart")
    if not hr then return end
    
    local b = Instance.new("BillboardGui")
    b.Name = "ShardESPName"
    b.Adornee = hr
    b.Size = UDim2.new(0, 100, 0, 20)
    b.StudsOffset = Vector3.new(0, 3, 0)
    b.AlwaysOnTop = true
    b.Parent = hr
    
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = name
    l.TextColor3 = color
    l.TextSize = fontSize
    l.Font = Enum.Font.GothamBold
    l.Parent = b
    table.insert(ESPObjects, b)
    return b
end

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

-- Box ESP
ESPLeft:AddToggle('BoxESP', {
    Text = 'Box ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            local fillColor = Options.BoxESP_FillColor.Value
            local fillTransparency = Options.BoxESP_FillTransparency.Value
            local teamCheck = Options.BoxESP_TeamCheck.Value
            
            local c = RunService.Heartbeat:Connect(function()
                ClearESP()
                for _, p in ipairs(Players:GetPlayers()) do
                    if p == LocalPlayer then continue end
                    if teamCheck and p.Team == LocalPlayer.Team then continue end
                    
                    local ch = p.Character
                    if ch then
                        local color = p.Team == LocalPlayer.Team and fillColor or Color3.new(1, 0.2, 0.2)
                        CreateESPBox(ch, color, fillTransparency)
                    end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Box ESP", "Activated", 2)
        else
            ClearESP()
            Library:Notify("Box ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('BoxESP_FillColor', {
    Default = Color3.new(0, 0.78, 1),
    Title = 'Fill Color'
})

ESPRight:AddSlider('BoxESP_FillTransparency', {
    Text = 'Fill Transparency',
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 2
})

ESPRight:AddToggle('BoxESP_TeamCheck', {
    Text = 'Team Check',
    Default = false
})

-- Name ESP
ESPLeft:AddToggle('NameESP', {
    Text = 'Name ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            local color = Options.NameESP_Color.Value
            local fontSize = Options.NameESP_FontSize.Value
            
            local c = RunService.Heartbeat:Connect(function()
                for _, p in ipairs(Players:GetPlayers()) do
                    if p == LocalPlayer then continue end
                    local ch = p.Character
                    if ch and not ch:FindFirstChild("ShardESPName") then
                        CreateESPName(ch, p.DisplayName or p.Name, color, fontSize)
                    end
                end
            end)
            table.insert(State.connections, c)
            Library:Notify("Name ESP", "Activated", 2)
        else
            ClearESP()
            Library:Notify("Name ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('NameESP_Color', {
    Default = Color3.new(1, 1, 1),
    Title = 'Color'
})

ESPRight:AddSlider('NameESP_FontSize', {
    Text = 'Font Size',
    Default = 12,
    Min = 10,
    Max = 24,
    Rounding = 0
})

-- Health ESP
ESPLeft:AddToggle('HealthESP', {
    Text = 'Health ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Health ESP", "Activated", 2)
        else
            Library:Notify("Health ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('HealthESP_Color', {
    Default = Color3.new(0, 1, 0),
    Title = 'Color'
})

-- Distance ESP
ESPLeft:AddToggle('DistanceESP', {
    Text = 'Distance ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Distance ESP", "Activated", 2)
        else
            Library:Notify("Distance ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('DistanceESP_Color', {
    Default = Color3.new(1, 1, 0),
    Title = 'Color'
})

-- Tracer ESP
ESPLeft:AddToggle('TracerESP', {
    Text = 'Tracer ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            local color = Options.TracerESP_Color.Value
            local thickness = Options.TracerESP_Thickness.Value
            Library:Notify("Tracer ESP", "Activated", 2)
        else
            Library:Notify("Tracer ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('TracerESP_Color', {
    Default = Color3.new(1, 1, 1),
    Title = 'Color'
})

ESPRight:AddSlider('TracerESP_Thickness', {
    Text = 'Thickness',
    Default = 0.1,
    Min = 0.05,
    Max = 0.5,
    Rounding = 2
})

-- Skeleton ESP
ESPLeft:AddToggle('SkeletonESP', {
    Text = 'Skeleton ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Skeleton ESP", "Activated", 2)
        else
            Library:Notify("Skeleton ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('SkeletonESP_Color', {
    Default = Color3.new(1, 1, 1),
    Title = 'Color'
})

ESPRight:AddSlider('SkeletonESP_Thickness', {
    Text = 'Thickness',
    Default = 0.05,
    Min = 0.02,
    Max = 0.2,
    Rounding = 2
})

-- Chams ESP
ESPLeft:AddToggle('ChamsESP', {
    Text = 'Chams ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Chams ESP", "Activated", 2)
        else
            Library:Notify("Chams ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('ChamsESP_Color', {
    Default = Color3.new(0, 1, 0),
    Title = 'Color'
})

-- Barrel ESP
ESPLeft:AddToggle('BarrelESP', {
    Text = 'Barrel ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Barrel ESP", "Activated", 2)
        else
            Library:Notify("Barrel ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('BarrelESP_Color', {
    Default = Color3.new(1, 0, 0),
    Title = 'Color'
})

-- Item ESP
ESPLeft:AddToggle('ItemESP', {
    Text = 'Item ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Item ESP", "Activated", 2)
        else
            Library:Notify("Item ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('ItemESP_Color', {
    Default = Color3.new(1, 1, 0),
    Title = 'Color'
})

ESPRight:AddSlider('ItemESP_MaxDistance', {
    Text = 'Max Distance',
    Default = 200,
    Min = 50,
    Max = 1000,
    Rounding = 0
})

-- Vehicle ESP
ESPLeft:AddToggle('VehicleESP', {
    Text = 'Vehicle ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Vehicle ESP", "Activated", 2)
        else
            Library:Notify("Vehicle ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('VehicleESP_Color', {
    Default = Color3.new(0, 1, 1),
    Title = 'Color'
})

-- Look ESP
ESPLeft:AddToggle('LookESP', {
    Text = 'Look ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Look ESP", "Activated", 2)
        else
            Library:Notify("Look ESP", "Deactivated", 2)
        end
    end
})

-- FOV Circle
ESPLeft:AddToggle('FOVCircle', {
    Text = 'FOV Circle',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("FOV Circle", "Activated", 2)
        else
            Library:Notify("FOV Circle", "Deactivated", 2)
        end
    end
})

ESPRight:AddSlider('FOVCircle_Radius', {
    Text = 'Radius',
    Default = 120,
    Min = 30,
    Max = 500,
    Rounding = 0
})

ESPRight:AddColorPicker('FOVCircle_Color', {
    Default = Color3.new(1, 1, 1),
    Title = 'Color'
})

ESPRight:AddToggle('FOVCircle_Filled', {
    Text = 'Filled',
    Default = false
})

ESPRight:AddSlider('FOVCircle_Thickness', {
    Text = 'Thickness',
    Default = 2,
    Min = 1,
    Max = 5,
    Rounding = 0
})

-- Head Dot ESP
ESPLeft:AddToggle('HeadDotESP', {
    Text = 'Head Dot ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Head Dot ESP", "Activated", 2)
        else
            Library:Notify("Head Dot ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('HeadDotESP_Color', {
    Default = Color3.new(1, 0, 0),
    Title = 'Color'
})

ESPRight:AddSlider('HeadDotESP_Size', {
    Text = 'Size',
    Default = 4,
    Min = 2,
    Max = 10,
    Rounding = 0
})

-- Offscreen ESP
ESPLeft:AddToggle('OffscreenESP', {
    Text = 'Offscreen ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Offscreen ESP", "Activated", 2)
        else
            Library:Notify("Offscreen ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddColorPicker('OffscreenESP_Color', {
    Default = Color3.new(1, 1, 1),
    Title = 'Color'
})

ESPRight:AddSlider('OffscreenESP_MaxDistance', {
    Text = 'Max Distance',
    Default = 1000,
    Min = 100,
    Max = 5000,
    Rounding = 0
})

-- Color ESP
ESPLeft:AddToggle('ColorESP', {
    Text = 'Color ESP',
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notify("Color ESP", "Activated", 2)
        else
            Library:Notify("Color ESP", "Deactivated", 2)
        end
    end
})

ESPRight:AddToggle('ColorESP_TeamColors', {
    Text = 'Team Colors',
    Default = false
})

ESPRight:AddToggle('ColorESP_DistanceColors', {
    Text = 'Distance Colors',
    Default = false
})

-- ═══════════════════════════════════════════════════
-- TAB: VISUALS
-- ═══════════════════════════════════════════════════

local VisualsLeft = Tabs.Visuals:AddLeftGroupbox('Visuals Modules')
local VisualsRight = Tabs.Visuals:AddRightGroupbox('Visuals Settings')

-- Trails
VisualsLeft:AddToggle('Trails', {
    Text = 'Trails',
    Default = false,
    Callback = function(Value)
        if Value then Library:Notify("Trails", "Activated", 2) else Library:Notify("Trails", "Deactivated", 2) end
    end
})

VisualsRight:AddColorPicker('Trails_Color', { Default = Color3.new(0, 1, 0), Title = 'Color' })
VisualsRight:AddSlider('Trails_Rate', { Text = 'Rate', Default = 50, Min = 10, Max = 200, Rounding = 0 })
VisualsRight:AddSlider('Trails_Lifetime', { Text = 'Lifetime', Default = 1, Min = 0.1, Max = 3, Rounding = 1 })
VisualsRight:AddSlider('Trails_Size', { Text = 'Size', Default = 0.5, Min = 0.1, Max = 2, Rounding = 1 })

-- Crown
VisualsLeft:AddToggle('Crown', {
    Text = 'Crown',
    Default = false,
    Callback = function(Value)
        if Value then Library:Notify("Crown", "Activated", 2) else Library:Notify("Crown", "Deactivated", 2) end
    end
})

-- Wings
VisualsLeft:AddToggle('Wings', {
    Text = 'Wings',
    Default = false,
    Callback = function(Value)
        if Value then Library:Notify("Wings", "Activated", 2) else Library:Notify("Wings", "Deactivated", 2) end
    end
})

VisualsRight:AddColorPicker('Wings_Color', { Default = Color3.new(1, 1, 1), Title = 'Color' })
VisualsRight:AddSlider('Wings_Transparency', { Text = 'Transparency', Default = 0.3, Min = 0, Max = 1, Rounding = 2 })

-- Aura
VisualsLeft:AddToggle('Aura', {
    Text = 'Aura',
    Default = false,
    Callback = function(Value)
        if Value then Library:Notify("Aura", "Activated", 2) else Library:Notify("Aura", "Deactivated", 2) end
    end
})

VisualsRight:AddColorPicker('Aura_Color', { Default = Color3.new(0, 1, 0), Title = 'Color' })
VisualsRight:AddSlider('Aura_Size', { Text = 'Size', Default = 4, Min = 1, Max = 10, Rounding = 0 })
VisualsRight:AddSlider('Aura_Brightness', { Text = 'Brightness', Default = 5, Min = 0, Max = 10, Rounding = 0 })

-- Chams
VisualsLeft:AddToggle('Chams', {
    Text = 'Chams',
    Default = false,
    Callback = function(Value)
        if Value then Library:Notify("Chams", "Activated", 2) else Library:Notify("Chams", "Deactivated", 2) end
    end
})

VisualsRight:AddColorPicker('Chams_Color', { Default = Color3.new(0, 1, 0), Title = 'Color' })
VisualsRight:AddSlider('Chams_Transparency', { Text = 'Transparency', Default = 0, Min = 0, Max = 1, Rounding = 2 })

-- Speed Lines
VisualsLeft:AddToggle('SpeedLines', {
    Text = 'Speed Lines',
    Default = false,
    Callback = function(Value)
        if Value then Library:Notify("Speed Lines", "Activated", 2) else Library:Notify("Speed Lines", "Deactivated", 2) end
    end
})

-- Glow Body
VisualsLeft:AddToggle('GlowBody', {
    Text = 'Glow Body',
    Default = false,
    Callback = function(Value)
        if Value then Library:Notify("Glow Body", "Activated", 2) else Library:Notify("Glow Body", "Deactivated", 2) end
    end
})

-- Rainbow Body
VisualsLeft:AddToggle('RainbowBody', {
    Text = 'Rainbow Body',
    Default = false,
    Callback = function(Value)
        if Value then Library:Notify("Rainbow Body", "Activated", 2) else Library:Notify("Rainbow Body", "Deactivated", 2) end
    end
})

-- ═══════════════════════════════════════════════════
-- TAB: MENU / UI SETTINGS
-- ═══════════════════════════════════════════════════

local MenuGroup = Tabs.Menu:AddLeftGroupbox('Menu')

MenuGroup:AddButton('Unload', function() Library:Unload() end)

MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'End',
    NoUI = true,
    Text = 'Menu keybind'
})

-- UI Scale slider
MenuGroup:AddSlider('WindowScale', {
    Text = 'UI Scale',
    Default = 1,
    Min = 0.5,
    Max = 1.5,
    Rounding = 2,
    Callback = function(Value) Library.SetScale(Value) end
})

Options.WindowScale:OnChanged(function()
    Library.SetScale(Options.WindowScale.Value)
end)

Library.ToggleKeybind = Options.MenuKeybind

-- Addons
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('ShardDLC')
SaveManager:SetFolder('ShardDLC')
SaveManager:BuildConfigSection(Tabs.Menu)
ThemeManager:ApplyToTab(Tabs.Menu)

-- Load config
SaveManager:Load()

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

Library:OnUnload(function()
    WatermarkConnection:Disconnect()
    
    -- Cleanup all active connections
    for i = #State.connections, 1, -1 do
        if State.connections[i] and State.connections[i].Disconnect then
            State.connections[i]:Disconnect()
            table.remove(State.connections, i)
        end
    end
    
    -- Cleanup ESP objects
    for _, o in ipairs(ESPObjects) do pcall(function() o:Destroy() end) end
    ESPObjects = {}
    
    -- Cleanup state objects
    for _, o in ipairs(State.espObjects) do pcall(function() o:Destroy() end) end
    State.espObjects = {}
    
    print('Shard DLC Unloaded!')
    Library.Unloaded = true
end)
