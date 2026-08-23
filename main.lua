--[[
    AKATSUKI BLOX FRUITS SCRIPT - v2.0.0
    Reestruturado e corrigido por Zeni
    Arquitetura modular, sistemas reais e controle de threads.
--]]

-- ==================== SERVICES ====================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- ==================== CONFIGURATION ====================
local Config = {
    -- Auto Farm
    AutoFarm = false,
    AutoFarmBoss = false,
    AutoCollectChest = false,
    AutoStats = false,
    SelectedMob = "Lowest Level Mob",
    SelectedBoss = "None",
    SelectedStat = "Melee",
    FarmSafeDistance = 14,

    -- PvP
    AimbotPvP = false,
    AimFOV = 300,
    FruitSniper = false,

    -- Raid
    AutoRaid = false,

    -- Visual
    PlayerESP = false,
    FruitESP = false,

    -- Extras
    AutoRevive = false,
    ServerHop = false,
}

-- ==================== CHARACTER SYSTEM ====================
local CharacterSystem = {}
CharacterSystem.__index = CharacterSystem

function CharacterSystem.new()
    local self = setmetatable({}, CharacterSystem)
    self.Character = nil
    self.HumanoidRootPart = nil
    self.Humanoid = nil
    self.OnCharacterAdded = nil
    self:Connect()
    return self
end

function CharacterSystem:Connect()
    self:UpdateCharacter(player.Character)
    player.CharacterAdded:Connect(function(char)
        self:UpdateCharacter(char)
        if self.OnCharacterAdded then
            self.OnCharacterAdded(char)
        end
    end)
    player.CharacterRemoving:Connect(function()
        self:UpdateCharacter(nil)
    end)
end

function CharacterSystem:UpdateCharacter(char)
    self.Character = char
    self.HumanoidRootPart = char and char:FindFirstChild("HumanoidRootPart") or nil
    self.Humanoid = char and char:FindFirstChild("Humanoid") or nil
end

function CharacterSystem:IsAlive()
    return self.Character ~= nil and self.HumanoidRootPart ~= nil and self.Humanoid ~= nil and self.Humanoid.Health > 0
end

function CharacterSystem:WaitForCharacter(timeout)
    timeout = timeout or 5
    local start = os.clock()
    while not self:IsAlive() do
        if os.clock() - start > timeout then return false end
        task.wait(0.2)
    end
    return true
end

function CharacterSystem:GetPosition()
    return self.HumanoidRootPart and self.HumanoidRootPart.Position or Vector3.zero
end

function CharacterSystem:TeleportTo(pos, safeDistance)
    if not self:IsAlive() then return false end
    pcall(function()
        self.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
        self.HumanoidRootPart.AssemblyAngularVelocity = Vector3.zero
        local targetPos = pos
        if safeDistance and safeDistance > 0 then
            targetPos = pos + Vector3.new(0, safeDistance, 0)
        end
        self.Character:PivotTo(CFrame.new(targetPos))
        task.wait(0.05)
        self.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
    end)
    return true
end

-- ==================== TASK MANAGER ====================
local TaskManager = {}
TaskManager.__index = TaskManager

function TaskManager.new(name)
    local self = setmetatable({}, TaskManager)
    self.Name = name or "Task"
    self.Token = nil
    self.Thread = nil
    return self
end

function TaskManager:IsRunning()
    return self.Token ~= nil
end

function TaskManager:Start(func, ...)
    self:Stop()
    self.Token = {}
    local token = self.Token
    self.Thread = task.spawn(function()
        local ok, err = pcall(func, token, ...)
        if not ok then
            warn("[TaskManager] Erro em", self.Name, ":", err)
        end
        if self.Token == token then
            self.Token = nil
            self.Thread = nil
        end
    end)
end

function TaskManager:Stop()
    if self.Token then
        self.Token = nil
        self.Thread = nil
    end
end

-- ==================== UTILITY FUNCTIONS ====================
local Utility = {}

function Utility.IsAliveModel(model, checkHumanoid)
    if not model or not model:IsA("Model") then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end
    if checkHumanoid and hum.Health <= 0 then return false end
    return true
end

function Utility.IsNPC(model)
    return Utility.IsAliveModel(model) and not Players:GetPlayerFromCharacter(model)
end

function Utility.GetClosestPlayer(maxDist)
    local char = CharacterSystemInstance
    if not char:IsAlive() then return nil end
    local closest, minDist = nil, maxDist or math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            local hrp = plr.Character.HumanoidRootPart
            local dist = (hrp.Position - char:GetPosition()).Magnitude
            if dist < minDist then
                minDist = dist
                closest = plr
            end
        end
    end
    return closest
end

function Utility.GetClosestEnemy(maxDist, filterFunc)
    local char = CharacterSystemInstance
    if not char:IsAlive() then return nil end
    local closest, minDist = nil, maxDist or math.huge
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model ~= char.Character and Utility.IsNPC(model) then
            if filterFunc and not filterFunc(model) then continue end
            local hrp = model.HumanoidRootPart
            local dist = (hrp.Position - char:GetPosition()).Magnitude
            if dist < minDist then
                minDist = dist
                closest = model
            end
        end
    end
    return closest
end

-- ==================== COMBAT SYSTEM ====================
local CombatSystem = {}

function CombatSystem.EquipBestWeapon()
    local char = CharacterSystemInstance
    if not char:IsAlive() then return nil end
    local backpack = player.Backpack
    local currentTool = char.Character:FindFirstChildOfClass("Tool")
    if currentTool then
        return currentTool
    end
    local bestTool = nil
    local bestScore = -1
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local score = 0
            if tool:FindFirstChild("Melee") or tool.Name:lower():find("combat") then score = 3
            elseif tool:FindFirstChild("Sword") then score = 2
            elseif tool:FindFirstChild("Fruit") then score = 1
            end
            if score > bestScore then
                bestScore = score
                bestTool = tool
            end
        end
    end
    if bestTool then
        char.Humanoid:EquipTool(bestTool)
        return bestTool
    end
    return nil
end

function CombatSystem.AttackTarget(target)
    local char = CharacterSystemInstance
    if not char:IsAlive() or not target or not target:IsA("Model") then return end
    local tool = CombatSystem.EquipBestWeapon()
    if tool then
        pcall(function()
            tool:Activate()
        end)
    end
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

-- ==================== QUEST SYSTEM ====================
local QuestSystem = {}
QuestSystem.__index = QuestSystem

local QuestData = {
    [1] = {
        { Level = 0, NPC = "Bandit", QuestName = "BanditQuest1", QuestID = 1 },
        { Level = 10, NPC = "Monkey", QuestName = "MonkeyQuest1", QuestID = 2 },
        { Level = 15, NPC = "Pirate", QuestName = "PirateQuest1", QuestID = 3 },
        { Level = 20, NPC = "Brute", QuestName = "BruteQuest1", QuestID = 4 },
        { Level = 30, NPC = "Desert Bandit", QuestName = "DesertBanditQuest1", QuestID = 5 },
    },
    [2] = {
        { Level = 700, NPC = "Raider", QuestName = "RaiderQuest1", QuestID = 101 },
        { Level = 750, NPC = "Mercenary", QuestName = "MercenaryQuest1", QuestID = 102 },
    },
    [3] = {
        { Level = 1500, NPC = "Pirate Millionaire", QuestName = "PirateMillionaireQuest1", QuestID = 201 },
    },
}

function QuestSystem.new()
    local self = setmetatable({}, QuestSystem)
    self.CurrentQuest = nil
    self.QuestRemote = nil
    self:InitRemotes()
    return self
end

function QuestSystem:InitRemotes()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        self.QuestRemote = remotes:FindFirstChild("CommF_")
    end
end

function QuestSystem:GetSea()
    local char = CharacterSystemInstance
    if not char:IsAlive() then return 1 end
    local pos = char:GetPosition()
    if pos.Y > 1000 then return 3 end
    if pos.Magnitude > 10000 then return 3 end
    if pos.X < -5000 and pos.Z < 5000 and pos.Y < 500 then return 2 end
    if pos.X < -10000 then return 3 end
    return 1
end

function QuestSystem:GetLevel()
    if not CharacterSystemInstance:IsAlive() then return 0 end
    return CharacterSystemInstance.Humanoid.Level or 0
end

function QuestSystem:FindAppropriateQuest()
    local sea = self:GetSea()
    local level = self:GetLevel()
    local questList = QuestData[sea] or {}
    local bestQuest = nil
    for _, q in ipairs(questList) do
        if q.Level <= level then
            bestQuest = q
        else
            break
        end
    end
    return bestQuest
end

function QuestSystem:GetCurrentQuestRemote()
    if not self.QuestRemote then return nil end
    local ok, current = pcall(function()
        return self.QuestRemote:InvokeServer("GetQuestData")
    end)
    if ok and current and current ~= "" then
        return current
    end
    return nil
end

function QuestSystem:AbandonCurrentQuest()
    if self.QuestRemote then
        pcall(function()
            self.QuestRemote:InvokeServer("AbandonQuest")
        end)
    end
end

function QuestSystem:StartQuest(questData)
    if not questData or not self.QuestRemote then return false end
    local ok, err = pcall(function()
        self.QuestRemote:InvokeServer("StartQuest", questData.QuestName, questData.QuestID)
    end)
    return ok
end

function QuestSystem:GetQuestNPC(questData)
    if not questData then return nil end
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and Utility.IsNPC(model) then
            local npcName = model.Name
            if npcName:lower():find(questData.NPC:lower()) then
                return model
            end
        end
    end
    return nil
end

function QuestSystem:IsQuestCompleted()
    if not self.QuestRemote then return false end
    local ok, completed = pcall(function()
        return self.QuestRemote:InvokeServer("CheckQuestCompleted")
    end)
    return ok and completed
end

-- ==================== MOB SYSTEM ====================
local MobSystem = {}

function MobSystem.GetMobName(model)
    return model and model.Name or "Unknown"
end

function MobSystem.IsMobForQuest(model, questData)
    if not questData then return false end
    local mobName = MobSystem.GetMobName(model)
    return mobName:lower():find(questData.NPC:lower()) ~= nil
end

function MobSystem.GetClosestMobForQuest(questData, maxDist)
    return Utility.GetClosestEnemy(maxDist, function(model)
        return MobSystem.IsMobForQuest(model, questData)
    end)
end

-- ==================== BOSS SYSTEM ====================
local BossSystem = {}

