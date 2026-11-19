-- Critter Acres: DungeonMap (StarterPlayerScripts LocalScript)
-- 🏰 Dungeon stage 4, the player's side (ServerScriptService.DungeonExtras sends things on RemoteEvent ReplicatedStorage.DungeonEvent):
--   🗺️ a minimap (left side) that fills in as you explore: clearings you've been near + their trails, 🏠 start, 🔥 campfires,
--      🗝️ key, 👑 boss, you (blue) and your party (green). ➖ folds it away.
--   🐾 Sniff: paw prints to the nearest chest you haven't opened.  🏠 Way home: a glowing trail back to the start.
--   🟢 sticky puddles (slower for a moment), 🦘 bounce pads, ⛄ rolling balls that bonk you back. Nothing ever hurts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local K = require(ReplicatedStorage:WaitForChild("UIKit"))
local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local event = ReplicatedStorage:WaitForChild("DungeonEvent", 60)
if not event then return end
local player = Players.LocalPlayer
local D = Data.Dungeon or {}

---------------------------------------------------------------- 🗺️ the minimap panel
local gui = Instance.new("ScreenGui")
gui.Name = "DungeonMap"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 3
gui.Parent = player:WaitForChild("PlayerGui")

local SIZE = 210
local panel = K.frame(gui, {Name = "Panel", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(SIZE + 16, SIZE + 112),
	BackgroundColor3 = K.CREAM, Visible = false})
K.round(panel, 16)
K.stroke(panel, Color3.fromRGB(230, 205, 165), 3)
local title = K.text(panel, {Text = "🗺️ Map", Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -60, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, Max = 20})
local canvas = K.frame(panel, {Name = "Canvas", Position = UDim2.fromOffset(8, 36), Size = UDim2.fromOffset(SIZE, SIZE), BackgroundColor3 = Color3.fromRGB(90, 80, 75),
	ClipsDescendants = true})
K.round(canvas, 12)
local btnRow = K.frame(panel, {Position = UDim2.new(0, 8, 0, SIZE + 44), Size = UDim2.new(1, -16, 0, 60), BackgroundTransparency = 1})
K.iconButton(btnRow, "🐾", "Sniff", {Kind = "special", Size = UDim2.new(0.5, -4, 1, 0), Tip = "🐾 Sniff", TipText = "Your buddy sniffs out the nearest chest you haven't opened."}, function()
	event:FireServer({Kind = "Sniff"})
end)
K.iconButton(btnRow, "🏠", "Way home", {Kind = "go", Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), Tip = "🏠 Way home", TipText = "A glowing trail back to the start."}, function()
	event:FireServer({Kind = "Home"})
end)
local small = false
local foldBtn
foldBtn = K.button(panel, {Text = "➖", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(40, 30), Max = 16, Tip = "Fold the map"}, function()
	small = not small
	canvas.Visible, btnRow.Visible = not small, not small
	panel.Size = small and UDim2.fromOffset(SIZE + 16, 40) or UDim2.fromOffset(SIZE + 16, SIZE + 112)
	foldBtn.Text = small and "🗺️" or "➖"
end)

local cur -- the map message of the dungeon you're in
local seen = {} -- seed -> {[node id] = true}
local nodeUI, trailUI, dots = {}, {}, {}
local scale, mid = 1, Vector2.zero
local TAG_ICON = {start = "🏠", boss = "👑", key = "🗝️", fire = "🔥"}

local function toMap(x, z) return Vector2.new(SIZE / 2 + (x - mid.X) * scale, SIZE / 2 + (z - mid.Y) * scale) end
local function line(a, b, w, col)
	local d = b - a
	local f = K.frame(canvas, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.fromOffset(d.Magnitude + w * 0.6, w), Rotation = math.deg(math.atan(d.Y, d.X)), BackgroundColor3 = col, ZIndex = 2, Visible = false})
	K.round(f, math.floor(w / 2))
	return f
