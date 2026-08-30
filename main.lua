-- [[
--     AKAT STEAL A EGG MAIN LOGIC [v1.0]
--     Compatível com Delta Mobile & PC | Steal a Egg (2026)
--     BACKEND ONLY — sem código de interface visual
--
--     FUNCIONALIDADES v1.0:
--     - Auto Steal: Rouba ovos automaticamente de qualquer área
--     - Steal All Areas: Cicla por todas as áreas do mapa em loop
--     - Instant Steal: Teleporta diretamente ao ovo e rouba instantaneamente
--     - Auto Farm Loop: Loop de farm contínuo e automático
--     - Auto Collect: Coleta ovos e itens próximos automaticamente
--     - Rare Egg Targeting: Foca em raridades específicas de ovos
--     - Egg Predictor: Exibe conteúdo do ovo antes de chocar
--     - Auto Return Base: Retorna à base após cada roubo
--     - Server Hop: Troca de servidor para encontrar ovos raros
--     - ESP: Destaca jogadores e ninhos
--     - Name / Tracer ESP
--     - Speed / Jump / AntiFling / Invisibility / XRay / SafeSpot
--     - Tp Base / Tp Nest
-- ]]

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local TeleportService   = game:GetService("TeleportService")
local HttpService        = game:GetService("HttpService")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local mouse  = player:GetMouse()

local ok_vim, VirtualInputManager = pcall(function()
    return game:GetService("VirtualInputManager")
end)
if not ok_vim then VirtualInputManager = nil end

-- ==================== GUARD CONTRA EXECUÇÃO DUPLICADA ====================
if _G.AkatLogicRunning then
    pcall(function()
        if _G.AkatCallbacks and _G.AkatCallbacks.ShutdownAll then
            _G.AkatCallbacks.ShutdownAll()
        end
    end)
end
_G.AkatLogicRunning = true

-- ==================== FLAG DE SHUTDOWN GLOBAL ====================
local scriptAlive = true

-- ==================== ESTADO DINÂMICO ====================
local stealLoopRunning          = false
local stealAllAreasRunning      = false
local autoFarmLoopRunning       = false
local autoCollectRunning        = false
local serverHopRunning          = false
local currentStealTarget        = nil
local currentFarmTween          = nil
local xrayDescendantConnection  = nil
local XRayParts                 = {}
local invisOriginalTransparency = {}
local knownAreas                = {}
local currentAreaIndex          = 1
local lastStealTime             = 0
local STEAL_COOLDOWN            = 0.5
local eggPredictions            = {}
local rareTargetFilter          = {"Legendary", "Epic", "Rare"} -- raridades alvo padrão

-- ==================== CONFIGURAÇÕES ====================
local Configs = {
    ESP              = false,
    Name             = false,
    Tracer           = false,
    AutoSteal        = false,
    StealAllAreas    = false,
    InstantSteal     = false,
    AutoFarmLoop     = false,
    AutoCollect      = false,
    RareEggTargeting = false,
    EggPredictor     = false,
    AutoReturnBase   = false,
    ServerHop        = false,
    Speed            = false,
    SpeedValue       = 16,
    JumpPower        = false,
    JumpPowerValue   = 50,
    AntiFling        = false,
    SafeSpot         = false,
    XRay             = false,
    Invisibility     = false,
    TpBase           = false,
    TpNest           = false,
    Debug            = false,
}
_G.Configs = Configs

-- ==================== FORWARD DECLARATIONS ====================
local UpdateName
local UpdateTracer
local RemoveVisual
local ESP_UpdatePlayer

-- ==================== DEBUG ====================
local function DebugLog(sistema, msg)
    if Configs.Debug then
        warn(("[AKAT][%s] %s"):format(sistema, tostring(msg)))
    end
end

-- ==================== CACHE CENTRALIZADO ====================
local CachedState = {
    Eggs        = {},  -- ovos detectados no workspace
    RareEggs    = {},  -- ovos raros detectados
    BasePosition = nil, -- posição da base do jogador
    NestPosition = nil, -- posição do ninho mais próximo
}

-- ==================== VARIÁVEIS DE ESTADO ====================
local ESPHighlights         = {}
local espEventConnections   = {}
local espCharConnections    = {}
local hbConnection          = nil
local steppedConnection     = nil
local characterConnection   = nil
local globalPlayerAddedConn  = nil
local globalPlayerRemovingConn = nil
local safePlatform          = nil
local lastPositionBeforeSafeSpot = nil

local EGG_COLORS = {
    Legendary = Color3.fromRGB(255, 165, 0),
    Epic      = Color3.fromRGB(148, 0, 211),
    Rare      = Color3.fromRGB(30, 144, 255),
    Common    = Color3.fromRGB(120, 200, 80),
    Unknown   = Color3.fromRGB(200, 200, 200),
}

-- ==================== DETECÇÃO DE RARIDADE DO OVO ====================
local function GetEggRarity(eggInstance)
    if not eggInstance then return "Unknown" end
    local name = eggInstance.Name:lower()

    -- Busca atributo de raridade primeiro
    local rarity = eggInstance:GetAttribute("Rarity")
        or eggInstance:GetAttribute("rarity")
        or eggInstance:GetAttribute("EggRarity")
    if rarity then
        local r = tostring(rarity)
        if r:find("Legendary") or r:find("legendary") then return "Legendary" end
        if r:find("Epic")      or r:find("epic")      then return "Epic" end
        if r:find("Rare")      or r:find("rare")      then return "Rare" end
        return r
    end

    -- Fallback por nome
    if name:find("legendary") or name:find("golden") or name:find("divine") then return "Legendary" end
    if name:find("epic")      or name:find("mythic")                         then return "Epic" end
    if name:find("rare")      or name:find("special")                        then return "Rare" end
    return "Common"
