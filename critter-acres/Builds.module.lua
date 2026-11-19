-- Critter Acres: Builds (ReplicatedStorage ModuleScript)
-- Part-built models shared by the server and clients:
--   Builds.Crop(name)   a fruit shaped like its crop (strawberry, lemon, grapes, pumpkin, star...)
--                       about 1 stud wide, sitting on y = 0. Parts named "Fruit" get the mutation tint.
--   Builds.Sprout()     a little seedling for crops that are still growing
--   Builds.Decor(name)  a farm decoration at real size, sitting on y = 0
-- Every model has an invisible PrimaryPart "Base" at its bottom center (use :ScaleTo and :PivotTo).
local Builds = {}

local UP = CFrame.Angles(0, 0, math.pi / 2) -- cylinders point along X; this stands them up
local function newModel(name)
	local m = Instance.new("Model")
	m.Name = name
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.one * 0.05
	base.Transparency = 1
	base.Anchored, base.CanCollide, base.CanQuery, base.CanTouch = true, false, false, false
	base.CFrame = CFrame.new()
	base.Parent = m
	m.PrimaryPart = base
	return m
end
local function p(m, props)
	local x = Instance.new("Part")
	x.Anchored, x.CanCollide, x.CanQuery, x.CanTouch, x.Massless = true, false, false, false, true
	x.TopSurface, x.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	x.Material = Enum.Material.SmoothPlastic
	for k, v in props do x[k] = v end
	x.Parent = m
	return x
end
local function egg(m, props) -- ellipsoid: a block with a sphere mesh (sized by the part)
	local x = p(m, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = x
	return x
end
local function ball(m, props)
	props.Shape = Enum.PartType.Ball
	return p(m, props)
end
local function disc(m, cf, height, diameter, props)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = cf * UP
	return p(m, props)
end
local GREEN = Color3.fromRGB(80, 170, 70)
local function leaves(m, y, n, size, color)
	for i = 0, n - 1 do
		local a = i * math.pi * 2 / n
		egg(m, {Name = "Leaf", Size = Vector3.new(size * 0.35, size * 0.08, size), Color = color or GREEN,
			CFrame = CFrame.new(math.cos(a) * size * 0.3, y, math.sin(a) * size * 0.3) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(-0.35, 0, 0)})
	end
end
local function stem(m, y, h, color)
	disc(m, CFrame.new(0, y + h / 2, 0), h, 0.08, {Name = "Stem", Color = color or Color3.fromRGB(110, 80, 50)})
end

---------------------------------------------------------------- crops
local CROP = {}
function CROP.Puffberry(m) -- strawberry
	local red = Color3.fromRGB(235, 45, 70)
	egg(m, {Name = "Fruit", Size = Vector3.new(1, 0.75, 1), CFrame = CFrame.new(0, 0.62, 0), Color = red})
	egg(m, {Name = "Fruit", Size = Vector3.new(0.62, 0.62, 0.62), CFrame = CFrame.new(0, 0.32, 0), Color = red})
	egg(m, {Name = "Fruit", Size = Vector3.new(0.28, 0.3, 0.28), CFrame = CFrame.new(0, 0.1, 0), Color = red})
	for i = 0, 9 do -- seeds
		local a = i * 2.4
		local y = 0.3 + (i % 3) * 0.17
		local r = 0.32 + (i % 3) * 0.08
		ball(m, {Size = Vector3.one * 0.06, Position = Vector3.new(math.cos(a) * r, y, math.sin(a) * r), Color = Color3.fromRGB(255, 230, 120)})
	end
	leaves(m, 0.98, 5, 0.6)
	stem(m, 1, 0.18)
end
function CROP.Sunberry(m) -- lemon
	local yellow = Color3.fromRGB(255, 220, 60)
	egg(m, {Name = "Fruit", Size = Vector3.new(0.8, 0.8, 1.15), CFrame = CFrame.new(0, 0.42, 0), Color = yellow})
	for _, z in {-0.6, 0.6} do egg(m, {Name = "Fruit", Size = Vector3.new(0.22, 0.22, 0.2), CFrame = CFrame.new(0, 0.42, z), Color = yellow}) end
	egg(m, {Name = "Leaf", Size = Vector3.new(0.25, 0.05, 0.5), CFrame = CFrame.new(0.1, 0.84, -0.2) * CFrame.Angles(0.3, 0.5, 0), Color = GREEN})
end
function CROP.Moonplum(m) -- grape bunch
	local purple = Color3.fromRGB(140, 90, 230)
	local rows = {{3, 0.85}, {3, 0.62}, {2, 0.4}, {1, 0.18}}
	for _, r in rows do
		for i = 0, r[1] - 1 do
			local a = i * math.pi * 2 / r[1] + r[2]
			local rad = r[1] == 1 and 0 or 0.17 + r[1] * 0.04
			ball(m, {Name = "Fruit", Size = Vector3.one * 0.32, Position = Vector3.new(math.cos(a) * rad, r[2], math.sin(a) * rad), Color = purple})
		end
	end
	stem(m, 0.95, 0.2, Color3.fromRGB(90, 130, 60))
	egg(m, {Name = "Leaf", Size = Vector3.new(0.45, 0.05, 0.4), CFrame = CFrame.new(0.15, 1.1, 0) * CFrame.Angles(0, 0, 0.4), Color = GREEN})
end
function CROP.RainbowDrop(m) -- rainbow-striped drop
	local colors = {Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 235, 90), Color3.fromRGB(110, 220, 110),
		Color3.fromRGB(90, 170, 255), Color3.fromRGB(170, 110, 255)}
	local widths = {0.55, 0.85, 0.98, 0.92, 0.7, 0.36}
	for i, w in widths do
		disc(m, CFrame.new(0, 0.1 + (i - 1) * 0.16, 0), 0.17, w, {Name = "Fruit", Color = colors[i], Material = Enum.Material.Neon})
	end
	ball(m, {Name = "Fruit", Size = Vector3.one * 0.18, Position = Vector3.new(0, 1.05, 0), Color = colors[6], Material = Enum.Material.Neon})
