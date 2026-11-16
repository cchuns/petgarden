-- Critter Acres: CritterUI (ReplicatedStorage ModuleScript)
-- Shared picture helpers for menus: 3D critter portraits in ViewportFrames,
-- with optional idle animation (bounce, turn, blink, happy hop, sleepy sway).
local RunService = game:GetService("RunService")

local UI = {}

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = model
	return p
end

-- A round critter (same look as the ones on the farm). opts: Boss, Sleepy, Crown
function UI.Creature(parent, color, accent, opts, props)
	opts = opts or {}
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(170, 170, 170)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-1, -1, -1)
	for k, v in props or {} do vf[k] = v end
	local model = Instance.new("Model")
	model.Name = "Critter"
	local body = part(model, {Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Position = Vector3.zero, Color = color})
	model.PrimaryPart = body
	part(model, {Shape = Enum.PartType.Ball, Size = Vector3.one * 2.8, Position = Vector3.new(0, -0.5, 0.9), Color = Color3.fromRGB(255, 250, 240)})
	for _, x in {-0.8, 0.8} do
		local eyeSize = opts.Boss and 0.9 or 0.75
		part(model, {Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * eyeSize, Position = Vector3.new(x, 0.6, 1.75),
			Color = Color3.fromRGB(25, 25, 35), Transparency = opts.Sleepy and 1 or 0})
		part(model, {Name = "Lid", Size = Vector3.new(0.7, 0.15, 0.2), Position = Vector3.new(x, 0.6, 1.95), Color = Color3.fromRGB(25, 25, 35),
			Transparency = opts.Sleepy and 0 or 1})
		part(model, {Size = Vector3.new(0.6, 1.8, 0.4), Position = Vector3.new(x * 1.6, 2.2, 0), Orientation = Vector3.new(0, 0, x * 25), Color = accent})
		part(model, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Position = Vector3.new(x * 2, -1.7, 0.4), Color = accent})
	end
	if opts.Boss or opts.Crown then
		for i = -1, 1 do
			part(model, {Size = Vector3.new(0.5, 1.2, 0.5), Position = Vector3.new(i * 0.8, 2.6, 0.3), Color = Color3.fromRGB(255, 210, 60),
				Material = Enum.Material.Neon})
		end
	end
	model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(1.5, 1.2, 9), Vector3.new(0, 0.2, 0))
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = parent
	return vf
end

-- Portrait of a species by name, e.g. UI.Portrait(frame, Data, "Splashy", {Size = ...})
-- A generated model from ReplicatedStorage.<folderName>, or nil if there isn't one.
function UI.Template(folderName, name)
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild(folderName)
	return folder and folder:FindFirstChild(name)
end

---------------------------------------------------------------- outfits (hats made of parts)
-- Built 1 stud wide, sitting on the origin (base at Y = 0), front = -Z. Scale with hat:ScaleTo(width).
local HAT = {}
local function bit(model, props)
	props.Anchored = true
	props.CanCollide, props.CanQuery, props.CanTouch, props.Massless = false, false, false, true
	props.Material = props.Material or Enum.Material.SmoothPlastic
	return part(model, props)
end
local UP = CFrame.Angles(0, 0, math.pi / 2) -- cylinders point along X; this stands them up
local function disc(model, y, diameter, height, color, extra)
	local props = {Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter), CFrame = CFrame.new(0, y, 0) * UP, Color = color}
	for k, v in extra or {} do props[k] = v end
	return bit(model, props)
end
function HAT.Flower(m)
	bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.32, Position = Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(255, 210, 60)})
	for i = 0, 5 do
		local a = i * math.pi / 3
		bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.34, Position = Vector3.new(math.cos(a) * 0.28, 0.14, math.sin(a) * 0.28),
			Color = i % 2 == 0 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 170, 210)})
	end
end
function HAT.Bow(m)
	local pink = Color3.fromRGB(255, 110, 170)
	for _, x in {-1, 1} do
		bit(m, {Size = Vector3.new(0.45, 0.36, 0.14), CFrame = CFrame.new(x * 0.26, 0.2, 0) * CFrame.Angles(0, 0, x * 0.35), Color = pink})
	end
	bit(m, {Size = Vector3.new(0.2, 0.2, 0.18), Position = Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(230, 70, 140)})
end
function HAT.PartyHat(m)
	local colors = {Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 230, 90)}
	for i = 0, 5 do
		disc(m, 0.1 + i * 0.17, 0.8 * (1 - i / 6.5), 0.18, colors[i % 2 + 1])
	end
	bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.22, Position = Vector3.new(0, 1.1, 0), Color = Color3.fromRGB(255, 90, 140)})
