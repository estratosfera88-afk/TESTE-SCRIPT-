-- [[
--     A̷K̷A̷T̷ THE MINE V1 | JULES RNG EDITION
--     Interface original mantida. Módulos: X-Ray, Instant Mine, Speed.
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer

-- ==================== VARIÁVEIS DE CONTROLE ====================
local scriptEnabled = false 
local speedValue = 35 
local xrayEnabled = true
local instantMineEnabled = true
local menuAberto = true
local isMinimized = false 

-- Dicionário do X-Ray
local oreDictionary = {
    ["diamond"] = Color3.fromRGB(0, 255, 255),
    ["gold"] = Color3.fromRGB(255, 215, 0),
    ["emerald"] = Color3.fromRGB(80, 200, 120),
    ["ruby"] = Color3.fromRGB(224, 17, 95),
    ["iron"] = Color3.fromRGB(200, 200, 200)
}

-- ==================== FUNÇÃO DE ANIMAÇÃO CORE ====================
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

local uiParent = player:WaitForChild("PlayerGui")
pcall(function() uiParent = game:GetService("CoreGui") end)
if uiParent:FindFirstChild("DeltaAkatTheMineGui") then uiParent.DeltaAkatTheMineGui:Destroy() end
ScreenGui.Parent = uiParent

-- ==================== BOTÃO FLUTUANTE ====================
local FloatBtn = Instance.new("ImageButton", ScreenGui)
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5) 
FloatBtn.Size = UDim2.new(0, 45, 0, 45)
FloatBtn.Position = UDim2.new(0.07, 22, 0.25, 22)
FloatBtn.Image = "rbxthumb://type=Asset&id=74407434556912&w=420&h=420"
FloatBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
FloatBtn.Visible = false 
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(1, 0)

local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Color = Color3.fromRGB(150, 0, 0)
FloatStroke.Thickness = 1.5

-- ==================== JANELA PRINCIPAL ====================
local Main = Instance.new("Frame", ScreenGui)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Size = UDim2.new(0, 240, 0, 185) 
Main.Position = UDim2.new(0.5, 0, 0.45, 0)
Main.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
Main.Visible = false
Main.ClipsDescendants = true 

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(150, 0, 0)
MainStroke.Thickness = 1.5
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 6)

-- Barra de Título
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
TitleText.Text = "THE MINE V1"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 11
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.BackgroundTransparency = 1

local MinimizeBtn = Instance.new("TextButton", Header)
MinimizeBtn.Size = UDim2.new(0, 24, 0, 24)
MinimizeBtn.Position = UDim2.new(1, -56, 0.5, -12)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 16
MinimizeBtn.BackgroundTransparency = 1

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -28, 0.5, -12)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(180, 0, 0)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.BackgroundTransparency = 1

local Separator = Instance.new("Frame", Main)
Separator.Size = UDim2.new(0.92, 0, 0, 1)
Separator.Position = UDim2.new(0.04, 0, 0, 32)
Separator.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
Separator.BorderSizePixel = 0

local ContentFrame = Instance.new("Frame", Main)
ContentFrame.Size = UDim2.new(1, 0, 1, -35)
ContentFrame.Position = UDim2.new(0, 0, 0, 35)
ContentFrame.BackgroundTransparency = 1

-- ==================== COMPONENTES DA UI ====================
local function CriarLinhaConfig(yPos, textoLabel, valInicial, multiplicador, min, max, callback)
    local linha = Instance.new("Frame", ContentFrame)
    linha.Size = UDim2.new(0.92, 0, 0, 30)
    linha.Position = UDim2.new(0.04, 0, 0, yPos)
    linha.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    linha.BorderSizePixel = 0
    Instance.new("UICorner", linha).CornerRadius = UDim.new(0, 4)
    
    local valorAtual = valInicial
    local txt = Instance.new("TextLabel", linha)
    txt.Size = UDim2.new(0.5, 0, 1, 0)
    txt.Position = UDim2.new(0, 8, 0, 0)
    txt.Text = textoLabel .. ": " .. valorAtual
    txt.TextColor3 = Color3.fromRGB(230, 230, 230)
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 11
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.BackgroundTransparency = 1

    local menos = Instance.new("TextButton", linha)
    menos.Size = UDim2.new(0, 24, 0, 22)
    menos.Position = UDim2.new(0.62, 0, 0.5, -11)
    menos.Text = "-"
    menos.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    menos.TextColor3 = Color3.fromRGB(255, 255, 255)
    menos.Font = Enum.Font.GothamBold
    menos.TextSize = 12
    Instance.new("UICorner", menos).CornerRadius = UDim.new(0, 3)

    local mais = Instance.new("TextButton", linha)
    mais.Size = UDim2.new(0, 24, 0, 22)
    mais.Position = UDim2.new(0.84, 0, 0.5, -11)
    mais.Text = "+"
    mais.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    mais.TextColor3 = Color3.fromRGB(255, 255, 255)
    mais.Font = Enum.Font.GothamBold
    mais.TextSize = 12
    Instance.new("UICorner", mais).CornerRadius = UDim.new(0, 3)

    local function atualizar(nv)
        valorAtual = math.clamp(nv, min, max)
        txt.Text = textoLabel .. ": " .. valorAtual
        callback(valorAtual)
    end

    menos.MouseButton1Click:Connect(function() EfeitoClique(menos); atualizar(valorAtual - multiplicador) end)
    mais.MouseButton1Click:Connect(function() EfeitoClique(mais); atualizar(valorAtual + multiplicador) end)
