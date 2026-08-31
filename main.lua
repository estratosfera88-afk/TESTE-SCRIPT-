-- [[
--     AKAT BLOX FRUITS LOGIC [v6.0]
--     Backend completo — Auto Farm, Combat, Visuals, Anti-Ban
--     Compatible com Delta Mobile & PC
--     BACKEND ONLY — sem código de interface visual
-- ]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui       = game:GetService("StarterGui")

local player  = Players.LocalPlayer
local Camera  = workspace.CurrentCamera
local mouse   = player:GetMouse()

-- ==================== GUARD ANTI-DUPLICATA ====================
if _G.AkatLogicRunning then
    pcall(function()
        if _G.AkatCallbacks and _G.AkatCallbacks.ShutdownAll then
            _G.AkatCallbacks.ShutdownAll()
        end
    end)
end
_G.AkatLogicRunning = true

local scriptAlive = true

-- ==================== CONFIGURAÇÕES ESPELHO ====================
local Configs = {
    -- Farm
    AutoFarmLevel    = false,
    AutoFarmBoss     = false,
    AutoFarmMastery  = false,
    AutoFarmBones    = false,
    AutoFarmChests   = false,
    AutoQuest        = false,
    MobAura          = false, AuraRadiusValue = 20,
    AutoSkills       = false,
    -- Combat
    InstantKill      = false,
    AntiKill         = false,
    NoClip           = false,
    -- Visuals
    ESP              = false,
    NameESP          = false,
    Tracer           = false,
    XRay             = false,
    -- Player
    Speed            = false, SpeedValue    = 16,
    JumpPower        = false, JumpPowerValue = 50,
    AntiFling        = false,
    Invisibility     = false,
    -- Settings
    AntiAFK          = false,
    AntiKick         = false,
    ChatLog          = false,
    Debug            = false,
}
_G.Configs = Configs

-- ==================== DEBUG ====================
local function Log(sys, msg)
    if Configs.Debug then
        warn(("[AKAT][%s] %s"):format(sys, tostring(msg)))
    end
end

-- ==================== ESTADO DINÂMICO ====================
local ESPHighlights  = {}
local NameTags       = {}
local Tracers        = {}
local XRayParts      = {}
local invisOrigTrans = {}
local espConns       = {}
local hbConn, steppedConn, charConn, pAddedConn, pRemConn = nil, nil, nil, nil, nil
local xrayConn       = nil

local selectedBoss   = "Gorilla King"
local selectedMastery = "Fruto"

-- ==================== FUNÇÕES AUXILIARES ====================
local function GetChar()       return player.Character end
local function GetRoot()       local c = GetChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum()        local c = GetChar(); return c and c:FindFirstChildOfClass("Humanoid") end

-- Verifica se o personagem está vivo
local function IsAlive()
    local h = GetHum()
    return h and h.Health > 0
end

-- ==================== ANTI-AFK ====================
local antiAfkConn = nil
local function StartAntiAFK()
    if antiAfkConn then return end
    antiAfkConn = RunService.Heartbeat:Connect(function()
        if not Configs.AntiAFK or not scriptAlive then return end
        -- Simula movimento virtual periódico a cada 60s
        pcall(function()
            local vip = player:FindFirstChild("PlayerGui")
            if vip then
                StarterGui:SetCore("ResetButtonCallback", false)
            end
        end)
    end)

    -- Loop separado para input periódico
    task.spawn(function()
        while scriptAlive and Configs.AntiAFK do
            task.wait(55)
            if not Configs.AntiAFK then break end
            -- Simula tecla virtual para manter conexão ativa
            pcall(function()
                if VirtualInputManager then
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.1)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end
            end)
            -- Movimenta câmera levemente para evitar kick
            pcall(function()
                if Camera then
                    Camera.CFrame = Camera.CFrame * CFrame.Angles(0, 0.001, 0)
                end
            end)
        end
    end)
end

local function StopAntiAFK()
    if antiAfkConn then antiAfkConn:Disconnect(); antiAfkConn = nil end
end

-- ==================== ANTI-KICK (BYPASS) ====================
-- Adiciona delays e variações aleatórias nas ações de farm para reduzir detecção.
local function SafeWait(base, variance)
    variance = variance or base * 0.3
    local delay = base + (math.random() - 0.5) * variance * 2
    task.wait(math.max(0.05, delay))
end

-- Teleporte com bypass: move em pequenos passos para parecer legítimo
local function SafeTeleport(root, targetCFrame, fast)
    if not root or not root.Parent then return end
    if fast then
        -- Teleporte direto com offset aleatório anti-detecção
        local offset = Vector3.new(
            (math.random() - 0.5) * 0.5,
            (math.random() * 0.3),
            (math.random() - 0.5) * 0.5
        )
        pcall(function() root.CFrame = targetCFrame + offset end)
        return
    end
    -- Teleporte suave em 2 etapas para farms visados
    local midPoint = CFrame.new(
        (root.Position + targetCFrame.Position) / 2
    )
    pcall(function() root.CFrame = midPoint end)
    task.wait(0.08 + math.random() * 0.04)
    pcall(function() root.CFrame = targetCFrame end)
end

-- ==================== ESP ====================
local ESP_COLORS = {
    Player = Color3.fromRGB(80, 180, 255),
    NPC    = Color3.fromRGB(200, 80, 80),
}

