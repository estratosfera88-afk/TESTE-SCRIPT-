-- [[ AKAT MM2 UNIFIED SCRIPT [v5.7 + UI v3.8] ]]

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
                if item:FindFirstChild("KnifeScript") or item:FindFirstChild("Knife") then
                    return "Murderer"
                elseif item:FindFirstChild("GunScript") or item:FindFirstChild("Gun") then
                    if gunDroppedThisRound then return "Hero" else return "Sheriff" end
                end
                
                local n = item.Name:lower()
                if n:find("knife") or n:find("faca") or n:find("sword") or n:find("blade") then
                    return "Murderer"
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
            table.insert(espEventConnections[p], c2)
            table.insert(espEventConnections[p], c3)
        end
    end)

    espEventConnections[p] = connections
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
    Configs.ESP = true
    if espPlayerAddedConn then espPlayerAddedConn:Disconnect() end
    if espPlayerRemovingConn then espPlayerRemovingConn:Disconnect() end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then ESP_ConnectPlayer(p) end
    end

    espPlayerAddedConn = Players.PlayerAdded:Connect(function(p)
        if Configs.ESP then ESP_ConnectPlayer(p) end
    end)
    
    espPlayerRemovingConn = Players.PlayerRemoving:Connect(function(p)
        ESP_DisconnectPlayer(p)
    end)
end

local function ESP_Disable()
    Configs.ESP = false
    if espPlayerAddedConn then espPlayerAddedConn:Disconnect(); espPlayerAddedConn = nil end
    if espPlayerRemovingConn then espPlayerRemovingConn:Disconnect(); espPlayerRemovingConn = nil end
    
    for _, p in ipairs(Players:GetPlayers()) do
        ESP_DisconnectPlayer(p)
    end
    ESP_ClearAll()
