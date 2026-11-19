-- Critter Acres: DungeonExtras (ServerScriptService)
-- 🏰 Dungeon stage 4. ServerScriptService.Dungeons builds the map, fills run.map and then calls API.dungeonExtras(run):
--   🧩 easy puzzles in quiet clearings (tier.Puzzles). Solving one brings a 🧩 Puzzle chest:
--        🔥 Torches: light every torch around the clearing.  🎨 Colour tiles: step on the tiles in the order the post shows
--        (top to bottom; a wrong step starts it again).  📦 Push block: push the crate onto the glowing switch (🔄 puts it back).
--   🌟 secret spots (tier.Secrets): a little twinkling star tucked at a clearing's edge; touch it for coins (once each).
--   🟢 cute traps on the trails (tier.Traps), all harmless: sticky puddles (slower for a moment), 🦘 bounce pads, rolling balls
--        that bonk you back (⛄ snowballs in the Ice Halls). The client (StarterPlayerScripts.DungeonMap) does the effects.
--   👑 the boss calls tier.Helpers mobs when its HP drops below Data.Dungeon.HelperAt.
--   🐾 sniff / 🏠 way home / 🗺️ minimap: RemoteEvent ReplicatedStorage.DungeonEvent (Kind "Sniff", "Home", "Map", "Bonk").
-- 🔘 lever doors are built by Dungeons itself (they are part of the terrain nooks). All numbers: Data.Dungeon (CritterData).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local t0 = os.clock()
while not API.realmHooks and os.clock() - t0 < 30 do task.wait(0.2) end
local R = API.realmHooks
if not R then warn("[DungeonExtras] Realms hooks missing") return end
local Data = API.Data
local D = Data.Dungeon
local M = Enum.Material
local event = ReplicatedStorage:WaitForChild("DungeonEvent", 60)
if not event then warn("[DungeonExtras] no DungeonEvent") return end
local UP = CFrame.Angles(0, 0, math.pi / 2)

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
	props.Shape = Enum.PartType.Ball
	return P(parent, props)
end
local function light(part, color, range, bright)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range or 14, bright or 1
	l.Parent = part
	return l
end
local function sparkle(part, color, rate)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)})
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Rate = rate or 3
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 0.8
	e.Parent = part
	return e
end
local function toastRun(run, text)
	for p in run.inside do API.toast(p, text) end
