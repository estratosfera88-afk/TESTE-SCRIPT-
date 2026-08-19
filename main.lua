-- [[ AKATSUKI MM2 UNIFIED SCRIPT [v5.7 + UI v3.8 - UPDATED] ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local mouse = player:GetMouse()

-- ==================== ESTADO GLOBAL E CONFIGURAÇÕES ====================
local gunDroppedThisRound = false
local lastPositionBeforeTpToGun = nil 
local trackingTpToGun = false
local autoCollectTemporarilyDisabled = false 
local aimbotConnection = nil

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

-- ==================== CACHE CENTRALIZADO ====================
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

-- ==================== ANTI-BAN & METAMETHOD HOOKS ====================
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
                return nil
            end
            return oldNamecall(self, ...)
        end)
        
        gmt.__index = newcclosure(function(self, key)
            if tostring(key):lower() == "kick" and self == player then
                return newcclosure(function() end)
            end
            
            if Configs.Aimbot and CachedState.HasGun and self == mouse then
                if key == "Hit" or key == "hit" then
                    local murderer = CachedState.Murderer
                    if murderer and murderer.Character then
                        local head = murderer.Character:FindFirstChild("Head")
                        local root = murderer.Character:FindFirstChild("HumanoidRootPart")
                        if head and root then
                            local velocity = root.AssemblyLinearVelocity or root.Velocity or Vector3.zero
                            if velocity.Magnitude > 80 then velocity = Vector3.zero end
                            local pingCompensation = 0.045
                            local targetPosition = head.Position + (velocity * pingCompensation)
                            return CFrame.new(targetPosition)
                        end
                    end
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

-- ==================== VARIÁVEIS DE ESTADO INTERNAS DA LÓGICA ====================
local PlayerRoles = {}
local ESPHighlights = {}
local espEventConnections = {}
local espPlayerAddedConn = nil
local espPlayerRemovingConn = nil
local ESP_UpdatePlayer 
local hbConnection = nil
local steppedConnection = nil
local safePlatform = nil
local lastPositionBeforeSafeSpot = nil
local currentCollectTarget = nil
local autoCollectTween = nil

local ROLE_COLORS = {
    Murderer  = Color3.fromRGB(220, 0,   0),    
    Sheriff   = Color3.fromRGB(0,   120, 255),  
    Hero      = Color3.fromRGB(255, 220, 0),    
    Innocent  = Color3.fromRGB(0,   200, 80),   
}

local function ESP_DetectRole(p)
    if not p or not p.Parent then return "Innocent" end
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

    local attrRole = checkAttr(p) or (p.Character and checkAttr(p.Character))
    if attrRole then return attrRole end

    local function scanTools(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                if item:FindFirstChild("KnifeScript") or item:FindFirstChild("Knife") then return "Murderer"
                elseif item:FindFirstChild("GunScript") or item:FindFirstChild("Gun") then
                    if gunDroppedThisRound then return "Hero" else return "Sheriff" end
                end
                local n = item.Name:lower()
                if n:find("knife") or n:find("faca") or n:find("sword") or n:find("blade") then return "Murderer"
                elseif n:find("gun") or n:find("pistol") or n:find("revolver") or n:find("arma") or n:find("luger") or n:find("blaster") or n:find("laser") or n:find("shark") or n:find("fang") or n:find("seer") then
                    if gunDroppedThisRound then return "Hero" else return "Sheriff" end
                end
            end
        end
        return nil
    end
    return scanTools(p.Character) or scanTools(p:FindFirstChild("Backpack")) or "Innocent"
end

ESP_UpdatePlayer = function(p)
    if not Configs.ESP or p == player then return end 
    if not p or not p.Character then
        if ESPHighlights[p] then pcall(function() ESPHighlights[p]:Destroy() end); ESPHighlights[p] = nil end
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
        ESPHighlights[p] = nil; PlayerRoles[p] = nil
    end
end

local function ESP_DisconnectPlayer(p)
    if espEventConnections[p] then
        for _, c in ipairs(espEventConnections[p]) do
            if c then pcall(function() c:Disconnect() end) end
        end
        espEventConnections[p] = nil
    end
    if ESPHighlights[p] then pcall(function() ESPHighlights[p]:Destroy() end); ESPHighlights[p] = nil end
    PlayerRoles[p] = nil
end

local function ESP_ConnectPlayer(p)
    if p == player then return end
    if espEventConnections[p] then return end
    local connections = {}
    local c1 = p.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if Configs.ESP then
            ESP_UpdatePlayer(p)
            char.ChildAdded:Connect(function() task.wait(0.1); if Configs.ESP then ESP_UpdatePlayer(p) end end)
            char.ChildRemoved:Connect(function() task.wait(0.1); if Configs.ESP then ESP_UpdatePlayer(p) end end)
        end
    end)
    table.insert(connections, c1)
    task.spawn(function()
        local bp = p:WaitForChild("Backpack", 5)
        if bp and espEventConnections[p] then
            local c2 = bp.ChildAdded:Connect(function() task.wait(0.1); if Configs.ESP then ESP_UpdatePlayer(p) end end)
            local c3 = bp.ChildRemoved:Connect(function() task.wait(0.1); if Configs.ESP then ESP_UpdatePlayer(p) end end)
            table.insert(espEventConnections[p], c2); table.insert(espEventConnections[p], c3)
        end
    end)
    espEventConnections[p] = connections
    ESP_UpdatePlayer(p)
end

local function ESP_Disable()
    Configs.ESP = false
    if espPlayerAddedConn then espPlayerAddedConn:Disconnect(); espPlayerAddedConn = nil end
    if espPlayerRemovingConn then espPlayerRemovingConn:Disconnect(); espPlayerRemovingConn = nil end
    for _, p in ipairs(Players:GetPlayers()) do ESP_DisconnectPlayer(p) end
    ESP_ClearAll()
end

local function ESP_Enable()
    Configs.ESP = true
    if espPlayerAddedConn then espPlayerAddedConn:Disconnect() end
    if espPlayerRemovingConn then espPlayerRemovingConn:Disconnect() end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then ESP_ConnectPlayer(p) end
    end
    espPlayerAddedConn = Players.PlayerAdded:Connect(function(p) if Configs.ESP then ESP_ConnectPlayer(p) end end)
    espPlayerRemovingConn = Players.PlayerRemoving:Connect(function(p) ESP_DisconnectPlayer(p) end)
end

local function ToggleAimbot(enabled)
    if Configs.Aimbot == enabled then return end 
    Configs.Aimbot = enabled
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    
    if enabled then
        aimbotConnection = RunService.RenderStepped:Connect(function()
            if not Configs.Aimbot or not CachedState.HasGun then return end
            local murderer = CachedState.Murderer
            if murderer and murderer.Character then
                local head = murderer.Character:FindFirstChild("Head")
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                
                if head and root and hum and hum.Health > 0 then
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, head.Position)
                    local targetLook = Vector3.new(head.Position.X, root.Position.Y, head.Position.Z)
                    root.CFrame = CFrame.lookAt(root.Position, targetLook)
                end
            end
        end)
    end
end

local function ObterArmaCaida(root)
    local gun = workspace:FindFirstChild("GunDrop", true)
    if gun then
        local targetPart = nil
        if gun:IsA("BasePart") then targetPart = gun
        elseif gun:IsA("Model") then targetPart = gun:FindFirstChildOfClass("BasePart") or gun.PrimaryPart
        elseif gun:IsA("Tool") then targetPart = gun:FindFirstChild("Handle") or gun:FindFirstChildOfClass("BasePart") end
        if targetPart and root and (root.Position - targetPart.Position).Magnitude < 1500 then return targetPart end
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
                closestDist = dist; closestCoin = d
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
            if current and max and tonumber(current) >= tonumber(max) then full = true end
        end
    end)
    return full