end
function HAT.Beanie(m)
	bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.82, Position = Vector3.new(0, 0.02, 0), Color = Color3.fromRGB(80, 140, 255)})
	disc(m, 0.06, 0.86, 0.16, Color3.fromRGB(240, 240, 255))
	bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.26, Position = Vector3.new(0, 0.48, 0), Color = Color3.fromRGB(255, 255, 255)})
end
function HAT.TopHat(m)
	local black = Color3.fromRGB(30, 30, 38)
	disc(m, 0.04, 1, 0.08, black)
	disc(m, 0.44, 0.62, 0.72, black)
	disc(m, 0.16, 0.64, 0.13, Color3.fromRGB(220, 50, 70))
end
function HAT.WizardHat(m)
	local purple = Color3.fromRGB(110, 70, 200)
	disc(m, 0.03, 1.1, 0.06, purple)
	for i = 0, 6 do
		disc(m, 0.14 + i * 0.17, 0.62 * (1 - i / 7.5), 0.19, purple)
	end
	bit(m, {Size = Vector3.new(0.16, 0.16, 0.05), CFrame = CFrame.new(0.06, 0.45, -0.24) * CFrame.Angles(0, 0, math.pi / 4),
		Color = Color3.fromRGB(255, 230, 90), Material = Enum.Material.Neon})
end
function HAT.Halo(m)
	for i = 0, 11 do
		local a = i * math.pi / 6
		bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.13, Position = Vector3.new(math.cos(a) * 0.36, 0.55, math.sin(a) * 0.36),
			Color = Color3.fromRGB(255, 240, 150), Material = Enum.Material.Neon})
	end
end
function HAT.Crown(m)
	local gold = Color3.fromRGB(255, 200, 50)
	disc(m, 0.11, 0.74, 0.22, gold, {Reflectance = 0.25})
	for i = 0, 5 do
		local a = i * math.pi / 3
		bit(m, {Size = Vector3.new(0.16, 0.16, 0.16), CFrame = CFrame.new(math.cos(a) * 0.3, 0.3, math.sin(a) * 0.3) * CFrame.Angles(0, -a, math.pi / 4),
			Color = gold, Reflectance = 0.25})
	end
	for _, x in {-0.2, 0, 0.2} do
		bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.1, Position = Vector3.new(x, 0.12, -0.36),
			Color = x == 0 and Color3.fromRGB(255, 60, 90) or Color3.fromRGB(80, 160, 255), Material = Enum.Material.Neon})
	end
end

function HAT.LeafCrown(m) -- limited: autumn leaves around a little acorn
	local colors = {Color3.fromRGB(230, 90, 30), Color3.fromRGB(250, 170, 40), Color3.fromRGB(200, 50, 40)}
	for i = 0, 7 do
		local a = i * math.pi / 4
		bit(m, {Size = Vector3.new(0.3, 0.42, 0.08), CFrame = CFrame.new(math.cos(a) * 0.36, 0.22, math.sin(a) * 0.36) * CFrame.Angles(0, -a + math.pi / 2, 0)
			* CFrame.Angles(-0.35, 0, math.pi / 4), Color = colors[i % 3 + 1]})
	end
	bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.26, Position = Vector3.new(0, 0.2, -0.36), Color = Color3.fromRGB(150, 95, 50)})
	bit(m, {Size = Vector3.new(0.3, 0.1, 0.3), Position = Vector3.new(0, 0.34, -0.36), Color = Color3.fromRGB(110, 70, 40)})
end

-- new hats (pets can wear these too)
function HAT.BunnyEars(m)
	for _, x in {-1, 1} do
		for k = 0, 2 do
			bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * (0.26 - k * 0.02), Position = Vector3.new(x * (0.2 + k * 0.03), 0.12 + k * 0.2, 0.02),
				Color = Color3.fromRGB(255, 255, 255)})
			bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * (0.14 - k * 0.01), Position = Vector3.new(x * (0.2 + k * 0.03), 0.12 + k * 0.2, -0.07),
				Color = Color3.fromRGB(255, 175, 200)})
		end
	end