end
local function build(msg)
	canvas:ClearAllChildren()
	K.round(canvas, 12)
	nodeUI, trailUI, dots = {}, {}, {}
	cur = msg
	seen[msg.Seed] = seen[msg.Seed] or {}
	title.Text = ("%s %s"):format(msg.Icon or "🗺️", msg.Name or "Map")
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for _, n in msg.Nodes do
		x0, x1 = math.min(x0, n.X - n.R), math.max(x1, n.X + n.R)
		z0, z1 = math.min(z0, n.Z - n.R), math.max(z1, n.Z + n.R)
	end
	mid = Vector2.new((x0 + x1) / 2, (z0 + z1) / 2)
	scale = (SIZE - 16) / math.max(1, x1 - x0, z1 - z0)
	for _, t in msg.Trails do
		local parts = {}
		local w = math.max(3, (t.W or 7) * 2 * scale)
		for k = 1, #t.P - 3, 2 do
			table.insert(parts, line(toMap(t.P[k], t.P[k + 1]), toMap(t.P[k + 2], t.P[k + 3]), w, Color3.fromRGB(225, 200, 160)))
		end
		table.insert(trailUI, {a = t.A, b = t.B, parts = parts})
	end
	for _, n in msg.Nodes do
		local p = toMap(n.X, n.Z)
		local s = math.max(8, n.R * 2 * scale)
		local f = K.frame(canvas, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(s, s),
			BackgroundColor3 = (n.Col or K.GREEN):Lerp(Color3.fromRGB(240, 225, 190), 0.45), ZIndex = 3, Visible = false})
		K.round(f, math.ceil(s / 2))
		if n.Tag then
			K.text(f, {Text = TAG_ICON[n.Tag] or "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), ZIndex = 5, Max = 18})
		end
		nodeUI[n.Id] = {f = f, n = n}
	end
	panel.Visible = true
end
local function dot(key, col, big)
	local d = dots[key]
	if not d then
		d = K.frame(canvas, {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(big and 12 or 9, big and 12 or 9), BackgroundColor3 = col, ZIndex = 8})
		K.round(d, 8)
		K.stroke(d, Color3.new(1, 1, 1), 2)
		dots[key] = d
	end
	return d
end
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then return end
	acc = 0
	local inside = player:GetAttribute("Dungeon") ~= nil and player:GetAttribute("Realm") ~= nil
	if not inside then panel.Visible = false return end
	if not cur or cur.Seed ~= player:GetAttribute("RealmSeed") then
		if not cur or cur.asked ~= player:GetAttribute("RealmSeed") or os.clock() - (cur.at or 0) > 3 then
			cur = {asked = player:GetAttribute("RealmSeed"), Seed = -1, at = os.clock()}
			event:FireServer({Kind = "Map"})
		end
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local O = cur.O
	local lp = Vector2.new(hrp.Position.X - O.X, hrp.Position.Z - O.Z)
	local mine = seen[cur.Seed]
	for id, u in nodeUI do
		if not mine[id] and (lp - Vector2.new(u.n.X, u.n.Z)).Magnitude < u.n.R + 16 then mine[id] = true end
		u.f.Visible = mine[id] == true
	end
	for _, t in trailUI do
		local on = mine[t.a] or mine[t.b]
		for _, f in t.parts do f.Visible = on == true end
	end
	-- you + your party
	local here = {}
	for _, p in Players:GetPlayers() do
		local h = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if h and p:GetAttribute("RealmSeed") == cur.Seed and p:GetAttribute("Dungeon") then
			local m = toMap(h.Position.X - O.X, h.Position.Z - O.Z)
			local d = dot(p.UserId, p == player and K.BLUE or K.GREEN, p == player)
			d.Position = UDim2.fromOffset(m.X, m.Y)
			here[p.UserId] = true
		end
	end
	for k, d in dots do
		if not here[k] then d:Destroy() dots[k] = nil end
	end
end)

---------------------------------------------------------------- 🐾 paw prints + 🏠 the glowing trail (only you see them)
local fx = Instance.new("Folder")
fx.Name = "DungeonTrailFx"
fx.Parent = workspace
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = {workspace.Terrain}
local function floorAt(p)
	local hit = workspace:Raycast(p + Vector3.new(0, 6, 0), Vector3.new(0, -16, 0), rp)
	return hit and hit.Position or p
end
local function along(pts, spacing, fn)
	local left, n = 0, 0
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local seg = b - a
		local len = Vector3.new(seg.X, 0, seg.Z).Magnitude
		local dir = len > 0.01 and Vector3.new(seg.X, 0, seg.Z) / len or Vector3.new(0, 0, -1)
		local d = left
		while d < len do
			n += 1
			if n > 260 then return end
			fn(a + seg * (d / math.max(len, 0.01)), dir, n)
			d += spacing
		end
		left = d - len
	end
end
local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = fx
	return p
end
local function fadeAll(list, after)
	task.delay(after, function()
		for _, p in list do
			if p.Parent then TweenService:Create(p, TweenInfo.new(1.2), {Transparency = 1}):Play() end
		end
		task.wait(1.3)
		for _, p in list do p:Destroy() end
	end)
end
local UP = CFrame.Angles(0, 0, math.pi / 2)
local function paws(pts)
	local list = {}
	local col = Color3.fromRGB(255, 150, 190)
	along(pts, 3.2, function(p, dir, n)
		local side = Vector3.new(-dir.Z, 0, dir.X) * ((n % 2 == 0) and 0.9 or -0.9)
		local f = floorAt(p + side)
		local cf = CFrame.lookAt(f + Vector3.new(0, 0.12, 0), f + Vector3.new(0, 0.12, 0) + dir)
		local pad = part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1.1, 1.1), CFrame = cf * UP, Color = col, Material = Enum.Material.Neon, Transparency = 1})
		table.insert(list, pad)
		for t = -1, 1 do
			local toe = part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 0.45, 0.45), CFrame = cf * CFrame.new(t * 0.45, 0, -0.75 + math.abs(t) * 0.12) * UP,
				Color = col, Material = Enum.Material.Neon, Transparency = 1})
			table.insert(list, toe)
		end
	end)
	for i, p in list do task.delay(i * 0.008, function() if p.Parent then p.Transparency = 0.15 end end) end -- (they appear one after another)
	fadeAll(list, 12)
