-- POTATO CONTROL: otimização visual local e Aim Help para o seu jogo.
-- Use este arquivo sozinho como LocalScript em StarterPlayerScripts.
-- CapsLock/Insert abre o painel; G alterna o Aim Help; Esc fecha o painel.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local INITIAL_SCAN_BATCH_SIZE = 300

local PC_ANTIGO = {
	DisableGlobalShadows = true,
	DisableLightShadows = true,
	DisablePostEffects = true,
	ReduceParticles = true,
	ParticleRateMultiplier = 0.2,
	ClearExistingParticles = true,
	DisableTrailsAndBeams = true,
	DisableAtmosphere = true,
	ReduceTerrainWaterEffects = true,
}

local EQUILIBRADO = {
	DisableGlobalShadows = false,
	DisableLightShadows = true,
	DisablePostEffects = true,
	ReduceParticles = true,
	ParticleRateMultiplier = 0.5,
	ClearExistingParticles = false,
	DisableTrailsAndBeams = false,
	DisableAtmosphere = false,
	ReduceTerrainWaterEffects = true,
}

local Config = {}
for key, value in pairs(PC_ANTIGO) do
	Config[key] = value
end

local DARK_COLORS = {
	background = Color3.fromRGB(12, 16, 24),
	panel = Color3.fromRGB(18, 24, 35),
	card = Color3.fromRGB(25, 33, 47),
	cardHover = Color3.fromRGB(32, 43, 60),
	accent = Color3.fromRGB(78, 190, 255),
	accentDark = Color3.fromRGB(24, 72, 105),
	text = Color3.fromRGB(239, 245, 255),
	muted = Color3.fromRGB(145, 160, 181),
	line = Color3.fromRGB(52, 66, 86),
}
local LIGHT_COLORS = {
	background = Color3.fromRGB(232, 238, 246),
	panel = Color3.fromRGB(246, 249, 253),
	card = Color3.fromRGB(224, 232, 242),
	cardHover = Color3.fromRGB(211, 222, 235),
	accent = Color3.fromRGB(0, 112, 178),
	accentDark = Color3.fromRGB(190, 224, 246),
	text = Color3.fromRGB(18, 29, 43),
	muted = Color3.fromRGB(72, 88, 107),
	line = Color3.fromRGB(177, 192, 210),
}
local COLORS = table.clone(DARK_COLORS)

local globalConnections = {}
local diagnosticEntries = {}
local MAX_DIAGNOSTIC_ENTRIES = 100
local FeatureModules = {}
local updateDiagnosticsPage
local shuttingDown = false
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(globalConnections, connection)
	return connection
end

local function logDiagnostic(message)
	local sanitized = tostring(message):gsub("[%c]", " "):sub(1, 180)
	local entry = os.date("%H:%M:%S") .. "  " .. sanitized
	table.insert(diagnosticEntries, entry)
	if #diagnosticEntries > MAX_DIAGNOSTIC_ENTRIES then
		table.remove(diagnosticEntries, 1)
	end
	if FeatureModules.Diagnostics then
		FeatureModules.Diagnostics.Update()
	end
end

local originals = setmetatable({}, { __mode = "k" })
local managed = setmetatable({}, { __mode = "k" })
local optimizationReady = false

local function setIfDifferent(instance, property, value)
	pcall(function()
		if instance[property] ~= value then
			instance[property] = value
		end
	end)
end

local function getOriginal(instance, property)
	local values = originals[instance]
	if not values then
		values = {}
		originals[instance] = values
	end

	if values[property] == nil then
		local ok, value = pcall(function()
			return instance[property]
		end)
		if not ok then
			return nil
		end
		values[property] = value
	end

	return values[property]
end

local function applyManaged(instance, property, enabled, optimizedValue)
	local original = getOriginal(instance, property)
	if original == nil then
		return
	end

	local target = original
	if enabled then
		target = optimizedValue
	end
	setIfDifferent(instance, property, target)
end

local function isRelevant(instance)
	return instance:IsA("ParticleEmitter")
		or instance:IsA("Trail")
		or instance:IsA("Beam")
		or instance:IsA("PostEffect")
		or instance:IsA("Atmosphere")
		or instance:IsA("Light")
end

local function applyInstance(instance, clearParticlesNow)
	if instance:IsA("ParticleEmitter") then
		local originalRate = getOriginal(instance, "Rate")
		if originalRate ~= nil then
			local targetRate = originalRate
			if Config.ReduceParticles then
				local multiplier = math.clamp(Config.ParticleRateMultiplier, 0, 1)
				targetRate = math.floor(originalRate * multiplier + 0.5)
			end
			setIfDifferent(instance, "Rate", targetRate)
		end

		if clearParticlesNow and Config.ReduceParticles and Config.ClearExistingParticles then
			pcall(function()
				instance:Clear()
			end)
		end
	end

	if instance:IsA("Trail") or instance:IsA("Beam") then
		applyManaged(instance, "Enabled", Config.DisableTrailsAndBeams, false)
	end

	if instance:IsA("PostEffect") then
		applyManaged(instance, "Enabled", Config.DisablePostEffects, false)
	end

	if instance:IsA("Atmosphere") then
		applyManaged(instance, "Density", Config.DisableAtmosphere, 0)
		applyManaged(instance, "Haze", Config.DisableAtmosphere, 0)
		applyManaged(instance, "Glare", Config.DisableAtmosphere, 0)
	end

	if instance:IsA("Light") then
		applyManaged(instance, "Shadows", Config.DisableLightShadows, false)
	end
end

local function applyGlobalSettings()
	applyManaged(Lighting, "GlobalShadows", Config.DisableGlobalShadows, false)

	local terrain = Workspace.Terrain
	applyManaged(terrain, "WaterWaveSize", Config.ReduceTerrainWaterEffects, 0)
	applyManaged(terrain, "WaterWaveSpeed", Config.ReduceTerrainWaterEffects, 0)
	applyManaged(terrain, "WaterReflectance", Config.ReduceTerrainWaterEffects, 0)
end

local function applyAll(clearParticlesNow)
	applyGlobalSettings()
	for instance in pairs(managed) do
		if instance.Parent then
			applyInstance(instance, clearParticlesNow)
		end
	end
end

local function register(instance)
	if managed[instance] or not isRelevant(instance) then
		return
	end
	managed[instance] = true
	if optimizationReady then
		applyInstance(instance, Config.ReduceParticles and Config.ClearExistingParticles)
	end
end

connect(Workspace.DescendantAdded, register)
connect(Lighting.DescendantAdded, register)

local function make(className, parent, properties)
	local object = Instance.new(className)
	for property, value in pairs(properties or {}) do
		object[property] = value
	end
	object.Parent = parent
	return object
end

local function addCorner(parent, radius)
	make("UICorner", parent, { CornerRadius = UDim.new(0, radius) })
end

local function addStroke(parent, color, transparency)
	make("UIStroke", parent, {
		Color = color,
		Transparency = transparency or 0,
		Thickness = 1,
	})
end

local AimAssist
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then
	error("PlayerGui não ficou disponível para criar o painel.")
end
if playerGui:GetAttribute("PotatoControlRunning") then
	return
end
playerGui:SetAttribute("PotatoControlRunning", true)

-- Aim Help integrado. Começa desligado e só ocupa o render loop quando ativado.
local AimConfig = {
	Active = true,
	ToggleKey = Enum.KeyCode.G,
	Intensity = 0.98,
	Friction = 0.45,
	FrictionAngleDeg = 7,
	Smoothing = 0.025,
	MaxAssistDegPerSec = 550,
	SpeedReferenceDeg = 25,
	MaxDistance = 35,
	MaxAngleDeg = 20,
	KeepAngleMultiplier = 1.6,
	ScanInterval = 0.04,
	CandidateRefresh = 0.4,
	SwitchMargin = 0.2,
	AimPartName = "UpperTorso",
	TargetTag = "AimAssistTarget",
	UseMouseAimDirection = false,
	ClickAssist = true,
	ClickAssistAutoHook = true,
	ClickAssistToleranceStuds = 0.8,
	ClickAssistMaxDeg = 4,
	ClickAssistInward = 0.3,
	ClickAssistStrength = 1,
	ClickAssistCooldown = 0.2,
	ShowIndicator = true,
	IndicatorColor = Color3.fromRGB(255, 255, 255),
	IndicatorSize = 14,
}

local DEFAULT_MODULE_CONFIG = {
	Version = 1,
	Hitbox = {
		Enabled = false,
		Tag = "DebugHitbox",
		Color = "#FFD166",
		OutlineColor = "#FFD166",
		Fill = false,
		FillTransparency = 0.8,
		Outline = true,
		Thickness = 0.02,
	},
	Crosshair = {
		Enabled = false,
		Color = "#FFFFFF",
		Preset1 = "",
		Preset2 = "",
		Preset3 = "",
		Size = 10,
		Thickness = 2,
		Gap = 4,
		Transparency = 0,
		Outline = true,
		Shape = "Cross",
		OffsetX = 0,
		OffsetY = 0,
	},
	Chat = {
		Macros = {},
		Favorites = { "", "", "" },
		Interval = 60,
	},
	HUD = {
		Enabled = false,
		FPS = true,
		Ping = true,
		Session = true,
		Keys = false,
		Modules = true,
		HideWhenPanelOpen = true,
		PositionX = 0.02,
		PositionY = 0.04,
		Scale = 0.9,
		Transparency = 0.15,
	},
	Accessibility = {
		Theme = "Dark",
		Scale = 1,
		Opacity = 0.06,
		HighContrast = false,
		ReducedMotion = false,
		DecorativeEffects = true,
		Compact = false,
		ControlSize = 1,
		Notifications = true,
		ChatNotifications = true,
		ProfileNotifications = true,
		DiagnosticNotifications = true,
		ErrorNotifications = true,
	},
	Controls = {
		Enabled = true,
		OpenPanel = "Insert",
		ToggleAim = "G",
		ToggleCrosshair = "K",
		ToggleHUD = "H",
		Macro1 = "",
		Macro2 = "",
		Macro3 = "",
	},
}

local function deepCopy(source)
	if type(source) ~= "table" then
		return source
	end
	local result = {}
	for key, value in pairs(source) do
		result[key] = deepCopy(value)
	end
	return result
end

local ModuleConfig = deepCopy(DEFAULT_MODULE_CONFIG)
local DEFAULT_AIM_CONFIG = deepCopy(AimConfig)

AimAssist = {}

local AIM_BIND_NAME = ("PotatoControlAim_%d_%d"):format(
	player.UserId,
	math.floor(os.clock() * 1000000)
)
local MAX_AIM_INTENSITY = 1
local MAX_AIM_FRICTION = 0.8
local aimCamera = Workspace.CurrentCamera
local aimRunning = false
local aimRequestedActive = AimConfig.Active
local aimPausedByPanel = false
local aimFrameBound = false
local aimConnections = {}
local aimRayParams = RaycastParams.new()
aimRayParams.FilterType = Enum.RaycastFilterType.Exclude
aimRayParams.IgnoreWater = true
aimRayParams.RespectCanCollide = true

local aimTarget, aimTargetPart, aimTargetHumanoid
local aimScanTimer = 0
local aimCandidateTimer = math.huge
local aimLastClick = -math.huge
local aimLastLook
local aimBillboard
local aimCandidates, aimParts, aimHumanoids, aimCandidateCount = {}, {}, {}, 0
local aimSeenCandidates = {}
local aimCameraPosition, aimCameraLook, aimPlayerPosition = Vector3.zero, Vector3.zero, Vector3.zero

local function setAimIndicator(part)
	if not aimBillboard then
		return
	end
	aimBillboard.Adornee = part
	aimBillboard.Enabled = part ~= nil
end

local function destroyAimIndicator()
	if aimBillboard then
		aimBillboard:Destroy()
		aimBillboard = nil
	end
end

local function ensureAimIndicator()
	if aimBillboard or not AimConfig.ShowIndicator then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PotatoControlAimIndicator"
	billboard.ResetOnSpawn = false
	billboard.Size = UDim2.fromOffset(AimConfig.IndicatorSize, AimConfig.IndicatorSize)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = AimConfig.IndicatorColor
	stroke.Thickness = 1.5
	stroke.Transparency = 0.35
	stroke.Parent = frame
	billboard.Parent = playerGui
	aimBillboard = billboard
	setAimIndicator(aimTargetPart)
end

local function clearAimTarget()
	aimTarget, aimTargetPart, aimTargetHumanoid = nil, nil, nil
	setAimIndicator(nil)
end

local function getAimPart(model)
	local part = model:FindFirstChild(AimConfig.AimPartName)
		or model:FindFirstChild("Torso")
		or model:FindFirstChild("HumanoidRootPart")
	return part and part:IsA("BasePart") and part or nil
end

local function isPlayerCharacterOrDescendant(model)
	local ancestor = model
	while ancestor do
		if ancestor:IsA("Model") and Players:GetPlayerFromCharacter(ancestor) then
			return true
		end
		ancestor = ancestor.Parent
	end
	return false
end

local function addAimCandidate(model)
	if aimCandidateCount >= 200 or aimSeenCandidates[model] or not model:IsA("Model") or model == player.Character
		or isPlayerCharacterOrDescendant(model) then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local part = humanoid and getAimPart(model)
	if not part then
		return
	end
	aimSeenCandidates[model] = true
	aimCandidateCount += 1
	aimCandidates[aimCandidateCount] = model
	aimParts[aimCandidateCount] = part
	aimHumanoids[aimCandidateCount] = humanoid
end

local function refreshAimCandidates()
	table.clear(aimCandidates)
	table.clear(aimParts)
	table.clear(aimHumanoids)
	table.clear(aimSeenCandidates)
	aimCandidateCount = 0
	for _, model in CollectionService:GetTagged(AimConfig.TargetTag) do
		addAimCandidate(model)
	end
end

local function hasAimLineOfSight(part, model)
	local result = Workspace:Raycast(aimCameraPosition, part.Position - aimCameraPosition, aimRayParams)
	return result == nil or result.Instance:IsDescendantOf(model)
end

local function evaluateAimCandidate(index, cosLimit)
	local model = aimCandidates[index]
	local part = aimParts[index]
	local humanoid = aimHumanoids[index]
	if not part.Parent or humanoid.Health <= 0 or isPlayerCharacterOrDescendant(model) then
		return nil
	end
	local position = part.Position
	local distance = (position - aimPlayerPosition).Magnitude
	if distance > AimConfig.MaxDistance then
		return nil
	end
	local offset = position - aimCameraPosition
	local magnitude = offset.Magnitude
	if magnitude < 1e-3 then
		return nil
	end
	local cosine = aimCameraLook:Dot(offset) / magnitude
	if cosine < cosLimit or not hasAimLineOfSight(part, model) then
		return nil
	end
	local alignment = (cosine - cosLimit) / (1 - cosLimit)
	local proximity = 1 - distance / AimConfig.MaxDistance
	return alignment * 0.7 + proximity * 0.3
end

local function scanAimTargets()
	local camera = aimCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root then
		clearAimTarget()
		return
	end
	if AimConfig.UseMouseAimDirection then
		local mousePosition = UserInputService:GetMouseLocation()
		aimCameraLook = camera:ScreenPointToRay(mousePosition.X, mousePosition.Y).Direction
	else
		aimCameraLook = camera.CFrame.LookVector
	end
	local cameraFrame = camera.CFrame
	aimCameraPosition = cameraFrame.Position
	aimPlayerPosition = root.Position
	local acquireAngle = math.clamp(AimConfig.MaxAngleDeg, 1, 60)
	local acquireCosine = math.cos(math.rad(acquireAngle))
	local keepCosine = math.cos(math.rad(math.min(acquireAngle * AimConfig.KeepAngleMultiplier, 85)))
	local bestModel, bestPart, bestHumanoid, bestScore = nil, nil, nil, -1
	local currentScore
	for index = 1, aimCandidateCount do
		local model = aimCandidates[index]
		local isCurrent = model == aimTarget
		local score = evaluateAimCandidate(index, isCurrent and keepCosine or acquireCosine)
		if score then
			if isCurrent then
				currentScore = score
			end
			if score > bestScore then
				bestModel, bestPart, bestHumanoid, bestScore = model, aimParts[index], aimHumanoids[index], score
			end
		end
	end
	if currentScore and (bestModel == aimTarget or bestScore < currentScore * (1 + AimConfig.SwitchMargin)) then
		return
	end
	if bestModel then
		aimTarget, aimTargetPart, aimTargetHumanoid = bestModel, bestPart, bestHumanoid
		setAimIndicator(bestPart)
	else
		clearAimTarget()
	end
end

local function stepAimAssist(deltaTime)
	local camera = aimCamera
	if not camera or camera.CameraType == Enum.CameraType.Scriptable then
		aimLastLook = nil
		if aimTarget then
			clearAimTarget()
		end
		return
	end
	deltaTime = math.min(deltaTime, 0.1)
	local cameraFrame = camera.CFrame
	local look = cameraFrame.LookVector
	if AimConfig.UseMouseAimDirection then
		local mousePosition = UserInputService:GetMouseLocation()
		look = camera:ScreenPointToRay(mousePosition.X, mousePosition.Y).Direction
	end
	aimCandidateTimer += deltaTime
	if aimCandidateTimer >= AimConfig.CandidateRefresh then
		aimCandidateTimer = 0
		refreshAimCandidates()
	end
	aimScanTimer += deltaTime
	if aimScanTimer >= AimConfig.ScanInterval then
		aimScanTimer = 0
		scanAimTargets()
	end
	local part = aimTargetPart
	if not (aimTarget and part and part.Parent and aimTargetHumanoid and aimTargetHumanoid.Health > 0) then
		if aimTarget then
			clearAimTarget()
		end
		aimLastLook = look
		return
	end
	local offset = part.Position - cameraFrame.Position
	if offset.Magnitude < 0.01 then
		aimLastLook = look
		return
	end
	local previousLook = aimLastLook or look
	local dot = math.clamp(look:Dot(previousLook), -1, 1)
	local turnSpeed = math.deg(math.acos(dot)) / math.max(deltaTime, 1e-3)
	local desiredLook = offset.Unit
	local errorAngle = math.acos(math.clamp(look:Dot(desiredLook), -1, 1))
	local frictionAngle = math.rad(math.max(AimConfig.FrictionAngleDeg, 0.1))
	local friction = math.clamp(AimConfig.Friction, 0, MAX_AIM_FRICTION)
		* math.clamp(1 - errorAngle / frictionAngle, 0, 1)
	local outputLook = look
	if friction > 0 then
		outputLook = previousLook:Lerp(look, 1 - friction).Unit
	end
	local userDelta = look - previousLook
	local targetDelta = desiredLook - look
	local directionFactor = 0.6
	if userDelta.Magnitude > 1e-6 and targetDelta.Magnitude > 1e-6 then
		local directionDot = userDelta:Dot(targetDelta) / (userDelta.Magnitude * targetDelta.Magnitude)
		directionFactor = math.clamp(0.6 + directionDot * 0.4, 0.2, 1)
	end
	local speedFactor = math.clamp(turnSpeed / AimConfig.SpeedReferenceDeg, 0.3, 1)
	local alpha = math.clamp(AimConfig.Intensity, 0, MAX_AIM_INTENSITY) * speedFactor * directionFactor
		* (1 - math.exp(-deltaTime / math.max(AimConfig.Smoothing, 1e-3)))
	local maxFraction = math.rad(AimConfig.MaxAssistDegPerSec) * deltaTime / math.max(errorAngle, 1e-4)
	outputLook = outputLook:Lerp(desiredLook, math.min(alpha, maxFraction)).Unit
	camera.CFrame = cameraFrame:Lerp(CFrame.lookAt(cameraFrame.Position, cameraFrame.Position + outputLook), 0.85)
	aimLastLook = outputLook
