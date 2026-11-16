-- Critter Acres: one-time world builder (run in Studio Edit mode with execute_luau, in parts).
-- Builds: Town Plaza openings, 6 personal farms, 4 new biomes (Forest, Peaks, Caves, Volcano) and paths.
-- Run with: loadstring(HttpService:GetAsync(".../BuildWorld.lua"))()(stepName)
-- Steps: "plaza", "farms", "Forest", "Peaks", "Caves", "Volcano", "paths"
local root = workspace:WaitForChild("CritterAcres")
local rng = Random.new(2026)

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end
local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if f then f:Destroy() end
	f = Instance.new(parent == root and "Folder" or "Model")
	f.Name = name
	f.Parent = parent
	return f
end
local function sign(parent, at, icon, text, color)
	local post = part(parent, {Name = "Sign", Size = Vector3.new(1, 10, 1), Position = at + Vector3.new(0, 5, 0), Color = Color3.fromRGB(120, 85, 55),
		Material = Enum.Material.Wood})
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 90)
	bb.StudsOffset = Vector3.new(0, 7.5, 0)
	bb.MaxDistance = 260
	bb.Parent = post
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = color
	t.BackgroundTransparency = 0.1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Text = icon .. " " .. text
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 16)
	t.Parent = bb
	return post
end
local UP = CFrame.Angles(0, 0, math.pi / 2)

local STEPS = {}

---------------------------------------------------------------- plaza: open the fence on 3 sides, back up the old shared plots
function STEPS.plaza()
	local fence = root:FindFirstChild("Fence")
	if fence then
		for _, p in fence:GetDescendants() do
			if p:IsA("BasePart") then
				local x, z = p.Position.X, p.Position.Z
				if (math.abs(x) > 33 and math.abs(z) < 7) or (z > 33 and math.abs(x) < 7) then p:Destroy() end
			end
		end
	end
	local old = root:FindFirstChild("Plots")
	if old then
		old.Name = "SharedPlotsBackup"
		old.Parent = game:GetService("ServerStorage")
	end
	-- likes leaderboard
	local board = folder(root, "LikeBoard")
	local b = part(board, {Name = "Board", Size = Vector3.new(12, 8, 1), Position = Vector3.new(-12, 5, -28), Color = Color3.fromRGB(255, 120, 160),
		Material = Enum.Material.SmoothPlastic})
	b.CFrame = CFrame.lookAt(b.Position, Vector3.new(0, 5, 10))
	for _, x in {-5, 5} do
		part(board, {Size = Vector3.new(0.8, 9, 0.8), CFrame = b.CFrame * CFrame.new(x, -1, 0.6), Color = Color3.fromRGB(120, 85, 55)})
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Gui"
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(600, 400)
	sg.Parent = b
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.FredokaOne
	list.TextScaled = true
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextStrokeTransparency = 0.4
	list.Text = "❤️"
	list.Parent = sg
	-- fusion cauldron
	local cauldron = folder(root, "Cauldron")
	local pot = part(cauldron, {Name = "Pot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 7, 7), CFrame = CFrame.new(12, 2.5, -28) * UP,
		Color = Color3.fromRGB(60, 50, 80), Material = Enum.Material.Metal})
	part(cauldron, {Name = "Brew", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 6, 6), CFrame = CFrame.new(12, 4.4, -28) * UP,
		Color = Color3.fromRGB(150, 255, 120), Material = Enum.Material.Neon})
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		part(cauldron, {Size = Vector3.new(0.8, 2, 0.8), Position = Vector3.new(12 + math.cos(a) * 3, 0.8, -28 + math.sin(a) * 3), Color = Color3.fromRGB(40, 35, 55)})
	end
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(Color3.fromRGB(180, 255, 140), Color3.fromRGB(255, 140, 255))
	bubbles.LightEmission = 1
	bubbles.Size = NumberSequence.new(0.8, 0)
	bubbles.Rate = 12
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.EmissionDirection = Enum.NormalId.Right -- the pot is turned on its side: Right is up
	bubbles.Parent = pot
	sign(cauldron, Vector3.new(16.5, 0, -24), "🧪", "", Color3.fromRGB(150, 90, 220))
end

---------------------------------------------------------------- personal farms
local FARM_SPOTS = {Vector3.new(-92, 0, -40), Vector3.new(-92, 0, 40), Vector3.new(92, 0, -40), Vector3.new(92, 0, 40),
	Vector3.new(-40, 0, 100), Vector3.new(40, 0, 100)}
