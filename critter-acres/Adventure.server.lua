-- Critter Acres: Adventure (ServerScriptService)
-- Things to do out in the world:
--   🚧 Biome gates  - the Forest / Peaks / Caves / Volcano open by farm level (no coins). The lands themselves
--                     are reached through the 🌀 Terrain Portal (Realms).
--   🦝 Raccoons     - sneak onto your farm toward ripe crops. Tap one before it runs off for a prize!
--   🎣 Fishing      - pond in the meadow: wait for the bite, tap fast. Fish book + coins + rare chests
--   ✨ Rare fruit   - drops somewhere in the world now and then; first one to grab it keeps it
--   🥚 Egg Snatch   - world event: carry the golden egg to the 🌀 Terrain Portal, others can tag you to take it
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local Data = API.Data
local ACTIONS = API.ACTIONS
local Builds = require(ReplicatedStorage:WaitForChild("Builds"))
local root = workspace:WaitForChild("CritterAcres")

local showEvent = ReplicatedStorage:FindFirstChild("CritterShow") or Instance.new("RemoteEvent")
showEvent.Name = "CritterShow"
showEvent.Parent = ReplicatedStorage

-- new titles from this script
for _, t in {{Name = "Fisher", Icon = "🎣", How = "Catch 25 fish"},
	{Name = "Egg Snatcher", Icon = "🥚", How = "Win an Egg Snatch"}, {Name = "Raccoon Chaser", Icon = "🦝", How = "Shoo 10 raccoons"}} do
	if not Data.TitleByName[t.Name] then
		table.insert(Data.Titles, t)
		Data.TitleByName[t.Name] = t
	end
end

local function P(parent, props)
	local x = Instance.new("Part")
	x.Anchored, x.TopSurface, x.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do x[k] = v end
	x.Parent = parent
	return x
end
local function sign(parent, at, text, color, height)
	local post = P(parent, {Size = Vector3.new(0.8, height or 8, 0.8), Position = at + Vector3.new(0, (height or 8) / 2, 0), Color = Color3.fromRGB(120, 85, 55),
		Material = Enum.Material.Wood})
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 80)
	bb.StudsOffset = Vector3.new(0, (height or 8) / 2 + 2, 0)
	bb.MaxDistance = 200
	bb.Parent = post
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = color
	t.BackgroundTransparency = 0.1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Text = text
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 16)
	t.Parent = bb
	return post, t
end
local function sparkles(parent, color, rate)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rate = rate or 10
	e.Lifetime = NumberRange.new(0.8, 1.5)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.7, 0)
	e.Parent = parent
	return e
