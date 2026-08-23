-- [[ AKATSUKI UI ONLY [v3.6] - FIXED & IMPROVED (SOLID LIQUID RED EDITION) - REDESIGN ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")

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
local UIState = "CLOSED" 

local UI_TEXT = {
    SearchPlaceholder = "Search...",
    ConfirmCloseTitle = "Do you want to close the script?",
    ConfirmBtn = "Confirm",
    CancelBtn = "Cancel",
    Intro = '<font color="#FFFFFF">Scripts by | </font><font color="#8B0000">AKATSUKI</font>',
    Tabs = { Player = "Player", Combat = "Combat", Visuals = "Visuals", Teleports = "Teleports", Settings = "Settings" },
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

-- ==================== NOVA PALETA DE CORES (REDESIGN) ====================
local Palette = {
    BgMain        = Color3.fromHex("#09090B"),
    PanelMain     = Color3.fromHex("#100609"),
    AreaInner     = Color3.fromHex("#14070A"),
    AreaSecondary = Color3.fromHex("#18080B"),
    BlackAux      = Color3.fromHex("#0D0D0F"),
    RedDark       = Color3.fromHex("#650008"),
    RedMain       = Color3.fromHex("#8B0000"),
    RedAccent     = Color3.fromHex("#B51A24"),
    RedBright     = Color3.fromHex("#D52A35"),
    White         = Color3.fromHex("#F2F2F2"),
    TextSecondary = Color3.fromHex("#A5A5A5"),
    TextTertiary  = Color3.fromHex("#707070"),
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
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then uiParent = gethui() else pcall(function() uiParent = game:GetService("CoreGui") end) end
if uiParent:FindFirstChild("DeltaAkatUniversalUI") then pcall(function() uiParent.DeltaAkatUniversalUI:Destroy() end) end
screenGui.Parent = uiParent

local SharedClickSound = Instance.new("Sound", screenGui)
SharedClickSound.Name = "SharedClickSound"
SharedClickSound.SoundId = "rbxassetid://6895079853"
SharedClickSound.Volume = 0.6
SharedClickSound.Looped = false

local function PlayUI_Click()
    pcall(function()
        SharedClickSound.TimePosition = 0
        SharedClickSound:Play()
    end)
end

local function RegistrarTransparencias(objeto)
    if originalTrans[objeto] then return end
    if objeto:IsA("Frame") or objeto:IsA("ScrollingFrame") or objeto:IsA("CanvasGroup") then 
        originalTrans[objeto] = { BackgroundTransparency = objeto.BackgroundTransparency }
    elseif objeto:IsA("TextLabel") or objeto:IsA("TextButton") or objeto:IsA("TextBox") then
        originalTrans[objeto] = { TextTransparency = objeto.TextTransparency, BackgroundTransparency = objeto.BackgroundTransparency, TextStrokeTransparency = objeto.TextStrokeTransparency or 1 }
    elseif objeto:IsA("ImageLabel") or objeto:IsA("ImageButton") then 
        originalTrans[objeto] = { ImageTransparency = objeto.ImageTransparency, BackgroundTransparency = objeto.BackgroundTransparency }
    elseif objeto:IsA("UIStroke") then 
        originalTrans[objeto] = { Transparency = objeto.Transparency } 
    end
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
FloatBtn.BackgroundColor3 = Palette.BlackAux
FloatBtn.Visible = true
FloatBtn.ZIndex = 100
FloatBtn.ClipsDescendants = false
if not FloatBtn:FindFirstChildOfClass("UICorner") then Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8) end

local FloatOpenSound = FloatBtn:FindFirstChild("FloatOpenSound") or Instance.new("Sound", FloatBtn)
FloatOpenSound.Name = "FloatOpenSound"
FloatOpenSound.SoundId = "rbxassetid://6310837681"
FloatOpenSound.Volume = 0.2 
FloatOpenSound.Looped = false

task.spawn(function()
    pcall(function()
        ContentProvider:PreloadAsync({FloatOpenSound, SharedClickSound})
    end)
end)

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
            if UIState == "MINIMIZED" or UIState == "CLOSED" then
                pcall(function() 
                    FloatOpenSound.TimePosition = 0
                    FloatOpenSound:Play() 
                end)
                SetUIState("OPEN")
            elseif UIState == "OPEN" then
                SetUIState("MINIMIZED")
            end
        end
        dragToggle = false 
    end
end)

-- ==================== SISTEMA RESPONSIVO (VIEWPORT) ====================
local Camera = workspace.CurrentCamera

local function GetSafeUISize(baseW, baseH)
    local viewport = Camera and Camera.ViewportSize or Vector2.new(1280, 720)
    local marginX = 40
    local marginY = 40
    local maxW = math.max(viewport.X - marginX, 280)
    local maxH = math.max(viewport.Y - marginY, 200)

    local scale = math.min(1, maxW / baseW, maxH / baseH)
    scale = math.clamp(scale, 0.55, 1)

    return UDim2.new(0, math.floor(baseW * scale), 0, math.floor(baseH * scale))
end

-- ==================== INTERFACE PRINCIPAL ====================
local mainWrapper = Instance.new("Frame", screenGui)
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0.5)
mainWrapper.Size = GetSafeUISize(640, 360) 
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible = false
mainWrapper.ClipsDescendants = false
mainWrapper.ZIndex = 1

local UIScaleMain = Instance.new("UIScale", mainWrapper)
UIScaleMain.Scale = 1

local mainFrame = Instance.new("Frame", mainWrapper)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundTransparency = 1 
mainFrame.ZIndex = 2
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

-- ==================== PREMIUM DARK PANEL SYSTEM (REDESIGN) ====================
local function CreateShadow(parent, cornerRadius)
    -- Camada de sombra ampla e suave
    local shadowWide = Instance.new("Frame", parent)
    shadowWide.Name = "ShadowWide"
    shadowWide.Size = UDim2.new(1, 18, 1, 18)
    shadowWide.Position = UDim2.new(0, -9, 0, -9)
    shadowWide.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadowWide.BackgroundTransparency = 0.78
    shadowWide.BorderSizePixel = 0
    shadowWide.ZIndex = 3
    Instance.new("UICorner", shadowWide).CornerRadius = UDim.new(0, cornerRadius + 6)

    -- Camada de sombra próxima e mais forte
    local shadowTight = Instance.new("Frame", parent)
    shadowTight.Name = "ShadowTight"
    shadowTight.Size = UDim2.new(1, 6, 1, 8)
    shadowTight.Position = UDim2.new(0, -3, 0, 3)
    shadowTight.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadowTight.BackgroundTransparency = 0.62
    shadowTight.BorderSizePixel = 0
    shadowTight.ZIndex = 4
    Instance.new("UICorner", shadowTight).CornerRadius = UDim.new(0, cornerRadius + 2)

    return shadowWide, shadowTight
end

local function CreateGradientPanel(parent, size, pos, name)
    local panel = Instance.new("Frame", parent)
    panel.Name = name
    panel.Size = size
    panel.Position = pos
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ZIndex = 5
    panel.ClipsDescendants = false

    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

    -- Sombra 3D real, sutil, sem caixa preta visível atrás
    CreateShadow(panel, 10)

    local outerStroke = Instance.new("UIStroke", panel)
    outerStroke.Name = "OuterStroke"
    outerStroke.Thickness = 1.2
    outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    outerStroke.Color = Color3.fromRGB(255, 255, 255)
    
    local outerGrad = Instance.new("UIGradient", outerStroke)
    outerGrad.Rotation = 45
    outerGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, Palette.RedDark),
        ColorSequenceKeypoint.new(1, Palette.RedMain)
    })

    local InnerBg = Instance.new("Frame", panel)
    InnerBg.Name = "InnerBg"
    InnerBg.Size = UDim2.new(1, 0, 1, 0)
    InnerBg.BackgroundColor3 = Palette.PanelMain
    InnerBg.BackgroundTransparency = 0 
    InnerBg.BorderSizePixel = 0
    InnerBg.ClipsDescendants = true
    InnerBg.ZIndex = 5
    Instance.new("UICorner", InnerBg).CornerRadius = UDim.new(0, 10)
    
    local overlay = Instance.new("Frame", InnerBg)
    overlay.Name = "RedGradientOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    overlay.BackgroundTransparency = 0
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 5
    Instance.new("UICorner", overlay).CornerRadius = UDim.new(0, 10)

    -- Overlay agora quase estático (predominantemente dark), com leve tom vermelho de identidade
    local redGrad = Instance.new("UIGradient", overlay)
    redGrad.Rotation = 90
    redGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Palette.AreaInner), 
        ColorSequenceKeypoint.new(1, Palette.BgMain)
    })
    overlay.BackgroundTransparency = 0.15

    -- Apenas o stroke principal (item de maior prioridade) mantém animação contínua e lenta
    RunService.RenderStepped:Connect(function()
        local t = os.clock()
        outerGrad.Rotation = (t * 4) % 360
    end)
    
    return panel
