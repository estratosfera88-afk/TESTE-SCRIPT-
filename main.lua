-- [[
--     AKAT MM2 SCRIPT [BETA v3.1] - ESP + AUTO SHOOT REWRITE 2026
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local mouse = player:GetMouse()

local gunDroppedThisRound = false

-- ==================== ANTI-BAN / ANTI-KICK & METAMETHOD HOOKS ====================
local oldIndex = nil
local oldNamecall = nil

task.spawn(function()
    local gmt = getrawmetatable and getrawmetatable(game)
    if gmt and setreadonly and hookfunction then
        setreadonly(gmt, false)
        oldIndex = gmt.__index
        oldNamecall = gmt.__namecall
        
        gmt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if tostring(method):lower() == "kick" and self == player then
                warn("[AKAT ANTI-BAN] Tentativa de Kick bloqueada!")
                return nil
            end
            return oldNamecall(self, ...)
        end)
        
        gmt.__index = newcclosure(function(self, key)
            if tostring(key):lower() == "kick" and self == player then
                return newcclosure(function()
                    warn("[AKAT ANTI-BAN] Kick indireto bloqueado!")
                end)
            end
            
            if _G.Configs and _G.Configs.AutoShoot and self == mouse then
                if key == "Hit" or key == "hit" then
                    local murderer = _G.AS_GetMurderer()
                    local pChar = murderer and murderer.Character
                    local head = pChar and (pChar:FindFirstChild("Head") or pChar:FindFirstChild("HumanoidRootPart"))
                    if head then return CFrame.new(head.Position) end
                elseif key == "Target" or key == "target" then
                    local murderer = _G.AS_GetMurderer()
                    local pChar = murderer and murderer.Character
                    local head = pChar and (pChar:FindFirstChild("Head") or pChar:FindFirstChild("HumanoidRootPart"))
                    if head then return head end
                end
            end
            
            return oldIndex(self, key)
        end)
        setreadonly(gmt, true)
    end

    local function applyBypass(character)
        if not character then return end
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid and hookproperty then
            pcall(function() hookproperty(humanoid, "WalkSpeed", 16) end)
        end
    end
    player.CharacterAdded:Connect(applyBypass)
    if player.Character then applyBypass(player.Character) end
end)

-- ==================== 1. CONFIGURAÇÕES E LOCALES ESTÁTICOS ====================
local Configs = {
    AutoShoot = false,
    Reach = false,
    ESP = false,
    Speed = false,
    AntiFling = false,
    TpToGun = false,
    SafeSpot = false,
    AutoCollect = false,
    ChatRoles = false
}
_G.Configs = Configs

local Locales = {
    PT = {
        SearchPlaceholder = "Pesquisar recursos...",
        ConfirmCloseTitle = "Deseja fechar o script?",
        ConfirmBtn = "Confirmar",
        CancelBtn = "Cancelar",
        Headers = {
            Combat = "CONTEÚDO DE COMBATE",
            Visuals = "SUPORTE VISUAL (ESP)",
            Movement = "MODIFICADORES DE MOVIMENTO",
            Teleports = "SISTEMAS DE TELEPORTE",
            Misc = "FUNÇÕES DIVERSAS"
        },
        Options = {
            AutoShoot = { Title = "Atirar no Murder (Mobile)", Desc = "Cria um botão de disparo flutuante. O tiro vai direto no assassino silenciosamente." },
            Reach = { Title = "Alcance da Faca", Desc = "Aumenta consideravelmente a área de corte da sua faca de forma invisível." },
            ESP = { Title = "ESP Jogadores", Desc = "Destaca jogadores pelas paredes (Xerife Azul / Herói Amarelo / Murder Vermelho)." },
            Speed = { Title = "Velocidade", Desc = "Aumenta a velocidade de caminhada de forma estável para 23." },
            AntiFling = { Title = "Anti-Arremesso", Desc = "Bloqueia colisões físicas agressivas para evitar que te matem por fling." },
            TpToGun = { Title = "Teleportar p/ Arma", Desc = "Teleporta instantaneamente para a arma dropada caso você seja inocente." },
            SafeSpot = { Title = "Lugar Seguro", Desc = "Cria uma plataforma invisível no céu isolada de perigos." },
            AutoCollect = { Title = "Coletar Moedas", Desc = "Coleta moedas continuamente pelo mapa de forma ultra veloz." },
            ChatRoles = { Title = "Revelar Funções", Desc = "Envia automaticamente no chat global quem são os cargos secretos." }
        },
        Intro = '<font color="#FFFFFF">Scripts por | </font><font color="#8B0000">Comunidade AKAT</font>'
    },
    EN = {
        SearchPlaceholder = "Search features...",
        ConfirmCloseTitle = "Do you want to close the script?",
        ConfirmBtn = "Confirm",
        CancelBtn = "Cancel",
        Headers = {
            Combat = "COMBAT FEATURES",
            Visuals = "VISUAL SUPPORT (ESP)",
            Movement = "MOVEMENT MODIFIERS",
            Teleports = "TELEPORTATION SYSTEMS",
            Misc = "MISCELLANEOUS"
        },
        Options = {
            AutoShoot = { Title = "Shoot Murderer (Mobile)", Desc = "Creates a floating fire button. Redirects bullets directly to the Murderer." },
            Reach = { Title = "Knife Reach", Desc = "Significantly increases your knife hitboxes smoothly." },
            ESP = { Title = "Player ESP", Desc = "Highlights players through walls based on game roles." },
            Speed = { Title = "WalkSpeed", Desc = "Increases your character speed smoothly up to 23." },
            AntiFling = { Title = "Anti-Fling", Desc = "Disables chaotic physics glitches from other players." },
            TpToGun = { Title = "TP to Dropped Gun", Desc = "Instantly fetches the gun if you are an innocent survivor." },
            SafeSpot = { Title = "Safe Spot", Desc = "Teleports you to a secure invisible structure high in the air." },
            AutoCollect = { Title = "Auto Collect Coins", Desc = "Continuously flies towards available coins across the map." },
            ChatRoles = { Title = "Reveal Active Roles", Desc = "Automatically leaks secret round rules and identities inside chat." }
        },
        Intro = '<font color="#FFFFFF">Scripts by | </font><font color="#8B0000">AKAT Community</font>'
    }
}

local currentLanguage = "PT"
local menuAberto = true
local isMinimized = false
local hbConnection = nil
local renderConnection = nil
local PlayerRoles = {}
local originalTrans = {}
local confirmBlur = nil
local isConfirmOpen = false
local wasMinimizedBeforeConfirm = false

local safePlatform = nil
local lastPositionBeforeSafeSpot = nil
local announcedThisRound = false
local hasTeleportedToGun = false
local originalPositionBeforeGun = nil
local currentCollectTarget = nil
local lastCoinSearch = 0
local wasAutoCollecting = false

-- ==================== ESP SYSTEM ====================
local ESPHighlights = {}
local ROLE_COLORS = {
    Murderer  = Color3.fromRGB(220, 0,   0),    
    Sheriff   = Color3.fromRGB(0,   120, 255),  
    Hero      = Color3.fromRGB(255, 220, 0),    
    Innocent  = Color3.fromRGB(0,   200, 80),   
}

local function ESP_DetectRole(p)
    if not p or not p.Parent then return "Innocent" end
    local function scanTools(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local n = item.Name:lower()
                if n:find("knife") or n:find("faca") or n:find("sword") then
                    return "Murderer"
                elseif n:find("gun") or n:find("pistol") or n:find("revolver") or n:find("arma") then
                    if gunDroppedThisRound then return "Hero" else return "Sheriff" end
                end
            end
        end
        return nil
    end

    local toolRole = scanTools(p.Character) or scanTools(p:FindFirstChild("Backpack"))
    if toolRole then return toolRole end

    local function checkAttr(target)
        if not target then return nil end
        local role = target:GetAttribute("Role") or target:GetAttribute("role") or target:GetAttribute("MMRole")
        if not role then return nil end
        local r = tostring(role):lower()
        if r:find("murder") or r:find("assassin") then return "Murderer" end
        if r:find("sheriff") or r:find("xerife")   then return "Sheriff"  end
        if r:find("hero")   or r:find("heroi")     then return "Hero"     end
        return nil
    end
    return checkAttr(p) or checkAttr(p.Character) or "Innocent"
end

local function ESP_UpdatePlayer(p)
    if not p or not p.Character then
        if ESPHighlights[p] then pcall(function() ESPHighlights[p]:Destroy() end) ESPHighlights[p] = nil end
        return
    end
    local char = p.Character
    local role = ESP_DetectRole(p)
    PlayerRoles[p] = role

    local color = ROLE_COLORS[role] or ROLE_COLORS.Innocent
    local hl = char:FindFirstChild("AkatESP")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "AkatESP"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 0.3
        hl.OutlineTransparency = 0
        hl.Parent = char
        ESPHighlights[p] = hl
    end
    hl.FillColor    = color
    hl.OutlineColor = color
end

local function ESP_ClearAll()
    for p, hl in pairs(ESPHighlights) do
        pcall(function() if hl and hl.Parent then hl:Destroy() end end)
        ESPHighlights[p] = nil
    end
    table.clear(PlayerRoles)
end

local espEventConnections = {}
local function ESP_ConnectPlayer(p)
    if p == player then return end
    local c1 = p.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        ESP_UpdatePlayer(p)
        char.ChildAdded:Connect(function() task.wait(0.05); ESP_UpdatePlayer(p) end)
        char.ChildRemoved:Connect(function() task.wait(0.05); ESP_UpdatePlayer(p) end)
    end)
    local bp = p:FindFirstChild("Backpack")
    local c2 = bp and bp.ChildAdded:Connect(function() task.wait(0.05); ESP_UpdatePlayer(p) end)
    local c3 = bp and bp.ChildRemoved:Connect(function() task.wait(0.05); ESP_UpdatePlayer(p) end)
    espEventConnections[p] = { c1, c2, c3 }
    ESP_UpdatePlayer(p)
end

local function ESP_DisconnectPlayer(p)
    if espEventConnections[p] then
        for _, c in ipairs(espEventConnections[p]) do if c then pcall(function() c:Disconnect() end) end end
        espEventConnections[p] = nil
    end
    if ESPHighlights[p] then pcall(function() ESPHighlights[p]:Destroy() end) ESPHighlights[p] = nil end
    PlayerRoles[p] = nil
end

local function ESP_Enable()
    for _, p in ipairs(Players:GetPlayers()) do if p ~= player then ESP_ConnectPlayer(p) end end
    Players.PlayerAdded:Connect(function(p) if Configs.ESP then ESP_ConnectPlayer(p) end end)
    Players.PlayerRemoving:Connect(function(p) ESP_DisconnectPlayer(p) end)
end

local function ESP_Disable()
    for _, p in ipairs(Players:GetPlayers()) do ESP_DisconnectPlayer(p) end
    ESP_ClearAll()
end

-- ==================== AUTO SHOOT CORE ====================
local function AS_HasGun()
    local char = player.Character
    if not char then return false, nil end
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then
            local n = item.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("revolver") or n:find("sheriff") then
                return true, item
            end
        end
    end
    return false, nil
end

local function AS_GetMurderer()
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local bestTarget, bestDist = nil, 400
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and PlayerRoles[p] == "Murderer" then
            local pChar = p.Character
            local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
            local pHum  = pChar and pChar:FindFirstChildOfClass("Humanoid")
            if pRoot and pHum and pHum.Health > 0 then
                local dist = (myRoot.Position - pRoot.Position).Magnitude
                if dist < bestDist then
                    bestDist   = dist
                    bestTarget = p
                end
            end
        end
    end
    return bestTarget
end
_G.AS_GetMurderer = AS_GetMurderer

-- ==================== INTERFACE (UI TRANSPARENTE / VERTICAL LIST) ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeltaAkatUniversalUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true

local uiParent = player:FindFirstChild("PlayerGui") or (gethui and gethui()) or game:GetService("CoreGui")
if uiParent:FindFirstChild("DeltaAkatUniversalUI") then
    pcall(function() uiParent.DeltaAkatUniversalUI:Destroy() end)
end
screenGui.Parent = uiParent

-- Botão de Ativar/Desativar Menu Geral
local FloatBtn = Instance.new("ImageButton", screenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0.08, 0, 0.25, 0)
FloatBtn.Image = "rbxthumb://type=Asset&id=99997714241420&w=150&h=150"
FloatBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
FloatBtn.Visible = false
FloatBtn.ZIndex = 30
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)
local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Thickness = 1.5

