-- [[
--     AKATSUKI SCRIPTS HUB — UNIFIED BUILD [v6.0]
--     UI + BACKEND BLOX FRUITS | Delta Mobile & PC (2026)
--     Um único arquivo — sem dependências externas
-- ]]

-- ==================== SERVIÇOS ====================
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local ContentProvider   = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- ==================== SHUTDOWN DO CICLO ANTERIOR ====================
if _G.AkatBFLogicRunning and _G.AkatCallbacks and type(_G.AkatCallbacks.ShutdownAll) == "function" then
    pcall(_G.AkatCallbacks.ShutdownAll)
end
if _G.AkatUIShutdown then
    pcall(_G.AkatUIShutdown)
end

-- ==================== FLAGS GLOBAIS ====================
local scriptAlive = true
_G.AkatBFLogicRunning = true

-- ==================== CONFIGURAÇÕES UNIFICADAS ====================
local Configs = {
    -- Farm
    AutoFarm        = false,
    FightingStyle   = "Current",
    FarmPosition    = "Above NPC",
    FarmHeightValue = 15,

    -- Mastery
    AutoMastery     = false,
    MasteryType     = "Fighting Style",
    TargetMastery   = 300,

    -- Boss
    AutoBoss        = false,
    BossSelection   = "Available Boss",
    BossName        = "Any",
    BossQuest       = false,




    -- Stats
    AutoStats       = false,
    PrimaryStat     = "Blox Fruit",
    SecondaryStat   = "Defense",
    TertiaryStat    = "Melee",


    Debug           = false,
}
_G.Configs = Configs

-- ==================== TEXTOS DA UI ====================
local UI_TEXT = {
    SearchPlaceholder = "Pesquisar...",
    ConfirmCloseTitle = "Deseja fechar o script?",
    ConfirmBtn        = "Sim",
    CancelBtn         = "Não",
    Intro             = '<font color="#FFFFFF">Scripts by | </font><font color="#8B0000">AKATSUKI</font>',
    Tabs = {
        Farm     = "Farm",
        Mastery  = "Mastery",
        Boss     = "Boss",
        Stats    = "Stats",
        Status   = "Status",
    },
    Options = {
        AutoFarm        = {Title="Auto Farm",       Desc="Farm Manager central: coordena Quest, alvo, combate e progressão."},
        FightingStyle   = {Title="Fighting Style",  Desc="Estilo de combate utilizado. 'Current' mantém o equipado."},
        FarmPosition    = {Title="Farm Position",   Desc="Posição relativa ao NPC: Above, Behind, Front ou Near."},
        FarmHeight      = {Title="Farm Height",     Desc="Distância vertical usada quando a posição é Above NPC."},
        AutoMastery     = {Title="Auto Mastery",    Desc="Farma até atingir a Mastery configurada."},
        MasteryType     = {Title="Mastery Type",    Desc="Fighting Style, Sword, Gun ou Blox Fruit."},
        TargetMastery   = {Title="Target Mastery",  Desc="Valor de Mastery no qual a tarefa termina."},
        AutoBoss        = {Title="Auto Boss",       Desc="Seleciona e enfrenta o Boss configurado."},
        BossSelection   = {Title="Boss Mode",       Desc="Boss selecionado, qualquer Boss disponível ou rotação."},
        BossName        = {Title="Boss",            Desc="Nome do Boss quando o modo Selected Boss for usado."},
        BossQuest       = {Title="Boss Quest",      Desc="Prioriza a Quest do Boss quando disponível."},
        AutoStats       = {Title="Auto Stats",      Desc="Distribui pontos conforme as três prioridades."},
        PrimaryStat     = {Title="Primary",         Desc="Primeira prioridade de distribuição."},
        SecondaryStat   = {Title="Secondary",       Desc="Segunda prioridade de distribuição."},
        TertiaryStat    = {Title="Tertiary",        Desc="Terceira prioridade de distribuição."},
        CurrentTask     = {Title="Current Task",    Desc="Tarefa atual do Farm Manager."},
        CurrentTarget   = {Title="Current Target",  Desc="NPC ou objetivo atual."},
        CurrentQuest    = {Title="Current Quest",   Desc="Quest atual."},
        CurrentArea     = {Title="Current Area",    Desc="Área detectada."},
        Level           = {Title="Level",           Desc="Level detectado."},
        Progress        = {Title="Progress",        Desc="Progresso da tarefa atual."},
        State           = {Title="State",           Desc="Estado da máquina de estados."},
    },
}

-- ==================== ESTADO DA UI ====================
local UIState       = "CLOSED"
local activeTab     = "Farm"
local tabButtons    = {}
local isExpanded    = false
local originalTrans = {}
local isConfirmOpen = false

-- ==================== DIMENSIONAMENTO RESPONSIVO ====================
local NORMAL_UI_SIZE   = Vector2.new(565, 385)
local EXPANDED_UI_SIZE = Vector2.new(905, 405)
local UI_SAFE_MARGIN   = 14

local FLOATING_BUTTON_SIZE = Vector2.new(150, 48)
local FLOATING_GAP         = 18

local function GetViewportSize()
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function GetResponsiveUISizes()
    local vp   = GetViewportSize()
    local maxW = math.max(1, vp.X - UI_SAFE_MARGIN * 2)
    local maxH = math.max(1, vp.Y - UI_SAFE_MARGIN * 2)
    return UDim2.fromOffset(math.min(NORMAL_UI_SIZE.X, maxW),   math.min(NORMAL_UI_SIZE.Y, maxH)),
           UDim2.fromOffset(math.min(EXPANDED_UI_SIZE.X, maxW), math.min(EXPANDED_UI_SIZE.Y, maxH))
end

local function ClampMainWrapperToViewport(wrapper)
    if not wrapper or not wrapper.Parent then return end
    local vp   = GetViewportSize()
    local size = wrapper.AbsoluteSize
    local halfW = math.max(0, size.X / 2)
    local halfH = math.max(0, size.Y / 2)
    local pos  = wrapper.AbsolutePosition + size / 2
    local x    = math.clamp(pos.X, halfW + UI_SAFE_MARGIN, vp.X - halfW - UI_SAFE_MARGIN)
    local y    = math.clamp(pos.Y, halfH + UI_SAFE_MARGIN, vp.Y - halfH - UI_SAFE_MARGIN)
    wrapper.Position = UDim2.fromOffset(x, y)
end

local function ClampFloatingToSafeArea(position)
    local vp   = GetViewportSize()
    local halfW = FLOATING_BUTTON_SIZE.X * 0.5
    local halfH = FLOATING_BUTTON_SIZE.Y * 0.5
    local x = math.clamp(position.X, halfW + UI_SAFE_MARGIN, vp.X - halfW - UI_SAFE_MARGIN)
    local y = math.clamp(position.Y, halfH + UI_SAFE_MARGIN, vp.Y - halfH - UI_SAFE_MARGIN)
    -- Zona reservada para thumbstick mobile (canto inferior esquerdo)
    if x < 230 and y > vp.Y - 220 then
        x = 230
        y = math.min(y, vp.Y - 230)
    end
    return Vector2.new(x, y)
end

-- ==================== SCREENGUI ====================
local screenGui          = Instance.new("ScreenGui")
screenGui.Name           = "AkatUnifiedUI"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then
    uiParent = gethui()
else
    pcall(function() uiParent = game:GetService("CoreGui") end)
end

if uiParent:FindFirstChild("AkatUnifiedUI") then
    pcall(function() uiParent.AkatUnifiedUI:Destroy() end)
end

for _, bf in ipairs(Lighting:GetChildren()) do
    if bf:IsA("BlurEffect") and (bf.Name == "ConfirmBlur" or bf.Name == "IntroBlur") then
        pcall(function() bf:Destroy() end)
    end
end

screenGui.Parent = uiParent

-- ==================== SOM ====================
local SharedClickSound      = Instance.new("Sound", screenGui)
SharedClickSound.SoundId    = "rbxassetid://6895079853"
SharedClickSound.Volume     = 0.6
SharedClickSound.Looped     = false

local function PlayUI_Click()
    pcall(function()
        SharedClickSound.TimePosition = 0
        SharedClickSound:Play()
    end)
end

-- ==================== FADE SINCRONIZADO ====================
local function RegistrarTransparencias(obj)
    if originalTrans[obj] then return end
    if obj:IsA("Frame") or obj:IsA("ScrollingFrame") or obj:IsA("CanvasGroup") then
        originalTrans[obj] = {BackgroundTransparency = obj.BackgroundTransparency}
    elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        originalTrans[obj] = {TextTransparency = obj.TextTransparency, BackgroundTransparency = obj.BackgroundTransparency, TextStrokeTransparency = obj.TextStrokeTransparency or 1}
    elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        originalTrans[obj] = {ImageTransparency = obj.ImageTransparency, BackgroundTransparency = obj.BackgroundTransparency}
    elseif obj:IsA("UIStroke") then
        originalTrans[obj] = {Transparency = obj.Transparency}
    end
end

local function AplicarFadeSincronizado(raiz, fadeOut, duracao)
    if not raiz or not raiz.Parent then return end
    local info = TweenInfo.new(duracao, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local function tratar(obj)
        if not obj or not obj.Parent then return end
        RegistrarTransparencias(obj)
        local orig = originalTrans[obj]
        if not orig then return end
        local function aplicar(prop, target)
            if obj[prop] == nil then return end
            if duracao == 0 then obj[prop] = target
            else TweenService:Create(obj, info, {[prop] = target}):Play() end
        end
        if orig.BackgroundTransparency ~= nil then aplicar("BackgroundTransparency", fadeOut and 1 or orig.BackgroundTransparency) end
        if orig.TextTransparency       ~= nil then aplicar("TextTransparency",       fadeOut and 1 or orig.TextTransparency) end
        if orig.ImageTransparency      ~= nil then aplicar("ImageTransparency",      fadeOut and 1 or orig.ImageTransparency) end
        if orig.Transparency           ~= nil then aplicar("Transparency",           fadeOut and 1 or orig.Transparency) end
    end
    tratar(raiz)
    for _, desc in ipairs(raiz:GetDescendants()) do tratar(desc) end
end

-- ==================== BOTÃO FLUTUANTE ====================
local FloatBtn            = Instance.new("ImageButton", screenGui)
FloatBtn.Name             = "FloatBtn"
FloatBtn.AnchorPoint      = Vector2.new(0.5, 0.5)
FloatBtn.Size             = UDim2.new(0, 44, 0, 44)
FloatBtn.Position         = UDim2.new(0.06, 0, 0.2, 0)
FloatBtn.Image            = "rbxthumb://type=Asset&id=139044062702391&w=150&h=150"
FloatBtn.BackgroundColor3 = Color3.fromRGB(15, 0, 0)
FloatBtn.Visible          = false
FloatBtn.ZIndex           = 100
FloatBtn.AutoButtonColor  = false
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)

local FloatOpenSound      = Instance.new("Sound", FloatBtn)
FloatOpenSound.SoundId    = "rbxassetid://6310837681"
FloatOpenSound.Volume     = 0.2

task.spawn(function()
    pcall(function() ContentProvider:PreloadAsync({FloatOpenSound, SharedClickSound}) end)
end)

-- ==================== JANELA PRINCIPAL ====================
local mainWrapper         = Instance.new("Frame", screenGui)
mainWrapper.Name          = "MainWrapper"
mainWrapper.AnchorPoint   = Vector2.new(0.5, 0.5)
mainWrapper.Size          = UDim2.new(0, 640, 0, 360)
mainWrapper.Position      = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible       = false
mainWrapper.ClipsDescendants = false
mainWrapper.ZIndex        = 1

local mainFrame           = Instance.new("Frame", mainWrapper)
mainFrame.Name            = "MainFrame"
mainFrame.Size            = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.ZIndex          = 2
mainFrame.ClipsDescendants = false

-- ==================== DRAG: JANELA PRINCIPAL ====================
local dragUIToggle, dragUIInput, dragUIStart, startUIPos = false, nil, nil, nil

mainFrame.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not dragUIToggle then
        dragUIToggle = true
        dragUIInput  = input
        dragUIStart  = input.Position
        startUIPos   = mainWrapper.Position
    end
end)

-- ==================== DRAG: BOTÃO FLUTUANTE ====================
local dragToggleF, dragInputF, dragStartF, startPosF, isDraggingF = false, nil, nil, nil, false

FloatBtn.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not dragToggleF then
        dragToggleF = true
        dragInputF  = input
        isDraggingF = false
        dragStartF  = input.Position
        startPosF   = FloatBtn.Position
    end
end)

-- ==================== FLOATING ACTION BUTTONS ====================
local floatingButtons        = {}
local floatingDragState      = nil
local floatingActionDebounce = {}
local FLOATING_ACTION_DEBOUNCE = 0.45

local function GetFloatingInitialPosition(side)
    local vp       = GetViewportSize()
    local mainPos  = mainWrapper.AbsolutePosition
    local mainSize = mainWrapper.AbsoluteSize
    if mainSize.X <= 0 or mainSize.Y <= 0 then
        mainPos  = Vector2.new(vp.X * 0.5 - 320, vp.Y * 0.5 - 180)
        mainSize = Vector2.new(640, 360)
    end
    local halfW   = FLOATING_BUTTON_SIZE.X * 0.5
    local centerY = mainPos.Y + mainSize.Y * 0.5
    local centerX = (side == "right") and (mainPos.X + mainSize.X + FLOATING_GAP + halfW) or (mainPos.X - FLOATING_GAP - halfW)
    local safe    = ClampFloatingToSafeArea(Vector2.new(centerX, centerY))
    return UDim2.fromOffset(safe.X, safe.Y)
end

local function SetupFloatingDrag(inputObj, root)
    inputObj.Active = true
    inputObj.InputBegan:Connect(function(input)
        if (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) or floatingDragState then return end
        floatingDragState = {root=root, input=input, inputType=input.UserInputType, startInputPosition=input.Position, startButtonPosition=root.Position, dragging=false}
    end)
end

local function CreateFloatingButton(buttonKey, text, side, callback)
    local existing = floatingButtons[buttonKey]
    if existing and existing.root and existing.root.Parent then
        if existing.destroyTween then pcall(function() existing.destroyTween:Cancel() end) existing.destroyTween = nil end
        existing.destroying = false
        existing.callback   = callback
        existing.root.Visible = true
        TweenService:Create(existing.root, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency=0}):Play()
        if existing.scale then TweenService:Create(existing.scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale=1}):Play() end
        return existing.root
    end
    floatingButtons[buttonKey] = nil

    local root    = Instance.new("CanvasGroup", screenGui)
    root.Name     = buttonKey .. "Button"
    root:SetAttribute("FloatingButtonKey", buttonKey)
    root.AnchorPoint        = Vector2.new(0.5, 0.5)
    root.Size               = UDim2.fromOffset(FLOATING_BUTTON_SIZE.X, FLOATING_BUTTON_SIZE.Y)
    root.Position           = GetFloatingInitialPosition(side)
    root.BackgroundTransparency = 1
    root.GroupTransparency  = 1
    root.ZIndex             = 80
    root.ClipsDescendants   = true
    Instance.new("UICorner", root).CornerRadius = UDim.new(0, 14)

    local button  = Instance.new("TextButton", root)
    button.Size   = UDim2.fromScale(1, 1)
    button.BackgroundColor3 = Color3.fromRGB(18, 2, 4)
    button.BackgroundTransparency = 0.42
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text  = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize   = 17
    button.Font       = Enum.Font.GothamBold
    button.ZIndex     = 81
    button.ClipsDescendants = true
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 14)

    local gradient = Instance.new("UIGradient", button)
    gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255,55,65)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(145,0,12)), ColorSequenceKeypoint.new(1, Color3.fromRGB(70,0,7))})
    gradient.Rotation = 45

    local scale   = Instance.new("UIScale", root)
    scale.Scale   = 0.88

    floatingButtons[buttonKey] = {root=root, gradient=gradient, callback=callback, scale=scale, destroying=false, destroyTween=nil}
    SetupFloatingDrag(button, root)

    task.spawn(function()
        local rotation = 45
        while root.Parent and floatingButtons[buttonKey] and floatingButtons[buttonKey].root == root do
            rotation = (rotation + 1.5) % 360
            if gradient.Parent then gradient.Rotation = rotation end
            task.wait(0.03)
        end
    end)

    TweenService:Create(root,  TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency=0}):Play()
    TweenService:Create(scale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale=1}):Play()
    return root
