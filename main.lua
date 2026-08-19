-- [[ AKATSUKI UI ONLY [v3.8] - FIXED & IMPROVED ]]

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

-- ==================== DYNAMIC UI COMPONENT & STATE MACHINE ====================
local UIState = "CLOSED" -- Estados: OPEN, CLOSED, MINIMIZED, OPENING, CLOSING

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
            local baseTransparency = orig.ImageTransparency
            if obj.Name == "Shadow3D" then baseTransparency = 0.5 end
            local t = fadeOut and 1 or baseTransparency
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
local FloatBtn = screenGui:FindFirstChild("FloatBtn") or Instance.new("ImageButton", screenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0.12, 0, 0.4, 0)
FloatBtn.Image = "rbxthumb://type=Asset&id=139044062702391&w=150&h=150"
FloatBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
FloatBtn.Visible = true
FloatBtn.ZIndex = 100
FloatBtn.ClipsDescendants = false
if not FloatBtn:FindFirstChildOfClass("UICorner") then Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8) end

-- Contorno Gradiente Estático (Mesmas cores do gradiente principal)
local FloatStroke = FloatBtn:FindFirstChild("FloatStroke") or Instance.new("UIStroke", FloatBtn)
FloatStroke.Name = "FloatStroke"
FloatStroke.Thickness = 2.5
FloatStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local floatStrokeGradient = FloatStroke:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", FloatStroke)
floatStrokeGradient.Rotation = 45
floatStrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 25, 30)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 10, 15)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 25, 30))
})

local Sharingan = FloatBtn:FindFirstChild("SharinganEffect") or Instance.new("ImageLabel", FloatBtn)
Sharingan.Name = "SharinganEffect"
Sharingan.Size = UDim2.new(0, 16, 0, 16)
Sharingan.AnchorPoint = Vector2.new(0.5, 0.5)
Sharingan.Position = UDim2.new(0.5, 0, 0.5, 0)
Sharingan.BackgroundTransparency = 1
Sharingan.Image = "rbxthumb://type=Asset&id=100882509796042&w=150&h=150"
Sharingan.ImageTransparency = 0 
Sharingan.ZIndex = 105
Sharingan.Visible = true

local orbitAngle = 0
RunService.RenderStepped:Connect(function(dt)
    if FloatBtn and FloatBtn.Parent and FloatBtn.Visible then
        Sharingan.Rotation = (Sharingan.Rotation + (dt * 180)) % 360
        orbitAngle = (orbitAngle + (dt * 2.2)) % (math.pi * 2)
        local radius = 38
        Sharingan.Position = UDim2.new(0.5, math.cos(orbitAngle) * radius, 0.5, math.sin(orbitAngle) * radius)
    end
end)

local SharinganSound = FloatBtn:FindFirstChild("SharinganSound") or Instance.new("Sound", FloatBtn)
SharinganSound.Name = "SharinganSound"
SharinganSound.SoundId = "rbxassetid://9114223178"
SharinganSound.Volume = 1
SharinganSound.RollOffMaxDistance = 10000

local dragToggle = false
local dragStart, startPos
local isDragging = false

FloatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragToggle = true
        isDragging = false
        dragStart = input.Position
        startPos = FloatBtn.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        if delta.Magnitude > 5 then
            isDragging = true
        end
        FloatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local SetUIState

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
        if dragToggle and not isDragging then
            pcall(function()
                SharinganSound.TimePosition = 0
                SharinganSound:Play()
            end)
            if UIState == "MINIMIZED" or UIState == "CLOSED" then
                SetUIState("OPEN")
            elseif UIState == "OPEN" then
                SetUIState("MINIMIZED")
            end
        end
        dragToggle = false 
    end
end)

-- ==================== INTERFACE PRINCIPAL ====================
local mainWrapper = Instance.new("Frame", screenGui)
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0.5)
mainWrapper.Size = UDim2.new(0, 535, 0, 300)
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible = false
mainWrapper.ClipsDescendants = false

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