-- BOTÃO FLUTUANTE EXTENSO AUTO SHOOT PARA MOBILE
local AutoShootMobileBtn = Instance.new("TextButton", screenGui)
AutoShootMobileBtn.Name = "AutoShootMobileBtn"
AutoShootMobileBtn.Size = UDim2.new(0, 150, 0, 44)
AutoShootMobileBtn.Position = UDim2.new(0.78, 0, 0.55, 0)
AutoShootMobileBtn.BackgroundColor3 = Color3.fromHex("#0A0A0A")
AutoShootMobileBtn.BackgroundTransparency = 0.25
AutoShootMobileBtn.Text = "AUTO SHOOT"
AutoShootMobileBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoShootMobileBtn.Font = Enum.Font.GothamBold
AutoShootMobileBtn.TextSize = 13
AutoShootMobileBtn.Visible = false
AutoShootMobileBtn.ZIndex = 35
Instance.new("UICorner", AutoShootMobileBtn).CornerRadius = UDim.new(0, 8)
local ASButtonStroke = Instance.new("UIStroke", AutoShootMobileBtn)
ASButtonStroke.Thickness = 1.5

local mainWrapper = Instance.new("Frame")
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0.5)
mainWrapper.Size = UDim2.new(0, 420, 0, 340)
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible = false
mainWrapper.Parent = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundColor3 = Color3.fromHex("#0A0A0A")
mainFrame.BackgroundTransparency = 0.25
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.ZIndex = 5
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 9)
local frameStroke = Instance.new("UIStroke", mainFrame)
frameStroke.Color = Color3.fromHex("#1F1F1F")
frameStroke.Thickness = 1
mainFrame.Parent = mainWrapper

