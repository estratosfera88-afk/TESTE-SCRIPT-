-- [[ AKATSUKI UI ONLY [v5.7.2] - REFINED UNIFIED EDITION ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer

-- ==================== ESTADO DOS TOGGLES DA UI ====================
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

-- ==================== DYNAMIC UI COMPONENT & STATE MACHINE ====================
local UIState = "CLOSED"

local UI_TEXT = {
	SearchPlaceholder = "Search...",
	ConfirmCloseTitle = "Do you want to close the script?",
	ConfirmBtn = "Yes",
	CancelBtn = "No",
	Intro = '<font color="#FFFFFF">Scripts by | </font><font color="#8B0000">AKATSUKI</font>',
	Tabs = { Player = "Player", Combat = "Combat", Visuals = "Visuals", Teleports = "Teleports", Settings = "Settings" },
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
local isExpanded = false
local originalTrans = {}
local isConfirmOpen = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeltaAkatUniversalUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local uiParent = player:FindFirstChild("PlayerGui")
if gethui then uiParent = gethui() else pcall(function() uiParent = game:GetService("CoreGui") end) end
if uiParent:FindFirstChild("DeltaAkatUniversalUI") then pcall(function() uiParent.DeltaAkatUniversalUI:Destroy() end) end
screenGui.Parent = uiParent

local SharedClickSound = Instance.new("Sound", screenGui)
SharedClickSound.Name = "SharedClickSound"
SharedClickSound.SoundId = "rbxassetid://6895079853"
SharedClickSound.Volume = 0.6
SharedClickSound.Looped = false

local function PlayUI_Click()
	pcall(function()
		SharedClickSound.TimePosition = 0
		SharedClickSound:Play()
	end)
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
	if not raiz or not raiz.Parent then return end
	local info = TweenInfo.new(duracao, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	local function tratarObjeto(obj)
		if not obj or not obj.Parent then return end
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
			local baseTransparency = orig.ImageTransparency
			local t = fadeOut and 1 or baseTransparency
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

-- ==================== BOTÃO FLUTUANTE ====================
local FloatBtn = screenGui:FindFirstChild("FloatBtn") or Instance.new("ImageButton", screenGui)
FloatBtn.Name = "FloatBtn"
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0.12, 0, 0.4, 0)
FloatBtn.Image = "rbxthumb://type=Asset&id=139044062702391&w=150&h=150"
FloatBtn.BackgroundColor3 = Color3.fromRGB(15, 0, 0)
FloatBtn.Visible = false
FloatBtn.ZIndex = 100
FloatBtn.ClipsDescendants = false
-- CORREÇÃO 4: Desativar AutoButtonColor para evitar branqueamento ao clicar
FloatBtn.AutoButtonColor = false
if not FloatBtn:FindFirstChildOfClass("UICorner") then Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8) end

local FloatOpenSound = FloatBtn:FindFirstChild("FloatOpenSound") or Instance.new("Sound", FloatBtn)
FloatOpenSound.Name = "FloatOpenSound"
FloatOpenSound.SoundId = "rbxassetid://6310837681"
FloatOpenSound.Volume = 0.2
FloatOpenSound.Looped = false

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({FloatOpenSound, SharedClickSound})
	end)
end)

local dragToggleF = false
local dragInputF = nil
local dragStartF = nil
local startPosF = nil
local isDraggingF = false

FloatBtn.InputBegan:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not dragToggleF then
		dragToggleF = true
		dragInputF = input
		isDraggingF = false
		dragStartF = input.Position
		startPosF = FloatBtn.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragToggleF and input == dragInputF then
		local delta = input.Position - dragStartF
		if delta.Magnitude > 5 then
			isDraggingF = true
		end
		FloatBtn.Position = UDim2.new(startPosF.X.Scale, startPosF.X.Offset + delta.X, startPosF.Y.Scale, startPosF.Y.Offset + delta.Y)
	end
end)

local SetUIState

UserInputService.InputEnded:Connect(function(input)
	if input == dragInputF then
		if dragToggleF and not isDraggingF then
			if UIState == "MINIMIZED" or UIState == "CLOSED" then
				pcall(function()
					FloatOpenSound.TimePosition = 0
					FloatOpenSound:Play()
				end)
				SetUIState("OPEN")
			elseif UIState == "OPEN" then
				SetUIState("MINIMIZED")
			end
		end
		dragToggleF = false
		dragInputF = nil
	end
end)

-- ==================== INTERFACE PRINCIPAL ====================
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

local dragUIToggle = false
local dragUIInput = nil
local dragUIStart = nil
local startUIPos = nil

mainFrame.InputBegan:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not dragUIToggle then
		dragUIToggle = true
		dragUIInput = input
		dragUIStart = input.Position
		startUIPos = mainWrapper.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragUIToggle and input == dragUIInput then
		local delta = input.Position - dragUIStart
		mainWrapper.Position = UDim2.new(startUIPos.X.Scale, startUIPos.X.Offset + delta.X, startUIPos.Y.Scale, startUIPos.Y.Offset + delta.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input == dragUIInput then
		dragUIToggle = false
		dragUIInput = nil
	end
end)

-- ==================== ESTRUTURA UNIFICADA DA JANELA ====================
local Shadow = Instance.new("ImageLabel", mainFrame)
Shadow.Name = "WindowShadow"
Shadow.AnchorPoint = Vector2.new(0, 0)
Shadow.Position = UDim2.new(0, -12, 0, -12)
Shadow.Size = UDim2.new(1, 24, 1, 24)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://5554831957"
Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
Shadow.ImageTransparency = 0.45
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(36, 36, 114, 114)
Shadow.ZIndex = 3

local MainBackground = Instance.new("Frame", mainFrame)
MainBackground.Name = "MainBackground"
MainBackground.Size = UDim2.new(1, 0, 1, 0)
MainBackground.BackgroundColor3 = Color3.fromRGB(15, 0, 3)
MainBackground.BorderSizePixel = 0
MainBackground.ClipsDescendants = true
MainBackground.ZIndex = 4

Instance.new("UICorner", MainBackground).CornerRadius = UDim.new(0, 10)

local MainStroke = Instance.new("UIStroke", MainBackground)
MainStroke.Name = "MainStroke"
MainStroke.Thickness = 2
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.Color = Color3.fromRGB(255, 255, 255)

local MainStrokeGrad = Instance.new("UIGradient", MainStroke)
MainStrokeGrad.Rotation = 45
MainStrokeGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 0, 5)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 20, 30))
})

local RedGradientOverlay = Instance.new("Frame", MainBackground)
RedGradientOverlay.Name = "RedGradientOverlay"
RedGradientOverlay.Size = UDim2.new(1, 0, 1, 0)
RedGradientOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
RedGradientOverlay.BackgroundTransparency = 0
RedGradientOverlay.BorderSizePixel = 0
RedGradientOverlay.ZIndex = 4
Instance.new("UICorner", RedGradientOverlay).CornerRadius = UDim.new(0, 10)

-- CORREÇÃO 2: Gradiente com cores duplicadas no início e fim para loop suave sem artefatos.
-- O Roblox interpola linearmente entre os keypoints. Ao girar de 0→360, a emenda entre
-- o último (time=1) e o primeiro (time=0) cria uma faixa estranha se as cores forem diferentes.
-- Solução: usar um gradiente cônico simulado com as cores espelhadas (ex: A→B→A),
-- garantindo que o ponto 0 e o ponto 1 tenham a mesma cor — a emenda fica invisível.
local SingleRedGrad = Instance.new("UIGradient", RedGradientOverlay)
SingleRedGrad.Rotation = 90
SingleRedGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0,   Color3.fromRGB(40, 0, 5)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 15, 22)),
	ColorSequenceKeypoint.new(1,   Color3.fromRGB(40, 0, 5))   -- mesmo que time=0: emenda invisível
})

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	SingleRedGrad.Rotation = (t * 12) % 360
end)

local LeftPanel = Instance.new("Frame", MainBackground)
LeftPanel.Name = "LeftPanel"
LeftPanel.Size = UDim2.new(0, 220, 1, 0)
LeftPanel.Position = UDim2.new(0, 0, 0, 0)
LeftPanel.BackgroundTransparency = 1
LeftPanel.ZIndex = 5

local RightPanel = Instance.new("Frame", MainBackground)
RightPanel.Name = "RightPanel"
RightPanel.Size = UDim2.new(1, -220, 1, 0)
RightPanel.Position = UDim2.new(0, 220, 0, 0)
RightPanel.BackgroundTransparency = 1
RightPanel.ZIndex = 5

-- ==================== HEADER DA BARRA LATERAL ====================
local HeaderLeft = Instance.new("Frame", LeftPanel)
HeaderLeft.Size = UDim2.new(1, 0, 0, 36)
HeaderLeft.Position = UDim2.new(0, 0, 0, 0)
HeaderLeft.BackgroundTransparency = 1
HeaderLeft.ZIndex = 10

local HeaderImage = Instance.new("ImageLabel", HeaderLeft)
HeaderImage.Size = UDim2.new(0, 24, 0, 24)
HeaderImage.Position = UDim2.new(0, 10, 0.5, -12)
HeaderImage.BackgroundTransparency = 1
HeaderImage.Image = "rbxthumb://type=Asset&id=134217291845443&w=150&h=150"
HeaderImage.ZIndex = 11

