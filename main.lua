-- [[
--     AKAT MM2 SCRIPT [BETA v2.5] - ESP & AUTOSHOOT REWRITTEN + ANTI-BAN
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==================== ANTI-BAN / ANTI-KICK INTEGRADO ====================
task.spawn(function()
    local gmt = getrawmetatable and getrawmetatable(game)
    if gmt and setreadonly and hookfunction then
        setreadonly(gmt, false)
        local oldIndex = gmt.__index
        local oldNamecall = gmt.__namecall

        gmt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if tostring(method):lower() == "kick" and self == player then
                warn("[AKAT ANTI-BAN] Tentativa de Kick bloqueada com sucesso!")
                return nil
            end
            return oldNamecall(self, ...)
        end)

        gmt.__index = newcclosure(function(self, key)
            if tostring(key):lower() == "kick" and self == player then
                return newcclosure(function()
                    warn("[AKAT ANTI-BAN] Tentativa de chamada de Kick indireta bloqueada!")
                end)
            end
            return oldIndex(self, key)
        end)
        setreadonly(gmt, true)
    end

    local function applyBypass(character)
        if not character then return end
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            if hookproperty then
                pcall(function()
                    hookproperty(humanoid, "WalkSpeed", 16)
                end)
            end
        end
    end

    player.CharacterAdded:Connect(applyBypass)
    if player.Character then applyBypass(player.Character) end
end)

-- ==================== 1. CONFIGURAÇÕES E LOCALES ESTÁTICOS ====================
local Configs = {
    ESP = false,
    AutoShoot = false,
    Speed = false,
    Reach = false,
    AntiFling = false,
    TpToGun = false,
    SafeSpot = false,
    AutoCollect = false,
    ChatRoles = false
}

local Locales = {
    PT = {
        SearchPlaceholder = "Pesquisar...",
        ConfirmCloseTitle = "Deseja fechar o script?",
        ConfirmBtn = "Confirmar",
        CancelBtn = "Cancelar",
        Tabs = {
            Combat = "Combate",
            Visuals = "Visuais",
            Movement = "Movimento",
            Teleports = "Teleportes",
            Misc = "Diversos"
        },
        Options = {
            AutoShoot = {
                Title = "Atirar no Murder",
                Desc = "Mira e dispara a arma automaticamente no Assassino ao equipá-la."
            },
            Reach = {
                Title = "Alcance da Faca",
                Desc = "Aumenta consideravelmente o alcance de ataque com a sua faca."
            },
            ESP = {
                Title = "ESP Jogadores",
                Desc = "Destaca na parede os jogadores de acordo com suas funções."
            },
            Speed = {
                Title = "Velocidade",
                Desc = "Aumenta levemente a velocidade do personagem para 23."
            },
            AntiFling = {
                Title = "Anti-Arremesso",
                Desc = "Bloqueia colisões que tentem te empurrar ou arremessar."
            },
            TpToGun = {
                Title = "Teleportar p/ Arma",
                Desc = "Teletransporta para a arma dropada e retorna ao local original rapidamente."
            },
            SafeSpot = {
                Title = "Lugar Seguro",
                Desc = "Cria uma plataforma invisível no céu para ficar totalmente seguro."
            },
            AutoCollect = {
                Title = "Coletar Moedas",
                Desc = "Voa suavemente coletando cada moeda com cooldown para evitar kick."
            },
            ChatRoles = {
                Title = "Revelar Funções",
                Desc = "Envia de forma limpa no chat quem é o Assassino e o Xerife."
            }
        },
        Intro = '<font color="#FFFFFF">Scripts por | </font><font color="#8B0000">Comunidade AKAT</font>'
    },
    EN = {
        SearchPlaceholder = "Search...",
        ConfirmCloseTitle = "Do you want to close the script?",
        ConfirmBtn = "Confirm",
        CancelBtn = "Cancel",
        Tabs = {
            Combat = "Combat",
            Visuals = "Visuals",
            Movement = "Movement",
            Teleports = "Teleports",
            Misc = "Misc"
        },
        Options = {
            AutoShoot = {
                Title = "Shoot Murderer",
                Desc = "Automatically aims and fires the gun at the Murderer when held."
            },
            Reach = {
                Title = "Knife Reach",
                Desc = "Significantly increases your knife attack reach."
            },
            ESP = {
                Title = "Player ESP",
                Desc = "Highlights players through walls based on their active roles."
            },
            Speed = {
                Title = "WalkSpeed",
                Desc = "Slightly increases player walkspeed up to 23."
            },
            AntiFling = {
                Title = "Anti-Fling",
                Desc = "Disables collisions to prevent other players from flinging you."
            },
            TpToGun = {
                Title = "TP to Gun",
                Desc = "Teleports to the dropped gun and instantly returns to your spot."
            },
            SafeSpot = {
                Title = "Safe Spot",
                Desc = "Teleports you to an invisible sky platform to remain completely safe."
            },
            AutoCollect = {
                Title = "Auto Collect",
                Desc = "Smoothly collects each coin with cooldown to avoid anti-cheat kicks."
            },
            ChatRoles = {
                Title = "Reveal Roles",
                Desc = "Automatically sends a message in public chat revealing active roles."
            }
        },
        Intro = '<font color="#FFFFFF">Scripts by | </font><font color="#8B0000">AKAT Community</font>'
    },
    ES = {
        SearchPlaceholder = "Buscar...",
        ConfirmCloseTitle = "¿Deseas cerrar el script?",
        ConfirmBtn = "Confirmar",
        CancelBtn = "Cancelar",
        Tabs = {
            Combat = "Combate",
            Visuals = "Visuales",
            Movement = "Movimiento",
            Teleports = "Teleportes",
            Misc = "Varios"
        },
        Options = {
            AutoShoot = {
                Title = "Disparar al Asesino",
                Desc = "Apunta y dispara la pistola automáticamente al Asesino al equiparla."
            },
            Reach = {
                Title = "Alcance del Cuchillo",
                Desc = "Aumenta considerablemente el alcance de ataque con tu cuchillo."
            },
            ESP = {
                Title = "ESP Jugadores",
                Desc = "Resalta a los jugadores a través de las paredes según sus roles."
            },
            Speed = {
                Title = "Velocidad",
                Desc = "Aumenta ligeramente la velocidad del personaje a 23."
            },
            AntiFling = {
                Title = "Anti-Fling",
                Desc = "Bloquea colisiones para evitar que te empujen o lancen."
            },
            TpToGun = {
                Title = "TP a la Arma",
                Desc = "Teletransporta a la pistola tirada y regresa a tu lugar velozmente."
            },
            SafeSpot = {
                Title = "Lugar Seguro",
                Desc = "Te teletransporta a una plataforma invisible en el cielo para estar a salvo."
            },
            AutoCollect = {
                Title = "Auto Monedas",
                Desc = "Recoge monedas suavemente con cooldown para evitar expulsión."
            },
            ChatRoles = {
                Title = "Revelar Roles",
                Desc = "Envía automáticamente en el chat quién es el Asesino y el Sheriff."
            }
        },
        Intro = '<font color="#FFFFFF">Scripts por | </font><font color="#8B0000">Comunidad AKAT</font>'
    }
}

-- ==================== 2. VARIÁVEIS DE ESTADO GLOBAIS ====================
local currentLanguage = "EN"
local activeTab = "Combat"
local tabButtons = {}
local menuAberto = true
local isMinimized = false
local hbConnection = nil
local renderConnection = nil
local confirmBlur = nil
local isConfirmOpen = false
local wasMinimizedBeforeConfirm = false

local safePlatform = nil
local lastPositionBeforeSafeSpot = nil
local hasTeleportedToGun = false
local originalPositionBeforeGun = nil
local currentCollectTarget = nil
local lastCoinSearch = 0
local wasAutoCollecting = false
local lastCoinCollectTime = 0       -- cooldown entre moedas (anti-kick)
local COIN_COLLECT_COOLDOWN = 0.7   -- segundos entre coletas
local COIN_FLY_SPEED = 28           -- studs/s (seguro vs anticheat)

local originalTrans = {}

-- ============================================================
--  ESP v2 - SISTEMA COMPLETO REESCRITO
-- ============================================================
-- Papéis detectados em tempo real, mapeados por Player object.
-- Categorias: "Murderer" | "Sheriff" | "Hero" | "Innocent"
-- "Hero" = sobrevivente que pegou a arma dropada do Sheriff morto.
-- ============================================================

local ESPRoles = {}          -- [player] = "Murderer"|"Sheriff"|"Hero"|"Innocent"
local ESPHighlights = {}     -- [player] = Highlight instance

local ESP_COLORS = {
    Murderer = { fill = Color3.fromRGB(220,  30,  30), outline = Color3.fromRGB(255,   0,   0) },
    Sheriff  = { fill = Color3.fromRGB(  0,  80, 220), outline = Color3.fromRGB(  0, 110, 255) },
    Hero     = { fill = Color3.fromRGB(220, 180,   0), outline = Color3.fromRGB(255, 215,   0) },
    Innocent = { fill = Color3.fromRGB(  0, 180,  60), outline = Color3.fromRGB(  0, 255,  80) },
}

-- Retorna true se a tool parece uma faca (Murder)
local function IsMurderTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local n = tool.Name:lower()
    return n:find("knife") or n:find("faca") or n:find("sword") or n:find("cutelo") or n:find("blade")
end

-- Retorna true se a tool parece uma arma de fogo (Sheriff / Hero)
local function IsGunTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local n = tool.Name:lower()
    return n:find("gun") or n:find("pistol") or n:find("revolver") or n:find("sheriff") or n:find("arma") or n:find("rifle")
end

-- Detecta o papel real de um jogador neste momento
local function DetectRoleNow(p)
    if not p or not p.Parent then return "Innocent" end

    -- Verifica atributos nativos do MM2 primeiro (mais confiável para o início de round)
    local nativeRole = p:GetAttribute("Role") or p:GetAttribute("role") or p:GetAttribute("Funcao") or p:GetAttribute("MM2Role")
    if nativeRole then
        local r = tostring(nativeRole):lower()
        if r:find("murder") or r:find("assassin") then return "Murderer" end
        if r:find("sheriff") or r:find("xerife")   then return "Sheriff"  end
        if r:find("hero")                           then return "Hero"     end
    end

    -- Verifica tools no character e backpack
    local function scanContainer(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if IsMurderTool(item) then return "Murderer" end
            if IsGunTool(item)    then
                -- Se o atributo nativo diz que é Inocente mas tem arma → é Hero
                if nativeRole and tostring(nativeRole):lower():find("innoc") then
                    return "Hero"
                end
                return "Sheriff"
            end
        end
        return nil
    end

    local roleChar = scanContainer(p.Character)
    if roleChar then return roleChar end
    local roleBP = scanContainer(p:FindFirstChild("Backpack"))
    if roleBP then return roleBP end

    return "Innocent"
end

-- Cria ou atualiza o Highlight de um jogador
local function ESP_ApplyHighlight(p)
    if not p or not p.Character then return end
    local pChar = p.Character

    -- Cria highlight se não existir
    local hl = ESPHighlights[p]
    if not hl or not hl.Parent then
        hl = Instance.new("Highlight")
        hl.Name = "AkatESPHighlight"
        hl.FillTransparency = 0.3
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = pChar
        ESPHighlights[p] = hl
    else
        -- Reparenta se o personagem mudou
        if hl.Parent ~= pChar then
            hl.Parent = pChar
        end
    end

    local role = ESPRoles[p] or "Innocent"
    local c = ESP_COLORS[role] or ESP_COLORS.Innocent
    hl.FillColor    = c.fill
    hl.OutlineColor = c.outline
end

-- Remove o Highlight de um jogador
local function ESP_RemoveHighlight(p)
    local hl = ESPHighlights[p]
    if hl then
        pcall(function() hl:Destroy() end)
        ESPHighlights[p] = nil
    end
end

-- Remove todos os highlights (quando ESP desliga)
local function ESP_ClearAll()
    for p, _ in pairs(ESPHighlights) do
        ESP_RemoveHighlight(p)
    end
    ESPHighlights = {}
end

-- Thread dedicada ao ESP: roda a 10 Hz para não custar FPS
local espThread = nil
local function ESP_StartThread()
    if espThread then return end
    espThread = task.spawn(function()
        while true do
            task.wait(0.1)
            if not Configs.ESP then
                ESP_ClearAll()
                -- Fica em idle até reativar
                repeat task.wait(0.2) until Configs.ESP
            end

            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player then
                    -- Atualiza papel em tempo real
                    local newRole = DetectRoleNow(p)
                    ESPRoles[p] = newRole

                    if p.Character and p.Character:FindFirstChildOfClass("Humanoid") then
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hum.Health > 0 then
                            ESP_ApplyHighlight(p)
                        else
                            -- Morreu: remove highlight
                            ESP_RemoveHighlight(p)
                        end
                    else
                        ESP_RemoveHighlight(p)
                    end
                end
            end

            -- Limpa highlights de jogadores que saíram
            for p, _ in pairs(ESPHighlights) do
                if not p.Parent or not Players:FindFirstChild(p.Name) then
                    ESP_RemoveHighlight(p)
                    ESPRoles[p] = nil
                end
            end
        end
    end)
end

-- Reconecta highlights quando personagem é carregado / regenerado
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        if Configs.ESP then
            ESPRoles[p] = DetectRoleNow(p)
            ESP_ApplyHighlight(p)
        end
    end)
end)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= player then
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            if Configs.ESP then
                ESPRoles[p] = DetectRoleNow(p)
                ESP_ApplyHighlight(p)
            end
        end)
    end
