-- [[
--     AKAT BLOX FRUITS MAIN LOGIC [v1.0 - FARM MANAGER]
--     Compatível com Delta Mobile & PC | Blox Fruits (2026)
--     BACKEND ONLY — sem código de interface visual
--
--     ARQUITETURA:
--     - FarmManager: orquestrador central (máquina de estados)
--     - Módulos: AutoQuest, AutoLevel, AutoMastery, AutoBoss, AutoMaterial
--     - Kill Aura / Combat integrado ao Farm Manager
--     - Posicionamento relativo ao NPC configurável
--     - Recuperação automática de erros
--     - Controle único do personagem (nunca duas rotinas simultâneas)
-- ]]

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

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

-- ==================== CONFIGURAÇÕES ====================
local Configs = {
    -- FARM
    AutoFarm          = false,
    AutoQuest         = false,
    AutoLevel         = false,
    KillAura          = false,
    FarmPosition      = "Above NPC",   -- "Above NPC" | "Behind NPC" | "Front of NPC" | "Near NPC"
    FarmHeight        = 8,             -- studs acima do NPC
    FightingStyle     = "Current",     -- "Current" | nome do estilo

    -- MASTERY
    AutoMastery       = false,
    MasteryType       = "Fighting Style", -- "Fighting Style" | "Sword" | "Gun" | "Blox Fruit"
    MasteryTarget     = 300,

    -- BOSS
    AutoBoss          = false,
    BossName          = "",
    BossQuest         = false,
    BossMode          = "Selected Boss", -- "Selected Boss" | "Available Boss" | "Boss Rotation"
    AutoServerSearch  = false,
    ServerReason      = "Boss",          -- "Boss" | "Event" | "Material" | "Fruit" | "Other"

    -- MATERIAL
    AutoMaterial      = false,
    MaterialName      = "",
    MaterialAmount    = 10,

    -- FRUIT
    DetectFruit       = false,
    FruitNotification = false,
    FruitFilter       = "Any",

    -- SEA EVENTS
    AutoSeaEvent      = false,
    SeaEventName      = "Any",

    -- STATS
    AutoStats         = false,
    StatPrimary       = "Blox Fruit",
    StatSecondary     = "Defense",
    StatTertiary      = "Melee",

    -- DEBUG
    Debug             = false,
}
_G.Configs = Configs

-- ==================== FARM MANAGER STATE ====================
local FarmState = {
    Status        = "Idle",
    CurrentMode   = "Level Farm",
    CurrentTask   = "",
    CurrentQuest  = "",
    CurrentTarget = "",
    CurrentArea   = "",
    Level         = 0,
    Sea           = 1,
    Progress      = 0,
    MaxProgress   = 1,
}
_G.FarmState = FarmState

-- Os estados possíveis do Farm Manager:
-- Idle | Initializing | CheckingCharacter | CheckingLevel
-- FindingQuest | GettingQuest | FindingTarget | Traveling
-- Positioning | Farming | TargetDead | QuestComplete
-- ChangingArea | MasteryFarming | BossFarming | MaterialFarming
-- ServerSearching | Completed | Stopped | ErrorRecovery

-- ==================== DEBUG ====================
local function DebugLog(sistema, msg)
    if Configs.Debug then
        warn(("[AKAT][%s] %s"):format(sistema, tostring(msg)))
    end
end

-- ==================== FORWARD DECLARATIONS ====================
local FarmManager_Stop
local FarmManager_SetState
local FarmManager_GetChar
local FarmManager_GetLevel
local FarmManager_GetSea
local FarmManager_GetQuestForLevel
local FarmManager_GetQuestNPCs
local FarmManager_GetQuestGiver
local FarmManager_AcceptQuest
local FarmManager_TurnInQuest
local FarmManager_IsQuestActive
local FarmManager_IsQuestComplete
local FarmManager_FindNPC
local FarmManager_MoveToPosition
local FarmManager_PositionAboveNPC
local FarmManager_EquipFightingStyle
local FarmManager_CombatAttack
local FarmManager_IsNPCAlive
local FarmManager_ResumeAfterError

-- ==================== CONEXÕES E ESTADO INTERNO ====================
local farmThread          = nil
local farmRunning         = false
local farmGeneration      = 0
local currentNPCTarget    = nil
local hbConnection        = nil
local steppedConnection   = nil
local characterConnection = nil
local globalPlayerAddedConn  = nil
local globalPlayerRemovingConn = nil

-- ==================== HELPERS GERAIS ====================
local function SafeWait(t)
    if not scriptAlive then return end
    task.wait(t)
end

local function IsAlive(char)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function GetCharAndRoot()
    local char = player.Character
    if not char then return nil, nil, nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    return char, root, hum
end

