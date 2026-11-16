-- Critter Acres: one-time island dresser (Studio Edit mode).
-- Swaps the block-built farm props for the cozy cartoon meshes in ServerStorage.IslandProps.
-- The old parts stay (the scripts use them for prompts, pet spots and plots) but turn invisible.
-- Everything new goes in Islands/Island_FarmX/Dressing, so running it again rebuilds cleanly.
local root = workspace:WaitForChild("CritterAcres")
local PROPS = game:GetService("ServerStorage"):WaitForChild("IslandProps")

local function hide(p, keepCollide)
	if not p:IsA("BasePart") then return end
	if p:GetAttribute("DressHidden") == nil then p:SetAttribute("DressHidden", p.Transparency) end
	p.Transparency = 1
	if not keepCollide then p.CanCollide = false end
end
local function hideAll(m, keepCollide)
	if m:IsA("BasePart") then hide(m, keepCollide) end
	for _, d in m:GetDescendants() do hide(d, keepCollide) end
end

-- clone a prop, size its mesh, sit its bottom at `floorY`, centered on cf
local function place(parent, name, cf, size, floorY, opts)
	opts = opts or {}
	local m = PROPS[name]:Clone()
	local mp = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if size then mp.Size = size end
	mp.Anchored = true
	mp.CanCollide = opts.collide ~= false
	mp.CollisionFidelity = opts.fidelity or Enum.CollisionFidelity.Box
	mp.CastShadow = true
	mp.CFrame = cf
	if floorY then
		local _, bs = m:GetBoundingBox()
		local cfb = m:GetBoundingBox()
		mp.CFrame = mp.CFrame + Vector3.new(0, floorY - (cfb.Y - bs.Y / 2), 0)
	end
	m.Parent = parent
	return m, mp
end

local WOOD, WOOD_DK = Color3.fromRGB(176, 122, 78), Color3.fromRGB(130, 86, 54)
local function P(parent, props)
	local p = Instance.new("Part")
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end

