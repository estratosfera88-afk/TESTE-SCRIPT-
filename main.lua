-- [[
--     AKAT | JULES RNG (THE MINE)
--     Otimizado para Delta Mobile 2026
--     Funções: X-Ray Filtrado, Instant Mine (Block Hit), Speed, UI Animada
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- ==================== CONFIGURAÇÕES GERAIS ====================
local flags = {
    ESP = false,
    InstantMine = false,
    Speed = false
}

local SPEED_MULTIPLIER = 32
local DEFAULT_SPEED = 16
local espCache = {}

-- Dimensoes da UI
local UI_WIDTH = 280
local UI_HEIGHT = 210
local HEADER_HEIGHT = 36

-- Dicionário de Minérios (Cores e Nomes Corretos)
local ORES_CONFIG = {
    ["coal"] = {Name = "Coal", Color = Color3.fromRGB(80, 80, 80)},
    ["iron"] = {Name = "Iron", Color = Color3.fromRGB(220, 220, 220)},
    ["emerald"] = {Name = "Emerald", Color = Color3.fromRGB(46, 204, 113)},
    ["ruby"] = {Name = "Ruby", Color = Color3.fromRGB(231, 76, 60)},
    ["diamond"] = {Name = "Diamond", Color = Color3.fromRGB(52, 152, 219)},
    ["mythril"] = {Name = "Mythril", Color = Color3.fromRGB(155, 89, 182)},
    ["lapis"] = {Name = "Lapis", Color = Color3.fromRGB(41, 128, 185)},
    ["gold"] = {Name = "Gold", Color = Color3.fromRGB(241, 196, 15)}
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
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5) 
FloatBtn.Size = UDim2.new(0, 0, 0, 0)
FloatBtn.Position = UDim2.new(0.08, 0, 0.25, 0)
FloatBtn.Image = "rbxthumb://type=Asset&id=74407434556912&w=420&h=420"
FloatBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
FloatBtn.Visible = false
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(1, 0)
local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Color = Color3.fromRGB(150, 0, 0)
FloatStroke.Thickness = 1.5

-- ==================== JANELA PRINCIPAL (CANVAS GROUP) ====================
local Main = Instance.new("CanvasGroup", ScreenGui)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT) 
Main.Position = UDim2.new(0.5, 0, 0.45, 0)
Main.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
Main.GroupTransparency = 1 
Main.Visible = false
Main.ClipsDescendants = true

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(150, 0, 0)
MainStroke.Thickness = 1.5
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)

-- Cabeçalho
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
Header.BackgroundTransparency = 1

local TitleText = Instance.new("TextLabel", Header)
TitleText.Size = UDim2.new(0.7, 0, 1, 0)
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.Text = "AKAT | JULES RNG"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 13
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.BackgroundTransparency = 1

-- Botão Minimizar
local MinimizeBtn = Instance.new("TextButton", Header)
MinimizeBtn.Size = UDim2.new(0, 24, 0, 24)
MinimizeBtn.Position = UDim2.new(1, -32, 0.5, -12)
MinimizeBtn.Text = "-"
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 14
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 4)
local MinStroke = Instance.new("UIStroke", MinimizeBtn)
MinStroke.Color = Color3.fromRGB(60, 60, 65)
MinStroke.Thickness = 1

local Separator = Instance.new("Frame", Main)
Separator.Size = UDim2.new(0.92, 0, 0, 1)
Separator.Position = UDim2.new(0.04, 0, 0, HEADER_HEIGHT)
Separator.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
Separator.BorderSizePixel = 0

-- Container de Configurações
local ContentFrame = Instance.new("Frame", Main)
ContentFrame.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT - 2)
ContentFrame.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT + 2)
ContentFrame.BackgroundTransparency = 1