end

local function isAimActive()
	return aimRunning and aimRequestedActive and not aimPausedByPanel
end

local function updateAimRunner()
	local shouldRun = isAimActive()
	if shouldRun and not aimFrameBound then
		ensureAimIndicator()
		RunService:BindToRenderStep(AIM_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, stepAimAssist)
		aimFrameBound = true
	elseif not shouldRun and aimFrameBound then
		RunService:UnbindFromRenderStep(AIM_BIND_NAME)
		aimFrameBound = false
		clearAimTarget()
		aimLastLook = nil
		destroyAimIndicator()
	end
end

function AimAssist.SetActive(value)
	aimRequestedActive = value == true
	AimConfig.Active = aimRequestedActive
	aimCandidateTimer = math.huge
	updateAimRunner()
end

function AimAssist.SetPanelPaused(value)
	aimPausedByPanel = value == true
	updateAimRunner()
end

function AimAssist.SetConfig(key, value)
	AimConfig[key] = value
	if key == "ShowIndicator" then
		if value and isAimActive() then
			ensureAimIndicator()
			setAimIndicator(aimTargetPart)
		else
			destroyAimIndicator()
		end
	elseif key == "IndicatorSize" and aimBillboard then
		aimBillboard.Size = UDim2.fromOffset(value, value)
	elseif key == "IndicatorColor" and aimBillboard then
		local stroke = aimBillboard:FindFirstChildWhichIsA("UIStroke", true)
		if stroke then
			stroke.Color = value
		end
	end
	if key == "TargetTag" then
		aimCandidateTimer = math.huge
	end
end

function AimAssist.GetActive()
	return aimRequestedActive
end

function AimAssist.ApplyClickAssist()
	local camera = aimCamera
	if not (isAimActive() and AimConfig.ClickAssist and camera)
		or camera.CameraType == Enum.CameraType.Scriptable then
		return false
	end
	local now = os.clock()
	if now - aimLastClick < AimConfig.ClickAssistCooldown then
		return false
	end
	scanAimTargets()
	local part = aimTargetPart
	if not (aimTarget and part and part.Parent and aimTargetHumanoid and aimTargetHumanoid.Health > 0) then
		return false
	end
	local cameraFrame = camera.CFrame
	local look = cameraFrame.LookVector
	if AimConfig.UseMouseAimDirection then
		local mousePosition = UserInputService:GetMouseLocation()
		look = camera:ScreenPointToRay(mousePosition.X, mousePosition.Y).Direction
	end
	local origin = cameraFrame.Position
	local distance = (part.Position - origin).Magnitude
	if distance < 1 then
		return false
	end
	local rayLength = distance + 6
	local hit = Workspace:Raycast(origin, look * rayLength, aimRayParams)
	if hit and hit.Instance:IsDescendantOf(aimTarget) then
		return false
	end
	local tolerance = math.max(AimConfig.ClickAssistToleranceStuds, 0)
	local right, up = cameraFrame.RightVector, cameraFrame.UpVector
	local hitPoint
	for ring = 1, 2 do
		local radius = tolerance * ring / 2
		for index = 0, 7 do
			local angle = index * (math.pi / 4)
			local direction = (look * distance
				+ (right * math.cos(angle) + up * math.sin(angle)) * radius).Unit
			local result = Workspace:Raycast(origin, direction * rayLength, aimRayParams)
			if result and result.Instance:IsDescendantOf(aimTarget) then
				hitPoint = result.Position
				break
			end
		end
		if hitPoint then
			break
		end
	end
	if not hitPoint then
		return false
	end
	local aimPoint = hitPoint:Lerp(part.Position, math.clamp(AimConfig.ClickAssistInward, 0, 1))
	local desiredLook = (aimPoint - origin).Unit
	local angle = math.deg(math.acos(math.clamp(look:Dot(desiredLook), -1, 1)))
	if angle > AimConfig.ClickAssistMaxDeg then
		return false
	end
	local outputLook = look:Lerp(desiredLook, math.clamp(AimConfig.ClickAssistStrength, 0, 1)).Unit
	camera.CFrame = cameraFrame:Lerp(CFrame.lookAt(origin, origin + outputLook), 0.9)
	aimLastLook = outputLook
	aimLastClick = now
	return true
end

function AimAssist.Start()
	if aimRunning then
		return
	end
	aimRunning = true
	aimCamera = Workspace.CurrentCamera
	local function refreshAimFilter()
		local filter = {}
		if player.Character then
			table.insert(filter, player.Character)
		end
		aimRayParams.FilterDescendantsInstances = filter
	end
	refreshAimFilter()
	table.insert(aimConnections, player.CharacterAdded:Connect(function()
		refreshAimFilter()
		clearAimTarget()
		aimLastLook = nil
	end))
	table.insert(aimConnections, player.CharacterRemoving:Connect(function()
		clearAimTarget()
		aimLastLook = nil
	end))
	table.insert(aimConnections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		aimCamera = Workspace.CurrentCamera
		clearAimTarget()
		aimLastLook = nil
	end))
	if AimConfig.Active then
		AimAssist.SetActive(true)
	end
end

function AimAssist.Stop()
	if aimFrameBound then
		pcall(function()
			RunService:UnbindFromRenderStep(AIM_BIND_NAME)
		end)
		aimFrameBound = false
	end
	for _, connection in ipairs(aimConnections) do
		connection:Disconnect()
	end
	table.clear(aimConnections)
	aimRunning = false
	clearAimTarget()
	aimLastLook = nil
	destroyAimIndicator()
end

local screenGui = make("ScreenGui", playerGui, {
	Name = "PotatoControlPanel",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 10000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = true,
})

local cursorModal = make("TextButton", screenGui, {
	Name = "CursorModal",
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.fromOffset(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	TextTransparency = 1,
	AutoButtonColor = false,
	Active = false,
	Selectable = false,
	Modal = true,
	Visible = false,
	ZIndex = 1,
})

local loadingScreen = make("Frame", screenGui, {
	Name = "StartupLoading",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = COLORS.background,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Active = true,
	ZIndex = 100,
})

local loadingCard = make("Frame", loadingScreen, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.9, 0, 0, 184),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
	ZIndex = 101,
})
addCorner(loadingCard, 16)
addStroke(loadingCard, COLORS.line, 0.15)

make("TextLabel", loadingCard, {
	Position = UDim2.new(0, 22, 0, 22),
	Size = UDim2.new(1, -44, 0, 28),
	BackgroundTransparency = 1,
	Text = "POTATO CONTROL",
	TextColor3 = COLORS.text,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 102,
})

local loadingStatus = make("TextLabel", loadingCard, {
	Position = UDim2.new(0, 22, 0, 59),
	Size = UDim2.new(1, -44, 0, 22),
	BackgroundTransparency = 1,
	Text = "Preparando otimizações...",
	TextColor3 = COLORS.muted,
	Font = Enum.Font.GothamMedium,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 102,
})

local loadingCounter = make("TextLabel", loadingCard, {
	Position = UDim2.new(0, 22, 0, 84),
	Size = UDim2.new(1, -44, 0, 18),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = COLORS.accent,
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 102,
})

local loadingTrack = make("Frame", loadingCard, {
	Position = UDim2.new(0, 22, 1, -38),
	Size = UDim2.new(1, -44, 0, 7),
	BackgroundColor3 = COLORS.line,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 102,
})
addCorner(loadingTrack, 4)

local loadingFill = make("Frame", loadingTrack, {
	Size = UDim2.new(0.3, 0, 1, 0),
	BackgroundColor3 = COLORS.accent,
	BorderSizePixel = 0,
	ZIndex = 103,
})
addCorner(loadingFill, 4)

local loadingTween = TweenService:Create(
	loadingFill,
	TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Position = UDim2.new(0.7, 0, 0, 0) }
)
loadingTween:Play()

local panel
local panelOpen = false
local ready = false
local setPanelOpen
local setHudVisibility
local setTouchButtonVisibility
local confirmationOverlay
local savedMouseBehavior
local savedMouseIconEnabled
local stopPanelDrag
local finishSliderDrag
local cursorBindName = ("PotatoControlCursor_%d_%d"):format(
	player.UserId,
	math.floor(os.clock() * 1000000)
)
local cursorBound = false

local function keepCursorFree()
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	if not UserInputService.MouseIconEnabled then
		UserInputService.MouseIconEnabled = true
	end
end

setPanelOpen = function(value)
	if value then
		if not ready or panelOpen then
			return
		end
		panelOpen = true
		if AimAssist then
			AimAssist.SetPanelPaused(true)
		end
		savedMouseBehavior = UserInputService.MouseBehavior
		savedMouseIconEnabled = UserInputService.MouseIconEnabled
		screenGui.Enabled = true
		loadingScreen.Visible = false
		cursorModal.Visible = true
		panel.Visible = true
		keepCursorFree()
		local ok = pcall(function()
			RunService:BindToRenderStep(cursorBindName, Enum.RenderPriority.Last.Value + 1, function()
				if panelOpen then
					keepCursorFree()
				end
			end)
		end)
		cursorBound = ok
		if setHudVisibility then setHudVisibility() end
		if setTouchButtonVisibility then setTouchButtonVisibility() end
		return
	end

	if not panelOpen then
		return
	end
	if FeatureModules.Controls and FeatureModules.Controls.CancelCapture then
		FeatureModules.Controls.CancelCapture()
	end
	if stopPanelDrag then
		stopPanelDrag()
	end
	if finishSliderDrag then
		finishSliderDrag()
	end
	panelOpen = false
	panel.Visible = false
	cursorModal.Visible = false
	screenGui.Enabled = false
	if cursorBound then
		pcall(function()
			RunService:UnbindFromRenderStep(cursorBindName)
		end)
		cursorBound = false
	end
	if savedMouseBehavior then
		pcall(function()
			UserInputService.MouseBehavior = savedMouseBehavior
		end)
	end
	if savedMouseIconEnabled ~= nil then
		pcall(function()
			UserInputService.MouseIconEnabled = savedMouseIconEnabled
		end)
	end
	if confirmationOverlay then confirmationOverlay.Visible = false end
	if AimAssist then
		AimAssist.SetPanelPaused(false)
	end
	if setHudVisibility then setHudVisibility() end
	if setTouchButtonVisibility then setTouchButtonVisibility() end
end

-- Dá tempo para a tela de carregamento aparecer antes da varredura inicial.
task.wait()

panel = make("Frame", screenGui, {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Visible = false,
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
})
addCorner(panel, 16)
addStroke(panel, COLORS.line, 0.15)

local minimized = false
local expandedSize
local panelScaleFactor = 1

local function clampCenter(value, viewportSize, panelSize)
	local low = panelSize / 2 + 8
	local high = viewportSize - panelSize / 2 - 8
	if high < low then
		return viewportSize / 2
	end
	return math.clamp(value, low, high)
end

local function resizePanel()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local width = math.max(220, math.min(720, viewport.X - 20, (viewport.X - 20) / panelScaleFactor))
	local height = math.max(280, math.min(740, viewport.Y - 20, (viewport.Y - 20) / panelScaleFactor))
	expandedSize = UDim2.fromOffset(width, height)
	panel.Size = minimized and UDim2.fromOffset(width, 76) or expandedSize
	local centerX = panel.Position.X.Scale * viewport.X + panel.Position.X.Offset
	local centerY = panel.Position.Y.Scale * viewport.Y + panel.Position.Y.Offset
	panel.Position = UDim2.fromOffset(
		clampCenter(centerX, viewport.X, width * panelScaleFactor),
		clampCenter(centerY, viewport.Y, (minimized and 76 or height) * panelScaleFactor)
	)
end

resizePanel()
local cameraSizeConnection
local function bindCameraSize()
	if cameraSizeConnection then
		cameraSizeConnection:Disconnect()
		cameraSizeConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraSizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resizePanel)
	end
	resizePanel()
end
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), bindCameraSize)
bindCameraSize()

make("Frame", panel, {
	Name = "AccentLine",
	Position = UDim2.new(0, 18, 0, 0),
	Size = UDim2.new(1, -36, 0, 3),
	BackgroundColor3 = COLORS.accent,
	BorderSizePixel = 0,
})

local dragArea = make("Frame", panel, {
	Name = "DragArea",
	Position = UDim2.new(0, 0, 0, 4),
	Size = UDim2.new(1, -94, 0, 68),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Active = true,
})

local panelDragConnections = {}
stopPanelDrag = function()
	for _, connection in ipairs(panelDragConnections) do
		connection:Disconnect()
	end
	table.clear(panelDragConnections)
end

local function startPanelDrag(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	stopPanelDrag()

	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local startPointer = input.Position
	local startX = panel.Position.X.Scale * viewport.X + panel.Position.X.Offset
	local startY = panel.Position.Y.Scale * viewport.Y + panel.Position.Y.Offset

	table.insert(panelDragConnections, UserInputService.InputChanged:Connect(function(changedInput)
		if changedInput.UserInputType ~= Enum.UserInputType.MouseMovement
			and changedInput.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local currentViewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or viewport
		local width = panel.AbsoluteSize.X
		local height = panel.AbsoluteSize.Y
		local delta = changedInput.Position - startPointer
		panel.Position = UDim2.fromOffset(
			clampCenter(startX + delta.X, currentViewport.X, width),
			clampCenter(startY + delta.Y, currentViewport.Y, height)
		)
	end))
	table.insert(panelDragConnections, UserInputService.InputEnded:Connect(function(endedInput)
		if endedInput.UserInputType == Enum.UserInputType.MouseButton1
			or endedInput.UserInputType == Enum.UserInputType.Touch then
			stopPanelDrag()
		end
	end))
end
dragArea.InputBegan:Connect(startPanelDrag)

local logo = make("Frame", panel, {
	Position = UDim2.new(0, 18, 0, 17),
	Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = COLORS.accentDark,
	BorderSizePixel = 0,
})
addCorner(logo, 12)
make("TextLabel", logo, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "PC",
	TextColor3 = COLORS.accent,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
})

make("TextLabel", panel, {
	Position = UDim2.new(0, 72, 0, 15),
	Size = UDim2.new(1, -132, 0, 27),
	BackgroundTransparency = 1,
	Text = "POTATO CONTROL",
	TextColor3 = COLORS.text,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
})

local profileStatus = make("TextLabel", panel, {
	Position = UDim2.new(0, 73, 0, 42),
	Size = UDim2.new(1, -138, 0, 18),
	BackgroundTransparency = 1,
	Text = "PERFIL ATIVO: PC ANTIGO",
	TextColor3 = COLORS.muted,
	Font = Enum.Font.GothamMedium,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
})

local closeButton = make("TextButton", panel, {
	Position = UDim2.new(1, -48, 0, 18),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = COLORS.card,
	BorderSizePixel = 0,
	Text = "×",
	TextColor3 = COLORS.muted,
	Font = Enum.Font.GothamMedium,
	TextSize = 22,
	AutoButtonColor = false,
})
addCorner(closeButton, 9)
closeButton.Activated:Connect(function()
	stopPanelDrag()
	setPanelOpen(false)
end)

local minimizeButton = make("TextButton", panel, {
	Position = UDim2.new(1, -84, 0, 18),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = COLORS.card,
	BorderSizePixel = 0,
	Text = "−",
	TextColor3 = COLORS.muted,
	Font = Enum.Font.GothamMedium,
	TextSize = 20,
	AutoButtonColor = false,
})
addCorner(minimizeButton, 9)

local presetFrame = make("Frame", panel, {
	Position = UDim2.new(0, 16, 0, 78),
	Size = UDim2.new(1, -32, 0, 50),
	BackgroundColor3 = COLORS.background,
	BorderSizePixel = 0,
})
addCorner(presetFrame, 11)

local function makePresetButton(text, position, size, color)
	local button = make("TextButton", presetFrame, {
		Position = position,
		Size = size,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = COLORS.text,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		AutoButtonColor = false,
	})
	addCorner(button, 8)
	return button
end

local balancedButton = makePresetButton(
	"EQUILIBRADO",
	UDim2.new(0, 6, 0, 6),
	UDim2.new(0.5, -9, 1, -12),
	COLORS.card
)
local oldPcButton = makePresetButton(
	"PC ANTIGO · MÁXIMO",
	UDim2.new(0.5, 3, 0, 6),
	UDim2.new(0.5, -9, 1, -12),
	COLORS.accentDark
)

local pageDefinitions = {
	{ "OPT", "OTIMIZAÇÃO" }, { "AIM", "AIM HELP" }, { "HITBOX", "HITBOX" },
	{ "CHAT", "CHAT" }, { "CROSSHAIR", "CROSSHAIR" }, { "PROFILES", "PROFILES" },
	{ "CONTROLS", "CONTROLS" }, { "HUD", "HUD" }, { "ACCESSIBILITY", "ACESSIBILIDADE" },
	{ "DIAGNOSTICS", "DIAGNÓSTICO" },
}
local pages = {}
local navButtons = {}
local activePageId = "OPT"
local lastSettingsPageId = "OPT"

local tabBar = make("ScrollingFrame", panel, {
	Name = "TabBar",
	Position = UDim2.new(0, 16, 0, 137),
	Size = UDim2.new(1, -32, 0, 34),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0,
	ScrollingDirection = Enum.ScrollingDirection.X,
	ScrollingEnabled = true,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	Active = true,
})
make("UIListLayout", tabBar, {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 5),
})

