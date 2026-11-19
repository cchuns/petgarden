-- Critter Acres: Realms (ServerScriptService)
-- 🧭 The wild terrains (Meadow, Forest, Peaks, Caves, Volcano) are no longer joined to town.
-- You reach them through the 🌀 Explorer's Portal (CritterAcres.TerrainPortal, north of the park):
--   * pick a terrain, go solo or make a party (invite anyone in the server, up to CFG.PartyMax)
--   * the leader presses Explore: a fresh map is generated from a random seed in a free "slot" far from town
--     (trail with glades, side pockets, ponds / ice / lava, resource nodes, mobs to battle, a treasure grove)
--   * walk back through the exit portal (or press 🚪 Leave) to return to town. Empty maps are wiped.
--   * lands open by farm level only (Data.Gates[land].Level), no coins
--   * each explorer can bring one buddy pet (it follows you and helps in battles), or go alone
-- Mobs are battle-only (never tamed). Combat.server.lua runs their brains, hearts, weapons and drops: Realms hands
-- every mob over with API.combatAddMob(run, model, template) and calls API.combatRunGone(run) when a map is wiped.
-- New pets only come from eggs.
-- Client: StarterPlayerScripts.TerrainPortal (portal screen, party invites, in-map bar, per-terrain look).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local t0 = os.clock()
while not API.TravelReady and os.clock() - t0 < 15 do task.wait(0.2) end
local Data, ACTIONS, root = API.Data, API.ACTIONS, API.root
local Terrain = workspace.Terrain
local M = Enum.Material

local CFG = {
	PartyMax = 4,
	InviteSecs = 45, -- invites expire
	Countdown = 4, -- seconds between Explore and the jump (everyone in the party sees it)
	Slots = 8, SlotX = 9000, SlotZ = 9000, SlotGap = 1200, -- maps are built far away from town and the islands
	Half = 500, -- maps are 1000 x 1000 studs (about 6x the first version)
	NearPortal = 45, -- Explore only works next to the Explorer's Portal
	EmptyWipe = 20, -- seconds an empty map waits before it is wiped (so you can pop back in)
	ChestCoins = {Meadow = 60, Forest = 120, Peaks = 220, Caves = 380, Volcano = 600},
}

local remote = ReplicatedStorage:FindFirstChild("RealmEvent")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "RealmEvent"
	remote.Parent = ReplicatedStorage
end

local PROPS = ServerStorage:WaitForChild("IslandProps")
local RPROPS = ServerStorage:WaitForChild("RealmProps", 10) -- generated terrain props + node templates (BuildTerrainPortal.lua)
local function template(name)
	return (RPROPS and RPROPS:FindFirstChild(name, true)) or PROPS:FindFirstChild(name)
end

---------------------------------------------------------------- terrain looks
-- Hill = how tall the land rises away from the trail, Wall = border mountains
local STYLE = {
	Meadow = {Ground = M.Grass, Alt = M.LeafyGrass, Path = M.Ground, Cliff = M.Rock, Hill = 9, Wall = 30, Pond = "Water",
		Trees = {"TreeRound", "TreeBlossom", "FruitTree", "Birch", "Maple"}, TreeCount = 420,
		Small = {"Flowers", "FlowerBush", "Bush", "TulipRow", "LavenderRow", "Fern", "MossyRock", "Rocks"}, SmallCount = 650},
	Forest = {Ground = M.LeafyGrass, Alt = M.Mud, Path = M.Ground, Cliff = M.Rock, Hill = 15, Wall = 42, Pond = "Water",
		Trees = {"Pine", "Maple", "Birch", "Cypress", "Willow", "Pine"}, TreeCount = 900,
		Small = {"Fern", "Fern", "Bush", "MossyRock", "GiantShroom", "Reeds"}, SmallCount = 560},
	Peaks = {Ground = M.Snow, Alt = M.Glacier, Path = M.Ground, Cliff = M.Rock, Hill = 24, Wall = 58, Pond = "Ice",
		Trees = {"SnowPine", "SnowPine", "Pine"}, TreeCount = 460, Small = {"IceCrystal", "Rocks", "IceCrystal"}, SmallCount = 330},
	Caves = {Ground = M.Slate, Alt = M.Basalt, Path = M.Cobblestone, Cliff = M.Basalt, Hill = 36, Wall = 62, Pond = "Water", Glow = true,
		Trees = {"GlowShroom", "CaveCrystal"}, TreeCount = 380, Small = {"CaveCrystal", "MossyRock", "Rocks", "GlowShroom"}, SmallCount = 330},
	Volcano = {Ground = M.Basalt, Alt = M.CrackedLava, Path = M.Slate, Cliff = M.Rock, Hill = 22, Wall = 52, Pond = "Lava",
		Trees = {"DeadTree"}, TreeCount = 280, Small = {"LavaRock", "Rocks", "LavaRock"}, SmallCount = 360},
}
local GLOW = {CaveCrystal = Color3.fromRGB(200, 120, 255), GlowShroom = Color3.fromRGB(90, 220, 255), IceCrystal = Color3.fromRGB(170, 225, 255),
	LavaRock = Color3.fromRGB(255, 140, 60)}

-- resources each terrain gives (from the gather nodes that live there)
local NODES_OF, RES_OF = {}, {}
for key, def in Data.Nodes do
	if def.Biome then
		NODES_OF[def.Biome] = NODES_OF[def.Biome] or {}
		table.insert(NODES_OF[def.Biome], key)
		RES_OF[def.Biome] = RES_OF[def.Biome] or {}
		if not table.find(RES_OF[def.Biome], def.Res) then table.insert(RES_OF[def.Biome], def.Res) end
	end
end

---------------------------------------------------------------- the seeded map
local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function distSeg(p, a, b)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

