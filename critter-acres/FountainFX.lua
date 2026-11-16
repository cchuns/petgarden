-- Critter Acres: FountainFX (Studio command-bar / builder snippet)
-- Water for the big town fountain (ServerStorage.IslandProps.Fountain, 40 wide x 37 tall, standing on the lawn).
--   basin + both bowls: exact round glassy water surfaces tucked just inside each wall
--   (terrain water was tried first: its 4-stud voxels make a jagged edge that pokes through the round basin)
--   overflow: streaky water curtains falling from each bowl's rim, a jet from the top flower, splash mist
-- Heights are above the fountain's bottom, measured from the generated mesh.
local CX, CZ, Y0 = 4, 13, 2.72
local park = workspace.CritterAcres.TownDressing.Park
local Terrain = workspace.Terrain

local old = park:FindFirstChild("FountainWater")
if old then old:Destroy() end
local F = Instance.new("Model")
F.Name = "FountainWater"

-- clear any old terrain water from the basin
Terrain:ReplaceMaterial(Region3.new(Vector3.new(CX - 22, 4, CZ - 22), Vector3.new(CX + 22, 12, CZ + 22)):ExpandToGrid(4), 4, Enum.Material.Water, Enum.Material.Air)

local function disc(name, r, y)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.3, r * 2, r * 2)
	p.CFrame = CFrame.new(CX, Y0 + y - 0.15, CZ) * CFrame.Angles(0, 0, math.pi / 2) -- top face sits at y
	p.Material = Enum.Material.Glass
	p.Color = Color3.fromRGB(95, 175, 210)
	p.Transparency = 0.25
	p.Reflectance = 0.15
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = F
	return p
end
disc("BasinWater", 16.9, 5.5)  -- floor 3.0, inner wall 16.2-16.9, rim 6.2
disc("MiddleWater", 8.9, 17.0) -- bowl floor 14.8, curves up to the rim 17.7 at r 9.5
disc("TopWater", 5.6, 24.8)    -- bowl floor 23.2, rim 25.1 at r 5.8-6.2

-- holder for the emitters (attachments on one invisible part)
local holder = Instance.new("Part")
holder.Name = "FX"
holder.Size = Vector3.one
holder.CFrame = CFrame.new(CX, Y0, CZ)
holder.Transparency = 1
holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
holder.Parent = F

local WATER = ColorSequence.new(Color3.fromRGB(225, 242, 255), Color3.fromRGB(170, 215, 240))
-- a falling water stream: streaks stretched along their motion
local function stream(at, dir, o)
	local a = Instance.new("Attachment")
	a.WorldCFrame = CFrame.lookAt(at, at + dir)
	a.Parent = holder
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = WATER
	e.LightEmission = 0.15
	e.LightInfluence = 0.9
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Squash = NumberSequence.new(-1.6)
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, o.size), NumberSequenceKeypoint.new(1, o.size * 0.8)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.8, 0.45), NumberSequenceKeypoint.new(1, 1)})
	e.EmissionDirection = Enum.NormalId.Front
	e.Speed = NumberRange.new(o.speed * 0.9, o.speed)
	e.SpreadAngle = Vector2.new(o.spread or 4, o.spread or 4)
	e.Acceleration = Vector3.new(0, -42, 0)
	e.Lifetime = NumberRange.new(o.life * 0.95, o.life)
	e.Rate = o.rate
	e.Drag = 0.2
	e.Parent = a
	return e
end
-- soft splash mist where water lands
local function mist(at, o)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = holder
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(240, 250, 255))
	e.LightInfluence = 1
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, o.size * 0.5), NumberSequenceKeypoint.new(1, o.size)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1)})
	e.Speed = NumberRange.new(0.8, 1.6)
	e.SpreadAngle = Vector2.new(60, 60)
	e.EmissionDirection = Enum.NormalId.Top
	e.Lifetime = NumberRange.new(0.8, 1.3)
	e.Rate = o.rate
	e.Parent = a
end

-- top flower: a little fountain jet that falls back into the top bowl
stream(Vector3.new(CX, Y0 + 37.2, CZ), Vector3.new(0, 1, 0), {size = 0.45, speed = 10, spread = 14, life = 1.25, rate = 70})
-- top bowl overflow -> middle bowl, middle bowl overflow -> big basin
for k = 0, 15 do
	local a = (k + 0.5) / 16 * math.pi * 2
	local out = Vector3.new(math.cos(a), 0, math.sin(a))
	-- pours from just past the bowl's outer lip edge (r 7.29, h 24.32), so it never passes through the stone
	stream(Vector3.new(CX, Y0 + 24.22, CZ) + out * 7.54, (out * 0.45 + Vector3.new(0, -1, 0)).Unit, {size = 0.5, speed = 1.7, life = 0.55, rate = 28})
	mist(Vector3.new(CX, Y0 + 17.1, CZ) + out * 8.0, {size = 1.6, rate = 2})
end
for k = 0, 23 do
	local a = (k + 0.5) / 24 * math.pi * 2
	local out = Vector3.new(math.cos(a), 0, math.sin(a))
	-- pours from just past the middle bowl's outer lip edge (r 11.33, h 15.97)
	stream(Vector3.new(CX, Y0 + 15.87, CZ) + out * 11.58, (out * 0.45 + Vector3.new(0, -1, 0)).Unit, {size = 0.65, speed = 1.7, life = 0.68, rate = 30})
	mist(Vector3.new(CX, Y0 + 5.6, CZ) + out * 12.2, {size = 2.6, rate = 2.5})
end

F.Parent = park
return "fountain water ready"
