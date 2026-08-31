--[[
    AKAT BLOX FRUITS FARM LOGIC
    Backend only — sem código de interface visual.
    Arquitetura: Farm Manager central + módulos de objetivo.
    Não contém bypass de anti-cheat/detecção.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer

if _G.AkatLogicRunning and _G.AkatCallbacks and _G.AkatCallbacks.ShutdownAll then
    pcall(_G.AkatCallbacks.ShutdownAll)
end

_G.AkatLogicRunning = true
local scriptAlive = true

local Configs = {
    AutoFarm = false, AutoQuest = true, AutoLevel = true, KillAura = true,
    FightingStyle = "Current", FarmPosition = "Above NPC", FarmHeightValue = 8,
    AutoMastery = false, MasteryType = "Fighting Style", TargetMastery = 300,
    AutoBoss = false, BossSelection = "Available Boss", BossName = "Any Boss", BossQuest = false,
    AutoMaterial = false, MaterialSelection = "Any", MaterialAmount = 100,
    DetectFruit = false, FruitNotification = true, FruitFilter = "Any", SelectedFruit = "Any",
    AutoSeaEvent = false, EventSelection = "Any", SelectedEvent = "Any",
    AutoStats = false, PrimaryStat = "Blox Fruit", SecondaryStat = "Defense", TertiaryStat = "Melee",
    AutoServerSearch = false, ServerReason = "Boss",
    Speed = false, SpeedValue = 16, JumpPower = false, JumpPowerValue = 50,
    AntiFling = false, ESP = false, Name = false, Tracer = false, XRay = false,
    ViewReach = false, Debug = false,
}
_G.Configs = Configs

local FarmState = {
    State = "Idle",
    CurrentTask = "Level Farm",
    CurrentTarget = nil,
    CurrentQuest = nil,
    CurrentArea = nil,
    Level = 0,
    Progress = "0%",
    Generation = 0,
    Character = nil,
}
_G.AkatFarmStatus = {
    State="Idle", CurrentTask="Level Farm", CurrentTarget="-",
    CurrentQuest="-", CurrentArea="-", Level=0, Progress="0%"
}

local controllerBusy = false
local movementToken = 0
local heartbeatConnection = nil
local characterConnection = nil
local playerAddedConnection = nil
local playerRemovingConnection = nil

local function status(state, taskName, target, quest, area, level, progress)
    FarmState.State = state or FarmState.State
    FarmState.CurrentTask = taskName or FarmState.CurrentTask
    FarmState.CurrentTarget = target
    FarmState.CurrentQuest = quest
    FarmState.CurrentArea = area
    FarmState.Level = level or FarmState.Level
    FarmState.Progress = progress or FarmState.Progress

    _G.AkatFarmStatus.State = FarmState.State
    _G.AkatFarmStatus.CurrentTask = FarmState.CurrentTask or "-"
    _G.AkatFarmStatus.CurrentTarget = FarmState.CurrentTarget or "-"
    _G.AkatFarmStatus.CurrentQuest = FarmState.CurrentQuest or "-"
    _G.AkatFarmStatus.CurrentArea = FarmState.CurrentArea or "-"
    _G.AkatFarmStatus.Level = FarmState.Level or 0
    _G.AkatFarmStatus.Progress = FarmState.Progress or "0%"
end

local function debugLog(msg)
    if Configs.Debug then warn("[AKAT][Blox Fruits] "..tostring(msg)) end
end

local function getCharacter()
    local char = player.Character
    if not char or not char.Parent then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return nil end
    return char, hum, root
end

local function isAlive()
    local _, hum = getCharacter()
    return hum and hum.Health > 0
end

local function findNumberValue(root, names)
    if not root then return nil end
    for _, name in ipairs(names) do
        local obj = root:FindFirstChild(name, true)
        if obj and (obj:IsA("IntValue") or obj:IsA("NumberValue")) then
            return obj.Value
        end
    end
    return nil
end

local function getLevel()
    local leaderstats = player:FindFirstChild("leaderstats")
    local data = player:FindFirstChild("Data")
    local level = findNumberValue(leaderstats, {"Level"})
        or findNumberValue(data, {"Level"})
        or findNumberValue(player, {"Level"})
    return tonumber(level) or 0
end

local function getSea()
    local data = player:FindFirstChild("Data")
    local spawn = data and data:FindFirstChild("LastSpawnPoint")
    local text = spawn and tostring(spawn.Value):lower() or ""

    if workspace:FindFirstChild("Third Sea") or text:find("third") then return 3 end
    if workspace:FindFirstChild("Second Sea") or text:find("second") then return 2 end
    if workspace:FindFirstChild("First Sea") or text:find("first") then return 1 end

    local map = workspace:FindFirstChild("Map")
    if map then
        local n = map.Name:lower()
        if n:find("third") then return 3 end
        if n:find("second") then return 2 end
    end
    return 1
end

-- Quest metadata is intentionally conservative: only entries whose target/giver can
-- actually be resolved in the live place are used. Missing entries are skipped.
local QuestTable = {
    {min=1,max=9,quest="BanditQuest1",questName="Bandit Quest",giver="Bandit Quest Giver",target="Bandit",qnum=1},
    {min=10,max=14,quest="JungleQuest",questName="Monkey Quest",giver="Jungle Quest Giver",target="Monkey",qnum=1},
    {min=15,max=29,quest="JungleQuest",questName="Gorilla Quest",giver="Jungle Quest Giver",target="Gorilla",qnum=2},
    {min=30,max=39,quest="BuggyQuest1",questName="Pirate Quest",giver="Pirate Quest Giver",target="Pirate",qnum=1},
    {min=40,max=59,quest="BuggyQuest1",questName="Brute Quest",giver="Pirate Quest Giver",target="Brute",qnum=2},
    {min=60,max=74,quest="DesertQuest",questName="Desert Bandit Quest",giver="Desert Quest Giver",target="Desert Bandit",qnum=1},
    {min=75,max=89,quest="DesertQuest",questName="Desert Officer Quest",giver="Desert Quest Giver",target="Desert Officer",qnum=2},
    {min=90,max=99,quest="SnowQuest",questName="Snow Bandit Quest",giver="Snow Quest Giver",target="Snow Bandit",qnum=1},
    {min=100,max=119,quest="SnowQuest",questName="Snowman Quest",giver="Snow Quest Giver",target="Snowman",qnum=2},
    {min=120,max=149,quest="MarineQuest2",questName="Chief Petty Officer Quest",giver="Marine Quest Giver",target="Chief Petty Officer",qnum=1},
    {min=150,max=174,quest="SkyQuest",questName="Sky Bandit Quest",giver="Sky Quest Giver",target="Sky Bandit",qnum=1},
    {min=175,max=224,quest="SkyQuest",questName="Dark Master Quest",giver="Sky Quest Giver",target="Dark Master",qnum=2},
    {min=225,max=249,quest="PrisonerQuest",questName="Prisoner Quest",giver="Prisoner Quest Giver",target="Prisoner",qnum=1},
    {min=250,max=299,quest="PrisonerQuest",questName="Dangerous Prisoner Quest",giver="Prisoner Quest Giver",target="Dangerous Prisoner",qnum=2},
    {min=300,max=324,quest="ColosseumQuest",questName="Toga Warrior Quest",giver="Colosseum Quest Giver",target="Toga Warrior",qnum=1},
    {min=325,max=374,quest="ColosseumQuest",questName="Gladiator Quest",giver="Colosseum Quest Giver",target="Gladiator",qnum=2},
    {min=375,max=399,quest="MagmaQuest",questName="Military Soldier Quest",giver="Magma Quest Giver",target="Military Soldier",qnum=1},
    {min=400,max=449,quest="MagmaQuest",questName="Military Spy Quest",giver="Magma Quest Giver",target="Military Spy",qnum=2},
    {min=450,max=474,quest="ImpelQuest",questName="Warden Quest",giver="Impel Quest Giver",target="Warden",qnum=1},
    {min=475,max=524,quest="ImpelQuest",questName="Chief Warden Quest",giver="Impel Quest Giver",target="Chief Warden",qnum=2},
    {min=525,max=549,quest="SwanQuest",questName="Swan Pirate Quest",giver="Swan Pirate Quest Giver",target="Swan Pirate",qnum=1},
    {min=550,max=624,quest="Area2Quest",questName="Factory Staff Quest",giver="Area 2 Quest Giver",target="Factory Staff",qnum=1},
}

local function resolveQuest(level)
    local best
    for _, q in ipairs(QuestTable) do
        if level >= q.min and level <= q.max then best = q break end
    end
    return best
end

local function findDescendantByNames(root, names, className)
    if not root then return nil end
    local wanted = {}
    for _, n in ipairs(names) do wanted[tostring(n):lower()] = true end
    for _, d in ipairs(root:GetDescendants()) do
        if (not className or d:IsA(className)) and wanted[d.Name:lower()] then return d end
    end
    return nil
end

local function getHumanoid(model)
    return model and model:FindFirstChildOfClass("Humanoid")
end

local function isValidNPC(model, targetName)
    if not model or not model.Parent or not model:IsA("Model") then return false end
    local hum = getHumanoid(model)
    local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    if not hum or hum.Health <= 0 or not root then return false end
    if targetName and targetName ~= "" then
        return model.Name:lower():find(tostring(targetName):lower(), 1, true) ~= nil
    end
    return true
end

local function findTarget(targetName)
    local _, _, myRoot = getCharacter()
    if not myRoot then return nil end

    local best, bestDist = nil, math.huge
    local map = workspace:FindFirstChild("Enemies") or workspace
    for _, d in ipairs(map:GetDescendants()) do
        if d:IsA("Model") and isValidNPC(d, targetName) then
            local root = d:FindFirstChild("HumanoidRootPart") or d.PrimaryPart
            if root then
                local dist = (myRoot.Position - root.Position).Magnitude
                if dist < bestDist then best, bestDist = d, dist end
            end
        end
    end
    return best
end

local function findQuestGiver(quest)
    if not quest then return nil end
    local names = {quest.giver, quest.questName, "Quest Giver", "Quest"}
    return findDescendantByNames(workspace, names, nil)
end

local function getRemote(name)
    local direct = ReplicatedStorage:FindFirstChild(name, true)
    return direct and (direct:IsA("RemoteFunction") or direct:IsA("RemoteEvent")) and direct or nil
end

local CommF = nil
local function refreshRemotes()
    CommF = getRemote("CommF_") or getRemote("CommF") or getRemote("CommF_")
end

local function invokeRemote(remote, ...)
    if not remote then return false, nil end
    local args = {...}
    if remote:IsA("RemoteFunction") then
        local ok, result = pcall(function() return remote:InvokeServer(table.unpack(args)) end)
        return ok, result
    elseif remote:IsA("RemoteEvent") then
        local ok = pcall(function() remote:FireServer(table.unpack(args)) end)
        return ok, nil
    end
    return false, nil
end

local function acceptQuest(quest)
    refreshRemotes()
    if not CommF or not quest then return false end
    -- Uses only the live-discovered CommF_ endpoint; if its protocol differs,
    -- fail safely instead of inventing another remote.
    local ok = invokeRemote(CommF, "StartQuest", quest.quest, quest.qnum or 1)
    return ok
end

local function questIsActive()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextLabel") and d.Visible then
            local t = d.Text:lower()
            if t:find("defeat") or t:find("kill") or t:find("eliminate") then return true end
        end
    end
    return false
end

local function equipToolByName(name)
    local char, hum = getCharacter()
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not hum or not backpack then return false end
    local wanted = tostring(name or ""):lower()

    local tool = nil
    if wanted ~= "" and wanted ~= "current" then
        tool = findDescendantByNames(char, {name}, "Tool")
            or findDescendantByNames(backpack, {name}, "Tool")
    end

    if not tool then
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") then tool = t break end
        end
    end

    if tool then
        pcall(function() hum:EquipTool(tool) end)
        return true
    end
    return false
end

local function equipSelectedStyle()
    local choice = Configs.FightingStyle
    if choice == "Current" then return true end
    if choice == "Melee" then
        -- No invented remote: keep current equipped combat tool/style.
        return equipToolByName("Combat") or true
    end
    return equipToolByName(choice)
end

local function attackTarget(target)
    if not Configs.KillAura or not target then return false end
    local _, hum = getCharacter()
    if not hum then return false end

    local choice = Configs.FightingStyle
    if choice ~= "Current" and choice ~= "Melee" then
        equipToolByName(choice)
    end

    local char = player.Character
    if not char then return false end

    -- Tool:Activate is a standard Roblox API. It is used only if the selected
    -- equipment is a real Tool; otherwise the manager safely waits for a valid one.
    local activated = false
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then
            local n = item.Name:lower()
            if choice == "Current" or choice == "Melee" or n:find(choice:lower(),1,true) then
                pcall(function() item:Activate() end)
                activated = true
                break
            end
        end
    end
    return activated
end

local function farmCFrame(targetRoot)
    local mode = Configs.FarmPosition
    local h = math.max(2, tonumber(Configs.FarmHeightValue) or 8)
    if mode == "Behind NPC" then return targetRoot.CFrame * CFrame.new(0, 0, h * 0.5) end
    if mode == "Front of NPC" then return targetRoot.CFrame * CFrame.new(0, 0, -h * 0.5) end
    if mode == "Near NPC" then return targetRoot.CFrame * CFrame.new(0, 2.5, 3) end
    return targetRoot.CFrame * CFrame.new(0, h, 0)
end

local function maintainPosition(target)
    local _, _, root = getCharacter()
    local targetRoot = target and (target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart)
    if not root or not targetRoot then return false end
    local cf = farmCFrame(targetRoot)
    movementToken += 1
    local token = movementToken
    pcall(function()
        root.CFrame = cf
    end)
    return token == movementToken
end

local function inventoryAmount(name)
    local inv = player:FindFirstChild("Inventory") or player:FindFirstChild("Data")
    if not inv then return 0 end
    local obj = findDescendantByNames(inv, {name}, nil)
    if obj and (obj:IsA("IntValue") or obj:IsA("NumberValue")) then return obj.Value end
    return 0
end

local function currentMastery()
    local char = player.Character
    if not char then return 0 end
    for _, d in ipairs(char:GetDescendants()) do
        if (d:IsA("IntValue") or d:IsA("NumberValue")) and d.Name:lower():find("mastery") then
            return tonumber(d.Value) or 0
        end
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, d in ipairs(backpack:GetDescendants()) do
            if (d:IsA("IntValue") or d:IsA("NumberValue")) and d.Name:lower():find("mastery") then
                return tonumber(d.Value) or 0
            end
        end
    end
    return 0
end

local function distributeStats()
    if not Configs.AutoStats then return end
    refreshRemotes()
    if not CommF then return end

    local priorities = {Configs.PrimaryStat, Configs.SecondaryStat, Configs.TertiaryStat}
    for _, stat in ipairs(priorities) do
        if stat and stat ~= "" then
            -- The server decides whether points are available. If this exact
            -- command is rejected, the manager simply continues.
            invokeRemote(CommF, "AddPoint", stat, 1)
        end
    end
end

local function detectFruit()
    local found
    for _, d in ipairs(workspace:GetDescendants()) do
        if (d:IsA("Tool") or d:IsA("Model")) and d.Name:lower():find("fruit") then
            if Configs.FruitFilter == "Selected Fruit" and Configs.SelectedFruit ~= "Any" and not d.Name:lower():find(Configs.SelectedFruit:lower(),1,true) then continue end
            found = d
            break
        end
    end
    return found
end

local function detectEvent()
    local keywords = {"event","sea event","ship","mirage","terror","fish","leviathan","raid"}
    local selected = Configs.EventSelection == "Selected Event" and Configs.SelectedEvent or nil
    for _, d in ipairs(workspace:GetDescendants()) do
        local n = d.Name:lower()
        if selected and selected ~= "Any" then
            if n:find(selected:lower(),1,true) then return d end
        else
            for _, k in ipairs(keywords) do
                if n:find(k,1,true) then return d end
            end
        end
    end
end

local function findBoss()
    local mode = Configs.BossSelection
    local wanted = mode == "Selected Boss" and Configs.BossName or nil
    local best
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") and isValidNPC(d) then
            local n = d.Name:lower()
            local isBossLike = n:find("boss") or n:find("rip indra") or n:find("rip_indra")
                or n:find("cake prince") or n:find("longma") or n:find("swan")
            if isBossLike then
                if not wanted or wanted == "Any Boss" or n:find(tostring(wanted):lower(), 1, true) then
                    return d
                end
                best = best or d
            end
        end
    end
    return mode == "Selected Boss" and nil or best
end

local function findMaterialTarget()
    local wanted = Configs.MaterialSelection
    if wanted == "Any" then return findTarget(nil) end
    return findTarget(wanted)
end

local function serverSearch()
    if not Configs.AutoServerSearch then return false end
    -- Only a standard Roblox teleport request is used; no anti-detection logic.
    local ok = pcall(function()
        TeleportService:Teleport(game.PlaceId, player)
    end)
    return ok
end

local function stopMovement()
    movementToken += 1
    local _, hum, root = getCharacter()
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.Anchored = false
    end
    if hum then
        hum.WalkSpeed = Configs.Speed and Configs.SpeedValue or 16
        hum.UseJumpPower = true
        hum.JumpPower = Configs.JumpPower and Configs.JumpPowerValue or 50
    end
end

local function clearFarmTarget()
    FarmState.CurrentTarget = nil
    status(FarmState.State, FarmState.CurrentTask, "-", FarmState.CurrentQuest or "-", FarmState.CurrentArea or "-", FarmState.Level, FarmState.Progress)
end

local function chooseObjective()
    local level = getLevel()
    local sea = getSea()
    local quest = resolveQuest(level)
    FarmState.Level = level
    FarmState.CurrentArea = "Sea "..tostring(sea)

    if Configs.AutoBoss then
        local boss = findBoss()
        if boss then return "Boss Farming", boss, nil end
    end

    if Configs.AutoMaterial then
        local target = findMaterialTarget()
        if target then return "Material Farming", target, quest end
    end

    if Configs.AutoMastery then
        local target = findTarget(quest and quest.target or nil)
        if target then return "Mastery Farming", target, quest end
    end

    local target = findTarget(quest and quest.target or nil)
    if target then return "Level Farm", target, quest end
    return "Level Farm", nil, quest
end

local function farmStep()
    if not Configs.AutoFarm then return end
    if not isAlive() then
        status("Character Dead","Level Farm","-","-","-",
            getLevel(),"Waiting respawn")
        return
    end

    local char = player.Character
    FarmState.Character = char
    local level = getLevel()
    local sea = getSea()
    status("Checking Level","Level Farm","-",
        FarmState.CurrentQuest or "-", "Sea "..sea, level, FarmState.Progress)

    local taskName, target, quest = chooseObjective()
    FarmState.CurrentTask = taskName
    FarmState.CurrentQuest = quest and quest.questName or "-"
    FarmState.CurrentArea = "Sea "..sea

    if not target then
        if Configs.AutoQuest and quest and not questIsActive() then
            status("Finding Quest",taskName,"-",quest.questName,FarmState.CurrentArea,level,"Waiting")
            local giver = findQuestGiver(quest)
            if giver then
                local giverRoot = giver:FindFirstChild("HumanoidRootPart") or giver.PrimaryPart or giver:FindFirstChildWhichIsA("BasePart")
                local _,_,root = getCharacter()
                if giverRoot and root then
                    root.CFrame = giverRoot.CFrame * CFrame.new(0,3,0)
                    task.wait(0.15)
                end
                acceptQuest(quest)
            end
        end
        status("Finding Target",taskName,"-",FarmState.CurrentQuest,FarmState.CurrentArea,level,"Waiting")
        return
    end

    FarmState.CurrentTarget = target.Name
    status("Traveling",taskName,target.Name,FarmState.CurrentQuest,FarmState.CurrentArea,level,FarmState.Progress)
    maintainPosition(target)
    status("Positioning",taskName,target.Name,FarmState.CurrentQuest,FarmState.CurrentArea,level,FarmState.Progress)
    equipSelectedStyle()

    while Configs.AutoFarm and scriptAlive and target and target.Parent do
        local _, hum, root = getCharacter()
        local targetRoot = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
        local targetHum = getHumanoid(target)
        if not hum or hum.Health <= 0 then
            status("Character Dead",taskName,target.Name,FarmState.CurrentQuest,FarmState.CurrentArea,level,"Waiting respawn")
            return
        end
        if not targetHum or targetHum.Health <= 0 or not targetRoot then break end

        local desired = farmCFrame(targetRoot)
        if (root.Position - desired.Position).Magnitude > 3 then
            root.CFrame = desired
        else
            pcall(function() root.CFrame = desired end)
        end

        attackTarget(target)

        local hp = math.max(0, targetHum.Health)
        local maxHp = math.max(1, targetHum.MaxHealth)
        local progress = math.floor((1 - hp/maxHp)*100)
        status("Farming",taskName,target.Name,FarmState.CurrentQuest,FarmState.CurrentArea,level,tostring(progress).."%")
        task.wait(0.08)
    end

    clearFarmTarget()
    status("Target Dead",taskName,"-",FarmState.CurrentQuest,FarmState.CurrentArea,level,"Next target")
end

local function farmManagerLoop()
    if controllerBusy then return end
    controllerBusy = true
    FarmState.Generation += 1
    local generation = FarmState.Generation

    task.spawn(function()
        while scriptAlive and Configs.AutoFarm and generation == FarmState.Generation do
            local ok, err = pcall(farmStep)
            if not ok then
                debugLog("Farm Manager recovery: "..tostring(err))
                status("Error Recovery","Level Farm","-",FarmState.CurrentQuest or "-",FarmState.CurrentArea or "-",getLevel(),"Retrying")
                clearFarmTarget()
                task.wait(0.4)
            else
                task.wait(0.12)
            end
        end
        controllerBusy = false
        if not Configs.AutoFarm then
            stopMovement()
            status("Stopped","Idle","-","-","-",getLevel(),"0%")
        end
    end)
end

local function toggleAutoFarm(enabled)
    Configs.AutoFarm = enabled and true or false
    FarmState.Generation += 1
    clearFarmTarget()

    if Configs.AutoFarm then
        local char, hum, root = getCharacter()
        if not char or not hum or not root then
            status("Initializing","Level Farm","-","-","-",getLevel(),"Waiting character")
            return
        end
        status("Initializing","Level Farm","-","-","-",getLevel(),"0%")
        farmManagerLoop()
    else
        stopMovement()
        status("Stopped","Idle","-","-","-",getLevel(),"0%")
    end
end

local function onCharacterAdded()
    FarmState.Generation += 1
    FarmState.CurrentTarget = nil
    FarmState.CurrentQuest = nil
    status(Configs.AutoFarm and "Initializing" or "Idle",
        Configs.AutoFarm and "Level Farm" or "Idle",
        "-", "-", "-", getLevel(), Configs.AutoFarm and "Waiting respawn" or "0%")
    task.wait(0.5)
    if Configs.AutoFarm then farmManagerLoop() end
end

_G.AkatCallbacks = {
    AutoFarm = toggleAutoFarm,
    AutoQuest = function(v) Configs.AutoQuest = v and true or false end,
    AutoLevel = function(v) Configs.AutoLevel = v and true or false end,
    FightingStyle = function(v) Configs.FightingStyle = tostring(v) end,
    KillAura = function(v) Configs.KillAura = v and true or false end,
    FarmPosition = function(v) Configs.FarmPosition = tostring(v) end,
    FarmHeight = function(v) Configs.FarmHeightValue = tonumber(v) or 8 end,

    AutoMastery = function(v) Configs.AutoMastery = v and true or false end,
    MasteryType = function(v) Configs.MasteryType = tostring(v) end,
    TargetMastery = function(v) Configs.TargetMastery = tonumber(v) or 300 end,

    AutoBoss = function(v) Configs.AutoBoss = v and true or false end,
    BossSelection = function(v) Configs.BossSelection = tostring(v) end,
    BossName = function(v) Configs.BossName = tostring(v) end,
    BossQuest = function(v) Configs.BossQuest = v and true or false end,

    AutoMaterial = function(v) Configs.AutoMaterial = v and true or false end,
    MaterialSelection = function(v) Configs.MaterialSelection = tostring(v) end,
    MaterialAmount = function(v) Configs.MaterialAmount = tonumber(v) or 100 end,

    DetectFruit = function(v) Configs.DetectFruit = v and true or false end,
    FruitNotification = function(v) Configs.FruitNotification = v and true or false end,
    FruitFilter = function(v) Configs.FruitFilter = tostring(v) end,
    SelectedFruit = function(v) Configs.SelectedFruit = tostring(v) end,

    AutoSeaEvent = function(v) Configs.AutoSeaEvent = v and true or false end,
    EventSelection = function(v) Configs.EventSelection = tostring(v) end,
    SelectedEvent = function(v) Configs.SelectedEvent = tostring(v) end,

    AutoStats = function(v) Configs.AutoStats = v and true or false end,
    PrimaryStat = function(v) Configs.PrimaryStat = tostring(v) end,
    SecondaryStat = function(v) Configs.SecondaryStat = tostring(v) end,
    TertiaryStat = function(v) Configs.TertiaryStat = tostring(v) end,

    AutoServerSearch = function(v) Configs.AutoServerSearch = v and true or false end,
    ServerReason = function(v) Configs.ServerReason = tostring(v) end,

    Speed = function(v)
        if type(v) == "number" then Configs.SpeedValue = v; Configs.Speed = true else Configs.Speed = v and true or false end
        if not Configs.AutoFarm then
            local _, hum = getCharacter()
            if hum then hum.WalkSpeed = Configs.Speed and Configs.SpeedValue or 16 end
        end
    end,
    JumpPower = function(v)
        if type(v) == "number" then Configs.JumpPowerValue = v; Configs.JumpPower = true else Configs.JumpPower = v and true or false end
        if not Configs.AutoFarm then
            local _, hum = getCharacter()
            if hum then hum.UseJumpPower = true; hum.JumpPower = Configs.JumpPower and Configs.JumpPowerValue or 50 end
        end
    end,
    AntiFling = function(v) Configs.AntiFling = v and true or false end,

    ESP = function(v) Configs.ESP = v and true or false end,
    Name = function(v) Configs.Name = v and true or false end,
    Tracer = function(v) Configs.Tracer = v and true or false end,
    XRay = function(v) Configs.XRay = v and true or false end,
    ViewReach = function(v) Configs.ViewReach = v and true or false end,

    ShutdownAll = function()
        scriptAlive = false
        Configs.AutoFarm = false
        FarmState.Generation += 1
        movementToken += 1
        stopMovement()
        status("Stopped","Idle","-","-","-",getLevel(),"0%")
        if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection=nil end
        if characterConnection then characterConnection:Disconnect(); characterConnection=nil end
        if playerAddedConnection then playerAddedConnection:Disconnect(); playerAddedConnection=nil end
        if playerRemovingConnection then playerRemovingConnection:Disconnect(); playerRemovingConnection=nil end
        _G.AkatLogicRunning = false
    end,
}

-- Single heartbeat only: movement/anti-fling housekeeping and lightweight detectors.
heartbeatConnection = RunService.Heartbeat:Connect(function()
    if not scriptAlive then return end
    if Configs.AntiFling then
        local _, hum, root = getCharacter()
        if hum and root and (root.AssemblyLinearVelocity.Magnitude > 80 or root.AssemblyAngularVelocity.Magnitude > 80) then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end

    if Configs.AutoLevel and Configs.AutoFarm then
        local level = getLevel()
        if level ~= FarmState.Level then
            FarmState.CurrentTarget = nil
            FarmState.CurrentQuest = nil
            status("Changing Area","Level Farm","-","-","Sea "..getSea(),level,"Updating")
        end
    end

    if Configs.AutoStats then distributeStats() end
    if Configs.DetectFruit then
        local fruit = detectFruit()
        if fruit then
            _G.AkatFarmStatus.CurrentTask = "Fruit Detected: "..fruit.Name
        end
    end
    if Configs.AutoSeaEvent then
        local event = detectEvent()
        if event then _G.AkatFarmStatus.CurrentTask = "Event: "..event.Name end
    end

    if Configs.AutoMastery and currentMastery() >= Configs.TargetMastery then
        Configs.AutoMastery = false
        if Configs.AutoFarm then
            status("Completed","Mastery Farming",FarmState.CurrentTarget or "-",FarmState.CurrentQuest or "-",FarmState.CurrentArea or "-",getLevel(),"100%")
        end
    end

    if Configs.AutoMaterial and Configs.MaterialSelection ~= "Any" then
        if inventoryAmount(Configs.MaterialSelection) >= Configs.MaterialAmount then
            Configs.AutoMaterial = false
            status("Completed","Material Farming","-",FarmState.CurrentQuest or "-",FarmState.CurrentArea or "-",getLevel(),"100%")
        end
    end
end)

characterConnection = player.CharacterAdded:Connect(onCharacterAdded)
playerAddedConnection = Players.PlayerAdded:Connect(function() end)
playerRemovingConnection = Players.PlayerRemoving:Connect(function() end)

refreshRemotes()
status("Idle","Level Farm","-","-","-",getLevel(),"0%")
