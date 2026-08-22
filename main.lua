-- [[ AKATSUKI BLOX FRUITS SCRIPT [v2.0.0] - FULL FIX & OPTIMIZED ]]
-- =====================================================================

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

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- ==================== CONFIGURAÇÕES PRINCIPAIS ====================
local Configs = {
    -- Auto Farm
    AutoFarm         = false,
    AutoFarmBoss     = false,
    AutoCollectChest = false,
    AutoStats        = false,
    SelectedStat     = "Melee", -- Melee, Defense, Sword, Gun, Demon Fruit

    -- PvP & Combat
    AimbotPvP        = false,
    AntiFlinch       = false,
    PvPAutoBlock     = false,
    FruitSniper      = false,

    -- Raid
    AutoRaid         = false,
    RaidInstant      = false,

    -- Visuais
    PlayerESP        = false,
    FruitESP         = false,

    -- Extras
    AutoRevive       = false,
    ServerHop        = false,
}

-- ==================== VARIÁVEIS DE CONTROLE DE THREADS ====================
local Threads = {
    AutoFarm    = nil,
    AutoBoss    = nil,
    AutoChest   = nil,
    AutoStats   = nil,
    AutoRaid    = nil,
    FruitSniper = nil,
}

local selectedBoss = "The Gorilla King"
local farmSafeDistance = 10 -- Distância flutuante
local camera = Workspace.CurrentCamera
local espObjects = {}
local fruitEspObjects = {}
local aimbotConnection = nil
local antiFlinchConn = nil

-- ==================== TABELA DE QUESTS ====================
local QuestsData = {
    -- Primeiro Mar (Sea 1)
    { MinLevel = 1,   MaxLevel = 14,  QuestName = "BanditQuest1",     QuestLevel = 1, EnemyName = "Bandit",                 NPC_Pos = Vector3.new(1059, 16, 1549),    Mob_Pos = Vector3.new(1190, 16, 1600) },
    { MinLevel = 15,  MaxLevel = 29,  QuestName = "JungleQuest",      QuestLevel = 1, EnemyName = "Monkey",                 NPC_Pos = Vector3.new(-1598, 37, 153),    Mob_Pos = Vector3.new(-1450, 26, 200) },
    { MinLevel = 30,  MaxLevel = 39,  QuestName = "JungleQuest",      QuestLevel = 2, EnemyName = "Gorilla",                NPC_Pos = Vector3.new(-1598, 37, 153),    Mob_Pos = Vector3.new(-1250, 6, -500) },
    { MinLevel = 40,  MaxLevel = 59,  QuestName = "PirateQuest",      QuestLevel = 1, EnemyName = "Pirate",                 NPC_Pos = Vector3.new(-1140, 4, 3828),    Mob_Pos = Vector3.new(-1200, 4, 3900) },
    { MinLevel = 60,  MaxLevel = 89,  QuestName = "DesertQuest",      QuestLevel = 1, EnemyName = "Desert Bandit",          NPC_Pos = Vector3.new(894, 6, 4388),      Mob_Pos = Vector3.new(950, 6, 4450) },
    { MinLevel = 90,  MaxLevel = 119, QuestName = "SnowQuest",        QuestLevel = 1, EnemyName = "Snow Bandit",            NPC_Pos = Vector3.new(1385, 87, -1298),   Mob_Pos = Vector3.new(1300, 87, -1350) },
    { MinLevel = 120, MaxLevel = 149, QuestName = "MarineQuest2",     QuestLevel = 1, EnemyName = "Chief Petty Officer",    NPC_Pos = Vector3.new(-5035, 29, 4325),   Mob_Pos = Vector3.new(-4800, 20, 4300) },
    { MinLevel = 150, MaxLevel = 189, QuestName = "SkyQuest",         QuestLevel = 1, EnemyName = "Sky Bandit",             NPC_Pos = Vector3.new(-4840, 718, -2620), Mob_Pos = Vector3.new(-4950, 718, -2900) },
    { MinLevel = 190, MaxLevel = 224, QuestName = "SkyQuest2",        QuestLevel = 1, EnemyName = "Toga Warrior",           NPC_Pos = Vector3.new(-4840, 718, -2620), Mob_Pos = Vector3.new(-4700, 845, -1900) },
    { MinLevel = 225, MaxLevel = 274, QuestName = "ColosseumQuest",   QuestLevel = 1, EnemyName = "Toga Warrior",           NPC_Pos = Vector3.new(-1580, 7, -2980),   Mob_Pos = Vector3.new(-1350, 7, -3100) },
    { MinLevel = 275, MaxLevel = 324, QuestName = "MagmaQuest",       QuestLevel = 1, EnemyName = "Military Soldier",       NPC_Pos = Vector3.new(-5310, 12, 8515),   Mob_Pos = Vector3.new(-5400, 12, 8500) },
    { MinLevel = 325, MaxLevel = 374, QuestName = "FishmanQuest",     QuestLevel = 1, EnemyName = "Fishman Warrior",        NPC_Pos = Vector3.new(60900, 18, 1500),   Mob_Pos = Vector3.new(61000, 18, 1200) },
    { MinLevel = 375, MaxLevel = 449, QuestName = "SkyExp1Quest",     QuestLevel = 1, EnemyName = "God's Guard",            NPC_Pos = Vector3.new(-4720, 845, -1950), Mob_Pos = Vector3.new(-4600, 845, -1800) },
    { MinLevel = 450, MaxLevel = 524, QuestName = "SkyExp2Quest",     QuestLevel = 1, EnemyName = "Shanda",                 NPC_Pos = Vector3.new(-7880, 5545, -380), Mob_Pos = Vector3.new(-7700, 5545, -500) },
    { MinLevel = 525, MaxLevel = 624, QuestName = "SkyExp2Quest",     QuestLevel = 2, EnemyName = "Royal Squad",            NPC_Pos = Vector3.new(-7880, 5545, -380), Mob_Pos = Vector3.new(-7900, 5545, -800) },
    { MinLevel = 625, MaxLevel = 699, QuestName = "FountainQuest",    QuestLevel = 1, EnemyName = "Galley Pirate",          NPC_Pos = Vector3.new(5258, 38, 4050),    Mob_Pos = Vector3.new(5500, 38, 3900) },
    { MinLevel = 700, MaxLevel = 9999,QuestName = "FountainQuest",    QuestLevel = 2, EnemyName = "Galley Captain",         NPC_Pos = Vector3.new(5258, 38, 4050),    Mob_Pos = Vector3.new(5600, 38, 4900) },
}