function STEPS.farms()
	local farms = folder(root, "Farms")
	local backup = game:GetService("ServerStorage"):FindFirstChild("SharedPlotsBackup")
	local plotTemplate = backup and backup:FindFirstChildWhichIsA("BasePart")
	for i, c in FARM_SPOTS do
		local m = Instance.new("Model")
		m.Name = "Farm" .. i
		m:SetAttribute("Slot", i)
		-- local frame: -Z faces the plaza center
		local face = CFrame.lookAt(c, Vector3.new(0, 0, 0) * Vector3.new(1, 0, 1) + Vector3.new(0, 0, 0.001))
		local base = CFrame.new(c) * face.Rotation
		local function at(x, y, z) return base * CFrame.new(x, y, z) end
		local ground = part(m, {Name = "Ground", Size = Vector3.new(50, 0.6, 50), CFrame = at(0, 0, 0), Color = Color3.fromRGB(120, 200, 95),
			Material = Enum.Material.Grass})
		m.PrimaryPart = ground
		-- plots 3x3 toward the back
		local plots = Instance.new("Folder")
		plots.Name = "Plots"
		plots.Parent = m
		local n = 0
		for row = 0, 2 do
			for col = -1, 1 do
				n += 1
				local p = plotTemplate and plotTemplate:Clone() or part(nil, {Size = Vector3.new(6, 0.8, 6), Color = Color3.fromRGB(150, 100, 62)})
				for _, ch in p:GetChildren() do ch:Destroy() end
				for k in p:GetAttributes() do p:SetAttribute(k, nil) end
				p.Name = "Plot" .. n
				p.CFrame = at(col * 9, 1.1, 2 + row * 9)
				p.Anchored = true
				p.Parent = plots
			end
		end
		-- fence with a gate gap at the front
		local wood = Color3.fromRGB(205, 160, 110)
		local function rail(x, z, len, alongX)
			part(m, {Name = "Fence", Size = alongX and Vector3.new(len, 2.6, 0.6) or Vector3.new(0.6, 2.6, len), CFrame = at(x, 1.6, z), Color = wood,
				Material = Enum.Material.WoodPlanks})
		end
		rail(0, 25, 50, true) -- back
		rail(-25, 0, 50, false)
		rail(25, 0, 50, false)
		rail(-15.5, -25, 19, true) -- front, left of the gate
		rail(15.5, -25, 19, true)
		for _, x in {-6, 6} do -- gate posts
			part(m, {Name = "GatePost", Size = Vector3.new(1.2, 6, 1.2), CFrame = at(x, 3, -25), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood})
		end
		part(m, {Name = "GateTop", Size = Vector3.new(13.4, 1.2, 1.4), CFrame = at(0, 6.4, -25), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood})
		-- owner sign over the gate
		local board = part(m, {Name = "OwnerSign", Size = Vector3.new(11, 3, 0.5), CFrame = at(0, 8.6, -25), Color = Color3.fromRGB(255, 240, 210)})
		local bb = Instance.new("BillboardGui")
		bb.Name = "Gui"
		bb.Size = UDim2.fromOffset(260, 90)
		bb.StudsOffset = Vector3.new(0, 1.5, 0)
		bb.MaxDistance = 220
		bb.Parent = board
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundColor3 = Color3.fromRGB(255, 200, 120)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(90, 60, 40)
		t.Text = "🏡 ❔"
		Instance.new("UICorner", t).CornerRadius = UDim.new(0, 16)
		t.Parent = bb
		-- like heart on a pedestal, outside left of the gate
		local heart = Instance.new("Model")
		heart.Name = "LikeHeart"
		local red = Color3.fromRGB(255, 70, 110)
		part(heart, {Size = Vector3.new(2, 2.5, 2), CFrame = at(-10, 1.25, -28.5), Color = Color3.fromRGB(240, 235, 225)})
		for _, x in {-0.7, 0.7} do
			part(heart, {Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = at(-10 + x, 5, -28.5), Color = red, Material = Enum.Material.SmoothPlastic})
		end
		local tip = part(heart, {Name = "Tip", Size = Vector3.new(2, 2, 1.6), CFrame = at(-10, 4.1, -28.5) * CFrame.Angles(0, 0, math.pi / 4), Color = red})
		heart.PrimaryPart = tip
		heart.Parent = m
		-- sell bin inside the gate
		local bin = part(m, {Name = "SellBin", Size = Vector3.new(4, 3, 3), CFrame = at(11, 1.8, -21), Color = Color3.fromRGB(170, 120, 70),
			Material = Enum.Material.WoodPlanks})
		part(m, {Size = Vector3.new(3.6, 0.6, 2.6), CFrame = at(11, 3.4, -21), Color = Color3.fromRGB(255, 200, 70)})
		local bbin = Instance.new("BillboardGui")
		bbin.Size = UDim2.fromOffset(60, 60)
		bbin.StudsOffset = Vector3.new(0, 3.5, 0)
		bbin.MaxDistance = 60
		bbin.Parent = bin
		local bt = Instance.new("TextLabel")
		bt.Size = UDim2.fromScale(1, 1)
		bt.BackgroundTransparency = 1
		bt.TextScaled = true
		bt.Text = "💰"
		bt.Parent = bbin
		-- where the owner appears
		part(m, {Name = "Home", Size = Vector3.new(4, 0.2, 4), CFrame = at(0, 0.4, -18), Transparency = 1, CanCollide = false, CanQuery = false})
		m.Parent = farms
	end
end

---------------------------------------------------------------- biomes
local BIOMES = {
	Forest = {Center = Vector3.new(-330, 0, -20), Size = Vector2.new(280, 320), Mult = 2.5, Color = Color3.fromRGB(80, 150, 70), Material = Enum.Material.Grass,
		Icon = "🍄", Label = "Mushroom Forest", SignColor = Color3.fromRGB(170, 90, 200)},
	Peaks = {Center = Vector3.new(330, 0, -20), Size = Vector2.new(280, 320), Mult = 2.5, Color = Color3.fromRGB(235, 245, 255), Material = Enum.Material.Snow,
		Icon = "❄️", Label = "Frosty Peaks", SignColor = Color3.fromRGB(90, 160, 230)},
	Caves = {Center = Vector3.new(-250, 0, -390), Size = Vector2.new(300, 260), Mult = 2.5, Color = Color3.fromRGB(70, 60, 95), Material = Enum.Material.Slate,
		Icon = "💎", Label = "Crystal Caves", SignColor = Color3.fromRGB(130, 90, 230)},
	Volcano = {Center = Vector3.new(250, 0, -390), Size = Vector2.new(300, 260), Mult = 2.5, Color = Color3.fromRGB(70, 55, 50), Material = Enum.Material.Basalt,
		Icon = "🌋", Label = "Lava Volcano", SignColor = Color3.fromRGB(230, 90, 50)},
}

local function scatter(b, count, clear, fn)
	count = math.floor(count * (b.Mult or 1)) -- bigger biomes get more of everything
	local placed = 0
	local tries = 0
	while placed < count and tries < count * 20 do
		tries += 1
		local x = b.Center.X + rng:NextNumber(-0.5, 0.5) * (b.Size.X - 10)
		local z = b.Center.Z + rng:NextNumber(-0.5, 0.5) * (b.Size.Y - 10)
		local d = Vector2.new(x - b.Center.X, z - b.Center.Z).Magnitude
		if d > (clear or 32) then -- keep a clearing in the middle (world boss arena)
			placed += 1
			fn(Vector3.new(x, 0, z), placed)
		end
	end
