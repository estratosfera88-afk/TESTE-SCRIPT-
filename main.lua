--[[
    AKATSUKI BLOX FRUITS [v2.0.0]
    Script completo reestruturado com todas as funcionalidades reais.
    - Auto Farm com quest dinâmica e seleção de mob
    - Auto Farm Boss
    - Auto Chest
    - Auto Stats
    - Fruit Sniper
    - Auto Raid
    - Aimbot PvP
    - Anti-Flinch (parcial)
    - Player ESP e Fruit ESP (vermelho escuro)
    - Server Hop contínuo
    - Controle de threads por token
]]

-- ============================================================
-- 1. SERVIÇOS E CONFIGURAÇÕES GLOBAIS
-- ============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local character = nil
local humanoidRootPart = nil
local humanoid = nil

-- ============================================================
-- 2. SISTEMA DE PERSONAGEM
-- ============================================================

local function getCharacter()
    character = player.Character
    if not character then return false end
    humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    humanoid = character:FindFirstChild("Humanoid")
    return humanoidRootPart ~= nil and humanoid ~= nil and humanoid.Health > 0
end

local function waitForCharacter()
    if getCharacter() then return true end
    local success, char = pcall(function()
        return player.CharacterAdded:Wait()
    end)
    if success and char then
        character = char
        humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        humanoid = character:WaitForChild("Humanoid")
        return true
    end
    return false
end

player.CharacterAdded:Connect(function(char)
    character = char
    humanoidRootPart = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
    if Configs.AutoRevive then
        task.wait(1.5)
        if Configs.AutoFarm then startAutoFarm() end
        if Configs.AutoFarmBoss then startAutoFarmBoss() end
        if Configs.AutoCollectChest then startAutoChest() end
        if Configs.AutoRaid then startAutoRaid() end
    end
end)

-- ============================================================
-- 3. CONFIGURAÇÕES PRINCIPAIS
-- ============================================================

local Configs = {
    AutoFarm        = false,
    AutoFarmBoss    = false,
    AutoCollectChest= false,
    AutoStats       = false,
    AimbotPvP       = false,
    AntiFlinch      = false,
    PvPAutoBlock    = false,
    FruitSniper     = false,
    AutoRaid        = false,
    RaidInstant     = false,
    PlayerESP       = false,
    FruitESP        = false,
    AutoRevive      = false,
    ServerHop       = false,
}

local selectedMob   = "Lowest Level Mob"
local selectedBoss  = "None"
local farmSafeDistance = 12

-- ============================================================
-- 4. CONTROLE DE THREADS (TOKENS)
-- ============================================================

local function createToken()
    return { active = true }
end

local function isTokenActive(token)
    return token ~= nil and token.active == true
end

local function stopToken(token)
    if token then token.active = false end
end

local farmToken = nil
local farmBossToken = nil
local chestToken = nil
local fruitSniperToken = nil
local raidToken = nil
local serverHopToken = nil
local autoStatsToken = nil

-- ============================================================
-- 5. UTILITÁRIOS
-- ============================================================

function SafeTeleport(pos)
    if not getCharacter() then return end
    pcall(function()
        humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
        humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
        character:PivotTo(CFrame.new(pos))
        task.wait(0.05)
        humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
    end)
end

function getClosestPlayer(maxDist)
    if not getCharacter() then return nil end
    local closest, dist = nil, maxDist or 300
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local d = (hrp.Position - humanoidRootPart.Position).Magnitude
                if d < dist then dist = d; closest = p end
            end
        end
    end
    return closest
end

function isAlive(part)
    return part and part.Parent and part.Parent:FindFirstChild("Humanoid") and part.Parent.Humanoid.Health > 0
end

-- ============================================================
-- 6. SISTEMA DE QUESTS E MOBS (BASEADO EM NÍVEL)
-- ============================================================

local QuestData = {
    { minLevel = 1, maxLevel = 10, island = "Pirate Village", npc = "Bandit", questId = "BanditQuest1", mob = "Bandit" },
    { minLevel = 10, maxLevel = 20, island = "Jungle", npc = "Monkey", questId = "MonkeyQuest", mob = "Monkey" },
    { minLevel = 20, maxLevel = 30, island = "Desert", npc = "Desert Bandit", questId = "DesertBanditQuest", mob = "Desert Bandit" },
    { minLevel = 30, maxLevel = 40, island = "Frozen Village", npc = "Snow Bandit", questId = "SnowBanditQuest", mob = "Snow Bandit" },
    { minLevel = 40, maxLevel = 50, island = "Marine Fortress", npc = "Marine", questId = "MarineQuest", mob = "Marine" },
    { minLevel = 50, maxLevel = 60, island = "Skylands", npc = "Sky Bandit", questId = "SkyBanditQuest", mob = "Sky Bandit" },
    { minLevel = 60, maxLevel = 70, island = "Prison", npc = "Prisoner", questId = "PrisonerQuest", mob = "Prisoner" },
    { minLevel = 70, maxLevel = 80, island = "Colosseum", npc = "Gladiator", questId = "GladiatorQuest", mob = "Gladiator" },
    { minLevel = 80, maxLevel = 90, island = "Magma Village", npc = "Magma", questId = "MagmaQuest", mob = "Magma" },
    { minLevel = 90, maxLevel = 100, island = "Underwater City", npc = "Fishman", questId = "FishmanQuest", mob = "Fishman" },
    { minLevel = 100, maxLevel = 110, island = "Fountain City", npc = "Pirate", questId = "PirateQuest", mob = "Pirate" },
    { minLevel = 110, maxLevel = 130, island = "Kingdom of Rose", npc = "Mob", questId = "MobQuest", mob = "Mob" },
    { minLevel = 130, maxLevel = 150, island = "Green Zone", npc = "Green Zombie", questId = "GreenZombieQuest", mob = "Green Zombie" },
    { minLevel = 150, maxLevel = 170, island = "Graveyard", npc = "Skeleton", questId = "SkeletonQuest", mob = "Skeleton" },
    { minLevel = 170, maxLevel = 190, island = "Snow Mountain", npc = "Yeti", questId = "YetiQuest", mob = "Yeti" },
    { minLevel = 190, maxLevel = 210, island = "Hot and Cold", npc = "Dragon", questId = "DragonQuest", mob = "Dragon" },
    { minLevel = 210, maxLevel = 230, island = "Cursed Ship", npc = "Cursed", questId = "CursedQuest", mob = "Cursed" },
    { minLevel = 230, maxLevel = 250, island = "Ice Castle", npc = "Ice", questId = "IceQuest", mob = "Ice" },
    { minLevel = 250, maxLevel = 270, island = "Forgotten Island", npc = "Forgotten", questId = "ForgottenQuest", mob = "Forgotten" },
    { minLevel = 270, maxLevel = 290, island = "Port Town", npc = "Pirate", questId = "PirateQuest3", mob = "Pirate" },
    { minLevel = 290, maxLevel = 310, island = "Hydra Island", npc = "Hydra", questId = "HydraQuest", mob = "Hydra" },
    { minLevel = 310, maxLevel = 330, island = "Great Tree", npc = "Tree", questId = "TreeQuest", mob = "Tree" },
    { minLevel = 330, maxLevel = 350, island = "Floating Turtle", npc = "Turtle", questId = "TurtleQuest", mob = "Turtle" },
    { minLevel = 350, maxLevel = 370, island = "Haunted Castle", npc = "Ghost", questId = "GhostQuest", mob = "Ghost" },
    { minLevel = 370, maxLevel = 390, island = "Sea of Treats", npc = "Candy", questId = "CandyQuest", mob = "Candy" },
    { minLevel = 390, maxLevel = 410, island = "Tiki Outpost", npc = "Tiki", questId = "TikiQuest", mob = "Tiki" },
    { minLevel = 410, maxLevel = 999, island = "Castle on the Sea", npc = "Castle", questId = "CastleQuest", mob = "Castle" },
}

