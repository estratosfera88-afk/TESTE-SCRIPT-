-- [[ AKATSUKI UI ONLY [v3.6] ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer

-- ==================== ESTADO DOS TOGGLES DA UI ====================
local Configs = {
    ESP = false,
    Aimbot = false, 
    Speed = false,
    Reach = false,
    AntiFling = false,
    TpToGun = false,
    SafeSpot = false,
    AutoCollect = false,
    ChatRoles = false
}

-- ==================== ASSETS (IDs verificados) ====================
local ASSETS = {
    FloatIcon = "rbxassetid://139044062702391",
    EyeOpen = "rbxassetid://103096515071530",
    EyeClosed = "rbxassetid://85795266774996",
    Sharingan = "rbxassetid://100882509796042",
    SharinganSound = "rbxassetid://6310837681",
}

-- ==================== DYNAMIC UI COMPONENT & STATE MACHINE ====================
-- Estados: OPEN, CLOSED, MINIMIZED, OPENING, CLOSING
local UIState = "CLOSED"
local isBusy = false -- trava geral contra cliques rápidos/duplicados

local UI_TEXT = {
    SearchPlaceholder = "Search...",
    ConfirmCloseTitle = "Do you want to close the script?",
    ConfirmBtn = "Confirm",
    CancelBtn = "Cancel",
    Intro = '<font color="#FFFFFF">Scripts by | </font><font color="#8B0000">AKATSUKI</font>',
    Tabs = { Player = "Player", Combat = "Combat", Visuals = "Visuals", Teleports = "Teleports", Misc = "Misc" },
    Options = {
        AutoShoot = { Title = "Aimbot Murderer", Desc = "Automatic aimbot that stays in the murderer's head non-stop." },
        Reach = { Title = "Knife Reach", Desc = "Significantly increases your knife attack reach (18 studs)." },
        ESP = { Title = "Player ESP", Desc = "Highlights players through walls (Sheriff Blue / Hero Yellow)." },
        Speed = { Title = "WalkSpeed", Desc = "Slightly increases player walkspeed up to 23 smoothly." },
        AntiFling = { Title = "Anti-Fling", Desc = "Disables collisions to prevent other players from flinging you." },
        TpToGun = { Title = "TP to Gun", Desc = "Teleports to dropped gun (Automatically disabled for the Murderer)." },
        SafeSpot = { Title = "Safe Spot", Desc = "Teleports you to an invisible sky platform to remain completely safe." },
        AutoCollect = { Title = "Auto Collect", Desc = "Smoothly collects coins continuously without clunky visual stops." },
        ChatRoles = { Title = "Reveal Roles", Desc = "Sends a message in chat revealing active roles." }
    }
}

local activeTab = "Player"
local tabButtons = {}
local isExpanded = false
local originalTrans = {}
local confirmBlur = nil
local isConfirmOpen = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeltaAkatUniversalUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then uiParent = gethui() else pcall(function() uiParent = game:GetService("CoreGui") end) end
if uiParent:FindFirstChild("DeltaAkatUniversalUI") then pcall(function() uiParent.DeltaAkatUniversalUI:Destroy() end) end
screenGui.Parent = uiParent

local function RegistrarTransparencias(objeto)
    if originalTrans[objeto] then return end
    if objeto:IsA("Frame") or objeto:IsA("ScrollingFrame") or objeto:IsA("CanvasGroup") then originalTrans[objeto] = { BackgroundTransparency = objeto.BackgroundTransparency }
    elseif objeto:IsA("TextLabel") or objeto:IsA("TextButton") or objeto:IsA("TextBox") then
        originalTrans[objeto] = { TextTransparency = objeto.TextTransparency, BackgroundTransparency = objeto.BackgroundTransparency, TextStrokeTransparency = objeto.TextStrokeTransparency or 1 }
    elseif objeto:IsA("ImageLabel") or objeto:IsA("ImageButton") then originalTrans[objeto] = { ImageTransparency = objeto.ImageTransparency, BackgroundTransparency = objeto.BackgroundTransparency }
    elseif objeto:IsA("UIStroke") then originalTrans[objeto] = { Transparency = objeto.Transparency } end
end

local function AplicarFadeSincronizado(raiz, fadeOut, duracao)
    local info = TweenInfo.new(duracao, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local function tratarObjeto(obj)
        RegistrarTransparencias(obj)
        local orig = originalTrans[obj]
        if not orig then return end
        if orig.BackgroundTransparency then
            local t = fadeOut and 1 or orig.BackgroundTransparency
            if obj.BackgroundTransparency ~= t then if duracao == 0 then obj.BackgroundTransparency = t else TweenService:Create(obj, info, {BackgroundTransparency = t}):Play() end end
        end
        if orig.TextTransparency then
            local t = fadeOut and 1 or orig.TextTransparency
            if obj.TextTransparency ~= t then if duracao == 0 then obj.TextTransparency = t else TweenService:Create(obj, info, {TextTransparency = t}):Play() end end
        end
        if orig.ImageTransparency then
            local t = fadeOut and 1 or (obj.Name == "Shadow3D" and 0.45 or orig.ImageTransparency)
            if obj.ImageTransparency ~= t then if duracao == 0 then obj.ImageTransparency = t else TweenService:Create(obj, info, {ImageTransparency = t}):Play() end end
        end
        if orig.Transparency then
            local t = fadeOut and 1 or orig.Transparency
            if obj.Transparency ~= t then if duracao == 0 then obj.Transparency = t else TweenService:Create(obj, info, {Transparency = t}):Play() end end
        end
    end
    tratarObjeto(raiz)
    for _, desc in ipairs(raiz:GetDescendants()) do tratarObjeto(desc) end
end

-- ==================== BOTÃO FLUTUANTE ====================
-- Criado e configurado já na inicialização, visível desde o início (Bug 2 corrigido)
local FloatBtn = Instance.new("ImageButton", screenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Size = UDim2.new(0, 50, 0, 50)
FloatBtn.Position = UDim2.new(0.12, 0, 0.4, 0)
FloatBtn.Image = ASSETS.FloatIcon
FloatBtn.ImageTransparency = 0
FloatBtn.ScaleType = Enum.ScaleType.Fit
FloatBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
FloatBtn.BackgroundTransparency = 0
FloatBtn.Visible = true
FloatBtn.ZIndex = 100
FloatBtn.ClipsDescendants = false
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 12)

local floatGrad = Instance.new("UIGradient", FloatBtn)
floatGrad.Rotation = 90
floatGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 8, 10)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 4, 4))
})