-- ==================== LISTA DE TELEPORTES ====================
local Teleports = {
    -- Primeiro Mar
    { Name = "Starter Marine",     Sea = 1, Position = Vector3.new(-2570, 7, 2050) },
    { Name = "Starter Pirate",     Sea = 1, Position = Vector3.new(1059, 16, 1549) },
    { Name = "Jungle",             Sea = 1, Position = Vector3.new(-1598, 37, 153) },
    { Name = "Pirate Village",     Sea = 1, Position = Vector3.new(-1140, 4, 3828) },
    { Name = "Desert",             Sea = 1, Position = Vector3.new(894, 6, 4388) },
    { Name = "Middle Town",        Sea = 1, Position = Vector3.new(-650, 15, 1550) },
    { Name = "Frozen Village",     Sea = 1, Position = Vector3.new(1385, 87, -1298) },
    { Name = "Marine Fortress",    Sea = 1, Position = Vector3.new(-5035, 29, 4325) },
    { Name = "Skylands",           Sea = 1, Position = Vector3.new(-4840, 718, -2620) },
    { Name = "Prison",             Sea = 1, Position = Vector3.new(4850, 5, 750) },
    { Name = "Colosseum",          Sea = 1, Position = Vector3.new(-1580, 7, -2980) },
    { Name = "Magma Village",      Sea = 1, Position = Vector3.new(-5310, 12, 8515) },
    { Name = "Underwater City",    Sea = 1, Position = Vector3.new(3850, 5, -1900) },
    { Name = "Fountain City",      Sea = 1, Position = Vector3.new(5258, 38, 4050) },

    -- Segundo Mar
    { Name = "Kingdom of Rose",    Sea = 2, Position = Vector3.new(-450, 73, 300) },
    { Name = "Café",               Sea = 2, Position = Vector3.new(-380, 73, 290) },
    { Name = "Green Zone",         Sea = 2, Position = Vector3.new(-2400, 73, -3200) },
    { Name = "Graveyard",          Sea = 2, Position = Vector3.new(-5400, 8, -700) },
    { Name = "Snow Mountain",      Sea = 2, Position = Vector3.new(600, 400, -5300) },
    { Name = "Hot and Cold",       Sea = 2, Position = Vector3.new(-6000, 15, -5000) },
    { Name = "Cursed Ship",        Sea = 2, Position = Vector3.new(920, 125, 32800) },
    { Name = "Ice Castle",         Sea = 2, Position = Vector3.new(5500, 28, -6200) },
    { Name = "Forgotten Island",   Sea = 2, Position = Vector3.new(-3050, 240, -10150) },

    -- Terceiro Mar
    { Name = "Port Town",          Sea = 3, Position = Vector3.new(-2900, 7, 5300) },
    { Name = "Hydra Island",       Sea = 3, Position = Vector3.new(5700, 600, 200) },
    { Name = "Great Tree",         Sea = 3, Position = Vector3.new(-2500, 10, -10500) },
    { Name = "Floating Turtle",    Sea = 3, Position = Vector3.new(-13200, 330, -7600) },
    { Name = "Castle on the Sea",  Sea = 3, Position = Vector3.new(-5000, 300, -3000) },
    { Name = "Haunted Castle",     Sea = 3, Position = Vector3.new(-9500, 140, 5500) },
    { Name = "Sea of Treats",      Sea = 3, Position = Vector3.new(-2100, 50, -12000) },
    { Name = "Tiki Outpost",       Sea = 3, Position = Vector3.new(-16100, 10, 200) },
}

-- ==================== UTILITÁRIOS ====================
local function CharacterReady()
    character = player.Character
    if not character then return false end
    humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    humanoid = character:FindFirstChild("Humanoid")
    return humanoidRootPart ~= nil and humanoid ~= nil and humanoid.Health > 0
end

local function SafeTeleport(pos)
    if not CharacterReady() then return end
    pcall(function()
        humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
        humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
        character:PivotTo(CFrame.new(pos))
        task.wait(0.05)
        humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
    end)
end

local function GetPlayerLevel()
    local data = player:FindFirstChild("Data")
    if data and data:FindFirstChild("Level") then
        return data.Level.Value
    end
    return 1
end

local function GetCurrentQuestInfo()
    local level = GetPlayerLevel()
    for _, q in ipairs(QuestsData) do
        if level >= q.MinLevel and level <= q.MaxLevel then
            return q
        end
    end
    return QuestsData[1]
end

