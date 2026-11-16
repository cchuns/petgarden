-- Critter Acres: BuildTerrainPortal (Studio Edit mode, one-time builder)
-- The wild terrains are no longer joined to town. They are made fresh every trip by ServerScriptService.Realms.
-- Steps (run in order):  props, clear, portal, acorns, border
--   props  : generated terrain props (snowy pine, crystals, glow shrooms, lava rock, dead tree, giant shroom, portal arch)
--            + one template of each gather node -> ServerStorage.RealmProps
--   clear  : the old biomes, their paths, portals, portal nooks and chips -> ServerStorage.OldTerrains (backup, nothing deleted).
--            The Meadow ground shrinks to a small "NorthGreen" north of the park (raid gate, fishing pond, Terrain Portal).
--   portal : CritterAcres.TerrainPortal (arch, pad, Gate = walk-in trigger, Out = arrival spot)
--   acorns : the 30 golden acorns (were in the old biomes) are re-hidden by trees, rocks and planters around town
--   border : grass baseplate + a tree belt around town so the old biome land doesn't show
-- Use: local B = require(ServerStorage.BuildTerrainPortal) ; B("props") ...
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local root = workspace:WaitForChild("CritterAcres")
local CX, CZ = 4, 13 -- park centre
local GREEN = {x1 = -62, x2 = 70, z1 = -98, z2 = -26}
local PORTAL_AT = Vector3.new(4, 0, -72)
local REMOVED = {Portal_Meadow = 18, Portal_Forest = 34, Portal_Peaks = 34, Portal_Caves = 34, Portal_Volcano = 34}

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end
local function posOf(x)
	if x:IsA("BasePart") then return x.Position end
	if x:IsA("Model") then return x:GetPivot().Position end
	return nil
end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local steps = {}

function steps.props()
	local RP = folder(ServerStorage, "RealmProps")
	local NAMES = {
		["a cute stylized snow-covered pine"] = "SnowPine", ["a cluster of glowing purple"] = "CaveCrystal", ["a group of three giant glowing cave"] = "GlowShroom",
		["a dark volcanic basalt"] = "LavaRock", ["a stylized charred dead tree"] = "DeadTree", ["a giant cute forest mushroom"] = "GiantShroom",
		["a cluster of pale blue ice"] = "IceCrystal", ["a magical stone portal"] = "PortalArchBig",
	}
	local out = {}
	for _, m in workspace:GetChildren() do
		if m:IsA("Model") and CollectionService:HasTag(m, "AssistantAIGeneratedAsset") then
			for prefix, name in NAMES do
				if m.Name:sub(1, #prefix) == prefix then
					local old = RP:FindFirstChild(name)
					if old then old:Destroy() end
					local main = m:FindFirstChildWhichIsA("BasePart", true)
					m.PrimaryPart = main
					for _, d in m:GetDescendants() do
						if d:IsA("BasePart") then d.Anchored = true end
					end
					local cf, size = m:GetBoundingBox()
					m.WorldPivot = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z) -- pivot = bottom centre
					m:PivotTo(CFrame.new(0, 0, 0))
					m.Name = name
					m.Parent = RP
					table.insert(out, ("%s %.1fx%.1fx%.1f"):format(name, size.X, size.Y, size.Z))
				end
			end
		end
	end
	-- gather node templates (one of each kind)
	local NF = folder(RP, "Nodes")
	for _, bn in {"Biome_MeadowExtras", "Biome_Forest", "Biome_Peaks", "Biome_Caves", "Biome_Volcano"} do
		local b = root:FindFirstChild(bn) or (ServerStorage:FindFirstChild("OldTerrains") and ServerStorage.OldTerrains:FindFirstChild(bn))
		local nodes = b and b:FindFirstChild("Nodes")
		for _, n in nodes and nodes:GetChildren() or {} do
			local key = n:GetAttribute("Node")
			if key and not NF:FindFirstChild(key) then
				local c = n:Clone()
				c.Name = key
				c:PivotTo(CFrame.new(0, c:GetPivot().Position.Y - n:GetPivot().Position.Y, 0) * n:GetPivot().Rotation)
				c.Parent = NF
				table.insert(out, "node " .. key)
			end
		end
	end
	return table.concat(out, ", ")
end

