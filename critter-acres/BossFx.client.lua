-- Critter Acres: BossFx (StarterPlayerScripts LocalScript)
-- Draws the 👑 boss special attacks sent by ServerScriptService.BossSkills (over the Combat remote):
--   BossCast    : big name over the boss ("☄️ Meteor Shower!") + a short hint at the top ("Get out of the red circles!")
--   BossZone    : red warning shapes on the ground that fill up until the hit lands
--                 Circle (+ Fall = something drops from the sky, Slam = shockwave from the boss), Lane (+ Breath blast)
--   BossShot    : a red lane for a moment, then a glowing ball flies down it. BossShotEnd = it hit someone (pop)
--   Stun        : you're dizzy / frozen / sticky for a moment (can't walk or jump), with a little effect over your head
-- Everything here is local only (parts live in workspace.BossFxLocal). Boss poses are in MobAnimator.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local K = require(ReplicatedStorage:WaitForChild("UIKit"))
local remote = ReplicatedStorage:WaitForChild("Combat")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local folder = Instance.new("Folder")
folder.Name = "BossFxLocal"
folder.Parent = workspace

local gui = Instance.new("ScreenGui")
gui.Name = "BossFx"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local DANGER = Color3.fromRGB(255, 70, 70)
-- what falls / flies / blasts for each look
local LOOK = {
	Pollen = {color = Color3.fromRGB(255, 220, 90), material = Enum.Material.Neon, shape = "Ball", tex = SPARK},
	Honey = {color = Color3.fromRGB(255, 180, 40), material = Enum.Material.Glass, shape = "Ball", tex = SPARK},
	Acorn = {color = Color3.fromRGB(150, 95, 50), material = Enum.Material.SmoothPlastic, shape = "Ball", tex = SMOKE, dust = Color3.fromRGB(200, 170, 120)},
	Thorn = {color = Color3.fromRGB(120, 200, 80), material = Enum.Material.Neon, shape = "Ball", tex = SPARK},
	Dirt = {color = Color3.fromRGB(150, 120, 80), material = Enum.Material.Slate, shape = "Ball", tex = SMOKE, dust = Color3.fromRGB(190, 160, 120)},
	Ice = {color = Color3.fromRGB(170, 225, 255), material = Enum.Material.Ice, shape = "Icicle", tex = SMOKE, dust = Color3.fromRGB(230, 245, 255)},
	Snow = {color = Color3.fromRGB(245, 250, 255), material = Enum.Material.Snow, shape = "Ball", tex = SMOKE, dust = Color3.fromRGB(240, 248, 255)},
	Gem = {color = Color3.fromRGB(200, 130, 255), material = Enum.Material.Neon, shape = "Gem", tex = SPARK},
	Lava = {color = Color3.fromRGB(255, 110, 40), material = Enum.Material.Neon, shape = "Rock", tex = FIRE, dust = Color3.fromRGB(110, 100, 100)},
}
local function lookOf(n) return LOOK[n or ""] or LOOK.Dirt end

---------------------------------------------------------------- little helpers
local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = props.Parent or folder
	return p
end
local function tween(o, t, goal, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local function emit(at, o)
	local holder = part({Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(at)})
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.tex or SPARK
	e.Color = ColorSequence.new(o.color)
	e.LightEmission = o.light or 0.5
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, o.size or 1), NumberSequenceKeypoint.new(1, (o.size or 1) * (o.grow or 0.3))})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	e.Speed = NumberRange.new((o.speed or 10) * 0.5, o.speed or 10)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = o.accel or Vector3.zero
	e.Drag = o.drag or 2
	e.Lifetime = NumberRange.new((o.life or 0.8) * 0.6, o.life or 0.8)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Rate = 0
	e.Parent = holder
	e:Emit(o.n or 20)
	Debris:AddItem(holder, (o.life or 0.8) + 0.2)
end

-- a flat round disc lying on the ground
local function disc(pos, r, color, transp)
	return part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, r * 2, r * 2), Color = color, Material = Enum.Material.Neon,
		Transparency = transp, CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)})
end

-- camera wobble (moves the camera, never turns it, so it works with mouse look too)
local shakeUntil, shakePow = 0, 0
local function shake(pow, secs)
	shakeUntil = math.max(shakeUntil, os.clock() + secs)
	shakePow = math.max(shakePow, pow)
