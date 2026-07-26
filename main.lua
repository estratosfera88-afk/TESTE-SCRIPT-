-- [[
--     AKAT | JULES RNG (THE MINE) - ULTRA OPTIMIZED & FIXED UI
--     Otimizado para Delta Mobile 2026
--     Funções: X-Ray V2 Corrigido, Instant Mine, Speed, UI Animada Sincronizada
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

-- Dimensões Ajustadas da UI (Sem espaço sobrando)
local UI_WIDTH = 340
local HEADER_HEIGHT = 40
local UI_HEIGHT = 188 

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

-- ==================== FUNÇÕES DE ANIMAÇÃO CORE ====================
local function Animar(obj, goal, time, style, dir)
    local tween = TweenService:Create(
        obj, 
        TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Cubic, dir or Enum.EasingDirection.Out), 
        goal
    )
    tween:Play()
    return tween
end

local function EfeitoClique(btn)
    local origSize = btn:GetAttribute("OriginalSize") or btn.Size
    if not btn:GetAttribute("OriginalSize") then
        btn:SetAttribute("OriginalSize", origSize)
    end
    
    Animar(btn, {Size = UDim2.new(origSize.X.Scale, origSize.X.Offset - 2, origSize.Y.Scale, origSize.Y.Offset - 2)}, 0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    task.wait(0.08)
    Animar(btn, {Size = origSize}, 0.15, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
end

local function CriarGradienteVermelhoEscuro(parent)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHex("#8B0000")),
        ColorSequenceKeypoint.new(0.5, Color3.fromHex("#2B0000")),
        ColorSequenceKeypoint.new(1, Color3.fromHex("#0A0A0A"))
    })
    grad.Rotation = 45
    grad.Parent = parent
    return grad
end

-- ==================== LÓGICA DO X-RAY V2 ====================
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
    for obj in pairs(espCache) do
        ClearESP(obj)
    end
    table.clear(espCache)
end

local function IsIgnored(name)
    name = name:lower()
    for _, keyword in ipairs(IGNORE_KEYWORDS) do
        if name:find(keyword) then
            return true
        end
    end
    return false
end

local function GetOreInfo(obj)
    if not obj or not obj.Parent then return nil end

    local name = obj.Name:lower()
    if IsIgnored(name) then return nil end

    for key, info in pairs(ORES_CONFIG) do
        if name:find(key) then
            return info, (RARITY_PRIORITY[key] or 1)
        end
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
    if obj:IsA("BasePart") then
        return obj
    elseif obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function CreateESP(obj, oreInfo, priority)
    if espCache[obj] then return end

    local targetPart = GetTargetPart(obj)
    if not targetPart then return end

    local hl = Instance.new("Highlight")
    hl.Adornee = obj
    hl.FillColor = oreInfo.Color
    hl.FillTransparency = 0.72
    hl.OutlineColor = oreInfo.Color
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = obj

    local bgui = Instance.new("BillboardGui")
    bgui.Adornee = targetPart
    bgui.Size = UDim2.new(0, 110, 0, 28)
    bgui.StudsOffset = Vector3.new(0, 2.8, 0)
    bgui.AlwaysOnTop = true
    bgui.MaxDistance = MAX_DISTANCE + 20
    bgui.Parent = targetPart

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, 0, 1, 0)
    txt.BackgroundTransparency = 1
    txt.Text = oreInfo.Name
    txt.TextColor3 = oreInfo.Color
    txt.TextStrokeTransparency = 0.3
    txt.TextStrokeColor3 = Color3.new(0, 0, 0)
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 13
    txt.Parent = bgui

    espCache[obj] = {
        Highlight = hl,
        Billboard = bgui,
        Label = txt,
        Name = oreInfo.Name,
        Priority = priority or 1,
        Part = targetPart
    }
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
    local candidates = {}
    local candidateObjs = {}

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
                            table.insert(candidates, {
                                Object = obj,
                                Info = oreInfo,
                                Priority = priority,
                                Distance = dist
                            })
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
            if dist > MAX_DISTANCE + 15 then
                ClearESP(obj)
            else
                if data.Label then
                    data.Label.Text = string.format("%s\n%.0fm", data.Name, dist)
                end
            end
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

