-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  SPA-GLOBAL · QUALY MODE · WP TOGGLE + ANTI CORNER CUT          ║
-- ║  1) Menú de carga PRO (Blanco, Negro, Rojo)                     ║
-- ║  2) Torre derecha con animaciones sube/baja posición            ║
-- ║  3) Modo Clasificación: ranking por tiempo, configurable        ║
-- ║  4) Anti Corner Cut integrado nativamente (optimizado)          ║
-- ║  ── NUEVAS FUNCIONES ──────────────────────────────────────────  ║
-- ║  5) ID de imagen por jugador → se muestra al lado de la torre   ║
-- ║  6) WPs configurables individualmente (LAP / PIT IN / PIT OUT)  ║
-- ║  7) Logo animado encima de la torre (ID 70836470072887)         ║
-- ║  8) Jugadores con FIA desaparecen de la torre automáticamente   ║
-- ╚══════════════════════════════════════════════════════════════════╝

local mfloor  = math.floor
local mceil   = math.ceil
local mclamp  = math.clamp
local mmax    = math.max
local mmin    = math.min
local mround  = math.round
local mrad    = math.rad
local mabs    = math.abs
local mpi     = math.pi
local mrandom = math.random
local sformat = string.format

-- [SDE_INFI · CAMBIO 2] Caché de telemetría — evita GetDescendants cada 0.06s por jugador
_telCache = {}
-- _telCache[uid] = { seat=seatRef, maxSpeed=N, turbo="Nivel X", drift="1.2", susp="Nivel 2", t=tick() }
_TEL_TTL  = 0.4   -- segundos antes de invalidar el caché por jugador
local ssub    = string.sub
local supper  = string.upper
local sfind   = string.find
local tinsert = table.insert
local tsort   = table.sort
local tcreate = table.create

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UserInputService= game:GetService("UserInputService")
local Workspace       = game:GetService("Workspace")
local TweenService    = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Camera    = Workspace.CurrentCamera

-- ─── CONSTANTES GLOBALES ───────────────────────────────────────
local CAL_FACTOR              = 0.6437
local CAL_OFFSET              = 0
local SPEED_CONVERSION_FACTOR = CAL_FACTOR
local SPEED_LIMIT             = 70
local showOnlyVehicles        = false
local MAX_LAPS                = 50
local MAX_PITS                = 3
local NOTIFICATION_COOLDOWN   = 10
local NOTIFICATION_DURATION   = 5
local notifiedPlayers         = {}
local lastSpeeds              = {}
-- CRASH_VELOCITY_DROP eliminado → ver tabla global SPA_Crash abajo [SPAV4]
local COLLISION_COOLDOWN      = 10
local lastCollisionNotificationTime = 0
local DEBOUNCE_TIME           = 3
local MAX_PLAYERS_DISPLAY     = 22
local CHECKPOINT_RADIUS       = 350
local WP_WIDTH                = 120
local WP_HEIGHT               = 90
local WP_THICKNESS            = 20

-- ─── CONFIG INDIVIDUAL POR WP (cada uno independiente, no se combinan) ─────
local wpCfg = {
	LAP     = { width = 120, height = 90, thickness = 20 },
	PIT_IN  = { width = 120, height = 90, thickness = 20 },
	PIT_OUT = { width = 120, height = 90, thickness = 20 },
}
local DETECT_LAPS             = true
local DETECT_PITS             = true
local LAP_LINE_CFRAME         = CFrame.new(0, 35, 0)
local PIT_ENTRY_CFRAME        = CFrame.new(80, 35, 0)
local PIT_EXIT_CFRAME         = CFrame.new(100, 35, 0)
local lapData                 = {}
local pitData                 = {}
local fastLapData             = {}
local isSpectating            = false
local originalCameraType      = nil
local originalCameraSubject   = nil
local spectRenderConnection   = nil
local targetSpectPlayer       = nil
local CAMERA_FOV              = 70
local SHOW_HEAD_NAME          = true
local SHOW_HEAD_SPEED         = true

-- WP visibilidad
local WP_VISIBLE              = true

-- Modo Clasificación
local QUALY_MODE              = false
local QUALY_LAPS              = 3

-- Torre de posiciones
local TOWER_SCALE      = 1.0
local TOWER_ROW_H      = 24
local TOWER_HEADER_H   = 28
local TOWER_WIDTH      = 148
-- [SDE_INFI · Broadcast] 1=Vueltas/Gaps  2=Tiempos  3=Llantas
towerBroadcastMode     = 1

local customPlayerData = {}
local FIA_EXCLUDED     = {}

-- ─── CONSTANTES ANTI-CC ────────────────────────────────────────
local DETECTCC        = true
local CCDEBOUNCETIME  = 5
local CCWPWIDTH       = 120
local CCWPHEIGHT      = 90
local CCWPTHICKNESS   = 20
local SHOW_WAYPOINTS_CC = true
local ccWaypoints     = {}
local ccData          = {}
local lastSeenInCC    = {}
local ccDebounce      = {}
local ccWpCounter     = 0

-- ─── OPTIMIZACIÓN 2: Cache de filas de GUI ─────────────────────
local vueltasRowCache  = {}
local boxesRowCache    = {}
local fastLapsRowCache = {}

-- ─── COLORES (PALETA iOS DARK-GLASS · SPAV4) ───────────────────
-- Grafito frío translúcido para los módulos + acentos estilo iOS.
local C_BG      = Color3.fromRGB(18, 20, 27)   -- grafito profundo (panel base)
local C_BG2     = Color3.fromRGB(32, 35, 45)   -- grafito elevado (filas/headers)
local C_RED     = Color3.fromRGB(255, 69, 58)  -- iOS systemRed
local C_WHITE   = Color3.fromRGB(245, 246, 250)
local C_GRAY    = Color3.fromRGB(152, 154, 164) -- iOS secondaryLabel
local C_YELLOW  = Color3.fromRGB(255, 214, 10)  -- iOS systemYellow
local C_GREEN   = Color3.fromRGB(48, 209, 88)   -- iOS systemGreen
local C_ORANGE  = Color3.fromRGB(255, 159, 10)  -- iOS systemOrange
local C_DARKRED = Color3.fromRGB(120, 30, 28)
local C_BLUE    = Color3.fromRGB(10, 132, 255)  -- iOS systemBlue
local C_F1_PURPLE    = Color3.fromRGB(191, 90, 242) -- iOS systemPurple
local C_F1_YELLOW    = Color3.fromRGB(255, 214, 10)
local C_F1_GREEN_LT  = Color3.fromRGB(48, 209, 88)
local CCWPCOLOR      = Color3.fromRGB(255, 214, 10) -- Color WPs Corner Cut

-- ════════════════════════════════════════════════════════════════
-- ███  MOTOR DE TEMA iOS · GLASSMORPHISM (SPAV4)  ████████████████
-- Capa PURAMENTE visual. Todo vive DENTRO de una función (IIFE) y se
-- expone como GLOBAL 'Glass'. Los globals NO consumen registros locales
-- del chunk principal, así evitamos el límite de 200 locales de Luau
-- sin quitar funcionalidad.
-- ════════════════════════════════════════════════════════════════
Glass = (function()
	local Lighting = game:GetService("Lighting")

	local GLASS = {
		PANEL_TRANSPARENCY  = 0.16,  -- contenedores/paneles grandes
		ROW_TRANSPARENCY    = 0.20,  -- filas de listas
		BUTTON_TRANSPARENCY = 0.08,  -- botones / inputs
		STROKE_COLOR        = Color3.fromRGB(255, 255, 255),
		STROKE_TRANSPARENCY = 0.86,  -- borde hairline translúcido (iOS)
		STROKE_THICKNESS    = 1,
		GRADIENT_TOP        = 0.0,    -- brillo interno (degradado vertical sutil)
		GRADIENT_BOTTOM     = 0.10,
		BLUR_SIZE           = 26,     -- desenfoque gaussiano del fondo al abrir modales
	}

	-- Radio de esquina estilo iOS (Roblox clampa a la mitad del lado menor)
	local function _iosRadius(g)
		local oy = g.Size.Y.Offset
		if g.Size.Y.Scale > 0 and oy == 0 then return UDim.new(0, 14) end
		if oy >= 120 then return UDim.new(0, 20) end
		if oy >= 50  then return UDim.new(0, 14) end
		if oy >= 28  then return UDim.new(0, 10) end
		return UDim.new(0, 8)
	end

	-- ¿Barra/divisor/indicador delgado? (se conserva nítido, sin vidrio)
	local function _isThinAccent(g)
		local s = g.Size
		local thinY = (s.Y.Scale == 0 and s.Y.Offset > 0 and s.Y.Offset <= 4)
		local thinX = (s.X.Scale == 0 and s.X.Offset > 0 and s.X.Offset <= 4)
		return thinY or thinX
	end

	local _GLASS_TARGETS = {
		Frame = true, TextButton = true, TextBox = true,
		ScrollingFrame = true, ImageButton = true,
	}

	local function glassify(inst)
		if typeof(inst) ~= "Instance" then return end
		if not _GLASS_TARGETS[inst.ClassName] then return end
		if inst:GetAttribute("_glassed") then return end
		inst:SetAttribute("_glassed", true)
		if _isThinAccent(inst) then return end

		-- Esquinas redondeadas
		local corner = inst:FindFirstChildOfClass("UICorner")
		if not corner then corner = Instance.new("UICorner"); corner.Parent = inst end
		corner.CornerRadius = _iosRadius(inst)

		-- Solo aplicar vidrio a elementos con fondo realmente visible
		if inst.BackgroundTransparency < 0.6 then
			local sy = inst.Size.Y.Scale
			local oy = inst.Size.Y.Offset
			local target
			if inst:IsA("ScrollingFrame") or (sy > 0) or oy >= 120 then
				target = GLASS.PANEL_TRANSPARENCY
			elseif inst:IsA("TextButton") or inst:IsA("ImageButton") or inst:IsA("TextBox") then
				target = GLASS.BUTTON_TRANSPARENCY
			else
				target = GLASS.ROW_TRANSPARENCY
			end
			inst.BackgroundTransparency = target

			-- Borde hairline: solo en rectángulos (en TextButton/TextBox el
			-- UIStroke contornearía el texto, así que se omite ahí).
			if (inst:IsA("Frame") or inst:IsA("ScrollingFrame") or inst:IsA("ImageButton"))
				and not inst:FindFirstChild("_GlassStroke") then
				local st = Instance.new("UIStroke")
				st.Name = "_GlassStroke"
				st.Color = GLASS.STROKE_COLOR
				st.Transparency = GLASS.STROKE_TRANSPARENCY
				st.Thickness = GLASS.STROKE_THICKNESS
				st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				st.Parent = inst
			end

			-- Degradado vertical sutil (brillo interno): solo en Frames planos,
			-- para no atenuar el texto de botones/inputs.
			if inst:IsA("Frame") and not inst:FindFirstChild("_GlassGradient") then
				local gr = Instance.new("UIGradient")
				gr.Name = "_GlassGradient"
				gr.Rotation = 90
				gr.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, GLASS.GRADIENT_TOP),
					NumberSequenceKeypoint.new(1, GLASS.GRADIENT_BOTTOM),
				})
				gr.Parent = inst
			end
		end
	end

	-- BlurEffect para el desenfoque gaussiano del fondo
	local _glassBlur = Lighting:FindFirstChild("SPA_GlassBlur")
	if not _glassBlur then
		_glassBlur = Instance.new("BlurEffect")
		_glassBlur.Name = "SPA_GlassBlur"
		_glassBlur.Size = 0
		_glassBlur.Enabled = true
		_glassBlur.Parent = Lighting
	end

	local _glassModals = {}
	local function _updateGlassBlur()
		local anyOpen = false
		for f, _ in pairs(_glassModals) do
			if f.Parent and f.Visible then anyOpen = true; break end
		end
		TweenService:Create(_glassBlur, TweenInfo.new(0.28, Enum.EasingStyle.Quart),
			{ Size = anyOpen and GLASS.BLUR_SIZE or 0 }):Play()
	end

	local function registerGlassModal(frame)
		if not frame then return end
		frame:SetAttribute("_glassed", true)
		local corner = frame:FindFirstChildOfClass("UICorner")
		if not corner then corner = Instance.new("UICorner"); corner.Parent = frame end
		corner.CornerRadius = UDim.new(0, 22)
		if frame.BackgroundTransparency < 0.6 then
			frame.BackgroundTransparency = GLASS.PANEL_TRANSPARENCY
		end
		if not frame:FindFirstChild("_GlassStroke") then
			local st = Instance.new("UIStroke")
			st.Name = "_GlassStroke"; st.Color = GLASS.STROKE_COLOR
			st.Transparency = 0.82; st.Thickness = 1.4
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = frame
		end
		_glassModals[frame] = true
		frame:GetPropertyChangedSignal("Visible"):Connect(_updateGlassBlur)
		frame.AncestryChanged:Connect(_updateGlassBlur)
	end

	local _GLASS_SKIP_GUI = { SPA_LOADING_PRO = true }
	local function attachGlass(screenGui)
		if not screenGui or _GLASS_SKIP_GUI[screenGui.Name] then return end
		for _, d in ipairs(screenGui:GetDescendants()) do glassify(d) end
		-- [SDE_INFI · CAMBIO 4] DescendantAdded eliminado: Glass estático, no callback en runtime
	end

	local function applyIOSGlassTheme()
		for _, g in ipairs(playerGui:GetChildren()) do
			if g:IsA("ScreenGui") then attachGlass(g) end
		end
		playerGui.ChildAdded:Connect(function(g)
			if g:IsA("ScreenGui") then task.defer(attachGlass, g) end
		end)
		_updateGlassBlur()
	end

	return {
		registerModal = registerGlassModal,
		apply         = applyIOSGlassTheme,
		glassify      = glassify,
		blur          = _glassBlur,
		BLUR_SIZE     = GLASS.BLUR_SIZE,
	}
end)()

-- ─── HELPERS GLOBALES ──────────────────────────────────────────
local function fmtTime(s)
	if not s or s <= 0 then return "--:--.---" end
	local mins = mfloor(s / 60)
	local secs = s % 60
	return sformat("%d:%06.3f", mins, secs)
end

local function fmtTimeDelta(s)
	if not s then return "" end
	if s == 0 then return "LEADER" end
	return sformat("+%06.3f", s)
end

local function getDisplayName(p)
	local cd = customPlayerData[p.UserId]
	if cd and cd.name and cd.name ~= "" then return cd.name end
	return p.Name
end

local function getNameColor(p)
	local cd = customPlayerData[p.UserId]
	if cd and cd.color then return cd.color end
	return C_WHITE
end

local function toSpeedDisplay(studs)
	return mfloor(studs * 0.28 * 3.6 * CAL_FACTOR + CAL_OFFSET + 0.5)
end

local function getVehicleSpeed(seat)
	if not seat then return 0 end
	local ok, mag = pcall(function()
		if seat.AssemblyLinearVelocity then return seat.AssemblyLinearVelocity.Magnitude else return seat.Velocity.Magnitude end
	end)
	if ok and mag then return mag else return 0 end
end

local function getPlayerSpeedLimit(seat)
	-- [SDE_INFI · CAMBIO 2] Cache hit
	local occ = seat and seat.Occupant
	local uid = occ and occ.Parent and occ.Parent.UserId
	if uid then
		local c = _telCache[uid]
		if c and c.seat == seat and c.maxSpeed ~= nil and (c.t + _TEL_TTL) > tick() then
			return c.maxSpeed
		end
	end
	-- Cache miss — calcular
	local result
	local root = _telGetRootModel and _telGetRootModel(seat)
	if root then
		for _, v in ipairs(root:GetDescendants()) do
			if (v:IsA("NumberValue") or v:IsA("IntValue")) and v.Value > 0 then
				local nm = v.Name:lower()
				if nm=="maxspeed" or nm=="topspeed" or nm=="top_speed" or nm=="speedlimit" then
					result = mfloor(v.Value * 10 + 0.5) / 10; break
				end
			end
		end
	end
	if not result then
		for _, v in pairs(seat:GetChildren()) do
			if (v:IsA("NumberValue") or v:IsA("IntValue")) and v.Value > 0
				and (v.Name:lower():find("speed") or v.Name:lower():find("limit")) then
				result = mfloor(v.Value * 10 + 0.5) / 10; break
			end
		end
	end
	if not result then
		-- Fallback: propiedad nativa MaxSpeed del VehicleSeat
		if seat and seat:IsA("VehicleSeat") then
			result = mfloor(seat.MaxSpeed * 10 + 0.5) / 10
		end
	end
	result = result or 0
	if uid then
		if not _telCache[uid] then _telCache[uid] = {} end
		local c = _telCache[uid]; c.seat = seat; c.maxSpeed = result; c.t = tick()
	end
	return result
end

local function getPlayerSpeed(p)
	local char = p.Character
	if not char then return 0 end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
		return toSpeedDisplay(getVehicleSpeed(hum.SeatPart))
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return 0 end
	return mround(hrp.AssemblyLinearVelocity.Magnitude * SPEED_CONVERSION_FACTOR + CAL_OFFSET)
end

local function ensurePlayerData(p)
	if not p then return end
	local uid = p.UserId
	if not lapData[uid] then lapData[uid] = {lapsMade=0, lastLapTouch=0} end
	if not pitData[uid] then pitData[uid] = {status="En Pista", pitStopsMade=0, lastPitTouch=0} end
	if not fastLapData[uid] then fastLapData[uid] = {bestTime=nil, lastStartTime=nil, currentLapStarted=false} end
	if not ccData[uid] then ccData[uid] = { total = 0, history = {} } end
end

for _, pl in ipairs(Players:GetPlayers()) do ensurePlayerData(pl) end

-- ─── NOTIFICACIONES ────────────────────────────────────────────
local NOTIF_ENABLED = true
local function showNotification(text, bgColor, icon, yOffset)
	if not NOTIF_ENABLED then return end
	local gui = Instance.new("ScreenGui")
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 200
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 420, 0, 48)
	frame.Position = UDim2.new(0.5, -210, 0, yOffset or 20)
	frame.BackgroundColor3 = C_BG
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 4, 1, 0)
	accent.BackgroundColor3 = bgColor
	accent.BorderSizePixel = 0
	accent.Parent = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame

	local iconLbl = Instance.new("TextLabel")
	iconLbl.Size = UDim2.new(0, 36, 1, 0)
	iconLbl.Position = UDim2.new(0, 8, 0, 0)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text = icon or "⚑"
	iconLbl.TextScaled = true
	iconLbl.Font = Enum.Font.GothamBold
	iconLbl.TextColor3 = bgColor
	iconLbl.Parent = frame

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -56, 1, 0)
	lbl.Position = UDim2.new(0, 50, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.TextColor3 = C_WHITE
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = text
	lbl.Parent = frame

	frame.Position = UDim2.new(0.5, -210, 0, (yOffset or 20) - 30)
	frame.BackgroundTransparency = 1
	local tweenIn = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -210, 0, yOffset or 20),
		BackgroundTransparency = 0.1
	})
	tweenIn:Play()

	task.delay(NOTIFICATION_DURATION - 0.4, function()
		local tweenOut = TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -210, 0, (yOffset or 20) - 20),
			BackgroundTransparency = 1
		})
		tweenOut:Play()
		tweenOut.Completed:Connect(function() gui:Destroy() end)
	end)
end

local function showSpeedingNotification(name, speed)
	showNotification(name .. "  EXCESO DE VELOCIDAD  " .. speed .. " KM/H", C_RED, "⚠", 20)
end

local function showCollisionNotification()
	showNotification("CHOQUE DETECTADO", C_ORANGE, "💥", 78)
end

local function showCCNotification(text, yOffset)
	showNotification(text, CCWPCOLOR, "⚠️", yOffset or 136)
end

-- ─── WAYPOINTS Y FÍSICAS ───────────────────────────────────────
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local function getPlayerCharacters()
	local chars = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then tinsert(chars, p.Character) end
	end
	return chars
end

local function playersInPart(boxPart)
	local parts = Workspace:GetPartsInPart(boxPart, overlapParams)
	local found = {}
	for _, hit in ipairs(parts) do
		local char = hit:FindFirstAncestorOfClass("Model")
		if char then
			local pl = Players:GetPlayerFromCharacter(char)
			if pl then found[pl.UserId] = true end
		end
	end
	return found
end

local function createSphereTrigger(name, cframe)
	local part = Instance.new("Part")
	part.Name = name; part.Shape = Enum.PartType.Ball; part.Size = Vector3.new(CHECKPOINT_RADIUS, CHECKPOINT_RADIUS, CHECKPOINT_RADIUS)
	part.CFrame = cframe; part.Anchored = true; part.CanCollide = false; part.CanTouch = false
	part.CanQuery = true; part.Transparency = 1; part.Parent = Workspace
	return part
end

local function createWall(name, color, cframe, size, transparency)
	local wp = Instance.new("Part")
	wp.Name = name; wp.Size = size or Vector3.new(WP_WIDTH, WP_HEIGHT, WP_THICKNESS)
	wp.CFrame = cframe * CFrame.Angles(0, mrad(90), 0)
	wp.Anchored = true; wp.CanCollide = false; wp.CanTouch = false; wp.CanQuery = true
	wp.Transparency = transparency or (WP_VISIBLE and 0.4 or 1)
	wp.Color = color; wp.Material = Enum.Material.Neon; wp.Parent = Workspace
	return wp
end

local lapWall    = createWall("LAP_WALL",     C_GREEN,                   LAP_LINE_CFRAME,  Vector3.new(wpCfg.LAP.width,     wpCfg.LAP.height,     wpCfg.LAP.thickness))
local pitInWall  = createWall("PIT_IN_WALL",  C_ORANGE,                  PIT_ENTRY_CFRAME, Vector3.new(wpCfg.PIT_IN.width,  wpCfg.PIT_IN.height,  wpCfg.PIT_IN.thickness))
local pitOutWall = createWall("PIT_OUT_WALL", Color3.fromRGB(128,0,128), PIT_EXIT_CFRAME,  Vector3.new(wpCfg.PIT_OUT.width, wpCfg.PIT_OUT.height, wpCfg.PIT_OUT.thickness))
local pitEntrySphere = createSphereTrigger("PitEntryTrigger", PIT_ENTRY_CFRAME)
local pitExitSphere  = createSphereTrigger("PitExitTrigger",  PIT_EXIT_CFRAME)
local lapSphere      = createSphereTrigger("LapTrigger",      LAP_LINE_CFRAME)

local function applyWPVisibility()
	local t = WP_VISIBLE and 0.4 or 1
	if lapWall    then lapWall.Transparency    = t end
	if pitInWall  then pitInWall.Transparency  = t end
	if pitOutWall then pitOutWall.Transparency = t end
end

-- Funciones CC Walls
local function createCCWall(id, name, cframe)
	return createWall("CCWP_" .. id, CCWPCOLOR, cframe, Vector3.new(CCWPWIDTH, CCWPHEIGHT, CCWPTHICKNESS), SHOW_WAYPOINTS_CC and 0.35 or 1)
end

local function applyWPVisibilityCC()
	local t = SHOW_WAYPOINTS_CC and 0.35 or 1
	for _, entry in pairs(ccWaypoints) do
		if entry.wall and entry.wall.Parent then entry.wall.Transparency = t end
	end
end

local function removeCCWall(id)
	local entry = ccWaypoints[id]
	if not entry then return end
	if entry.wall and entry.wall.Parent then entry.wall:Destroy() end
	lastSeenInCC[id] = nil
	local prefix = tostring(id) .. "_"  -- [SPAV4 fix] evita borrar debounces de IDs con mismo dígito inicial (1 vs 10,11..)
	for key, _ in pairs(ccDebounce) do
		if type(key) == "string" and key:sub(1, #prefix) == prefix then ccDebounce[key] = nil end
	end
	ccWaypoints[id] = nil
end

-- ─── NUEVO LOADING SCREEN (PROFESIONAL BLANCO/NEGRO/ROJO) ──────
local loadGui = Instance.new("ScreenGui")
loadGui.Name = "SPA_LOADING_PRO"
loadGui.ResetOnSpawn = false
loadGui.DisplayOrder = 999
loadGui.Parent = playerGui

local loadBg = Instance.new("Frame")
loadBg.Size = UDim2.new(1,0,1,0)
loadBg.BackgroundColor3 = Color3.fromRGB(10, 11, 16) -- Negro profundo translúcido
loadBg.BackgroundTransparency = 0.12
loadBg.BorderSizePixel = 0
loadBg.Parent = loadGui

local centerContainer = Instance.new("Frame")
centerContainer.Size = UDim2.new(0, 420, 0, 210)
centerContainer.Position = UDim2.new(0.5, -210, 0.5, -105)
centerContainer.BackgroundColor3 = C_BG2
centerContainer.BackgroundTransparency = 0.16
centerContainer.BorderSizePixel = 0
centerContainer.Parent = loadBg
do
	local _cc = Instance.new("UICorner"); _cc.CornerRadius = UDim.new(0, 26); _cc.Parent = centerContainer
	local _cs = Instance.new("UIStroke"); _cs.Color = Color3.fromRGB(255,255,255); _cs.Transparency = 0.82; _cs.Thickness = 1.4; _cs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; _cs.Parent = centerContainer
	local _cg = Instance.new("UIGradient"); _cg.Rotation = 90; _cg.Transparency = NumberSequence.new(0.0, 0.12); _cg.Parent = centerContainer
end

local logoText = Instance.new("TextLabel")
logoText.Size = UDim2.new(1,0,0,50)
logoText.Position = UDim2.new(0,0,0,40)
logoText.BackgroundTransparency = 1
logoText.Text = "SPA GLOBAL"
logoText.TextColor3 = Color3.fromRGB(255, 255, 255)
logoText.Font = Enum.Font.GothamBlack
logoText.TextSize = 48
logoText.Parent = centerContainer

local subText = Instance.new("TextLabel")
subText.Size = UDim2.new(1,0,0,20)
subText.Position = UDim2.new(0,0,0,95)
subText.BackgroundTransparency = 1
subText.Text = "RACE CONTROL SYSTEM"
subText.TextColor3 = C_RED
subText.Font = Enum.Font.GothamBold
subText.TextSize = 18
subText.Parent = centerContainer

local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1,0,0,20)
statusText.Position = UDim2.new(0,0,0,160)
statusText.BackgroundTransparency = 1
statusText.Text = "INICIALIZANDO SISTEMAS..."
statusText.TextColor3 = C_GRAY
statusText.Font = Enum.Font.GothamMedium
statusText.TextSize = 12
statusText.Parent = centerContainer

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1,0,0,2)
barBg.Position = UDim2.new(0,0,0,140)
barBg.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
barBg.BorderSizePixel = 0
barBg.Parent = centerContainer

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0,0,1,0)
barFill.BackgroundColor3 = C_RED
barFill.BorderSizePixel = 0
barFill.Parent = barBg

task.spawn(function()
	TweenService:Create(Glass.blur, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {Size = Glass.BLUR_SIZE}):Play()
	TweenService:Create(barFill, TweenInfo.new(3.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size=UDim2.new(1,0,1,0)}):Play()
	task.wait(0.8)
	statusText.Text = "CARGANDO TELEMETRÍA Y UI..."
	task.wait(1.2)
	statusText.Text = "INICIANDO ANTI CORNER CUT..."
	task.wait(1)
	statusText.Text = "SISTEMA LISTO"
	statusText.TextColor3 = C_WHITE
	task.wait(0.5)

	TweenService:Create(Glass.blur, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {Size = 0}):Play()
	TweenService:Create(loadBg, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {BackgroundTransparency=1}):Play()
	TweenService:Create(logoText, TweenInfo.new(0.4), {TextTransparency=1}):Play()
	TweenService:Create(subText, TweenInfo.new(0.4), {TextTransparency=1}):Play()
	TweenService:Create(statusText, TweenInfo.new(0.4), {TextTransparency=1}):Play()
	TweenService:Create(barBg, TweenInfo.new(0.4), {BackgroundTransparency=1}):Play()
	TweenService:Create(barFill, TweenInfo.new(0.4), {BackgroundTransparency=1}):Play()
	task.wait(0.6)
	loadGui:Destroy()
end)

-- ─── HUD PANEL PRINCIPAL ───────────────────────────────────────
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "F125_HUD"
hudGui.ResetOnSpawn = false
hudGui.DisplayOrder = 10
hudGui.Parent = playerGui

local lapPanel = Instance.new("Frame")
lapPanel.Name = "LapPanel"
lapPanel.Size = UDim2.new(0, 320, 0, 52)
lapPanel.Position = UDim2.new(0.5, -160, 0, 10)
lapPanel.BackgroundColor3 = C_BG
lapPanel.BackgroundTransparency = 0.1
lapPanel.BorderSizePixel = 0
lapPanel.Parent = hudGui
local lapPanelCorner = Instance.new("UICorner")
lapPanelCorner.CornerRadius = UDim.new(0,4)
lapPanelCorner.Parent = lapPanel

local lapPanelLine = Instance.new("Frame")
lapPanelLine.Size = UDim2.new(1,0,0,3)
lapPanelLine.Position = UDim2.new(0,0,1,-3)
lapPanelLine.BackgroundColor3 = C_RED
lapPanelLine.BorderSizePixel = 0
lapPanelLine.Parent = lapPanel

local lapLabel = Instance.new("TextLabel")
lapLabel.Size = UDim2.new(0.3,0,0.5,0)
lapLabel.Position = UDim2.new(0,10,0,4)
lapLabel.BackgroundTransparency = 1
lapLabel.Text = "LAP"
lapLabel.Font = Enum.Font.GothamBold
lapLabel.TextColor3 = C_GRAY
lapLabel.TextSize = 11
lapLabel.TextXAlignment = Enum.TextXAlignment.Left
lapLabel.Parent = lapPanel

local lapNumLabel = Instance.new("TextLabel")
lapNumLabel.Name = "LapNum"
lapNumLabel.Size = UDim2.new(0.35,0,0.55,0)
lapNumLabel.Position = UDim2.new(0,10,0.42,0)
lapNumLabel.BackgroundTransparency = 1
lapNumLabel.Text = "0 / " .. MAX_LAPS
lapNumLabel.Font = Enum.Font.GothamBlack
lapNumLabel.TextColor3 = C_WHITE
lapNumLabel.TextSize = 20
lapNumLabel.TextXAlignment = Enum.TextXAlignment.Left
lapNumLabel.Parent = lapPanel

local sep = Instance.new("Frame")
sep.Size = UDim2.new(0,1,0.7,0)
sep.Position = UDim2.new(0.38,-0.5,0.15,0)
sep.BackgroundColor3 = C_GRAY
sep.BackgroundTransparency = 0.5
sep.BorderSizePixel = 0
sep.Parent = lapPanel

local timeLabel = Instance.new("TextLabel")
timeLabel.Size = UDim2.new(0.62,-5,0.5,0)
timeLabel.Position = UDim2.new(0.38,6,0,4)
timeLabel.BackgroundTransparency = 1
timeLabel.Text = "BEST"
timeLabel.Font = Enum.Font.GothamBold
timeLabel.TextColor3 = C_GRAY
timeLabel.TextSize = 11
timeLabel.TextXAlignment = Enum.TextXAlignment.Left
timeLabel.Parent = lapPanel

local bestTimeLabel = Instance.new("TextLabel")
bestTimeLabel.Name = "BestTime"
bestTimeLabel.Size = UDim2.new(0.62,-5,0.55,0)
bestTimeLabel.Position = UDim2.new(0.38,6,0.42,0)
bestTimeLabel.BackgroundTransparency = 1
bestTimeLabel.Text = "--:--.---  |  ---"
bestTimeLabel.Font = Enum.Font.GothamBlack
bestTimeLabel.TextColor3 = C_GREEN
bestTimeLabel.TextSize = 12
bestTimeLabel.TextXAlignment = Enum.TextXAlignment.Left
bestTimeLabel.Parent = lapPanel

-- ─── TORRE DERECHA ─────────────────────────────────────────────
local towerGui = Instance.new("ScreenGui")
towerGui.Name = "F125_Tower"
towerGui.ResetOnSpawn = false
towerGui.DisplayOrder = 10
towerGui.Parent = playerGui

local towerConfig = {
	posX        = 1,
	offsetX     = -160,
	posY        = 0,
	offsetY     = 12,
	headerColor = C_RED,
	titleText   = "SPA GLOBAL",
	visible     = true,
	hudMasterVisible = true,  -- [SPAV4] visibilidad maestra del HUD (tecla Q) sin nuevo local
}

local towerContainer = Instance.new("Frame")
towerContainer.Name = "TowerContainer"
towerContainer.Size = UDim2.new(0, TOWER_WIDTH, 0, 30)
towerContainer.Position = UDim2.new(towerConfig.posX, towerConfig.offsetX, towerConfig.posY, towerConfig.offsetY)
towerContainer.BackgroundTransparency = 1
towerContainer.ClipsDescendants = false
towerContainer.Visible = towerConfig.visible
towerContainer.ZIndex = 2  -- [SPAV4] filas y nombres por ENCIMA del fondo blanco (towerBgBottom)
towerContainer.Parent = towerGui

local towerLayout = Instance.new("UIListLayout")
towerLayout.SortOrder = Enum.SortOrder.LayoutOrder
towerLayout.Padding = UDim.new(0, 2)
towerLayout.Parent = towerContainer

-- Fondo visual externo SIN mover la torre original
local towerBgTop = Instance.new("ImageLabel")
towerBgTop.Name = "TowerBgTop"
towerBgTop.Size = UDim2.new(0, TOWER_WIDTH, 0, 44)
towerBgTop.Position = UDim2.new(towerConfig.posX, towerConfig.offsetX, towerConfig.posY, towerConfig.offsetY - 46)
towerBgTop.BackgroundColor3 = Color3.fromRGB(255,255,255)
towerBgTop.BackgroundTransparency = 0
towerBgTop.Image = "rbxassetid://70836470072887"
towerBgTop.ScaleType = Enum.ScaleType.Fit
towerBgTop.BorderSizePixel = 0
towerBgTop.ZIndex = 1
towerBgTop.Parent = towerGui
local _bgTopCorner = Instance.new("UICorner")
_bgTopCorner.CornerRadius = UDim.new(0,6)
_bgTopCorner.Parent = towerBgTop

local towerBgBottom = Instance.new("Frame")
towerBgBottom.Name = "TowerBgBottom"
towerBgBottom.Size = UDim2.new(0, TOWER_WIDTH, 0, TOWER_HEADER_H)
towerBgBottom.Position = UDim2.new(towerConfig.posX, towerConfig.offsetX, towerConfig.posY, towerConfig.offsetY - 2)
towerBgBottom.BackgroundColor3 = Color3.fromRGB(255,255,255)
towerBgBottom.BackgroundTransparency = 0.75
towerBgBottom.BorderSizePixel = 0
towerBgBottom.ZIndex = 0  -- [SPAV4] detrás del nombre de los jugadores (ya no se ve blanquecino encima)
towerBgBottom.Parent = towerGui
local _bgBottomCorner = Instance.new("UICorner")
_bgBottomCorner.CornerRadius = UDim.new(0,6)
_bgBottomCorner.Parent = towerBgBottom

RunService.Heartbeat:Connect(function()
	local contentH = towerLayout.AbsoluteContentSize.Y
	local tw = mround(TOWER_WIDTH * TOWER_SCALE)
	towerBgTop.Size = UDim2.new(0, tw, 0, 44)
	towerBgTop.Position = UDim2.new(towerConfig.posX, towerConfig.offsetX, towerConfig.posY, towerConfig.offsetY - 46)
	towerBgTop.Visible = towerConfig.visible and towerConfig.hudMasterVisible
	local bottomH = math.max(0, contentH + 2)
	towerBgBottom.Size = UDim2.new(0, tw, 0, bottomH)
	towerBgBottom.Position = UDim2.new(towerConfig.posX, towerConfig.offsetX, towerConfig.posY, towerConfig.offsetY - 2)
	towerBgBottom.Visible = towerConfig.visible and towerConfig.hudMasterVisible and bottomH > 0
end)

-- ─── HEADER ORIGINAL DE LA TORRE ──────────────────────
-- Se crea DESPUÉS del towerContainer para poder referenciarlo.
-- Lo configuramos al final del setup de la torre (ver abajo: setupTowerBanner)
local towerHeader = Instance.new("Frame")
towerHeader.Size = UDim2.new(1,0,0,TOWER_HEADER_H)
towerHeader.BackgroundColor3 = towerConfig.headerColor
towerHeader.BorderSizePixel = 0
towerHeader.LayoutOrder = 0
towerHeader.Parent = towerContainer
local thc = Instance.new("UICorner"); thc.CornerRadius = UDim.new(0,3); thc.Parent = towerHeader

