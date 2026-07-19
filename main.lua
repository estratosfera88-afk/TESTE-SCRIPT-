-- [[
--     AKAT MM2 MAIN LOGIC - FULLY UPDATED & OPTIMIZED [v5.2 - FIXED EDITION 2026]
--     Compatível com Delta Mobile & PC | MM2 (2026)
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local mouse = player:GetMouse()

-- Estado dinâmico da rodada
local gunDroppedThisRound = false
local lastPositionBeforeTpToGun = nil 
local trackingTpToGun = false
local aimbotConnection = nil

-- Configurações expostas de forma Global
local Configs = {
    ESP = false,
    Aimbot = false, 
    Speed = false,
    Reach = false,
    AntiFling = false,
    TpToGun = false,
    SafeSpot = false,
    AutoCollect = false,
    ChatRoles = false
}
_G.Configs = Configs

-- ==================== CAMADA DE CACHE CENTRALIZADO (PREVINE CRASH) ====================
local CachedState = {
    HasGun = false,
    Murderer = nil,
    Coins = {}
}

local function PlayerTemArma()
    return CachedState.HasGun
end

local function AS_GetMurderer()
    return CachedState.Murderer
end
_G.AS_GetMurderer = AS_GetMurderer

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
            
            -- SILENT AIM METAMETHOD AJUSTADO PARA HEAD (CABEÇA)
            if Configs.Aimbot and CachedState.HasGun and self == mouse then
                if key == "Hit" or key == "hit" then
                    local murderer = CachedState.Murderer
                    local pChar = murderer and murderer.Character
                    local head = pChar and pChar:FindFirstChild("Head")
                    if head then return head.CFrame end
                elseif key == "Target" or key == "target" then
                    local murderer = CachedState.Murderer
                    local pChar = murderer and murderer.Character
                    local head = pChar and pChar:FindFirstChild("Head")
                    if head then return head end
                end
            end
            
            return oldIndex(self, key)
        end)
        setreadonly(gmt, true)
    end
end)

-- ==================== VARIÁVEIS DE ESTADO INTERNAS ====================
local PlayerRoles = {}
local ESPHighlights = {}
local espEventConnections = {}
local hbConnection = nil
local steppedConnection = nil
local safePlatform = nil
local lastPositionBeforeSafeSpot = nil
local announcedThisRound = false
local currentCollectTarget = nil
local autoCollectTween = nil

local ROLE_COLORS = {
    Murderer  = Color3.fromRGB(220, 0,   0),    
    Sheriff   = Color3.fromRGB(0,   120, 255),  
    Hero      = Color3.fromRGB(255, 220, 0),    
    Innocent  = Color3.fromRGB(0,   200, 80),   
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

    return checkAttr(p) or (p.Character and checkAttr(p.Character)) or "Innocent"
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
        task.wait(0.5)
        ESP_UpdatePlayer(p)
        char.ChildAdded:Connect(function() task.wait(0.1); ESP_UpdatePlayer(p) end)
        char.ChildRemoved:Connect(function() task.wait(0.1); ESP_UpdatePlayer(p) end)
    end)

    local bp = p:WaitForChild("Backpack", 5)
    local c2 = bp and bp.ChildAdded:Connect(function() task.wait(0.1); ESP_UpdatePlayer(p) end)
    local c3 = bp and bp.ChildRemoved:Connect(function() task.wait(0.1); ESP_UpdatePlayer(p) end)

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

-- ==================== NOVO SISTEMA DE AIMBOT COM SHIFT LOCK SEGURO ====================
local function ToggleAimbot(enabled)
    if Configs.Aimbot == enabled then return end 
    Configs.Aimbot = enabled
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    
    if enabled then
        aimbotConnection = RunService.RenderStepped:Connect(function()
            if not Configs.Aimbot then return end
            if not CachedState.HasGun then return end
            
            local murderer = CachedState.Murderer
            if murderer and murderer.Character then
                local head = murderer.Character:FindFirstChild("Head")
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                
                if head and root and hum and hum.Health > 0 then
                    -- Alinha a Câmera diretamente na Cabeça do Murderer
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, head.Position)
                    
                    -- Simulação de Shift Lock: Gira o corpo do personagem no eixo Y (evita inclinar para cima/baixo)
                    local targetLook = Vector3.new(head.Position.X, root.Position.Y, head.Position.Z)
                    root.CFrame = CFrame.lookAt(root.Position, targetLook)
                end
            end
        end)
    end
end

-- ==================== LÓGICA DE PROCURA DE ITENS & SEGURANÇA ====================
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

local function ObterMoedaProxima(root)
    local closestCoin, closestDist = nil, math.huge
    local listaMoedas = CachedState.Coins
    
    for i = 1, #listaMoedas do
        local d = listaMoedas[i]
        if d and d.Parent then
            local dist = (root.Position - d.Position).Magnitude
            if dist < closestDist and dist < 1500 then
                closestDist = dist
                closestCoin = d
            end
        end
    end
    return closestCoin
end

