--// ====================== ANTI-BAN / ANTI-KICK SYSTEM ======================
local AntiBanEnabled = true

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

if AntiBanEnabled then
    pcall(function()
        local oldKick = LocalPlayer.Kick
        LocalPlayer.Kick = function(self, reason)
            warn("[ANTI-KICK] Tentativa bloqueada: " .. tostring(reason or "Sem motivo"))
            return nil
        end

        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        setreadonly(mt, false)

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if self == LocalPlayer and (method == "Kick" or method == "kick") then
                warn("[ANTI-KICK] Namecall bloqueado!")
                return nil
            end
            return oldNamecall(self, ...)
        end)

        setreadonly(mt, true)
    end)
    print("✅ Anti-Ban / Anti-Kick carregado com sucesso")
end
--// =====================================================================

task.wait(0.1)

local Rayfield = nil
local success = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not success or not Rayfield then
    task.wait(2)
    success = pcall(function()
        Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield", true))()
    end)
end

if not Rayfield then
    warn("ERRO CRÍTICO: Não foi possivel carregar Rayfield.")
    return
end

--// REMOVE NOTIFICAÇÕES DO RAYFIELD
local OldNotify = Rayfield.Notify
Rayfield.Notify = function(self, tbl)
    if not tbl or not tbl.Title then
        return OldNotify(self, tbl)
    end
    local title = tostring(tbl.Title):lower()
    if title == "rayfield" or title == "sirius" then
        return
    end
    return OldNotify(self, tbl)
end

--// RENAME FIX + DRAG NO BOTÃO DA TOPBAR
task.spawn(function()
    task.wait(2)
    pcall(function()
        for _, v in ipairs(game.CoreGui:GetDescendants()) do
            if v:IsA("TextLabel") and (v.Text == "Show Rayfield" or v.Text:find("Rayfield")) then
                v.Text = "Aimbot Hub"
            end
        end
    end)

    -- Drag no botão de abrir/fechar a UI (topbar do Rayfield)
    pcall(function()
        local topbarButton = nil

        -- Procura o frame/button da topbar do Rayfield no CoreGui
        for _, v in ipairs(game.CoreGui:GetDescendants()) do
            if (v:IsA("TextButton") or v:IsA("Frame") or v:IsA("ImageButton")) then
                local name = v.Name:lower()
                if name:find("toggle") or name:find("open") or name:find("topbar") or name:find("dragbar") or name:find("main") then
                    if v.AbsoluteSize.X > 80 and v.AbsoluteSize.X < 400 and v.AbsoluteSize.Y < 60 then
                        topbarButton = v
                        break
                    end
                end
            end
        end

        if not topbarButton then return end

        local originalPosition = topbarButton.Position
        local draggingTopbar   = false
        local dragStartPos     = nil
        local dragStartObjPos  = nil

        -- Botão de reset (aparece ao lado do topbar quando arrastado)
        local ResetGui = Instance.new("ScreenGui")
        ResetGui.Name = "TopbarReset"
        ResetGui.ResetOnSpawn = false
        ResetGui.Parent = game.CoreGui

        local ResetBtn = Instance.new("TextButton")
        ResetBtn.Parent = ResetGui
        ResetBtn.Size = UDim2.new(0, 36, 0, 22)
        ResetBtn.Position = UDim2.new(0.5, -18, 0, 6)
        ResetBtn.BackgroundColor3 = Color3.fromRGB(160, 0, 0)
        ResetBtn.Text = "⟳"
        ResetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        ResetBtn.TextSize = 16
        ResetBtn.Font = Enum.Font.GothamBold
        ResetBtn.BorderSizePixel = 0
        ResetBtn.Visible = false

        local ResetCorner = Instance.new("UICorner")
        ResetCorner.CornerRadius = UDim.new(0, 6)
        ResetCorner.Parent = ResetBtn

        ResetBtn.MouseButton1Click:Connect(function()
            topbarButton.Position = originalPosition
            ResetBtn.Visible = false
        end)

        topbarButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingTopbar  = true
                dragStartPos    = input.Position
                dragStartObjPos = topbarButton.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        draggingTopbar = false
                    end
                end)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if draggingTopbar and (
                input.UserInputType == Enum.UserInputType.Touch or
                input.UserInputType == Enum.UserInputType.MouseMovement
            ) then
                local delta = input.Position - dragStartPos
                topbarButton.Position = UDim2.new(
                    dragStartObjPos.X.Scale,
                    dragStartObjPos.X.Offset + delta.X,
                    dragStartObjPos.Y.Scale,
                    dragStartObjPos.Y.Offset + delta.Y
                )
                ResetBtn.Visible = true
            end
        end)
    end)
