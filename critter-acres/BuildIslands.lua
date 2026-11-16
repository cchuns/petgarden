-- Critter Acres: one-time builder (Studio Edit mode). Moves the 6 farms onto floating sky islands far from town
-- and builds 🌀 portals (one per island, one in town, one in the Meadow, one in each biome).
-- Run with: loadstring(HttpService:GetAsync(".../BuildIslands.lua"))()(stepName)   steps: "islands", "portals", "baseplate"
local root = workspace:WaitForChild("CritterAcres")
local RADIUS = 2500 -- islands sit on a ring this far from town (so you only see your own)

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end
local VERT = CFrame.Angles(0, 0, math.pi / 2) -- cylinders stand up

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- a 🌀 portal arch facing `look` (the side you walk in from)
local function portal(parent, name, pos, look, where, subText)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Portal", where)
	local cf = CFrame.lookAt(pos, pos + look)
	local stone, trim = Color3.fromRGB(150, 140, 175), Color3.fromRGB(255, 215, 120)
	part(m, {Name = "Base", Size = Vector3.new(18, 1, 7), CFrame = cf * CFrame.new(0, 0.5, 0), Color = stone, Material = Enum.Material.Slate})
	for _, x in {-7.5, 7.5} do
		part(m, {Name = "Pillar", Size = Vector3.new(2.6, 16, 2.6), CFrame = cf * CFrame.new(x, 9, 0), Color = stone, Material = Enum.Material.Slate})
		part(m, {Name = "Cap", Size = Vector3.new(3.4, 1, 3.4), CFrame = cf * CFrame.new(x, 17.4, 0), Color = trim, Material = Enum.Material.SmoothPlastic})
	end
	part(m, {Name = "Top", Size = Vector3.new(19, 2.4, 3), CFrame = cf * CFrame.new(0, 18.6, 0), Color = stone, Material = Enum.Material.Slate})
	local disc = part(m, {Name = "Swirl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 13, 13), CFrame = cf * CFrame.new(0, 8.6, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Color3.fromRGB(150, 110, 255), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, CanQuery = false})
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(220, 200, 255), Color3.fromRGB(140, 220, 255))
	pe.Size = NumberSequence.new(0.9, 0)
	pe.Lifetime = NumberRange.new(1, 1.6)
	pe.Rate = 18
	pe.Speed = NumberRange.new(1, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.LightEmission = 1
	pe.Parent = disc
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(170, 130, 255), 22, 1.6
	light.Parent = disc
	local gate = part(m, {Name = "Gate", Size = Vector3.new(12, 14, 4), CFrame = cf * CFrame.new(0, 8, 0), Transparency = 1, CanCollide = false, CanQuery = false})
	gate:SetAttribute("Portal", where)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 74)
	bb.StudsOffset = Vector3.new(0, 4.5, 0)
	bb.MaxDistance = 220
	bb.Parent = m:FindFirstChild("Top")
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(120, 90, 210)
	t.BackgroundTransparency = 0.1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4
	t.Text = "🌀 Portal\n" .. subText
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 16)
	t.Parent = bb
	m.PrimaryPart = m:FindFirstChild("Base")
	m.Parent = parent
	return m
end

