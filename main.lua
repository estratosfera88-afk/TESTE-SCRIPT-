-- [[
--     AKAT MM2 SCRIPT [BETA v2.2] - PERFORMANCE & UI OVERHAUL
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==================== 1. CONFIGURAÇÕES E LOCALES ESTÁTICOS ====================
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
            AutoShoot = {
                Title = "Atirar no Murder",
                Desc = "Mira e dispara a arma automaticamente no Assassino ao equipá-la."
            },
            Reach = {
                Title = "Alcance da Faca",
                Desc = "Aumenta consideravelmente o alcance de ataque com a sua faca."
            },
            ESP = {
                Title = "ESP Jogadores",
                Desc = "Destaca na parede os jogadores de acordo com suas funções."
            },
            Speed = {
                Title = "Velocidade",
                Desc = "Aumenta levemente a velocidade do personagem para 23."
            },
            AntiFling = {
                Title = "Anti-Arremesso",
                Desc = "Bloqueia colisões que tentem te empurrar ou arremessar."
            },
            TpToGun = {
                Title = "Teleportar p/ Arma",
                Desc = "Teletransporta para a arma dropada e retorna ao local original rapidamente."
            },
            SafeSpot = {
                Title = "Lugar Seguro",
                Desc = "Cria uma plataforma invisível no céu para ficar totalmente seguro."
            },
            AutoCollect = {
                Title = "Coletar Moedas",
                Desc = "Voa atravessando tudo rapidamente e espera coletar cada moeda antes de ir para a próxima."
            },
            ChatRoles = {
                Title = "Revelar Funções",
                Desc = "Envia de forma limpa no chat quem é o Assassino e o Xerife."
            }
        },
        Intro = '<font color="#FFFFFF">Scripts por | </font><font color="#8B0000">Comunidade AKAT</font>'
    },
    EN = {
        SearchPlaceholder = "Search...",
        ConfirmCloseTitle = "Do you want to close the script?",
        ConfirmBtn = "Confirm",
        CancelBtn = "Cancel",
        Tabs = {
            Combat = "Combat",
            Visuals = "Visuals",
            Movement = "Movement",
            Teleports = "Teleports",
            Misc = "Misc"
        },
        Options = {
            AutoShoot = {
                Title = "Shoot Murderer",
                Desc = "Automatically aims and fires the gun at the Murderer when held."
            },
            Reach = {
                Title = "Knife Reach",
                Desc = "Significantly increases your knife attack reach."
            },
            ESP = {
                Title = "Player ESP",
                Desc = "Highlights players through walls based on their active roles."
            },
            Speed = {
                Title = "WalkSpeed",
                Desc = "Slightly increases player walkspeed up to 23."
            },
            AntiFling = {
                Title = "Anti-Fling",
                Desc = "Disables collisions to prevent other players from flinging you."
            },
            TpToGun = {
                Title = "TP to Gun",
                Desc = "Teleports to the dropped gun and instantly returns to your spot."
            },
            SafeSpot = {
                Title = "Safe Spot",
                Desc = "Teleports you to an invisible sky platform to remain completely safe."
            },
            AutoCollect = {
                Title = "Auto Collect",
                Desc = "Flies through walls very fast, waiting for each coin to be collected before moving to the next."
            },
            ChatRoles = {
                Title = "Reveal Roles",
                Desc = "Automatically sends a message in public chat revealing active roles."
            }
        },
        Intro = '<font color="#FFFFFF">Scripts by | </font><font color="#8B0000">AKAT Community</font>'
    },
    ES = {
        SearchPlaceholder = "Buscar...",
        ConfirmCloseTitle = "¿Deseas cerrar el script?",
        ConfirmBtn = "Confirmar",
        CancelBtn = "Cancelar",
        Tabs = {
            Combat = "Combate",
            Visuales = "Visuales",
            Movement = "Movimiento",
            Teleports = "Teleportes",
            Misc = "Varios"
        },
        Options = {
            AutoShoot = {
                Title = "Disparar al Asesino",
                Desc = "Apunta y dispara la pistola automáticamente al Asesino al equiparla."
            },
            Reach = {
                Title = "Alcance del Cuchillo",
                Desc = "Aumenta considerablemente el alcance de ataque con tu cuchillo."
            },
            ESP = {
                Title = "ESP Jogadores",
                Desc = "Resalta a los jugadores a través de las paredes según sus roles."
            },
            Speed = {
                Title = "Velocidad",
                Desc = "Aumenta ligeramente la velocidad del personagem a 23."
            },
            AntiFling = {
                Title = "Anti-Fling",
                Desc = "Bloqueia colisiones para evitar que te empujen o lancen."
            },
            TpToGun = {
                Title = "TP a la Arma",
                Desc = "Teletransporta a la pistola tirada y regresa a tu lugar velozmente."
            },
            SafeSpot = {
                Title = "Lugar Seguro",
                Desc = "Te teletransporta a una plataforma invisible en el cielo para estar a salvo."
            },
            AutoCollect = {
                Title = "Auto Monedas",
                Desc = "Vuela atravesando todo rápidamente y espera a recolectar cada moneda antes de ir a la siguiente."
            },
            ChatRoles = {
                Title = "Revelar Roles",
                Desc = "Envía automáticamente en el chat quién es el Asesino y el Sheriff."
            }
        },
        Intro = '<font color="#FFFFFF">Scripts por | </font><font color="#8B0000">Comunidad AKAT</font>'
    }
}