-- ==================== DETECÇÃO DE NÍVEL / SEA ====================
FarmManager_GetLevel = function()
    local level = 0
    pcall(function()
        -- Blox Fruits armazena o Level no leaderstats
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local lv = ls:FindFirstChild("Lv.")
                or ls:FindFirstChild("Level")
                or ls:FindFirstChild("level")
            if lv then level = tonumber(lv.Value) or 0 end
        end
    end)
    FarmState.Level = level
    return level
end

FarmManager_GetSea = function()
    local sea = 1
    pcall(function()
        -- Detecta o mar pela localização ou atributo de jogo
        local seaAttr = player:GetAttribute("Sea")
            or player:GetAttribute("CurrentSea")
            or player:GetAttribute("Island")
        if seaAttr then
            sea = tonumber(seaAttr) or 1
        else
            -- Fallback: usa o Level para inferir o sea
            local lv = FarmState.Level
            if lv >= 1500 then sea = 3
            elseif lv >= 700 then sea = 2
            else sea = 1 end
        end
    end)
    FarmState.Sea = sea
    return sea
end

-- ==================== TABELA DE PROGRESSÃO ====================
-- Mapeamento Level → {área, QuestGiver, NPCs, questKills}
-- Ajuste os nomes conforme o seu servidor/versão do jogo.
local LEVEL_DATA = {
    -- ===== PRIMEIRO MAR =====
    { minLv=1,   maxLv=15,  area="Starter Island",       giver="Military Soldier",  npcs={"Bandit"},              kills=8  },
    { minLv=15,  maxLv=30,  area="Jungle",               giver="Military Soldier",  npcs={"Gorilla"},             kills=8  },
    { minLv=30,  maxLv=60,  area="Pirate Village",        giver="Pirate Millionaire",npcs={"Pirate"},              kills=8  },
    { minLv=60,  maxLv=90,  area="Desert",               giver="Desert Bandit",     npcs={"Desert Bandit"},       kills=8  },
    { minLv=90,  maxLv=120, area="Frozen Village",        giver="Snow Bandit",       npcs={"Snow Bandit"},         kills=8  },
    { minLv=120, maxLv=150, area="Marine Fortress",       giver="Marine Sergeant",   npcs={"Marine"},              kills=8  },
    { minLv=150, maxLv=190, area="Skylands",             giver="Sky Bandit",        npcs={"Sky Bandit"},          kills=8  },
    { minLv=190, maxLv=250, area="Prison",               giver="Warden",            npcs={"Prisoner"},            kills=8  },
    { minLv=250, maxLv=300, area="Colosseum",            giver="Gladiator",         npcs={"Gladiator"},           kills=8  },
    { minLv=300, maxLv=375, area="Magma Village",        giver="Magma Ninja",       npcs={"Magma Ninja"},         kills=8  },
    { minLv=375, maxLv=450, area="Underwater City",      giver="Fishman Warrior",   npcs={"Fishman Warrior"},     kills=8  },
    { minLv=450, maxLv=550, area="Fountain City",        giver="Fishman Lord",      npcs={"Fishman Lord"},        kills=8  },
    { minLv=550, maxLv=650, area="Upper Skylands",       giver="Sky Pirate",        npcs={"Sky Pirate"},          kills=8  },
    { minLv=650, maxLv=700, area="Ice Castle",           giver="Ice Warrior",       npcs={"Ice Warrior"},         kills=8  },

    -- ===== SEGUNDO MAR =====
    { minLv=700,  maxLv=850,  area="Flower Island",      giver="Swan Pirate",       npcs={"Swan Pirate"},         kills=10 },
    { minLv=850,  maxLv=975,  area="Usopp Island",       giver="Fishman Raider",    npcs={"Fishman Raider"},      kills=10 },
    { minLv=975,  maxLv=1050, area="Thriller Bark",      giver="Rolling Zombie",    npcs={"Rolling Zombie"},      kills=10 },
    { minLv=1050, maxLv=1200, area="Gravestone",         giver="Ghost",             npcs={"Ghost"},               kills=10 },
    { minLv=1200, maxLv=1350, area="Snow Mountain",      giver="Snow Lurker",       npcs={"Snow Lurker"},         kills=10 },
    { minLv=1350, maxLv=1475, area="Hot and Cold",       giver="Magma Samurai",     npcs={"Magma Samurai"},       kills=10 },

    -- ===== TERCEIRO MAR =====
    { minLv=1500, maxLv=1575, area="Port Town",          giver="Pirate Millionaire",npcs={"Pirate"},              kills=12 },
    { minLv=1575, maxLv=1700, area="Hydra Island",       giver="Marine Avenger",    npcs={"Marine Avenger"},      kills=12 },
    { minLv=1700, maxLv=1850, area="Great Tree",         giver="Bro",               npcs={"Bro"},                 kills=12 },
    { minLv=1850, maxLv=2000, area="Floating Turtle",    giver="Longma",            npcs={"Longma"},              kills=12 },
    { minLv=2000, maxLv=2300, area="Elf Island",         giver="Dark Elf",          npcs={"Dark Elf"},            kills=12 },
    { minLv=2300, maxLv=9999, area="Sea of Treats",      giver="Cookie Crafter",    npcs={"Cookie Crafter"},      kills=12 },
}

