-- [[
--     A̷K̷A̷T̷ THE MINE V1.0 | JULES RNG EDITION
--     Otimizado para Delta Mobile 2026
--     Funções: X-Ray, Instant Mine, Speed (Fade UI)
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Variáveis de Controle das Funções
local flags = {
    ESP = false,
    InstantMine = false,
    Speed = false
}

-- Configurações
local SPEED_MULTIPLIER = 32 -- Velocidade moderada
local DEFAULT_SPEED = 16

-- Cache para otimização
local espCache = {}

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
    local baseSize = btn.Size
    Animar(btn, {Size = baseSize - UDim2.new(0, 3, 0, 3)}, 0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    task.wait(0.08)
    Animar(btn, {Size = baseSize}, 0.15, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
end

-- ==================== CRIAÇÃO DA SCREEN GUI ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaAkatTheMineGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

-- Proteção e injeção (compatível com Delta)
local uiParent = player:WaitForChild("PlayerGui")
pcall(function() uiParent = CoreGui end)
if uiParent:FindFirstChild("DeltaAkatTheMineGui") then uiParent.DeltaAkatTheMineGui:Destroy() end
ScreenGui.Parent = uiParent

-- ==================== BOTÃO FLUTUANTE ====================
local FloatBtn = Instance.new("ImageButton", ScreenGui)
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5) 
FloatBtn.Size = UDim2.new(0, 45, 0, 45)
FloatBtn.Position = UDim2.new(0.07, 22, 0.25, 22)
FloatBtn.Image = "rbxthumb://type=Asset&id=74407434556912&w=420&h=420"
FloatBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(1, 0)

local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Color = Color3.fromRGB(150, 0, 0)
FloatStroke.Thickness = 1.5

-- ==================== JANELA PRINCIPAL (CANVAS GROUP PARA FADE) ====================
local Main = Instance.new("CanvasGroup", ScreenGui)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Size = UDim2.new(0, 240, 0, 160) 
Main.Position = UDim2.new(0.5, 0, 0.45, 0)
Main.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
Main.GroupTransparency = 1 -- Inicia invisível para o Fade In
Main.Visible = false

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(150, 0, 0)
MainStroke.Thickness = 1.5
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 6)

-- Cabeçalho
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundTransparency = 1

local TitleAkat = Instance.new("TextLabel", Header)
TitleAkat.Size = UDim2.new(0, 36, 1, 0)
TitleAkat.Position = UDim2.new(0, 10, 0, 0)
TitleAkat.Text = "A̷K̷A̷T̷"
TitleAkat.TextColor3 = Color3.fromRGB(180, 0, 0)
TitleAkat.Font = Enum.Font.GothamBold
TitleAkat.TextSize = 11
TitleAkat.TextXAlignment = Enum.TextXAlignment.Left
TitleAkat.BackgroundTransparency = 1

local TitleLine = Instance.new("Frame", Header)
TitleLine.Size = UDim2.new(0, 1, 0, 14)
TitleLine.Position = UDim2.new(0, 48, 0.5, -7)
TitleLine.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
TitleLine.BorderSizePixel = 0

local TitleText = Instance.new("TextLabel", Header)
TitleText.Size = UDim2.new(0.55, 0, 1, 0)
TitleText.Position = UDim2.new(0, 56, 0, 0)
TitleText.Text = "THE MINE V1.0"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 11
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.BackgroundTransparency = 1

local Separator = Instance.new("Frame", Main)
Separator.Size = UDim2.new(0.92, 0, 0, 1)
Separator.Position = UDim2.new(0.04, 0, 0, 32)
Separator.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
Separator.BorderSizePixel = 0

-- Container de Botões
local ContentFrame = Instance.new("Frame", Main)
ContentFrame.Size = UDim2.new(1, 0, 1, -35)
ContentFrame.Position = UDim2.new(0, 0, 0, 35)
ContentFrame.BackgroundTransparency = 1

-- ==================== CONSTRUTOR DE TOGGLES ====================
local function CriarToggle(yPos, texto, flagName)
    local btn = Instance.new("TextButton", ContentFrame)
    btn.Size = UDim2.new(0.92, 0, 0, 30)
    btn.Position = UDim2.new(0.04, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    btn.Text = texto .. " [OFF]"
    btn.TextColor3 = Color3.fromRGB(160, 160, 160)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    btn.MouseButton1Click:Connect(function()
        EfeitoClique(btn)
        flags[flagName] = not flags[flagName]
        if flags[flagName] then
            btn.Text = texto .. " [ON]"
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            Animar(btn, {BackgroundColor3 = Color3.fromRGB(150, 0, 0)}, 0.15)
        else
            btn.Text = texto .. " [OFF]"
            btn.TextColor3 = Color3.fromRGB(160, 160, 160)
            Animar(btn, {BackgroundColor3 = Color3.fromRGB(28, 28, 32)}, 0.15)
        end
    end)
end

CriarToggle(10, "X-RAY MINÉRIOS", "ESP")
CriarToggle(45, "INSTANT MINE", "InstantMine")
CriarToggle(80, "SPEED MODERADO", "Speed")

-- ==================== LÓGICA DE FADE IN/OUT ====================
local menuAberto = false
FloatBtn.MouseButton1Click:Connect(function()
    EfeitoClique(FloatBtn)
    menuAberto = not menuAberto
    if menuAberto then
        Main.Visible = true
        Animar(Main, {GroupTransparency = 0}, 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    else
        local fecharTween = Animar(Main, {GroupTransparency = 1}, 0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
        fecharTween.Completed:Connect(function()
            if not menuAberto then Main.Visible = false end
        end)
    end
end)

-- ==================== LÓGICA DE ARRASTAR ====================
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

-- ==================== SISTEMAS DO JOGO ====================

-- Cores dinâmicas baseadas na raridade presumida (Adapte os nomes conforme o jogo)
local function GetOreColor(name)
    name = name:lower()
    if name:find("diamond") or name:find("diamante") then return Color3.fromRGB(0, 255, 255) end
    if name:find("gold") or name:find("ouro") then return Color3.fromRGB(255, 215, 0) end
    if name:find("emerald") or name:find("esmeralda") then return Color3.fromRGB(80, 200, 120) end
    if name:find("ruby") or name:find("rubi") then return Color3.fromRGB(220, 20, 60) end
    if name:find("iron") or name:find("ferro") then return Color3.fromRGB(200, 200, 200) end
    return Color3.fromRGB(255, 255, 255) -- Cor padrão para outros
end

-- 1. X-Ray (ESP)
local function UpdateESP()
    -- Função genérica de busca (varre o Workspace em busca de objetos extraíveis)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            -- Identifica minérios pelo nome ou por conter ProximityPrompts/ClickDetectors
            local isOre = obj.Name:lower():find("ore") or obj.Name:lower():find("minerio") or obj:FindFirstChildOfClass("ProximityPrompt")

            if isOre then
                if flags.ESP then
                    if not espCache[obj] then
                        local color = GetOreColor(obj.Name)
                        
                        -- Cria o Highlight (Caixa que atravessa parede)
                        local hl = Instance.new("Highlight")
                        hl.Parent = obj
                        hl.Adornee = obj
                        hl.FillColor = color
                        hl.FillTransparency = 0.5
                        hl.OutlineColor = color
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        
                        -- Cria o Nome Acima (Billboard)
                        local bgui = Instance.new("BillboardGui")
                        bgui.Parent = obj
                        bgui.Adornee = obj
                        bgui.Size = UDim2.new(0, 100, 0, 20)
                        bgui.StudsOffset = Vector3.new(0, 2, 0)
                        bgui.AlwaysOnTop = true
                        
                        local txt = Instance.new("TextLabel", bgui)
                        txt.Size = UDim2.new(1, 0, 1, 0)
                        txt.BackgroundTransparency = 1
                        txt.Text = obj.Name
                        txt.TextColor3 = color
                        txt.TextStrokeTransparency = 0
                        txt.Font = Enum.Font.GothamBold
                        txt.TextSize = 12

                        espCache[obj] = {Highlight = hl, Billboard = bgui}
                    end
                else
                    -- Limpa o ESP se desligado
                    if espCache[obj] then
                        espCache[obj].Highlight:Destroy()
                        espCache[obj].Billboard:Destroy()
                        espCache[obj] = nil
                    end
                end
            end
        end
    end
end

-- 2. Instant Mine & 3. Speed Loops
RunService.Heartbeat:Connect(function()
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")

    -- Speed
    if hum then
        if flags.Speed then
            hum.WalkSpeed = SPEED_MULTIPLIER
        else
            -- Previne conflitos se o jogo forçar uma velocidade específica
            if hum.WalkSpeed == SPEED_MULTIPLIER then
                hum.WalkSpeed = DEFAULT_SPEED
            end
        end
    end

    -- Instant Mine (Zera o tempo de ProximityPrompts e Cooldowns de Ferramentas)
    if flags.InstantMine then
        -- Remove delay de Interações
        for _, prompt in ipairs(workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") then
                prompt.HoldDuration = 0
            end
        end

        -- Tenta remover cooldowns locais da picareta
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                for _, config in ipairs(tool:GetDescendants()) do
                    if config:IsA("NumberValue") and (config.Name:lower():find("cooldown") or config.Name:lower():find("wait")) then
                        config.Value = 0
                    end
                end
            end
        end
    end
end)

-- Loop lento para o X-Ray (para não causar travamentos no Mobile)
task.spawn(function()
    while task.wait(1) do
        UpdateESP()
    end
end)

-- Limpeza de memória ao desconectar objetos deletados (Minérios minerados)
workspace.DescendantRemoving:Connect(function(obj)
    if espCache[obj] then
        pcall(function()
            espCache[obj].Highlight:Destroy()
            espCache[obj].Billboard:Destroy()
        end)
        espCache[obj] = nil
    end
end)
