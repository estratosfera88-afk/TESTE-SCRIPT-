-- [[
--     AKAT BLOX FRUITS MAIN LOGIC [v1.0]
--     Compatível com Delta Mobile & PC | Blox Fruits (2026)
--     BACKEND ONLY — sem código de interface visual
--
--     ARQUITETURA:
--     - Farm Manager central (máquina de estados única)
--     - Auto Quest, Auto Level, Mastery, Boss, Material = módulos do Manager
--     - Somente UM controlador de personagem ativo por vez
--     - Shutdown limpo com restauração total do estado
-- ]]

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==================== GUARD CONTRA EXECUÇÃO DUPLICADA ====================
if _G.AkatBFLogicRunning then
    pcall(function()
        if _G.AkatCallbacks and _G.AkatCallbacks.ShutdownAll then
            _G.AkatCallbacks.ShutdownAll()
        end
    end)
end
_G.AkatBFLogicRunning = true

-- ==================== FLAG DE SHUTDOWN GLOBAL ====================
local scriptAlive = true

-- ==================== CONFIGURAÇÕES ====================
local Configs = {
    -- Farm
    AutoFarm        = false,
    AutoQuest       = false,
    AutoLevel       = false,
    KillAura        = false,
    FightingStyle   = "Current",  -- "Current" | "Melee" | nome do estilo
    FarmPosition    = "Above",    -- "Above" | "Behind" | "Front" | "Near"
    FarmHeight      = 8,          -- distância acima do NPC

    -- Mastery
    AutoMastery     = false,
    MasteryType     = "FightingStyle", -- "FightingStyle" | "Sword" | "Gun" | "BloxFruit"
    MasteryTarget   = 300,

    -- Boss
    AutoBoss        = false,
    BossName        = "Any",
    BossQuest       = false,
    BossMode        = "Selected",  -- "Selected" | "Available" | "Rotation"
    AutoServerSearch = false,
    ServerReason    = "Boss",

    -- Material
    AutoMaterial    = false,
    MaterialName    = "Any",
    MaterialAmount  = 50,

    -- Fruit
    DetectFruit     = false,
    FruitNotification = false,
    FruitFilter     = "Any",

    -- Sea Event
    AutoSeaEvent    = false,
    SeaEventName    = "Any",

    -- Stats
    AutoStats       = false,
    StatPrimary     = "BloxFruit",
    StatSecondary   = "Defense",
    StatTertiary    = "Melee",

    -- Misc
    SpeedValue      = 16,
    JumpPowerValue  = 50,
    AntiFling       = false,
    ESP             = false,
    Name            = false,
    Tracer          = false,
    XRay            = false,
    ViewReach       = false,
    Debug           = false,
}
_G.Configs = Configs

-- ==================== HELPERS DE COMPATIBILIDADE ====================
local function IsAnyFarmModeEnabled()
    return Configs.AutoFarm or Configs.AutoMastery or Configs.AutoBoss or Configs.AutoMaterial
end

local function NormalizeFarmPosition(value)
    local v = tostring(value or "Above"):lower()
    if v:find("behind") then return "Behind" end
    if v:find("front") then return "Front" end
    if v:find("near") then return "Near" end
    return "Above"
end

local function NormalizeMasteryType(value)
    local v = tostring(value or "FightingStyle"):lower()
    if v:find("sword") then return "Sword" end
    if v:find("gun") then return "Gun" end
    if v:find("fruit") then return "BloxFruit" end
    return "FightingStyle"
end

local function NormalizeBossMode(value)
    local v = tostring(value or "Selected"):lower()
    if v:find("available") then return "Available" end
    if v:find("rotation") then return "Rotation" end
    return "Selected"
end
\nlocal function NormalizeBossName(value)
    local v = tostring(value or "Any")
    if v == "Any Boss" then return "Any" end
    return v
end

local function NormalizeStat(value)
    local v = tostring(value or ""):lower()
    if v:find("fruit") then return "BloxFruit" end
    if v:find("defense") then return "Defense" end
    if v:find("melee") then return "Melee" end
    if v:find("sword") then return "Sword" end
    if v:find("gun") then return "Gun" end
    return "Melee"
end

local function NormalizeMaterial(value)
    local v = tostring(value or "Any")
    return v == "" and "Any" or v
end


-- ==================== ESTADO DO FARM MANAGER ====================
-- Estados possíveis da máquina
local FM_STATES = {
    IDLE            = "Idle",
    INIT            = "Initializing",
    CHECK_CHAR      = "Checking Character",
    CHECK_LEVEL     = "Checking Level",
    FIND_QUEST      = "Finding Quest",
    GET_QUEST       = "Getting Quest",
    FIND_TARGET     = "Finding Target",
    TRAVEL          = "Traveling",
    POSITION        = "Positioning",
    FARMING         = "Farming",
    TARGET_DEAD     = "Target Dead",
    QUEST_COMPLETE  = "Quest Complete",
    CHANGE_AREA     = "Changing Area",
    MASTERY_FARM    = "Mastery Farming",
    BOSS_FARM       = "Boss Farming",
    MATERIAL_FARM   = "Material Farming",
    SERVER_SEARCH   = "Server Searching",
    ERROR_RECOVERY  = "Error Recovery",
    COMPLETED       = "Completed",
    STOPPED         = "Stopped",
}

local FarmManager = {
    State       = FM_STATES.IDLE,
    Mode        = "None",         -- "Level" | "Mastery" | "Boss" | "Material"
    Task        = "None",
    Quest       = "None",
    Target      = "None",
    Area        = "None",
    Level       = 0,
    Sea         = 1,
    Progress    = 0,              -- 0-100
    KillCount   = 0,
    KillRequired= 0,
    CurrentTarget = nil,          -- instância do NPC
    CurrentQuestGiver = nil,
    LastError   = "",
    LoopRunning = false,
    Generation  = 0,              -- incrementado a cada reinício para cancelar loops antigos
}
_G.FarmManager = FarmManager

-- ==================== DEBUG ====================
local function DebugLog(sistema, msg)
    if Configs.Debug then
        warn(("[AKAT-BF][%s] %s"):format(sistema, tostring(msg)))
    end
end

-- ==================== FORWARD DECLARATIONS ====================
local UpdateFarmStatus
local StopFarm
local SelectNextTarget
local TravelToPosition
local EquipFightingStyle

-- ==================== UTILIDADES ====================
local function GetCharacter()
    return player.Character
end

local function GetRoot()
    local char = GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function IsAlive()
    local hum = GetHumanoid()
    return hum ~= nil and hum.Health > 0