local function ESP_Apply(target, isNPC)
    if not target or not target.Parent then return end
    local char = target:IsA("Model") and target or (target.Character)
    if not char then return end

    local existing = char:FindFirstChild("AkatESP")
    local hl = existing or Instance.new("Highlight")
    hl.Name              = "AkatESP"
    hl.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency  = 0.35
    hl.OutlineTransparency = 0
    hl.FillColor         = isNPC and ESP_COLORS.NPC    or ESP_COLORS.Player
    hl.OutlineColor      = isNPC and ESP_COLORS.NPC    or ESP_COLORS.Player
    if not existing then hl.Parent = char end
    return hl
end

local function ESP_ClearPlayer(p)
    if ESPHighlights[p] then
        pcall(function() ESPHighlights[p]:Destroy() end)
        ESPHighlights[p] = nil
    end
end

local function ESP_Enable()
    Configs.ESP = true
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            ESPHighlights[p] = ESP_Apply(p, false)
        end
    end
    -- NPCs do workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(obj) then
            ESP_Apply(obj, true)
        end
    end
end

local function ESP_Disable()
    Configs.ESP = false
    for p, hl in pairs(ESPHighlights) do
        pcall(function() if hl.Parent then hl:Destroy() end end)
        ESPHighlights[p] = nil
    end
    -- Remove de NPCs
    for _, obj in ipairs(workspace:GetDescendants()) do
        local hl = obj:IsA("Model") and obj:FindFirstChild("AkatESP")
        if hl then pcall(function() hl:Destroy() end) end
    end
end

-- ==================== NAME ESP ====================
local function UpdateNameTag(p)
    if p == player or not p.Character or not Configs.NameESP then
        if NameTags[p] then pcall(function() NameTags[p]:Destroy() end); NameTags[p] = nil end
        return
    end
    local head = p.Character:FindFirstChild("Head")
    if not head then return end

    local tag = NameTags[p]
    if not tag or not tag.Parent then
        tag              = Instance.new("BillboardGui")
        tag.Name         = "AkatName"
        tag.Size         = UDim2.fromOffset(160, 30)
        tag.StudsOffset  = Vector3.new(0, 3.2, 0)
        tag.AlwaysOnTop  = true
        tag.Parent       = head

        local lbl              = Instance.new("TextLabel")
        lbl.Name               = "Name"
        lbl.Size               = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Font               = Enum.Font.GothamBold
        lbl.TextSize           = 12
        lbl.TextStrokeTransparency = 0.5
        lbl.Parent             = tag
        NameTags[p] = tag
    end

    local lbl = tag:FindFirstChild("Name")
    if lbl then
        lbl.Text       = "[" .. p.DisplayName .. "]"
        lbl.TextColor3 = ESP_COLORS.Player
    end
end

local function ClearNameTags()
    for p, t in pairs(NameTags) do
        pcall(function() t:Destroy() end); NameTags[p] = nil
    end
end

-- ==================== TRACER ESP ====================
local function UpdateTracer(p)
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

    local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not tRoot or not myRoot then return end

    local data = Tracers[p]
    if not data or not data.a.Parent then
        local a              = Instance.new("Attachment", myRoot)
        local b              = Instance.new("Attachment", tRoot)
        local beam           = Instance.new("Beam", myRoot)
        beam.Attachment0     = a
        beam.Attachment1     = b
        beam.FaceCamera      = true
        beam.LightEmission   = 0.8
        beam.LightInfluence  = 0
        beam.Transparency    = NumberSequence.new(0)
        beam.Width0          = 0.1
        beam.Width1          = 0.05
        data                 = {a = a, b = b, beam = beam}
        Tracers[p]           = data
    end
    data.beam.Color = ColorSequence.new(ESP_COLORS.Player)
end

local function ClearTracers()
    for p, d in pairs(Tracers) do
        pcall(function() d.a:Destroy(); d.b:Destroy(); d.beam:Destroy() end)
        Tracers[p] = nil
    end
end

-- ==================== X-RAY ====================
local function XRay_Enable()
    if xrayConn then xrayConn:Disconnect(); xrayConn = nil end

    local function apply(part)
        if not Configs.XRay or not part:IsA("BasePart") then return end
        local char = player.Character
        if part:IsDescendantOf(char) or part:IsDescendantOf(Camera) then return end
        if XRayParts[part] == nil then XRayParts[part] = part.LocalTransparencyModifier end
        part.LocalTransparencyModifier = 0.6
    end

    for _, d in ipairs(workspace:GetDescendants()) do apply(d) end
    xrayConn = workspace.DescendantAdded:Connect(function(d) task.defer(function() apply(d) end) end)
end

local function XRay_Disable()
    if xrayConn then xrayConn:Disconnect(); xrayConn = nil end
    for part, orig in pairs(XRayParts) do
        if part and part.Parent then part.LocalTransparencyModifier = orig end
    end
    table.clear(XRayParts)
end

-- ==================== INVISIBILIDADE ====================
local function Invisibility_Apply(enabled)
    local char = player.Character
    if not char then return end
    if enabled then
        table.clear(invisOrigTrans)
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                invisOrigTrans[p] = p.Transparency; p.Transparency = 1
            elseif p:IsA("Decal") then
                invisOrigTrans[p] = p.Transparency; p.Transparency = 1
            end
        end
    else
        for p, t in pairs(invisOrigTrans) do
            if p and p.Parent then p.Transparency = t end
        end
        table.clear(invisOrigTrans)
    end
end