end
local function glowTrail(pts)
	local list = {}
	along(pts, 2.6, function(p, _, n)
		local f = floorAt(p)
		local b = part({Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, Position = f + Vector3.new(0, 0.7, 0), Color = Color3.fromRGB(255, 225, 120),
			Material = Enum.Material.Neon, Transparency = 1})
		table.insert(list, b)
		task.delay(n * 0.02, function()
			if not b.Parent then return end
			b.Transparency = 0.1
			TweenService:Create(b, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Position = b.Position + Vector3.new(0, 0.5, 0)}):Play()
		end)
	end)
	fadeAll(list, 18)
end

event.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" then return end
	if msg.Kind == "Map" then build(msg)
	elseif msg.Kind == "Paws" then paws(msg.Pts or {})
	elseif msg.Kind == "Trail" then glowTrail(msg.Pts or {}) end
end)

---------------------------------------------------------------- 🟢 🦘 ⛄ traps (only your own character)
local rollers = {} -- path part -> {ball, pts, len, cum, period, size}
local function addRoller(pathPart)
	local pts = {}
	for x, y, z in string.gmatch(pathPart:GetAttribute("Pts") or "", "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
		table.insert(pts, Vector3.new(tonumber(x), tonumber(y), tonumber(z)))
	end
	if #pts < 2 then return end
	local size = pathPart:GetAttribute("Size") or 4
	local cum = {0}
	for i = 2, #pts do cum[i] = cum[i - 1] + (pts[i] - pts[i - 1]).Magnitude end
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * size
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
	ball.Color = pathPart:GetAttribute("Color") or Color3.new(1, 1, 1)
	local okMat, mat = pcall(function() return Enum.Material[pathPart:GetAttribute("Mat") or "SmoothPlastic"] end)
	ball.Material = okMat and mat or Enum.Material.SmoothPlastic
	ball.Parent = fx
	rollers[pathPart] = {ball = ball, pts = pts, cum = cum, len = cum[#cum], period = pathPart:GetAttribute("Period") or 6, size = size}
end
CollectionService:GetInstanceAddedSignal("DungeonRoller"):Connect(function(p) task.defer(addRoller, p) end)
CollectionService:GetInstanceRemovedSignal("DungeonRoller"):Connect(function(p)
	local r = rollers[p]
	if r then r.ball:Destroy() rollers[p] = nil end
end)
for _, p in CollectionService:GetTagged("DungeonRoller") do addRoller(p) end

local slowUntil, slowBase, slowSet = 0, nil, nil
local bounceAt, bonkAt = 0, 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local t = workspace:GetServerTimeNow()
	-- ⛄ rolling balls (move every frame, even with no character)
	for pathPart, r in rollers do
		if not pathPart.Parent then r.ball:Destroy() rollers[pathPart] = nil continue end
		local u = (t / r.period) % 2
		u = u > 1 and 2 - u or u
		local want = u * r.len
		local i = 2
		while i < #r.pts and r.cum[i] < want do i += 1 end
		local a, b = r.pts[i - 1], r.pts[i]
		local segLen = math.max(0.01, r.cum[i] - r.cum[i - 1])
		local pos = a:Lerp(b, math.clamp((want - r.cum[i - 1]) / segLen, 0, 1)) + Vector3.new(0, r.size / 2, 0)
		local dir = (b - a)
		local axis = Vector3.new(-dir.Z, 0, dir.X)
		local spin = axis.Magnitude > 0.01 and CFrame.fromAxisAngle(axis.Unit, -want / (r.size / 2)) or CFrame.identity
		r.ball.CFrame = CFrame.new(pos) * spin
		if hrp and now - bonkAt > 1.2 then
			local off = hrp.Position - pos
			if Vector3.new(off.X, 0, off.Z).Magnitude < r.size / 2 + 1.6 and math.abs(off.Y) < r.size / 2 + 3 then
				bonkAt = now
				local away = Vector3.new(off.X, 0, off.Z)
				away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
				hrp.AssemblyLinearVelocity = away * (D.BonkPush or 45) + Vector3.new(0, 28, 0)
				event:FireServer({Kind = "Bonk"})
			end
		end
	end
	if not hrp or not hum or not player:GetAttribute("Dungeon") then return end
	-- 🟢 sticky puddles
	local onPuddle = false
	for _, p in CollectionService:GetTagged("DungeonPuddle") do
		local off = hrp.Position - p.Position
		if Vector3.new(off.X, 0, off.Z).Magnitude < (p:GetAttribute("R") or 4) and off.Y > -1 and off.Y < 5 then onPuddle = true break end
	end
	if onPuddle then
		if not slowSet then
			slowBase = hum.WalkSpeed
			slowSet = slowBase * (D.SlowX or 0.5)
			hum.WalkSpeed = slowSet
		end
		slowUntil = now + (D.SlowFor or 1.5)
	elseif slowSet and now > slowUntil then
		if math.abs(hum.WalkSpeed - slowSet) < 0.01 then hum.WalkSpeed = slowBase end -- (only if nothing else changed it meanwhile)
		slowSet, slowBase = nil, nil
	end
	-- 🦘 bounce pads
	if now - bounceAt > 0.8 then
		for _, p in CollectionService:GetTagged("DungeonBounce") do
			local off = hrp.Position - p.Position
			if Vector3.new(off.X, 0, off.Z).Magnitude < (p:GetAttribute("R") or 3) and off.Y > 0 and off.Y < 4.5 then
				bounceAt = now
				local v = hrp.AssemblyLinearVelocity
				hrp.AssemblyLinearVelocity = Vector3.new(v.X, D.BounceUp or 70, v.Z)
				break
			end
		end
	end
end)
player.CharacterAdded:Connect(function() slowSet, slowBase = nil, nil end)