end

-- Inicia a thread do ESP no carregamento
ESP_StartThread()

-- ============================================================
--  AUTO SHOOT v2 - SISTEMA COMPLETO REESCRITO
-- ============================================================
-- Detecta arma no char/backpack, mira no head do Murderer,
-- dispara via RemoteEvent nativo do MM2 para máxima compatibilidade.
-- Funciona no Delta Mobile e PC.
-- ============================================================

local lastShootTime     = 0
local SHOOT_COOLDOWN    = 0.22   -- segundos entre tiros (evita flood)
local SHOOT_MAX_DIST    = 300    -- studs — distância máxima de engajamento

-- Verifica se o jogador local tem a arma equipada (character ou backpack)
local function LocalHasGun()
    local char = player.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if IsGunTool(t) then return t end
        end
    end
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if IsGunTool(t) then return t end
        end
    end
    return nil
end

-- Obtém o Murderer mais próximo com vida
local function GetClosestMurderer()
    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil, math.huge end

    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hum  = p.Character:FindFirstChildOfClass("Humanoid")
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            -- Considera Murderer pela detecção em tempo real do ESP
            if hum and root and hum.Health > 0 and DetectRoleNow(p) == "Murderer" then
                local dist = (myRoot.Position - root.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    best = p
                end
            end
        end
    end
    return best, bestDist
end

-- Dispara a arma via Activate (compatível com Delta Mobile e PC)
-- Equipa a tool no character antes se necessário
local function AutoShoot_Fire(gunTool, targetChar)
    if not gunTool or not targetChar then return end

    local targetHead = targetChar:FindFirstChild("Head")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    local aimPart    = targetHead or targetRoot
    if not aimPart then return end

    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    -- Rotaciona o personagem e câmera em direção ao alvo
    local targetPos = aimPart.Position
    local lookAt    = Vector3.new(targetPos.X, myRoot.Position.Y, targetPos.Z)
    myRoot.CFrame   = CFrame.new(myRoot.Position, lookAt)

    -- CFrame da câmera apontando para a cabeça (mobile não precisa de clique)
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)

    -- Equipa a tool se ainda está na backpack
    if gunTool.Parent ~= player.Character then
        player.Character.Humanoid:EquipTool(gunTool)
        task.wait(0.05)
    end

    -- Tenta disparar pelos caminhos disponíveis:
    -- 1) Activate nativo
    -- 2) FireServer via RemoteEvent interno da tool (MM2 usa "Shoot" ou "Fire")
    local fired = false

    -- Caminho 1: Activate
    local okActivate = pcall(function() gunTool:Activate() end)
    if okActivate then fired = true end

    -- Caminho 2: RemoteEvent interno (fallback mobile)
    if not fired then
        for _, v in ipairs(gunTool:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local n = v.Name:lower()
                if n:find("shoot") or n:find("fire") or n:find("shot") then
                    pcall(function() v:FireServer(targetPos) end)
                    fired = true
                    break
                end
            end
        end
    end
end

-- Thread do AutoShoot (RenderStepped para responsividade)
local autoShootConnection = nil
local function AutoShoot_Start()
    if autoShootConnection then return end
    autoShootConnection = RunService.RenderStepped:Connect(function()
        if not Configs.AutoShoot then return end

        local gunTool = LocalHasGun()
        if not gunTool then return end

        local murderer, dist = GetClosestMurderer()
        if not murderer or dist > SHOOT_MAX_DIST then return end

        local now = os.clock()
        if now - lastShootTime < SHOOT_COOLDOWN then return end

        lastShootTime = now
        task.spawn(AutoShoot_Fire, gunTool, murderer.Character)
    end)
end
AutoShoot_Start()

-- ============================================================
-- Detecção de papel para ChatRoles (usa o novo sistema)
-- ============================================================
local PlayerRoles = ESPRoles   -- alias: ambos apontam para a mesma tabela

local announcedThisRound = false

-- ==================== 3. CRIAÇÃO DA INTERFACE (UI) ====================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeltaAkatUniversalUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then
    uiParent = gethui()
else
    local successCore, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if successCore and coreGui then uiParent = coreGui end
end

if uiParent:FindFirstChild("DeltaAkatUniversalUI") then
    pcall(function() uiParent.DeltaAkatUniversalUI:Destroy() end)
end
screenGui.Parent = uiParent

-- Botão Flutuante (AKAT) - NA ESQUERDA
local FloatBtn = Instance.new("ImageButton", screenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0.12, 0, 0.4, 0)
FloatBtn.Image = "rbxthumb://type=Asset&id=99997714241420&w=150&h=150"
FloatBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
FloatBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
FloatBtn.Visible = false
FloatBtn.ZIndex = 30

local floatCorner = Instance.new("UICorner", FloatBtn)
floatCorner.CornerRadius = UDim.new(0, 8)

local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Thickness = 1
FloatStroke.Color = Color3.fromRGB(255, 255, 255)

local StrokeGradient = Instance.new("UIGradient", FloatStroke)
StrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromHex("#8B0000")),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 15, 15)),
    ColorSequenceKeypoint.new(1,   Color3.fromHex("#8B0000"))
})