local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Name = "FloatStroke"
FloatStroke.Thickness = 2
local floatStrokeGradient = Instance.new("UIGradient", FloatStroke)
floatStrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(139, 0, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 0, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(139, 0, 0))
})

-- Sharingan orbitando o botão flutuante
local Sharingan = Instance.new("ImageLabel", FloatBtn)
Sharingan.Name = "SharinganEffect"
Sharingan.Size = UDim2.new(0, 18, 0, 18)
Sharingan.AnchorPoint = Vector2.new(0.5, 0.5)
Sharingan.Position = UDim2.new(0.5, 0, 0.5, 0)
Sharingan.BackgroundTransparency = 1
Sharingan.Image = ASSETS.Sharingan
Sharingan.ImageTransparency = 0
Sharingan.ScaleType = Enum.ScaleType.Fit
Sharingan.ZIndex = 105
Sharingan.Visible = true

local orbitAngle = 0
local orbitConnection
orbitConnection = RunService.RenderStepped:Connect(function(dt)
    if FloatBtn and FloatBtn.Parent then
        Sharingan.Rotation = (Sharingan.Rotation + (dt * 180)) % 360
        orbitAngle = (orbitAngle + (dt * 2.2)) % (math.pi * 2)
        local radius = 30
        Sharingan.Position = UDim2.new(0.5, math.cos(orbitAngle) * radius, 0.5, math.sin(orbitAngle) * radius)
    end
end)

local SharinganSound = Instance.new("Sound", FloatBtn)
SharinganSound.Name = "SharinganSound"
SharinganSound.SoundId = ASSETS.SharinganSound
SharinganSound.Volume = 0.4
SharinganSound.Looped = false

local dragToggle, dragStart, startPos
local floatMoved = false
FloatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragToggle = true; dragStart = input.Position; startPos = FloatBtn.Position; floatMoved = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        if delta.Magnitude > 3 then floatMoved = true end
        FloatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragToggle = false end
end)

-- ==================== INTERFACE PRINCIPAL ====================
local mainWrapper = Instance.new("Frame", screenGui)
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0.5)
mainWrapper.Size = UDim2.new(0, 560, 0, 330)
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible = false
mainWrapper.ClipsDescendants = false

-- Sombras 3D (esquerda e direita), contidas rigorosamente aos limites da UI
local ShadowLeft = Instance.new("ImageLabel", mainWrapper)
ShadowLeft.Name = "Shadow3D"
ShadowLeft.AnchorPoint = Vector2.new(0.5, 0.5)
ShadowLeft.Size = UDim2.new(1, 40, 1, 40)
ShadowLeft.Position = UDim2.new(0, -6, 0.5, 6)
ShadowLeft.BackgroundTransparency = 1
ShadowLeft.Image = "rbxassetid://6014261993"
ShadowLeft.ImageColor3 = Color3.fromRGB(0, 0, 0)
ShadowLeft.ImageTransparency = 0.45
ShadowLeft.ScaleType = Enum.ScaleType.Slice
ShadowLeft.SliceCenter = Rect.new(49, 49, 450, 450)
ShadowLeft.ZIndex = 1
ShadowLeft.Visible = false -- ativado apenas quando a UI está aberta, evita vazamento visual quando fechada

local ShadowRight = Instance.new("ImageLabel", mainWrapper)
ShadowRight.Name = "Shadow3DRight"
ShadowRight.AnchorPoint = Vector2.new(0.5, 0.5)
ShadowRight.Size = UDim2.new(1, 40, 1, 40)
ShadowRight.Position = UDim2.new(1, 6, 0.5, 6)
ShadowRight.BackgroundTransparency = 1
ShadowRight.Image = "rbxassetid://6014261993"
ShadowRight.ImageColor3 = Color3.fromRGB(0, 0, 0)
ShadowRight.ImageTransparency = 0.45
ShadowRight.ScaleType = Enum.ScaleType.Slice
ShadowRight.SliceCenter = Rect.new(49, 49, 450, 450)
ShadowRight.ZIndex = 1
ShadowRight.Visible = false

local mainFrame = Instance.new("Frame", mainWrapper)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundTransparency = 1 
mainFrame.ZIndex = 5
mainFrame.ClipsDescendants = false

local dragUIToggle, dragUIStart, startUIPos
mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragUIToggle = true; dragUIStart = input.Position; startUIPos = mainWrapper.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragUIToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragUIStart
        mainWrapper.Position = UDim2.new(startUIPos.X.Scale, startUIPos.X.Offset + delta.X, startUIPos.Y.Scale, startUIPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragUIToggle = false end
end)

-- Painel com gradient vermelho ANIMADO (rotação contínua e suave)
local function CreateGradientPanel(parent, size, pos, name, cornerRadius)
    local panel = Instance.new("Frame", parent)
    panel.Name = name
    panel.Size = size
    panel.Position = pos
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ZIndex = 5
    panel.ClipsDescendants = true

    local InnerBg = Instance.new("Frame", panel)
    InnerBg.Name = "InnerBg"
    InnerBg.Size = UDim2.new(1, 0, 1, 0)
    InnerBg.BackgroundColor3 = Color3.fromRGB(15, 8, 10)
    InnerBg.BorderSizePixel = 0
    InnerBg.ClipsDescendants = true
    InnerBg.ZIndex = 5
    Instance.new("UICorner", InnerBg).CornerRadius = UDim.new(0, cornerRadius or 14)

    local overlay = Instance.new("Frame", InnerBg)
    overlay.Name = "RedGradientOverlay"
    overlay.AnchorPoint = Vector2.new(0.5, 0.5)
    overlay.Size = UDim2.new(1.8, 0, 1.8, 0)
    overlay.Position = UDim2.new(0.5, 0, 0.5, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 5

    local redGrad = Instance.new("UIGradient", overlay)
    redGrad.Rotation = 90
    redGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 0, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 10, 15)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 0, 0))
    })
    redGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(0.5, 0.25),
        NumberSequenceKeypoint.new(1, 0.7)
    })

    -- Animação de rotação lenta, contínua e elegante (não pisca, não troca de cor bruscamente)
    RunService.RenderStepped:Connect(function(dt)
        if panel and panel.Parent then
            redGrad.Rotation = (redGrad.Rotation + (dt * 6)) % 360
        end
    end)

    local lightBeam = Instance.new("Frame", InnerBg)
    lightBeam.Name = "LightBeam"
    lightBeam.Size = UDim2.new(2, 0, 2, 0)
    lightBeam.AnchorPoint = Vector2.new(0.5, 0.5)
    lightBeam.Position = UDim2.new(0.5, 0, 0.5, 0)
    lightBeam.BackgroundTransparency = 1
    lightBeam.ZIndex = 6

    local beamGrad = Instance.new("UIGradient", lightBeam)
    beamGrad.Rotation = 45
    beamGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 80)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
    })
    beamGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.93),
        NumberSequenceKeypoint.new(1, 1)
    })

    RunService.RenderStepped:Connect(function(dt)
        if panel and panel.Parent then
            beamGrad.Rotation = (beamGrad.Rotation + (dt * 15)) % 360
        end
    end)
    
    local stroke = Instance.new("UIStroke", InnerBg)
    stroke.Color = Color3.fromRGB(60, 20, 25)
    stroke.Thickness = 1.2
    
    return panel