end

local function LimparEDesligarAbsolutamente()
    if hbConnection then hbConnection:Disconnect(); hbConnection = nil end
    if steppedConnection then steppedConnection:Disconnect(); steppedConnection = nil end
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    for k in pairs(Configs) do Configs[k] = false end
    autoCollectTemporarilyDisabled = false
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
    ESP = function(enabled) if enabled then ESP_Enable() else ESP_Disable() end end,
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
            if autoCollectTween then autoCollectTween:Cancel(); autoCollectTween = nil end
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then 
                root.Anchored = false 
                root.AssemblyLinearVelocity = Vector3.zero
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {char}
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                local result = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayParams)
                if result then root.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0)) end
            end
        end
    end,
    ["Tp To Gun"] = function(enabled) Configs.TpToGun = enabled end,
    TpToGun = function(enabled) Configs.TpToGun = enabled end,
    AutoShoot = function(enabled) ToggleAimbot(enabled) end,
    ShutdownAll = function() LimparEDesligarAbsolutamente() end
}

-- ==================== THREAD AUTO COLLECT ====================
task.spawn(function()
    while true do
        task.wait(0.005)
        if Configs.AutoCollect then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if IsBagFull() then
                if autoCollectTween then autoCollectTween:Cancel(); autoCollectTween = nil end
                currentCollectTarget = nil; task.wait(0.5); continue
            end
            if root and hum and hum.Health > 0 then
                local target = ObterMoedaProxima(root)
                if target and target.Parent then
                    if currentCollectTarget ~= target then
                        currentCollectTarget = target
                        if autoCollectTween then autoCollectTween:Cancel() end
                        local dist = (root.Position - target.Position).Magnitude
                        autoCollectTween = TweenService:Create(root, TweenInfo.new(dist / 37, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target.Position)})
                        autoCollectTween:Play()
                        autoCollectTween.Completed:Wait() 
                    end
                    pcall(function()
                        firetouchinterest(root, target, 0); firetouchinterest(root, target, 1)
                        for _, part in ipairs(char:GetChildren()) do
                            if part:IsA("BasePart") and (part.Name:find("Foot") or part.Name:find("Leg") or part.Name:find("Torso")) then
                                firetouchinterest(part, target, 0); firetouchinterest(part, target, 1)
                            end
                        end
                    end)
                else
                    if autoCollectTween then autoCollectTween:Cancel(); autoCollectTween = nil end
                    currentCollectTarget = nil
                end
            end
        end
    end
end)

-- ==================== THREAD TELEPORT TO GUN ====================
task.spawn(function()
    while true do
        task.wait(0.05)
        if Configs.TpToGun then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            
            if root and hum and hum.Health > 0 then
                local isMurdererRole = (PlayerRoles[player] == "Murderer")
                local hasKnife = player.Backpack:FindFirstChild("Knife") or char:FindFirstChild("Knife") or player.Backpack:FindFirstChild("Faca") or char:FindFirstChild("Faca")

                if isMurdererRole or hasKnife then
                    trackingTpToGun = false; lastPositionBeforeTpToGun = nil
                    if autoCollectTemporarilyDisabled then autoCollectTemporarilyDisabled = false; Configs.AutoCollect = true end
                    continue
                end
                
                local gunPart = ObterArmaCaida(root)
                if gunPart and gunPart.Parent then
                    if not trackingTpToGun then
                        lastPositionBeforeTpToGun = root.CFrame
                        trackingTpToGun = true
                        if Configs.AutoCollect then
                            autoCollectTemporarilyDisabled = true; Configs.AutoCollect = false
                            if autoCollectTween then autoCollectTween:Cancel(); autoCollectTween = nil end
                            currentCollectTarget = nil
                        end
                    end
                    root.CFrame = gunPart.CFrame * CFrame.new(0, 3, 0)
                else
                    if trackingTpToGun then
                        if lastPositionBeforeTpToGun then root.CFrame = lastPositionBeforeTpToGun end
                        lastPositionBeforeTpToGun = nil; trackingTpToGun = false
                        if autoCollectTemporarilyDisabled then autoCollectTemporarilyDisabled = false; Configs.AutoCollect = true end
                    end
                end
            end
        else
            if trackingTpToGun then
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root and lastPositionBeforeTpToGun then root.CFrame = lastPositionBeforeTpToGun end
                lastPositionBeforeTpToGun = nil; trackingTpToGun = false
                if autoCollectTemporarilyDisabled then autoCollectTemporarilyDisabled = false; Configs.AutoCollect = true end
            end
        end
    end
end)

