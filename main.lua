-- [[
--     AKAT | JULES RNG (THE MINE) - DARK RED EDITION
--     Otimizado para Delta Mobile 2026 (Premium UI Sync & Frame Clipping)
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- ==================== CONFIGURAÇÕES GERAIS ====================
local flags = {
    ESP = false,
    InstantMine = false,
    Speed = false
}

local SPEED_MULTIPLIER = 32
local DEFAULT_SPEED = 16

-- Dimensões da UI
local UI_WIDTH = 370
local HEADER_HEIGHT = 42
local UI_HEIGHT = 200

-- Cores do Tema Premium
local DARK_RED = Color3.fromRGB(139, 0, 0)
local ALMOST_BLACK = Color3.fromRGB(8, 8, 8)

-- Configurações do X-Ray V2
local MAX_DISTANCE = 180          
local MAX_HIGHLIGHTS = 45         
local UPDATE_INTERVAL = 0.65      
local espCache = {}

local RARITY_PRIORITY = {
    ["diamond"] = 10,
    ["mythril"] = 9,
    ["ruby"]    = 8,
    ["emerald"] = 7,
    ["gold"]    = 6,
    ["lapis"]   = 5,
    ["iron"]    = 4,
    ["coal"]    = 3,
    ["ore"]     = 2,
    ["minerio"] = 2
}

local ORES_CONFIG = {
    ["coal"]    = {Name = "Coal",    Color = Color3.fromRGB(90, 90, 90)},
    ["iron"]    = {Name = "Iron",    Color = Color3.fromRGB(210, 210, 210)},
    ["emerald"] = {Name = "Emerald", Color = Color3.fromRGB(46, 204, 113)},
    ["ruby"]    = {Name = "Ruby",    Color = Color3.fromRGB(231, 76, 60)},
    ["diamond"] = {Name = "Diamond", Color = Color3.fromRGB(52, 152, 219)},
    ["mythril"] = {Name = "Mythril", Color = Color3.fromRGB(155, 89, 182)},
    ["lapis"]   = {Name = "Lapis",   Color = Color3.fromRGB(41, 128, 185)},
    ["gold"]    = {Name = "Gold",    Color = Color3.fromRGB(241, 196, 15)}
}

local IGNORE_KEYWORDS = {
    "stone", "pedra", "dirt", "terra", "baseplate", "grass", "rock",
    "wall", "floor", "ceiling", "part", "mesh", "handle", "tool",
    "character", "humanoid", "accessory", "hat", "hair"
}

-- ==================== GERENCIADOR DE GRADIENTES ROTATIVOS ====================
local function CriarGradienteRotativo(parent, speed, color1, color2, color3)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color1 or DARK_RED),
        ColorSequenceKeypoint.new(0.5, color2 or Color3.fromRGB(15, 15, 15)),
        ColorSequenceKeypoint.new(1, color3 or DARK_RED)
    })
    grad.Parent = parent

    TweenService:Create(grad, TweenInfo.new(speed or 3.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360}):Play()
    return grad
end

-- ==================== ANIMAÇÕES FLUIDAS ====================
local function Animar(obj, goal, time, style, dir)
    local tween = TweenService:Create(
        obj, 
        TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), 
        goal
    )
    tween:Play()
    return tween
end

local function EfeitoClique(btn)
    task.spawn(function()
        local origSize = btn:GetAttribute("OriginalSize") or btn.Size
        if not btn:GetAttribute("OriginalSize") then
            btn:SetAttribute("OriginalSize", origSize)
        end
        
        Animar(btn, {Size = UDim2.new(origSize.X.Scale, origSize.X.Offset - 2, origSize.Y.Scale, origSize.Y.Offset - 2)}, 0.05)
        task.wait(0.05)
        Animar(btn, {Size = origSize}, 0.08)
    end)
end

-- ==================== LÓGICA DO X-RAY V2 ====================
-- (Mantida perfeitamente intacta conforme script original)
local function ClearESP(obj)
    local data = espCache[obj]
    if not data then return end
    pcall(function()
        if data.Highlight and data.Highlight.Parent then data.Highlight:Destroy() end
        if data.Billboard and data.Billboard.Parent then data.Billboard:Destroy() end
    end)
    espCache[obj] = nil
end

local function ClearAllESP()
    for obj in pairs(espCache) do ClearESP(obj) end
    table.clear(espCache)