end

local function DestroyFloatingButton(buttonKey)
    local data = floatingButtons[buttonKey]
    if not data or data.destroying then return end
    local root = data.root
    if not root or not root.Parent then floatingButtons[buttonKey] = nil; return end
    data.destroying = true
    floatingActionDebounce[buttonKey] = nil
    if floatingDragState and floatingDragState.root == root then floatingDragState = nil end

    local scale = data.scale
    local fade  = TweenService:Create(root,  TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency=1})
    local shrink = scale and TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale=0.88})
    data.destroyTween = fade
    fade:Play()
    if shrink then shrink:Play() end
    fade.Completed:Connect(function()
        if floatingButtons[buttonKey] ~= data then return end
        floatingButtons[buttonKey] = nil
        if root and root.Parent then root:Destroy() end
    end)
end

-- ==================== INPUT UNIFICADO (MOVED / ENDED) ====================
local SetUIState -- forward declaration

UserInputService.InputChanged:Connect(function(input)
    -- Drag janela principal
    if dragUIToggle and dragUIInput then
        local validUI = (dragUIInput.UserInputType == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch)
            or (dragUIInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
        if validUI then
            local delta = input.Position - dragUIStart
            local vp  = GetViewportSize()
            local hw  = mainWrapper.AbsoluteSize.X / 2
            local hh  = mainWrapper.AbsoluteSize.Y / 2
            local baseX = startUIPos.X.Offset + vp.X * startUIPos.X.Scale
            local baseY = startUIPos.Y.Offset + vp.Y * startUIPos.Y.Scale
            mainWrapper.Position = UDim2.fromOffset(
                math.clamp(baseX + delta.X, hw, vp.X - hw),
                math.clamp(baseY + delta.Y, hh, vp.Y - hh)
            )
        end
    end

    -- Drag botão flutuante
    if dragToggleF and dragInputF then
        local validF = (dragInputF.UserInputType == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch)
            or (dragInputF.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
        if validF then
            local delta = input.Position - dragStartF
            if delta.Magnitude > 5 then isDraggingF = true end
            local vp = GetViewportSize()
            local baseAbsX = vp.X * startPosF.X.Scale + startPosF.X.Offset
            local baseAbsY = vp.Y * startPosF.Y.Scale + startPosF.Y.Offset
            FloatBtn.Position = UDim2.fromOffset(
                math.clamp(baseAbsX + delta.X, 22, vp.X - 22),
                math.clamp(baseAbsY + delta.Y, 22, vp.Y - 22)
            )
        end
    end

    -- Drag floating action buttons
    local state = floatingDragState
    if state and state.root and state.root.Parent then
        local shouldMove = (state.inputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
            or (state.inputType == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch)
        if shouldMove then
            local delta = input.Position - state.startInputPosition
            if delta.Magnitude > 5 then state.dragging = true end
            local vp  = GetViewportSize()
            local sx  = state.startButtonPosition.X.Offset + vp.X * state.startButtonPosition.X.Scale
            local sy  = state.startButtonPosition.Y.Offset + vp.Y * state.startButtonPosition.Y.Scale
            local safe = ClampFloatingToSafeArea(Vector2.new(sx + delta.X, sy + delta.Y))
            if state.root.Parent then state.root.Position = UDim2.fromOffset(safe.X, safe.Y) end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    -- Botão flutuante principal
    if input == dragInputF then
        if dragToggleF and not isDraggingF then
            if UIState == "MINIMIZED" or UIState == "CLOSED" then
                pcall(function() FloatOpenSound.TimePosition = 0; FloatOpenSound:Play() end)
                SetUIState("OPEN")
            elseif UIState == "OPEN" then
                SetUIState("MINIMIZED")
            end
        end
        dragToggleF = false; dragInputF = nil
    end

    -- Drag janela
    if input == dragUIInput then dragUIToggle = false; dragUIInput = nil end

    -- Floating action buttons
    local state = floatingDragState
    if state and input == state.input then
        local root       = state.root
        local wasDragging = state.dragging
        local buttonKey  = root and root:GetAttribute("FloatingButtonKey")
        floatingDragState = nil
        if not wasDragging and root and root.Parent then
            local action = floatingButtons[buttonKey]
            local now    = os.clock()
            local last   = floatingActionDebounce[buttonKey] or 0
            if action and action.callback and (now - last) >= FLOATING_ACTION_DEBOUNCE then
                floatingActionDebounce[buttonKey] = now
                task.spawn(action.callback)
            end
        end
    end
end)

-- ==================== ESTRUTURA DA JANELA ====================
local Shadow              = Instance.new("ImageLabel", mainFrame)
Shadow.Name               = "WindowShadow"
Shadow.AnchorPoint        = Vector2.new(0, 0)
Shadow.Position           = UDim2.new(0, -12, 0, -12)
Shadow.Size               = UDim2.new(1, 24, 1, 24)
Shadow.BackgroundTransparency = 1
Shadow.Image              = "rbxassetid://5554831957"
Shadow.ImageColor3        = Color3.fromRGB(5, 0, 1)
Shadow.ImageTransparency  = 0.40
Shadow.ScaleType          = Enum.ScaleType.Slice
Shadow.SliceCenter        = Rect.new(36, 36, 114, 114)
Shadow.ZIndex             = 3

local MainBackground      = Instance.new("Frame", mainFrame)
MainBackground.Name       = "MainBackground"
MainBackground.Size       = UDim2.new(1, 0, 1, 0)
MainBackground.BackgroundColor3 = Color3.fromRGB(15, 0, 3)
MainBackground.BorderSizePixel  = 0
MainBackground.ClipsDescendants = true
MainBackground.ZIndex     = 4
Instance.new("UICorner", MainBackground).CornerRadius = UDim.new(0, 10)

local MainStroke          = Instance.new("UIStroke", MainBackground)
MainStroke.Thickness      = 2
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
Instance.new("UIGradient", MainStroke).Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(50,0,5)), ColorSequenceKeypoint.new(1, Color3.fromRGB(180,20,30))})
local MainStrokeGrad = MainStroke:FindFirstChildOfClass("UIGradient")
MainStrokeGrad.Rotation = 45

local RedGradientOverlay  = Instance.new("Frame", MainBackground)
RedGradientOverlay.Size   = UDim2.new(1, 0, 1, 0)
RedGradientOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
RedGradientOverlay.BackgroundTransparency = 0
RedGradientOverlay.BorderSizePixel = 0
RedGradientOverlay.ZIndex = 4
Instance.new("UICorner", RedGradientOverlay).CornerRadius = UDim.new(0, 10)
local SingleRedGrad       = Instance.new("UIGradient", RedGradientOverlay)
SingleRedGrad.Rotation    = 90
SingleRedGrad.Color       = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(40,0,5)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120,15,22)), ColorSequenceKeypoint.new(1, Color3.fromRGB(40,0,5))})

local LeftPanel           = Instance.new("Frame", MainBackground)
LeftPanel.Name            = "LeftPanel"
LeftPanel.Size            = UDim2.new(0, 220, 1, 0)
LeftPanel.Position        = UDim2.new(0, 0, 0, 0)
LeftPanel.BackgroundTransparency = 1
LeftPanel.ZIndex          = 5

local RightPanel          = Instance.new("Frame", MainBackground)
RightPanel.Name           = "RightPanel"
RightPanel.Size           = UDim2.new(1, -220, 1, 0)
RightPanel.Position       = UDim2.new(0, 220, 0, 0)
RightPanel.BackgroundTransparency = 1
RightPanel.ZIndex         = 5

-- ==================== HEADER ESQUERDO ====================
local HeaderLeft          = Instance.new("Frame", LeftPanel)
HeaderLeft.Size           = UDim2.new(1, 0, 0, 36)
HeaderLeft.BackgroundTransparency = 1
HeaderLeft.ZIndex         = 20

local HeaderImage         = Instance.new("ImageLabel", HeaderLeft)
HeaderImage.Size          = UDim2.new(0, 24, 0, 24)
HeaderImage.Position      = UDim2.new(0, 10, 0.5, -12)
HeaderImage.BackgroundTransparency = 1
HeaderImage.Image         = "rbxthumb://type=Asset&id=134217291845443&w=150&h=150"
HeaderImage.ZIndex        = 21

local titleLabel          = Instance.new("TextLabel", HeaderLeft)
titleLabel.Size           = UDim2.new(1, -44, 0, 16)
titleLabel.Position       = UDim2.new(0, 40, 0, 4)
titleLabel.BackgroundTransparency = 1
titleLabel.Text           = "AKATSUKI SCRIPTS HUB"
titleLabel.TextColor3     = Color3.fromRGB(245, 245, 245)
titleLabel.TextSize       = 13
titleLabel.Font           = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex         = 21

local subtitleLabel       = Instance.new("TextLabel", HeaderLeft)
subtitleLabel.Size        = UDim2.new(1, -44, 0, 12)
subtitleLabel.Position    = UDim2.new(0, 40, 0, 20)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text        = "BLOX FRUITS FARM | AKATSUKI"
subtitleLabel.TextColor3  = Color3.fromRGB(180, 180, 180)
subtitleLabel.TextTransparency = 0.2
subtitleLabel.TextSize    = 9.5
subtitleLabel.Font        = Enum.Font.Gotham
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.ZIndex      = 21

-- ==================== BARRA DE PESQUISA ====================
local SearchContainer     = Instance.new("Frame", LeftPanel)
SearchContainer.Size      = UDim2.new(1, -16, 0, 36)
SearchContainer.Position  = UDim2.new(0, 8, 0, 44)
SearchContainer.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
SearchContainer.BackgroundTransparency = 0.85
SearchContainer.ZIndex    = 20
Instance.new("UICorner", SearchContainer).CornerRadius = UDim.new(0, 8)
local searchStroke        = Instance.new("UIStroke", SearchContainer)
searchStroke.Color        = Color3.fromRGB(60, 20, 20)
searchStroke.Transparency = 0.75
searchStroke.Thickness    = 1

local searchTextBox       = Instance.new("TextBox", SearchContainer)
searchTextBox.Size        = UDim2.new(1, -16, 1, 0)
searchTextBox.Position    = UDim2.new(0, 12, 0, 0)
searchTextBox.BackgroundTransparency = 1
searchTextBox.PlaceholderText  = UI_TEXT.SearchPlaceholder
searchTextBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
searchTextBox.Text        = ""
searchTextBox.TextColor3  = Color3.fromRGB(230, 230, 230)
searchTextBox.Font        = Enum.Font.GothamMedium
searchTextBox.TextSize    = 13
searchTextBox.TextXAlignment = Enum.TextXAlignment.Left
searchTextBox.ZIndex      = 22
searchTextBox.Active      = true
searchTextBox.ClearTextOnFocus = false

-- ==================== TABS CONTAINER ====================
local TabsContainer       = Instance.new("ScrollingFrame", LeftPanel)
TabsContainer.Name        = "TabsContainer"
TabsContainer.Size        = UDim2.new(1, -8, 1, -152)
TabsContainer.Position    = UDim2.new(0, 4, 0, 87)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ZIndex      = 10
TabsContainer.CanvasSize  = UDim2.new(0, 0, 0, 0)
TabsContainer.ScrollBarThickness = 2
TabsContainer.ScrollBarImageColor3 = Color3.fromRGB(200, 50, 50)
TabsContainer.ScrollBarImageTransparency = 0.45
TabsContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

local TabsLayout          = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder      = Enum.SortOrder.LayoutOrder
TabsLayout.Padding        = UDim.new(0, 2)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function UpdateTabsCanvas()
    TabsContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(TabsLayout.AbsoluteContentSize.Y + 8, TabsContainer.AbsoluteSize.Y + 12))
end
TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabsCanvas)
TabsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTabsCanvas)

-- ==================== ACTIVEBAR ====================
local ActiveBarContainer  = Instance.new("Frame", LeftPanel)
ActiveBarContainer.Size   = UDim2.new(1, -8, 1, -152)
ActiveBarContainer.Position = UDim2.new(0, 4, 0, 87)
ActiveBarContainer.BackgroundTransparency = 1
ActiveBarContainer.ClipsDescendants = true
ActiveBarContainer.ZIndex = 8

local sharedActiveBar     = Instance.new("Frame", ActiveBarContainer)
sharedActiveBar.Name      = "SharedActiveBar"
sharedActiveBar.AnchorPoint = Vector2.new(0, 0.5)
sharedActiveBar.Size      = UDim2.new(0, 3, 0, 22)
sharedActiveBar.Position  = UDim2.new(0, 7, 0, 0)
sharedActiveBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sharedActiveBar.BorderSizePixel = 0
sharedActiveBar.Visible   = false
sharedActiveBar.ZIndex    = 8
Instance.new("UICorner", sharedActiveBar).CornerRadius = UDim.new(1, 0)
local activeBarScale      = Instance.new("UIScale", sharedActiveBar)
activeBarScale.Scale      = 1
local sharedBarGrad       = Instance.new("UIGradient", sharedActiveBar)
sharedBarGrad.Rotation    = 90
sharedBarGrad.Color       = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(120,0,10)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,30,40)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120,0,10))})

-- ==================== USER PROFILE ====================
local UserProfileFrame    = Instance.new("Frame", LeftPanel)
UserProfileFrame.Size     = UDim2.new(1, -16, 0, 55)
UserProfileFrame.Position = UDim2.new(0, 8, 1, -63)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(20, 12, 12)
UserProfileFrame.BackgroundTransparency = 0.35
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex   = 20
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 8)

local userStroke          = Instance.new("UIStroke", UserProfileFrame)
userStroke.Thickness      = 0.9
local uGrad               = Instance.new("UIGradient", userStroke)
uGrad.Color               = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255,10,15)), ColorSequenceKeypoint.new(1, Color3.fromRGB(60,0,0))})

local AvatarImage         = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Size          = UDim2.new(0, 34, 0, 34)
AvatarImage.Position      = UDim2.new(0, 10, 0.5, -17)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image         = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex        = 21
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)
local avGrad              = Instance.new("UIGradient", Instance.new("UIStroke", AvatarImage))
avGrad.Color              = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255,10,15)), ColorSequenceKeypoint.new(1, Color3.fromRGB(60,0,0))})
AvatarImage:FindFirstChildOfClass("UIStroke").Thickness = 0.9

