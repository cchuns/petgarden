-- Critter Acres: CritterPlay (StarterPlayerScripts LocalScript)
-- The open-world / play side of the HUD:
--   • world event banner: countdown, timer, compass arrow + distance to the event, 🚀 go there, race board, boss HP
--   • weather drawn around your camera (rain, snow, storm lightning) and boss/star knockbacks
--   • 🗺️ map: travel to your farm, the plaza and every biome (with who lives there), visit friends' farms (❤️ ranking)
--   • 🧪 fusion: 3 of a kind -> Shiny -> Rainbow, with a swirl-and-flash show
--   • buddy bar (the pet that follows you): 🤚 rub game, 🎾 fetch, tricks
--   • popups: mutated/giant berry harvests, fetch combos, catch race win
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))
local PackOpen = require(ReplicatedStorage:WaitForChild("PackOpen"))
local actionFn = ReplicatedStorage:WaitForChild("CritterAction")
local stateEvent = ReplicatedStorage:WaitForChild("CritterState")
local revealEvent = ReplicatedStorage:WaitForChild("CritterReveal")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local gui = Instance.new("ScreenGui")
gui.Name = "CritterPlay"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2
gui.Parent = player:WaitForChild("PlayerGui")

local CREAM, BROWN = Color3.fromRGB(255, 250, 235), Color3.fromRGB(90, 60, 40)
local GREEN, WHITE = Color3.fromRGB(150, 230, 130), Color3.new(1, 1, 1)
local state = nil

---------------------------------------------------------------- tiny UI kit
local function round(obj, r) Instance.new("UICorner", obj).CornerRadius = UDim.new(0, r or 12) return obj end
local function L(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextColor3 = BROWN
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	for k, v in props do t[k] = v end
	t.Parent = parent
	return t
end
local function B(parent, props, fn)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = CREAM
	b.TextColor3 = BROWN
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.AutoButtonColor = true
	for k, v in props do b[k] = v end
	round(b, 12)
	local s = Instance.new("UIStroke", b)
	s.Color, s.Thickness, s.ApplyStrokeMode = Color3.fromRGB(230, 190, 140), 2, Enum.ApplyStrokeMode.Border
	b.Parent = parent
	if fn then b.Activated:Connect(fn) end
	return b
end
local function F(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do f[k] = v end
	f.Parent = parent
	return f
end
local function tween(obj, secs, goal, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(secs, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local function act(...)
	local res = actionFn:InvokeServer(...)
	return res
end
local function floatText(text, pos, color, size)
	local l = L(gui, {Text = text, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(size or 60, size or 60), ZIndex = 80,
		TextColor3 = color or WHITE, TextStrokeTransparency = 0.3})
	tween(l, 1.1, {Position = pos - UDim2.fromOffset(0, 120), TextTransparency = 1, TextStrokeTransparency = 1, Rotation = math.random(-25, 25)}, Enum.EasingStyle.Sine)
	task.delay(1.2, function() l:Destroy() end)
end

stateEvent.OnClientEvent:Connect(function(s) state = s end)

---------------------------------------------------------------- weather around your camera
local sky = Instance.new("Part")
sky.Name = "LocalWeather"
sky.Anchored, sky.CanCollide, sky.CanQuery, sky.CanTouch = true, false, false, false
sky.Transparency = 1
sky.Size = Vector3.new(120, 1, 120)
sky.Parent = workspace
local rain = Instance.new("ParticleEmitter")
rain.EmissionDirection = Enum.NormalId.Bottom
rain.Color = ColorSequence.new(Color3.fromRGB(160, 205, 255))
rain.Size = NumberSequence.new(0.15)
rain.Speed = NumberRange.new(55, 65)
rain.Lifetime = NumberRange.new(0.9, 1)
rain.Rate = 600
rain.LightEmission = 0.3
rain.Enabled = false
rain.Parent = sky
local snow = Instance.new("ParticleEmitter")
snow.EmissionDirection = Enum.NormalId.Bottom
snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
snow.Color = ColorSequence.new(WHITE)
snow.Size = NumberSequence.new(0.5)
snow.Speed = NumberRange.new(6, 9)
snow.Lifetime = NumberRange.new(5, 6)
snow.SpreadAngle = Vector2.new(25, 25)
snow.RotSpeed = NumberRange.new(-60, 60)
snow.Rate = 260
snow.Enabled = false
snow.Parent = sky
local flash = Instance.new("ColorCorrectionEffect")
flash.Name = "Lightning"
flash.Parent = Lighting
local function weatherFx()
	local w = workspace:GetAttribute("Weather")
	rain.Enabled = w == "Rain" or w == "Storm"
	snow.Enabled = w == "Snow"
end
workspace:GetAttributeChangedSignal("Weather"):Connect(weatherFx)
weatherFx()
task.spawn(function() -- lightning flashes during storms
	while true do
		task.wait(2.5 + math.random() * 4)
		if workspace:GetAttribute("Weather") == "Storm" then
			for _ = 1, math.random(1, 2) do
				flash.Brightness = 0.7
				task.wait(0.06)
				flash.Brightness = 0
				task.wait(0.09)
			end
		end
	end
end)
RunService.RenderStepped:Connect(function()
	sky.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 35, 0))
end)

-- knocked back by a boss stomp, a meteor or a falling star
revealEvent.OnClientEvent:Connect(function(info)
	if info.Kind ~= "Knock" then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	hrp.AssemblyLinearVelocity = info.Dir * info.Power + Vector3.new(0, info.Power * 0.6, 0)
end)

---------------------------------------------------------------- world event banner
local EVENT_ICON = {}
for _, e in Data.Events do EVENT_ICON[e.Name] = e.Icon end
local EVENT_NAME = {FallingStar = "Falling Star", CatchRace = "Catch Race", WorldBoss = "World Boss", PresentRush = "Present Rush",
	EggSnatch = "Egg Snatch"}
local banner = F(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 88), Size = UDim2.fromOffset(500, 62),
	BackgroundColor3 = Color3.fromRGB(45, 35, 70), BackgroundTransparency = 0.1, Visible = false})