-- ==================== ANTI-FLING & NOCLIP ====================
steppedConnection = RunService.Stepped:Connect(function()
    if Configs.AntiFling then
        pcall(function()
            if player.Character then
                for _, part in ipairs(player.Character:GetChildren()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
    end
end)

-- ==================== DYNAMIC UI COMPONENT (AJUSTADO) ====================
-- (Substitua todo o bloco "DYNAMIC UI COMPONENT" do seu script original por este código)

local UI_TEXT = {
    SearchPlaceholder = "Search...",
    ConfirmCloseTitle = "Do you want to close the script?",
    ConfirmBtn = "Confirm",
    CancelBtn = "Cancel",
    Intro = '<font color="#FFFFFF">Scripts by | </font><font color="#8B0000">AKATSUKI</font>',
    Tabs = { Player = "Player", Combat = "Combat", Visuals = "Visuals", Teleports = "Teleports", Misc = "Misc" },
    Options = {
        AutoShoot = { Title = "Aimbot Murderer", Desc = "Automatic aimbot that stays in the murderer's head non-stop." },
        Reach = { Title = "Knife Reach", Desc = "Significantly increases your knife attack reach (18 studs)." },
        ESP = { Title = "Player ESP", Desc = "Highlights players through walls (Sheriff Blue / Hero Yellow)." },
        Speed = { Title = "WalkSpeed", Desc = "Slightly increases player walkspeed up to 23 smoothly." },
        AntiFling = { Title = "Anti-Fling", Desc = "Disables collisions to prevent other players from flinging you." },
        TpToGun = { Title = "TP to Gun", Desc = "Teleports to dropped gun (Automatically disabled for the Murderer)." },
        SafeSpot = { Title = "Safe Spot", Desc = "Teleports you to an invisible sky platform to remain completely safe." },
        AutoCollect = { Title = "Auto Collect", Desc = "Smoothly collects coins continuously without clunky visual stops." },
        ChatRoles = { Title = "Reveal Roles", Desc = "Sends a message in chat revealing active roles." }
    }
}

local activeTab = "Player"
local menuAberto = true
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeltaAkatUniversalUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = uiParent

-- Som de Abertura
local OpenSound = Instance.new("Sound", screenGui)
OpenSound.SoundId = "rbxassetid://6310837681" -- ID do som
OpenSound.Volume = 0.5

-- Botão Flutuante
local FloatBtn = Instance.new("ImageButton", screenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0.12, 0, 0.4, 0)
FloatBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
FloatBtn.Visible = true
FloatBtn.ZIndex = 30
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(1, 0)

-- Sharingan Orbitante
local Sharingan = Instance.new("ImageLabel", screenGui)
Sharingan.Name = "SharinganEffect"
Sharingan.Size = UDim2.new(0, 25, 0, 25)
Sharingan.BackgroundTransparency = 1
Sharingan.Image = "rbxassetid://100882509796042" -- ID solicitado
Sharingan.ZIndex = 35

RunService.RenderStepped:Connect(function()
    local time = tick()
    -- Orbita ao redor do FloatBtn
    Sharingan.Position = UDim2.new(0, FloatBtn.AbsolutePosition.X + math.cos(time * 2) * 35, 0, FloatBtn.AbsolutePosition.Y + math.sin(time * 2) * 35)
    Sharingan.Rotation = Sharingan.Rotation + 2
end)

-- Sistema de Minimização Inteligente
FloatBtn.MouseButton1Click:Connect(function()
    local mainWrapper = screenGui:FindFirstChild("MainWrapper")
    if mainWrapper then
        if not mainWrapper.Visible then
            mainWrapper.Visible = true
            OpenSound:Play() -- Som toca apenas ao abrir
        else
            mainWrapper.Visible = false
        end
    end
end)

-- Interface Principal (Wrapper)
local mainWrapper = Instance.new("Frame", screenGui)
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0.5)
mainWrapper.Size = UDim2.new(0, 535, 0, 300)
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible = true

-- Sombra (Removida sombra inclinada interna, mantendo borda suave)
local shadow3D = Instance.new("ImageLabel", mainWrapper)
shadow3D.Size = UDim2.new(1, 20, 1, 20)
shadow3D.Position = UDim2.new(0, -10, 0, -10)
shadow3D.BackgroundTransparency = 1
shadow3D.Image = "rbxassetid://6014261993"
shadow3D.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow3D.ImageTransparency = 0.5
shadow3D.ScaleType = Enum.ScaleType.Slice
shadow3D.ZIndex = 1

local mainFrame = Instance.new("Frame", mainWrapper)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.ClipsDescendants = true -- Corta sombras vazantes

-- Gradiente solicitado (Overlay vertical vermelho semitransparente)
local GradientOverlay = Instance.new("Frame", mainFrame)
GradientOverlay.Size = UDim2.new(1, 0, 1, 0)
GradientOverlay.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
GradientOverlay.BackgroundTransparency = 0.5
local grad = Instance.new("UIGradient", GradientOverlay)
grad.Rotation = 90
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 0, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 0, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 0, 0))
})

-- Esquerda e Direita (Linhas Alinhadas)
local LeftPanel = Instance.new("Frame", mainFrame)
LeftPanel.Size = UDim2.new(0, 200, 1, 0)
LeftPanel.BackgroundTransparency = 1

local RightPanel = Instance.new("Frame", mainFrame)
RightPanel.Size = UDim2.new(1, -200, 1, 0)
RightPanel.Position = UDim2.new(0, 200, 0, 0)
RightPanel.BackgroundTransparency = 1

-- Títulos Esquerda (Alinhamento corrigido para o topo)
local title = Instance.new("TextLabel", LeftPanel)
title.Position = UDim2.new(0, 10, 0, 5) -- Mais próximo do topo
title.Size = UDim2.new(1, -10, 0, 16)
title.Text = "AKATSUKI SCRIPTS"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left

local subtitle = Instance.new("TextLabel", LeftPanel)
subtitle.Position = UDim2.new(0, 10, 0, 20) -- Próximo do título
subtitle.Size = UDim2.new(1, -10, 0, 12)
subtitle.Text = "MM2 SCRIPT | by zeni <3"
subtitle.TextColor3 = Color3.fromRGB(200, 50, 50)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 9
subtitle.TextXAlignment = Enum.TextXAlignment.Left

-- Linha Divisória Superior (Reta, ponta a ponta)
local TopLine = Instance.new("Frame", LeftPanel)
TopLine.Size = UDim2.new(1, 0, 0, 1)
TopLine.Position = UDim2.new(0, 0, 0, 35)
TopLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TopLine.BorderSizePixel = 0

-- Botão de Maximizar (Contorno fino e menor)
local ExpandBtn = Instance.new("TextButton", RightPanel)
ExpandBtn.Size = UDim2.new(0, 18, 0, 18)
ExpandBtn.Position = UDim2.new(1, -50, 0, 10)
ExpandBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ExpandBtn.Text = ""
Instance.new("UICorner", ExpandBtn).CornerRadius = UDim.new(0, 4)
local square = Instance.new("Frame", ExpandBtn)
square.Size = UDim2.new(0, 8, 0, 8)
square.Position = UDim2.new(0, 5, 0, 5)
square.BackgroundTransparency = 1
local stroke = Instance.new("UIStroke", square) -- Contorno fino
stroke.Thickness = 1
stroke.Color = Color3.fromRGB(255, 255, 255)

-- Linha Vermelha Inclinada (Corrigida para branca, mais fina)
local RedLine = Instance.new("Frame", RightPanel)
RedLine.Size = UDim2.new(0, 1, 0, 20)
RedLine.Rotation = 45
RedLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- Branca
RedLine.BorderSizePixel = 0

-- Botão de Olho (Tamanho reduzido)
local PrivacyBtn = Instance.new("ImageButton", LeftPanel)
PrivacyBtn.Size = UDim2.new(0, 16, 0, 16) -- Menor
PrivacyBtn.Position = UDim2.new(0, 170, 0, 10)
PrivacyBtn.Image = "rbxassetid://135604583195835"

-- ==================== INTERFACE PRINCIPAL ====================
local mainWrapper = Instance.new("Frame", screenGui)
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0.5)
mainWrapper.Size = UDim2.new(0, 535, 0, 300)
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible = false

-- Correção da Sombra Central (Corrigido desalinhamento e inclinação lateral)
local shadow3D = Instance.new("ImageLabel", mainWrapper)
shadow3D.Name = "Shadow3D"
shadow3D.AnchorPoint = Vector2.new(0.5, 0.5)
shadow3D.Position = UDim2.new(0.5, 0, 0.5, 0)
shadow3D.Size = UDim2.new(1, 35, 1, 35)
shadow3D.BackgroundTransparency = 1
shadow3D.Image = "rbxassetid://6014261993"
shadow3D.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow3D.ImageTransparency = 0.45
shadow3D.ScaleType = Enum.ScaleType.Slice
shadow3D.SliceCenter = Rect.new(49, 49, 450, 450)
shadow3D.ZIndex = 1

local mainFrame = Instance.new("Frame", mainWrapper)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundTransparency = 1 
mainFrame.ZIndex = 5