end

-- ==================== DETECÇÃO DO CONTEÚDO DO OVO (EGG PREDICTOR) ====================
local function PredictEggContent(eggInstance)
    if not eggInstance then return "?" end

    -- Tenta ler atributo de conteúdo
    local content = eggInstance:GetAttribute("Contents")
        or eggInstance:GetAttribute("Pet")
        or eggInstance:GetAttribute("Reward")
    if content then return tostring(content) end

    -- Tenta ler StringValue filho
    for _, child in ipairs(eggInstance:GetDescendants()) do
        if child:IsA("StringValue") and (
            child.Name:lower():find("pet")    or
            child.Name:lower():find("reward") or
            child.Name:lower():find("content")
        ) then
            return child.Value
        end
    end

    local rarity = GetEggRarity(eggInstance)
    return "[" .. rarity .. " Egg]"
end

-- ==================== DETECÇÃO DE OVOS NO WORKSPACE ====================
local function FindAllEggs()
    local eggs = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Model") then
            local name = d.Name:lower()
            if name:find("egg") and not d:IsDescendantOf(Players) then
                -- Evita adicionar partes filhas de modelo já listado
                local alreadyIn = false
                for _, e in ipairs(eggs) do
                    if e == d.Parent then alreadyIn = true; break end
                end
                if not alreadyIn then
                    table.insert(eggs, d)
                end
            end
        end
    end
    return eggs
end

local function FindRareEggs()
    local rare = {}
    for _, egg in ipairs(CachedState.Eggs) do
        local rarity = GetEggRarity(egg)
        for _, filter in ipairs(rareTargetFilter) do
            if rarity == filter then
                table.insert(rare, egg)
                break
            end
        end
    end
    return rare
end

-- Obtém a BasePart principal de um ovo (Model ou Part)
local function GetEggPart(egg)
    if egg:IsA("BasePart") then return egg end
    if egg:IsA("Model") then
        return egg.PrimaryPart
            or egg:FindFirstChildOfClass("BasePart")
    end
    return nil
end

-- ==================== DETECÇÃO DE BASE DO JOGADOR ====================
local function FindPlayerBase()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    -- Busca objeto nomeado "Base", "Nest", "Home", "PlayerBase" no workspace
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Model") then
            local name = d.Name:lower()
            if (name:find("base") or name:find("home") or name:find("spawn")) and
               not d:IsDescendantOf(Players) then
                local part = d:IsA("BasePart") and d or d:FindFirstChildOfClass("BasePart")
                if part and root then
                    return part
                end
            end
        end
    end

    -- SpawnLocation como fallback
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("SpawnLocation") then
            return d
        end
    end

    return nil
end

-- ==================== DETECÇÃO DE NINHOS NO MAPA ====================
local function FindAllNests()
    local nests = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Model") then
            local name = d.Name:lower()
            if name:find("nest") and not d:IsDescendantOf(Players) then
                table.insert(nests, d)
            end
        end
    end
    return nests
end

local function FindNearestNest(root)
    if not root then return nil end
    local nests = FindAllNests()
    local nearest, nearestDist = nil, math.huge
    for _, nest in ipairs(nests) do
        local part = nest:IsA("BasePart") and nest or nest:FindFirstChildOfClass("BasePart")
        if part then
            local dist = (root.Position - part.Position).Magnitude
            if dist < nearestDist then
                nearest = part
                nearestDist = dist
            end
        end
    end
    return nearest
end

-- ==================== DETECÇÃO DE ÁREAS DO MAPA ====================
local function ScanMapAreas()
    local areas = {}
    -- Procura modelos/folders com "Area", "Zone", "Map" no nome
    for _, d in ipairs(workspace:GetChildren()) do
        if (d:IsA("Model") or d:IsA("Folder")) then
            local name = d.Name:lower()
            if name:find("area") or name:find("zone") or name:find("map") or name:find("region") then
                -- Tenta obter um ponto de referência da área
                local refPart = d:IsA("Model") and (d.PrimaryPart or d:FindFirstChildOfClass("BasePart"))
                if refPart then
                    table.insert(areas, {name = d.Name, part = refPart})
                end
            end
        end
    end

    -- Se não encontrou nada, usa ninhos como áreas
    if #areas == 0 then
        local nests = FindAllNests()
        for _, nest in ipairs(nests) do
            local part = nest:IsA("BasePart") and nest or nest:FindFirstChildOfClass("BasePart")
            if part then
                table.insert(areas, {name = nest.Name, part = part})
            end
        end
    end

    return areas
end