end

local LeftPanel = CreateGradientPanel(mainFrame, UDim2.new(0, 220, 1, 0), UDim2.new(0, 0, 0, 0), "LeftPanel")
local RightPanel = CreateGradientPanel(mainFrame, UDim2.new(1, -235, 1, 0), UDim2.new(0, 235, 0, 0), "RightPanel")

local LeftSeparatorLine = Instance.new("Frame", LeftPanel.InnerBg)
LeftSeparatorLine.Size = UDim2.new(1, 0, 0, 1)
LeftSeparatorLine.Position = UDim2.new(0, 0, 0, 36)
LeftSeparatorLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
LeftSeparatorLine.BackgroundTransparency = 0.85
LeftSeparatorLine.BorderSizePixel = 0
LeftSeparatorLine.ZIndex = 10

local HeaderLeft = Instance.new("Frame", LeftPanel.InnerBg)
HeaderLeft.Size = UDim2.new(1, 0, 0, 36)
HeaderLeft.Position = UDim2.new(0, 0, 0, 0)
HeaderLeft.BackgroundTransparency = 1
HeaderLeft.ZIndex = 10

local title = Instance.new("TextLabel", HeaderLeft)
title.Size = UDim2.new(1, 0, 0, 16)
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 4)
title.BackgroundTransparency = 1
title.Text = "AKATSUKI SCRIPTS"
title.TextColor3 = Palette.White
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Center
title.ZIndex = 11

local subtitle = Instance.new("TextLabel", HeaderLeft)
subtitle.Size = UDim2.new(1, 0, 0, 12)
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Position = UDim2.new(0.5, 0, 0, 20)
subtitle.BackgroundTransparency = 1
subtitle.Text = "MM2 SCRIPT | by zeni <3"
subtitle.TextColor3 = Palette.TextSecondary
subtitle.TextTransparency = 0.2
subtitle.TextSize = 9.5
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Center
subtitle.ZIndex = 11

-- ==================== SEARCH BAR (REDESIGN) ====================
local SearchContainer = Instance.new("Frame", LeftPanel.InnerBg)
SearchContainer.Name = "SearchContainer"
SearchContainer.Size = UDim2.new(1, -16, 0, 34)
SearchContainer.Position = UDim2.new(0, 8, 0, 44)
SearchContainer.BackgroundColor3 = Palette.BlackAux
SearchContainer.BackgroundTransparency = 0.25
SearchContainer.ZIndex = 10
Instance.new("UICorner", SearchContainer).CornerRadius = UDim.new(0, 9)

local searchStroke = Instance.new("UIStroke", SearchContainer)
searchStroke.Name = "SearchStroke"
searchStroke.Color = Color3.fromRGB(60, 60, 65)
searchStroke.Transparency = 0.55
searchStroke.Thickness = 1

local SearchIconFrame = Instance.new("Frame", SearchContainer)
SearchIconFrame.Size = UDim2.new(0, 14, 0, 14)
SearchIconFrame.Position = UDim2.new(0, 10, 0.5, -7)
SearchIconFrame.BackgroundTransparency = 1
SearchIconFrame.ZIndex = 12

local scCircle = Instance.new("Frame", SearchIconFrame)
scCircle.Size = UDim2.new(0, 8, 0, 8)
scCircle.BackgroundTransparency = 1
Instance.new("UICorner", scCircle).CornerRadius = UDim.new(1, 0)
local scCStroke = Instance.new("UIStroke", scCircle)
scCStroke.Color = Palette.TextSecondary
scCStroke.Thickness = 1.2

local scHandle = Instance.new("Frame", SearchIconFrame)
scHandle.Size = UDim2.new(0, 1.2, 0, 5)
scHandle.Position = UDim2.new(0, 9, 0, 8)
scHandle.Rotation = -45
scHandle.BackgroundColor3 = Palette.TextSecondary
scHandle.BorderSizePixel = 0

local searchTextBox = Instance.new("TextBox", SearchContainer)
searchTextBox.Size = UDim2.new(1, -34, 1, 0)
searchTextBox.Position = UDim2.new(0, 30, 0, 0)
searchTextBox.BackgroundTransparency = 1
searchTextBox.PlaceholderText = UI_TEXT.SearchPlaceholder
searchTextBox.PlaceholderColor3 = Palette.TextTertiary
searchTextBox.Text = ""
searchTextBox.TextColor3 = Palette.White
searchTextBox.Font = Enum.Font.Gotham
searchTextBox.TextSize = 11
searchTextBox.TextXAlignment = Enum.TextXAlignment.Left
searchTextBox.ZIndex = 12

-- Foco visual sutil na search bar (sem exagero)
searchTextBox.Focused:Connect(function()
    TweenService:Create(searchStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {Color = Palette.RedDark, Transparency = 0.15}):Play()
end)
searchTextBox.FocusLost:Connect(function()
    TweenService:Create(searchStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {Color = Color3.fromRGB(60, 60, 65), Transparency = 0.55}):Play()
end)

-- ==================== TABS & PROFILE ====================
local TabsContainer = Instance.new("ScrollingFrame", LeftPanel.InnerBg)
TabsContainer.Name = "TabsContainer"
TabsContainer.Size = UDim2.new(1, -8, 1, -145)
TabsContainer.Position = UDim2.new(0, 4, 0, 86)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ZIndex = 10
TabsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
TabsContainer.ScrollBarThickness = 3
TabsContainer.ScrollBarImageColor3 = Palette.RedAccent
TabsContainer.ScrollBarImageTransparency = 0.2
TabsContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