local towerHeaderText = Instance.new("TextLabel")
towerHeaderText.Name = "TowerLapText"
towerHeaderText.Size = UDim2.new(0.75,0,1,0)
towerHeaderText.Position = UDim2.new(0,8,0,0)
towerHeaderText.BackgroundTransparency = 1
towerHeaderText.Text = "LAP 0/" .. MAX_LAPS
towerHeaderText.Font = Enum.Font.GothamBlack
towerHeaderText.TextColor3 = C_WHITE
towerHeaderText.TextSize = 12
towerHeaderText.TextXAlignment = Enum.TextXAlignment.Left
towerHeaderText.Parent = towerHeader

local liveDot = Instance.new("Frame")
liveDot.Size = UDim2.new(0,8,0,8)
liveDot.Position = UDim2.new(1,-26,0.5,-4)
liveDot.BackgroundColor3 = C_WHITE
liveDot.BorderSizePixel = 0
liveDot.Parent = towerHeader
local liveDotC = Instance.new("UICorner"); liveDotC.CornerRadius = UDim.new(1,0); liveDotC.Parent = liveDot

local liveTxt = Instance.new("TextLabel")
liveTxt.Size = UDim2.new(0,20,1,0)
liveTxt.Position = UDim2.new(1,-20,0,0)
liveTxt.BackgroundTransparency = 1
liveTxt.Text = "●"
liveTxt.Font = Enum.Font.GothamBold
liveTxt.TextColor3 = C_WHITE
liveTxt.TextTransparency = 0.3
liveTxt.TextSize = 9
liveTxt.Parent = towerHeader

local towerRows    = {}  
local towerRowData = {}  
-- [SPAV4] flag de visibilidad maestra del HUD vive en towerConfig (sin nuevo local)



local function applyTowerConfig()
	towerContainer.Position = UDim2.new(towerConfig.posX, towerConfig.offsetX, towerConfig.posY, towerConfig.offsetY)
	towerContainer.Visible = towerConfig.visible
	towerHeader.BackgroundColor3 = towerConfig.headerColor
end

local function applyTowerScale()
	local rh = mround(TOWER_ROW_H  * TOWER_SCALE)
	local hh = mround(TOWER_HEADER_H * TOWER_SCALE)
	local tw = mround(TOWER_WIDTH  * TOWER_SCALE)
	local ts = mclamp(mround(12 * TOWER_SCALE), 9, 22)
	local ns = mclamp(mround(11 * TOWER_SCALE), 8, 20)
	local ps = mclamp(mround(14 * TOWER_SCALE), 10, 24)
	local ls = mclamp(mround(10 * TOWER_SCALE), 8, 18)

	towerContainer.Size = UDim2.new(0, tw, 0, 30)
	towerHeader.Size    = UDim2.new(1, 0, 0, hh)
	towerHeaderText.TextSize = ts

	for uid, row in pairs(towerRows) do
		row.Size = UDim2.new(1,0,0,rh)
		local tb = row:FindFirstChild("TeamBar")
		if tb then tb.Size = UDim2.new(0, mround(4*TOWER_SCALE), 1, 0) end
		local posFrame = row:FindFirstChild("PosFrame")
		if posFrame then
			posFrame.Size = UDim2.new(0, mround(26*TOWER_SCALE), 1, 0)
			local pt = posFrame:FindFirstChild("Pos")
			if pt then pt.TextSize = ps end
		end
		local playerImg = row:FindFirstChild("PlayerImg")
		if playerImg then
			local _imgSize = mround(rh * 0.8)
			playerImg.Size     = UDim2.new(0, _imgSize, 0, _imgSize)
			playerImg.Position = UDim2.new(0, mround(34*TOWER_SCALE), 0.5, -mround(_imgSize/2))
		end
		local nameTxt = row:FindFirstChild("Name")
		if nameTxt then
			nameTxt.Size     = UDim2.new(0.42, 0, 1, 0)
			nameTxt.Position = UDim2.new(0, mround(34*TOWER_SCALE) + mround(rh*0.8) + 4, 0, 0)
			nameTxt.TextSize = ns
		end
		local lapTxt = row:FindFirstChild("Lap")
		if lapTxt then lapTxt.TextSize = ls end
	end
	towerConfig.offsetX = -tw
	applyTowerConfig()
end

local function animTowerRow(uid, newPos, oldPos)
	local rd = towerRowData[uid]
	if not rd then return end
	local row    = towerRows[uid]
	local arrow  = rd.arrowLbl
	if not arrow or not row then return end

	if newPos < oldPos then
		arrow.Text       = "▲"
		arrow.TextColor3 = C_F1_GREEN_LT
		TweenService:Create(row, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(0, 40, 15)}):Play()
		task.delay(1.2, function()
			if arrow and arrow.Parent then
				arrow.Text = ""
				TweenService:Create(row, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundColor3 = C_BG2}):Play()
			end
		end)
	elseif newPos > oldPos then
		arrow.Text       = "▼"
		arrow.TextColor3 = C_RED
		TweenService:Create(row, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(40, 5, 5)}):Play()
		task.delay(1.2, function()
			if arrow and arrow.Parent then
				arrow.Text = ""
				TweenService:Create(row, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundColor3 = C_BG2}):Play()
			end
		end)
	end
end

local function getOrCreateTowerRow(uid, name, pos)
	if towerRows[uid] then return towerRows[uid] end
	local rh = mround(TOWER_ROW_H * TOWER_SCALE)
	local ns = mclamp(mround(11 * TOWER_SCALE), 8, 20)
	local ps = mclamp(mround(14 * TOWER_SCALE), 10, 24)
	local ls = mclamp(mround(10 * TOWER_SCALE), 8, 18)

	local row = Instance.new("Frame")
	row.Name            = "Row_" .. uid
	row.Size            = UDim2.new(1, 0, 0, rh)
	row.BackgroundColor3= C_BG2
	row.BorderSizePixel = 0
	row.LayoutOrder     = pos
	row.Parent          = towerContainer

	local colorBar = Instance.new("Frame")
	colorBar.Name            = "TeamBar"
	colorBar.Size            = UDim2.new(0, mround(4 * TOWER_SCALE), 1, 0)
	colorBar.BackgroundColor3= C_WHITE
	colorBar.BorderSizePixel = 0
	colorBar.Parent          = row

	local posFrame = Instance.new("Frame")
	posFrame.Name            = "PosFrame"
	posFrame.Size            = UDim2.new(0, mround(26*TOWER_SCALE), 1, 0)
	posFrame.Position        = UDim2.new(0, 4, 0, 0)
	posFrame.BackgroundColor3= C_WHITE
	posFrame.BorderSizePixel = 0
	posFrame.Parent          = row
	local posFrameC = Instance.new("UICorner"); posFrameC.CornerRadius = UDim.new(0,2); posFrameC.Parent = posFrame

	local posTxt = Instance.new("TextLabel")
	posTxt.Name            = "Pos"
	posTxt.Size            = UDim2.new(1, 0, 1, 0)
	posTxt.BackgroundTransparency = 1
	posTxt.Text            = tostring(pos)
	posTxt.Font            = Enum.Font.GothamBlack
	posTxt.TextColor3      = C_BG
	posTxt.TextSize        = ps
	posTxt.Parent          = posFrame

	local arrowLbl = Instance.new("TextLabel")
	arrowLbl.Name            = "Arrow"
	arrowLbl.Size            = UDim2.new(0, 10, 1, 0)
	arrowLbl.Position        = UDim2.new(0, mround(30*TOWER_SCALE), 0, 0)
	arrowLbl.BackgroundTransparency = 1
	arrowLbl.Text            = ""
	arrowLbl.Font            = Enum.Font.GothamBold
	arrowLbl.TextSize        = 9
	arrowLbl.TextColor3      = C_F1_GREEN_LT
	arrowLbl.Parent          = row

	local nameTxt = Instance.new("TextLabel")
	nameTxt.Name            = "Name"
	nameTxt.Size            = UDim2.new(0.42, 0, 1, 0)
	nameTxt.Position        = UDim2.new(0, mround(34*TOWER_SCALE) + mround(rh*0.8) + 4, 0, 0)
	nameTxt.BackgroundTransparency = 1
	nameTxt.Text            = supper(ssub(name, 1, 8))
	nameTxt.Font            = Enum.Font.GothamBold
	nameTxt.TextColor3      = C_WHITE
	nameTxt.TextSize        = ns
	nameTxt.TextXAlignment  = Enum.TextXAlignment.Left
	nameTxt.Parent          = row

	local lapTxt = Instance.new("TextLabel")
	lapTxt.Name            = "Lap"
	lapTxt.Size            = UDim2.new(0.3, 0, 1, 0)
	lapTxt.Position        = UDim2.new(0.7, 0, 0, 0)
	lapTxt.BackgroundTransparency = 1
	lapTxt.Text            = "L0"
	lapTxt.Font            = Enum.Font.GothamBold
	lapTxt.TextColor3      = C_GRAY
	lapTxt.TextSize        = ls
	lapTxt.TextXAlignment  = Enum.TextXAlignment.Right
	lapTxt.Parent          = row

	-- Imagen del jugador al lado derecho de la fila
	local playerImg = Instance.new("ImageLabel")
	playerImg.Name                    = "PlayerImg"
	local _imgSize = mround(rh * 0.8)
	playerImg.Size                    = UDim2.new(0, _imgSize, 0, _imgSize)
	playerImg.Position                = UDim2.new(0, mround(34*TOWER_SCALE), 0.5, -mround(_imgSize/2))
	playerImg.BackgroundTransparency  = 1
	playerImg.BorderSizePixel         = 0
	playerImg.ZIndex                  = 5
	playerImg.ScaleType               = Enum.ScaleType.Fit
	local _pcd = customPlayerData[uid]
	playerImg.Image = (_pcd and _pcd.imageId and _pcd.imageId ~= "") and ("rbxassetid://".._pcd.imageId) or ""
	playerImg.Parent                  = row

	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent       = row

	towerRows[uid]    = row
	towerRowData[uid] = {
		lastPos  = pos,
		arrowLbl = arrowLbl,
	}
	return row
end

-- ─── PANEL PRINCIPAL ───────────────────────────────────────────
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "SPA_PANEL"
mainGui.ResetOnSpawn = false
mainGui.DisplayOrder = 50
mainGui.Parent = playerGui

local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0, 54, 0, 54)
floatBtn.Position = UDim2.new(0, 14, 0.5, -27)
floatBtn.BackgroundColor3 = C_RED
floatBtn.Text = "SPA"
floatBtn.TextColor3 = C_WHITE
floatBtn.Font = Enum.Font.GothamBlack
floatBtn.TextSize = 13
floatBtn.BorderSizePixel = 0
floatBtn.Parent = mainGui
local fbc = Instance.new("UICorner"); fbc.CornerRadius = UDim.new(0,4); fbc.Parent = floatBtn

local fbLine = Instance.new("Frame")
fbLine.Size = UDim2.new(1,0,0,3)
fbLine.Position = UDim2.new(0,0,1,-3)
fbLine.BackgroundColor3 = C_WHITE
fbLine.BackgroundTransparency = 0.5
fbLine.BorderSizePixel = 0
fbLine.Parent = floatBtn

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0.78, 0, 0.72, 0)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = C_BG
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = mainGui
local mfc = Instance.new("UICorner"); mfc.CornerRadius = UDim.new(0,6); mfc.Parent = mainFrame
Glass.registerModal(mainFrame)

local topAccent = Instance.new("Frame")
topAccent.Size = UDim2.new(1,0,0,3)
topAccent.BackgroundColor3 = C_RED
topAccent.BorderSizePixel = 0
topAccent.Parent = mainFrame

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1,0,0,38)
titleBar.Position = UDim2.new(0,0,0,3)
titleBar.BackgroundColor3 = C_BG2
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleTxt = Instance.new("TextLabel")
titleTxt.Size = UDim2.new(0.7,0,1,0)
titleTxt.Position = UDim2.new(0,14,0,0)
titleTxt.BackgroundTransparency = 1
titleTxt.Text = "SPA GLOBAL  —  RACE CONTROL"
titleTxt.Font = Enum.Font.GothamBlack
titleTxt.TextColor3 = C_WHITE
titleTxt.TextSize = 14
titleTxt.TextXAlignment = Enum.TextXAlignment.Left
titleTxt.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,32,0,28)
closeBtn.Position = UDim2.new(1,-38,0,5)
closeBtn.BackgroundColor3 = C_RED
closeBtn.Text = "✕"
closeBtn.TextColor3 = C_WHITE
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0,3); cbc.Parent = closeBtn

-- ─── TABS ──────────────────────────────────────────────────────
local tabs = {"VUELTAS", "BOXES", "FAST LAPS", "ONBOARD", "FIA", "CONFIG", "CHOQUES", "ANÁLISIS", "LLANTAS"}
local tabButtons = {}
local tabFrames  = {}
local currentTab = "VUELTAS"

-- ─── SIDEBAR VERTICAL iOS (negro translúcido) ───────────────────
-- titleBar ocupa y=3 h=38 → sidebar empieza en y=41
-- [SPAV4 MOBILE FIX] ScrollingFrame → las tabs son scrolleables en móvil/pantallas pequeñas
local tabBar = Instance.new("ScrollingFrame")
tabBar.Name = "TabSidebar"
tabBar.Size = UDim2.new(0, 106, 1, -41)
tabBar.Position = UDim2.new(0, 0, 0, 41)
tabBar.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
tabBar.BackgroundTransparency = 0.04
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 3
tabBar.ScrollBarThickness = 2
tabBar.ScrollBarImageColor3 = C_RED
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
tabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
tabBar.ScrollingDirection = Enum.ScrollingDirection.Y
tabBar.Parent = mainFrame
do
	Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 6)
end

-- Línea separadora derecha del sidebar
local tabSep = Instance.new("Frame")
tabSep.Size = UDim2.new(0, 1, 1, -41)
tabSep.Position = UDim2.new(0, 106, 0, 41)
tabSep.BackgroundColor3 = Color3.fromRGB(255,255,255)
tabSep.BackgroundTransparency = 0.88
tabSep.BorderSizePixel = 0
tabSep.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Vertical
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 1)
tabLayout.Parent = tabBar

local tabIcons = {
	["VUELTAS"]   = "🏁",
	["BOXES"]     = "🔧",
	["FAST LAPS"] = "⚡",
	["ONBOARD"]   = "📷",
	["FIA"]       = "🔵",
	["CONFIG"]    = "⚙",
	["CHOQUES"]   = "💥",
	["ANÁLISIS"]  = "🔍",
	["LLANTAS"]   = "🏎",
}

for i, tabName in ipairs(tabs) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 38)
	btn.BackgroundColor3 = tabName == currentTab and C_RED or Color3.fromRGB(0,0,0)
	btn.BackgroundTransparency = tabName == currentTab and 0.0 or 0.6
	btn.Text = (tabIcons[tabName] or "") .. "  " .. tabName
	btn.TextColor3 = tabName == currentTab and C_WHITE or C_GRAY
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 10
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.BorderSizePixel = 0
	btn.LayoutOrder = i
	btn.ZIndex = 4
	btn.Parent = tabBar
	tabButtons[tabName] = btn
	do
		local _bp = Instance.new("UIPadding"); _bp.PaddingLeft = UDim.new(0,10); _bp.Parent = btn
	end

	-- Indicador: franja roja a la DERECHA del botón activo
	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(0, 3, 1, 0)
	indicator.Position = UDim2.new(1, -3, 0, 0)
	indicator.BackgroundColor3 = tabName == currentTab and C_RED or Color3.fromRGB(0,0,0)
	indicator.BackgroundTransparency = tabName == currentTab and 0 or 1
	indicator.BorderSizePixel = 0
	indicator.ZIndex = 5
	indicator.Parent = btn

	-- Área de contenido: a la DERECHA del sidebar (x=110, y=41)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -114, 1, -49)
	frame.Position = UDim2.new(0, 110, 0, 41)
	frame.BackgroundTransparency = 1
	frame.Visible = tabName == currentTab
	frame.Parent = mainFrame
	tabFrames[tabName] = frame

	btn.MouseButton1Click:Connect(function()
		currentTab = tabName
		for name, f in pairs(tabFrames) do
			f.Visible = name == currentTab
			local isActive = name == currentTab
			tabButtons[name].BackgroundColor3 = isActive and C_RED or Color3.fromRGB(0,0,0)
			tabButtons[name].BackgroundTransparency = isActive and 0.0 or 0.6
			tabButtons[name].TextColor3 = isActive and C_WHITE or C_GRAY
			local ind = tabButtons[name]:FindFirstChild("Indicator")
			if ind then
				ind.BackgroundColor3 = isActive and C_RED or Color3.fromRGB(0,0,0)
				ind.BackgroundTransparency = isActive and 0 or 1
			end
		end
	end)
end

-- ─── SCROLL HELPER ─────────────────────────────────────────────
local function createScrollingList(parent)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size                 = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundColor3     = C_BG
	scroll.BorderSizePixel      = 0
	-- SIN AutomaticCanvasSize: es unreliable en executors.
	-- Usamos AbsoluteContentSize del UIListLayout directamente.
	scroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
	scroll.ScrollingDirection   = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness   = 10
	scroll.ScrollBarImageColor3 = C_ORANGE
	scroll.ElasticBehavior      = Enum.ElasticBehavior.Always
	scroll.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding   = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent    = scroll

	-- Sincronizar canvas SIEMPRE que el contenido cambie
	local function _syncCanvas()
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 24)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(_syncCanvas)
	task.defer(_syncCanvas)  -- primer sync al siguiente frame (contenido ya renderizado)

	return scroll, layout
end

-- ─── UI HELPERS ────────────────────────────────────────────────
local function makeSectionHeader(parent, text, order, bgColor, textColor)
	local h = Instance.new("Frame")
	h.Size = UDim2.new(1,0,0,22)
	h.BackgroundColor3 = bgColor or C_DARKRED
	h.BorderSizePixel = 0
	h.LayoutOrder = order
	h.Parent = parent
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,-12,1,0)
	lbl.Position = UDim2.new(0,10,0,0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextColor3 = textColor or C_WHITE
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = h
end

local function makeVueltasRow(parent, order, pos, p)
	local uid = p.UserId
	local ld  = lapData[uid]     or {lapsMade=0}
	local pd2 = pitData[uid]     or {pitStopsMade=0}
	local fld = fastLapData[uid] or {}
	local displayName = getDisplayName(p) .. (FIA_EXCLUDED[uid] and "  [FIA]" or "")
	local nameCol     = FIA_EXCLUDED[uid] and C_BLUE or getNameColor(p)

	local topRow = Instance.new("Frame")
	topRow.Size = UDim2.new(1,0,0,30)
	topRow.BackgroundColor3 = order%2==0 and C_BG2 or C_BG
	topRow.BorderSizePixel = 0
	topRow.LayoutOrder = order*10
	topRow.Parent = parent

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0,3,1,0)
	bar.BackgroundColor3 = Color3.fromHSV((order*0.13)%1, 0.85, 1)
	bar.BorderSizePixel = 0
	bar.Parent = topRow

	local posLbl = Instance.new("TextLabel")
	posLbl.Size = UDim2.new(0,28,1,0)
	posLbl.Position = UDim2.new(0,6,0,0)
	posLbl.BackgroundTransparency = 1
	posLbl.Text = "P"..pos
	posLbl.Font = Enum.Font.GothamBlack
	posLbl.TextColor3 = C_RED
	posLbl.TextSize = 13
	posLbl.TextXAlignment = Enum.TextXAlignment.Left
	posLbl.Parent = topRow

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(0.48,0,1,0)
	nameLbl.Position = UDim2.new(0,38,0,0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = displayName
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextColor3 = nameCol
	nameLbl.TextSize = 12
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Parent = topRow

	local lapCountLbl = Instance.new("TextLabel")
	lapCountLbl.Size = UDim2.new(0.38,-8,1,0)
	lapCountLbl.Position = UDim2.new(0.6,0,0,0)
	lapCountLbl.BackgroundTransparency = 1
	lapCountLbl.Text = sformat("LAP %d/%d", ld.lapsMade or 0, MAX_LAPS)
	lapCountLbl.Font = Enum.Font.GothamBold
	lapCountLbl.TextColor3 = (ld.lapsMade or 0)==MAX_LAPS and C_YELLOW or C_WHITE
	lapCountLbl.TextSize = 12
	lapCountLbl.TextXAlignment = Enum.TextXAlignment.Right
	lapCountLbl.Parent = topRow
	local rp1 = Instance.new("UIPadding"); rp1.PaddingRight = UDim.new(0,8); rp1.Parent = topRow

	local btnRow = Instance.new("Frame")
	btnRow.Size = UDim2.new(1,0,0,26)
	btnRow.BackgroundColor3 = order%2==0 and Color3.fromRGB(14,14,20) or Color3.fromRGB(10,10,16)
	btnRow.BorderSizePixel = 0
	btnRow.LayoutOrder = order*10+1
	btnRow.Parent = parent

	local btnLayout = Instance.new("UIListLayout")
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.Padding = UDim.new(0,4)
	btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	btnLayout.Parent = btnRow

	local function makeResetBtn(txt, bgColor, callback)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0,90,0,20)
		b.BackgroundColor3 = bgColor
		b.Text = txt
		b.Font = Enum.Font.GothamBold
		b.TextColor3 = C_WHITE
		b.TextSize = 10
		b.BorderSizePixel = 0
		b.Parent = btnRow
		local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,3); bc.Parent = b
		b.MouseButton1Click:Connect(callback)
		return b
	end

	makeResetBtn("↺ VUELTAS", C_DARKRED, function()
		lapData[uid] = {lapsMade=0, lastLapTouch=0}
		fastLapData[uid] = {bestTime=nil, lastStartTime=nil, currentLapStarted=false}
		if vueltasRowCache[uid] then
			local cachedTop = vueltasRowCache[uid].topRow
			if cachedTop then
				local lc = cachedTop:FindFirstChild("LapCount")
				if lc then
					lc.Text      = sformat("LAP 0/%d", MAX_LAPS)
					lc.TextColor3= C_WHITE
				end
			end
		end
	end)
	makeResetBtn("↺ BOXES", Color3.fromRGB(80,40,0), function()
		pitData[uid] = {status="En Pista", pitStopsMade=0, lastPitTouch=0}
		if boxesRowCache[uid] then
			local rightLbl = boxesRowCache[uid]:FindFirstChild("RightLbl")
			if rightLbl then
				rightLbl.Text      = sformat("PIT 0/%d", MAX_PITS)
				rightLbl.TextColor3= C_WHITE
			end
		end
	end)
	makeResetBtn("↺ TIEMPO", Color3.fromRGB(0,70,30), function()
		if fastLapData[uid] then
			fastLapData[uid].bestTime = nil
			fastLapData[uid].currentLapStarted = false
			fastLapData[uid].lastStartTime = nil
		end
		if fastLapsRowCache[uid] then
			local rightLbl = fastLapsRowCache[uid]:FindFirstChild("RightLbl")
			if rightLbl then
				rightLbl.Text      = "NO TIME"
				rightLbl.TextColor3= C_GRAY
			end
		end
	end)

	-- [SDE_INFI] Botones ajuste manual de vueltas +1 / -1
	local function _refreshLapCount()
		local cur = lapData[uid] and lapData[uid].lapsMade or 0
		lapCountLbl.Text      = sformat("LAP %d/%d", cur, MAX_LAPS)
		lapCountLbl.TextColor3= cur == MAX_LAPS and C_YELLOW or C_WHITE
		-- Sincronizar también la caché si ya existe
		if vueltasRowCache[uid] then
			local cachedTop = vueltasRowCache[uid].topRow
			if cachedTop then
				local lc = cachedTop:FindFirstChild("LapCount")
				if lc then lc.Text = lapCountLbl.Text; lc.TextColor3 = lapCountLbl.TextColor3 end
			end
		end
	end

	local lapAdjRow = Instance.new("Frame")
	lapAdjRow.Size = UDim2.new(1,0,0,26)
	lapAdjRow.BackgroundColor3 = order%2==0 and Color3.fromRGB(10,18,10) or Color3.fromRGB(8,14,8)
	lapAdjRow.BorderSizePixel = 0
	lapAdjRow.LayoutOrder = order*10+2
	lapAdjRow.Parent = parent

	local lapAdjLayout = Instance.new("UIListLayout")
	lapAdjLayout.FillDirection = Enum.FillDirection.Horizontal
	lapAdjLayout.Padding = UDim.new(0,4)
	lapAdjLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	lapAdjLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lapAdjLayout.Parent = lapAdjRow

	local addBtn = Instance.new("TextButton")
	addBtn.Size = UDim2.new(0,110,0,20)
	addBtn.BackgroundColor3 = Color3.fromRGB(0,100,40)
	addBtn.Text = "+1 VUELTA"
	addBtn.Font = Enum.Font.GothamBlack
	addBtn.TextColor3 = C_WHITE
	addBtn.TextSize = 10
	addBtn.BorderSizePixel = 0
	addBtn.Parent = lapAdjRow
	Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0,3)
	addBtn.MouseButton1Click:Connect(function()
		if not lapData[uid] then lapData[uid] = {lapsMade=0, lastLapTouch=0} end
		lapData[uid].lapsMade = mmin(lapData[uid].lapsMade + 1, MAX_LAPS)
		_refreshLapCount()
	end)

	local subBtn = Instance.new("TextButton")
	subBtn.Size = UDim2.new(0,110,0,20)
	subBtn.BackgroundColor3 = Color3.fromRGB(160,60,0)
	subBtn.Text = "-1 VUELTA"
	subBtn.Font = Enum.Font.GothamBlack
	subBtn.TextColor3 = C_WHITE
	subBtn.TextSize = 10
	subBtn.BorderSizePixel = 0
	subBtn.Parent = lapAdjRow
	Instance.new("UICorner", subBtn).CornerRadius = UDim.new(0,3)
	subBtn.MouseButton1Click:Connect(function()
		if not lapData[uid] then lapData[uid] = {lapsMade=0, lastLapTouch=0} end
		lapData[uid].lapsMade = mmax(lapData[uid].lapsMade - 1, 0)
		_refreshLapCount()
	end)

	lapCountLbl.Name = "LapCount"
	vueltasRowCache[uid] = {topRow = topRow, btnRow = btnRow, lapAdjRow = lapAdjRow}
end

-- ─── VARIABLES SCROLL / PANEL ──────────────────────────────────
local vueltasScroll   = nil
local boxesScroll     = nil
local fastLapsScroll  = nil
local onboardScroll   = nil
local nameConfigPanel = nil
local configScroll    = nil

