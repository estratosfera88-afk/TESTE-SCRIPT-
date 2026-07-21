--// =====================================================================
--//  PARTE 2: LÓGICA E SISTEMAS - AKAT EDITION
--// =====================================================================

--// ANTI-BAN / ANTI-KICK SYSTEM
local AntiBanEnabled = true

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

if AntiBanEnabled then
    pcall(function()
        local oldKick = LocalPlayer.Kick
        LocalPlayer.Kick = function(self, reason)
            warn("[ANTI-KICK] Tentativa bloqueada: " .. tostring(reason or "Sem motivo"))
            return nil
        end

        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        setreadonly(mt, false)

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if self == LocalPlayer and (method == "Kick" or method == "kick") then
                warn("[ANTI-KICK] Namecall bloqueado!")
                return nil
            end
            return oldNamecall(self, ...)
        end)

        setreadonly(mt, true)
    end)
    print("✅ Anti-Ban / Anti-Kick carregado com sucesso")
end

task.wait(0.1)

--// SERVICES & ESTADO GLOBAL
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera

_G.AkatHub = _G.AkatHub or {}
local Akat = _G.AkatHub

-- Configurações padrão da Lógica
Akat.Aimbot = Akat.Aimbot or false
Akat.AimbotFix = Akat.AimbotFix or false
Akat.AimbotFixEnabled = Akat.AimbotFixEnabled or false
Akat.LockedTarget = Akat.LockedTarget or nil
Akat.AimPart = Akat.AimPart or "Head"

Akat.ESP = Akat.ESP or false
Akat.Names = Akat.Names or false
Akat.DistanceESP = Akat.DistanceESP or false
Akat.TracerESP = Akat.TracerESP or false
Akat.HealthESP = Akat.HealthESP or false
Akat.TeamCheck = Akat.TeamCheck or false
Akat.WallCheck = Akat.WallCheck or true
Akat.AimSmoothness = Akat.AimSmoothness or 4

Akat.FOVCircle = Akat.FOVCircle or false
Akat.FOVRadius = Akat.FOVRadius or 150
Akat.FOVThickness = Akat.FOVThickness or 4
Akat.FOVTransparency = Akat.FOVTransparency or 0
Akat.FOVColor = Akat.FOVColor or Color3.fromRGB(255,0,0)
Akat.FOVRainbow = Akat.FOVRainbow or false

Akat.AntiLag = Akat.AntiLag or false
Akat.ShowFPS = Akat.ShowFPS or false
Akat.RedMode = Akat.RedMode or false
Akat.TargetFPS = Akat.TargetFPS or 60

local OriginalAutoRotate = true
local MAX_LOCK_DISTANCE = 300
local ESP_MAX_DISTANCE = 500

--// COPIAR DISCORD
local function CopiarLinkDiscord()
    local link = "https://discord.gg/rZuYzZ7zvt"
    if setclipboard then
        pcall(setclipboard, link)
    elseif toclipboard then
        pcall(toclipboard, link)
    elseif syn and syn.write_clipboard then
        pcall(syn.write_clipboard, link)
    end
end

--// LÓGICA DO AIMBOT
local function GetTargetPart(Character)
    if Akat.AimPart == "Head" then
        return Character:FindFirstChild("Head")
    elseif Akat.AimPart == "Body" then
        return Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("UpperTorso") or Character:FindFirstChild("Torso")
    end
    return Character:FindFirstChild("Head")
end

local function GetClosestPlayer()
    local ClosestPlayer = nil
    local shortestDistance = MAX_LOCK_DISTANCE
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    for _, v in ipairs(Players:GetPlayers()) do
        if v == LocalPlayer or (Akat.TeamCheck and v.Team == LocalPlayer.Team) then continue end
        local Char = v.Character
        if not Char then continue end
        local Hum = Char:FindFirstChildOfClass("Humanoid")
        if not Hum or Hum.Health <= 0 then continue end
        local Root = Char:FindFirstChild("HumanoidRootPart")
        if not Root then continue end

        local distance = (Root.Position - myRoot.Position).Magnitude
        if distance < shortestDistance then
            shortestDistance = distance
            ClosestPlayer = v
        end
    end
    return ClosestPlayer