task.spawn(function()
    local rot = 0
    while task.wait() do
        if not StrokeGradient.Parent then break end
        rot = (rot + 3) % 360
        StrokeGradient.Rotation = rot
    end
end)

-- Wrapper Principal
local mainWrapper = Instance.new("Frame")
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0)
mainWrapper.Size = UDim2.new(0, 520, 0, 300)
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, -150)
mainWrapper.BackgroundTransparency = 1
mainWrapper.ClipsDescendants = false
mainWrapper.Visible = false
mainWrapper.Parent = screenGui

local shadow3D = Instance.new("ImageLabel")
shadow3D.Name = "Shadow3D"
shadow3D.AnchorPoint = Vector2.new(0.5, 0.5)
shadow3D.Position = UDim2.new(0.5, 0, 0.5, 4)
shadow3D.Size = UDim2.new(1, 40, 1, 40)
shadow3D.BackgroundTransparency = 1
shadow3D.Image = "rbxassetid://6014261993"
shadow3D.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow3D.ImageTransparency = 0.5
shadow3D.ScaleType = Enum.ScaleType.Slice
shadow3D.SliceCenter = Rect.new(49, 49, 450, 450)
shadow3D.ZIndex = 1
shadow3D.Parent = mainWrapper

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundColor3 = Color3.fromHex("#0A0A0A")
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.ZIndex = 5
local mainCorner = Instance.new("UICorner", mainFrame)
mainCorner.CornerRadius = UDim.new(0, 9)

local frameStroke = Instance.new("UIStroke", mainFrame)
frameStroke.Color = Color3.fromHex("#161616")
frameStroke.Thickness = 1
mainFrame.Parent = mainWrapper

-- TopBar
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
subtitle.Text = "MM2 SCRIPT [BETA v2.5]"
subtitle.TextColor3 = Color3.fromHex("#555555")
subtitle.TextSize = 10
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 6

-- Barra de Pesquisa Animada
local searchBarFrame = Instance.new("Frame", topBar)
searchBarFrame.Name = "SearchBarFrame"
searchBarFrame.AnchorPoint = Vector2.new(1, 0.5)
searchBarFrame.Position = UDim2.new(1, -154, 0.5, 0)
searchBarFrame.Size = UDim2.new(0, 0, 0, 26)
searchBarFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
searchBarFrame.ClipsDescendants = true
searchBarFrame.ZIndex = 7

local searchCorner = Instance.new("UICorner", searchBarFrame)
searchCorner.CornerRadius = UDim.new(0, 13)
local searchStroke = Instance.new("UIStroke", searchBarFrame)
searchStroke.Color = Color3.fromHex("#1F1F1F")
searchStroke.Thickness = 1

local searchTextBox = Instance.new("TextBox", searchBarFrame)
searchTextBox.Name = "SearchTextBox"
searchTextBox.Size = UDim2.new(1, -20, 1, 0)
searchTextBox.Position = UDim2.new(0, 12, 0, 0)
searchTextBox.BackgroundTransparency = 1
searchTextBox.PlaceholderText = "Pesquisar..."
searchTextBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
searchTextBox.Text = ""
searchTextBox.TextColor3 = Color3.fromRGB(230, 230, 230)
searchTextBox.Font = Enum.Font.Gotham
searchTextBox.TextSize = 11
searchTextBox.TextXAlignment = Enum.TextXAlignment.Left
searchTextBox.ZIndex = 8

-- Botões superiores
local topButtons = Instance.new("Frame", topBar)
topButtons.Size = UDim2.new(0, 128, 0, 26)
topButtons.Position = UDim2.new(1, -144, 0.5, -13)
topButtons.BackgroundTransparency = 1
topButtons.ZIndex = 6

local UIListTop = Instance.new("UIListLayout", topButtons)
UIListTop.FillDirection = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding = UDim.new(0, 8)
UIListTop.SortOrder = Enum.SortOrder.LayoutOrder

local LanguageBtn = Instance.new("TextButton", topButtons)
LanguageBtn.Name = "LanguageBtn"
LanguageBtn.LayoutOrder = 0
LanguageBtn.Size = UDim2.new(0, 26, 0, 26)
LanguageBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
LanguageBtn.Text = currentLanguage
LanguageBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
LanguageBtn.Font = Enum.Font.GothamBold
LanguageBtn.TextSize = 10
LanguageBtn.ZIndex = 7
Instance.new("UICorner", LanguageBtn).CornerRadius = UDim.new(0, 5)

local SearchBtn = Instance.new("TextButton", topButtons)
SearchBtn.Name = "SearchBtn"
SearchBtn.LayoutOrder = 1
SearchBtn.Size = UDim2.new(0, 26, 0, 26)
SearchBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
SearchBtn.Text = ""
SearchBtn.ZIndex = 7
Instance.new("UICorner", SearchBtn).CornerRadius = UDim.new(0, 5)

local SearchIcon = Instance.new("Frame", SearchBtn)
SearchIcon.Name = "Icon"
SearchIcon.Size = UDim2.new(0, 14, 0, 14)
SearchIcon.AnchorPoint = Vector2.new(0.5, 0.5)
SearchIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
SearchIcon.BackgroundTransparency = 1
SearchIcon.ZIndex = 8

local SearchCircle = Instance.new("Frame", SearchIcon)
SearchCircle.Name = "Circle"
SearchCircle.Size = UDim2.new(0, 8, 0, 8)
SearchCircle.Position = UDim2.new(0, 1, 0, 1)
SearchCircle.BackgroundTransparency = 1
SearchCircle.ZIndex = 8
Instance.new("UICorner", SearchCircle).CornerRadius = UDim.new(1, 0)
local circleStroke = Instance.new("UIStroke", SearchCircle)
circleStroke.Color = Color3.fromHex("#A0A0A0")
circleStroke.Thickness = 1

local SearchHandle = Instance.new("Frame", SearchIcon)
SearchHandle.Name = "Handle"
SearchHandle.Size = UDim2.new(0, 1, 0, 5)
SearchHandle.Position = UDim2.new(0, 9, 0, 8)
SearchHandle.Rotation = -45
SearchHandle.BackgroundColor3 = Color3.fromHex("#A0A0A0")
SearchHandle.BorderSizePixel = 0
SearchHandle.ZIndex = 8

local MinimizeBtn = Instance.new("TextButton", topButtons)
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.LayoutOrder = 2
MinimizeBtn.Size = UDim2.new(0, 26, 0, 26)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
MinimizeBtn.Text = ""
MinimizeBtn.ZIndex = 7
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 5)

local MinimizeLine = Instance.new("Frame", MinimizeBtn)
MinimizeLine.Name = "Line"
MinimizeLine.AnchorPoint = Vector2.new(0.5, 0.5)
MinimizeLine.Position = UDim2.new(0.5, 0, 0.5, 0)
MinimizeLine.Size = UDim2.new(0, 10, 0, 1)
MinimizeLine.BackgroundColor3 = Color3.fromHex("#A0A0A0")
MinimizeLine.BorderSizePixel = 0
MinimizeLine.ZIndex = 8