end
function HAT.CatEars(m)
	for _, x in {-1, 1} do
		bit(m, {Size = Vector3.new(0.32, 0.32, 0.12), CFrame = CFrame.new(x * 0.27, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 4), Color = Color3.fromRGB(245, 165, 80)})
		bit(m, {Size = Vector3.new(0.18, 0.18, 0.05), CFrame = CFrame.new(x * 0.27, 0.08, -0.06) * CFrame.Angles(0, 0, math.pi / 4), Color = Color3.fromRGB(255, 185, 200)})
	end
end
function HAT.FlowerCrown(m)
	local colors = {Color3.fromRGB(255, 150, 190), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 215, 80), Color3.fromRGB(190, 150, 255)}
	for i = 0, 9 do
		local a = i * math.pi / 5
		bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.2, Position = Vector3.new(math.cos(a) * 0.4, 0.08, math.sin(a) * 0.4), Color = colors[i % 4 + 1]})
		bit(m, {Size = Vector3.new(0.14, 0.04, 0.08), CFrame = CFrame.new(math.cos(a + 0.3) * 0.42, 0.02, math.sin(a + 0.3) * 0.42) * CFrame.Angles(0, -a, 0),
			Color = Color3.fromRGB(110, 190, 90)})
	end
end
function HAT.StrawHat(m)
	local straw = Color3.fromRGB(238, 205, 120)
	disc(m, 0.04, 1.5, 0.08, straw)
	disc(m, 0.26, 0.82, 0.42, straw)
	disc(m, 0.13, 0.85, 0.12, Color3.fromRGB(235, 85, 100))
	bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.2, Position = Vector3.new(0.4, 0.16, -0.12), Color = Color3.fromRGB(255, 255, 255)})
	bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.09, Position = Vector3.new(0.4, 0.17, -0.22), Color = Color3.fromRGB(255, 210, 60)})
end

function UI.BuildOutfit(name)
	local fn = HAT[(name or ""):gsub(" ", "")]
	if not fn then return nil end
	local m = Instance.new("Model")
	m.Name = "Outfit"
	local base = bit(m, {Name = "Base", Size = Vector3.one * 0.05, Position = Vector3.zero, Transparency = 1})
	m.PrimaryPart = base
	fn(m)
	return m
end

---------------------------------------------------------------- 👗 clothes for players (boutique)
-- Same idea as hats: built 1 stud wide around the origin. Face: the front of the face, things stick out to -Z.
-- Back: the middle of the back, things stick out to +Z.
local WEAR = {}
local function flat(model, dia, pos, color, extra) -- a thin round disc facing forward
	local props = {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.04, dia, dia), CFrame = CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0), Color = color}
	for k, v in extra or {} do props[k] = v end
	return bit(model, props)
end
local function glassesFrame(m, color)
	bit(m, {Size = Vector3.new(0.14, 0.035, 0.035), Position = Vector3.new(0, 0.05, -0.05), Color = color})
	for _, x in {-1, 1} do
		bit(m, {Size = Vector3.new(0.035, 0.035, 0.5), Position = Vector3.new(x * 0.42, 0.05, 0.2), Color = color})
	end
end
function WEAR.RoundGlasses(m)
	local frame = Color3.fromRGB(70, 50, 40)
	for _, x in {-1, 1} do
		flat(m, 0.36, Vector3.new(x * 0.22, 0.02, -0.04), frame)
		flat(m, 0.29, Vector3.new(x * 0.22, 0.02, -0.065), Color3.fromRGB(200, 235, 255), {Transparency = 0.35})
	end
	glassesFrame(m, frame)
end
function WEAR.HeartShades(m)
	local pink = Color3.fromRGB(255, 90, 160)
	for _, x in {-1, 1} do
		for _, dx in {-0.07, 0.07} do
			bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.2, Position = Vector3.new(x * 0.22 + dx, 0.07, -0.05), Color = pink})
		end
		bit(m, {Size = Vector3.new(0.2, 0.2, 0.06), CFrame = CFrame.new(x * 0.22, -0.01, -0.05) * CFrame.Angles(0, 0, math.pi / 4), Color = pink})
	end
	glassesFrame(m, Color3.fromRGB(230, 60, 130))
end
function WEAR.StarShades(m)
	local gold = Color3.fromRGB(255, 210, 60)
	for _, x in {-1, 1} do
		for _, a in {0, math.pi / 4} do
			bit(m, {Size = Vector3.new(0.27, 0.27, 0.05), CFrame = CFrame.new(x * 0.23, 0.03, -0.05) * CFrame.Angles(0, 0, a), Color = gold})
		end
		flat(m, 0.16, Vector3.new(x * 0.23, 0.03, -0.085), Color3.fromRGB(255, 120, 60))
	end
	glassesFrame(m, Color3.fromRGB(230, 170, 40))
