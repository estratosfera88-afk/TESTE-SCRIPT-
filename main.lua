--[[
    AKAT BLOX FRUITS MAIN LOGIC [v6.0]
    Compatível com Delta Mobile & PC | Blox Fruits
    BACKEND ONLY — sem código de interface visual

    Recursos:
    - Auto Farm Level: quest -> mobs -> entrega -> próximo alvo.
    - Auto Farm Boss: seleção de boss + respawn loop.
    - Auto Farm Mastery: Fruit / Gun / Sword com alvo inteligente.
    - Auto Bones / Materials: descoberta dinâmica de mobs e itens.
    - Auto Chests: scanner de baús + coleta.
    - Mob Aura / Auto Skills.
    - ESP / Name / Tracer / XRay.
    - Teleportes rápidos para mob, boss e chest.
    - Controle de velocidade, pulo e Anti-Fling.

    Observação:
    Este backend usa descoberta dinâmica e chamadas públicas/locais disponíveis no
    cliente. Não inclui bypass de anti-ban/anti-kick nem tentativa de ocultar
    automação de sistemas de segurança do jogo. O SafeFarm/limiter reduz spam,
    travamentos e reposicionamentos excessivos.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = nil
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)

local player = Players.LocalPlayer

if _G.AkatLogicRunning then
    pcall(function()
        if _G.AkatCallbacks and _G.AkatCallbacks.ShutdownAll then
            _G.AkatCallbacks.ShutdownAll()
        end
    end)
end
_G.AkatLogicRunning = true

local scriptAlive = true

local Configs = {
    ESP = false,
    Name = false,
    Tracer = false,
    XRay = false,
    Speed = false,
    SpeedValue = 16,
    JumpPower = false,
    JumpPowerValue = 50,
    AntiFling = false,
    Invisibility = false,

    AutoFarmLevel = false,
    AutoFarmBoss = false,
    AutoFarmMastery = false,
    AutoFruitMastery = false,
    AutoGunMastery = false,
    AutoSwordMastery = false,
    AutoBones = false,
    AutoMaterials = false,
    AutoChests = false,

    MobAura = false,
    AutoSkills = false,
    SafeFarm = true,

    FarmWorld = "First Sea",
    BossTarget = "Auto",
    MasteryWeapon = "Auto",
    MaterialTarget = "Bones",

    MobRadius = 35,
    TeleportDelay = 0.20,
    Debug = false,
}

_G.Configs = Configs

local State = {
    CurrentMob = nil,
    CurrentBoss = nil,
    CurrentChest = nil,
    CurrentQuest = nil,
    LastTeleport = 0,
    LastQuest = 0,
    LastAttack = 0,
    LastSkill = 0,
    LastScan = 0,
    LastChestScan = 0,
    MasteryTool = nil,
    RunningMode = "Idle",
}

local Connections = {}
local ESPObjects = {}
local NameTags = {}
local Tracers = {}
local XRayParts = {}
local invisOriginal = {}

local function DebugLog(area, msg)
    if Configs.Debug then
        warn(("[AKAT][%s] %s"):format(area, tostring(msg)))
    end
end

local function Character()
    return player.Character
end

local function Root()
    local c = Character()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function Humanoid()
    local c = Character()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function Alive()
    local h = Humanoid()
    return h and h.Health > 0 and Root() ~= nil
end

local function Distance(a, b)
    if not a or not b then return math.huge end
    local ap = typeof(a) == "Vector3" and a or a.Position
    local bp = typeof(b) == "Vector3" and b or b.Position
    return (ap - bp).Magnitude
end

local function FindPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart")
            or obj:FindFirstChild("Head")
            or obj:FindFirstChildWhichIsA("BasePart")
    end
    if obj:IsA("Tool") then
        return obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

local function GetEnemies()
    local list = {}
    local folder = workspace:FindFirstChild("Enemies")
    local source = folder or workspace
    for _, d in ipairs(source:GetChildren()) do
        if d:IsA("Model") then
            local hum = d:FindFirstChildOfClass("Humanoid")
            local root = d:FindFirstChild("HumanoidRootPart") or d:FindFirstChild("Head")
            if hum and root and hum.Health > 0 then
                table.insert(list, d)
            end
        end
    end
    return list
end

local function GetEnemyByName(name)
    if not name or name == "" or name == "Auto" then return nil end
    local low = tostring(name):lower()
    for _, enemy in ipairs(GetEnemies()) do
        if enemy.Name:lower() == low or enemy.Name:lower():find(low, 1, true) then
            return enemy
        end
    end
    return nil
end

local function FindNearestEnemy(filter)
    local root = Root()
    if not root then return nil end
    local nearest, best = nil, math.huge
    for _, enemy in ipairs(GetEnemies()) do
        if not filter or filter(enemy) then
            local eroot = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Head")
            local hum = enemy:FindFirstChildOfClass("Humanoid")
            if eroot and hum and hum.Health > 0 then
                local d = Distance(root, eroot)
                if d < best then
                    best, nearest = d, enemy
                end
            end
        end
    end
    return nearest
end

local function GetTools()
    local result = {}
    local char = Character()
    local backpack = player:FindFirstChildOfClass("Backpack")
    local function scan(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(result, item)
            end
        end
    end
    scan(char)
    scan(backpack)
    return result
end

local function FindTool(kind, preferred)
    local pref = tostring(preferred or ""):lower()
    local candidates = GetTools()

    if pref ~= "" and pref ~= "auto" then
        for _, tool in ipairs(candidates) do
            if tool.Name:lower() == pref or tool.Name:lower():find(pref, 1, true) then
                return tool
            end
        end
    end

    local function score(tool)
        local n = tool.Name:lower()
        local s = 0
        if kind == "Fruit" then
            if n:find("fruit") or n:find("buddha") or n:find("gravity") or n:find("light") then s += 8 end
            if tool.ToolTip:lower():find("fruit") then s += 10 end
        elseif kind == "Gun" then
            if n:find("gun") or n:find("pistol") or n:find("cannon") or n:find("rifle") then s += 8 end
            if tool.ToolTip:lower():find("gun") then s += 10 end
        elseif kind == "Sword" then
            if not n:find("fruit") and not n:find("gun") then s += 4 end
            if n:find("sword") or n:find("blade") or n:find("katana") then s += 8 end
            if tool.ToolTip:lower():find("sword") then s += 10 end
        end
        return s
    end

    table.sort(candidates, function(a,b) return score(a) > score(b) end)
    return candidates[1]
end

local function EquipTool(tool)
    if not tool then return false end
    local hum = Humanoid()
    if not hum then return false end
    if tool.Parent ~= Character() then
        pcall(function() hum:EquipTool(tool) end)
        task.wait()
    end
    return tool.Parent == Character()
end

local function ActivateTool(tool)
    if not tool or tool.Parent ~= Character() then return false end
    local ok = pcall(function() tool:Activate() end)
    return ok
end

local function PressKey(key)
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, key, false, game)
            task.wait(0.03)
            VirtualInputManager:SendKeyEvent(false, key, false, game)
        end)
        return
    end
    local ok, fn = pcall(function()
        return keypress
    end)
    if ok and type(fn) == "function" then
        pcall(function()
            keypress(key:byte())
            task.wait(0.03)
            keyrelease(key:byte())
        end)
    end
end