-- ══════════════════════════════════════════════════════════════
-- ═══  _setupUI1  ══════════════════════════════════════════════
-- ══════════════════════════════════════════════════════════════
function _setupUI1()  -- [SPAV4] global: libera registros del ámbito principal
	vueltasScroll,  _ = createScrollingList(tabFrames["VUELTAS"])
	boxesScroll,    _ = createScrollingList(tabFrames["BOXES"])
	fastLapsScroll, _ = createScrollingList(tabFrames["FAST LAPS"])
	onboardScroll,  _ = createScrollingList(tabFrames["ONBOARD"])
	local fiaScroll,_  = createScrollingList(tabFrames["FIA"])
	configScroll,   _ = createScrollingList(tabFrames["CONFIG"])
	-- [SPAV4] configScroll hereda grosor y color de createScrollingList

	-- Nombres config panel
	nameConfigPanel = Instance.new("Frame")
	nameConfigPanel.Size = UDim2.new(1,0,0,0)
	nameConfigPanel.AutomaticSize = Enum.AutomaticSize.Y
	nameConfigPanel.BackgroundTransparency = 1
	nameConfigPanel.LayoutOrder = 0
	nameConfigPanel.Parent = vueltasScroll

	local nameConfigHeader = Instance.new("TextButton")
	nameConfigHeader.Size = UDim2.new(1,0,0,26)
	nameConfigHeader.BackgroundColor3 = Color3.fromRGB(0,80,160)
	nameConfigHeader.Text = "✏  NOMBRES Y COLORES PERSONALIZADOS  ▼"
	nameConfigHeader.Font = Enum.Font.GothamBold
	nameConfigHeader.TextColor3 = C_WHITE
	nameConfigHeader.TextSize = 11
	nameConfigHeader.BorderSizePixel = 0
	nameConfigHeader.LayoutOrder = 0
	nameConfigHeader.Parent = nameConfigPanel
	local nhc = Instance.new("UICorner"); nhc.CornerRadius = UDim.new(0,3); nhc.Parent = nameConfigHeader

	local nameConfigBody = Instance.new("Frame")
	nameConfigBody.Size = UDim2.new(1,0,0,0)
	nameConfigBody.AutomaticSize = Enum.AutomaticSize.Y
	nameConfigBody.BackgroundColor3 = Color3.fromRGB(12,12,20)
	nameConfigBody.BorderSizePixel = 0
	nameConfigBody.LayoutOrder = 1
	nameConfigBody.Visible = false
	nameConfigBody.Parent = nameConfigPanel
	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.Padding = UDim.new(0,2)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Parent = nameConfigBody

	nameConfigHeader.MouseButton1Click:Connect(function()
		nameConfigBody.Visible = not nameConfigBody.Visible
		nameConfigHeader.Text = nameConfigBody.Visible
			and "✏  NOMBRES Y COLORES PERSONALIZADOS  ▲"
			or  "✏  NOMBRES Y COLORES PERSONALIZADOS  ▼"
	end)

	local COLOR_PALETTE = {
		{name="BLANCO",   color=Color3.fromRGB(255,255,255)},
		{name="ROJO",     color=Color3.fromRGB(230,0,0)},
		{name="AZUL",     color=Color3.fromRGB(0,120,255)},
		{name="VERDE",    color=Color3.fromRGB(0,210,90)},
		{name="AMARILLO", color=Color3.fromRGB(255,200,0)},
		{name="NARANJA",  color=Color3.fromRGB(255,130,0)},
		{name="MORADO",   color=Color3.fromRGB(160,0,220)},
		{name="CYAN",     color=Color3.fromRGB(0,220,220)},
		{name="ROSA",     color=Color3.fromRGB(255,80,180)},
		{name="GRIS",     color=Color3.fromRGB(160,160,170)},
	}

	local function buildNameConfigRows()
		for _, c in ipairs(nameConfigBody:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		for i, plr in ipairs(Players:GetPlayers()) do
			local uid = plr.UserId
			local cd  = customPlayerData[uid] or {name="", color=C_WHITE}

			local row = Instance.new("Frame")
			row.Size = UDim2.new(1,0,0,50)
			row.BackgroundColor3 = i%2==0 and C_BG2 or C_BG
			row.BorderSizePixel = 0
			row.LayoutOrder = i
			row.Parent = nameConfigBody

			local realLbl = Instance.new("TextLabel")
			realLbl.Size = UDim2.new(1,-8,0,18)
			realLbl.Position = UDim2.new(0,6,0,2)
			realLbl.BackgroundTransparency = 1
			realLbl.Text = "👤 " .. plr.Name
			realLbl.Font = Enum.Font.GothamBold
			realLbl.TextColor3 = C_GRAY
			realLbl.TextSize = 11
			realLbl.TextXAlignment = Enum.TextXAlignment.Left
			realLbl.Parent = row

			local nameBox = Instance.new("TextBox")
			nameBox.Size = UDim2.new(0.55,0,0,24)
			nameBox.Position = UDim2.new(0,6,0,20)
			nameBox.BackgroundColor3 = Color3.fromRGB(30,30,45)
			nameBox.BorderSizePixel = 0
			nameBox.Font = Enum.Font.GothamBold
			nameBox.TextColor3 = cd.color or C_WHITE
			nameBox.TextSize = 12
			nameBox.Text = cd.name or ""
			nameBox.PlaceholderText = "Nombre..."
			nameBox.ClearTextOnFocus = false
			nameBox.TextXAlignment = Enum.TextXAlignment.Left
			nameBox.Parent = row
			local nbc = Instance.new("UICorner"); nbc.CornerRadius = UDim.new(0,3); nbc.Parent = nameBox
			local nbp = Instance.new("UIPadding"); nbp.PaddingLeft = UDim.new(0,4); nbp.Parent = nameBox

			local colorIdx = 1
			if cd.color then
				for ci, opt in ipairs(COLOR_PALETTE) do
					if opt.color == cd.color then colorIdx = ci; break end
				end
			end

			local colorBtn = Instance.new("TextButton")
			colorBtn.Size = UDim2.new(0.38,-8,0,24)
			colorBtn.Position = UDim2.new(0.58,4,0,20)
			colorBtn.BackgroundColor3 = COLOR_PALETTE[colorIdx].color
			colorBtn.Text = COLOR_PALETTE[colorIdx].name
			colorBtn.Font = Enum.Font.GothamBold
			colorBtn.TextColor3 = Color3.fromRGB(0,0,0)
			colorBtn.TextSize = 10
			colorBtn.BorderSizePixel = 0
			colorBtn.Parent = row
			local cbc3 = Instance.new("UICorner"); cbc3.CornerRadius = UDim.new(0,3); cbc3.Parent = colorBtn

			nameBox.FocusLost:Connect(function()
				if not customPlayerData[uid] then customPlayerData[uid] = {name="", color=C_WHITE} end
				customPlayerData[uid].name = nameBox.Text
			end)

			colorBtn.MouseButton1Click:Connect(function()
				colorIdx = colorIdx % #COLOR_PALETTE + 1
				local opt = COLOR_PALETTE[colorIdx]
				colorBtn.BackgroundColor3 = opt.color
				colorBtn.Text = opt.name
				if not customPlayerData[uid] then customPlayerData[uid] = {name="", color=C_WHITE, imageId=""} end
				customPlayerData[uid].color = opt.color
				nameBox.TextColor3 = opt.color
			end)

			-- ─── CAMPO ID DE IMAGEN DEL JUGADOR (se muestra al lado de la torre) ───
			row.Size = UDim2.new(1, 0, 0, 78)

			local imgIdLbl = Instance.new("TextLabel")
			imgIdLbl.Size           = UDim2.new(0.36, 0, 0, 20)
			imgIdLbl.Position       = UDim2.new(0, 6, 0, 52)
			imgIdLbl.BackgroundTransparency = 1
			imgIdLbl.Text           = "🖼 ID Imagen:"
			imgIdLbl.Font           = Enum.Font.GothamBold
			imgIdLbl.TextColor3     = C_GRAY
			imgIdLbl.TextSize       = 10
			imgIdLbl.TextXAlignment = Enum.TextXAlignment.Left
			imgIdLbl.Parent         = row

			local imgIdBox = Instance.new("TextBox")
			imgIdBox.Size           = UDim2.new(0.57, -6, 0, 20)
			imgIdBox.Position       = UDim2.new(0.37, 2, 0, 52)
			imgIdBox.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
			imgIdBox.BorderSizePixel  = 0
			imgIdBox.Font             = Enum.Font.GothamBold
			imgIdBox.TextColor3       = C_YELLOW
			imgIdBox.TextSize         = 10
			local _icd = customPlayerData[uid]
			imgIdBox.Text             = (_icd and _icd.imageId) or ""
			imgIdBox.PlaceholderText  = "ej: 107605669230122"
			imgIdBox.ClearTextOnFocus = false
			imgIdBox.TextXAlignment   = Enum.TextXAlignment.Left
			imgIdBox.Parent           = row
			Instance.new("UICorner", imgIdBox).CornerRadius = UDim.new(0, 3)
			local _ibPad = Instance.new("UIPadding"); _ibPad.PaddingLeft = UDim.new(0,4); _ibPad.Parent = imgIdBox

			local imgPreview = Instance.new("ImageLabel")
			imgPreview.Size             = UDim2.new(0, 20, 0, 20)
			imgPreview.Position         = UDim2.new(1, -24, 0, 52)
			imgPreview.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
			imgPreview.BorderSizePixel  = 0
			imgPreview.ScaleType        = Enum.ScaleType.Fit
			imgPreview.Image            = (_icd and _icd.imageId and _icd.imageId ~= "") and ("rbxassetid://".._icd.imageId) or ""
			imgPreview.Parent           = row
			Instance.new("UICorner", imgPreview).CornerRadius = UDim.new(0, 3)

			imgIdBox.FocusLost:Connect(function()
				local rawId = imgIdBox.Text:gsub("%D", "")
				imgIdBox.Text = rawId
				if not customPlayerData[uid] then customPlayerData[uid] = {name="", color=C_WHITE, imageId=""} end
				customPlayerData[uid].imageId = rawId
				imgPreview.Image = rawId ~= "" and ("rbxassetid://"..rawId) or ""
				-- Actualizar imagen en fila de la torre en tiempo real
				local tRow = towerRows[uid]
				if tRow then
					local pImg = tRow:FindFirstChild("PlayerImg")
					if pImg then
						pImg.Image = rawId ~= "" and ("rbxassetid://"..rawId) or ""
					end
				end
			end)

			-- ── LÍMITES PERSONALIZADOS POR PILOTO ──────────────────────
			row.Size = UDim2.new(1, 0, 0, 188)  -- ampliado para 4 límites extra
			local function mkLimL(txt, yp)
				local l=Instance.new("TextLabel"); l.Size=UDim2.new(0.35,0,0,18); l.Position=UDim2.new(0,6,0,yp)
				l.BackgroundTransparency=1; l.Text=txt; l.Font=Enum.Font.GothamBold
				l.TextColor3=C_GRAY; l.TextSize=9; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=row; return l
			end
			-- 1) Velocidad límite
			mkLimL("🚗 Vel lím km/h", 80)
			local spdBox=Instance.new("TextBox"); spdBox.Size=UDim2.new(0.28,0,0,18); spdBox.Position=UDim2.new(0.36,2,0,80)
			spdBox.BackgroundColor3=Color3.fromRGB(28,28,42); spdBox.BorderSizePixel=0
			spdBox.Font=Enum.Font.GothamBold; spdBox.TextColor3=C_YELLOW; spdBox.TextSize=10
			local _cdA=customPlayerData[uid]
			spdBox.Text=(_cdA and _cdA.speedLimit) and tostring(_cdA.speedLimit) or ""
			spdBox.PlaceholderText=tostring(SPEED_LIMIT); spdBox.ClearTextOnFocus=false
			spdBox.TextXAlignment=Enum.TextXAlignment.Left; spdBox.Parent=row
			Instance.new("UICorner",spdBox).CornerRadius=UDim.new(0,3)
			spdBox.FocusLost:Connect(function()
				local n=tonumber(spdBox.Text:gsub("%D",""))
				if not customPlayerData[uid] then customPlayerData[uid]={name="",color=C_WHITE,imageId=""} end
				customPlayerData[uid].speedLimit=n; spdBox.Text=n and tostring(n) or ""
			end)
			-- 2) Turbo máximo
			mkLimL("⚡ Turbo máx", 102)
			local trbIdx=1
			do local _cdB=customPlayerData[uid]
				if _cdB and _cdB.maxTurbo then
					for ci,n in ipairs(SPA_Telemetry.TURBO_CYCLE) do if n==_cdB.maxTurbo then trbIdx=ci;break end end
				end
			end
			local trbBtn=Instance.new("TextButton"); trbBtn.Size=UDim2.new(0.60,0,0,18); trbBtn.Position=UDim2.new(0.36,2,0,102)
			trbBtn.BackgroundColor3=Color3.fromRGB(30,30,45); trbBtn.BorderSizePixel=0
			trbBtn.Font=Enum.Font.GothamBold; trbBtn.TextColor3=C_ORANGE; trbBtn.TextSize=10
			trbBtn.Text=SPA_Telemetry.TURBO_CYCLE[trbIdx]; trbBtn.Parent=row
			Instance.new("UICorner",trbBtn).CornerRadius=UDim.new(0,3)
			trbBtn.MouseButton1Click:Connect(function()
				trbIdx=trbIdx%#SPA_Telemetry.TURBO_CYCLE+1
				trbBtn.Text=SPA_Telemetry.TURBO_CYCLE[trbIdx]
				if not customPlayerData[uid] then customPlayerData[uid]={name="",color=C_WHITE,imageId=""} end
				customPlayerData[uid].maxTurbo=trbIdx==1 and nil or SPA_Telemetry.TURBO_CYCLE[trbIdx]
			end)
			-- 3) Suspensión máxima
			mkLimL("🔧 Susp máx", 124)
			local spIdx=1
			do local _cdC=customPlayerData[uid]
				if _cdC and _cdC.maxSusp then
					for ci,n in ipairs(SPA_Telemetry.SUSP_CYCLE) do if n==_cdC.maxSusp then spIdx=ci;break end end
				end
			end
			local spBtn=Instance.new("TextButton"); spBtn.Size=UDim2.new(0.60,0,0,18); spBtn.Position=UDim2.new(0.36,2,0,124)
			spBtn.BackgroundColor3=Color3.fromRGB(30,30,45); spBtn.BorderSizePixel=0
			spBtn.Font=Enum.Font.GothamBold; spBtn.TextColor3=C_GREEN; spBtn.TextSize=10
			spBtn.Text=SPA_Telemetry.SUSP_CYCLE[spIdx]; spBtn.Parent=row
			Instance.new("UICorner",spBtn).CornerRadius=UDim.new(0,3)
			spBtn.MouseButton1Click:Connect(function()
				spIdx=spIdx%#SPA_Telemetry.SUSP_CYCLE+1
				spBtn.Text=SPA_Telemetry.SUSP_CYCLE[spIdx]
				if not customPlayerData[uid] then customPlayerData[uid]={name="",color=C_WHITE,imageId=""} end
				customPlayerData[uid].maxSusp=spIdx==1 and nil or SPA_Telemetry.SUSP_CYCLE[spIdx]
			end)
			-- 4) Drift máximo
			mkLimL("💨 Drift máx", 146)
			local drfBox=Instance.new("TextBox"); drfBox.Size=UDim2.new(0.28,0,0,18); drfBox.Position=UDim2.new(0.36,2,0,146)
			drfBox.BackgroundColor3=Color3.fromRGB(28,28,42); drfBox.BorderSizePixel=0
			drfBox.Font=Enum.Font.GothamBold; drfBox.TextColor3=C_YELLOW; drfBox.TextSize=10
			local _cdD=customPlayerData[uid]
			drfBox.Text=(_cdD and _cdD.maxDrift) and tostring(_cdD.maxDrift) or ""
			drfBox.PlaceholderText="ej: 2.5"; drfBox.ClearTextOnFocus=false
			drfBox.TextXAlignment=Enum.TextXAlignment.Left; drfBox.Parent=row
			Instance.new("UICorner",drfBox).CornerRadius=UDim.new(0,3)
			drfBox.FocusLost:Connect(function()
				local n=tonumber(drfBox.Text)
				if not customPlayerData[uid] then customPlayerData[uid]={name="",color=C_WHITE,imageId=""} end
				customPlayerData[uid].maxDrift=n; drfBox.Text=n and tostring(n) or ""
			end)
		end

		local clearRow = Instance.new("Frame")
		clearRow.Size = UDim2.new(1,0,0,30)
		clearRow.BackgroundColor3 = C_BG
		clearRow.BorderSizePixel = 0
		clearRow.LayoutOrder = 999
		clearRow.Parent = nameConfigBody

		local clearBtn = Instance.new("TextButton")
		clearBtn.Size = UDim2.new(1,-12,0.8,0)
		clearBtn.Position = UDim2.new(0,6,0.1,0)
		clearBtn.BackgroundColor3 = C_DARKRED
		clearBtn.Text = "↺  LIMPIAR TODOS LOS NOMBRES"
		clearBtn.Font = Enum.Font.GothamBlack
		clearBtn.TextColor3 = C_WHITE
		clearBtn.TextSize = 11
		clearBtn.BorderSizePixel = 0
		clearBtn.Parent = clearRow
		local clc = Instance.new("UICorner"); clc.CornerRadius = UDim.new(0,3); clc.Parent = clearBtn
		clearBtn.MouseButton1Click:Connect(function()
			customPlayerData = {}
			buildNameConfigRows()
		end)

		-- [SDE_INFI] Botón CERRAR PERSONALIZACIÓN
		local closeRow = Instance.new("Frame")
		closeRow.Size = UDim2.new(1,0,0,30)
		closeRow.BackgroundColor3 = C_BG
		closeRow.BorderSizePixel = 0
		closeRow.LayoutOrder = 1000
		closeRow.Parent = nameConfigBody

		local closeConfigBtn = Instance.new("TextButton")
		closeConfigBtn.Size = UDim2.new(1,-12,0.8,0)
		closeConfigBtn.Position = UDim2.new(0,6,0.1,0)
		closeConfigBtn.BackgroundColor3 = C_DARKRED
		closeConfigBtn.Text = "✕  CERRAR PERSONALIZACIÓN"
		closeConfigBtn.Font = Enum.Font.GothamBlack
		closeConfigBtn.TextColor3 = C_WHITE
		closeConfigBtn.TextSize = 11
		closeConfigBtn.BorderSizePixel = 0
		closeConfigBtn.Parent = closeRow
		local clcc = Instance.new("UICorner"); clcc.CornerRadius = UDim.new(0,3); clcc.Parent = closeConfigBtn
		closeConfigBtn.MouseButton1Click:Connect(function()
			nameConfigBody.Visible = false
			nameConfigHeader.Text  = "✏  NOMBRES Y COLORES PERSONALIZADOS  ▼"
		end)
	end

	buildNameConfigRows()
	Players.PlayerAdded:Connect(function()   task.wait(1);   buildNameConfigRows() end)
	Players.PlayerRemoving:Connect(function() task.wait(0.2); buildNameConfigRows() end)

	-- FIA list
	local function buildFIAList()
		for _, c in ipairs(fiaScroll:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
		end

		local infoRow = Instance.new("Frame")
		infoRow.Size = UDim2.new(1,0,0,36)
		infoRow.BackgroundColor3 = C_BLUE
		infoRow.BorderSizePixel = 0
		infoRow.LayoutOrder = 0
		infoRow.Parent = fiaScroll
		local infoC = Instance.new("UICorner"); infoC.CornerRadius = UDim.new(0,4); infoC.Parent = infoRow
		local infoLbl = Instance.new("TextLabel")
		infoLbl.Size = UDim2.new(1,-10,1,0)
		infoLbl.Position = UDim2.new(0,8,0,0)
		infoLbl.BackgroundTransparency = 1
		infoLbl.Text = "🔵 EXCLUIDO  —  no cuenta vueltas ni tiempo"
		infoLbl.Font = Enum.Font.GothamBold
		infoLbl.TextColor3 = C_WHITE
		infoLbl.TextSize = 11
		infoLbl.TextXAlignment = Enum.TextXAlignment.Left
		infoLbl.TextWrapped = true
		infoLbl.Parent = infoRow

		local allPlayers = Players:GetPlayers()
		for i, plr in ipairs(allPlayers) do
			local uid        = plr.UserId
			local isExcluded = FIA_EXCLUDED[uid] == true

			local row = Instance.new("Frame")
			row.Name            = "FIA_ROW_"..uid
			row.Size            = UDim2.new(1,0,0,38)
			row.BackgroundColor3= isExcluded and Color3.fromRGB(20,30,55) or C_BG2
			row.BorderSizePixel = 0
			row.LayoutOrder     = i
			row.Parent          = fiaScroll

			local sideBar = Instance.new("Frame")
			sideBar.Size            = UDim2.new(0,4,1,0)
			sideBar.BackgroundColor3= isExcluded and C_BLUE or C_GRAY
			sideBar.BorderSizePixel = 0
			sideBar.Parent          = row

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(0.55,0,1,0)
			nameLbl.Position = UDim2.new(0,14,0,0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = plr.Name
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.TextColor3 = isExcluded and C_BLUE or C_WHITE
			nameLbl.TextSize = 13
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.Parent = row

			local statusLbl = Instance.new("TextLabel")
			statusLbl.Size = UDim2.new(0.22,0,1,0)
			statusLbl.Position = UDim2.new(0.38,0,0,0)
			statusLbl.BackgroundTransparency = 1
			statusLbl.Text = isExcluded and "EXCLUIDO" or "ACTIVO"
			statusLbl.Font = Enum.Font.GothamBold
			statusLbl.TextColor3 = isExcluded and C_BLUE or C_GREEN
			statusLbl.TextSize = 11
			statusLbl.TextXAlignment = Enum.TextXAlignment.Center
			statusLbl.Parent = row

			local toggleBtn = Instance.new("TextButton")
			toggleBtn.Size = UDim2.new(0.28,-8,0.7,0)
			toggleBtn.Position = UDim2.new(0.72,0,0.15,0)
			toggleBtn.BackgroundColor3 = isExcluded and C_BLUE or Color3.fromRGB(0,100,40)
			toggleBtn.Text = isExcluded and "REINCORPORAR" or "EXCLUIR"
			toggleBtn.Font = Enum.Font.GothamBold
			toggleBtn.TextColor3 = C_WHITE
			toggleBtn.TextSize = 10
			toggleBtn.BorderSizePixel = 0
			toggleBtn.Parent = row
			local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,3); bc.Parent = toggleBtn
			local rp = Instance.new("UIPadding"); rp.PaddingRight = UDim.new(0,6); rp.Parent = row

			toggleBtn.MouseButton1Click:Connect(function()
				FIA_EXCLUDED[uid] = not FIA_EXCLUDED[uid]
				buildFIAList()
			end)
		end

		local clearRow = Instance.new("Frame")
		clearRow.Size = UDim2.new(1,0,0,38)
		clearRow.BackgroundColor3 = C_BG
		clearRow.BorderSizePixel = 0
		clearRow.LayoutOrder = 999
		clearRow.Parent = fiaScroll

		local clearBtn = Instance.new("TextButton")
		clearBtn.Size = UDim2.new(1,-16,0.75,0)
		clearBtn.Position = UDim2.new(0,8,0.125,0)
		clearBtn.BackgroundColor3 = C_DARKRED
		clearBtn.Text = "↺  REINCORPORAR A TODOS"
		clearBtn.Font = Enum.Font.GothamBlack
		clearBtn.TextColor3 = C_WHITE
		clearBtn.TextSize = 12
		clearBtn.BorderSizePixel = 0
		clearBtn.Parent = clearRow
		local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0,3); cc.Parent = clearBtn
		clearBtn.MouseButton1Click:Connect(function()
			FIA_EXCLUDED = {}
			buildFIAList()
		end)
	end

	buildFIAList()
	Players.PlayerAdded:Connect(function() task.wait(1); buildFIAList() end)
	Players.PlayerRemoving:Connect(function(pl) FIA_EXCLUDED[pl.UserId] = nil; task.wait(0.1); buildFIAList() end)
	tabButtons["FIA"].MouseButton1Click:Connect(function() buildFIAList() end)

	-- ONBOARD / SPECTATING
	local SPECT_FOV                   = 70
	local SPECT_HORIZONTAL_DISTANCE   = 60
	local SPECT_MIN_HEIGHT            = 20
	local SPECT_MAX_HEIGHT            = 150
	local SPECT_REPOSITION_THRESHOLD  = 160

	local spectCameraOffset       = Vector3.new(0,0,0)
	local spectFixedCameraPosition= Vector3.new(0,0,0)
	local spectLastPosition       = Vector3.new(0,0,0)
	local spectTotalDistance      = 0
	local spectCurrentIndex       = 1

	local spectHUD = Instance.new("TextLabel")
	spectHUD.Name = "SpectTrackingHUD"
	spectHUD.Size = UDim2.new(0,280,0,32)
	spectHUD.Position = UDim2.new(0.5,-140,1,-80)
	spectHUD.BackgroundColor3 = Color3.fromRGB(20,20,20)
	spectHUD.BackgroundTransparency = 0.3
	spectHUD.BorderSizePixel = 0
	spectHUD.Font = Enum.Font.GothamBold
	spectHUD.Text = ""
	spectHUD.TextColor3 = Color3.fromRGB(255,120,0)
	spectHUD.TextScaled = true
	spectHUD.Visible = false
	spectHUD.Parent = mainGui
	local spectHUDCorner = Instance.new("UICorner",spectHUD)
	spectHUDCorner.CornerRadius = UDim.new(0,8)

	local function spectRandomizeOffset()
		local angle   = mrandom() * 2 * mpi
		local height  = mrandom(SPECT_MIN_HEIGHT, SPECT_MAX_HEIGHT)
		local offsetXZ= Vector3.new(math.cos(angle)*SPECT_HORIZONTAL_DISTANCE, 0, math.sin(angle)*SPECT_HORIZONTAL_DISTANCE)
		spectCameraOffset = offsetXZ + Vector3.new(0,height,0)
	end

	local function spectatePlayerFunc(plr, index)
		if not plr or plr == player then return end
		if not isSpectating then
			isSpectating = true
			originalCameraType    = Camera.CameraType
			originalCameraSubject = Camera.CameraSubject

			spectRenderConnection = RunService.RenderStepped:Connect(function()
				if not (isSpectating and targetSpectPlayer) then return end
				if not targetSpectPlayer.Parent then stopSpectatingFunc(); return end
				local char = targetSpectPlayer.Character
				if not char then stopSpectatingFunc(); return end
				local rootPart = char:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local currentPos = rootPart.Position
					spectTotalDistance += (currentPos - spectLastPosition).Magnitude
					spectLastPosition   = currentPos
					if spectTotalDistance >= SPECT_REPOSITION_THRESHOLD then
						spectRandomizeOffset()
						spectFixedCameraPosition = currentPos + spectCameraOffset
						spectTotalDistance = 0
					end
					local lookAt = currentPos + Vector3.new(0,3,0)
					Camera.CFrame = CFrame.lookAt(spectFixedCameraPosition, lookAt)
				else
					stopSpectatingFunc()
				end
			end)
		end

		targetSpectPlayer = plr
		spectCurrentIndex = index or 1

		local char = plr.Character
		if not char then return end
		local rootPart = char:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		spectRandomizeOffset()
		spectLastPosition        = rootPart.Position
		spectFixedCameraPosition = spectLastPosition + spectCameraOffset
		spectTotalDistance       = 0

		Camera.CameraType   = Enum.CameraType.Scriptable
		Camera.FieldOfView  = SPECT_FOV

		spectHUD.Text    = "📹 TRACKING: " .. plr.Name
		spectHUD.Visible = true

		for _, btn in ipairs(onboardScroll:GetChildren()) do
			if btn:IsA("TextButton") and btn.Name:match("^OB_") then
				btn.BackgroundColor3 = btn.Name == "OB_"..plr.UserId and C_RED or C_BG2
			end
		end
	end

	function stopSpectatingFunc()
		if not isSpectating then return end
		isSpectating      = false
		targetSpectPlayer = nil
		if spectRenderConnection then spectRenderConnection:Disconnect(); spectRenderConnection = nil end
		Camera.CameraType = originalCameraType or Enum.CameraType.Custom
		local myChar = player.Character
		if myChar then
			local myHum = myChar:FindFirstChildOfClass("Humanoid")
			if myHum then Camera.CameraSubject = myHum else Camera.CameraSubject = originalCameraSubject or myChar:FindFirstChild("Head") end
		else
			task.spawn(function()
				player.CharacterAdded:Wait()
				task.wait(0.5)
				local newChar = player.Character
				if newChar then
					local newHum = newChar:FindFirstChildOfClass("Humanoid")
					if newHum then Camera.CameraSubject = newHum; Camera.CameraType = Enum.CameraType.Custom end
				end
			end)
		end
		spectHUD.Visible = false
		for _, btn in ipairs(onboardScroll:GetChildren()) do
			if btn:IsA("TextButton") and btn.Name:match("^OB_") then btn.BackgroundColor3 = C_BG2 end
		end
	end

	local function buildOnboardList()
		for _, c in ipairs(onboardScroll:GetChildren()) do
			if c:IsA("TextButton") or c:IsA("TextLabel") or c:IsA("Frame") then c:Destroy() end
		end
		makeSectionHeader(onboardScroll, "📹  TRACKING CAMERA", 0)
		local others = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then tinsert(others, plr) end
		end
		for i, plr in ipairs(others) do
			local btn = Instance.new("TextButton")
			btn.Name = "OB_"..plr.UserId
			btn.Size = UDim2.new(1,0,0,36)
			btn.BackgroundColor3 = C_BG2
			btn.Text = ""
			btn.BorderSizePixel = 0
			btn.LayoutOrder = i
			btn.Parent = onboardScroll

			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(0,3,1,0)
			bar.BackgroundColor3 = Color3.fromHSV((i*0.13)%1,0.85,1)
			bar.BorderSizePixel = 0
			bar.Parent = btn

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(0.7,0,1,0)
			nameLbl.Position = UDim2.new(0,14,0,0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = "▶  "..plr.Name
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.TextColor3 = C_WHITE
			nameLbl.TextSize = 13
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.Parent = btn

			btn.MouseButton1Click:Connect(function() spectatePlayerFunc(plr, i) end)
		end

		local navRow = Instance.new("Frame")
		navRow.Size = UDim2.new(1,0,0,36)
		navRow.BackgroundTransparency = 1
		navRow.BorderSizePixel = 0
		navRow.LayoutOrder = 900
		navRow.Parent = onboardScroll

		local navLayout = Instance.new("UIListLayout")
		navLayout.FillDirection = Enum.FillDirection.Horizontal
		navLayout.Padding = UDim.new(0,4)
		navLayout.Parent = navRow

		local prevBtn = Instance.new("TextButton")
		prevBtn.Size = UDim2.new(0.5,-2,1,0)
		prevBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
		prevBtn.Text = "◄ PREV"
		prevBtn.Font = Enum.Font.GothamBold
		prevBtn.TextColor3 = C_WHITE
		prevBtn.TextScaled = true
		prevBtn.BorderSizePixel = 0
		prevBtn.Parent = navRow
		local prevC = Instance.new("UICorner",prevBtn); prevC.CornerRadius = UDim.new(0,6)

		local nextBtn = Instance.new("TextButton")
		nextBtn.Size = UDim2.new(0.5,-2,1,0)
		nextBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
		nextBtn.Text = "NEXT ►"
		nextBtn.Font = Enum.Font.GothamBold
		nextBtn.TextColor3 = C_WHITE
		nextBtn.TextScaled = true
		nextBtn.BorderSizePixel = 0
		nextBtn.Parent = navRow
		local nextC = Instance.new("UICorner",nextBtn); nextC.CornerRadius = UDim.new(0,6)

		prevBtn.MouseButton1Click:Connect(function()
			local valid = {}
			for _, p in ipairs(Players:GetPlayers()) do if p ~= player then tinsert(valid, p) end end
			if #valid > 0 then
				spectCurrentIndex = spectCurrentIndex - 1
				if spectCurrentIndex < 1 then spectCurrentIndex = #valid end
				spectatePlayerFunc(valid[spectCurrentIndex], spectCurrentIndex)
			end
		end)
		nextBtn.MouseButton1Click:Connect(function()
			local valid = {}
			for _, p in ipairs(Players:GetPlayers()) do if p ~= player then tinsert(valid, p) end end
			if #valid > 0 then
				spectCurrentIndex = spectCurrentIndex + 1
				if spectCurrentIndex > #valid then spectCurrentIndex = 1 end
				spectatePlayerFunc(valid[spectCurrentIndex], spectCurrentIndex)
			end
		end)

		local exitBtn = Instance.new("TextButton")
		exitBtn.Size = UDim2.new(1,0,0,40)
		exitBtn.BackgroundColor3 = C_DARKRED
		exitBtn.Text = "✕  SALIR DE TRACKING"
		exitBtn.Font = Enum.Font.GothamBlack
		exitBtn.TextColor3 = C_WHITE
		exitBtn.TextSize = 13
		exitBtn.BorderSizePixel = 0
		exitBtn.LayoutOrder = 999
		exitBtn.Parent = onboardScroll
		exitBtn.MouseButton1Click:Connect(stopSpectatingFunc)
	end

	buildOnboardList()
	Players.PlayerAdded:Connect(function()   task.wait(1); buildOnboardList() end)
	Players.PlayerRemoving:Connect(function(pl)
		if targetSpectPlayer == pl then stopSpectatingFunc() end
		buildOnboardList()
	end)
end

-- ════════════════════════════════════════════════════════════════
-- ███  SPA COLLISION DETECTION SYSTEM (SPAV4 · Alpha)  ███████████
-- Toda la data vive en la tabla GLOBAL SPA_Crash → 0 nuevos locals
-- en el chunk principal.
-- ════════════════════════════════════════════════════════════════

-- [SDE_INFI · CAMBIO 1] Tabla de control del Heartbeat maestro único
-- Una sola global en vez de 9 sueltas — evita colisiones en el executor
_SDEI = {
	-- Acumuladores de tiempo
	HB = { crash=0, anal=0, buf=0, prx=0, head=0, lap=0, tire=0 },
	-- Cuerpos de cada subsistema (se asignan dentro de sus setup functions)
	hbCrash=nil, hbAnal=nil, hbBuf=nil, hbPrx=nil,
	hbHead=nil,  hbLap=nil,  hbTire=nil,
}

SPA_Crash = {
	-- [SPAV4] Umbrales calibrados para VehicleSeats únicamente (no peatones)
	THRESHOLD      = 28,   -- Δv mínimo (studs/s) para impacto en vehículo (sube vs peatones)
	RADIUS         = 28,   -- radio (studs) entre coches para choque coche-coche
	COOLDOWN_PAIR = 8,    -- segundos entre el mismo par
	COOLDOWN_WALL = 4,    -- segundos muro por mismo jugador
	MIN_SPEED      = 18,   -- velocidad mínima (studs/s) — ignora paradas y maniobras lentas
	GRACE_LAP      = 5,    -- segundos de gracia tras cruzar LAP_WALL
	MAX_LOG        = 60,   -- máximo de entradas en el historial

	-- Runtime data (se populan en _setupCollisionDetection)
	prevVel     = {},  -- [uid] = Vector3  velocidad frame anterior
	pairCD      = {},  -- ["uid1_uid2"] = tick()
	wallCD      = {},  -- [uid] = tick()
	graceLap    = {},  -- [uid] = tick()   tiempo del último cruce de meta
	log         = {},  -- array de entradas de choque
	rebuildFn   = nil, -- función para refrescar la UI (asignada en setup)
}

-- [SPAV4 MEJORADO] Detecta si el jugador está ACTIVAMENTE en un VehicleSeat
-- Jugadores a pie / en silla normal / sin personaje → false, nil
local function _crashInVehicle(p)
	local char = p.Character
	if not char then return false, nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return false, nil end
	local seat = hum.SeatPart
	-- seat.Occupant == hum garantiza que él ESTÁ sentado ahí (no que acabe de salir)
	if seat and seat:IsA("VehicleSeat") and seat.Occupant == hum then
		return true, seat
	end
	return false, nil
end

-- Retorna la velocidad del VehicleSeat, o NIL si no está en un coche.
-- nil = el jugador NO se detecta para choques (peatón, spectator, etc.)
local function _crashGetVel(p)
	local inSeat, seat = _crashInVehicle(p)
	if not inSeat or not seat then return nil end
	local ok, v = pcall(function() return seat.AssemblyLinearVelocity end)
	if not ok or not v then return nil end
	return v
end

-- Helper: tipo de impacto por ángulo relativo
local function _crashType(velA, posA, posB)
	local dir = (posB - posA)
	if dir.Magnitude < 0.01 then return "CONTACTO" end
	dir = dir.Unit
	local vn = velA.Magnitude < 0.01 and dir or velA.Unit
	local dot = mclamp(vn:Dot(dir), -1, 1)
	local ang = math.deg(math.acos(dot))
	if ang < 35 then return "ALCANCE"
	elseif ang < 65 then return "LATERAL"
	elseif ang < 115 then return "T-BONE"
	else return "FRONTAL" end
end

-- Helper: severidad por magnitud del Δv
local function _crashSeverity(delta)
	if delta >= 50 then return "FUERTE", C_RED
	elseif delta >= 32 then return "MODERADO", C_ORANGE
	else return "LEVE", C_YELLOW end
end

function _setupCollisionDetection()
	-- ── Actualiza el LAP grace period ────────────────────────────
	-- Se conecta al mismo trigger de vuelta: si el jugador cruza la
	-- línea, se guarda el tick para ignorar micro-choques de salida.
	local _lapOrig = lapWall
	if _lapOrig and _lapOrig.Parent then
		-- hook pasivo: revisamos via lapData.lastLapTouch en la detección
		-- (no necesita nuevo evento)
	end

	-- [SDE_INFI · CAMBIO 1] Cuerpo extraído como función — fusionado en Heartbeat maestro
	_SDEI.hbCrash = function()
		local allPl = Players:GetPlayers()
		local impacted = {}   -- [uid] = {delta, pos, vel, player}

		-- 1) Muestrear velocidades y detectar Δv alto
		for _, p in ipairs(allPl) do
			local uid = p.UserId
			if FIA_EXCLUDED[uid] then continue end
			if pitData[uid] and pitData[uid].status == "En Boxes" then continue end

			-- [SPAV4] nil = no está en VehicleSeat → ignorar completamente
			local vel = _crashGetVel(p)
			if not vel then
				-- Limpiar historial: evita falsa alarma al volver a entrar al coche
				SPA_Crash.prevVel[uid] = nil
				continue
			end

			local prev = SPA_Crash.prevVel[uid] or vel
			local delta = (vel - prev).Magnitude
			SPA_Crash.prevVel[uid] = vel

			local speed = vel.Magnitude
			if delta < SPA_Crash.THRESHOLD then continue end
			-- Ambas velocidades (actual y anterior) deben superar MIN_SPEED
			-- Así ignoramos arrancadas lentas o frenadas de pit-lane
			if speed < SPA_Crash.MIN_SPEED and prev.Magnitude < SPA_Crash.MIN_SPEED then continue end

			-- Grace period tras cruzar meta (evita detectar roce al inicio de vuelta)
			local ld = lapData[uid]
			if ld and ld.lastLapTouch and (tick() - ld.lastLapTouch) < SPA_Crash.GRACE_LAP then continue end

			local char = p.Character
			if not char then continue end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then continue end

			impacted[uid] = { delta=delta, pos=hrp.Position, vel=vel, player=p }
		end

		-- 2) Parear impactos cercanos (coche-coche) o marcar muro
		local processed = {}
		for uid1, d1 in pairs(impacted) do
			if processed[uid1] then continue end
			local paired = false

			for uid2, d2 in pairs(impacted) do
				if uid2 == uid1 or processed[uid2] then continue end
				local dist = (d1.pos - d2.pos).Magnitude
				if dist > SPA_Crash.RADIUS then continue end

				-- Cooldown por par (orden UID ascendente)
				local k = uid1 < uid2 and (uid1.."_"..uid2) or (uid2.."_"..uid1)
				if SPA_Crash.pairCD[k] and (tick() - SPA_Crash.pairCD[k]) < SPA_Crash.COOLDOWN_PAIR then
					processed[uid1]=true; processed[uid2]=true; paired=true; break
				end
				SPA_Crash.pairCD[k] = tick()
				processed[uid1]=true; processed[uid2]=true; paired=true

				-- Clasificar
				local tipo = _crashType(d1.vel, d1.pos, d2.pos)
				-- Velocidad de cierre (closing speed) entre los dos coches: más precisa que solo Δv
				local closingSpeed = (d1.vel - d2.vel).Magnitude
				local impactMagnitude = math.max(d1.delta, d2.delta, closingSpeed * 0.6)
				local sev, sevColor = _crashSeverity(impactMagnitude)
				local nA = getDisplayName(d1.player)
				local nB = getDisplayName(d2.player)
				local kmhA = mfloor(d1.vel.Magnitude * 0.28 * 3.6 * CAL_FACTOR + 0.5)
				local kmhB = mfloor(d2.vel.Magnitude * 0.28 * 3.6 * CAL_FACTOR + 0.5)

				-- Notificación corta (solo quién chocó con quién)
				local icon = tipo == "ALCANCE" and "🚗💨" or (tipo == "FRONTAL" and "💥" or "⚠")
				showNotification(icon .. "  " .. nA .. "  ↔  " .. nB, C_ORANGE, "💥", 20)

				-- Log completo
				table.insert(SPA_Crash.log, 1, {
					time     = os.date("%H:%M:%S"),
					type     = tipo,
					sev      = sev,
					sevColor = sevColor,
					nameA    = nA,
					nameB    = nB,
					speedA   = kmhA,
					speedB   = kmhB,
					delta    = mfloor(math.max(d1.delta, d2.delta)),
					dist     = mfloor(dist),
					wall     = false,
				})
				if #SPA_Crash.log > SPA_Crash.MAX_LOG then table.remove(SPA_Crash.log) end
				if SPA_Crash.rebuildFn then SPA_Crash.rebuildFn() end
				break
			end

			-- Sin par → golpe de muro
			if not paired then
				processed[uid1] = true
				if SPA_Crash.wallCD[uid1] and (tick()-SPA_Crash.wallCD[uid1]) < SPA_Crash.COOLDOWN_WALL then continue end
				SPA_Crash.wallCD[uid1] = tick()

				local nA = getDisplayName(d1.player)
				local kmhA = mfloor(d1.vel.Magnitude * 0.28 * 3.6 * CAL_FACTOR + 0.5)
				local sev, sevColor = _crashSeverity(d1.delta)

				showNotification("🧱  " .. nA .. "  chocó contra un muro", C_GRAY, "🧱", 20)

				table.insert(SPA_Crash.log, 1, {
					time     = os.date("%H:%M:%S"),
					type     = "MURO",
					sev      = sev,
					sevColor = sevColor,
					nameA    = nA,
					nameB    = nil,
					speedA   = kmhA,
					speedB   = 0,
					delta    = mfloor(d1.delta),
					dist     = 0,
					wall     = true,
				})
				if #SPA_Crash.log > SPA_Crash.MAX_LOG then table.remove(SPA_Crash.log) end
				if SPA_Crash.rebuildFn then SPA_Crash.rebuildFn() end
			end
		end
	end

	-- ── UI de la pestaña CHOQUES ─────────────────────────────────
	local choquesFrame = tabFrames["CHOQUES"]
	if not choquesFrame then return end

	local chScroll = Instance.new("ScrollingFrame")
	chScroll.Size                = UDim2.new(1, 0, 1, 0)
	chScroll.BackgroundColor3    = C_BG
	chScroll.BackgroundTransparency = 0.12
	chScroll.BorderSizePixel     = 0
	chScroll.CanvasSize          = UDim2.new(0, 0, 0, 0)  -- gestionado por listener
	chScroll.ScrollingDirection  = Enum.ScrollingDirection.Y
	chScroll.ScrollBarThickness  = 8
	chScroll.ScrollBarImageColor3= C_ORANGE
	chScroll.ElasticBehavior     = Enum.ElasticBehavior.Always
	chScroll.Parent = choquesFrame

	local chLayout = Instance.new("UIListLayout")
	chLayout.Padding   = UDim.new(0, 2)
	chLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chLayout.Parent    = chScroll
	-- Scroll infinito: sincronizar canvas con el contenido real
	local function _syncCh()
		chScroll.CanvasSize = UDim2.new(0, 0, 0, chLayout.AbsoluteContentSize.Y + 24)
	end
	chLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(_syncCh)
	task.defer(_syncCh)

	-- Función de rebuild UI (se asigna en SPA_Crash.rebuildFn)
	local function rebuildChoquesUI()
		for _, c in ipairs(chScroll:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
		end

		-- Header con estadísticas
		local totalCars  = 0
		local totalWalls = 0
		for _, e in ipairs(SPA_Crash.log) do
			if e.wall then totalWalls+=1 else totalCars+=1 end
		end

		local statBar = Instance.new("Frame")
		statBar.Size = UDim2.new(1,0,0,44)
		statBar.BackgroundColor3 = Color3.fromRGB(12,12,18)
		statBar.BackgroundTransparency = 0.1
		statBar.BorderSizePixel = 0
		statBar.LayoutOrder = 0
		statBar.Parent = chScroll

		local function makeStatCell(txt, val, col, xPos)
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(0.33,0,1,0)
			lbl.Position = UDim2.new(xPos,0,0,0)
			lbl.BackgroundTransparency = 1
			lbl.Text = val .. "\n" .. txt
			lbl.Font = Enum.Font.GothamBold
			lbl.TextColor3 = col
			lbl.TextSize = 11
			lbl.TextXAlignment = Enum.TextXAlignment.Center
			lbl.Parent = statBar
		end
		makeStatCell("COCHES",   tostring(totalCars),              C_ORANGE, 0)
		makeStatCell("MUROS",    tostring(totalWalls),             C_GRAY,   0.33)
		makeStatCell("TOTAL",    tostring(#SPA_Crash.log),         C_WHITE,  0.66)

		-- Separador header
		local sepH = Instance.new("Frame"); sepH.Size=UDim2.new(1,0,0,22); sepH.BackgroundColor3=Color3.fromRGB(100,40,0)
		sepH.BorderSizePixel=0; sepH.LayoutOrder=1; sepH.Parent=chScroll
		local sepLbl=Instance.new("TextLabel"); sepLbl.Size=UDim2.new(1,-12,1,0); sepLbl.Position=UDim2.new(0,10,0,0)
		sepLbl.BackgroundTransparency=1; sepLbl.Text="  HISTORIAL DE INCIDENTES"; sepLbl.Font=Enum.Font.GothamBlack
		sepLbl.TextColor3=C_ORANGE; sepLbl.TextSize=11; sepLbl.TextXAlignment=Enum.TextXAlignment.Left; sepLbl.Parent=sepH

		if #SPA_Crash.log == 0 then
			local noLbl=Instance.new("TextLabel"); noLbl.Size=UDim2.new(1,0,0,50); noLbl.BackgroundTransparency=1
			noLbl.Text="Sin incidentes registrados"; noLbl.Font=Enum.Font.GothamBold
			noLbl.TextColor3=C_GRAY; noLbl.TextSize=13; noLbl.LayoutOrder=2; noLbl.Parent=chScroll
			return
		end

		local TYPE_ICON = { ALCANCE="🚗", LATERAL="↔", ["T-BONE"]="🔄", FRONTAL="💥", MURO="🧱", CONTACTO="⚠" }

		for idx, entry in ipairs(SPA_Crash.log) do
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1,0,0, entry.wall and 56 or 72)
			card.BackgroundColor3 = idx%2==0 and C_BG2 or C_BG
			card.BackgroundTransparency = 0.15
			card.BorderSizePixel = 0
			card.LayoutOrder = idx+1
			card.Parent = chScroll

			-- Barra izquierda de severidad
			local sevBar = Instance.new("Frame"); sevBar.Size=UDim2.new(0,4,1,0)
			sevBar.BackgroundColor3=entry.sevColor; sevBar.BorderSizePixel=0; sevBar.Parent=card

			-- Hora
			local timeLbl=Instance.new("TextLabel"); timeLbl.Size=UDim2.new(0,60,0,18); timeLbl.Position=UDim2.new(0,10,0,4)
			timeLbl.BackgroundTransparency=1; timeLbl.Text=entry.time; timeLbl.Font=Enum.Font.GothamBold
			timeLbl.TextColor3=C_GRAY; timeLbl.TextSize=10; timeLbl.TextXAlignment=Enum.TextXAlignment.Left; timeLbl.Parent=card

			-- Badge tipo
			local typeBg=Instance.new("Frame"); typeBg.Size=UDim2.new(0,70,0,18); typeBg.Position=UDim2.new(0,75,0,4)
			typeBg.BackgroundColor3=entry.wall and C_BG2 or Color3.fromRGB(40,20,0); typeBg.BorderSizePixel=0; typeBg.Parent=card
			Instance.new("UICorner",typeBg).CornerRadius=UDim.new(0,4)
			local typeLbl=Instance.new("TextLabel"); typeLbl.Size=UDim2.new(1,0,1,0)
			typeLbl.BackgroundTransparency=1; typeLbl.Text=(TYPE_ICON[entry.type] or "").. " " ..entry.type
			typeLbl.Font=Enum.Font.GothamBold; typeLbl.TextColor3=entry.sevColor; typeLbl.TextSize=10; typeLbl.Parent=typeBg

			-- Badge severidad
			local sevBg=Instance.new("Frame"); sevBg.Size=UDim2.new(0,70,0,18); sevBg.Position=UDim2.new(0,150,0,4)
			sevBg.BackgroundColor3=Color3.fromRGB(8,8,12); sevBg.BorderSizePixel=0; sevBg.Parent=card
			Instance.new("UICorner",sevBg).CornerRadius=UDim.new(0,4)
			local sevLbl=Instance.new("TextLabel"); sevLbl.Size=UDim2.new(1,0,1,0)
			sevLbl.BackgroundTransparency=1; sevLbl.Text=entry.sev
			sevLbl.Font=Enum.Font.GothamBlack; sevLbl.TextColor3=entry.sevColor; sevLbl.TextSize=10; sevLbl.Parent=sevBg

			-- Δv badge
			local dvLbl=Instance.new("TextLabel"); dvLbl.Size=UDim2.new(0,60,0,18); dvLbl.Position=UDim2.new(1,-68,0,4)
			dvLbl.BackgroundTransparency=1; dvLbl.Text="Δv "..entry.delta.." s/s"
			dvLbl.Font=Enum.Font.GothamBold; dvLbl.TextColor3=C_GRAY; dvLbl.TextSize=9; dvLbl.TextXAlignment=Enum.TextXAlignment.Right; dvLbl.Parent=card

			-- Nombres
			local rowY = entry.wall and 26 or 26
			local nameA=Instance.new("TextLabel"); nameA.Size=UDim2.new(entry.wall and 0.85 or 0.42,0,0,18)
			nameA.Position=UDim2.new(0,10,0,rowY); nameA.BackgroundTransparency=1
			nameA.Text= (entry.wall and "🧱 " or "🔴 ") .. entry.nameA
			nameA.Font=Enum.Font.GothamBlack; nameA.TextColor3=C_WHITE; nameA.TextSize=12
			nameA.TextXAlignment=Enum.TextXAlignment.Left; nameA.Parent=card

			if not entry.wall then
				local vsLbl=Instance.new("TextLabel"); vsLbl.Size=UDim2.new(0.1,0,0,18)
				vsLbl.Position=UDim2.new(0.43,0,0,rowY); vsLbl.BackgroundTransparency=1
				vsLbl.Text="VS"; vsLbl.Font=Enum.Font.GothamBlack; vsLbl.TextColor3=C_RED; vsLbl.TextSize=10; vsLbl.Parent=card

				local nameB=Instance.new("TextLabel"); nameB.Size=UDim2.new(0.44,0,0,18)
				nameB.Position=UDim2.new(0.54,0,0,rowY); nameB.BackgroundTransparency=1
				nameB.Text= "🔵 " .. (entry.nameB or "?")
				nameB.Font=Enum.Font.GothamBlack; nameB.TextColor3=C_WHITE; nameB.TextSize=12
				nameB.TextXAlignment=Enum.TextXAlignment.Left; nameB.Parent=card
			end

			-- Velocidades y distancia
			local infoY = entry.wall and 44 or 50
			if not entry.wall then
				local speedLbl=Instance.new("TextLabel"); speedLbl.Size=UDim2.new(0.7,0,0,16)
				speedLbl.Position=UDim2.new(0,10,0,infoY); speedLbl.BackgroundTransparency=1
				speedLbl.Text=sformat("%s: %d km/h  |  %s: %d km/h  |  dist: %d st", entry.nameA, entry.speedA, entry.nameB or "?", entry.speedB, entry.dist)
				speedLbl.Font=Enum.Font.GothamBold; speedLbl.TextColor3=C_GRAY; speedLbl.TextSize=9
				speedLbl.TextXAlignment=Enum.TextXAlignment.Left; speedLbl.TextTruncate=Enum.TextTruncate.AtEnd; speedLbl.Parent=card
			else
				local speedLbl=Instance.new("TextLabel"); speedLbl.Size=UDim2.new(0.7,0,0,16)
				speedLbl.Position=UDim2.new(0,10,0,infoY); speedLbl.BackgroundTransparency=1
				speedLbl.Text=sformat("Velocidad: %d km/h", entry.speedA)
				speedLbl.Font=Enum.Font.GothamBold; speedLbl.TextColor3=C_GRAY; speedLbl.TextSize=9
				speedLbl.TextXAlignment=Enum.TextXAlignment.Left; speedLbl.Parent=card
			end
		end

		-- Botón limpiar historial
		local clrRow=Instance.new("Frame"); clrRow.Size=UDim2.new(1,0,0,36); clrRow.BackgroundColor3=C_BG
		clrRow.BackgroundTransparency=0.1; clrRow.BorderSizePixel=0; clrRow.LayoutOrder=999; clrRow.Parent=chScroll
		local clrBtn=Instance.new("TextButton"); clrBtn.Size=UDim2.new(1,-16,0.75,0); clrBtn.Position=UDim2.new(0,8,0.125,0)
		clrBtn.BackgroundColor3=C_DARKRED; clrBtn.Text="🗑  LIMPIAR HISTORIAL DE CHOQUES"; clrBtn.Font=Enum.Font.GothamBlack
		clrBtn.TextColor3=C_WHITE; clrBtn.TextSize=11; clrBtn.BorderSizePixel=0; clrBtn.Parent=clrRow
		Instance.new("UICorner",clrBtn).CornerRadius=UDim.new(0,3)
		clrBtn.MouseButton1Click:Connect(function()
			SPA_Crash.log = {}; rebuildChoquesUI()
		end)
	end

	SPA_Crash.rebuildFn = function()
		rebuildChoquesUI()
		-- [BUG2 FIX] Choque real también queda en SPA_Replay para Ghost 3D
		local lat = SPA_Crash.log[1]
		if lat and not lat._rpDone and _rpCapture then
			lat._rpDone = true
			local uidA, uidB, posA
			for _, pl in ipairs(Players:GetPlayers()) do
				local dn = getDisplayName(pl)
				if dn == lat.nameA then
					uidA = pl.UserId
					local char = pl.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					if hrp then posA = hrp.Position end
				end
				if lat.nameB and dn == lat.nameB then uidB = pl.UserId end
			end
			if uidA then _rpCapture(uidA, lat.nameA, uidB, lat.nameB, lat.delta, posA) end
		end
	end
	rebuildChoquesUI()
end


-- ════════════════════════════════════════════════════════════════
-- ███  SPA ANÁLISIS DE COMPORTAMIENTO (SPAV4)  ███████████████████
-- ⚠️  IMPORTANTE: No es posible detectar qué executor usa un jugador
--     desde un LocalScript de Roblox. Esto detecta COMPORTAMIENTO
--     ANÓMALO (velocidad imposible, vuelo, teletransporte) que PUEDE
--     indicar el uso de exploits, pero NO es prueba definitiva.
-- ════════════════════════════════════════════════════════════════
SPA_Analysis = {
	SPEED_ALERT   = 340,  -- studs/s sin vehículo antes de flagear (≈ 120 km/h peatón)
	TELEPORT_DIST = 220,  -- studs en 0.5s sin vehículo = posible teletransporte
	FLY_TIME      = 2.8,  -- segundos en el aire sin vehículo = posible vuelo/noclip
	data          = {},   -- [uid] = {maxSpeed, airTime, lastPos, lastPosTick, flags, anomalies, status}
	rebuildFn     = nil,
}

local function _analHasFlag(flags, f)
	for _, v in ipairs(flags) do if v == f then return true end end
	return false
end

function _setupAnalysisDetection()
	local function _initData(uid)
		if not SPA_Analysis.data[uid] then
			SPA_Analysis.data[uid] = {
				maxSpeed   = 0,
				airTime    = 0,
				lastPos    = nil,
				lastTick   = tick(),
				flags      = {},
				anomalies  = 0,
				status     = "NORMAL",
			}
		end
		return SPA_Analysis.data[uid]
	end

	-- [SDE_INFI · CAMBIO 1] Cuerpo extraído como función — fusionado en Heartbeat maestro
	_SDEI.hbAnal = function()
		local now   = tick()
		local dirty = false

		-- Construir set de UIDs activos para limpieza
		local activeUids = {}
		for _, p in ipairs(Players:GetPlayers()) do activeUids[p.UserId] = true end
		for uid in pairs(SPA_Analysis.data) do
			if not activeUids[uid] then SPA_Analysis.data[uid] = nil; dirty = true end
		end

		for _, p in ipairs(Players:GetPlayers()) do
			if p == player then continue end  -- no analizarse a uno mismo
			local uid  = p.UserId
			local char = p.Character
			if not char then continue end
			local hrp  = char:FindFirstChild("HumanoidRootPart")
			local hum  = char:FindFirstChildOfClass("Humanoid")
			if not hrp or not hum then continue end

			local d       = _initData(uid)
			local pos     = hrp.Position
			local speed   = hrp.AssemblyLinearVelocity.Magnitude
			local seat    = hum.SeatPart
			local inVeh   = seat and seat:IsA("VehicleSeat") and seat.Occupant == hum

			-- ── Velocidad máxima vista ──────────────────────────────
			if speed > d.maxSpeed then d.maxSpeed = speed; dirty = true end

			if not inVeh then
				-- ── Flag: velocidad anómala sin vehículo ─────────────
				if speed > SPA_Analysis.SPEED_ALERT then
					if not _analHasFlag(d.flags, "VELOCIDAD") then
						table.insert(d.flags, "VELOCIDAD"); d.anomalies += 1; dirty = true
					end
				end

				-- ── Flag: teletransporte (salto brusco de posición) ──
				if d.lastPos then
					local dist    = (pos - d.lastPos).Magnitude
					local elapsed = now - d.lastTick
					if dist > SPA_Analysis.TELEPORT_DIST and elapsed <= 0.6 then
						if not _analHasFlag(d.flags, "TELEPORT") then
							table.insert(d.flags, "TELEPORT"); d.anomalies += 1; dirty = true
						end
					end
				end

				-- ── Flag: vuelo / noclip (en el aire sin vehículo) ───
				if hum.FloorMaterial == Enum.Material.Air then
					d.airTime += 0.5
				else
					d.airTime = 0
				end
				if d.airTime >= SPA_Analysis.FLY_TIME then
					if not _analHasFlag(d.flags, "VUELO") then
						table.insert(d.flags, "VUELO"); d.anomalies += 1; dirty = true
					end
				end
			else
				d.airTime = 0
			end

			d.lastPos  = pos
			d.lastTick = now

			-- ── Estado global del jugador ─────────────────────────
			local prev = d.status
			if     d.anomalies == 0 then d.status = "NORMAL"
			elseif d.anomalies <= 2 then d.status = "SOSPECHOSO"
			else                         d.status = "ALERTA" end
			if d.status ~= prev then dirty = true end
		end

		if dirty and SPA_Analysis.rebuildFn then SPA_Analysis.rebuildFn() end
	end

	-- ── UI de la pestaña ANÁLISIS ─────────────────────────────────
	local analFrame = tabFrames["ANÁLISIS"]
	if not analFrame then return end

	local analScroll = Instance.new("ScrollingFrame")
	analScroll.Size                 = UDim2.new(1, 0, 1, 0)
	analScroll.BackgroundColor3     = C_BG
	analScroll.BorderSizePixel      = 0
	analScroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
	analScroll.ScrollingDirection   = Enum.ScrollingDirection.Y
	analScroll.ScrollBarThickness   = 10
	analScroll.ScrollBarImageColor3 = C_ORANGE
	analScroll.ElasticBehavior      = Enum.ElasticBehavior.Always
	analScroll.Parent               = analFrame

	local analLayout = Instance.new("UIListLayout")
	analLayout.Padding   = UDim.new(0, 2)
	analLayout.SortOrder = Enum.SortOrder.LayoutOrder
	analLayout.Parent    = analScroll
	local function _syncAnal()
		analScroll.CanvasSize = UDim2.new(0, 0, 0, analLayout.AbsoluteContentSize.Y + 24)
	end
	analLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(_syncAnal)
	task.defer(_syncAnal)


	local function rebuildAnalUI()
		-- Limpiar solo las tarjetas de replay y el texto de estado,
		-- dejando la instrucción fija (se recrea a continuación).
		for _, c in ipairs(analScroll:GetChildren()) do
			if not c:IsA("UIListLayout") then c:Destroy() end
		end

		-- ── Texto de instrucción: siempre visible en la parte superior ──
		local infoF = Instance.new("Frame")
		infoF.Size = UDim2.new(1, 0, 0, 46)
		infoF.BackgroundColor3 = Color3.fromRGB(10, 20, 38)
		infoF.BackgroundTransparency = 0.1
		infoF.BorderSizePixel = 0
		infoF.LayoutOrder = 0
		infoF.Parent = analScroll
		Instance.new("UICorner", infoF).CornerRadius = UDim.new(0, 6)
		local infoL = Instance.new("TextLabel")
		infoL.Size = UDim2.new(1, -16, 1, 0)
		infoL.Position = UDim2.new(0, 10, 0, 0)
		infoL.BackgroundTransparency = 1
		infoL.Text = "ℹ️  Para ver los choques debes estar arriba de un vehículo."
		infoL.Font = Enum.Font.GothamBold
		infoL.TextColor3 = Color3.fromRGB(100, 160, 255)
		infoL.TextSize = 12
		infoL.TextWrapped = true
		infoL.TextXAlignment = Enum.TextXAlignment.Left
		infoL.Parent = infoF

		-- ── Sección de replays grabados ─────────────────────────────
		if SPA_Replay and SPA_Replay.rebuildFn then
			SPA_Replay.rebuildFn()
		end

		-- Si no hay tarjetas aún, mostrar mensaje de espera
		local _hasCards = false
		for _, c in ipairs(analScroll:GetChildren()) do
			if c:GetAttribute("IsReplayCard") then _hasCards = true; break end
		end
		if not _hasCards then
			local _ef = Instance.new("Frame")
			_ef.Size = UDim2.new(1, 0, 0, 50)
			_ef.BackgroundTransparency = 1
			_ef.LayoutOrder = 1
			_ef.Parent = analScroll
			local _el = Instance.new("TextLabel")
			_el.Size = UDim2.new(1, -20, 1, 0)
			_el.Position = UDim2.new(0, 10, 0, 0)
			_el.BackgroundTransparency = 1
			_el.Text = "Sin contactos grabados aún. Se registran automáticamente al detectar un choque."
			_el.Font = Enum.Font.GothamBold
			_el.TextColor3 = C_GRAY
			_el.TextSize = 11
			_el.TextWrapped = true
			_el.TextXAlignment = Enum.TextXAlignment.Left
			_el.Parent = _ef
		end
	end

	SPA_Analysis.rebuildFn = rebuildAnalUI
	rebuildAnalUI()

	-- Refresh periódico de la UI (incluso cuando no hay dirty)
	task.spawn(function()
		while analFrame.Parent do
			task.wait(2)
			if tabFrames["ANÁLISIS"] and tabFrames["ANÁLISIS"].Visible then
				rebuildAnalUI()
			end
		end
	end)
end

-- ════════════════════════════════════════════════════════════════
-- ███  SPA TELEMETRÍA · TURBO · DRIFT · SUSPENSIÓN (SPAV4)  ██████
-- Globals → 0 nuevos locals top-level.
-- ════════════════════════════════════════════════════════════════
SPA_Telemetry = {
	SUSP_LEVELS  = {{1.7,"Nivel 1"},{2.5,"Nivel 2"},{2.0,"Nivel 3"},{3.0,"Nivel 4"}},
	TURBO_LEVELS = {{11.3,"Nivel 0"},{27.9,"Nivel 1"},{44.5,"Nivel 2"},{61.1,"Nivel 3"}},
	TURBO_CYCLE  = {"Sin lím","Nivel 0","Nivel 1","Nivel 2","Nivel 3"},
	SUSP_CYCLE   = {"Sin lím","Nivel 1","Nivel 2","Nivel 3","Nivel 4"},
	TURBO_IDX    = {["Nivel 0"]=1,["Nivel 1"]=2,["Nivel 2"]=3,["Nivel 3"]=4},
	SUSP_IDX     = {["Nivel 1"]=1,["Nivel 2"]=2,["Nivel 3"]=3,["Nivel 4"]=4},
	alerts       = {},
}

function _telGetRootModel(seat)
	if not seat then return nil end
	local cur = seat.Parent
	while cur and cur:IsA("Model") do
		local par = cur.Parent
		if not par or not par:IsA("Model") then return cur end
		cur = par
	end
	return cur
end

function _telFormatDrift(v)
	if not v then return "N/A" end
	local s = mfloor(v * 10 + 0.5) / 10
	if s <= 0 then return "0" end
	return sformat("%.1f", s)
end

function _telGetTurbo(seat)
	local occ = seat and seat.Occupant
	local uid = occ and occ.Parent and occ.Parent.UserId
	if uid then
		local c = _telCache[uid]
		if c and c.seat == seat and c.turbo ~= nil and (c.t + _TEL_TTL) > tick() then return c.turbo end
	end
	local function ext(v)
		local n
		if v:IsA("NumberValue") or v:IsA("IntValue") then n = v.Value
		elseif v:IsA("StringValue") then n = tonumber(v.Value) end
		if n then
			for _, e in ipairs(SPA_Telemetry.TURBO_LEVELS) do
				if mabs(n - e[1]) <= 3 then return e[2] end
			end
		end
	end
	local result
	local root = _telGetRootModel(seat)
	if root then
		for _, v in ipairs(root:GetDescendants()) do
			if v.Name:lower() == "turbo" then local r = ext(v); if r then result = r; break end end
		end
	end
	if not result then
		for _, v in ipairs(seat:GetChildren()) do
			if v.Name:lower() == "turbo" then local r = ext(v); if r then result = r; break end end
		end
	end
	result = result or "N/A"
	if uid then
		if not _telCache[uid] then _telCache[uid] = {} end
		local c = _telCache[uid]; c.seat = seat; c.turbo = result; c.t = tick()
	end
	return result
end

function _telGetDrift(seat)
	local occ = seat and seat.Occupant
	local uid = occ and occ.Parent and occ.Parent.UserId
	if uid then
		local c = _telCache[uid]
		if c and c.seat == seat and c.drift ~= nil and (c.t + _TEL_TTL) > tick() then return c.drift end
	end
	local root = _telGetRootModel(seat)
	local result
	if not root then result = "N/A"
	else
		local best, found = math.huge, false
		for _, part in ipairs(root:GetDescendants()) do
			if part:IsA("BasePart") and part.Name:lower():find("physicalwheel") then
				local ok, cpp = pcall(function() return part.CustomPhysicalProperties end)
				if ok and cpp then
					local ok2, f = pcall(function() return cpp.Friction end)
					if ok2 then found = true; if f < best then best = f end end
				end
			end
		end
		result = found and _telFormatDrift(best) or "N/A"
	end
	if uid then
		if not _telCache[uid] then _telCache[uid] = {} end
		local c = _telCache[uid]; c.seat = seat; c.drift = result; c.t = tick()
	end
	return result
end

function _telGetSusp(seat)
	local occ = seat and seat.Occupant
	local uid = occ and occ.Parent and occ.Parent.UserId
	if uid then
		local c = _telCache[uid]
		if c and c.seat == seat and c.susp ~= nil and (c.t + _TEL_TTL) > tick() then return c.susp end
	end
	local root = _telGetRootModel(seat)
	local result
	if not root then result = "N/A"
	else
		local total, count = 0, 0
		for _, child in ipairs(root:GetDescendants()) do
			if child:IsA("SpringConstraint") then
				local ok, val = pcall(function() return child.FreeLength end)
				if ok and type(val) == "number" then total += val; count += 1 end
			end
		end
		if count == 0 then result = "N/A"
		else
			local avg = total / count
			result = "N/A"
			for _, e in ipairs(SPA_Telemetry.SUSP_LEVELS) do
				if mabs(avg - e[1]) <= 0.15 then result = e[2]; break end
			end
		end
	end
	if uid then
		if not _telCache[uid] then _telCache[uid] = {} end
		local c = _telCache[uid]; c.seat = seat; c.susp = result; c.t = tick()
	end
	return result
end


-- ════════════════════════════════════════════════════════════════
-- ███  SPA TIRES — SISTEMA DE COMPUESTOS DE NEUMÁTICOS (SPAV4)  ██
-- Detecta el compuesto activo leyendo TextureID de piezas
-- "physicalwheel"/"wheel" en el modelo raíz del vehículo.
-- Solo reconoce los 6 IDs configurados; cualquier otro = ignora.
-- ════════════════════════════════════════════════════════════════
SPA_Tires = {
	COMPOUNDS = {
		["11262113208"] = { name = "BLANDA",      icon = "🔴", color = Color3.fromRGB(230, 30,  30)  },
		["11262228611"] = { name = "FULL WET",     icon = "🔵", color = Color3.fromRGB(10,  100, 255) },
		["11262205570"] = { name = "SUPER BLANDA", icon = "🟣", color = Color3.fromRGB(191, 90,  242) },
		["11262199449"] = { name = "INTERMEDIA",   icon = "🟢", color = Color3.fromRGB(48,  209, 88)  },
		["11262217221"] = { name = "MEDIA",        icon = "🟡", color = Color3.fromRGB(255, 214, 10)  },
		["4504219366"]  = { name = "DURA",         icon = "⚪", color = Color3.fromRGB(210, 210, 215) },
	},
	current   = {},   -- [uid] = { name, icon, color }
	log       = {},   -- historial de cambios (más reciente primero)
	MAX_LOG   = 80,
	rebuildFn = nil,
}

function _tirGetCompound(seat)
	local root = _telGetRootModel(seat)
	if not root then return nil end
	for _, part in ipairs(root:GetDescendants()) do
		if part:IsA("BasePart") then
			local nm = part.Name:lower()
			if nm:find("physicalwheel") or nm:find("wheel") then
				-- MeshPart con TextureID
				if part:IsA("MeshPart") and part.TextureID and part.TextureID ~= "" then
					local id = part.TextureID:match("%d+")
					if id and SPA_Tires.COMPOUNDS[id] then return SPA_Tires.COMPOUNDS[id] end
				end
				-- Decal / Texture hijo
				for _, child in ipairs(part:GetChildren()) do
					if (child:IsA("Decal") or child:IsA("Texture")) and child.Texture and child.Texture ~= "" then
						local id = child.Texture:match("%d+")
						if id and SPA_Tires.COMPOUNDS[id] then return SPA_Tires.COMPOUNDS[id] end
					end
				end
			end
		end
	end
	return nil
end

function _tirLogChange(p, oldCpd, newCpd, inPit)
	local uid  = p.UserId
	local lap  = (lapData[uid] and lapData[uid].lapsMade) or 0
	table.insert(SPA_Tires.log, 1, {
		time     = os.date("%H:%M:%S"),
		name     = getDisplayName(p),
		uid      = uid,
		oldName  = oldCpd and oldCpd.name or "—",
		oldIcon  = oldCpd and oldCpd.icon or "❓",
		oldColor = oldCpd and oldCpd.color or C_GRAY,
		newName  = newCpd.name,
		newIcon  = newCpd.icon,
		newColor = newCpd.color,
		lap      = lap,
		inPit    = inPit,
	})
	if #SPA_Tires.log > SPA_Tires.MAX_LOG then table.remove(SPA_Tires.log) end
	local locStr = inPit and "PIT" or "PISTA"
	showNotification(newCpd.icon .. "  " .. getDisplayName(p) .. "  →  " .. newCpd.name .. "  [" .. locStr .. "]", newCpd.color, newCpd.icon, 164)
	if SPA_Tires.rebuildFn then SPA_Tires.rebuildFn() end
end

-- ════════════════════════════════════════════════════════════════
-- ███  SPA REPLAY — Proximidad 35 st + Ring Buffer + Replay 2D  ██
-- Cada jugador tiene un radio invisible de 35 studs.
-- Si otro jugador entra y hay Δv ≥ 8 st/s se guarda el buffer
-- de los últimos 2 s → se puede ver la trayectoria en ANÁLISIS.
-- ════════════════════════════════════════════════════════════════
SPA_Replay = {
	RADIUS     = 35,    -- radio de monitoreo por jugador (studs)
	BUF_SEC    = 8.0,   -- segundos de historia en el ring buffer
	BUF_HZ     = 30,    -- muestras/segundo a 30 hz → trayectoria suave y exacta
	MIN_DV     = 8,     -- Δv mínimo para capturar (capta rozones)
	COOLDOWN   = 3,     -- segundos entre capturas del mismo par
	MAX_EVENTS = 15,    -- eventos máximos guardados en ANÁLISIS
	buffers    = {},    -- [uid] → tabla de muestras {pos,vel,t}
	pairCD     = {},    -- ["uidA_uidB"] = tick() última captura
	events     = {},    -- lista de eventos capturados
	rebuildFn  = nil,
}

-- Empuja una muestra al buffer del jugador (tabla simple con límite)
function _rpBufPush(uid, pos, vel)
	-- [SDE_INFI · CAMBIO 3] Ring buffer pre-allocado — elimina table.insert/remove cada frame
	local maxN = math.ceil(SPA_Replay.BUF_SEC * SPA_Replay.BUF_HZ)
	local b = SPA_Replay.buffers[uid]
	if not b then
		b = { data = table.create(maxN), head = 0, size = 0 }
		SPA_Replay.buffers[uid] = b
	end
	b.head = (b.head % maxN) + 1
	if b.size < maxN then b.size += 1 end
	local slot = b.data[b.head]
	if slot then
		slot.pos = pos; slot.vel = vel; slot.t = tick()   -- reutiliza tabla existente
	else
		b.data[b.head] = { pos = pos, vel = vel, t = tick() }   -- solo crea en los primeros maxN frames
	end
end

-- Devuelve copia del buffer actual (orden cronológico) — compatible con ring buffer
function _rpBufSnap(uid)
	local b = SPA_Replay.buffers[uid]
	if not b or b.size == 0 then return {} end
	-- [SDE_INFI · CAMBIO 3] Reconstruir orden cronológico desde el ring buffer
	local maxN = math.ceil(SPA_Replay.BUF_SEC * SPA_Replay.BUF_HZ)
	local snap  = {}
	-- oldest index = head - size + 1 (mod maxN, 1-based)
	for i = 1, b.size do
		local idx = ((b.head - b.size + i - 1) % maxN) + 1
		local s   = b.data[idx]
		if s then snap[i] = { pos = s.pos, vel = s.vel, t = s.t } end
	end
	return snap
end

-- Captura un evento de contacto y lo guarda en events
function _rpCapture(uidA, nameA, uidB, nameB, dv, posImp)
	local now = tick()
	local key = uidA < uidB and (uidA .. "_" .. uidB) or (uidB .. "_" .. uidA)
	if SPA_Replay.pairCD[key] and now - SPA_Replay.pairCD[key] < SPA_Replay.COOLDOWN then return end
	SPA_Replay.pairCD[key] = now
	local ev = {
		time      = os.date("%H:%M:%S"),
		nameA     = nameA,
		nameB     = nameB,
		uidA      = uidA,
		uidB      = uidB,
		dv        = mfloor(dv + 0.5),
		posImpact = posImp,
		snapA     = _rpBufSnap(uidA),
		snapB     = uidB and _rpBufSnap(uidB) or {},
	}
	table.insert(SPA_Replay.events, 1, ev)
	if #SPA_Replay.events > SPA_Replay.MAX_EVENTS then table.remove(SPA_Replay.events) end
	if SPA_Replay.rebuildFn then SPA_Replay.rebuildFn() end
end


-- Clona el modelo 3D del coche de un jugador para el replay 3D
-- Mismo patrón que Curve Tracker: Clone + deshabilitar física + semitransparente
function _rpCloneVehicle(p)
	local inV, seat = _crashInVehicle(p)
	if not inV or not seat then return nil, nil end
	local root = _telGetRootModel(seat)
	if not root then return nil, nil end
	local ok, clone = pcall(function() return root:Clone() end)
	if not ok or not clone then return nil, nil end
	-- Eliminar scripts y humanoides (igual que Curve Tracker)
	for _, obj in ipairs(clone:GetDescendants()) do
		if obj:IsA("BaseScript") or obj:IsA("ModuleScript") then obj:Destroy()
		elseif obj:IsA("Humanoid") then obj:Destroy() end
	end
	-- Preparar partes: ancladas, sin colisión, semitransparentes
	local parts = {}
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false; part.Anchored = true; part.Massless = true
			part.Transparency = mmax(part.Transparency, 0.45)
			if part:IsA("VehicleSeat") then
				pcall(function() part.Disabled=true; part.MaxSpeed=0; part.Torque=0 end)
			end
			parts[#parts + 1] = part
		end
	end
	clone.Name = "SPA_Ghost_" .. p.UserId
	return clone, parts
end

-- Ejecuta el replay 3D en el Workspace usando los clones
function _rpPlay3D(ev, cloneA, partsA, cloneB, partsB)
	-- ── Construir timeline a partir de un snap ───────────────────
	-- Cada entrada: { pos, vel, t }  (t relativo al inicio del snap)
	local function mkTL(snap)
		if not snap or #snap == 0 then return {} end
		local tl, t0 = {}, snap[1].t or 0
		for _, s in ipairs(snap) do
			tl[#tl+1] = {
				pos = s.pos,
				vel = s.vel or Vector3.zero,
				t   = math.max(0, (s.t or 0) - t0),
			}
		end
		return tl
	end

	-- ── Interpolación hermite cúbica entre dos muestras ──────────
	-- Usa las velocidades reales grabadas → curvas suaves y exactas
	-- incluso con pocos puntos.
	local function hermite(p0, v0, p1, v1, alpha)
		local a = alpha
		local b = 1 - a
		-- Coeficientes Hermite estándar
		local h00 = (1 + 2*a) * b * b
		local h10 = a * b * b
		local h01 = a * a * (3 - 2*a)
		local h11 = a * a * (a - 1)
		return h00*p0 + h10*v0 + h01*p1 + h11*v1
	end

	-- ── Posición + velocidad interpoladas en tiempo t ────────────
	local function sampleAt(tl, t)
		if #tl == 0 then return nil, nil end
		if t <= 0 or #tl == 1 then return tl[1].pos, tl[1].vel end
		if t >= tl[#tl].t     then return tl[#tl].pos, tl[#tl].vel end
		for i = 1, #tl - 1 do
			local a, b = tl[i], tl[i+1]
			if a.t <= t and b.t > t then
				local d = b.t - a.t
				if d < 0.001 then return a.pos, a.vel end
				local alpha = (t - a.t) / d
				-- Escalar velocidades al intervalo de tiempo
				local v0 = a.vel * d
				local v1 = b.vel * d
				local pos = hermite(a.pos, v0, b.pos, v1, alpha)
				local vel = a.vel:Lerp(b.vel, alpha)
				return pos, vel
			end
		end
		return tl[#tl].pos, tl[#tl].vel
	end

	local tlA, tlB = mkTL(ev.snapA), mkTL(ev.snapB)

	-- ── Duración total ────────────────────────────────────────────
	local dur = math.max(
		tlA[#tlA] and tlA[#tlA].t or 0,
		tlB[#tlB] and tlB[#tlB].t or 0
	)
	if dur < 0.05 then
		dur = math.max(#(ev.snapA or {}), #(ev.snapB or {})) / SPA_Replay.BUF_HZ
	end

	-- ── Mover ghost usando PivotTo (Model) o CFrame (BasePart) ───
	local function moveCl(cl, tl, t)
		if not cl or not cl.Parent then return end
		local pos, vel = sampleAt(tl, t)
		if not pos then return end
		-- Dirección: usar velocidad real si tiene magnitud suficiente,
		-- si no mirar al siguiente punto muestreado (0.033s adelante)
		local dir
		if vel and vel.Magnitude > 0.5 then
			dir = vel.Unit
		else
			local nxtPos = sampleAt(tl, t + 0.033)
			if nxtPos and (nxtPos - pos).Magnitude > 0.01 then
				dir = (nxtPos - pos).Unit
			else
				dir = Vector3.new(0, 0, 1)
			end
		end
		-- Orientación: mantener el coche horizontal (Y=0 en dir)
		local flatDir = Vector3.new(dir.X, 0, dir.Z)
		if flatDir.Magnitude < 0.01 then flatDir = Vector3.new(0, 0, 1) end
		local cf = CFrame.lookAt(pos, pos + flatDir)
		if cl:IsA("Model") then
			pcall(function() cl:PivotTo(cf) end)
		elseif cl:IsA("BasePart") then
			pcall(function() cl.CFrame = cf end)
		end
	end

	-- ── Parte de referencia para la cámara ───────────────────────
	local function getFollowPart(cl)
		if not cl or not cl.Parent then return nil end
		if cl:IsA("Model") then
			return cl.PrimaryPart
				or cl:FindFirstChild("Body") or cl:FindFirstChild("Chassis")
				or cl:FindFirstChild("Main") or cl:FindFirstChild("Base")
				or cl:FindFirstChildWhichIsA("BasePart", true)
		elseif cl:IsA("BasePart") then
			return cl
		end
		return nil
	end

	-- ── Reproducción ─────────────────────────────────────────────
	local origCT  = Camera.CameraType
	local camVel  = Vector3.zero          -- velocidad de la cámara para smooth follow
	Camera.CameraType = Enum.CameraType.Scriptable

	-- Poner la cámara en la posición inicial del choque de inmediato
	local startPosA = tlA[#tlA] and tlA[#tlA].pos   -- última muestra = punto de impacto
	local startPosB = tlB[#tlB] and tlB[#tlB].pos
	local initPos   = startPosA or startPosB
	if initPos then
		Camera.CFrame = CFrame.new(initPos + Vector3.new(0, 12, 22), initPos)
	end

	local t0rs = tick()
	local lastCamPos = Camera.CFrame.Position
	local _rc
	_rc = RunService.RenderStepped:Connect(function(dt)
		local t = tick() - t0rs
		moveCl(cloneA, tlA, t)
		moveCl(cloneB, tlB, t)

		-- Cámara: spring suave hacia el ghost más relevante
		local fol = getFollowPart(cloneA) or getFollowPart(cloneB)
		if fol and fol.Parent then
			-- Punto objetivo: detrás y arriba del ghost
			local target = fol.CFrame * CFrame.new(0, 8, 22)
			local targetPos = target.Position
			-- Spring damper: suaviza el movimiento de la cámara
			local diff     = targetPos - lastCamPos
			camVel         = camVel * 0.72 + diff * (1 - 0.72)
			local newPos   = lastCamPos + camVel
			lastCamPos     = newPos
			Camera.CFrame  = CFrame.lookAt(newPos, fol.Position + Vector3.new(0, 1, 0))
		end

		-- Fin del replay
		if t > dur + 1.0 then
			_rc:Disconnect()
			Camera.CameraType = origCT
			if origCT == Enum.CameraType.Custom then
				local mc = player.Character
				if mc then
					local mh = mc:FindFirstChildOfClass("Humanoid")
					if mh then Camera.CameraSubject = mh end
				end
			end
			task.delay(0.5, function()
				if cloneA and cloneA.Parent then cloneA:Destroy() end
				if cloneB and cloneB.Parent then cloneB:Destroy() end
			end)
		end
	end)
end

function _setupReplayDetection()

	-- ── 1) Ring buffer: muestrear todos los jugadores a BUF_HZ ───
	-- [SDE_INFI · CAMBIO 1] _hbBuf — buffer de posiciones (≈30 Hz)
	_SDEI.hbBuf = function()
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			if not char then continue end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then continue end
			-- Preferir posición del seat si está en vehículo
			local hum = char:FindFirstChildOfClass("Humanoid")
			local seat = hum and hum.SeatPart
			local pos = (seat and seat:IsA("VehicleSeat") and seat.Occupant == hum)
				and seat.Position
				or hrp.Position
			local vel = (seat and seat:IsA("VehicleSeat") and seat.Occupant == hum)
				and seat.AssemblyLinearVelocity
				or hrp.AssemblyLinearVelocity
			_rpBufPush(p.UserId, pos, vel)
		end
	end

	-- [SDE_INFI · CAMBIO 1] upvalue para _prevV (era local del Connect original)
	local _prevV = {}
	-- _hbPrx — proximidad + pequeño-Δv (0.1 s)
	_SDEI.hbPrx = function()
		local allPl = Players:GetPlayers()
		local curV, curP, uid2P = {}, {}, {}
		for _, p in ipairs(allPl) do
			local uid = p.UserId
			uid2P[uid] = p
			local inV, seat = _crashInVehicle(p)
			if not inV then continue end
			local char = p.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then continue end
			curV[uid] = seat.AssemblyLinearVelocity
			curP[uid] = hrp.Position
		end
		for uidA, vA in pairs(curV) do
			local prev = _prevV[uidA]
			if not prev then continue end
			local dvA = (vA - prev).Magnitude
			if dvA < SPA_Replay.MIN_DV then continue end
			local pA = curP[uidA]
			if not pA then continue end
			for uidB, pB in pairs(curP) do
				if uidB == uidA then continue end
				if (pA - pB).Magnitude <= SPA_Replay.RADIUS then
					local pa = uid2P[uidA]; local pb = uid2P[uidB]
					if pa and pb then
						_rpCapture(uidA, getDisplayName(pa), uidB, getDisplayName(pb), dvA, pA)
					end
				end
			end
		end
		_prevV = curV
		-- [FIX] NO borrar buffers al salir — los snapshots ya están capturados
		-- y si borramos los buffers los eventos grabados pueden quedar buggeados
	end

	-- ── 3) UI en pestaña ANÁLISIS ─────────────────────────────────
	local analFrame = tabFrames["ANÁLISIS"]
	if not analFrame then return end
	local analScroll = analFrame:FindFirstChildOfClass("ScrollingFrame")
	if not analScroll then return end

	-- Canvas 2D: dibuja trayectorias top-down con Frames
	local function renderCanvas(canvas, ev, animated)
		for _, c in ipairs(canvas:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
		end
		local cW, cH = 154, 154
		local allP = {}
		for _, s in ipairs(ev.snapA or {}) do allP[#allP + 1] = s.pos end
		for _, s in ipairs(ev.snapB or {}) do allP[#allP + 1] = s.pos end
		if ev.posImpact then allP[#allP + 1] = ev.posImpact end
		if #allP < 1 then
			local nl = Instance.new("TextLabel"); nl.Size = UDim2.new(1,0,1,0)
			nl.BackgroundTransparency = 1; nl.Text = "Sin datos"
			nl.Font = Enum.Font.GothamBold; nl.TextColor3 = C_GRAY
			nl.TextSize = 11; nl.Parent = canvas; return
		end
		local mnX, mxX, mnZ, mxZ = allP[1].X, allP[1].X, allP[1].Z, allP[1].Z
		for _, p in ipairs(allP) do
			if p.X < mnX then mnX = p.X end; if p.X > mxX then mxX = p.X end
			if p.Z < mnZ then mnZ = p.Z end; if p.Z > mxZ then mxZ = p.Z end
		end
		local pad = mmax(6, mmax(mxX - mnX, mxZ - mnZ) * 0.15)
		mnX -= pad; mxX += pad; mnZ -= pad; mxZ += pad
		local rX = mmax(1, mxX - mnX); local rZ = mmax(1, mxZ - mnZ)
		local function pt(pos)
			return UDim2.new(0, mfloor((pos.X - mnX) / rX * (cW - 8) + 4 + 0.5),
			                    0, mfloor((pos.Z - mnZ) / rZ * (cH - 8) + 4 + 0.5))
		end
		local function mkD(pos, col, sz, zi, al)
			local d = Instance.new("Frame"); d.Size = UDim2.new(0, sz, 0, sz)
			d.Position = pt(pos); d.AnchorPoint = Vector2.new(0.5, 0.5)
			d.BackgroundColor3 = col; d.BackgroundTransparency = al or 0.1
			d.BorderSizePixel = 0; d.ZIndex = zi or 2; d.Parent = canvas
			Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0); return d
		end
		local function drawSnap(snap, col)
			if not snap then return end
			local n = #snap
			for i, s in ipairs(snap) do
				local al = 0.7-(i/n)*0.5
				mkD(s.pos, col, i==n and 9 or 5, 3, al)
				if i<n then
					local p1,p2 = pt(s.pos), pt(snap[i+1].pos)
					local dx,dy = p2.X.Offset-p1.X.Offset, p2.Y.Offset-p1.Y.Offset
					local ln = math.sqrt(dx*dx+dy*dy)
					if ln>0.5 then
						local seg=Instance.new("Frame")
						seg.Size=UDim2.new(0,ln,0,2)
						seg.Position=UDim2.new(0,p1.X.Offset,0,p1.Y.Offset)
						seg.AnchorPoint=Vector2.new(0,0.5)
						seg.BackgroundColor3=col; seg.BackgroundTransparency=al+0.2
						seg.BorderSizePixel=0; seg.Rotation=math.deg(math.atan(dy,dx))
						seg.ZIndex=1; seg.Parent=canvas
					end
				end
			end
		end
		if not animated then
			drawSnap(ev.snapA, C_BLUE); drawSnap(ev.snapB, C_ORANGE)
			if ev.posImpact then mkD(ev.posImpact, C_RED, 11, 3) end
		else
			local sA, sB = ev.snapA or {}, ev.snapB or {}
			local maxL = mmax(#sA, #sB)
			local function realDt(s)
				if #s>=2 and s[1].t and s[#s].t then
					return math.max(0.04,(s[#s].t-s[1].t)/math.max(1,#s-1))
				end; return 1/SPA_Replay.BUF_HZ
			end
			local dt = math.min(realDt(sA),realDt(sB))
			local function mkLine(p1,p2,col)
				local dx,dy=p2.X.Offset-p1.X.Offset,p2.Y.Offset-p1.Y.Offset
				local ln=math.sqrt(dx*dx+dy*dy); if ln<0.5 then return end
				local sg=Instance.new("Frame"); sg.Size=UDim2.new(0,ln,0,2)
				sg.Position=UDim2.new(0,p1.X.Offset,0,p1.Y.Offset)
				sg.AnchorPoint=Vector2.new(0,0.5); sg.BackgroundColor3=col
				sg.BackgroundTransparency=0.3; sg.BorderSizePixel=0
				sg.Rotation=math.deg(math.atan(dy,dx)); sg.ZIndex=1; sg.Parent=canvas
			end
			task.spawn(function()
				for i=1,maxL do
					if sA[i] then
						mkD(sA[i].pos,C_BLUE,i==#sA and 9 or 5,3,0.1)
						if i<#sA then mkLine(pt(sA[i].pos),pt(sA[i+1].pos),C_BLUE) end
					end
					if sB[i] then
						mkD(sB[i].pos,C_ORANGE,i==#sB and 9 or 5,3,0.1)
						if i<#sB then mkLine(pt(sB[i].pos),pt(sB[i+1].pos),C_ORANGE) end
					end
					task.wait(dt)
				end
				if ev.posImpact then mkD(ev.posImpact,C_RED,16,3) end
			end)
		end
	end

	-- Construye una tarjeta de evento
	local function buildCard(ev, order)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 222)
		card.BackgroundColor3 = C_BG2; card.BackgroundTransparency = 0.1
		card.BorderSizePixel = 0; card:SetAttribute("IsReplayCard", true)
		card.LayoutOrder = order

		local bar = Instance.new("Frame"); bar.Size = UDim2.new(0, 4, 1, 0)
		bar.BackgroundColor3 = C_BLUE; bar.BorderSizePixel = 0; bar.Parent = card

		-- Header
		local hdr = Instance.new("Frame"); hdr.Size = UDim2.new(1, 0, 0, 28)
		hdr.BackgroundColor3 = Color3.fromRGB(0, 18, 46); hdr.BorderSizePixel = 0; hdr.Parent = card
		local tLbl = Instance.new("TextLabel"); tLbl.Size = UDim2.new(0, 54, 1, 0)
		tLbl.Position = UDim2.new(0, 8, 0, 0); tLbl.BackgroundTransparency = 1
		tLbl.Text = ev.time; tLbl.Font = Enum.Font.GothamBold
		tLbl.TextColor3 = C_GRAY; tLbl.TextSize = 10
		tLbl.TextXAlignment = Enum.TextXAlignment.Left; tLbl.Parent = hdr
		local nLbl = Instance.new("TextLabel"); nLbl.Size = UDim2.new(0.55, 0, 1, 0)
		nLbl.Position = UDim2.new(0, 64, 0, 0); nLbl.BackgroundTransparency = 1
		nLbl.Text = (ev.nameA or "?") .. (ev.nameB and ("  ↔  " .. ev.nameB) or "  ↔  MURO")
		nLbl.Font = Enum.Font.GothamBold; nLbl.TextColor3 = C_WHITE; nLbl.TextSize = 10
		nLbl.TextXAlignment = Enum.TextXAlignment.Left
		nLbl.TextTruncate = Enum.TextTruncate.AtEnd; nLbl.Parent = hdr
		local dvB = Instance.new("TextLabel"); dvB.Size = UDim2.new(0, 52, 0, 18)
		dvB.Position = UDim2.new(1, -58, 0.5, -9)
		dvB.BackgroundColor3 = Color3.fromRGB(8, 8, 12); dvB.BorderSizePixel = 0
		dvB.Text = "Δv " .. ev.dv .. " s/s"; dvB.Font = Enum.Font.GothamBold
		dvB.TextColor3 = C_ORANGE; dvB.TextSize = 9; dvB.Parent = hdr
		Instance.new("UICorner", dvB).CornerRadius = UDim.new(0, 4)

		-- Canvas 2D
		local cbg = Instance.new("Frame"); cbg.Size = UDim2.new(0, 158, 0, 158)
		cbg.Position = UDim2.new(0, 6, 0, 30)
		cbg.BackgroundColor3 = Color3.fromRGB(6, 8, 14)
		cbg.BorderSizePixel = 0; cbg.ClipsDescendants = true; cbg.Parent = card
		Instance.new("UICorner", cbg).CornerRadius = UDim.new(0, 4)
		renderCanvas(cbg, ev, false)

		-- Panel derecho: leyenda + botones
		local inf = Instance.new("Frame"); inf.Size = UDim2.new(1, -170, 0, 158)
		inf.Position = UDim2.new(0, 166, 0, 30); inf.BackgroundTransparency = 1; inf.Parent = card
		local function ir(icon, txt, col, yp)
			local r = Instance.new("TextLabel"); r.Size = UDim2.new(1, -2, 0, 17)
			r.Position = UDim2.new(0, 2, 0, yp); r.BackgroundTransparency = 1
			r.Text = icon .. " " .. txt; r.Font = Enum.Font.GothamBold
			r.TextColor3 = col; r.TextSize = 10
			r.TextXAlignment = Enum.TextXAlignment.Left
			r.TextTruncate = Enum.TextTruncate.AtEnd; r.Parent = inf
		end
		ir("🔵", ev.nameA or "?",    C_BLUE,   2)
		ir("🟠", ev.nameB or "MURO", C_ORANGE, 22)
		ir("⚡", "Δv " .. ev.dv .. " st/s", C_YELLOW, 42)
		if ev.posImpact then
			ir("📍", sformat("%.0f, %.0f", ev.posImpact.X, ev.posImpact.Z), C_GRAY, 62)
		end

		local captEv, captCbg = ev, cbg
		-- ▶ ANIMAR: replay 2D en el canvas de la tarjeta
		local aBtn = Instance.new("TextButton"); aBtn.Size = UDim2.new(1, -2, 0, 24)
		aBtn.Position = UDim2.new(0, 2, 0, 88)
		aBtn.BackgroundColor3 = Color3.fromRGB(0, 28, 76)
		aBtn.Text = "▶  ANIMAR 2D"; aBtn.Font = Enum.Font.GothamBold
		aBtn.TextColor3 = C_BLUE; aBtn.TextSize = 10; aBtn.BorderSizePixel = 0; aBtn.Parent = inf
		Instance.new("UICorner", aBtn).CornerRadius = UDim.new(0, 3)
		aBtn.MouseButton1Click:Connect(function()
			aBtn.Text = "⏳ ..."; aBtn.TextColor3 = C_GRAY
			renderCanvas(captCbg, captEv, true)
			local dur = mmax(#(captEv.snapA or {}), #(captEv.snapB or {})) * 0.08 + 0.5
			task.delay(dur, function() aBtn.Text = "▶  ANIMAR 2D"; aBtn.TextColor3 = C_BLUE end)
		end)

		-- ▶ 3D: clona el modelo real del coche y lo anima en el Workspace
		local gBtn = Instance.new("TextButton"); gBtn.Size = UDim2.new(1, -2, 0, 24)
		gBtn.Position = UDim2.new(0, 2, 0, 116)
		gBtn.BackgroundColor3 = Color3.fromRGB(0, 55, 20)
		gBtn.Text = "▶  GHOST 3D"; gBtn.Font = Enum.Font.GothamBold
		gBtn.TextColor3 = C_GREEN; gBtn.TextSize = 10; gBtn.BorderSizePixel = 0; gBtn.Parent = inf
		Instance.new("UICorner", gBtn).CornerRadius = UDim.new(0, 3)
		gBtn.MouseButton1Click:Connect(function()
			gBtn.Text = "⏳ ..."; gBtn.TextColor3 = C_GRAY
			local pA, pB
			for _, pl in ipairs(Players:GetPlayers()) do
				if pl.UserId == captEv.uidA then pA = pl end
				if captEv.uidB and pl.UserId == captEv.uidB then pB = pl end
			end
			if not pA or (captEv.nameB and not pB) then
				for _, pl in ipairs(Players:GetPlayers()) do
					local dn = getDisplayName(pl)
					if not pA and dn == captEv.nameA then pA = pl end
					if not pB and captEv.nameB and dn == captEv.nameB then pB = pl end
				end
			end
			local function mkGhost(pl, col, snap)
				if pl then
					local cl = _rpCloneVehicle(pl)
					if cl then
						local pts = {}
						for _,pp in ipairs(cl:GetDescendants()) do
							if pp:IsA("BasePart") then
								if pp.Transparency < 0.9 then pp.Color = col end
								pts[#pts+1] = pp
							end
						end
						cl.Parent = Workspace
						return cl, pts
					end
				end
				if not snap or #snap == 0 then return nil, {} end
				local sp = Instance.new("Part")
				sp.Name="SPA_GhostSphere"; sp.Shape=Enum.PartType.Ball
				sp.Size=Vector3.new(6,3,10); sp.Anchored=true; sp.CanCollide=false
				sp.Material=Enum.Material.Neon; sp.Color=col; sp.Transparency=0.45
				sp.CFrame=CFrame.new(snap[1].pos); sp.Parent=Workspace
				local lt=Instance.new("PointLight"); lt.Color=col
				lt.Brightness=2; lt.Range=22; lt.Parent=sp
				return sp, {sp}
			end
			local clA, parA = mkGhost(pA, C_BLUE,   captEv.snapA)
			local clB, parB = mkGhost(pB, C_ORANGE, captEv.snapB)
			if not clA and not clB then
				gBtn.Text = "Sin datos"; gBtn.TextColor3 = C_RED
				task.delay(2, function() gBtn.Text="▶  GHOST 3D"; gBtn.TextColor3=C_GREEN end)
				return
			end
			-- _rpPlay3D maneja cámara chase y restauración
			_rpPlay3D(captEv, clA, parA or {}, clB, parB or {})
			local dur3 = mmax(#(captEv.snapA or {}), #(captEv.snapB or {})) / SPA_Replay.BUF_HZ + 2
			task.delay(dur3, function() gBtn.Text="▶  GHOST 3D"; gBtn.TextColor3=C_GREEN end)
		end)

		-- 🗑 BORRAR
		local dBtn = Instance.new("TextButton"); dBtn.Size = UDim2.new(1, -2, 0, 24)
		dBtn.Position = UDim2.new(0, 2, 0, 144)
		dBtn.BackgroundColor3 = C_DARKRED; dBtn.Text = "🗑 BORRAR"
		dBtn.Font = Enum.Font.GothamBold; dBtn.TextColor3 = C_WHITE
		dBtn.TextSize = 10; dBtn.BorderSizePixel = 0; dBtn.Parent = inf
		Instance.new("UICorner", dBtn).CornerRadius = UDim.new(0, 3)
		dBtn.MouseButton1Click:Connect(function()
			for i, e in ipairs(SPA_Replay.events) do
				if e == captEv then table.remove(SPA_Replay.events, i); break end
			end
			if SPA_Replay.rebuildFn then SPA_Replay.rebuildFn() end
		end)

		return card
	end

	-- Reconstruye la sección de replays en analScroll
	local function rebuildCards()
		for _, c in ipairs(analScroll:GetChildren()) do
			if c:GetAttribute("IsReplayCard") then c:Destroy() end
		end
		if #SPA_Replay.events == 0 then return end
		-- Header de sección
		local sh = Instance.new("Frame"); sh.Size = UDim2.new(1, 0, 0, 26)
		sh.BackgroundColor3 = Color3.fromRGB(0, 20, 52); sh.BorderSizePixel = 0
		sh.LayoutOrder = 500; sh:SetAttribute("IsReplayCard", true); sh.Parent = analScroll
		local shl = Instance.new("TextLabel"); shl.Size = UDim2.new(0.7, 0, 1, 0)
		shl.Position = UDim2.new(0, 10, 0, 0); shl.BackgroundTransparency = 1
		shl.Text = "📹  CONTACTOS GRABADOS (" .. #SPA_Replay.events .. ")"
		shl.Font = Enum.Font.GothamBlack; shl.TextColor3 = C_BLUE; shl.TextSize = 11
		shl.TextXAlignment = Enum.TextXAlignment.Left; shl.Parent = sh
		local caBtn = Instance.new("TextButton"); caBtn.Size = UDim2.new(0, 58, 0.7, 0)
		caBtn.Position = UDim2.new(1, -64, 0.15, 0); caBtn.BackgroundColor3 = C_DARKRED
		caBtn.Text = "🗑 TODO"; caBtn.Font = Enum.Font.GothamBold
		caBtn.TextColor3 = C_WHITE; caBtn.TextSize = 9; caBtn.BorderSizePixel = 0; caBtn.Parent = sh
		Instance.new("UICorner", caBtn).CornerRadius = UDim.new(0, 3)
		caBtn.MouseButton1Click:Connect(function()
			SPA_Replay.events = {}
			if SPA_Replay.rebuildFn then SPA_Replay.rebuildFn() end
		end)
		-- Tarjetas de eventos
		for i, ev in ipairs(SPA_Replay.events) do
			local c = buildCard(ev, 500 + i); c.Parent = analScroll
		end
	end

	SPA_Replay.rebuildFn = rebuildCards
end


_setupUI1()

-- ══════════════════════════════════════════════════════════════
-- ═══  _setupUI2  ══════════════════════════════════════════════
-- ══════════════════════════════════════════════════════════════
function _setupUI2()  -- [SPAV4] global: libera registros del ámbito principal

	-- ── Config helper builders ──────────────────────────────────
	local function mkConfigToggleRow(parent, labelTxt, getter, setter, order)
		local row = Instance.new("Frame")
		row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=C_BG2; row.BorderSizePixel=0; row.LayoutOrder=order; row.Parent=parent
		local lbl=Instance.new("TextLabel")
		lbl.Size=UDim2.new(0.6,0,1,0); lbl.Position=UDim2.new(0,10,0,0); lbl.BackgroundTransparency=1
		lbl.Text=labelTxt; lbl.Font=Enum.Font.GothamBold; lbl.TextColor3=C_WHITE; lbl.TextSize=12
		lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
		local btn=Instance.new("TextButton")
		btn.Size=UDim2.new(0.35,-4,0.7,0); btn.Position=UDim2.new(0.62,0,0.15,0); btn.BorderSizePixel=0
		btn.Font=Enum.Font.GothamBold; btn.TextSize=12; btn.Parent=row
		local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,3); bc.Parent=btn
		local function paint()
			local v=getter()
			btn.Text=v and "  ON  " or "  OFF  "
			btn.BackgroundColor3=v and Color3.fromRGB(0,120,50) or Color3.fromRGB(80,20,20)
			btn.TextColor3=v and C_GREEN or Color3.fromRGB(255,80,80)
		end
		paint()
		btn.MouseButton1Click:Connect(function() setter(not getter()); paint() end)
	end

	local function mkConfigAdjustRow(parent, labelTxt, getter, setter, step, minV, maxV, onChange, order)
		local row=Instance.new("Frame")
		row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=C_BG2; row.BorderSizePixel=0; row.LayoutOrder=order; row.Parent=parent
		local lbl=Instance.new("TextLabel")
		lbl.Size=UDim2.new(0.5,0,1,0); lbl.Position=UDim2.new(0,10,0,0); lbl.BackgroundTransparency=1
		lbl.Text=labelTxt; lbl.Font=Enum.Font.GothamBold; lbl.TextColor3=C_WHITE; lbl.TextSize=12
		lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
		local valLbl=Instance.new("TextLabel")
		valLbl.Size=UDim2.new(0.15,0,1,0); valLbl.Position=UDim2.new(0.5,0,0,0); valLbl.BackgroundTransparency=1
		valLbl.Text=tostring(getter()); valLbl.Font=Enum.Font.GothamBold; valLbl.TextColor3=C_YELLOW; valLbl.TextSize=13; valLbl.Parent=row
		local minus=Instance.new("TextButton")
		minus.Size=UDim2.new(0.15,0,0.7,0); minus.Position=UDim2.new(0.65,0,0.15,0)
		minus.BackgroundColor3=Color3.fromRGB(50,50,60); minus.Text="−"; minus.Font=Enum.Font.GothamBold
		minus.TextColor3=C_WHITE; minus.TextSize=16; minus.BorderSizePixel=0; minus.Parent=row
		local mc=Instance.new("UICorner"); mc.CornerRadius=UDim.new(0,3); mc.Parent=minus
		local plus=Instance.new("TextButton")
		plus.Size=UDim2.new(0.15,0,0.7,0); plus.Position=UDim2.new(0.82,0,0.15,0)
		plus.BackgroundColor3=Color3.fromRGB(50,50,60); plus.Text="+"; plus.Font=Enum.Font.GothamBold
		plus.TextColor3=C_WHITE; plus.TextSize=16; plus.BorderSizePixel=0; plus.Parent=row
		local pc=Instance.new("UICorner"); pc.CornerRadius=UDim.new(0,3); pc.Parent=plus
		local function apply(v)
			setter(v); valLbl.Text=tostring(getter())
			if onChange then onChange(v) end
		end
		minus.MouseButton1Click:Connect(function() apply(mclamp(getter()-step,minV,maxV)) end)
		plus.MouseButton1Click:Connect(function() apply(mclamp(getter()+step,minV,maxV)) end)
	end

	local function mkConfigWPRow(parent, labelTxt, onWP, order)
		local row=Instance.new("Frame")
		row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=C_BG2; row.BorderSizePixel=0; row.LayoutOrder=order; row.Parent=parent
		local lbl=Instance.new("TextLabel")
		lbl.Size=UDim2.new(0.6,0,1,0); lbl.Position=UDim2.new(0,10,0,0); lbl.BackgroundTransparency=1
		lbl.Text=labelTxt; lbl.Font=Enum.Font.GothamBold; lbl.TextColor3=C_WHITE; lbl.TextSize=12
		lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
		local btn=Instance.new("TextButton")
		btn.Size=UDim2.new(0.35,-4,0.7,0); btn.Position=UDim2.new(0.62,0,0.15,0)
		btn.BackgroundColor3=Color3.fromRGB(0,80,160); btn.Text="SET WP"
		btn.Font=Enum.Font.GothamBold; btn.TextColor3=C_WHITE; btn.TextSize=11; btn.BorderSizePixel=0; btn.Parent=row
		local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,3); bc.Parent=btn
		btn.MouseButton1Click:Connect(function()
			local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then onWP(root.CFrame) end
		end)
	end

	local function mkConfigActionRow(parent, btnTxt, btnColor, onAction, order)
		local row=Instance.new("Frame")
		row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=C_BG2; row.BorderSizePixel=0; row.LayoutOrder=order; row.Parent=parent
		local btn=Instance.new("TextButton")
		btn.Size=UDim2.new(1,-16,0.75,0); btn.Position=UDim2.new(0,8,0.125,0)
		btn.BackgroundColor3=btnColor or C_RED; btn.Text=btnTxt
		btn.Font=Enum.Font.GothamBlack; btn.TextColor3=C_WHITE; btn.TextSize=12; btn.BorderSizePixel=0; btn.Parent=row
		local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,3); bc.Parent=btn
		btn.MouseButton1Click:Connect(onAction)
	end

	local function rebuildWall(wp, cf, width, height, thickness)
		if not wp then return end
		wp.CFrame = cf * CFrame.Angles(0, mrad(90), 0)
		wp.Size   = Vector3.new(width or WP_WIDTH, height or WP_HEIGHT, thickness or WP_THICKNESS)
	end

	-- ── CONFIG: Carrera ─────────────────────────────────────────
	makeSectionHeader(configScroll, "⚙  CARRERA", 1)
	mkConfigAdjustRow(configScroll, "Max Vueltas", function() return MAX_LAPS end, function(v) MAX_LAPS=v end, 1, 1, 999, function() towerHeaderText.Text = "LAP ?/"..MAX_LAPS; lapNumLabel.Text = "? / "..MAX_LAPS end, 2)
	mkConfigAdjustRow(configScroll, "Max Boxes", function() return MAX_PITS end, function(v) MAX_PITS=v end, 1, 1, 99, nil, 3)

	do
		local row=Instance.new("Frame")
		row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=C_BG2; row.BorderSizePixel=0; row.LayoutOrder=4; row.Parent=configScroll
		local lbl=Instance.new("TextLabel")
		lbl.Size=UDim2.new(0.5,0,1,0); lbl.Position=UDim2.new(0,10,0,0); lbl.BackgroundTransparency=1
		lbl.Text="Límite Vel. (km/h)"; lbl.Font=Enum.Font.GothamBold; lbl.TextColor3=C_WHITE; lbl.TextSize=12
		lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
		local box=Instance.new("TextBox")
		box.Size=UDim2.new(0.25,0,0.75,0); box.Position=UDim2.new(0.55,0,0.125,0)
		box.BackgroundColor3=Color3.fromRGB(40,40,55); box.BorderSizePixel=0
		box.Font=Enum.Font.GothamBold; box.TextColor3=C_YELLOW; box.TextSize=13
		box.Text=tostring(SPEED_LIMIT); box.ClearTextOnFocus=false; box.Parent=row
		local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,3); bc.Parent=box
		box:GetPropertyChangedSignal("Text"):Connect(function() box.Text=box.Text:gsub("%D","") end)
		box.FocusLost:Connect(function()
			local n=tonumber(box.Text)
			if not n then box.Text=tostring(SPEED_LIMIT); return end
			SPEED_LIMIT=mclamp(n,10,500); box.Text=tostring(SPEED_LIMIT)
		end)
	end

	-- ── CONFIG: Modo Clasificación ─────────────────────────────
	makeSectionHeader(configScroll, "🏆  MODO CLASIFICACIÓN", 5)
	mkConfigToggleRow(configScroll, "Activar Modo Qualy",
		function() return QUALY_MODE end,
		function(v)
			QUALY_MODE = v
			if v then
				towerHeader.BackgroundColor3 = Color3.fromRGB(80, 0, 140)
				towerHeaderText.Text = "QUALY "..QUALY_LAPS.." LAP"
			else
				towerHeader.BackgroundColor3 = towerConfig.headerColor
				towerHeaderText.Text = "LAP 0/"..MAX_LAPS
			end
		end, 6)

	mkConfigAdjustRow(configScroll, "Vueltas Qualy", function() return QUALY_LAPS end, function(v) QUALY_LAPS = v end, 1, 1, 99, nil, 7)

	mkConfigActionRow(configScroll, "↺  RESETEAR TIEMPOS QUALY", Color3.fromRGB(80,0,120), function()
		fastLapData = {}
		for _, pl in ipairs(Players:GetPlayers()) do ensurePlayerData(pl) end
		bestTimeLabel.Text = "--:--.---  |  ---"
		for uid, row in pairs(fastLapsRowCache) do
			local rightLbl = row:FindFirstChild("RightLbl")
			if rightLbl then rightLbl.Text = "NO TIME"; rightLbl.TextColor3= C_GRAY end
		end
	end, 8)

	-- ── CONFIG: Calibración ────────────────────────────────────
	makeSectionHeader(configScroll, "📡  CALIBRACIÓN", 9)
	do
		local row1=Instance.new("Frame")
		row1.Size=UDim2.new(1,0,0,34); row1.BackgroundColor3=C_BG2; row1.BorderSizePixel=0; row1.LayoutOrder=10; row1.Parent=configScroll
		local lbl1=Instance.new("TextLabel")
		lbl1.Size=UDim2.new(0.55,0,1,0); lbl1.Position=UDim2.new(0,10,0,0); lbl1.BackgroundTransparency=1
		lbl1.Text="Factor calibración"; lbl1.Font=Enum.Font.GothamBold; lbl1.TextColor3=C_WHITE; lbl1.TextSize=12
		lbl1.TextXAlignment=Enum.TextXAlignment.Left; lbl1.Parent=row1
		local box1=Instance.new("TextBox")
		box1.Size=UDim2.new(0.32,0,0.75,0); box1.Position=UDim2.new(0.56,0,0.125,0)
		box1.BackgroundColor3=Color3.fromRGB(40,40,55); box1.BorderSizePixel=0
		box1.Font=Enum.Font.GothamBold; box1.TextColor3=C_YELLOW; box1.TextSize=13
		box1.Text=tostring(CAL_FACTOR); box1.ClearTextOnFocus=false; box1.Parent=row1
		local bc1=Instance.new("UICorner"); bc1.CornerRadius=UDim.new(0,3); bc1.Parent=box1
		box1.FocusLost:Connect(function()
			local n=tonumber(box1.Text)
			if not n then box1.Text=tostring(CAL_FACTOR); return end
			n=mclamp(n,0.01,10); CAL_FACTOR=n; SPEED_CONVERSION_FACTOR=CAL_FACTOR; box1.Text=tostring(n)
		end)

		local row2=Instance.new("Frame")
		row2.Size=UDim2.new(1,0,0,34); row2.BackgroundColor3=C_BG2; row2.BorderSizePixel=0; row2.LayoutOrder=11; row2.Parent=configScroll
		local lbl2=Instance.new("TextLabel")
		lbl2.Size=UDim2.new(0.55,0,1,0); lbl2.Position=UDim2.new(0,10,0,0); lbl2.BackgroundTransparency=1
		lbl2.Text="Offset calibración"; lbl2.Font=Enum.Font.GothamBold; lbl2.TextColor3=C_WHITE; lbl2.TextSize=12
		lbl2.TextXAlignment=Enum.TextXAlignment.Left; lbl2.Parent=row2
		local box2=Instance.new("TextBox")
		box2.Size=UDim2.new(0.32,0,0.75,0); box2.Position=UDim2.new(0.56,0,0.125,0)
		box2.BackgroundColor3=Color3.fromRGB(40,40,55); box2.BorderSizePixel=0
		box2.Font=Enum.Font.GothamBold; box2.TextColor3=C_YELLOW; box2.TextSize=13
		box2.Text=tostring(CAL_OFFSET); box2.ClearTextOnFocus=false; box2.Parent=row2
		local bc2=Instance.new("UICorner"); bc2.CornerRadius=UDim.new(0,3); bc2.Parent=box2
		box2.FocusLost:Connect(function()
			local n=tonumber(box2.Text)
			if not n then box2.Text=tostring(CAL_OFFSET); return end
			CAL_OFFSET=n; box2.Text=tostring(n)
		end)
	end

	-- ── CONFIG: Detección ──────────────────────────────────────
	makeSectionHeader(configScroll, "🏁  DETECCIÓN", 20)
	mkConfigToggleRow(configScroll, "Detección Vueltas",  function() return DETECT_LAPS end,         function(v) DETECT_LAPS=v end,         21)
	mkConfigToggleRow(configScroll, "Detección Boxes",    function() return DETECT_PITS end,         function(v) DETECT_PITS=v end,         22)
	mkConfigToggleRow(configScroll, "Solo Vehículos",     function() return showOnlyVehicles end,    function(v) showOnlyVehicles=v end,    23)

	-- ── CONFIG: Waypoints ──────────────────────────────────────
	makeSectionHeader(configScroll, "📐  WAYPOINTS", 30)
	mkConfigToggleRow(configScroll, "Mostrar Waypoints", function() return WP_VISIBLE end, function(v) WP_VISIBLE = v; applyWPVisibility() end, 31)
	-- ─── TAMAÑO INDIVIDUAL POR WP (no se combinan) ─────────────────────────
	makeSectionHeader(configScroll, "📐  LAP WP (Meta/Vuelta)", 32)
	mkConfigAdjustRow(configScroll, "LAP – Ancho (studs)", function() return wpCfg.LAP.width end, function(v)
		wpCfg.LAP.width = v
		if lapWall then lapWall.Size = Vector3.new(wpCfg.LAP.width, wpCfg.LAP.height, wpCfg.LAP.thickness) end
	end, 5, 10, 1000, nil, 33)
	mkConfigAdjustRow(configScroll, "LAP – Alto (studs)", function() return wpCfg.LAP.height end, function(v)
		wpCfg.LAP.height = v
		if lapWall then lapWall.Size = Vector3.new(wpCfg.LAP.width, wpCfg.LAP.height, wpCfg.LAP.thickness) end
	end, 5, 10, 500, nil, 34)
	mkConfigAdjustRow(configScroll, "LAP – Grosor (studs)", function() return wpCfg.LAP.thickness end, function(v)
		wpCfg.LAP.thickness = v
		if lapWall then lapWall.Size = Vector3.new(wpCfg.LAP.width, wpCfg.LAP.height, wpCfg.LAP.thickness) end
	end, 1, 1, 200, nil, 35)

	makeSectionHeader(configScroll, "📐  PIT IN WP (Entrada Boxes)", 36)
	mkConfigAdjustRow(configScroll, "PIT IN – Ancho (studs)", function() return wpCfg.PIT_IN.width end, function(v)
		wpCfg.PIT_IN.width = v
		if pitInWall then pitInWall.Size = Vector3.new(wpCfg.PIT_IN.width, wpCfg.PIT_IN.height, wpCfg.PIT_IN.thickness) end
	end, 5, 10, 1000, nil, 37)
	mkConfigAdjustRow(configScroll, "PIT IN – Alto (studs)", function() return wpCfg.PIT_IN.height end, function(v)
		wpCfg.PIT_IN.height = v
		if pitInWall then pitInWall.Size = Vector3.new(wpCfg.PIT_IN.width, wpCfg.PIT_IN.height, wpCfg.PIT_IN.thickness) end
	end, 5, 10, 500, nil, 38)
	mkConfigAdjustRow(configScroll, "PIT IN – Grosor (studs)", function() return wpCfg.PIT_IN.thickness end, function(v)
		wpCfg.PIT_IN.thickness = v
		if pitInWall then pitInWall.Size = Vector3.new(wpCfg.PIT_IN.width, wpCfg.PIT_IN.height, wpCfg.PIT_IN.thickness) end
	end, 1, 1, 200, nil, 39)

	makeSectionHeader(configScroll, "📐  PIT OUT WP (Salida Boxes)", 40)
	mkConfigAdjustRow(configScroll, "PIT OUT – Ancho (studs)", function() return wpCfg.PIT_OUT.width end, function(v)
		wpCfg.PIT_OUT.width = v
		if pitOutWall then pitOutWall.Size = Vector3.new(wpCfg.PIT_OUT.width, wpCfg.PIT_OUT.height, wpCfg.PIT_OUT.thickness) end
	end, 5, 10, 1000, nil, 41)
	mkConfigAdjustRow(configScroll, "PIT OUT – Alto (studs)", function() return wpCfg.PIT_OUT.height end, function(v)
		wpCfg.PIT_OUT.height = v
		if pitOutWall then pitOutWall.Size = Vector3.new(wpCfg.PIT_OUT.width, wpCfg.PIT_OUT.height, wpCfg.PIT_OUT.thickness) end
	end, 5, 10, 500, nil, 42)
	mkConfigAdjustRow(configScroll, "PIT OUT – Grosor (studs)", function() return wpCfg.PIT_OUT.thickness end, function(v)
		wpCfg.PIT_OUT.thickness = v
		if pitOutWall then pitOutWall.Size = Vector3.new(wpCfg.PIT_OUT.width, wpCfg.PIT_OUT.height, wpCfg.PIT_OUT.thickness) end
	end, 1, 1, 200, nil, 43)
	mkConfigAdjustRow(configScroll, "Radio Checkpoint", function() return CHECKPOINT_RADIUS end, function(v) CHECKPOINT_RADIUS=v end, 10, 100, 600, function()
		lapSphere.Size       = Vector3.new(CHECKPOINT_RADIUS,CHECKPOINT_RADIUS,CHECKPOINT_RADIUS)
		pitEntrySphere.Size  = Vector3.new(CHECKPOINT_RADIUS,CHECKPOINT_RADIUS,CHECKPOINT_RADIUS)
		pitExitSphere.Size   = Vector3.new(CHECKPOINT_RADIUS,CHECKPOINT_RADIUS,CHECKPOINT_RADIUS)
	end, 34)
	mkConfigWPRow(configScroll, "Posición Meta/Vuelta", function(cf)
		LAP_LINE_CFRAME=cf
		if lapWall    then lapWall.CFrame=cf*CFrame.Angles(0,mrad(90),0)   end
		if lapSphere  then lapSphere.CFrame=cf                               end
		applyWPVisibility()
	end, 35)
	mkConfigWPRow(configScroll, "Posición Entrada Boxes", function(cf)
		PIT_ENTRY_CFRAME=cf
		if pitInWall      then pitInWall.CFrame=cf*CFrame.Angles(0,mrad(90),0)   end
		if pitEntrySphere then pitEntrySphere.CFrame=cf                          end
		applyWPVisibility()
	end, 36)
	mkConfigWPRow(configScroll, "Posición Salida Boxes", function(cf)
		PIT_EXIT_CFRAME=cf
		if pitOutWall    then pitOutWall.CFrame=cf*CFrame.Angles(0,mrad(90),0)  end
		if pitExitSphere then pitExitSphere.CFrame=cf                           end
		applyWPVisibility()
	end, 37)

	-- ── CONFIG: HUD Cabeza ─────────────────────────────────────
	makeSectionHeader(configScroll, "🧠  HUD SOBRE LA CABEZA", 40)
	mkConfigToggleRow(configScroll, "Mostrar nombre sobre cabeza",    function() return SHOW_HEAD_NAME  end, function(v) SHOW_HEAD_NAME=v  end, 41)
	mkConfigToggleRow(configScroll, "Mostrar velocidad sobre cabeza", function() return SHOW_HEAD_SPEED end, function(v) SHOW_HEAD_SPEED=v end, 42)

	-- ── CONFIG: Resetear ───────────────────────────────────────
	makeSectionHeader(configScroll, "🔄  RESETEAR", 50)
	mkConfigActionRow(configScroll, "RESETEAR VUELTAS (todos)", C_DARKRED, function()
		lapData={}
		for _,pl in ipairs(Players:GetPlayers()) do ensurePlayerData(pl) end
		for uid, cached in pairs(vueltasRowCache) do
			local topRow = cached.topRow
			if topRow then
				local lc = topRow:FindFirstChild("LapCount")
				if lc then lc.Text = sformat("LAP 0/%d", MAX_LAPS); lc.TextColor3= C_WHITE end
			end
		end
	end, 51)
	mkConfigActionRow(configScroll, "RESETEAR FAST LAPS (todos)", C_DARKRED, function()
		fastLapData={}
		for _,pl in ipairs(Players:GetPlayers()) do ensurePlayerData(pl) end
		bestTimeLabel.Text="--:--.---  |  ---"
		for uid, row in pairs(fastLapsRowCache) do
			local rightLbl = row:FindFirstChild("RightLbl")
			if rightLbl then rightLbl.Text = "NO TIME"; rightLbl.TextColor3= C_GRAY end
		end
	end, 52)
	mkConfigActionRow(configScroll, "RESETEAR BOXES (todos)", C_DARKRED, function()
		pitData={}
		for _,pl in ipairs(Players:GetPlayers()) do ensurePlayerData(pl) end
		for uid, row in pairs(boxesRowCache) do
			local rightLbl = row:FindFirstChild("RightLbl")
			if rightLbl then rightLbl.Text = sformat("PIT 0/%d", MAX_PITS); rightLbl.TextColor3= C_WHITE end
		end
	end, 53)
	mkConfigActionRow(configScroll, "OCULTAR HUD (Q)", C_BG2, function()
		if toggleHUD then toggleHUD() end
	end, 54)

	-- ── CONFIG: Torre ──────────────────────────────────────────
	makeSectionHeader(configScroll, "🏆  TORRE DE POSICIONES", 60)
	mkConfigToggleRow(configScroll, "Mostrar Torre", function() return towerConfig.visible end, function(v) towerConfig.visible=v; applyTowerConfig() end, 61)

	do  -- Tamaño torre
		local row=Instance.new("Frame")
		row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=C_BG2; row.BorderSizePixel=0; row.LayoutOrder=62; row.Parent=configScroll
		local lbl=Instance.new("TextLabel")
		lbl.Size=UDim2.new(0.45,0,1,0); lbl.Position=UDim2.new(0,10,0,0); lbl.BackgroundTransparency=1
		lbl.Text="Tamaño Torre"; lbl.Font=Enum.Font.GothamBold; lbl.TextColor3=C_WHITE; lbl.TextSize=12
		lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
		local valLbl=Instance.new("TextLabel")
		valLbl.Size=UDim2.new(0.15,0,1,0); valLbl.Position=UDim2.new(0.45,0,0,0); valLbl.BackgroundTransparency=1
		valLbl.Text=sformat("%.1f",TOWER_SCALE); valLbl.Font=Enum.Font.GothamBold; valLbl.TextColor3=C_YELLOW; valLbl.TextSize=13; valLbl.Parent=row
		local minus=Instance.new("TextButton")
		minus.Size=UDim2.new(0.15,0,0.7,0); minus.Position=UDim2.new(0.62,0,0.15,0)
		minus.BackgroundColor3=Color3.fromRGB(50,50,60); minus.Text="−"; minus.Font=Enum.Font.GothamBold
		minus.TextColor3=C_WHITE; minus.TextSize=16; minus.BorderSizePixel=0; minus.Parent=row
		local mc=Instance.new("UICorner"); mc.CornerRadius=UDim.new(0,3); mc.Parent=minus
		local plus=Instance.new("TextButton")
		plus.Size=UDim2.new(0.15,0,0.7,0); plus.Position=UDim2.new(0.80,0,0.15,0)
		plus.BackgroundColor3=Color3.fromRGB(50,50,60); plus.Text="+"; plus.Font=Enum.Font.GothamBold
		plus.TextColor3=C_WHITE; plus.TextSize=16; plus.BorderSizePixel=0; plus.Parent=row
		local pc=Instance.new("UICorner"); pc.CornerRadius=UDim.new(0,3); pc.Parent=plus
		minus.MouseButton1Click:Connect(function()
			TOWER_SCALE=mclamp(mfloor((TOWER_SCALE-0.1)*10+0.5)/10,0.5,3.0)
			valLbl.Text=sformat("%.1f",TOWER_SCALE); applyTowerScale()
		end)
		plus.MouseButton1Click:Connect(function()
			TOWER_SCALE=mclamp(mfloor((TOWER_SCALE+0.1)*10+0.5)/10,0.5,3.0)
			valLbl.Text=sformat("%.1f",TOWER_SCALE); applyTowerScale()
		end)
	end

	do  -- Posición X torre
		local row=Instance.new("Frame")
		row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=C_BG2; row.BorderSizePixel=0; row.LayoutOrder=63; row.Parent=configScroll
		local lbl=Instance.new("TextLabel")
		lbl.Size=UDim2.new(0.45,0,1,0); lbl.Position=UDim2.new(0,10,0,0); lbl.BackgroundTransparency=1
		lbl.Text="Posición X (%)"; lbl.Font=Enum.Font.GothamBold; lbl.TextColor3=C_WHITE; lbl.TextSize=12
		lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
		local valLbl=Instance.new("TextLabel")
		valLbl.Size=UDim2.new(0.15,0,1,0); valLbl.Position=UDim2.new(0.45,0,0,0); valLbl.BackgroundTransparency=1
		valLbl.Text=tostring(mround(towerConfig.posX*100)); valLbl.Font=Enum.Font.GothamBold; valLbl.TextColor3=C_YELLOW; valLbl.TextSize=13; valLbl.Parent=row
		local minus=Instance.new("TextButton")
		minus.Size=UDim2.new(0.15,0,0.7,0); minus.Position=UDim2.new(0.62,0,0.15,0)
		minus.BackgroundColor3=Color3.fromRGB(50,50,60); minus.Text="−"; minus.Font=Enum.Font.GothamBold
		minus.TextColor3=C_WHITE; minus.TextSize=16; minus.BorderSizePixel=0; minus.Parent=row
		local mc=Instance.new("UICorner"); mc.CornerRadius=UDim.new(0,3); mc.Parent=minus
		local plus=Instance.new("TextButton")
		plus.Size=UDim2.new(0.15,0,0.7,0); plus.Position=UDim2.new(0.80,0,0.15,0)
		plus.BackgroundColor3=Color3.fromRGB(50,50,60); plus.Text="+"; plus.Font=Enum.Font.GothamBold
		plus.TextColor3=C_WHITE; plus.TextSize=16; plus.BorderSizePixel=0; plus.Parent=row
		local pc=Instance.new("UICorner"); pc.CornerRadius=UDim.new(0,3); pc.Parent=plus
		minus.MouseButton1Click:Connect(function()
			towerConfig.posX=mclamp(towerConfig.posX-0.05,0,1)
			towerConfig.offsetX=-mround(TOWER_WIDTH*TOWER_SCALE)
			valLbl.Text=tostring(mround(towerConfig.posX*100)); applyTowerConfig()
		end)
		plus.MouseButton1Click:Connect(function()
			towerConfig.posX=mclamp(towerConfig.posX+0.05,0,1)
			towerConfig.offsetX=-mround(TOWER_WIDTH*TOWER_SCALE)
			valLbl.Text=tostring(mround(towerConfig.posX*100)); applyTowerConfig()
		end)
	end

	do  -- Posición Y torre
		local row=Instance.new("Frame")
		row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=C_BG2; row.BorderSizePixel=0; row.LayoutOrder=64; row.Parent=configScroll
		local lbl=Instance.new("TextLabel")
		lbl.Size=UDim2.new(0.45,0,1,0); lbl.Position=UDim2.new(0,10,0,0); lbl.BackgroundTransparency=1
		lbl.Text="Posición Y (%)"; lbl.Font=Enum.Font.GothamBold; lbl.TextColor3=C_WHITE; lbl.TextSize=12
		lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
		local valLbl=Instance.new("TextLabel")
		valLbl.Size=UDim2.new(0.15,0,1,0); valLbl.Position=UDim2.new(0.45,0,0,0); valLbl.BackgroundTransparency=1
		valLbl.Text=tostring(mround(towerConfig.posY*100)); valLbl.Font=Enum.Font.GothamBold; valLbl.TextColor3=C_YELLOW; valLbl.TextSize=13; valLbl.Parent=row
		local minus=Instance.new("TextButton")
		minus.Size=UDim2.new(0.15,0,0.7,0); minus.Position=UDim2.new(0.62,0,0.15,0)
		minus.BackgroundColor3=Color3.fromRGB(50,50,60); minus.Text="−"; minus.Font=Enum.Font.GothamBold
		minus.TextColor3=C_WHITE; minus.TextSize=16; minus.BorderSizePixel=0; minus.Parent=row
		local mc=Instance.new("UICorner"); mc.CornerRadius=UDim.new(0,3); mc.Parent=minus
		local plus=Instance.new("TextButton")
		plus.Size=UDim2.new(0.15,0,0.7,0); plus.Position=UDim2.new(0.80,0,0.15,0)
		plus.BackgroundColor3=Color3.fromRGB(50,50,60); plus.Text="+"; plus.Font=Enum.Font.GothamBold
		plus.TextColor3=C_WHITE; plus.TextSize=16; plus.BorderSizePixel=0; plus.Parent=row
		local pc=Instance.new("UICorner"); pc.CornerRadius=UDim.new(0,3); pc.Parent=plus
		minus.MouseButton1Click:Connect(function()
			towerConfig.posY=mclamp(towerConfig.posY-0.05,0,1)
			towerConfig.offsetY=12; valLbl.Text=tostring(mround(towerConfig.posY*100)); applyTowerConfig()
		end)
		plus.MouseButton1Click:Connect(function()
			towerConfig.posY=mclamp(towerConfig.posY+0.05,0,1)
			towerConfig.offsetY=12; valLbl.Text=tostring(mround(towerConfig.posY*100)); applyTowerConfig()
		end)
	end

	do  -- Color encabezado torre
		local colorOptions={
			{name="ROJO",    color=Color3.fromRGB(230,0,0)},
			{name="BLANCO",  color=Color3.fromRGB(200,200,200)},
			{name="VERDE",   color=Color3.fromRGB(0,180,70)},
			{name="AMARILLO",color=Color3.fromRGB(220,180,0)},
			{name="AZUL",    color=Color3.fromRGB(0,100,210)},
			{name="NARANJA", color=Color3.fromRGB(255,130,0)},
			{name="MORADO",  color=Color3.fromRGB(140,0,200)},
		}
		local colorIndex=1
		local row=Instance.new("Frame")
		row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=C_BG2; row.BorderSizePixel=0; row.LayoutOrder=65; row.Parent=configScroll
		local lbl=Instance.new("TextLabel")
		lbl.Size=UDim2.new(0.45,0,1,0); lbl.Position=UDim2.new(0,10,0,0); lbl.BackgroundTransparency=1
		lbl.Text="Color Encabezado"; lbl.Font=Enum.Font.GothamBold; lbl.TextColor3=C_WHITE; lbl.TextSize=12
		lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
		local colorBtn=Instance.new("TextButton")
		colorBtn.Size=UDim2.new(0.50,-8,0.7,0); colorBtn.Position=UDim2.new(0.48,0,0.15,0)
		colorBtn.BackgroundColor3=colorOptions[colorIndex].color
		colorBtn.Text=colorOptions[colorIndex].name
		colorBtn.Font=Enum.Font.GothamBold; colorBtn.TextColor3=C_WHITE; colorBtn.TextSize=11
		colorBtn.BorderSizePixel=0; colorBtn.Parent=row
		local cbc2=Instance.new("UICorner"); cbc2.CornerRadius=UDim.new(0,3); cbc2.Parent=colorBtn
		colorBtn.MouseButton1Click:Connect(function()
			colorIndex=colorIndex%#colorOptions+1
			local opt=colorOptions[colorIndex]
			colorBtn.BackgroundColor3=opt.color; colorBtn.Text=opt.name
			towerConfig.headerColor=opt.color; applyTowerConfig()
		end)
	end

	do  -- Título torre
		local row=Instance.new("Frame")
		row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=C_BG2; row.BorderSizePixel=0; row.LayoutOrder=66; row.Parent=configScroll
		local lbl=Instance.new("TextLabel")
		lbl.Size=UDim2.new(0.35,0,1,0); lbl.Position=UDim2.new(0,10,0,0); lbl.BackgroundTransparency=1
		lbl.Text="Título Torre"; lbl.Font=Enum.Font.GothamBold; lbl.TextColor3=C_WHITE; lbl.TextSize=12
		lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
		local input=Instance.new("TextBox")
		input.Size=UDim2.new(0.40,0,0.7,0); input.Position=UDim2.new(0.36,0,0.15,0)
		input.BackgroundColor3=Color3.fromRGB(30,30,40); input.BorderSizePixel=0
		input.Text=towerConfig.titleText; input.Font=Enum.Font.GothamBold
		input.TextColor3=C_YELLOW; input.TextSize=11; input.ClearTextOnFocus=false
		input.TextXAlignment=Enum.TextXAlignment.Left; input.Parent=row
		local tic=Instance.new("UICorner"); tic.CornerRadius=UDim.new(0,3); tic.Parent=input
		local tip=Instance.new("UIPadding"); tip.PaddingLeft=UDim.new(0,4); tip.Parent=input
		local okBtn=Instance.new("TextButton")
		okBtn.Size=UDim2.new(0.20,-4,0.7,0); okBtn.Position=UDim2.new(0.78,0,0.15,0)
		okBtn.BackgroundColor3=Color3.fromRGB(0,100,40); okBtn.Text="✔ OK"
		okBtn.Font=Enum.Font.GothamBold; okBtn.TextColor3=C_WHITE; okBtn.TextSize=11
		okBtn.BorderSizePixel=0; okBtn.Parent=row
		local okc=Instance.new("UICorner"); okc.CornerRadius=UDim.new(0,3); okc.Parent=okBtn
		okBtn.MouseButton1Click:Connect(function()
			if input.Text and input.Text~="" then
				towerConfig.titleText=input.Text
				towerHeaderText.Text=input.Text
			end
		end)
	end

	mkConfigActionRow(configScroll, "↺  RESETEAR POSICIÓN TORRE", Color3.fromRGB(40,40,60), function()
		TOWER_SCALE=1.0
		towerConfig.posX=1; towerConfig.offsetX=-TOWER_WIDTH
		towerConfig.posY=0; towerConfig.offsetY=12
		applyTowerScale(); applyTowerConfig()
	end, 67)

	-- ── Sección Broadcast ─────────────────────────────────────────
	makeSectionHeader(configScroll, "📺  BROADCAST · COLUMNA TORRE", 70)
	do
		local _broadcastLabels = {
			[1] = "📺  BROADCAST: VUELTAS/GAPS",
			[2] = "📺  BROADCAST: TIEMPOS",
			[3] = "📺  BROADCAST: LLANTAS",
		}
		local broadRow = Instance.new("Frame")
		broadRow.Size = UDim2.new(1,0,0,34)
		broadRow.BackgroundColor3 = C_BG2
		broadRow.BorderSizePixel = 0
		broadRow.LayoutOrder = 71
		broadRow.Parent = configScroll

		local broadBtn = Instance.new("TextButton")
		broadBtn.Size = UDim2.new(1,-12,0.75,0)
		broadBtn.Position = UDim2.new(0,6,0.125,0)
		broadBtn.BackgroundColor3 = Color3.fromRGB(60,0,100)
		broadBtn.Text = _broadcastLabels[towerBroadcastMode]
		broadBtn.Font = Enum.Font.GothamBlack
		broadBtn.TextColor3 = C_WHITE
		broadBtn.TextSize = 11
		broadBtn.BorderSizePixel = 0
		broadBtn.Parent = broadRow
		Instance.new("UICorner", broadBtn).CornerRadius = UDim.new(0,3)

		broadBtn.MouseButton1Click:Connect(function()
			towerBroadcastMode = (towerBroadcastMode % 3) + 1
			broadBtn.Text = _broadcastLabels[towerBroadcastMode]
		end)
	end

	-- ══════════════════════════════════════════════════════════
	-- ACTUALIZACIÓN DE LISTAS
	-- ══════════════════════════════════════════════════════════
	local function updateGuiLists()
		local activeUids = {}
		local allData = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
				ensurePlayerData(p)
				tinsert(allData, {
					player = p,
					lap    = lapData[p.UserId],
					pit    = pitData[p.UserId],
					fast   = fastLapData[p.UserId],
					speed  = getPlayerSpeed(p)
				})
				activeUids[p.UserId] = true
			end
		end

		for uid, cached in pairs(vueltasRowCache) do
			if not activeUids[uid] then
				if cached.topRow    and cached.topRow.Parent    then cached.topRow:Destroy()    end
				if cached.btnRow    and cached.btnRow.Parent    then cached.btnRow:Destroy()    end
				if cached.lapAdjRow and cached.lapAdjRow.Parent then cached.lapAdjRow:Destroy() end
				vueltasRowCache[uid] = nil
			end
		end
		for uid, row in pairs(boxesRowCache) do
			if not activeUids[uid] then if row and row.Parent then row:Destroy() end; boxesRowCache[uid] = nil end
		end
		for uid, row in pairs(fastLapsRowCache) do
			if not activeUids[uid] then if row and row.Parent then row:Destroy() end; fastLapsRowCache[uid] = nil end
		end

		tsort(allData, function(a,b)
			local la,lb = a.lap.lapsMade or 0, b.lap.lapsMade or 0
			if la ~= lb then return la > lb end
			local ta = a.lap.lastLapTouch==0 and math.huge or (a.lap.lastLapTouch or math.huge)
			local tb = b.lap.lastLapTouch==0 and math.huge or (b.lap.lastLapTouch or math.huge)
			return ta < tb
		end)

		local qualySorted = {}
		for _, pd in ipairs(allData) do tinsert(qualySorted, pd) end
		tsort(qualySorted, function(a,b)
			local at,bt = a.fast.bestTime, b.fast.bestTime
			if at and bt  then return at < bt
			elseif at     then return true
			elseif bt     then return false
			else return a.player.Name < b.player.Name end
		end)

		-- Filtrar jugadores FIA: no aparecen en la torre
		-- Si tienen fila creada, destruirla para que desaparezca limpiamente
		for uid2, tRow2 in pairs(towerRows) do
			if FIA_EXCLUDED[uid2] then
				tRow2:Destroy()
				towerRows[uid2] = nil
				towerRowData[uid2] = nil
			end
		end
		local _towerFiltered = {}
		for _, pd in ipairs(QUALY_MODE and qualySorted or allData) do
			if not FIA_EXCLUDED[pd.player.UserId] then
				table.insert(_towerFiltered, pd)
			end
		end
		local sourceData = _towerFiltered

		local existingRows = {}
		for _, child in pairs(towerContainer:GetChildren()) do
			if child:IsA("Frame") and child ~= towerHeader then existingRows[child.Name] = child end
		end

		local bestQualyTime = (qualySorted[1] and qualySorted[1].fast.bestTime) or nil

		for i, pd in ipairs(sourceData) do
			if i > MAX_PLAYERS_DISPLAY then break end
			local uid     = pd.player.UserId
			local rowName = "Row_"..uid
			local row     = existingRows[rowName]

			if not row then
				row = getOrCreateTowerRow(uid, getDisplayName(pd.player), i)
				if row then
					local tb = row:FindFirstChild("TeamBar")
					if tb then tb.BackgroundColor3 = getNameColor(pd.player) end
				end
			else
				row.LayoutOrder = i
				existingRows[rowName] = nil
				local nameTxt = row:FindFirstChild("Name")
				if nameTxt then
					nameTxt.Text       = supper(ssub(getDisplayName(pd.player),1,8))
					nameTxt.TextColor3 = FIA_EXCLUDED[uid] and C_BLUE or getNameColor(pd.player)
				end
				local tb = row:FindFirstChild("TeamBar")
				if tb then tb.BackgroundColor3 = getNameColor(pd.player) end
			end

			if row then
				local rd = towerRowData[uid]
				if rd then
					if rd.lastPos and rd.lastPos ~= i then animTowerRow(uid, i, rd.lastPos) end
					rd.lastPos = i
				end
				local posFrame = row:FindFirstChild("PosFrame")
				if posFrame then
					local posTxt = posFrame:FindFirstChild("Pos")
					if posTxt then posTxt.Text = tostring(i) end
					if i == 1 then posFrame.BackgroundColor3 = QUALY_MODE and C_F1_PURPLE or C_RED
					elseif i <= 3 then posFrame.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
					else posFrame.BackgroundColor3 = C_WHITE end
					local posTxt2 = posFrame:FindFirstChild("Pos")
					if posTxt2 then posTxt2.TextColor3 = (i <= 3) and C_WHITE or C_BG end
				end
				local lapTxt = row:FindFirstChild("Lap")
				if lapTxt then
					if QUALY_MODE then
						-- Modo Qualy: siempre muestra tiempos/gaps, ignora towerBroadcastMode
						if pd.fast.bestTime then
							if i == 1 then lapTxt.Text = fmtTime(pd.fast.bestTime); lapTxt.TextColor3= C_F1_PURPLE
							else local delta = pd.fast.bestTime - (bestQualyTime or pd.fast.bestTime); lapTxt.Text = fmtTimeDelta(delta); lapTxt.TextColor3= C_F1_YELLOW end
						else lapTxt.Text = "NO TIME"; lapTxt.TextColor3= C_GRAY end
						lapTxt.TextSize = mclamp(mround(7*TOWER_SCALE), 6, 12)
					elseif towerBroadcastMode == 2 then
						-- Modo 2: Mejor tiempo personal
						if pd.fast.bestTime then
							lapTxt.Text      = fmtTime(pd.fast.bestTime)
							lapTxt.TextColor3 = i == 1 and C_F1_PURPLE or C_WHITE
						else
							lapTxt.Text      = "NO TIME"
							lapTxt.TextColor3 = C_GRAY
						end
						lapTxt.TextSize = mclamp(mround(7*TOWER_SCALE), 6, 12)
					elseif towerBroadcastMode == 3 then
						-- Modo 3: Compuesto de llanta actual
						local tirUid = pd.player.UserId
						local cpd = SPA_Tires and SPA_Tires.current and SPA_Tires.current[tirUid]
						if cpd then
							lapTxt.Text      = cpd.icon .. " " .. cpd.name
							lapTxt.TextColor3 = cpd.color
						else
							lapTxt.Text      = "—"
							lapTxt.TextColor3 = C_GRAY
						end
						lapTxt.TextSize = mclamp(mround(8*TOWER_SCALE), 6, 14)
					else
						-- Modo 1 (default): Vueltas
						lapTxt.Text = "L"..(pd.lap.lapsMade or 0); lapTxt.TextColor3= C_GRAY; lapTxt.TextSize = mclamp(mround(10*TOWER_SCALE), 8, 18)
					end
				end
			end

			local uid = pd.player.UserId
			if vueltasRowCache[uid] then
				local cached   = vueltasRowCache[uid]
				local cachedTop = cached.topRow
				local cachedBtn = cached.btnRow
				if cachedTop then
					cachedTop.LayoutOrder = i * 10
					local lc = cachedTop:FindFirstChild("LapCount")
					if lc then
						local ld = lapData[uid] or {lapsMade=0}
						lc.Text       = sformat("LAP %d/%d", ld.lapsMade or 0, MAX_LAPS)
						lc.TextColor3 = (ld.lapsMade or 0)==MAX_LAPS and C_YELLOW or C_WHITE
					end
					local nameLbl = cachedTop:FindFirstChild("NameLabel")
					if nameLbl then
						local displayName = getDisplayName(pd.player)..(FIA_EXCLUDED[uid] and "  [FIA]" or "")
						nameLbl.Text       = displayName
						nameLbl.TextColor3 = FIA_EXCLUDED[uid] and C_BLUE or getNameColor(pd.player)
					end
					local posLbl = cachedTop:FindFirstChild("PosLabel")
					if posLbl then posLbl.Text = "P"..i end
				end
				if cachedBtn then cachedBtn.LayoutOrder = i * 10 + 1 end
				local cachedAdj = cached.lapAdjRow
				if cachedAdj then cachedAdj.LayoutOrder = i * 10 + 2 end
			else
				makeVueltasRow(vueltasScroll, i, i, pd.player)
				local cached = vueltasRowCache[uid]
				if cached and cached.topRow then
					local children = cached.topRow:GetChildren()
					for _, child in ipairs(children) do
						if child:IsA("TextLabel") then
							if child.Text:match("^P%d") then child.Name = "PosLabel"
							elseif child.Text:match("^LAP") then child.Name = "LapCount"
							elseif child.Name == "" or child.Name == "TextLabel" then child.Name = "NameLabel" end
						end
					end
				end
			end

			local displayName2 = getDisplayName(pd.player)..(FIA_EXCLUDED[uid] and "  [FIA]" or "")
			local nameCol2     = FIA_EXCLUDED[uid] and C_BLUE or getNameColor(pd.player)
			local pitText      = sformat("PIT %d/%d", pd.pit.pitStopsMade or 0, MAX_PITS)
			local pitColor     = pd.pit.status=="En Boxes" and C_ORANGE or C_WHITE

			if boxesRowCache[uid] then
				local cachedRow = boxesRowCache[uid]
				cachedRow.LayoutOrder = i
				local nameLbl  = cachedRow:FindFirstChild("NameLbl")
				local posLbl   = cachedRow:FindFirstChild("PosLbl")
				local rightLbl = cachedRow:FindFirstChild("RightLbl")
				if nameLbl  then nameLbl.Text = displayName2; nameLbl.TextColor3 = nameCol2 end
				if posLbl   then posLbl.Text  = "P"..i end
				if rightLbl then rightLbl.Text = pitText; rightLbl.TextColor3 = pitColor end
			else
				local order = i
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1,0,0,30); row.BackgroundColor3 = order % 2 == 0 and C_BG2 or C_BG; row.BorderSizePixel = 0; row.LayoutOrder = order; row.Parent = boxesScroll
				local bar = Instance.new("Frame")
				bar.Size = UDim2.new(0,3,1,0); bar.BackgroundColor3 = Color3.fromHSV((order*0.13)%1, 0.85, 1); bar.BorderSizePixel = 0; bar.Parent = row
				local posLbl = Instance.new("TextLabel")
				posLbl.Name = "PosLbl"; posLbl.Size = UDim2.new(0,28,1,0); posLbl.Position = UDim2.new(0,6,0,0); posLbl.BackgroundTransparency = 1; posLbl.Text = "P"..i; posLbl.Font = Enum.Font.GothamBlack; posLbl.TextColor3 = C_RED; posLbl.TextSize = 13; posLbl.TextXAlignment = Enum.TextXAlignment.Left; posLbl.Parent = row
				local nameLbl = Instance.new("TextLabel")
				nameLbl.Name = "NameLbl"; nameLbl.Size = UDim2.new(0.5,0,1,0); nameLbl.Position = UDim2.new(0,38,0,0); nameLbl.BackgroundTransparency = 1; nameLbl.Text = displayName2; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextColor3 = nameCol2; nameLbl.TextSize = 12; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Parent = row
				local rightLbl = Instance.new("TextLabel")
				rightLbl.Name = "RightLbl"; rightLbl.Size = UDim2.new(0.4,-8,1,0); rightLbl.Position = UDim2.new(0.6,0,0,0); rightLbl.BackgroundTransparency = 1; rightLbl.Text = pitText; rightLbl.Font = Enum.Font.GothamBold; rightLbl.TextColor3 = pitColor; rightLbl.TextSize = 12; rightLbl.TextXAlignment = Enum.TextXAlignment.Right; rightLbl.Parent = row
				local rp = Instance.new("UIPadding"); rp.PaddingRight = UDim.new(0,8); rp.Parent = row
				boxesRowCache[uid] = row
			end
		end
		for _, old in pairs(existingRows) do old:Destroy() end

		for i, pd in ipairs(qualySorted) do
			local uid       = pd.player.UserId
			local timeText  = pd.fast.bestTime and fmtTime(pd.fast.bestTime) or "NO TIME"
			local timeColor = pd.fast.bestTime and (i==1 and C_GREEN or C_WHITE) or C_GRAY

			if fastLapsRowCache[uid] then
				local cachedRow = fastLapsRowCache[uid]
				cachedRow.LayoutOrder = i
				local posLbl   = cachedRow:FindFirstChild("PosLbl")
				local nameLbl  = cachedRow:FindFirstChild("NameLbl")
				local rightLbl = cachedRow:FindFirstChild("RightLbl")
				if posLbl   then posLbl.Text   = "P"..i end
				if nameLbl  then nameLbl.Text  = getDisplayName(pd.player); nameLbl.TextColor3 = getNameColor(pd.player) end
				if rightLbl then rightLbl.Text = timeText; rightLbl.TextColor3= timeColor end
			else
				local order = i
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1,0,0,30); row.BackgroundColor3 = order % 2 == 0 and C_BG2 or C_BG; row.BorderSizePixel = 0; row.LayoutOrder = order; row.Parent = fastLapsScroll
				local bar = Instance.new("Frame")
				bar.Size = UDim2.new(0,3,1,0); bar.BackgroundColor3 = Color3.fromHSV((order*0.13)%1, 0.85, 1); bar.BorderSizePixel = 0; bar.Parent = row
				local posLbl = Instance.new("TextLabel")
				posLbl.Name = "PosLbl"; posLbl.Size = UDim2.new(0,28,1,0); posLbl.Position = UDim2.new(0,6,0,0); posLbl.BackgroundTransparency = 1; posLbl.Text = "P"..i; posLbl.Font = Enum.Font.GothamBlack; posLbl.TextColor3 = C_RED; posLbl.TextSize = 13; posLbl.TextXAlignment = Enum.TextXAlignment.Left; posLbl.Parent = row
				local nameLbl = Instance.new("TextLabel")
				nameLbl.Name = "NameLbl"; nameLbl.Size = UDim2.new(0.5,0,1,0); nameLbl.Position = UDim2.new(0,38,0,0); nameLbl.BackgroundTransparency = 1; nameLbl.Text = getDisplayName(pd.player); nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextColor3 = getNameColor(pd.player); nameLbl.TextSize = 12; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Parent = row
				local rightLbl = Instance.new("TextLabel")
				rightLbl.Name = "RightLbl"; rightLbl.Size = UDim2.new(0.4,-8,1,0); rightLbl.Position = UDim2.new(0.6,0,0,0); rightLbl.BackgroundTransparency = 1; rightLbl.Text = timeText; rightLbl.Font = Enum.Font.GothamBold; rightLbl.TextColor3 = timeColor; rightLbl.TextSize = 12; rightLbl.TextXAlignment = Enum.TextXAlignment.Right; rightLbl.Parent = row
				local rp = Instance.new("UIPadding"); rp.PaddingRight = UDim.new(0,8); rp.Parent = row
				fastLapsRowCache[uid] = row
			end
		end

		if qualySorted[1] and qualySorted[1].fast.bestTime then
			local best = qualySorted[1]
			bestTimeLabel.Text      = fmtTime(best.fast.bestTime).."  |  "..getDisplayName(best.player)
			bestTimeLabel.TextColor3= C_GREEN
		else
			bestTimeLabel.Text      = "--:--.---  |  ---"
			bestTimeLabel.TextColor3= C_GRAY
		end

		local leaderLaps = (allData[1] and allData[1].lap.lapsMade) or 0
		if QUALY_MODE then towerHeaderText.Text = "QUALY "..QUALY_LAPS.." LAP"
		else towerHeaderText.Text = "LAP "..leaderLaps.."/"..MAX_LAPS end
		lapNumLabel.Text = leaderLaps.." / "..MAX_LAPS
	end

	-- [SDE_INFI · PointToObjectSpace] Tracking de lado por muro (reemplaza lastSeenIn booleanos)
	-- Estructura: [uid] = { side = 1/-1, cross = tick() }
	local _lapSide    = {}   -- lapWall
	local _pitInSide  = {}   -- pitInWall (entrada boxes)
	local _pitOutSide = {}   -- pitOutWall (salida boxes)

	local function createSpeedTag(character, p)
		local head = character:FindFirstChild("Head")
		if not head then return end
		local existing = head:FindFirstChild("SpeedTag")
		if existing then return existing end

		local billboard = Instance.new("BillboardGui")
		-- [SPAV4] 3 líneas: Nombre · Vel · Telemetría
		billboard.Name        = "SpeedTag"; billboard.Size = UDim2.new(0,240,0,68); billboard.StudsOffset = Vector3.new(0,3,0); billboard.AlwaysOnTop = true; billboard.MaxDistance = math.huge; billboard.Adornee = head; billboard.Parent = head
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "NameLabel"; nameLbl.Size = UDim2.new(1,0,0.33,0); nameLbl.BackgroundTransparency= 1; nameLbl.TextColor3 = getNameColor(p); nameLbl.TextStrokeColor3 = Color3.fromRGB(0,0,0); nameLbl.TextStrokeTransparency= 0; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextScaled = true; nameLbl.Text = getDisplayName(p); nameLbl.Parent = billboard
		local speedLbl = Instance.new("TextLabel")
		speedLbl.Name = "SpeedText"; speedLbl.Size = UDim2.new(1,0,0.33,0); speedLbl.Position = UDim2.new(0,0,0.33,0); speedLbl.BackgroundTransparency= 1; speedLbl.TextColor3 = C_WHITE; speedLbl.TextStrokeColor3 = Color3.fromRGB(0,0,0); speedLbl.TextStrokeTransparency= 0; speedLbl.Font = Enum.Font.GothamBold; speedLbl.TextScaled = false; speedLbl.Text = ""; speedLbl.Parent = billboard
		-- Línea de telemetría (Turbo · Drift · Suspensión)
		local telLbl = Instance.new("TextLabel")
		telLbl.Name = "TelemetryText"; telLbl.Size = UDim2.new(1,0,0.34,0); telLbl.Position = UDim2.new(0,0,0.66,0); telLbl.BackgroundTransparency= 1; telLbl.TextColor3 = Color3.fromRGB(160,210,255); telLbl.TextStrokeColor3 = Color3.fromRGB(0,0,0); telLbl.TextStrokeTransparency= 0; telLbl.Font = Enum.Font.GothamBold; telLbl.TextScaled = false; telLbl.Text = ""; telLbl.Parent = billboard
		return billboard
	end

	local function removeSpeedTag(character)
		local head = character:FindFirstChild("Head")
		if head then local tag = head:FindFirstChild("SpeedTag"); if tag then tag:Destroy() end end
	end

	local alertedPlayers = {}

	-- [SDE_INFI · CAMBIO 1] _hbHead — actualiza SpeedTags sobre las cabezas (≈16 Hz)
	_SDEI.hbHead = function()
		local localChar = player.Character
		if not localChar or not localChar:FindFirstChild("HumanoidRootPart") then return end
		overlapParams.FilterDescendantsInstances = getPlayerCharacters()
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			if not char then continue end
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			local head     = char:FindFirstChild("Head")
			if not humanoid or not head then continue end

			local seat = humanoid.SeatPart
			if seat and seat:IsA("VehicleSeat") and seat.Occupant == humanoid then
				local tag = createSpeedTag(char, p)
				if tag then
					tag.Enabled = SHOW_HEAD_NAME or SHOW_HEAD_SPEED
					local nameLbl  = tag:FindFirstChild("NameLabel")
					if nameLbl then
						nameLbl.Text       = getDisplayName(p)
						nameLbl.TextColor3 = FIA_EXCLUDED[p.UserId] and C_BLUE or getNameColor(p)
						nameLbl.Visible    = SHOW_HEAD_NAME
					end
					local speedLbl = tag:FindFirstChild("SpeedText")
					if speedLbl then
						local uid    = p.UserId
						local cdS    = customPlayerData[uid]
						-- Límite efectivo: personalizado si existe, global (70) si no
						local effLim = (cdS and cdS.speedLimit) or SPEED_LIMIT
						-- MaxSpeed del vehículo = lo que se compara vs el límite
						local maxSpd = getPlayerSpeedLimit(seat)
						if SHOW_HEAD_SPEED then
							-- Studs/s = info aparte, se muestra al lado del MaxSpeed
							local studs = mfloor(getVehicleSpeed(seat) + 0.5)
							speedLbl.Text      = sformat("%.1f km/h  |  %d st/s", maxSpd, studs)
							local dist         = (head.Position - Camera.CFrame.Position).Magnitude
							speedLbl.TextSize  = mclamp(30*(10/mmax(dist,1)),14,40)
							-- Rojo cuando MaxSpeed supera el límite efectivo
							speedLbl.TextColor3= maxSpd > effLim and C_RED or C_WHITE
							speedLbl.Visible   = true
						else
							speedLbl.Text    = ""
							speedLbl.Visible = false
						end
						-- Notificación: dispara UNA VEZ cuando el piloto monta un motor nuevo que supera el límite
						-- Si sigue con el mismo MaxSpeed ilegal → sin spam
						if maxSpd > effLim then
							if lastSpeeds[uid] ~= maxSpd then
								-- Motor diferente al anterior → alerta única
								showSpeedingNotification(getDisplayName(p), maxSpd)
							end
						end
						-- Guardar siempre el MaxSpeed actual (legal o ilegal)
						lastSpeeds[uid] = maxSpd
					end
					-- [SPAV4] Telemetría: Turbo · Drift · Suspensión
					local telLbl = tag:FindFirstChild("TelemetryText")
					if telLbl and SHOW_HEAD_SPEED then
						local turboV = _telGetTurbo(seat)
						local driftV = _telGetDrift(seat)
						local suspV  = _telGetSusp(seat)
						local distT  = (head.Position - Camera.CFrame.Position).Magnitude
						telLbl.Text     = sformat("T:%s  D:%s  S:%s", turboV, driftV, suspV)
						telLbl.TextSize = mclamp(30*(10/mmax(distT,1))*0.7, 9, 28)
						telLbl.Visible  = true
						local cdT = customPlayerData[p.UserId]
						if cdT then
							local now = tick()
							if cdT.maxTurbo then
								local cI = SPA_Telemetry.TURBO_IDX[turboV] or 0
								local mI = SPA_Telemetry.TURBO_IDX[cdT.maxTurbo] or 999
								local ak = p.UserId.."_turbo"
								if cI > mI and (not SPA_Telemetry.alerts[ak] or now-SPA_Telemetry.alerts[ak] > NOTIFICATION_COOLDOWN) then
									SPA_Telemetry.alerts[ak] = now
									showNotification("⚡ "..getDisplayName(p).."  TURBO "..turboV.." > "..cdT.maxTurbo, C_ORANGE, "⚡", 56)
								end
							end
							if cdT.maxSusp then
								local cI2 = SPA_Telemetry.SUSP_IDX[suspV] or 0
								local mI2 = SPA_Telemetry.SUSP_IDX[cdT.maxSusp] or 999
								local ak2 = p.UserId.."_susp"
								if cI2 > mI2 and (not SPA_Telemetry.alerts[ak2] or now-SPA_Telemetry.alerts[ak2] > NOTIFICATION_COOLDOWN) then
									SPA_Telemetry.alerts[ak2] = now
									showNotification("🔧 "..getDisplayName(p).."  SUSP "..suspV.." > "..cdT.maxSusp, C_YELLOW, "🔧", 92)
								end
							end
							if cdT.maxDrift then
								local dNum = tonumber(driftV) or 0
								local ak3  = p.UserId.."_drift"
								if dNum > cdT.maxDrift and (not SPA_Telemetry.alerts[ak3] or now-SPA_Telemetry.alerts[ak3] > NOTIFICATION_COOLDOWN) then
									SPA_Telemetry.alerts[ak3] = now
									showNotification("💨 "..getDisplayName(p).."  DRIFT "..driftV.." > "..tostring(cdT.maxDrift), C_RED, "💨", 128)
								end
							end
						end
					elseif telLbl then
						telLbl.Text = ""; telLbl.Visible = false
					end
				end
			else
				removeSpeedTag(char)
				alertedPlayers[p.UserId] = nil
			end
		end
	end

	-- [SDE_INFI · CAMBIO 1] _hbLap — detección de vueltas, pits y CC (≈16 Hz)
	_SDEI.hbLap = function()
		-- ── Helper: posición del piloto (VehicleSeat > HumanoidRootPart) ──
		local function _getPos(pl)
			local char = pl.Character
			if not char then return nil end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				local seat = hum.SeatPart
				if seat and seat:IsA("VehicleSeat") and seat.Occupant == hum then
					return seat.CFrame.Position
				end
			end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			return hrp and hrp.Position or nil
		end

		-- ── Helper: detecta cruce de muro para un jugador ──────────────
		-- Retorna true la primera vez que el jugador cambia de lado
		-- mientras está dentro de los límites del muro y el debounce expiró.
		-- Actualiza siempre el tracking[uid].side para el próximo frame.
		local function _wallCross(wall, tracking, uid, pos, debounceTime)
			local l3    = wall.CFrame:PointToObjectSpace(pos)
			local side  = l3.Z >= 0 and 1 or -1
			local half  = wall.Size
			local inBnd = mabs(l3.X) <= half.X / 2 + 4
			           and mabs(l3.Y) <= half.Y / 2 + 4
			local tr    = tracking[uid]
			if not tr then
				-- Primera vez: inicializar sin disparar cruce
				tracking[uid] = { side = side, cross = 0 }
				return false
			end
			local crossed = false
			if inBnd and side ~= tr.side then
				local now = tick()
				if now - tr.cross >= debounceTime then
					tr.cross  = now
					crossed   = true
				end
			end
			tr.side = side   -- actualizar siempre, también fuera de bounds
			return crossed
		end

		-- ── Detección Vueltas ──────────────────────────────────────────
		if DETECT_LAPS and lapWall then
			for _, pl in ipairs(Players:GetPlayers()) do
				ensurePlayerData(pl)
				local uid = pl.UserId
				local pos = _getPos(pl)
				if not pos then continue end
				if _wallCross(lapWall, _lapSide, uid, pos, DEBOUNCE_TIME) then
					if not FIA_EXCLUDED[uid] then
						local ld  = lapData[uid]
						local fld = fastLapData[uid]
						local now = tick()
						ld.lapsMade     = mmin(ld.lapsMade + 1, MAX_LAPS)
						ld.lastLapTouch = now
						if fld.currentLapStarted and fld.lastStartTime then
							local lapTime = now - fld.lastStartTime
							local isNewBest = not fld.bestTime or lapTime < fld.bestTime
							if isNewBest then
								fld.bestTime = lapTime
								-- [SDE_INFI · Broadcast] Animación vuelta rápida absoluta
								local row = towerRows[uid]
								if row then
									TweenService:Create(row,
										TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
										{ BackgroundColor3 = C_F1_PURPLE }
									):Play()
									task.delay(7, function()
										if row and row.Parent then
											TweenService:Create(row,
												TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
												{ BackgroundColor3 = C_BG2 }
											):Play()
										end
									end)
								end
							end
						end
						fld.lastStartTime     = now
						fld.currentLapStarted = true
					end
				end
			end
		end

		-- ── Detección Pit In / Pit Out ─────────────────────────────────
		if DETECT_PITS and pitInWall and pitOutWall then
			for _, pl in ipairs(Players:GetPlayers()) do
				ensurePlayerData(pl)
				local uid = pl.UserId
				local pd  = pitData[uid]
				local pos = _getPos(pl)
				if not pos then continue end
				if not FIA_EXCLUDED[uid] then
					-- Entrada boxes (pitInWall): En Pista → En Boxes
					if _wallCross(pitInWall, _pitInSide, uid, pos, DEBOUNCE_TIME) then
						if pd.status == "En Pista" then
							pd.status      = "En Boxes"
							pd.lastPitTouch = tick()
						end
					end
					-- Salida boxes (pitOutWall): En Boxes → En Pista + suma pit
					if _wallCross(pitOutWall, _pitOutSide, uid, pos, DEBOUNCE_TIME) then
						if pd.status == "En Boxes" then
							local now = tick()
							if now - pd.lastPitTouch >= DEBOUNCE_TIME then
								pd.pitStopsMade = mmin(pd.pitStopsMade + 1, MAX_PITS)
								pd.status       = "En Pista"
								pd.lastPitTouch = now
							end
						end
					end
				end
			end
		end

		-- ── Detección Corner Cut (PointToObjectSpace) ──────────────────
		if DETECTCC then
			for id, entry in pairs(ccWaypoints) do
				local wall = entry.wall
				if not wall or not wall.Parent then continue end
				if not lastSeenInCC[id] then lastSeenInCC[id] = {} end
				for _, pl in ipairs(Players:GetPlayers()) do
					local uid = pl.UserId
					local pos = _getPos(pl)
					if not pos then continue end
					local l3    = wall.CFrame:PointToObjectSpace(pos)
					local side  = l3.Z >= 0 and 1 or -1
					local half  = wall.Size
					local inBnd = mabs(l3.X) <= half.X / 2 + 4
					           and mabs(l3.Y) <= half.Y / 2 + 4
					local tr    = lastSeenInCC[id][uid]
					if not tr then
						lastSeenInCC[id][uid] = { side = side, cross = 0 }
						continue
					end
					if inBnd and side ~= tr.side then
						local now = tick()
						local key = tostring(id) .. "_" .. tostring(uid)
						local lastTime = ccDebounce[key] or 0
						if now - lastTime > CCDEBOUNCETIME then
							ccDebounce[key] = now
							if not ccData[uid] then ccData[uid] = { total = 0, history = {} } end
							ccData[uid].total = ccData[uid].total + 1
							local lap     = lapData[uid] and lapData[uid].lapsMade or 0
							local timeStr = os.date("%H:%M:%S")
							table.insert(ccData[uid].history, 1, {
								wpName = entry.name,
								lap    = lap,
								time   = timeStr
							})
							if #ccData[uid].history > 20 then table.remove(ccData[uid].history, 21) end
							showCCNotification("🚫 CORNER CUT — " .. getDisplayName(pl) .. " [" .. entry.name .. "]")
						end
					end
					tr.side = side   -- actualizar siempre (también fuera de bounds)
				end
			end
		end
	end

	task.spawn(function()
		while true do updateGuiLists(); task.wait(0.25) end
	end)

	local cronRunning    = false
	local cronStartTime  = 0
	local cronConnection = nil

	makeSectionHeader(configScroll, "🔔  NOTIFICACIONES", 78)
	mkConfigToggleRow(configScroll, "Mostrar notificaciones",
		function() return NOTIF_ENABLED end,
		function(v) NOTIF_ENABLED = v end, 79)

	makeSectionHeader(configScroll, "⏱  CRONÓMETRO", 80)
	do
		local cronRow = Instance.new("Frame")
		cronRow.Size=UDim2.new(1,0,0,44); cronRow.BackgroundColor3=C_BG2; cronRow.BorderSizePixel=0; cronRow.LayoutOrder=81; cronRow.Parent=configScroll

		local cronBtn = Instance.new("TextButton")
		cronBtn.Size=UDim2.new(0.42,-8,0.72,0); cronBtn.Position=UDim2.new(0,8,0.14,0)
		cronBtn.BackgroundColor3=Color3.fromRGB(0,120,50); cronBtn.Text="▶  INICIAR"
		cronBtn.Font=Enum.Font.GothamBold; cronBtn.TextColor3=C_WHITE; cronBtn.TextSize=12
		cronBtn.BorderSizePixel=0; cronBtn.Parent=cronRow
		local cronBtnC=Instance.new("UICorner"); cronBtnC.CornerRadius=UDim.new(0,3); cronBtnC.Parent=cronBtn

		local cronDisplay=Instance.new("Frame")
		cronDisplay.Size=UDim2.new(0.52,-8,0.72,0); cronDisplay.Position=UDim2.new(0.46,0,0.14,0)
		cronDisplay.BackgroundColor3=Color3.fromRGB(0,0,0); cronDisplay.BorderSizePixel=0; cronDisplay.Parent=cronRow
		local cronDisplayC=Instance.new("UICorner"); cronDisplayC.CornerRadius=UDim.new(0,3); cronDisplayC.Parent=cronDisplay

		local cronLbl=Instance.new("TextLabel")
		cronLbl.Size=UDim2.new(1,0,1,0); cronLbl.BackgroundTransparency=1
		cronLbl.Text="--:--.---"; cronLbl.Font=Enum.Font.GothamBlack
		cronLbl.TextColor3=C_GREEN; cronLbl.TextSize=14; cronLbl.Parent=cronDisplay
		local cronLblP=Instance.new("UIPadding"); cronLblP.PaddingLeft=UDim.new(0,6); cronLblP.Parent=cronDisplay

		cronBtn.MouseButton1Click:Connect(function()
			if not cronRunning then
				cronRunning    = true
				cronStartTime  = tick()
				cronBtn.Text   = "■  DETENER"
				cronBtn.BackgroundColor3 = Color3.fromRGB(160,20,20)
				cronLbl.Text   = "0:00.000"
				cronLbl.TextColor3 = C_YELLOW
				cronConnection = RunService.Heartbeat:Connect(function()
					local e    = tick()-cronStartTime
					local mins = mfloor(e/60)
					local secs = e%60
					cronLbl.Text = sformat("%d:%06.3f",mins,secs)
				end)
			else
				cronRunning = false
				if cronConnection then cronConnection:Disconnect(); cronConnection=nil end
				local e    = tick()-cronStartTime
				local mins = mfloor(e/60)
				local secs = e%60
				cronLbl.Text       = sformat("%d:%06.3f",mins,secs)
				cronLbl.TextColor3 = C_GREEN
				cronBtn.Text       = "▶  INICIAR"
				cronBtn.BackgroundColor3 = Color3.fromRGB(0,120,50)
			end
		end)
	end

	local towerVisible = true
	function toggleHUD()
		towerVisible = not towerVisible
		towerConfig.hudMasterVisible = towerVisible  -- [SPAV4 fix] sincroniza banner/fondo de la torre
		towerContainer.Visible = towerVisible and towerConfig.visible
		lapPanel.Visible       = towerVisible
	end

	floatBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)
	closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.Q then toggleHUD() end
	end)

	Players.PlayerRemoving:Connect(function(pl)
		local uid = pl.UserId
		lapData[uid]=nil; pitData[uid]=nil; fastLapData[uid]=nil
		lastSpeeds[uid]=nil; notifiedPlayers[uid]=nil
		_lapSide[uid]=nil; _pitInSide[uid]=nil; _pitOutSide[uid]=nil
		FIA_EXCLUDED[uid]=nil; customPlayerData[uid]=nil; alertedPlayers[uid]=nil
		_telCache[uid]=nil   -- [SDE_INFI · CAMBIO 2] Invalidar caché de telemetría
		if towerRows[uid] then towerRows[uid]:Destroy(); towerRows[uid]=nil end
		if towerRowData[uid] then towerRowData[uid]=nil end
		if vueltasRowCache[uid] then
			if vueltasRowCache[uid].topRow    then vueltasRowCache[uid].topRow:Destroy()    end
			if vueltasRowCache[uid].btnRow    then vueltasRowCache[uid].btnRow:Destroy()    end
			if vueltasRowCache[uid].lapAdjRow then vueltasRowCache[uid].lapAdjRow:Destroy() end
			vueltasRowCache[uid] = nil
		end
		if boxesRowCache[uid] then boxesRowCache[uid]:Destroy(); boxesRowCache[uid] = nil end
		if fastLapsRowCache[uid] then fastLapsRowCache[uid]:Destroy(); fastLapsRowCache[uid] = nil end

		-- Limpieza CC
		ccData[uid] = nil
		for id, _ in pairs(lastSeenInCC) do if lastSeenInCC[id] then lastSeenInCC[id][uid] = nil end end
		for key, _ in pairs(ccDebounce) do if key:find(tostring(uid)) then ccDebounce[key] = nil end end
	end)
end
_setupUI2()
_setupCollisionDetection()  -- [SPAV4] sistema de choques
_setupAnalysisDetection()    -- [SPAV4] análisis de comportamiento
_setupReplayDetection()      -- [SPAV4] replay de contactos (radio 35 st + buffer 2s)

-- ══════════════════════════════════════════════════════════════
-- ═══  _setupCCUI (Anti Corner Cut UI) ═════════════════════════
-- ══════════════════════════════════════════════════════════════
function _setupCCUI()  -- [SPAV4] global: libera registros del ámbito principal
	local ccGui = Instance.new("ScreenGui")
	ccGui.Name = "SPACCANTICC"
	ccGui.ResetOnSpawn = false
	ccGui.DisplayOrder = 55
	ccGui.Parent = playerGui

	local ccBtn = Instance.new("TextButton")
	ccBtn.Size = UDim2.new(0, 54, 0, 44)
	ccBtn.Position = UDim2.new(0, 14, 0.5, 34) -- Justo debajo de SPA
	ccBtn.BackgroundColor3 = Color3.fromRGB(180, 130, 0)
	ccBtn.Text = "CC"
	ccBtn.TextColor3 = C_WHITE
	ccBtn.Font = Enum.Font.GothamBlack
	ccBtn.TextSize = 13
	ccBtn.BorderSizePixel = 0
	ccBtn.Parent = ccGui
	Instance.new("UICorner", ccBtn).CornerRadius = UDim.new(0, 4)

	local ccBtnLine = Instance.new("Frame")
	ccBtnLine.Size = UDim2.new(1, 0, 0, 3)
	ccBtnLine.Position = UDim2.new(0, 0, 1, -3)
	ccBtnLine.BackgroundColor3 = CCWPCOLOR
	ccBtnLine.BackgroundTransparency = 0.3
	ccBtnLine.BorderSizePixel = 0
	ccBtnLine.Parent = ccBtn

	local ccPanel = Instance.new("Frame")
	ccPanel.Size = UDim2.new(0.6, 0, 0.65, 0)
	ccPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
	ccPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	ccPanel.BackgroundColor3 = C_BG
	ccPanel.BorderSizePixel = 0
	ccPanel.Visible = false
	ccPanel.Parent = ccGui
	Instance.new("UICorner", ccPanel).CornerRadius = UDim.new(0, 6)
	Glass.registerModal(ccPanel)

	local topAccent = Instance.new("Frame")
	topAccent.Size = UDim2.new(1, 0, 0, 3)
	topAccent.BackgroundColor3 = CCWPCOLOR
	topAccent.BorderSizePixel = 0
	topAccent.Parent = ccPanel

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 38)
	titleBar.Position = UDim2.new(0, 0, 0, 3)
	titleBar.BackgroundColor3 = C_BG2
	titleBar.BorderSizePixel = 0
	titleBar.Parent = ccPanel

	local titleTxt = Instance.new("TextLabel")
	titleTxt.Size = UDim2.new(0.75, 0, 1, 0)
	titleTxt.Position = UDim2.new(0, 14, 0, 0)
	titleTxt.BackgroundTransparency = 1
	titleTxt.Text = "SPA ANTI CORNER CUT"
	titleTxt.Font = Enum.Font.GothamBlack
	titleTxt.TextColor3 = CCWPCOLOR
	titleTxt.TextSize = 13
	titleTxt.TextXAlignment = Enum.TextXAlignment.Left
	titleTxt.Parent = titleBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 32, 0, 28)
	closeBtn.Position = UDim2.new(1, -38, 0, 5)
	closeBtn.BackgroundColor3 = C_RED
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = C_WHITE
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = titleBar
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 3)

	local tabNames = {"WP CC", "REGISTROS CC", "CONFIG CC"}
	local tabButtons = {}
	local tabFrames  = {}
	local currentCCTab = "WP CC"

	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(1, 0, 0, 32)
	tabBar.Position = UDim2.new(0, 0, 0, 41)
	tabBar.BackgroundColor3 = C_BG2
	tabBar.BorderSizePixel = 0
	tabBar.Parent = ccPanel

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	local function createScrollList(parent)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Size                 = UDim2.new(1, 0, 1, 0)
		scroll.BackgroundColor3     = C_BG
		scroll.BorderSizePixel      = 0
		scroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
		scroll.ScrollingDirection   = Enum.ScrollingDirection.Y
		scroll.ScrollBarThickness   = 8
		scroll.ScrollBarImageColor3 = CCWPCOLOR
		scroll.ElasticBehavior      = Enum.ElasticBehavior.Always
		scroll.Parent = parent
		local layout = Instance.new("UIListLayout")
		layout.Padding   = UDim.new(0, 2)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent    = scroll
		-- Scroll infinito: AbsoluteContentSize listener
		local function _syncCC()
			scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 24)
		end
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(_syncCC)
		task.defer(_syncCC)
		return scroll
	end

	for i, tabName in ipairs(tabNames) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1/#tabNames, 0, 1, 0)
		btn.BackgroundColor3 = (tabName == currentCCTab) and CCWPCOLOR or C_BG2
		btn.Text = tabName
		btn.TextColor3 = (tabName == currentCCTab) and Color3.fromRGB(0,0,0) or C_GRAY
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		btn.BorderSizePixel = 0
		btn.LayoutOrder = i
		btn.Parent = tabBar
		tabButtons[tabName] = btn

		local indicator = Instance.new("Frame")
		indicator.Name = "Indicator"
		indicator.Size = UDim2.new(1, 0, 0, 2)
		indicator.Position = UDim2.new(0, 0, 1, -2)
		indicator.BackgroundColor3 = (tabName == currentCCTab) and CCWPCOLOR or C_BG2
		indicator.BorderSizePixel = 0
		indicator.Parent = btn

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, -16, 1, -82)
		frame.Position = UDim2.new(0, 8, 0, 74)
		frame.BackgroundTransparency = 1
		frame.Visible = (tabName == currentCCTab)
		frame.Parent = ccPanel
		tabFrames[tabName] = frame
	end

	local wpCCScroll     = createScrollList(tabFrames["WP CC"])
	local regCCScroll    = createScrollList(tabFrames["REGISTROS CC"])
	local configCCScroll = createScrollList(tabFrames["CONFIG CC"])

	local function makeCCSectionHeader(parent, text, order)
		local h = Instance.new("Frame")
		h.Size = UDim2.new(1, 0, 0, 22)
		h.BackgroundColor3 = Color3.fromRGB(100, 80, 0)
		h.BorderSizePixel = 0
		h.LayoutOrder = order
		h.Parent = parent
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -12, 1, 0)
		lbl.Position = UDim2.new(0, 10, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextColor3 = CCWPCOLOR
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = h
	end

	-- Forward declarations
	local buildWpCCList, buildRegCCList, buildConfigCCList

	function buildWpCCList()
		for _, c in ipairs(wpCCScroll:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") or c:IsA("TextButton") then c:Destroy() end end

		local topRow = Instance.new("Frame"); topRow.Size = UDim2.new(1, 0, 0, 48); topRow.BackgroundColor3 = Color3.fromRGB(14, 14, 22); topRow.BorderSizePixel = 0; topRow.LayoutOrder = 0; topRow.Parent = wpCCScroll
		local infoLbl = Instance.new("TextLabel"); infoLbl.Size = UDim2.new(0.62, 0, 1, 0); infoLbl.Position = UDim2.new(0, 10, 0, 0); infoLbl.BackgroundTransparency = 1; infoLbl.Text = "Pon el WP en la curva que quieres vigilar"; infoLbl.Font = Enum.Font.GothamBold; infoLbl.TextColor3 = C_GRAY; infoLbl.TextSize = 11; infoLbl.TextXAlignment = Enum.TextXAlignment.Left; infoLbl.TextWrapped = true; infoLbl.Parent = topRow
		local toggleBtn = Instance.new("TextButton"); toggleBtn.Size = UDim2.new(0.33, -8, 0.65, 0); toggleBtn.Position = UDim2.new(0.65, 0, 0.175, 0); toggleBtn.BackgroundColor3 = DETECTCC and Color3.fromRGB(0, 120, 50) or Color3.fromRGB(80, 20, 20); toggleBtn.Text = DETECTCC and "DETEC: ON" or "DETEC: OFF"; toggleBtn.Font = Enum.Font.GothamBold; toggleBtn.TextColor3 = DETECTCC and C_GREEN or Color3.fromRGB(255, 80, 80); toggleBtn.TextSize = 10; toggleBtn.BorderSizePixel = 0; toggleBtn.Parent = topRow; Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 3)

		toggleBtn.MouseButton1Click:Connect(function()
			DETECTCC = not DETECTCC
			toggleBtn.BackgroundColor3 = DETECTCC and Color3.fromRGB(0, 120, 50) or Color3.fromRGB(80, 20, 20)
			toggleBtn.Text = DETECTCC and "DETEC: ON" or "DETEC: OFF"
			toggleBtn.TextColor3 = DETECTCC and C_GREEN or Color3.fromRGB(255, 80, 80)
		end)

		makeCCSectionHeader(wpCCScroll, "AGREGAR WAYPOINT CORNER CUT", 1)
		local addRow = Instance.new("Frame"); addRow.Size = UDim2.new(1, 0, 0, 130); addRow.BackgroundColor3 = C_BG2; addRow.BorderSizePixel = 0; addRow.LayoutOrder = 2; addRow.Parent = wpCCScroll
		local nameBox = Instance.new("TextBox"); nameBox.Size = UDim2.new(0.52, -8, 0, 26); nameBox.Position = UDim2.new(0, 8, 0, 6); nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 45); nameBox.BorderSizePixel = 0; nameBox.Font = Enum.Font.GothamBold; nameBox.TextColor3 = C_YELLOW; nameBox.TextSize = 12; nameBox.Text = ""; nameBox.PlaceholderText = "Nombre curva (ej. Curva 3)"; nameBox.ClearTextOnFocus = false; nameBox.TextXAlignment = Enum.TextXAlignment.Left; nameBox.Parent = addRow; Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 3); local nbp = Instance.new("UIPadding"); nbp.PaddingLeft = UDim.new(0, 6); nbp.Parent = nameBox
		local setBtn = Instance.new("TextButton"); setBtn.Size = UDim2.new(0.44, -8, 0, 26); setBtn.Position = UDim2.new(0.54, 0, 0, 6); setBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 160); setBtn.Text = "SET WP CC"; setBtn.Font = Enum.Font.GothamBold; setBtn.TextColor3 = C_WHITE; setBtn.TextSize = 11; setBtn.BorderSizePixel = 0; setBtn.Parent = addRow; Instance.new("UICorner", setBtn).CornerRadius = UDim.new(0, 3)

		local function makeSliderRow(labelText, getVal, setVal, minV, maxV, yPos)
			local sliderLbl = Instance.new("TextLabel"); sliderLbl.Size = UDim2.new(0.26, 0, 0, 20); sliderLbl.Position = UDim2.new(0, 8, 0, yPos); sliderLbl.BackgroundTransparency = 1; sliderLbl.Text = labelText; sliderLbl.Font = Enum.Font.GothamBold; sliderLbl.TextColor3 = C_GRAY; sliderLbl.TextSize = 10; sliderLbl.TextXAlignment = Enum.TextXAlignment.Left; sliderLbl.Parent = addRow
			local minusBtn = Instance.new("TextButton"); minusBtn.Size = UDim2.new(0, 22, 0, 20); minusBtn.Position = UDim2.new(0.27, 0, 0, yPos); minusBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 0); minusBtn.Text = "-"; minusBtn.Font = Enum.Font.GothamBlack; minusBtn.TextColor3 = C_YELLOW; minusBtn.TextSize = 14; minusBtn.BorderSizePixel = 0; minusBtn.Parent = addRow; Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(0, 3)
			local valLbl = Instance.new("TextLabel"); valLbl.Size = UDim2.new(0.17, 0, 0, 20); valLbl.Position = UDim2.new(0.27, 26, 0, yPos); valLbl.BackgroundColor3 = Color3.fromRGB(20, 20, 32); valLbl.BorderSizePixel = 0; valLbl.Text = tostring(getVal()); valLbl.Font = Enum.Font.GothamBlack; valLbl.TextColor3 = C_WHITE; valLbl.TextSize = 11; valLbl.TextXAlignment = Enum.TextXAlignment.Center; valLbl.Parent = addRow; Instance.new("UICorner", valLbl).CornerRadius = UDim.new(0, 3)
			local plusBtn = Instance.new("TextButton"); plusBtn.Size = UDim2.new(0, 22, 0, 20); plusBtn.Position = UDim2.new(0.27, 62, 0, yPos); plusBtn.BackgroundColor3 = Color3.fromRGB(0, 70, 30); plusBtn.Text = "+"; plusBtn.Font = Enum.Font.GothamBlack; plusBtn.TextColor3 = C_GREEN; plusBtn.TextSize = 14; plusBtn.BorderSizePixel = 0; plusBtn.Parent = addRow; Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(0, 3)
			local notaLbl2 = Instance.new("TextLabel"); notaLbl2.Size = UDim2.new(0.42, -4, 0, 20); notaLbl2.Position = UDim2.new(0.57, 4, 0, yPos); notaLbl2.BackgroundTransparency = 1; notaLbl2.Text = "studs"; notaLbl2.Font = Enum.Font.GothamBold; notaLbl2.TextColor3 = Color3.fromRGB(80, 70, 40); notaLbl2.TextSize = 10; notaLbl2.TextXAlignment = Enum.TextXAlignment.Left; notaLbl2.Parent = addRow
			local step = math.max(1, math.ceil((maxV - minV) / 20))
			minusBtn.MouseButton1Click:Connect(function() setVal(math.max(minV, getVal() - step)); valLbl.Text = tostring(getVal()) end)
			plusBtn.MouseButton1Click:Connect(function() setVal(math.min(maxV, getVal() + step)); valLbl.Text = tostring(getVal()) end)
		end

		makeSliderRow("ANCHO:", function() return CCWPWIDTH end, function(v) CCWPWIDTH=v end, 20, 500, 40)
		makeSliderRow("ALTO:", function() return CCWPHEIGHT end, function(v) CCWPHEIGHT=v end, 10, 400, 65)
		makeSliderRow("GROSOR:", function() return CCWPTHICKNESS end, function(v) CCWPTHICKNESS=v end, 2, 50, 90)

		local notaGeneral = Instance.new("TextLabel"); notaGeneral.Size = UDim2.new(1, -12, 0, 16); notaGeneral.Position = UDim2.new(0, 8, 0, 112); notaGeneral.BackgroundTransparency = 1; notaGeneral.Text = "* Los valores se aplican al siguiente WP que pongas"; notaGeneral.Font = Enum.Font.GothamBold; notaGeneral.TextColor3 = Color3.fromRGB(90, 80, 40); notaGeneral.TextSize = 9; notaGeneral.TextXAlignment = Enum.TextXAlignment.Left; notaGeneral.Parent = addRow

		setBtn.MouseButton1Click:Connect(function()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root then return end
			local wpName = nameBox.Text ~= "" and nameBox.Text or ("WP_CC_" .. (ccWpCounter + 1))
			ccWpCounter = ccWpCounter + 1
			local id = ccWpCounter
			local wall = createCCWall(id, wpName, root.CFrame)
			ccWaypoints[id] = { name = wpName, wall = wall }
			lastSeenInCC[id] = {}
			nameBox.Text = ""
			buildWpCCList()
		end)

		local count = 0
		for _ in pairs(ccWaypoints) do count = count + 1 end
		makeCCSectionHeader(wpCCScroll, count == 0 and "WAYPOINTS ACTIVOS (ninguno)" or ("WAYPOINTS ACTIVOS (" .. count .. ")"), 3)

		if count > 0 then
			local order = 10
			for id, entry in pairs(ccWaypoints) do
				local row = Instance.new("Frame"); row.Size = UDim2.new(1, 0, 0, 38); row.BackgroundColor3 = C_BG2; row.BorderSizePixel = 0; row.LayoutOrder = order; row.Parent = wpCCScroll; order = order + 1
				local sideBar = Instance.new("Frame"); sideBar.Size = UDim2.new(0, 4, 1, 0); sideBar.BackgroundColor3 = CCWPCOLOR; sideBar.BorderSizePixel = 0; sideBar.Parent = row
				local iconLbl = Instance.new("TextLabel"); iconLbl.Size = UDim2.new(0, 28, 1, 0); iconLbl.Position = UDim2.new(0, 8, 0, 0); iconLbl.BackgroundTransparency = 1; iconLbl.Text = "📍"; iconLbl.TextScaled = true; iconLbl.Font = Enum.Font.GothamBold; iconLbl.TextColor3 = CCWPCOLOR; iconLbl.Parent = row
				local nameLbl = Instance.new("TextLabel"); nameLbl.Size = UDim2.new(0.55, 0, 1, 0); nameLbl.Position = UDim2.new(0, 42, 0, 0); nameLbl.BackgroundTransparency = 1; nameLbl.Text = entry.name; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextColor3 = C_WHITE; nameLbl.TextSize = 12; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Parent = row
				local idLbl = Instance.new("TextLabel"); idLbl.Size = UDim2.new(0.12, 0, 1, 0); idLbl.Position = UDim2.new(0.57, 0, 0, 0); idLbl.BackgroundTransparency = 1; idLbl.Text = "#" .. id; idLbl.Font = Enum.Font.GothamBold; idLbl.TextColor3 = C_GRAY; idLbl.TextSize = 10; idLbl.TextXAlignment = Enum.TextXAlignment.Center; idLbl.Parent = row
				local quitarBtn = Instance.new("TextButton"); quitarBtn.Size = UDim2.new(0.26, -8, 0.7, 0); quitarBtn.Position = UDim2.new(0.72, 0, 0.15, 0); quitarBtn.BackgroundColor3 = C_DARKRED; quitarBtn.Text = "✕ QUITAR"; quitarBtn.Font = Enum.Font.GothamBold; quitarBtn.TextColor3 = C_WHITE; quitarBtn.TextSize = 10; quitarBtn.BorderSizePixel = 0; quitarBtn.Parent = row; Instance.new("UICorner", quitarBtn).CornerRadius = UDim.new(0, 3)

				local capturedId = id
				quitarBtn.MouseButton1Click:Connect(function() removeCCWall(capturedId); buildWpCCList() end)
			end
		end

		local clearRow = Instance.new("Frame"); clearRow.Size = UDim2.new(1, 0, 0, 38); clearRow.BackgroundColor3 = C_BG; clearRow.BorderSizePixel = 0; clearRow.LayoutOrder = 999; clearRow.Parent = wpCCScroll
		local clearBtn = Instance.new("TextButton"); clearBtn.Size = UDim2.new(1, -16, 0.75, 0); clearBtn.Position = UDim2.new(0, 8, 0.125, 0); clearBtn.BackgroundColor3 = C_DARKRED; clearBtn.Text = "🗑 QUITAR TODOS LOS WP CC"; clearBtn.Font = Enum.Font.GothamBlack; clearBtn.TextColor3 = C_WHITE; clearBtn.TextSize = 11; clearBtn.BorderSizePixel = 0; clearBtn.Parent = clearRow; Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 3)
		clearBtn.MouseButton1Click:Connect(function() for id, _ in pairs(ccWaypoints) do removeCCWall(id) end; buildWpCCList() end)
	end

	function buildRegCCList()
		for _, c in ipairs(regCCScroll:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") or c:IsA("TextButton") then c:Destroy() end end
		makeCCSectionHeader(regCCScroll, "REGISTRO DE CORNER CUTS POR PILOTO", 0)

		local allPlayers = Players:GetPlayers()
		if #allPlayers == 0 then
			local emptyLbl = Instance.new("TextLabel"); emptyLbl.Size = UDim2.new(1, 0, 0, 40); emptyLbl.BackgroundTransparency = 1; emptyLbl.Text = "No hay jugadores en el servidor"; emptyLbl.TextColor3 = C_GRAY; emptyLbl.Font = Enum.Font.GothamBold; emptyLbl.TextSize = 13; emptyLbl.LayoutOrder = 1; emptyLbl.Parent = regCCScroll
			return
		end

		local order = 1
		for _, pl in ipairs(allPlayers) do
			local uid = pl.UserId
			local data = ccData[uid] or { total = 0, history = {} }
			local total = data.total
			local displayName = getDisplayName(pl)

			local row = Instance.new("Frame"); row.Size = UDim2.new(1, 0, 0, 40); row.BackgroundColor3 = total > 0 and Color3.fromRGB(20, 15, 5) or C_BG2; row.BorderSizePixel = 0; row.LayoutOrder = order; row.Parent = regCCScroll; order = order + 1
			local sideBar = Instance.new("Frame"); sideBar.Size = UDim2.new(0, 4, 1, 0); sideBar.BackgroundColor3 = total > 0 and CCWPCOLOR or C_GRAY; sideBar.BorderSizePixel = 0; sideBar.Parent = row
			local nameLbl = Instance.new("TextLabel"); nameLbl.Size = UDim2.new(0.5, 0, 1, 0); nameLbl.Position = UDim2.new(0, 14, 0, 0); nameLbl.BackgroundTransparency = 1; nameLbl.Text = displayName; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextColor3 = total > 0 and C_YELLOW or C_WHITE; nameLbl.TextSize = 12; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Parent = row
			local countLbl = Instance.new("TextLabel"); countLbl.Size = UDim2.new(0.2, 0, 1, 0); countLbl.Position = UDim2.new(0.5, 0, 0, 0); countLbl.BackgroundTransparency = 1; countLbl.Text = total > 0 and ("⚠️ x" .. total) or "✔ 0"; countLbl.Font = Enum.Font.GothamBlack; countLbl.TextColor3 = total > 0 and CCWPCOLOR or C_GREEN; countLbl.TextSize = 13; countLbl.Parent = row
			local resetBtn = Instance.new("TextButton"); resetBtn.Size = UDim2.new(0.24, -8, 0.65, 0); resetBtn.Position = UDim2.new(0.74, 0, 0.175, 0); resetBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 0); resetBtn.Text = "RESET"; resetBtn.Font = Enum.Font.GothamBold; resetBtn.TextColor3 = C_YELLOW; resetBtn.TextSize = 10; resetBtn.BorderSizePixel = 0; resetBtn.Parent = row; Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 3)

			local capturedUid = uid
			resetBtn.MouseButton1Click:Connect(function() ccData[capturedUid] = { total = 0, history = {} }; buildRegCCList() end)

			if total > 0 and #data.history > 0 then
				for hi, entry in ipairs(data.history) do
					if hi > 10 then break end
					local histRow = Instance.new("Frame"); histRow.Size = UDim2.new(1, 0, 0, 24); histRow.BackgroundColor3 = Color3.fromRGB(12, 10, 3); histRow.BorderSizePixel = 0; histRow.LayoutOrder = order; histRow.Parent = regCCScroll; order = order + 1
					local indent = Instance.new("Frame"); indent.Size = UDim2.new(0, 2, 1, 0); indent.Position = UDim2.new(0, 12, 0, 0); indent.BackgroundColor3 = CCWPCOLOR; indent.BackgroundTransparency = 0.6; indent.BorderSizePixel = 0; indent.Parent = histRow
					local histLbl = Instance.new("TextLabel"); histLbl.Size = UDim2.new(1, -24, 1, 0); histLbl.Position = UDim2.new(0, 22, 0, 0); histLbl.BackgroundTransparency = 1; histLbl.Text = entry.time .. "  |  " .. entry.wpName .. "  |  LAP " .. entry.lap; histLbl.Font = Enum.Font.GothamBold; histLbl.TextColor3 = C_GRAY; histLbl.TextSize = 10; histLbl.TextXAlignment = Enum.TextXAlignment.Left; histLbl.Parent = histRow
				end
				local sep = Instance.new("Frame"); sep.Size = UDim2.new(1, 0, 0, 4); sep.BackgroundColor3 = Color3.fromRGB(40, 30, 0); sep.BorderSizePixel = 0; sep.LayoutOrder = order; sep.Parent = regCCScroll; order = order + 1
			end
		end

		local clearRow = Instance.new("Frame"); clearRow.Size = UDim2.new(1, 0, 0, 38); clearRow.BackgroundColor3 = C_BG; clearRow.BorderSizePixel = 0; clearRow.LayoutOrder = 9999; clearRow.Parent = regCCScroll
		local clearAllBtn = Instance.new("TextButton"); clearAllBtn.Size = UDim2.new(1, -16, 0.75, 0); clearAllBtn.Position = UDim2.new(0, 8, 0.125, 0); clearAllBtn.BackgroundColor3 = C_DARKRED; clearAllBtn.Text = "🗑 RESETEAR TODOS LOS REGISTROS CC"; clearAllBtn.Font = Enum.Font.GothamBlack; clearAllBtn.TextColor3 = C_WHITE; clearAllBtn.TextSize = 11; clearAllBtn.BorderSizePixel = 0; clearAllBtn.Parent = clearRow; Instance.new("UICorner", clearAllBtn).CornerRadius = UDim.new(0, 3)
		clearAllBtn.MouseButton1Click:Connect(function() for uid, _ in pairs(ccData) do ccData[uid] = { total = 0, history = {} } end; buildRegCCList() end)
	end

	function buildConfigCCList()
		for _, c in ipairs(configCCScroll:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") or c:IsA("TextButton") then c:Destroy() end end
		makeCCSectionHeader(configCCScroll, "⚙  CONFIGURACIÓN ANTI CORNER CUT", 0)

		local function makeToggleRow(parent, labelText, getVal, setVal, order)
			local row = Instance.new("Frame"); row.Size = UDim2.new(1, 0, 0, 34); row.BackgroundColor3 = C_BG2; row.BorderSizePixel = 0; row.LayoutOrder = order; row.Parent = parent
			local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(0.62, 0, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0); lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = C_WHITE; lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row
			local togBtn = Instance.new("TextButton"); togBtn.Size = UDim2.new(0.33, -8, 0.65, 0); togBtn.Position = UDim2.new(0.65, 0, 0.175, 0); togBtn.BorderSizePixel = 0; togBtn.Font = Enum.Font.GothamBold; togBtn.TextSize = 11; togBtn.Parent = row; Instance.new("UICorner", togBtn).CornerRadius = UDim.new(0, 3)
			local function refresh() local v = getVal(); togBtn.BackgroundColor3 = v and Color3.fromRGB(0,120,50) or Color3.fromRGB(80,20,20); togBtn.TextColor3 = v and C_GREEN or Color3.fromRGB(255,80,80); togBtn.Text = v and "ON" or "OFF" end
			refresh(); togBtn.MouseButton1Click:Connect(function() setVal(not getVal()); refresh() end)
		end

		local function makeAdjustRow(parent, labelText, getVal, setVal, step, minV, maxV, onChange, order)
			local row = Instance.new("Frame"); row.Size = UDim2.new(1, 0, 0, 34); row.BackgroundColor3 = C_BG2; row.BorderSizePixel = 0; row.LayoutOrder = order; row.Parent = parent
			local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(0.42, 0, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0); lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = C_WHITE; lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row
			local minusBtn = Instance.new("TextButton"); minusBtn.Size = UDim2.new(0, 28, 0.7, 0); minusBtn.Position = UDim2.new(0.44, 0, 0.15, 0); minusBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 0); minusBtn.Text = "-"; minusBtn.Font = Enum.Font.GothamBlack; minusBtn.TextColor3 = C_YELLOW; minusBtn.TextSize = 16; minusBtn.BorderSizePixel = 0; minusBtn.Parent = row; Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(0, 3)
			local valLbl = Instance.new("TextLabel"); valLbl.Size = UDim2.new(0.2, 0, 0.7, 0); valLbl.Position = UDim2.new(0.44, 32, 0.15, 0); valLbl.BackgroundColor3 = Color3.fromRGB(20, 20, 32); valLbl.BorderSizePixel = 0; valLbl.Text = tostring(getVal()); valLbl.Font = Enum.Font.GothamBlack; valLbl.TextColor3 = C_WHITE; valLbl.TextSize = 12; valLbl.TextXAlignment = Enum.TextXAlignment.Center; valLbl.Parent = row; Instance.new("UICorner", valLbl).CornerRadius = UDim.new(0, 3)
			local plusBtn = Instance.new("TextButton"); plusBtn.Size = UDim2.new(0, 28, 0.7, 0); plusBtn.Position = UDim2.new(0.65, 4, 0.15, 0); plusBtn.BackgroundColor3 = Color3.fromRGB(0, 70, 30); plusBtn.Text = "+"; plusBtn.Font = Enum.Font.GothamBlack; plusBtn.TextColor3 = C_GREEN; plusBtn.TextSize = 16; plusBtn.BorderSizePixel = 0; plusBtn.Parent = row; Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(0, 3)
			local studsLbl = Instance.new("TextLabel"); studsLbl.Size = UDim2.new(0.28, -8, 1, 0); studsLbl.Position = UDim2.new(0.71, 0, 0, 0); studsLbl.BackgroundTransparency = 1; studsLbl.Text = "studs"; studsLbl.Font = Enum.Font.GothamBold; studsLbl.TextColor3 = Color3.fromRGB(80, 70, 40); studsLbl.TextSize = 10; studsLbl.TextXAlignment = Enum.TextXAlignment.Left; studsLbl.Parent = row
			minusBtn.MouseButton1Click:Connect(function() setVal(math.max(minV, getVal() - step)); valLbl.Text = tostring(getVal()); if onChange then onChange() end end)
			plusBtn.MouseButton1Click:Connect(function() setVal(math.min(maxV, getVal() + step)); valLbl.Text = tostring(getVal()); if onChange then onChange() end end)
		end

		makeToggleRow(configCCScroll, "Detección CC activa", function() return DETECTCC end, function(v) DETECTCC = v end, 1)
		makeToggleRow(configCCScroll, "👁  Mostrar WP CC", function() return SHOW_WAYPOINTS_CC end, function(v) SHOW_WAYPOINTS_CC = v; applyWPVisibilityCC() end, 2)
		makeCCSectionHeader(configCCScroll, "⏱  DEBOUNCE (seg entre detecciones)", 3)
		makeAdjustRow(configCCScroll, "Tiempo debounce", function() return CCDEBOUNCETIME end, function(v) CCDEBOUNCETIME = v end, 1, 1, 30, nil, 4)
		makeCCSectionHeader(configCCScroll, "📐  TAMAÑO WP POR DEFECTO", 5)
		makeAdjustRow(configCCScroll, "Ancho WP", function() return CCWPWIDTH end, function(v) CCWPWIDTH = v end, 5, 20, 500, nil, 6)
		makeAdjustRow(configCCScroll, "Alto WP", function() return CCWPHEIGHT end, function(v) CCWPHEIGHT = v end, 5, 10, 400, nil, 7)
		makeAdjustRow(configCCScroll, "Grosor WP", function() return CCWPTHICKNESS end, function(v) CCWPTHICKNESS = v end, 1, 2, 50, nil, 8)

		local notaRow = Instance.new("Frame"); notaRow.Size = UDim2.new(1, 0, 0, 28); notaRow.BackgroundColor3 = Color3.fromRGB(30, 25, 5); notaRow.BorderSizePixel = 0; notaRow.LayoutOrder = 9; notaRow.Parent = configCCScroll
		local notaLbl = Instance.new("TextLabel"); notaLbl.Size = UDim2.new(1, -12, 1, 0); notaLbl.Position = UDim2.new(0, 10, 0, 0); notaLbl.BackgroundTransparency = 1; notaLbl.Text = "ℹ  Los valores de tamaño aplican a nuevos WPs"; notaLbl.Font = Enum.Font.GothamBold; notaLbl.TextColor3 = Color3.fromRGB(140, 120, 50); notaLbl.TextSize = 10; notaLbl.TextXAlignment = Enum.TextXAlignment.Left; notaLbl.Parent = notaRow
	end

	for _, btn in pairs(tabButtons) do
		btn.MouseButton1Click:Connect(function()
			currentCCTab = btn.Text
			for name, f in pairs(tabFrames) do
				local isActive = (name == currentCCTab)
				f.Visible = isActive
				tabButtons[name].BackgroundColor3 = isActive and CCWPCOLOR or C_BG2
				tabButtons[name].TextColor3 = isActive and Color3.fromRGB(0,0,0) or C_GRAY
				local ind = tabButtons[name]:FindFirstChild("Indicator")
				if ind then ind.BackgroundColor3 = isActive and CCWPCOLOR or C_BG2 end
			end
			if currentCCTab == "WP CC" then buildWpCCList() elseif currentCCTab == "REGISTROS CC" then buildRegCCList() elseif currentCCTab == "CONFIG CC" then buildConfigCCList() end
		end)
	end

	ccBtn.MouseButton1Click:Connect(function()
		ccPanel.Visible = not ccPanel.Visible
		if ccPanel.Visible then
			if currentCCTab == "WP CC" then buildWpCCList() elseif currentCCTab == "REGISTROS CC" then buildRegCCList() elseif currentCCTab == "CONFIG CC" then buildConfigCCList() end
		end
	end)

	closeBtn.MouseButton1Click:Connect(function() ccPanel.Visible = false end)

	task.spawn(function()
		while true do
			task.wait(1)
			if ccPanel.Visible and currentCCTab == "REGISTROS CC" then buildRegCCList() end
		end
	end)

	buildWpCCList()