local TabsLayout = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabsLayout.Padding = UDim.new(0, 2)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function UpdateTabsCanvas()
    local contentH = TabsLayout.AbsoluteContentSize.Y + 8
    local minH = TabsContainer.AbsoluteSize.Y + 12
    TabsContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(contentH, minH))
end

TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabsCanvas)
TabsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTabsCanvas)

local UserProfileFrame = Instance.new("Frame", LeftPanel.InnerBg)
UserProfileFrame.Size = UDim2.new(1, -16, 0, 58)
UserProfileFrame.Position = UDim2.new(0, 8, 1, -66)
UserProfileFrame.BackgroundColor3 = Palette.BlackAux
UserProfileFrame.BackgroundTransparency = 0.35
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex = 10
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 8)

-- BADGE STROKE (discreta, com leve acento vermelho passando lentamente)
local userStroke = Instance.new("UIStroke", UserProfileFrame)
userStroke.Thickness = 1
userStroke.Color = Color3.fromRGB(60, 60, 65)
userStroke.Transparency = 0.4
local uGrad = Instance.new("UIGradient", userStroke)
uGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Palette.RedAccent),
    ColorSequenceKeypoint.new(0.15, Color3.fromRGB(60, 60, 65)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 60, 65))
})
RunService.RenderStepped:Connect(function()
    uGrad.Rotation = (os.clock() * 8) % 360
end)

local userGrad = Instance.new("UIGradient", UserProfileFrame)
userGrad.Rotation = 45
userGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 16, 18)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 6, 7))
})

local AvatarImage = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Size = UDim2.new(0, 38, 0, 38)
AvatarImage.Position = UDim2.new(0, 10, 0.5, -19)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex = 11
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

-- Contorno circular fino, estático, com pequeno destaque vermelho
local AvatarStroke = Instance.new("UIStroke", AvatarImage)
AvatarStroke.Thickness = 1.2
AvatarStroke.Color = Palette.RedAccent
AvatarStroke.Transparency = 0.35

local DisplayNameLabel = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Size = UDim2.new(1, -92, 0, 16)
DisplayNameLabel.Position = UDim2.new(0, 58, 0.5, -17)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text = player.DisplayName
DisplayNameLabel.TextColor3 = Palette.White
DisplayNameLabel.Font = Enum.Font.GothamBold
DisplayNameLabel.TextSize = 13.5
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLabel.ZIndex = 11

local UsernameLabel = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Size = UDim2.new(1, -92, 0, 14)
UsernameLabel.Position = UDim2.new(0, 58, 0.5, 3)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text = "@" .. player.Name
UsernameLabel.TextColor3 = Palette.TextTertiary
UsernameLabel.Font = Enum.Font.Gotham
UsernameLabel.TextSize = 11
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UsernameLabel.ZIndex = 11

local PrivacyBtn = Instance.new("ImageButton", UserProfileFrame)
PrivacyBtn.Size = UDim2.new(0, 21, 0, 21)
PrivacyBtn.Position = UDim2.new(1, -30, 0.5, -11)
PrivacyBtn.BackgroundColor3 = Palette.BlackAux
PrivacyBtn.BackgroundTransparency = 0.1
PrivacyBtn.BorderSizePixel = 0
PrivacyBtn.ZIndex = 12
Instance.new("UICorner", PrivacyBtn).CornerRadius = UDim.new(0, 6)

local privStroke = Instance.new("UIStroke", PrivacyBtn)
privStroke.Color = Color3.fromRGB(60, 60, 65)
privStroke.Transparency = 0.5
privStroke.Thickness = 1

local PrivacyIcon = Instance.new("ImageLabel", PrivacyBtn)
PrivacyIcon.Size = UDim2.new(1, -8, 1, -8)
PrivacyIcon.Position = UDim2.new(0, 4, 0, 4)
PrivacyIcon.BackgroundTransparency = 1
PrivacyIcon.Image = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
PrivacyIcon.ImageColor3 = Palette.TextSecondary
PrivacyIcon.ZIndex = 13

PrivacyBtn.MouseEnter:Connect(function()
    TweenService:Create(PrivacyBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Palette.RedDark, BackgroundTransparency = 0.25}):Play()
    TweenService:Create(PrivacyIcon, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {ImageColor3 = Palette.White}):Play()
end)
PrivacyBtn.MouseLeave:Connect(function()
    TweenService:Create(PrivacyBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Palette.BlackAux, BackgroundTransparency = 0.1}):Play()
    TweenService:Create(PrivacyIcon, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {ImageColor3 = Palette.TextSecondary}):Play()
end)

local isPrivate = false
PrivacyBtn.MouseButton1Click:Connect(function()
    PlayUI_Click()
    local flashTween = TweenService:Create(PrivacyBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {BackgroundTransparency = 0})
    flashTween:Play()

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

local ControlsFrame = Instance.new("Frame", topButtons)
ControlsFrame.Size = UDim2.new(0, 96, 1, 0)
ControlsFrame.Position = UDim2.new(1, -96, 0, 0)
ControlsFrame.BackgroundTransparency = 1
ControlsFrame.ZIndex = 11

local UIListTop = Instance.new("UIListLayout", ControlsFrame)
UIListTop.FillDirection = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding = UDim.new(0, 6)
UIListTop.SortOrder = Enum.SortOrder.LayoutOrder

local MinimizeBtn = Instance.new("TextButton", ControlsFrame)
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.LayoutOrder = 1
MinimizeBtn.Size = UDim2.new(0, 26, 0, 26)
MinimizeBtn.BackgroundColor3 = Palette.BlackAux
MinimizeBtn.BackgroundTransparency = 0.3
MinimizeBtn.Text = ""
MinimizeBtn.ZIndex = 11
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 7)
local MinimizeLine = Instance.new("Frame", MinimizeBtn)
MinimizeLine.Name = "Line"
MinimizeLine.AnchorPoint = Vector2.new(0.5, 0.5)
MinimizeLine.Position = UDim2.new(0.5, 0, 0.5, 0)
MinimizeLine.Size = UDim2.new(0, 9, 0, 1.2)
MinimizeLine.BackgroundColor3 = Palette.TextSecondary
MinimizeLine.BorderSizePixel = 0
MinimizeLine.ZIndex = 12

local ExpandBtn = Instance.new("TextButton", ControlsFrame)
ExpandBtn.Name = "ExpandBtn"
ExpandBtn.LayoutOrder = 2
ExpandBtn.Size = UDim2.new(0, 26, 0, 26)
ExpandBtn.BackgroundColor3 = Palette.BlackAux
ExpandBtn.BackgroundTransparency = 0.3
ExpandBtn.Text = ""
ExpandBtn.ZIndex = 11
Instance.new("UICorner", ExpandBtn).CornerRadius = UDim.new(0, 7)

