-- Critter Acres: one-time town builder (Studio Edit mode). Lays the town out in cozy districts:
--   ⛲ Town square (middle): fountain, benches, boards, Farmer Fern, spawn
--   🛍️ Market street (west): Seeds & Eggs shop, Bow & Bell Boutique, Bun's Bakery, sell stand
--   🧭 Adventure gate (north, at the meadow): expedition booth, raid gate, Explorer Pip
--   🎡 Festival Green (east): carousel, fashion stage (Data.StagePos), game booths, nest tent, playground
--   🔨 Craft corner (south-west): workbench and gear forge
--   🌀 Portal plaza (south): town portal and the welcome arch
-- Moves the working parts (prompts, shopkeeper, boards) with PivotTo, then re-runs DressTown so the cozy meshes
-- follow, then adds streets, lamps, bunting and decorations into CritterAcres.TownDressing.
-- Run with: loadstring(GetAsync(".../BuildTown.lua"))()(loadstring(GetAsync(".../DressTown.lua"))())
local root = workspace:WaitForChild("CritterAcres")
local PROPS = game:GetService("ServerStorage"):WaitForChild("IslandProps")
local SQUARE = Vector3.new(4, 0, 13)

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end

---------------------------------------------------------------- moving the working parts
local function boxOf(o)
	local mn, mx = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, d in (o:IsA("BasePart") and {o} or o:GetDescendants()) do
		if d:IsA("BasePart") then
			mn = mn:Min(d.Position - d.Size / 2)
			mx = mx:Max(d.Position + d.Size / 2)
		end
	end
	return mn, mx
end
local function yaw(v) return math.atan2(-v.X, -v.Z) end
local function flat(v) return Vector3.new(v.X, 0, v.Z).Unit end
-- moves o so its middle is at x/z and `oldFront` turns into `newFront`
local function moveTo(o, x, z, newFront, oldFront)
	if o:GetAttribute("Front") then oldFront = o:GetAttribute("Front") end
	newFront = newFront or oldFront
	local mn, mx = boxOf(o)
	local c = (mn + mx) / 2
	local T = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw(newFront) - yaw(oldFront), 0) * CFrame.new(-c.X, 0, -c.Z)
	local function apply(inst)
		if inst:IsA("Model") then
			inst:PivotTo(T * inst:GetPivot())
			return
		end
		if inst:IsA("BasePart") then inst.CFrame = T * inst.CFrame end
		for _, ch in inst:GetChildren() do apply(ch) end
	end
	apply(o)
	o:SetAttribute("Front", newFront)
end

---------------------------------------------------------------- ground
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function refreshGround()
	local list = {}
	for _, n in {"FarmGround", "Paths", "Meadow"} do
		if root:FindFirstChild(n) then table.insert(list, root[n]) end
	end
	if workspace:FindFirstChild("Baseplate") then table.insert(list, workspace.Baseplate) end
	groundParams.FilterDescendantsInstances = list
end
local TOP = 2.84
local function floorAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), groundParams)
	return hit and hit.Position.Y or TOP
end

---------------------------------------------------------------- placing props
local D -- CritterAcres.TownDressing
local count = {}
local function place(name, x, z, size, front, opts)
	opts = opts or {}
	local tpl = PROPS:FindFirstChild(name)
	if not tpl then return nil end
	local m = tpl:Clone()
	local mp = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if size then mp.Size = size end
	mp.Anchored = true
	mp.CanCollide = opts.collide == true
	mp.CollisionFidelity = Enum.CollisionFidelity.Hull
	local pos = Vector3.new(x, 0, z)
	mp.CFrame = CFrame.lookAt(pos, pos + (front or Vector3.new(0, 0, -1)))
	local cfb, bs = m:GetBoundingBox()
	mp.CFrame += Vector3.new(0, floorAt(x, z) - (cfb.Y - bs.Y / 2), 0)
	m.Parent = opts.parent or D
	count[name] = (count[name] or 0) + 1
	return m, mp
end
local function sign(p, text, color, up, width)
	local bb = Instance.new("BillboardGui")
	bb.Name = "TownSign"
	bb.Size = UDim2.fromOffset(width or 240, 58)
	bb.StudsOffsetWorldSpace = Vector3.new(0, up, 0)
	bb.MaxDistance = 170
	bb.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = color
	t.BackgroundTransparency = 0.1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.45
	t.Text = text
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 16)
	local pad = Instance.new("UIPadding", t)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	t.Parent = bb
	return bb
