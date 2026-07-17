-- [[
--     AKAT MM2 SCRIPT [BETA v2.4] - ANTI-BAN & FLOATING BUTTON OPTIMIZED
--     UPDATE 2026: ESP REWRITTEN & SILENT AIM (AUTO SHOOT) ADDED
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==================== VARIÁVEIS GLOBAIS DE PAPÉIS (NOVO SISTEMA 2026) ====================
local PlayerRolesCache = {}
local OriginalSheriff = nil
local CurrentMurderer = nil

local function IsRoundActive()
    return workspace:FindFirstChild("Normal") ~= nil or workspace:FindFirstChild("CoinContainer", true) ~= nil or workspace:FindFirstChild("Spawns", true) ~= nil
end

local function GetLiveMurderer()
    if CurrentMurderer and CurrentMurderer.Parent and CurrentMurderer.Character and CurrentMurderer.Character:FindFirstChild("Humanoid") and CurrentMurderer.Character.Humanoid.Health > 0 then
        return CurrentMurderer
    end
    for p, role in pairs(PlayerRolesCache) do
        if role == "Murderer" and p.Parent and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            CurrentMurderer = p
            return p
        end
    end
    return nil
end

-- ==================== ANTI-BAN & SILENT AIM (HOOKS) ====================
task.spawn(function()
    local gmt = getrawmetatable and getrawmetatable(game)
    if gmt and setreadonly and hookfunction and hookmetamethod then
        setreadonly(gmt, false)
        local oldIndex = gmt.__index
        local oldNamecall = gmt.__namecall

        -- Hook via Namecall (Bloqueio de Kicks)
        gmt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if tostring(method):lower() == "kick" and self == player then
                warn("[AKAT ANTI-BAN] Tentativa de Kick bloqueada com sucesso!")
                return nil
            end
            return oldNamecall(self, ...)
        end)

        -- Hook via Index (Bloqueio de Kicks Indiretos e Silent Aim para o Auto Shoot)
        gmt.__index = newcclosure(function(self, key)
            if tostring(key):lower() == "kick" and self == player then
                return newcclosure(function() 
                    warn("[AKAT ANTI-BAN] Tentativa de chamada de Kick indireta bloqueada!")
                end)
            end
            
            -- SILENT AIM (Interceptação direta e predição de tiro)
            if not checkcaller() and typeof(self) == "Instance" and self:IsA("Mouse") and Configs.AutoShoot then
                if key == "Hit" or key == "Target" then
                    local char = player.Character
                    local hasGunEquipped = false
                    if char then
                        for _, child in ipairs(char:GetChildren()) do
                            if child:IsA("Tool") and (child.Name:lower():find("gun") or child.Name:lower():find("sheriff") or child.Name:lower():find("revolver") or child:FindFirstChild("GunScript")) then
                                hasGunEquipped = true
                                break
                            end
                        end
                    end
                    
                    if hasGunEquipped then
                        local murderer = GetLiveMurderer()
                        if murderer and murderer.Character then
                            local head = murderer.Character:FindFirstChild("Head")
                            local myRoot = char:FindFirstChild("HumanoidRootPart")
                            if head and myRoot then
                                local root = murderer.Character:FindFirstChild("HumanoidRootPart")
                                local dist = (head.Position - myRoot.Position).Magnitude
                                local predPos = head.Position
                                if root then
                                    predPos = head.Position + (root.Velocity * (dist / 150)) -- Predição baseada no movimento
                                end
                                
                                if key == "Hit" then
                                    return CFrame.new(predPos)
                                elseif key == "Target" then
                                    return head
                                end
                            end
                        end
                    end
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

-- ==================== 1. CONFIGURAÇÕES E LOCALES ESTÁTICOS ====================
Configs = {
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

local Locales = {
    PT = {
        SearchPlaceholder = "Pesquisar...",
        ConfirmCloseTitle = "Deseja fechar o script?",
        ConfirmBtn = "Confirmar",
        CancelBtn = "Cancelar",
        Tabs = {
            Combat = "Combate",
            Visuals = "Visuais",
            Movement = "Movimento",
            Teleports = "Teleportes",
            Misc = "Diversos"
        },
        Options = {
            AutoShoot = { Title = "Atirar no Murder", Desc = "Mira silenciosa e disparo automático no Assassino ao equipar a arma." },
            Reach = { Title = "Alcance da Faca", Desc = "Aumenta consideravelmente o alcance de ataque com a sua faca." },
            ESP = { Title = "ESP Jogadores", Desc = "Destaca as funções reais: Vermelho(Murder), Azul(Sheriff), Amarelo(Hero) e Verde." },
            Speed = { Title = "Velocidade", Desc = "Aumenta levemente a velocidade do personagem para 23." },
            AntiFling = { Title = "Anti-Arremesso", Desc = "Bloqueia colisões que tentem te empurrar ou arremessar." },
            TpToGun = { Title = "Teleportar p/ Arma", Desc = "Teletransporta para a arma dropada e retorna ao local original." },
            SafeSpot = { Title = "Lugar Seguro", Desc = "Cria uma plataforma invisível no céu para ficar totalmente seguro." },
            AutoCollect = { Title = "Coletar Moedas", Desc = "Voa de forma segura recolhendo moedas pelo mapa." },
            ChatRoles = { Title = "Revelar Funções", Desc = "Envia no chat automaticamente quem é Assassino e Xerife." }
        },
        Intro = '<font color="#FFFFFF">Scripts por | </font><font color="#8B0000">Comunidade AKAT</font>'
    },
    EN = {
        SearchPlaceholder = "Search...",
        ConfirmCloseTitle = "Do you want to close the script?",
        ConfirmBtn = "Confirm",
        CancelBtn = "Cancel",
        Tabs = { Combat = "Combat", Visuals = "Visuals", Movement = "Movement", Teleports = "Teleports", Misc = "Misc" },
        Options = {
            AutoShoot = { Title = "Shoot Murderer", Desc = "Silent aim and automatic firing at Murderer when holding a gun." },
            Reach = { Title = "Knife Reach", Desc = "Significantly increases your knife attack reach." },
            ESP = { Title = "Player ESP", Desc = "Highlights true roles: Red(Murder), Blue(Sheriff), Yellow(Hero) & Green." },
            Speed = { Title = "WalkSpeed", Desc = "Slightly increases player walkspeed up to 23." },
            AntiFling = { Title = "Anti-Fling", Desc = "Disables collisions to prevent other players from flinging you." },
            TpToGun = { Title = "TP to Gun", Desc = "Teleports to the dropped gun and instantly returns to your spot." },
            SafeSpot = { Title = "Safe Spot", Desc = "Teleports you to an invisible sky platform to remain completely safe." },
            AutoCollect = { Title = "Auto Collect", Desc = "Flies safely through the map waiting for each coin." },
            ChatRoles = { Title = "Reveal Roles", Desc = "Automatically sends a message in chat revealing active roles." }
        },
        Intro = '<font color="#FFFFFF">Scripts by | </font><font color="#8B0000">AKAT Community</font>'
    },
    ES = {
        SearchPlaceholder = "Buscar...",
        ConfirmCloseTitle = "¿Deseas cerrar el script?",
        ConfirmBtn = "Confirmar",
        CancelBtn = "Cancelar",
        Tabs = { Combat = "Combate", Visuales = "Visuales", Movement = "Movimiento", Teleports = "Teleportes", Misc = "Varios" },
        Options = {
            AutoShoot = { Title = "Disparar al Asesino", Desc = "Aim silencioso y disparo automático al Asesino al equipar el arma." },
            Reach = { Title = "Alcance del Cuchillo", Desc = "Aumenta considerablemente el alcance de ataque con tu cuchillo." },
            ESP = { Title = "ESP Jogadores", Desc = "Resalta roles reales: Rojo(Asesino), Azul(Sheriff), Amarillo(Hero) y Verde." },
            Speed = { Title = "Velocidad", Desc = "Aumenta ligeramente la velocidad del personaje a 23." },
            AntiFling = { Title = "Anti-Fling", Desc = "Bloqueia colisiones para evitar que te empujen o lancen." },
            TpToGun = { Title = "TP a la Arma", Desc = "Teletransporta a la pistola tirada y regresa a tu lugar." },
            SafeSpot = { Title = "Lugar Seguro", Desc = "Te teletransporta a una plataforma invisible en el cielo." },
            AutoCollect = { Title = "Auto Monedas", Desc = "Vuela recolectando monedas de forma rápida y segura." },
            ChatRoles = { Title = "Revelar Roles", Desc = "Envía automáticamente en el chat quién es Asesino y Sheriff." }
        },
        Intro = '<font color="#FFFFFF">Scripts por | </font><font color="#8B0000">Comunidad AKAT</font>'
    }
}

-- ==================== 2. VARIÁVEIS DE ESTADO ====================
local currentLanguage = "EN"
local activeTab = "Combat"
local tabButtons = {} 
local menuAberto = true
local isMinimized = false
local hbConnection = nil 
local renderConnection = nil
local originalTrans = {}
local confirmBlur = nil
local isConfirmOpen = false
local wasMinimizedBeforeConfirm = false

local safePlatform = nil
local lastPositionBeforeSafeSpot = nil
local announcedThisRound = false
local lastShootTime = 0
local hasTeleportedToGun = false
local originalPositionBeforeGun = nil
local currentCollectTarget = nil 
local lastCoinSearch = 0
local wasAutoCollecting = false
local lastCoinCollectedTime = 0
local coinCollectionCooldown = 0.7

-- ==================== 3. INTERFACE (UI) ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeltaAkatUniversalUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true 

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then 
    uiParent = gethui()
else
    local successCore, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if successCore and coreGui then uiParent = coreGui end
end

if uiParent:FindFirstChild("DeltaAkatUniversalUI") then 
    pcall(function() uiParent.DeltaAkatUniversalUI:Destroy() end) 
end
screenGui.Parent = uiParent

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
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8) 
local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Thickness = 1
FloatStroke.Color = Color3.fromRGB(255, 255, 255)
local StrokeGradient = Instance.new("UIGradient", FloatStroke)
StrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromHex("#8B0000")),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 15, 15)), 
    ColorSequenceKeypoint.new(1, Color3.fromHex("#8B0000"))
})