end

local function CriarBotaoToggle(yPos, textoLabel, estadoInicial, callback)
    local linha = Instance.new("Frame", ContentFrame)
    linha.Size = UDim2.new(0.92, 0, 0, 30)
    linha.Position = UDim2.new(0.04, 0, 0, yPos)
    linha.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    linha.BorderSizePixel = 0
    Instance.new("UICorner", linha).CornerRadius = UDim.new(0, 4)

    local txt = Instance.new("TextLabel", linha)
    txt.Size = UDim2.new(0.55, 0, 1, 0)
    txt.Position = UDim2.new(0, 8, 0, 0)
    txt.Text = textoLabel
    txt.TextColor3 = Color3.fromRGB(230, 230, 230)
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 10
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.BackgroundTransparency = 1

    local btn = Instance.new("TextButton", linha)
    btn.Size = UDim2.new(0, 76, 0, 22)
    btn.Position = UDim2.new(0.62, 0, 0.5, -11)
    btn.Text = estadoInicial and "ON" or "OFF"
    btn.BackgroundColor3 = estadoInicial and Color3.fromRGB(150, 0, 0) or Color3.fromRGB(45, 45, 50)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)

    local estado = estadoInicial
    btn.MouseButton1Click:Connect(function()
        EfeitoClique(btn)
        estado = not estado
        if estado then
            btn.Text = "ON"
            Animar(btn, {BackgroundColor3 = Color3.fromRGB(150, 0, 0)}, 0.15)
        else
            btn.Text = "OFF"
            Animar(btn, {BackgroundColor3 = Color3.fromRGB(45, 45, 50)}, 0.15)
        end
        callback(estado)
    end)
end

-- 1. Botão Liga/Desliga Alternável (Master Switch)
local StatusBtn = Instance.new("TextButton", ContentFrame)
StatusBtn.Size = UDim2.new(0.92, 0, 0, 30)
StatusBtn.Position = UDim2.new(0.04, 0, 0, 5)
StatusBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
StatusBtn.Text = "MASTER: OFF"
StatusBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
StatusBtn.Font = Enum.Font.GothamBold
StatusBtn.TextSize = 12
Instance.new("UICorner", StatusBtn).CornerRadius = UDim.new(0, 4)

StatusBtn.MouseButton1Click:Connect(function()
    EfeitoClique(StatusBtn)
    scriptEnabled = not scriptEnabled
    if scriptEnabled then
        StatusBtn.Text = "MASTER: ON"
        StatusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        Animar(StatusBtn, {BackgroundColor3 = Color3.fromRGB(150, 0, 0)}, 0.15)
    else
        StatusBtn.Text = "MASTER: OFF"
        StatusBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
        Animar(StatusBtn, {BackgroundColor3 = Color3.fromRGB(28, 28, 32)}, 0.15)
        
        -- Limpa X-Ray ao desligar mestre
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "Minecraft_Box_ESP" or obj.Name == "Minecraft_Text_ESP" then
                obj:Destroy()
            end
        end
    end
end)

CriarLinhaConfig(40, "SPEED", speedValue, 1, 16, 100, function(v) speedValue = v end)
CriarBotaoToggle(75, "X-RAY ESP", xrayEnabled, function(v) 
    xrayEnabled = v 
    if not v then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "Minecraft_Box_ESP" or obj.Name == "Minecraft_Text_ESP" then
                obj:Destroy()
            end
        end
    end
end)
CriarBotaoToggle(110, "INSTANT MINE", instantMineEnabled, function(v) instantMineEnabled = v end)