local function IsBagFull()
    local full = false
    pcall(function()
        local mainGui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("MainGui")
        local gameGui = mainGui and mainGui:FindFirstChild("Game")
        local coinBag = gameGui and gameGui:FindFirstChild("CoinBag")
        local amount = coinBag and coinBag:FindFirstChild("Container") and coinBag.Container:FindFirstChild("Amount")
        if amount and amount:IsA("TextLabel") then
            local current, max = amount.Text:match("(%d+)/(%d+)")
            if current and max and tonumber(current) >= tonumber(max) then
                full = true
            end
        end
    end)
    return full
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
    if steppedConnection then steppedConnection:Disconnect(); steppedConnection = nil end
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    for k in pairs(Configs) do Configs[k] = false end
    ESP_Disable()
    if safePlatform then pcall(function() safePlatform:Destroy() end); safePlatform = nil end
    if autoCollectTween then autoCollectTween:Cancel(); autoCollectTween = nil end
    pcall(function()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then 
            hum.WalkSpeed = 16 
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then root.Anchored = false end
        end
    end)
end

-- ==================== PONTE DE COMUNICAÇÃO GLOBAL (UI -> BACKEND) ====================
_G.AkatCallbacks = {
    ESP = function(enabled)
        Configs.ESP = enabled
        if enabled then ESP_Enable() else ESP_Disable() end
    end,
    SafeSpot = function(enabled)
        Configs.SafeSpot = enabled
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
            if lastPositionBeforeSafeSpot and root.Parent then
                root.CFrame = lastPositionBeforeSafeSpot
                lastPositionBeforeSafeSpot = nil
            end
        end
    end,
    AutoCollect = function(enabled)
        Configs.AutoCollect = enabled
        if not enabled then 
            currentCollectTarget = nil 
            if autoCollectTween then
                autoCollectTween:Cancel()
                autoCollectTween = nil
            end
            
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then 
                root.Anchored = false 
                root.AssemblyLinearVelocity = Vector3.zero
                
                -- Pousa suavemente no chão evitando o void
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {char}
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                local result = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayParams)
                if result then
                    root.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
                end
            end
        end
    end,
    ["Tp to gun"] = function(enabled) Configs.TpToGun = enabled end,
    ["Tp To Gun"] = function(enabled) Configs.TpToGun = enabled end,
    TpToGun = function(enabled) Configs.TpToGun = enabled end,
    ["Shoot murder"] = function(enabled) ToggleAimbot(enabled) end,
    ["Shoot Murderer"] = function(enabled) ToggleAimbot(enabled) end,
    AutoShoot = function(enabled) ToggleAimbot(enabled) end,
    ShutdownAll = function() LimparEDesligarAbsolutamente() end
}

-- ==================== THREAD DO AUTO COLLECT COLETANDO IMEDIATAMENTE ====================
task.spawn(function()
    while true do
        task.wait(0.02) -- Frequência otimizada para detecção instantânea
        if Configs.AutoCollect then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            
            if IsBagFull() then
                if autoCollectTween then autoCollectTween:Cancel(); autoCollectTween = nil end
                currentCollectTarget = nil
                if root then root.Anchored = false end
                task.wait(1) 
                continue
            end

            if root and hum and hum.Health > 0 then
                local target = ObterMoedaProxima(root)
                if target and target.Parent then
                    root.Anchored = true 
                    if currentCollectTarget ~= target then
                        currentCollectTarget = target
                        if autoCollectTween then autoCollectTween:Cancel() end
                        
                        -- CORREÇÃO: Vai diretamente para a CFrame exata do centro da moeda
                        local goalCFrame = CFrame.new(target.Position)
                        local dist = (root.Position - target.Position).Magnitude
                        local timeToReach = dist / 40 
                        
                        autoCollectTween = TweenService:Create(root, TweenInfo.new(timeToReach, Enum.EasingStyle.Linear), {CFrame = goalCFrame})
                        autoCollectTween:Play()
                    end
                    
                    -- Disparos de touch nativos instantâneos (Sem yields internos)
                    pcall(function()
                        firetouchinterest(root, target, 0)
                        firetouchinterest(root, target, 1)
                        -- Disparo reserva usando a parte inferior para garantir coletas em moedas baixas
                        local lowerPart = char:FindFirstChild("LowerTorso") or char:FindFirstChild("LeftFoot")
                        if lowerPart then
                            firetouchinterest(lowerPart, target, 0)
                            firetouchinterest(lowerPart, target, 1)
                        end
                    end)
                else
                    if autoCollectTween then autoCollectTween:Cancel(); autoCollectTween = nil end
                    currentCollectTarget = nil
                    root.Anchored = false
                end
            end
        end
    end
end)

