-- Critter Acres: Dungeons (ServerScriptService)
-- 🏰 The Dungeon Portal (town, beside the 🌀 Explorer's Portal). Same party / buddy / invite system as the Explorer's
-- Portal (Realms): a party picks a dungeon + ⭐ tier there, pays ⚡ raid energy each, and Realms calls
-- API.buildDungeon(run) instead of its land map. Every run makes a fresh natural-looking map out of terrain:
--   * a hidden maze graph decides what joins what (loops AND dead ends); each "room" becomes a clearing of its own
--     size, nudged off the grid, and each link a winding trail. Everything else is steep cliff (too high to climb,
--     an invisible lid stops anyone getting over) with rows of bushes / rocks / crystals along the edges and trees
--     on top. Cave dungeons (Theme.Cave) get a rock ceiling; the others are open sky.
--   * 🎨 zones: 2-4 areas (e.g. 🍄 Mushroom Path, 💧 Drippy Tunnels), each with its own ground, lantern colour,
--     decorations, a sign chip where you walk in and a big landmark in clearings where trails meet
--   * 🪜 secret ledges: a rock pillar with a ✨ silver chest. The way up (stone steps or an obby of pads) is a pillar
--     1-2 clearings away; a high bridge / pads follow the trail over to it. From the top you can only jump down.
--   * 🚪 exit portal + 🔥 campfire at the start; more 🔥 campfires on the way (faint = wake at the last one you lit)
--   * 🗝️ the key in the farthest side clearing, guarded; it opens the boss gate (vines / ice / crystal) for everyone
--   * 👑 the boss in a big round arena behind the gate; beating it brings the 🎁 boss chest + a way home
--   * 🧺 chests at the end of dead-end trails (each explorer opens each one once)
--   * 🙈 hidden chests in little nooks in the cliff, behind a bush you walk through or a cracked rock you break (⛏️ hold)
--   * 🏃 a runaway chest with googly eyes: it hops away down the trails when you come close, then gets tired
--   * 📜 scrolls / ⭐ run score / 🎉 first-clear bonus: ServerScriptService.DungeonRewards (API.dungeonScroll, API.dungeonCleared)
-- Walls block things: run.blocked(a, b) tells Combat when terrain / the gate is in the way (no attacks, shots or
-- noticing through it) and run.clampGoal keeps every mob inside its own clearing.
-- All tuning lives in Data.Dungeon (CritterData). Mobs come from ServerStorage.MobModels.<Land> like the lands.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local t0 = os.clock()
while not API.realmHooks and os.clock() - t0 < 30 do task.wait(0.2) end
local R = API.realmHooks
if not R then warn("[Dungeons] Realms hooks missing, dungeons are off") return end
local Data = API.Data
local D = Data.Dungeon
local M = Enum.Material
local Terrain = workspace.Terrain
local UP = CFrame.Angles(0, 0, math.pi / 2) -- cylinders point along X; this stands them up

local function P(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = M.SmoothPlastic
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end
local function egg(parent, props)
	local p = P(parent, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
local function light(part, color, range, bright)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range or 24, bright or 1.3, false
	l.Parent = part
	return l
end
local function sparkle(part, color, rate)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.Size = NumberSequence.new(0.5, 0)
	pe.Rate, pe.Lifetime, pe.Speed = rate or 6, NumberRange.new(1, 1.8), NumberRange.new(1, 2.5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.LightEmission = 1
	pe.Parent = part
	return pe
end
local function toastRun(run, text)
	for p in run.inside do API.toast(p, text) end
end
local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function distSeg(p, a, b)
	local ab = b - a
	local l2 = ab:Dot(ab)
	if l2 < 1e-6 then return (p - a).Magnitude end
	local t = math.clamp((p - a):Dot(ab) / l2, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

---------------------------------------------------------------- the maze graph (pure data)
-- n x n cells, id = (y - 1) * n + x. open[a][b] = true when two neighbours are joined.
local function makeMaze(rng, n, loops)
	local open = {}
	local function link(a, b)
		open[a] = open[a] or {}
		open[b] = open[b] or {}
		open[a][b], open[b][a] = true, true
	end
	local function nbrs(c)
		local x, y = (c - 1) % n + 1, (c - 1) // n + 1
		local t = {}
		if x > 1 then table.insert(t, c - 1) end
		if x < n then table.insert(t, c + 1) end
		if y > 1 then table.insert(t, c - n) end
		if y < n then table.insert(t, c + n) end
		return t
	end
	local first = rng:NextInteger(1, n * n)
	local seen, stack = {[first] = true}, {first}
	while #stack > 0 do
		local c = stack[#stack]
		local opts = {}
		for _, b in nbrs(c) do if not seen[b] then table.insert(opts, b) end end
		if #opts == 0 then
			table.remove(stack)
		else
			local b = opts[rng:NextInteger(1, #opts)]
			link(c, b)
			seen[b] = true
			table.insert(stack, b)
		end
	end
	for c = 1, n * n do -- extra trails: more than one way through
		for _, b in nbrs(c) do
			if b > c and not (open[c] and open[c][b]) and rng:NextNumber() < loops then link(c, b) end
		end
	end
	return open
end
local function walk(open, from) -- distances + the way back from every cell
	local dist, prev, q = {[from] = 0}, {}, {from}
	local i = 1
	while q[i] do
		local c = q[i]
		i += 1
		for b in open[c] or {} do
			if not dist[b] then dist[b], prev[b] = dist[c] + 1, c table.insert(q, b) end
		end
	end
	return dist, prev
end
local function onBorder(c, n)
	local x, y = (c - 1) % n + 1, (c - 1) // n + 1
	return x == 1 or y == 1 or x == n or y == n
end
local function outward(c, n) -- a side of a border cell that leads out of the maze: {dx, dy}
	local x, y = (c - 1) % n + 1, (c - 1) // n + 1
	if y == n then return {0, 1} elseif y == 1 then return {0, -1} elseif x == n then return {1, 0} end
	return {-1, 0}
end
local function linksOf(open, c)
	local k = 0
	for _ in open[c] or {} do k += 1 end
	return k
end

---------------------------------------------------------------- little builds (part-built, ARTSTYLE.md); p = a spot on the ground
local function campfire(parent, pos)
	local m = Instance.new("Model")
	m.Name = "Campfire"
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		P(m, {Name = "Stone", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, Position = pos + Vector3.new(math.cos(a) * 2, 0.5, math.sin(a) * 2),
			Color = Color3.fromRGB(150, 145, 160), CanCollide = false})
	end
	for i = 0, 1 do
		P(m, {Name = "Log", Size = Vector3.new(3.2, 0.7, 0.7), CFrame = CFrame.new(pos + Vector3.new(0, 0.5 + i * 0.5, 0)) * CFrame.Angles(0, i * math.pi / 2 + 0.4, 0),
			Color = Color3.fromRGB(130, 85, 50), Material = M.Wood, CanCollide = false})
	end
	local flame = egg(m, {Name = "Flame", Size = Vector3.new(1.2, 2, 1.2), Position = pos + Vector3.new(0, 1.8, 0), Color = Color3.fromRGB(140, 140, 150),
		Material = M.Neon, Transparency = 0.6, CanCollide = false})
	local l = light(flame, Color3.fromRGB(255, 160, 70), 26, 0)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/fire_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 90, 40))
	pe.Size = NumberSequence.new(1.2, 0.2)
	pe.Lifetime, pe.Speed, pe.Rate = NumberRange.new(0.6, 0.9), NumberRange.new(3, 5), 25
	pe.LightEmission = 0.8
	pe.Enabled = false
	pe.Parent = flame
	local zone = P(m, {Name = "Zone", Size = Vector3.new(12, 8, 12), Position = pos + Vector3.new(0, 4, 0), Transparency = 1, CanCollide = false, CanQuery = false})
	m.Parent = parent
	local function lit(on)
		flame.Color, flame.Transparency = on and Color3.fromRGB(255, 170, 60) or Color3.fromRGB(140, 140, 150), on and 0.15 or 0.6
		l.Brightness, pe.Enabled = on and 1.6 or 0, on
	end
	return zone, lit
end

local function keyModel(parent, pos)
	local m = Instance.new("Model")
	m.Name = "DungeonKey"
	P(m, {Name = "Pedestal", Size = Vector3.new(3, 3, 3), Position = pos + Vector3.new(0, 1.5, 0), Color = Color3.fromRGB(200, 190, 215), Material = M.Marble})
	local gold = Color3.fromRGB(255, 205, 60)
	local ring = P(m, {Name = "Key", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 1.8, 1.8), CFrame = CFrame.new(pos + Vector3.new(0, 5.6, 0)) * CFrame.Angles(0, math.pi / 2, 0),
		Color = gold, Material = M.Neon, CanCollide = false})
	P(m, {Name = "KeyBar", Size = Vector3.new(0.5, 2.4, 0.5), Position = pos + Vector3.new(0, 3.9, 0), Color = gold, Material = M.Neon, CanCollide = false})
	P(m, {Name = "KeyTooth", Size = Vector3.new(0.5, 0.45, 1), Position = pos + Vector3.new(0, 3.3, 0.45), Color = gold, Material = M.Neon, CanCollide = false})
	light(ring, gold, 18, 1.5)
	sparkle(ring, Color3.fromRGB(255, 240, 150), 8)
	m.Parent = parent
	return m, ring
end

-- 🏮 a little lantern post at a clearing's edge (lights caves; tinted with the zone colour)
local function lantern(parent, pos, col)
	P(parent, {Name = "Post", Size = Vector3.new(0.5, 6, 0.5), Position = pos + Vector3.new(0, 3, 0), Color = Color3.fromRGB(110, 80, 55), Material = M.Wood, CanCollide = false})
	local glow = egg(parent, {Name = "Lamp", Size = Vector3.new(1.5, 1.8, 1.5), Position = pos + Vector3.new(0, 6.6, 0), Color = col, Material = M.Neon, CanCollide = false})
	light(glow, col, 30, 1.3)
end

-- small decorations, one kind per zone
local DECO = {}
function DECO.Mushroom(f, p, s, col)
	P(f, {Name = "Deco", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.9, s * 0.35, s * 0.35), CFrame = CFrame.new(p + Vector3.new(0, s * 0.45, 0)) * UP,
		Color = Color3.fromRGB(250, 240, 220), CanCollide = false})
	egg(f, {Name = "Deco", Size = Vector3.new(s, s * 0.5, s), Position = p + Vector3.new(0, s * 0.95, 0), Color = col, CanCollide = false})
end
function DECO.Crystal(f, p, s, col, rng)
	P(f, {Name = "Deco", Size = Vector3.new(s * 0.45, s * 1.6, s * 0.45), CFrame = CFrame.new(p + Vector3.new(0, s * 0.6, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
		Color = col, Material = M.Neon, CanCollide = false})
end
function DECO.Blob(f, p, s, col)
	egg(f, {Name = "Deco", Size = Vector3.new(s * 1.2, s * 0.8, s), Position = p + Vector3.new(0, s * 0.35, 0), Color = col, Material = M.Glass, Transparency = 0.25, CanCollide = false})
end
function DECO.Flower(f, p, s, col, rng)
	for _ = 1, 3 do
		local q = p + Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		P(f, {Name = "Deco", Size = Vector3.new(0.25, s * 0.6, 0.25), Position = q + Vector3.new(0, s * 0.3, 0), Color = Color3.fromRGB(90, 170, 80), CanCollide = false})
		P(f, {Name = "Deco", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.4, Position = q + Vector3.new(0, s * 0.65, 0), Color = col, Material = M.Neon, CanCollide = false})
	end
end
function DECO.Rock(f, p, s, col)
	egg(f, {Name = "Deco", Size = Vector3.new(s * 1.3, s * 0.7, s), Position = p + Vector3.new(0, s * 0.3, 0), Color = col, Material = M.Slate, CanCollide = false})
end

-- 🗿 big landmarks for clearings where 3+ trails meet (about 8-11 studs tall, radius <= 6)
local MARK = {}
function MARK.BigMushroom(f, p, col)
	P(f, {Name = "Mark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 3, 3), CFrame = CFrame.new(p + Vector3.new(0, 3.5, 0)) * UP, Color = Color3.fromRGB(250, 240, 220), CanCollide = true})
	egg(f, {Name = "Mark", Size = Vector3.new(11, 4.5, 11), Position = p + Vector3.new(0, 8, 0), Color = col})
	for i = 0, 5 do
		local a = i * math.pi / 3
		P(f, {Name = "Mark", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, Position = p + Vector3.new(math.cos(a) * 3.2, 9.6, math.sin(a) * 3.2), Color = Color3.new(1, 1, 1), CanCollide = false})
	end
end
function MARK.BigCrystal(f, p, col)
	for i = 1, 5 do
		local a = i * 1.3
		local h = 5 + i * 1.3
		local c = P(f, {Name = "Mark", Size = Vector3.new(1.8, h, 1.8), CFrame = CFrame.new(p + Vector3.new(math.cos(a) * 1.6, h / 2 - 0.5, math.sin(a) * 1.6)) * CFrame.Angles(math.cos(a) * 0.25, a, math.sin(a) * 0.25),
			Color = col:Lerp(Color3.new(1, 1, 1), (i % 2) * 0.25), Material = M.Neon, CanCollide = i == 5})
		if i == 5 then light(c, col, 30, 1.2) end
	end
end
function MARK.Fountain(f, p, col)
	P(f, {Name = "Mark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 11, 11), CFrame = CFrame.new(p + Vector3.new(0, 0.7, 0)) * UP, Color = Color3.fromRGB(200, 200, 215), Material = M.Marble, CanCollide = true})
	P(f, {Name = "Mark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 9.6, 9.6), CFrame = CFrame.new(p + Vector3.new(0, 1.45, 0)) * UP, Color = col, Material = M.Glass, Transparency = 0.25, CanCollide = false})
	P(f, {Name = "Mark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 1.4, 1.4), CFrame = CFrame.new(p + Vector3.new(0, 3.5, 0)) * UP, Color = Color3.fromRGB(200, 200, 215), Material = M.Marble})
	local top = P(f, {Name = "Mark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 4, 4), CFrame = CFrame.new(p + Vector3.new(0, 6.2, 0)) * UP, Color = Color3.fromRGB(200, 200, 215), Material = M.Marble})
	local w = Instance.new("ParticleEmitter")
	w.Color = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.4))
	w.Size = NumberSequence.new(0.35, 0.1)
	w.Speed = NumberRange.new(7, 9)
	w.Acceleration = Vector3.new(0, -25, 0)
	w.Lifetime = NumberRange.new(0.6, 0.8)
	w.SpreadAngle = Vector2.new(25, 25)
	w.Rate = 35
	w.EmissionDirection = Enum.NormalId.Right -- the disc is turned: Right points up
	w.Parent = top
	light(top, col, 22, 1)
end
function MARK.Pool(f, p, col)
	P(f, {Name = "Mark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 13, 13), CFrame = CFrame.new(p + Vector3.new(0, 0.4, 0)) * UP, Color = Color3.fromRGB(150, 145, 160), Material = M.Slate})
	local pool = P(f, {Name = "Mark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 11, 11), CFrame = CFrame.new(p + Vector3.new(0, 0.7, 0)) * UP, Color = col, Material = M.Neon, Transparency = 0.2, CanCollide = false})
	local b = Instance.new("ParticleEmitter")
	b.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	b.Color = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.5))
	b.Size = NumberSequence.new(0.6, 0.2)
	b.Speed = NumberRange.new(1, 3)
	b.Lifetime = NumberRange.new(1, 2)
	b.Rate = 10
	b.EmissionDirection = Enum.NormalId.Right
	b.Parent = pool
	light(pool, col, 24, 1.2)
	for i = 0, 2 do
		local a = i * 2.1
		egg(f, {Name = "Mark", Size = Vector3.new(1.6, 1.6, 1.6), Position = p + Vector3.new(math.cos(a) * 3, 1, math.sin(a) * 3), Color = col:Lerp(Color3.new(1, 1, 1), 0.3), Material = M.Glass, Transparency = 0.3, CanCollide = false})
	end
end
function MARK.BigTree(f, p, col)
	P(f, {Name = "Mark", Size = Vector3.new(2.6, 9, 2.6), Position = p + Vector3.new(0, 4.5, 0), Color = Color3.fromRGB(120, 85, 55), Material = M.Wood, CanCollide = true})
	for i = 0, 2 do
		local a = i * 2.1
		P(f, {Name = "Mark", Shape = Enum.PartType.Ball, Size = Vector3.one * (6 - i * 0.6), Position = p + Vector3.new(math.cos(a) * 1.6, 9.5 + i * 0.6, math.sin(a) * 1.6), Color = col, Material = M.Grass, CanCollide = false})
	end
end

---------------------------------------------------------------- build one dungeon into a Realms run
local VOX = 4
local function build(run)
	local land = run.terrain
	local th = D.Themes[land] or D.Themes.Meadow
	local zoneDefs = D.Zones[land] or D.Zones.Meadow
	local tier = D.Tiers[run.tier or 1] or D.Tiers[1]
	local rng = Random.new(run.seed)
	local n, G, F, WH, HB = tier.Size, D.Gap, D.Floor, D.WallH, D.LedgeH
	local O = Vector3.new(run.origin.X, 0, run.origin.Z)
	local folder = run.folder
	local blockers = Instance.new("Folder") -- parts that block attacks / sight besides the terrain (the boss gate)
	blockers.Name = "Blockers"
	blockers.Parent = folder
	run.dungeon, run.checkpoint, run.hasKey = true, {}, false
	run.noRespawn = true -- cleared clearings stay cleared
	local def = {Color = th.Accent}
	local nx0, nz0 = rng:NextNumber(-4000, 4000), rng:NextNumber(-4000, 4000) -- noise offsets for this map

	-- the graph: start on the edge, the boss behind the edge cell farthest from it, the key off the main way
	local open = makeMaze(rng, n, tier.Loops)
	local function xy(c) return (c - 1) % n + 1, (c - 1) // n + 1 end
	local borders = {}
	for c = 1, n * n do if onBorder(c, n) then table.insert(borders, c) end end
	local start = borders[rng:NextInteger(1, #borders)]
	local dist, prev = walk(open, start)
	local bossCell, far = start, -1
	for _, c in borders do
		if c ~= start and dist[c] and dist[c] > far then bossCell, far = c, dist[c] end
	end
	local path, onPath = {}, {}
	do
		local c = bossCell
		while c do table.insert(path, 1, c) onPath[c] = true c = prev[c] end
	end
	local maxD = 1
	for _, d in dist do maxD = math.max(maxD, d) end
	local deadEnds = {}
	for c = 1, n * n do
		if linksOf(open, c) == 1 and c ~= start and c ~= bossCell then table.insert(deadEnds, c) end
	end
	local keyCell, kd = nil, -1
	for c = 1, n * n do
		if not onPath[c] and dist[c] and dist[c] > kd then keyCell, kd = c, dist[c] end
	end
	keyCell = keyCell or deadEnds[1] or bossCell
	local fires = {start}
	for i = 1, D.Campfires do
		local c = path[math.clamp(math.floor(#path * i / (D.Campfires + 1)) + 1, 2, math.max(2, #path - 1))]
		if c and c ~= bossCell and not table.find(fires, c) then table.insert(fires, c) end
	end
	local busy = {[start] = true, [bossCell] = true, [keyCell] = true}
	for _, c in fires do busy[c] = true end

	-- 🎨 zones: seeds spread far apart, every clearing joins its nearest seed (by walking distance)
	local zoneOf = {}
	do
		local nz = math.min(tier.Zones, #zoneDefs)
		local seeds = {}
		local best, bd = nil, -1
		for c = 1, n * n do if c ~= start and (dist[c] or 0) > bd then best, bd = c, dist[c] or 0 end end
		table.insert(seeds, best)
		local near = {}
		local d1 = walk(open, best)
		for c = 1, n * n do near[c] = math.min(dist[c] or 99, d1[c] or 99) end
		while #seeds < nz do
			local pick, pd = nil, -1
			for c = 1, n * n do
				if c ~= start and not table.find(seeds, c) and near[c] > pd then pick, pd = c, near[c] end
			end
			if not pick or pd < 2 then break end
			table.insert(seeds, pick)
			local dd = walk(open, pick)
			for c = 1, n * n do near[c] = math.min(near[c], dd[c] or 99) end
		end
		local dists = {}
		for i, s in seeds do dists[i] = walk(open, s) end
		local order = {}
		for i = 1, #zoneDefs do order[i] = i end
		for i = #order, 2, -1 do local j = rng:NextInteger(1, i) order[i], order[j] = order[j], order[i] end
		for c = 1, n * n do
			if c ~= start then
				local bi, bv = 1, math.huge
				for i in seeds do
					local v = dists[i][c] or math.huge
					if v < bv then bi, bv = i, v end
				end
				zoneOf[c] = zoneDefs[order[bi]]
			end
		end
	end

	-- 🪜 ledge routes: [S (the way up) ... T (the ledge with the chest)] along linked clearings, none busy, no overlaps
	local routes, onRoute, climbRoom = {}, {}, {}
	do
		local cands = {}
		for _, c in deadEnds do if not busy[c] then table.insert(cands, c) end end
		for c = 1, n * n do if not busy[c] and not table.find(cands, c) and linksOf(open, c) <= 2 then table.insert(cands, c) end end
		for _, T in cands do
			if #routes >= tier.Ledges then break end
			if not onRoute[T] then
				local r, cur = {T}, T
				for _ = 1, tier.Route do
					local opts = {}
					for b in open[cur] or {} do
						if not busy[b] and not onRoute[b] and not table.find(r, b) then table.insert(opts, b) end
					end
					if #opts == 0 then break end
					cur = opts[rng:NextInteger(1, #opts)]
					table.insert(r, cur)
				end
				if #r >= 2 then
					local route = {}
					for i = #r, 1, -1 do table.insert(route, r[i]) end
					table.insert(routes, route)
					for _, c in route do onRoute[c] = true end
					climbRoom[route[1]] = true
				end
			end
		end
	end

	-- 🌳 clearings: each cell's spot nudged off the grid with its own size; the boss arena sits outside the edge
	local node = {} -- id -> {p = Vector2 (local), r = radius}
	for c = 1, n * n do
		local x, y = xy(c)
		local p = Vector2.new((x - (n + 1) / 2) * G, (y - (n + 1) / 2) * G) + Vector2.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * G * 0.17
		local r = rng:NextNumber(D.ClearR[1], D.ClearR[2])
		if c == start then r = D.ClearR[2] + 2 elseif busy[c] or onRoute[c] then r = math.max(r, (D.ClearR[1] + D.ClearR[2]) / 2 + 2) end
		node[c] = {p = p, r = r, c = c}
	end
	local out = outward(bossCell, n)
	local outV = Vector2.new(out[1], out[2])
	local ARENA = "Arena"
	node[ARENA] = {p = node[bossCell].p + outV * (node[bossCell].r + D.ArenaR + 26), r = D.ArenaR, c = ARENA}

	-- 🛤️ trails: a bendy curve for every link (some wider, some narrower); stored as short straight bits
	local trails, segs = {}, {}
	local function addTrail(a, b, w, bend)
		local A, B = node[a].p, node[b].p
		local dir = (B - A)
		local perp = Vector2.new(-dir.Y, dir.X).Unit
		local ctrl = (A + B) / 2 + perp * bend
		local pts = {}
		for k = 0, 8 do
			local t = k / 8
			table.insert(pts, A * (1 - t) ^ 2 + ctrl * 2 * t * (1 - t) + B * t * t)
		end
		local tr = {a = a, b = b, pts = pts, w = w}
		table.insert(trails, tr)
		for k = 1, #pts - 1 do
			-- the width wobbles a little along the way
			table.insert(segs, {pts[k], pts[k + 1], w * (0.85 + 0.3 * math.noise(k * 0.7 + nx0, #trails))})
		end
		return tr
	end
	for c = 1, n * n do
		for b in open[c] or {} do
			if b > c then addTrail(c, b, rng:NextNumber(D.TrailW[1], D.TrailW[2]), rng:NextNumber(-1, 1) * G * 0.22) end
		end
	end
	local bossTrail = addTrail(bossCell, ARENA, D.TrailW[2], rng:NextNumber(-1, 1) * 6)
	local function trailOf(a, b)
		for _, t in trails do
			if (t.a == a and t.b == b) then return t, false end
			if (t.a == b and t.b == a) then return t, true end
		end
	end

	-- how far a spot is from open ground (negative = on a clearing / trail), and which clearing is nearest
	local allNodes = {}
	for _, nd in node do table.insert(allNodes, nd) end
	-- 🙈 hidden nooks: a little hollow in the cliff at a clearing's edge (part of the open ground, but not a clearing)
	local nooks = {}
	do
		local cands = {}
		for c = 1, n * n do
			if c ~= start and c ~= keyCell and not onRoute[c] and not table.find(fires, c) then table.insert(cands, c) end
		end
		for i = #cands, 2, -1 do local j = rng:NextInteger(1, i) cands[i], cands[j] = cands[j], cands[i] end
		for _, c in cands do
			if #nooks >= (tier.Hidden or 0) then break end
			local nd = node[c]
			for _ = 1, 12 do
				local a = rng:NextNumber(0, math.pi * 2)
				local dir = Vector2.new(math.cos(a), math.sin(a))
				local ctr = nd.p + dir * (nd.r + 3)
				local ok = true
				for _, o in allNodes do
					if o ~= nd and (ctr - o.p).Magnitude - o.r < 9 then ok = false break end
				end
				if ok then
					for _, sg in segs do
						if distSeg(ctr, sg[1], sg[2]) - sg[3] < 7 then ok = false break end
					end
				end
				if ok then
					local nk = {p = ctr, r = 5, c = "Nook", home = nd, dir = dir}
					table.insert(nooks, nk)
					table.insert(allNodes, nk)
					break
				end
			end
		end
	end
	local function field(p, nl, sl)
		local dClear, near = math.huge, nil
		for _, nd in nl or allNodes do
			local d = (p - nd.p).Magnitude - nd.r
			if d < dClear then dClear, near = d, nd end
		end
		local dPath = math.huge
		for _, s in sl or segs do
			local d = distSeg(p, s[1], s[2]) - s[3]
			if d < dPath then dPath = d end
		end
		return math.min(dClear, dPath), dPath, near
	end
	local function noise2(x, z, f) return math.noise(x * f + nx0, z * f + nz0) end
	local function heightAt(p, d)
		local floor = F + 1.0 * noise2(p.X, p.Y, 1 / 30)
		if d <= 0 then return floor end
		local bumps = 7 * smooth(d / 14) * (0.5 + 0.5 * noise2(p.X + 300, p.Y - 200, 1 / 22))
		return floor + WH * smooth(d / 5) + bumps
	end

	-- the area to fill: everything + a thick border of cliff
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, nd in node do
		minX, maxX = math.min(minX, nd.p.X - nd.r), math.max(maxX, nd.p.X + nd.r)
		minZ, maxZ = math.min(minZ, nd.p.Y - nd.r), math.max(maxZ, nd.p.Y + nd.r)
	end
	local PAD = 44
	minX, maxX = math.floor((minX - PAD) / VOX) * VOX, math.ceil((maxX + PAD) / VOX) * VOX
	minZ, maxZ = math.floor((minZ - PAD) / VOX) * VOX, math.ceil((maxZ + PAD) / VOX) * VOX
	local cols, rows = (maxX - minX) // VOX, (maxZ - minZ) // VOX
	local TOP = F + WH + 10
	local layers = math.ceil(TOP / VOX)
	local zoneGround = {}
	for c, nd in node do
		local z = zoneOf[c]
		zoneGround[nd] = (z and z.Ground) or th.Ground
	end
	for _, nk in nooks do zoneGround[nk] = zoneGround[nk.home] or th.Ground end

	-- ⛰️ write the terrain in strips (cheap enough: only the trails / clearings near each strip are checked)
	local H, Dm = {}, {} -- per column: surface height, distance to open ground (kept for placing things later)
	for i0 = 1, cols, 16 do
		local w = math.min(16, cols - i0 + 1)
		local xs0, xs1 = minX + (i0 - 1) * VOX, minX + (i0 - 1 + w) * VOX
		-- only what's near this strip matters (farther than ~60 studs it's all cliff anyway)
		local nl, sl = {}, {}
		for _, nd in allNodes do
			if nd.p.X + nd.r >= xs0 - 60 and nd.p.X - nd.r <= xs1 + 60 then table.insert(nl, nd) end
		end
		for _, s in segs do
			if math.max(s[1].X, s[2].X) + s[3] >= xs0 - 60 and math.min(s[1].X, s[2].X) - s[3] <= xs1 + 60 then table.insert(sl, s) end
		end
		local mats, occ = {}, {}
		for a = 1, w do
			local i = i0 + a - 1
			local x = minX + (i - 0.5) * VOX
			H[i], Dm[i] = {}, {}
			mats[a], occ[a] = {}, {}
			for b = 1, layers do mats[a][b], occ[a][b] = {}, {} end
			for k = 1, rows do
				local z = minZ + (k - 0.5) * VOX
				local p = Vector2.new(x, z)
				local d, dPath, near = field(p, nl, sl)
				local h = heightAt(p, d)
				H[i][k], Dm[i][k] = h, d
				local m
				if d <= 0 then
					m = (dPath <= 0 and math.noise(x / 9 + nx0, z / 9) > dPath / 5 - 0.35) and th.Path or zoneGround[near]
				elseif d < 9 then
					m = th.Cliff
				else
					m = th.Top
				end
				-- cave ceiling: a rock lid over everything walkable, bumpy underneath
				local cb = th.Cave and d < 12 and (F + D.CaveH + 3 * (0.5 + 0.5 * noise2(x - 500, z + 90, 1 / 16))) or nil
				for b = 1, layers do
					local y0 = (b - 1) * VOX
					local o = math.clamp((h - y0) / VOX, 0, 1)
					local mm = m
					if h - y0 > VOX * 2 and d > 0 then mm = th.Cliff end
					if o <= 0 and cb then
						local oc = math.clamp((y0 + VOX - cb) / VOX, 0, 1)
						if oc > 0 and y0 < TOP then o, mm = oc, th.Ceil end
					end
					if o <= 0 then mm = M.Air end
					mats[a][b][k], occ[a][b][k] = mm, o
				end
			end
		end
		local lo = Vector3.new(O.X + xs0, 0, O.Z + minZ)
		Terrain:WriteVoxels(Region3.new(lo, Vector3.new(O.X + xs1, layers * VOX, O.Z + maxZ)), VOX, mats, occ)
		task.wait()
	end
	-- where things stand: the ground under a local spot
	local rpG = RaycastParams.new()
	rpG.FilterType = Enum.RaycastFilterType.Include
	rpG.FilterDescendantsInstances = {Terrain}
	local function ground(p) -- p = Vector2 local -> Vector3 world on the floor
		local wx, wz = O.X + p.X, O.Z + p.Y
		local hit = workspace:Raycast(Vector3.new(wx, F + D.CaveH - 2, wz), Vector3.new(0, -(D.CaveH + 10), 0), rpG)
		return Vector3.new(wx, hit and hit.Position.Y or F, wz)
	end
	local function W(p) return ground(p) end
	local function NC(c) return W(node[c].p) end

	-- the lid: nobody gets up onto the cliffs (an invisible ceiling just above the bridges)
	P(folder, {Name = "Lid", Size = Vector3.new(maxX - minX, 2, maxZ - minZ), Position = O + Vector3.new((minX + maxX) / 2, F + D.LidH + 1, (minZ + maxZ) / 2),
		Transparency = 1, CanQuery = false})
	run.ground = P(folder, {Name = "RealmGround", Size = Vector3.new(maxX - minX, 1, maxZ - minZ), Position = O + Vector3.new((minX + maxX) / 2, F, (minZ + maxZ) / 2),
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})

	-- 🧱 terrain + the gate block attacks, shots and noticing; mobs stay inside their own clearing
	local rpB = RaycastParams.new()
	rpB.FilterType = Enum.RaycastFilterType.Include
	rpB.FilterDescendantsInstances = {Terrain, blockers}
	local eye = F + 3.5
	function run.blocked(a, b)
		local p, q = Vector3.new(a.X, math.max(eye, a.Y), a.Z), Vector3.new(b.X, math.max(eye, b.Y), b.Z)
		local d = q - p
		if d.Magnitude < 0.5 then return false end
		return workspace:Raycast(p, d, rpB) ~= nil
	end
	function run.clampGoal(mob, goal)
		local h = Vector2.new(mob.home.X - O.X, mob.home.Z - O.Z)
		local best, bd = nil, math.huge
		for _, nd in node do
			local dd = (h - nd.p).Magnitude - nd.r
			if dd < bd then best, bd = nd, dd end
		end
		if not best then return goal end
		local g = Vector2.new(goal.X - O.X, goal.Z - O.Z)
		local off = g - best.p
		local lim = math.max(2, best.r - 3)
		if off.Magnitude > lim then g = best.p + off.Unit * lim end
		return Vector3.new(O.X + g.X, goal.Y, O.Z + g.Y)
	end
	task.wait()

	-- 🌿 barricades: bushes / rocks / crystals along every clearing's edge and both sides of the trails
	local edgeList = th.Edge or {"Bush", "Rocks"}
	local placed = 0
	local function edgeProp(p2, scaleLo, scaleHi)
		local wp = W(p2)
		local name = edgeList[rng:NextInteger(1, #edgeList)]
		local m = R.placeProp(name, folder, wp.X, wp.Y, wp.Z, rng:NextNumber(scaleLo, scaleHi), rng)
		if m then
			placed += 1
			local gc = R.glowColors and R.glowColors[name]
			if gc and th.Cave and placed % 3 == 0 then
				local part = m:FindFirstChildWhichIsA("BasePart", true)
				if part then light(part, gc, 16, 1) end
			end
		end
		if placed % 30 == 0 then task.wait() end
	end
	for _, nd in node do
		local steps = math.floor(nd.r * 2 * math.pi / 8)
		for s = 1, steps do
			local a = s / steps * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
			local p2 = nd.p + Vector2.new(math.cos(a), math.sin(a)) * (nd.r + rng:NextNumber(0.5, 2.5))
			local dAll, dPath = field(p2)
			if dPath > 3 and dAll > 0.3 and rng:NextNumber() < 0.75 then edgeProp(p2, 0.9, 1.5) end
		end
	end
	for _, tr in trails do
		for k = 2, #tr.pts - 1, 1 do
			local a, b = tr.pts[k - 1], tr.pts[k + 1]
			local dir = (b - a).Unit
			local side = Vector2.new(-dir.Y, dir.X)
			for _, s in {-1, 1} do
				local p2 = tr.pts[k] + side * s * (tr.w + rng:NextNumber(0.5, 2))
				local d = field(p2)
				local inClear = false
				for _, nd in node do if (p2 - nd.p).Magnitude < nd.r + 2 then inClear = true break end end
				if not inClear and d > -0.5 and rng:NextNumber() < 0.55 then edgeProp(p2, 0.8, 1.3) end
			end
		end
	end
	-- 🌲 trees on top of the cliffs (open-sky dungeons; cave ones have a ceiling there)
	if not th.Cave and th.Trees and #th.Trees > 0 then
		local tries, trees = 0, 0
		while trees < D.Trees and tries < D.Trees * 5 do
			tries += 1
			local i, k = rng:NextInteger(1, cols), rng:NextInteger(1, rows)
			local d = Dm[i][k]
			if d > 7 and d < 40 then
				local x, z = minX + (i - 0.5) * VOX, minZ + (k - 0.5) * VOX
				local name = th.Trees[rng:NextInteger(1, #th.Trees)]
				if R.placeProp(name, folder, O.X + x, H[i][k], O.Z + z, rng:NextNumber(0.9, 1.4), rng) then trees += 1 end
				if trees % 25 == 0 then task.wait() end
			end
		end
	end

	-- 🏮 lanterns at each clearing's edge (more in caves), away from the trail mouths
	for c, nd in node do
		local col = (zoneOf[c] and th.Light:Lerp(zoneOf[c].Color, 0.5)) or th.Light
		local want = th.Cave and 3 or 2
		local got = 0
		for t = 1, 12 do
			if got >= want then break end
			local a = rng:NextNumber(0, math.pi * 2)
			local p2 = nd.p + Vector2.new(math.cos(a), math.sin(a)) * (nd.r - 2.5)
			local _, dPath = field(p2)
			if dPath > 2 then
				lantern(folder, W(p2), col)
				got += 1
			end
		end
	end

	-- 🪧 a sign at each zone's way in + 🗿 a landmark in clearings where 3+ trails meet
	local signed = {}
	for c = 1, n * n do
		local z = zoneOf[c]
		local pc = prev[c]
		if z and pc and zoneOf[pc] ~= z and not signed[z] then
			local best = true
			for c2 = 1, n * n do
				if zoneOf[c2] == z and (dist[c2] or 99) < (dist[c] or 99) then best = false break end
			end
			if best then
				signed[z] = true
				local tr = trailOf(c, pc)
				local mid = tr and tr.pts[5] or (node[c].p + node[pc].p) / 2
				R.chip(run, W(mid) + Vector3.new(0, 10, 0), z.Icon, z.Name)
			end
		end
	end
	local marks, marked = 0, {}
	for c = 1, n * n do
		if marks < D.Landmarks and zoneOf[c] and not busy[c] and not onRoute[c] and linksOf(open, c) >= 3 then
			local z = zoneOf[c]
			local fn = MARK[z.Mark] or MARK.BigCrystal
			fn(folder, NC(c), z.Color, rng)
			marks += 1
			marked[c] = true
		end
	end
	-- a few zone decorations in each clearing, near the edge so the middle stays open
	for c = 1, n * n do
		local z = zoneOf[c]
		if z then
			local nd = node[c]
			local fn = DECO[z.Deco] or DECO.Rock
			for _ = 1, rng:NextInteger(2, 4) do
				local a = rng:NextNumber(0, math.pi * 2)
				local p2 = nd.p + Vector2.new(math.cos(a), math.sin(a)) * nd.r * rng:NextNumber(0.6, 0.85)
				local _, dPath = field(p2)
				if dPath > 1 then fn(folder, W(p2), rng:NextNumber(2.2, 4), z.Color:Lerp(th.Deco[rng:NextInteger(1, #th.Deco)], 0.3), rng) end
			end
		end
	end
	task.wait()

	-- 🚪 start: exit portal at the clearing's edge (on the side with no trail), campfire in the middle
	local sN = node[start]
	local bestA, bestD = 0, -math.huge
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		local _, dPath = field(sN.p + Vector2.new(math.cos(a), math.sin(a)) * (sN.r - 4))
		if dPath > bestD then bestA, bestD = a, dPath end
	end
	local edge = W(sN.p + Vector2.new(math.cos(bestA), math.sin(bestA)) * (sN.r - 7))
	local sc = NC(start)
	local pcf = CFrame.lookAt(edge, Vector3.new(sc.X, edge.Y, sc.Z))
	local _, exitGate = R.exitPortal(folder, pcf, def)
	exitGate.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and R.runOf[player] == run and os.clock() - (run.arrived[player] or 0) > 3 then run.leave(player, "portal") end
	end)
	R.chip(run, (pcf * CFrame.new(0, 18, 0)).Position, "🏠", "Back to town")
	run.spawnPos = (pcf * CFrame.new(0, 3, -10)).Position

	-- 🔥 campfires (touch one to light it = your wake-up spot)
	for i, c in fires do
		local nd = node[c]
		local p2 = nd.p
		if i > 1 then
			local a = rng:NextNumber(0, math.pi * 2)
			p2 = nd.p + Vector2.new(math.cos(a), math.sin(a)) * nd.r * 0.35
		end
		local pos = W(p2)
		local zone, lit = campfire(folder, pos)
		local seen = {}
		if i == 1 then lit(true) end
		zone.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or R.runOf[player] ~= run or seen[player] then return end
			seen[player] = true
			run.checkpoint[player] = pos + Vector3.new(0, 3, 6)
			lit(true)
			if i > 1 then API.toast(player, "🔥 Campfire lit! If you faint, you wake up here.") end
		end)
		if i > 1 then R.chip(run, pos + Vector3.new(0, 9, 0), "🔥", "Campfire") end
	end

	-- 🔒 the boss gate across the trail to the arena (vines / ice / crystal per theme); the key makes it shrink away
	local gp = bossTrail.pts[5]
	local gdir = (bossTrail.pts[6] - bossTrail.pts[4]).Unit
	local gw = W(gp)
	local gateCF = CFrame.lookAt(gw + Vector3.new(0, D.LidH / 2, 0), gw + Vector3.new(gdir.X, D.LidH / 2, gdir.Y))
	local gate = P(blockers, {Name = "BossGate", Size = Vector3.new(bossTrail.w * 2 + 10, D.LidH + 2, 3), CFrame = gateCF,
		Color = th.Gate.Color, Material = th.Gate.Mat, Transparency = th.Gate.Mat == M.Glass and 0.25 or 0})
	light(gate, th.Gate.Color, 20, 1)
	local lockMsg = {}
	gate.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and R.runOf[player] == run and not run.hasKey and os.clock() - (lockMsg[player] or 0) > 4 then
			lockMsg[player] = os.clock()
			API.toast(player, "🔒 The way to the boss is blocked. Find the 🗝️ key down a side trail!")
		end
	end)
	R.chip(run, gw + Vector3.new(0, 14, 0), "🔒", "Boss gate")

	-- 🪜 ledge routes: a rock pillar to climb in S (stone steps spiral up it, or an obby of pads), bridges / pads
	-- along the trails at ledge height, a big pillar with a ✨ silver chest in T. Nothing climbs back up to T.
	local OBBY = {Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 200, 80), Color3.fromRGB(120, 220, 120), Color3.fromRGB(110, 180, 255), Color3.fromRGB(190, 140, 255)}
	local rockCol = th.PillarColor or Color3.fromRGB(150, 140, 135)
	local function pillar(p3, radius, top)
		local h = top - p3.Y + 1
		P(folder, {Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, radius * 2, radius * 2), CFrame = CFrame.new(p3 + Vector3.new(0, h / 2 - 1, 0)) * UP,
			Color = rockCol, Material = th.PillarMat or M.Rock})
		P(folder, {Name = "PillarTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, radius * 2 + 0.6, radius * 2 + 0.6), CFrame = CFrame.new(Vector3.new(p3.X, top - 0.2, p3.Z)) * UP,
			Color = th.Accent:Lerp(rockCol, 0.5), Material = M.Grass})
	end
	local function pad(p3, s, k)
		local col = OBBY[(k - 1) % #OBBY + 1]
		P(folder, {Name = "Pad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, s, s), CFrame = CFrame.new(p3 - Vector3.new(0, 0.5, 0)) * UP, Color = col})
		P(folder, {Name = "PadTrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, s + 0.4, s + 0.4), CFrame = CFrame.new(p3 - Vector3.new(0, 1.05, 0)) * UP,
			Color = col:Lerp(Color3.new(1, 1, 1), 0.4), Material = M.Neon, CanCollide = false})
	end
	local plankCol = Color3.fromRGB(175, 125, 80)
	local function plank(a, b) -- a rope-plank walkway between two world points at ledge height
		local mid, len = (a + b) / 2, (b - a).Magnitude
		if len < 0.5 then return end
		local cf = CFrame.lookAt(mid, mid + (b - a))
		P(folder, {Name = "Bridge", Size = Vector3.new(5, 0.8, len + 0.6), CFrame = cf * CFrame.new(0, -0.4, 0), Color = plankCol, Material = M.WoodPlanks})
		for _, s in {-1, 1} do
			P(folder, {Name = "Rope", Size = Vector3.new(0.3, 0.3, len + 0.6), CFrame = cf * CFrame.new(s * 2.4, 1.4, 0), Color = Color3.fromRGB(220, 190, 140), CanCollide = true})
		end
	end
	for ri, route in routes do
		local S, T = route[1], route[#route]
		local sC = NC(S)
		local topY = F + HB
		pillar(sC, 4, topY)
		if rng:NextNumber() >= tier.Obby then
			-- stone steps spiralling up around the pillar (close together: a walk-up, small hops at most)
			local a0 = rng:NextNumber(0, math.pi * 2)
			local steps = 11
			for k = 1, steps do
				local a = a0 + k * 0.52
				local y = sC.Y + (topY - sC.Y) * k / (steps + 1)
				P(folder, {Name = "Step", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 4.2, 4.2), CFrame = CFrame.new(sC.X + math.cos(a) * 6, y - 0.5, sC.Z + math.sin(a) * 6) * UP,
					Color = rockCol:Lerp(Color3.new(1, 1, 1), 0.15), Material = th.PillarMat or M.Rock})
			end
		else
			-- 🦘 obby: bright pads circling up (easy gaps for little jumpers)
			local a0 = rng:NextNumber(0, math.pi * 2)
			for k = 1, 4 do
				local a = a0 + k * 1.15
				pad(Vector3.new(sC.X + math.cos(a) * 8.5, sC.Y + (topY - sC.Y) * k / 5, sC.Z + math.sin(a) * 8.5), 5, k + ri)
			end
		end
		-- across: follow each trail at ledge height (bridge or pads), a small pillar where it passes a clearing
		for i = 1, #route - 1 do
			local tr, rev = trailOf(route[i], route[i + 1])
			if tr then
				local pts = {}
				for k = 1, #tr.pts do pts[k] = tr.pts[rev and (#tr.pts + 1 - k) or k] end
				local usePads = rng:NextNumber() < tier.Pads
				local a1, b1 = node[route[i]], node[route[i + 1]]
				local list = {}
				for k = 1, #pts do
					local p2 = pts[k]
					-- skip the bits over the pillars themselves (the walkway starts at their rim)
					if (p2 - a1.p).Magnitude > 3.5 and (p2 - b1.p).Magnitude > (route[i + 1] == T and 6.5 or 3.5) then
						table.insert(list, Vector3.new(O.X + p2.X, topY, O.Z + p2.Y))
					end
				end
				table.insert(list, 1, Vector3.new(O.X + a1.p.X, topY, O.Z + a1.p.Y) + (list[1] and (list[1] - Vector3.new(O.X + a1.p.X, topY, O.Z + a1.p.Y)).Unit * 3.5 or Vector3.zero))
				local bEdge = Vector3.new(O.X + b1.p.X, topY, O.Z + b1.p.Y)
				table.insert(list, bEdge + ((list[#list] - bEdge).Unit * (route[i + 1] == T and 6.5 or 3.5)))
				if usePads then
					local total = 0
					for k = 2, #list do total += (list[k] - list[k - 1]).Magnitude end
					local count = math.max(2, math.floor(total / 8))
					-- walk along the curve, dropping a pad every total/count studs
					local step, acc, k = total / (count + 1), 0, 2
					local walked, from = 0, list[1]
					for j = 1, count do
						local want = step * j
						while k <= #list and walked + (list[k] - from).Magnitude < want do
							walked += (list[k] - from).Magnitude
							from = list[k]
							k += 1
						end
						if k > #list then break end
						local p3 = from + (list[k] - from).Unit * (want - walked)
						pad(p3, 4.6, j + i + ri)
					end
				else
					for k = 2, #list do plank(list[k - 1], list[k]) end
				end
				if route[i + 1] ~= T then pillar(NC(route[i + 1]), 4, topY) end
			end
		end
		-- the ledge: a big rock pillar with the silver chest (seen from below, reached only from above)
		local tC = NC(T)
		pillar(tC, 6.5, topY)
		local tr = trailOf(route[#route - 1], T)
		local fromDir = tr and (Vector3.new(node[route[#route - 1]].p.X, 0, node[route[#route - 1]].p.Y) - Vector3.new(node[T].p.X, 0, node[T].p.Y)).Unit or Vector3.new(1, 0, 0)
		local chestPos = Vector3.new(tC.X, topY, tC.Z) - fromDir * 2
		run.makeChest(CFrame.lookAt(chestPos, chestPos + fromDir), "Silver")
	end

	-- 🗝️ the key (taking it opens the boss gate for everyone)
	local kc = NC(keyCell)
	local keyM, keyPart = keyModel(folder, kc)
	R.chip(run, kc + Vector3.new(0, 11, 0), "🗝️", "Key")
	local prompt = API.makePrompt(keyPart, "🗝️ Take", "Boss key")
	prompt.MaxActivationDistance = 12
	prompt.Triggered:Connect(function(player)
		if R.runOf[player] ~= run or run.hasKey then return end
		run.hasKey = true
		keyM:Destroy()
		gate.CanCollide = false
		gate.Parent = folder -- out of Blockers: attacks pass now
		API.pop(gate, "🔓")
		TweenService:Create(gate, TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{Size = Vector3.new(gate.Size.X, 0.2, gate.Size.Z), CFrame = gate.CFrame - Vector3.new(0, gate.Size.Y / 2, 0), Transparency = 1}):Play()
		task.delay(1.3, function() if gate.Parent then gate:Destroy() end end)
		toastRun(run, ("🗝️ %s found the key! The 👑 boss gate is open!"):format(player.DisplayName))
	end)

	-- 👾 mobs: in the clearings (never on the start, the boss's way in or a climbing pillar's clearing)
	local MOBS = ServerStorage:FindFirstChild("MobModels") and ServerStorage.MobModels:FindFirstChild(land)
	local normal, special, boss = {}, {}, nil
	for _, t in MOBS and MOBS:GetChildren() or {} do
		if t:IsA("Model") then
			if t:GetAttribute("Boss") then boss = t elseif t:GetAttribute("Special") then table.insert(special, t) else table.insert(normal, t) end
		end
	end
	local function mob(t, pos, roam, depth, role)
		local m = t:Clone()
		m:PivotTo(CFrame.new(pos.X, pos.Y + R.bottomOffset(t), pos.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		m:SetAttribute("Roam", roam)
		m:SetAttribute("Depth", depth)
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
	local function depthOf(c) return math.clamp(tier.Depth + math.floor((dist[c] or 0) / maxD * 2.99), 0, Data.MobScale.DepthMax) end
	if #normal > 0 then
		for c = 1, n * n do
			local guard = c == keyCell
			if c ~= start and c ~= bossCell and not climbRoom[c] and (guard or rng:NextNumber() < tier.Mobs) then
				local nd = node[c]
				local rMin = (marked[c] or onRoute[c]) and 8 or 3 -- keep clear of a landmark / pillar in the middle
				for i = 1, rng:NextInteger(2, guard and 4 or 3) do
					local list = ((guard and i == 1) or rng:NextNumber() < 0.07) and #special > 0 and special or normal
					local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(rMin, math.max(rMin + 1, nd.r - 4))
					local role = i > 1 and rng:NextNumber() < Data.MobRanged.Chance and "Ranged" or nil
					mob(list[rng:NextInteger(1, #list)], W(nd.p + Vector2.new(math.cos(a), math.sin(a)) * r), math.max(6, nd.r * 0.5), depthOf(c), role)
				end
			end
		end
	end
	-- 👑 the boss in the middle of the arena
	local ac = NC(ARENA)
	R.chip(run, ac + Vector3.new(0, 18, 0), "👑", boss and (boss.Name:gsub("(%l)(%u)", "%1 %2")) or "Boss")
	for k = 0, 5 do -- big glowing orbs around the arena so the fight is bright
		local a = k / 6 * math.pi * 2
		local p2 = node[ARENA].p + Vector2.new(math.cos(a), math.sin(a)) * (D.ArenaR - 3)
		local orb = egg(folder, {Name = "ArenaLight", Size = Vector3.one * 2.4, Position = W(p2) + Vector3.new(0, 9, 0), Color = th.Light, Material = M.Neon, CanCollide = false})
		light(orb, th.Light, 40, 1.4)
	end
	local function bossBeaten()
		if run.bossDone then return end
		run.bossDone = true
		task.wait(1.2)
		if not folder.Parent then return end
		local gpos = Vector3.new(gw.X, ac.Y, gw.Z)
		run.makeChest(CFrame.lookAt(ac, gpos), "Boss")
		local back = W(node[ARENA].p + outV * (D.ArenaR - 9))
		local ecf = CFrame.lookAt(back, Vector3.new(ac.X, back.Y, ac.Z))
		local _, g2 = R.exitPortal(folder, ecf, def)
		g2.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and R.runOf[player] == run then run.leave(player, "portal") end
		end)
		R.chip(run, (ecf * CFrame.new(0, 18, 0)).Position, "🏠", "Home")
		for p in run.inside do
			API.toast(p, "🎉 Dungeon cleared! Open the 🎁 boss chest, then hop in the portal home.")
			local prof = API.profiles[p]
			if prof then
				prof.DungeonTier = prof.DungeonTier or {}
				local best = prof.DungeonTier[land] or 0
				if API.dungeonCleared then -- ⭐ run score + 🎉 first-clear bonus (DungeonRewards)
					local ok, err = pcall(API.dungeonCleared, run, p, (run.tier or 1) > best)
					if not ok then warn("[Dungeons] score: " .. tostring(err)) end
				end
				if (run.tier or 1) > best then
					prof.DungeonTier[land] = run.tier or 1
					if (run.tier or 1) < #D.Tiers then
						API.toast(p, ("%s ⭐%d %s is open now!"):format(th.Icon, (run.tier or 1) + 1, th.Name))
					end
				end
			end
		end
	end
	if boss then
		local bm = mob(boss, ac, 12, 2)
		bm:GetAttributeChangedSignal("Dead"):Connect(function()
			if bm:GetAttribute("Dead") then task.spawn(bossBeaten) end
		end)
	else
		task.defer(bossBeaten) -- no boss model for this land yet: the chest is there from the start
	end

	-- 🧺 floor chests: at the far end of dead-end clearings (then other clearings off the main way)
	local spots = {}
	for _, c in deadEnds do if c ~= keyCell and not onRoute[c] then table.insert(spots, c) end end
	for i = #spots, 2, -1 do local j = rng:NextInteger(1, i) spots[i], spots[j] = spots[j], spots[i] end
	for c = 1, n * n do
		if #spots >= tier.Chests then break end
		if not onPath[c] and not busy[c] and not onRoute[c] and not table.find(spots, c) then table.insert(spots, c) end
	end
	for i = 1, math.min(tier.Chests, #spots) do
		local c = spots[i]
		local nd = node[c]
		local d = Vector2.zero
		for b in open[c] or {} do d += (node[b].p - nd.p).Unit end
		local back = d.Magnitude > 0.01 and -d.Unit or Vector2.new(1, 0)
		local pos = W(nd.p + back * (nd.r - 5))
		run.makeChest(CFrame.lookAt(pos, Vector3.new(O.X + nd.p.X, pos.Y, O.Z + nd.p.Y)), "Wood")
	end

	-- 🙈 hidden chests: in each nook, behind a bush you walk through or a cracked rock you break
	for i, nk in nooks do
		local fwd = Vector3.new(nk.dir.X, 0, nk.dir.Y)
		local inside = W(nk.p + nk.dir * 1.5)
		local mouth = W(nk.home.p + nk.dir * (nk.home.r + 0.5))
		run.makeChest(CFrame.lookAt(inside, Vector3.new(mouth.X, inside.Y, mouth.Z)), "Hidden")
		local face = CFrame.lookAt(mouth, mouth + fwd) -- -Z points into the nook
		if (i + rng:NextInteger(0, 1)) % 2 == 0 then
			-- 🌿 a bush wall: soft, you walk right through it (a few sparkles hint at it)
			local leaf = land == "Peaks" and Color3.fromRGB(225, 240, 255) or (land == "Volcano" and Color3.fromRGB(110, 80, 80) or Color3.fromRGB(80, 165, 70))
			local mat = land == "Peaks" and M.Snow or M.Grass
			for k = 1, 9 do
				local x, y = ((k - 1) % 3 - 1) * 3.2 + rng:NextNumber(-0.6, 0.6), ((k - 1) // 3) * 2.6 + 2
				local b = egg(folder, {Name = "SecretBush", Size = Vector3.new(rng:NextNumber(4.4, 5.6), rng:NextNumber(3.6, 4.6), 3.6),
					CFrame = face * CFrame.new(x, y, rng:NextNumber(-0.6, 0.6)), Color = leaf:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.18)),
					Material = mat, CanCollide = false, CanQuery = false, CanTouch = false})
				if k == 5 then sparkle(b, Color3.fromRGB(255, 240, 150), 2) end
			end
		else
			-- 🪨 a cracked rock: hold ⛏️ to break it (its cracks glow a little)
			local rock = egg(blockers, {Name = "CrackedRock", Size = Vector3.new(11, 9, 5), CFrame = face * CFrame.new(0, 4.2, 0),
				Color = th.PillarColor, Material = th.PillarMat, CanQuery = true})
			local cracks = {}
			for _, c in {{-1.6, 1.2, 25}, {1.2, -0.4, -35}, {0.2, 2.3, 70}} do
				table.insert(cracks, P(folder, {Name = "Crack", Size = Vector3.new(3.4, 0.25, 0.3), CFrame = face * CFrame.new(c[1], 4.2 + c[2], 2.45) * CFrame.Angles(0, 0, math.rad(c[3])),
					Color = th.Accent, Material = M.Neon, Transparency = 0.25, CanCollide = false, CanQuery = false, CanTouch = false}))
			end
			local prompt = API.makePrompt(rock, "⛏️ Break", "Cracked rock")
			prompt.HoldDuration = D.RockHold or 1.2
			prompt.Triggered:Connect(function(player)
				if R.runOf[player] ~= run or not rock.Parent then return end
				API.pop(rock, "💥")
				local at = rock.CFrame
				for _, c in cracks do c:Destroy() end
				rock:Destroy()
				for _ = 1, 6 do -- bits that tumble away and vanish
					local bit = egg(folder, {Size = Vector3.one * rng:NextNumber(1.2, 2.2), CFrame = at * CFrame.new(rng:NextNumber(-3, 3), rng:NextNumber(-2, 2), 0),
						Color = th.PillarColor, Material = th.PillarMat, Anchored = false, CanCollide = false, CanQuery = false, CanTouch = false})
					bit.AssemblyLinearVelocity = (at.LookVector * -1 + Vector3.new(rng:NextNumber(-1, 1), 1, rng:NextNumber(-1, 1))) * 18
					task.delay(1.4, function() if bit.Parent then bit:Destroy() end end)
				end
				API.toast(player, "💥 The rock broke! A secret chest!")
			end)
		end
	end

	-- 🏃 the runaway chest: it hops off down the trails when someone comes close, then gets tired
	do
		local cands = {}
		for c = 1, n * n do
			if not busy[c] and not onRoute[c] and c ~= start then table.insert(cands, c) end
		end
		for _ = 1, math.min(tier.Runaway or 0, #cands) do
			local c = table.remove(cands, rng:NextInteger(1, #cands))
			local nd = node[c]
			local at = W(nd.p + Vector2.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * nd.r * 0.4)
			local box, m = run.makeChest(CFrame.new(at), "Runaway")
			local prompt = box:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt.Enabled = false end
			-- googly eyes on the front
			local pv = m:GetPivot()
			for _, x in {-1, 1} do
				local eye = egg(m, {Name = "Eye", Size = Vector3.one * 1.1, CFrame = pv * CFrame.new(x * 0.95, 2.1, -1.45), Color = Color3.new(1, 1, 1), CanCollide = false, CanQuery = false, CanTouch = false})
				egg(m, {Name = "Pupil", Size = Vector3.one * 0.5, CFrame = eye.CFrame * CFrame.new(0, -0.05, -0.38), Color = Color3.fromRGB(30, 30, 40), CanCollide = false, CanQuery = false, CanTouch = false})
			end
			local cur, hops, told = c, 0, {}
			local function hop(from, to, t, h)
				local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
				local look = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, -1)
				local steps = math.max(5, math.floor(t * 30))
				for k = 1, steps do
					if not m.Parent then return end
					local a = k / steps
					local p = from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * h, 0)
					m:PivotTo(CFrame.lookAt(p, p + look))
					task.wait(t / steps)
				end
			end
			task.spawn(function()
				while m.Parent and hops < (D.RunawayHops or 3) do
					task.wait(0.25)
					local pos = m:GetPivot().Position
					local near = {}
					for p in run.inside do
						local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
						if hrp and (hrp.Position - pos).Magnitude < (D.RunawayNear or 16) then table.insert(near, p) end
					end
					if #near > 0 then
						hops += 1
						for _, p in near do
							if not told[p] then told[p] = true API.toast(p, "🏃 A chest ran away! Catch it!") end
						end
						-- off down a trail to a linked clearing (never the boss arena), bouncing along
						local opts = {}
						for b in open[cur] or {} do table.insert(opts, b) end
						local nxt = #opts > 0 and opts[rng:NextInteger(1, #opts)] or cur
						local tr, rev = trailOf(cur, nxt)
						local from = pos
						if tr and nxt ~= cur then
							for k = 1, #tr.pts do
								local q = rev and tr.pts[#tr.pts + 1 - k] or tr.pts[k]
								local to = W(q)
								hop(from, to, 0.32, 2.2)
								from = to
							end
						end
						local nn = node[nxt]
						local to = W(nn.p + Vector2.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * nn.r * 0.45)
						hop(from, to, 0.45, 3)
						cur = nxt
					end
				end
				if not m.Parent then return end
				if prompt then prompt.Enabled = true end
				local pos = m:GetPivot().Position
				for p in run.inside do
					local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					if hrp and (hrp.Position - pos).Magnitude < 60 then API.toast(p, "😮‍💨 The chest is tired! Open it now!") end
				end
			end)
		end
	end

	-- a walkable spot for flying critters / buddy pets: somewhere in a clearing
	local nodeList = {}
	for _, nd in node do table.insert(nodeList, nd) end
	run.pickPoint = function()
		local nd = nodeList[Random.new():NextInteger(1, #nodeList)]
		return Vector3.new(O.X + nd.p.X, 0, O.Z + nd.p.Y)
	end
	run.layout = {dungeon = true}
	run.t0 = os.clock() -- ⭐ the run score's clock
end

---------------------------------------------------------------- chests (loot rolls live here so Realms stays small)
local CHEST = {
	Wood = {Scale = 0.75, Res = {1, 3}, Text = "🧺 Chest! ", Act = "🧺 Open", Obj = "Chest", Pop = "✨"},
	Silver = {Scale = 0.85, Res = {2, 4}, Text = "✨ Silver chest! ", Act = "✨ Open", Obj = "Silver chest", Pop = "🌟"},
	Boss = {Scale = 1.2, Res = {3, 6}, Text = "🎁 Boss chest! ", Act = "🎁 Open", Obj = "Boss chest", Pop = "🎉"},
	Hidden = {Scale = 0.8, Res = {2, 4}, Text = "🙈 Secret chest! ", Act = "🙈 Open", Obj = "Secret chest", Pop = "🌟"},
	Runaway = {Scale = 0.8, Res = {2, 5}, Text = "🏃 You caught the runaway chest! ", Act = "🏃 Open", Obj = "Runaway chest", Pop = "🎉"},
}
local function makeChestFor(run)
	local land = run.terrain
	local tier = D.Tiers[run.tier or 1] or D.Tiers[1]
	return function(cf, kind)
		local k = CHEST[kind] or CHEST.Wood
		local mult = ({Boss = D.BossChestX, Silver = D.SilverX, Hidden = D.HiddenX, Runaway = D.RunawayX})[kind] or 1
		local capChance = ({Boss = 1, Silver = D.SilverCapsule, Hidden = D.HiddenCapsule, Runaway = D.RunawayCapsule})[kind] or D.ChestCapsule
		local m, box = R.treasure(run.folder, cf, {Color = (D.Themes[land] or D.Themes.Meadow).Accent}, k.Scale)
		if kind ~= "Boss" then run.chestTotal = (run.chestTotal or 0) + 1 end -- (⭐ run score: find half of them)
		if kind == "Silver" then -- silver bands instead of gold
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") and p.Material == M.Metal then p.Color = Color3.fromRGB(215, 225, 240) end
			end
		end
		local seen = {}
		local prompt = API.makePrompt(box, k.Act, k.Obj)
		prompt.MaxActivationDistance = kind == "Silver" and 7 or 12 -- (a ledge chest can't be opened from the ground below)
		prompt.Triggered:Connect(function(player)
			if R.runOf[player] ~= run then return end
			if seen[player.UserId] then API.toast(player, "🧺 You already opened this one. Find another!") return end
			seen[player.UserId] = true
			if kind ~= "Boss" then
				run.found = run.found or {}
				run.found[player] = (run.found[player] or 0) + 1
			end
			local got = {}
			local x = kind == "Boss" and run.scoreX and run.scoreX[player] or 1 -- (⭐ run score bonus)
			local coins = math.floor((D.ChestCoins[land] or 40) * tier.Loot * mult * x + 0.5)
			API.addCoins(player, coins)
			table.insert(got, ("💰 +%d"):format(coins))
			for _, res in R.resOf(land) do
				local nRes = math.random(k.Res[1], k.Res[2])
				API.addRes(player, res, nRes)
				table.insert(got, ("%s +%d"):format(Data.ResByName[res] and Data.ResByName[res].Icon or "📦", nRes))
			end
			if API.giveCapsule and math.random() < capChance then
				API.giveCapsule(player, land, 1)
				local cap = Data.Capsules[land]
				if cap then table.insert(got, cap.Icon .. " " .. cap.Name) end
			end
			API.pop(box, k.Pop)
			API.toast(player, k.Text .. table.concat(got, "  "))
			-- 📜 a furniture scroll: always in the boss chest, sometimes in the special chests
			if API.dungeonScroll and kind ~= "Wood" then
				local ok, text = pcall(API.dungeonScroll, player, land, kind == "Boss", tier.Loot)
				if ok and text then API.toast(player, text) elseif not ok then warn("[Dungeons] scroll: " .. tostring(text)) end
			end
		end)
		return box, m
	end
end

API.buildDungeon = function(run)
	run.makeChest = makeChestFor(run)
	build(run)
end

print("[Dungeons] ready")