task.spawn(function()
    local rot = 0
    while task.wait() do
        if not StrokeGradient.Parent then break end
        rot = (rot + 3) % 360
        StrokeGradient.Rotation = rot
    end
end)

local mainWrapper = Instance.new("Frame")
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0)
mainWrapper.Size = UDim2.new(0, 520, 0, 300)
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, -150)
mainWrapper.BackgroundTransparency = 1
mainWrapper.ClipsDescendants = false
mainWrapper.Visible = false
mainWrapper.Parent = screenGui

local shadow3D = Instance.new("ImageLabel", mainWrapper)
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

local mainFrame = Instance.new("Frame", mainWrapper)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundColor3 = Color3.fromHex("#0A0A0A")
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true 
mainFrame.ZIndex = 5
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 9)
local frameStroke = Instance.new("UIStroke", mainFrame)
frameStroke.Color = Color3.fromHex("#161616")
frameStroke.Thickness = 1

local topBar = Instance.new("Frame", mainFrame)
topBar.Size = UDim2.new(1, 0, 0, 52)
topBar.BackgroundTransparency = 1
topBar.ZIndex = 6

local title = Instance.new("TextLabel", topBar)
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
subtitle.Size = UDim2.new(0, 200, 0, 14)
subtitle.Position = UDim2.new(0, 16, 0, 28)
subtitle.BackgroundTransparency = 1
subtitle.Text = "MM2 SCRIPT [BETA]"
subtitle.TextColor3 = Color3.fromHex("#555555")
subtitle.TextSize = 10
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 6

