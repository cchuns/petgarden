-- Critter Acres: town builder v2 (Studio Edit mode, one-time). Cozy riverside town:
--   🌊 Willow Creek (terrain water) wraps the west and south; part-built bridges cross it
--   ⛲ Town park in the middle (pond, gazebo, fountain, boards, Farmer Fern, spawn) inside a ring road
--   🏪 Market street (west): walk-in shoplots (Seeds & Eggs, Boutique, Bakery | Market Hall, Explorer's Lodge, a spare lot)
--   🔨 Smithy (south-west, workbench + gear forge) · 🌀 portal plaza on the south road · 🏡 cottages
--   🎡 Festival Green (east): carousel, stage (Data.StagePos), booths, nest tent, playground
--   🌳 one hedge network along the streets and around town (openings only at entrances), lots of nature
--   🌀 hedge nooks around every portal · signs: hanging blade signs + floating icon chips (CritterWorld animates them)
-- Run with: loadstring(GetAsync(".../BuildTownV2.lua"))()(step)
--   steps in order: clear, terrain, roads, move, shops, park, festival, cottages, hedges, nature, nooks, chips
local root = workspace:WaitForChild("CritterAcres")
local PROPS = game:GetService("ServerStorage"):WaitForChild("IslandProps")
local Terrain = workspace.Terrain

local G = 2.84 -- town ground height (floors and roads sit here)
local ROAD = 2.87
local CX, CZ = 4, 13 -- town centre (the park)
local RING_IN, RING_OUT = 32, 42
local PARK_R = 29.5
local N, S, E, W = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0)
local STONE = Color3.fromRGB(196, 170, 132)
local RIVER = {{-178, -105}, {-175, -40}, {-172, 13}, {-166, 90}, {-142, 170}, {-92, 230}, {-24, 260}, {4, 265}, {60, 261},
	{130, 246}, {190, 252}, {250, 272}}
local BRIDGE_W, BRIDGE_S = Vector3.new(-172, 0, 13), Vector3.new(4, 0, 265)

---------------------------------------------------------------- helpers
local function P(parent, props)
	local p = Instance.new(props.Wedge and "WedgePart" or "Part")
	props.Wedge = nil
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end
local function folder(parent, name, fresh)
	local f = parent:FindFirstChild(name)
	if f and fresh then f:Destroy() f = nil end
	if not f then
		f = Instance.new(name == "TownDressing" and "Model" or "Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end
local function flat(v) return Vector3.new(v.X, 0, v.Z).Unit end
local function yaw(v) return math.atan2(-v.X, -v.Z) end
local function V(t) return Vector3.new(t[1], 0, t[2]) end
local rng = Random.new(2611)
local function J(a) return rng:NextNumber(-a, a) end

local function D() return folder(root, "TownDressing") end
local function sub(name) return folder(D(), name) end

-- ground under a spot (terrain, roads, the meadow, islands...), ignoring props and buildings
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local function refreshParams()
	local list = {D()}
	for _, n in {"TownBuildings", "Helpers", "Critters", "TownChips", "Portals", "Acorns", "Playground", "Decor", "Fence", "SeedShop", "SellStand",
		"ExpeditionBooth", "RaidGate", "Workbench", "Cauldron", "LikeBoard", "RecordBoard", "NewsBoard", "Boutique", "GearForge", "Spawn"} do
		if root:FindFirstChild(n) then table.insert(list, root[n]) end
	end
	groundParams.FilterDescendantsInstances = list
end
-- the town lawn is terrain at a known height; terrain collision can be stale in Edit mode, so it isn't ray-tested
local LAWN = 2.72
local function inLawn(x, z)
	return (x > -192 and x < 188 and z > -30 and z < 300) or (x >= 188 and x < 260 and z > 140 and z < 300)
		or (x > -192 and x < -104 and z > -40 and z <= -30) or (x > 116 and x < 188 and z > -40 and z <= -30) or (x > -192 and x < -110 and z > -112 and z <= -40)
end
local function groundY(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -240, 0), groundParams)
	if hit and hit.Instance == Terrain then
		if inLawn(x, z) then return LAWN, nil end
		return hit.Position.Y, hit
	end
	if hit and hit.Position.Y > 1 then return hit.Position.Y, hit end
	if inLawn(x, z) then return LAWN, nil end
	return hit and hit.Position.Y or G, hit
end

-- clone a prop: size = exact box, or scale = uniform; front = facing; opts: y (bottom height), collide, parent, yaw
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
	mp.CanQuery = opts.collide == true
	mp.CollisionFidelity = Enum.CollisionFidelity.Hull
	local pos = Vector3.new(x, 0, z)
	local cf = front and CFrame.lookAt(pos, pos + front) or CFrame.new(pos) * CFrame.Angles(0, opts.yaw or rng:NextNumber(0, 6.28), 0)
	mp.CFrame = cf
	local cfb, bs = m:GetBoundingBox()
	mp.CFrame += Vector3.new(0, (opts.y or groundY(x, z)) - (cfb.Y - bs.Y / 2) - (opts.sink or 0), 0)
	m.Parent = opts.parent or D()
	count[name] = (count[name] or 0) + 1
	return m, mp
end

-- is this spot free of buildings, roads and big things?
local freeParams = OverlapParams.new()
freeParams.FilterType = Enum.RaycastFilterType.Include
local function refreshFree()
	local list = {}
	for _, n in {"TownBuildings", "Playground", "Portals"} do
		if root:FindFirstChild(n) then table.insert(list, root[n]) end
	end
	local tf = root:FindFirstChild("Paths") and root.Paths:FindFirstChild("TownFloor")
	if tf then table.insert(list, tf) end
	for _, n in {"Hedges", "Big"} do
		if D():FindFirstChild(n) then table.insert(list, D()[n]) end
	end
	freeParams.FilterDescendantsInstances = list
end
local function free(x, z, r)
	local y = groundY(x, z)
	return #workspace:GetPartBoundsInRadius(Vector3.new(x, y + 3, z), r, freeParams) == 0
end