local function GetTargetEnemy(enemyName)
    if not CharacterReady() then return nil end
    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    local searchFolder = enemiesFolder or Workspace

    local closest, dist = nil, math.huge
    for _, obj in ipairs(searchFolder:GetChildren()) do
        if obj:IsA("Model") and obj ~= character then
            if enemyName == nil or obj.Name == enemyName then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                if hum and hrp and hum.Health > 0 then
                    local d = (hrp.Position - humanoidRootPart.Position).Magnitude
                    if d < dist then
                        dist = d
                        closest = { Model = obj, HRP = hrp, Humanoid = hum }
                    end
                end
            end
        end
    end
    return closest
end

local function AutoAttack(targetModel)
    if not CharacterReady() then return end
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

    if tool then pcall(function() tool:Activate() end) end

    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local comm = remotes:FindFirstChild("CommF_") or remotes:FindFirstChild("Validator")
            if comm and comm:IsA("RemoteFunction") then
                comm:InvokeServer("Attack")
            elseif remotes:FindFirstChild("CDN") then
                remotes.CDN:FireServer(targetModel)
            end
        end
    end)
end

-- ==================== SISTEMAS DE AUTO FARM ====================
local function StartAutoFarm()
    if Threads.AutoFarm then task.cancel(Threads.AutoFarm) end
    Threads.AutoFarm = task.spawn(function()
        while Configs.AutoFarm do
            if CharacterReady() then
                local qInfo = GetCurrentQuestInfo()
                local mainGui = player.PlayerGui:FindFirstChild("Main")
                local questFrame = mainGui and mainGui:FindFirstChild("Quest")
                local hasQuest = questFrame and questFrame.Visible

                if not hasQuest then
                    if (humanoidRootPart.Position - qInfo.NPC_Pos).Magnitude > 20 then
                        SafeTeleport(qInfo.NPC_Pos + Vector3.new(0, 5, 0))
                        task.wait(0.5)
                    else
                        pcall(function()
                            ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest", qInfo.QuestName, qInfo.QuestLevel)
                        end)
                        task.wait(0.5)
                    end
                else
                    local enemy = GetTargetEnemy(qInfo.EnemyName)
                    if enemy then
                        humanoidRootPart.CFrame = enemy.HRP.CFrame * CFrame.new(0, farmSafeDistance, 0)
                        humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                        AutoAttack(enemy.Model)
                    else
                        SafeTeleport(qInfo.Mob_Pos)
                        task.wait(0.5)
                    end
                end
            end
            task.wait(0.05)
        end
    end)
end

local function StartAutoBoss()
    if Threads.AutoBoss then task.cancel(Threads.AutoBoss) end
    Threads.AutoBoss = task.spawn(function()
        while Configs.AutoFarmBoss do
            if CharacterReady() then
                local boss = GetTargetEnemy(selectedBoss)
                if boss then
                    humanoidRootPart.CFrame = boss.HRP.CFrame * CFrame.new(0, farmSafeDistance, 0)
                    humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                    AutoAttack(boss.Model)
                else
                    task.wait(1)
                end
            end
            task.wait(0.05)
        end
    end)
end

local function StartAutoStats()
    if Threads.AutoStats then task.cancel(Threads.AutoStats) end
    Threads.AutoStats = task.spawn(function()
        while Configs.AutoStats do
            pcall(function()
                local points = player.Data.Points.Value
                if points > 0 then
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("AddPoint", Configs.SelectedStat, math.min(points, 10))
                end
            end)
            task.wait(1)
        end
    end)
end

local function StartAutoChest()
    if Threads.AutoChest then task.cancel(Threads.AutoChest) end
    Threads.AutoChest = task.spawn(function()
        while Configs.AutoCollectChest do
            if CharacterReady() then
                for _, obj in ipairs(Workspace:GetChildren()) do
                    if not Configs.AutoCollectChest then break end
                    local name = obj.Name:lower()
                    if name:find("chest") then
                        local hrp = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("BasePart")
                        if hrp then
                            SafeTeleport(hrp.Position + Vector3.new(0, 2, 0))
                            task.wait(0.3)
                        end
                    end
                end
            end
            task.wait(1)
        end
    end)
end