local topBar = Instance.new("Frame", mainFrame)
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 52)
topBar.BackgroundTransparency = 1
topBar.ZIndex = 6

local title = Instance.new("TextLabel", topBar)
title.Name = "Title"
title.Size = UDim2.new(0, 200, 0, 22)
title.Position = UDim2.new(0, 16, 0, 10)
title.BackgroundTransparency = 1
title.Text = "AKAT SCRIPTS"
title.TextColor3 = Color3.fromHex("#8B0000")
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 6

local subtitle = Instance.new("TextLabel", topBar)
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(0, 200, 0, 14)
subtitle.Position = UDim2.new(0, 16, 0, 28)
subtitle.BackgroundTransparency = 1
subtitle.Text = "MM2 SINGLE LIST EDITION"
subtitle.TextColor3 = Color3.fromRGB(160, 160, 160)
subtitle.TextSize = 9
subtitle.Font = Enum.Font.GothamMone
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 6

local searchBarFrame = Instance.new("Frame", topBar)
searchBarFrame.Name = "SearchBarFrame"
searchBarFrame.AnchorPoint = Vector2.new(1, 0.5)
searchBarFrame.Position = UDim2.new(1, -120, 0.5, 0)
searchBarFrame.Size = UDim2.new(0, 0, 0, 26)
searchBarFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
searchBarFrame.ClipsDescendants = true
searchBarFrame.ZIndex = 7
Instance.new("UICorner", searchBarFrame).CornerRadius = UDim.new(0, 13)
local searchStroke = Instance.new("UIStroke", searchBarFrame)
searchStroke.Color = Color3.fromHex("#252525")

local searchTextBox = Instance.new("TextBox", searchBarFrame)
searchTextBox.Name = "SearchTextBox"
searchTextBox.Size = UDim2.new(1, -20, 1, 0)
searchTextBox.Position = UDim2.new(0, 12, 0, 0)
searchTextBox.BackgroundTransparency = 1
searchTextBox.PlaceholderText = "Pesquisar..."
searchTextBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
searchTextBox.Text = ""
searchTextBox.TextColor3 = Color3.fromRGB(240, 240, 240)
searchTextBox.Font = Enum.Font.Gotham
searchTextBox.TextSize = 11
searchTextBox.TextXAlignment = Enum.TextXAlignment.Left
searchTextBox.ZIndex = 8

