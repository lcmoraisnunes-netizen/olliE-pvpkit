--[[
    olliE PvP Kit Hub — 1.8 KIT PVP / Bloxine Extra
    Place \~72393956865647
    Fixed: floating open/close button + RightCtrl keybind
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Config = {
    ESP = {
        Enabled = true,
        Box = true,
        HitboxESP = true,
        Skeleton = true,
        Snaplines = true,
        Name = true,
        Distance = true,
        Health = true,
        TeamCheck = false,
        MaxDistance = 1500,
        BoxColor = Color3.fromRGB(255, 60, 60),
        SkeletonColor = Color3.fromRGB(255, 255, 255),
        SnaplineColor = Color3.fromRGB(255, 255, 0),
        HitboxColor = Color3.fromRGB(0, 255, 255),
        NameColor = Color3.fromRGB(255, 255, 255),
    },
    Aimbot = {
        Enabled = true,
        FOV = 120,
        Smoothness = 0.18,
        Prediction = 0.12,
        Sticky = true,
        TeamCheck = false,
        TargetPart = "Head",
        ShowFOV = true,
        FOVColor = Color3.fromRGB(255, 255, 255),
        LockedColor = Color3.fromRGB(0, 255, 100),
        Key = Enum.UserInputType.MouseButton2,
    },
    Hitbox = {
        Enabled = false,
        Size = 8,
        Transparency = 0.6,
        Color = Color3.fromRGB(255, 0, 0),
        TeamCheck = false,
    },
    Misc = {
        Speed = false,
        SpeedValue = 28,
        Jump = false,
        JumpValue = 80,
        Noclip = false,
        Fullbright = false,
    },
    AntiBan = {
        Enabled = true,
        HookKick = true,
        HookNamecall = true,
    }
}

local ESPObjects = {}
local CurrentTarget = nil
local Aiming = false
local Connections = {}
local DrawingObjects = {}
local UIVisible = true
local MainFrame = nil
local ScreenGuiRef = nil

local function IsAlive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    return hum and root and hum.Health > 0
end

local function GetRoot(char)
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end

local function IsEnemy(plr)
    if plr == LocalPlayer then return false end
    if Config.ESP.TeamCheck or Config.Aimbot.TeamCheck or Config.Hitbox.TeamCheck then
        if plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
            return false
        end
    end
    return true
end

local function WorldToScreen(pos)
    local screen, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screen.X, screen.Y), onScreen, screen.Z
end

local function GetDistance(pos)
    local root = LocalPlayer.Character and GetRoot(LocalPlayer.Character)
    if not root then return 0 end
    return (root.Position - pos).Magnitude
end

local function CreateDrawing(class, props)
    local obj = Drawing.new(class)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    table.insert(DrawingObjects, obj)
    return obj
end

local function ClearPlayerESP(plr)
    local data = ESPObjects[plr]
    if not data then return end
    for _, obj in pairs(data) do
        if typeof(obj) == "table" then
            for _, o in pairs(obj) do
                if o and o.Remove then pcall(function() o:Remove() end) end
            end
        elseif obj and obj.Remove then
            pcall(function() obj:Remove() end)
        end
    end
    ESPObjects[plr] = nil
end

local function SetupPlayerESP(plr)
    if ESPObjects[plr] then return end
    local data = {
        Box = CreateDrawing("Square", {Thickness = 1.5, Filled = false, Visible = false}),
        BoxOutline = CreateDrawing("Square", {Thickness = 3, Filled = false, Color = Color3.new(0,0,0), Visible = false}),
        Name = CreateDrawing("Text", {Size = 14, Center = true, Outline = true, Visible = false}),
        Distance = CreateDrawing("Text", {Size = 12, Center = true, Outline = true, Visible = false}),
        HealthBar = CreateDrawing("Square", {Filled = true, Visible = false}),
        HealthOutline = CreateDrawing("Square", {Filled = false, Thickness = 1, Color = Color3.new(0,0,0), Visible = false}),
        Snapline = CreateDrawing("Line", {Thickness = 1.2, Visible = false}),
        Hitbox = CreateDrawing("Square", {Thickness = 1.5, Filled = false, Visible = false}),
        Skeleton = {},
    }
    for i = 1, 14 do
        data.Skeleton[i] = CreateDrawing("Line", {Thickness = 1.5, Visible = false})
    end
    ESPObjects[plr] = data
end

local function UpdateSkeleton(data, char)
    local joints = {
        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
        {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
    }
    local r6map = {
        Head = "Head", UpperTorso = "Torso", LowerTorso = "Torso",
        LeftUpperArm = "Left Arm", LeftLowerArm = "Left Arm", LeftHand = "Left Arm",
        RightUpperArm = "Right Arm", RightLowerArm = "Right Arm", RightHand = "Right Arm",
        LeftUpperLeg = "Left Leg", LeftLowerLeg = "Left Leg", LeftFoot = "Left Leg",
        RightUpperLeg = "Right Leg", RightLowerLeg = "Right Leg", RightFoot = "Right Leg",
    }
    for i, pair in ipairs(joints) do
        local line = data.Skeleton[i]
        if not line then continue end
        local p1 = char:FindFirstChild(pair[1]) or char:FindFirstChild(r6map[pair[1]] or "")
        local p2 = char:FindFirstChild(pair[2]) or char:FindFirstChild(r6map[pair[2]] or "")
        if p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
            local s1, on1 = WorldToScreen(p1.Position)
            local s2, on2 = WorldToScreen(p2.Position)
            if on1 and on2 then
                line.From = s1
                line.To = s2
                line.Color = Config.ESP.SkeletonColor
                line.Visible = Config.ESP.Skeleton and Config.ESP.Enabled
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end
end

local function UpdateESP()
    for plr, data in pairs(ESPObjects) do
        if not IsAlive(plr) or not IsEnemy(plr) then
            for _, obj in pairs(data) do
                if typeof(obj) == "table" then
                    for _, o in pairs(obj) do if o then o.Visible = false end end
                elseif obj then obj.Visible = false end
            end
            continue
        end
        local char = plr.Character
        local root = GetRoot(char)
        local hum = char:FindFirstChildOfClass("Humanoid")
        local head = char:FindFirstChild("Head")
        if not root or not hum then
            for _, obj in pairs(data) do
                if typeof(obj) == "table" then
                    for _, o in pairs(obj) do if o then o.Visible = false end end
                elseif obj then obj.Visible = false end
            end
            continue
        end
        local dist = GetDistance(root.Position)
        if dist > Config.ESP.MaxDistance then
            for _, obj in pairs(data) do
                if typeof(obj) == "table" then
                    for _, o in pairs(obj) do if o then o.Visible = false end end
                elseif obj then obj.Visible = false end
            end
            continue
        end
        local pos, onScreen, depth = WorldToScreen(root.Position)
        if not onScreen or depth < 0 then
            for _, obj in pairs(data) do
                if typeof(obj) == "table" then
                    for _, o in pairs(obj) do if o then o.Visible = false end end
                elseif obj then obj.Visible = false end
            end
            continue
        end
        local headPos = head and head.Position or (root.Position + Vector3.new(0, 1.5, 0))
        local footPos = root.Position - Vector3.new(0, 3, 0)
        local headScreen = WorldToScreen(headPos)
        local footScreen = WorldToScreen(footPos)
        local height = math.abs(headScreen.Y - footScreen.Y)
        local width = height * 0.55

        if Config.ESP.Box and Config.ESP.Enabled then
            data.BoxOutline.Size = Vector2.new(width + 2, height + 2)
            data.BoxOutline.Position = Vector2.new(pos.X - (width + 2)/2, pos.Y - height/2 - 1)
            data.BoxOutline.Visible = true
            data.Box.Size = Vector2.new(width, height)
            data.Box.Position = Vector2.new(pos.X - width/2, pos.Y - height/2)
            data.Box.Color = Config.ESP.BoxColor
            data.Box.Visible = true
        else
            data.Box.Visible = false
            data.BoxOutline.Visible = false
        end

        if Config.ESP.HitboxESP and Config.ESP.Enabled then
            local hbSize = Config.Hitbox.Enabled and Config.Hitbox.Size or 2
            local hbScreen, hbOn = WorldToScreen(root.Position)
            if hbOn then
                local scale = (height / 6) * (hbSize / 2)
                data.Hitbox.Size = Vector2.new(scale, scale)
                data.Hitbox.Position = Vector2.new(hbScreen.X - scale/2, hbScreen.Y - scale/2)
                data.Hitbox.Color = Config.ESP.HitboxColor
                data.Hitbox.Visible = true
            else
                data.Hitbox.Visible = false
            end
        else
            data.Hitbox.Visible = false
        end

        if Config.ESP.Name and Config.ESP.Enabled then
            data.Name.Text = plr.Name
            data.Name.Position = Vector2.new(pos.X, pos.Y - height/2 - 16)
            data.Name.Color = Config.ESP.NameColor
            data.Name.Visible = true
        else
            data.Name.Visible = false
        end

        if Config.ESP.Distance and Config.ESP.Enabled then
            data.Distance.Text = string.format("[%dm]", math.floor(dist))
            data.Distance.Position = Vector2.new(pos.X, pos.Y + height/2 + 2)
            data.Distance.Color = Config.ESP.NameColor
            data.Distance.Visible = true
        else
            data.Distance.Visible = false
        end

        if Config.ESP.Health and Config.ESP.Enabled then
            local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local barH = height
            local barW = 3
            data.HealthOutline.Size = Vector2.new(barW + 2, barH + 2)
            data.HealthOutline.Position = Vector2.new(pos.X - width/2 - 8, pos.Y - height/2 - 1)
            data.HealthOutline.Visible = true
            data.HealthBar.Size = Vector2.new(barW, barH * hp)
            data.HealthBar.Position = Vector2.new(pos.X - width/2 - 7, pos.Y - height/2 + (barH * (1 - hp)))
            data.HealthBar.Color = Color3.fromRGB(255 * (1 - hp), 255 * hp, 0)
            data.HealthBar.Visible = true
        else
            data.HealthBar.Visible = false
            data.HealthOutline.Visible = false
        end

        if Config.ESP.Snaplines and Config.ESP.Enabled then
            data.Snapline.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            data.Snapline.To = Vector2.new(pos.X, pos.Y + height/2)
            data.Snapline.Color = Config.ESP.SnaplineColor
            data.Snapline.Visible = true
        else
            data.Snapline.Visible = false
        end

        if Config.ESP.Skeleton and Config.ESP.Enabled then
            UpdateSkeleton(data, char)
        else
            for _, line in pairs(data.Skeleton) do line.Visible = false end
        end
    end
end

local FOVCircle = CreateDrawing("Circle", {
    Thickness = 1.5,
    Color = Config.Aimbot.FOVColor,
    Filled = false,
    Visible = false,
    NumSides = 64,
})

local function GetClosestInFOV()
    local closest = nil
    local closestDist = Config.Aimbot.FOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, plr in ipairs(Players:GetPlayers()) do
        if not IsAlive(plr) or not IsEnemy(plr) then continue end
        local char = plr.Character
        local part = char:FindFirstChild(Config.Aimbot.TargetPart) or char:FindFirstChild("Head") or GetRoot(char)
        if not part then continue end
        local screen, onScreen = WorldToScreen(part.Position)
        if not onScreen then continue end
        local dist = (screen - center).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = plr
        end
    end
    return closest
end

local function UpdateAimbot()
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Radius = Config.Aimbot.FOV
    FOVCircle.Color = CurrentTarget and Config.Aimbot.LockedColor or Config.Aimbot.FOVColor
    FOVCircle.Visible = Config.Aimbot.ShowFOV and Config.Aimbot.Enabled

    if not Config.Aimbot.Enabled or not Aiming then
        if not Config.Aimbot.Sticky then CurrentTarget = nil end
        return
    end

    if Config.Aimbot.Sticky and CurrentTarget and IsAlive(CurrentTarget) and IsEnemy(CurrentTarget) then
        -- keep
    else
        CurrentTarget = GetClosestInFOV()
    end

    if not CurrentTarget then return end
    local char = CurrentTarget.Character
    local part = char:FindFirstChild(Config.Aimbot.TargetPart) or char:FindFirstChild("Head") or GetRoot(char)
    if not part then CurrentTarget = nil return end

    local targetPos = part.Position
    if Config.Aimbot.Prediction > 0 and part:IsA("BasePart") then
        targetPos = targetPos + (part.AssemblyLinearVelocity * Config.Aimbot.Prediction)
    end
    local camPos = Camera.CFrame.Position
    local direction = (targetPos - camPos).Unit
    local targetCF = CFrame.new(camPos, camPos + direction)
    Camera.CFrame = Camera.CFrame:Lerp(targetCF, Config.Aimbot.Smoothness)
end

local function ApplyHitbox(plr)
    if not Config.Hitbox.Enabled then return end
    if not IsAlive(plr) or not IsEnemy(plr) then return end
    local char = plr.Character
    local root = GetRoot(char)
    if not root then return end
    pcall(function()
        root.Size = Vector3.new(Config.Hitbox.Size, Config.Hitbox.Size, Config.Hitbox.Size)
        root.Transparency = Config.Hitbox.Transparency
        root.CanCollide = false
        root.Massless = true
        root.Color = Config.Hitbox.Color
        root.Material = Enum.Material.ForceField
    end)
end

local function ResetHitbox(plr)
    if not IsAlive(plr) then return end
    local char = plr.Character
    local root = GetRoot(char)
    if not root then return end
    pcall(function()
        root.Size = Vector3.new(2, 2, 1)
        root.Transparency = 1
        root.CanCollide = true
        root.Massless = false
        root.Material = Enum.Material.Plastic
    end)
end

local function UpdateMisc()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = GetRoot(char)
    if not hum or not root then return end
    if Config.Misc.Speed then hum.WalkSpeed = Config.Misc.SpeedValue end
    if Config.Misc.Jump then
        hum.JumpPower = Config.Misc.JumpValue
        hum.UseJumpPower = true
    end
    if Config.Misc.Noclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end

local originalAmbient, originalBrightness, originalClock
local function ToggleFullbright(state)
    if state then
        originalAmbient = Lighting.Ambient
        originalBrightness = Lighting.Brightness
        originalClock = Lighting.ClockTime
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    else
        if originalAmbient then Lighting.Ambient = originalAmbient end
        if originalBrightness then Lighting.Brightness = originalBrightness end
        if originalClock then Lighting.ClockTime = originalClock end
        Lighting.GlobalShadows = true
    end
end

local function InitAntiBan()
    if not Config.AntiBan.Enabled then return end
    if Config.AntiBan.HookNamecall then
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "Kick" or method == "kick" then return nil end
            if method == "FireServer" or method == "InvokeServer" then
                local remoteName = tostring(self)
                if string.find(string.lower(remoteName), "kick")
                    or string.find(string.lower(remoteName), "ban")
                    or string.find(string.lower(remoteName), "detect")
                    or string.find(string.lower(remoteName), "anticheat") then
                    return nil
                end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end
    if Config.AntiBan.HookKick then
        pcall(function()
            hookfunction(LocalPlayer.Kick, newcclosure(function() return nil end))
        end)
    end
end

local function ToggleUI()
    UIVisible = not UIVisible
    if MainFrame then
        MainFrame.Visible = UIVisible
    end
end

local function CreateGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "olliE_PvPKitHub"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() ScreenGui.Parent = CoreGui end)
    if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    ScreenGuiRef = ScreenGui

    -- Floating open/close button (always visible)
    local FloatBtn = Instance.new("TextButton")
    FloatBtn.Name = "FloatToggle"
    FloatBtn.Size = UDim2.new(0, 48, 0, 48)
    FloatBtn.Position = UDim2.new(0, 20, 0.5, -24)
    FloatBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    FloatBtn.Text = "oE"
    FloatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    FloatBtn.TextSize = 16
    FloatBtn.Font = Enum.Font.GothamBold
    FloatBtn.BorderSizePixel = 0
    FloatBtn.ZIndex = 50
    FloatBtn.Parent = ScreenGui
    local FloatCorner = Instance.new("UICorner")
    FloatCorner.CornerRadius = UDim.new(1, 0)
    FloatCorner.Parent = FloatBtn
    local FloatStroke = Instance.new("UIStroke")
    FloatStroke.Color = Color3.fromRGB(255, 255, 255)
    FloatStroke.Thickness = 1.5
    FloatStroke.Parent = FloatBtn

    -- make floating button draggable
    local draggingFloat, dragStart, startPos
    FloatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingFloat = true
            dragStart = input.Position
            startPos = FloatBtn.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingFloat and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            FloatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingFloat = false
        end
    end)

    FloatBtn.MouseButton1Click:Connect(function()
        ToggleUI()
    end)

    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 320, 0, 420)
    Main.Position = UDim2.new(0.5, -160, 0.5, -210)
    Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Visible = true
    Main.Parent = ScreenGui
    MainFrame = Main
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = Main

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 36)
    TitleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = Main
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 8)
    TitleCorner.Parent = TitleBar

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -80, 1, 0)
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "olliE // PvP Kit Hub"
    Title.TextColor3 = Color3.fromRGB(255, 80, 80)
    Title.TextSize = 15
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 28, 0, 28)
    MinBtn.Position = UDim2.new(1, -64, 0, 4)
    MinBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    MinBtn.Text = "−"
    MinBtn.TextColor3 = Color3.fromRGB(255, 200, 80)
    MinBtn.TextSize = 18
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.Parent = TitleBar
    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 6)
    MinCorner.Parent = MinBtn
    MinBtn.MouseButton1Click:Connect(function()
        ToggleUI()
    end)

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -32, 0, 4)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    CloseBtn.Text = "×"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    CloseBtn.TextSize = 18
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = TitleBar
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn
    CloseBtn.MouseButton1Click:Connect(function()
        ToggleUI()
    end)

    local Content = Instance.new("ScrollingFrame")
    Content.Size = UDim2.new(1, -16, 1, -48)
    Content.Position = UDim2.new(0, 8, 0, 42)
    Content.BackgroundTransparency = 1
    Content.BorderSizePixel = 0
    Content.ScrollBarThickness = 4
    Content.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
    Content.CanvasSize = UDim2.new(0, 0, 0, 780)
    Content.Parent = Main
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.Parent = Content

    local function Section(name)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 22)
        f.BackgroundTransparency = 1
        f.Parent = Content
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, 0, 1, 0)
        t.BackgroundTransparency = 1
        t.Text = "— " .. name
        t.TextColor3 = Color3.fromRGB(160, 160, 170)
        t.TextSize = 12
        t.Font = Enum.Font.GothamBold
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = f
    end

    local function Toggle(name, default, callback)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 28)
        f.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
        f.BorderSizePixel = 0
        f.Parent = Content
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = f
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -50, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(230, 230, 235)
        label.TextSize = 13
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = f
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 36, 0, 18)
        btn.Position = UDim2.new(1, -44, 0.5, -9)
        btn.BackgroundColor3 = default and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(60, 60, 70)
        btn.Text = ""
        btn.Parent = f
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(1, 0)
        bc.Parent = btn
        local state = default
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.BackgroundColor3 = state and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(60, 60, 70)
            callback(state)
        end)
    end

    local function Slider(name, min, max, default, callback)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 44)
        f.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
        f.BorderSizePixel = 0
        f.Parent = Content
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = f
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -20, 0, 18)
        label.Position = UDim2.new(0, 10, 0, 4)
        label.BackgroundTransparency = 1
        label.Text = name .. ": " .. tostring(default)
        label.TextColor3 = Color3.fromRGB(230, 230, 235)
        label.TextSize = 12
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = f
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, -20, 0, 6)
        bar.Position = UDim2.new(0, 10, 0, 28)
        bar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        bar.BorderSizePixel = 0
        bar.Parent = f
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(1, 0)
        bc.Parent = bar
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
        fill.BorderSizePixel = 0
        fill.Parent = bar
        local fc = Instance.new("UICorner")
        fc.CornerRadius = UDim.new(1, 0)
        fc.Parent = fill
        local dragging = false
        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                local val = math.floor(min + (max - min) * rel)
                fill.Size = UDim2.new(rel, 0, 1, 0)
                label.Text = name .. ": " .. tostring(val)
                callback(val)
            end
        end)
    end

    Section("ESP")
    Toggle("Master ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
    Toggle("Box ESP", Config.ESP.Box, function(v) Config.ESP.Box = v end)
    Toggle("Hitbox ESP", Config.ESP.HitboxESP, function(v) Config.ESP.HitboxESP = v end)
    Toggle("Skeleton ESP", Config.ESP.Skeleton, function(v) Config.ESP.Skeleton = v end)
    Toggle("Snaplines", Config.ESP.Snaplines, function(v) Config.ESP.Snaplines = v end)
    Toggle("Names", Config.ESP.Name, function(v) Config.ESP.Name = v end)
    Toggle("Distance", Config.ESP.Distance, function(v) Config.ESP.Distance = v end)
    Toggle("Health Bar", Config.ESP.Health, function(v) Config.ESP.Health = v end)
    Toggle("Team Check (ESP)", Config.ESP.TeamCheck, function(v) Config.ESP.TeamCheck = v end)

    Section("AIMBOT")
    Toggle("Aimbot", Config.Aimbot.Enabled, function(v) Config.Aimbot.Enabled = v end)
    Toggle("Show FOV Circle", Config.Aimbot.ShowFOV, function(v) Config.Aimbot.ShowFOV = v end)
    Toggle("Sticky Target", Config.Aimbot.Sticky, function(v) Config.Aimbot.Sticky = v end)
    Toggle("Team Check (Aim)", Config.Aimbot.TeamCheck, function(v) Config.Aimbot.TeamCheck = v end)
    Slider("FOV Size", 40, 400, Config.Aimbot.FOV, function(v) Config.Aimbot.FOV = v end)
    Slider("Smoothness", 1, 30, math.floor(Config.Aimbot.Smoothness * 100), function(v) Config.Aimbot.Smoothness = v / 100 end)
    Slider("Prediction", 0, 30, math.floor(Config.Aimbot.Prediction * 100), function(v) Config.Aimbot.Prediction = v / 100 end)

    Section("HITBOX EXPANDER")
    Toggle("Hitbox Expander", Config.Hitbox.Enabled, function(v)
        Config.Hitbox.Enabled = v
        if not v then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr \~= LocalPlayer then ResetHitbox(plr) end
            end
        end
    end)
    Slider("Hitbox Size", 2, 20, Config.Hitbox.Size, function(v) Config.Hitbox.Size = v end)
    Slider("Transparency", 0, 100, math.floor(Config.Hitbox.Transparency * 100), function(v) Config.Hitbox.Transparency = v / 100 end)

    Section("MISC")
    Toggle("Speed", Config.Misc.Speed, function(v) Config.Misc.Speed = v end)
    Slider("Speed Value", 16, 100, Config.Misc.SpeedValue, function(v) Config.Misc.SpeedValue = v end)
    Toggle("Jump Power", Config.Misc.Jump, function(v) Config.Misc.Jump = v end)
    Slider("Jump Value", 50, 200, Config.Misc.JumpValue, function(v) Config.Misc.JumpValue = v end)
    Toggle("Noclip", Config.Misc.Noclip, function(v) Config.Misc.Noclip = v end)
    Toggle("Fullbright", Config.Misc.Fullbright, function(v)
        Config.Misc.Fullbright = v
        ToggleFullbright(v)
    end)

    Section("PROTECTION")
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 24)
    status.BackgroundTransparency = 1
    status.Text = Config.AntiBan.Enabled and "Anti-Ban: ACTIVE" or "Anti-Ban: OFF"
    status.TextColor3 = Config.AntiBan.Enabled and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(220, 80, 80)
    status.TextSize = 13
    status.Font = Enum.Font.GothamBold
    status.Parent = Content

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, 0, 0, 36)
    hint.BackgroundTransparency = 1
    hint.Text = "RMB hold = aimlock\nRightCtrl / red oE button = toggle UI"
    hint.TextColor3 = Color3.fromRGB(120, 120, 130)
    hint.TextSize = 11
    hint.Font = Enum.Font.Gotham
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.Parent = Content
end

local function Init()
    InitAntiBan()
    CreateGUI()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr \~= LocalPlayer then SetupPlayerESP(plr) end
    end
    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function()
            task.wait(0.5)
            SetupPlayerESP(plr)
        end)
        if plr.Character then SetupPlayerESP(plr) end
    end)
    Players.PlayerRemoving:Connect(function(plr)
        ClearPlayerESP(plr)
        if CurrentTarget == plr then CurrentTarget = nil end
    end)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.8)
        if Config.Misc.Fullbright then ToggleFullbright(true) end
    end)
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Config.Aimbot.Key then Aiming = true end
        if input.KeyCode == Enum.KeyCode.RightControl then
            ToggleUI()
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Config.Aimbot.Key then
            Aiming = false
            if not Config.Aimbot.Sticky then CurrentTarget = nil end
        end
    end)
    table.insert(Connections, RunService.RenderStepped:Connect(function()
        UpdateESP()
        UpdateAimbot()
        UpdateMisc()
        if Config.Hitbox.Enabled then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr \~= LocalPlayer then ApplyHitbox(plr) end
            end
        end
    end))
end

Init()
print("[olliE] PvP Kit Hub loaded — floating oE button + RightCtrl toggle")