round(banner, 18)
local bStroke = Instance.new("UIStroke", banner)
bStroke.Color, bStroke.Thickness = Color3.fromRGB(255, 210, 90), 3
local bIcon = L(banner, {Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(54, 54)})
local bTime = L(banner, {Position = UDim2.fromOffset(66, 8), Size = UDim2.fromOffset(220, 46), TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left})
local bArrow = L(banner, {Position = UDim2.fromOffset(290, 7), Size = UDim2.fromOffset(48, 48), Text = "⬆", TextColor3 = Color3.fromRGB(255, 220, 90)})
local bDist = L(banner, {Position = UDim2.fromOffset(340, 12), Size = UDim2.fromOffset(80, 38), TextColor3 = WHITE})
local bGo = B(banner, {Text = "🚀", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(64, 48),
	BackgroundColor3 = Color3.fromRGB(255, 225, 120)}, function()
	local m = act("TravelEvent")
	if type(m) == "string" then ReplicatedStorage.CritterUIBridge:Fire("Toast", m) end
end)
local bExtra = F(banner, {Position = UDim2.new(0, 0, 1, 6), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1})
local bBoard = L(bExtra, {Size = UDim2.fromScale(1, 1), TextColor3 = WHITE, TextStrokeTransparency = 0.3, Visible = false})
local hpBg = F(bExtra, {Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.fromRGB(40, 30, 50), Visible = false})
round(hpBg, 11)
local hpFill = F(hpBg, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 70, 90)})
round(hpFill, 11)
local hpText = L(hpBg, {Size = UDim2.fromScale(1, 1), TextColor3 = WHITE, TextStrokeTransparency = 0.3})

RunService.RenderStepped:Connect(function()
	local nextE, active = workspace:GetAttribute("EventNext"), workspace:GetAttribute("Event")
	banner.Visible = nextE ~= nil or active ~= nil
	if not banner.Visible then return end
	local now = os.time()
	if nextE then
		bIcon.Text = EVENT_ICON[nextE] or "❔"
		bTime.Text = ("%s in %ds"):format(EVENT_NAME[nextE] or nextE, math.max(0, (workspace:GetAttribute("EventAt") or now) - now))
		bIcon.Rotation = math.sin(os.clock() * 10) * 12
		bArrow.Visible, bDist.Visible, bGo.Visible = false, false, false
		bBoard.Visible, hpBg.Visible = false, false
		return
	end
	bIcon.Rotation = 0
	bIcon.Text = EVENT_ICON[active] or "❔"
	bTime.Text = ("%s ⏱%d"):format(EVENT_NAME[active] or active, math.max(0, (workspace:GetAttribute("EventEnds") or now) - now))
	local pos = workspace:GetAttribute("EventPos")
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if pos and hrp then
		local rel = camera.CFrame:VectorToObjectSpace(pos - hrp.Position)
		bArrow.Rotation = math.deg(math.atan2(rel.X, -rel.Z))
		local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
		bDist.Text = ("📍%d"):format(d)
		bArrow.Visible, bDist.Visible = true, true
		bGo.Visible = d > 40 and active ~= "CatchRace" -- the race is fairer if you have to run
	else
		bArrow.Visible, bDist.Visible, bGo.Visible = false, false, false
	end
	local boardJson = workspace:GetAttribute("EventBoard")
	bBoard.Visible = boardJson ~= nil
	if boardJson then
		local ok, list = pcall(HttpService.JSONDecode, HttpService, boardJson)
		local medals = {"🥇", "🥈", "🥉"}
		local parts = {}
		for i, e in ok and list or {} do table.insert(parts, ("%s %s %d"):format(medals[i], e[1], e[2])) end
		bBoard.Text = #parts > 0 and table.concat(parts, "   ") or "🏃 ⭐0"
	end
	local hp, maxHp = workspace:GetAttribute("BossHP"), workspace:GetAttribute("BossMaxHP")
	hpBg.Visible = hp ~= nil
	if hp and maxHp then
		hpFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
		hpText.Text = ("👹 %d"):format(hp)
	end
end)

---------------------------------------------------------------- shared big-reveal overlay (fusion, race win, jackpot)
local overlay = F(gui, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 15, 35), BackgroundTransparency = 0.25,
	Visible = false, Active = true, ZIndex = 70})
local function clearOverlay() for _, ch in overlay:GetChildren() do ch:Destroy() end end
local function OL(props) props.ZIndex = props.ZIndex or 72 return L(overlay, props) end
local function flashScreen(color)
	local f = F(overlay, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = color or WHITE, ZIndex = 90})
	tween(f, 0.6, {BackgroundTransparency = 1})
	task.delay(0.65, function() f:Destroy() end)
end
local function rays(color)
	local holder = F(overlay, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1, ZIndex = 71})
	for i = 0, 5 do
		local r = F(holder, {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(46, 1100), Rotation = i * 30, BackgroundColor3 = color, ZIndex = 71})
		local g = Instance.new("UIGradient", r)
		g.Rotation = 90
		g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1)})
		TweenService:Create(r, TweenInfo.new(9, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {Rotation = i * 30 + 360}):Play()
	end
end
local function waitTap()
	local done = false
	local b = B(overlay, {Text = "✔", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(160, 64),
		BackgroundColor3 = GREEN, ZIndex = 85}, function() done = true end)
	b.Size = UDim2.fromOffset(0, 0)
	tween(b, 0.3, {Size = UDim2.fromOffset(160, 64)}, Enum.EasingStyle.Back)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 30 do task.wait() end
end
local busy = false
local function show(fn)
	task.spawn(function()
		while busy do task.wait(0.2) end
		busy = true
		clearOverlay()
		overlay.Visible = true
		local ok, err = pcall(fn)
		if not ok then warn("CritterPlay show:", err) end
		clearOverlay()
		overlay.Visible = false
		busy = false
	end)
end
-- big pet reveal with badges
local function petReveal(species, variant, sizeName, outfit, topIcon)
	local s = Data.SpeciesByName[species]
	local rarity = Data.Rarities[s.Rarity]
	local v = variant and Data.VariantByName[variant]
	local sz = sizeName and Data.SizeByName[sizeName]
	local color = v and v.Color or rarity.Color
	flashScreen(color)
	rays(color)
	local vf = CritterUI.Portrait(overlay, Data, species, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(0, 0), ZIndex = 74}, {Variant = variant, Outfit = outfit})
	CritterUI.Animate(vf, "show")
	vf:SetAttribute("Hop", os.clock())
	tween(vf, 0.6, {Size = UDim2.fromOffset(380, 380)}, Enum.EasingStyle.Back)
	if topIcon then OL({Text = topIcon, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(90, 90)}) end
	OL({Text = (v and v.Icon .. " " or "") .. species .. (sz and " " .. sz.Icon or ""), AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, topIcon and 96 or 24), Size = UDim2.new(0.6, 0, 0, 64), TextColor3 = color, TextStrokeTransparency = 0.2})
	if v then
		local chip = OL({Text = v.Icon .. " " .. v.Name:upper(), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.78, 0),
			Size = UDim2.fromOffset(220, 50), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 240, 190)})
		round(chip, 14)
		CritterUI.Glow(chip, "Legendary", color)
	end
	waitTap()
end