local BossList = {
    { Name = "Gorilla King", Sea = 1, ModelName = "Gorilla King", Level = 25 },
    { Name = "Bobby", Sea = 1, ModelName = "Bobby", Level = 55 },
    { Name = "Yeti", Sea = 1, ModelName = "Yeti", Level = 105 },
    { Name = "Mob Leader", Sea = 1, ModelName = "Mob Leader", Level = 120 },
    { Name = "Vice Admiral", Sea = 1, ModelName = "Vice Admiral", Level = 130 },
    { Name = "Diamond", Sea = 2, ModelName = "Diamond", Level = 750 },
    { Name = "Jeremy", Sea = 2, ModelName = "Jeremy", Level = 850 },
    { Name = "Fajita", Sea = 2, ModelName = "Fajita", Level = 900 },
    { Name = "Don Swan", Sea = 2, ModelName = "Don Swan", Level = 1000 },
    { Name = "Smoke Admiral", Sea = 2, ModelName = "Smoke Admiral", Level = 1150 },
    { Name = "Stone", Sea = 3, ModelName = "Stone", Level = 1500 },
    { Name = "Island Empress", Sea = 3, ModelName = "Island Empress", Level = 1600 },
    { Name = "Kilo Admiral", Sea = 3, ModelName = "Kilo Admiral", Level = 1750 },
    { Name = "Captain Elephant", Sea = 3, ModelName = "Captain Elephant", Level = 1900 },
    { Name = "Beautiful Pirate", Sea = 3, ModelName = "Beautiful Pirate", Level = 2000 },
}

function BossSystem.GetBossByName(name)
    for _, boss in ipairs(BossList) do
        if boss.Name:lower() == name:lower() then
            return boss
        end
    end
    return nil
end

function BossSystem.FindBossModel(bossData)
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model.Name:lower() == bossData.ModelName:lower() then
            if Utility.IsAliveModel(model) then
                return model
            end
        end
    end
    return nil
end

-- ==================== AUTO FARM SYSTEM ====================
local AutoFarm = {}
AutoFarm.__index = AutoFarm

function AutoFarm.new()
    local self = setmetatable({}, AutoFarm)
    self.TaskManager = TaskManager.new("AutoFarm")
    self.QuestSystem = QuestSystem.new()
    return self
end

function AutoFarm:Start()
    if self.TaskManager:IsRunning() then return end
    self.TaskManager:Start(function(token)
        while token == self.TaskManager.Token and Config.AutoFarm do
            if not CharacterSystemInstance:WaitForCharacter(2) then task.wait(1); continue end

            local targetQuest = self.QuestSystem:FindAppropriateQuest()
            if not targetQuest then
                task.wait(2)
                continue
            end

            local currentQuest = self.QuestSystem:GetCurrentQuestRemote()
            if currentQuest ~= targetQuest.QuestName then
                self.QuestSystem:AbandonCurrentQuest()
                self.QuestSystem:StartQuest(targetQuest)
                task.wait(1)
            end

            local npc = self.QuestSystem:GetQuestNPC(targetQuest)
            if npc then
                local npcHRP = npc:FindFirstChild("HumanoidRootPart")
                if npcHRP then
                    CharacterSystemInstance:TeleportTo(npcHRP.Position, Config.FarmSafeDistance)
                    task.wait(0.5)
                    pcall(function()
                        if npc:FindFirstChild("ProximityPrompt") then
                            fireproximityprompt(npc.ProximityPrompt)
                        end
                    end)
                    task.wait(0.5)
                end
            end

            while Config.AutoFarm and CharacterSystemInstance:IsAlive() do
                if self.QuestSystem:IsQuestCompleted() then break end

                local target = nil
                if Config.SelectedMob == "Lowest Level Mob" then
                    target = MobSystem.GetClosestMobForQuest(targetQuest, 300)
                else
                    target = Utility.GetClosestEnemy(300, function(model)
                        return model.Name:lower() == Config.SelectedMob:lower()
                    end)
                end

                if target then
                    local targetHRP = target:FindFirstChild("HumanoidRootPart")
                    if targetHRP then
                        CharacterSystemInstance:TeleportTo(targetHRP.Position, Config.FarmSafeDistance)
                        task.wait(0.1)
                        for _ = 1, 5 do
                            if not Config.AutoFarm then break end
                            CombatSystem.AttackTarget(target)
                            task.wait(0.15)
                        end
                    end
                else
                    task.wait(0.5)
                end
                task.wait(0.2)
            end

            task.wait(0.5)
        end
    end)
end

function AutoFarm:Stop()
    self.TaskManager:Stop()
end

-- ==================== BOSS FARM SYSTEM ====================
local BossFarm = {}
BossFarm.__index = BossFarm

function BossFarm.new()
    local self = setmetatable({}, BossFarm)
    self.TaskManager = TaskManager.new("BossFarm")
    return self
end

function BossFarm:Start()
    if self.TaskManager:IsRunning() then return end
    self.TaskManager:Start(function(token)
        while token == self.TaskManager.Token and Config.AutoFarmBoss do
            if not CharacterSystemInstance:IsAlive() then task.wait(1); continue end
            local bossData = BossSystem.GetBossByName(Config.SelectedBoss)
            if not bossData then task.wait(2); continue end

            local bossModel = BossSystem.FindBossModel(bossData)
            if not bossModel then
                task.wait(5)
                continue
            end

            local bossHRP = bossModel:FindFirstChild("HumanoidRootPart")
            if bossHRP then
                CharacterSystemInstance:TeleportTo(bossHRP.Position, Config.FarmSafeDistance)
                task.wait(0.1)
                while Config.AutoFarmBoss and CharacterSystemInstance:IsAlive() do
                    if not BossSystem.FindBossModel(bossData) then break end
                    if bossModel:FindFirstChild("Humanoid") and bossModel.Humanoid.Health <= 0 then break end
                    CombatSystem.AttackTarget(bossModel)
                    task.wait(0.15)
                end
                task.wait(2)
            end
        end
    end)
end

function BossFarm:Stop()
    self.TaskManager:Stop()
end

-- ==================== AUTO STATS SYSTEM ====================
local AutoStatsSystem = {}
AutoStatsSystem.__index = AutoStatsSystem

function AutoStatsSystem.new()
    local self = setmetatable({}, AutoStatsSystem)
    self.TaskManager = TaskManager.new("AutoStats")
    self.StatRemote = nil
    self:InitRemote()
    return self
end

function AutoStatsSystem:InitRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        self.StatRemote = remotes:FindFirstChild("CommF_")
    end
end

function AutoStatsSystem:GetAvailablePoints()
    if not CharacterSystemInstance:IsAlive() then return 0 end
    return CharacterSystemInstance.Humanoid:GetAttribute("StatPoints") or 0
end

function AutoStatsSystem:DistributePoints(stat)
    if not self.StatRemote then return false end
    local success = pcall(function()
        self.StatRemote:InvokeServer("AddPoint", stat)
    end)
    return success
end

function AutoStatsSystem:Start()
    if self.TaskManager:IsRunning() then return end
    self.TaskManager:Start(function(token)
        while token == self.TaskManager.Token and Config.AutoStats do
            if CharacterSystemInstance:IsAlive() then
                local points = self:GetAvailablePoints()
                while points > 0 and Config.AutoStats do
                    local stat = Config.SelectedStat or "Melee"
                    if not self:DistributePoints(stat) then break end
                    points = points - 1
                    task.wait(0.05)
                end
            end
            task.wait(2)
        end
    end)
end

function AutoStatsSystem:Stop()
    self.TaskManager:Stop()
end

-- ==================== AUTO CHEST SYSTEM ====================
local AutoChest = {}
AutoChest.__index = AutoChest

function AutoChest.new()
    local self = setmetatable({}, AutoChest)
    self.TaskManager = TaskManager.new("AutoChest")
    return self
end

function AutoChest:FindChest()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if not obj:IsA("Model") then continue end
        local name = obj.Name:lower()
        if name:find("chest") or name:find("treasure") or name:find("box") then
            local pp = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("BasePart")
            if pp then
                return obj, pp
            end
        end
    end
    return nil, nil
end

function AutoChest:Start()
    if self.TaskManager:IsRunning() then return end
    self.TaskManager:Start(function(token)
        while token == self.TaskManager.Token and Config.AutoCollectChest do
            if CharacterSystemInstance:IsAlive() then
                local chest, part = self:FindChest()
                if chest and part then
                    CharacterSystemInstance:TeleportTo(part.Position, 3)
                    task.wait(0.5)
                    pcall(function()
                        if part.Parent and part.Parent:FindFirstChild("ProximityPrompt") then
                            fireproximityprompt(part.Parent.ProximityPrompt)
                        end
                    end)
                    task.wait(1)
                end
            end
            task.wait(2)
        end
    end)
end

function AutoChest:Stop()
    self.TaskManager:Stop()
end

-- ==================== AIMBOT SYSTEM ====================
local Aimbot = {}
Aimbot.__index = Aimbot

function Aimbot.new()
    local self = setmetatable({}, Aimbot)
    self.Connection = nil
    self.Target = nil
    return self
end

function Aimbot:Start()
    self:Stop()
    self.Connection = RunService.RenderStepped:Connect(function()
        if not Config.AimbotPvP then
            self:Stop()
            return
        end
        if not CharacterSystemInstance:IsAlive() then return end
        local target = Utility.GetClosestPlayer(Config.AimFOV)
        if target and target.Character and target.Character:FindFirstChild("Head") then
            local head = target.Character.Head
            camera.CFrame = CFrame.new(camera.CFrame.Position, head.Position)
            self.Target = target
        else
            self.Target = nil
        end
    end)
end

function Aimbot:Stop()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

-- ==================== FRUIT SNIPER SYSTEM ====================
local FruitSniper = {}
FruitSniper.__index = FruitSniper

function FruitSniper.new()
    local self = setmetatable({}, FruitSniper)
    self.TaskManager = TaskManager.new("FruitSniper")
    return self
end

function FruitSniper:FindRealFruit()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("fruit") then
            local pp = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
            if pp and obj:FindFirstChild("ProximityPrompt") then
                return obj, pp
            end
        end
    end
    return nil, nil
end

function FruitSniper:Start()
    if self.TaskManager:IsRunning() then return end
    self.TaskManager:Start(function(token)
        while token == self.TaskManager.Token and Config.FruitSniper do
            if CharacterSystemInstance:IsAlive() then
                local fruit, part = self:FindRealFruit()
                if fruit and part then
                    CharacterSystemInstance:TeleportTo(part.Position, 3)
                    task.wait(0.3)
                    pcall(function()
                        if part.Parent and part.Parent:FindFirstChild("ProximityPrompt") then
                            fireproximityprompt(part.Parent.ProximityPrompt)
                        end
                    end)
                    task.wait(1)
                end
            end
            task.wait(2)
        end
    end)
end