end
function CROP.Pumpkin(m)
	local orange = Color3.fromRGB(255, 135, 30)
	for i = 0, 5 do
		local a = i * math.pi / 3
		egg(m, {Name = "Fruit", Size = Vector3.new(0.45, 0.8, 0.85), CFrame = CFrame.new(math.cos(a) * 0.27, 0.4, math.sin(a) * 0.27) * CFrame.Angles(0, -a, 0), Color = orange})
	end
	disc(m, CFrame.new(0, 0.85, 0), 0.25, 0.14, {Name = "Stem", Color = Color3.fromRGB(110, 140, 60)})
	egg(m, {Name = "Leaf", Size = Vector3.new(0.4, 0.05, 0.35), CFrame = CFrame.new(0.2, 0.86, 0.1) * CFrame.Angles(0, 0.4, 0.3), Color = GREEN})
end
function CROP.Moonflower(m) -- glowing flower
	stem(m, 0, 0.5, Color3.fromRGB(80, 150, 90))
	for i = 0, 5 do
		local a = i * math.pi / 3
		egg(m, {Name = "Fruit", Size = Vector3.new(0.3, 0.07, 0.62), CFrame = CFrame.new(math.cos(a) * 0.28, 0.55, math.sin(a) * 0.28) * CFrame.Angles(0, -a + math.pi / 2, 0)
			* CFrame.Angles(0.3, 0, 0), Color = Color3.fromRGB(190, 210, 255), Material = Enum.Material.Neon})
	end
	ball(m, {Name = "Fruit", Size = Vector3.one * 0.28, Position = Vector3.new(0, 0.58, 0), Color = Color3.fromRGB(255, 240, 150), Material = Enum.Material.Neon})
	leaves(m, 0.1, 2, 0.5)
end
function CROP.Starfruit(m) -- five-point star
	local gold = Color3.fromRGB(255, 240, 110)
	disc(m, CFrame.new(0, 0.5, 0) * CFrame.Angles(math.pi / 2, 0, 0), 0.3, 0.42, {Name = "Fruit", Color = gold, Material = Enum.Material.Neon})
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5 + math.pi / 2
		p(m, {Name = "Fruit", Size = Vector3.new(0.26, 0.5, 0.26), Color = gold, Material = Enum.Material.Neon,
			CFrame = CFrame.new(math.cos(a) * 0.3, 0.5 + math.sin(a) * 0.3, 0) * CFrame.Angles(0, 0, a - math.pi / 2) * CFrame.Angles(0, math.pi / 4, 0)})
	end