local StatusIndicator     = Instance.new("Frame", AvatarImage)
StatusIndicator.Size      = UDim2.new(0, 9, 0, 9)
StatusIndicator.Position  = UDim2.new(1, -7, 1, -7)
StatusIndicator.BackgroundColor3 = Color3.fromRGB(40, 220, 80)
StatusIndicator.BorderSizePixel  = 0
StatusIndicator.ZIndex    = 22
Instance.new("UICorner", StatusIndicator).CornerRadius = UDim.new(1, 0)
local statusStroke        = Instance.new("UIStroke", StatusIndicator)
statusStroke.Color        = Color3.fromRGB(15, 5, 5)
statusStroke.Thickness    = 1.5

local DisplayNameLabel    = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Size     = UDim2.new(1, -82, 0, 16)
DisplayNameLabel.Position = UDim2.new(0, 54, 0.5, -16)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text     = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
DisplayNameLabel.Font     = Enum.Font.GothamBold
DisplayNameLabel.TextSize = 13.5
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLabel.ZIndex   = 21

local UsernameLabel       = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Size        = UDim2.new(1, -82, 0, 14)
UsernameLabel.Position    = UDim2.new(0, 54, 0.5, 2)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text        = "@" .. player.Name
UsernameLabel.TextColor3  = Color3.fromRGB(110, 110, 110)
UsernameLabel.Font        = Enum.Font.Gotham
UsernameLabel.TextSize    = 11.5
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UsernameLabel.ZIndex      = 21

local PrivacyBtn          = Instance.new("ImageButton", UserProfileFrame)
PrivacyBtn.Size           = UDim2.new(0, 20, 0, 20)
PrivacyBtn.Position       = UDim2.new(1, -26, 0.5, -10)
PrivacyBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
PrivacyBtn.BackgroundTransparency = 0.2
PrivacyBtn.BorderSizePixel = 0
PrivacyBtn.ZIndex         = 22
PrivacyBtn.AutoButtonColor = false
Instance.new("UICorner", PrivacyBtn).CornerRadius = UDim.new(0, 5)

local PrivacyIcon         = Instance.new("ImageLabel", PrivacyBtn)
PrivacyIcon.Size          = UDim2.new(1, -6, 1, -6)
PrivacyIcon.Position      = UDim2.new(0, 3, 0, 3)
PrivacyIcon.BackgroundTransparency = 1
PrivacyIcon.Image         = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
PrivacyIcon.ZIndex        = 23

local isPrivate = false
PrivacyBtn.MouseButton1Click:Connect(function()
    PlayUI_Click()
    isPrivate = not isPrivate
    if isPrivate then
        PrivacyIcon.Image     = "rbxthumb://type=Asset&id=85795266774996&w=150&h=150"
        DisplayNameLabel.Text = string.rep("*", math.clamp(#player.DisplayName, 3, 8))
        UsernameLabel.Text    = "@" .. string.rep("*", math.clamp(#player.Name, 3, 8))
    else
        PrivacyIcon.Image     = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
        DisplayNameLabel.Text = player.DisplayName
        UsernameLabel.Text    = "@" .. player.Name
    end
end)

-- ==================== PAINEL DIREITO — HEADER ====================
local topButtons          = Instance.new("Frame", RightPanel)
topButtons.Size           = UDim2.new(1, -12, 0, 36)
topButtons.BackgroundTransparency = 1
topButtons.ZIndex         = 20

local ControlsFrame       = Instance.new("Frame", topButtons)
ControlsFrame.Size        = UDim2.new(0, 130, 1, 0)
ControlsFrame.Position    = UDim2.new(1, -130, 0, 0)
ControlsFrame.BackgroundTransparency = 1
ControlsFrame.ZIndex      = 25

local UIListTop           = Instance.new("UIListLayout", ControlsFrame)
UIListTop.FillDirection   = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment   = Enum.VerticalAlignment.Center
UIListTop.Padding         = UDim.new(0, 2)

local TOP_BTN_COLOR       = Color3.fromRGB(150, 150, 150)

local function CriarBotaoTopo(nome, idAsset, ordem)
    local btn   = Instance.new("ImageButton", ControlsFrame)
    btn.Name    = nome
    btn.LayoutOrder = ordem
    btn.Size    = UDim2.new(0, 28, 0, 28)
    btn.BackgroundTransparency = 1
    btn.ZIndex  = 25
    btn.AutoButtonColor = false
    local icon  = Instance.new("ImageLabel", btn)
    icon.Name   = "Icon"
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position    = UDim2.new(0.5, 0, 0.5, 0)
    icon.Size        = UDim2.new(0, 14, 0, 14)
    icon.BackgroundTransparency = 1
    icon.Image       = idAsset
    icon.ImageColor3 = TOP_BTN_COLOR
    icon.ZIndex      = 26
    return btn, icon
end

local MinimizeBtn, MinimizeIcon = CriarBotaoTopo("MinimizeBtn", "rbxthumb://type=Asset&id=97090905107587&w=150&h=150", 1)
local ExpandBtn,   ExpandIcon   = CriarBotaoTopo("ExpandBtn",   "rbxthumb://type=Asset&id=78749046909931&w=150&h=150", 2)
local CloseBtn,    CloseIcon    = CriarBotaoTopo("CloseBtn",    "rbxthumb://type=Asset&id=70710316269357&w=150&h=150", 3)

local BadgeFrame          = Instance.new("Frame", RightPanel)
BadgeFrame.Size           = UDim2.new(0, 44, 0, 18)
BadgeFrame.Position       = UDim2.new(0, 12, 0, 9)
BadgeFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
BadgeFrame.BorderSizePixel  = 0
BadgeFrame.ZIndex         = 15
Instance.new("UICorner", BadgeFrame).CornerRadius = UDim.new(0, 8)
local badgeGrad           = Instance.new("UIGradient", BadgeFrame)
badgeGrad.Rotation        = 45
badgeGrad.Color           = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(230,20,25)), ColorSequenceKeypoint.new(1, Color3.fromRGB(80,0,0))})
local BadgeText           = Instance.new("TextLabel", BadgeFrame)
BadgeText.Size            = UDim2.new(1, 0, 1, 0)
BadgeText.BackgroundTransparency = 1
BadgeText.Text            = "V6.0"
BadgeText.TextColor3      = Color3.fromRGB(255, 255, 255)
BadgeText.Font            = Enum.Font.GothamBold
BadgeText.TextSize        = 8.5
BadgeText.ZIndex          = 16

-- ==================== TOGGLES CONTAINER ====================
local togglesContainer    = Instance.new("ScrollingFrame", RightPanel)
togglesContainer.Name     = "TogglesContainer"
togglesContainer.Size     = UDim2.new(1, -12, 1, -48)
togglesContainer.Position = UDim2.new(0, 6, 0, 42)
togglesContainer.BackgroundColor3 = Color3.fromRGB(30, 12, 14)
togglesContainer.BackgroundTransparency = 0.7
togglesContainer.BorderSizePixel = 0
togglesContainer.ClipsDescendants = true
togglesContainer.ZIndex   = 10
togglesContainer.ScrollBarThickness = 2
togglesContainer.ScrollBarImageColor3 = Color3.fromRGB(220, 30, 40)
togglesContainer.ScrollBarImageTransparency = 0.35
togglesContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
togglesContainer.AutomaticCanvasSize = Enum.AutomaticSize.None
Instance.new("UICorner", togglesContainer).CornerRadius = UDim.new(0, 8)

local containerLayout     = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
containerLayout.Padding   = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local uiPadding           = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingTop      = UDim.new(0, 8)
uiPadding.PaddingBottom   = UDim.new(0, 8)
uiPadding.PaddingLeft     = UDim.new(0, 4)
uiPadding.PaddingRight    = UDim.new(0, 6)

local function UpdateCanvasSize()
    local contentH = containerLayout.AbsoluteContentSize.Y + 24
    local minH     = togglesContainer.AbsoluteSize.Y + 1
    togglesContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(contentH, minH))
end
containerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvasSize)
togglesContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateCanvasSize)

-- ==================== CONFIRM OVERLAY ====================
local confirmBlur         = Instance.new("BlurEffect", Lighting)
confirmBlur.Name          = "ConfirmBlur"
confirmBlur.Size          = 0

local confirmOverlay      = Instance.new("Frame", screenGui)
confirmOverlay.Size       = UDim2.new(1, 0, 1, 0)
confirmOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
confirmOverlay.BackgroundTransparency = 0.55
confirmOverlay.Visible    = false
confirmOverlay.ZIndex     = 990

local confirmCard         = Instance.new("Frame", confirmOverlay)
confirmCard.Size          = UDim2.new(0, 300, 0, 130)
confirmCard.AnchorPoint   = Vector2.new(0.5, 0.5)
confirmCard.Position      = UDim2.new(0.5, 0, 0.5, 0)
confirmCard.BackgroundColor3 = Color3.fromRGB(18, 8, 8)
confirmCard.BorderSizePixel  = 0
confirmCard.ZIndex        = 995
Instance.new("UICorner", confirmCard).CornerRadius = UDim.new(0, 14)

local confirmStroke       = Instance.new("UIStroke", confirmCard)
confirmStroke.Thickness   = 1.5
local confStrokeGrad      = Instance.new("UIGradient", confirmStroke)
confStrokeGrad.Color      = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(120,0,10)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,30,40)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120,0,10))})

local confirmLabel        = Instance.new("TextLabel", confirmCard)
confirmLabel.Size         = UDim2.new(1, -24, 0, 22)
confirmLabel.Position     = UDim2.new(0, 12, 0, 18)
confirmLabel.BackgroundTransparency = 1
confirmLabel.TextColor3   = Color3.fromRGB(235, 235, 235)
confirmLabel.Font         = Enum.Font.GothamBold
confirmLabel.TextSize     = 13
confirmLabel.TextXAlignment = Enum.TextXAlignment.Center
confirmLabel.Text         = UI_TEXT.ConfirmCloseTitle
confirmLabel.ZIndex       = 1000

local confirmSep          = Instance.new("Frame", confirmCard)
confirmSep.Size           = UDim2.new(1, -40, 0, 1)
confirmSep.Position       = UDim2.new(0, 20, 0, 48)
confirmSep.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
confirmSep.BackgroundTransparency = 0.6
confirmSep.BorderSizePixel = 0
confirmSep.ZIndex         = 999
Instance.new("UICorner", confirmSep).CornerRadius = UDim.new(1, 0)

local btnYes              = Instance.new("TextButton", confirmCard)
btnYes.Size               = UDim2.new(0, 118, 0, 32)
btnYes.Position           = UDim2.new(0.5, -124, 0, 62)
btnYes.BackgroundColor3   = Color3.fromRGB(139, 0, 0)
btnYes.TextColor3         = Color3.fromRGB(255, 255, 255)
btnYes.Font               = Enum.Font.GothamMedium
btnYes.TextSize           = 14
btnYes.Text               = UI_TEXT.ConfirmBtn
btnYes.ZIndex             = 1000
btnYes.BorderSizePixel    = 0
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 14)

local btnNo               = Instance.new("TextButton", confirmCard)
btnNo.Size                = UDim2.new(0, 118, 0, 32)
btnNo.Position            = UDim2.new(0.5, 6, 0, 62)
btnNo.BackgroundColor3    = Color3.fromRGB(30, 30, 30)
btnNo.TextColor3          = Color3.fromRGB(170, 170, 170)
btnNo.Font                = Enum.Font.GothamMedium
btnNo.TextSize            = 14
btnNo.Text                = UI_TEXT.CancelBtn
btnNo.ZIndex              = 1000
btnNo.BorderSizePixel     = 0
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 14)

btnYes.MouseEnter:Connect(function() TweenService:Create(btnYes, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(180,20,20)}):Play() end)
btnYes.MouseLeave:Connect(function() TweenService:Create(btnYes, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(139,0,0)}):Play() end)
btnNo.MouseEnter:Connect(function()  TweenService:Create(btnNo,  TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(45,45,45)}):Play() end)
btnNo.MouseLeave:Connect(function()  TweenService:Create(btnNo,  TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(30,30,30)}):Play() end)

AplicarFadeSincronizado(confirmCard, true, 0)

-- ==================== RENDERSTEP: GRADIENTES ANIMADOS ====================
RunService.RenderStepped:Connect(function()
    local t = os.clock()
    SingleRedGrad.Rotation   = 90 + math.sin(t * 0.55) * 28
    confStrokeGrad.Rotation  = 90 + math.sin(t * 0.70) * 25
    uGrad.Rotation           = 45 + math.sin(t * 0.80) * 35
    badgeGrad.Rotation       = 45 + math.sin(t * 0.45) * 20
end)

-- ==================== SISTEMA DE NOTIFICAÇÕES ====================
local ActiveNotifications = {}
local NOTIF_DURATION      = 10

local function UpdateNotifications()
    local currentY = -24
    for _, notif in ipairs(ActiveNotifications) do
        if notif and notif.Parent then
            local h = notif.Size.Y.Offset
            if h == 0 then h = 96 end
            TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 1, currentY)}):Play()
            currentY = currentY - (h + 12)
        end
    end
end