local function CreateGradientPanel(parent, size, pos, name)
    local panel = Instance.new("Frame", parent)
    panel.Name = name
    panel.Size = size
    panel.Position = pos
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ZIndex = 5
    panel.ClipsDescendants = false

    -- CORREÇÃO DA SOMBRA 3D: Sombra moderna sem pontas vazando
    local shadow = Instance.new("ImageLabel", panel)
    shadow.Name = "Shadow3D"
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0.5, 0, 0.5, 2)
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://6015897843"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.5
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(25, 25, 225, 225)
    shadow.ZIndex = 4

    local InnerBg = Instance.new("Frame", panel)
    InnerBg.Name = "InnerBg"
    InnerBg.Size = UDim2.new(1, 0, 1, 0)
    InnerBg.BackgroundColor3 = Color3.fromRGB(20, 8, 12)
    InnerBg.BorderSizePixel = 0
    InnerBg.ClipsDescendants = true
    InnerBg.ZIndex = 5
    Instance.new("UICorner", InnerBg).CornerRadius = UDim.new(0, 10)
    
    local overlay = Instance.new("Frame", InnerBg)
    overlay.Name = "RedGradientOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 5

    -- GRADIENTE DA UI: Vermelho sutil no lugar do preto puro
    local redGrad = Instance.new("UIGradient", overlay)
    redGrad.Rotation = 90
    redGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 25, 30)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 10, 15)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 25, 30))
    })
    
    redGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.65),
        NumberSequenceKeypoint.new(0.5, 0.40),
        NumberSequenceKeypoint.new(1, 0.65)
    })

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
        NumberSequenceKeypoint.new(0.5, 0.96),
        NumberSequenceKeypoint.new(1, 1)
    })

    RunService.RenderStepped:Connect(function(dt)
        redGrad.Rotation = (redGrad.Rotation + (dt * 10)) % 360
        beamGrad.Rotation = (beamGrad.Rotation + (dt * 12)) % 360
    end)
    
    local stroke = Instance.new("UIStroke", InnerBg)
    stroke.Color = Color3.fromRGB(80, 20, 25)
    stroke.Thickness = 1.2
    
    return panel
end

local LeftPanel = CreateGradientPanel(mainFrame, UDim2.new(0, 165, 1, 0), UDim2.new(0, 0, 0, 0), "LeftPanel")
local RightPanel = CreateGradientPanel(mainFrame, UDim2.new(1, -180, 1, 0), UDim2.new(0, 180, 0, 0), "RightPanel")

-- ==================== LEFT PANEL CONTENT ====================
-- TÍTULO E SUBTÍTULO CENTRALIZADOS NO TOPO DO PAINEL ESQUERDO
local LeftHeaderFrame = Instance.new("Frame", LeftPanel.InnerBg)
LeftHeaderFrame.Name = "LeftHeaderFrame"
LeftHeaderFrame.Size = UDim2.new(1, 0, 0, 36)
LeftHeaderFrame.Position = UDim2.new(0, 0, 0, 0)
LeftHeaderFrame.BackgroundTransparency = 1
LeftHeaderFrame.ZIndex = 11

local title = Instance.new("TextLabel", LeftHeaderFrame)
title.Size = UDim2.new(1, 0, 0, 16)
title.Position = UDim2.new(0, 0, 0, 4)
title.BackgroundTransparency = 1
title.Text = "AKATSUKI SCRIPTS"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextSize = 11.5
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Center
title.ZIndex = 12

local subtitle = Instance.new("TextLabel", LeftHeaderFrame)
subtitle.Size = UDim2.new(1, 0, 0, 12)
subtitle.Position = UDim2.new(0, 0, 0, 20)
subtitle.BackgroundTransparency = 1
subtitle.Text = "MM2 SCRIPT | by zeni <3"
subtitle.TextColor3 = Color3.fromRGB(220, 50, 50)
subtitle.TextTransparency = 0.2
subtitle.TextSize = 8.5
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Center
subtitle.ZIndex = 12

local LeftSeparatorLine = Instance.new("Frame", LeftPanel.InnerBg)
LeftSeparatorLine.Size = UDim2.new(1, 0, 0, 1)
LeftSeparatorLine.Position = UDim2.new(0, 0, 0, 36)
LeftSeparatorLine.BackgroundColor3 = Color3.fromRGB(110, 25, 30)
LeftSeparatorLine.BorderSizePixel = 0
LeftSeparatorLine.ZIndex = 10