local topButtons = Instance.new("Frame", topBar)
topButtons.Size = UDim2.new(0, 100, 0, 26)
topButtons.Position = UDim2.new(1, -110, 0.5, -13)
topButtons.BackgroundTransparency = 1
topButtons.ZIndex = 6

local UIListTop = Instance.new("UIListLayout", topButtons)
UIListTop.FillDirection = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding = UDim.new(0, 6)

local LanguageBtn = Instance.new("TextButton", topButtons)
LanguageBtn.Name = "LanguageBtn"
LanguageBtn.Size = UDim2.new(0, 26, 0, 26)
LanguageBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
LanguageBtn.Text = currentLanguage
LanguageBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
LanguageBtn.Font = Enum.Font.GothamBold
LanguageBtn.TextSize = 10
LanguageBtn.ZIndex = 7
Instance.new("UICorner", LanguageBtn).CornerRadius = UDim.new(0, 5)

local SearchBtn = Instance.new("TextButton", topButtons)
SearchBtn.Name = "SearchBtn"
SearchBtn.Size = UDim2.new(0, 26, 0, 26)
SearchBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
SearchBtn.Text = "🔍"
SearchBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
SearchBtn.TextSize = 10
SearchBtn.ZIndex = 7
Instance.new("UICorner", SearchBtn).CornerRadius = UDim.new(0, 5)

local MinimizeBtn = Instance.new("TextButton", topButtons)
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.Size = UDim2.new(0, 26, 0, 26)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
MinimizeBtn.Text = "−"
MinimizeBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 12
MinimizeBtn.ZIndex = 7
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 5)

local CloseBtn = Instance.new("TextButton", topButtons)
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.ZIndex = 7
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

local div = Instance.new("Frame", mainFrame)
div.Size = UDim2.new(1, 0, 0, 1)
div.Position = UDim2.new(0, 0, 0, 52)
div.BackgroundColor3 = Color3.fromHex("#1F1F1F")
div.BorderSizePixel = 0
div.ZIndex = 6

local togglesContainer = Instance.new("ScrollingFrame", mainFrame)
togglesContainer.Name = "TogglesContainer"
togglesContainer.Size = UDim2.new(1, -24, 1, -64)
togglesContainer.Position = UDim2.new(0, 12, 0, 58)
togglesContainer.BackgroundTransparency = 1
togglesContainer.BorderSizePixel = 0
togglesContainer.ScrollBarThickness = 3
togglesContainer.ScrollBarImageColor3 = Color3.fromHex("#8B0000")
togglesContainer.ZIndex = 6
pcall(function() togglesContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y end)

local containerLayout = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
containerLayout.Padding = UDim.new(0, 6)

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
confirmLabel.ZIndex = 51

local btnYes = Instance.new("TextButton", confirmFrame)
btnYes.Size = UDim2.new(0, 110, 0, 34)
btnYes.Position = UDim2.new(0.5, -115, 0.55, 0)
btnYes.BackgroundColor3 = Color3.fromHex("#8B0000")
btnYes.TextColor3 = Color3.fromRGB(255, 255, 255)
btnYes.Font = Enum.Font.GothamMedium
btnYes.TextSize = 12
btnYes.ZIndex = 51
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 6)

local btnNo = Instance.new("TextButton", confirmFrame)
btnNo.Size = UDim2.new(0, 110, 0, 34)
btnNo.Position = UDim2.new(0.5, 5, 0.55, 0)
btnNo.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
btnNo.TextColor3 = Color3.fromRGB(180, 180, 180)
btnNo.Font = Enum.Font.GothamMedium
btnNo.TextSize = 12
btnNo.ZIndex = 51
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 6)

-- ==================== ANIMACAO DOS GRADIENTES ====================
local function AplicarEfeitoGradienteLoop(strokeObj)
    local gradient = Instance.new("UIGradient", strokeObj)
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHex("#8B0000")),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromHex("#8B0000"))
    })
    task.spawn(function()
        local rot = 0
        while task.wait() do
            if not gradient.Parent then break end
            rot = (rot + 3.5) % 360
            gradient.Rotation = rot
        end
    end)
end

AplicarEfeitoGradienteLoop(FloatStroke)
AplicarEfeitoGradienteLoop(ASButtonStroke)

-- ==================== RECURSOS DA LISTA INTERNA ====================
local function RegistrarTransparencias(objeto)
    if originalTrans[objeto] then return end
    if objeto:IsA("Frame") or objeto:IsA("ScrollingFrame") then
        originalTrans[objeto] = { BackgroundTransparency = objeto.BackgroundTransparency }
    elseif objeto:IsA("TextLabel") or objeto:IsA("TextButton") or objeto:IsA("TextBox") then
        originalTrans[objeto] = {
            TextTransparency = objeto.TextTransparency,
            BackgroundTransparency = objeto.BackgroundTransparency
        }
    elseif objeto:IsA("UIStroke") then
        originalTrans[objeto] = { Transparency = objeto.Transparency }
    end
end