-- the river's middle line, every `step` studs
local function riverLine(step)
	local pts = {}
	local function cm(p0, p1, p2, p3, t)
		local t2, t3 = t * t, t * t * t
		return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
	end
	for i = 1, #RIVER - 1 do
		local p0, p1, p2, p3 = V(RIVER[math.max(1, i - 1)]), V(RIVER[i]), V(RIVER[i + 1]), V(RIVER[math.min(#RIVER, i + 2)])
		local n = math.ceil((p2 - p1).Magnitude / step)
		for k = 0, n - 1 do table.insert(pts, cm(p0, p1, p2, p3, k / n)) end
	end
	table.insert(pts, V(RIVER[#RIVER]))
	return pts
end

-- moves a working model so `key` lands on `target`, turned to face `newFront`
local function moveKey(o, key, target, newFront)
	local oldFront = o:GetAttribute("Front") or flat(key.CFrame.LookVector)
	local kp = key.Position
	local T = CFrame.new(target) * CFrame.Angles(0, yaw(newFront) - yaw(oldFront), 0) * CFrame.new(-kp)
	local function apply(inst)
		if inst:IsA("Model") then inst:PivotTo(T * inst:GetPivot()) return end
		if inst:IsA("BasePart") then inst.CFrame = T * inst.CFrame end
		for _, ch in inst:GetChildren() do apply(ch) end
	end
	apply(o)
	o:SetAttribute("Front", newFront)
end
local function noBubbles(o)
	for _, d in o:GetDescendants() do
		if d:IsA("BillboardGui") then d.Enabled = false end
	end
end
local function chip(pos, icon, label)
	local f = folder(root, "TownChips")
	for _, c in f:GetChildren() do
		if c:GetAttribute("Label") == label and (c.Position - pos).Magnitude < 40 then c:Destroy() end
	end
	local p = P(f, {Name = "Chip", Size = Vector3.one * 0.5, Position = pos, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
	p:SetAttribute("Icon", icon)
	p:SetAttribute("Label", label)
	return p
end
local function lamp(x, z, parent)
	local _, mp = place("LampPost", x, z, Vector3.new(2.2, 8.5, 2.2), nil, {collide = true, parent = parent or sub("Lamps"), yaw = 0})
	if mp then
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = Color3.fromRGB(255, 205, 140), 18, 1.2
		l.Parent = mp
	end
end

---------------------------------------------------------------- 🏠 buildings from parts
-- cfg: x, z, front, W, D, H1 (stone), H2 (plaster), R (roof rise), roof, kind = "shop" | "hall" | "smithy" | "cottage"
local WOOD, DARK, PLASTER, STONEW = Color3.fromRGB(150, 108, 70), Color3.fromRGB(107, 74, 46), Color3.fromRGB(241, 230, 204), Color3.fromRGB(176, 170, 160)
local function building(parent, cfg)
	local m = Instance.new("Model")
	m.Name = cfg.Name or "Building"
	local base = Vector3.new(cfg.x, cfg.y or G, cfg.z)
	local CF = CFrame.lookAt(base, base + cfg.front)
	local Wd, Dp, H1, H2, R = cfg.W, cfg.D, cfg.H1, cfg.H2 or 0, cfg.R
	local function at(x, y, z) return CF * CFrame.new(x, y, z) end
	local function part(size, cf, color, mat, extra)
		local props = {Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.SmoothPlastic}
		for k, v in extra or {} do props[k] = v end
		return P(m, props)
	end
	local open = cfg.kind == "hall" or cfg.kind == "smithy"
	-- floor: stone tiles in shops, planks in cottages; thick so no grass ever shows through
	if cfg.kind == "cottage" then
		part(Vector3.new(Wd, 0.4, Dp), at(0, 0.2, 0), WOOD, Enum.Material.WoodPlanks)
	else
		part(Vector3.new(Wd, 1.6, Dp), at(0, -0.4, 0), Color3.fromRGB(196, 186, 170), Enum.Material.Slate)
	end
	local y0 = 0.4
	-- lower stone storey
	if cfg.kind == "hall" then
		for _, x in {-Wd / 2 + 0.8, 0, Wd / 2 - 0.8} do
			for _, z in {-Dp / 2 + 0.8, Dp / 2 - 0.8} do
				part(Vector3.new(1.6, H1, 1.6), at(x, y0 + H1 / 2, z), STONEW, Enum.Material.Cobblestone)
			end
		end
		part(Vector3.new(Wd, 0.8, Dp), at(0, y0 + H1 + 0.4, 0), DARK, Enum.Material.Wood)
	else
		part(Vector3.new(Wd, H1, 1), at(0, y0 + H1 / 2, Dp / 2 - 0.5), STONEW, Enum.Material.Cobblestone) -- back
		for _, sx in {-1, 1} do
			part(Vector3.new(1, H1, Dp - 2), at(sx * (Wd / 2 - 0.5), y0 + H1 / 2, 0), STONEW, Enum.Material.Cobblestone)
		end
		if cfg.kind ~= "smithy" then
			local dw = cfg.kind == "cottage" and 3.4 or 5
			local dh = math.min(H1 - 0.6, 6.2)
			local side = (Wd - dw) / 2
			for _, sx in {-1, 1} do
				local cx = sx * (dw / 2 + side / 2)
				if cfg.cozy then -- a real display window hole (glass and goods go in later)
					local ww, wy0, wy1 = side - 2.4, 1.1, 5.9
					part(Vector3.new(side, wy0, 1), at(cx, y0 + wy0 / 2, -Dp / 2 + 0.5), STONEW, Enum.Material.Cobblestone)
					part(Vector3.new(side, H1 - wy1, 1), at(cx, y0 + wy1 + (H1 - wy1) / 2, -Dp / 2 + 0.5), STONEW, Enum.Material.Cobblestone)
					for _, ex in {-1, 1} do
						part(Vector3.new((side - ww) / 2, wy1 - wy0, 1), at(cx + ex * (ww / 2 + (side - ww) / 4), y0 + (wy0 + wy1) / 2, -Dp / 2 + 0.5), STONEW,
							Enum.Material.Cobblestone)
					end
				else
					part(Vector3.new(side, H1, 1), at(cx, y0 + H1 / 2, -Dp / 2 + 0.5), STONEW, Enum.Material.Cobblestone)
				end
			end
			part(Vector3.new(dw, H1 - dh, 1), at(0, y0 + dh + (H1 - dh) / 2, -Dp / 2 + 0.5), STONEW, Enum.Material.Cobblestone)
			if cfg.kind == "cottage" then -- a closed door
				part(Vector3.new(dw, dh, 0.4), at(0, y0 + dh / 2, -Dp / 2 + 0.6), DARK, Enum.Material.Wood)
			else -- an open door, swung inside
				part(Vector3.new(0.3, dh, dw - 0.2), at(dw / 2 - 0.2, y0 + dh / 2, -Dp / 2 + dw / 2 + 0.9), DARK, Enum.Material.Wood)
			end
			-- front windows with flower boxes (cozy shops get big display windows instead)
			for _, sx in (cfg.cozy and {} or {-1, 1}) do
				local wx = sx * (dw / 2 + side / 2)
				local ww = math.min(3.4, side - 1.6)
				part(Vector3.new(ww, 2.4, 0.3), at(wx, y0 + 3.6, -Dp / 2 - 0.05), Color3.fromRGB(190, 225, 240), Enum.Material.Glass, {Transparency = 0.25})
				part(Vector3.new(ww + 0.6, 0.3, 0.7), at(wx, y0 + 2.3, -Dp / 2 - 0.2), DARK, Enum.Material.Wood)
				part(Vector3.new(ww + 0.4, 0.3, 0.5), at(wx, y0 + 4.95, -Dp / 2 - 0.1), DARK, Enum.Material.Wood)
				local box = PROPS:FindFirstChild("WindowBox")
				if box then
					local b = box:Clone()
					local bp = b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart", true)
					bp.Size = Vector3.new(ww + 0.4, 1.2, 1)
					bp.Anchored, bp.CanCollide = true, false
					bp.CFrame = at(wx, y0 + 1.6, -Dp / 2 - 0.75)
					b.Parent = m
				end
			end
		end
	end
	-- upper plaster storey with timber beams
	local top = y0 + H1
	if cfg.kind ~= "hall" and H2 > 0 then
		part(Vector3.new(Wd, 0.6, Dp), at(0, top + 0.3, 0), DARK, Enum.Material.Wood) -- the beam band / inside ceiling
		local y1 = top + 0.6
		part(Vector3.new(Wd, H2, 1), at(0, y1 + H2 / 2, -Dp / 2 + 0.5), PLASTER)
		part(Vector3.new(Wd, H2, 1), at(0, y1 + H2 / 2, Dp / 2 - 0.5), PLASTER)
		for _, sx in {-1, 1} do part(Vector3.new(1, H2, Dp - 2), at(sx * (Wd / 2 - 0.5), y1 + H2 / 2, 0), PLASTER) end
		for _, zs in {-1, 1} do
			for k = 0, 4 do
				local x = -Wd / 2 + 0.3 + k * (Wd - 0.6) / 4
				part(Vector3.new(0.5, H2, 0.3), at(x, y1 + H2 / 2, zs * (Dp / 2 + 0.05)), DARK, Enum.Material.Wood)
			end
			part(Vector3.new(Wd + 0.2, 0.4, 0.3), at(0, y1 + H2 - 0.2, zs * (Dp / 2 + 0.05)), DARK, Enum.Material.Wood)
		end
		for _, sx in {-1, 1} do -- upstairs windows
			part(Vector3.new(2.6, 2, 0.3), at(sx * Wd / 4 - sx * (Wd / 8), y1 + H2 / 2, -Dp / 2 - 0.12), Color3.fromRGB(190, 225, 240), Enum.Material.Glass,
				{Transparency = 0.25})
		end
		top = y1 + H2
	elseif cfg.kind ~= "hall" then
		part(Vector3.new(Wd, 0.6, Dp), at(0, top + 0.3, 0), DARK, Enum.Material.Wood)
		top += 0.6
	end
	-- gable roof (ridge runs left-right)
	local hd = Dp / 2 + 1
	local a = math.atan(R / hd)
	local L = math.sqrt(hd * hd + R * R) + 0.6
	for _, zs in {-1, 1} do
		part(Vector3.new(Wd + 2, 0.7, L), at(0, top + R / 2 + 0.3, zs * hd / 2) * CFrame.Angles(zs == -1 and -a or a, 0, 0),
			cfg.roof, Enum.Material.Slate)
	end
	part(Vector3.new(Wd + 2.2, 0.6, 1), at(0, top + R + 0.4, 0), cfg.roof:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Slate)
	if cfg.kind ~= "hall" then -- gable ends
		for _, sx in {-1, 1} do
			part(Vector3.new(1, R, Dp / 2), at(sx * (Wd / 2 - 0.5), top + R / 2, -Dp / 4), cfg.kind == "smithy" and STONEW or PLASTER, nil, {Wedge = true})
			part(Vector3.new(1, R, Dp / 2), at(sx * (Wd / 2 - 0.5), top + R / 2, Dp / 4) * CFrame.Angles(0, math.pi, 0), cfg.kind == "smithy" and STONEW or PLASTER,
				nil, {Wedge = true})
		end
	end
	-- chimney
	local big = cfg.kind == "smithy"
	part(Vector3.new(big and 3.4 or 2.2, R + (big and 6 or 3.5), big and 3.4 or 2.2), at(Wd / 2 - 3.5, top + (R + (big and 6 or 3.5)) / 2, Dp / 4), STONEW,
		Enum.Material.Cobblestone)
	-- a warm lantern inside
	if cfg.kind ~= "cottage" then
		local lan = part(Vector3.new(0.9, 1.1, 0.9), at(0, y0 + (cfg.kind == "hall" and H1 - 1 or H1 - 1.2), 0), Color3.fromRGB(255, 214, 140), Enum.Material.Neon,
			{CanCollide = false})
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = Color3.fromRGB(255, 205, 140), 20, 1.3
		l.Parent = lan
	end
	m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
	m:SetAttribute("Front", cfg.front)
	m.Parent = parent
	return m, CF, top
end

-- 🪧 hanging blade sign on an iron bracket beside the door (readable from the street both ways)
local function bladeSign(m, CF, cfg, word, color)
	local Dp = cfg.D
	local function at(x, y, z) return CF * CFrame.new(x, y, z) end
	local iron = Color3.fromRGB(45, 42, 40)
	local x = cfg.cozy and (cfg.W / 2 - 0.8) or 4.6 -- cozy shops: at the corner, clear of the awning
	local by = cfg.cozy and 10.4 or 8.6
	P(m, {Name = "Bracket", Size = Vector3.new(0.25, 0.25, 3.4), CFrame = at(x, by, -Dp / 2 - 1.7), Color = iron, Material = Enum.Material.Metal, CanCollide = false})
	for _, dz in {-0.9, 0.9} do
		P(m, {Size = Vector3.new(0.08, 0.6, 0.08), CFrame = at(x, by - 0.4, -Dp / 2 - 2.2 + dz), Color = iron, Material = Enum.Material.Metal, CanCollide = false})
	end
	local board = P(m, {Name = "Sign", Size = Vector3.new(0.25, 2.8, 3), CFrame = at(x, by - 2.1, -Dp / 2 - 2.2), Color = color, Material = Enum.Material.Wood, CanCollide = false})
	for _, face in {Enum.NormalId.Left, Enum.NormalId.Right} do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 70
		sg.LightInfluence = 0.2
		sg.MaxDistance = 140
		local fr = Instance.new("Frame")
		fr.BackgroundTransparency = 1
		fr.AnchorPoint = Vector2.new(0.5, 0.5)
		fr.Position = UDim2.fromScale(0.5, 0.5)
		fr.Size = UDim2.new(1, -16, 1, -16)
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(244, 238, 220)
		st.Thickness = 3
		st.Transparency = 0.4
		st.Parent = fr
		Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 8)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.BuilderSansBold
		t.Text = word
		t.TextColor3 = Color3.fromRGB(244, 238, 220)
		t.TextScaled = true
		local pad = Instance.new("UIPadding", t)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
		Instance.new("UITextSizeConstraint", t).MaxTextSize = 44
		t.Parent = fr
		fr.Parent = sg
		sg.Parent = board
	end
end

-- 🏡 storybook dressing for a shop: shingles, dormer, chimney smoke, timber X-beams, shutters, flower boxes,
-- a striped scalloped awning, display windows with goods, a door lantern, rough stones and corner quoins, a potted plant
local function cozy(m, CF, cfg)
	local Wd, Dp, H1, H2, R = cfg.W, cfg.D, cfg.H1, cfg.H2 or 0, cfg.R
	local y0 = 0.4
	local top = y0 + H1 + 0.6 + (cfg.kind ~= "hall" and H2 or 0)
	if cfg.kind == "hall" then top = y0 + H1 end
	local fz = -Dp / 2
	local accent = cfg.sign
	local light = accent:Lerp(Color3.new(1, 1, 1), 0.35)
	local function at(x, y, z) return CF * CFrame.new(x, y, z) end
	local function part(size, cf, color, mat, extra)
		local props = {Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.SmoothPlastic}
		for k, v in extra or {} do props[k] = v end
		return P(m, props)
	end
	local NOHIT = {CanCollide = false, CanQuery = false, CanTouch = false}
	-- roof: shingle rows on both sides and a dormer on the front
	local hd = Dp / 2 + 1
	local a = math.atan(R / hd)
	local L = math.sqrt(hd * hd + R * R) + 0.6
	for _, zs in {-1, 1} do
		local slab = at(0, top + R / 2 + 0.3, zs * hd / 2) * CFrame.Angles(zs == -1 and -a or a, 0, 0)
		for k = 1, 6 do
			part(Vector3.new(Wd + 2.1, 0.2, 0.55), slab * CFrame.new(0, 0.44, -L / 2 + k * L / 7), cfg.roof:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Slate, NOHIT)
		end
	end
	if cfg.kind ~= "smithy" then
		local dz = -hd / 2 + 0.4
		local dy = top + R * 0.5 + 0.9
		part(Vector3.new(5, 3.4, 3.6), at(0, dy, dz), PLASTER)
		part(Vector3.new(2.6, 1.9, 0.2), at(0, dy + 0.1, dz - 1.85), Color3.fromRGB(190, 225, 240), Enum.Material.Glass, {Transparency = 0.25})
		part(Vector3.new(3.2, 0.3, 0.3), at(0, dy - 1.0, dz - 1.9), DARK, Enum.Material.Wood)
		for _, sx in {-1, 1} do
			part(Vector3.new(3.3, 0.35, 4.4), at(sx * 1.35, dy + 2.25, dz) * CFrame.Angles(0, 0, sx * -0.62), cfg.roof, Enum.Material.Slate)
		end
	end
	-- chimney smoke
	local big = cfg.kind == "smithy"
	local smoke = part(Vector3.new(1, 1, 1), at(Wd / 2 - 3.5, top + R + (big and 6 or 3.5) + 0.6, Dp / 4), Color3.new(1, 1, 1), nil,
		{Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Name = "Smoke"})
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, big and 6 or 4)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)})
	e.Lifetime = NumberRange.new(3, 5)
	e.Rate = big and 5 or 2.5
	e.Speed = NumberRange.new(2, 3.5)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = Vector3.new(0.6, 0.4, 0)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Parent = smoke
	if cfg.kind == "smithy" then return end
	-- the beam band between the floors, with little corbels
	part(Vector3.new(Wd + 0.6, 0.7, 1.4), at(0, y0 + H1 + 0.3, fz - 0.2), DARK, Enum.Material.Wood)
	for k = 0, 6 do
		part(Vector3.new(0.6, 1, 0.8), at(-Wd / 2 + 1 + k * (Wd - 2) / 6, y0 + H1 - 0.55, fz - 0.4), DARK, Enum.Material.Wood)
	end
	-- upper floor: X-beams in the outer panels, shutters and flower boxes on the windows
	if cfg.kind ~= "hall" and H2 > 0 then
		local y1 = y0 + H1 + 0.6
		local pw = Wd / 4
		local th = math.atan(H2 / pw)
		local len = math.sqrt(pw * pw + H2 * H2)
		for _, sx in {-1, 1} do
			local cx = sx * (Wd / 2 - pw / 2)
			for _, s in {-1, 1} do
				part(Vector3.new(len, 0.45, 0.3), at(cx, y1 + H2 / 2, fz - 0.08) * CFrame.Angles(0, 0, s * th), DARK, Enum.Material.Wood, NOHIT)
			end
			local wx = sx * Wd / 8
			for _, ex in {-1, 1} do
				part(Vector3.new(1.1, 2.4, 0.2), at(wx + ex * 1.95, y1 + H2 / 2, fz - 0.2), accent, Enum.Material.Wood, NOHIT)
			end
			local box = PROPS:FindFirstChild("WindowBox")
			if box then
				local b = box:Clone()
				local bp = b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart", true)
				bp.Size = Vector3.new(3.2, 1, 0.9)
				bp.Anchored, bp.CanCollide = true, false
				bp.CFrame = at(wx, y1 + H2 / 2 - 1.75, fz - 0.6)
				b.Parent = m
			end
		end
	end
	-- the striped awning with a scalloped edge
	local ay = cfg.kind == "hall" and (y0 + H1 - 0.3) or (y0 + 8.4)
	local out, drop = 3.4, 1.6
	local tilt = math.atan(drop / out)
	local span = Wd - 3
	local n = math.floor(span / 2)
	local sw = span / n
	for k = 0, n - 1 do
		local x = -span / 2 + sw * (k + 0.5)
		part(Vector3.new(sw + 0.02, 0.2, math.sqrt(out * out + drop * drop)), at(x, ay - drop / 2, fz - out / 2) * CFrame.Angles(-tilt, 0, 0),
			k % 2 == 0 and Color3.fromRGB(250, 248, 240) or light, Enum.Material.Fabric, NOHIT)
		for _, dx in {-sw / 4, sw / 4} do
			part(Vector3.new(1, 1, 1), at(x + dx, ay - drop - 0.25, fz - out - 0.02), k % 2 == 0 and Color3.fromRGB(250, 248, 240) or light, Enum.Material.Fabric,
				{Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false, CanTouch = false})
		end
	end
	if cfg.kind == "hall" then return end
	-- display windows: glass, frame, cross bars, goods inside, flower box outside
	local dw = 5
	local side = (Wd - dw) / 2
	local ww, wy0, wy1 = side - 2.4, 1.1, 5.9
	local wh = wy1 - wy0
	for _, sx in {-1, 1} do
		local cx = sx * (dw / 2 + side / 2)
		local cy = y0 + (wy0 + wy1) / 2
		part(Vector3.new(ww, wh, 0.2), at(cx, cy, fz + 0.5), Color3.fromRGB(200, 230, 245), Enum.Material.Glass, {Transparency = 0.6})
		part(Vector3.new(ww + 1, 0.5, 0.5), at(cx, y0 + wy1 + 0.2, fz - 0.15), DARK, Enum.Material.Wood)
		part(Vector3.new(ww + 1, 0.5, 0.8), at(cx, y0 + wy0 - 0.2, fz - 0.3), DARK, Enum.Material.Wood)
		for _, ex in {-1, 1} do part(Vector3.new(0.5, wh, 0.5), at(cx + ex * (ww / 2 + 0.2), cy, fz - 0.15), DARK, Enum.Material.Wood) end
		part(Vector3.new(0.3, wh, 0.3), at(cx, cy, fz + 0.3), DARK, Enum.Material.Wood, NOHIT)
		part(Vector3.new(ww, 0.3, 0.3), at(cx, y0 + wy0 + wh * 0.68, fz + 0.3), DARK, Enum.Material.Wood, NOHIT)
		part(Vector3.new(ww, 0.3, 1.8), at(cx, y0 + wy0 - 0.15, fz + 1.9), WOOD, Enum.Material.Wood)
		for k = 0, 3 do
			local c = (cfg.goods or {Color3.fromRGB(240, 120, 110), Color3.fromRGB(250, 205, 90)})[k % #(cfg.goods or {1, 2}) + 1]
			local gx = cx - ww / 2 + 1 + k * (ww - 2) / 3
			part(Vector3.new(1.3, 1.3, 1.3), at(gx, y0 + wy0 + 0.65, fz + 1.9), c, Enum.Material.Fabric, {Shape = k % 2 == 0 and Enum.PartType.Ball or Enum.PartType.Block,
				CanCollide = false})
		end
		local box = PROPS:FindFirstChild("WindowBox")
		if box then
			local b = box:Clone()
			local bp = b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart", true)
			bp.Size = Vector3.new(ww, 1.1, 1)
			bp.Anchored, bp.CanCollide = true, false
			bp.CFrame = at(cx, y0 + wy0 - 0.85, fz - 0.8)
			b.Parent = m
		end
	end
	-- door frame and a little lantern
	part(Vector3.new(dw + 1, 0.6, 0.5), at(0, y0 + 6.5, fz - 0.15), DARK, Enum.Material.Wood)
	for _, ex in {-1, 1} do part(Vector3.new(0.5, 6.2, 0.5), at(ex * (dw / 2 + 0.25), y0 + 3.1, fz - 0.15), DARK, Enum.Material.Wood) end
	part(Vector3.new(0.2, 0.2, 0.9), at(dw / 2 + 1.1, y0 + 6.3, fz - 0.45), Color3.fromRGB(45, 42, 40), Enum.Material.Metal, NOHIT)
	local lan = part(Vector3.new(0.7, 1, 0.7), at(dw / 2 + 1.1, y0 + 5.7, fz - 0.85), Color3.fromRGB(255, 214, 140), Enum.Material.Neon, NOHIT)
	local pl = Instance.new("PointLight")
	pl.Color, pl.Range, pl.Brightness = Color3.fromRGB(255, 205, 140), 12, 1
	pl.Parent = lan
	-- rough stones and corner quoins on the stone storey
	local stoneRng = Random.new(math.floor(math.abs(CF.X * 7 + CF.Z * 13)))
	local placed = 0
	for _ = 1, 40 do
		if placed >= 14 then break end
		local x, y = stoneRng:NextNumber(-Wd / 2 + 1.2, Wd / 2 - 1.2), stoneRng:NextNumber(0.6, H1 - 0.6)
		local inDoor = math.abs(x) < dw / 2 + 1 and y < 7.2
		local inWin = math.abs(math.abs(x) - (dw / 2 + side / 2)) < ww / 2 + 1 and y > wy0 - 1 and y < wy1 + 1
		local inAwning = y > 7.4 and y < 9
		if not inDoor and not inWin and not inAwning then
			part(Vector3.new(stoneRng:NextNumber(1.4, 2.6), stoneRng:NextNumber(0.7, 1.1), 0.25), at(x, y0 + y, fz - 0.1), STONEW:Lerp(Color3.new(0, 0, 0), stoneRng:NextNumber(0.04, 0.12)),
				Enum.Material.Cobblestone, NOHIT)
			placed += 1
		end
	end
	for k = 0, math.floor(H1 / 1.3) - 1 do
		for _, sx in {-1, 1} do
			part(Vector3.new(k % 2 == 0 and 1.8 or 1.1, 1.15, 0.3), at(sx * (Wd / 2 - (k % 2 == 0 and 0.9 or 0.55)), y0 + 0.6 + k * 1.3, fz - 0.12),
				Color3.fromRGB(205, 198, 186), Enum.Material.Cobblestone, NOHIT)
		end
	end
	-- a potted plant by the door
	local px = -(dw / 2 + 1.6)
	part(Vector3.new(1.6, 1.8, 1.8), at(px, 0.9, fz - 1.3) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(196, 120, 80), Enum.Material.Slate, {Shape = Enum.PartType.Cylinder})
	part(Vector3.new(2.4, 2.4, 2.4), at(px, 2.6, fz - 1.3), Color3.fromRGB(95, 160, 74), Enum.Material.Grass, {Shape = Enum.PartType.Ball, CanCollide = false})
	for _, o in {{-0.6, 3.4, -0.6}, {0.7, 3.2, -0.3}, {0, 3.7, 0.5}} do
		part(Vector3.new(0.6, 0.6, 0.6), at(px + o[1], o[2], fz - 1.3 + o[3]), light, nil, {Shape = Enum.PartType.Ball, CanCollide = false})
	end
end

---------------------------------------------------------------- steps
local STEPS = {}

-- clear the old town dressing (keeps the meadow trees and flowers), hide the old floors
function STEPS.clear()
	local out = {}
	local gone = {SeedStall = 1, FruitStall = 1, MapBooth = 1, ArenaGate = 1, HeartBed = 1, Workbench = 1, LampPost = 1, Bunting = 1, Signpost = 1, Planter = 1,
		Fountain = 1, Bench = 1, CafeTable = 1, Balloons = 1, Bakery = 1, Boutique = 1, Crates = 1, Carousel = 1, FestivalTent = 1, GameBooth = 1, SweetsCart = 1,
		Forge = 1, WelcomeArch = 1}
	local n = 0
	for _, c in D():GetChildren() do
		local inTown = false
		if c:IsA("PVInstance") then
			local p = c:GetPivot().Position
			inTown = p.X > -200 and p.X < 260 and p.Z > -30 and p.Z < 300
		end
		if gone[c.Name] or c:IsA("Folder") or inTown then
			c:Destroy()
			n += 1
		end
	end
	table.insert(out, "removed dressing: " .. n)
	for _, name in {"Boutique", "GearForge", "TownBuildings", "TownChips"} do
		if root:FindFirstChild(name) then root[name]:Destroy() end
	end
	if root:FindFirstChild("Paths") and root.Paths:FindFirstChild("TownFloor") then root.Paths.TownFloor:Destroy() end
	for _, d in root:GetDescendants() do
		if d:IsA("BillboardGui") and d.Name == "TownSign" then d:Destroy() end
	end
	local function hideGround(p)
		if p:GetAttribute("DressHidden") == nil then p:SetAttribute("DressHidden", p.Transparency) end
		p.Transparency = 1
		p.CanCollide, p.CanQuery = false, false
	end
	if root:FindFirstChild("FarmGround") then hideGround(root.FarmGround) end
	if root:FindFirstChild("Path") and root.Path:IsA("BasePart") then hideGround(root.Path) end
	local hidden = 0
	for _, p in (root:FindFirstChild("Paths") and root.Paths:GetChildren() or {}) do
		if p:IsA("BasePart") and math.abs(p.Position.X) < 200 and p.Position.Z > -30 and p.Position.Z < 300 then
			hideGround(p)
			hidden += 1
		end
	end
	table.insert(out, "hid old floors: " .. hidden)
	return table.concat(out, "\n")
end

-- 🌱 terrain grass under the town, 🌊 Willow Creek and the park pond
function STEPS.terrain()
	local grass = Enum.Material.Grass
	local function fill(x1, x2, z1, z2)
		Terrain:FillBlock(CFrame.new((x1 + x2) / 2, 8, (z1 + z2) / 2), Vector3.new(x2 - x1, 16, z2 - z1), Enum.Material.Air) -- nothing above the lawn
		-- terrain's surface ends up 2 studs above a fill's top, so filling to 0.7 gives a lawn at 2.7 (just under the stone paths)
		Terrain:FillBlock(CFrame.new((x1 + x2) / 2, -2.65, (z1 + z2) / 2), Vector3.new(x2 - x1, 6.7, z2 - z1), grass)
	end
	fill(-192, 188, -30, 300)
	fill(188, 260, 140, 300)
	fill(-192, -104, -40, -30)
	fill(116, 188, -40, -30)
	fill(-192, -110, -112, -40)
	local bed = folder(root.Paths, "TownFloor")
	local beds = folder(bed, "RiverBed", true)
	local function water(x, z, r)
		Terrain:FillCylinder(CFrame.new(x, 2, z), 12, r + 1, Enum.Material.Air) -- clear whole layers first: water won't replace solid ground
		Terrain:FillCylinder(CFrame.new(x, -1.8, z), 4.4, r, Enum.Material.Water) -- water surface just under the lawn
		P(beds, {Name = "Bed", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, (r + 2.5) * 2, (r + 2.5) * 2), CFrame = CFrame.new(x, 0.1, z) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(122, 140, 100), Material = Enum.Material.Sand, CanCollide = true})
	end
	local pts = riverLine(7)
	for i, p in pts do
		water(p.X, p.Z, 13.5)
		if i % 12 == 0 then task.wait() end
	end
	pcall(function() Terrain.Decoration = false end)
	Terrain.WaterColor = Color3.fromRGB(78, 168, 200)
	Terrain.WaterTransparency = 0.55
	Terrain.WaterWaveSize = 0.06
	Terrain.WaterWaveSpeed = 6
	Terrain.WaterReflectance = 0.35
	return ("grass + creek (%d spots) + pond"):format(#pts)
end

-- 🛤️ cobble streets, the ring road, plazas and the two bridges
function STEPS.roads()
	local F = folder(root.Paths, "TownFloor")
	local R = folder(F, "Roads", true)
	local function rect(name, x1, x2, z1, z2, y, color, mat)
		return P(R, {Name = name, Size = Vector3.new(x2 - x1, 1, z2 - z1), Position = Vector3.new((x1 + x2) / 2, (y or ROAD) - 0.5, (z1 + z2) / 2), Color = color or STONE,
			Material = mat or Enum.Material.Pavement})
	end
	local function disc(name, x, z, r, y, color)
		return P(R, {Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, r * 2, r * 2), CFrame = CFrame.new(x, (y or ROAD + 0.02) - 0.5, z) * CFrame.Angles(0, 0, math.pi / 2),
			Color = color or STONE, Material = Enum.Material.Pavement})
	end
	rect("WestStreet", -158, CX - RING_OUT + 2, 6, 20)
	rect("EastStreet", CX + RING_OUT - 2, 190, 6, 20)
	rect("NorthRoad", CX - 7, CX + 7, -66, CZ - RING_OUT + 2)
	rect("SouthRoad", CX - 7, CX + 7, CZ + RING_OUT - 2, 250)
	rect("ForestRoad", -200, -186, 6, 20)
	-- ring road: short pieces, alternating a hair up and down so they never flicker where they overlap
	local n = 52
	local mid = (RING_IN + RING_OUT) / 2
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local pos = Vector3.new(CX + math.cos(a) * mid, 0, CZ + math.sin(a) * mid)
		local y = ROAD + 0.02 + (i % 2) * 0.02
		P(R, {Name = "Ring", Size = Vector3.new(RING_OUT - RING_IN, 1, 2 * math.pi * RING_OUT / n + 0.8), CFrame = CFrame.new(pos.X, y - 0.5, pos.Z) * CFrame.Angles(0, -a, 0),
			Color = STONE, Material = Enum.Material.Pavement})
	end
	disc("PortalPlaza", CX, 130, 18)
	disc("CarouselRing", 80, 40, 15, ROAD + 0.02, Color3.fromRGB(232, 196, 186))
	disc("GateYard", CX, -40, 11)
	-- 🌉 bridges (planks on stone ends, with rails)
	local wood, stone = Color3.fromRGB(160, 112, 70), Color3.fromRGB(170, 165, 155)
	local function bridge(c, along, len, width)
		local cf = CFrame.lookAt(c + Vector3.new(0, 3.05, 0), c + Vector3.new(0, 3.05, 0) + along)
		local m = Instance.new("Model")
		m.Name = "Bridge"
		P(m, {Name = "Deck", Size = Vector3.new(width, 0.6, len), CFrame = cf, Color = wood, Material = Enum.Material.WoodPlanks})
		for _, z in {-len / 2 + 2, len / 2 - 2} do
			P(m, {Name = "End", Size = Vector3.new(width + 1, 3.4, 4), CFrame = cf * CFrame.new(0, -1.9, z), Color = stone, Material = Enum.Material.Cobblestone})
		end
		for _, sx in {-1, 1} do
			P(m, {Name = "Rail", Size = Vector3.new(0.5, 0.4, len), CFrame = cf * CFrame.new(sx * (width / 2 - 0.25), 2.6, 0), Color = wood, Material = Enum.Material.Wood})
			for k = 0, math.floor(len / 4) do
				P(m, {Name = "Post", Size = Vector3.new(0.5, 2.6, 0.5), CFrame = cf * CFrame.new(sx * (width / 2 - 0.25), 1.3, -len / 2 + 0.5 + k * (len - 1) / math.floor(len / 4)),
					Color = wood, Material = Enum.Material.Wood})
			end
		end
		m.Parent = R
	end
	bridge(BRIDGE_W, E, 40, 14)
	bridge(BRIDGE_S, S, 38, 8)
	return "roads, ring road, plazas, 2 bridges"
end

-- 🌀 town portal to the south plaza; spawn and boards into the park
function STEPS.move()
	local out = {}
	local tp = root.Portals:FindFirstChild("Portal_Town")
	if tp then
		local base = tp:FindFirstChild("Base") or tp.PrimaryPart
		local look = flat(base.CFrame.LookVector)
		local floorY = ROAD + 0.02
		local cf = CFrame.lookAt(Vector3.new(CX, floorY, 130), Vector3.new(CX, floorY, 130) + N)
		local T = (cf * CFrame.new(0, 0.5, 0)) * base.CFrame:Inverse()
		tp:PivotTo(T * tp:GetPivot())
		table.insert(out, "town portal -> south plaza (was facing " .. tostring(look) .. ")")
	end
	local sp = root:FindFirstChild("Spawn")
	if sp then sp.CFrame = CFrame.new(-8, G + sp.Size.Y / 2 + 0.05, 21) * CFrame.Angles(0, math.pi, 0) end
	noBubbles(sp)
	local function board(name, x, z)
		local o = root:FindFirstChild(name)
		if not o then return end
		local key = o:IsA("BasePart") and o or (o:FindFirstChild("Board") or o:FindFirstChildWhichIsA("BasePart", true))
		local front = flat(Vector3.new(CX - x, 0, CZ - z))
		local oldFront = o:GetAttribute("Front") or flat(key.CFrame.LookVector)
		local kp = key.Position
		local T = CFrame.new(x, kp.Y, z) * CFrame.Angles(0, yaw(front) - yaw(oldFront), 0) * CFrame.new(-kp)
		local list = o:GetDescendants()
		if o:IsA("BasePart") then table.insert(list, o) end -- a board part brings its legs (child parts) along
		for _, d in list do
			if d:IsA("BasePart") then d.CFrame = T * d.CFrame end
		end
		o:SetAttribute("Front", front)
	end
	board("LikeBoard", -14, 30)
	board("RecordBoard", 24, 27)
	board("NewsBoard", 22, -6)
	table.insert(out, "spawn and boards in the park")
	return table.concat(out, "\n")
end

-- 🏪 the walk-in shoplots and the smithy (working parts move inside)
local SHOPS = {
	{Name = "SeedsAndEggs", Word = "SEEDS", Icon = "🌱", Label = "Seeds & Eggs", x = -58, z = -14, front = S, roof = Color3.fromRGB(95, 143, 78), sign = Color3.fromRGB(62, 107, 58), kind = "shop"},
	{Name = "BoutiqueShop", Word = "BOUTIQUE", Icon = "👗", Label = "Bow & Bell Boutique", x = -93, z = -14, front = S, roof = Color3.fromRGB(217, 138, 168), sign = Color3.fromRGB(155, 79, 110), kind = "shop"},
	{Name = "Bakery", Word = "BAKERY", Icon = "🧁", Label = "Bun's Bakery", x = -128, z = -14, front = S, roof = Color3.fromRGB(224, 181, 74), sign = Color3.fromRGB(154, 107, 30), kind = "shop"},
	{Name = "MarketHall", Word = "MARKET", Icon = "💰", Label = "Market Hall", x = -58, z = 40, front = N, roof = Color3.fromRGB(181, 82, 59), sign = Color3.fromRGB(122, 47, 34), kind = "hall"},
	{Name = "Lodge", Word = "LODGE", Icon = "🗺️", Label = "Explorer's Lodge", x = -93, z = 40, front = N, roof = Color3.fromRGB(79, 111, 168), sign = Color3.fromRGB(47, 70, 110), kind = "shop"},
	{Name = "Smithy", Word = "SMITHY", Icon = "🔨", Label = "Smithy", x = -30, z = 100, front = E, roof = Color3.fromRGB(108, 122, 134), sign = Color3.fromRGB(63, 74, 84), kind = "smithy"},
}
function STEPS.shops()
	refreshParams()
	local B = folder(root, "TownBuildings")
	for _, s in SHOPS do
		local old = B:FindFirstChild(s.Name)
		if old then old:Destroy() end
	end
	for _, n in {"Boutique", "GearForge"} do
		if root:FindFirstChild(n) then root[n]:Destroy() end
	end
	for _, c in (D():FindFirstChild("Big") and D().Big:GetChildren() or {}) do
		if c.Name == "HeartBed" or c.Name == "ArenaGate" then c:Destroy() end
	end
	for _, c in (D():FindFirstChild("Garden") and D().Garden:GetChildren() or {}) do
		local p = c:GetPivot().Position
		if Vector3.new(p.X + 124, 0, p.Z - 35).Magnitude < 12 or Vector3.new(p.X + 128, 0, p.Z - 40).Magnitude < 13 then c:Destroy() end
	end
	-- market street lamps sit between the shop paths
	for _, c in (D():FindFirstChild("Lamps") and D().Lamps:GetChildren() or {}) do
		local p = c:GetPivot().Position
		if p.X < -40 and p.X > -160 and (math.abs(p.Z - 4) < 1.5 or math.abs(p.Z - 22) < 1.5) then c:Destroy() end
	end
	for _, x in {-44, -75.5, -110.5, -144} do lamp(x, 4) lamp(x, 22) end
	local paths = folder(folder(root.Paths, "TownFloor"), "ShopPaths", true)
	local out = {}
	for _, s in SHOPS do
		local cfg = {Name = s.Name, x = s.x, z = s.z, front = s.front, W = 30, D = 26, H1 = 12, H2 = s.kind == "smithy" and 0 or 5, R = 8, roof = s.roof, kind = s.kind}
		if s.kind == "smithy" then cfg.H1 = 13 end
		cfg.cozy = s.kind == "shop"
		cfg.sign = s.sign
		cfg.goods = ({
			SeedsAndEggs = {Color3.fromRGB(180, 140, 90), Color3.fromRGB(255, 250, 240), Color3.fromRGB(140, 200, 120)},
			BoutiqueShop = {Color3.fromRGB(255, 150, 190), Color3.fromRGB(150, 200, 255), Color3.fromRGB(255, 215, 90)},
			Bakery = {Color3.fromRGB(220, 170, 100), Color3.fromRGB(245, 180, 200), Color3.fromRGB(200, 140, 80)},
			Lodge = {Color3.fromRGB(240, 225, 180), Color3.fromRGB(110, 150, 90), Color3.fromRGB(160, 110, 70)},
		})[s.Name]
		local m, CF = building(B, cfg)
		cozy(m, CF, cfg)
		-- soil under the shop (no grass under the floor) and rugs on the stone
		Terrain:FillBlock(CFrame.lookAt(Vector3.new(s.x, -0.65, s.z), Vector3.new(s.x, -0.65, s.z) + s.front), Vector3.new(cfg.W + 1, 2.7, cfg.D + 1), Enum.Material.Grass)
		if s.kind ~= "smithy" then
			local rugC = s.sign:Lerp(Color3.new(1, 1, 1), 0.25)
			P(m, {Name = "RugEdge", Size = Vector3.new(cfg.W * 0.55 + 0.8, 0.06, cfg.D * 0.3 + 0.8), CFrame = CF * CFrame.new(0, 0.42, -4.5),
				Color = s.sign:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Fabric, CanQuery = false})
			P(m, {Name = "Rug", Size = Vector3.new(cfg.W * 0.55, 0.08, cfg.D * 0.3), CFrame = CF * CFrame.new(0, 0.44, -4.5), Color = rugC, Material = Enum.Material.Fabric,
				CanQuery = false})
			P(m, {Name = "RugStripe", Size = Vector3.new(cfg.W * 0.55 - 2, 0.1, 0.6), CFrame = CF * CFrame.new(0, 0.45, -4.5), Color = Color3.fromRGB(250, 240, 220),
				Material = Enum.Material.Fabric, CanQuery = false})
			P(m, {Name = "DoorMat", Size = Vector3.new(4.2, 0.06, 2.4), CFrame = CF * CFrame.new(0, 0.43, -cfg.D / 2 + 2.2), Color = Color3.fromRGB(170, 120, 75),
				Material = Enum.Material.Fabric, CanQuery = false})
		end
		bladeSign(m, CF, cfg, s.Word, s.sign)
		local function at(x, y, z) return CF * CFrame.new(x, y, z) end
		local deco = function(size, cf, color, mat, extra)
			local props = {Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.SmoothPlastic}
			for k, v in extra or {} do props[k] = v end
			return P(m, props)
		end
		-- the counter (the working counter is moved onto the same spot) and back shelves
		local counterAt = at(0, 0.4 + 1.5, 1.5).Position
		if s.kind ~= "smithy" then
			deco(Vector3.new(9, 3, 2), CFrame.new(counterAt) * (CF - CF.Position), WOOD, Enum.Material.WoodPlanks)
			for _, y in {2.6, 4.8} do
				deco(Vector3.new(16, 0.3, 1.4), at(0, 0.4 + y, cfg.D / 2 - 1.8), WOOD, Enum.Material.Wood)
				for k = 0, 6 do
					local c = ({Color3.fromRGB(240, 120, 110), Color3.fromRGB(250, 205, 90), Color3.fromRGB(140, 200, 120), Color3.fromRGB(150, 180, 240)})[(k + math.floor(y)) % 4 + 1]
					deco(Vector3.new(1.2, 1.2, 0.9), at(-6.6 + k * 2.2, 0.4 + y + 0.75, cfg.D / 2 - 1.8), c, nil, {CanCollide = false})
				end
			end
		end
		-- the path from the door out to the street
		local door = at(0, 0, -cfg.D / 2).Position
		local streetEdge = s.kind == "smithy" and Vector3.new(CX - 7, 0, s.z) or Vector3.new(s.x, 0, s.front == S and 6 or 20)
		local mid = (door + streetEdge) / 2
		local len = (streetEdge - door).Magnitude + 1
		P(paths, {Name = "Path", Size = Vector3.new(4.6, 1, len), CFrame = CFrame.lookAt(Vector3.new(mid.X, ROAD + 0.01 - 0.5, mid.Z), Vector3.new(streetEdge.X, ROAD + 0.01 - 0.5, streetEdge.Z)),
			Color = STONE, Material = Enum.Material.Pavement})
		chip(at(0, 24, 0).Position, s.Icon, s.Label)
		-- what's inside / the working parts
		if s.Name == "SeedsAndEggs" then
			local shop = root:FindFirstChild("SeedShop")
			if shop and shop:FindFirstChild("Counter") then
				local c = shop.Counter
				if not shop:GetAttribute("Front") then
					local keeper = shop:FindFirstChild("Shopkeeper")
					shop:SetAttribute("Front", keeper and flat(c.Position - keeper:GetPivot().Position) or flat(c.CFrame.LookVector))
				end
				moveKey(shop, c, Vector3.new(counterAt.X, G + 0.4 + c.Size.Y / 2, counterAt.Z), s.front)
				noBubbles(shop)
				local dock = shop:FindFirstChild("Dock")
				if dock then dock.CFrame = CFrame.new(s.x + 8, G + 0.3, 13) end
				for _, k in {{-7, -4.5}, {-8, -2}, {7.5, -4}} do
					deco(Vector3.new(2, 2.2, 2), at(k[1], 0.4 + 1.1, k[2]), Color3.fromRGB(180, 140, 90), Enum.Material.Fabric) -- seed sacks
				end
				table.insert(out, "seed shop inside")
			end
		elseif s.Name == "BoutiqueShop" then
			local bm = Instance.new("Model")
			bm.Name = "Boutique"
			local counter = P(bm, {Name = "Counter", Size = Vector3.new(9, 3, 2), CFrame = CFrame.new(counterAt) * (CF - CF.Position), Transparency = 1, CanCollide = false})
			bm.PrimaryPart = counter
			bm.Parent = root
			for k, c in {Color3.fromRGB(255, 150, 190), Color3.fromRGB(150, 200, 255), Color3.fromRGB(255, 215, 90)} do -- hat stands
				local x = -7 + (k - 1) * 3.2
				deco(Vector3.new(0.3, 4, 0.3), at(x, 0.4 + 2, -3.5), DARK, Enum.Material.Wood)
				deco(Vector3.new(1.4, 1, 1.4), at(x, 0.4 + 4.4, -3.5), c, Enum.Material.Fabric, {Shape = Enum.PartType.Ball})
			end
			deco(Vector3.new(2.4, 5, 0.3), at(9.8, 0.4 + 2.8, 0), Color3.fromRGB(200, 230, 245), Enum.Material.Glass, {Transparency = 0.2}) -- mirror
			table.insert(out, "boutique counter inside")
		elseif s.Name == "Bakery" then
			deco(Vector3.new(4, 4, 3), at(8, 0.4 + 2, 5), Color3.fromRGB(170, 90, 70), Enum.Material.Brick) -- oven
			deco(Vector3.new(2.2, 1.4, 0.2), at(8, 0.4 + 1.6, 3.4), Color3.fromRGB(255, 140, 50), Enum.Material.Neon)
			for k = 0, 4 do
				deco(Vector3.new(1, 0.7, 1.4), at(-3 + k * 1.5, 0.4 + 3.35, 1.5), Color3.fromRGB(220, 170, 100), nil, {CanCollide = false}) -- bread on the counter
			end
			table.insert(out, "bakery (Bun stands inside)")
		elseif s.Name == "MarketHall" then
			local ss = root:FindFirstChild("SellStand")
			if ss and ss:FindFirstChild("Counter") then
				local c = ss.Counter
				moveKey(ss, c, Vector3.new(counterAt.X, G + 0.4 + c.Size.Y / 2, counterAt.Z), s.front)
				noBubbles(ss)
				table.insert(out, "sell counter in the market hall")
			end
			for _, k in {{-8, 4}, {8, 4}, {-8, -4}} do place("Crates", at(k[1], 0, k[2]).X, at(k[1], 0, k[2]).Z, Vector3.new(4, 4.6, 3), s.front, {parent = m, y = G + 0.4}) end
		elseif s.Name == "Lodge" then
			local eb = root:FindFirstChild("ExpeditionBooth")
			if eb and eb:FindFirstChild("Counter") then
				local c = eb.Counter
				moveKey(eb, c, Vector3.new(counterAt.X, G + 0.4 + c.Size.Y / 2, counterAt.Z), s.front)
				noBubbles(eb)
				table.insert(out, "expedition counter in the lodge")
			end
			deco(Vector3.new(5, 0.4, 3.4), at(-6.5, 0.4 + 2.6, -3.5), WOOD, Enum.Material.Wood) -- map table
			deco(Vector3.new(4.4, 0.05, 2.8), at(-6.5, 0.4 + 2.83, -3.5), Color3.fromRGB(240, 225, 180), Enum.Material.SmoothPlastic)
			for _, dx in {-2, 2} do deco(Vector3.new(0.4, 2.6, 0.4), at(-6.5 + dx, 0.4 + 1.3, -3.5), WOOD, Enum.Material.Wood) end
		elseif s.Name == "Smithy" then
			local wb = root:FindFirstChild("Workbench")
			if wb and wb:FindFirstChild("Table") then
				local t = wb.Table
				moveKey(wb, t, at(-4, 0.4 + t.Size.Y / 2, 2).Position, s.front)
				noBubbles(wb)
				place("Workbench", t.Position.X, t.Position.Z, Vector3.new(8.6, 6, 5), s.front, {parent = m, collide = true, y = G + 0.4})
				table.insert(out, "workbench in the smithy")
			end
			local fpos = at(5, 0, 3).Position
			place("Forge", fpos.X, fpos.Z, Vector3.new(8, 10, 9), s.front, {parent = m, collide = true, y = G + 0.4})
			local gf = Instance.new("Model")
			gf.Name = "GearForge"
			local anvil = P(gf, {Name = "Anvil", Size = Vector3.new(3, 3, 4), CFrame = at(5, 0.4 + 1.5, -3), Transparency = 1, CanCollide = false})
			gf.PrimaryPart = anvil
			gf.Parent = root
			deco(Vector3.new(2.6, 1.2, 1.2), at(5, 0.4 + 2.2, -3), Color3.fromRGB(70, 70, 76), Enum.Material.Metal) -- anvil
			deco(Vector3.new(1.4, 1.6, 1.4), at(5, 0.4 + 0.8, -3), Color3.fromRGB(90, 70, 55), Enum.Material.Wood)
			table.insert(out, "forge + anvil in the smithy")
		end
		m.Parent = B
	end
	-- the spare lot: a little garden for now
	local lotCF = CFrame.lookAt(Vector3.new(-128, G, 40), Vector3.new(-128, G, 40) + N)
	for _, k in {{-6, 0, "FlowerBush"}, {5, 3, "FlowerBush"}, {0, 4, "Fern"}, {-2, -2, "Flowers"}, {6, -3, "Flowers"}} do
		local p = (lotCF * CFrame.new(k[1], 0, k[2])).Position
		place(k[3], p.X, p.Z, nil, nil, {parent = sub("Garden")})
	end
	place("Bench", -128, 33, Vector3.new(6, 4.3, 2.9), N, {parent = sub("Garden"), collide = true})
	-- 💕 best friends nest and ⚔️ raid gate stay outdoors
	local cau = root:FindFirstChild("Cauldron")
	if cau and cau:FindFirstChild("Pot") then
		moveKey(cau, cau.Pot, Vector3.new(124, G + cau.Pot.Size.Y / 2, 36), W)
		noBubbles(cau)
		place("HeartBed", 124, 36, Vector3.new(8.5, 4.5, 8.2), W, {parent = sub("Big"), collide = true, y = G})
		chip(Vector3.new(124, G + 14, 36), "💕", "Best Friends Nest")
	end
	local rg = root:FindFirstChild("RaidGate")
	if rg and rg:FindFirstChild("Portal") then
		local p = rg.Portal
		local y0 = groundY(-30, -50)
		moveKey(rg, p, Vector3.new(-30, p.Position.Y, -50), S)
		local mn = math.huge
		for _, d in rg:GetDescendants() do if d:IsA("BasePart") then mn = math.min(mn, d.Position.Y - d.Size.Y / 2) end end
		rg:PivotTo(rg:GetPivot() + Vector3.new(0, y0 - mn, 0))
		noBubbles(rg)
		place("ArenaGate", -30, -50, Vector3.new(13, 13.5, 5), S, {parent = sub("Big")})
		chip(Vector3.new(-30, y0 + 19, -50), "⚔️", "Raid Arena")
	end
	return table.concat(out, "\n")
end

-- ⛲ the park: fountain, gazebo, fruit trees, benches, flower beds
function STEPS.park()
	refreshParams()
	local Pk = sub("Park")
	place("Fountain", CX, 33, Vector3.new(15, 12, 15), S, {parent = Pk, collide = true})
	place("Gazebo", 18, 8, Vector3.new(14, 13, 14), W, {parent = Pk, collide = true})
	place("FruitTree", 8, -8, Vector3.new(9, 10, 9), nil, {parent = Pk, collide = true})
	place("FlowerBush", -22, 8, nil, nil, {parent = Pk})
	place("Bench", -6, -10, Vector3.new(6, 4.3, 2.9), S, {parent = Pk, collide = true})
	place("Bench", 7, 9, Vector3.new(6, 4.3, 2.9), W, {parent = Pk, collide = true})
	for k = 0, 9 do -- flowers and lily pads around the pond
		local a = k / 10 * math.pi * 2
		local x, z = -6 + math.cos(a) * 12.5, 3 + math.sin(a) * 12.5
		if free(x, z, 1.5) then place(k % 3 == 0 and "Fern" or "Flowers", x, z, nil, nil, {parent = Pk}) end
	end
	for k = 1, 5 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(2, 7)
		place("LilyPad", -6 + math.cos(a) * r, 3 + math.sin(a) * r, nil, nil, {parent = Pk, y = 2.12})
	end
	for k = 0, 7 do -- flower bed ring around the fountain
		local a = k / 8 * math.pi * 2
		place("Flowers", CX + math.cos(a) * 9.5, 33 + math.sin(a) * 9.5, nil, nil, {parent = Pk})
	end
	return "park dressed"
end

-- 🎡 Festival Green
function STEPS.festival()
	refreshParams()
	local Fz = sub("Festival")
	place("Carousel", 80, 40, Vector3.new(20, 19, 20), W, {parent = D()})
	local _, tent = place("FestivalTent", 138, 36, Vector3.new(15, 15, 15), W, {parent = Fz, collide = true})
	place("GameBooth", 76, -8, Vector3.new(9, 9, 8), S, {parent = Fz, collide = true})
	place("GameBooth", 92, -8, Vector3.new(9, 9, 8), S, {parent = Fz, collide = true})
	place("SweetsCart", 108, -8, Vector3.new(6.5, 9, 4.4), S, {parent = Fz, collide = true})
	for _, x in {106, 115, 124} do place("Bench", x, 58, Vector3.new(6, 4.3, 2.9), S, {parent = Fz, collide = true}) end
	for _, xz in {{62, 34}, {98, 30}, {62, 58}, {140, 60}} do place("Balloons", xz[1], xz[2], Vector3.new(4, 9, 4), nil, {parent = D()}) end
	return "festival green"
end

-- 🏡 cottages (closed, just for looks)
function STEPS.cottages()
	refreshParams()
	local B = folder(root, "TownBuildings")
	local C = folder(B, "Cottages", true)
	local roofs = {Color3.fromRGB(201, 112, 90), Color3.fromRGB(108, 143, 184), Color3.fromRGB(217, 138, 168), Color3.fromRGB(224, 181, 74), Color3.fromRGB(120, 160, 100)}
	local list = {}
	for _, z in {165, 190, 215} do
		table.insert(list, {x = -20, z = z, front = E})
		table.insert(list, {x = 28, z = z, front = W})
	end
	for _, x in {70, 92, 114, 136} do table.insert(list, {x = x, z = 142, front = N}) end
	for _, x in {-110, -86, -62} do table.insert(list, {x = x, z = 205, front = N}) end
	for i, c in list do
		building(C, {Name = "Cottage", x = c.x, z = c.z, front = c.front, W = 12, D = 10, H1 = 5, H2 = 3.5, R = 4.5, roof = roofs[i % #roofs + 1], kind = "cottage"})
		local cf = CFrame.lookAt(Vector3.new(c.x, 0, c.z), Vector3.new(c.x, 0, c.z) + c.front)
		for _, k in {{-7.5, -3}, {7.5, 2}} do -- a bush at the corners
			local p = (cf * CFrame.new(k[1], 0, k[2])).Position
			place(i % 2 == 0 and "FlowerBush" or "Bush", p.X, p.Z, Vector3.new(3.6, 3, 3.6), nil, {parent = sub("Garden")})
		end
	end
	return #list .. " cottages"
end

-- 🌳 one hedge network: along the streets, around the park, around the whole town. Openings only at entrances.
local GAPS = {}
local function gap(x, z, r) table.insert(GAPS, {x, z, r or 4.6}) end
local function inGap(x, z)
	for _, g in GAPS do
		if (x - g[1]) ^ 2 + (z - g[2]) ^ 2 < g[3] ^ 2 then return true end
	end
	return false
end
local HN = 0
-- continuous, neatly trimmed hedges: leafy strips with soft rounded top edges and rounded ends at every opening
local HEDGE_H, HEDGE_W, HEDGE_R = 2.6, 2.4, 0.45
local HEDGE_GREEN = Color3.fromRGB(78, 128, 56)
local function hedgeSegment(H, a, b, y)
	local A, B = Vector3.new(a[1], 0, a[2]), Vector3.new(b[1], 0, b[2])
	local L = (B - A).Magnitude
	if L < 0.05 then return end
	local mid = (A + B) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(B.X, y, B.Z))
	local function piece(size, c, shape)
		local props = {Name = "HedgeBody", Size = size, CFrame = c, Color = HEDGE_GREEN, Material = Enum.Material.LeafyGrass, MaterialVariant = "TrimmedHedge",
			CastShadow = true}
		if shape then props.Shape = shape end
		return P(H, props)
	end
	local len = L + 0.6 -- a little overlap so segments join without seams
	piece(Vector3.new(HEDGE_W, HEDGE_H - HEDGE_R, len), cf * CFrame.new(0, (HEDGE_H - HEDGE_R) / 2, 0))
	piece(Vector3.new(HEDGE_W - HEDGE_R * 2, HEDGE_R, len), cf * CFrame.new(0, HEDGE_H - HEDGE_R / 2, 0))
	for _, sx in {-1, 1} do -- rounded top edges
		piece(Vector3.new(len, HEDGE_R * 2, HEDGE_R * 2), cf * CFrame.new(sx * (HEDGE_W / 2 - HEDGE_R), HEDGE_H - HEDGE_R, 0) * CFrame.Angles(0, math.pi / 2, 0),
			Enum.PartType.Cylinder)
	end
	HN += 1
end
local function hedgeCap(H, p, y) -- a rounded end where a hedge stops at an opening
	P(H, {Name = "HedgeBody", Shape = Enum.PartType.Cylinder, Size = Vector3.new(HEDGE_H - HEDGE_R, HEDGE_W, HEDGE_W),
		CFrame = CFrame.new(p[1], y + (HEDGE_H - HEDGE_R) / 2, p[2]) * CFrame.Angles(0, 0, math.pi / 2), Color = HEDGE_GREEN, Material = Enum.Material.LeafyGrass,
		MaterialVariant = "TrimmedHedge"})
	P(H, {Name = "HedgeBody", Shape = Enum.PartType.Ball, Size = Vector3.one * HEDGE_W, CFrame = CFrame.new(p[1], y + HEDGE_H - HEDGE_W / 2, p[2]),
		Color = HEDGE_GREEN, Material = Enum.Material.LeafyGrass, MaterialVariant = "TrimmedHedge"})
end
local function hedgeRun(pts, opts)
	opts = opts or {}
	local H = sub("Hedges")
	-- 1. sample the line every ~1.3 studs, splitting it into runs at the openings
	local runs, run = {}, {}
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local L = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		local n = math.max(1, math.ceil(L / 1.3))
		for k = 0, n - (i == #pts - 1 and 0 or 1) do
			local t = k / n
			local x, z = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
			if inGap(x, z) or (opts.skip and opts.skip(x, z)) then
				if #run > 0 then table.insert(runs, run) run = {} end
			else
				table.insert(run, {x, z})
			end
		end
	end
	if #run > 0 then table.insert(runs, run) end
	-- 2. each run: merge straight bits into long segments, round the ends
	local sinceTree = 0
	for _, r in runs do
		if #r >= 2 then
			local y = groundY(r[1][1], r[1][2]) - 0.05
			local s = 1
			for i = 2, #r do
				local last = i == #r
				local bend = false
				if not last then
					local d1 = Vector3.new(r[i][1] - r[s][1], 0, r[i][2] - r[s][2])
					local d2 = Vector3.new(r[i + 1][1] - r[i][1], 0, r[i + 1][2] - r[i][2])
					if d1.Magnitude > 0.01 and d2.Magnitude > 0.01 and d1.Unit:Dot(d2.Unit) < 0.994 then bend = true end
				end
				if bend or last or (i - s) > 60 then
					hedgeSegment(H, r[s], r[i], y)
					s = i
				end
				-- street trees and wildflower verges along the way
				sinceTree += 1.3
				if opts.trees and sinceTree > 34 and rng:NextNumber() < 0.08 then
					sinceTree = 0
					place(rng:NextNumber() < 0.3 and "TreeBlossom" or "TreeRound", r[i][1], r[i][2], nil, nil, {parent = H}) -- no hull: the canopy hangs over the street
				end
				if opts.verge and i % 5 == 0 then
					local v = opts.verge * (2.4 + J(0.3))
					place(rng:NextNumber() < 0.25 and "Fern" or "Flowers", r[i][1] + v.X, r[i][2] + v.Z, Vector3.new(2.4, 1.8, 2.4), nil, {parent = sub("Verge")})
				end
			end
			if not opts.loop then
				hedgeCap(H, r[1], y)
				hedgeCap(H, r[#r], y)
			end
			if HN % 40 == 0 then task.wait() end
		end
	end
end
local function arc(cx, cz, r, a0, a1, step)
	local pts = {}
	local n = math.max(2, math.ceil(math.abs(a1 - a0) * r / (step or 2.6)))
	for i = 0, n do
		local a = a0 + (a1 - a0) * i / n
		table.insert(pts, {cx + math.cos(a) * r, cz + math.sin(a) * r})
	end
	return pts
end
local function roundedRect(x1, x2, z1, z2, r)
	local pts = {}
	local function add(list) for _, p in list do table.insert(pts, p) end end
	add(arc(x2 - r, z1 + r, r, -math.pi / 2, 0))
	add(arc(x2 - r, z2 - r, r, 0, math.pi / 2))
	add(arc(x1 + r, z2 - r, r, math.pi / 2, math.pi))
	add(arc(x1 + r, z1 + r, r, math.pi, math.pi * 1.5))
	table.insert(pts, pts[1])
	return pts
end
function STEPS.hedges()
	refreshParams()
	local old = D():FindFirstChild("Hedges")
	if old then old:Destroy() end
	if D():FindFirstChild("Verge") then D().Verge:Destroy() end
	GAPS = {}
	-- openings: shop paths, festival entrances, crossings, cottages, the park, the town exits
	for _, s in SHOPS do
		if s.kind ~= "smithy" then gap(s.x, s.front == S and 2.5 or 23.5) end
	end
	gap(-128, 23.5) -- the garden lot
	gap(CX - 10.5, 100) -- smithy path
	for _, x in {76, 92, 108} do gap(x, 2.5) end
	for _, x in {80, 118} do gap(x, 23.5, 6) end
	for _, z in {165, 190, 215} do gap(CX - 10.5, z) gap(CX + 10.5, z) end
	gap(CX + 10.5, 133) gap(CX - 10.5, 196) -- cottage lanes
	gap(CX - 10.5, 130, 19) gap(CX + 10.5, 130, 19) -- portal plaza
	gap(CX, CZ - PARK_R, 5) gap(CX, CZ + PARK_R, 5) gap(CX - PARK_R, CZ, 5) gap(CX + PARK_R, CZ, 5)
	local OUT = RING_OUT + 2.5
	gap(CX - OUT, CZ, 10) gap(CX + OUT, CZ, 10) gap(CX, CZ + OUT, 10) gap(CX, CZ - OUT, 10)
	gap(-150, 13, 9) gap(150, 13, 9) gap(CX, -33, 9) gap(CX, 238, 9)
	-- streets (both sides) with street trees and wildflower verges
	local edgeW = CX - math.sqrt((RING_OUT + 2) ^ 2 - 10.5 ^ 2) - 1
	local edgeE = CX + math.sqrt((RING_OUT + 2) ^ 2 - 10.5 ^ 2) + 1
	hedgeRun({{-148, 2.5}, {edgeW, 2.5}}, {trees = true, verge = S})
	hedgeRun({{-148, 23.5}, {edgeW, 23.5}}, {trees = true, verge = N})
	hedgeRun({{edgeE, 2.5}, {148, 2.5}}, {trees = true, verge = S})
	hedgeRun({{edgeE, 23.5}, {148, 23.5}}, {trees = true, verge = N})
	local edgeS = CZ + math.sqrt((RING_OUT + 2) ^ 2 - 10.5 ^ 2) + 1
	hedgeRun({{CX - 10.5, edgeS}, {CX - 10.5, 236}}, {trees = true, verge = E})
	hedgeRun({{CX + 10.5, edgeS}, {CX + 10.5, 236}}, {trees = true, verge = W})
	-- around the park and the outside of the ring road (not where it meets the north edge of town)
	hedgeRun(arc(CX, CZ, PARK_R, 0, math.pi * 2))
	hedgeRun(arc(CX, CZ, OUT, 0, math.pi * 2), {skip = function(x, z) return z < -24 end})
	-- the whole town
	hedgeRun(roundedRect(-150, 150, -33, 238, 16))
	return ("hedge pieces: %d"):format(HN)
end

-- 🌲 nature: groves, willows and reeds by the creek, pines outside town, rocks, lamps, little lights
function STEPS.nature()
	refreshParams()
	refreshFree()
	local Big = sub("Big")
	local Nat = sub("Nature")
	local n = 0
	local function tree(x, z, kind)
		if not free(x, z, kind == "Pine" and 3.5 or 6) then return end
		local sizes = {TreeRound = Vector3.new(16, 22, 16), TreeBlossom = Vector3.new(13, 14, 13), FruitTree = Vector3.new(11, 12, 11), Pine = Vector3.new(9, 18, 9),
			Willow = Vector3.new(18, 17, 17)}
		local s = rng:NextNumber(0.8, 1.15)
		place(kind, x, z, sizes[kind] * s, nil, {parent = Big, collide = true})
		n += 1
	end
	local kinds = {"TreeRound", "TreeRound", "TreeBlossom", "FruitTree", "Pine"}
	local groves = {{-115, 85, 5}, {-70, 140, 5}, {-118, 160, 4}, {-40, 70, 3}, {-128, 230, 3}, {60, 185, 5}, {110, 190, 4}, {140, 105, 3},
		{132, -22, 3}, {-48, -20, 2}, {50, 225, 3}, {-60, 235, 2}, {30, 75, 3}}
	for _, g in groves do
		for k = 1, g[3] do
			local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, 12)
			tree(g[1] + math.cos(a) * r, g[2] + math.sin(a) * r, kinds[rng:NextInteger(1, #kinds)])
		end
		for k = 1, 3 do
			local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(4, 15)
			local x, z = g[1] + math.cos(a) * r, g[2] + math.sin(a) * r
			if free(x, z, 2) then place(({"Fern", "Bush", "MossyRock", "Flowers"})[k % 4 + 1], x, z, nil, nil, {parent = Nat}) end
		end
		task.wait()
	end
	-- pines just outside the town hedge
	for _, p in roundedRect(-153, 158, -41, 246, 20) do
		local nearGate = p[2] < -30 and ((p[1] > CX - 22 and p[1] < CX + 22) or (p[1] > -46 and p[1] < -14) or (p[1] > 18 and p[1] < 50))
		if not nearGate and rng:NextNumber() < 0.16 then tree(p[1] + J(2), p[2] + J(2), rng:NextNumber() < 0.7 and "Pine" or "TreeRound") end
	end
	-- by the creek: willows, reeds, rocks, lily pads (not on the bridges)
	local pts = riverLine(9)
	for i, p in pts do
		local nb = (pts[math.min(#pts, i + 1)] - pts[math.max(1, i - 1)])
		if nb.Magnitude > 0.1 then
			local side = Vector3.new(-nb.Unit.Z, 0, nb.Unit.X)
			local nearBridge = (p - BRIDGE_W).Magnitude < 24 or (p - BRIDGE_S).Magnitude < 22
			if not nearBridge then
				local s = i % 2 == 0 and 1 or -1
				if i % 2 == 0 then
					local r = p + side * s * 14.2
					place("Reeds", r.X, r.Z, nil, nil, {parent = Nat, sink = 0.6})
				end
				if i % 5 == 0 then
					local w = p + side * s * 21
					tree(w.X, w.Z, "Willow")
				end
				if i % 7 == 3 then
					local r = p + side * -s * 15.5
					place("MossyRock", r.X, r.Z, Vector3.new(3.6, 3, 3.6), nil, {parent = Nat, collide = true})
				end
				if i % 4 == 1 then
					local l = p + side * J(7)
					place("LilyPad", l.X, l.Z, nil, nil, {parent = Nat, y = 2.12})
				end
			end
		end
		if i % 15 == 0 then task.wait() end
	end
	-- 🐟 a fishing dock on the creek beside the south footbridge
	place("FishingDock", 26, 251, Vector3.new(6, 4, 12), S, {parent = Big, collide = true, y = -0.6})
	-- lamps along the streets and around the ring road
	for _, x in {-59, -85, -111, -137} do lamp(x, 4) lamp(x, 22) end
	for _, x in {64, 100, 132} do lamp(x, 4) lamp(x, 22) end
	for _, z in {75, 177, 202, 228} do lamp(CX - 8.6, z) lamp(CX + 8.6, z) end
	for _, a in {0.25, 0.75, 1.25, 1.75} do lamp(CX + math.cos(a * math.pi) * (RING_OUT + 1.3), CZ + math.sin(a * math.pi) * (RING_OUT + 1.3)) end
	lamp(CX - 12, 118) lamp(CX + 12, 118)
	-- ✨ little lights: petals over the flower beds, fireflies by the water
	local L = sub("Sparkles")
	local function motes(pos, color, light, size, rate)
		local p = P(L, {Name = "Motes", Size = Vector3.new(18, 4, 18), Position = pos, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(color)
		e.LightEmission = light
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, size), NumberSequenceKeypoint.new(1, 0)})
		e.Transparency = NumberSequence.new(0.2)
		e.Lifetime = NumberRange.new(3, 5)
		e.Rate = rate
		e.Speed = NumberRange.new(0.3, 0.9)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, 0.15, 0)
		e.Parent = p
	end
	for _, xz in {{CX, 33}, {-6, 3}, {-124, 35}, {80, 40}} do motes(Vector3.new(xz[1], G + 3, xz[2]), Color3.fromRGB(255, 190, 215), 0.2, 0.35, 2) end
	for i, p in pts do
		if i % 9 == 0 then motes(p + Vector3.new(0, G + 2.5, 0), Color3.fromRGB(230, 255, 140), 1, 0.25, 2.5) end
	end
	return ("trees %d, lamps and creek plants placed"):format(n)
end

-- 🌀 soft hedge nooks around every portal, with a stone pad, planters and a lamp; town exits get hedge arches
function STEPS.nooks()
	refreshParams()
	local Nk = sub("PortalNooks")
	Nk:ClearAllChildren()
	GAPS = {{CX, 144, 8}} -- the south road runs on behind the town portal
	local n = 0
	for _, portal in root.Portals:GetChildren() do
		local base = portal:FindFirstChild("Base") or portal.PrimaryPart
		if base then
			local look = flat(base.CFrame.LookVector)
			local pos = base.Position
			local y = pos.Y - base.Size.Y / 2
			P(Nk, {Name = "Pad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 22, 22), CFrame = CFrame.new(pos.X, y - 0.1, pos.Z) * CFrame.Angles(0, 0, math.pi / 2),
				Color = Color3.fromRGB(176, 170, 160), Material = Enum.Material.Cobblestone})
			local backA = math.atan2(-look.Z, -look.X)
			local pts = arc(pos.X, pos.Z, 14, backA - 1.95, backA + 1.95)
			hedgeRun(pts) -- uses the Hedges folder too
			local side = Vector3.new(-look.Z, 0, look.X)
			for _, s in {-1, 1} do
				local q = pos + side * s * 11.5 + look * 5
				place("Planter", q.X, q.Z, Vector3.new(5, 2.6, 2), look, {parent = Nk})
			end
			local l = pos + side * 12.5 - look * 4
			lamp(l.X, l.Z, Nk)
			-- the old purple bubble goes; a quiet chip instead
			noBubbles(portal)
			chip(pos + Vector3.new(0, 24, 0), "🌀", portal.Name == "Portal_Town" and "Portal" or "Portal")
			n += 1
		end
	end
	-- 🌹 hedge arches at the town exits
	for _, a in {{CX, -33, S, "🧭", "To the Meadow"}, {-150, 13, E, "🌲", "To the Forest"}, {150, 13, W, "❄️", "To the Peaks"}, {CX, 238, N, "🎣", "Willow Creek"}} do
		local _, mp = place("HedgeArch", a[1], a[2], Vector3.new(18, 14, 4.5), a[3], {parent = Nk})
		chip(Vector3.new(a[1], groundY(a[1], a[2]) + 18, a[2]), a[4], a[5])
	end
	return n .. " portal nooks + 4 hedge arches"
end

-- 🪧 nothing to build here: the chips were added by the other steps; this reports them
function STEPS.chips()
	local f = root:FindFirstChild("TownChips")
	return ("%d sign chips"):format(f and #f:GetChildren() or 0)
end

-- ✂️ neatly trimmed grass, and no grass blades poking up through roads and paths (the soil under them has no grass)
local function soilUnder(part)
	local size = part.Size
	if part.Shape == Enum.PartType.Cylinder then
		Terrain:FillCylinder(CFrame.new(part.Position.X, -0.65, part.Position.Z), 2.7, size.Y / 2, Enum.Material.Grass)
	else
		local cf = part.CFrame
		local flatCF = CFrame.lookAt(Vector3.new(cf.X, -0.65, cf.Z), Vector3.new(cf.X, -0.65, cf.Z) + flat(cf.LookVector))
		Terrain:FillBlock(flatCF, Vector3.new(size.X, 2.7, size.Z), Enum.Material.Grass)
	end
end
function STEPS.grass()
	local out = {}
	-- lush, evenly trimmed lawn: the TrimmedLawn material on all grass, no grass blades (so nothing pokes through roads)
	pcall(function() game:GetService("MaterialService"):SetBaseMaterialOverride(Enum.Material.Grass, "TrimmedLawn") end)
	pcall(function() Terrain.Decoration = false end)
	Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 168, 72))
	table.insert(out, "trimmed lawn, no grass blades")
	local n = 0
	local tf = root.Paths:FindFirstChild("TownFloor")
	for _, d in (tf and tf:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Parent.Name ~= "RiverBed" and d.Parent.Name ~= "Accents" and d.Name ~= "PondBed" and d.Name ~= "Deck" and d.Name ~= "Rail" and d.Name ~= "Post" and d.Name ~= "End" then
			soilUnder(d)
			n += 1
			if n % 40 == 0 then task.wait() end
		end
	end
	table.insert(out, "soil under " .. n .. " road and path pieces")
	return table.concat(out, " | ")
end

-- 🪨 stone footpaths: into the park, to the cottages, the festival, the lot, the raid gate and the fishing dock
function STEPS.paths()
	refreshParams()
	local F = folder(folder(root.Paths, "TownFloor"), "Footpaths", true)
	local COBBLE = Color3.fromRGB(205, 190, 165)
	local function path(a, b, w)
		local A, B = Vector3.new(a[1], 0, a[2]), Vector3.new(b[1], 0, b[2])
		local mid = (A + B) / 2
		local len = (B - A).Magnitude + 1.2
		local y = ROAD + 0.01 - 0.5
		local p = P(F, {Name = "Footpath", Size = Vector3.new(w or 4.4, 1, len), CFrame = CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(B.X, y, B.Z)),
			Color = COBBLE, Material = Enum.Material.Cobblestone})
		soilUnder(p)
		return p
	end
	-- the park: four ways in from the ring road, plus spawn to the fountain
	for _, d in {N, S, E, W} do -- four ways in from the ring road to the big fountain
		path({CX + d.X * (RING_IN + 0.5), CZ + d.Z * (RING_IN + 0.5)}, {CX + d.X * 20.5, CZ + d.Z * 20.5})
	end
	-- cottages by the south road (doors face the road)
	for _, z in {165, 190, 215} do
		path({-14.5, z}, {CX - 7, z}, 3.6)
		path({22.5, z}, {CX + 7, z}, 3.6)
	end
	-- lanes to the cottages by the festival and by the creek (with an opening in the road hedge)
	path({CX + 7, 133}, {140, 133}, 4)
	for _, x in {70, 92, 114, 136} do path({x, 133}, {x, 137}, 3.4) end
	path({CX - 7, 196}, {-114, 196}, 4)
	for _, x in {-110, -86, -62} do path({x, 196}, {x, 200}, 3.4) end
	-- festival green
	path({80, 20}, {80, 26})
	path({118, 20}, {118, 55})
	path({118, 36}, {128.5, 36}, 3.6)
	for _, x in {76, 92, 108} do path({x, -3.5}, {x, 6}) end
	-- the garden lot, the raid gate, the meadow portal and the fishing dock
	path({-128, 20}, {-128, 32})
	path({-7, -42}, {-28, -45.5})
	path({15, -42}, {32, -46})
	path({CX + 7, 244}, {24, 246}, 3.6)
	return "stone footpaths: " .. #F:GetChildren()
end

-- 🌸 flower patches along the trimmed hedges (each patch one or two colours, like planted beds)
function STEPS.bloom()
	local H = D():FindFirstChild("Hedges")
	if not H then return "no hedges" end
	local Fl = sub("HedgeFlowers")
	Fl:ClearAllChildren()
	local brng = Random.new(91)
	local C = {pink = Color3.fromRGB(255, 150, 190), white = Color3.fromRGB(255, 252, 245), yellow = Color3.fromRGB(255, 215, 80),
		lilac = Color3.fromRGB(195, 160, 255), red = Color3.fromRGB(235, 80, 95), peach = Color3.fromRGB(255, 185, 140)}
	local palettes = {{C.pink, C.white}, {C.yellow, C.white}, {C.lilac, C.pink}, {C.red, C.pink}, {C.white}, {C.peach, C.yellow}}
	local flowers, patches = 0, 0
	for i, b in H:GetChildren() do
		-- the main body block of each segment (long along Z, as tall as the hedge minus the rounded top)
		if b:IsA("BasePart") and b.Name == "HedgeBody" and b.Shape == Enum.PartType.Block and b.Size.X > HEDGE_W - 0.1 then
			local L = b.Size.Z
			local topY = b.Position.Y + b.Size.Y / 2 + HEDGE_R
			local k = -L / 2 + brng:NextNumber(0.5, 3)
			while k < L / 2 - 0.5 do
				if brng:NextNumber() < 0.42 then
					patches += 1
					local pal = palettes[brng:NextInteger(1, #palettes)]
					local plen = brng:NextNumber(1.4, 3.2)
					for _ = 1, math.floor(plen * 3) do
						local along = k + brng:NextNumber(0, plen)
						local onTop = brng:NextNumber() < 0.65
						local x = onTop and brng:NextNumber(-HEDGE_W / 2 + 0.5, HEDGE_W / 2 - 0.5) or (brng:NextNumber() < 0.5 and -1 or 1) * (HEDGE_W / 2 + 0.05)
						local y = onTop and (topY - 0.05) or (topY - brng:NextNumber(0.6, 1.6))
						local pos = (b.CFrame * CFrame.new(x, 0, along)).Position
						P(Fl, {Name = "Bloom", Shape = Enum.PartType.Ball, Size = Vector3.one * brng:NextNumber(0.32, 0.48), Position = Vector3.new(pos.X, y, pos.Z),
							Color = pal[brng:NextInteger(1, #pal)], CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false})
						flowers += 1
					end
					k += plen + brng:NextNumber(2, 6)
				else
					k += brng:NextNumber(2, 5)
				end
			end
			if i % 60 == 0 then task.wait() end
		end
	end
	return ("%d blossoms in %d flower patches"):format(flowers, patches)
end

-- ⛲ the water garden: a big pond with koi, a gazebo on the water reached by a wooden pier, an arched bridge,
-- the fountain spilling into the pond, and tidy flower beds (Farmer Fern looks after them)
function STEPS.park2()
	refreshParams()
	local old = D():FindFirstChild("Park")
	if old then old:Destroy() end
	local Pk = sub("Park")
	local PCX, PCZ, PR = 2, 6, 14 -- the pond
	-- water: fill the old little pond back in, then dig the big one
	Terrain:FillCylinder(CFrame.new(-6, 1.35, 3), 2.7, 11, Enum.Material.Grass)
	Terrain:FillCylinder(CFrame.new(PCX, 2.5, PCZ), 6, PR + 1, Enum.Material.Air)
	Terrain:FillCylinder(CFrame.new(PCX, 1.1, PCZ), 2.2, PR, Enum.Material.Water)
	local F = folder(root.Paths, "TownFloor")
	local pb = F:FindFirstChild("PondBed")
	if pb then pb:Destroy() end
	P(F, {Name = "PondBed", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, (PR + 2.5) * 2, (PR + 2.5) * 2), CFrame = CFrame.new(PCX, 0.13, PCZ) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(110, 140, 105), Material = Enum.Material.Sand})
	local WOODC, WOODD = Color3.fromRGB(165, 118, 74), Color3.fromRGB(120, 84, 52)
	local function wood(size, cf, extra)
		local props = {Size = size, CFrame = cf, Color = WOODC, Material = Enum.Material.WoodPlanks}
		for k, v in extra or {} do props[k] = v end
		return P(Pk, props)
	end
	local UP = CFrame.Angles(0, 0, math.pi / 2)
	-- 🏯 the gazebo on a round deck in the middle of the pond
	local deckTop = 3.3
	wood(Vector3.new(0.6, 14, 14), CFrame.new(PCX, deckTop - 0.3, PCZ) * UP, {Shape = Enum.PartType.Cylinder})
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		wood(Vector3.new(deckTop + 0.5, 0.7, 0.7), CFrame.new(PCX + math.cos(a) * 6, (deckTop - 0.5) / 2, PCZ + math.sin(a) * 6) * UP,
			{Shape = Enum.PartType.Cylinder, Color = WOODD, Material = Enum.Material.Wood})
	end
	place("Gazebo", PCX, PCZ, Vector3.new(12, 12, 12), E, {parent = Pk, collide = true, y = deckTop})
	-- 🎣 the pier from the east bank to the gazebo deck
	local pierA, pierB = Vector3.new(PCX + 6.6, 0, PCZ), Vector3.new(PCX + PR + 3, 0, PCZ)
	local pmid, plen = (pierA + pierB) / 2, (pierB - pierA).Magnitude
	wood(Vector3.new(plen, 0.5, 4.2), CFrame.new(pmid.X, deckTop - 0.25, pmid.Z))
	for k = 0, math.floor(plen / 3) do
		for _, sz in {-1, 1} do
			local x = pierA.X + 1 + k * 3
			wood(Vector3.new(deckTop + 1.6, 0.5, 0.5), CFrame.new(x, (deckTop + 1.6) / 2, PCZ + sz * 2.2) * UP,
				{Shape = Enum.PartType.Cylinder, Color = WOODD, Material = Enum.Material.Wood})
		end
	end
	for _, sz in {-1, 1} do -- rope rails
		wood(Vector3.new(plen, 0.15, 0.15), CFrame.new(pmid.X, deckTop + 1.4, PCZ + sz * 2.2), {Color = Color3.fromRGB(215, 190, 140), Material = Enum.Material.Fabric})
	end
	-- 🌉 an arched wooden bridge over the west side of the pond
	local bx, bz1, bz2 = -8, -8, 20
	local segs = 8
	local function archY(t) return 3.05 + 1.9 * math.sin(math.pi * t) end
	for k = 0, segs - 1 do
		local t1, t2 = k / segs, (k + 1) / segs
		local p1 = Vector3.new(bx, archY(t1), bz1 + (bz2 - bz1) * t1)
		local p2 = Vector3.new(bx, archY(t2), bz1 + (bz2 - bz1) * t2)
		local mid, len = (p1 + p2) / 2, (p2 - p1).Magnitude
		wood(Vector3.new(5, 0.5, len + 0.15), CFrame.lookAt(mid, p2))
		for _, sx in {-1, 1} do
			wood(Vector3.new(0.35, 0.35, len + 0.1), CFrame.lookAt(mid + Vector3.new(sx * 2.35, 1.6, 0), p2 + Vector3.new(sx * 2.35, 1.6, 0)),
				{Color = Color3.fromRGB(205, 75, 70), Material = Enum.Material.Wood})
			wood(Vector3.new(0.35, 1.8, 0.35), CFrame.new(p1 + Vector3.new(sx * 2.35, 0.9, 0)), {Color = Color3.fromRGB(205, 75, 70), Material = Enum.Material.Wood})
		end
	end
	-- ⛲ the fountain on the south bank, spilling water into the pond
	local fz = 26
	local _, fp = place("Fountain", PCX, fz, Vector3.new(13, 11, 13), N, {parent = Pk, collide = true})
	if fp then
		local topY = fp.Position.Y + fp.Size.Y / 2
		local spout = P(Pk, {Name = "Spout", Size = Vector3.one * 0.4, CFrame = CFrame.lookAt(Vector3.new(PCX, topY - 1.2, fz - 1), Vector3.new(PCX, topY + 0.2, fz - 2.2)),
			Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
		local w = Instance.new("ParticleEmitter")
		w.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		w.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
		w.LightEmission = 0.25
		w.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.25)})
		w.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.6)})
		w.EmissionDirection = Enum.NormalId.Front
		w.Speed = NumberRange.new(9, 10.5)
		w.Acceleration = Vector3.new(0, -26, 0)
		w.SpreadAngle = Vector2.new(5, 5)
		w.Lifetime = NumberRange.new(1, 1.2)
		w.Rate = 70
		w.Parent = spout
		local splash = P(Pk, {Name = "Splash", Size = Vector3.new(2, 0.2, 2), Position = Vector3.new(PCX, 2.3, fz - 8.5), Transparency = 1, CanCollide = false, CanQuery = false,
			CanTouch = false})
		local sp = Instance.new("ParticleEmitter")
		sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sp.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255))
		sp.Size = NumberSequence.new(0.35, 0)
		sp.Speed = NumberRange.new(2, 4)
		sp.SpreadAngle = Vector2.new(60, 60)
		sp.Acceleration = Vector3.new(0, -12, 0)
		sp.Lifetime = NumberRange.new(0.4, 0.7)
		sp.Rate = 30
		sp.Parent = splash
	end
	-- 🐟 koi (the client swims them around the gazebo)
	local fishF = folder(Pk, "PondFish")
	for k = 1, 7 do
		local m = place("Koi", PCX + 9, PCZ, Vector3.new(1.1, 0.75, 2.4), nil, {parent = fishF, y = 1.1})
		if m then
			m:SetAttribute("CX", PCX)
			m:SetAttribute("CZ", PCZ)
			m:SetAttribute("R", rng:NextNumber(8.2, PR - 1.6))
			m:SetAttribute("Speed", rng:NextNumber(0.18, 0.32) * (k % 3 == 0 and -1 or 1))
			m:SetAttribute("Phase", k / 7 * math.pi * 2)
			m:SetAttribute("Y", rng:NextNumber(1.2, 1.7))
		end
	end
	for k = 1, 8 do -- lily pads and reeds
		local a = rng:NextNumber(0, 6.28)
		local r = rng:NextNumber(8, PR - 1.5)
		local x, z = PCX + math.cos(a) * r, PCZ + math.sin(a) * r
		if math.abs(z - PCZ) > 3 or x < PCX then place("LilyPad", x, z, nil, nil, {parent = Pk, y = 2.12}) end
	end
	for k = 0, 13 do
		local a = k / 14 * math.pi * 2 + 0.2
		local x, z = PCX + math.cos(a) * (PR + 0.4), PCZ + math.sin(a) * (PR + 0.4)
		local nearThing = (math.abs(z - PCZ) < 4 and x > PCX) or math.abs(x - bx) < 4 or (z > fz - 9 and math.abs(x - PCX) < 8)
		if not nearThing and k % 2 == 0 then place("Reeds", x, z, nil, nil, {parent = Pk, sink = 0.6}) end
	end
	-- 🌷 tidy flower beds with wooden edging, rows of flowers, one colour per row
	local rows = {Color3.fromRGB(235, 80, 95), Color3.fromRGB(255, 215, 80), Color3.fromRGB(255, 150, 190), Color3.fromRGB(255, 252, 245), Color3.fromRGB(195, 160, 255)}
	local function bed(x, z, w, d, seed)
		local cf = CFrame.lookAt(Vector3.new(x, G, z), Vector3.new(CX, G, CZ))
		local function at(lx, ly, lz) return cf * CFrame.new(lx, ly, lz) end
		P(Pk, {Name = "Soil", Size = Vector3.new(w, 0.5, d), CFrame = at(0, 0.15, 0), Color = Color3.fromRGB(95, 66, 45), Material = Enum.Material.Ground})
		for _, sz in {-1, 1} do
			P(Pk, {Name = "Edging", Size = Vector3.new(w + 0.6, 0.6, 0.3), CFrame = at(0, 0.2, sz * (d / 2 + 0.15)), Color = WOODC, Material = Enum.Material.Wood})
		end
		for _, sx in {-1, 1} do
			P(Pk, {Name = "Edging", Size = Vector3.new(0.3, 0.6, d), CFrame = at(sx * (w / 2 + 0.15), 0.2, 0), Color = WOODC, Material = Enum.Material.Wood})
		end
		local nRows = math.max(2, math.floor(d / 1.4))
		for r = 1, nRows do
			local col = rows[(r + seed) % #rows + 1]
			local lz = -d / 2 + (r - 0.5) * d / nRows
			for c = 0, math.floor(w / 1.1) - 1 do
				local lx = -w / 2 + 0.55 + c * 1.1 + (r % 2) * 0.3
				if lx < w / 2 - 0.3 then
					P(Pk, {Name = "Leaf", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.75, CFrame = at(lx, 0.65, lz), Color = Color3.fromRGB(85, 150, 70),
						Material = Enum.Material.Grass, CanCollide = false, CastShadow = false})
					P(Pk, {Name = "Bloom", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, CFrame = at(lx, 1.15, lz), Color = col, CanCollide = false, CastShadow = false})
				end
			end
		end
	end
	bed(18, -8, 9, 5, 0)
	bed(-14, -6, 8, 4.5, 1)
	bed(19, 24, 9, 5, 2)
	bed(-15, 27, 9, 5, 3)
	place("Wheelbarrow", 25, 16, Vector3.new(2.6, 3, 4.2), W, {parent = Pk, collide = true})
	for k = 0, 5 do -- flowers around the back of the fountain
		local a = math.pi * (0.15 + k * 0.14)
		place("Flowers", PCX + math.cos(a) * 9, fz + math.sin(a) * 9, nil, nil, {parent = Pk})
	end
	place("FruitTree", 25, 4, Vector3.new(9, 10, 9), nil, {parent = Pk, collide = true})
	place("Bench", 16, -2, Vector3.new(6, 4.3, 2.9), flat(Vector3.new(PCX - 16, 0, PCZ + 2)), {parent = Pk, collide = true})
	place("Bench", -14, 15, Vector3.new(6, 4.3, 2.9), flat(Vector3.new(PCX + 14, 0, PCZ - 15)), {parent = Pk, collide = true})
	-- the spawn moves beside the pond; the boards move to a notice corner at the portal plaza
	local sp = root:FindFirstChild("Spawn")
	if sp then sp.CFrame = CFrame.new(-20, G + sp.Size.Y / 2 + 0.05, 6) * CFrame.Angles(0, -math.pi / 2, 0) end
	local function board(name, x, z)
		local o = root:FindFirstChild(name)
		if not o then return end
		local key = o:IsA("BasePart") and o or (o:FindFirstChild("Board") or o:FindFirstChildWhichIsA("BasePart", true))
		local front = flat(Vector3.new(CX - x, 0, 130 - z))
		local oldFront = o:GetAttribute("Front") or flat(key.CFrame.LookVector)
		local kp = key.Position
		local T = CFrame.new(x, kp.Y, z) * CFrame.Angles(0, yaw(front) - yaw(oldFront), 0) * CFrame.new(-kp)
		local list = o:GetDescendants()
		if o:IsA("BasePart") then table.insert(list, o) end -- a board part brings its legs (child parts) along
		for _, d in list do
			if d:IsA("BasePart") then d.CFrame = T * d.CFrame end
		end
		o:SetAttribute("Front", front)
	end
	board("LikeBoard", -15, 123)
	board("RecordBoard", 23, 123)
	board("NewsBoard", -15, 139)
	return "water garden: big pond, koi, gazebo deck + pier, arched bridge, fountain spill, 4 flower beds"
end

-- ⛲ the town centre: one big fountain filling the hedge circle, a walking ring around it with flower beds and benches
function STEPS.plaza()
	refreshParams()
	local old = D():FindFirstChild("Park")
	if old then old:Destroy() end
	local pb = root.Paths:FindFirstChild("TownFloor") and root.Paths.TownFloor:FindFirstChild("PondBed")
	if pb then pb:Destroy() end
	local Pk = sub("Park")
	local FR = 20 -- fountain radius (the walking ring is between it and the hedge)
	-- the fountain: the detailed three-tier model at one even scale (40 wide, 37 tall: never stretched)
	place("Fountain", CX, CZ, Vector3.new(FR * 2, FR * 2 * 0.924, FR * 2), S, {parent = Pk, collide = true})
	-- its water (terrain water in the basin, glassy bowls, overflow streams, mist) is made by FountainFX.lua
	-- the walking ring: flower beds on the diagonals, benches, the spawn, Farmer Fern's spot
	local rows = {Color3.fromRGB(235, 80, 95), Color3.fromRGB(255, 215, 80), Color3.fromRGB(255, 150, 190), Color3.fromRGB(255, 252, 245), Color3.fromRGB(195, 160, 255)}
	local WOODC = Color3.fromRGB(165, 118, 74)
	local function bed(ang, seed)
		local r = 25.2
		local x, z = CX + math.cos(ang) * r, CZ + math.sin(ang) * r
		local cf = CFrame.lookAt(Vector3.new(x, G, z), Vector3.new(CX, G, CZ))
		local w, d = 8, 3.6
		local function at(lx, ly, lz) return cf * CFrame.new(lx, ly, lz) end
		P(Pk, {Name = "Soil", Size = Vector3.new(w, 0.5, d), CFrame = at(0, 0.15, 0), Color = Color3.fromRGB(95, 66, 45), Material = Enum.Material.Ground})
		for _, sz in {-1, 1} do P(Pk, {Name = "Edging", Size = Vector3.new(w + 0.6, 0.6, 0.3), CFrame = at(0, 0.2, sz * (d / 2 + 0.15)), Color = WOODC, Material = Enum.Material.Wood}) end
		for _, sx in {-1, 1} do P(Pk, {Name = "Edging", Size = Vector3.new(0.3, 0.6, d), CFrame = at(sx * (w / 2 + 0.15), 0.2, 0), Color = WOODC, Material = Enum.Material.Wood}) end
		for rr = 1, 3 do
			local col = rows[(rr + seed) % #rows + 1]
			local lz = -d / 2 + (rr - 0.5) * d / 3
			for c = 0, 6 do
				local lx = -w / 2 + 0.6 + c * 1.1 + (rr % 2) * 0.3
				if lx < w / 2 - 0.3 then
					P(Pk, {Name = "Leaf", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.75, CFrame = at(lx, 0.65, lz), Color = Color3.fromRGB(85, 150, 70),
						Material = Enum.Material.Grass, CanCollide = false, CastShadow = false})
					P(Pk, {Name = "Bloom", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, CFrame = at(lx, 1.15, lz), Color = col, CanCollide = false, CastShadow = false})
				end
			end
		end
	end
	for k, deg in {45, 135, 225, 315} do bed(math.rad(deg), k) end
	local function ringSpot(deg, r) return CX + math.cos(math.rad(deg)) * r, CZ + math.sin(math.rad(deg)) * r end
	for _, deg in {20, 340, 250, 290, 70} do
		local x, z = ringSpot(deg, 25.5)
		place("Bench", x, z, Vector3.new(6, 4.3, 2.9), flat(Vector3.new(CX - x, 0, CZ - z)), {parent = Pk, collide = true})
	end
	local wx, wz = ringSpot(110, 25.5)
	place("Wheelbarrow", wx, wz, Vector3.new(2.6, 3, 4.2), flat(Vector3.new(CX - wx, 0, CZ - wz)), {parent = Pk, collide = true})
	for k = 0, 23 do -- a ring of flowers around the fountain's foot (not on the paths)
		local deg = k * 15 + 7.5
		local onPath = deg % 90 < 8 or deg % 90 > 82
		if not onPath then
			local x, z = ringSpot(deg, FR + 1.2)
			place("Flowers", x, z, Vector3.new(2.6, 2, 2.6), nil, {parent = Pk})
		end
	end
	local sp = root:FindFirstChild("Spawn")
	if sp then
		local x, z = ringSpot(200, 25)
		sp.CFrame = CFrame.lookAt(Vector3.new(x, G + sp.Size.Y / 2 + 0.05, z), Vector3.new(CX, G + sp.Size.Y / 2 + 0.05, CZ))
	end
	return "big fountain (radius " .. FR .. ") with jets, 4 flower beds, benches, spawn on the ring"
end

-- 🧱 floors with personality: cobblestones in gentle colour changes, curb stones, scattered pavers,
-- patterned plaza rings and stepping-stone footpaths
function STEPS.floors()
	local F = folder(root.Paths, "TownFloor")
	local R = F:FindFirstChild("Roads")
	local A = folder(F, "Accents", true)
	local frng = Random.new(77)
	local function shade(base, amt)
		return base:Lerp(frng:NextNumber() < 0.5 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1), frng:NextNumber(0, amt))
	end
	local CURB = Color3.fromRGB(150, 138, 124)
	local PAVER = Color3.fromRGB(205, 182, 148)
	local count = 0
	local function slab(cf, size, color, mat)
		count += 1
		return P(A, {Name = "Paver", Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.Slate, CanQuery = false, CastShadow = false})
	end
	-- streets: cobblestone, curbs on both long edges, pavers scattered in
	for _, p in (R and R:GetChildren() or {}) do
		if p:IsA("BasePart") then
			p.Material = Enum.Material.Cobblestone
			p.Color = shade(STONE, 0.05)
			if p.Shape == Enum.PartType.Block and p.Name ~= "Ring" then
				local alongX = p.Size.X >= p.Size.Z
				local L = alongX and p.Size.X or p.Size.Z
				local Wd = alongX and p.Size.Z or p.Size.X
				local axis = alongX and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
				local across = alongX and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
				local topY = p.Position.Y + p.Size.Y / 2
				for _, s in {-1, 1} do -- curbs
					local c = p.Position + across * s * (Wd / 2 - 0.4)
					slab(CFrame.new(c.X, topY + 0.06, c.Z), alongX and Vector3.new(L, 0.12, 0.8) or Vector3.new(0.8, 0.12, L), CURB, Enum.Material.Cobblestone)
				end
				for _ = 1, math.floor(L * Wd / 45) do -- pavers
					local u, v = frng:NextNumber(-L / 2 + 1.5, L / 2 - 1.5), frng:NextNumber(-Wd / 2 + 1.8, Wd / 2 - 1.8)
					local c = p.Position + axis * u + across * v
					slab(CFrame.new(c.X, topY + 0.025, c.Z) * CFrame.Angles(0, frng:NextNumber(-0.08, 0.08), 0),
						Vector3.new(frng:NextNumber(1.4, 3.2), 0.05, frng:NextNumber(1.4, 2.6)), shade(PAVER, 0.14))
				end
			end
		end
	end
	-- the ring road: curbs on both edges (open where the four roads meet) and pavers
	local n = 72
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local nearRoad = false
		for _, ra in {0, math.pi / 2, math.pi, math.pi * 1.5} do
			if math.abs((a - ra + math.pi) % (math.pi * 2) - math.pi) < 0.2 then nearRoad = true end
		end
		for _, r in {RING_IN + 0.4, RING_OUT - 0.4} do
			if not nearRoad then
				local pos = Vector3.new(CX + math.cos(a) * r, ROAD + 0.1, CZ + math.sin(a) * r)
				slab(CFrame.new(pos) * CFrame.Angles(0, -a, 0), Vector3.new(0.8, 0.12, 2 * math.pi * r / n + 0.15), CURB, Enum.Material.Cobblestone)
			end
		end
		if frng:NextNumber() < 0.7 then
			local r = frng:NextNumber(RING_IN + 2, RING_OUT - 2)
			local pos = Vector3.new(CX + math.cos(a) * r, ROAD + 0.065, CZ + math.sin(a) * r)
			slab(CFrame.new(pos) * CFrame.Angles(0, -a + frng:NextNumber(-0.1, 0.1), 0), Vector3.new(frng:NextNumber(1.4, 2.6), 0.05, frng:NextNumber(1.6, 3)),
				shade(PAVER, 0.14))
		end
	end
	-- plazas: patterned stone rings
	local function ring(x, z, r, y, color)
		count += 1
		return P(A, {Name = "PlazaRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, r * 2, r * 2), CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2),
			Color = color, Material = Enum.Material.Cobblestone, CanQuery = false, CastShadow = false})
	end
	local base = ROAD + 0.02
	for _, pl in {{CX, 130, 18}, {CX, -40, 11}} do
		ring(pl[1], pl[2], pl[3] - 2, base + 0.03, CURB)
		ring(pl[1], pl[2], pl[3] - 3, base + 0.05, Color3.fromRGB(214, 192, 158))
		ring(pl[1], pl[2], pl[3] * 0.45, base + 0.07, Color3.fromRGB(176, 160, 140))
		ring(pl[1], pl[2], pl[3] * 0.45 - 1, base + 0.09, Color3.fromRGB(226, 208, 176))
		for k = 0, 11 do -- a ring of little dark stones
			local a = k / 12 * math.pi * 2
			ring(pl[1] + math.cos(a) * (pl[3] - 5.5), pl[2] + math.sin(a) * (pl[3] - 5.5), 0.9, base + 0.07, CURB)
		end
	end
	for k = 0, 7 do -- petals around the carousel
		local a = k / 8 * math.pi * 2
		ring(80 + math.cos(a) * 12.5, 40 + math.sin(a) * 12.5, 2.4, ROAD + 0.04, k % 2 == 0 and Color3.fromRGB(245, 205, 215) or Color3.fromRGB(200, 225, 240))
	end
	-- shop paths: cobbles; footpaths: pebbles with stepping stones
	local sp = F:FindFirstChild("ShopPaths")
	for _, p in (sp and sp:GetChildren() or {}) do
		p.Material = Enum.Material.Cobblestone
		p.Color = shade(STONE, 0.05)
	end
	local fp = F:FindFirstChild("Footpaths")
	for _, p in (fp and fp:GetChildren() or {}) do
		p.Material = Enum.Material.Pebble
		p.Color = Color3.fromRGB(196, 182, 156)
		local L = p.Size.Z
		local topY = p.Position.Y + p.Size.Y / 2
		for k = 0, math.floor(L / 2.4) do
			local c = p.CFrame * CFrame.new(frng:NextNumber(-0.5, 0.5), 0, -L / 2 + 1.2 + k * 2.4)
			local r = frng:NextNumber(1.05, 1.45)
			count += 1
			P(A, {Name = "SteppingStone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, r * 2, r * 2),
				CFrame = CFrame.new(c.X, topY + 0.07, c.Z) * CFrame.Angles(0, 0, math.pi / 2),
				Color = shade(Color3.fromRGB(214, 206, 190), 0.12), Material = Enum.Material.Slate, CanQuery = false, CastShadow = false})
		end
	end
	return ("%d floor accents (curbs, pavers, plaza rings, stepping stones)"):format(count)
end

return function(step)
	count = {}
	local fn = STEPS[step]
	if not fn then return "no step " .. tostring(step) end
	local res = fn()
	local parts = {}
	for k, v in count do table.insert(parts, k .. " " .. v) end
	table.sort(parts)
	return res .. (#parts > 0 and ("\nplaced: " .. table.concat(parts, ", ")) or "")
end
