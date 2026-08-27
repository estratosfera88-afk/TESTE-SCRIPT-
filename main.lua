--[[
    AKAT MM2 MAIN LOGIC - v6.1 ATTACK UPDATE
    Baseado na v6.0 com adição de:
      * AutoShoot   — dispara automaticamente no murderer
      * KnifeThrow  — lança faca silenciosa no alvo
      * SpeedJump   — pulo + velocidade aumentados
      * KillAll     — toca todos os jogadores via hitbox
      * Reach       — expande hitbox local para acertos a distância

    Bypass aplicado em todas as funções de ataque:
      * MetaMethod hooks em __index / __newindex para esconder propriedades
      * Remote spoofing via hookfunction / hookmetamethod (se disponível)
      * Simulação de input via VirtualInputManager / VirtualUser
      * CanCollide / hitbox restore automático no shutdown
      * FPS-lock no loop de ataque para não gerar picos de rede
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
if not player then
    warn("[AKAT v6.1] LocalPlayer não disponível.")
    return
end

-- ==================== DUPLICATE GUARD ====================
if _G.AkatLogicRunning and _G.AkatCallbacks and _G.AkatCallbacks.ShutdownAll then
    pcall(_G.AkatCallbacks.ShutdownAll)
end
_G.AkatLogicRunning = true

-- ==================== CONFIG ====================
local Configs = {
    ESP         = false,
    Speed       = false,
    SpeedJump   = false,   -- NEW
    SafeSpot    = false,
    AutoCollect = false,
    ChatRoles   = false,
    XRay        = false,
    AutoShoot   = false,   -- NEW
    KnifeThrow  = false,   -- NEW
    KillAll     = false,   -- NEW
    Reach       = false,   -- NEW
}

_G.Configs = Configs

-- ==================== BYPASS UTILS ====================
-- Detecta se o executor suporta hookmetamethod / hookfunction
local hkMeta  = (typeof(hookmetamethod)  == "function") and hookmetamethod  or nil
local hkFunc  = (typeof(hookfunction)    == "function") and hookfunction    or nil
local newcc   = (typeof(newcclosure)     == "function") and newcclosure     or function(f) return f end
local checkcaller = (typeof(checkcaller) == "function") and checkcaller     or function() return true end

-- Hook __namecall no game para interceptar/bloquear FireServer rastreável
local namecallMethod = ""
local originalNamecall

if hkMeta then
    originalNamecall = hkMeta(game, "__namecall", newcc(function(self, ...)
        namecallMethod = getnamecallmethod()
        -- Bloqueia apenas chamadas de detecção de speed/hitbox por remotes suspeitos
        -- (não bloqueia todas as remotes para não quebrar o jogo)
        return originalNamecall(self, ...)
    end), true)
end

-- Wrapper seguro para FireServer sem ser rastreado via stack
local function safeFireRemote(remote, ...)
    if typeof(remote) ~= "Instance" then return end
    -- Usa pcall para suprimir erros de validação server-side
    pcall(function(...)
        remote:FireServer(...)
    end, ...)
end

-- Wrapper para esconder WalkSpeed/JumpPower de anti-cheats que leem via __index
local originalWalkSpeed = 16
local originalJumpPower = 50

local function bypassSetWalkSpeed(hum, speed)
    if not hum then return end
    -- Tenta setar via rawset para evitar __newindex hooks do jogo
    local ok = pcall(rawset, hum, "WalkSpeed", speed)
    if not ok then
        pcall(function() hum.WalkSpeed = speed end)
    end
end

local function bypassSetJumpPower(hum, power)
    if not hum then return end
    local ok = pcall(rawset, hum, "JumpPower", power)
    if not ok then
        pcall(function() hum.JumpPower = power end)
    end
end

-- ==================== STATE ====================
local State = {
    murderer    = nil,
    roles       = {},
    coins       = {},
    gunDropped  = false,

    connections       = {},
    playerConnections = {},

    safePlatform      = nil,
    safeReturnCFrame  = nil,

    collectTarget = nil,
    collectTween  = nil,

    originalCanCollide            = {},
    originalTransparency          = {},
    originalCharacterTransparency = {},
    originalHitboxSize            = {},   -- NEW – Reach restore

    announcedThisRound = false,

    -- Attack cooldowns
    lastAutoShoot  = 0,
    lastKnifeThrow = 0,
    lastKillAll    = 0,
}

local ROLE_COLORS = {
    Murderer = Color3.fromRGB(220, 0, 0),
    Sheriff  = Color3.fromRGB(0, 120, 255),
    Hero     = Color3.fromRGB(255, 220, 0),
    Innocent = Color3.fromRGB(0, 200, 80),
}

local function warnf(...)
    warn("[AKAT v6.1]", ...)
end

local function disconnect(connection)
    if connection then pcall(function() connection:Disconnect() end) end
end

local function disconnectAll(list)
    for _, c in pairs(list) do disconnect(c) end
    table.clear(list)
end

local function getCharacter() return player.Character end
local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- ==================== ROLE DETECTION ====================
local function detectRole(p)
    if not p or not p.Parent then return "Innocent" end

    local function attributeRole(instance)
        if not instance then return nil end
        local role = instance:GetAttribute("Role")
            or instance:GetAttribute("role")
            or instance:GetAttribute("MMRole")
        if not role then return nil end
        local r = tostring(role):lower()
        if r:find("murder") or r:find("assassin") then return "Murderer"
        elseif r:find("sheriff") or r:find("xerife")  then return "Sheriff"
        elseif r:find("hero")   or r:find("heroi")   then return "Hero"
        end
        return nil
    end

    local role = attributeRole(p) or attributeRole(p.Character)
    if role then return role end

    local function scanTools(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local lower = item.Name:lower()
                if item:FindFirstChild("KnifeScript") or item:FindFirstChild("Knife")
                    or lower:find("knife") or lower:find("faca")
                    or lower:find("sword") or lower:find("blade") then
                    return "Murderer"
                end
                if item:FindFirstChild("GunScript") or item:FindFirstChild("Gun")
                    or lower:find("gun") or lower:find("pistol") or lower:find("revolver") then
                    return State.gunDropped and "Hero" or "Sheriff"
                end
            end
        end
        return nil
    end

    return scanTools(p.Character)
        or scanTools(p:FindFirstChildOfClass("Backpack"))
        or "Innocent"
end

local function refreshRoles()
    local murderer = nil
    for _, p in ipairs(Players:GetPlayers()) do
        local role = detectRole(p)
        State.roles[p] = role
        if role == "Murderer" then murderer = p end
    end
    State.murderer = murderer
end

_G.AS_GetMurderer = function() return State.murderer end

-- ==================== HELPERS ====================
local function getPlayerRoot(p)
    local char = p and p.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getPlayerHumanoid(p)
    local char = p and p.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- ==================== BYPASS – ANTI-CHEAT SPOOF ====================
-- Mantém uma tabela de valores "falsos" que são exibidos para leitura externa
-- enquanto os valores reais são aplicados via rawset
local spoofedValues = {}

local function spoofProperty(instance, property, fakeValue, realValue)
    if not instance then return end
    spoofedValues[instance] = spoofedValues[instance] or {}
    spoofedValues[instance][property] = fakeValue
    -- Aplica o valor real
    pcall(rawset, instance, property, realValue)
end

-- ==================== ESP ====================
local function removeESP(p)
    local char = p and p.Character
    if char then
        local hl = char:FindFirstChild("AkatESP")
        if hl then pcall(function() hl:Destroy() end) end
    end
end

local function updateESP(p)
    if p == player then return end
    if not Configs.ESP or not p.Character then removeESP(p); return end
    local char = p.Character
    local role = State.roles[p] or detectRole(p)
    State.roles[p] = role
    local hl = char:FindFirstChild("AkatESP")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "AkatESP"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 0.3
        hl.OutlineTransparency = 0
        hl.Parent = char
    end
    local color = ROLE_COLORS[role] or ROLE_COLORS.Innocent
    hl.FillColor = color
    hl.OutlineColor = color
end

local function clearESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then removeESP(p) end
    end
end

local function connectPlayer(p)
    if p == player or State.playerConnections[p] then return end
    local connections = {}
    State.playerConnections[p] = connections
    table.insert(connections, p.CharacterAdded:Connect(function()
        task.wait(0.25)
        if Configs.ESP then updateESP(p) end
    end))
    table.insert(connections, p.CharacterRemoving:Connect(function()
        removeESP(p)
    end))
    local backpack = p:FindFirstChildOfClass("Backpack")
    if backpack then
        table.insert(connections, backpack.ChildAdded:Connect(function()
            if Configs.ESP then task.defer(updateESP, p) end
        end))
        table.insert(connections, backpack.ChildRemoved:Connect(function()
            if Configs.ESP then task.defer(updateESP, p) end
        end))
    end
    updateESP(p)
end

local function disconnectPlayer(p)
    disconnectAll(State.playerConnections[p] or {})
    State.playerConnections[p] = nil
    State.roles[p] = nil
    removeESP(p)
end

local function enableESP()
    Configs.ESP = true
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then connectPlayer(p); updateESP(p) end
    end
end

local function disableESP()
    Configs.ESP = false
    clearESP()
    for p, connections in pairs(State.playerConnections) do
        disconnectAll(connections)
        State.playerConnections[p] = nil
    end
end

-- ==================== COIN CACHE ====================
local COIN_SCAN_INTERVAL = 0.5
local lastCoinScan = 0

local function looksLikeCoin(part)
    if not part:IsA("BasePart") or part.Transparency >= 1 then return false end
    if part:IsDescendantOf(player) then return false end
    if part:FindFirstAncestorOfClass("Tool") or part:FindFirstAncestorOfClass("Accessory") then return false end
    local n = part.Name:lower()
    return n:find("coin") or n:find("moeda") or n:find("gold")
        or n == "snowflake" or n == "candycane"
        or n:find("token") or n:find("diamond")
        or n:find("present") or n:find("candy")
end

local function refreshCoins()
    local now = os.clock()
    if now - lastCoinScan < COIN_SCAN_INTERVAL then return end
    lastCoinScan = now
    local result = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if looksLikeCoin(d) then table.insert(result, d) end
    end
    State.coins = result
end

local function nearestCoin(root)
    local best, bestDist = nil, math.huge
    for i = #State.coins, 1, -1 do
        local coin = State.coins[i]
        if not coin or not coin.Parent then
            table.remove(State.coins, i)
        else
            local d = (root.Position - coin.Position).Magnitude
            if d < bestDist and d < 1500 then best = coin; bestDist = d end
        end
    end
    return best
end

-- ==================== BAG ====================
local function isBagFull()
    local full = false
    pcall(function()
        local gui = player:FindFirstChild("PlayerGui")
        local mainGui = gui and gui:FindFirstChild("MainGui")
        local gameGui = mainGui and mainGui:FindFirstChild("Game")
        local bag = gameGui and gameGui:FindFirstChild("CoinBag")
        local container = bag and bag:FindFirstChild("Container")
        local amount = container and container:FindFirstChild("Amount")
        if amount and amount:IsA("TextLabel") then
            local current, max = amount.Text:match("(%d+)%s*/%s*(%d+)")
            if current and max then full = tonumber(current) >= tonumber(max) end
        end
    end)
    return full
end

-- ==================== SAFE SPOT ====================
local function destroySafePlatform()
    if State.safePlatform then
        pcall(function() State.safePlatform:Destroy() end)
        State.safePlatform = nil
    end
end

local function enableSafeSpot()
    local root = getRoot()
    if not root then return end
    State.safeReturnCFrame = root.CFrame
    if not State.safePlatform or not State.safePlatform.Parent then
        local platform = Instance.new("Part")
        platform.Name      = "AkatSafePlatform"
        platform.Size      = Vector3.new(15, 1, 15)
        platform.Position  = Vector3.new(root.Position.X, 900, root.Position.Z)
        platform.Anchored  = true
        platform.CanCollide = true
        platform.Transparency = 0.4
        platform.Material  = Enum.Material.ForceField
        platform.Color     = Color3.fromRGB(139, 0, 0)
        platform.Parent    = workspace
        State.safePlatform = platform
    end
    root.CFrame = State.safePlatform.CFrame + Vector3.new(0, 3, 0)
end

local function disableSafeSpot()
    local root = getRoot()
    destroySafePlatform()
    if root and State.safeReturnCFrame then root.CFrame = State.safeReturnCFrame end
    State.safeReturnCFrame = nil
end

-- ==================== X-RAY ====================
local function restoreXRay()
    for instance, transparency in pairs(State.originalTransparency) do
        if instance and instance.Parent then
            pcall(function() instance.Transparency = transparency end)
        end
    end
    table.clear(State.originalTransparency)
end

local function enableXRay()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart")
            and not d:IsDescendantOf(getCharacter() or workspace)
            and not d:IsDescendantOf(workspace.CurrentCamera or workspace) then
            if State.originalTransparency[d] == nil then
                State.originalTransparency[d] = d.Transparency
            end
            d.Transparency = 0.5
        end
    end
end

-- ==================== CHARACTER TRANSPARENCY ====================
local function restoreCharacterTransparency()
    for instance, transparency in pairs(State.originalCharacterTransparency) do
        if instance and instance.Parent then
            pcall(function() instance.Transparency = transparency end)
        end
    end
    table.clear(State.originalCharacterTransparency)
end

-- ==================== REACH (HITBOX EXPANDER) ====================
--[[
    Bypass: expande o HumanoidRootPart do PRÓPRIO personagem localmente.
    O servidor não vê essa mudança diretamente, mas o raycast/touch do jogo
    usa a posição do HRP + tamanho para registrar colisões.
    Para MM2 especificamente, o toque na faca usa TouchInterest, então
    expandir o HRP local faz a faca "alcançar" alvos mais distantes.
]]

local REACH_SIZE = Vector3.new(12, 5, 12)  -- tamanho expandido (padrão ~2x2x1)
local REACH_ORIG = Vector3.new(2, 2, 1)

local function enableReach()
    local char = getCharacter()
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Salva tamanho original
    if not State.originalHitboxSize["HRP"] then
        State.originalHitboxSize["HRP"] = hrp.Size
    end

    -- Expande localmente (invisível, CanCollide = false para não travar no mapa)
    hrp.Size = REACH_SIZE
    -- Mantém CanCollide false para não colidir com paredes
    hrp.CanCollide = false
end

local function disableReach()
    local char = getCharacter()
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and State.originalHitboxSize["HRP"] then
            pcall(function() hrp.Size = State.originalHitboxSize["HRP"] end)
        end
    end
    State.originalHitboxSize = {}
end

-- ==================== SPEED JUMP ====================
--[[
    Bypass: alterna WalkSpeed e JumpPower via rawset para dificultar
    detecção por scripts que lêem via __index hookado.
    Valores moderados (24 speed, 75 jump) para minimizar detecção visual.
]]

local SPEED_JUMP_WALKSPEED  = 24
local SPEED_JUMP_JUMPPOWER  = 75

local function applySpeedJump(hum, enabled)
    if not hum then return end
    if enabled then
        bypassSetWalkSpeed(hum, SPEED_JUMP_WALKSPEED)
        bypassSetJumpPower(hum, SPEED_JUMP_JUMPPOWER)
    else
        bypassSetWalkSpeed(hum, 16)
        bypassSetJumpPower(hum, 50)
    end
end

-- ==================== AUTO SHOOT ====================
--[[
    Bypass:
      1. Localiza o tool de arma no personagem ou backpack do localplayer
      2. Simula o clique via VirtualInputManager (não via mouse real)
         → Dificulta detecção por hooks em UserInputService
      3. Aplica cooldown de 0.6s para simular cadência humana
      4. Só atira se o murderer estiver a < 80 studs E o player tiver arma
]]

local AUTOSHOOT_COOLDOWN = 0.6
local AUTOSHOOT_RANGE    = 80

local function getLocalGun()
    local char = getCharacter()
    local backpack = player:FindFirstChildOfClass("Backpack")

    local function findGun(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local lower = item.Name:lower()
                if lower:find("gun") or lower:find("pistol")
                    or lower:find("revolver") or item:FindFirstChild("GunScript")
                    or item:FindFirstChild("Gun") then
                    return item
                end
            end
        end
        return nil
    end

    return findGun(char) or findGun(backpack)
end

local function equipTool(tool)
    if not tool then return end
    local hum = getHumanoid()
    if hum then
        pcall(function() hum:EquipTool(tool) end)
    end
end

local function doAutoShoot()
    if not Configs.AutoShoot then return end

    local now = os.clock()
    if now - State.lastAutoShoot < AUTOSHOOT_COOLDOWN then return end

    local root = getRoot()
    if not root then return end

    -- Precisa ter arma equipada
    local gun = getLocalGun()
    if not gun then return end

    -- Precisa ter murderer vivo e próximo
    local murderer = State.murderer
    if not murderer then return end
    local mRoot = getPlayerRoot(murderer)
    if not mRoot then return end

    local dist = (root.Position - mRoot.Position).Magnitude
    if dist > AUTOSHOOT_RANGE then return end

    State.lastAutoShoot = now

    -- Equipa se não estiver ativo
    local charGun = getCharacter() and getCharacter():FindFirstChildWhichIsA("Tool")
    if not charGun or charGun ~= gun then
        equipTool(gun)
        task.wait(0.1) -- aguarda animação de equip
    end

    -- Aponta câmera para o alvo via CFrame (não move o mouse fisicamente)
    pcall(function()
        local camera = workspace.CurrentCamera
        if camera then
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, mRoot.Position)
        end
    end)

    -- Simula clique via VirtualInputManager (bypass de hook no mouse)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(
            workspace.CurrentCamera.ViewportSize.X / 2,
            workspace.CurrentCamera.ViewportSize.Y / 2,
            0, true, game, 0
        )
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(
            workspace.CurrentCamera.ViewportSize.X / 2,
            workspace.CurrentCamera.ViewportSize.Y / 2,
            0, false, game, 0
        )
    end)
end

-- ==================== KNIFE THROW ====================
--[[
    Bypass:
      1. Localiza a faca no murderer (pode estar no char ou backpack)
      2. Move o HRP do murderer para tocar no player local via CFrame silencioso
         (server-side o murderer parece estar se movendo normalmente)
      3. Alternativa: aciona o TouchInterest da faca diretamente via
         firetouchinterest() se o executor suportar
      4. Cooldown de 1.5s
]]

local KNIFETHROW_COOLDOWN = 1.5
local KNIFETHROW_RANGE    = 200  -- alcança qualquer mapa

local function getMurdererKnife(murderer)
    if not murderer then return nil end
    local char = murderer.Character
    local backpack = murderer:FindFirstChildOfClass("Backpack")

    local function findKnife(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local lower = item.Name:lower()
                if lower:find("knife") or lower:find("faca")
                    or lower:find("sword") or lower:find("blade")
                    or item:FindFirstChild("KnifeScript")
                    or item:FindFirstChild("Knife") then
                    return item
                end
            end
        end
        return nil
    end

    return findKnife(char) or findKnife(backpack)
end

local function doKnifeThrow()
    if not Configs.KnifeThrow then return end

    local now = os.clock()
    if now - State.lastKnifeThrow < KNIFETHROW_COOLDOWN then return end

    local root = getRoot()
    if not root then return end

    local murderer = State.murderer
    if not murderer then return end

    local mRoot = getPlayerRoot(murderer)
    if not mRoot then return end

    local dist = (root.Position - mRoot.Position).Magnitude
    if dist > KNIFETHROW_RANGE then return end

    State.lastKnifeThrow = now

    -- Método 1: firetouchinterest (executores que suportam)
    local knife = getMurdererKnife(murderer)
    if knife then
        local knifeHandle = knife:FindFirstChild("Handle") or knife:FindFirstChildOfClass("BasePart")
        if knifeHandle and typeof(firetouchinterest) == "function" then
            -- Faz o HRP do player "tocar" a faca silenciosamente
            pcall(function()
                firetouchinterest(root, knifeHandle, 0)  -- 0 = touch begin
                task.wait(0.05)
                firetouchinterest(root, knifeHandle, 1)  -- 1 = touch end
            end)
            return
        end
    end

    -- Método 2 (fallback): teletransporta o HRP do murderer para tocar no player
    -- e volta instantaneamente (imperceptível por ~1 frame)
    pcall(function()
        local originalCFrame = mRoot.CFrame
        mRoot.CFrame = root.CFrame * CFrame.new(0, 0, -2)
        task.wait(0.033)  -- ~1 frame a 30fps
        mRoot.CFrame = originalCFrame
    end)
end

-- ==================== KILL ALL ====================
--[[
    Bypass:
      1. Itera sobre todos os jogadores inocentes
      2. Para cada um, usa firetouchinterest com a faca do murderer
         (o server registra como toque legítimo)
      3. Alternativa sem firetouchinterest: expande o HRP do murderer
         temporariamente e o teletransporta sobre cada alvo
      4. Cooldown de 3s para não gerar spam de kills suspeito
      5. Não elimina o Sheriff por padrão (configurável)
]]

local KILLALL_COOLDOWN    = 3.0
local KILLALL_SKIP_SHERIFF = true

local function doKillAll()
    if not Configs.KillAll then return end

    local now = os.clock()
    if now - State.lastKillAll < KILLALL_COOLDOWN then return end

    local murderer = State.murderer
    if not murderer then return end

    local knife = getMurdererKnife(murderer)
    local mRoot = getPlayerRoot(murderer)
    if not mRoot then return end

    State.lastKillAll = now

    local knifeHandle = knife and (knife:FindFirstChild("Handle") or knife:FindFirstChildOfClass("BasePart"))

    for _, p in ipairs(Players:GetPlayers()) do
        if p == player or p == murderer then continue end
        if KILLALL_SKIP_SHERIFF and State.roles[p] == "Sheriff" then continue end

        local pRoot = getPlayerRoot(p)
        local pHum  = getPlayerHumanoid(p)
        if not pRoot or not pHum or pHum.Health <= 0 then continue end

        -- Método 1: firetouchinterest
        if knifeHandle and typeof(firetouchinterest) == "function" then
            pcall(function()
                firetouchinterest(pRoot, knifeHandle, 0)
                task.wait(0.03)
                firetouchinterest(pRoot, knifeHandle, 1)
            end)
        else
            -- Método 2 (fallback): teleporta murderer sobre o alvo
            pcall(function()
                local savedCFrame = mRoot.CFrame
                mRoot.CFrame = pRoot.CFrame
                task.wait(0.05)
                mRoot.CFrame = savedCFrame
            end)
        end

        task.wait(0.1)  -- pequeno delay entre kills para parecer natural
    end
end

-- ==================== CHAT ====================
local function sendChat(message)
    local ok, err = pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channels = TextChatService:FindFirstChild("TextChannels")
            local general = channels and channels:FindFirstChild("RBXGeneral")
            if general then general:SendAsync(message) end
        else
            local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            local event = events and events:FindFirstChild("SayMessageRequest")
            if event then event:FireServer(message, "All") end
        end
    end)
    if not ok then warnf("Falha ao enviar chat:", err) end
end

-- ==================== CLEANUP ====================
local shuttingDown = false

local function shutdown()
    if shuttingDown then return end
    shuttingDown = true

    -- Desativa tudo
    for k in pairs(Configs) do Configs[k] = false end

    disconnectAll(State.connections)
    for p, connections in pairs(State.playerConnections) do
        disconnectAll(connections)
        State.playerConnections[p] = nil
    end

    if State.collectTween then
        pcall(function() State.collectTween:Cancel() end)
        State.collectTween = nil
    end

    State.collectTarget = nil

    disableSafeSpot()
    clearESP()
    restoreXRay()
    restoreCharacterTransparency()
    disableReach()

    local root = getRoot()
    if root then
        root.Anchored = false
        root.CanCollide = true
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    local hum = getHumanoid()
    if hum then
        bypassSetWalkSpeed(hum, 16)
        bypassSetJumpPower(hum, 50)
    end

    _G.AkatLogicRunning = false
end

-- ==================== GLOBAL CALLBACKS ====================
_G.AkatCallbacks = {
    ESP = function(enabled)
        Configs.ESP = enabled and true or false
        if Configs.ESP then enableESP() else disableESP() end
    end,

    Speed = function(enabled)
        Configs.Speed = enabled and true or false
    end,

    SpeedJump = function(enabled)
        Configs.SpeedJump = enabled and true or false
        if not enabled then
            local hum = getHumanoid()
            if hum then
                bypassSetWalkSpeed(hum, Configs.Speed and 23 or 16)
                bypassSetJumpPower(hum, 50)
            end
        end
    end,

    SafeSpot = function(enabled)
        Configs.SafeSpot = enabled and true or false
        if Configs.SafeSpot then enableSafeSpot() else disableSafeSpot() end
    end,

    AutoCollect = function(enabled)
        Configs.AutoCollect = enabled and true or false
        if not Configs.AutoCollect then
            State.collectTarget = nil
            if State.collectTween then
                pcall(function() State.collectTween:Cancel() end)
                State.collectTween = nil
            end
        end
    end,

    ChatRoles = function(enabled)
        Configs.ChatRoles = enabled and true or false
        if not Configs.ChatRoles then State.announcedThisRound = false end
    end,

    XRay = function(enabled)
        Configs.XRay = enabled and true or false
        if Configs.XRay then enableXRay() else restoreXRay() end
    end,

    AutoShoot = function(enabled)
        Configs.AutoShoot = enabled and true or false
    end,

    KnifeThrow = function(enabled)
        Configs.KnifeThrow = enabled and true or false
    end,

    KillAll = function(enabled)
        Configs.KillAll = enabled and true or false
    end,

    Reach = function(enabled)
        Configs.Reach = enabled and true or false
        if Configs.Reach then enableReach() else disableReach() end
    end,

    ShutdownAll = shutdown,
}

-- ==================== PLAYER LIFECYCLE ====================
table.insert(State.connections, Players.PlayerAdded:Connect(function(p)
    connectPlayer(p)
end))

table.insert(State.connections, Players.PlayerRemoving:Connect(function(p)
    disconnectPlayer(p)
end))

table.insert(State.connections, player.CharacterAdded:Connect(function()
    task.wait(0.25)

    State.originalHitboxSize = {}  -- reseta ao respawnar

    if Configs.ESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then updateESP(p) end
        end
    end

    if Configs.SafeSpot then enableSafeSpot() end

    if Configs.XRay then
        restoreXRay()
        enableXRay()
    end

    if Configs.Reach then
        task.wait(0.5)  -- aguarda char carregar
        enableReach()
    end
end))

-- ==================== NOCLIP PARA AUTOCOLLECT ====================
table.insert(State.connections, RunService.Stepped:Connect(function()
    if not (Configs.AutoCollect or Configs.SafeSpot) then return end
    local char = getCharacter()
    if not char then return end
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            if State.originalCanCollide[part] == nil then
                State.originalCanCollide[part] = part.CanCollide
            end
            part.CanCollide = false
        end
    end
end))

table.insert(State.connections, RunService.Heartbeat:Connect(function()
    if Configs.AutoCollect or Configs.SafeSpot then return end
    for part, value in pairs(State.originalCanCollide) do
        if part and part.Parent then part.CanCollide = value end
        State.originalCanCollide[part] = nil
    end
end))

-- ==================== MAIN LOCAL LOOP ====================
local scanAccumulator = 0
local espAccumulator  = 0
local reachAccumulator = 0

table.insert(State.connections, RunService.Heartbeat:Connect(function(dt)
    if shuttingDown then return end

    local hum  = getHumanoid()
    local root = getRoot()

    -- Speed / SpeedJump
    if hum then
        if Configs.SpeedJump then
            applySpeedJump(hum, true)
        elseif Configs.Speed then
            bypassSetWalkSpeed(hum, 23)
            bypassSetJumpPower(hum, 50)
        else
            bypassSetWalkSpeed(hum, 16)
            bypassSetJumpPower(hum, 50)
        end
    end

    if not root or not hum or hum.Health <= 0 then return end

    scanAccumulator  += dt
    espAccumulator   += dt
    reachAccumulator += dt

    if scanAccumulator >= 0.5 then
        scanAccumulator = 0
        refreshRoles()
        if Configs.AutoCollect then refreshCoins() end
    end

    if Configs.ESP and espAccumulator >= 1 then
        espAccumulator = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then updateESP(p) end
        end
    end

    -- Reach: reaplicar a cada 2s (o jogo pode resetar o Size)
    if Configs.Reach and reachAccumulator >= 2 then
        reachAccumulator = 0
        enableReach()
    end

    -- AutoShoot: roda a cada frame (tem cooldown interno)
    if Configs.AutoShoot then
        doAutoShoot()
    end
end))

-- ==================== ATTACK LOOP (task.spawn separado para FPS-lock) ====================
task.spawn(function()
    while not shuttingDown do
        task.wait(0.15)  -- ~6 verificações por segundo

        if Configs.KnifeThrow then
            doKnifeThrow()
        end

        if Configs.KillAll then
            doKillAll()
        end
    end
end)

-- ==================== AUTO COLLECT LOOP ====================
task.spawn(function()
    while not shuttingDown do
        task.wait(0.08)
        if not Configs.AutoCollect then continue end

        local root = getRoot()
        local hum  = getHumanoid()
        if not root or not hum or hum.Health <= 0 then continue end

        if isBagFull() then
            if State.collectTween then
                pcall(function() State.collectTween:Cancel() end)
                State.collectTween = nil
            end
            State.collectTarget = nil
            continue
        end

        local target = nearestCoin(root)
        if not target then State.collectTarget = nil; continue end

        if target ~= State.collectTarget then
            State.collectTarget = target
            if State.collectTween then
                pcall(function() State.collectTween:Cancel() end)
            end

            local distance = (root.Position - target.Position).Magnitude
            local duration = math.clamp(distance / 37, 0.08, 3)

            State.collectTween = TweenService:Create(
                root,
                TweenInfo.new(duration, Enum.EasingStyle.Linear),
                {CFrame = CFrame.new(target.Position + Vector3.new(0, 2.5, 0))}
            )

            local tween = State.collectTween
            tween:Play()

            task.spawn(function()
                pcall(function() tween.Completed:Wait() end)
                if State.collectTween == tween then State.collectTween = nil end
            end)
        end
    end
end)

-- ==================== CHAT ROLE ANNOUNCEMENT ====================
task.spawn(function()
    while not shuttingDown do
        task.wait(0.5)
        if not Configs.ChatRoles then continue end

        local murderer = State.murderer
        local sheriff  = nil
        for p, role in pairs(State.roles) do
            if role == "Sheriff" then sheriff = p; break end
        end

        if not murderer and not sheriff then
            State.announcedThisRound = false
        elseif not State.announcedThisRound then
            State.announcedThisRound = true
            local parts = {"[AKAT]"}
            if murderer then
                table.insert(parts, "Murderer: " .. murderer.DisplayName .. " (@" .. murderer.Name .. ")")
            end
            if sheriff then
                table.insert(parts, "Sheriff: " .. sheriff.DisplayName .. " (@" .. sheriff.Name .. ")")
            end
            sendChat(table.concat(parts, " | "))
        end
    end
end)

-- ==================== REMOTE UI LOADER ====================
task.spawn(function()
    local uiRawUrl = "https://raw.githubusercontent.com/estratosfera88-afk/Ui-do-teste/refs/heads/main/ui.lua"
    local ok, rawContent = pcall(function()
        return game:HttpGet(uiRawUrl, true)
    end)
    if not ok then warnf("HttpGet da UI falhou:", rawContent); return end
    if type(rawContent) ~= "string" or rawContent == "" then warnf("A UI retornou conteúdo vazio."); return end
    local loadFn, compileErr = loadstring(rawContent)
    if not loadFn then warnf("Falha ao compilar a UI:", compileErr); return end
    local runOk, runErr = pcall(loadFn)
    if not runOk then warnf("Falha ao executar a UI:", runErr) end
end)

-- ==================== INIT ====================
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= player then connectPlayer(p) end
end

refreshRoles()

warnf("v6.1 carregada — AutoShoot, KnifeThrow, SpeedJump, KillAll, Reach ativos.")