end)

--// SERVICES
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local Lighting = game:GetService("Lighting")

--// VARIABLES
local Aimbot = false
local AimbotFix = false
local AimbotFixEnabled = false
local LockedTarget = nil
local AimPart = "Head"

local ESP = false
local Names = false
local DistanceESP = false
local TracerESP = false
local HealthESP = false
local TeamCheck = false
local WallCheck = true
local AimSmoothness = 4
local NameESPColor = Color3.fromRGB(0,255,0)

local FOVCircle = false
local FOVRadius = 150
local FOVThickness = 4
local FOVTransparency = 0
local FOVColor = Color3.fromRGB(255,0,0)
local FOVRainbow = false

local AntiLag = false
local ShowFPS = false
local RedMode = false
local TargetFPS = 60

--// CAMERA FIX
local OriginalAutoRotate = true

--// ==================== LOCK ====================
local MAX_LOCK_DISTANCE = 300

local function GetTargetPart(Character)
    if AimPart == "Head" then
        return Character:FindFirstChild("Head")
    elseif AimPart == "Body" then
        return Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("UpperTorso") or Character:FindFirstChild("Torso")
    end
    return Character:FindFirstChild("Head")
end

local function GetClosestPlayer()
    local ClosestPlayer = nil
    local shortestDistance = MAX_LOCK_DISTANCE
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    for _, v in ipairs(Players:GetPlayers()) do
        if v == LocalPlayer or (TeamCheck and v.Team == LocalPlayer.Team) then continue end
        local Char = v.Character
        if not Char then continue end
        local Hum = Char:FindFirstChildOfClass("Humanoid")
        if not Hum or Hum.Health <= 0 then continue end
        local Root = Char:FindFirstChild("HumanoidRootPart")
        if not Root then continue end

        local distance = (Root.Position - myRoot.Position).Magnitude
        if distance < shortestDistance then
            shortestDistance = distance
            ClosestPlayer = v
        end
    end
    return ClosestPlayer
end

local function ShouldReleaseTarget()
    if not LockedTarget or not LockedTarget.Character then return true end
    local Hum = LockedTarget.Character:FindFirstChildOfClass("Humanoid")
    if not Hum or Hum.Health <= 0 then return true end

    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot = LockedTarget.Character:FindFirstChild("HumanoidRootPart")
    if myRoot and targetRoot and (targetRoot.Position - myRoot.Position).Magnitude > 150 then
        return true
    end
    return false
end

local function ApplyCameraFix()
    if not LocalPlayer.Character then return end
    local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if Humanoid then
        OriginalAutoRotate = Humanoid.AutoRotate
        Humanoid.AutoRotate = false
    end
end

local function RemoveCameraFix()
    if not LocalPlayer.Character then return end
    local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if Humanoid then
        Humanoid.AutoRotate = OriginalAutoRotate
    end
end