local searchBarFrame = Instance.new("Frame", topBar)
searchBarFrame.AnchorPoint = Vector2.new(1, 0.5)
searchBarFrame.Position = UDim2.new(1, -154, 0.5, 0)
searchBarFrame.Size = UDim2.new(0, 0, 0, 26) 
searchBarFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
searchBarFrame.ClipsDescendants = true
searchBarFrame.ZIndex = 7
Instance.new("UICorner", searchBarFrame).CornerRadius = UDim.new(0, 13) 
local searchStroke = Instance.new("UIStroke", searchBarFrame)
searchStroke.Color = Color3.fromHex("#1F1F1F")

local searchTextBox = Instance.new("TextBox", searchBarFrame)
searchTextBox.Size = UDim2.new(1, -20, 1, 0)
searchTextBox.Position = UDim2.new(0, 12, 0, 0)
searchTextBox.BackgroundTransparency = 1
searchTextBox.PlaceholderText = "Pesquisar..."
searchTextBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
searchTextBox.Text = ""
searchTextBox.TextColor3 = Color3.fromRGB(230, 230, 230)
searchTextBox.Font = Enum.Font.Gotham
searchTextBox.TextSize = 11
searchTextBox.TextXAlignment = Enum.TextXAlignment.Left
searchTextBox.ZIndex = 8

local topButtons = Instance.new("Frame", topBar)
topButtons.Size = UDim2.new(0, 128, 0, 26) 
topButtons.Position = UDim2.new(1, -144, 0.5, -13) 
topButtons.BackgroundTransparency = 1
topButtons.ZIndex = 6

local UIListTop = Instance.new("UIListLayout", topButtons)
UIListTop.FillDirection = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding = UDim.new(0, 8)
UIListTop.SortOrder = Enum.SortOrder.LayoutOrder

local LanguageBtn = Instance.new("TextButton", topButtons)
LanguageBtn.Name = "LanguageBtn"
LanguageBtn.LayoutOrder = 0
LanguageBtn.Size = UDim2.new(0, 26, 0, 26)
LanguageBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
LanguageBtn.Text = currentLanguage
LanguageBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
LanguageBtn.Font = Enum.Font.GothamBold
LanguageBtn.TextSize = 10
LanguageBtn.ZIndex = 7
Instance.new("UICorner", LanguageBtn).CornerRadius = UDim.new(0, 5)

local SearchBtn = Instance.new("TextButton", topButtons)
SearchBtn.Name = "SearchBtn"
SearchBtn.LayoutOrder = 1
SearchBtn.Size = UDim2.new(0, 26, 0, 26)
SearchBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
SearchBtn.Text = ""
SearchBtn.ZIndex = 7
Instance.new("UICorner", SearchBtn).CornerRadius = UDim.new(0, 5)

local SearchIcon = Instance.new("Frame", SearchBtn)
SearchIcon.Size = UDim2.new(0, 14, 0, 14)
SearchIcon.AnchorPoint = Vector2.new(0.5, 0.5)
SearchIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
SearchIcon.BackgroundTransparency = 1
SearchIcon.ZIndex = 8
local SearchCircle = Instance.new("Frame", SearchIcon)
SearchCircle.Size = UDim2.new(0, 8, 0, 8)
SearchCircle.Position = UDim2.new(0, 1, 0, 1)
SearchCircle.BackgroundTransparency = 1
SearchCircle.ZIndex = 8
Instance.new("UICorner", SearchCircle).CornerRadius = UDim.new(1, 0)
local circleStroke = Instance.new("UIStroke", SearchCircle)
circleStroke.Color = Color3.fromHex("#A0A0A0")
circleStroke.Thickness = 1 
local SearchHandle = Instance.new("Frame", SearchIcon)
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
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
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
CloseBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
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
div.Size = UDim2.new(1, 0, 0, 1)
div.Position = UDim2.new(0, 0, 0, 52)
div.BackgroundColor3 = Color3.fromHex("#121212")
div.BorderSizePixel = 0
div.ZIndex = 6

local SidebarFrame = Instance.new("Frame", mainFrame)
SidebarFrame.Size = UDim2.new(0, 140, 1, -53)
SidebarFrame.Position = UDim2.new(0, 0, 0, 53)
SidebarFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
SidebarFrame.BorderSizePixel = 0
SidebarFrame.ZIndex = 6
Instance.new("UICorner", SidebarFrame).CornerRadius = UDim.new(0, 9)

local SidebarSeparator = Instance.new("Frame", SidebarFrame)
SidebarSeparator.Size = UDim2.new(0, 1, 1, 0)
SidebarSeparator.Position = UDim2.new(1, 0, 0, 0)
SidebarSeparator.BackgroundColor3 = Color3.fromHex("#121212")
SidebarSeparator.BorderSizePixel = 0
SidebarSeparator.ZIndex = 6

local ProfileDiv = Instance.new("Frame", SidebarFrame)
ProfileDiv.Size = UDim2.new(1, 0, 0, 1)
ProfileDiv.Position = UDim2.new(0, 0, 1, -66)
ProfileDiv.BackgroundColor3 = Color3.fromHex("#121212")
ProfileDiv.BorderSizePixel = 0
ProfileDiv.ZIndex = 6

