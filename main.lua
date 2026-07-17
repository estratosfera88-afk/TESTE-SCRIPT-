-- [[
--     AKAT MM2 MAIN LOGIC - BACKEND ONLY [v3.4 - AUTO COLLECT v2]
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local mouse = player:GetMouse()

local gunDroppedThisRound = false
local lastPositionBeforeTpToGun = nil
local trackingTpToGun = false

local Configs = {
    ESP = false,
    AutoShoot = false,
    Speed = false,
    Reach = false,
    AntiFling = false,
    TpToGun = false,
    SafeSpot = false,
    AutoCollect = false,
    ChatRoles = false
}
_G.Configs = Configs

-- ==================== ANTI-BAN / ANTI-KICK & METAMETHOD HOOKS ====================
local oldIndex = nil
local oldNamecall = nil

task.spawn(function()
    local gmt = getrawmetatable and getrawmetatable(game)
    if gmt and setreadonly and hookfunction then
        setreadonly(gmt, false)
        oldNamecall = gmt.__namecall
        oldIndex = gmt.__index

        gmt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if tostring(method):lower() == "kick" and self == player then
                warn("[AKAT ANTI-BAN] Tentativa de Kick bloqueada!")
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

            if _G.Configs and _G.Configs.AutoShoot and self == mouse then
                if key == "Hit" or key == "hit" then
                    local murderer = _G.AS_GetMurderer()
                    local pChar = murderer and murderer.Character
                    local head = pChar and (pChar:FindFirstChild("Head") or pChar:FindFirstChild("HumanoidRootPart"))
                    if head then return CFrame.new(head.Position) end
                elseif key == "Target" or key == "target" then
                    local murderer = _G.AS_GetMurderer()
                    local pChar = murderer and murderer.Character
                    local head = pChar and (pChar:FindFirstChild("Head") or pChar:FindFirstChild("HumanoidRootPart"))
                    if head then return head end
                end
            end

            return oldIndex(self, key)
        end)
        setreadonly(gmt, true)
    end

    local function applyBypass(character)
        if not character then return end
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid and hookproperty then
            pcall(function() hookproperty(humanoid, "WalkSpeed", 16) end)
        end
    end
    player.CharacterAdded:Connect(applyBypass)
    if player.Character then applyBypass(player.Character) end
end)

-- ==================== VARIÁVEIS DE ESTADO INTERNAS ====================
local PlayerRoles = {}
local ESPHighlights = {}
local espEventConnections = {}
local hbConnection = nil
local renderConnection = nil
local safePlatform = nil
local lastPositionBeforeSafeSpot = nil
local announcedThisRound = false

local ROLE_COLORS = {
    Murderer = Color3.fromRGB(220, 0,   0),
    Sheriff  = Color3.fromRGB(0,   120, 255),
    Hero     = Color3.fromRGB(255, 220, 0),
    Innocent = Color3.fromRGB(0,   200, 80),
}

-- ==================== SISTEMAS AUXILIARES E DETECÇÕES ====================
local function ESP_DetectRole(p)
    if not p or not p.Parent then return "Innocent" end
    local function scanTools(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local n = item.Name:lower()
                if n:find("knife") or n:find("faca") or n:find("sword") then
                    return "Murderer"
                elseif n:find("gun") or n:find("pistol") or n:find("revolver") or n:find("arma") then
                    if gunDroppedThisRound then return "Hero" else return "Sheriff" end
                end
            end
        end
        return nil
    end

    local toolRole = scanTools(p.Character) or scanTools(p:FindFirstChild("Backpack"))
    if toolRole then return toolRole end

    local function checkAttr(target)
        if not target then return nil end
        local role = target:GetAttribute("Role") or target:GetAttribute("role") or target:GetAttribute("MMRole")
        if not role then return nil end
        local r = tostring(role):lower()
        if r:find("murder") or r:find("assassin") then return "Murderer" end
        if r:find("sheriff") or r:find("xerife")   then return "Sheriff"  end
        if r:find("hero")   or r:find("heroi")     then return "Hero"     end
        return nil
    end

    return checkAttr(p) or checkAttr(p.Character) or "Innocent"
end

local function ESP_UpdatePlayer(p)
    if not p or not p.Character then
        if ESPHighlights[p] then
            pcall(function() ESPHighlights[p]:Destroy() end)
            ESPHighlights[p] = nil
        end
        return
    end

    local char = p.Character
    local role = ESP_DetectRole(p)
    PlayerRoles[p] = role

    local color = ROLE_COLORS[role] or ROLE_COLORS.Innocent
    local hl = char:FindFirstChild("AkatESP")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "AkatESP"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 0.3
        hl.OutlineTransparency = 0
        hl.Parent = char
        ESPHighlights[p] = hl
    end

    hl.FillColor    = color
    hl.OutlineColor = color
end

local function ESP_ClearAll()
    for p, hl in pairs(ESPHighlights) do
        pcall(function() if hl and hl.Parent then hl:Destroy() end end)
        ESPHighlights[p] = nil
        PlayerRoles[p] = nil
    end
end

local function ESP_ConnectPlayer(p)
    if p == player then return end

    local c1 = p.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        ESP_UpdatePlayer(p)
        char.ChildAdded:Connect(function() task.wait(0.05); ESP_UpdatePlayer(p) end)
        char.ChildRemoved:Connect(function() task.wait(0.05); ESP_UpdatePlayer(p) end)
    end)

    local bp = p:FindFirstChild("Backpack")
    local c2 = bp and bp.ChildAdded:Connect(function() task.wait(0.05); ESP_UpdatePlayer(p) end)
    local c3 = bp and bp.ChildRemoved:Connect(function() task.wait(0.05); ESP_UpdatePlayer(p) end)

    espEventConnections[p] = { c1, c2, c3 }
    ESP_UpdatePlayer(p)
end

local function ESP_DisconnectPlayer(p)
    if espEventConnections[p] then
        for _, c in ipairs(espEventConnections[p]) do
            if c then pcall(function() c:Disconnect() end) end
        end
        espEventConnections[p] = nil
    end
    if ESPHighlights[p] then
        pcall(function() ESPHighlights[p]:Destroy() end)
        ESPHighlights[p] = nil
    end
    PlayerRoles[p] = nil
end

local function ESP_Enable()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then ESP_ConnectPlayer(p) end
    end
    Players.PlayerAdded:Connect(function(p)
        if Configs.ESP then ESP_ConnectPlayer(p) end
    end)
    Players.PlayerRemoving:Connect(function(p)
        ESP_DisconnectPlayer(p)
    end)
end

local function ESP_Disable()
    for _, p in ipairs(Players:GetPlayers()) do
        ESP_DisconnectPlayer(p)
    end
    ESP_ClearAll()
end

-- ==================== AUTO SHOOT v3 LERP SYSTEM ====================
local AS = { lastShot = 0, cooldown = 0.22, maxRange = 300 }

local function AS_HasGun()
    local char = player.Character
    if not char then return false, nil end
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then
            local n = item.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("revolver") or n:find("sheriff") then
                return true, item
            end
        end
    end
    return false, nil
end

local function AS_GetMurderer()
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local bestTarget, bestDist = nil, AS.maxRange

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and PlayerRoles[p] == "Murderer" then
            local pChar = p.Character
            local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
            local pHum  = pChar and pChar:FindFirstChildOfClass("Humanoid")
            if pRoot and pHum and pHum.Health > 0 then
                local dist = (myRoot.Position - pRoot.Position).Magnitude
                if dist < bestDist then
                    bestDist   = dist
                    bestTarget = p
                end
            end
        end
    end
    return bestTarget
end
_G.AS_GetMurderer = AS_GetMurderer

local function AS_Tick()
    if not Configs.AutoShoot then return end
    local hasGun, gunTool = AS_HasGun()
    if not hasGun or not gunTool then return end
    local murderer = AS_GetMurderer()
    if not murderer then return end

    local pChar = murderer.Character
    local head  = pChar and (pChar:FindFirstChild("Head") or pChar:FindFirstChild("HumanoidRootPart"))
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not head or not myRoot then return end

    local targetPos = head.Position
    myRoot.CFrame = CFrame.new(myRoot.Position, Vector3.new(targetPos.X, myRoot.Position.Y, targetPos.Z))
    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPos), 0.18)