end

local function ShouldReleaseTarget()
    if not Akat.LockedTarget or not Akat.LockedTarget.Character then return true end
    local Hum = Akat.LockedTarget.Character:FindFirstChildOfClass("Humanoid")
    if not Hum or Hum.Health <= 0 then return true end

    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot = Akat.LockedTarget.Character:FindFirstChild("HumanoidRootPart")
    if myRoot and targetRoot and (targetRoot.Position - myRoot.Position).Magnitude > 150 then
        return true
    end
    return false
end

function Akat.ApplyCameraFix()
    if not LocalPlayer.Character then return end
    local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if Humanoid then
        OriginalAutoRotate = Humanoid.AutoRotate
        Humanoid.AutoRotate = false
    end
end

function Akat.RemoveCameraFix()
    if not LocalPlayer.Character then return end
    local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if Humanoid then
        Humanoid.AutoRotate = OriginalAutoRotate
    end
end

local function ToggleAimbotFix(active)
    Akat.AimbotFix = active
    if active then
        Akat.ApplyCameraFix()
        if Akat.ToggleButton then
            Akat.ToggleButton.Text = "ON"
            TweenService:Create(Akat.ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(180,0,0)}):Play()
        end
    else
        Akat.RemoveCameraFix()
        Akat.LockedTarget = nil
        if Akat.ToggleButton then
            Akat.ToggleButton.Text = "OFF"
            TweenService:Create(Akat.ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20,20,20)}):Play()
        end
    end
end

if Akat.ToggleButton then
    Akat.ToggleButton.MouseButton1Click:Connect(function()
        ToggleAimbotFix(not Akat.AimbotFix)
    end)
end

local function GetClosestPlayerForAimbot()
    local Closest, ClosestDistance = nil, math.huge
    local Center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for _, v in ipairs(Players:GetPlayers()) do
        if v == LocalPlayer or (Akat.TeamCheck and v.Team == LocalPlayer.Team) then continue end
        local Char = v.Character
        if not Char then continue end

        local Hum = Char:FindFirstChildOfClass("Humanoid")
        if not Hum or Hum.Health <= 0 then continue end

        local TargetPart = GetTargetPart(Char)
        if not TargetPart then continue end

        local Pos, Visible = Camera:WorldToViewportPoint(TargetPart.Position)
        if not Visible or Pos.Z <= 0 then continue end

        if Akat.WallCheck then
            local Params = RaycastParams.new()
            Params.FilterType = Enum.RaycastFilterType.Blacklist
            Params.FilterDescendantsInstances = {LocalPlayer.Character}
            local Result = workspace:Raycast(Camera.CFrame.Position, TargetPart.Position - Camera.CFrame.Position, Params)
            if Result and not Result.Instance:IsDescendantOf(Char) then continue end
        end

        local Distance = (Vector2.new(Pos.X, Pos.Y) - Center).Magnitude
        if Distance > Akat.FOVRadius then continue end

        if Distance < ClosestDistance then
            ClosestDistance = Distance
            Closest = TargetPart
        end
    end
    return Closest
end

--// ANTI-LAG SYSTEM
function Akat.AplicarAntiLag(ativo)
    pcall(function()
        if ativo then
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1000000
            Lighting.Brightness = 1
            Lighting.ClockTime = 12
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
            Lighting.Technology = Enum.Technology.Compatibility

            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                elseif obj:IsA("BasePart") then
                    obj.Material = Enum.Material.Plastic
                    obj.Reflectance = 0
                end
            end
        else
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            Lighting.GlobalShadows = true
            Lighting.Technology = Enum.Technology.Future
        end
    end)
