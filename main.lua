-- =====================================================================
-- [[ AKATSUKI BLOX FRUITS SCRIPT [v1.1.1] - AUTO FARM | PVP | RAID | TP ]]
-- =====================================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- ==================== CONFIGURAÇÕES PRINCIPAIS ====================
local Configs = {
    AutoFarm = false,
    AutoFarmMob = false,
    AutoFarmBoss = false,
    AutoCollectChest = false,
    AutoStats = false,

    AimbotPvP = false,
    AntiFlinch = false,
    PvPAutoBlock = false,
    FruitSniper = false,

    AutoRaid = false,
    RaidInstant = false,

    PlayerESP = false,
    FruitESP = false,

    AutoRevive = false,
    ServerHop = false,
}

-- ==================== VARIÁVEIS ====================
local farmLoop = nil
local selectedMob = "Lowest Level Mob"
local selectedBoss = "None"
local farmSafeDistance = 12
local pvpTarget = nil
local aimbotConnection = nil
local antiFlinchConn = nil
local camera = Workspace.CurrentCamera
local espObjects = {}

-- ==================== LISTA DE TELEPORTES ====================
local Teleports = {
    { Name = "Cidade do Povo",     Sea = 1, Position = Vector3.new(-1245, 40, 1380) },
    { Name = "Marine Starter",     Sea = 1, Position = Vector3.new(975, 122, 1596) },
    { Name = "Baú Misterioso",     Sea = 1, Position = Vector3.new(-3000, 15, 1000) },
    { Name = "Ilha Cozinha",       Sea = 1, Position = Vector3.new(-471, 7, -1120) },
    { Name = "Ilha Espadas",       Sea = 1, Position = Vector3.new(-938, 9, -1254) },
    { Name = "Floresta",           Sea = 1, Position = Vector3.new(-2100, 10, -120) },
    { Name = "Ilha Pirata",        Sea = 1, Position = Vector3.new(-1500, 7, 200) },
    { Name = "Deserto",            Sea = 1, Position = Vector3.new(922, 9, 1000) },
    { Name = "Ilha Zoro",          Sea = 1, Position = Vector3.new(2022, 8, -700) },
    { Name = "Ilha Skypea",        Sea = 1, Position = Vector3.new(-5074, 2000, 200) },
    { Name = "Café (Mar 2)",       Sea = 2, Position = Vector3.new(-2600, 6, -830) },
    { Name = "Floresta Mar 2",     Sea = 2, Position = Vector3.new(-1060, 8, -4360) },
    { Name = "Ilha Snow",          Sea = 2, Position = Vector3.new(1660, 8, 570) },
    { Name = "Ilha Colosseum",     Sea = 2, Position = Vector3.new(925, 10, -1830) },
    { Name = "Ilha Zou",           Sea = 2, Position = Vector3.new(-4200, 80, -400) },
    { Name = "Sand Kingdom",       Sea = 2, Position = Vector3.new(4380, 10, -3280) },
    { Name = "Assassin Hideout",   Sea = 2, Position = Vector3.new(-3680, 10, -4080) },
    { Name = "Port Town",          Sea = 3, Position = Vector3.new(-2640, 72, -3735) },
    { Name = "Hydra Island",       Sea = 3, Position = Vector3.new(4700, 350, 8600) },
    { Name = "Floating Turtle",    Sea = 3, Position = Vector3.new(-11950, 800, -6025) },
    { Name = "Great Tree",         Sea = 3, Position = Vector3.new(-14150, 250, -6025) },
    { Name = "Castle on the Sea",  Sea = 3, Position = Vector3.new(-6700, 250, 8200) },
    { Name = "Raid Island",        Sea = 0, Position = Vector3.new(-15970, 700, 3800) },
    { Name = "Marineford",         Sea = 0, Position = Vector3.new(-28000, 11, 2375) },
    { Name = "Fountain City",      Sea = 0, Position = Vector3.new(-5000, 350, 9800) },
}

-- ==================== UTILITÁRIOS ====================
local function CharacterReady()
    character = player.Character
    if not character then return false end
    humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    humanoid = character:FindFirstChild("Humanoid")
    return humanoidRootPart ~= nil and humanoid ~= nil and humanoid.Health > 0
end

local function SafeTeleport(pos)
    if not CharacterReady() then return end
    pcall(function()
        humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
        humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
        character:PivotTo(CFrame.new(pos))
        task.wait(0.05)
        humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
    end)
end

local function GetClosestPlayer(maxDist)
    local closest, dist = nil, maxDist or math.huge
    if not CharacterReady() then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local d = (hrp.Position - humanoidRootPart.Position).Magnitude
                if d < dist then dist = d; closest = p end
            end
        end
    end
    return closest
end