end

local DECOR = {}
function DECOR.Forest(m, b)
	scatter(b, 30, 34, function(p)
		local h = rng:NextNumber(10, 18)
		part(m, {Size = Vector3.new(2.2, h, 2.2), Position = p + Vector3.new(0, h / 2, 0), Color = Color3.fromRGB(110, 75, 50), Material = Enum.Material.Wood})
		for k = 0, 2 do
			part(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(7, 10), CanCollide = false,
				Position = p + Vector3.new(rng:NextNumber(-2, 2), h + k * 1.5, rng:NextNumber(-2, 2)),
				Color = Color3.fromRGB(60 + rng:NextInteger(0, 30), 140 + rng:NextInteger(0, 40), 60), Material = Enum.Material.Grass})
		end
	end)
	scatter(b, 22, 30, function(p, i) -- giant mushrooms
		local h = rng:NextNumber(3, 8)
		part(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.6, 1.6), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * UP,
			Color = Color3.fromRGB(250, 240, 220)})
		local capColor = i % 3 == 0 and Color3.fromRGB(150, 110, 255) or Color3.fromRGB(235, 70, 70)
		part(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, h * 0.9 + 2, h * 0.9 + 2), CFrame = CFrame.new(p + Vector3.new(0, h + 0.5, 0)) * UP,
			Color = capColor, Material = i % 3 == 0 and Enum.Material.Neon or Enum.Material.SmoothPlastic})
		for _ = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = (h * 0.9 + 2) * 0.3
			part(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7, CanCollide = false,
				Position = p + Vector3.new(math.cos(a) * r, h + 1.4, math.sin(a) * r), Color = Color3.new(1, 1, 1)})
		end
	end)
end
function DECOR.Peaks(m, b)
	scatter(b, 26, 34, function(p)
		local h = rng:NextNumber(10, 16)
		part(m, {Size = Vector3.new(1.6, 4, 1.6), Position = p + Vector3.new(0, 2, 0), Color = Color3.fromRGB(100, 70, 50)})
		for k = 0, 3 do
			local w = (1 - k / 4.5) * h * 0.55
			part(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 0.25, w, w), CFrame = CFrame.new(p + Vector3.new(0, 4 + k * h * 0.2, 0)) * UP,
				Color = k == 3 and Color3.fromRGB(245, 250, 255) or Color3.fromRGB(40, 110, 80), CanCollide = k == 0})
		end
	end)
	scatter(b, 14, 30, function(p) -- snowy boulders
		local s = rng:NextNumber(4, 9)
		part(m, {Size = Vector3.new(s, s * 0.7, s * 0.9), CFrame = CFrame.new(p + Vector3.new(0, s * 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.2),
			Color = Color3.fromRGB(150, 160, 175), Material = Enum.Material.Rock})
		part(m, {Size = Vector3.new(s * 0.9, 0.8, s * 0.8), Position = p + Vector3.new(0, s * 0.68, 0), Color = Color3.fromRGB(250, 252, 255),
			Material = Enum.Material.Snow, CanCollide = false})
	end)
	scatter(b, 12, 30, function(p) -- ice spikes
		for _ = 1, 3 do
			local h = rng:NextNumber(4, 9)
			part(m, {Size = Vector3.new(1.2, h, 1.2), CFrame = CFrame.new(p + Vector3.new(rng:NextNumber(-2, 2), h / 2, rng:NextNumber(-2, 2)))
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)), Color = Color3.fromRGB(160, 220, 255),
				Material = Enum.Material.Glass, Transparency = 0.2})
		end
	end)
	-- big mountains at the far edge (decor only)
	for k = -1, 1 do
		local p = b.Center + Vector3.new(b.Size.X * 0.42, 0, k * 50)
		for lvl = 0, 4 do
			local w = 50 - lvl * 10
			part(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(12, w, w), CFrame = CFrame.new(p + Vector3.new(0, 6 + lvl * 12, 0)) * UP,
				Color = lvl >= 3 and Color3.fromRGB(250, 252, 255) or Color3.fromRGB(140, 150, 170), Material = lvl >= 3 and Enum.Material.Snow or Enum.Material.Rock})
		end
	end
end
function DECOR.Caves(m, b)
	scatter(b, 26, 32, function(p, i) -- crystal clusters
		local color = ({Color3.fromRGB(170, 110, 255), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 120, 220)})[i % 3 + 1]
		for _ = 1, rng:NextInteger(3, 5) do
			local h = rng:NextNumber(3, 10)
			part(m, {Size = Vector3.new(1.4, h, 1.4), CFrame = CFrame.new(p + Vector3.new(rng:NextNumber(-2.5, 2.5), h / 2 - 0.5, rng:NextNumber(-2.5, 2.5)))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), Color = color, Material = Enum.Material.Neon})
		end
	end)
	scatter(b, 16, 30, function(p) -- dark rocks
		local s = rng:NextNumber(5, 11)
		part(m, {Size = Vector3.new(s, s * 0.8, s), CFrame = CFrame.new(p + Vector3.new(0, s * 0.35, 0)) * CFrame.Angles(0.2, rng:NextNumber(0, 3), 0.15),
			Color = Color3.fromRGB(55, 50, 70), Material = Enum.Material.Slate})
	end)
	-- cave walls around the back and sides, with arches
	for _, side in {{0, -0.5, true}, {-0.5, 0, false}, {0.5, 0, false}} do
		local len = side[3] and b.Size.X or b.Size.Y
		local p = b.Center + Vector3.new(side[1] * b.Size.X, 0, side[2] * b.Size.Y)
		part(m, {Size = side[3] and Vector3.new(len, 22, 6) or Vector3.new(6, 22, len), Position = p + Vector3.new(0, 11, 0), Color = Color3.fromRGB(60, 55, 75),
			Material = Enum.Material.Slate})
	end