-- ==================== BLOX FRUITS: MAPA DE BOSSES ====================
-- Coordenadas aproximadas dos bosses do First Sea
local BossData = {
    ["Gorilla King"]       = { pos = Vector3.new(1375, 130, 1350),  name = "Gorilla King" },
    ["Saber Expert"]       = { pos = Vector3.new(-1375, 130, -480), name = "Saber Expert" },
    ["Cursed Captain"]     = { pos = Vector3.new(1000, 130, -2100), name = "Cursed Captain" },
    ["Yeti"]               = { pos = Vector3.new(-4650, 130, 320),  name = "Yeti" },
    ["Smoke Admiral"]      = { pos = Vector3.new(-680, 130, 2100),  name = "Smoke Admiral" },
    ["Magma Admiral"]      = { pos = Vector3.new(-4300, 130, -2500), name = "Magma Admiral" },
    ["Ice Admiral"]        = { pos = Vector3.new(-4650, 130, 320),  name = "Ice Admiral" },
    ["Sand Boss"]          = { pos = Vector3.new(3750, 130, -200),  name = "Sand Boss" },
    ["Thunder God"]        = { pos = Vector3.new(7600, 130, 1200),  name = "Thunder God" },
    ["Lord of Destruction"] = { pos = Vector3.new(7600, 130, -900), name = "Lord of Destruction" },
}

-- Ilhas por nível aproximado (First Sea)
local LevelIslands = {
    { minLevel = 1,   maxLevel = 15,   pos = Vector3.new(1100, 120, 1300),   name = "Starter Island"  },
    { minLevel = 15,  maxLevel = 30,   pos = Vector3.new(900,  120, 1600),   name = "Marine Base"     },
    { minLevel = 30,  maxLevel = 60,   pos = Vector3.new(1375, 120, 1350),   name = "Jungle"          },
    { minLevel = 60,  maxLevel = 90,   pos = Vector3.new(-980, 120, 1800),   name = "Pirate Village"  },
    { minLevel = 90,  maxLevel = 120,  pos = Vector3.new(-1375, 120, -480),  name = "Desert"          },
    { minLevel = 120, maxLevel = 170,  pos = Vector3.new(450,  120, -2100),  name = "Frozen Village"  },
    { minLevel = 170, maxLevel = 220,  pos = Vector3.new(1000, 120, -2100),  name = "Marine Fortress" },
    { minLevel = 220, maxLevel = 300,  pos = Vector3.new(7600, 120, 1200),   name = "Skylands"        },
    { minLevel = 300, maxLevel = 700,  pos = Vector3.new(-4300, 120, -2500), name = "Magma Village"   },
    { minLevel = 700, maxLevel = 1500, pos = Vector3.new(-4650, 120, 320),   name = "Ice Castle"      },
}

-- Spawns de baús por ilhas
local ChestSpawns = {
    Vector3.new(1100, 125, 1300),
    Vector3.new(-980, 125, 1800),
    Vector3.new(450,  125, -2100),
    Vector3.new(7600, 125, 1200),
    Vector3.new(-4300, 125, -2500),
}

-- Spawns de Bones / Materials
local BoneSpawns = {
    Vector3.new(1000, 125, -2100),
    Vector3.new(-1375, 125, -480),
    Vector3.new(-4300, 125, -2500),
    Vector3.new(7600, 125, 1200),
}

-- ==================== OBTER NÍVEL DO PLAYER ====================
local function GetPlayerLevel()
    local level = 0
    pcall(function()
        -- Tenta via leaderstats
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local lv = ls:FindFirstChild("Level") or ls:FindFirstChild("Lv") or ls:FindFirstChild("level")
            if lv then level = tonumber(lv.Value) or 0 end
        end
        -- Fallback: tenta via Data
        if level == 0 then
            local data = player:FindFirstChild("Data")
            if data then
                local lv = data:FindFirstChild("Level")
                if lv then level = tonumber(lv.Value) or 0 end
            end
        end
    end)
    return level
end

-- ==================== OBTER ILHA CERTA PARA NÍVEL ====================
local function GetIslandForLevel(level)
    local best = LevelIslands[1]
    for _, island in ipairs(LevelIslands) do
        if level >= island.minLevel then best = island end
    end
    return best
end

-- ==================== ENCONTRAR MOB MAIS PRÓXIMO ====================
local function FindNearestMob(root, maxDist)
    maxDist = maxDist or 1500
    local nearest, nearestDist = nil, maxDist

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local mRoot = obj:FindFirstChild("HumanoidRootPart")
            if hum and mRoot and hum.Health > 0 and not Players:GetPlayerFromCharacter(obj) then
                local dist = (root.Position - mRoot.Position).Magnitude
                if dist < nearestDist then
                    nearest = obj
                    nearestDist = dist
                end
            end
        end
    end
    return nearest
end

-- ==================== ENCONTRAR MOB POR NOME ====================
local function FindMobByName(name, root, maxDist)
    maxDist = maxDist or 2000
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:find(name) then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local mRoot = obj:FindFirstChild("HumanoidRootPart")
            if hum and mRoot and hum.Health > 0 then
                if not root or (root.Position - mRoot.Position).Magnitude < maxDist then
                    return obj
                end
            end
        end
    end
    return nil
end

-- ==================== MOB AURA (KILL AURA) ====================
-- Usa firetouchinterest para todos os ataques corpo a corpo do personagem
local function ApplyMobAura(root, char, radius)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    -- Usa todas as BaseParts do personagem como hitbox (simula área de hit)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            for _, mob in ipairs(workspace:GetDescendants()) do
                if mob:IsA("Model") and not Players:GetPlayerFromCharacter(mob) then
                    local mHum  = mob:FindFirstChildOfClass("Humanoid")
                    local mRoot = mob:FindFirstChild("HumanoidRootPart")
                    if mHum and mRoot and mHum.Health > 0 then
                        if (root.Position - mRoot.Position).Magnitude <= radius then
                            pcall(function()
                                firetouchinterest(mRoot, part, 0)
                                firetouchinterest(mRoot, part, 1)
                            end)
                        end
                    end
                end
            end
        end
    end
