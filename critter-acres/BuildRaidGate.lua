-- Critter Acres: Raid Gate builder. Run once in Edit mode.
local root = workspace.CritterAcres
local G = root:GetAttribute("GroundY") or 0.1
local old = root:FindFirstChild("RaidGate")
if old then old:Destroy() end

local gate = Instance.new("Model")
gate.Name = "RaidGate"
local cf = CFrame.lookAt(Vector3.new(-27, G, 31), Vector3.new(0, G, 24))
local function P(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = gate
	return p
end
local STONE = Color3.fromRGB(110, 105, 125)
for _, x in {-4, 4} do
	P({Size = Vector3.new(2.4, 11, 2.4), CFrame = cf * CFrame.new(x, 5.5, 2), Color = STONE, Material = Enum.Material.Slate})
	P({Size = Vector3.new(1.6, 4, 0.2), CFrame = cf * CFrame.new(x, 7, 0.75), Color = Color3.fromRGB(220, 60, 70)}) -- banners
end
P({Size = Vector3.new(11, 2, 2.6), CFrame = cf * CFrame.new(0, 12, 2), Color = STONE, Material = Enum.Material.Slate})
P({Name = "Portal", Size = Vector3.new(5.6, 9.5, 0.3), CFrame = cf * CFrame.new(0, 5.6, 2), Color = Color3.fromRGB(170, 90, 255),
	Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false})
local pedestal = P({Name = "Pedestal", Size = Vector3.new(3, 3, 3), CFrame = cf * CFrame.new(0, 1.5, -3), Color = Color3.fromRGB(90, 85, 100),
	Material = Enum.Material.Slate})
P({Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = cf * CFrame.new(0, 3.8, -3), Color = Color3.fromRGB(255, 80, 90),
	Material = Enum.Material.Neon, CanCollide = false})

local bb = Instance.new("BillboardGui")
bb.Size = UDim2.fromOffset(220, 50)
bb.StudsOffset = Vector3.new(0, 11.5, 0)
bb.MaxDistance = 100
local t = Instance.new("TextLabel")
t.Size = UDim2.fromScale(1, 1)
t.BackgroundColor3 = Color3.fromRGB(255, 120, 110)
t.Font = Enum.Font.FredokaOne
t.TextScaled = true
t.TextColor3 = Color3.new(1, 1, 1)
t.Text = "⚔️ Raid Gate"
Instance.new("UICorner", t).CornerRadius = UDim.new(0, 12)
t.Parent = bb
bb.Parent = pedestal

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "RaidPrompt"
prompt.ActionText = "Open"
prompt.ObjectText = "Raid Gate"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Parent = pedestal

gate.PrimaryPart = pedestal
gate.Parent = root
return "raid gate built"
