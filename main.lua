-- [[
--     AKAT BLOX FRUITS MAIN LOGIC [v1.0]
--     Compatível com Delta Mobile & PC | Blox Fruits (2026)
--     BACKEND ONLY — sem código de interface visual
--
--     FUNCIONALIDADES:
--     - Auto Farm Level (seleção dinâmica de ilha/quest/mob por nível)
--     - Auto Farm Boss (First Sea — lista de bosses configurável)
--     - Auto Farm Mastery (Fruit / Gun / Sword com Smart Targeting)
--     - Auto Farm Materials / Bones
--     - Auto Farm Chests
--     - Mob Aura (Kill Aura para NPCs)
--     - Auto Quest (aceitar, completar, entregar automaticamente)
--     - Auto Skills (Fruit / Sword / Gun com respeito a cooldowns)
--     - Sistema de estado robusto (evita conflitos entre farms)
--     - Proteções: respawn, HumanoidRootPart ausente, NPC/boss inexistente
-- ]]

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
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

-- ==================== SISTEMA DE ESTADO CENTRAL ====================
-- Evita que múltiplos farms controlem o personagem ao mesmo tempo.
local FarmState = {
    Active = "None",   -- "None" | "Level" | "Boss" | "Mastery" | "Material" | "Chest"
    Status = "Idle",   -- Texto descritivo do que está fazendo
}
_G.BFState = FarmState

-- ==================== CONFIGURAÇÕES ====================
local Configs = {
    -- Farm Level
    AutoFarmLevel      = false,
    -- Farm Boss
    AutoFarmBoss       = false,
    SelectedBoss       = "Gorilla King",
    AutoCollectDrops   = false,
    AutoSkills         = false,
    -- Farm Mastery
    AutoFarmMastery    = false,
    MasteryType        = "Fruit",   -- "Fruit" | "Gun" | "Sword"
    SmartTargeting     = true,
    -- Farm Materials/Bones
    AutoFarmMaterials  = false,
    MaterialTarget     = "Bones",  -- "Bones" | "Materials" | "All"
    -- Farm Chests
    AutoFarmChests     = false,
    -- Mob Aura
    MobAura            = false,
    AuraRange          = 30,
    -- Auto Quest
    AutoQuest          = false,
    -- Player Stats
    Speed              = false,
    SpeedValue         = 16,
    JumpPower          = false,
    JumpPowerValue     = 50,
    -- Misc
    Debug              = false,
    TpToIsland         = false,
}
_G.Configs = Configs

-- ==================== FORWARD DECLARATIONS ====================
local StopAllFarms
local GetCharacterRoot
local GetHumanoid
local IsAlive
local SafeTP
local UseAutoSkills
local FindNearestNPC
local MobAuraLoop
local AutoQuestLoop
local LevelFarmLoop
local BossFarmLoop
local MasteryFarmLoop
local MaterialFarmLoop
local ChestFarmLoop

-- ==================== DEBUG ====================
local function DebugLog(sistema, msg)
    if Configs.Debug then
        warn(("[AKAT BF][%s] %s"):format(sistema, tostring(msg)))
    end
end

-- ==================== STATUS DISPLAY ====================
local function SetStatus(status)
    FarmState.Status = status
    _G.BFFarmStatus = status
    DebugLog("Status", status)
end

-- ==================== HELPERS SEGUROS ====================
GetCharacterRoot = function()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

GetHumanoid = function()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

IsAlive = function()
    local hum = GetHumanoid()
    return hum ~= nil and hum.Health > 0
end

-- Teleporte seguro com verificações
SafeTP = function(targetCFrame)
    if not IsAlive() then return false end
    local root = GetCharacterRoot()
    if not root then return false end
    local ok = pcall(function()
        root.CFrame = targetCFrame
    end)
    return ok
end

-- ==================== DADOS DO BLOX FRUITS (First Sea) ====================