local title = Instance.new("TextLabel", HeaderLeft)
title.Size = UDim2.new(1, -44, 0, 16)
title.Position = UDim2.new(0, 40, 0, 4)
title.BackgroundTransparency = 1
title.Text = "AKATSUKI SCRIPTS HUB"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 11

local subtitle = Instance.new("TextLabel", HeaderLeft)
subtitle.Size = UDim2.new(1, -44, 0, 12)
subtitle.Position = UDim2.new(0, 40, 0, 20)
subtitle.BackgroundTransparency = 1
subtitle.Text = "MM2 SCRIPT | by zeni"
subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
subtitle.TextTransparency = 0.2
subtitle.TextSize = 9.5
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 11

-- ==================== BARRA DE PESQUISA ====================
local SearchContainer = Instance.new("Frame", LeftPanel)
SearchContainer.Name = "SearchContainer"
SearchContainer.Size = UDim2.new(1, -16, 0, 36)
SearchContainer.Position = UDim2.new(0, 8, 0, 44)
SearchContainer.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
SearchContainer.BackgroundTransparency = 0.85
SearchContainer.ZIndex = 10
Instance.new("UICorner", SearchContainer).CornerRadius = UDim.new(0, 8)

local searchStroke = Instance.new("UIStroke", SearchContainer)
searchStroke.Color = Color3.fromRGB(60, 20, 20)
searchStroke.Transparency = 0.75
searchStroke.Thickness = 1

local SearchIconFrame = Instance.new("Frame", SearchContainer)
SearchIconFrame.Size = UDim2.new(0, 14, 0, 14)
SearchIconFrame.Position = UDim2.new(0, 14, 0.5, -7)
SearchIconFrame.BackgroundTransparency = 1
SearchIconFrame.ZIndex = 12

local scCircle = Instance.new("Frame", SearchIconFrame)
scCircle.Size = UDim2.new(0, 8, 0, 8)
scCircle.BackgroundTransparency = 1
Instance.new("UICorner", scCircle).CornerRadius = UDim.new(1, 0)
local scCStroke = Instance.new("UIStroke", scCircle)
scCStroke.Color = Color3.fromRGB(140, 140, 140)
scCStroke.Thickness = 1.2

local scHandle = Instance.new("Frame", SearchIconFrame)
scHandle.Size = UDim2.new(0, 1.2, 0, 5)
scHandle.Position = UDim2.new(0, 9, 0, 8)
scHandle.Rotation = -45
scHandle.BackgroundColor3 = Color3.fromRGB(140, 140, 140)
scHandle.BorderSizePixel = 0

local searchTextBox = Instance.new("TextBox", SearchContainer)
searchTextBox.Size = UDim2.new(1, -38, 1, 0)
searchTextBox.Position = UDim2.new(0, 38, 0, 0)
searchTextBox.BackgroundTransparency = 1
searchTextBox.PlaceholderText = UI_TEXT.SearchPlaceholder
searchTextBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
searchTextBox.Text = ""
searchTextBox.TextColor3 = Color3.fromRGB(230, 230, 230)
searchTextBox.Font = Enum.Font.GothamMedium
searchTextBox.TextSize = 13
searchTextBox.TextXAlignment = Enum.TextXAlignment.Left
searchTextBox.ZIndex = 12
searchTextBox.Active = true
searchTextBox.ClearTextOnFocus = false

-- ==================== TABS CONTAINER ====================
local TabsContainer = Instance.new("ScrollingFrame", LeftPanel)
TabsContainer.Name = "TabsContainer"
TabsContainer.Size = UDim2.new(1, -8, 1, -152)
TabsContainer.Position = UDim2.new(0, 4, 0, 87)
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
	local minH = TabsContainer.AbsoluteSize.Y + 12
	TabsContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(contentH, minH))
end

TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabsCanvas)
TabsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateTabsCanvas)

-- ==================== ACTIVEBAR REUTILIZÁVEL ====================
local sharedActiveBar = Instance.new("Frame", LeftPanel)
sharedActiveBar.Name = "SharedActiveBar"
sharedActiveBar.AnchorPoint = Vector2.new(0, 0.5)
sharedActiveBar.Size = UDim2.new(0, 3, 0, 22)
sharedActiveBar.Position = UDim2.new(0, 11, 0, 0)
sharedActiveBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sharedActiveBar.BorderSizePixel = 0
sharedActiveBar.Visible = false
sharedActiveBar.ZIndex = 15
sharedActiveBar.ClipsDescendants = false
Instance.new("UICorner", sharedActiveBar).CornerRadius = UDim.new(1, 0)

local sharedBarGrad = Instance.new("UIGradient", sharedActiveBar)
sharedBarGrad.Rotation = 90
sharedBarGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(120, 0, 10)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 30, 40)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(120, 0, 10))
})

-- ==================== USER PROFILE BADGE ====================
local UserProfileFrame = Instance.new("Frame", LeftPanel)
UserProfileFrame.Size = UDim2.new(1, -16, 0, 55)
UserProfileFrame.Position = UDim2.new(0, 8, 1, -63)
UserProfileFrame.BackgroundColor3 = Color3.fromRGB(20, 12, 12)
UserProfileFrame.BackgroundTransparency = 0.35
UserProfileFrame.BorderSizePixel = 0
UserProfileFrame.ZIndex = 10
Instance.new("UICorner", UserProfileFrame).CornerRadius = UDim.new(0, 8)

local userStroke = Instance.new("UIStroke", UserProfileFrame)
userStroke.Thickness = 0.9
userStroke.Color = Color3.fromRGB(255, 255, 255)
local uGrad = Instance.new("UIGradient", userStroke)
uGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 10, 15)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 0, 0))
})

local AvatarImage = Instance.new("ImageLabel", UserProfileFrame)
AvatarImage.Size = UDim2.new(0, 34, 0, 34)
AvatarImage.Position = UDim2.new(0, 10, 0.5, -17)
AvatarImage.BackgroundTransparency = 1
AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
AvatarImage.ZIndex = 11
Instance.new("UICorner", AvatarImage).CornerRadius = UDim.new(1, 0)

local AvatarStroke = Instance.new("UIStroke", AvatarImage)
AvatarStroke.Thickness = 0.9
AvatarStroke.Color = Color3.fromRGB(255, 255, 255)
local avGrad = Instance.new("UIGradient", AvatarStroke)
avGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 10, 15)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 0, 0))
})

local StatusIndicator = Instance.new("Frame", AvatarImage)
StatusIndicator.Size = UDim2.new(0, 9, 0, 9)
StatusIndicator.Position = UDim2.new(1, -7, 1, -7)
StatusIndicator.BackgroundColor3 = Color3.fromRGB(40, 220, 80)
StatusIndicator.BorderSizePixel = 0
StatusIndicator.ZIndex = 14
Instance.new("UICorner", StatusIndicator).CornerRadius = UDim.new(1, 0)
local statusStroke = Instance.new("UIStroke", StatusIndicator)
statusStroke.Color = Color3.fromRGB(15, 5, 5)
statusStroke.Thickness = 1.5

local DisplayNameLabel = Instance.new("TextLabel", UserProfileFrame)
DisplayNameLabel.Size = UDim2.new(1, -82, 0, 16)
DisplayNameLabel.Position = UDim2.new(0, 54, 0.5, -16)
DisplayNameLabel.BackgroundTransparency = 1
DisplayNameLabel.Text = player.DisplayName
DisplayNameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
DisplayNameLabel.Font = Enum.Font.GothamBold
DisplayNameLabel.TextSize = 13.5
DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLabel.ZIndex = 11

local UsernameLabel = Instance.new("TextLabel", UserProfileFrame)
UsernameLabel.Size = UDim2.new(1, -82, 0, 14)
UsernameLabel.Position = UDim2.new(0, 54, 0.5, 2)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Text = "@" .. player.Name
UsernameLabel.TextColor3 = Color3.fromRGB(110, 110, 110)
UsernameLabel.Font = Enum.Font.Gotham
UsernameLabel.TextSize = 11.5
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
UsernameLabel.ZIndex = 11