local function AplicarFadeSincronizado(raiz, fadeOut, duracao)
    local info = TweenInfo.new(duracao, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local function tratarObjeto(obj)
        RegistrarTransparencias(obj)
        local orig = originalTrans[obj]
        if not orig then return end
        if orig.BackgroundTransparency then
            local t = fadeOut and 1 or (obj == mainFrame and 0.25 or orig.BackgroundTransparency)
            if duracao == 0 then obj.BackgroundTransparency = t else TweenService:Create(obj, info, {BackgroundTransparency = t}):Play() end
        end
        if orig.TextTransparency then
            local t = fadeOut and 1 or orig.TextTransparency
            if duracao == 0 then obj.TextTransparency = t else TweenService:Create(obj, info, {TextTransparency = t}):Play() end
        end
        if orig.Transparency then
            local t = fadeOut and 1 or orig.Transparency
            if duracao == 0 then obj.Transparency = t else TweenService:Create(obj, info, {Transparency = t}):Play() end
        end
    end
    tratarObjeto(raiz)
    for _, desc in ipairs(raiz:GetDescendants()) do tratarObjeto(desc) end
end

local headersCriados = {}
local function CriarCabecalhoSecao(parent, categoryKey, order)
    local hFrame = Instance.new("Frame")
    hFrame.Name = "Header_" .. categoryKey
    hFrame.Size = UDim2.new(1, 0, 0, 24)
    hFrame.BackgroundTransparency = 1
    hFrame.LayoutOrder = order
    hFrame.Parent = parent

    local textLabel = Instance.new("TextLabel", hFrame)
    textLabel.Name = "Text"
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = Locales[currentLanguage].Headers[categoryKey] or categoryKey
    textLabel.TextColor3 = Color3.fromHex("#8B0000")
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 10
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Bottom
    
    headersCriados[categoryKey] = textLabel
end

local function AtualizarIdioma()
    local langData = Locales[currentLanguage]
    if not langData then return end
    searchTextBox.PlaceholderText = langData.SearchPlaceholder
    confirmLabel.Text = langData.ConfirmCloseTitle
    btnYes.Text = langData.ConfirmBtn
    btnNo.Text  = langData.CancelBtn
    
    for catKey, label in pairs(headersCriados) do
        if langData.Headers[catKey] then label.Text = langData.Headers[catKey] end
    end

    for _, child in ipairs(togglesContainer:GetChildren()) do
        if child:IsA("Frame") and child:GetAttribute("ConfigKey") then
            local configKey = child:GetAttribute("ConfigKey")
            if langData.Options[configKey] then
                local t = child:FindFirstChild("Title")
                local d = child:FindFirstChild("Description")
                if t then t.Text = langData.Options[configKey].Title end
                if d then d.Text = langData.Options[configKey].Desc end
            end
        end
    end
end

local function FiltrarListaGlobal(query)
    local text = query:lower()
    for _, child in ipairs(togglesContainer:GetChildren()) do
        if child:IsA("Frame") then
            if child:GetAttribute("ConfigKey") then
                local t = child:FindFirstChild("Title")
                local match = (text == "") or (t and t.Text:lower():find(text) ~= nil)
                child.Visible = match
            end
        end
    end
end

local ConfigCallbacks = {
    AutoShoot = function(enabled)
        AutoShootMobileBtn.Visible = enabled
    end,
    ESP = function(enabled)
        if enabled then ESP_Enable() else ESP_Disable() end
    end,
    SafeSpot = function(enabled)
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if enabled then
            lastPositionBeforeSafeSpot = root.CFrame
            if not safePlatform or not safePlatform.Parent then
                safePlatform = Instance.new("Part")
                safePlatform.Name = "AkatSafePlatform"
                safePlatform.Size = Vector3.new(15, 1, 15)
                safePlatform.Position = Vector3.new(root.Position.X, 900, root.Position.Z)
                safePlatform.Anchored = true
                safePlatform.Transparency = 0.5
                safePlatform.Material = Enum.Material.ForceField
                safePlatform.Color = Color3.fromHex("#8B0000")
                safePlatform.Parent = workspace
            end
            root.CFrame = safePlatform.CFrame * CFrame.new(0, 3, 0)
        else
            if safePlatform then safePlatform:Destroy() safePlatform = nil end
            if lastPositionBeforeSafeSpot then root.CFrame = lastPositionBeforeSafeSpot lastPositionBeforeSafeSpot = nil end
        end
    end,
    AutoCollect = function(enabled)
        if not enabled then currentCollectTarget = nil end
    end
}

local function createToggleInList(parent, configKey, category, order)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = "Toggle_" .. configKey
    toggleFrame.Size = UDim2.new(1, 0, 0, 52)
    toggleFrame.BackgroundColor3 = Color3.fromHex("#0F0F0F")
    toggleFrame.BackgroundTransparency = 0.1
    toggleFrame.LayoutOrder = order
    toggleFrame:SetAttribute("ConfigKey", configKey)
    toggleFrame.Parent = parent
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 6)
    
    local strk = Instance.new("UIStroke", toggleFrame)
    strk.Color = Color3.fromHex("#1F1F1F")

    local titleLabel = Instance.new("TextLabel", toggleFrame)
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(0.75, 0, 0, 16)
    titleLabel.Position = UDim2.new(0, 12, 0, 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromHex("#EAEAEA")
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local descLabel = Instance.new("TextLabel", toggleFrame)
    descLabel.Name = "Description"
    descLabel.Size = UDim2.new(0.75, 0, 0, 24)
    descLabel.Position = UDim2.new(0, 12, 0, 22)
    descLabel.BackgroundTransparency = 1
    descLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 9
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.TextWrapped = true

    local switchTrack = Instance.new("Frame", toggleFrame)
    switchTrack.Size = UDim2.new(0, 36, 0, 18)
    switchTrack.Position = UDim2.new(1, -48, 0.5, -9)
    switchTrack.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
    Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)

    local switchCircle = Instance.new("Frame", switchTrack)
    switchCircle.Size = UDim2.new(0, 12, 0, 12)
    switchCircle.Position = Configs[configKey] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
    switchCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", switchCircle).CornerRadius = UDim.new(1, 0)

    local triggerBtn = Instance.new("TextButton", toggleFrame)
    triggerBtn.Size = UDim2.new(1, 0, 1, 0)
    triggerBtn.BackgroundTransparency = 1
    triggerBtn.Text = ""

    triggerBtn.MouseButton1Click:Connect(function()
        Configs[configKey] = not Configs[configKey]
        local targetPos   = Configs[configKey] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        local targetColor = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
        local anim = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        
        TweenService:Create(switchCircle, anim, {Position = targetPos}):Play()
        TweenService:Create(switchTrack, anim, {BackgroundColor3 = targetColor}):Play()
        if ConfigCallbacks[configKey] then task.spawn(ConfigCallbacks[configKey], Configs[configKey]) end
    end)