local function GetClosestEnemy(maxDistance)
    local closest, dist = nil, maxDistance or 300
    if not CharacterReady() then return nil end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= character then
            local hum = obj:FindFirstChild("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 and not Players:GetPlayerFromCharacter(obj) then
                local d = (hrp.Position - humanoidRootPart.Position).Magnitude
                if d < dist then
                    dist = d
                    closest = { Model = obj, HRP = hrp, Humanoid = hum }
                end
            end
        end
    end
    return closest
end

-- ==================== AUTO FARM (MOBS) ====================
local function StartAutoFarm()
    if farmLoop then farmLoop = false; task.wait(0.1) end
    farmLoop = true
    task.spawn(function()
        local equippedTool = nil
        while farmLoop and Configs.AutoFarm do
            if not CharacterReady() then
                task.wait(1)
            else
                -- Tentar pegar missão (protegido)
                pcall(function()
                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                    if remotes and remotes:FindFirstChild("CommF_") then
                        remotes.CommF_:InvokeServer("StartQuest", "BanditQuest1", 1)
                    end
                end)

                local enemy = GetClosestEnemy(300)
                if enemy then
                    -- Equipar ferramenta se necessário
                    if not equippedTool or equippedTool.Parent ~= character then
                        equippedTool = character:FindFirstChildOfClass("Tool")
                        if not equippedTool then
                            for _, t in ipairs(player.Backpack:GetChildren()) do
                                if t:IsA("Tool") then
                                    humanoid:EquipTool(t)
                                    equippedTool = t
                                    break
                                end
                            end
                        end
                    end

                    -- Flutuar acima do inimigo (suavizado)
                    local targetCFrame = enemy.HRP.CFrame * CFrame.new(0, farmSafeDistance, 0)
                    humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(targetCFrame, 0.4)
                    humanoidRootPart.AssemblyLinearVelocity = Vector3.zero

                    -- Atacar
                    if equippedTool then
                        pcall(function()
                            equippedTool:Activate()
                        end)
                        task.wait(0.08)
                    end
                else
                    task.wait(0.5)
                end
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

local function StopAutoFarm()
    farmLoop = false
end

-- ==================== AUTO FARM (BOSS) ====================
local function StartAutoFarmBoss()
    task.spawn(function()
        while Configs.AutoFarmBoss do
            if not CharacterReady() then
                task.wait(1)
            else
                -- Procurar boss (nome contém "boss" ou health alto)
                local boss = nil
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("Model") and obj ~= character then
                        local hum = obj:FindFirstChild("Humanoid")
                        local hrp = obj:FindFirstChild("HumanoidRootPart")
                        if hum and hrp and hum.Health > 0 and not Players:GetPlayerFromCharacter(obj) then
                            local name = obj.Name:lower()
                            if name:find("boss") or hum.MaxHealth >= 5000 then
                                boss = { Model = obj, HRP = hrp, Humanoid = hum }
                                break
                            end
                        end
                    end
                end
                if boss then
                    local equippedTool = character:FindFirstChildOfClass("Tool")
                    if not equippedTool then
                        for _, t in ipairs(player.Backpack:GetChildren()) do
                            if t:IsA("Tool") then
                                humanoid:EquipTool(t)
                                equippedTool = t
                                break
                            end
                        end
                    end
                    local targetCFrame = boss.HRP.CFrame * CFrame.new(0, farmSafeDistance, 0)
                    humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(targetCFrame, 0.3)
                    humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                    if equippedTool then
                        pcall(function() equippedTool:Activate() end)
                        task.wait(0.1)
                    end
                else
                    task.wait(1)
                end
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- ==================== AUTO COLETAR CHEST ====================
local collectedChests = {}
local function StartAutoChest()
    task.spawn(function()
        while Configs.AutoCollectChest do
            if CharacterReady() then
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if not Configs.AutoCollectChest then break end
                    local name = obj.Name:lower()
                    if (name:find("chest") or name:find("bag") or name:find("box")) and obj:IsA("Model") then
                        if not collectedChests[obj] then
                            collectedChests[obj] = true
                            local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                            if hrp then
                                SafeTeleport(hrp.Position + Vector3.new(0, 3, 0))
                                task.wait(0.4)
                            end
                        end
                    end
                end
            end
            task.wait(2)
        end
    end)
end

-- ==================== AUTO STATS ====================
local function StartAutoStats()
    task.spawn(function()
        while Configs.AutoStats do
            if CharacterReady() then
                pcall(function()
                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                    if remotes then
                        -- Exemplo: distribuir pontos em Melee/Defense/Blox Fruit
                        local statsRemote = remotes:FindFirstChild("Stats") or remotes:FindFirstChild("AddPoint")
                        if statsRemote then
                            -- Ajuste conforme o remote real
                            statsRemote:FireServer("Melee")
                            statsRemote:FireServer("Defense")
                            statsRemote:FireServer("BloxFruit")
                        end
                    end
                end)
            end
            task.wait(5)
        end
    end)
end

-- ==================== AIMBOT PVP ====================
local function StartAimbot()
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    aimbotConnection = RunService.RenderStepped:Connect(function()
        if not Configs.AimbotPvP then
            if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
            return
        end
        if not CharacterReady() then return end
        local target = GetClosestPlayer(300)
        if target and target.Character then
            local head = target.Character:FindFirstChild("Head")
            if head then
                camera.CFrame = CFrame.lookAt(camera.CFrame.Position, head.Position)
            end
        end
    end)
end

-- ==================== PLAYER ESP ====================
local function ClearESP()
    for p, data in pairs(espObjects) do
        pcall(function()
            if data.Billboard then data.Billboard:Destroy() end
        end)
    end
    espObjects = {}
end

local function UpdateESP()
    ClearESP()
    if not Configs.PlayerESP then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local billboard = Instance.new("BillboardGui")
                billboard.Adornee = hrp
                billboard.Size = UDim2.new(0, 150, 0, 40)
                billboard.StudsOffset = Vector3.new(0, 4, 0)
                billboard.AlwaysOnTop = true
                billboard.Parent = Workspace

                local label = Instance.new("TextLabel", billboard)
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.TextColor3 = Color3.fromRGB(0, 255, 255)
                label.TextStrokeTransparency = 0
                label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 14
                label.Text = p.Name

                espObjects[p] = { Billboard = billboard }
            end
        end
    end
end

-- ==================== FRUIT ESP ====================
local fruitESPObjects = {}
local function UpdateFruitESP()
    -- Limpa ESP de frutas antigas
    for obj, data in pairs(fruitESPObjects) do
        pcall(function() data.Billboard:Destroy() end)
    end
    fruitESPObjects = {}

    if not Configs.FruitESP then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local name = obj.Name:lower()
        if (name:find("fruit") or name:find("devil")) and obj:IsA("Model") then
            local pp = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
            if pp then
                local billboard = Instance.new("BillboardGui")
                billboard.Adornee = pp
                billboard.Size = UDim2.new(0, 120, 0, 30)
                billboard.StudsOffset = Vector3.new(0, 3, 0)
                billboard.AlwaysOnTop = true
                billboard.Parent = Workspace

                local label = Instance.new("TextLabel", billboard)
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.TextColor3 = Color3.fromRGB(255, 100, 100)
                label.TextStrokeTransparency = 0
                label.Font = Enum.Font.GothamBold
                label.TextSize = 12
                label.Text = "Fruta 🍈"

                fruitESPObjects[obj] = { Billboard = billboard }
            end
        end
    end
end

-- ==================== AUTO REVIVE ====================
player.CharacterAdded:Connect(function(char)
    character = char
    humanoidRootPart = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
    if Configs.AutoRevive then
        task.wait(1)
        if Configs.AutoFarm then StartAutoFarm() end
        if Configs.AutoFarmBoss then StartAutoFarmBoss() end
    end
end)

-- ==================== SERVER HOP ====================
local function HttpGet(url)
    if game.HttpGet then
        return game.HttpGet(url)
    else
        return HttpService:GetAsync(url)
    end
end

local function ServerHop()
    local success, result = pcall(function()
        return HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
    end)
    if success and result then
        local servers = HttpService:JSONDecode(result)
        if servers and servers.data then
            for _, server in ipairs(servers.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id)
                    return
                end
            end
        end
    end
end

-- ==================== AUTO RAID ====================
local function StartAutoRaid()
    task.spawn(function()
        while Configs.AutoRaid do
            if CharacterReady() then
                SafeTeleport(Vector3.new(-15970, 700, 3800))
                task.wait(2)
                pcall(function()
                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                    if remotes then
                        local raidRemote = remotes:FindFirstChild("StartRaid") or remotes:FindFirstChild("Raid")
                        if raidRemote then raidRemote:FireServer() end
                    end
                end)
                task.wait(3)
                for i = 1, 60 do
                    if not Configs.AutoRaid then break end
                    if CharacterReady() then
                        local enemy = GetClosestEnemy(100)
                        if enemy then
                            SafeTeleport(enemy.HRP.Position + Vector3.new(0, 10, 0))
                            task.wait(0.1)
                            if Configs.RaidInstant and enemy.Humanoid.Health > 0 then
                                pcall(function() enemy.Humanoid.Health = 0 end)
                            end
                            local tool = character:FindFirstChildOfClass("Tool")
                            if tool then pcall(function() tool:Activate() end) end
                        end
                    end
                    task.wait(0.5)
                end
            end
            task.wait(1)
        end
    end)
end

-- =====================================================================
-- ==================== UI SYSTEM ====================
-- =====================================================================

local UIState = "CLOSED"

local UI_TEXT = {
    SearchPlaceholder = "Pesquisar...",
    ConfirmCloseTitle = "Deseja fechar o script?",
    ConfirmBtn = "Confirmar",
    CancelBtn = "Cancelar",
    Intro = '<font color="#FFFFFF">Blox Fruits | </font><font color="#8B0000">AKATSUKI</font>',
    Tabs = {
        AutoFarm = "Auto Farm",
        PvP = "PvP",
        Raids = "Raids",
        Teleports = "Teleportes",
        Settings = "Extras",
    },
    Options = {
        AutoFarm        = { Title = "Auto Farm",          Desc = "Flutua sobre mobs e ataca até a morte." },
        AutoFarmBoss    = { Title = "Auto Boss Farm",     Desc = "Vai até o boss e ataca automaticamente." },
        AutoCollectChest= { Title = "Auto Chest",         Desc = "Coleta baús e drops no mapa automaticamente." },
        AutoStats       = { Title = "Auto Stats",         Desc = "Distribui atributos automaticamente ao upar." },
        AimbotPvP       = { Title = "Aimbot PvP",         Desc = "Mira na cabeça de jogadores próximos." },
        AntiFlinch      = { Title = "Anti-Flinch",        Desc = "Impede que você tome knockback de ataques." },
        PvPAutoBlock    = { Title = "Auto Block",         Desc = "Bloqueia automaticamente quando atacado." },
        FruitSniper     = { Title = "Fruit Sniper",       Desc = "Teleporta até frutas que caem no mapa." },
        AutoRaid        = { Title = "Auto Raid",          Desc = "Inicia e completa raids automaticamente." },
        RaidInstant     = { Title = "Raid Instant Kill",  Desc = "Elimina inimigos de raid muito mais rápido." },
        PlayerESP       = { Title = "Player ESP",         Desc = "Mostra o nome colorido de todos no mapa." },
        FruitESP        = { Title = "Fruit ESP",          Desc = "Mostra frutas spawnadas no mapa." },
        AutoRevive      = { Title = "Auto Revive",        Desc = "Reinicia farms automaticamente após morrer." },
        ServerHop       = { Title = "Server Hop",         Desc = "Troca de servidor automaticamente (menos players)." },
    }
}

local activeTab = "AutoFarm"
local tabButtons = {}
local isExpanded = false
local originalTrans = {}
local confirmBlur = nil
local isConfirmOpen = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BloxFruitsAkatUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then uiParent = gethui() else pcall(function() uiParent = game:GetService("CoreGui") end) end
if uiParent:FindFirstChild("BloxFruitsAkatUI") then pcall(function() uiParent.BloxFruitsAkatUI:Destroy() end) end
screenGui.Parent = uiParent

local SharedClickSound = Instance.new("Sound", screenGui)
SharedClickSound.SoundId = "rbxassetid://6895079853"
SharedClickSound.Volume = 0.6
SharedClickSound.Looped = false

local function PlayUI_Click()
    pcall(function() SharedClickSound.TimePosition = 0; SharedClickSound:Play() end)
end

local function RegistrarTransparencias(objeto)
    if originalTrans[objeto] then return end
    if objeto:IsA("Frame") or objeto:IsA("ScrollingFrame") or objeto:IsA("CanvasGroup") then
        originalTrans[objeto] = { BackgroundTransparency = objeto.BackgroundTransparency }
    elseif objeto:IsA("TextLabel") or objeto:IsA("TextButton") or objeto:IsA("TextBox") then
        originalTrans[objeto] = { TextTransparency = objeto.TextTransparency, BackgroundTransparency = objeto.BackgroundTransparency, TextStrokeTransparency = objeto.TextStrokeTransparency or 1 }
    elseif objeto:IsA("ImageLabel") or objeto:IsA("ImageButton") then
        originalTrans[objeto] = { ImageTransparency = objeto.ImageTransparency, BackgroundTransparency = objeto.BackgroundTransparency }
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
        if orig.BackgroundTransparency ~= nil then
            local t = fadeOut and 1 or orig.BackgroundTransparency
            if duracao == 0 then obj.BackgroundTransparency = t else TweenService:Create(obj, info, {BackgroundTransparency = t}):Play() end
        end
        if orig.TextTransparency ~= nil then
            local t = fadeOut and 1 or orig.TextTransparency
            if duracao == 0 then obj.TextTransparency = t else TweenService:Create(obj, info, {TextTransparency = t}):Play() end
        end
        if orig.ImageTransparency ~= nil then
            local t = fadeOut and 1 or orig.ImageTransparency
            if duracao == 0 then obj.ImageTransparency = t else TweenService:Create(obj, info, {ImageTransparency = t}):Play() end
        end
        if orig.Transparency ~= nil then
            local t = fadeOut and 1 or orig.Transparency
            if duracao == 0 then obj.Transparency = t else TweenService:Create(obj, info, {Transparency = t}):Play() end
        end
    end
    tratarObjeto(raiz)
    for _, desc in ipairs(raiz:GetDescendants()) do tratarObjeto(desc) end
end

-- ==================== BOTÃO FLUTUANTE ====================
local FloatBtn = Instance.new("ImageButton", screenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0.12, 0, 0.4, 0)
FloatBtn.Image = "rbxthumb://type=Asset&id=139044062702391&w=150&h=150"
FloatBtn.BackgroundColor3 = Color3.fromRGB(15, 0, 0)
FloatBtn.Visible = true
FloatBtn.ZIndex = 100
FloatBtn.ClipsDescendants = false
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)

local FloatOpenSound = Instance.new("Sound", FloatBtn)
FloatOpenSound.SoundId = "rbxassetid://6310837681"
FloatOpenSound.Volume = 0.2
FloatOpenSound.Looped = false

task.spawn(function()
    pcall(function() ContentProvider:PreloadAsync({FloatOpenSound, SharedClickSound}) end)
end)

local dragToggle, dragStart, startPos, isDragging = false, nil, nil, false

FloatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragToggle = true; isDragging = false
        dragStart = input.Position; startPos = FloatBtn.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        if delta.Magnitude > 5 then isDragging = true end
        FloatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local SetUIState
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if dragToggle and not isDragging then
            if UIState == "MINIMIZED" or UIState == "CLOSED" then
                pcall(function() FloatOpenSound.TimePosition = 0; FloatOpenSound:Play() end)
                SetUIState("OPEN")
            elseif UIState == "OPEN" then
                SetUIState("MINIMIZED")
            end
        end
        dragToggle = false
    end
end)

-- ==================== MAIN WRAPPER ====================
local mainWrapper = Instance.new("Frame", screenGui)
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0.5)
mainWrapper.Size = UDim2.new(0, 640, 0, 360)
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
mainWrapper.BackgroundTransparency = 1
mainWrapper.Visible = false
mainWrapper.ClipsDescendants = false
mainWrapper.ZIndex = 1