-- ==================== PVP E ESP ====================
local function StartAimbot()
    if aimbotConnection then aimbotConnection:Disconnect() end
    aimbotConnection = RunService.RenderStepped:Connect(function()
        if not Configs.AimbotPvP then
            if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
            return
        end
        if CharacterReady() then
            local closestPlayer = nil
            local minDist = 300
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character and p.Character:FindFirstChild("Head") then
                    local head = p.Character.Head
                    local dist = (head.Position - humanoidRootPart.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        closestPlayer = head
                    end
                end
            end
            if closestPlayer then
                camera.CFrame = CFrame.new(camera.CFrame.Position, closestPlayer.Position)
            end
        end
    end)
end

local function ClearESP()
    for p, data in pairs(espObjects) do
        pcall(function() if data.Billboard then data.Billboard:Destroy() end end)
    end
    espObjects = {}
end

local function UpdateESP()
    ClearESP()
    if not Configs.PlayerESP then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local billboard = Instance.new("BillboardGui")
                billboard.Adornee = hrp
                billboard.Size = UDim2.new(0, 150, 0, 40)
                billboard.StudsOffset = Vector3.new(0, 4, 0)
                billboard.AlwaysOnTop = true 
                billboard.Parent = Workspace

                local label = Instance.new("TextLabel", billboard)
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.TextColor3 = Color3.fromRGB(0, 255, 255) 
                label.TextStrokeTransparency = 0
                label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 13
                label.Text = p.Name 

                espObjects[p] = { Billboard = billboard }
            end
        end
    end
end

local function StartFruitSniper()
    if Threads.FruitSniper then task.cancel(Threads.FruitSniper) end
    Threads.FruitSniper = task.spawn(function()
        while Configs.FruitSniper do
            if CharacterReady() then
                for _, obj in ipairs(Workspace:GetChildren()) do
                    if not Configs.FruitSniper then break end
                    if obj:IsA("Tool") or (obj:IsA("Model") and (obj.Name:find("Fruit") or obj.Name:find("Devil"))) then
                        local handle = obj:FindFirstChild("Handle") or obj.PrimaryPart
                        if handle then
                            SafeTeleport(handle.Position + Vector3.new(0, 2, 0))
                            task.wait(0.5)
                        end
                    end
                end
            end
            task.wait(1)
        end
    end)
end

local function UpdateFruitESP()
    for _, item in pairs(fruitEspObjects) do
        if item.Billboard then item.Billboard:Destroy() end
    end
    fruitEspObjects = {}
    if not Configs.FruitESP then return end
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Tool") or (obj:IsA("Model") and (obj.Name:find("Fruit") or obj.Name:find("Devil"))) then
            local part = obj:FindFirstChild("Handle") or obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
            if part then
                local billboard = Instance.new("BillboardGui")
                billboard.Adornee = part
                billboard.Size = UDim2.new(0, 140, 0, 30)
                billboard.StudsOffset = Vector3.new(0, 3, 0)
                billboard.AlwaysOnTop = true
                billboard.Parent = Workspace

                local label = Instance.new("TextLabel", billboard)
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.TextColor3 = Color3.fromRGB(255, 170, 0)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 13
                label.Text = "🍎 " .. obj.Name
                label.TextStrokeTransparency = 0

                table.insert(fruitEspObjects, { Billboard = billboard })
            end
        end
    end
end

-- ==================== RAIDS & EXTRAS ====================
local function StartAutoRaid()
    if Threads.AutoRaid then task.cancel(Threads.AutoRaid) end
    Threads.AutoRaid = task.spawn(function()
        while Configs.AutoRaid do
            if CharacterReady() then
                SafeTeleport(Vector3.new(-15970, 700, 3800))
                task.wait(1)
                pcall(function()
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("RaidsNpc", "Select", "Flame")
                end)
                local raidEnemy = GetTargetEnemy()
                if raidEnemy then
                    humanoidRootPart.CFrame = raidEnemy.HRP.CFrame * CFrame.new(0, Configs.RaidInstant and 3 or 10, 0)
                    AutoAttack(raidEnemy.Model)
                end
            end
            task.wait(0.1)
        end
    end)
end

local function ServerHop()
    local success, servers = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if success and servers and servers.data then
        for _, s in ipairs(servers.data) do
            if s.id ~= game.JobId and s.playing < s.maxPlayers then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id)
                return
            end
        end
    end
end

player.CharacterAdded:Connect(function(char)
    character = char
    humanoidRootPart = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
    if Configs.AutoRevive then
        task.wait(1.5)
        if Configs.AutoFarm then StartAutoFarm() end
    end
end)

RunService.Heartbeat:Connect(function()
    if Configs.PlayerESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and not espObjects[p] and p.Character then
                UpdateESP()
                break
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if espObjects[p] then
        pcall(function() if espObjects[p].Billboard then espObjects[p].Billboard:Destroy() end end)
        espObjects[p] = nil
    end
end)

-- =====================================================================
-- ==================== UI SYSTEM CONSTRUCT (v1.1.0 -> v2.0.0) ====================
-- =====================================================================

local UIState = "CLOSED"
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
        AutoFarm        = { Title = "Auto Farm Level",    Desc = "Auto Quest, Teleport e Farm de Nível Inteligente." },
        AutoFarmBoss    = { Title = "Auto Boss Farm",     Desc = "Farm automático de Boss selecionado." },
        AutoCollectChest= { Title = "Auto Chest",         Desc = "Coleta inteligente de baús pelo mapa." },
        AutoStats       = { Title = "Auto Stats",         Desc = "Distribui pontos de atributos automaticamente." },
        AimbotPvP       = { Title = "Aimbot PvP",         Desc = "Mira suave e travamento nos jogadores em combate." },
        AntiFlinch      = { Title = "Anti-Knockback",     Desc = "Remove o empurrão de golpes recebidos." },
        PvPAutoBlock    = { Title = "Auto Block",         Desc = "Defesa automática ao sofrer ataques." },
        FruitSniper     = { Title = "Fruit Sniper",       Desc = "Coleta automática de frutas espalhadas." },
        AutoRaid        = { Title = "Auto Raid",          Desc = "Inicia e conclui Raids automaticamente." },
        RaidInstant     = { Title = "Raid Fast Kill",     Desc = "Eliminação rápida dos inimigos na Raid." },
        PlayerESP       = { Title = "Player ESP",         Desc = "Visualização de jogadores no mapa." },
        FruitESP        = { Title = "Fruit ESP",          Desc = "Destaca frutas físicas spawnadas." },
        AutoRevive      = { Title = "Auto Revive Farm",   Desc = "Reinicia rotina de farm após renascer." },
        ServerHop       = { Title = "Server Hop",         Desc = "Troca para servidor mais vazio." },
    }
}

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

local function PlayUI_Click() pcall(function() SharedClickSound.TimePosition = 0; SharedClickSound:Play() end) end

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