-- ==================== 2. VARIÁVEIS DE ESTADO GLOBAIS ====================
local currentLanguage = "EN"
local activeTab = "Combat"
local tabButtons = {} 
local menuAberto = true
local isMinimized = false
local hbConnection = nil 
local renderConnection = nil
local PlayerRoles = {}
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

-- ==================== 3. CRIAÇÃO DE TODA A ESTRUTURA DE INTERFACE (UI) ====================
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

-- Botão Flutuante (AKAT)
local FloatBtn = Instance.new("ImageButton", screenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5) 
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0.05, 22, 0.5, 0)
FloatBtn.Image = "rbxthumb://type=Asset&id=74407434556912&w=420&h=420"
FloatBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
FloatBtn.Visible = false 
FloatBtn.ZIndex = 30

local floatCorner = Instance.new("UICorner", FloatBtn)
floatCorner.CornerRadius = UDim.new(0, 8) 
local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Color = Color3.fromHex("#8B0000")
FloatStroke.Thickness = 1

-- Wrapper Principal
local mainWrapper = Instance.new("Frame")
mainWrapper.Name = "MainWrapper"
mainWrapper.AnchorPoint = Vector2.new(0.5, 0)
mainWrapper.Size = UDim2.new(0, 520, 0, 300)
mainWrapper.Position = UDim2.new(0.5, 0, 0.5, -150)
mainWrapper.BackgroundTransparency = 1
mainWrapper.ClipsDescendants = false
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

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundColor3 = Color3.fromHex("#0A0A0A")
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true 
mainFrame.ZIndex = 5
local mainCorner = Instance.new("UICorner", mainFrame)
mainCorner.CornerRadius = UDim.new(0, 9)

local frameStroke = Instance.new("UIStroke", mainFrame)
frameStroke.Color = Color3.fromHex("#161616")
frameStroke.Thickness = 1
mainFrame.Parent = mainWrapper

-- TopBar
local topBar = Instance.new("Frame", mainFrame)
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 52)
topBar.BackgroundTransparency = 1
topBar.ZIndex = 6

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
subtitle.Text = "MM2 SCRIPT [BETA]"
subtitle.TextColor3 = Color3.fromHex("#555555")
subtitle.TextSize = 10
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 6

-- Barra de Pesquisa Animada
local searchBarFrame = Instance.new("Frame", topBar)
searchBarFrame.Name = "SearchBarFrame"
searchBarFrame.AnchorPoint = Vector2.new(1, 0.5)
searchBarFrame.Position = UDim2.new(1, -154, 0.5, 0)
searchBarFrame.Size = UDim2.new(0, 0, 0, 26) 
searchBarFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
searchBarFrame.ClipsDescendants = true
searchBarFrame.ZIndex = 7

local searchCorner = Instance.new("UICorner", searchBarFrame)
searchCorner.CornerRadius = UDim.new(0, 13) 
local searchStroke = Instance.new("UIStroke", searchBarFrame)
searchStroke.Color = Color3.fromHex("#1F1F1F")
searchStroke.Thickness = 1

local searchTextBox = Instance.new("TextBox", searchBarFrame)
searchTextBox.Name = "SearchTextBox"
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

-- Alinhamento de Todos os Botões Superiores
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

-- Botão de Idioma
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

-- Botão da Lupa de Pesquisa
local SearchBtn = Instance.new("TextButton", topButtons)
SearchBtn.Name = "SearchBtn"
SearchBtn.LayoutOrder = 1
SearchBtn.Size = UDim2.new(0, 26, 0, 26)
SearchBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
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

-- Botão de Minimizar
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

-- Botão de Fechar
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

-- Divisor Horizontal
local div = Instance.new("Frame", mainFrame)
div.Size = UDim2.new(1, 0, 0, 1)
div.Position = UDim2.new(0, 0, 0, 52)
div.BackgroundColor3 = Color3.fromHex("#121212")
div.BorderSizePixel = 0
div.ZIndex = 6

-- Painel Lateral (Sidebar)
local SidebarFrame = Instance.new("Frame", mainFrame)
SidebarFrame.Name = "SidebarFrame"
SidebarFrame.Size = UDim2.new(0, 140, 1, -53)
SidebarFrame.Position = UDim2.new(0, 0, 0, 53)
SidebarFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
SidebarFrame.BorderSizePixel = 0
SidebarFrame.ZIndex = 6

local SidebarCorner = Instance.new("UICorner", SidebarFrame)
SidebarCorner.CornerRadius = UDim.new(0, 9)

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
TabsContainer.Name = "TabsContainer"
TabsContainer.Size = UDim2.new(1, 0, 1, -75) 
TabsContainer.Position = UDim2.new(0, 0, 0, 5)
TabsContainer.BackgroundTransparency = 1
TabsContainer.BorderSizePixel = 0
TabsContainer.ScrollBarThickness = 0
TabsContainer.ZIndex = 7
TabsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
TabsContainer.ElasticBehavior = Enum.ElasticBehavior.Never
pcall(function() TabsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y end)

local TabsLayout = Instance.new("UIListLayout", TabsContainer)
TabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabsLayout.Padding = UDim.new(0, 6)
TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local TabsPadding = Instance.new("UIPadding", TabsContainer)
TabsPadding.PaddingBottom = UDim.new(0, 15)
TabsPadding.PaddingTop = UDim.new(0, 5)