local mainFrame = Instance.new("Frame", mainWrapper)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.ZIndex = 2
mainFrame.ClipsDescendants = false

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

-- ==================== GRADIENT PANELS ====================
local function CreateGradientPanel(parent, size, pos, name)
    local panel = Instance.new("Frame", parent)
    panel.Name = name
    panel.Size = size
    panel.Position = pos
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ZIndex = 5
    panel.ClipsDescendants = false
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
    local outerStroke = Instance.new("UIStroke", panel)
    outerStroke.Name = "OuterStroke"
    outerStroke.Thickness = 2.5
    outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    outerStroke.Color = Color3.fromRGB(255, 255, 255)
    local outerGrad = Instance.new("UIGradient", outerStroke)
    outerGrad.Rotation = 45
    outerGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 20, 30))
    })
    local InnerBg = Instance.new("Frame", panel)
    InnerBg.Name = "InnerBg"
    InnerBg.Size = UDim2.new(1, 0, 1, 0)
    InnerBg.BackgroundColor3 = Color3.fromRGB(15, 0, 3)
    InnerBg.BackgroundTransparency = 0
    InnerBg.BorderSizePixel = 0
    InnerBg.ClipsDescendants = true
    InnerBg.ZIndex = 5
    Instance.new("UICorner", InnerBg).CornerRadius = UDim.new(0, 10)
    local overlay = Instance.new("Frame", InnerBg)
    overlay.Name = "RedGradientOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    overlay.BackgroundTransparency = 0
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 5
    Instance.new("UICorner", overlay).CornerRadius = UDim.new(0, 10)
    local redGrad = Instance.new("UIGradient", overlay)
    redGrad.Rotation = 90
    redGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 0, 5)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 20, 30))
    })
    RunService.RenderStepped:Connect(function()
        redGrad.Rotation = (os.clock() * 12) % 360
    end)
    return panel
end

local LeftPanel  = CreateGradientPanel(mainFrame, UDim2.new(0, 200, 1, 0), UDim2.new(0, 0, 0, 0), "LeftPanel")
local RightPanel = CreateGradientPanel(mainFrame, UDim2.new(1, -215, 1, 0), UDim2.new(0, 215, 0, 0), "RightPanel")

-- ==================== LEFT PANEL CONTENTS ====================
local LeftSeparatorLine = Instance.new("Frame", LeftPanel.InnerBg)
LeftSeparatorLine.Size = UDim2.new(1, 0, 0, 1)
LeftSeparatorLine.Position = UDim2.new(0, 0, 0, 36)
LeftSeparatorLine.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
LeftSeparatorLine.BackgroundTransparency = 0.5
LeftSeparatorLine.BorderSizePixel = 0
LeftSeparatorLine.ZIndex = 10

