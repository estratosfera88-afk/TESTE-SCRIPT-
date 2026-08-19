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

-- ==================== PONTE DE COMUNICAÇÃO GLOBAL ====================
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

-- ==================== THREADS LOGICAS ====================
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

-- ==================== DYNAMIC UI COMPONENT ====================

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
local tabButtons = {}
local UIState = "INTRO" -- "OPEN", "MINIMIZED", "TRANSITION", "INTRO"
local isExpanded = false
local originalTrans = {}
local confirmBlur = nil
local isConfirmOpen = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeltaAkatUniversalUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then uiParent = gethui() else pcall(function() uiParent = game:GetService("CoreGui") end) end
if uiParent:FindFirstChild("DeltaAkatUniversalUI") then pcall(function() uiParent.DeltaAkatUniversalUI:Destroy() end) end
screenGui.Parent = uiParent

local function RegistrarTransparencias(objeto)
    if originalTrans[objeto] then return end
    if objeto:IsA("Frame") or objeto:IsA("ScrollingFrame") or objeto:IsA("CanvasGroup") then originalTrans[objeto] = { BackgroundTransparency = objeto.BackgroundTransparency }
    elseif objeto:IsA("TextLabel") or objeto:IsA("TextButton") or objeto:IsA("TextBox") then
        originalTrans[objeto] = { TextTransparency = objeto.TextTransparency, BackgroundTransparency = objeto.BackgroundTransparency, TextStrokeTransparency = objeto.TextStrokeTransparency or 1 }
    elseif objeto:IsA("ImageLabel") or objeto:IsA("ImageButton") then originalTrans[objeto] = { ImageTransparency = objeto.ImageTransparency, BackgroundTransparency = objeto.BackgroundTransparency }
    elseif objeto:IsA("UIStroke") then originalTrans[objeto] = { Transparency = objeto.Transparency } end
end

local function AplicarFadeSincronizado(raiz, fadeOut, duracao)
    local info = TweenInfo.new(duracao, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local function tratarObjeto(obj)
        RegistrarTransparencias(obj)
        local orig = originalTrans[obj]
        if not orig then return end
        if orig.BackgroundTransparency then
            local t = fadeOut and 1 or orig.BackgroundTransparency
            if obj.BackgroundTransparency ~= t then if duracao == 0 then obj.BackgroundTransparency = t else TweenService:Create(obj, info, {BackgroundTransparency = t}):Play() end end
        end
        if orig.TextTransparency then
            local t = fadeOut and 1 or orig.TextTransparency
            if obj.TextTransparency ~= t then if duracao == 0 then obj.TextTransparency = t else TweenService:Create(obj, info, {TextTransparency = t}):Play() end end
        end
        if orig.ImageTransparency then
            local t = fadeOut and 1 or orig.ImageTransparency
            if obj.ImageTransparency ~= t then if duracao == 0 then obj.ImageTransparency = t else TweenService:Create(obj, info, {ImageTransparency = t}):Play() end end
        end
        if orig.Transparency then
            local t = fadeOut and 1 or orig.Transparency
            if obj.Transparency ~= t then if duracao == 0 then obj.Transparency = t else TweenService:Create(obj, info, {Transparency = t}):Play() end end
        end
    end
    tratarObjeto(raiz)
    for _, desc in ipairs(raiz:GetDescendants()) do tratarObjeto(desc) end
end

-- ==================== BOTÃO FLUTUANTE (ANIMAÇÃO SHARINGAN) ====================
local FloatBtn = Instance.new("ImageButton", screenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0.12, 0, 0.4, 0)
FloatBtn.Image = "rbxassetid://139044062702391" 
FloatBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
FloatBtn.Visible = false 
FloatBtn.ZIndex = 30
FloatBtn.ClipsDescendants = false
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)

local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Thickness = 2
local floatStrokeGradient = Instance.new("UIGradient", FloatStroke)
floatStrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(139, 0, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 0, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(139, 0, 0))
})
TweenService:Create(floatStrokeGradient, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360}):Play()

-- Sharingan orbitando ao redor do botão
local Sharingan = Instance.new("ImageLabel", FloatBtn)
Sharingan.Name = "SharinganEffect"
Sharingan.Size = UDim2.new(0, 18, 0, 18)
Sharingan.AnchorPoint = Vector2.new(0.5, 0.5)
Sharingan.Position = UDim2.new(0.5, 0, 0.5, 0)
Sharingan.BackgroundTransparency = 1
Sharingan.Image = "rbxassetid://100882509796042"
Sharingan.ImageTransparency = 0 
Sharingan.ZIndex = 35