end

-- ==================== INICIALIZACAO DE ELEMENTOS DA LISTA ====================
local layoutCounter = 1

CriarCabecalhoSecao(togglesContainer, "Combat", layoutCounter) layoutCounter = layoutCounter + 1
createToggleInList(togglesContainer, "AutoShoot", "Combat", layoutCounter) layoutCounter = layoutCounter + 1
createToggleInList(togglesContainer, "Reach", "Combat", layoutCounter) layoutCounter = layoutCounter + 1

CriarCabecalhoSecao(togglesContainer, "Visuals", layoutCounter) layoutCounter = layoutCounter + 1
createToggleInList(togglesContainer, "ESP", "Visuals", layoutCounter) layoutCounter = layoutCounter + 1

CriarCabecalhoSecao(togglesContainer, "Movement", layoutCounter) layoutCounter = layoutCounter + 1
createToggleInList(togglesContainer, "Speed", "Movement", layoutCounter) layoutCounter = layoutCounter + 1
createToggleInList(togglesContainer, "AntiFling", "Movement", layoutCounter) layoutCounter = layoutCounter + 1

CriarCabecalhoSecao(togglesContainer, "Teleports", layoutCounter) layoutCounter = layoutCounter + 1
createToggleInList(togglesContainer, "TpToGun", "Teleports", layoutCounter) layoutCounter = layoutCounter + 1
createToggleInList(togglesContainer, "SafeSpot", "Teleports", layoutCounter) layoutCounter = layoutCounter + 1

CriarCabecalhoSecao(togglesContainer, "Misc", layoutCounter) layoutCounter = layoutCounter + 1
createToggleInList(togglesContainer, "AutoCollect", "Misc", layoutCounter) layoutCounter = layoutCounter + 1
createToggleInList(togglesContainer, "ChatRoles", "Misc", layoutCounter) layoutCounter = layoutCounter + 1

-- ==================== MOBILE AUTO SHOOT CLICK CONNECTOR ====================
AutoShootMobileBtn.MouseButton1Click:Connect(function()
    local hasGun, gunTool = AS_HasGun()
    if hasGun and gunTool then
        pcall(function()
            gunTool:Activate()
        end)
    end
end)

-- ==================== SISTEMA DE LIMPEZA E LOGICA DOS BOTOES DA WINDOW ====================
local function LimparEDesligarAbsolutamente()
    if hbConnection then hbConnection:Disconnect() hbConnection = nil end
    if renderConnection then renderConnection:Disconnect() renderConnection = nil end
    for k in pairs(Configs) do Configs[k] = false end
    ESP_Disable()
    AutoShootMobileBtn.Visible = false
    if safePlatform then pcall(function() safePlatform:Destroy() end) safePlatform = nil end
    pcall(function()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 hum.PlatformStand = false end
        
        local knife = char and (char:FindFirstChild("Knife") or char:FindFirstChild("Faca"))
        if knife and knife:FindFirstChild("Handle") then
            local origSize = knife.Handle:GetAttribute("OrigSize")
            if origSize then
                knife.Handle.Size = origSize
                knife.Handle.CanCollide = true
                knife.Handle.Massless = false
                knife.Handle:SetAttribute("OrigSize", nil)
            end
        end
    end)
end

local function AlternarConfirmacao(exibir)
    isConfirmOpen = exibir
    if exibir then
        if not confirmBlur then
            confirmBlur = Instance.new("BlurEffect")
            confirmBlur.Size = 0
            confirmBlur.Parent = Lighting
        end
        confirmFrame.Visible = true
        AplicarFadeSincronizado(confirmFrame, true, 0)
        AplicarFadeSincronizado(confirmFrame, false, 0.15)
        TweenService:Create(confirmBlur, TweenInfo.new(0.15), {Size = 12}):Play()
    else
        AplicarFadeSincronizado(confirmFrame, true, 0.15)
        if confirmBlur then TweenService:Create(confirmBlur, TweenInfo.new(0.15), {Size = 0}):Play() end
        task.delay(0.15, function()
            if not isConfirmOpen then
                confirmFrame.Visible = false
                if confirmBlur then confirmBlur:Destroy() confirmBlur = nil end
            end
        end)
    end
end

local function executarMinimizacao()
    if isConfirmOpen then return end
    isMinimized = not isMinimized
    local windowAnim = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if isMinimized then
        AplicarFadeSincronizado(togglesContainer, true, 0.1)
        TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 420, 0, 52)}):Play()
        task.delay(0.1, function() if isMinimized then togglesContainer.Visible = false div.Visible = false end end)
    else
        div.Visible = true
        togglesContainer.Visible = true
        AplicarFadeSincronizado(togglesContainer, true, 0)
        TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 420, 0, 340)}):Play()
        AplicarFadeSincronizado(togglesContainer, false, 0.2)
    end
end