local function TeleportTo(cf)
    local root = Root()
    if not root or not cf then return false end
    local delayTime = Configs.SafeFarm and math.max(0.08, Configs.TeleportDelay) or 0
    local now = os.clock()
    if now - State.LastTeleport < delayTime then return false end
    State.LastTeleport = now
    pcall(function()
        root.CFrame = cf
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    return true
end

local function TeleportNear(target, offset)
    local part = FindPart(target)
    if not part then return false end
    offset = offset or CFrame.new(0, 6, 0)
    return TeleportTo(part.CFrame * offset)
end

-- ==================== QUEST DISCOVERY ====================
local FIRST_SEA_QUESTS = {
    {min=1, max=9, mob="Bandit", quest="BanditQuest1", id=1},
    {min=10, max=14, mob="Monkey", quest="JungleQuest", id=1},
    {min=15, max=29, mob="Gorilla", quest="JungleQuest", id=2},
    {min=30, max=44, mob="Pirate", quest="BuggyQuest1", id=1},
    {min=45, max=59, mob="Brute", quest="BuggyQuest1", id=2},
    {min=60, max=74, mob="Desert Bandit", quest="DesertQuest", id=1},
    {min=75, max=89, mob="Desert Officer", quest="DesertQuest", id=2},
    {min=90, max=99, mob="Snow Bandit", quest="SnowQuest", id=1},
    {min=100, max=119, mob="Snowman", quest="SnowQuest", id=2},
    {min=120, max=149, mob="Chief Petty Officer", quest="MarineQuest2", id=1},
    {min=150, max=174, mob="Sky Bandit", quest="SkyQuest", id=1},
    {min=175, max=224, mob="Dark Master", quest="SkyQuest", id=2},
    {min=225, max=274, mob="Toga Warrior", quest="ColosseumQuest", id=1},
    {min=275, max=299, mob="Gladiator", quest="ColosseumQuest", id=2},
    {min=300, max=324, mob="Military Soldier", quest="MagmaQuest", id=1},
    {min=325, max=374, mob="Military Spy", quest="MagmaQuest", id=2},
    {min=375, max=399, mob="Fishman Warrior", quest="FishmanQuest", id=1},
    {min=400, max=449, mob="Fishman Commando", quest="FishmanQuest", id=2},
    {min=450, max=474, mob="God's Guard", quest="SkyExp1Quest", id=1},
    {min=475, max=524, mob="Shanda", quest="SkyExp1Quest", id=2},
    {min=525, max=549, mob="Royal Squad", quest="SkyExp2Quest", id=1},
    {min=550, max=624, mob="Royal Soldier", quest="SkyExp2Quest", id=2},
    {min=625, max=649, mob="Galley Pirate", quest="FountainQuest", id=1},
    {min=650, max=700, mob="Galley Captain", quest="FountainQuest", id=2},
}

local function GetLevel()
    local data = player:FindFirstChild("Data")
    local lvl = data and data:FindFirstChild("Level")
    if lvl and tonumber(lvl.Value) then return tonumber(lvl.Value) end
    local leaderstats = player:FindFirstChild("leaderstats")
    local ls = leaderstats and leaderstats:FindFirstChild("Level")
    return ls and tonumber(ls.Value) or 1
end

local function GetQuestRemote()
    local comm = ReplicatedStorage:FindFirstChild("Remotes")
    local rf = comm and comm:FindFirstChild("CommF_")
    if rf and rf:IsA("RemoteFunction") then return rf end
    local direct = ReplicatedStorage:FindFirstChild("CommF_")
    if direct and direct:IsA("RemoteFunction") then return direct end
    return nil
end

local function InvokeComm(...)
    local rf = GetQuestRemote()
    if not rf then return nil end
    local args = {...}
    local ok, result = pcall(function()
        return rf:InvokeServer(unpack(args))
    end)
    if ok then return result end
    DebugLog("Remote", result)
    return nil
end

local function StartQuest(q)
    if not q then return false end
    local now = os.clock()
    if now - State.LastQuest < 1.0 then return false end
    State.LastQuest = now
    local result = InvokeComm("StartQuest", q.quest, q.id)
    State.CurrentQuest = q
    return result ~= nil
end

local function AbandonQuest()
    pcall(function() InvokeComm("AbandonQuest") end)
    State.CurrentQuest = nil
end

local function GetQuestForLevel(level)
    if Configs.FarmWorld ~= "First Sea" then return nil end
    for _, q in ipairs(FIRST_SEA_QUESTS) do
        if level >= q.min and level <= q.max then
            return q
        end
    end
    return FIRST_SEA_QUESTS[#FIRST_SEA_QUESTS]
end

-- ==================== COMBAT ====================
local function AttackTarget(target, kind)
    if not target then return false end
    local hum = target:FindFirstChildOfClass("Humanoid")
    local root = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Head")
    if not hum or not root or hum.Health <= 0 then return false end

    local radius = math.max(8, Configs.MobRadius)
    if Distance(Root(), root) > radius then
        TeleportNear(target, CFrame.new(0, 6, 0))
    end

    local tool = FindTool(kind or "Sword", Configs.MasteryWeapon)
    if tool then
        EquipTool(tool)
        ActivateTool(tool)
    end

    if Configs.AutoSkills or kind == "Fruit" then
        local now = os.clock()
        if now - State.LastSkill >= 0.45 then
            State.LastSkill = now
            for _, key in ipairs({"Z","X","C","V"}) do
                if hum.Health <= 0 then break end
                PressKey(key)
                task.wait(0.05)
            end
        end
    end
    return true
end

local function KillAura()
    if not Configs.MobAura then return end
    local root = Root()
    if not root then return end
    local radius = math.max(5, Configs.MobRadius)
    for _, enemy in ipairs(GetEnemies()) do
        local eroot = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Head")
        local hum = enemy:FindFirstChildOfClass("Humanoid")
        if eroot and hum and hum.Health > 0 and Distance(root, eroot) <= radius then
            AttackTarget(enemy, "Sword")
        end
    end
end

-- ==================== AUTO LEVEL ====================
local function AutoFarmLevelStep()
    local level = GetLevel()
    local q = GetQuestForLevel(level)
    if not q then return end

    local target = GetEnemyByName(q.mob)
    if not target then
        target = FindNearestEnemy(function(enemy)
            return enemy.Name:lower():find(q.mob:lower(), 1, true) ~= nil
        end)
    end

    if not target then
        State.CurrentMob = nil
        return
    end

    State.RunningMode = "Level"
    State.CurrentMob = target

    if not State.CurrentQuest then
        StartQuest(q)
    end

    local eroot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Head")
    if eroot and Distance(Root(), eroot) > Configs.MobRadius then
        TeleportNear(target, CFrame.new(0, 6, 0))
    end

    AttackTarget(target, "Sword")
    KillAura()
end

-- ==================== BOSS ====================
local BOSS_NAMES = {
    ["Gorilla King"] = true,
    ["Saber Expert"] = true,
    ["Mob Leader"] = true,
    ["Vice Admiral"] = true,
    ["Warden"] = true,
    ["Chief Warden"] = true,
    ["Swan"] = true,
    ["Magma Admiral"] = true,
    ["Fishman Lord"] = true,
    ["Wysper"] = true,
    ["Thunder God"] = true,
    ["Cyborg"] = true,
    ["Saber Expert"] = true,
}

local function FindBoss()
    if Configs.BossTarget ~= "Auto" then
        return GetEnemyByName(Configs.BossTarget)
    end
    local best
    for _, enemy in ipairs(GetEnemies()) do
        if BOSS_NAMES[enemy.Name] then
            local hum = enemy:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                best = enemy
                break
            end
        end
    end
    return best
end

local function AutoBossStep()
    local boss = FindBoss()
    if not boss then
        State.CurrentBoss = nil
        State.RunningMode = "Boss / Waiting Respawn"
        return
    end

    State.RunningMode = "Boss"
    State.CurrentBoss = boss
    TeleportNear(boss, CFrame.new(0, 7, 0))
    AttackTarget(boss, "Sword")
    if Configs.AutoSkills then
        AttackTarget(boss, "Fruit")
    end
end

-- ==================== MASTERY ====================
local function MasteryKind()
    local selection = Configs.MasteryWeapon
    if selection == "Fruit" then return "Fruit" end
    if selection == "Gun" then return "Gun" end
    if selection == "Sword" then return "Sword" end
    if Configs.AutoFruitMastery then return "Fruit" end
    if Configs.AutoGunMastery then return "Gun" end
    if Configs.AutoSwordMastery then return "Sword" end
    return "Sword"
end

local function AutoMasteryStep()
    local kind = MasteryKind()
    local tool = FindTool(kind, nil)
    if not tool then
        State.RunningMode = "Mastery / Tool not found"
        return
    end
    State.MasteryTool = tool
    State.RunningMode = "Mastery: " .. kind

    local target = FindNearestEnemy(function(enemy)
        local hum = enemy:FindFirstChildOfClass("Humanoid")
        return hum and hum.MaxHealth >= 500
    end)
    if not target then return end

    TeleportNear(target, CFrame.new(0, 6, 0))
    EquipTool(tool)
    AttackTarget(target, kind)
end

-- ==================== BONES / MATERIALS ====================
local MATERIAL_KEYWORDS = {
    Bones = {"bone", "bone"},
    Leather = {"leather"},
    ["Scrap Metal"] = {"scrap", "metal"},
    ["Magma Ore"] = {"magma", "ore"},
    ["Angel Wings"] = {"angel", "wing"},
    ["Fish Tail"] = {"fish", "tail"},
    ["Dragon Scale"] = {"dragon", "scale"},
}

local function MaterialFilter(enemy)
    local selected = Configs.MaterialTarget
    local keys = MATERIAL_KEYWORDS[selected] or {}
    if #keys == 0 then return true end
    local n = enemy.Name:lower()
    for _, k in ipairs(keys) do
        if n:find(k, 1, true) then return true end
    end
    return false
end

local function AutoMaterialsStep()
    State.RunningMode = "Materials: " .. tostring(Configs.MaterialTarget)
    local target = FindNearestEnemy(MaterialFilter)
    if target then
        State.CurrentMob = target
        TeleportNear(target, CFrame.new(0, 6, 0))
        AttackTarget(target, "Sword")
    else
        -- Fallback: if the exact drop name is unknown, farm nearby enemies.
        target = FindNearestEnemy()
        if target then
            State.CurrentMob = target
            TeleportNear(target, CFrame.new(0, 6, 0))
            AttackTarget(target, "Sword")
        end
    end
end

local function AutoBonesStep()
    Configs.MaterialTarget = "Bones"
    AutoMaterialsStep()
end

-- ==================== CHESTS ====================
local function IsChest(obj)
    local n = obj.Name:lower()
    return n:find("chest", 1, true) ~= nil
end

local function GetChests()
    local list = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if (d:IsA("BasePart") or d:IsA("Model")) and IsChest(d) then
            local p = FindPart(d)
            if p then table.insert(list, p) end
        end
    end
    return list
end

local function FindNearestChest()
    local root = Root()
    if not root then return nil end
    local best, dist = nil, math.huge
    for _, chest in ipairs(GetChests()) do
        local d = Distance(root, chest)
        if d < dist then
            dist, best = d, chest
        end
    end
    return best
end

local function AutoChestStep()
    local chest = FindNearestChest()
    if not chest then
        State.CurrentChest = nil
        State.RunningMode = "Chests / Scanning"
        return
    end
    State.CurrentChest = chest
    State.RunningMode = "Chests"
    TeleportTo(chest.CFrame * CFrame.new(0, 3, 0))
    pcall(function()
        if firetouchinterest then
            firetouchinterest(Root(), chest, 0)
            firetouchinterest(Root(), chest, 1)
        end
    end)
end

-- ==================== TELEPORT ACTIONS ====================
local function TpNearestMob()
    local target = FindNearestEnemy()
    if target then
        State.CurrentMob = target
        return TeleportNear(target, CFrame.new(0, 5, 0))
    end
    return false
end

local function TpBoss()
    local boss = FindBoss()
    if boss then
        State.CurrentBoss = boss
        return TeleportNear(boss, CFrame.new(0, 7, 0))
    end
    return false
end

local function TpChest()
    local chest = FindNearestChest()
    if chest then
        State.CurrentChest = chest
        return TeleportTo(chest.CFrame * CFrame.new(0, 3, 0))
    end
    return false
end

local function TpSafe()
    local target = State.CurrentMob or State.CurrentBoss
    if target then
        return TeleportNear(target, CFrame.new(0, math.max(8, Configs.MobRadius), 0))
    end
    return false
end

-- ==================== VISUALS ====================
local function ClearVisuals()
    for _, v in pairs(ESPObjects) do pcall(function() v:Destroy() end) end
    table.clear(ESPObjects)
    for _, v in pairs(NameTags) do pcall(function() v:Destroy() end) end
    table.clear(NameTags)
    for _, d in pairs(Tracers) do
        pcall(function() d.a:Destroy() end)
        pcall(function() d.b:Destroy() end)
        pcall(function() d.beam:Destroy() end)
    end
    table.clear(Tracers)
end

local function AddESP(model, label, textColor)
    if not model or not model.Parent then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if Configs.ESP then
        local hl = ESPObjects[model]
        if not hl or not hl.Parent then
            hl = Instance.new("Highlight")
            hl.Name = "AkatBloxESP"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillTransparency = 0.55
            hl.OutlineTransparency = 0
            hl.Parent = model
            ESPObjects[model] = hl
        end
        hl.FillColor = textColor or Color3.fromRGB(220, 40, 40)
        hl.OutlineColor = hl.FillColor
    elseif ESPObjects[model] then
        pcall(function() ESPObjects[model]:Destroy() end)
        ESPObjects[model] = nil
    end

    if Configs.Name then
        local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
        if head then
            local gui = NameTags[model]
            if not gui or not gui.Parent then
                gui = Instance.new("BillboardGui")
                gui.Name = "AkatBloxName"
                gui.Size = UDim2.fromOffset(150, 24)
                gui.StudsOffset = Vector3.new(0, 3, 0)
                gui.AlwaysOnTop = true
                gui.Parent = head

                local text = Instance.new("TextLabel", gui)
                text.Name = "Text"
                text.Size = UDim2.fromScale(1,1)
                text.BackgroundTransparency = 1
                text.Font = Enum.Font.GothamBold
                text.TextSize = 11
                text.TextStrokeTransparency = 0.5
                NameTags[model] = gui
            end
            local text = gui:FindFirstChild("Text")
            if text then
                text.Text = label or model.Name
                text.TextColor3 = textColor or Color3.new(1,1,1)
            end
        end
    elseif NameTags[model] then
        pcall(function() NameTags[model]:Destroy() end)
        NameTags[model] = nil
    end
end

local function UpdateTracerForPlayer(p)
    if p == player or not p.Character or not Configs.Tracer then
        local d = Tracers[p]
        if d then
            pcall(function() d.a:Destroy() end)
            pcall(function() d.b:Destroy() end)
            pcall(function() d.beam:Destroy() end)
            Tracers[p] = nil
        end
        return
    end

    local myRoot = Root()
    local target = p.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot or not target then return end

    local d = Tracers[p]
    if not d or not d.a.Parent or not d.b.Parent then
        local a = Instance.new("Attachment", myRoot)
        local b = Instance.new("Attachment", target)
        local beam = Instance.new("Beam", myRoot)
        beam.Attachment0 = a
        beam.Attachment1 = b
        beam.FaceCamera = true
        beam.Width0 = 0.10
        beam.Width1 = 0.05
        beam.Transparency = NumberSequence.new(0)
        d = {a=a,b=b,beam=beam}
        Tracers[p] = d
    end
    d.beam.Color = ColorSequence.new(Color3.fromRGB(255, 70, 70))
end

local function UpdateVisuals()
    if not Configs.ESP and not Configs.Name and not Configs.Tracer then
        ClearVisuals()
        return
    end

    for _, enemy in ipairs(GetEnemies()) do
        AddESP(enemy, enemy.Name, Color3.fromRGB(255, 90, 90))
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            AddESP(p.Character, p.DisplayName, Color3.fromRGB(255, 210, 90))
            UpdateTracerForPlayer(p)
        end
    end
end

local xrayConnection
local function ToggleXRay(enabled)
    Configs.XRay = enabled and true or false
    if xrayConnection then xrayConnection:Disconnect(); xrayConnection=nil end
    if not Configs.XRay then
        for part, original in pairs(XRayParts) do
            if part and part.Parent then part.LocalTransparencyModifier = original end
        end
        table.clear(XRayParts)
        return
    end
    local function apply(part)
        if not Configs.XRay or not part:IsA("BasePart") then return end
        local c = Character()
        if c and part:IsDescendantOf(c) then return end
        if XRayParts[part] == nil then XRayParts[part] = part.LocalTransparencyModifier end
        part.LocalTransparencyModifier = 0.55
    end
    for _, d in ipairs(workspace:GetDescendants()) do apply(d) end
    xrayConnection = workspace.DescendantAdded:Connect(function(d)
        task.defer(function() apply(d) end)
    end)
end

local function ToggleInvisibility(enabled)
    Configs.Invisibility = enabled and true or false
    local c = Character()
    if not c then return end
    if enabled then
        table.clear(invisOriginal)
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                invisOriginal[d] = d.Transparency
                d.Transparency = 1
            elseif d:IsA("Decal") then
                invisOriginal[d] = d.Transparency
                d.Transparency = 1
            end
        end
    else
        for part, value in pairs(invisOriginal) do
            if part and part.Parent then part.Transparency = value end
        end
        table.clear(invisOriginal)
    end
end

-- ==================== CALLBACK API ====================
_G.AkatCallbacks = {
    AutoFarmLevel = function(enabled)
        Configs.AutoFarmLevel = enabled and true or false
        if Configs.AutoFarmLevel then
            State.RunningMode = "Level"
        end
    end,

    AutoFarmBoss = function(enabled)
        Configs.AutoFarmBoss = enabled and true or false
        if Configs.AutoFarmBoss then State.RunningMode = "Boss" end
    end,

    AutoFarmMastery = function(enabled)
        Configs.AutoFarmMastery = enabled and true or false
        if Configs.AutoFarmMastery then State.RunningMode = "Mastery" end
    end,

    AutoFruitMastery = function(enabled)
        Configs.AutoFruitMastery = enabled and true or false
        if enabled then Configs.AutoFarmMastery = true end
    end,

    AutoGunMastery = function(enabled)
        Configs.AutoGunMastery = enabled and true or false
        if enabled then Configs.AutoFarmMastery = true end
    end,

    AutoSwordMastery = function(enabled)
        Configs.AutoSwordMastery = enabled and true or false
        if enabled then Configs.AutoFarmMastery = true end
    end,

    AutoBones = function(enabled)
        Configs.AutoBones = enabled and true or false
        if enabled then Configs.MaterialTarget = "Bones" end
    end,

    AutoMaterials = function(enabled)
        Configs.AutoMaterials = enabled and true or false
    end,

    AutoChests = function(enabled)
        Configs.AutoChests = enabled and true or false
    end,

    MobAura = function(enabled)
        Configs.MobAura = enabled and true or false
    end,

    AutoSkills = function(enabled)
        Configs.AutoSkills = enabled and true or false
    end,

    SafeFarm = function(enabled)
        Configs.SafeFarm = enabled and true or false
    end,

    FarmWorld = function(value)
        Configs.FarmWorld = tostring(value)
        State.CurrentQuest = nil
    end,

    BossTarget = function(value)
        Configs.BossTarget = tostring(value)
        State.CurrentBoss = nil
    end,

    MasteryWeapon = function(value)
        Configs.MasteryWeapon = tostring(value)
        State.MasteryTool = nil
    end,

    MaterialTarget = function(value)
        Configs.MaterialTarget = tostring(value)
    end,

    MobRadius = function(value)
        Configs.MobRadius = math.clamp(tonumber(value) or 35, 5, 100)
    end,

    TpNearestMob = function() return TpNearestMob() end,
    TpBoss = function() return TpBoss() end,
    TpChest = function() return TpChest() end,
    TpSafe = function() return TpSafe() end,

    ESP = function(enabled)
        Configs.ESP = enabled and true or false
        if not Configs.ESP and not Configs.Name and not Configs.Tracer then ClearVisuals() end
    end,

    Name = function(enabled)
        Configs.Name = enabled and true or false
        if not Configs.Name and not Configs.ESP and not Configs.Tracer then ClearVisuals() end
    end,

    Tracer = function(enabled)
        Configs.Tracer = enabled and true or false
        if not Configs.Tracer then
            for p, d in pairs(Tracers) do
                pcall(function() d.a:Destroy() end)
                pcall(function() d.b:Destroy() end)
                pcall(function() d.beam:Destroy() end)
                Tracers[p] = nil
            end
        end
    end,

    XRay = function(enabled)
        ToggleXRay(enabled)
    end,

    Speed = function(value)
        if type(value) == "number" then
            Configs.SpeedValue = math.clamp(value, 0, 200)
            Configs.Speed = true
        else
            Configs.Speed = value and true or false
        end
    end,

    JumpPower = function(value)
        if type(value) == "number" then
            Configs.JumpPowerValue = math.clamp(value, 0, 200)
            Configs.JumpPower = true
        else
            Configs.JumpPower = value and true or false
        end
    end,

    AntiFling = function(enabled)
        Configs.AntiFling = enabled and true or false
    end,

    Invisibility = function(enabled)
        ToggleInvisibility(enabled)
    end,

    ShutdownAll = function()
        scriptAlive = false
        for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
        table.clear(Connections)
        if xrayConnection then xrayConnection:Disconnect(); xrayConnection=nil end
        ClearVisuals()
        for part, value in pairs(invisOriginal) do
            if part and part.Parent then part.Transparency=value end
        end
        table.clear(invisOriginal)
        _G.AkatLogicRunning = false
    end,
}

-- ==================== CHARACTER STATE ====================
local function RefreshCharacterState()
    local hum = Humanoid()
    if not hum then return end
    if not Configs.AutoFarmLevel and not Configs.AutoFarmBoss and not Configs.AutoFarmMastery
        and not Configs.AutoBones and not Configs.AutoMaterials and not Configs.AutoChests then
        hum.WalkSpeed = Configs.Speed and Configs.SpeedValue or 16
        hum.UseJumpPower = true
        hum.JumpPower = Configs.JumpPower and Configs.JumpPowerValue or 50
    end
end

table.insert(Connections, player.CharacterAdded:Connect(function()
    task.wait(0.8)
    RefreshCharacterState()
    if Configs.Invisibility then ToggleInvisibility(true) end
end))

-- ==================== MAIN FARM LOOP ====================
task.spawn(function()
    while scriptAlive do
        task.wait(0.10)
        if not Alive() then continue end

        local farmActive = Configs.AutoFarmLevel or Configs.AutoFarmBoss or Configs.AutoFarmMastery
            or Configs.AutoBones or Configs.AutoMaterials or Configs.AutoChests

        if farmActive then
            local hum = Humanoid()
            if hum then
                hum.WalkSpeed = 0
                hum.UseJumpPower = true
                hum.JumpPower = 0
            end
        end

        if Configs.AutoFarmLevel then
            AutoFarmLevelStep()
        elseif Configs.AutoFarmBoss then
            AutoBossStep()
        elseif Configs.AutoFarmMastery then
            AutoMasteryStep()
        elseif Configs.AutoBones then
            AutoBonesStep()
        elseif Configs.AutoMaterials then
            AutoMaterialsStep()
        elseif Configs.AutoChests then
            AutoChestStep()
        else
            State.RunningMode = "Idle"
        end

        if Configs.MobAura then KillAura() end
    end
end)

-- ==================== ANTI-FLING / MOVEMENT ====================
table.insert(Connections, RunService.Heartbeat:Connect(function()
    if not scriptAlive then return end
    local root = Root()
    local hum = Humanoid()
    if not root or not hum then return end

    local farmActive = Configs.AutoFarmLevel or Configs.AutoFarmBoss or Configs.AutoFarmMastery
        or Configs.AutoBones or Configs.AutoMaterials or Configs.AutoChests

    if not farmActive then
        hum.WalkSpeed = Configs.Speed and Configs.SpeedValue or 16
        hum.UseJumpPower = true
        hum.JumpPower = Configs.JumpPower and Configs.JumpPowerValue or 50
    end

    if Configs.AntiFling then
        if root.AssemblyLinearVelocity.Magnitude > 70 or root.AssemblyAngularVelocity.Magnitude > 70 then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
end))

-- ==================== VISUAL SCAN ====================
task.spawn(function()
    while scriptAlive do
        task.wait(0.35)
        if Configs.ESP or Configs.Name or Configs.Tracer then
            UpdateVisuals()
        end
    end
end)

-- ==================== STATE EXPORT ====================
_G.AkatBloxState = State

DebugLog("Init", "Blox Fruits backend iniciado.")
-- =====================================================================
-- AKAT BLOX FRUITS | RAW UI EMBED
-- Backend first, complete UI source appended below.
-- =====================================================================

-- [[ AKATSUKI UI ONLY [v6.0 - BLOX FRUITS FARM PANEL] - REFINED UNIFIED EDITION — FIXED BUILD ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer

-- Limpa uma instância anterior da UI para evitar conexões e objetos duplicados.
if _G.AkatUIShutdown then
	pcall(_G.AkatUIShutdown)
end

-- ==================== ESTADO DOS TOGGLES DA UI ====================
local Configs = {
	ESP              = false,
	Name             = false,
	Tracer           = false,
	XRay             = false,
	Speed            = false,
	SpeedValue       = 16,
	JumpPower        = false,
	JumpPowerValue   = 50,
	AntiFling        = false,
	Invisibility     = false,
	AutoFarmLevel    = false,
	AutoFarmBoss     = false,
	AutoFarmMastery  = false,
	AutoFruitMastery = false,
	AutoGunMastery   = false,
	AutoSwordMastery = false,
	AutoBones        = false,
	AutoMaterials    = false,
	AutoChests       = false,
	MobAura          = false,
	AutoSkills       = false,
	SafeFarm         = true,
	FarmWorld        = "First Sea",
	BossTarget       = "Auto",
	MasteryWeapon    = "Auto",
	MaterialTarget   = "Bones",
	MobRadius        = 35,
	TeleportDelay    = 0.20,
	Debug            = false,
}

-- ==================== DYNAMIC UI COMPONENT & STATE MACHINE ====================
local UIState = "CLOSED"

local UI_TEXT = {
	SearchPlaceholder = "Pesquisar...",
	ConfirmCloseTitle = "Deseja fechar o script?",
	ConfirmBtn        = "Sim",
	CancelBtn         = "Não",
	Intro             = '<font color="#FFFFFF">Scripts by | </font><font color="#8B0000">AKATSUKI</font>',
	Tabs              = {
		Farming = "Farming",
		Combat = "Combat",
		Visuals = "Visuals",
		Teleports = "Teleports",
		Settings = "Settings",
	},
	Options = {
		AutoFarmLevel    = { Title = "Auto Farm Level",    Desc = "Aceita quests, encontra o grupo de mobs correto e repete o ciclo automaticamente." },
		AutoFarmBoss     = { Title = "Auto Farm Boss",     Desc = "Procura o boss selecionado, ataca com a arma equipada e repete após o respawn." },
		AutoFarmMastery  = { Title = "Auto Farm Mastery",  Desc = "Farma mastery com alvo inteligente para Fruit, Gun ou Sword." },
		AutoFruitMastery = { Title = "Auto Fruit Mastery", Desc = "Prioriza habilidades do fruto selecionado para acumular mastery." },
		AutoGunMastery   = { Title = "Auto Gun Mastery",   Desc = "Usa a gun selecionada contra alvos com vida suficiente para não desperdiçar dano." },
		AutoSwordMastery = { Title = "Auto Sword Mastery", Desc = "Equipa a espada selecionada e usa ataques em loop contra mobs adequados." },
		AutoBones        = { Title = "Auto Farm Bones",    Desc = "Procura mobs que concedem Bones e coleta o recurso automaticamente." },
		AutoMaterials    = { Title = "Auto Farm Materials",Desc = "Seleciona materiais disponíveis e procura os mobs/itens correspondentes." },
		AutoChests       = { Title = "Auto Farm Chests",   Desc = "Vasculha o mapa por baús e coleta os pontos encontrados." },
		MobAura          = { Title = "Mob Aura",            Desc = "Mantém o personagem próximo dos mobs e executa o ataque automaticamente." },
		AutoSkills       = { Title = "Auto Skills",         Desc = "Executa habilidades disponíveis do fruto/arma em ciclo controlado." },
		SafeFarm         = { Title = "Safe Farm",           Desc = "Usa pausas e limites de teleporte para reduzir travamentos e reposicionamentos excessivos." },
		AntiFling        = { Title = "Anti-Fling",          Desc = "Reduz efeitos de física que podem lançar o personagem para longe." },
		Invisibility     = { Title = "Invisibility",       Desc = "Torna o personagem localmente invisível." },
		ESP              = { Title = "NPC / Player ESP",   Desc = "Destaca alvos e jogadores para facilitar a visualização durante o farm." },
		Name             = { Title = "Name ESP",            Desc = "Exibe nomes dos jogadores e NPCs próximos." },
		Tracer           = { Title = "Tracer ESP",          Desc = "Desenha linhas até jogadores e alvos encontrados." },
		XRay             = { Title = "X-Ray",               Desc = "Aumenta a transparência local de partes do mapa." },
		Speed             = { Title = "Speed",              Desc = "Ajusta a velocidade do personagem fora do farm." },
		JumpPower         = { Title = "Jump",               Desc = "Ajusta a força do pulo do personagem." },
		TpNearestMob      = { Title = "TP Nearest Mob",     Desc = "Teleporta uma vez para o NPC hostil mais próximo." },
		TpBoss            = { Title = "TP Boss",            Desc = "Teleporta uma vez para o boss atualmente selecionado." },
		TpChest           = { Title = "TP Chest",            Desc = "Teleporta uma vez para o baú detectado mais próximo." },
		TpSafe            = { Title = "TP Safe Farm Spot",  Desc = "Reposiciona para um ponto seguro próximo do alvo atual." },
	},
}

local activeTab     = "Player"
local tabButtons    = {}
local isExpanded    = false
local originalTrans = {}
local isConfirmOpen = false

-- ==================== DIMENSIONAMENTO RESPONSIVO ====================
local NORMAL_UI_SIZE   = Vector2.new(565, 385)
local EXPANDED_UI_SIZE = Vector2.new(905, 405)
local UI_SAFE_MARGIN   = 14

local function GetViewportSize()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1280, 720)
end

local FLOATING_BUTTON_SIZE = Vector2.new(150, 48)
local FLOATING_GAP = 18

local function ClampFloatingPosition(pos)
	local vp = GetViewportSize()
	local halfW, halfH = FLOATING_BUTTON_SIZE.X / 2, FLOATING_BUTTON_SIZE.Y / 2
	local minX = halfW + 8
	local maxX = vp.X - halfW - 8
	local minY = halfH + 8
	local maxY = vp.Y - halfH - 8

	-- Zona reservada para o analógico virtual no canto inferior esquerdo.
	if pos.X < 210 and pos.Y > vp.Y - 210 then
		pos = Vector2.new(220, math.min(pos.Y, vp.Y - 230))
	end

	return Vector2.new(math.clamp(pos.X, minX, maxX), math.clamp(pos.Y, minY, maxY))
end

local function GetResponsiveUISizes()
	local vp = GetViewportSize()
	local maxW = math.max(1, vp.X - (UI_SAFE_MARGIN * 2))
	local maxH = math.max(1, vp.Y - (UI_SAFE_MARGIN * 2))

	local normalW = math.min(NORMAL_UI_SIZE.X, maxW)
	local normalH = math.min(NORMAL_UI_SIZE.Y, maxH)
	local expandedW = math.min(EXPANDED_UI_SIZE.X, maxW)
	local expandedH = math.min(EXPANDED_UI_SIZE.Y, maxH)

	return UDim2.fromOffset(normalW, normalH), UDim2.fromOffset(expandedW, expandedH)
end

local function ClampMainWrapperToViewport()
	if not mainWrapper or not mainWrapper.Parent then return end

	local vp = GetViewportSize()
	local size = mainWrapper.AbsoluteSize
	local halfW = math.min(size.X / 2, math.max(0, vp.X / 2 - UI_SAFE_MARGIN))
	local halfH = math.min(size.Y / 2, math.max(0, vp.Y / 2 - UI_SAFE_MARGIN))

	local pos = mainWrapper.AbsolutePosition + (size / 2)
	local x = math.clamp(pos.X, halfW + UI_SAFE_MARGIN, vp.X - halfW - UI_SAFE_MARGIN)
	local y = math.clamp(pos.Y, halfH + UI_SAFE_MARGIN, vp.Y - halfH - UI_SAFE_MARGIN)

	mainWrapper.Position = UDim2.fromOffset(x, y)
end

-- ==================== SCREENGUI ====================
local screenGui           = Instance.new("ScreenGui")
screenGui.Name            = "AkatBloxFruitsUI"
screenGui.ResetOnSpawn    = false
screenGui.IgnoreGuiInset  = true
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then
	uiParent = gethui()
else
	pcall(function() uiParent = game:GetService("CoreGui") end)
end

if uiParent:FindFirstChild("AkatBloxFruitsUI") then
	pcall(function() uiParent.AkatBloxFruitsUI:Destroy() end)
end

for _, bf in ipairs(Lighting:GetChildren()) do
	if bf:IsA("BlurEffect") and (bf.Name == "ConfirmBlur" or bf.Name == "IntroBlur") then
		pcall(function() bf:Destroy() end)
	end
end

screenGui.Parent = uiParent

local SharedClickSound     = Instance.new("Sound", screenGui)
SharedClickSound.Name      = "SharedClickSound"
SharedClickSound.SoundId   = "rbxassetid://6895079853"
SharedClickSound.Volume    = 0.6
SharedClickSound.Looped    = false

local function PlayUI_Click()
	pcall(function()
		SharedClickSound.TimePosition = 0
		SharedClickSound:Play()
	end)
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
	if not raiz or not raiz.Parent then return end
	local info = TweenInfo.new(duracao, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	local function tratarObjeto(obj)
		if not obj or not obj.Parent then return end
		RegistrarTransparencias(obj)
		local orig = originalTrans[obj]
		if not orig then return end
		if orig.BackgroundTransparency ~= nil then
			local t = fadeOut and 1 or orig.BackgroundTransparency
			if obj.BackgroundTransparency ~= t then
				if duracao == 0 then obj.BackgroundTransparency = t
				else TweenService:Create(obj, info, {BackgroundTransparency = t}):Play() end
			end
		end
		if orig.TextTransparency ~= nil then
			local t = fadeOut and 1 or orig.TextTransparency
			if obj.TextTransparency ~= t then
				if duracao == 0 then obj.TextTransparency = t
				else TweenService:Create(obj, info, {TextTransparency = t}):Play() end
			end
		end
		if orig.ImageTransparency ~= nil then
			local t = fadeOut and 1 or orig.ImageTransparency
			if obj.ImageTransparency ~= t then
				if duracao == 0 then obj.ImageTransparency = t
				else TweenService:Create(obj, info, {ImageTransparency = t}):Play() end
			end
		end
		if orig.Transparency ~= nil then
			local t = fadeOut and 1 or orig.Transparency
			if obj.Transparency ~= t then
				if duracao == 0 then obj.Transparency = t
				else TweenService:Create(obj, info, {Transparency = t}):Play() end
			end
		end
	end
	tratarObjeto(raiz)
	for _, desc in ipairs(raiz:GetDescendants()) do tratarObjeto(desc) end
end

-- ==================== BOTÃO FLUTUANTE ====================
local FloatBtn = Instance.new("ImageButton", screenGui)
FloatBtn.Name                = "FloatBtn"
FloatBtn.AnchorPoint         = Vector2.new(0.5, 0.5)
FloatBtn.Size                = UDim2.new(0, 44, 0, 44)
FloatBtn.Position         = UDim2.new(0.06, 0, 0.2, 0)
FloatBtn.Image               = "rbxthumb://type=Asset&id=139044062702391&w=150&h=150"
FloatBtn.BackgroundColor3    = Color3.fromRGB(15, 0, 0)
FloatBtn.Visible             = false
FloatBtn.ZIndex              = 100
FloatBtn.ClipsDescendants    = false
FloatBtn.AutoButtonColor     = false
if not FloatBtn:FindFirstChildOfClass("UICorner") then
	Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)
end

local FloatOpenSound         = Instance.new("Sound", FloatBtn)
FloatOpenSound.Name          = "FloatOpenSound"
FloatOpenSound.SoundId       = "rbxassetid://6310837681"
FloatOpenSound.Volume        = 0.2
FloatOpenSound.Looped        = false

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({FloatOpenSound, SharedClickSound})
	end)
end)

-- ==================== DRAG DO FLOATING BUTTON ====================
local dragToggleF  = false
local dragInputF   = nil
local dragStartF   = nil
local startPosF    = nil
local isDraggingF  = false

FloatBtn.InputBegan:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch)
		and not dragToggleF then
		dragToggleF  = true
		dragInputF   = input
		isDraggingF  = false
		dragStartF   = input.Position
		startPosF    = FloatBtn.Position
	end