local CloseBtn = Instance.new("TextButton", topButtons)
CloseBtn.Name = "CloseBtn"
CloseBtn.LayoutOrder = 3
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
CloseBtn.Text = ""
CloseBtn.ZIndex = 7
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

local CloseLine1 = Instance.new("Frame", CloseBtn)
CloseLine1.Name = "Line1"
CloseLine1.AnchorPoint = Vector2.new(0.5, 0.5)
CloseLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine1.Size = UDim2.new(0, 10, 0, 1)
CloseLine1.Rotation = 45
CloseLine1.BackgroundColor3 = Color3.fromHex("#A0A0A0")
CloseLine1.BorderSizePixel = 0
CloseLine1.ZIndex = 8

local CloseLine2 = Instance.new("Frame", CloseBtn)
CloseLine2.Name = "Line2"
CloseLine2.AnchorPoint = Vector2.new(0.5, 0.5)
CloseLine2.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine2.Size = UDim2.new(0, 10, 0, 1)
CloseLine2.Rotation = -45
CloseLine2.BackgroundColor3 = Color3.fromHex("#A0A0A0")
CloseLine2.BorderSizePixel = 0
CloseLine2.ZIndex = 8

local div = Instance.new("Frame", mainFrame)
div.Size = UDim2.new(1, 0, 0, 1)
div.Position = UDim2.new(0, 0, 0, 52)
div.BackgroundColor3 = Color3.fromHex("#121212")
div.BorderSizePixel = 0
div.ZIndex = 6

local SidebarFrame = Instance.new("Frame", mainFrame)
SidebarFrame.Name = "SidebarFrame"
SidebarFrame.Size = UDim2.new(0, 140, 1, -53)
SidebarFrame.Position = UDim2.new(0, 0, 0, 53)
SidebarFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
SidebarFrame.BorderSizePixel = 0
SidebarFrame.ZIndex = 6

local SidebarCorner = Instance.new("UICorner", SidebarFrame)
SidebarCorner.CornerRadius = UDim.new(0, 9)

local SidebarSeparator = Instance.new("Frame", SidebarFrame)
SidebarSeparator.Size = UDim2.new(0, 1, 1, 0)
SidebarSeparator.Position = UDim2.new(1, 0, 0, 0)
SidebarSeparator.BackgroundColor3 = Color3.fromHex("#121212")
SidebarSeparator.BorderSizePixel = 0
SidebarSeparator.ZIndex = 6

local ProfileDiv = Instance.new("Frame", SidebarFrame)
ProfileDiv.Size = UDim2.new(1, 0, 0, 1)
ProfileDiv.Position = UDim2.new(0, 0, 1, -66)
ProfileDiv.BackgroundColor3 = Color3.fromHex("#121212")
ProfileDiv.BorderSizePixel = 0
ProfileDiv.ZIndex = 6

local TabsContainer = Instance.new("ScrollingFrame", SidebarFrame)
TabsContainer.Name = "TabsContainer"
TabsContainer.Size = UDim2.new(1, 0, 1, -75)
TabsContainer.Position = UDim2.new(0, 0, 0, 5)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ScrollBarThickness = 0
TabsContainer.ZIndex = 7
TabsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
TabsContainer.ElasticBehavior = Enum.ElasticBehavior.Never
pcall(function() TabsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y end)

local TabsLayout = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabsLayout.Padding = UDim.new(0, 6)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local TabsPadding = Instance.new("UIPadding", TabsContainer)
TabsPadding.PaddingBottom = UDim.new(0, 15)
TabsPadding.PaddingTop = UDim.new(0, 5)

local UserProfileFrame = Instance.new("Frame", SidebarFrame)
UserProfileFrame.Name = "UserProfileFrame"
UserProfileFrame.Size = UDim2.new(1, -16, 0, 50)
UserProfileFrame.Position = UDim2.new(0, 8, 1, -58)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex = 7

local ProfileCorner = Instance.new("UICorner", UserProfileFrame)
ProfileCorner.CornerRadius = UDim.new(0, 6)
local ProfileBorder = Instance.new("UIStroke", UserProfileFrame)
ProfileBorder.Color = Color3.fromRGB(24, 24, 24)
ProfileBorder.Thickness = 1

local AvatarImage = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Name = "AvatarImage"
AvatarImage.Size = UDim2.new(0, 32, 0, 32)
AvatarImage.Position = UDim2.new(0, 10, 0.5, -16)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex = 8
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

local DisplayNameLabel = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Name = "DisplayNameLabel"
DisplayNameLabel.Size = UDim2.new(1, -54, 0, 14)
DisplayNameLabel.Position = UDim2.new(0, 48, 0.5, -14)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
DisplayNameLabel.Font = Enum.Font.GothamBold
DisplayNameLabel.TextSize = 11
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLabel.ZIndex = 8

local UsernameLabel = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Name = "UsernameLabel"
UsernameLabel.Size = UDim2.new(1, -54, 0, 12)
UsernameLabel.Position = UDim2.new(0, 48, 0.5, 0)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text = "@" .. player.Name
UsernameLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
UsernameLabel.Font = Enum.Font.Gotham
UsernameLabel.TextSize = 9
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UsernameLabel.ZIndex = 8

local togglesContainer = Instance.new("ScrollingFrame", mainFrame)
togglesContainer.Name = "TogglesContainer"
togglesContainer.Size = UDim2.new(1, -156, 1, -66)
togglesContainer.Position = UDim2.new(0, 148, 0, 58)
togglesContainer.BackgroundTransparency = 1
togglesContainer.BorderSizePixel = 0
togglesContainer.ScrollBarThickness = 0
togglesContainer.ZIndex = 6
togglesContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
togglesContainer.ElasticBehavior = Enum.ElasticBehavior.Never
pcall(function() togglesContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y end)

local containerLayout = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
containerLayout.Padding = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local uiPadding = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingBottom = UDim.new(0, 8)

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
confirmLabel.Text = "Deseja fechar o script?"
confirmLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
confirmLabel.Font = Enum.Font.GothamBold
confirmLabel.TextSize = 14
confirmLabel.ZIndex = 51

local btnYes = Instance.new("TextButton", confirmFrame)
btnYes.Size = UDim2.new(0, 110, 0, 34)
btnYes.Position = UDim2.new(0.5, -115, 0.55, 0)
btnYes.BackgroundColor3 = Color3.fromHex("#8B0000")
btnYes.Text = "Confirmar"
btnYes.TextColor3 = Color3.fromRGB(255, 255, 255)
btnYes.Font = Enum.Font.GothamMedium
btnYes.TextSize = 12
btnYes.ZIndex = 51
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 6)

local btnNo = Instance.new("TextButton", confirmFrame)
btnNo.Size = UDim2.new(0, 110, 0, 34)
btnNo.Position = UDim2.new(0.5, 5, 0.55, 0)
btnNo.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
btnNo.Text = "Cancelar"
btnNo.TextColor3 = Color3.fromRGB(180, 180, 180)
btnNo.Font = Enum.Font.GothamMedium
btnNo.TextSize = 12
btnNo.ZIndex = 51
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 6)

-- ==================== 4. FUNÇÕES DE SUPORTE ====================