end

-- ==================== LÓGICA DE TELEPORTE ====================
local function ObterArmaCaida(root)
    local gun = workspace:FindFirstChild("GunDrop", true)
    if gun then
        local targetPart = nil
        if gun:IsA("BasePart") then targetPart = gun
        elseif gun:IsA("Model") then targetPart = gun:FindFirstChildOfClass("BasePart") or gun.PrimaryPart
        elseif gun:IsA("Tool") then targetPart = gun:FindFirstChild("Handle") or gun:FindFirstChildOfClass("BasePart")
        end
        if targetPart and root then
            if (root.Position - targetPart.Position).Magnitude < 1500 then return targetPart end
        end
    end
    return nil
end

local function PlayerTemArma()
    if player.Backpack:FindFirstChild("Gun") or (player.Character and player.Character:FindFirstChild("Gun")) then return true end
    return false
end

local function EnviarMensagemChat(msg)
    local TextChatService = game:GetService("TextChatService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if channel then channel:SendAsync(msg) end
        else
            local chatEvent = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                and ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
            if chatEvent then chatEvent:FireServer(msg, "All") end
        end
    end)
end

local function LimparEDesligarAbsolutamente()
    if hbConnection then hbConnection:Disconnect(); hbConnection = nil end
    if renderConnection then renderConnection:Disconnect(); renderConnection = nil end
    for k in pairs(Configs) do Configs[k] = false end
    ESP_Disable()
    if safePlatform then pcall(function() safePlatform:Destroy() end); safePlatform = nil end
    pcall(function()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.PlatformStand = false
        end
        if char then
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Tool") then
                    local handle = item:FindFirstChild("Handle")
                    local rp = handle and handle:FindFirstChild("AkatReachPart")
                    if rp then rp:Destroy() end
                end
            end
        end
    end)