-- Tabela de progressão de nível → ilha/quest
-- Estrutura: { minLevel, maxLevel, island, questNPC, mobName }
local LEVEL_PROGRESSION = {
    { min = 1,    max = 15,   island = "Starter Island",      questNPC = "Guard",               mob = "Bandit" },
    { min = 15,   max = 30,   island = "Middle Island",        questNPC = "Military Detective",  mob = "Monkey" },
    { min = 30,   max = 60,   island = "Middle Island",        questNPC = "Military Detective",  mob = "Gorilla" },
    { min = 60,   max = 90,   island = "Middle Island",        questNPC = "Military Detective",  mob = "Gorilla King" },
    { min = 90,   max = 120,  island = "Middle Island",        questNPC = "Military Detective",  mob = "Toga Warrior" },
    { min = 120,  max = 150,  island = "Jungle",               questNPC = "Military Soldier",    mob = "Tribal Man" },
    { min = 150,  max = 190,  island = "Pirate Village",       questNPC = "Military Soldier",    mob = "Brute" },
    { min = 190,  max = 250,  island = "Desert",               questNPC = "Military Soldier",    mob = "Desert Bandits" },
    { min = 250,  max = 300,  island = "Snow Island",          questNPC = "Military Soldier",    mob = "Snowman" },
    { min = 300,  max = 375,  island = "Marine Fortress",      questNPC = "Marine Captain",      mob = "Marine" },
    { min = 375,  max = 450,  island = "Sky Island",           questNPC = "Sky Bandit",          mob = "Sky Bandit" },
    { min = 450,  max = 550,  island = "Prison",               questNPC = "Warden",              mob = "Prisoner" },
    { min = 550,  max = 650,  island = "Colosseum",            questNPC = "Gladiator",           mob = "Gladiator" },
    { min = 650,  max = 700,  island = "Magma Village",        questNPC = "Hot Dog Man",         mob = "Magma Ninja" },
    { min = 700,  max = 750,  island = "Upper Skylands",       questNPC = "Skypiean",            mob = "Sky Castaway" },
}

-- Bosses do First Sea
local FIRST_SEA_BOSSES = {
    "Gorilla King",
    "Saber Expert",
    "Vice Admiral",
    "Warden",
    "Chief Warden",
    "Swan",
    "Yeti",
    "Mob Leader",
    "Greybeard",
    "Wysper",
    "Thunder God",
}

-- ==================== SKILL COOLDOWN MANAGER ====================
local SkillCooldowns = {}

local function CanUseSkill(skillName, cooldownTime)
    local last = SkillCooldowns[skillName] or 0
    return (os.clock() - last) >= cooldownTime
end

local function RegisterSkillUse(skillName)
    SkillCooldowns[skillName] = os.clock()
end

-- ==================== AUTO SKILLS ====================
-- Detecta e usa skills disponíveis do fruto/espada/gun equipados.
UseAutoSkills = function()
    if not scriptAlive or not IsAlive() then return end
    local char = player.Character
    if not char then return end

    -- Tenta usar skills do personagem (teclas Z, X, C, V para frutos)
    -- e skills de espada/gun via RemoteEvents conhecidos do BF
    local function tryFireSkill(toolName, skillKey, cooldown)
        if not CanUseSkill(toolName .. skillKey, cooldown) then return end

        local tool = char:FindFirstChild(toolName)
            or player.Backpack:FindFirstChild(toolName)
        if not tool then return end

        -- Equipa se estiver no backpack
        if tool.Parent == player.Backpack then
            local hum = GetHumanoid()
            if hum then
                pcall(function() hum:EquipTool(tool) end)
                task.wait(0.1)
            end
        end

        -- Tenta ativar a tool
        pcall(function()
            if tool.Parent == char then
                tool:Activate()
                RegisterSkillUse(toolName .. skillKey)
            end
        end)
    end

    -- Procura qualquer tool equipada e tenta ativá-la
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            -- Determina cooldown base pelo tipo
            local cd = 0.8
            if n:find("gun") or n:find("pistol") or n:find("musket") then cd = 0.5 end
            if CanUseSkill(tool.Name .. "_activate", cd) then
                pcall(function()
                    tool:Activate()
                    RegisterSkillUse(tool.Name .. "_activate")
                end)
            end
        end
    end
end