end

_setupCCUI()

-- ════════════════════════════════════════════════════════════════
-- ███  _setupTireSystem — Pestaña LLANTAS + detección compuesto  ██
-- ════════════════════════════════════════════════════════════════
function _setupTireSystem()
	local tireFrame = tabFrames["LLANTAS"]
	if not tireFrame then return end

	-- ── Scroll principal ────────────────────────────────────────
	local tireScroll = Instance.new("ScrollingFrame")
	tireScroll.Size                 = UDim2.new(1, 0, 1, 0)
	tireScroll.BackgroundColor3     = C_BG
	tireScroll.BorderSizePixel      = 0
	tireScroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
	tireScroll.ScrollingDirection   = Enum.ScrollingDirection.Y
	tireScroll.ScrollBarThickness   = 10
	tireScroll.ScrollBarImageColor3 = C_ORANGE
	tireScroll.ElasticBehavior      = Enum.ElasticBehavior.Always
	tireScroll.Parent               = tireFrame

	local tireLayout = Instance.new("UIListLayout")
	tireLayout.Padding   = UDim.new(0, 2)
	tireLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tireLayout.Parent    = tireScroll

	local function _syncTire()
		tireScroll.CanvasSize = UDim2.new(0, 0, 0, tireLayout.AbsoluteContentSize.Y + 24)
	end
	tireLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(_syncTire)
	task.defer(_syncTire)

	-- ── Orden visual de compuestos en el selector ───────────────
	local TIRE_ORDER = { "SUPER BLANDA", "BLANDA", "MEDIA", "DURA", "INTERMEDIA", "FULL WET" }
	local tireByName = {}
	for id, cpd in pairs(SPA_Tires.COMPOUNDS) do tireByName[cpd.name] = cpd end

	-- ── UI rebuild ──────────────────────────────────────────────
	local function rebuildTireUI()
		for _, c in ipairs(tireScroll:GetChildren()) do
			if not c:IsA("UIListLayout") then c:Destroy() end
		end

		-- Sección: estado actual ─────────────────────────────────
		local hdrCur = Instance.new("Frame")
		hdrCur.Size = UDim2.new(1, 0, 0, 22); hdrCur.BackgroundColor3 = Color3.fromRGB(0, 40, 80)
		hdrCur.BorderSizePixel = 0; hdrCur.LayoutOrder = 0; hdrCur.Parent = tireScroll
		local hdrCurLbl = Instance.new("TextLabel")
		hdrCurLbl.Size = UDim2.new(1, -12, 1, 0); hdrCurLbl.Position = UDim2.new(0, 10, 0, 0)
		hdrCurLbl.BackgroundTransparency = 1; hdrCurLbl.Text = "🏎  COMPUESTO ACTUAL POR PILOTO"
		hdrCurLbl.Font = Enum.Font.GothamBlack; hdrCurLbl.TextColor3 = Color3.fromRGB(100, 180, 255)
		hdrCurLbl.TextSize = 11; hdrCurLbl.TextXAlignment = Enum.TextXAlignment.Left; hdrCurLbl.Parent = hdrCur

		local allPl = Players:GetPlayers()
		for i, p in ipairs(allPl) do
			local uid    = p.UserId
			local cur    = SPA_Tires.current[uid]
			local inPit  = pitData[uid] and pitData[uid].status == "En Boxes"

			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 44); row.BackgroundColor3 = i%2==0 and C_BG2 or C_BG
			row.BackgroundTransparency = 0.1; row.BorderSizePixel = 0; row.LayoutOrder = i; row.Parent = tireScroll

			local sideBar = Instance.new("Frame")
			sideBar.Size = UDim2.new(0, 4, 1, 0); sideBar.BackgroundColor3 = cur and cur.color or C_GRAY
			sideBar.BorderSizePixel = 0; sideBar.Parent = row

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(0.34, 0, 1, 0); nameLbl.Position = UDim2.new(0, 14, 0, 0)
			nameLbl.BackgroundTransparency = 1; nameLbl.Text = getDisplayName(p)
			nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextColor3 = getNameColor(p)
			nameLbl.TextSize = 12; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Parent = row

			local pitLbl = Instance.new("TextLabel")
			pitLbl.Size = UDim2.new(0.18, 0, 1, 0); pitLbl.Position = UDim2.new(0.34, 0, 0, 0)
			pitLbl.BackgroundTransparency = 1; pitLbl.Text = inPit and "🔧 PIT" or "🏁 PISTA"
			pitLbl.Font = Enum.Font.GothamBold; pitLbl.TextColor3 = inPit and C_ORANGE or C_GREEN
			pitLbl.TextSize = 11; pitLbl.TextXAlignment = Enum.TextXAlignment.Center; pitLbl.Parent = row

			local cpIcon = Instance.new("TextLabel")
			cpIcon.Size = UDim2.new(0, 22, 1, 0); cpIcon.Position = UDim2.new(0.52, 0, 0, 0)
			cpIcon.BackgroundTransparency = 1; cpIcon.Text = cur and cur.icon or "❓"
			cpIcon.Font = Enum.Font.GothamBold; cpIcon.TextScaled = true; cpIcon.Parent = row

			local cpLbl = Instance.new("TextLabel")
			cpLbl.Size = UDim2.new(0.25, 0, 1, 0); cpLbl.Position = UDim2.new(0.57, 0, 0, 0)
			cpLbl.BackgroundTransparency = 1; cpLbl.Text = cur and cur.name or "SIN DATOS"
			cpLbl.Font = Enum.Font.GothamBlack; cpLbl.TextColor3 = cur and cur.color or C_GRAY
			cpLbl.TextSize = 12; cpLbl.TextXAlignment = Enum.TextXAlignment.Left; cpLbl.Parent = row

			-- Botón SET (solo en pit): abre selector de compuesto
			if inPit then
				local setBtn = Instance.new("TextButton")
				setBtn.Size = UDim2.new(0.12, -4, 0.7, 0); setBtn.Position = UDim2.new(0.87, 0, 0.15, 0)
				setBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 160); setBtn.Text = "SET"
				setBtn.Font = Enum.Font.GothamBold; setBtn.TextColor3 = C_WHITE
				setBtn.TextSize = 10; setBtn.BorderSizePixel = 0; setBtn.Parent = row
				Instance.new("UICorner", setBtn).CornerRadius = UDim.new(0, 3)

				local captP, captUid = p, uid
				setBtn.MouseButton1Click:Connect(function()
					-- destruir selector previo si existe
					local prev = tireFrame:FindFirstChild("TireSel_"..captUid)
					if prev then prev:Destroy(); return end

					local sel = Instance.new("Frame")
					sel.Name = "TireSel_"..captUid
					sel.Size = UDim2.new(0, 220, 0, 30 + #TIRE_ORDER * 34)
					sel.Position = UDim2.new(0.5, -110, 0, 48)
					sel.BackgroundColor3 = C_BG2; sel.BackgroundTransparency = 0.05
					sel.BorderSizePixel = 0; sel.ZIndex = 20; sel.Parent = tireFrame
					Instance.new("UICorner", sel).CornerRadius = UDim.new(0, 8)
					Glass.registerModal(sel)

					local selHdr = Instance.new("TextLabel")
					selHdr.Size = UDim2.new(1, 0, 0, 28); selHdr.BackgroundColor3 = C_RED
					selHdr.BackgroundTransparency = 0; selHdr.BorderSizePixel = 0
					selHdr.Text = "🔧 CAMBIO LLANTA — " .. getDisplayName(captP)
					selHdr.Font = Enum.Font.GothamBold; selHdr.TextColor3 = C_WHITE
					selHdr.TextSize = 10; selHdr.ZIndex = 21; selHdr.Parent = sel
					Instance.new("UICorner", selHdr).CornerRadius = UDim.new(0, 8)

					for idx, cname in ipairs(TIRE_ORDER) do
						local cpd = tireByName[cname]
						if not cpd then continue end
						local btn2 = Instance.new("TextButton")
						btn2.Size = UDim2.new(1, 0, 0, 32)
						btn2.Position = UDim2.new(0, 0, 0, 28 + (idx-1)*34)
						btn2.BackgroundColor3 = cpd.color; btn2.BackgroundTransparency = 0.75
						btn2.Text = cpd.icon .. "  " .. cpd.name
						btn2.Font = Enum.Font.GothamBlack; btn2.TextColor3 = cpd.color
						btn2.TextSize = 12; btn2.BorderSizePixel = 0; btn2.ZIndex = 21; btn2.Parent = sel

						local captCpd = cpd
						btn2.MouseButton1Click:Connect(function()
							local oldCpd = SPA_Tires.current[captUid]
							if not oldCpd or oldCpd.name ~= captCpd.name then
								SPA_Tires.current[captUid] = captCpd
								local isInPit = pitData[captUid] and pitData[captUid].status == "En Boxes"
								_tirLogChange(captP, oldCpd, captCpd, isInPit)
							end
							sel:Destroy()
						end)
					end

					local closeSelBtn = Instance.new("TextButton")
					closeSelBtn.Size = UDim2.new(0, 22, 0, 22)
					closeSelBtn.Position = UDim2.new(1, -24, 0, 3)
					closeSelBtn.BackgroundColor3 = C_DARKRED; closeSelBtn.Text = "✕"
					closeSelBtn.Font = Enum.Font.GothamBold; closeSelBtn.TextColor3 = C_WHITE
					closeSelBtn.TextSize = 11; closeSelBtn.BorderSizePixel = 0
					closeSelBtn.ZIndex = 22; closeSelBtn.Parent = sel
					Instance.new("UICorner", closeSelBtn).CornerRadius = UDim.new(0, 4)
					closeSelBtn.MouseButton1Click:Connect(function() sel:Destroy() end)
				end)
			end
		end

		-- Sección: historial ─────────────────────────────────────
		local hdrHist = Instance.new("Frame")
		hdrHist.Size = UDim2.new(1, 0, 0, 22); hdrHist.BackgroundColor3 = Color3.fromRGB(60, 35, 0)
		hdrHist.BorderSizePixel = 0; hdrHist.LayoutOrder = 100; hdrHist.Parent = tireScroll
		local hdrHistLbl = Instance.new("TextLabel")
		hdrHistLbl.Size = UDim2.new(1, -12, 1, 0); hdrHistLbl.Position = UDim2.new(0, 10, 0, 0)
		hdrHistLbl.BackgroundTransparency = 1
		hdrHistLbl.Text = "📋  HISTORIAL DE CAMBIOS (" .. #SPA_Tires.log .. ")"
		hdrHistLbl.Font = Enum.Font.GothamBlack; hdrHistLbl.TextColor3 = C_ORANGE
		hdrHistLbl.TextSize = 11; hdrHistLbl.TextXAlignment = Enum.TextXAlignment.Left; hdrHistLbl.Parent = hdrHist

		if #SPA_Tires.log == 0 then
			local noHist = Instance.new("TextLabel")
			noHist.Size = UDim2.new(1, 0, 0, 40); noHist.BackgroundTransparency = 1
			noHist.Text = "Sin cambios registrados aún"; noHist.Font = Enum.Font.GothamBold
			noHist.TextColor3 = C_GRAY; noHist.TextSize = 12; noHist.LayoutOrder = 101; noHist.Parent = tireScroll
		end

		for idx, entry in ipairs(SPA_Tires.log) do
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, 0, 0, 54)
			card.BackgroundColor3 = idx%2==0 and C_BG2 or C_BG
			card.BackgroundTransparency = 0.12; card.BorderSizePixel = 0
			card.LayoutOrder = 100 + idx; card.Parent = tireScroll

			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(0, 4, 1, 0); bar.BackgroundColor3 = entry.newColor
			bar.BorderSizePixel = 0; bar.Parent = card

			local timeLbl = Instance.new("TextLabel")
			timeLbl.Size = UDim2.new(0, 58, 0, 18); timeLbl.Position = UDim2.new(0, 10, 0, 4)
			timeLbl.BackgroundTransparency = 1; timeLbl.Text = entry.time
			timeLbl.Font = Enum.Font.GothamBold; timeLbl.TextColor3 = C_GRAY
			timeLbl.TextSize = 10; timeLbl.TextXAlignment = Enum.TextXAlignment.Left; timeLbl.Parent = card

			local locBg = Instance.new("Frame")
			locBg.Size = UDim2.new(0, 54, 0, 16); locBg.Position = UDim2.new(0, 70, 0, 5)
			locBg.BackgroundColor3 = entry.inPit and Color3.fromRGB(40,25,0) or Color3.fromRGB(0,35,15)
			locBg.BorderSizePixel = 0; locBg.Parent = card
			Instance.new("UICorner", locBg).CornerRadius = UDim.new(0, 4)
			local locLbl = Instance.new("TextLabel")
			locLbl.Size = UDim2.new(1, 0, 1, 0); locLbl.BackgroundTransparency = 1
			locLbl.Text = entry.inPit and "🔧 PIT" or "🏁 PISTA"
			locLbl.Font = Enum.Font.GothamBold; locLbl.TextColor3 = entry.inPit and C_ORANGE or C_GREEN
			locLbl.TextSize = 9; locLbl.Parent = locBg

			local lapBadge = Instance.new("TextLabel")
			lapBadge.Size = UDim2.new(0, 46, 0, 16); lapBadge.Position = UDim2.new(0, 126, 0, 5)
			lapBadge.BackgroundTransparency = 1; lapBadge.Text = "LAP " .. entry.lap
			lapBadge.Font = Enum.Font.GothamBold; lapBadge.TextColor3 = C_GRAY
			lapBadge.TextSize = 9; lapBadge.TextXAlignment = Enum.TextXAlignment.Left; lapBadge.Parent = card

			local nameLbl2 = Instance.new("TextLabel")
			nameLbl2.Size = UDim2.new(0.45, 0, 0, 18); nameLbl2.Position = UDim2.new(0, 10, 0, 24)
			nameLbl2.BackgroundTransparency = 1; nameLbl2.Text = "👤 " .. entry.name
			nameLbl2.Font = Enum.Font.GothamBold; nameLbl2.TextColor3 = C_WHITE
			nameLbl2.TextSize = 11; nameLbl2.TextXAlignment = Enum.TextXAlignment.Left; nameLbl2.Parent = card

			local changeLbl = Instance.new("TextLabel")
			changeLbl.Size = UDim2.new(0.52, -8, 0, 18); changeLbl.Position = UDim2.new(0.47, 0, 0, 24)
			changeLbl.BackgroundTransparency = 1
			changeLbl.Text = entry.oldIcon .. " " .. entry.oldName .. "  →  " .. entry.newIcon .. " " .. entry.newName
			changeLbl.Font = Enum.Font.GothamBold; changeLbl.TextColor3 = entry.newColor
			changeLbl.TextSize = 11; changeLbl.TextXAlignment = Enum.TextXAlignment.Right
			changeLbl.TextTruncate = Enum.TextTruncate.AtEnd; changeLbl.Parent = card
			local rp = Instance.new("UIPadding"); rp.PaddingRight = UDim.new(0, 8); rp.Parent = card
		end

		-- Botón limpiar historial
		local clrRow = Instance.new("Frame")
		clrRow.Size = UDim2.new(1, 0, 0, 36); clrRow.BackgroundColor3 = C_BG
		clrRow.BackgroundTransparency = 0.1; clrRow.BorderSizePixel = 0
		clrRow.LayoutOrder = 9999; clrRow.Parent = tireScroll
		local clrBtn = Instance.new("TextButton")
		clrBtn.Size = UDim2.new(1, -16, 0.75, 0); clrBtn.Position = UDim2.new(0, 8, 0.125, 0)
		clrBtn.BackgroundColor3 = C_DARKRED; clrBtn.Text = "🗑  LIMPIAR HISTORIAL DE LLANTAS"
		clrBtn.Font = Enum.Font.GothamBlack; clrBtn.TextColor3 = C_WHITE
		clrBtn.TextSize = 11; clrBtn.BorderSizePixel = 0; clrBtn.Parent = clrRow
		Instance.new("UICorner", clrBtn).CornerRadius = UDim.new(0, 3)
		clrBtn.MouseButton1Click:Connect(function() SPA_Tires.log = {}; rebuildTireUI() end)

		_syncTire()
	end

	SPA_Tires.rebuildFn = rebuildTireUI

	-- ── Heartbeat: detección automática de compuesto ────────────
	-- [SDE_INFI · CAMBIO 1] Cuerpo extraído — fusionado en Heartbeat maestro
	_SDEI.hbTire = function()
		for _, p in ipairs(Players:GetPlayers()) do
			local uid  = p.UserId
			if FIA_EXCLUDED[uid] then continue end
			local char = p.Character
			if not char then continue end
			local hum  = char:FindFirstChildOfClass("Humanoid")
			if not hum then continue end
			local seat = hum.SeatPart
			if not seat or not seat:IsA("VehicleSeat") or seat.Occupant ~= hum then continue end
			local cpd = _tirGetCompound(seat)
			if not cpd then continue end   -- ID desconocida → ignorar
			local prev = SPA_Tires.current[uid]
			if not prev or prev.name ~= cpd.name then
				SPA_Tires.current[uid] = cpd
				local isInPit = pitData[uid] and pitData[uid].status == "En Boxes"
				_tirLogChange(p, prev, cpd, isInPit)
			end
		end
	end

	-- Limpiar estado al salir
	Players.PlayerRemoving:Connect(function(pl)
		SPA_Tires.current[pl.UserId] = nil
	end)

	rebuildTireUI()

	-- Actualización periódica mientras la pestaña esté visible
	task.spawn(function()
		while tireFrame.Parent do
			task.wait(1)
			if tireFrame.Visible then rebuildTireUI() end
		end
	end)
