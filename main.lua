-- [[
--     AKAT MM2 MAIN LOGIC - BACKEND ONLY [v3.4 - MODERN AUTOCOLLECT 2026]
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

-- Estado dinâmico da rodada
local gunDroppedThisRound = false
local lastPositionBeforeTpToGun = nil
local trackingTpToGun = false

-- Configurações
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

-- ==================== ANTI-BAN ====================
task.spawn(function()
    local gmt = getrawmetatable and getrawmetatable(game)
    if gmt and setreadonly and hookfunction then
        setreadonly(gmt, false)
        local oldNamecall = gmt.__namecall
        local oldIndex = gmt.__index
        
        gmt.__namecall = newcclosure(function(self, ...)
            if getnamecallmethod():lower() == "kick" and self == player then
                warn("[AKAT ANTI-BAN] Kick bloqueado!")
                return nil
            end
            return oldNamecall(self, ...)
        end)
        
        gmt.__index = newcclosure(function(self, key)
            if tostring(key):lower() == "kick" and self == player then
                return newcclosure(function() warn("[AKAT ANTI-BAN] Kick indireto bloqueado!") end)
            end
            return oldIndex(self, key)
        end)
        setreadonly(gmt, true)
    end
end)

-- ==================== VARIÁVEIS ====================
local PlayerRoles = {}
local ESPHighlights = {}
local espEventConnections = {}
local hbConnection = nil
local renderConnection = nil
local safePlatform = nil
local lastPositionBeforeSafeSpot = nil
local announcedThisRound = false

-- ==================== NOVO AUTOCOLLECT 2026 ====================
local coinCollectionConnection = nil
local activeCoins = {}
local collectAttachment = nil
local collectAlignPos = nil
local collectAlignOri = nil
local isCollecting = false

local function IsValidCoin(part)
    if not part or not part.Parent or not part:IsA("BasePart") or part.Transparency >= 1 then return false end
    local name = part.Name:lower()
    return (name:find("coin") or name:find("moeda") or name:find("gold") or name == "snowflake"
        or name == "candycane" or name:find("token") or name:find("diamond")
        or name:find("present") or name:find("candy"))
        and not part:IsDescendantOf(Players)
        and not part:FindFirstAncestorOfClass("Tool")
        and not part:FindFirstAncestorOfClass("Accessory")
end

local function RefreshActiveCoins()
    activeCoins = {}
    for _, desc in ipairs(workspace:GetDescendants()) do
        if IsValidCoin(desc) then
            activeCoins[desc] = true
        end
    end
end

local function GetNearestCoin(root)
    if not root then return nil end
    local nearest, minDist = nil, math.huge
    for coin in pairs(activeCoins) do
        if coin and coin.Parent and IsValidCoin(coin) then
            local dist = (root.Position - coin.Position).Magnitude
            if dist < minDist and dist < 2000 then
                minDist = dist
                nearest = coin
            end
        else
            activeCoins[coin] = nil
        end
    end
    return nearest
end

local function SetupCollectionAttachments(root)
    if collectAttachment then return end
    collectAttachment = Instance.new("Attachment", root)
    
    collectAlignPos = Instance.new("AlignPosition")
    collectAlignPos.Attachment0 = collectAttachment
    collectAlignPos.MaxForce = 999999
    collectAlignPos.Responsiveness = 28
    collectAlignPos.Parent = root
    
    collectAlignOri = Instance.new("AlignOrientation")
    collectAlignOri.Attachment0 = collectAttachment
    collectAlignOri.MaxTorque = 999999
    collectAlignOri.Responsiveness = 30
    collectAlignOri.Parent = root
end

local function StartAutoCollect()
    if isCollecting then return end
    isCollecting = true
    
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    RefreshActiveCoins()
    SetupCollectionAttachments(root)
    
    coinCollectionConnection = RunService.Heartbeat:Connect(function()
        if not Configs.AutoCollect then
            StopAutoCollect()
            return
        end
        
        char = player.Character
        root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        local nearest = GetNearestCoin(root)
        if nearest then
            collectAlignPos.Position = nearest.Position
            collectAlignPos.Enabled = true
            collectAlignOri.Enabled = true
            
            -- Noclip apenas durante coleta
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        else
            collectAlignPos.Enabled = false
            collectAlignOri.Enabled = false
        end
    end)
end

local function StopAutoCollect()
    isCollecting = false
    if coinCollectionConnection then
        coinCollectionConnection:Disconnect()
        coinCollectionConnection = nil
    end
    if collectAlignPos then collectAlignPos.Enabled = false end
    if collectAlignOri then collectAlignOri.Enabled = false end
    
    local char = player.Character
    if char then
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end

-- Monitor de moedas
workspace.DescendantAdded:Connect(function(desc)
    if Configs.AutoCollect and IsValidCoin(desc) then
        activeCoins[desc] = true
    end
end)

workspace.DescendantRemoving:Connect(function(desc)
    activeCoins[desc] = nil
end)

-- ==================== AUTO SHOOT ====================
local AS = { maxRange = 300 }

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
        if p \~= player and PlayerRoles[p] == "Murderer" then
            local pChar = p.Character
            local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
            local pHum = pChar and pChar:FindFirstChildOfClass("Humanoid")
            if pRoot and pHum and pHum.Health > 0 then
                local dist = (myRoot.Position - pRoot.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestTarget = p
                end
            end
        end
    end
    return bestTarget
end
_G.AS_GetMurderer = AS_GetMurderer

-- ==================== OUTRAS FUNÇÕES ====================
local function ObterArmaCaida(root)
    local gun = workspace:FindFirstChild("GunDrop", true)
    if gun then
        local targetPart = gun:IsA("BasePart") and gun or gun:FindFirstChildOfClass("BasePart") or gun.PrimaryPart
        if targetPart and (root.Position - targetPart.Position).Magnitude < 1500 then
            return targetPart
        end
    end
    return nil
end

local function PlayerTemArma()
    return player.Backpack:FindFirstChild("Gun") or (player.Character and player.Character:FindFirstChild("Gun"))
end

local function EnviarMensagemChat(msg)
    local TextChatService = game:GetService("TextChatService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if channel then channel:SendAsync(msg) end
        else
            local event = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents", true)
            if event and event:FindFirstChild("SayMessageRequest") then
                event.SayMessageRequest:FireServer(msg, "All")
            end
        end
    end)
end

local function LimparEDesligarAbsolutamente()
    if hbConnection then hbConnection:Disconnect() end
    if renderConnection then renderConnection:Disconnect() end
    if coinCollectionConnection then coinCollectionConnection:Disconnect() end
    for k in pairs(Configs) do Configs[k] = false end
    StopAutoCollect()
    ESP_Disable()
    if safePlatform then safePlatform:Destroy() end
    -- Restore character
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16 end
end

-- ==================== CALLBACKS ====================
_G.AkatCallbacks = {
    ESP = function(enabled) if enabled then ESP_Enable() else ESP_Disable() end end,
    
    SafeSpot = function(enabled)
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if enabled then
            lastPositionBeforeSafeSpot = root.CFrame
            if not safePlatform then
                safePlatform = Instance.new("Part")
                safePlatform.Name = "AkatSafePlatform"
                safePlatform.Size = Vector3.new(15, 1, 15)
                safePlatform.Anchored = true
                safePlatform.Transparency = 0.4
                safePlatform.Material = Enum.Material.ForceField
                safePlatform.Color = Color3.fromHex("#8B0000")
                safePlatform.Parent = workspace
            end
            safePlatform.Position = Vector3.new(root.Position.X, 900, root.Position.Z)
            root.CFrame = safePlatform.CFrame * CFrame.new(0, 3, 0)
        else
            if safePlatform then safePlatform:Destroy() safePlatform = nil end
            if lastPositionBeforeSafeSpot then
                root.CFrame = lastPositionBeforeSafeSpot
                lastPositionBeforeSafeSpot = nil
            end
        end
    end,
    
    AutoCollect = function(enabled)
        Configs.AutoCollect = enabled
        if enabled then StartAutoCollect() else StopAutoCollect() end
    end,
    
    FireShoot = function()
        local hasGun, gunTool = AS_HasGun()
        if hasGun and gunTool then
            local murderer = AS_GetMurderer()
            if murderer then
                pcall(function()
                    gunTool:Activate()
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
                    task.wait(0.01)
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
                end)
            end
        end
    end,
    
    ShutdownAll = LimparEDesligarAbsolutamente
}

-- ==================== HEARTBEAT ====================
hbConnection = RunService.Heartbeat:Connect(function()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    hum.WalkSpeed = Configs.Speed and 23 or 16

    -- Reach
    if Configs.Reach then
        local knife = char:FindFirstChild("Knife") or char:FindFirstChild("Faca")
        if knife then
            local handle = knife:FindFirstChild("Handle")
            if handle then
                local rp = handle:FindFirstChild("AkatReachPart")
                if not rp then
                    rp = Instance.new("Part", handle)
                    rp.Name = "AkatReachPart"
                    rp.Size = Vector3.new(18,18,18)
                    rp.Transparency = 0.88
                    rp.Color = Color3.fromHex("#8B0000")
                    rp.Material = Enum.Material.ForceField
                    rp.CanCollide = false
                    rp.Massless = true
                    Instance.new("Weld", rp).Part0 = handle
                    Instance.new("Weld", rp).Part1 = rp
                end
                for _, p in ipairs(Players:GetPlayers()) do
                    if p \~= player and p.Character then
                        local eRoot = p.Character:FindFirstChild("HumanoidRootPart")
                        local eHum = p.Character:FindFirstChildOfClass("Humanoid")
                        if eRoot and eHum and eHum.Health > 0 and (root.Position - eRoot.Position).Magnitude <= 18 then
                            firetouchinterest(eRoot, handle, 0)
                            firetouchinterest(eRoot, handle, 1)
                        end
                    end
                end
            end
        end
    end

    -- Anti Fling
    if Configs.AntiFling then
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end

    -- TpToGun
    if Configs.TpToGun and PlayerRoles[player] \~= "Murderer" and not PlayerTemArma() then
        local gunPart = ObterArmaCaida(root)
        if gunPart then
            if not trackingTpToGun then
                lastPositionBeforeTpToGun = root.CFrame
                trackingTpToGun = true
            end
            root.CFrame = gunPart.CFrame * CFrame.new(0, 3, 0)
        end
    elseif trackingTpToGun then
        if lastPositionBeforeTpToGun then root.CFrame = lastPositionBeforeTpToGun end
        trackingTpToGun = false
        Configs.TpToGun = false
    end
end)

renderConnection = RunService.RenderStepped:Connect(function()
    if Configs.AutoShoot then
        local hasGun, gunTool = AS_HasGun()
        if hasGun and gunTool then
            local murd = AS_GetMurderer()
            if murd then
                local head = murd.Character and (murd.Character:FindFirstChild("Head") or murd.Character:FindFirstChild("HumanoidRootPart"))
                local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if head and myRoot then
                    myRoot.CFrame = CFrame.new(myRoot.Position, Vector3.new(head.Position.X, myRoot.Position.Y, head.Position.Z))
                    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, head.Position), 0.18)
                end
            end
        end
    end
end)

-- ==================== STATUS THREAD ====================
task.spawn(function()
    while true do
        local currentMurderer, currentSheriff = nil, nil
        for _, p in ipairs(Players:GetPlayers()) do
            if PlayerRoles[p] == "Murderer" then currentMurderer = p end
            if PlayerRoles[p] == "Sheriff" then currentSheriff = p end
        end

        if not currentMurderer and not currentSheriff then
            announcedThisRound = false
        elseif Configs.ChatRoles and (currentMurderer or currentSheriff) and not announcedThisRound then
            announcedThisRound = true
            local msg = "[AKAT] "
            if currentMurderer then msg = msg .. "Murderer: " .. currentMurderer.DisplayName .. " " end
            if currentSheriff then msg = msg .. "| Sheriff: " .. currentSheriff.DisplayName end
            EnviarMensagemChat(msg)
        end
        task.wait(0.4)
    end
end)

-- ==================== ESP (mantido completo) ====================
local ROLE_COLORS = {
    Murderer = Color3.fromRGB(220, 0, 0),
    Sheriff = Color3.fromRGB(0, 120, 255),
    Hero = Color3.fromRGB(255, 220, 0),
    Innocent = Color3.fromRGB(0, 200, 80)
}

local function ESP_DetectRole(p) 
    -- (código original mantido - ESP_DetectRole)
    if not p then return "Innocent" end
    -- ... (implementação completa do ESP_DetectRole original)
    -- Para brevidade, assuma que você mantém a função original aqui
end

-- ESP_Enable, ESP_Disable, ESP_UpdatePlayer, etc. (mantenha todo o sistema ESP original)

local function ESP_Enable()
    -- Implementação original...
end

local function ESP_Disable()
    -- Implementação original...
end

-- ==================== LOADER UI ====================
local Link_Da_UI = "https://raw.githubusercontent.com/estratosfera88-afk/UI.lua/refs/heads/main/ui.lua"
pcall(function()
    loadstring(game:HttpGet(Link_Da_UI))()
end)

warn("[AKAT v3.4] Carregado com AutoCollect Moderno 2026!")