-- ==================== ESP ====================
ESP_UpdatePlayer = function(p)
    if not Configs.ESP or p == player then return end
    if not p or not p.Character then
        if ESPHighlights[p] then
            pcall(function() ESPHighlights[p]:Destroy() end)
            ESPHighlights[p] = nil
        end
        return
    end

    local char  = p.Character
    local color = Color3.fromRGB(200, 80, 80)
    local hl    = char:FindFirstChild("AkatESP")
    if not hl then
        hl                   = Instance.new("Highlight")
        hl.Name              = "AkatESP"
        hl.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency  = 0.3
        hl.OutlineTransparency = 0
        hl.Parent            = char
        ESPHighlights[p]     = hl
    end
    hl.FillColor    = color
    hl.OutlineColor = color
end

local function ESP_ClearAll()
    for p, hl in pairs(ESPHighlights) do
        pcall(function() if hl and hl.Parent then hl:Destroy() end end)
        ESPHighlights[p] = nil
    end
end

local function ESP_ConnectPlayer(p)
    if p == player then return end

    if espEventConnections[p] then
        for _, c in ipairs(espEventConnections[p]) do pcall(function() c:Disconnect() end) end
    end
    local conns = {}
    espEventConnections[p] = conns

    table.insert(conns, p.CharacterAdded:Connect(function(char)
        task.wait(0.18)
        if not scriptAlive then return end
        if Configs.ESP  then ESP_UpdatePlayer(p) end
        if Configs.Name then UpdateName(p) end
        if Configs.Tracer then UpdateTracer(p) end
    end))
    table.insert(conns, p.CharacterRemoving:Connect(function()
        RemoveVisual(p)
    end))
    ESP_UpdatePlayer(p)
end

local function ESP_DisconnectPlayer(p)
    if espEventConnections[p] then
        for _, c in ipairs(espEventConnections[p]) do pcall(function() c:Disconnect() end) end
        espEventConnections[p] = nil
    end
    if ESPHighlights[p] then
        pcall(function() ESPHighlights[p]:Destroy() end)
        ESPHighlights[p] = nil
    end
end

local function ESP_Enable()
    Configs.ESP = true
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then ESP_ConnectPlayer(p) end
    end
end

local function ESP_Disable()
    Configs.ESP = false
    for _, p in ipairs(Players:GetPlayers()) do ESP_DisconnectPlayer(p) end
    ESP_ClearAll()
end

-- ==================== NAME / TRACER ====================
local NameTags = {}
local Tracers  = {}

RemoveVisual = function(p)
    if NameTags[p] then
        pcall(function() NameTags[p]:Destroy() end)
        NameTags[p] = nil
    end
    if Tracers[p] then
        local d = Tracers[p]
        pcall(function() d.a:Destroy()    end)
        pcall(function() d.b:Destroy()    end)
        pcall(function() d.beam:Destroy() end)
        Tracers[p] = nil
    end
end

UpdateName = function(p)
    if p == player or not p.Character or not Configs.Name then
        if NameTags[p] then
            pcall(function() NameTags[p]:Destroy() end)
            NameTags[p] = nil
        end
        return
    end
    local head = p.Character:FindFirstChild("Head")
    if not head then return end

    local tag = NameTags[p]
    if not tag or not tag.Parent then
        tag               = Instance.new("BillboardGui")
        tag.Name          = "AkatName"
        tag.Size          = UDim2.fromOffset(140, 26)
        tag.StudsOffset   = Vector3.new(0, 2.8, 0)
        tag.AlwaysOnTop   = true
        tag.Parent        = head

        local label                    = Instance.new("TextLabel")
        label.Name                     = "Name"
        label.Size                     = UDim2.fromScale(1, 1)
        label.BackgroundTransparency   = 1
        label.Font                     = Enum.Font.GothamBold
        label.TextSize                 = 12
        label.TextStrokeTransparency   = 0.55
        label.Parent                   = tag
        NameTags[p] = tag
    end

    local lbl = tag:FindFirstChild("Name")
    if lbl then
        lbl.Text      = p.DisplayName
        lbl.TextColor3 = Color3.fromRGB(200, 80, 80)
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    end
end

UpdateTracer = function(p)
    if p == player or not p.Character or not Configs.Tracer then
        if Tracers[p] then
            local d = Tracers[p]
            pcall(function() d.a:Destroy() end)
            pcall(function() d.b:Destroy() end)
            pcall(function() d.beam:Destroy() end)
            Tracers[p] = nil
        end
        return
    end

    local root = p.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local data = Tracers[p]
    if data and data.beam and data.beam.Parent then
        return
    end

    local a = Instance.new("Attachment", myRoot)
    local b = Instance.new("Attachment", root)
    local beam        = Instance.new("Beam")
    beam.Attachment0  = a
    beam.Attachment1  = b
    beam.Color        = ColorSequence.new(Color3.fromRGB(200, 80, 80))
    beam.Width0       = 0.12
    beam.Width1       = 0.12
    beam.Transparency = NumberSequence.new(0)
    beam.FaceCamera   = true
    beam.Parent       = myRoot

    Tracers[p] = {a = a, b = b, beam = beam}
end

local function Visuals_UpdateAll()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            if Configs.Name   then UpdateName(p)   end
            if Configs.Tracer then UpdateTracer(p) end
        end
    end
end

local function Visuals_ClearAll()
    for p, _ in pairs(NameTags) do RemoveVisual(p) end
    for p, _ in pairs(Tracers)  do RemoveVisual(p) end
end

-- ==================== FUNÇÕES AUXILIARES ====================
local function RestoreLocalCanCollide()
    if Configs.AutoCollect or Configs.SafeSpot or Configs.AntiFling then return end
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then part.CanCollide = true end
    end