end

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
    ESP = function(enabled)
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
                currentCollectTarget = nil
                task.wait(0.5) 
                continue
            end

            if root and hum and hum.Health > 0 then
                local target = ObterMoedaProxima(root)
                if target and target.Parent then
                    if currentCollectTarget ~= target then
                        currentCollectTarget = target
                        if autoCollectTween then autoCollectTween:Cancel() end
                        
                        local goalCFrame = CFrame.new(target.Position)
                        local dist = (root.Position - target.Position).Magnitude
                        local timeToReach = dist / 37
                        
                        autoCollectTween = TweenService:Create(root, TweenInfo.new(timeToReach, Enum.EasingStyle.Linear), {CFrame = goalCFrame})
                        autoCollectTween:Play()
                        autoCollectTween.Completed:Wait() 
                    end
                    
                    pcall(function()
                        firetouchinterest(root, target, 0)
                        firetouchinterest(root, target, 1)
                        
                        for _, part in ipairs(char:GetChildren()) do
                            if part:IsA("BasePart") and (part.Name:find("Foot") or part.Name:find("Leg") or part.Name:find("Torso")) then
                                firetouchinterest(part, target, 0)
                                firetouchinterest(part, target, 1)
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
                    trackingTpToGun = false
                    lastPositionBeforeTpToGun = nil
                    if autoCollectTemporarilyDisabled then
                        autoCollectTemporarilyDisabled = false
                        Configs.AutoCollect = true
                    end
                    continue
                end
                
                local gunPart = ObterArmaCaida(root)
                if gunPart and gunPart.Parent then
                    if not trackingTpToGun then
                        lastPositionBeforeTpToGun = root.CFrame
                        trackingTpToGun = true
                        
                        if Configs.AutoCollect then
                            autoCollectTemporarilyDisabled = true
                            Configs.AutoCollect = false
                            if autoCollectTween then autoCollectTween:Cancel(); autoCollectTween = nil end
                            currentCollectTarget = nil
                        end
                    end
                    root.CFrame = gunPart.CFrame * CFrame.new(0, 3, 0)
                else
                    if trackingTpToGun then
                        if lastPositionBeforeTpToGun then
                            root.CFrame = lastPositionBeforeTpToGun
                        end
                        lastPositionBeforeTpToGun = nil
                        trackingTpToGun = false
                        
                        if autoCollectTemporarilyDisabled then
                            autoCollectTemporarilyDisabled = false
                            Configs.AutoCollect = true
                        end
                    end
                end
            end
        else
            if trackingTpToGun then
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root and lastPositionBeforeTpToGun then
                    root.CFrame = lastPositionBeforeTpToGun
                end
                lastPositionBeforeTpToGun = nil
                trackingTpToGun = false
                
                if autoCollectTemporarilyDisabled then
                    autoCollectTemporarilyDisabled = false
                    Configs.AutoCollect = true
                end
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
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
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
    Intro = '<font color="#FFFFFF">Scripts by | </font><font color="#8B0000">AKAT Community</font>',
    Tabs = {
        Player = "Player",
        Combat = "Combat",
        Visuals = "Visuals",
        Teleports = "Teleports",
        Misc = "Misc"
    },
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
local menuAberto = true
local isMinimized = false
local originalTrans = {}
local confirmBlur = nil
local isConfirmOpen = false
local wasMinimizedBeforeConfirm = false
local searchOpen = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeltaAkatUniversalUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then 
    uiParent = gethui()
else
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then uiParent = cg end
end

if uiParent:FindFirstChild("DeltaAkatUniversalUI") then
    pcall(function() uiParent.DeltaAkatUniversalUI:Destroy() end)
end
screenGui.Parent = uiParent

local function RegistrarTransparencias(objeto)
    if originalTrans[objeto] then return end
    if objeto:IsA("Frame") or objeto:IsA("ScrollingFrame") or objeto:IsA("CanvasGroup") then
        originalTrans[objeto] = { BackgroundTransparency = objeto.BackgroundTransparency }
    elseif objeto:IsA("TextLabel") or objeto:IsA("TextButton") or objeto:IsA("TextBox") then
        originalTrans[objeto] = {
            TextTransparency = objeto.TextTransparency,
            BackgroundTransparency = objeto.BackgroundTransparency,
            TextStrokeTransparency = objeto.TextStrokeTransparency or 1
        }
    elseif objeto:IsA("ImageLabel") or objeto:IsA("ImageButton") then
        originalTrans[objeto] = {
            ImageTransparency = objeto.ImageTransparency,
            BackgroundTransparency = objeto.BackgroundTransparency
        }
    elseif objeto:IsA("UIStroke") then
        originalTrans[objeto] = { Transparency = objeto.Transparency }
    end
end

local function AplicarFadeSincronizado(raiz, fadeOut, duracao)
    local info = TweenInfo.new(duracao, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local function tratarObjeto(obj)
        RegistrarTransparencias(obj)
        local orig = originalTrans[obj]
        if not orig then return end
        if orig.BackgroundTransparency then
            local t = fadeOut and 1 or orig.BackgroundTransparency
            if obj.BackgroundTransparency ~= t then
                if duracao == 0 then obj.BackgroundTransparency = t else TweenService:Create(obj, info, {BackgroundTransparency = t}):Play() end
            end
        end
        if orig.TextTransparency then
            local t = fadeOut and 1 or orig.TextTransparency
            if obj.TextTransparency ~= t then
                if duracao == 0 then obj.TextTransparency = t else TweenService:Create(obj, info, {TextTransparency = t}):Play() end
            end
        end
        if orig.TextStrokeTransparency then
            local t = fadeOut and 1 or orig.TextStrokeTransparency
            if obj.TextStrokeTransparency ~= t then
                if duracao == 0 then obj.TextStrokeTransparency = t else TweenService:Create(obj, info, {TextStrokeTransparency = t}):Play() end
            end
        end
        if orig.ImageTransparency then
            local t = fadeOut and 1 or (obj.Name == "Shadow3D" and 0.5 or orig.ImageTransparency)
            if obj.ImageTransparency ~= t then
                if duracao == 0 then obj.ImageTransparency = t else TweenService:Create(obj, info, {ImageTransparency = t}):Play() end
            end
        end
        if orig.Transparency then
            local t = fadeOut and 1 or orig.Transparency
            if obj.Transparency ~= t then
                if duracao == 0 then obj.Transparency = t else TweenService:Create(obj, info, {Transparency = t}):Play() end
            end
        end
    end
    tratarObjeto(raiz)
    for _, desc in ipairs(raiz:GetDescendants()) do tratarObjeto(desc) end
end

local function CopiarLinkDiscord()
    local link = "https://discord.gg/tfQYbRXT9Q"
    if setclipboard then
        pcall(setclipboard, link)
    elseif toclipboard then
        pcall(toclipboard, link)
    elseif syn and syn.write_clipboard then
        pcall(syn.write_clipboard, link)
    end
end

local notifContainer = Instance.new("Frame", screenGui)
notifContainer.Name = "NotifContainer"
notifContainer.AnchorPoint = Vector2.new(1, 1)
notifContainer.Position = UDim2.new(1, -20, 1, -20)
notifContainer.Size = UDim2.new(0, 260, 1, -40)
notifContainer.BackgroundTransparency = 1
notifContainer.ZIndex = 100

local notifLayout = Instance.new("UIListLayout", notifContainer)
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.Padding = UDim.new(0, 8)

local function CriarNotificacao(titulo, mensagem, tempo)
    tempo = tempo or 4

    local notif = Instance.new("Frame")
    notif.Name = "Notification"
    notif.Size = UDim2.new(1, 0, 0, 52)
    notif.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    notif.BackgroundTransparency = 1
    notif.BorderSizePixel = 0
    notif.ZIndex = 101
    notif.ClipsDescendants = true
    notif.Parent = notifContainer

    local corner = Instance.new("UICorner", notif)
    corner.CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", notif)
    stroke.Color = Color3.fromRGB(35, 35, 35)
    stroke.Thickness = 1.2
    stroke.Transparency = 1

    local accentBar = Instance.new("Frame", notif)
    accentBar.Size = UDim2.new(0, 3, 0, 30)
    accentBar.Position = UDim2.new(0, 10, 0.5, -15)
    accentBar.BackgroundColor3 = Color3.fromHex("#8B0000")
    accentBar.BorderSizePixel = 0
    accentBar.BackgroundTransparency = 1
    accentBar.ZIndex = 102
    Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

    local titleLbl = Instance.new("TextLabel", notif)
    titleLbl.Size = UDim2.new(1, -35, 0, 16)
    titleLbl.Position = UDim2.new(0, 22, 0, 9)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = titulo
    titleLbl.TextColor3 = Color3.fromHex("#8B0000")
    titleLbl.TextTransparency = 1
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 11
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.ZIndex = 102

    local msgLbl = Instance.new("TextLabel", notif)
    msgLbl.Size = UDim2.new(1, -35, 0, 16)
    msgLbl.Position = UDim2.new(0, 22, 0, 27)
    msgLbl.BackgroundTransparency = 1
    msgLbl.Text = mensagem
    msgLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    msgLbl.TextTransparency = 1
    msgLbl.Font = Enum.Font.Gotham
    msgLbl.TextSize = 10
    msgLbl.TextXAlignment = Enum.TextXAlignment.Left
    msgLbl.ZIndex = 102

    local alphaVal = Instance.new("NumberValue")
    alphaVal.Value = 0

    local targetBgTrans = 0.12

    local function atualizarAlpha(alpha)
        if not notif or not notif.Parent then return end
        notif.BackgroundTransparency = 1 - ((1 - targetBgTrans) * alpha)
        stroke.Transparency = 1 - alpha
        accentBar.BackgroundTransparency = 1 - alpha
        titleLbl.TextTransparency = 1 - alpha
        msgLbl.TextTransparency = 1 - alpha
    end

    local conn = alphaVal.Changed:Connect(atualizarAlpha)

    local tweenIn = TweenService:Create(alphaVal, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Value = 1})
    tweenIn:Play()

    task.delay(tempo, function()
        if notif and notif.Parent then
            local tweenOut = TweenService:Create(alphaVal, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {Value = 0})
            tweenOut:Play()
            tweenOut.Completed:Connect(function()
                conn:Disconnect()
                alphaVal:Destroy()
                if notif and notif.Parent then
                    notif:Destroy()
                end
            end)
        end
    end)
end

local function ConfigurarArrastarAkat(inst, trigger)
    trigger = trigger or inst
    local dragging = false
    local dragStart, startPos, currentInput
    
    trigger.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not dragging then
            dragging = true
            currentInput = input
            dragStart = input.Position
            startPos = inst.Position
            
            local dragConnection
            local endConnection
            
            dragConnection = UserInputService.InputChanged:Connect(function(changedInput)
                if changedInput == currentInput or (currentInput.UserInputType == Enum.UserInputType.MouseButton1 and changedInput.UserInputType == Enum.UserInputType.MouseMovement) then
                    local delta = changedInput.Position - dragStart
                    inst.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end)
            
            endConnection = currentInput.Changed:Connect(function()
                if currentInput.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if dragConnection then dragConnection:Disconnect() end
                    if endConnection then endConnection:Disconnect() end
                end
            end)
        end
    end)