function steps.clear()
	local BK = folder(ServerStorage, "OldTerrains")
	local out = {}
	local moved = 0
	local function stash(x, sub)
		x.Parent = sub and folder(BK, sub) or BK
		moved += 1
	end
	for _, n in {"Biome_Forest", "Biome_Peaks", "Biome_Caves", "Biome_Volcano", "Biome_MeadowExtras"} do
		local f = root:FindFirstChild(n)
		if f then stash(f) end
	end
	local paths = root:FindFirstChild("Paths")
	for _, p in paths and paths:GetChildren() or {} do
		if p:IsA("BasePart") and math.abs(p.Position.X) > 90 then stash(p, "Paths") end -- the long roads out to the biomes
	end
	-- portals that went to the biomes, plus their hedge nooks, planters, lamps and chips
	local gone = {}
	for name, r in REMOVED do
		local p = root.Portals:FindFirstChild(name)
		if p then
			table.insert(gone, {flat(p:GetPivot().Position), r})
			stash(p, "Portals")
		end
	end
	local function nearGone(pos)
		if not pos then return false end
		for _, g in gone do
			if (flat(pos) - g[1]).Magnitude < g[2] then return true end
		end
		return false
	end
	local dressing = root:FindFirstChild("TownDressing")
	for _, sub in dressing and dressing:GetChildren() or {} do
		for _, item in sub:GetChildren() do
			if nearGone(posOf(item)) then stash(item, "Dressing_" .. sub.Name) end
		end
	end
	for _, chip in root.TownChips:GetChildren() do
		local p = posOf(chip)
		if p and (nearGone(p) or (math.abs(math.abs(p.X) - 150) < 3 and math.abs(p.Z - 13) < 3)) then
			stash(chip, "Chips")
		elseif p and math.abs(p.X - CX) < 3 and math.abs(p.Z + 33) < 3 then -- the hedge arch north of the park now leads to the portal
			for _, t in chip:GetDescendants() do
				if t:IsA("TextLabel") then
					if t.Text:find("Meadow") then t.Text = "Terrain Portal" end
					if t.Text == "🧭" then t.Text = "🌀" end
				end
			end
		end
	end
	-- the meadow shrinks to a small green north of the park
	local m = root:FindFirstChild("Meadow")
	if m then
		local top = m.Position.Y + m.Size.Y / 2
		m.Size = Vector3.new(GREEN.x2 - GREEN.x1, m.Size.Y, GREEN.z2 - GREEN.z1)
		m.Position = Vector3.new((GREEN.x1 + GREEN.x2) / 2, top - m.Size.Y / 2, (GREEN.z1 + GREEN.z2) / 2)
		m.Name = "NorthGreen"
		table.insert(out, "Meadow -> NorthGreen")
	end
	local decor = root:FindFirstChild("Decor")
	for _, d in decor and decor:GetChildren() or {} do
		local p = posOf(d)
		if p and p.Z < -30 and (p.Z < GREEN.z1 or p.X < GREEN.x1 or p.X > GREEN.x2) then stash(d, "Decor") end
	end
	table.insert(out, ("moved %d things to ServerStorage.OldTerrains"):format(moved))
	return table.concat(out, ", ")
end

