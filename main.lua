-- [[
--     AKAT MM2 MAIN LOGIC - FULLY UPDATED & OPTIMIZED [v4.8 - PERFORMANCE & MOBILE FIX]
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
            
            -- SILENT AIM METAMETHOD OTIMIZADO
            if Configs.Aimbot and CachedState.HasGun and self == mouse then
                if key == "Hit" or key == "hit" then
                    local murderer = CachedState.Murderer
                    local pChar = murderer and murderer.Character
                    local head = pChar and (pChar:FindFirstChild("Head") or pChar:FindFirstChild("HumanoidRootPart"))
                    if head then return head.CFrame end
                elseif key == "Target" or key == "target" then
                    local murderer = CachedState.Murderer
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
local safePlatform = nil
local lastPositionBeforeSafeSpot = nil
local announcedThisRound = false
local currentCollectTarget = nil

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

-- ==================== NOVO SISTEMA DE AIMBOT MODERNO (MOBILE OPTIMIZED) ====================
local function ToggleAimbot(enabled)
    if Configs.Aimbot == enabled and aimbotConnection then return end 
    Configs.Aimbot = enabled
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    
    if enabled then
        aimbotConnection = RunService.RenderStepped:Connect(function()
            if not Configs.Aimbot then return end
            if not CachedState.HasGun then return end 
            
            local murderer = CachedState.Murderer
            if murderer and murderer.Character then
                local head = murderer.Character:FindFirstChild("Head")
                local mHum = murderer.Character:FindFirstChildOfClass("Humanoid")
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                
                if head and hum and hum.Health > 0 and mHum and mHum.Health > 0 then
                    -- CORREÇÃO DA CÂMERA FUGIR NO MOBILE: Desativa temporariamente o AutoRotate ao mirar
                    if UserInputService.TouchEnabled then
                        hum.AutoRotate = false
                    end

                    -- TIRO PREMIUM PREDITIVO: Calcula posição futura se o alvo pular ou se mover muito
                    local targetVelocity = murderer.Character:FindFirstChild("HumanoidRootPart") and murderer.Character.HumanoidRootPart.Velocity or Vector3.new(0,0,0)
                    local predictionOffset = targetVelocity * 0.135
                    
                    if mHum.FloorMaterial == Enum.Material.Air then
                        -- Se o Murderer estiver pulando, ajustamos o foco vertical perfeitamente na cabeça
                        predictionOffset = Vector3.new(targetVelocity.X * 0.14, targetVelocity.Y * 0.09, targetVelocity.Z * 0.14)
                    end
                    
                    local finalAimPosition = head.Position + predictionOffset
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, finalAimPosition)
                end
            else
                -- Se o Murderer morrer ou sumir, restaura o controle do mobile imediatamente
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and UserInputService.TouchEnabled then hum.AutoRotate = true end
            end
        end)
    else
        -- Restaura o comportamento padrão ao desligar o aimbot
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
    end
end

-- ==================== LÓGICA DE PROCURA DE ITENS & SEGURANÇA ====================
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
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    for k in pairs(Configs) do Configs[k] = false end
    ESP_Disable()
    if safePlatform then pcall(function() safePlatform:Destroy() end); safePlatform = nil end
    pcall(function()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then 
            hum.WalkSpeed = 16 
            hum.PlatformStand = false
            hum.AutoRotate = true
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then part.CanTouch = true end
            end
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
            if lastPositionBeforeSafeSpot then
                root.CFrame = lastPositionBeforeSafeSpot
                lastPositionBeforeSafeSpot = nil
            end
        end
    end,
    AutoCollect = function(enabled)
        Configs.AutoCollect = enabled
        if not enabled then 
            currentCollectTarget = nil 
            local char = player.Character
            if char then
                for _, part in ipairs(char:GetChildren()) do
                    if part:IsA("BasePart") then part.CanTouch = true end
                end
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then root.Anchored = false end
            end
        end
    end,
    ["Shoot murder"] = function(enabled)
        ToggleAimbot(enabled)
    end,
    AutoShoot = function(enabled) 
        ToggleAimbot(enabled)
    end,
    ShutdownAll = function()
        LimparEDesligarAbsolutamente()
    end
}

-- ==================== THREAD DO AUTO COLLECT (EFICIENTE & SEM PULOS & IMUNE) ====================
task.spawn(function()
    while true do
        task.wait(0.01) -- Reduzido o delay para transição ultra rápida de moeda em moeda
        if Configs.AutoCollect then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            
            if root and hum and hum.Health > 0 then
                -- IMUNIDADE ABSOLUTA ATIVADA: Desativa o registro de toque de todas as partes (Faca/Tiros ignoram você)
                for _, part in ipairs(char:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                        if part.Name ~= "HumanoidRootPart" then
                            part.CanTouch = false 
                        end
                    end
                end

                if IsBagFull() then
                    if safePlatform then
                        root.CFrame = safePlatform.CFrame * CFrame.new(0, 3, 0)
                    end
                    task.wait(0.5)
                else
                    local target = ObterMoedaProxima(root)
                    if target and target.Parent then
                        currentCollectTarget = target
                        local distance = (root.Position - target.Position).Magnitude
                        
                        if distance > 0 then
                            local speed = 55 -- Velocidade otimizada
                            local duration = distance / speed
                            local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
                            
                            -- REMOVIDO O OFFSET VERTICAL (Sem pulos, liso de moeda em moeda)
                            local targetCFrame = target.CFrame 
                            local tween = TweenService:Create(root, tweenInfo, {CFrame = targetCFrame})
                            
                            local noclipConn = RunService.Stepped:Connect(function()
                                if char then
                                    for _, part in ipairs(char:GetChildren()) do
                                        if part:IsA("BasePart") then part.CanCollide = false end
                                    end
                                end
                            end)
                            
                            root.Velocity = Vector3.new(0, 0, 0)
                            tween:Play()
                            tween.Completed:Wait()
                            if noclipConn then noclipConn:Disconnect() end
                        end
                        
                        pcall(function()
                            firetouchinterest(root, target, 0)
                            task.wait(0.01) 
                            firetouchinterest(root, target, 1)
                        end)
                    end
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
    if Configs.Speed then
        hum.WalkSpeed = 23
    else
        hum.WalkSpeed = 16
    end

    -- KNIFE REACH
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
    else
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then
                local handle = item:FindFirstChild("Handle")
                local rp = handle and handle:FindFirstChild("AkatReachPart")
                if rp then rp:Destroy() end
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
        if math.abs(root.Velocity.Magnitude) > 60 or math.abs(root.RotVelocity.Magnitude) > 60 then
            root.Velocity = Vector3.new(0, 0, 0)
            root.RotVelocity = Vector3.new(0, 0, 0)
        end
    end

    -- TELEPORT TO GUN (RESOLVIDO BUG DE SEGUNDO PLANO)
    local isMurdererRole = (PlayerRoles[player] == "Murderer")
    local hasKnife = player.Backpack:FindFirstChild("Knife") or (char and char:FindFirstChild("Knife")) or player.Backpack:FindFirstChild("Faca") or (char and char:FindFirstChild("Faca"))

    if Configs.TpToGun then
        if isMurdererRole or hasKnife then
            Configs.TpToGun = false
            trackingTpToGun = false
        else
            -- Procura a arma em tempo real direto na workspace (instantâneo)
            local gunDrop = workspace:FindFirstChild("GunDrop", true)
            if gunDrop then
                local gunPart = gunDrop:IsA("BasePart") and gunDrop or gunDrop:FindFirstChildOfClass("BasePart") or gunDrop.PrimaryPart
                if gunPart then
                    if not trackingTpToGun then
                        lastPositionBeforeTpToGun = root.CFrame 
                        trackingTpToGun = true
                    end
                    -- Teleporta instantaneamente para a arma caída
                    root.CFrame = gunPart.CFrame * CFrame.new(0, 2, 0)
                    
                    -- Se coletou a arma com sucesso, finaliza a função sozinho sem travar
                    local localHasGun = player.Backpack:FindFirstChild("Gun") or char:FindFirstChild("Gun") or player.Backpack:FindFirstChild("Revolver") or char:FindFirstChild("Revolver")
                    if localHasGun then
                        trackingTpToGun = false
                        Configs.TpToGun = false
                    end
                end
            end
        end
    else
        if trackingTpToGun then
            if lastPositionBeforeTpToGun then
                root.CFrame = lastPositionBeforeTpToGun
                lastPositionBeforeTpToGun = nil
            end
            trackingTpToGun = false
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
                local temArma = p.Character:FindFirstChild("Gun") or p.Backpack:FindFirstChild("Gun") or p.Character:FindFirstChild("Revolver") or p.Backpack:FindFirstChild("Revolver")
                if temArma then 
                    gunFoundInPlayers = true 
                    if p == player then localPlayerHasGun = true end
                end
                if p.Character:FindFirstChild("Knife") or p.Backpack:FindFirstChild("Knife") then knifeFoundInPlayers = true end
            end
            
            if Configs.ESP and p ~= player then
                ESP_UpdatePlayer(p)
            end
        end
        
        CachedState.HasGun = localPlayerHasGun
        CachedState.Murderer = currentMurderer

        if Configs.AutoCollect and (tick() - tempoUltimoScanMoedas > 0.8) then
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
        task.wait(0.25)
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