end

local FloatBtn = Instance.new("ImageButton", screenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0.12, 0, 0.4, 0)
FloatBtn.Image = "rbxthumb://type=Asset&id=99997714241420&w=150&h=150"
FloatBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
FloatBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
FloatBtn.Visible = false
FloatBtn.ZIndex = 30
FloatBtn.ClipsDescendants = false

local Sharingan = Instance.new("ImageLabel", FloatBtn)
Sharingan.Name = "SharinganEffect"
Sharingan.Size = UDim2.new(2.5, 0, 2.5, 0)
Sharingan.Position = UDim2.new(0.5, 0, 0.5, 0)
Sharingan.AnchorPoint = Vector2.new(0.5, 0.5)
Sharingan.BackgroundTransparency = 1
Sharingan.Image = "rbxassetid://100882509796042"
Sharingan.ZIndex = 29

local SharinganSound = Instance.new("Sound", FloatBtn)
SharinganSound.SoundId = "rbxassetid://6310837681"
SharinganSound.Volume = 1

local RotateTween = TweenService:Create(Sharingan, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360})
RotateTween:Play()

task.spawn(function()
    while true do
        TweenService:Create(Sharingan, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), {ImageTransparency = 0.5}):Play()
        task.wait(2)
        TweenService:Create(Sharingan, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), {ImageTransparency = 0}):Play()
        task.wait(2)
    end
end)

local floatCorner = Instance.new("UICorner", FloatBtn)
floatCorner.CornerRadius = UDim.new(0, 8)

local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Thickness = 1
FloatStroke.Color = Color3.fromRGB(139, 0, 0)

local function AnimarCliqueFloatBtn()
    local originalSize = UDim2.new(0, 44, 0, 44)
    local targetSize   = UDim2.new(0, 41, 0, 41)
    local shrink = TweenService:Create(FloatBtn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize})
    local expand = TweenService:Create(FloatBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = originalSize})
    shrink:Play()
    local c; c = shrink.Completed:Connect(function() expand:Play(); c:Disconnect() end)
end

local mainWrapper = Instance.new("Frame")
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0)
mainWrapper.Size = UDim2.new(0, 520, 0, 300)
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, -160)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible = false
mainWrapper.Parent = screenGui

local shadow3D = Instance.new("ImageLabel")
shadow3D.Name = "Shadow3D"
shadow3D.AnchorPoint = Vector2.new(0.5, 0.5)
shadow3D.Position = UDim2.new(0.5, 0, 0.5, 4)
shadow3D.Size = UDim2.new(1, 40, 1, 40)
shadow3D.BackgroundTransparency = 1
shadow3D.Image = "rbxassetid://6014261993"
shadow3D.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow3D.ImageTransparency = 0.5
shadow3D.ScaleType = Enum.ScaleType.Slice
shadow3D.SliceCenter = Rect.new(49, 49, 450, 450)
shadow3D.ZIndex = 1
shadow3D.Parent = mainWrapper

local mainFrame = Instance.new("CanvasGroup")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundColor3 = Color3.fromHex("#0A0A0A")
mainFrame.BackgroundTransparency = 0.22
mainFrame.BorderSizePixel = 0
mainFrame.ZIndex = 5
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 9)

local frameStroke = Instance.new("UIStroke", mainFrame)
frameStroke.Color = Color3.fromHex("#161616")
frameStroke.Thickness = 1.2
frameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border 
mainFrame.Parent = mainWrapper

local topBar = Instance.new("Frame", mainFrame)
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 52)
topBar.BackgroundTransparency = 1
topBar.ZIndex = 6
topBar.ClipsDescendants = true

local title = Instance.new("TextLabel", topBar)
title.Name = "Title"
title.Size = UDim2.new(0, 200, 0, 22)
title.Position = UDim2.new(0, 16, 0, 10)
title.BackgroundTransparency = 1
title.Text = "AKAT SCRIPTS"
title.TextColor3 = Color3.fromHex("#8B0000")
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 6

local subtitle = Instance.new("TextLabel", topBar)
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(0, 200, 0, 14)
subtitle.Position = UDim2.new(0, 16, 0, 28)
subtitle.BackgroundTransparency = 1
subtitle.Text = "MM2 SCRIPT [BETA v3.6]"
subtitle.TextColor3 = Color3.fromHex("#8B0000")
subtitle.TextSize = 10
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 6

local topButtons = Instance.new("Frame", topBar)
topButtons.Name = "TopButtons"
topButtons.Size = UDim2.new(0, 94, 0, 26)
topButtons.AnchorPoint = Vector2.new(1, 0.5)
topButtons.Position = UDim2.new(1, -16, 0.5, 0)
topButtons.BackgroundTransparency = 1
topButtons.ZIndex = 6

local UIListTop = Instance.new("UIListLayout", topButtons)
UIListTop.FillDirection = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding = UDim.new(0, 8)
UIListTop.SortOrder = Enum.SortOrder.LayoutOrder

local searchBarFrame = Instance.new("Frame", topBar)
searchBarFrame.Name = "SearchBarFrame"
searchBarFrame.AnchorPoint = Vector2.new(1, 0.5)
searchBarFrame.Position = UDim2.new(1, -130, 0.5, 0)
searchBarFrame.Size = UDim2.new(0, 0, 0, 26)
searchBarFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
searchBarFrame.ClipsDescendants = true
searchBarFrame.Visible = false
searchBarFrame.ZIndex = 7
Instance.new("UICorner", searchBarFrame).CornerRadius = UDim.new(0, 13)
local searchStroke = Instance.new("UIStroke", searchBarFrame)
searchStroke.Color = Color3.fromHex("#1F1F1F")
searchStroke.Thickness = 1