end

-- ==================== AUTO SKILLS ====================
-- Ativa todas as skills do fruto/espada em loop
local function UseAutoSkills(char)
    if not char then return end

    -- Tenta usar skills via RemoteEvent (padrão de muitos servidores BF)
    local function tryFireRemote(name, ...)
        local rem = ReplicatedStorage:FindFirstChild(name, true)
        if rem and rem:IsA("RemoteEvent") then
            pcall(function() rem:FireServer(...) end)
            return true
        end
        return false
    end

    -- Ativa fruto (1, 2, 3, 4)
    for _, key in ipairs({Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V}) do
        pcall(function()
            if VirtualInputManager then
                VirtualInputManager:SendKeyEvent(true, key, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, key, false, game)
            end
        end)
        task.wait(0.12)
    end

    -- Clique do mouse para ataque básico
    pcall(function()
        if VirtualInputManager then
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end
    end)
end

-- ==================== AUTO QUEST ====================
local function TryAcceptQuest()
    -- Tenta interagir com NPCs de quest via RemoteEvents conhecidos do BF
    local function tryRemote(name)
        local rem = ReplicatedStorage:FindFirstChild(name, true)
        if rem and (rem:IsA("RemoteEvent") or rem:IsA("RemoteFunction")) then
            pcall(function() rem:FireServer() end)
            return true
        end
        return false
    end

    -- Nomes comuns de remotes de quest no BF
    local questRemotes = {
        "GiveQuest", "AcceptQuest", "QuestAccept",
        "ReceiveQuest", "StartQuest",
    }

    for _, name in ipairs(questRemotes) do
        if tryRemote(name) then
            Log("AutoQuest", "Quest aceita via " .. name)
            return true
        end
    end

    -- Fallback: procura NPC de quest próximo e interage
    local root = GetRoot()
    if not root then return false end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local name = obj.Name:lower()
            if name:find("quest") or name:find("npc") then
                local objRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("BasePart")
                if objRoot and (root.Position - objRoot.Position).Magnitude < 10 then
                    -- Simula interação E (padrão BF)
                    pcall(function()
                        if VirtualInputManager then
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                            task.wait(0.1)
                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                        end
                    end)
                    return true
                end
            end
        end
    end
    return false
end

-- ==================== AUTO FARM LEVEL ====================
task.spawn(function()
    local lastIslandTp = 0
    local ISLAND_TP_COOLDOWN = 8  -- Anti-kick: não teleporta ilha mais de 1x a cada 8s

    while scriptAlive do
        SafeWait(0.15, 0.05)
        if not Configs.AutoFarmLevel or not IsAlive() then continue end

        local root = GetRoot()
        if not root then continue end

        -- 1. Vai para a ilha certa pelo nível
        local level = GetPlayerLevel()
        local island = GetIslandForLevel(level)
        local now = os.clock()
        if now - lastIslandTp > ISLAND_TP_COOLDOWN then
            SafeTeleport(root, CFrame.new(island.pos), true)
            lastIslandTp = now
            SafeWait(1.5, 0.3)  -- Espera carregar a ilha
        end

        -- 2. Aceita quest automaticamente
        if Configs.AutoQuest then
            TryAcceptQuest()
        end

        -- 3. Encontra mob mais próximo e teleporta até ele
        local mob = FindNearestMob(root, 1500)
        if mob then
            local mobRoot = mob:FindFirstChild("HumanoidRootPart")
            if mobRoot then
                SafeTeleport(root, CFrame.new(mobRoot.Position + Vector3.new(0, 2, 0)), true)
                SafeWait(0.3, 0.1)
            end
        end

        -- 4. Usa skills se AutoSkills ativo
        if Configs.AutoSkills then
            local char = GetChar()
            if char then UseAutoSkills(char) end
        end

        -- 5. Mob Aura
        if Configs.MobAura then
            local char = GetChar()
            if char and root then
                ApplyMobAura(root, char, Configs.AuraRadiusValue or 20)
            end
        end
    end
end)

-- ==================== AUTO FARM BOSS ====================
task.spawn(function()
    local lastBossTp     = 0
    local BOSS_TP_COOLDOWN = 3
    local bossRespawnWait = 30  -- Espera padrão de respawn do boss

    while scriptAlive do
        SafeWait(0.2, 0.05)
        if not Configs.AutoFarmBoss or not IsAlive() then continue end

        local root = GetRoot()
        if not root then continue end

        local bossInfo = BossData[selectedBoss]
        if not bossInfo then continue end

        -- Tenta encontrar o boss no workspace
        local bossModel = FindMobByName(bossInfo.name, nil, math.huge)

        if bossModel then
            local bossRoot = bossModel:FindFirstChild("HumanoidRootPart")
            local bossHum  = bossModel:FindFirstChildOfClass("Humanoid")

            if bossRoot and bossHum and bossHum.Health > 0 then
                -- Teleporta até o boss
                local now = os.clock()
                if now - lastBossTp > BOSS_TP_COOLDOWN then
                    SafeTeleport(root, CFrame.new(bossRoot.Position + Vector3.new(2, 3, 0)), false)
                    lastBossTp = now
                end

                -- Usa skills
                if Configs.AutoSkills then
                    local char = GetChar()
                    if char then UseAutoSkills(char) end
                end

                -- Mob Aura com raio maior para boss
                if Configs.MobAura then
                    local char = GetChar()
                    if char then ApplyMobAura(root, char, math.max(Configs.AuraRadiusValue or 20, 25)) end
                end

                -- firetouchinterest como fallback
                local char = GetChar()
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and bossHum.Health > 0 then
                            pcall(function()
                                firetouchinterest(bossRoot, part, 0)
                                firetouchinterest(bossRoot, part, 1)
                            end)
                        end
                    end
                end
            end
        else
            -- Boss não encontrado — teleporta até a posição conhecida e aguarda spawn
            Log("BossFarm", "Boss '" .. bossInfo.name .. "' não encontrado, teleportando para área...")
            SafeTeleport(root, CFrame.new(bossInfo.pos + Vector3.new(0, 5, 0)), true)

            -- Anti-kick durante espera: pequenos movimentos
            for i = 1, 10 do
                SafeWait(3, 0.5)
                if not Configs.AutoFarmBoss or not scriptAlive then break end
                -- Mini-movimento para não ser kickado por AFK
                pcall(function()
                    local r = GetRoot()
                    if r then
                        r.CFrame = r.CFrame * CFrame.new(
                            (math.random() - 0.5) * 0.2,
                            0,
                            (math.random() - 0.5) * 0.2
                        )
                    end
                end)
            end
        end
    end
end)