local orbitAngle = 0
RunService.RenderStepped:Connect(function(dt)
    if FloatBtn.Visible then
        Sharingan.Rotation = Sharingan.Rotation + (dt * 150)
        orbitAngle = orbitAngle + (dt * 2.5) 
        local radius = 32 -- Distância da órbita externa
        Sharingan.Position = UDim2.new(0.5, math.cos(orbitAngle) * radius, 0.5, math.sin(orbitAngle) * radius)
    end
end)

local SharinganSound = Instance.new("Sound", FloatBtn)
SharinganSound.SoundId = "rbxassetid://6310837681"
SharinganSound.Volume = 0.4

-- Drag do Botão Flutuante
local dragToggle, dragStart, startPos
FloatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragToggle = true; dragStart = input.Position; startPos = FloatBtn.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        FloatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragToggle = false end
end)

-- ==================== INTERFACE PRINCIPAL ====================
local mainWrapper = Instance.new("Frame", screenGui)
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0.5)
mainWrapper.Size = UDim2.new(0, 535, 0, 300)
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible = false

-- Sombreamento Seguro e Uniforme (Sem vazamento de pontas)
local ShadowFrame = Instance.new("ImageLabel", mainWrapper)
ShadowFrame.Name = "DropShadow"
ShadowFrame.Size = UDim2.new(1, 40, 1, 40)
ShadowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
ShadowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
ShadowFrame.BackgroundTransparency = 1
ShadowFrame.Image = "rbxassetid://6015264002"
ShadowFrame.ImageColor3 = Color3.fromRGB(0, 0, 0)
ShadowFrame.ImageTransparency = 0.4
ShadowFrame.ScaleType = Enum.ScaleType.Slice
ShadowFrame.SliceCenter = Rect.new(120, 120, 120, 120) 
ShadowFrame.ZIndex = 1

local mainFrame = Instance.new("Frame", mainWrapper)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 2, 2)
mainFrame.ClipsDescendants = true 
mainFrame.ZIndex = 5
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 9)

local strokeMain = Instance.new("UIStroke", mainFrame)
strokeMain.Color = Color3.fromRGB(60, 10, 15)
strokeMain.Thickness = 1.2

-- Gradient Red Unificado da UI
local mainGradient = Instance.new("UIGradient", mainFrame)
mainGradient.Rotation = 90
mainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 0, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 0, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 0, 0))
})
mainGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.25),
    NumberSequenceKeypoint.new(0.5, 0.05),
    NumberSequenceKeypoint.new(1, 0.3)
})

-- Efeito de Linha/Luz sutil animado
local SweepEffect = Instance.new("Frame", mainFrame)
SweepEffect.Size = UDim2.new(0, 70, 2, 0)
SweepEffect.Position = UDim2.new(-0.5, 0, -0.5, 0)
SweepEffect.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
SweepEffect.Rotation = 15
SweepEffect.ZIndex = 5
SweepEffect.BorderSizePixel = 0

local sweepGradient = Instance.new("UIGradient", SweepEffect)
sweepGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.5, 0.88),
    NumberSequenceKeypoint.new(1, 1)
})
TweenService:Create(SweepEffect, TweenInfo.new(4.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Position = UDim2.new(1.5, 0, -0.5, 0)}):Play()

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

-- Layout Esquerdo Ajustado (Mais Fino)
local LeftPanel = Instance.new("Frame", mainFrame)
LeftPanel.Name = "LeftPanel"
LeftPanel.Size = UDim2.new(0, 160, 1, 0)
LeftPanel.Position = UDim2.new(0, 0, 0, 0)
LeftPanel.BackgroundTransparency = 1
LeftPanel.ZIndex = 6

-- Layout Direito
local RightPanel = Instance.new("Frame", mainFrame)
RightPanel.Name = "RightPanel"
RightPanel.Size = UDim2.new(1, -160, 1, 0)
RightPanel.Position = UDim2.new(0, 160, 0, 0)
RightPanel.BackgroundTransparency = 1
RightPanel.ZIndex = 6

-- ==================== LEFT PANEL (HEADER E MENU) ====================
local titleContainer = Instance.new("Frame", LeftPanel)
titleContainer.Size = UDim2.new(1, 0, 0, 36)
titleContainer.Position = UDim2.new(0, 12, 0, 6)
titleContainer.BackgroundTransparency = 1
titleContainer.ZIndex = 6