function FruitSniper:Stop()
    self.TaskManager:Stop()
end

-- ==================== AUTO RAID SYSTEM ====================
local AutoRaidSystem = {}
AutoRaidSystem.__index = AutoRaidSystem

function AutoRaidSystem.new()
    local self = setmetatable({}, AutoRaidSystem)
    self.TaskManager = TaskManager.new("AutoRaid")
    self.RaidRemote = nil
    self:InitRemote()
    return self
end

function AutoRaidSystem:InitRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        self.RaidRemote = remotes:FindFirstChild("Raid") or remotes:FindFirstChild("StartRaid")
    end
end

function AutoRaidSystem:Start()
    if self.TaskManager:IsRunning() then return end
    self.TaskManager:Start(function(token)
        while token == self.TaskManager.Token and Config.AutoRaid do
            if CharacterSystemInstance:IsAlive() then
                local sea = QuestSystemInstance:GetSea()
                if sea == 1 then
                    CharacterSystemInstance:TeleportTo(Vector3.new(-5000, 10, -2000))
                elseif sea == 2 then
                    CharacterSystemInstance:TeleportTo(Vector3.new(-3000, 20, 5000))
                elseif sea == 3 then
                    CharacterSystemInstance:TeleportTo(Vector3.new(-12000, 300, 8000))
                end
                task.wait(2)
                if self.RaidRemote then
                    pcall(function()
                        self.RaidRemote:FireServer()
                    end)
                end
                task.wait(5)
                while Config.AutoRaid and CharacterSystemInstance:IsAlive() do
                    local enemy = Utility.GetClosestEnemy(100)
                    if enemy then
                        local hrp = enemy:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            CharacterSystemInstance:TeleportTo(hrp.Position, Config.FarmSafeDistance)
                            task.wait(0.1)
                            for _ = 1, 10 do
                                if not Config.AutoRaid then break end
                                CombatSystem.AttackTarget(enemy)
                                task.wait(0.1)
                            end
                        end
                    else
                        task.wait(0.5)
                    end
                    task.wait(1)
                end
            end
            task.wait(5)
        end
    end)
end

function AutoRaidSystem:Stop()
    self.TaskManager:Stop()
end

-- ==================== PLAYER ESP SYSTEM ====================
local PlayerESP = {}
PlayerESP.__index = PlayerESP

function PlayerESP.new()
    local self = setmetatable({}, PlayerESP)
    self.Objects = {}
    self.UpdateConnection = nil
    return self
end

function PlayerESP:CreateESP(plr)
    if self.Objects[plr] then return end
    local char = plr.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_" .. plr.Name
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = Workspace

    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(100, 0, 0)
    label.TextStrokeTransparency = 0.2
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Text = plr.Name .. " • " .. math.floor((hrp.Position - CharacterSystemInstance:GetPosition()).Magnitude) .. " studs"

    self.Objects[plr] = {
        Billboard = billboard,
        Label = label,
        HRP = hrp
    }

    task.spawn(function()
        while self.Objects[plr] do
            if not plr.Parent or not plr.Character or plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health <= 0 then
                self:RemoveESP(plr)
                break
            end
            local currentHRP = plr.Character:FindFirstChild("HumanoidRootPart")
            if currentHRP then
                local dist = math.floor((currentHRP.Position - CharacterSystemInstance:GetPosition()).Magnitude)
                label.Text = plr.Name .. " • " .. dist .. " studs"
            end
            task.wait(0.5)
        end
    end)
end

function PlayerESP:RemoveESP(plr)
    if self.Objects[plr] then
        pcall(function()
            self.Objects[plr].Billboard:Destroy()
        end)
        self.Objects[plr] = nil
    end
end

function PlayerESP:ClearAll()
    for plr, _ in pairs(self.Objects) do
        self:RemoveESP(plr)
    end
end

function PlayerESP:Update()
    self:ClearAll()
    if not Config.PlayerESP then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            self:CreateESP(plr)
        end
    end
end

function PlayerESP:Start()
    self:Update()
    self.UpdateConnection = RunService.Heartbeat:Connect(function()
        if not Config.PlayerESP then
            self:Stop()
            return
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and not self.Objects[plr] then
                self:CreateESP(plr)
            end
        end
    end)
end

function PlayerESP:Stop()
    if self.UpdateConnection then
        self.UpdateConnection:Disconnect()
        self.UpdateConnection = nil
    end
    self:ClearAll()
end

-- ==================== FRUIT ESP SYSTEM ====================
local FruitESP = {}
FruitESP.__index = FruitESP

function FruitESP.new()
    local self = setmetatable({}, FruitESP)
    self.Objects = {}
    self.UpdateConnection = nil
    return self
end

function FruitESP:CreateFruitESP(model)
    if self.Objects[model] then return end
    local part = model.PrimaryPart or model:FindFirstChildOfClass("BasePart")
    if not part then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "FruitESP_" .. model.Name
    billboard.Adornee = part
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = Workspace

    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(100, 0, 0)
    label.TextStrokeTransparency = 0.2
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.Text = model.Name .. " • " .. math.floor((part.Position - CharacterSystemInstance:GetPosition()).Magnitude) .. " studs"

    self.Objects[model] = {
        Billboard = billboard,
        Label = label,
        Part = part
    }

    task.spawn(function()
        while self.Objects[model] do
            if not model.Parent then
                self:RemoveFruitESP(model)
                break
            end
            local currentPart = model.PrimaryPart or model:FindFirstChildOfClass("BasePart")
            if currentPart then
                local dist = math.floor((currentPart.Position - CharacterSystemInstance:GetPosition()).Magnitude)
                label.Text = model.Name .. " • " .. dist .. " studs"
            end
            task.wait(0.5)
        end
    end)
end

function FruitESP:RemoveFruitESP(model)
    if self.Objects[model] then
        pcall(function()
            self.Objects[model].Billboard:Destroy()
        end)
        self.Objects[model] = nil
    end
end

function FruitESP:ClearAll()
    for model, _ in pairs(self.Objects) do
        self:RemoveFruitESP(model)
    end
end

function FruitESP:Update()
    self:ClearAll()
    if not Config.FruitESP then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("fruit") and obj:FindFirstChild("ProximityPrompt") then
            self:CreateFruitESP(obj)
        end
    end
end

function FruitESP:Start()
    self:Update()
    self.UpdateConnection = RunService.Heartbeat:Connect(function()
        if not Config.FruitESP then
            self:Stop()
            return
        end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name:lower():find("fruit") and obj:FindFirstChild("ProximityPrompt") and not self.Objects[obj] then
                self:CreateFruitESP(obj)
            end
        end
    end)
end

function FruitESP:Stop()
    if self.UpdateConnection then
        self.UpdateConnection:Disconnect()
        self.UpdateConnection = nil
    end
    self:ClearAll()
end

-- ==================== SERVER HOP SYSTEM ====================
local ServerHopSystem = {}
ServerHopSystem.__index = ServerHopSystem

function ServerHopSystem.new()
    local self = setmetatable({}, ServerHopSystem)
    self.TaskManager = TaskManager.new("ServerHop")
    return self
end

function ServerHopSystem:FindServer()
    local success, servers = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
        )
    end)
    if success and servers and servers.data then
        for _, server in ipairs(servers.data) do
            if server.id ~= game.JobId and server.playing < server.maxPlayers then
                return server.id
            end
        end
    end
    return nil
end

function ServerHopSystem:Hop()
    local serverId = self:FindServer()
    if serverId then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId)
    end
end

function ServerHopSystem:Start()
    if self.TaskManager:IsRunning() then return end
    self.TaskManager:Start(function(token)
        while token == self.TaskManager.Token and Config.ServerHop do
            self:Hop()
            task.wait(30)
        end
    end)
end

function ServerHopSystem:Stop()
    self.TaskManager:Stop()
end

-- ==================== AUTO REVIVE (Recovery) ====================
local AutoReviveSystem = {}
AutoReviveSystem.__index = AutoReviveSystem

function AutoReviveSystem.new()
    local self = setmetatable({}, AutoReviveSystem)
    self.Connection = nil
    return self
end

function AutoReviveSystem:Start()
    self:Stop()
    self.Connection = player.CharacterAdded:Connect(function(char)
        if not Config.AutoRevive then return end
        task.wait(1)
        if not CharacterSystemInstance:IsAlive() then return end
        if Config.AutoFarm then AutoFarmInstance:Start() end
        if Config.AutoFarmBoss then BossFarmInstance:Start() end
        if Config.AutoCollectChest then AutoChestInstance:Start() end
        if Config.AutoStats then AutoStatsInstance:Start() end
        if Config.FruitSniper then FruitSniperInstance:Start() end
        if Config.AutoRaid then AutoRaidInstance:Start() end
        if Config.PlayerESP then PlayerESPInstance:Start() end
        if Config.FruitESP then FruitESPInstance:Start() end
    end)
end

function AutoReviveSystem:Stop()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

-- ==================== TELEPORT SYSTEM ====================
local TeleportSystem = {}
TeleportSystem.__index = TeleportSystem

TeleportSystem.Locations = {
    -- First Sea
    { Name = "Middle Town", Sea = 1, Position = Vector3.new(-700, 15, 1300) },
    { Name = "Jungle", Sea = 1, Position = Vector3.new(-2100, 15, -120) },
    { Name = "Pirate Village", Sea = 1, Position = Vector3.new(-1500, 15, 200) },
    { Name = "Desert", Sea = 1, Position = Vector3.new(900, 15, 1000) },
    { Name = "Frozen Village", Sea = 1, Position = Vector3.new(1200, 15, -1000) },
    { Name = "Marine Fortress", Sea = 1, Position = Vector3.new(975, 15, 1596) },
    { Name = "Skylands", Sea = 1, Position = Vector3.new(-5000, 1000, -200) },
    { Name = "Prison", Sea = 1, Position = Vector3.new(3000, 15, -2000) },
    { Name = "Colosseum", Sea = 1, Position = Vector3.new(1000, 15, 3000) },
    { Name = "Magma Village", Sea = 1, Position = Vector3.new(2000, 15, 2000) },
    { Name = "Underwater City", Sea = 1, Position = Vector3.new(-3000, -100, 3000) },
    { Name = "Fountain City", Sea = 1, Position = Vector3.new(-5000, 15, 3000) },

    -- Second Sea
    { Name = "Kingdom of Rose", Sea = 2, Position = Vector3.new(-2600, 15, -830) },
    { Name = "Green Zone", Sea = 2, Position = Vector3.new(-1060, 15, -4360) },
    { Name = "Graveyard", Sea = 2, Position = Vector3.new(-2000, 15, -3000) },
    { Name = "Snow Mountain", Sea = 2, Position = Vector3.new(1660, 15, 570) },
    { Name = "Hot and Cold", Sea = 2, Position = Vector3.new(1000, 15, 1000) },
    { Name = "Cursed Ship", Sea = 2, Position = Vector3.new(500, 15, -2000) },
    { Name = "Ice Castle", Sea = 2, Position = Vector3.new(3000, 15, 3000) },
    { Name = "Forgotten Island", Sea = 2, Position = Vector3.new(-4200, 15, -400) },
    { Name = "Café", Sea = 2, Position = Vector3.new(-2500, 15, -1000) },

    -- Third Sea
    { Name = "Port Town", Sea = 3, Position = Vector3.new(-2640, 72, -3735) },
    { Name = "Hydra Island", Sea = 3, Position = Vector3.new(4700, 350, 8600) },
    { Name = "Great Tree", Sea = 3, Position = Vector3.new(-14150, 250, -6025) },
    { Name = "Floating Turtle", Sea = 3, Position = Vector3.new(-11950, 800, -6025) },
    { Name = "Haunted Castle", Sea = 3, Position = Vector3.new(-6700, 250, 8200) },
    { Name = "Sea of Treats", Sea = 3, Position = Vector3.new(1000, 200, 3000) },
    { Name = "Tiki Outpost", Sea = 3, Position = Vector3.new(5000, 200, 5000) },
    { Name = "Castle on the Sea", Sea = 3, Position = Vector3.new(-6700, 250, 8200) },
}