-- Drag da Janela UI
local dragUIToggle, dragUIStart, startUIPos
mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragUIToggle = true; dragUIStart = input.Position; startUIPos = mainWrapper.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragUIToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragUIStart
        mainWrapper.Position = UDim2.new(startUIPos.X.Scale, startUIPos.X.Offset + delta.X, startUIPos.Y.Scale, startUIPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragUIToggle = false end
end)

-- Substituição do Gradiente Tradicional por Mesh Gradient Fluido e Animado
local function CreateMeshGradientPanel(parent, size, pos, name)
    local panel = Instance.new("Frame", parent)
    panel.Name = name
    panel.Size = size
    panel.Position = pos
    panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255) 
    panel.BorderSizePixel = 0
    panel.ZIndex = 5
    panel.ClipsDescendants = true
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 9)
    
    local grad1 = Instance.new("UIGradient", panel)
    grad1.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 8, 10)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 10, 15)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 15))
    })
    
    -- Camada de malha líquida simulando Mesh Gradient com transições orgânicas e fluidas
    local meshLayer = Instance.new("ImageLabel", panel)
    meshLayer.Size = UDim2.new(1.4, 0, 1.4, 0)
    meshLayer.Position = UDim2.new(-0.2, 0, -0.2, 0)
    meshLayer.BackgroundTransparency = 1
    meshLayer.Image = "rbxassetid://6087845535"
    meshLayer.ImageColor3 = Color3.fromRGB(120, 20, 30)
    meshLayer.ImageTransparency = 0.65
    meshLayer.ScaleType = Enum.ScaleType.Tile
    meshLayer.ZIndex = 5

    RunService.RenderStepped:Connect(function()
        local t = tick() * 0.4
        grad1.Offset = Vector2.new(math.sin(t) * 0.3, math.cos(t * 0.8) * 0.3)
        meshLayer.Rotation = math.sin(t * 0.5) * 15
        meshLayer.Position = UDim2.new(-0.2 + math.cos(t * 0.6) * 0.05, 0, -0.2 + math.sin(t * 0.7) * 0.05, 0)
    end)
    
    local stroke = Instance.new("UIStroke", panel)
    stroke.Color = Color3.fromRGB(50, 15, 20)
    stroke.Thickness = 1.2
    return panel
end

-- Divisão de Painéis (Parte Esquerda Ampliada Moderadamente para 200px)
local LeftPanel = CreateMeshGradientPanel(mainFrame, UDim2.new(0, 200, 1, 0), UDim2.new(0, 0, 0, 0), "LeftPanel")
local RightPanel = CreateMeshGradientPanel(mainFrame, UDim2.new(1, -210, 1, 0), UDim2.new(0, 210, 0, 0), "RightPanel")

-- ==================== LEFT PANEL (Título, Linha Divisoria Reta e Perfil) ====================
local titleContainer = Instance.new("Frame", LeftPanel)
titleContainer.Size = UDim2.new(1, -16, 0, 42)
titleContainer.Position = UDim2.new(0, 8, 0, 10)
titleContainer.BackgroundTransparency = 1
titleContainer.ZIndex = 6

local title = Instance.new("TextLabel", titleContainer)
title.Size = UDim2.new(1, 0, 0, 16)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "AKATSUKI SCRIPTS"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextSize = 11
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 7

local subtitle = Instance.new("TextLabel", titleContainer)
subtitle.Size = UDim2.new(1, 0, 0, 14)
subtitle.Position = UDim2.new(0, 0, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Text = "MM2 SCRIPT | by zeni <3"
subtitle.TextColor3 = Color3.fromRGB(220, 50, 50)
subtitle.TextSize = 9
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 7

-- Linha horizontal reta integrando o topo esquerdo
local LeftSeparatorLine = Instance.new("Frame", LeftPanel)
LeftSeparatorLine.Size = UDim2.new(1, -16, 0, 1)
LeftSeparatorLine.Position = UDim2.new(0, 8, 0, 56)
LeftSeparatorLine.BackgroundColor3 = Color3.fromRGB(80, 20, 25)
LeftSeparatorLine.BorderSizePixel = 0
LeftSeparatorLine.ZIndex = 7

local TabsContainer = Instance.new("ScrollingFrame", LeftPanel)
TabsContainer.Name = "TabsContainer"
TabsContainer.Size = UDim2.new(1, 0, 1, -126)
TabsContainer.Position = UDim2.new(0, 0, 0, 64)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ZIndex = 7
TabsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
TabsContainer.ScrollBarThickness = 0

local TabsLayout = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabsLayout.Padding = UDim.new(0, 4)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TabsContainer.CanvasSize = UDim2.new(0, 0, 0, TabsLayout.AbsoluteContentSize.Y + 8)
end)

-- User Profile na Parte Esquerda Ampliada com Botão de Olho Ajustado e Branco
local UserProfileFrame = Instance.new("Frame", LeftPanel)
UserProfileFrame.Size = UDim2.new(1, -16, 0, 48)
UserProfileFrame.Position = UDim2.new(0, 8, 1, -54)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(20, 12, 15)
UserProfileFrame.BackgroundTransparency = 0.35
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex = 7
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 7)

local profileStroke = Instance.new("UIStroke", UserProfileFrame)
profileStroke.Color = Color3.fromRGB(50, 18, 22)
profileStroke.Thickness = 1

local AvatarImage = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Size = UDim2.new(0, 32, 0, 32)
AvatarImage.Position = UDim2.new(0, 8, 0.5, -16)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex = 8
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

local DisplayNameLabel = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Size = UDim2.new(1, -78, 0, 14)
DisplayNameLabel.Position = UDim2.new(0, 46, 0.5, -13)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
DisplayNameLabel.Font = Enum.Font.GothamBold
DisplayNameLabel.TextSize = 10
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLabel.ZIndex = 8

local UsernameLabel = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Size = UDim2.new(1, -78, 0, 12)
UsernameLabel.Position = UDim2.new(0, 46, 0.5, 1)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text = "@" .. player.Name
UsernameLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
UsernameLabel.Font = Enum.Font.Gotham
UsernameLabel.TextSize = 9
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UsernameLabel.ZIndex = 8

-- Botão de censura do nome de usuário reposicionado no canto da badge, reduzido e com ícone branco
local PrivacyBtn = Instance.new("ImageButton", UserProfileFrame)
PrivacyBtn.Size = UDim2.new(0, 20, 0, 20)
PrivacyBtn.Position = UDim2.new(1, -24, 0.5, -10)
PrivacyBtn.BackgroundColor3 = Color3.fromRGB(30, 15, 18)
PrivacyBtn.BackgroundTransparency = 0.2
PrivacyBtn.Image = "rbxthumb://type=Asset&id=135604583195835&w=150&h=150"
PrivacyBtn.ImageColor3 = Color3.fromRGB(255, 255, 255) -- Alterado de vermelho escuro para branco
PrivacyBtn.ZIndex = 9
Instance.new("UICorner", PrivacyBtn).CornerRadius = UDim.new(0, 4)

local privacyStroke = Instance.new("UIStroke", PrivacyBtn)
privacyStroke.Color = Color3.fromRGB(90, 25, 25)
privacyStroke.Thickness = 1