end
function CROP.AppleTree(m) -- one apple (trees hang several)
	ball(m, {Name = "Fruit", Size = Vector3.one * 0.9, Position = Vector3.new(0, 0.45, 0), Color = Color3.fromRGB(230, 40, 50)})
	stem(m, 0.85, 0.2)
	egg(m, {Name = "Leaf", Size = Vector3.new(0.3, 0.05, 0.45), CFrame = CFrame.new(0.15, 1, 0) * CFrame.Angles(0, 0, 0.5), Color = GREEN})
end
function CROP.CherryTree(m)
	for _, x in {-0.22, 0.22} do
		ball(m, {Name = "Fruit", Size = Vector3.one * 0.5, Position = Vector3.new(x, 0.25, 0), Color = Color3.fromRGB(200, 20, 55)})
		p(m, {Name = "Stem", Size = Vector3.new(0.05, 0.65, 0.05), CFrame = CFrame.new(x * 0.5, 0.75, 0) * CFrame.Angles(0, 0, -x * 1.6), Color = Color3.fromRGB(110, 140, 60)})
	end
	egg(m, {Name = "Leaf", Size = Vector3.new(0.3, 0.05, 0.5), CFrame = CFrame.new(0.15, 1.05, 0) * CFrame.Angles(0, 0, 0.4), Color = GREEN})
end
function CROP.MangoTree(m)
	egg(m, {Name = "Fruit", Size = Vector3.new(0.75, 1, 0.65), CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, 0.25), Color = Color3.fromRGB(255, 170, 40)})
	egg(m, {Name = "Fruit", Size = Vector3.new(0.5, 0.5, 0.45), CFrame = CFrame.new(-0.12, 0.72, 0), Color = Color3.fromRGB(240, 90, 50)})
	egg(m, {Name = "Leaf", Size = Vector3.new(0.25, 0.05, 0.55), CFrame = CFrame.new(0.1, 1.05, 0) * CFrame.Angles(0, 0, 0.4), Color = GREEN})
end
function CROP.DragonfruitTree(m)
	egg(m, {Name = "Fruit", Size = Vector3.new(0.8, 1, 0.8), CFrame = CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(255, 60, 160)})
	for i = 0, 5 do
		local a = i * math.pi / 3
		p(m, {Name = "Leaf", Size = Vector3.new(0.12, 0.35, 0.08), Color = Color3.fromRGB(120, 210, 80),
			CFrame = CFrame.new(math.cos(a) * 0.35, 0.45 + (i % 2) * 0.25, math.sin(a) * 0.35) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, 0.6)})
	end
end
function Builds.Crop(name)
	local fn = CROP[(name or ""):gsub(" ", "")]
	local m = newModel("Crop")
	if fn then fn(m) else ball(m, {Name = "Fruit", Size = Vector3.one, Position = Vector3.new(0, 0.5, 0), Color = Color3.new(1, 1, 1)}) end
	return m
end
function Builds.Sprout()
	local m = newModel("Sprout")
	stem(m, 0, 0.5, Color3.fromRGB(90, 170, 70))
	for _, s in {-1, 1} do
		egg(m, {Name = "Leaf", Size = Vector3.new(0.5, 0.06, 0.28), CFrame = CFrame.new(s * 0.22, 0.48, 0) * CFrame.Angles(0, 0, s * 0.4), Color = Color3.fromRGB(110, 200, 90)})
	end
	return m
end

---------------------------------------------------------------- decorations (real size, in studs)
local DECOR = {}
local wood, dark = Color3.fromRGB(190, 140, 90), Color3.fromRGB(120, 85, 55)
function DECOR.FlowerBed(m)
	p(m, {Size = Vector3.new(4, 0.6, 2.2), Position = Vector3.new(0, 0.3, 0), Color = Color3.fromRGB(120, 85, 60), Material = Enum.Material.Wood})
	local colors = {Color3.fromRGB(255, 110, 160), Color3.fromRGB(255, 230, 90), Color3.fromRGB(170, 120, 255), Color3.fromRGB(255, 255, 255)}
	for i = 0, 7 do
		local x, z = -1.5 + (i % 4), (i < 4) and -0.5 or 0.5
		stem(m, 0.6, 0.5, Color3.fromRGB(90, 160, 70))
		m:GetChildren()[#m:GetChildren()].Position = Vector3.new(x, 0.85, z)
		ball(m, {Size = Vector3.one * 0.5, Position = Vector3.new(x, 1.2, z), Color = colors[i % 4 + 1]})
	end
end
function DECOR.WhiteFence(m)
	for _, x in {-1.8, 0, 1.8} do p(m, {Size = Vector3.new(0.4, 2.2, 0.4), Position = Vector3.new(x, 1.1, 0), Color = Color3.new(1, 1, 1), CanCollide = true}) end
	for _, y in {0.7, 1.6} do p(m, {Size = Vector3.new(4, 0.3, 0.2), Position = Vector3.new(0, y, 0), Color = Color3.new(1, 1, 1)}) end
end
function DECOR.HayBale(m)
	disc(m, CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2), 2.4, 1.8, {Color = Color3.fromRGB(235, 200, 100), Material = Enum.Material.Fabric, CanCollide = true})