end
function WEAR.CritterBackpack(m)
	local mint = Color3.fromRGB(130, 210, 175)
	bit(m, {Size = Vector3.new(0.72, 0.8, 0.38), Position = Vector3.new(0, -0.05, 0.2), Color = mint})
	bit(m, {Size = Vector3.new(0.5, 0.3, 0.08), Position = Vector3.new(0, -0.25, 0.42), Color = Color3.fromRGB(190, 240, 215)})
	for _, x in {-1, 1} do
		bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.24, Position = Vector3.new(x * 0.25, 0.38, 0.2), Color = mint})
		bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.08, Position = Vector3.new(x * 0.13, 0.08, 0.4), Color = Color3.fromRGB(40, 35, 35)})
		bit(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.1, Position = Vector3.new(x * 0.24, -0.02, 0.39), Color = Color3.fromRGB(255, 160, 180)})
	end
end
function WEAR.HeroCape(m)
	bit(m, {Size = Vector3.new(0.95, 1.35, 0.04), CFrame = CFrame.new(0, -0.3, 0.06) * CFrame.Angles(0.08, 0, 0), Color = Color3.fromRGB(225, 60, 75)})
	bit(m, {Size = Vector3.new(0.97, 0.12, 0.08), Position = Vector3.new(0, 0.36, 0.04), Color = Color3.fromRGB(255, 205, 60)})
end
function WEAR.ButterflyWings(m)
	for _, x in {-1, 1} do
		flat(m, 0.72, Vector3.new(x * 0.42, 0.18, 0.12), Color3.fromRGB(255, 150, 205), {Transparency = 0.1})
		flat(m, 0.36, Vector3.new(x * 0.48, 0.22, 0.1), Color3.fromRGB(255, 220, 240))
		flat(m, 0.48, Vector3.new(x * 0.32, -0.26, 0.12), Color3.fromRGB(185, 140, 255), {Transparency = 0.1})
	end
end
function WEAR.AngelWings(m)
	for _, x in {-1, 1} do
		for i = 0, 3 do
			flat(m, 0.5 - i * 0.07, Vector3.new(x * (0.3 + i * 0.16), 0.3 - i * 0.14 + (i == 0 and 0 or 0.1), 0.14 + i * 0.01), Color3.fromRGB(255, 255, 255))
		end
		flat(m, 0.3, Vector3.new(x * 0.34, -0.05, 0.13), Color3.fromRGB(240, 245, 255))
	end
end

function UI.BuildWear(name)
	local key = (name or ""):gsub(" ", "")
	local fn = WEAR[key] or HAT[key]
	if not fn then return nil end
	local m = Instance.new("Model")
	m.Name = "Wear"
	local base = bit(m, {Name = "Base", Size = Vector3.one * 0.05, Position = Vector3.zero, Transparency = 1})
	m.PrimaryPart = base
	fn(m)
	return m
end

-- Where a slot sits on a character: returns the body part, the spot and a good width.
local SLOT_PARTS = {Hat = {"Head"}, Face = {"Head"}, Back = {"UpperTorso", "Torso"}}
function UI.WearSpot(char, slot)
	for _, n in SLOT_PARTS[slot] or {} do
		local p = char:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			local s = p.Size
			local w = math.min(s.X, s.Z)
			if slot == "Hat" then return p, p.CFrame * CFrame.new(0, s.Y * 0.42, 0), w * 1.1 end
			if slot == "Face" then return p, p.CFrame * CFrame.new(0, s.Y * 0.08, -s.Z * 0.5), w * 1.0 end
			return p, p.CFrame * CFrame.new(0, s.Y * 0.1, s.Z * 0.5), s.X * 0.62
		end
	end
end

-- Puts clothes `name` in `slot` on a character (welded, so everyone sees it). nil takes it off.
function UI.PutOn(char, slot, name)
	local old = char:FindFirstChild("Wear_" .. slot)
	if old then old:Destroy() end
	if not name then return nil end
	local m = UI.BuildWear(name)
	if not m then return nil end
	local anchor, spot, width = UI.WearSpot(char, slot)
	if not anchor then m:Destroy() return nil end
	m.Name = "Wear_" .. slot
	m:ScaleTo(math.max(0.2, width))
	m:PivotTo(spot)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = anchor, p
			w.Parent = p
			p.Anchored = false
			p.Massless = true
		end
	end
	m.Parent = char
	return m