local searchTextBox = Instance.new("TextBox", searchBarFrame)
searchTextBox.Name = "SearchTextBox"
searchTextBox.Size = UDim2.new(1, -20, 1, 0)
searchTextBox.Position = UDim2.new(0, 12, 0, 0)
searchTextBox.BackgroundTransparency = 1
searchTextBox.PlaceholderText = UI_TEXT.SearchPlaceholder
searchTextBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
searchTextBox.Text = ""
searchTextBox.TextColor3 = Color3.fromRGB(230, 230, 230)
searchTextBox.Font = Enum.Font.Gotham
searchTextBox.TextSize = 11
searchTextBox.TextXAlignment = Enum.TextXAlignment.Left
searchTextBox.ZIndex = 8

local SearchBtn = Instance.new("TextButton", topButtons)
SearchBtn.Name = "SearchBtn"
SearchBtn.LayoutOrder = 1
SearchBtn.Size = UDim2.new(0, 26, 0, 26)
SearchBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
SearchBtn.BackgroundTransparency = 0.5
SearchBtn.Text = ""
SearchBtn.ZIndex = 7
Instance.new("UICorner", SearchBtn).CornerRadius = UDim.new(0, 5)

local SearchIcon = Instance.new("Frame", SearchBtn)
SearchIcon.Name = "Icon"
SearchIcon.Size = UDim2.new(0, 14, 0, 14)
SearchIcon.AnchorPoint = Vector2.new(0.5, 0.5)
SearchIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
SearchIcon.BackgroundTransparency = 1
SearchIcon.ZIndex = 8

local SearchCircle = Instance.new("Frame", SearchIcon)
SearchCircle.Name = "Circle"
SearchCircle.Size = UDim2.new(0, 8, 0, 8)
SearchCircle.Position = UDim2.new(0, 1, 0, 1)
SearchCircle.BackgroundTransparency = 1
SearchCircle.ZIndex = 8
Instance.new("UICorner", SearchCircle).CornerRadius = UDim.new(1, 0)
local circleStroke = Instance.new("UIStroke", SearchCircle)
circleStroke.Color = Color3.fromHex("#A0A0A0")
circleStroke.Thickness = 1

local SearchHandle = Instance.new("Frame", SearchIcon)
SearchHandle.Name = "Handle"
SearchHandle.Size = UDim2.new(0, 1, 0, 5)
SearchHandle.Position = UDim2.new(0, 9, 0, 8)
SearchHandle.Rotation = -45
SearchHandle.BackgroundColor3 = Color3.fromHex("#A0A0A0")
SearchHandle.BorderSizePixel = 0
SearchHandle.ZIndex = 8

local MinimizeBtn = Instance.new("TextButton", topButtons)
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.LayoutOrder = 2
MinimizeBtn.Size = UDim2.new(0, 26, 0, 26)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
MinimizeBtn.BackgroundTransparency = 0.5
MinimizeBtn.Text = ""
MinimizeBtn.ZIndex = 7
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 5)

local MinimizeLine = Instance.new("Frame", MinimizeBtn)
MinimizeLine.Name = "Line"
MinimizeLine.AnchorPoint = Vector2.new(0.5, 0.5)
MinimizeLine.Position = UDim2.new(0.5, 0, 0.5, 0)
MinimizeLine.Size = UDim2.new(0, 10, 0, 1)
MinimizeLine.BackgroundColor3 = Color3.fromHex("#A0A0A0")
MinimizeLine.BorderSizePixel = 0
MinimizeLine.ZIndex = 8

local CloseBtn = Instance.new("TextButton", topButtons)
CloseBtn.Name = "CloseBtn"
CloseBtn.LayoutOrder = 3
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
CloseBtn.BackgroundTransparency = 0.5
CloseBtn.Text = ""
CloseBtn.ZIndex = 7
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

local CloseLine1 = Instance.new("Frame", CloseBtn)
CloseLine1.Name = "Line1"
CloseLine1.AnchorPoint = Vector2.new(0.5, 0.5)
CloseLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine1.Size = UDim2.new(0, 10, 0, 1)
CloseLine1.Rotation = 45
CloseLine1.BackgroundColor3 = Color3.fromHex("#A0A0A0")
CloseLine1.BorderSizePixel = 0
CloseLine1.ZIndex = 8

local CloseLine2 = Instance.new("Frame", CloseBtn)
CloseLine2.Name = "Line2"
CloseLine2.AnchorPoint = Vector2.new(0.5, 0.5)
CloseLine2.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine2.Size = UDim2.new(0, 10, 0, 1)
CloseLine2.Rotation = -45
CloseLine2.BackgroundColor3 = Color3.fromHex("#A0A0A0")
CloseLine2.BorderSizePixel = 0
CloseLine2.ZIndex = 8

local div = Instance.new("Frame", mainFrame)
div.Name = "Div"
div.Size = UDim2.new(1, -152, 0, 1)
div.Position = UDim2.new(0, 140, 0, 52)
div.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
div.BorderSizePixel = 0
div.ZIndex = 6

local SidebarFrame = Instance.new("Frame", mainFrame)
SidebarFrame.Name = "SidebarFrame"
SidebarFrame.Size = UDim2.new(0, 140, 1, -52)
SidebarFrame.Position = UDim2.new(0, 0, 0, 52)
SidebarFrame.BackgroundTransparency = 1
SidebarFrame.BorderSizePixel = 0
SidebarFrame.ZIndex = 6
SidebarFrame.ClipsDescendants = true

local SidebarBgContainer = Instance.new("Frame", SidebarFrame)
SidebarBgContainer.Name = "SidebarBgContainer"
SidebarBgContainer.Size = UDim2.new(1, 0, 1, 0)
SidebarBgContainer.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
SidebarBgContainer.BackgroundTransparency = 0.35
SidebarBgContainer.BorderSizePixel = 0
SidebarBgContainer.ZIndex = 6

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 9)
SidebarCorner.Parent = SidebarBgContainer