local function alternarVisibilidadeMenu()
    menuAberto = not menuAberto
    local tempoAnim = 0.15
    local windowAnim = TweenInfo.new(tempoAnim, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if menuAberto then
        mainWrapper.Visible = true
        togglesContainer.Visible = false
        div.Visible = false
        mainWrapper.Size = UDim2.new(0, 380, 0, isMinimized and 40 or 300)
        AplicarFadeSincronizado(mainWrapper, true, 0)
        AplicarFadeSincronizado(mainWrapper, false, tempoAnim)
        local pop = TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 420, 0, isMinimized and 52 or 340)})
        pop:Play()
        pop.Completed:Connect(function()
            if menuAberto and not isMinimized and not isConfirmOpen then
                togglesContainer.Visible = true
                div.Visible = true
                AplicarFadeSincronizado(togglesContainer, false, 0.1)
            end
        end)
    else
        togglesContainer.Visible = false
        div.Visible = false
        AplicarFadeSincronizado(mainWrapper, true, tempoAnim)
        local hide = TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 380, 0, isMinimized and 40 or 300)})
        hide:Play()
        hide.Completed:Connect(function() if not menuAberto then mainWrapper.Visible = false end end)
    end
end

local function ConfigurarArrastarAkat(inst)
    local drag = false
    local startPos, dragStart, dragInput
    inst.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = true
            dragStart = input.Position
            startPos = inst.Position
            dragInput = input
            local connection
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then drag = false connection:Disconnect() end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if drag and input == dragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            inst.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function ExecutarIntroAkat()
    local Blur = Instance.new("BlurEffect")
    Blur.Size = 0
    Blur.Parent = Lighting

    local IntroFrame = Instance.new("Frame", screenGui)
    IntroFrame.Size = UDim2.new(1, 0, 1, 0)
    IntroFrame.BackgroundColor3 = Color3.fromHex("#0A0A0A")
    IntroFrame.BackgroundTransparency = 1
    IntroFrame.ZIndex = 500

    local IntroText = Instance.new("TextLabel", IntroFrame)
    IntroText.AnchorPoint = Vector2.new(0.5, 0.5)
    IntroText.Size = UDim2.new(0, 500, 0, 80)
    IntroText.Position = UDim2.new(0.5, 0, 0.5, 0)
    IntroText.BackgroundTransparency = 1
    IntroText.Font = Enum.Font.GothamBold
    IntroText.TextSize = 24
    IntroText.RichText = true
    IntroText.Text = Locales[currentLanguage].Intro
    IntroText.TextTransparency = 1

    TweenService:Create(IntroFrame, TweenInfo.new(0.4), {BackgroundTransparency = 0.2}):Play()
    TweenService:Create(IntroText, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.4), {Size = 12}):Play()
    task.wait(1.8)

    TweenService:Create(IntroText, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    TweenService:Create(IntroFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.3), {Size = 0}):Play()
    task.wait(0.3)
    IntroFrame:Destroy()
    Blur:Destroy()

    mainWrapper.Visible = true
    FloatBtn.Visible = true
    AplicarFadeSincronizado(mainWrapper, true, 0)
    AplicarFadeSincronizado(mainWrapper, false, 0.15)
    AtualizarIdioma()
end

-- ==================== SEÇÃO DOS BOTÕES SUPERIORES E INPUTS ====================
local searchOpen = false
SearchBtn.MouseButton1Click:Connect(function()
    searchOpen = not searchOpen
    local info = TweenInfo.new(0.25, Enum.EasingStyle.Quint)
    if searchOpen then
        TweenService:Create(searchBarFrame, info, {Size = UDim2.new(0, 140, 0, 26)}):Play()
        searchTextBox:CaptureFocus()
    else
        searchTextBox.Text = ""
        TweenService:Create(searchBarFrame, info, {Size = UDim2.new(0, 0, 0, 26)}):Play()
        searchTextBox:ReleaseFocus()
        FiltrarListaGlobal("")
    end
end)

searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
    FiltrarListaGlobal(searchTextBox.Text)
end)

LanguageBtn.MouseButton1Click:Connect(function()
    currentLanguage = (currentLanguage == "PT") and "EN" or "PT"
    LanguageBtn.Text = currentLanguage
    AtualizarIdioma()
end)

MinimizeBtn.MouseButton1Click:Connect(executarMinimizacao)
CloseBtn.MouseButton1Click:Connect(function() AlternarConfirmacao(true) end)
btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)
btnYes.MouseButton1Click:Connect(function()
    LimparEDesligarAbsolutamente()
    screenGui:Destroy()
end)

FloatBtn.MouseButton1Click:Connect(alternarVisibilidadeMenu)
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and (input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightShift) then
        alternarVisibilidadeMenu()
    end
end)

ConfigurarArrastarAkat(mainWrapper)
ConfigurarArrastarAkat(FloatBtn)
ConfigurarArrastarAkat(AutoShootMobileBtn)