-- the layout: a long winding main trail from the spawn glade (south) to the treasure grove + boss den (north) with
-- glades on the way, and side trails (some branch again) out to pockets: ponds, rich resource fields, quiet nooks.
-- Everything comes from Random.new(seed), so the same map number always makes the same map.
local function makeLayout(seed, style)
	local rng = Random.new(seed)
	local H = CFG.Half
	local L = {rng = rng, ox = rng:NextNumber(-5000, 5000), oz = rng:NextNumber(-5000, 5000), style = style}
	local n = rng:NextInteger(9, 12)
	local pts = {}
	local x = rng:NextNumber(-60, 60)
	for i = 0, n - 1 do
		local z = -(H - 45) + (2 * H - 100) * i / (n - 1)
		if i > 0 then x = math.clamp(x + rng:NextNumber(-170, 170), -(H - 130), H - 130) end
		table.insert(pts, Vector2.new(x, z))
	end
	L.pts = pts
	L.segs, L.clear = {}, {}
	for i = 1, n - 1 do table.insert(L.segs, {pts[i], pts[i + 1], 8}) end
	table.insert(L.clear, {pos = pts[1], r = 24, kind = "Spawn"})
	table.insert(L.clear, {pos = pts[n], r = 36, kind = "Treasure"})
	for i = 2, n - 1 do table.insert(L.clear, {pos = pts[i], r = rng:NextNumber(18, 28), kind = "Glade"}) end
	-- side trails out to pockets
	local function free(p, r)
		for _, c in L.clear do
			if (p - c.pos).Magnitude < c.r + r + 30 then return false end
		end
		return true
	end
	local ends = {}
	local want = rng:NextInteger(9, 13)
	local tries = 0
	while #ends < want and tries < want * 12 do
		tries += 1
		local from = (#ends > 2 and rng:NextNumber() < 0.35) and ends[rng:NextInteger(1, #ends)] or pts[rng:NextInteger(2, n - 1)]
		local ang, len = rng:NextNumber(0, math.pi * 2), rng:NextNumber(110, 260)
		local to = from + Vector2.new(math.cos(ang), math.sin(ang)) * len
		to = Vector2.new(math.clamp(to.X, -(H - 95), H - 95), math.clamp(to.Y, -(H - 95), H - 95))
		local r = rng:NextNumber(18, 27)
		if free(to, r) then
			local kind = #ends < 2 and "Pond" or (#ends < 4 and "Rich" or (rng:NextNumber() < 0.15 and "Pond" or "Pocket"))
			table.insert(L.segs, {from, to, 6})
			table.insert(L.clear, {pos = to, r = r, kind = kind})
			table.insert(ends, to)
		end
	end
	return L
end

local function fbm(L, x, z, f)
	local s, a, fr = 0, 1, f
	for _ = 1, 3 do
		s += a * math.noise(x * fr + L.ox, z * fr + L.oz)
		a *= 0.5
		fr *= 2
	end
	return s
end

-- height (local studs, world y) and distances to the trail / glades for a local x, z
local function sample(L, x, z)
	local p = Vector2.new(x, z)
	local dPath = math.huge
	for _, s in L.segs do
		local d = distSeg(p, s[1], s[2]) - s[3]
		if d < dPath then dPath = d end
	end
	local dClear, near = math.huge, nil
	for _, c in L.clear do
		local d = (p - c.pos).Magnitude - c.r
		if d < dClear then dClear, near = d, c end
	end
	local st = L.style
	local base = 8 + 3 * fbm(L, x, z, 1 / 90)
	local hills = st.Hill * math.max(0, 0.6 + 0.5 * fbm(L, x + 311, z - 97, 1 / 55))
	local open = smooth(math.min(dPath, dClear) / 26)
	local edge = smooth((math.max(math.abs(x), math.abs(z)) - (CFG.Half - 48)) / 40)
	local h = base + hills * open + st.Wall * edge
	local pond
	if near and near.kind == "Pond" then -- a round dip in the middle of the pond pocket
		local d = (p - near.pos).Magnitude
		local pr = near.r * 0.62
		if d < pr then
			near.level = near.level or (8 + 3 * fbm(L, near.pos.X, near.pos.Y, 1 / 90) - 0.6)
			h = math.min(h, near.level - 3.2 * (1 - (d / pr) ^ 2) + 0.2)
			pond = near
		end
	end
	return math.clamp(h, 1, 76), dPath, dClear, pond
end

local VOX = 4
local YMIN, YMAX = -8, 80
local function writeTerrain(L, origin)
	local half = CFG.Half
	local nx = (half * 2) // VOX
	local ny = (YMAX - YMIN) // VOX
	local st = L.style
	-- surface heights + materials per column
	local H, MAT, WL = {}, {}, {}
	for i = 1, nx do
		H[i], MAT[i], WL[i] = {}, {}, {}
		local x = -half + (i - 0.5) * VOX
		for k = 1, nx do
			local z = -half + (k - 0.5) * VOX
			local h, dPath, dClear, pond = sample(L, x, z)
			H[i][k] = h
			local m = st.Ground
			if dPath < 0 and math.noise(x / 9 + L.ox, z / 9) > dPath / 6 - 0.4 then
				m = st.Path
			elseif dPath > 2 and dClear > 2 and fbm(L, x - 777, z + 555, 1 / 38) > 0.32 then
				m = st.Alt
			end
			if pond then
				WL[i][k] = pond.level
				if st.Pond == "Ice" then m = M.Glacier elseif st.Pond == "Lava" then m = M.CrackedLava else m = M.Sand end
			end
			MAT[i][k] = m
		end
		if i % 20 == 0 then task.wait() end
	end
	-- steep spots turn to rock (and snow caps on the peaks)
	for i = 1, nx do
		for k = 1, nx do
			local h = H[i][k]
			local s = 0
			if i > 1 then s = math.max(s, math.abs(h - H[i - 1][k])) end
			if k > 1 then s = math.max(s, math.abs(h - H[i][k - 1])) end
			if i < nx then s = math.max(s, math.abs(h - H[i + 1][k])) end
			if k < nx then s = math.max(s, math.abs(h - H[i][k + 1])) end
			if s > 5.5 and not WL[i][k] then MAT[i][k] = st.Cliff end
			if L.style == STYLE.Peaks and h > 34 and s < 7 then MAT[i][k] = M.Snow end
		end
	end
	-- write in strips
	local STRIP = 20
	for i0 = 1, nx, STRIP do
		local w = math.min(STRIP, nx - i0 + 1)
		local mats, occ = {}, {}
		for a = 1, w do
			local i = i0 + a - 1
			mats[a], occ[a] = {}, {}
			for b = 1, ny do
				mats[a][b], occ[a][b] = {}, {}
				local y0 = YMIN + (b - 1) * VOX
				for k = 1, nx do
					local h = H[i][k]
					local o = math.clamp((h - y0) / VOX, 0, 1)
					local m = h - y0 > VOX * 2.5 and st.Cliff or MAT[i][k]
					local wl = WL[i][k]
					if o <= 0 and wl and y0 < wl and L.style.Pond == "Water" then
						m, o = M.Water, math.clamp((wl - y0) / VOX, 0, 1)
					elseif o <= 0 then
						m = M.Air
					end
					mats[a][b][k], occ[a][b][k] = m, o
				end
			end
		end
		local lo = Vector3.new(origin.X - half + (i0 - 1) * VOX, YMIN, origin.Z - half)
		local region = Region3.new(lo, lo + Vector3.new(w * VOX, ny * VOX, nx * VOX))
		Terrain:WriteVoxels(region, VOX, mats, occ)
		task.wait()
	end
end

---------------------------------------------------------------- props
local bottomCache = {}
local function bottomOffset(t) -- pivot height above the model's lowest point
	if bottomCache[t] then return bottomCache[t] end
	local cf, size = t:GetBoundingBox()
	local off = t:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
	bottomCache[t] = off
	return off
end
local function placeProp(name, parent, x, y, z, scale, rng, sink)
	local t = template(name)
	if not t then return nil end
	local m = t:Clone()
	m.Name = name
	local s = scale or 1
	if math.abs(s - 1) > 0.01 then m:ScaleTo(m:GetScale() * s) end
	local off = bottomOffset(t) * s
	m:PivotTo(CFrame.new(x, y + off - (sink or 0.4), z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
			if d.Size.Magnitude < 6 then d.CanCollide = false end
		end
	end
	m.Parent = parent
	return m
end
local function glow(m, color, range)
	local main = m:FindFirstChildWhichIsA("BasePart", true)
	if not main then return end
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range or 14, 1.4, false
	l.Parent = main
end

local function P(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end
local function label(part, text, color, maxDist)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 60)
	bb.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 3, 0)
	bb.MaxDistance = maxDist or 160
	bb.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = color
	t.BackgroundTransparency = 0.1
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.Parent = bb
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 12)
	return bb
end

-- the way home: a small portal arch at the spawn glade
local function exitPortal(parent, cf, def)
	local m = Instance.new("Model")
	m.Name = "ExitPortal"
	local stone = Color3.fromRGB(150, 140, 175)
	P(m, {Name = "Base", Size = Vector3.new(14, 1, 6), CFrame = cf * CFrame.new(0, 0.2, 0), Color = stone, Material = M.Slate})
	for _, x in {-6, 6} do
		P(m, {Name = "Pillar", Size = Vector3.new(2.2, 13, 2.2), CFrame = cf * CFrame.new(x, 7, 0), Color = stone, Material = M.Slate})
		P(m, {Name = "Cap", Size = Vector3.new(2.8, 0.8, 2.8), CFrame = cf * CFrame.new(x, 13.9, 0), Color = def.Color, Material = M.Neon})
	end
	local top = P(m, {Name = "Top", Size = Vector3.new(15, 2, 2.6), CFrame = cf * CFrame.new(0, 14.8, 0), Color = stone, Material = M.Slate})
	P(m, {Name = "Swirl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 10.5, 10.5), CFrame = cf * CFrame.new(0, 7, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Color3.fromRGB(150, 110, 255), Material = M.Neon, Transparency = 0.3, CanCollide = false, CanQuery = false})
	local gate = P(m, {Name = "Gate", Size = Vector3.new(9, 11, 3), CFrame = cf * CFrame.new(0, 6.5, 0), Transparency = 1, CanCollide = false, CanQuery = false})
	m.Parent = parent
	return m, gate
end

-- the goal: a treasure chest in the last glade (each explorer opens it once)
local function treasure(parent, cf, def, scale)
	local m = Instance.new("Model")
	m.Name = "Treasure"
	local wood, gold = Color3.fromRGB(150, 95, 55), Color3.fromRGB(255, 205, 70)
	local box = P(m, {Name = "Box", Size = Vector3.new(5, 3, 3.4), CFrame = cf * CFrame.new(0, 1.5, 0), Color = wood, Material = M.Wood})
	P(m, {Name = "Lid", Size = Vector3.new(5.2, 1.4, 3.6), CFrame = cf * CFrame.new(0, 3.7, 0), Color = wood:Lerp(Color3.new(1, 1, 1), 0.1), Material = M.Wood})
	P(m, {Size = Vector3.new(5.3, 0.4, 3.7), CFrame = cf * CFrame.new(0, 3, 0), Color = gold, Material = M.Metal})
	for _, x in {-1.8, 1.8} do P(m, {Size = Vector3.new(0.45, 4.6, 3.7), CFrame = cf * CFrame.new(x, 2.3, 0), Color = gold, Material = M.Metal}) end
	P(m, {Name = "Lock", Size = Vector3.new(0.8, 1, 0.4), CFrame = cf * CFrame.new(0, 2.8, -1.9), Color = gold, Material = M.Neon})
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
	pe.Size = NumberSequence.new(0.6, 0)
	pe.Rate, pe.Lifetime, pe.Speed = 10, NumberRange.new(1, 1.6), NumberRange.new(1, 3)
	pe.SpreadAngle = Vector2.new(60, 60)
	pe.LightEmission = 1
	pe.Parent = box
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = gold, 16, 1.5
	l.Parent = box
	if scale and scale ~= 1 then
		m.WorldPivot = cf
		m:ScaleTo(scale)
	end
	m.Parent = parent
	return m, box
end

-- 🪧 signs: the same minimal chips as town (white icon that opens to show the name, drawn by CritterWorld).
-- A chip is a tiny invisible part in CritterAcres.TownChips with Icon + Label attributes.
local function chip(run, pos, icon, text)
	local p = P(root:WaitForChild("TownChips"), {Name = "Chip", Size = Vector3.one * 0.5, Position = pos, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
	p:SetAttribute("Icon", icon)
	p:SetAttribute("Label", text)
	table.insert(run.chips, p)
	return p
end

---------------------------------------------------------------- runs (one generated map each)
local runs = {} -- slot -> run
local runOf = {} -- player -> run they are inside
local parties = {} -- party tables
local partyOf = {} -- player -> party
local invites = {} -- target player -> {[fromUserId] = {party, at}}
local buddyOf = {} -- player -> pet Id that comes along (nil = alone)
API.pointPickers = API.pointPickers or {}
API.travelSpots = API.travelSpots or {}

local function portalOut()
	local tp = root:FindFirstChild("TerrainPortal")
	local out = tp and tp:FindFirstChild("Out")
	return out and out.Position or Vector3.new(4, API.GROUND_Y, -40)
end
API.travelSpots.TerrainPortal = portalOut()
-- 🏰 the Dungeon Portal is a stop in the 🌀 portal picker too (just in front of its gate)
local function dungeonOut()
	local dp = root:FindFirstChild("DungeonPortal")
	local out = dp and dp:FindFirstChild("Out")
	return out and out.Position or nil
end
API.travelSpots.DungeonPortal = dungeonOut()
local pond = root:FindFirstChild("FishingPond")
if pond then
	local cf, size = pond:GetBoundingBox()
	API.travelSpots.Pond = cf.Position + Vector3.new(size.X / 2 + 6, 0, 0)
end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

local function knock(player, from, power)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local dir = (hrp.Position - from) * Vector3.new(1, 0, 1)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
	API.reveal(player, {Kind = "Knock", Dir = dir, Power = power})
end

local function buildMap(run)
	local def = Data.BiomeByName[run.terrain]
	local st = STYLE[run.terrain]
	local L = makeLayout(run.seed, st)
	local rng = L.rng
	local O = run.origin
	run.layout = L
	writeTerrain(L, O)
	local folder = run.folder
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = {Terrain}
	local function world(x, z)
		local h = sample(L, x, z)
		local hit = workspace:Raycast(Vector3.new(O.X + x, YMAX + 20, O.Z + z), Vector3.new(0, -(YMAX - YMIN + 40), 0), rp)
		if hit then h = hit.Position.Y end
		return O.X + x, h, O.Z + z
	end
	-- glades
	local spawnC, treasureC
	for _, c in L.clear do
		if c.kind == "Spawn" then spawnC = c elseif c.kind == "Treasure" then treasureC = c end
	end
	-- exit portal faces up the trail
	local sx, sy, sz = world(spawnC.pos.X, spawnC.pos.Y - 8)
	local look = (L.pts[2] - L.pts[1]).Unit
	local pcf = CFrame.lookAt(Vector3.new(sx, sy, sz), Vector3.new(sx + look.X, sy, sz + look.Y))
	local _, gate = exitPortal(folder, pcf, def)
	run.spawnPos = (pcf * CFrame.new(0, 0, -9)).Position
	gate.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and runOf[player] == run and os.clock() - (run.arrived[player] or 0) > 3 then
			run.leave(player, "portal")
		end
	end)
	-- chests: the big treasure at the end, small supply stashes in some pockets (each explorer opens each one once)
	local function chest(cf, big)
		local _, box = treasure(folder, cf, def, big and 1 or 0.7)
		local seen = {}
		local prompt = API.makePrompt(box, big and "🎁 Open" or "🧺 Open", big and "Treasure" or "Supply stash")
		prompt.MaxActivationDistance = 12
		prompt.Triggered:Connect(function(player)
			if runOf[player] ~= run then return end
			if seen[player.UserId] then
				API.toast(player, big and "🎁 You already opened this one. A new map has a new treasure!" or "🧺 You already took this stash. Find another one!")
				return
			end
			seen[player.UserId] = true
			local got = {}
			if big then
				local coins = CFG.ChestCoins[run.terrain] or 60
				API.addCoins(player, coins)
				table.insert(got, ("💰 +%d"):format(coins))
			end
			if API.giveCapsule and (big or rng:NextNumber() < 0.15) then
				API.giveCapsule(player, run.terrain, 1)
				local cap = Data.Capsules[run.terrain]
				if cap then table.insert(got, cap.Icon .. " " .. cap.Name) end
			end
			for _, res in RES_OF[run.terrain] or {} do
				local n = big and rng:NextInteger(3, 6) or rng:NextInteger(1, 3)
				API.addRes(player, res, n)
				table.insert(got, ("%s +%d"):format(Data.ResByName[res] and Data.ResByName[res].Icon or "📦", n))
			end
			API.pop(box, big and "🎉" or "✨")
			API.toast(player, (big and "🎁 Treasure! " or "🧺 Supply stash! ") .. table.concat(got, "  "))
			if big then API.questEvent(player, "Explore", 1) end
		end)
		return box
	end
	local tx, ty, tz = world(treasureC.pos.X, treasureC.pos.Y)
	local tcf = CFrame.lookAt(Vector3.new(tx, ty, tz), Vector3.new(sx, ty, sz))
	chest(tcf, true)
	chip(run, (pcf * CFrame.new(0, 18, 0)).Position, "🏠", "Back to town")
	chip(run, (tcf * CFrame.new(0, 9, 0)).Position, "🎁", "Treasure")
	-- mobs of this land (any models in ServerStorage.MobModels.<Land>; MobAnimator brings them to life on each screen)
	local MOBS = ServerStorage:FindFirstChild("MobModels") and ServerStorage.MobModels:FindFirstChild(run.terrain)
	local normal, special, boss = {}, {}, nil
	for _, t in MOBS and MOBS:GetChildren() or {} do
		if t:IsA("Model") then
			if t:GetAttribute("Boss") then boss = t elseif t:GetAttribute("Special") then table.insert(special, t) else table.insert(normal, t) end
		end
	end
	-- how deep in the map a spot is: 0 near the start, 2 near the treasure + boss den (Combat: +0..2 mob levels)
	local trip = math.max(1, (Vector2.new(tx, tz) - Vector2.new(sx, sz)).Magnitude)
	local function depthAt(wx, wz)
		return math.clamp(math.floor((Vector2.new(wx, wz) - Vector2.new(sx, sz)).Magnitude / trip * 3), 0, 2)
	end
	local function mob(t, x, z, roam, yaw, herd, role)
		local wx, wy, wz = world(x, z)
		local m = t:Clone()
		m:PivotTo(CFrame.new(wx, wy + bottomOffset(t), wz) * CFrame.Angles(0, yaw or rng:NextNumber(0, math.pi * 2), 0))
		m:SetAttribute("Roam", roam)
		if herd then m:SetAttribute("Herd", herd) end
		m:SetAttribute("Depth", depthAt(wx, wz))
		if role then m:SetAttribute("Role", role) end
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then d.Anchored = true end
		end
		CollectionService:AddTag(m, "MobRig")
		m.Parent = folder
		if API.combatAddMob then API.combatAddMob(run, m, t) end
		return m
	end
	-- the boss den beside the treasure: the land's boss waits there (or a marker until it has one)
	local den = tcf * CFrame.new(16, 0, 6)
	local dx, dz = den.X - O.X, den.Z - O.Z
	if boss then
		mob(boss, dx, dz, 3, math.atan2(-(sx - den.X), -(sz - den.Z)))
		chip(run, Vector3.new(den.X, den.Y + 18, den.Z), "👑", boss.Name:gsub("(%l)(%u)", "%1 %2"))
	else
		placeProp("Rocks", folder, den.X, den.Y, den.Z, 1.6, rng)
		chip(run, (den * CFrame.new(0, 8, 0)).Position, "👑", "Boss den · soon")
	end
	-- mob groups in the glades and pockets. Kinds marked HerdKind come as a herd (3-5 of one kind that travel
	-- together, attribute Herd = group id, MobAnimator does the following); the rest come as a loose mixed group.
	if #normal > 0 then
		local herdN = 0
		local function kindOf(t) return t:GetAttribute("MobKind") or t.Name end
		for _, c in L.clear do
			local chance = c.kind == "Rich" and 1 or (c.kind == "Pocket" and 0.75 or (c.kind == "Glade" and 0.6 or 0))
			if rng:NextNumber() < chance then
				local first = normal[rng:NextInteger(1, #normal)]
				if first:GetAttribute("HerdKind") and rng:NextNumber() < 0.75 then
					herdN += 1
					local id = "H" .. herdN
					local sp = {}
					for _, s in special do if kindOf(s) == kindOf(first) then table.insert(sp, s) end end
					local roam = math.clamp(c.r * 0.8, 12, 24)
					local a0 = rng:NextNumber(0, math.pi * 2)
					local cx, cz = c.pos.X + math.cos(a0) * c.r * 0.25, c.pos.Y + math.sin(a0) * c.r * 0.25
					for i = 1, rng:NextInteger(3, 5) do
						local t = (#sp > 0 and rng:NextNumber() < 0.07) and sp[rng:NextInteger(1, #sp)] or first
						local ang, r = rng:NextNumber(0, math.pi * 2), i == 1 and 0 or rng:NextNumber(2.5, 6)
						-- 🏹 some of the group shoot from afar (never the leader, so the group still charges in)
						local role = i > 1 and rng:NextNumber() < Data.MobRanged.Chance and "Ranged" or nil
						mob(t, cx + math.cos(ang) * r, cz + math.sin(ang) * r, roam, a0, run.key .. id, role)
					end
				else
					local roam = math.clamp(c.r * 0.45, 6, 12)
					for i = 1, rng:NextInteger(2, 4) do
						local list = (#special > 0 and rng:NextNumber() < 0.07) and special or normal
						local ang, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, c.r * 0.55)
						local role = i > 1 and rng:NextNumber() < Data.MobRanged.Chance and "Ranged" or nil
						mob(list[rng:NextInteger(1, #list)], c.pos.X + math.cos(ang) * r, c.pos.Y + math.sin(ang) * r, roam, nil, nil, role)
					end
				end
			end
		end
	end
	-- 🧺 supply stashes in some pockets
	for _, c in L.clear do
		if (c.kind == "Pocket" and rng:NextNumber() < 0.5) or (c.kind == "Rich" and rng:NextNumber() < 0.35) then
			local ang = rng:NextNumber(0, math.pi * 2)
			local x, z = c.pos.X + math.cos(ang) * c.r * 0.3, c.pos.Y + math.sin(ang) * c.r * 0.3
			local wx, wy, wz = world(x, z)
			chest(CFrame.new(wx, wy, wz) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), false)
		end
	end
	-- a ring of pretty things around the grove
	for a = 0, 7 do
		local ang = a / 8 * math.pi * 2
		local x, z = treasureC.pos.X + math.cos(ang) * (treasureC.r - 3), treasureC.pos.Y + math.sin(ang) * (treasureC.r - 3)
		local wx, wy, wz = world(x, z)
		local name = st.Small[rng:NextInteger(1, #st.Small)]
		local m = placeProp(name, folder, wx, wy, wz, rng:NextNumber(1, 1.4), rng)
		if m and st.Glow and GLOW[name] then glow(m, GLOW[name]) end
	end
	task.wait()
	-- ponds: lava pools push you back, ice ponds are slippery fun
	for _, c in L.clear do
		if c.kind == "Pond" and c.level and st.Pond == "Lava" then
			local wx, _, wz = world(c.pos.X, c.pos.Y)
			local lava = P(folder, {Name = "Lava", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, c.r * 1.2, c.r * 1.2),
				CFrame = CFrame.new(wx, c.level - 0.3, wz) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 110, 30), Material = M.Neon, CanCollide = false})
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = Color3.fromRGB(255, 120, 40), 30, 2
			l.Parent = lava
			local hot = {}
			lava.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player and os.clock() - (hot[player] or 0) > 1.5 then
					hot[player] = os.clock()
					knock(player, lava.Position, 70)
					API.toast(player, "🔥 Hot hot hot! Stay out of the lava!")
				end
			end)
		elseif c.kind == "Pond" and c.level and st.Pond == "Water" then
			for _ = 1, rng:NextInteger(3, 6) do
				local ang, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, c.r * 0.5)
				placeProp("LilyPad", folder, O.X + c.pos.X + math.cos(ang) * r, c.level + 0.15, O.Z + c.pos.Y + math.sin(ang) * r, rng:NextNumber(0.8, 1.2), rng, 0)
			end
			for _ = 1, 5 do
				local ang = rng:NextNumber(0, math.pi * 2)
				local x, z = c.pos.X + math.cos(ang) * c.r * 0.68, c.pos.Y + math.sin(ang) * c.r * 0.68
				local wx, wy, wz = world(x, z)
				placeProp("Reeds", folder, wx, wy, wz, rng:NextNumber(0.8, 1.2), rng)
			end
		end
	end
	-- trees and small things: off the trail, mostly close enough to be seen from it
	local lights = 0
	local function scatter(list, n, minOpen, maxOpen, scaleLo, scaleHi)
		local placed, tries = 0, 0
		while placed < n and tries < n * 6 do
			tries += 1
			local x, z = rng:NextNumber(-CFG.Half + 12, CFG.Half - 12), rng:NextNumber(-CFG.Half + 12, CFG.Half - 12)
			local h, dPath, dClear, inPond = sample(L, x, z)
			local d = math.min(dPath, dClear)
			if not inPond and d > minOpen and d < maxOpen and h < 70 then
				local name = list[rng:NextInteger(1, #list)]
				local m = placeProp(name, folder, O.X + x, h, O.Z + z, rng:NextNumber(scaleLo, scaleHi), rng)
				if m then
					placed += 1
					if st.Glow and GLOW[name] and lights < 28 and d < 30 then
						lights += 1
						glow(m, GLOW[name], 18)
					end
				end
				if placed % 25 == 0 then task.wait() end
			end
		end
	end
	scatter(st.Trees, st.TreeCount, 4, 70, 0.85, 1.35)
	scatter(st.Small, st.SmallCount, 1.5, 40, 0.8, 1.3)
	task.wait()
	-- resource nodes: in every glade, lots in pockets, a field of them in "rich" pockets, and some along the trails
	local kinds = NODES_OF[run.terrain] or {}
	local NF = RPROPS and RPROPS:FindFirstChild("Nodes")
	local function node(x, z)
		local key = kinds[rng:NextInteger(1, #kinds)]
		local t = NF and NF:FindFirstChild(key)
		if not t then return end
		local wx, wy, wz = world(x, z)
		local m = t:Clone()
		m:PivotTo(CFrame.new(wx, wy + bottomOffset(t) - 0.2, wz) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		m.Parent = folder
		if API.setupNode then API.setupNode(m) end
	end
	if #kinds > 0 then
		local PER = {Glade = {3, 4}, Pocket = {5, 7}, Rich = {10, 14}, Treasure = {3, 4}}
		for _, c in L.clear do
			local per = PER[c.kind]
			if per then
				for _ = 1, rng:NextInteger(per[1], per[2]) do
					local ang, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(c.r * 0.4, c.r * 0.9)
					node(c.pos.X + math.cos(ang) * r, c.pos.Y + math.sin(ang) * r)
				end
			end
		end
		for _, s in L.segs do
			local len = (s[2] - s[1]).Magnitude
			local dir = (s[2] - s[1]).Unit
			local side = Vector2.new(-dir.Y, dir.X)
			for d = 30, len - 30, 40 do
				if rng:NextNumber() < 0.4 then
					local p = s[1] + dir * d + side * (rng:NextNumber() < 0.5 and -1 or 1) * (s[3] + rng:NextNumber(4, 9))
					node(p.X, p.Y)
				end
			end
			task.wait()
		end
	end
	-- invisible walls at the map edge (the border mountains already block most of it)
	for _, w in {{0, -1}, {0, 1}, {-1, 0}, {1, 0}} do
		local size = w[1] == 0 and Vector3.new(CFG.Half * 2, 220, 4) or Vector3.new(4, 220, CFG.Half * 2)
		P(folder, {Name = "Edge", Size = size, Position = Vector3.new(O.X + w[1] * (CFG.Half - 6), 100, O.Z + w[2] * (CFG.Half - 6)), Transparency = 1, CanQuery = false})
	end
	-- a box for flying critters (FarmServer's skyPoint uses biomeParts[key])
	run.ground = P(folder, {Name = "RealmGround", Size = Vector3.new(CFG.Half * 2 - 160, 1, CFG.Half * 2 - 160), Position = Vector3.new(O.X, 0, O.Z), Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false})
end

-- a walkable spot for wild critters: inside a glade, a pocket, or on the trail
local function pickPoint(run)
	local L = run.layout
	local rng = Random.new()
	for _ = 1, 8 do
		local c = L.clear[rng:NextInteger(1, #L.clear)]
		if c.kind ~= "Pond" and c.kind ~= "Spawn" then
			local ang, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * c.r * 0.8
			return Vector3.new(run.origin.X + c.pos.X + math.cos(ang) * r, 0, run.origin.Z + c.pos.Y + math.sin(ang) * r)
		end
	end
	local s = L.segs[rng:NextInteger(1, #L.segs)]
	local p = s[1]:Lerp(s[2], rng:NextNumber())
	return Vector3.new(run.origin.X + p.X, 0, run.origin.Z + p.Y)
end

local function freeSlot()
	for i = 1, CFG.Slots do
		if not runs[i] then return i end
	end
end

local function partyView(party)
	if not party then return nil end
	local members = {}
	for _, m in party.members do
		table.insert(members, {UserId = m.UserId, Name = m.DisplayName, Leader = m == party.leader, Inside = party.run ~= nil and runOf[m] == party.run})
	end
	return {Leader = party.leader.UserId, Terrain = party.terrain, Members = members, Running = party.run ~= nil and party.run.terrain or nil,
		Seed = party.run and party.run.seed, Mode = party.mode, Tier = party.tier, RunMode = party.run and (party.run.tier and "Dungeon" or "Realm") or nil}
end
local function push(player)
	remote:FireClient(player, {Kind = "Party", Party = partyView(partyOf[player])})
end
local function pushParty(party)
	for _, m in party.members do push(m) end
end

local function wipe(run)
	if runs[run.slot] ~= run then return end
	runs[run.slot] = nil
	API.biomeParts[run.key] = nil
	API.pointPickers[run.key] = nil
	for c in API.critters do
		if c.biome == run.key and not c.owner then pcall(API.removeCritter, c) end
	end
	if API.combatRunGone then pcall(API.combatRunGone, run) end
	run.folder:Destroy()
	for _, c in run.chips do c:Destroy() end
	Terrain:FillBlock(CFrame.new(run.origin.X, (YMIN + YMAX) / 2, run.origin.Z), Vector3.new(CFG.Half * 2 + 8, YMAX - YMIN + 8, CFG.Half * 2 + 8), M.Air)
	if run.party and run.party.run == run then
		run.party.run = nil
		pushParty(run.party)
	end
end

local function newRun(party)
	local slot = freeSlot()
	if not slot then return nil, "🌀 All the wild lands are busy. Try again in a minute!" end
	local col, row = (slot - 1) % 4, (slot - 1) // 4
	local run = {slot = slot, key = "Realm" .. slot, terrain = party.terrain, seed = math.random(1, 999999), party = party,
		origin = Vector3.new(CFG.SlotX + col * CFG.SlotGap, 0, CFG.SlotZ + row * CFG.SlotGap), inside = {}, arrived = {}, opened = {}, chips = {}, prevFollow = {}}
	run.folder = Instance.new("Folder")
	run.folder.Name = run.key .. "_" .. run.terrain
	run.folder:SetAttribute("Terrain", run.terrain)
	run.folder:SetAttribute("Seed", run.seed)
	run.folder.Parent = workspace
	runs[slot] = run
	party.run = run
	-- 🏰 a dungeon party gets a maze from ServerScriptService.Dungeons instead of a land map
	if party.mode == "Dungeon" then
		run.tier, run.paid = party.tier or 1, {}
		run.folder:SetAttribute("Dungeon", true)
	end
	local ok, err = pcall(run.tier and API.buildDungeon or buildMap, run)
	if not ok then
		warn("[Realms] map build failed", err)
		wipe(run)
		return nil, "🌀 The portal fizzled. Try again!"
	end
	API.biomeParts[run.key] = run.ground
	API.pointPickers[run.key] = function() return run.pickPoint and run.pickPoint() or pickPoint(run) end
	run.ready = true
	function run.leave(player, why)
		if runOf[player] ~= run then return end
		runOf[player] = nil
		run.inside[player] = nil
		player:SetAttribute("Realm", nil)
		player:SetAttribute("RealmSeed", nil)
		player:SetAttribute("RealmBuddy", nil)
		player:SetAttribute("Dungeon", nil)
		local prof = API.profiles[player]
		if prof and run.prevFollow[player] ~= nil then
			prof.FollowId = run.prevFollow[player] or nil
			if prof.FollowId == false then prof.FollowId = nil end
		end
		run.prevFollow[player] = nil
		if API.combatLeft then pcall(API.combatLeft, player) end
		if why ~= "died" and why ~= "gone" then API.teleportTo(player, portalOut()) end
		if why == "portal" or why == "button" then API.toast(player, "🏠 Back in town! Come explore again soon.") end
		if run.party then pushParty(run.party) end
		if not next(run.inside) then
			task.delay(CFG.EmptyWipe, function()
				if not next(run.inside) then wipe(run) end
			end)
		end
	end
	return run
end

local function sendIn(player, run)
	local old = runOf[player]
	if old and old ~= run then old.leave(player, "gone") end
	runOf[player] = run
	run.inside[player] = true
	run.arrived[player] = os.clock()
	player:SetAttribute("Realm", run.terrain)
	player:SetAttribute("RealmSeed", run.seed)
	if run.tier then player:SetAttribute("Dungeon", run.tier) end
	-- the buddy pet you picked trots along (FollowId), the one that followed you before comes back after
	local prof = API.profiles[player]
	local bid = buddyOf[player]
	local rec = prof and bid and API.findRec(prof, bid)
	if rec and not rec.Trip and not rec.Stored and not API.isResting(rec) then
		if run.prevFollow[player] == nil then run.prevFollow[player] = prof.FollowId or false end
		prof.FollowId = bid
		local c = API.critterFor(rec)
		if c then c.version += 1 c.speedBoost = nil end
		player:SetAttribute("RealmBuddy", bid)
	end
	local a = math.random() * math.pi * 2
	API.teleportTo(player, run.spawnPos + Vector3.new(math.cos(a) * 3, 0, math.sin(a) * 3))
	API.questEvent(player, "Explore", 1)
	if run.party then pushParty(run.party) end
end

---------------------------------------------------------------- parties
local function newParty(player)
	local party = {leader = player, members = {player}, terrain = "Meadow", mode = "Realm", tier = 1}
	table.insert(parties, party)
	partyOf[player] = party
	return party
end
local function leaveParty(player, why)
	local party = partyOf[player]
	if not party then return end
	partyOf[player] = nil
	local i = table.find(party.members, player)
	if i then table.remove(party.members, i) end
	if party.run and runOf[player] == party.run then party.run.leave(player, why) end
	if #party.members == 0 then
		local k = table.find(parties, party)
		if k then table.remove(parties, k) end
		if party.run then party.run.party = nil end
	else
		if party.leader == player then
			party.leader = party.members[1]
			API.toast(party.leader, "👑 You lead the party now.")
		end
		for _, m in party.members do API.toast(m, ("👋 %s left the party."):format(player.DisplayName)) end
		pushParty(party)
	end
	push(player)
end
local function nearPortal(player, mode)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local tp = root:FindFirstChild(mode == "Dungeon" and "DungeonPortal" or "TerrainPortal")
	if not hrp or not tp then return false end
	return (hrp.Position - tp:GetPivot().Position).Magnitude <= CFG.NearPortal
end
-- ⚡ raid energy for a dungeon (once per explorer per run). Returns an error text, or nil when paid.
local function payEnergy(player, run)
	if not run.tier or run.paid[player] then return nil end
	local prof = API.profiles[player]
	if not prof then return "❔" end
	if API.updateEnergy then API.updateEnergy(prof) end
	local cost = Data.Dungeon.Energy
	if (prof.Energy or 0) < cost then return ("⚡ Out of raid energy! You need %d. It refills 1 every hour."):format(cost) end
	if prof.Energy >= Data.EnergyMax then prof.EnergyAt = os.time() end
	prof.Energy -= cost
	run.paid[player] = true
	return nil
end
local function dungeonName(land, tier)
	local th = Data.Dungeon.Themes[land] or {}
	return ("%s %s ⭐%d"):format(th.Icon or "🏰", th.Name or land, tier or 1)
end
local function isOpen(prof, name, player)
	local g = Data.Gates[name]
	if not g then return true end
	if player and player:GetAttribute("DevOpenAll") then return true end -- (Studio dev menu: 🔓 every land + dungeon)
	if player then return API.farmLevelOf(player) >= g.Level end
	return (prof.Gates and prof.Gates[name]) == true
end
-- keep the old "Gates" list (map screen, travel) in step with the farm level
local function syncGates(player, prof)
	prof.Gates = prof.Gates or {}
	local open, new = {}, nil
	for name, g in Data.Gates do
		if API.farmLevelOf(player) >= g.Level and not prof.Gates[name] then
			prof.Gates[name] = true
			new = name
		end
		if prof.Gates[name] then table.insert(open, name) end
	end
	player:SetAttribute("Gates", table.concat(open, ","))
	if new then
		local def = Data.BiomeByName[new]
		API.toast(player, ("🔓 The %s %s is open! Visit the 🌀 Explorer's Portal to explore it."):format(def and def.Icon or "", new))
	end
end
task.spawn(function()
	while true do
		task.wait(3)
		for player, prof in API.profiles do
			if player.Parent then pcall(syncGates, player, prof) end
		end
	end
end)

local function mobsOf(land)
	local list = {}
	local f = ServerStorage:FindFirstChild("MobModels") and ServerStorage.MobModels:FindFirstChild(land)
	for _, t in f and f:GetChildren() or {} do
		if t:IsA("Model") then
			table.insert(list, {Name = (t.Name:gsub("(%l)(%u)", "%1 %2")), Boss = t:GetAttribute("Boss") or nil, Special = t:GetAttribute("Special") or nil})
		end
	end
	return list
end

---------------------------------------------------------------- actions (CritterAction remote)
function ACTIONS.RealmInfo(player, prof)
	local list = {}
	for _, b in Data.Biomes do
		local g = Data.Gates[b.Name]
		table.insert(list, {Name = b.Name, Icon = b.Icon, Color = b.Color, Species = b.Species, Res = RES_OF[b.Name] or {},
			Open = isOpen(prof, b.Name, player), Level = g and g.Level, Mobs = mobsOf(b.Name)})
	end
	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= player then
			local pp = partyOf[p]
			table.insert(others, {UserId = p.UserId, Name = p.DisplayName, InMine = pp ~= nil and pp == partyOf[player],
				Busy = runOf[p] ~= nil and pp ~= partyOf[player]})
		end
	end
	local inv = {}
	for fromId, v in invites[player] or {} do
		if os.clock() - v.at < CFG.InviteSecs and v.party.leader and table.find(parties, v.party) then
			table.insert(inv, {FromId = fromId, Name = v.from.DisplayName, Terrain = v.party.terrain})
		end
	end
	-- pets that can come along as a buddy (not on a trip, not in storage)
	local pets = {}
	for _, rec in prof.Pets or {} do
		if not rec.Trip and not rec.Stored then
			local sp = Data.SpeciesByName[rec.Species]
			table.insert(pets, {Id = rec.Id, Species = rec.Species, Name = rec.Name, Variant = rec.Variant, Rarity = sp and sp.Rarity or "Common",
				Level = API.petLevel(rec), Power = (Data.Rarities[sp and sp.Rarity or "Common"] or {Order = 1}).Order * 10 + API.petLevel(rec), Tired = API.isResting(rec) or nil})
		end
	end
	table.sort(pets, function(a, b) return (tonumber(a.Power) or 0) > (tonumber(b.Power) or 0) end)
	local bid = buddyOf[player]
	if bid and not API.findRec(prof, bid) then buddyOf[player] = nil bid = nil end
	-- 🏰 dungeons: one per land (same farm level lock), ⭐ tiers open one by one
	local dungeons = {}
	for _, b in Data.Biomes do
		local th = Data.Dungeon.Themes[b.Name]
		if th then
			local g = Data.Gates[b.Name]
			table.insert(dungeons, {Land = b.Name, Name = th.Name, Icon = th.Icon, Color = th.Accent, Open = isOpen(prof, b.Name, player), Level = g and g.Level,
				Best = (prof.DungeonTier or {})[b.Name] or 0, Mobs = mobsOf(b.Name)})
		end
	end
	if API.updateEnergy then API.updateEnergy(prof) end
	return {Terrains = list, Party = partyView(partyOf[player]), Players = others, Invites = inv, Max = CFG.PartyMax,
		Inside = runOf[player] and runOf[player].terrain or nil, Pets = pets, Buddy = bid,
		Dungeons = dungeons, Tiers = #Data.Dungeon.Tiers, Energy = prof.Energy, EnergyMax = Data.EnergyMax, EnergyCost = Data.Dungeon.Energy}
end

-- 🏰 pick a dungeon + ⭐ tier (the leader only; tier N needs tier N-1 cleared by the leader)
function ACTIONS.DungeonPick(player, prof, land, tier)
	if type(land) ~= "string" or not Data.Dungeon.Themes[land] then return "❔" end
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, #Data.Dungeon.Tiers)
	local party = partyOf[player] or newParty(player)
	if party.leader ~= player then return "👑 Only the party leader picks the dungeon." end
	if party.run then return "🌀 Your party is already out exploring. Join them or wait until they are back." end
	if not isOpen(prof, land, player) then return ("🔒 This dungeon opens at farm level %d. Keep farming!"):format(Data.Gates[land].Level) end
	local best = (prof.DungeonTier or {})[land] or 0
	if tier > best + 1 then return ("⭐ Clear ⭐%d first to open ⭐%d!"):format(tier - 1, tier) end
	party.mode, party.terrain, party.tier = "Dungeon", land, tier
	pushParty(party)
	return nil
end

-- pick the pet that comes along (nil = go alone)
function ACTIONS.RealmBuddy(player, prof, id)
	if id == nil then buddyOf[player] = nil return nil end
	local rec = API.findRec(prof, id)
	if not rec or rec.Trip or rec.Stored then return "🐾 That pet can't come right now." end
	if API.isResting(rec) then return "😴 That pet is napping. Pick another buddy!" end
	buddyOf[player] = id
	return nil
end

function ACTIONS.RealmPick(player, prof, name)
	if type(name) ~= "string" or not Data.BiomeByName[name] then return "❔" end
	local party = partyOf[player] or newParty(player)
	if party.leader ~= player then return "👑 Only the party leader picks where to go." end
	if party.run then return "🌀 Your party is already exploring. Join them or wait until they are back." end
	if not isOpen(prof, name, player) then return ("🔒 The %s opens at farm level %d. Keep farming!"):format(name, Data.Gates[name].Level) end
	party.terrain, party.mode = name, "Realm"
	pushParty(party)
	return nil
end

function ACTIONS.RealmOpenGate(player, prof, name) -- (old button) lands open by farm level now
	local g = type(name) == "string" and Data.Gates[name]
	if not g then return "❔" end
	if API.farmLevelOf(player) < g.Level then return ("🔒 The %s opens at farm level %d. Keep farming!"):format(name, g.Level) end
	syncGates(player, prof)
	return nil
end

function ACTIONS.PartyInvite(player, prof, userId)
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not target or target == player then return "❔" end
	local party = partyOf[player] or newParty(player)
	if party.leader ~= player then return "👑 Only the party leader can invite." end
	if #party.members >= CFG.PartyMax then return ("👫 A party can have %d explorers."):format(CFG.PartyMax) end
	if partyOf[target] == party then return nil end
	invites[target] = invites[target] or {}
	invites[target][player.UserId] = {party = party, from = player, at = os.clock()}
	remote:FireClient(target, {Kind = "Invite", FromId = player.UserId, Name = player.DisplayName, Terrain = party.terrain, Secs = CFG.InviteSecs})
	return ("💌 Invite sent to %s!"):format(target.DisplayName)
end

function ACTIONS.PartyAccept(player, prof, fromId)
	local v = invites[player] and invites[player][fromId]
	if invites[player] then invites[player][fromId] = nil end
	if not v or os.clock() - v.at > CFG.InviteSecs or not table.find(parties, v.party) then return "💌 That invite ran out. Ask for a new one!" end
	local party = v.party
	if #party.members >= CFG.PartyMax then return "👫 That party is full." end
	if partyOf[player] ~= party then
		leaveParty(player, "button")
		table.insert(party.members, player)
		partyOf[player] = party
	end
	for _, m in party.members do
		if m ~= player then API.toast(m, ("🎉 %s joined the party!"):format(player.DisplayName)) end
	end
	pushParty(party)
	if party.run then return "🌀 Your party is exploring! Walk into the Explorer's Portal to join them." end
	return nil
end

function ACTIONS.PartyDecline(player, prof, fromId)
	if invites[player] then invites[player][fromId] = nil end
	local from = Players:GetPlayerByUserId(fromId)
	if from then API.toast(from, ("🙈 %s can't come right now."):format(player.DisplayName)) end
	return nil
end

function ACTIONS.PartyLeave(player, prof)
	leaveParty(player, "button")
	return nil
end

function ACTIONS.PartyKick(player, prof, userId)
	local party = partyOf[player]
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not party or party.leader ~= player or not target or partyOf[target] ~= party or target == player then return "❔" end
	leaveParty(target, "button")
	API.toast(target, "👋 You left the party.")
	return nil
end

-- mode = "Realm" (🌀 Explorer's Portal window) or "Dungeon" (🏰 Dungeon Portal window)
function ACTIONS.RealmEnter(player, prof, mode)
	mode = mode == "Dungeon" and "Dungeon" or "Realm"
	if runOf[player] then return "🌀 You are already exploring!" end
	local party = partyOf[player] or newParty(player)
	local where = party.run and (party.run.tier and "Dungeon" or "Realm") or party.mode
	if not nearPortal(player, where) then
		return where == "Dungeon" and "🏰 Walk to the Dungeon Portal first." or "🌀 Walk to the Explorer's Portal first."
	end
	if player:GetAttribute("Carrying") then return "🥚 Finish the egg snatch first!" end
	if party.run then -- the party is already out there: hop in
		if not party.run.ready then return "🌀 The map is still being made..." end
		local err = payEnergy(player, party.run)
		if err then return err end
		sendIn(player, party.run)
		return nil
	end
	if party.leader ~= player then return "👑 Wait for the leader to press Explore." end
	if party.starting then return nil end
	if party.mode ~= mode then return mode == "Dungeon" and "🏰 Pick a dungeon first." or "🌀 Pick a land first." end
	if not isOpen(prof, party.terrain, player) then return ("🔒 The %s opens at farm level %d."):format(party.terrain, Data.Gates[party.terrain].Level) end
	if mode == "Dungeon" then
		if API.updateEnergy then API.updateEnergy(prof) end
		if (prof.Energy or 0) < Data.Dungeon.Energy then return ("⚡ Out of raid energy! You need %d. It refills 1 every hour."):format(Data.Dungeon.Energy) end
	end
	party.starting = true
	local title = mode == "Dungeon" and dungeonName(party.terrain, party.tier) or nil
	for _, m in party.members do
		remote:FireClient(m, {Kind = "Go", Terrain = party.terrain, In = CFG.Countdown, Title = title})
	end
	task.spawn(function()
		task.wait(CFG.Countdown)
		local run, err = newRun(party)
		party.starting = nil
		if not run then
			for _, m in party.members do API.toast(m, err) end
			pushParty(party)
			return
		end
		for _, m in party.members do
			if m.Parent and not runOf[m] then
				local err = payEnergy(m, run)
				if err then API.toast(m, err) else sendIn(m, run) end
			end
		end
		local def = Data.BiomeByName[run.terrain]
		for _, m in party.members do
			if runOf[m] ~= run then continue end
			if run.tier then
				API.toast(m, ("%s Welcome to the %s! Find the 🗝️ key, open the 👑 boss door and beat the boss. Light 🔥 campfires on the way!")
					:format(Data.Dungeon.Themes[run.terrain].Icon, dungeonName(run.terrain, run.tier)))
			else
				API.toast(m, ("%s Welcome to the %s! Map #%d. Find the 🎁 treasure at the end of the trail!"):format(def.Icon, run.terrain, run.seed))
			end
		end
		if not next(run.inside) then wipe(run) end
	end)
	return nil
end

function ACTIONS.RealmLeave(player, prof)
	local run = runOf[player]
	if run then run.leave(player, "button") end
	return nil
end

-- the old map / portal travel can't jump into a generated map
local oldTravel = ACTIONS.Travel
function ACTIONS.Travel(player, prof, where, ...)
	if type(where) == "string" and where:sub(1, 5) == "Realm" then return nil end
	if runOf[player] then runOf[player].leave(player, "gone") end
	return oldTravel(player, prof, where, ...)
end
for _, name in {"GoHome", "Visit", "TravelEvent", "TravelShop", "PortalGo"} do
	local raw = ACTIONS[name]
	if raw then
		ACTIONS[name] = function(player, ...)
			local run = runOf[player]
			local res = raw(player, ...)
			if run and runOf[player] == run then -- they left the map some other way
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if hrp and (math.abs(hrp.Position.X - run.origin.X) > CFG.Half or math.abs(hrp.Position.Z - run.origin.Z) > CFG.Half) then
					runOf[player] = nil
					run.inside[player] = nil
					player:SetAttribute("Realm", nil)
					player:SetAttribute("RealmSeed", nil)
					if run.party then pushParty(run.party) end
				end
			end
			return res
		end
	end
end

---------------------------------------------------------------- the portal in town (walk in = open the screen, client side)
local tp = root:WaitForChild("TerrainPortal", 30)
if tp then API.travelSpots.TerrainPortal = portalOut() end
task.spawn(function()
	if root:WaitForChild("DungeonPortal", 30) then API.travelSpots.DungeonPortal = dungeonOut() end
end)

---------------------------------------------------------------- players coming and going
local function hookPlayer(player)
	player.CharacterAdded:Connect(function()
		local run = runOf[player]
		if run then -- fainted or reset: you wake up in town
			run.leave(player, "died")
		end
	end)
end
Players.PlayerAdded:Connect(hookPlayer)
for _, p in Players:GetPlayers() do hookPlayer(p) end
Players.PlayerRemoving:Connect(function(player)
	local run = runOf[player]
	if run then run.leave(player, "gone") end
	leaveParty(player, "gone")
	invites[player] = nil
	buddyOf[player] = nil
	for _, t in invites do
		t[player.UserId] = nil
	end
end)


API.runOf = runOf
-- where you wake up after fainting: the last 🔥 campfire you lit in a dungeon, else the map's start
API.realmSpawn = function(player)
	local run = runOf[player]
	return run and (run.checkpoint and run.checkpoint[player] or run.spawnPos)
end
-- shared bits for ServerScriptService.Dungeons
API.realmHooks = {P = P, chip = chip, exitPortal = exitPortal, treasure = treasure, runOf = runOf, bottomOffset = bottomOffset,
	placeProp = placeProp, template = template, glowColors = GLOW,
	resOf = function(land) return RES_OF[land] or {} end}
API.DEV_EXTRA = API.DEV_EXTRA or {}
API.DEV_EXTRA.Realm = function(player, prof, name) -- jump straight into a fresh map (Studio dev menu)
	local party = partyOf[player] or newParty(player)
	if party.run then return "Already exploring" end
	party.terrain = Data.BiomeByName[name or ""] and name or party.terrain
	party.mode = "Realm"
	local run, err = newRun(party)
	if not run then return err end
	sendIn(player, run)
	return ("🌀 %s map #%d"):format(run.terrain, run.seed)
end
API.DEV_EXTRA.Dungeon = function(player, prof, name, tier) -- jump straight into a fresh dungeon (Studio dev menu), no energy
	if type(name) == "string" and name:find(":") then name, tier = name:match("^(.-):(%d+)$") end -- (the dev menu sends "Land:tier")
	local party = partyOf[player] or newParty(player)
	if party.run then return "Already exploring" end
	party.terrain = Data.Dungeon.Themes[name or ""] and name or party.terrain
	party.mode, party.tier = "Dungeon", math.clamp(tonumber(tier) or 1, 1, #Data.Dungeon.Tiers)
	local run, err = newRun(party)
	if not run then return err end
	run.paid[player] = true
	sendIn(player, run)
	return "🏰 " .. dungeonName(run.terrain, run.tier)
end
API.DEV_EXTRA.DungeonsAll = function(player, prof) -- every dungeon open at every ⭐ (ignores farm level until you leave)
	prof.DungeonTier = prof.DungeonTier or {}
	for land in Data.Dungeon.Themes do prof.DungeonTier[land] = #Data.Dungeon.Tiers end
	player:SetAttribute("DevOpenAll", true)
	prof.Energy = math.max(prof.Energy or 0, Data.EnergyMax or 0)
	return ("🔓 All dungeons open, ⭐1-%d"):format(#Data.Dungeon.Tiers)
end
API.DEV_EXTRA.DungeonsReset = function(player, prof) -- back to a new player's dungeons
	prof.DungeonTier = {}
	player:SetAttribute("DevOpenAll", nil)
	return "🔒 Dungeon stars reset"
end

print("[Realms] ready")