end

local function IsIgnored(name)
    name = name:lower()
    for _, keyword in ipairs(IGNORE_KEYWORDS) do
        if name:find(keyword) then return true end
    end
    return false
end

local function GetOreInfo(obj)
    if not obj or not obj.Parent then return nil end
    local name = obj.Name:lower()
    if IsIgnored(name) then return nil end

    for key, info in pairs(ORES_CONFIG) do
        if name:find(key) then return info, (RARITY_PRIORITY[key] or 1) end
    end

    if name:find("ore") or name:find("minerio") or name:find("gem") or name:find("cristal") then
        return {Name = obj.Name, Color = Color3.fromRGB(255, 200, 50)}, 2
    end
    if obj:FindFirstChildOfClass("ProximityPrompt") then
        return {Name = obj.Name, Color = Color3.fromRGB(255, 180, 0)}, 2
    end
    if obj:GetAttribute("Health") or obj:GetAttribute("HP") or obj:GetAttribute("Durability") then
        return {Name = obj.Name, Color = Color3.fromRGB(200, 200, 100)}, 1
    end
    return nil
end

local function GetTargetPart(obj)
    if obj:IsA("BasePart") then return obj
    elseif obj:IsA("Model") then return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function CreateESP(obj, oreInfo, priority)
    if espCache[obj] then return end
    local targetPart = GetTargetPart(obj)
    if not targetPart then return end

    local hl = Instance.new("Highlight", obj)
    hl.Adornee = obj
    hl.FillColor = oreInfo.Color
    hl.FillTransparency = 0.72
    hl.OutlineColor = oreInfo.Color
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    local bgui = Instance.new("BillboardGui", targetPart)
    bgui.Adornee = targetPart
    bgui.Size = UDim2.new(0, 110, 0, 28)
    bgui.StudsOffset = Vector3.new(0, 2.8, 0)
    bgui.AlwaysOnTop = true
    bgui.MaxDistance = MAX_DISTANCE + 20

    local txt = Instance.new("TextLabel", bgui)
    txt.Size = UDim2.new(1, 0, 1, 0)
    txt.BackgroundTransparency = 1
    txt.Text = oreInfo.Name
    txt.TextColor3 = oreInfo.Color
    txt.TextStrokeTransparency = 0.3
    txt.TextStrokeColor3 = Color3.new(0, 0, 0)
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 13

    espCache[obj] = { Highlight = hl, Billboard = bgui, Label = txt, Name = oreInfo.Name, Priority = priority or 1, Part = targetPart }
end

local function IsAlreadyTracked(obj)
    if espCache[obj] then return true end
    local p = obj.Parent
    while p and p ~= workspace do
        if espCache[p] then return true end
        p = p.Parent
    end
    return false
end

local function UpdateESP()
    if not flags.ESP then
        if next(espCache) then ClearAllESP() end
        return
    end

    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local myPos = root.Position
    local candidates, candidateObjs = {}, {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local isTracked = IsAlreadyTracked(obj) or candidateObjs[obj]
            if not isTracked then
                local p = obj.Parent
                while p and p ~= workspace do
                    if candidateObjs[p] then isTracked = true; break end
                    p = p.Parent
                end
            end
            if not isTracked and obj:IsA("BasePart") and obj.Parent:IsA("Model") and obj.Parent ~= workspace then
                if GetOreInfo(obj.Parent) then isTracked = true end
            end
            if not isTracked then
                local oreInfo, priority = GetOreInfo(obj)
                if oreInfo then
                    local part = GetTargetPart(obj)
                    if part then
                        local dist = (part.Position - myPos).Magnitude
                        if dist <= MAX_DISTANCE then
                            candidateObjs[obj] = true
                            table.insert(candidates, { Object = obj, Info = oreInfo, Priority = priority, Distance = dist })
                        end
                    end
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.Priority ~= b.Priority then return a.Priority > b.Priority end
        return a.Distance < b.Distance
    end)

    local created = 0
    for _, data in ipairs(candidates) do
        if created >= MAX_HIGHLIGHTS then break end
        if not espCache[data.Object] then
            CreateESP(data.Object, data.Info, data.Priority)
            created = created + 1
        end
    end

    for obj, data in pairs(espCache) do
        if not obj.Parent or not data.Part or not data.Part.Parent then
            ClearESP(obj)
        else
            local dist = (data.Part.Position - myPos).Magnitude
            if dist > MAX_DISTANCE + 15 then ClearESP(obj)
            else if data.Label then data.Label.Text = string.format("%s\n%.0fm", data.Name, dist) end end
        end
    end