local function RegistrarTransparencias(objeto)
    if originalTrans[objeto] then return end
    if objeto:IsA("Frame") or objeto:IsA("ScrollingFrame") then
        originalTrans[objeto] = { BackgroundTransparency = objeto.BackgroundTransparency }
    elseif objeto:IsA("TextLabel") or objeto:IsA("TextButton") or objeto:IsA("TextBox") then
        originalTrans[objeto] = {
            TextTransparency = objeto.TextTransparency,
            BackgroundTransparency = objeto.BackgroundTransparency,
            TextStrokeTransparency = objeto.TextStrokeTransparency or 1
        }
    elseif objeto:IsA("ImageLabel") or objeto:IsA("ImageButton") then
        originalTrans[objeto] = {
            ImageTransparency = objeto.ImageTransparency,
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
            local target = fadeOut and 1 or orig.BackgroundTransparency
            if duracao == 0 then obj.BackgroundTransparency = target else TweenService:Create(obj, info, {BackgroundTransparency = target}):Play() end
        end
        if orig.TextTransparency then
            local target = fadeOut and 1 or orig.TextTransparency
            if duracao == 0 then obj.TextTransparency = target else TweenService:Create(obj, info, {TextTransparency = target}):Play() end
        end
        if orig.TextStrokeTransparency then
            local target = fadeOut and 1 or orig.TextStrokeTransparency
            if duracao == 0 then obj.TextStrokeTransparency = target else TweenService:Create(obj, info, {TextStrokeTransparency = target}):Play() end
        end
        if orig.ImageTransparency then
            local target = fadeOut and 1 or (obj.Name == "Shadow3D" and 0.5 or orig.ImageTransparency)
            if duracao == 0 then obj.ImageTransparency = target else TweenService:Create(obj, info, {ImageTransparency = target}):Play() end
        end
        if orig.Transparency then
            local target = fadeOut and 1 or orig.Transparency
            if duracao == 0 then obj.Transparency = target else TweenService:Create(obj, info, {Transparency = target}):Play() end
        end
    end
    tratarObjeto(raiz)
    for _, desc in ipairs(raiz:GetDescendants()) do tratarObjeto(desc) end
end

local function AplicarFadeIdioma(fadeOut, duracao)
    local info = TweenInfo.new(duracao, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    for _, btn in pairs(tabButtons) do
        local label = btn:FindFirstChild("Label")
        if label then
            RegistrarTransparencias(label)
            local orig = originalTrans[label]
            local target = fadeOut and 1 or (orig and orig.TextTransparency or 0)
            TweenService:Create(label, info, {TextTransparency = target}):Play()
        end
    end

    for _, child in ipairs(togglesContainer:GetDescendants()) do
        if child:IsA("TextLabel") then
            RegistrarTransparencias(child)
            local orig = originalTrans[child]
            local target = fadeOut and 1 or (orig and orig.TextTransparency or 0)
            TweenService:Create(child, info, {TextTransparency = target}):Play()
        end
    end

    RegistrarTransparencias(searchTextBox)
    local targetST = fadeOut and 1 or 0
    TweenService:Create(searchTextBox, info, {TextTransparency = targetST}):Play()
end

local function CriarIconeProcedural(parent, tabName)
    local iconContainer = Instance.new("Frame", parent)
    iconContainer.Name = "Icon"
    iconContainer.Size = UDim2.new(0, 16, 0, 16)
    iconContainer.Position = UDim2.new(0, 12, 0.5, -8)
    iconContainer.BackgroundTransparency = 1
    iconContainer.ZIndex = 9

    local imageLabel = Instance.new("ImageLabel", iconContainer)
    imageLabel.Name = "AccentImage"
    imageLabel.Size = UDim2.new(1, 0, 1, 0)
    imageLabel.BackgroundTransparency = 1
    imageLabel.ZIndex = 10
    imageLabel.ImageColor3 = Color3.fromRGB(180, 180, 180)

    if tabName == "Movement" then
        imageLabel.Image = "rbxthumb://type=Asset&id=116118153718196&w=150&h=150"
    elseif tabName == "Teleports" then
        imageLabel.Image = "rbxthumb://type=Asset&id=131357413318360&w=150&h=150"
    elseif tabName == "Misc" then
        imageLabel.Image = "rbxthumb://type=Asset&id=96954032676031&w=150&h=150"
    elseif tabName == "Visuals" then
        imageLabel.Image = "rbxthumb://type=Asset&id=134099134229815&w=150&h=150"
    elseif tabName == "Combat" then
        imageLabel.Image = "rbxthumb://type=Asset&id=131607049070859&w=150&h=150"
    end
end

local function RecolorirIcone(iconContainer, targetColor, animSpeed)
    if not iconContainer then return end
    for _, child in ipairs(iconContainer:GetDescendants()) do
        if child.Name == "AccentStroke" and child:IsA("UIStroke") then
            TweenService:Create(child, animSpeed, {Color = targetColor}):Play()
        elseif child.Name == "AccentFill" and child:IsA("Frame") then
            TweenService:Create(child, animSpeed, {BackgroundColor3 = targetColor}):Play()
        elseif child.Name == "AccentImage" and child:IsA("ImageLabel") then
            TweenService:Create(child, animSpeed, {ImageColor3 = targetColor}):Play()
        end
    end
end

local function AtualizarIdioma()
    local langData = Locales[currentLanguage]
    if not langData then return end

    searchTextBox.PlaceholderText = langData.SearchPlaceholder

    for tabName, btn in pairs(tabButtons) do
        local label = btn:FindFirstChild("Label")
        if label then
            label.Text = langData.Tabs[tabName] or tabName
        end
    end

    for _, child in ipairs(togglesContainer:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
            local configKey = child:GetAttribute("ConfigKey")
            if configKey and langData.Options[configKey] then
                local titleLabel = child:FindFirstChild("Title")
                local descLabel  = child:FindFirstChild("Description")
                if titleLabel then titleLabel.Text = langData.Options[configKey].Title end
                if descLabel  then descLabel.Text  = langData.Options[configKey].Desc  end
            end
        end
    end

    confirmLabel.Text = langData.ConfirmCloseTitle
    btnYes.Text = langData.ConfirmBtn
    btnNo.Text  = langData.CancelBtn
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

            child.Visible = shouldBeVisible

            if shouldBeVisible then
                itemIndex = itemIndex + 1
                child.Size = UDim2.new(1, -8, 0, 0)
                child.BackgroundTransparency = 1

                local t = child:FindFirstChild("Title")
                local d = child:FindFirstChild("Description")
                if t then t.TextTransparency = 1 end
                if d then d.TextTransparency = 1 end

                task.delay((itemIndex - 1) * 0.03, function()
                    TweenService:Create(child, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, -8, 0, 56),
                        BackgroundTransparency = 0
                    }):Play()
                    if t then TweenService:Create(t, TweenInfo.new(0.2), {TextTransparency = 0}):Play() end
                    if d then TweenService:Create(d, TweenInfo.new(0.2), {TextTransparency = 0}):Play() end
                end)
            end
        end
    end
end

local function selectTab(tabName)
    activeTab = tabName
    local animSpeed = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    for name, btn in pairs(tabButtons) do
        local label = btn:FindFirstChild("Label")
        local iconContainer = btn:FindFirstChild("Icon")
        if name == tabName then
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromHex("#8B0000")}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end
            RecolorirIcone(iconContainer, Color3.fromRGB(255, 255, 255), animSpeed)
        else
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(15, 15, 15)}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(180, 180, 180)}):Play() end
            RecolorirIcone(iconContainer, Color3.fromRGB(180, 180, 180), animSpeed)
        end
    end

    togglesContainer.CanvasPosition = Vector2.new(0, 0)
    searchTextBox.Text = ""
    filterToggles(tabName, "")
end

local function createTabBtn(tabName)
    local tabBtn = Instance.new("TextButton", TabsContainer)
    tabBtn.Name = tabName .. "TabBtn"
    tabBtn.Size = UDim2.new(1, -16, 0, 32)
    tabBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    tabBtn.Text = ""
    tabBtn.ZIndex = 8
    tabBtn.AutoButtonColor = false

    local corner = Instance.new("UICorner", tabBtn)
    corner.CornerRadius = UDim.new(0, 5)

    CriarIconeProcedural(tabBtn, tabName)

    local tabLabel = Instance.new("TextLabel", tabBtn)
    tabLabel.Name = "Label"
    tabLabel.Size = UDim2.new(1, -44, 1, 0)
    tabLabel.Position = UDim2.new(0, 36, 0, 0)
    tabLabel.BackgroundTransparency = 1
    tabLabel.Text = Locales[currentLanguage].Tabs[tabName] or tabName
    tabLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    tabLabel.Font = Enum.Font.GothamMedium
    tabLabel.TextSize = 11
    tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.ZIndex = 9

    tabBtn.MouseButton1Down:Connect(function()
        TweenService:Create(tabBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, -24, 0, 30)
        }):Play()
    end)

    local function restaurarTamanho()
        TweenService:Create(tabBtn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, -16, 0, 32)
        }):Play()
    end

    tabBtn.MouseButton1Up:Connect(restaurarTamanho)

    tabBtn.MouseLeave:Connect(function()
        restaurarTamanho()
        if activeTab ~= tabName then
            TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(15, 15, 15)}):Play()
            TweenService:Create(tabLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {TextColor3 = Color3.fromRGB(180, 180, 180)}):Play()
            RecolorirIcone(tabBtn:FindFirstChild("Icon"), Color3.fromRGB(180, 180, 180), TweenInfo.new(0.15, Enum.EasingStyle.Quad))
        end
    end)

    tabBtn.MouseEnter:Connect(function()
        if activeTab ~= tabName then
            TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(22, 22, 22)}):Play()
            TweenService:Create(tabLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {TextColor3 = Color3.fromRGB(220, 220, 220)}):Play()
            RecolorirIcone(tabBtn:FindFirstChild("Icon"), Color3.fromRGB(220, 220, 220), TweenInfo.new(0.15, Enum.EasingStyle.Quad))
        end
    end)

    tabBtn.MouseButton1Click:Connect(function()
        selectTab(tabName)
    end)

    tabButtons[tabName] = tabBtn