---------------------------------------------------------------- side buttons: 🗺️ map and 🧪 fusion
local side = F(gui, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(360, 64), BackgroundTransparency = 1})
local sl = Instance.new("UIListLayout", side)
sl.FillDirection = Enum.FillDirection.Horizontal
sl.Padding = UDim.new(0, 8)

-- the window uses the shared UIKit look (same as the 🐾 / 🏡 / 🗺️ / 🛒 menus)
local UI = require(ReplicatedStorage:WaitForChild("UIKit"))
local winGui = Instance.new("ScreenGui") -- its own layer: Sibling draw order, under the toasts and reveals
winGui.Name = "CritterPlayWindow"
winGui.ResetOnSpawn = false
winGui.DisplayOrder = 1
winGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
winGui.Parent = player:WaitForChild("PlayerGui")
local win = UI.window(winGui, {Icon = "💕", Title = "Best Friends Nest"})
local window = win.frame
local wBody = win.body
local openWin = nil
win.onClose = function() openWin = nil end
-- older pages set wTitle.Text = "🗺️ Map ..." : split it into the icon + title
local wTitle = setmetatable({}, {__newindex = function(_, k, v)
	if k == "Text" then
		local icon, rest = tostring(v):match("^(%S+)%s*(.*)$")
		win.setTitle(icon or "", rest or "")
	end
end})
local function clearBody()
	win.clear()
	win.setSub("")
	win.setTabs({})
end
local function section(order, text, _color, sub) return UI.header(wBody, text, order, sub) end
local function grid(order, cell) return UI.grid(wBody, cell, order) end

-- 🗺️ map
local thumbs = {}
local function thumb(userId)
	if thumbs[userId] then return thumbs[userId] end
	local ok, img = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	thumbs[userId] = ok and img or ""
	return thumbs[userId]
end
local renderMap
function renderMap()
	clearBody()
	wTitle.Text = "🗺️ Map"
	win.setSub("Go anywhere, visit friends")
	section(1, "🚀 Travel", Color3.fromRGB(120, 180, 255))
	local g = grid(2, UDim2.fromOffset(176, 150))
	local function travelTile(order, icon, color, fn, species)
		local b = B(g, {Text = "", LayoutOrder = order, BackgroundColor3 = color:Lerp(WHITE, 0.45), ZIndex = 42}, fn)
		b.UIStroke.Color, b.UIStroke.Thickness = color, 4
		L(b, {Text = icon, Size = UDim2.new(1, 0, 0.55, 0), ZIndex = 43})
		if species then -- little pictures of who lives there
			local row = F(b, {Position = UDim2.fromScale(0, 0.55), Size = UDim2.fromScale(1, 0.42), BackgroundTransparency = 1, ZIndex = 43})
			local rl = Instance.new("UIListLayout", row)
			rl.FillDirection = Enum.FillDirection.Horizontal
			rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
			for i, name in species do
				if i > 4 then break end
				local found = state and state.Found and state.Found[name]
				if found then
					local vf = CritterUI.Portrait(row, Data, name, {Size = UDim2.fromOffset(40, 56), ZIndex = 44})
					vf.ZIndex = 44
				else
					L(row, {Text = "❔", Size = UDim2.fromOffset(40, 56), ZIndex = 44})
				end
			end
		end
	end
	travelTile(1, "🏡 My Farm", Color3.fromRGB(120, 200, 95), function() act("GoHome") window.Visible = false end)
	travelTile(2, "🏛️ Plaza", Color3.fromRGB(255, 190, 90), function() act("Travel", "Plaza") window.Visible = false end)
	travelTile(3, "🌀 Terrain Portal", Color3.fromRGB(150, 110, 255), function() act("Travel", "TerrainPortal") window.Visible = false end)
	-- farms on this server, most ❤️ first
	section(3, "🏡 Farms on this server (most ❤️ likes first)", Color3.fromRGB(255, 110, 150))
	local list = act("Farms") or {}
	table.sort(list, function(a, b) return a.Likes > b.Likes end)
	local fl = F(wBody, {Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4, ZIndex = 41})
	local fll = Instance.new("UIListLayout", fl)
	fll.Padding = UDim.new(0, 6)
	local medals = {"🥇", "🥈", "🥉"}
	for i, f in list do
		local row = F(fl, {Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = f.Mine and Color3.fromRGB(230, 250, 220) or WHITE, ZIndex = 42})
		round(row, 14)
		L(row, {Text = medals[i] or tostring(i), Position = UDim2.fromOffset(6, 8), Size = UDim2.fromOffset(48, 48), ZIndex = 43})
		local img = Instance.new("ImageLabel")
		img.BackgroundColor3 = Color3.fromRGB(230, 220, 205)
		img.Position = UDim2.fromOffset(58, 6)
		img.Size = UDim2.fromOffset(52, 52)
		img.ZIndex = 43
		round(img, 26)
		img.Parent = row
		task.spawn(function() img.Image = thumb(f.UserId) end)
		L(row, {Text = f.Name, Position = UDim2.fromOffset(118, 6), Size = UDim2.new(0.4, 0, 0, 52), ZIndex = 43, TextXAlignment = Enum.TextXAlignment.Left})
		L(row, {Text = ("⭐%d   ❤️%d%s"):format(f.Level, f.Likes, f.Liked and " ✔" or ""), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -90, 0, 10),
			Size = UDim2.fromOffset(170, 44), ZIndex = 43})
		if not f.Mine then
			B(row, {Text = "🚀", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(70, 50),
				BackgroundColor3 = Color3.fromRGB(255, 225, 120), ZIndex = 43}, function()
				act("Visit", f.UserId)
				window.Visible = false
			end)
		end
	end
end

-- 🧪 fusion
local renderFuse
local function fuseShow(group, res)
	local pets = group.pets
	local positions = {UDim2.fromScale(0.3, 0.42), UDim2.fromScale(0.5, 0.25), UDim2.fromScale(0.7, 0.42)}
	local vfs = {}
	for i = 1, 3 do
		local p = pets[i]
		local vf = CritterUI.Portrait(overlay, Data, p.Species, {AnchorPoint = Vector2.new(0.5, 0.5), Position = positions[i], Size = UDim2.fromOffset(200, 200),
			ZIndex = 74}, {Variant = p.Variant, Outfit = p.Outfit})
		CritterUI.Animate(vf, "idle")
		table.insert(vfs, vf)
	end
	local pot = OL({Text = "🧪", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(150, 150)})
	task.wait(0.6)
	-- swirl into the middle
	local t0 = os.clock()
	while os.clock() - t0 < 1.8 do
		local f = (os.clock() - t0) / 1.8
		for i, vf in vfs do
			local a = (i - 1) * math.pi * 2 / 3 + f * f * math.pi * 6
			local r = 0.22 * (1 - f)
			vf.Position = UDim2.fromScale(0.5 + math.cos(a) * r, 0.45 + math.sin(a) * r * 1.4)
			vf.Size = UDim2.fromOffset(200 * (1 - f * 0.8), 200 * (1 - f * 0.8))
		end
		pot.Rotation = math.sin(os.clock() * 30) * 15 * f
		task.wait()
	end
	for _, vf in vfs do vf:Destroy() end
	pot:Destroy()
	petReveal(res.Species, res.Variant, res.SizeName, res.Outfit, "🧪")