end
RunService:BindToRenderStep("BossFxShake", Enum.RenderPriority.Camera.Value + 2, function()
	local left = shakeUntil - os.clock()
	if left <= 0 then shakePow = 0 return end
	local a = shakePow * math.min(1, left / 0.3)
	camera.CFrame += Vector3.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, (math.random() - 0.5) * a)
end)
local function shakeNear(pos, range, pow, secs)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and (hrp.Position - pos).Magnitude < range then shake(pow, secs) end
end

-- a ring of dust that rolls out from an impact
local function shockwave(pos, r, color)
	local ring = disc(pos + Vector3.new(0, 0.2, 0), 1, color, 0.3)
	ring.Material = Enum.Material.SmoothPlastic
	tween(ring, 0.45, {Size = Vector3.new(0.15, r * 2.2, r * 2.2), Transparency = 1})
	Debris:AddItem(ring, 0.5)
end

local function impact(pos, r, lk)
	local L = lookOf(lk)
	emit(pos + Vector3.new(0, 1, 0), {color = L.color, tex = L.tex, size = 1.6, grow = 0.2, speed = 22, life = 0.7, n = 30, light = 0.8, accel = Vector3.new(0, -30, 0)})
	emit(pos + Vector3.new(0, 1, 0), {color = L.dust or Color3.fromRGB(230, 220, 200), tex = SMOKE, size = 2.4, grow = 2, speed = 10, life = 1.0, n = 14, light = 0, accel = Vector3.new(0, 3, 0)})
	shockwave(pos, r, L.dust or L.color)
	shakeNear(pos, r + 18, 0.6, 0.25)
end

-- the thing that falls or flies (an icicle, a gem, a lava rock, or a ball)
local function projectile(lk, size)
	local L = lookOf(lk)
	local p
	if L.shape == "Icicle" then
		p = part({Size = Vector3.new(size * 0.6, size * 2.2, size * 0.6), Color = L.color, Material = L.material, Transparency = 0.15})
		-- a pointy tip on the bottom
		local tip = part({Size = Vector3.new(size * 0.6, size * 0.6, size * 0.6), Color = L.color, Material = L.material, Transparency = 0.15, Parent = p})
		tip.CFrame = p.CFrame * CFrame.new(0, -size * 1.2, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = p, tip
		w.Parent = p
		tip.Anchored = false
	elseif L.shape == "Gem" then
		p = part({Size = Vector3.one * size, Color = L.color, Material = L.material})
		p.CFrame = CFrame.Angles(math.pi / 4, 0, math.pi / 4)
	elseif L.shape == "Rock" then
		p = part({Shape = Enum.PartType.Ball, Size = Vector3.one * size, Color = L.color, Material = L.material})
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat = size * 1.5, 12
		fire.Parent = p
	else
		p = part({Shape = Enum.PartType.Ball, Size = Vector3.one * size, Color = L.color, Material = L.material})
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = L.color, size * 4, 2
	light.Parent = p
	-- a glowing trail behind it
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, size * 0.4, 0), Vector3.new(0, -size * 0.4, 0)
	a0.Parent, a1.Parent = p, p
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(L.color)
	tr.LightEmission = 0.8
	tr.Lifetime = 0.25
	tr.Transparency = NumberSequence.new(0.2, 1)
	tr.Parent = p
	return p
end

---------------------------------------------------------------- zones (red shapes on the ground)
local zones = {} -- {model, parts}
local function addZone(model, parts)
	local z = {model = model, parts = parts}
	table.insert(zones, z)
	return z
end
local function dropZone(z)
	for _, p in z.parts do if p.Parent then p:Destroy() end end
	local i = table.find(zones, z)
	if i then table.remove(zones, i) end
end
local function zoneGone(z) return not table.find(zones, z) end