local dragToggle, dragStart, startPos, isDragging = false, nil, nil, false
FloatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragToggle = true; isDragging = false; dragStart = input.Position; startPos = FloatBtn.Position
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

local mainWrapper = Instance.new("Frame", screenGui)
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0.5)
mainWrapper.Size = UDim2.new(0, 640, 0, 360)
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible = false
mainWrapper.ZIndex = 1

local mainFrame = Instance.new("Frame", mainWrapper)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.ZIndex = 2

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

local function CreateGradientPanel(parent, size, pos, name)
    local panel = Instance.new("Frame", parent)
    panel.Name = name; panel.Size = size; panel.Position = pos
    panel.BackgroundTransparency = 1; panel.ZIndex = 5
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
    local outerStroke = Instance.new("UIStroke", panel)
    outerStroke.Thickness = 2.5; outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    outerStroke.Color = Color3.fromRGB(255, 255, 255)
    local outerGrad = Instance.new("UIGradient", outerStroke)
    outerGrad.Rotation = 45; outerGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)), ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 20, 30))})
    local InnerBg = Instance.new("Frame", panel)
    InnerBg.Name = "InnerBg"; InnerBg.Size = UDim2.new(1, 0, 1, 0)
    InnerBg.BackgroundColor3 = Color3.fromRGB(15, 0, 3); InnerBg.ClipsDescendants = true; InnerBg.ZIndex = 5
    Instance.new("UICorner", InnerBg).CornerRadius = UDim.new(0, 10)
    local overlay = Instance.new("Frame", InnerBg)
    overlay.Size = UDim2.new(1, 0, 1, 0); overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255); overlay.ZIndex = 5
    Instance.new("UICorner", overlay).CornerRadius = UDim.new(0, 10)
    local redGrad = Instance.new("UIGradient", overlay)
    redGrad.Rotation = 90; redGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 0, 5)), ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 20, 30))})
    RunService.RenderStepped:Connect(function() redGrad.Rotation = (os.clock() * 12) % 360 end)
    return panel
end

local LeftPanel  = CreateGradientPanel(mainFrame, UDim2.new(0, 200, 1, 0), UDim2.new(0, 0, 0, 0), "LeftPanel")
local RightPanel = CreateGradientPanel(mainFrame, UDim2.new(1, -215, 1, 0), UDim2.new(0, 215, 0, 0), "RightPanel")

-- ==================== LEFT PANEL ====================
local LeftSeparatorLine = Instance.new("Frame", LeftPanel.InnerBg)
LeftSeparatorLine.Size = UDim2.new(1, 0, 0, 1); LeftSeparatorLine.Position = UDim2.new(0, 0, 0, 36)
LeftSeparatorLine.BackgroundColor3 = Color3.fromRGB(255, 80, 80); LeftSeparatorLine.BackgroundTransparency = 0.5; LeftSeparatorLine.ZIndex = 10

local HeaderLeft = Instance.new("Frame", LeftPanel.InnerBg)
HeaderLeft.Size = UDim2.new(1, 0, 0, 36); HeaderLeft.BackgroundTransparency = 1; HeaderLeft.ZIndex = 10

local title = Instance.new("TextLabel", HeaderLeft)
title.Size = UDim2.new(1, 0, 0, 16); title.Position = UDim2.new(0, 0, 0, 4)
title.BackgroundTransparency = 1; title.Text = "AKATSUKI SCRIPTS"; title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold; title.TextSize = 13; title.ZIndex = 11

local subtitle = Instance.new("TextLabel", HeaderLeft)
subtitle.Size = UDim2.new(1, 0, 0, 12); subtitle.Position = UDim2.new(0, 0, 0, 20)
subtitle.BackgroundTransparency = 1; subtitle.Text = "BLOX FRUITS | by zeni <3"
subtitle.TextColor3 = Color3.fromRGB(180, 180, 180); subtitle.TextTransparency = 0.2
subtitle.Font = Enum.Font.Gotham; subtitle.TextSize = 9.5; subtitle.ZIndex = 11

local TabsContainer = Instance.new("ScrollingFrame", LeftPanel.InnerBg)
TabsContainer.Size = UDim2.new(1, -8, 1, -130); TabsContainer.Position = UDim2.new(0, 4, 0, 44)
TabsContainer.BackgroundTransparency = 1; TabsContainer.BorderSizePixel = 0; TabsContainer.ZIndex = 10
TabsContainer.ScrollBarThickness = 3; TabsContainer.ScrollBarImageColor3 = Color3.fromRGB(200, 50, 50)
local TabsLayout = Instance.new("UIListLayout", TabsContainer)
TabsLayout.Padding = UDim.new(0, 2); TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function UpdateTabsCanvas()
    TabsContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(TabsLayout.AbsoluteContentSize.Y + 8, TabsContainer.AbsoluteSize.Y + 12))
end
TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabsCanvas)

local UserProfileFrame = Instance.new("Frame", LeftPanel.InnerBg)
UserProfileFrame.Size = UDim2.new(1, -12, 0, 75); UserProfileFrame.Position = UDim2.new(0, 6, 1, -81)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 5); UserProfileFrame.BackgroundTransparency = 0.5; UserProfileFrame.ZIndex = 10
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 8)

local AvatarImage = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Size = UDim2.new(0, 50, 0, 50); AvatarImage.Position = UDim2.new(0, 8, 0.5, -25)
AvatarImage.BackgroundTransparency = 1; AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"; AvatarImage.ZIndex = 11
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