end

-- ==================== AUTO COLLECT v2 - SISTEMA MODERNO MM2 2026 ====================
local AC = {
    active          = false,
    currentTarget   = nil,
    moveConnection  = nil,
    scanThread      = nil,
    roundWatcher    = nil,
    collectedCache  = {},
    SCAN_INTERVAL   = 0.35,
    COLLECT_RADIUS  = 4,
    MAX_COIN_DIST   = 1600,
    MOVE_SPEED      = 8,
    SWAP_THRESHOLD  = 8,   -- Diferença mínima (studs) para trocar de alvo
}

local COIN_NAMES = {
    "coin", "moeda", "gold", "snowflake", "candycane", "token",
    "diamond", "present", "candy", "gem", "collectible", "shard",
    "crystal", "orb", "star", "doubloon", "emerald", "ruby",
}

local function AC_IsCoinName(name)
    local lower = name:lower()
    for _, kw in ipairs(COIN_NAMES) do
        if lower:find(kw) then return true end
    end
    return false
end

local function AC_IsValidCoin(part)
    if not part or not part.Parent then return false end
    if not part:IsA("BasePart") then return false end
    if part.Transparency >= 1 then return false end
    if part:IsDescendantOf(Players) then return false end
    if part:FindFirstAncestorOfClass("Tool") then return false end
    if part:FindFirstAncestorOfClass("Accessory") then return false end
    if not AC_IsCoinName(part.Name) then return false end
    return true
end