-- ==================== ENCONTRAR NPC MAIS PRÓXIMO ====================
FindNearestNPC = function(nameFilter, maxRange, smartTargeting)
    local root = GetCharacterRoot()
    if not root then return nil end

    local nearest, nearestDist = nil, math.huge
    local maxRange = maxRange or 1000

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= player.Character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                -- Filtra por nome se fornecido
                local nameMatch = true
                if nameFilter and nameFilter ~= "" then
                    nameMatch = obj.Name:lower():find(nameFilter:lower()) ~= nil
                end

                if nameMatch then
                    local dist = (root.Position - hrp.Position).Magnitude
                    if dist < maxRange and dist < nearestDist then
                        -- Smart targeting: prefere NPCs com HP suficiente para mastery
                        if smartTargeting then
                            local hpRatio = hum.Health / hum.MaxHealth
                            if hpRatio > 0.15 then  -- só alvo com mais de 15% HP
                                nearest = obj
                                nearestDist = dist
                            end
                        else
                            nearest = obj
                            nearestDist = dist
                        end
                    end
                end
            end
        end
    end

    return nearest, nearestDist
end

-- ==================== MOB AURA / KILL AURA ====================
MobAuraLoop = function()
    task.spawn(function()
        local lastAuraTime = 0
        local AURA_INTERVAL = 0.15

        while scriptAlive do
            task.wait(AURA_INTERVAL)

            if not Configs.MobAura then continue end
            if not IsAlive() then continue end

            local char = player.Character
            local root = GetCharacterRoot()
            if not char or not root then continue end

            -- Encontra todos os NPCs no alcance da aura
            local range = Configs.AuraRange or 30
            local found = false

            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and obj ~= char then
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    local hrp = obj:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.Health > 0 then
                        local dist = (root.Position - hrp.Position).Magnitude
                        if dist <= range then
                            found = true
                            -- Ataca via firetouchinterest na tool equipada
                            local equippedTool = nil
                            for _, item in ipairs(char:GetChildren()) do
                                if item:IsA("Tool") then
                                    equippedTool = item
                                    break
                                end
                            end

                            if equippedTool then
                                local handle = equippedTool:FindFirstChild("Handle")
                                    or equippedTool:FindFirstChildOfClass("BasePart")
                                if handle then
                                    pcall(function()
                                        firetouchinterest(hrp, handle, 0)
                                        firetouchinterest(hrp, handle, 1)
                                    end)
                                end
                            end

                            -- Teleporta para perto do NPC para garantir hits
                            if dist > range * 0.5 then
                                SafeTP(hrp.CFrame * CFrame.new(0, 0, -3))
                            end
                        end
                    end
                end
            end

            if not found then
                SetStatus("Searching NPCs")
            end
        end
    end)
end

-- ==================== AUTO QUEST SYSTEM ====================
-- Encontra o NPC de quest correspondente ao nível atual, aceita a quest,
-- vai até os mobs, elimina, volta, entrega, repete.

local function GetPlayerLevel()
    local level = 0
    pcall(function()
        -- Tenta ler o nível via LeaderStats
        local ls = player:FindFirstChild("leaderstats")
            or player:FindFirstChild("Leaderstats")
            or player:FindFirstChild("LeaderStats")
        if ls then
            local lv = ls:FindFirstChild("Level")
                or ls:FindFirstChild("Lv")
                or ls:FindFirstChild("Beli")
            if lv then level = tonumber(lv.Value) or 0 end
        end
    end)
    return level
end

local function GetProgressionEntry(level)
    local entry = LEVEL_PROGRESSION[1]
    for _, e in ipairs(LEVEL_PROGRESSION) do
        if level >= e.min then
            entry = e
        end
    end
    return entry
end

local function FindQuestNPC(npcName)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find(npcName:lower()) then
            local hrp = obj:FindFirstChild("HumanoidRootPart")
                or obj:FindFirstChildOfClass("BasePart")
            if hrp then return hrp end
        end
    end
    return nil
end

local function TryAcceptQuest(questNPCPart)
    if not questNPCPart then return false end
    SetStatus("Accepting Quest")

    -- TP até o NPC de quest
    SafeTP(questNPCPart.CFrame * CFrame.new(0, 0, -5))
    task.wait(0.5)

    -- Tenta usar RemoteEvents de quest conhecidos no BF
    local accepted = false
    pcall(function()
        -- Tenta via ProximityPrompt
        for _, pp in ipairs(questNPCPart.Parent:GetDescendants()) do
            if pp:IsA("ProximityPrompt") and pp.ActionText:lower():find("quest") then
                fireproximityprompt(pp)
                accepted = true
                break
            end
        end
    end)

    -- Fallback: tenta RemoteEvents da pasta de quests
    if not accepted then
        pcall(function()
            local questFolder = ReplicatedStorage:FindFirstChild("Quests")
                or ReplicatedStorage:FindFirstChild("Quest")
            if questFolder then
                local re = questFolder:FindFirstChild("GetQuest")
                    or questFolder:FindFirstChild("AcceptQuest")
                    or questFolder:FindFirstChildOfClass("RemoteEvent")
                if re then
                    re:FireServer()
                    accepted = true
                end
            end
        end)
    end

    return accepted