-- Perfil de Usuário
local UserProfileFrame = Instance.new("Frame", SidebarFrame)
UserProfileFrame.Name = "UserProfileFrame"
UserProfileFrame.Size = UDim2.new(1, -16, 0, 50)
UserProfileFrame.Position = UDim2.new(0, 8, 1, -58)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15) 
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex = 7

local ProfileCorner = Instance.new("UICorner", UserProfileFrame)
ProfileCorner.CornerRadius = UDim.new(0, 6)
local ProfileBorder = Instance.new("UIStroke", UserProfileFrame)
ProfileBorder.Color = Color3.fromRGB(24, 24, 24)
ProfileBorder.Thickness = 1

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

-- Container Principal de Toggles
local togglesContainer = Instance.new("ScrollingFrame", mainFrame)
togglesContainer.Name = "TogglesContainer"
togglesContainer.Size = UDim2.new(1, -156, 1, -66)
togglesContainer.Position = UDim2.new(0, 148, 0, 58)
togglesContainer.BackgroundTransparency = 1
togglesContainer.BorderSizePixel = 0
togglesContainer.ScrollBarThickness = 0
togglesContainer.ZIndex = 6
togglesContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
togglesContainer.ElasticBehavior = Enum.ElasticBehavior.Never
pcall(function() togglesContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y end)

local containerLayout = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
containerLayout.Padding = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local uiPadding = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingBottom = UDim.new(0, 8)

-- Painel de Confirmação para Fechar
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


-- ==================== 4. FUNÇÕES DE SUPORTE E DE EXECUÇÃO ====================

local function IsInMatch()
    local normal = workspace:FindFirstChild("Normal")
    local map = workspace:FindFirstChild("Map")
    return (normal ~= nil or map ~= nil)
end

local function DetectarRoleReal(p)
    if not p or not p.Parent then return "Survivor" end
    local char = p.Character
    local backpack = p:FindFirstChild("Backpack")
    
    local function checarPasta(pasta)
        if not pasta then return nil end
        if pasta:FindFirstChild("Knife") then return "Murderer" end
        if pasta:FindFirstChild("Gun") or pasta:FindFirstChild("Sheriff") then return "Sheriff" end
        for _, item in ipairs(pasta:GetChildren()) do
            if item:IsA("Tool") then
                local nome = item.Name:lower()
                if nome:find("knife") or nome:find("faca") or nome:find("sword") or nome:find("cutelo") then
                    return "Murderer"
                elseif nome:find("gun") or nome:find("pistol") or nome:find("revolver") or nome:find("sheriff") or nome:find("arma") then
                    return "Sheriff"
                end
            end
        end
        return nil
    end
    
    local roleChar = checarPasta(char)
    if roleChar then return roleChar end
    local roleBP = checarPasta(backpack)
    if roleBP then return roleBP end
    
    local nativeRole = p:GetAttribute("Role") or p:GetAttribute("role") or p:GetAttribute("Funcao")
    local roleStr = nativeRole and string.lower(tostring(nativeRole)) or ""
    if string.find(roleStr, "murder") or string.find(roleStr, "assassino") then return "Murderer" end
    if string.find(roleStr, "sheriff") or string.find(roleStr, "xerife") or string.find(roleStr, "hero") then return "Sheriff" end
    return "Survivor"
end

local function ObterMurderer()
    local closestMurderer = nil
    local closestDistance = math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local targetHum = p.Character:FindFirstChildOfClass("Humanoid")
            if targetHum and targetHum.Health > 0 and (PlayerRoles[p] == "Murderer") then
                local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if playerRoot then
                    local dist = (playerRoot.Position - p.Character.HumanoidRootPart.Position).Magnitude
                    if dist < closestDistance then
                        closestDistance = dist
                        closestMurderer = p
                    end
                end
            end
        end
    end
    return closestMurderer, closestDistance
end