end)

local SetUIState 

-- ==================== DRAG DA JANELA PRINCIPAL ====================
local mainWrapper         = Instance.new("Frame", screenGui)
mainWrapper.Name          = "MainWrapper"
mainWrapper.AnchorPoint   = Vector2.new(0.5, 0.5)
mainWrapper.Size          = UDim2.new(0, 640, 0, 360)
mainWrapper.Position      = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible       = false
mainWrapper.ClipsDescendants = false
mainWrapper.ZIndex        = 1

local mainFrame           = Instance.new("Frame", mainWrapper)
mainFrame.Name            = "MainFrame"
mainFrame.Size            = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.ZIndex          = 2
mainFrame.ClipsDescendants = false

local dragUIToggle = false
local dragUIInput  = nil
local dragUIStart  = nil
local startUIPos   = nil

mainFrame.InputBegan:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch)
		and not dragUIToggle then
		dragUIToggle = true
		dragUIInput  = input
		dragUIStart  = input.Position
		startUIPos   = mainWrapper.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragUIToggle and input == dragUIInput then
		local delta   = input.Position - dragUIStart
		local vp      = workspace.CurrentCamera.ViewportSize
		local hw      = mainWrapper.Size.X.Offset / 2
		local hh      = mainWrapper.Size.Y.Offset / 2
		local newX    = startUIPos.X.Offset + delta.X
		local newY    = startUIPos.Y.Offset + delta.Y
		local absX    = vp.X * startUIPos.X.Scale + newX
		local absY    = vp.Y * startUIPos.Y.Scale + newY
		absX          = math.clamp(absX, hw, vp.X - hw)
		absY          = math.clamp(absY, hh, vp.Y - hh)
		mainWrapper.Position = UDim2.new(0, absX, 0, absY)
	end

	if dragToggleF and input == dragInputF then
		local delta   = input.Position - dragStartF
		if delta.Magnitude > 5 then isDraggingF = true end

		local vp      = workspace.CurrentCamera.ViewportSize
		local half    = 22
		local baseAbsX = vp.X * startPosF.X.Scale + startPosF.X.Offset
		local baseAbsY = vp.Y * startPosF.Y.Scale + startPosF.Y.Offset
		local newAbsX  = math.clamp(baseAbsX + delta.X, half, vp.X - half)
		local newAbsY  = math.clamp(baseAbsY + delta.Y, half, vp.Y - half)
		FloatBtn.Position = UDim2.new(0, newAbsX, 0, newAbsY)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input == dragInputF then
		if dragToggleF and not isDraggingF then
			if UIState == "MINIMIZED" or UIState == "CLOSED" then
				pcall(function()
					FloatOpenSound.TimePosition = 0
					FloatOpenSound:Play()
				end)
				SetUIState("OPEN")
			elseif UIState == "OPEN" then
				SetUIState("MINIMIZED")
			end
		end
		dragToggleF = false
		dragInputF  = nil
	end

	if input == dragUIInput then
		dragUIToggle = false
		dragUIInput  = nil
	end
end)


-- ==================== FLOATING ACTION BUTTONS ====================
local floatingButtons = {}
local floatingDragState = nil
local floatingActionDebounce = {}
local FLOATING_ACTION_DEBOUNCE = 0.45

-- Reserva uma área para o thumbstick móvel no canto inferior esquerdo.
local function ClampFloatingToSafeArea(position)
    local vp = GetViewportSize()
    local halfW = FLOATING_BUTTON_SIZE.X * 0.5
    local halfH = FLOATING_BUTTON_SIZE.Y * 0.5
    local x = math.clamp(position.X, halfW + UI_SAFE_MARGIN, vp.X - halfW - UI_SAFE_MARGIN)
    local y = math.clamp(position.Y, halfH + UI_SAFE_MARGIN, vp.Y - halfH - UI_SAFE_MARGIN)
    -- Zona reservada para o analógico do mobile (canto inferior esquerdo)
    if x < 230 and y > vp.Y - 220 then
        x = 230
        y = math.min(y, vp.Y - 230)
    end
    return Vector2.new(x, y)
end

local function GetFloatingInitialPosition(side)
    local vp = GetViewportSize()
    local mainPos = mainWrapper.AbsolutePosition
    local mainSize = mainWrapper.AbsoluteSize

    if mainSize.X <= 0 or mainSize.Y <= 0 then
        mainPos = Vector2.new(vp.X * 0.5 - 320, vp.Y * 0.5 - 180)
        mainSize = Vector2.new(640, 360)
    end

    local halfW = FLOATING_BUTTON_SIZE.X * 0.5
    local halfH = FLOATING_BUTTON_SIZE.Y * 0.5
    local centerY = mainPos.Y + mainSize.Y * 0.5

    local centerX
    if side == "right" then
        centerX = mainPos.X + mainSize.X + FLOATING_GAP + halfW
    else
        centerX = mainPos.X - FLOATING_GAP - halfW
    end

    local safePosition = ClampFloatingToSafeArea(Vector2.new(centerX, centerY))
    return UDim2.fromOffset(safePosition.X, safePosition.Y)
end

local function SetFloatingButtonPosition(button, position)
    if button and button.Parent then
        button.Position = position
    end
end

local function SetupFloatingDrag(inputObject, root)
    inputObject.Active = true

    inputObject.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if floatingDragState then return end

        floatingDragState = {
            root = root,
            input = input,
            inputType = input.UserInputType,
            startInputPosition = input.Position,
            startButtonPosition = root.Position,
            dragging = false,
        }
    end)
end

UserInputService.InputChanged:Connect(function(input)
    local state = floatingDragState
    if not state or not state.root or not state.root.Parent then return end

    local shouldMove
    if state.inputType == Enum.UserInputType.MouseButton1 then
        shouldMove = input.UserInputType == Enum.UserInputType.MouseMovement
    else
        shouldMove = input.UserInputType == Enum.UserInputType.Touch
    end
    if not shouldMove then return end

    local delta = input.Position - state.startInputPosition
    if delta.Magnitude > 5 then state.dragging = true end

    local vp = GetViewportSize()
    local startX = state.startButtonPosition.X.Offset + vp.X * state.startButtonPosition.X.Scale
    local startY = state.startButtonPosition.Y.Offset + vp.Y * state.startButtonPosition.Y.Scale
    local safePosition = ClampFloatingToSafeArea(Vector2.new(startX + delta.X, startY + delta.Y))
    SetFloatingButtonPosition(state.root, UDim2.fromOffset(safePosition.X, safePosition.Y))
end)

UserInputService.InputEnded:Connect(function(input)
    local state = floatingDragState
    if not state or input ~= state.input then return end

    local root = state.root
    local wasDragging = state.dragging
    local buttonKey = root and root:GetAttribute("FloatingButtonKey")
    floatingDragState = nil

    if not wasDragging and root and root.Parent then
        local action = floatingButtons[buttonKey]
        local now = os.clock()
        local last = floatingActionDebounce[buttonKey] or 0

        -- Proteção contra toque duplo/acidental no mobile. Um único toque
        -- gera no máximo uma ação dentro desta pequena janela.
        if action and action.callback and (now - last) >= FLOATING_ACTION_DEBOUNCE then
            floatingActionDebounce[buttonKey] = now
            task.spawn(action.callback)
        end
    end
end)

function CreateFloatingButton(buttonKey, text, side, callback)
    local existing = floatingButtons[buttonKey]
    if existing and existing.root and existing.root.Parent then
        if existing.destroyTween then
            pcall(function() existing.destroyTween:Cancel() end)
            existing.destroyTween = nil
        end
        existing.destroying = false
        existing.callback = callback
        existing.root.Visible = true

        TweenService:Create(
            existing.root,
            TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {GroupTransparency = 0}
        ):Play()

        if existing.scale then
            TweenService:Create(
                existing.scale,
                TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Scale = 1}
            ):Play()
        end

        return existing.root
    end

    floatingButtons[buttonKey] = nil

    local root = Instance.new("CanvasGroup")
    root.Name = buttonKey .. "Button"
    root:SetAttribute("FloatingButtonKey", buttonKey)
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Size = UDim2.fromOffset(FLOATING_BUTTON_SIZE.X, FLOATING_BUTTON_SIZE.Y)
    root.Position = GetFloatingInitialPosition(side)
    root.BackgroundTransparency = 1
    root.GroupTransparency = 1
    root.ZIndex = 80
    root.Parent = screenGui

    local button = Instance.new("TextButton")
    button.Name = "Action"
    button.Size = UDim2.fromScale(1, 1)
    button.BackgroundColor3 = Color3.fromRGB(18, 2, 4)
    button.BackgroundTransparency = 0.42
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 17
    button.Font = Enum.Font.GothamBold
    button.ZIndex = 81
    button.Parent = root

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = button

    button.TextColor3 = Color3.fromRGB(255, 255, 255)

    -- Uma única borda interna. Evita as pontas vermelhas que apareciam
    -- para fora do arredondamento do botão em telas móveis.
    root.ClipsDescendants = true
    button.ClipsDescendants = true
    local rootCorner = Instance.new("UICorner")
    rootCorner.CornerRadius = UDim.new(0, 14)
    rootCorner.Parent = root

    -- O AUTO SHOOT não usa UIStroke: o stroke vermelho era o responsável
    -- pelas pontas/bordas escapando para fora em alguns aparelhos móveis.
    if buttonKey ~= "Never" then
        local stroke = Instance.new("UIStroke")
        stroke.Name = "CleanBorder"
        stroke.Thickness = 1
        stroke.Transparency = 0.18
        stroke.Color = Color3.fromRGB(150, 20, 28)
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = button
    end

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 55, 65)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(145, 0, 12)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 0, 7)),
    })
    gradient.Rotation = 45
    gradient.Parent = button

    local scale = Instance.new("UIScale")
    scale.Scale = 0.88
    scale.Parent = root

    floatingButtons[buttonKey] = {
        root = root,
        gradient = gradient,
        callback = callback,
        scale = scale,
        destroying = false,
        destroyTween = nil,
    }

    SetupFloatingDrag(button, root)

    task.spawn(function()
        local rotation = 45
        while root.Parent and floatingButtons[buttonKey] and floatingButtons[buttonKey].root == root do
            rotation = (rotation + 1.5) % 360
            if gradient and gradient.Parent then gradient.Rotation = rotation end
            task.wait(0.03)
        end
    end)

    TweenService:Create(
        root,
        TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {GroupTransparency = 0}
    ):Play()

    TweenService:Create(
        scale,
        TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Scale = 1}
    ):Play()

    return root
end

function DestroyFloatingButton(buttonKey)
    local data = floatingButtons[buttonKey]
    if not data or data.destroying then return end

    local root = data.root
    if not root or not root.Parent then
        floatingButtons[buttonKey] = nil
        return
    end

    data.destroying = true
    floatingActionDebounce[buttonKey] = nil

    if floatingDragState and floatingDragState.root == root then
        floatingDragState = nil
    end

    local scale = data.scale
    local fade = TweenService:Create(
        root,
        TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {GroupTransparency = 1}
    )
    local shrink = scale and TweenService:Create(
        scale,
        TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Scale = 0.88}
    )

    data.destroyTween = fade
    fade:Play()
    if shrink then shrink:Play() end

    fade.Completed:Connect(function()
        if floatingButtons[buttonKey] ~= data then return end

        floatingButtons[buttonKey] = nil
        if root and root.Parent then
            root:Destroy()
        end
    end)