local PrivacySlash = Instance.new("Frame", PrivacyBtn)
PrivacySlash.Size = UDim2.new(0, 12, 0, 1.5)
PrivacySlash.AnchorPoint = Vector2.new(0.5, 0.5)
PrivacySlash.Position = UDim2.new(0.5, 0, 0.5, 0)
PrivacySlash.Rotation = -45
PrivacySlash.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
PrivacySlash.BorderSizePixel = 0
PrivacySlash.Visible = false
PrivacySlash.ZIndex = 10

local isPrivate = false
PrivacyBtn.MouseButton1Click:Connect(function()
    isPrivate = not isPrivate
    PrivacySlash.Visible = isPrivate
    if isPrivate then
        DisplayNameLabel.Text = string.rep("*", #player.DisplayName)
        UsernameLabel.Text = "@" .. string.rep("*", #player.Name)
    else
        DisplayNameLabel.Text = player.DisplayName
        UsernameLabel.Text = "@" .. player.Name
    end
end)

-- ==================== RIGHT PANEL (Compacto, Linha Separadora e Busca Otimizada) ====================
local topButtons = Instance.new("Frame", RightPanel)
topButtons.Size = UDim2.new(1, -16, 0, 36)
topButtons.Position = UDim2.new(0, 8, 0, 8)
topButtons.BackgroundTransparency = 1
topButtons.ZIndex = 6

local UIListTop = Instance.new("UIListLayout", topButtons)
UIListTop.FillDirection = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding = UDim.new(0, 6)
UIListTop.SortOrder = Enum.SortOrder.LayoutOrder

-- Search Dinâmico e Compacto (Com largura reduzida no tamanho normal)
local SearchBtn = Instance.new("TextButton", topButtons)
SearchBtn.Name = "SearchBtn"
SearchBtn.LayoutOrder = 1
SearchBtn.Size = UDim2.new(0, 24, 0, 24)
SearchBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
SearchBtn.BackgroundTransparency = 0.3
SearchBtn.Text = ""
SearchBtn.ClipsDescendants = true
SearchBtn.ZIndex = 7
Instance.new("UICorner", SearchBtn).CornerRadius = UDim.new(0, 5)

local SearchIcon = Instance.new("Frame", SearchBtn)
SearchIcon.Name = "Icon"
SearchIcon.Size = UDim2.new(0, 12, 0, 12)
SearchIcon.AnchorPoint = Vector2.new(0, 0.5)
SearchIcon.Position = UDim2.new(0, 6, 0.5, 0)
SearchIcon.BackgroundTransparency = 1
SearchIcon.ZIndex = 8

local SearchCircle = Instance.new("Frame", SearchIcon)
SearchCircle.Size = UDim2.new(0, 7, 0, 7)
SearchCircle.Position = UDim2.new(0, 1, 0, 1)
SearchCircle.BackgroundTransparency = 1
SearchCircle.ZIndex = 8
Instance.new("UICorner", SearchCircle).CornerRadius = UDim.new(1, 0)
local circleStroke = Instance.new("UIStroke", SearchCircle)
circleStroke.Color = Color3.fromHex("#A0A0A0")
circleStroke.Thickness = 1

local SearchHandle = Instance.new("Frame", SearchIcon)
SearchHandle.Size = UDim2.new(0, 1, 0, 4)
SearchHandle.Position = UDim2.new(0, 8, 0, 7)
SearchHandle.Rotation = -45
SearchHandle.BackgroundColor3 = Color3.fromHex("#A0A0A0")
SearchHandle.BorderSizePixel = 0
SearchHandle.ZIndex = 8

local searchTextBox = Instance.new("TextBox", SearchBtn)
searchTextBox.Size = UDim2.new(1, -26, 1, 0)
searchTextBox.Position = UDim2.new(0, 24, 0, 0)
searchTextBox.BackgroundTransparency = 1
searchTextBox.PlaceholderText = UI_TEXT.SearchPlaceholder
searchTextBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
searchTextBox.Text = ""
searchTextBox.TextColor3 = Color3.fromRGB(230, 230, 230)
searchTextBox.Font = Enum.Font.Gotham
searchTextBox.TextSize = 10
searchTextBox.TextXAlignment = Enum.TextXAlignment.Left
searchTextBox.Visible = false
searchTextBox.ZIndex = 8

-- Expand Button Reduzido
local ExpandBtn = Instance.new("TextButton", topButtons)
ExpandBtn.Name = "ExpandBtn"
ExpandBtn.LayoutOrder = 2
ExpandBtn.Size = UDim2.new(0, 24, 0, 24)
ExpandBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
ExpandBtn.BackgroundTransparency = 0.3
ExpandBtn.Text = ""
ExpandBtn.ZIndex = 7
Instance.new("UICorner", ExpandBtn).CornerRadius = UDim.new(0, 5)
local ExpandSquare = Instance.new("Frame", ExpandBtn)
ExpandSquare.Size = UDim2.new(0, 9, 0, 9)
ExpandSquare.AnchorPoint = Vector2.new(0.5, 0.5)
ExpandSquare.Position = UDim2.new(0.5, 0, 0.5, 0)
ExpandSquare.BackgroundTransparency = 1
ExpandSquare.ZIndex = 8
local ExpandStroke = Instance.new("UIStroke", ExpandSquare)
ExpandStroke.Color = Color3.fromHex("#A0A0A0")
ExpandStroke.Thickness = 1.2

-- Minimize Button Reduzido
local MinimizeBtn = Instance.new("TextButton", topButtons)
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.LayoutOrder = 3
MinimizeBtn.Size = UDim2.new(0, 24, 0, 24)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MinimizeBtn.BackgroundTransparency = 0.3
MinimizeBtn.Text = ""
MinimizeBtn.ZIndex = 7
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 5)
local MinimizeLine = Instance.new("Frame", MinimizeBtn)
MinimizeLine.Name = "Line"
MinimizeLine.AnchorPoint = Vector2.new(0.5, 0.5)
MinimizeLine.Position = UDim2.new(0.5, 0, 0.5, 0)
MinimizeLine.Size = UDim2.new(0, 9, 0, 1.2)
MinimizeLine.BackgroundColor3 = Color3.fromHex("#A0A0A0")
MinimizeLine.BorderSizePixel = 0
MinimizeLine.ZIndex = 8

-- Close Button Reduzido
local CloseBtn = Instance.new("TextButton", topButtons)
CloseBtn.Name = "CloseBtn"
CloseBtn.LayoutOrder = 4
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
CloseBtn.BackgroundTransparency = 0.3
CloseBtn.Text = ""
CloseBtn.ZIndex = 7
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)
local CloseLine1 = Instance.new("Frame", CloseBtn)
CloseLine1.Name = "Line1"
CloseLine1.AnchorPoint = Vector2.new(0.5, 0.5)
CloseLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine1.Size = UDim2.new(0, 10, 0, 1.2)
CloseLine1.Rotation = 45
CloseLine1.BackgroundColor3 = Color3.fromHex("#A0A0A0")
CloseLine1.BorderSizePixel = 0
CloseLine1.ZIndex = 8
local CloseLine2 = Instance.new("Frame", CloseBtn)
CloseLine2.Name = "Line2"
CloseLine2.AnchorPoint = Vector2.new(0.5, 0.5)
CloseLine2.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine2.Size = UDim2.new(0, 10, 0, 1.2)
CloseLine2.Rotation = -45
CloseLine2.BackgroundColor3 = Color3.fromHex("#A0A0A0")
CloseLine2.BorderSizePixel = 0
CloseLine2.ZIndex = 8