local function GetLevelData(level)
    for _, data in ipairs(LEVEL_DATA) do
        if level >= data.minLv and level < data.maxLv then
            return data
        end
    end
    return LEVEL_DATA[#LEVEL_DATA]
end

-- ==================== FARM MANAGER STATE MACHINE ====================
FarmManager_SetState = function(state, detail)
    FarmState.Status = state
    if detail then FarmState.CurrentTask = detail end
    DebugLog("FarmManager", "Estado: " .. state .. (detail and (" | " .. detail) or ""))
end

-- ==================== LOCALIZAÇÃO DE OBJETOS NO MUNDO ====================
local function FindInWorkspace(namePatterns, maxDist, origin)
    local best, bestDist = nil, maxDist or math.huge
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") or d:IsA("BasePart") then
            for _, pat in ipairs(namePatterns) do
                if d.Name:lower():find(pat:lower()) then
                    local root = d:IsA("Model")
                        and (d:FindFirstChild("HumanoidRootPart") or d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart"))
                        or d
                    if root and origin then
                        local dist = (origin - root.Position).Magnitude
                        if dist < bestDist then
                            best = d
                            bestDist = dist
                        end
                    elseif root then
                        best = d
                        break
                    end
                end
            end
        end
    end
    return best
end

-- ==================== LOCALIZAÇÃO DE NPC ====================
FarmManager_FindNPC = function(npcNames, origin)
    local best, bestDist = nil, math.huge
    for _, npcName in ipairs(npcNames) do
        for _, model in ipairs(workspace:GetDescendants()) do
            if model:IsA("Model") then
                local nameLower = model.Name:lower()
                if nameLower:find(npcName:lower()) then
                    local npcRoot  = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                    local npcHum   = model:FindFirstChildOfClass("Humanoid")
                    -- Ignora NPCs mortos
                    if npcRoot and npcHum and npcHum.Health > 0 then
                        local dist = origin and (origin - npcRoot.Position).Magnitude or 0
                        if dist < bestDist then
                            best = model
                            bestDist = dist
                        end
                    end
                end
            end
        end
    end
    return best
end

FarmManager_IsNPCAlive = function(npcModel)
    if not npcModel or not npcModel.Parent then return false end
    local hum = npcModel:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

-- ==================== POSICIONAMENTO RELATIVO AO NPC ====================
FarmManager_PositionAboveNPC = function(npcModel, myRoot, height)
    if not npcModel or not myRoot then return end
    local npcRoot = npcModel:FindFirstChild("HumanoidRootPart") or npcModel.PrimaryPart
    if not npcRoot then return end
    local h = height or Configs.FarmHeight or 8
    local pos = npcRoot.Position

    local targetCFrame
    if Configs.FarmPosition == "Above NPC" then
        targetCFrame = CFrame.new(pos + Vector3.new(0, h, 0))
    elseif Configs.FarmPosition == "Behind NPC" then
        local look = npcRoot.CFrame.LookVector
        targetCFrame = CFrame.new(pos - look * 4 + Vector3.new(0, 2, 0))
    elseif Configs.FarmPosition == "Front of NPC" then
        local look = npcRoot.CFrame.LookVector
        targetCFrame = CFrame.new(pos + look * 4 + Vector3.new(0, 2, 0))
    else
        -- Near NPC
        targetCFrame = CFrame.new(pos + Vector3.new(2, 2, 2))
    end

    pcall(function()
        myRoot.CFrame = targetCFrame
    end)
end

-- ==================== TELEPORTE / MOVIMENTO ATÉ ALVO ====================
FarmManager_MoveToPosition = function(targetPos, myRoot, label)
    if not myRoot or not targetPos then return end
    FarmManager_SetState("Traveling", label or "Traveling")
    pcall(function()
        myRoot.CFrame = CFrame.new(targetPos + Vector3.new(0, 4, 0))
    end)
    SafeWait(0.15)
end

-- ==================== EQUIPAR FIGHTING STYLE ====================
FarmManager_EquipFightingStyle = function()
    if Configs.FightingStyle == "Current" then return true end
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end

    local styleName = Configs.FightingStyle:lower()

    -- Tenta encontrar o Fighting Style no Backpack
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find(styleName) then
                pcall(function() hum:EquipTool(item) end)
                SafeWait(0.1)
                return true
            end
        end
    end

    -- Já equipado no personagem?
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find(styleName) then
                return true
            end
        end
    end

    DebugLog("FightingStyle", "Estilo não encontrado: " .. Configs.FightingStyle .. " — usando atual.")
    return false
end

-- ==================== COMBATE / KILL AURA ====================
FarmManager_CombatAttack = function(npcModel)
    if not npcModel or not npcModel.Parent then return end
    local char = player.Character
    if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local npcRoot = npcModel:FindFirstChild("HumanoidRootPart") or npcModel.PrimaryPart
    if not npcRoot then return end

    -- Usa a ferramenta equipada (Fighting Style / Fruit / Sword / Gun)
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            pcall(function() tool:Activate() end)
        end
    end

    -- firetouchinterest nos hitboxes do NPC
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            pcall(function()
                firetouchinterest(npcRoot, part, 0)
                firetouchinterest(npcRoot, part, 1)
            end)
        end
    end
end

-- ==================== QUEST SYSTEM ====================
FarmManager_GetQuestForLevel = function(level)
    return GetLevelData(level or FarmState.Level)
end

FarmManager_IsQuestActive = function()
    local active = false
    pcall(function()
        -- Blox Fruits usa uma RemoteFunction ou atributo para checar quest ativa
        local questData = player:GetAttribute("CurrentQuest")
            or player:GetAttribute("Quest")
        active = questData ~= nil and questData ~= ""
    end)
    return active
end

FarmManager_IsQuestComplete = function(questData, killCount)
    if not questData then return false end
    return killCount >= (questData.kills or 8)
end

FarmManager_GetQuestGiver = function(giverName, myRoot)
    -- Procura o NPC Quest Giver pela área atual
    return FindInWorkspace({giverName, "quest", "giver"}, 3000, myRoot and myRoot.Position)
end

FarmManager_AcceptQuest = function(giverModel)
    if not giverModel then return false end
    local giverRoot = giverModel:FindFirstChild("HumanoidRootPart")
        or giverModel.PrimaryPart
    if not giverRoot then return false end

    -- Teleporta para perto do Quest Giver
    local _, myRoot = GetCharAndRoot()
    if myRoot then
        myRoot.CFrame = CFrame.new(giverRoot.Position + Vector3.new(0, 4, 2))
    end
    SafeWait(0.3)

    -- Tenta interagir via RemoteEvent padrão do Blox Fruits
    pcall(function()
        local re = ReplicatedStorage:FindFirstChild("Interactions", true)
            or workspace:FindFirstChild("QuestGiver", true)
        if re and re:IsA("RemoteEvent") then
            re:FireServer("accept", giverModel)
        end
    end)

    -- Alternativa: firetouchinterest no Quest Giver
    local char = player.Character
    if char then
        local myRootPart = char:FindFirstChild("HumanoidRootPart")
        if myRootPart then
            pcall(function()
                firetouchinterest(giverRoot, myRootPart, 0)
                firetouchinterest(giverRoot, myRootPart, 1)
            end)
        end
    end

    DebugLog("AutoQuest", "Quest aceita de: " .. giverModel.Name)
    return true
end

FarmManager_TurnInQuest = function(giverModel)
    if not giverModel then return false end
    local giverRoot = giverModel:FindFirstChild("HumanoidRootPart")
        or giverModel.PrimaryPart
    if not giverRoot then return false end

    local _, myRoot = GetCharAndRoot()
    if myRoot then
        myRoot.CFrame = CFrame.new(giverRoot.Position + Vector3.new(0, 4, 2))
    end
    SafeWait(0.3)

    pcall(function()
        local re = ReplicatedStorage:FindFirstChild("Interactions", true)
        if re and re:IsA("RemoteEvent") then
            re:FireServer("turnin", giverModel)
        end
    end)

    local char = player.Character
    if char then
        local myRootPart = char:FindFirstChild("HumanoidRootPart")
        if myRootPart then
            pcall(function()
                firetouchinterest(giverRoot, myRootPart, 0)
                firetouchinterest(giverRoot, myRootPart, 1)
            end)
        end
    end

    DebugLog("AutoQuest", "Quest entregue a: " .. giverModel.Name)
    return true
end

-- ==================== ERRO RECOVERY ====================
FarmManager_ResumeAfterError = function(errorType)
    FarmManager_SetState("ErrorRecovery", errorType)
    DebugLog("ErrorRecovery", "Recuperando de: " .. tostring(errorType))

    if errorType == "CharacterDead" or errorType == "CharacterRespawning" then
        -- Aguarda respawn
        local waited = 0
        while waited < 10 and scriptAlive do
            SafeWait(0.5)
            waited += 0.5
            local char, root, hum = GetCharAndRoot()
            if char and root and hum and hum.Health > 0 then
                SafeWait(1)
                return true
            end
        end
        return false

    elseif errorType == "TargetMissing" then
        currentNPCTarget = nil
        SafeWait(0.5)
        return true

    elseif errorType == "QuestMissing" or errorType == "QuestComplete" then
        SafeWait(0.3)
        return true

    elseif errorType == "CharacterStuck" or errorType == "TargetStuck" then
        local char, root = GetCharAndRoot()
        if root then
            root.CFrame = root.CFrame * CFrame.new(0, 5, 0)
        end
        SafeWait(0.5)
        return true

    elseif errorType == "LevelChanged" or errorType == "AreaChanged" then
        currentNPCTarget = nil
        SafeWait(0.3)
        return true
    end

    SafeWait(0.5)
    return true
end

-- ==================== THREAD PRINCIPAL: FARM MANAGER ====================
local function StartFarmManager()
    if farmRunning then return end
    farmRunning = true
    farmGeneration += 1
    local myGen = farmGeneration

    task.spawn(function()
        while scriptAlive and farmRunning and farmGeneration == myGen do
            -- ===== ESTADO: IDLE / VERIFICAÇÃO INICIAL =====
            if not Configs.AutoFarm then
                FarmManager_SetState("Idle")
                SafeWait(0.3)
                continue
            end

            FarmManager_SetState("Initializing")

            -- ===== CHECK CHARACTER =====
            FarmManager_SetState("CheckingCharacter")
            local char, root, hum = GetCharAndRoot()
            if not char or not root or not hum then
                SafeWait(0.5)
                continue
            end
            if hum.Health <= 0 then
                FarmManager_ResumeAfterError("CharacterDead")
                continue
            end

            -- ===== CHECK LEVEL =====
            FarmManager_SetState("CheckingLevel")
            local level = FarmManager_GetLevel()
            local sea   = FarmManager_GetSea()
            local questData = FarmManager_GetQuestForLevel(level)

            FarmState.CurrentArea  = questData.area
            FarmState.CurrentQuest = questData.giver .. " Quest"

            -- ===== AUTO LEVEL: verifica mudança de área =====
            if Configs.AutoLevel then
                local newData = FarmManager_GetQuestForLevel(level)
                if newData.area ~= FarmState.CurrentArea then
                    FarmManager_SetState("ChangingArea", newData.area)
                    FarmState.CurrentArea = newData.area
                    currentNPCTarget = nil
                    SafeWait(0.5)
                    continue
                end
            end

            -- ===== BOSS FARM MODE =====
            if Configs.AutoBoss and Configs.BossName ~= "" then
                FarmManager_SetState("BossFarming", Configs.BossName)
                char, root, hum = GetCharAndRoot()
                if not char or not root or hum.Health <= 0 then
                    FarmManager_ResumeAfterError("CharacterDead")
                    continue
                end

                local bossModel = FindInWorkspace({Configs.BossName}, 5000, root.Position)
                if not bossModel then
                    FarmManager_SetState("FindingTarget", Configs.BossName)
                    SafeWait(2)
                    continue
                end

                local bossRoot = bossModel:FindFirstChild("HumanoidRootPart") or bossModel.PrimaryPart
                if bossRoot then
                    FarmManager_MoveToPosition(bossRoot.Position, root, "Moving to Boss")
                    char, root, hum = GetCharAndRoot()
                    if char and root then
                        FarmManager_PositionAboveNPC(bossModel, root, Configs.FarmHeight)
                        FarmManager_CombatAttack(bossModel)
                    end
                end

                SafeWait(0.15)
                continue
            end

            -- ===== MATERIAL FARM MODE =====
            if Configs.AutoMaterial and Configs.MaterialName ~= "" then
                FarmManager_SetState("MaterialFarming", Configs.MaterialName)

                -- Verifica inventário
                local currentAmount = 0
                pcall(function()
                    currentAmount = player:GetAttribute("Mat_" .. Configs.MaterialName) or 0
                end)

                if currentAmount >= Configs.MaterialAmount then
                    FarmManager_SetState("Completed", "Material " .. Configs.MaterialName)
                    Configs.AutoMaterial = false
                    SafeWait(0.5)
                    continue
                end

                -- Continua farm normal para drop de material
                FarmState.CurrentTask = "Material: " .. Configs.MaterialName
            end

            -- ===== MASTERY FARM MODE =====
            if Configs.AutoMastery then
                FarmManager_SetState("MasteryFarming", Configs.MasteryType)

                -- Verifica mastery atual
                local currentMastery = 0
                pcall(function()
                    currentMastery = player:GetAttribute("Mastery_" .. Configs.MasteryType) or 0
                end)

                if currentMastery >= Configs.MasteryTarget then
                    FarmManager_SetState("Completed", "Mastery atingida: " .. Configs.MasteryTarget)
                    Configs.AutoMastery = false
                    SafeWait(0.5)
                    continue
                end

                FarmState.CurrentTask = "Mastery: " .. currentMastery .. "/" .. Configs.MasteryTarget
            end

            -- ===== AUTO QUEST =====
            if Configs.AutoQuest then
                FarmManager_SetState("FindingQuest", questData.area)

                if not FarmManager_IsQuestActive() then
                    FarmManager_SetState("GettingQuest", questData.giver)
                    char, root, hum = GetCharAndRoot()
                    if not char or not root then
                        SafeWait(0.5)
                        continue
                    end

                    local giver = FarmManager_GetQuestGiver(questData.giver, root)
                    if giver then
                        local giverRoot = giver:FindFirstChild("HumanoidRootPart") or giver.PrimaryPart
                        if giverRoot then
                            FarmManager_MoveToPosition(giverRoot.Position, root, "Going to Quest Giver")
                        end
                        FarmManager_AcceptQuest(giver)
                        SafeWait(0.5)
                    else
                        DebugLog("AutoQuest", "Quest Giver não encontrado: " .. questData.giver)
                        FarmManager_ResumeAfterError("QuestMissing")
                        continue
                    end
                end
            end

            -- ===== EQUIPA FIGHTING STYLE =====
            FarmManager_EquipFightingStyle()

            -- ===== LOCALIZA NPC OBJETIVO =====
            FarmManager_SetState("FindingTarget", table.concat(questData.npcs, ", "))
            char, root, hum = GetCharAndRoot()
            if not char or not root or not hum or hum.Health <= 0 then
                FarmManager_ResumeAfterError("CharacterDead")
                continue
            end

            -- Valida se o NPC atual ainda está vivo
            if currentNPCTarget and not FarmManager_IsNPCAlive(currentNPCTarget) then
                FarmManager_SetState("TargetDead")
                currentNPCTarget = nil
                SafeWait(0.1)
            end

            if not currentNPCTarget then
                currentNPCTarget = FarmManager_FindNPC(questData.npcs, root.Position)
            end

            if not currentNPCTarget then
                DebugLog("Farm", "Nenhum NPC encontrado. Aguardando respawn...")
                FarmManager_ResumeAfterError("TargetMissing")
                continue
            end

            FarmState.CurrentTarget = currentNPCTarget.Name

            -- ===== POSICIONA ACIMA DO NPC =====
            FarmManager_SetState("Positioning", currentNPCTarget.Name)
            char, root, hum = GetCharAndRoot()
            if not char or not root then continue end

            FarmManager_PositionAboveNPC(currentNPCTarget, root, Configs.FarmHeight)

            -- ===== COMBATE =====
            FarmManager_SetState("Farming", currentNPCTarget.Name)

            if not FarmManager_IsNPCAlive(currentNPCTarget) then
                FarmManager_SetState("TargetDead")
                currentNPCTarget = nil
                SafeWait(0.1)
                continue
            end

            -- Kill Aura / Ataque
            if Configs.KillAura then
                FarmManager_CombatAttack(currentNPCTarget)
            end

            -- Atualiza progresso da Quest
            FarmState.Progress = FarmState.Progress + 0
            FarmState.MaxProgress = questData.kills

            SafeWait(0.12)
        end

        farmRunning = false
        FarmManager_SetState("Stopped")
    end)
end

FarmManager_Stop = function()
    farmRunning = false
    farmGeneration += 1
    currentNPCTarget = nil
    FarmManager_SetState("Stopped")

    -- Restaura controle ao jogador
    local char, root, hum = GetCharAndRoot()
    if root then
        root.Anchored = false
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    if hum then
        hum.WalkSpeed = 16
        hum.UseJumpPower = true
        hum.JumpPower = 50
    end
end

-- ==================== THREAD: KILL AURA CONTÍNUA ====================
-- Esta thread mantém o Kill Aura ativo separado do ciclo de farm principal,
-- para que o ataque seja contínuo enquanto o manager move/posiciona o personagem.
task.spawn(function()
    while scriptAlive do
        SafeWait(0.08)
        if not Configs.AutoFarm or not Configs.KillAura then continue end

        local char, root, hum = GetCharAndRoot()
        if not char or not root or not hum or hum.Health <= 0 then continue end

        local target = currentNPCTarget
        if not target or not target.Parent then continue end

        local npcHum = target:FindFirstChildOfClass("Humanoid")
        if not npcHum or npcHum.Health <= 0 then
            currentNPCTarget = nil
            continue
        end

        -- Mantém posição relativa ao NPC (acompanha movimento)
        FarmManager_PositionAboveNPC(target, root, Configs.FarmHeight)

        -- Ataca continuamente
        FarmManager_CombatAttack(target)
    end
end)

-- ==================== THREAD: DETECT FRUIT ====================
task.spawn(function()
    while scriptAlive do
        SafeWait(3)
        if not Configs.DetectFruit then continue end

        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Model") or d:IsA("BasePart") then
                local name = d.Name:lower()
                if name:find("fruit") or name:find("fruta") or name:find("devil") then
                    local filter = Configs.FruitFilter:lower()
                    local matches = filter == "any" or name:find(filter)
                    if matches then
                        DebugLog("FruitDetect", "Fruta detectada: " .. d.Name)
                        if Configs.FruitNotification and _G.AkatCallbacks and _G.AkatCallbacks.Notification then
                            _G.AkatCallbacks.Notification("FRUTA DETECTADA", d.Name)
                        end
                    end
                end
            end
        end
    end
end)

-- ==================== THREAD: AUTO STATS ====================
task.spawn(function()
    while scriptAlive do
        SafeWait(5)
        if not Configs.AutoStats then continue end

        pcall(function()
            -- Distribuição de pontos via RemoteEvent do jogo
            local priorities = {Configs.StatPrimary, Configs.StatSecondary, Configs.StatTertiary}
            for _, stat in ipairs(priorities) do
                local re = ReplicatedStorage:FindFirstChild("AddStat", true)
                if re and re:IsA("RemoteEvent") then
                    re:FireServer(stat)
                end
            end
        end)
    end
end)

-- ==================== THREAD: SEA EVENTS ====================
task.spawn(function()
    while scriptAlive do
        SafeWait(4)
        if not Configs.AutoSeaEvent then continue end

        local char, root, hum = GetCharAndRoot()
        if not char or not root or not hum or hum.Health <= 0 then continue end

        local eventName = Configs.SeaEventName
        if eventName == "Any" or eventName == "" then
            -- Tenta encontrar qualquer event ativo
            local eventModel = FindInWorkspace({"raid", "event", "sea event"}, 10000, root.Position)
            if eventModel then
                local evRoot = eventModel:FindFirstChild("HumanoidRootPart") or eventModel.PrimaryPart
                    or (eventModel:IsA("BasePart") and eventModel)
                if evRoot then
                    FarmManager_MoveToPosition(evRoot.Position, root, "Sea Event")
                end
            end
        else
            local eventModel = FindInWorkspace({eventName}, 10000, root.Position)
            if eventModel then
                local evRoot = eventModel:FindFirstChild("HumanoidRootPart") or eventModel.PrimaryPart
                    or (eventModel:IsA("BasePart") and eventModel)
                if evRoot then
                    FarmManager_MoveToPosition(evRoot.Position, root, eventName)
                end
            end
        end
    end
end)

-- ==================== THREAD: AUTO SERVER SEARCH ====================
task.spawn(function()
    while scriptAlive do
        SafeWait(5)
        if not Configs.AutoServerSearch then continue end

        -- Condições que exigem troca de servidor
        local needSwitch = false
        if Configs.ServerReason == "Boss" and Configs.AutoBoss then
            if Configs.BossName ~= "" then
                local _, root = GetCharAndRoot()
                if root then
                    local found = FindInWorkspace({Configs.BossName}, 5000, root.Position)
                    needSwitch = (found == nil)
                end
            end
        end

        if needSwitch then
            DebugLog("ServerSearch", "Procurando novo servidor para: " .. Configs.ServerReason)
            pcall(function()
                local tpService = game:GetService("TeleportService")
                local placeId   = game.PlaceId
                tpService:Teleport(placeId, player)
            end)
            SafeWait(5)
        end
    end
end)

-- ==================== NOCLIP (Stepped) ====================
steppedConnection = RunService.Stepped:Connect(function()
    if not scriptAlive then return end
    if Configs.AutoFarm then
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

    local char, root, hum = GetCharAndRoot()
    if not root or not hum then return end

    if Configs.AutoFarm then
        if hum.WalkSpeed ~= 0 then hum.WalkSpeed = 0 end
        if hum.JumpPower ~= 0 then hum.JumpPower = 0 end
        hum.UseJumpPower = true
        root.Anchored = false
    else
        root.Anchored = false
        hum.WalkSpeed = 16
        hum.UseJumpPower = true
        hum.JumpPower = 50
    end
end)

-- ==================== RESPAWN / RESET ====================
local function ResetFarmState()
    currentNPCTarget = nil
    FarmState.Progress = 0
    FarmState.CurrentTarget = ""
end

characterConnection = player.CharacterAdded:Connect(function()
    ResetFarmState()
    task.wait(1)
    if Configs.AutoFarm and scriptAlive then
        FarmManager_ResumeAfterError("CharacterRespawning")
    end
end)

-- ==================== SHUTDOWN COMPLETO ====================
local function LimparEDesligarAbsolutamente()
    scriptAlive  = false
    farmRunning  = false
    farmGeneration += 1
    currentNPCTarget = nil

    if hbConnection        then hbConnection:Disconnect();        hbConnection        = nil end
    if steppedConnection   then steppedConnection:Disconnect();   steppedConnection   = nil end
    if characterConnection then characterConnection:Disconnect(); characterConnection = nil end
    if globalPlayerAddedConn    then globalPlayerAddedConn:Disconnect();    globalPlayerAddedConn    = nil end
    if globalPlayerRemovingConn then globalPlayerRemovingConn:Disconnect(); globalPlayerRemovingConn = nil end

    for k, v in pairs(Configs) do
        if type(v) == "boolean" then Configs[k] = false end
    end

    FarmManager_SetState("Stopped")

    pcall(function()
        local char, root, hum = GetCharAndRoot()
        if root then
            root.Anchored = false
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
        if hum then
            hum.WalkSpeed    = 16
            hum.UseJumpPower = true
            hum.JumpPower    = 50
        end
    end)

    _G.AkatLogicRunning = false
end

-- ==================== CALLBACKS DA UI EXTERNA ====================
_G.AkatCallbacks = {

    AutoFarm = function(enabled)
        Configs.AutoFarm = enabled and true or false
        if Configs.AutoFarm then
            StartFarmManager()
        else
            FarmManager_Stop()
        end
    end,

    AutoQuest = function(enabled)
        Configs.AutoQuest = enabled and true or false
    end,

    AutoLevel = function(enabled)
        Configs.AutoLevel = enabled and true or false
    end,

    KillAura = function(enabled)
        Configs.KillAura = enabled and true or false
    end,

    FarmPosition = function(value)
        Configs.FarmPosition = value or "Above NPC"
    end,

    FarmHeight = function(value)
        if type(value) == "number" then
            Configs.FarmHeight = math.clamp(value, 1, 50)
        end
    end,

    FightingStyle = function(value)
        Configs.FightingStyle = value or "Current"
    end,

    AutoMastery = function(enabled)
        Configs.AutoMastery = enabled and true or false
    end,

    MasteryType = function(value)
        Configs.MasteryType = value or "Fighting Style"
    end,

    MasteryTarget = function(value)
        if type(value) == "number" then
            Configs.MasteryTarget = math.max(1, value)
        end
    end,

    AutoBoss = function(enabled)
        Configs.AutoBoss = enabled and true or false
        if Configs.AutoBoss and Configs.AutoFarm then
            StartFarmManager()
        end
    end,

    BossName = function(value)
        Configs.BossName = value or ""
    end,

    BossQuest = function(enabled)
        Configs.BossQuest = enabled and true or false
    end,

    BossMode = function(value)
        Configs.BossMode = value or "Selected Boss"
    end,

    AutoMaterial = function(enabled)
        Configs.AutoMaterial = enabled and true or false
    end,

    MaterialName = function(value)
        Configs.MaterialName = value or ""
    end,

    MaterialAmount = function(value)
        if type(value) == "number" then
            Configs.MaterialAmount = math.max(1, value)
        end
    end,

    DetectFruit = function(enabled)
        Configs.DetectFruit = enabled and true or false
    end,

    FruitNotification = function(enabled)
        Configs.FruitNotification = enabled and true or false
    end,

    FruitFilter = function(value)
        Configs.FruitFilter = value or "Any"
    end,

    AutoSeaEvent = function(enabled)
        Configs.AutoSeaEvent = enabled and true or false
    end,

    SeaEventName = function(value)
        Configs.SeaEventName = value or "Any"
    end,

    AutoStats = function(enabled)
        Configs.AutoStats = enabled and true or false
    end,

    StatPrimary = function(value)
        Configs.StatPrimary = value or "Blox Fruit"
    end,

    StatSecondary = function(value)
        Configs.StatSecondary = value or "Defense"
    end,

    StatTertiary = function(value)
        Configs.StatTertiary = value or "Melee"
    end,

    AutoServerSearch = function(enabled)
        Configs.AutoServerSearch = enabled and true or false
    end,

    ServerReason = function(value)
        Configs.ServerReason = value or "Boss"
    end,

    Debug = function(enabled)
        Configs.Debug = enabled and true or false
    end,

    GetFarmState = function()
        return FarmState
    end,

    ShutdownAll = function()
        LimparEDesligarAbsolutamente()
    end,
}

-- ==================== INICIALIZADOR DA UI EXTERNA ====================
task.spawn(function()
    local uiRawUrl = "https://raw.githubusercontent.com/estratosfera88-afk/Ui-do-teste/refs/heads/main/bf_ui.lua"

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