local DisplayNameLabel = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Size = UDim2.new(1, -94, 0, 16); DisplayNameLabel.Position = UDim2.new(0, 64, 0.5, -18)
DisplayNameLabel.BackgroundTransparency = 1; DisplayNameLabel.Text = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(235, 235, 235); DisplayNameLabel.Font = Enum.Font.GothamBold; DisplayNameLabel.TextSize = 11; DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left; DisplayNameLabel.ZIndex = 11

local UsernameLabel = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Size = UDim2.new(1, -94, 0, 14); UsernameLabel.Position = UDim2.new(0, 64, 0.5, 2)
UsernameLabel.BackgroundTransparency = 1; UsernameLabel.Text = "@" .. player.Name
UsernameLabel.TextColor3 = Color3.fromRGB(140, 140, 140); UsernameLabel.Font = Enum.Font.Gotham; UsernameLabel.TextSize = 10; UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left; UsernameLabel.ZIndex = 11

-- ==================== RIGHT PANEL ====================
local topButtons = Instance.new("Frame", RightPanel.InnerBg)
topButtons.Size = UDim2.new(1, -12, 0, 36); topButtons.BackgroundTransparency = 1; topButtons.ZIndex = 10

local ControlsFrame = Instance.new("Frame", topButtons)
ControlsFrame.Size = UDim2.new(0, 120, 1, 0); ControlsFrame.Position = UDim2.new(1, -120, 0, 0); ControlsFrame.BackgroundTransparency = 1; ControlsFrame.ZIndex = 11

local UIListTop = Instance.new("UIListLayout", ControlsFrame)
UIListTop.FillDirection = Enum.FillDirection.Horizontal; UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right; UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center; UIListTop.Padding = UDim.new(0, 5); UIListTop.SortOrder = Enum.SortOrder.LayoutOrder

local function MakeControlBtn(order)
    local btn = Instance.new("TextButton", ControlsFrame)
    btn.LayoutOrder = order; btn.Size = UDim2.new(0, 24, 0, 24); btn.BackgroundColor3 = Color3.fromRGB(15, 15, 15); btn.BackgroundTransparency = 0.3; btn.Text = ""; btn.ZIndex = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    return btn
end

local SearchBtn = MakeControlBtn(1); SearchBtn.ClipsDescendants = true
local searchTextBox = Instance.new("TextBox", SearchBtn)
searchTextBox.Size = UDim2.new(1, -26, 1, 0); searchTextBox.Position = UDim2.new(0, 24, 0, 0)
searchTextBox.BackgroundTransparency = 1; searchTextBox.PlaceholderText = UI_TEXT.SearchPlaceholder
searchTextBox.TextColor3 = Color3.fromRGB(230, 230, 230); searchTextBox.Font = Enum.Font.Gotham; searchTextBox.TextSize = 10; searchTextBox.TextXAlignment = Enum.TextXAlignment.Left; searchTextBox.Visible = false; searchTextBox.ZIndex = 12

local MinimizeBtn = MakeControlBtn(2)
local ExpandBtn = MakeControlBtn(3)
local CloseBtn = MakeControlBtn(4)

local RightSeparatorLine = Instance.new("Frame", RightPanel.InnerBg)
RightSeparatorLine.Size = UDim2.new(1, 0, 0, 1); RightSeparatorLine.Position = UDim2.new(0, 0, 0, 36)
RightSeparatorLine.BackgroundColor3 = Color3.fromRGB(255, 80, 80); RightSeparatorLine.BackgroundTransparency = 0.5; RightSeparatorLine.ZIndex = 10

local BadgeFrame = Instance.new("Frame", RightPanel.InnerBg)
BadgeFrame.Size = UDim2.new(0, 45, 0, 18); BadgeFrame.Position = UDim2.new(0, 12, 0, 9); BadgeFrame.BackgroundColor3 = Color3.fromRGB(230, 20, 25); BadgeFrame.ZIndex = 15
Instance.new("UICorner", BadgeFrame).CornerRadius = UDim.new(1, 0)
local BadgeText = Instance.new("TextLabel", BadgeFrame)
BadgeText.Size = UDim2.new(1, 0, 1, 0); BadgeText.BackgroundTransparency = 1; BadgeText.Text = "v2.0.0"; BadgeText.TextColor3 = Color3.fromRGB(255, 255, 255); BadgeText.Font = Enum.Font.GothamBold; BadgeText.TextSize = 10; BadgeText.ZIndex = 16

-- ==================== TOGGLES E TABS ====================
local togglesContainer = Instance.new("ScrollingFrame", RightPanel.InnerBg)
togglesContainer.Size = UDim2.new(1, -6, 1, -48); togglesContainer.Position = UDim2.new(0, 0, 0, 42)
togglesContainer.BackgroundTransparency = 1; togglesContainer.BorderSizePixel = 0; togglesContainer.ScrollBarThickness = 3; togglesContainer.ScrollBarImageColor3 = Color3.fromRGB(220, 30, 40); togglesContainer.ZIndex = 10
local containerLayout = Instance.new("UIListLayout", togglesContainer)
containerLayout.Padding = UDim.new(0, 6); containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local uiPadding = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingTop = UDim.new(0, 8); uiPadding.PaddingBottom = UDim.new(0, 8); uiPadding.PaddingLeft = UDim.new(0, 4); uiPadding.PaddingRight = UDim.new(0, 8)