-- ==================== BOTÃO FLUTUANTE (ESTILO MM2) ====================
local FloatBtn = Instance.new("ImageButton", ScreenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0.1, 0, 0.35, 0)
FloatBtn.Image = "rbxthumb://type=Asset&id=99997714241420&w=150&h=150"
FloatBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
FloatBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
FloatBtn.Visible = false
FloatBtn.ZIndex = 30
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)

local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Thickness = 1.2
FloatStroke.Color = Color3.fromHex("#8B0000")

local FloatGradient = Instance.new("UIGradient", FloatStroke)
FloatGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromHex("#8B0000")),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 15, 15)),
    ColorSequenceKeypoint.new(1, Color3.fromHex("#8B0000"))
})

TweenService:Create(FloatGradient, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360}):Play()

-- ==================== JANELA PRINCIPAL ====================
local Main = Instance.new("CanvasGroup", ScreenGui)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT) 
Main.Position = UDim2.new(0.5, 0, 0.45, 0)
Main.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
Main.GroupTransparency = 1 
Main.Visible = false
Main.ClipsDescendants = true

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Thickness = 1.5
MainStroke.Color = Color3.fromHex("#8B0000")
CriarGradienteVermelhoEscuro(MainStroke)
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 9)

-- Cabeçalho
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
Header.BackgroundTransparency = 1

-- Título com Separador Moderno
local TitleContainer = Instance.new("Frame", Header)
TitleContainer.Size = UDim2.new(0.8, 0, 1, 0)
TitleContainer.Position = UDim2.new(0, 12, 0, 0)
TitleContainer.BackgroundTransparency = 1

local TitleAkat = Instance.new("TextLabel", TitleContainer)
TitleAkat.Size = UDim2.new(0, 42, 1, 0)
TitleAkat.Text = "AKAT"
TitleAkat.TextColor3 = Color3.fromHex("#8B0000")
TitleAkat.Font = Enum.Font.GothamBold
TitleAkat.TextSize = 13
TitleAkat.TextXAlignment = Enum.TextXAlignment.Left
TitleAkat.BackgroundTransparency = 1

-- Separador Moderno (Barra Estilizada ao invés de "|")
local ModernSeparator = Instance.new("Frame", TitleContainer)
ModernSeparator.AnchorPoint = Vector2.new(0, 0.5)
ModernSeparator.Size = UDim2.new(0, 2, 0, 14)
ModernSeparator.Position = UDim2.new(0, 48, 0.5, 0)
ModernSeparator.BackgroundColor3 = Color3.fromHex("#8B0000")
ModernSeparator.BorderSizePixel = 0
Instance.new("UICorner", ModernSeparator).CornerRadius = UDim.new(1, 0)
CriarGradienteVermelhoEscuro(ModernSeparator)

local TitleGame = Instance.new("TextLabel", TitleContainer)
TitleGame.Size = UDim2.new(1, -58, 1, 0)
TitleGame.Position = UDim2.new(0, 58, 0, 0)
TitleGame.Text = "JULES RNG (THE MINE)"
TitleGame.TextColor3 = Color3.fromRGB(240, 240, 240)
TitleGame.Font = Enum.Font.GothamBold
TitleGame.TextSize = 12
TitleGame.TextXAlignment = Enum.TextXAlignment.Left
TitleGame.BackgroundTransparency = 1

-- Botão Minimizar
local MinimizeBtn = Instance.new("TextButton", Header)
MinimizeBtn.Size = UDim2.new(0, 24, 0, 24)
MinimizeBtn.Position = UDim2.new(1, -32, 0.5, -12)
MinimizeBtn.Text = "-"
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 14
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 5)
local MinStroke = Instance.new("UIStroke", MinimizeBtn)
MinStroke.Color = Color3.fromHex("#8B0000")
MinStroke.Thickness = 1
CriarGradienteVermelhoEscuro(MinStroke)