local SidebarSeparator = Instance.new("Frame", SidebarFrame)
SidebarSeparator.Size = UDim2.new(0, 1, 1, 0)
SidebarSeparator.Position = UDim2.new(1, -1, 0, 0)
SidebarSeparator.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
SidebarSeparator.BorderSizePixel = 0
SidebarSeparator.ZIndex = 6

local TabsContainer = Instance.new("ScrollingFrame", SidebarFrame)
TabsContainer.Name = "TabsContainer"
TabsContainer.Size = UDim2.new(1, 0, 1, -66)
TabsContainer.Position = UDim2.new(0, 0, 0, 6)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ZIndex = 7
TabsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
TabsContainer.ElasticBehavior = Enum.ElasticBehavior.Never
TabsContainer.ScrollBarThickness = 2
TabsContainer.ScrollBarImageColor3 = Color3.fromRGB(139, 0, 0)
TabsContainer.ScrollBarImageTransparency = 0.4

local TabsLayout = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabsLayout.Padding = UDim.new(0, 4)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TabsContainer.CanvasSize = UDim2.new(0, 0, 0, TabsLayout.AbsoluteContentSize.Y + 8)
end)

local UserProfileFrame = Instance.new("Frame", SidebarFrame)
UserProfileFrame.Name = "UserProfileFrame"
UserProfileFrame.Size = UDim2.new(1, -16, 0, 50)
UserProfileFrame.Position = UDim2.new(0, 8, 1, -58)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
UserProfileFrame.BackgroundTransparency = 0.2
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex = 7
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 6)

local AvatarImage = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Name = "AvatarImage"
AvatarImage.Size = UDim2.new(0, 32, 0, 32)
AvatarImage.Position = UDim2.new(0, 10, 0.5, -16)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex = 8
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

local DisplayNameLabel = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Name = "DisplayNameLabel"
DisplayNameLabel.Size = UDim2.new(1, -54, 0, 14)
DisplayNameLabel.Position = UDim2.new(0, 48, 0.5, -14)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
DisplayNameLabel.Font = Enum.Font.GothamBold
DisplayNameLabel.TextSize = 11
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLabel.ZIndex = 8

local UsernameLabel = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Name = "UsernameLabel"
UsernameLabel.Size = UDim2.new(1, -54, 0, 12)
UsernameLabel.Position = UDim2.new(0, 48, 0.5, 0)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text = "@" .. player.Name
UsernameLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
UsernameLabel.Font = Enum.Font.Gotham
UsernameLabel.TextSize = 9
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UsernameLabel.ZIndex = 8

local togglesContainer = Instance.new("ScrollingFrame", mainFrame)
togglesContainer.Name = "TogglesContainer"
togglesContainer.Size = UDim2.new(1, -152, 1, -62)
togglesContainer.Position = UDim2.new(0, 146, 0, 58)
togglesContainer.BackgroundTransparency = 1
togglesContainer.BorderSizePixel = 0
togglesContainer.ScrollBarThickness = 3
togglesContainer.ScrollBarImageColor3 = Color3.fromRGB(139, 0, 0)
togglesContainer.ScrollBarImageTransparency = 0.2
togglesContainer.ZIndex = 6
togglesContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
togglesContainer.ElasticBehavior = Enum.ElasticBehavior.Never

local containerLayout = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
containerLayout.Padding = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local uiPadding = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingBottom = UDim.new(0, 8)
uiPadding.PaddingRight = UDim.new(0, 4)

containerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    togglesContainer.CanvasSize = UDim2.new(0, 0, 0, containerLayout.AbsoluteContentSize.Y + 16)
end)

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

local function CriarIconeProcedural(parent, tabName)
    local iconContainer = Instance.new("Frame", parent)
    iconContainer.Name = "Icon"
    iconContainer.Size = UDim2.new(0, 18, 0, 18) 
    iconContainer.Position = UDim2.new(0, 12, 0.5, -9)
    iconContainer.BackgroundTransparency = 1
    iconContainer.ZIndex = 9
    
    local imageLabel = Instance.new("ImageLabel", iconContainer)
    imageLabel.Name = "AccentImage"
    imageLabel.Size = UDim2.new(1, 0, 1, 0)
    imageLabel.BackgroundTransparency = 1
    imageLabel.ZIndex = 10
    imageLabel.ImageColor3 = Color3.fromRGB(180, 180, 180)
    
    if tabName == "Player" then
        imageLabel.Image = "rbxthumb://type=Asset&id=78324938264014&w=150&h=150"
    elseif tabName == "Teleports" then
        imageLabel.Image = "rbxthumb://type=Asset&id=122367250674432&w=150&h=150"
    elseif tabName == "Misc" then
        imageLabel.Image = "rbxthumb://type=Asset&id=79429182159899&w=150&h=150"
    elseif tabName == "Visuals" then
        imageLabel.Image = "rbxthumb://type=Asset&id=135604583195835&w=150&h=150"
    elseif tabName == "Combat" then
        imageLabel.Image = "rbxthumb://type=Asset&id=139442231247295&w=150&h=150"
    end
end

local function RecolorirIcone(iconContainer, targetColor, animSpeed)
    if not iconContainer then return end
    for _, child in ipairs(iconContainer:GetDescendants()) do
        if child.Name == "AccentStroke" and child:IsA("UIStroke") then
            TweenService:Create(child, animSpeed, {Color = targetColor}):Play()
        elseif child.Name == "AccentFill" and child:IsA("Frame") then
            TweenService:Create(child, animSpeed, {BackgroundColor3 = targetColor}):Play()
        elseif child.Name == "AccentImage" and child:IsA("ImageLabel") then
            TweenService:Create(child, animSpeed, {ImageColor3 = targetColor}):Play()
        end
    end