end
function DECOR.OakTree(m)
	p(m, {Size = Vector3.new(1.2, 6, 1.2), Position = Vector3.new(0, 3, 0), Color = dark, Material = Enum.Material.Wood, CanCollide = true})
	for i = 0, 3 do
		ball(m, {Size = Vector3.one * (4.5 - i * 0.4), Position = Vector3.new(math.cos(i * 1.7) * 1.2, 6.5 + i * 0.6, math.sin(i * 1.7) * 1.2),
			Color = Color3.fromRGB(70 + i * 10, 160, 70), Material = Enum.Material.Grass})
	end
end
function DECOR.Bench(m)
	p(m, {Size = Vector3.new(4, 0.4, 1.4), Position = Vector3.new(0, 1, 0), Color = wood, Material = Enum.Material.WoodPlanks, CanCollide = true})
	p(m, {Size = Vector3.new(4, 1.2, 0.3), Position = Vector3.new(0, 1.8, 0.6), Color = wood, Material = Enum.Material.WoodPlanks})
	for _, x in {-1.7, 1.7} do p(m, {Size = Vector3.new(0.3, 1, 1.2), Position = Vector3.new(x, 0.5, 0), Color = dark}) end
end
function DECOR.LampPost(m)
	disc(m, CFrame.new(0, 2.5, 0), 5, 0.35, {Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal, CanCollide = true})
	local bulb = ball(m, {Size = Vector3.one * 1, Position = Vector3.new(0, 5.4, 0), Color = Color3.fromRGB(255, 240, 180), Material = Enum.Material.Neon})
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color = 16, 1.5, Color3.fromRGB(255, 230, 170)
	light.Parent = bulb
end
function DECOR.MushroomHouse(m)
	disc(m, CFrame.new(0, 1.4, 0), 2.8, 2.6, {Color = Color3.fromRGB(250, 240, 220), CanCollide = true})
	egg(m, {Size = Vector3.new(4.4, 2.2, 4.4), CFrame = CFrame.new(0, 3.2, 0), Color = Color3.fromRGB(230, 70, 70)})
	for i = 0, 4 do ball(m, {Size = Vector3.one * 0.5, Position = Vector3.new(math.cos(i * 1.3) * 1.4, 3.9, math.sin(i * 1.3) * 1.4), Color = Color3.new(1, 1, 1)}) end
	p(m, {Size = Vector3.new(0.9, 1.4, 0.2), Position = Vector3.new(0, 0.7, -1.3), Color = dark})
end
function DECOR.Snowman(m)
	ball(m, {Size = Vector3.one * 2.4, Position = Vector3.new(0, 1.2, 0), Color = Color3.new(1, 1, 1), Material = Enum.Material.Snow, CanCollide = true})
	ball(m, {Size = Vector3.one * 1.7, Position = Vector3.new(0, 2.9, 0), Color = Color3.new(1, 1, 1), Material = Enum.Material.Snow})
	ball(m, {Size = Vector3.one * 1.2, Position = Vector3.new(0, 4.1, 0), Color = Color3.new(1, 1, 1), Material = Enum.Material.Snow})
	p(m, {Size = Vector3.new(0.18, 0.18, 0.6), Position = Vector3.new(0, 4.1, -0.75), Color = Color3.fromRGB(255, 140, 40)})
	for _, x in {-0.22, 0.22} do ball(m, {Size = Vector3.one * 0.15, Position = Vector3.new(x, 4.3, -0.55), Color = Color3.new(0.1, 0.1, 0.1)}) end
	disc(m, CFrame.new(0, 4.75, 0), 0.6, 0.9, {Color = Color3.fromRGB(40, 40, 50)})
