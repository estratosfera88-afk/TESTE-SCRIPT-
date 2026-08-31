-- [[
--     AKAT BLOX FRUITS LOGIC [v2.0] — FIXED & IMPROVED
--     Correções: race condition de callbacks, busy loops, farm state,
--     noclip seguro, speed/jumppower, guards de executor, shutdown.
-- ]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- ==================== GUARD CONTRA DUPLICATA ====================
if _G.AkatLogicRunning then
	pcall(function()
		if _G.AkatCallbacks and _G.AkatCallbacks.ShutdownAll then
			_G.AkatCallbacks.ShutdownAll()
		end
	end)
	task.wait(0.1)
end
_G.AkatLogicRunning = true

-- ==================== FLAG DE VIDA ====================
local scriptAlive = true

-- ==================== CONFIGS ====================
local Configs = {
	AutoFarmLevel      = false,
	AutoFarmBoss       = false,
	SelectedBoss       = "Gorilla King",
	AutoCollectDrops   = false,
	AutoSkills         = false,
	AutoFarmMastery    = false,
	MasteryType        = "Fruit",
	SmartTargeting     = true,
	AutoFarmMaterials  = false,
	MaterialTarget     = "Bones",
	AutoFarmChests     = false,
	MobAura            = false,
	AuraRange          = 30,
	AutoQuest          = false,
	Speed              = false,
	SpeedValue         = 16,
	JumpPower          = false,
	JumpPowerValue     = 50,
	Debug              = false,
}
_G.Configs = Configs

-- ==================== ESTADO CENTRAL ====================
local FarmState = {
	Active = "None",  -- "None"|"Level"|"Boss"|"Mastery"|"Material"|"Chest"
	Status = "Idle",
}
_G.BFState      = FarmState
_G.BFFarmStatus = "Idle"

-- ==================== DEBUG ====================
local function Log(sys, msg)
	if Configs.Debug then
		warn(("[AKAT][%s] %s"):format(sys, tostring(msg)))
	end
end

local function SetStatus(s)
	FarmState.Status = s
	_G.BFFarmStatus  = s
	Log("Status", s)
end

-- ==================== GUARDS DE EXECUTOR ====================
-- Funções podem não existir em todos os executores
local function SafeFireTouchInterest(a, b, mode)
	if typeof(firetouchinterest) == "function" then
		pcall(firetouchinterest, a, b, mode)
	end
end

local function SafeFireProximityPrompt(pp)
	if typeof(fireproximityprompt) == "function" then
		pcall(fireproximityprompt, pp)
	elseif typeof(pp.Triggered) ~= "nil" then
		-- fallback sem executor privilegiado
		pcall(function() pp.Triggered:Fire(player) end)
	end
end

local function SafeSetClipboard(text)
	if typeof(setclipboard) == "function" then
		pcall(setclipboard, text)
	end
end

-- ==================== HELPERS DE PERSONAGEM ====================
local function GetRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHum()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function IsAlive()
	local h = GetHum()
	return h ~= nil and h.Health > 0
end

local function SafeTP(cf)
	if not IsAlive() then return false end
	local root = GetRoot()
	if not root then return false end
	local ok = pcall(function() root.CFrame = cf end)
	return ok
end

local function ApplyCharStats()
	local hum  = GetHum()
	local root = GetRoot()
	if hum then
		hum.WalkSpeed    = Configs.Speed     and Configs.SpeedValue    or 16
		hum.UseJumpPower = true
		hum.JumpPower    = Configs.JumpPower and Configs.JumpPowerValue or 50
	end
	if root then
		root.Anchored = false
	end
end

-- ==================== DADOS BLOX FRUITS ====================
local LEVEL_PROGRESSION = {
	{ min = 1,   max = 15,  island = "Starter Island",   questNPC = "Guard",              mob = "Bandit"       },
	{ min = 15,  max = 30,  island = "Middle Island",     questNPC = "Military Detective", mob = "Monkey"       },
	{ min = 30,  max = 60,  island = "Middle Island",     questNPC = "Military Detective", mob = "Gorilla"      },
	{ min = 60,  max = 90,  island = "Middle Island",     questNPC = "Military Detective", mob = "Gorilla King" },
	{ min = 90,  max = 120, island = "Middle Island",     questNPC = "Military Detective", mob = "Toga Warrior" },
	{ min = 120, max = 150, island = "Jungle",            questNPC = "Military Soldier",   mob = "Tribal Man"   },
	{ min = 150, max = 190, island = "Pirate Village",    questNPC = "Military Soldier",   mob = "Brute"        },
	{ min = 190, max = 250, island = "Desert",            questNPC = "Military Soldier",   mob = "Desert Bandits"},
	{ min = 250, max = 300, island = "Snow Island",       questNPC = "Military Soldier",   mob = "Snowman"      },
	{ min = 300, max = 375, island = "Marine Fortress",   questNPC = "Marine Captain",     mob = "Marine"       },
	{ min = 375, max = 450, island = "Sky Island",        questNPC = "Sky Bandit",         mob = "Sky Bandit"   },
	{ min = 450, max = 550, island = "Prison",            questNPC = "Warden",             mob = "Prisoner"     },
	{ min = 550, max = 650, island = "Colosseum",         questNPC = "Gladiator",          mob = "Gladiator"    },
	{ min = 650, max = 700, island = "Magma Village",     questNPC = "Hot Dog Man",        mob = "Magma Ninja"  },
	{ min = 700, max = 750, island = "Upper Skylands",    questNPC = "Skypiean",           mob = "Sky Castaway" },
}

local function GetLevel()
	local lv = 0
	pcall(function()
		local ls = player:FindFirstChild("leaderstats")
			or player:FindFirstChild("Leaderstats")
			or player:FindFirstChild("LeaderStats")
		if ls then
			local node = ls:FindFirstChild("Level") or ls:FindFirstChild("Lv")
			if node then lv = tonumber(node.Value) or 0 end
		end
	end)
	return lv
end

local function GetProgression(lv)
	local entry = LEVEL_PROGRESSION[1]
	for _, e in ipairs(LEVEL_PROGRESSION) do
		if lv >= e.min then entry = e end
	end
	return entry
end

-- ==================== SKILL COOLDOWNS ====================
local SkillCD = {}

local function CanUseSkill(name, cd)
	return (os.clock() - (SkillCD[name] or 0)) >= cd
end

local function UseSkill(name)
	SkillCD[name] = os.clock()
end

-- ==================== AUTO SKILLS ====================
local function UseAutoSkills()
	if not scriptAlive or not IsAlive() then return end
	local char = player.Character
	if not char then return end
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			local n  = tool.Name:lower()
			local cd = n:find("gun") or n:find("pistol") and 0.4 or 0.75
			if CanUseSkill(tool.Name, cd) then
				pcall(function() tool:Activate() end)
				UseSkill(tool.Name)
			end
		end
	end
end

-- ==================== ENCONTRAR NPC ====================
local function FindNPC(nameFilter, maxRange, smart)
	local root = GetRoot()
	if not root then return nil, nil end
	local best, bestD = nil, math.huge
	maxRange = maxRange or 5000
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj ~= player.Character then
			local hum = obj:FindFirstChildOfClass("Humanoid")
			local hrp = obj:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 then
				local nameOk = not nameFilter or nameFilter == ""
					or obj.Name:lower():find(nameFilter:lower(), 1, true) ~= nil
				if nameOk then
					local d = (root.Position - hrp.Position).Magnitude
					if d < maxRange and d < bestD then
						if smart then
							if (hum.Health / hum.MaxHealth) > 0.15 then
								best = obj; bestD = d
							end
						else
							best = obj; bestD = d
						end
					end
				end
			end
		end
	end
	return best, bestD
end

-- ==================== COLETAR DROPS ====================
local function CollectNearbyDrops(maxDist)
	maxDist = maxDist or 120
	local root = GetRoot()
	if not root then return end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and not obj.CanCollide then
			local n = obj.Name:lower()
			if n:find("drop") or n:find("fruit") or n:find("loot") or n:find("item") or n:find("chest") then
				local d = (root.Position - obj.Position).Magnitude
				if d < maxDist then
					SafeTP(CFrame.new(obj.Position + Vector3.new(0, 3, 0)))
					SafeFireTouchInterest(root, obj, 0)
					SafeFireTouchInterest(root, obj, 1)
				end
			end
		end
	end
end

-- ==================== MOB AURA LOOP ====================
local function MobAuraLoop()
	task.spawn(function()
		while scriptAlive do
			task.wait(0.18)
			if not Configs.MobAura then continue end
			if not IsAlive() then continue end
			local char = player.Character
			local root = GetRoot()
			if not char or not root then continue end
			local range = Configs.AuraRange or 30
			local found = false
			for _, obj in ipairs(workspace:GetDescendants()) do
				if not scriptAlive or not Configs.MobAura then break end
				if obj:IsA("Model") and obj ~= char then
					local hum = obj:FindFirstChildOfClass("Humanoid")
					local hrp = obj:FindFirstChild("HumanoidRootPart")
					if hum and hrp and hum.Health > 0 then
						local d = (root.Position - hrp.Position).Magnitude
						if d <= range then
							found = true
							-- Ataca via tool equipada
							for _, item in ipairs(char:GetChildren()) do
								if item:IsA("Tool") then
									local handle = item:FindFirstChild("Handle")
										or item:FindFirstChildOfClass("BasePart")
									if handle then
										SafeFireTouchInterest(hrp, handle, 0)
										SafeFireTouchInterest(hrp, handle, 1)
									end
									-- Ativa a tool também
									pcall(function() item:Activate() end)
									break
								end
							end
							-- Aproxima se estiver longe
							if d > range * 0.45 then
								SafeTP(hrp.CFrame * CFrame.new(0, 0, -3.5))
							end
						end
					end
				end
			end
			if not found then
				SetStatus("Mob Aura: Procurando NPCs")
			end
		end
	end)
end

-- ==================== QUEST HELPERS ====================
local function FindQuestNPC(name)
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name:lower():find(name:lower(), 1, true) then
			local hrp = obj:FindFirstChild("HumanoidRootPart")
				or obj:FindFirstChildOfClass("BasePart")
			if hrp then return hrp end
		end
	end
	return nil
end

local function TryQuestAction(npcPart, action)
	if not npcPart then return false end
	SafeTP(npcPart.CFrame * CFrame.new(0, 0, -5))
	task.wait(0.5)
	local done = false
	-- ProximityPrompt
	pcall(function()
		local parent = npcPart.Parent or npcPart
		for _, pp in ipairs(parent:GetDescendants()) do
			if pp:IsA("ProximityPrompt") then
				SafeFireProximityPrompt(pp)
				done = true
				break
			end
		end
	end)
	-- RemoteEvent fallback
	if not done then
		pcall(function()
			local qf = ReplicatedStorage:FindFirstChild("Quests") or ReplicatedStorage:FindFirstChild("Quest")
			if qf then
				local re = qf:FindFirstChild(action) or qf:FindFirstChildOfClass("RemoteEvent")
				if re then re:FireServer(); done = true end
			end
		end)
	end
	return done
end

-- ==================== LOOP: AUTO QUEST ====================
local function AutoQuestLoop()
	task.spawn(function()
		while scriptAlive do
			task.wait(0.4)
			if not Configs.AutoQuest then continue end
			if not IsAlive() then task.wait(2) continue end

			local lv    = GetLevel()
			local entry = GetProgression(lv)

			SetStatus("Quest: buscando " .. entry.questNPC)
			local npcPart = FindQuestNPC(entry.questNPC)
			if not npcPart then task.wait(2) continue end

			TryQuestAction(npcPart, "GetQuest")
			task.wait(1)

			SetStatus("Quest: indo para " .. entry.mob)
			local mob = FindNPC(entry.mob, 8000, false)
			if mob then
				local mhrp = mob:FindFirstChild("HumanoidRootPart")
				if mhrp then SafeTP(mhrp.CFrame * CFrame.new(0, 0, -4)) end
			end

			SetStatus("Quest: farmando " .. entry.mob)
			local start = os.clock()
			while scriptAlive and Configs.AutoQuest and (os.clock() - start) < 70 do
				task.wait(0.22)
				if not IsAlive() then break end
				if Configs.AutoSkills then UseAutoSkills() end
				local t, d = FindNPC(entry.mob, 5000, false)
				if t then
					local thrp = t:FindFirstChild("HumanoidRootPart")
					if thrp and d and d > 5 then
						SafeTP(thrp.CFrame * CFrame.new(0, 0, -4))
					end
				else
					task.wait(2)
				end
			end

			SetStatus("Quest: entregando")
			local npcPart2 = FindQuestNPC(entry.questNPC)
			TryQuestAction(npcPart2, "DeliverQuest")
			task.wait(1)
		end
	end)
end

-- ==================== LOOP: LEVEL FARM ====================
local function LevelFarmLoop()
	task.spawn(function()
		while scriptAlive do
			task.wait(0.28)
			if not Configs.AutoFarmLevel then continue end
			if FarmState.Active ~= "Level" then continue end
			if not IsAlive() then task.wait(2) continue end

			local lv    = GetLevel()
			local entry = GetProgression(lv)
			SetStatus("Level Farm — " .. entry.island .. " | Lv." .. lv)

			local mob, d = FindNPC(entry.mob, 8000, false)
			if not mob then
				SetStatus("Buscando: " .. entry.mob)
				task.wait(2)
				continue
			end
			local mhrp = mob:FindFirstChild("HumanoidRootPart")
			if not mhrp then continue end

			if d and d > 8 then
				SafeTP(mhrp.CFrame * CFrame.new(0, 0, -4.5))
				task.wait(0.25)
			end

			if Configs.AutoSkills then UseAutoSkills() end

			-- Verifica se o mob ainda está vivo
			local mhum = mob:FindFirstChildOfClass("Humanoid")
			if not mhum or mhum.Health <= 0 then continue end
		end
	end)
end

-- ==================== LOOP: BOSS FARM ====================
local function BossFarmLoop()
	task.spawn(function()
		while scriptAlive do
			task.wait(0.5)
			if not Configs.AutoFarmBoss then continue end
			if FarmState.Active ~= "Boss" then continue end
			if not IsAlive() then task.wait(2) continue end

			local bossName = Configs.SelectedBoss or "Gorilla King"
			SetStatus("Boss: buscando " .. bossName)

			local boss, d = FindNPC(bossName, 15000, false)
			if not boss then
				SetStatus("Boss: aguardando respawn — " .. bossName)
				task.wait(6)
				continue
			end

			local bhrp = boss:FindFirstChild("HumanoidRootPart")
			if not bhrp then task.wait(2) continue end

			SetStatus("Boss: viajando → " .. bossName)
			SafeTP(bhrp.CFrame * CFrame.new(0, 0, -6))
			task.wait(0.5)

			SetStatus("Boss: lutando — " .. bossName)
			local fightStart = os.clock()
			local MAX_FIGHT  = 150

			while scriptAlive and Configs.AutoFarmBoss and FarmState.Active == "Boss" do
				task.wait(0.2)
				if not IsAlive() then break end

				local bhum = boss:FindFirstChildOfClass("Humanoid")
				if not bhum or bhum.Health <= 0 then
					SetStatus("Boss: derrotado — " .. bossName)
					break
				end

				if bhrp and bhrp.Parent then
					local root = GetRoot()
					if root then
						local dist = (root.Position - bhrp.Position).Magnitude
						if dist > 14 then
							SafeTP(bhrp.CFrame * CFrame.new(0, 0, -6))
						end
					end
				end

				if Configs.AutoSkills then UseAutoSkills() end

				if (os.clock() - fightStart) > MAX_FIGHT then
					Log("Boss", "Timeout de luta — saindo")
					break
				end
			end

			if Configs.AutoCollectDrops then
				SetStatus("Boss: coletando drops")
				task.wait(0.6)
				CollectNearbyDrops(150)
			end

			-- Espera respawn
			SetStatus("Boss: aguardando respawn — " .. bossName)
			local waitStart = os.clock()
			while scriptAlive and Configs.AutoFarmBoss and FarmState.Active == "Boss" do
				task.wait(3)
				local b2 = FindNPC(bossName, 15000, false)
				if b2 then break end
				if (os.clock() - waitStart) > 360 then break end
			end
		end
	end)
end

-- ==================== LOOP: MASTERY FARM ====================
local function MasteryFarmLoop()
	task.spawn(function()
		while scriptAlive do
			task.wait(0.3)
			if not Configs.AutoFarmMastery then continue end
			if FarmState.Active ~= "Mastery" then continue end
			if not IsAlive() then task.wait(2) continue end

			local mType = Configs.MasteryType or "Fruit"
			SetStatus("Mastery Farm: " .. mType)

			local mob, d = FindNPC("", Configs.AuraRange * 4, Configs.SmartTargeting)
			if not mob then
				SetStatus("Mastery: buscando mobs")
				task.wait(1.5)
				continue
			end

			local mhrp = mob:FindFirstChild("HumanoidRootPart")
			if not mhrp then continue end

			if d and d > 7 then
				SafeTP(mhrp.CFrame * CFrame.new(0, 0, -4.5))
				task.wait(0.25)
			end

			SetStatus("Mastery: usando skills — " .. mType)
			if Configs.AutoSkills then
				UseAutoSkills()
				task.wait(0.25)
				UseAutoSkills()
			end

			local mhum = mob:FindFirstChildOfClass("Humanoid")
			if mhum and mhum.Health <= 0 then continue end
		end
	end)
end

-- ==================== LOOP: MATERIAL FARM ====================
local function MaterialFarmLoop()
	task.spawn(function()
		while scriptAlive do
			task.wait(0.32)
			if not Configs.AutoFarmMaterials then continue end
			if FarmState.Active ~= "Material" then continue end
			if not IsAlive() then task.wait(2) continue end

			local target = Configs.MaterialTarget or "Bones"
			SetStatus("Materials: " .. target)

			local mob, d = FindNPC("", 8000, false)
			if not mob then
				SetStatus("Materials: buscando mobs")
				task.wait(2)
				continue
			end

			local mhrp = mob:FindFirstChild("HumanoidRootPart")
			if not mhrp then continue end

			if d and d > 8 then
				SafeTP(mhrp.CFrame * CFrame.new(0, 0, -4))
				task.wait(0.25)
			end

			if Configs.AutoSkills then UseAutoSkills() end

			-- Coleta drops/bones no chão
			local root = GetRoot()
			if root then
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("BasePart") then
						local n = obj.Name:lower()
						local isLoot = n:find("bone") or n:find("material") or n:find("drop")
							or n:find("loot") or n:find("item") or n:find("fragment")
						if isLoot then
							local dist = (root.Position - obj.Position).Magnitude
							if dist < 40 then
								SafeTP(CFrame.new(obj.Position + Vector3.new(0, 3, 0)))
								SafeFireTouchInterest(root, obj, 0)
								SafeFireTouchInterest(root, obj, 1)
							end
						end
					end
				end
			end
		end
	end)
end

-- ==================== LOOP: CHEST FARM ====================
local function ChestFarmLoop()
	task.spawn(function()
		while scriptAlive do
			task.wait(0.5)
			if not Configs.AutoFarmChests then continue end
			if FarmState.Active ~= "Chest" then continue end
			if not IsAlive() then task.wait(2) continue end

			SetStatus("Baús: procurando")
			local root = GetRoot()
			if not root then continue end

			local chests = {}
			for _, obj in ipairs(workspace:GetDescendants()) do
				local n = obj.Name:lower()
				if n:find("chest") or n == "locker" or n:find("crate") then
					local part = (obj:IsA("BasePart") and obj)
						or obj:FindFirstChildOfClass("BasePart")
						or (obj:IsA("Model") and obj.PrimaryPart)
					if part then
						local dist = (root.Position - part.Position).Magnitude
						if dist < 4000 then
							table.insert(chests, { part = part, dist = dist })
						end
					end
				end
			end

			if #chests == 0 then
				SetStatus("Baús: nenhum encontrado")
				task.wait(4)
				continue
			end

			table.sort(chests, function(a, b) return a.dist < b.dist end)

			for _, cd in ipairs(chests) do
				if not scriptAlive or not Configs.AutoFarmChests or FarmState.Active ~= "Chest" then break end
				if not IsAlive() then break end
				local cp = cd.part
				if not cp or not cp.Parent then continue end

				SetStatus("Baús: coletando")
				SafeTP(CFrame.new(cp.Position + Vector3.new(0, 3.5, 0)))
				task.wait(0.3)

				local opened = false
				pcall(function()
					local parent = cp.Parent or cp
					for _, pp in ipairs(parent:GetDescendants()) do
						if pp:IsA("ProximityPrompt") then
							SafeFireProximityPrompt(pp)
							opened = true
							break
						end
					end
				end)
				if not opened then
					local r2 = GetRoot()
					if r2 then
						SafeFireTouchInterest(r2, cp, 0)
						SafeFireTouchInterest(r2, cp, 1)
					end
				end
				task.wait(0.4)
			end
		end
	end)
end

-- ==================== CONTROLE DE ESTADO ====================
local function SetActiveFarm(farmType)
	FarmState.Active = farmType
end

local function StopAllFarms()
	Configs.AutoFarmLevel     = false
	Configs.AutoFarmBoss      = false
	Configs.AutoFarmMastery   = false
	Configs.AutoFarmMaterials = false
	Configs.AutoFarmChests    = false
	FarmState.Active          = "None"
	SetStatus("Idle")
	pcall(ApplyCharStats)
end

-- ==================== HEARTBEAT — STATS DO PLAYER ====================
-- Aplica speed/jumppower somente quando não está em farm
local hbConn = RunService.Heartbeat:Connect(function()
	if not scriptAlive then return end
	if FarmState.Active == "None" then
		pcall(ApplyCharStats)
	end
end)

-- ==================== NOCLIP DURANTE FARM ====================
-- Aplica noclip somente quando algum farm está ativo, para evitar bugs de colisão
local steppedConn = RunService.Stepped:Connect(function()
	if not scriptAlive then return end
	if FarmState.Active ~= "None" or Configs.AutoQuest then
		pcall(function()
			local char = player.Character
			if not char then return end
			for _, p in ipairs(char:GetChildren()) do
				if p:IsA("BasePart") then
					p.CanCollide = false
				end
			end
		end)
	end
end)

-- ==================== INICIAR LOOPS ====================
MobAuraLoop()
AutoQuestLoop()
LevelFarmLoop()
BossFarmLoop()
MasteryFarmLoop()
MaterialFarmLoop()
ChestFarmLoop()

-- ==================== CICLO DE RESPAWN ====================
local charConn = player.CharacterAdded:Connect(function()
	SetStatus("Idle")
	task.wait(1.2)
	Log("Respawn", "Personagem carregado — retomando estado")
end)

-- ==================== SHUTDOWN ====================
local function FullShutdown()
	scriptAlive = false
	pcall(function() hbConn:Disconnect()      end)
	pcall(function() steppedConn:Disconnect() end)
	pcall(function() charConn:Disconnect()    end)
	StopAllFarms()
	pcall(function()
		local char = player.Character
		if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = false
			root.AssemblyLinearVelocity  = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		for _, p in ipairs(char:GetChildren()) do
			if p:IsA("BasePart") then p.CanCollide = true end
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed    = 16
			hum.UseJumpPower = true
			hum.JumpPower    = 50
		end
	end)
	_G.AkatLogicRunning = false
end

-- ==================== CALLBACKS PARA A UI ====================
-- CORREÇÃO: _G.AkatCallbacks definido ANTES de carregar a UI
-- para eliminar a race condition entre logic e ui.
_G.AkatCallbacks = {

	AutoFarmLevel = function(on)
		Configs.AutoFarmLevel = on == true
		if on then SetActiveFarm("Level")
		elseif FarmState.Active == "Level" then
			FarmState.Active = "None"; SetStatus("Idle")
		end
	end,

	AutoFarmBoss = function(on)
		Configs.AutoFarmBoss = on == true
		if on then SetActiveFarm("Boss")
		elseif FarmState.Active == "Boss" then
			FarmState.Active = "None"; SetStatus("Idle")
		end
	end,

	SelectedBoss = function(v)
		Configs.SelectedBoss = tostring(v)
	end,

	AutoCollectDrops = function(on)
		Configs.AutoCollectDrops = on == true
	end,

	AutoFarmMastery = function(on)
		Configs.AutoFarmMastery = on == true
		if on then SetActiveFarm("Mastery")
		elseif FarmState.Active == "Mastery" then
			FarmState.Active = "None"; SetStatus("Idle")
		end
	end,

	MasteryType = function(v)
		Configs.MasteryType = tostring(v)
	end,

	SmartTargeting = function(on)
		Configs.SmartTargeting = on == true
	end,

	AutoFarmMaterials = function(on)
		Configs.AutoFarmMaterials = on == true
		if on then SetActiveFarm("Material")
		elseif FarmState.Active == "Material" then
			FarmState.Active = "None"; SetStatus("Idle")
		end
	end,

	MaterialTarget = function(v)
		Configs.MaterialTarget = tostring(v)
	end,

	AutoFarmChests = function(on)
		Configs.AutoFarmChests = on == true
		if on then SetActiveFarm("Chest")
		elseif FarmState.Active == "Chest" then
			FarmState.Active = "None"; SetStatus("Idle")
		end
	end,

	MobAura = function(on)
		Configs.MobAura = on == true
	end,

	-- CORREÇÃO: slider chama com valor numérico
	AuraRange = function(v)
		if type(v) == "number" then
			Configs.AuraRange = math.clamp(math.floor(v + 0.5), 5, 100)
		end
	end,

	AutoQuest = function(on)
		Configs.AutoQuest = on == true
	end,

	AutoSkills = function(on)
		Configs.AutoSkills = on == true
	end,

	-- CORREÇÃO: Speed/JumpPower recebem o valor numérico do slider
	Speed = function(v)
		if type(v) == "number" then
			Configs.SpeedValue = math.clamp(math.floor(v + 0.5), 1, 500)
			Configs.Speed      = true
		else
			Configs.Speed = v == true
		end
		if FarmState.Active == "None" then pcall(ApplyCharStats) end
	end,

	JumpPower = function(v)
		if type(v) == "number" then
			Configs.JumpPowerValue = math.clamp(math.floor(v + 0.5), 1, 500)
			Configs.JumpPower      = true
		else
			Configs.JumpPower = v == true
		end
		if FarmState.Active == "None" then pcall(ApplyCharStats) end
	end,

	StopAllFarms = function()
		StopAllFarms()
	end,

	ShutdownAll = function()
		FullShutdown()
	end,
}

-- ==================== CARREGA UI APÓS CALLBACKS PRONTOS ====================
-- CORREÇÃO: a UI é carregada depois dos callbacks para eliminar race condition.
task.spawn(function()
	local UI_URL = "https://raw.githubusercontent.com/estratosfera88-afk/Ui-do-teste/refs/heads/main/ui.lua"

	local content
	local ok, err = pcall(function()
		content = game:HttpGet(UI_URL, true)
	end)

	if not ok or not content or content == "" then
		warn("[AKAT] HttpGet falhou: " .. tostring(err or "resposta vazia"))
		return
	end

	local fn, compErr = loadstring(content)
	if not fn then
		warn("[AKAT] loadstring falhou: " .. tostring(compErr))
		return
	end

	local runOk, runErr = pcall(fn)
	if not runOk then
		warn("[AKAT] Erro ao executar UI: " .. tostring(runErr))
	end
end)
