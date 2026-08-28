-- [[
--     AKAT MM2 MAIN LOGIC - FULLY UPDATED & OPTIMIZED [v6.0 - VISUALS / TELEPORTS / TARGETED ACTIONS 2026]
--     Compatível com Delta Mobile & PC | MM2 (2026)
--     BACKEND ONLY — sem código de interface visual
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local mouse = player:GetMouse()
local VirtualInputManager = game:GetService("VirtualInputManager")

-- ==================== GUARD CONTRA EXECUÇÃO DUPLICADA ====================
if _G.AkatLogicRunning then
    pcall(function()
        if _G.AkatCallbacks and _G.AkatCallbacks.ShutdownAll then
            _G.AkatCallbacks.ShutdownAll()
        end
    end)
end
_G.AkatLogicRunning = true

-- ==================== ESTADO DINÂMICO DA RODADA ====================
local gunDroppedThisRound = false
local lastPositionBeforeTpToGun = nil
local trackingTpToGun = false
local autoFarmTemporarilyDisabled = false
local autoShootConnection = nil
local autoShootFiring = false
local knifeThrowFiring = false
local knifeThrowTarget = nil
local knifeThrowConnection = nil
local roundGeneration = 0
local characterConnection = nil
local xrayDescendantConnection = nil
local XRayParts = {}
local noclipEnabled = false

-- ==================== CONFIGURAÇÕES LOCAIS DO BACKEND ====================
local Configs = {
    ESP          = false,
    Name         = false,
    Tracer       = false,
    ViewReach    = false,
    AutoShoot    = false,
    Speed        = false,
    SpeedValue   = 16,
    JumpPower    = false,
    JumpPowerValue = 50,
    Reach        = false,
    ReachValue   = 18,
    AntiFling    = false,
    TpToGun      = false,
    TpLobby      = false,
    TpMap        = false,
    SafeSpot     = false,
    AutoFarm     = false,
    ChatRoles    = false,
    KnifeThrow   = false,
    XRay         = false,
    KillAll      = false,
    Invisibility = false
}
_G.Configs = Configs

-- ==================== CAMADA DE CACHE CENTRALIZADO ====================
local CachedState = {
    HasGun   = false,
    Murderer = nil,
    Coins    = {}
}

local function PlayerTemArma()
    return CachedState.HasGun
end

local function AS_GetMurderer()
    return CachedState.Murderer
end
_G.AS_GetMurderer = AS_GetMurderer

-- ==================== ANTI-BAN / METAMETHOD HOOKS ====================
local oldIndex    = nil
local oldNamecall = nil

task.spawn(function()
    local gmt = getrawmetatable and getrawmetatable(game)
    if gmt and setreadonly and hookfunction then
        setreadonly(gmt, false)
        oldNamecall = gmt.__namecall
        oldIndex    = gmt.__index

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

            if self == mouse then
                -- Silent target used only while the one-shot Auto Shoot press is active.
                if Configs.AutoShoot and autoShootFiring then
                    if key == "Hit" or key == "hit" then
                        local murderer = CachedState.Murderer
                        if murderer and murderer.Character then
                            local head = murderer.Character:FindFirstChild("Head")
                            local root = murderer.Character:FindFirstChild("HumanoidRootPart")
                            if head and root then
                                local velocity = root.AssemblyLinearVelocity or root.Velocity or Vector3.zero
                                if velocity.Magnitude > 80 then velocity = Vector3.zero end
                                local targetPosition = head.Position + (velocity * 0.045)
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

                -- Silent target used only while the one-shot Knife Throw press is active.
                if Configs.KnifeThrow and knifeThrowFiring and knifeThrowTarget then
                    local targetChar = knifeThrowTarget.Character
                    local targetHead = targetChar and targetChar:FindFirstChild("Head")
                    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
                    if key == "Hit" or key == "hit" then
                        if targetHead and targetRoot then
                            local velocity = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity or Vector3.zero
                            if velocity.Magnitude > 80 then velocity = Vector3.zero end
                            return CFrame.new(targetHead.Position + (velocity * 0.045))
                        end
                    elseif key == "Target" or key == "target" then
                        if targetHead then return targetHead end
                    end
                end
            end

            return oldIndex(self, key)
        end)

        setreadonly(gmt, true)
    end
end)

-- ==================== VARIÁVEIS DE ESTADO INTERNAS ====================
local PlayerRoles          = {}
local ESPHighlights        = {}
local espEventConnections  = {}
local espPlayerAddedConn   = nil
local espPlayerRemovingConn = nil
local ESP_UpdatePlayer     
local hbConnection         = nil
local steppedConnection    = nil
local safePlatform         = nil
local lastPositionBeforeSafeSpot = nil
local announcedThisRound   = false
local currentFarmTarget = nil
local autoFarmTween     = nil

local ROLE_COLORS = {
    Murderer = Color3.fromRGB(220, 0,   0),
    Sheriff  = Color3.fromRGB(0,   120, 255),
    Hero     = Color3.fromRGB(255, 220, 0),
    Innocent = Color3.fromRGB(0,   200, 80),
}

-- ==================== SISTEMAS AUXILIARES ====================
local function ESP_DetectRole(p)
    if not p or not p.Parent then return "Innocent" end

    local function checkAttr(target)
        if not target then return nil end
        local role = target:GetAttribute("Role") or target:GetAttribute("role") or target:GetAttribute("MMRole")
        if not role then
            local roleValue = target:FindFirstChild("Role") or target:FindFirstChild("role") or target:FindFirstChild("MMRole")
            if roleValue and roleValue:IsA("StringValue") then
                role = roleValue.Value
            end
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
                    if gunDroppedThisRound then return "Hero" else return "Sheriff" end
                end
                local n = item.Name:lower()
                if n:find("knife") or n:find("faca") or n:find("sword") or n:find("blade") then
                    return "Murderer"
                elseif n:find("gun") or n:find("pistol") or n:find("revolver") or n:find("arma")
                    or n:find("luger") or n:find("blaster") or n:find("laser") or n:find("shark")
                    or n:find("fang") or n:find("seer") then
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

    local char  = p.Character
    local role  = ESP_DetectRole(p)
    PlayerRoles[p] = role

    local color = ROLE_COLORS[role] or ROLE_COLORS.Innocent
    local hl    = char:FindFirstChild("AkatESP")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name               = "AkatESP"
        hl.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency   = 0.3
        hl.OutlineTransparency = 0
        hl.Parent             = char
        ESPHighlights[p]      = hl
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

    local connections = {}
    espEventConnections[p] = connections

    table.insert(connections, p.CharacterAdded:Connect(function(char)
        roundGeneration = roundGeneration + 1
        task.wait(0.15)
        if not Configs.ESP then return end
        ESP_UpdatePlayer(p)

        table.insert(connections, char.ChildAdded:Connect(function()
            task.defer(function()
                if Configs.ESP then ESP_UpdatePlayer(p) end
            end)
        end))
        table.insert(connections, char.ChildRemoved:Connect(function()
            task.defer(function()
                if Configs.ESP then ESP_UpdatePlayer(p) end
            end)
        end))
    end))

    table.insert(connections, p.CharacterRemoving:Connect(function()
        RemoveVisual(p)
        PlayerRoles[p] = nil
    end))

    local bp = p:FindFirstChildOfClass("Backpack") or p:FindFirstChild("Backpack")
    if bp then
        table.insert(connections, bp.ChildAdded:Connect(function()
            task.defer(function()
                if Configs.ESP then ESP_UpdatePlayer(p) end
            end)
        end))
        table.insert(connections, bp.ChildRemoved:Connect(function()
            task.defer(function()
                if Configs.ESP then ESP_UpdatePlayer(p) end
            end)
        end))
    end

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

-- ==================== NAME / TRACER / VIEW REACH ====================
local NameTags = {}
local Tracers = {}
local ReachBoxes = {}

local function RemoveVisual(p)
    if NameTags[p] then pcall(function() NameTags[p]:Destroy() end); NameTags[p] = nil end
    if Tracers[p] then
        pcall(function() Tracers[p].a:Destroy() end)
        pcall(function() Tracers[p].b:Destroy() end)
        pcall(function() Tracers[p].beam:Destroy() end)
        Tracers[p] = nil
    end
    if ReachBoxes[p] then pcall(function() ReachBoxes[p]:Destroy() end); ReachBoxes[p] = nil end
end

local function UpdateName(p)
    if p == player or not p.Character or not Configs.Name then
        if NameTags[p] then pcall(function() NameTags[p]:Destroy() end); NameTags[p]=nil end
        return
    end
    local head = p.Character:FindFirstChild("Head")
    if not head then return end
    local role = ESP_DetectRole(p); PlayerRoles[p] = role
    local color = ROLE_COLORS[role] or ROLE_COLORS.Innocent
    local tag = NameTags[p]
    if not tag or not tag.Parent then
        tag = Instance.new("BillboardGui")
        tag.Name = "AkatName"
        tag.Size = UDim2.fromOffset(140, 26)
        tag.StudsOffset = Vector3.new(0, 2.8, 0)
        tag.AlwaysOnTop = true
        tag.Parent = head
        local label = Instance.new("TextLabel")
        label.Name = "Name"
        label.Size = UDim2.fromScale(1,1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextStrokeTransparency = 0.55
        label.Parent = tag
        NameTags[p] = tag
    end
    local label = tag:FindFirstChild("Name")
    if label then label.Text = "[" .. p.DisplayName .. "]"; label.TextColor3 = color end
end

local function UpdateTracer(p)
    if p == player or not p.Character or not Configs.Tracer then
        if Tracers[p] then
            pcall(function() Tracers[p].a:Destroy() end); pcall(function() Tracers[p].b:Destroy() end); pcall(function() Tracers[p].beam:Destroy() end)
            Tracers[p]=nil
        end
        return
    end
    local targetRoot = p.Character:FindFirstChild("HumanoidRootPart")
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not myRoot then return end
    local role = ESP_DetectRole(p); PlayerRoles[p]=role
    local color = ROLE_COLORS[role] or ROLE_COLORS.Innocent
    local data = Tracers[p]
    if not data or not data.a.Parent or not data.b.Parent or not data.beam.Parent then
        local a = Instance.new("Attachment"); a.Name="AkatTracerStart"; a.Parent=myRoot
        local b = Instance.new("Attachment"); b.Name="AkatTracerEnd"; b.Parent=targetRoot
        local beam = Instance.new("Beam"); beam.Name="AkatTracer"; beam.Attachment0=a; beam.Attachment1=b; beam.FaceCamera=true; beam.LightEmission=0; beam.Width0=0.035; beam.Width1=0.01; beam.Transparency=NumberSequence.new(0.15); beam.Parent=myRoot
        data={a=a,b=b,beam=beam}; Tracers[p]=data
    end
    data.beam.Color = ColorSequence.new(color)
    -- Dynamic thickness/distance keeps distant tracers subtle and nearby ones readable.
    local d = (myRoot.Position-targetRoot.Position).Magnitude
    local w = math.clamp(0.055 - d*0.00006, 0.012, 0.055)
    data.beam.Width0=w; data.beam.Width1=w*0.28
end

local function UpdateReachBox(p)
    if p == player or not p.Character or not Configs.ViewReach then
        if ReachBoxes[p] then pcall(function() ReachBoxes[p]:Destroy() end); ReachBoxes[p]=nil end
        return
    end
    local char = p.Character
    local box = ReachBoxes[p]
    if not box or not box.Parent then
        box = Instance.new("BoxHandleAdornment")
        box.Name = "AkatReachView"
        box.Adornee = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
        box.Size = char:GetExtentsSize() + Vector3.new(0.35,0.35,0.35)
        box.Color3 = Color3.fromRGB(220,0,0)
        box.Transparency = 0.72
        box.AlwaysOnTop = true
        box.ZIndex = 1
        box.Parent = char
        ReachBoxes[p]=box
    else
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
        box.Adornee=root; box.Size=char:GetExtentsSize()+Vector3.new(0.35,0.35,0.35)
    end
end

local function Visuals_UpdateAll()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            UpdateName(p); UpdateTracer(p); UpdateReachBox(p)
        end
    end
end

local function Visuals_ClearAll()
    for p in pairs(NameTags) do if NameTags[p] then pcall(function() NameTags[p]:Destroy() end) end; NameTags[p]=nil end
    for p in pairs(Tracers) do local d=Tracers[p]; pcall(function() d.a:Destroy() end); pcall(function() d.b:Destroy() end); pcall(function() d.beam:Destroy() end); Tracers[p]=nil end
    for p in pairs(ReachBoxes) do pcall(function() ReachBoxes[p]:Destroy() end); ReachBoxes[p]=nil end
end

local function ESP_Enable()
    Configs.ESP = true
    if espPlayerAddedConn    then espPlayerAddedConn:Disconnect() end
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
    if espPlayerAddedConn then
        espPlayerAddedConn:Disconnect()
        espPlayerAddedConn = nil
    end
    if espPlayerRemovingConn then
        espPlayerRemovingConn:Disconnect()
        espPlayerRemovingConn = nil
    end

    for _, p in ipairs(Players:GetPlayers()) do
        ESP_DisconnectPlayer(p)
    end
    ESP_ClearAll()
end

local autoShootBusy = false
local lastAutoShot = 0
local AUTO_SHOOT_COOLDOWN = 0.20

local function AutoShoot_FindGun()
    local char = player.Character
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
                if role == "Murderer" then
                    murderer = p
                    break
                end
            end
        end
    end
    if not murderer or murderer == player or not murderer.Parent then return nil end

    local char = murderer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local head = char and char:FindFirstChild("Head")

    if not char or not hum or hum.Health <= 0 or not head then
        return nil
    end

    -- Revalidate the role every press so a new round cannot leave a stale cached role.
    local freshRole = ESP_DetectRole(murderer)
    PlayerRoles[murderer] = freshRole
    if freshRole ~= "Murderer" then
        return nil
    end

    return murderer, head
end

local function AutoShoot_ClickOnce()
    local x, y = 0, 0
    pcall(function()
        local pos = UserInputService:GetMouseLocation()
        x, y = pos.X, pos.Y
    end)

    local pressed = false
    local ok = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        pressed = true
        task.wait(0.025)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        pressed = false
    end)

    if pressed then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
    end

    return ok
end

local function ExecuteAutoShootOnce()
    if not Configs.AutoShoot or autoShootBusy then return false end

    local now = tick()
    if now - lastAutoShot < AUTO_SHOOT_COOLDOWN then
        return false
    end

    local murderer = AutoShoot_GetValidTarget()
    if not murderer then return false end

    local gun, hum = AutoShoot_FindGun()
    if not gun or not gun:IsA("Tool") or not hum or hum.Health <= 0 then
        return false
    end

    autoShootBusy = true
    lastAutoShot = now

    local ok = pcall(function()
        if gun.Parent ~= player.Character then
            hum:EquipTool(gun)
            task.wait(0.05)
        end

        if not Configs.AutoShoot or gun.Parent ~= player.Character then
            return
        end

        -- On mobile, do not synthesize a mouse click at the current pointer
        -- position: that can steal/break the movement thumbstick. Tool:Activate()
        -- triggers the same weapon action without consuming the joystick.
        autoShootFiring = true

        if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
            pcall(function() gun:Activate() end)
        else
            local clickOK = AutoShoot_ClickOnce()
            if not clickOK then
                pcall(function() gun:Activate() end)
            end
        end

        task.wait(0.03)
        autoShootFiring = false
    end)

    autoShootFiring = false

    pcall(function()
        if hum and hum.Parent and gun and gun.Parent == player.Character then
            hum:UnequipTools()
        end
    end)

    autoShootBusy = false
    return ok
end

local function ToggleAutoShoot(enabled)
    -- A toggle somente habilita/desabilita o botão flutuante.
    -- A execução real acontece exclusivamente por AutoShootOnce.
    Configs.AutoShoot = enabled

    if autoShootConnection then
        autoShootConnection:Disconnect()
        autoShootConnection = nil
    end

    if not enabled then
        autoShootBusy = false
        autoShootFiring = false
    end
end

local function ObterArmaCaida(root)
    local gun = workspace:FindFirstChild("GunDrop", true)
    if gun then
        local targetPart = nil
        if gun:IsA("BasePart") then
            targetPart = gun
        elseif gun:IsA("Model") then
            targetPart = gun:FindFirstChildOfClass("BasePart") or gun.PrimaryPart
        elseif gun:IsA("Tool") then
            targetPart = gun:FindFirstChild("Handle") or gun:FindFirstChildOfClass("BasePart")
        end
        if targetPart and root then
            if (root.Position - targetPart.Position).Magnitude < 1500 then
                return targetPart
            end
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
        local mainGui = player:FindFirstChild("PlayerGui")
            and player.PlayerGui:FindFirstChild("MainGui")
        local gameGui = mainGui and mainGui:FindFirstChild("Game")
        local coinBag = gameGui and gameGui:FindFirstChild("CoinBag")
        local amount  = coinBag
            and coinBag:FindFirstChild("Container")
            and coinBag.Container:FindFirstChild("Amount")
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
    local TextChatService  = game:GetService("TextChatService")
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
    if hbConnection      then hbConnection:Disconnect();      hbConnection      = nil end
    if steppedConnection then steppedConnection:Disconnect(); steppedConnection = nil end
    if autoShootConnection  then autoShootConnection:Disconnect();  autoShootConnection  = nil end
    if knifeThrowConnection then knifeThrowConnection:Disconnect(); knifeThrowConnection = nil end

    for k in pairs(Configs) do Configs[k] = false end
    autoFarmTemporarilyDisabled = false
    autoShootFiring = false
    knifeThrowFiring = false
    knifeThrowTarget = nil

    ESP_Disable()

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
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("Decal") then
                    part.Transparency = 0
                end
            end
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                root.Anchored = false
                root.AssemblyLinearVelocity  = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                root.Transparency = 1
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = 16
                hum.UseJumpPower = true
                hum.JumpPower = 50
            end
        end
        
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") and d:GetAttribute("OriginalTransparency") then
                d.Transparency = d:GetAttribute("OriginalTransparency")
            end
        end
    end)

    _G.AkatLogicRunning = false