end

local ConfigCallbacks = {
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
                safePlatform.Transparency = 0.4
                safePlatform.Material = Enum.Material.ForceField
                safePlatform.Color = Color3.fromHex("#8B0000")
                safePlatform.Parent = workspace
            end
            root.CFrame = safePlatform.CFrame * CFrame.new(0, 3, 0)
        else
            if safePlatform then
                safePlatform:Destroy()
                safePlatform = nil
            end
            if lastPositionBeforeSafeSpot then
                root.CFrame = lastPositionBeforeSafeSpot
                lastPositionBeforeSafeSpot = nil
            end
        end
    end,

    AutoCollect = function(enabled)
        if not enabled then
            currentCollectTarget = nil
        end
    end
}

local function createToggle(parent, configKey, tabCategory)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = configKey
    toggleFrame.Size = UDim2.new(1, -8, 0, 56)
    toggleFrame.BackgroundColor3 = Color3.fromHex("#0F0F0F")
    toggleFrame.ZIndex = 6
    toggleFrame:SetAttribute("Tab", tabCategory)
    toggleFrame:SetAttribute("ConfigKey", configKey)
    toggleFrame.Parent = parent

    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", toggleFrame)
    stroke.Color = Color3.fromHex("#141414")
    stroke.Thickness = 1

    local titleLabel = Instance.new("TextLabel", toggleFrame)
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(0.65, 0, 0, 16)
    titleLabel.Position = UDim2.new(0, 12, 0, 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromHex("#CCCCCC")
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 6

    local descLabel = Instance.new("TextLabel", toggleFrame)
    descLabel.Name = "Description"
    descLabel.Size = UDim2.new(0.65, 0, 0, 28)
    descLabel.Position = UDim2.new(0, 12, 0, 22)
    descLabel.BackgroundTransparency = 1
    descLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 9
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.TextWrapped = true
    descLabel.ZIndex = 6

    local switchTrack = Instance.new("Frame", toggleFrame)
    switchTrack.Size = UDim2.new(0, 40, 0, 20)
    switchTrack.Position = UDim2.new(1, -52, 0.5, -10)
    switchTrack.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
    switchTrack.ZIndex = 6
    Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)

    local trackStroke = Instance.new("UIStroke", switchTrack)
    trackStroke.Color = Color3.fromRGB(45, 45, 45)
    trackStroke.Thickness = 1

    local switchCircle = Instance.new("Frame", switchTrack)
    switchCircle.Size = UDim2.new(0, 14, 0, 14)
    switchCircle.Position = Configs[configKey] and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    switchCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    switchCircle.ZIndex = 7
    Instance.new("UICorner", switchCircle).CornerRadius = UDim.new(1, 0)

    local triggerBtn = Instance.new("TextButton", toggleFrame)
    triggerBtn.Size = UDim2.new(1, 0, 1, 0)
    triggerBtn.BackgroundTransparency = 1
    triggerBtn.Text = ""
    triggerBtn.ZIndex = 8

    triggerBtn.MouseButton1Click:Connect(function()
        Configs[configKey] = not Configs[configKey]
        local targetPos   = Configs[configKey] and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        local targetColor = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)

        local toggleAnim = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(switchCircle, toggleAnim, {Position = targetPos}):Play()
        TweenService:Create(switchTrack, toggleAnim, {BackgroundColor3 = targetColor}):Play()

        if ConfigCallbacks[configKey] then
            task.spawn(ConfigCallbacks[configKey], Configs[configKey])
        end
    end)
end

local function LimparEDesligarAbsolutamente()
    if hbConnection then hbConnection:Disconnect() hbConnection = nil end
    if autoShootConnection then autoShootConnection:Disconnect() autoShootConnection = nil end

    for k in pairs(Configs) do Configs[k] = false end

    ESP_ClearAll()

    if safePlatform then pcall(function() safePlatform:Destroy() end) safePlatform = nil end

    pcall(function()
        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.PlatformStand = false
        end
        if char then
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Tool") then
                    local handle = item:FindFirstChild("Handle")
                    local reachPart = handle and handle:FindFirstChild("AkatReachPart")
                    if reachPart then reachPart:Destroy() end
                end
            end
        end
    end)
end

local function AlternarConfirmacao(exibir)
    isConfirmOpen = exibir
    local tempoAnim = 0.15

    if exibir then
        if not confirmBlur then
            confirmBlur = Instance.new("BlurEffect")
            confirmBlur.Name = "AkatConfirmBlur"
            confirmBlur.Size = 0
            confirmBlur.Parent = Lighting
        end
        confirmFrame.Visible = true
        AplicarFadeSincronizado(confirmFrame, true, 0)
        AplicarFadeSincronizado(confirmFrame, false, tempoAnim)
        TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 14}):Play()
    else
        AplicarFadeSincronizado(confirmFrame, true, tempoAnim)
        if confirmBlur then TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play() end

        if wasMinimizedBeforeConfirm then
            AplicarFadeSincronizado(SidebarFrame, true, 0.15)
            AplicarFadeSincronizado(togglesContainer, true, 0.15)
            isMinimized = true
            TweenService:Create(mainWrapper, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.new(0, 520, 0, 52)}):Play()
            task.delay(0.15, function()
                if isMinimized then
                    togglesContainer.Visible = false
                    SidebarFrame.Visible = false
                    div.Visible = false
                end
            end)
        end

        task.delay(tempoAnim, function()
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
    local windowAnim = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    if isMinimized then
        AplicarFadeSincronizado(SidebarFrame, true, 0.1)
        AplicarFadeSincronizado(togglesContainer, true, 0.1)
        TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 520, 0, 52)}):Play()
        task.delay(0.1, function()
            if isMinimized then
                togglesContainer.Visible = false
                SidebarFrame.Visible = false
                div.Visible = false
            end
        end)
    else
        div.Visible = true
        SidebarFrame.Visible = true
        togglesContainer.Visible = true
        AplicarFadeSincronizado(SidebarFrame, true, 0)
        AplicarFadeSincronizado(togglesContainer, true, 0)
        TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 520, 0, 300)}):Play()
        AplicarFadeSincronizado(SidebarFrame, false, 0.16)
        AplicarFadeSincronizado(togglesContainer, false, 0.16)
        filterToggles(activeTab, searchTextBox.Text)
    end
end

local function alternarVisibilidadeMenu()
    menuAberto = not menuAberto
    local tempoAnim = 0.12
    local windowAnim = TweenInfo.new(tempoAnim, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    if menuAberto then
        mainWrapper.Visible = true
        togglesContainer.Visible = false
        SidebarFrame.Visible = false
        div.Visible = false

        mainWrapper.Size = UDim2.new(0, 480, 0, isMinimized and 40 or 270)
        AplicarFadeSincronizado(mainWrapper, true, 0)
        AplicarFadeSincronizado(mainWrapper, false, tempoAnim)

        local pop = TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 520, 0, isMinimized and 52 or 300)})
        pop:Play()
        pop.Completed:Connect(function()
            if menuAberto and not isMinimized and not isConfirmOpen then
                SidebarFrame.Visible = true
                togglesContainer.Visible = true
                div.Visible = true
                AplicarFadeSincronizado(SidebarFrame, true, 0)
                AplicarFadeSincronizado(SidebarFrame, false, 0.1)
                filterToggles(activeTab, searchTextBox.Text)
            end
        end)
    else
        togglesContainer.Visible = false
        SidebarFrame.Visible = false
        div.Visible = false
        AplicarFadeSincronizado(mainWrapper, true, tempoAnim)
        local hide = TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 480, 0, isMinimized and 40 or 270)})
        hide:Play()
        hide.Completed:Connect(function()
            if not menuAberto then mainWrapper.Visible = false end
        end)
    end
end