local function CriarNotificacaoBase(titulo, descricao, accentColor, extraSetup)
    accentColor = accentColor or Color3.fromRGB(180, 20, 20)
    local notifHolder         = Instance.new("Frame", screenGui)
    notifHolder.AnchorPoint   = Vector2.new(1, 1)
    notifHolder.Size          = UDim2.new(0, 330, 0, 96)
    notifHolder.Position      = UDim2.new(1, 360, 1, -24)
    notifHolder.BackgroundTransparency = 1
    notifHolder.ZIndex        = 200
    local notifScale          = Instance.new("UIScale", notifHolder)
    notifScale.Scale          = 0.96

    local notifCard           = Instance.new("Frame", notifHolder)
    notifCard.Size            = UDim2.new(1, 0, 1, 0)
    notifCard.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
    notifCard.BackgroundTransparency = 0.25
    notifCard.BorderSizePixel = 0
    notifCard.ZIndex          = 201
    Instance.new("UICorner", notifCard).CornerRadius = UDim.new(0, 16)

    local accentBar           = Instance.new("Frame", notifCard)
    accentBar.Size            = UDim2.new(0, 4, 0, 52)
    accentBar.Position        = UDim2.new(0, 14, 0.5, -26)
    accentBar.BackgroundColor3 = accentColor
    accentBar.BorderSizePixel = 0
    accentBar.ZIndex          = 202
    Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

    local notifTitle          = Instance.new("TextLabel", notifCard)
    notifTitle.Size           = UDim2.new(1, -76, 0, 18)
    notifTitle.Position       = UDim2.new(0, 26, 0.5, -19)
    notifTitle.BackgroundTransparency = 1
    notifTitle.Text           = titulo or "AKATSUKI"
    notifTitle.TextColor3     = Color3.fromRGB(240, 240, 240)
    notifTitle.Font           = Enum.Font.GothamBold
    notifTitle.TextSize       = 16
    notifTitle.TextXAlignment = Enum.TextXAlignment.Left
    notifTitle.ZIndex         = 203

    local notifDesc           = Instance.new("TextLabel", notifCard)
    notifDesc.Size            = UDim2.new(1, -76, 0, 18)
    notifDesc.Position        = UDim2.new(0, 26, 0.5, 1)
    notifDesc.BackgroundTransparency = 1
    notifDesc.Text            = descricao or ""
    notifDesc.TextColor3      = Color3.fromRGB(150, 150, 155)
    notifDesc.Font            = Enum.Font.Gotham
    notifDesc.TextSize        = 12
    notifDesc.TextXAlignment  = Enum.TextXAlignment.Left
    notifDesc.TextWrapped     = true
    notifDesc.ZIndex          = 203

    local notifCloseBtn       = Instance.new("TextButton", notifCard)
    notifCloseBtn.Size        = UDim2.new(0, 24, 0, 24)
    notifCloseBtn.Position    = UDim2.new(1, -32, 0, 10)
    notifCloseBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
    notifCloseBtn.BackgroundTransparency = 0.2
    notifCloseBtn.Text        = "✕"
    notifCloseBtn.TextColor3  = Color3.fromRGB(160, 160, 165)
    notifCloseBtn.TextSize    = 11
    notifCloseBtn.Font        = Enum.Font.GothamBold
    notifCloseBtn.ZIndex      = 205
    notifCloseBtn.BorderSizePixel = 0
    Instance.new("UICorner", notifCloseBtn).CornerRadius = UDim.new(0, 6)

    notifCloseBtn.MouseEnter:Connect(function()
        TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160,20,20), TextColor3 = Color3.fromRGB(255,255,255)}):Play()
    end)
    notifCloseBtn.MouseLeave:Connect(function()
        TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(35,35,38), TextColor3 = Color3.fromRGB(160,160,165)}):Play()
    end)

    local progressBg          = Instance.new("Frame", notifCard)
    progressBg.Size           = UDim2.new(1, -28, 0, 3)
    progressBg.Position       = UDim2.new(0, 14, 1, -10)
    progressBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    progressBg.BorderSizePixel  = 0
    progressBg.ZIndex         = 202
    progressBg.ClipsDescendants = true
    Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)
    local progressBar         = Instance.new("Frame", progressBg)
    progressBar.Size          = UDim2.new(1, 0, 1, 0)
    progressBar.BackgroundColor3 = accentColor
    progressBar.BorderSizePixel  = 0
    progressBar.ZIndex        = 203
    Instance.new("UICorner", progressBar).CornerRadius = UDim.new(1, 0)

    if extraSetup then extraSetup(notifCard, notifTitle, notifDesc) end

    table.insert(ActiveNotifications, 1, notifHolder)
    UpdateNotifications()

    TweenService:Create(notifHolder, TweenInfo.new(0.30, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 1, -24)}):Play()
    TweenService:Create(notifScale,  TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1}):Play()

    local dismissed = false
    local function Dismiss()
        if dismissed then return end
        dismissed = true
        for i, v in ipairs(ActiveNotifications) do if v == notifHolder then table.remove(ActiveNotifications, i); break end end
        UpdateNotifications()
        local slideOut = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
        TweenService:Create(notifHolder, slideOut, {Position = UDim2.new(1, 360, notifHolder.Position.Y.Scale, notifHolder.Position.Y.Offset)}):Play()
        TweenService:Create(notifCard,   slideOut, {BackgroundTransparency = 1}):Play()
        TweenService:Create(notifScale,  TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.96}):Play()
        task.delay(0.28, function() if notifHolder and notifHolder.Parent then notifHolder:Destroy() end end)
    end

    notifCloseBtn.MouseButton1Click:Connect(Dismiss)
    task.delay(0.1, function() TweenService:Create(progressBar, TweenInfo.new(NOTIF_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 1, 0)}):Play() end)
    task.delay(NOTIF_DURATION + 0.1, Dismiss)
end

local function CriarNotificacao(titulo, descricao)
    CriarNotificacaoBase(titulo, descricao, Color3.fromRGB(180, 20, 20))
end

local function CriarNotificacaoDiscord()
    CriarNotificacaoBase("DISCORD SERVER", "https://discord.gg/rZuYzZ7zvt", Color3.fromRGB(88, 101, 242), function(card)
        local copyBtn      = Instance.new("TextButton", card)
        copyBtn.Size       = UDim2.new(0, 70, 0, 24)
        copyBtn.AnchorPoint = Vector2.new(1, 1)
        copyBtn.Position   = UDim2.new(1, -14, 1, -14)
        copyBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
        copyBtn.Text       = "COPY"
        copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        copyBtn.Font       = Enum.Font.GothamBold
        copyBtn.TextSize   = 12
        copyBtn.ZIndex     = 205
        copyBtn.BorderSizePixel = 0
        Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)
        copyBtn.MouseButton1Click:Connect(function()
            PlayUI_Click()
            if setclipboard then
                pcall(function() setclipboard("https://discord.gg/rZuYzZ7zvt") end)
                CriarNotificacao("LINK COPIED!", "Discord link copiado com sucesso.")
            end
        end)
    end)
end

-- ==================== FILTRO / PESQUISA ====================
local filterDebounceThread = nil

local function filterToggles(currentActiveTab, query)
    local searchQuery = (query or ""):lower()
    local itemIndex   = 0
    for _, child in ipairs(togglesContainer:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
            local itemTab     = child:GetAttribute("Tab") or "Farm"
            local validTab = tabButtons[itemTab] ~= nil
            local visible
            if searchQuery ~= "" then
                local t = child:FindFirstChild("Title")
                local d = child:FindFirstChild("Description")
                visible = validTab and ((t and t.Text:lower():find(searchQuery) ~= nil) or (d and d.Text:lower():find(searchQuery) ~= nil))
            else
                visible = (itemTab == currentActiveTab)
            end
            child.Visible = visible
            if visible then
                itemIndex = itemIndex + 1
                child.Size = UDim2.new(1, -10, 0, 0)
                child.BackgroundTransparency = 1
                local t = child:FindFirstChild("Title")
                local d = child:FindFirstChild("Description")
                if t then t.TextTransparency = 1 end
                if d then d.TextTransparency = 1 end
                task.delay((itemIndex - 1) * 0.02, function()
                    if not child or not child.Parent then return end
                    TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.new(1, -10, 0, child:GetAttribute("ItemHeight") or 60), BackgroundTransparency = 0.45}):Play()
                    if t then TweenService:Create(t, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
                    if d then TweenService:Create(d, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
                end)
            end
        end
    end
    task.delay(0.05, function() pcall(UpdateCanvasSize) end)
end

-- ==================== ACTIVEBAR: POSICIONAMENTO ====================
local function UpdateActiveBarPosition(animar)
    local targetBtn = tabButtons[activeTab]
    if not targetBtn or not sharedActiveBar.Visible then return end
    local deferCount = 0
    local function aplicar()
        if not targetBtn or not targetBtn.Parent then return end
        deferCount += 1
        local btnAbsSize = targetBtn.AbsoluteSize.Y
        local btnAbsPos  = targetBtn.AbsolutePosition.Y
        local panelAbsY  = ActiveBarContainer.AbsolutePosition.Y
        if (btnAbsSize == 0 or btnAbsPos == 0) and deferCount < 8 then task.defer(aplicar); return end
        local targetYPos = (btnAbsPos + btnAbsSize / 2) - panelAbsY
        if animar then
            TweenService:Create(sharedActiveBar, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(0, 7, 0, targetYPos)}):Play()
            activeBarScale.Scale = 1.08
            TweenService:Create(activeBarScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
        else
            sharedActiveBar.Position = UDim2.new(0, 7, 0, targetYPos)
            activeBarScale.Scale = 1
        end
    end
    task.defer(aplicar)
end

TabsContainer:GetPropertyChangedSignal("CanvasPosition"):Connect(function() UpdateActiveBarPosition(false) end)

-- ==================== SELECIONAR ABA ====================
local function selectTab(tabName)
    activeTab = tabName
    for name, btn in pairs(tabButtons) do
        local label = btn:FindFirstChild("Label")
        local iconC = btn:FindFirstChild("Icon")
        local anim  = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
        if name == tabName then
            TweenService:Create(btn,   anim, {BackgroundColor3 = Color3.fromRGB(45,10,15), BackgroundTransparency = 0.5}):Play()
            if label then TweenService:Create(label, anim, {TextColor3 = Color3.fromRGB(255,255,255)}):Play() end
            if iconC and iconC:FindFirstChild("AccentImage") then TweenService:Create(iconC.AccentImage, anim, {ImageColor3 = Color3.fromRGB(255,255,255)}):Play() end
            originalTrans[btn] = {BackgroundTransparency = 0.5}
        else
            TweenService:Create(btn,   anim, {BackgroundColor3 = Color3.fromRGB(15,15,15), BackgroundTransparency = 1}):Play()
            if label then TweenService:Create(label, anim, {TextColor3 = Color3.fromRGB(150,150,150)}):Play() end
            if iconC and iconC:FindFirstChild("AccentImage") then TweenService:Create(iconC.AccentImage, anim, {ImageColor3 = Color3.fromRGB(150,150,150)}):Play() end
            originalTrans[btn] = {BackgroundTransparency = 1}
        end
    end
    sharedActiveBar.Visible = true
    UpdateActiveBarPosition(true)
    togglesContainer.CanvasPosition = Vector2.new(0, 0)
    searchTextBox.Text = ""
    filterToggles(tabName, "")
end

-- ==================== CRIAR ABA ====================
local function createTabBtn(tabName)
    local tabBtn  = Instance.new("TextButton", TabsContainer)
    tabBtn.Name   = tabName .. "TabBtn"
    tabBtn.Size   = UDim2.new(1, -16, 0, 36)
    tabBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text   = ""
    tabBtn.ZIndex = 11
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 8)

    local iconContainer = Instance.new("Frame", tabBtn)
    iconContainer.Name  = "Icon"
    iconContainer.Size  = UDim2.new(0, 14, 0, 14)
    iconContainer.Position = UDim2.new(0, 14, 0.5, -7)
    iconContainer.BackgroundTransparency = 1
    iconContainer.ZIndex = 12
    local imageLabel    = Instance.new("ImageLabel", iconContainer)
    imageLabel.Name     = "AccentImage"
    imageLabel.Size     = UDim2.new(1, 0, 1, 0)
    imageLabel.BackgroundTransparency = 1
    imageLabel.ZIndex   = 13
    imageLabel.ImageColor3 = Color3.fromRGB(150, 150, 150)
    imageLabel.Image    = "rbxthumb://type=Asset&id=71234705040146&w=150&h=150"

    local tabLabel      = Instance.new("TextLabel", tabBtn)
    tabLabel.Name       = "Label"
    tabLabel.Size       = UDim2.new(1, -42, 1, 0)
    tabLabel.Position   = UDim2.new(0, 38, 0, 0)
    tabLabel.BackgroundTransparency = 1
    tabLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    tabLabel.Font       = Enum.Font.GothamMedium
    tabLabel.TextSize   = 13
    tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.Text       = UI_TEXT.Tabs[tabName] or tabName
    tabLabel.ZIndex     = 12

    local tabScale = Instance.new("UIScale", tabBtn)
    tabScale.Scale = 1
    tabBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(tabScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.97}):Play()
        end
    end)
    tabBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(tabScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        end
    end)
    tabBtn.MouseButton1Click:Connect(function() selectTab(tabName) end)
    tabButtons[tabName] = tabBtn
end

-- ==================== TOGGLE PADRÃO (60px) ====================
local function createToggle(parent, configKey, tabCategory)
    local frame = Instance.new("Frame")
    frame.Name  = configKey
    frame.Size  = UDim2.new(1, -10, 0, 60)
    frame:SetAttribute("ItemHeight", 60)
    frame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
    frame.BackgroundTransparency = 0.45
    frame.ZIndex = 11
    frame.ClipsDescendants = true
    frame:SetAttribute("Tab", tabCategory)
    frame:SetAttribute("ConfigKey", configKey)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local optData  = UI_TEXT.Options[configKey]
    local titleLbl = Instance.new("TextLabel", frame)
    titleLbl.Name  = "Title"
    titleLbl.Size  = UDim2.new(0.7, 0, 0, 18)
    titleLbl.Position = UDim2.new(0, 12, 0, 9)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3 = Color3.fromRGB(210, 210, 210)
    titleLbl.Font  = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Text  = optData and optData.Title or configKey
    titleLbl.ZIndex = 11

    local descLbl  = Instance.new("TextLabel", frame)
    descLbl.Name   = "Description"
    descLbl.Size   = UDim2.new(0.7, 0, 0, 28)
    descLbl.Position = UDim2.new(0, 12, 0, 28)
    descLbl.BackgroundTransparency = 1
    descLbl.TextColor3 = Color3.fromRGB(130, 130, 130)
    descLbl.Font   = Enum.Font.Gotham
    descLbl.TextSize = 10.5
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.TextYAlignment = Enum.TextYAlignment.Top
    descLbl.TextWrapped = true
    descLbl.Text   = optData and optData.Desc or ""
    descLbl.ZIndex = 11

    local track    = Instance.new("Frame", frame)
    track.Size     = UDim2.new(0, 48, 0, 24)
    track.Position = UDim2.new(1, -54, 0.5, -12)
    track.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
    track.ZIndex   = 11
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local circle   = Instance.new("Frame", track)
    circle.Size    = UDim2.new(0, 18, 0, 18)
    circle.Position = Configs[configKey] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    circle.ZIndex  = 12
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local frameScale = Instance.new("UIScale", frame)
    frameScale.Scale = 1

    local triggerBtn = Instance.new("TextButton", frame)
    triggerBtn.Size  = UDim2.new(1, 0, 1, 0)
    triggerBtn.BackgroundTransparency = 1
    triggerBtn.Text  = ""
    triggerBtn.ZIndex = 13

    triggerBtn.MouseButton1Click:Connect(function()
        PlayUI_Click()
        Configs[configKey] = not Configs[configKey]
        local on   = Configs[configKey]
        local anim = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(circle, anim, {Position = on and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}):Play()
        TweenService:Create(track,  anim, {BackgroundColor3 = on and Color3.fromHex("#8B0000") or Color3.fromRGB(30,30,30)}):Play()
        frameScale.Scale = 0.97
        TweenService:Create(frameScale, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1}):Play()
        local cb = _G.AkatCallbacks and _G.AkatCallbacks[configKey]
        if type(cb) == "function" then pcall(cb, on) end
    end)
end