end

--// CORES DE VIDA
local function GetHealthColor(ratio)
    if ratio >= 0.5 then
        local t = (ratio - 0.5) / 0.5
        return Color3.fromRGB(math.floor(255 * (1 - t)), 255, 0)
    else
        local t = ratio / 0.5
        return Color3.fromRGB(255, math.floor(255 * t), 0)
    end
end

--// ESP SYSTEM
local Highlights = {}
local Drawings = {}
local TracerLines = {}
local HealthBars = {}
local MaxHealthCache = {}

local function CreateESP(Player)
    if Player == LocalPlayer then return end

    local Highlight = Instance.new("Highlight")
    Highlight.FillTransparency = 0.5
    Highlight.OutlineTransparency = 0
    Highlight.Enabled = false
    Highlight.Parent = Akat.uiParent or LocalPlayer:FindFirstChild("PlayerGui")
    Highlights[Player] = Highlight

    local Text = Drawing.new("Text")
    Text.Size = 13
    Text.Font = 2
    Text.Center = true
    Text.Outline = true
    Text.Visible = false
    Drawings[Player] = Text

    local Tracer = Drawing.new("Line")
    Tracer.Thickness = 1
    Tracer.Transparency = 1
    Tracer.Visible = false
    TracerLines[Player] = Tracer

    local HealthBarBG = Drawing.new("Square")
    HealthBarBG.Filled = true
    HealthBarBG.Color = Color3.fromRGB(0, 0, 0)
    HealthBarBG.Transparency = 1
    HealthBarBG.Visible = false

    local HealthBarInner = Drawing.new("Square")
    HealthBarInner.Filled = true
    HealthBarInner.Color = Color3.fromRGB(20, 20, 20)
    HealthBarInner.Transparency = 0.7
    HealthBarInner.Visible = false

    local HealthBarFill = Drawing.new("Square")
    HealthBarFill.Filled = true
    HealthBarFill.Color = Color3.fromRGB(0, 255, 0)
    HealthBarFill.Transparency = 1
    HealthBarFill.Visible = false

    HealthBars[Player] = {BG = HealthBarBG, Inner = HealthBarInner, Fill = HealthBarFill}
end

for _, p in ipairs(Players:GetPlayers()) do CreateESP(p) end
Players.PlayerAdded:Connect(CreateESP)

Players.PlayerRemoving:Connect(function(Player)
    if Highlights[Player] then Highlights[Player]:Destroy() Highlights[Player] = nil end
    if Drawings[Player] then Drawings[Player]:Remove() Drawings[Player] = nil end
    if TracerLines[Player] then TracerLines[Player]:Remove() TracerLines[Player] = nil end
    if HealthBars[Player] then
        HealthBars[Player].BG:Remove()
        HealthBars[Player].Inner:Remove()
        HealthBars[Player].Fill:Remove()
        HealthBars[Player] = nil
    end
    MaxHealthCache[Player] = nil
end)