local ExpandSquare = Instance.new("Frame", ExpandBtn)
ExpandSquare.Name = "Square"
ExpandSquare.Size = UDim2.new(0, 7, 0, 7)
ExpandSquare.AnchorPoint = Vector2.new(0.5, 0.5)
ExpandSquare.Position = UDim2.new(0.5, 0, 0.5, 0)
ExpandSquare.BackgroundTransparency = 1
ExpandSquare.ZIndex = 12
local ExpandStroke = Instance.new("UIStroke", ExpandSquare)
ExpandStroke.Color = Palette.TextSecondary
ExpandStroke.Thickness = 1 

local CloseBtn = Instance.new("TextButton", ControlsFrame)
CloseBtn.Name = "CloseBtn"
CloseBtn.LayoutOrder = 3
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.BackgroundColor3 = Palette.BlackAux
CloseBtn.BackgroundTransparency = 0.3
CloseBtn.Text = ""
CloseBtn.ZIndex = 11
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 7)
local CloseLine1 = Instance.new("Frame", CloseBtn)
CloseLine1.Name = "Line1"
CloseLine1.AnchorPoint = Vector2.new(0.5, 0.5)
CloseLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine1.Size = UDim2.new(0, 10, 0, 1.2)
CloseLine1.Rotation = 45
CloseLine1.BackgroundColor3 = Palette.TextSecondary
CloseLine1.BorderSizePixel = 0
CloseLine1.ZIndex = 12
local CloseLine2 = Instance.new("Frame", CloseBtn)
CloseLine2.Name = "Line2"
CloseLine2.AnchorPoint = Vector2.new(0.5, 0.5)
CloseLine2.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine2.Size = UDim2.new(0, 10, 0, 1.2)
CloseLine2.Rotation = -45
CloseLine2.BackgroundColor3 = Palette.TextSecondary
CloseLine2.BorderSizePixel = 0
CloseLine2.ZIndex = 12

local RightSeparatorLine = Instance.new("Frame", RightPanel.InnerBg)
RightSeparatorLine.Size = UDim2.new(1, 0, 0, 1)
RightSeparatorLine.Position = UDim2.new(0, 0, 0, 36)
RightSeparatorLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
RightSeparatorLine.BackgroundTransparency = 0.9
RightSeparatorLine.BorderSizePixel = 0
RightSeparatorLine.ZIndex = 10

local BadgeFrame = Instance.new("Frame", RightPanel.InnerBg)
BadgeFrame.Name = "BadgeFrame"
BadgeFrame.Size = UDim2.new(0, 44, 0, 18)
BadgeFrame.Position = UDim2.new(0, 12, 0, 9)
BadgeFrame.BackgroundColor3 = Palette.BlackAux
BadgeFrame.BorderSizePixel = 0
BadgeFrame.ZIndex = 15
Instance.new("UICorner", BadgeFrame).CornerRadius = UDim.new(1, 0)

local badgeGrad = Instance.new("UIGradient", BadgeFrame)
badgeGrad.Rotation = 45
badgeGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 8, 8)),
    ColorSequenceKeypoint.new(1, Palette.RedDark)
})

local BadgeText = Instance.new("TextLabel", BadgeFrame)
BadgeText.Size = UDim2.new(1, 0, 1, 0)
BadgeText.BackgroundTransparency = 1
BadgeText.Text = "V3.6"
BadgeText.TextColor3 = Palette.White
BadgeText.Font = Enum.Font.GothamBold
BadgeText.TextSize = 8.5
BadgeText.ZIndex = 16

local BadgeStroke = Instance.new("UIStroke", BadgeFrame)
BadgeStroke.Color = Palette.RedAccent
BadgeStroke.Transparency = 0.75
BadgeStroke.Thickness = 1
BadgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local togglesContainer = Instance.new("ScrollingFrame", RightPanel.InnerBg)
togglesContainer.Name = "TogglesContainer"
togglesContainer.Size = UDim2.new(1, -6, 1, -48)
togglesContainer.Position = UDim2.new(0, 0, 0, 42)
togglesContainer.BackgroundTransparency = 1
togglesContainer.BorderSizePixel = 0
togglesContainer.ScrollBarThickness = 3
togglesContainer.ScrollBarImageColor3 = Palette.RedAccent
togglesContainer.ScrollBarImageTransparency = 0
togglesContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
togglesContainer.AutomaticCanvasSize = Enum.AutomaticSize.None
togglesContainer.ZIndex = 10

local containerLayout = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
containerLayout.Padding = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local uiPadding = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingTop = UDim.new(0, 8)
uiPadding.PaddingBottom = UDim.new(0, 8)
uiPadding.PaddingLeft = UDim.new(0, 4)
uiPadding.PaddingRight = UDim.new(0, 4)

local function UpdateCanvasSize()
    local contentHeight = containerLayout.AbsoluteContentSize.Y + 24
    local minHeight = togglesContainer.AbsoluteSize.Y + 1
    togglesContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(contentHeight, minHeight))
end

containerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvasSize)
togglesContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateCanvasSize)

-- ==================== CONFIRM FRAME (REDESIGNED) ====================
local confirmOverlay = Instance.new("Frame", mainWrapper)
confirmOverlay.Name = "ConfirmOverlay"
confirmOverlay.Size = UDim2.new(1, 0, 1, 0)
confirmOverlay.Position = UDim2.new(0, 0, 0, 0)
confirmOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
confirmOverlay.BackgroundTransparency = 1 
confirmOverlay.Visible = false
confirmOverlay.ZIndex = 990
confirmOverlay.ClipsDescendants = true
Instance.new("UICorner", confirmOverlay).CornerRadius = UDim.new(0, 10)

local confirmCard = Instance.new("Frame", confirmOverlay)
confirmCard.Name = "ConfirmCard"
confirmCard.Size = UDim2.new(0, 300, 0, 130)
confirmCard.AnchorPoint = Vector2.new(0.5, 0.5)
confirmCard.Position = UDim2.new(0.5, 0, 0.5, 0)
confirmCard.BackgroundColor3 = Palette.AreaInner
confirmCard.BackgroundTransparency = 0
confirmCard.BorderSizePixel = 0
confirmCard.ZIndex = 995
Instance.new("UICorner", confirmCard).CornerRadius = UDim.new(0, 14)

-- Contorno discreto e estático para a tela de confirmação
local confirmStroke = Instance.new("UIStroke", confirmCard)
confirmStroke.Thickness = 1.2
confirmStroke.Color = Palette.RedAccent
confirmStroke.Transparency = 0.55

local confirmCardGrad = Instance.new("UIGradient", confirmCard)
confirmCardGrad.Rotation = 135
confirmCardGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 10, 11)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 5, 6))
})

local confirmLabel = Instance.new("TextLabel", confirmCard)
confirmLabel.Size = UDim2.new(1, -24, 0, 22)
confirmLabel.Position = UDim2.new(0, 12, 0, 18)
confirmLabel.BackgroundTransparency = 1
confirmLabel.TextColor3 = Palette.White
confirmLabel.Font = Enum.Font.GothamBold
confirmLabel.TextSize = 13
confirmLabel.TextXAlignment = Enum.TextXAlignment.Center
confirmLabel.Text = UI_TEXT.ConfirmCloseTitle
confirmLabel.ZIndex = 1000