end
function DECOR.Pond(m)
	disc(m, CFrame.new(0, 0.15, 0), 0.3, 6.5, {Color = Color3.fromRGB(140, 140, 150), Material = Enum.Material.Slate})
	disc(m, CFrame.new(0, 0.25, 0), 0.3, 5.6, {Color = Color3.fromRGB(80, 170, 255), Material = Enum.Material.Glass, Transparency = 0.2})
	for i = 0, 2 do
		disc(m, CFrame.new(math.cos(i * 2) * 1.6, 0.42, math.sin(i * 2) * 1.6), 0.06, 0.9, {Color = Color3.fromRGB(90, 180, 80)})
	end
end
function DECOR.Fountain(m)
	disc(m, CFrame.new(0, 0.5, 0), 1, 6, {Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Marble, CanCollide = true})
	disc(m, CFrame.new(0, 1.02, 0), 0.1, 5.2, {Color = Color3.fromRGB(90, 180, 255), Material = Enum.Material.Glass, Transparency = 0.25})
	disc(m, CFrame.new(0, 2, 0), 2, 0.8, {Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Marble})
	local top = disc(m, CFrame.new(0, 3.1, 0), 0.4, 2.2, {Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Marble})
	local water = Instance.new("ParticleEmitter")
	water.Color = ColorSequence.new(Color3.fromRGB(150, 210, 255))
	water.Size = NumberSequence.new(0.3, 0.1)
	water.Speed = NumberRange.new(6, 8)
	water.Acceleration = Vector3.new(0, -25, 0)
	water.Lifetime = NumberRange.new(0.6, 0.8)
	water.SpreadAngle = Vector2.new(20, 20)
	water.Rate = 40
	water.EmissionDirection = Enum.NormalId.Right -- the disc is turned: Right points up
	water.Parent = top
end
function DECOR.Windmill(m)
	p(m, {Size = Vector3.new(3, 8, 3), Position = Vector3.new(0, 4, 0), Color = Color3.fromRGB(240, 230, 210), Material = Enum.Material.WoodPlanks, CanCollide = true})
	p(m, {Size = Vector3.new(3.6, 1.6, 3.6), CFrame = CFrame.new(0, 8.6, 0) * CFrame.Angles(0, math.pi / 4, 0), Color = Color3.fromRGB(200, 70, 60)})
	local hub = ball(m, {Name = "Hub", Size = Vector3.one * 0.8, Position = Vector3.new(0, 7, -1.7), Color = dark})
	for i = 0, 3 do
		p(m, {Name = "Blade", Size = Vector3.new(0.9, 4.5, 0.15), CFrame = hub.CFrame * CFrame.Angles(0, 0, i * math.pi / 2) * CFrame.new(0, 2.3, -0.1), Color = Color3.new(1, 1, 1)})
	end
	m:SetAttribute("Spin", true) -- the server turns the blades
