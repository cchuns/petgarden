-- Critter Acres: ExpeditionBooth (StarterPlayerScripts)
-- Opens from the Expedition Booth prompt. Kid-friendly steps:
-- 1) pick a place (cards with little 3D pictures), 2) pick a pet, 3) GO!
-- Also shows pets that are away, with progress bars and a Collect button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))
local actionFn = ReplicatedStorage:WaitForChild("CritterAction")
local stateEvent = ReplicatedStorage:WaitForChild("CritterState")
local player = Players.LocalPlayer

local CREAM, BROWN = Color3.fromRGB(255, 250, 235), Color3.fromRGB(90, 60, 40)
local GREEN, GREY = Color3.fromRGB(110, 210, 90), Color3.fromRGB(190, 190, 190)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function round(o, r) new("UICorner", {CornerRadius = UDim.new(0, r or 14)}, o) return o end
local function stroke(o, color, th) return new("UIStroke", {Color = color, Thickness = th or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function text(props, parent)
	local t = new("TextLabel", {BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = BROWN}, parent)
	for k, v in props do t[k] = v end
	return t
end
local function btn(props, parent, onClick)
	local b = new("TextButton", {Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = BROWN, AutoButtonColor = true}, parent)
	for k, v in props do b[k] = v end
	round(b)
	if onClick then b.Activated:Connect(onClick) end
	return b
end

local function niceTime(secs)
	if secs >= 3600 then
		local h = secs / 3600
		return h == 1 and "1 hour" or ("%d hours"):format(h)
	end
	return ("%d min"):format(math.max(1, secs // 60))
end
local function timeLeft(at)
	local s = math.max(0, at - os.time())
	if s >= 3600 then return ("%dh %dm"):format(s // 3600, (s % 3600) // 60) end
	if s >= 60 then return ("%dm %ds"):format(s // 60, s % 60) end
	return ("%ds"):format(s)
end
local function chanceInfo(chance)
	if chance >= 0.8 then return "😀 Great chance!", Color3.fromRGB(110, 210, 90) end
	if chance >= 0.5 then return "🙂 Good chance", Color3.fromRGB(255, 205, 70) end
	return "😬 Risky!", Color3.fromRGB(255, 130, 100)
end

---------------------------------------------------------------- little 3D pictures
local function vpart(vf, props)
	local p = new("Part", {Anchored = true, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth}, nil)
	for k, v in props do p[k] = v end
	p.Parent = vf
	return p
end
local function ball(vf, pos, size, color, neon)
	return vpart(vf, {Shape = Enum.PartType.Ball, Size = Vector3.one * size, Position = pos, Color = color,
		Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic})
end
local function disc(vf, pos, d, h, color, neon) -- vertical cylinder
	return vpart(vf, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color, Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic})
end
local function cone(vf, pos, radius, height, color, topColor)
	local steps = 7
	for i = 0, steps - 1 do
		local r = radius * (1 - i / steps)
		disc(vf, pos + Vector3.new(0, height / steps * (i + 0.5), 0), r * 2, height / steps, (topColor and i >= steps - 2) and topColor or color)
	end
end
local function mushroom(vf, pos, s, capColor)
	disc(vf, pos + Vector3.new(0, 1.5 * s, 0), 0.9 * s, 3 * s, Color3.fromRGB(250, 240, 220))
	local cap = vpart(vf, {Size = Vector3.new(4, 1.8, 4) * s, Position = pos + Vector3.new(0, 3.2 * s, 0), Color = capColor})
	new("SpecialMesh", {MeshType = Enum.MeshType.Sphere}, cap)
	ball(vf, pos + Vector3.new(0.8 * s, 3.9 * s, 0.6 * s), 0.6 * s, Color3.new(1, 1, 1))
	ball(vf, pos + Vector3.new(-0.7 * s, 3.8 * s, 0.9 * s), 0.5 * s, Color3.new(1, 1, 1))
end

local SCENES = {}
function SCENES.Meadow(vf)
	vf.BackgroundColor3 = Color3.fromRGB(160, 215, 255)
	disc(vf, Vector3.new(0, -0.5, 0), 22, 1, Color3.fromRGB(120, 210, 90))
	ball(vf, Vector3.new(-4, -2.5, -3), 9, Color3.fromRGB(100, 190, 80))
	ball(vf, Vector3.new(5, -3.5, -4), 11, Color3.fromRGB(130, 215, 95))
	ball(vf, Vector3.new(6, 7, -8), 2.5, Color3.fromRGB(255, 230, 90), true)
	local colors = {Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 230, 90), Color3.new(1, 1, 1)}
	for i = 1, 9 do
		ball(vf, Vector3.new(-6 + i * 1.4, 0.3, 2 + (i % 3)), 0.7, colors[i % 3 + 1])
	end
end
function SCENES.Forest(vf)
	vf.BackgroundColor3 = Color3.fromRGB(210, 180, 245)
	disc(vf, Vector3.new(0, -0.5, 0), 22, 1, Color3.fromRGB(70, 140, 70))
	mushroom(vf, Vector3.new(-3.5, 0, -2), 1.3, Color3.fromRGB(235, 70, 80))
	mushroom(vf, Vector3.new(3, 0, -3), 1.6, Color3.fromRGB(170, 90, 230))
	mushroom(vf, Vector3.new(0.5, 0, 2.5), 0.7, Color3.fromRGB(255, 150, 60))
end
function SCENES.Peaks(vf)
	vf.BackgroundColor3 = Color3.fromRGB(200, 230, 255)
	disc(vf, Vector3.new(0, -0.5, 0), 22, 1, Color3.fromRGB(235, 245, 255))
	cone(vf, Vector3.new(-3, 0, -3), 5, 9, Color3.fromRGB(140, 170, 210), Color3.new(1, 1, 1))
	cone(vf, Vector3.new(3.5, 0, -1), 4, 6.5, Color3.fromRGB(160, 190, 225), Color3.new(1, 1, 1))
	for i = 1, 8 do
		ball(vf, Vector3.new(-7 + i * 1.8, 3 + (i % 3) * 2, 2), 0.4, Color3.new(1, 1, 1))
	end
end
function SCENES.Caves(vf)
	vf.BackgroundColor3 = Color3.fromRGB(45, 30, 80)
	disc(vf, Vector3.new(0, -0.5, 0), 22, 1, Color3.fromRGB(70, 50, 100))
	local cols = {Color3.fromRGB(170, 110, 255), Color3.fromRGB(90, 230, 255), Color3.fromRGB(255, 120, 230)}
	for i, x in {-5, -2.5, 0, 2.5, 5} do
		local h = 3 + (i % 3) * 1.5
		vpart(vf, {Size = Vector3.new(1.2, h, 1.2), CFrame = CFrame.new(x, h / 2, -1 + (i % 2) * 2) * CFrame.Angles(0, math.rad(45), math.rad((i % 2 == 0) and 12 or -12)),
			Color = cols[i % 3 + 1], Material = Enum.Material.Neon})
	end
end
function SCENES.Volcano(vf)
	vf.BackgroundColor3 = Color3.fromRGB(255, 160, 100)
	disc(vf, Vector3.new(0, -0.5, 0), 22, 1, Color3.fromRGB(90, 60, 50))
	cone(vf, Vector3.new(0, 0, -2), 6, 8, Color3.fromRGB(70, 55, 55))
	disc(vf, Vector3.new(0, 8.1, -2), 2.4, 0.4, Color3.fromRGB(255, 120, 30), true)
	for i = 1, 4 do
		ball(vf, Vector3.new(-1.5 + i * 0.8, 9 + i * 0.7, -2), 0.6 + i * 0.1, Color3.fromRGB(255, 90 + i * 30, 30), true)
		ball(vf, Vector3.new(-1 + i * 0.6, 11.5 + i, -3), 1.2 + i * 0.3, Color3.fromRGB(150, 140, 140))
	end
	vpart(vf, {Size = Vector3.new(0.8, 5, 0.3), CFrame = CFrame.new(1.8, 5.5, 1.2) * CFrame.Angles(0, 0, math.rad(-35)),
		Color = Color3.fromRGB(255, 110, 30), Material = Enum.Material.Neon})
end
local function picture(sceneName, parent, props)
	local vf = new("ViewportFrame", {Ambient = Color3.fromRGB(170, 170, 170), LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1)}, parent)
	for k, v in props do vf[k] = v end
	round(vf)
	SCENES[sceneName](vf)
	local cam = new("Camera", {FieldOfView = 45, CFrame = CFrame.lookAt(Vector3.new(0, 6, 17), Vector3.new(0, 3, 0))}, vf)
	vf.CurrentCamera = cam
	return vf
end

---------------------------------------------------------------- window (no words: pictures, icons, numbers)
local CritterUI_ = CritterUI
local WHITE = Color3.new(1, 1, 1)
local gui = new("ScreenGui", {Name = "ExpeditionGui", ResetOnSpawn = false, DisplayOrder = 5, Enabled = false}, player:WaitForChild("PlayerGui"))
new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Active = true}, gui)
local win = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.96, 0.92),
	BackgroundColor3 = CREAM, ClipsDescendants = true}, gui), 22)