-- Linha horizontal reta abaixo da área superior direita
local RightSeparatorLine = Instance.new("Frame", RightPanel)
RightSeparatorLine.Size = UDim2.new(1, -16, 0, 1)
RightSeparatorLine.Position = UDim2.new(0, 8, 0, 50)
RightSeparatorLine.BackgroundColor3 = Color3.fromRGB(80, 20, 25)
RightSeparatorLine.BorderSizePixel = 0
RightSeparatorLine.ZIndex = 7

-- Toggles Area (Abaixo da linha separadora)
local togglesContainer = Instance.new("ScrollingFrame", RightPanel)
togglesContainer.Name = "TogglesContainer"
togglesContainer.Size = UDim2.new(1, 0, 1, -54)
togglesContainer.Position = UDim2.new(0, 0, 0, 54)
togglesContainer.BackgroundTransparency = 1
togglesContainer.BorderSizePixel = 0
togglesContainer.ScrollBarThickness = 2
togglesContainer.ScrollBarImageColor3 = Color3.fromRGB(139, 0, 0)
togglesContainer.ScrollBarImageTransparency = 0.2
togglesContainer.ZIndex = 6
togglesContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

local containerLayout = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
containerLayout.Padding = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local uiPadding = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingBottom = UDim.new(0, 8)

containerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    togglesContainer.CanvasSize = UDim2.new(0, 0, 0, containerLayout.AbsoluteContentSize.Y + 16)
end)

-- Confirm Frame
local confirmFrame = Instance.new("Frame", mainFrame)
confirmFrame.Name = "ConfirmFrame"
confirmFrame.Size = UDim2.new(1, 0, 1, 0)
confirmFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
confirmFrame.BackgroundTransparency = 0.4
confirmFrame.Visible = false
confirmFrame.ZIndex = 50
Instance.new("UICorner", confirmFrame).CornerRadius = UDim.new(0, 9)

local confirmLabel = Instance.new("TextLabel", confirmFrame)
confirmLabel.Size = UDim2.new(1, 0, 0, 30)
confirmLabel.Position = UDim2.new(0, 0, 0.35, -10)
confirmLabel.BackgroundTransparency = 1
confirmLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
confirmLabel.Font = Enum.Font.GothamBold
confirmLabel.TextSize = 14
confirmLabel.Text = UI_TEXT.ConfirmCloseTitle
confirmLabel.ZIndex = 51

local btnYes = Instance.new("TextButton", confirmFrame)
btnYes.Size = UDim2.new(0, 110, 0, 34)
btnYes.Position = UDim2.new(0.5, -115, 0.55, 0)
btnYes.BackgroundColor3 = Color3.fromHex("#8B0000")
btnYes.TextColor3 = Color3.fromRGB(255, 255, 255)
btnYes.Font = Enum.Font.GothamMedium
btnYes.TextSize = 12
btnYes.Text = UI_TEXT.ConfirmBtn
btnYes.ZIndex = 51
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 6)

local btnNo = Instance.new("TextButton", confirmFrame)
btnNo.Size = UDim2.new(0, 110, 0, 34)
btnNo.Position = UDim2.new(0.5, 5, 0.55, 0)
btnNo.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
btnNo.TextColor3 = Color3.fromRGB(180, 180, 180)
btnNo.Font = Enum.Font.GothamMedium
btnNo.TextSize = 12
btnNo.Text = UI_TEXT.CancelBtn
btnNo.ZIndex = 51
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 6)

-- ==================== FUNÇÕES DA UI ====================

local function filterToggles(currentActiveTab, query)
    local searchQuery = (query or ""):lower()
    local itemIndex = 0
    for _, child in ipairs(togglesContainer:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
            local itemTab = child:GetAttribute("Tab") or "Combat"
            local shouldBeVisible = false
            if searchQuery ~= "" then
                local titleLabel = child:FindFirstChild("Title")
                shouldBeVisible = titleLabel and titleLabel.Text:lower():find(searchQuery) ~= nil
            else
                shouldBeVisible = (itemTab == currentActiveTab)
            end
            
            if child.Visible ~= shouldBeVisible or shouldBeVisible then
                child.Visible = shouldBeVisible
                if shouldBeVisible then
                    itemIndex = itemIndex + 1
                    child.Size = UDim2.new(1, -16, 0, 0)
                    child.BackgroundTransparency = 1
                    local t = child:FindFirstChild("Title")
                    local d = child:FindFirstChild("Description")
                    if t then t.TextTransparency = 1 end
                    if d then d.TextTransparency = 1 end
                    task.delay((itemIndex - 1) * 0.02, function()
                        if not child or not child.Parent then return end
                        TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                            Size = UDim2.new(1, -16, 0, 52), BackgroundTransparency = 0.35
                        }):Play()
                        if t then TweenService:Create(t, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
                        if d then TweenService:Create(d, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
                    end)
                end
            end
        end
    end
end

local function selectTab(tabName)
    activeTab = tabName
    local animSpeed = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for name, btn in pairs(tabButtons) do
        local label = btn:FindFirstChild("Label")
        local iconContainer = btn:FindFirstChild("Icon")
        local activeBar = btn:FindFirstChild("ActiveBar")
        if name == tabName then
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(25, 5, 5), BackgroundTransparency = 0.4}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end
            if activeBar then activeBar.Visible = true end
            if iconContainer and iconContainer:FindFirstChild("AccentImage") then
                TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            end
        else
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 1}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(150, 150, 150)}):Play() end
            if activeBar then activeBar.Visible = false end
            if iconContainer and iconContainer:FindFirstChild("AccentImage") then
                TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Color3.fromRGB(150, 150, 150)}):Play()
            end
        end
    end
    togglesContainer.CanvasPosition = Vector2.new(0, 0)
    searchTextBox.Text = ""
    filterToggles(tabName, "")
end