local function makePage(pageId)
	local page = make("ScrollingFrame", panel, {
		Name = "Page_" .. pageId,
		Position = UDim2.new(0, 16, 0, 178),
		Size = UDim2.new(1, -32, 1, -240),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = COLORS.accent,
		ScrollBarImageTransparency = 0.2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollingEnabled = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Active = true,
		Visible = false,
	})
	make("UIPadding", page, {
		PaddingLeft = UDim.new(0, 3),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 7),
	})
	make("UIListLayout", page, {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 7),
	})
	pages[pageId] = page
	return page
end

local function setActivePage(pageId)
	if not pages[pageId] then
		return
	end
	activePageId = pageId
	if pageId ~= "PROFILES" and pageId ~= "DIAGNOSTICS" then
		lastSettingsPageId = pageId
	end
	for id, page in pairs(pages) do
		page.Visible = id == pageId
	end
	for id, button in pairs(navButtons) do
		local selected = id == pageId
		button.BackgroundColor3 = selected and COLORS.accentDark or COLORS.card
		button.TextColor3 = selected and COLORS.accent or COLORS.muted
	end
end

for index, definition in ipairs(pageDefinitions) do
	local id, title = definition[1], definition[2]
	makePage(id)
	local button = make("TextButton", tabBar, {
		Name = "Tab_" .. id,
		Size = UDim2.fromOffset(104, 30),
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
		Text = title,
		TextColor3 = COLORS.muted,
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		AutoButtonColor = false,
		LayoutOrder = index,
	})
	addCorner(button, 8)
	navButtons[id] = button
	connect(button.Activated, function()
		setActivePage(id)
	end)
end

local content = pages.OPT
setActivePage("OPT")

local refreshers = {}
local activeProfile = "PC ANTIGO"
local profileRevision = 0
local scheduleProfileSave

local function markCustom()
	profileRevision += 1
	activeProfile = "CUSTOM"
	profileStatus.Text = "PERFIL ATIVO: " .. activeProfile
	if scheduleProfileSave then
		scheduleProfileSave()
	end
end

local function refreshUI()
	profileStatus.Text = "PERFIL ATIVO: " .. activeProfile
	for _, refresh in ipairs(refreshers) do
		refresh()
	end
end

local function addSection(title)
	make("TextLabel", content, {
		Size = UDim2.new(1, -8, 0, 20),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = COLORS.accent,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
	})
end

local function affectsSetting(instance, key)
	if key == "DisableLightShadows" then
		return instance:IsA("Light")
	elseif key == "DisablePostEffects" then
		return instance:IsA("PostEffect")
	elseif key == "ReduceParticles" or key == "ParticleRateMultiplier" or key == "ClearExistingParticles" then
		return instance:IsA("ParticleEmitter")
	elseif key == "DisableTrailsAndBeams" then
		return instance:IsA("Trail") or instance:IsA("Beam")
	elseif key == "DisableAtmosphere" then
		return instance:IsA("Atmosphere")
	end
	return false
end

local function applyChange(key, clearParticlesNow)
	if key == "DisableGlobalShadows" or key == "ReduceTerrainWaterEffects" then
		applyGlobalSettings()
		return
	end

	for instance in pairs(managed) do
		if instance.Parent and affectsSetting(instance, key) then
			applyInstance(instance, clearParticlesNow)
		end
	end
end

local function applyPreset(preset, name)
	for key, value in pairs(preset) do
		Config[key] = value
	end
	profileRevision += 1
	activeProfile = name
	applyAll(Config.ReduceParticles and Config.ClearExistingParticles)
	refreshUI()
	if scheduleProfileSave then
		scheduleProfileSave()
	end
end