local function RegistrarTransparencias(objeto)
    if originalTrans[objeto] then return end
    if objeto:IsA("Frame") or objeto:IsA("ScrollingFrame") then
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
    local info = TweenInfo.new(duracao, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local function tratarObjeto(obj)
        RegistrarTransparencias(obj)
        local orig = originalTrans[obj]
        if not orig then return end
        
        if orig.BackgroundTransparency then
            local target = fadeOut and 1 or orig.BackgroundTransparency
            if duracao == 0 then obj.BackgroundTransparency = target else TweenService:Create(obj, info, {BackgroundTransparency = target}):Play() end
        end
        if orig.TextTransparency then
            local target = fadeOut and 1 or orig.TextTransparency
            if duracao == 0 then obj.TextTransparency = target else TweenService:Create(obj, info, {TextTransparency = target}):Play() end
        end
        if orig.TextStrokeTransparency then
            local target = fadeOut and 1 or orig.TextStrokeTransparency
            if duracao == 0 then obj.TextStrokeTransparency = target else TweenService:Create(obj, info, {TextStrokeTransparency = target}):Play() end
        end
        if orig.ImageTransparency then
            local target = fadeOut and 1 or (obj.Name == "Shadow3D" and 0.5 or orig.ImageTransparency)
            if duracao == 0 then obj.ImageTransparency = target else TweenService:Create(obj, info, {ImageTransparency = target}):Play() end
        end
        if orig.Transparency then
            local target = fadeOut and 1 or orig.Transparency
            if duracao == 0 then obj.Transparency = target else TweenService:Create(obj, info, {Transparency = target}):Play() end
        end
    end
    tratarObjeto(raiz)
    for _, desc in ipairs(raiz:GetDescendants()) do tratarObjeto(desc) end
end

local function AplicarFadeTextos(raiz, fadeOut, duracao)
    local info = TweenInfo.new(duracao, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local function tratarObjeto(obj)
        RegistrarTransparencias(obj)
        local orig = originalTrans[obj]
        if not orig then return end
        if orig.TextTransparency then
            local target = fadeOut and 1 or orig.TextTransparency
            if duracao == 0 then obj.TextTransparency = target else TweenService:Create(obj, info, {TextTransparency = target}):Play() end
        end
        if orig.TextStrokeTransparency then
            local target = fadeOut and 1 or orig.TextStrokeTransparency
            if duracao == 0 then obj.TextStrokeTransparency = target else TweenService:Create(obj, info, {TextStrokeTransparency = target}):Play() end
        end
    end
    tratarObjeto(raiz)
    for _, desc in ipairs(raiz:GetDescendants()) do tratarObjeto(desc) end
end

-- CARREGAMENTO DE ÍCONES PERSONALIZADOS VIA ASSET ID
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
    imageLabel.ImageColor3 = Color3.fromRGB(180, 180, 180) -- Cor padrão inativa

    if tabName == "Movement" then
        imageLabel.Image = "rbxassetid://90358690675463"
    elseif tabName == "Teleports" then
        imageLabel.Image = "rbxassetid://90358690675463"
    elseif tabName == "Misc" then
        imageLabel.Image = "rbxassetid://110656497311677"
    elseif tabName == "Visuals" then
        imageLabel.Image = "rbxassetid://98051686611454"
    elseif tabName == "Combat" then
        imageLabel.Image = "rbxassetid://133188606257719"
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

local function AtualizarIdioma()
    local langData = Locales[currentLanguage]
    if not langData then return end
    
    -- TÍTULO E SUBTÍTULO BLOQUEADOS PARA NÃO SE ALTERAREM
    searchTextBox.PlaceholderText = langData.SearchPlaceholder
    
    for tabName, btn in pairs(tabButtons) do
        local label = btn:FindFirstChild("Label")
        if label then
            label.Text = langData.Tabs[tabName] or tabName
        end
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
            local shouldBeVisible = false
            
            if searchQuery ~= "" then
                local titleLabel = child:FindFirstChild("Title")
                shouldBeVisible = titleLabel and titleLabel.Text:lower():find(searchQuery) ~= nil
            else
                shouldBeVisible = (itemTab == currentActiveTab)
            end
            
            child.Visible = shouldBeVisible
            
            if shouldBeVisible then
                itemIndex = itemIndex + 1
                child.Size = UDim2.new(1, -8, 0, 0)
                child.BackgroundTransparency = 1
                
                local title = child:FindFirstChild("Title")
                local desc = child:FindFirstChild("Description")
                if title then title.TextTransparency = 1 end
                if desc then desc.TextTransparency = 1 end
                
                task.delay((itemIndex - 1) * 0.03, function()
                    -- Altura dos containers redefinida para 56 para evitar cortar descrições
                    TweenService:Create(child, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, -8, 0, 56),
                        BackgroundTransparency = 0
                    }):Play()
                    
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
    tabBtn.ZIndex = 8
    tabBtn.AutoButtonColor = false
    
    local corner = Instance.new("UICorner", tabBtn)
    corner.CornerRadius = UDim.new(0, 5)
    
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
    tabLabel.ZIndex = 9
    
    tabBtn.MouseButton1Down:Connect(function()
        TweenService:Create(tabBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, -24, 0, 30)
        }):Play()
    end)
    
    local function restaurarTamanho()
        TweenService:Create(tabBtn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, -16, 0, 32)
        }):Play()
    end
    
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
    
    tabBtn.MouseButton1Click:Connect(function()
        selectTab(tabName)
    end)
    
    tabButtons[tabName] = tabBtn
end

local ConfigCallbacks = {
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
            if safePlatform then
                safePlatform:Destroy()
                safePlatform = nil
            end
            if lastPositionBeforeSafeSpot then
                root.CFrame = lastPositionBeforeSafeSpot
                lastPositionBeforeSafeSpot = nil
            end
        end
    end,

    AutoCollect = function(enabled)
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not enabled then
            currentCollectTarget = nil
            if hum then
                pcall(function()
                    hum.PlatformStand = false
                end)
            end
        else
            if hum then
                pcall(function()
                    hum.PlatformStand = true
                end)
            end
        end
    end
}