local function ConfigurarArrastarAkat(inst)
    local drag = false
    local startPos, dragStart, dragInput
    inst.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            drag = true
            dragStart = input.Position
            startPos = inst.Position
            dragInput = input

            local connection
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    drag = false
                    connection:Disconnect()
                end
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
    IntroFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    IntroFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    IntroFrame.Size = UDim2.new(1, 0, 1, 0)
    IntroFrame.BackgroundColor3 = Color3.fromHex("#0A0A0A")
    IntroFrame.BackgroundTransparency = 1
    IntroFrame.ZIndex = 500

    local IntroText = Instance.new("TextLabel", IntroFrame)
    IntroText.AnchorPoint = Vector2.new(0.5, 0.5)
    IntroText.Size = UDim2.new(0, 600, 0, 80)
    IntroText.Position = UDim2.new(0.5, 0, 0.5, 10)
    IntroText.BackgroundTransparency = 1
    IntroText.Font = Enum.Font.GothamBold
    IntroText.TextSize = 26
    IntroText.RichText = true
    IntroText.Text = Locales[currentLanguage].Intro
    IntroText.TextTransparency = 1
    IntroText.ZIndex = 501

    local IntroLine = Instance.new("Frame", IntroFrame)
    IntroLine.AnchorPoint = Vector2.new(0.5, 0.5)
    IntroLine.Position = UDim2.new(0.5, 0, 0.5, 30)
    IntroLine.Size = UDim2.new(0, 0, 0, 2)
    IntroLine.BackgroundColor3 = Color3.fromHex("#8B0000")
    IntroLine.BorderSizePixel = 0
    IntroLine.BackgroundTransparency = 1
    IntroLine.ZIndex = 502

    TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.2}):Play()
    TweenService:Create(IntroText, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, -6)}):Play()
    TweenService:Create(IntroLine, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(0, 260, 0, 2), Position = UDim2.new(0.5, 0, 0.5, 17)}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 14}):Play()
    task.wait(0.5)

    local correndoBrilho = true
    task.spawn(function()
        local infoFadeOut = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        local infoFadeIn  = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        while correndoBrilho do
            local tw1 = TweenService:Create(IntroText, infoFadeOut, {TextTransparency = 0.4})
            local tw2 = TweenService:Create(IntroLine, infoFadeOut, {BackgroundTransparency = 0.4})
            tw1:Play() tw2:Play()
            tw1.Completed:Wait()
            if not correndoBrilho then break end
            local tw3 = TweenService:Create(IntroText, infoFadeIn, {TextTransparency = 0})
            local tw4 = TweenService:Create(IntroLine, infoFadeIn, {BackgroundTransparency = 0})
            tw3:Play() tw4:Play()
            tw3.Completed:Wait()
        end
    end)

    task.wait(1.5)
    correndoBrilho = false

    TweenService:Create(IntroText, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, -16)}):Play()
    TweenService:Create(IntroLine, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 2)}):Play()
    TweenService:Create(IntroFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play()
    task.wait(0.35)

    IntroFrame:Destroy()
    Blur:Destroy()

    RegistrarTransparencias(mainFrame)
    for _, item in ipairs(mainFrame:GetDescendants()) do RegistrarTransparencias(item) end

    mainWrapper.Visible = true
    FloatBtn.Visible = true

    AplicarFadeSincronizado(mainWrapper, true, 0)
    mainWrapper.Size = UDim2.new(0, 505, 0, 288)

    local fastOpen = TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    AplicarFadeSincronizado(mainWrapper, false, 0.12)
    local openTween = TweenService:Create(mainWrapper, fastOpen, {Size = UDim2.new(0, 520, 0, 300)})
    openTween:Play()
    openTween.Completed:Connect(function() selectTab("Combat") end)
end

local function EnviarMensagemChat(msg)
    local TextChatService = game:GetService("TextChatService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if channel then channel:SendAsync(msg) end
        else
            local chatEvent = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") and
                              ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
            if chatEvent then chatEvent:FireServer(msg, "All") end
        end
    end)
end

-- ==================== 5. INSTANCIAÇÃO DE ELEMENTOS E EVENTOS ====================

local function AplicarEfeitoFisicoBotao(btn, hoverColor)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(36, 36, 36)}):Play()
        if btn.Name == "MinimizeBtn" then
            TweenService:Create(btn.Line, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = hoverColor}):Play()
        elseif btn.Name == "SearchBtn" then
            TweenService:Create(circleStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Color = hoverColor}):Play()
            TweenService:Create(SearchHandle, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = hoverColor}):Play()
        elseif btn.Name == "CloseBtn" then
            TweenService:Create(btn.Line1, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = hoverColor}):Play()
            TweenService:Create(btn.Line2, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = hoverColor}):Play()
        elseif btn.Name == "LanguageBtn" then
            TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextColor3 = hoverColor}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(24, 24, 24)}):Play()
        if btn.Name == "MinimizeBtn" then
            TweenService:Create(btn.Line, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "SearchBtn" then
            TweenService:Create(circleStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Color = Color3.fromHex("#A0A0A0")}):Play()
            TweenService:Create(SearchHandle, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "CloseBtn" then
            TweenService:Create(btn.Line1, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
            TweenService:Create(btn.Line2, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "LanguageBtn" then
            TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextColor3 = Color3.fromRGB(160, 160, 160)}):Play()
        end
    end)
end

AplicarEfeitoFisicoBotao(LanguageBtn, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(SearchBtn,   Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(MinimizeBtn, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(CloseBtn,    Color3.fromRGB(255,  60,  60))

createTabBtn("Combat")
createTabBtn("Visuals")
createTabBtn("Movement")
createTabBtn("Teleports")
createTabBtn("Misc")

createToggle(togglesContainer, "AutoShoot",   "Combat")
createToggle(togglesContainer, "Reach",       "Combat")
createToggle(togglesContainer, "ESP",         "Visuals")
createToggle(togglesContainer, "Speed",       "Movement")
createToggle(togglesContainer, "AntiFling",   "Movement")
createToggle(togglesContainer, "TpToGun",     "Teleports")
createToggle(togglesContainer, "SafeSpot",    "Teleports")
createToggle(togglesContainer, "AutoCollect", "Misc")
createToggle(togglesContainer, "ChatRoles",   "Misc")

local searchOpen = false
SearchBtn.MouseButton1Click:Connect(function()
    searchOpen = not searchOpen
    local searchAnimInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if searchOpen then
        TweenService:Create(searchBarFrame, searchAnimInfo, {Size = UDim2.new(0, 160, 0, 26)}):Play()
        searchTextBox:CaptureFocus()
    else
        searchTextBox.Text = ""
        TweenService:Create(searchBarFrame, searchAnimInfo, {Size = UDim2.new(0, 0, 0, 26)}):Play()
        searchTextBox:ReleaseFocus()
        filterToggles(activeTab, "")
    end
end)

searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
    filterToggles(activeTab, searchTextBox.Text)
end)

local languageTransitioning = false
LanguageBtn.MouseButton1Click:Connect(function()
    if languageTransitioning then return end
    languageTransitioning = true

    AplicarFadeIdioma(true, 0.1)
    task.wait(0.1)

    if currentLanguage == "EN" then
        currentLanguage = "PT"
    elseif currentLanguage == "PT" then
        currentLanguage = "ES"
    else
        currentLanguage = "EN"
    end

    LanguageBtn.Text = currentLanguage
    AtualizarIdioma()

    AplicarFadeIdioma(false, 0.12)
    task.wait(0.12)

    languageTransitioning = false
end)

AtualizarIdioma()

CloseBtn.MouseButton1Click:Connect(function()
    wasMinimizedBeforeConfirm = isMinimized
    if isMinimized then
        isMinimized = false
        div.Visible = true
        SidebarFrame.Visible = true
        togglesContainer.Visible = true
        AplicarFadeSincronizado(SidebarFrame, false, 0)
        AplicarFadeSincronizado(togglesContainer, false, 0)
        local expandTween = TweenService:Create(mainWrapper, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.new(0, 520, 0, 300)})
        expandTween:Play()
        task.spawn(function()
            expandTween.Completed:Wait()
            AlternarConfirmacao(true)
        end)
    else
        AlternarConfirmacao(true)
    end
end)

btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)