end

-- ==================== CRIAÇÃO DA SCREEN GUI ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaAkatTheMineGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

local uiParent = player:WaitForChild("PlayerGui")
pcall(function() uiParent = CoreGui end)
if uiParent:FindFirstChild("DeltaAkatTheMineGui") then uiParent.DeltaAkatTheMineGui:Destroy() end
ScreenGui.Parent = uiParent

-- ==================== BOTÃO FLUTUANTE ====================
local FloatBtn = Instance.new("ImageButton", ScreenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Size = UDim2.new(0, 0, 0, 0)
FloatBtn.Position = UDim2.new(0.1, 0, 0.35, 0)
FloatBtn.Image = "rbxthumb://type=Asset&id=99997714241420&w=150&h=150"
FloatBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
FloatBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
FloatBtn.Visible = false
FloatBtn.ZIndex = 30
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)

local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Thickness = 1.4
FloatStroke.Color = DARK_RED
CriarGradienteRotativo(FloatStroke, 3)

-- ==================== JANELA PRINCIPAL (REFINAMENTO PREMIUM) ====================
local Main = Instance.new("CanvasGroup", ScreenGui)
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT) 
Main.Position = UDim2.new(0.5, 0, 0.45, 0)
Main.BackgroundTransparency = 1
Main.GroupTransparency = 1 
Main.Visible = false
Main.ClipsDescendants = true

local MainScale = Instance.new("UIScale", Main)
MainScale.Scale = 1

local MainFrame = Instance.new("Frame", Main)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(1, 0, 1, 0)
MainFrame.Position = UDim2.new(0, 0, 0, 0)
-- Fundo alterado para branco para o Gradiente de Profundidade funcionar perfeitamente
MainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255) 
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Gradiente de Fundo (Profundidade Premium)
local BgGradient = Instance.new("UIGradient", MainFrame)
BgGradient.Rotation = 90
BgGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 18)), -- Topo levemente mais claro
    ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 6, 8))     -- Base bem escura
})

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Thickness = 1.5
MainStroke.Color = DARK_RED
CriarGradienteRotativo(MainStroke, 4)

-- Cabeçalho
local Header = Instance.new("Frame", MainFrame)
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
Header.BackgroundTransparency = 1

local TitleContainer = Instance.new("Frame", Header)
TitleContainer.Size = UDim2.new(0.82, 0, 1, 0)
TitleContainer.Position = UDim2.new(0, 12, 0, 0)
TitleContainer.BackgroundTransparency = 1

-- Badge AKAT (Compacta e Elegante, Sem vermelho exagerado)
local AkatBadge = Instance.new("Frame", TitleContainer)
AkatBadge.AnchorPoint = Vector2.new(0, 0.5)
AkatBadge.Size = UDim2.new(0, 46, 0, 16) -- Altura diminuída
AkatBadge.Position = UDim2.new(0, 0, 0.5, 0)
AkatBadge.BackgroundColor3 = Color3.fromRGB(12, 12, 14) -- Predominantemente preto
AkatBadge.BorderSizePixel = 0
AkatBadge.ZIndex = 2
Instance.new("UICorner", AkatBadge).CornerRadius = UDim.new(0, 5)

local AkatBadgeStroke = Instance.new("UIStroke", AkatBadge)
AkatBadgeStroke.Thickness = 1
AkatBadgeStroke.Color = DARK_RED -- Apenas detalhe em vermelho neon
AkatBadgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local TitleAkat = Instance.new("TextLabel", AkatBadge)
TitleAkat.Size = UDim2.new(1, 0, 1, 0)
TitleAkat.Text = "AKAT"
TitleAkat.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleAkat.Font = Enum.Font.GothamBold
TitleAkat.TextSize = 10
TitleAkat.TextXAlignment = Enum.TextXAlignment.Center
TitleAkat.BackgroundTransparency = 1
TitleAkat.ZIndex = 3

