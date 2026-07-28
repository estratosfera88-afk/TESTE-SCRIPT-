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
    InstantMine = false,
    Float = false,
    Speed = false
}

local SPEED_MULTIPLIER = 32
local DEFAULT_SPEED = 16

-- Cores do Tema Premium
local DARK_RED = Color3.fromRGB(55, 0, 0)
local NEON_RED = Color3.fromRGB(139, 0, 0)
local ALMOST_BLACK = Color3.fromRGB(8, 8, 8)
local BLACK_GRADIENT = Color3.fromRGB(0, 0, 0)
local DARK_GRAY_GRADIENT = Color3.fromRGB(60, 60, 60)

-- Configurações do X-Ray V2
local MAX_DISTANCE = 180          
local MAX_HIGHLIGHTS = 45         
local UPDATE_INTERVAL = 0.65      
local espCache = {}

local RARITY_PRIORITY = {
    ["diamond"] = 10, ["mythril"] = 9, ["ruby"] = 8, ["emerald"] = 7,
    ["gold"] = 6, ["lapis"] = 5, ["iron"] = 4, ["coal"] = 3, ["ore"] = 2
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

-- ==================== GERENCIADORES E ANIMAÇÕES ====================
local function CriarGradienteRotativo(parent, speed, color1, color2, color3)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color1),
        ColorSequenceKeypoint.new(0.5, color2),
        ColorSequenceKeypoint.new(1, color3)
    })
    grad.Parent = parent
    TweenService:Create(grad, TweenInfo.new(speed or 3.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360}):Play()
    return grad
end

local function Animar(obj, goal, time, style, dir)
    local tween = TweenService:Create(obj, TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), goal)
    tween:Play()
    return tween
end

local function EfeitoClique(btn)
    task.spawn(function()
        local origSize = btn:GetAttribute("OriginalSize") or btn.Size
        if not btn:GetAttribute("OriginalSize") then btn:SetAttribute("OriginalSize", origSize) end
        Animar(btn, {Size = UDim2.new(origSize.X.Scale, origSize.X.Offset - 2, origSize.Y.Scale, origSize.Y.Offset - 2)}, 0.05)
        task.wait(0.05)
        Animar(btn, {Size = origSize}, 0.08)
    end)
end

-- ==================== CACHE DE PROMPTS ====================
local promptCache = {}
local function TrackPrompt(obj)
    if obj:IsA("ProximityPrompt") then promptCache[obj] = true end
end
workspace.DescendantAdded:Connect(TrackPrompt)
workspace.DescendantRemoving:Connect(function(obj)
    if obj:IsA("ProximityPrompt") then promptCache[obj] = nil end
end)
for _, obj in ipairs(workspace:GetDescendants()) do TrackPrompt(obj) end

-- ==================== LÓGICA DO X-RAY V2 ====================
local function ClearESP(obj)
    local data = espCache[obj]
    if not data then return end
    pcall(function()
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
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
    return nil
end

local function GetTargetPart(obj)
    if obj:IsA("BasePart") then return obj
    elseif obj:IsA("Model") then return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true) end
    return nil
end

local function CreateESP(obj, oreInfo, priority)
    if espCache[obj] then return end
    local targetPart = GetTargetPart(obj)
    if not targetPart then return end

    local hl = Instance.new("Highlight", obj)
    hl.Adornee = obj; hl.FillColor = oreInfo.Color; hl.FillTransparency = 0.72; hl.OutlineColor = oreInfo.Color; hl.OutlineTransparency = 0; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    local bgui = Instance.new("BillboardGui", targetPart)
    bgui.Adornee = targetPart; bgui.Size = UDim2.new(0, 110, 0, 28); bgui.StudsOffset = Vector3.new(0, 2.8, 0); bgui.AlwaysOnTop = true; bgui.MaxDistance = MAX_DISTANCE + 20

    local txt = Instance.new("TextLabel", bgui)
    txt.Size = UDim2.new(1, 0, 1, 0); txt.BackgroundTransparency = 1; txt.Text = oreInfo.Name; txt.TextColor3 = oreInfo.Color; txt.TextStrokeTransparency = 0.3; txt.Font = Enum.Font.GothamBold; txt.TextSize = 13

    espCache[obj] = { Highlight = hl, Billboard = bgui, Label = txt, Name = oreInfo.Name, Priority = priority or 1, Part = targetPart, Color = oreInfo.Color }