btnYes.MouseButton1Click:Connect(function()
    local syncTime = 0.18
    if confirmBlur then TweenService:Create(confirmBlur, TweenInfo.new(syncTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play() end
    AplicarFadeSincronizado(mainWrapper, true, syncTime)
    TweenService:Create(FloatBtn, TweenInfo.new(syncTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {ImageTransparency = 1}):Play()
    task.wait(syncTime)
    LimparEDesligarAbsolutamente()
    pcall(function() if confirmBlur then confirmBlur:Destroy() end end)
    screenGui:Destroy()
end)

-- ==================== ANIMAÇÃO SUAVE DO BOTÃO FLUTUANTE ====================
-- Pulso suave com Sine 0.12s — profissional e sem brusquidão
local function AnimarCliqueFloatBtn()
    local originalSize = UDim2.new(0, 44, 0, 44)
    local shrunkSize   = UDim2.new(0, 38, 0, 38)

    local shrink = TweenService:Create(FloatBtn,
        TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { Size = shrunkSize })

    local expand = TweenService:Create(FloatBtn,
        TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { Size = originalSize })

    shrink:Play()
    local c
    c = shrink.Completed:Connect(function()
        expand:Play()
        c:Disconnect()
    end)
end

MinimizeBtn.MouseButton1Click:Connect(executarMinimizacao)

FloatBtn.MouseButton1Click:Connect(function()
    AnimarCliqueFloatBtn()
    alternarVisibilidadeMenu()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and (input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightShift) then
        alternarVisibilidadeMenu()
    end
end)

ConfigurarArrastarAkat(mainWrapper)
ConfigurarArrastarAkat(FloatBtn)

task.spawn(function()
    task.wait(0.1)
    RegistrarTransparencias(confirmFrame)
    for _, d in ipairs(confirmFrame:GetDescendants()) do RegistrarTransparencias(d) end
end)

-- ==================== 6. THREADS EM SEGUNDO PLANO ====================

-- ChatRoles — usa ESPRoles para anunciar Murder/Sheriff no chat
task.spawn(function()
    while true do
        local currentMurderer, currentSheriff = nil, nil

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then
                local role = ESPRoles[p] or DetectRoleNow(p)
                ESPRoles[p] = role
                if role == "Murderer" then currentMurderer = p end
                if role == "Sheriff"  then currentSheriff  = p end
            end
        end

        if not currentMurderer and not currentSheriff then
            announcedThisRound = false
        elseif Configs.ChatRoles and (currentMurderer or currentSheriff) and not announcedThisRound then
            announcedThisRound = true
            local msg = "[AKAT] "
            if currentMurderer then
                msg = msg .. "Murderer: " .. currentMurderer.DisplayName .. " (@" .. currentMurderer.Name .. ") "
            end
            if currentSheriff then
                msg = msg .. "| Sheriff: " .. currentSheriff.DisplayName .. " (@" .. currentSheriff.Name .. ")"
            end
            EnviarMensagemChat(msg)
        end

        task.wait(0.4)
    end
end)

-- Teleport to Gun — helper
local function ObterArmaCaida(root)
    local gun = workspace:FindFirstChild("GunDrop", true)
    if gun then
        local targetPart = nil
        if gun:IsA("BasePart") then
            targetPart = gun
        elseif gun:IsA("Model") then
            targetPart = gun:FindFirstChildOfClass("BasePart") or gun.PrimaryPart
        elseif gun:IsA("Tool") then
            targetPart = gun:FindFirstChild("Handle") or gun:FindFirstChildOfClass("BasePart")
        end
        if targetPart and root then
            if (root.Position - targetPart.Position).Magnitude < 1500 then
                return targetPart
            end
        end
    end
    return nil
end

local function PlayerTemArma()
    if player.Backpack:FindFirstChild("Gun") or (player.Character and player.Character:FindFirstChild("Gun")) then
        return true
    end
    return false
end

-- Auto Collect — helper
local function ObterMoedaProxima(root)
    local closestCoin, closestDist = nil, math.huge
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and d.Transparency < 1 then
            local name = d.Name:lower()
            if name:find("coin") or name:find("moeda") or name:find("gold") or
               name == "snowflake" or name == "candycane" or name:find("token") or
               name:find("diamond") or name:find("present") or name:find("candy") then
                if not d:IsDescendantOf(Players) and
                   not d:FindFirstAncestorOfClass("Tool") and
                   not d:FindFirstAncestorOfClass("Accessory") then
                    local dist = (root.Position - d.Position).Magnitude
                    if dist < closestDist and dist < 1500 then
                        closestDist = dist
                        closestCoin = d
                    end
                end
            end
        end
    end
    return closestCoin
end

-- Heartbeat principal
hbConnection = RunService.Heartbeat:Connect(function(dt)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")

    -- Anti-Fling
    if Configs.AntiFling then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                for _, part in ipairs(p.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                        pcall(function()
                            part.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
                            part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        end)
                    end
                end
            end
        end
    end

    -- Teleport to Gun
    if Configs.TpToGun and root and not PlayerTemArma() then
        local gunDrop = ObterArmaCaida(root)
        if gunDrop and not hasTeleportedToGun then
            hasTeleportedToGun = true
            originalPositionBeforeGun = root.CFrame
            pcall(function()
                root.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end)
            root.CFrame = gunDrop.CFrame * CFrame.new(0, 1.2, 0)
            task.spawn(function()
                task.wait(0.35)
                if originalPositionBeforeGun and root and Configs.TpToGun then
                    root.CFrame = originalPositionBeforeGun
                end
                task.wait(1.5)
                hasTeleportedToGun = false
            end)
        end
    end

    -- ============================================================
    --  AUTO COLLECT v2 — velocidade segura + cooldown anti-kick
    -- ============================================================
    if Configs.AutoCollect and root then
        -- Invalida alvo se sumiu
        if currentCollectTarget and (
            not currentCollectTarget.Parent or
            not currentCollectTarget:IsDescendantOf(workspace) or
            currentCollectTarget.Transparency >= 1
        ) then
            currentCollectTarget = nil
            lastCoinCollectTime  = os.clock()   -- inicia cooldown após coleta
        end

        -- Busca próxima moeda respeitando cooldown
        if not currentCollectTarget and os.clock() - lastCoinSearch > 0.15 then
            lastCoinSearch = os.clock()
            if os.clock() - lastCoinCollectTime >= COIN_COLLECT_COOLDOWN then
                currentCollectTarget = ObterMoedaProxima(root)
            end
        end

        if currentCollectTarget then
            wasAutoCollecting = true

            if hum then pcall(function() hum.PlatformStand = true end) end

            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end

            local targetPos  = currentCollectTarget.Position
            local currentPos = root.Position
            local dist       = (targetPos - currentPos).Magnitude

            pcall(function()
                root.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end)

            if dist > 1 then
                -- Movimento suave a velocidade segura
                local moveAmount = COIN_FLY_SPEED * dt
                local direction  = (targetPos - currentPos).Unit
                if moveAmount >= dist then
                    root.CFrame = CFrame.new(targetPos)
                else
                    root.CFrame = CFrame.new(currentPos + direction * moveAmount)
                end
            else
                root.CFrame = CFrame.new(targetPos)
                if firetouchinterest then
                    firetouchinterest(root, currentCollectTarget, 0)
                    firetouchinterest(root, currentCollectTarget, 1)
                end
            end
        else
            if wasAutoCollecting then
                wasAutoCollecting = false
                if hum then pcall(function() hum.PlatformStand = false end) end
                if char then
                    for _, part in ipairs(char:GetChildren()) do
                        if part:IsA("BasePart") and (
                            part.Name == "HumanoidRootPart" or part.Name == "Head" or
                            part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "LowerTorso"
                        ) then
                            part.CanCollide = true
                        end
                    end
                end
                if root then root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
            end
        end
    else
        currentCollectTarget = nil
        if wasAutoCollecting then
            wasAutoCollecting = false
            if hum then pcall(function() hum.PlatformStand = false end) end
            if char then
                for _, part in ipairs(char:GetChildren()) do
                    if part:IsA("BasePart") and (
                        part.Name == "HumanoidRootPart" or part.Name == "Head" or
                        part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "LowerTorso"
                    ) then
                        part.CanCollide = true
                    end
                end
            end
            if root then root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
        end
    end

    -- Speed
    if char and root and hum then
        local velocidadeAlvo = Configs.Speed and 23 or 16
        if hum.WalkSpeed ~= velocidadeAlvo then hum.WalkSpeed = velocidadeAlvo end

        -- Knife Reach
        local knife = char:FindFirstChild("Knife")
        if knife and knife:IsA("Tool") then
            local handle = knife:FindFirstChild("Handle")
            if handle then
                local reachPart = handle:FindFirstChild("AkatReachPart")
                if Configs.Reach then
                    if not reachPart then
                        reachPart = Instance.new("Part")
                        reachPart.Name = "AkatReachPart"
                        reachPart.Size = Vector3.new(25, 25, 25)
                        reachPart.Transparency = 1
                        reachPart.CanCollide = false
                        reachPart.Massless = true
                        reachPart.CFrame = handle.CFrame
                        reachPart.Parent = handle
                        local weld = Instance.new("WeldConstraint")
                        weld.Part0 = handle
                        weld.Part1 = reachPart
                        weld.Parent = reachPart
                    end
                    if firetouchinterest then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                local tRoot = p.Character.HumanoidRootPart
                                if (root.Position - tRoot.Position).Magnitude <= 25 then
                                    firetouchinterest(handle, tRoot, 0)
                                    firetouchinterest(handle, tRoot, 1)
                                end
                            end
                        end
                    end
                else
                    if reachPart then reachPart:Destroy() end
                end
            end
        end
    end
end)

task.spawn(ExecutarIntroAkat)