local confirmSep = Instance.new("Frame", confirmCard)
confirmSep.Size = UDim2.new(1, -40, 0, 1)
confirmSep.Position = UDim2.new(0, 20, 0, 48)
confirmSep.BackgroundColor3 = Palette.RedDark
confirmSep.BackgroundTransparency = 0.6
confirmSep.BorderSizePixel = 0
confirmSep.ZIndex = 999
Instance.new("UICorner", confirmSep).CornerRadius = UDim.new(1, 0)

local btnYes = Instance.new("TextButton", confirmCard)
btnYes.Size = UDim2.new(0, 118, 0, 32)
btnYes.Position = UDim2.new(0.5, -124, 0, 62)
btnYes.BackgroundColor3 = Palette.RedMain
btnYes.TextColor3 = Palette.White
btnYes.Font = Enum.Font.GothamMedium
btnYes.TextSize = 11
btnYes.Text = UI_TEXT.ConfirmBtn
btnYes.ZIndex = 1000
btnYes.BorderSizePixel = 0
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 8)
local btnYesGrad = Instance.new("UIGradient", btnYes)
btnYesGrad.Rotation = 90
btnYesGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Palette.RedAccent),
    ColorSequenceKeypoint.new(1, Palette.RedDark)
})

local btnNo = Instance.new("TextButton", confirmCard)
btnNo.Size = UDim2.new(0, 118, 0, 32)
btnNo.Position = UDim2.new(0.5, 6, 0, 62)
btnNo.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
btnNo.TextColor3 = Palette.TextSecondary
btnNo.Font = Enum.Font.GothamMedium
btnNo.TextSize = 11
btnNo.Text = UI_TEXT.CancelBtn
btnNo.ZIndex = 1000
btnNo.BorderSizePixel = 0
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 8)
local btnNoStroke = Instance.new("UIStroke", btnNo)
btnNoStroke.Color = Color3.fromRGB(60, 60, 60)
btnNoStroke.Thickness = 1
btnNoStroke.Transparency = 0.3

btnYes.MouseEnter:Connect(function() TweenService:Create(btnYes, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Palette.RedAccent}):Play() end)
btnYes.MouseLeave:Connect(function() TweenService:Create(btnYes, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Palette.RedMain}):Play() end)
btnNo.MouseEnter:Connect(function() TweenService:Create(btnNo, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(42, 42, 42)}):Play() end)
btnNo.MouseLeave:Connect(function() TweenService:Create(btnNo, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(28, 28, 28)}):Play() end)

-- Ensure initial correct transparencies map immediately 
AplicarFadeSincronizado(confirmCard, true, 0) 

-- ==================== SISTEMA DE NOTIFICAÇÃO ====================
local NOTIF_DURATION = 6 

local function CriarNotificacao(titulo, descricao, icone)
    local notifHolder = Instance.new("Frame", screenGui)
    notifHolder.Name = "NotifHolder"
    notifHolder.AnchorPoint = Vector2.new(1, 1)
    notifHolder.Size = UDim2.new(0, 300, 0, 80)
    notifHolder.Position = UDim2.new(1, -20, 1, -24)
    notifHolder.BackgroundTransparency = 1
    notifHolder.ZIndex = 200
    notifHolder.ClipsDescendants = false

    local notifCard = Instance.new("Frame", notifHolder)
    notifCard.Name = "NotifCard"
    notifCard.Size = UDim2.new(1, 0, 1, 0)
    notifCard.BackgroundColor3 = Palette.AreaInner
    notifCard.BackgroundTransparency = 0.08
    notifCard.BorderSizePixel = 0
    notifCard.ZIndex = 201
    notifCard.ClipsDescendants = false
    Instance.new("UICorner", notifCard).CornerRadius = UDim.new(0, 16)

    local notifStroke = Instance.new("UIStroke", notifCard)
    notifStroke.Thickness = 1
    notifStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    notifStroke.Color = Color3.fromRGB(60, 60, 65)
    notifStroke.Transparency = 0.5

    -- Sombra sutil, sem caixa preta visível
    local shadowFrame = Instance.new("Frame", notifHolder)
    shadowFrame.Name = "Shadow"
    shadowFrame.Size = UDim2.new(1, 10, 1, 10)
    shadowFrame.Position = UDim2.new(0, -5, 0, 4)
    shadowFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadowFrame.BackgroundTransparency = 0.75
    shadowFrame.BorderSizePixel = 0
    shadowFrame.ZIndex = 199
    Instance.new("UICorner", shadowFrame).CornerRadius = UDim.new(0, 18)

    local accentBar = Instance.new("Frame", notifCard)
    accentBar.Size = UDim2.new(0, 3, 0, 40)
    accentBar.Position = UDim2.new(0, 12, 0.5, -20)
    accentBar.BackgroundColor3 = Palette.RedAccent
    accentBar.BorderSizePixel = 0
    accentBar.ZIndex = 202
    Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)
    local accentGrad = Instance.new("UIGradient", accentBar)
    accentGrad.Rotation = 90
    accentGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Palette.RedBright),
        ColorSequenceKeypoint.new(1, Palette.RedDark)
    })

    local notifTitle = Instance.new("TextLabel", notifCard)
    notifTitle.Size = UDim2.new(1, -68, 0, 18)
    notifTitle.Position = UDim2.new(0, 24, 0, 12)
    notifTitle.BackgroundTransparency = 1
    notifTitle.Text = titulo or "AKATSUKI"
    notifTitle.TextColor3 = Palette.White
    notifTitle.Font = Enum.Font.GothamBold
    notifTitle.TextSize = 13
    notifTitle.TextXAlignment = Enum.TextXAlignment.Left
    notifTitle.ZIndex = 203

    local notifDesc = Instance.new("TextLabel", notifCard)
    notifDesc.Size = UDim2.new(1, -34, 0, 30)
    notifDesc.Position = UDim2.new(0, 24, 0, 32)
    notifDesc.BackgroundTransparency = 1
    notifDesc.Text = descricao or ""
    notifDesc.TextColor3 = Palette.TextSecondary
    notifDesc.Font = Enum.Font.Gotham
    notifDesc.TextSize = 11.5
    notifDesc.TextXAlignment = Enum.TextXAlignment.Left
    notifDesc.TextYAlignment = Enum.TextYAlignment.Top
    notifDesc.TextWrapped = true
    notifDesc.ZIndex = 203

    local notifCloseBtn = Instance.new("TextButton", notifCard)
    notifCloseBtn.Size = UDim2.new(0, 20, 0, 20)
    notifCloseBtn.Position = UDim2.new(1, -28, 0, 8)
    notifCloseBtn.BackgroundColor3 = Palette.BlackAux
    notifCloseBtn.BackgroundTransparency = 0.2
    notifCloseBtn.Text = ""
    notifCloseBtn.ZIndex = 205
    notifCloseBtn.BorderSizePixel = 0
    Instance.new("UICorner", notifCloseBtn).CornerRadius = UDim.new(0, 6)

    local xStroke = Instance.new("UIStroke", notifCloseBtn)
    xStroke.Color = Color3.fromRGB(80, 80, 85)
    xStroke.Thickness = 1
    xStroke.Transparency = 0.5

    local xL1 = Instance.new("Frame", notifCloseBtn)
    xL1.AnchorPoint = Vector2.new(0.5, 0.5)
    xL1.Position = UDim2.new(0.5, 0, 0.5, 0)
    xL1.Size = UDim2.new(0, 8, 0, 1.2)
    xL1.Rotation = 45
    xL1.BackgroundColor3 = Palette.TextSecondary
    xL1.BorderSizePixel = 0
    xL1.ZIndex = 206
    Instance.new("UICorner", xL1).CornerRadius = UDim.new(1,0)
    local xL2 = Instance.new("Frame", notifCloseBtn)
    xL2.AnchorPoint = Vector2.new(0.5, 0.5)
    xL2.Position = UDim2.new(0.5, 0, 0.5, 0)
    xL2.Size = UDim2.new(0, 8, 0, 1.2)
    xL2.Rotation = -45
    xL2.BackgroundColor3 = Palette.TextSecondary
    xL2.BorderSizePixel = 0
    xL2.ZIndex = 206
    Instance.new("UICorner", xL2).CornerRadius = UDim.new(1,0)

    notifCloseBtn.MouseEnter:Connect(function()
        TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Palette.RedDark}):Play()
        TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Palette.White}):Play()
        TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Palette.White}):Play()
    end)
    notifCloseBtn.MouseLeave:Connect(function()
        TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Palette.BlackAux}):Play()
        TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Palette.TextSecondary}):Play()
        TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Palette.TextSecondary}):Play()
    end)

    local progressBg = Instance.new("Frame", notifCard)
    progressBg.Size = UDim2.new(1, -24, 0, 3)
    progressBg.Position = UDim2.new(0, 12, 1, -10)
    progressBg.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
    progressBg.BorderSizePixel = 0
    progressBg.ZIndex = 202
    progressBg.ClipsDescendants = true
    Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)

    local progressBar = Instance.new("Frame", progressBg)
    progressBar.Size = UDim2.new(1, 0, 1, 0)
    progressBar.Position = UDim2.new(0, 0, 0, 0)
    progressBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    progressBar.BorderSizePixel = 0
    progressBar.ZIndex = 203
    Instance.new("UICorner", progressBar).CornerRadius = UDim.new(1, 0)
    local progressGrad = Instance.new("UIGradient", progressBar)
    progressGrad.Rotation = 0
    progressGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Palette.RedDark),
        ColorSequenceKeypoint.new(0.5, Palette.RedMain),
        ColorSequenceKeypoint.new(1, Palette.RedAccent)
    })

    notifHolder.Position = UDim2.new(1, 320, 1, -24)

    local dismissed = false
    local function DismissNotif()
        if dismissed then return end
        dismissed = true
        local slideOut = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        TweenService:Create(notifHolder, slideOut, {Position = UDim2.new(1, 340, 1, -24)}):Play()
        TweenService:Create(notifCard, slideOut, {BackgroundTransparency = 1}):Play()
        TweenService:Create(shadowFrame, slideOut, {BackgroundTransparency = 1}):Play()
        task.delay(0.4, function()
            if notifHolder and notifHolder.Parent then
                notifHolder:Destroy()
            end
        end)
    end

    notifCloseBtn.MouseButton1Click:Connect(function() DismissNotif() end)

    local slideIn = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    TweenService:Create(notifHolder, slideIn, {Position = UDim2.new(1, -20, 1, -24)}):Play()

    local barTween = TweenService:Create(progressBar, TweenInfo.new(NOTIF_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 1, 0)})
    task.delay(0.3, function() barTween:Play() end)

    task.delay(NOTIF_DURATION + 0.3, function() DismissNotif() end)