end

local LeftPanel = CreateGradientPanel(mainFrame, UDim2.new(0, 175, 1, 0), UDim2.new(0, 0, 0, 0), "LeftPanel", 14)
local RightPanel = CreateGradientPanel(mainFrame, UDim2.new(1, -183, 1, 0), UDim2.new(0, 183, 0, 0), "RightPanel", 14)

-- ==================== LEFT PANEL CONTENT ====================
-- Título e subtítulo maiores, centralizados no topo (hierarquia clara)
local titleContainer = Instance.new("Frame", LeftPanel)
titleContainer.Size = UDim2.new(1, -12, 0, 46)
titleContainer.Position = UDim2.new(0, 6, 0, 6)
titleContainer.BackgroundTransparency = 1
titleContainer.ZIndex = 10

local title = Instance.new("TextLabel", titleContainer)
title.Size = UDim2.new(1, 0, 0, 22)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "AKATSUKI SCRIPTS"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextSize = 15
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Center
title.TextScaled = false
title.ZIndex = 11

local subtitle = Instance.new("TextLabel", titleContainer)
subtitle.Size = UDim2.new(1, 0, 0, 16)
subtitle.Position = UDim2.new(0, 0, 0, 24)
subtitle.BackgroundTransparency = 1
subtitle.Text = "MM2 SCRIPT | by zeni <3"
subtitle.TextColor3 = Color3.fromRGB(220, 50, 50)
subtitle.TextTransparency = 0.25
subtitle.TextSize = 10.5
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Center
subtitle.ZIndex = 11

local LeftSeparatorLine = Instance.new("Frame", LeftPanel)
LeftSeparatorLine.Size = UDim2.new(1, 0, 0, 1)
LeftSeparatorLine.Position = UDim2.new(0, 0, 0, 56)
LeftSeparatorLine.BackgroundColor3 = Color3.fromRGB(80, 20, 25)
LeftSeparatorLine.BorderSizePixel = 0
LeftSeparatorLine.ZIndex = 10

-- Tabs maiores, com espaçamento confortável
local TabsContainer = Instance.new("ScrollingFrame", LeftPanel)
TabsContainer.Name = "TabsContainer"
TabsContainer.Size = UDim2.new(1, 0, 1, -122)
TabsContainer.Position = UDim2.new(0, 0, 0, 64)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ZIndex = 10
TabsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
TabsContainer.ScrollBarThickness = 2
TabsContainer.ScrollBarImageColor3 = Color3.fromRGB(139, 0, 0)
TabsContainer.ScrollBarImageTransparency = 0.5

local TabsLayout = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabsLayout.Padding = UDim.new(0, 8)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TabsContainer.CanvasSize = UDim2.new(0, 0, 0, TabsLayout.AbsoluteContentSize.Y + 8)
end)

-- Badge do usuário: estilo dark glass moderno
local UserProfileFrame = Instance.new("Frame", LeftPanel)
UserProfileFrame.Size = UDim2.new(1, -14, 0, 50)
UserProfileFrame.Position = UDim2.new(0, 7, 1, -58)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(14, 9, 11)
UserProfileFrame.BackgroundTransparency = 0.12
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex = 10
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 12)

local profileGlassGrad = Instance.new("UIGradient", UserProfileFrame)
profileGlassGrad.Rotation = 90
profileGlassGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 16, 18)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 6, 7))
})

local profileStroke = Instance.new("UIStroke", UserProfileFrame)
profileStroke.Color = Color3.fromRGB(65, 24, 28)
profileStroke.Thickness = 1
profileStroke.Transparency = 0.2

local AvatarImage = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Size = UDim2.new(0, 32, 0, 32)
AvatarImage.Position = UDim2.new(0, 8, 0.5, -16)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex = 11
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)
local avatarRing = Instance.new("UIStroke", AvatarImage)
avatarRing.Color = Color3.fromRGB(139, 0, 0)
avatarRing.Thickness = 1.2
avatarRing.Transparency = 0.3

local DisplayNameLabel = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Size = UDim2.new(1, -70, 0, 14)
DisplayNameLabel.Position = UDim2.new(0, 46, 0.5, -14)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
DisplayNameLabel.Font = Enum.Font.GothamBold
DisplayNameLabel.TextSize = 10.5
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLabel.ZIndex = 11

local UsernameLabel = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Size = UDim2.new(1, -70, 0, 12)
UsernameLabel.Position = UDim2.new(0, 46, 0.5, 1)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text = "@" .. player.Name
UsernameLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
UsernameLabel.Font = Enum.Font.Gotham
UsernameLabel.TextSize = 9
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UsernameLabel.ZIndex = 11

-- Botão de censura: dark, porém mais claro que a badge para contraste do ícone
local PrivacyBtn = Instance.new("ImageButton", UserProfileFrame)
PrivacyBtn.Size = UDim2.new(0, 24, 0, 24)
PrivacyBtn.Position = UDim2.new(1, -30, 0.5, -12)
PrivacyBtn.BackgroundColor3 = Color3.fromRGB(48, 30, 34)
PrivacyBtn.BackgroundTransparency = 0
PrivacyBtn.Image = ""
PrivacyBtn.ZIndex = 12
Instance.new("UICorner", PrivacyBtn).CornerRadius = UDim.new(0, 7)

local privacyBtnGrad = Instance.new("UIGradient", PrivacyBtn)
privacyBtnGrad.Rotation = 90
privacyBtnGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(58, 36, 40)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 20, 23))
})