local function AC_FindNearest(root)
    if not root then return nil end
    local origin  = root.Position
    local best, bestDist = nil, AC.MAX_COIN_DIST
    for _, desc in ipairs(workspace:GetDescendants()) do
        if AC_IsValidCoin(desc) and not AC.collectedCache[desc] then
            local d = (origin - desc.Position).Magnitude
            if d < bestDist then
                bestDist = d
                best = desc
            end
        end
    end
    return best
end

local function AC_ClearCache()
    for inst in pairs(AC.collectedCache) do
        if not inst or not inst.Parent then
            AC.collectedCache[inst] = nil
        end
    end
end

local function AC_StopMovement()
    if AC.moveConnection then
        AC.moveConnection:Disconnect()
        AC.moveConnection = nil
    end
    AC.currentTarget = nil
end

local function AC_StopScan()
    -- scanThread é um task.spawn; só sinalizamos via Configs.AutoCollect = false
    AC.scanThread = nil
end

local function AC_StartCollection()
    if AC.moveConnection then return end

    AC.moveConnection = RunService.Heartbeat:Connect(function(dt)
        if not Configs.AutoCollect then
            AC_StopMovement()
            return
        end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then return end

        local target = AC.currentTarget

        -- Valida alvo atual
        if target then
            if not AC_IsValidCoin(target) then
                AC.collectedCache[target] = true
                AC.currentTarget = nil
                return
            end

            local dist = (root.Position - target.Position).Magnitude

            -- Chegou na moeda
            if dist <= AC.COLLECT_RADIUS then
                AC.collectedCache[target] = true
                AC.currentTarget = nil
                return
            end

            -- Movimento suave com Lerp de posição
            local targetPos  = target.Position
            local currentPos = root.Position
            local speed      = math.min(AC.MOVE_SPEED * dt * 60, dist)
            local newPos     = currentPos + (targetPos - currentPos).Unit * speed

            -- Raycast para altura do chão
            local rpParams = RaycastParams.new()
            rpParams.FilterDescendantsInstances = { char }
            rpParams.FilterType = Enum.RaycastFilterType.Exclude

            local hit = workspace:Raycast(
                Vector3.new(newPos.X, currentPos.Y + 5, newPos.Z),
                Vector3.new(0, -25, 0),
                rpParams
            )
            local groundY = hit and (hit.Position.Y + 3) or currentPos.Y
            local finalY  = currentPos.Y + (groundY - currentPos.Y) * 0.2

            root.CFrame = CFrame.new(
                Vector3.new(newPos.X, finalY, newPos.Z),
                Vector3.new(targetPos.X, finalY, targetPos.Z)
            )
        end
    end)
end

local function AC_StartScan()
    if AC.scanThread then return end

    AC.scanThread = task.spawn(function()
        while Configs.AutoCollect do
            AC_ClearCache()

            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if root and hum and hum.Health > 0 then
                if not AC.currentTarget or not AC_IsValidCoin(AC.currentTarget) then
                    AC.currentTarget = AC_FindNearest(root)
                else
                    local nearest = AC_FindNearest(root)
                    if nearest and nearest ~= AC.currentTarget then
                        local dCurrent = (root.Position - AC.currentTarget.Position).Magnitude
                        local dNearest = (root.Position - nearest.Position).Magnitude
                        if dNearest < dCurrent - AC.SWAP_THRESHOLD then
                            AC.currentTarget = nearest
                        end
                    end
                end
            end

            task.wait(AC.SCAN_INTERVAL)
        end

        -- Desativado externamente
        AC_StopMovement()
        AC.scanThread = nil
    end)
end