end
function DECOR.CrystalLamp(m)
	p(m, {Size = Vector3.new(1.4, 0.6, 1.4), Position = Vector3.new(0, 0.3, 0), Color = Color3.fromRGB(70, 60, 90), Material = Enum.Material.Slate})
	local colors = {Color3.fromRGB(170, 110, 255), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 120, 220)}
	for i = 1, 4 do
		p(m, {Size = Vector3.new(0.5, 1.4 + i * 0.4, 0.5), CFrame = CFrame.new(math.cos(i * 1.6) * 0.3, 1 + i * 0.2, math.sin(i * 1.6) * 0.3) * CFrame.Angles(0.2 * i, i, 0.15),
			Color = colors[i % 3 + 1], Material = Enum.Material.Neon})
	end
	local light = Instance.new("PointLight")
	light.Range, light.Color = 14, Color3.fromRGB(190, 140, 255)
	light.Parent = m:GetChildren()[#m:GetChildren()]
end
function DECOR.GoldStatue(m)
	p(m, {Size = Vector3.new(2.6, 1.2, 2.6), Position = Vector3.new(0, 0.6, 0), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Marble, CanCollide = true})
	local gold = Color3.fromRGB(255, 200, 50)
	ball(m, {Size = Vector3.one * 2, Position = Vector3.new(0, 2.2, 0), Color = gold, Reflectance = 0.3, Material = Enum.Material.Metal})
	for _, x in {-0.5, 0.5} do
		p(m, {Size = Vector3.new(0.4, 1, 0.3), CFrame = CFrame.new(x, 3.4, 0) * CFrame.Angles(0, 0, -x * 0.5), Color = gold, Reflectance = 0.3, Material = Enum.Material.Metal})
	end
end
function DECOR.LavaLamp(m)
	disc(m, CFrame.new(0, 0.3, 0), 0.6, 1.4, {Color = Color3.fromRGB(40, 30, 40), Material = Enum.Material.Basalt})
	local glass = egg(m, {Size = Vector3.new(1, 2.4, 1), CFrame = CFrame.new(0, 1.8, 0), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, Transparency = 0.2})
	disc(m, CFrame.new(0, 3.1, 0), 0.4, 0.8, {Color = Color3.fromRGB(40, 30, 40), Material = Enum.Material.Basalt})
	local light = Instance.new("PointLight")
	light.Range, light.Color = 12, Color3.fromRGB(255, 130, 60)
	light.Parent = glass
end
function DECOR.Sprinkler(m)
	disc(m, CFrame.new(0, 0.2, 0), 0.4, 1.2, {Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.Metal})
	disc(m, CFrame.new(0, 1, 0), 1.6, 0.25, {Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Metal})
	local head = p(m, {Name = "Head", Size = Vector3.new(1.2, 0.3, 0.3), Position = Vector3.new(0, 1.9, 0), Color = Color3.fromRGB(70, 140, 255)})
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Color = ColorSequence.new(Color3.fromRGB(150, 210, 255))
	spray.Size = NumberSequence.new(0.25, 0.05)
	spray.Speed = NumberRange.new(10, 14)
	spray.Acceleration = Vector3.new(0, -20, 0)
	spray.Lifetime = NumberRange.new(0.8, 1)
	spray.SpreadAngle = Vector2.new(70, 10)
	spray.Rate = 0
	spray.Parent = head
	m:SetAttribute("Spin", true)
end
function DECOR.Beehive(m)
	p(m, {Size = Vector3.new(0.4, 2, 0.4), Position = Vector3.new(0, 1, 0), Color = dark})
	for i = 0, 3 do
		egg(m, {Size = Vector3.new(1.6 - math.abs(i - 1.5) * 0.3, 0.6, 1.6 - math.abs(i - 1.5) * 0.3), CFrame = CFrame.new(0, 2.3 + i * 0.45, 0),
			Color = i % 2 == 0 and Color3.fromRGB(255, 200, 70) or Color3.fromRGB(235, 170, 50)})
	end
	local bees = Instance.new("ParticleEmitter")
	bees.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bees.Color = ColorSequence.new(Color3.fromRGB(255, 220, 60))
	bees.Size = NumberSequence.new(0.35)
	bees.Speed = NumberRange.new(1, 3)
	bees.SpreadAngle = Vector2.new(180, 180)
	bees.Lifetime = NumberRange.new(1.5, 2.5)
	bees.Rate = 4
	bees.Parent = m:GetChildren()[#m:GetChildren()]
end
-- 🧱 placeholder for decorations made in the Critter Editor that have no shape yet: a gift box
-- (its color comes from the name, so different ones look different). Marked with the attribute Placeholder.
local PASTEL = {Color3.fromRGB(255, 170, 190), Color3.fromRGB(150, 205, 255), Color3.fromRGB(180, 230, 140),
	Color3.fromRGB(255, 215, 120), Color3.fromRGB(210, 175, 255)}
local function placeholder(m, name)
	local h = 0
	for i = 1, #name do h += name:byte(i) end
	local white = Color3.new(1, 1, 1)
	p(m, {Name = "Box", Size = Vector3.new(2.4, 2.2, 2.4), Position = Vector3.new(0, 1.1, 0), Color = PASTEL[h % #PASTEL + 1], CanCollide = true})
	p(m, {Size = Vector3.new(2.5, 2.3, 0.45), Position = Vector3.new(0, 1.1, 0), Color = white})
	p(m, {Size = Vector3.new(0.45, 2.3, 2.5), Position = Vector3.new(0, 1.1, 0), Color = white})
	for _, s in {-1, 1} do
		egg(m, {Size = Vector3.new(0.9, 0.55, 0.4), CFrame = CFrame.new(s * 0.4, 2.45, 0) * CFrame.Angles(0, 0, -s * 0.5), Color = white})
	end
	ball(m, {Size = Vector3.one * 0.4, Position = Vector3.new(0, 2.4, 0), Color = white})
	m:SetAttribute("Placeholder", true)
end
function Builds.Decor(name)
	name = name or ""
	local fn = DECOR[(name:gsub(" ", ""))]
	local m = newModel(name)
	if fn then fn(m) else placeholder(m, name) end
	return m
end

return Builds