local PrivacyIcon = Instance.new("ImageLabel", PrivacyBtn)
PrivacyIcon.Size = UDim2.new(1, -8, 1, -8)
PrivacyIcon.Position = UDim2.new(0, 4, 0, 4)
PrivacyIcon.BackgroundTransparency = 1
PrivacyIcon.Image = ASSETS.EyeOpen
PrivacyIcon.ImageColor3 = Color3.fromRGB(235, 235, 235)
PrivacyIcon.ScaleType = Enum.ScaleType.Fit
PrivacyIcon.ZIndex = 13

local privacyStroke = Instance.new("UIStroke", PrivacyBtn)
privacyStroke.Color = Color3.fromRGB(110, 35, 38)
privacyStroke.Thickness = 1
privacyStroke.Transparency = 0.15

local isPrivate = false
PrivacyBtn.MouseButton1Click:Connect(function()
    isPrivate = not isPrivate
    if isPrivate then
        PrivacyIcon.Image = ASSETS.EyeClosed
        DisplayNameLabel.Text = string.rep("*", math.clamp(#player.DisplayName, 3, 8))
        UsernameLabel.Text = "@" .. string.rep("*", math.clamp(#player.Name, 3, 8))
    else
        PrivacyIcon.Image = ASSETS.EyeOpen
        DisplayNameLabel.Text = player.DisplayName
        UsernameLabel.Text = "@" .. player.Name
    end
end)

-- ==================== BADGE "UI v3.6" — TOPO ESQUERDO DA JANELA, ISOLADA ====================
local VersionBadge = Instance.new("Frame", mainWrapper)
VersionBadge.Name = "VersionBadge"
VersionBadge.AnchorPoint = Vector2.new(0, 0)
VersionBadge.Position = UDim2.new(0, 10, 0, -22)
VersionBadge.Size = UDim2.new(0, 62, 0, 18)
VersionBadge.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
VersionBadge.BackgroundTransparency = 0
VersionBadge.ZIndex = 20
Instance.new("UICorner", VersionBadge).CornerRadius = UDim.new(0, 6)

local versionBadgeGrad = Instance.new("UIGradient", VersionBadge)
versionBadgeGrad.Rotation = 90
versionBadgeGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 38, 38)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 3, 3))
})
-- Sem contorno/borda, conforme solicitado (nenhum UIStroke aqui)

local VersionBadgeText = Instance.new("TextLabel", VersionBadge)
VersionBadgeText.Size = UDim2.new(1, 0, 1, 0)
VersionBadgeText.BackgroundTransparency = 1
VersionBadgeText.Text = "UI v3.6"
VersionBadgeText.TextColor3 = Color3.fromRGB(200, 200, 200)
VersionBadgeText.Font = Enum.Font.GothamMedium
VersionBadgeText.TextSize = 9
VersionBadgeText.ZIndex = 21

-- ==================== RIGHT PANEL HEADER ====================
local topButtons = Instance.new("Frame", RightPanel)
topButtons.Size = UDim2.new(1, -12, 0, 36)
topButtons.Position = UDim2.new(0, 6, 0, 6)
topButtons.BackgroundTransparency = 1
topButtons.ZIndex = 10

local UIListTop = Instance.new("UIListLayout", topButtons)
UIListTop.FillDirection = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding = UDim.new(0, 6)
UIListTop.SortOrder = Enum.SortOrder.LayoutOrder

local SearchBtn = Instance.new("TextButton", topButtons)
SearchBtn.Name = "SearchBtn"
SearchBtn.LayoutOrder = 1
SearchBtn.Size = UDim2.new(0, 24, 0, 24)
SearchBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
SearchBtn.BackgroundTransparency = 0.3
SearchBtn.Text = ""
SearchBtn.ClipsDescendants = true
SearchBtn.ZIndex = 11
Instance.new("UICorner", SearchBtn).CornerRadius = UDim.new(0, 5)

local SearchIcon = Instance.new("Frame", SearchBtn)
SearchIcon.Name = "Icon"
SearchIcon.Size = UDim2.new(0, 12, 0, 12)
SearchIcon.AnchorPoint = Vector2.new(0, 0.5)
SearchIcon.Position = UDim2.new(0, 6, 0.5, 0)
SearchIcon.BackgroundTransparency = 1
SearchIcon.ZIndex = 12

local SearchCircle = Instance.new("Frame", SearchIcon)
SearchCircle.Size = UDim2.new(0, 7, 0, 7)
SearchCircle.Position = UDim2.new(0, 1, 0, 1)
SearchCircle.BackgroundTransparency = 1
SearchCircle.ZIndex = 12
Instance.new("UICorner", SearchCircle).CornerRadius = UDim.new(1, 0)
local circleStroke = Instance.new("UIStroke", SearchCircle)
circleStroke.Color = Color3.fromHex("#A0A0A0")
circleStroke.Thickness = 1

local SearchHandle = Instance.new("Frame", SearchIcon)
SearchHandle.Size = UDim2.new(0, 1, 0, 4)
SearchHandle.Position = UDim2.new(0, 8, 0, 7)
SearchHandle.Rotation = -45
SearchHandle.BackgroundColor3 = Color3.fromHex("#A0A0A0")
SearchHandle.BorderSizePixel = 0
SearchHandle.ZIndex = 12

local searchTextBox = Instance.new("TextBox", SearchBtn)
searchTextBox.Size = UDim2.new(1, -26, 1, 0)
searchTextBox.Position = UDim2.new(0, 24, 0, 0)
searchTextBox.BackgroundTransparency = 1
searchTextBox.PlaceholderText = UI_TEXT.SearchPlaceholder
searchTextBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
searchTextBox.Text = ""
searchTextBox.TextColor3 = Color3.fromRGB(230, 230, 230)
searchTextBox.Font = Enum.Font.Gotham
searchTextBox.TextSize = 10
searchTextBox.TextXAlignment = Enum.TextXAlignment.Left
searchTextBox.Visible = false
searchTextBox.ZIndex = 12

local ExpandBtn = Instance.new("TextButton", topButtons)
ExpandBtn.Name = "ExpandBtn"
ExpandBtn.LayoutOrder = 2
ExpandBtn.Size = UDim2.new(0, 24, 0, 24)
ExpandBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
ExpandBtn.BackgroundTransparency = 0.3
ExpandBtn.Text = ""
ExpandBtn.ZIndex = 11
Instance.new("UICorner", ExpandBtn).CornerRadius = UDim.new(0, 5)