function steps.portal()
	local old = root:FindFirstChild("TerrainPortal")
	if old then old:Destroy() end
	local green = root:FindFirstChild("NorthGreen")
	local gy = green and (green.Position.Y + green.Size.Y / 2) or 2.84
	local at = Vector3.new(PORTAL_AT.X, gy, PORTAL_AT.Z)
	local cf = CFrame.lookAt(at, at + Vector3.new(0, 0, 1)) -- faces the park (south, +Z)
	local m = Instance.new("Model")
	m.Name = "TerrainPortal"
	local function P(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		for k, v in props do p[k] = v end
		p.Parent = m
		return p
	end
	local stone, trim = Color3.fromRGB(170, 160, 190), Color3.fromRGB(255, 215, 120)
	local pad = P({Name = "Pad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 30, 30), CFrame = cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = stone, Material = Enum.Material.Slate})
	P({Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 24, 24), CFrame = cf * CFrame.new(0, 0.52, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(150, 110, 255), Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false})
	P({Name = "PadTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 22, 22), CFrame = cf * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = stone:Lerp(Color3.new(1, 1, 1), 0.2), Material = Enum.Material.Slate})
	-- the arch (generated) or a part arch if it's missing
	local RP = ServerStorage:FindFirstChild("RealmProps")
	local arch = RP and RP:FindFirstChild("PortalArchBig")
	if arch then
		local a = arch:Clone()
		a.Name = "Arch"
		local _, size = a:GetBoundingBox()
		a:ScaleTo(a:GetScale() * (26 / size.Y))
		a:PivotTo(cf * CFrame.new(0, 1.1, 0))
		a.Parent = m
	else
		for _, x in {-9, 9} do P({Name = "Pillar", Size = Vector3.new(3, 20, 3), CFrame = cf * CFrame.new(x, 11, 0), Color = stone, Material = Enum.Material.Slate}) end
		P({Name = "Top", Size = Vector3.new(22, 3, 3.4), CFrame = cf * CFrame.new(0, 22, 0), Color = stone, Material = Enum.Material.Slate})
	end
	local swirl = P({Name = "Swirl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 13, 13), CFrame = cf * CFrame.new(0, 11, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Color3.fromRGB(170, 130, 255), Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = false})
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 220, 110)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(190, 120, 230)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(130, 200, 255)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(160, 120, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 130, 70))})
	pe.Size = NumberSequence.new(1, 0)
	pe.Lifetime = NumberRange.new(1.2, 2)
	pe.Rate = 30
	pe.Speed = NumberRange.new(1, 4)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.LightEmission = 1
	pe.Parent = swirl
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(170, 130, 255), 30, 2
	light.Parent = swirl
	-- five land stones around the pad (Meadow, Forest, Peaks, Caves, Volcano)
	local lands = {{"🌼", Color3.fromRGB(150, 220, 110)}, {"🍄", Color3.fromRGB(170, 100, 210)}, {"❄️", Color3.fromRGB(130, 200, 255)},
		{"💎", Color3.fromRGB(150, 110, 255)}, {"🌋", Color3.fromRGB(255, 110, 60)}}
	for i, l in lands do
		local ang = math.rad(-150 + (i - 1) * 75) -- a half ring behind and beside the arch
		local pcf = cf * CFrame.new(math.sin(ang) * 13, 0, -math.cos(ang) * 13)
		local post = P({Name = "LandStone", Size = Vector3.new(2.2, 4, 2.2), CFrame = pcf * CFrame.new(0, 3, 0), Color = stone, Material = Enum.Material.Slate})
		local gem = P({Name = "LandGem", Size = Vector3.new(1.6, 1.6, 1.6), CFrame = pcf * CFrame.new(0, 6, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Color = l[2], Material = Enum.Material.Neon, CanCollide = false})
		local gl = Instance.new("PointLight")
		gl.Color, gl.Range, gl.Brightness = l[2], 10, 1
		gl.Parent = gem
	end
	local gate = P({Name = "Gate", Size = Vector3.new(12, 16, 5), CFrame = cf * CFrame.new(0, 9, 0), Transparency = 1, CanCollide = false, CanQuery = false})
	gate:SetAttribute("TerrainPortal", true)
	P({Name = "Out", Size = Vector3.new(4, 1, 4), CFrame = cf * CFrame.new(0, 0.6, 16), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
	-- sign: a town chip (minimal white icon that opens to show the name, drawn by CritterWorld)
	local chips = root:WaitForChild("TownChips")
	for _, c in chips:GetChildren() do
		if c:GetAttribute("Label") == "Terrain Portal" then c:Destroy() end
		if c:GetAttribute("Label") == "To the Meadow" then c:SetAttribute("Label", "To the Terrain Portal") end -- the north arch
	end
	local ch = Instance.new("Part")
	ch.Name = "Chip"
	ch.Anchored, ch.CanCollide, ch.CanQuery, ch.CanTouch, ch.Transparency = true, false, false, false, 1
	ch.Size = Vector3.one * 0.5
	ch.Position = at + Vector3.new(0, 30, 0)
	ch:SetAttribute("Icon", "🌀")
	ch:SetAttribute("Label", "Terrain Portal")
	ch.Parent = chips
	m.PrimaryPart = pad
	m.Parent = root
	-- a stone path from the hedge arch to the pad
	local path = root:FindFirstChild("Path")
	if path then
		local old2 = root:FindFirstChild("PortalPath")
		if old2 then old2:Destroy() end
		local z1, z2 = path.Position.Z - path.Size.Z / 2, at.Z + 15
		local p = path:Clone()
		p.Name = "PortalPath"
		p.Size = Vector3.new(path.Size.X, path.Size.Y, math.abs(z1 - z2))
		p.Position = Vector3.new(path.Position.X, path.Position.Y, (z1 + z2) / 2)
		p.Parent = root
	end
	return "Terrain Portal at " .. tostring(at)
end

function steps.acorns()
	local acorns = root:FindFirstChild("Acorns")
	if not acorns then return "no acorns" end
	-- hiding spots: trees, rocks, bushes, planters, lamps around town and the green
	local spots = {}
	local OK = {Pine = 1, Birch = 1, Maple = 1, TreeRound = 1, TreeBlossom = 1, Cypress = 1, Willow = 1, FruitTree = 1, MossyRock = 1, Rocks = 1, Bush = 1,
		FlowerBush = 1, Planter = 1, Bamboo = 1, Fern = 1, Topiary = 1, PottedPlant = 1, Crates = 1, Wheelbarrow = 1}
	for _, d in root.TownDressing:GetDescendants() do
		if d:IsA("Model") and OK[d.Name] then
			local cf, size = d:GetBoundingBox()
			local p = cf.Position
			local fromPark = (flat(p) - Vector3.new(CX, 0, CZ)).Magnitude
			local onGreen = p.X > GREEN.x1 and p.X < GREEN.x2 and p.Z > GREEN.z1 and p.Z < GREEN.z2
			if fromPark < 230 or onGreen then
				table.insert(spots, {pos = p, bottom = p.Y - size.Y / 2, r = math.max(size.X, size.Z) / 2})
			end
		end
	end
	local rng = Random.new(3030)
	for i = #spots, 2, -1 do
		local j = rng:NextInteger(1, i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	local picked = {}
	local list = acorns:GetChildren()
	table.sort(list, function(a, b) return (a:GetAttribute("Id") or 0) < (b:GetAttribute("Id") or 0) end)
	local minGap = 26
	while #picked < #list and minGap > 4 do
		for _, s in spots do
			if #picked >= #list then break end
			local far = true
			for _, q in picked do
				if (flat(q.pos) - flat(s.pos)).Magnitude < minGap then far = false break end
			end
			if far and not table.find(picked, s) then table.insert(picked, s) end
		end
		minGap -= 6
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {acorns}
	for i, a in list do
		local s = picked[i]
		if s then
			local ang = rng:NextNumber(0, math.pi * 2)
			local r = math.max(1.6, math.min(s.r * 0.75, 4))
			local x, z = s.pos.X + math.cos(ang) * r, s.pos.Z + math.sin(ang) * r
			local hit = workspace:Raycast(Vector3.new(x, s.bottom + 3, z), Vector3.new(0, -12, 0), params)
			local y = hit and hit.Position.Y or s.bottom
			local cf, size = a:GetBoundingBox()
			local off = a:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
			a:PivotTo(CFrame.new(x, y + off, z) * a:GetPivot().Rotation)
		end
	end
	return ("%d acorns re-hidden (%d spots)"):format(math.min(#list, #picked), #spots)
end

function steps.border()
	local bp = workspace:FindFirstChild("Baseplate")
	if bp then
		bp.Material = Enum.Material.Grass
		bp.Color = Color3.fromRGB(118, 176, 84)
	end
	local PROPS = ServerStorage:WaitForChild("IslandProps")
	local B = root.TownDressing:FindFirstChild("Border")
	if B then B:Destroy() end
	B = Instance.new("Folder")
	B.Name = "Border"
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {root:FindFirstChild("Acorns"), workspace:FindFirstChild("MobPreview")}
	local STEP = 12
	local x1, x2, z1, z2 = -330, 330, -230, 380
	local grid = {}
	for x = x1, x2, STEP do
		grid[x] = {}
		for z = z1, z2, STEP do
			local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -260, 0), params)
			grid[x][z] = hit and (hit.Instance == bp and "bare" or "built") or "none"
		end
	end
	local rng = Random.new(777)
	local kinds = {"Pine", "Pine", "Maple", "Birch", "TreeRound", "Cypress"}
	local n = 0
	for x = x1, x2, STEP do
		for z = z1, z2, STEP do
			if grid[x][z] == "bare" then
				local near = false
				for dx = -3, 3 do
					for dz = -3, 3 do
						local c = grid[x + dx * STEP] and grid[x + dx * STEP][z + dz * STEP]
						if c == "built" then near = true end
					end
				end
				local fromPark = (Vector3.new(x, 0, z) - Vector3.new(CX, 0, CZ)).Magnitude
				if near and fromPark > 60 and rng:NextNumber() < 0.8 then
					local t = PROPS:FindFirstChild(kinds[rng:NextInteger(1, #kinds)])
					if t then
						local mm = t:Clone()
						local s = rng:NextNumber(1.1, 1.7)
						mm:ScaleTo(mm:GetScale() * s)
						local cf, size = mm:GetBoundingBox()
						local off = mm:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
						mm:PivotTo(CFrame.new(x + rng:NextNumber(-4, 4), bp.Position.Y + bp.Size.Y / 2 + off - 0.3, z + rng:NextNumber(-4, 4)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
						mm.Parent = B
						n += 1
					end
				end
			end
		end
	end
	B.Parent = root.TownDressing
	return ("border: %d trees"):format(n)
end

return function(step)
	return steps[step]()
end