local function createToggle(parent, configKey, tabCategory)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = configKey
    toggleFrame.Size = UDim2.new(1, -8, 0, 56) -- Altura aumentada de 48 para 56 para dar margem
    toggleFrame.BackgroundColor3 = Color3.fromHex("#0F0F0F")
    toggleFrame.ZIndex = 6
    toggleFrame:SetAttribute("Tab", tabCategory)
    toggleFrame:SetAttribute("ConfigKey", configKey)
    toggleFrame.Parent = parent
    
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", toggleFrame)
    stroke.Color = Color3.fromHex("#141414")
    stroke.Thickness = 1
    
    local titleLabel = Instance.new("TextLabel", toggleFrame)
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(0.65, 0, 0, 16)
    titleLabel.Position = UDim2.new(0, 12, 0, 6) -- Deslocado levemente para cima (Y: 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromHex("#CCCCCC")
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 6
    
    local descLabel = Instance.new("TextLabel", toggleFrame)
    descLabel.Name = "Description"
    descLabel.Size = UDim2.new(0.65, 0, 0, 28) -- Altura expandida de 14 para 28
    descLabel.Position = UDim2.new(0, 12, 0, 22) -- Alinhado na parte inferior
    descLabel.BackgroundTransparency = 1
    descLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 9
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top -- Força o alinhamento no topo do container
    descLabel.TextWrapped = true -- PERMITE A QUEBRA DE LINHA CORRETA SEM APAGAR O TEXTO
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
        local targetPos = Configs[configKey] and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        local targetColor = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
        
        local toggleAnim = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(switchCircle, toggleAnim, {Position = targetPos}):Play()
        TweenService:Create(switchTrack, toggleAnim, {BackgroundColor3 = targetColor}):Play()
        
        if ConfigCallbacks[configKey] then
            task.spawn(ConfigCallbacks[configKey], Configs[configKey])
        end
    end)
end

local function LimparEDesligarAbsolutamente()
    if hbConnection then hbConnection:Disconnect() hbConnection = nil end
    if renderConnection then renderConnection:Disconnect() renderConnection = nil end
    for k in pairs(Configs) do Configs[k] = false end
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local hl = p.Character:FindFirstChild("AkatHighlightMinimal")
            if hl then pcall(function() hl:Destroy() end) end
        end
    end
    
    if safePlatform then pcall(function() safePlatform:Destroy() end) safePlatform = nil end
    
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
                    local reachPart = handle and handle:FindFirstChild("AkatReachPart")
                    if reachPart then reachPart:Destroy() end
                end
            end
        end
    end)
end

local function AlternarConfirmacao(exibir)
    isConfirmOpen = exibir
    local tempoAnim = 0.2
    
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
        TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 14}):Play()
    else
        AplicarFadeSincronizado(confirmFrame, true, tempoAnim)
        if confirmBlur then TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play() end
        if wasMinimizedBeforeConfirm then
            togglesContainer.Visible = false
            SidebarFrame.Visible = false
            div.Visible = false
            isMinimized = true
            TweenService:Create(mainWrapper, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.new(0, 520, 0, 52)}):Play()
        end
        task.delay(tempoAnim, function()
            if not isConfirmOpen then 
                confirmFrame.Visible = false 
                if confirmBlur then confirmBlur:Destroy() confirmBlur = nil end
            end
        end)
    end
end

-- Função de minimização totalmente otimizada (Buttery Smooth)
local function executarMinimizacao()
    if isConfirmOpen then return end
    isMinimized = not isMinimized
    local windowAnim = TweenInfo.new(0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    
    if isMinimized then
        -- Desvanece itens e redimensiona simultaneamente
        AplicarFadeSincronizado(SidebarFrame, true, 0.15)
        AplicarFadeSincronizado(togglesContainer, true, 0.15)
        
        TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 520, 0, 52)}):Play()
        
        task.delay(0.15, function()
            if isMinimized then
                togglesContainer.Visible = false 
                SidebarFrame.Visible = false
                div.Visible = false
            end
        end)
    else
        div.Visible = true
        SidebarFrame.Visible = true
        togglesContainer.Visible = true
        
        AplicarFadeSincronizado(SidebarFrame, true, 0)
        AplicarFadeSincronizado(togglesContainer, true, 0)
        
        TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 520, 0, 300)}):Play()
        
        AplicarFadeSincronizado(SidebarFrame, false, 0.22)
        AplicarFadeSincronizado(togglesContainer, false, 0.22)
        
        filterToggles(activeTab, searchTextBox.Text)
    end
end

-- Função de exibição do menu principal altamente responsiva
local function alternarVisibilidadeMenu()
    menuAberto = not menuAberto
    local tempoAnim = 0.2
    local windowAnim = TweenInfo.new(tempoAnim, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    if menuAberto then
        mainWrapper.Visible = true
        togglesContainer.Visible = false
        SidebarFrame.Visible = false
        div.Visible = false
        
        mainWrapper.Size = UDim2.new(0, 480, 0, isMinimized and 40 or 270)
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
                AplicarFadeSincronizado(SidebarFrame, false, 0.15)
                
                filterToggles(activeTab, searchTextBox.Text)
            end
        end)
    else
        togglesContainer.Visible = false
        SidebarFrame.Visible = false
        div.Visible = false
        
        AplicarFadeSincronizado(mainWrapper, true, tempoAnim)
        local hide = TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 480, 0, isMinimized and 40 or 270)})
        hide:Play()
        hide.Completed:Connect(function() 
            if not menuAberto then mainWrapper.Visible = false end 
        end)
    end
end

-- Mecanismo de Arrastar Aprimorado (Mobile/PC)
local function ConfigurarArrastarAkat(inst)
    local drag = false
    local startPos, dragStart, dragInput
    inst.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            drag = true
            dragStart = input.Position
            startPos = inst.Position
            dragInput = input
            
            local connection
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    drag = false
                    connection:Disconnect()
                end
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

