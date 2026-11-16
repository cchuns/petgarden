-- Critter Acres: one-time town dresser (Studio Edit mode). Same idea as DressIslands.lua:
-- cozy cartoon meshes (ServerStorage.IslandProps) go on top, the old block parts turn invisible but stay
-- (prompts, shopkeeper, leaderboards and collisions still use them). New things live in CritterAcres.TownDressing.
local root = workspace:WaitForChild("CritterAcres")
local PROPS = game:GetService("ServerStorage"):WaitForChild("IslandProps")

local function hasGui(p)
	for _, c in p:GetChildren() do
		if c:IsA("SurfaceGui") or c:IsA("Decal") or c:IsA("Texture") then return true end
	end
	return false
end
local function hide(p, keepCollide)
	if not p:IsA("BasePart") or hasGui(p) then return end
	if p:GetAttribute("DressHidden") == nil then p:SetAttribute("DressHidden", p.Transparency) end
	p.Transparency = 1
	if not keepCollide then p.CanCollide = false end
end
local function hideIn(m, keep)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and not d:FindFirstAncestor("Shopkeeper") and d.Name ~= "Board" then
			hide(d, keep and keep[d.Name])
		end
	end
end

local function place(parent, name, cf, size, floorY, opts)
	opts = opts or {}
	local m = PROPS[name]:Clone()
	local mp = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if size then mp.Size = size end
	mp.Anchored = true
	mp.CanCollide = opts.collide == true
	mp.CollisionFidelity = Enum.CollisionFidelity.Hull
	mp.CFrame = cf
	if floorY then
		local cfb, bs = m:GetBoundingBox()
		mp.CFrame += Vector3.new(0, floorY - (cfb.Y - bs.Y / 2), 0)
	end
	m.Parent = parent
	return m, mp
end

local function floorAt(x, z, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
	return hit and hit.Position.Y or 2.84
end
local function flatCF(part, x, z) -- the part's facing, but upright, at x/z (BuildTown sets a "Front" on things it moved)
	local holder = part
	while holder.Parent and holder.Parent ~= root do holder = holder.Parent end
	local look = holder:GetAttribute("Front") or part.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z).Unit
	return CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + look)
end
local function bottom(o)
	local y = math.huge
	for _, d in (o:IsA("BasePart") and {o} or o:GetDescendants()) do
		if d:IsA("BasePart") then y = math.min(y, d.Position.Y - d.Size.Y / 2) end
	end
	return y
end