local TabsContainer = Instance.new("ScrollingFrame", SidebarFrame)
TabsContainer.Size = UDim2.new(1, 0, 1, -75) 
TabsContainer.Position = UDim2.new(0, 0, 0, 5)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ScrollBarThickness = 0
TabsContainer.ZIndex = 7
TabsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
pcall(function() TabsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
local TabsLayout = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabsLayout.Padding = UDim.new(0, 6)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local TabsPadding = Instance.new("UIPadding", TabsContainer)
TabsPadding.PaddingBottom = UDim.new(0, 15)
TabsPadding.PaddingTop = UDim.new(0, 5)

local UserProfileFrame = Instance.new("Frame", SidebarFrame)
UserProfileFrame.Size = UDim2.new(1, -16, 0, 50)
UserProfileFrame.Position = UDim2.new(0, 8, 1, -58)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15) 
UserProfileFrame.ZIndex = 7
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 6)
local ProfileBorder = Instance.new("UIStroke", UserProfileFrame)
ProfileBorder.Color = Color3.fromRGB(24, 24, 24)
ProfileBorder.Thickness = 1

local AvatarImage = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Size = UDim2.new(0, 32, 0, 32)
AvatarImage.Position = UDim2.new(0, 10, 0.5, -16)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex = 8
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

local DisplayNameLabel = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Size = UDim2.new(1, -54, 0, 14)
DisplayNameLabel.Position = UDim2.new(0, 48, 0.5, -14)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
DisplayNameLabel.Font = Enum.Font.GothamBold
DisplayNameLabel.TextSize = 11
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.ZIndex = 8

local UsernameLabel = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Size = UDim2.new(1, -54, 0, 12)
UsernameLabel.Position = UDim2.new(0, 48, 0.5, 0)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text = "@" .. player.Name
UsernameLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
UsernameLabel.Font = Enum.Font.Gotham
UsernameLabel.TextSize = 9
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.ZIndex = 8

local togglesContainer = Instance.new("ScrollingFrame", mainFrame)
togglesContainer.Size = UDim2.new(1, -156, 1, -66)
togglesContainer.Position = UDim2.new(0, 148, 0, 58)
togglesContainer.BackgroundTransparency = 1
togglesContainer.BorderSizePixel = 0
togglesContainer.ScrollBarThickness = 0
togglesContainer.ZIndex = 6
togglesContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
pcall(function() togglesContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
local containerLayout = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
containerLayout.Padding = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local uiPadding = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingBottom = UDim.new(0, 8)

local confirmFrame = Instance.new("Frame", mainFrame)
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
confirmLabel.Text = "Deseja fechar o script?"
confirmLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
confirmLabel.Font = Enum.Font.GothamBold
confirmLabel.TextSize = 14
confirmLabel.ZIndex = 51

local btnYes = Instance.new("TextButton", confirmFrame)
btnYes.Size = UDim2.new(0, 110, 0, 34)
btnYes.Position = UDim2.new(0.5, -115, 0.55, 0)
btnYes.BackgroundColor3 = Color3.fromHex("#8B0000")
btnYes.Text = "Confirmar"
btnYes.TextColor3 = Color3.fromRGB(255, 255, 255)
btnYes.Font = Enum.Font.GothamMedium
btnYes.TextSize = 12
btnYes.ZIndex = 51
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 6)

local btnNo = Instance.new("TextButton", confirmFrame)
btnNo.Size = UDim2.new(0, 110, 0, 34)
btnNo.Position = UDim2.new(0.5, 5, 0.55, 0)
btnNo.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
btnNo.Text = "Cancelar"
btnNo.TextColor3 = Color3.fromRGB(180, 180, 180)
btnNo.Font = Enum.Font.GothamMedium
btnNo.TextSize = 12
btnNo.ZIndex = 51
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 6)


-- ==================== 4. LÓGICAS INTERNAS DE UI ====================