end

local function TryDeliverQuest(questNPCPart)
    if not questNPCPart then return false end
    SetStatus("Delivering Quest")

    SafeTP(questNPCPart.CFrame * CFrame.new(0, 0, -5))
    task.wait(0.5)

    local delivered = false
    pcall(function()
        for _, pp in ipairs(questNPCPart.Parent:GetDescendants()) do
            if pp:IsA("ProximityPrompt") then
                fireproximityprompt(pp)
                delivered = true
                break
            end
        end
    end)

    pcall(function()
        local questFolder = ReplicatedStorage:FindFirstChild("Quests")
            or ReplicatedStorage:FindFirstChild("Quest")
        if questFolder then
            local re = questFolder:FindFirstChild("DeliverQuest")
                or questFolder:FindFirstChild("CompleteQuest")
                or questFolder:FindFirstChildOfClass("RemoteEvent")
            if re then
                re:FireServer()
                delivered = true
            end
        end
    end)

    return delivered
end

-- ==================== LOOP: AUTO QUEST STANDALONE ====================
AutoQuestLoop = function()
    task.spawn(function()
        while scriptAlive do
            task.wait(0.3)
            if not Configs.AutoQuest then continue end
            if not IsAlive() then task.wait(2) continue end

            local level = GetPlayerLevel()
            local entry = GetProgressionEntry(level)

            SetStatus("Searching Quest: " .. entry.questNPC)
            local questNPCPart = FindQuestNPC(entry.questNPC)

            if not questNPCPart then
                task.wait(2)
                continue
            end

            TryAcceptQuest(questNPCPart)
            task.wait(1)

            -- Vai até os mobs da quest
            SetStatus("Traveling to " .. entry.mob)
            local mob, _ = FindNearestNPC(entry.mob, 5000, false)
            if mob then
                local mobHRP = mob:FindFirstChild("HumanoidRootPart")
                if mobHRP then
                    SafeTP(mobHRP.CFrame * CFrame.new(0, 0, -4))
                end
            end

            task.wait(2)

            -- Usa aura/skills para eliminar mobs
            SetStatus("Farming " .. entry.mob)
            local farmTime = os.clock()
            while scriptAlive and Configs.AutoQuest and (os.clock() - farmTime) < 60 do
                task.wait(0.2)
                if not IsAlive() then break end
                if Configs.AutoSkills then UseAutoSkills() end

                local target, dist = FindNearestNPC(entry.mob, 3000, false)
                if target then
                    local hrp = target:FindFirstChild("HumanoidRootPart")
                    if hrp and dist and dist > 5 then
                        SafeTP(hrp.CFrame * CFrame.new(0, 0, -4))
                    end
                else
                    -- Sem mob disponível: espera spawn
                    SetStatus("Waiting Spawn")
                    task.wait(3)
                end
            end

            -- Tenta entregar quest
            local questNPCPart2 = FindQuestNPC(entry.questNPC)
            TryDeliverQuest(questNPCPart2)
            task.wait(1)
        end
    end)
end

-- ==================== LOOP: AUTO FARM LEVEL ====================
LevelFarmLoop = function()
    task.spawn(function()
        while scriptAlive do
            task.wait(0.25)
            if not Configs.AutoFarmLevel then continue end
            if FarmState.Active ~= "Level" then continue end
            if not IsAlive() then task.wait(2) continue end

            local level = GetPlayerLevel()
            local entry = GetProgressionEntry(level)

            SetStatus("Level Farm — " .. entry.island .. " | Lv." .. level)

            -- Localiza mob da ilha atual
            local mob, dist = FindNearestNPC(entry.mob, 5000, false)
            if not mob then
                SetStatus("Searching mob: " .. entry.mob)
                task.wait(2)
                continue
            end

            local mobHRP = mob:FindFirstChild("HumanoidRootPart")
            if not mobHRP then continue end

            -- Se longe, teleporta para perto
            if dist and dist > 10 then
                SetStatus("Traveling")
                SafeTP(mobHRP.CFrame * CFrame.new(0, 0, -5))
                task.wait(0.3)
            end

            SetStatus("Farming: " .. entry.mob)

            -- Ataca o mob
            if Configs.AutoSkills then UseAutoSkills() end

            -- Mob Aura cuida de atacar NPCs próximos;
            -- aqui garante que o personagem fique no spot certo
            local char = player.Character
            local root = GetCharacterRoot()
            if root and mobHRP and mobHRP.Parent then
                local mobHum = mob:FindFirstChildOfClass("Humanoid")
                if not mobHum or mobHum.Health <= 0 then
                    -- Mob morreu: procura o próximo
                    continue
                end
            end

            -- Quest automática se configurada
            if Configs.AutoQuest then
                -- A AutoQuestLoop cuida disso; aqui apenas aguarda
                task.wait(0.1)
            end
        end
    end)