-- ==================== AUTO FARM MASTERY ====================
task.spawn(function()
    -- Para mastery, usamos mobs de nível médio onde o personagem não mata em 1 hit
    -- mas acumula hits/skills (mais skills por mob = mais mastery)
    local MASTERY_MOBS_AREA = Vector3.new(-980, 120, 1800)  -- Pirate Village

    while scriptAlive do
        SafeWait(0.18, 0.05)
        if not Configs.AutoFarmMastery or not IsAlive() then continue end

        local root = GetRoot()
        if not root then continue end

        local mob = FindNearestMob(root, 300)
        if not mob then
            -- Vai para área de mastery
            SafeTeleport(root, CFrame.new(MASTERY_MOBS_AREA + Vector3.new(
                (math.random() - 0.5) * 20, 5, (math.random() - 0.5) * 20
            )), true)
            SafeWait(1.2, 0.3)
            continue
        end

        local mobRoot = mob:FindFirstChild("HumanoidRootPart")
        local mobHum  = mob:FindFirstChildOfClass("Humanoid")
        if not mobRoot or not mobHum or mobHum.Health <= 0 then continue end

        -- Fica próximo ao mob
        SafeTeleport(root, CFrame.new(mobRoot.Position + Vector3.new(2, 2, 0)), true)

        -- Usa skills repetidamente baseado no tipo de mastery selecionado
        local char = GetChar()
        if char then
            if selectedMastery == "Fruto" then
                -- Usa skills do fruto (Z, X, C, V)
                for _, key in ipairs({Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V}) do
                    pcall(function()
                        if VirtualInputManager then
                            VirtualInputManager:SendKeyEvent(true, key, false, game)
                            task.wait(0.06); VirtualInputManager:SendKeyEvent(false, key, false, game)
                        end
                    end)
                    SafeWait(0.2, 0.05)
                end
            elseif selectedMastery == "Espada" then
                -- Usa ataque de espada (clique + skills Q, E)
                for i = 1, 3 do
                    pcall(function()
                        if VirtualInputManager then
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                            task.wait(0.05); VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                        end
                    end)
                    SafeWait(0.15, 0.04)
                end
                for _, key in ipairs({Enum.KeyCode.Q, Enum.KeyCode.E}) do
                    pcall(function()
                        if VirtualInputManager then
                            VirtualInputManager:SendKeyEvent(true, key, false, game)
                            task.wait(0.05); VirtualInputManager:SendKeyEvent(false, key, false, game)
                        end
                    end)
                    SafeWait(0.2, 0.05)
                end
            elseif selectedMastery == "Arma de Fogo" then
                -- Simula atirar com arma de fogo
                for i = 1, 5 do
                    pcall(function()
                        if VirtualInputManager then
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                            task.wait(0.08); VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                        end
                    end)
                    SafeWait(0.12, 0.03)
                end
            end
        end

        -- Mob Aura para garantir hits
        if Configs.MobAura and char then
            ApplyMobAura(root, char, Configs.AuraRadiusValue or 20)
        end
    end
end)

-- ==================== AUTO FARM BONES/MATERIALS ====================
task.spawn(function()
    local boneIdx = 1

    while scriptAlive do
        SafeWait(0.2, 0.06)
        if not Configs.AutoFarmBones or not IsAlive() then continue end

        local root = GetRoot()
        if not root then continue end

        -- Rotaciona entre os spawn points de bones
        local spawnPos = BoneSpawns[boneIdx]
        boneIdx = (boneIdx % #BoneSpawns) + 1

        SafeTeleport(root, CFrame.new(spawnPos + Vector3.new(
            (math.random() - 0.5) * 10, 4, (math.random() - 0.5) * 10
        )), true)
        SafeWait(1.0, 0.2)

        if not Configs.AutoFarmBones then continue end

        -- Mata mobs na área para obter drops
        for i = 1, 8 do
            if not Configs.AutoFarmBones or not IsAlive() then break end
            local mob = FindNearestMob(root, 200)
            if mob then
                local mobRoot = mob:FindFirstChild("HumanoidRootPart")
                if mobRoot then
                    SafeTeleport(root, CFrame.new(mobRoot.Position + Vector3.new(1, 2, 0)), true)
                    local char = GetChar()
                    if char then
                        ApplyMobAura(root, char, 30)
                        if Configs.AutoSkills then UseAutoSkills(char) end
                    end
                end
            end
            SafeWait(0.4, 0.1)
        end

        -- Coleta drops via touch
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    local name = obj.Name:lower()
                    if name:find("bone") or name:find("material") or name:find("drop") or name:find("fragment") then
                        if (root.Position - obj.Position).Magnitude < 150 then
                            SafeTeleport(root, CFrame.new(obj.Position + Vector3.new(0, 2, 0)), true)
                            pcall(function()
                                firetouchinterest(root, obj, 0)
                                firetouchinterest(root, obj, 1)
                            end)
                        end
                    end
                end
            end
        end)

        SafeWait(2.5, 0.5)  -- Anti-kick: pausa entre rotações de spawn
    end
end)