local function circleZone(msg)
	local pos, r, warn = msg.Pos + Vector3.new(0, 0.15, 0), msg.R, msg.Warn
	local edge = disc(pos, r, DANGER, 0.55)
	local fill = disc(pos + Vector3.new(0, 0.03, 0), 0.2, DANGER, 0.35)
	local mark = part({Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, CFrame = CFrame.new(pos)})
	local z = addZone(msg.Model, {edge, fill, mark})
	tween(fill, warn, {Size = Vector3.new(0.15, r * 2, r * 2)}, Enum.EasingStyle.Linear)
	-- a gentle pulse on the edge
	task.spawn(function()
		local t0 = os.clock()
		while not zoneGone(z) and os.clock() - t0 < warn do
			edge.Transparency = 0.45 + math.sin((os.clock() - t0) * 10) * 0.12
			task.wait()
		end
	end)
	-- ☄️ something falls from the sky and lands right when the circle is full
	if msg.Fall then
		local fallT = 0.6
		task.delay(math.max(0, warn - fallT), function()
			if zoneGone(z) then return end
			local L = lookOf(msg.Fall)
			local size = math.clamp(r * 0.55, 2, 4)
			local rock = projectile(msg.Fall, size)
			table.insert(z.parts, rock)
			local from = pos + Vector3.new(10, 70, 6)
			local t0 = os.clock()
			local spin = CFrame.Angles(math.random() * 3, math.random() * 3, 0)
			while not zoneGone(z) do
				local k = math.min(1, (os.clock() - t0) / fallT)
				local p = from:Lerp(pos + Vector3.new(0, size * 0.4, 0), k * k)
				if L.shape == "Icicle" then
					rock.CFrame = CFrame.lookAt(p, p + (pos - from).Unit) * CFrame.Angles(math.pi / 2, 0, 0) -- tip first
				else
					rock.CFrame = CFrame.new(p) * spin * CFrame.Angles(k * 6, k * 4, 0)
				end
				if k >= 1 then break end
				task.wait()
			end
		end)
	end
	task.delay(warn, function()
		if zoneGone(z) then return end
		dropZone(z)
		if msg.Fall then impact(msg.Pos, r, msg.Fall)
		elseif msg.Slam then
			impact(msg.Pos, r, msg.Slam)
			shockwave(msg.Pos, r * 1.1, lookOf(msg.Slam).dust or lookOf(msg.Slam).color)
			shakeNear(msg.Pos, r + 30, 1.2, 0.45)
		end
	end)
end

-- breath blast down the lane
local function breath(msg)
	local L = lookOf(msg.Breath)
	local dir, a = msg.Dir, msg.Pos + Vector3.new(0, 3, 0)
	local holder = part({Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.lookAt(a, a + dir)})
	local e = Instance.new("ParticleEmitter")
	e.Texture = msg.Breath == "Lava" and FIRE or SMOKE
	e.Color = ColorSequence.new(L.color, Color3.new(1, 1, 1))
	e.LightEmission = 0.7
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, msg.W * 0.6)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	e.Speed = NumberRange.new(msg.L * 0.9, msg.L * 1.2)
	e.Lifetime = NumberRange.new(0.9, 1.1)
	e.SpreadAngle = Vector2.new(9, 9)
	e.Drag = 0.6
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.EmissionDirection = Enum.NormalId.Front
	e.Rate = 70
	e.Parent = holder
	shakeNear(msg.Pos, msg.L + 10, 0.35, msg.Hold or 1)
	task.delay(msg.Hold or 1, function() e.Enabled = false end)
	Debris:AddItem(holder, (msg.Hold or 1) + 1.3)
end

local function laneParts(a, dir, len, w, transp)
	local mid = a + dir * (len / 2)
	local cf = CFrame.lookAt(mid, mid + dir)
	local edge = part({Size = Vector3.new(w, 0.15, len), Color = DANGER, Material = Enum.Material.Neon, Transparency = transp, CFrame = cf})
	return edge, cf
end

local function laneZone(msg)
	local a, dir, len, w, warn = msg.Pos + Vector3.new(0, 0.2, 0), msg.Dir, msg.L, msg.W, msg.Warn
	local edge = laneParts(a, dir, len, w, 0.55)
	local fill = part({Size = Vector3.new(w, 0.17, 0.1), Color = DANGER, Material = Enum.Material.Neon, Transparency = 0.35, CFrame = CFrame.lookAt(a, a + dir)})
	local z = addZone(msg.Model, {edge, fill})
	local t0 = os.clock()
	task.spawn(function()
		while not zoneGone(z) do
			local k = math.min(1, (os.clock() - t0) / warn)
			local l = math.max(0.1, len * k)
			local mid = a + dir * (l / 2)
			fill.Size = Vector3.new(w, 0.17, l)
			fill.CFrame = CFrame.lookAt(mid, mid + dir)
			edge.Transparency = 0.45 + math.sin((os.clock() - t0) * 10) * 0.12
			if k >= 1 then break end
			task.wait()
		end
	end)
	task.delay(warn, function()
		if zoneGone(z) then return end
		if msg.Breath then
			breath(msg)
			tween(edge, msg.Hold or 1, {Transparency = 0.85})
			tween(fill, msg.Hold or 1, {Transparency = 1})
			task.delay(msg.Hold or 1, function() dropZone(z) end)
		else
			dropZone(z) -- charge: the boss runs through it (MobAnimator), dust behind it
			for i = 0, 4 do
				task.delay(i * 0.12, function()
					emit(a + dir * (len * i / 5) + Vector3.new(0, 1, 0), {color = Color3.fromRGB(200, 175, 135), tex = SMOKE, size = 2.6, grow = 1.8, speed = 6, life = 0.9, n = 8, light = 0})
				end)
			end
			shakeNear(msg.Pos, len + 15, 0.8, 0.6)
		end
	end)