end

-- ==================== PONTE DE COMUNICAÇÃO GLOBAL ====================
local knifeThrowBusy = false
local lastKnifeThrow = 0
local KNIFE_THROW_COOLDOWN = 0.40

local function KnifeThrow_ClickHoldRelease()
    local x, y = 0, 0
    pcall(function()
        local pos = UserInputService:GetMouseLocation()
        x, y = pos.X, pos.Y
    end)

    local pressed = false
    local ok = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        pressed = true

        -- MM2 knife throwing is commonly triggered by holding then releasing.
        -- Keep the press long enough for the local tool script to enter throw mode.
        task.wait(0.12)

        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        pressed = false
    end)

    if pressed then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
    end

    return ok
end

local function ExecuteKnifeThrowOnce()
    if not Configs.KnifeThrow or knifeThrowBusy then return false end

    local now = tick()
    if now - lastKnifeThrow < KNIFE_THROW_COOLDOWN then
        return false
    end

    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or hum.Health <= 0 or not root then
        return false
    end

    local knife = char:FindFirstChild("Knife") or char:FindFirstChild("Faca")
    local backpack = player:FindFirstChildOfClass("Backpack")

    if not knife and backpack then
        knife = backpack:FindFirstChild("Knife") or backpack:FindFirstChild("Faca")
        if knife then
            hum:EquipTool(knife)
            task.wait(0.05)
        end
    end

    if not Configs.KnifeThrow or not knife or knife.Parent ~= char then
        return false
    end

    local closestPlayer, closestDist = nil, math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local role = ESP_DetectRole(p)
            PlayerRoles[p] = role

            -- Prefer Innocent; if the round data exposes no Innocent,
            -- allow Sheriff as the secondary valid target.
            if role == "Innocent" or role == "Sheriff" then
                local eRoot = p.Character:FindFirstChild("HumanoidRootPart")
                local eHum = p.Character:FindFirstChildOfClass("Humanoid")

                if eRoot and eHum and eHum.Health > 0 then
                    local dist = (root.Position - eRoot.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestPlayer = p
                    end
                end
            end
        end
    end

    if not closestPlayer or not closestPlayer.Character then
        return false
    end

    local targetRoot = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then
        return false
    end

    knifeThrowBusy = true
    lastKnifeThrow = now
    knifeThrowTarget = closestPlayer

    local ok = pcall(function()
        if not Configs.KnifeThrow then return end

        -- Keep the target hook active while the actual throw is triggered.
        -- On mobile, avoid synthetic mouse input so the movement thumbstick
        -- remains untouched while the knife is thrown toward the selected target.
        knifeThrowFiring = true

        if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
            pcall(function() knife:Activate() end)
            task.wait(0.18)
        else
            local clickOK = KnifeThrow_ClickHoldRelease()

            -- Fallback for builds that expose a direct throw remote.
            if not clickOK then
                local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                local throwEvent = remotes
                    and remotes:FindFirstChild("Extras")
                    and remotes.Extras:FindFirstChild("Throw")
                if throwEvent then
                    throwEvent:FireServer(targetRoot.Position)
                else
                    pcall(function() knife:Activate() end)
                end
            end
        end

        task.wait(0.18)
        knifeThrowFiring = false
    end)

    knifeThrowFiring = false
    knifeThrowTarget = nil

    pcall(function()
        if hum and hum.Parent and knife and knife.Parent == char then
            hum:UnequipTools()
        end
    end)

    knifeThrowBusy = false
    return ok
end

_G.AkatCallbacks = {

    ESP = function(enabled)
        if enabled then ESP_Enable() else ESP_Disable() end
    end,

    Name = function(enabled)
        Configs.Name = enabled and true or false
        if not Configs.Name then
            for p,tag in pairs(NameTags) do pcall(function() tag:Destroy() end); NameTags[p]=nil end
        end
    end,
    Tracer = function(enabled)
        Configs.Tracer = enabled and true or false
        if not Configs.Tracer then
            for p,d in pairs(Tracers) do pcall(function() d.a:Destroy() end); pcall(function() d.b:Destroy() end); pcall(function() d.beam:Destroy() end); Tracers[p]=nil end
        end
    end,
    ViewReach = function(enabled)
        Configs.ViewReach = enabled and true or false
        if not Configs.ViewReach then
            for p,b in pairs(ReachBoxes) do pcall(function() b:Destroy() end); ReachBoxes[p]=nil end
        end
    end,

    Speed = function(value)
        if type(value) == "number" then
            Configs.SpeedValue = math.clamp(value, 0, 200)
            Configs.Speed = true
        else
            Configs.Speed = value and true or false
        end
    end,

    JumpPower = function(value)
        if type(value) == "number" then
            Configs.JumpPowerValue = math.clamp(value, 0, 200)
            Configs.JumpPower = true
        else
            Configs.JumpPower = value and true or false
        end
    end,

    Reach = function(value)
        if type(value) == "number" then
            Configs.ReachValue = math.clamp(value, 1, 50)
            Configs.Reach = true
        else
            Configs.Reach = value and true or false
        end
    end,
    AntiFling = function(enabled)
        Configs.AntiFling = enabled and true or false
        noclipEnabled = Configs.AntiFling
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
                safePlatform               = Instance.new("Part")
                safePlatform.Name          = "AkatSafePlatform"
                safePlatform.Size          = Vector3.new(15, 1, 15)
                safePlatform.Position      = Vector3.new(root.Position.X, 900, root.Position.Z)
                safePlatform.Anchored      = true
                safePlatform.Transparency  = 0.4
                safePlatform.Material      = Enum.Material.ForceField
                safePlatform.Color         = Color3.fromHex("#8B0000")
                safePlatform.Parent        = workspace
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

    AutoFarm = function(enabled)
        Configs.AutoFarm = enabled and true or false
        currentFarmTarget = nil
        if autoFarmTween then autoFarmTween:Cancel(); autoFarmTween = nil end

        if not Configs.AutoFarm then
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

TpLobby = function(enabled)
        Configs.TpLobby = false
        if not enabled then return false end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return false end

        local function scorePart(part)
            local n = part.Name:lower()
            local score = 0
            if n:find("lobby") then score += 8 end
            if n:find("spawn") then score += 6 end
            if part:IsA("SpawnLocation") then score += 10 end
            return score
        end

        local candidates = {}
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("SpawnLocation") or (d:IsA("BasePart") and (d.Name:lower():find("lobby") or d.Name:lower():find("spawn"))) then
                table.insert(candidates, d)
            end
        end

        table.sort(candidates, function(a,b) return scorePart(a) > scorePart(b) end)
        local target = candidates[1]
        if target then
            root.CFrame = target.CFrame + Vector3.new(0, 4, 0)
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

        local lobbyNames = {Lobby=true, LobbyMap=true, LobbyArea=true}
        local bestPart, bestScore = nil, -math.huge

        for _, container in ipairs(workspace:GetChildren()) do
            if not lobbyNames[container.Name] then
                local isCandidate = container:IsA("Model") or container:IsA("Folder")
                if isCandidate then
                    for _, d in ipairs(container:GetDescendants()) do
                        if d:IsA("BasePart") then
                            local n = d.Name:lower()
                            local score = 0
                            if n:find("spawn") or n:find("player") then score += 25 end
                            if n:find("map") then score += 8 end
                            if d.Size.X > 6 and d.Size.Z > 6 then score += 2 end
                            if score > bestScore then bestScore, bestPart = score, d end
                        end
                    end
                end
            end
        end

        if not bestPart then
            -- Fallback: use a large non-lobby floor part, then place the player above it.
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("BasePart") and d.Size.X > 12 and d.Size.Z > 12
                    and not d:IsDescendantOf(char)
                    and not d.Name:lower():find("lobby") then
                    bestPart = d
                    break
                end
            end
        end

        if bestPart then
            local pos = bestPart.Position + Vector3.new(0, math.max(4, bestPart.Size.Y * 0.5 + 3), 0)
            root.CFrame = CFrame.new(pos)
            return true
        end
        return false
    end,

TpToGun = function(enabled) Configs.TpToGun = enabled end,
    ["Tp to gun"] = function(enabled) Configs.TpToGun = enabled end,
    ["Tp To Gun"] = function(enabled) Configs.TpToGun = enabled end,

    AutoShoot = function(enabled)
        ToggleAutoShoot(enabled)
    end,

    -- A toggle não dispara. O botão flutuante chama esta função uma única vez.
    AutoShootOnce = function()
        if not Configs.AutoShoot then
            return false
        end
        return ExecuteAutoShootOnce()
    end,

    KnifeThrow = function(enabled)
        Configs.KnifeThrow = enabled

        if knifeThrowConnection then
            knifeThrowConnection:Disconnect()
            knifeThrowConnection = nil
        end

        -- Sem loop automático: o botão flutuante é o único gatilho.
        if not enabled then
            knifeThrowBusy = false
        end
    end,

    KnifeThrowOnce = function()
        if not Configs.KnifeThrow then
            return false
        end
        return ExecuteKnifeThrowOnce()
    end,

    -- 2. X-Ray
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
                XRayParts[part] = nil
            end
            return
        end

        local function apply(part)
            if not Configs.XRay or not part:IsA("BasePart") then return end
            local char = player.Character
            if part:IsDescendantOf(char) or part:IsDescendantOf(Camera) then return end
            if XRayParts[part] == nil then
                XRayParts[part] = part.LocalTransparencyModifier
            end
            part.LocalTransparencyModifier = 0.55
        end

        for _, d in ipairs(workspace:GetDescendants()) do
            apply(d)
        end

        xrayDescendantConnection = workspace.DescendantAdded:Connect(function(d)
            if d:IsA("BasePart") then
                task.defer(function() apply(d) end)
            end
        end)
    end,

    -- 4. Kill All Automático Corrigido (Pega a faca e ataca no ar)
    KillAll = function(enabled)
        Configs.KillAll = enabled
        if enabled then
            task.spawn(function()
                while Configs.KillAll do
                    task.wait(0.15)
                    local char = player.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if not char or not hum or hum.Health <= 0 then continue end

                    -- Auto equip da faca a partir do inventário
                    local myKnife = char:FindFirstChild("Knife") or char:FindFirstChild("Faca")
                    if not myKnife and player:FindFirstChild("Backpack") then
                        myKnife = player.Backpack:FindFirstChild("Knife") or player.Backpack:FindFirstChild("Faca")
                        if myKnife then
                            hum:EquipTool(myKnife)
                            task.wait(0.05)
                        end
                    end
                    
                    if myKnife and myKnife.Parent == char then
                        local handle = myKnife:FindFirstChild("Handle") or myKnife:FindFirstChildOfClass("BasePart")
                        
                        -- Simula o ataque no ar
                        pcall(function() myKnife:Activate() end)

                        -- Executa o Kill All em todos os jogadores vivos
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= player and p.Character then
                                local enemyRoot = p.Character:FindFirstChild("HumanoidRootPart")
                                local enemyHum = p.Character:FindFirstChildOfClass("Humanoid")
                                if enemyRoot and enemyHum and enemyHum.Health > 0 and handle then
                                    pcall(function()
                                        firetouchinterest(enemyRoot, handle, 0)
                                        firetouchinterest(enemyRoot, handle, 1)
                                    end)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end,
    
    -- 5. Invisibility
    Invisibility = function(enabled)
        Configs.Invisibility = enabled
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.Transparency = enabled and 1 or 0
                elseif part:IsA("Decal") then
                    part.Transparency = enabled and 1 or 0
                end
            end
        end
    end,

    ShutdownAll = function()
        LimparEDesligarAbsolutamente()
    end,
}

-- ==================== THREAD DO AUTO COLLECT ====================
task.spawn(function()
    while true do
        task.wait(0.005)
        if Configs.AutoFarm then
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

                        local goalCFrame  = CFrame.new(target.Position)
                        local dist        = (root.Position - target.Position).Magnitude
                        local timeToReach = dist / 37

                        autoFarmTween = TweenService:Create(
                            root,
                            TweenInfo.new(timeToReach, Enum.EasingStyle.Linear),
                            {CFrame = goalCFrame}
                        )
                        autoFarmTween:Play()
                        -- Do not block the worker on a stale tween; round transitions can destroy the target.
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
                                part.Name:find("Foot") or
                                part.Name:find("Leg")  or
                                part.Name:find("Torso")
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
                local hasKnife = player.Backpack:FindFirstChild("Knife")
                    or char:FindFirstChild("Knife")
                    or player.Backpack:FindFirstChild("Faca")
                    or char:FindFirstChild("Faca")

                if isMurdererRole or hasKnife then
                    trackingTpToGun        = false
                    lastPositionBeforeTpToGun = nil
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
                        trackingTpToGun = true

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
                        if lastPositionBeforeTpToGun then
                            root.CFrame = lastPositionBeforeTpToGun
                        end
                        lastPositionBeforeTpToGun = nil
                        trackingTpToGun           = false

                        if autoFarmTemporarilyDisabled then
                            autoFarmTemporarilyDisabled = false
                            Configs.AutoFarm = true
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
                trackingTpToGun           = false

                if autoFarmTemporarilyDisabled then
                    autoFarmTemporarilyDisabled = false
                    Configs.AutoFarm = true
                end
            end
        end
    end
end)

-- ==================== NOCLIP SEGURO ====================
steppedConnection = RunService.Stepped:Connect(function()
    if Configs.AutoFarm or Configs.SafeSpot or trackingTpToGun or Configs.AntiFling then
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

-- ==================== CICLO DE VIDA DA RODADA / RESPAWN ====================
local function ResetRoundState()
    roundGeneration += 1
    CachedState.Murderer = nil
    CachedState.HasGun = false
    CachedState.Coins = {}
    currentFarmTarget = nil
    if autoFarmTween then autoFarmTween:Cancel(); autoFarmTween = nil end
    gunDroppedThisRound = false
    trackingTpToGun = false
    lastPositionBeforeTpToGun = nil
    announcedThisRound = false
    autoShootBusy = false
    autoShootFiring = false

    for p in pairs(PlayerRoles) do PlayerRoles[p] = nil end
    for p in pairs(NameTags) do if NameTags[p] then pcall(function() NameTags[p]:Destroy() end) end; NameTags[p] = nil end
    for p in pairs(Tracers) do
        local d = Tracers[p]
        pcall(function() d.a:Destroy() end); pcall(function() d.b:Destroy() end); pcall(function() d.beam:Destroy() end)
        Tracers[p] = nil
    end
    for p in pairs(ReachBoxes) do if ReachBoxes[p] then pcall(function() ReachBoxes[p]:Destroy() end) end; ReachBoxes[p] = nil end

    if Configs.ESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then ESP_ConnectPlayer(p) end
        end
    end
end

characterConnection = player.CharacterAdded:Connect(function(char)
    ResetRoundState()
    task.wait(0.2)

    if Configs.Invisibility and char.Parent then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = 1
            elseif part:IsA("Decal") then
                part.Transparency = 1
            end
        end
    end
    if Configs.XRay then
        if xrayDescendantConnection then xrayDescendantConnection:Disconnect() end
        -- Reapply only to the current workspace once after respawn.
        task.defer(function()
            if Configs.XRay then _G.AkatCallbacks.XRay(true) end
        end)
    end
end)

Players.PlayerAdded:Connect(function(p)
    if Configs.ESP then ESP_ConnectPlayer(p) end
end)

Players.PlayerRemoving:Connect(function(p)
    ESP_DisconnectPlayer(p)
    PlayerRoles[p] = nil
end)

-- ==================== LOOP PRINCIPAL ====================
hbConnection = RunService.Heartbeat:Connect(function(dt)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")

    if not root or not hum then return end

    hum.WalkSpeed = Configs.Speed and Configs.SpeedValue or 16
    hum.UseJumpPower = true
    hum.JumpPower = Configs.JumpPower and Configs.JumpPowerValue or 50

    if Configs.Reach then
        local myKnife = char:FindFirstChild("Knife") or char:FindFirstChild("Faca")
        local handle  = myKnife and myKnife:FindFirstChild("Handle")
        if handle then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    local enemyRoot = p.Character:FindFirstChild("HumanoidRootPart")
                    local enemyHum  = p.Character:FindFirstChildOfClass("Humanoid")
                    if enemyRoot and enemyHum and enemyHum.Health > 0 then
                        local dist = (root.Position - enemyRoot.Position).Magnitude
                        if dist <= (Configs.ReachValue or 18) then
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

    if Configs.AntiFling then
        -- Anti-Fling also silently keeps our own character noclip.
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
        if math.abs(root.AssemblyLinearVelocity.Magnitude) > 60
            or math.abs(root.AssemblyAngularVelocity.Magnitude) > 60 then
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
end)

-- ==================== THREAD CENTRAL DE SCANNER E CACHE ====================
task.spawn(function()
    local tempoUltimoScanMoedas = 0
    local tempoUltimoScanESP    = 0

    while true do
        local gunFoundInPlayers  = false
        local knifeFoundInPlayers = false
        local localPlayerHasGun  = false
        local currentMurderer, currentSheriff = nil, nil

        local agora         = tick()
        local atualizarESP  = Configs.ESP and (agora - tempoUltimoScanESP > 0.35)
        if atualizarESP then
            tempoUltimoScanESP = agora
        end

        for _, p in ipairs(Players:GetPlayers()) do
            if atualizarESP and p ~= player then
                ESP_UpdatePlayer(p)
            end

            -- Atualiza os papéis independentemente do ESP estar ligado.
            local role = ESP_DetectRole(p)
            PlayerRoles[p] = role

            if role == "Murderer" then currentMurderer = p end
            if role == "Sheriff"  then currentSheriff  = p end

            if p.Character then
                local temArma = p.Character:FindFirstChild("Gun")
                    or p.Backpack:FindFirstChild("Gun")
                if temArma then
                    gunFoundInPlayers = true
                    if p == player then localPlayerHasGun = true end
                end
                if p.Character:FindFirstChild("Knife")
                    or p.Backpack:FindFirstChild("Knife") then
                    knifeFoundInPlayers = true
                end
            end
        end

        CachedState.HasGun   = localPlayerHasGun
        CachedState.Murderer = currentMurderer

        if Configs.AutoFarm and (tick() - tempoUltimoScanMoedas > 0.3) then
            tempoUltimoScanMoedas = tick()
            local moedasEncontradas = {}

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
                            table.insert(moedasEncontradas, d)
                        end
                    end
                end
            end
            CachedState.Coins = moedasEncontradas
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
                msg = msg
                    .. "Murderer: " .. currentMurderer.DisplayName
                    .. " (@" .. currentMurderer.Name .. ") "
            end
            if currentSheriff then
                msg = msg
                    .. "| Sheriff: " .. currentSheriff.DisplayName
                    .. " (@" .. currentSheriff.Name .. ")"
            end
            EnviarMensagemChat(msg)
        end

        if Configs.Name or Configs.Tracer or Configs.ViewReach then
            Visuals_UpdateAll()
        end
        task.wait(0.2)
    end
end)

-- ==================== INICIALIZADOR DA UI EXTERNA ====================
task.spawn(function()
    local uiRawUrl = "https://raw.githubusercontent.com/estratosfera88-afk/Ui-do-teste/refs/heads/main/ui.lua"

    local rawContent = nil
    local fetchSuccess, fetchErr = pcall(function()
        rawContent = game:HttpGet(uiRawUrl, true)
    end)

    if not fetchSuccess then
        warn("[AKAT LOGIC] HttpGet falhou: " .. tostring(fetchErr))
        return
    end

    if not rawContent or rawContent == "" then
        warn("[AKAT LOGIC] HttpGet retornou vazio. Verifique a URL.")
        return
    end

    local fn, compileErr = loadstring(rawContent)
    if not fn then
        warn("[AKAT LOGIC] loadstring falhou ao compilar a UI: " .. tostring(compileErr))
        return
    end

    local runSuccess, runErr = pcall(fn)
    if not runSuccess then
        warn("[AKAT LOGIC] Erro ao executar a UI: " .. tostring(runErr))
    end
end)