end

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
                    child.Size = UDim2.new(1, -8, 0, 0)
                    child.BackgroundTransparency = 1
                    local t = child:FindFirstChild("Title")
                    local d = child:FindFirstChild("Description")
                    if t then t.TextTransparency = 1 end
                    if d then d.TextTransparency = 1 end
                    task.delay((itemIndex - 1) * 0.02, function()
                        if not child or not child.Parent then return end
                        TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                            Size = UDim2.new(1, -8, 0, 56),
                            BackgroundTransparency = 0.35
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
            local targetTrans = 0.4
            if originalTrans[btn] then
                originalTrans[btn].BackgroundTransparency = targetTrans
            end
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(24, 15, 15), BackgroundTransparency = targetTrans}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end
            if activeBar then activeBar.Visible = true end
            RecolorirIcone(iconContainer, Color3.fromRGB(255, 255, 255), animSpeed)
        else
            local targetTrans = 1
            if originalTrans[btn] then
                originalTrans[btn].BackgroundTransparency = targetTrans
            end
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(12, 12, 12), BackgroundTransparency = targetTrans}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(180, 180, 180)}):Play() end
            if activeBar then activeBar.Visible = false end
            RecolorirIcone(iconContainer, Color3.fromRGB(180, 180, 180), animSpeed)
        end
    end
    togglesContainer.CanvasPosition = Vector2.new(0, 0)
    searchTextBox.Text = ""
    filterToggles(tabName, "")
end

local function createTabBtn(tabName)
    local tabBtn = Instance.new("TextButton", TabsContainer)
    tabBtn.Name = tabName .. "TabBtn"
    tabBtn.Size = UDim2.new(1, -12, 0, 34)
    tabBtn.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text = ""
    tabBtn.ZIndex = 8
    tabBtn.AutoButtonColor = false

    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 6)

    local activeBar = Instance.new("Frame", tabBtn)
    activeBar.Name = "ActiveBar"
    activeBar.AnchorPoint = Vector2.new(0, 0.5)
    activeBar.Size = UDim2.new(0, 3, 0, 18)
    activeBar.Position = UDim2.new(0, 2, 0.5, 0)
    activeBar.BackgroundColor3 = Color3.fromHex("#8B0000")
    activeBar.BorderSizePixel = 0
    activeBar.Visible = false
    activeBar.ZIndex = 12 
    Instance.new("UICorner", activeBar).CornerRadius = UDim.new(1, 0)

    CriarIconeProcedural(tabBtn, tabName)
    local tabLabel = Instance.new("TextLabel", tabBtn)
    tabLabel.Name = "Label"
    tabLabel.Size = UDim2.new(1, -44, 1, 0) 
    tabLabel.Position = UDim2.new(0, 38, 0, 0) 
    tabLabel.BackgroundTransparency = 1
    tabLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    tabLabel.Font = Enum.Font.GothamMedium
    tabLabel.TextSize = 11
    tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.Text = UI_TEXT.Tabs[tabName] or tabName
    tabLabel.ZIndex = 9

    tabBtn.MouseButton1Down:Connect(function()
        TweenService:Create(tabLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {TextSize = 10}):Play()
    end)
    tabBtn.MouseButton1Up:Connect(function()
        TweenService:Create(tabLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {TextSize = 11}):Play()
    end)
    tabBtn.MouseLeave:Connect(function()
        TweenService:Create(tabLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {TextSize = 11}):Play()
        if activeTab ~= tabName then
            TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(12, 12, 12), BackgroundTransparency = 1}):Play()
            TweenService:Create(tabLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {TextColor3 = Color3.fromRGB(180, 180, 180)}):Play()
            RecolorirIcone(tabBtn:FindFirstChild("Icon"), Color3.fromRGB(180, 180, 180), TweenInfo.new(0.15, Enum.EasingStyle.Quad))
        end
    end)
    tabBtn.MouseEnter:Connect(function()
        if activeTab ~= tabName then
            TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(22, 22, 22), BackgroundTransparency = 0.7}):Play()
            TweenService:Create(tabLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {TextColor3 = Color3.fromRGB(220, 220, 220)}):Play()
            RecolorirIcone(tabBtn:FindFirstChild("Icon"), Color3.fromRGB(220, 220, 220), TweenInfo.new(0.15, Enum.EasingStyle.Quad))
        end
    end)
    tabBtn.MouseButton1Click:Connect(function() selectTab(tabName) end)
    tabButtons[tabName] = tabBtn
end

local function createToggle(parent, configKey, tabCategory)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = configKey
    toggleFrame.Size = UDim2.new(1, -8, 0, 56)
    toggleFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
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
    titleLabel.Size = UDim2.new(0.65, 0, 0, 16)
    titleLabel.Position = UDim2.new(0, 12, 0, 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromHex("#CCCCCC")
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = optData and optData.Title or configKey
    titleLabel.ZIndex = 6
    
    local descLabel = Instance.new("TextLabel", toggleFrame)
    descLabel.Name = "Description"
    descLabel.Size = UDim2.new(0.65, 0, 0, 28)
    descLabel.Position = UDim2.new(0, 12, 0, 22)
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
    switchTrack.Size = UDim2.new(0, 40, 0, 20)
    switchTrack.Position = UDim2.new(1, -52, 0.5, -10)
    switchTrack.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
    switchTrack.ZIndex = 6
    Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)
    local trackStroke = Instance.new("UIStroke", switchTrack)
    trackStroke.Color = Color3.fromRGB(45, 45, 45)
    trackStroke.Thickness = 1
    local switchCircle = Instance.new("Frame", switchTrack)
    switchCircle.Size = UDim2.new(0, 14, 0, 14)
    switchCircle.Position = Configs[configKey] and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
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
        local targetPos   = Configs[configKey] and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        local targetColor = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
        local anim = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(switchCircle, anim, {Position = targetPos}):Play()
        TweenService:Create(switchTrack, anim, {BackgroundColor3 = targetColor}):Play()
        
        if _G.AkatCallbacks and _G.AkatCallbacks[configKey] then
            task.spawn(_G.AkatCallbacks[configKey], Configs[configKey])
        end
    end)
end