stroke(win, Color3.fromRGB(255, 160, 60), 5)
new("UISizeConstraint", {MaxSize = Vector2.new(1040, 680)}, win)
local closeBtn = btn({Text = "✖", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(56, 56),
	BackgroundColor3 = Color3.fromRGB(255, 120, 110), TextColor3 = WHITE, ZIndex = 20}, win)

-- LEFT: big picture of the chosen place + place thumbnails
local left = new("Frame", {Position = UDim2.fromOffset(14, 14), Size = UDim2.new(0.52, -20, 1, -28), BackgroundTransparency = 1}, win)
local bigHolder = round(new("Frame", {Size = UDim2.new(1, 0, 0.78, 0), BackgroundColor3 = Color3.fromRGB(40, 40, 60), ClipsDescendants = true}, left), 20)
local bigStroke = stroke(bigHolder, WHITE, 5)
local starsChip = round(text({Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(170, 44), BackgroundTransparency = 0.15,
	BackgroundColor3 = Color3.fromRGB(40, 30, 60), TextColor3 = WHITE, ZIndex = 5}, bigHolder), 14)
local timeChip = round(text({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(120, 44), BackgroundTransparency = 0.15,
	BackgroundColor3 = Color3.fromRGB(40, 30, 60), TextColor3 = WHITE, ZIndex = 5}, bigHolder), 14)