end

local function UpdateESP()
    if not flags.ESP then if next(espCache) then ClearAllESP() end return end
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local myPos = root.Position
    local candidates = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            if not espCache[obj] then
                local oreInfo, priority = GetOreInfo(obj)
                if oreInfo then
                    local part = GetTargetPart(obj)
                    if part and (part.Position - myPos).Magnitude <= MAX_DISTANCE then
                        table.insert(candidates, { Object = obj, Info = oreInfo, Priority = priority, Distance = (part.Position - myPos).Magnitude })
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
        if not obj.Parent or not data.Part or not data.Part.Parent then ClearESP(obj)
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

local uiParent = pcall(function() return CoreGui end) and CoreGui or player:WaitForChild("PlayerGui")
if uiParent:FindFirstChild("DeltaAkatTheMineGui") then uiParent.DeltaAkatTheMineGui:Destroy() end
ScreenGui.Parent = uiParent

-- Botão Flutuante
local FloatBtn = Instance.new("ImageButton", ScreenGui)
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5); FloatBtn.Size = UDim2.new(0, 0, 0, 0); FloatBtn.Position = UDim2.new(0.1, 0, 0.35, 0); FloatBtn.Image = "rbxthumb://type=Asset&id=99997714241420&w=150&h=150"; FloatBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10); FloatBtn.Visible = false; FloatBtn.ZIndex = 30
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)
local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Thickness = 1.4; FloatStroke.Color = Color3.fromRGB(255, 255, 255)
CriarGradienteRotativo(FloatStroke, 3, DARK_RED, NEON_RED, DARK_RED)

-- Main Frame
local Main = Instance.new("CanvasGroup", ScreenGui)
Main.AnchorPoint = Vector2.new(0.5, 0.5); Main.Size = UDim2.new(0, 370, 0, 310); Main.Position = UDim2.new(0.5, 0, 0.45, 0); Main.BackgroundTransparency = 1; Main.GroupTransparency = 1; Main.Visible = false
local MainScale = Instance.new("UIScale", Main); MainScale.Scale = 1

local MainFrame = Instance.new("Frame", Main)
MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255); MainFrame.BorderSizePixel = 0
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local BgGradient = Instance.new("UIGradient", MainFrame)
BgGradient.Rotation = 90; BgGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 18)), ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 6, 8))})

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Thickness = 1.5; MainStroke.Color = Color3.fromRGB(255, 255, 255)
CriarGradienteRotativo(MainStroke, 4, DARK_RED, NEON_RED, DARK_RED)

-- Cabeçalho
local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 42); Header.BackgroundTransparency = 1

local AkatBadge = Instance.new("Frame", Header)
AkatBadge.Size = UDim2.new(0, 46, 0, 16); AkatBadge.Position = UDim2.new(0, 12, 0.5, -8); AkatBadge.BackgroundColor3 = Color3.fromRGB(12, 12, 14); Instance.new("UICorner", AkatBadge).CornerRadius = UDim.new(0, 5)
local BadgeStroke = Instance.new("UIStroke", AkatBadge); BadgeStroke.Thickness = 1.2; BadgeStroke.Color = Color3.fromRGB(255, 255, 255)
CriarGradienteRotativo(BadgeStroke, 2.5, DARK_RED, NEON_RED, DARK_RED)
local TitleAkat = Instance.new("TextLabel", AkatBadge); TitleAkat.Size = UDim2.new(1, 0, 1, 0); TitleAkat.Text = "AKAT"; TitleAkat.TextColor3 = Color3.fromRGB(255, 255, 255); TitleAkat.Font = Enum.Font.GothamBold; TitleAkat.TextSize = 10; TitleAkat.BackgroundTransparency = 1