local function AlternarConfirmacao(exibir)
    isConfirmOpen = exibir
    local tempoAnim = 0.15
    if exibir then
        if not confirmBlur then
            confirmBlur = Instance.new("BlurEffect")
            confirmBlur.Name = "AkatConfirmBlur"
            confirmBlur.Size = 0
            confirmBlur.Parent = Lighting
        end
        confirmFrame.Visible = true
        AplicarFadeSincronizado(confirmFrame, true, 0)
        AplicarFadeSincronizado(confirmFrame, false, tempoAnim)
        TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 14}):Play()
    else
        AplicarFadeSincronizado(confirmFrame, true, tempoAnim)
        if confirmBlur then 
            local blurTween = TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 0})
            blurTween:Play()
            blurTween.Completed:Connect(function()
                if confirmBlur and confirmBlur.Size == 0 then
                    confirmBlur:Destroy()
                    confirmBlur = nil
                end
            end)
        end
        if wasMinimizedBeforeConfirm then
            AplicarFadeSincronizado(SidebarFrame, true, 0.15)
            AplicarFadeSincronizado(togglesContainer, true, 0.15)
            isMinimized = true
            TweenService:Create(mainWrapper, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 520, 0, 52)}):Play()
            task.delay(0.15, function()
                if isMinimized then
                    togglesContainer.Visible = false
                    SidebarFrame.Visible = false
                    div.Visible = false
                end
            end)
        end
        task.delay(tempoAnim, function()
            if not isConfirmOpen then
                confirmFrame.Visible = false
            end
        end)
    end
end

local function executarMinimizacao()
    if isConfirmOpen then return end
    isMinimized = not isMinimized
    local windowAnim = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    
    if isMinimized then
        searchOpen = false
        searchTextBox.Text = ""
        local tween = TweenService:Create(searchBarFrame, windowAnim, {Size = UDim2.new(0, 0, 0, 26), Position = UDim2.new(1, -130, 0.5, 0)})
        tween:Play()
        tween.Completed:Connect(function()
            if isMinimized then searchBarFrame.Visible = false end
        end)
        searchTextBox:ReleaseFocus()
        filterToggles(activeTab, "")

        TweenService:Create(SearchBtn, windowAnim, {Size = UDim2.new(0, 0, 0, 26), BackgroundTransparency = 1}):Play()
        TweenService:Create(circleStroke, windowAnim, {Transparency = 1}):Play()
        TweenService:Create(SearchHandle, windowAnim, {BackgroundTransparency = 1}):Play()

        AplicarFadeSincronizado(SidebarFrame, true, 0.1)
        AplicarFadeSincronizado(togglesContainer, true, 0.1)
        TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 520, 0, 52)}):Play()
        
        task.delay(0.1, function()
            if isMinimized then
                togglesContainer.Visible = false
                SidebarFrame.Visible = false
                div.Visible = false
                SearchBtn.Visible = false
            end
        end)
    else
        div.Visible = true
        SidebarFrame.Visible = true
        togglesContainer.Visible = true
        SearchBtn.Visible = true
        searchBarFrame.Visible = searchOpen

        TweenService:Create(searchBarFrame, windowAnim, {Size = searchOpen and UDim2.new(0, 160, 0, 26) or UDim2.new(0, 0, 0, 26), Position = UDim2.new(1, -130, 0.5, 0)}):Play()
        TweenService:Create(SearchBtn, windowAnim, {Size = UDim2.new(0, 26, 0, 26), BackgroundTransparency = 0.5}):Play()
        TweenService:Create(circleStroke, windowAnim, {Transparency = 0}):Play()
        TweenService:Create(SearchHandle, windowAnim, {BackgroundTransparency = 0}):Play()

        AplicarFadeSincronizado(SidebarFrame, true, 0)
        AplicarFadeSincronizado(togglesContainer, true, 0)
        TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 520, 0, 300)}):Play()
        AplicarFadeSincronizado(SidebarFrame, false, 0.22)
        AplicarFadeSincronizado(togglesContainer, false, 0.22)
        filterToggles(activeTab, searchTextBox.Text)
    end
end

local function alternarVisibilidadeMenu()
    if isConfirmOpen then
        AlternarConfirmacao(false)
    end

    menuAberto = not menuAberto
    local tempoAnim = 0.14
    local windowAnim = TweenInfo.new(tempoAnim, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    if menuAberto then
        mainWrapper.Visible = true
        togglesContainer.Visible = false
        SidebarFrame.Visible = false
        div.Visible = false
        mainWrapper.Size = UDim2.new(0, 520, 0, isMinimized and 52 or 300)
        AplicarFadeSincronizado(mainWrapper, true, 0)
        AplicarFadeSincronizado(mainWrapper, false, tempoAnim)
        local pop = TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 520, 0, isMinimized and 52 or 300)})
        pop:Play()
        pop.Completed:Connect(function()
            if menuAberto and not isMinimized and not isConfirmOpen then
                SidebarFrame.Visible = true
                togglesContainer.Visible = true
                div.Visible = true
                AplicarFadeSincronizado(SidebarFrame, true, 0)
                AplicarFadeSincronizado(SidebarFrame, false, 0.08)
                filterToggles(activeTab, searchTextBox.Text)
            end
        end)
    else
        togglesContainer.Visible = false
        SidebarFrame.Visible = false
        div.Visible = false
        AplicarFadeSincronizado(mainWrapper, true, tempoAnim)
        local hide = TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 520, 0, isMinimized and 52 or 300)})
        hide:Play()
        hide.Completed:Connect(function()
            if not menuAberto then mainWrapper.Visible = false end
        end)
    end
end

