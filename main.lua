-- [[
--     AKAT MM2 MAIN LOGIC [v6.7 - MELHORIAS VISUAIS + AUTOSHOOT]
--     Compatível com Delta Mobile & PC | MM2 (2026)
--     BACKEND ONLY — sem código de interface visual
--
--     MELHORIAS v6.7 (sobre v6.6):
--     - AutoShoot: Reescrito para garantir que a bala saia da arma em direção
--       ao murder. O personagem gira para encarar o alvo, equipa a arma,
--       seta o mouse.Hit via hook para apontar à cabeça e dispara via
--       gun:Activate(). Cooldown ajustado e lógica de fallback mais robusta.
--     - Tracer ESP: Transparência reduzida de 0.15 para 0.0 (totalmente opaco),
--       largura aumentada para traçadores mais visíveis.
--     - View Reach: Cápsula removida. Substituída por SelectionSphere simples
--       usando um BallHandleAdornment no próprio HumanoidRootPart do jogador.
--       Sem welds, sem parts extras, sem bug de rotação. Raio = ReachValue.
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
    ReachValue     = 5,
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
local UpdateReachSphere
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

-- ==================== FIX v6.7: VIEW REACH — ESFERA SIMPLES (SEM BUG) ====================
-- BallHandleAdornment diretamente no HumanoidRootPart do próprio jogador.
-- Sem Parts extras, sem Welds, sem Model auxiliar.
-- Isso elimina completamente o bug de rotação/torção da cápsula anterior.
-- O raio da esfera = ReachValue (alcance real da faca).

local ReachSphere = nil   -- BallHandleAdornment

local function DestroyReachSphere()
    if ReachSphere and ReachSphere.Parent then
        pcall(function() ReachSphere:Destroy() end)
    end
    ReachSphere = nil
end

UpdateReachSphere = function()
    if not Configs.ViewReach then
        DestroyReachSphere()
        return
    end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        DestroyReachSphere()
        return
    end

    local reach  = math.max(1, Configs.ReachValue or 18)

    -- Se já existe e está no root correto, só atualiza o raio
    if ReachSphere and ReachSphere.Parent == root then
        ReachSphere.Radius = reach
        return
    end

    -- Recria do zero
    DestroyReachSphere()

    local sphere              = Instance.new("SphereHandleAdornment")
    sphere.Name               = "AkatReachSphere"
    sphere.Adornee            = root
    sphere.Radius             = reach
    sphere.Color3             = Color3.fromRGB(220, 0, 0)
    sphere.Transparency       = 0.60      -- visível mas não intrusivo
    sphere.AlwaysOnTop        = false     -- respeita oclusão do mundo
    sphere.ZIndex             = 1
    sphere.Parent             = root

    ReachSphere = sphere
end

-- ==================== NAME / TRACER (v6.7: TRACER MAIS FORTE) ====================
local function GetRoleColor(p)
    local role = ESP_DetectRole(p)
    PlayerRoles[p] = role
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

-- FIX v6.7: TRACER MAIS FORTE
-- Transparência: 0.0 (100% opaco)
-- Largura: mais grossa para maior visibilidade
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

        local beam              = Instance.new("Beam")
        beam.Name               = "AkatTracer"
        beam.Attachment0        = a
        beam.Attachment1        = b
        beam.FaceCamera         = true
        beam.LightEmission      = 1        -- brilho para destacar mais
        beam.LightInfluence     = 0        -- não afetado por sombras
        -- Transparência ZERO = totalmente opaco
        beam.Transparency       = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.0),
            NumberSequenceKeypoint.new(0.5, 0.0),
            NumberSequenceKeypoint.new(1,   0.0),
        })
        beam.Width0             = 0.12     -- largura inicial (pé do beam)
        beam.Width1             = 0.06     -- largura final (alvo)
        beam.Parent             = myRoot

        data        = {a = a, b = b, beam = beam}
        Tracers[p]  = data
    end

    data.beam.Color = ColorSequence.new(color)

    -- Ajusta a largura proporcionalmente à distância (mantém visível à distância)
    local d = (myRoot.Position - targetRoot.Position).Magnitude
    local w = math.clamp(0.14 - d * 0.00008, 0.04, 0.14)
    data.beam.Width0 = w
    data.beam.Width1 = w * 0.5
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
    DestroyReachSphere()
end

-- ==================== AUTO SHOOT / SHOOT MURDER ====================
-- Baseado diretamente no método funcional do Shoot Murder fornecido.
-- O tiro usa Gun.Shoot + GunRaycastAttachment e envia o CFrame de origem
-- e o CFrame previsto do Murderer. Não depende de mouse.Hit, câmera ou Activate().

local autoShootBusy       = false
local autoShootRunning    = false
local lastAutoShot        = 0
local AUTO_SHOOT_COOLDOWN = 0.35
local AUTO_SHOOT_INTERVAL = 0.06
local AUTO_SHOOT_PREDICTION = 0.15