-- Watcher de rodada: reinicia o AC automaticamente entre partidas
local function AC_WatchRound()
    if AC.roundWatcher then return end

    AC.roundWatcher = task.spawn(function()
        local wasRoundActive = false

        while true do
            task.wait(1.2)

            local roundActive = false
            for _, p in ipairs(Players:GetPlayers()) do
                if PlayerRoles[p] == "Murderer" then
                    roundActive = true
                    break
                end
            end

            if roundActive ~= wasRoundActive then
                if not roundActive then
                    -- Rodada terminou → limpa tudo
                    AC.collectedCache = {}
                    AC_StopMovement()
                    AC_StopScan()
                elseif Configs.AutoCollect then
                    -- Nova rodada → aguarda moedas aparecerem e reinicia
                    task.wait(2)
                    AC_StartCollection()
                    AC_StartScan()
                end
                wasRoundActive = roundActive
            end
        end
    end)
end

AC_WatchRound()

-- ==================== PONTE DE COMUNICAÇÃO GLOBAL (UI -> BACKEND) ====================
_G.AkatCallbacks = {
    ESP = function(enabled)
        if enabled then ESP_Enable() else ESP_Disable() end
    end,
    SafeSpot = function(enabled)
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if enabled then
            lastPositionBeforeSafeSpot = root.CFrame
            if not safePlatform or not safePlatform.Parent then
                safePlatform = Instance.new("Part")
                safePlatform.Name = "AkatSafePlatform"
                safePlatform.Size = Vector3.new(15, 1, 15)
                safePlatform.Position = Vector3.new(root.Position.X, 900, root.Position.Z)
                safePlatform.Anchored = true
                safePlatform.Transparency = 0.4
                safePlatform.Material = Enum.Material.ForceField
                safePlatform.Color = Color3.fromHex("#8B0000")
                safePlatform.Parent = workspace
            end
            root.CFrame = safePlatform.CFrame * CFrame.new(0, 3, 0)
        else
            if safePlatform then safePlatform:Destroy(); safePlatform = nil end
            if lastPositionBeforeSafeSpot then
                root.CFrame = lastPositionBeforeSafeSpot
                lastPositionBeforeSafeSpot = nil
            end
        end
    end,
    AutoCollect = function(enabled)
        if enabled then
            AC.collectedCache = {}
            AC.currentTarget  = nil
            AC_StartCollection()
            AC_StartScan()
        else
            AC_StopMovement()
            AC_StopScan()
            AC.collectedCache = {}
            AC.currentTarget  = nil
            local char = player.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = false end
        end
    end,
    FireShoot = function()
        local hasGun, gunTool = AS_HasGun()
        if hasGun and gunTool then
            local murderer = AS_GetMurderer()
            if murderer then
                pcall(function()
                    gunTool:Activate()
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                    task.wait(0.01)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                end)
            end
        end
    end,
    ShutdownAll = function()
        LimparEDesligarAbsolutamente()
    end
}