function TeleportSystem:Teleport(location)
    if not location then return end
    CharacterSystemInstance:TeleportTo(location.Position)
end

-- ==================== INSTANCIAÇÃO DOS SISTEMAS ====================
local CharacterSystemInstance = CharacterSystem.new()
local QuestSystemInstance = QuestSystem.new()
local AutoFarmInstance = AutoFarm.new()
local BossFarmInstance = BossFarm.new()
local AutoStatsInstance = AutoStatsSystem.new()
local AutoChestInstance = AutoChest.new()
local AimbotInstance = Aimbot.new()
local FruitSniperInstance = FruitSniper.new()
local AutoRaidInstance = AutoRaidSystem.new()
local PlayerESPInstance = PlayerESP.new()
local FruitESPInstance = FruitESP.new()
local ServerHopInstance = ServerHopSystem.new()
local AutoReviveInstance = AutoReviveSystem.new()

-- ==================== UI SYSTEM ====================
local UI_TEXT = {
    SearchPlaceholder = "Pesquisar...",
    ConfirmCloseTitle = "Deseja fechar o script?",
    ConfirmBtn = "Confirmar",
    CancelBtn = "Cancelar",
    Intro = '<font color="#FFFFFF">Blox Fruits | </font><font color="#8B0000">AKATSUKI</font>',
    Tabs = {
        AutoFarm   = "Auto Farm",
        PvP        = "PvP",
        Raids      = "Raids",
        Teleports  = "Teleportes",
        Settings   = "Extras",
    },
    Options = {
        AutoFarm        = { Title = "Auto Farm",          Desc = "Flutua sobre mobs e ataca até a morte." },
        AutoFarmBoss    = { Title = "Auto Boss Farm",     Desc = "Vai até o boss e ataca automaticamente." },
        AutoCollectChest= { Title = "Auto Chest",         Desc = "Coleta baús e drops no mapa automaticamente." },
        AutoStats       = { Title = "Auto Stats",         Desc = "Distribui atributos automaticamente ao upar." },
        AimbotPvP       = { Title = "Aimbot PvP",         Desc = "Mira na cabeça de jogadores próximos." },
        FruitSniper     = { Title = "Fruit Sniper",       Desc = "Teleporta até frutas que caem no mapa." },
        AutoRaid        = { Title = "Auto Raid",          Desc = "Inicia e completa raids automaticamente." },
        PlayerESP       = { Title = "Player ESP",         Desc = "Mostra o nome colorido de todos no mapa." },
        FruitESP        = { Title = "Fruit ESP",          Desc = "Mostra frutas spawnadas no mapa." },
        AutoRevive      = { Title = "Auto Revive",        Desc = "Reinicia farms automaticamente após morrer." },
        ServerHop       = { Title = "Server Hop",         Desc = "Troca de servidor automaticamente (menos players)." },
    }
}

local UIState = "CLOSED"
local activeTab = "AutoFarm"
local tabButtons = {}
local isExpanded = false
local originalTrans = {}
local confirmBlur = nil
local isConfirmOpen = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BloxFruitsAkatUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then uiParent = gethui() else pcall(function() uiParent = game:GetService("CoreGui") end) end
if uiParent:FindFirstChild("BloxFruitsAkatUI") then pcall(function() uiParent.BloxFruitsAkatUI:Destroy() end) end
screenGui.Parent = uiParent

local SharedClickSound = Instance.new("Sound", screenGui)
SharedClickSound.SoundId = "rbxassetid://6895079853"
SharedClickSound.Volume = 0.6
SharedClickSound.Looped = false

local function PlayUI_Click()
    pcall(function() SharedClickSound.TimePosition = 0; SharedClickSound:Play() end)
end

local function RegistrarTransparencias(objeto)
    if originalTrans[objeto] then return end
    if objeto:IsA("Frame") or objeto:IsA("ScrollingFrame") or objeto:IsA("CanvasGroup") then
        originalTrans[objeto] = { BackgroundTransparency = objeto.BackgroundTransparency }
    elseif objeto:IsA("TextLabel") or objeto:IsA("TextButton") or objeto:IsA("TextBox") then
        originalTrans[objeto] = { TextTransparency = objeto.TextTransparency, BackgroundTransparency = objeto.BackgroundTransparency, TextStrokeTransparency = objeto.TextStrokeTransparency or 1 }
    elseif objeto:IsA("ImageLabel") or objeto:IsA("ImageButton") then
        originalTrans[objeto] = { ImageTransparency = objeto.ImageTransparency, BackgroundTransparency = objeto.BackgroundTransparency }
    elseif objeto:IsA("UIStroke") then
        originalTrans[objeto] = { Transparency = objeto.Transparency }
    end
end

local function AplicarFadeSincronizado(raiz, fadeOut, duracao)
    local info = TweenInfo.new(duracao, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local function tratarObjeto(obj)
        RegistrarTransparencias(obj)
        local orig = originalTrans[obj]
        if not orig then return end
        if orig.BackgroundTransparency ~= nil then
            local t = fadeOut and 1 or orig.BackgroundTransparency
            if duracao == 0 then obj.BackgroundTransparency = t else TweenService:Create(obj, info, {BackgroundTransparency = t}):Play() end
        end
        if orig.TextTransparency ~= nil then
            local t = fadeOut and 1 or orig.TextTransparency
            if duracao == 0 then obj.TextTransparency = t else TweenService:Create(obj, info, {TextTransparency = t}):Play() end
        end
        if orig.ImageTransparency ~= nil then
            local t = fadeOut and 1 or orig.ImageTransparency
            if duracao == 0 then obj.ImageTransparency = t else TweenService:Create(obj, info, {ImageTransparency = t}):Play() end
        end
        if orig.Transparency ~= nil then
            local t = fadeOut and 1 or orig.Transparency
            if duracao == 0 then obj.Transparency = t else TweenService:Create(obj, info, {Transparency = t}):Play() end
        end
    end
    tratarObjeto(raiz)
    for _, desc in ipairs(raiz:GetDescendants()) do tratarObjeto(desc) end
end

-- ==================== BOTÃO FLUTUANTE ====================
local FloatBtn = Instance.new("ImageButton", screenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0.12, 0, 0.4, 0)
FloatBtn.Image = "rbxthumb://type=Asset&id=139044062702391&w=150&h=150"
FloatBtn.BackgroundColor3 = Color3.fromRGB(15, 0, 0)
FloatBtn.Visible = true
FloatBtn.ZIndex = 100
FloatBtn.ClipsDescendants = false
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)

local FloatOpenSound = Instance.new("Sound", FloatBtn)
FloatOpenSound.SoundId = "rbxassetid://6310837681"
FloatOpenSound.Volume = 0.2
FloatOpenSound.Looped = false

task.spawn(function()
    pcall(function() ContentProvider:PreloadAsync({FloatOpenSound, SharedClickSound}) end)
end)

local dragToggle, dragStart, startPos, isDragging = false, nil, nil, false

FloatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragToggle = true; isDragging = false
        dragStart = input.Position; startPos = FloatBtn.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        if delta.Magnitude > 5 then isDragging = true end
        FloatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local SetUIState
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if dragToggle and not isDragging then
            if UIState == "MINIMIZED" or UIState == "CLOSED" then
                pcall(function() FloatOpenSound.TimePosition = 0; FloatOpenSound:Play() end)
                SetUIState("OPEN")
            elseif UIState == "OPEN" then
                SetUIState("MINIMIZED")
            end
        end
        dragToggle = false
    end
end)

-- ==================== MAIN WRAPPER ====================
local mainWrapper = Instance.new("Frame", screenGui)
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0.5)
mainWrapper.Size = UDim2.new(0, 640, 0, 360)
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible = false
mainWrapper.ClipsDescendants = false
mainWrapper.ZIndex = 1

local mainFrame = Instance.new("Frame", mainWrapper)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.ZIndex = 2
mainFrame.ClipsDescendants = false

local dragUIToggle, dragUIStart, startUIPos
mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragUIToggle = true; dragUIStart = input.Position; startUIPos = mainWrapper.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragUIToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragUIStart
        mainWrapper.Position = UDim2.new(startUIPos.X.Scale, startUIPos.X.Offset + delta.X, startUIPos.Y.Scale, startUIPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragUIToggle = false end
end)

-- ==================== GRADIENT PANELS ====================
local function CreateGradientPanel(parent, size, pos, name)
    local panel = Instance.new("Frame", parent)
    panel.Name = name
    panel.Size = size
    panel.Position = pos
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ZIndex = 5
    panel.ClipsDescendants = false
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
    local outerStroke = Instance.new("UIStroke", panel)
    outerStroke.Name = "OuterStroke"
    outerStroke.Thickness = 2.5
    outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    outerStroke.Color = Color3.fromRGB(255, 255, 255)
    local outerGrad = Instance.new("UIGradient", outerStroke)
    outerGrad.Rotation = 45
    outerGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 20, 30))
    })
    local InnerBg = Instance.new("Frame", panel)
    InnerBg.Name = "InnerBg"
    InnerBg.Size = UDim2.new(1, 0, 1, 0)
    InnerBg.BackgroundColor3 = Color3.fromRGB(15, 0, 3)
    InnerBg.BackgroundTransparency = 0
    InnerBg.BorderSizePixel = 0
    InnerBg.ClipsDescendants = true
    InnerBg.ZIndex = 5
    Instance.new("UICorner", InnerBg).CornerRadius = UDim.new(0, 10)
    local overlay = Instance.new("Frame", InnerBg)
    overlay.Name = "RedGradientOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    overlay.BackgroundTransparency = 0
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 5
    Instance.new("UICorner", overlay).CornerRadius = UDim.new(0, 10)
    local redGrad = Instance.new("UIGradient", overlay)
    redGrad.Rotation = 90
    redGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 0, 5)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 20, 30))
    })
    RunService.RenderStepped:Connect(function()
        redGrad.Rotation = (os.clock() * 12) % 360
    end)
    return panel