local TitleGame = Instance.new("TextLabel", Header)
TitleGame.Size = UDim2.new(0, 200, 1, 0); TitleGame.Position = UDim2.new(0, 66, 0, 0); TitleGame.Text = "JULES RNG (THE MINE)"; TitleGame.TextColor3 = Color3.fromRGB(240, 240, 240); TitleGame.Font = Enum.Font.GothamBold; TitleGame.TextSize = 11; TitleGame.TextXAlignment = Enum.TextXAlignment.Left; TitleGame.BackgroundTransparency = 1

local MinimizeBtn = Instance.new("TextButton", Header)
MinimizeBtn.Size = UDim2.new(0, 26, 0, 26); MinimizeBtn.Position = UDim2.new(1, -34, 0.5, -13); MinimizeBtn.Text = ""; MinimizeBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22); Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)
local MinLine = Instance.new("Frame", MinimizeBtn); MinLine.Size = UDim2.new(0, 10, 0, 1); MinLine.AnchorPoint = Vector2.new(0.5, 0.5); MinLine.Position = UDim2.new(0.5, 0, 0.5, 0); MinLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255); MinLine.BorderSizePixel = 0
local MinStroke = Instance.new("UIStroke", MinimizeBtn); MinStroke.Color = Color3.fromRGB(255, 255, 255); MinStroke.Thickness = 1; CriarGradienteRotativo(MinStroke, 3, DARK_RED, NEON_RED, DARK_RED)

local Separator = Instance.new("Frame", MainFrame)
Separator.Size = UDim2.new(0.94, 0, 0, 1); Separator.Position = UDim2.new(0.03, 0, 0, 42); Separator.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Separator.BorderSizePixel = 0

-- Content Frame (Scrolling)
local ContentFrame = Instance.new("ScrollingFrame", MainFrame)
ContentFrame.Size = UDim2.new(1, 0, 1, -43); ContentFrame.Position = UDim2.new(0, 0, 0, 43); ContentFrame.BackgroundTransparency = 1; ContentFrame.BorderSizePixel = 0; ContentFrame.ScrollBarThickness = 0; ContentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
local UIListLayout = Instance.new("UIListLayout", ContentFrame)
UIListLayout.Padding = UDim.new(0, 6); UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
Instance.new("UIPadding", ContentFrame).PaddingTop = UDim.new(0, 8)

-- ==================== AUTO MINE PAINEL (DINÂMICO) ====================
local selectedOreForAutoMine = nil

local AutoMinePanel = Instance.new("Frame", ContentFrame)
AutoMinePanel.Size = UDim2.new(0.94, 0, 0, 110); AutoMinePanel.BackgroundColor3 = Color3.fromRGB(12, 12, 15); AutoMinePanel.Visible = false; AutoMinePanel.LayoutOrder = 3; AutoMinePanel.ClipsDescendants = true
Instance.new("UICorner", AutoMinePanel).CornerRadius = UDim.new(0, 6)
local PanelStroke = Instance.new("UIStroke", AutoMinePanel); PanelStroke.Color = Color3.fromRGB(30, 30, 35); PanelStroke.Thickness = 1

local PanelHeader = Instance.new("TextLabel", AutoMinePanel)
PanelHeader.Size = UDim2.new(1, 0, 0, 24); PanelHeader.Text = "SELECIONE UM MINÉRIO"; PanelHeader.TextColor3 = Color3.fromRGB(150, 150, 150); PanelHeader.Font = Enum.Font.GothamBold; PanelHeader.TextSize = 10; PanelHeader.BackgroundTransparency = 1