end

-- ==================== LOOP: AUTO FARM BOSS ====================
BossFarmLoop = function()
    task.spawn(function()
        while scriptAlive do
            task.wait(0.5)
            if not Configs.AutoFarmBoss then continue end
            if FarmState.Active ~= "Boss" then continue end
            if not IsAlive() then task.wait(2) continue end

            local bossName = Configs.SelectedBoss or "Gorilla King"
            SetStatus("Searching Boss: " .. bossName)

            local boss, dist = FindNearestNPC(bossName, 10000, false)
            if not boss then
                SetStatus("Waiting Boss Respawn: " .. bossName)
                task.wait(5)
                continue
            end

            local bossHRP = boss:FindFirstChild("HumanoidRootPart")
            if not bossHRP then
                task.wait(2)
                continue
            end

            SetStatus("Traveling to Boss: " .. bossName)
            SafeTP(bossHRP.CFrame * CFrame.new(0, 0, -6))
            task.wait(0.5)

            -- Luta contra o boss
            SetStatus("Fighting Boss: " .. bossName)
            local fightStart = os.clock()
            local MAX_FIGHT_TIME = 120  -- 2 minutos máximo por boss

            while scriptAlive and Configs.AutoFarmBoss and FarmState.Active == "Boss" do
                task.wait(0.2)
                if not IsAlive() then break end

                local bossHum = boss:FindFirstChildOfClass("Humanoid")
                if not bossHum or bossHum.Health <= 0 then
                    SetStatus("Boss Defeated: " .. bossName)
                    break
                end

                -- Fica próximo do boss
                if bossHRP and bossHRP.Parent then
                    local d = (GetCharacterRoot() and GetCharacterRoot().Position or Vector3.zero
                        - bossHRP.Position).Magnitude
                    if d > 12 then
                        SafeTP(bossHRP.CFrame * CFrame.new(0, 0, -6))
                    end
                end

                -- Usa skills
                if Configs.AutoSkills then UseAutoSkills() end

                -- Timeout de segurança
                if (os.clock() - fightStart) > MAX_FIGHT_TIME then
                    DebugLog("BossFarm", "Fight timeout — boss pode ser imune ou não encontrado")
                    break
                end
            end

            -- Coleta drops (firetouchinterest em drops próximos)
            if Configs.AutoCollectDrops then
                SetStatus("Collecting Drops")
                task.wait(0.5)
                local root = GetCharacterRoot()
                if root then
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if obj:IsA("BasePart") and obj.CanCollide == false then
                            local n = obj.Name:lower()
                            if n:find("drop") or n:find("fruit") or n:find("chest")
                                or n:find("loot") or n:find("item") then
                                local d = (root.Position - obj.Position).Magnitude
                                if d < 100 then
                                    SafeTP(CFrame.new(obj.Position + Vector3.new(0, 3, 0)))
                                    pcall(function()
                                        firetouchinterest(root, obj, 0)
                                        firetouchinterest(root, obj, 1)
                                    end)
                                end
                            end
                        end
                    end
                end
            end

            -- Aguarda respawn
            SetStatus("Waiting Boss Respawn: " .. bossName)
            local waitRespawn = os.clock()
            while scriptAlive and Configs.AutoFarmBoss and FarmState.Active == "Boss" do
                task.wait(2)
                local b2, _ = FindNearestNPC(bossName, 10000, false)
                if b2 then break end
                if (os.clock() - waitRespawn) > 300 then break end  -- 5 min max espera
            end
        end
    end)
end