local PrivacyBtn = Instance.new("ImageButton", UserProfileFrame)
PrivacyBtn.Size = UDim2.new(0, 20, 0, 20)
PrivacyBtn.Position = UDim2.new(1, -26, 0.5, -10)
PrivacyBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
PrivacyBtn.BackgroundTransparency = 0.2
PrivacyBtn.BorderSizePixel = 0
PrivacyBtn.ZIndex = 12
-- CORREÇÃO 4: Desativar AutoButtonColor em todos os ImageButtons
PrivacyBtn.AutoButtonColor = false
Instance.new("UICorner", PrivacyBtn).CornerRadius = UDim.new(0, 5)
local privStroke = Instance.new("UIStroke", PrivacyBtn)
privStroke.Color = Color3.fromRGB(60, 20, 20)
privStroke.Thickness = 1
privStroke.Transparency = 0.5

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
	local flashTween = TweenService:Create(PrivacyBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {BackgroundTransparency = 0})
	flashTween:Play()

	isPrivate = not isPrivate
	if isPrivate then
		PrivacyIcon.Image = "rbxthumb://type=Asset&id=85795266774996&w=150&h=150"
		DisplayNameLabel.Text = string.rep("", math.clamp(#player.DisplayName, 3, 8))
		UsernameLabel.Text = "@" .. string.rep("", math.clamp(#player.Name, 3, 8))
	else
		PrivacyIcon.Image = "rbxthumb://type=Asset&id=103096515071530&w=150&h=150"
		DisplayNameLabel.Text = player.DisplayName
		UsernameLabel.Text = "@" .. player.Name
	end
end)

-- ==================== RIGHT PANEL HEADER & BADGE ====================
local topButtons = Instance.new("Frame", RightPanel)
topButtons.Size = UDim2.new(1, -12, 0, 36)
topButtons.Position = UDim2.new(0, 0, 0, 0)
topButtons.BackgroundTransparency = 1
topButtons.ZIndex = 10

local ControlsFrame = Instance.new("Frame", topButtons)
ControlsFrame.Size = UDim2.new(0, 130, 1, 0)
ControlsFrame.Position = UDim2.new(1, -130, 0, 0)
ControlsFrame.BackgroundTransparency = 1
ControlsFrame.ZIndex = 11

local UIListTop = Instance.new("UIListLayout", ControlsFrame)
UIListTop.FillDirection = Enum.FillDirection.Horizontal
UIListTop.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListTop.VerticalAlignment = Enum.VerticalAlignment.Center
UIListTop.Padding = UDim.new(0, 14)
UIListTop.SortOrder = Enum.SortOrder.LayoutOrder

local TOP_BTN_COLOR = Color3.fromRGB(170, 170, 170)

local MinimizeBtn = Instance.new("ImageButton", ControlsFrame)
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.LayoutOrder = 1
MinimizeBtn.Size = UDim2.new(0, 16, 0, 16)
MinimizeBtn.BackgroundTransparency = 1
MinimizeBtn.Image = "rbxthumb://type=Asset&id=97090905107587&w=150&h=150"
MinimizeBtn.ImageColor3 = TOP_BTN_COLOR
MinimizeBtn.ZIndex = 11
-- CORREÇÃO 4: Desativar AutoButtonColor para evitar branqueamento ao clicar
MinimizeBtn.AutoButtonColor = false

local ExpandBtn = Instance.new("ImageButton", ControlsFrame)
ExpandBtn.Name = "ExpandBtn"
ExpandBtn.LayoutOrder = 2
ExpandBtn.Size = UDim2.new(0, 16, 0, 16)
ExpandBtn.BackgroundTransparency = 1
ExpandBtn.Image = "rbxthumb://type=Asset&id=78749046909931&w=150&h=150"
ExpandBtn.ImageColor3 = TOP_BTN_COLOR
ExpandBtn.ZIndex = 11
-- CORREÇÃO 4: Desativar AutoButtonColor
ExpandBtn.AutoButtonColor = false

local CloseBtn = Instance.new("ImageButton", ControlsFrame)
CloseBtn.Name = "CloseBtn"
CloseBtn.LayoutOrder = 3
CloseBtn.Size = UDim2.new(0, 16, 0, 16)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Image = "rbxthumb://type=Asset&id=70710316269357&w=150&h=150"
CloseBtn.ImageColor3 = TOP_BTN_COLOR
CloseBtn.ZIndex = 11
-- CORREÇÃO 4: Desativar AutoButtonColor
CloseBtn.AutoButtonColor = false

local BadgeFrame = Instance.new("Frame", RightPanel)
BadgeFrame.Name = "BadgeFrame"
BadgeFrame.Size = UDim2.new(0, 44, 0, 18)
BadgeFrame.Position = UDim2.new(0, 12, 0, 9)
BadgeFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
BadgeFrame.BorderSizePixel = 0
BadgeFrame.ZIndex = 15
Instance.new("UICorner", BadgeFrame).CornerRadius = UDim.new(0, 8)

local badgeStroke = Instance.new("UIStroke", BadgeFrame)
badgeStroke.Thickness = 0.9
badgeStroke.Color = Color3.fromRGB(255, 255, 255)

local badgeGrad = Instance.new("UIGradient", BadgeFrame)
badgeGrad.Rotation = 45
badgeGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0))
})

local badgeStrokeGrad = Instance.new("UIGradient", badgeStroke)
badgeStrokeGrad.Rotation = 45
badgeStrokeGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0))
})

local BadgeText = Instance.new("TextLabel", BadgeFrame)
BadgeText.Size = UDim2.new(1, 0, 1, 0)
BadgeText.BackgroundTransparency = 1
BadgeText.Text = "V5.7"
BadgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
BadgeText.Font = Enum.Font.GothamBold
BadgeText.TextSize = 8.5
BadgeText.ZIndex = 16

-- ==================== TOGGLES CONTAINER ====================
local togglesContainer = Instance.new("ScrollingFrame", RightPanel)
togglesContainer.Name = "TogglesContainer"
togglesContainer.Size = UDim2.new(1, -12, 1, -48)
togglesContainer.Position = UDim2.new(0, 6, 0, 42)
togglesContainer.BackgroundColor3 = Color3.fromRGB(30, 12, 14)
togglesContainer.BackgroundTransparency = 0.7
togglesContainer.BorderSizePixel = 0
togglesContainer.ClipsDescendants = true
togglesContainer.ZIndex = 10
togglesContainer.ScrollBarThickness = 3
togglesContainer.ScrollBarImageColor3 = Color3.fromRGB(220, 30, 40)
togglesContainer.ScrollBarImageTransparency = 0
togglesContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
togglesContainer.AutomaticCanvasSize = Enum.AutomaticSize.None

Instance.new("UICorner", togglesContainer).CornerRadius = UDim.new(0, 8)

local containerLayout = Instance.new("UIListLayout", togglesContainer)
containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
containerLayout.Padding = UDim.new(0, 6)
containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local uiPadding = Instance.new("UIPadding", togglesContainer)
uiPadding.PaddingTop = UDim.new(0, 8)
uiPadding.PaddingBottom = UDim.new(0, 8)
uiPadding.PaddingLeft = UDim.new(0, 4)
uiPadding.PaddingRight = UDim.new(0, 6)

local function UpdateCanvasSize()
	local contentHeight = containerLayout.AbsoluteContentSize.Y + 24
	local minHeight = togglesContainer.AbsoluteSize.Y + 1
	togglesContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(contentHeight, minHeight))
end

containerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvasSize)
togglesContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateCanvasSize)

-- ==================== CONFIRM FRAME & INTENSE BLUR ====================
local confirmBlur = Lighting:FindFirstChild("ConfirmBlur") or Instance.new("BlurEffect", Lighting)
confirmBlur.Name = "ConfirmBlur"
confirmBlur.Size = 0

local confirmOverlay = Instance.new("Frame", screenGui)
confirmOverlay.Name = "ConfirmOverlay"
confirmOverlay.Size = UDim2.new(1, 0, 1, 0)
confirmOverlay.Position = UDim2.new(0, 0, 0, 0)
confirmOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
confirmOverlay.BackgroundTransparency = 0.55
confirmOverlay.Visible = false
confirmOverlay.ZIndex = 990
confirmOverlay.ClipsDescendants = true

local confirmCard = Instance.new("Frame", confirmOverlay)
confirmCard.Name = "ConfirmCard"
confirmCard.Size = UDim2.new(0, 300, 0, 130)
confirmCard.AnchorPoint = Vector2.new(0.5, 0.5)
confirmCard.Position = UDim2.new(0.5, 0, 0.5, 0)
confirmCard.BackgroundColor3 = Color3.fromRGB(18, 8, 8)
confirmCard.BackgroundTransparency = 0
confirmCard.BorderSizePixel = 0
confirmCard.ZIndex = 995
Instance.new("UICorner", confirmCard).CornerRadius = UDim.new(0, 14)

local confirmStroke = Instance.new("UIStroke", confirmCard)
confirmStroke.Thickness = 1.5
confirmStroke.Color = Color3.fromRGB(255, 255, 255)

local confStrokeGrad = Instance.new("UIGradient", confirmStroke)
confStrokeGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(120, 0, 10)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 30, 40)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(120, 0, 10))
})

RunService.RenderStepped:Connect(function()
	confStrokeGrad.Rotation = (os.clock() * 15) % 360
	uGrad.Rotation = (os.clock() * 60) % 360
	avGrad.Rotation = (os.clock() * 60) % 360
	badgeGrad.Rotation = (os.clock() * 10) % 360
	badgeStrokeGrad.Rotation = (os.clock() * 10) % 360
end)

local confirmCardGrad = Instance.new("UIGradient", confirmCard)
confirmCardGrad.Rotation = 135
confirmCardGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 10, 10)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 4, 4))
})

local confirmLabel = Instance.new("TextLabel", confirmCard)
confirmLabel.Size = UDim2.new(1, -24, 0, 22)
confirmLabel.Position = UDim2.new(0, 12, 0, 18)
confirmLabel.BackgroundTransparency = 1
confirmLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
confirmLabel.Font = Enum.Font.GothamBold
confirmLabel.TextSize = 13
confirmLabel.TextXAlignment = Enum.TextXAlignment.Center
confirmLabel.Text = UI_TEXT.ConfirmCloseTitle
confirmLabel.ZIndex = 1000