local function AutoShoot_FindGun()
    local char = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not char then return nil end

    -- Prioridade absoluta para a Tool chamada Gun, igual ao Shoot Murder funcional.
    local gun = char:FindFirstChild("Gun")
    if gun and gun:IsA("Tool") then
        return gun
    end

    if backpack then
        gun = backpack:FindFirstChild("Gun")
        if gun and gun:IsA("Tool") then
            return gun
        end
    end

    -- Fallback apenas para nomes equivalentes, sem escolher qualquer Tool aleatória.
    local function findNamedGun(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local n = item.Name:lower()
                if n == "gun" or n:find("sheriff") or n:find("revolver") or n:find("pistol") then
                    return item
                end
            end
        end
        return nil
    end

    return findNamedGun(char) or findNamedGun(backpack)
end

-- Mesmo detector do Shoot Murder funcional: Knife no Character ou Backpack.
local function AutoShoot_GetMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local char = plr.Character
            local backpack = plr:FindFirstChildOfClass("Backpack")
            local knife = (char and char:FindFirstChild("Knife"))
                or (backpack and backpack:FindFirstChild("Knife"))

            if knife and char and char:FindFirstChild("HumanoidRootPart") then
                return plr
            end
        end
    end

    return nil
end

-- Disparo copiado/adaptado do Shoot Murder que funciona:
-- Gun.Shoot:FireServer(GunRaycastAttachment.WorldCFrame, CFrame.new(predictedPosition))
local function ShootMurdererOnce()
    local char = player.Character
    if not char then return false end

    local gun = AutoShoot_FindGun()
    if not gun then
        DebugLog("AutoShoot", "Gun não encontrada")
        return false
    end

    -- O script funcional coloca a Gun diretamente no Character.
    if gun.Parent ~= char then
        pcall(function()
            gun.Parent = char
        end)
        task.wait(0.05)
    end

    if gun.Parent ~= char then
        DebugLog("AutoShoot", "Não foi possível equipar Gun")
        return false
    end

    local shoot = gun:FindFirstChild("Shoot")
    if not shoot or not shoot:IsA("RemoteEvent") then
        DebugLog("AutoShoot", "Gun.Shoot não encontrado")
        return false
    end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local attachment = root:FindFirstChild("GunRaycastAttachment")
    if not attachment or not attachment:IsA("Attachment") then
        DebugLog("AutoShoot", "GunRaycastAttachment não encontrado")
        return false
    end

    local murderer = AutoShoot_GetMurderer()
    if not murderer or not murderer.Character then
        DebugLog("AutoShoot", "Murderer não encontrado")
        return false
    end

    local mroot = murderer.Character:FindFirstChild("HumanoidRootPart")
    local mhum = murderer.Character:FindFirstChildOfClass("Humanoid")
    if not mroot or (mhum and mhum.Health <= 0) then
        return false
    end

    local velocity = mroot.AssemblyLinearVelocity or Vector3.zero
    if velocity.Magnitude > 100 then
        velocity = Vector3.zero
    end

    local predictedPosition = mroot.Position + velocity * AUTO_SHOOT_PREDICTION

    local ok, err = pcall(function()
        shoot:FireServer(
            attachment.WorldCFrame,
            CFrame.new(predictedPosition)
        )
    end)

    if ok then
        lastAutoShot = tick()
        DebugLog("AutoShoot", "Shoot Murder enviado para " .. murderer.Name)
        return true
    end

    DebugLog("AutoShoot", "Falha no Shoot: " .. tostring(err))
    return false
end

-- Wrapper usado pelo Auto Shoot automático e pelo botão flutuante.
-- O botão chama esta função diretamente; portanto não precisa depender de Activate().
local function ExecuteAutoShootOnce(force)
    if autoShootBusy or not scriptAlive then
        return false
    end

    -- O botão flutuante pode disparar mesmo quando a rotina automática está parada.
    if not force and not Configs.AutoShoot then
        return false
    end

    local now = tick()
    if now - lastAutoShot < AUTO_SHOOT_COOLDOWN then
        return false
    end

    autoShootBusy = true
    local fired = false

    local ok, err = pcall(function()
        fired = ShootMurdererOnce()
    end)

    if not ok then
        DebugLog("AutoShoot", "Erro: " .. tostring(err))
    end

    autoShootBusy = false
    autoShootFiring = false
    return fired
end

-- Auto Shoot é somente o estado que habilita o botão flutuante.
-- NÃO existe loop automático: cada tiro acontece exclusivamente quando
-- o usuário toca/clica no botão flutuante AUTO SHOOT.
local function ToggleAutoShoot(enabled)
    Configs.AutoShoot = enabled and true or false
    autoShootFiring   = false
    autoShootRunning  = false
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
            DestroyReachSphere()
        else
            UpdateReachSphere()
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
        -- Atualiza a esfera imediatamente ao mudar o valor
        if Configs.ViewReach then UpdateReachSphere() end
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

    TpMurder = function(enabled)
        Configs.TpMurder = false
        if not enabled then return false end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return false end

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
        return ExecuteAutoShootOnce(true)
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

        -- Reconstrói visuais ausentes e força atualização de cor
        if Configs.Name or Configs.Tracer or Configs.ViewReach then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    if Configs.Name   then UpdateName(p)    end
                    if Configs.Tracer then UpdateTracer(p)  end
                    if Configs.ViewReach and not ReachBoxes[p] then UpdateReachBox(p) end
                end
            end
            -- Atualiza raio da esfera se o reach mudou
            if Configs.ViewReach then UpdateReachSphere() end
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
        if Configs.ViewReach then UpdateReachSphere() end
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
                UpdateReachSphere()
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