end
local nestPick = {}
function renderFuse() -- (the 💕 Best Friends Nest lives where fusion used to be)
	clearBody()
	win.setTitle("💕", "Best Friends Nest")
	win.setSub("2 pets cuddle and make a Friend Egg. Both pets stay!")
	win.setHelp({{"💕", "Pick 2 pets from your farm."}, {"⏱", "They cuddle in the nest. Tap 💕 Cheer on the nest to speed it up."},
		{"🥚", "You get a Friend Egg. The baby looks like one of them, with mixed colors!"}})
	local pets = state and state.Pets or {}
	local cuddling = {}
	for _, p in pets do
		if p.Nest then table.insert(cuddling, p) end
	end
	if #cuddling >= 2 then
		local left = math.max(0, (cuddling[1].Nest or 0) - os.time())
		UI.header(wBody, ("🥚 Friend Egg in %d:%02d"):format(left // 60, left % 60), 1, "Tap 💕 Cheer on the nest (on your farm) to speed it up. Friends can cheer too!")
		local g = UI.grid(wBody, UDim2.fromOffset(200, 220), 2)
		for i, p in cuddling do
			UI.card(g, {Order = i, Name = p.Name or p.Species, Sub = "💕 Cuddling", Color = Color3.fromRGB(255, 150, 190), Art = function(pic)
				local vf = CritterUI.Portrait(pic, Data, p.Species, {Size = UDim2.fromScale(1, 1)}, {Variant = p.Variant, Outfit = p.Outfit})
				CritterUI.Animate(vf, "show")
			end})
		end
		UI.button(wBody, {Text = "✖ Stop cuddling", LayoutOrder = 4, Size = UDim2.fromOffset(240, 50), Kind = "careful",
			Tip = "Stop cuddling", TipText = "Both pets go back to your farm. No egg this time."}, function()
			act("NestCancel")
			task.wait(0.2)
			renderFuse()
		end)
		return
	end
	UI.header(wBody, ("Pick 2 friends  (%d/2)"):format(#nestPick), 1, "🤫 Some best-friend pairs can make a SECRET pet...")
	local g = UI.grid(wBody, UDim2.fromOffset(150, 190), 2)
	local n = 0
	for _, p in pets do
		if not p.Trip and not p.Stored then
			n += 1
			local resting = p.NestRest and os.time() < p.NestRest
			local picked = table.find(nestPick, p.Id) ~= nil
			local sub = resting and ("😴 Resting %d:%02d"):format((p.NestRest - os.time()) // 60, (p.NestRest - os.time()) % 60) or (picked and "💕 Picked" or p.Rarity)
			local c = UI.card(g, {Order = n, Name = p.Name or p.Species, Sub = sub, Color = picked and Color3.fromRGB(255, 90, 150) or Data.Rarities[p.Rarity].Color,
				Art = function(pic)
					local vf = CritterUI.Portrait(pic, Data, p.Species, {Size = UDim2.fromScale(1, 1)}, {Variant = p.Variant, Outfit = p.Outfit})
					CritterUI.Animate(vf, picked and "show" or "idle")
				end,
				CardFn = function()
					if resting then
						floatText("😴 Still resting", UDim2.fromScale(0.5, 0.4), Color3.fromRGB(200, 200, 220), 30)
						return
					end
					local i = table.find(nestPick, p.Id)
					if i then table.remove(nestPick, i) elseif #nestPick < 2 then table.insert(nestPick, p.Id) end
					renderFuse()
				end})
			if picked then c.BackgroundColor3 = Color3.fromRGB(255, 228, 238) end
			if resting then c.BackgroundColor3 = UI.GREY end
		end
	end
	if n == 0 then UI.empty(wBody, "🐾", "Bring pets to your farm first.", nil, nil, 3) end
	local ready = #nestPick == 2
	UI.button(wBody, {Text = ready and "💕 Start cuddling" or ("💕 Pick %d more"):format(2 - #nestPick), LayoutOrder = 4, Size = UDim2.fromOffset(300, 56),
		Kind = ready and "go" or "no"}, function()
		if not ready then
			floatText("Pick 2 pets first", UDim2.fromScale(0.5, 0.4), Color3.fromRGB(255, 150, 190), 30)
			return
		end
		local msg = act("NestStart", nestPick[1], nestPick[2])
		nestPick = {}
		if type(msg) == "string" then floatText(msg, UDim2.fromScale(0.5, 0.4), Color3.fromRGB(255, 120, 170), 30) end
		task.wait(0.2)
		renderFuse()
	end)
end

local renderShop -- old seed shop page (the 🛒 Shop menu replaced it)
local shopTab = "Seeds"
local bridge = ReplicatedStorage:WaitForChild("CritterUIBridge")
local function openWindow(name)
	if name == "Shop" then -- the 🛒 shop is in the new menus now
		win.close()
		bridge:Fire("Open", "Shop", shopTab)
		return
	end
	if openWin == name and window.Visible then
		win.close()
		return
	end
	openWin = name
	win.open()
	wBody.CanvasPosition = Vector2.zero
	stateEvent:FireServer()
	task.wait(0.15)
	if name == "Map" then renderMap() elseif name == "Fuse" then renderFuse() else renderShop() end
end
B(side, {Text = "🗺️ Map", Size = UDim2.fromOffset(96, 64), BackgroundColor3 = Color3.fromRGB(190, 225, 255)}, function() openWindow("Map") end)
local nestBtn = B(side, {Text = "💕 Nest", Size = UDim2.fromOffset(96, 64), BackgroundColor3 = Color3.fromRGB(255, 200, 225)}, function() openWindow("Fuse") end)
nestBtn.Name = "NestButton" -- CritterHooks hides it until farm level 3
stateEvent.OnClientEvent:Connect(function()
	if openWin == "Fuse" and window.Visible then renderFuse() end
end)
-- the cauldron in the plaza opens fusion too
task.spawn(function()
	local root = workspace:WaitForChild("CritterAcres")
	local cauldron = root:WaitForChild("Cauldron", 30)
	local pot = cauldron and cauldron:WaitForChild("Pot", 10)
	if not pot then return end
	local prompt = Instance.new("ProximityPrompt") -- a local prompt: it only opens your own menu
	prompt.ActionText = "💕 Best Friends Nest"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pot
	prompt.Triggered:Connect(function() if openWin ~= "Fuse" then openWindow("Fuse") end end)
end)

---------------------------------------------------------------- buddy bar (your follower pet): rub, fetch, tricks
local buddyBar = F(gui, {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(520, 76),
	BackgroundColor3 = Color3.fromRGB(45, 35, 70), BackgroundTransparency = 0.15, Visible = false})
round(buddyBar, 18)
local buddyList = Instance.new("UIListLayout", buddyBar)
buddyList.FillDirection = Enum.FillDirection.Horizontal
buddyList.Padding = UDim.new(0, 6)
buddyList.VerticalAlignment = Enum.VerticalAlignment.Center
local bp = Instance.new("UIPadding", buddyBar)
bp.PaddingLeft, bp.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
local buddyKey = nil
local buddyShown = false -- the buddy bar shows when you tap your buddy button (CritterMenus)
local openRub

local function buddyPet()
	for _, p in state and state.Pets or {} do
		if p.Follow and not p.Trip then return p end
	end
end
local function renderBuddy()
	local p = buddyPet()
	buddyBar.Visible = p ~= nil and buddyShown
	if not p then buddyKey = nil return end
	local key = ("%d|%d|%s|%s"):format(p.Id, p.Level, p.Variant or "", p.Outfit or "")
	if key == buddyKey then return end
	buddyKey = key
	for _, ch in buddyBar:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local face = F(buddyBar, {Size = UDim2.fromOffset(64, 64), BackgroundColor3 = Data.Rarities[p.Rarity].Color:Lerp(WHITE, 0.5), LayoutOrder = 0})
	round(face, 14)
	local vf = CritterUI.Portrait(face, Data, p.Species, {Size = UDim2.fromScale(1, 1)}, {Variant = p.Variant, Outfit = p.Outfit})
	CritterUI.Animate(vf, "idle")
	B(buddyBar, {Text = "🤚\nPet", Size = UDim2.fromOffset(62, 62), LayoutOrder = 1, BackgroundColor3 = Color3.fromRGB(255, 190, 210)}, function() openRub(p) end)
	B(buddyBar, {Text = "🎾\nFetch", Size = UDim2.fromOffset(62, 62), LayoutOrder = 2, BackgroundColor3 = Color3.fromRGB(210, 255, 150)}, function()
		local msg = act("Throw", camera.CFrame.LookVector)
		if type(msg) == "string" then floatText(msg, UDim2.new(1, -300, 1, -120)) end
	end)
	for i, t in Data.Tricks do
		local locked = p.Level < t.Level
		local b = B(buddyBar, {Text = locked and "🔒" or (t.Icon .. "\n" .. t.Name), Size = UDim2.fromOffset(62, 62), LayoutOrder = 2 + i,
			BackgroundColor3 = locked and Color3.fromRGB(150, 145, 160) or Color3.fromRGB(255, 235, 170)}, function()
			if locked then return end
			act("Trick", t.Name)
		end)
		if locked then
			L(b, {Text = "Lv" .. t.Level, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 0, 0.36, 0),
				TextColor3 = WHITE, TextStrokeTransparency = 0.3})
		end
	end
	buddyBar.Size = UDim2.fromOffset(16 + 64 + 6 + (2 + #Data.Tricks) * 68, 76)
end
stateEvent.OnClientEvent:Connect(renderBuddy)

-- 🤚 rub mini game: rub the pet (drag over it) to fill the hearts; tap the ✨ tickle spot for a bonus
local rubbing = false
function openRub(p)
	if busy then return end
	show(function()
		local panel = F(overlay, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 520),
			BackgroundColor3 = Color3.fromRGB(255, 235, 245), ZIndex = 72})
		round(panel, 30)
		local vf = CritterUI.Portrait(panel, Data, p.Species, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(0.85, 0.75), ZIndex = 73}, {Variant = p.Variant, Outfit = p.Outfit})
		CritterUI.Animate(vf, "show")
		local meterBg = F(panel, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(0.8, 0, 0, 34),
			BackgroundColor3 = Color3.fromRGB(230, 210, 220), ZIndex = 73})
		round(meterBg, 17)
		local meter = F(meterBg, {Size = UDim2.fromScale(0.02, 1), BackgroundColor3 = Color3.fromRGB(255, 100, 160), ZIndex = 74})
		round(meter, 17)
		L(meterBg, {Text = "💖", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 6, 0.5, 0), Size = UDim2.fromOffset(40, 40), ZIndex = 74})
		local hint = L(panel, {Text = "👆↔️", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(120, 50), ZIndex = 74})
		TweenService:Create(hint, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Position = UDim2.new(0.5, 30, 0, 10)}):Play()
		local closed = false
		B(panel, {Text = "✖", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(46, 46), ZIndex = 76,
			BackgroundColor3 = Color3.fromRGB(255, 180, 170)}, function() closed = true end)
		local tickle = B(panel, {Text = "✨", Size = UDim2.fromOffset(56, 56), ZIndex = 76, BackgroundColor3 = Color3.fromRGB(255, 250, 200)})
		local fill, lastPos, trail = 0, nil, 0
		local function addFill(n)
			fill = math.min(1, fill + n)
			meter.Size = UDim2.fromScale(math.max(0.02, fill), 1)
		end
		local function moveTickle()
			tickle.Position = UDim2.fromScale(0.15 + math.random() * 0.6, 0.15 + math.random() * 0.5)
		end
		moveTickle()
		tickle.Activated:Connect(function()
			addFill(0.12)
			vf:SetAttribute("Hop", os.clock())
			floatText("😆", UDim2.fromOffset(tickle.AbsolutePosition.X + 28, tickle.AbsolutePosition.Y))
			moveTickle()
		end)
		local inputs = {}
		table.insert(inputs, UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				rubbing = true
				lastPos = nil
			end
		end))
		table.insert(inputs, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then rubbing = false end
		end))
		table.insert(inputs, UserInputService.InputChanged:Connect(function(input)
			if not rubbing then return end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			local a, s = vf.AbsolutePosition, vf.AbsoluteSize
			if pos.X < a.X or pos.Y < a.Y or pos.X > a.X + s.X or pos.Y > a.Y + s.Y then lastPos = nil return end
			if lastPos then
				local d = (pos - lastPos).Magnitude
				addFill(d / 2600)
				trail += d
				if trail > 45 then
					trail = 0
					floatText(math.random() < 0.3 and "💖" or "❤️", UDim2.fromOffset(pos.X, pos.Y - 36), nil, 40)
				end
				vf.Rotation = math.clamp((pos.X - lastPos.X) * 0.3, -6, 6)
			end
			lastPos = pos
		end))
		local t0, nextMove = os.clock(), os.clock() + 1.6
		while not closed and fill < 1 and os.clock() - t0 < 45 do
			if os.clock() > nextMove then
				nextMove = os.clock() + 1.6
				moveTickle()
			end
			vf.Rotation *= 0.9
			task.wait()
		end
		for _, c in inputs do c:Disconnect() end
		rubbing = false
		if fill >= 1 then -- all filled up: big heart burst
			tickle:Destroy()
			act("Rub", p.Id)
			vf:SetAttribute("Hop", os.clock())
			local c = vf.AbsolutePosition + vf.AbsoluteSize / 2
			for i = 1, 14 do
				task.delay(i * 0.04, function()
					floatText(i % 3 == 0 and "💖" or "❤️", UDim2.fromOffset(c.X + math.random(-160, 160), c.Y + math.random(-80, 120)), nil, 56)
				end)
			end
			task.wait(1.4)
		end
	end)