end

-- Where a hat goes on a model in its current pose: on top of a "Head" part if it has one, else on top of
-- the model's box, a little toward the front. Returns the CFrame and a good hat width.
function UI.HatSpot(model)
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local up = head.CFrame.UpVector
		local cf = CFrame.lookAt(head.Position, head.Position + model:GetPivot().LookVector, up)
		return cf * CFrame.new(0, head.Size.Y * 0.4, 0), math.min(head.Size.X, head.Size.Z) * 0.7
	end
	local cf, size = model:GetBoundingBox()
	return cf * CFrame.new(0, size.Y * 0.44, -size.Z * 0.1), math.min(size.X, size.Z) * 0.45
end

-- Puts outfit `name` on `model` (a child Model called "Outfit"). Returns the hat model.
function UI.Dress(model, name)
	local old = model:FindFirstChild("Outfit")
	if old then old:Destroy() end
	local hat = UI.BuildOutfit(name)
	if not hat then return nil end
	local spot, width = UI.HatSpot(model)
	hat:ScaleTo(math.max(0.2, width))
	hat:PivotTo(spot)
	hat.Parent = model
	return hat
end

-- Uses the generated 3D model from ReplicatedStorage.PetModels when there is one.
-- opts: Sleepy, Outfit (hat name), Variant ("Shiny" / "Rainbow" tints the picture), Yaw
function UI.Portrait(parent, Data, speciesName, props, opts)
	local template = UI.Template("PetModels", speciesName)
	local vf
	if not template then
		local s = Data.SpeciesByName[speciesName]
		vf = UI.Creature(parent, s.Color, s.Ear, opts, props)
	else
		vf = UI.ModelView(parent, template, props, opts)
	end
	if opts and opts.Outfit then
		local m = vf:FindFirstChild("Critter")
		if m then UI.Dress(m, opts.Outfit) end
	end
	if opts and opts.Variant then vf:SetAttribute("Variant", opts.Variant) end
	return vf
end

-- Shows any template model in a ViewportFrame, sized to fit and facing the camera.
function UI.ModelView(parent, template, props, opts)
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(200, 200, 200)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-1, -1, -1)
	for k, v in props or {} do vf[k] = v end
	local m = template:Clone()
	m.Name = "Critter"
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * 4.2 / math.max(size.X, size.Y, size.Z))
	m:PivotTo(CFrame.Angles(0, (opts and opts.Yaw) or math.pi, 0)) -- face the camera
	local box = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() - box.Position) -- center it
	m.Parent = vf
	if opts and opts.Sleepy then vf.ImageColor3 = Color3.fromRGB(185, 185, 215) end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(1.5, 1.2, 9), Vector3.new(0, 0.2, 0))
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = parent
	return vf
end