local function RegistrarTransparencias(objeto)
    if originalTrans[objeto] then return end
    if objeto:IsA("Frame") or objeto:IsA("ScrollingFrame") then
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
    local info = TweenInfo.new(duracao, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local function tratarObjeto(obj)
        RegistrarTransparencias(obj)
        local orig = originalTrans[obj]
        if not orig then return end
        if orig.BackgroundTransparency then TweenService:Create(obj, info, {BackgroundTransparency = fadeOut and 1 or orig.BackgroundTransparency}):Play() end
        if orig.TextTransparency then TweenService:Create(obj, info, {TextTransparency = fadeOut and 1 or orig.TextTransparency}):Play() end
        if orig.ImageTransparency then TweenService:Create(obj, info, {ImageTransparency = fadeOut and 1 or (obj.Name == "Shadow3D" and 0.5 or orig.ImageTransparency)}):Play() end
        if orig.Transparency then TweenService:Create(obj, info, {Transparency = fadeOut and 1 or orig.Transparency}):Play() end
    end
    tratarObjeto(raiz)
    for _, desc in ipairs(raiz:GetDescendants()) do tratarObjeto(desc) end
end

local function CriarIconeProcedural(parent, tabName)
    local iconContainer = Instance.new("Frame", parent)
    iconContainer.Name = "Icon"
    iconContainer.Size = UDim2.new(0, 16, 0, 16)
    iconContainer.Position = UDim2.new(0, 12, 0.5, -8)
    iconContainer.BackgroundTransparency = 1
    iconContainer.ZIndex = 9

    local imageLabel = Instance.new("ImageLabel", iconContainer)
    imageLabel.Name = "AccentImage"
    imageLabel.Size = UDim2.new(1, 0, 1, 0)
    imageLabel.BackgroundTransparency = 1
    imageLabel.ZIndex = 10
    imageLabel.ImageColor3 = Color3.fromRGB(180, 180, 180) 

    if tabName == "Movement" then imageLabel.Image = "rbxthumb://type=Asset&id=116118153718196&w=150&h=150"
    elseif tabName == "Teleports" then imageLabel.Image = "rbxthumb://type=Asset&id=131357413318360&w=150&h=150"
    elseif tabName == "Misc" then imageLabel.Image = "rbxthumb://type=Asset&id=96954032676031&w=150&h=150"
    elseif tabName == "Visuals" then imageLabel.Image = "rbxthumb://type=Asset&id=134099134229815&w=150&h=150"
    elseif tabName == "Combat" then imageLabel.Image = "rbxthumb://type=Asset&id=131607049070859&w=150&h=150" end
end

local function RecolorirIcone(iconContainer, targetColor, animSpeed)
    if not iconContainer then return end
    for _, child in ipairs(iconContainer:GetDescendants()) do
        if child.Name == "AccentImage" and child:IsA("ImageLabel") then TweenService:Create(child, animSpeed, {ImageColor3 = targetColor}):Play() end
    end
end

local function AtualizarIdioma()
    local langData = Locales[currentLanguage]
    searchTextBox.PlaceholderText = langData.SearchPlaceholder
    for tabName, btn in pairs(tabButtons) do
        local label = btn:FindFirstChild("Label")
        if label then label.Text = langData.Tabs[tabName] or tabName end
    end
    for _, child in ipairs(togglesContainer:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
            local configKey = child:GetAttribute("ConfigKey")
            if configKey and langData.Options[configKey] then
                local titleLabel = child:FindFirstChild("Title")
                local descLabel = child:FindFirstChild("Description")
                if titleLabel then titleLabel.Text = langData.Options[configKey].Title end
                if descLabel then descLabel.Text = langData.Options[configKey].Desc end
            end
        end
    end
    confirmLabel.Text = langData.ConfirmCloseTitle
    btnYes.Text = langData.ConfirmBtn
    btnNo.Text = langData.CancelBtn
end

local function filterToggles(currentActiveTab, query)
    local searchQuery = (query or ""):lower()
    local itemIndex = 0
    for _, child in ipairs(togglesContainer:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
            local itemTab = child:GetAttribute("Tab") or "Combat"
            local shouldBeVisible = (searchQuery == "") and (itemTab == currentActiveTab) or (child:FindFirstChild("Title") and child:FindFirstChild("Title").Text:lower():find(searchQuery) ~= nil)
            
            child.Visible = shouldBeVisible
            if shouldBeVisible then
                itemIndex = itemIndex + 1
                child.Size = UDim2.new(1, -8, 0, 0)
                child.BackgroundTransparency = 1
                
                local title, desc = child:FindFirstChild("Title"), child:FindFirstChild("Description")
                if title then title.TextTransparency = 1 end
                if desc then desc.TextTransparency = 1 end
                
                task.delay((itemIndex - 1) * 0.03, function()
                    TweenService:Create(child, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Size = UDim2.new(1, -8, 0, 56), BackgroundTransparency = 0 }):Play()
                    if title then TweenService:Create(title, TweenInfo.new(0.2), {TextTransparency = 0}):Play() end
                    if desc then TweenService:Create(desc, TweenInfo.new(0.2), {TextTransparency = 0}):Play() end
                end)
            end
        end
    end
end

local function selectTab(tabName)
    activeTab = tabName
    local animSpeed = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for name, btn in pairs(tabButtons) do
        local label = btn:FindFirstChild("Label")
        local iconContainer = btn:FindFirstChild("Icon")
        if name == tabName then
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromHex("#8B0000")}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end
            RecolorirIcone(iconContainer, Color3.fromRGB(255, 255, 255), animSpeed)
        else
            TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(15, 15, 15)}):Play()
            if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(180, 180, 180)}):Play() end
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
    tabBtn.Size = UDim2.new(1, -16, 0, 32)
    tabBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    tabBtn.Text = "" 
    tabBtn.AutoButtonColor = false
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 5)
    CriarIconeProcedural(tabBtn, tabName)
    
    local tabLabel = Instance.new("TextLabel", tabBtn)
    tabLabel.Name = "Label"
    tabLabel.Size = UDim2.new(1, -44, 1, 0)
    tabLabel.Position = UDim2.new(0, 36, 0, 0)
    tabLabel.BackgroundTransparency = 1
    tabLabel.Text = Locales[currentLanguage].Tabs[tabName] or tabName
    tabLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    tabLabel.Font = Enum.Font.GothamMedium
    tabLabel.TextSize = 11
    tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    tabBtn.MouseButton1Down:Connect(function() TweenService:Create(tabBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, -24, 0, 30)}):Play() end)
    local function restaurarTamanho() TweenService:Create(tabBtn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(1, -16, 0, 32)}):Play() end
    tabBtn.MouseButton1Up:Connect(restaurarTamanho)
    
    tabBtn.MouseLeave:Connect(function()
        restaurarTamanho()
        if activeTab ~= tabName then
            TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(15, 15, 15)}):Play()
            TweenService:Create(tabLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {TextColor3 = Color3.fromRGB(180, 180, 180)}):Play()
            RecolorirIcone(tabBtn:FindFirstChild("Icon"), Color3.fromRGB(180, 180, 180), TweenInfo.new(0.15, Enum.EasingStyle.Quad))
        end
    end)
    
    tabBtn.MouseEnter:Connect(function()
        if activeTab ~= tabName then
            TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(22, 22, 22)}):Play()
            TweenService:Create(tabLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {TextColor3 = Color3.fromRGB(220, 220, 220)}):Play()
            RecolorirIcone(tabBtn:FindFirstChild("Icon"), Color3.fromRGB(220, 220, 220), TweenInfo.new(0.15, Enum.EasingStyle.Quad))
        end
    end)
    tabBtn.MouseButton1Click:Connect(function() selectTab(tabName) end)
    tabButtons[tabName] = tabBtn