local HeaderLeft = Instance.new("Frame", LeftPanel.InnerBg)
HeaderLeft.Size = UDim2.new(1, 0, 0, 36)
HeaderLeft.Position = UDim2.new(0, 0, 0, 0)
HeaderLeft.BackgroundTransparency = 1
HeaderLeft.ZIndex = 10

local title = Instance.new("TextLabel", HeaderLeft)
title.Size = UDim2.new(1, 0, 0, 16)
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 4)
title.BackgroundTransparency = 1
title.Text = "AKATSUKI SCRIPTS"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Center
title.ZIndex = 11

local subtitle = Instance.new("TextLabel", HeaderLeft)
subtitle.Size = UDim2.new(1, 0, 0, 12)
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Position = UDim2.new(0.5, 0, 0, 20)
subtitle.BackgroundTransparency = 1
subtitle.Text = "BLOX FRUITS | by zeni <3"
subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
subtitle.TextTransparency = 0.2
subtitle.TextSize = 9.5
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Center
subtitle.ZIndex = 11

local TabsContainer = Instance.new("ScrollingFrame", LeftPanel.InnerBg)
TabsContainer.Name = "TabsContainer"
TabsContainer.Size = UDim2.new(1, -8, 1, -130)
TabsContainer.Position = UDim2.new(0, 4, 0, 44)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ZIndex = 10
TabsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
TabsContainer.ScrollBarThickness = 3
TabsContainer.ScrollBarImageColor3 = Color3.fromRGB(200, 50, 50)
TabsContainer.ScrollBarImageTransparency = 0.2
TabsContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

local TabsLayout = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabsLayout.Padding = UDim.new(0, 2)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function UpdateTabsCanvas()
    local contentH = TabsLayout.AbsoluteContentSize.Y + 8
    TabsContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(contentH, TabsContainer.AbsoluteSize.Y + 12))
end
TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabsCanvas)
TabsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTabsCanvas)

local UserProfileFrame = Instance.new("Frame", LeftPanel.InnerBg)
UserProfileFrame.Size = UDim2.new(1, -12, 0, 75)
UserProfileFrame.Position = UDim2.new(0, 6, 1, -81)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
UserProfileFrame.BackgroundTransparency = 0.5
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex = 10
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 8)
local userGrad = Instance.new("UIGradient", UserProfileFrame)
userGrad.Rotation = 45
userGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 20)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 5, 5))
})

local AvatarImage = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Size = UDim2.new(0, 50, 0, 50)
AvatarImage.Position = UDim2.new(0, 8, 0.5, -25)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex = 11
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

local DisplayNameLabel = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Size = UDim2.new(1, -94, 0, 16)
DisplayNameLabel.Position = UDim2.new(0, 64, 0.5, -18)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
DisplayNameLabel.Font = Enum.Font.GothamBold
DisplayNameLabel.TextSize = 11
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLabel.ZIndex = 11

local UsernameLabel = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Size = UDim2.new(1, -94, 0, 14)
UsernameLabel.Position = UDim2.new(0, 64, 0.5, 2)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text = "@" .. player.Name
UsernameLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
UsernameLabel.Font = Enum.Font.Gotham
UsernameLabel.TextSize = 10
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UsernameLabel.ZIndex = 11

local PrivacyBtn = Instance.new("ImageButton", UserProfileFrame)
PrivacyBtn.Size = UDim2.new(0, 24, 0, 24)
PrivacyBtn.Position = UDim2.new(1, -28, 0, 4)
PrivacyBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
PrivacyBtn.BackgroundTransparency = 0.4
PrivacyBtn.BorderSizePixel = 0
PrivacyBtn.ZIndex = 12
Instance.new("UICorner", PrivacyBtn).CornerRadius = UDim.new(0, 6)
local privGrad = Instance.new("UIGradient", PrivacyBtn)
privGrad.Rotation = 45
privGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0))
})
local PrivacyIcon = Instance.new("ImageLabel", PrivacyBtn)
PrivacyIcon.Size = UDim2.new(1, -6, 1, -6)
PrivacyIcon.Position = UDim2.new(0, 3, 0, 3)
PrivacyIcon.BackgroundTransparency = 1
PrivacyIcon.Image = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
PrivacyIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
PrivacyIcon.ZIndex = 13