local confirmSep = Instance.new("Frame", confirmCard)
confirmSep.Size = UDim2.new(1, -40, 0, 1)
confirmSep.Position = UDim2.new(0, 20, 0, 48)
confirmSep.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
confirmSep.BackgroundTransparency = 0.6
confirmSep.BorderSizePixel = 0
confirmSep.ZIndex = 999
Instance.new("UICorner", confirmSep).CornerRadius = UDim.new(1, 0)

local btnYes = Instance.new("TextButton", confirmCard)
btnYes.Size = UDim2.new(0, 118, 0, 32)
btnYes.Position = UDim2.new(0.5, -124, 0, 62)
btnYes.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
btnYes.TextColor3 = Color3.fromRGB(255, 255, 255)
btnYes.Font = Enum.Font.GothamMedium
btnYes.TextSize = 14
btnYes.Text = UI_TEXT.ConfirmBtn
btnYes.ZIndex = 1000
btnYes.BorderSizePixel = 0
Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 14)
local btnYesGrad = Instance.new("UIGradient", btnYes)
btnYesGrad.Rotation = 90
btnYesGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 20, 20)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 0, 0))
})

local btnNo = Instance.new("TextButton", confirmCard)
btnNo.Size = UDim2.new(0, 118, 0, 32)
btnNo.Position = UDim2.new(0.5, 6, 0, 62)
btnNo.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
btnNo.TextColor3 = Color3.fromRGB(170, 170, 170)
btnNo.Font = Enum.Font.GothamMedium
btnNo.TextSize = 14
btnNo.Text = UI_TEXT.CancelBtn
btnNo.ZIndex = 1000
btnNo.BorderSizePixel = 0
Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 14)
local btnNoStroke = Instance.new("UIStroke", btnNo)
btnNoStroke.Color = Color3.fromRGB(60, 60, 60)
btnNoStroke.Thickness = 1
btnNoStroke.Transparency = 0.3

btnYes.MouseEnter:Connect(function() TweenService:Create(btnYes, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(180, 20, 20)}):Play() end)
btnYes.MouseLeave:Connect(function() TweenService:Create(btnYes, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(139, 0, 0)}):Play() end)
btnNo.MouseEnter:Connect(function() TweenService:Create(btnNo, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(45, 45, 45)}):Play() end)
btnNo.MouseLeave:Connect(function() TweenService:Create(btnNo, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play() end)

AplicarFadeSincronizado(confirmCard, true, 0)

-- ==================== SISTEMA DE NOTIFICAÇÃO (STACK / FILA) ====================
local ActiveNotifications = {}
local NOTIF_DURATION = 10

-- CORREÇÃO 3: Sistema de posicionamento corrigido.
-- O problema era que notif.AbsoluteSize.Y retorna 0 quando o frame acabou de
-- ser inserido (ainda não renderizado). O fallback usava lógica de nome que
-- podia falhar. Agora usamos os tamanhos fixos declarados (size.Y.Offset)
-- diretamente, que sempre estão disponíveis mesmo antes da renderização.
local function UpdateNotifications()
	for i, notif in ipairs(ActiveNotifications) do
		if notif and notif.Parent then
			-- Usa o tamanho declarado do UDim2 (Size.Y.Offset) em vez de AbsoluteSize.Y
			-- para garantir cálculo correto antes da primeira renderização do frame
			local h = notif.Size.Y.Offset
			if h == 0 then h = 96 end -- fallback de segurança
			local targetY = -24 - ((i - 1) * (h + 12))
			TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				Position = UDim2.new(1, -20, 1, targetY)
			}):Play()
		end
	end
end

-- ==================== NOTIFICAÇÃO 1 (COM TÍTULO E SUBTÍTULO CENTRALIZADOS NA BARRA DE DESTAQUE) ====================
local function CriarNotificacao(titulo, descricao, iconeId)
	local notifHolder = Instance.new("Frame", screenGui)
	notifHolder.Name = "NotifHolder"
	notifHolder.AnchorPoint = Vector2.new(1, 1)
	notifHolder.Size = UDim2.new(0, 330, 0, 96)
	notifHolder.Position = UDim2.new(1, 340, 1, -24)
	notifHolder.BackgroundTransparency = 1
	notifHolder.ZIndex = 200
	notifHolder.ClipsDescendants = false

	local notifCard = Instance.new("Frame", notifHolder)
	notifCard.Name = "NotifCard"
	notifCard.Size = UDim2.new(1, 0, 1, 0)
	notifCard.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	notifCard.BackgroundTransparency = 0.25
	notifCard.BorderSizePixel = 0
	notifCard.ZIndex = 201
	notifCard.ClipsDescendants = false
	Instance.new("UICorner", notifCard).CornerRadius = UDim.new(0, 16)

	local notifShadow = Instance.new("ImageLabel", notifCard)
	notifShadow.Name = "Shadow"
	notifShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	notifShadow.Position = UDim2.new(0.5, 0, 0.5, 4)
	notifShadow.Size = UDim2.new(1, 24, 1, 24)
	notifShadow.BackgroundTransparency = 1
	notifShadow.Image = "rbxassetid://5554831957"
	notifShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	notifShadow.ImageTransparency = 0.35
	notifShadow.ScaleType = Enum.ScaleType.Slice
	notifShadow.SliceCenter = Rect.new(36, 36, 114, 114)
	notifShadow.ZIndex = 200

	local accentBar = Instance.new("Frame", notifCard)
	accentBar.Size = UDim2.new(0, 4, 0, 52)
	accentBar.Position = UDim2.new(0, 14, 0.5, -26)
	accentBar.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
	accentBar.BorderSizePixel = 0
	accentBar.ZIndex = 202
	Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)
	local accentGrad = Instance.new("UIGradient", accentBar)
	accentGrad.Rotation = 90
	accentGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 30, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 10, 10))
	})

	local notifTitle = Instance.new("TextLabel", notifCard)
	notifTitle.Size = UDim2.new(1, -76, 0, 18)
	notifTitle.Position = UDim2.new(0, 26, 0.5, -19)
	notifTitle.BackgroundTransparency = 1
	notifTitle.Text = titulo or "AKATSUKI"
	notifTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
	notifTitle.Font = Enum.Font.GothamBold
	notifTitle.TextSize = 16
	notifTitle.TextXAlignment = Enum.TextXAlignment.Left
	notifTitle.ZIndex = 203

	local notifDesc = Instance.new("TextLabel", notifCard)
	notifDesc.Size = UDim2.new(1, -76, 0, 18)
	notifDesc.Position = UDim2.new(0, 26, 0.5, 1)
	notifDesc.BackgroundTransparency = 1
	notifDesc.Text = descricao or ""
	notifDesc.TextColor3 = Color3.fromRGB(150, 150, 155)
	notifDesc.Font = Enum.Font.Gotham
	notifDesc.TextSize = 12
	notifDesc.TextXAlignment = Enum.TextXAlignment.Left
	notifDesc.TextYAlignment = Enum.TextYAlignment.Top
	notifDesc.TextWrapped = true
	notifDesc.ZIndex = 203

	local notifCloseBtn = Instance.new("TextButton", notifCard)
	notifCloseBtn.Size = UDim2.new(0, 24, 0, 24)
	notifCloseBtn.Position = UDim2.new(1, -32, 0, 10)
	notifCloseBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
	notifCloseBtn.BackgroundTransparency = 0.2
	notifCloseBtn.Text = ""
	notifCloseBtn.ZIndex = 205
	notifCloseBtn.BorderSizePixel = 0
	Instance.new("UICorner", notifCloseBtn).CornerRadius = UDim.new(0, 6)

	local xStroke = Instance.new("UIStroke", notifCloseBtn)
	xStroke.Color = Color3.fromRGB(80, 80, 85)
	xStroke.Thickness = 1
	xStroke.Transparency = 0.5

	local xL1 = Instance.new("Frame", notifCloseBtn)
	xL1.AnchorPoint = Vector2.new(0.5, 0.5)
	xL1.Position = UDim2.new(0.5, 0, 0.5, 0)
	xL1.Size = UDim2.new(0, 10, 0, 1.5)
	xL1.Rotation = 45
	xL1.BackgroundColor3 = Color3.fromRGB(160, 160, 165)
	xL1.BorderSizePixel = 0
	xL1.ZIndex = 206
	Instance.new("UICorner", xL1).CornerRadius = UDim.new(1,0)
	local xL2 = Instance.new("Frame", notifCloseBtn)
	xL2.AnchorPoint = Vector2.new(0.5, 0.5)
	xL2.Position = UDim2.new(0.5, 0, 0.5, 0)
	xL2.Size = UDim2.new(0, 10, 0, 1.5)
	xL2.Rotation = -45
	xL2.BackgroundColor3 = Color3.fromRGB(160, 160, 165)
	xL2.BorderSizePixel = 0
	xL2.ZIndex = 206
	Instance.new("UICorner", xL2).CornerRadius = UDim.new(1,0)

	notifCloseBtn.MouseEnter:Connect(function()
		TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160, 20, 20)}):Play()
		TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
		TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
	end)
	notifCloseBtn.MouseLeave:Connect(function()
		TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(35, 35, 38)}):Play()
		TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160,160,165)}):Play()
		TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160,160,165)}):Play()
	end)

	local progressBg = Instance.new("Frame", notifCard)
	progressBg.Size = UDim2.new(1, -28, 0, 3)
	progressBg.Position = UDim2.new(0, 14, 1, -10)
	progressBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	progressBg.BorderSizePixel = 0
	progressBg.ZIndex = 202
	progressBg.ClipsDescendants = true
	Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)

	local progressBar = Instance.new("Frame", progressBg)
	progressBar.Size = UDim2.new(1, 0, 1, 0)
	progressBar.Position = UDim2.new(0, 0, 0, 0)
	progressBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	progressBar.BorderSizePixel = 0
	progressBar.ZIndex = 203
	Instance.new("UICorner", progressBar).CornerRadius = UDim.new(1, 0)

	local progressGrad = Instance.new("UIGradient", progressBar)
	progressGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 0, 0))
	})

	table.insert(ActiveNotifications, 1, notifHolder)
	UpdateNotifications()

	local dismissed = false
	local function DismissNotif()
		if dismissed then return end
		dismissed = true

		for i, v in ipairs(ActiveNotifications) do
			if v == notifHolder then
				table.remove(ActiveNotifications, i)
				break
			end
		end
		UpdateNotifications()

		local slideOut = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		TweenService:Create(notifHolder, slideOut, {Position = UDim2.new(1, 360, notifHolder.Position.Y.Scale, notifHolder.Position.Y.Offset)}):Play()
		TweenService:Create(notifCard, slideOut, {BackgroundTransparency = 1}):Play()
		task.delay(0.28, function()
			if notifHolder and notifHolder.Parent then
				notifHolder:Destroy()
			end
		end)
	end

	notifCloseBtn.MouseButton1Click:Connect(function() DismissNotif() end)

	local barTween = TweenService:Create(progressBar, TweenInfo.new(NOTIF_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 1, 0)})
	task.delay(0.1, function() barTween:Play() end)
	task.delay(NOTIF_DURATION + 0.1, function() DismissNotif() end)