end
local function hrpOf(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local function loc(map, pos) return Vector2.new(pos.X - map.O.X, pos.Z - map.O.Z) end

---------------------------------------------------------------- map helpers: nearest clearing + the way along the trails
local function nearestCell(map, pos)
	local p2 = loc(map, pos)
	local best, bd = nil, math.huge
	for c, nd in map.node do
		local d = (p2 - nd.p).Magnitude - nd.r
		if d < bd then best, bd = c, d end
	end
	return best
end
local function nbrs(map, c)
	local list = {}
	for b in map.open[c] or {} do table.insert(list, b) end
	if c == map.bossCell then table.insert(list, map.arena) end
	if c == map.arena then table.insert(list, map.bossCell) end
	return list
end
local function bfs(map, from)
	local dist, prev, q = {[from] = 0}, {}, {from}
	local i = 1
	while q[i] do
		local c = q[i]
		i += 1
		for _, b in nbrs(map, c) do
			if dist[b] == nil then dist[b], prev[b] = dist[c] + 1, c table.insert(q, b) end
		end
	end
	return dist, prev
end
-- world points from clearing a to clearing b along the trails (nil if there's no way)
local function wayPoints(map, a, b)
	local _, prev = bfs(map, a)
	local cells, c = {}, b
	while c ~= nil do
		table.insert(cells, 1, c)
		if c == a then break end
		c = prev[c]
	end
	if cells[1] ~= a then return nil end
	local pts = {map.W(map.node[a].p)}
	for i = 1, #cells - 1 do
		local tr, rev = map.trailOf(cells[i], cells[i + 1])
		if tr then
			for k = 2, #tr.pts do
				table.insert(pts, map.W(rev and tr.pts[#tr.pts + 1 - k] or tr.pts[k]))
			end
		else
			table.insert(pts, map.W(map.node[cells[i + 1]].p))
		end
	end
	return pts
end

---------------------------------------------------------------- 🧩 puzzles
local function puzzleChest(run, map, nd, at, by)
	local look = Vector3.new(map.O.X + nd.p.X, at.Y, map.O.Z + nd.p.Y)
	if (look - at).Magnitude < 0.5 then look = at + Vector3.new(0, 0, -1) end
	run.makeChest(CFrame.lookAt(at, look), "Puzzle")
	toastRun(run, ("🧩 %s solved a puzzle! A chest popped up."):format(by.DisplayName))
end
-- a spot at the clearing's edge, away from the trail mouths
local function edgeSpot(map, nd, a, inset)
	for k = 0, 8 do
		local aa = a + (k % 2 == 0 and 1 or -1) * math.ceil(k / 2) * 0.22
		local p2 = nd.p + Vector2.new(math.cos(aa), math.sin(aa)) * (nd.r - inset)
		local _, dPath = map.field(p2)
		if dPath > 2.5 then return p2 end
	end
	return nd.p + Vector2.new(math.cos(a), math.sin(a)) * (nd.r - inset)
end

local PUZZLE = {}
function PUZZLE.Torches(run, map, nd)
	local rng, folder, th = map.rng, map.folder, map.theme
	local count = 3
	local a0 = rng:NextNumber(0, math.pi * 2)
	local lit, done = 0, false
	for i = 1, count do
		local p2 = edgeSpot(map, nd, a0 + (i - 1) * math.pi * 2 / count, 3.5)
		local w = map.W(p2)
		local post = P(folder, {Name = "TorchPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.5, 1, 1), CFrame = CFrame.new(w + Vector3.new(0, 2.25, 0)) * UP,
			Color = Color3.fromRGB(130, 90, 60), Material = M.Wood})
		P(folder, {Name = "TorchBowl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 2.2, 2.2), CFrame = CFrame.new(w + Vector3.new(0, 4.7, 0)) * UP,
			Color = th.PillarColor or Color3.fromRGB(140, 130, 125), Material = th.PillarMat or M.Slate})
		local flame = egg(folder, {Name = "TorchFlame", Size = Vector3.new(1.4, 1.8, 1.4), Position = w + Vector3.new(0, 5.6, 0), Color = Color3.fromRGB(255, 160, 50),
			Material = M.Neon, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
		local l = light(flame, Color3.fromRGB(255, 170, 80), 18, 1.4)
		l.Enabled = false
		local prompt = API.makePrompt(post, "🔥 Light", "Torch")
		prompt.MaxActivationDistance = 10
		prompt.Triggered:Connect(function(player)
			if R.runOf[player] ~= run or done or not prompt.Enabled then return end
			prompt.Enabled = false
			flame.Transparency = 0.1
			l.Enabled = true
			local f = Instance.new("Fire")
			f.Size, f.Heat = 3, 4
			f.Parent = flame
			lit += 1
			API.pop(flame, "🔥")
			if lit >= count then
				done = true
				puzzleChest(run, map, nd, map.W(nd.p), player)
			else
				for p in run.inside do
					local h = hrpOf(p)
					if h and (h.Position - w).Magnitude < nd.r + 20 then API.toast(p, ("🔥 %d of %d torches lit!"):format(lit, count)) end
				end
			end
		end)
	end
	R.chip(run, map.W(nd.p) + Vector3.new(0, 9, 0), "🔥", "Light the torches")
end

local TILE_COLS = {
	{Color3.fromRGB(240, 90, 90), "red"}, {Color3.fromRGB(255, 205, 60), "yellow"}, {Color3.fromRGB(90, 160, 255), "blue"}, {Color3.fromRGB(110, 215, 95), "green"},
}
function PUZZLE.Tiles(run, map, nd)
	local rng, folder = map.rng, map.folder
	local cols = table.clone(TILE_COLS)
	for i = #cols, 2, -1 do local j = rng:NextInteger(1, i) cols[i], cols[j] = cols[j], cols[i] end
	local n = 3
	-- the hint post in the middle: orbs top (1st) to bottom (3rd)
	local c3 = map.W(nd.p)
	P(folder, {Name = "HintPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 0.8, 0.8), CFrame = CFrame.new(c3 + Vector3.new(0, 4, 0)) * UP,
		Color = Color3.fromRGB(240, 235, 225), Material = M.Marble})
	for i = 1, n do
		local orb = egg(folder, {Name = "HintOrb", Size = Vector3.one * 1.6, Position = c3 + Vector3.new(0, 8.6 - (i - 1) * 2, 0), Color = cols[i][1], Material = M.Neon, CanCollide = false})
		if i == 1 then sparkle(orb, cols[1][1], 2) end
	end
	R.chip(run, c3 + Vector3.new(0, 12, 0), "🎨", "Colours in order")
	-- tiles around the post, in a mixed-up order
	local tiles = {}
	local order = {}
	for i = 1, n do order[i] = i end
	for i = n, 2, -1 do local j = rng:NextInteger(1, i) order[i], order[j] = order[j], order[i] end
	local a0 = rng:NextNumber(0, math.pi * 2)
	for k = 1, n do
		local ci = order[k]
		local a = a0 + (k - 1) * math.pi * 2 / n
		local w = map.W(nd.p + Vector2.new(math.cos(a), math.sin(a)) * 7)
		local tile = P(folder, {Name = "ColourTile", Size = Vector3.new(5, 0.5, 5), CFrame = CFrame.new(w + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, a, 0),
			Color = cols[ci][1]:Lerp(Color3.new(1, 1, 1), 0.25), Material = M.SmoothPlastic})
		P(folder, {Name = "TileRim", Size = Vector3.new(5.6, 0.3, 5.6), CFrame = tile.CFrame * CFrame.new(0, -0.15, 0), Color = Color3.fromRGB(240, 235, 225), Material = M.Marble})
		tiles[ci] = tile
	end
	local nextI, done, on, oops = 1, false, {}, {}
	local function reset()
		nextI = 1
		for ci, t in tiles do
			t.Material = M.SmoothPlastic
			t.Color = cols[ci][1]:Lerp(Color3.new(1, 1, 1), 0.25)
		end
	end
	task.spawn(function()
		while not done and map.folder.Parent do
			task.wait(0.15)
			for p in run.inside do
				local h = hrpOf(p)
				local stand = nil
				if h then
					for ci, t in tiles do
						local d = Vector2.new(h.Position.X - t.Position.X, h.Position.Z - t.Position.Z)
						if math.abs(d.X) < 2.8 and math.abs(d.Y) < 2.8 and math.abs(h.Position.Y - t.Position.Y) < 5 then stand = ci break end
					end
				end
				if stand and on[p] ~= stand then
					if stand == nextI then
						local t = tiles[stand]
						t.Material, t.Color = M.Neon, cols[stand][1]
						API.pop(t, "✨")
						nextI += 1
						if nextI > n then
							done = true
							puzzleChest(run, map, nd, map.W(nd.p + Vector2.new(math.cos(a0 + math.pi / n), math.sin(a0 + math.pi / n)) * 4), p)
						end
					elseif stand > nextI or tiles[stand].Material ~= M.Neon then
						reset()
						if os.clock() - (oops[p] or 0) > 3 then
							oops[p] = os.clock()
							API.toast(p, ("🔄 Oops! Start again: %s first (the top orb)."):format(cols[1][2]))
						end
					end
				end
				on[p] = stand
			end
		end
	end)
end

function PUZZLE.Block(run, map, nd)
	local rng, folder = map.rng, map.folder
	local dirs = {Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1)}
	local u = dirs[rng:NextInteger(1, 4)]
	local STEP = 4
	local startP = nd.p - u * STEP
	local padP = nd.p + u * STEP * 2
	local padW = map.W(padP)
	local pad = P(folder, {Name = "Switch", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 6, 6), CFrame = CFrame.new(padW + Vector3.new(0, 0.15, 0)) * UP,
		Color = Color3.fromRGB(255, 205, 60), Material = M.Neon})
	sparkle(pad, Color3.fromRGB(255, 230, 120), 3)
	local crate = P(folder, {Name = "PushBlock", Size = Vector3.new(4.6, 4.6, 4.6), CFrame = CFrame.new(map.W(startP) + Vector3.new(0, 2.3, 0)),
		Color = Color3.fromRGB(190, 135, 80), Material = M.WoodPlanks})
	for _, e in {Vector3.new(0, 2.35, 0), Vector3.new(0, -2.35, 0)} do
		P(crate, {Name = "Band", Size = Vector3.new(4.8, 0.4, 4.8), CFrame = crate.CFrame + e, Color = Color3.fromRGB(120, 85, 55), Material = M.Wood, CanCollide = false, CanQuery = false})
	end
	-- (the bands follow the crate: weld them)
	for _, b in crate:GetChildren() do
		if b:IsA("BasePart") then b.Anchored = false local wd = Instance.new("WeldConstraint") wd.Part0, wd.Part1, wd.Parent = crate, b, b end
	end
	R.chip(run, map.W(nd.p) + Vector3.new(0, 10, 0), "📦", "Box on the switch")
	local at, done, busy = startP, false, false
	local push = API.makePrompt(crate, "📦 Push", "Box")
	push.MaxActivationDistance = 9
	local back = API.makePrompt(pad, "🔄 Box back", "Switch")
	back.HoldDuration = 0.5
	back.MaxActivationDistance = 10
	local function moveTo(p2, player)
		busy = true
		at = p2
		local w = map.W(p2)
		local tw = TweenService:Create(crate, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {CFrame = CFrame.new(w + Vector3.new(0, 2.3, 0))})
		tw:Play()
		tw.Completed:Wait()
		busy = false
		if (at - padP).Magnitude < 1 and not done then
			done = true
			push.Enabled, back.Enabled = false, false
			pad.Color = Color3.fromRGB(110, 215, 95)
			crate.Material = M.Neon
			crate.Color = Color3.fromRGB(255, 220, 140)
			puzzleChest(run, map, nd, map.W(nd.p - u * STEP * 2 + Vector2.new(u.Y, -u.X) * 5), player)
		end
	end
	push.Triggered:Connect(function(player)
		if R.runOf[player] ~= run or done or busy then return end
		local h = hrpOf(player)
		if not h then return end
		local away = loc(map, crate.Position) - loc(map, h.Position)
		local d = math.abs(away.X) >= math.abs(away.Y) and Vector2.new(math.sign(away.X), 0) or Vector2.new(0, math.sign(away.Y))
		local nxt = at + d * STEP
		if (nxt - nd.p).Magnitude > nd.r - 4 then
			API.toast(player, "📦 It won't go that way. Push from another side!")
			return
		end
		moveTo(nxt, player)
	end)
	back.Triggered:Connect(function(player)
		if R.runOf[player] ~= run or done or busy then return end
		moveTo(startP, player)
	end)
end

local function addPuzzles(run, map)
	local rng, tier = map.rng, map.tier
	local want = tier.Puzzles or 0
	if want <= 0 then return end
	local nookHome = {}
	for _, nk in map.nooks do nookHome[nk.home] = true end
	local cands = {}
	for c, nd in map.node do
		if c ~= map.start and c ~= map.bossCell and c ~= map.keyCell and c ~= map.arena and not map.busy[c] and not map.onRoute[c]
			and not map.marked[c] and not nookHome[nd] and nd.r >= 13.5 then table.insert(cands, c) end
	end
	table.sort(cands, function(a, b) return tostring(a) < tostring(b) end)
	for i = #cands, 2, -1 do local j = rng:NextInteger(1, i) cands[i], cands[j] = cands[j], cands[i] end
	local kinds = {"Torches", "Tiles", "Block"}
	local k0 = rng:NextInteger(0, 2)
	run.puzzleCells = {}
	for i = 1, math.min(want, #cands) do
		local c = cands[i]
		run.puzzleCells[c] = true
		local ok, err = pcall(PUZZLE[kinds[(k0 + i - 1) % 3 + 1]], run, map, map.node[c])
		if not ok then warn("[DungeonExtras] puzzle: " .. tostring(err)) end
	end
end

---------------------------------------------------------------- 🌟 secret spots
local function addSecrets(run, map)
	local rng, tier = map.rng, map.tier
	local cands = {}
	for c in map.node do
		if c ~= map.start and c ~= map.arena and not (run.puzzleCells and run.puzzleCells[c]) then table.insert(cands, c) end
	end
	table.sort(cands, function(a, b) return tostring(a) < tostring(b) end)
	local spots = {}
	for _ = 1, math.min(tier.Secrets or 0, #cands) do
		local c = table.remove(cands, rng:NextInteger(1, #cands))
		local nd = map.node[c]
		local p2 = edgeSpot(map, nd, rng:NextNumber(0, math.pi * 2), 1.6)
		local w = map.W(p2)
		local star = egg(map.folder, {Name = "SecretStar", Size = Vector3.one * 1.3, Position = w + Vector3.new(0, 1.4, 0), Color = Color3.fromRGB(255, 225, 90),
			Material = M.Neon, CanCollide = false, CanQuery = false, CanTouch = false})
		sparkle(star, Color3.fromRGB(255, 240, 160), 4)
		light(star, Color3.fromRGB(255, 220, 120), 8, 0.8)
		TweenService:Create(star, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Position = star.Position + Vector3.new(0, 0.8, 0)}):Play()
		table.insert(spots, {star = star, got = {}})
	end
	if #spots == 0 then return end
	task.spawn(function()
		while map.folder.Parent do
			task.wait(0.3)
			for p in run.inside do
				local h = hrpOf(p)
				if h then
					for _, s in spots do
						if not s.got[p] and (h.Position - s.star.Position).Magnitude < 5 then
							s.got[p] = true
							local coins = math.floor((D.SecretCoins or 30) * (map.tier.Loot or 1) + 0.5)
							API.addCoins(p, coins)
							API.pop(s.star, "🌟")
							API.toast(p, ("🌟 You found a secret spot! 💰 +%d"):format(coins))
						end
					end
				end
			end
		end
	end)
end

---------------------------------------------------------------- 🟢 cute traps (the client does the bouncing / slowing / bonking)
local TRAP_LOOK = { -- puddle colour + material, rolling ball colour + material
	Meadow = {Puddle = {Color3.fromRGB(120, 230, 100), M.Glass}, Ball = {Color3.fromRGB(130, 235, 110), M.Glass}, Icon = "🟢"},
	Forest = {Puddle = {Color3.fromRGB(110, 80, 55), M.Mud}, Ball = {Color3.fromRGB(150, 100, 55), M.Wood}, Icon = "🌰"},
	Peaks = {Puddle = {Color3.fromRGB(190, 230, 255), M.Ice}, Ball = {Color3.fromRGB(245, 250, 255), M.Snow}, Icon = "⛄"},
	Caves = {Puddle = {Color3.fromRGB(170, 110, 240), M.Glass}, Ball = {Color3.fromRGB(180, 130, 255), M.Glass}, Icon = "💎"},
	Volcano = {Puddle = {Color3.fromRGB(70, 60, 70), M.Slate}, Ball = {Color3.fromRGB(150, 140, 140), M.Slate}, Icon = "🪨"},
}
local function addTraps(run, map)
	local rng, tier = map.rng, map.tier
	local look = TRAP_LOOK[map.land] or TRAP_LOOK.Meadow
	local list = {}
	for _, tr in map.trails do
		if tr.b ~= map.arena and tr.a ~= map.arena and tr.a ~= map.start and tr.b ~= map.start then table.insert(list, tr) end
	end
	for i = #list, 2, -1 do local j = rng:NextInteger(1, i) list[i], list[j] = list[j], list[i] end
	local kinds = {"Puddle", "Bounce", "Roller"}
	local k0 = rng:NextInteger(0, 2)
	for i = 1, math.min(tier.Traps or 0, #list) do
		local tr = list[i]
		local kind = kinds[(k0 + i - 1) % 3 + 1]
		local k = rng:NextInteger(3, #tr.pts - 2)
		local w = map.W(tr.pts[k])
		if kind == "Puddle" then
			local r = math.max(4, tr.w * 0.85)
			local pud = P(map.folder, {Name = "StickyPuddle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, r * 2, r * 2), CFrame = CFrame.new(w + Vector3.new(0, 0.05, 0)) * UP,
				Color = look.Puddle[1], Material = look.Puddle[2], Transparency = look.Puddle[2] == M.Glass and 0.2 or 0, CanCollide = false, CanQuery = false})
			for b = 1, 3 do -- a few bubbles
				local a = rng:NextNumber(0, math.pi * 2)
				egg(map.folder, {Name = "Bubble", Size = Vector3.one * rng:NextNumber(0.6, 1.1), Position = w + Vector3.new(math.cos(a) * r * 0.5, 0.25, math.sin(a) * r * 0.5),
					Color = look.Puddle[1]:Lerp(Color3.new(1, 1, 1), 0.4), Material = M.Glass, Transparency = 0.2, CanCollide = false, CanQuery = false, CanTouch = false})
			end
			pud:SetAttribute("R", r)
			CollectionService:AddTag(pud, "DungeonPuddle")
		elseif kind == "Bounce" then
			local pad = P(map.folder, {Name = "BouncePad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 6, 6), CFrame = CFrame.new(w + Vector3.new(0, 0.3, 0)) * UP,
				Color = Color3.fromRGB(255, 120, 170), Material = M.SmoothPlastic})
			P(map.folder, {Name = "BounceRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4.2, 4.2), CFrame = CFrame.new(w + Vector3.new(0, 0.8, 0)) * UP,
				Color = Color3.fromRGB(255, 225, 240), Material = M.Neon, CanCollide = false, CanQuery = false, CanTouch = false})
			pad:SetAttribute("R", 3.2)
			CollectionService:AddTag(pad, "DungeonBounce")
		else
			-- the ball rolls back and forth along the trail (each client moves its own copy in step with the server clock)
			local pts = {}
			for j = 2, #tr.pts - 1 do
				local q = map.W(tr.pts[j])
				table.insert(pts, ("%.1f,%.1f,%.1f"):format(q.X, q.Y, q.Z))
			end
			local path = P(map.folder, {Name = "RollerPath", Size = Vector3.one * 0.2, Position = w, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
			path:SetAttribute("Pts", table.concat(pts, ";"))
			path:SetAttribute("Period", rng:NextNumber(5.5, 8))
			path:SetAttribute("Size", 4)
			path:SetAttribute("Color", look.Ball[1])
			path:SetAttribute("Mat", look.Ball[2].Name)
			CollectionService:AddTag(path, "DungeonRoller")
		end
	end
end

---------------------------------------------------------------- 👑 the boss calls helpers
local function addHelpers(run, map)
	local boss, n = map.boss, map.tier.Helpers or 0
	if not boss or n <= 0 or #map.normal == 0 then return end
	local called = false
	boss:GetAttributeChangedSignal("HP"):Connect(function()
		if called then return end
		local hp, max = boss:GetAttribute("HP"), boss:GetAttribute("MaxHP")
		if not hp or not max or max <= 0 or hp <= 0 or hp / max > (D.HelperAt or 0.5) then return end
		called = true
		local ctr = map.node[map.arena]
		local rng = Random.new()
		for i = 1, n do
			local a = (i / n) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local p = map.W(ctr.p + Vector2.new(math.cos(a), math.sin(a)) * math.min(ctr.r - 6, 14))
			local ok, err = pcall(map.mob, map.normal[rng:NextInteger(1, #map.normal)], p, 10, math.clamp((map.tier.Depth or 0) + 1, 0, Data.MobScale.DepthMax))
			if not ok then warn("[DungeonExtras] helper: " .. tostring(err)) end
		end
		local part = boss.PrimaryPart or boss:FindFirstChildWhichIsA("BasePart", true)
		if part then API.pop(part, "📣") end
		toastRun(run, "👑 The boss called for help! 👾 Watch out!")
	end)
end

---------------------------------------------------------------- the 🗺️ map for the client
local function mapMsg(run, map)
	if run.mapMsg then return run.mapMsg end
	local nodes, trails = {}, {}
	local fireAt = {}
	for _, c in map.fires do fireAt[c] = true end
	for c, nd in map.node do
		local tag = (c == map.start and "start") or (c == map.arena and "boss") or (c == map.keyCell and "key") or (fireAt[c] and "fire") or nil
		local z = map.zoneOf[c]
		table.insert(nodes, {Id = tostring(c), X = nd.p.X, Z = nd.p.Y, R = nd.r, Col = z and z.Color or map.theme.Accent, Tag = tag})
	end
	for _, tr in map.trails do
		local p = {}
		for k = 1, #tr.pts, 2 do table.insert(p, tr.pts[k].X) table.insert(p, tr.pts[k].Y) end
		local last = tr.pts[#tr.pts]
		if #tr.pts % 2 == 0 then table.insert(p, last.X) table.insert(p, last.Y) end
		table.insert(trails, {A = tostring(tr.a), B = tostring(tr.b), P = p, W = tr.w})
	end
	run.mapMsg = {Kind = "Map", Seed = run.seed, O = map.O, Nodes = nodes, Trails = trails, Icon = map.theme.Icon, Name = map.theme.Name}
	return run.mapMsg
end

---------------------------------------------------------------- 🐾 sniff / 🏠 way home / bonks
local lastSniff, lastHome, lastBonk = {}, {}, {}
local function buddyPart(player)
	local prof = API.profiles[player]
	local rec = prof and prof.FollowId and API.findRec and API.findRec(prof, prof.FollowId)
	local c = rec and API.critterFor and API.critterFor(rec)
	local m = c and c.model
	return m and m.Parent and (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)) or nil
end
event.OnServerEvent:Connect(function(player, msg)
	if type(msg) ~= "table" then return end
	local run = R.runOf[player]
	local map = run and run.map
	if not map or not map.folder.Parent then return end
	local h = hrpOf(player)
	if msg.Kind == "Map" then
		event:FireClient(player, mapMsg(run, map))
	elseif msg.Kind == "Sniff" and h then
		local left = (D.SniffCd or 20) - (os.clock() - (lastSniff[player] or -999))
		if left > 0 then API.toast(player, ("🐾 Your buddy's nose needs a rest: %ds"):format(math.ceil(left))) return end
		local from = nearestCell(map, h.Position)
		local dist = bfs(map, from)
		local best, bs = nil, math.huge
		for _, ch in run.chests or {} do
			if ch.box.Parent and not ch.seen[player.UserId] then
				local c = nearestCell(map, ch.box.Position)
				local score = (dist[c] or 99) * 1000 + (ch.box.Position - h.Position).Magnitude
				if score < bs then best, bs = ch, score end
			end
		end
		if not best then API.toast(player, "🐾 Sniff sniff... no more chests here! You found them all.") return end
		lastSniff[player] = os.clock()
		local pts = wayPoints(map, from, nearestCell(map, best.box.Position)) or {}
		table.insert(pts, 1, h.Position - Vector3.new(0, 3, 0))
		table.insert(pts, best.box.Position)
		event:FireClient(player, {Kind = "Paws", Pts = pts})
		local bp = buddyPart(player)
		if bp then API.pop(bp, "👃") end
		API.toast(player, bp and "🐾 Your buddy sniffed something! Follow the paw prints." or "🐾 Sniff sniff! Follow the paw prints.")
	elseif msg.Kind == "Home" and h then
		if os.clock() - (lastHome[player] or -999) < 4 then return end
		lastHome[player] = os.clock()
		local pts = wayPoints(map, nearestCell(map, h.Position), map.start) or {}
		table.insert(pts, 1, h.Position - Vector3.new(0, 3, 0))
		event:FireClient(player, {Kind = "Trail", Pts = pts})
		API.toast(player, "🏠 Follow the glowing trail back to the start!")
	elseif msg.Kind == "Bonk" and h then
		if os.clock() - (lastBonk[player] or 0) < 1 then return end
		lastBonk[player] = os.clock()
		API.pop(h, (TRAP_LOOK[map.land] or TRAP_LOOK.Meadow).Icon)
	end
end)
Players.PlayerRemoving:Connect(function(p) lastSniff[p], lastHome[p], lastBonk[p] = nil, nil, nil end)

---------------------------------------------------------------- called by Dungeons at the end of build
API.dungeonExtras = function(run)
	local map = run.map
	if not map then return end
	for _, step in {addPuzzles, addSecrets, addTraps, addHelpers} do
		local ok, err = pcall(step, run, map)
		if not ok then warn("[DungeonExtras] " .. tostring(err)) end
		task.wait()
	end
	-- anyone already inside gets the map (the rest ask for it when they arrive)
	for p in run.inside do event:FireClient(p, mapMsg(run, map)) end
end

print("[DungeonExtras] ready")