-- ==================== TOGGLE COMPACTO (42px) ====================
local function createCompactToggle(parent, configKey, tabCategory)
    local frame = Instance.new("Frame")
    frame.Name  = configKey
    frame.Size  = UDim2.new(1, -10, 0, 42)
    frame:SetAttribute("ItemHeight", 42)
    frame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
    frame.BackgroundTransparency = 0.45
    frame.ZIndex = 11
    frame.ClipsDescendants = true
    frame:SetAttribute("Tab", tabCategory)
    frame:SetAttribute("ConfigKey", configKey)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel", frame)
    title.Name  = "Title"
    title.Size  = UDim2.new(1, -78, 1, 0)
    title.Position = UDim2.fromOffset(12, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(210, 210, 210)
    title.Font  = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.Text  = (UI_TEXT.Options[configKey] and UI_TEXT.Options[configKey].Title) or configKey
    title.ZIndex = 12

    local track = Instance.new("Frame", frame)
    track.Size  = UDim2.fromOffset(42, 22)
    track.Position = UDim2.new(1, -52, 0.5, -11)
    track.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
    track.ZIndex = 12
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame", track)
    circle.Size  = UDim2.fromOffset(16, 16)
    circle.Position = Configs[configKey] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    circle.ZIndex = 13
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local hit   = Instance.new("TextButton", frame)
    hit.Size    = UDim2.fromScale(1, 1)
    hit.BackgroundTransparency = 1
    hit.Text    = ""
    hit.ZIndex  = 14
    hit.MouseButton1Click:Connect(function()
        PlayUI_Click()
        Configs[configKey] = not Configs[configKey]
        local on   = Configs[configKey]
        local anim = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(circle, anim, {Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
        TweenService:Create(track,  anim, {BackgroundColor3 = on and Color3.fromHex("#8B0000") or Color3.fromRGB(30,30,30)}):Play()
        local cb = _G.AkatCallbacks and _G.AkatCallbacks[configKey]
        if type(cb) == "function" then pcall(cb, on) end
    end)
end

-- ==================== DROPDOWN (42px) ====================
local function createDropdown(parent, configKey, tabCategory, options, defaultValue)
    local frame = Instance.new("Frame")
    frame.Name  = configKey
    frame.Size  = UDim2.new(1, -10, 0, 42)
    frame:SetAttribute("ItemHeight", 42)
    frame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
    frame.BackgroundTransparency = 0.45
    frame.ZIndex = 11
    frame.ClipsDescendants = true
    frame:SetAttribute("Tab", tabCategory)
    frame:SetAttribute("ConfigKey", configKey)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel", frame)
    title.Name  = "Title"
    title.Size  = UDim2.new(0, 120, 1, 0)
    title.Position = UDim2.fromOffset(12, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(210, 210, 210)
    title.Font  = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text  = (UI_TEXT.Options[configKey] and UI_TEXT.Options[configKey].Title) or configKey
    title.ZIndex = 12

    local valueBtn = Instance.new("TextButton", frame)
    valueBtn.Name  = "Value"
    valueBtn.Size  = UDim2.new(0, 175, 0, 28)
    valueBtn.Position = UDim2.new(1, -187, 0.5, -14)
    valueBtn.BackgroundColor3 = Color3.fromRGB(35, 10, 13)
    valueBtn.BackgroundTransparency = 0.15
    valueBtn.BorderSizePixel = 0
    valueBtn.AutoButtonColor = false
    valueBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
    valueBtn.Font  = Enum.Font.GothamMedium
    valueBtn.TextSize = 11
    valueBtn.TextXAlignment = Enum.TextXAlignment.Center
    valueBtn.ZIndex = 13
    Instance.new("UICorner", valueBtn).CornerRadius = UDim.new(0, 7)

    local index = 1
    for i, opt in ipairs(options) do
        if opt == (Configs[configKey] or defaultValue) then index = i; break end
    end
    Configs[configKey] = options[index] or defaultValue or options[1]
    valueBtn.Text = tostring(Configs[configKey])

    valueBtn.MouseButton1Click:Connect(function()
        PlayUI_Click()
        index = (index % #options) + 1
        Configs[configKey] = options[index]
        valueBtn.Text = tostring(Configs[configKey])
        local cb = _G.AkatCallbacks and _G.AkatCallbacks[configKey]
        if type(cb) == "function" then pcall(cb, Configs[configKey]) end
    end)
end

-- ==================== STATUS ROW (somente leitura) ====================
local function createStatusRow(parent, configKey, tabCategory)
    local frame = Instance.new("Frame")
    frame.Name  = configKey
    frame.Size  = UDim2.new(1, -10, 0, 42)
    frame:SetAttribute("ItemHeight", 42)
    frame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
    frame.BackgroundTransparency = 0.45
    frame.ZIndex = 11
    frame:SetAttribute("Tab", tabCategory)
    frame:SetAttribute("ConfigKey", configKey)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel", frame)
    title.Name  = "Title"
    title.Size  = UDim2.new(0.45, 0, 1, 0)
    title.Position = UDim2.fromOffset(12, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(170, 170, 170)
    title.Font  = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text  = (UI_TEXT.Options[configKey] and UI_TEXT.Options[configKey].Title) or configKey
    title.ZIndex = 12

    local value = Instance.new("TextLabel", frame)
    value.Name  = "Value"
    value.Size  = UDim2.new(0.52, -12, 1, 0)
    value.Position = UDim2.new(0.45, 0, 0, 0)
    value.BackgroundTransparency = 1
    value.TextColor3 = Color3.fromRGB(235, 235, 235)
    value.Font  = Enum.Font.GothamMedium
    value.TextSize = 12
    value.TextXAlignment = Enum.TextXAlignment.Right
    value.TextTruncate = Enum.TextTruncate.AtEnd
    value.Text  = "-"
    value.ZIndex = 12
end

-- ==================== SLIDER COMPACTO ====================
local function createCompactSlider(parent, configKey, tabCategory, minValue, maxValue, defaultValue)
    local frame = Instance.new("Frame")
    frame.Name  = configKey
    frame.Size  = UDim2.new(1, -10, 0, 42)
    frame:SetAttribute("ItemHeight", 42)
    frame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
    frame.BackgroundTransparency = 0.45
    frame.ZIndex = 11
    frame.ClipsDescendants = true
    frame:SetAttribute("Tab", tabCategory)
    frame:SetAttribute("ConfigKey", configKey)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local titleLbl = Instance.new("TextLabel", frame)
    titleLbl.Name  = "Title"
    titleLbl.Size  = UDim2.new(0, 100, 1, 0)
    titleLbl.Position = UDim2.new(0, 12, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3 = Color3.fromRGB(210, 210, 210)
    titleLbl.Font  = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextYAlignment = Enum.TextYAlignment.Center
    titleLbl.Text  = (UI_TEXT.Options[configKey] and UI_TEXT.Options[configKey].Title) or configKey
    titleLbl.ZIndex = 12

    local track    = Instance.new("Frame", frame)
    track.Size     = UDim2.new(1, -168, 0, 6)
    track.Position = UDim2.new(0, 116, 0.5, -3)
    track.BackgroundColor3 = Color3.fromRGB(45, 25, 27)
    track.BorderSizePixel  = 0
    track.ZIndex   = 12
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill     = Instance.new("Frame", track)
    fill.Size      = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
    fill.BorderSizePixel  = 0
    fill.ZIndex    = 13
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob     = Instance.new("Frame", track)
    knob.Size      = UDim2.fromOffset(14, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position  = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel  = 0
    knob.ZIndex    = 14
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local valueLbl = Instance.new("TextLabel", frame)
    valueLbl.Name  = "Value"
    valueLbl.Size  = UDim2.fromOffset(46, 22)
    valueLbl.AnchorPoint = Vector2.new(1, 0.5)
    valueLbl.Position    = UDim2.new(1, -10, 0.5, 0)
    valueLbl.BackgroundTransparency = 1
    valueLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLbl.Font  = Enum.Font.GothamBold
    valueLbl.TextSize = 15
    valueLbl.TextXAlignment = Enum.TextXAlignment.Right
    valueLbl.ZIndex = 13

    local hit      = Instance.new("TextButton", frame)
    hit.Size       = UDim2.new(1, -148, 0, 30)
    hit.Position   = UDim2.new(0, 110, 0.5, -15)
    hit.BackgroundTransparency = 1
    hit.Text       = ""
    hit.AutoButtonColor = false
    hit.ZIndex     = 15

    local currentValue = math.clamp(tonumber(defaultValue) or tonumber(Configs[configKey .. "Value"]) or minValue, minValue, maxValue)
    local dragging = false

    local function setValue(v, notify)
        currentValue = math.clamp(v, minValue, maxValue)
        local alpha  = (currentValue - minValue) / math.max(1, maxValue - minValue)
        valueLbl.Text = string.format("%.0f", currentValue)
        fill.Size     = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        Configs[configKey .. "Value"] = currentValue
        Configs[configKey] = currentValue
        if notify then
            local cb = _G.AkatCallbacks and _G.AkatCallbacks[configKey]
            if type(cb) == "function" then pcall(cb, currentValue) end
        end
    end

    local function updateFromInput(input)
        local left  = track.AbsolutePosition.X
        local width = math.max(1, track.AbsoluteSize.X)
        local alpha = math.clamp((input.Position.X - left) / width, 0, 1)
        setValue(math.floor(minValue + (maxValue - minValue) * alpha + 0.5), true)
    end

    setValue(currentValue, false)

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ==================== PESQUISA: DEBOUNCE ====================
searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
    if filterDebounceThread then task.cancel(filterDebounceThread) end
    filterDebounceThread = task.delay(0.08, function()
        filterDebounceThread = nil
        filterToggles(activeTab, searchTextBox.Text)
    end)
end)

-- ==================== EXPAND / RESIZE RESPONSIVO ====================
local function ApplyResponsiveWindowSize(animate)
    local normalSize, expandedSize = GetResponsiveUISizes()
    local targetSize = isExpanded and expandedSize or normalSize
    if animate then
        TweenService:Create(mainWrapper, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = targetSize}):Play()
    else
        mainWrapper.Size = targetSize
    end
    task.defer(function() ClampMainWrapperToViewport(mainWrapper) end)
end

local viewportConnection
local function BindViewportResize()
    if viewportConnection then viewportConnection:Disconnect(); viewportConnection = nil end
    local camera = workspace.CurrentCamera
    if not camera then return end
    viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if not mainWrapper or not mainWrapper.Parent then return end
        ApplyResponsiveWindowSize(UIState == "OPEN")
        ClampMainWrapperToViewport(mainWrapper)
        UpdateActiveBarPosition(false)
        task.defer(UpdateCanvasSize)
        task.defer(UpdateTabsCanvas)
    end)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(BindViewportResize)
BindViewportResize()

ExpandBtn.MouseButton1Click:Connect(function()
    PlayUI_Click()
    if UIState ~= "OPEN" then return end
    isExpanded = not isExpanded
    ApplyResponsiveWindowSize(true)
end)

-- ==================== MÁQUINA DE ESTADOS DA UI ====================
local isTransitioning = false

SetUIState = function(newState)
    if UIState == newState or isTransitioning then return end
    isTransitioning = true
    local tempoAnim  = 0.25
    local windowAnim = TweenInfo.new(tempoAnim, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    if newState == "OPEN" then
        mainWrapper.Visible = true
        mainWrapper.Size    = select(1, GetResponsiveUISizes())
        AplicarFadeSincronizado(mainWrapper, true,  0)
        AplicarFadeSincronizado(mainWrapper, false, tempoAnim)
        local normalSize, expandedSize = GetResponsiveUISizes()
        local targetSize = isExpanded and expandedSize or normalSize
        local t = TweenService:Create(mainWrapper, windowAnim, {Size = targetSize})
        t:Play()
        t.Completed:Connect(function()
            UIState         = "OPEN"
            isTransitioning = false
            selectTab(activeTab)
            filterToggles(activeTab, searchTextBox.Text)
            UpdateActiveBarPosition(false)
        end)
    elseif newState == "MINIMIZED" or newState == "CLOSED" then
        AplicarFadeSincronizado(mainWrapper, true, tempoAnim)
        local vp = GetViewportSize()
        local shrinkSize = UDim2.fromOffset(math.min(NORMAL_UI_SIZE.X, math.max(1, vp.X - UI_SAFE_MARGIN * 2)), math.min(NORMAL_UI_SIZE.Y, math.max(1, vp.Y - UI_SAFE_MARGIN * 2)))
        local t = TweenService:Create(mainWrapper, windowAnim, {Size = shrinkSize})
        t:Play()
        t.Completed:Connect(function()
            mainWrapper.Visible = false
            UIState             = newState
            isTransitioning     = false
        end)
    else
        isTransitioning = false
    end
end

-- ==================== HOVER / CLICK NOS BOTÕES DO TOPO ====================
local function AplicarEfeitoFisicoBotao(btn, icon, hoverColor)
    local btnScale = Instance.new("UIScale", btn)
    btnScale.Scale = 1
    btn.MouseEnter:Connect(function() if UIState ~= "OPEN" then return end TweenService:Create(icon, TweenInfo.new(0.15), {ImageColor3 = hoverColor}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(icon, TweenInfo.new(0.15), {ImageColor3 = TOP_BTN_COLOR}):Play(); TweenService:Create(btnScale, TweenInfo.new(0.12), {Scale = 1}):Play() end)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(btnScale, TweenInfo.new(0.07), {Scale = 0.92}):Play()
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(btnScale, TweenInfo.new(0.12, Enum.EasingStyle.Back), {Scale = 1}):Play()
        end
    end)
end

AplicarEfeitoFisicoBotao(MinimizeBtn, MinimizeIcon, Color3.fromRGB(255,255,255))
AplicarEfeitoFisicoBotao(ExpandBtn,   ExpandIcon,   Color3.fromRGB(255,255,255))
AplicarEfeitoFisicoBotao(CloseBtn,    CloseIcon,    Color3.fromRGB(255,60,60))

MinimizeBtn.MouseButton1Click:Connect(function() PlayUI_Click(); SetUIState("MINIMIZED") end)

-- ==================== CONFIRMAÇÃO DE FECHAMENTO ====================
local function AlternarConfirmacao(exibir)
    isConfirmOpen = exibir
    local tempoAnim = 0.25
    if exibir then
        mainWrapper.Visible    = false
        FloatBtn.Visible       = false
        confirmOverlay.Visible = true
        TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 28}):Play()
        local oldScale = confirmCard:FindFirstChildOfClass("UIScale")
        if oldScale then oldScale:Destroy() end
        local cardScale = Instance.new("UIScale", confirmCard)
        cardScale.Scale = 0.88
        TweenService:Create(cardScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        AplicarFadeSincronizado(confirmCard, false, tempoAnim)
    else
        TweenService:Create(confirmBlur, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = 0}):Play()
        AplicarFadeSincronizado(confirmCard, true, tempoAnim)
        local sc = confirmCard:FindFirstChildOfClass("UIScale")
        if sc then TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.88}):Play() end
        task.delay(tempoAnim + 0.05, function()
            if not isConfirmOpen then
                confirmOverlay.Visible = false
                local sc2 = confirmCard:FindFirstChildOfClass("UIScale")
                if sc2 then sc2:Destroy() end
                if UIState == "OPEN" then mainWrapper.Visible = true end
                FloatBtn.Visible = true
            end
        end)
    end
end

CloseBtn.MouseButton1Click:Connect(function() PlayUI_Click(); AlternarConfirmacao(true) end)
btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)
btnYes.MouseButton1Click:Connect(function()
    TweenService:Create(confirmBlur, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = 0}):Play()
    AplicarFadeSincronizado(confirmCard, true, 0.2)
    task.wait(0.2)
    pcall(function() confirmBlur:Destroy() end)
    scriptAlive = false
    if _G.AkatCallbacks and type(_G.AkatCallbacks.ShutdownAll) == "function" then
        pcall(_G.AkatCallbacks.ShutdownAll)
    end
    pcall(function() screenGui:Destroy() end)
end)

-- ==================== CRIAR ABAS ====================
createTabBtn("Farm")
createTabBtn("Mastery")
createTabBtn("Boss")
createTabBtn("Stats")
createTabBtn("Status")