local isPrivate = false
PrivacyBtn.MouseButton1Click:Connect(function()
    PlayUI_Click()
    isPrivate = not isPrivate
    if isPrivate then
        PrivacyIcon.Image = "rbxthumb://type=Asset&id=85795266774996&w=150&h=150"
        DisplayNameLabel.Text = string.rep("*", math.clamp(#player.DisplayName, 3, 8))
        UsernameLabel.Text = "@" .. string.rep("*", math.clamp(#player.Name, 3, 8))
    else
        PrivacyIcon.Image = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
        DisplayNameLabel.Text = player.DisplayName
        UsernameLabel.Text = "@" .. player.Name
    end
end)

-- ==================== RIGHT PANEL HEADER ====================
local topButtons = Instance.new("Frame", RightPanel.InnerBg)
topButtons.Size = UDim2.new(1, -12, 0, 36)
topButtons.Position = UDim2.new(0, 0, 0, 0)
topButtons.BackgroundTransparency = 1
topButtons.ZIndex = 10

local ControlsFrame = Instance.new("Frame", topButtons)
ControlsFrame.Size = UDim2.new(0, 120, 1, 0)
ControlsFrame.Position = UDim2.new(1, -120, 0, 0)
ControlsFrame.BackgroundTransparency = 1
ControlsFrame.ZIndex = 11

local UIListTop = Instance.new("UIListLayout", ControlsFrame)
UIListTop.FillDirection = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding = UDim.new(0, 5)
UIListTop.SortOrder = Enum.SortOrder.LayoutOrder

local function MakeControlBtn(order)
    local btn = Instance.new("TextButton", ControlsFrame)
    btn.LayoutOrder = order
    btn.Size = UDim2.new(0, 24, 0, 24)
    btn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    btn.BackgroundTransparency = 0.3
    btn.Text = ""
    btn.ZIndex = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    return btn
end

local SearchBtn = MakeControlBtn(1); SearchBtn.Name = "SearchBtn"; SearchBtn.ClipsDescendants = true
local searchCircleFrame = Instance.new("Frame", SearchBtn)
searchCircleFrame.Size = UDim2.new(0, 12, 0, 12); searchCircleFrame.AnchorPoint = Vector2.new(0, 0.5)
searchCircleFrame.Position = UDim2.new(0, 6, 0.5, 0); searchCircleFrame.BackgroundTransparency = 1; searchCircleFrame.ZIndex = 12
local searchCircleInner = Instance.new("Frame", searchCircleFrame)
searchCircleInner.Size = UDim2.new(0, 7, 0, 7); searchCircleInner.BackgroundTransparency = 1; searchCircleInner.ZIndex = 12
Instance.new("UICorner", searchCircleInner).CornerRadius = UDim.new(1, 0)
local circleStroke = Instance.new("UIStroke", searchCircleInner); circleStroke.Color = Color3.fromHex("#A0A0A0"); circleStroke.Thickness = 1
local searchHandle = Instance.new("Frame", searchCircleFrame)
searchHandle.Size = UDim2.new(0, 1, 0, 4); searchHandle.Position = UDim2.new(0, 8, 0, 7)
searchHandle.Rotation = -45; searchHandle.BackgroundColor3 = Color3.fromHex("#A0A0A0"); searchHandle.BorderSizePixel = 0; searchHandle.ZIndex = 12
local searchTextBox = Instance.new("TextBox", SearchBtn)
searchTextBox.Size = UDim2.new(1, -26, 1, 0); searchTextBox.Position = UDim2.new(0, 24, 0, 0)
searchTextBox.BackgroundTransparency = 1; searchTextBox.PlaceholderText = UI_TEXT.SearchPlaceholder
searchTextBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120); searchTextBox.Text = ""
searchTextBox.TextColor3 = Color3.fromRGB(230, 230, 230); searchTextBox.Font = Enum.Font.Gotham
searchTextBox.TextSize = 10; searchTextBox.TextXAlignment = Enum.TextXAlignment.Left; searchTextBox.Visible = false; searchTextBox.ZIndex = 12

local MinimizeBtn = MakeControlBtn(2); MinimizeBtn.Name = "MinimizeBtn"
local MinimizeLine = Instance.new("Frame", MinimizeBtn)
MinimizeLine.AnchorPoint = Vector2.new(0.5, 0.5); MinimizeLine.Position = UDim2.new(0.5, 0, 0.5, 0)
MinimizeLine.Size = UDim2.new(0, 9, 0, 1.2); MinimizeLine.BackgroundColor3 = Color3.fromHex("#A0A0A0"); MinimizeLine.BorderSizePixel = 0; MinimizeLine.ZIndex = 12

local ExpandBtn = MakeControlBtn(3); ExpandBtn.Name = "ExpandBtn"
local ExpandSquare = Instance.new("Frame", ExpandBtn)
ExpandSquare.Size = UDim2.new(0, 7, 0, 7); ExpandSquare.AnchorPoint = Vector2.new(0.5, 0.5)
ExpandSquare.Position = UDim2.new(0.5, 0, 0.5, 0); ExpandSquare.BackgroundTransparency = 1; ExpandSquare.ZIndex = 12
local ExpandStroke = Instance.new("UIStroke", ExpandSquare); ExpandStroke.Color = Color3.fromHex("#A0A0A0"); ExpandStroke.Thickness = 1

local CloseBtn = MakeControlBtn(4); CloseBtn.Name = "CloseBtn"
local CloseLine1 = Instance.new("Frame", CloseBtn)
CloseLine1.AnchorPoint = Vector2.new(0.5, 0.5); CloseLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine1.Size = UDim2.new(0, 10, 0, 1.2); CloseLine1.Rotation = 45; CloseLine1.BackgroundColor3 = Color3.fromHex("#A0A0A0"); CloseLine1.BorderSizePixel = 0; CloseLine1.ZIndex = 12
local CloseLine2 = Instance.new("Frame", CloseBtn)
CloseLine2.AnchorPoint = Vector2.new(0.5, 0.5); CloseLine2.Position = UDim2.new(0.5, 0, 0.5, 0)
CloseLine2.Size = UDim2.new(0, 10, 0, 1.2); CloseLine2.Rotation = -45; CloseLine2.BackgroundColor3 = Color3.fromHex("#A0A0A0"); CloseLine2.BorderSizePixel = 0; CloseLine2.ZIndex = 12

local RightSeparatorLine = Instance.new("Frame", RightPanel.InnerBg)
RightSeparatorLine.Size = UDim2.new(1, 0, 0, 1); RightSeparatorLine.Position = UDim2.new(0, 0, 0, 36)
RightSeparatorLine.BackgroundColor3 = Color3.fromRGB(255, 80, 80); RightSeparatorLine.BackgroundTransparency = 0.5
RightSeparatorLine.BorderSizePixel = 0; RightSeparatorLine.ZIndex = 10

local BadgeFrame = Instance.new("Frame", RightPanel.InnerBg)
BadgeFrame.Size = UDim2.new(0, 45, 0, 18); BadgeFrame.Position = UDim2.new(0, 12, 0, 9)
BadgeFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255); BadgeFrame.BorderSizePixel = 0; BadgeFrame.ZIndex = 15
Instance.new("UICorner", BadgeFrame).CornerRadius = UDim.new(1, 0)
local badgeGrad = Instance.new("UIGradient", BadgeFrame)
badgeGrad.Rotation = 45
badgeGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0))
})
local BadgeText = Instance.new("TextLabel", BadgeFrame)
BadgeText.Size = UDim2.new(1, 0, 1, 0); BadgeText.BackgroundTransparency = 1
BadgeText.Text = "v1.1.1"; BadgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
BadgeText.Font = Enum.Font.GothamBold; BadgeText.TextSize = 10; BadgeText.ZIndex = 16

-- ==================== TOGGLES CONTAINER ====================
local togglesContainer = Instance.new("ScrollingFrame", RightPanel.InnerBg)
togglesContainer.Name = "TogglesContainer"
togglesContainer.Size = UDim2.new(1, -6, 1, -48)
togglesContainer.Position = UDim2.new(0, 0, 0, 42)
togglesContainer.BackgroundTransparency = 1
togglesContainer.BorderSizePixel = 0
togglesContainer.ScrollBarThickness = 3
togglesContainer.ScrollBarImageColor3 = Color3.fromRGB(220, 30, 40)
togglesContainer.ScrollBarImageTransparency = 0
togglesContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
togglesContainer.ZIndex = 10

local containerLayout = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
containerLayout.Padding = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local uiPadding = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingTop = UDim.new(0, 8); uiPadding.PaddingBottom = UDim.new(0, 8)
uiPadding.PaddingLeft = UDim.new(0, 4); uiPadding.PaddingRight = UDim.new(0, 8)

local function UpdateCanvasSize()
    local contentHeight = containerLayout.AbsoluteContentSize.Y + 24
    togglesContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(contentHeight, togglesContainer.AbsoluteSize.Y + 1))
end
containerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvasSize)
togglesContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateCanvasSize)

-- ==================== CONFIRM FRAME ====================
local confirmFrame = Instance.new("Frame", mainWrapper)
confirmFrame.Name = "ConfirmFrame"; confirmFrame.Size = UDim2.new(1, 0, 1, 0)
confirmFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0); confirmFrame.BackgroundTransparency = 0
confirmFrame.Visible = false; confirmFrame.ZIndex = 999
Instance.new("UICorner", confirmFrame).CornerRadius = UDim.new(0, 10)

local confirmLabel = Instance.new("TextLabel", confirmFrame)
confirmLabel.Size = UDim2.new(1, 0, 0, 30); confirmLabel.Position = UDim2.new(0, 0, 0.35, -10)
confirmLabel.BackgroundTransparency = 1; confirmLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
confirmLabel.Font = Enum.Font.GothamBold; confirmLabel.TextSize = 14
confirmLabel.Text = UI_TEXT.ConfirmCloseTitle; confirmLabel.ZIndex = 1000

local btnYes = Instance.new("TextButton", confirmFrame)
btnYes.Size = UDim2.new(0, 110, 0, 34); btnYes.Position = UDim2.new(0.5, -115, 0.55, 0)
btnYes.BackgroundColor3 = Color3.fromHex("#8B0000"); btnYes.TextColor3 = Color3.fromRGB(255, 255, 255)
btnYes.Font = Enum.Font.GothamMedium; btnYes.TextSize = 12; btnYes.Text = UI_TEXT.ConfirmBtn; btnYes.ZIndex = 1000
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 6)

local btnNo = Instance.new("TextButton", confirmFrame)
btnNo.Size = UDim2.new(0, 110, 0, 34); btnNo.Position = UDim2.new(0.5, 5, 0.55, 0)
btnNo.BackgroundColor3 = Color3.fromRGB(26, 26, 26); btnNo.TextColor3 = Color3.fromRGB(180, 180, 180)
btnNo.Font = Enum.Font.GothamMedium; btnNo.TextSize = 12; btnNo.Text = UI_TEXT.CancelBtn; btnNo.ZIndex = 1000
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 6)

-- ==================== TELEPORT TAB ====================
local teleportScrollFrame = Instance.new("ScrollingFrame", RightPanel.InnerBg)
teleportScrollFrame.Name = "TeleportScroll"
teleportScrollFrame.Size = UDim2.new(1, -6, 1, -48)
teleportScrollFrame.Position = UDim2.new(0, 0, 0, 42)
teleportScrollFrame.BackgroundTransparency = 1
teleportScrollFrame.BorderSizePixel = 0
teleportScrollFrame.ScrollBarThickness = 3
teleportScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(220, 30, 40)
teleportScrollFrame.ScrollBarImageTransparency = 0
teleportScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
teleportScrollFrame.ZIndex = 10
teleportScrollFrame.Visible = false