end

local function SyncFloatingButton(configKey)
	if configKey == "AutoFarmLevel" then
		if Configs[configKey] then
			CreateFloatingButton(
				"AutoFarmLevel",
				"FARM LEVEL",
				"right",
				function()
					if _G.AkatCallbacks and type(_G.AkatCallbacks.AutoFarmLevel) == "function" then
						task.spawn(function() pcall(_G.AkatCallbacks.AutoFarmLevel, true) end)
					end
				end
			)
		else
			DestroyFloatingButton("AutoFarmLevel")
		end
	end
end

_G.AkatUIShutdown = function()
    if floatingDragState then
        floatingDragState = nil
    end

    for key, data in pairs(floatingButtons) do
        if data and data.root then
            pcall(function()
                if data.root.Parent then
                    data.root:Destroy()
                end
            end)
        end
        floatingButtons[key] = nil
    end

    pcall(function()
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end)
end

-- ==================== ESTRUTURA UNIFICADA DA JANELA ====================
local Shadow               = Instance.new("ImageLabel", mainFrame)
Shadow.Name                = "WindowShadow"
Shadow.AnchorPoint         = Vector2.new(0, 0)
Shadow.Position            = UDim2.new(0, -12, 0, -12)
Shadow.Size                = UDim2.new(1, 24, 1, 24)
Shadow.BackgroundTransparency = 1
Shadow.Image               = "rbxassetid://5554831957"
Shadow.ImageColor3         = Color3.fromRGB(5, 0, 1)
Shadow.ImageTransparency   = 0.40
Shadow.ScaleType           = Enum.ScaleType.Slice
Shadow.SliceCenter         = Rect.new(36, 36, 114, 114)
Shadow.ZIndex              = 3

local MainBackground       = Instance.new("Frame", mainFrame)
MainBackground.Name        = "MainBackground"
MainBackground.Size        = UDim2.new(1, 0, 1, 0)
MainBackground.BackgroundColor3 = Color3.fromRGB(15, 0, 3)
MainBackground.BorderSizePixel = 0
MainBackground.ClipsDescendants = true
MainBackground.ZIndex      = 4
Instance.new("UICorner", MainBackground).CornerRadius = UDim.new(0, 10)

local MainStroke           = Instance.new("UIStroke", MainBackground)
MainStroke.Name            = "MainStroke"
MainStroke.Thickness       = 2
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.Color           = Color3.fromRGB(255, 255, 255)

local MainStrokeGrad       = Instance.new("UIGradient", MainStroke)
MainStrokeGrad.Rotation    = 45
MainStrokeGrad.Color       = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(50,  0,  5)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 20, 30))
})

local RedGradientOverlay   = Instance.new("Frame", MainBackground)
RedGradientOverlay.Name    = "RedGradientOverlay"
RedGradientOverlay.Size    = UDim2.new(1, 0, 1, 0)
RedGradientOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
RedGradientOverlay.BackgroundTransparency = 0
RedGradientOverlay.BorderSizePixel = 0
RedGradientOverlay.ZIndex  = 4
Instance.new("UICorner", RedGradientOverlay).CornerRadius = UDim.new(0, 10)

local SingleRedGrad        = Instance.new("UIGradient", RedGradientOverlay)
SingleRedGrad.Rotation     = 90
SingleRedGrad.Color        = ColorSequence.new({
	ColorSequenceKeypoint.new(0,   Color3.fromRGB(40, 0, 5)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 15, 22)),
	ColorSequenceKeypoint.new(1,   Color3.fromRGB(40, 0, 5))
})

local LeftPanel            = Instance.new("Frame", MainBackground)
LeftPanel.Name             = "LeftPanel"
LeftPanel.Size             = UDim2.new(0, 220, 1, 0)
LeftPanel.Position         = UDim2.new(0, 0, 0, 0)
LeftPanel.BackgroundTransparency = 1
LeftPanel.ZIndex           = 5

local RightPanel           = Instance.new("Frame", MainBackground)
RightPanel.Name            = "RightPanel"
RightPanel.Size            = UDim2.new(1, -220, 1, 0)
RightPanel.Position        = UDim2.new(0, 220, 0, 0)
RightPanel.BackgroundTransparency = 1
RightPanel.ZIndex          = 5

-- ==================== HEADER DA BARRA LATERAL ====================
local HeaderLeft           = Instance.new("Frame", LeftPanel)
HeaderLeft.Size            = UDim2.new(1, 0, 0, 36)
HeaderLeft.Position        = UDim2.new(0, 0, 0, 0)
HeaderLeft.BackgroundTransparency = 1
HeaderLeft.ZIndex          = 20

local HeaderImage          = Instance.new("ImageLabel", HeaderLeft)
HeaderImage.Size           = UDim2.new(0, 24, 0, 24)
HeaderImage.Position       = UDim2.new(0, 10, 0.5, -12)
HeaderImage.BackgroundTransparency = 1
HeaderImage.Image          = "rbxthumb://type=Asset&id=134217291845443&w=150&h=150"
HeaderImage.ZIndex         = 21

local title                = Instance.new("TextLabel", HeaderLeft)
title.Size                 = UDim2.new(1, -44, 0, 16)
title.Position             = UDim2.new(0, 40, 0, 4)
title.BackgroundTransparency = 1
title.Text                 = "AKATSUKI SCRIPTS HUB"
title.TextColor3           = Color3.fromRGB(245, 245, 245)
title.TextSize             = 13
title.Font                 = Enum.Font.GothamBold
title.TextXAlignment       = Enum.TextXAlignment.Left
title.ZIndex               = 21

local subtitle             = Instance.new("TextLabel", HeaderLeft)
subtitle.Size              = UDim2.new(1, -44, 0, 12)
subtitle.Position          = UDim2.new(0, 40, 0, 20)
subtitle.BackgroundTransparency = 1
subtitle.Text              = "BLOX FRUITS SCRIPT | by zeni"
subtitle.TextColor3        = Color3.fromRGB(180, 180, 180)
subtitle.TextTransparency  = 0.2
subtitle.TextSize          = 9.5
subtitle.Font              = Enum.Font.Gotham
subtitle.TextXAlignment    = Enum.TextXAlignment.Left
subtitle.ZIndex            = 21

-- ==================== BARRA DE PESQUISA ====================
local SearchContainer      = Instance.new("Frame", LeftPanel)
SearchContainer.Name       = "SearchContainer"
SearchContainer.Size       = UDim2.new(1, -16, 0, 36)
SearchContainer.Position   = UDim2.new(0, 8, 0, 44)
SearchContainer.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
SearchContainer.BackgroundTransparency = 0.85
SearchContainer.ZIndex     = 20
Instance.new("UICorner", SearchContainer).CornerRadius = UDim.new(0, 8)

local searchStroke         = Instance.new("UIStroke", SearchContainer)
searchStroke.Color         = Color3.fromRGB(60, 20, 20)
searchStroke.Transparency  = 0.75
searchStroke.Thickness     = 1

local SearchIconFrame      = Instance.new("Frame", SearchContainer)
SearchIconFrame.Size       = UDim2.new(0, 14, 0, 14)
SearchIconFrame.Position   = UDim2.new(0, 14, 0.5, -7)
SearchIconFrame.BackgroundTransparency = 1
SearchIconFrame.ZIndex     = 21

local scCircle             = Instance.new("Frame", SearchIconFrame)
scCircle.Size              = UDim2.new(0, 8, 0, 8)
scCircle.BackgroundTransparency = 1
Instance.new("UICorner", scCircle).CornerRadius = UDim.new(1, 0)
local scCStroke            = Instance.new("UIStroke", scCircle)
scCStroke.Color            = Color3.fromRGB(140, 140, 140)
scCStroke.Thickness        = 1.2

local scHandle             = Instance.new("Frame", SearchIconFrame)
scHandle.Size              = UDim2.new(0, 1.2, 0, 5)
scHandle.Position          = UDim2.new(0, 9, 0, 8)
scHandle.Rotation          = -45
scHandle.BackgroundColor3  = Color3.fromRGB(140, 140, 140)
scHandle.BorderSizePixel   = 0

local searchTextBox        = Instance.new("TextBox", SearchContainer)
searchTextBox.Size         = UDim2.new(1, -38, 1, 0)
searchTextBox.Position     = UDim2.new(0, 38, 0, 0)
searchTextBox.BackgroundTransparency = 1
searchTextBox.PlaceholderText  = UI_TEXT.SearchPlaceholder
searchTextBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
searchTextBox.Text         = ""
searchTextBox.TextColor3   = Color3.fromRGB(230, 230, 230)
searchTextBox.Font         = Enum.Font.GothamMedium
searchTextBox.TextSize     = 13
searchTextBox.TextXAlignment = Enum.TextXAlignment.Left
searchTextBox.ZIndex       = 22
searchTextBox.Active       = true
searchTextBox.ClearTextOnFocus = false

-- ==================== TABS CONTAINER ====================
local TabsContainer        = Instance.new("ScrollingFrame", LeftPanel)
TabsContainer.Name         = "TabsContainer"
TabsContainer.Size         = UDim2.new(1, -8, 1, -152)
TabsContainer.Position     = UDim2.new(0, 4, 0, 87)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ZIndex       = 10
TabsContainer.CanvasSize   = UDim2.new(0, 0, 0, 0)
TabsContainer.ScrollBarThickness = 2
TabsContainer.ScrollBarImageColor3 = Color3.fromRGB(200, 50, 50)
TabsContainer.ScrollBarImageTransparency = 0.45
TabsContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

local TabsLayout           = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder       = Enum.SortOrder.LayoutOrder
TabsLayout.Padding         = UDim.new(0, 2)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function UpdateTabsCanvas()
	local contentH = TabsLayout.AbsoluteContentSize.Y + 8
	local minH     = TabsContainer.AbsoluteSize.Y + 12
	TabsContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(contentH, minH))
end

TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabsCanvas)
TabsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTabsCanvas)

-- ==================== ACTIVEBAR REUTILIZÁVEL ====================
local ActiveBarContainer   = Instance.new("Frame", LeftPanel)
ActiveBarContainer.Name    = "ActiveBarContainer"
ActiveBarContainer.Size    = UDim2.new(1, -8, 1, -152)
ActiveBarContainer.Position = UDim2.new(0, 4, 0, 87)
ActiveBarContainer.BackgroundTransparency = 1
ActiveBarContainer.ClipsDescendants = true
ActiveBarContainer.ZIndex  = 8

local sharedActiveBar      = Instance.new("Frame", ActiveBarContainer)
sharedActiveBar.Name       = "SharedActiveBar"
sharedActiveBar.AnchorPoint = Vector2.new(0, 0.5)
sharedActiveBar.Size       = UDim2.new(0, 3, 0, 22)
sharedActiveBar.Position   = UDim2.new(0, 7, 0, 0)
sharedActiveBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sharedActiveBar.BorderSizePixel = 0
sharedActiveBar.Visible    = false
sharedActiveBar.ZIndex     = 8
sharedActiveBar.ClipsDescendants = false
Instance.new("UICorner", sharedActiveBar).CornerRadius = UDim.new(1, 0)

local activeBarScale = Instance.new("UIScale", sharedActiveBar)
activeBarScale.Scale = 1

local sharedBarGrad        = Instance.new("UIGradient", sharedActiveBar)
sharedBarGrad.Rotation     = 90
sharedBarGrad.Color        = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(120, 0, 10)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 30, 40)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(120, 0, 10))
})

-- ==================== USER PROFILE BADGE ====================
local UserProfileFrame     = Instance.new("Frame", LeftPanel)
UserProfileFrame.Size      = UDim2.new(1, -16, 0, 55)
UserProfileFrame.Position  = UDim2.new(0, 8, 1, -63)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(20, 12, 12)
UserProfileFrame.BackgroundTransparency = 0.35
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex    = 20
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 8)

local userStroke           = Instance.new("UIStroke", UserProfileFrame)
userStroke.Thickness       = 0.9
userStroke.Color           = Color3.fromRGB(255, 255, 255)
local uGrad                = Instance.new("UIGradient", userStroke)
uGrad.Color                = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 10, 15)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 0, 0))
})

local AvatarImage          = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Size           = UDim2.new(0, 34, 0, 34)
AvatarImage.Position       = UDim2.new(0, 10, 0.5, -17)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image          = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex         = 21
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

local AvatarStroke         = Instance.new("UIStroke", AvatarImage)
AvatarStroke.Thickness     = 0.9
AvatarStroke.Color         = Color3.fromRGB(255, 255, 255)
local avGrad               = Instance.new("UIGradient", AvatarStroke)
avGrad.Color               = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 10, 15)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 0, 0))
})

local StatusIndicator      = Instance.new("Frame", AvatarImage)
StatusIndicator.Size       = UDim2.new(0, 9, 0, 9)
StatusIndicator.Position   = UDim2.new(1, -7, 1, -7)
StatusIndicator.BackgroundColor3 = Color3.fromRGB(40, 220, 80)
StatusIndicator.BorderSizePixel = 0
StatusIndicator.ZIndex     = 22
Instance.new("UICorner", StatusIndicator).CornerRadius = UDim.new(1, 0)
local statusStroke         = Instance.new("UIStroke", StatusIndicator)
statusStroke.Color         = Color3.fromRGB(15, 5, 5)
statusStroke.Thickness     = 1.5

local DisplayNameLabel     = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Size      = UDim2.new(1, -82, 0, 16)
DisplayNameLabel.Position  = UDim2.new(0, 54, 0.5, -16)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text      = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
DisplayNameLabel.Font      = Enum.Font.GothamBold
DisplayNameLabel.TextSize  = 13.5
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLabel.ZIndex    = 21

local UsernameLabel        = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Size         = UDim2.new(1, -82, 0, 14)
UsernameLabel.Position     = UDim2.new(0, 54, 0.5, 2)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text         = "@" .. player.Name
UsernameLabel.TextColor3   = Color3.fromRGB(110, 110, 110)
UsernameLabel.Font         = Enum.Font.Gotham
UsernameLabel.TextSize     = 11.5
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UsernameLabel.ZIndex       = 21

local PrivacyBtn           = Instance.new("ImageButton", UserProfileFrame)
PrivacyBtn.Size            = UDim2.new(0, 20, 0, 20)
PrivacyBtn.Position        = UDim2.new(1, -26, 0.5, -10)
PrivacyBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
PrivacyBtn.BackgroundTransparency = 0.2
PrivacyBtn.BorderSizePixel = 0
PrivacyBtn.ZIndex          = 22
PrivacyBtn.AutoButtonColor = false
Instance.new("UICorner", PrivacyBtn).CornerRadius = UDim.new(0, 5)
local privStroke           = Instance.new("UIStroke", PrivacyBtn)
privStroke.Color           = Color3.fromRGB(60, 20, 20)
privStroke.Thickness       = 1
privStroke.Transparency    = 0.5

local PrivacyIcon          = Instance.new("ImageLabel", PrivacyBtn)
PrivacyIcon.Size           = UDim2.new(1, -6, 1, -6)
PrivacyIcon.Position       = UDim2.new(0, 3, 0, 3)
PrivacyIcon.BackgroundTransparency = 1
PrivacyIcon.Image          = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
PrivacyIcon.ImageColor3    = Color3.fromRGB(255, 255, 255)
PrivacyIcon.ZIndex         = 23

local isPrivate = false

PrivacyBtn.MouseButton1Click:Connect(function()
	PlayUI_Click()
	local flashTween = TweenService:Create(PrivacyBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {BackgroundTransparency = 0})
	flashTween:Play()

	isPrivate = not isPrivate
	if isPrivate then
		PrivacyIcon.Image = "rbxthumb://type=Asset&id=85795266774996&w=150&h=150"
		DisplayNameLabel.Text = string.rep("*", math.clamp(#player.DisplayName, 3, 8))
		UsernameLabel.Text    = "@" .. string.rep("*", math.clamp(#player.Name, 3, 8))
	else
		PrivacyIcon.Image = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
		DisplayNameLabel.Text = player.DisplayName
		UsernameLabel.Text    = "@" .. player.Name
	end
end)

-- ==================== RIGHT PANEL HEADER & BADGE ====================
local topButtons           = Instance.new("Frame", RightPanel)
topButtons.Size            = UDim2.new(1, -12, 0, 36)
topButtons.Position        = UDim2.new(0, 0, 0, 0)
topButtons.BackgroundTransparency = 1
topButtons.ZIndex          = 20

local ControlsFrame        = Instance.new("Frame", topButtons)
ControlsFrame.Size         = UDim2.new(0, 130, 1, 0)
ControlsFrame.Position     = UDim2.new(1, -130, 0, 0)
ControlsFrame.BackgroundTransparency = 1
ControlsFrame.ZIndex       = 25

local UIListTop            = Instance.new("UIListLayout", ControlsFrame)
UIListTop.FillDirection    = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding          = UDim.new(0, 2)
UIListTop.SortOrder        = Enum.SortOrder.LayoutOrder

local TOP_BTN_COLOR        = Color3.fromRGB(150, 150, 150)

local function CriarBotaoTopo(nome, idAsset, ordem)
	local btn              = Instance.new("ImageButton", ControlsFrame)
	btn.Name               = nome
	btn.LayoutOrder        = ordem
	btn.Size               = UDim2.new(0, 28, 0, 28)
	btn.BackgroundTransparency = 1
	btn.ZIndex             = 25
	btn.AutoButtonColor    = false

	local icon             = Instance.new("ImageLabel", btn)
	icon.Name              = "Icon"
	icon.AnchorPoint       = Vector2.new(0.5, 0.5)
	icon.Position          = UDim2.new(0.5, 0, 0.5, 0)
	icon.Size              = UDim2.new(0, 14, 0, 14)
	icon.BackgroundTransparency = 1
	icon.Image             = idAsset
	icon.ImageColor3       = TOP_BTN_COLOR
	icon.ZIndex            = 26

	return btn, icon
end

local MinimizeBtn, MinimizeIcon = CriarBotaoTopo("MinimizeBtn", "rbxthumb://type=Asset&id=97090905107587&w=150&h=150", 1)
local ExpandBtn,   ExpandIcon   = CriarBotaoTopo("ExpandBtn",   "rbxthumb://type=Asset&id=78749046909931&w=150&h=150", 2)
local CloseBtn,    CloseIcon    = CriarBotaoTopo("CloseBtn",    "rbxthumb://type=Asset&id=70710316269357&w=150&h=150", 3)

local BadgeFrame           = Instance.new("Frame", RightPanel)
BadgeFrame.Name            = "BadgeFrame"
BadgeFrame.Size            = UDim2.new(0, 44, 0, 18)
BadgeFrame.Position        = UDim2.new(0, 12, 0, 9)
BadgeFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
BadgeFrame.BorderSizePixel = 0
BadgeFrame.ZIndex          = 15
Instance.new("UICorner", BadgeFrame).CornerRadius = UDim.new(0, 8)

local badgeStroke          = Instance.new("UIStroke", BadgeFrame)
badgeStroke.Thickness      = 0.9
badgeStroke.Color          = Color3.fromRGB(255, 255, 255)

local badgeGrad            = Instance.new("UIGradient", BadgeFrame)
badgeGrad.Rotation         = 45
badgeGrad.Color            = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0))
})