--// LOOP PRINCIPAL (RENDERSTEPPED)
RunService.RenderStepped:Connect(function()
    -- Atualização do FOV Circle
    if Akat.Circle and Akat.Stroke then
        Akat.Circle.Position = UDim2.new(0, Camera.ViewportSize.X/2, 0, Camera.ViewportSize.Y/2)
        Akat.Circle.Size = UDim2.new(0, Akat.FOVRadius*2, 0, Akat.FOVRadius*2)
        Akat.Circle.Visible = Akat.FOVCircle
        Akat.Stroke.Thickness = Akat.FOVThickness
        Akat.Stroke.Transparency = Akat.FOVTransparency
        Akat.Stroke.Color = Akat.FOVRainbow and Color3.fromHSV(tick()%5/5, 1, 1) or Akat.FOVColor
    end

    -- Lógica de Mira
    if Akat.AimbotFix and Akat.AimbotFixEnabled then
        if ShouldReleaseTarget() then
            Akat.LockedTarget = GetClosestPlayer()
        end
        if not Akat.LockedTarget then
            Akat.LockedTarget = GetClosestPlayer()
        end

        if Akat.LockedTarget and Akat.LockedTarget.Character then
            local Target = GetTargetPart(Akat.LockedTarget.Character)
            if Target then
                local Root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if Root then
                    local LookPos = Vector3.new(Target.Position.X, Root.Position.Y, Target.Position.Z)
                    Root.CFrame = CFrame.lookAt(Root.Position, LookPos)
                end
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, Target.Position)
            end
        end
    elseif Akat.Aimbot then
        local Target = GetClosestPlayerForAimbot()
        if Target then
            local TargetCFrame = CFrame.lookAt(Camera.CFrame.Position, Target.Position)
            Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, 1 / Akat.AimSmoothness)
        end
    end

    -- ESP Loop
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for Player, Highlight in pairs(Highlights) do
        local Char = Player.Character
        local Text = Drawings[Player]
        local Tracer = TracerLines[Player]
        local HBar = HealthBars[Player]

        local function HideAll()
            if Highlight then Highlight.Enabled = false end
            if Text then Text.Visible = false end
            if Tracer then Tracer.Visible = false end
            if HBar then
                HBar.BG.Visible    = false
                HBar.Inner.Visible = false
                HBar.Fill.Visible  = false
            end
        end

        if not Char then HideAll() continue end

        local Hum  = Char:FindFirstChildOfClass("Humanoid")
        local Root = Char:FindFirstChild("HumanoidRootPart")
        local Head = Char:FindFirstChild("Head")

        if not Hum or Hum.Health <= 0 or not Root then HideAll() continue end

        if myRoot then
            local worldDist = (Root.Position - myRoot.Position).Magnitude
            if worldDist > ESP_MAX_DISTANCE then HideAll() continue end
        end

        local IsEnemy   = (Player.Team ~= LocalPlayer.Team)
        local TeamColor = IsEnemy and Color3.fromRGB(255,0,0) or Color3.fromRGB(0,255,0)

        Highlight.Adornee      = Char
        Highlight.FillColor    = TeamColor
        Highlight.OutlineColor = TeamColor
        Highlight.Enabled      = Akat.ESP

        local HeadWorld = Head and (Head.Position + Vector3.new(0, 2.8, 0)) or Root.Position
        local HeadPos   = Camera:WorldToViewportPoint(HeadWorld)
        local RootPos   = Camera:WorldToViewportPoint(Root.Position)
        local headX, headY = HeadPos.X, HeadPos.Y
        local behindCam = (HeadPos.Z < 0) or (RootPos.Z < 0)

        local Dist = math.floor((Camera.CFrame.Position - Root.Position).Magnitude)

        if Text then
            if (Akat.Names or Akat.DistanceESP) and not behindCam then
                local label = ""
                if Akat.Names then label = Player.Name end
                if Akat.DistanceESP then
                    label = label .. (label ~= "" and " " or "") .. "[" .. Dist .. "m]"
                end
                Text.Text     = label
                Text.Position = Vector2.new(headX, headY)
                Text.Color    = TeamColor
                Text.Visible  = true
            else
                Text.Visible = false
            end
        end

        if Tracer then
            if Akat.TracerESP and not behindCam then
                Tracer.From         = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                Tracer.To           = Vector2.new(RootPos.X, RootPos.Y)
                Tracer.Color        = TeamColor
                Tracer.Thickness    = 1
                Tracer.Transparency = 1
                Tracer.Visible      = true
            else
                Tracer.Visible = false
            end
        end

        if HBar then
            if Akat.HealthESP and not behindCam then
                local dist3d    = (Camera.CFrame.Position - Root.Position).Magnitude
                local barWidth  = math.clamp(120 - dist3d * 0.18, 36, 120)
                local barHeight = 2
                local border    = 1

                local curMax = Hum.MaxHealth
                local curHp  = Hum.Health

                if curMax and curMax == curMax and curMax > 0 then
                    if not MaxHealthCache[Player] or curMax > MaxHealthCache[Player] then
                        MaxHealthCache[Player] = curMax
                    end
                end

                local maxHp = MaxHealthCache[Player] or 100
                local hp    = (curHp and curHp == curHp and curHp >= 0) and curHp or maxHp
                if hp > maxHp then hp = maxHp end

                local healthRatio = math.clamp(hp / maxHp, 0, 1)
                local healthColor = GetHealthColor(healthRatio)

                local barX = headX - barWidth / 2
                local barY = headY - 15

                HBar.BG.Size     = Vector2.new(barWidth + border * 2, barHeight + border * 2)
                HBar.BG.Position = Vector2.new(barX - border, barY - border)
                HBar.BG.Visible  = true

                HBar.Inner.Size     = Vector2.new(barWidth, barHeight)
                HBar.Inner.Position = Vector2.new(barX, barY)
                HBar.Inner.Visible  = true

                local fillWidth = barWidth * healthRatio
                if fillWidth < 1 and healthRatio > 0 then fillWidth = 1 end
                HBar.Fill.Size     = Vector2.new(fillWidth, barHeight)
                HBar.Fill.Position = Vector2.new(barX, barY)
                HBar.Fill.Color    = healthColor
                HBar.Fill.Visible  = (healthRatio > 0)
            else
                HBar.BG.Visible    = false
                HBar.Inner.Visible = false
                HBar.Fill.Visible  = false
            end
        end
    end