local Separator = Instance.new("Frame", Main)
Separator.Size = UDim2.new(0.94, 0, 0, 1)
Separator.Position = UDim2.new(0.03, 0, 0, HEADER_HEIGHT)
Separator.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
Separator.BorderSizePixel = 0

-- Container de Configurações
local ContentFrame = Instance.new("Frame", Main)
ContentFrame.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT - 1)
ContentFrame.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT + 1)
ContentFrame.BackgroundTransparency = 1

-- ==================== CONSTRUTOR DE TOGGLES (TEXTO NO MEIO) ====================
local function CriarToggle(yPos, texto, flagName)
    local row = Instance.new("Frame", ContentFrame)
    row.Size = UDim2.new(0.94, 0, 0, 38)
    row.Position = UDim2.new(0.03, 0, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local rowStroke = Instance.new("UIStroke", row)
    rowStroke.Color = Color3.fromRGB(30, 30, 35)
    rowStroke.Thickness = 1

    -- Nome centralizado no meio da linha
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.Text = texto
    lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.BackgroundTransparency = 1

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 50, 0, 22)
    btn.Position = UDim2.new(1, -56, 0.5, -11)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    btn.Text = "OFF"
    btn.TextColor3 = Color3.fromRGB(150, 150, 150)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local btnStroke = Instance.new("UIStroke", btn)
    btnStroke.Color = Color3.fromRGB(45, 45, 50)
    btnStroke.Thickness = 1

    btn.MouseButton1Click:Connect(function()
        EfeitoClique(btn)
        flags[flagName] = not flags[flagName]
        if flags[flagName] then
            btn.Text = "ON"
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btnStroke.Color = Color3.fromHex("#8B0000")
            Animar(btn, {BackgroundColor3 = Color3.fromRGB(120, 10, 10)}, 0.15)
        else
            btn.Text = "OFF"
            btn.TextColor3 = Color3.fromRGB(150, 150, 150)
            btnStroke.Color = Color3.fromRGB(45, 45, 50)
            Animar(btn, {BackgroundColor3 = Color3.fromRGB(28, 28, 32)}, 0.15)
            
            if flagName == "ESP" then ClearAllESP() end
        end
    end)
end

-- Posições perfeitamente ajustadas sem espaço sobrando no final
CriarToggle(8, "X-RAY MINÉRIOS V2", "ESP")
CriarToggle(52, "INSTANT MINE", "InstantMine")
CriarToggle(96, "SPEED MODERADO", "Speed")

-- ==================== CONTROLES DE UI (ANIMAÇÃO SINCRONIZADA) ====================
local menuAberto = true
local isMinimized = false
local isAnimating = false

