-- Critter Acres world builder. Run once in Studio (Edit mode, command bar or MCP).
-- Rebuilds Workspace.CritterAcres from scratch.
local old = workspace:FindFirstChild("CritterAcres")
if old then old:Destroy() end
for _, s in workspace:GetChildren() do
	if s:IsA("SpawnLocation") then s:Destroy() end
end

local G = 0.1 -- ground top height
local root = Instance.new("Model")
root.Name = "CritterAcres"
root:SetAttribute("GroundY", G)

local function P(parent, props)
	local p = Instance.new(props.Class or "Part")
	props.Class = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end

local function sign(parent, text, offset, w)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Sign"
	bb.Size = UDim2.fromOffset(w or 220, 60)
	bb.StudsOffset = offset
	bb.MaxDistance = 90
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
	t.BackgroundTransparency = 0.1
	t.TextColor3 = Color3.fromRGB(90, 60, 40)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 12)
	t.Parent = bb
	bb.Parent = parent
	return bb
end

-- Ground
P(root, {Name = "FarmGround", Size = Vector3.new(80, 1, 80), Position = Vector3.new(0, G - 0.5, 0),
	Color = Color3.fromRGB(120, 200, 90), Material = Enum.Material.Grass})
local meadow = P(root, {Name = "Meadow", Size = Vector3.new(110, 1, 70), Position = Vector3.new(0, G - 0.5, -75),
	Color = Color3.fromRGB(160, 225, 115), Material = Enum.Material.Grass})
P(root, {Name = "Path", Size = Vector3.new(8, 0.1, 18), Position = Vector3.new(0, G + 0.05, -44),
	Color = Color3.fromRGB(225, 200, 150), Material = Enum.Material.Sand, CanCollide = false})

-- Plots (4 x 3)
local plots = Instance.new("Folder")
plots.Name = "Plots"
local n = 0
for _, x in {-12, -4, 4, 12} do
	for _, z in {-14, -6, 2} do
		n += 1
		P(plots, {Name = "Plot" .. n, Size = Vector3.new(6, 0.8, 6), Position = Vector3.new(x, G + 0.4, z),
			Color = Color3.fromRGB(150, 100, 62), Material = Enum.Material.Ground})
	end
end
plots.Parent = root

-- Spawn
local spawn = P(root, {Class = "SpawnLocation", Name = "Spawn", Size = Vector3.new(8, 1, 8),
	Position = Vector3.new(0, G + 0.5, 26), Color = Color3.fromRGB(255, 220, 120), Neutral = true, Duration = 0})
sign(spawn, "Welcome to Critter Acres!", Vector3.new(0, 6, 0), 280)

-- Sell stand
local stand = Instance.new("Model")
stand.Name = "SellStand"
local counter = P(stand, {Name = "Counter", Size = Vector3.new(8, 3, 3), Position = Vector3.new(24, G + 1.5, 12),
	Color = Color3.fromRGB(190, 130, 80), Material = Enum.Material.Wood})
for _, o in {Vector3.new(-3.7, 0, -1.2), Vector3.new(3.7, 0, -1.2), Vector3.new(-3.7, 0, 1.2), Vector3.new(3.7, 0, 1.2)} do
	P(stand, {Size = Vector3.new(0.5, 7, 0.5), Position = Vector3.new(24, G + 3.5, 12) + o, Color = Color3.fromRGB(240, 235, 225)})
end
P(stand, {Name = "Roof", Size = Vector3.new(9.5, 0.6, 4.5), Position = Vector3.new(24, G + 7.2, 12), Color = Color3.fromRGB(255, 150, 190)})
for i = -2, 2 do
	P(stand, {Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), Position = Vector3.new(24 + i * 1.3, G + 3.5, 12),
		Color = Color3.fromRGB(255, 110, 170), CanCollide = false})
end
sign(counter, "Market Stall: sell berries here", Vector3.new(0, 7.5, 0), 260)
stand.PrimaryPart = counter
stand.Parent = root

-- Build pads
local pads = Instance.new("Folder")
pads.Name = "BuildPads"
local function pad(name, pos, kind, cost, label, perk)
	local p = P(pads, {Name = name, Size = Vector3.new(14, 0.2, 14), Position = pos,
		Color = Color3.fromRGB(235, 220, 175), Material = Enum.Material.SmoothPlastic})
	p:SetAttribute("Building", kind)
	p:SetAttribute("Cost", cost)
	p:SetAttribute("Label", label)
	p:SetAttribute("Perk", perk)
	sign(p, ("Build: %s\n%d coins"):format(label, cost), Vector3.new(0, 4, 0))