-- ==================== PERSISTENT BACKEND SCANNERS ====================
task.spawn(function()
    while true do
        local gunFound, knifeFound = false, false
        local currentMurderer, currentSheriff = nil, nil
        
        for _, p in ipairs(Players:GetPlayers()) do
            local role = PlayerRoles[p] or ESP_DetectRole(p)
            if role == "Murderer" then currentMurderer = p end
            if role == "Sheriff"  then currentSheriff  = p end
            
            if p.Character then
                if p.Character:FindFirstChild("Gun") or p.Backpack:FindFirstChild("Gun") then gunFound = true end
                if p.Character:FindFirstChild("Knife") or p.Backpack:FindFirstChild("Knife") then knifeFound = true end
            end
            if Configs.ESP and p ~= player then ESP_UpdatePlayer(p) end
        end
        
        local gunDropExists = workspace:FindFirstChild("GunDrop", true) ~= nil
        if gunDropExists then gunDroppedThisRound = true end
        if not gunFound and not gunDropExists and not knifeFound then gunDroppedThisRound = false end

        if Configs.ChatRoles and (currentMurderer or currentSheriff) and not announcedThisRound then
            announcedThisRound = true
            local msg = "[AKAT SYSTEM] "
            if currentMurderer then msg = msg .. "Assassin: @" .. currentMurderer.Name .. " " end
            if currentSheriff then msg = msg .. "| Sheriff: @" .. currentSheriff.Name end
            
            local textChat = game:GetService("TextChatService")
            pcall(function()
                if textChat.ChatVersion == Enum.ChatVersion.TextChatService then
                    local channel = textChat.TextChannels:FindFirstChild("RBXGeneral")
                    if channel then channel:SendAsync(msg) end
                else
                    game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All")
                end
            end)
        end
        if not currentMurderer and not currentSheriff then announcedThisRound = false end
        task.wait(0.5)
    end
end)

-- ==================== HEARTBEAT SYSTEMS (REACH, MOVEMENT, AUTOCOLLECT) ====================
local function ObterArmaCaida(root)
    local gun = workspace:FindFirstChild("GunDrop", true)
    if gun then
        local targetPart = gun:IsA("BasePart") and gun or (gun:FindFirstChildOfClass("BasePart") or gun:FindFirstChild("Handle"))
        if targetPart and (root.Position - targetPart.Position).Magnitude < 1200 then return targetPart end
    end
    return nil
end

local function ObterMoedaProxima(root)
    local closestCoin, closestDist = nil, math.huge
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and d.Transparency < 1 then
            local name = d.Name:lower()
            if name:find("coin") or name:find("moeda") or name:find("gold") or name == "snowflake" or name:find("token") then
                if not d:IsDescendantOf(Players) and not d:FindFirstAncestorOfClass("Tool") then
                    local dist = (root.Position - d.Position).Magnitude
                    if dist < closestDist and dist < 1200 then closestDist = dist closestCoin = d end
                end
            end
        end
    end
    return closestCoin
end

hbConnection = RunService.Heartbeat:Connect(function(dt)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    if Configs.Reach then
        pcall(function()
            local knife = char:FindFirstChild("Knife") or char:FindFirstChild("Faca")
            if knife and knife:FindFirstChild("Handle") then
                local h = knife.Handle
                if not h:GetAttribute("OrigSize") then
                    h:SetAttribute("OrigSize", h.Size)
                end
                h.Massless = true
                h.CanCollide = false
                h.Size = Vector3.new(15, 15, 15)
            end
        end)
    else
        pcall(function()
            local knife = char:FindFirstChild("Knife") or char:FindFirstChild("Faca")
            if knife and knife:FindFirstChild("Handle") then
                local h = knife.Handle
                local orig = h:GetAttribute("OrigSize")
                if orig then
                    h.Size = orig
                    h.CanCollide = true
                    h.Massless = false
                    h:SetAttribute("OrigSize", nil)
                end
            end
        end)
    end

    if Configs.Speed then hum.WalkSpeed = 23 elseif hum.WalkSpeed == 23 then hum.WalkSpeed = 16 end

    if Configs.AntiFling then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                for _, part in ipairs(p.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                        pcall(function() part.AssemblyLinearVelocity = Vector3.new(0,0,0) part.AssemblyAngularVelocity = Vector3.new(0,0,0) end)
                    end
                end
            end
        end
    end

    if Configs.TpToGun and (PlayerRoles[player] or ESP_DetectRole(player)) ~= "Murderer" then
        if not (player.Backpack:FindFirstChild("Gun") or char:FindFirstChild("Gun")) then
            local drop = ObterArmaCaida(root)
            if drop and not hasTeleportedToGun then
                hasTeleportedToGun = true
                originalPositionBeforeGun = root.CFrame
                root.CFrame = drop.CFrame * CFrame.new(0, 1.5, 0)
                task.spawn(function()
                    task.wait(0.3)
                    if originalPositionBeforeGun and Configs.TpToGun then root.CFrame = originalPositionBeforeGun end
                    task.wait(1.5)
                    hasTeleportedToGun = false
                end)
            end
        end
    end

    if Configs.AutoCollect then
        if currentCollectTarget and (not currentCollectTarget.Parent or currentCollectTarget.Transparency >= 1) then currentCollectTarget = nil end
        if not currentCollectTarget and os.clock() - lastCoinSearch > 0.05 then
            lastCoinSearch = os.clock()
            currentCollectTarget = ObterMoedaProxima(root)
        end

        if currentCollectTarget then
            wasAutoCollecting = true
            hum.PlatformStand = true
            for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
            
            local tPos = currentCollectTarget.Position
            local cPos = root.Position
            local dist = (tPos - cPos).Magnitude
            root.AssemblyLinearVelocity = Vector3.new(0,0,0)

            if dist > 1 then
                local moveAmt = 28 * dt
                root.CFrame = CFrame.new(cPos + (tPos - cPos).Unit * (moveAmt >= dist and dist or moveAmt))
            else
                root.CFrame = CFrame.new(tPos)
                if firetouchinterest then firetouchinterest(root, currentCollectTarget, 0) firetouchinterest(root, currentCollectTarget, 1) end
            end
        end
    else
        if wasAutoCollecting then
            wasAutoCollecting = false
            hum.PlatformStand = false
            root.AssemblyLinearVelocity = Vector3.new(0,0,0)
        end
    end
end)

task.spawn(ExecutarIntroAkat)