local teleportScrollFrame = Instance.new("ScrollingFrame", RightPanel.InnerBg)
teleportScrollFrame.Size = UDim2.new(1, -6, 1, -48); teleportScrollFrame.Position = UDim2.new(0, 0, 0, 42)
teleportScrollFrame.BackgroundTransparency = 1; teleportScrollFrame.BorderSizePixel = 0; teleportScrollFrame.ScrollBarThickness = 3; teleportScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(220, 30, 40); teleportScrollFrame.ZIndex = 10; teleportScrollFrame.Visible = false
local tpLayout = Instance.new("UIListLayout", teleportScrollFrame)
tpLayout.Padding = UDim.new(0, 5); tpLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function filterToggles(currentActiveTab, query)
    local searchQuery = (query or ""):lower()
    for _, child in ipairs(togglesContainer:GetChildren()) do
        if child:IsA("Frame") then
            local itemTab = child:GetAttribute("Tab") or ""
            local titleLabel = child:FindFirstChild("Title")
            if (searchQuery ~= "" and titleLabel and titleLabel.Text:lower():find(searchQuery)) or (searchQuery == "" and itemTab == currentActiveTab) then
                child.Visible = true
            else
                child.Visible = false
            end
        end
    end
end

local function selectTab(tabName)
    activeTab = tabName
    togglesContainer.Visible = (tabName ~= "Teleports")
    teleportScrollFrame.Visible = (tabName == "Teleports")
    for name, btn in pairs(tabButtons) do
        if name == tabName then
            TweenService:Create(btn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(25, 5, 5), BackgroundTransparency = 0.4}):Play()
        else
            TweenService:Create(btn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 1}):Play()
        end
    end
    filterToggles(tabName, "")
end

local function createTabBtn(tabName)
    local tabBtn = Instance.new("TextButton", TabsContainer)
    tabBtn.Size = UDim2.new(1, -16, 0, 36); tabBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15); tabBtn.BackgroundTransparency = 1; tabBtn.Text = ""; tabBtn.ZIndex = 11
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 8)
    local tabLabel = Instance.new("TextLabel", tabBtn)
    tabLabel.Size = UDim2.new(1, -42, 1, 0); tabLabel.Position = UDim2.new(0, 38, 0, 0)
    tabLabel.BackgroundTransparency = 1; tabLabel.TextColor3 = Color3.fromRGB(200, 200, 200); tabLabel.Font = Enum.Font.GothamMedium; tabLabel.TextSize = 11; tabLabel.TextXAlignment = Enum.TextXAlignment.Left; tabLabel.Text = UI_TEXT.Tabs[tabName] or tabName; tabLabel.ZIndex = 12
    tabBtn.MouseButton1Click:Connect(function() PlayUI_Click(); selectTab(tabName) end)
    tabButtons[tabName] = tabBtn
end

local function createToggle(parent, configKey, tabCategory)
    local toggleFrame = Instance.new("Frame", parent)
    toggleFrame.Size = UDim2.new(1, -12, 0, 52); toggleFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 5); toggleFrame.BackgroundTransparency = 0.45; toggleFrame.ZIndex = 11
    toggleFrame:SetAttribute("Tab", tabCategory)
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 6)
    
    local optData = UI_TEXT.Options[configKey]
    local titleLabel = Instance.new("TextLabel", toggleFrame)
    titleLabel.Name = "Title"; titleLabel.Size = UDim2.new(0.7, 0, 0, 16); titleLabel.Position = UDim2.new(0, 10, 0, 6)
    titleLabel.BackgroundTransparency = 1; titleLabel.TextColor3 = Color3.fromHex("#CCCCCC"); titleLabel.Font = Enum.Font.GothamBold; titleLabel.TextSize = 11; titleLabel.TextXAlignment = Enum.TextXAlignment.Left; titleLabel.Text = optData and optData.Title or configKey; titleLabel.ZIndex = 11
    local descLabel = Instance.new("TextLabel", toggleFrame)
    descLabel.Size = UDim2.new(0.7, 0, 0, 26); descLabel.Position = UDim2.new(0, 10, 0, 22)
    descLabel.BackgroundTransparency = 1; descLabel.TextColor3 = Color3.fromRGB(130, 130, 130); descLabel.Font = Enum.Font.Gotham; descLabel.TextSize = 9; descLabel.TextXAlignment = Enum.TextXAlignment.Left; descLabel.TextYAlignment = Enum.TextYAlignment.Top; descLabel.Text = optData and optData.Desc or ""; descLabel.ZIndex = 11
    
    local switchTrack = Instance.new("Frame", toggleFrame)
    switchTrack.Size = UDim2.new(0, 38, 0, 18); switchTrack.Position = UDim2.new(1, -48, 0.5, -9); switchTrack.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30); switchTrack.ZIndex = 11
    Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)
    local switchCircle = Instance.new("Frame", switchTrack)
    switchCircle.Size = UDim2.new(0, 12, 0, 12); switchCircle.Position = Configs[configKey] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6); switchCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255); switchCircle.ZIndex = 12
    Instance.new("UICorner", switchCircle).CornerRadius = UDim.new(1, 0)
    
    local triggerBtn = Instance.new("TextButton", toggleFrame)
    triggerBtn.Size = UDim2.new(1, 0, 1, 0); triggerBtn.BackgroundTransparency = 1; triggerBtn.Text = ""; triggerBtn.ZIndex = 13

    triggerBtn.MouseButton1Click:Connect(function()
        Configs[configKey] = not Configs[configKey]
        local on = Configs[configKey]
        TweenService:Create(switchCircle, TweenInfo.new(0.3), {Position = on and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)}):Play()
        TweenService:Create(switchTrack, TweenInfo.new(0.3), {BackgroundColor3 = on and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)}):Play()

        if configKey == "AutoFarm" then if on then StartAutoFarm() else if Threads.AutoFarm then task.cancel(Threads.AutoFarm); Threads.AutoFarm = nil end end
        elseif configKey == "AutoFarmBoss" then if on then StartAutoBoss() else if Threads.AutoBoss then task.cancel(Threads.AutoBoss); Threads.AutoBoss = nil end end
        elseif configKey == "AutoStats" then if on then StartAutoStats() else if Threads.AutoStats then task.cancel(Threads.AutoStats); Threads.AutoStats = nil end end
        elseif configKey == "AutoCollectChest" then if on then StartAutoChest() else if Threads.AutoChest then task.cancel(Threads.AutoChest); Threads.AutoChest = nil end end
        elseif configKey == "AimbotPvP" then if on then StartAimbot() end
        elseif configKey == "FruitSniper" then if on then StartFruitSniper() else if Threads.FruitSniper then task.cancel(Threads.FruitSniper); Threads.FruitSniper = nil end end
        elseif configKey == "FruitESP" then UpdateFruitESP()
        elseif configKey == "PlayerESP" then UpdateESP(); if not on then ClearESP() end
        elseif configKey == "AutoRaid" then if on then StartAutoRaid() else if Threads.AutoRaid then task.cancel(Threads.AutoRaid); Threads.AutoRaid = nil end end
        elseif configKey == "ServerHop" then if on then pcall(ServerHop) end
        end
    end)