end
function DECOR.Volcano(m, b)
	scatter(b, 7, 34, function(p) -- lava pools (just for looks, critters walk over them)
		local s = rng:NextNumber(8, 14)
		part(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, s, s), CFrame = CFrame.new(p + Vector3.new(0, 0.35, 0)) * UP,
			Color = Color3.fromRGB(255, 110, 30), Material = Enum.Material.Neon, CanCollide = false})
		part(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, s + 2, s + 2), CFrame = CFrame.new(p + Vector3.new(0, 0.25, 0)) * UP,
			Color = Color3.fromRGB(40, 30, 30), Material = Enum.Material.Basalt, CanCollide = false})
	end)
	scatter(b, 18, 30, function(p)
		local s = rng:NextNumber(4, 10)
		part(m, {Size = Vector3.new(s, s * 0.9, s * 0.8), CFrame = CFrame.new(p + Vector3.new(0, s * 0.4, 0)) * CFrame.Angles(0.25, rng:NextNumber(0, 3), 0.2),
			Color = Color3.fromRGB(45, 35, 35), Material = Enum.Material.Basalt})
	end)
	-- the volcano itself at the back, smoking
	local p = b.Center + Vector3.new(0, 0, -b.Size.Y * 0.42)
	local top
	for lvl = 0, 5 do
		local w = 70 - lvl * 11
		top = part(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, w, w), CFrame = CFrame.new(p + Vector3.new(0, 4.5 + lvl * 9, 0)) * UP,
			Color = Color3.fromRGB(70 - lvl * 5, 50, 45), Material = Enum.Material.Basalt})
	end
	local glow = part(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 12, 12), CFrame = CFrame.new(p + Vector3.new(0, 50, 0)) * UP,
		Color = Color3.fromRGB(255, 120, 30), Material = Enum.Material.Neon})
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(90, 80, 80)
	smoke.Size = 18
	smoke.RiseVelocity = 8
	smoke.Parent = glow
	local fire = Instance.new("Fire")
	fire.Size = 16
	fire.Heat = 20
	fire.Parent = glow
end

---------------------------------------------------------------- resource nodes (CraftServer makes them gatherable)
local function nodeModel(parent, kind, pos)
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Node", kind)
	local main
	local function rock(size, color, mat)
		return part(m, {Name = "Main", Size = size, CFrame = CFrame.new(pos + Vector3.new(0, size.Y * 0.45, 0)) * CFrame.Angles(0.15, rng:NextNumber(0, 6), 0.1),
			Color = color, Material = mat or Enum.Material.Rock})
	end
	local function bits(color, mat, n, spread, y)
		for _ = 1, n do
			part(m, {Size = Vector3.one * rng:NextNumber(0.6, 1.1), CanCollide = false,
				CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-spread, spread), y + rng:NextNumber(-0.5, 0.8), rng:NextNumber(-spread, spread)))
					* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Color = color, Material = mat or Enum.Material.Neon})
		end
	end
	if kind == "Bush" then
		main = part(m, {Name = "Main", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Position = pos + Vector3.new(0, 1.2, 0), Color = Color3.fromRGB(110, 190, 80),
			Material = Enum.Material.Grass})
		for i = 1, 3 do
			part(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CanCollide = false, Position = pos + Vector3.new(math.cos(i * 2) * 1.3, 1, math.sin(i * 2) * 1.3),
				Color = Color3.fromRGB(130, 210, 90), Material = Enum.Material.Grass})
		end
		bits(Color3.fromRGB(255, 240, 150), Enum.Material.SmoothPlastic, 3, 1.3, 2)
	elseif kind == "Pebble" then
		main = rock(Vector3.new(3.4, 2.4, 3), Color3.fromRGB(150, 150, 160))
	elseif kind == "Log" then
		main = part(m, {Name = "Main", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 2.2, 2.2), CFrame = CFrame.new(pos + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Color = Color3.fromRGB(130, 90, 55), Material = Enum.Material.Wood})
		for _, x in {-3.05, 3.05} do
			part(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.8, 1.8), CanCollide = false, CFrame = main.CFrame * CFrame.new(x, 0, 0),
				Color = Color3.fromRGB(220, 180, 120), Material = Enum.Material.Wood})
		end
	elseif kind == "Shroom" then
		part(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 0.7, 0.7), CFrame = CFrame.new(pos + Vector3.new(0, 0.8, 0)) * UP, Color = Color3.fromRGB(250, 240, 220)})
		main = part(m, {Name = "Main", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 2.4, 2.4), CFrame = CFrame.new(pos + Vector3.new(0, 1.8, 0)) * UP,
			Color = Color3.fromRGB(235, 70, 70)})
		for i = 1, 4 do part(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, CanCollide = false, Position = pos + Vector3.new(math.cos(i * 1.6) * 0.7, 2.25, math.sin(i * 1.6) * 0.7), Color = Color3.new(1, 1, 1)}) end
	elseif kind == "IceRock" then
		main = rock(Vector3.new(3, 3.6, 3), Color3.fromRGB(170, 225, 255), Enum.Material.Ice)
		bits(Color3.fromRGB(200, 240, 255), Enum.Material.Glass, 3, 1.2, 3)
	elseif kind == "IronOre" then
		main = rock(Vector3.new(3.6, 3, 3.4), Color3.fromRGB(110, 105, 115))
		bits(Color3.fromRGB(210, 210, 225), Enum.Material.Metal, 5, 1.4, 1.8)
	elseif kind == "GoldOre" then
		main = rock(Vector3.new(3.6, 3, 3.4), Color3.fromRGB(70, 60, 80), Enum.Material.Slate)
		bits(Color3.fromRGB(255, 205, 60), Enum.Material.Neon, 5, 1.4, 1.8)
	elseif kind == "GemRock" then
		main = rock(Vector3.new(2.6, 1.6, 2.6), Color3.fromRGB(60, 55, 75), Enum.Material.Slate)
		for _ = 1, 4 do
			part(m, {Size = Vector3.new(0.8, rng:NextNumber(2, 3.5), 0.8), CanCollide = false, CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-0.8, 0.8), 2, rng:NextNumber(-0.8, 0.8)))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)), Color = Color3.fromRGB(180, 110, 255), Material = Enum.Material.Neon})
		end
	elseif kind == "MagmaRock" then
		main = rock(Vector3.new(3.6, 3, 3.4), Color3.fromRGB(45, 35, 35), Enum.Material.Basalt)
		bits(Color3.fromRGB(255, 120, 40), Enum.Material.Neon, 5, 1.4, 1.6)
	elseif kind == "ObsidianRock" then
		main = rock(Vector3.new(2.4, 1.4, 2.4), Color3.fromRGB(35, 25, 45), Enum.Material.Glass)
		for _ = 1, 4 do
			part(m, {Size = Vector3.new(0.9, rng:NextNumber(2.5, 4), 0.9), CanCollide = false, CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-0.8, 0.8), 2.2, rng:NextNumber(-0.8, 0.8)))
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), Color = Color3.fromRGB(50, 30, 70), Material = Enum.Material.Glass, Reflectance = 0.3})
		end
	end
	m.PrimaryPart = main
	m.Parent = parent
	return m