--// THEME
local Theme = {
    -- Textos
    TextColor = Color3.fromRGB(255, 255, 255),

    -- Fundos principais (preto fosco)
    Background = Color3.fromRGB(10, 10, 10),
    Topbar = Color3.fromRGB(15, 15, 15),
    Shadow = Color3.fromRGB(0, 0, 0),

    -- Notificações
    NotificationBackground = Color3.fromRGB(10, 10, 10),
    NotificationActionsBackground = Color3.fromRGB(20, 20, 20),

    -- Abas (preto fosco; selecionada em vermelho escuro brilhante)
    TabBackground = Color3.fromRGB(15, 15, 15),
    TabStroke = Color3.fromRGB(30, 30, 30),
    TabBackgroundSelected = Color3.fromRGB(160, 0, 0),
    TabTextColor = Color3.fromRGB(180, 180, 180),
    SelectedTabTextColor = Color3.fromRGB(255, 255, 255),

    -- Elementos (preto fosco com borda sutil)
    ElementBackground = Color3.fromRGB(18, 18, 18),
    ElementBackgroundHover = Color3.fromRGB(28, 28, 28),
    SecondaryElementBackground = Color3.fromRGB(22, 22, 22),
    ElementStroke = Color3.fromRGB(35, 35, 35),
    SecondaryElementStroke = Color3.fromRGB(45, 45, 45),

    -- Slider (trilho preto, progresso em vermelho escuro brilhante)
    SliderBackground = Color3.fromRGB(20, 20, 20),
    SliderProgress = Color3.fromRGB(180, 0, 0),
    SliderStroke = Color3.fromRGB(200, 0, 0),

    -- Toggle (desligado preto, ligado vermelho escuro brilhante)
    ToggleBackground = Color3.fromRGB(18, 18, 18),
    ToggleEnabled = Color3.fromRGB(180, 0, 0),
    ToggleDisabled = Color3.fromRGB(40, 40, 40),
    ToggleEnabledStroke = Color3.fromRGB(210, 0, 0),
    ToggleDisabledStroke = Color3.fromRGB(60, 60, 60),
    ToggleEnabledOuterStroke = Color3.fromRGB(160, 0, 0),
    ToggleDisabledOuterStroke = Color3.fromRGB(35, 35, 35),

    -- Dropdown
    DropdownSelected = Color3.fromRGB(160, 0, 0),
    DropdownUnselected = Color3.fromRGB(18, 18, 18),

    -- Input
    InputBackground = Color3.fromRGB(18, 18, 18),
    InputStroke = Color3.fromRGB(35, 35, 35),
    PlaceholderColor = Color3.fromRGB(120, 120, 120)
}

--// WINDOW
local Window = Rayfield:CreateWindow({
    Name = "Aimbot Hub Universal",
    LoadingTitle = "Carregando...",
    LoadingSubtitle = "Aimbot Hub",
    Theme = Theme,
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
    Size = UDim2.new(0, 520, 0, 440)
})

--// TABS
-- Ícones únicos por aba:
-- Aimbot : 4483345998  (mira/crosshair)
-- FOV    : 7733920644  (círculo/lupa)
-- ESP    : 6023426926  (olho)
-- FPS    : 4666593447  (velocímetro)
local Main   = Window:CreateTab("Aimbot", 4483345998)
local FOVTab = Window:CreateTab("FOV",    7733920644)
local Visual = Window:CreateTab("ESP",    6023426926)
local FPSUI  = Window:CreateTab("FPS",    4666593447)

--// FOV CIRCLE GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FOVCircle"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game.CoreGui

local Circle = Instance.new("Frame")
Circle.Parent = ScreenGui
Circle.AnchorPoint = Vector2.new(0.5, 0.5)
Circle.Position = UDim2.new(0.5, 0, 0.5, 0)
Circle.BackgroundTransparency = 1
Circle.BorderSizePixel = 0
Circle.Visible = false

local CircleCorner = Instance.new("UICorner")
CircleCorner.CornerRadius = UDim.new(1, 0)
CircleCorner.Parent = Circle

local Stroke = Instance.new("UIStroke")
Stroke.Parent = Circle
Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
Stroke.LineJoinMode = Enum.LineJoinMode.Round
Stroke.Thickness = FOVThickness
Stroke.Color = FOVColor
Stroke.Transparency = FOVTransparency

--// FPS COUNTER GUI
local FPSGui = Instance.new("ScreenGui")
FPSGui.Name = "FPSCounter"
FPSGui.IgnoreGuiInset = true
FPSGui.ResetOnSpawn = false
FPSGui.Parent = game.CoreGui

local FPSFrame = Instance.new("Frame")
FPSFrame.Parent = FPSGui
FPSFrame.Size = UDim2.new(0, 98, 0, 48)
FPSFrame.Position = UDim2.new(0.03, 0, 0.22, 0)
FPSFrame.BackgroundTransparency = 0.4
FPSFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
FPSFrame.Visible = false

local FPSCorner = Instance.new("UICorner")
FPSCorner.CornerRadius = UDim.new(1, 0)
FPSCorner.Parent = FPSFrame

local FPSStroke = Instance.new("UIStroke")
FPSStroke.Parent = FPSFrame
FPSStroke.Thickness = 2
FPSStroke.Color = Color3.fromRGB(255, 0, 0)
FPSStroke.Transparency = 0.1

