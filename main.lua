-- [[
--     AKAT MM2 MAIN LOGIC - FULLY UPDATED & FIXED [v3.6 - MOBILE & BYPASS]
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
_G.ForceAutoShoot = false

-- Configurações expostas de forma Global
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
            
            if _G.Configs and (_G.Configs.AutoShoot or _G.ForceAutoShoot) and self == mouse then
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

-- ==================== AUTO SHOOT SYSTEM ====================
local AS = { lastShot = 0, cooldown = 0.22, maxRange = 300 }

local function AS_HasGun()
    local char = player.Character
    if not char then return false, nil end
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then
            local n = item.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("revolver") or n:find("sheriff") or n:find("arma") then
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
    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPos), 0.20)
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

local function PlayerTemArma()
    if player.Backpack:FindFirstChild("Gun") or (player.Character and player.Character:FindFirstChild("Gun")) then return true end
    return false
end

local function ObterMoedaProxima(root)
    local closestCoin, closestDist = nil, math.huge
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and d.Transparency < 1 then
            local name = d.Name:lower()
            if name:find("coin") or name:find("moeda") or name:find("gold") or name == "snowflake"
                or name == "candycane" or name:find("token") or name:find("diamond")
                or name:find("present") or name:find("candy") then
                if not d:IsDescendantOf(Players) and not d:FindFirstAncestorOfClass("Tool")
                    and not d:FindFirstAncestorOfClass("Accessory") then
                    local dist = (root.Position - d.Position).Magnitude
                    if dist < closestDist and dist < 1500 then
                        closestDist = dist
                        closestCoin = d
                    end
                end
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
    if renderConnection then renderConnection:Disconnect(); renderConnection = nil end
    for k in pairs(Configs) do Configs[k] = false end
    ESP_Disable()
    if safePlatform then pcall(function() safePlatform:Destroy() end); safePlatform = nil end
    if game:GetService("CoreGui"):FindFirstChild("AkatFloatingUI") then
        game:GetService("CoreGui").AkatFloatingUI:Destroy()
    end
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

-- ==================== CRIAÇÃO DO BOTÃO FLUTUANTE EXTENSO ====================
local function CriarBotaoFlutuante()
    if game:GetService("CoreGui"):FindFirstChild("AkatFloatingUI") then
        game:GetService("CoreGui").AkatFloatingUI:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AkatFloatingUI"
    ScreenGui.Parent = game:GetService("CoreGui")
    ScreenGui.ResetOnSpawn = false

    local Button = Instance.new("TextButton")
    Button.Name = "AutoShootButton"
    Button.Parent = ScreenGui
    Button.Size = UDim2.new(0, 175, 0, 46) -- Modelo um pouco mais extenso
    Button.Position = UDim2.new(0.15, 0, 0.45, 0)
    Button.Text = "Auto shoot"
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.Font = Enum.Font.GothamBold
    Button.TextSize = 15
    Button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Button.ClipsDescendants = true

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = Button

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(45, 5, 5)
    UIStroke.Thickness = 1.5
    UIStroke.Parent = Button

    local UIGradient = Instance.new("UIGradient")
    UIGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 0, 0)), -- Vermelho Escuro
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 15))  -- Preto
    })
    UIGradient.Rotation = 45
    UIGradient.Parent = Button

    -- Sistema de Arrastar (Mobile & PC)
    local dragging, dragInput, dragStart, startPos
    Button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Button.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    Button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            Button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    Button.MouseButton1Click:Connect(function()
        Button.TextSize = 13
        task.wait(0.05)
        Button.TextSize = 15
        if _G.AkatCallbacks and _G.AkatCallbacks.FireShoot then
            _G.AkatCallbacks.FireShoot()
        end
    end)
end

task.spawn(CriarBotaoFlutuante)

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
        if not enabled then 
            currentCollectTarget = nil 
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = false end
        end
    end,
    FireShoot = function()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum then return end

        local gunTool = char:FindFirstChild("Gun") or player.Backpack:FindFirstChild("Gun")
        if not gunTool then
            for _, item in ipairs(player.Backpack:GetChildren()) do
                local n = item.Name:lower()
                if n:find("gun") or n:find("pistol") or n:find("revolver") or n:find("arma") then
                    gunTool = item
                    break
                end
            end
        end

        if gunTool then
            local murderer = AS_GetMurderer()
            if murderer and murderer.Character then
                local head = murderer.Character:FindFirstChild("Head") or murderer.Character:FindFirstChild("HumanoidRootPart")
                local myRoot = char:FindFirstChild("HumanoidRootPart")
                
                if head and myRoot then
                    if gunTool.Parent == player.Backpack then
                        hum:EquipTool(gunTool)
                        task.wait(0.1)
                    end

                    _G.ForceAutoShoot = true
                    
                    myRoot.CFrame = CFrame.new(myRoot.Position, Vector3.new(head.Position.X, myRoot.Position.Y, head.Position.Z))
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
                    task.wait(0.05)
                    
                    pcall(function() 
                        gunTool:Activate() 
                    end)
                    
                    task.spawn(function()
                        task.wait(0.2)
                        _G.ForceAutoShoot = false
                    end)
                end
            end
        end
    end,
    ShutdownAll = function()
        LimparEDesligarAbsolutamente()
    end
}

-- ==================== THREAD INDEPENDENTE DO AUTO COLLECT (SEM TRAVADAS) ====================
task.spawn(function()
    while true do
        task.wait()
        if Configs.AutoCollect then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            
            if root and hum then
                if IsBagFull() then
                    hum.PlatformStand = false
                    if safePlatform then
                        root.CFrame = safePlatform.CFrame * CFrame.new(0, 3, 0)
                    end
                    task.wait(0.5)
                else
                    local target = ObterMoedaProxima(root)
                    if target and target.Parent then
                        hum.PlatformStand = true
                        
                        -- Ativa Noclip apenas no instante do voo/teleporte até a moeda
                        for _, part in ipairs(char:GetChildren()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                        
                        root.Velocity = Vector3.new(0, 0, 0)
                        root.CFrame = target.CFrame
                        
                        pcall(function()
                            firetouchinterest(root, target, 0)
                            firetouchinterest(root, target, 1)
                        end)
                        task.wait(0.06)
                    else
                        hum.PlatformStand = false
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

    -- ANTI FLING (Isolado de outros sistemas)
    if Configs.AntiFling then
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
                lastPositionBeforeSafeSpot = nil
            end
            trackingTpToGun = false
            Configs.TpToGun = false
        end
    end
end)

renderConnection = RunService.RenderStepped:Connect(function()
    AS_Tick()
end)

-- THREAD STATUS (SCANNER DE FUNÇÕES)
task.spawn(function()
    while true do
        local gunFoundInPlayers = false
        local knifeFoundInPlayers = false
        local currentMurderer, currentSheriff = nil, nil
        
        for _, p in ipairs(Players:GetPlayers()) do
            local role = PlayerRoles[p]
            if role == "Murderer" then currentMurderer = p end
            if role == "Sheriff"  then currentSheriff  = p end
            
            if p.Character then
                if p.Character:FindFirstChild("Gun") or p.Backpack:FindFirstChild("Gun") then gunFoundInPlayers = true end
                if p.Character:FindFirstChild("Knife") or p.Backpack:FindFirstChild("Knife") then knifeFoundInPlayers = true end
            end
            
            if Configs.ESP and p ~= player then
                ESP_UpdatePlayer(p)
            end
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
        task.wait(0.4)
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