local thumbs = new("Frame", {Position = UDim2.new(0, 0, 0.8, 0), Size = UDim2.new(1, 0, 0.2, 0), BackgroundTransparency = 1}, left)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.02, 0)}, thumbs)

-- RIGHT: drops, sort bar, pet picker, away strip, GO
local right = new("Frame", {Position = UDim2.new(0.52, 6, 0, 76), Size = UDim2.new(0.48, -20, 1, -90), BackgroundTransparency = 1}, win)
local drops = new("Frame", {Size = UDim2.new(1, 0, 0, 96), BackgroundTransparency = 1}, right)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0)}, drops)
local sortBar = new("Frame", {Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1}, right)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.015, 0)}, sortBar)
local petGrid = new("ScrollingFrame", {Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 1, -330), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 8, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, right)
new("UIGridLayout", {CellSize = UDim2.fromOffset(96, 116), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder}, petGrid)
local away = round(new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -84), Size = UDim2.new(1, 0, 0, 80),
	BackgroundColor3 = Color3.fromRGB(255, 240, 210)}, right), 14)
local awayRow = new("ScrollingFrame", {Position = UDim2.fromOffset(52, 4), Size = UDim2.new(1, -56, 1, -8), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new()}, away)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8)}, awayRow)
text({Text = "🎒", Position = UDim2.fromOffset(6, 0), Size = UDim2.new(0, 44, 1, 0)}, away)
local goBtn = btn({Text = "🎒 ➜", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 74),
	BackgroundColor3 = GREY, TextColor3 = WHITE}, right)
stroke(goBtn, WHITE, 4)

-- result popup (pictures only)
local result = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.6),
	BackgroundColor3 = Color3.fromRGB(255, 235, 150), Visible = false, ZIndex = 40}, win), 22)
stroke(result, Color3.fromRGB(255, 160, 60), 6)
local resultPic = new("Frame", {Position = UDim2.fromScale(0.04, 0.08), Size = UDim2.fromScale(0.36, 0.62), BackgroundTransparency = 1, ZIndex = 41}, result)
local resultFace = text({Position = UDim2.fromScale(0.42, 0.05), Size = UDim2.fromScale(0.54, 0.25), ZIndex = 41}, result)
local resultLoot = new("Frame", {Position = UDim2.fromScale(0.42, 0.33), Size = UDim2.fromScale(0.54, 0.38), BackgroundTransparency = 1, ZIndex = 41}, result)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.04, 0)}, resultLoot)
btn({Text = "👍", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromScale(0.3, 0.2),
	BackgroundColor3 = GREEN, TextColor3 = WHITE, ZIndex = 42}, result, function() result.Visible = false end)