local title = Instance.new("TextLabel", titleContainer)
title.Size = UDim2.new(1, 0, 0, 16)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "AKATSUKI SCRIPTS"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextSize = 12
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 7

local subtitle = Instance.new("TextLabel", titleContainer)
subtitle.Size = UDim2.new(1, 0, 0, 14)
subtitle.Position = UDim2.new(0, 0, 0, 16)
subtitle.BackgroundTransparency = 1
subtitle.Text = "MM2 SCRIPT | by zeni <3"
subtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
subtitle.TextTransparency = 0.4
subtitle.TextSize = 9
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 7

-- Badge UI V3.8
local BadgeFrame = Instance.new("Frame", titleContainer)
BadgeFrame.Size = UDim2.new(0, 48, 0, 16)
BadgeFrame.Position = UDim2.new(0, 114, 0, 0) 
BadgeFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
BadgeFrame.BorderSizePixel = 0
BadgeFrame.ZIndex = 7
Instance.new("UICorner", BadgeFrame).CornerRadius = UDim.new(1, 0)

local BadgeGrad = Instance.new("UIGradient", BadgeFrame)
BadgeGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 25)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 5, 5))
})

local BadgeText = Instance.new("TextLabel", BadgeFrame)
BadgeText.Size = UDim2.new(1, 0, 1, 0)
BadgeText.BackgroundTransparency = 1
BadgeText.Text = "UI V3.8"
BadgeText.TextColor3 = Color3.fromRGB(160, 255, 160) 
BadgeText.Font = Enum.Font.GothamBold
BadgeText.TextSize = 8
BadgeText.ZIndex = 8

local LeftSeparatorLine = Instance.new("Frame", LeftPanel)
LeftSeparatorLine.Size = UDim2.new(1, -12, 0, 1)
LeftSeparatorLine.Position = UDim2.new(0, 12, 0, 40)
LeftSeparatorLine.BackgroundColor3 = Color3.fromRGB(80, 20, 25)
LeftSeparatorLine.BorderSizePixel = 0
LeftSeparatorLine.ZIndex = 7

-- Scrollbar no Painel Esquerdo
local TabsContainer = Instance.new("ScrollingFrame", LeftPanel)
TabsContainer.Name = "TabsContainer"
TabsContainer.Size = UDim2.new(1, -8, 1, -100)
TabsContainer.Position = UDim2.new(0, 4, 0, 46)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ZIndex = 7
TabsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
TabsContainer.ScrollBarThickness = 2 
TabsContainer.ScrollBarImageColor3 = Color3.fromRGB(139, 0, 0)
TabsContainer.ScrollBarImageTransparency = 0.2

local TabsLayout = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabsLayout.Padding = UDim.new(0, 4)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TabsContainer.CanvasSize = UDim2.new(0, 0, 0, TabsLayout.AbsoluteContentSize.Y + 8)
end)

local UserProfileFrame = Instance.new("Frame", LeftPanel)
UserProfileFrame.Size = UDim2.new(1, -20, 0, 46)
UserProfileFrame.Position = UDim2.new(0, 10, 1, -52)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(20, 12, 15)
UserProfileFrame.BackgroundTransparency = 0.35
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex = 7
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 7)

local profileStroke = Instance.new("UIStroke", UserProfileFrame)
profileStroke.Color = Color3.fromRGB(50, 18, 22)
profileStroke.Thickness = 1

local AvatarImage = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Size = UDim2.new(0, 30, 0, 30)
AvatarImage.Position = UDim2.new(0, 8, 0.5, -15)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex = 8
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

local DisplayNameLabel = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Size = UDim2.new(1, -70, 0, 14)
DisplayNameLabel.Position = UDim2.new(0, 44, 0.5, -13)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
DisplayNameLabel.Font = Enum.Font.GothamBold
DisplayNameLabel.TextSize = 10
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLabel.ZIndex = 8

local UsernameLabel = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Size = UDim2.new(1, -70, 0, 12)
UsernameLabel.Position = UDim2.new(0, 44, 0.5, 1)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text = "@" .. player.Name
UsernameLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
UsernameLabel.Font = Enum.Font.Gotham
UsernameLabel.TextSize = 9
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UsernameLabel.ZIndex = 8