-- ==================== HEARTBEAT PRINCIPAL ====================
hbConnection = RunService.Heartbeat:Connect(function(dt)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    -- WALK SPEED
    if Configs.Speed then
        hum.WalkSpeed = 23
    else
        hum.WalkSpeed = 16
    end

    -- KNIFE REACH v3
    if Configs.Reach then
        local myKnife = char:FindFirstChild("Knife") or char:FindFirstChild("Faca")
        if myKnife then
            local handle = myKnife:FindFirstChild("Handle")
            if handle then
                local rp = handle:FindFirstChild("AkatReachPart")
                if not rp then
                    rp = Instance.new("Part")
                    rp.Name = "AkatReachPart"
                    rp.Size = Vector3.new(18, 18, 18)
                    rp.Transparency = 0.88
                    rp.Color = Color3.fromHex("#8B0000")
                    rp.Material = Enum.Material.ForceField
                    rp.CanCollide = false
                    rp.Massless = true
                    local weld = Instance.new("Weld", rp)
                    weld.Part0 = handle
                    weld.Part1 = rp
                    rp.Parent = handle
                end
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= player and p.Character then
                        local enemyRoot = p.Character:FindFirstChild("HumanoidRootPart")
                        local enemyHum  = p.Character:FindFirstChildOfClass("Humanoid")
                        if enemyRoot and enemyHum and enemyHum.Health > 0 then
                            if (root.Position - enemyRoot.Position).Magnitude <= 18 then
                                pcall(function()
                                    firetouchinterest(enemyRoot, handle, 0)
                                    firetouchinterest(enemyRoot, handle, 1)
                                end)
                            end
                        end
                    end
                end
            end
        end
    else
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then
                local handle = item:FindFirstChild("Handle")
                local rp = handle and handle:FindFirstChild("AkatReachPart")
                if rp then rp:Destroy() end
            end
        end
    end

    -- ANTI FLING / NOCLIP
    if Configs.AntiFling or Configs.AutoCollect then
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                for _, part in ipairs(p.Character:GetChildren()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end
    end

    -- TELEPORT TO GUN
    if Configs.TpToGun and PlayerRoles[player] ~= "Murderer" and not PlayerTemArma() then
        local gunPart = ObterArmaCaida(root)
        if gunPart then
            if not trackingTpToGun then
                lastPositionBeforeTpToGun = root.CFrame
                trackingTpToGun = true
            end
            root.CFrame = gunPart.CFrame * CFrame.new(0, 3, 0)
        end
    else
        if trackingTpToGun then
            if lastPositionBeforeTpToGun then
                root.CFrame = lastPositionBeforeTpToGun
                lastPositionBeforeTpToGun = nil
            end
            trackingTpToGun = false
            Configs.TpToGun = false
        end
    end
end)

-- ==================== RENDER STEPPED ====================
renderConnection = RunService.RenderStepped:Connect(function()
    AS_Tick()
end)

-- ==================== THREAD DE STATUS / CHAT ROLES ====================
task.spawn(function()
    while true do
        local gunFoundInPlayers  = false
        local knifeFoundInPlayers = false
        local currentMurderer, currentSheriff = nil, nil

        for _, p in ipairs(Players:GetPlayers()) do
            local role = PlayerRoles[p]
            if role == "Murderer" then currentMurderer = p end
            if role == "Sheriff"  then currentSheriff  = p end

            if p.Character then
                local bp = p:FindFirstChild("Backpack")
                if p.Character:FindFirstChild("Gun") or (bp and bp:FindFirstChild("Gun")) then gunFoundInPlayers = true end
                if p.Character:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")) then knifeFoundInPlayers = true end
            end

            if Configs.ESP and p ~= player then
                ESP_UpdatePlayer(p)
            end
        end

        local gunDropExists = workspace:FindFirstChild("GunDrop", true) ~= nil
        if gunDropExists then gunDroppedThisRound = true end
        if not gunFoundInPlayers and not gunDropExists and not knifeFoundInPlayers then
            gunDroppedThisRound = false
        end

        if not currentMurderer and not currentSheriff then
            announcedThisRound = false
        elseif Configs.ChatRoles and (currentMurderer or currentSheriff) and not announcedThisRound then
            announcedThisRound = true
            local msg = "[AKAT] "
            if currentMurderer then
                msg = msg .. "Murderer: " .. currentMurderer.DisplayName .. " (@" .. currentMurderer.Name .. ") "
            end
            if currentSheriff then
                msg = msg .. "| Sheriff: " .. currentSheriff.DisplayName .. " (@" .. currentSheriff.Name .. ")"
            end
            EnviarMensagemChat(msg)
        end

        task.wait(0.4)
    end
end)

-- ==================== CARREGAMENTO DA UI ====================
local Link_Da_UI = "https://raw.githubusercontent.com/estratosfera88-afk/UI.lua/refs/heads/main/ui.lua"

local Sucesso, Erro = pcall(function()
    loadstring(game:HttpGet(Link_Da_UI))()
end)

if not Sucesso then
    warn("[AKAT LOADER ERROR] Falha ao carregar a UI: ", Erro)
end