end
local BIOME_NODES = {
	Meadow = {{"Bush", 14}, {"Pebble", 10}},
	Forest = {{"Log", 14}, {"Shroom", 12}},
	Peaks = {{"IceRock", 12}, {"IronOre", 10}},
	Caves = {{"GoldOre", 10}, {"GemRock", 10}},
	Volcano = {{"MagmaRock", 10}, {"ObsidianRock", 8}},
}
local function addNodes(m, b, name)
	local f = Instance.new("Folder")
	f.Name = "Nodes"
	f.Parent = m
	for _, n in BIOME_NODES[name] do
		local count = n[2]
		local placed = 0
		while placed < count do
			local x = b.Center.X + rng:NextNumber(-0.45, 0.45) * b.Size.X
			local z = b.Center.Z + rng:NextNumber(-0.45, 0.45) * b.Size.Y
			if Vector2.new(x - b.Center.X, z - b.Center.Z).Magnitude > 30 then
				placed += 1
				nodeModel(f, n[1], Vector3.new(x, 0.3, z))
			end
		end
	end
end

local function buildBiome(name)
	local b = BIOMES[name]
	local m = folder(root, "Biome_" .. name)
	m:SetAttribute("Biome", name)
	part(m, {Name = "Ground", Size = Vector3.new(b.Size.X, 0.6, b.Size.Y), Position = b.Center, Color = b.Color, Material = b.Material})
	DECOR[name](m, b)
	addNodes(m, b, name)
	-- entrance sign on the side facing the plaza
	local toPlaza = (Vector3.new(0, 0, 0) - b.Center) * Vector3.new(1, 0, 1)
	local edge = b.Center + toPlaza.Unit * (math.min(b.Size.X, b.Size.Y) / 2 - 4)
	sign(m, edge, b.Icon, b.Label, b.SignColor)
end
for name in BIOMES do STEPS[name] = function() buildBiome(name) end end

---------------------------------------------------------------- paths between everything
function STEPS.paths()
	local m = folder(root, "Paths")
	local color = Color3.fromRGB(225, 200, 150)
	local function path(a, b, w)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		part(m, {Size = Vector3.new(w or 8, 0.4, len), CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.12, 0), b + Vector3.new(0, 0.12, 0)), Color = color,
			Material = Enum.Material.Sand, CanCollide = false})
	end
	path(Vector3.new(-36, 0, 0), Vector3.new(-192, 0, -10)) -- plaza -> forest (between the west farms)
	path(Vector3.new(36, 0, 0), Vector3.new(192, 0, -10)) -- plaza -> peaks
	path(Vector3.new(-60, 0, -200), Vector3.new(-170, 0, -262)) -- meadow -> caves
	path(Vector3.new(60, 0, -200), Vector3.new(170, 0, -262)) -- meadow -> volcano
	-- plaza openings -> each farm's gate
	for _, c in FARM_SPOTS do
		local gate = c + (-c * Vector3.new(1, 0, 1)).Unit * 28
		local from = c.Z > 60 and Vector3.new(0, 0, 36) or Vector3.new(c.X > 0 and 36 or -36, 0, 0)
		path(from, gate, 6)
	end
end

---------------------------------------------------------------- the meadow gets bigger, with flowers and nodes
function STEPS.meadow()
	local meadow = root:FindFirstChild("Meadow")
	meadow.Size = Vector3.new(220, meadow.Size.Y, 160)
	meadow.Position = Vector3.new(0, meadow.Position.Y, -125)
	local m = folder(root, "Biome_MeadowExtras")
	local b = {Center = Vector3.new(0, 0, -125), Size = Vector2.new(220, 160), Mult = 1}
	scatter(b, 40, 30, function(p, i) -- flower patches
		local colors = {Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 230, 90), Color3.fromRGB(170, 130, 255), Color3.new(1, 1, 1)}
		for k = 1, 4 do
			part(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CanCollide = false,
				Position = p + Vector3.new(rng:NextNumber(-2, 2), 0.8, rng:NextNumber(-2, 2)), Color = colors[(i + k) % 4 + 1]})
		end
	end)
	scatter(b, 12, 30, function(p) -- round trees
		part(m, {Size = Vector3.new(1.6, 8, 1.6), Position = p + Vector3.new(0, 4, 0), Color = Color3.fromRGB(120, 85, 55), Material = Enum.Material.Wood})
		part(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 8, Position = p + Vector3.new(0, 9.5, 0), Color = Color3.fromRGB(110, 190, 80), Material = Enum.Material.Grass, CanCollide = false})
	end)
	addNodes(m, b, "Meadow")
end