end

-- ==================== NOTIFICAÇÃO DE LINK COPIADO (REBAIXADA) ====================
local function CriarNotificacaoLinkCopiado(texto, iconeId)
	local notifHolder = Instance.new("Frame", screenGui)
	notifHolder.Name = "NotifHolderLink"
	notifHolder.AnchorPoint = Vector2.new(1, 1)
	notifHolder.Size = UDim2.new(0, 330, 0, 64)
	notifHolder.Position = UDim2.new(1, 360, 1, -24)
	notifHolder.BackgroundTransparency = 1
	notifHolder.ZIndex = 200
	notifHolder.ClipsDescendants = false

	local notifCard = Instance.new("Frame", notifHolder)
	notifCard.Name = "NotifCard"
	notifCard.Size = UDim2.new(1, 0, 1, 0)
	notifCard.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	notifCard.BackgroundTransparency = 0.25
	notifCard.BorderSizePixel = 0
	notifCard.ZIndex = 201
	notifCard.ClipsDescendants = false
	Instance.new("UICorner", notifCard).CornerRadius = UDim.new(0, 16)

	local notifShadow = Instance.new("ImageLabel", notifCard)
	notifShadow.Name = "Shadow"
	notifShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	notifShadow.Position = UDim2.new(0.5, 0, 0.5, 4)
	notifShadow.Size = UDim2.new(1, 24, 1, 24)
	notifShadow.BackgroundTransparency = 1
	notifShadow.Image = "rbxassetid://5554831957"
	notifShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	notifShadow.ImageTransparency = 0.35
	notifShadow.ScaleType = Enum.ScaleType.Slice
	notifShadow.SliceCenter = Rect.new(36, 36, 114, 114)
	notifShadow.ZIndex = 200

	local accentBar = Instance.new("Frame", notifCard)
	accentBar.Size = UDim2.new(0, 4, 0, 36)
	accentBar.Position = UDim2.new(0, 14, 0.5, -18)
	accentBar.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
	accentBar.BorderSizePixel = 0
	accentBar.ZIndex = 202
	Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)
	local accentGrad = Instance.new("UIGradient", accentBar)
	accentGrad.Rotation = 90
	accentGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 30, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 10, 10))
	})

	local contentContainer = Instance.new("Frame", notifCard)
	contentContainer.Size = UDim2.new(1, -64, 1, -12)
	contentContainer.Position = UDim2.new(0, 26, 0, 6)
	contentContainer.BackgroundTransparency = 1

	local cLayout = Instance.new("UIListLayout", contentContainer)
	cLayout.FillDirection = Enum.FillDirection.Horizontal
	cLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cLayout.Padding = UDim.new(0, 8)

	local notifText = Instance.new("TextLabel", contentContainer)
	notifText.LayoutOrder = 1
	notifText.AutomaticSize = Enum.AutomaticSize.X
	notifText.Size = UDim2.new(0, 0, 0, 24)
	notifText.BackgroundTransparency = 1
	notifText.Text = texto or "LINK COPIED SUCCESSFULLY"
	notifText.TextColor3 = Color3.fromRGB(240, 240, 240)
	notifText.Font = Enum.Font.GothamBold
	notifText.TextSize = 15
	notifText.TextXAlignment = Enum.TextXAlignment.Left
	notifText.ZIndex = 203

	if iconeId then
		local verifyIcon = Instance.new("ImageLabel", contentContainer)
		verifyIcon.LayoutOrder = 2
		verifyIcon.Size = UDim2.new(0, 24, 0, 24)
		verifyIcon.BackgroundTransparency = 1
		verifyIcon.Image = iconeId
		verifyIcon.ZIndex = 204
	end

	local notifCloseBtn = Instance.new("TextButton", notifCard)
	notifCloseBtn.Size = UDim2.new(0, 20, 0, 20)
	notifCloseBtn.Position = UDim2.new(1, -28, 0.5, -10)
	notifCloseBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
	notifCloseBtn.BackgroundTransparency = 0.2
	notifCloseBtn.Text = ""
	notifCloseBtn.ZIndex = 205
	notifCloseBtn.BorderSizePixel = 0
	Instance.new("UICorner", notifCloseBtn).CornerRadius = UDim.new(0, 6)

	local xStroke = Instance.new("UIStroke", notifCloseBtn)
	xStroke.Color = Color3.fromRGB(80, 80, 85)
	xStroke.Thickness = 1
	xStroke.Transparency = 0.5

	local xL1 = Instance.new("Frame", notifCloseBtn)
	xL1.AnchorPoint = Vector2.new(0.5, 0.5)
	xL1.Position = UDim2.new(0.5, 0, 0.5, 0)
	xL1.Size = UDim2.new(0, 8, 0, 1.5)
	xL1.Rotation = 45
	xL1.BackgroundColor3 = Color3.fromRGB(160, 160, 165)
	xL1.BorderSizePixel = 0
	xL1.ZIndex = 206
	Instance.new("UICorner", xL1).CornerRadius = UDim.new(1,0)
	local xL2 = Instance.new("Frame", notifCloseBtn)
	xL2.AnchorPoint = Vector2.new(0.5, 0.5)
	xL2.Position = UDim2.new(0.5, 0, 0.5, 0)
	xL2.Size = UDim2.new(0, 8, 0, 1.5)
	xL2.Rotation = -45
	xL2.BackgroundColor3 = Color3.fromRGB(160, 160, 165)
	xL2.BorderSizePixel = 0
	xL2.ZIndex = 206
	Instance.new("UICorner", xL2).CornerRadius = UDim.new(1,0)

	notifCloseBtn.MouseEnter:Connect(function()
		TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160, 20, 20)}):Play()
		TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
		TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
	end)
	notifCloseBtn.MouseLeave:Connect(function()
		TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(35, 35, 38)}):Play()
		TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160,160,165)}):Play()
		TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160,160,165)}):Play()
	end)

	local progressBg = Instance.new("Frame", notifCard)
	progressBg.Size = UDim2.new(1, -28, 0, 3)
	progressBg.Position = UDim2.new(0, 14, 1, -8)
	progressBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	progressBg.BorderSizePixel = 0
	progressBg.ZIndex = 202
	progressBg.ClipsDescendants = true
	Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)

	local progressBar = Instance.new("Frame", progressBg)
	progressBar.Size = UDim2.new(1, 0, 1, 0)
	progressBar.Position = UDim2.new(0, 0, 0, 0)
	progressBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	progressBar.BorderSizePixel = 0
	progressBar.ZIndex = 203
	Instance.new("UICorner", progressBar).CornerRadius = UDim.new(1, 0)

	local progressGrad = Instance.new("UIGradient", progressBar)
	progressGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 20, 25)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 0, 0))
	})

	table.insert(ActiveNotifications, 1, notifHolder)
	UpdateNotifications()

	local dismissed = false
	local function DismissNotif()
		if dismissed then return end
		dismissed = true

		for i, v in ipairs(ActiveNotifications) do
			if v == notifHolder then
				table.remove(ActiveNotifications, i)
				break
			end
		end
		UpdateNotifications()

		local slideOut = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		TweenService:Create(notifHolder, slideOut, {Position = UDim2.new(1, 360, notifHolder.Position.Y.Scale, notifHolder.Position.Y.Offset)}):Play()
		TweenService:Create(notifCard, slideOut, {BackgroundTransparency = 1}):Play()
		task.delay(0.28, function()
			if notifHolder and notifHolder.Parent then
				notifHolder:Destroy()
			end
		end)
	end

	notifCloseBtn.MouseButton1Click:Connect(function() DismissNotif() end)

	local barTween = TweenService:Create(progressBar, TweenInfo.new(NOTIF_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 1, 0)})
	task.delay(0.1, function() barTween:Play() end)
	task.delay(NOTIF_DURATION + 0.1, function() DismissNotif() end)