local FPSGlow = Instance.new("UIStroke")
FPSGlow.Parent = FPSFrame
FPSGlow.Thickness = 5
FPSGlow.Color = Color3.fromRGB(255, 0, 0)
FPSGlow.Transparency = 0.8
FPSGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

local FPSText = Instance.new("TextLabel")
FPSText.Parent = FPSFrame
FPSText.Size = UDim2.new(1, 0, 1, 0)
FPSText.BackgroundTransparency = 1
FPSText.Text = "FPS: 60"
FPSText.TextColor3 = Color3.fromRGB(255, 255, 255)
FPSText.TextSize = 29
FPSText.Font = Enum.Font.GothamBold
FPSText.TextStrokeTransparency = 0.6
FPSText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

--// FLOATING BUTTON
local MobileGui = Instance.new("ScreenGui")
MobileGui.Name = "AimbotFixButton"
MobileGui.ResetOnSpawn = false
MobileGui.Parent = game.CoreGui

local ToggleButton = Instance.new("TextButton")
ToggleButton.Parent = MobileGui
ToggleButton.Size = UDim2.new(0,58,0,58)
ToggleButton.Position = UDim2.new(0.82,0,0.7,0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(20,20,20)
ToggleButton.Text = "OFF"
ToggleButton.TextScaled = false
ToggleButton.TextSize = 18
ToggleButton.Font = Enum.Font.GothamBlack
ToggleButton.TextColor3 = Color3.fromRGB(0,0,0)
ToggleButton.TextStrokeTransparency = 0.2
ToggleButton.TextStrokeColor3 = Color3.fromRGB(0,0,0)
ToggleButton.BorderSizePixel = 0
ToggleButton.Visible = false

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(1,0)
Corner.Parent = ToggleButton

local StrokeButton = Instance.new("UIStroke")
StrokeButton.Parent = ToggleButton
StrokeButton.Thickness = 3
StrokeButton.Color = Color3.fromRGB(255,0,0)

local BlackStroke = Instance.new("UIStroke")
BlackStroke.Parent = ToggleButton
BlackStroke.Thickness = 1.2
BlackStroke.Color = Color3.fromRGB(0,0,0)
BlackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local Gradient = Instance.new("UIGradient")
Gradient.Parent = ToggleButton
Gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80,0,0))
}

task.spawn(function()
    while task.wait() do
        TweenService:Create(Gradient, TweenInfo.new(2, Enum.EasingStyle.Linear), {Rotation = Gradient.Rotation + 180}):Play()
        task.wait(2)
    end
end)

--// DRAG BUTTON
local dragging = false
local dragInput
local dragStart
local startPos

ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = ToggleButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

ToggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        ToggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

--// AIMBOT FIX FUNCTIONS
local function UpdateButtonVisibility()
    ToggleButton.Visible = AimbotFixEnabled
end

local function ToggleAimbotFix(active)
    AimbotFix = active
    if active then
        ApplyCameraFix()
        ToggleButton.Text = "ON"
        TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255,0,0)}):Play()
    else
        RemoveCameraFix()
        LockedTarget = nil
        ToggleButton.Text = "OFF"
        TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20,20,20)}):Play()
    end
end

--// UI ELEMENTS - AIMBOT TAB
Main:CreateToggle({Name = "Aimbot", CurrentValue = false, Callback = function(v)
    Aimbot = v
    if not v then LockedTarget = nil end
    if v and AimbotFixEnabled then
        Rayfield:Notify({Title = "⚠️ AVISO", Content = "Não use Aimbot e Aimbot Fix ao mesmo tempo, Pois não vai funcionar.", Duration = 6})
    end
end})

Main:CreateToggle({Name = "Enable Aimbot Pro", CurrentValue = false, Callback = function(v)
    AimbotFixEnabled = v
    ToggleAimbotFix(v)
    UpdateButtonVisibility()
end})

Main:CreateToggle({Name = "Wall Check", CurrentValue = true, Callback = function(v) WallCheck = v end})

Main:CreateDropdown({Name = "Aim Part", Options = {"Head", "Body"}, CurrentOption = {"Head"}, Callback = function(Option)
    AimPart = Option[1]
    LockedTarget = nil
end})