-- Botão Privacidade (Novos Ícones e Tamanho Ajustado)
local PrivacyBtn = Instance.new("ImageButton", UserProfileFrame)
PrivacyBtn.Size = UDim2.new(0, 18, 0, 18)
PrivacyBtn.Position = UDim2.new(1, -24, 0.5, -9)
PrivacyBtn.BackgroundColor3 = Color3.fromRGB(30, 15, 18)
PrivacyBtn.BackgroundTransparency = 0.2
PrivacyBtn.Image = ""
PrivacyBtn.ZIndex = 9
Instance.new("UICorner", PrivacyBtn).CornerRadius = UDim.new(0, 4)

local privacyStroke = Instance.new("UIStroke", PrivacyBtn)
privacyStroke.Color = Color3.fromRGB(90, 25, 25)
privacyStroke.Thickness = 1

local PrivacyIcon = Instance.new("ImageLabel", PrivacyBtn)
PrivacyIcon.Size = UDim2.new(0, 12, 0, 12) 
PrivacyIcon.AnchorPoint = Vector2.new(0.5, 0.5)
PrivacyIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
PrivacyIcon.BackgroundTransparency = 1
PrivacyIcon.Image = "rbxassetid://103096515071530" 
PrivacyIcon.ImageColor3 = Color3.fromRGB(220, 60, 60)
PrivacyIcon.ZIndex = 10