end

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
                    child.Size = UDim2.new(1, -18, 0, 0)
                    child.BackgroundTransparency = 1
                    local t = child:FindFirstChild("Title")
                    local d = child:FindFirstChild("Description")
                    if t then t.TextTransparency = 1 end
                    if d then d.TextTransparency = 1 end
                    task.delay((itemIndex - 1) * 0.02, function()
                        if not child or not child.Parent then return end
                        TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                            Size = UDim2.new(1, -18, 0, 58), BackgroundTransparency = 0
                        }):Play()
                        if t then TweenService:Create(t, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
                        if d then TweenService:Create(d, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
                    end)
                end
            end
        end
    end
    task.delay(0.05, UpdateCanvasSize)
end

local function selectTab(tabName)
    activeTab = tabName
    local animSpeed = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for name, btn in pairs(tabButtons) do
        local label = btn:FindFirstChild("Label")
        local iconContainer = btn:FindFirstChild("Icon")
        local activeBar = btn:FindFirstChild("ActiveBar")
        if name == tabName then
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Palette.AreaInner, BackgroundTransparency = 0.3}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Palette.White}):Play() end
            if activeBar then
                activeBar.Visible = true
                activeBar.Size = UDim2.new(0, 0, 0, 20)
                TweenService:Create(activeBar, animSpeed, {Size = UDim2.new(0, 2, 0, 20)}):Play()
            end
            if iconContainer and iconContainer:FindFirstChild("AccentImage") then
                TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Palette.White}):Play()
            end
            originalTrans[btn] = { BackgroundTransparency = 0.3, TextTransparency = 0 }
        else
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Palette.BlackAux, BackgroundTransparency = 1}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Palette.TextSecondary}):Play() end
            if activeBar then activeBar.Visible = false end
            if iconContainer and iconContainer:FindFirstChild("AccentImage") then
                TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Palette.TextSecondary}):Play()
            end
            originalTrans[btn] = { BackgroundTransparency = 1, TextTransparency = 0 }
        end
    end
    togglesContainer.CanvasPosition = Vector2.new(0, 0)
    searchTextBox.Text = ""
    filterToggles(tabName, "")
end

local function createTabBtn(tabName)
    local tabBtn = Instance.new("TextButton", TabsContainer)
    tabBtn.Name = tabName .. "TabBtn"
    tabBtn.Size = UDim2.new(1, -16, 0, 36)
    tabBtn.BackgroundColor3 = Palette.BlackAux
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text = ""
    tabBtn.ZIndex = 11
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 8)

    local activeBar = Instance.new("Frame", tabBtn)
    activeBar.Name = "ActiveBar"
    activeBar.Size = UDim2.new(0, 2, 0, 20)
    activeBar.Position = UDim2.new(0, 2, 0.5, -10)
    activeBar.BackgroundColor3 = Palette.RedAccent
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
    imageLabel.ImageColor3 = Palette.TextSecondary
    
    if tabName == "Player" then imageLabel.Image = "rbxthumb://type=Asset&id=107032293182891&w=150&h=150"
    elseif tabName == "Teleports" then imageLabel.Image = "rbxthumb://type=Asset&id=131082536388353&w=150&h=150"
    elseif tabName == "Settings" then imageLabel.Image = "rbxthumb://type=Asset&id=88409765080516&w=150&h=150"
    elseif tabName == "Visuals" then imageLabel.Image = "rbxthumb://type=Asset&id=97681798175944&w=150&h=150"
    elseif tabName == "Combat" then imageLabel.Image = "rbxthumb://type=Asset&id=105897102093789&w=150&h=150" end

    local tabLabel = Instance.new("TextLabel", tabBtn)
    tabLabel.Name = "Label"
    tabLabel.Size = UDim2.new(1, -42, 1, 0) 
    tabLabel.Position = UDim2.new(0, 38, 0, 0) 
    tabLabel.BackgroundTransparency = 1
    tabLabel.TextColor3 = Palette.TextSecondary
    tabLabel.Font = Enum.Font.GothamMedium
    tabLabel.TextSize = 13
    tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.Text = UI_TEXT.Tabs[tabName] or tabName
    tabLabel.ZIndex = 12

    tabBtn.MouseEnter:Connect(function()
        if tabButtons[tabName] and activeTab ~= tabName then
            TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.75}):Play()
        end
    end)
    tabBtn.MouseLeave:Connect(function()
        if tabButtons[tabName] and activeTab ~= tabName then
            TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
        end
    end)

    tabBtn.MouseButton1Click:Connect(function() PlayUI_Click(); selectTab(tabName) end)
    tabButtons[tabName] = tabBtn