Main:CreateSlider({Name = "Aimbot Smoothness", Range = {1,30}, Increment = 1, Suffix = "Smooth", CurrentValue = 4, Callback = function(v) AimSmoothness = v end})

--// ESP TAB
Visual:CreateToggle({Name = "Team Check", CurrentValue = false, Callback = function(v) TeamCheck = v end})
Visual:CreateToggle({Name = "Player ESP", CurrentValue = false, Callback = function(v) ESP = v end})
Visual:CreateToggle({Name = "Name ESP", CurrentValue = false, Callback = function(v) Names = v end})
Visual:CreateToggle({Name = "Distance ESP", CurrentValue = false, Callback = function(v) DistanceESP = v end})
Visual:CreateToggle({Name = "Tracer ESP", CurrentValue = false, Callback = function(v) TracerESP = v end})
Visual:CreateToggle({Name = "Health ESP", CurrentValue = false, Callback = function(v) HealthESP = v end})
-- Name ESP Color agora segue automaticamente a cor do time (verde aliado / vermelho inimigo)

--// FOV TAB
FOVTab:CreateToggle({Name = "Enable Circle", CurrentValue = false, Callback = function(v) FOVCircle = v end})
FOVTab:CreateSlider({Name = "Circle Size", Range = {50,250}, Increment = 5, Suffix = "PX", CurrentValue = 150, Callback = function(v) FOVRadius = v end})
FOVTab:CreateSlider({Name = "Circle Thickness", Range = {1,30}, Increment = 1, Suffix = "PX", CurrentValue = 4, Callback = function(v) FOVThickness = v end})
FOVTab:CreateSlider({Name = "Circle Transparency", Range = {0,1}, Increment = 0.05, Suffix = "", CurrentValue = 0, Callback = function(v) FOVTransparency = v end})
FOVTab:CreateColorPicker({Name = "Circle Color", Color = Color3.fromRGB(255,0,0), Callback = function(v) FOVColor = v end})
FOVTab:CreateToggle({Name = "RGB", CurrentValue = false, Callback = function(v) FOVRainbow = v end})

--// FPS UI
FPSUI:CreateToggle({
    Name = "Anti Lag",
    CurrentValue = false,
    Callback = function(v)
        AntiLag = v
        pcall(function()
            if v then
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 1000000
                Lighting.Brightness = 1
                Lighting.ClockTime = 12
                Lighting.EnvironmentDiffuseScale = 0
                Lighting.EnvironmentSpecularScale = 0
                Lighting.Technology = Enum.Technology.Compatibility

                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                        obj.Enabled = false
                    elseif obj:IsA("BasePart") then
                        obj.Material = Enum.Material.Plastic
                        obj.Reflectance = 0
                    end
                end
            else
                settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
                Lighting.GlobalShadows = true
                Lighting.Technology = Enum.Technology.Future
            end
        end)
    end
})

FPSUI:CreateToggle({Name = "Show FPS", CurrentValue = false, Callback = function(v)
    ShowFPS = v
    FPSFrame.Visible = v
end})

FPSUI:CreateToggle({Name = "RED Mode", CurrentValue = false, Callback = function(v) RedMode = v end})

FPSUI:CreateDropdown({Name = "FPS Limit", Options = {"30", "60", "120", "240", "Unlimited"}, CurrentOption = {"60"}, Callback = function(Option)
    TargetFPS = Option[1] == "Unlimited" and 9999 or tonumber(Option[1])
    if setfpscap then setfpscap(TargetFPS) end
end})

--// GET CLOSEST PLAYER FOR AIMBOT NORMAL
local function GetClosestPlayerForAimbot()
    local Closest, ClosestDistance = nil, math.huge
    local Center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for _, v in ipairs(Players:GetPlayers()) do
        if v == LocalPlayer or (TeamCheck and v.Team == LocalPlayer.Team) then continue end
        local Char = v.Character
        if not Char then continue end

        local Hum = Char:FindFirstChildOfClass("Humanoid")
        if not Hum or Hum.Health <= 0 then continue end

        local TargetPart = GetTargetPart(Char)
        if not TargetPart then continue end

        local Pos, Visible = Camera:WorldToViewportPoint(TargetPart.Position)
        if not Visible or Pos.Z <= 0 then continue end

        if WallCheck then
            local Params = RaycastParams.new()
            Params.FilterType = Enum.RaycastFilterType.Blacklist
            Params.FilterDescendantsInstances = {LocalPlayer.Character}
            local Result = workspace:Raycast(Camera.CFrame.Position, TargetPart.Position - Camera.CFrame.Position, Params)
            if Result and not Result.Instance:IsDescendantOf(Char) then continue end
        end

        local Distance = (Vector2.new(Pos.X, Pos.Y) - Center).Magnitude
        if Distance > FOVRadius then continue end

        if Distance < ClosestDistance then
            ClosestDistance = Distance
            Closest = TargetPart
        end
    end
    return Closest