end

-- ==================== NOTIFICAÇÃO 2 (DISCORD COM TÍTULO E SUBTÍTULO CENTRALIZADOS NA BARRA) ====================
local function CriarNotificacaoDiscord()
	local notifHolder = Instance.new("Frame", screenGui)
	notifHolder.Name = "NotifHolderDiscord"
	notifHolder.AnchorPoint = Vector2.new(1, 1)
	notifHolder.Size = UDim2.new(0, 330, 0, 96)
	notifHolder.Position = UDim2.new(1, 360, 1, -24)
	notifHolder.BackgroundTransparency = 1
	notifHolder.ZIndex = 200
	notifHolder.ClipsDescendants = false

	local notifCard = Instance.new("Frame", notifHolder)
	notifCard.Name = "NotifCard"
	notifCard.Size = UDim2.new(1, 0, 1, 0)
	notifCard.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	notifCard.BackgroundTransparency = 0.25
	notifCard.BorderSizePixel = 0
	notifCard.ZIndex = 201
	notifCard.ClipsDescendants = false
	Instance.new("UICorner", notifCard).CornerRadius = UDim.new(0, 16)

	local notifShadow = Instance.new("ImageLabel", notifCard)
	notifShadow.Name = "Shadow"
	notifShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	notifShadow.Position = UDim2.new(0.5, 0, 0.5, 4)
	notifShadow.Size = UDim2.new(1, 24, 1, 24)
	notifShadow.BackgroundTransparency = 1
	notifShadow.Image = "rbxassetid://5554831957"
	notifShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	notifShadow.ImageTransparency = 0.35
	notifShadow.ScaleType = Enum.ScaleType.Slice
	notifShadow.SliceCenter = Rect.new(36, 36, 114, 114)
	notifShadow.ZIndex = 200

	local accentBar = Instance.new("Frame", notifCard)
	accentBar.Size = UDim2.new(0, 4, 0, 52)
	accentBar.Position = UDim2.new(0, 14, 0.5, -26)
	accentBar.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	accentBar.BorderSizePixel = 0
	accentBar.ZIndex = 202
	Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

	local notifTitle = Instance.new("TextLabel", notifCard)
	notifTitle.Size = UDim2.new(1, -76, 0, 18)
	notifTitle.Position = UDim2.new(0, 26, 0.5, -19)
	notifTitle.BackgroundTransparency = 1
	notifTitle.Text = "DISCORD SERVER"
	notifTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
	notifTitle.Font = Enum.Font.GothamBold
	notifTitle.TextSize = 16
	notifTitle.TextXAlignment = Enum.TextXAlignment.Left
	notifTitle.ZIndex = 203

	local notifDesc = Instance.new("TextLabel", notifCard)
	notifDesc.Size = UDim2.new(1, -100, 0, 18)
	notifDesc.Position = UDim2.new(0, 26, 0.5, 1)
	notifDesc.BackgroundTransparency = 1
	notifDesc.Text = "https://discord.gg/rZuYzZ7zvt"
	notifDesc.TextColor3 = Color3.fromRGB(150, 150, 155)
	notifDesc.Font = Enum.Font.Gotham
	notifDesc.TextSize = 12
	notifDesc.TextXAlignment = Enum.TextXAlignment.Left
	notifDesc.TextYAlignment = Enum.TextYAlignment.Top
	notifDesc.TextWrapped = true
	notifDesc.ZIndex = 203

	local copyBtn = Instance.new("TextButton", notifCard)
	copyBtn.Size = UDim2.new(0, 70, 0, 24)
	copyBtn.AnchorPoint = Vector2.new(1, 1)
	copyBtn.Position = UDim2.new(1, -14, 1, -14)
	copyBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	copyBtn.Text = "COPY"
	copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	copyBtn.Font = Enum.Font.GothamBold
	copyBtn.TextSize = 12
	copyBtn.ZIndex = 205
	copyBtn.BorderSizePixel = 0
	Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)

	copyBtn.MouseButton1Click:Connect(function()
		PlayUI_Click()
		pcall(function()
			if setclipboard then
				setclipboard("https://discord.gg/rZuYzZ7zvt")
			end
		end)
		CriarNotificacaoLinkCopiado("LINK COPIED SUCCESSFULLY!", "rbxthumb://type=Asset&id=118293546444074&w=150&h=150")
	end)

	local notifCloseBtn = Instance.new("TextButton", notifCard)
	notifCloseBtn.Size = UDim2.new(0, 24, 0, 24)
	notifCloseBtn.Position = UDim2.new(1, -32, 0, 10)
	notifCloseBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
	notifCloseBtn.BackgroundTransparency = 0.2
	notifCloseBtn.Text = ""
	notifCloseBtn.ZIndex = 205
	notifCloseBtn.BorderSizePixel = 0
	Instance.new("UICorner", notifCloseBtn).CornerRadius = UDim.new(0, 6)

	local xStroke = Instance.new("UIStroke", notifCloseBtn)
	xStroke.Color = Color3.fromRGB(80, 80, 85)
	xStroke.Thickness = 1
	xStroke.Transparency = 0.5

	local xL1 = Instance.new("Frame", notifCloseBtn)
	xL1.AnchorPoint = Vector2.new(0.5, 0.5)
	xL1.Position = UDim2.new(0.5, 0, 0.5, 0)
	xL1.Size = UDim2.new(0, 10, 0, 1.5)
	xL1.Rotation = 45
	xL1.BackgroundColor3 = Color3.fromRGB(160, 160, 165)
	xL1.BorderSizePixel = 0
	xL1.ZIndex = 206
	Instance.new("UICorner", xL1).CornerRadius = UDim.new(1,0)
	local xL2 = Instance.new("Frame", notifCloseBtn)
	xL2.AnchorPoint = Vector2.new(0.5, 0.5)
	xL2.Position = UDim2.new(0.5, 0, 0.5, 0)
	xL2.Size = UDim2.new(0, 10, 0, 1.5)
	xL2.Rotation = -45
	xL2.BackgroundColor3 = Color3.fromRGB(160, 160, 165)
	xL2.BorderSizePixel = 0
	xL2.ZIndex = 206
	Instance.new("UICorner", xL2).CornerRadius = UDim.new(1,0)

	notifCloseBtn.MouseEnter:Connect(function()
		TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160, 20, 20)}):Play()
		TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
		TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
	end)
	notifCloseBtn.MouseLeave:Connect(function()
		TweenService:Create(notifCloseBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(35, 35, 38)}):Play()
		TweenService:Create(xL1, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160,160,165)}):Play()
		TweenService:Create(xL2, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(160,160,165)}):Play()
	end)

	local progressBg = Instance.new("Frame", notifCard)
	progressBg.Size = UDim2.new(1, -28, 0, 3)
	progressBg.Position = UDim2.new(0, 14, 1, -10)
	progressBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	progressBg.BorderSizePixel = 0
	progressBg.ZIndex = 202
	progressBg.ClipsDescendants = true
	Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)

	local progressBar = Instance.new("Frame", progressBg)
	progressBar.Size = UDim2.new(1, 0, 1, 0)
	progressBar.Position = UDim2.new(0, 0, 0, 0)
	progressBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	progressBar.BorderSizePixel = 0
	progressBar.ZIndex = 203
	Instance.new("UICorner", progressBar).CornerRadius = UDim.new(1, 0)

	local progressGrad = Instance.new("UIGradient", progressBar)
	progressGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(88, 101, 242)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 30, 100))
	})

	table.insert(ActiveNotifications, 1, notifHolder)
	UpdateNotifications()

	local dismissed = false
	local function DismissNotif()
		if dismissed then return end
		dismissed = true

		for i, v in ipairs(ActiveNotifications) do
			if v == notifHolder then
				table.remove(ActiveNotifications, i)
				break
			end
		end
		UpdateNotifications()

		local slideOut = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		TweenService:Create(notifHolder, slideOut, {Position = UDim2.new(1, 360, notifHolder.Position.Y.Scale, notifHolder.Position.Y.Offset)}):Play()
		TweenService:Create(notifCard, slideOut, {BackgroundTransparency = 1}):Play()
		task.delay(0.28, function()
			if notifHolder and notifHolder.Parent then
				notifHolder:Destroy()
			end
		end)
	end

	notifCloseBtn.MouseButton1Click:Connect(function() DismissNotif() end)

	local barTween = TweenService:Create(progressBar, TweenInfo.new(NOTIF_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 1, 0)})
	task.delay(0.1, function() barTween:Play() end)
	task.delay(NOTIF_DURATION + 0.1, function() DismissNotif() end)
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
					child.Size = UDim2.new(1, -10, 0, 0)
					child.BackgroundTransparency = 1
					local t = child:FindFirstChild("Title")
					local d = child:FindFirstChild("Description")
					if t then t.TextTransparency = 1 end
					if d then d.TextTransparency = 1 end
					task.delay((itemIndex - 1) * 0.02, function()
						if not child or not child.Parent then return end
						TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
							Size = UDim2.new(1, -10, 0, 60), BackgroundTransparency = 0.45
						}):Play()
						if t then TweenService:Create(t, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
						if d then TweenService:Create(d, TweenInfo.new(0.15), {TextTransparency = 0}):Play() end
					end)
				end
			end
		end
	end
	task.delay(0.05, function() pcall(UpdateCanvasSize) end)
