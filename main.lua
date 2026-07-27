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
    AutoMine = false,
    Float = false,
    Speed = false
}

local SPEED_MULTIPLIER = 32
local DEFAULT_SPEED = 16

-- Dimensões da UI
local UI_WIDTH = 370
local HEADER_HEIGHT = 42
local UI_HEIGHT = 246 -- Aumentado para acomodar os 4 Toggles

-- Cores do Tema Premium (Dark Red Edition)
local DARK_RED = Color3.fromRGB(55, 0, 0)
local NEON_RED = Color3.fromRGB(139, 0, 0) -- Substitui o vermelho brilhante por um escuro puro
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

-- ==================== LÓGICA DO AUTO MINE ====================
local promptCache = {}

local function TrackPrompt(obj)
    if obj:IsA("ProximityPrompt") then
        promptCache[obj] = true
    end
end

workspace.DescendantAdded:Connect(TrackPrompt)
workspace.DescendantRemoving:Connect(function(obj)
    if obj:IsA("ProximityPrompt") then promptCache[obj] = nil end
end)

for _, obj in ipairs(workspace:GetDescendants()) do
    TrackPrompt(obj)
end

task.spawn(function()
    while true do
        task.wait(0.25)
        if flags.AutoMine then
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root then
                for prompt in pairs(promptCache) do
                    if prompt.Enabled and prompt.Parent and prompt.Parent:IsA("BasePart") then
                        local dist = (prompt.Parent.Position - root.Position).Magnitude
                        -- Dispara automaticamente ao entrar na área de interação
                        if dist <= (prompt.MaxActivationDistance + 2) then
                            pcall(function()
                                if fireproximityprompt then
                                    fireproximityprompt(prompt, 1)
                                else
                                    prompt:InputHoldBegin()
                                    task.wait(0.05)
                                    prompt:InputHoldEnd()
                                end
                            end)
                        end
                    end
                end
            end
        end
    end
end)

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
FloatStroke.Color = Color3.fromRGB(255, 255, 255)
CriarGradienteRotativo(FloatStroke, 3, DARK_RED, NEON_RED, DARK_RED)

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
MainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255) 
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local BgGradient = Instance.new("UIGradient", MainFrame)
BgGradient.Rotation = 90
BgGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 18)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 6, 8))
})

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Thickness = 1.5
MainStroke.Color = Color3.fromRGB(255, 255, 255)
CriarGradienteRotativo(MainStroke, 4, DARK_RED, NEON_RED, DARK_RED)

-- Cabeçalho
local Header = Instance.new("Frame", MainFrame)
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
Header.BackgroundTransparency = 1

local TitleContainer = Instance.new("Frame", Header)
TitleContainer.Size = UDim2.new(0.82, 0, 1, 0)
TitleContainer.Position = UDim2.new(0, 12, 0, 0)
TitleContainer.BackgroundTransparency = 1

local AkatBadge = Instance.new("Frame", TitleContainer)
AkatBadge.AnchorPoint = Vector2.new(0, 0.5)
AkatBadge.Size = UDim2.new(0, 46, 0, 16)
AkatBadge.Position = UDim2.new(0, 0, 0.5, 0)
AkatBadge.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
AkatBadge.BorderSizePixel = 0
AkatBadge.ZIndex = 2
Instance.new("UICorner", AkatBadge).CornerRadius = UDim.new(0, 5)

local AkatBadgeStroke = Instance.new("UIStroke", AkatBadge)
AkatBadgeStroke.Thickness = 1.2
AkatBadgeStroke.Color = Color3.fromRGB(255, 255, 255) 
AkatBadgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
CriarGradienteRotativo(AkatBadgeStroke, 2.5, DARK_RED, NEON_RED, DARK_RED)

local TitleAkat = Instance.new("TextLabel", AkatBadge)
TitleAkat.Size = UDim2.new(1, 0, 1, 0)
TitleAkat.Text = "AKAT"
TitleAkat.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleAkat.Font = Enum.Font.GothamBold
TitleAkat.TextSize = 10
TitleAkat.TextXAlignment = Enum.TextXAlignment.Center
TitleAkat.BackgroundTransparency = 1
TitleAkat.ZIndex = 3

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

-- Botão Minimizar com Flash Effect
local MinimizeBtn = Instance.new("TextButton", Header)
MinimizeBtn.Size = UDim2.new(0, 26, 0, 26)
MinimizeBtn.Position = UDim2.new(1, -34, 0.5, -13)
MinimizeBtn.Text = ""
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

local MinimizeFlash = Instance.new("Frame", MinimizeBtn)
MinimizeFlash.Size = UDim2.new(1, 0, 1, 0)
MinimizeFlash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
MinimizeFlash.BackgroundTransparency = 1
Instance.new("UICorner", MinimizeFlash).CornerRadius = UDim.new(0, 6)

local MinLine = Instance.new("Frame", MinimizeBtn)
MinLine.Size = UDim2.new(0, 10, 0, 1)
MinLine.AnchorPoint = Vector2.new(0.5, 0.5)
MinLine.Position = UDim2.new(0.5, 0, 0.5, 0)
MinLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
MinLine.BorderSizePixel = 0

local MinStroke = Instance.new("UIStroke", MinimizeBtn)
MinStroke.Color = Color3.fromRGB(255, 255, 255)
MinStroke.Thickness = 1
CriarGradienteRotativo(MinStroke, 3, DARK_RED, NEON_RED, DARK_RED)

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