end

--// FUNÇÃO COR DA BARRA DE VIDA (3 cores: verde > amarelo > vermelho)
local function GetHealthColor(ratio)
    -- ratio: 1.0 = vida cheia (verde), 0.5 = meio (amarelo), 0.0 = morto (vermelho)
    if ratio >= 0.5 then
        -- verde -> amarelo (de 1.0 até 0.5)
        local t = (ratio - 0.5) / 0.5  -- 1.0 no topo, 0.0 no meio
        return Color3.fromRGB(
            math.floor(255 * (1 - t)),  -- R sobe de 0 a 255
            255,                         -- G fixo em 255
            0
        )
    else
        -- amarelo -> vermelho (de 0.5 até 0.0)
        local t = ratio / 0.5  -- 1.0 no meio, 0.0 no fundo
        return Color3.fromRGB(
            255,                         -- R fixo em 255
            math.floor(255 * t),         -- G desce de 255 a 0
            0
        )
    end
end

--// ESP
local Highlights = {}
local Drawings = {}
local TracerLines = {}
local HealthBars = {}

-- Cache do MaxHealth por player (resolve jogos que iniciam com Health=0)
local MaxHealthCache = {}

local ESP_MAX_DISTANCE = 500  -- ignora players além desta distância (lobby, etc)

local function CreateESP(Player)
    if Player == LocalPlayer then return end

    -- Highlight
    local Highlight = Instance.new("Highlight")
    Highlight.FillTransparency = 0.5
    Highlight.OutlineTransparency = 0
    Highlight.Enabled = false
    Highlight.Parent = game.CoreGui
    Highlights[Player] = Highlight

    -- Name + Distance label
    local Text = Drawing.new("Text")
    Text.Size = 13
    Text.Font = 2
    Text.Center = true
    Text.Outline = true
    Text.Visible = false
    Drawings[Player] = Text

    -- Tracer line
    local Tracer = Drawing.new("Line")
    Tracer.Thickness = 1
    Tracer.Transparency = 1
    Tracer.Visible = false
    TracerLines[Player] = Tracer

    -- Health bar: borda preta (BG), fundo escuro (Inner), preenchimento (Fill)
    local HealthBarBG = Drawing.new("Square")
    HealthBarBG.Filled = true
    HealthBarBG.Color = Color3.fromRGB(0, 0, 0)
    HealthBarBG.Transparency = 1
    HealthBarBG.Visible = false

    local HealthBarInner = Drawing.new("Square")
    HealthBarInner.Filled = true
    HealthBarInner.Color = Color3.fromRGB(20, 20, 20)
    HealthBarInner.Transparency = 0.7
    HealthBarInner.Visible = false

    local HealthBarFill = Drawing.new("Square")
    HealthBarFill.Filled = true
    HealthBarFill.Color = Color3.fromRGB(0, 255, 0)
    HealthBarFill.Transparency = 1
    HealthBarFill.Visible = false

    HealthBars[Player] = {BG = HealthBarBG, Inner = HealthBarInner, Fill = HealthBarFill}
end

for _, p in ipairs(Players:GetPlayers()) do CreateESP(p) end
Players.PlayerAdded:Connect(CreateESP)

Players.PlayerRemoving:Connect(function(Player)
    if Highlights[Player] then Highlights[Player]:Destroy() Highlights[Player] = nil end
    if Drawings[Player] then Drawings[Player]:Remove() Drawings[Player] = nil end
    if TracerLines[Player] then TracerLines[Player]:Remove() TracerLines[Player] = nil end
    if HealthBars[Player] then
        HealthBars[Player].BG:Remove()
        HealthBars[Player].Inner:Remove()
        HealthBars[Player].Fill:Remove()
        HealthBars[Player] = nil
    end
    MaxHealthCache[Player] = nil
end)