end)

--// LOOP DO CONTADOR DE FPS
local lastTime = tick()
local frameCount = 0
local hue = 0

RunService.RenderStepped:Connect(function()
    if not Akat.ShowFPS or not Akat.FPSText then return end
    frameCount += 1
    local currentTime = tick()
    if currentTime - lastTime >= 0.1 then
        local fps = math.floor(frameCount / (currentTime - lastTime))
        Akat.FPSText.Text = "FPS: " .. tostring(fps)

        if Akat.RedMode then
            local t = tick() * 3
            local alpha = (math.sin(t) + 1) / 2
            local color = Color3.fromRGB(160, math.floor(40 * alpha), math.floor(40 * alpha))
            Akat.FPSText.TextColor3 = color
            if Akat.FPSStroke then Akat.FPSStroke.Color = color end
            if Akat.FPSGlow then Akat.FPSGlow.Color = color end
        else
            hue = (hue + 0.035) % 1
            local color = Color3.fromHSV(hue, 1, 1)
            Akat.FPSText.TextColor3 = color
            if Akat.FPSStroke then Akat.FPSStroke.Color = color end
            if Akat.FPSGlow then Akat.FPSGlow.Color = color end
        end

        frameCount = 0
        lastTime = currentTime
    end
end)

--// NOTIFICAÇÕES DE INICIALIZAÇÃO
task.spawn(function()
    if Akat.CriarNotificacao then
        Akat.CriarNotificacao("Aimbot Hub Universal", "AKAT Edition carregado com sucesso!", 6)
        task.wait(0.5)
        CopiarLinkDiscord()
        Akat.CriarNotificacao("Discord AKAT", "Link do Discord copiado com sucesso!", 6)
    end
end)

-- ==================== CARGA DINÂMICA DA INTERFACE ====================
local Link_Da_UI = "https://raw.githubusercontent.com/estratosfera88-afk/ui.lua.DO-AIMBOT-HUB/refs/heads/main/lua"

local Sucesso, Erro = pcall(function()
    loadstring(game:HttpGet(Link_Da_UI))()
end)

if not Sucesso then
    warn("[AKAT LOADER ERROR] Falha ao carregar a UI: ", Erro)
end