local ExpandSquare = Instance.new("Frame", ExpandBtn)
ExpandSquare.Size = UDim2.new(0, 7, 0, 7)
ExpandSquare.AnchorPoint = Vector2.new(0.5, 0.5)
ExpandSquare.Position = UDim2.new(0.5, 0, 0.5, 0)
ExpandSquare.BackgroundTransparency = 1
ExpandSquare.ZIndex = 12
local ExpandStroke = Instance.new("UIStroke", ExpandSquare)
ExpandStroke.Color = Color3.fromHex("#A0A0A0")
ExpandStroke.Thickness = 1 

local MinimizeBtn = Instance.new("TextButton", topButtons)
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.LayoutOrder = 3
MinimizeBtn.Size = UDim2.new(0, 24, 0, 24)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MinimizeBtn.BackgroundTransparency = 0.3
MinimizeBtn.Text = ""
MinimizeBtn.ZIndex = 11
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 5)
local MinimizeLine = Instance.new("Frame", MinimizeBtn)
MinimizeLine.Name = "Line"
MinimizeLine.AnchorPoint = Vector2.new(0.5, 0.5)
MinimizeLine.Position = UDim2.new(0.5, 0, 0.5, 0)
MinimizeLine.Size = UDim2.new(0, 9, 0, 1.2)
MinimizeLine.BackgroundColor3 = Color3.fromHex("#A0A0A0")
MinimizeLine.BorderSizePixel = 0
MinimizeLine.ZIndex = 12

local CloseBtn = Instance.new("TextButton", topButtons)
CloseBtn.Name = "CloseBtn"
CloseBtn.LayoutOrder = 4
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
CloseBtn.BackgroundTransparency = 0.3
CloseBtn.Text = ""
CloseBtn.ZIndex = 11
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)
local CloseLine1 = Instance.new("Frame", CloseBtn)
CloseLine1.Name = "Line1"
CloseLine1.AnchorPoint = Vector2.new(0.5, 0.5)
CloseLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine1.Size = UDim2.new(0, 10, 0, 1.2)
CloseLine1.Rotation = 45
CloseLine1.BackgroundColor3 = Color3.fromHex("#A0A0A0")
CloseLine1.BorderSizePixel = 0
CloseLine1.ZIndex = 12
local CloseLine2 = Instance.new("Frame", CloseBtn)
CloseLine2.Name = "Line2"
CloseLine2.AnchorPoint = Vector2.new(0.5, 0.5)
CloseLine2.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine2.Size = UDim2.new(0, 10, 0, 1.2)
CloseLine2.Rotation = -45
CloseLine2.BackgroundColor3 = Color3.fromHex("#A0A0A0")
CloseLine2.BorderSizePixel = 0
CloseLine2.ZIndex = 12

local RightSeparatorLine = Instance.new("Frame", RightPanel)
RightSeparatorLine.Size = UDim2.new(1, 0, 0, 1)
RightSeparatorLine.Position = UDim2.new(0, 0, 0, 44)
RightSeparatorLine.BackgroundColor3 = Color3.fromRGB(80, 20, 25)
RightSeparatorLine.BorderSizePixel = 0
RightSeparatorLine.ZIndex = 10

local togglesContainer = Instance.new("ScrollingFrame", RightPanel)
togglesContainer.Name = "TogglesContainer"
togglesContainer.Size = UDim2.new(1, 0, 1, -52)
togglesContainer.Position = UDim2.new(0, 0, 0, 52)
togglesContainer.BackgroundTransparency = 1
togglesContainer.BorderSizePixel = 0
togglesContainer.ScrollBarThickness = 2
togglesContainer.ScrollBarImageColor3 = Color3.fromRGB(139, 0, 0)
togglesContainer.ScrollBarImageTransparency = 0.3
togglesContainer.ZIndex = 10
togglesContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

local containerLayout = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
containerLayout.Padding = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local uiPadding = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingBottom = UDim.new(0, 8)

containerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    togglesContainer.CanvasSize = UDim2.new(0, 0, 0, containerLayout.AbsoluteContentSize.Y + 16)
end)

-- Confirm Frame
local confirmFrame = Instance.new("Frame", mainFrame)
confirmFrame.Name = "ConfirmFrame"
confirmFrame.Size = UDim2.new(1, 0, 1, 0)
confirmFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
confirmFrame.BackgroundTransparency = 0.4
confirmFrame.Visible = false
confirmFrame.ZIndex = 50
Instance.new("UICorner", confirmFrame).CornerRadius = UDim.new(0, 14)

local confirmLabel = Instance.new("TextLabel", confirmFrame)
confirmLabel.Size = UDim2.new(1, 0, 0, 30)
confirmLabel.Position = UDim2.new(0, 0, 0.35, -10)
confirmLabel.BackgroundTransparency = 1
confirmLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
confirmLabel.Font = Enum.Font.GothamBold
confirmLabel.TextSize = 14
confirmLabel.Text = UI_TEXT.ConfirmCloseTitle
confirmLabel.ZIndex = 51

local btnYes = Instance.new("TextButton", confirmFrame)
btnYes.Size = UDim2.new(0, 110, 0, 34)
btnYes.Position = UDim2.new(0.5, -115, 0.55, 0)
btnYes.BackgroundColor3 = Color3.fromHex("#8B0000")
btnYes.TextColor3 = Color3.fromRGB(255, 255, 255)
btnYes.Font = Enum.Font.GothamMedium
btnYes.TextSize = 12
btnYes.Text = UI_TEXT.ConfirmBtn
btnYes.ZIndex = 51
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 8)

local btnNo = Instance.new("TextButton", confirmFrame)
btnNo.Size = UDim2.new(0, 110, 0, 34)
btnNo.Position = UDim2.new(0.5, 5, 0.55, 0)
btnNo.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
btnNo.TextColor3 = Color3.fromRGB(180, 180, 180)
btnNo.Font = Enum.Font.GothamMedium
btnNo.TextSize = 12
btnNo.Text = UI_TEXT.CancelBtn
btnNo.ZIndex = 51
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 8)