end

-- CORREÇÃO 1: UpdateActiveBarPosition corrigida.
-- O problema era que AbsolutePosition só é calculado após o layout ser aplicado.
-- Quando chamado sem animação (animar=false) no momento em que a UI abre,
-- o frame pode ainda não ter posição absoluta correta.
-- Solução: aguardar um frame (RunService.RenderStepped) antes de calcular
-- quando animar=false para garantir que o layout já foi computado.
local function UpdateActiveBarPosition(animar)
	local targetBtn = tabButtons[activeTab]
	if not targetBtn or not sharedActiveBar.Visible then return end

	local function aplicar()
		if not targetBtn or not targetBtn.Parent then return end
		local targetCenterY = targetBtn.AbsolutePosition.Y + (targetBtn.AbsoluteSize.Y / 2)
		local parentTopY = LeftPanel.AbsolutePosition.Y
		local targetYPos = targetCenterY - parentTopY

		if animar then
			TweenService:Create(sharedActiveBar, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 11, 0, targetYPos)
			}):Play()
		else
			sharedActiveBar.Position = UDim2.new(0, 11, 0, targetYPos)
		end
	end

	if animar then
		aplicar()
	else
		-- Aguarda o próximo frame para garantir layout calculado
		task.defer(aplicar)
	end
end

TabsContainer:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	UpdateActiveBarPosition(false)
end)

local function selectTab(tabName)
	activeTab = tabName
	local targetBtn = tabButtons[tabName]

	for name, btn in pairs(tabButtons) do
		local label = btn:FindFirstChild("Label")
		local iconContainer = btn:FindFirstChild("Icon")
		local animSpeed = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

		if name == tabName then
			TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(45, 10, 15), BackgroundTransparency = 0.5}):Play()
			if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end
			if iconContainer and iconContainer:FindFirstChild("AccentImage") then
				TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
			end
			originalTrans[btn] = { BackgroundTransparency = 0.5, TextTransparency = 0 }
		else
			TweenService:Create(btn, animSpeed, {BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 1}):Play()
			if label then TweenService:Create(label, animSpeed, {TextColor3 = Color3.fromRGB(150, 150, 150)}):Play() end
			if iconContainer and iconContainer:FindFirstChild("AccentImage") then
				TweenService:Create(iconContainer.AccentImage, animSpeed, {ImageColor3 = Color3.fromRGB(150, 150, 150)}):Play()
			end
			originalTrans[btn] = { BackgroundTransparency = 1, TextTransparency = 0 }
		end
	end

	if targetBtn then
		sharedActiveBar.Visible = true
		UpdateActiveBarPosition(true)
	end

	togglesContainer.CanvasPosition = Vector2.new(0, 0)
	searchTextBox.Text = ""
	filterToggles(tabName, "")
end

local function createTabBtn(tabName)
	local tabBtn = Instance.new("TextButton", TabsContainer)
	tabBtn.Name = tabName .. "TabBtn"
	tabBtn.Size = UDim2.new(1, -16, 0, 36)
	tabBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	tabBtn.BackgroundTransparency = 1
	tabBtn.Text = ""
	tabBtn.ZIndex = 11
	Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 8)

	local iconContainer = Instance.new("Frame", tabBtn)
	iconContainer.Name = "Icon"
	iconContainer.Size = UDim2.new(0, 14, 0, 14)
	iconContainer.Position = UDim2.new(0, 14, 0.5, -7)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 12
	local imageLabel = Instance.new("ImageLabel", iconContainer)
	imageLabel.Name = "AccentImage"
	imageLabel.Size = UDim2.new(1, 0, 1, 0)
	imageLabel.BackgroundTransparency = 1
	imageLabel.ZIndex = 13
	imageLabel.ImageColor3 = Color3.fromRGB(150, 150, 150)

	if tabName == "Player" then imageLabel.Image = "rbxthumb://type=Asset&id=71234705040146&w=150&h=150"
	elseif tabName == "Teleports" then imageLabel.Image = "rbxthumb://type=Asset&id=131082536388353&w=150&h=150"
	elseif tabName == "Settings" then imageLabel.Image = "rbxthumb://type=Asset&id=88409765080516&w=150&h=150"
	elseif tabName == "Visuals" then imageLabel.Image = "rbxthumb://type=Asset&id=97681798175944&w=150&h=150"
	elseif tabName == "Combat" then imageLabel.Image = "rbxthumb://type=Asset&id=105897102093789&w=150&h=150" end

	local tabLabel = Instance.new("TextLabel", tabBtn)
	tabLabel.Name = "Label"
	tabLabel.Size = UDim2.new(1, -42, 1, 0)
	tabLabel.Position = UDim2.new(0, 38, 0, 0)
	tabLabel.BackgroundTransparency = 1
	tabLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	tabLabel.Font = Enum.Font.GothamMedium
	tabLabel.TextSize = 13
	tabLabel.TextXAlignment = Enum.TextXAlignment.Left
	tabLabel.Text = UI_TEXT.Tabs[tabName] or tabName
	tabLabel.ZIndex = 12

	tabBtn.MouseButton1Click:Connect(function() selectTab(tabName) end)
	tabButtons[tabName] = tabBtn
end

local function createToggle(parent, configKey, tabCategory)
	local toggleFrame = Instance.new("Frame")
	toggleFrame.Name = configKey
	toggleFrame.Size = UDim2.new(1, -10, 0, 60)
	toggleFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
	toggleFrame.BackgroundTransparency = 0.45
	toggleFrame.ZIndex = 11
	toggleFrame.ClipsDescendants = true
	toggleFrame:SetAttribute("Tab", tabCategory)
	toggleFrame:SetAttribute("ConfigKey", configKey)
	toggleFrame.Parent = parent

	local toggleScale = Instance.new("UIScale", toggleFrame)
	toggleScale.Scale = 1

	Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 8)

	local optData = UI_TEXT.Options[configKey]
	local titleLabel = Instance.new("TextLabel", toggleFrame)
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(0.7, 0, 0, 18)
	titleLabel.Position = UDim2.new(0, 12, 0, 9)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = optData and optData.Title or configKey
	titleLabel.ZIndex = 11

	local descLabel = Instance.new("TextLabel", toggleFrame)
	descLabel.Name = "Description"
	descLabel.Size = UDim2.new(0.7, 0, 0, 28)
	descLabel.Position = UDim2.new(0, 12, 0, 28)
	descLabel.BackgroundTransparency = 1
	descLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 10.5
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextWrapped = true
	descLabel.Text = optData and optData.Desc or ""
	descLabel.ZIndex = 11

	local switchTrack = Instance.new("Frame", toggleFrame)
	switchTrack.Size = UDim2.new(0, 48, 0, 24)
	switchTrack.Position = UDim2.new(1, -54, 0.5, -12)
	switchTrack.BackgroundColor3 = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
	switchTrack.ZIndex = 11
	Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)

	local switchCircle = Instance.new("Frame", switchTrack)
	switchCircle.Size = UDim2.new(0, 18, 0, 18)
	switchCircle.Position = Configs[configKey] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
	switchCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	switchCircle.ZIndex = 12
	Instance.new("UICorner", switchCircle).CornerRadius = UDim.new(1, 0)

	local triggerBtn = Instance.new("TextButton", toggleFrame)
	triggerBtn.Size = UDim2.new(1, 0, 1, 0)
	triggerBtn.BackgroundTransparency = 1
	triggerBtn.Text = ""
	triggerBtn.ZIndex = 13

	triggerBtn.MouseButton1Click:Connect(function()
		PlayUI_Click()
		Configs[configKey] = not Configs[configKey]
		local targetPos   = Configs[configKey] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
		local targetColor = Configs[configKey] and Color3.fromHex("#8B0000") or Color3.fromRGB(30, 30, 30)
		local anim = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(switchCircle, anim, {Position = targetPos}):Play()
		TweenService:Create(switchTrack, anim, {BackgroundColor3 = targetColor}):Play()

		toggleScale.Scale = 0.96
		TweenService:Create(toggleScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end)
end

searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
	filterToggles(activeTab, searchTextBox.Text)
end)

ExpandBtn.MouseButton1Click:Connect(function()
	PlayUI_Click()
	isExpanded = not isExpanded
	local newSize = isExpanded and UDim2.new(0, 800, 0, 480) or UDim2.new(0, 640, 0, 360)
	TweenService:Create(mainWrapper, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = newSize}):Play()
end)