-- Nome do Jogo
local TitleGame = Instance.new("TextLabel", TitleContainer)
TitleGame.AnchorPoint = Vector2.new(0, 0.5)
TitleGame.Size = UDim2.new(1, -54, 1, 0)
TitleGame.Position = UDim2.new(0, 54, 0.5, 0)
TitleGame.Text = "JULES RNG (THE MINE)"
TitleGame.TextColor3 = Color3.fromRGB(240, 240, 240)
TitleGame.Font = Enum.Font.GothamBold
TitleGame.TextSize = 11
TitleGame.TextXAlignment = Enum.TextXAlignment.Left
TitleGame.BackgroundTransparency = 1

-- Botão Minimizar (Fino, elegante e fixo no "—")
local MinimizeBtn = Instance.new("TextButton", Header)
MinimizeBtn.Size = UDim2.new(0, 26, 0, 26)
MinimizeBtn.Position = UDim2.new(1, -34, 0.5, -13)
MinimizeBtn.Text = "" -- Texto removido para usar um traço vetorial perfeito
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

-- Traço de minimizar (muito mais limpo e fino que texto)
local MinLine = Instance.new("Frame", MinimizeBtn)
MinLine.Size = UDim2.new(0, 10, 0, 1) -- Linha vetorial de 1 pixel de altura
MinLine.AnchorPoint = Vector2.new(0.5, 0.5)
MinLine.Position = UDim2.new(0.5, 0, 0.5, 0)
MinLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
MinLine.BorderSizePixel = 0

local MinStroke = Instance.new("UIStroke", MinimizeBtn)
MinStroke.Color = DARK_RED
MinStroke.Thickness = 1
CriarGradienteRotativo(MinStroke, 3)

local Separator = Instance.new("Frame", MainFrame)
Separator.Size = UDim2.new(0.94, 0, 0, 1)
Separator.Position = UDim2.new(0.03, 0, 0, HEADER_HEIGHT)
Separator.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Separator.BorderSizePixel = 0

local ContentFrame = Instance.new("Frame", MainFrame)
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + 1))
ContentFrame.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT + 1)
ContentFrame.BackgroundTransparency = 1
ContentFrame.BorderSizePixel = 0
ContentFrame.ClipsDescendants = true