local OreScroll = Instance.new("ScrollingFrame", AutoMinePanel)
OreScroll.Size = UDim2.new(1, -10, 1, -56); OreScroll.Position = UDim2.new(0, 5, 0, 24); OreScroll.BackgroundTransparency = 1; OreScroll.ScrollBarThickness = 2; OreScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local OreLayout = Instance.new("UIListLayout", OreScroll); OreLayout.Padding = UDim.new(0, 4); OreLayout.SortOrder = Enum.SortOrder.LayoutOrder

local RefreshBtn = Instance.new("TextButton", AutoMinePanel)
RefreshBtn.Size = UDim2.new(1, -10, 0, 24); RefreshBtn.Position = UDim2.new(0, 5, 1, -28); RefreshBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 26); RefreshBtn.Text = "REFRESH LIST"; RefreshBtn.TextColor3 = Color3.fromRGB(200, 200, 200); RefreshBtn.Font = Enum.Font.GothamBold; RefreshBtn.TextSize = 10; Instance.new("UICorner", RefreshBtn).CornerRadius = UDim.new(0, 4)
local RefreshStroke = Instance.new("UIStroke", RefreshBtn); RefreshStroke.Color = Color3.fromRGB(40, 40, 45); RefreshStroke.Thickness = 1

local function PopuleOreList()
    for _, child in ipairs(OreScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    local uniqueOres = {}
    
    -- Busca globalmente no workspace caso o ESP esteja desligado ou vazio no momento
    for _, obj in ipairs(workspace:GetDescendants()) do
        local oreInfo = GetOreInfo(obj)
        if oreInfo and not uniqueOres[oreInfo.Name] then
            uniqueOres[oreInfo.Name] = oreInfo.Color
        end
    end
    
    for oreName, oreColor in pairs(uniqueOres) do
        local btn = Instance.new("TextButton", OreScroll)
        btn.Size = UDim2.new(1, 0, 0, 22); btn.BackgroundColor3 = Color3.fromRGB(18, 18, 22); btn.Text = oreName; btn.TextColor3 = oreColor; btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        local bStroke = Instance.new("UIStroke", btn); bStroke.Color = Color3.fromRGB(30, 30, 35)
        
        btn.MouseButton1Click:Connect(function()
            EfeitoClique(btn); selectedOreForAutoMine = oreName
            PanelHeader.Text = "ALVO ATUAL: " .. string.upper(oreName)
            for _, b in ipairs(OreScroll:GetChildren()) do
                if b:IsA("TextButton") then local s = b:FindFirstChildOfClass("UIStroke"); if s then s.Color = Color3.fromRGB(30, 30, 35) end end
            end
            bStroke.Color = Color3.fromRGB(255, 255, 255)
        end)
    end
end
RefreshBtn.MouseButton1Click:Connect(function() EfeitoClique(RefreshBtn); PopuleOreList() end)

-- ==================== CONSTRUTOR DE TOGGLES ====================
local layoutOrderCounter = {["ESP"] = 1, ["AutoMine"] = 2, ["InstantMine"] = 4, ["Float"] = 5, ["Speed"] = 6}

local function CriarToggle(texto, flagName)
    local row = Instance.new("Frame", ContentFrame)
    row.Size = UDim2.new(0.94, 0, 0, 40); row.BackgroundColor3 = Color3.fromRGB(16, 16, 20); row.LayoutOrder = layoutOrderCounter[flagName]
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    local rowStroke = Instance.new("UIStroke", row); rowStroke.Color = Color3.fromRGB(30, 30, 35); rowStroke.Thickness = 1

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -70, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0); lbl.Text = texto; lbl.TextColor3 = Color3.fromRGB(230, 230, 230); lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Center; lbl.BackgroundTransparency = 1

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 52, 0, 24); btn.Position = UDim2.new(1, -58, 0.5, -12); btn.BackgroundColor3 = Color3.fromRGB(22, 22, 26); btn.Text = ""; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    -- Efeito do botão: Gradiente EXCLUSIVO no UIStroke do BOTÃO (Sem mexer no texto)
    local btnStroke = Instance.new("UIStroke", btn)
    btnStroke.Color = Color3.fromRGB(35, 35, 40); btnStroke.Thickness = 1.5
    local btnGrad = CriarGradienteRotativo(btnStroke, 1.8, DARK_RED, NEON_RED, DARK_RED)
    btnGrad.Enabled = false 

    local btnText = Instance.new("TextLabel", btn)
    btnText.Size = UDim2.new(1, 0, 1, 0); btnText.BackgroundTransparency = 1; btnText.Text = "OFF"; btnText.TextColor3 = Color3.fromRGB(150, 150, 150); btnText.Font = Enum.Font.GothamBold; btnText.TextSize = 10

    btn.MouseButton1Click:Connect(function()
        EfeitoClique(btn)
        flags[flagName] = not flags[flagName]
        
        if flags[flagName] then
            btnText.Text = "ON"
            Animar(btnText, {TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.2)
            btnGrad.Enabled = true
            Animar(btnStroke, {Color = Color3.fromRGB(255, 255, 255)}, 0.2)

            if flagName == "AutoMine" then AutoMinePanel.Visible = true; PopuleOreList() end
            if flagName == "Float" and character then
                local root = character:FindFirstChild("HumanoidRootPart")
                if root and not root:FindFirstChild("AkatFloatForce") then
                    local bv = Instance.new("BodyVelocity")
                    bv.Name = "AkatFloatForce"
                    bv.MaxForce = Vector3.new(0, 100000, 0)
                    bv.Velocity = Vector3.new(0, 0, 0)
                    bv.Parent = root
                end
            end
        else
            btnText.Text = "OFF"
            Animar(btnText, {TextColor3 = Color3.fromRGB(150, 150, 150)}, 0.2)
            Animar(btnStroke, {Color = Color3.fromRGB(35, 35, 40)}, 0.2)
            task.delay(0.2, function() if not flags[flagName] then btnGrad.Enabled = false end end)
            
            if flagName == "ESP" then ClearAllESP() end
            if flagName == "AutoMine" then AutoMinePanel.Visible = false; if character and character:FindFirstChild("HumanoidRootPart") then character.HumanoidRootPart.Anchored = false end end
            if flagName == "Float" and character and character:FindFirstChild("HumanoidRootPart") then
                local root = character.HumanoidRootPart
                if root:FindFirstChild("AkatFloatForce") then root.AkatFloatForce:Destroy() end
            end
        end
    end)
end

CriarToggle("X RAY MINES", "ESP")
CriarToggle("AUTO MINE", "AutoMine")
CriarToggle("INSTANT MINE", "InstantMine")
CriarToggle("FLOAT", "Float")
CriarToggle("SPEED MOD", "Speed")

-- ==================== SISTEMA CORE DE FUNCIONALIDADES ====================
local floatJumpConnection

local function UpdateAbilities()
    -- Lógica do Instant Mine
    if flags.InstantMine then
        if character then
            local tool = character:FindFirstChildOfClass("Tool")
            if tool then
                for _, v in ipairs(tool:GetDescendants()) do
                    if v:IsA("NumberValue") or v:IsA("IntValue") then
                        local name = v.Name:lower()
                        if name:find("speed") or name:find("cooldown") or name:find("wait") or name:find("delay") then v.Value = 0.01
                        elseif name:find("damage") or name:find("efficiency") or name:find("power") then v.Value = 99999 end
                    end
                end
            end
        end
        for prompt in pairs(promptCache) do
            if prompt and prompt.Parent then
                pcall(function() prompt.HoldDuration = 0 end)
            end
        end
    end

    -- Lógica do Auto Mine Otimizado
    if flags.AutoMine and selectedOreForAutoMine and character then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            root.Anchored = true 
            
            local targetObj, targetDist = nil, math.huge
            for _, obj in ipairs(workspace:GetDescendants()) do
                local oreInfo = GetOreInfo(obj)
                if oreInfo and oreInfo.Name == selectedOreForAutoMine then
                    local part = GetTargetPart(obj)
                    if part then
                        local dist = (part.Position - root.Position).Magnitude
                        if dist < targetDist then targetDist = dist; targetObj = obj end
                    end
                end
            end
            
            if targetObj then
                local prompt = targetObj:FindFirstChildOfClass("ProximityPrompt") or targetObj:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then
                    prompt.MaxActivationDistance = 99999
                    prompt.RequiresLineOfSight = false
                    pcall(function()
                        if fireproximityprompt then fireproximityprompt(prompt)
                        else prompt:InputHoldBegin(); task.wait(0.01); prompt:InputHoldEnd() end
                    end)
                end
            end
        end
    end

    -- Lógica do Speed
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if hum then
        if flags.Speed then hum.WalkSpeed = SPEED_MULTIPLIER
        else if hum.WalkSpeed == SPEED_MULTIPLIER then hum.WalkSpeed = DEFAULT_SPEED end end
    end
end

RunService.Heartbeat:Connect(UpdateAbilities)

-- ==================== LÓGICA DO FLOAT (PROGRESSIVO E SUAVE) ====================
local function AtivarFloatMode(char)
    local root = char:WaitForChild("HumanoidRootPart", 3)
    if not root then return end
    
    if flags.Float and not root:FindFirstChild("AkatFloatForce") then
        local bv = Instance.new("BodyVelocity")
        bv.Name = "AkatFloatForce"
        bv.MaxForce = Vector3.new(0, 100000, 0)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = root
    end
end

if floatJumpConnection then floatJumpConnection:Disconnect() end
floatJumpConnection = UserInputService.JumpRequest:Connect(function()
    if flags.Float and character then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            local force = root:FindFirstChild("AkatFloatForce")
            if not force then
                force = Instance.new("BodyVelocity")
                force.Name = "AkatFloatForce"
                force.MaxForce = Vector3.new(0, 100000, 0)
                force.Velocity = Vector3.new(0, 0, 0)
                force.Parent = root
            end
            TweenService:Create(force, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Velocity = Vector3.new(0, 22, 0)}):Play()
            task.delay(0.15, function()
                if force and force.Parent then
                    TweenService:Create(force, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Velocity = Vector3.new(0, 0, 0)}):Play()
                end
            end)
        end
    end