end

-- ==================== SHUTDOWN COMPLETO ====================
local function LimparEDesligarAbsolutamente()
    scriptAlive = false

    if hbConnection            then hbConnection:Disconnect();            hbConnection            = nil end
    if steppedConnection       then steppedConnection:Disconnect();       steppedConnection       = nil end
    if characterConnection     then characterConnection:Disconnect();     characterConnection     = nil end
    if xrayDescendantConnection then xrayDescendantConnection:Disconnect(); xrayDescendantConnection = nil end
    if globalPlayerAddedConn   then globalPlayerAddedConn:Disconnect();   globalPlayerAddedConn   = nil end
    if globalPlayerRemovingConn then globalPlayerRemovingConn:Disconnect(); globalPlayerRemovingConn = nil end

    for k, v in pairs(Configs) do
        if type(v) == "boolean" then Configs[k] = false end
    end
    stealLoopRunning     = false
    stealAllAreasRunning = false
    autoFarmLoopRunning  = false
    autoCollectRunning   = false
    serverHopRunning     = false

    ESP_Disable()
    Visuals_ClearAll()

    if safePlatform then
        pcall(function() safePlatform:Destroy() end)
        safePlatform = nil
    end

    if currentFarmTween then
        currentFarmTween:Cancel()
        currentFarmTween = nil
    end

    pcall(function()
        local char = player.Character
        if not char then return end

        for part, origTrans in pairs(invisOriginalTransparency) do
            if part and part.Parent then part.Transparency = origTrans end
        end
        table.clear(invisOriginalTransparency)

        for part, orig in pairs(XRayParts) do
            if part and part.Parent then part.LocalTransparencyModifier = orig end
        end
        table.clear(XRayParts)

        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.Anchored                = false
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end

        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed    = 16
            hum.UseJumpPower = true
            hum.JumpPower    = 50
        end
    end)

    _G.AkatLogicRunning = false
end

-- ==================== AÇÃO DE ROUBO DE OVO ====================
-- Tenta interagir com o ovo via FireTouchInterest / RemoteEvent
local function TryStealEgg(eggPart)
    if not eggPart or not eggPart.Parent then return false end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local now = tick()
    if now - lastStealTime < STEAL_COOLDOWN then return false end
    lastStealTime = now

    local stolen = false

    -- Método 1: FireTouchInterest (mais comum em jogos Roblox)
    pcall(function()
        firetouchinterest(root, eggPart, 0)
        firetouchinterest(root, eggPart, 1)
        stolen = true
    end)

    -- Método 2: Busca RemoteEvent "Steal" / "Collect" / "Grab" no ovo ou seus ancestrais
    if not stolen then
        pcall(function()
            local remotes = {}
            for _, d in ipairs(eggPart:GetDescendants()) do
                if d:IsA("RemoteEvent") then table.insert(remotes, d) end
            end
            -- Busca no pai também
            if eggPart.Parent then
                for _, d in ipairs(eggPart.Parent:GetDescendants()) do
                    if d:IsA("RemoteEvent") then
                        local n = d.Name:lower()
                        if n:find("steal") or n:find("collect") or n:find("grab") or n:find("hatch") then
                            table.insert(remotes, d)
                        end
                    end
                end
            end
            for _, re in ipairs(remotes) do
                pcall(function() re:FireServer(eggPart) end)
            end
            stolen = #remotes > 0
        end)
    end

    -- Método 3: Teleporta até o ovo e usa firetouchinterest em todas as partes do char
    if not stolen then
        pcall(function()
            root.CFrame = CFrame.new(eggPart.Position + Vector3.new(0, 2, 0))
            task.wait(0.05)
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    firetouchinterest(part, eggPart, 0)
                    firetouchinterest(part, eggPart, 1)
                end
            end
            stolen = true
        end)
    end

    DebugLog("Steal", stolen and "Ovo roubado: " .. eggPart.Name or "Falha ao roubar: " .. eggPart.Name)
    return stolen
end