-- ==================== AUTO FARM CHESTS ====================
task.spawn(function()
    local chestIdx = 1

    while scriptAlive do
        SafeWait(0.2, 0.06)
        if not Configs.AutoFarmChests or not IsAlive() then continue end

        local root = GetRoot()
        if not root then continue end

        -- Procura baús reais no workspace
        local foundChest = false
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") or obj:IsA("BasePart") then
                local name = obj.Name:lower()
                if name:find("chest") or name:find("bau") or name:find("treasure") then
                    local cPart = obj:IsA("BasePart") and obj or obj:FindFirstChildOfClass("BasePart")
                    if cPart then
                        local dist = (root.Position - cPart.Position).Magnitude
                        if dist < 3000 then
                            SafeTeleport(root, CFrame.new(cPart.Position + Vector3.new(0, 2, 0)), false)
                            SafeWait(0.5, 0.1)
                            -- Interação com baú
                            pcall(function()
                                firetouchinterest(root, cPart, 0)
                                firetouchinterest(root, cPart, 1)
                            end)
                            pcall(function()
                                if VirtualInputManager then
                                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                                    task.wait(0.1)
                                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                                end
                            end)
                            foundChest = true
                            SafeWait(0.8, 0.2)
                        end
                    end
                end
            end
        end

        if not foundChest then
            -- Rotaciona entre spawn points conhecidos
            local spawnPos = ChestSpawns[chestIdx]
            chestIdx = (chestIdx % #ChestSpawns) + 1
            SafeTeleport(root, CFrame.new(spawnPos + Vector3.new(
                (math.random() - 0.5) * 15, 4, (math.random() - 0.5) * 15
            )), true)
            SafeWait(3.0, 0.5)  -- Espera baús respawnarem
        end
    end
end)

-- ==================== INSTANT KILL ====================
task.spawn(function()
    while scriptAlive do
        SafeWait(0.12)
        if not Configs.InstantKill or not IsAlive() then continue end

        local root = GetRoot()
        local char = GetChar()
        if not root or not char then continue end

        -- Usa firetouchinterest com todas as parts para matar players
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
                local pHum  = p.Character:FindFirstChildOfClass("Humanoid")
                if pRoot and pHum and pHum.Health > 0 then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            pcall(function()
                                firetouchinterest(pRoot, part, 0)
                                firetouchinterest(pRoot, part, 1)
                            end)
                        end
                    end
                end
            end
        end
    end
end)

-- ==================== ANTI-KILL (GOD MODE PARCIAL) ====================
local function ApplyAntiKill(enabled)
    Configs.AntiKill = enabled
    local char = GetChar()
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if enabled then
        -- Reseta HP constantemente (god mode simples)
        task.spawn(function()
            while Configs.AntiKill and scriptAlive do
                task.wait(0.1)
                local h = GetHum()
                if h and h.Health < h.MaxHealth then
                    h.Health = h.MaxHealth
                end
            end
        end)
    end
end

-- ==================== NO-CLIP ====================
steppedConn = RunService.Stepped:Connect(function()
    if not scriptAlive then return end
    if Configs.NoClip or Configs.AutoFarmLevel or Configs.AutoFarmBoss
        or Configs.AutoFarmMastery or Configs.AutoFarmBones or Configs.AutoFarmChests then
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)

-- ==================== ANTI-FLING ====================
-- ==================== HEARTBEAT PRINCIPAL ====================
hbConn = RunService.Heartbeat:Connect(function()
    if not scriptAlive then return end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    -- Speed
    if not (Configs.AutoFarmLevel or Configs.AutoFarmBoss or Configs.AutoFarmMastery
            or Configs.AutoFarmBones or Configs.AutoFarmChests) then
        hum.WalkSpeed    = Configs.Speed    and Configs.SpeedValue    or 16
        hum.UseJumpPower = true
        hum.JumpPower    = Configs.JumpPower and Configs.JumpPowerValue or 50
    end

    -- Anti-Fling
    if Configs.AntiFling then
        if root.AssemblyLinearVelocity.Magnitude > 80 or root.AssemblyAngularVelocity.Magnitude > 80 then
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end

    -- Tracers (atualização leve por frame)
    if Configs.Tracer then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                if not Tracers[p] then UpdateTracer(p) end
            end
        end
    end

    -- Mob Aura standalone (quando nenhum farm está ativo)
    if Configs.MobAura and not (Configs.AutoFarmLevel or Configs.AutoFarmBoss or Configs.AutoFarmMastery) then
        ApplyMobAura(root, char, Configs.AuraRadiusValue or 20)
    end
end)

-- ==================== THREAD: VISUAIS (Name + ESP) ====================
task.spawn(function()
    local lastESP = 0
    while scriptAlive do
        task.wait(0.35)
        if Configs.ESP then
            local now = os.clock()
            if now - lastESP > 0.5 then
                lastESP = now
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= player and p.Character then
                        if not ESPHighlights[p] then ESPHighlights[p] = ESP_Apply(p, false) end
                    end
                end
            end
        end
        if Configs.NameESP then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then UpdateNameTag(p) end
            end
        end
    end
end)

-- ==================== ANTI-KICK AVANÇADO ====================
-- Monitora se o servidor está prestes a kickar e ajusta timing
task.spawn(function()
    local lastAction = os.clock()
    while scriptAlive do
        task.wait(45)
        if not Configs.AntiKick then continue end

        -- Verifica se algum farm está rolando há muito tempo sem pausa
        local now = os.clock()
        if now - lastAction > 120 then
            -- Pausa os farms por 3s para simular comportamento humano
            local wasLvl    = Configs.AutoFarmLevel
            local wasBoss   = Configs.AutoFarmBoss
            local wasMastery = Configs.AutoFarmMastery
            local wasBones  = Configs.AutoFarmBones
            local wasChests = Configs.AutoFarmChests

            Configs.AutoFarmLevel   = false
            Configs.AutoFarmBoss    = false
            Configs.AutoFarmMastery = false
            Configs.AutoFarmBones   = false
            Configs.AutoFarmChests  = false

            -- Simula comportamento idle
            local root = GetRoot()
            if root then
                local hum = GetHum()
                if hum then
                    hum.WalkSpeed = 0
                    task.wait(2 + math.random() * 2)
                    hum.WalkSpeed = Configs.Speed and Configs.SpeedValue or 16
                end
            end

            -- Restaura
            Configs.AutoFarmLevel   = wasLvl
            Configs.AutoFarmBoss    = wasBoss
            Configs.AutoFarmMastery = wasMastery
            Configs.AutoFarmBones   = wasBones
            Configs.AutoFarmChests  = wasChests
            lastAction = os.clock()
        else
            -- Pequena ação de micro-variação para não parecer bot
            local root = GetRoot()
            if root and (wasLvl or wasBoss or wasMastery or wasBones or wasChests) then
                pcall(function()
                    root.CFrame = root.CFrame * CFrame.new(
                        (math.random() - 0.5) * 0.1, 0, (math.random() - 0.5) * 0.1
                    )
                end)
            end
        end
    end
end)

-- ==================== CHARACTER EVENTS ====================
local function OnCharacterAdded(char)
    -- Reset estados
    table.clear(invisOrigTrans)
    ClearTracers()

    task.wait(0.3)
    if not scriptAlive then return end

    -- Reaplica visuais
    if Configs.XRay      then XRay_Enable() end
    if Configs.Invisibility then Invisibility_Apply(true) end
    if Configs.AntiKill  then ApplyAntiKill(true) end
    if Configs.ESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then ESPHighlights[p] = ESP_Apply(p, false) end
        end
    end
end

charConn = player.CharacterAdded:Connect(OnCharacterAdded)

pAddedConn = Players.PlayerAdded:Connect(function(p)
    if not Configs.ESP then return end
    p.CharacterAdded:Connect(function(char)
        task.wait(0.3)
        if Configs.ESP then ESPHighlights[p] = ESP_Apply(p, false) end
        if Configs.NameESP then UpdateNameTag(p) end
        if Configs.Tracer  then UpdateTracer(p)  end
    end)
end)

pRemConn = Players.PlayerRemoving:Connect(function(p)
    ESP_ClearPlayer(p)
    if NameTags[p] then pcall(function() NameTags[p]:Destroy() end); NameTags[p] = nil end
    if Tracers[p]  then
        local d = Tracers[p]
        pcall(function() d.a:Destroy(); d.b:Destroy(); d.beam:Destroy() end)
        Tracers[p] = nil
    end
end)

-- ==================== SHUTDOWN ====================
local function Shutdown()
    scriptAlive = false

    if hbConn      then hbConn:Disconnect()      end
    if steppedConn then steppedConn:Disconnect()  end
    if charConn    then charConn:Disconnect()     end
    if pAddedConn  then pAddedConn:Disconnect()   end
    if pRemConn    then pRemConn:Disconnect()     end
    if xrayConn    then xrayConn:Disconnect()     end
    StopAntiAFK()

    -- Limpa todos os Configs
    for k, v in pairs(Configs) do if type(v) == "boolean" then Configs[k] = false end end

    ESP_Disable()
    ClearNameTags()
    ClearTracers()
    XRay_Disable()
    Invisibility_Apply(false)

    -- Restaura personagem
    pcall(function()
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if root then
            root.Anchored = false
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if hum then hum.WalkSpeed = 16; hum.UseJumpPower = true; hum.JumpPower = 50 end
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end)

    _G.AkatLogicRunning = false
end

-- ==================== CALLBACKS DA UI ====================
_G.AkatCallbacks = {

    AutoFarmLevel = function(enabled)
        Configs.AutoFarmLevel = enabled and true or false
        Log("AutoFarmLevel", enabled and "Ativado" or "Desativado")
    end,

    AutoFarmBoss = function(enabled)
        Configs.AutoFarmBoss = enabled and true or false
        Log("AutoFarmBoss", enabled and "Ativado" or "Desativado")
    end,

    AutoFarmMastery = function(enabled)
        Configs.AutoFarmMastery = enabled and true or false
        Log("AutoFarmMastery", enabled and "Ativado" or "Desativado")
    end,

    AutoFarmBones = function(enabled)
        Configs.AutoFarmBones = enabled and true or false
        Log("AutoFarmBones", enabled and "Ativado" or "Desativado")
    end,

    AutoFarmChests = function(enabled)
        Configs.AutoFarmChests = enabled and true or false
        Log("AutoFarmChests", enabled and "Ativado" or "Desativado")
    end,

    AutoQuest = function(enabled)
        Configs.AutoQuest = enabled and true or false
    end,

    MobAura = function(enabled)
        Configs.MobAura = enabled and true or false
    end,

    AuraRadius = function(value)
        if type(value) == "number" then
            Configs.AuraRadiusValue = math.clamp(value, 5, 80)
            Configs.AuraRadius = true
        else
            Configs.AuraRadius = value and true or false
        end
    end,

    AutoSkills = function(enabled)
        Configs.AutoSkills = enabled and true or false
    end,

    SetBossTarget = function(bossName)
        selectedBoss = bossName
        Log("Boss", "Alvo definido: " .. bossName)
    end,

    SetMasteryType = function(mtype)
        selectedMastery = mtype
        Log("Mastery", "Tipo: " .. mtype)
    end,

    InstantKill = function(enabled)
        Configs.InstantKill = enabled and true or false
    end,

    AntiKill = function(enabled)
        ApplyAntiKill(enabled)
    end,

    NoClip = function(enabled)
        Configs.NoClip = enabled and true or false
        if not enabled then
            local char = player.Character
            if char then
                for _, p in ipairs(char:GetChildren()) do
                    if p:IsA("BasePart") then p.CanCollide = true end
                end
            end
        end
    end,

    ESP = function(enabled)
        if enabled then ESP_Enable() else ESP_Disable() end
    end,

    NameESP = function(enabled)
        Configs.NameESP = enabled and true or false
        if not enabled then ClearNameTags() else
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then UpdateNameTag(p) end
            end
        end
    end,

    Tracer = function(enabled)
        Configs.Tracer = enabled and true or false
        if not enabled then ClearTracers() else
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then UpdateTracer(p) end
            end
        end
    end,

    XRay = function(enabled)
        Configs.XRay = enabled and true or false
        if enabled then XRay_Enable() else XRay_Disable() end
    end,

    Speed = function(value)
        if type(value) == "number" then
            Configs.SpeedValue = math.clamp(value, 0, 500)
            Configs.Speed = true
        else
            Configs.Speed = value and true or false
        end
        local hum = GetHum()
        if hum then hum.WalkSpeed = Configs.Speed and Configs.SpeedValue or 16 end
    end,

    JumpPower = function(value)
        if type(value) == "number" then
            Configs.JumpPowerValue = math.clamp(value, 0, 500)
            Configs.JumpPower = true
        else
            Configs.JumpPower = value and true or false
        end
        local hum = GetHum()
        if hum then hum.UseJumpPower = true; hum.JumpPower = Configs.JumpPower and Configs.JumpPowerValue or 50 end
    end,

    AntiFling = function(enabled)
        Configs.AntiFling = enabled and true or false
    end,

    Invisibility = function(enabled)
        Configs.Invisibility = enabled and true or false
        Invisibility_Apply(enabled)
    end,

    TpPlayer = function(enabled)
        if not enabled then return end
        -- Teleporta até o jogador mais próximo (UI pode passar nome via parâmetro)
        local root = GetRoot()
        if not root then return end
        local nearest, nearestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local pr = p.Character:FindFirstChild("HumanoidRootPart")
                if pr then
                    local d = (root.Position - pr.Position).Magnitude
                    if d < nearestDist then nearest = p; nearestDist = d end
                end
            end
        end
        if nearest and nearest.Character then
            local pr = nearest.Character:FindFirstChild("HumanoidRootPart")
            if pr then SafeTeleport(root, CFrame.new(pr.Position + Vector3.new(2, 3, 0)), true) end
        end
    end,

    AntiAFK = function(enabled)
        Configs.AntiAFK = enabled and true or false
        if enabled then StartAntiAFK() else StopAntiAFK() end
    end,

    AntiKick = function(enabled)
        Configs.AntiKick = enabled and true or false
        Log("AntiKick", enabled and "Ativado" or "Desativado")
    end,

    ChatLog = function(enabled)
        Configs.ChatLog = enabled and true or false
        if enabled then
            -- Captura mensagens de chat
            local TextChatService = game:GetService("TextChatService")
            pcall(function()
                TextChatService.OnIncomingMessage = function(msg)
                    print(("[CHAT] %s: %s"):format(
                        msg.TextSource and msg.TextSource.Name or "?",
                        msg.Text
                    ))
                    return nil
                end
            end)
        end
    end,

    ShutdownAll = function()
        Shutdown()
    end,
}

-- ==================== INICIALIZADOR DA UI EXTERNA ====================
task.spawn(function()
    local uiUrl = "https://raw.githubusercontent.com/estratosfera88-afk/Ui-do-teste/refs/heads/main/bf_ui.lua"

    local raw, fetchOk, fetchErr = nil, false, ""
    fetchOk, fetchErr = pcall(function()
        raw = game:HttpGet(uiUrl, true)
    end)

    if not fetchOk or not raw or raw == "" then
        warn("[AKAT LOGIC] HttpGet falhou ou retornou vazio: " .. tostring(fetchErr))
        return
    end

    local fn, compileErr = loadstring(raw)
    if not fn then
        warn("[AKAT LOGIC] loadstring falhou: " .. tostring(compileErr))
        return
    end

    local runOk, runErr = pcall(fn)
    if not runOk then
        warn("[AKAT LOGIC] Erro ao executar a UI: " .. tostring(runErr))
    end
end)