-- Bring a portrait to life. style: "idle" (gentle bounce) or "show" (bounce, turn, blink).
-- Set vf:SetAttribute("Hop", os.clock()) to make it do a happy hop.
function UI.Animate(vf, style, sleepy)
	local model = vf:FindFirstChild("Critter")
	if not model then return end
	local base = model:GetPivot()
	local eyes, lids = {}, {}
	for _, p in model:GetChildren() do
		if p.Name == "Eye" then table.insert(eyes, p) elseif p.Name == "Lid" then table.insert(lids, p) end
	end
	local seed = math.random() * 10
	local nextBlink = os.clock() + 1 + math.random() * 2
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not vf.Parent then conn:Disconnect() return end
		local t = os.clock() + seed
		local y, turn, tilt = 0, 0, 0
		if sleepy then
			y = math.sin(t * 1.2) * 0.12
			tilt = math.sin(t * 0.8) * 0.12
		else
			y = math.abs(math.sin(t * 2.2)) * (style == "show" and 0.45 or 0.25)
			if style == "show" then turn = math.sin(t * 0.6) * 0.6 end
			-- blink
			if os.clock() > nextBlink then
				for _, e in eyes do e.Transparency = 1 end
				for _, l in lids do l.Transparency = 0 end
				if os.clock() > nextBlink + 0.14 then
					for _, e in eyes do e.Transparency = 0 end
					for _, l in lids do l.Transparency = 1 end
					nextBlink = os.clock() + 2 + math.random() * 3
				end
			end
		end
		if style == "spin" then turn = t * 0.8 end
		local z, roll, pitch = 0, 0, 0
		local hop = vf:GetAttribute("Hop")
		if hop then
			local k = os.clock() - hop
			if k < 0.6 then
				y += math.sin(k / 0.6 * math.pi) * 1.6
				turn += k / 0.6 * math.pi * 2
			end
		end
		-- battle poses: vf:SetAttribute("Pose", "attack" | "hit" | "ko"), with PoseAt = os.clock()
		local pose, at = vf:GetAttribute("Pose"), vf:GetAttribute("PoseAt") or 0
		local k = os.clock() - at
		local speed = vf:GetAttribute("PoseSpeed") or 1
		if pose == "attack" and k < 0.45 / speed then -- wind up, then lunge at the viewer and spin a bit
			local f = k / (0.45 / speed)
			local lunge = f < 0.3 and -f / 0.3 * 0.8 or math.sin((f - 0.3) / 0.7 * math.pi) * 2.6
			z += lunge
			y += math.sin(f * math.pi) * 0.8
			pitch = -math.sin(f * math.pi) * 0.35
			turn += math.sin(f * math.pi) * 0.5
		elseif pose == "hit" and k < 0.4 / speed then -- knocked back with a shake, flash red
			local f = k / (0.4 / speed)
			z -= math.sin(f * math.pi) * 1.4
			roll = math.sin(f * math.pi * 6) * 0.25 * (1 - f)
			vf.ImageColor3 = Color3.new(1, 0.45 + 0.55 * f, 0.45 + 0.55 * f)
		elseif pose == "hit" then
			vf.ImageColor3 = Color3.new(1, 1, 1)
		elseif pose == "ko" then -- tip over and fade
			local f = math.min(1, k / 0.5)
			roll = f * 1.5
			y -= f * 1.2
			vf.ImageColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(120, 120, 130), f)
		elseif not sleepy then -- shiny pets shimmer gold, rainbow pets cycle colors
			local variant = vf:GetAttribute("Variant")
			if variant == "Rainbow" then
				vf.ImageColor3 = Color3.fromHSV((t * 0.25) % 1, 0.35, 1)
			elseif variant == "Shiny" then
				local s = 0.5 + math.sin(t * 3) * 0.5
				vf.ImageColor3 = Color3.new(1, 0.9 + 0.1 * s, 0.62 + 0.25 * s)
			end
		end
		model:PivotTo(base * CFrame.new(0, y, z) * CFrame.Angles(pitch, turn, tilt + roll))
	end)
end

-- Rarity effects for gear and loot: shine sweep, pulsing outline and floating sparkles.
local RARITY_FX = {Rare = 1, Epic = 2, Legendary = 3}
function UI.Glow(frame, rarityName, color)
	local level = RARITY_FX[rarityName]
	if not level then return end
	local TweenService = game:GetService("TweenService")
	local stroke = frame:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", frame)
	stroke.Color = color
	stroke.Thickness = 2 + level
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Thickness = 2 + level * 2.5, Transparency = 0.3}):Play()
	if level >= 2 then -- a shine that sweeps across
		local shine = Instance.new("Frame")
		shine.Name = "Shine"
		shine.Size = UDim2.fromScale(1, 1)
		shine.BackgroundColor3 = Color3.new(1, 1, 1)
		shine.BackgroundTransparency = 0
		shine.ZIndex = frame.ZIndex + 5
		local corner = frame:FindFirstChildOfClass("UICorner")
		if corner then corner:Clone().Parent = shine end
		local g = Instance.new("UIGradient", shine)
		g.Rotation = 25
		g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1),
			NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1)})
		g.Offset = Vector2.new(-1, 0)
		shine.Parent = frame
		TweenService:Create(g, TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0.6),
			{Offset = Vector2.new(1, 0)}):Play()
	end
	if level >= 2 then -- sparkles drifting up
		for i = 1, level * 3 do
			local s = Instance.new("TextLabel")
			s.BackgroundTransparency = 1
			s.Text = level == 3 and "✦" or "✧"
			s.TextColor3 = level == 3 and Color3.fromRGB(255, 230, 120) or Color3.new(1, 1, 1)
			s.TextScaled = true
			s.Size = UDim2.fromOffset(12, 12)
			s.ZIndex = frame.ZIndex + 6
			local x = math.random()
			s.Position = UDim2.fromScale(x, 0.9)
			s.Parent = frame
			TweenService:Create(s, TweenInfo.new(1.2 + math.random(), Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, false, math.random() * 1.5),
				{Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.2, 0.05), TextTransparency = 1, Rotation = 180}):Play()
		end
	end
end

return UI