-- ==================== THREAD TELEPORT TO GUN CORRIGIDA E ATIVA ====================
task.spawn(function()
    while true do
        task.wait(0.1)
        if Configs.TpToGun then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            
            if root and hum and hum.Health > 0 then
                -- Bloqueio de segurança caso seja o assassino
                local isMurdererRole = (PlayerRoles[player] == "Murderer")
                local hasKnife = player.Backpack:FindFirstChild("Knife") or char:FindFirstChild("Knife") or player.Backpack:FindFirstChild("Faca") or char:FindFirstChild("Faca")

                if isMurdererRole or hasKnife then
                    Configs.TpToGun = false
                    trackingTpToGun = false
                    lastPositionBeforeTpToGun = nil
                    continue
                end
                
                local gunPart = ObterArmaCaida(root)
                if gunPart and gunPart.Parent then
                    if not trackingTpToGun then
                        lastPositionBeforeTpToGun = root.CFrame
                        trackingTpToGun = true
                    end
                    -- Mantém o TP atualizado e travado em cima da arma caída imediatamente
                    root.CFrame = gunPart.CFrame * CFrame.new(0, 3, 0)
                end
            end
        else
            -- Retorna de forma segura ao local original se a opção for desligada na UI
            if trackingTpToGun then
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root and lastPositionBeforeTpToGun then
                    root.CFrame = lastPositionBeforeTpToGun
                end
                lastPositionBeforeTpToGun = nil
                trackingTpToGun = false
            end
        end
    end
end)

-- ==================== NOCLIP SEGURO (MÉTODO ATUALIZADO) ====================
steppedConnection = RunService.Stepped:Connect(function()
    if Configs.AutoCollect or Configs.SafeSpot then
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- ==================== LOOP PRINCIPAL (HEARTBEAT) ====================
hbConnection = RunService.Heartbeat:Connect(function(dt)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")

    if not root or not hum then return end

    -- WALK SPEED
    hum.WalkSpeed = Configs.Speed and 23 or 16

    -- KNIFE REACH (Silent Mag Reach)
    if Configs.Reach then
        local myKnife = char:FindFirstChild("Knife") or char:FindFirstChild("Faca")
        local handle = myKnife and myKnife:FindFirstChild("Handle")
        if handle then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    local enemyRoot = p.Character:FindFirstChild("HumanoidRootPart")
                    local enemyHum = p.Character:FindFirstChildOfClass("Humanoid")
                    if enemyRoot and enemyHum and enemyHum.Health > 0 then
                        local dist = (root.Position - enemyRoot.Position).Magnitude
                        if dist <= 18 then 
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

    -- ANTI FLING
    if Configs.AntiFling then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                for _, part in ipairs(p.Character:GetChildren()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end
        if math.abs(root.AssemblyLinearVelocity.Magnitude) > 60 or math.abs(root.AssemblyAngularVelocity.Magnitude) > 60 then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
end)

-- ==================== THREAD CENTRAL DE SCANNER E CACHE COLETOR ====================
task.spawn(function()
    local tempoUltimoScanMoedas = 0
    
    while true do
        local gunFoundInPlayers = false
        local knifeFoundInPlayers = false
        local localPlayerHasGun = false
        local currentMurderer, currentSheriff = nil, nil
        
        for _, p in ipairs(Players:GetPlayers()) do
            local role = PlayerRoles[p]
            if role == "Murderer" then currentMurderer = p end
            if role == "Sheriff"  then currentSheriff  = p end
            
            if p.Character then
                local temArma = p.Character:FindFirstChild("Gun") or p.Backpack:FindFirstChild("Gun")
                if temArma then 
                    gunFoundInPlayers = true 
                    if p == player then localPlayerHasGun = true end
                end
                if p.Character:FindFirstChild("Knife") or p.Backpack:FindFirstChild("Knife") then 
                    knifeFoundInPlayers = true 
                end
            end
        end
        
        CachedState.HasGun = localPlayerHasGun
        CachedState.Murderer = currentMurderer

        if Configs.AutoCollect and (tick() - tempoUltimoScanMoedas > 1.0) then
            tempoUltimoScanMoedas = tick()
            local moedasEncontradas = {}
            
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("BasePart") and d.Transparency < 1 then
                    local name = d.Name:lower()
                    if name:find("coin") or name:find("moeda") or name:find("gold") or name == "snowflake"
                        or name == "candycane" or name:find("token") or name:find("diamond")
                        or name:find("present") or name:find("candy") then
                        if not d:IsDescendantOf(Players) and not d:FindFirstAncestorOfClass("Tool")
                            and not d:FindFirstAncestorOfClass("Accessory") then
                            table.insert(moedasEncontradas, d)
                        end
                    end
                end
            end
            CachedState.Coins = moedasEncontradas
        end
        
        local gunDropExists = workspace:FindFirstChild("GunDrop", true) ~= nil
        if gunDropExists then gunDroppedThisRound = true end
        if not gunFoundInPlayers and not gunDropExists and not knifeFoundInPlayers then gunDroppedThisRound = false end

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
        task.wait(0.3)
    end
end)

-- ==================== CARGA DINÂMICA DA INTERFACE ====================
local Link_Da_UI = "https://raw.githubusercontent.com/estratosfera88-afk/UI.lua/refs/heads/main/ui.lua"

local Sucesso, Erro = pcall(function()
    loadstring(game:HttpGet(Link_Da_UI))()
end)

if not Sucesso then
    warn("[AKAT LOADER ERROR] Falha ao carregar a UI: ", Erro)
end