-- ==================== FUNÇÕES DA INTERFACE ====================
local function filterToggles(currentActiveTab, query)
    local searchQuery = (query or ""):lower()
    local itemIndex = 0
    for _, child in ipairs(togglesContainer:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
            local itemTab = child:GetAttribute("Tab") or "Combat"
            local shouldBeVisible = false
            if searchQuery ~= "" then
                local titleLabel = child:FindFirstChild("Title")
                shouldBeVisible = titleLabel and titleLabel.Text:lower():find(searchQuery) ~= nil
            else
                shouldBeVisible = (itemTab == currentActiveTab)
            end
            
            if child.Visible ~= shouldBeVisible or shouldBeVisible then
                child.Visible = shouldBeVisible
                if shouldBeVisible then
                    itemIndex = itemIndex + 1
                    child.Size = UDim2.new(1, -16, 0, 0)
                    child.BackgroundTransparency = 1
                    local t = child:FindFirstChild("Title")
                    local d = child:FindFirstChild("Description")
                    if t then t.TextTransparency = 1 end
                    if d then d.TextTransparency = 1 end
                    task.delay((itemIndex - 1) * 0.02, function()
                        if not child or not child.Parent then return end
                        TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                            Size = UDim2.new(1, -16, 0, 52), BackgroundTransparency = 0.35
                        }):Play()
                        if t then TweenService:Create(t, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
                        if d then TweenService:Create(d, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
                    end)
                end
            end
        end
    end
end

local function selectTab(tabName)
    activeTab = tabName
    local animSpeed = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for name, btn in pairs(tabButtons) do
        local label = btn:FindFirstChild("Label")
        local iconContainer = btn:FindFirstChild("Icon")
        local activeBar = btn:FindFirstChild("ActiveBar")
        if name == tabName then
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(25, 5, 5), BackgroundTransparency = 0.4}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end
            if activeBar then activeBar.Visible = true end
            if iconContainer and iconContainer:FindFirstChild("AccentImage") then
                TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            end
        else
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 1}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(150, 150, 150)}):Play() end
            if activeBar then activeBar.Visible = false end
            if iconContainer and iconContainer:FindFirstChild("AccentImage") then
                TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Color3.fromRGB(150, 150, 150)}):Play()
            end
        end
    end
    togglesContainer.CanvasPosition = Vector2.new(0, 0)
    searchTextBox.Text = ""
    filterToggles(tabName, "")
end

-- Tabs maiores: botões proporcionalmente ampliados, com espaçamento confortável (item 1)
local function createTabBtn(tabName)
    local tabBtn = Instance.new("TextButton", TabsContainer)
    tabBtn.Name = tabName .. "TabBtn"
    tabBtn.Size = UDim2.new(1, -14, 0, 40)
    tabBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text = ""
    tabBtn.ZIndex = 11
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 9)

    local activeBar = Instance.new("Frame", tabBtn)
    activeBar.Name = "ActiveBar"
    activeBar.Size = UDim2.new(0, 3, 0, 20)
    activeBar.Position = UDim2.new(0, 3, 0.5, -10)
    activeBar.BackgroundColor3 = Color3.fromHex("#8B0000")
    activeBar.BorderSizePixel = 0
    activeBar.Visible = false
    activeBar.ZIndex = 13 
    Instance.new("UICorner", activeBar).CornerRadius = UDim.new(1, 0)

    local iconContainer = Instance.new("Frame", tabBtn)
    iconContainer.Name = "Icon"
    iconContainer.Size = UDim2.new(0, 19, 0, 19) 
    iconContainer.Position = UDim2.new(0, 12, 0.5, -9.5)
    iconContainer.BackgroundTransparency = 1
    iconContainer.ZIndex = 12
    local imageLabel = Instance.new("ImageLabel", iconContainer)
    imageLabel.Name = "AccentImage"
    imageLabel.Size = UDim2.new(1, 0, 1, 0)
    imageLabel.BackgroundTransparency = 1
    imageLabel.ZIndex = 13
    imageLabel.ImageColor3 = Color3.fromRGB(150, 150, 150)
    
    if tabName == "Player" then imageLabel.Image = "rbxthumb://type=Asset&id=78324938264014&w=150&h=150"
    elseif tabName == "Teleports" then imageLabel.Image = "rbxthumb://type=Asset&id=122367250674432&w=150&h=150"
    elseif tabName == "Misc" then imageLabel.Image = "rbxthumb://type=Asset&id=79429182159899&w=150&h=150"
    elseif tabName == "Visuals" then imageLabel.Image = "rbxthumb://type=Asset&id=135604583195835&w=150&h=150"
    elseif tabName == "Combat" then imageLabel.Image = "rbxthumb://type=Asset&id=139442231247295&w=150&h=150" end

    local tabLabel = Instance.new("TextLabel", tabBtn)
    tabLabel.Name = "Label"
    tabLabel.Size = UDim2.new(1, -42, 1, 0) 
    tabLabel.Position = UDim2.new(0, 38, 0, 0) 
    tabLabel.BackgroundTransparency = 1
    tabLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    tabLabel.Font = Enum.Font.GothamMedium
    tabLabel.TextSize = 13
    tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.Text = UI_TEXT.Tabs[tabName] or tabName
    tabLabel.ZIndex = 12

    tabBtn.MouseButton1Click:Connect(function() selectTab(tabName) end)
    tabButtons[tabName] = tabBtn
end

local function createToggle(parent, configKey, tabCategory)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = configKey
    toggleFrame.Size = UDim2.new(1, -16, 0, 52)
    toggleFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    toggleFrame.BackgroundTransparency = 0.35
    toggleFrame.ZIndex = 11
    toggleFrame.ClipsDescendants = true 
    toggleFrame:SetAttribute("Tab", tabCategory)
    toggleFrame:SetAttribute("ConfigKey", configKey)
    toggleFrame.Parent = parent
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", toggleFrame)
    stroke.Color = Color3.fromHex("#141414")
    stroke.Thickness = 1
    
    local optData = UI_TEXT.Options[configKey]
    local titleLabel = Instance.new("TextLabel", toggleFrame)
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(0.7, 0, 0, 16)
    titleLabel.Position = UDim2.new(0, 10, 0, 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromHex("#CCCCCC")
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = optData and optData.Title or configKey
    titleLabel.ZIndex = 11
    
    local descLabel = Instance.new("TextLabel", toggleFrame)
    descLabel.Name = "Description"
    descLabel.Size = UDim2.new(0.7, 0, 0, 26)
    descLabel.Position = UDim2.new(0, 10, 0, 22)
    descLabel.BackgroundTransparency = 1
    descLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 9
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.TextWrapped = true
    descLabel.Text = optData and optData.Desc or ""
    descLabel.ZIndex = 11
    
    local switchTrack = Instance.new("Frame", toggleFrame)
    switchTrack.Size = UDim2.new(0, 38, 0, 18)
    switchTrack.Position = UDim2.new(1, -48, 0.5, -9)
    switchTrack.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
    switchTrack.ZIndex = 11
    Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)
    local switchCircle = Instance.new("Frame", switchTrack)
    switchCircle.Size = UDim2.new(0, 12, 0, 12)
    switchCircle.Position = Configs[configKey] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
    switchCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    switchCircle.ZIndex = 12
    Instance.new("UICorner", switchCircle).CornerRadius = UDim.new(1, 0)
    
    local triggerBtn = Instance.new("TextButton", toggleFrame)
    triggerBtn.Size = UDim2.new(1, 0, 1, 0)
    triggerBtn.BackgroundTransparency = 1
    triggerBtn.Text = ""
    triggerBtn.ZIndex = 13
    
    triggerBtn.MouseButton1Click:Connect(function()
        Configs[configKey] = not Configs[configKey]
        local targetPos   = Configs[configKey] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        local targetColor = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
        local anim = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(switchCircle, anim, {Position = targetPos}):Play()
        TweenService:Create(switchTrack, anim, {BackgroundColor3 = targetColor}):Play()
    end)