end

local ConfigCallbacks = {
    SafeSpot = function(enabled)
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if enabled then
            lastPositionBeforeSafeSpot = root.CFrame
            if not safePlatform then
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
            if safePlatform then safePlatform:Destroy() safePlatform = nil end
            if lastPositionBeforeSafeSpot then root.CFrame = lastPositionBeforeSafeSpot lastPositionBeforeSafeSpot = nil end
        end
    end,
    AutoCollect = function(enabled) if not enabled then currentCollectTarget = nil end end
}

local function createToggle(parent, configKey, tabCategory)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(1, -8, 0, 56) 
    toggleFrame.BackgroundColor3 = Color3.fromHex("#0F0F0F")
    toggleFrame:SetAttribute("Tab", tabCategory)
    toggleFrame:SetAttribute("ConfigKey", configKey)
    toggleFrame.Parent = parent
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", toggleFrame)
    stroke.Color = Color3.fromHex("#141414")
    
    local titleLabel = Instance.new("TextLabel", toggleFrame)
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(0.65, 0, 0, 16)
    titleLabel.Position = UDim2.new(0, 12, 0, 6) 
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromHex("#CCCCCC")
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
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
    
    local switchTrack = Instance.new("Frame", toggleFrame)
    switchTrack.Size = UDim2.new(0, 40, 0, 20)
    switchTrack.Position = UDim2.new(1, -52, 0.5, -10)
    switchTrack.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
    Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)
    
    local trackStroke = Instance.new("UIStroke", switchTrack)
    trackStroke.Color = Color3.fromRGB(45, 45, 45)
    
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
        local targetPos = Configs[configKey] and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        local targetColor = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
        
        local toggleAnim = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(switchCircle, toggleAnim, {Position = targetPos}):Play()
        TweenService:Create(switchTrack, toggleAnim, {BackgroundColor3 = targetColor}):Play()
        if ConfigCallbacks[configKey] then task.spawn(ConfigCallbacks[configKey], Configs[configKey]) end
    end)
end

-- ==================== 5. PROCEDIMENTOS & COMANDOS ====================
local function LimparEDesligarAbsolutamente()
    if hbConnection then hbConnection:Disconnect() hbConnection = nil end
    if renderConnection then renderConnection:Disconnect() renderConnection = nil end
    for k in pairs(Configs) do Configs[k] = false end
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local hl = p.Character:FindFirstChild("AkatESP_MM2")
            if hl then pcall(function() hl:Destroy() end) end
        end
    end
    if safePlatform then pcall(function() safePlatform:Destroy() end) safePlatform = nil end
    
    pcall(function()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16; hum.PlatformStand = false end
        if char then
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Tool") and item:FindFirstChild("Handle") then
                    local rPart = item.Handle:FindFirstChild("AkatReachPart")
                    if rPart then rPart:Destroy() end
                end
            end
        end
    end)
end

local function AlternarConfirmacao(exibir)
    isConfirmOpen = exibir
    local tempoAnim = 0.15 
    if exibir then
        if not confirmBlur then confirmBlur = Instance.new("BlurEffect", Lighting) confirmBlur.Size = 0 end
        confirmFrame.Visible = true
        AplicarFadeSincronizado(confirmFrame, true, 0)
        AplicarFadeSincronizado(confirmFrame, false, tempoAnim)
        TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 14}):Play()
    else
        AplicarFadeSincronizado(confirmFrame, true, tempoAnim)
        if confirmBlur then TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play() end
        if wasMinimizedBeforeConfirm then
            AplicarFadeSincronizado(SidebarFrame, true, 0.15)
            AplicarFadeSincronizado(togglesContainer, true, 0.15)
            isMinimized = true
            TweenService:Create(mainWrapper, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.new(0, 520, 0, 52)}):Play()
            task.delay(0.15, function() if isMinimized then togglesContainer.Visible = false SidebarFrame.Visible = false div.Visible = false end end)
        end
        task.delay(tempoAnim, function() if not isConfirmOpen then confirmFrame.Visible = false if confirmBlur then confirmBlur:Destroy() confirmBlur = nil end end end)
    end
end

local function ConfigurarArrastarAkat(inst)
    local drag, startPos, dragStart, dragInput = false
    inst.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            drag = true
            dragStart = input.Position
            startPos = inst.Position
            dragInput = input
            local connection
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then drag = false connection:Disconnect() end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if drag and input == dragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            inst.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

createTabBtn("Combat") createTabBtn("Visuals") createTabBtn("Movement") createTabBtn("Teleports") createTabBtn("Misc")
createToggle(togglesContainer, "AutoShoot", "Combat") createToggle(togglesContainer, "Reach", "Combat")
createToggle(togglesContainer, "ESP", "Visuals")
createToggle(togglesContainer, "Speed", "Movement") createToggle(togglesContainer, "AntiFling", "Movement")
createToggle(togglesContainer, "TpToGun", "Teleports") createToggle(togglesContainer, "SafeSpot", "Teleports")
createToggle(togglesContainer, "AutoCollect", "Misc") createToggle(togglesContainer, "ChatRoles", "Misc")

SearchBtn.MouseButton1Click:Connect(function()
    local searchAnimInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if searchBarFrame.Size.X.Offset == 0 then
        TweenService:Create(searchBarFrame, searchAnimInfo, {Size = UDim2.new(0, 160, 0, 26)}):Play()
        searchTextBox:CaptureFocus()
    else
        searchTextBox.Text = ""
        TweenService:Create(searchBarFrame, searchAnimInfo, {Size = UDim2.new(0, 0, 0, 26)}):Play()
        searchTextBox:ReleaseFocus()
        filterToggles(activeTab, "")
    end
end)