-- Introdução do Script
local function ExecutarIntroAkat()
    local Blur = Instance.new("BlurEffect")
    Blur.Size = 0
    Blur.Parent = Lighting

    local IntroFrame = Instance.new("Frame", screenGui)
    IntroFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    IntroFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    IntroFrame.Size = UDim2.new(1, 0, 1, 0)
    IntroFrame.BackgroundColor3 = Color3.fromHex("#0A0A0A")
    IntroFrame.BackgroundTransparency = 1
    IntroFrame.ZIndex = 500

    local IntroText = Instance.new("TextLabel", IntroFrame)
    IntroText.AnchorPoint = Vector2.new(0.5, 0.5)
    IntroText.Size = UDim2.new(0, 600, 0, 80)
    IntroText.Position = UDim2.new(0.5, 0, 0.5, 10) 
    IntroText.BackgroundTransparency = 1
    IntroText.Font = Enum.Font.GothamBold
    IntroText.TextSize = 26
    IntroText.RichText = true
    IntroText.Text = Locales[currentLanguage].Intro
    IntroText.TextTransparency = 1
    IntroText.ZIndex = 501
    
    local IntroLine = Instance.new("Frame", IntroFrame)
    IntroLine.AnchorPoint = Vector2.new(0.5, 0.5)
    IntroLine.Position = UDim2.new(0.5, 0, 0.5, 30) 
    IntroLine.Size = UDim2.new(0, 0, 0, 2) 
    IntroLine.BackgroundColor3 = Color3.fromHex("#8B0000")
    IntroLine.BorderSizePixel = 0
    IntroLine.BackgroundTransparency = 1
    IntroLine.ZIndex = 502

    TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.2}):Play()
    TweenService:Create(IntroText, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, -6)}):Play()
    TweenService:Create(IntroLine, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(0, 260, 0, 2), Position = UDim2.new(0.5, 0, 0.5, 17)}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 14}):Play()
    task.wait(0.5)

    local correndoBrilho = true
    task.spawn(function()
        local infoFadeOut = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        local infoFadeIn = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        while correndoBrilho do
            local tw1 = TweenService:Create(IntroText, infoFadeOut, {TextTransparency = 0.4})
            local tw2 = TweenService:Create(IntroLine, infoFadeOut, {BackgroundTransparency = 0.4})
            tw1:Play() tw2:Play()
            tw1.Completed:Wait()
            if not correndoBrilho then break end
            local tw3 = TweenService:Create(IntroText, infoFadeIn, {TextTransparency = 0})
            local tw4 = TweenService:Create(IntroLine, infoFadeIn, {BackgroundTransparency = 0})
            tw3:Play() tw4:Play()
            tw3.Completed:Wait()
        end
    end)

    task.wait(1.5)
    correndoBrilho = false

    TweenService:Create(IntroText, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, -16)}):Play()
    TweenService:Create(IntroLine, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 2)}):Play()
    TweenService:Create(IntroFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    TweenService:Create(Blur, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play()
    task.wait(0.35)

    IntroFrame:Destroy()
    Blur:Destroy()

    RegistrarTransparencias(mainFrame)
    for _, item in ipairs(mainFrame:GetDescendants()) do RegistrarTransparencias(item) end

    mainWrapper.Visible = true
    FloatBtn.Visible = true
    
    AplicarFadeSincronizado(mainWrapper, true, 0)
    mainWrapper.Size = UDim2.new(0, 505, 0, 288)
    
    local fastOpen = TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    AplicarFadeSincronizado(mainWrapper, false, 0.12)
    local openTween = TweenService:Create(mainWrapper, fastOpen, {Size = UDim2.new(0, 520, 0, 300)})
    openTween:Play()
    openTween.Completed:Connect(function() selectTab("Combat") end)
end

local function EnviarMensagemChat(msg)
    local TextChatService = game:GetService("TextChatService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if channel then
                channel:SendAsync(msg)
            end
        else
            local chatEvent = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") and ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
            if chatEvent then
                chatEvent:FireServer(msg, "All")
            end
        end
    end)
end

-- ==================== 5. INSTANCIAÇÃO DINÂMICA DE ELEMENTOS E EVENTOS ====================

local function AplicarEfeitoFisicoBotao(btn, hoverColor)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(36, 36, 36)}):Play()
        if btn.Name == "MinimizeBtn" then
            TweenService:Create(btn.Line, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = hoverColor}):Play()
        elseif btn.Name == "SearchBtn" then
            TweenService:Create(circleStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Color = hoverColor}):Play()
            TweenService:Create(SearchHandle, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = hoverColor}):Play()
        elseif btn.Name == "CloseBtn" then
            TweenService:Create(btn.Line1, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = hoverColor}):Play()
            TweenService:Create(btn.Line2, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = hoverColor}):Play()
        elseif btn.Name == "LanguageBtn" then
            TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextColor3 = hoverColor}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(24, 24, 24)}):Play()
        if btn.Name == "MinimizeBtn" then
            TweenService:Create(btn.Line, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "SearchBtn" then
            TweenService:Create(circleStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Color = Color3.fromHex("#A0A0A0")}):Play()
            TweenService:Create(SearchHandle, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "CloseBtn" then
            TweenService:Create(btn.Line1, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
            TweenService:Create(btn.Line2, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromHex("#A0A0A0")}):Play()
        elseif btn.Name == "LanguageBtn" then
            TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextColor3 = Color3.fromRGB(160, 160, 160)}):Play()
        end
    end)
end