-- ==================== CONTEÚDO DAS ABAS ====================
-- Farm: Quest, Level e ataque são internos ao Auto Farm.
createToggle(togglesContainer,        "AutoFarm",      "Farm")
createDropdown(togglesContainer,      "FightingStyle", "Farm", {"Current","Melee"}, "Current")
createDropdown(togglesContainer,      "FarmPosition",  "Farm", {"Above NPC","Behind NPC","Front of NPC","Near NPC"}, "Above NPC")
createCompactSlider(togglesContainer, "FarmHeight",    "Farm", 5, 40, 8)

-- Mastery
createToggle(togglesContainer,        "AutoMastery",   "Mastery")
createDropdown(togglesContainer,      "MasteryType",   "Mastery", {"Fighting Style","Sword","Gun","Blox Fruit"}, "Fighting Style")
createCompactSlider(togglesContainer, "TargetMastery", "Mastery", 1, 600, 300)

-- Boss
createToggle(togglesContainer,        "AutoBoss",      "Boss")
createDropdown(togglesContainer,      "BossSelection", "Boss", {"Available Boss","Selected Boss","Boss Rotation"}, "Available Boss")
createDropdown(togglesContainer,      "BossName",      "Boss", {"Any Boss","Saber Expert","Mob Leader","Vice Admiral","Warden","Chief Warden","Swan","Don Swan","Diamond","Jeremy","Smoke Admiral","Cursed Captain","Awakened Ice Admiral","Tide Keeper","Stone","Island Empress","Beautiful Pirate","Longma","Cake Queen","Cake Prince","Rip Indra"}, "Any Boss")
createToggle(togglesContainer,        "BossQuest",     "Boss")

-- Stats
createToggle(togglesContainer,        "AutoStats",     "Stats")
createDropdown(togglesContainer,      "PrimaryStat",   "Stats", {"Blox Fruit","Defense","Melee","Sword","Gun"}, "Blox Fruit")
createDropdown(togglesContainer,      "SecondaryStat", "Stats", {"Defense","Melee","Blox Fruit","Sword","Gun"}, "Defense")
createDropdown(togglesContainer,      "TertiaryStat",  "Stats", {"Melee","Defense","Blox Fruit","Sword","Gun"}, "Melee")

-- Status
createStatusRow(togglesContainer, "State",         "Status")
createStatusRow(togglesContainer, "CurrentTask",   "Status")
createStatusRow(togglesContainer, "CurrentTarget", "Status")
createStatusRow(togglesContainer, "CurrentQuest",  "Status")
createStatusRow(togglesContainer, "CurrentArea",   "Status")
createStatusRow(togglesContainer, "Level",         "Status")
createStatusRow(togglesContainer, "Progress",      "Status")

-- ==================== STATUS LIVE ====================
task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.25)
        local status = _G.AkatFarmStatus
        if status then
            local values = {
                State         = status.State,
                CurrentTask   = status.CurrentTask or status.task,
                CurrentTarget = status.CurrentTarget or status.target,
                CurrentQuest  = status.CurrentQuest or status.quest,
                CurrentArea   = status.CurrentArea  or status.area,
                Level         = status.Level  or status.level,
                Progress      = status.Progress and (tostring(status.Progress) .. "%") or "-",
            }
            for key, text in pairs(values) do
                local row   = togglesContainer:FindFirstChild(key)
                local label = row and row:FindFirstChild("Value")
                if label then label.Text = tostring(text or "-") end
            end
        end
    end
end)

-- =====================================================================
-- ==================== BACKEND: LÓGICA DO FARM ========================
-- =====================================================================

-- ==================== HELPERS DE COMPATIBILIDADE ====================
local function IsAnyFarmModeEnabled()
    return Configs.AutoFarm or Configs.AutoMastery or Configs.AutoBoss
end

local function NormalizeFarmPosition(value)
    local v = tostring(value or "Above"):lower()
    if v:find("behind") then return "Behind" end
    if v:find("front")  then return "Front"  end
    if v:find("near")   then return "Near"   end
    return "Above"
end

local function NormalizeMasteryType(value)
    local v = tostring(value or ""):lower()
    if v:find("sword") then return "Sword" end
    if v:find("gun")   then return "Gun"   end
    if v:find("fruit") then return "BloxFruit" end
    return "FightingStyle"
end

local function NormalizeBossMode(value)
    local v = tostring(value or ""):lower()
    if v:find("available") then return "Available" end
    if v:find("rotation")  then return "Rotation"  end
    return "Selected"
end

local function NormalizeBossName(value)
    local v = tostring(value or "Any")
    return (v == "Any Boss") and "Any" or v
end

local function NormalizeStat(value)
    local v = tostring(value or ""):lower()
    if v:find("fruit")   then return "BloxFruit" end
    if v:find("defense") then return "Defense"   end
    if v:find("melee")   then return "Melee"     end
    if v:find("sword")   then return "Sword"     end
    if v:find("gun")     then return "Gun"       end
    return "Melee"
end


-- ==================== ESTADOS DA MÁQUINA ====================
local FM_STATES = {
    IDLE           = "Idle",
    INIT           = "Initializing",
    CHECK_CHAR     = "Checking Char",
    CHECK_LEVEL    = "Checking Level",
    FIND_QUEST     = "Finding Quest",
    GET_QUEST      = "Getting Quest",
    FIND_TARGET    = "Finding Target",
    TRAVEL         = "Traveling",
    POSITION       = "Positioning",
    FARMING        = "Farming",
    TARGET_DEAD    = "Target Dead",
    QUEST_COMPLETE = "Quest Complete",
    CHANGE_AREA    = "Area Changed",
    MASTERY_FARM   = "Mastery Farm",
    BOSS_FARM      = "Boss Farm",
    ERROR_RECOVERY = "Error Recovery",
    COMPLETED      = "Completed",
    STOPPED        = "Stopped",
}

local FarmManager = {
    State          = FM_STATES.IDLE,
    Mode           = "None",
    Task           = "None",
    Quest          = "None",
    Target         = "None",
    Area           = "None",
    Level          = 0,
    Sea            = 1,
    Progress       = 0,
    KillCount      = 0,
    KillRequired   = 0,
    CurrentTarget  = nil,
    CurrentQuestGiver = nil,
    LastError      = "",
    LoopRunning    = false,
    Generation     = 0,
}
_G.FarmManager = FarmManager

local function DebugLog(sys, msg)
    if Configs.Debug then warn(("[AKAT][%s] %s"):format(sys, tostring(msg))) end
end

-- ==================== UTILIDADES DO PERSONAGEM ====================
local function GetCharacter() return player.Character end
local function GetRoot()
    local c = GetCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHumanoid()
    local c = GetCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function IsAlive()
    local h = GetHumanoid()
    return h ~= nil and h.Health > 0
end

local function GetLevel()
    local ok, lv = pcall(function()
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local l = ls:FindFirstChild("Level") or ls:FindFirstChild("Lv")
            if l then return l.Value end
        end
        local pd = player:FindFirstChild("PlayerData") or player:FindFirstChild("Data")
        if pd then
            local l = pd:FindFirstChild("Level") or pd:FindFirstChild("Lv")
            if l then return l.Value end
        end
        return 0
    end)
    return ok and lv or 0
end

local function GetSea()
    local lv = GetLevel()
    if lv >= 1500 then return 3
    elseif lv >= 700 then return 2
    else return 1 end
end

local function GetStatPoints()
    local ok, pts = pcall(function()
        local containers = {player:FindFirstChild("leaderstats"), player:FindFirstChild("Data"), player:FindFirstChild("PlayerData")}
        for _, container in ipairs(containers) do
            if container then
                local sp = container:FindFirstChild("StatPoints") or container:FindFirstChild("Stat Points") or container:FindFirstChild("Points")
                if sp and (sp:IsA("IntValue") or sp:IsA("NumberValue")) then return sp.Value end
            end
        end
        local attrs = {player:GetAttribute("StatPoints"), player:GetAttribute("Stat Points"), player:GetAttribute("Points")}
        for _, value in ipairs(attrs) do if type(value) == "number" then return value end end
        return 0
    end)
    return ok and pts or 0
end

local function GetMastery(itemType)
    local ok, m = pcall(function()
        local char = GetCharacter()
        local bp = player:FindFirstChildOfClass("Backpack")
        local requested = NormalizeMasteryType(itemType)
        local function readTool(tool)
            if not tool or not tool:IsA("Tool") then return nil end
            local n = tool.Name:lower()
            local tip = tostring(tool.ToolTip or ""):lower()
            if requested == "Sword" and not (tip == "sword" or n:find("sword", 1, true)) then return nil end
            if requested == "Gun" and not (tip == "gun" or n:find("gun", 1, true)) then return nil end
            if requested == "BloxFruit" and not (tip:find("blox", 1, true) or tip:find("fruit", 1, true) or n:find("fruit", 1, true)) then return nil end
            if requested == "FightingStyle" and not (tip == "melee" or n:find("fighting", 1, true) or n:find("combat", 1, true)) then return nil end
            local v = tool:GetAttribute("Mastery") or tool:GetAttribute("MasteryLevel") or tool:GetAttribute("Level")
            return type(v) == "number" and v or nil
        end
        for _, container in ipairs({char, bp}) do
            if container then
                for _, obj in ipairs(container:GetChildren()) do
                    local value = readTool(obj)
                    if value ~= nil then return value end
                end
            end
        end
        return 0
    end)
    return ok and m or 0
end

local function GetMaterialCount(materialName)
    local ok, count = pcall(function()
        local name = NormalizeMaterial(materialName)
        if name == "Any" then return 0 end
        local inv = player:FindFirstChild("Inventory")
        if inv then
            local mat = inv:FindFirstChild(name, true)
            if mat then
                if mat:IsA("IntValue") or mat:IsA("NumberValue") then return mat.Value end
                local attr = mat:GetAttribute("Amount") or mat:GetAttribute("Count")
                if type(attr) == "number" then return attr end
            end
        end
        local attr = player:GetAttribute(name) or player:GetAttribute(name:gsub("%s+", ""))
        return type(attr) == "number" and attr or 0
    end)
    return ok and count or 0
end

-- ==================== TABELA DE ÁREAS ====================
local SEA1_AREAS = {
    {minLv=1,   maxLv=14,   area="Middle Town",      npcName="Bandit",         killReq=8 },
    {minLv=15,  maxLv=29,   area="Jungle",           npcName="Monkey",         killReq=8 },
    {minLv=30,  maxLv=59,   area="Pirate Village",   npcName="Pirate",         killReq=8 },
    {minLv=60,  maxLv=89,   area="Desert",           npcName="Desert Bandit",  killReq=8 },
    {minLv=90,  maxLv=119,  area="Frozen Village",   npcName="Snow Bandit",    killReq=8 },
    {minLv=120, maxLv=174,  area="Marine Fortress",  npcName="Marine",         killReq=10},
    {minLv=175, maxLv=299,  area="Skylands",         npcName="Sky Bandit",     killReq=10},
    {minLv=300, maxLv=374,  area="Prison",           npcName="Prisoner",       killReq=10},
    {minLv=375, maxLv=449,  area="Colosseum",        npcName="Gladiator",      killReq=10},
    {minLv=450, maxLv=524,  area="Magma Village",    npcName="Magma Ninja",    killReq=10},
    {minLv=525, maxLv=624,  area="Underwater City",  npcName="Dragon Crew",    killReq=10},
    {minLv=625, maxLv=699,  area="Fountain City",    npcName="Dark Master",    killReq=10},
}
local SEA2_AREAS = {
    {minLv=700,  maxLv=774,  area="Kingdom of Rose",  npcName="Galley Pirate",   killReq=8 },
    {minLv=775,  maxLv=874,  area="Green Zone",       npcName="Factory Bandit",  killReq=8 },
    {minLv=875,  maxLv=924,  area="Graveyard",        npcName="Possessed Mummy", killReq=8 },
    {minLv=925,  maxLv=999,  area="Snow Mountain",    npcName="Snowman",         killReq=8 },
    {minLv=1000, maxLv=1049, area="Hot & Cold",       npcName="Ice Demon",       killReq=10},
    {minLv=1050, maxLv=1174, area="Cursed Ship",      npcName="Ship Deckhand",   killReq=10},
    {minLv=1175, maxLv=1274, area="Ice Castle",       npcName="Ice Admiral",     killReq=10},
    {minLv=1275, maxLv=1374, area="Forgotten Island", npcName="Demonic Soul",    killReq=10},
    {minLv=1375, maxLv=1499, area="Flamingo",         npcName="Drug Barto",      killReq=10},
}
local SEA3_AREAS = {
    {minLv=1500, maxLv=1574, area="Port Town",        npcName="Stone",           killReq=8 },
    {minLv=1575, maxLv=1649, area="Hydra Island",     npcName="Sea Soldier",     killReq=8 },
    {minLv=1650, maxLv=1749, area="Great Tree",       npcName="Forest Pirate",   killReq=8 },
    {minLv=1750, maxLv=1874, area="Floating Turtle",  npcName="Fishman Raider",  killReq=10},
    {minLv=1875, maxLv=1999, area="Haunted Castle",   npcName="Demonic Ghoul",   killReq=10},
    {minLv=2000, maxLv=2074, area="Sea of Treats",    npcName="Sweet Thief",     killReq=10},
    {minLv=2075, maxLv=2249, area="Cake Island",      npcName="Cake Guard",      killReq=10},
    {minLv=2250, maxLv=2449, area="Candy Island",     npcName="Cocoa Warrior",   killReq=10},
    {minLv=2450, maxLv=9999, area="Ice Cream Island", npcName="Ice Cream Angel", killReq=10},
}

local function GetAreaData(level)
    local function search(t)
        for _, d in ipairs(t) do if level >= d.minLv and level <= d.maxLv then return d end end
    end
    local sea = GetSea()
    return sea == 3 and search(SEA3_AREAS) or sea == 2 and search(SEA2_AREAS) or search(SEA1_AREAS)
end

-- ==================== SISTEMA DE TARGET ====================
local function IsValidNPC(model)
    if not model or not model.Parent then return false end
    if not model:IsA("Model") then return false end
    local hum  = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if not model:FindFirstChild("HumanoidRootPart") then return false end
    return true
end

local function FindBestNPC(npcName, maxDistance)
    local root = GetRoot()
    if not root then return nil end
    maxDistance = maxDistance or 800

    local folders = {}
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then table.insert(folders, enemies) end
    table.insert(folders, workspace) -- fallback for revisions that do not expose workspace.Enemies

    local best, bestDist = nil, math.huge
    local seen = {}
    local wanted = tostring(npcName or "Any"):lower()

    for _, folder in ipairs(folders) do
        for _, model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") and not seen[model] then
                seen[model] = true
                local nameMatch = (wanted == "any") or model.Name:lower():find(wanted, 1, true) ~= nil
                if nameMatch and IsValidNPC(model) then
                    local r = model:FindFirstChild("HumanoidRootPart")
                    if r then
                        local dist = (root.Position - r.Position).Magnitude
                        if dist < bestDist and dist <= maxDistance then
                            bestDist = dist
                            best = model
                        end
                    end
                end
            end
        end
    end
    return best
end

local function SelectNextTarget(npcName)
    local npc = FindBestNPC(npcName)
    if npc then
        FarmManager.CurrentTarget = npc
        FarmManager.Target        = npc.Name
        DebugLog("Target", "Novo alvo: " .. npc.Name)
        return npc
    end
    FarmManager.CurrentTarget = nil
    FarmManager.Target        = "None"
    return nil