local function makeToggle(title, description, key, settings, onChange)
	local values = settings or Config
	local row = make("Frame", content, {
		Size = UDim2.new(1, -8, 0, 56),
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
	})
	row:SetAttribute("CompactHeight", 46)
	row:SetAttribute("RegularHeight", 56)
	addCorner(row, 10)

	make("TextLabel", row, {
		Position = UDim2.new(0, 12, 0, 7),
		Size = UDim2.new(1, -108, 0, 20),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = COLORS.text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	make("TextLabel", row, {
		Position = UDim2.new(0, 12, 0, 29),
		Size = UDim2.new(1, -108, 0, 17),
		BackgroundTransparency = 1,
		Text = description,
		TextColor3 = COLORS.muted,
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local button = make("TextButton", row, {
		Position = UDim2.new(1, -78, 0.5, -14),
		Size = UDim2.fromOffset(66, 28),
		BackgroundColor3 = COLORS.accentDark,
		BorderSizePixel = 0,
		Text = "ON",
		TextColor3 = COLORS.accent,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		AutoButtonColor = false,
	})
	addCorner(button, 8)

	local function refresh()
		local enabled = values[key]
		button.Text = enabled and "ON" or "OFF"
		button.BackgroundColor3 = enabled and COLORS.accentDark or COLORS.cardHover
		button.TextColor3 = enabled and COLORS.accent or COLORS.muted
	end
	table.insert(refreshers, refresh)
	refresh()

	button.Activated:Connect(function()
		values[key] = not values[key]
		if values == Config then
			local clearNow = (key == "ClearExistingParticles" and Config[key] and Config.ReduceParticles)
				or (key == "ReduceParticles" and Config[key] and Config.ClearExistingParticles)
			applyChange(key, clearNow)
		elseif onChange then
			onChange(key, values[key])
		end
		markCustom()
		refreshUI()
	end)
end

local draggingSlider
local dragConnections = {}

local function disconnectDrag()
	for _, connection in ipairs(dragConnections) do
		connection:Disconnect()
	end
	table.clear(dragConnections)
end

finishSliderDrag = function()
	if not draggingSlider then
		return
	end
	local key = draggingSlider.key
	draggingSlider = nil
	disconnectDrag()
	if key == "ParticleRateMultiplier" then
		applyChange(key, Config.ReduceParticles and Config.ClearExistingParticles)
	end
	refreshUI()
end

local function startSliderDrag(key, setFromX, input)
	if draggingSlider then
		disconnectDrag()
	end
	draggingSlider = { key = key, setFromX = setFromX }
	setFromX(input.Position.X)
	table.insert(dragConnections, UserInputService.InputChanged:Connect(function(changedInput)
		if draggingSlider and (changedInput.UserInputType == Enum.UserInputType.MouseMovement
			or changedInput.UserInputType == Enum.UserInputType.Touch) then
			draggingSlider.setFromX(changedInput.Position.X)
		end
	end))
	table.insert(dragConnections, UserInputService.InputEnded:Connect(function(endedInput)
		if draggingSlider and (endedInput.UserInputType == Enum.UserInputType.MouseButton1
			or endedInput.UserInputType == Enum.UserInputType.Touch) then
			finishSliderDrag()
		end
	end))
end

local function makeSlider(title, description, key, minimum, maximum, step, formatValue, settings, onChange)
	local values = settings or Config
	local row = make("Frame", content, {
		Size = UDim2.new(1, -8, 0, 74),
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
	})
	row:SetAttribute("CompactHeight", 64)
	row:SetAttribute("RegularHeight", 74)
	addCorner(row, 10)

	make("TextLabel", row, {
		Position = UDim2.new(0, 12, 0, 7),
		Size = UDim2.new(1, -100, 0, 19),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = COLORS.text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local valueLabel = make("TextLabel", row, {
		Position = UDim2.new(1, -108, 0, 7),
		Size = UDim2.fromOffset(96, 19),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.accent,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	make("TextLabel", row, {
		Position = UDim2.new(0, 12, 0, 26),
		Size = UDim2.new(1, -24, 0, 15),
		BackgroundTransparency = 1,
		Text = description,
		TextColor3 = COLORS.muted,
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local track = make("Frame", row, {
		Position = UDim2.new(0, 14, 0, 53),
		Size = UDim2.new(1, -28, 0, 7),
		BackgroundColor3 = COLORS.line,
		BorderSizePixel = 0,
		Active = true,
	})
	addCorner(track, 4)
	local fill = make("Frame", track, {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = COLORS.accent,
		BorderSizePixel = 0,
		Active = false,
	})
	addCorner(fill, 4)
	local knob = make("Frame", track, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(13, 13),
		BackgroundColor3 = COLORS.text,
		BorderSizePixel = 0,
		Active = false,
	})
	addCorner(knob, 7)

	local function refresh()
		local alpha = math.clamp((values[key] - minimum) / (maximum - minimum), 0, 1)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = formatValue(values[key])
	end
	table.insert(refreshers, refresh)
	refresh()

	local function setFromX(x)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
		local raw = minimum + alpha * (maximum - minimum)
		local newValue = math.clamp(math.floor(raw / step + 0.5) * step, minimum, maximum)
		if values[key] == newValue then return end
		values[key] = newValue
		if onChange then
			onChange(key, values[key])
		end
		refresh()
		markCustom()
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			startSliderDrag(key, setFromX, input)
		end
	end)
end

addSection("RENDERIZAÇÃO")
makeToggle("Sombras globais", "Desliga sombras do sol e da lua", "DisableGlobalShadows")
makeToggle("Sombras de luzes", "Desliga sombras de luzes locais", "DisableLightShadows")
makeToggle("Pós-processamento", "Desliga blur, bloom e efeitos de câmera", "DisablePostEffects")

addSection("EFEITOS")
makeToggle("Reduzir partículas", "Diminui a quantidade emitida", "ReduceParticles")
makeSlider("Taxa de partículas", "Percentual da taxa original", "ParticleRateMultiplier", 0, 1, 0.05, function(value)
	return string.format("%.0f%%", value * 100)
end)
makeToggle("Limpar partículas atuais", "Apaga partículas já visíveis ao aplicar", "ClearExistingParticles")
makeToggle("Trails e beams", "Desliga rastros e feixes visuais", "DisableTrailsAndBeams")
makeToggle("Atmosfera", "Remove densidade, névoa e glare", "DisableAtmosphere")
makeToggle("Água do terreno", "Reduz ondas e reflexos da água", "ReduceTerrainWaterEffects")

content = pages.AIM
addSection("AUXÍLIO DE MIRA · ARCO")
make("TextLabel", content, {
	Size = UDim2.new(1, -8, 0, 30),
	BackgroundTransparency = 1,
	Text = "Somente NPCs com a tag AimAssistTarget. Personagens de jogadores são sempre ignorados.",
	TextColor3 = COLORS.muted,
	Font = Enum.Font.Gotham,
	TextSize = 9,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
})
makeToggle("Aim Help", "Atalho em CONTROLS; pausa ao abrir o painel", "Active", AimConfig, function(_, value)
	AimAssist.SetActive(value)
end)
makeSlider("Força do acompanhamento", "Intensidade da correção da câmera", "Intensity", 0, 1, 0.02, function(value)
	return string.format("%.0f%%", value * 100)
end, AimConfig, AimAssist.SetConfig)
makeSlider("Distância de busca", "Alcance máximo em studs", "MaxDistance", 5, 100, 5, function(value)
	return string.format("%d studs", math.floor(value + 0.5))
end, AimConfig, AimAssist.SetConfig)
makeSlider("Ângulo de busca", "Tamanho do cone para encontrar alvos", "MaxAngleDeg", 5, 60, 1, function(value)
	return string.format("%d°", math.floor(value + 0.5))
end, AimConfig, AimAssist.SetConfig)
makeToggle("Ajuste ao disparar", "Corrige a direção dentro do limite configurado", "ClickAssist", AimConfig, AimAssist.SetConfig)
makeToggle("Ativar no clique esquerdo", "Executa o ajuste junto ao clique", "ClickAssistAutoHook", AimConfig, AimAssist.SetConfig)
makeToggle("Mostrar alvo atual", "Exibe um pequeno marcador no alvo", "ShowIndicator", AimConfig, AimAssist.SetConfig)

local requestConfirmation
local pressedKeys = {}
local showNotice
local function makePageLabel(parent, text, height, color)
	return make("TextLabel", parent, {
		Size = UDim2.new(1, -8, 0, height or 30),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color or COLORS.muted,
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
end

local function makePageTextBox(parent, title, placeholder, initialText, height)
	local row = make("Frame", parent, {
		Size = UDim2.new(1, -8, 0, height or 55),
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
	})
	addCorner(row, 9)
	make("TextLabel", row, {
		Position = UDim2.new(0, 10, 0, 5),
		Size = UDim2.new(1, -20, 0, 14),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = COLORS.muted,
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local box = make("TextBox", row, {
		Position = UDim2.new(0, 8, 0, 22),
		Size = UDim2.new(1, -16, 0, (height or 55) - 27),
		BackgroundColor3 = COLORS.background,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Text = initialText or "",
		PlaceholderText = placeholder,
		PlaceholderColor3 = COLORS.muted,
		TextColor3 = COLORS.text,
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
	})
	addCorner(box, 6)
	return box, row
end

local function makeActionRow(parent, buttons)
	local row = make("Frame", parent, {
		Size = UDim2.new(1, -8, 0, 36),
		BackgroundTransparency = 1,
	})
	local count = #buttons
	local gap = 6
	for index, item in ipairs(buttons) do
		local button = make("TextButton", row, {
			Position = UDim2.new((index - 1) / count, (index - 1) * gap, 0, 0),
			Size = UDim2.new(1 / count, -gap, 1, 0),
			BackgroundColor3 = item.primary and COLORS.accentDark or COLORS.card,
			BorderSizePixel = 0,
			Text = item.text,
			TextColor3 = item.primary and COLORS.accent or COLORS.text,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AutoButtonColor = false,
		})
		addCorner(button, 8)
		if item.callback then
			connect(button.Activated, item.callback)
		end
	end
	return row
end

local function normalizeHex(value)
	local text = tostring(value or ""):gsub("%s", "")
	if text:sub(1, 1) == "#" then
		text = text:sub(2)
	end
	if #text ~= 6 or not text:match("^%x%x%x%x%x%x$") then
		return nil
	end
	return "#" .. text:upper()
end

local function colorFromHex(value)
	local hex = normalizeHex(value)
	if not hex then
		return nil
	end
	return Color3.fromRGB(
		tonumber(hex:sub(2, 3), 16),
		tonumber(hex:sub(4, 5), 16),
		tonumber(hex:sub(6, 7), 16)
	)
end

local function colorToHex(color)
	return string.format("#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

-- HITBOX: SelectionBox somente em peças associadas à tag de depuração.
do
content = pages.HITBOX
local hitboxConfig = ModuleConfig.Hitbox
local hitboxSelections = setmetatable({}, { __mode = "k" })
local hitboxVisuals = setmetatable({}, { __mode = "k" })
local hitboxDestroyConnections = setmetatable({}, { __mode = "k" })
local hitboxPreviewUntil = 0
local hitboxPreviewTask
local hitboxPartCache = {}
local hitboxPartCacheTag
local hitboxList
local hitboxColorInput
local hitboxOutlineColorInput
local hitboxTagInput
local hitboxSummary

local function isPlayerPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if Players:GetPlayerFromCharacter(model) then
			return true
		end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function getTaggedDebugParts(forceRefresh)
	if not forceRefresh and hitboxPartCacheTag == hitboxConfig.Tag then
		return hitboxPartCache
	end
	local result, seen = {}, {}
	for _, tagged in ipairs(CollectionService:GetTagged(hitboxConfig.Tag)) do
		local function include(part)
			if #result >= 100 or seen[part] or not part:IsA("BasePart")
				or not part:IsDescendantOf(Workspace) or isPlayerPart(part) then
				return
			end
			seen[part] = true
			result[#result + 1] = part
			if hitboxSelections[part] == nil then
				hitboxSelections[part] = true
			end
		end
		if tagged:IsA("BasePart") then
			include(tagged)
		elseif tagged:IsA("Model") or tagged:IsA("Folder") then
			for _, descendant in ipairs(tagged:GetDescendants()) do
				if descendant:IsA("BasePart") then
					include(descendant)
				end
				if #result >= 100 then
					break
				end
			end
		end
	end
	table.sort(result, function(left, right)
		return left:GetFullName() < right:GetFullName()
	end)
	hitboxPartCache = result
	hitboxPartCacheTag = hitboxConfig.Tag
	return result
end

local function updateHitboxVisuals()
	local shouldShow = hitboxConfig.Enabled or os.clock() < hitboxPreviewUntil
	local fillColor = colorFromHex(hitboxConfig.Color) or Color3.fromRGB(255, 209, 102)
	local outlineColor = colorFromHex(hitboxConfig.OutlineColor) or fillColor
	local alive = {}
	if shouldShow then
		for _, part in ipairs(getTaggedDebugParts()) do
			if hitboxSelections[part] and part.Parent and part:IsDescendantOf(Workspace) and not isPlayerPart(part) then
				alive[part] = true
				local box = hitboxVisuals[part]
				if not box or box.Parent == nil then
					box = Instance.new("SelectionBox")
					box.Name = "ZKXDebugHitboxPreview"
					box.Adornee = part
					box.Parent = Workspace
					hitboxVisuals[part] = box
					hitboxDestroyConnections[part] = part.Destroying:Connect(function()
						local current = hitboxVisuals[part]
						if current then current:Destroy() end
						hitboxVisuals[part] = nil
						hitboxSelections[part] = nil
						hitboxDestroyConnections[part] = nil
					end)
				end
				box.Adornee = part
				box.Color3 = outlineColor
				box.SurfaceColor3 = fillColor
				box.SurfaceTransparency = hitboxConfig.Fill and hitboxConfig.FillTransparency or 1
				box.LineThickness = hitboxConfig.Outline and hitboxConfig.Thickness or 0
				box.Transparency = 0.12
				box.Visible = true
			end
		end
	end
	for part, box in pairs(hitboxVisuals) do
		if not alive[part] then
			box:Destroy()
			hitboxVisuals[part] = nil
			local destroyConnection = hitboxDestroyConnections[part]
			if destroyConnection then destroyConnection:Disconnect() end
			hitboxDestroyConnections[part] = nil
		end
	end
	if hitboxSummary then
		local count = 0
		for _ in pairs(alive) do
			count += 1
		end
		hitboxSummary.Text = string.format("%d peça(s) selecionada(s) · limite de segurança: 100", count)
	end
end

local function refreshHitboxList()
	if not hitboxList then
		return
	end
	for _, child in ipairs(hitboxList:GetChildren()) do
		if child:GetAttribute("HitboxChoice") then
			child:Destroy()
		end
	end
	local parts = getTaggedDebugParts(true)
	if #parts == 0 then
		local empty = make("TextLabel", hitboxList, {
			Name = "NoTaggedHitboxes",
			Size = UDim2.new(1, -8, 0, 30),
			BackgroundTransparency = 1,
			Text = "Nenhuma peça encontrada. Marque BaseParts ou Models com a tag configurada.",
			TextColor3 = COLORS.muted,
			Font = Enum.Font.Gotham,
			TextSize = 9,
			TextWrapped = true,
		})
		empty:SetAttribute("HitboxChoice", true)
	end
	for index, part in ipairs(parts) do
		local button = make("TextButton", hitboxList, {
			Size = UDim2.new(1, -8, 0, 30),
			BackgroundColor3 = COLORS.card,
			BorderSizePixel = 0,
			Text = (hitboxSelections[part] and "✓  " or "□  ") .. part.Name,
			TextColor3 = hitboxSelections[part] and COLORS.text or COLORS.muted,
			Font = Enum.Font.GothamMedium,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AutoButtonColor = false,
			LayoutOrder = index,
		})
		button:SetAttribute("HitboxChoice", true)
		addCorner(button, 7)
		button.Activated:Connect(function()
			if not part.Parent or not part:IsDescendantOf(Workspace) then
				hitboxSelections[part] = nil
				refreshHitboxList()
				return
			end
			hitboxSelections[part] = not hitboxSelections[part]
			button.Text = (hitboxSelections[part] and "✓  " or "□  ") .. part.Name
			button.TextColor3 = hitboxSelections[part] and COLORS.text or COLORS.muted
			updateHitboxVisuals()
			markCustom()
		end)
	end
	updateHitboxVisuals()
end

addSection("VISUALIZAÇÃO DE DEPURAÇÃO")
makePageLabel(content, "Exibe somente objetos com a tag configurada; atualize a lista após mudar tags. A seleção vale nesta sessão. Não altera tamanho, colisão ou personagens de jogadores.", 42)
makeToggle("Ativar visualizador", "Mostra as peças selecionadas", "Enabled", hitboxConfig, function()
	updateHitboxVisuals()
end)
hitboxTagInput = makePageTextBox(content, "TAG DE DEPURAÇÃO", "DebugHitbox", hitboxConfig.Tag)
connect(hitboxTagInput.FocusLost, function()
	local tag = hitboxTagInput.Text:match("^%s*(.-)%s*$")
	if #tag < 1 or #tag > 40 then
		hitboxTagInput.Text = hitboxConfig.Tag
		logDiagnostic("Tag de hitbox inválida")
		return
	end
	if tag == hitboxConfig.Tag then
		hitboxTagInput.Text = tag
		return
	end
	hitboxConfig.Tag = tag
	refreshHitboxList()
	markCustom()
end)
hitboxColorInput = makePageTextBox(content, "COR HEX", "#FFD166", hitboxConfig.Color)
connect(hitboxColorInput.FocusLost, function()
	local color = normalizeHex(hitboxColorInput.Text)
	if not color then
		hitboxColorInput.Text = hitboxConfig.Color
		logDiagnostic("HEX de hitbox inválido")
		return
	end
	if color == hitboxConfig.Color then
		hitboxColorInput.Text = color
		return
	end
	hitboxConfig.Color = color
	hitboxColorInput.Text = color
	updateHitboxVisuals()
	markCustom()
end)
hitboxOutlineColorInput = makePageTextBox(content, "COR HEX DO CONTORNO", "#FFD166", hitboxConfig.OutlineColor)
connect(hitboxOutlineColorInput.FocusLost, function()
	local color = normalizeHex(hitboxOutlineColorInput.Text)
	if not color then
		hitboxOutlineColorInput.Text = hitboxConfig.OutlineColor
		logDiagnostic("HEX do contorno de hitbox inválido")
		return
	end
	if color == hitboxConfig.OutlineColor then
		hitboxOutlineColorInput.Text = color
		return
	end
	hitboxConfig.OutlineColor = color
	hitboxOutlineColorInput.Text = color
	updateHitboxVisuals()
	markCustom()
end)
makeSlider("Transparência do preenchimento", "0 opaco · 1 invisível", "FillTransparency", 0, 1, 0.05,
	function(value) return string.format("%.0f%%", value * 100) end, hitboxConfig, function()
	updateHitboxVisuals()
end)
makeSlider("Espessura do contorno", "Espessura SelectionBox em studs", "Thickness", 0, 0.08, 0.005,
	function(value) return string.format("%.3f", value) end, hitboxConfig, function()
	updateHitboxVisuals()
end)
makeToggle("Preenchimento", "Exibe as faces da caixa", "Fill", hitboxConfig, function()
	updateHitboxVisuals()
end)
makeToggle("Contorno", "Exibe as arestas da caixa", "Outline", hitboxConfig, function()
	updateHitboxVisuals()
end)
makeActionRow(content, {
	{ text = "ATUALIZAR LISTA", callback = refreshHitboxList },
	{ text = "PRÉVIA 8s", primary = true, callback = function()
		if hitboxPreviewTask then pcall(task.cancel, hitboxPreviewTask) end
		hitboxPreviewUntil = os.clock() + 8
		updateHitboxVisuals()
		hitboxPreviewTask = task.delay(8.1, function()
			hitboxPreviewTask = nil
			updateHitboxVisuals()
		end)
	end },
	{ text = "PADRÃO", callback = function()
		hitboxConfig.Color = DEFAULT_MODULE_CONFIG.Hitbox.Color
		hitboxConfig.OutlineColor = DEFAULT_MODULE_CONFIG.Hitbox.OutlineColor
		hitboxConfig.FillTransparency = DEFAULT_MODULE_CONFIG.Hitbox.FillTransparency
		hitboxConfig.Thickness = DEFAULT_MODULE_CONFIG.Hitbox.Thickness
		hitboxColorInput.Text = hitboxConfig.Color
		hitboxOutlineColorInput.Text = hitboxConfig.OutlineColor
		refreshUI()
		updateHitboxVisuals()
		markCustom()
	end },
})
hitboxSummary = makePageLabel(content, "0 peça(s) selecionada(s)", 22, COLORS.accent)
hitboxList = make("ScrollingFrame", content, {
	Name = "HitboxSelectionList",
	Size = UDim2.new(1, -8, 0, 180),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = COLORS.accent,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollingEnabled = true,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	Active = true,
})
make("UIListLayout", hitboxList, {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 4),
})
refreshHitboxList()
FeatureModules.Hitbox = {
	Config = hitboxConfig,
	Update = updateHitboxVisuals,
	RefreshList = refreshHitboxList,
	SyncInputs = function()
		hitboxTagInput.Text = hitboxConfig.Tag
		hitboxColorInput.Text = hitboxConfig.Color
		hitboxOutlineColorInput.Text = hitboxConfig.OutlineColor
	end,
	CancelPreview = function()
		hitboxPreviewUntil = 0
		if hitboxPreviewTask then
			pcall(task.cancel, hitboxPreviewTask)
			hitboxPreviewTask = nil
		end
		updateHitboxVisuals()
	end,
	ResetSelection = function()
		table.clear(hitboxSelections)
		refreshHitboxList()
	end,
	Disable = function()
		hitboxConfig.Enabled = false
		FeatureModules.Hitbox.CancelPreview()
		updateHitboxVisuals()
	end,
}
end

-- CROSSHAIR: interface 2D independente da ScreenGui do painel.
do
content = pages.CROSSHAIR
local crosshairConfig = ModuleConfig.Crosshair
local crosshairColorInput
local crosshairPresetStatus
local crosshairPreviewUntil = 0
local crosshairPreviewTask
local crosshairGui = make("ScreenGui", playerGui, {
	Name = "ZKXCrosshairGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 8000,
	Enabled = false,
})
local crosshairRoot = make("Frame", crosshairGui, {
	Name = "CrosshairRoot",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.fromOffset(0, 0),
	BackgroundTransparency = 1,
})
local crosshairPieces = {}
for _, name in ipairs({ "Top", "Bottom", "Left", "Right", "Dot" }) do
	local piece = make("Frame", crosshairRoot, {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Visible = false,
	})
	local stroke = make("UIStroke", piece, {
		Color = Color3.fromRGB(0, 0, 0),
		Thickness = 1,
		Transparency = 0,
		Enabled = false,
	})
	crosshairPieces[name] = { Frame = piece, Stroke = stroke }
end

local function updateCrosshair()
	local showCrosshair = crosshairConfig.Enabled or os.clock() < crosshairPreviewUntil
	local color = colorFromHex(crosshairConfig.Color) or Color3.new(1, 1, 1)
	local size = math.clamp(crosshairConfig.Size, 2, 30)
	local thickness = math.clamp(crosshairConfig.Thickness, 1, 8)
	local gap = math.clamp(crosshairConfig.Gap, 0, 24)
	crosshairRoot.Position = UDim2.new(0.5, crosshairConfig.OffsetX, 0.5, crosshairConfig.OffsetY)
	crosshairGui.Enabled = showCrosshair
	for name, pair in pairs(crosshairPieces) do
		local frame, stroke = pair.Frame, pair.Stroke
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = math.clamp(crosshairConfig.Transparency, 0, 0.9)
		stroke.Enabled = crosshairConfig.Outline and showCrosshair
		if name == "Dot" then
			frame.Size = UDim2.fromOffset(thickness * 2, thickness * 2)
			frame.Position = UDim2.fromOffset(0, 0)
			frame.Visible = showCrosshair and crosshairConfig.Shape == "Dot"
		elseif crosshairConfig.Shape == "Cross" then
			frame.Visible = showCrosshair
			if name == "Top" then
				frame.Size = UDim2.fromOffset(thickness, size)
				frame.Position = UDim2.fromOffset(0, -gap - size / 2)
			elseif name == "Bottom" then
				frame.Size = UDim2.fromOffset(thickness, size)
				frame.Position = UDim2.fromOffset(0, gap + size / 2)
			elseif name == "Left" then
				frame.Size = UDim2.fromOffset(size, thickness)
				frame.Position = UDim2.fromOffset(-gap - size / 2, 0)
			else
				frame.Size = UDim2.fromOffset(size, thickness)
				frame.Position = UDim2.fromOffset(gap + size / 2, 0)
			end
		else
			frame.Visible = false
		end
	end
end

addSection("MIRA VISUAL INDEPENDENTE")
makePageLabel(content, "Desenho 2D separado. Não altera a mira interna, hitboxes, câmera ou mecânica de combate.", 30)
makeToggle("Mostrar mira", "A mira fica em uma ScreenGui própria", "Enabled", crosshairConfig, updateCrosshair)
crosshairColorInput = makePageTextBox(content, "COR HEX", "#FFFFFF", crosshairConfig.Color)
connect(crosshairColorInput.FocusLost, function()
	local color = normalizeHex(crosshairColorInput.Text)
	if not color then
		crosshairColorInput.Text = crosshairConfig.Color
		logDiagnostic("HEX da mira inválido")
		return
	end
	if color == crosshairConfig.Color then
		crosshairColorInput.Text = color
		return
	end
	crosshairConfig.Color = color
	crosshairColorInput.Text = color
	updateCrosshair()
	markCustom()
end)
makeSlider("Tamanho", "Comprimento da cruz em pixels", "Size", 2, 30, 1, function(value)
	return string.format("%d px", math.floor(value + 0.5))
end, crosshairConfig, updateCrosshair)
makeSlider("Espessura", "Largura dos traços", "Thickness", 1, 8, 1, function(value)
	return string.format("%d px", math.floor(value + 0.5))
end, crosshairConfig, updateCrosshair)
makeSlider("Espaço central", "Distância do centro da cruz", "Gap", 0, 24, 1, function(value)
	return string.format("%d px", math.floor(value + 0.5))
end, crosshairConfig, updateCrosshair)
makeSlider("Transparência", "0 opaco · 90% transparente", "Transparency", 0, 0.9, 0.05, function(value)
	return string.format("%.0f%%", value * 100)
end, crosshairConfig, updateCrosshair)
makeSlider("Posição X", "Deslocamento horizontal do centro", "OffsetX", -100, 100, 2, function(value)
	return string.format("%d px", math.floor(value + 0.5))
end, crosshairConfig, updateCrosshair)
makeSlider("Posição Y", "Deslocamento vertical do centro", "OffsetY", -100, 100, 2, function(value)
	return string.format("%d px", math.floor(value + 0.5))
end, crosshairConfig, updateCrosshair)
makeToggle("Contorno preto", "Melhora o contraste sobre cenários claros", "Outline", crosshairConfig, updateCrosshair)
makeActionRow(content, {
	{ text = "PRÉVIA 8s", primary = true, callback = function()
		if crosshairPreviewTask then pcall(task.cancel, crosshairPreviewTask) end
		crosshairPreviewUntil = os.clock() + 8
		updateCrosshair()
		crosshairPreviewTask = task.delay(8.1, function()
			crosshairPreviewTask = nil
			updateCrosshair()
		end)
	end },
	{ text = "CRUZ", callback = function()
		crosshairConfig.Shape = "Cross"
		updateCrosshair()
		markCustom()
	end },
	{ text = "PONTO", callback = function()
		crosshairConfig.Shape = "Dot"
		updateCrosshair()
		markCustom()
	end },
	{ text = "PADRÃO", callback = function()
		for key, value in pairs(DEFAULT_MODULE_CONFIG.Crosshair) do
			crosshairConfig[key] = value
		end
		crosshairPreviewUntil = 0
		if crosshairPreviewTask then
			pcall(task.cancel, crosshairPreviewTask)
			crosshairPreviewTask = nil
		end
		crosshairColorInput.Text = crosshairConfig.Color
		refreshUI()
		updateCrosshair()
		markCustom()
	end },
})
local crosshairPresetFields = { "Color", "Size", "Thickness", "Gap", "Transparency", "Outline", "Shape", "OffsetX", "OffsetY" }
local function saveCrosshairPreset(slot)
	local snapshot = {}
	for _, key in ipairs(crosshairPresetFields) do snapshot[key] = crosshairConfig[key] end
	local ok, encoded = pcall(function() return HttpService:JSONEncode(snapshot) end)
	if not ok or #encoded > 512 then
		crosshairPresetStatus.Text = "Não foi possível gravar o preset."
		return
	end
	crosshairConfig["Preset" .. slot] = encoded
	crosshairPresetStatus.Text = "Preset " .. slot .. " salvo no perfil."
	markCustom()
end

local function applyCrosshairPreset(slot)
	local encoded = crosshairConfig["Preset" .. slot]
	if type(encoded) ~= "string" or encoded == "" then
		crosshairPresetStatus.Text = "Slot " .. slot .. " vazio. Ajuste e salve uma mira."
		return
	end
	local ok, snapshot = pcall(function() return HttpService:JSONDecode(encoded) end)
	if not ok or type(snapshot) ~= "table" then
		crosshairPresetStatus.Text = "Preset " .. slot .. " inválido; o perfil foi mantido."
		logDiagnostic("Preset de mira inválido no slot " .. slot)
		return
	end
	local color = normalizeHex(snapshot.Color)
	local function finite(value, minimum, maximum)
		return type(value) == "number" and value == value and math.abs(value) < math.huge
			and value >= minimum and value <= maximum
	end
	if not color or not finite(snapshot.Size, 2, 30) or not finite(snapshot.Thickness, 1, 8)
		or not finite(snapshot.Gap, 0, 24) or not finite(snapshot.Transparency, 0, 0.9)
		or type(snapshot.Outline) ~= "boolean" or (snapshot.Shape ~= "Cross" and snapshot.Shape ~= "Dot")
		or not finite(snapshot.OffsetX, -100, 100) or not finite(snapshot.OffsetY, -100, 100) then
		crosshairPresetStatus.Text = "Preset " .. slot .. " inválido; o perfil foi mantido."
		logDiagnostic("Preset de mira fora dos limites no slot " .. slot)
		return
	end
	for _, key in ipairs(crosshairPresetFields) do
		crosshairConfig[key] = key == "Color" and color or snapshot[key]
	end
	crosshairColorInput.Text = crosshairConfig.Color
	crosshairPresetStatus.Text = "Preset " .. slot .. " aplicado."
	refreshUI()
	updateCrosshair()
	markCustom()
end

crosshairPresetStatus = makePageLabel(content, "PRESETS PERSONALIZADOS · 3 slots salvos junto ao perfil", 24, COLORS.accent)
for slot = 1, 3 do
	makeActionRow(content, {
		{ text = "SALVAR MIRA " .. slot, callback = function() saveCrosshairPreset(slot) end },
		{ text = "APLICAR MIRA " .. slot, primary = true, callback = function() applyCrosshairPreset(slot) end },
	})
end
updateCrosshair()
FeatureModules.Crosshair = {
	Config = crosshairConfig,
	Gui = crosshairGui,
	Update = updateCrosshair,
	SyncInputs = function() crosshairColorInput.Text = crosshairConfig.Color end,
	CancelPreview = function()
		crosshairPreviewUntil = 0
		if crosshairPreviewTask then
			pcall(task.cancel, crosshairPreviewTask)
			crosshairPreviewTask = nil
		end
	end,
	Disable = function()
		crosshairConfig.Enabled = false
		FeatureModules.Crosshair.CancelPreview()
		updateCrosshair()
	end,
}
end

-- CHAT: macros ficam no perfil local e o envio passa pelo filtro oficial.
do
content = pages.CHAT
local chatConfig = ModuleConfig.Chat
local selectedMacroId
local macroList
local chatPreview
local chatStatus
local chatHistoryLabel
local macroTitleInput
local macroCategoryInput
local macroMessageInput
local categoryFilterInput
local copyMessageInput
local chatHistory = {}
local lastChatAttempt = -math.huge
local chatSending = false
local macroFilterTask
local refreshMacroList
local sendFavoriteMacro

local function findMacro(id)
	for _, macro in ipairs(chatConfig.Macros) do
		if macro.Id == id then
			return macro
		end
	end
	return nil
end

local function displayMacro(macro)
	selectedMacroId = macro and macro.Id or nil
	if macro then
		macroTitleInput.Text = macro.Title
		macroCategoryInput.Text = macro.Category
		macroMessageInput.Text = macro.Message
		chatPreview.Text = "PRÉVIA: " .. macro.Message
	else
		macroTitleInput.Text = ""
		macroCategoryInput.Text = "Geral"
		macroMessageInput.Text = ""
		chatPreview.Text = "PRÉVIA: selecione uma macro para revisar o texto."
	end
	if refreshMacroList then
		refreshMacroList()
	end
end

refreshMacroList = function()
	if macroFilterTask then
		pcall(task.cancel, macroFilterTask)
		macroFilterTask = nil
	end
	if not macroList then
		return
	end
	for _, child in ipairs(macroList:GetChildren()) do
		if child:GetAttribute("MacroRow") then
			child:Destroy()
		end
	end
	local filter = (categoryFilterInput.Text or ""):lower():match("^%s*(.-)%s*$")
	local visibleCount = 0
	for _, macro in ipairs(chatConfig.Macros) do
		local category = tostring(macro.Category or "Geral")
		if filter == "" or category:lower():find(filter, 1, true) then
			visibleCount += 1
			local selected = selectedMacroId == macro.Id
			local row = make("TextButton", macroList, {
				Size = UDim2.new(1, -8, 0, 29),
				BackgroundColor3 = selected and COLORS.accentDark or COLORS.card,
				BorderSizePixel = 0,
				Text = string.format("[%s]  %s", category, macro.Title),
				TextColor3 = selected and COLORS.accent or COLORS.text,
				Font = Enum.Font.GothamMedium,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				AutoButtonColor = false,
				LayoutOrder = visibleCount,
			})
			row:SetAttribute("MacroRow", true)
			addCorner(row, 7)
			row.Activated:Connect(function()
				displayMacro(macro)
			end)
		end
	end
	if visibleCount == 0 then
		local empty = make("TextLabel", macroList, {
			Size = UDim2.new(1, -8, 0, 30),
			BackgroundTransparency = 1,
			Text = "Nenhuma macro nessa categoria. Use o formulário para criar uma.",
			TextColor3 = COLORS.muted,
			Font = Enum.Font.Gotham,
			TextSize = 9,
			TextWrapped = true,
		})
		empty:SetAttribute("MacroRow", true)
	end
end

local function getTextChannel()
	local folder = TextChatService:FindFirstChild("TextChannels")
	local channels = folder and folder:GetChildren() or TextChatService:GetChildren()
	if folder then
		local general = folder:FindFirstChild("RBXGeneral")
		if general and general:IsA("TextChannel") then return general end
	else
		local general = TextChatService:FindFirstChild("RBXGeneral")
		if general and general:IsA("TextChannel") then return general end
	end
	for _, child in ipairs(channels) do
		if child:IsA("TextChannel") then
			return child
		end
	end
	return nil
end

local function actuallySendMacro(macro)
	if chatSending then
		return
	end
	local now = os.clock()
	local interval = math.clamp(chatConfig.Interval, 60, 300)
	local remaining = interval - (now - lastChatAttempt)
	if remaining > 0 then
		chatStatus.Text = string.format("Aguarde %.1f s antes da próxima mensagem.", remaining)
		return
	end
	local channel = getTextChannel()
	if not channel then
		chatStatus.Text = "TextChatService sem TextChannel disponível."
		logDiagnostic("Envio de macro indisponível: sem TextChannel")
		showNotice("Chat oficial indisponível", "Chat")
		return
	end
	chatSending = true
	lastChatAttempt = now
	chatStatus.Text = "Enviando pelo TextChatService..."
	task.spawn(function()
		local ok, result = pcall(function()
			return channel:SendAsync(macro.Message)
		end)
		chatSending = false
		if shuttingDown or not chatStatus.Parent then return end
		if not ok then
			chatStatus.Text = "Falha no envio oficial do chat."
			logDiagnostic("TextChannel:SendAsync falhou: " .. tostring(result))
			showNotice("Falha ao enviar macro", "Chat")
			return
		end
		if result and result.Status == Enum.TextChatMessageStatus.Success then
			chatStatus.Text = "Mensagem aceita pelo TextChatService."
			table.insert(chatHistory, 1, os.date("%H:%M:%S") .. "  " .. macro.Message:sub(1, 60))
			while #chatHistory > 50 do
				table.remove(chatHistory)
			end
			if chatHistoryLabel then
				chatHistoryLabel.Text = "HISTÓRICO LOCAL:\n" .. table.concat(chatHistory, "\n", 1, math.min(4, #chatHistory))
			end
			showNotice("Macro enviada pelo chat oficial", "Chat")
		else
			local status = result and result.Status and result.Status.Name or "desconhecido"
			chatStatus.Text = "O chat não aceitou a mensagem (" .. status .. ")."
			logDiagnostic("TextChatService retornou " .. status)
		end
	end)
end

local function requestMacroSend(id)
	local macro = findMacro(id)
	if not macro then
		chatStatus.Text = "Escolha uma macro válida primeiro."
		return
	end
	chatPreview.Text = "PRÉVIA: " .. macro.Message
	requestConfirmation("Enviar esta mensagem pelo chat do Roblox?\n\n" .. macro.Message, function()
		actuallySendMacro(macro)
	end)
end

sendFavoriteMacro = function(slot)
	local id = chatConfig.Favorites[slot]
	if id and id ~= "" then
		requestMacroSend(id)
	else
		chatStatus.Text = "Associe uma macro a este favorito na aba CHAT."
	end
end

addSection("MACROS DE MENSAGEM")
makePageLabel(content, "Crie frases por categoria, revise a prévia e confirme cada envio. Intervalo local mínimo: 60 segundos.", 34)
macroTitleInput = makePageTextBox(content, "NOME", "Ex.: Saudação", "", 50)
macroCategoryInput = makePageTextBox(content, "CATEGORIA", "Geral", "Geral", 50)
macroMessageInput = makePageTextBox(content, "MENSAGEM · ATÉ 200 CARACTERES", "Texto da macro", "", 70)
categoryFilterInput = makePageTextBox(content, "FILTRAR CATEGORIA", "vazio mostra todas", "", 48)
connect(categoryFilterInput:GetPropertyChangedSignal("Text"), function()
	if macroFilterTask then pcall(task.cancel, macroFilterTask) end
	macroFilterTask = task.delay(0.15, function()
		macroFilterTask = nil
		if not shuttingDown and macroList and macroList.Parent then refreshMacroList() end
	end)
end)
chatPreview = makePageLabel(content, "PRÉVIA: selecione uma macro para revisar o texto.", 40, COLORS.accent)
macroList = make("ScrollingFrame", content, {
	Name = "MacroList",
	Size = UDim2.new(1, -8, 0, 128),
	BackgroundColor3 = COLORS.background,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = COLORS.accent,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	Active = true,
})
addCorner(macroList, 8)
make("UIPadding", macroList, {
	PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
	PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
})
make("UIListLayout", macroList, {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 4),
})

makeActionRow(content, {
	{ text = "CRIAR / SALVAR", primary = true, callback = function()
		local title = macroTitleInput.Text:match("^%s*(.-)%s*$")
		local category = macroCategoryInput.Text:match("^%s*(.-)%s*$")
		local message = macroMessageInput.Text
		if #title < 1 or #title > 32 or #category < 1 or #category > 20
			or #message < 1 or #message > 200 or title:find("%c")
			or category:find("%c") or message:find("%c") then
			chatStatus.Text = "Revise os limites e use textos de uma linha, sem controles."
			return
		end
		local existing = findMacro(selectedMacroId)
		local function saveMacro()
			if existing then
				existing.Title, existing.Category, existing.Message = title, category, message
				chatStatus.Text = "Macro atualizada."
			else
				local macro = {
					Id = HttpService:GenerateGUID(false),
					Title = title,
					Category = category,
					Message = message,
				}
				table.insert(chatConfig.Macros, macro)
				selectedMacroId = macro.Id
				chatStatus.Text = "Macro criada."
			end
			local saved = findMacro(selectedMacroId)
			if saved then
				chatPreview.Text = "PRÉVIA: " .. saved.Message
			end
			refreshMacroList()
			markCustom()
		end
		if existing then
			requestConfirmation("Substituir o conteúdo da macro selecionada?", saveMacro)
		else
			saveMacro()
		end
	end },
	{ text = "EXCLUIR", callback = function()
		local index
		for i, macro in ipairs(chatConfig.Macros) do
			if macro.Id == selectedMacroId then
				index = i
				break
			end
		end
		if not index then
			chatStatus.Text = "Selecione uma macro para excluir."
			return
		end
		requestConfirmation("Excluir a macro selecionada?", function()
			table.remove(chatConfig.Macros, index)
			for slot = 1, 3 do
				if chatConfig.Favorites[slot] == selectedMacroId then
					chatConfig.Favorites[slot] = ""
				end
			end
			displayMacro(nil)
			chatStatus.Text = "Macro excluída."
			markCustom()
		end)
	end },
	{ text = "LIMPAR", callback = function()
		displayMacro(nil)
	end },
})
makeActionRow(content, {
	{ text = "PRÉVIA / ENVIAR", primary = true, callback = function()
		requestMacroSend(selectedMacroId)
	end },
	{ text = "COPIAR TEXTO", callback = function()
		local macro = findMacro(selectedMacroId)
		if not macro then
			chatStatus.Text = "Selecione uma macro primeiro."
			return
		end
		copyMessageInput.Text = macro.Message
		copyMessageInput:CaptureFocus()
		chatStatus.Text = "Texto selecionável: use Ctrl+A e Ctrl+C."
	end },
})
makeActionRow(content, {
	{ text = "FAVORITO 1", callback = function()
		if not selectedMacroId then
			chatStatus.Text = "Selecione uma macro."
			return
		end
		chatConfig.Favorites[1] = chatConfig.Favorites[1] == selectedMacroId and "" or selectedMacroId
		chatStatus.Text = "Favorito 1 atualizado. Configure a tecla em CONTROLS."
		markCustom()
	end },
	{ text = "FAVORITO 2", callback = function()
		if not selectedMacroId then
			chatStatus.Text = "Selecione uma macro."
			return
		end
		chatConfig.Favorites[2] = chatConfig.Favorites[2] == selectedMacroId and "" or selectedMacroId
		chatStatus.Text = "Favorito 2 atualizado. Configure a tecla em CONTROLS."
		markCustom()
	end },
	{ text = "FAVORITO 3", callback = function()
		if not selectedMacroId then
			chatStatus.Text = "Selecione uma macro."
			return
		end
		chatConfig.Favorites[3] = chatConfig.Favorites[3] == selectedMacroId and "" or selectedMacroId
		chatStatus.Text = "Favorito 3 atualizado. Configure a tecla em CONTROLS."
		markCustom()
	end },
})
copyMessageInput = makePageTextBox(content, "COPIAR SEM ENVIAR · CTRL+A / CTRL+C", "A mensagem será exibida aqui", "", 55)
makeSlider("Intervalo entre envios", "Mínimo de 1 min; o chat oficial ainda pode bloquear", "Interval", 60, 300, 10,
	function(value) return string.format("%d s", math.floor(value + 0.5)) end, chatConfig, function()
	markCustom()
end)
chatStatus = makePageLabel(content, "Macros salvas localmente nesta sessão até sincronizar o perfil.", 34, COLORS.accent)
chatHistoryLabel = makePageLabel(content, "HISTÓRICO LOCAL: vazio", 70)
refreshMacroList()
FeatureModules.Chat = {
	Config = chatConfig,
	Find = findMacro,
	Display = displayMacro,
	RefreshList = refreshMacroList,
	SendFavorite = sendFavoriteMacro,
	History = chatHistory,
	Status = chatStatus,
	HistoryLabel = chatHistoryLabel,
	CancelFilter = function()
		if macroFilterTask then
			pcall(task.cancel, macroFilterTask)
			macroFilterTask = nil
		end
	end,
}
end

-- HUD: métricas reais, atualizadas em intervalo limitado e apenas quando ativo.
do
content = pages.HUD
local hudConfig = ModuleConfig.HUD
local sessionStartedAt = os.clock()
local hudEpoch = 0
local hudRunnerActive = false
local hudGui = make("ScreenGui", playerGui, {
	Name = "ZKXPerformanceHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 7000,
	Enabled = false,
})
local hudCard = make("Frame", hudGui, {
	Name = "Metrics",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(hudConfig.PositionX, 0, hudConfig.PositionY, 0),
	Size = UDim2.fromOffset(210, 96),
	BackgroundColor3 = COLORS.background,
	BackgroundTransparency = hudConfig.Transparency,
	BorderSizePixel = 0,
})
addCorner(hudCard, 9)
addStroke(hudCard, COLORS.line, 0.2)
local hudScale = make("UIScale", hudCard, { Scale = hudConfig.Scale })
local hudText = make("TextLabel", hudCard, {
	Position = UDim2.new(0, 10, 0, 8),
	Size = UDim2.new(1, -20, 1, -16),
	BackgroundTransparency = 1,
	Text = "ZKX HUD",
	TextColor3 = COLORS.text,
	Font = Enum.Font.Code,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
})

local function graphicsModuleActive()
	for _, value in pairs(Config) do
		if value == true then return true end
	end
	return Config.ParticleRateMultiplier < 1
end

local function getModuleSummary()
	local active = {}
	if graphicsModuleActive() then table.insert(active, "Otimização") end
	if AimAssist.GetActive() then table.insert(active, "Aim NPC") end
	if FeatureModules.Hitbox.Config.Enabled then table.insert(active, "Hitbox debug") end
	if FeatureModules.Crosshair.Config.Enabled then table.insert(active, "Crosshair") end
	if hudConfig.Enabled then table.insert(active, "HUD") end
	return #active > 0 and table.concat(active, ", ") or "nenhum"
end

local function updateHudMetrics()
	if not hudConfig.Enabled then return end
	local lines = {}
	if hudConfig.FPS then
		local ok, frameTime = pcall(function() return Stats.FrameTime end)
		if ok and type(frameTime) == "number" and frameTime > 0 then
			table.insert(lines, string.format("FPS  %d", math.floor(1 / frameTime + 0.5)))
		else
			table.insert(lines, "FPS  indisponível")
		end
	end
	if hudConfig.Ping then
		local ok, ping = pcall(function() return player:GetNetworkPing() end)
		if ok and type(ping) == "number" and ping >= 0 then
			table.insert(lines, string.format("PING  %d ms", math.floor(ping * 1000 + 0.5)))
		else
			table.insert(lines, "PING  indisponível")
		end
	end
	if hudConfig.Session then
		local totalSeconds = math.max(0, math.floor(os.clock() - sessionStartedAt))
		table.insert(lines, string.format("SESSÃO  %02d:%02d", math.floor(totalSeconds / 60), totalSeconds % 60))
	end
	if hudConfig.Keys then
		local keys = {}
		for name in pairs(pressedKeys) do keys[#keys + 1] = name end
		table.sort(keys)
		table.insert(lines, "TECLAS  " .. (#keys > 0 and table.concat(keys, " + ") or "—"))
	end
	if hudConfig.Modules then
		table.insert(lines, "MÓDULOS  " .. getModuleSummary())
	end
	hudText.Text = #lines > 0 and table.concat(lines, "\n") or "HUD ativo"
end

setHudVisibility = function()
	hudGui.Enabled = hudConfig.Enabled and not (panelOpen and hudConfig.HideWhenPanelOpen)
end

local function refreshHud()
	hudCard.Position = UDim2.new(math.clamp(hudConfig.PositionX, 0, 0.92), 0,
		math.clamp(hudConfig.PositionY, 0, 0.92), 0)
	hudCard.BackgroundTransparency = math.clamp(hudConfig.Transparency, 0, 0.8)
	hudScale.Scale = math.clamp(hudConfig.Scale, 0.6, 1.4)
	setHudVisibility()
	updateHudMetrics()
	if hudConfig.Enabled and not hudRunnerActive then
		hudEpoch += 1
		local epoch = hudEpoch
		hudRunnerActive = true
		task.spawn(function()
			while hudConfig.Enabled and hudEpoch == epoch do
				if not (panelOpen and hudConfig.HideWhenPanelOpen) then
					updateHudMetrics()
				end
				task.wait(0.5)
			end
			if hudEpoch == epoch then hudRunnerActive = false end
		end)
	elseif not hudConfig.Enabled and hudRunnerActive then
		hudEpoch += 1
		hudRunnerActive = false
	end
end

addSection("INDICADORES")
makePageLabel(content, "FPS usa Stats.FrameTime; ping usa Player:GetNetworkPing(). Métricas não disponíveis aparecem como indisponíveis.", 36)
makeToggle("Ativar HUD", "Desativado, não mantém tarefa de atualização", "Enabled", hudConfig, refreshHud)
makeToggle("FPS", "Tempo do frame mais recente do cliente", "FPS", hudConfig, refreshHud)
makeToggle("Ping", "Latência de ida e volta da sessão", "Ping", hudConfig, refreshHud)
makeToggle("Tempo de sessão", "Relógio desde o início desta sessão", "Session", hudConfig, refreshHud)
makeToggle("Teclas pressionadas", "Lista teclas observadas pelo painel", "Keys", hudConfig, refreshHud)
makeToggle("Módulos ativos", "Resumo de módulos ligados", "Modules", hudConfig, refreshHud)
makeToggle("Ocultar com o painel aberto", "Evita sobrepor o painel", "HideWhenPanelOpen", hudConfig, refreshHud)
makeSlider("Posição horizontal", "0 esquerda · 1 direita", "PositionX", 0, 0.92, 0.02, function(value)
	return string.format("%.0f%%", value * 100)
end, hudConfig, refreshHud)
makeSlider("Posição vertical", "0 topo · 1 base", "PositionY", 0, 0.92, 0.02, function(value)
	return string.format("%.0f%%", value * 100)
end, hudConfig, refreshHud)
makeSlider("Escala do HUD", "Tamanho do bloco", "Scale", 0.6, 1.4, 0.05, function(value)
	return string.format("%.0f%%", value * 100)
end, hudConfig, refreshHud)
makeSlider("Transparência do fundo", "0 opaco · 80% transparente", "Transparency", 0, 0.8, 0.05, function(value)
	return string.format("%.0f%%", value * 100)
end, hudConfig, refreshHud)
refreshHud()
FeatureModules.HUD = {
	Config = hudConfig,
	Gui = hudGui,
	Refresh = refreshHud,
	Update = updateHudMetrics,
	Summary = getModuleSummary,
	GraphicsActive = graphicsModuleActive,
}
end

-- ACCESSIBILITY: escala, paleta e densidade aplicadas ao painel inteiro.
do
content = pages.ACCESSIBILITY
local accessibilityConfig = ModuleConfig.Accessibility
local panelScale = make("UIScale", panel, { Scale = 1 })
local accentLine = panel:FindFirstChild("AccentLine")
local logoFrame = logo
local notificationToken = 0
local notificationTask

showNotice = function(message, category)
	if not accessibilityConfig.Notifications then return end
	local categoryKey = category and (category .. "Notifications") or nil
	if categoryKey and accessibilityConfig[categoryKey] == false then return end
	if notificationTask then
		pcall(task.cancel, notificationTask)
		notificationTask = nil
	end
	notificationToken += 1
	local token = notificationToken
	profileStatus.Text = "AVISO: " .. tostring(message):sub(1, 60)
	notificationTask = task.delay(3, function()
		notificationTask = nil
		if notificationToken == token and profileStatus.Parent then
			profileStatus.Text = "PERFIL ATIVO: " .. activeProfile
		end
	end)
end

local function setCompactRows()
	for _, instance in ipairs(panel:GetDescendants()) do
		local compactHeight = instance:GetAttribute("CompactHeight")
		local regularHeight = instance:GetAttribute("RegularHeight")
		if compactHeight and regularHeight and instance:IsA("GuiObject") then
			local current = instance.Size
			instance.Size = UDim2.new(current.X.Scale, current.X.Offset,
				current.Y.Scale, accessibilityConfig.Compact and compactHeight or regularHeight)
		end
	end
end

local function applyAccessibilityLayout(includeCompactRows)
	local requestedScale = math.clamp(accessibilityConfig.Scale * accessibilityConfig.ControlSize, 0.6, 1.4)
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local fitScale = math.min((viewport.X - 20) / 220, (viewport.Y - 20) / 280)
	panelScaleFactor = math.min(requestedScale, math.max(0.6, fitScale))
	panelScale.Scale = panelScaleFactor
	resizePanel()
	panel.BackgroundTransparency = math.clamp(accessibilityConfig.Opacity, 0, 0.55)
	presetFrame.BackgroundTransparency = math.clamp(accessibilityConfig.Opacity, 0, 0.55)
	accentLine.Visible = accessibilityConfig.DecorativeEffects
	logoFrame.Visible = accessibilityConfig.DecorativeEffects
	if accessibilityConfig.ReducedMotion then
		pcall(function() loadingTween:Cancel() end)
	elseif loadingScreen.Visible then
		pcall(function() loadingTween:Play() end)
	end
	if includeCompactRows then setCompactRows() end
end

local function applyAccessibilityTheme()
	local old = COLORS
	local palette = table.clone(accessibilityConfig.Theme == "Light" and LIGHT_COLORS or DARK_COLORS)
	if accessibilityConfig.HighContrast then
		palette.muted = accessibilityConfig.Theme == "Light"
			and Color3.fromRGB(37, 52, 70) or Color3.fromRGB(203, 216, 231)
	end
	local colorProperties = {
		"BackgroundColor3", "TextColor3", "ImageColor3", "BorderColor3",
		"ScrollBarImageColor3", "Color",
	}
	local roots = { screenGui, FeatureModules.HUD.Gui }
	if FeatureModules.TouchGui then table.insert(roots, FeatureModules.TouchGui) end
	for _, root in ipairs(roots) do
		if root and root.Parent then
			for _, instance in ipairs(root:GetDescendants()) do
				for _, property in ipairs(colorProperties) do
					local ok, current = pcall(function() return instance[property] end)
					if ok and typeof(current) == "Color3" then
						for key, oldColor in pairs(old) do
							if current == oldColor then
								pcall(function() instance[property] = palette[key] end)
								break
							end
						end
					end
				end
			end
		end
	end
	COLORS = palette
	applyAccessibilityLayout(true)
	refreshUI()
	setActivePage(activePageId)
end

addSection("CONFORTO VISUAL")
makeActionRow(content, {
	{ text = "TEMA ESCURO", callback = function()
		accessibilityConfig.Theme = "Dark"
		applyAccessibilityTheme()
		markCustom()
	end },
	{ text = "TEMA CLARO", callback = function()
		accessibilityConfig.Theme = "Light"
		applyAccessibilityTheme()
		markCustom()
	end },
})
makeSlider("Escala da interface", "Ajusta o painel para diferentes telas", "Scale", 0.7, 1.25, 0.05, function(value)
	return string.format("%.0f%%", value * 100)
end, accessibilityConfig, function() applyAccessibilityLayout(false) end)
makeSlider("Tamanho dos controles", "Escala adicional para botões e campos", "ControlSize", 0.85, 1.2, 0.05, function(value)
	return string.format("%.0f%%", value * 100)
end, accessibilityConfig, function() applyAccessibilityLayout(false) end)
makeSlider("Opacidade do painel", "0 opaco · 55% transparente", "Opacity", 0, 0.55, 0.05, function(value)
	return string.format("%.0f%%", value * 100)
end, accessibilityConfig, function() applyAccessibilityLayout(false) end)
makeToggle("Contraste reforçado", "Aumenta a legibilidade do texto secundário", "HighContrast", accessibilityConfig,
	function() applyAccessibilityTheme() end)
makeToggle("Interface compacta", "Reduz a altura dos controles compatíveis", "Compact", accessibilityConfig,
	function() applyAccessibilityLayout(true) end)
makeToggle("Reduzir animações", "Interrompe animações decorativas", "ReducedMotion", accessibilityConfig,
	function() applyAccessibilityLayout(false) end)
makeToggle("Efeitos decorativos", "Mostra faixa e marca do cabeçalho", "DecorativeEffects", accessibilityConfig,
	function() applyAccessibilityLayout(false) end)
makeToggle("Notificações", "Controla avisos temporários no cabeçalho", "Notifications", accessibilityConfig)
makeToggle("Avisos de chat", "Notificações de macros e envio", "ChatNotifications", accessibilityConfig)
makeToggle("Avisos de perfil", "Notificações de salvar e carregar", "ProfileNotifications", accessibilityConfig)
makeToggle("Avisos de diagnóstico", "Notificações de validação", "DiagnosticNotifications", accessibilityConfig)
makeToggle("Avisos de erro", "Notificações de falha em ações", "ErrorNotifications", accessibilityConfig)
applyAccessibilityTheme()
FeatureModules.Accessibility = {
	Config = accessibilityConfig,
	ApplyTheme = applyAccessibilityTheme,
	ApplyLayout = applyAccessibilityLayout,
	Cleanup = function()
		notificationToken += 1
		if notificationTask then
			pcall(task.cancel, notificationTask)
			notificationTask = nil
		end
	end,
}
end

local captureProfile
local validateClientProfile
local applyProfileData
local resetTabValues
local resetAllValues
local applyNamedPreset
local loadServerProfile
local restartModules
-- Profile and diagnostics page state is scoped to its page-building block.

-- PROFILES: un único formato versionado para todos los módulos.
do
local profileStorageStatus
content = pages.PROFILES
addSection("PERFIL UNIFICADO · FORMATO v1")
makePageLabel(content, "Autosave com debounce; armazenamento permanente usa o Script de servidor opcional. Sem ele, use exportação/importação JSON.", 40)
makePageLabel(content, "Reset Tab usa a última aba de módulo visitada antes de abrir PROFILES.", 24, COLORS.muted)
profileStorageStatus = makePageLabel(content, "Persistência: verificando o servidor...", 32, COLORS.accent)
makeActionRow(content, {
	{ text = "COMPETITIVE", primary = true, callback = function()
		requestConfirmation("Aplicar Competitive e substituir todas as configurações atuais?", function()
			if applyNamedPreset then applyNamedPreset("Competitive") end
		end)
	end },
	{ text = "LOW-END", callback = function()
		requestConfirmation("Aplicar Low-End e substituir todas as configurações atuais?", function()
			if applyNamedPreset then applyNamedPreset("Low-End") end
		end)
	end },
	{ text = "CUSTOM", callback = function()
		profileRevision += 1
		activeProfile = "CUSTOM"
		profileStatus.Text = "PERFIL ATIVO: CUSTOM"
		if scheduleProfileSave then scheduleProfileSave() end
	end },
})
makeActionRow(content, {
	{ text = "RESET TAB", callback = function()
		local resetTarget = activePageId == "PROFILES" and lastSettingsPageId or activePageId
		requestConfirmation("Restaurar os padrões da aba " .. resetTarget .. "?", function()
			if resetTabValues then resetTabValues(resetTarget) end
		end)
	end },
	{ text = "RESET ALL", primary = true, callback = function()
		requestConfirmation("Restaurar todos os módulos aos padrões e substituir o perfil salvo?", function()
			if resetAllValues then resetAllValues() end
		end)
	end },
})
local profileJsonInput = makePageTextBox(content, "IMPORTAR / EXPORTAR JSON", "JSON do perfil", "", 118)
makeActionRow(content, {
	{ text = "EXPORTAR", callback = function()
		if not captureProfile then return end
		local ok, json = pcall(function()
			return HttpService:JSONEncode(captureProfile())
		end)
		if ok then
			profileJsonInput.Text = json
			profileStorageStatus.Text = "JSON pronto. Selecione o campo e use Ctrl+A / Ctrl+C."
			profileJsonInput:CaptureFocus()
		else
			profileStorageStatus.Text = "Falha ao exportar o JSON."
			logDiagnostic("JSON export: " .. tostring(json))
		end
	end },
	{ text = "IMPORTAR", primary = true, callback = function()
		if #profileJsonInput.Text > 30000 then
			profileStorageStatus.Text = "JSON excede o limite de 30 KB."
			return
		end
		local ok, decoded = pcall(function() return HttpService:JSONDecode(profileJsonInput.Text) end)
		if not ok or not validateClientProfile then
			profileStorageStatus.Text = "JSON inválido ou versão incompatível."
			logDiagnostic("Importação JSON inválida")
			return
		end
		local valid, clean = validateClientProfile(decoded)
		if not valid then
			profileStorageStatus.Text = "Perfil inválido: " .. tostring(clean)
			return
		end
		requestConfirmation("Substituir todas as configurações pelo perfil importado?", function()
			if applyProfileData then applyProfileData(clean, "IMPORTADO", true) end
		end)
	end },
	{ text = "CARREGAR SERVIDOR", callback = function()
		if loadServerProfile then loadServerProfile(true) end
	end },
})
makeActionRow(content, {
	{ text = "SALVAR AGORA", primary = true, callback = function()
		if scheduleProfileSave then scheduleProfileSave(true) end
	end },
})
FeatureModules.Profile = { Status = profileStorageStatus }
end

-- CONTROLS: um único dispatcher global, sem ligações novas ao rebind.
do
content = pages.CONTROLS
local controlsConfig = ModuleConfig.Controls
local pendingBindAction
local controlsStatus
local controlsBindingsLabel
local bindActionOrder = { "OpenPanel", "ToggleAim", "ToggleCrosshair", "ToggleHUD", "Macro1", "Macro2", "Macro3" }
local bindActionNames = {
	OpenPanel = "Abrir painel", ToggleAim = "Alternar Aim NPC", ToggleCrosshair = "Alternar crosshair",
	ToggleHUD = "Alternar HUD", Macro1 = "Favorito de chat 1", Macro2 = "Favorito de chat 2", Macro3 = "Favorito de chat 3",
}

local function bindingDisplay(key)
	return key == "" and "—" or key
end

local function refreshControlsDisplay()
	if not controlsBindingsLabel then return end
	local lines = { "CAPSLOCK também abre o painel · ESC fecha · toque usa botão flutuante." }
	for _, action in ipairs(bindActionOrder) do
		local extra = action == "OpenPanel" and " (ou CapsLock)" or ""
		lines[#lines + 1] = bindActionNames[action] .. ": " .. bindingDisplay(controlsConfig[action]) .. extra
	end
	controlsBindingsLabel.Text = table.concat(lines, "\n")
end

local function getInputBindName(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode ~= Enum.KeyCode.Unknown then return input.KeyCode.Name end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton2
		or input.UserInputType == Enum.UserInputType.MouseButton3 then
		return input.UserInputType.Name
	end
	return nil
end

local function isValidBindName(key)
	if key == "MouseButton1" or key == "MouseButton2" or key == "MouseButton3" then
		return true
	end
	for _, enumItem in ipairs(Enum.KeyCode:GetEnumItems()) do
		if enumItem.Name == key and enumItem ~= Enum.KeyCode.Unknown then
			return true
		end
	end
	return false
end

local function findBindConflict(key, exceptAction)
	if key == "Escape" then return "ESC é reservado para fechar o painel." end
	if key == "CapsLock" and exceptAction ~= "OpenPanel" then
		return "CapsLock já abre o painel."
	end
	for _, action in ipairs(bindActionOrder) do
		if action ~= exceptAction and controlsConfig[action] == key then
			return "Conflito com " .. bindActionNames[action] .. "."
		end
	end
	return nil
end

local function beginBindCapture(action)
	pendingBindAction = action
	controlsStatus.Text = "Pressione uma tecla ou botão do mouse..."
end

local touchGui = make("ScreenGui", playerGui, {
	Name = "ZKXTouchControls",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 11000,
	Enabled = UserInputService.TouchEnabled,
})
local touchOpenButton = make("TextButton", touchGui, {
	Name = "OpenPanel",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.55, 0),
	Size = UDim2.fromOffset(54, 54),
	BackgroundColor3 = COLORS.accentDark,
	BorderSizePixel = 0,
	Text = "ZKX",
	TextColor3 = COLORS.accent,
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	AutoButtonColor = false,
})
addCorner(touchOpenButton, 16)
setTouchButtonVisibility = function()
	touchOpenButton.Visible = UserInputService.TouchEnabled and not panelOpen
end
setTouchButtonVisibility()
connect(touchOpenButton.Activated, function()
	if ready then setPanelOpen(not panelOpen) end
end)

addSection("ATALHOS ATIVOS")
makeToggle("Atalhos dos módulos", "Painel e ESC continuam disponíveis", "Enabled", controlsConfig, function()
	refreshControlsDisplay()
end)
controlsBindingsLabel = makePageLabel(content, "", 164, COLORS.text)
refreshControlsDisplay()
controlsStatus = makePageLabel(content, "Escolha CONFIGURAR e pressione uma tecla. Teclas conflitantes serão rejeitadas.", 32, COLORS.accent)
for _, action in ipairs(bindActionOrder) do
	makeActionRow(content, {
		{ text = "CONFIGURAR " .. bindActionNames[action], callback = function()
			beginBindCapture(action)
		end },
	})
end
makeActionRow(content, {
	{ text = "RESTAURAR ATALHOS", callback = function()
		requestConfirmation("Restaurar os atalhos padrão?", function()
			for key, value in pairs(DEFAULT_MODULE_CONFIG.Controls) do controlsConfig[key] = value end
			refreshControlsDisplay()
			markCustom()
		end)
	end },
})
FeatureModules.TouchGui = touchGui
FeatureModules.Controls = {
	Config = controlsConfig,
	Refresh = refreshControlsDisplay,
	IsValidBindName = isValidBindName,
	FindConflict = findBindConflict,
	GetInputBindName = getInputBindName,
	ActionOrder = bindActionOrder,
	CaptureInput = function(key)
		if not pendingBindAction then return false end
		if key == "Escape" then
			pendingBindAction = nil
			controlsStatus.Text = "Captura de atalho cancelada."
			return true
		end
		if not key or not isValidBindName(key) then
			controlsStatus.Text = "Entrada não suportada. Use teclado ou botão do mouse."
			return true
		end
		local action = pendingBindAction
		local conflict = findBindConflict(key, action)
		if conflict then
			controlsStatus.Text = conflict
			logDiagnostic("Atalho recusado " .. key .. ": " .. conflict)
		else
			controlsConfig[action] = key
			controlsStatus.Text = bindActionNames[action] .. " configurado: " .. key
			refreshControlsDisplay()
			markCustom()
		end
		pendingBindAction = nil
		return true
	end,
	CancelCapture = function()
		if pendingBindAction then
			pendingBindAction = nil
			if controlsStatus and controlsStatus.Parent then
				controlsStatus.Text = "Captura de atalho cancelada."
			end
		end
	end,
}
end

-- DIAGNOSTICS: estados e histórico finito de erros relevantes.
do
content = pages.DIAGNOSTICS
local diagnosticsStateLabel
local diagnosticsLogLabel
local debugMode = false
local function currentModuleStates()
	return {
		"Otimização: ativa (" .. (FeatureModules.HUD.GraphicsActive() and "alterações aplicadas" or "padrão") .. ")",
		"Aim Help NPC: " .. (AimAssist.GetActive() and "ativo" or "desativado"),
		"Hitbox debug: " .. (FeatureModules.Hitbox.Config.Enabled and "ativo" or "desativado"),
		"Macros de chat: " .. tostring(#FeatureModules.Chat.Config.Macros) .. " cadastradas",
		"Crosshair: " .. (FeatureModules.Crosshair.Config.Enabled and "visível" or "oculto"),
		"HUD: " .. (FeatureModules.HUD.Config.Enabled and "ativo" or "desativado"),
		"Conexões globais rastreadas: " .. tostring(#globalConnections),
		"Configuração: v" .. tostring(DEFAULT_MODULE_CONFIG.Version),
	}
end

updateDiagnosticsPage = function()
	if diagnosticsStateLabel then
		diagnosticsStateLabel.Text = table.concat(currentModuleStates(), "\n")
	end
	if diagnosticsLogLabel then
		diagnosticsLogLabel.Text = #diagnosticEntries > 0
			and table.concat(diagnosticEntries, "\n") or "Sem erros registrados."
	end
end

addSection("ESTADO E MANUTENÇÃO")
diagnosticsStateLabel = makePageLabel(content, "", 168, COLORS.text)
makeActionRow(content, {
	{ text = "LIMPAR LOG", callback = function()
		table.clear(diagnosticEntries)
		updateDiagnosticsPage()
	end },
	{ text = "VALIDAR PERFIL", callback = function()
		if validateClientProfile and captureProfile then
			local valid, reason = validateClientProfile(captureProfile())
			if valid then
				logDiagnostic("Validação de perfil concluída")
				showNotice("Perfil válido", "Diagnostic")
			else
				logDiagnostic("Validação: " .. tostring(reason))
				showNotice("Perfil inválido", "Diagnostic")
			end
		end
		updateDiagnosticsPage()
	end },
	{ text = "REINICIAR MÓDULOS", primary = true, callback = function()
		if restartModules then restartModules() end
	end },
})
diagnosticsLogLabel = makePageLabel(content, "Sem erros registrados.", 150)
makeActionRow(content, {
	{ text = "MODO DEBUG", callback = function()
		debugMode = not debugMode
		if debugMode then
			local ok, memory = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
			logDiagnostic(ok and ("Memória processo: " .. tostring(math.floor(memory)) .. " MB")
				or "Métrica de memória indisponível")
		else
			logDiagnostic("Modo debug desativado")
		end
		updateDiagnosticsPage()
	end },
})
updateDiagnosticsPage()
FeatureModules.Diagnostics = {
	Update = updateDiagnosticsPage,
	StateLabel = diagnosticsStateLabel,
	LogLabel = diagnosticsLogLabel,
}
end

local function makeDefaultProfile()
	local aim = deepCopy(DEFAULT_AIM_CONFIG)
	aim.IndicatorColor = colorToHex(aim.IndicatorColor)
	return {
		Version = DEFAULT_MODULE_CONFIG.Version,
		Preset = "PC ANTIGO",
		Graphics = deepCopy(PC_ANTIGO),
		Aim = aim,
		Hitbox = deepCopy(DEFAULT_MODULE_CONFIG.Hitbox),
		Crosshair = deepCopy(DEFAULT_MODULE_CONFIG.Crosshair),
		Chat = deepCopy(DEFAULT_MODULE_CONFIG.Chat),
		HUD = deepCopy(DEFAULT_MODULE_CONFIG.HUD),
		Accessibility = deepCopy(DEFAULT_MODULE_CONFIG.Accessibility),
		Controls = deepCopy(DEFAULT_MODULE_CONFIG.Controls),
	}
end

captureProfile = function()
	local aim = {}
	for key, value in pairs(AimConfig) do
		if key ~= "ToggleKey" then aim[key] = value end
	end
	aim.IndicatorColor = colorToHex(AimConfig.IndicatorColor)
	return {
		Version = DEFAULT_MODULE_CONFIG.Version,
		Preset = activeProfile,
		Graphics = deepCopy(Config),
		Aim = aim,
		Hitbox = deepCopy(FeatureModules.Hitbox.Config),
		Crosshair = deepCopy(FeatureModules.Crosshair.Config),
		Chat = deepCopy(FeatureModules.Chat.Config),
		HUD = deepCopy(FeatureModules.HUD.Config),
		Accessibility = deepCopy(FeatureModules.Accessibility.Config),
		Controls = deepCopy(FeatureModules.Controls.Config),
	}
end

local function sanitizeGroup(source, defaults, rules, groupName)
	local clean = deepCopy(defaults)
	if source == nil then return clean end
	if type(source) ~= "table" then
		logDiagnostic(groupName .. " inválido; padrões restaurados")
		return clean
	end
	for key, rule in pairs(rules) do
		local value = source[key]
		if value ~= nil then
			local valid = false
			if rule.type == "boolean" then
				valid = type(value) == "boolean"
			elseif rule.type == "number" then
				valid = type(value) == "number" and value == value
					and math.abs(value) < math.huge and value >= rule.min and value <= rule.max
			elseif rule.type == "string" then
				valid = type(value) == "string" and #value >= (rule.min or 0)
					and #value <= rule.max and value:find("%c") == nil
			elseif rule.type == "hex" then
				valid = type(value) == "string" and normalizeHex(value) ~= nil
			elseif rule.type == "enum" then
				valid = type(value) == "string" and rule.values[value] == true
			end
			if valid then
				clean[key] = rule.type == "hex" and normalizeHex(value) or value
			else
				logDiagnostic(groupName .. "." .. key .. " inválido; padrão restaurado")
			end
		end
	end
	return clean
end

validateClientProfile = function(input)
	if type(input) ~= "table" or input.Version ~= DEFAULT_MODULE_CONFIG.Version then
		return false, "versão ausente ou incompatível"
	end
	local clean = makeDefaultProfile()
	local rootName = input.Preset
	if type(rootName) == "string" and #rootName <= 30 and rootName:find("%c") == nil then
		clean.Preset = rootName
	end
	local graphicsDefaults = deepCopy(PC_ANTIGO)
	local graphicsRules = {}
	for key, value in pairs(graphicsDefaults) do
		graphicsRules[key] = { type = type(value) }
	end
	graphicsRules.ParticleRateMultiplier = { type = "number", min = 0, max = 1 }
	clean.Graphics = sanitizeGroup(input.Graphics, graphicsDefaults, graphicsRules, "Graphics")

	local aimDefaults = deepCopy(DEFAULT_AIM_CONFIG)
	aimDefaults.IndicatorColor = colorToHex(aimDefaults.IndicatorColor)
	local aimRules = {}
	for key, value in pairs(aimDefaults) do
		if type(value) == "boolean" then
			aimRules[key] = { type = "boolean" }
		elseif type(value) == "number" then
			local bounds = {
				Intensity = { 0, 1 }, Friction = { 0, 0.8 }, FrictionAngleDeg = { 0.1, 60 },
				Smoothing = { 0.001, 1 }, MaxAssistDegPerSec = { 0, 600 }, SpeedReferenceDeg = { 1, 100 },
				MaxDistance = { 1, 1000 }, MaxAngleDeg = { 1, 85 }, KeepAngleMultiplier = { 1, 3 },
				ScanInterval = { 0.01, 1 }, CandidateRefresh = { 0.05, 5 }, SwitchMargin = { 0, 3 },
				ClickAssistToleranceStuds = { 0, 10 }, ClickAssistMaxDeg = { 0, 15 }, ClickAssistInward = { 0, 1 },
				ClickAssistStrength = { 0, 1 }, ClickAssistCooldown = { 0.1, 10 }, IndicatorSize = { 4, 64 },
			}
			local bound = bounds[key]
			if bound then aimRules[key] = { type = "number", min = bound[1], max = bound[2] } end
		elseif key == "IndicatorColor" then
			aimRules[key] = { type = "hex" }
		elseif key == "AimPartName" then
			aimRules[key] = { type = "string", min = 1, max = 32 }
		elseif key == "TargetTag" then
			aimRules[key] = { type = "string", min = 1, max = 40 }
		end
	end
	clean.Aim = sanitizeGroup(input.Aim, aimDefaults, aimRules, "Aim")

	clean.Hitbox = sanitizeGroup(input.Hitbox, DEFAULT_MODULE_CONFIG.Hitbox, {
		Enabled = { type = "boolean" }, Tag = { type = "string", min = 1, max = 40 }, Color = { type = "hex" },
		OutlineColor = { type = "hex" },
		Fill = { type = "boolean" }, FillTransparency = { type = "number", min = 0, max = 1 },
		Outline = { type = "boolean" }, Thickness = { type = "number", min = 0, max = 0.08 },
	}, "Hitbox")
	clean.Crosshair = sanitizeGroup(input.Crosshair, DEFAULT_MODULE_CONFIG.Crosshair, {
		Enabled = { type = "boolean" }, Color = { type = "hex" },
		Preset1 = { type = "string", max = 512 }, Preset2 = { type = "string", max = 512 },
		Preset3 = { type = "string", max = 512 }, Size = { type = "number", min = 2, max = 30 },
		Thickness = { type = "number", min = 1, max = 8 }, Gap = { type = "number", min = 0, max = 24 },
		Transparency = { type = "number", min = 0, max = 0.9 }, Outline = { type = "boolean" },
		Shape = { type = "enum", values = { Cross = true, Dot = true } },
		OffsetX = { type = "number", min = -100, max = 100 }, OffsetY = { type = "number", min = -100, max = 100 },
	}, "Crosshair")
	clean.HUD = sanitizeGroup(input.HUD, DEFAULT_MODULE_CONFIG.HUD, {
		Enabled = { type = "boolean" }, FPS = { type = "boolean" }, Ping = { type = "boolean" },
		Session = { type = "boolean" }, Keys = { type = "boolean" }, Modules = { type = "boolean" },
		HideWhenPanelOpen = { type = "boolean" }, PositionX = { type = "number", min = 0, max = 0.92 },
		PositionY = { type = "number", min = 0, max = 0.92 }, Scale = { type = "number", min = 0.6, max = 1.4 },
		Transparency = { type = "number", min = 0, max = 0.8 },
	}, "HUD")
	clean.Accessibility = sanitizeGroup(input.Accessibility, DEFAULT_MODULE_CONFIG.Accessibility, {
		Theme = { type = "enum", values = { Dark = true, Light = true } },
		Scale = { type = "number", min = 0.7, max = 1.25 }, Opacity = { type = "number", min = 0, max = 0.55 },
		HighContrast = { type = "boolean" }, ReducedMotion = { type = "boolean" },
		DecorativeEffects = { type = "boolean" }, Compact = { type = "boolean" },
		ControlSize = { type = "number", min = 0.85, max = 1.2 }, Notifications = { type = "boolean" },
		ChatNotifications = { type = "boolean" }, ProfileNotifications = { type = "boolean" },
		DiagnosticNotifications = { type = "boolean" }, ErrorNotifications = { type = "boolean" },
	}, "Accessibility")
	clean.Controls = sanitizeGroup(input.Controls, DEFAULT_MODULE_CONFIG.Controls, {
		Enabled = { type = "boolean" }, OpenPanel = { type = "string", max = 24 },
		ToggleAim = { type = "string", max = 24 }, ToggleCrosshair = { type = "string", max = 24 },
		ToggleHUD = { type = "string", max = 24 }, Macro1 = { type = "string", max = 24 },
		Macro2 = { type = "string", max = 24 }, Macro3 = { type = "string", max = 24 },
	}, "Controls")

	local chat = deepCopy(DEFAULT_MODULE_CONFIG.Chat)
	local sourceChat = type(input.Chat) == "table" and input.Chat or {}
	local interval = sourceChat.Interval
	if type(interval) == "number" and interval == interval and math.abs(interval) < math.huge
		and interval >= 60 and interval <= 300 then
		chat.Interval = math.floor(interval + 0.5)
	end
	local seenMacroIds = {}
	if type(sourceChat.Macros) == "table" then
		for index, macro in ipairs(sourceChat.Macros) do
			if index > 40 then break end
			if type(macro) == "table" and type(macro.Id) == "string" and #macro.Id <= 40
				and #macro.Id > 0 and type(macro.Title) == "string" and #macro.Title >= 1 and #macro.Title <= 32
				and type(macro.Category) == "string" and #macro.Category >= 1 and #macro.Category <= 20
				and type(macro.Message) == "string" and #macro.Message >= 1 and #macro.Message <= 200
				and not macro.Id:find("%c") and not seenMacroIds[macro.Id]
				and not macro.Title:find("%c") and not macro.Category:find("%c") and not macro.Message:find("%c") then
				seenMacroIds[macro.Id] = true
				table.insert(chat.Macros, {
					Id = macro.Id, Title = macro.Title, Category = macro.Category, Message = macro.Message,
				})
			else
				logDiagnostic("Macro inválida ignorada durante a recuperação")
			end
		end
	end
	if type(sourceChat.Favorites) == "table" then
		for slot = 1, 3 do
			local id = sourceChat.Favorites[slot]
			if type(id) == "string" and #id <= 40 then chat.Favorites[slot] = id end
		end
	end
	for slot = 1, 3 do
		local found = false
		for _, macro in ipairs(chat.Macros) do
			if chat.Favorites[slot] == macro.Id then
				found = true
				break
			end
		end
		if not found then chat.Favorites[slot] = "" end
	end
	clean.Chat = chat

	local seenBinds = {}
	for _, action in ipairs(FeatureModules.Controls.ActionOrder) do
		local key = clean.Controls[action]
		local invalid = key ~= "" and (not FeatureModules.Controls.IsValidBindName(key)
			or key == "Escape" or (key == "CapsLock" and action ~= "OpenPanel") or seenBinds[key])
		if invalid then
			logDiagnostic("Atalho inválido restaurado: " .. action)
			key = DEFAULT_MODULE_CONFIG.Controls[action]
			if key ~= "" and (not FeatureModules.Controls.IsValidBindName(key) or key == "Escape"
				or (key == "CapsLock" and action ~= "OpenPanel") or seenBinds[key]) then
				key = ""
			end
			clean.Controls[action] = key
		end
		if key ~= "" then seenBinds[key] = true end
	end
	return true, clean
end

local loadingProfile = false
applyProfileData = function(clean, profileName, shouldAutosave)
	loadingProfile = true
	profileRevision += 1
	local applied, applyError = pcall(function()
		FeatureModules.Hitbox.CancelPreview()
		FeatureModules.Crosshair.CancelPreview()
		FeatureModules.Controls.CancelCapture()
		for key in pairs(Config) do Config[key] = nil end
		for key, value in pairs(clean.Graphics) do Config[key] = value end
		for key, value in pairs(clean.Aim) do
			if key ~= "IndicatorColor" then AimConfig[key] = value end
		end
		AimConfig.IndicatorColor = colorFromHex(clean.Aim.IndicatorColor) or DEFAULT_AIM_CONFIG.IndicatorColor
		for key, value in pairs(clean.Hitbox) do FeatureModules.Hitbox.Config[key] = value end
		for key, value in pairs(clean.Crosshair) do FeatureModules.Crosshair.Config[key] = value end
		for key, value in pairs(clean.Chat) do FeatureModules.Chat.Config[key] = deepCopy(value) end
		for key, value in pairs(clean.HUD) do FeatureModules.HUD.Config[key] = value end
		for key, value in pairs(clean.Accessibility) do FeatureModules.Accessibility.Config[key] = value end
		for key, value in pairs(clean.Controls) do FeatureModules.Controls.Config[key] = value end
		activeProfile = profileName or clean.Preset or "CUSTOM"
		profileStatus.Text = "PERFIL ATIVO: " .. activeProfile
		applyAll(false)
		for key, value in pairs(AimConfig) do
			if key ~= "Active" and key ~= "ToggleKey" then
				pcall(function() AimAssist.SetConfig(key, value) end)
			end
		end
		AimAssist.SetActive(AimConfig.Active)
		refreshUI()
		FeatureModules.Hitbox.SyncInputs()
		FeatureModules.Hitbox.RefreshList()
		FeatureModules.Crosshair.SyncInputs()
		FeatureModules.Crosshair.Update()
		FeatureModules.HUD.Refresh()
		FeatureModules.Accessibility.ApplyTheme()
		FeatureModules.Controls.Refresh()
		FeatureModules.Chat.Display(nil)
		updateDiagnosticsPage()
	end)
	loadingProfile = false
	if not applied then
		FeatureModules.Profile.Status.Text = "Falha ao aplicar o perfil; consulte DIAGNOSTICS."
		logDiagnostic("Aplicação do perfil falhou: " .. tostring(applyError))
		return false
	end
	if shouldAutosave and scheduleProfileSave then scheduleProfileSave() end
	return true
end

local profileRemote
local PROFILE_SAVE_DEBOUNCE = 2
local PROFILE_SAVE_MIN_INTERVAL = 1.4
local PROFILE_LOAD_MIN_INTERVAL = 3.1
local function getProfileRemote(waitSeconds)
	if profileRemote then
		local ok, available = pcall(function()
			return profileRemote.Parent ~= nil and profileRemote:IsA("RemoteFunction")
		end)
		if ok and available then return profileRemote end
		profileRemote = nil
	end
	local found = ReplicatedStorage:FindFirstChild("ZKXProfileStore")
	if not found and waitSeconds and waitSeconds > 0 then
		found = ReplicatedStorage:WaitForChild("ZKXProfileStore", waitSeconds)
	end
	if found and found:IsA("RemoteFunction") then
		profileRemote = found
	end
	return profileRemote
end
local saveGeneration = 0
local saveInFlight = false
local loadInFlight = false
local saveAgain = false
local saveTask
local lastSaveStartedAt = -math.huge
local lastLoadStartedAt = -math.huge
local function saveProfileNow()
	if loadingProfile or shuttingDown then return end
	if loadInFlight then
		saveAgain = true
		return
	end
	if not getProfileRemote(1) then
		FeatureModules.Profile.Status.Text = "Sem Script de servidor: alterações ficam nesta sessão. Exporte o JSON para guardar."
		return
	end
	if saveInFlight then
		saveAgain = true
		return
	end
	if os.clock() - lastSaveStartedAt < PROFILE_SAVE_MIN_INTERVAL then
		if scheduleProfileSave then scheduleProfileSave() end
		return
	end
	local valid, snapshotOrError = validateClientProfile(captureProfile())
	if not valid then
		FeatureModules.Profile.Status.Text = "Autosave cancelado: perfil inválido."
		logDiagnostic("Autosave bloqueado: " .. tostring(snapshotOrError))
		return
	end
	saveInFlight = true
	lastSaveStartedAt = os.clock()
	FeatureModules.Profile.Status.Text = "Salvando perfil..."
	task.spawn(function()
		local ok, success, reason = pcall(function()
			return profileRemote:InvokeServer("Save", snapshotOrError)
		end)
		saveInFlight = false
		if shuttingDown then return end
		if ok and success then
			FeatureModules.Profile.Status.Text = "Salvo no DataStore do servidor."
		else
			FeatureModules.Profile.Status.Text = "Falha ao salvar: " .. tostring(ok and reason or success)
			logDiagnostic("Autosave falhou: " .. tostring(ok and reason or success))
		end
		if saveAgain then
			saveAgain = false
			if scheduleProfileSave then scheduleProfileSave() end
		end
	end)
end

scheduleProfileSave = function(immediate)
	if loadingProfile or shuttingDown then return end
	saveGeneration += 1
	local generation = saveGeneration
	FeatureModules.Profile.Status.Text = profileRemote and "Alterações pendentes..." or "Sem servidor: exporte o JSON para persistir."
	if saveTask then
		pcall(task.cancel, saveTask)
		saveTask = nil
	end
	saveTask = task.delay(immediate and 0 or PROFILE_SAVE_DEBOUNCE, function()
		saveTask = nil
		if generation == saveGeneration and not shuttingDown then saveProfileNow() end
	end)
end

loadServerProfile = function(confirmReplace)
	local function performLoad()
		if shuttingDown then return end
		if loadInFlight then
			FeatureModules.Profile.Status.Text = "Já existe um carregamento em andamento."
			return
		end
		if saveInFlight or saveTask then
			FeatureModules.Profile.Status.Text = "Aguarde o autosave pendente antes de carregar."
			return
		end
		local loadRemaining = PROFILE_LOAD_MIN_INTERVAL - (os.clock() - lastLoadStartedAt)
		if loadRemaining > 0 then
			FeatureModules.Profile.Status.Text = string.format("Aguarde %.1f s antes de carregar novamente.", loadRemaining)
			return
		end
		loadInFlight = true
		lastLoadStartedAt = os.clock()
		local revisionAtStart = profileRevision
		local completed, loadError = pcall(function()
			FeatureModules.Profile.Status.Text = "Carregando configuração do servidor..."
			if not getProfileRemote(3) then
				FeatureModules.Profile.Status.Text = "Persistência indisponível; use exportação JSON ou instale o Script de servidor."
				return
			end
			local requestOk, success, dataOrReason = pcall(function()
				return profileRemote:InvokeServer("Load")
			end)
			if shuttingDown then return end
			if not requestOk or not success then
				FeatureModules.Profile.Status.Text = "Falha ao carregar: " .. tostring(requestOk and dataOrReason or success)
				logDiagnostic("Load do perfil falhou: " .. tostring(requestOk and dataOrReason or success))
				return
			end
			if dataOrReason == nil then
				FeatureModules.Profile.Status.Text = "Sem perfil salvo; usando padrões locais."
				return
			end
			local valid, cleanOrError = validateClientProfile(dataOrReason)
			if not valid then
				FeatureModules.Profile.Status.Text = "Perfil do servidor inválido; padrões mantidos."
				logDiagnostic("Perfil salvo rejeitado: " .. tostring(cleanOrError))
				return
			end
			if profileRevision ~= revisionAtStart then
				FeatureModules.Profile.Status.Text = "Configurações alteradas durante o carregamento; perfil não aplicado."
				logDiagnostic("Load cancelado para preservar alterações locais recentes")
				return
			end
			local applied = applyProfileData(cleanOrError, cleanOrError.Preset, false)
			if not applied then return end
			FeatureModules.Profile.Status.Text = "Perfil carregado do servidor."
			showNotice("Perfil carregado do servidor", "Profile")
		end)
		loadInFlight = false
		if not completed and not shuttingDown then
			FeatureModules.Profile.Status.Text = "Falha ao carregar o perfil; consulte DIAGNOSTICS."
			logDiagnostic("Load do perfil interrompido: " .. tostring(loadError))
		end
		if saveAgain then
			saveAgain = false
			if scheduleProfileSave then scheduleProfileSave() end
		end
	end
	if confirmReplace then
		requestConfirmation("Substituir as configurações atuais pelo perfil do servidor?", function()
			task.spawn(performLoad)
		end)
	else
		performLoad()
	end
end

local function resetOneTable(target, defaults)
	for key in pairs(target) do target[key] = nil end
	for key, value in pairs(defaults) do target[key] = deepCopy(value) end
end

resetTabValues = function(pageId)
	if pageId == "OPT" then
		resetOneTable(Config, PC_ANTIGO)
		activeProfile = "PC ANTIGO"
		applyAll(false)
	elseif pageId == "AIM" then
		resetOneTable(AimConfig, DEFAULT_AIM_CONFIG)
		for key, value in pairs(AimConfig) do
			if key ~= "Active" and key ~= "ToggleKey" then
				pcall(function() AimAssist.SetConfig(key, value) end)
			end
		end
		AimAssist.SetActive(AimConfig.Active)
	elseif pageId == "HITBOX" then
		FeatureModules.Hitbox.CancelPreview()
		resetOneTable(FeatureModules.Hitbox.Config, DEFAULT_MODULE_CONFIG.Hitbox)
		FeatureModules.Hitbox.ResetSelection()
		FeatureModules.Hitbox.SyncInputs()
	elseif pageId == "CHAT" then
		resetOneTable(FeatureModules.Chat.Config, DEFAULT_MODULE_CONFIG.Chat)
		FeatureModules.Chat.Display(nil)
	elseif pageId == "CROSSHAIR" then
		resetOneTable(FeatureModules.Crosshair.Config, DEFAULT_MODULE_CONFIG.Crosshair)
		FeatureModules.Crosshair.SyncInputs()
		FeatureModules.Crosshair.Disable()
	elseif pageId == "CONTROLS" then
		FeatureModules.Controls.CancelCapture()
		resetOneTable(FeatureModules.Controls.Config, DEFAULT_MODULE_CONFIG.Controls)
		FeatureModules.Controls.Refresh()
	elseif pageId == "HUD" then
		resetOneTable(FeatureModules.HUD.Config, DEFAULT_MODULE_CONFIG.HUD)
		FeatureModules.HUD.Refresh()
	elseif pageId == "ACCESSIBILITY" then
		resetOneTable(FeatureModules.Accessibility.Config, DEFAULT_MODULE_CONFIG.Accessibility)
		FeatureModules.Accessibility.ApplyTheme()
	elseif pageId == "DIAGNOSTICS" then
		table.clear(diagnosticEntries)
		updateDiagnosticsPage()
	end
	refreshUI()
	if pageId ~= "DIAGNOSTICS" then markCustom() end
end

resetAllValues = function()
	local valid, clean = validateClientProfile(makeDefaultProfile())
	if not valid or not applyProfileData(clean, "PC ANTIGO", true) then return end
	FeatureModules.Hitbox.ResetSelection()
	table.clear(diagnosticEntries)
	updateDiagnosticsPage()
	if scheduleProfileSave then scheduleProfileSave(true) end
end

applyNamedPreset = function(name)
	local preset = makeDefaultProfile()
	if name == "Competitive" then
		preset.Preset = "Competitive"
		preset.Graphics = {
			DisableGlobalShadows = false, DisableLightShadows = false, DisablePostEffects = false,
			ReduceParticles = false, ParticleRateMultiplier = 1, ClearExistingParticles = false,
			DisableTrailsAndBeams = false, DisableAtmosphere = false, ReduceTerrainWaterEffects = false,
		}
	elseif name == "Low-End" then
		preset.Preset = "Low-End"
		preset.Aim.Active = false
		preset.HUD.Enabled = false
		preset.Accessibility.Compact = true
		preset.Accessibility.Scale = 0.9
		preset.Accessibility.ReducedMotion = true
		preset.Accessibility.DecorativeEffects = false
	else
		return
	end
	applyProfileData(preset, name, true)
end

restartModules = function()
	local ok, err = pcall(function()
		applyAll(false)
		AimAssist.Stop()
		AimAssist.Start()
		FeatureModules.Hitbox.Update()
		FeatureModules.Crosshair.Update()
		FeatureModules.HUD.Refresh()
	end)
	if not ok then logDiagnostic("Reinicialização: " .. tostring(err)) end
	updateDiagnosticsPage()
end
local footer = make("Frame", panel, {
	Position = UDim2.new(0, 16, 1, -50),
	Size = UDim2.new(1, -32, 0, 36),
	BackgroundTransparency = 1,
})
make("TextLabel", footer, {
	Size = UDim2.new(1, -190, 1, 0),
	BackgroundTransparency = 1,
	Text = "CAPSLOCK / INSERT ABRE  ·  G MIRA  ·  ESC FECHA",
	TextColor3 = COLORS.muted,
	Font = Enum.Font.GothamMedium,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
})

local resetButton = make("TextButton", footer, {
	Position = UDim2.new(1, -178, 0, 0),
	Size = UDim2.fromOffset(82, 34),
	BackgroundColor3 = COLORS.card,
	BorderSizePixel = 0,
	Text = "PC ANTIGO",
	TextColor3 = COLORS.text,
	Font = Enum.Font.GothamBold,
	TextSize = 9,
	AutoButtonColor = false,
})
addCorner(resetButton, 8)
local footerClose = make("TextButton", footer, {
	Position = UDim2.new(1, -88, 0, 0),
	Size = UDim2.fromOffset(82, 34),
	BackgroundColor3 = COLORS.accentDark,
	BorderSizePixel = 0,
	Text = "FECHAR",
	TextColor3 = COLORS.accent,
	Font = Enum.Font.GothamBold,
	TextSize = 9,
	AutoButtonColor = false,
})
addCorner(footerClose, 8)

confirmationOverlay = make("Frame", panel, {
	Name = "ConfirmationOverlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = COLORS.background,
	BackgroundTransparency = 0.18,
	BorderSizePixel = 0,
	Active = true,
	Visible = false,
	ZIndex = 200,
})
local confirmationCard = make("Frame", confirmationOverlay, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.86, 0, 0, 194),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
	ZIndex = 201,
})
addCorner(confirmationCard, 12)
addStroke(confirmationCard, COLORS.line, 0.1)
local confirmationText = make("TextLabel", confirmationCard, {
	Position = UDim2.new(0, 14, 0, 12),
	Size = UDim2.new(1, -28, 1, -64),
	BackgroundTransparency = 1,
	Text = "Confirmar ação?",
	TextColor3 = COLORS.text,
	Font = Enum.Font.GothamMedium,
	TextSize = 11,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	ZIndex = 202,
})
local pendingConfirmation
local confirmCancel = make("TextButton", confirmationCard, {
	Position = UDim2.new(0, 12, 1, -42),
	Size = UDim2.new(0.5, -18, 0, 30),
	BackgroundColor3 = COLORS.card,
	BorderSizePixel = 0,
	Text = "CANCELAR",
	TextColor3 = COLORS.muted,
	Font = Enum.Font.GothamBold,
	TextSize = 9,
	AutoButtonColor = false,
	ZIndex = 202,
})
addCorner(confirmCancel, 8)
local confirmAccept = make("TextButton", confirmationCard, {
	Position = UDim2.new(0.5, 6, 1, -42),
	Size = UDim2.new(0.5, -18, 0, 30),
	BackgroundColor3 = COLORS.accentDark,
	BorderSizePixel = 0,
	Text = "CONFIRMAR",
	TextColor3 = COLORS.accent,
	Font = Enum.Font.GothamBold,
	TextSize = 9,
	AutoButtonColor = false,
	ZIndex = 202,
})
addCorner(confirmAccept, 8)
requestConfirmation = function(message, callback)
	confirmationText.Text = tostring(message):sub(1, 420)
	pendingConfirmation = callback
	confirmationOverlay.Visible = true
end
connect(confirmCancel.Activated, function()
	confirmationOverlay.Visible = false
	pendingConfirmation = nil
end)
connect(confirmAccept.Activated, function()
	local callback = pendingConfirmation
	pendingConfirmation = nil
	confirmationOverlay.Visible = false
	if callback then
		local ok, err = pcall(callback)
		if not ok then
			logDiagnostic("Ação confirmada falhou: " .. tostring(err))
			showNotice("Falha na ação", "Error")
		end
	end
end)

balancedButton.Activated:Connect(function()
	applyPreset(EQUILIBRADO, "EQUILIBRADO")
end)
oldPcButton.Activated:Connect(function()
	applyPreset(PC_ANTIGO, "PC ANTIGO")
end)
resetButton.Activated:Connect(function()
	applyPreset(PC_ANTIGO, "PC ANTIGO")
end)
footerClose.Activated:Connect(function()
	stopPanelDrag()
	setPanelOpen(false)
end)

local function setMinimized(value)
	minimized = value
	presetFrame.Visible = not minimized
	tabBar.Visible = not minimized
	if minimized then
		for _, page in pairs(pages) do page.Visible = false end
	else
		setActivePage(activePageId)
	end
	footer.Visible = not minimized
	minimizeButton.Text = minimized and "□" or "−"
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local width = expandedSize.X.Offset
	local height = minimized and 76 or expandedSize.Y.Offset
	panel.Size = UDim2.fromOffset(width, height)
	local centerX = panel.Position.X.Scale * viewport.X + panel.Position.X.Offset
	local centerY = panel.Position.Y.Scale * viewport.Y + panel.Position.Y.Offset
	panel.Position = UDim2.fromOffset(
		clampCenter(centerX, viewport.X, width * panelScaleFactor),
		clampCenter(centerY, viewport.Y, height * panelScaleFactor)
	)
end

minimizeButton.Activated:Connect(function()
	stopPanelDrag()
	setMinimized(not minimized)
end)

local lastHotkeyToggle = 0
connect(UserInputService.InputBegan, function(input, gameProcessed)
	local controls = FeatureModules.Controls
	local key = controls.GetInputBindName(input)
	local focusedTextBox = UserInputService:GetFocusedTextBox()
	if focusedTextBox then
		if input.KeyCode == Enum.KeyCode.Escape and panelOpen then
			pcall(function() focusedTextBox:ReleaseFocus() end)
			setPanelOpen(false)
		end
		return
	end
	if key then pressedKeys[key] = true end
	if not ready then return end
	if controls.CaptureInput(key) then return end
	if input.KeyCode == Enum.KeyCode.Escape and panelOpen then
		stopPanelDrag()
		if draggingSlider then finishSliderDrag() end
		setPanelOpen(false)
		return
	end
	if key and (key == controls.Config.OpenPanel or key == "CapsLock") then
		local now = os.clock()
		if now - lastHotkeyToggle < 0.2 then return end
		lastHotkeyToggle = now
		if panelOpen then
			stopPanelDrag()
			if draggingSlider then finishSliderDrag() end
		end
		setPanelOpen(not panelOpen)
		return
	end
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and AimConfig.ClickAssistAutoHook then
		AimAssist.ApplyClickAssist()
	end
	if not controls.Config.Enabled or not key then return end
	if key == controls.Config.ToggleAim then
		AimAssist.SetActive(not AimAssist.GetActive())
		markCustom()
		refreshUI()
		updateDiagnosticsPage()
	elseif key == controls.Config.ToggleCrosshair then
		FeatureModules.Crosshair.Config.Enabled = not FeatureModules.Crosshair.Config.Enabled
		FeatureModules.Crosshair.Update()
		markCustom()
		refreshUI()
	elseif key == controls.Config.ToggleHUD then
		FeatureModules.HUD.Config.Enabled = not FeatureModules.HUD.Config.Enabled
		FeatureModules.HUD.Refresh()
		markCustom()
		refreshUI()
	elseif key == controls.Config.Macro1 then
		FeatureModules.Chat.SendFavorite(1)
	elseif key == controls.Config.Macro2 then
		FeatureModules.Chat.SendFavorite(2)
	elseif key == controls.Config.Macro3 then
		FeatureModules.Chat.SendFavorite(3)
	end
end)
connect(UserInputService.InputEnded, function(input)
	local key = FeatureModules.Controls.GetInputBindName(input)
	if key then pressedKeys[key] = nil end
end)

local function scan(root, label)
	-- Caminha pela hierarquia em lotes, sem criar uma tabela gigante com todos
	-- os descendentes de uma vez. Os objetos novos continuam cobertos pelo evento.
	local stack = {}
	local stackSize = 0
	for _, child in ipairs(root:GetChildren()) do
		stackSize += 1
		stack[stackSize] = child
	end

	local processed = 0
	local inBatch = 0
	local batchSize = INITIAL_SCAN_BATCH_SIZE
	loadingStatus.Text = label
	loadingCounter.Text = "0 objetos verificados"

	while stackSize > 0 do
		local instance = stack[stackSize]
		stack[stackSize] = nil
		stackSize -= 1

		register(instance)
		for _, child in ipairs(instance:GetChildren()) do
			stackSize += 1
			stack[stackSize] = child
		end

		processed += 1
		inBatch += 1
		if inBatch >= batchSize then
			loadingCounter.Text = string.format("%d objetos verificados", processed)
			task.wait()
			inBatch = 0
		end
	end

	loadingCounter.Text = string.format("%d objetos verificados", processed)
end

local startupThread
local function cleanup()
	if shuttingDown then return end
	shuttingDown = true
	ready = false
	if saveTask then
		pcall(task.cancel, saveTask)
		saveTask = nil
	end
	if FeatureModules.Chat and FeatureModules.Chat.CancelFilter then
		FeatureModules.Chat.CancelFilter()
	end
	saveGeneration += 1
	if startupThread then
		pcall(task.cancel, startupThread)
		startupThread = nil
	end
	if panelOpen then setPanelOpen(false) end
	if stopPanelDrag then stopPanelDrag() end
	if finishSliderDrag then finishSliderDrag() end
	disconnectDrag()
	AimAssist.Stop()
	FeatureModules.Hitbox.Disable()
	FeatureModules.Crosshair.Disable()
	FeatureModules.HUD.Config.Enabled = false
	FeatureModules.HUD.Refresh()
	FeatureModules.Accessibility.Cleanup()
	setHudVisibility()
	for key in pairs(Config) do
		if key == "ParticleRateMultiplier" then
			Config[key] = 1
		elseif type(Config[key]) == "boolean" then
			Config[key] = false
		end
	end
	applyAll(false)
	pcall(function() loadingTween:Cancel() end)
	if cameraSizeConnection then cameraSizeConnection:Disconnect() end
	for _, connection in ipairs(globalConnections) do
		pcall(function() connection:Disconnect() end)
	end
	table.clear(globalConnections)
	if screenGui.Parent then screenGui:Destroy() end
	if FeatureModules.Crosshair.Gui.Parent then FeatureModules.Crosshair.Gui:Destroy() end
	if FeatureModules.HUD.Gui.Parent then FeatureModules.HUD.Gui:Destroy() end
	if FeatureModules.TouchGui.Parent then FeatureModules.TouchGui:Destroy() end
	if playerGui.Parent then playerGui:SetAttribute("PotatoControlRunning", false) end
end

connect(script.Destroying, cleanup)

-- A tela cobre a inicialização. A travessia incremental evita o pico de custo
-- de GetDescendants() em mapas grandes; depois, só objetos novos são tratados.
startupThread = task.spawn(function()
	loadingStatus.Text = "Carregando perfil e módulos..."
	local loadOk, loadError = pcall(function()
		loadServerProfile(false)
	end)
	if not loadOk then
		FeatureModules.Profile.Status.Text = "Perfil não carregado; usando valores seguros."
		logDiagnostic("Inicialização do perfil: " .. tostring(loadError))
	end
	if shuttingDown then return end
	optimizationReady = true
	applyAll(Config.ReduceParticles and Config.ClearExistingParticles)

	local scanOk, scanError = pcall(function()
		scan(Workspace, "Analisando o cenário...")
		scan(Lighting, "Analisando iluminação e efeitos...")
	end)
	if shuttingDown then return end
	if scanOk then
		loadingStatus.Text = "Tudo pronto"
		loadingCounter.Text = "O painel está disponível"
	else
		loadingStatus.Text = "Inicialização parcial concluída"
		loadingCounter.Text = "O painel ainda pode ser aberto"
		logDiagnostic("Varredura inicial: " .. tostring(scanError))
	end
	pcall(function() loadingTween:Cancel() end)
	loadingFill.Position = UDim2.new(0, 0, 0, 0)
	loadingFill.Size = UDim2.new(1, 0, 1, 0)
	task.wait(0.35)
	if shuttingDown then return end
	local aimOk, aimError = pcall(AimAssist.Start)
	if not aimOk then logDiagnostic("Aim Help não iniciou: " .. tostring(aimError)) end
	ready = true
	loadingScreen.Visible = false
	screenGui.Enabled = false
	setTouchButtonVisibility()
	setHudVisibility()
	updateDiagnosticsPage()
	startupThread = nil
end)