searchTextBox:GetPropertyChangedSignal("Text"):Connect(function() filterToggles(activeTab, searchTextBox.Text) end)

LanguageBtn.MouseButton1Click:Connect(function()
    if currentLanguage == "EN" then currentLanguage = "PT" elseif currentLanguage == "PT" then currentLanguage = "ES" else currentLanguage = "EN" end
    LanguageBtn.Text = currentLanguage
    AtualizarIdioma()
end)

CloseBtn.MouseButton1Click:Connect(function() AlternarConfirmacao(true) end)
btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)
btnYes.MouseButton1Click:Connect(function() LimparEDesligarAbsolutamente() screenGui:Destroy() end)
MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    local windowAnim = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if isMinimized then
        AplicarFadeSincronizado(SidebarFrame, true, 0.1) AplicarFadeSincronizado(togglesContainer, true, 0.1)
        TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 520, 0, 52)}):Play()
        task.delay(0.1, function() if isMinimized then togglesContainer.Visible = false SidebarFrame.Visible = false div.Visible = false end end)
    else
        div.Visible = true SidebarFrame.Visible = true togglesContainer.Visible = true
        AplicarFadeSincronizado(SidebarFrame, false, 0.16) AplicarFadeSincronizado(togglesContainer, false, 0.16)
        TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 520, 0, 300)}):Play()
    end
end)

FloatBtn.MouseButton1Click:Connect(function()
    TweenService:Create(FloatBtn, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(0, 38, 0, 38)}):Play()
    task.wait(0.1)
    TweenService:Create(FloatBtn, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = UDim2.new(0, 44, 0, 44)}):Play()
    mainWrapper.Visible = not mainWrapper.Visible
end)
ConfigurarArrastarAkat(mainWrapper) ConfigurarArrastarAkat(FloatBtn)

-- ==================== 6. ROTINAS E SISTEMAS PRINCIPAIS (MM2 2026) ====================

local function EnviarMensagemChat(msg)
    local TextChatService = game:GetService("TextChatService")
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            TextChatService.TextChannels:FindFirstChild("RBXGeneral"):SendAsync(msg)
        else
            game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All")
        end
    end)
end

-- Lógica Dinâmica de Papéis
local function UpdateRoles()
    if not IsRoundActive() then
        for _, p in ipairs(Players:GetPlayers()) do PlayerRolesCache[p] = "Innocent" end
        OriginalSheriff = nil
        CurrentMurderer = nil
        return
    end

    for _, p in ipairs(Players:GetPlayers()) do
        local hasKnife, hasGun = false, false
        local function checkTools(folder)
            if not folder then return end
            for _, item in ipairs(folder:GetChildren()) do
                if item:IsA("Tool") then
                    local name = item.Name:lower()
                    if name:find("knife") or name == "awp" or name == "pitchfork" or name == "scythe" or item:FindFirstChild("KnifeServer") then hasKnife = true
                    elseif name:find("gun") or name == "luger" or name == "blaster" or name == "laser" or name:find("revolver") or item:FindFirstChild("GunScript") then hasGun = true end
                end
            end
        end
        
        checkTools(p.Character)
        checkTools(p:FindFirstChild("Backpack"))
        
        if hasKnife then
            PlayerRolesCache[p] = "Murderer"
            CurrentMurderer = p
        elseif hasGun then
            if PlayerRolesCache[p] ~= "Sheriff" and PlayerRolesCache[p] ~= "Hero" then
                if OriginalSheriff == nil or OriginalSheriff == p then
                    OriginalSheriff = p
                    PlayerRolesCache[p] = "Sheriff"
                else
                    PlayerRolesCache[p] = "Hero"
                end
            end
        else
            -- Pre-revelação
            if PlayerRolesCache[p] == "Innocent" or PlayerRolesCache[p] == nil then
                local roleAttr = p:GetAttribute("Role") or p:GetAttribute("role") or p:GetAttribute("Funcao")
                if roleAttr then
                    local roleStr = string.lower(tostring(roleAttr))
                    if roleStr:find("murder") or roleStr:find("assassin") then PlayerRolesCache[p] = "Murderer"; CurrentMurderer = p
                    elseif roleStr:find("sheriff") or roleStr:find("xerife") then PlayerRolesCache[p] = "Sheriff"; if not OriginalSheriff then OriginalSheriff = p end
                    elseif roleStr:find("hero") then PlayerRolesCache[p] = "Hero" end
                end
            end
        end
        if PlayerRolesCache[p] == nil then PlayerRolesCache[p] = "Innocent" end
    end
end

-- Novo Sistema de ESP Refatorado
local function UpdateESP()
    if not Configs.ESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and p.Character:FindFirstChild("AkatESP_MM2") then p.Character.AkatESP_MM2:Destroy() end
        end
        return
    end
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hum = p.Character:FindFirstChild("Humanoid")
            local isAlive = hum and hum.Health > 0
            local hl = p.Character:FindFirstChild("AkatESP_MM2")
            
            if isAlive and IsRoundActive() then
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "AkatESP_MM2"
                    hl.FillTransparency = 0.5
                    hl.OutlineTransparency = 0.1
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = p.Character
                end
                
                local role = PlayerRolesCache[p] or "Innocent"
                if role == "Murderer" then hl.FillColor = Color3.fromRGB(255, 0, 0); hl.OutlineColor = Color3.fromRGB(255, 0, 0)
                elseif role == "Sheriff" then hl.FillColor = Color3.fromRGB(0, 0, 255); hl.OutlineColor = Color3.fromRGB(0, 0, 255)
                elseif role == "Hero" then hl.FillColor = Color3.fromRGB(255, 255, 0); hl.OutlineColor = Color3.fromRGB(255, 255, 0)
                else hl.FillColor = Color3.fromRGB(0, 255, 0); hl.OutlineColor = Color3.fromRGB(0, 255, 0) end
            else
                if hl then hl:Destroy() end
            end
        end
    end