end
_setupTireSystem()

-- [SDE_INFI · CAMBIO 1] Heartbeat maestro único — reemplaza 7 callbacks separados
RunService.Heartbeat:Connect(function(dt)
	local HB = _SDEI.HB
	HB.crash += dt
	HB.anal  += dt
	HB.buf   += dt
	HB.prx   += dt
	HB.head  += dt
	HB.lap   += dt
	HB.tire  += dt

	if HB.crash >= 0.05                  then HB.crash = 0; if _SDEI.hbCrash then _SDEI.hbCrash() end end
	if HB.buf   >= (1/SPA_Replay.BUF_HZ) then HB.buf   = 0; if _SDEI.hbBuf   then _SDEI.hbBuf()   end end
	if HB.prx   >= 0.1                   then HB.prx   = 0; if _SDEI.hbPrx   then _SDEI.hbPrx()   end end
	if HB.head  >= 0.06                  then HB.head  = 0; if _SDEI.hbHead  then _SDEI.hbHead()  end end
	if HB.lap   >= 0.06                  then HB.lap   = 0; if _SDEI.hbLap   then _SDEI.hbLap()   end end
	if HB.anal  >= 0.5                   then HB.anal  = 0; if _SDEI.hbAnal  then _SDEI.hbAnal()  end end
	if HB.tire  >= 0.5                   then HB.tire  = 0; if _SDEI.hbTire  then _SDEI.hbTire()  end end
end)

-- ███ Activar la interfaz iOS Glassmorphism sobre TODAS las GUIs ███
Glass.apply()

print("✅ SPA GLOBAL PRO — RACE CONTROL SYSTEM (Unificado)")
print("🏁 Anti-Corner Cut NATIVO integrado sin memory leaks")
print("🍏 SPAV4 — Interfaz iOS Glassmorphism aplicada (frosted glass + blur)")