end
local function hrpOf(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function joinedEvent(e, player)
	if e.joined[player] then return end
	e.joined[player] = true
	API.questEvent(player, "Event", 1)
end
local function onFarm(player, pos)
	local farm = API.farmOf[player]
	if not farm or not farm.ground then return false end
	local rel = farm.ground.CFrame:PointToObjectSpace(pos)
	return math.abs(rel.X) < 25 and math.abs(rel.Z) < 25
end

local stuff = Instance.new("Folder")
stuff.Name = "AdventureStuff"
stuff.Parent = workspace

---------------------------------------------------------------- 🚧 biome gates
local function gatesAttr(player, prof)
	local open = {}
	for name in Data.Gates do
		if prof.Gates[name] then table.insert(open, name) end
	end
	player:SetAttribute("Gates", table.concat(open, ","))
end
local gateLabels = {}
for name, g in Data.Gates do
	if not g.At then continue end -- lands now open from the 🌀 Terrain Portal screen (Realms)
	local m = Instance.new("Model")
	m.Name = "Gate_" .. name
	local dir = (Vector3.new(0, 0, 0) - g.At) * Vector3.new(1, 0, 1)
	local cf = CFrame.lookAt(g.At, g.At + dir.Unit)
	for _, x in {-6, 6} do
		P(m, {Size = Vector3.new(1.6, 12, 1.6), CFrame = cf * CFrame.new(x, 6, 0), Color = Color3.fromRGB(150, 105, 65), Material = Enum.Material.Wood})
	end
	P(m, {Size = Vector3.new(14.6, 1.6, 2), CFrame = cf * CFrame.new(0, 12.5, 0), Color = Color3.fromRGB(150, 105, 65), Material = Enum.Material.Wood})
	local _, label = sign(m, (cf * CFrame.new(-9, 0, -2)).Position, "", Color3.fromRGB(110, 90, 160), 7)
	gateLabels[name] = label
	local def = Data.BiomeByName[name]
	label.Text = ("%s %s\n🔒 farm Lv %d"):format(def and def.Icon or "🚧", name, g.Level)
	local hit = P(m, {Name = "Hit", Size = Vector3.new(12, 10, 1), CFrame = cf * CFrame.new(0, 5, 0), Transparency = 1, CanCollide = false})
	local prompt = API.makePrompt(hit, "🔓 Open gate", name)
	prompt.MaxActivationDistance = 14
	prompt.Triggered:Connect(function(player)
		local prof = API.profiles[player]
		if not prof then return end
		if prof.Gates[name] then API.toast(player, ("The %s gate is open for you! Walk on in."):format(name)) return end
		if API.farmLevelOf(player) < g.Level then
			API.toast(player, ("🔒 The %s opens at farm level %d. Keep farming!"):format(name, g.Level))
			return
		end
		prof.Gates[name] = true
		gatesAttr(player, prof)
		API.reveal(player, {Kind = "Gate", Name = name})
		API.notifyAll(("🔓 %s opened the %s!"):format(player.DisplayName, name))
	end)
	m.Parent = stuff
end
local function lockedBiomeAt(prof, pos)
	for name, b in Data.GateBounds do
		if pos.X > b[1] and pos.X < b[3] and pos.Z > b[2] and pos.Z < b[4] and not prof.Gates[name] then return name end
	end
end
local function eventInside(name)
	local pos = workspace:GetAttribute("EventPos")
	local b = Data.GateBounds[name]
	return workspace:GetAttribute("Event") and typeof(pos) == "Vector3" and pos.X > b[1] and pos.X < b[3] and pos.Z > b[2] and pos.Z < b[4]
end
task.spawn(function()
	while true do
		task.wait(0.5)
		for player, prof in API.profiles do
			local hrp = prof.Gates and hrpOf(player)
			if hrp then
				local locked = lockedBiomeAt(prof, hrp.Position)
				if locked and not eventInside(locked) then
					local g = Data.Gates[locked]
					local back = g.At + ((Vector3.new(0, 0, 0) - g.At) * Vector3.new(1, 0, 1)).Unit * 14
					API.teleportTo(player, Vector3.new(back.X, API.GROUND_Y, back.Z))
					API.toast(player, ("🔒 The %s opens at farm level %d!"):format(locked, g.Level))
				end
			end
		end
	end
end)
-- the 🗺️ map can't jump into a locked biome
local oldTravel = ACTIONS.Travel
function ACTIONS.Travel(player, prof, where)
	if Data.Gates[where] and API.farmLevelOf(player) < Data.Gates[where].Level then
		return ("🔒 The %s opens at farm level %d."):format(where, Data.Gates[where].Level)
	end
	return oldTravel(player, prof, where)
end
API.TravelReady = true -- (Portals wraps Travel after this)

---------------------------------------------------------------- 🎣 fishing pond
do
	local m = Instance.new("Model")
	m.Name = "FishingPond"
	local c = Data.PondPos
	local y = API.groundAt(c.X, c.Z)
	P(m, {Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 30, 30), CFrame = CFrame.new(c.X, y + 0.2, c.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(150, 140, 125), Material = Enum.Material.Pebble})
	P(m, {Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 27, 27), CFrame = CFrame.new(c.X, y + 0.35, c.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(70, 160, 230), Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false})
	local dock = P(m, {Name = "Dock", Size = Vector3.new(5, 0.6, 12), CFrame = CFrame.new(c.X, y + 1, c.Z + 13), Color = Color3.fromRGB(180, 130, 80),
		Material = Enum.Material.WoodPlanks})
	for _, x in {-2, 2} do
		P(m, {Size = Vector3.new(0.6, 2, 0.6), CFrame = CFrame.new(c.X + x, y + 0.2, c.Z + 8), Color = Color3.fromRGB(120, 85, 55)})
	end
	for i = 1, 6 do -- lily pads
		local a = i * 1.05
		P(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 2.6, 2.6), CFrame = CFrame.new(c.X + math.cos(a) * 9, y + 0.6, c.Z + math.sin(a) * 9) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(90, 180, 80), CanCollide = false})
	end
	sign(m, Vector3.new(c.X + 5, y, c.Z + 17), "🎣 Fishing Pond", Color3.fromRGB(60, 140, 220))
	dock:SetAttribute("FishSpot", true) -- the client puts its own 🎣 prompt here
	m.Parent = root
