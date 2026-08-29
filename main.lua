-- [[
--     AKAT MM2 MAIN LOGIC [v6.4 - BUGS CORRIGIDOS]
--     Compatível com Delta Mobile & PC | MM2 (2026)
--     BACKEND ONLY — sem código de interface visual
--
--     CORREÇÕES v6.4:
--     - Forward declarations de UpdateName/UpdateTracer/UpdateReachBox/RemoveVisual
--       (causa raiz de "attempt to call a nil value")
--     - Flag scriptAlive para parar todos os loops após ShutdownAll
--     - Invisibility salva/restaura transparências originais
--     - AntiFling não seta CanCollide de outros jogadores; restaura o próprio ao desligar
--     - ReachCircle posicionado via HipHeight (funciona em qualquer rig)
--     - PlayerAdded/PlayerRemoving globais únicos (sem duplicação com ESP_Enable)
--     - XRay: usa table.clear após iteração (sem remoção durante pairs)
--     - ShutdownAll restaura corretamente: transparência, CanCollide, velocidade, XRay
--     - AutoCollect: wait de 0.005 → 0.08 (redução de CPU significativa)
--     - Reach movido do Heartbeat para thread dedicada com 0.1s de intervalo
--     - Reach busca faca por múltiplos nomes (não só "Knife"/"Faca")
--     - knifeThrowConnection removido (variável global morta/código morto)
--     - espCharConnections: evita acúmulo de conexões ChildAdded por respawn
--     - Configs.Debug adicionado
--     - characterConnection desconectado no ShutdownAll
--     - Aliases TpToGun delegam para a função principal (sem triplicação)
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
-- Todos os loops while verificam este flag para parar ao chamar ShutdownAll.
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
-- Tabela para salvar transparências originais antes de aplicar Invisibility.
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
    TpMap          = false,
    SafeSpot       = false,
    AutoFarm       = false,
    ChatRoles      = false,
    XRay           = false,
    KillAll        = false,
    Invisibility   = false,
    Debug          = false,   -- NOVO: ativa mensagens de diagnóstico no console
}
_G.Configs = Configs

-- ==================== FORWARD DECLARATIONS ====================
-- CRÍTICO: estas funções são referenciadas dentro de closures de ESP_ConnectPlayer
-- (que é declarado antes delas). Sem forward declaration, as closures capturam nil
-- e o script lança "attempt to call a nil value" quando os eventos disparam.
local UpdateName        -- function(p)
local UpdateTracer      -- function(p)
local UpdateReachBox    -- function(p)
local RemoveVisual      -- function(p)
local UpdateReachCircle -- function()
local EnviarMensagemChat -- function(msg)
local ESP_UpdatePlayer  -- function(p)

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
local espEventConnections   = {}  -- Conexões principais por jogador (CharacterAdded, CharacterRemoving, Backpack)
local espCharConnections    = {}  -- Conexões do char atual (ChildAdded/Removed) — separadas para evitar acúmulo
local hbConnection          = nil
local steppedConnection     = nil
local characterConnection   = nil
local globalPlayerAddedConn  = nil  -- Conexão global única para PlayerAdded
local globalPlayerRemovingConn = nil -- Conexão global única para PlayerRemoving
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

-- Implementação de ESP_UpdatePlayer (forward declared acima).
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

    -- Desconecta conexões principais antigas deste player.
    if espEventConnections[p] then
        for _, c in ipairs(espEventConnections[p]) do
            pcall(function() c:Disconnect() end)
        end
    end
    -- Desconecta conexões do char anterior.
    if espCharConnections[p] then
        for _, c in ipairs(espCharConnections[p]) do
            pcall(function() c:Disconnect() end)
        end
        espCharConnections[p] = nil
    end

    local conns = {}
    espEventConnections[p] = conns

    -- Conexão de CharacterAdded: reconstrói visuais a cada respawn.
    table.insert(conns, p.CharacterAdded:Connect(function(char)
        roundGeneration += 1

        -- Desconecta conexões do char ANTERIOR antes de criar novas.
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
        if Configs.Name      then UpdateName(p)       end   -- Forward declarations garantem que não são nil
        if Configs.Tracer    then UpdateTracer(p)     end
        if Configs.ViewReach then UpdateReachBox(p)   end

        -- Segunda passagem após cargos serem atribuídos pelo servidor.
        task.spawn(function()
            task.wait(0.55)
            if not scriptAlive or not p.Parent then return end
            PlayerRoles[p] = ESP_DetectRole(p)
            if Configs.ESP       then ESP_UpdatePlayer(p) end
            if Configs.Name      then UpdateName(p)       end
            if Configs.Tracer    then UpdateTracer(p)     end
            if Configs.ViewReach then UpdateReachBox(p)   end
        end)

        -- Monitora mudanças de ferramenta no char atual.
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

    -- Limpa visuais quando o personagem é removido.
    table.insert(conns, p.CharacterRemoving:Connect(function()
        RemoveVisual(p)   -- Forward declaration: segura aqui, a função já existe quando o evento dispara
        PlayerRoles[p] = nil
    end))

    -- Monitora mudanças na Backpack (pick-up de itens).
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

-- ESP_Enable/Disable gerenciam apenas os jogadores já presentes.
-- Jogadores novos são tratados pelos handlers globais únicos (definidos no final do script).
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
local NameTags  = {}
local Tracers   = {}
local ReachBoxes = {}
local ReachCircle = nil

-- Implementação de UpdateReachCircle (forward declared).
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
        ReachCircle             = Instance.new("CylinderHandleAdornment")
        ReachCircle.Name        = "AkatMyReachCircle"
        ReachCircle.AlwaysOnTop = true
        ReachCircle.Transparency = 0.72
        ReachCircle.Color3      = Color3.fromRGB(220, 0, 0)
        -- Height mínima cria um disco visual (não um cilindro em pé).
        -- O CylinderHandleAdornment alinha o eixo com o Y do adornee;
        -- como o HumanoidRootPart está em pé, o disco ficará horizontal.
        ReachCircle.Height      = 0.08
        ReachCircle.Parent      = char
    end

    ReachCircle.Adornee = root
    ReachCircle.Radius  = math.max(1, Configs.ReachValue or 18)

    -- Posiciona o disco nos pés usando HipHeight (funciona para qualquer rig).
    -- HipHeight = distância do centro do root até o chão (propriedade do Humanoid).
    local rootHalfH = root.Size.Y * 0.5
    local hipHeight = (hum and hum.HipHeight) or 2.2
    -- Offset relativo ao root: desce rootHalfH (base do root) + hipHeight (até o chão).
    -- Subtrai 0.05 para tocar levemente o chão em vez de flutuar.
    ReachCircle.CFrame = CFrame.new(0, -(rootHalfH + hipHeight - 0.05), 0)
end

-- Implementação de RemoveVisual (forward declared).
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

-- Implementação de UpdateName (forward declared).
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

    local role  = ESP_DetectRole(p)
    PlayerRoles[p] = role
    local color = ROLE_COLORS[role] or ROLE_COLORS.Innocent

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

-- Implementação de UpdateTracer (forward declared).
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

    local role  = ESP_DetectRole(p)
    PlayerRoles[p] = role
    local color = ROLE_COLORS[role] or ROLE_COLORS.Innocent

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

-- Implementação de UpdateReachBox (forward declared).
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

-- ==================== AUTO SHOOT ====================
local autoShootBusy       = false
local lastAutoShot        = 0
local AUTO_SHOOT_COOLDOWN = 0.20

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
    local murderer = CachedState.Murderer
    if not murderer or murderer == player or not murderer.Parent then
        murderer = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local role = ESP_DetectRole(p)
                PlayerRoles[p] = role
                if role == "Murderer" then murderer = p; break end
            end
        end
    end
    if not murderer or murderer == player or not murderer.Parent then return nil end

    local char = murderer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local head = char and char:FindFirstChild("Head")
    if not char or not hum or hum.Health <= 0 or not head then return nil end

    -- Revalida o cargo para evitar alvo obsoleto de rodada anterior.
    local freshRole = ESP_DetectRole(murderer)
    PlayerRoles[murderer] = freshRole
    if freshRole ~= "Murderer" then return nil end

    return murderer, head
end

local function ExecuteAutoShootOnce()
    if not Configs.AutoShoot or autoShootBusy then return false end

    local now = tick()
    if now - lastAutoShot < AUTO_SHOOT_COOLDOWN then return false end

    local murderer = AutoShoot_GetValidTarget()
    if not murderer then
        DebugLog("AutoShoot", "Nenhum alvo válido encontrado.")
        return false
    end

    local gun, hum = AutoShoot_FindGun()
    if not gun or not gun:IsA("Tool") or not hum or hum.Health <= 0 then
        DebugLog("AutoShoot", "Arma não encontrada ou personagem sem vida.")
        return false
    end

    autoShootBusy = true
    lastAutoShot  = now

    local ok, err = pcall(function()
        if gun.Parent ~= player.Character then
            hum:EquipTool(gun)
            task.wait(0.06)
        end

        if not Configs.AutoShoot or gun.Parent ~= player.Character then return end

        autoShootFiring = true
        -- gun:Activate() é o método mais confiável (mobile e PC, sem depender do cursor).
        local aktivOk, aktivErr = pcall(function() gun:Activate() end)
        if not aktivOk then DebugLog("AutoShoot", "Activate falhou: " .. tostring(aktivErr)) end
        task.wait(0.04)
        autoShootFiring = false
    end)

    autoShootFiring = false

    if not ok then
        DebugLog("AutoShoot", "Erro geral: " .. tostring(err))
    end

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

-- Implementação de EnviarMensagemChat (forward declared).
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

-- Restaura CanCollide no personagem local quando sistemas de noclip são desligados.
local function RestoreLocalCanCollide()
    -- Só restaura se NENHUM sistema que precisa de noclip ainda está ativo.
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

    -- Desconecta todas as conexões de RunService e eventos.
    if hbConnection         then hbConnection:Disconnect();         hbConnection         = nil end
    if steppedConnection    then steppedConnection:Disconnect();    steppedConnection    = nil end
    if characterConnection  then characterConnection:Disconnect();  characterConnection  = nil end
    if xrayDescendantConnection then xrayDescendantConnection:Disconnect(); xrayDescendantConnection = nil end
    if globalPlayerAddedConn    then globalPlayerAddedConn:Disconnect();    globalPlayerAddedConn    = nil end
    if globalPlayerRemovingConn then globalPlayerRemovingConn:Disconnect(); globalPlayerRemovingConn = nil end

    -- Reseta configs (preserva valores numéricos).
    for k, v in pairs(Configs) do
        if type(v) == "boolean" then Configs[k] = false end
    end
    autoFarmTemporarilyDisabled = false
    autoShootFiring             = false
    autoShootBusy               = false
    tpGunNoclip                 = false

    -- Desliga ESP e limpa visuais.
    ESP_Disable()
    Visuals_ClearAll()

    -- Remove SafeSpot.
    if safePlatform then
        pcall(function() safePlatform:Destroy() end)
        safePlatform = nil
    end

    -- Cancela tween do AutoFarm.
    if autoFarmTween then
        autoFarmTween:Cancel()
        autoFarmTween = nil
    end

    -- Restaura estado do personagem.
    pcall(function()
        local char = player.Character
        if not char then return end

        -- 1. Restaura transparências originais (Invisibility).
        for part, origTrans in pairs(invisOriginalTransparency) do
            if part and part.Parent then
                part.Transparency = origTrans
            end
        end
        table.clear(invisOriginalTransparency)

        -- 2. Restaura LocalTransparencyModifier (XRay).
        for part, orig in pairs(XRayParts) do
            if part and part.Parent then
                part.LocalTransparencyModifier = orig
            end
        end
        table.clear(XRayParts)

        -- 3. Restaura físicas do root.
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.Anchored                = false
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end

        -- 4. Restaura CanCollide.
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end

        -- 5. Restaura velocidade e pulo.
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed    = 16
            hum.UseJumpPower = true
            hum.JumpPower    = 50
        end
    end)

    _G.AkatLogicRunning = false
end

-- ==================== CALLBACKS DA UI EXTERNA (_G.AkatCallbacks) ====================
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
        -- Atualiza raio do círculo imediatamente.
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
                -- Reposiciona no chão via raycast (evita o player ficar suspenso no ar).
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

    TpMap = function(enabled)
        Configs.TpMap = false
        if not enabled then return false end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return false end

        local lobbyNames = {Lobby = true, LobbyMap = true, LobbyArea = true}
        local bestPart, bestScore = nil, -math.huge

        for _, container in ipairs(workspace:GetChildren()) do
            if not lobbyNames[container.Name] and (container:IsA("Model") or container:IsA("Folder")) then
                for _, d in ipairs(container:GetDescendants()) do
                    if d:IsA("BasePart") then
                        local n     = d.Name:lower()
                        local score = 0
                        if n:find("spawn") or n:find("player") then score += 25 end
                        if n:find("map") then score += 8 end
                        if d.Size.X > 6 and d.Size.Z > 6 then score += 2 end
                        if score > bestScore then bestScore = score; bestPart = d end
                    end
                end
            end
        end

        if not bestPart then
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("BasePart") and d.Size.X > 12 and d.Size.Z > 12
                    and not d:IsDescendantOf(char)
                    and not d.Name:lower():find("lobby") then
                    bestPart = d; break
                end
            end
        end

        if bestPart then
            root.CFrame = CFrame.new(bestPart.Position + Vector3.new(0, math.max(4, bestPart.Size.Y * 0.5 + 3), 0))
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

    -- Aliases para compatibilidade com diferentes versões da UI.
    ["Tp to gun"] = function(enabled) _G.AkatCallbacks.TpToGun(enabled) end,
    ["Tp To Gun"] = function(enabled) _G.AkatCallbacks.TpToGun(enabled) end,

    AutoShoot = function(enabled)
        ToggleAutoShoot(enabled)
    end,

    -- A UI chama AutoShootOnce para cada disparo; Toggle apenas habilita/desabilita.
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
            -- Restaura LocalTransparencyModifier. Usa table.clear APÓS iteração
            -- para evitar comportamento indefinido ao modificar durante pairs().
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

                -- Busca a faca (char ou backpack).
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
            -- Salva transparências originais antes de tornar invisível.
            -- Não assume que todas eram 0 (acessórios, decorações podem variar).
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
            -- Restaura exatamente os valores salvos.
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
        -- Reduzido de 0.005 (200/s) para 0.08 (~12/s): redução de ~94% na carga de CPU.
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
            -- Restaura posição se estava rastreando e foi desligado externamente.
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
-- Movido do Heartbeat (60+ fps) para thread dedicada (10 fps).
-- Redução de carga ~85% com mesma eficácia prática.
-- Busca faca por múltiplos nomes (não só "Knife"/"Faca").
task.spawn(function()
    while scriptAlive do
        task.wait(0.1)
        if not Configs.Reach then continue end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        -- Busca a faca ativa com nomes variados.
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
    -- Aplica noclip apenas no personagem LOCAL e apenas quando necessário.
    -- AntiFling NÃO modifica personagens de outros jogadores (inacessível no servidor).
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

    -- Velocidade e pulo: AutoFarm trava WalkSpeed/JumpPower; outros sistemas restauram.
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

    -- AntiFling: zera velocidades anômalas do personagem LOCAL.
    -- Não toca personagens de outros jogadores (não teria efeito no servidor).
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

        -- Scan de moedas: só quando AutoFarm está ativo e a cada 0.3s.
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

        -- Atualiza flag de arma caída.
        local gunDropExists = workspace:FindFirstChild("GunDrop", true) ~= nil
        if gunDropExists then gunDroppedThisRound = true end
        if not gunFoundInPlayers and not gunDropExists and not knifeFoundInPlayers then
            gunDroppedThisRound = false
        end

        -- Anúncio de cargos no chat (uma vez por rodada).
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

        -- Reconstrói visuais ausentes (entrou novo jogador, nova rodada, etc.).
        if Configs.Name or Configs.Tracer or Configs.ViewReach then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    local needsRebuild = (Configs.Name and not NameTags[p])
                        or (Configs.Tracer and not Tracers[p])
                        or (Configs.ViewReach and not ReachBoxes[p])
                    if needsRebuild then
                        PlayerRoles[p] = ESP_DetectRole(p)
                        UpdateName(p); UpdateTracer(p); UpdateReachBox(p)
                    end
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

    -- Limpa cargos e visuais antigos (chars do round anterior).
    for p in pairs(PlayerRoles) do PlayerRoles[p] = nil end
    Visuals_ClearAll()

    -- Limpa transparências salvas da Invisibility (novo char = novas instâncias de Part).
    table.clear(invisOriginalTransparency)

    -- Reconecta ESP para todos os jogadores presentes.
    if Configs.ESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then ESP_ConnectPlayer(p) end
        end
    end

    -- Aguarda cargos serem atribuídos antes de reconstruir visuais.
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

    -- Reaplica XRay ao novo personagem.
    if Configs.XRay then
        if xrayDescendantConnection then
            xrayDescendantConnection:Disconnect()
            xrayDescendantConnection = nil
        end
        task.defer(function()
            if Configs.XRay and scriptAlive then _G.AkatCallbacks.XRay(true) end
        end)
    end

    -- Reaplica Invisibility ao novo personagem (salva novas transparências).
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

    -- Reconstrói visuais com defer para o char estar completamente carregado.
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
-- Conectados uma ÚNICA VEZ (não duplicados com ESP_Enable/Disable).
-- ESP_Enable só conecta os jogadores JÁ presentes; o global cuida dos que entram depois.
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