end
local function lamp(x, z)
	local _, mp = place("LampPost", x, z, Vector3.new(2.2, 8.5, 2.2), nil, {collide = true})
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 205, 140), 18, 1.2
	light.Parent = mp
end
local function signpost(x, z, front, text, color)
	local _, mp = place("Signpost", x, z, Vector3.new(4.5, 7.5, 3.3), front, {collide = true})
	if mp then sign(mp, text, color, 6, 220) end
end

-- 🎏 a string of little flags between two points (sags in the middle)
local FLAG_COLORS = {Color3.fromRGB(255, 150, 190), Color3.fromRGB(255, 220, 100), Color3.fromRGB(140, 225, 190),
	Color3.fromRGB(140, 195, 255), Color3.fromRGB(200, 160, 255)}
local function bunting(a, b, sag)
	local m = Instance.new("Model")
	m.Name = "Bunting"
	local n = math.max(4, math.floor((b - a).Magnitude / 1.8))
	local function at(t) return a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0) end
	for i = 0, n - 1 do
		local p1, p2 = at(i / n), at((i + 1) / n)
		part(m, {Name = "String", Size = Vector3.new(0.08, 0.08, (p2 - p1).Magnitude), CFrame = CFrame.lookAt((p1 + p2) / 2, p2),
			Color = Color3.fromRGB(255, 250, 235), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, CanTouch = false})
		if i > 0 then
			local p = at(i / n)
			local dir = flat(b - a)
			part(m, {Name = "Flag", Size = Vector3.new(0.85, 0.85, 0.06), CFrame = CFrame.lookAt(p, p + dir:Cross(Vector3.yAxis)) * CFrame.new(0, -0.3, 0)
				* CFrame.Angles(0, 0, math.pi / 4), Color = FLAG_COLORS[i % #FLAG_COLORS + 1], Material = Enum.Material.SmoothPlastic,
				CanCollide = false, CanQuery = false, CanTouch = false})
		end
	end
	m.Parent = D
	count.Bunting = (count.Bunting or 0) + 1
end
local function floor(parent, name, x1, x2, z1, z2, color, material)
	return part(parent, {Name = name, Size = Vector3.new(x2 - x1, 1, z2 - z1), Position = Vector3.new((x1 + x2) / 2, TOP - 0.5, (z1 + z2) / 2),
		Color = color, Material = material or Enum.Material.Pavement})
end
local function disc(parent, name, x, z, dia, color, material)
	return part(parent, {Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, dia, dia), CFrame = CFrame.new(x, TOP - 0.53, z) * CFrame.Angles(0, 0, math.pi / 2), -- a hair lower: no flicker where it meets a street
		Color = color, Material = material or Enum.Material.Pavement})
end

local NORTH, SOUTH, EAST, WEST = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0)