-- BARRA DE ROLAGAL PAINEL ESQUERDO
local TabsContainer = Instance.new("ScrollingFrame", LeftPanel.InnerBg)
TabsContainer.Name = "TabsContainer"
TabsContainer.Size = UDim2.new(1, 0, 1, -94)
TabsContainer.Position = UDim2.new(0, 0, 0, 44)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ZIndex = 10
TabsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
TabsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabsContainer.ScrollBarThickness = 3
TabsContainer.ScrollBarImageColor3 = Color3.fromRGB(180, 30, 40)
TabsContainer.ScrollBarImageTransparency = 0.4
TabsContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
TabsContainer.ClipsDescendants = true

local tabsPadding = Instance.new("UIPadding", TabsContainer)
tabsPadding.PaddingRight = UDim.new(0, 4)
tabsPadding.PaddingLeft = UDim.new(0, 4)

local TabsLayout = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabsLayout.Padding = UDim.new(0, 6)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local UserProfileFrame = Instance.new("Frame", LeftPanel.InnerBg)
UserProfileFrame.Size = UDim2.new(1, -12, 0, 44)
UserProfileFrame.Position = UDim2.new(0, 6, 1, -50)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
UserProfileFrame.BackgroundTransparency = 0.4
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex = 10
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 8)

local userGrad = Instance.new("UIGradient", UserProfileFrame)
userGrad.Rotation = 45
userGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 20)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 5, 5))
})

local AvatarImage = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Size = UDim2.new(0, 28, 0, 28)
AvatarImage.Position = UDim2.new(0, 6, 0.5, -14)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex = 11
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

local DisplayNameLabel = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Size = UDim2.new(1, -62, 0, 13)
DisplayNameLabel.Position = UDim2.new(0, 38, 0.5, -12)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
DisplayNameLabel.Font = Enum.Font.GothamBold
DisplayNameLabel.TextSize = 9.5
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLabel.ZIndex = 11

local UsernameLabel = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Size = UDim2.new(1, -62, 0, 11)
UsernameLabel.Position = UDim2.new(0, 38, 0.5, 1)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text = "@" .. player.Name
UsernameLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
UsernameLabel.Font = Enum.Font.Gotham
UsernameLabel.TextSize = 8.5
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UsernameLabel.ZIndex = 11

local PrivacyBtn = Instance.new("ImageButton", UserProfileFrame)
PrivacyBtn.Size = UDim2.new(0, 20, 0, 20)
PrivacyBtn.Position = UDim2.new(1, -24, 0.5, -10)
PrivacyBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
PrivacyBtn.BackgroundTransparency = 0.2
PrivacyBtn.ZIndex = 12
Instance.new("UICorner", PrivacyBtn).CornerRadius = UDim.new(0, 6)

local PrivacyIcon = Instance.new("ImageLabel", PrivacyBtn)
PrivacyIcon.Size = UDim2.new(1, -6, 1, -6)
PrivacyIcon.Position = UDim2.new(0, 3, 0, 3)
PrivacyIcon.BackgroundTransparency = 1
PrivacyIcon.Image = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
PrivacyIcon.ImageColor3 = Color3.fromRGB(220, 220, 220)
PrivacyIcon.ZIndex = 13

local isPrivate = false
PrivacyBtn.MouseButton1Click:Connect(function()
    isPrivate = not isPrivate
    if isPrivate then
        PrivacyIcon.Image = "rbxthumb://type=Asset&id=85795266774996&w=150&h=150"
        DisplayNameLabel.Text = string.rep("*", math.clamp(#player.DisplayName, 3, 8))
        UsernameLabel.Text = "@" .. string.rep("*", math.clamp(#player.Name, 3, 8))
    else
        PrivacyIcon.Image = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
        DisplayNameLabel.Text = player.DisplayName
        UsernameLabel.Text = "@" .. player.Name
    end
end)

-- ==================== RIGHT PANEL HEADER & BADGE ====================
local topButtons = Instance.new("Frame", RightPanel.InnerBg)
topButtons.Size = UDim2.new(1, -12, 0, 36)
topButtons.Position = UDim2.new(0, 0, 0, 0)
topButtons.BackgroundTransparency = 1
topButtons.ZIndex = 10

-- BADGE UI V3.8 REPOSICIONADA NO LADO ESQUERDO DO PAINEL DIREITO
local BadgeFrame = Instance.new("Frame", topButtons)
BadgeFrame.Name = "BadgeFrame"
BadgeFrame.Size = UDim2.new(0, 56, 0, 20)
BadgeFrame.Position = UDim2.new(0, 12, 0.5, -10)
BadgeFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
BadgeFrame.BorderSizePixel = 0
BadgeFrame.ZIndex = 12
Instance.new("UICorner", BadgeFrame).CornerRadius = UDim.new(0, 5)

local badgeGrad = Instance.new("UIGradient", BadgeFrame)
badgeGrad.Rotation = 45
badgeGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 0, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 0, 0))
})