-- ==================== CONSTRUTOR DE TOGGLES ====================
local function CriarToggle(yPos, texto, flagName)
    local row = Instance.new("Frame", ContentFrame)
    row.Size = UDim2.new(0.92, 0, 0, 36)
    row.Position = UDim2.new(0.04, 0, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.65, 0, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.Text = texto
    lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 56, 0, 24)
    btn.Position = UDim2.new(1, -62, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    btn.Text = "OFF"
    btn.TextColor3 = Color3.fromRGB(160, 160, 160)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    btn.MouseButton1Click:Connect(function()
        EfeitoClique(btn)
        flags[flagName] = not flags[flagName]
        if flags[flagName] then
            btn.Text = "ON"
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            Animar(btn, {BackgroundColor3 = Color3.fromRGB(150, 0, 0)}, 0.15)
        else
            btn.Text = "OFF"
            btn.TextColor3 = Color3.fromRGB(160, 160, 160)
            Animar(btn, {BackgroundColor3 = Color3.fromRGB(35, 35, 40)}, 0.15)
        end
    end)
end

CriarToggle(12, "X-RAY MINÉRIOS", "ESP")
CriarToggle(56, "INSTANT MINE", "InstantMine")
CriarToggle(100, "SPEED MODERADO", "Speed")

-- ==================== CONTROLES DE UI (FADE & DRAG) ====================
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
        local targetSize = isMinimized and UDim2.new(0, UI_WIDTH, 0, HEADER_HEIGHT) or UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT)
        Main.Size = targetSize
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
        local tween = Animar(Main, {Size = UDim2.new(0, UI_WIDTH, 0, HEADER_HEIGHT)}, 0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
        tween.Completed:Wait()
        ContentFrame.Visible = false
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

-- ==================== SISTEMA DA INTRODUÇÃO AKAT ====================
local function ExecutarIntro()
    local Blur = Instance.new("BlurEffect")
    Blur.Size = 0
    Blur.Parent = Lighting

    local IntroFrame = Instance.new("Frame", ScreenGui)
    IntroFrame.Size = UDim2.new(1, 0, 1, 0)
    IntroFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
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
    IntroText.Text = '<font color="rgb(255, 255, 255)">Scripts | </font><font color="rgb(150, 0, 0)">By A̷K̷A̷T̷ Community</font>'
    IntroText.TextTransparency = 1
    IntroText.ZIndex = 501

    local IntroLine = Instance.new("Frame", IntroFrame)
    IntroLine.AnchorPoint = Vector2.new(0.5, 0.5)
    IntroLine.Size = UDim2.new(0, 0, 0, 2) 
    IntroLine.Position = UDim2.new(0.5, 0, 0.5, 35)
    IntroLine.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    IntroLine.BorderSizePixel = 0
    IntroLine.ZIndex = 501

    Animar(IntroFrame, {BackgroundTransparency = 0.25}, 0.7) 
    Animar(Blur, {Size = 20}, 0.7) 
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

    -- Revela a UI após a Intro
    FloatBtn.Visible = true
    Main.Visible = true
    ContentFrame.Visible = true
    Animar(FloatBtn, {Size = UDim2.new(0, 48, 0, 48)}, 0.3, Enum.EasingStyle.Back)
    Animar(Main, {GroupTransparency = 0}, 0.3, Enum.EasingStyle.Sine)
end

-- ==================== LÓGICA DOS CHEATS ====================

-- 1. X-Ray (ESP Inteligente Corrigido)
local function GetOreInfo(obj)
    local name = obj.Name:lower()
    
    -- Ignora terras, pedras comuns e cenários
    if name:find("stone") or name:find("pedra") or name:find("dirt") or name:find("terra") or name:find("baseplate") then 
        return nil 
    end
    
    -- Checa minérios configurados
    for key, info in pairs(ORES_CONFIG) do
        if name:find(key) then 
            return info 
        end
    end
    
    -- Fallback: Se tiver ProximityPrompt ou contiver "ore"/"minerio" no nome
    if name:find("ore") or name:find("minerio") or obj:FindFirstChildOfClass("ProximityPrompt") then
        return {Name = obj.Name, Color = Color3.fromRGB(255, 215, 0)}
    end
    
    return nil
end

local function ClearAllESP()
    for obj, data in pairs(espCache) do
        if data then
            pcall(function()
                if data.Highlight then data.Highlight:Destroy() end
                if data.Billboard then data.Billboard:Destroy() end
            end)
        end
    end
    table.clear(espCache)
end

local function UpdateESP()
    if not flags.ESP then
        if next(espCache) then
            ClearAllESP()
        end
        return
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local oreInfo = GetOreInfo(obj)
            
            if oreInfo then
                if not espCache[obj] then
                    local targetPart = obj:IsA("BasePart") and obj or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")))
                    
                    if targetPart then
                        local color = oreInfo.Color
                        
                        -- Highlight Outline + Fill
                        local hl = Instance.new("Highlight")
                        hl.Parent = obj
                        hl.Adornee = obj
                        hl.FillColor = color
                        hl.FillTransparency = 0.8
                        hl.OutlineColor = color
                        hl.OutlineTransparency = 0
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        
                        -- Nome do Minério Flutuante
                        local bgui = Instance.new("BillboardGui")
                        bgui.Parent = targetPart
                        bgui.Adornee = targetPart
                        bgui.Size = UDim2.new(0, 100, 0, 20)
                        bgui.StudsOffset = Vector3.new(0, 2.5, 0)
                        bgui.AlwaysOnTop = true
                        
                        local txt = Instance.new("TextLabel", bgui)
                        txt.Size = UDim2.new(1, 0, 1, 0)
                        txt.BackgroundTransparency = 1
                        txt.Text = oreInfo.Name
                        txt.TextColor3 = color
                        txt.TextStrokeTransparency = 0
                        txt.Font = Enum.Font.GothamBold
                        txt.TextSize = 12

                        espCache[obj] = {Highlight = hl, Billboard = bgui}
                    end
                end
            end
        end
    end
end

-- 2. Instant Mine (Zero Health/Durability Direto no Bloco)
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

-- 3. Loop Principal
RunService.Heartbeat:Connect(function()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

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

-- Task separada para o X-Ray não gerar lag no Mobile
task.spawn(function()
    while task.wait(1) do
        UpdateESP()
    end
end)

-- Limpeza de Memória quando o minério é destruído
workspace.DescendantRemoving:Connect(function(obj)
    if espCache[obj] then
        pcall(function()
            if espCache[obj].Highlight then espCache[obj].Highlight:Destroy() end
            if espCache[obj].Billboard then espCache[obj].Billboard:Destroy() end
        end)
        espCache[obj] = nil
    end
end)

-- Inicia a Intro
task.spawn(ExecutarIntro)