return function()
	local old = root:FindFirstChild("TownDressing")
	if old then old:Destroy() end
	local D = Instance.new("Model")
	D.Name = "TownDressing"
	local out = {}
	local ignore = {D}
	for _, n in {"Decor", "Fence"} do if root:FindFirstChild(n) then table.insert(ignore, root[n]) end end

	-- 🌱 seed shop (shopkeeper and the counter prompt stay)
	local shop = root:FindFirstChild("SeedShop")
	if shop and shop:FindFirstChild("Counter") then
		local counter = shop.Counter
		local y = bottom(counter)
		hideIn(shop, {Counter = true})
		local keeper = shop:FindFirstChild("Shopkeeper")
		local front = counter.CFrame.LookVector
		if shop:GetAttribute("Front") then
			front = shop:GetAttribute("Front")
		elseif keeper then -- the stall faces away from the shopkeeper
			local k = keeper:GetPivot().Position
			front = Vector3.new(counter.Position.X - k.X, 0, counter.Position.Z - k.Z).Unit
		end
		local c = counter.Position - front * 2.5
		place(D, "SeedStall", CFrame.lookAt(Vector3.new(c.X, 0, c.Z), Vector3.new(c.X, 0, c.Z) + front), Vector3.new(17, 13, 9.5), y)
		table.insert(out, "seed shop")
	end
	-- 🔨 workbench
	local wb = root:FindFirstChild("Workbench")
	if wb and wb:FindFirstChild("Table") then
		local t = wb.Table
		local y = bottom(wb)
		hideIn(wb, {Table = true})
		place(D, "Workbench", flatCF(t, t.Position.X, t.Position.Z), Vector3.new(8.6, 6, 5), y, {collide = true})
		table.insert(out, "workbench")
	end
	-- 💰 sell stand
	local ss = root:FindFirstChild("SellStand")
	if ss and ss:FindFirstChild("Counter") then
		local c = ss.Counter
		local y = bottom(ss)
		local cf = ss:GetBoundingBox()
		hideIn(ss, {Counter = true})
		place(D, "FruitStall", flatCF(c, cf.X, cf.Z), Vector3.new(10.5, 8.6, 6), y)
		table.insert(out, "sell stand")
	end
	-- 💕 best friends nest (the old cauldron spot)
	local cau = root:FindFirstChild("Cauldron")
	if cau and cau:FindFirstChild("Pot") then
		local pot = cau.Pot
		local y = bottom(cau)
		hideIn(cau, {Pot = true})
		place(D, "HeartBed", flatCF(pot, pot.Position.X, pot.Position.Z), Vector3.new(8.5, 4.5, 8.2), y, {collide = true})
		table.insert(out, "nest")
	end
	-- 🗺️ expedition booth (the map board keeps its picture if it has one)
	local eb = root:FindFirstChild("ExpeditionBooth")
	if eb and eb:FindFirstChild("Counter") then
		local c = eb.Counter
		local y = bottom(eb)
		local cf = eb:GetBoundingBox()
		hideIn(eb, {Counter = true})
		place(D, "MapBooth", flatCF(c, cf.X, cf.Z), Vector3.new(10.5, 9.4, 7.6), y)
		table.insert(out, "expedition booth")
	end
	-- ⚔️ raid gate (the glowing portal and pedestal stay)
	local rg = root:FindFirstChild("RaidGate")
	if rg and rg:FindFirstChild("Portal") then
		local p = rg.Portal
		local y = bottom(rg)
		for _, d in rg:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "Portal" and d.Name ~= "Pedestal" and d.Material ~= Enum.Material.Neon then hide(d, true) end
		end
		place(D, "ArenaGate", flatCF(p, p.Position.X, p.Position.Z), Vector3.new(13, 13.5, 5), y)
		table.insert(out, "raid gate")
	end
	-- 🪧 the three boards: wooden posts and frames, the screens stay
	for _, n in {"LikeBoard", "RecordBoard", "NewsBoard"} do
		local b = root:FindFirstChild(n)
		if b then
			for _, d in (b:IsA("BasePart") and {b} or {}) do d.Material = Enum.Material.SmoothPlastic end
			for _, d in b:GetDescendants() do
				if d:IsA("BasePart") and not hasGui(d) then
					d.Material = Enum.Material.SmoothPlastic
					d.Color = Color3.fromRGB(176, 122, 78)
				end
			end
		end
	end

	-- 🌳 block trees and ball flowers → the cozy models
	local decor = root:FindFirstChild("Decor")
	local nTree, nFlower, nBush = 0, 0, 0
	if decor then
		local trunks, canopies, petals = {}, {}, {}
		for _, p in decor:GetChildren() do
			if p:IsA("BasePart") then
				if p.Shape == Enum.PartType.Cylinder and p.BrickColor.Name == "Brown" then table.insert(trunks, p)
				elseif p.Shape == Enum.PartType.Ball and p.Material == Enum.Material.Grass then table.insert(canopies, p)
				elseif p.Shape == Enum.PartType.Ball then table.insert(petals, p) end
			end
		end
		for i, t in trunks do
			local y = t.Position.Y - t.Size.X / 2
			local bigC = 8
			for _, c in canopies do
				if (Vector3.new(c.Position.X, 0, c.Position.Z) - Vector3.new(t.Position.X, 0, t.Position.Z)).Magnitude < 3 then bigC = c.Size.X end
			end
			local s = bigC / 8
			local name = i % 3 == 0 and "TreeBlossom" or "TreeRound"
			local size = name == "TreeRound" and Vector3.new(16, 22, 16) or Vector3.new(13, 14, 13)
			place(D, name, CFrame.new(t.Position.X, 0, t.Position.Z) * CFrame.Angles(0, i * 1.7, 0), size * math.clamp(s, 0.8, 1.25), floorAt(t.Position.X, t.Position.Z, ignore), {collide = true})
			nTree += 1
		end
		for _, c in canopies do
			local near = false
			for _, t in trunks do
				if (Vector3.new(c.Position.X, 0, c.Position.Z) - Vector3.new(t.Position.X, 0, t.Position.Z)).Magnitude < 3 then near = true end
			end
			if not near then -- a lone green ball = a bush
				place(D, "Bush", CFrame.new(c.Position.X, 0, c.Position.Z), Vector3.new(5.6, 4, 5.7) * math.clamp(c.Size.X / 4, 0.7, 1.4), floorAt(c.Position.X, c.Position.Z, ignore))
				nBush += 1
			end
		end
		local used = {}
		for i, p in petals do
			if not used[i] then
				local sum, n = p.Position, 1
				for j = i + 1, #petals do
					if not used[j] and (petals[j].Position - p.Position).Magnitude < 3 then
						used[j] = true
						sum += petals[j].Position
						n += 1
					end
				end
				local c = sum / n
				place(D, "Flowers", CFrame.new(c.X, 0, c.Z) * CFrame.Angles(0, i, 0), Vector3.new(3, 2.3, 3) * 1.1, floorAt(c.X, c.Z, ignore))
				nFlower += 1
			end
		end
		hideIn(decor)
	end
	table.insert(out, ("trees %d, bushes %d, flowers %d"):format(nTree, nBush, nFlower))

	-- 🪵 the old plaza fence goes away: the town is open now (BuildTown adds the streets, lamps and districts)
	local fence = root:FindFirstChild("Fence")
	if fence then
		for _, p in fence:GetDescendants() do hide(p) end
	end

	-- ⛲ the town square floor: warm paving stones
	local sq = root:FindFirstChild("FarmGround")
	if sq then
		sq.Material = Enum.Material.Pavement
		sq.Color = Color3.fromRGB(196, 170, 132)
	end
	D.Parent = root
	return table.concat(out, "\n")
end