local function groundAt(x, z, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	return hit and hit.Position.Y or 2.5
end

local STEPS = {}

-- 🏝️ move each farm out onto its own island
function STEPS.islands()
	local farms = root.Farms:GetChildren()
	table.sort(farms, function(a, b) return a.Name < b.Name end)
	local folder = root:FindFirstChild("Islands") or Instance.new("Folder")
	folder.Name = "Islands"
	folder.Parent = root
	folder:ClearAllChildren()
	local out = {}
	for i, farm in farms do
		local ground = farm:FindFirstChild("Ground")
		if ground then
			local a = (i - 1) * math.pi * 2 / #farms + math.pi / 6
			local target = Vector3.new(math.cos(a) * RADIUS, 0, math.sin(a) * RADIUS)
			local c = ground.Position
			farm:PivotTo(farm:GetPivot() + Vector3.new(target.X - c.X, 0, target.Z - c.Z))
			c = ground.Position
			-- island grass sits a hair under the farm ground (so walking on and off it has no step)
			local top = c.Y + ground.Size.Y / 2 - 0.1
			local m = Instance.new("Model")
			m.Name = "Island_" .. farm.Name
			m:SetAttribute("Farm", farm.Name)
			local grass, dirt, rock = Color3.fromRGB(110, 190, 85), Color3.fromRGB(140, 100, 65), Color3.fromRGB(120, 112, 105)
			part(m, {Name = "Top", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 190, 190), CFrame = CFrame.new(c.X, top - 3, c.Z) * VERT, Color = grass,
				Material = Enum.Material.Grass})
			part(m, {Name = "Dirt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 182, 182), CFrame = CFrame.new(c.X, top - 11, c.Z) * VERT, Color = dirt,
				Material = Enum.Material.Ground})
			local rocks = {{160, 18, -24}, {125, 20, -42}, {85, 22, -62}, {45, 22, -82}, {16, 16, -98}}
			for k, r in rocks do
				part(m, {Name = "Rock" .. k, Shape = Enum.PartType.Cylinder, Size = Vector3.new(r[2], r[1], r[1]), CFrame = CFrame.new(c.X + k % 2 * 3, top + r[3], c.Z - k % 3 * 2) * VERT,
					Color = rock:Lerp(Color3.new(0, 0, 0), k * 0.04), Material = Enum.Material.Slate, CanCollide = false})
			end
			local rng = Random.new(i * 77)
			for k = 1, 10 do -- little floating rocks and cloud puffs around the edge
				local aa = k / 10 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
				local d = rng:NextNumber(105, 140)
				if k % 2 == 0 then
					part(m, {Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(24, 40), Position = Vector3.new(c.X + math.cos(aa) * d, top - rng:NextNumber(18, 40), c.Z + math.sin(aa) * d),
						Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, Transparency = 0.15, CanCollide = false, CanQuery = false})
				else
					part(m, {Name = "Pebble", Size = Vector3.one * rng:NextNumber(4, 9), CFrame = CFrame.new(c.X + math.cos(aa) * d, top - rng:NextNumber(5, 30), c.Z + math.sin(aa) * d)
						* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Color = rock, Material = Enum.Material.Slate, CanCollide = false})
				end
			end
			-- invisible edge walls so nobody falls off
			for k = 1, 36 do
				local aa = k / 36 * math.pi * 2
				local p = Vector3.new(c.X + math.cos(aa) * 93, top + 7, c.Z + math.sin(aa) * 93)
				part(m, {Name = "Edge", Size = Vector3.new(17, 14, 2), CFrame = CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), Transparency = 1, CanQuery = false})
			end
			m.Parent = folder
			table.insert(out, ("%s -> %d,%d top %.2f"):format(farm.Name, c.X, c.Z, top))
		end
	end
	return table.concat(out, "\n")
end

-- 🌀 portals: one per island (outside the farm gate), town, meadow and each biome
function STEPS.portals()
	local folder = root:FindFirstChild("Portals") or Instance.new("Folder")
	folder.Name = "Portals"
	folder.Parent = root
	folder:ClearAllChildren()
	local out = {}
	for _, farm in root.Farms:GetChildren() do
		local ground = farm:FindFirstChild("Ground")
		local posts = {}
		for _, ch in farm:GetChildren() do if ch.Name == "GatePost" then table.insert(posts, ch.Position) end end
		if ground and #posts > 0 then
			local mid = Vector3.zero
			for _, p in posts do mid += p end
			mid /= #posts
			local dir = flat(mid - ground.Position).Unit
			local top = ground.Position.Y + ground.Size.Y / 2 - 0.1
			local pos = Vector3.new(ground.Position.X, top, ground.Position.Z) + dir * 66
			portal(folder, "Portal_" .. farm.Name, pos, -dir, "Island", "Town · Wild · Friends")
			table.insert(out, farm.Name .. " portal")
		end
	end
	local ignore = {folder}
	local function at(name, x, z, faceX, faceZ, where, sub)
		local y = groundAt(x, z, ignore)
		local look = flat(Vector3.new(faceX - x, 0, faceZ - z)).Unit
		portal(folder, name, Vector3.new(x, y, z), look, where, sub)
		table.insert(out, ("%s at %d,%.1f,%d"):format(name, x, y, z))
	end
	at("Portal_Town", 3, 74, 3, 0, "Town", "Home · Wild · Friends")
	at("Portal_Meadow", 34, -52, 4, -20, "Wild", "Home · Town · Friends")
	at("Portal_Forest", -300, 0, -200, 0, "Wild", "Home · Town · Friends")
	at("Portal_Peaks", 310, 0, 200, 0, "Wild", "Home · Town · Friends")
	at("Portal_Caves", -230, -270, -170, -200, "Wild", "Home · Town · Friends")
	at("Portal_Volcano", 230, -270, 170, -200, "Wild", "Home · Town · Friends")
	return table.concat(out, "\n")
end

-- the big grass baseplate only needs to cover town and the wild now
function STEPS.baseplate()
	local b = workspace:FindFirstChild("Baseplate")
	if not b then return "no baseplate" end
	b.Size = Vector3.new(1150, b.Size.Y, 1150)
	b.Position = Vector3.new(0, b.Position.Y, -180)
	return "baseplate " .. tostring(b.Size)
end

return function(step) return STEPS[step]() end