end
local casts = {} -- player -> {biteAt, token}
function ACTIONS.FishCast(player, prof)
	local hrp = hrpOf(player)
	if not hrp or (hrp.Position - Data.PondPos).Magnitude > 40 then return {Error = "Go to the 🎣 Fishing Pond in the meadow!"} end
	local wait = Data.FishWait[1] + math.random() * (Data.FishWait[2] - Data.FishWait[1])
	local token = math.random(1, 1e9)
	casts[player] = {biteAt = os.clock() + wait, token = token}
	return {Token = token, Wait = wait}
end
function ACTIONS.FishReel(player, prof, token)
	local cst = casts[player]
	casts[player] = nil
	if not cst or cst.token ~= token then return {Error = "🎣 Cast again!"} end
	local now = os.clock()
	if now < cst.biteAt - 0.15 then return {Miss = "Too soon! The fish swam away 🐟💨"} end
	if now > cst.biteAt + Data.FishWindow + 0.6 then return {Miss = "Too slow! The fish got away 🐟💨"} end
	local luck = 1 + (API.friendLuck and API.friendLuck(player) or 0)
	local list = {}
	for _, f in Data.Fish do
		table.insert(list, {F = f, Weight = f.Weight * (Data.Rarities[f.Rarity].Order >= 3 and luck or 1)})
	end
	local f = API.rollWeighted(list).F
	prof.Fish = prof.Fish or {}
	local isNew = not prof.Fish[f.Name]
	prof.Fish[f.Name] = (prof.Fish[f.Name] or 0) + 1
	prof.FishTotal = (prof.FishTotal or 0) + 1
	API.addCoins(player, f.Coins)
	if f.Egg then API.addEgg(prof, f.Egg) API.pushState(player) end
	API.questEvent(player, "Fish", 1)
	if prof.FishTotal >= 10 and API.badge then API.badge(player, "Fisher") end
	if prof.FishTotal >= 25 then API.giveTitle(player, "Fisher") end
	if f.Rarity == "Legendary" then API.notifyAll(("🎣 %s caught a %s %s!"):format(player.DisplayName, f.Icon, f.Name)) end
	return {Fish = f.Name, Icon = f.Icon, Rarity = f.Rarity, Coins = f.Coins, New = isNew, Egg = f.Egg, Count = prof.Fish[f.Name], Book = prof.Fish}
end
function ACTIONS.FishBook(player, prof) return prof.Fish or {} end

---------------------------------------------------------------- 🦝 raccoons
local function raccoonModel()
	local m = Instance.new("Model")
	m.Name = "Raccoon"
	local body = P(m, {Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), Color = Color3.fromRGB(130, 130, 140), CanCollide = false})
	local function bit(props, offset)
		local x = P(m, props)
		x.CanCollide, x.Anchored = false, false
		x.CFrame = body.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = body, x
		w.Parent = x
		return x
	end
	bit({Size = Vector3.new(2.2, 0.6, 0.4), Color = Color3.fromRGB(40, 40, 45)}, CFrame.new(0, 0.35, -1.15)) -- mask
	for _, x in {-0.5, 0.5} do
		bit({Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, Color = Color3.new(1, 1, 1)}, CFrame.new(x, 0.4, -1.3))
		bit({Size = Vector3.new(0.5, 0.8, 0.3), Color = Color3.fromRGB(110, 110, 120)}, CFrame.new(x * 1.6, 1.4, 0))
	end
	bit({Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4, Color = Color3.fromRGB(30, 30, 30)}, CFrame.new(0, -0.1, -1.4))
	for i = 0, 3 do -- striped tail
		bit({Shape = Enum.PartType.Ball, Size = Vector3.one * (0.9 - i * 0.08), Color = i % 2 == 0 and Color3.fromRGB(60, 60, 65) or Color3.fromRGB(190, 190, 195)},
			CFrame.new(0, 0.2 + i * 0.35, 1.4 + i * 0.55))
	end
	-- sack of "berries"
	bit({Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, Color = Color3.fromRGB(190, 150, 100), Material = Enum.Material.Fabric}, CFrame.new(1.2, 0.6, 0.4))
	m.PrimaryPart = body
	return m, body