---------------------------------------------------------------- 30 golden acorns: on rocks, behind things, in corners
function STEPS.acorns()
	local f = folder(root, "Acorns")
	local id = 0
	local function acorn(pos)
		id += 1
		local m = Instance.new("Model")
		m.Name = "Acorn" .. id
		m:SetAttribute("Id", id)
		local nut = part(m, {Name = "Nut", Size = Vector3.new(1.1, 1.4, 1.1), Position = pos + Vector3.new(0, 0.8, 0), Color = Color3.fromRGB(255, 200, 50),
			Material = Enum.Material.SmoothPlastic, Reflectance = 0.25, CanCollide = false})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = nut
		part(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 1.3, 1.3), CFrame = CFrame.new(pos + Vector3.new(0, 1.45, 0)) * UP, Color = Color3.fromRGB(150, 100, 50),
			CanCollide = false})
		part(m, {Size = Vector3.new(0.15, 0.4, 0.15), Position = pos + Vector3.new(0, 1.85, 0), Color = Color3.fromRGB(110, 70, 40), CanCollide = false})
		local glow = Instance.new("ParticleEmitter")
		glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		glow.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
		glow.LightEmission = 1
		glow.Size = NumberSequence.new(0.4, 0)
		glow.Rate = 3
		glow.Speed = NumberRange.new(0.5, 1)
		glow.SpreadAngle = Vector2.new(180, 180)
		glow.Parent = nut
		m.PrimaryPart = nut
		m.Parent = f
	end
	-- 6 per biome: 3 on top of something climbable (low rocks / mushroom caps), 3 tucked away near the edges
	local areas = {
		{folder = root:FindFirstChild("Biome_MeadowExtras"), center = Vector3.new(0, 0, -125), size = Vector2.new(220, 160)},
	}
	for name, b in BIOMES do
		table.insert(areas, {folder = root:FindFirstChild("Biome_" .. name), center = b.Center, size = b.Size})
	end
	for _, a in areas do
		local tops = {}
		if a.folder then
			for _, p in a.folder:GetDescendants() do
				if p:IsA("BasePart") and p.CanCollide and p.Name ~= "Ground" and not p:FindFirstAncestorWhichIsA("Model") then
					local top = p.Position.Y + p.Size.Y / 2
					if top > 2.5 and top < 8 and math.min(p.Size.X, p.Size.Z) >= 2.5 then table.insert(tops, p) end
				end
			end
		end
		for k = 1, 3 do
			local p = tops[rng:NextInteger(1, math.max(1, #tops))]
			if p then
				acorn(Vector3.new(p.Position.X, p.Position.Y + p.Size.Y / 2 - 0.2, p.Position.Z))
			else
				acorn(a.center + Vector3.new(rng:NextNumber(-40, 40), 0.3, rng:NextNumber(-40, 40)))
			end
		end
		for k = 1, 3 do -- near the edges and corners, away from the paths
			local sx, sz = (rng:NextNumber() < 0.5 and -1 or 1), (rng:NextNumber() < 0.5 and -1 or 1)
			acorn(a.center + Vector3.new(sx * a.size.X * rng:NextNumber(0.35, 0.46), 0.3, sz * a.size.Y * rng:NextNumber(0.35, 0.46)))
		end
	end
end

---------------------------------------------------------------- plaza extras: workbench, record board; playground south of the plaza
function STEPS.plazaExtras()
	-- 🔨 workbench (CritterWorld opens the crafting window from a prompt on it)
	local wb = folder(root, "Workbench")
	local c = Vector3.new(24, 0, -14)
	local top = part(wb, {Name = "Table", Size = Vector3.new(8, 1, 4), Position = c + Vector3.new(0, 3, 0), Color = Color3.fromRGB(170, 120, 75), Material = Enum.Material.WoodPlanks})
	for _, x in {-3.5, 3.5} do
		for _, z in {-1.5, 1.5} do part(wb, {Size = Vector3.new(0.7, 3, 0.7), Position = c + Vector3.new(x, 1.5, z), Color = Color3.fromRGB(120, 85, 55)}) end
	end
	part(wb, {Size = Vector3.new(1.2, 0.5, 0.5), CFrame = CFrame.new(c + Vector3.new(-2, 3.75, 0)) * CFrame.Angles(0, 0.6, 0), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Metal})
	part(wb, {Size = Vector3.new(0.3, 0.3, 2), CFrame = CFrame.new(c + Vector3.new(-2, 3.65, 0.6)) * CFrame.Angles(0, 0.6, 0), Color = Color3.fromRGB(140, 95, 60)})
	part(wb, {Shape = Enum.PartType.Ball, Size = Vector3.one * 1, Position = c + Vector3.new(2, 4, 0), Color = Color3.fromRGB(180, 110, 255), Material = Enum.Material.Neon})
	sign(wb, c + Vector3.new(4.6, 0, 2.6), "🔨", "Workbench", Color3.fromRGB(200, 130, 60))
	-- 🏆 record board
	local rb = folder(root, "RecordBoard")
	local b = part(rb, {Name = "Board", Size = Vector3.new(14, 9, 1), Position = Vector3.new(-28, 5.5, -26), Color = Color3.fromRGB(70, 60, 110)})
	b.CFrame = CFrame.lookAt(b.Position, Vector3.new(0, 5.5, 10))
	for _, x in {-6, 6} do part(rb, {Size = Vector3.new(0.8, 10, 0.8), CFrame = b.CFrame * CFrame.new(x, -1, 0.6), Color = Color3.fromRGB(120, 85, 55)}) end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(700, 450)
	sg.Parent = b
	local t = Instance.new("TextLabel")
	t.Name = "List"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 235, 150)
	t.TextStrokeTransparency = 0.4
	t.Text = "🏆 RECORDS"
	t.Parent = sg
	-- 🛝 playground (trampolines and bounce pads are named "Bounce"; CritterWorld bounces you)
	local pg = folder(root, "Playground")
	local o = Vector3.new(20, 0, 54)
	part(pg, {Name = "Ground", Size = Vector3.new(30, 0.4, 26), Position = o + Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(255, 200, 150), Material = Enum.Material.Sand})
	local colors = {Color3.fromRGB(255, 90, 120), Color3.fromRGB(90, 190, 255), Color3.fromRGB(255, 210, 70)}
	for i = 1, 3 do -- trampolines (bigger = higher)
		local pos = o + Vector3.new(-10 + (i - 1) * 7, 0, -7)
		part(pg, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 5.6, 5.6), CFrame = CFrame.new(pos + Vector3.new(0, 0.7, 0)) * UP, Color = Color3.fromRGB(60, 60, 70)})
		local pad = part(pg, {Name = "Bounce", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 5, 5), CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * UP, Color = colors[i]})
		pad:SetAttribute("Power", 70 + i * 20)
	end
	-- slide: ladder up to a platform, a long ramp down
	local tower = o + Vector3.new(10, 0, -6)
	part(pg, {Name = "Platform", Size = Vector3.new(6, 1, 6), Position = tower + Vector3.new(0, 12, 0), Color = Color3.fromRGB(90, 190, 255)})
	for _, x in {-2.5, 2.5} do
		for _, z in {-2.5, 2.5} do part(pg, {Size = Vector3.new(0.8, 12, 0.8), Position = tower + Vector3.new(x, 6, z), Color = Color3.fromRGB(255, 210, 70)}) end
	end
	local truss = Instance.new("TrussPart")
	truss.Anchored = true
	truss.Size = Vector3.new(2, 12, 2)
	truss.Position = tower + Vector3.new(0, 6, -4)
	truss.Color = Color3.fromRGB(255, 90, 120)
	truss.Parent = pg
	local slideTop, slideBottom = tower + Vector3.new(0, 12, 3), tower + Vector3.new(0, 0.6, 22)
	local mid = (slideTop + slideBottom) / 2
	part(pg, {Name = "Slide", Size = Vector3.new(4, 0.6, (slideBottom - slideTop).Magnitude), CFrame = CFrame.lookAt(mid, slideBottom),
		Color = Color3.fromRGB(255, 120, 170), Material = Enum.Material.SmoothPlastic})
	-- bounce pads in a line up to a high perch
	for i = 1, 4 do
		local pad = part(pg, {Name = "Bounce", Size = Vector3.new(3, 0.5, 3), Position = o + Vector3.new(-12 + i * 4, 0.6 + i * 1.5, 7), Color = colors[i % 3 + 1]})
		pad:SetAttribute("Power", 60)
		part(pg, {Size = Vector3.new(1, 0.6 + i * 1.5, 1), Position = o + Vector3.new(-12 + i * 4, (0.6 + i * 1.5) / 2, 7), Color = Color3.fromRGB(200, 200, 210)})
	end
	part(pg, {Name = "Perch", Size = Vector3.new(5, 1, 5), Position = o + Vector3.new(10, 14, 8), Color = Color3.fromRGB(255, 210, 70)})
	part(pg, {Size = Vector3.new(1, 14, 1), Position = o + Vector3.new(10, 7, 8), Color = Color3.fromRGB(200, 200, 210)})
	sign(pg, o + Vector3.new(-14, 0, -12), "🛝", "Playground", Color3.fromRGB(255, 110, 150))