end

local function createToggle(parent, configKey, tabCategory)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = configKey
    toggleFrame.Size = UDim2.new(1, -18, 0, 58)
    toggleFrame.BackgroundColor3 = Palette.BlackAux
    toggleFrame.BackgroundTransparency = 0.15
    toggleFrame.ZIndex = 11
    toggleFrame.ClipsDescendants = true 
    toggleFrame:SetAttribute("Tab", tabCategory)
    toggleFrame:SetAttribute("ConfigKey", configKey)
    toggleFrame.Parent = parent
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 9)
    local stroke = Instance.new("UIStroke", toggleFrame)
    stroke.Color = Color3.fromRGB(45, 45, 48)
    stroke.Transparency = 0.4
    stroke.Thickness = 1
    
    local optData = UI_TEXT.Options[configKey]
    local titleLabel = Instance.new("TextLabel", toggleFrame)
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(0.7, 0, 0, 16)
    titleLabel.Position = UDim2.new(0, 14, 0, 9)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Palette.White
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13.5
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = optData and optData.Title or configKey
    titleLabel.ZIndex = 11
    
    local descLabel = Instance.new("TextLabel", toggleFrame)
    descLabel.Name = "Description"
    descLabel.Size = UDim2.new(0.7, 0, 0, 28)
    descLabel.Position = UDim2.new(0, 14, 0, 27)
    descLabel.BackgroundTransparency = 1
    descLabel.TextColor3 = Palette.TextSecondary
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 10.5
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.TextWrapped = true
    descLabel.Text = optData and optData.Desc or ""
    descLabel.ZIndex = 11
    
    local switchTrack = Instance.new("Frame", toggleFrame)
    switchTrack.Size = UDim2.new(0, 45, 0, 22)
    switchTrack.Position = UDim2.new(1, -59, 0.5, -11)
    switchTrack.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#700008") or Color3.fromRGB(32, 32, 36)
    switchTrack.ZIndex = 11
    Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)
    
    local switchCircle = Instance.new("Frame", switchTrack)
    switchCircle.Size = UDim2.new(0, 16, 0, 16)
    switchCircle.Position = Configs[configKey] and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    switchCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    switchCircle.ZIndex = 12
    Instance.new("UICorner", switchCircle).CornerRadius = UDim.new(1, 0)
    
    local triggerBtn = Instance.new("TextButton", toggleFrame)
    triggerBtn.Size = UDim2.new(1, 0, 1, 0)
    triggerBtn.BackgroundTransparency = 1
    triggerBtn.Text = ""
    triggerBtn.ZIndex = 13
    
    triggerBtn.MouseButton1Click:Connect(function()
        PlayUI_Click()
        Configs[configKey] = not Configs[configKey]
        local targetPos   = Configs[configKey] and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local targetColor = Configs[configKey] and Color3.fromHex("#700008") or Color3.fromRGB(32, 32, 36)
        local anim = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(switchCircle, anim, {Position = targetPos}):Play()
        TweenService:Create(switchTrack, anim, {BackgroundColor3 = targetColor}):Play()
        -- pequeno efeito de escala no clique
        local scalePunch = Instance.new("UIScale", switchTrack)
        scalePunch.Scale = 0.92
        TweenService:Create(scalePunch, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        task.delay(0.25, function() if scalePunch then scalePunch:Destroy() end end)
    end)

    toggleFrame.MouseEnter:Connect(function()
        TweenService:Create(toggleFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 0}):Play()
    end)
    toggleFrame.MouseLeave:Connect(function()
        TweenService:Create(toggleFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.15}):Play()
    end)
end

-- Funcionalidade da barra de busca sem precisar clicar pra expandir
searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
    filterToggles(activeTab, searchTextBox.Text)
end)

ExpandBtn.MouseButton1Click:Connect(function()
    PlayUI_Click()
    isExpanded = not isExpanded
    local newSize = isExpanded and GetSafeUISize(800, 480) or GetSafeUISize(640, 360)
    TweenService:Create(mainWrapper, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = newSize}):Play()
end)

if Camera then
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if UIState == "OPEN" then
            local targetSize = isExpanded and GetSafeUISize(800, 480) or GetSafeUISize(640, 360)
            TweenService:Create(mainWrapper, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize}):Play()
        end
    end)
end

SetUIState = function(newState)
    if UIState == newState or UIState == "OPENING" or UIState == "CLOSING" then return end
    
    UIState = (newState == "OPEN" and "OPENING") or (newState == "MINIMIZED" and "CLOSING") or (newState == "CLOSED" and "CLOSING") or newState
    local tempoAnim = 0.25
    local windowAnim = TweenInfo.new(tempoAnim, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    if newState == "OPEN" then
        mainWrapper.Visible = true
        local shrinkSize = isExpanded and GetSafeUISize(560, 320) or GetSafeUISize(480, 260)
        mainWrapper.Size = shrinkSize
        AplicarFadeSincronizado(mainWrapper, true, 0)
        AplicarFadeSincronizado(mainWrapper, false, tempoAnim)
        
        local targetSize = isExpanded and GetSafeUISize(800, 480) or GetSafeUISize(640, 360)
        local openTween = TweenService:Create(mainWrapper, windowAnim, {Size = targetSize})
        openTween:Play()
        openTween.Completed:Connect(function()
            UIState = "OPEN"
            filterToggles(activeTab, searchTextBox.Text)
        end)

    elseif newState == "MINIMIZED" or newState == "CLOSED" then
        AplicarFadeSincronizado(mainWrapper, true, tempoAnim)
        local shrinkSize = isExpanded and GetSafeUISize(560, 320) or GetSafeUISize(480, 260)
        local closeTween = TweenService:Create(mainWrapper, windowAnim, {Size = shrinkSize})
        closeTween:Play()
        
        closeTween.Completed:Connect(function()
            mainWrapper.Visible = false
            UIState = newState
        end)
    end
end

MinimizeBtn.MouseButton1Click:Connect(function() 
    PlayUI_Click()
    TweenService:Create(MinimizeBtn, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = Palette.BlackAux, BackgroundTransparency = 0.3}):Play()
    TweenService:Create(MinimizeLine, TweenInfo.new(0.15), {BackgroundColor3 = Palette.TextSecondary}):Play()
    SetUIState("MINIMIZED")
end)