local tpLayout = Instance.new("UIListLayout", teleportScrollFrame)
tpLayout.SortOrder = Enum.SortOrder.LayoutOrder
tpLayout.Padding = UDim.new(0, 5)
tpLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local tpPad = Instance.new("UIPadding", teleportScrollFrame)
tpPad.PaddingTop = UDim.new(0, 8); tpPad.PaddingBottom = UDim.new(0, 8)
tpPad.PaddingLeft = UDim.new(0, 4); tpPad.PaddingRight = UDim.new(0, 8)

local seaLabels = { [0] = "Especiais", [1] = "Primeiro Mar", [2] = "Segundo Mar", [3] = "Terceiro Mar" }
local createdSections = {}

local function GetOrCreateSection(seaNum)
    if createdSections[seaNum] then return createdSections[seaNum] end
    local section = Instance.new("Frame", teleportScrollFrame)
    section.Name = "Section_" .. seaNum
    section.Size = UDim2.new(1, -12, 0, 22)
    section.BackgroundTransparency = 1
    section.ZIndex = 11
    local lbl = Instance.new("TextLabel", section)
    lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = seaLabels[seaNum] or ("Mar " .. seaNum)
    lbl.TextColor3 = Color3.fromRGB(255, 80, 80); lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 12
    createdSections[seaNum] = section
    return section
end

for _, tp in ipairs(Teleports) do
    GetOrCreateSection(tp.Sea)
    local btn = Instance.new("TextButton", teleportScrollFrame)
    btn.Name = "TP_" .. tp.Name
    btn.Size = UDim2.new(1, -12, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
    btn.BackgroundTransparency = 0.45
    btn.Text = ""
    btn.ZIndex = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", btn); stroke.Color = Color3.fromHex("#141414"); stroke.Thickness = 1
    local lbl = Instance.new("TextLabel", btn)
    lbl.Size = UDim2.new(1, -65, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = tp.Name
    lbl.TextColor3 = Color3.fromHex("#CCCCCC"); lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 12
    local icon = Instance.new("TextLabel", btn)
    icon.Size = UDim2.new(0, 50, 1, 0); icon.Position = UDim2.new(1, -55, 0, 0)
    icon.BackgroundTransparency = 1; icon.Text = "TP  ›"
    icon.TextColor3 = Color3.fromRGB(200, 50, 50); icon.Font = Enum.Font.GothamBold
    icon.TextSize = 13; icon.ZIndex = 12
    local tpPos = tp.Position
    btn.MouseButton1Click:Connect(function()
        PlayUI_Click()
        local t = TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.1})
        t:Play(); t.Completed:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.45}):Play()
        end)
        SafeTeleport(tpPos)
    end)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.25}):Play()
        TweenService:Create(lbl, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.45}):Play()
        TweenService:Create(lbl, TweenInfo.new(0.15), {TextColor3 = Color3.fromHex("#CCCCCC")}):Play()
    end)
end

local function UpdateTpCanvas()
    local h = tpLayout.AbsoluteContentSize.Y + 24
    teleportScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(h, teleportScrollFrame.AbsoluteSize.Y + 1))
end
tpLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTpCanvas)
teleportScrollFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTpCanvas)

-- ==================== FILTER & TABS LOGIC ====================
local function filterToggles(currentActiveTab, query)
    local searchQuery = (query or ""):lower()
    local itemIndex = 0
    for _, child in ipairs(togglesContainer:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
            local itemTab = child:GetAttribute("Tab") or ""
            local shouldBeVisible = false
            if searchQuery ~= "" then
                local titleLabel = child:FindFirstChild("Title")
                shouldBeVisible = titleLabel and titleLabel.Text:lower():find(searchQuery) ~= nil
            else
                shouldBeVisible = (itemTab == currentActiveTab)
            end
            if shouldBeVisible then
                child.Visible = true
                itemIndex = itemIndex + 1
                child.Size = UDim2.new(1, -12, 0, 0)
                child.BackgroundTransparency = 1
                local t = child:FindFirstChild("Title")
                local d = child:FindFirstChild("Description")
                if t then t.TextTransparency = 1 end
                if d then d.TextTransparency = 1 end
                task.delay((itemIndex - 1) * 0.02, function()
                    if not child or not child.Parent then return end
                    TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, -12, 0, 52), BackgroundTransparency = 0.45
                    }):Play()
                    if t then TweenService:Create(t, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
                    if d then TweenService:Create(d, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
                end)
            else
                child.Visible = false
            end
        end
    end
    task.delay(0.05, UpdateCanvasSize)
end

local function selectTab(tabName)
    activeTab = tabName
    local isTeleport = (tabName == "Teleports")
    togglesContainer.Visible = not isTeleport
    teleportScrollFrame.Visible = isTeleport

    local animSpeed = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for name, btn in pairs(tabButtons) do
        local label = btn:FindFirstChild("Label")
        local activeBar = btn:FindFirstChild("ActiveBar")
        local iconContainer = btn:FindFirstChild("Icon")
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
    if not isTeleport then
        filterToggles(tabName, "")
    end
end

-- ==================== CREATE TAB BTN ====================
local tabIconMap = {
    AutoFarm  = "rbxthumb://type=Asset&id=107032293182891&w=150&h=150",
    PvP       = "rbxthumb://type=Asset&id=105897102093789&w=150&h=150",
    Raids     = "rbxthumb://type=Asset&id=97681798175944&w=150&h=150",
    Teleports = "rbxthumb://type=Asset&id=131082536388353&w=150&h=150",
    Settings  = "rbxthumb://type=Asset&id=88409765080516&w=150&h=150",
}

local function createTabBtn(tabName)
    local tabBtn = Instance.new("TextButton", TabsContainer)
    tabBtn.Name = tabName .. "TabBtn"
    tabBtn.Size = UDim2.new(1, -16, 0, 36)
    tabBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text = ""
    tabBtn.ZIndex = 11
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 8)
    local activeBar = Instance.new("Frame", tabBtn)
    activeBar.Name = "ActiveBar"; activeBar.Size = UDim2.new(0, 3, 0, 20)
    activeBar.Position = UDim2.new(0, 2, 0.5, -10); activeBar.BackgroundColor3 = Color3.fromHex("#8B0000")
    activeBar.BorderSizePixel = 0; activeBar.Visible = false; activeBar.ZIndex = 13
    Instance.new("UICorner", activeBar).CornerRadius = UDim.new(1, 0)
    local iconContainer = Instance.new("Frame", tabBtn)
    iconContainer.Name = "Icon"; iconContainer.Size = UDim2.new(0, 18, 0, 18)
    iconContainer.Position = UDim2.new(0, 12, 0.5, -9); iconContainer.BackgroundTransparency = 1; iconContainer.ZIndex = 12
    local imageLabel = Instance.new("ImageLabel", iconContainer)
    imageLabel.Name = "AccentImage"; imageLabel.Size = UDim2.new(1, 0, 1, 0)
    imageLabel.BackgroundTransparency = 1; imageLabel.ZIndex = 13
    imageLabel.ImageColor3 = Color3.fromRGB(150, 150, 150)
    imageLabel.Image = tabIconMap[tabName] or ""
    local tabLabel = Instance.new("TextLabel", tabBtn)
    tabLabel.Name = "Label"; tabLabel.Size = UDim2.new(1, -42, 1, 0)
    tabLabel.Position = UDim2.new(0, 38, 0, 0); tabLabel.BackgroundTransparency = 1
    tabLabel.TextColor3 = Color3.fromRGB(150, 150, 150); tabLabel.Font = Enum.Font.GothamMedium
    tabLabel.TextSize = 11; tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.Text = UI_TEXT.Tabs[tabName] or tabName; tabLabel.ZIndex = 12
    tabBtn.MouseButton1Click:Connect(function() selectTab(tabName) end)
    tabButtons[tabName] = tabBtn
end