end

---------------------------------------------------------------- 6 bonus plots per farm (start locked)
function STEPS.farmPlots()
	local spots = {{-18, 3}, {18, 0}, {-18, -6}, {18, -9}, {18, 9}, {0, -11}}
	for _, farm in root.Farms:GetChildren() do
		local plots = farm:FindFirstChild("Plots")
		local template = plots and plots:FindFirstChild("Plot1")
		if template then
			for i, s in spots do
				local n = 9 + i
				local old = plots:FindFirstChild("Plot" .. n)
				if old then old:Destroy() end
				local p = template:Clone()
				for _, ch in p:GetChildren() do ch:Destroy() end
				p.Name = "Plot" .. n
				p.CFrame = farm.Ground.CFrame * CFrame.new(s[1], 1.1, s[2])
				p.Parent = plots
			end
		end
	end
end

---------------------------------------------------------------- seed shop in the middle of the plaza
function STEPS.shop()
	local m = folder(root, "SeedShop")
	local c = Vector3.new(0, 0, -12)
	local wood = Color3.fromRGB(190, 135, 85)
	local counter = part(m, {Name = "Counter", Size = Vector3.new(14, 3.2, 4), Position = c + Vector3.new(0, 1.6, 0), Color = wood, Material = Enum.Material.WoodPlanks})
	for _, x in {-6.6, 6.6} do
		for _, z in {-1.6, -6} do
			part(m, {Size = Vector3.new(0.8, 9, 0.8), Position = c + Vector3.new(x, 4.5, z), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood})
		end
	end
	for i = 0, 6 do -- striped roof
		part(m, {Size = Vector3.new(2.1, 0.5, 7), CFrame = CFrame.new(c + Vector3.new(-6.3 + i * 2.1, 9.2, -3.8)) * CFrame.Angles(0.18, 0, 0),
			Color = i % 2 == 0 and Color3.fromRGB(110, 200, 110) or Color3.fromRGB(255, 255, 255)})
	end
	local sackColors = {Color3.fromRGB(230, 200, 150), Color3.fromRGB(210, 180, 130)}
	for i = -2, 2 do -- seed sacks on the counter
		part(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Position = c + Vector3.new(i * 2.4, 3.8, 0.4), Color = sackColors[(i % 2) + 1],
			CanCollide = false})
		part(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, Position = c + Vector3.new(i * 2.4, 4.6, 0.4),
			Color = ({Color3.fromRGB(255, 110, 170), Color3.fromRGB(255, 215, 70), Color3.fromRGB(150, 110, 255), Color3.fromRGB(255, 140, 40),
				Color3.fromRGB(235, 50, 60)})[i + 3], CanCollide = false})
	end
	-- shopkeeper critter behind the counter
	local pm = game:GetService("ReplicatedStorage"):FindFirstChild("PetModels")
	local keeperT = pm and (pm:FindFirstChild("Pockets") or pm:FindFirstChild("Hopsy"))
	if keeperT then
		local keeper = keeperT:Clone()
		keeper.Name = "Shopkeeper"
		local _, size = keeper:GetBoundingBox()
		keeper:ScaleTo(keeper:GetScale() * 4.5 / math.max(size.Y, 0.1))
		local _, s2 = keeper:GetBoundingBox()
		keeper:PivotTo(CFrame.new(c + Vector3.new(0, s2.Y / 2 + 0.1, -4)) * CFrame.Angles(0, math.pi, 0))
		for _, d in keeper:GetDescendants() do
			if d:IsA("BasePart") then d.Anchored, d.CanCollide = true, false end
		end
		keeper.Parent = m
	end
	-- big board: stock + countdown (ShopServer writes Gui.Text)
	local board = part(m, {Name = "Board", Size = Vector3.new(1, 1, 1), Position = c + Vector3.new(0, 13, -4), Transparency = 1, CanCollide = false, CanQuery = false})
	local bb = Instance.new("BillboardGui")
	bb.Name = "Gui"
	bb.Size = UDim2.fromOffset(340, 130)
	bb.MaxDistance = 250
	bb.Parent = board
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(70, 140, 70)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Text = "🛒"
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 18)
	local st = Instance.new("UIStroke", t)
	st.Color, st.Thickness, st.ApplyStrokeMode = Color3.fromRGB(255, 230, 120), 4, Enum.ApplyStrokeMode.Border
	t.Parent = bb
	-- landing pad for the delivery balloon
	part(m, {Name = "Dock", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7, 7), CFrame = CFrame.new(c + Vector3.new(12, 0.35, 2)) * UP,
		Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.SmoothPlastic, CanCollide = false})