-- ==================== LOOP: AUTO FARM MASTERY ====================
MasteryFarmLoop = function()
    task.spawn(function()
        while scriptAlive do
            task.wait(0.3)
            if not Configs.AutoFarmMastery then continue end
            if FarmState.Active ~= "Mastery" then continue end
            if not IsAlive() then task.wait(2) continue end

            local masteryType = Configs.MasteryType or "Fruit"
            SetStatus("Mastery Farm: " .. masteryType)

            -- Smart targeting: procura NPCs com HP suficiente
            local useSmartTargeting = Configs.SmartTargeting
            local mob, dist = FindNearestNPC("", Configs.AuraRange * 3, useSmartTargeting)

            if not mob then
                SetStatus("Searching mobs for Mastery")
                task.wait(1)
                continue
            end

            local mobHRP = mob:FindFirstChild("HumanoidRootPart")
            if not mobHRP then continue end

            -- Posiciona perto do mob
            if dist and dist > 8 then
                SafeTP(mobHRP.CFrame * CFrame.new(0, 0, -5))
                task.wait(0.3)
            end

            SetStatus("Mastery Farming: " .. masteryType)

            -- Usa skills repetidamente
            if Configs.AutoSkills then
                UseAutoSkills()
                task.wait(0.3)
                UseAutoSkills()
            end

            -- Verifica se o mob ainda está vivo (para mastery, queremos mobs com HP)
            local mobHum = mob:FindFirstChildOfClass("Humanoid")
            if mobHum and mobHum.Health <= 0 then
                -- Mob morreu: procura outro
                continue
            end
        end
    end)
end