end

local function GetLevel()
    local ok, level = pcall(function()
        -- Verifica múltiplos locais onde o level pode estar armazenado em BF
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local lv = ls:FindFirstChild("Level") or ls:FindFirstChild("Lv")
            if lv then return lv.Value end
        end
        -- Fallback via PlayerData remoto
        local pd = player:FindFirstChild("PlayerData") or player:FindFirstChild("Data")
        if pd then
            local lv = pd:FindFirstChild("Level") or pd:FindFirstChild("Lv")
            if lv then return lv.Value end
        end
        return 0
    end)
    return ok and level or 0
end

local function GetSea()
    -- Sea 1 = Lv 1-700, Sea 2 = 701-1500, Sea 3 = 1500+
    local lv = GetLevel()
    if lv >= 1500 then return 3
    elseif lv >= 700 then return 2
    else return 1 end
end

local function GetStatPoints()
    local ok, pts = pcall(function()
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local sp = ls:FindFirstChild("StatPoints") or ls:FindFirstChild("Stat Points")
            if sp then return sp.Value end
        end
        return 0
    end)
    return ok and pts or 0
end

local function GetMastery(itemType)
    local ok, m = pcall(function()
        local char = GetCharacter()
        if not char then return 0 end
        local normalized = NormalizeMasteryType(itemType)
        local tool
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") then
                tool = obj
                break
            end
        end
        local candidates = {char, tool}
        for _, obj in ipairs(candidates) do
            if obj then
                local value = obj:GetAttribute("Mastery")
                    or obj:GetAttribute("Level")
                    or obj:GetAttribute("MasteryLevel")
                if type(value) == "number" then return value end
            end
        end
        return 0
    end)
    return ok and m or 0
end

local function GetMaterialCount(materialName)
    local ok, count = pcall(function()
        local name = NormalizeMaterial(materialName)
        if name == "Any" then return 0 end
        local inv = player:FindFirstChild("Inventory")
        if inv then
            local mat = inv:FindFirstChild(name, true)
            if mat then
                if mat:IsA("IntValue") or mat:IsA("NumberValue") then return mat.Value end
                local attr = mat:GetAttribute("Amount") or mat:GetAttribute("Count")
                if type(attr) == "number" then return attr end
            end
        end
        local attr = player:GetAttribute(name) or player:GetAttribute(name:gsub("%s+", ""))
        return type(attr) == "number" and attr or 0
    end)
    return ok and count or 0
end

-- ==================== DETECÇÃO DE ÁREA / QUEST ====================
-- Tabela de progressão por level (Sea 1)
local SEA1_AREAS = {
    {minLv=1,   maxLv=14,   area="Middle Town",      quest="Bandit",          npcName="Bandit",        killReq=8 },
    {minLv=15,  maxLv=29,   area="Jungle",           quest="Monkey",          npcName="Monkey",        killReq=8 },
    {minLv=30,  maxLv=59,   area="Pirate Village",   quest="Pirate",          npcName="Pirate",        killReq=8 },
    {minLv=60,  maxLv=89,   area="Desert",           quest="Desert Bandit",   npcName="Desert Bandit", killReq=8 },
    {minLv=90,  maxLv=119,  area="Frozen Village",   quest="Snow Bandit",     npcName="Snow Bandit",   killReq=8 },
    {minLv=120, maxLv=174,  area="Marine Fortress",  quest="Marine",          npcName="Marine",        killReq=10},
    {minLv=175, maxLv=299,  area="Skylands",         quest="Skypiea Warrior", npcName="Sky Bandit",    killReq=10},
    {minLv=300, maxLv=374,  area="Prison",           quest="Prisoner",        npcName="Prisoner",      killReq=10},
    {minLv=375, maxLv=449,  area="Colosseum",        quest="Gladiator",       npcName="Gladiator",     killReq=10},
    {minLv=450, maxLv=524,  area="Magma Village",    quest="Magma Ninja",     npcName="Magma Ninja",   killReq=10},
    {minLv=525, maxLv=624,  area="Underwater City",  quest="Dragon Crew",     npcName="Dragon Crew",   killReq=10},
    {minLv=625, maxLv=699,  area="Fountain City",    quest="Dark Master",     npcName="Dark Master",   killReq=10},
}

-- Sea 2
local SEA2_AREAS = {
    {minLv=700,  maxLv=774,  area="Kingdom of Rose",  quest="Galley Pirate",    npcName="Galley Pirate",   killReq=8 },
    {minLv=775,  maxLv=874,  area="Green Zone",       quest="Factory Bandit",   npcName="Factory Bandit",  killReq=8 },
    {minLv=875,  maxLv=924,  area="Graveyard",        quest="Possessed Mummy",  npcName="Possessed Mummy", killReq=8 },
    {minLv=925,  maxLv=999,  area="Snow Mountain",    quest="Snowman",          npcName="Snowman",         killReq=8 },
    {minLv=1000, maxLv=1049, area="Hot & Cold",       quest="Ice Demon",        npcName="Ice Demon",       killReq=10},
    {minLv=1050, maxLv=1174, area="Cursed Ship",      quest="Ship Deckhand",    npcName="Ship Deckhand",   killReq=10},
    {minLv=1175, maxLv=1274, area="Ice Castle",       quest="Ice Admiral",      npcName="Ice Admiral",     killReq=10},
    {minLv=1275, maxLv=1374, area="Forgotten Island", quest="Demonic Soul",     npcName="Demonic Soul",    killReq=10},
    {minLv=1375, maxLv=1499, area="Flamingo",         quest="Drug Barto",       npcName="Drug Barto",      killReq=10},
}

-- Sea 3
local SEA3_AREAS = {
    {minLv=1500, maxLv=1574, area="Port Town",        quest="Stone",            npcName="Stone",           killReq=8 },
    {minLv=1575, maxLv=1649, area="Hydra Island",     quest="Sea Soldier",      npcName="Sea Soldier",     killReq=8 },
    {minLv=1650, maxLv=1749, area="Great Tree",       quest="Forest Pirate",    npcName="Forest Pirate",   killReq=8 },
    {minLv=1750, maxLv=1874, area="Floating Turtle",  quest="Fishman Raider",   npcName="Fishman Raider",  killReq=10},
    {minLv=1875, maxLv=1999, area="Haunted Castle",   quest="Demonic Ghoul",    npcName="Demonic Ghoul",   killReq=10},
    {minLv=2000, maxLv=2074, area="Sea of Treats",    quest="Sweet Thief",      npcName="Sweet Thief",     killReq=10},
    {minLv=2075, maxLv=2249, area="Cake Island",      quest="Cake Guard",       npcName="Cake Guard",      killReq=10},
    {minLv=2250, maxLv=2449, area="Candy Island",     quest="Cocoa Warrior",    npcName="Cocoa Warrior",   killReq=10},
    {minLv=2450, maxLv=9999, area="Ice Cream Island", quest="Ice Cream Angel",  npcName="Ice Cream Angel", killReq=10},
}