end

local LeftPanel  = CreateGradientPanel(mainFrame, UDim2.new(0, 200, 1, 0), UDim2.new(0, 0, 0, 0), "LeftPanel")
local RightPanel = CreateGradientPanel(mainFrame, UDim2.new(1, -215, 1, 0), UDim2.new(0, 215, 0, 0), "RightPanel")

-- ==================== LEFT PANEL CONTENTS ====================
local LeftSeparatorLine = Instance.new("Frame", LeftPanel.InnerBg)
LeftSeparatorLine.Size = UDim2.new(1, 0, 0, 1)
LeftSeparatorLine.Position = UDim2.new(0, 0, 0, 36)
LeftSeparatorLine.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
LeftSeparatorLine.BackgroundTransparency = 0.5
LeftSeparatorLine.BorderSizePixel = 0
LeftSeparatorLine.ZIndex = 10

local HeaderLeft = Instance.new("Frame", LeftPanel.InnerBg)
HeaderLeft.Size = UDim2.new(1, 0, 0, 36)
HeaderLeft.Position = UDim2.new(0, 0, 0, 0)
HeaderLeft.BackgroundTransparency = 1
HeaderLeft.ZIndex = 10

local title = Instance.new("TextLabel", HeaderLeft)
title.Size = UDim2.new(1, 0, 0, 16)
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 4)
title.BackgroundTransparency = 1
title.Text = "AKATSUKI SCRIPTS"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Center
title.ZIndex = 11

local subtitle = Instance.new("TextLabel", HeaderLeft)
subtitle.Size = UDim2.new(1, 0, 0, 12)
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Position = UDim2.new(0.5, 0, 0, 20)
subtitle.BackgroundTransparency = 1
subtitle.Text = "BLOX FRUITS | by zeni <3"
subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
subtitle.TextTransparency = 0.2
subtitle.TextSize = 9.5
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Center
subtitle.ZIndex = 11

local TabsContainer = Instance.new("ScrollingFrame", LeftPanel.InnerBg)
TabsContainer.Name = "TabsContainer"
TabsContainer.Size = UDim2.new(1, -8, 1, -130)
TabsContainer.Position = UDim2.new(0, 4, 0, 44)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ZIndex = 10
TabsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
TabsContainer.ScrollBarThickness = 3
TabsContainer.ScrollBarImageColor3 = Color3.fromRGB(200, 50, 50)
TabsContainer.ScrollBarImageTransparency = 0.2
TabsContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

local TabsLayout = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabsLayout.Padding = UDim.new(0, 2)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function UpdateTabsCanvas()
    local contentH = TabsLayout.AbsoluteContentSize.Y + 8
    TabsContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(contentH, TabsContainer.AbsoluteSize.Y + 12))
end
TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabsCanvas)
TabsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTabsCanvas)

local UserProfileFrame = Instance.new("Frame", LeftPanel.InnerBg)
UserProfileFrame.Size = UDim2.new(1, -12, 0, 75)
UserProfileFrame.Position = UDim2.new(0, 6, 1, -81)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
UserProfileFrame.BackgroundTransparency = 0.5
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex = 10
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 8)
local userGrad = Instance.new("UIGradient", UserProfileFrame)
userGrad.Rotation = 45
userGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 20)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 5, 5))
})

local AvatarImage = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Size = UDim2.new(0, 50, 0, 50)
AvatarImage.Position = UDim2.new(0, 8, 0.5, -25)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex = 11
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

local DisplayNameLabel = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Size = UDim2.new(1, -94, 0, 16)
DisplayNameLabel.Position = UDim2.new(0, 64, 0.5, -18)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
DisplayNameLabel.Font = Enum.Font.GothamBold
DisplayNameLabel.TextSize = 11
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLabel.ZIndex = 11

local UsernameLabel = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Size = UDim2.new(1, -94, 0, 14)
UsernameLabel.Position = UDim2.new(0, 64, 0.5, 2)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text = "@" .. player.Name
UsernameLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
UsernameLabel.Font = Enum.Font.Gotham
UsernameLabel.TextSize = 10
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UsernameLabel.ZIndex = 11

local PrivacyBtn = Instance.new("ImageButton", UserProfileFrame)
PrivacyBtn.Size = UDim2.new(0, 24, 0, 24)
PrivacyBtn.Position = UDim2.new(1, -28, 0, 4)
PrivacyBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
PrivacyBtn.BackgroundTransparency = 0.4
PrivacyBtn.BorderSizePixel = 0
PrivacyBtn.ZIndex = 12
Instance.new("UICorner", PrivacyBtn).CornerRadius = UDim.new(0, 6)
local privGrad = Instance.new("UIGradient", PrivacyBtn)
privGrad.Rotation = 45
privGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0))
})
local PrivacyIcon = Instance.new("ImageLabel", PrivacyBtn)
PrivacyIcon.Size = UDim2.new(1, -6, 1, -6)
PrivacyIcon.Position = UDim2.new(0, 3, 0, 3)
PrivacyIcon.BackgroundTransparency = 1
PrivacyIcon.Image = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
PrivacyIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
PrivacyIcon.ZIndex = 13

local isPrivate = false
PrivacyBtn.MouseButton1Click:Connect(function()
    PlayUI_Click()
    isPrivate = not isPrivate
    if isPrivate then
        PrivacyIcon.Image = "rbxthumb://type=Asset&id=85795266774996&w=150&h=150"
        DisplayNameLabel.Text = string.rep("*", math.clamp(#player.DisplayName, 3, 8))
        UsernameLabel.Text = "@" .. string.rep("*", math.clamp(#player.Name, 3, 8))
    else
        PrivacyIcon.Image = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
        DisplayNameLabel.Text = player.DisplayName
        UsernameLabel.Text = "@" .. player.Name
    end
end)

-- ==================== RIGHT PANEL HEADER ====================
local topButtons = Instance.new("Frame", RightPanel.InnerBg)
topButtons.Size = UDim2.new(1, -12, 0, 36)
topButtons.Position = UDim2.new(0, 0, 0, 0)
topButtons.BackgroundTransparency = 1
topButtons.ZIndex = 10

local ControlsFrame = Instance.new("Frame", topButtons)
ControlsFrame.Size = UDim2.new(0, 120, 1, 0)
ControlsFrame.Position = UDim2.new(1, -120, 0, 0)
ControlsFrame.BackgroundTransparency = 1
ControlsFrame.ZIndex = 11

local UIListTop = Instance.new("UIListLayout", ControlsFrame)
UIListTop.FillDirection = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding = UDim.new(0, 5)
UIListTop.SortOrder = Enum.SortOrder.LayoutOrder

local function MakeControlBtn(order)
    local btn = Instance.new("TextButton", ControlsFrame)
    btn.LayoutOrder = order
    btn.Size = UDim2.new(0, 24, 0, 24)
    btn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    btn.BackgroundTransparency = 0.3
    btn.Text = ""
    btn.ZIndex = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    return btn
end

local SearchBtn = MakeControlBtn(1); SearchBtn.Name = "SearchBtn"; SearchBtn.ClipsDescendants = true
local searchCircleFrame = Instance.new("Frame", SearchBtn)
searchCircleFrame.Size = UDim2.new(0, 12, 0, 12); searchCircleFrame.AnchorPoint = Vector2.new(0, 0.5)
searchCircleFrame.Position = UDim2.new(0, 6, 0.5, 0); searchCircleFrame.BackgroundTransparency = 1; searchCircleFrame.ZIndex = 12
local searchCircleInner = Instance.new("Frame", searchCircleFrame)
searchCircleInner.Size = UDim2.new(0, 7, 0, 7); searchCircleInner.BackgroundTransparency = 1; searchCircleInner.ZIndex = 12
Instance.new("UICorner", searchCircleInner).CornerRadius = UDim.new(1, 0)
local circleStroke = Instance.new("UIStroke", searchCircleInner); circleStroke.Color = Color3.fromHex("#A0A0A0"); circleStroke.Thickness = 1
local searchHandle = Instance.new("Frame", searchCircleFrame)
searchHandle.Size = UDim2.new(0, 1, 0, 4); searchHandle.Position = UDim2.new(0, 8, 0, 7)
searchHandle.Rotation = -45; searchHandle.BackgroundColor3 = Color3.fromHex("#A0A0A0"); searchHandle.BorderSizePixel = 0; searchHandle.ZIndex = 12
local searchTextBox = Instance.new("TextBox", SearchBtn)
searchTextBox.Size = UDim2.new(1, -26, 1, 0); searchTextBox.Position = UDim2.new(0, 24, 0, 0)
searchTextBox.BackgroundTransparency = 1; searchTextBox.PlaceholderText = UI_TEXT.SearchPlaceholder
searchTextBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120); searchTextBox.Text = ""
searchTextBox.TextColor3 = Color3.fromRGB(230, 230, 230); searchTextBox.Font = Enum.Font.Gotham
searchTextBox.TextSize = 10; searchTextBox.TextXAlignment = Enum.TextXAlignment.Left; searchTextBox.Visible = false; searchTextBox.ZIndex = 12

local MinimizeBtn = MakeControlBtn(2); MinimizeBtn.Name = "MinimizeBtn"
local MinimizeLine = Instance.new("Frame", MinimizeBtn)
MinimizeLine.AnchorPoint = Vector2.new(0.5, 0.5); MinimizeLine.Position = UDim2.new(0.5, 0, 0.5, 0)
MinimizeLine.Size = UDim2.new(0, 9, 0, 1.2); MinimizeLine.BackgroundColor3 = Color3.fromHex("#A0A0A0"); MinimizeLine.BorderSizePixel = 0; MinimizeLine.ZIndex = 12

local ExpandBtn = MakeControlBtn(3); ExpandBtn.Name = "ExpandBtn"
local ExpandSquare = Instance.new("Frame", ExpandBtn)
ExpandSquare.Size = UDim2.new(0, 7, 0, 7); ExpandSquare.AnchorPoint = Vector2.new(0.5, 0.5)
ExpandSquare.Position = UDim2.new(0.5, 0, 0.5, 0); ExpandSquare.BackgroundTransparency = 1; ExpandSquare.ZIndex = 12
local ExpandStroke = Instance.new("UIStroke", ExpandSquare); ExpandStroke.Color = Color3.fromHex("#A0A0A0"); ExpandStroke.Thickness = 1

local CloseBtn = MakeControlBtn(4); CloseBtn.Name = "CloseBtn"
local CloseLine1 = Instance.new("Frame", CloseBtn)
CloseLine1.AnchorPoint = Vector2.new(0.5, 0.5); CloseLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine1.Size = UDim2.new(0, 10, 0, 1.2); CloseLine1.Rotation = 45; CloseLine1.BackgroundColor3 = Color3.fromHex("#A0A0A0"); CloseLine1.BorderSizePixel = 0; CloseLine1.ZIndex = 12
local CloseLine2 = Instance.new("Frame", CloseBtn)
CloseLine2.AnchorPoint = Vector2.new(0.5, 0.5); CloseLine2.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine2.Size = UDim2.new(0, 10, 0, 1.2); CloseLine2.Rotation = -45; CloseLine2.BackgroundColor3 = Color3.fromHex("#A0A0A0"); CloseLine2.BorderSizePixel = 0; CloseLine2.ZIndex = 12

local RightSeparatorLine = Instance.new("Frame", RightPanel.InnerBg)
RightSeparatorLine.Size = UDim2.new(1, 0, 0, 1); RightSeparatorLine.Position = UDim2.new(0, 0, 0, 36)
RightSeparatorLine.BackgroundColor3 = Color3.fromRGB(255, 80, 80); RightSeparatorLine.BackgroundTransparency = 0.5
RightSeparatorLine.BorderSizePixel = 0; RightSeparatorLine.ZIndex = 10

local BadgeFrame = Instance.new("Frame", RightPanel.InnerBg)
BadgeFrame.Size = UDim2.new(0, 45, 0, 18); BadgeFrame.Position = UDim2.new(0, 12, 0, 9)
BadgeFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255); BadgeFrame.BorderSizePixel = 0; BadgeFrame.ZIndex = 15
Instance.new("UICorner", BadgeFrame).CornerRadius = UDim.new(1, 0)
local badgeGrad = Instance.new("UIGradient", BadgeFrame)
badgeGrad.Rotation = 45
badgeGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0))
})
local BadgeText = Instance.new("TextLabel", BadgeFrame)
BadgeText.Size = UDim2.new(1, 0, 1, 0); BadgeText.BackgroundTransparency = 1
BadgeText.Text = "v2.0.0"; BadgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
BadgeText.Font = Enum.Font.GothamBold; BadgeText.TextSize = 10; BadgeText.ZIndex = 16