end

-- ==================== SISTEMA DE QUEST ====================
local function FindQuestGiver(npcName)
    local myRoot = GetRoot()
    if not myRoot then return nil end
    local wanted = tostring(npcName or ""):lower()
    local best, bestScore = nil, -math.huge

    local function scoreCandidate(model)
        if not model or not model:IsA("Model") then return end
        local n = model.Name:lower()
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
        if not root then return end
        local hasPrompt, hasClick = false, false
        for _, obj in ipairs(model:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then hasPrompt = true elseif obj:IsA("ClickDetector") then hasClick = true end
            if hasPrompt and hasClick then break end
        end
        local hasQuestWord = n:find("quest", 1, true) ~= nil
        local hasNpcName = wanted ~= "" and n:find(wanted, 1, true) ~= nil
        if not hasQuestWord and not (hasNpcName and (hasPrompt or hasClick)) then return end
        local dist = (myRoot.Position - root.Position).Magnitude
        local score = 0
        if hasQuestWord then score += 100000 end
        if hasNpcName then score += 20000 end
        if hasPrompt then score += 5000 end
        if hasClick then score += 2500 end
        score -= dist
        if score > bestScore then best, bestScore = model, score end
    end

    local enemies = workspace:FindFirstChild("Enemies")
    for _, model in ipairs(workspace:GetDescendants()) do scoreCandidate(model) end
    if enemies then
        for _, model in ipairs(enemies:GetChildren()) do
            -- Never prefer a combat NPC over a real quest giver.
            if model:IsA("Model") and model.Name:lower():find("quest", 1, true) then scoreCandidate(model) end
        end
    end
    return best
end

local function HasActiveQuest()
    local ok, result = pcall(function()
        local gui = player:FindFirstChild("PlayerGui")
        local main = gui and gui:FindFirstChild("Main")
        local quest = main and main:FindFirstChild("Quest")
        if quest and quest.Visible then return true end
        if gui then
            local qFrame = gui:FindFirstChild("QuestFrame", true)
            if qFrame and qFrame.Visible then return true end
        end
        local v = player:GetAttribute("HasQuest") or player:GetAttribute("QuestActive")
        return v == true
    end)
    return ok and result or false
end

local function AcceptQuest(questGiver)
    if not questGiver or not GetRoot() then return false end
    local qRoot = questGiver:FindFirstChild("HumanoidRootPart") or questGiver:FindFirstChild("Head")
    if not qRoot then return false end
    local myRoot = GetRoot()
    pcall(function() myRoot.CFrame = CFrame.new(qRoot.Position + Vector3.new(0, 2, 4)) end)
    task.wait(0.25)
    local interacted = false
    for _, obj in ipairs(questGiver:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            pcall(function() fireproximityprompt(obj) end); interacted = true; break
        elseif obj:IsA("ClickDetector") then
            pcall(function() fireclickdetector(obj) end); interacted = true; break
        end
    end
    if not interacted then
        pcall(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local commF = remotes and remotes:FindFirstChild("CommF_")
            local areaData = GetAreaData(FarmManager.Level)
            if commF and areaData and commF:IsA("RemoteFunction") then
                -- The quest giver name is retained as the primary locator; StartQuest is a fallback only.
                local questName = areaData.questName or tostring(areaData.area):gsub("[%s%-]", "") .. "Quest"
                commF:InvokeServer("StartQuest", questName, areaData.questIndex or 1)
                interacted = true
            end
        end)
    end
    task.wait(0.35)
    return HasActiveQuest() or interacted
end

local function IsQuestComplete()
    return FarmManager.KillRequired > 0 and FarmManager.KillCount >= FarmManager.KillRequired
end

-- ==================== POSICIONAMENTO ====================
local function GetPositionRelativeToNPC(npcRoot)
    local base = npcRoot.Position
    local h    = math.clamp(tonumber(Configs.FarmHeightValue) or 8, 5, 40)
    local mode = NormalizeFarmPosition(Configs.FarmPosition)
    if mode == "Behind" then
        return CFrame.new(base - npcRoot.CFrame.LookVector * 4 + Vector3.new(0, 3, 0))
    elseif mode == "Front" then
        return CFrame.new(base + npcRoot.CFrame.LookVector * 4 + Vector3.new(0, 3, 0))
    elseif mode == "Near" then
        return CFrame.new(base + Vector3.new(3, 3, 0))
    else
        return CFrame.new(base + Vector3.new(0, h, 0))
    end
end

local function MaintainPositionAboveNPC(force)
    local target = FarmManager.CurrentTarget
    if not IsValidNPC(target) then return false end

    local npcRoot = target:FindFirstChild("HumanoidRootPart")
    local myRoot = GetRoot()
    if not npcRoot or not myRoot then return false end

    local targetCF = GetPositionRelativeToNPC(npcRoot)
    local distance = (myRoot.Position - targetCF.Position).Magnitude
    local threshold = force and 0 or 6

    if distance > threshold then
        pcall(function()
            myRoot.Anchored = false
            myRoot.CFrame = targetCF
            myRoot.AssemblyLinearVelocity = Vector3.zero
            myRoot.AssemblyAngularVelocity = Vector3.zero
        end)
    else
        pcall(function()
            myRoot.AssemblyLinearVelocity = Vector3.zero
            myRoot.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    return true
end
local function TravelToPosition(targetCF, label)
    local root = GetRoot()
    if not root then return false end
    pcall(function() root.Anchored = false end)
    FarmManager.Task = "Traveling" .. (label and (" to " .. label) or "")
    local ok = pcall(function()
        root.CFrame = targetCF
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    task.wait(0.20)
    return ok
end

-- ==================== FIGHTING STYLE ====================
local function FindToolMatchingStyle(char, bp, requested)
    requested = tostring(requested or "Current"):lower()
    local candidates = {}
    local function inspect(container)
        if not container then return end
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                local tip = tostring(tool.ToolTip or ""):lower()
                if requested == "melee" then
                    if tip == "melee" or n:find("fighting", 1, true) or n:find("combat", 1, true) then
                        table.insert(candidates, tool)
                    end
                elseif n:find(requested, 1, true) then
                    table.insert(candidates, tool)
                end
            end
        end
    end
    inspect(char); inspect(bp)
    return candidates[1]
end

local function EquipFightingStyle()
    local requested = tostring(Configs.FightingStyle or "Current")
    if requested == "Current" then
        return GetCharacter() and GetCharacter():FindFirstChildOfClass("Tool") ~= nil
    end
    local char = GetCharacter()
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local bp   = player:FindFirstChildOfClass("Backpack")
    if not char or not hum then return false end
    local tool = FindToolMatchingStyle(char, bp, requested)
    if not tool then return false end
    if tool.Parent ~= char then
        pcall(function() hum:EquipTool(tool) end)
    end
    return true
end

-- ==================== KILL AURA / COMBAT ====================
local function GetCombatRemotes()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    local net = modules and modules:FindFirstChild("Net")
    if not net then return nil, nil end
    local registerAttack = net:FindFirstChild("RE/RegisterAttack")
    local registerHit    = net:FindFirstChild("RE/RegisterHit")
    if not registerAttack or not registerHit then return nil, nil end
    return registerAttack, registerHit
end

local function ExecuteKillAura()
    local target = FarmManager.CurrentTarget
    if not IsValidNPC(target) then return false end

    local char = GetCharacter()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    local npcHum = target:FindFirstChildOfClass("Humanoid")
    local npcRoot = target:FindFirstChild("HumanoidRootPart")

    if not char or not hum or not myRoot or not npcHum or not npcRoot then return false end
    if npcHum.Health <= 0 then return false end

    local tool = char:FindFirstChildOfClass("Tool")
    local handle = tool and (tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart"))

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local commF = remotes and remotes:FindFirstChild("CommF_")

    if commF and commF:IsA("RemoteFunction") then
        local ok = pcall(function()
            commF:InvokeServer("DoDamage", {
                Target = npcRoot,
                Humanoid = npcHum,
                Damage = 1,
            })
        end)

        if not ok then
            pcall(function()
                commF:InvokeServer("Combat", npcRoot, npcHum)
            end)
        end
    end

    if remotes then
        local hitEvents = {
            remotes:FindFirstChild("RE/Attacked"),
            remotes:FindFirstChild("RE/DoDamage"),
            remotes:FindFirstChild("RE/Combat"),
            remotes:FindFirstChild("HitEvent"),
            remotes:FindFirstChild("Combat"),
        }

        for _, ev in ipairs(hitEvents) do
            if ev and ev:IsA("RemoteEvent") then
                pcall(function()
                    ev:FireServer(npcRoot, npcHum, 1)
                end)
            end
        end
    end

    if tool then
        pcall(function()
            tool:Activate()
        end)

        if handle and typeof(firetouchinterest) == "function" then
            pcall(function()
                firetouchinterest(handle, npcRoot, 0)
                firetouchinterest(handle, npcRoot, 1)
            end)
        end
    end

    pcall(function()
        myRoot.CFrame = CFrame.new(
            myRoot.Position,
            Vector3.new(npcRoot.Position.X, myRoot.Position.Y, npcRoot.Position.Z)
        )
    end)

    return true
end
local function DistributeStats()
    if not Configs.AutoStats then return end
    local pts = GetStatPoints()
    if pts <= 0 then return end

    local priority = {NormalizeStat(Configs.PrimaryStat), NormalizeStat(Configs.SecondaryStat), NormalizeStat(Configs.TertiaryStat)}
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local commF = remotes and remotes:FindFirstChild("CommF_")

    if commF and commF:IsA("RemoteFunction") then
        pcall(function()
            for i = 1, pts do
                local stat = priority[(i - 1) % #priority + 1]
                commF:InvokeServer("AddPoint", stat, 1)
                task.wait(0.06)
            end
        end)
        return
    end

    pcall(function()
        local re = ReplicatedStorage:FindFirstChild("Remotes", true)
        if not re then return end
        local ev = re:FindFirstChild("StatUpdate") or re:FindFirstChild("AddStat") or re:FindFirstChild("DistributeStat")
        if not ev then return end
        for i = 1, pts do
            local stat = priority[(i - 1) % #priority + 1]
            if ev:IsA("RemoteEvent") then ev:FireServer(stat)
            elseif ev:IsA("RemoteFunction") then ev:InvokeServer(stat) end
            task.wait(0.1)
        end
    end)
end

-- ==================== BOSS DETECTION ====================
local function FindBoss(bossName)
    local myChar = player.Character
    local wantedName = tostring(bossName or "Any"):lower()
    local searchFolders = {}
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then table.insert(searchFolders, enemies) end
    table.insert(searchFolders, workspace)

    local best, bestHP = nil, 0
    local seen = {}

    for _, folder in ipairs(searchFolders) do
        local children = (folder == workspace) and workspace:GetChildren() or folder:GetChildren()
        for _, model in ipairs(children) do
            if model:IsA("Model") and not seen[model] then
                seen[model] = true
                if model == myChar then continue end

                local isPlayer = false
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character == model then isPlayer = true; break end
                end
                if isPlayer then continue end

                local modelNameLower = model.Name:lower()
                local nameMatch = (wantedName == "any") or modelNameLower:find(wantedName, 1, true)
                if not nameMatch then continue end

                local hum = model:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then continue end
                if not model:FindFirstChild("HumanoidRootPart") then continue end

                local isBoss = hum.MaxHealth >= 5000
                if not isBoss then
                    isBoss = model:GetAttribute("IsBoss") == true
                        or model:FindFirstChild("BossHealthBar") ~= nil
                        or model:FindFirstChild("Boss") ~= nil
                end
                if not isBoss then continue end

                if hum.Health > bestHP then
                    bestHP = hum.Health
                    best = model
                end
            end
        end
    end
    return best
end
-- ==================== STOP FARM ====================
local function UpdateFarmStatus()
    _G.AkatFarmStatus = {
        State         = FarmManager.State,
        CurrentTask   = FarmManager.Task,
        CurrentTarget = FarmManager.Target,
        CurrentQuest  = FarmManager.Quest,
        CurrentArea   = FarmManager.Area,
        Level         = FarmManager.Level,
        Progress      = FarmManager.Progress,
    }
end

local function StopFarm()
    FarmManager.Generation += 1
    FarmManager.State       = FM_STATES.STOPPED
    FarmManager.CurrentTarget = nil
    FarmManager.LoopRunning = false
    pcall(function()
        local char = GetCharacter()
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then root.Anchored = false; root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero end
    end)
    UpdateFarmStatus()
end

-- ==================== FARM LOOP: MÁQUINA DE ESTADOS ====================
local function FarmLoop(generation)
    while scriptAlive and IsAnyFarmModeEnabled() and FarmManager.Generation == generation do
        local state = FarmManager.State

        if state == FM_STATES.IDLE or state == FM_STATES.STOPPED then
            FarmManager.State = FM_STATES.INIT
            task.wait(0.3)

        elseif state == FM_STATES.INIT then
            FarmManager.State = FM_STATES.CHECK_CHAR
            task.wait(0.2)

        elseif state == FM_STATES.CHECK_CHAR then
            if not GetCharacter() or not IsAlive() then
                FarmManager.Task = "Waiting respawn..."
                UpdateFarmStatus()
                task.wait(2)
            else
                FarmManager.State = FM_STATES.CHECK_LEVEL
            end

        elseif state == FM_STATES.CHECK_LEVEL then
            local lv  = GetLevel()
            FarmManager.Level = lv
            FarmManager.Sea   = GetSea()
            local areaData = GetAreaData(lv)
            if areaData then
                FarmManager.Area         = areaData.area
                FarmManager.KillRequired = areaData.killReq
            else
                FarmManager.Area         = "Unknown"
                FarmManager.KillRequired = 10
            end
            if    Configs.AutoBoss     then FarmManager.Mode = "Boss";     FarmManager.State = FM_STATES.BOSS_FARM
            elseif Configs.AutoMastery then FarmManager.Mode = "Mastery";  FarmManager.State = FM_STATES.MASTERY_FARM
            else                             FarmManager.Mode = "Level";   FarmManager.State = FM_STATES.FIND_QUEST
            end
            EquipFightingStyle()
            UpdateFarmStatus()
            task.wait(0.2)

        elseif state == FM_STATES.FIND_QUEST then
            if HasActiveQuest() then
                FarmManager.State = FM_STATES.FIND_TARGET
            else
                local areaData = GetAreaData(FarmManager.Level)
                if areaData then
                    FarmManager.Quest = areaData.npcName
                    FarmManager.State = FM_STATES.GET_QUEST
                else
                    FarmManager.State = FM_STATES.ERROR_RECOVERY
                    FarmManager.LastError = "No area data"
                end
            end
            UpdateFarmStatus()

        elseif state == FM_STATES.GET_QUEST then
            FarmManager.KillCount = 0
            local areaData = GetAreaData(FarmManager.Level)
            if areaData then
                local qg = FindQuestGiver(areaData.npcName)
                if qg then
                    FarmManager.CurrentQuestGiver = qg
                    local qRoot = qg:FindFirstChild("HumanoidRootPart") or qg:FindFirstChild("Head")
                    if qRoot then TravelToPosition(CFrame.new(qRoot.Position + Vector3.new(0, 2, 4)), "Quest Giver") end
                    AcceptQuest(qg)
                    task.wait(0.5)
                end
            end
            FarmManager.State = FM_STATES.FIND_TARGET
            UpdateFarmStatus()

        elseif state == FM_STATES.FIND_TARGET then
            local areaData = GetAreaData(FarmManager.Level)
            local npcName  = areaData and areaData.npcName or "Any"
            local npc      = SelectNextTarget(npcName)
            if npc then
                FarmManager.State = FM_STATES.TRAVEL
            else
                task.wait(0.8)
                npc = SelectNextTarget(npcName)
                if not npc then
                    FarmManager.LastError = "No NPC found"
                    FarmManager.State     = FM_STATES.ERROR_RECOVERY
                end
            end
            UpdateFarmStatus()

        elseif state == FM_STATES.TRAVEL then
            if not IsValidNPC(FarmManager.CurrentTarget) then
                FarmManager.State = FM_STATES.FIND_TARGET
            else
                local npcRoot = FarmManager.CurrentTarget:FindFirstChild("HumanoidRootPart")
                if npcRoot then
                    TravelToPosition(GetPositionRelativeToNPC(npcRoot), FarmManager.CurrentTarget.Name)
                    FarmManager.State = FM_STATES.FARMING
                else
                    FarmManager.State = FM_STATES.FIND_TARGET
                end
            end
            UpdateFarmStatus()

        elseif state == FM_STATES.FARMING then
            local target = FarmManager.CurrentTarget
            if not IsValidNPC(target) then
                FarmManager.KillCount += 1
                FarmManager.Progress = math.floor((FarmManager.KillCount / math.max(1, FarmManager.KillRequired)) * 100)
                FarmManager.State = FM_STATES.TARGET_DEAD
            else
                -- Auto Quest/Auto Level/Combat are intentionally part of Auto Farm now.
                if not HasActiveQuest() then
                    pcall(function() local r = GetRoot(); if r then r.Anchored = false end end)
                    FarmManager.State = FM_STATES.FIND_QUEST
                else
                    EquipFightingStyle()
                    MaintainPositionAboveNPC(false)
                    ExecuteKillAura()

                    local newLv = GetLevel()
                    if newLv ~= FarmManager.Level then
                        FarmManager.Level = newLv
                        local newArea = GetAreaData(newLv)
                        if not newArea or newArea.area ~= FarmManager.Area then
                            FarmManager.CurrentTarget = nil
                            FarmManager.State = FM_STATES.CHECK_LEVEL
                        end
                    end
                    DistributeStats()
                end
            end
            UpdateFarmStatus()
            task.wait(0.10)

        elseif state == FM_STATES.TARGET_DEAD then
            pcall(function() local r = GetRoot(); if r then r.Anchored = false end end)
            FarmManager.CurrentTarget = nil
            FarmManager.Target        = "None"
            FarmManager.State = IsQuestComplete() and FM_STATES.QUEST_COMPLETE or FM_STATES.FIND_TARGET
            UpdateFarmStatus()

        elseif state == FM_STATES.QUEST_COMPLETE then
            FarmManager.Task = "Quest Complete!"
            UpdateFarmStatus()
            if FarmManager.CurrentQuestGiver then
                local qg = FarmManager.CurrentQuestGiver
                local qRoot = qg:FindFirstChild("HumanoidRootPart") or qg:FindFirstChild("Head")
                if qRoot and qRoot.Parent then
                    TravelToPosition(CFrame.new(qRoot.Position + Vector3.new(0, 2, 4)), "Quest Giver")
                    task.wait(0.5)
                    AcceptQuest(qg)
                    task.wait(0.5)
                end
            end
            FarmManager.KillCount = 0
            FarmManager.Progress  = 0
            FarmManager.State     = FM_STATES.FIND_QUEST
            UpdateFarmStatus()

        elseif state == FM_STATES.CHANGE_AREA then
            pcall(function() local r = GetRoot(); if r then r.Anchored = false end end)
            FarmManager.CurrentTarget = nil
            FarmManager.KillCount     = 0
            FarmManager.Progress      = 0
            FarmManager.Task          = "Mudando de área..."
            UpdateFarmStatus()
            task.wait(0.5)
            FarmManager.State = FM_STATES.CHECK_LEVEL

        elseif state == FM_STATES.MASTERY_FARM then
            local masteryType = NormalizeMasteryType(Configs.MasteryType)
            local current     = GetMastery(masteryType)
            local target      = Configs.TargetMastery or 300
            FarmManager.Task     = ("Mastery %s: %d/%d"):format(masteryType, current, target)
            FarmManager.Progress = math.floor((current / math.max(1, target)) * 100)
            if current >= target then
                FarmManager.Task    = "Mastery Complete!"
                Configs.AutoMastery = false
                FarmManager.State   = FM_STATES.COMPLETED
            else
                local areaData = GetAreaData(FarmManager.Level)
                local npcName  = areaData and areaData.npcName or "Any"
                if not IsValidNPC(FarmManager.CurrentTarget) then SelectNextTarget(npcName) end
                if FarmManager.CurrentTarget then MaintainPositionAboveNPC(false); ExecuteKillAura()
                else task.wait(0.5) end
            end
            UpdateFarmStatus()
            task.wait(0.10)

        elseif state == FM_STATES.BOSS_FARM then
            local bossName = NormalizeBossName(Configs.BossName or "Any")
            if NormalizeBossMode(Configs.BossSelection) == "Available" then bossName = "Any" end
            local boss = FindBoss(bossName)
            if boss then
                FarmManager.CurrentTarget = boss
                FarmManager.Target        = boss.Name
                FarmManager.Task          = "Boss: " .. boss.Name
                local bossHum = boss:FindFirstChildOfClass("Humanoid")
                if bossHum then
                    FarmManager.Progress = math.floor(((bossHum.MaxHealth - bossHum.Health) / math.max(1, bossHum.MaxHealth)) * 100)
                end
                MaintainPositionAboveNPC(false)
                ExecuteKillAura()
                if not IsValidNPC(boss) then
                    FarmManager.Task  = "Boss Defeated!"
                    FarmManager.CurrentTarget = nil
                    UpdateFarmStatus()
                    task.wait(2)
                end
            else
                FarmManager.Task = "Procurando boss: " .. bossName
                task.wait(1)
            end
            UpdateFarmStatus()
            task.wait(0.10)
        elseif state == FM_STATES.ERROR_RECOVERY then
            FarmManager.Task = "Recovering: " .. FarmManager.LastError
            UpdateFarmStatus()
            task.wait(2)
            if IsAlive() then FarmManager.State = FM_STATES.CHECK_LEVEL end

        elseif state == FM_STATES.COMPLETED then
            UpdateFarmStatus()
            if IsAnyFarmModeEnabled() then
                FarmManager.State    = FM_STATES.CHECK_LEVEL
                FarmManager.Progress = 0
                task.wait(0.15)
            else
                FarmManager.LoopRunning = false
                break
            end

        else
            task.wait(0.2)
        end

        task.wait(0)
    end

    if FarmManager.Generation == generation and not IsAnyFarmModeEnabled() then
        StopFarm()
    end
end

-- ==================== INICIAR FARM LOOP ====================
local function EnsureFarmLoop()
    if not IsAnyFarmModeEnabled() then StopFarm(); return end
    if not FarmManager.LoopRunning then
        FarmManager.LoopRunning = true
        FarmManager.Generation += 1
        FarmManager.State = FM_STATES.IDLE
        local gen = FarmManager.Generation
        task.spawn(function()
            local ok, err = pcall(FarmLoop, gen)
            if not ok then
                FarmManager.LoopRunning = false
                FarmManager.LastError   = tostring(err)
                FarmManager.State       = FM_STATES.ERROR_RECOVERY
                DebugLog("Farm", "Loop error: " .. tostring(err))
            end
        end)
    else
        FarmManager.State = FM_STATES.CHECK_LEVEL
        UpdateFarmStatus()
    end
end

local function SetFarmModeState()
    if IsAnyFarmModeEnabled() then EnsureFarmLoop()
    elseif FarmManager.LoopRunning then StopFarm() end
end

-- ==================== NOCLIP (Stepped) ====================
RunService.Stepped:Connect(function()
    if not scriptAlive then return end
    if IsAnyFarmModeEnabled() then
        local char = GetCharacter()
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)

-- ==================== THREADS SECUNDÁRIAS ====================
player.CharacterAdded:Connect(function()
    if IsAnyFarmModeEnabled() then
        FarmManager.CurrentTarget = nil
        FarmManager.State         = FM_STATES.CHECK_CHAR
        task.wait(1.5)
        if IsAnyFarmModeEnabled() and IsAlive() then FarmManager.State = FM_STATES.INIT end
    end
end)

-- ==================== SHUTDOWN ====================
_G.AkatCallbacks = _G.AkatCallbacks or {}

local function LimparEDesligar()
    scriptAlive = false
    StopFarm()
    for k, v in pairs(Configs) do if type(v) == "boolean" then Configs[k] = false end end
    pcall(function()
        local char = GetCharacter()
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if root then root.Anchored = false; root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero end
    end)
    _G.AkatBFLogicRunning = false
end

_G.AkatUIShutdown = function()
    for key, data in pairs(floatingButtons) do
        if data and data.root then pcall(function() data.root:Destroy() end) end
        floatingButtons[key] = nil
    end
    pcall(function() if screenGui and screenGui.Parent then screenGui:Destroy() end end)
end

-- ==================== CALLBACKS ====================
_G.AkatCallbacks.AutoFarm      = function(v) Configs.AutoFarm = v == true; SetFarmModeState() end
_G.AkatCallbacks.FightingStyle = function(v) Configs.FightingStyle = tostring(v); EquipFightingStyle() end
_G.AkatCallbacks.FarmPosition  = function(v) Configs.FarmPosition = tostring(v) end
_G.AkatCallbacks.FarmHeight    = function(v) Configs.FarmHeightValue = math.clamp(tonumber(v) or 8, 5, 40) end
_G.AkatCallbacks.AutoMastery   = function(v) Configs.AutoMastery = v == true; SetFarmModeState() end
_G.AkatCallbacks.MasteryType   = function(v) Configs.MasteryType = tostring(v) end
_G.AkatCallbacks.TargetMastery = function(v) Configs.TargetMastery = math.clamp(math.floor(tonumber(v) or 300), 1, 600) end
_G.AkatCallbacks.AutoBoss      = function(v) Configs.AutoBoss = v == true; SetFarmModeState() end
_G.AkatCallbacks.BossSelection = function(v) Configs.BossSelection = tostring(v); if IsAnyFarmModeEnabled() then FarmManager.State = FM_STATES.CHECK_LEVEL end end
_G.AkatCallbacks.BossName      = function(v) Configs.BossName = NormalizeBossName(v) end
_G.AkatCallbacks.BossQuest     = function(v) Configs.BossQuest = v == true end
_G.AkatCallbacks.AutoStats     = function(v) Configs.AutoStats = v == true end
_G.AkatCallbacks.PrimaryStat   = function(v) Configs.PrimaryStat = tostring(v) end
_G.AkatCallbacks.SecondaryStat = function(v) Configs.SecondaryStat = tostring(v) end
_G.AkatCallbacks.TertiaryStat  = function(v) Configs.TertiaryStat = tostring(v) end
_G.AkatCallbacks.Debug         = function(v) Configs.Debug = v == true end
_G.AkatCallbacks.ShutdownAll   = LimparEDesligar

_G.AkatBFLogicReady = true

-- ==================== ANIMAÇÃO DE INTRODUÇÃO ====================
local function ExecutarIntroAkat()
    local Blur    = Instance.new("BlurEffect", Lighting)
    Blur.Name     = "IntroBlur"
    Blur.Size     = 0

    local IntroFrame  = Instance.new("Frame", screenGui)
    IntroFrame.Size   = UDim2.new(1, 0, 1, 0)
    IntroFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    IntroFrame.BackgroundTransparency = 1
    IntroFrame.ZIndex = 500

    local MaskContainer = Instance.new("Frame", IntroFrame)
    MaskContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    MaskContainer.Position    = UDim2.new(0.5, 0, 0.5, -10)
    MaskContainer.Size        = UDim2.new(0, 420, 0, 40)
    MaskContainer.BackgroundTransparency = 1
    MaskContainer.ClipsDescendants = true
    MaskContainer.ZIndex      = 501

    local IntroText   = Instance.new("TextLabel", MaskContainer)
    IntroText.Size    = UDim2.new(1, 0, 1, 0)
    IntroText.Position = UDim2.new(0, 0, 1, 0)
    IntroText.BackgroundTransparency = 1
    IntroText.Font    = Enum.Font.GothamBold
    IntroText.TextSize = 26
    IntroText.RichText = true
    IntroText.Text    = UI_TEXT.Intro
    IntroText.ZIndex  = 502

    local IntroLine   = Instance.new("Frame", IntroFrame)
    IntroLine.AnchorPoint = Vector2.new(0.5, 0.5)
    IntroLine.Position    = UDim2.new(0.5, 0, 0.5, 16)
    IntroLine.Size        = UDim2.new(0, 0, 0, 2)
    IntroLine.BackgroundColor3 = Color3.fromHex("#8B0000")
    IntroLine.BorderSizePixel  = 0
    IntroLine.BackgroundTransparency = 1
    IntroLine.ZIndex      = 503
    Instance.new("UICorner", IntroLine).CornerRadius = UDim.new(1, 0)

    TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.05}):Play()
    TweenService:Create(Blur,       TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 24}):Play()
    task.wait(0.1)
    TweenService:Create(IntroText,  TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
    task.wait(0.2)
    TweenService:Create(IntroLine,  TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(0, 260, 0, 2)}):Play()
    task.wait(1.6)
    TweenService:Create(IntroText,  TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
    TweenService:Create(IntroLine,  TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play()
    task.wait(0.3)
    TweenService:Create(IntroFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    TweenService:Create(Blur,       TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play()
    task.wait(0.3)

    RegistrarTransparencias(mainWrapper)
    for _, item in ipairs(mainWrapper:GetDescendants()) do RegistrarTransparencias(item) end

    mainWrapper.Size    = select(1, GetResponsiveUISizes())
    mainWrapper.Visible = true
    FloatBtn.Visible    = true
    UIState             = "OPEN"
    isTransitioning     = false

    local oldScale = mainWrapper:FindFirstChild("IntroMainScale")
    if oldScale then oldScale:Destroy() end
    local MainScale   = Instance.new("UIScale", mainWrapper)
    MainScale.Name    = "IntroMainScale"
    MainScale.Scale   = 0.85
    AplicarFadeSincronizado(mainWrapper, true,  0)
    AplicarFadeSincronizado(mainWrapper, false, 0.35)

    FloatBtn.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(FloatBtn, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 44, 0, 44)}):Play()

    local openScale = TweenService:Create(MainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
    openScale:Play()

    CriarNotificacao("AKATSUKI SCRIPTS", "Bem-vindo, " .. player.DisplayName .. "! Farm iniciado.")
    task.wait(0.8)
    CriarNotificacaoDiscord()

    openScale.Completed:Connect(function()
        MainScale:Destroy()
        pcall(function() Blur:Destroy() end)
        IntroFrame:Destroy()
        task.defer(function() if screenGui and screenGui.Parent then selectTab("Farm") end end)
    end)
end

ExecutarIntroAkat()