end

---------------------------------------------------------------- 🛒 seed shop: seeds (restocks), 🎁 packs, 📗 seed book
local SoundService = game:GetService("SoundService")
local tickSound = Instance.new("Sound")
tickSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
tickSound.Volume = 0.25
tickSound.Parent = gui
local shopInfo = nil

-- a strip of cards that zooms past a ▼ marker and stops on cells[resultIndex]
local function playReel(cells, resultIndex, makeCell)
	local CELL, GAP = 140, 10
	local box = F(overlay, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.92, 0, 0, 190),
		BackgroundColor3 = Color3.fromRGB(40, 32, 60), ClipsDescendants = true, ZIndex = 72})
	round(box, 20)
	local strip = F(box, {Size = UDim2.new(0, #cells * (CELL + GAP), 1, -24), BackgroundTransparency = 1, ZIndex = 72})
	for i, d in cells do
		local cell = F(strip, {Position = UDim2.fromOffset((i - 1) * (CELL + GAP), 0), Size = UDim2.new(0, CELL, 1, 0), ZIndex = 73})
		round(cell, 16)
		makeCell(cell, d)
	end
	F(box, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 220, 80), ZIndex = 80})
	OL({Text = "▼", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.5, -95), Size = UDim2.fromOffset(60, 50), TextColor3 = Color3.fromRGB(255, 220, 80), ZIndex = 80})
	task.wait()
	local w = box.AbsoluteSize.X
	local finalX = w / 2 - ((resultIndex - 1) * (CELL + GAP) + CELL / 2) + (math.random() - 0.5) * CELL * 0.6
	strip.Position = UDim2.new(0, w / 2 - CELL / 2, 0, 12)
	local tw = tween(strip, 4.4, {Position = UDim2.new(0, finalX, 0, 12)}, Enum.EasingStyle.Quint)
	local last = -1
	local conn = RunService.RenderStepped:Connect(function()
		local idx = math.floor((w / 2 - strip.Position.X.Offset) / (CELL + GAP))
		if idx ~= last then
			last = idx
			tickSound.PlaybackSpeed = 0.9 + math.random() * 0.3
			SoundService:PlayLocalSound(tickSound)
		end
	end)
	tw.Completed:Wait()
	conn:Disconnect()
	task.wait(0.7)
	box:Destroy()