local isPrivate = false
PrivacyBtn.MouseButton1Click:Connect(function()
    isPrivate = not isPrivate
    PrivacyIcon.Image = isPrivate and "rbxassetid://85795266774996" or "rbxassetid://103096515071530"
    if isPrivate then
        DisplayNameLabel.Text = string.rep("*", #player.DisplayName)
        UsernameLabel.Text = "@" .. string.rep("*", #player.Name)
    else
        DisplayNameLabel.Text = player.DisplayName
        UsernameLabel.Text = "@" .. player.Name
    end
end)

-- ==================== RIGHT PANEL ====================
local topButtons = Instance.new("Frame", RightPanel)
topButtons.Size = UDim2.new(1, -12, 0, 36)
topButtons.Position = UDim2.new(0, 0, 0, 4)
topButtons.BackgroundTransparency = 1
topButtons.ZIndex = 6

local UIListTop = Instance.new("UIListLayout", topButtons)
UIListTop.FillDirection = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding = UDim.new(0, 6)
UIListTop.SortOrder = Enum.SortOrder.LayoutOrder

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
ExpandSquare.Size = UDim2.new(0, 7, 0, 7)
ExpandSquare.AnchorPoint = Vector2.new(0.5, 0.5)
ExpandSquare.Position = UDim2.new(0.5, 0, 0.5, 0)
ExpandSquare.BackgroundTransparency = 1
ExpandSquare.ZIndex = 8
local ExpandStroke = Instance.new("UIStroke", ExpandSquare)
ExpandStroke.Color = Color3.fromHex("#A0A0A0")
ExpandStroke.Thickness = 1 

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

local RightSeparatorLine = Instance.new("Frame", RightPanel)
RightSeparatorLine.Size = UDim2.new(1, 0, 0, 1)
RightSeparatorLine.Position = UDim2.new(0, 0, 0, 40)
RightSeparatorLine.BackgroundColor3 = Color3.fromRGB(80, 20, 25)
RightSeparatorLine.BorderSizePixel = 0
RightSeparatorLine.ZIndex = 7

local togglesContainer = Instance.new("ScrollingFrame", RightPanel)
togglesContainer.Name = "TogglesContainer"
togglesContainer.Size = UDim2.new(1, 0, 1, -48)
togglesContainer.Position = UDim2.new(0, 0, 0, 46)
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
    tabLabel.Size = UDim2.new(1, -34, 1, 0) 
    tabLabel.Position = UDim2.new(0, 32, 0, 0) 
    tabLabel.BackgroundTransparency = 1
    tabLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    tabLabel.Font = Enum.Font.GothamMedium
    tabLabel.TextSize = 10
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

-- Funcionalidades da Search Bar com Timer de Inatividade
local searchExpanded = false
local searchInactivityTimer = nil

local function CloseSearchSmoothly()
    if not searchExpanded then return end
    searchExpanded = false
    local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    TweenService:Create(SearchBtn, info, {Size = UDim2.new(0, 24, 0, 24)}):Play()
    TweenService:Create(SearchIcon, info, {Position = UDim2.new(0, 6, 0.5, 0)}):Play()
    searchTextBox:ReleaseFocus()
    task.delay(0.15, function() if not searchExpanded then searchTextBox.Visible = false end end)
    filterToggles(activeTab, "")
end

SearchBtn.MouseButton1Click:Connect(function()
    if UIState == "TRANSITION" then return end
    searchExpanded = not searchExpanded
    local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if searchExpanded then
        TweenService:Create(SearchBtn, info, {Size = UDim2.new(0, 120, 0, 24)}):Play()
        TweenService:Create(SearchIcon, info, {Position = UDim2.new(0, 6, 0.5, 0)}):Play()
        searchTextBox.Visible = true
        searchTextBox:CaptureFocus()
        searchTextBox.Text = ""
    else
        CloseSearchSmoothly()
    end
end)

searchTextBox:GetPropertyChangedSignal("Text"):Connect(function() 
    filterToggles(activeTab, searchTextBox.Text)
    if searchInactivityTimer then task.cancel(searchInactivityTimer) end
    searchInactivityTimer = task.delay(4, function()
        if searchExpanded and not searchTextBox:IsFocused() then CloseSearchSmoothly() end
    end)
end)

UserInputService.InputBegan:Connect(function(input)
    if searchExpanded and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        local pos = input.Position
        local absPos = SearchBtn.AbsolutePosition
        local absSize = SearchBtn.AbsoluteSize
        if pos.X < absPos.X or pos.X > absPos.X + absSize.X or pos.Y < absPos.Y or pos.Y > absPos.Y + absSize.Y then
            CloseSearchSmoothly()
        end
    end
end)

ExpandBtn.MouseButton1Click:Connect(function()
    if UIState == "TRANSITION" then return end
    isExpanded = not isExpanded
    local newSize = isExpanded and UDim2.new(0, 620, 0, 380) or UDim2.new(0, 535, 0, 300)
    TweenService:Create(mainWrapper, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = newSize}):Play()
end)

-- Sistema de Visibilidade Seguro para o FloatBtn
local function alternarVisibilidadeMenu(abrir)
    if UIState == "TRANSITION" then return end
    if abrir and UIState == "OPEN" then return end
    if not abrir and UIState == "MINIMIZED" then return end

    UIState = "TRANSITION"
    local tempoAnim = 0.25
    local windowAnim = TweenInfo.new(tempoAnim, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    
    if abrir then
        mainWrapper.Visible = true
        mainWrapper.Size = UDim2.new(0, 480, 0, 260)
        AplicarFadeSincronizado(mainWrapper, true, 0)
        AplicarFadeSincronizado(mainWrapper, false, tempoAnim)
        TweenService:Create(mainWrapper, windowAnim, {Size = isExpanded and UDim2.new(0, 620, 0, 380) or UDim2.new(0, 535, 0, 300)}):Play()
        filterToggles(activeTab, searchTextBox.Text)
        
        task.delay(tempoAnim, function()
            UIState = "OPEN"
        end)
    else
        -- O botão flutuante SEMPRE FICA VISÍVEL, evitamos sumi-lo.
        AplicarFadeSincronizado(mainWrapper, true, tempoAnim)
        TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 480, 0, 260)}):Play()
        
        task.delay(tempoAnim, function()
            mainWrapper.Visible = false 
            UIState = "MINIMIZED"
        end)
    end
end

-- Botão de Minimizar da Janela
MinimizeBtn.MouseButton1Click:Connect(function() 
    alternarVisibilidadeMenu(false) 
end)

-- Botão flutuante abre a interface (E TOCA SOM)
FloatBtn.MouseButton1Click:Connect(function()
    if UIState == "MINIMIZED" then
        SharinganSound:Play()
        alternarVisibilidadeMenu(true)
    end
end)

local function AlternarConfirmacao(exibir)
    if UIState == "TRANSITION" then return end
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
    FloatBtn.Visible = true -- SEMPRE VISÍVEL!
    local MainScale = Instance.new("UIScale", mainWrapper); MainScale.Scale = 0.85
    AplicarFadeSincronizado(mainWrapper, true, 0)
    AplicarFadeSincronizado(mainWrapper, false, 0.35)
    
    local openScale = TweenService:Create(MainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
    openScale:Play()
    
    openScale.Completed:Connect(function() 
        selectTab("Player") 
        MainScale:Destroy(); IntroFrame:Destroy(); Blur:Destroy()
        UIState = "OPEN"
    end)
end

ExecutarIntroAkat()