FloatBtn.MouseButton1Click:Connect(function()
    if isAnimating then return end
    isAnimating = true
    EfeitoClique(FloatBtn)
    
    menuAberto = not menuAberto
    if menuAberto then
        Main.Visible = true
        local targetHeight = isMinimized and HEADER_HEIGHT or UI_HEIGHT
        Main.Size = UDim2.new(0, UI_WIDTH, 0, targetHeight)
        
        -- Sincronização Perfeita usando GroupTransparency do CanvasGroup
        local tween = Animar(Main, {GroupTransparency = 0}, 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
        tween.Completed:Wait()
    else
        local tween = Animar(Main, {GroupTransparency = 1}, 0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
        tween.Completed:Wait()
        Main.Visible = false
    end
    isAnimating = false
end)

MinimizeBtn.MouseButton1Click:Connect(function()
    if isAnimating or not menuAberto then return end
    isAnimating = true
    EfeitoClique(MinimizeBtn)
    
    isMinimized = not isMinimized
    if isMinimized then
        MinimizeBtn.Text = "+"
        ContentFrame.Visible = false
        local tween = Animar(Main, {Size = UDim2.new(0, UI_WIDTH, 0, HEADER_HEIGHT)}, 0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
        tween.Completed:Wait()
    else
        MinimizeBtn.Text = "-"
        ContentFrame.Visible = true
        local tween = Animar(Main, {Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT)}, 0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
        tween.Completed:Wait()
    end
    isAnimating = false
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
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if drag and input == dragInput then drag = false; dragInput = nil end
    end)
end

ConfigurarArrastar(Main)
ConfigurarArrastar(FloatBtn)

-- ==================== INTRODUÇÃO AKAT ====================
local function ExecutarIntro()
    local Blur = Instance.new("BlurEffect")
    Blur.Size = 0
    Blur.Parent = Lighting

    local IntroFrame = Instance.new("Frame", ScreenGui)
    IntroFrame.Size = UDim2.new(1, 0, 1, 0)
    IntroFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
    IntroFrame.BackgroundTransparency = 1
    IntroFrame.BorderSizePixel = 0
    IntroFrame.ZIndex = 500

    local IntroText = Instance.new("TextLabel", IntroFrame)
    IntroText.AnchorPoint = Vector2.new(0.5, 0.5)
    IntroText.Size = UDim2.new(1, 0, 0, 50)
    IntroText.Position = UDim2.new(0.5, 0, 0.5, 15) 
    IntroText.BackgroundTransparency = 1
    IntroText.Font = Enum.Font.GothamBold
    IntroText.TextSize = 24
    IntroText.RichText = true
    IntroText.Text = '<font color="rgb(255, 255, 255)">Scripts | </font><font color="#8B0000">By A̷K̷A̷T̷ Community</font>'
    IntroText.TextTransparency = 1
    IntroText.ZIndex = 501

    local IntroLine = Instance.new("Frame", IntroFrame)
    IntroLine.AnchorPoint = Vector2.new(0.5, 0.5)
    IntroLine.Size = UDim2.new(0, 0, 0, 2) 
    IntroLine.Position = UDim2.new(0.5, 0, 0.5, 35)
    IntroLine.BackgroundColor3 = Color3.fromHex("#8B0000")
    IntroLine.BorderSizePixel = 0
    IntroLine.ZIndex = 501
    CriarGradienteVermelhoEscuro(IntroLine)

    Animar(IntroFrame, {BackgroundTransparency = 0.15}, 0.7) 
    Animar(Blur, {Size = 24}, 0.7) 
    task.wait(0.3)

    Animar(IntroText, {TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.6)
    Animar(IntroLine, {Size = UDim2.new(0, 280, 0, 2)}, 0.6)
    task.wait(2.2) 

    Animar(IntroText, {TextTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, -15)}, 0.5)
    Animar(IntroLine, {Size = UDim2.new(0, 0, 0, 2)}, 0.5)
    task.wait(0.15)
    Animar(IntroFrame, {BackgroundTransparency = 1}, 0.5)
    Animar(Blur, {Size = 0}, 0.5)
    task.wait(0.5)

    IntroFrame:Destroy()
    Blur:Destroy()

    FloatBtn.Visible = true
    Main.Visible = true
    ContentFrame.Visible = true
    Animar(FloatBtn, {Size = UDim2.new(0, 44, 0, 44)}, 0.3, Enum.EasingStyle.Back)
    Animar(Main, {GroupTransparency = 0}, 0.35, Enum.EasingStyle.Sine)
end

-- ==================== CHEATS AUXILIARES ====================
local function ForceBreakBlocks()
    if not flags.InstantMine then return end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            obj.HoldDuration = 0
        end
        
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
        if flags.Speed then
            hum.WalkSpeed = SPEED_MULTIPLIER
        else
            if hum.WalkSpeed == SPEED_MULTIPLIER then
                hum.WalkSpeed = DEFAULT_SPEED
            end
        end
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