-- ==================== TOGGLES CONTAINER ====================
local togglesContainer = Instance.new("ScrollingFrame", RightPanel.InnerBg)
togglesContainer.Name = "TogglesContainer"
togglesContainer.Size = UDim2.new(1, -6, 1, -48)
togglesContainer.Position = UDim2.new(0, 0, 0, 42)
togglesContainer.BackgroundTransparency = 1
togglesContainer.BorderSizePixel = 0
togglesContainer.ScrollBarThickness = 3
togglesContainer.ScrollBarImageColor3 = Color3.fromRGB(220, 30, 40)
togglesContainer.ScrollBarImageTransparency = 0
togglesContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
togglesContainer.ZIndex = 10

local containerLayout = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
containerLayout.Padding = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local uiPadding = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingTop = UDim.new(0, 8); uiPadding.PaddingBottom = UDim.new(0, 8)
uiPadding.PaddingLeft = UDim.new(0, 4); uiPadding.PaddingRight = UDim.new(0, 8)

local function UpdateCanvasSize()
    local contentHeight = containerLayout.AbsoluteContentSize.Y + 24
    togglesContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(contentHeight, togglesContainer.AbsoluteSize.Y + 1))
end
containerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvasSize)
togglesContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateCanvasSize)

-- ==================== CONFIRM FRAME ====================
local confirmFrame = Instance.new("Frame", mainWrapper)
confirmFrame.Name = "ConfirmFrame"; confirmFrame.Size = UDim2.new(1, 0, 1, 0)
confirmFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0); confirmFrame.BackgroundTransparency = 0
confirmFrame.Visible = false; confirmFrame.ZIndex = 999
Instance.new("UICorner", confirmFrame).CornerRadius = UDim.new(0, 10)

local confirmLabel = Instance.new("TextLabel", confirmFrame)
confirmLabel.Size = UDim2.new(1, 0, 0, 30); confirmLabel.Position = UDim2.new(0, 0, 0.35, -10)
confirmLabel.BackgroundTransparency = 1; confirmLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
confirmLabel.Font = Enum.Font.GothamBold; confirmLabel.TextSize = 14
confirmLabel.Text = UI_TEXT.ConfirmCloseTitle; confirmLabel.ZIndex = 1000

local btnYes = Instance.new("TextButton", confirmFrame)
btnYes.Size = UDim2.new(0, 110, 0, 34); btnYes.Position = UDim2.new(0.5, -115, 0.55, 0)
btnYes.BackgroundColor3 = Color3.fromHex("#8B0000"); btnYes.TextColor3 = Color3.fromRGB(255, 255, 255)
btnYes.Font = Enum.Font.GothamMedium; btnYes.TextSize = 12; btnYes.Text = UI_TEXT.ConfirmBtn; btnYes.ZIndex = 1000
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 6)

local btnNo = Instance.new("TextButton", confirmFrame)
btnNo.Size = UDim2.new(0, 110, 0, 34); btnNo.Position = UDim2.new(0.5, 5, 0.55, 0)
btnNo.BackgroundColor3 = Color3.fromRGB(26, 26, 26); btnNo.TextColor3 = Color3.fromRGB(180, 180, 180)
btnNo.Font = Enum.Font.GothamMedium; btnNo.TextSize = 12; btnNo.Text = UI_TEXT.CancelBtn; btnNo.ZIndex = 1000
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 6)

-- ==================== TELEPORT TAB ====================
local teleportScrollFrame = Instance.new("ScrollingFrame", RightPanel.InnerBg)
teleportScrollFrame.Name = "TeleportScroll"
teleportScrollFrame.Size = UDim2.new(1, -6, 1, -48)
teleportScrollFrame.Position = UDim2.new(0, 0, 0, 42)
teleportScrollFrame.BackgroundTransparency = 1
teleportScrollFrame.BorderSizePixel = 0
teleportScrollFrame.ScrollBarThickness = 3
teleportScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(220, 30, 40)
teleportScrollFrame.ScrollBarImageTransparency = 0
teleportScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
teleportScrollFrame.ZIndex = 10
teleportScrollFrame.Visible = false

local tpLayout = Instance.new("UIListLayout", teleportScrollFrame)
tpLayout.SortOrder = Enum.SortOrder.LayoutOrder
tpLayout.Padding = UDim.new(0, 5)
tpLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local tpPad = Instance.new("UIPadding", teleportScrollFrame)
tpPad.PaddingTop = UDim.new(0, 8); tpPad.PaddingBottom = UDim.new(0, 8)
tpPad.PaddingLeft = UDim.new(0, 4); tpPad.PaddingRight = UDim.new(0, 8)

local seaLabels = { [1] = "Primeiro Mar", [2] = "Segundo Mar", [3] = "Terceiro Mar" }
local createdSections = {}

local function GetOrCreateSection(seaNum)
    if createdSections[seaNum] then return createdSections[seaNum] end
    local section = Instance.new("Frame", teleportScrollFrame)
    section.Name = "Section_" .. seaNum
    section.Size = UDim2.new(1, -12, 0, 22)
    section.BackgroundTransparency = 1
    section.ZIndex = 11
    local lbl = Instance.new("TextLabel", section)
    lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = seaLabels[seaNum] or ("Mar " .. seaNum)
    lbl.TextColor3 = Color3.fromRGB(255, 80, 80); lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 12
    createdSections[seaNum] = section
    return section
end

for _, tp in ipairs(TeleportSystem.Locations) do
    GetOrCreateSection(tp.Sea)
    local btn = Instance.new("TextButton", teleportScrollFrame)
    btn.Name = "TP_" .. tp.Name
    btn.Size = UDim2.new(1, -12, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
    btn.BackgroundTransparency = 0.45
    btn.Text = ""
    btn.ZIndex = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", btn); stroke.Color = Color3.fromHex("#141414"); stroke.Thickness = 1
    local lbl = Instance.new("TextLabel", btn)
    lbl.Size = UDim2.new(1, -65, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = tp.Name
    lbl.TextColor3 = Color3.fromHex("#CCCCCC"); lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 12
    local icon = Instance.new("TextLabel", btn)
    icon.Size = UDim2.new(0, 50, 1, 0); icon.Position = UDim2.new(1, -55, 0, 0)
    icon.BackgroundTransparency = 1; icon.Text = "TP  ›"
    icon.TextColor3 = Color3.fromRGB(200, 50, 50); icon.Font = Enum.Font.GothamBold
    icon.TextSize = 13; icon.ZIndex = 12
    local tpPos = tp.Position
    btn.MouseButton1Click:Connect(function()
        PlayUI_Click()
        local t = TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.1})
        t:Play(); t.Completed:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.45}):Play()
        end)
        TeleportSystem:Teleport(tp)
    end)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.25}):Play()
        TweenService:Create(lbl, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.45}):Play()
        TweenService:Create(lbl, TweenInfo.new(0.15), {TextColor3 = Color3.fromHex("#CCCCCC")}):Play()
    end)
end

local function UpdateTpCanvas()
    local h = tpLayout.AbsoluteContentSize.Y + 24
    teleportScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(h, teleportScrollFrame.AbsoluteSize.Y + 1))
end
tpLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTpCanvas)
teleportScrollFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTpCanvas)