local badgeStrokeGrad      = Instance.new("UIGradient", badgeStroke)
badgeStrokeGrad.Rotation   = 45
badgeStrokeGrad.Color      = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0))
})

local BadgeText            = Instance.new("TextLabel", BadgeFrame)
BadgeText.Size             = UDim2.new(1, 0, 1, 0)
BadgeText.BackgroundTransparency = 1
BadgeText.Text             = "BF 6.0"
BadgeText.TextColor3       = Color3.fromRGB(255, 255, 255)
BadgeText.Font             = Enum.Font.GothamBold
BadgeText.TextSize         = 8.5
BadgeText.ZIndex           = 16

-- ==================== TOGGLES CONTAINER ====================
local togglesContainer     = Instance.new("ScrollingFrame", RightPanel)
togglesContainer.Name      = "TogglesContainer"
togglesContainer.Size      = UDim2.new(1, -12, 1, -48)
togglesContainer.Position  = UDim2.new(0, 6, 0, 42)
togglesContainer.BackgroundColor3 = Color3.fromRGB(30, 12, 14)
togglesContainer.BackgroundTransparency = 0.7
togglesContainer.BorderSizePixel = 0
togglesContainer.ClipsDescendants = true
togglesContainer.ZIndex    = 10
togglesContainer.ScrollBarThickness = 2
togglesContainer.ScrollBarImageColor3 = Color3.fromRGB(220, 30, 40)
togglesContainer.ScrollBarImageTransparency = 0.35
togglesContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
togglesContainer.AutomaticCanvasSize = Enum.AutomaticSize.None
Instance.new("UICorner", togglesContainer).CornerRadius = UDim.new(0, 8)

local containerLayout      = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder  = Enum.SortOrder.LayoutOrder
containerLayout.Padding    = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local uiPadding            = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingTop       = UDim.new(0, 8)
uiPadding.PaddingBottom    = UDim.new(0, 8)
uiPadding.PaddingLeft      = UDim.new(0, 4)
uiPadding.PaddingRight     = UDim.new(0, 6)

local function UpdateCanvasSize()
	local contentHeight = containerLayout.AbsoluteContentSize.Y + 24
	local minHeight     = togglesContainer.AbsoluteSize.Y + 1
	togglesContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(contentHeight, minHeight))
end

containerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvasSize)
togglesContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateCanvasSize)

-- ==================== CONFIRM FRAME & INTENSE BLUR ====================
local confirmBlur          = Instance.new("BlurEffect", Lighting)
confirmBlur.Name           = "ConfirmBlur"
confirmBlur.Size           = 0

local confirmOverlay       = Instance.new("Frame", screenGui)
confirmOverlay.Name        = "ConfirmOverlay"
confirmOverlay.Size        = UDim2.new(1, 0, 1, 0)
confirmOverlay.Position    = UDim2.new(0, 0, 0, 0)
confirmOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
confirmOverlay.BackgroundTransparency = 0.55
confirmOverlay.Visible     = false
confirmOverlay.ZIndex      = 990
confirmOverlay.ClipsDescendants = true

local confirmCard          = Instance.new("Frame", confirmOverlay)
confirmCard.Name           = "ConfirmCard"
confirmCard.Size           = UDim2.new(0, 300, 0, 130)
confirmCard.AnchorPoint    = Vector2.new(0.5, 0.5)
confirmCard.Position       = UDim2.new(0.5, 0, 0.5, 0)
confirmCard.BackgroundColor3 = Color3.fromRGB(18, 8, 8)
confirmCard.BackgroundTransparency = 0
confirmCard.BorderSizePixel = 0
confirmCard.ZIndex         = 995
Instance.new("UICorner", confirmCard).CornerRadius = UDim.new(0, 14)

local confirmStroke        = Instance.new("UIStroke", confirmCard)
confirmStroke.Thickness    = 1.5
confirmStroke.Color        = Color3.fromRGB(255, 255, 255)

local confStrokeGrad       = Instance.new("UIGradient", confirmStroke)
confStrokeGrad.Color       = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(120, 0, 10)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 30, 40)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(120, 0, 10))
})

local confirmCardGrad      = Instance.new("UIGradient", confirmCard)
confirmCardGrad.Rotation   = 135
confirmCardGrad.Color      = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 10, 10)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12,  4,  4))
})

local confirmLabel         = Instance.new("TextLabel", confirmCard)
confirmLabel.Size          = UDim2.new(1, -24, 0, 22)
confirmLabel.Position      = UDim2.new(0, 12, 0, 18)
confirmLabel.BackgroundTransparency = 1
confirmLabel.TextColor3    = Color3.fromRGB(235, 235, 235)
confirmLabel.Font          = Enum.Font.GothamBold
confirmLabel.TextSize      = 13
confirmLabel.TextXAlignment = Enum.TextXAlignment.Center
confirmLabel.Text          = UI_TEXT.ConfirmCloseTitle
confirmLabel.ZIndex        = 1000

local confirmSep           = Instance.new("Frame", confirmCard)
confirmSep.Size            = UDim2.new(1, -40, 0, 1)
confirmSep.Position        = UDim2.new(0, 20, 0, 48)
confirmSep.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
confirmSep.BackgroundTransparency = 0.6
confirmSep.BorderSizePixel = 0
confirmSep.ZIndex          = 999
Instance.new("UICorner", confirmSep).CornerRadius = UDim.new(1, 0)

local btnYes               = Instance.new("TextButton", confirmCard)
btnYes.Size                = UDim2.new(0, 118, 0, 32)
btnYes.Position            = UDim2.new(0.5, -124, 0, 62)
btnYes.BackgroundColor3    = Color3.fromRGB(139, 0, 0)
btnYes.TextColor3          = Color3.fromRGB(255, 255, 255)
btnYes.Font                = Enum.Font.GothamMedium
btnYes.TextSize            = 14
btnYes.Text                = UI_TEXT.ConfirmBtn
btnYes.ZIndex              = 1000
btnYes.BorderSizePixel     = 0
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 14)
local btnYesGrad           = Instance.new("UIGradient", btnYes)
btnYesGrad.Rotation        = 90
btnYesGrad.Color           = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 20, 20)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(100,  0,  0))
})

local btnNo                = Instance.new("TextButton", confirmCard)
btnNo.Size                 = UDim2.new(0, 118, 0, 32)
btnNo.Position             = UDim2.new(0.5, 6, 0, 62)
btnNo.BackgroundColor3     = Color3.fromRGB(30, 30, 30)
btnNo.TextColor3           = Color3.fromRGB(170, 170, 170)
btnNo.Font                 = Enum.Font.GothamMedium
btnNo.TextSize             = 14
btnNo.Text                 = UI_TEXT.CancelBtn
btnNo.ZIndex               = 1000
btnNo.BorderSizePixel      = 0
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 14)
local btnNoStroke          = Instance.new("UIStroke", btnNo)
btnNoStroke.Color          = Color3.fromRGB(60, 60, 60)
btnNoStroke.Thickness      = 1
btnNoStroke.Transparency   = 0.3

btnYes.MouseEnter:Connect(function() TweenService:Create(btnYes, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(180, 20, 20)}):Play() end)
btnYes.MouseLeave:Connect(function() TweenService:Create(btnYes, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(139,  0,  0)}):Play() end)
btnNo.MouseEnter:Connect(function()  TweenService:Create(btnNo,  TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(45, 45, 45)}):Play() end)
btnNo.MouseLeave:Connect(function()  TweenService:Create(btnNo,  TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play() end)

AplicarFadeSincronizado(confirmCard, true, 0)

-- ==================== RENDERSTEP UNIFICADO ====================
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	SingleRedGrad.Rotation   = 90 + math.sin(t * 0.55) * 28
	confStrokeGrad.Rotation  = 90 + math.sin(t * 0.70) * 25
	uGrad.Rotation           = 45 + math.sin(t * 0.80) * 35
	avGrad.Rotation          = 45 + math.sin(t * 0.80) * 35
	badgeGrad.Rotation       = 45 + math.sin(t * 0.45) * 20
	badgeStrokeGrad.Rotation = 45 + math.sin(t * 0.45) * 20
end)

-- ==================== SISTEMA DE NOTIFICAÇÃO (STACK / FILA) ====================
local ActiveNotifications = {}
local NOTIF_DURATION      = 10

local function UpdateNotifications()
	local currentY = -24
	for _, notif in ipairs(ActiveNotifications) do
		if notif and notif.Parent then
			local h = notif.Size.Y.Offset
			if h == 0 then h = 96 end
			TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				Position = UDim2.new(1, -20, 1, currentY)
			}):Play()
			currentY = currentY - (h + 12)
		end
	end
end

-- ==================== NOTIFICAÇÃO GENÉRICA ====================
local function CriarNotificacao(titulo, descricao, iconeId)
	local notifHolder              = Instance.new("Frame", screenGui)
	notifHolder.Name               = "NotifHolder"
	notifHolder.AnchorPoint        = Vector2.new(1, 1)
	notifHolder.Size               = UDim2.new(0, 330, 0, 96)
	notifHolder.Position           = UDim2.new(1, 340, 1, -24)
	notifHolder.BackgroundTransparency = 1
	notifHolder.ZIndex             = 200
	notifHolder.ClipsDescendants   = false

	local notifScale = Instance.new("UIScale", notifHolder)
	notifScale.Scale = 0.96

	local notifCard                = Instance.new("Frame", notifHolder)
	notifCard.Name                 = "NotifCard"
	notifCard.Size                 = UDim2.new(1, 0, 1, 0)
	notifCard.BackgroundColor3     = Color3.fromRGB(16, 16, 18)
	notifCard.BackgroundTransparency = 0.25
	notifCard.BorderSizePixel      = 0
	notifCard.ZIndex               = 201
	notifCard.ClipsDescendants     = false
	Instance.new("UICorner", notifCard).CornerRadius = UDim.new(0, 16)

	local notifShadow              = Instance.new("ImageLabel", notifCard)
	notifShadow.Name               = "Shadow"
	notifShadow.AnchorPoint        = Vector2.new(0.5, 0.5)
	notifShadow.Position           = UDim2.new(0.5, 0, 0.5, 4)
	notifShadow.Size               = UDim2.new(1, 24, 1, 24)
	notifShadow.BackgroundTransparency = 1
	notifShadow.Image              = "rbxassetid://5554831957"
	notifShadow.ImageColor3        = Color3.fromRGB(0, 0, 0)
	notifShadow.ImageTransparency  = 0.35
	notifShadow.ScaleType          = Enum.ScaleType.Slice
	notifShadow.SliceCenter        = Rect.new(36, 36, 114, 114)
	notifShadow.ZIndex             = 200

	local accentBar                = Instance.new("Frame", notifCard)
	accentBar.Size                 = UDim2.new(0, 4, 0, 52)
	accentBar.Position             = UDim2.new(0, 14, 0.5, -26)
	accentBar.BackgroundColor3     = Color3.fromRGB(180, 20, 20)
	accentBar.BorderSizePixel      = 0
	accentBar.ZIndex               = 202
	Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)
	local accentGrad               = Instance.new("UIGradient", accentBar)
	accentGrad.Rotation            = 90
	accentGrad.Color               = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 30, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 10, 10))
	})

	local notifTitle               = Instance.new("TextLabel", notifCard)
	notifTitle.Size                = UDim2.new(1, -76, 0, 18)
	notifTitle.Position            = UDim2.new(0, 26, 0.5, -19)
	notifTitle.BackgroundTransparency = 1
	notifTitle.Text                = titulo or "AKATSUKI"
	notifTitle.TextColor3          = Color3.fromRGB(240, 240, 240)
	notifTitle.Font                = Enum.Font.GothamBold
	notifTitle.TextSize            = 16
	notifTitle.TextXAlignment      = Enum.TextXAlignment.Left
	notifTitle.ZIndex              = 203

	local notifDesc                = Instance.new("TextLabel", notifCard)
	notifDesc.Size                 = UDim2.new(1, -76, 0, 18)
	notifDesc.Position             = UDim2.new(0, 26, 0.5, 1)
	notifDesc.BackgroundTransparency = 1
	notifDesc.Text                 = descricao or ""
	notifDesc.TextColor3           = Color3.fromRGB(150, 150, 155)
	notifDesc.Font                 = Enum.Font.Gotham
	notifDesc.TextSize             = 12
	notifDesc.TextXAlignment       = Enum.TextXAlignment.Left
	notifDesc.TextYAlignment       = Enum.TextYAlignment.Top
	notifDesc.TextWrapped          = true
	notifDesc.ZIndex               = 203

	local notifCloseBtn            = Instance.new("TextButton", notifCard)
	notifCloseBtn.Size             = UDim2.new(0, 24, 0, 24)
	notifCloseBtn.Position         = UDim2.new(1, -32, 0, 10)
	notifCloseBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
	notifCloseBtn.BackgroundTransparency = 0.2
	notifCloseBtn.Text             = ""
	notifCloseBtn.ZIndex           = 205
	notifCloseBtn.BorderSizePixel  = 0
	Instance.new("UICorner", notifCloseBtn).CornerRadius = UDim.new(0, 6)
	local xStroke                  = Instance.new("UIStroke", notifCloseBtn)
	xStroke.Color                  = Color3.fromRGB(80, 80, 85)
	xStroke.Thickness              = 1
	xStroke.Transparency           = 0.5

	local xL1                      = Instance.new("Frame", notifCloseBtn)
	xL1.AnchorPoint                = Vector2.new(0.5, 0.5)
	xL1.Position                   = UDim2.new(0.5, 0, 0.5, 0)
	xL1.Size                       = UDim2.new(0, 10, 0, 1.5)
	xL1.Rotation                   = 45
	xL1.BackgroundColor3           = Color3.fromRGB(160, 160, 165)
	xL1.BorderSizePixel            = 0
	xL1.ZIndex                     = 206
	Instance.new("UICorner", xL1).CornerRadius = UDim.new(1, 0)
	local xL2                      = Instance.new("Frame", notifCloseBtn)
	xL2.AnchorPoint                = Vector2.new(0.5, 0.5)
	xL2.Position                   = UDim2.new(0.5, 0, 0.5, 0)
	xL2.Size                       = UDim2.new(0, 10, 0, 1.5)
	xL2.Rotation                   = -45
	xL2.BackgroundColor3           = Color3.fromRGB(160, 160, 165)
	xL2.BorderSizePixel            = 0
	xL2.ZIndex                     = 206
	Instance.new("UICorner", xL2).CornerRadius = UDim.new(1, 0)

	notifCloseBtn.MouseEnter:Connect(function()
		TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160, 20, 20)}):Play()
		TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end)
	notifCloseBtn.MouseLeave:Connect(function()
		TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(35, 35, 38)}):Play()
		TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160, 160, 165)}):Play()
		TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160, 160, 165)}):Play()
	end)

	local progressBg               = Instance.new("Frame", notifCard)
	progressBg.Size                = UDim2.new(1, -28, 0, 3)
	progressBg.Position            = UDim2.new(0, 14, 1, -10)
	progressBg.BackgroundColor3    = Color3.fromRGB(30, 30, 35)
	progressBg.BorderSizePixel     = 0
	progressBg.ZIndex              = 202
	progressBg.ClipsDescendants    = true
	Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)

	local progressBar              = Instance.new("Frame", progressBg)
	progressBar.Size               = UDim2.new(1, 0, 1, 0)
	progressBar.Position           = UDim2.new(0, 0, 0, 0)
	progressBar.BackgroundColor3   = Color3.fromRGB(255, 255, 255)
	progressBar.BorderSizePixel    = 0
	progressBar.ZIndex             = 203
	Instance.new("UICorner", progressBar).CornerRadius = UDim.new(1, 0)
	local progressGrad             = Instance.new("UIGradient", progressBar)
	progressGrad.Color             = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 0, 0))
	})

	table.insert(ActiveNotifications, 1, notifHolder)
	UpdateNotifications()

	TweenService:Create(notifHolder, TweenInfo.new(0.30, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -20, 1, -24)
	}):Play()
	TweenService:Create(notifScale, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Scale = 1
	}):Play()

	local dismissed = false
	local function DismissNotif()
		if dismissed then return end
		dismissed = true
		for i, v in ipairs(ActiveNotifications) do
			if v == notifHolder then table.remove(ActiveNotifications, i) break end
		end
		UpdateNotifications()
		local slideOut = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		TweenService:Create(notifHolder, slideOut, {
			Position = UDim2.new(1, 360, notifHolder.Position.Y.Scale, notifHolder.Position.Y.Offset)
		}):Play()
		TweenService:Create(notifCard, slideOut, {BackgroundTransparency = 1}):Play()
		TweenService:Create(notifScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.96
		}):Play()
		task.delay(0.28, function()
			if notifHolder and notifHolder.Parent then notifHolder:Destroy() end
		end)
	end

	notifCloseBtn.MouseButton1Click:Connect(function() DismissNotif() end)
	local barTween = TweenService:Create(progressBar, TweenInfo.new(NOTIF_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 1, 0)})
	task.delay(0.1, function() barTween:Play() end)
	task.delay(NOTIF_DURATION + 0.1, function() DismissNotif() end)
end