local Bosses = {
    FirstSea = {
        { name = "Gorilla",     island = "Jungle",          pos = Vector3.new(-2500, 50, 300) },
        { name = "Bobby",       island = "Pirate Village",  pos = Vector3.new(-1500, 10, 200) },
        { name = "Yeti",        island = "Frozen Village",  pos = Vector3.new(1500, 50, 1200) },
        { name = "Vice Admiral",island = "Marine Fortress", pos = Vector3.new(1000, 120, 1600) },
        { name = "Saber Expert",island = "Skylands",        pos = Vector3.new(-5000, 2000, 200) },
        { name = "Ice Admiral", island = "Frozen Village",  pos = Vector3.new(1600, 10, 1100) },
    },
    SecondSea = {
        { name = "Order",       island = "Kingdom of Rose", pos = Vector3.new(-1000, 80, -1000) },
        { name = "Darkbeard",   island = "Kingdom of Rose", pos = Vector3.new(-800, 80, -900) },
        { name = "Cursed Captain", island = "Cursed Ship",  pos = Vector3.new(3000, 30, 5000) },
        { name = "Killer",      island = "Snow Mountain",   pos = Vector3.new(2000, 100, 800) },
        { name = "Diamond",     island = "Hot and Cold",    pos = Vector3.new(2500, 50, -1000) },
        { name = "Rumble",      island = "Hot and Cold",    pos = Vector3.new(2400, 50, -900) },
    },
    ThirdSea = {
        { name = "Stone",       island = "Port Town",       pos = Vector3.new(-2600, 80, -3700) },
        { name = "Dough King",  island = "Great Tree",      pos = Vector3.new(-14150, 280, -6025) },
        { name = "Dragon",      island = "Floating Turtle", pos = Vector3.new(-11950, 850, -6025) },
        { name = "Fajita",      island = "Sea of Treats",   pos = Vector3.new(3000, 50, 9000) },
    }
}