local function dressFarm(farm, island)
	local g = farm:FindFirstChild("Ground")
	if not g then return "no ground" end
	local old = island:FindFirstChild("Dressing")
	if old then old:Destroy() end
	local D = Instance.new("Model")
	D.Name = "Dressing"
	local gcf = g.CFrame -- farm frame: front (gate side) is -Z
	local floor = g.Position.Y + g.Size.Y / 2 -- farm ground top
	local function at(x, z, yaw) return gcf * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw or 0, 0) end
	local count = 0

	-- 🏠 pet hut
	local hut = farm:FindFirstChild("Hut")
	if hut then
		local cf, s = hut:GetBoundingBox()
		hideAll(hut)
		local r = gcf:PointToObjectSpace(cf.Position)
		place(D, "PetHouse", at(r.X, r.Z), Vector3.new(10.5, 9.6, 8.3), floor)
		count += 1
	end
	-- 🪑 bench
	local bench = farm:FindFirstChild("Bench")
	if bench then
		local cf = bench:GetBoundingBox()
		hideAll(bench)
		local r = gcf:PointToObjectSpace(cf.Position)
		place(D, "Bench", at(r.X, r.Z), Vector3.new(8, 4.2, 3), floor)
		count += 1
	end
	-- 🥚 nest: a woven basket around the eggs (eggs stay)
	local nest = farm:FindFirstChild("Nest")
	if nest then
		for _, p in nest:GetChildren() do
			if p:IsA("BasePart") and not p.Name:match("^Egg") then hide(p) end
		end
		local base = nest:FindFirstChild("Base")
		local r = gcf:PointToObjectSpace((base or nest.PrimaryPart or nest:GetBoundingBox()).Position)
		place(D, "Nest", at(r.X, r.Z), Vector3.new(7.6, 1.9, 7.6), floor)
		count += 1
	end
	-- 🛒 sell cart (the old bin stays as the invisible prompt)
	local bin = farm:FindFirstChild("SellBin")
	if bin then
		hide(bin, true)
		local lid = farm:FindFirstChild("Part")
		if lid then hide(lid) end
		local r = gcf:PointToObjectSpace(bin.Position)
		place(D, "Cart", at(r.X + 0.9, r.Z), Vector3.new(4.4, 4.8, 4.2), floor) -- (nudged away from the mailbox)
		count += 1
	end
	-- 🪵 picket fence pieces along every fence plank (planks stay as invisible walls)
	for _, f in farm:GetChildren() do
		if f.Name == "Fence" and f:IsA("BasePart") then
			hide(f, true)
			local long = math.max(f.Size.X, f.Size.Z)
			local rot = f.Size.X >= f.Size.Z and f.CFrame or f.CFrame * CFrame.Angles(0, math.pi / 2, 0)
			local n = math.max(1, math.round(long / 3.6))
			local w = long / n
			for k = 1, n do
				local off = -long / 2 + w * (k - 0.5)
				place(D, "Fence", rot * CFrame.new(off, 0, 0), Vector3.new(w + 0.05, 2.8, 0.45), floor)
				count += 1
			end
		end
	end
	-- 🌸 gate arch over the entrance + the name sign floats above it
	local posts = {}
	for _, f in farm:GetChildren() do if f.Name == "GatePost" then table.insert(posts, f) end end
	if #posts == 2 then
		local mid = (posts[1].Position + posts[2].Position) / 2
		local width = (posts[1].Position - posts[2].Position).Magnitude + 2.4
		for _, p in posts do hide(p) end
		local top = farm:FindFirstChild("GateTop")
		if top then hide(top) end
		local r = gcf:PointToObjectSpace(mid)
		place(D, "GateArch", at(r.X, r.Z), Vector3.new(width, 7.6, 2.2), floor, {fidelity = Enum.CollisionFidelity.Hull})
		count += 1
	end
	local sign = farm:FindFirstChild("OwnerSign")
	if sign then hide(sign) end -- (its name tag is a billboard: it still shows)
	local isTop = island:FindFirstChild("Top")
	place(D, "Signboard", at(15, -30, 0), Vector3.new(6.5, 5.5, 1.1), isTop and (isTop.Position.Y + isTop.Size.X / 2) or floor)
	-- 🌱 wooden frames around every plot
	local plots = farm:FindFirstChild("Plots")
	for _, plot in plots and plots:GetChildren() or {} do
		if plot:IsA("BasePart") then
			local s = plot.Size
			local cf = CFrame.new(plot.Position.X, floor, plot.Position.Z) * (gcf - gcf.Position)
			local h = 1.5
			for _, side in {{0, s.Z / 2 + 0.3, s.X + 1.2, 0.6}, {0, -s.Z / 2 - 0.3, s.X + 1.2, 0.6}, {s.X / 2 + 0.3, 0, 0.6, s.Z}, {-s.X / 2 - 0.3, 0, 0.6, s.Z}} do
				P(D, {Name = "Bed", Size = Vector3.new(side[3], h, side[4]), CFrame = cf * CFrame.new(side[1], h / 2, side[2]), Color = WOOD, CanCollide = false})
			end
			for _, c in {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}} do
				P(D, {Name = "BedPost", Size = Vector3.new(0.8, h + 0.3, 0.8), CFrame = cf * CFrame.new(c[1] * (s.X / 2 + 0.3), (h + 0.3) / 2, c[2] * (s.Z / 2 + 0.3)),
					Color = WOOD_DK, CanCollide = false})
			end
			count += 1
		end
	end
	local rng = Random.new(#farm.Name * 31 + string.byte(farm.Name, -1))
	-- 🏝️ island: softer colors, chunky rock underside instead of stacked cylinders
	local topPart = island:FindFirstChild("Top")
	local center = topPart and topPart.Position or g.Position
	local islandTop = topPart and (topPart.Position.Y + topPart.Size.X / 2) or floor
	if topPart then
		topPart.Material = Enum.Material.SmoothPlastic
		topPart.Color = Color3.fromRGB(126, 204, 96)
	end
	local dirt = island:FindFirstChild("Dirt")
	if dirt then
		dirt.Material = Enum.Material.SmoothPlastic
		dirt.Color = Color3.fromRGB(150, 108, 72)
	end
	for _, p in island:GetChildren() do
		if p.Name:match("^Rock%d") then hide(p) end
		if p.Name == "Pebble" then p.Material = Enum.Material.SmoothPlastic p.Color = Color3.fromRGB(150, 145, 160) end
	end
	local under = islandTop - 14
	local function underRock(x, z, w, h)
		local m, mp = place(D, "UnderRock", CFrame.new(center.X + x, 0, center.Z + z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Vector3.new(w, h, w), nil,
			{collide = false})
		local cf, s = m:GetBoundingBox()
		mp.CFrame += Vector3.new(0, under + 1 - (cf.Y + s.Y / 2), 0) -- its top tucks under the dirt layer
	end
	underRock(0, 0, 165, 80)
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local d = rng:NextNumber(48, 66)
		underRock(math.cos(a) * d, math.sin(a) * d, rng:NextNumber(42, 60), rng:NextNumber(26, 40))
	end
	count += 7

	-- 🪨 stepping-stone path from the gate out to the portal
	for k = 0, 9 do
		local z = -29 - k * 3.6
		local x = math.sin(k * 0.9) * 1.6
		P(D, {Name = "Stone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, rng:NextNumber(3, 3.8), rng:NextNumber(3, 3.8)),
			CFrame = at(x, z) * CFrame.new(0, islandTop + 0.15 - g.Position.Y, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(196, 190, 205), CanCollide = false})
	end

	-- 🌳 nature around the farm (not on the front path to the portal)
	local front = gcf:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local frontAng = math.atan2(front.Z, front.X)
	local function freeSpot(rMin, rMax)
		for _ = 1, 30 do
			local a = rng:NextNumber(0, math.pi * 2)
			local da = math.abs((a - frontAng + math.pi) % (math.pi * 2) - math.pi)
			local d = rng:NextNumber(rMin, rMax)
			local p = Vector3.new(g.Position.X + math.cos(a) * d, 0, g.Position.Z + math.sin(a) * d)
			local rel = gcf:PointToObjectSpace(Vector3.new(p.X, g.Position.Y, p.Z))
			local insideFarm = math.abs(rel.X) < 33 and math.abs(rel.Z) < 33
			if da > 0.5 and not insideFarm and (Vector3.new(p.X, 0, p.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude < 84 then return p end
		end
	end
	local function scatter(name, n, size, rMin, rMax, collide)
		for _ = 1, n do
			local p = freeSpot(rMin, rMax)
			if p then
				local s = rng:NextNumber(0.8, 1.2)
				place(D, name, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), size * s, islandTop,
					{collide = collide, fidelity = Enum.CollisionFidelity.Hull})
				count += 1
			end
		end
	end
	scatter("TreeRound", 5, Vector3.new(18, 21.7, 16.8), 46, 80, true)
	scatter("TreeBlossom", 4, Vector3.new(14, 15.1, 12.5), 42, 80, true)
	scatter("Bush", 12, Vector3.new(5.6, 4, 5.7), 36, 86, false)
	scatter("Rocks", 6, Vector3.new(4.8, 4, 4.5), 36, 86, true)
	scatter("Flowers", 20, Vector3.new(2.9, 2.5, 2.9), 34, 86, false)
	-- flower clumps along the front path
	for k = 1, 6 do
		local side = k % 2 == 0 and 1 or -1
		place(D, "Flowers", at(side * rng:NextNumber(4, 6), -31 - k * 5.5, rng:NextNumber(0, 6.28)), Vector3.new(2.9, 2.5, 2.9) * rng:NextNumber(0.8, 1.1), islandTop,
			{collide = false})
		count += 1
	end
	D.Parent = island
	return ("%s: %d props"):format(farm.Name, count)
end

local function dressPortals()
	local n = 0
	for _, m in (root:FindFirstChild("Portals") or Instance.new("Folder")):GetChildren() do
		local old = m:FindFirstChild("Arch")
		if old then old:Destroy() end
		local base = m:FindFirstChild("Base")
		if base then
			for _, p in m:GetChildren() do
				if p.Name == "Base" or p.Name == "Pillar" or p.Name == "Cap" or p.Name == "Top" then hide(p) end
			end
			local arch, mp = place(m, "PortalArch", base.CFrame * CFrame.new(0, 0, 0), Vector3.new(19.5, 20.5, 5), base.Position.Y - base.Size.Y / 2,
				{fidelity = Enum.CollisionFidelity.Hull})
			arch.Name = "Arch"
			n += 1
		end
	end
	return ("portals: %d arches"):format(n)
end

return function()
	local out = {}
	for _, farm in root.Farms:GetChildren() do
		local island = root.Islands:FindFirstChild("Island_" .. farm.Name)
		if island then table.insert(out, dressFarm(farm, island)) end
		task.wait()
	end
	table.insert(out, dressPortals())
	return table.concat(out, "\n")
end