-- ==================== NOTIFICAÇÃO DE LINK COPIADO ====================
local function CriarNotificacaoLinkCopiado(texto, iconeId)
	local notifHolder              = Instance.new("Frame", screenGui)
	notifHolder.Name               = "NotifHolderLink"
	notifHolder.AnchorPoint        = Vector2.new(1, 1)
	notifHolder.Size               = UDim2.new(0, 330, 0, 64)
	notifHolder.Position           = UDim2.new(1, 360, 1, -24)
	notifHolder.BackgroundTransparency = 1
	notifHolder.ZIndex             = 200
	notifHolder.ClipsDescendants   = false

	local notifScale = Instance.new("UIScale", notifHolder)
	notifScale.Scale = 0.96

	local notifCard                = Instance.new("Frame", notifHolder)
	notifCard.Name                 = "NotifCard"
	notifCard.Size                 = UDim2.new(1, 0, 1, 0)
	notifCard.BackgroundColor3     = Color3.fromRGB(16, 16, 18)
	notifCard.BackgroundTransparency = 0.25
	notifCard.BorderSizePixel      = 0
	notifCard.ZIndex               = 201
	notifCard.ClipsDescendants     = false
	Instance.new("UICorner", notifCard).CornerRadius = UDim.new(0, 16)

	local notifShadow              = Instance.new("ImageLabel", notifCard)
	notifShadow.Name               = "Shadow"
	notifShadow.AnchorPoint        = Vector2.new(0.5, 0.5)
	notifShadow.Position           = UDim2.new(0.5, 0, 0.5, 4)
	notifShadow.Size               = UDim2.new(1, 24, 1, 24)
	notifShadow.BackgroundTransparency = 1
	notifShadow.Image              = "rbxassetid://5554831957"
	notifShadow.ImageColor3        = Color3.fromRGB(0, 0, 0)
	notifShadow.ImageTransparency  = 0.35
	notifShadow.ScaleType          = Enum.ScaleType.Slice
	notifShadow.SliceCenter        = Rect.new(36, 36, 114, 114)
	notifShadow.ZIndex             = 200

	local accentBar                = Instance.new("Frame", notifCard)
	accentBar.Size                 = UDim2.new(0, 4, 0, 36)
	accentBar.Position             = UDim2.new(0, 14, 0.5, -18)
	accentBar.BackgroundColor3     = Color3.fromRGB(180, 20, 20)
	accentBar.BorderSizePixel      = 0
	accentBar.ZIndex               = 202
	Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)
	local accentGrad               = Instance.new("UIGradient", accentBar)
	accentGrad.Rotation            = 90
	accentGrad.Color               = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 30, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 10, 10))
	})

	local contentContainer         = Instance.new("Frame", notifCard)
	contentContainer.Size          = UDim2.new(1, -64, 1, -12)
	contentContainer.Position      = UDim2.new(0, 26, 0, 6)
	contentContainer.BackgroundTransparency = 1
	local cLayout                  = Instance.new("UIListLayout", contentContainer)
	cLayout.FillDirection          = Enum.FillDirection.Horizontal
	cLayout.SortOrder              = Enum.SortOrder.LayoutOrder
	cLayout.VerticalAlignment      = Enum.VerticalAlignment.Center
	cLayout.HorizontalAlignment    = Enum.HorizontalAlignment.Center
	cLayout.Padding                = UDim.new(0, 8)

	local notifText                = Instance.new("TextLabel", contentContainer)
	notifText.LayoutOrder          = 1
	notifText.AutomaticSize        = Enum.AutomaticSize.X
	notifText.Size                 = UDim2.new(0, 0, 0, 24)
	notifText.BackgroundTransparency = 1
	notifText.Text                 = texto or "LINK COPIED SUCCESSFULLY"
	notifText.TextColor3           = Color3.fromRGB(240, 240, 240)
	notifText.Font                 = Enum.Font.GothamBold
	notifText.TextSize             = 15
	notifText.TextXAlignment       = Enum.TextXAlignment.Left
	notifText.ZIndex               = 203

	if iconeId then
		local verifyIcon           = Instance.new("ImageLabel", contentContainer)
		verifyIcon.LayoutOrder     = 2
		verifyIcon.Size            = UDim2.new(0, 24, 0, 24)
		verifyIcon.BackgroundTransparency = 1
		verifyIcon.Image           = iconeId
		verifyIcon.ZIndex          = 204
	end

	local notifCloseBtn            = Instance.new("TextButton", notifCard)
	notifCloseBtn.Size             = UDim2.new(0, 20, 0, 20)
	notifCloseBtn.Position         = UDim2.new(1, -28, 0.5, -10)
	notifCloseBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
	notifCloseBtn.BackgroundTransparency = 0.2
	notifCloseBtn.Text             = ""
	notifCloseBtn.ZIndex           = 205
	notifCloseBtn.BorderSizePixel  = 0
	Instance.new("UICorner", notifCloseBtn).CornerRadius = UDim.new(0, 6)
	local xStroke                  = Instance.new("UIStroke", notifCloseBtn)
	xStroke.Color                  = Color3.fromRGB(80, 80, 85)
	xStroke.Thickness              = 1
	xStroke.Transparency           = 0.5
	local xL1                      = Instance.new("Frame", notifCloseBtn)
	xL1.AnchorPoint                = Vector2.new(0.5, 0.5)
	xL1.Position                   = UDim2.new(0.5, 0, 0.5, 0)
	xL1.Size                       = UDim2.new(0, 8, 0, 1.5)
	xL1.Rotation                   = 45
	xL1.BackgroundColor3           = Color3.fromRGB(160, 160, 165)
	xL1.BorderSizePixel            = 0
	xL1.ZIndex                     = 206
	Instance.new("UICorner", xL1).CornerRadius = UDim.new(1, 0)
	local xL2                      = Instance.new("Frame", notifCloseBtn)
	xL2.AnchorPoint                = Vector2.new(0.5, 0.5)
	xL2.Position                   = UDim2.new(0.5, 0, 0.5, 0)
	xL2.Size                       = UDim2.new(0, 8, 0, 1.5)
	xL2.Rotation                   = -45
	xL2.BackgroundColor3           = Color3.fromRGB(160, 160, 165)
	xL2.BorderSizePixel            = 0
	xL2.ZIndex                     = 206
	Instance.new("UICorner", xL2).CornerRadius = UDim.new(1, 0)

	notifCloseBtn.MouseEnter:Connect(function()
		TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160, 20, 20)}):Play()
		TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end)
	notifCloseBtn.MouseLeave:Connect(function()
		TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(35, 35, 38)}):Play()
		TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160, 160, 165)}):Play()
		TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160, 160, 165)}):Play()
	end)

	local progressBg               = Instance.new("Frame", notifCard)
	progressBg.Size                = UDim2.new(1, -28, 0, 3)
	progressBg.Position            = UDim2.new(0, 14, 1, -8)
	progressBg.BackgroundColor3    = Color3.fromRGB(30, 30, 35)
	progressBg.BorderSizePixel     = 0
	progressBg.ZIndex              = 202
	progressBg.ClipsDescendants    = true
	Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)
	local progressBar              = Instance.new("Frame", progressBg)
	progressBar.Size               = UDim2.new(1, 0, 1, 0)
	progressBar.Position           = UDim2.new(0, 0, 0, 0)
	progressBar.BackgroundColor3   = Color3.fromRGB(255, 255, 255)
	progressBar.BorderSizePixel    = 0
	progressBar.ZIndex             = 203
	Instance.new("UICorner", progressBar).CornerRadius = UDim.new(1, 0)
	local progressGrad             = Instance.new("UIGradient", progressBar)
	progressGrad.Color             = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 0, 0))
	})

	table.insert(ActiveNotifications, 1, notifHolder)
	UpdateNotifications()

	TweenService:Create(notifHolder, TweenInfo.new(0.30, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -20, 1, -24)
	}):Play()
	TweenService:Create(notifScale, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Scale = 1
	}):Play()

	local dismissed = false
	local function DismissNotif()
		if dismissed then return end
		dismissed = true
		for i, v in ipairs(ActiveNotifications) do
			if v == notifHolder then table.remove(ActiveNotifications, i) break end
		end
		UpdateNotifications()
		local slideOut = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		TweenService:Create(notifHolder, slideOut, {
			Position = UDim2.new(1, 360, notifHolder.Position.Y.Scale, notifHolder.Position.Y.Offset)
		}):Play()
		TweenService:Create(notifCard, slideOut, {BackgroundTransparency = 1}):Play()
		TweenService:Create(notifScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.96
		}):Play()
		task.delay(0.28, function()
			if notifHolder and notifHolder.Parent then notifHolder:Destroy() end
		end)
	end

	notifCloseBtn.MouseButton1Click:Connect(function() DismissNotif() end)
	local barTween = TweenService:Create(progressBar, TweenInfo.new(NOTIF_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 1, 0)})
	task.delay(0.1, function() barTween:Play() end)
	task.delay(NOTIF_DURATION + 0.1, function() DismissNotif() end)
end

-- ==================== NOTIFICAÇÃO DISCORD ====================
local function CriarNotificacaoDiscord()
	local notifHolder              = Instance.new("Frame", screenGui)
	notifHolder.Name               = "NotifHolderDiscord"
	notifHolder.AnchorPoint        = Vector2.new(1, 1)
	notifHolder.Size               = UDim2.new(0, 330, 0, 96)
	notifHolder.Position           = UDim2.new(1, 360, 1, -24)
	notifHolder.BackgroundTransparency = 1
	notifHolder.ZIndex             = 200
	notifHolder.ClipsDescendants   = false

	local notifScale = Instance.new("UIScale", notifHolder)
	notifScale.Scale = 0.96

	local notifCard                = Instance.new("Frame", notifHolder)
	notifCard.Name                 = "NotifCard"
	notifCard.Size                 = UDim2.new(1, 0, 1, 0)
	notifCard.BackgroundColor3     = Color3.fromRGB(16, 16, 18)
	notifCard.BackgroundTransparency = 0.25
	notifCard.BorderSizePixel      = 0
	notifCard.ZIndex               = 201
	notifCard.ClipsDescendants     = false
	Instance.new("UICorner", notifCard).CornerRadius = UDim.new(0, 16)

	local notifShadow              = Instance.new("ImageLabel", notifCard)
	notifShadow.Name               = "Shadow"
	notifShadow.AnchorPoint        = Vector2.new(0.5, 0.5)
	notifShadow.Position           = UDim2.new(0.5, 0, 0.5, 4)
	notifShadow.Size               = UDim2.new(1, 24, 1, 24)
	notifShadow.BackgroundTransparency = 1
	notifShadow.Image              = "rbxassetid://5554831957"
	notifShadow.ImageColor3        = Color3.fromRGB(0, 0, 0)
	notifShadow.ImageTransparency  = 0.35
	notifShadow.ScaleType          = Enum.ScaleType.Slice
	notifShadow.SliceCenter        = Rect.new(36, 36, 114, 114)
	notifShadow.ZIndex             = 200

	local accentBar                = Instance.new("Frame", notifCard)
	accentBar.Size                 = UDim2.new(0, 4, 0, 52)
	accentBar.Position             = UDim2.new(0, 14, 0.5, -26)
	accentBar.BackgroundColor3     = Color3.fromRGB(88, 101, 242)
	accentBar.BorderSizePixel      = 0
	accentBar.ZIndex               = 202
	Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

	local notifTitle               = Instance.new("TextLabel", notifCard)
	notifTitle.Size                = UDim2.new(1, -76, 0, 18)
	notifTitle.Position            = UDim2.new(0, 26, 0.5, -19)
	notifTitle.BackgroundTransparency = 1
	notifTitle.Text                = "DISCORD SERVER"
	notifTitle.TextColor3          = Color3.fromRGB(240, 240, 240)
	notifTitle.Font                = Enum.Font.GothamBold
	notifTitle.TextSize            = 16
	notifTitle.TextXAlignment      = Enum.TextXAlignment.Left
	notifTitle.ZIndex              = 203

	local notifDesc                = Instance.new("TextLabel", notifCard)
	notifDesc.Size                 = UDim2.new(1, -100, 0, 18)
	notifDesc.Position             = UDim2.new(0, 26, 0.5, 1)
	notifDesc.BackgroundTransparency = 1
	notifDesc.Text                 = "https://discord.gg/rZuYzZ7zvt"
	notifDesc.TextColor3           = Color3.fromRGB(150, 150, 155)
	notifDesc.Font                 = Enum.Font.Gotham
	notifDesc.TextSize             = 12
	notifDesc.TextXAlignment       = Enum.TextXAlignment.Left
	notifDesc.TextYAlignment       = Enum.TextYAlignment.Top
	notifDesc.TextWrapped          = true
	notifDesc.ZIndex               = 203

	local copyBtn                  = Instance.new("TextButton", notifCard)
	copyBtn.Size                   = UDim2.new(0, 70, 0, 24)
	copyBtn.AnchorPoint            = Vector2.new(1, 1)
	copyBtn.Position               = UDim2.new(1, -14, 1, -14)
	copyBtn.BackgroundColor3       = Color3.fromRGB(88, 101, 242)
	copyBtn.Text                   = "COPY"
	copyBtn.TextColor3             = Color3.fromRGB(255, 255, 255)
	copyBtn.Font                   = Enum.Font.GothamBold
	copyBtn.TextSize               = 12
	copyBtn.ZIndex                 = 205
	copyBtn.BorderSizePixel        = 0
	Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)

	copyBtn.MouseButton1Click:Connect(function()
		PlayUI_Click()
		local success = false
		if setclipboard then
			local ok = pcall(function()
				setclipboard("https://discord.gg/rZuYzZ7zvt")
			end)
			success = ok
		end
		if success then
			CriarNotificacaoLinkCopiado("LINK COPIED SUCCESSFULLY!", "rbxthumb://type=Asset&id=118293546444074&w=150&h=150")
		end
	end)

	local notifCloseBtn            = Instance.new("TextButton", notifCard)
	notifCloseBtn.Size             = UDim2.new(0, 24, 0, 24)
	notifCloseBtn.Position         = UDim2.new(1, -32, 0, 10)
	notifCloseBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
	notifCloseBtn.BackgroundTransparency = 0.2
	notifCloseBtn.Text             = ""
	notifCloseBtn.ZIndex           = 205
	notifCloseBtn.BorderSizePixel  = 0
	Instance.new("UICorner", notifCloseBtn).CornerRadius = UDim.new(0, 6)
	local xStroke                  = Instance.new("UIStroke", notifCloseBtn)
	xStroke.Color                  = Color3.fromRGB(80, 80, 85)
	xStroke.Thickness              = 1
	xStroke.Transparency           = 0.5
	local xL1                      = Instance.new("Frame", notifCloseBtn)
	xL1.AnchorPoint                = Vector2.new(0.5, 0.5)
	xL1.Position                   = UDim2.new(0.5, 0, 0.5, 0)
	xL1.Size                       = UDim2.new(0, 10, 0, 1.5)
	xL1.Rotation                   = 45
	xL1.BackgroundColor3           = Color3.fromRGB(160, 160, 165)
	xL1.BorderSizePixel            = 0
	xL1.ZIndex                     = 206
	Instance.new("UICorner", xL1).CornerRadius = UDim.new(1, 0)
	local xL2                      = Instance.new("Frame", notifCloseBtn)
	xL2.AnchorPoint                = Vector2.new(0.5, 0.5)
	xL2.Position                   = UDim2.new(0.5, 0, 0.5, 0)
	xL2.Size                       = UDim2.new(0, 10, 0, 1.5)
	xL2.Rotation                   = -45
	xL2.BackgroundColor3           = Color3.fromRGB(160, 160, 165)
	xL2.BorderSizePixel            = 0
	xL2.ZIndex                     = 206
	Instance.new("UICorner", xL2).CornerRadius = UDim.new(1, 0)

	notifCloseBtn.MouseEnter:Connect(function()
		TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160, 20, 20)}):Play()
		TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end)
	notifCloseBtn.MouseLeave:Connect(function()
		TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(35, 35, 38)}):Play()
		TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160, 160, 165)}):Play()
		TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160, 160, 165)}):Play()
	end)

	local progressBg               = Instance.new("Frame", notifCard)
	progressBg.Size                = UDim2.new(1, -28, 0, 3)
	progressBg.Position            = UDim2.new(0, 14, 1, -10)
	progressBg.BackgroundColor3    = Color3.fromRGB(30, 30, 35)
	progressBg.BorderSizePixel     = 0
	progressBg.ZIndex              = 202
	progressBg.ClipsDescendants    = true
	Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)
	local progressBar              = Instance.new("Frame", progressBg)
	progressBar.Size               = UDim2.new(1, 0, 1, 0)
	progressBar.Position           = UDim2.new(0, 0, 0, 0)
	progressBar.BackgroundColor3   = Color3.fromRGB(255, 255, 255)
	progressBar.BorderSizePixel    = 0
	progressBar.ZIndex             = 203
	Instance.new("UICorner", progressBar).CornerRadius = UDim.new(1, 0)
	local progressGrad             = Instance.new("UIGradient", progressBar)
	progressGrad.Color             = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(88, 101, 242)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 30, 100))
	})

	table.insert(ActiveNotifications, 1, notifHolder)
	UpdateNotifications()

	TweenService:Create(notifHolder, TweenInfo.new(0.30, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -20, 1, -24)
	}):Play()
	TweenService:Create(notifScale, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Scale = 1
	}):Play()

	local dismissed = false
	local function DismissNotif()
		if dismissed then return end
		dismissed = true
		for i, v in ipairs(ActiveNotifications) do
			if v == notifHolder then table.remove(ActiveNotifications, i) break end
		end
		UpdateNotifications()
		local slideOut = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		TweenService:Create(notifHolder, slideOut, {
			Position = UDim2.new(1, 360, notifHolder.Position.Y.Scale, notifHolder.Position.Y.Offset)
		}):Play()
		TweenService:Create(notifCard, slideOut, {BackgroundTransparency = 1}):Play()
		TweenService:Create(notifScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.96
		}):Play()
		task.delay(0.28, function()
			if notifHolder and notifHolder.Parent then notifHolder:Destroy() end
		end)
	end

	notifCloseBtn.MouseButton1Click:Connect(function() DismissNotif() end)
	local barTween = TweenService:Create(progressBar, TweenInfo.new(NOTIF_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 1, 0)})
	task.delay(0.1, function() barTween:Play() end)
	task.delay(NOTIF_DURATION + 0.1, function() DismissNotif() end)
end

-- ==================== FILTRO / PESQUISA ====================
local filterDebounceThread = nil