end
pad("HutPad", Vector3.new(-24, G + 0.1, -8), "CritterHut", 20, "Critter Hut", "+2 critter friends")
pad("StandPad", Vector3.new(-24, G + 0.1, 16), "FruitStand", 30, "Fruit Stand", "Puffberries sell for more")
pads.Parent = root

-- Fence (gap on the north side leads to the meadow)
local fence = Instance.new("Model")
fence.Name = "Fence"
local L, WHITE = 36, Color3.fromRGB(250, 245, 235)
local corners = {Vector3.new(-L, 0, -L), Vector3.new(L, 0, -L), Vector3.new(L, 0, L), Vector3.new(-L, 0, L)}
for i = 1, 4 do
	local a, b = corners[i], corners[i % 4 + 1]
	for s = 0, 11 do
		local p1 = a:Lerp(b, s / 12)
		local p2 = a:Lerp(b, (s + 1) / 12)
		local mid = (p1 + p2) / 2
		P(fence, {Size = Vector3.new(0.8, 3.4, 0.8), Position = p1 + Vector3.new(0, G + 1.7, 0), Color = WHITE})
		if not (i == 1 and math.abs(mid.X) < 6) then
			for _, h in {1.3, 2.6} do
				local up = Vector3.new(0, G + h, 0)
				P(fence, {Size = Vector3.new(0.35, 0.35, (p2 - p1).Magnitude), CFrame = CFrame.lookAt(mid + up, p2 + up), Color = WHITE})
			end
		end
	end
end
fence.Parent = root

-- Decor: trees and flowers
local decor = Instance.new("Model")
decor.Name = "Decor"
local function tree(x, z, s)
	P(decor, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(6 * s, 1.6 * s, 1.6 * s),
		CFrame = CFrame.new(x, G + 3 * s, z) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(130, 90, 60)})
	P(decor, {Shape = Enum.PartType.Ball, Size = Vector3.one * 7 * s, Position = Vector3.new(x, G + 7 * s, z),
		Color = Color3.fromRGB(80 + math.random(0, 40), 170 + math.random(0, 30), 80), Material = Enum.Material.Grass})
end
for _, t in {{-44, 30}, {44, 30}, {-44, -10}, {45, -25}, {-48, -60}, {48, -70}, {-30, -100}, {25, -98}, {-10, -80}} do
	tree(t[1], t[2], 0.9 + math.random() * 0.4)
end
local flowerColors = {Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 220, 90), Color3.fromRGB(170, 140, 255), Color3.fromRGB(255, 255, 255)}
for _ = 1, 50 do
	local pos = meadow.Position + Vector3.new((math.random() - 0.5) * 100, 0, (math.random() - 0.5) * 60)
	P(decor, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, Position = Vector3.new(pos.X, G + 0.4, pos.Z),
		Color = flowerColors[math.random(#flowerColors)], CanCollide = false})
end
decor.Parent = root

-- What's New board near spawn
local board = P(root, {Name = "NewsBoard", Size = Vector3.new(10, 6, 0.6), CFrame = CFrame.new(12, 4.1, 30) * CFrame.Angles(0, math.rad(200), 0),
	Color = Color3.fromRGB(190, 130, 80), Material = Enum.Material.Wood})
for _, x in {-4, 4} do
	P(board, {Size = Vector3.new(0.6, 4, 0.6), CFrame = board.CFrame * CFrame.new(x, -4.2, 0), Color = Color3.fromRGB(150, 100, 60)})
end
local sg = Instance.new("SurfaceGui")
sg.Face = Enum.NormalId.Front
sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sg.PixelsPerStud = 40
sg.Parent = board
local news = Instance.new("TextLabel")
news.Size = UDim2.fromScale(1, 1)
news.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
news.TextColor3 = Color3.fromRGB(90, 60, 40)
news.Font = Enum.Font.FredokaOne
news.TextScaled = true
news.Text = "WHAT'S NEW!\nSend pets on trips & hatch eggs\nFill your Critter Book\nDaily quests & login gifts\nWeather events & Golden harvests"
news.Parent = sg

root.Parent = workspace
return "built"