-- ==================== FILTER & TABS LOGIC ====================
local function filterToggles(currentActiveTab, query)
    local searchQuery = (query or ""):lower()
    local itemIndex = 0
    for _, child in ipairs(togglesContainer:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
            local itemTab = child:GetAttribute("Tab") or ""
            local shouldBeVisible = false
            if searchQuery ~= "" then
                local titleLabel = child:FindFirstChild("Title")
                local descLabel = child:FindFirstChild("Description")
                local text = ""
                if titleLabel then text = titleLabel.Text end
                shouldBeVisible = text:lower():find(searchQuery) ~= nil
            else
                shouldBeVisible = (itemTab == currentActiveTab)
            end
            if shouldBeVisible then
                child.Visible = true
                itemIndex = itemIndex + 1
                if child:FindFirstChild("Title") then
                    child.Size = UDim2.new(1, -12, 0, 52)
                end
                child.BackgroundTransparency = 0.45
                local t = child:FindFirstChild("Title")
                local d = child:FindFirstChild("Description")
                if t then t.TextTransparency = 0 end
                if d then d.TextTransparency = 0 end
            else
                child.Visible = false
            end
        end
    end
    task.delay(0.05, UpdateCanvasSize)
end

local function selectTab(tabName)
    activeTab = tabName
    local isTeleport = (tabName == "Teleports")
    togglesContainer.Visible = not isTeleport
    teleportScrollFrame.Visible = isTeleport

    local animSpeed = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for name, btn in pairs(tabButtons) do
        local label = btn:FindFirstChild("Label")
        local activeBar = btn:FindFirstChild("ActiveBar")
        local iconContainer = btn:FindFirstChild("Icon")
        if name == tabName then
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(25, 5, 5), BackgroundTransparency = 0.4}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end
            if activeBar then activeBar.Visible = true end
            if iconContainer and iconContainer:FindFirstChild("AccentImage") then
                TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            end
        else
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 1}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(150, 150, 150)}):Play() end
            if activeBar then activeBar.Visible = false end
            if iconContainer and iconContainer:FindFirstChild("AccentImage") then
                TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Color3.fromRGB(150, 150, 150)}):Play()
            end
        end
    end
    togglesContainer.CanvasPosition = Vector2.new(0, 0)
    searchTextBox.Text = ""
    if not isTeleport then
        filterToggles(tabName, "")
    end
end

-- ==================== CREATE TAB BTN ====================
local tabIconMap = {
    AutoFarm  = "rbxthumb://type=Asset&id=107032293182891&w=150&h=150",
    PvP       = "rbxthumb://type=Asset&id=105897102093789&w=150&h=150",
    Raids     = "rbxthumb://type=Asset&id=97681798175944&w=150&h=150",
    Teleports = "rbxthumb://type=Asset&id=131082536388353&w=150&h=150",
    Settings  = "rbxthumb://type=Asset&id=88409765080516&w=150&h=150",
}

local function createTabBtn(tabName)
    local tabBtn = Instance.new("TextButton", TabsContainer)
    tabBtn.Name = tabName .. "TabBtn"
    tabBtn.Size = UDim2.new(1, -16, 0, 36)
    tabBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text = ""
    tabBtn.ZIndex = 11
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 8)
    local activeBar = Instance.new("Frame", tabBtn)
    activeBar.Name = "ActiveBar"; activeBar.Size = UDim2.new(0, 3, 0, 20)
    activeBar.Position = UDim2.new(0, 2, 0.5, -10); activeBar.BackgroundColor3 = Color3.fromHex("#8B0000")
    activeBar.BorderSizePixel = 0; activeBar.Visible = false; activeBar.ZIndex = 13
    Instance.new("UICorner", activeBar).CornerRadius = UDim.new(1, 0)
    local iconContainer = Instance.new("Frame", tabBtn)
    iconContainer.Name = "Icon"; iconContainer.Size = UDim2.new(0, 18, 0, 18)
    iconContainer.Position = UDim2.new(0, 12, 0.5, -9); iconContainer.BackgroundTransparency = 1; iconContainer.ZIndex = 12
    local imageLabel = Instance.new("ImageLabel", iconContainer)
    imageLabel.Name = "AccentImage"; imageLabel.Size = UDim2.new(1, 0, 1, 0)
    imageLabel.BackgroundTransparency = 1; imageLabel.ZIndex = 13
    imageLabel.ImageColor3 = Color3.fromRGB(150, 150, 150)
    imageLabel.Image = tabIconMap[tabName] or ""
    local tabLabel = Instance.new("TextLabel", tabBtn)
    tabLabel.Name = "Label"; tabLabel.Size = UDim2.new(1, -42, 1, 0)
    tabLabel.Position = UDim2.new(0, 38, 0, 0); tabLabel.BackgroundTransparency = 1
    tabLabel.TextColor3 = Color3.fromRGB(150, 150, 150); tabLabel.Font = Enum.Font.GothamMedium
    tabLabel.TextSize = 11; tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.Text = UI_TEXT.Tabs[tabName] or tabName; tabLabel.ZIndex = 12
    tabBtn.MouseButton1Click:Connect(function() selectTab(tabName) end)
    tabButtons[tabName] = tabBtn
end

-- ==================== CREATE TOGGLE ====================
local function createToggle(parent, configKey, tabCategory)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = configKey
    toggleFrame.Size = UDim2.new(1, -12, 0, 52)
    toggleFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
    toggleFrame.BackgroundTransparency = 0.45
    toggleFrame.ZIndex = 11
    toggleFrame.ClipsDescendants = true
    toggleFrame:SetAttribute("Tab", tabCategory)
    toggleFrame:SetAttribute("ConfigKey", configKey)
    toggleFrame.Parent = parent
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", toggleFrame); stroke.Color = Color3.fromHex("#141414"); stroke.Thickness = 1
    local optData = UI_TEXT.Options[configKey]
    local titleLabel = Instance.new("TextLabel", toggleFrame)
    titleLabel.Name = "Title"; titleLabel.Size = UDim2.new(0.7, 0, 0, 16)
    titleLabel.Position = UDim2.new(0, 10, 0, 6); titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromHex("#CCCCCC"); titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11; titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = optData and optData.Title or configKey; titleLabel.ZIndex = 11
    local descLabel = Instance.new("TextLabel", toggleFrame)
    descLabel.Name = "Description"; descLabel.Size = UDim2.new(0.7, 0, 0, 26)
    descLabel.Position = UDim2.new(0, 10, 0, 22); descLabel.BackgroundTransparency = 1
    descLabel.TextColor3 = Color3.fromRGB(130, 130, 130); descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 9; descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top; descLabel.TextWrapped = true
    descLabel.Text = optData and optData.Desc or ""; descLabel.ZIndex = 11
    local switchTrack = Instance.new("Frame", toggleFrame)
    switchTrack.Size = UDim2.new(0, 38, 0, 18); switchTrack.Position = UDim2.new(1, -48, 0.5, -9)
    switchTrack.BackgroundColor3 = Config[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
    switchTrack.ZIndex = 11
    Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)
    local switchCircle = Instance.new("Frame", switchTrack)
    switchCircle.Size = UDim2.new(0, 12, 0, 12)
    switchCircle.Position = Config[configKey] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
    switchCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255); switchCircle.ZIndex = 12
    Instance.new("UICorner", switchCircle).CornerRadius = UDim.new(1, 0)
    local triggerBtn = Instance.new("TextButton", toggleFrame)
    triggerBtn.Name = "TriggerButton"
    triggerBtn.Size = UDim2.new(1, 0, 1, 0); triggerBtn.BackgroundTransparency = 1
    triggerBtn.Text = ""; triggerBtn.ZIndex = 13

    triggerBtn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        local on = Config[configKey]
        local targetPos   = on and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        local targetColor = on and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
        local anim = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(switchCircle, anim, {Position = targetPos}):Play()
        TweenService:Create(switchTrack, anim, {BackgroundColor3 = targetColor}):Play()

        -- Conectar aos sistemas
        if configKey == "AutoFarm" then
            if on then AutoFarmInstance:Start() else AutoFarmInstance:Stop() end
        elseif configKey == "AutoFarmBoss" then
            if on then BossFarmInstance:Start() else BossFarmInstance:Stop() end
        elseif configKey == "AutoCollectChest" then
            if on then AutoChestInstance:Start() else AutoChestInstance:Stop() end
        elseif configKey == "AutoStats" then
            if on then AutoStatsInstance:Start() else AutoStatsInstance:Stop() end
        elseif configKey == "AimbotPvP" then
            if on then AimbotInstance:Start() else AimbotInstance:Stop() end
        elseif configKey == "FruitSniper" then
            if on then FruitSniperInstance:Start() else FruitSniperInstance:Stop() end
        elseif configKey == "AutoRaid" then
            if on then AutoRaidInstance:Start() else AutoRaidInstance:Stop() end
        elseif configKey == "PlayerESP" then
            if on then PlayerESPInstance:Start() else PlayerESPInstance:Stop() end
        elseif configKey == "FruitESP" then
            if on then FruitESPInstance:Start() else FruitESPInstance:Stop() end
        elseif configKey == "ServerHop" then
            if on then ServerHopInstance:Start() else ServerHopInstance:Stop() end
        elseif configKey == "AutoRevive" then
            if on then AutoReviveInstance:Start() else AutoReviveInstance:Stop() end
        end
    end)
end

-- ==================== CREATE SELECTORS ====================
local function createCycleSelector(parent, labelText, configKey, options, tabCategory)
    local frame = Instance.new("Frame")
    frame.Name = configKey .. "Selector"
    frame.Size = UDim2.new(1, -12, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
    frame.BackgroundTransparency = 0.45
    frame.ZIndex = 11
    frame.ClipsDescendants = true
    frame:SetAttribute("Tab", tabCategory)
    frame:SetAttribute("ConfigKey", configKey)
    frame.Parent = togglesContainer
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", frame); stroke.Color = Color3.fromHex("#141414"); stroke.Thickness = 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0, 80, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 10
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 12

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(1, -95, 1, -8)
    btn.Position = UDim2.new(0, 90, 0, 4)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.BackgroundTransparency = 0.5
    btn.Text = Config[configKey] or options[1]
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.ZIndex = 13
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local currentIndex = 1
    for i, opt in ipairs(options) do
        if opt == Config[configKey] then currentIndex = i break end
    end

    btn.MouseButton1Click:Connect(function()
        currentIndex = currentIndex % #options + 1
        btn.Text = options[currentIndex]
        Config[configKey] = options[currentIndex]
        if configKey == "SelectedBoss" and Config.AutoFarmBoss then
            BossFarmInstance:Stop()
            BossFarmInstance:Start()
        end
        -- Para SelectedMob, se AutoFarm estiver rodando, reinicia para aplicar novo filtro
        if configKey == "SelectedMob" and Config.AutoFarm then
            AutoFarmInstance:Stop()
            AutoFarmInstance:Start()
        end
    end)

    -- Garante que o valor inicial esteja correto
    Config[configKey] = btn.Text
    return frame
end

-- ==================== SEARCH ====================
local searchExpanded = false
local searchInactivityTimer = nil

local function resetSearchInactivityTimer()
    if searchInactivityTimer then task.cancel(searchInactivityTimer) end
    searchInactivityTimer = task.delay(4, function()
        if searchExpanded and searchTextBox.Text == "" then
            searchExpanded = false
            TweenService:Create(SearchBtn, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 24, 0, 24)}):Play()
            searchTextBox:ReleaseFocus()
            task.delay(0.2, function() searchTextBox.Visible = false end)
            filterToggles(activeTab, "")
        end
    end)