local BadgeText = Instance.new("TextLabel", BadgeFrame)
BadgeText.Size = UDim2.new(1, 0, 1, 0)
BadgeText.BackgroundTransparency = 1
BadgeText.Text = "UI V3.8"
BadgeText.TextColor3 = Color3.fromRGB(235, 235, 235)
BadgeText.Font = Enum.Font.Gotham -- Fonte mais fina
BadgeText.TextSize = 9.5
BadgeText.ZIndex = 13

-- Container para os botões de controle da direita
local ControlsFrame = Instance.new("Frame", topButtons)
ControlsFrame.Size = UDim2.new(0, 120, 1, 0)
ControlsFrame.Position = UDim2.new(1, -120, 0, 0)
ControlsFrame.BackgroundTransparency = 1
ControlsFrame.ZIndex = 11

local UIListTop = Instance.new("UIListLayout", ControlsFrame)
UIListTop.FillDirection = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding = UDim.new(0, 5)
UIListTop.SortOrder = Enum.SortOrder.LayoutOrder

local SearchBtn = Instance.new("TextButton", ControlsFrame)
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

local ExpandBtn = Instance.new("TextButton", ControlsFrame)
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

local MinimizeBtn = Instance.new("TextButton", ControlsFrame)
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

local CloseBtn = Instance.new("TextButton", ControlsFrame)
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

local RightSeparatorLine = Instance.new("Frame", RightPanel.InnerBg)
RightSeparatorLine.Size = UDim2.new(1, 0, 0, 1)
RightSeparatorLine.Position = UDim2.new(0, 0, 0, 36)
RightSeparatorLine.BackgroundColor3 = Color3.fromRGB(110, 25, 30)
RightSeparatorLine.BorderSizePixel = 0
RightSeparatorLine.ZIndex = 10

-- BARRA DE ROLAGEM PAINEL DIREITO
local togglesContainer = Instance.new("ScrollingFrame", RightPanel.InnerBg)
togglesContainer.Name = "TogglesContainer"
togglesContainer.Size = UDim2.new(1, 0, 1, -44)
togglesContainer.Position = UDim2.new(0, 0, 0, 40)
togglesContainer.BackgroundTransparency = 1
togglesContainer.BorderSizePixel = 0
togglesContainer.ScrollBarThickness = 3
togglesContainer.ScrollBarImageColor3 = Color3.fromRGB(180, 30, 40)
togglesContainer.ScrollBarImageTransparency = 0.4
togglesContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
togglesContainer.ClipsDescendants = true
togglesContainer.ZIndex = 10
togglesContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
togglesContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y

local containerLayout = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
containerLayout.Padding = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local uiPadding = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingLeft = UDim.new(0, 8)
uiPadding.PaddingRight = UDim.new(0, 8)
uiPadding.PaddingBottom = UDim.new(0, 8)
uiPadding.PaddingTop = UDim.new(0, 2)

-- Confirm Frame
local confirmFrame = Instance.new("Frame", mainFrame)
confirmFrame.Name = "ConfirmFrame"
confirmFrame.Size = UDim2.new(1, 0, 1, 0)
confirmFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
confirmFrame.BackgroundTransparency = 0.4
confirmFrame.Visible = false
confirmFrame.ZIndex = 50
Instance.new("UICorner", confirmFrame).CornerRadius = UDim.new(0, 9)

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
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 6)