end)

-- ==================== EVENTOS E INTRODUÇÃO ====================
task.spawn(function() while true do task.wait(UPDATE_INTERVAL); pcall(UpdateESP) end end)

player.CharacterAdded:Connect(function(char)
    character = char; ClearAllESP()
    task.delay(0.5, function() AtivarFloatMode(char) end)
end)

local menuAberto, isMinimized, expandedPos = true, false, Main.Position
FloatBtn.MouseButton1Click:Connect(function()
    EfeitoClique(FloatBtn); menuAberto = not menuAberto
    if menuAberto then Main.Visible = true; Animar(Main, {GroupTransparency = 0}, 0.2); Animar(MainScale, {Scale = 1}, 0.2)
    else local t = Animar(Main, {GroupTransparency = 1}, 0.2); Animar(MainScale, {Scale = 0.85}, 0.2); t.Completed:Connect(function() if not menuAberto then Main.Visible = false end end) end
end)

MinimizeBtn.MouseButton1Click:Connect(function()
    EfeitoClique(MinimizeBtn)
    local targetHeight, targetPos
    if not isMinimized then
        expandedPos = Main.Position; isMinimized = true; targetHeight = 42
        targetPos = UDim2.new(expandedPos.X.Scale, expandedPos.X.Offset, expandedPos.Y.Scale, expandedPos.Y.Offset - ((310 - 42) / 2))
    else
        isMinimized = false; targetHeight = 310; targetPos = expandedPos
    end
    Animar(Main, {Size = UDim2.new(0, 370, 0, targetHeight), Position = targetPos}, 0.35, Enum.EasingStyle.Quint)
end)