--// MAIN LOOP
RunService.RenderStepped:Connect(function()
    -- FOV Circle
    Circle.Position = UDim2.new(0, Camera.ViewportSize.X/2, 0, Camera.ViewportSize.Y/2)
    Circle.Size = UDim2.new(0, FOVRadius*2, 0, FOVRadius*2)
    Circle.Visible = FOVCircle
    Stroke.Thickness = FOVThickness
    Stroke.Transparency = FOVTransparency
    Stroke.Color = FOVRainbow and Color3.fromHSV(tick()%5/5, 1, 1) or FOVColor

    -- Aimbot logic
    if AimbotFix and AimbotFixEnabled then
        if ShouldReleaseTarget() then
            LockedTarget = GetClosestPlayer()
        end
        if not LockedTarget then
            LockedTarget = GetClosestPlayer()
        end

        if LockedTarget and LockedTarget.Character then
            local Target = GetTargetPart(LockedTarget.Character)
            if Target then
                local Root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if Root then
                    local LookPos = Vector3.new(Target.Position.X, Root.Position.Y, Target.Position.Z)
                    Root.CFrame = CFrame.lookAt(Root.Position, LookPos)
                end
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, Target.Position)
            end
        end
    elseif Aimbot then
        local Target = GetClosestPlayerForAimbot()
        if Target then
            local TargetCFrame = CFrame.lookAt(Camera.CFrame.Position, Target.Position)
            Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, 1 / AimSmoothness)
        end
    end

    -- ESP loop
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for Player, Highlight in pairs(Highlights) do
        local Char = Player.Character
        local Text = Drawings[Player]
        local Tracer = TracerLines[Player]
        local HBar = HealthBars[Player]

        local function HideAll()
            if Highlight then Highlight.Enabled = false end
            if Text then Text.Visible = false end
            if Tracer then Tracer.Visible = false end
            if HBar then
                HBar.BG.Visible    = false
                HBar.Inner.Visible = false
                HBar.Fill.Visible  = false
            end
        end

        if not Char then HideAll() continue end

        local Hum  = Char:FindFirstChildOfClass("Humanoid")
        local Root = Char:FindFirstChild("HumanoidRootPart")
        local Head = Char:FindFirstChild("Head")

        if not Hum or Hum.Health <= 0 or not Root then HideAll() continue end

        -- Filtro de distância: ignora players muito longe (lobby, outras regiões do mapa)
        if myRoot then
            local worldDist = (Root.Position - myRoot.Position).Magnitude
            if worldDist > ESP_MAX_DISTANCE then HideAll() continue end
        end

        -- Cor por time
        local IsEnemy   = (Player.Team ~= LocalPlayer.Team)
        local TeamColor = IsEnemy and Color3.fromRGB(255,0,0) or Color3.fromRGB(0,255,0)

        -- Player Highlight ESP
        Highlight.Adornee      = Char
        Highlight.FillColor    = TeamColor
        Highlight.OutlineColor = TeamColor
        Highlight.Enabled      = ESP

        -- Posição 3D → 2D
        local HeadWorld = Head and (Head.Position + Vector3.new(0, 2.8, 0)) or Root.Position
        local HeadPos   = Camera:WorldToViewportPoint(HeadWorld)
        local RootPos   = Camera:WorldToViewportPoint(Root.Position)
        local headX, headY = HeadPos.X, HeadPos.Y
        local behindCam = (HeadPos.Z < 0) or (RootPos.Z < 0)

        local Dist = math.floor((Camera.CFrame.Position - Root.Position).Magnitude)

        -- Name ESP + Distance ESP
        if Text then
            if (Names or DistanceESP) and not behindCam then
                local label = ""
                if Names then label = Player.Name end
                if DistanceESP then
                    label = label .. (label ~= "" and " " or "") .. "[" .. Dist .. "m]"
                end
                Text.Text     = label
                Text.Position = Vector2.new(headX, headY)
                Text.Color    = TeamColor
                Text.Visible  = true
            else
                Text.Visible = false
            end
        end

        -- Tracer ESP
        if Tracer then
            if TracerESP and not behindCam then
                Tracer.From         = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                Tracer.To           = Vector2.new(RootPos.X, RootPos.Y)
                Tracer.Color        = TeamColor
                Tracer.Thickness    = 1
                Tracer.Transparency = 1
                Tracer.Visible      = true
            else
                Tracer.Visible = false
            end
        end

        -- Health Bar ESP
        if HBar then
            if HealthESP and not behindCam then
                local dist3d    = (Camera.CFrame.Position - Root.Position).Magnitude
                local barWidth  = math.clamp(120 - dist3d * 0.18, 36, 120)
                local barHeight = 2
                local border    = 1

                -- FIX CACHE: atualiza MaxHealth só quando o valor for válido e estável
                -- Resolve jogos que iniciam Health=0 e MaxHealth=100 ao mesmo tempo
                local curMax = Hum.MaxHealth
                local curHp  = Hum.Health

                -- Atualiza cache somente se curMax for um número positivo real
                if curMax and curMax == curMax and curMax > 0 then
                    -- Só sobe o cache, nunca desce (evita piscar durante respawn)
                    if not MaxHealthCache[Player] or curMax > MaxHealthCache[Player] then
                        MaxHealthCache[Player] = curMax
                    end
                end

                local maxHp = MaxHealthCache[Player] or 100
                local hp    = (curHp and curHp == curHp and curHp >= 0) and curHp or maxHp
                if hp > maxHp then hp = maxHp end

                local healthRatio = math.clamp(hp / maxHp, 0, 1)
                local healthColor = GetHealthColor(healthRatio)

                local barX = headX - barWidth / 2
                local barY = headY - 15

                HBar.BG.Size     = Vector2.new(barWidth + border * 2, barHeight + border * 2)
                HBar.BG.Position = Vector2.new(barX - border, barY - border)
                HBar.BG.Visible  = true

                HBar.Inner.Size     = Vector2.new(barWidth, barHeight)
                HBar.Inner.Position = Vector2.new(barX, barY)
                HBar.Inner.Visible  = true

                -- fillWidth = 0 quando hp=0 (barra vazia de verdade)
                local fillWidth = barWidth * healthRatio
                if fillWidth < 1 and healthRatio > 0 then fillWidth = 1 end
                HBar.Fill.Size     = Vector2.new(fillWidth, barHeight)
                HBar.Fill.Position = Vector2.new(barX, barY)
                HBar.Fill.Color    = healthColor
                HBar.Fill.Visible  = (healthRatio > 0)
            else
                HBar.BG.Visible    = false
                HBar.Inner.Visible = false
                HBar.Fill.Visible  = false
            end
        end
    end