-- ==================== CONFIRM DIALOG LOGIC (REDESIGNED & SYNCED) ====================
local function AlternarConfirmacao(exibir)
    isConfirmOpen = exibir
    local tempoAnim = 0.22

    if exibir then
        confirmOverlay.Visible = true
        
        confirmCard.Size = UDim2.new(0, 280, 0, 115)
        local cardScale = Instance.new("UIScale", confirmCard)
        cardScale.Scale = 0.88
        TweenService:Create(cardScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        
        -- Aproveitando nossa função para fazer o FadeIn perfeito junto de tudo que tem dentro
        AplicarFadeSincronizado(confirmCard, false, tempoAnim)
    else
        -- FadeOut sincronizado
        AplicarFadeSincronizado(confirmCard, true, tempoAnim)
        
        local sc = confirmCard:FindFirstChildOfClass("UIScale")
        if sc then
            TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.88}):Play()
        end
        task.delay(tempoAnim + 0.05, function()
            if not isConfirmOpen then
                confirmOverlay.Visible = false
                local sc2 = confirmCard:FindFirstChildOfClass("UIScale")
                if sc2 then sc2:Destroy() end
            end
        end)
    end
end

CloseBtn.MouseButton1Click:Connect(function() 
    PlayUI_Click()
    AlternarConfirmacao(true) 
end)

btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)

btnYes.MouseButton1Click:Connect(function()
    local syncTime = 0.2
    AplicarFadeSincronizado(mainWrapper, true, syncTime)
    TweenService:Create(FloatBtn, TweenInfo.new(syncTime, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)}):Play()
    task.wait(syncTime)
    screenGui:Destroy()
end)

local function AplicarEfeitoFisicoBotao(btn, hoverColor)
    btn.MouseEnter:Connect(function()
        if UIState ~= "OPEN" then return end 
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = Color3.fromRGB(28, 28, 30), BackgroundTransparency = 0.1}):Play()
        if btn.Name == "ExpandBtn" then TweenService:Create(ExpandStroke, TweenInfo.new(0.15), {Color = hoverColor}):Play()
        elseif btn.Name == "MinimizeBtn" then TweenService:Create(MinimizeLine, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
        elseif btn.Name == "CloseBtn" then TweenService:Create(CloseLine1, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play(); TweenService:Create(CloseLine2, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play() end
        if btn.Name == "CloseBtn" then TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Palette.RedDark}):Play() end
    end)
    btn.MouseLeave:Connect(function()
        if UIState ~= "OPEN" then return end 
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = Palette.BlackAux, BackgroundTransparency = 0.3}):Play()
        if btn.Name == "ExpandBtn" then TweenService:Create(ExpandStroke, TweenInfo.new(0.15), {Color = Palette.TextSecondary}):Play()
        elseif btn.Name == "MinimizeBtn" then TweenService:Create(MinimizeLine, TweenInfo.new(0.15), {BackgroundColor3 = Palette.TextSecondary}):Play()
        elseif btn.Name == "CloseBtn" then TweenService:Create(CloseLine1, TweenInfo.new(0.15), {BackgroundColor3 = Palette.TextSecondary}):Play(); TweenService:Create(CloseLine2, TweenInfo.new(0.15), {BackgroundColor3 = Palette.TextSecondary}):Play() end
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 24, 0, 24)}):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Back), {Size = UDim2.new(0, 26, 0, 26)}):Play()
    end)
end

AplicarEfeitoFisicoBotao(MinimizeBtn, Palette.White)
AplicarEfeitoFisicoBotao(ExpandBtn, Palette.White)
AplicarEfeitoFisicoBotao(CloseBtn, Palette.RedBright)

createTabBtn("Player")
createTabBtn("Combat")
createTabBtn("Visuals")
createTabBtn("Teleports")
createTabBtn("Settings")

createToggle(togglesContainer, "Speed",       "Player")
createToggle(togglesContainer, "AntiFling",   "Player")
createToggle(togglesContainer, "AutoShoot",   "Combat")
createToggle(togglesContainer, "Reach",       "Combat")
createToggle(togglesContainer, "ESP",         "Visuals")
createToggle(togglesContainer, "TpToGun",     "Teleports")
createToggle(togglesContainer, "SafeSpot",    "Teleports")
createToggle(togglesContainer, "AutoCollect", "Settings")
createToggle(togglesContainer, "ChatRoles",   "Settings")

-- ==================== ANIMAÇÃO DE INTRODUÇÃO ====================
local function ExecutarIntroAkat()
    local Blur = Instance.new("BlurEffect"); Blur.Size = 0; Blur.Parent = Lighting
    local IntroFrame = Instance.new("Frame", screenGui); IntroFrame.Size = UDim2.new(1, 0, 1, 0); IntroFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0); IntroFrame.BackgroundTransparency = 1; IntroFrame.ZIndex = 500
    local MaskContainer = Instance.new("Frame", IntroFrame); MaskContainer.AnchorPoint = Vector2.new(0.5, 0.5); MaskContainer.Position = UDim2.new(0.5, 0, 0.5, -10); MaskContainer.Size = UDim2.new(0, 420, 0, 40); MaskContainer.BackgroundTransparency = 1; MaskContainer.ClipsDescendants = true; MaskContainer.ZIndex = 501
    local IntroText = Instance.new("TextLabel", MaskContainer); IntroText.Size = UDim2.new(1, 0, 1, 0); IntroText.Position = UDim2.new(0, 0, 1, 0); IntroText.BackgroundTransparency = 1; IntroText.Font = Enum.Font.GothamBold; IntroText.TextSize = 26; IntroText.RichText = true; IntroText.Text = UI_TEXT.Intro; IntroText.ZIndex = 502
    local IntroLine = Instance.new("Frame", IntroFrame); IntroLine.AnchorPoint = Vector2.new(0.5, 0.5); IntroLine.Position = UDim2.new(0.5, 0, 0.5, 16); IntroLine.Size = UDim2.new(0, 0, 0, 2); IntroLine.BackgroundColor3 = Palette.RedMain; IntroLine.BorderSizePixel = 0; IntroLine.BackgroundTransparency = 1; IntroLine.ZIndex = 503; Instance.new("UICorner", IntroLine).CornerRadius = UDim.new(1, 0)

    TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.05}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 24}):Play(); task.wait(0.1)
    TweenService:Create(IntroText, TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play(); task.wait(0.2)
    TweenService:Create(IntroLine, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(0, 260, 0, 2)}):Play(); task.wait(1.6) 
    TweenService:Create(IntroText, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
    TweenService:Create(IntroLine, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play(); task.wait(0.3)
    TweenService:Create(IntroFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play(); task.wait(0.3)

    RegistrarTransparencias(mainWrapper)
    for _, item in ipairs(mainWrapper:GetDescendants()) do RegistrarTransparencias(item) end

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
        MainScale:Destroy()
        IntroFrame:Destroy()
        Blur:Destroy()
        task.delay(0.4, function()
            CriarNotificacao(
                "AKATSUKI SCRIPTS",
                "MM2 Script carregado com sucesso! Bem-vindo, " .. player.DisplayName .. "."
            )
        end)
    end)
end

ExecutarIntroAkat()