local function GetAreaData(level)
    local function search(t)
        for _, d in ipairs(t) do
            if level >= d.minLv and level <= d.maxLv then
                return d
            end
        end
        return nil
    end

    local sea = GetSea()
    if sea == 3 then return search(SEA3_AREAS)
    elseif sea == 2 then return search(SEA2_AREAS)
    else return search(SEA1_AREAS) end
end

-- ==================== SISTEMA DE TARGET ====================
local function IsValidNPC(model)
    if not model or not model.Parent then return false end
    if not model:IsA("Model") then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local root = model:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return true
end

local function NPC_MatchesTarget(model, npcName)
    if not npcName or npcName == "Any" then return IsValidNPC(model) end
    return IsValidNPC(model) and model.Name:lower():find(npcName:lower()) ~= nil
end

local function FindBestNPC(npcName, maxDistance)
    local root = GetRoot()
    if not root then return nil end

    maxDistance = maxDistance or 600
    local best, bestDist = nil, math.huge

    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") and NPC_MatchesTarget(model, npcName) then
            local r = model:FindFirstChild("HumanoidRootPart")
            if r then
                local dist = (root.Position - r.Position).Magnitude
                if dist < bestDist and dist < maxDistance then
                    bestDist = dist
                    best = model
                end
            end
        end
    end

    return best
end

SelectNextTarget = function(npcName)
    local npc = FindBestNPC(npcName)
    if npc then
        FarmManager.CurrentTarget = npc
        FarmManager.Target = npc.Name
        DebugLog("Target", "Novo alvo: " .. npc.Name)
        return npc
    end
    FarmManager.CurrentTarget = nil
    FarmManager.Target = "None"
    return nil
end

-- ==================== SISTEMA DE QUEST ====================
local function FindQuestGiver(npcName)
    local myRoot = GetRoot()
    local best, bestDist = nil, math.huge
    local wanted = tostring(npcName or ""):lower()
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") then
            local n = model.Name:lower()
            local isCandidate = n:find("quest") or n:find("questgiver")
            if not isCandidate and wanted ~= "" then
                isCandidate = n:find(wanted, 1, true) ~= nil
            end
            local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model.PrimaryPart
            if isCandidate and root then
                local dist = myRoot and (myRoot.Position - root.Position).Magnitude or 0
                if dist < bestDist then
                    best, bestDist = model, dist
                end
            end
        end
    end
    return best
end

local function HasActiveQuest()
    local ok, result = pcall(function()
        -- Verifica via RemoteFunction ou GUI
        local gui = player:FindFirstChild("PlayerGui")
        if gui then
            local qFrame = gui:FindFirstChild("QuestFrame", true)
            if qFrame and qFrame.Visible then return true end
        end
        -- Via atributo do jogador
        local hasQuest = player:GetAttribute("HasQuest") or player:GetAttribute("QuestActive")
        return hasQuest == true
    end)
    return ok and result or false
end