-- ==================== CONSTRUTOR DE TOGGLES (REFINAMENTO PREMIUM) ====================
local function CriarToggle(yPos, texto, flagName)
    local row = Instance.new("Frame", ContentFrame)
    row.Size = UDim2.new(0.94, 0, 0, 40)
    row.Position = UDim2.new(0.03, 0, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local rowStroke = Instance.new("UIStroke", row)
    rowStroke.Color = Color3.fromRGB(30, 30, 35)
    rowStroke.Thickness = 1

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.Text = texto
    lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.BackgroundTransparency = 1

    -- Container do botão 
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 52, 0, 24)
    btn.Position = UDim2.new(1, -58, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 26) -- Fundo escuro normal (OFF)
    btn.Text = "" -- Texto tratado separadamente para fluidez
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    local btnStroke = Instance.new("UIStroke", btn)
    btnStroke.Color = Color3.fromRGB(35, 35, 40) -- Borda discreta padrão
    btnStroke.Thickness = 1

    -- Fundo Gradiente Animado (ON)
    local gradFrame = Instance.new("Frame", btn)
    gradFrame.Size = UDim2.new(1, 0, 1, 0)
    gradFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    gradFrame.BackgroundTransparency = 1 -- Invisível no estado OFF
    Instance.new("UICorner", gradFrame).CornerRadius = UDim.new(0, 5)

    -- Rotação Contínua dentro do botão
    CriarGradienteRotativo(gradFrame, 2.5, ALMOST_BLACK, DARK_RED, ALMOST_BLACK)

    -- Texto do Botão (Sobreposto para não ser afetado pelo gradiente)
    local btnText = Instance.new("TextLabel", btn)
    btnText.Size = UDim2.new(1, 0, 1, 0)
    btnText.BackgroundTransparency = 1
    btnText.Text = "OFF"
    btnText.TextColor3 = Color3.fromRGB(150, 150, 150)
    btnText.Font = Enum.Font.GothamBold -- Mesma fonte/espessura para ambos
    btnText.TextSize = 10
    btnText.ZIndex = 2

    btn.MouseButton1Click:Connect(function()
        EfeitoClique(btn)
        flags[flagName] = not flags[flagName]
        
        if flags[flagName] then
            btnText.Text = "ON"
            -- Transição fluida de cores
            Animar(btnText, {TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.2)
            Animar(gradFrame, {BackgroundTransparency = 0}, 0.2)
            Animar(btnStroke, {Color = Color3.fromRGB(80, 20, 20)}, 0.2)
        else
            btnText.Text = "OFF"
            -- Retorno fluido ao estado original
            Animar(btnText, {TextColor3 = Color3.fromRGB(150, 150, 150)}, 0.2)
            Animar(gradFrame, {BackgroundTransparency = 1}, 0.2)
            Animar(btnStroke, {Color = Color3.fromRGB(35, 35, 40)}, 0.2)
            
            if flagName == "ESP" then ClearAllESP() end
        end
    end)
end

CriarToggle(8, "X RAY MINES", "ESP")
CriarToggle(54, "INSTANT MINE", "InstantMine")
CriarToggle(100, "SPEED MOD", "Speed")

-- ==================== CONTROLES DA UI E ANIMAÇÕES DE ENTRADA/SAÍDA ====================
local menuAberto = true
local isMinimized = false
local fadeTween = nil
local resizeTween = nil
local expandedPos = Main.Position

local function ToggleMenu(open)
    menuAberto = open
    if fadeTween then fadeTween:Cancel(); fadeTween = nil end
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    if open then
        Main.Visible = true
        MainScale.Scale = 0.85
        Main.GroupTransparency = 1
        
        fadeTween = TweenService:Create(Main, tweenInfo, {GroupTransparency = 0})
        local scaleTween = TweenService:Create(MainScale, tweenInfo, {Scale = 1})
        fadeTween:Play()
        scaleTween:Play()
    else
        fadeTween = TweenService:Create(Main, tweenInfo, {GroupTransparency = 1})
        local scaleTween = TweenService:Create(MainScale, tweenInfo, {Scale = 0.85})
        
        fadeTween.Completed:Connect(function(state)
            if state == Enum.PlaybackState.Completed and not menuAberto then
                Main.Visible = false
            end
        end)
        
        fadeTween:Play()
        scaleTween:Play()
    end
end

FloatBtn.MouseButton1Click:Connect(function()
    EfeitoClique(FloatBtn)
    ToggleMenu(not menuAberto)
end)

MinimizeBtn.MouseButton1Click:Connect(function()
    EfeitoClique(MinimizeBtn)
    
    local heightDiff = UI_HEIGHT - HEADER_HEIGHT
    local targetHeight, targetPos

    if not isMinimized then
        expandedPos = Main.Position
        isMinimized = true
        -- O Texto permanece uma linha limpa. Não alteramos para "+" mais.
        targetHeight = HEADER_HEIGHT
        targetPos = UDim2.new(expandedPos.X.Scale, expandedPos.X.Offset, expandedPos.Y.Scale, expandedPos.Y.Offset - (heightDiff / 2))
    else
        isMinimized = false
        targetHeight = UI_HEIGHT
        targetPos = expandedPos
    end

    local targetSize = UDim2.new(0, UI_WIDTH, 0, targetHeight)

    if resizeTween then resizeTween:Cancel(); resizeTween = nil end

    resizeTween = TweenService:Create(Main, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = targetSize,
        Position = targetPos
    })
    resizeTween:Play()
end)

local function ConfigurarArrastar(inst)
    local drag = false
    local startPos, dragStart, dragInput
    inst.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            drag = true; dragStart = input.Position; startPos = inst.Position; dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if drag and input == dragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            inst.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            if inst == Main and not isMinimized then
                expandedPos = Main.Position
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if drag and input == dragInput then drag = false; dragInput = nil end
    end)
end

ConfigurarArrastar(Main)
ConfigurarArrastar(FloatBtn)