local function createTabBtn(tabName)
    local tabBtn = Instance.new("TextButton", TabsContainer)
    tabBtn.Name = tabName .. "TabBtn"
    tabBtn.Size = UDim2.new(1, -12, 0, 30)
    tabBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text = ""
    tabBtn.ZIndex = 8
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 6)

    local activeBar = Instance.new("Frame", tabBtn)
    activeBar.Name = "ActiveBar"
    activeBar.Size = UDim2.new(0, 3, 0, 16)
    activeBar.Position = UDim2.new(0, 2, 0.5, -8)
    activeBar.BackgroundColor3 = Color3.fromHex("#8B0000")
    activeBar.BorderSizePixel = 0
    activeBar.Visible = false
    activeBar.ZIndex = 12 
    Instance.new("UICorner", activeBar).CornerRadius = UDim.new(1, 0)

    local iconContainer = Instance.new("Frame", tabBtn)
    iconContainer.Name = "Icon"
    iconContainer.Size = UDim2.new(0, 15, 0, 15) 
    iconContainer.Position = UDim2.new(0, 10, 0.5, -7)
    iconContainer.BackgroundTransparency = 1
    iconContainer.ZIndex = 9
    local imageLabel = Instance.new("ImageLabel", iconContainer)
    imageLabel.Name = "AccentImage"
    imageLabel.Size = UDim2.new(1, 0, 1, 0)
    imageLabel.BackgroundTransparency = 1
    imageLabel.ZIndex = 10
    imageLabel.ImageColor3 = Color3.fromRGB(150, 150, 150)
    
    if tabName == "Player" then imageLabel.Image = "rbxthumb://type=Asset&id=78324938264014&w=150&h=150"
    elseif tabName == "Teleports" then imageLabel.Image = "rbxthumb://type=Asset&id=122367250674432&w=150&h=150"
    elseif tabName == "Misc" then imageLabel.Image = "rbxthumb://type=Asset&id=79429182159899&w=150&h=150"
    elseif tabName == "Visuals" then imageLabel.Image = "rbxthumb://type=Asset&id=135604583195835&w=150&h=150"
    elseif tabName == "Combat" then imageLabel.Image = "rbxthumb://type=Asset&id=139442231247295&w=150&h=150" end

    local tabLabel = Instance.new("TextLabel", tabBtn)
    tabLabel.Name = "Label"
    tabLabel.Size = UDim2.new(1, -40, 1, 0) 
    tabLabel.Position = UDim2.new(0, 32, 0, 0) 
    tabLabel.BackgroundTransparency = 1
    tabLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    tabLabel.Font = Enum.Font.GothamMedium
    tabLabel.TextSize = 11
    tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.Text = UI_TEXT.Tabs[tabName] or tabName
    tabLabel.ZIndex = 9

    tabBtn.MouseButton1Click:Connect(function() selectTab(tabName) end)
    tabButtons[tabName] = tabBtn
end

local function createToggle(parent, configKey, tabCategory)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = configKey
    toggleFrame.Size = UDim2.new(1, -16, 0, 52)
    toggleFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    toggleFrame.BackgroundTransparency = 0.35
    toggleFrame.ZIndex = 6
    toggleFrame.ClipsDescendants = true 
    toggleFrame:SetAttribute("Tab", tabCategory)
    toggleFrame:SetAttribute("ConfigKey", configKey)
    toggleFrame.Parent = parent
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", toggleFrame)
    stroke.Color = Color3.fromHex("#141414")
    stroke.Thickness = 1
    
    local optData = UI_TEXT.Options[configKey]
    local titleLabel = Instance.new("TextLabel", toggleFrame)
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(0.7, 0, 0, 16)
    titleLabel.Position = UDim2.new(0, 10, 0, 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromHex("#CCCCCC")
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = optData and optData.Title or configKey
    titleLabel.ZIndex = 6
    
    local descLabel = Instance.new("TextLabel", toggleFrame)
    descLabel.Name = "Description"
    descLabel.Size = UDim2.new(0.7, 0, 0, 26)
    descLabel.Position = UDim2.new(0, 10, 0, 22)
    descLabel.BackgroundTransparency = 1
    descLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 9
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.TextWrapped = true
    descLabel.Text = optData and optData.Desc or ""
    descLabel.ZIndex = 6
    
    local switchTrack = Instance.new("Frame", toggleFrame)
    switchTrack.Size = UDim2.new(0, 38, 0, 18)
    switchTrack.Position = UDim2.new(1, -48, 0.5, -9)
    switchTrack.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
    switchTrack.ZIndex = 6
    Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)
    local switchCircle = Instance.new("Frame", switchTrack)
    switchCircle.Size = UDim2.new(0, 12, 0, 12)
    switchCircle.Position = Configs[configKey] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
    switchCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    switchCircle.ZIndex = 7
    Instance.new("UICorner", switchCircle).CornerRadius = UDim.new(1, 0)
    
    local triggerBtn = Instance.new("TextButton", toggleFrame)
    triggerBtn.Size = UDim2.new(1, 0, 1, 0)
    triggerBtn.BackgroundTransparency = 1
    triggerBtn.Text = ""
    triggerBtn.ZIndex = 8
    
    triggerBtn.MouseButton1Click:Connect(function()
        Configs[configKey] = not Configs[configKey]
        local targetPos   = Configs[configKey] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        local targetColor = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
        local anim = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(switchCircle, anim, {Position = targetPos}):Play()
        TweenService:Create(switchTrack, anim, {BackgroundColor3 = targetColor}):Play()
        if _G.AkatCallbacks and _G.AkatCallbacks[configKey] then task.spawn(_G.AkatCallbacks[configKey], Configs[configKey]) end
    end)
end

-- Funcionalidades dos Botões
local searchExpanded = false
SearchBtn.MouseButton1Click:Connect(function()
    searchExpanded = not searchExpanded
    local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if searchExpanded then
        TweenService:Create(SearchBtn, info, {Size = UDim2.new(0, 120, 0, 24)}):Play()
        TweenService:Create(SearchIcon, info, {Position = UDim2.new(0, 6, 0.5, 0)}):Play()
        searchTextBox.Visible = true
        searchTextBox:CaptureFocus()
    else
        TweenService:Create(SearchBtn, info, {Size = UDim2.new(0, 24, 0, 24)}):Play()
        TweenService:Create(SearchIcon, info, {Position = UDim2.new(0, 6, 0.5, 0)}):Play()
        searchTextBox:ReleaseFocus()
        searchTextBox.Text = ""
        task.delay(0.2, function() if not searchExpanded then searchTextBox.Visible = false end end)
        filterToggles(activeTab, "")
    end
end)
searchTextBox:GetPropertyChangedSignal("Text"):Connect(function() filterToggles(activeTab, searchTextBox.Text) end)

ExpandBtn.MouseButton1Click:Connect(function()
    isExpanded = not isExpanded
    local newSize = isExpanded and UDim2.new(0, 620, 0, 380) or UDim2.new(0, 535, 0, 300)
    TweenService:Create(mainWrapper, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = newSize}):Play()
end)

local function alternarVisibilidadeMenu(abrir)
    menuAberto = abrir
    local tempoAnim = 0.2
    local windowAnim = TweenInfo.new(tempoAnim, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    
    if abrir then
        FloatBtn.Visible = false
        mainWrapper.Visible = true
        mainWrapper.Size = UDim2.new(0, 480, 0, 260)
        AplicarFadeSincronizado(mainWrapper, true, 0)
        
        AplicarFadeSincronizado(mainWrapper, false, tempoAnim)
        TweenService:Create(mainWrapper, windowAnim, {Size = isExpanded and UDim2.new(0, 620, 0, 380) or UDim2.new(0, 535, 0, 300)}):Play()
        filterToggles(activeTab, searchTextBox.Text)
    else
        AplicarFadeSincronizado(mainWrapper, true, tempoAnim)
        TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 480, 0, 260)}):Play()
        
        SharinganSound:Play()
        task.delay(tempoAnim, function()
            if not menuAberto then 
                mainWrapper.Visible = false 
                FloatBtn.Visible = true
                Sharingan.ImageTransparency = 0
            end
        end)
    end
end

