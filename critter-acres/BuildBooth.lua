-- Critter Acres: Expedition Booth builder. Run once in Edit mode (also included in Builder.lua).
local root = workspace.CritterAcres
local G = root:GetAttribute("GroundY") or 0.1
local old = root:FindFirstChild("ExpeditionBooth")
if old then old:Destroy() end

local booth = Instance.new("Model")
booth.Name = "ExpeditionBooth"
local cf = CFrame.lookAt(Vector3.new(-14, G, 31), Vector3.new(0, G, 26))
local function P(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = booth
	return p
end

local counter = P({Name = "Counter", Size = Vector3.new(9, 3, 3), CFrame = cf * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(70, 170, 200)})
P({Size = Vector3.new(9.4, 0.4, 3.4), CFrame = cf * CFrame.new(0, 3.2, 0), Color = Color3.fromRGB(255, 240, 200)})
for _, x in {-4.3, 4.3} do
	P({Size = Vector3.new(0.6, 9, 0.6), CFrame = cf * CFrame.new(x, 4.5, 1.2), Color = Color3.fromRGB(250, 250, 250)})
end
for i = 0, 5 do -- striped awning
	P({Size = Vector3.new(1.6, 0.4, 4.5), CFrame = cf * CFrame.new(-4 + i * 1.6, 9.1, 0.4) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = i % 2 == 0 and Color3.fromRGB(255, 140, 60) or Color3.new(1, 1, 1)})
end
local board = P({Name = "MapBoard", Size = Vector3.new(8.4, 5, 0.4), CFrame = cf * CFrame.new(0, 6, 1.4), Color = Color3.fromRGB(150, 100, 60)})
local sg = Instance.new("SurfaceGui")
sg.Face = Enum.NormalId.Front
sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sg.PixelsPerStud = 40
sg.Parent = board
local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(255, 245, 210)
bg.Parent = sg
local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.35)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(90, 60, 40)
title.Text = "🗺️ EXPEDITIONS"
title.Parent = bg
local row = Instance.new("Frame")
row.Position = UDim2.fromScale(0.03, 0.4)
row.Size = UDim2.fromScale(0.94, 0.55)
row.BackgroundTransparency = 1
row.Parent = bg
local layout = Instance.new("UIListLayout", row)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0.02, 0)
for _, s in {{"🌼", Color3.fromRGB(120, 210, 90)}, {"🍄", Color3.fromRGB(200, 120, 230)}, {"🏔️", Color3.fromRGB(120, 200, 255)},
	{"💎", Color3.fromRGB(150, 110, 255)}, {"🌋", Color3.fromRGB(255, 110, 60)}} do
	local b = Instance.new("TextLabel")
	b.Size = UDim2.fromScale(0.18, 1)
	b.BackgroundColor3 = s[2]
	b.TextScaled = true
	b.Text = s[1]
	Instance.new("UICorner", b).CornerRadius = UDim.new(0.3, 0)
	b.Parent = row
end

local bb = Instance.new("BillboardGui")
bb.Size = UDim2.fromOffset(240, 50)
bb.StudsOffset = Vector3.new(0, 9, 0)
bb.MaxDistance = 100
local t = Instance.new("TextLabel")
t.Size = UDim2.fromScale(1, 1)
t.BackgroundColor3 = Color3.fromRGB(255, 200, 90)
t.Font = Enum.Font.FredokaOne
t.TextScaled = true
t.TextColor3 = Color3.fromRGB(90, 60, 40)
t.Text = "Expedition Booth"
Instance.new("UICorner", t).CornerRadius = UDim.new(0, 12)
t.Parent = bb
bb.Parent = counter

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "BoothPrompt"
prompt.ActionText = "Open"
prompt.ObjectText = "Expedition Booth"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Parent = counter

booth.PrimaryPart = counter
booth.Parent = root
return "booth built"
