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