end

SearchBtn.MouseButton1Click:Connect(function()
    PlayUI_Click()
    searchExpanded = not searchExpanded
    local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if searchExpanded then
        TweenService:Create(SearchBtn, info, {Size = UDim2.new(0, 120, 0, 24)}):Play()
        searchTextBox.Visible = true; searchTextBox:CaptureFocus()
        resetSearchInactivityTimer()
    else
        TweenService:Create(SearchBtn, info, {Size = UDim2.new(0, 24, 0, 24)}):Play()
        searchTextBox:ReleaseFocus(); searchTextBox.Text = ""
        task.delay(0.2, function() if not searchExpanded then searchTextBox.Visible = false end end)
        filterToggles(activeTab, "")
    end
end)
searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
    resetSearchInactivityTimer(); filterToggles(activeTab, searchTextBox.Text)
end)

-- ==================== EXPAND / MINIMIZE / CLOSE ====================
ExpandBtn.MouseButton1Click:Connect(function()
    PlayUI_Click()
    isExpanded = not isExpanded
    local newSize = isExpanded and UDim2.new(0, 800, 0, 480) or UDim2.new(0, 640, 0, 360)
    TweenService:Create(mainWrapper, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = newSize}):Play()
end)

SetUIState = function(newState)
    if UIState == newState or UIState == "OPENING" or UIState == "CLOSING" then return end
    UIState = (newState == "OPEN" and "OPENING") or "CLOSING"
    local t = 0.25
    local anim = TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if newState == "OPEN" then
        mainWrapper.Visible = true
        mainWrapper.Size = UDim2.new(0, 480, 0, 260)
        AplicarFadeSincronizado(mainWrapper, true, 0)
        AplicarFadeSincronizado(mainWrapper, false, t)
        local ot = TweenService:Create(mainWrapper, anim, {Size = isExpanded and UDim2.new(0, 800, 0, 480) or UDim2.new(0, 640, 0, 360)})
        ot:Play(); ot.Completed:Connect(function() UIState = "OPEN"; filterToggles(activeTab, searchTextBox.Text) end)
    else
        AplicarFadeSincronizado(mainWrapper, true, t)
        local ct = TweenService:Create(mainWrapper, anim, {Size = UDim2.new(0, 480, 0, 260)})
        ct:Play(); ct.Completed:Connect(function() mainWrapper.Visible = false; UIState = newState end)
    end
end

MinimizeBtn.MouseButton1Click:Connect(function() PlayUI_Click(); SetUIState("MINIMIZED") end)

local function AlternarConfirmacao(exibir)
    isConfirmOpen = exibir
    local t = 0.15
    if exibir then
        if not confirmBlur then confirmBlur = Instance.new("BlurEffect"); confirmBlur.Size = 0; confirmBlur.Parent = Lighting end
        confirmFrame.Visible = true
        AplicarFadeSincronizado(confirmFrame, true, 0)
        AplicarFadeSincronizado(confirmFrame, false, t)
        TweenService:Create(confirmBlur, TweenInfo.new(t, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 56}):Play()
    else
        AplicarFadeSincronizado(confirmFrame, true, t)
        if confirmBlur then
            local bt = TweenService:Create(confirmBlur, TweenInfo.new(t, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 0})
            bt:Play(); bt.Completed:Connect(function() if confirmBlur and confirmBlur.Size == 0 then confirmBlur:Destroy(); confirmBlur = nil end end)
        end
        task.delay(t, function() if not isConfirmOpen then confirmFrame.Visible = false end end)
    end
end

CloseBtn.MouseButton1Click:Connect(function() PlayUI_Click(); AlternarConfirmacao(true) end)
btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)
btnYes.MouseButton1Click:Connect(function()
    -- Parar todos os sistemas
    AutoFarmInstance:Stop()
    BossFarmInstance:Stop()
    AutoStatsInstance:Stop()
    AutoChestInstance:Stop()
    AimbotInstance:Stop()
    FruitSniperInstance:Stop()
    AutoRaidInstance:Stop()
    PlayerESPInstance:Stop()
    FruitESPInstance:Stop()
    ServerHopInstance:Stop()
    AutoReviveInstance:Stop()

    local s = 0.2
    if confirmBlur then TweenService:Create(confirmBlur, TweenInfo.new(s, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 0}):Play() end
    AplicarFadeSincronizado(mainWrapper, true, s)
    TweenService:Create(FloatBtn, TweenInfo.new(s, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)}):Play()
    task.wait(s)
    screenGui:Destroy()
end)

-- ==================== BUTTON HOVER FX ====================
local function AplicarEfeitoBotao(btn)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 30, 30), BackgroundTransparency = 0.1}):Play()
        if btn.Name == "CloseBtn" then
            TweenService:Create(CloseLine1, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(255, 60, 60)}):Play()
            TweenService:Create(CloseLine2, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(255, 60, 60)}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 0.3}):Play()
        if btn.Name == "CloseBtn" then
            TweenService:Create(CloseLine1, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
            TweenService:Create(CloseLine2, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        end
    end)
end
AplicarEfeitoBotao(SearchBtn); AplicarEfeitoBotao(MinimizeBtn)
AplicarEfeitoBotao(ExpandBtn); AplicarEfeitoBotao(CloseBtn)

-- ==================== CRIAR ABAS E TOGGLES ====================
createTabBtn("AutoFarm")
createTabBtn("PvP")
createTabBtn("Raids")
createTabBtn("Teleports")
createTabBtn("Settings")

-- Auto Farm tab
createToggle(togglesContainer, "AutoFarm",         "AutoFarm")
createToggle(togglesContainer, "AutoFarmBoss",     "AutoFarm")
createToggle(togglesContainer, "AutoCollectChest", "AutoFarm")
createToggle(togglesContainer, "AutoStats",        "AutoFarm")

-- Seletor de Mob e Boss (somente AutoFarm)
local mobOptions = {"Lowest Level Mob", "Bandit", "Monkey", "Pirate", "Brute", "Desert Bandit", "Raider", "Mercenary", "Pirate Millionaire"}
createCycleSelector(togglesContainer, "Mob:", "SelectedMob", mobOptions, "AutoFarm")

local bossOptions = {"None"}
for _, boss in ipairs(BossList) do
    table.insert(bossOptions, boss.Name)
end
createCycleSelector(togglesContainer, "Boss:", "SelectedBoss", bossOptions, "AutoFarm")

-- PvP tab
createToggle(togglesContainer, "AimbotPvP",   "PvP")
createToggle(togglesContainer, "FruitSniper", "PvP")

-- Raids tab
createToggle(togglesContainer, "AutoRaid", "Raids")

-- Settings tab
createToggle(togglesContainer, "PlayerESP",  "Settings")
createToggle(togglesContainer, "FruitESP",   "Settings")
createToggle(togglesContainer, "AutoRevive", "Settings")
createToggle(togglesContainer, "ServerHop",  "Settings")

-- ==================== ESP UPDATE LOOP ====================
Players.PlayerRemoving:Connect(function(p)
    if PlayerESPInstance.Objects[p] then
        PlayerESPInstance:RemoveESP(p)
    end
end)

-- ==================== ANIMAÇÃO DE INTRODUÇÃO ====================
local function ExecutarIntroAkat()
    local Blur = Instance.new("BlurEffect"); Blur.Size = 0; Blur.Parent = Lighting
    local IntroFrame = Instance.new("Frame", screenGui)
    IntroFrame.Size = UDim2.new(1, 0, 1, 0); IntroFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    IntroFrame.BackgroundTransparency = 1; IntroFrame.ZIndex = 500
    local MaskContainer = Instance.new("Frame", IntroFrame)
    MaskContainer.AnchorPoint = Vector2.new(0.5, 0.5); MaskContainer.Position = UDim2.new(0.5, 0, 0.5, -10)
    MaskContainer.Size = UDim2.new(0, 460, 0, 40); MaskContainer.BackgroundTransparency = 1
    MaskContainer.ClipsDescendants = true; MaskContainer.ZIndex = 501
    local IntroText = Instance.new("TextLabel", MaskContainer)
    IntroText.Size = UDim2.new(1, 0, 1, 0); IntroText.Position = UDim2.new(0, 0, 1, 0)
    IntroText.BackgroundTransparency = 1; IntroText.Font = Enum.Font.GothamBold
    IntroText.TextSize = 26; IntroText.RichText = true; IntroText.Text = UI_TEXT.Intro; IntroText.ZIndex = 502
    local IntroLine = Instance.new("Frame", IntroFrame)
    IntroLine.AnchorPoint = Vector2.new(0.5, 0.5); IntroLine.Position = UDim2.new(0.5, 0, 0.5, 16)
    IntroLine.Size = UDim2.new(0, 0, 0, 2); IntroLine.BackgroundColor3 = Color3.fromHex("#8B0000")
    IntroLine.BorderSizePixel = 0; IntroLine.BackgroundTransparency = 1; IntroLine.ZIndex = 503
    Instance.new("UICorner", IntroLine).CornerRadius = UDim.new(1, 0)

    TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.05}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 24}):Play()
    task.wait(0.1)
    TweenService:Create(IntroText, TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
    task.wait(0.2)
    TweenService:Create(IntroLine, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(0, 280, 0, 2)}):Play()
    task.wait(1.6)
    TweenService:Create(IntroText, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
    TweenService:Create(IntroLine, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play()
    task.wait(0.3)
    TweenService:Create(IntroFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play()
    task.wait(0.3)

    RegistrarTransparencias(mainWrapper)
    for _, item in ipairs(mainWrapper:GetDescendants()) do RegistrarTransparencias(item) end
    mainWrapper.Visible = true; FloatBtn.Visible = true; UIState = "OPEN"
    local MainScale = Instance.new("UIScale", mainWrapper); MainScale.Scale = 0.85
    AplicarFadeSincronizado(mainWrapper, true, 0)
    AplicarFadeSincronizado(mainWrapper, false, 0.35)
    local openScale = TweenService:Create(MainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
    openScale:Play()
    FloatBtn.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(FloatBtn, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 44, 0, 44)}):Play()
    openScale.Completed:Connect(function()
        selectTab("AutoFarm")
        MainScale:Destroy(); IntroFrame:Destroy(); Blur:Destroy()
    end)
end

task.spawn(ExecutarIntroAkat)