end

local searchExpanded = false
local searchInactivityTimer = nil

local function resetSearchInactivityTimer()
    if searchInactivityTimer then task.cancel(searchInactivityTimer) end
    searchInactivityTimer = task.delay(4, function()
        if searchExpanded and searchTextBox.Text == "" then
            searchExpanded = false
            local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            TweenService:Create(SearchBtn, info, {Size = UDim2.new(0, 24, 0, 24)}):Play()
            searchTextBox:ReleaseFocus()
            task.delay(0.2, function() searchTextBox.Visible = false end)
            filterToggles(activeTab, "")
        end
    end)
end

SearchBtn.MouseButton1Click:Connect(function()
    searchExpanded = not searchExpanded
    local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if searchExpanded then
        TweenService:Create(SearchBtn, info, {Size = UDim2.new(0, 120, 0, 24)}):Play()
        searchTextBox.Visible = true
        searchTextBox:CaptureFocus()
        resetSearchInactivityTimer()
    else
        TweenService:Create(SearchBtn, info, {Size = UDim2.new(0, 24, 0, 24)}):Play()
        searchTextBox:ReleaseFocus()
        searchTextBox.Text = ""
        task.delay(0.2, function() if not searchExpanded then searchTextBox.Visible = false end end)
        filterToggles(activeTab, "")
    end
end)

searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
    resetSearchInactivityTimer()
    filterToggles(activeTab, searchTextBox.Text)
end)

searchTextBox.Focused:Connect(function() resetSearchInactivityTimer() end)

UserInputService.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and searchExpanded then
        local pos = input.Position
        local btnPos = SearchBtn.AbsolutePosition
        local btnSize = SearchBtn.AbsoluteSize
        if pos.X < btnPos.X or pos.X > btnPos.X + btnSize.X or pos.Y < btnPos.Y or pos.Y > btnPos.Y + btnSize.Y then
            if searchTextBox.Text == "" then
                searchExpanded = false
                local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                TweenService:Create(SearchBtn, info, {Size = UDim2.new(0, 24, 0, 24)}):Play()
                searchTextBox:ReleaseFocus()
                task.delay(0.2, function() searchTextBox.Visible = false end)
                filterToggles(activeTab, "")
            end
        end
    end
end)

ExpandBtn.MouseButton1Click:Connect(function()
    isExpanded = not isExpanded
    local newSize = isExpanded and UDim2.new(0, 640, 0, 400) or UDim2.new(0, 560, 0, 330)
    TweenService:Create(mainWrapper, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = newSize}):Play()
end)

-- ==================== SISTEMA DE ESTADO CENTRALIZADO ====================
-- Único ponto de transição de estado, evita duplicação de UI, botão flutuante,
-- animações conflitantes e o botão flutuante nunca é destruído/recriado.
local function SetUIState(newState)
    if isBusy then return end -- protege contra cliques rápidos repetidos
    if UIState == newState then return end
    if UIState == "OPENING" or UIState == "CLOSING" then return end

    isBusy = true
    local tempoAnim = 0.25
    local windowAnim = TweenInfo.new(tempoAnim, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    if newState == "OPEN" then
        UIState = "OPENING"
        mainWrapper.Visible = true
        ShadowLeft.Visible = true
        ShadowRight.Visible = true
        mainWrapper.Size = UDim2.new(0, 500, 0, 280)
        AplicarFadeSincronizado(mainWrapper, true, 0)
        AplicarFadeSincronizado(mainWrapper, false, tempoAnim)

        local openTween = TweenService:Create(mainWrapper, windowAnim, {Size = isExpanded and UDim2.new(0, 640, 0, 400) or UDim2.new(0, 560, 0, 330)})
        openTween:Play()
        openTween.Completed:Connect(function()
            UIState = "OPEN"
            isBusy = false
            filterToggles(activeTab, searchTextBox.Text)
        end)
        -- Botão flutuante permanece visível e funcional sempre; apenas a UI abre por cima

    elseif newState == "MINIMIZED" or newState == "CLOSED" then
        UIState = "CLOSING"
        AplicarFadeSincronizado(mainWrapper, true, tempoAnim)
        local closeTween = TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 500, 0, 280)})
        closeTween:Play()

        closeTween.Completed:Connect(function()
            mainWrapper.Visible = false
            ShadowLeft.Visible = false
            ShadowRight.Visible = false
            UIState = newState
            isBusy = false
        end)
        -- Botão flutuante NUNCA é ocultado aqui: continua visível e funcionando
    else
        isBusy = false
    end
end

-- Minimizar: some a UI, botão flutuante continua visível e funcionando
MinimizeBtn.MouseButton1Click:Connect(function()
    if UIState == "OPEN" then
        SetUIState("MINIMIZED")
    end
end)

-- Clique no botão flutuante: reabre a UI. O som toca só nesse clique de abertura.
FloatBtn.MouseButton1Click:Connect(function()
    if floatMoved then return end -- evita abrir a UI acidentalmente após arrastar
    if UIState == "MINIMIZED" or UIState == "CLOSED" then
        SharinganSound:Stop()
        SharinganSound:Play()
        SetUIState("OPEN")
    end
end)

local function AlternarConfirmacao(exibir)
    isConfirmOpen = exibir
    local tempoAnim = 0.15
    if exibir then
        if not confirmBlur then confirmBlur = Instance.new("BlurEffect"); confirmBlur.Size = 0; confirmBlur.Parent = Lighting end
        confirmFrame.Visible = true
        AplicarFadeSincronizado(confirmFrame, true, 0)
        AplicarFadeSincronizado(confirmFrame, false, tempoAnim)
        TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 14}):Play()
    else
        AplicarFadeSincronizado(confirmFrame, true, tempoAnim)
        if confirmBlur then 
            local blurTween = TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 0})
            blurTween:Play()
            blurTween.Completed:Connect(function() if confirmBlur and confirmBlur.Size == 0 then confirmBlur:Destroy(); confirmBlur = nil end end)
        end
        task.delay(tempoAnim, function() if not isConfirmOpen then confirmFrame.Visible = false end end)
    end