-- ==================== INTRODUÇÃO ====================
local function ExecutarIntro()
    local Blur = Instance.new("BlurEffect", Lighting)
    Blur.Size = 0

    local IntroFrame = Instance.new("Frame", ScreenGui)
    IntroFrame.Size = UDim2.new(1, 0, 1, 0)
    IntroFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 7)
    IntroFrame.BackgroundTransparency = 1
    IntroFrame.BorderSizePixel = 0
    IntroFrame.ZIndex = 500

    local Card = Instance.new("Frame", IntroFrame)
    Card.AnchorPoint = Vector2.new(0.5, 0.5)
    Card.Size = UDim2.new(0, 290, 0, 70)
    Card.Position = UDim2.new(0.5, 0, 0.5, 0)
    Card.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
    Card.BackgroundTransparency = 1
    Card.ZIndex = 501
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 10)

    local CardStroke = Instance.new("UIStroke", Card)
    CardStroke.Thickness = 1.5
    CardStroke.Color = DARK_RED
    CardStroke.Transparency = 1
    CriarGradienteRotativo(CardStroke, 2)

    local IntroText = Instance.new("TextLabel", Card)
    IntroText.Size = UDim2.new(1, 0, 0, 30)
    IntroText.Position = UDim2.new(0, 0, 0, 12)
    IntroText.BackgroundTransparency = 1
    IntroText.Font = Enum.Font.GothamBold
    IntroText.TextSize = 20
    IntroText.RichText = true
    IntroText.Text = '<font color="#FFFFFF">AKAT</font> <font color="#8B0000">COMMUNITY</font>'
    IntroText.TextTransparency = 1
    IntroText.ZIndex = 502

    local SubText = Instance.new("TextLabel", Card)
    SubText.Size = UDim2.new(1, 0, 0, 20)
    SubText.Position = UDim2.new(0, 0, 0, 38)
    SubText.BackgroundTransparency = 1
    SubText.Font = Enum.Font.GothamMedium
    SubText.TextSize = 11
    SubText.Text = "JULES RNG (THE MINE) • LOADING..."
    SubText.TextColor3 = Color3.fromRGB(180, 180, 180)
    SubText.TextTransparency = 1
    SubText.ZIndex = 502

    Animar(IntroFrame, {BackgroundTransparency = 0.25}, 0.3) 
    Animar(Blur, {Size = 20}, 0.3) 
    task.wait(0.12)

    Animar(Card, {BackgroundTransparency = 0.05}, 0.3)
    Animar(CardStroke, {Transparency = 0}, 0.3)
    Animar(IntroText, {TextTransparency = 0}, 0.3)
    Animar(SubText, {TextTransparency = 0}, 0.3)
    task.wait(1.5) 

    Animar(IntroText, {TextTransparency = 1}, 0.25)
    Animar(SubText, {TextTransparency = 1}, 0.25)
    Animar(Card, {BackgroundTransparency = 1}, 0.25)
    Animar(CardStroke, {Transparency = 1}, 0.25)
    Animar(IntroFrame, {BackgroundTransparency = 1}, 0.3)
    Animar(Blur, {Size = 0}, 0.3)
    task.wait(0.3)

    IntroFrame:Destroy()
    Blur:Destroy()

    FloatBtn.Visible = true
    Main.Visible = true
    Main.GroupTransparency = 1
    MainScale.Scale = 0.85

    Animar(FloatBtn, {Size = UDim2.new(0, 46, 0, 46)}, 0.2)
    Animar(Main, {GroupTransparency = 0}, 0.2)
    Animar(MainScale, {Scale = 1}, 0.2)
end

-- ==================== CHEATS AUXILIARES ====================
local function ForceBreakBlocks()
    if not flags.InstantMine then return end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then obj.HoldDuration = 0 end
        
        if obj:IsA("BasePart") or obj:IsA("Model") then
            for _, v in ipairs(obj:GetChildren()) do
                if v:IsA("NumberValue") or v:IsA("IntValue") then
                    local n = v.Name:lower()
                    if n == "health" or n == "hp" or n == "durability" or n == "maxhealth" then
                        if v.Value > 1 then v.Value = 0 end
                    end
                end
            end
            
            if obj:GetAttribute("Health") then obj:SetAttribute("Health", 0) end
            if obj:GetAttribute("HP") then obj:SetAttribute("HP", 0) end
        end
    end
end

-- ==================== LOOPS PRINCIPAIS ====================
RunService.Heartbeat:Connect(function()
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if hum then
        if flags.Speed then hum.WalkSpeed = SPEED_MULTIPLIER
        else if hum.WalkSpeed == SPEED_MULTIPLIER then hum.WalkSpeed = DEFAULT_SPEED end end
    end
    ForceBreakBlocks()
end)

task.spawn(function()
    while true do
        task.wait(UPDATE_INTERVAL)
        pcall(UpdateESP)
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if espCache[obj] then ClearESP(obj) end
end)

player.CharacterAdded:Connect(function(char)
    character = char
    ClearAllESP()
end)

-- Inicialização
task.spawn(ExecutarIntro)