AplicarEfeitoFisicoBotao(LanguageBtn, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(SearchBtn, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(MinimizeBtn, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(CloseBtn, Color3.fromRGB(255, 60, 60))

createTabBtn("Combat")
createTabBtn("Visuals")
createTabBtn("Movement")
createTabBtn("Teleports")
createTabBtn("Misc")

createToggle(togglesContainer, "AutoShoot", "Combat")
createToggle(togglesContainer, "Reach", "Combat")
createToggle(togglesContainer, "ESP", "Visuals")
createToggle(togglesContainer, "Speed", "Movement")
createToggle(togglesContainer, "AntiFling", "Movement")
createToggle(togglesContainer, "TpToGun", "Teleports")
createToggle(togglesContainer, "SafeSpot", "Teleports")
createToggle(togglesContainer, "AutoCollect", "Misc")
createToggle(togglesContainer, "ChatRoles", "Misc")

local searchOpen = false
SearchBtn.MouseButton1Click:Connect(function()
    searchOpen = not searchOpen
    local searchAnimInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if searchOpen then
        TweenService:Create(searchBarFrame, searchAnimInfo, {Size = UDim2.new(0, 160, 0, 26)}):Play()
        searchTextBox:CaptureFocus()
    else
        searchTextBox.Text = ""
        TweenService:Create(searchBarFrame, searchAnimInfo, {Size = UDim2.new(0, 0, 0, 26)}):Play()
        searchTextBox:ReleaseFocus()
        filterToggles(activeTab, "")
    end
end)

searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
    filterToggles(activeTab, searchTextBox.Text)
end)

local languageTransitioning = false
LanguageBtn.MouseButton1Click:Connect(function()
    if languageTransitioning then return end
    languageTransitioning = true
    
    AplicarFadeTextos(mainFrame, true, 0.1)
    task.wait(0.1)
    
    if currentLanguage == "EN" then
        currentLanguage = "PT"
    elseif currentLanguage == "PT" then
        currentLanguage = "ES"
    else
        currentLanguage = "EN"
    end
    
    LanguageBtn.Text = currentLanguage
    AtualizarIdioma()
    
    AplicarFadeTextos(mainFrame, false, 0.12)
    task.wait(0.12)
    
    languageTransitioning = false
end)

AtualizarIdioma()

CloseBtn.MouseButton1Click:Connect(function()
    wasMinimizedBeforeConfirm = isMinimized
    if isMinimized then
        isMinimized = false
        div.Visible = true
        SidebarFrame.Visible = true
        togglesContainer.Visible = true
        local expandTween = TweenService:Create(mainWrapper, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.new(0, 520, 0, 300)})
        expandTween:Play()
        expandTween.Completed:Wait()
    end
    AlternarConfirmacao(true)
end)

btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)