end

CloseBtn.MouseButton1Click:Connect(function() AlternarConfirmacao(true) end)
btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)
btnYes.MouseButton1Click:Connect(function()
    local syncTime = 0.2
    if confirmBlur then TweenService:Create(confirmBlur, TweenInfo.new(syncTime, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 0}):Play() end
    AplicarFadeSincronizado(mainWrapper, true, syncTime)
    if orbitConnection then orbitConnection:Disconnect() end
    TweenService:Create(FloatBtn, TweenInfo.new(syncTime, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)}):Play()
    task.wait(syncTime)
    screenGui:Destroy()
end)

local function AplicarEfeitoFisicoBotao(btn, hoverColor)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = Color3.fromRGB(30, 30, 30), BackgroundTransparency = 0.1}):Play()
        if btn.Name == "ExpandBtn" then TweenService:Create(ExpandStroke, TweenInfo.new(0.15), {Color = hoverColor}):Play()
        elseif btn.Name == "MinimizeBtn" then TweenService:Create(btn.Line, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
        elseif btn.Name == "SearchBtn" and not searchExpanded then TweenService:Create(circleStroke, TweenInfo.new(0.15), {Color = hoverColor}):Play(); TweenService:Create(SearchHandle, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
        elseif btn.Name == "CloseBtn" then TweenService:Create(btn.Line1, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play(); TweenService:Create(btn.Line2, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play() end
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 0.3}):Play()
        if btn.Name == "ExpandBtn" then TweenService:Create(ExpandStroke, TweenInfo.new(0.15), {Color = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "MinimizeBtn" then TweenService:Create(btn.Line, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "SearchBtn" then TweenService:Create(circleStroke, TweenInfo.new(0.15), {Color = Color3.fromHex("#A0A0A0")}):Play(); TweenService:Create(SearchHandle, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "CloseBtn" then TweenService:Create(btn.Line1, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play(); TweenService:Create(btn.Line2, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play() end
    end)
end

AplicarEfeitoFisicoBotao(SearchBtn, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(ExpandBtn, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(MinimizeBtn, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(CloseBtn, Color3.fromRGB(255, 60, 60))

createTabBtn("Player")
createTabBtn("Combat")
createTabBtn("Visuals")
createTabBtn("Teleports")
createTabBtn("Misc")

createToggle(togglesContainer, "Speed",       "Player")
createToggle(togglesContainer, "AntiFling",   "Player")
createToggle(togglesContainer, "AutoShoot",   "Combat")
createToggle(togglesContainer, "Reach",       "Combat")
createToggle(togglesContainer, "ESP",         "Visuals")
createToggle(togglesContainer, "TpToGun",     "Teleports")
createToggle(togglesContainer, "SafeSpot",    "Teleports")
createToggle(togglesContainer, "AutoCollect", "Misc")
createToggle(togglesContainer, "ChatRoles",   "Misc")

-- ==================== ANIMAÇÃO DE INTRODUÇÃO ====================
local function ExecutarIntroAkat()
    local Blur = Instance.new("BlurEffect"); Blur.Size = 0; Blur.Parent = Lighting
    local IntroFrame = Instance.new("Frame", screenGui); IntroFrame.Size = UDim2.new(1, 0, 1, 0); IntroFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0); IntroFrame.BackgroundTransparency = 1; IntroFrame.ZIndex = 500
    local MaskContainer = Instance.new("Frame", IntroFrame); MaskContainer.AnchorPoint = Vector2.new(0.5, 0.5); MaskContainer.Position = UDim2.new(0.5, 0, 0.5, -10); MaskContainer.Size = UDim2.new(0, 420, 0, 40); MaskContainer.BackgroundTransparency = 1; MaskContainer.ClipsDescendants = true; MaskContainer.ZIndex = 501
    local IntroText = Instance.new("TextLabel", MaskContainer); IntroText.Size = UDim2.new(1, 0, 1, 0); IntroText.Position = UDim2.new(0, 0, 1, 0); IntroText.BackgroundTransparency = 1; IntroText.Font = Enum.Font.GothamBold; IntroText.TextSize = 26; IntroText.RichText = true; IntroText.Text = UI_TEXT.Intro; IntroText.ZIndex = 502
    local IntroLine = Instance.new("Frame", IntroFrame); IntroLine.AnchorPoint = Vector2.new(0.5, 0.5); IntroLine.Position = UDim2.new(0.5, 0, 0.5, 22); IntroLine.Size = UDim2.new(0, 0, 0, 2); IntroLine.BackgroundColor3 = Color3.fromHex("#8B0000"); IntroLine.BorderSizePixel = 0; IntroLine.BackgroundTransparency = 1; IntroLine.ZIndex = 503; Instance.new("UICorner", IntroLine).CornerRadius = UDim.new(1, 0)

    TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.05}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 24}):Play(); task.wait(0.1)
    TweenService:Create(IntroText, TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play(); task.wait(0.2)
    TweenService:Create(IntroLine, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(0, 260, 0, 2)}):Play(); task.wait(1.6) 
    TweenService:Create(IntroText, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
    TweenService:Create(IntroLine, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play(); task.wait(0.3)
    TweenService:Create(IntroFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play(); task.wait(0.3)

    RegistrarTransparencias(mainFrame)
    for _, item in ipairs(mainFrame:GetDescendants()) do RegistrarTransparencias(item) end

    -- UI e botão flutuante aparecem juntos, sem precisar de clique (Bug 2 corrigido)
    mainWrapper.Visible = true
    ShadowLeft.Visible = true
    ShadowRight.Visible = true
    UIState = "OPEN"
    local MainScale = Instance.new("UIScale", mainWrapper); MainScale.Scale = 0.85
    AplicarFadeSincronizado(mainWrapper, true, 0)
    AplicarFadeSincronizado(mainWrapper, false, 0.35)
    
    local openScale = TweenService:Create(MainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
    openScale:Play()
    
    openScale.Completed:Connect(function() 
        selectTab("Player") 
        MainScale:Destroy(); IntroFrame:Destroy(); Blur:Destroy()
    end)
end

ExecutarIntroAkat()