local function ExecutarIntroAkat()
    local Blur = Instance.new("BlurEffect")
    Blur.Size = 0
    Blur.Parent = Lighting

    local IntroFrame = Instance.new("Frame", screenGui)
    IntroFrame.Size = UDim2.new(1, 0, 1, 0)
    IntroFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    IntroFrame.BackgroundTransparency = 1
    IntroFrame.ZIndex = 500

    local MaskContainer = Instance.new("Frame", IntroFrame)
    MaskContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    MaskContainer.Position = UDim2.new(0.5, 0, 0.5, -10)
    MaskContainer.Size = UDim2.new(0, 420, 0, 40)
    MaskContainer.BackgroundTransparency = 1
    MaskContainer.ClipsDescendants = true
    MaskContainer.ZIndex = 501

    local IntroText = Instance.new("TextLabel", MaskContainer)
    IntroText.Size = UDim2.new(1, 0, 1, 0)
    IntroText.Position = UDim2.new(0, 0, 1, 0)
    IntroText.BackgroundTransparency = 1
    IntroText.Font = Enum.Font.GothamBold
    IntroText.TextSize = 26
    IntroText.RichText = true
    IntroText.Text = UI_TEXT.Intro
    IntroText.ZIndex = 502

    local IntroLine = Instance.new("Frame", IntroFrame)
    IntroLine.AnchorPoint = Vector2.new(0.5, 0.5)
    IntroLine.Position = UDim2.new(0.5, 0, 0.5, 22)
    IntroLine.Size = UDim2.new(0, 0, 0, 2)
    IntroLine.BackgroundColor3 = Color3.fromHex("#8B0000")
    IntroLine.BorderSizePixel = 0
    IntroLine.BackgroundTransparency = 1
    IntroLine.ZIndex = 503
    Instance.new("UICorner", IntroLine).CornerRadius = UDim.new(1, 0)

    TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.05}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 24}):Play()
    task.wait(0.1)

    TweenService:Create(IntroText, TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
    task.wait(0.2)

    TweenService:Create(IntroLine, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(0, 260, 0, 2)}):Play()
    task.wait(1.6) 

    TweenService:Create(IntroText, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
    TweenService:Create(IntroLine, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play()
    task.wait(0.3)
    
    TweenService:Create(IntroFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play()
    task.wait(0.3)

    RegistrarTransparencias(mainFrame)
    for _, item in ipairs(mainFrame:GetDescendants()) do RegistrarTransparencias(item) end

    mainWrapper.Visible = true
    FloatBtn.Visible = true

    local MainScale = Instance.new("UIScale", mainWrapper)
    MainScale.Scale = 0.85

    AplicarFadeSincronizado(mainWrapper, true, 0)
    mainWrapper.Size = UDim2.new(0, 520, 0, 300)

    AplicarFadeSincronizado(mainWrapper, false, 0.35)
    local openScale = TweenService:Create(MainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
    local openTween = TweenService:Create(mainWrapper, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 520, 0, 300)})
    
    openScale:Play()
    openTween:Play()
    
    openTween.Completed:Connect(function() 
        selectTab("Player") 
        MainScale:Destroy() 
        IntroFrame:Destroy()
        Blur:Destroy()

        CopiarLinkDiscord()
        CriarNotificacao("AKAT COMMUNITY", "Link Discord Copied", 4)
    end)
end

local function AplicarEfeitoFisicoBotao(btn, hoverColor)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = Color3.fromRGB(36, 36, 36), BackgroundTransparency = 0.3}):Play()
        if btn.Name == "MinimizeBtn" then
            TweenService:Create(btn.Line, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = hoverColor}):Play()
        elseif btn.Name == "SearchBtn" then
            TweenService:Create(circleStroke, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {Color = hoverColor}):Play()
            TweenService:Create(SearchHandle, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = hoverColor}):Play()
        elseif btn.Name == "CloseBtn" then
            TweenService:Create(btn.Line1, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = hoverColor}):Play()
            TweenService:Create(btn.Line2, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = hoverColor}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = Color3.fromRGB(10, 10, 10), BackgroundTransparency = 0.5}):Play()
        if btn.Name == "MinimizeBtn" then
            TweenService:Create(btn.Line, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "SearchBtn" then
            TweenService:Create(circleStroke, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {Color = Color3.fromHex("#A0A0A0")}):Play()
            TweenService:Create(SearchHandle, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "CloseBtn" then
            TweenService:Create(btn.Line1, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
            TweenService:Create(btn.Line2, TweenInfo.new(0.15, Enum.EasingStyle.Cubic), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        end
    end)
end

AplicarEfeitoFisicoBotao(SearchBtn, Color3.fromRGB(255, 255, 255))
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

SearchBtn.MouseButton1Click:Connect(function()
    if isMinimized then return end
    searchOpen = not searchOpen
    local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if searchOpen then
        searchBarFrame.Visible = true
        TweenService:Create(searchBarFrame, info, {Size = UDim2.new(0, 160, 0, 26)}):Play()
        searchTextBox:CaptureFocus()
    else
        searchTextBox.Text = ""
        local tween = TweenService:Create(searchBarFrame, info, {Size = UDim2.new(0, 0, 0, 26)})
        tween:Play()
        searchTextBox:ReleaseFocus()
        filterToggles(activeTab, "")
        tween.Completed:Connect(function()
            if not searchOpen then
                searchBarFrame.Visible = false
            end
        end)
    end
end)

searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
    filterToggles(activeTab, searchTextBox.Text)
end)

CloseBtn.MouseButton1Click:Connect(function()
    wasMinimizedBeforeConfirm = isMinimized
    if isMinimized then
        isMinimized = false
        div.Visible = true
        SidebarFrame.Visible = true
        togglesContainer.Visible = true
        searchBarFrame.Visible = searchOpen
        AplicarFadeSincronizado(SidebarFrame, false, 0.15)
        AplicarFadeSincronizado(togglesContainer, false, 0.15)
        TweenService:Create(mainWrapper, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 520, 0, 300)}):Play()
        AlternarConfirmacao(true)
    else
        AlternarConfirmacao(true)
    end
end)

btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)

btnYes.MouseButton1Click:Connect(function()
    local syncTime = 0.18
    if confirmBlur then TweenService:Create(confirmBlur, TweenInfo.new(syncTime, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 0}):Play() end
    AplicarFadeSincronizado(mainWrapper, true, syncTime)
    TweenService:Create(FloatBtn, TweenInfo.new(syncTime, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {ImageTransparency = 1}):Play()
    task.wait(syncTime)
    
    if _G.AkatCallbacks and _G.AkatCallbacks.ShutdownAll then
        _G.AkatCallbacks.ShutdownAll()
    end
    
    pcall(function() if confirmBlur then confirmBlur:Destroy() end end)
    screenGui:Destroy()
end)

FloatBtn.MouseButton1Click:Connect(function()
    AnimarCliqueFloatBtn()
    SharinganSound:Play()
    alternarVisibilidadeMenu()
end)

MinimizeBtn.MouseButton1Click:Connect(executarMinimizacao)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and (input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightShift) then
        alternarVisibilidadeMenu()
    end
end)

ConfigurarArrastarAkat(mainWrapper)
ConfigurarArrastarAkat(FloatBtn)

task.wait(0.1)
RegistrarTransparencias(confirmFrame)
for _, d in ipairs(confirmFrame:GetDescendants()) do RegistrarTransparencias(d) end

task.spawn(ExecutarIntroAkat)