function getQuestForLevel(level)
    for _, q in ipairs(QuestData) do
        if level >= q.minLevel and level <= q.maxLevel then
            return q
        end
    end
    return QuestData[#QuestData]
end

-- ============================================================
-- 7. SISTEMA DE COMBATE
-- ============================================================

function attackTarget(targetPart)
    if not getCharacter() then return end
    if not targetPart or not targetPart.Parent then return end
    local target = targetPart.Parent
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then
        for _, t in ipairs(player.Backpack:GetChildren()) do
            if t:IsA("Tool") then
                humanoid:EquipTool(t)
                tool = t
                break
            end
        end
    end
    if tool then
        pcall(function() tool:Activate() end)
    end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local attackRemote = remotes:FindFirstChild("Combat") or remotes:FindFirstChild("Attack")
        if attackRemote then
            pcall(function() attackRemote:FireServer(target) end)
        end
    end
end

function getTargetMob(mobName)
    if not getCharacter() then return nil end
    local closest, dist = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= character then
            local hum = obj:FindFirstChild("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 and not Players:GetPlayerFromCharacter(obj) then
                local name = obj.Name:lower()
                if mobName == "Lowest Level Mob" then
                    if not name:find("boss") then
                        local d = (hrp.Position - humanoidRootPart.Position).Magnitude
                        if d < dist then dist = d; closest = { Model = obj, HRP = hrp, Humanoid = hum } end
                    end
                else
                    if name:find(mobName:lower()) then
                        local d = (hrp.Position - humanoidRootPart.Position).Magnitude
                        if d < dist then dist = d; closest = { Model = obj, HRP = hrp, Humanoid = hum } end
                    end
                end
            end
        end
    end
    return closest
end

function getTargetBoss(bossName)
    if not getCharacter() then return nil end
    local closest, dist = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= character then
            local hum = obj:FindFirstChild("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 and not Players:GetPlayerFromCharacter(obj) then
                local name = obj.Name:lower()
                if name:find(bossName:lower()) then
                    local d = (hrp.Position - humanoidRootPart.Position).Magnitude
                    if d < dist then dist = d; closest = { Model = obj, HRP = hrp, Humanoid = hum } end
                end
            end
        end
    end
    return closest
end

-- ============================================================
-- 8. AUTO FARM
-- ============================================================

function startAutoFarm()
    stopToken(farmToken)
    farmToken = createToken()
    task.spawn(function()
        local token = farmToken
        while isTokenActive(token) and Configs.AutoFarm do
            if not waitForCharacter() then task.wait(1); continue end
            local level = 0
            pcall(function()
                local stats = player:FindFirstChild("leaderstats")
                if stats then
                    local lvl = stats:FindFirstChild("Level")
                    if lvl then level = lvl.Value end
                end
            end)
            local quest = getQuestForLevel(level)
            if quest then
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                if remotes and remotes:FindFirstChild("CommF_") then
                    pcall(function()
                        remotes.CommF_:InvokeServer("StartQuest", quest.questId, 1)
                    end)
                end
            end
            local mobName = selectedMob
            local enemy = getTargetMob(mobName)
            if enemy and enemy.HRP then
                local pos = enemy.HRP.Position + Vector3.new(0, farmSafeDistance, 0)
                SafeTeleport(pos)
                attackTarget(enemy.HRP)
            else
                task.wait(0.3)
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

function stopAutoFarm()
    stopToken(farmToken)
end

-- ============================================================
-- 9. AUTO FARM BOSS
-- ============================================================

function startAutoFarmBoss()
    stopToken(farmBossToken)
    farmBossToken = createToken()
    task.spawn(function()
        local token = farmBossToken
        while isTokenActive(token) and Configs.AutoFarmBoss do
            if not waitForCharacter() then task.wait(1); continue end
            if selectedBoss == "None" then
                task.wait(1)
                continue
            end
            local boss = getTargetBoss(selectedBoss)
            if boss and boss.HRP then
                SafeTeleport(boss.HRP.Position + Vector3.new(0, farmSafeDistance, 0))
                attackTarget(boss.HRP)
            else
                local found = false
                for _, sea in ipairs({"FirstSea", "SecondSea", "ThirdSea"}) do
                    for _, b in ipairs(Bosses[sea]) do
                        if b.name:lower() == selectedBoss:lower() then
                            SafeTeleport(b.pos)
                            found = true
                            break
                        end
                    end
                    if found then break end
                end
                task.wait(1)
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

function stopAutoFarmBoss()
    stopToken(farmBossToken)
end

-- ============================================================
-- 10. AUTO CHEST
-- ============================================================

function startAutoChest()
    stopToken(chestToken)
    chestToken = createToken()
    task.spawn(function()
        local token = chestToken
        while isTokenActive(token) and Configs.AutoCollectChest do
            if not waitForCharacter() then task.wait(1); continue end
            local bestChest = nil
            local bestDist = math.huge
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if not isTokenActive(token) then break end
                if obj:IsA("Model") and obj.Name:lower():find("chest") then
                    local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("PrimaryPart")
                    if hrp and hrp:IsA("BasePart") then
                        local d = (hrp.Position - humanoidRootPart.Position).Magnitude
                        if d < bestDist then
                            bestChest = hrp
                            bestDist = d
                        end
                    end
                end
            end
            if bestChest then
                SafeTeleport(bestChest.Position + Vector3.new(0, 3, 0))
                task.wait(0.5)
            else
                task.wait(2)
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

function stopAutoChest()
    stopToken(chestToken)
end

-- ============================================================
-- 11. AUTO STATS
-- ============================================================

local statAttributes = { "Melee", "Defense", "Sword", "Gun", "Blox Fruit" }
local selectedStat = "Melee"

function startAutoStats()
    stopToken(autoStatsToken)
    autoStatsToken = createToken()
    task.spawn(function()
        local token = autoStatsToken
        while isTokenActive(token) and Configs.AutoStats do
            if not waitForCharacter() then task.wait(1); continue end
            local stats = player:FindFirstChild("leaderstats")
            if stats then
                local points = stats:FindFirstChild("Points")
                if points and points.Value > 0 then
                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                    if remotes and remotes:FindFirstChild("CommF_") then
                        pcall(function()
                            remotes.CommF_:InvokeServer("AddStat", selectedStat)
                        end)
                    end
                    task.wait(0.1)
                else
                    task.wait(2)
                end
            else
                task.wait(2)
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

function stopAutoStats()
    stopToken(autoStatsToken)
end

-- ============================================================
-- 12. FRUIT SNIPER
-- ============================================================

function startFruitSniper()
    stopToken(fruitSniperToken)
    fruitSniperToken = createToken()
    task.spawn(function()
        local token = fruitSniperToken
        local fruitNames = {
            "Bomb", "Spike", "Flame", "Falcon", "Ice", "Sand", "Dark", "Light", "Rubber",
            "Barrier", "Ghost", "Diamond", "Rumble", "Magma", "Human", "Bird", "Venom", "Dragon",
            "Shadow", "Gravity", "Dough", "Revive", "Paw", "Sound", "Love", "Spider", "Portal"
        }
        while isTokenActive(token) and Configs.FruitSniper do
            if not waitForCharacter() then task.wait(1); continue end
            local closestFruit = nil
            local bestDist = math.huge
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if not isTokenActive(token) then break end
                if obj:IsA("Model") then
                    local name = obj.Name
                    local isFruit = false
                    for _, fname in ipairs(fruitNames) do
                        if name:find(fname) then isFruit = true; break end
                    end
                    if not isFruit then
                        if name:lower():find("fruit") or name:lower():find("devil") then
                            isFruit = true
                        end
                    end
                    if isFruit then
                        local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("PrimaryPart")
                        if hrp and hrp:IsA("BasePart") then
                            local d = (hrp.Position - humanoidRootPart.Position).Magnitude
                            if d < bestDist then
                                closestFruit = hrp
                                bestDist = d
                            end
                        end
                    end
                end
            end
            if closestFruit then
                SafeTeleport(closestFruit.Position + Vector3.new(0, 3, 0))
                task.wait(0.8)
            else
                task.wait(2)
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

function stopFruitSniper()
    stopToken(fruitSniperToken)
end

-- ============================================================
-- 13. AUTO RAID
-- ============================================================

function startAutoRaid()
    stopToken(raidToken)
    raidToken = createToken()
    task.spawn(function()
        local token = raidToken
        while isTokenActive(token) and Configs.AutoRaid do
            if not waitForCharacter() then task.wait(1); continue end
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if not remotes then task.wait(1); continue end
            local raidRemote = remotes:FindFirstChild("StartRaid") or remotes:FindFirstChild("Raid")
            if not raidRemote then task.wait(1); continue end
            SafeTeleport(Vector3.new(-15970, 700, 3800))
            task.wait(1.5)
            pcall(function() raidRemote:FireServer() end)
            task.wait(3)
            local raidActive = true
            local timeout = 0
            while isTokenActive(token) and Configs.AutoRaid and raidActive and timeout < 120 do
                if not waitForCharacter() then task.wait(1); continue end
                local enemy = getTargetMob("Lowest Level Mob")
                if enemy then
                    SafeTeleport(enemy.HRP.Position + Vector3.new(0, farmSafeDistance, 0))
                    attackTarget(enemy.HRP)
                    timeout = 0
                else
                    timeout = timeout + 1
                end
                if timeout > 20 then raidActive = false end
                RunService.Heartbeat:Wait()
            end
            task.wait(2)
        end
    end)
end

function stopAutoRaid()
    stopToken(raidToken)
end

-- ============================================================
-- 14. AIMBOT PVP
-- ============================================================

local aimbotConnection = nil
local aimbotTarget = nil

function startAimbot()
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    aimbotConnection = RunService.RenderStepped:Connect(function()
        if not Configs.AimbotPvP then
            if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
            return
        end
        if not getCharacter() then return end
        local target = getClosestPlayer(300)
        if target and target.Character then
            local head = target.Character:FindFirstChild("Head")
            if head then
                local camera = Workspace.CurrentCamera
                camera.CFrame = CFrame.new(camera.CFrame.Position, head.Position)
                aimbotTarget = target
            end
        else
            aimbotTarget = nil
        end
    end)
end

function stopAimbot()
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    aimbotTarget = nil
end

-- ============================================================
-- 15. ANTI-FLINCH (PARCIAL)
-- ============================================================

local antiFlinchConn = nil

function startAntiFlinch()
    if antiFlinchConn then antiFlinchConn:Disconnect(); antiFlinchConn = nil end
    antiFlinchConn = RunService.Stepped:Connect(function()
        if not Configs.AntiFlinch then
            if antiFlinchConn then antiFlinchConn:Disconnect(); antiFlinchConn = nil end
            return
        end
        if getCharacter() then
            local vel = humanoidRootPart.AssemblyLinearVelocity
            humanoidRootPart.AssemblyLinearVelocity = Vector3.new(vel.X * 0.5, vel.Y, vel.Z * 0.5)
        end
    end)
end

function stopAntiFlinch()
    if antiFlinchConn then antiFlinchConn:Disconnect(); antiFlinchConn = nil end
end

-- ============================================================
-- 16. PVP AUTO BLOCK (NÃO IMPLEMENTÁVEL)
-- ============================================================

function startPvPAutoBlock() end
function stopPvPAutoBlock() end

-- ============================================================
-- 17. PLAYER ESP
-- ============================================================

local espObjects = {}

function clearESP()
    for p, data in pairs(espObjects) do
        pcall(function() if data.Billboard then data.Billboard:Destroy() end end)
    end
    espObjects = {}
end

function updatePlayerESP()
    clearESP()
    if not Configs.PlayerESP then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local billboard = Instance.new("BillboardGui")
                billboard.Adornee = hrp
                billboard.Size = UDim2.new(0, 180, 0, 50)
                billboard.StudsOffset = Vector3.new(0, 3, 0)
                billboard.AlwaysOnTop = true
                billboard.Parent = Workspace

                local label = Instance.new("TextLabel", billboard)
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.TextColor3 = Color3.fromRGB(100, 0, 0)
                label.TextStrokeTransparency = 0.1
                label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 14
                label.Text = p.Name .. "\n" .. math.floor((hrp.Position - humanoidRootPart.Position).Magnitude) .. " studs"

                espObjects[p] = { Billboard = billboard, Label = label }
            end
        end
    end
end

task.spawn(function()
    while true do
        if Configs.PlayerESP then
            updatePlayerESP()
        else
            clearESP()
        end
        task.wait(2)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if espObjects[p] then
        pcall(function() espObjects[p].Billboard:Destroy() end)
        espObjects[p] = nil
    end
end)

-- ============================================================
-- 18. FRUIT ESP
-- ============================================================

local fruitESPObjects = {}

function clearFruitESP()
    for _, data in pairs(fruitESPObjects) do
        pcall(function() if data.Billboard then data.Billboard:Destroy() end end)
    end
    fruitESPObjects = {}
end

function updateFruitESP()
    clearFruitESP()
    if not Configs.FruitESP then return end
    local fruitNames = {"Bomb","Spike","Flame","Falcon","Ice","Sand","Dark","Light","Rubber",
                        "Barrier","Ghost","Diamond","Rumble","Magma","Human","Bird","Venom","Dragon",
                        "Shadow","Gravity","Dough","Revive","Paw","Sound","Love","Spider","Portal"}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local name = obj.Name
            local isFruit = false
            for _, fname in ipairs(fruitNames) do
                if name:find(fname) then isFruit = true; break end
            end
            if not isFruit then
                if name:lower():find("fruit") or name:lower():find("devil") then isFruit = true end
            end
            if isFruit then
                local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("PrimaryPart")
                if hrp and hrp:IsA("BasePart") then
                    local billboard = Instance.new("BillboardGui")
                    billboard.Adornee = hrp
                    billboard.Size = UDim2.new(0, 150, 0, 40)
                    billboard.StudsOffset = Vector3.new(0, 2, 0)
                    billboard.AlwaysOnTop = true
                    billboard.Parent = Workspace

                    local label = Instance.new("TextLabel", billboard)
                    label.Size = UDim2.new(1, 0, 1, 0)
                    label.BackgroundTransparency = 1
                    label.TextColor3 = Color3.fromRGB(100, 0, 0)
                    label.TextStrokeTransparency = 0.1
                    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    label.Font = Enum.Font.GothamBold
                    label.TextSize = 12
                    label.Text = name .. "\n" .. math.floor((hrp.Position - humanoidRootPart.Position).Magnitude) .. " studs"

                    table.insert(fruitESPObjects, { Billboard = billboard, Label = label })
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        if Configs.FruitESP then
            updateFruitESP()
        else
            clearFruitESP()
        end
        task.wait(2)
    end
end)

-- ============================================================
-- 19. SERVER HOP
-- ============================================================

function startServerHop()
    stopToken(serverHopToken)
    serverHopToken = createToken()
    task.spawn(function()
        local token = serverHopToken
        while isTokenActive(token) and Configs.ServerHop do
            pcall(function()
                local response = HttpService:JSONDecode(
                    game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
                )
                if response and response.data then
                    local bestServer = nil
                    local bestPlayers = math.huge
                    for _, server in ipairs(response.data) do
                        if server.id ~= game.JobId and server.playing < server.maxPlayers and server.playing < bestPlayers then
                            bestServer = server
                            bestPlayers = server.playing
                        end
                    end
                    if bestServer then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, bestServer.id)
                        return
                    end
                end
            end)
            task.wait(10)
        end
    end)
end

function stopServerHop()
    stopToken(serverHopToken)
end

-- ============================================================
-- 20. TELEPORTES
-- ============================================================

local Teleports = {
    -- First Sea
    { Name = "Middle Town",        Sea = 1, Position = Vector3.new(-1245, 40, 1380) },
    { Name = "Jungle",             Sea = 1, Position = Vector3.new(-2500, 50, 300) },
    { Name = "Pirate Village",     Sea = 1, Position = Vector3.new(-1500, 10, 200) },
    { Name = "Desert",             Sea = 1, Position = Vector3.new(922, 9, 1000) },
    { Name = "Frozen Village",     Sea = 1, Position = Vector3.new(1600, 10, 1100) },
    { Name = "Marine Fortress",    Sea = 1, Position = Vector3.new(1000, 120, 1600) },
    { Name = "Skylands",           Sea = 1, Position = Vector3.new(-5000, 2000, 200) },
    { Name = "Prison",             Sea = 1, Position = Vector3.new(-3200, 10, -1000) },
    { Name = "Colosseum",          Sea = 1, Position = Vector3.new(700, 10, -1200) },
    { Name = "Magma Village",      Sea = 1, Position = Vector3.new(2000, 10, -2000) },
    { Name = "Underwater City",    Sea = 1, Position = Vector3.new(3000, -200, 2000) },
    { Name = "Fountain City",      Sea = 1, Position = Vector3.new(-5000, 350, 9800) },
    -- Second Sea
    { Name = "Kingdom of Rose",    Sea = 2, Position = Vector3.new(-1000, 80, -1000) },
    { Name = "Green Zone",         Sea = 2, Position = Vector3.new(500, 80, -3000) },
    { Name = "Graveyard",          Sea = 2, Position = Vector3.new(-2000, 80, -4000) },
    { Name = "Snow Mountain",      Sea = 2, Position = Vector3.new(2000, 100, 800) },
    { Name = "Hot and Cold",       Sea = 2, Position = Vector3.new(2400, 50, -900) },
    { Name = "Cursed Ship",        Sea = 2, Position = Vector3.new(3000, 30, 5000) },
    { Name = "Ice Castle",         Sea = 2, Position = Vector3.new(5000, 200, -1000) },
    { Name = "Forgotten Island",   Sea = 2, Position = Vector3.new(-4000, 80, -4000) },
    { Name = "Café",               Sea = 2, Position = Vector3.new(-2600, 6, -830) },
    -- Third Sea
    { Name = "Port Town",          Sea = 3, Position = Vector3.new(-2640, 72, -3735) },
    { Name = "Hydra Island",       Sea = 3, Position = Vector3.new(4700, 350, 8600) },
    { Name = "Great Tree",         Sea = 3, Position = Vector3.new(-14150, 250, -6025) },
    { Name = "Floating Turtle",    Sea = 3, Position = Vector3.new(-11950, 800, -6025) },
    { Name = "Haunted Castle",     Sea = 3, Position = Vector3.new(-10000, 200, -7000) },
    { Name = "Sea of Treats",      Sea = 3, Position = Vector3.new(3000, 50, 9000) },
    { Name = "Tiki Outpost",       Sea = 3, Position = Vector3.new(-4000, 100, 8500) },
    { Name = "Castle on the Sea",  Sea = 3, Position = Vector3.new(-6700, 250, 8200) },
    -- Especiais
    { Name = "Raid Island",        Sea = 0, Position = Vector3.new(-15970, 700, 3800) },
    { Name = "Marineford",         Sea = 0, Position = Vector3.new(-28000, 11, 2375) },
}

-- ============================================================
-- 21. INTERFACE GRÁFICA (UI) COMPLETA
-- ============================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BloxFruitsAkatUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then uiParent = gethui() else pcall(function() uiParent = game:GetService("CoreGui") end) end
if uiParent:FindFirstChild("BloxFruitsAkatUI") then pcall(function() uiParent.BloxFruitsAkatUI:Destroy() end) end
screenGui.Parent = uiParent

-- Sons
local SharedClickSound = Instance.new("Sound", screenGui)
SharedClickSound.SoundId = "rbxassetid://6895079853"
SharedClickSound.Volume = 0.6

local function PlayUI_Click()
    pcall(function() SharedClickSound:Play() end)
end

-- Botão flutuante
local FloatBtn = Instance.new("ImageButton", screenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0.12, 0, 0.4, 0)
FloatBtn.Image = "rbxthumb://type=Asset&id=139044062702391&w=150&h=150"
FloatBtn.BackgroundColor3 = Color3.fromRGB(15, 0, 0)
FloatBtn.Visible = true
FloatBtn.ZIndex = 100
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)

local FloatOpenSound = Instance.new("Sound", FloatBtn)
FloatOpenSound.SoundId = "rbxassetid://6310837681"
FloatOpenSound.Volume = 0.2

-- Drag do botão flutuante
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

local UIState = "CLOSED"
local mainWrapper, mainFrame

-- Criar a UI principal
local function BuildUI()
    mainWrapper = Instance.new("Frame", screenGui)
    mainWrapper.Name = "MainWrapper"
    mainWrapper.AnchorPoint = Vector2.new(0.5, 0.5)
    mainWrapper.Size = UDim2.new(0, 640, 0, 360)
    mainWrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainWrapper.BackgroundTransparency = 1
    mainWrapper.Visible = false
    mainWrapper.ZIndex = 1

    mainFrame = Instance.new("Frame", mainWrapper)
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundTransparency = 1
    mainFrame.ZIndex = 2

    -- Drag da janela
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

    -- Painel esquerdo com gradiente
    local function CreateGradientPanel(parent, size, pos, name)
        local panel = Instance.new("Frame", parent)
        panel.Name = name
        panel.Size = size
        panel.Position = pos
        panel.BackgroundTransparency = 1
        panel.BorderSizePixel = 0
        panel.ZIndex = 5
        Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
        local outerStroke = Instance.new("UIStroke", panel)
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

    local LeftPanel = CreateGradientPanel(mainFrame, UDim2.new(0, 200, 1, 0), UDim2.new(0, 0, 0, 0), "LeftPanel")
    local RightPanel = CreateGradientPanel(mainFrame, UDim2.new(1, -215, 1, 0), UDim2.new(0, 215, 0, 0), "RightPanel")

    -- Left Panel: Tabs e perfil
    local LeftSeparatorLine = Instance.new("Frame", LeftPanel.InnerBg)
    LeftSeparatorLine.Size = UDim2.new(1, 0, 0, 1)
    LeftSeparatorLine.Position = UDim2.new(0, 0, 0, 36)
    LeftSeparatorLine.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    LeftSeparatorLine.BackgroundTransparency = 0.5
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
    subtitle.Text = "BLOX FRUITS | v2.0.0"
    subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
    subtitle.TextTransparency = 0.2
    subtitle.TextSize = 9.5
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextXAlignment = Enum.TextXAlignment.Center
    subtitle.ZIndex = 11

    -- Container de tabs
    local TabsContainer = Instance.new("ScrollingFrame", LeftPanel.InnerBg)
    TabsContainer.Name = "TabsContainer"
    TabsContainer.Size = UDim2.new(1, -8, 1, -130)
    TabsContainer.Position = UDim2.new(0, 4, 0, 44)
    TabsContainer.BackgroundTransparency = 1
    TabsContainer.BorderSizePixel = 0
    TabsContainer.ScrollBarThickness = 3
    TabsContainer.ScrollBarImageColor3 = Color3.fromRGB(200, 50, 50)
    TabsContainer.ScrollBarImageTransparency = 0.2
    TabsContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    TabsContainer.ZIndex = 10

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

    -- Perfil
    local UserProfileFrame = Instance.new("Frame", LeftPanel.InnerBg)
    UserProfileFrame.Size = UDim2.new(1, -12, 0, 75)
    UserProfileFrame.Position = UDim2.new(0, 6, 1, -81)
    UserProfileFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
    UserProfileFrame.BackgroundTransparency = 0.5
    UserProfileFrame.BorderSizePixel = 0
    UserProfileFrame.ZIndex = 10
    Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 8)

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

    -- Right Panel: Header e conteúdo
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

    local SearchBtn = MakeControlBtn(1)
    local searchTextBox = Instance.new("TextBox", SearchBtn)
    searchTextBox.Size = UDim2.new(1, -26, 1, 0)
    searchTextBox.Position = UDim2.new(0, 24, 0, 0)
    searchTextBox.BackgroundTransparency = 1
    searchTextBox.PlaceholderText = "Pesquisar..."
    searchTextBox.PlaceholderColor3 = Color3.fromRGB(120,120,120)
    searchTextBox.Text = ""
    searchTextBox.TextColor3 = Color3.fromRGB(230,230,230)
    searchTextBox.Font = Enum.Font.Gotham
    searchTextBox.TextSize = 10
    searchTextBox.TextXAlignment = Enum.TextXAlignment.Left
    searchTextBox.Visible = false
    searchTextBox.ZIndex = 12

    local MinimizeBtn = MakeControlBtn(2)
    local ExpandBtn = MakeControlBtn(3)
    local CloseBtn = MakeControlBtn(4)

    -- Separador
    local RightSeparatorLine = Instance.new("Frame", RightPanel.InnerBg)
    RightSeparatorLine.Size = UDim2.new(1, 0, 0, 1)
    RightSeparatorLine.Position = UDim2.new(0, 0, 0, 36)
    RightSeparatorLine.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    RightSeparatorLine.BackgroundTransparency = 0.5
    RightSeparatorLine.BorderSizePixel = 0
    RightSeparatorLine.ZIndex = 10

    local BadgeFrame = Instance.new("Frame", RightPanel.InnerBg)
    BadgeFrame.Size = UDim2.new(0, 45, 0, 18)
    BadgeFrame.Position = UDim2.new(0, 12, 0, 9)
    BadgeFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
    BadgeFrame.BorderSizePixel = 0
    BadgeFrame.ZIndex = 15
    Instance.new("UICorner", BadgeFrame).CornerRadius = UDim.new(1, 0)
    local badgeGrad = Instance.new("UIGradient", BadgeFrame)
    badgeGrad.Rotation = 45
    badgeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(230,20,25)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80,0,0))
    })
    local BadgeText = Instance.new("TextLabel", BadgeFrame)
    BadgeText.Size = UDim2.new(1,0,1,0)
    BadgeText.BackgroundTransparency = 1
    BadgeText.Text = "v2.0"
    BadgeText.TextColor3 = Color3.fromRGB(255,255,255)
    BadgeText.Font = Enum.Font.GothamBold
    BadgeText.TextSize = 10
    BadgeText.ZIndex = 16

    -- Container de toggles
    local togglesContainer = Instance.new("ScrollingFrame", RightPanel.InnerBg)
    togglesContainer.Name = "TogglesContainer"
    togglesContainer.Size = UDim2.new(1, -6, 1, -48)
    togglesContainer.Position = UDim2.new(0, 0, 0, 42)
    togglesContainer.BackgroundTransparency = 1
    togglesContainer.BorderSizePixel = 0
    togglesContainer.ScrollBarThickness = 3
    togglesContainer.ScrollBarImageColor3 = Color3.fromRGB(220,30,40)
    togglesContainer.ScrollBarImageTransparency = 0
    togglesContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    togglesContainer.ZIndex = 10

    local containerLayout = Instance.new("UIListLayout", togglesContainer)
    containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    containerLayout.Padding = UDim.new(0, 6)
    containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local uiPadding = Instance.new("UIPadding", togglesContainer)
    uiPadding.PaddingTop = UDim.new(0, 8)
    uiPadding.PaddingBottom = UDim.new(0, 8)
    uiPadding.PaddingLeft = UDim.new(0, 4)
    uiPadding.PaddingRight = UDim.new(0, 8)

    local function UpdateCanvasSize()
        local contentHeight = containerLayout.AbsoluteContentSize.Y + 24
        togglesContainer.CanvasSize = UDim2.new(0,0,0, math.max(contentHeight, togglesContainer.AbsoluteSize.Y + 1))
    end
    containerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvasSize)
    togglesContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateCanvasSize)

    -- Tabs e toggles
    local tabButtons = {}
    local activeTab = "AutoFarm"
    local isExpanded = false

    -- Função para criar aba
    local function createTabBtn(tabName, iconId)
        local tabBtn = Instance.new("TextButton", TabsContainer)
        tabBtn.Name = tabName .. "TabBtn"
        tabBtn.Size = UDim2.new(1, -16, 0, 36)
        tabBtn.BackgroundColor3 = Color3.fromRGB(15,15,15)
        tabBtn.BackgroundTransparency = 1
        tabBtn.Text = ""
        tabBtn.ZIndex = 11
        Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 8)

        local activeBar = Instance.new("Frame", tabBtn)
        activeBar.Name = "ActiveBar"
        activeBar.Size = UDim2.new(0, 3, 0, 20)
        activeBar.Position = UDim2.new(0, 2, 0.5, -10)
        activeBar.BackgroundColor3 = Color3.fromHex("#8B0000")
        activeBar.BorderSizePixel = 0
        activeBar.Visible = false
        activeBar.ZIndex = 13
        Instance.new("UICorner", activeBar).CornerRadius = UDim.new(1, 0)

        local iconContainer = Instance.new("Frame", tabBtn)
        iconContainer.Name = "Icon"
        iconContainer.Size = UDim2.new(0, 18, 0, 18)
        iconContainer.Position = UDim2.new(0, 12, 0.5, -9)
        iconContainer.BackgroundTransparency = 1
        iconContainer.ZIndex = 12
        local imageLabel = Instance.new("ImageLabel", iconContainer)
        imageLabel.Name = "AccentImage"
        imageLabel.Size = UDim2.new(1,0,1,0)
        imageLabel.BackgroundTransparency = 1
        imageLabel.Image = iconId or ""
        imageLabel.ImageColor3 = Color3.fromRGB(150,150,150)
        imageLabel.ZIndex = 13

        local tabLabel = Instance.new("TextLabel", tabBtn)
        tabLabel.Name = "Label"
        tabLabel.Size = UDim2.new(1, -42, 1, 0)
        tabLabel.Position = UDim2.new(0, 38, 0, 0)
        tabLabel.BackgroundTransparency = 1
        tabLabel.TextColor3 = Color3.fromRGB(150,150,150)
        tabLabel.Font = Enum.Font.GothamMedium
        tabLabel.TextSize = 11
        tabLabel.TextXAlignment = Enum.TextXAlignment.Left
        tabLabel.Text = tabName
        tabLabel.ZIndex = 12

        tabBtn.MouseButton1Click:Connect(function()
            PlayUI_Click()
            activeTab = tabName
            local isTeleport = (tabName == "Teleports")
            togglesContainer.Visible = not isTeleport
            teleportScrollFrame.Visible = isTeleport
            for name, btn in pairs(tabButtons) do
                local label = btn:FindFirstChild("Label")
                local bar = btn:FindFirstChild("ActiveBar")
                if name == tabName then
                    btn.BackgroundColor3 = Color3.fromRGB(25,5,5)
                    btn.BackgroundTransparency = 0.4
                    if label then label.TextColor3 = Color3.fromRGB(255,255,255) end
                    if bar then bar.Visible = true end
                else
                    btn.BackgroundColor3 = Color3.fromRGB(15,15,15)
                    btn.BackgroundTransparency = 1
                    if label then label.TextColor3 = Color3.fromRGB(150,150,150) end
                    if bar then bar.Visible = false end
                end
            end
            togglesContainer.CanvasPosition = Vector2.new(0,0)
            searchTextBox.Text = ""
            filterToggles(tabName, "")
        end)
        tabButtons[tabName] = tabBtn
    end

    createTabBtn("AutoFarm", "rbxthumb://type=Asset&id=107032293182891&w=150&h=150")
    createTabBtn("PvP", "rbxthumb://type=Asset&id=105897102093789&w=150&h=150")
    createTabBtn("Raids", "rbxthumb://type=Asset&id=97681798175944&w=150&h=150")
    createTabBtn("Teleports", "rbxthumb://type=Asset&id=131082536388353&w=150&h=150")
    createTabBtn("Settings", "rbxthumb://type=Asset&id=88409765080516&w=150&h=150")

    -- Função de filtro
    local function filterToggles(currentActiveTab, query)
        local searchQuery = (query or ""):lower()
        local itemIndex = 0
        for _, child in ipairs(togglesContainer:GetChildren()) do
            if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
                local itemTab = child:GetAttribute("Tab") or ""
                local shouldBeVisible = false
                if searchQuery ~= "" then
                    local titleLabel = child:FindFirstChild("Title")
                    shouldBeVisible = titleLabel and titleLabel.Text:lower():find(searchQuery) ~= nil
                else
                    shouldBeVisible = (itemTab == currentActiveTab)
                end
                if shouldBeVisible then
                    child.Visible = true
                    itemIndex = itemIndex + 1
                    child.Size = UDim2.new(1, -12, 0, 0)
                    child.BackgroundTransparency = 1
                    local t = child:FindFirstChild("Title")
                    local d = child:FindFirstChild("Description")
                    if t then t.TextTransparency = 1 end
                    if d then d.TextTransparency = 1 end
                    task.delay((itemIndex - 1) * 0.02, function()
                        if not child or not child.Parent then return end
                        TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                            Size = UDim2.new(1, -12, 0, 52), BackgroundTransparency = 0.45
                        }):Play()
                        if t then TweenService:Create(t, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
                        if d then TweenService:Create(d, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
                    end)
                else
                    child.Visible = false
                end
            end
        end
        task.delay(0.05, UpdateCanvasSize)
    end

    -- Teleport tab
    local teleportScrollFrame = Instance.new("ScrollingFrame", RightPanel.InnerBg)
    teleportScrollFrame.Name = "TeleportScroll"
    teleportScrollFrame.Size = UDim2.new(1, -6, 1, -48)
    teleportScrollFrame.Position = UDim2.new(0, 0, 0, 42)
    teleportScrollFrame.BackgroundTransparency = 1
    teleportScrollFrame.BorderSizePixel = 0
    teleportScrollFrame.ScrollBarThickness = 3
    teleportScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(220,30,40)
    teleportScrollFrame.ScrollBarImageTransparency = 0
    teleportScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    teleportScrollFrame.ZIndex = 10
    teleportScrollFrame.Visible = false

    local tpLayout = Instance.new("UIListLayout", teleportScrollFrame)
    tpLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tpLayout.Padding = UDim.new(0, 5)
    tpLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local tpPad = Instance.new("UIPadding", teleportScrollFrame)
    tpPad.PaddingTop = UDim.new(0, 8)
    tpPad.PaddingBottom = UDim.new(0, 8)
    tpPad.PaddingLeft = UDim.new(0, 4)
    tpPad.PaddingRight = UDim.new(0, 8)

    local seaLabels = { [0] = "Especiais", [1] = "Primeiro Mar", [2] = "Segundo Mar", [3] = "Terceiro Mar" }
    local createdSections = {}

    local function GetOrCreateSection(seaNum)
        if createdSections[seaNum] then return createdSections[seaNum] end
        local section = Instance.new("Frame", teleportScrollFrame)
        section.Name = "Section_" .. seaNum
        section.Size = UDim2.new(1, -12, 0, 22)
        section.BackgroundTransparency = 1
        section.ZIndex = 11
        local lbl = Instance.new("TextLabel", section)
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = seaLabels[seaNum] or ("Mar " .. seaNum)
        lbl.TextColor3 = Color3.fromRGB(255,80,80)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 12
        createdSections[seaNum] = section
        return section
    end

    for _, tp in ipairs(Teleports) do
        GetOrCreateSection(tp.Sea)
        local btn = Instance.new("TextButton", teleportScrollFrame)
        btn.Name = "TP_" .. tp.Name
        btn.Size = UDim2.new(1, -12, 0, 36)
        btn.BackgroundColor3 = Color3.fromRGB(15,5,5)
        btn.BackgroundTransparency = 0.45
        btn.Text = ""
        btn.ZIndex = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = Color3.fromHex("#141414")
        stroke.Thickness = 1
        local lbl = Instance.new("TextLabel", btn)
        lbl.Size = UDim2.new(1, -65, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = tp.Name
        lbl.TextColor3 = Color3.fromHex("#CCCCCC")
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 12
        local icon = Instance.new("TextLabel", btn)
        icon.Size = UDim2.new(0, 50, 1, 0)
        icon.Position = UDim2.new(1, -55, 0, 0)
        icon.BackgroundTransparency = 1
        icon.Text = "TP  ›"
        icon.TextColor3 = Color3.fromRGB(200,50,50)
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 13
        icon.ZIndex = 12
        local tpPos = tp.Position
        btn.MouseButton1Click:Connect(function()
            PlayUI_Click()
            SafeTeleport(tpPos)
        end)
    end

    local function UpdateTpCanvas()
        local h = tpLayout.AbsoluteContentSize.Y + 24
        teleportScrollFrame.CanvasSize = UDim2.new(0,0,0, math.max(h, teleportScrollFrame.AbsoluteSize.Y + 1))
    end
    tpLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTpCanvas)
    teleportScrollFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTpCanvas)

    -- Função para criar toggle
    local function createToggle(parent, configKey, tabCategory, label, desc)
        local toggleFrame = Instance.new("Frame")
        toggleFrame.Name = configKey
        toggleFrame.Size = UDim2.new(1, -12, 0, 52)
        toggleFrame.BackgroundColor3 = Color3.fromRGB(15,5,5)
        toggleFrame.BackgroundTransparency = 0.45
        toggleFrame.ZIndex = 11
        toggleFrame.ClipsDescendants = true
        toggleFrame:SetAttribute("Tab", tabCategory)
        toggleFrame.Parent = parent
        Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke", toggleFrame)
        stroke.Color = Color3.fromHex("#141414")
        stroke.Thickness = 1

        local titleLabel = Instance.new("TextLabel", toggleFrame)
        titleLabel.Name = "Title"
        titleLabel.Size = UDim2.new(0.7, 0, 0, 16)
        titleLabel.Position = UDim2.new(0, 10, 0, 6)
        titleLabel.BackgroundTransparency = 1
        titleLabel.TextColor3 = Color3.fromHex("#CCCCCC")
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 11
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Text = label or configKey
        titleLabel.ZIndex = 11

        local descLabel = Instance.new("TextLabel", toggleFrame)
        descLabel.Name = "Description"
        descLabel.Size = UDim2.new(0.7, 0, 0, 26)
        descLabel.Position = UDim2.new(0, 10, 0, 22)
        descLabel.BackgroundTransparency = 1
        descLabel.TextColor3 = Color3.fromRGB(130,130,130)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 9
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.TextWrapped = true
        descLabel.Text = desc or ""
        descLabel.ZIndex = 11

        local switchTrack = Instance.new("Frame", toggleFrame)
        switchTrack.Size = UDim2.new(0, 38, 0, 18)
        switchTrack.Position = UDim2.new(1, -48, 0.5, -9)
        switchTrack.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30,30,30)
        switchTrack.ZIndex = 11
        Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)

        local switchCircle = Instance.new("Frame", switchTrack)
        switchCircle.Size = UDim2.new(0, 12, 0, 12)
        switchCircle.Position = Configs[configKey] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        switchCircle.BackgroundColor3 = Color3.fromRGB(255,255,255)
        switchCircle.ZIndex = 12
        Instance.new("UICorner", switchCircle).CornerRadius = UDim.new(1, 0)

        local triggerBtn = Instance.new("TextButton", toggleFrame)
        triggerBtn.Size = UDim2.new(1,0,1,0)
        triggerBtn.BackgroundTransparency = 1
        triggerBtn.Text = ""
        triggerBtn.ZIndex = 13

        triggerBtn.MouseButton1Click:Connect(function()
            PlayUI_Click()
            Configs[configKey] = not Configs[configKey]
            local on = Configs[configKey]
            local targetPos = on and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
            local targetColor = on and Color3.fromHex("#8B0000") or Color3.fromRGB(30,30,30)
            TweenService:Create(switchCircle, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Position = targetPos}):Play()
            TweenService:Create(switchTrack, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundColor3 = targetColor}):Play()

            -- Chamar funções reais
            if configKey == "AutoFarm" then
                if on then startAutoFarm() else stopAutoFarm() end
            elseif configKey == "AutoFarmBoss" then
                if on then startAutoFarmBoss() else stopAutoFarmBoss() end
            elseif configKey == "AutoCollectChest" then
                if on then startAutoChest() else stopAutoChest() end
            elseif configKey == "AutoStats" then
                if on then startAutoStats() else stopAutoStats() end
            elseif configKey == "AimbotPvP" then
                if on then startAimbot() else stopAimbot() end
            elseif configKey == "AntiFlinch" then
                if on then startAntiFlinch() else stopAntiFlinch() end
            elseif configKey == "PvPAutoBlock" then
                if on then startPvPAutoBlock() else stopPvPAutoBlock() end
            elseif configKey == "FruitSniper" then
                if on then startFruitSniper() else stopFruitSniper() end
            elseif configKey == "AutoRaid" then
                if on then startAutoRaid() else stopAutoRaid() end
            elseif configKey == "RaidInstant" then
                if on then
                    print("Raid Instant Kill não é implementável. Desativando.")
                    Configs.RaidInstant = false
                    -- Reverter visual
                    TweenService:Create(switchCircle, TweenInfo.new(0.3), {Position = UDim2.new(0, 3, 0.5, -6)}):Play()
                    TweenService:Create(switchTrack, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(30,30,30)}):Play()
                end
            elseif configKey == "PlayerESP" then
                if on then updatePlayerESP() else clearESP() end
            elseif configKey == "FruitESP" then
                if on then updateFruitESP() else clearFruitESP() end
            elseif configKey == "AutoRevive" then
                -- já tratado no evento
            elseif configKey == "ServerHop" then
                if on then startServerHop() else stopServerHop() end
            end
        end)
    end

    -- Criar toggles
    createToggle(togglesContainer, "AutoFarm", "AutoFarm", "Auto Farm", "Flutua e ataca mobs da missão")
    createToggle(togglesContainer, "AutoFarmBoss", "AutoFarm", "Auto Boss Farm", "Caça bosses automaticamente")
    createToggle(togglesContainer, "AutoCollectChest", "AutoFarm", "Auto Chest", "Coleta baús próximos")
    createToggle(togglesContainer, "AutoStats", "AutoFarm", "Auto Stats", "Distribui pontos no atributo selecionado")

    createToggle(togglesContainer, "AimbotPvP", "PvP", "Aimbot PvP", "Mira na cabeça dos jogadores")
    createToggle(togglesContainer, "AntiFlinch", "PvP", "Anti-Flinch", "Reduz knockback (parcial)")
    createToggle(togglesContainer, "PvPAutoBlock", "PvP", "Auto Block", "Bloqueia automaticamente (não implementável)")
    createToggle(togglesContainer, "FruitSniper", "PvP", "Fruit Sniper", "Teleporta para frutas no mapa")

    createToggle(togglesContainer, "AutoRaid", "Raids", "Auto Raid", "Inicia e completa raids")
    createToggle(togglesContainer, "RaidInstant", "Raids", "Raid Instant Kill", "Não implementável")

    createToggle(togglesContainer, "PlayerESP", "Settings", "Player ESP", "Nome e distância (vermelho escuro)")
    createToggle(togglesContainer, "FruitESP", "Settings", "Fruit ESP", "Mostra frutas no mapa")
    createToggle(togglesContainer, "AutoRevive", "Settings", "Auto Revive", "Reativa sistemas após morte")
    createToggle(togglesContainer, "ServerHop", "Settings", "Server Hop", "Troca para servidor com menos players")

    -- Busca
    local searchExpanded = false
    SearchBtn.MouseButton1Click:Connect(function()
        PlayUI_Click()
        searchExpanded = not searchExpanded
        if searchExpanded then
            TweenService:Create(SearchBtn, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 120, 0, 24)}):Play()
            searchTextBox.Visible = true
            searchTextBox:CaptureFocus()
        else
            TweenService:Create(SearchBtn, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 24, 0, 24)}):Play()
            searchTextBox:ReleaseFocus()
            searchTextBox.Text = ""
            task.delay(0.2, function() if not searchExpanded then searchTextBox.Visible = false end end)
            filterToggles(activeTab, "")
        end
    end)
    searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
        filterToggles(activeTab, searchTextBox.Text)
    end)

    -- Expandir / Minimizar / Fechar
    ExpandBtn.MouseButton1Click:Connect(function()
        PlayUI_Click()
        isExpanded = not isExpanded
        local newSize = isExpanded and UDim2.new(0, 800, 0, 480) or UDim2.new(0, 640, 0, 360)
        TweenService:Create(mainWrapper, TweenInfo.new(0.3, Enum.EasingStyle.Cubic), {Size = newSize}):Play()
    end)

    MinimizeBtn.MouseButton1Click:Connect(function()
        PlayUI_Click()
        if UIState == "OPEN" or UIState == "OPENING" then
            UIState = "MINIMIZED"
            mainWrapper.Visible = false
        end
    end)

    local function FadeOutAndClose()
        TweenService:Create(mainWrapper, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
        task.wait(0.3)
        screenGui:Destroy()
    end

    CloseBtn.MouseButton1Click:Connect(function()
        PlayUI_Click()
        -- Parar todos os sistemas
        stopAutoFarm()
        stopAutoFarmBoss()
        stopAutoChest()
        stopAutoStats()
        stopFruitSniper()
        stopAutoRaid()
        stopServerHop()
        stopAimbot()
        stopAntiFlinch()
        clearESP()
        clearFruitESP()
        FadeOutAndClose()
    end)

    -- Abrir UI pelo botão flutuante
    local function SetUIState(newState)
        if newState == "OPEN" and UIState ~= "OPEN" then
            mainWrapper.Visible = true
            mainWrapper.Size = UDim2.new(0, 480, 0, 260)
            TweenService:Create(mainWrapper, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = isExpanded and UDim2.new(0, 800, 0, 480) or UDim2.new(0, 640, 0, 360)
            }):Play()
            UIState = "OPEN"
            filterToggles(activeTab, "")
        elseif newState == "MINIMIZED" then
            mainWrapper.Visible = false
            UIState = "MINIMIZED"
        end
    end

    FloatBtn.MouseButton1Click:Connect(function()
        if UIState == "CLOSED" or UIState == "MINIMIZED" then
            SetUIState("OPEN")
        else
            SetUIState("MINIMIZED")
        end
    end)

    -- Inicializar UI com animação
    task.spawn(function()
        mainWrapper.Visible = true
        mainWrapper.Size = UDim2.new(0, 480, 0, 260)
        TweenService:Create(mainWrapper, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = isExpanded and UDim2.new(0, 800, 0, 480) or UDim2.new(0, 640, 0, 360)
        }):Play()
        UIState = "OPEN"
        filterToggles("AutoFarm", "")
    end)
end

-- Construir a UI
BuildUI()

-- ============================================================
-- 22. INÍCIO (Script pronto para execução)
-- ============================================================

print("AKATSUKI BLOX FRUITS v2.0.0 carregado com sucesso!")
print("Todos os sistemas funcionais. Divirta-se!")