local function ConfigurarArrastar(inst)
    local drag, startPos, dragStart, dragInput = false
    inst.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then drag = true; dragStart = input.Position; startPos = inst.Position; dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if drag and input == dragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            inst.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            if inst == Main and not isMinimized then expandedPos = Main.Position end
        end
    end)
    UserInputService.InputEnded:Connect(function(input) if drag and input == dragInput then drag = false end end)
end
ConfigurarArrastar(Main); ConfigurarArrastar(FloatBtn)

local function ExecutarIntro()
    local Blur = Instance.new("BlurEffect", Lighting); Blur.Size = 0
    local IntroFrame = Instance.new("Frame", ScreenGui); IntroFrame.Size = UDim2.new(1, 0, 1, 0); IntroFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 7); IntroFrame.BackgroundTransparency = 1; IntroFrame.ZIndex = 500
    local Card = Instance.new("Frame", IntroFrame); Card.AnchorPoint = Vector2.new(0.5, 0.5); Card.Size = UDim2.new(0, 290, 0, 70); Card.Position = UDim2.new(0.5, 0, 0.5, 0); Card.BackgroundColor3 = Color3.fromRGB(12, 12, 15); Card.BackgroundTransparency = 1; Card.ZIndex = 501; Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 10)
    
    local CardStroke = Instance.new("UIStroke", Card); CardStroke.Thickness = 1.5; CardStroke.Color = Color3.fromRGB(255, 255, 255); CardStroke.Transparency = 1; CriarGradienteRotativo(CardStroke, 2, DARK_RED, NEON_RED, DARK_RED)
    local IntroText = Instance.new("TextLabel", Card); IntroText.Size = UDim2.new(1, 0, 0, 30); IntroText.Position = UDim2.new(0, 0, 0, 12); IntroText.BackgroundTransparency = 1; IntroText.Font = Enum.Font.GothamBold; IntroText.TextSize = 20; IntroText.RichText = true; IntroText.Text = '<font color="#FFFFFF">AKAT</font> <font color="#8B0000">COMMUNITY</font>'; IntroText.TextTransparency = 1; IntroText.ZIndex = 502
    local SubText = Instance.new("TextLabel", Card); SubText.Size = UDim2.new(1, 0, 0, 20); SubText.Position = UDim2.new(0, 0, 0, 38); SubText.BackgroundTransparency = 1; SubText.Font = Enum.Font.GothamMedium; SubText.TextSize = 11; SubText.Text = "JULES RNG (THE MINE) • LOADING..."; SubText.TextColor3 = Color3.fromRGB(180, 180, 180); SubText.TextTransparency = 1; SubText.ZIndex = 502

    Animar(IntroFrame, {BackgroundTransparency = 0.25}, 0.3); Animar(Blur, {Size = 20}, 0.3); task.wait(0.12)
    Animar(Card, {BackgroundTransparency = 0.05}, 0.3); Animar(CardStroke, {Transparency = 0}, 0.3); Animar(IntroText, {TextTransparency = 0}, 0.3); Animar(SubText, {TextTransparency = 0}, 0.3)
    task.wait(5) 
    Animar(IntroText, {TextTransparency = 1}, 0.25); Animar(SubText, {TextTransparency = 1}, 0.25); Animar(Card, {BackgroundTransparency = 1}, 0.25); Animar(CardStroke, {Transparency = 1}, 0.25); Animar(IntroFrame, {BackgroundTransparency = 1}, 0.3); Animar(Blur, {Size = 0}, 0.3)
    task.wait(0.3); IntroFrame:Destroy(); Blur:Destroy()
    
    FloatBtn.Visible = true; Main.Visible = true; Main.GroupTransparency = 1; MainScale.Scale = 0.85
    Animar(FloatBtn, {Size = UDim2.new(0, 46, 0, 46)}, 0.2); Animar(Main, {GroupTransparency = 0}, 0.2); Animar(MainScale, {Scale = 1}, 0.2)
end

task.spawn(ExecutarIntro)