-- ==================== CONSTRUTOR DE TOGGLES ====================
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

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 52, 0, 24)
    btn.Position = UDim2.new(1, -58, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    btn.Text = ""
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    -- Novo sistema de Gradiente que afeta apenas a borda do botão
    local btnStroke = Instance.new("UIStroke", btn)
    btnStroke.Color = Color3.fromRGB(35, 35, 40) 
    btnStroke.Thickness = 1.5

    local btnGrad = CriarGradienteRotativo(btnStroke, 2.5, DARK_RED, NEON_RED, DARK_RED)
    btnGrad.Enabled = false -- Gradiente desligado por padrão

    local btnText = Instance.new("TextLabel", btn)
    btnText.Size = UDim2.new(1, 0, 1, 0)
    btnText.BackgroundTransparency = 1
    btnText.Text = "OFF"
    btnText.TextColor3 = Color3.fromRGB(150, 150, 150)
    btnText.Font = Enum.Font.GothamBold
    btnText.TextSize = 10
    btnText.ZIndex = 2

    btn.MouseButton1Click:Connect(function()
        EfeitoClique(btn)
        flags[flagName] = not flags[flagName]
        
        if flags[flagName] then
            btnText.Text = "ON"
            Animar(btnText, {TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.2)
            
            -- Liga o efeito na borda
            btnGrad.Enabled = true
            Animar(btnStroke, {Color = Color3.fromRGB(255, 255, 255)}, 0.2)

            -- Ativação individual do Float
            if flagName == "Float" then
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if root and not root:FindFirstChild("AkatFloatForce") then
                    local bv = Instance.new("BodyVelocity")
                    bv.Name = "AkatFloatForce"
                    bv.MaxForce = Vector3.new(0, 100000, 0)
                    bv.Velocity = Vector3.new(0, 0, 0)
                    bv.P = 1250
                    bv.Parent = root
                end
            end
        else
            btnText.Text = "OFF"
            Animar(btnText, {TextColor3 = Color3.fromRGB(150, 150, 150)}, 0.2)
            
            -- Desliga o efeito na borda
            Animar(btnStroke, {Color = Color3.fromRGB(35, 35, 40)}, 0.2)
            task.delay(0.2, function()
                if not flags[flagName] then btnGrad.Enabled = false end
            end)
            
            if flagName == "ESP" then ClearAllESP() end
            
            -- Desativação do Float
            if flagName == "Float" then
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if root and root:FindFirstChild("AkatFloatForce") then
                    root.AkatFloatForce:Destroy()
                end
            end
        end
    end)
end

CriarToggle(8, "X RAY MINES", "ESP")
CriarToggle(54, "AUTO MINE", "AutoMine")
CriarToggle(100, "FLOAT", "Float")
CriarToggle(146, "SPEED MOD", "Speed")

-- ==================== CONTROLES DA UI E ANIMAÇÕES ====================
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
    -- Efeito de Flash modernizado
    MinimizeFlash.BackgroundTransparency = 0
    Animar(MinimizeFlash, {BackgroundTransparency = 1}, 0.2)
    EfeitoClique(MinimizeBtn)
    
    local heightDiff = UI_HEIGHT - HEADER_HEIGHT
    local targetHeight, targetPos

    if not isMinimized then
        expandedPos = Main.Position
        isMinimized = true
        targetHeight = HEADER_HEIGHT
        targetPos = UDim2.new(expandedPos.X.Scale, expandedPos.X.Offset, expandedPos.Y.Scale, expandedPos.Y.Offset - (heightDiff / 2))
    else
        isMinimized = false
        targetHeight = UI_HEIGHT
        targetPos = expandedPos
    end

    local targetSize = UDim2.new(0, UI_WIDTH, 0, targetHeight)

    if resizeTween then resizeTween:Cancel(); resizeTween = nil end

    -- Animação 60FPS extremamente fluida sem delay (Quint Easing)
    resizeTween = TweenService:Create(Main, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
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

-- ==================== INTRODUÇÃO (AGORA 5 SEGUNDOS) ====================
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
    CardStroke.Color = Color3.fromRGB(255, 255, 255)
    CardStroke.Transparency = 1
    CriarGradienteRotativo(CardStroke, 2, DARK_RED, NEON_RED, DARK_RED)

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
    
    -- Duração estendida da introdução
    task.wait(5) 

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

-- ==================== LOOPS DE OTMIZAÇÃO E EVENTOS ====================
RunService.Heartbeat:Connect(function()
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if hum then
        if flags.Speed then hum.WalkSpeed = SPEED_MULTIPLIER
        else if hum.WalkSpeed == SPEED_MULTIPLIER then hum.WalkSpeed = DEFAULT_SPEED end end
    end
end)

task.spawn(function()
    while true do
        task.wait(UPDATE_INTERVAL)
        pcall(UpdateESP)
    end
end)

player.CharacterAdded:Connect(function(char)
    character = char
    ClearAllESP()
    
    -- Reaplicar o Float caso o player dê respawn e a função esteja ativada
    if flags.Float then
        task.wait(0.5)
        local root = char:WaitForChild("HumanoidRootPart", 3)
        if root and not root:FindFirstChild("AkatFloatForce") then
            local bv = Instance.new("BodyVelocity")
            bv.Name = "AkatFloatForce"
            bv.MaxForce = Vector3.new(0, 100000, 0)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.P = 1250
            bv.Parent = root
        end
    end
end)

-- Inicialização
task.spawn(ExecutarIntro)