-- ==================== CALLBACKS DA UI EXTERNA ====================
_G.AkatCallbacks = {

    ESP = function(enabled)
        if enabled then ESP_Enable() else ESP_Disable() end
    end,

    Name = function(enabled)
        Configs.Name = enabled and true or false
        if not Configs.Name then
            for p, tag in pairs(NameTags) do
                pcall(function() tag:Destroy() end)
                NameTags[p] = nil
            end
        else
            Visuals_UpdateAll()
        end
    end,

    Tracer = function(enabled)
        Configs.Tracer = enabled and true or false
        if not Configs.Tracer then
            for p, d in pairs(Tracers) do
                pcall(function() d.a:Destroy()    end)
                pcall(function() d.b:Destroy()    end)
                pcall(function() d.beam:Destroy() end)
                Tracers[p] = nil
            end
        else
            Visuals_UpdateAll()
        end
    end,

    Speed = function(value)
        if type(value) == "number" then
            Configs.SpeedValue = math.clamp(value, 0, 200)
            Configs.Speed = true
        else
            Configs.Speed = value and true or false
        end
        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Configs.Speed and Configs.SpeedValue or 16 end
    end,

    JumpPower = function(value)
        if type(value) == "number" then
            Configs.JumpPowerValue = math.clamp(value, 0, 200)
            Configs.JumpPower = true
        else
            Configs.JumpPower = value and true or false
        end
        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower    = Configs.JumpPower and Configs.JumpPowerValue or 50
        end
    end,

    AntiFling = function(enabled)
        Configs.AntiFling = enabled and true or false
        if not Configs.AntiFling then RestoreLocalCanCollide() end
    end,

    -- ==================== AUTO STEAL ====================
    -- Procura o ovo mais próximo e tenta roubá-lo em loop.
    AutoSteal = function(enabled)
        Configs.AutoSteal = enabled and true or false
        if not enabled then
            stealLoopRunning = false
            return
        end
        if stealLoopRunning then return end
        stealLoopRunning = true

        task.spawn(function()
            while scriptAlive and Configs.AutoSteal do
                task.wait(0.15)
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if not char or not root or not hum or hum.Health <= 0 then continue end

                local eggs = Configs.RareEggTargeting and CachedState.RareEggs or CachedState.Eggs
                local nearest, nearestDist = nil, math.huge

                for _, egg in ipairs(eggs) do
                    local part = GetEggPart(egg)
                    if part and part.Parent then
                        local dist = (root.Position - part.Position).Magnitude
                        if dist < nearestDist and dist < 2000 then
                            nearest = part
                            nearestDist = dist
                        end
                    end
                end

                if nearest then
                    -- Aproxima-se do ovo suavemente antes de interagir
                    if nearestDist > 6 then
                        local travelTime = math.clamp(nearestDist / 40, 0.05, 3)
                        if currentFarmTween then currentFarmTween:Cancel() end
                        currentFarmTween = TweenService:Create(
                            root,
                            TweenInfo.new(travelTime, Enum.EasingStyle.Linear),
                            {CFrame = CFrame.new(nearest.Position + Vector3.new(0, 2, 0))}
                        )
                        currentFarmTween:Play()
                        task.wait(travelTime)
                    end
                    TryStealEgg(nearest)
                    if Configs.AutoReturnBase then
                        local base = FindPlayerBase()
                        if base and root then
                            root.CFrame = CFrame.new(base.Position + Vector3.new(0, 3, 0))
                        end
                    end
                end
            end
            stealLoopRunning = false
        end)
    end,

    AutoStealOnce = function()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local eggs = Configs.RareEggTargeting and CachedState.RareEggs or CachedState.Eggs
        local nearest, nearestDist = nil, math.huge
        for _, egg in ipairs(eggs) do
            local part = GetEggPart(egg)
            if part and part.Parent then
                local dist = (root.Position - part.Position).Magnitude
                if dist < nearestDist then nearest = part; nearestDist = dist end
            end
        end
        if nearest then TryStealEgg(nearest) end
    end,

    -- ==================== STEAL ALL AREAS ====================
    -- Cicla por todas as áreas detectadas no mapa roubando ovos em cada uma.
    StealAllAreas = function(enabled)
        Configs.StealAllAreas = enabled and true or false
        if not enabled then
            stealAllAreasRunning = false
            return
        end
        if stealAllAreasRunning then return end
        stealAllAreasRunning = true

        task.spawn(function()
            local areas = ScanMapAreas()
            if #areas == 0 then
                stealAllAreasRunning = false
                warn("[AKAT] StealAllAreas: Nenhuma área encontrada no mapa.")
                return
            end

            local idx = 1
            while scriptAlive and Configs.StealAllAreas do
                task.wait(0.1)
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if not char or not root or not hum or hum.Health <= 0 then continue end

                local area = areas[idx]
                if not area or not area.part or not area.part.Parent then
                    areas = ScanMapAreas()
                    if #areas == 0 then task.wait(1); continue end
                    idx = 1
                    continue
                end

                DebugLog("StealAllAreas", "Visitando área: " .. tostring(area.name))

                -- Teleporta para a área
                root.CFrame = CFrame.new(area.part.Position + Vector3.new(0, 4, 0))
                task.wait(0.3)

                -- Rouba todos os ovos próximos da área
                local collected = 0
                for _, egg in ipairs(CachedState.Eggs) do
                    local part = GetEggPart(egg)
                    if part and part.Parent then
                        local dist = (area.part.Position - part.Position).Magnitude
                        if dist < 80 then
                            TryStealEgg(part)
                            collected += 1
                            task.wait(0.1)
                        end
                    end
                end

                DebugLog("StealAllAreas", "Coletados " .. collected .. " ovos na área.")

                if Configs.AutoReturnBase then
                    local base = FindPlayerBase()
                    if base and root then
                        root.CFrame = CFrame.new(base.Position + Vector3.new(0, 3, 0))
                        task.wait(0.5)
                    end
                end

                idx = (idx % #areas) + 1
                task.wait(0.5)
            end
            stealAllAreasRunning = false
        end)
    end,

    -- ==================== INSTANT STEAL ====================
    -- Teleporta diretamente até o ovo mais próximo e rouba instantaneamente.
    InstantSteal = function(enabled)
        Configs.InstantSteal = enabled and true or false
    end,

    InstantStealOnce = function()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local eggs = Configs.RareEggTargeting and CachedState.RareEggs or CachedState.Eggs
        if #eggs == 0 then
            DebugLog("InstantSteal", "Nenhum ovo encontrado.")
            return
        end

        local nearest, nearestDist = nil, math.huge
        for _, egg in ipairs(eggs) do
            local part = GetEggPart(egg)
            if part and part.Parent then
                local dist = (root.Position - part.Position).Magnitude
                if dist < nearestDist then nearest = part; nearestDist = dist end
            end
        end

        if nearest then
            -- Teleporte instantâneo
            root.CFrame = CFrame.new(nearest.Position + Vector3.new(0, 2, 0))
            task.wait(0.05)
            TryStealEgg(nearest)
            DebugLog("InstantSteal", "Teleportado e roubado: " .. nearest.Name)

            if Configs.AutoReturnBase then
                local base = FindPlayerBase()
                if base then root.CFrame = CFrame.new(base.Position + Vector3.new(0, 3, 0)) end
            end
        end
    end,

    -- ==================== AUTO FARM LOOP ====================
    -- Loop de farm automático e contínuo — cicla entre todos os ovos disponíveis.
    AutoFarmLoop = function(enabled)
        Configs.AutoFarmLoop = enabled and true or false
        if not enabled then
            autoFarmLoopRunning = false
            return
        end
        if autoFarmLoopRunning then return end
        autoFarmLoopRunning = true

        task.spawn(function()
            while scriptAlive and Configs.AutoFarmLoop do
                task.wait(0.12)
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if not char or not root or not hum or hum.Health <= 0 then continue end

                local eggs = CachedState.Eggs
                if #eggs == 0 then task.wait(0.5); continue end

                for _, egg in ipairs(eggs) do
                    if not scriptAlive or not Configs.AutoFarmLoop then break end
                    local part = GetEggPart(egg)
                    if part and part.Parent then
                        local dist = (root.Position - part.Position).Magnitude
                        local travelTime = math.clamp(dist / 50, 0.05, 2.5)
                        if currentFarmTween then currentFarmTween:Cancel() end
                        currentFarmTween = TweenService:Create(
                            root,
                            TweenInfo.new(travelTime, Enum.EasingStyle.Linear),
                            {CFrame = CFrame.new(part.Position + Vector3.new(0, 2, 0))}
                        )
                        currentFarmTween:Play()
                        task.wait(travelTime + 0.05)
                        TryStealEgg(part)
                    end
                end

                if Configs.AutoReturnBase then
                    local base = FindPlayerBase()
                    if base and root then
                        root.CFrame = CFrame.new(base.Position + Vector3.new(0, 3, 0))
                        task.wait(0.4)
                    end
                end
            end
            autoFarmLoopRunning = false
        end)
    end,

    -- ==================== AUTO COLLECT ====================
    -- Coleta automaticamente ovos e itens próximos ao personagem.
    AutoCollect = function(enabled)
        Configs.AutoCollect = enabled and true or false
        if not enabled then
            autoCollectRunning = false
            return
        end
        if autoCollectRunning then return end
        autoCollectRunning = true

        task.spawn(function()
            while scriptAlive and Configs.AutoCollect do
                task.wait(0.1)
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not char or not root then continue end

                -- FireTouchInterest em todos os ovos/itens próximos (raio: 20 studs)
                for _, egg in ipairs(CachedState.Eggs) do
                    local part = GetEggPart(egg)
                    if part and part.Parent then
                        local dist = (root.Position - part.Position).Magnitude
                        if dist < 20 then
                            pcall(function()
                                firetouchinterest(root, part, 0)
                                firetouchinterest(root, part, 1)
                            end)
                        end
                    end
                end

                -- Também tenta coletar quaisquer itens coletáveis próximos genéricos
                for _, d in ipairs(workspace:GetDescendants()) do
                    if d:IsA("BasePart") and d.Transparency < 1 and not d:IsDescendantOf(Players) then
                        local name = d.Name:lower()
                        if name:find("collect") or name:find("pickup") or name:find("item") then
                            local dist = (root.Position - d.Position).Magnitude
                            if dist < 20 then
                                pcall(function()
                                    firetouchinterest(root, d, 0)
                                    firetouchinterest(root, d, 1)
                                end)
                            end
                        end
                    end
                end
            end
            autoCollectRunning = false
        end)
    end,

    -- ==================== RARE EGG TARGETING ====================
    -- Liga/desliga o filtro de raridade para as funções de steal/farm.
    RareEggTargeting = function(enabled)
        Configs.RareEggTargeting = enabled and true or false
        if enabled then
            DebugLog("RareEggTargeting", "Focando em: " .. table.concat(rareTargetFilter, ", "))
        end
    end,

    -- ==================== EGG PREDICTOR ====================
    -- Quando ativado, exibe no chat/output o conteúdo previsto dos ovos próximos.
    EggPredictor = function(enabled)
        Configs.EggPredictor = enabled and true or false
        if not enabled then
            table.clear(eggPredictions)
            return
        end

        task.spawn(function()
            while scriptAlive and Configs.EggPredictor do
                task.wait(2)
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not root then continue end

                for _, egg in ipairs(CachedState.Eggs) do
                    local part = GetEggPart(egg)
                    if part and part.Parent then
                        local dist = (root.Position - part.Position).Magnitude
                        if dist < 60 then
                            local content = PredictEggContent(egg)
                            local rarity  = GetEggRarity(egg)
                            local key = tostring(egg) .. tostring(egg:GetFullName())
                            if not eggPredictions[key] then
                                eggPredictions[key] = true
                                warn(("[AKAT][EggPredictor] %s | Raridade: %s | Conteúdo: %s"):format(
                                    egg.Name, rarity, content
                                ))
                            end
                        end
                    end
                end
            end
        end)
    end,

    -- ==================== AUTO RETURN BASE ====================
    -- Toggle — a lógica de retorno é aplicada nas funções de steal acima.
    AutoReturnBase = function(enabled)
        Configs.AutoReturnBase = enabled and true or false
    end,

    -- ==================== SERVER HOP ====================
    -- Troca de servidor em busca de ovos raros.
    ServerHop = function(enabled)
        Configs.ServerHop = enabled and true or false
        if not enabled then
            serverHopRunning = false
            return
        end
        if serverHopRunning then return end
        serverHopRunning = true

        task.spawn(function()
            while scriptAlive and Configs.ServerHop do
                task.wait(5) -- verifica a cada 5 segundos

                -- Só troca se não houver ovos raros no servidor atual
                if #CachedState.RareEggs > 0 then
                    DebugLog("ServerHop", "Ovos raros encontrados — mantendo servidor.")
                    task.wait(10)
                    continue
                end

                DebugLog("ServerHop", "Nenhum ovo raro. Trocando de servidor...")
                pcall(function()
                    local placeId = game.PlaceId
                    TeleportService:Teleport(placeId, player)
                end)
                task.wait(5)
            end
            serverHopRunning = false
        end)
    end,

    -- ==================== TP BASE ====================
    TpBase = function(enabled)
        Configs.TpBase = false
        if not enabled then return end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local base = FindPlayerBase()
        if base then
            root.CFrame = CFrame.new(base.Position + Vector3.new(0, 4, 0))
            DebugLog("TpBase", "Teleportado para: " .. base.Name)
        else
            warn("[AKAT] TpBase: Base não encontrada no mapa.")
        end
    end,

    -- ==================== TP NEST ====================
    TpNest = function(enabled)
        Configs.TpNest = false
        if not enabled then return end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local nest = FindNearestNest(root)
        if nest then
            root.CFrame = CFrame.new(nest.Position + Vector3.new(0, 4, 0))
            DebugLog("TpNest", "Teleportado para ninho: " .. nest.Name)
        else
            warn("[AKAT] TpNest: Nenhum ninho encontrado no mapa.")
        end
    end,

    -- ==================== SAFE SPOT ====================
    SafeSpot = function(enabled)
        Configs.SafeSpot = enabled
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        if enabled then
            lastPositionBeforeSafeSpot = root.CFrame
            if not safePlatform or not safePlatform.Parent then
                safePlatform             = Instance.new("Part")
                safePlatform.Name        = "AkatSafePlatform"
                safePlatform.Size        = Vector3.new(15, 1, 15)
                safePlatform.Position    = Vector3.new(root.Position.X, 900, root.Position.Z)
                safePlatform.Anchored    = true
                safePlatform.Transparency = 0.4
                safePlatform.Material    = Enum.Material.ForceField
                safePlatform.Color       = Color3.fromHex("#8B0000")
                safePlatform.Parent      = workspace
            end
            root.CFrame = safePlatform.CFrame * CFrame.new(0, 3, 0)
        else
            if safePlatform then safePlatform:Destroy(); safePlatform = nil end
            if lastPositionBeforeSafeSpot and root.Parent then
                root.CFrame = lastPositionBeforeSafeSpot
                lastPositionBeforeSafeSpot = nil
            end
            RestoreLocalCanCollide()
        end
    end,

    -- ==================== X-RAY ====================
    XRay = function(enabled)
        Configs.XRay = enabled and true or false

        if xrayDescendantConnection then
            xrayDescendantConnection:Disconnect()
            xrayDescendantConnection = nil
        end

        if not Configs.XRay then
            for part, original in pairs(XRayParts) do
                if part and part.Parent then part.LocalTransparencyModifier = original end
            end
            table.clear(XRayParts)
            return
        end

        local function applyXRay(part)
            if not Configs.XRay or not part:IsA("BasePart") then return end
            local char = player.Character
            if part:IsDescendantOf(char) or part:IsDescendantOf(Camera) then return end
            if XRayParts[part] == nil then XRayParts[part] = part.LocalTransparencyModifier end
            part.LocalTransparencyModifier = 0.55
        end

        for _, d in ipairs(workspace:GetDescendants()) do applyXRay(d) end

        xrayDescendantConnection = workspace.DescendantAdded:Connect(function(d)
            if d:IsA("BasePart") then task.defer(function() applyXRay(d) end) end
        end)
    end,

    -- ==================== INVISIBILITY ====================
    Invisibility = function(enabled)
        Configs.Invisibility = enabled
        local char = player.Character
        if not char then return end

        if enabled then
            table.clear(invisOriginalTransparency)
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    invisOriginalTransparency[part] = part.Transparency
                    part.Transparency = 1
                elseif part:IsA("Decal") then
                    invisOriginalTransparency[part] = part.Transparency
                    part.Transparency = 1
                end
            end
        else
            for part, origTrans in pairs(invisOriginalTransparency) do
                if part and part.Parent then part.Transparency = origTrans end
            end
            table.clear(invisOriginalTransparency)
        end
    end,

    ShutdownAll = function()
        LimparEDesligarAbsolutamente()
    end,
}

-- ==================== THREAD CENTRAL: SCANNER E CACHE ====================
task.spawn(function()
    local tempoUltimoScanESP  = 0
    local tempoUltimoScanEggs = 0

    while scriptAlive do
        local agora = tick()

        -- Scan de ESP
        if Configs.ESP and (agora - tempoUltimoScanESP > 0.35) then
            tempoUltimoScanESP = agora
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player then ESP_UpdatePlayer(p) end
            end
        end

        -- Scan de ovos
        if agora - tempoUltimoScanEggs > 0.4 then
            tempoUltimoScanEggs = agora
            CachedState.Eggs = FindAllEggs()
            CachedState.RareEggs = FindRareEggs()

            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                CachedState.NestPosition = FindNearestNest(root)
            end
        end

        -- Atualiza Name / Tracer continuamente
        if Configs.Name or Configs.Tracer then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    if Configs.Name   then UpdateName(p)   end
                    if Configs.Tracer then UpdateTracer(p) end
                end
            end
        end

        task.wait(0.2)
    end
end)

-- ==================== CICLO DE VIDA: RESPAWN ====================
local function ResetState()
    stealLoopRunning     = false
    stealAllAreasRunning = false
    autoFarmLoopRunning  = false
    autoCollectRunning   = false
    currentStealTarget   = nil
    if currentFarmTween then currentFarmTween:Cancel(); currentFarmTween = nil end
    table.clear(invisOriginalTransparency)

    Visuals_ClearAll()

    if Configs.ESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then ESP_ConnectPlayer(p) end
        end
    end

    task.spawn(function()
        task.wait(0.5)
        if not scriptAlive then return end
        if Configs.Name or Configs.Tracer then Visuals_UpdateAll() end
    end)
end

characterConnection = player.CharacterAdded:Connect(function(char)
    ResetState()
    task.wait(0.2)

    if Configs.XRay then
        if xrayDescendantConnection then
            xrayDescendantConnection:Disconnect()
            xrayDescendantConnection = nil
        end
        task.defer(function()
            if Configs.XRay and scriptAlive then _G.AkatCallbacks.XRay(true) end
        end)
    end

    if Configs.Invisibility and char.Parent then
        table.clear(invisOriginalTransparency)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                invisOriginalTransparency[part] = part.Transparency
                part.Transparency = 1
            elseif part:IsA("Decal") then
                invisOriginalTransparency[part] = part.Transparency
                part.Transparency = 1
            end
        end
    end

    -- Re-ativa loops que estavam ligados antes do respawn
    if Configs.AutoSteal        then _G.AkatCallbacks.AutoSteal(true)        end
    if Configs.StealAllAreas    then _G.AkatCallbacks.StealAllAreas(true)    end
    if Configs.AutoFarmLoop     then _G.AkatCallbacks.AutoFarmLoop(true)     end
    if Configs.AutoCollect      then _G.AkatCallbacks.AutoCollect(true)      end
    if Configs.EggPredictor     then _G.AkatCallbacks.EggPredictor(true)     end
end)

-- ==================== HANDLERS GLOBAIS DE JOGADORES ====================
globalPlayerAddedConn = Players.PlayerAdded:Connect(function(p)
    if Configs.ESP and scriptAlive then ESP_ConnectPlayer(p) end
end)

globalPlayerRemovingConn = Players.PlayerRemoving:Connect(function(p)
    ESP_DisconnectPlayer(p)
    RemoveVisual(p)
end)

-- ==================== NOCLIP SEGURO (Stepped) ====================
steppedConnection = RunService.Stepped:Connect(function()
    if not scriptAlive then return end
    if Configs.AutoCollect or Configs.SafeSpot or Configs.AntiFling then
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)

-- ==================== LOOP PRINCIPAL (Heartbeat) ====================
hbConnection = RunService.Heartbeat:Connect(function()
    if not scriptAlive then return end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    hum.WalkSpeed    = Configs.Speed    and Configs.SpeedValue    or 16
    hum.UseJumpPower = true
    hum.JumpPower    = Configs.JumpPower and Configs.JumpPowerValue or 50

    if Configs.AntiFling then
        if root.AssemblyLinearVelocity.Magnitude  > 60
            or root.AssemblyAngularVelocity.Magnitude > 60 then
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
end)

-- ==================== INICIALIZADOR DA UI EXTERNA ====================
task.spawn(function()
    local uiRawUrl = "https://raw.githubusercontent.com/estratosfera88-afk/Ui-do-teste/refs/heads/main/ui.lua"

    local rawContent = nil
    local fetchOk, fetchErr = pcall(function()
        rawContent = game:HttpGet(uiRawUrl, true)
    end)

    if not fetchOk then
        warn("[AKAT LOGIC] HttpGet falhou: " .. tostring(fetchErr))
        return
    end
    if not rawContent or rawContent == "" then
        warn("[AKAT LOGIC] HttpGet retornou vazio. Verifique a URL.")
        return
    end

    local fn, compileErr = loadstring(rawContent)
    if not fn then
        warn("[AKAT LOGIC] loadstring falhou: " .. tostring(compileErr))
        return
    end

    local runOk, runErr = pcall(fn)
    if not runOk then
        warn("[AKAT LOGIC] Erro ao executar a UI: " .. tostring(runErr))
    end
end)