local btnNo = Instance.new("TextButton", confirmFrame)
btnNo.Size = UDim2.new(0, 110, 0, 34)
btnNo.Position = UDim2.new(0.5, 5, 0.55, 0)
btnNo.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
btnNo.TextColor3 = Color3.fromRGB(180, 180, 180)
btnNo.Font = Enum.Font.GothamMedium
btnNo.TextSize = 12
btnNo.Text = UI_TEXT.CancelBtn
btnNo.ZIndex = 51
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 6)

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
                    child.Size = UDim2.new(1, 0, 0, 0)
                    child.BackgroundTransparency = 1
                    local t = child:FindFirstChild("Title")
                    local d = child:FindFirstChild("Description")
                    if t then t.TextTransparency = 1 end
                    if d then d.TextTransparency = 1 end
                    task.delay((itemIndex - 1) * 0.02, function()
                        if not child or not child.Parent then return end
                        TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                            Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 0.35
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

local function createTabBtn(tabName)
    local tabBtn = Instance.new("TextButton", TabsContainer)
    tabBtn.Name = tabName .. "TabBtn"
    tabBtn.Size = UDim2.new(1, -8, 0, 36)
    tabBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text = ""
    tabBtn.ZIndex = 11
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 8)

    local activeBar = Instance.new("Frame", tabBtn)
    activeBar.Name = "ActiveBar"
    activeBar.Size = UDim2.new(0, 3, 0, 20)
    activeBar.Position = UDim2.new(0, 2, 0.5, -10)
    activeBar.BackgroundColor3 = Color3.fromHex("#8B0000")
    activeBar.BorderSizePixel = 0
    activeBar.Visible = false
    activeBar.ZIndex = 13 
    Instance.new("UICorner", activeBar).CornerRadius = UDim.new(1, 0)

    local iconContainer = Instance.new("Frame", tabBtn)
    iconContainer.Name = "Icon"
    iconContainer.Size = UDim2.new(0, 18, 0, 18) 
    iconContainer.Position = UDim2.new(0, 12, 0.5, -9)
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
    tabLabel.TextSize = 11
    tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.Text = UI_TEXT.Tabs[tabName] or tabName
    tabLabel.ZIndex = 12

    tabBtn.MouseButton1Click:Connect(function() selectTab(tabName) end)
    tabButtons[tabName] = tabBtn
end

local function createToggle(parent, configKey, tabCategory)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = configKey
    toggleFrame.Size = UDim2.new(1, 0, 0, 52)
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
    local newSize = isExpanded and UDim2.new(0, 620, 0, 380) or UDim2.new(0, 535, 0, 300)
    TweenService:Create(mainWrapper, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = newSize}):Play()
end)

SetUIState = function(newState)
    if UIState == newState or UIState == "OPENING" or UIState == "CLOSING" then return end
    
    UIState = (newState == "OPEN" and "OPENING") or (newState == "MINIMIZED" and "CLOSING") or (newState == "CLOSED" and "CLOSING") or newState
    local tempoAnim = 0.25
    local windowAnim = TweenInfo.new(tempoAnim, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    if newState == "OPEN" then
        mainWrapper.Visible = true
        mainWrapper.Size = UDim2.new(0, 480, 0, 260)
        AplicarFadeSincronizado(mainWrapper, true, 0)
        AplicarFadeSincronizado(mainWrapper, false, tempoAnim)
        
        local openTween = TweenService:Create(mainWrapper, windowAnim, {Size = isExpanded and UDim2.new(0, 620, 0, 380) or UDim2.new(0, 535, 0, 300)})
        openTween:Play()
        openTween.Completed:Connect(function()
            UIState = "OPEN"
            filterToggles(activeTab, searchTextBox.Text)
        end)

    elseif newState == "MINIMIZED" or newState == "CLOSED" then
        AplicarFadeSincronizado(mainWrapper, true, tempoAnim)
        local closeTween = TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 480, 0, 260)})
        closeTween:Play()
        
        closeTween.Completed:Connect(function()
            mainWrapper.Visible = false
            UIState = newState
        end)
    end
end

MinimizeBtn.MouseButton1Click:Connect(function() 
    SetUIState("MINIMIZED")
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

    mainWrapper.Visible = true
    FloatBtn.Visible = true 
    UIState = "OPEN"
    local MainScale = Instance.new("UIScale", mainWrapper); MainScale.Scale = 0.85
    AplicarFadeSincronizado(mainWrapper, true, 0)
    AplicarFadeSincronizado(mainWrapper, false, 0.35)
    
    local openScale = TweenService:Create(MainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
    openScale:Play()
    
    FloatBtn.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(FloatBtn, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 44, 0, 44)}):Play()
    
    openScale.Completed:Connect(function() 
        selectTab("Player") 
        MainScale:Destroy(); IntroFrame:Destroy(); Blur:Destroy()
    end)
end

ExecutarIntroAkat()