local function tileOf(parent, icon, value, color, props)
	local t = round(new("Frame", {Size = UDim2.new(0.235, 0, 1, 0), BackgroundColor3 = color or WHITE, ZIndex = props and props.ZIndex or 1}, parent), 14)
	text({Text = icon, Size = UDim2.fromScale(1, 0.6), ZIndex = t.ZIndex + 1}, t)
	text({Text = value, Position = UDim2.fromScale(0, 0.58), Size = UDim2.fromScale(1, 0.4), ZIndex = t.ZIndex + 1}, t)
	return t
end

local function showResult(res)
	if type(res) ~= "table" then return end
	for _, ch in resultPic:GetChildren() do ch:Destroy() end
	for _, ch in resultLoot:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local vf = CritterUI_.Portrait(resultPic, Data, res.Species, {Size = UDim2.fromScale(1, 1), ZIndex = 42}, {Sleepy = res.Outcome == "Exhausted"})
	CritterUI_.Animate(vf, "show", res.Outcome == "Exhausted")
	if res.Outcome == "Great" then
		vf:SetAttribute("Hop", os.clock())
		resultFace.Text = "🎉"
		tileOf(resultLoot, "💰", tostring(res.Coins), WHITE, {ZIndex = 42}).Size = UDim2.new(0.3, 0, 1, 0)
		local crop = Data.CropByName[res.Berry]
		tileOf(resultLoot, crop.Icon, "x" .. res.Count, crop.Color:Lerp(WHITE, 0.5), {ZIndex = 42}).Size = UDim2.new(0.3, 0, 1, 0)
		if res.Egg then
			local egg = tileOf(resultLoot, Data.Eggs[res.Egg].Icon, "🥚", Color3.fromRGB(255, 225, 120), {ZIndex = 42})
			egg.Size = UDim2.new(0.3, 0, 1, 0)
			CritterUI_.Glow(egg, "Epic", Color3.fromRGB(255, 200, 60))
		end
	elseif res.Outcome == "Lost" then
		resultFace.Text = "💨"
		tileOf(resultLoot, "💰", tostring(res.Coins), WHITE, {ZIndex = 42}).Size = UDim2.new(0.3, 0, 1, 0)
	else
		resultFace.Text = "😴"
		tileOf(resultLoot, "📦", "0", Color3.fromRGB(220, 220, 220), {ZIndex = 42}).Size = UDim2.new(0.3, 0, 1, 0)
		tileOf(resultLoot, "🔋", "0%", Color3.fromRGB(255, 180, 170), {ZIndex = 42}).Size = UDim2.new(0.3, 0, 1, 0)
	end
	result.Visible = true
	result.Size = UDim2.fromScale(0.4, 0.4)
	TweenService:Create(result, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Size = UDim2.fromScale(0.62, 0.6)}):Play()
end

---------------------------------------------------------------- state + rendering
local state = nil
local pickedPlace, pickedPet = 1, nil
local sortBy, filter = "Power", "All"
local render, renderAway
local bigPic

local function setBigPicture()
	if bigPic then bigPic:Destroy() end
	local dest = Data.Expeditions[pickedPlace]
	bigPic = picture(dest.Scene, bigHolder, {Size = UDim2.fromScale(1, 1)})
	bigStroke.Color = dest.Color
	starsChip.Text = string.rep("⭐", dest.Stars)
	timeChip.Text = "⏱ " .. niceTime(dest.Secs):gsub(" hours?", "h"):gsub(" min", "m")
end

-- slowly orbit the big picture's camera
RunService.RenderStepped:Connect(function()
	if gui.Enabled and bigPic and bigPic.CurrentCamera then
		local a = os.clock() * 0.25
		bigPic.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(math.sin(a) * 15, 6 + math.sin(a * 0.7), math.cos(a) * 15), Vector3.new(0, 3, 0))
	end
end)