end)

--// FPS COUNTER
local lastTime = tick()
local frameCount = 0
local hue = 0

RunService.RenderStepped:Connect(function()
    if not ShowFPS then return end
    frameCount += 1
    local currentTime = tick()
    if currentTime - lastTime >= 0.1 then
        local fps = math.floor(frameCount / (currentTime - lastTime))
        FPSText.Text = "FPS: " .. tostring(fps)

        if RedMode then
            local t = tick() * 3
            local alpha = (math.sin(t) + 1) / 2
            local color = Color3.fromRGB(160, math.floor(40 * alpha), math.floor(40 * alpha))
            FPSText.TextColor3 = color
            FPSStroke.Color = color
            FPSGlow.Color = color
        else
            hue = (hue + 0.035) % 1
            local color = Color3.fromHSV(hue, 1, 1)
            FPSText.TextColor3 = color
            FPSStroke.Color = color
            FPSGlow.Color = color
        end

        frameCount = 0
        lastTime = currentTime
    end
end)

--// BUTTON CLICK
ToggleButton.MouseButton1Click:Connect(function()
    ToggleAimbotFix(not AimbotFix)
end)

--// NOTIFICAÇÕES FINAIS
task.spawn(function()
    repeat task.wait() until Window

    Rayfield:Notify({
        Title = "Aimbot Hub Universal",
        Content = "Carregado com sucesso.",
        Duration = 6,
        Image = 4483362458
    })

    task.wait(0.2)

    pcall(function()
        if setclipboard then
            setclipboard("https://discord.gg/rZuYzZ7zvt")

            Rayfield:Notify({
                Title = "Script Link Server Discord.",
                Content = "Link do Discord copiado",
                Duration = 6,
                Image = 6031225819
            })
        end
    end)
end)