local function AcceptQuest(questGiver)
    if not questGiver or not GetRoot() then return false end
    local qRoot = questGiver:FindFirstChild("HumanoidRootPart") or questGiver:FindFirstChild("Head") or questGiver.PrimaryPart
    if not qRoot then return false end

    local myRoot = GetRoot()
    myRoot.CFrame = CFrame.new(qRoot.Position + Vector3.new(0, 2, 4))
    task.wait(0.25)

    local interacted = false
    for _, obj in ipairs(questGiver:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            pcall(function() fireproximityprompt(obj) end)
            interacted = true
            break
        elseif obj:IsA("ClickDetector") then
            pcall(function() fireclickdetector(obj) end)
            interacted = true
            break
        end
    end

    if not interacted then
        pcall(function()
            local re = ReplicatedStorage:FindFirstChild("Remotes", true)
                or ReplicatedStorage:FindFirstChild("Events", true)
            if re then
                local acceptEv = re:FindFirstChild("QuestAccept")
                    or re:FindFirstChild("AcceptQuest")
                    or re:FindFirstChild("Quest")
                if acceptEv and acceptEv:IsA("RemoteEvent") then
                    acceptEv:FireServer(questGiver)
                    interacted = true
                elseif acceptEv and acceptEv:IsA("RemoteFunction") then
                    acceptEv:InvokeServer(questGiver)
                    interacted = true
                end
            end
        end)
    end

    task.wait(0.35)
    local active = HasActiveQuest()
    DebugLog("Quest", ("Interação=%s | Ativa=%s"):format(tostring(interacted), tostring(active)))
    return active or interacted
end

local function IsQuestComplete()
    if FarmManager.KillRequired <= 0 then return false end
    return FarmManager.KillCount >= FarmManager.KillRequired
end

-- ==================== POSICIONAMENTO ACIMA DO NPC ====================
local function GetPositionRelativeToNPC(npcRoot)
    local base = npcRoot.Position
    local h = Configs.FarmHeight or 8

    if NormalizeFarmPosition(Configs.FarmPosition) == "Above" then
        return CFrame.new(base + Vector3.new(0, h, 0))
    elseif NormalizeFarmPosition(Configs.FarmPosition) == "Behind" then
        local cf = npcRoot.CFrame
        return CFrame.new(base + cf.LookVector * -3 + Vector3.new(0, 2, 0))
    elseif NormalizeFarmPosition(Configs.FarmPosition) == "Front" then
        local cf = npcRoot.CFrame
        return CFrame.new(base + cf.LookVector * 3 + Vector3.new(0, 2, 0))
    else -- Near
        return CFrame.new(base + Vector3.new(2, 2, 2))
    end
end

local function MaintainPositionAboveNPC()
    local target = FarmManager.CurrentTarget
    if not target or not target.Parent then return false end

    local npcRoot = target:FindFirstChild("HumanoidRootPart")
    if not npcRoot then return false end

    local myRoot = GetRoot()
    if not myRoot then return false end

    local targetCF = GetPositionRelativeToNPC(npcRoot)
    local dist = (myRoot.Position - targetCF.Position).Magnitude

    if dist > 4 then
        pcall(function()
            myRoot.CFrame = targetCF
        end)
    end
    return true
end

TravelToPosition = function(targetCFrame, label)
    local root = GetRoot()
    if not root then return false end

    FarmManager.State = FM_STATES.TRAVEL
    if label then FarmManager.Task = "Traveling to " .. label end
    if UpdateFarmStatus then UpdateFarmStatus() end

    local ok = pcall(function()
        root.CFrame = targetCFrame
    end)
    task.wait(0.4)
    return ok
end

-- ==================== FIGHTING STYLE ====================
EquipFightingStyle = function()
    if Configs.FightingStyle == "Current" then return true end

    local ok = pcall(function()
        local char = GetCharacter()
        if not char then return end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end

        -- Procura a tool do estilo na backpack
        local bp = player:FindFirstChildOfClass("Backpack")
        if not bp then return end

        local styleName = Configs.FightingStyle:lower()
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find(styleName) then
                hum:EquipTool(tool)
                task.wait(0.2)
                break
            end
        end
    end)
    return ok
end

-- ==================== KILL AURA / COMBATE ====================
local function ExecuteKillAura()
    if not Configs.KillAura then return end

    local target = FarmManager.CurrentTarget
    if not target or not target.Parent then return end

    local char = GetCharacter()
    if not char then return end

    local myRoot = GetRoot()
    if not myRoot then return end

    local npcHum = target:FindFirstChildOfClass("Humanoid")
    local npcRoot = target:FindFirstChild("HumanoidRootPart")
    if not npcHum or npcHum.Health <= 0 or not npcRoot then
        FarmManager.CurrentTarget = nil
        return
    end

    -- Encontra ferramenta/arma equipada
    pcall(function()
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("BasePart")
                if handle then
                    -- Usa firetouchinterest para Hit
                    firetouchinterest(npcRoot, handle, 0)
                    firetouchinterest(npcRoot, handle, 1)
                end

                -- Tenta Activate também
                pcall(function() tool:Activate() end)
                break
            end
        end
    end)
end

-- ==================== DISTRIBUIÇÃO DE STATS ====================
local function DistributeStats()
    if not Configs.AutoStats then return end
    local pts = GetStatPoints()
    if pts <= 0 then return end

    local priority = {Configs.StatPrimary, Configs.StatSecondary, Configs.StatTertiary}
    local statMap = {
        BloxFruit = "Fruit",
        Defense   = "Defense",
        Melee     = "Melee",
        Sword     = "Sword",
        Gun       = "Gun",
    }

    pcall(function()
        local re = ReplicatedStorage:FindFirstChild("Remotes", true)
        if not re then return end

        local statEv = re:FindFirstChild("StatUpdate")
            or re:FindFirstChild("AddStat")
            or re:FindFirstChild("DistributeStat")

        if not statEv then return end

        for i = 1, pts do
            local statKey = priority[(i - 1) % #priority + 1]
            local mapped = statMap[statKey] or statKey
            if statEv:IsA("RemoteEvent") then
                statEv:FireServer(mapped)
            elseif statEv:IsA("RemoteFunction") then
                statEv:InvokeServer(mapped)
            end
            task.wait(0.1)
        end
    end)
end

-- ==================== BOSS FARM ====================
local function FindBoss(bossName)
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") then
            local n = model.Name
            if bossName == "Any" or n:lower():find(bossName:lower()) then
                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and hum.MaxHealth >= 1000 then -- Boss tem muito HP
                    return model
                end
            end
        end
    end
    return nil
end

-- ==================== FRUIT DETECTION ====================
local fruitNotificationCooldown = {}
local function ScanFruits()
    if not Configs.DetectFruit then return end

    for _, obj in ipairs(workspace:GetDescendants()) do
        local n = obj.Name:lower()
        if (n:find("fruit") or n:find("devil") or n:find("blox"))
            and obj:IsA("BasePart") and obj.Transparency < 0.5 then

            local filter = tostring(Configs.FruitFilter or "Any")
            local matches = filter == "Any"
                or obj.Name:lower():find(filter:lower(), 1, true) ~= nil

            if matches and not fruitNotificationCooldown[obj] then
                fruitNotificationCooldown[obj] = true

                if Configs.FruitNotification then
                    -- Notificação via callback da UI
                    if _G.AkatCallbacks and _G.AkatCallbacks.Notify then
                        pcall(function()
                            _G.AkatCallbacks.Notify("FRUIT DETECTED", obj.Name .. " found nearby!")
                        end)
                    end
                end

                task.delay(30, function()
                    fruitNotificationCooldown[obj] = nil
                end)
            end
        end
    end
end

-- ==================== SEA EVENTS ====================
local function ScanSeaEvents()
    if not Configs.AutoSeaEvent then return end
    -- Detecção de eventos via nomes de modelos comuns em BF
    local eventKeywords = {"Raid", "Kitsune", "Ship", "Tide", "Storm", "Event"}
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") then
            for _, kw in ipairs(eventKeywords) do
                if model.Name:lower():find(kw:lower()) then
                    if Configs.SeaEventName == "Any" or model.Name:lower():find(Configs.SeaEventName:lower()) then
                        FarmManager.Task = "Sea Event: " .. model.Name
                        if UpdateFarmStatus then UpdateFarmStatus() end
                    end
                end
            end
        end
    end
end

-- ==================== ERROR RECOVERY ====================
local function HandleError(reason)
    FarmManager.State = FM_STATES.ERROR_RECOVERY
    FarmManager.LastError = reason
    FarmManager.CurrentTarget = nil
    if UpdateFarmStatus then UpdateFarmStatus() end
    DebugLog("Error", "Recovery: " .. reason)
    task.wait(1.5)
end

-- ==================== STOP SYSTEM ====================
StopFarm = function()
    FarmManager.Generation += 1
    FarmManager.State = FM_STATES.STOPPED
    FarmManager.CurrentTarget = nil
    FarmManager.LoopRunning = false

    local char = GetCharacter()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if hum then
        hum.WalkSpeed    = 16
        hum.UseJumpPower = true
        hum.JumpPower    = 50
    end
    if root then
        root.Anchored = false
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    if UpdateFarmStatus then UpdateFarmStatus() end
    DebugLog("Farm", "Farm parado. Controle devolvido ao jogador.")
end

-- ==================== FARM MANAGER: MÁQUINA DE ESTADOS ====================
local function FarmLoop(generation)
    while scriptAlive and IsAnyFarmModeEnabled() and FarmManager.Generation == generation do
        local state = FarmManager.State

        -- ===== IDLE / INIT =====
        if state == FM_STATES.IDLE or state == FM_STATES.STOPPED then
            FarmManager.State = FM_STATES.INIT
            if UpdateFarmStatus then UpdateFarmStatus() end
            task.wait(0.3)

        -- ===== INIT =====
        elseif state == FM_STATES.INIT then
            FarmManager.State = FM_STATES.CHECK_CHAR
            if UpdateFarmStatus then UpdateFarmStatus() end
            task.wait(0.2)

        -- ===== CHECK CHARACTER =====
        elseif state == FM_STATES.CHECK_CHAR then
            if not GetCharacter() or not IsAlive() then
                -- Aguarda respawn
                FarmManager.Task = "Waiting respawn..."
                if UpdateFarmStatus then UpdateFarmStatus() end
                task.wait(2)
            else
                FarmManager.State = FM_STATES.CHECK_LEVEL
            end

        -- ===== CHECK LEVEL =====
        elseif state == FM_STATES.CHECK_LEVEL then
            local lv  = GetLevel()
            local sea = GetSea()
            FarmManager.Level = lv
            FarmManager.Sea   = sea

            local areaData = GetAreaData(lv)
            if areaData then
                FarmManager.Area         = areaData.area
                FarmManager.KillRequired = areaData.killReq
            else
                FarmManager.Area = "Unknown"
                FarmManager.KillRequired = 10
            end

            -- Detecta modo atual
            if Configs.AutoBoss then
                FarmManager.Mode  = "Boss"
                FarmManager.State = FM_STATES.BOSS_FARM
            elseif Configs.AutoMastery then
                FarmManager.Mode  = "Mastery"
                FarmManager.State = FM_STATES.MASTERY_FARM
            elseif Configs.AutoMaterial then
                FarmManager.Mode  = "Material"
                FarmManager.State = FM_STATES.MATERIAL_FARM
            else
                FarmManager.Mode  = "Level"
                FarmManager.State = FM_STATES.FIND_QUEST
            end

            EquipFightingStyle()
            if UpdateFarmStatus then UpdateFarmStatus() end
            task.wait(0.2)

        -- ===== FIND QUEST =====
        elseif state == FM_STATES.FIND_QUEST then
            if not Configs.AutoQuest or HasActiveQuest() then
                -- Já tem quest ativa ou não usa auto quest — vai direto ao target
                FarmManager.State = FM_STATES.FIND_TARGET
            else
                local lv = FarmManager.Level
                local areaData = GetAreaData(lv)
                if areaData then
                    FarmManager.Quest = areaData.quest
                    FarmManager.State = FM_STATES.GET_QUEST
                else
                    HandleError("No area data for level " .. lv)
                end
            end
            if UpdateFarmStatus then UpdateFarmStatus() end

        -- ===== GET QUEST =====
        elseif state == FM_STATES.GET_QUEST then
            FarmManager.KillCount = 0

            local lv = FarmManager.Level
            local areaData = GetAreaData(lv)
            if areaData then
                local qg = FindQuestGiver(areaData.npcName)
                if qg then
                    FarmManager.CurrentQuestGiver = qg
                    local root = qg:FindFirstChild("HumanoidRootPart") or qg.PrimaryPart
                    if root then
                        TravelToPosition(CFrame.new(root.Position + Vector3.new(0, 2, 4)), "Quest Giver")
                    end
                    AcceptQuest(qg)
                    task.wait(0.5)
                end
            end

            FarmManager.State = FM_STATES.FIND_TARGET
            if UpdateFarmStatus then UpdateFarmStatus() end

        -- ===== FIND TARGET =====
        elseif state == FM_STATES.FIND_TARGET then
            local lv = FarmManager.Level
            local areaData = GetAreaData(lv)
            local npcName = areaData and areaData.npcName or "Any"

            local npc = SelectNextTarget(npcName)
            if npc then
                FarmManager.State = FM_STATES.TRAVEL
            else
                -- Nenhum NPC encontrado — tenta mais longe
                task.wait(0.8)
                npc = SelectNextTarget(npcName)
                if not npc then
                    HandleError("No valid NPC found")
                    task.wait(1)
                end
            end
            if UpdateFarmStatus then UpdateFarmStatus() end

        -- ===== TRAVEL =====
        elseif state == FM_STATES.TRAVEL then
            local target = FarmManager.CurrentTarget
            if not IsValidNPC(target) then
                FarmManager.State = FM_STATES.FIND_TARGET
            else
                local npcRoot = target:FindFirstChild("HumanoidRootPart")
                if npcRoot then
                    local destCF = GetPositionRelativeToNPC(npcRoot)
                    TravelToPosition(destCF, target.Name)
                    FarmManager.State = FM_STATES.POSITION
                else
                    FarmManager.State = FM_STATES.FIND_TARGET
                end
            end
            if UpdateFarmStatus then UpdateFarmStatus() end

        -- ===== POSITION =====
        elseif state == FM_STATES.POSITION then
            if not IsValidNPC(FarmManager.CurrentTarget) then
                FarmManager.State = FM_STATES.FIND_TARGET
            else
                MaintainPositionAboveNPC()
                FarmManager.State = FM_STATES.FARMING
            end
            if UpdateFarmStatus then UpdateFarmStatus() end

        -- ===== FARMING =====
        elseif state == FM_STATES.FARMING then
            local target = FarmManager.CurrentTarget

            if not IsValidNPC(target) then
                -- Alvo morreu
                FarmManager.KillCount += 1
                FarmManager.Progress = math.floor(
                    (FarmManager.KillCount / math.max(1, FarmManager.KillRequired)) * 100
                )
                FarmManager.State = FM_STATES.TARGET_DEAD
            else
                -- Mantém posição e combate
                MaintainPositionAboveNPC()
                ExecuteKillAura()

                -- Verifica mudança de level
                local newLv = GetLevel()
                if newLv ~= FarmManager.Level then
                    FarmManager.Level = newLv
                    local newSea = GetSea()
                    if newSea ~= FarmManager.Sea then
                        FarmManager.State = FM_STATES.CHANGE_AREA
                    else
                        local newArea = GetAreaData(newLv)
                        if newArea and newArea.area ~= FarmManager.Area then
                            FarmManager.State = FM_STATES.CHANGE_AREA
                        end
                    end
                end

                -- Distribui stats se disponíveis
                DistributeStats()
            end

            if UpdateFarmStatus then UpdateFarmStatus() end
            task.wait(0.08)

        -- ===== TARGET DEAD =====
        elseif state == FM_STATES.TARGET_DEAD then
            FarmManager.CurrentTarget = nil
            FarmManager.Target = "None"

            if IsQuestComplete() then
                FarmManager.State = FM_STATES.QUEST_COMPLETE
            else
                FarmManager.State = FM_STATES.FIND_TARGET
            end
            if UpdateFarmStatus then UpdateFarmStatus() end

        -- ===== QUEST COMPLETE =====
        elseif state == FM_STATES.QUEST_COMPLETE then
            FarmManager.Task = "Quest Complete!"
            if UpdateFarmStatus then UpdateFarmStatus() end

            -- Retorna ao quest giver e pega próxima quest
            if Configs.AutoQuest and FarmManager.CurrentQuestGiver then
                local qg = FarmManager.CurrentQuestGiver
                local root = qg:FindFirstChild("HumanoidRootPart") or qg.PrimaryPart
                if root and root.Parent then
                    TravelToPosition(CFrame.new(root.Position + Vector3.new(0, 2, 4)), "Quest Giver")
                    task.wait(0.5)
                    AcceptQuest(qg)
                    task.wait(0.5)
                end
            end

            FarmManager.KillCount = 0
            FarmManager.Progress  = 0
            FarmManager.State = FM_STATES.FIND_QUEST
            if UpdateFarmStatus then UpdateFarmStatus() end

        -- ===== CHANGE AREA =====
        elseif state == FM_STATES.CHANGE_AREA then
            FarmManager.CurrentTarget = nil
            FarmManager.KillCount     = 0
            FarmManager.Progress      = 0
            FarmManager.Task          = "Area Changed — Updating route..."
            if UpdateFarmStatus then UpdateFarmStatus() end
            task.wait(0.5)
            FarmManager.State = FM_STATES.CHECK_LEVEL

        -- ===== MASTERY FARM =====
        elseif state == FM_STATES.MASTERY_FARM then
            local masteryType = NormalizeMasteryType(Configs.MasteryType)
            local current = GetMastery(masteryType)
            FarmManager.Task = ("Mastery %s: %d / %d"):format(
                masteryType, current, Configs.MasteryTarget
            )
            FarmManager.Progress = math.floor((current / math.max(1, Configs.MasteryTarget)) * 100)

            if current >= Configs.MasteryTarget then
                FarmManager.Task  = "Mastery Complete!"
                Configs.AutoMastery = false
                FarmManager.State = FM_STATES.COMPLETED
            else
                -- Farm normalmente mas monitora mastery
                local lv = GetLevel()
                local areaData = GetAreaData(lv)
                local npcName = areaData and areaData.npcName or "Any"

                local target = FarmManager.CurrentTarget
                if not IsValidNPC(target) then
                    target = SelectNextTarget(npcName)
                end

                if target then
                    MaintainPositionAboveNPC()
                    ExecuteKillAura()
                else
                    task.wait(0.5)
                end
            end

            if UpdateFarmStatus then UpdateFarmStatus() end
            task.wait(0.10)

        -- ===== BOSS FARM =====
        elseif state == FM_STATES.BOSS_FARM then
            local bossName = NormalizeBossName(Configs.BossName or "Any")
            if Configs.BossMode == "Available" then bossName = "Any" end
            local boss = FindBoss(bossName)

            if boss then
                FarmManager.CurrentTarget = boss
                FarmManager.Target = boss.Name
                FarmManager.Task   = "Boss: " .. boss.Name

                local bossHum = boss:FindFirstChildOfClass("Humanoid")
                if bossHum then
                    FarmManager.Progress = math.floor(
                        ((bossHum.MaxHealth - bossHum.Health) / math.max(1, bossHum.MaxHealth)) * 100
                    )
                end

                MaintainPositionAboveNPC()
                ExecuteKillAura()

                if not IsValidNPC(boss) then
                    FarmManager.Task = "Boss Defeated!"
                    FarmManager.CurrentTarget = nil
                    if UpdateFarmStatus then UpdateFarmStatus() end
                    task.wait(2)
                end
            else
                FarmManager.Task = "Searching for boss: " .. bossName
                task.wait(1)
            end

            if UpdateFarmStatus then UpdateFarmStatus() end
            task.wait(0.10)

        -- ===== MATERIAL FARM =====
        elseif state == FM_STATES.MATERIAL_FARM then
            local current = GetMaterialCount(Configs.MaterialName)
            FarmManager.Task = ("Material %s: %d / %d"):format(
                Configs.MaterialName, current, Configs.MaterialAmount
            )
            FarmManager.Progress = math.floor((current / math.max(1, Configs.MaterialAmount)) * 100)

            if current >= Configs.MaterialAmount then
                FarmManager.Task = "Material Goal Reached!"
                Configs.AutoMaterial = false
                FarmManager.State = FM_STATES.COMPLETED
            else
                -- Farm normalmente
                local lv = GetLevel()
                local areaData = GetAreaData(lv)
                local npcName = areaData and areaData.npcName or "Any"

                local target = FarmManager.CurrentTarget
                if not IsValidNPC(target) then
                    target = SelectNextTarget(npcName)
                end

                if target then
                    MaintainPositionAboveNPC()
                    ExecuteKillAura()
                else
                    task.wait(0.5)
                end
            end

            if UpdateFarmStatus then UpdateFarmStatus() end
            task.wait(0.10)

        -- ===== ERROR RECOVERY =====
        elseif state == FM_STATES.ERROR_RECOVERY then
            FarmManager.Task = "Recovering: " .. FarmManager.LastError
            if UpdateFarmStatus then UpdateFarmStatus() end
            task.wait(2)
            if IsAlive() then
                FarmManager.State = FM_STATES.CHECK_LEVEL
            end

        -- ===== COMPLETED =====
        elseif state == FM_STATES.COMPLETED then
            if UpdateFarmStatus then UpdateFarmStatus() end
            if IsAnyFarmModeEnabled() then
                FarmManager.State = FM_STATES.CHECK_LEVEL
                FarmManager.Progress = 0
                task.wait(0.15)
            else
                FarmManager.LoopRunning = false
                break
            end

        else
            task.wait(0.2)
        end

        task.wait(0)  -- yield para não travar o scheduler
    end

    -- Saiu do loop: só restaura movimento se nenhum modo de farm continuar ativo.
    if FarmManager.Generation == generation and not IsAnyFarmModeEnabled() then
        StopFarm()
    end
end

-- ==================== CALLBACKS EXPOSTOS ====================
UpdateFarmStatus = function()
    _G.AkatFarmStatus = {
        State = FarmManager.State,
        Mode = FarmManager.Mode,
        CurrentTask = FarmManager.Task,
        CurrentTarget = FarmManager.Target,
        CurrentQuest = FarmManager.Quest,
        CurrentArea = FarmManager.Area,
        Level = FarmManager.Level,
        Sea = FarmManager.Sea,
        Progress = FarmManager.Progress,
        Kills = FarmManager.KillCount,
        Required = FarmManager.KillRequired,
    }
    if _G.AkatCallbacks and _G.AkatCallbacks.UpdateStatus then
        pcall(function()
            _G.AkatCallbacks.UpdateStatus({
                state    = FarmManager.State,
                mode     = FarmManager.Mode,
                task     = FarmManager.Task,
                quest    = FarmManager.Quest,
                target   = FarmManager.Target,
                area     = FarmManager.Area,
                level    = FarmManager.Level,
                progress = FarmManager.Progress,
            })
        end)
    end
end

-- ==================== SHUTDOWN COMPLETO ====================
local function LimparEDesligarAbsolutamente()
    scriptAlive = false
    StopFarm()

    for k, v in pairs(Configs) do
        if type(v) == "boolean" then Configs[k] = false end
    end

    pcall(function()
        local char = GetCharacter()
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if root then
            root.Anchored = false
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if hum then
            hum.WalkSpeed    = 16
            hum.UseJumpPower = true
            hum.JumpPower    = 50
        end
    end)

    _G.AkatBFLogicRunning = false
    DebugLog("System", "Script encerrado com sucesso.")
end

-- ==================== NOCLIP SEGURO (Stepped) ====================
local steppedConnection = RunService.Stepped:Connect(function()
    if not scriptAlive then return end
    if Configs.AutoFarm or Configs.AutoBoss or Configs.AutoMastery or Configs.AutoMaterial then
        local char = GetCharacter()
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)

-- ==================== LOOP PRINCIPAL (Heartbeat) ====================
local hbConnection = RunService.Heartbeat:Connect(function()
    if not scriptAlive then return end

    local char = GetCharacter()
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    if IsAnyFarmModeEnabled() then
        root.Anchored = false
        if hum.WalkSpeed ~= 0 then hum.WalkSpeed = 0 end
        hum.UseJumpPower = true
        if hum.JumpPower ~= 0 then hum.JumpPower = 0 end
    else
        hum.WalkSpeed = math.clamp(tonumber(Configs.SpeedValue) or 16, 1, 100)
        hum.UseJumpPower = true
        hum.JumpPower = math.clamp(tonumber(Configs.JumpPowerValue) or 50, 0, 150)
    end

    if Configs.AntiFling then
        root.AssemblyAngularVelocity = Vector3.zero
        if root.AssemblyLinearVelocity.Magnitude > 80 then
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
end)

-- ==================== THREAD: SCANNER DE FRUTAS E EVENTOS ====================
task.spawn(function()
    while scriptAlive do
        task.wait(2)
        pcall(ScanFruits)
        pcall(ScanSeaEvents)
    end
end)

-- ==================== THREAD: RESPAWN WATCHER ====================
local characterConnection = player.CharacterAdded:Connect(function()
    if IsAnyFarmModeEnabled() then
        FarmManager.CurrentTarget = nil
        FarmManager.State = FM_STATES.CHECK_CHAR
        task.wait(1.5) -- espera carregar
        if IsAnyFarmModeEnabled() and IsAlive() then
            FarmManager.State = FM_STATES.INIT
        end
    end
end)

-- ==================== REGISTRO DE CALLBACKS ====================
_G.AkatCallbacks = _G.AkatCallbacks or {}

local function EnsureFarmLoop()
    if not IsAnyFarmModeEnabled() then
        StopFarm()
        return
    end
    if not FarmManager.LoopRunning then
        FarmManager.LoopRunning = true
        FarmManager.Generation += 1
        FarmManager.State = FM_STATES.IDLE
        local gen = FarmManager.Generation
        task.spawn(function()
            local ok, err = pcall(FarmLoop, gen)
            if not ok then
                FarmManager.LoopRunning = false
                FarmManager.LastError = tostring(err)
                FarmManager.State = FM_STATES.ERROR_RECOVERY
                DebugLog("Farm", "Loop error: " .. tostring(err))
            end
        end)
    else
        FarmManager.State = FM_STATES.CHECK_LEVEL
        if UpdateFarmStatus then UpdateFarmStatus() end
    end
end

local function SetFarmModeState()
    if IsAnyFarmModeEnabled() then
        EnsureFarmLoop()
    elseif FarmManager.LoopRunning then
        StopFarm()
    end
end

_G.AkatCallbacks.AutoFarm = function(enabled)
    Configs.AutoFarm = enabled == true
    SetFarmModeState()
end

_G.AkatCallbacks.AutoQuest = function(enabled)
    Configs.AutoQuest = enabled and true or false
end

_G.AkatCallbacks.AutoLevel = function(enabled)
    Configs.AutoLevel = enabled and true or false
end

_G.AkatCallbacks.KillAura = function(enabled)
    Configs.KillAura = enabled and true or false
end

_G.AkatCallbacks.FightingStyle = function(value)
    Configs.FightingStyle = tostring(value) == "Fighting Style" and "FightingStyle" or tostring(value)
    EquipFightingStyle()
end

_G.AkatCallbacks.FarmPosition = function(value)
    Configs.FarmPosition = NormalizeFarmPosition(value)
end

_G.AkatCallbacks.FarmHeight = function(value)
    Configs.FarmHeight = math.clamp(tonumber(value) or 8, 1, 30)
end

_G.AkatCallbacks.AutoMastery = function(enabled)
    Configs.AutoMastery = enabled == true
    SetFarmModeState()
end

_G.AkatCallbacks.MasteryType = function(value)
    Configs.MasteryType = NormalizeMasteryType(value)
end

_G.AkatCallbacks.MasteryTarget = function(value)
    Configs.MasteryTarget = math.max(1, tonumber(value) or 300)
end

_G.AkatCallbacks.AutoBoss = function(enabled)
    Configs.AutoBoss = enabled == true
    SetFarmModeState()
end

_G.AkatCallbacks.BossName = function(value)
    Configs.BossName = NormalizeBossName(value)
end

_G.AkatCallbacks.BossMode = function(value)
    Configs.BossMode = NormalizeBossMode(value)
end

_G.AkatCallbacks.BossQuest = function(enabled)
    Configs.BossQuest = enabled and true or false
end

_G.AkatCallbacks.AutoMaterial = function(enabled)
    Configs.AutoMaterial = enabled == true
    SetFarmModeState()
end

_G.AkatCallbacks.MaterialName = function(value)
    Configs.MaterialName = NormalizeMaterial(value)
end

_G.AkatCallbacks.MaterialAmount = function(value)
    Configs.MaterialAmount = math.max(1, tonumber(value) or 50)
end

_G.AkatCallbacks.DetectFruit = function(enabled)
    Configs.DetectFruit = enabled and true or false
end

_G.AkatCallbacks.FruitNotification = function(enabled)
    Configs.FruitNotification = enabled and true or false
end

_G.AkatCallbacks.FruitFilter = function(value)
    local v = tostring(value)
    Configs.FruitFilter = (v == "Selected Fruit") and tostring(Configs.SelectedFruit or "Any") or v
end

_G.AkatCallbacks.AutoSeaEvent = function(enabled)
    Configs.AutoSeaEvent = enabled and true or false
end

_G.AkatCallbacks.SeaEventName = function(value)
    Configs.SeaEventName = tostring(value)
end

_G.AkatCallbacks.AutoStats = function(enabled)
    Configs.AutoStats = enabled and true or false
end

_G.AkatCallbacks.StatPrimary = function(value)
    Configs.StatPrimary = NormalizeStat(value)
end

_G.AkatCallbacks.StatSecondary = function(value)
    Configs.StatSecondary = NormalizeStat(value)
end

_G.AkatCallbacks.StatTertiary = function(value)
    Configs.StatTertiary = NormalizeStat(value)
end

_G.AkatCallbacks.AutoServerSearch = function(enabled)
    Configs.AutoServerSearch = enabled and true or false
    if enabled then
        -- Rejoin via teleport de servidor
        task.spawn(function()
            pcall(function()
                local TeleportService = game:GetService("TeleportService")
                TeleportService:Teleport(game.PlaceId, player)
            end)
        end)
    end
end

_G.AkatCallbacks.Speed = function(value)
    Configs.SpeedValue = math.clamp(tonumber(value) or 16, 1, 100)
end

_G.AkatCallbacks.JumpPower = function(value)
    Configs.JumpPowerValue = math.clamp(tonumber(value) or 50, 0, 150)
end

_G.AkatCallbacks.AntiFling = function(enabled)
    Configs.AntiFling = enabled == true
end

_G.AkatCallbacks.ESP = function(enabled) Configs.ESP = enabled == true end
_G.AkatCallbacks.Name = function(enabled) Configs.Name = enabled == true end
_G.AkatCallbacks.Tracer = function(enabled) Configs.Tracer = enabled == true end
_G.AkatCallbacks.XRay = function(enabled) Configs.XRay = enabled == true end
_G.AkatCallbacks.ViewReach = function(enabled) Configs.ViewReach = enabled == true end

_G.AkatCallbacks.BossSelection = function(value)
    Configs.BossMode = NormalizeBossMode(value)
    if Configs.BossMode == "Available" then
        Configs.BossName = "Any"
    end
    if IsAnyFarmModeEnabled() then
        FarmManager.State = FM_STATES.CHECK_LEVEL
    end
end

_G.AkatCallbacks.MaterialSelection = function(value)
    Configs.MaterialName = NormalizeMaterial(value)
end

_G.AkatCallbacks.PrimaryStat = function(value) Configs.StatPrimary = NormalizeStat(value) end
_G.AkatCallbacks.SecondaryStat = function(value) Configs.StatSecondary = NormalizeStat(value) end
_G.AkatCallbacks.TertiaryStat = function(value) Configs.StatTertiary = NormalizeStat(value) end

_G.AkatCallbacks.EventSelection = function(value)
    local v = tostring(value)
    if v == "Any" then
        Configs.SeaEventName = "Any"
    elseif v == "Selected Event" and Configs.SeaEventName == "Any" then
        Configs.SeaEventName = "Any"
    end
end

_G.AkatCallbacks.SelectedEvent = function(value)
    Configs.SeaEventName = tostring(value)
end

_G.AkatCallbacks.SelectedFruit = function(value)
    Configs.FruitFilter = tostring(value)
end

_G.AkatCallbacks.Debug = function(enabled)
    Configs.Debug = enabled and true or false
end

_G.AkatCallbacks.GetFarmStatus = function()
    return {
        state    = FarmManager.State,
        mode     = FarmManager.Mode,
        task     = FarmManager.Task,
        quest    = FarmManager.Quest,
        target   = FarmManager.Target,
        area     = FarmManager.Area,
        level    = FarmManager.Level,
        sea      = FarmManager.Sea,
        progress = FarmManager.Progress,
        kills    = FarmManager.KillCount,
        required = FarmManager.KillRequired,
    }
end

_G.AkatCallbacks.ShutdownAll = function()
    LimparEDesligarAbsolutamente()
end

-- ==================== CONEXÃO COM A UI ====================
-- A UI usa _G.AkatCallbacks e _G.AkatFarmStatus.
-- Se a UI já estiver carregada, ela se conecta automaticamente.
_G.AkatBFLogicReady = true
_G.AkatBFGetConfig = function()
    return Configs
end

DebugLog("System", "Backend pronto. A UI pode conectar pelos callbacks globais.")

-- ==================== INICIALIZADOR DA UI EXTERNA ====================
task.spawn(function()
    local uiRawUrl = "https://raw.githubusercontent.com/estratosfera88-afk/Ui-do-teste/refs/heads/main/bf_ui.lua"

    local rawContent = nil
    local fetchOk, fetchErr = pcall(function()
        rawContent = game:HttpGet(uiRawUrl, true)
    end)

    if not fetchOk then
        warn("[AKAT BF LOGIC] HttpGet falhou: " .. tostring(fetchErr))
        return
    end
    if not rawContent or rawContent == "" then
        warn("[AKAT BF LOGIC] HttpGet retornou vazio. Verifique a URL.")
        return
    end

    local fn, compileErr = loadstring(rawContent)
    if not fn then
        warn("[AKAT BF LOGIC] loadstring falhou: " .. tostring(compileErr))
        return
    end

    local runOk, runErr = pcall(fn)
    if not runOk then
        warn("[AKAT BF LOGIC] Erro ao executar a UI: " .. tostring(runErr))
    end
end)