end

local function seedCard(parent, cropName, amount, z)
	local crop = Data.CropByName[cropName]
	local rc = Data.Rarities[crop.Rarity].Color
	parent.BackgroundColor3 = rc:Lerp(Color3.fromRGB(40, 32, 60), 0.35)
	local st = Instance.new("UIStroke", parent)
	st.Color, st.Thickness = rc, 3
	L(parent, {Text = crop.Icon, Size = UDim2.fromScale(1, 0.62), ZIndex = z})
	L(parent, {Text = (crop.Tree and "🌳 " or "") .. "x" .. amount, Position = UDim2.fromScale(0, 0.64), Size = UDim2.fromScale(1, 0.3),
		TextColor3 = WHITE, TextStrokeTransparency = 0.3, ZIndex = z})
end

local function rollPackItem(pack) -- random filler cards for the reel
	local total = 0
	for _, it in pack.Items do total += it.Weight end
	local r = math.random() * total
	for _, it in pack.Items do
		r -= it.Weight
		if r <= 0 then return it end
	end
	return pack.Items[1]
end

local function packShow(res)
	local pack = Data.SeedPackByName[res.Pack]
	local crop = Data.CropByName[res.Item.Crop]
	PackOpen.Play(overlay, {Style = "Pack", Icon = pack.Icon, Title = res.Pack .. " Seed Pack", Color = pack.Color, Cards = {{
		Rarity = crop.Rarity, Name = ("%d %s seed%s"):format(res.Item.Amount, res.Item.Crop, res.Item.Amount > 1 and "s" or ""),
		Badges = crop.PackOnly and {"🎁 PACK ONLY!"} or nil,
		Art = function(f, z) seedCard(f, res.Item.Crop, res.Item.Amount, z) end}}})
end