end

---------------------------------------------------------------- shots
local shots = {} -- id -> {ball, zone}
local function shot(msg)
	local from, dir, range = msg.From, msg.Dir, msg.Range
	local groundY = from.Y - 2.6
	local lane = laneParts(Vector3.new(from.X, groundY, from.Z), dir, range, msg.R * 2, 0.5)
	local z = addZone(msg.Model, {lane})
	local s = {zone = z}
	shots[msg.Id] = s
	tween(lane, msg.Aim, {Transparency = 0.3}, Enum.EasingStyle.Linear)
	task.delay(msg.Aim, function()
		if zoneGone(z) then shots[msg.Id] = nil return end
		local ball = projectile(msg.Look, msg.R * 1.4)
		s.ball = ball
		table.insert(z.parts, ball)
		tween(lane, 0.6, {Transparency = 1})
		local t0 = os.clock()
		while not zoneGone(z) and shots[msg.Id] == s do
			local d = (os.clock() - t0) * msg.Speed
			if d > range then break end
			local p = from + dir * d
			ball.CFrame = CFrame.lookAt(p, p + dir) * CFrame.Angles(0, 0, d * 0.4)
			task.wait()
		end
		if shots[msg.Id] == s then shots[msg.Id] = nil end
		if not zoneGone(z) then dropZone(z) end
	end)
end
local function shotEnd(msg)
	local s = shots[msg.Id]
	shots[msg.Id] = nil
	if s then
		local look
		if s.ball then look = s.ball.Color end
		dropZone(s.zone)
		emit(msg.Pos, {color = look or Color3.fromRGB(255, 220, 120), size = 1.4, grow = 0.2, speed = 16, life = 0.5, n = 22, light = 1})
	end
end

---------------------------------------------------------------- 😵 stun
local stunUntil = 0
local STUN = {
	Dizzy = {icon = "💫", text = "Dizzy!", color = Color3.fromRGB(255, 230, 120)},
	Ice = {icon = "🧊", text = "Frozen!", color = Color3.fromRGB(170, 225, 255)},
	Honey = {icon = "🍯", text = "Sticky!", color = Color3.fromRGB(255, 190, 70)},
}
local function stun(msg)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head")
	if not hum or not head then return end
	local S = STUN[msg.Look] or STUN.Dizzy
	local secs = msg.Secs or 1.2
	local first = os.clock() > stunUntil
	stunUntil = math.max(stunUntil, os.clock() + secs)
	if not first then return end
	local walk, jumpH, jumpP = hum.WalkSpeed, hum.JumpHeight, hum.JumpPower
	hum.WalkSpeed, hum.JumpHeight, hum.JumpPower = 0, 0, 0
	-- the little effect over your head
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(150, 60)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = head
	bb.Parent = gui
	local label = K.text(bb, {Text = S.icon .. " " .. S.text, Size = UDim2.fromScale(1, 1), Max = 30, TextColor3 = S.color})
	label.TextStrokeTransparency = 0.2
	-- frozen: an ice block around you; sticky: a honey blob at your feet; dizzy: stars circling your head
	local extra = {}
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if msg.Look == "Ice" and hrp then
		table.insert(extra, part({Size = Vector3.new(4.5, 6.5, 4.5), Color = S.color, Material = Enum.Material.Ice, Transparency = 0.45, CFrame = hrp.CFrame * CFrame.new(0, -0.3, 0)}))
	elseif msg.Look == "Honey" and hrp then
		table.insert(extra, disc(hrp.Position - Vector3.new(0, 2.9, 0), 3, S.color, 0.15))
		extra[#extra].Material = Enum.Material.Glass
	end
	local stars = {}
	if msg.Look ~= "Ice" then
		for i = 1, 3 do
			stars[i] = part({Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, Color = S.color, Material = Enum.Material.Neon})
		end
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now > stunUntil or not hum.Parent or hum.Health <= 0 then
			conn:Disconnect()
			if hum.Parent then
				if hum.WalkSpeed == 0 then hum.WalkSpeed = walk end
				if hum.JumpHeight == 0 then hum.JumpHeight = jumpH end
				if hum.JumpPower == 0 then hum.JumpPower = jumpP end
			end
			bb:Destroy()
			for _, p in stars do p:Destroy() end
			for _, p in extra do p:Destroy() end
			return
		end
		for i, p in stars do
			local a = now * 6 + i * math.pi * 2 / 3
			p.CFrame = head.CFrame * CFrame.new(math.cos(a) * 1.4, 1.1, math.sin(a) * 1.4)
		end
		label.Rotation = math.sin(now * 8) * 6
	end)