btnYes.MouseButton1Click:Connect(function()
    local syncTime = 0.18
    if confirmBlur then TweenService:Create(confirmBlur, TweenInfo.new(syncTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play() end
    AplicarFadeSincronizado(mainWrapper, true, syncTime)
    TweenService:Create(FloatBtn, TweenInfo.new(syncTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {ImageTransparency = 1}):Play()
    
    task.wait(syncTime)
    LimparEDesligarAbsolutamente()
    pcall(function() if confirmBlur then confirmBlur:Destroy() end end)
    screenGui:Destroy()
end)

MinimizeBtn.MouseButton1Click:Connect(executarMinimizacao)
FloatBtn.MouseButton1Click:Connect(alternarVisibilidadeMenu)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and (input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightShift) then
        alternarVisibilidadeMenu()
    end
end)

ConfigurarArrastarAkat(mainWrapper)
ConfigurarArrastarAkat(FloatBtn)

task.spawn(function()
    task.wait(0.1)
    RegistrarTransparencias(confirmFrame)
    for _, d in ipairs(confirmFrame:GetDescendants()) do RegistrarTransparencias(d) end
end)

-- ==================== 6. THREADS EM SEGUNDO PLANO ====================

task.spawn(function()
    while true do
        local currentMurderer = nil
        local currentSheriff = nil
        
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then 
                local role = DetectarRoleReal(p)
                PlayerRoles[p] = role
                if role == "Murderer" then currentMurderer = p end
                if role == "Sheriff" then currentSheriff = p end
            end
        end
        
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

renderConnection = RunService.RenderStepped:Connect(function()
    if Configs.AutoShoot then
        local char = player.Character
        local gunTool = char and char:FindFirstChild("Gun")
        if gunTool and gunTool:IsA("Tool") then
            local murderer, distancia = ObterMurderer()
            if murderer and murderer.Character and distancia < 250 then
                local targetPart = murderer.Character:FindFirstChild("Head") or murderer.Character:FindFirstChild("HumanoidRootPart")
                if targetPart then
                    local lookVector = (targetPart.Position - Camera.CFrame.Position).Unit
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, Camera.CFrame.Position + lookVector)
                    
                    local now = os.clock()
                    if now - lastShootTime > 0.25 then 
                        lastShootTime = now
                        gunTool:Activate()
                    end
                end
            end
        end
    end
end)

local function ObterArmaCaida()
    local gun = workspace:FindFirstChild("GunDrop", true)
    if not gun then
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name == "GunDrop" or child.Name == "Gun" then
                return child
            end
        end
    end
    return gun
end

hbConnection = RunService.Heartbeat:Connect(function(dt)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")

    if Configs.AntiFling then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                for _, part in ipairs(p.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                        pcall(function()
                            part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        end)
                    end
                end
            end
        end
    end

    if Configs.ESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local pChar = p.Character
                local hl = pChar:FindFirstChild("AkatHighlightMinimal")
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "AkatHighlightMinimal"
                    hl.FillTransparency = 0.25
                    hl.OutlineTransparency = 0
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = pChar
                end
                local role = PlayerRoles[p] or "Survivor"
                if role == "Murderer" then
                    hl.FillColor = Color3.fromRGB(255, 0, 0)
                    hl.OutlineColor = Color3.fromRGB(255, 0, 0)
                elseif role == "Sheriff" then
                    hl.FillColor = Color3.fromRGB(0, 110, 255)
                    hl.OutlineColor = Color3.fromRGB(0, 110, 255)
                else
                    hl.FillColor = Color3.fromRGB(0, 255, 0)
                    hl.OutlineColor = Color3.fromRGB(0, 255, 0)
                end
            end
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local hl = p.Character:FindFirstChild("AkatHighlightMinimal")
                if hl then hl:Destroy() end
            end
        end
    end

    -- TELEPORT TO GUN CORRIGIDO COM VERIFICAÇÃO DE PARTIDA ATIVA
    if Configs.TpToGun and root and IsInMatch() then
        local gunDrop = ObterArmaCaida()
        if gunDrop then
            local targetPart = nil
            if gunDrop:IsA("BasePart") then
                targetPart = gunDrop
            else
                targetPart = gunDrop:FindFirstChildOfClass("BasePart") or gunDrop:FindFirstChild("Handle")
            end

            if targetPart and not hasTeleportedToGun then
                hasTeleportedToGun = true
                originalPositionBeforeGun = root.CFrame
                
                root.CFrame = targetPart.CFrame * CFrame.new(0, 1.5, 0)
                
                task.spawn(function()
                    task.wait(0.3) 
                    if originalPositionBeforeGun and root and Configs.TpToGun then
                        root.CFrame = originalPositionBeforeGun
                    end
                    task.wait(1.5) 
                    hasTeleportedToGun = false
                end)
            end
        else
            hasTeleportedToGun = false
        end
    end

    -- AUTO COLLECT REESTRUTURADO E ALTAMENTE OTIMIZADO PARA DELTA MOBILE 2026
    if Configs.AutoCollect and root and IsInMatch() then
        -- No-clip otimizado para celulares sem provocar quedas de FPS por varredura recursiva
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                elseif part:IsA("Accessory") then
                    local handle = part:FindFirstChild("Handle")
                    if handle then handle.CanCollide = false end
                end
            end
            if root then root.CanCollide = false end
        end

        if currentCollectTarget and (not currentCollectTarget.Parent or not currentCollectTarget:IsDescendantOf(workspace)) then
            currentCollectTarget = nil
        end

        -- Busca controlada por clock para evitar gargalo de hardware no Delta
        if not currentCollectTarget and os.clock() - lastCoinSearch > 0.15 then
            lastCoinSearch = os.clock()
            local closestCoin = nil
            local closestDist = math.huge
            
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "Coin_Container" then
                    if d.Name == "Coin" or d.Name == "CoinVisual" or d.Name == "MainCoin" or d.Name == "GoldenCoin" or d.Name == "Coin_Can" or d.Name == "SpinningCoin" then
                        if d.Transparency < 1 and d:IsDescendantOf(workspace) then
                            local dist = (root.Position - d.Position).Magnitude
                            if dist < closestDist and dist < 1200 then
                                closestDist = dist
                                closestCoin = d
                            end
                        end
                    end
                end
            end
            currentCollectTarget = closestCoin
        end

        -- Movimento de interpolação perfeito sem rubberbanding (PlatStand ativo via Callback)
        if currentCollectTarget then
            local targetPos = currentCollectTarget.Position
            local currentPos = root.Position
            local dist = (targetPos - currentPos).Magnitude
            
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end)
            
            if dist > 0.5 then
                local flySpeed = 115 -- Velocidade otimizada e ultra segura para bypass de física
                local moveAmount = flySpeed * dt
                local direction = (targetPos - currentPos).Unit
                
                if moveAmount >= dist then
                    root.CFrame = CFrame.new(targetPos)
                else
                    root.CFrame = CFrame.new(currentPos + direction * moveAmount)
                end
            else
                root.CFrame = CFrame.new(targetPos)
            end
        end
    else
        currentCollectTarget = nil
    end

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
                        reachPart = Instance.new("Part")
                        reachPart.Name = "AkatReachPart"
                        reachPart.Size = Vector3.new(25, 25, 25)
                        reachPart.Transparency = 1
                        reachPart.CanCollide = false
                        reachPart.Massless = true
                        reachPart.CFrame = handle.CFrame
                        reachPart.Parent = handle
                        local weld = Instance.new("WeldConstraint")
                        weld.Part0 = handle
                        weld.Part1 = reachPart
                        weld.Parent = reachPart
                    end
                    if firetouchinterest then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                local tRoot = p.Character.HumanoidRootPart
                                if (root.Position - tRoot.Position).Magnitude <= 25 then
                                    firetouchinterest(handle, tRoot, 0)
                                    firetouchinterest(handle, tRoot, 1)
                                end
                            end
                        end
                    end
                else
                    if reachPart then reachPart:Destroy() end
                end
            end
        end
    end
end)

task.spawn(ExecutarIntroAkat)