end
local raccoonBusy = {}
local function sendRaccoon(farm)
	local owner = farm.owner
	if not owner or raccoonBusy[farm] then return end
	local ripe = {}
	for _, plot in farm.plots do
		if plot:GetAttribute("Mature") and not plot:GetAttribute("Locked") then table.insert(ripe, plot) end
	end
	if #ripe == 0 then return end
	raccoonBusy[farm] = true
	local target = ripe[math.random(#ripe)]
	local g = farm.ground.CFrame
	local startLocal = Vector3.new(math.random() < 0.5 and -24 or 24, 0, math.random(-10, 20))
	local from = g:PointToWorldSpace(startLocal)
	local mid = target.Position + ((from - target.Position) * Vector3.new(1, 0, 1)).Unit * 3
	local m, body = raccoonModel()
	local prompt = API.makePrompt(body, "🦝 Shoo!", "Sneaky Raccoon")
	prompt.MaxActivationDistance = 14
	m.Parent = stuff
	local caught = false
	prompt.Triggered:Connect(function(who)
		if caught then return end
		caught = true
		local got = API.grant(who, API.rollWeighted(Data.RaccoonPrizes))
		API.reveal(who, {Kind = "Prize", Prize = got})
		API.toast(who, "🦝 Shoo shoo! The raccoon dropped its loot and ran away!")
		local prof = API.profiles[who]
		if prof then
			prof.Shooed = (prof.Shooed or 0) + 1
			if prof.Shooed >= 10 then API.giveTitle(who, "Raccoon Chaser") end
		end
	end)
	API.toast(owner, "🦝 A sneaky raccoon is going for your berries! Tap it to shoo it away!")
	local function walk(a, b, secs)
		local t0 = os.clock()
		while os.clock() - t0 < secs and m.Parent do
			if caught then return end
			local f = (os.clock() - t0) / secs
			local p = a:Lerp(b, f)
			local y = API.groundAt(p.X, p.Z) + 1.3 + math.abs(math.sin(f * secs * 9)) * 0.4
			body.CFrame = CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(b.X, y, b.Z))
			task.wait()
		end
	end
	walk(from, mid, 6)
	local t0 = os.clock()
	while not caught and os.clock() - t0 < 3 and m.Parent do -- nibble nibble
		body.CFrame *= CFrame.Angles(0, math.sin(os.clock() * 20) * 0.08, 0)
		task.wait()
	end
	if caught then
		walk(mid, from, 1.2) -- runs off fast
		caught = true
	else
		local away = g:PointToWorldSpace(Vector3.new(startLocal.X * 1.6, 0, startLocal.Z))
		walk(mid, away, 7)
		if not caught and owner.Parent then API.toast(owner, "🦝 The raccoon got away! Be quicker next time 😜") end
	end
	if m.Parent then m:Destroy() end
	raccoonBusy[farm] = nil
end
task.spawn(function()
	local nextAt = {}
	while true do
		task.wait(5)
		for _, farm in API.farms do
			local owner = farm.owner
			if owner then
				nextAt[farm] = nextAt[farm] or os.clock() + math.random(Data.RaccoonGap[1], Data.RaccoonGap[2])
				local hrp = hrpOf(owner)
				if os.clock() > nextAt[farm] and hrp and onFarm(owner, hrp.Position) then
					nextAt[farm] = os.clock() + math.random(Data.RaccoonGap[1], Data.RaccoonGap[2])
					task.spawn(sendRaccoon, farm)
				end
			else
				nextAt[farm] = nil
			end
		end
	end
end)

---------------------------------------------------------------- ✨ rare fruit drops
local function dropFruit()
	local biomes = {"Meadow", "Forest", "Peaks", "Caves", "Volcano"}
	local where = biomes[math.random(#biomes)]
	local pos = API.biomePoint(where)
	if not pos then return end
	local prize = API.rollWeighted(Data.FruitDrops)
	local cropName = prize.Crop or "Starfruit"
	local fruit = Builds.Crop(cropName)
	fruit:ScaleTo(1.6)
	local y = API.groundAt(pos.X, pos.Z)
	fruit:PivotTo(CFrame.new(pos.X, y + 0.2, pos.Z))
	local main
	for _, d in fruit:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide = true, false
			if d.Name == "Fruit" then d.Material = Enum.Material.Neon end
			main = main or d
		end
	end
	local beam = P(fruit, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(120, 2, 2), CFrame = CFrame.new(pos.X, y + 60, pos.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 230, 120), Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = false})
	sparkles(main, Color3.fromRGB(255, 240, 150), 20)
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color = 16, 2, Color3.fromRGB(255, 230, 140)
	light.Parent = main
	local prompt = API.makePrompt(main, "✨ Grab!", "Rare " .. cropName)
	prompt.MaxActivationDistance = 12
	fruit.Parent = stuff
	local icon = Data.BiomeByName[where] and Data.BiomeByName[where].Icon or "🌼"
	workspace:SetAttribute("FruitPos", Vector3.new(pos.X, y, pos.Z))
	workspace:SetAttribute("FruitWhere", icon .. " " .. where)
	API.notifyAll(("✨ A rare fruit dropped in the %s %s! Find it first!"):format(where, icon))
	local taken = false
	prompt.Triggered:Connect(function(who)
		if taken then return end
		taken = true
		local got = API.grant(who, prize)
		API.reveal(who, {Kind = "Prize", Prize = got})
		API.notifyAll(("✨ %s found the rare fruit!"):format(who.DisplayName))
		fruit:Destroy()
	end)
	local t0 = os.clock()
	while fruit.Parent and os.clock() - t0 < 120 do
		beam.Transparency = 0.45 + math.sin(os.clock() * 3) * 0.15
		task.wait(0.1)
	end
	if fruit.Parent then fruit:Destroy() end
	workspace:SetAttribute("FruitPos", nil)
	workspace:SetAttribute("FruitWhere", nil)
end
task.spawn(function()
	task.wait(40)
	while true do
		if #Players:GetPlayers() > 0 then pcall(dropFruit) end
		task.wait(math.random(Data.FruitGap[1], Data.FruitGap[2]))
	end
end)

---------------------------------------------------------------- world events (run by WorldEvents' timer)
local EVENTS = API.EVENTS
if not EVENTS then
	for _ = 1, 40 do
		if API.EVENTS then break end
		task.wait(0.5)
	end
	EVENTS = API.EVENTS
end

local function eggSnatch(e)
	local center = Vector3.new(0, API.GROUND_Y, 20)
	workspace:SetAttribute("EventPos", center)
	API.notifyAll("🥚 EGG SNATCH! Grab the golden egg in the plaza and carry it to the 🌀 Terrain Portal! Others can tag you to take it!")
	local goalGate = root:FindFirstChild("TerrainPortal") and root.TerrainPortal:FindFirstChild("Gate")
	local goal = goalGate and goalGate.Position or Vector3.new(4, API.GROUND_Y, -72)
	local egg = P(stuff, {Name = "SnatchEgg", Size = Vector3.new(2.4, 3, 2.4), CFrame = CFrame.new(center + Vector3.new(0, 2, 0)), Color = Color3.fromRGB(255, 210, 60),
		Material = Enum.Material.Neon, CanCollide = false})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	sparkles(egg, Color3.fromRGB(255, 240, 150), 20)
	local light = Instance.new("PointLight")
	light.Range, light.Brightness = 18, 2
	light.Parent = egg
	local carrier, carrierSpeed, tagPrompt, weld
	local tagAt = 0
	local touched = {}
	local winner
	local function drop()
		if weld then weld:Destroy() weld = nil end
		if tagPrompt then tagPrompt:Destroy() tagPrompt = nil end
		if carrier then
			local hum = carrier.Character and carrier.Character:FindFirstChildOfClass("Humanoid")
			if hum and carrierSpeed then hum.WalkSpeed = carrierSpeed end
			carrier:SetAttribute("Carrying", nil)
		end
		carrier = nil
	end
	local function give(player)
		local char = player.Character
		local head = char and char:FindFirstChild("Head")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = hrpOf(player)
		if not head or not hum or not hrp then return end
		drop()
		carrier = player
		touched[player] = true
		joinedEvent(e, player)
		tagAt = os.clock()
		carrierSpeed = hum.WalkSpeed
		hum.WalkSpeed = carrierSpeed * 0.88
		player:SetAttribute("Carrying", true)
		egg.Anchored = false
		egg.Massless = true
		egg.CFrame = head.CFrame * CFrame.new(0, 2.6, 0)
		weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = head, egg
		weld.Parent = egg
		tagPrompt = Instance.new("ProximityPrompt")
		tagPrompt.ActionText = "🙌 Tag! Take the egg"
		tagPrompt.ObjectText = player.DisplayName
		tagPrompt.HoldDuration = 0
		tagPrompt.MaxActivationDistance = 9
		tagPrompt.RequiresLineOfSight = false
		tagPrompt.Parent = hrp
		tagPrompt.Triggered:Connect(function(who)
			if who == carrier or os.clock() - tagAt < 2.5 then return end -- a short shield after each grab
			API.toast(carrier, ("🙌 %s tagged you and took the egg!"):format(who.DisplayName))
			give(who)
			API.notifyAll(("🥚 %s grabbed the egg!"):format(who.DisplayName))
		end)
		API.toast(player, "🥚 You have the egg! RUN to the 🌀 Terrain Portal! 🏃")
	end
	local grab = API.makePrompt(egg, "🥚 Grab the egg!", "Golden Egg")
	grab.MaxActivationDistance = 12
	grab.Triggered:Connect(function(who)
		if carrier then return end
		grab.Enabled = false
		give(who)
		API.notifyAll(("🥚 %s grabbed the golden egg!"):format(who.DisplayName))
	end)
	while e.endsAt - os.clock() > 0 do
		if carrier then
			local hrp = hrpOf(carrier)
			local hum = carrier.Character and carrier.Character:FindFirstChildOfClass("Humanoid")
			if not carrier.Parent or not hrp or not hum or hum.Health <= 0 then -- dropped: back on the ground
				local at = egg.Position
				drop()
				egg.Anchored = true
				egg.CFrame = CFrame.new(at.X, API.groundAt(at.X, at.Z) + 1.6, at.Z)
				grab.Enabled = true
			else
				workspace:SetAttribute("EventPos", hrp.Position)
				workspace:SetAttribute("EventBoard", "🥚 " .. carrier.DisplayName)
				if (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(goal.X, 0, goal.Z)).Magnitude < 9 then
					winner = carrier
					break
				end
			end
		end
		task.wait(0.2)
	end
	drop()
	egg:Destroy()
	if winner then
		local got = API.grant(winner, Data.SnatchPrize)
		API.reveal(winner, {Kind = "Prize", Prize = got})
		API.giveTitle(winner, "Egg Snatcher")
		API.notifyAll(("🥚 %s got the golden egg to the portal and won a Star Egg!"):format(winner.DisplayName))
	else
		API.notifyAll("🥚 Time's up! The golden egg rolled away...")
	end
	for p in touched do
		if p ~= winner and p.Parent then
			API.addCoins(p, 30)
			API.toast(p, "🥚 Thanks for playing Egg Snatch! 💰+30")
		end
	end
end

if EVENTS then
	EVENTS.EggSnatch = eggSnatch
else
	warn("[Adventure] WorldEvents not found: Egg Snatch is off")
end

---------------------------------------------------------------- joining
local function onProfile(player)
	local prof
	for _ = 1, 60 do
		prof = API.profiles[player]
		if prof then break end
		task.wait(0.5)
	end
	if not prof then return end
	if not prof.Gates then
		prof.Gates = {}
		for name in Data.Gates do -- older saves: biomes you already explored stay open
			if prof.Visited and prof.Visited[name] then prof.Gates[name] = true end
		end
	end
	gatesAttr(player, prof)
end
Players.PlayerAdded:Connect(onProfile)
for _, p in Players:GetPlayers() do task.spawn(onProfile, p) end
Players.PlayerRemoving:Connect(function(p) casts[p] = nil showVotes[p] = nil end)

API.DEV_EXTRA = API.DEV_EXTRA or {}
API.DEV_EXTRA.Raccoon = function(player)
	local farm = API.farmOf[player]
	if farm then task.spawn(sendRaccoon, farm) end
	return "🦝 Raccoon sent (needs a ripe crop)"
end
API.DEV_EXTRA.Fruit = function() task.spawn(dropFruit) return "✨ Rare fruit dropped" end
API.DEV_EXTRA.Gates = function(player, prof)
	for name in Data.Gates do prof.Gates[name] = true end
	gatesAttr(player, prof)
	return "🔓 All gates open"
end

print("[Adventure] ready")