-- ==================== LÓGICA DE ARRASTAR E EXPANDIR ====================
FloatBtn.MouseButton1Click:Connect(function()
    EfeitoClique(FloatBtn)
    menuAberto = not menuAberto
    if menuAberto then
        Main.Visible = true
        local alturaAlvo = isMinimized and 32 or 185
        Animar(Main, {Size = UDim2.new(0, 240, 0, alturaAlvo)}, 0.25, Enum.EasingStyle.Circular)
    else
        Animar(Main, {Size = UDim2.new(0, 0, 0, 0)}, 0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
        task.delay(0.23, function() if not menuAberto then Main.Visible = false end end)
    end
end)

MinimizeBtn.MouseButton1Click:Connect(function()
    EfeitoClique(MinimizeBtn)
    isMinimized = not isMinimized
    if isMinimized then
        MinimizeBtn.Text = "+"
        Animar(Main, {Size = UDim2.new(0, 240, 0, 32)}, 0.22, Enum.EasingStyle.Cubic)
    else
        MinimizeBtn.Text = "-"
        Main.Visible = true
        Animar(Main, {Size = UDim2.new(0, 240, 0, 185)}, 0.25, Enum.EasingStyle.Circular)
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    EfeitoClique(CloseBtn)
    task.wait(0.1)
    ScreenGui:Destroy()
end)

local function ConfigurarArrastarAkat(inst)
    local drag = false
    local startPos, dragStart, dragInput
    inst.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not drag then
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

ConfigurarArrastarAkat(Main)
ConfigurarArrastarAkat(FloatBtn)

-- ==================== LÓGICA: THE MINE (JULES RNG) ====================

-- 1. SPEED HACK
RunService.Heartbeat:Connect(function()
    if not scriptEnabled then return end
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.WalkSpeed ~= speedValue then
            humanoid.WalkSpeed = speedValue
        end
    end
end)

-- 2. INSTANT MINE
task.spawn(function()
    while task.wait(0.5) do
        if scriptEnabled and instantMineEnabled then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") and obj.HoldDuration > 0 then
                    obj.HoldDuration = 0
                end
            end
        end
    end
end)

-- 3. X-RAY (MINECRAFT STYLE)
local function CreateESP(part, name, color)
    if part:FindFirstChild("Minecraft_Box_ESP") then return end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "Minecraft_Box_ESP"
    box.Size = part.Size + Vector3.new(0.05, 0.05, 0.05)
    box.Adornee = part
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Transparency = 0.6
    box.Color3 = color
    box.Parent = part

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Minecraft_Text_ESP"
    billboard.Adornee = part
    billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.StudsOffset = Vector3.new(0, part.Size.Y/2 + 1.5, 0)
    billboard.AlwaysOnTop = true
    
    local text = Instance.new("TextLabel")
    text.Parent = billboard
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(1, 0, 1, 0)
    text.Text = name:upper()
    text.TextColor3 = color
    text.TextStrokeTransparency = 0
    text.Font = Enum.Font.GothamBold
    text.TextSize = 12

    billboard.Parent = part
end

task.spawn(function()
    while task.wait(1.5) do
        if scriptEnabled and xrayEnabled then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") or obj:IsA("Model") then
                    local objName = string.lower(obj.Name)
                    for oreName, color in pairs(oreDictionary) do
                        if string.find(objName, oreName) then
                            local targetPart = obj:IsA("Model") and obj.PrimaryPart or obj
                            if targetPart then
                                CreateESP(targetPart, obj.Name, color)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ==================== SISTEMA DE INTRODUÇÃO AKAT ====================
local function ExecutarIntroAkat()
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

    Animar(IntroFrame, {BackgroundTransparency = 0.25}, 0.7, Enum.EasingStyle.Cubic) 
    Animar(Blur, {Size = 20}, 0.7, Enum.EasingStyle.Cubic) 
    task.wait(0.3)

    Animar(IntroText, {TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.6, Enum.EasingStyle.Cubic)
    Animar(IntroLine, {Size = UDim2.new(0, 280, 0, 2)}, 0.6, Enum.EasingStyle.Cubic)
    task.wait(2.2) 

    Animar(IntroText, {TextTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, -15)}, 0.5, Enum.EasingStyle.Cubic)
    Animar(IntroLine, {Size = UDim2.new(0, 0, 0, 2)}, 0.5, Enum.EasingStyle.Cubic)
    task.wait(0.15)
    Animar(IntroFrame, {BackgroundTransparency = 1}, 0.5, Enum.EasingStyle.Cubic)
    Animar(Blur, {Size = 0}, 0.5, Enum.EasingStyle.Cubic)
    task.wait(0.4)

    IntroFrame:Destroy()
    Blur:Destroy()

    Main.Size = UDim2.new(0, 0, 0, 0) 
    Main.Visible = true
    
    FloatBtn.Size = UDim2.new(0, 0, 0, 0)
    FloatBtn.Visible = true

    Animar(Main, {Size = UDim2.new(0, 240, 0, 185)}, 0.28, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
    Animar(FloatBtn, {Size = UDim2.new(0, 45, 0, 45)}, 0.28, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
end

task.spawn(ExecutarIntroAkat)