return function(dressTown)
	local out = {}
	local g = root:FindFirstChild("FarmGround")
	local gx1, gx2, gz1, gz2 = -36, 44, -27, 53 -- the square's edges (new streets start right there)
	if g then
		TOP = g.Position.Y + g.Size.Y / 2
		gx1, gx2 = g.Position.X - g.Size.X / 2, g.Position.X + g.Size.X / 2
		gz1, gz2 = g.Position.Z - g.Size.Z / 2, g.Position.Z + g.Size.Z / 2
	end

	------------------------------------------------------------ 1. move the working parts into their districts
	local shop = root:FindFirstChild("SeedShop")
	if shop and shop:FindFirstChild("Counter") then
		local keeper = shop:FindFirstChild("Shopkeeper")
		local old = keeper and flat(shop.Counter.Position - keeper:GetPivot().Position) or shop.Counter.CFrame.LookVector
		moveTo(shop, -56, -12, SOUTH, old)
	end
	local function mv(name, key, x, z, front)
		local o = root:FindFirstChild(name)
		local k = o and (key and o:FindFirstChild(key, true) or o)
		if not k then table.insert(out, "missing " .. name) return end
		local look = k:IsA("BasePart") and flat(k.CFrame.LookVector) or NORTH
		moveTo(o, x, z, front, look)
	end
	mv("SellStand", "Counter", -90, 20, NORTH)
	mv("Workbench", "Table", -44, 46, EAST)
	mv("Cauldron", "Pot", 101, 34, WEST)
	mv("ExpeditionBooth", "Counter", -18, -34, SOUTH)
	mv("RaidGate", "Portal", 28, -34, SOUTH)
	mv("Playground", nil, 82, 89, nil)
	table.insert(out, "moved: seed shop, sell stand, workbench, nest, booth, raid gate, playground")

	------------------------------------------------------------ 2. streets and floors (inside Paths, so critters and drops find the ground)
	local paths = root:FindFirstChild("Paths")
	local old = paths and paths:FindFirstChild("TownFloor")
	if old then old:Destroy() end
	local F = Instance.new("Folder")
	F.Name = "TownFloor"
	local stone = Color3.fromRGB(196, 170, 132)
	floor(F, "MarketStreet", -110, gx1, -4, 12, stone)
	floor(F, "FestivalStreet", gx2, 124, -4, 12, stone)
	floor(F, "GateYard", -30, 40, -42, gz1, stone)
	floor(F, "PortalRoad", -4, 12, gz2, 59, stone)
	disc(F, "PortalPlaza", 4, 74, 34, stone)
	floor(F, "CraftDeck", -66, gx1, 36, 60, Color3.fromRGB(176, 128, 86), Enum.Material.WoodPlanks)
	disc(F, "CarouselRing", 78, 30, 28, Color3.fromRGB(232, 196, 186))
	-- grass lawn at town height under all the districts (the baseplate around town is lower and grey)
	local meadow = root:FindFirstChild("Meadow")
	local lawn = floor(F, "TownLawn", -127.5, 142.5, -30, 110, meadow and meadow.Color or Color3.fromRGB(160, 225, 115), Enum.Material.Grass)
	lawn.Position -= Vector3.new(0, 0.06, 0) -- a hair under the streets: no flicker
	F.Parent = paths or root
	-- the old farm paths and north path under the new town go invisible (still ground, nothing changes for critters)
	if paths then
		for _, p in paths:GetChildren() do
			if p:IsA("BasePart") and math.abs(p.Position.X) < 70 and p.Position.Z > -30 and p.Position.Z < 100 then
				if p:GetAttribute("DressHidden") == nil then p:SetAttribute("DressHidden", p.Transparency) end
				p.Transparency = 1
			end
		end
	end
	local np = root:FindFirstChild("Path")
	if np and np:IsA("BasePart") then
		np.Size = Vector3.new(np.Size.X, np.Size.Y, 12) -- now just the bit from the gate yard into the meadow
		np.Position = Vector3.new(np.Position.X, np.Position.Y, -48)
	end
	refreshGround()

	------------------------------------------------------------ 3. re-dress the moved stalls (meshes follow their parts)
	if dressTown then table.insert(out, dressTown()) end
	D = root:WaitForChild("TownDressing")

	-- old block trees and flowers that now sit in a street or a building go away
	local zones = {{-114, -32, -28, 36}, {-72, -32, 30, 64}, {-34, 44, -46, -25}, {42, 136, -28, 110}, {-20, 28, 51, 96}, {-38, 46, -29, 55}}
	local removed = 0
	for _, m in D:GetChildren() do
		if m.Name == "TreeRound" or m.Name == "TreeBlossom" or m.Name == "Bush" or m.Name == "Flowers" then
			local p = m:GetPivot().Position
			for _, zn in zones do
				if p.X > zn[1] - 4 and p.X < zn[2] + 4 and p.Z > zn[3] - 4 and p.Z < zn[4] + 4 then
					m:Destroy()
					removed += 1
					break
				end
			end
		end
	end
	table.insert(out, "cleared old nature: " .. removed)

	------------------------------------------------------------ 4. ⛲ town square
	place("Fountain", 4, 8, Vector3.new(15, 12, 15), SOUTH, {collide = true})
	for k = 0, 3 do
		local a = math.pi / 4 + k * math.pi / 2
		local x, z = 4 + math.cos(a) * 14, 8 + math.sin(a) * 14
		place("Bench", x, z, Vector3.new(6, 4.3, 2.9), flat(Vector3.new(4 - x, 0, 8 - z)), {collide = true})
	end
	for _, xz in {{4, -4}, {-8, 8}, {16, 8}} do
		place("Planter", xz[1], xz[2], Vector3.new(5, 2.6, 2), flat(Vector3.new(4 - xz[1], 0, 8 - xz[2])))
	end
	place("CafeTable", 30, 28, Vector3.new(7, 7, 7), WEST, {collide = true})
	place("CafeTable", -24, 34, Vector3.new(7, 7, 7), EAST, {collide = true})
	place("Balloons", -28, 46, Vector3.new(4, 9, 4))
	place("Balloons", 36, 46, Vector3.new(4, 9, 4))
	for _, xz in {{-33, -24}, {41, -24}, {-33, 50}, {41, 50}} do lamp(xz[1], xz[2]) end

	------------------------------------------------------------ 5. 🛍️ market street (west)
	if shop and shop:FindFirstChild("Counter") then sign(shop.Counter, "🌱 Seeds & Eggs 🥚", Color3.fromRGB(110, 180, 90), 12, 240) end
	local _, bk = place("Bakery", -88, -15, Vector3.new(17, 20, 15), SOUTH, {collide = true})
	if bk then sign(bk, "🧁 Bun's Bakery", Color3.fromRGB(240, 150, 120), 12, 220) end
	local _, bq = place("Boutique", -58, 24, Vector3.new(19, 21, 18), NORTH, {collide = true})
	local bm = root:FindFirstChild("Boutique")
	if bm then bm:Destroy() end
	bm = Instance.new("Model")
	bm.Name = "Boutique"
	local counter = part(bm, {Name = "Counter", Size = Vector3.new(8, 4, 2), Position = Vector3.new(-58, TOP + 2, 13.5), Transparency = 1, CanCollide = false})
	sign(bq or counter, "👗 Bow & Bell Boutique", Color3.fromRGB(240, 120, 180), bq and 12.5 or 6, 260)
	bm.PrimaryPart = counter
	bm.Parent = root
	for _, xz in {{-44, -6}, {-44, 14}, {-74, -6}, {-74, 14}, {-104, -6}, {-104, 14}} do lamp(xz[1], xz[2]) end
	for _, x in {-44, -74, -104} do
		bunting(Vector3.new(x, TOP + 7.4, -6), Vector3.new(x, TOP + 7.4, 14), 1.4)
	end
	bunting(Vector3.new(-44, TOP + 7.4, -6), Vector3.new(-74, TOP + 7.4, -6), 1.8)
	bunting(Vector3.new(-44, TOP + 7.4, 14), Vector3.new(-74, TOP + 7.4, 14), 1.8)
	place("Crates", -68, -9, Vector3.new(4.4, 5, 3.3), SOUTH, {collide = true})
	place("Crates", -102, -11, Vector3.new(4.4, 5, 3.3), SOUTH, {collide = true})
	place("Crates", -80, 18, Vector3.new(4.4, 5, 3.3), NORTH, {collide = true})
	place("CafeTable", -72, -14, Vector3.new(7, 7, 7), SOUTH, {collide = true})
	for _, xz in {{-66, 13.5}, {-50, 13.5}} do place("Planter", xz[1], xz[2], Vector3.new(5, 2.6, 2), NORTH) end
	for _, xz in {{-96, -6}, {-82, -6}} do place("Planter", xz[1], xz[2], Vector3.new(5, 2.6, 2), SOUTH) end
	signpost(-38, -8, EAST, "🛍️ Market Street", Color3.fromRGB(230, 140, 90))

	------------------------------------------------------------ 6. 🧭 adventure gate (north)
	signpost(12, -30, SOUTH, "🧭 To the Wild", Color3.fromRGB(240, 160, 60))
	for _, xz in {{-30, -40}, {40, -40}} do lamp(xz[1], xz[2]) end
	for _, xz in {{-6, -40}, {16, -40}} do place("Planter", xz[1], xz[2], Vector3.new(5, 2.6, 2), SOUTH) end
	bunting(Vector3.new(-30, TOP + 7.4, -40), Vector3.new(40, TOP + 7.4, -40), 3)

	------------------------------------------------------------ 7. 🎡 festival green (east)
	place("Carousel", 78, 30, Vector3.new(20, 19, 20), WEST)
	local _, tent = place("FestivalTent", 114, 34, Vector3.new(15, 15, 15), WEST, {collide = true})
	if tent then sign(tent, "💕 Best Friends Nest", Color3.fromRGB(240, 110, 160), 10, 240) end
	place("GameBooth", 64, -16, Vector3.new(9, 9, 8), SOUTH, {collide = true})
	place("GameBooth", 78, -16, Vector3.new(9, 9, 8), SOUTH, {collide = true})
	place("SweetsCart", 96, -14, Vector3.new(6.5, 9, 4.4), SOUTH, {collide = true})
	for _, x in {72, 82, 92} do place("Bench", x, 46, Vector3.new(6, 4.3, 2.9), SOUTH, {collide = true}) end
	for _, xz in {{58, 44}, {108, 48}, {58, 20}, {100, 18}} do place("Balloons", xz[1], xz[2], Vector3.new(4, 9, 4)) end
	for _, xz in {{50, -6}, {50, 14}, {86, -6}, {86, 14}, {120, -6}, {120, 14}, {64, 50}, {100, 50}} do lamp(xz[1], xz[2]) end
	for _, x in {50, 86, 120} do bunting(Vector3.new(x, TOP + 7.4, -6), Vector3.new(x, TOP + 7.4, 14), 1.4) end
	bunting(Vector3.new(50, TOP + 7.4, 14), Vector3.new(86, TOP + 7.4, 14), 2)
	bunting(Vector3.new(86, TOP + 7.4, 14), Vector3.new(120, TOP + 7.4, 14), 2)
	bunting(Vector3.new(64, TOP + 7.4, 50), Vector3.new(100, TOP + 7.4, 50), 2.5)
	signpost(46, -8, WEST, "🎡 Festival Green", Color3.fromRGB(200, 120, 230))

	------------------------------------------------------------ 8. 🔨 craft corner (south-west)
	local _, forge = place("Forge", -58, 46, Vector3.new(8, 10, 9), EAST, {collide = true})
	local gf = root:FindFirstChild("GearForge")
	if gf then gf:Destroy() end
	gf = Instance.new("Model")
	gf.Name = "GearForge"
	local anvil = part(gf, {Name = "Anvil", Size = Vector3.new(3, 3, 5), Position = Vector3.new(-52.5, TOP + 1.5, 46), Transparency = 1, CanCollide = false})
	gf.PrimaryPart = anvil
	gf.Parent = root
	sign(forge or anvil, "🔨 Gear Forge", Color3.fromRGB(230, 120, 70), forge and 7.5 or 5, 200)
	local wb = root:FindFirstChild("Workbench")
	if wb and wb:FindFirstChild("Table") then sign(wb.Table, "🪚 Workbench", Color3.fromRGB(176, 122, 78), 6, 200) end
	place("Crates", -62, 57, Vector3.new(4.4, 5, 3.3), EAST, {collide = true})
	place("Crates", -40, 57, Vector3.new(4.4, 5, 3.3), WEST, {collide = true})
	lamp(-64, 38)
	signpost(-38, 38, EAST, "🔨 Craft Corner", Color3.fromRGB(176, 122, 78))

	------------------------------------------------------------ 9. 🌀 portal plaza (south)
	local _, arch = place("WelcomeArch", 4, 57, Vector3.new(20, 15, 4), SOUTH)
	if arch then sign(arch, "🌷 Welcome to Critter Acres! 🌷", Color3.fromRGB(120, 190, 110), 9, 320) end
	for _, xz in {{-13, 74}, {21, 74}} do place("Planter", xz[1], xz[2], Vector3.new(5, 2.6, 2), flat(Vector3.new(4 - xz[1], 0, 0))) end
	for _, xz in {{-10, 64}, {18, 64}} do lamp(xz[1], xz[2]) end
	for k = 0, 7 do
		local a = k * math.pi / 4 + 0.2
		local x, z = 4 + math.cos(a) * 19, 74 + math.sin(a) * 19
		if z > 60 then place("Flowers", x, z, Vector3.new(3.3, 2.5, 3.3), nil) end
	end

	------------------------------------------------------------ 10. 🌳 trees around the edges
	local trees = {{-60, -32}, {-86, -34}, {-116, -22}, {-116, 30}, {-82, 42}, {-104, 40}, {-74, 64}, {-26, 86}, {34, 86},
		{-38, -48}, {48, -48}, {136, -24}, {138, 22}, {136, 62}, {58, 74}, {108, 104}, {56, 102}, {-34, 66}}
	for i, xz in trees do
		local name = i % 3 == 0 and "TreeBlossom" or "TreeRound"
		place(name, xz[1], xz[2], name == "TreeRound" and Vector3.new(16, 22, 16) or Vector3.new(13, 14, 13), flat(Vector3.new(math.cos(i * 1.7), 0, math.sin(i * 1.7))),
			{collide = true})
	end

	local parts = {}
	for k, v in count do table.insert(parts, k .. " " .. v) end
	table.sort(parts)
	table.insert(out, "placed: " .. table.concat(parts, ", "))
	return table.concat(out, "\n")
end