-- ==================== CREATE TOGGLE ====================
local function createToggle(parent, configKey, tabCategory)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = configKey
    toggleFrame.Size = UDim2.new(1, -12, 0, 52)
    toggleFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
    toggleFrame.BackgroundTransparency = 0.45
    toggleFrame.ZIndex = 11
    toggleFrame.ClipsDescendants = true
    toggleFrame:SetAttribute("Tab", tabCategory)
    toggleFrame:SetAttribute("ConfigKey", configKey)
    toggleFrame.Parent = parent
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", toggleFrame); stroke.Color = Color3.fromHex("#141414"); stroke.Thickness = 1
    local optData = UI_TEXT.Options[configKey]
    local titleLabel = Instance.new("TextLabel", toggleFrame)
    titleLabel.Name = "Title"; titleLabel.Size = UDim2.new(0.7, 0, 0, 16)
    titleLabel.Position = UDim2.new(0, 10, 0, 6); titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromHex("#CCCCCC"); titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11; titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = optData and optData.Title or configKey; titleLabel.ZIndex = 11
    local descLabel = Instance.new("TextLabel", toggleFrame)
    descLabel.Name = "Description"; descLabel.Size = UDim2.new(0.7, 0, 0, 26)
    descLabel.Position = UDim2.new(0, 10, 0, 22); descLabel.BackgroundTransparency = 1
    descLabel.TextColor3 = Color3.fromRGB(130, 130, 130); descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 9; descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top; descLabel.TextWrapped = true
    descLabel.Text = optData and optData.Desc or ""; descLabel.ZIndex = 11
    local switchTrack = Instance.new("Frame", toggleFrame)
    switchTrack.Size = UDim2.new(0, 38, 0, 18); switchTrack.Position = UDim2.new(1, -48, 0.5, -9)
    switchTrack.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
    switchTrack.ZIndex = 11
    Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)
    local switchCircle = Instance.new("Frame", switchTrack)
    switchCircle.Size = UDim2.new(0, 12, 0, 12)
    switchCircle.Position = Configs[configKey] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
    switchCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255); switchCircle.ZIndex = 12
    Instance.new("UICorner", switchCircle).CornerRadius = UDim.new(1, 0)
    local triggerBtn = Instance.new("TextButton", toggleFrame)
    triggerBtn.Size = UDim2.new(1, 0, 1, 0); triggerBtn.BackgroundTransparency = 1
    triggerBtn.Text = ""; triggerBtn.ZIndex = 13

    triggerBtn.MouseButton1Click:Connect(function()
        Configs[configKey] = not Configs[configKey]
        local on = Configs[configKey]
        local targetPos   = on and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        local targetColor = on and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
        local anim = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(switchCircle, anim, {Position = targetPos}):Play()
        TweenService:Create(switchTrack, anim, {BackgroundColor3 = targetColor}):Play()

        if configKey == "AutoFarm" then
            if on then StartAutoFarm() else StopAutoFarm() end
        elseif configKey == "AutoFarmBoss" then
            if on then StartAutoFarmBoss() end
        elseif configKey == "AutoCollectChest" then
            if on then StartAutoChest() end
        elseif configKey == "AutoStats" then
            if on then StartAutoStats() end
        elseif configKey == "AimbotPvP" then
            if on then StartAimbot() end
        elseif configKey == "PlayerESP" then
            UpdateESP()
            if not on then ClearESP() end
        elseif configKey == "FruitESP" then
            UpdateFruitESP()
        elseif configKey == "AutoRaid" then
            if on then StartAutoRaid() end
        elseif configKey == "ServerHop" then
            if on then pcall(ServerHop) end
        elseif configKey == "FruitSniper" then
            if on then
                task.spawn(function()
                    while Configs.FruitSniper do
                        if CharacterReady() then
                            for _, obj in ipairs(Workspace:GetDescendants()) do
                                if not Configs.FruitSniper then break end
                                local n = obj.Name:lower()
                                if (n:find("fruit") or n:find("devil")) and obj:IsA("Model") then
                                    local pp = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                                    if pp then
                                        SafeTeleport(pp.Position + Vector3.new(0, 3, 0))
                                        task.wait(0.5)
                                    end
                                end
                            end
                        end
                        task.wait(1)
                    end
                end)
            end
        elseif configKey == "AntiFlinch" then
            if antiFlinchConn then antiFlinchConn:Disconnect(); antiFlinchConn = nil end
            if on then
                antiFlinchConn = RunService.Stepped:Connect(function()
                    if not Configs.AntiFlinch then
                        if antiFlinchConn then antiFlinchConn:Disconnect(); antiFlinchConn = nil end
                        return
                    end
                    if character then
                        local hrp = character:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0) end
                    end
                end)
            end
        elseif configKey == "PvPAutoBlock" then
            if on then
                task.spawn(function()
                    local lastHealth = humanoid.Health
                    while Configs.PvPAutoBlock do
                        task.wait(0.1)
                        if humanoid.Health < lastHealth then
                            local tool = character:FindFirstChildOfClass("Tool")
                            if tool and tool:IsA("Tool") and tool:FindFirstChild("Handle") then
                                pcall(function()
                                    humanoid:EquipTool(tool)
                                    -- Simular bloqueio (depende do jogo)
                                    -- Pode ser necessário pressionar uma tecla ou usar remote
                                end)
                            end
                        end
                        lastHealth = humanoid.Health
                    end
                end)
            end
        end
    end)
end

-- ==================== SEARCH ====================
local searchExpanded = false
local searchInactivityTimer = nil

local function resetSearchInactivityTimer()
    if searchInactivityTimer then task.cancel(searchInactivityTimer) end
    searchInactivityTimer = task.delay(4, function()
        if searchExpanded and searchTextBox.Text == "" then
            searchExpanded = false
            TweenService:Create(SearchBtn, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 24, 0, 24)}):Play()
            searchTextBox:ReleaseFocus()
            task.delay(0.2, function() searchTextBox.Visible = false end)
            filterToggles(activeTab, "")
        end
    end)
end

SearchBtn.MouseButton1Click:Connect(function()
    PlayUI_Click()
    searchExpanded = not searchExpanded
    local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if searchExpanded then
        TweenService:Create(SearchBtn, info, {Size = UDim2.new(0, 120, 0, 24)}):Play()
        searchTextBox.Visible = true; searchTextBox:CaptureFocus()
        resetSearchInactivityTimer()
    else
        TweenService:Create(SearchBtn, info, {Size = UDim2.new(0, 24, 0, 24)}):Play()
        searchTextBox:ReleaseFocus(); searchTextBox.Text = ""
        task.delay(0.2, function() if not searchExpanded then searchTextBox.Visible = false end end)
        filterToggles(activeTab, "")
    end
end)
searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
    resetSearchInactivityTimer(); filterToggles(activeTab, searchTextBox.Text)
end)

-- ==================== EXPAND / MINIMIZE / CLOSE ====================
ExpandBtn.MouseButton1Click:Connect(function()
    PlayUI_Click()
    isExpanded = not isExpanded
    local newSize = isExpanded and UDim2.new(0, 800, 0, 480) or UDim2.new(0, 640, 0, 360)
    TweenService:Create(mainWrapper, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = newSize}):Play()
end)

SetUIState = function(newState)
    if UIState == newState or UIState == "OPENING" or UIState == "CLOSING" then return end
    UIState = (newState == "OPEN" and "OPENING") or "CLOSING"
    local t = 0.25
    local anim = TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if newState == "OPEN" then
        mainWrapper.Visible = true
        mainWrapper.Size = UDim2.new(0, 480, 0, 260)
        AplicarFadeSincronizado(mainWrapper, true, 0)
        AplicarFadeSincronizado(mainWrapper, false, t)
        local ot = TweenService:Create(mainWrapper, anim, {Size = isExpanded and UDim2.new(0, 800, 0, 480) or UDim2.new(0, 640, 0, 360)})
        ot:Play(); ot.Completed:Connect(function() UIState = "OPEN"; filterToggles(activeTab, searchTextBox.Text) end)
    else
        AplicarFadeSincronizado(mainWrapper, true, t)
        local ct = TweenService:Create(mainWrapper, anim, {Size = UDim2.new(0, 480, 0, 260)})
        ct:Play(); ct.Completed:Connect(function() mainWrapper.Visible = false; UIState = newState end)
    end