end

---------------------------------------------------------------- on every farm: nap hut, bench, egg nest
function STEPS.farmExtras()
	local farmsF = root:FindFirstChild("Farms")
	for _, farm in farmsF:GetChildren() do
		for _, n in {"Hut", "Bench", "Nest", "NapSpot", "BenchSpot"} do
			local old = farm:FindFirstChild(n)
			if old then old:Destroy() end
		end
		local base = farm.Ground.CFrame
		local function at(x, y, z) return base * CFrame.new(x, y, z) end
		-- nap hut (back left)
		local hut = Instance.new("Model")
		hut.Name = "Hut"
		part(hut, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 6, 6), CFrame = at(-18, 2.8, 19) * UP, Color = Color3.fromRGB(250, 238, 210)})
		local cap = part(hut, {Size = Vector3.new(10, 4, 10), CFrame = at(-18, 6.3, 19), Color = Color3.fromRGB(120, 140, 255)})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = cap
		part(hut, {Size = Vector3.new(2.2, 3.2, 0.3), CFrame = at(-18, 1.9, 15.9), Color = Color3.fromRGB(110, 80, 60)})
		local zz = Instance.new("BillboardGui")
		zz.Size = UDim2.fromOffset(60, 50)
		zz.StudsOffset = Vector3.new(0, 3, 0)
		zz.MaxDistance = 80
		zz.Parent = cap
		local zt = Instance.new("TextLabel")
		zt.BackgroundTransparency = 1
		zt.Size = UDim2.fromScale(1, 1)
		zt.TextScaled = true
		zt.Text = "💤"
		zt.Parent = zz
		hut.Parent = farm
		part(farm, {Name = "NapSpot", Size = Vector3.new(1, 0.2, 1), CFrame = at(-15, 0.4, 12), Transparency = 1, CanCollide = false, CanQuery = false})
		-- bench (back right)
		local bench = Instance.new("Model")
		bench.Name = "Bench"
		local wood = Color3.fromRGB(205, 160, 110)
		part(bench, {Size = Vector3.new(8, 0.6, 2.2), CFrame = at(18, 1.6, 20), Color = wood, Material = Enum.Material.WoodPlanks})
		part(bench, {Size = Vector3.new(8, 2, 0.4), CFrame = at(18, 2.8, 21), Color = wood, Material = Enum.Material.WoodPlanks})
		for _, x in {14.6, 21.4} do part(bench, {Size = Vector3.new(0.6, 1.4, 2), CFrame = at(x, 0.7, 20), Color = Color3.fromRGB(140, 100, 60)}) end
		bench.Parent = farm
		part(farm, {Name = "BenchSpot", Size = Vector3.new(1, 0.2, 1), CFrame = at(16, 0.4, 14), Transparency = 1, CanCollide = false, CanQuery = false})
		-- egg nest (front left, near the gate)
		local nest = Instance.new("Model")
		nest.Name = "Nest"
		local nb = part(nest, {Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 6.5, 6.5), CFrame = at(-15, 0.8, -16) * UP,
			Color = Color3.fromRGB(215, 175, 100), Material = Enum.Material.Fabric})
		part(nest, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 7.2, 7.2), CFrame = at(-15, 1.3, -16) * UP,
			Color = Color3.fromRGB(190, 145, 80), Material = Enum.Material.Fabric, CanCollide = false})
		for i = 1, 3 do
			local a = i * math.pi * 2 / 3
			local egg = part(nest, {Name = "Egg" .. i, Size = Vector3.new(1.6, 2.1, 1.6), CFrame = at(-15 + math.cos(a) * 1.6, 2.4, -16 + math.sin(a) * 1.6),
				Color = Color3.fromRGB(245, 235, 210), Transparency = 1, CanCollide = false})
			local em = Instance.new("SpecialMesh")
			em.MeshType = Enum.MeshType.Sphere
			em.Parent = egg
		end
		nest.PrimaryPart = nb
		nest.Parent = farm
	end
end

return function(step)
	STEPS[step]()
	return "built " .. step
end