-- ==================== LOOP: AUTO FARM MATERIALS / BONES ====================
MaterialFarmLoop = function()
    task.spawn(function()
        while scriptAlive do
            task.wait(0.3)
            if not Configs.AutoFarmMaterials then continue end
            if FarmState.Active ~= "Material" then continue end
            if not IsAlive() then task.wait(2) continue end

            local target = Configs.MaterialTarget or "Bones"
            SetStatus("Material Farm: " .. target)

            -- Detecta mobs que fornecem o material
            -- Bones: geralmente dropados por NPCs específicos
            -- Materials: drops de qualquer NPC
            local mobFilter = ""
            if target == "Bones" then
                -- Bones são dropados por NPCs de qualquer tipo
                mobFilter = ""
            end

            local mob, dist = FindNearestNPC(mobFilter, 5000, false)
            if not mob then
                SetStatus("Searching mobs for " .. target)
                task.wait(2)
                continue
            end

            local mobHRP = mob:FindFirstChild("HumanoidRootPart")
            if not mobHRP then continue end

            if dist and dist > 10 then
                SetStatus("Traveling to mob")
                SafeTP(mobHRP.CFrame * CFrame.new(0, 0, -5))
                task.wait(0.3)
            end

            SetStatus("Farming for " .. target)

            if Configs.AutoSkills then UseAutoSkills() end

            -- Coleta drops no chão próximos
            local root = GetCharacterRoot()
            if root then
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        local n = obj.Name:lower()
                        local isLoot = n:find("bone") or n:find("material")
                            or n:find("drop") or n:find("loot") or n:find("item")
                            or n:find("fragment")
                        if isLoot then
                            local d = (root.Position - obj.Position).Magnitude
                            if d < 30 then
                                SafeTP(CFrame.new(obj.Position + Vector3.new(0, 3, 0)))
                                pcall(function()
                                    firetouchinterest(root, obj, 0)
                                    firetouchinterest(root, obj, 1)
                                end)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ==================== LOOP: AUTO FARM CHESTS ====================
ChestFarmLoop = function()
    task.spawn(function()
        while scriptAlive do
            task.wait(0.5)
            if not Configs.AutoFarmChests then continue end
            if FarmState.Active ~= "Chest" then continue end
            if not IsAlive() then task.wait(2) continue end

            SetStatus("Searching Chests")

            local root = GetCharacterRoot()
            if not root then continue end

            -- Localiza todos os baús no workspace
            local chests = {}
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") or obj:IsA("BasePart") then
                    local n = obj.Name:lower()
                    if n:find("chest") or n == "locker" or n:find("crate") then
                        local part = obj:IsA("BasePart") and obj
                            or obj:FindFirstChildOfClass("BasePart")
                            or (obj:IsA("Model") and obj.PrimaryPart)
                        if part then
                            local dist = (root.Position - part.Position).Magnitude
                            if dist < 3000 then
                                table.insert(chests, {part = part, dist = dist})
                            end
                        end
                    end
                end
            end

            if #chests == 0 then
                SetStatus("No Chests Found")
                task.wait(3)
                continue
            end

            -- Ordena por distância
            table.sort(chests, function(a, b) return a.dist < b.dist end)

            -- Vai a cada baú e tenta coletar
            for _, chestData in ipairs(chests) do
                if not scriptAlive or not Configs.AutoFarmChests
                    or FarmState.Active ~= "Chest" then break end
                if not IsAlive() then break end

                local chestPart = chestData.part
                if not chestPart or not chestPart.Parent then continue end

                SetStatus("Traveling to Chest")
                local ok = SafeTP(CFrame.new(chestPart.Position + Vector3.new(0, 3, 0)))
                if not ok then continue end

                task.wait(0.3)

                SetStatus("Collecting Chest")

                -- Tenta abrir via ProximityPrompt
                local opened = false
                pcall(function()
                    local parent = chestPart.Parent or chestPart
                    for _, pp in ipairs(parent:GetDescendants()) do
                        if pp:IsA("ProximityPrompt") then
                            fireproximityprompt(pp)
                            opened = true
                            break
                        end
                    end
                end)

                -- Fallback: touch
                if not opened then
                    pcall(function()
                        local root2 = GetCharacterRoot()
                        if root2 then
                            firetouchinterest(root2, chestPart, 0)
                            firetouchinterest(root2, chestPart, 1)
                        end
                    end)
                end

                task.wait(0.4)
            end
        end
    end)
end

-- ==================== CONTROLE DO ESTADO DE FARM ====================
StopAllFarms = function()
    -- Interrompe todos os farms desligando as flags
    Configs.AutoFarmLevel     = false
    Configs.AutoFarmBoss      = false
    Configs.AutoFarmMastery   = false
    Configs.AutoFarmMaterials = false
    Configs.AutoFarmChests    = false
    FarmState.Active          = "None"
    SetStatus("Idle")

    -- Restaura velocidade do personagem
    local hum = GetHumanoid()
    if hum then
        hum.WalkSpeed    = Configs.Speed     and Configs.SpeedValue    or 16
        hum.UseJumpPower = true
        hum.JumpPower    = Configs.JumpPower and Configs.JumpPowerValue or 50
    end

    local root = GetCharacterRoot()
    if root then
        root.Anchored = false
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

local function SetActiveFarm(farmType)
    if FarmState.Active ~= farmType and FarmState.Active ~= "None" then
        -- Para o farm atual antes de iniciar o novo
        local prev = FarmState.Active
        FarmState.Active = "None"
        task.wait(0.2)
    end
    FarmState.Active = farmType
end

-- ==================== THREAD: HEARTBEAT / PLAYER STATS ====================
local hbConnection = RunService.Heartbeat:Connect(function()
    if not scriptAlive then return end

    local char = player.Character
    local root = GetCharacterRoot()
    local hum  = GetHumanoid()
    if not root or not hum then return end

    -- Aplica velocidade/pulo apenas se não estiver em farm (o farm controla)
    if FarmState.Active == "None" then
        root.Anchored = false
        hum.WalkSpeed = Configs.Speed     and Configs.SpeedValue    or 16
        hum.UseJumpPower = true
        hum.JumpPower = Configs.JumpPower and Configs.JumpPowerValue or 50
    end
end)

-- ==================== THREAD: NOCLIP SEGURO (Stepped) ====================
-- Necessário para teleportes não ficarem presos em geometria
local steppedConnection = RunService.Stepped:Connect(function()
    if not scriptAlive then return end
    -- Só aplica noclip quando algum farm está ativo
    if FarmState.Active ~= "None" or Configs.AutoQuest then
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- ==================== INICIAR LOOPS ====================
MobAuraLoop()
AutoQuestLoop()
LevelFarmLoop()
BossFarmLoop()
MasteryFarmLoop()
MaterialFarmLoop()
ChestFarmLoop()

-- ==================== CICLO DE VIDA: RESPAWN ====================
local characterConnection = player.CharacterAdded:Connect(function(char)
    SetStatus("Idle")
    -- Aguarda o personagem carregar antes de retomar farms
    task.wait(1)
    DebugLog("Respawn", "Personagem adicionado — retomando farms ativos")
end)

-- ==================== SHUTDOWN COMPLETO ====================
local function LimparEDesligarAbsolutamente()
    scriptAlive = false

    if hbConnection      then hbConnection:Disconnect()      end
    if steppedConnection then steppedConnection:Disconnect() end
    if characterConnection then characterConnection:Disconnect() end

    StopAllFarms()

    pcall(function()
        local char = player.Character
        if not char then return end

        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.Anchored = false
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

-- ==================== CALLBACKS DA UI EXTERNA ====================
_G.AkatCallbacks = {

    -- Farm Level
    AutoFarmLevel = function(enabled)
        Configs.AutoFarmLevel = enabled and true or false
        if enabled then
            SetActiveFarm("Level")
        else
            if FarmState.Active == "Level" then
                FarmState.Active = "None"
                SetStatus("Idle")
            end
        end
    end,

    -- Farm Boss
    AutoFarmBoss = function(enabled)
        Configs.AutoFarmBoss = enabled and true or false
        if enabled then
            SetActiveFarm("Boss")
        else
            if FarmState.Active == "Boss" then
                FarmState.Active = "None"
                SetStatus("Idle")
            end
        end
    end,

    SelectedBoss = function(bossName)
        Configs.SelectedBoss = bossName
    end,

    AutoCollectDrops = function(enabled)
        Configs.AutoCollectDrops = enabled and true or false
    end,

    -- Farm Mastery
    AutoFarmMastery = function(enabled)
        Configs.AutoFarmMastery = enabled and true or false
        if enabled then
            SetActiveFarm("Mastery")
        else
            if FarmState.Active == "Mastery" then
                FarmState.Active = "None"
                SetStatus("Idle")
            end
        end
    end,

    MasteryType = function(mtype)
        Configs.MasteryType = mtype
    end,

    SmartTargeting = function(enabled)
        Configs.SmartTargeting = enabled and true or false
    end,

    -- Farm Materials
    AutoFarmMaterials = function(enabled)
        Configs.AutoFarmMaterials = enabled and true or false
        if enabled then
            SetActiveFarm("Material")
        else
            if FarmState.Active == "Material" then
                FarmState.Active = "None"
                SetStatus("Idle")
            end
        end
    end,

    MaterialTarget = function(target)
        Configs.MaterialTarget = target
    end,

    -- Farm Chests
    AutoFarmChests = function(enabled)
        Configs.AutoFarmChests = enabled and true or false
        if enabled then
            SetActiveFarm("Chest")
        else
            if FarmState.Active == "Chest" then
                FarmState.Active = "None"
                SetStatus("Idle")
            end
        end
    end,

    -- Mob Aura
    MobAura = function(enabled)
        Configs.MobAura = enabled and true or false
    end,

    AuraRange = function(value)
        if type(value) == "number" then
            Configs.AuraRange = math.clamp(value, 5, 100)
        end
    end,

    -- Auto Quest
    AutoQuest = function(enabled)
        Configs.AutoQuest = enabled and true or false
    end,

    -- Auto Skills
    AutoSkills = function(enabled)
        Configs.AutoSkills = enabled and true or false
    end,

    -- Player Stats
    Speed = function(value)
        if type(value) == "number" then
            Configs.SpeedValue = math.clamp(value, 0, 200)
            Configs.Speed = true
        else
            Configs.Speed = value and true or false
        end
        if FarmState.Active == "None" then
            local char = player.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = Configs.Speed and Configs.SpeedValue or 16 end
        end
    end,

    JumpPower = function(value)
        if type(value) == "number" then
            Configs.JumpPowerValue = math.clamp(value, 0, 200)
            Configs.JumpPower = true
        else
            Configs.JumpPower = value and true or false
        end
        if FarmState.Active == "None" then
            local char = player.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower    = Configs.JumpPower and Configs.JumpPowerValue or 50
            end
        end
    end,

    -- Stop All
    StopAllFarms = function()
        StopAllFarms()
    end,

    ShutdownAll = function()
        LimparEDesligarAbsolutamente()
    end,
}

-- ==================== INICIALIZADOR DA UI EXTERNA ====================
task.spawn(function()
    local uiRawUrl = "https://raw.githubusercontent.com/estratosfera88-afk/Ui-do-teste/refs/heads/main/ui.lua"

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