end

-- Lógica Central do AutoShoot
local function AutoShootLoop()
    if not Configs.AutoShoot then return end
    local char = player.Character
    if not char then return end
    
    local gunTool = nil
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") and (child.Name:lower():find("gun") or child.Name:lower():find("sheriff") or child.Name:lower():find("revolver") or child:FindFirstChild("GunScript")) then
            gunTool = child
            break
        end
    end
    
    if gunTool then
        local murderer = GetLiveMurderer()
        if murderer and murderer.Character then
            local head = murderer.Character:FindFirstChild("Head")
            local myRoot = char:FindFirstChild("HumanoidRootPart")
            local murderHum = murderer.Character:FindFirstChild("Humanoid")
            
            if head and myRoot and murderHum and murderHum.Health > 0 then
                -- Opcional: Manter personagem focado pra evitar raycast blocks
                local targetPos = Vector3.new(head.Position.X, myRoot.Position.Y, head.Position.Z)
                myRoot.CFrame = CFrame.new(myRoot.Position, targetPos)
                
                local now = os.clock()
                if now - lastShootTime > 0.1 then
                    lastShootTime = now
                    pcall(function() gunTool:Activate() end)
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        UpdateRoles()
        
        local currentSheriffOrHero = nil
        for p, r in pairs(PlayerRolesCache) do
            if r == "Sheriff" or r == "Hero" then currentSheriffOrHero = p break end
        end
        
        if not IsRoundActive() then
            announcedThisRound = false
        elseif Configs.ChatRoles and (CurrentMurderer or currentSheriffOrHero) and not announcedThisRound then
            announcedThisRound = true
            local msg = "[AKAT] "
            if CurrentMurderer then msg = msg .. "Murderer: " .. CurrentMurderer.DisplayName .. " " end
            if currentSheriffOrHero then msg = msg .. "| Sheriff/Hero: " .. currentSheriffOrHero.DisplayName end
            EnviarMensagemChat(msg)
        end
        task.wait(0.2)
    end
end)

renderConnection = RunService.RenderStepped:Connect(AutoShootLoop)

hbConnection = RunService.Heartbeat:Connect(function(dt)
    UpdateESP()

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    -- AntiFling
    if Configs.AntiFling then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                for _, part in ipairs(p.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                        pcall(function() part.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
                    end
                end
            end
        end
    end

    -- TpToGun
    if Configs.TpToGun and root then
        local myRole = PlayerRolesCache[player] or "Innocent"
        if myRole ~= "Murderer" and not (player.Backpack:FindFirstChild("Gun") or (char and char:FindFirstChild("Gun"))) then
            local gunDrop = workspace:FindFirstChild("GunDrop", true)
            if gunDrop and not hasTeleportedToGun then
                local tPart = gunDrop:IsA("BasePart") and gunDrop or gunDrop:FindFirstChildOfClass("BasePart")
                if tPart and (root.Position - tPart.Position).Magnitude < 1500 then
                    hasTeleportedToGun = true
                    originalPositionBeforeGun = root.CFrame
                    root.CFrame = tPart.CFrame * CFrame.new(0, 1.2, 0)
                    task.spawn(function()
                        task.wait(0.35) 
                        if originalPositionBeforeGun and Configs.TpToGun then root.CFrame = originalPositionBeforeGun end
                        task.wait(1.5) hasTeleportedToGun = false
                    end)
                end
            end
        end
    end

    -- Funções Estéticas (Reach, Speed)
    if char and root and hum then
        local velocidadeAlvo = Configs.Speed and 23 or 16
        if hum.WalkSpeed ~= velocidadeAlvo then hum.WalkSpeed = velocidadeAlvo end

        local knife = char:FindFirstChild("Knife")
        if knife and knife:IsA("Tool") then
            local handle = knife:FindFirstChild("Handle")
            if handle then
                local reachPart = handle:FindFirstChild("AkatReachPart")
                if Configs.Reach then
                    if not reachPart then
                        reachPart = Instance.new("Part", handle)
                        reachPart.Name = "AkatReachPart"
                        reachPart.Size = Vector3.new(25, 25, 25)
                        reachPart.Transparency = 1
                        reachPart.CanCollide = false
                        reachPart.Massless = true
                        local weld = Instance.new("WeldConstraint", reachPart)
                        weld.Part0 = handle; weld.Part1 = reachPart
                    end
                    if firetouchinterest then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                if (root.Position - p.Character.HumanoidRootPart.Position).Magnitude <= 25 then
                                    firetouchinterest(handle, p.Character.HumanoidRootPart, 0)
                                    firetouchinterest(handle, p.Character.HumanoidRootPart, 1)
                                end
                            end
                        end
                    end
                elseif reachPart then reachPart:Destroy() end
            end
        end
    end
end)

-- Iniciar Interface
task.spawn(function()
    mainWrapper.Visible = true
    FloatBtn.Visible = true
    AplicarFadeSincronizado(mainWrapper, true, 0)
    local openTween = TweenService:Create(mainWrapper, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 520, 0, 300)})
    AplicarFadeSincronizado(mainWrapper, false, 0.3)
    openTween:Play()
    openTween.Completed:Connect(function() selectTab("Combat") end)
end)