SetUIState = function(newState)
	if UIState == newState or UIState == "OPENING" or UIState == "CLOSING" then return end

	UIState = (newState == "OPEN" and "OPENING") or (newState == "MINIMIZED" and "CLOSING") or (newState == "CLOSED" and "CLOSING") or newState
	local tempoAnim = 0.25
	local windowAnim = TweenInfo.new(tempoAnim, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	if newState == "OPEN" then
		mainWrapper.Visible = true
		mainWrapper.Size = UDim2.new(0, 480, 0, 260)
		AplicarFadeSincronizado(mainWrapper, true, 0)
		AplicarFadeSincronizado(mainWrapper, false, tempoAnim)

		local openTween = TweenService:Create(mainWrapper, windowAnim, {Size = isExpanded and UDim2.new(0, 800, 0, 480) or UDim2.new(0, 640, 0, 360)})
		openTween:Play()
		openTween.Completed:Connect(function()
			UIState = "OPEN"
			selectTab("Player")
			filterToggles(activeTab, searchTextBox.Text)
			UpdateActiveBarPosition(false)
		end)

	elseif newState == "MINIMIZED" or newState == "CLOSED" then
		AplicarFadeSincronizado(mainWrapper, true, tempoAnim)
		local closeTween = TweenService:Create(mainWrapper, windowAnim, {Size = UDim2.new(0, 480, 0, 260)})
		closeTween:Play()

		closeTween.Completed:Connect(function()
			mainWrapper.Visible = false
			UIState = newState
		end)
	end
end

-- CORREÇÃO 5: Click flash nos botões do topo.
-- Função utilitária que aplica flash rápido de ImageColor3 sem interferir
-- nas conexões de hover já existentes. Usa reversão automática (Reverses=true).
local function AplicarClickFlash(btn)
	btn.MouseButton1Click:Connect(function()
		-- Flash rápido: vai para branco e volta automaticamente
		local flashInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0)
		TweenService:Create(btn, flashInfo, {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end)
end

MinimizeBtn.MouseButton1Click:Connect(function()
	PlayUI_Click()
	SetUIState("MINIMIZED")
end)

-- ==================== CONFIRMAÇÃO DE FECHAMENTO COM DESFOQUE INTENSO ====================
local function AlternarConfirmacao(exibir)
	isConfirmOpen = exibir
	local tempoAnim = 0.25

	if exibir then
		mainWrapper.Visible = false
		FloatBtn.Visible = false
		confirmOverlay.Visible = true

		TweenService:Create(confirmBlur, TweenInfo.new(tempoAnim, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 28}):Play()

		confirmCard.Size = UDim2.new(0, 280, 0, 115)
		local cardScale = Instance.new("UIScale", confirmCard)
		cardScale.Scale = 0.88
		TweenService:Create(cardScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		AplicarFadeSincronizado(confirmCard, false, tempoAnim)

	else
		TweenService:Create(confirmBlur, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = 0}):Play()
		AplicarFadeSincronizado(confirmCard, true, tempoAnim)
		local sc = confirmCard:FindFirstChildOfClass("UIScale")
		if sc then
			TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.88}):Play()
		end
		task.delay(tempoAnim + 0.05, function()
			if not isConfirmOpen then
				confirmOverlay.Visible = false
				local sc2 = confirmCard:FindFirstChildOfClass("UIScale")
				if sc2 then sc2:Destroy() end

				if UIState == "OPEN" then
					mainWrapper.Visible = true
				end
				FloatBtn.Visible = true
			end
		end)
	end
end

CloseBtn.MouseButton1Click:Connect(function()
	PlayUI_Click()
	AlternarConfirmacao(true)
end)

btnNo.MouseButton1Click:Connect(function() AlternarConfirmacao(false) end)

btnYes.MouseButton1Click:Connect(function()
	local syncTime = 0.2
	TweenService:Create(confirmBlur, TweenInfo.new(syncTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = 0}):Play()
	AplicarFadeSincronizado(confirmCard, true, syncTime)
	task.wait(syncTime)
	screenGui:Destroy()
end)

-- Hover nos botões do topo (mantido igual ao original)
local function AplicarEfeitoFisicoBotao(btn, hoverColor)
	btn.MouseEnter:Connect(function()
		if UIState ~= "OPEN" then return end
		TweenService:Create(btn, TweenInfo.new(0.15), {ImageColor3 = hoverColor}):Play()
	end)
	btn.MouseLeave:Connect(function()
		if UIState ~= "OPEN" then return end
		TweenService:Create(btn, TweenInfo.new(0.15), {ImageColor3 = TOP_BTN_COLOR}):Play()
	end)
end

AplicarEfeitoFisicoBotao(MinimizeBtn, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(ExpandBtn, Color3.fromRGB(255, 255, 255))
AplicarEfeitoFisicoBotao(CloseBtn, Color3.fromRGB(255, 60, 60))

-- CORREÇÃO 5: Aplicar click flash nos três botões do topo
AplicarClickFlash(MinimizeBtn)
AplicarClickFlash(ExpandBtn)
AplicarClickFlash(CloseBtn)

createTabBtn("Player")
createTabBtn("Combat")
createTabBtn("Visuals")
createTabBtn("Teleports")
createTabBtn("Settings")

createToggle(togglesContainer, "Speed",       "Player")
createToggle(togglesContainer, "AntiFling",   "Player")
createToggle(togglesContainer, "AutoShoot",   "Combat")
createToggle(togglesContainer, "Reach",       "Combat")
createToggle(togglesContainer, "ESP",         "Visuals")
createToggle(togglesContainer, "TpToGun",     "Teleports")
createToggle(togglesContainer, "SafeSpot",    "Teleports")
createToggle(togglesContainer, "AutoCollect", "Settings")
createToggle(togglesContainer, "ChatRoles",   "Settings")

-- ==================== ANIMAÇÃO DE INTRODUÇÃO ====================
local function ExecutarIntroAkat()
	local Blur = Instance.new("BlurEffect"); Blur.Size = 0; Blur.Parent = Lighting
	local IntroFrame = Instance.new("Frame", screenGui); IntroFrame.Size = UDim2.new(1, 0, 1, 0); IntroFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0); IntroFrame.BackgroundTransparency = 1; IntroFrame.ZIndex = 500
	local MaskContainer = Instance.new("Frame", IntroFrame); MaskContainer.AnchorPoint = Vector2.new(0.5, 0.5); MaskContainer.Position = UDim2.new(0.5, 0, 0.5, -10); MaskContainer.Size = UDim2.new(0, 420, 0, 40); MaskContainer.BackgroundTransparency = 1; MaskContainer.ClipsDescendants = true; MaskContainer.ZIndex = 501
	local IntroText = Instance.new("TextLabel", MaskContainer); IntroText.Size = UDim2.new(1, 0, 1, 0); IntroText.Position = UDim2.new(0, 0, 1, 0); IntroText.BackgroundTransparency = 1; IntroText.Font = Enum.Font.GothamBold; IntroText.TextSize = 26; IntroText.RichText = true; IntroText.Text = UI_TEXT.Intro; IntroText.ZIndex = 502
	local IntroLine = Instance.new("Frame", IntroFrame); IntroLine.AnchorPoint = Vector2.new(0.5, 0.5); IntroLine.Position = UDim2.new(0.5, 0, 0.5, 16); IntroLine.Size = UDim2.new(0, 0, 0, 2); IntroLine.BackgroundColor3 = Color3.fromHex("#8B0000"); IntroLine.BorderSizePixel = 0; IntroLine.BackgroundTransparency = 1; IntroLine.ZIndex = 503; Instance.new("UICorner", IntroLine).CornerRadius = UDim.new(1, 0)

	TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.05}):Play()
	TweenService:Create(Blur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 24}):Play(); task.wait(0.1)
	TweenService:Create(IntroText, TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play(); task.wait(0.2)
	TweenService:Create(IntroLine, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(0, 260, 0, 2)}):Play(); task.wait(1.6)
	TweenService:Create(IntroText, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
	TweenService:Create(IntroLine, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play(); task.wait(0.3)
	TweenService:Create(IntroFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Blur, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play(); task.wait(0.3)

	RegistrarTransparencias(mainWrapper)
	for _, item in ipairs(mainWrapper:GetDescendants()) do RegistrarTransparencias(item) end

	mainWrapper.Visible = true
	FloatBtn.Visible = true
	UIState = "OPEN"
	local MainScale = Instance.new("UIScale", mainWrapper); MainScale.Scale = 0.85
	AplicarFadeSincronizado(mainWrapper, true, 0)
	AplicarFadeSincronizado(mainWrapper, false, 0.35)

	local openScale = TweenService:Create(MainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
	openScale:Play()

	FloatBtn.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(FloatBtn, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 44, 0, 44)}):Play()

	selectTab("Player")

	CriarNotificacao(
		"AKATSUKI SCRIPTS",
		"MM2 Script carregado com sucesso. Bem-vindo, " .. player.DisplayName .. "."
	)

	task.wait(0.8)
	CriarNotificacaoDiscord()

	openScale.Completed:Connect(function()
		selectTab("Player")
		MainScale:Destroy()
		IntroFrame:Destroy()
		Blur:Destroy()
	end)
end

ExecutarIntroAkat()