-- Botão de Minimizar: Oculta perfeitamente a janela inteira e mantém o flutuante ativo
MinimizeBtn.MouseButton1Click:Connect(function() 
    alternarVisibilidadeMenu(false) 
end)

-- Botão Flutuante: Restaura a UI principal instantaneamente
FloatBtn.MouseButton1Click:Connect(function()
    alternarVisibilidadeMenu(true)
end)

local function AlternarConfirmacao(exibir)
    isConfirmOpen = exibir
    local tempoAnim = 0.15
    if exibir then
        if not confirmBlur then confirmBlur = Instance.new("BlurEffect"); confirmBlur.Size = 0; confirmBlur.Parent = Lighting end
        confirmFrame.Visible = true
        AplicarFadeSincronizado(confirmFrame, true, 0)
        AplicarFadeSincronizado(confirmFrame, false, tempoAnim)
        TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 14}):Play()
    else
        AplicarFadeSincronizado(confirmFrame, true, tempoAnim)
        if confirmBlur then 
            local blurTween = TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 0})
            blurTween:Play()
            blurTween.Completed:Connect(function() if confirmBlur and confirmBlur.Size == 0 then confirmBlur:Destroy(); confirmBlur = nil end end)
        end
        task.delay(tempoAnim, function() if not isConfirmOpen then confirmFrame.Visible = false end end)
    end
end

CloseBtn.MouseButton1Click:Connect(function() AlternarConfirmacao(true) end)
btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)
btnYes.MouseButton1Click:Connect(function()
    local syncTime = 0.2
    if confirmBlur then TweenService:Create(confirmBlur, TweenInfo.new(syncTime, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 0}):Play() end
    AplicarFadeSincronizado(mainWrapper, true, syncTime)
    TweenService:Create(FloatBtn, TweenInfo.new(syncTime, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)}):Play()
    task.wait(syncTime)
    LimparEDesligarAbsolutamente()
    screenGui:Destroy()
end)

local function AplicarEfeitoFisicoBotao(btn, hoverColor)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = Color3.fromRGB(30, 30, 30), BackgroundTransparency = 0.1}):Play()
        if btn.Name == "ExpandBtn" then TweenService:Create(ExpandStroke, TweenInfo.new(0.15), {Color = hoverColor}):Play()
        elseif btn.Name == "MinimizeBtn" then TweenService:Create(btn.Line, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
        elseif btn.Name == "SearchBtn" and not searchExpanded then TweenService:Create(circleStroke, TweenInfo.new(0.15), {Color = hoverColor}):Play(); TweenService:Create(SearchHandle, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
        elseif btn.Name == "CloseBtn" then TweenService:Create(btn.Line1, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play(); TweenService:Create(btn.Line2, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play() end
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 0.3}):Play()
        if btn.Name == "ExpandBtn" then TweenService:Create(ExpandStroke, TweenInfo.new(0.15), {Color = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "MinimizeBtn" then TweenService:Create(btn.Line, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "SearchBtn" then TweenService:Create(circleStroke, TweenInfo.new(0.15), {Color = Color3.fromHex("#A0A0A0")}):Play(); TweenService:Create(SearchHandle, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "CloseBtn" then TweenService:Create(btn.Line1, TweenInfo.new(0.15), {Color3.fromHex("#A0A0A0")}):Play(); TweenService:Create(btn.Line2, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play() end
    end)
end

AplicarEfeitoFisicoBotao(SearchBtn, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(ExpandBtn, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(MinimizeBtn, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(CloseBtn, Color3.fromRGB(255, 60, 60))

createTabBtn("Player")
createTabBtn("Combat")
createTabBtn("Visuals")
createTabBtn("Teleports")
createTabBtn("Misc")

createToggle(togglesContainer, "Speed",       "Player")
createToggle(togglesContainer, "AntiFling",   "Player")
createToggle(togglesContainer, "AutoShoot",   "Combat")
createToggle(togglesContainer, "Reach",       "Combat")
createToggle(togglesContainer, "ESP",         "Visuals")
createToggle(togglesContainer, "TpToGun",     "Teleports")
createToggle(togglesContainer, "SafeSpot",    "Teleports")
createToggle(togglesContainer, "AutoCollect", "Misc")
createToggle(togglesContainer, "ChatRoles",   "Misc")

-- Intro Inicial
local function ExecutarIntroAkat()
    local Blur = Instance.new("BlurEffect"); Blur.Size = 0; Blur.Parent = Lighting
    local IntroFrame = Instance.new("Frame", screenGui); IntroFrame.Size = UDim2.new(1, 0, 1, 0); IntroFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0); IntroFrame.BackgroundTransparency = 1; IntroFrame.ZIndex = 500
    local MaskContainer = Instance.new("Frame", IntroFrame); MaskContainer.AnchorPoint = Vector2.new(0.5, 0.5); MaskContainer.Position = UDim2.new(0.5, 0, 0.5, -10); MaskContainer.Size = UDim2.new(0, 420, 0, 40); MaskContainer.BackgroundTransparency = 1; MaskContainer.ClipsDescendants = true; MaskContainer.ZIndex = 501
    local IntroText = Instance.new("TextLabel", MaskContainer); IntroText.Size = UDim2.new(1, 0, 1, 0); IntroText.Position = UDim2.new(0, 0, 1, 0); IntroText.BackgroundTransparency = 1; IntroText.Font = Enum.Font.GothamBold; IntroText.TextSize = 26; IntroText.RichText = true; IntroText.Text = UI_TEXT.Intro; IntroText.ZIndex = 502
    local IntroLine = Instance.new("Frame", IntroFrame); IntroLine.AnchorPoint = Vector2.new(0.5, 0.5); IntroLine.Position = UDim2.new(0.5, 0, 0.5, 22); IntroLine.Size = UDim2.new(0, 0, 0, 2); IntroLine.BackgroundColor3 = Color3.fromHex("#8B0000"); IntroLine.BorderSizePixel = 0; IntroLine.BackgroundTransparency = 1; IntroLine.ZIndex = 503; Instance.new("UICorner", IntroLine).CornerRadius = UDim.new(1, 0)

    TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.05}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 24}):Play(); task.wait(0.1)
    TweenService:Create(IntroText, TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play(); task.wait(0.2)
    TweenService:Create(IntroLine, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(0, 260, 0, 2)}):Play(); task.wait(1.6) 
    TweenService:Create(IntroText, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
    TweenService:Create(IntroLine, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play(); task.wait(0.3)
    TweenService:Create(IntroFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play(); task.wait(0.3)

    RegistrarTransparencias(mainFrame)
    for _, item in ipairs(mainFrame:GetDescendants()) do RegistrarTransparencias(item) end

    mainWrapper.Visible = true
    FloatBtn.Visible = false 
    local MainScale = Instance.new("UIScale", mainWrapper); MainScale.Scale = 0.85
    AplicarFadeSincronizado(mainWrapper, true, 0)
    AplicarFadeSincronizado(mainWrapper, false, 0.35)
    
    local openScale = TweenService:Create(MainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
    openScale:Play()
    
    openScale.Completed:Connect(function() 
        selectTab("Player") 
        MainScale:Destroy(); IntroFrame:Destroy(); Blur:Destroy()
    end)
end

ExecutarIntroAkat()