local thumbStrokes = {}
for i, dest in Data.Expeditions do
	local b = btn({Text = "", Size = UDim2.new(0.18, 0, 1, 0), BackgroundColor3 = dest.Color, AutoButtonColor = false}, thumbs, function()
		pickedPlace = i
		setBigPicture()
		render()
	end)
	b.UICorner.CornerRadius = UDim.new(0.5, 0)
	picture(dest.Scene, b, {Position = UDim2.fromScale(0.06, 0.06), Size = UDim2.fromScale(0.88, 0.88)}).UICorner.CornerRadius = UDim.new(0.5, 0)
	thumbStrokes[i] = stroke(b, WHITE, 3)
end

local function petChance(p)
	return Data.TripChance(Data.PetPower(p.Rarity, p.Level), Data.Expeditions[pickedPlace].Need)
end

-- sort / filter buttons (icons only)
local sortButtons = {}
for _, s in {{"Power", "💪"}, {"Level", "⭐"}, {"Rarity", "💎"}, {"All", "🐾"}, {"Worker", "🏡"}, {"Battler", "📦"}} do
	local isFilter = s[1] == "All" or s[1] == "Worker" or s[1] == "Battler"
	sortButtons[s[1]] = btn({Text = s[2], Size = UDim2.new(0.152, 0, 1, 0), BackgroundColor3 = WHITE}, sortBar, function()
		if isFilter then filter = s[1] else sortBy = s[1] end
		render()
	end)
end

local function homePets()
	local list = {}
	for _, p in state and state.Pets or {} do
		if not p.Trip and (filter == "All" or (filter == "Worker") == (not p.Stored)) then table.insert(list, p) end
	end
	table.sort(list, function(a, b)
		if (a.Rest ~= nil) ~= (b.Rest ~= nil) then return b.Rest ~= nil end -- rested pets first
		if sortBy == "Level" and a.Level ~= b.Level then return a.Level > b.Level end
		if sortBy == "Rarity" then
			local ra, rb = Data.Rarities[a.Rarity].Order, Data.Rarities[b.Rarity].Order
			if ra ~= rb then return ra > rb end
		end
		return Data.PetPower(a.Rarity, a.Level) > Data.PetPower(b.Rarity, b.Level)
	end)
	return list
end