local function filterToggles(currentActiveTab, query)
	local searchQuery = (query or ""):lower()
	local itemIndex   = 0
	for _, child in ipairs(togglesContainer:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
			local itemTab       = child:GetAttribute("Tab") or "Combat"
			local shouldBeVisible = false
			if searchQuery ~= "" then
				local titleLabel = child:FindFirstChild("Title")
				local descLabel  = child:FindFirstChild("Description")
				local matchTitle = titleLabel and titleLabel.Text:lower():find(searchQuery) ~= nil
				local matchDesc  = descLabel  and descLabel.Text:lower():find(searchQuery)  ~= nil
				shouldBeVisible  = matchTitle or matchDesc
			else
				shouldBeVisible = (itemTab == currentActiveTab)
			end

			child.Visible = shouldBeVisible
			if shouldBeVisible then
				itemIndex = itemIndex + 1
				child.Size = UDim2.new(1, -10, 0, 0)
				child.BackgroundTransparency = 1
				local t = child:FindFirstChild("Title")
				local d = child:FindFirstChild("Description")
				if t then t.TextTransparency = 1 end
				if d then d.TextTransparency = 1 end
				local delay = (itemIndex - 1) * 0.02
				task.delay(delay, function()
					if not child or not child.Parent then return end
					TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
						Size = UDim2.new(1, -10, 0, child:GetAttribute("ItemHeight") or 60), BackgroundTransparency = 0.45
					}):Play()
					if t then TweenService:Create(t, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
					if d then TweenService:Create(d, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
				end)
			end
		end
	end
	task.delay(0.05, function() pcall(UpdateCanvasSize) end)
end

-- ==================== ACTIVEBAR POSITION UPDATE ====================
local function UpdateActiveBarPosition(animar)
	local targetBtn = tabButtons[activeTab]
	if not targetBtn or not sharedActiveBar.Visible then return end

	local MAX_DEFER   = 8
	local deferCount  = 0

	local function aplicar()
		if not targetBtn or not targetBtn.Parent then return end
		deferCount = deferCount + 1

		local btnAbsSize = targetBtn.AbsoluteSize.Y
		local btnAbsPos  = targetBtn.AbsolutePosition.Y
		local panelAbsY  = ActiveBarContainer.AbsolutePosition.Y

		if (btnAbsSize == 0 or btnAbsPos == 0 or panelAbsY == 0) and deferCount < MAX_DEFER then
			task.defer(aplicar)
			return
		end

		local targetCenterY = btnAbsPos + (btnAbsSize / 2)
		local targetYPos    = targetCenterY - panelAbsY

		if animar then
			local moveTween = TweenService:Create(
				sharedActiveBar,
				TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{Position = UDim2.new(0, 7, 0, targetYPos)}
			)
			moveTween:Play()

			activeBarScale.Scale = 1.08
			TweenService:Create(
				activeBarScale,
				TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Scale = 1}
			):Play()
		else
			sharedActiveBar.Position = UDim2.new(0, 7, 0, targetYPos)
			activeBarScale.Scale = 1
		end
	end

	task.defer(aplicar)
end

TabsContainer:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	UpdateActiveBarPosition(false)
end)

-- ==================== SELECIONAR ABA ====================
local function selectTab(tabName)
	activeTab = tabName
	local targetBtn = tabButtons[tabName]

	for name, btn in pairs(tabButtons) do
		local label          = btn:FindFirstChild("Label")
		local iconContainer  = btn:FindFirstChild("Icon")
		local animSpeed      = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

		if name == tabName then
			TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(45, 10, 15), BackgroundTransparency = 0.5}):Play()
			if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end
			if iconContainer and iconContainer:FindFirstChild("AccentImage") then
				TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
			end
			originalTrans[btn] = { BackgroundTransparency = 0.5, TextTransparency = 0 }
		else
			TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 1}):Play()
			if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(150, 150, 150)}):Play() end
			if iconContainer and iconContainer:FindFirstChild("AccentImage") then
				TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Color3.fromRGB(150, 150, 150)}):Play()
			end
			originalTrans[btn] = { BackgroundTransparency = 1, TextTransparency = 0 }
		end
	end

	if targetBtn then
		sharedActiveBar.Visible = true
		UpdateActiveBarPosition(true)
	end

	togglesContainer.CanvasPosition = Vector2.new(0, 0)
	searchTextBox.Text = ""
	filterToggles(tabName, "")
end

-- ==================== CRIAR BOTÃO DE ABA ====================
local function createTabBtn(tabName)
	local tabBtn               = Instance.new("TextButton", TabsContainer)
	tabBtn.Name                = tabName .. "TabBtn"
	tabBtn.Size                = UDim2.new(1, -16, 0, 36)
	tabBtn.BackgroundColor3    = Color3.fromRGB(15, 15, 15)
	tabBtn.BackgroundTransparency = 1
	tabBtn.Text                = ""
	tabBtn.ZIndex              = 11
	Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 8)

	local iconContainer        = Instance.new("Frame", tabBtn)
	iconContainer.Name         = "Icon"
	iconContainer.Size         = UDim2.new(0, 14, 0, 14)
	iconContainer.Position     = UDim2.new(0, 14, 0.5, -7)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex       = 12
	local imageLabel           = Instance.new("ImageLabel", iconContainer)
	imageLabel.Name            = "AccentImage"
	imageLabel.Size            = UDim2.new(1, 0, 1, 0)
	imageLabel.BackgroundTransparency = 1
	imageLabel.ZIndex          = 13
	imageLabel.ImageColor3     = Color3.fromRGB(150, 150, 150)

	if tabName == "Farming"   then imageLabel.Image = "rbxthumb://type=Asset&id=71234705040146&w=150&h=150"
	elseif tabName == "Teleports" then imageLabel.Image = "rbxthumb://type=Asset&id=131082536388353&w=150&h=150"
	elseif tabName == "Settings"  then imageLabel.Image = "rbxthumb://type=Asset&id=88409765080516&w=150&h=150"
	elseif tabName == "Visuals"   then imageLabel.Image = "rbxthumb://type=Asset&id=97681798175944&w=150&h=150"
	elseif tabName == "Combat"    then imageLabel.Image = "rbxthumb://type=Asset&id=105897102093789&w=150&h=150" end

	local tabLabel             = Instance.new("TextLabel", tabBtn)
	tabLabel.Name              = "Label"
	tabLabel.Size              = UDim2.new(1, -42, 1, 0)
	tabLabel.Position          = UDim2.new(0, 38, 0, 0)
	tabLabel.BackgroundTransparency = 1
	tabLabel.TextColor3        = Color3.fromRGB(150, 150, 150)
	tabLabel.Font              = Enum.Font.GothamMedium
	tabLabel.TextSize          = 13
	tabLabel.TextXAlignment    = Enum.TextXAlignment.Left
	tabLabel.Text              = UI_TEXT.Tabs[tabName] or tabName
	tabLabel.ZIndex            = 12

	local tabScale = Instance.new("UIScale", tabBtn)
	tabScale.Scale = 1

	tabBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(tabScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.97}):Play()
		end
	end)

	tabBtn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(tabScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		end
	end)

	tabBtn.MouseButton1Click:Connect(function() selectTab(tabName) end)
	tabButtons[tabName] = tabBtn
end

-- ==================== CRIAR AÇÃO DE CLIQUE ====================
-- Ações de teleporte não ficam ligadas: cada toque executa uma vez.
local function createAction(parent, configKey, tabCategory)
    local frame = Instance.new("Frame")
    frame.Name = configKey .. "Action"
    frame.Size = UDim2.new(1, -10, 0, 42)
    frame:SetAttribute("ItemHeight", 42)
    frame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
    frame.BackgroundTransparency = 0.45
    frame.BorderSizePixel = 0
    frame.ZIndex = 11
    frame.ClipsDescendants = true
    frame.LayoutOrder = ({TpNearestMob=1, TpBoss=2, TpChest=3, TpSafe=4})[configKey] or 10
    frame:SetAttribute("Tab", tabCategory)
    frame:SetAttribute("ConfigKey", configKey)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel", frame)
    title.Name = "Title"
    title.Size = UDim2.new(1, -24, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(220, 220, 220)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.Text = (UI_TEXT.Options[configKey] and UI_TEXT.Options[configKey].Title) or configKey
    title.ZIndex = 12

    -- Sem imagem de indicador (removida por request)

    -- Overlay de clique controlado manualmente para evitar sombra residual
    local clickOverlay = Instance.new("Frame", frame)
    clickOverlay.Name = "ClickOverlay"
    clickOverlay.Size = UDim2.fromScale(1, 1)
    clickOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    clickOverlay.BackgroundTransparency = 1
    clickOverlay.BorderSizePixel = 0
    clickOverlay.ZIndex = 12
    Instance.new("UICorner", clickOverlay).CornerRadius = UDim.new(0, 8)

    local hit = Instance.new("TextButton", frame)
    hit.Name = "Action"
    hit.Size = UDim2.fromScale(1, 1)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.AutoButtonColor = false
    hit.ZIndex = 13

    local clickActive = false

    local function startPulse()
        if clickActive then return end
        clickActive = true
        TweenService:Create(clickOverlay,
            TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.60}
        ):Play()
    end

    local function endPulse()
        if not clickActive then return end
        clickActive = false
        TweenService:Create(clickOverlay,
            TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}
        ):Play()
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            startPulse()
        end
    end)

    hit.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            endPulse()
        end
    end)

    -- Garante que a sombra suma caso o ponteiro saia sem soltar
    hit.MouseLeave:Connect(function()
        endPulse()
    end)

    hit.MouseButton1Click:Connect(function()
        PlayUI_Click()
        endPulse()
        local cb = _G.AkatCallbacks and _G.AkatCallbacks[configKey]
        if type(cb) == "function" then
            task.spawn(function() pcall(cb, true) end)
        end
    end)

    return frame
end

-- ==================== CRIAR TOGGLE ====================
local function createToggle(parent, configKey, tabCategory)
	local toggleFrame              = Instance.new("Frame")
	toggleFrame.Name               = configKey
	toggleFrame.Size               = UDim2.new(1, -10, 0, 60)
	toggleFrame.BackgroundColor3   = Color3.fromRGB(15, 5, 5)
	toggleFrame.BackgroundTransparency = 0.45
	toggleFrame.ZIndex             = 11
	toggleFrame.ClipsDescendants   = true
	
	toggleFrame:SetAttribute("Tab",       tabCategory)
	toggleFrame:SetAttribute("ConfigKey", configKey)
	toggleFrame.Parent             = parent

	local toggleScale              = Instance.new("UIScale", toggleFrame)
	toggleScale.Scale              = 1
	Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 8)

	local optData                  = UI_TEXT.Options[configKey]
	local titleLabel               = Instance.new("TextLabel", toggleFrame)
	titleLabel.Name                = "Title"
	titleLabel.Size                = UDim2.new(0.7, 0, 0, 18)
	titleLabel.Position            = UDim2.new(0, 12, 0, 9)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3          = Color3.fromRGB(210, 210, 210)
	titleLabel.Font                = Enum.Font.GothamBold
	titleLabel.TextSize            = 13
	titleLabel.TextXAlignment      = Enum.TextXAlignment.Left
	titleLabel.Text                = optData and optData.Title or configKey
	titleLabel.ZIndex              = 11

	local descLabel                = Instance.new("TextLabel", toggleFrame)
	descLabel.Name                 = "Description"
	descLabel.Size                 = UDim2.new(0.7, 0, 0, 28)
	descLabel.Position             = UDim2.new(0, 12, 0, 28)
	descLabel.BackgroundTransparency = 1
	descLabel.TextColor3           = Color3.fromRGB(130, 130, 130)
	descLabel.Font                 = Enum.Font.Gotham
	descLabel.TextSize             = 10.5
	descLabel.TextXAlignment       = Enum.TextXAlignment.Left
	descLabel.TextYAlignment       = Enum.TextYAlignment.Top
	descLabel.TextWrapped          = true
	descLabel.Text                 = optData and optData.Desc or ""
	descLabel.ZIndex               = 11

	local switchTrack              = Instance.new("Frame", toggleFrame)
	switchTrack.Size               = UDim2.new(0, 48, 0, 24)
	switchTrack.Position           = UDim2.new(1, -54, 0.5, -12)
	switchTrack.BackgroundColor3   = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
	switchTrack.ZIndex             = 11
	Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)

	local switchCircle             = Instance.new("Frame", switchTrack)
	switchCircle.Size              = UDim2.new(0, 18, 0, 18)
	switchCircle.Position          = Configs[configKey] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
	switchCircle.BackgroundColor3  = Color3.fromRGB(255, 255, 255)
	switchCircle.ZIndex            = 12
	Instance.new("UICorner", switchCircle).CornerRadius = UDim.new(1, 0)

	local triggerBtn               = Instance.new("TextButton", toggleFrame)
	triggerBtn.Size                = UDim2.new(1, 0, 1, 0)
	triggerBtn.BackgroundTransparency = 1
	triggerBtn.Text                = ""
	triggerBtn.ZIndex              = 13

	triggerBtn.MouseButton1Click:Connect(function()
		PlayUI_Click()
		Configs[configKey] = not Configs[configKey]
		local targetPos   = Configs[configKey] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
		local targetColor = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
		local anim        = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(switchCircle, anim, {Position = targetPos}):Play()
		TweenService:Create(switchTrack,  anim, {BackgroundColor3 = targetColor}):Play()
		toggleScale.Scale = 0.97
		TweenService:Create(toggleScale, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1}):Play()

		if _G.AkatCallbacks and type(_G.AkatCallbacks[configKey]) == "function" then
			local success, err = pcall(function()
				_G.AkatCallbacks[configKey](Configs[configKey])
			end)
			if not success then
				warn("[AKAT UI] Callback failed for " .. tostring(configKey) .. ": " .. tostring(err))
			end
		else
			warn("[AKAT UI] Callback not found: " .. tostring(configKey))
		end
		SyncFloatingButton(configKey)
	end)
end

-- ==================== TOGGLE COMPACTO ====================
local function createCompactToggle(parent, configKey, tabCategory)
    local frame = Instance.new("Frame")
    frame.Name = configKey
    frame.Size = UDim2.new(1, -10, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
    frame.BackgroundTransparency = 0.45
    frame.ZIndex = 11
    frame.ClipsDescendants = true
    frame:SetAttribute("Tab", tabCategory)
    frame:SetAttribute("ConfigKey", configKey)
    frame:SetAttribute("ItemHeight", 42)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -78, 1, 0)
    title.Position = UDim2.fromOffset(12, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(210,210,210)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.Text = (UI_TEXT.Options[configKey] and UI_TEXT.Options[configKey].Title) or configKey
    title.ZIndex = 12

    local track = Instance.new("Frame", frame)
    track.Size = UDim2.fromOffset(42, 22)
    track.Position = UDim2.new(1, -52, 0.5, -11)
    track.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30,30,30)
    track.ZIndex = 12
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)

    local circle = Instance.new("Frame", track)
    circle.Size = UDim2.fromOffset(16,16)
    circle.Position = Configs[configKey] and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
    circle.BackgroundColor3 = Color3.fromRGB(255,255,255)
    circle.ZIndex = 13
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)

    local hit = Instance.new("TextButton", frame)
    hit.Size = UDim2.fromScale(1,1)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.ZIndex = 14
    hit.MouseButton1Click:Connect(function()
        PlayUI_Click()
        Configs[configKey] = not Configs[configKey]
        local on = Configs[configKey]
        TweenService:Create(circle, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = on and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)}):Play()
        TweenService:Create(track, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = on and Color3.fromHex("#8B0000") or Color3.fromRGB(30,30,30)}):Play()
        if _G.AkatCallbacks and type(_G.AkatCallbacks[configKey]) == "function" then
            pcall(function() _G.AkatCallbacks[configKey](on) end)
        end
    end)
end