function renderShop()
	clearBody()
	wTitle.Text = "🛒"
	local l = Instance.new("UIListLayout", wBody)
	l.Padding = UDim.new(0, 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	shopInfo = act("ShopInfo") or shopInfo
	local info = shopInfo
	if not info then return end
	-- tabs
	local tabs = F(wBody, {Size = UDim2.new(1, -10, 0, 56), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 41})
	local tl = Instance.new("UIListLayout", tabs)
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 8)
	for _, t in {{"Seeds", "🌱 Seeds"}, {"Packs", (info.FreePacks > 0) and "🎁 Packs 🆓" or "🎁 Packs"}, {"Book", "📗 Seed Book"}} do
		local on = shopTab == t[1]
		local b = B(tabs, {Text = t[2], Size = UDim2.new(0.31, 0, 1, 0), ZIndex = 42, BackgroundColor3 = on and Color3.fromRGB(255, 225, 120) or Color3.fromRGB(240, 235, 225)},
			function() shopTab = t[1] renderShop() end)
		if on then b.UIStroke.Thickness = 4 end
	end
	if shopTab == "Seeds" then
		local timer = L(wBody, {Text = "⏱", LayoutOrder = 1, Size = UDim2.new(1, -10, 0, 40), ZIndex = 42})
		task.spawn(function() -- live countdown while this page is open
			while timer.Parent do
				local left = math.max(0, (workspace:GetAttribute("ShopRestockAt") or os.time()) - os.time())
				timer.Text = ("🛒 ⏱ %d:%02d"):format(left // 60, left % 60)
				if left <= 0 then task.wait(1.5) if timer.Parent then renderShop() end return end
				task.wait(1)
			end
		end)
		local g = grid(2, UDim2.fromOffset(150, 178))
		for i, it in info.Items do
			local crop = Data.CropByName[it.Crop]
			local locked = info.Level < it.Unlock
			local soldOut = it.Left <= 0
			local rc = Data.Rarities[crop.Rarity].Color
			local card = B(g, {Text = "", LayoutOrder = i, ZIndex = 42, BackgroundColor3 = (locked or soldOut) and Color3.fromRGB(215, 210, 205) or rc:Lerp(WHITE, 0.6)},
				function()
					if locked or soldOut then return end
					local res = act("BuySeed", it.Crop, 1)
					if type(res) == "table" and res.Ok then
						shopInfo = res.Info
						floatText(crop.Icon .. " +1", UDim2.fromOffset(card.AbsolutePosition.X + 75, card.AbsolutePosition.Y))
						renderShop()
					elseif type(res) == "table" then
						floatText(res.Error, UDim2.fromOffset(card.AbsolutePosition.X + 75, card.AbsolutePosition.Y), Color3.fromRGB(255, 120, 120))
					end
				end)
			card.UIStroke.Color, card.UIStroke.Thickness = rc, 4
			L(card, {Text = crop.Icon, Size = UDim2.fromScale(1, 0.42), ZIndex = 43})
			L(card, {Text = it.Crop, Position = UDim2.fromScale(0.04, 0.42), Size = UDim2.fromScale(0.92, 0.17), ZIndex = 43})
			L(card, {Text = locked and ("🔒 Farm level " .. it.Unlock) or ("💰 " .. it.Price), Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.18), ZIndex = 43})
			L(card, {Text = soldOut and "Sold out" or ((crop.Tree and "🌳 Tree  " or "") .. it.Left .. " left"), Position = UDim2.fromScale(0, 0.8), Size = UDim2.fromScale(1, 0.17), ZIndex = 43})
			if crop.Rarity == "Legendary" or crop.Rarity == "Epic" then CritterUI.Glow(card, crop.Rarity, rc) end
		end
		if not info.Bell then
			local bell = B(g, {Text = "", LayoutOrder = 99, ZIndex = 42, BackgroundColor3 = Color3.fromRGB(255, 240, 190)}, function()
				local res = act("BuyBell")
				if type(res) == "table" and res.Ok then shopInfo = res.Info renderShop() end
			end)
			L(bell, {Text = "🔔", Size = UDim2.fromScale(1, 0.6), ZIndex = 43})
			L(bell, {Text = "💰 " .. Data.BellCost, Position = UDim2.fromScale(0, 0.65), Size = UDim2.fromScale(1, 0.28), ZIndex = 43})
		end
	elseif shopTab == "Packs" then
		local g = grid(1, UDim2.fromOffset(230, 260))
		for i, pack in Data.SeedPacks do
			local free = pack.Name == "Basic" and info.FreePacks > 0
			local card = B(g, {Text = "", LayoutOrder = i, ZIndex = 42, BackgroundColor3 = pack.Color:Lerp(WHITE, 0.45)}, function()
				if busy then return end
				local res = act("BuyPack", pack.Name)
				if type(res) == "table" and res.Item then
					shopInfo = res.Info
					window.Visible = false
					openWin = nil
					show(function() packShow(res) end)
				elseif type(res) == "table" then
					floatText(res.Error, UDim2.fromScale(0.5, 0.5), Color3.fromRGB(255, 120, 120))
				end
			end)
			card.UIStroke.Color, card.UIStroke.Thickness = pack.Color, 5
			local icon = L(card, {Text = pack.Icon, Size = UDim2.fromScale(1, 0.5), ZIndex = 43})
			TweenService:Create(icon, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Rotation = 8}):Play()
			-- what can be inside (best ones first)
			local row = F(card, {Position = UDim2.fromScale(0.05, 0.5), Size = UDim2.fromScale(0.9, 0.2), BackgroundTransparency = 1, ZIndex = 43})
			local rl = Instance.new("UIListLayout", row)
			rl.FillDirection = Enum.FillDirection.Horizontal
			rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
			for k = #pack.Items, 1, -1 do
				L(row, {Text = Data.CropByName[pack.Items[k].Crop].Icon, Size = UDim2.new(1 / #pack.Items, 0, 1, 0), ZIndex = 44})
			end
			L(card, {Text = free and ("🆓 x" .. info.FreePacks) or ("💰 " .. pack.Price), Position = UDim2.fromScale(0, 0.74), Size = UDim2.fromScale(1, 0.22),
				ZIndex = 43, TextColor3 = free and Color3.fromRGB(40, 150, 40) or BROWN})
			if free or pack.Name == "Mythic" then CritterUI.Glow(card, pack.Name == "Mythic" and "Legendary" or "Epic", pack.Color) end
		end
	else -- 📗 Seed Book
		for i, rowDef in Data.SeedBookRows do
			local st = info.Rows[i]
			local row = F(wBody, {Size = UDim2.new(1, -10, 0, 96), BackgroundColor3 = st.Claimed and Color3.fromRGB(225, 245, 215) or WHITE, LayoutOrder = i, ZIndex = 42})
			round(row, 16)
			L(row, {Text = rowDef.Icon, Position = UDim2.fromOffset(8, 18), Size = UDim2.fromOffset(60, 60), ZIndex = 43})
			for k, cropName in rowDef.Crops do
				local crop = Data.CropByName[cropName]
				local have = info.SeedBook and info.SeedBook[cropName]
				local tile = L(row, {Text = have and crop.Icon or "❔", Position = UDim2.fromOffset(70 + (k - 1) * 76, 12), Size = UDim2.fromOffset(70, 70), ZIndex = 43,
					BackgroundTransparency = 0, BackgroundColor3 = have and Data.Rarities[crop.Rarity].Color:Lerp(WHITE, 0.55) or Color3.fromRGB(80, 75, 95)})
				round(tile, 14)
			end
			local reward = rowDef.Reward
			local done = st.Have >= st.Need
			local b = B(row, {Text = st.Claimed and "✅" or (done and ("🎁 " .. Data.PrizeIcon(reward)) or (("%d/%d  %s"):format(st.Have, st.Need, Data.PrizeIcon(reward)))),
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 64), ZIndex = 43,
				BackgroundColor3 = done and not st.Claimed and GREEN or Color3.fromRGB(240, 235, 225)}, function()
				if done and not st.Claimed then
					local res = act("ClaimSeedRow", i)
					if type(res) == "table" and res.Ok then shopInfo = res.Info renderShop() end
				end
			end)
			if done and not st.Claimed then CritterUI.Glow(b, "Legendary", Color3.fromRGB(255, 200, 60)) end
		end
	end
end

-- 🛒 button with the restock countdown (blinks when rare seeds are in): takes you to the shop
local shopBtn = B(side, {Text = "🛒", Size = UDim2.fromOffset(140, 64), BackgroundColor3 = Color3.fromRGB(200, 240, 180)}, function() act("TravelShop") end)
task.spawn(function()
	while true do
		local left = math.max(0, (workspace:GetAttribute("ShopRestockAt") or os.time()) - os.time())
		local rare = workspace:GetAttribute("ShopRare")
		local icon = "🛒"
		if rare then
			local first = string.split(rare, ",")[1]
			icon = Data.CropByName[first] and Data.CropByName[first].Icon or "🛒"
		end
		shopBtn.Text = ("%s Shop %d:%02d"):format(icon, left // 60, left % 60)
		shopBtn.BackgroundColor3 = (rare and os.clock() % 1 < 0.5) and Color3.fromRGB(255, 225, 120) or Color3.fromRGB(200, 240, 180)
		task.wait(0.5)
	end
end)
-- a prompt on the shop counter opens the window (only for you)
task.spawn(function()
	local root = workspace:WaitForChild("CritterAcres")
	local shop = root:WaitForChild("SeedShop", 30)
	local counter = shop and shop:WaitForChild("Counter", 10)
	if not counter then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Shop 🛒"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	prompt.Triggered:Connect(function() if openWin ~= "Shop" then openWindow("Shop") end end)
end)
-- 🔔 bell: big popup when rare seeds arrive
revealEvent.OnClientEvent:Connect(function(info)
	if info.Kind ~= "Bell" then return end
	local card = F(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -200), Size = UDim2.fromOffset(360, 150),
		BackgroundColor3 = Color3.fromRGB(255, 240, 190), ZIndex = 60})
	round(card, 22)
	local icons = {}
	for _, c in info.Crops do table.insert(icons, Data.CropByName[c].Icon) end
	L(card, {Text = "🔔 " .. table.concat(icons, " "), Size = UDim2.new(1, -20, 0.55, 0), Position = UDim2.fromOffset(10, 6), ZIndex = 61})
	B(card, {Text = "🚀🛒", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(150, 50), ZIndex = 61,
		BackgroundColor3 = GREEN}, function()
		local m = act("TravelShop")
		if type(m) == "string" then ReplicatedStorage.CritterUIBridge:Fire("Toast", m) end
		card:Destroy()
	end)
	CritterUI.Glow(card, "Legendary", Color3.fromRGB(255, 200, 60))
	tween(card, 0.4, {Position = UDim2.new(0.5, 0, 0, 160)}, Enum.EasingStyle.Back)
	task.delay(8, function()
		if card.Parent then
			tween(card, 0.3, {Position = UDim2.new(0.5, 0, 0, -200)})
			task.wait(0.35)
			card:Destroy()
		end
	end)
end)

---------------------------------------------------------------- popups: harvests, fetch combos, race wins
local function harvestPopup(info)
	local crop = Data.CropByName[info.Crop]
	local best = nil
	for _, n in info.Muts or {} do
		local m = Data.MutationByName[n]
		if m and (not best or m.Mult > best.Mult) then best = m end
	end
	local size = info.Size and Data.CropSizeByName[info.Size]
	local color = best and best.Color or Color3.fromRGB(255, 220, 120)
	local jackpot = info.Value >= 150 or (best and best.Name == "Prismatic") or info.Size == "MEGA"
	local function card(parent, z)
		local c = F(parent, {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(240, 240), BackgroundColor3 = color:Lerp(Color3.fromRGB(40, 32, 60), 0.35),
			ZIndex = z})
		round(c, 26)
		L(c, {Text = crop.Icon, Position = UDim2.fromScale(0.1, 0.04), Size = UDim2.fromScale(0.8, size and (0.4 + size.Scale * 0.05) or 0.45), ZIndex = z + 1})
		local icons = {}
		for _, n in info.Muts or {} do table.insert(icons, Data.MutationByName[n].Icon) end
		L(c, {Text = table.concat(icons, "") .. (size and ("  " .. size.Icon) or ""), Position = UDim2.fromScale(0.05, 0.56), Size = UDim2.fromScale(0.9, 0.18),
			TextColor3 = WHITE, TextStrokeTransparency = 0.2, ZIndex = z + 1})
		L(c, {Text = "💰 " .. info.Value, Position = UDim2.fromScale(0.05, 0.76), Size = UDim2.fromScale(0.9, 0.2), TextColor3 = Color3.fromRGB(255, 235, 120),
			TextStrokeTransparency = 0.2, ZIndex = z + 1})
		CritterUI.Glow(c, jackpot and "Legendary" or "Epic", color)
		return c
	end
	if jackpot then
		show(function()
			flashScreen(color)
			rays(color)
			local c = card(overlay, 74)
			c.Position = UDim2.fromScale(0.5, 0.45)
			c.Size = UDim2.fromOffset(0, 0)
			tween(c, 0.5, {Size = UDim2.fromOffset(320, 320)}, Enum.EasingStyle.Back)
			OL({Text = "🤩", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(100, 100)})
			waitTap()
		end)
	else
		local c = card(gui, 50)
		c.AnchorPoint = Vector2.new(0, 0.5)
		c.Size = UDim2.fromOffset(170, 170)
		c.Position = UDim2.new(1, 20, 0.35, 0)
		tween(c, 0.35, {Position = UDim2.new(1, -310, 0.35, 0)}, Enum.EasingStyle.Back)
		task.delay(2.6, function()
			tween(c, 0.3, {Position = UDim2.new(1, 20, 0.35, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.35)
			c:Destroy()
		end)
	end
end

revealEvent.OnClientEvent:Connect(function(info)
	if info.Kind == "Harvest" then
		harvestPopup(info)
	elseif info.Kind == "Fetch" then
		floatText(("🎾 x%d"):format(info.Combo), UDim2.new(1, -260, 1, -110), Color3.fromRGB(210, 255, 120), 70)
	elseif info.Kind == "RaceWin" then
		show(function() petReveal(info.Species, info.Variant, nil, nil, "🏆") end)
	end
end)

stateEvent:FireServer()

---------------------------------------------------------------- the new menus (CritterMenus) open our screens
bridge.Event:Connect(function(cmd, arg)
	if cmd == "Nest" then
		if openWin ~= "Fuse" or not window.Visible then openWin = nil openWindow("Fuse") end
	elseif cmd == "Shop" then
		shopTab = arg or "Seeds"
		openWindow("Shop")
	elseif cmd == "PackShow" then
		show(function() packShow(arg) end)
	elseif cmd == "Buddy" then
		buddyShown = arg and true or false
		buddyKey = nil
		renderBuddy()
	elseif cmd == "HideOld" then
		side.Visible = false
	end
end)