function render()
	if not gui.Enabled then return end
	renderAway()
	for i, st in thumbStrokes do
		st.Thickness = i == pickedPlace and 6 or 2
		st.Color = i == pickedPlace and Color3.fromRGB(255, 220, 60) or WHITE
	end
	for key, b in sortButtons do
		local on = key == sortBy or key == filter
		b.BackgroundColor3 = on and Color3.fromRGB(255, 225, 120) or WHITE
	end
	-- pets
	for _, ch in petGrid:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local pets = homePets()
	local picked
	for _, p in pets do
		if p.Id == pickedPet and not p.Rest then picked = p end
	end
	if not picked then pickedPet = nil end
	for i, p in pets do
		local on = pickedPet == p.Id
		local resting = p.Rest ~= nil
		local rarity = Data.Rarities[p.Rarity]
		local b = btn({Text = "", LayoutOrder = i, AutoButtonColor = not resting,
			BackgroundColor3 = on and Color3.fromRGB(255, 225, 120) or (resting and Color3.fromRGB(205, 205, 205) or WHITE)}, petGrid, function()
			if resting then return end
			pickedPet = p.Id
			render()
		end)
		stroke(b, rarity.Color, on and 6 or 3)
		local vf = CritterUI_.Portrait(b, Data, p.Species, {Size = UDim2.new(1, 0, 0.74, 0)}, {Sleepy = resting})
		CritterUI_.Animate(vf, on and "show" or "idle", resting)
		local lv = round(text({Text = tostring(p.Level), Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(28, 24), BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(255, 190, 40), TextColor3 = WHITE}, b), 12)
		lv.ZIndex = 3
		if resting then
			text({Text = "💤", Position = UDim2.fromScale(0, 0.72), Size = UDim2.fromScale(1, 0.26)}, b)
		else
			local chance = petChance(p)
			local face, color = chanceInfo(chance)
			local c = text({Text = ("%s %d%%"):format(face:match("^%S+"), math.floor(chance * 100 + 0.5)), Position = UDim2.fromScale(0, 0.72),
				Size = UDim2.fromScale(1, 0.26), TextColor3 = color, TextStrokeTransparency = 0.5}, b)
		end
		if on then
			round(text({Text = "✔", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(26, 26),
				BackgroundTransparency = 0, BackgroundColor3 = GREEN, TextColor3 = WHITE, ZIndex = 3}, b), 13)
		end
	end
	if #pets == 0 then
		text({Text = "🐾❓", Size = UDim2.fromOffset(96, 116)}, petGrid)
	end
	-- drops for this place (and the picked pet's odds)
	for _, ch in drops:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local dest = Data.Expeditions[pickedPlace]
	local crop = Data.CropByName[dest.Berry]
	local egg = Data.Eggs[dest.Egg]
	if picked then
		local chance = petChance(picked)
		local face, color = chanceInfo(chance)
		local t = tileOf(drops, face:match("^%S+"), ("%d%%"):format(chance * 100 + 0.5), color:Lerp(WHITE, 0.5))
		if chance < Data.RiskyChance then
			text({Text = "⚠️", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(26, 26), ZIndex = 3}, t)
		end
	else
		tileOf(drops, "🐾", "?", Color3.fromRGB(235, 235, 235))
	end
	tileOf(drops, "💰", tostring(dest.Coins), WHITE)
	tileOf(drops, crop.Icon, "x" .. dest.Berries, crop.Color:Lerp(WHITE, 0.55))
	local eggTile = tileOf(drops, egg.Icon, ("%d%%"):format(dest.EggChance * 100), Color3.fromRGB(255, 240, 200))
	if dest.Egg ~= "Mystery" then CritterUI_.Glow(eggTile, dest.Egg == "Lava" and "Legendary" or "Epic", dest.Color) end
	goBtn.BackgroundColor3 = picked and GREEN or GREY
end

function renderAway()
	for _, ch in awayRow:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	for _, p in state and state.Pets or {} do
		if p.Trip then
			local dest = Data.Expeditions[p.Trip.Index] or Data.Expeditions[1]
			local ready = os.time() >= p.Trip.ReturnAt
			local b = btn({Text = "", Size = UDim2.fromOffset(64, 68), BackgroundColor3 = ready and Color3.fromRGB(255, 225, 120) or WHITE}, awayRow, function()
				if ready then showResult(actionFn:InvokeServer("TripClaim", p.Id)) end
			end)
			stroke(b, dest.Color, 3)
			local vf = CritterUI_.Portrait(b, Data, p.Species, {Size = UDim2.new(1, 0, 0.78, 0)})
			if ready then
				CritterUI_.Animate(vf, "show")
				text({Text = "🎁", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 2, 0, -2), Size = UDim2.fromOffset(26, 26), ZIndex = 3}, b)
			else
				local total = dest.Secs / (workspace:GetAttribute("CritterTimeScale") or 1)
				local frac = math.clamp(1 - (p.Trip.ReturnAt - os.time()) / total, 0, 1)
				local bg = round(new("Frame", {Position = UDim2.new(0.08, 0, 0.82, 0), Size = UDim2.new(0.84, 0, 0.12, 0), BackgroundColor3 = Color3.fromRGB(220, 210, 195)}, b), 6)
				round(new("Frame", {Size = UDim2.fromScale(frac, 1), BackgroundColor3 = dest.Color}, bg), 6)
			end
		end
	end
end

goBtn.Activated:Connect(function()
	if not pickedPet then return end
	local id = pickedPet
	pickedPet = nil
	local msg = actionFn:InvokeServer("Trip", id, pickedPlace)
	if type(msg) == "string" and msg:find("😴") then return end
	stateEvent:FireServer()
end)

stateEvent.OnClientEvent:Connect(function(s)
	state = s
	render()
end)

local function open()
	gui.Enabled = true
	result.Visible = false
	setBigPicture()
	stateEvent:FireServer()
	render()
end
closeBtn.Activated:Connect(function() gui.Enabled = false end)

local booth = workspace:WaitForChild("CritterAcres"):WaitForChild("ExpeditionBooth")
booth:WaitForChild("Counter"):WaitForChild("BoothPrompt").Triggered:Connect(open)

task.spawn(function() -- keep the away bars moving
	while true do
		task.wait(1)
		if gui.Enabled and not result.Visible then renderAway() end
	end
end)