end

MinimizeBtn.MouseButton1Click:Connect(function() PlayUI_Click(); SetUIState("MINIMIZED") end)

local function AlternarConfirmacao(exibir)
    isConfirmOpen = exibir
    local t = 0.15
    if exibir then
        if not confirmBlur then confirmBlur = Instance.new("BlurEffect"); confirmBlur.Size = 0; confirmBlur.Parent = Lighting end
        confirmFrame.Visible = true
        AplicarFadeSincronizado(confirmFrame, true, 0)
        AplicarFadeSincronizado(confirmFrame, false, t)
        TweenService:Create(confirmBlur, TweenInfo.new(t, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 56}):Play()
    else
        AplicarFadeSincronizado(confirmFrame, true, t)
        if confirmBlur then
            local bt = TweenService:Create(confirmBlur, TweenInfo.new(t, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 0})
            bt:Play(); bt.Completed:Connect(function() if confirmBlur and confirmBlur.Size == 0 then confirmBlur:Destroy(); confirmBlur = nil end end)
        end
        task.delay(t, function() if not isConfirmOpen then confirmFrame.Visible = false end end)
    end
end

CloseBtn.MouseButton1Click:Connect(function() PlayUI_Click(); AlternarConfirmacao(true) end)
btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)
btnYes.MouseButton1Click:Connect(function()
    StopAutoFarm()
    Configs.AimbotPvP = false; Configs.AutoRaid = false; Configs.AntiFlinch = false; Configs.PlayerESP = false
    ClearESP()
    if aimbotConnection then aimbotConnection:Disconnect() end
    if antiFlinchConn then antiFlinchConn:Disconnect() end
    local s = 0.2
    if confirmBlur then TweenService:Create(confirmBlur, TweenInfo.new(s, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = 0}):Play() end
    AplicarFadeSincronizado(mainWrapper, true, s)
    TweenService:Create(FloatBtn, TweenInfo.new(s, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)}):Play()
    task.wait(s)
    screenGui:Destroy()
end)

-- ==================== BUTTON HOVER FX ====================
local function AplicarEfeitoBotao(btn)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 30, 30), BackgroundTransparency = 0.1}):Play()
        if btn.Name == "CloseBtn" then
            TweenService:Create(CloseLine1, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(255, 60, 60)}):Play()
            TweenService:Create(CloseLine2, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(255, 60, 60)}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 0.3}):Play()
        if btn.Name == "CloseBtn" then
            TweenService:Create(CloseLine1, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
            TweenService:Create(CloseLine2, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        end
    end)
end
AplicarEfeitoBotao(SearchBtn); AplicarEfeitoBotao(MinimizeBtn)
AplicarEfeitoBotao(ExpandBtn); AplicarEfeitoBotao(CloseBtn)

-- ==================== CRIAR ABAS E TOGGLES ====================
createTabBtn("AutoFarm")
createTabBtn("PvP")
createTabBtn("Raids")
createTabBtn("Teleports")
createTabBtn("Settings")

createToggle(togglesContainer, "AutoFarm",         "AutoFarm")
createToggle(togglesContainer, "AutoFarmBoss",     "AutoFarm")
createToggle(togglesContainer, "AutoCollectChest", "AutoFarm")
createToggle(togglesContainer, "AutoStats",        "AutoFarm")
createToggle(togglesContainer, "AimbotPvP",    "PvP")
createToggle(togglesContainer, "AntiFlinch",   "PvP")
createToggle(togglesContainer, "PvPAutoBlock", "PvP")
createToggle(togglesContainer, "FruitSniper",  "PvP")
createToggle(togglesContainer, "AutoRaid",    "Raids")
createToggle(togglesContainer, "RaidInstant", "Raids")
createToggle(togglesContainer, "PlayerESP",  "Settings")
createToggle(togglesContainer, "FruitESP",   "Settings")
createToggle(togglesContainer, "AutoRevive", "Settings")
createToggle(togglesContainer, "ServerHop",  "Settings")

-- ==================== ESP UPDATE LOOP ====================
RunService.Heartbeat:Connect(function()
    if Configs.PlayerESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and not espObjects[p] and p.Character then
                UpdateESP()
                break
            end
        end
    end
    if Configs.FruitESP then
        UpdateFruitESP()
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if espObjects[p] then
        pcall(function()
            if espObjects[p].Billboard then espObjects[p].Billboard:Destroy() end
        end)
        espObjects[p] = nil
    end
end)

-- ==================== ANIMAÇÃO DE INTRODUÇÃO ====================
local function ExecutarIntroAkat()
    local Blur = Instance.new("BlurEffect"); Blur.Size = 0; Blur.Parent = Lighting
    local IntroFrame = Instance.new("Frame", screenGui)
    IntroFrame.Size = UDim2.new(1, 0, 1, 0); IntroFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    IntroFrame.BackgroundTransparency = 1; IntroFrame.ZIndex = 500
    local MaskContainer = Instance.new("Frame", IntroFrame)
    MaskContainer.AnchorPoint = Vector2.new(0.5, 0.5); MaskContainer.Position = UDim2.new(0.5, 0, 0.5, -10)
    MaskContainer.Size = UDim2.new(0, 460, 0, 40); MaskContainer.BackgroundTransparency = 1
    MaskContainer.ClipsDescendants = true; MaskContainer.ZIndex = 501
    local IntroText = Instance.new("TextLabel", MaskContainer)
    IntroText.Size = UDim2.new(1, 0, 1, 0); IntroText.Position = UDim2.new(0, 0, 1, 0)
    IntroText.BackgroundTransparency = 1; IntroText.Font = Enum.Font.GothamBold
    IntroText.TextSize = 26; IntroText.RichText = true; IntroText.Text = UI_TEXT.Intro; IntroText.ZIndex = 502
    local IntroLine = Instance.new("Frame", IntroFrame)
    IntroLine.AnchorPoint = Vector2.new(0.5, 0.5); IntroLine.Position = UDim2.new(0.5, 0, 0.5, 16)
    IntroLine.Size = UDim2.new(0, 0, 0, 2); IntroLine.BackgroundColor3 = Color3.fromHex("#8B0000")
    IntroLine.BorderSizePixel = 0; IntroLine.BackgroundTransparency = 1; IntroLine.ZIndex = 503
    Instance.new("UICorner", IntroLine).CornerRadius = UDim.new(1, 0)

    TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.05}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 24}):Play()
    task.wait(0.1)
    TweenService:Create(IntroText, TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
    task.wait(0.2)
    TweenService:Create(IntroLine, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(0, 280, 0, 2)}):Play()
    task.wait(1.6)
    TweenService:Create(IntroText, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
    TweenService:Create(IntroLine, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play()
    task.wait(0.3)
    TweenService:Create(IntroFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play()
    task.wait(0.3)

    RegistrarTransparencias(mainWrapper)
    for _, item in ipairs(mainWrapper:GetDescendants()) do RegistrarTransparencias(item) end
    mainWrapper.Visible = true; FloatBtn.Visible = true; UIState = "OPEN"
    local MainScale = Instance.new("UIScale", mainWrapper); MainScale.Scale = 0.85
    AplicarFadeSincronizado(mainWrapper, true, 0)
    AplicarFadeSincronizado(mainWrapper, false, 0.35)
    local openScale = TweenService:Create(MainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
    openScale:Play()
    FloatBtn.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(FloatBtn, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 44, 0, 44)}):Play()
    openScale.Completed:Connect(function()
        selectTab("AutoFarm")
        MainScale:Destroy(); IntroFrame:Destroy(); Blur:Destroy()
    end)
end

task.spawn(ExecutarIntroAkat)