end

---------------------------------------------------------------- the boss's name pops up over it
local hint = K.frame(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 222), Size = UDim2.fromOffset(440, 46),
	BackgroundColor3 = Color3.fromRGB(255, 235, 225), Visible = false})
-- under the boss bar (which sits under the land bar and the top-right dock)
local function placeHint() hint.Position = UDim2.new(0.5, 0, 0, player:GetAttribute("HudCompact") and 270 or 222) end
placeHint()
player:GetAttributeChangedSignal("HudCompact"):Connect(placeHint)
K.round(hint, 14)
K.stroke(hint, DANGER, 3)
local hintText = K.text(hint, {Text = "", Size = UDim2.fromScale(1, 1), Max = 24})
local hintN = 0
local HINT = {
	Rain = "⚠️ Get out of the red circles!",
	Slam = "⚠️ Run out of the red circle!",
	Volley = "⚠️ Step out of the red lanes!",
	Line = "⚠️ Step out of the red lane!",
}

local function mobTop(m)
	local cf, size = m:GetBoundingBox()
	return cf.Position + Vector3.new(0, size.Y / 2, 0), size.Y
end

local function cast(msg)
	local m = msg.Model
	if m and m.Parent then
		local top = mobTop(m)
		local anchor = part({Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(top)})
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(340, 70)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.MaxDistance = 160
		bb.Adornee = anchor
		bb.Parent = gui
		local t = K.text(bb, {Text = (msg.Icon or "⚠️") .. " " .. (msg.Name or "") .. "!", Size = UDim2.fromScale(1, 1), Max = 36, TextColor3 = Color3.fromRGB(255, 235, 120)})
		t.TextStrokeTransparency = 0
		t.TextStrokeColor3 = Color3.fromRGB(120, 30, 30)
		local sc = Instance.new("UIScale")
		sc.Scale = 0.3
		sc.Parent = t
		tween(sc, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
		task.delay(1.8, function()
			tween(t, 0.5, {TextTransparency = 1, TextStrokeTransparency = 1})
			task.delay(0.55, function() bb:Destroy() anchor:Destroy() end)
		end)
	end
	-- the hint only matters if you're near the fight
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if m and m.Parent and hrp and (hrp.Position - m:GetPivot().Position).Magnitude < 90 then
		hintN += 1
		local n = hintN
		hintText.Text = HINT[msg.Type] or "⚠️ Watch out!"
		hint.Visible = true
		task.delay(2.4, function() if hintN == n then hint.Visible = false end end)
	end
end

---------------------------------------------------------------- messages
remote.OnClientEvent:Connect(function(msg)
	local k = msg.Kind
	if k == "BossCast" then
		cast(msg)
	elseif k == "BossZone" then
		if msg.Shape == "Lane" then laneZone(msg) else circleZone(msg) end
	elseif k == "BossShot" then
		shot(msg)
	elseif k == "BossShotEnd" then
		shotEnd(msg)
	elseif k == "Stun" then
		stun(msg)
	elseif k == "Defeat" and msg.Boss then
		-- the boss is gone: clear its warnings
		for i = #zones, 1, -1 do
			if zones[i].model == msg.Model then dropZone(zones[i]) end
		end
		hint.Visible = false
	end
end)

-- leaving the land (or the map going away) clears everything
player:GetAttributeChangedSignal("Realm"):Connect(function()
	for i = #zones, 1, -1 do dropZone(zones[i]) end
	shots = {}
	hint.Visible = false
end)