-- ==================== CRIAR SLIDER NUMÉRICO COMPACTO ====================
local function createCompactSlider(parent, configKey, tabCategory, minValue, maxValue, defaultValue)
	local frame = Instance.new("Frame")
	frame.Name  = configKey
	frame.Size  = UDim2.new(1, -10, 0, 42)
	frame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
	frame.BackgroundTransparency = 0.45
	frame.ZIndex = 11
	frame.ClipsDescendants = true
	frame:SetAttribute("Tab",       tabCategory)
	frame:SetAttribute("ConfigKey", configKey)
	frame:SetAttribute("ItemHeight", 42)
	frame.Parent = parent
	local scale = Instance.new("UIScale", frame)
	scale.Scale = 1
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local optData = UI_TEXT.Options[configKey]
	local titleLbl = Instance.new("TextLabel", frame)
	titleLbl.Name  = "Title"
	titleLbl.Size  = UDim2.new(0, 100, 1, 0)
	titleLbl.Position = UDim2.new(0, 12, 0, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3 = Color3.fromRGB(210, 210, 210)
	titleLbl.Font  = Enum.Font.GothamBold
	titleLbl.TextSize = 13
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.TextYAlignment = Enum.TextYAlignment.Center
	titleLbl.Text  = optData and optData.Title or configKey
	titleLbl.ZIndex = 12

	local track = Instance.new("Frame", frame)
	track.Name  = "SliderTrack"
	track.Size  = UDim2.new(1, -168, 0, 6)
	track.Position = UDim2.new(0, 116, 0.5, -3)
	track.BackgroundColor3 = Color3.fromRGB(45, 25, 27)
	track.BorderSizePixel  = 0
	track.ZIndex = 12
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame", track)
	fill.Name  = "Fill"
	fill.Size  = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
	fill.BorderSizePixel  = 0
	fill.ZIndex = 13
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame", track)
	knob.Name  = "Knob"
	knob.Size  = UDim2.fromOffset(14, 14)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position    = UDim2.new(0, 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel  = 0
	knob.ZIndex = 14
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local valueLabel = Instance.new("TextLabel", frame)
	valueLabel.Name  = "Value"
	valueLabel.Size  = UDim2.fromOffset(46, 22)
	valueLabel.AnchorPoint = Vector2.new(1, 0.5)
	valueLabel.Position    = UDim2.new(1, -10, 0.5, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	valueLabel.Font  = Enum.Font.GothamBold
	valueLabel.TextSize = 15
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.ZIndex = 13

	local hit = Instance.new("TextButton", frame)
	hit.Name  = "SliderHitbox"
	hit.Size  = UDim2.new(1, -148, 0, 30)
	hit.Position = UDim2.new(0, 110, 0.5, -15)
	hit.BackgroundTransparency = 1
	hit.Text  = ""
	hit.AutoButtonColor = false
	hit.ZIndex = 15

	local value   = tonumber(defaultValue) or tonumber(Configs[configKey .. "Value"]) or minValue
	value = math.clamp(value, minValue, maxValue)
	local dragging = false

	local function setValue(v, notify)
		value = math.clamp(v, minValue, maxValue)
		local alpha = (value - minValue) / (maxValue - minValue)
		valueLabel.Text = (configKey == "Speed" or configKey == "JumpPower")
			and string.format("%.1f", value)
			or  string.format("%.0f", value)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		Configs[configKey .. "Value"] = value
		Configs[configKey] = true
		if notify and _G.AkatCallbacks and type(_G.AkatCallbacks[configKey]) == "function" then
			local ok, err = pcall(function() _G.AkatCallbacks[configKey](value) end)
			if not ok then warn("[AKAT UI] Slider callback failed for " .. tostring(configKey) .. ": " .. tostring(err)) end
		end
	end

	local function updateFromInput(input)
		local x     = input.Position.X
		local left  = track.AbsolutePosition.X
		local width = math.max(1, track.AbsoluteSize.X)
		local alpha = math.clamp((x - left) / width, 0, 1)
		local v     = minValue + (maxValue - minValue) * alpha
		setValue(math.floor(v * 10 + 0.5) / 10, true)
	end

	setValue(value, false)

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromInput(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
	if filterDebounceThread then
		task.cancel(filterDebounceThread)
	end
	filterDebounceThread = task.delay(0.08, function()
		filterDebounceThread = nil
		filterToggles(activeTab, searchTextBox.Text)
	end)
end)

-- ==================== EXPAND RESPONSIVO ====================
local function ApplyResponsiveWindowSize(animate)
	local normalSize, expandedSize = GetResponsiveUISizes()
	local targetSize = isExpanded and expandedSize or normalSize

	if animate then
		TweenService:Create(
			mainWrapper,
			TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{Size = targetSize}
		):Play()
	else
		mainWrapper.Size = targetSize
	end

	task.defer(function()
		ClampMainWrapperToViewport()
	end)
end

local viewportConnection
local function BindViewportResize()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end

	local camera = workspace.CurrentCamera
	if not camera then return end

	viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if not mainWrapper or not mainWrapper.Parent then return end

		ApplyResponsiveWindowSize(UIState == "OPEN")
		ClampMainWrapperToViewport()
		UpdateActiveBarPosition(false)
		task.defer(UpdateCanvasSize)
		task.defer(UpdateTabsCanvas)
	end)
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(BindViewportResize)
BindViewportResize()

-- ==================== EXPAND ====================
ExpandBtn.MouseButton1Click:Connect(function()
	PlayUI_Click()
	if UIState ~= "OPEN" then return end

	isExpanded = not isExpanded
	ApplyResponsiveWindowSize(true)
end)

-- ==================== MÁQUINA DE ESTADOS DA UI ====================
local isTransitioning = false

SetUIState = function(newState)
	if UIState == newState then return end
	if isTransitioning then return end
	isTransitioning = true

	local tempoAnim  = 0.25
	local windowAnim = TweenInfo.new(tempoAnim, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	if newState == "OPEN" then
		mainWrapper.Visible = true
		do
			local normalSize = select(1, GetResponsiveUISizes())
			mainWrapper.Size = normalSize
		end
		AplicarFadeSincronizado(mainWrapper, true, 0)
		AplicarFadeSincronizado(mainWrapper, false, tempoAnim)

		local normalSize, expandedSize = GetResponsiveUISizes()
		local targetSize = isExpanded and expandedSize or normalSize
		local openTween  = TweenService:Create(mainWrapper, windowAnim, {Size = targetSize})
		openTween:Play()
		openTween.Completed:Connect(function()
			UIState         = "OPEN"
			isTransitioning = false
			selectTab(activeTab)
			filterToggles(activeTab, searchTextBox.Text)
			UpdateActiveBarPosition(false)
		end)

	elseif newState == "MINIMIZED" or newState == "CLOSED" then
		AplicarFadeSincronizado(mainWrapper, true, tempoAnim)
		local normalSize = select(1, GetResponsiveUISizes())
		local vp = GetViewportSize()
		local shrinkSize = UDim2.fromOffset(
			math.min(NORMAL_UI_SIZE.X, math.max(1, vp.X - (UI_SAFE_MARGIN * 2))),
			math.min(NORMAL_UI_SIZE.Y, math.max(1, vp.Y - (UI_SAFE_MARGIN * 2)))
		)
		local closeTween = TweenService:Create(mainWrapper, windowAnim, {Size = shrinkSize})
		closeTween:Play()
		closeTween.Completed:Connect(function()
			mainWrapper.Visible = false
			UIState             = newState
			isTransitioning     = false
		end)
	else
		isTransitioning = false
	end
end

-- ==================== FLASH DE CLIQUE NOS BOTÕES DO TOPO ====================
local function AplicarClickFlash(btn, icon)
	btn.MouseButton1Click:Connect(function()
		local flashInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0)
		TweenService:Create(icon, flashInfo, {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end)
end

MinimizeBtn.MouseButton1Click:Connect(function()
	PlayUI_Click()
	SetUIState("MINIMIZED")
end)

-- ==================== CONFIRMAÇÃO DE FECHAMENTO ====================
local function AlternarConfirmacao(exibir)
	isConfirmOpen = exibir
	local tempoAnim = 0.25

	if exibir then
		mainWrapper.Visible  = false
		FloatBtn.Visible     = false
		confirmOverlay.Visible = true

		TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 28}):Play()

		local oldScale = confirmCard:FindFirstChildOfClass("UIScale")
		if oldScale then oldScale:Destroy() end

		confirmCard.Size = UDim2.new(0, 280, 0, 115)
		local cardScale  = Instance.new("UIScale", confirmCard)
		cardScale.Scale  = 0.88
		TweenService:Create(cardScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		AplicarFadeSincronizado(confirmCard, false, tempoAnim)

	else
		TweenService:Create(confirmBlur, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = 0}):Play()
		AplicarFadeSincronizado(confirmCard, true, tempoAnim)
		local sc = confirmCard:FindFirstChildOfClass("UIScale")
		if sc then
			TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.88}):Play()
		end
		task.delay(tempoAnim + 0.05, function()
			if not isConfirmOpen then
				confirmOverlay.Visible = false
				local sc2 = confirmCard:FindFirstChildOfClass("UIScale")
				if sc2 then sc2:Destroy() end
				if UIState == "OPEN" then
					mainWrapper.Visible = true
				end
				FloatBtn.Visible = true
			end
		end)
	end
end

CloseBtn.MouseButton1Click:Connect(function()
	PlayUI_Click()
	AlternarConfirmacao(true)
end)

btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)

btnYes.MouseButton1Click:Connect(function()
	local syncTime = 0.2
	TweenService:Create(confirmBlur, TweenInfo.new(syncTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = 0}):Play()
	AplicarFadeSincronizado(confirmCard, true, syncTime)
	task.wait(syncTime)
	pcall(function() confirmBlur:Destroy() end)
	if _G.AkatUIShutdown then
		pcall(_G.AkatUIShutdown)
	end
end)

-- ==================== HOVER NOS BOTÕES DO TOPO ====================
local function AplicarEfeitoFisicoBotao(btn, icon, hoverColor)
	local btnScale = Instance.new("UIScale", btn)
	btnScale.Scale = 1

	btn.MouseEnter:Connect(function()
		if UIState ~= "OPEN" then return end
		TweenService:Create(icon, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = hoverColor}):Play()
	end)

	btn.MouseLeave:Connect(function()
		if UIState ~= "OPEN" then return end
		TweenService:Create(icon, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = TOP_BTN_COLOR}):Play()
		TweenService:Create(btnScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end)

	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(btnScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.92}):Play()
		end
	end)

	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(btnScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		end
	end)
end

AplicarEfeitoFisicoBotao(MinimizeBtn, MinimizeIcon, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(ExpandBtn,   ExpandIcon,   Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(CloseBtn,    CloseIcon,    Color3.fromRGB(255, 60,  60))

AplicarClickFlash(MinimizeBtn, MinimizeIcon)
AplicarClickFlash(ExpandBtn,   ExpandIcon)
AplicarClickFlash(CloseBtn,    CloseIcon)

-- ==================== CRIAR ABAS ====================
createTabBtn("Farming")
createTabBtn("Combat")
createTabBtn("Visuals")
createTabBtn("Teleports")
createTabBtn("Settings")

-- ==================== COMPONENTES DE SELEÇÃO ====================
local function createDropdown(parent, key, tabCategory, options, defaultValue)
	local frame = Instance.new("Frame")
	frame.Name = key
	frame.Size = UDim2.new(1, -10, 0, 60)
	frame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
	frame.BackgroundTransparency = 0.45
	frame.BorderSizePixel = 0
	frame.ZIndex = 11
	frame.ClipsDescendants = false
	frame:SetAttribute("Tab", tabCategory)
	frame:SetAttribute("ConfigKey", key)
	frame:SetAttribute("ItemHeight", 60)
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local title = Instance.new("TextLabel", frame)
	title.Name = "Title"
	title.Size = UDim2.new(0.42, 0, 0, 18)
	title.Position = UDim2.new(0, 12, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = (UI_TEXT.Options[key] and UI_TEXT.Options[key].Title) or key
	title.TextColor3 = Color3.fromRGB(220,220,220)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 12.5
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 12

	local selected = defaultValue or options[1]
	local button = Instance.new("TextButton", frame)
	button.Name = "Selector"
	button.Size = UDim2.new(0.50, 0, 0, 30)
	button.Position = UDim2.new(0.46, 0, 0.5, -15)
	button.BackgroundColor3 = Color3.fromRGB(30, 8, 10)
	button.BackgroundTransparency = 0.1
	button.Text = tostring(selected)
	button.TextColor3 = Color3.fromRGB(240,240,240)
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 11.5
	button.AutoButtonColor = false
	button.ZIndex = 13
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)

	local arrow = Instance.new("TextLabel", button)
	arrow.Size = UDim2.new(0, 18, 1, 0)
	arrow.Position = UDim2.new(1, -22, 0, 0)
	arrow.BackgroundTransparency = 1
	arrow.Text = "⌄"
	arrow.TextColor3 = Color3.fromRGB(180,180,180)
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 14
	arrow.ZIndex = 14

	local panel = Instance.new("Frame", frame)
	panel.Name = "SelectionPanel"
	panel.Size = UDim2.new(0.50, 0, 0, math.min(150, #options * 30 + 6))
	panel.Position = UDim2.new(0.46, 0, 1, 4)
	panel.BackgroundColor3 = Color3.fromRGB(18, 7, 8)
	panel.BackgroundTransparency = 0.02
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 100
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
	local pStroke = Instance.new("UIStroke", panel)
	pStroke.Thickness = 1
	pStroke.Transparency = 0.35
	pStroke.Color = Color3.fromRGB(130, 20, 25)

	local scroll = Instance.new("ScrollingFrame", panel)
	scroll.Size = UDim2.new(1, -6, 1, -6)
	scroll.Position = UDim2.new(0, 3, 0, 3)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 2
	scroll.CanvasSize = UDim2.new()
	scroll.ZIndex = 101
	local layout = Instance.new("UIListLayout", scroll)
	layout.Padding = UDim.new(0, 2)

	local function close()
		panel.Visible = false
		TweenService:Create(panel, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 0.02}):Play()
	end

	for _, value in ipairs(options) do
		local opt = Instance.new("TextButton", scroll)
		opt.Size = UDim2.new(1, -2, 0, 26)
		opt.BackgroundColor3 = Color3.fromRGB(28, 9, 11)
		opt.BackgroundTransparency = 0.15
		opt.BorderSizePixel = 0
		opt.Text = tostring(value)
		opt.TextColor3 = Color3.fromRGB(205,205,205)
		opt.Font = Enum.Font.Gotham
		opt.TextSize = 11
		opt.AutoButtonColor = false
		opt.ZIndex = 102
		Instance.new("UICorner", opt).CornerRadius = UDim.new(0, 6)
		opt.MouseButton1Click:Connect(function()
			selected = value
			button.Text = tostring(value)
			close()
			PlayUI_Click()
			if _G.AkatCallbacks and type(_G.AkatCallbacks[key]) == "function" then
				task.spawn(function() pcall(_G.AkatCallbacks[key], value) end)
			end
		end)
	end

	button.MouseButton1Click:Connect(function()
		PlayUI_Click()
		panel.Visible = not panel.Visible
		if panel.Visible then
			panel.BackgroundTransparency = 1
			TweenService:Create(panel, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.02}):Play()
		end
	end)

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 4)
	end)
end

-- ==================== TOGGLES / SLIDERS ====================
createToggle(togglesContainer, "AutoFarmLevel",    "Farming")
createToggle(togglesContainer, "AutoFarmBoss",     "Farming")
createToggle(togglesContainer, "AutoFarmMastery",  "Farming")
createToggle(togglesContainer, "AutoBones",        "Farming")
createToggle(togglesContainer, "AutoMaterials",    "Farming")
createToggle(togglesContainer, "AutoChests",       "Farming")
createDropdown(togglesContainer, "FarmWorld",      "Farming", {"First Sea","Second Sea","Third Sea"}, "First Sea")
createDropdown(togglesContainer, "BossTarget",     "Farming", {"Auto","Gorilla King","Saber Expert","Mob Leader","Vice Admiral","Warden","Chief Warden","Swan","Magma Admiral","Fishman Lord"}, "Auto")
createDropdown(togglesContainer, "MaterialTarget", "Farming", {"Bones","Leather","Scrap Metal","Magma Ore","Angel Wings","Fish Tail","Dragon Scale"}, "Bones")

createToggle(togglesContainer, "MobAura",          "Combat")
createToggle(togglesContainer, "AutoSkills",       "Combat")
createToggle(togglesContainer, "AutoFruitMastery", "Combat")
createToggle(togglesContainer, "AutoGunMastery",   "Combat")
createToggle(togglesContainer, "AutoSwordMastery", "Combat")
createToggle(togglesContainer, "AutoFarmMastery",  "Combat")
createDropdown(togglesContainer, "MasteryWeapon",  "Combat", {"Auto","Fruit","Gun","Sword"}, "Auto")
createCompactSlider(togglesContainer, "MobRadius", "Combat", 10, 80, 35)

createToggle(togglesContainer, "ESP",     "Visuals")
createToggle(togglesContainer, "Name",    "Visuals")
createToggle(togglesContainer, "Tracer",  "Visuals")
createToggle(togglesContainer, "XRay",    "Visuals")

createAction(togglesContainer, "TpNearestMob", "Teleports")
createAction(togglesContainer, "TpBoss",       "Teleports")
createAction(togglesContainer, "TpChest",      "Teleports")
createAction(togglesContainer, "TpSafe",       "Teleports")

createCompactSlider(togglesContainer, "Speed",     "Settings", 16, 100, 16)
createCompactSlider(togglesContainer, "JumpPower", "Settings", 50, 150, 50)
createToggle(togglesContainer, "AntiFling", "Settings")
createToggle(togglesContainer, "SafeFarm",  "Settings")
createToggle(togglesContainer, "Invisibility", "Settings")

-- ==================== ANIMAÇÃO DE INTRODUÇÃO ====================
local function ExecutarIntroAkat()
	local Blur             = Instance.new("BlurEffect")
	Blur.Name              = "IntroBlur"
	Blur.Size              = 0
	Blur.Parent            = Lighting

	local IntroFrame       = Instance.new("Frame", screenGui)
	IntroFrame.Size        = UDim2.new(1, 0, 1, 0)
	IntroFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	IntroFrame.BackgroundTransparency = 1
	IntroFrame.ZIndex      = 500

	local MaskContainer    = Instance.new("Frame", IntroFrame)
	MaskContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	MaskContainer.Position = UDim2.new(0.5, 0, 0.5, -10)
	MaskContainer.Size     = UDim2.new(0, 420, 0, 40)
	MaskContainer.BackgroundTransparency = 1
	MaskContainer.ClipsDescendants = true
	MaskContainer.ZIndex   = 501

	local IntroText        = Instance.new("TextLabel", MaskContainer)
	IntroText.Size         = UDim2.new(1, 0, 1, 0)
	IntroText.Position     = UDim2.new(0, 0, 1, 0)
	IntroText.BackgroundTransparency = 1
	IntroText.Font         = Enum.Font.GothamBold
	IntroText.TextSize     = 26
	IntroText.RichText     = true
	IntroText.Text         = UI_TEXT.Intro
	IntroText.ZIndex       = 502

	local IntroLine        = Instance.new("Frame", IntroFrame)
	IntroLine.AnchorPoint  = Vector2.new(0.5, 0.5)
	IntroLine.Position     = UDim2.new(0.5, 0, 0.5, 16)
	IntroLine.Size         = UDim2.new(0, 0, 0, 2)
	IntroLine.BackgroundColor3 = Color3.fromHex("#8B0000")
	IntroLine.BorderSizePixel = 0
	IntroLine.BackgroundTransparency = 1
	IntroLine.ZIndex       = 503
	Instance.new("UICorner", IntroLine).CornerRadius = UDim.new(1, 0)

	TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.05}):Play()
	TweenService:Create(Blur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 24}):Play()
	task.wait(0.1)
	TweenService:Create(IntroText, TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
	task.wait(0.2)
	TweenService:Create(IntroLine, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(0, 260, 0, 2)}):Play()
	task.wait(1.6)
	TweenService:Create(IntroText, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
	TweenService:Create(IntroLine, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play()
	task.wait(0.3)
	TweenService:Create(IntroFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Blur, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play()
	task.wait(0.3)

	RegistrarTransparencias(mainWrapper)
	for _, item in ipairs(mainWrapper:GetDescendants()) do RegistrarTransparencias(item) end

	local introNormalSize = select(1, GetResponsiveUISizes())
	mainWrapper.Size = introNormalSize
	mainWrapper.Visible = true
	FloatBtn.Visible    = true
	UIState             = "OPEN"
	isTransitioning     = false

	local oldMainScale = mainWrapper:FindFirstChild("IntroMainScale")
	if oldMainScale then oldMainScale:Destroy() end
	local MainScale     = Instance.new("UIScale", mainWrapper)
	MainScale.Name = "IntroMainScale"
	MainScale.Scale     = 0.85
	AplicarFadeSincronizado(mainWrapper, true, 0)
	AplicarFadeSincronizado(mainWrapper, false, 0.35)

	local openScale = TweenService:Create(MainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
	openScale:Play()

	FloatBtn.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(FloatBtn, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 44, 0, 44)}):Play()

	CriarNotificacao(
		"AKATSUKI SCRIPTS",
		"Blox Fruits Script iniciado com sucesso. Bem-vindo, " .. player.DisplayName .. "."
	)


	openScale.Completed:Connect(function()
		MainScale:Destroy()
		pcall(function() Blur:Destroy() end)
		IntroFrame:Destroy()
		task.defer(function()
			selectTab("Farming")
		end)
	end)
end

ExecutarIntroAkat()