end

-- ==================== CONSTRUIR MENUS ====================
createTabBtn("AutoFarm")
createTabBtn("PvP")
createTabBtn("Raids")
createTabBtn("Teleports")
createTabBtn("Settings")

createToggle(togglesContainer, "AutoFarm",         "AutoFarm")
createToggle(togglesContainer, "AutoFarmBoss",     "AutoFarm")
createToggle(togglesContainer, "AutoCollectChest", "AutoFarm")
createToggle(togglesContainer, "AutoStats",        "AutoFarm")

createToggle(togglesContainer, "AimbotPvP",    "PvP")
createToggle(togglesContainer, "AntiFlinch",   "PvP")
createToggle(togglesContainer, "PvPAutoBlock", "PvP")
createToggle(togglesContainer, "FruitSniper",  "PvP")

createToggle(togglesContainer, "AutoRaid",    "Raids")
createToggle(togglesContainer, "RaidInstant", "Raids")

createToggle(togglesContainer, "PlayerESP",  "Settings")
createToggle(togglesContainer, "FruitESP",   "Settings")
createToggle(togglesContainer, "AutoRevive", "Settings")
createToggle(togglesContainer, "ServerHop",  "Settings")

-- ==================== TELA DE CONFIRMAÇÃO & JANELA ====================
local confirmFrame = Instance.new("Frame", mainWrapper)
confirmFrame.Size = UDim2.new(1, 0, 1, 0); confirmFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0); confirmFrame.BackgroundTransparency = 0.2; confirmFrame.Visible = false; confirmFrame.ZIndex = 999
local btnYes = Instance.new("TextButton", confirmFrame)
btnYes.Size = UDim2.new(0, 110, 0, 34); btnYes.Position = UDim2.new(0.5, -115, 0.55, 0); btnYes.BackgroundColor3 = Color3.fromHex("#8B0000"); btnYes.TextColor3 = Color3.fromRGB(255, 255, 255); btnYes.Text = UI_TEXT.ConfirmBtn; btnYes.ZIndex = 1000
local btnNo = Instance.new("TextButton", confirmFrame)
btnNo.Size = UDim2.new(0, 110, 0, 34); btnNo.Position = UDim2.new(0.5, 5, 0.55, 0); btnNo.BackgroundColor3 = Color3.fromRGB(26, 26, 26); btnNo.TextColor3 = Color3.fromRGB(180, 180, 180); btnNo.Text = UI_TEXT.CancelBtn; btnNo.ZIndex = 1000

ExpandBtn.MouseButton1Click:Connect(function()
    isExpanded = not isExpanded
    TweenService:Create(mainWrapper, TweenInfo.new(0.3), {Size = isExpanded and UDim2.new(0, 800, 0, 480) or UDim2.new(0, 640, 0, 360)}):Play()
end)

SetUIState = function(newState)
    if UIState == newState then return end
    UIState = newState
    if newState == "OPEN" then
        mainWrapper.Visible = true
        TweenService:Create(mainWrapper, TweenInfo.new(0.25), {Size = isExpanded and UDim2.new(0, 800, 0, 480) or UDim2.new(0, 640, 0, 360)}):Play()
    else
        local ct = TweenService:Create(mainWrapper, TweenInfo.new(0.25), {Size = UDim2.new(0, 480, 0, 260)})
        ct:Play(); ct.Completed:Connect(function() mainWrapper.Visible = false end)
    end
end

MinimizeBtn.MouseButton1Click:Connect(function() SetUIState("MINIMIZED") end)
CloseBtn.MouseButton1Click:Connect(function() confirmFrame.Visible = true end)
btnNo.MouseButton1Click:Connect(function() confirmFrame.Visible = false end)
btnYes.MouseButton1Click:Connect(function()
    for _, th in pairs(Threads) do if th then task.cancel(th) end end
    if aimbotConnection then aimbotConnection:Disconnect() end
    screenGui:Destroy()
end)

-- ==================== INICIAR UI ====================
task.spawn(function()
    task.wait(0.5)
    mainWrapper.Visible = true
    UIState = "OPEN"
    selectTab("AutoFarm")
end) 
