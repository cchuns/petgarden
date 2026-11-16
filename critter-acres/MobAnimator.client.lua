-- Critter Acres: MobAnimator (StarterPlayerScripts LocalScript)
-- Brings terrain mobs to life on your screen. Any Model tagged "MobRig" whose parts follow the rig layout
-- (Body + Head / EarL/R / WingL/R / ArmL/R / Feet / Crest / Tail / Shell ..., eyes and face bits as "riders") gets:
--   idle breathing, wandering around its home spot, turning to watch you, ear twitches, wing flaps,
--   stepping feet, swinging arms, a wagging tail, blinking eyes, shines that follow you, a mouth that opens,
--   and a signature move every so often (see "signature moves" below). Specials (attribute Special) sparkle and glow.
-- Herds: mobs that share a "Herd" id (set by Realms) travel together. The first one seen leads; the rest keep
--   their spot in the group and follow it around.
-- Mobs follow the terrain height as they walk.
-- In the wild lands the server (ServerScriptService.Combat) is the brain: it sets Goal + Spd (where to walk, how fast),
--   bumps Act (play the attack move now), Angry/TargetId (face that player) and Dead (dizzy spin away).
--   The wander/herd code below only runs for mobs without a Goal.
-- Attributes on the model: MobKind (defaults to the name), Special, Boss, Roam (studs), Herd (group id), GlowColor.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local rigs, herds = {}, {}
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function env(k, dur, e) return smooth(math.min(k, dur - k) / (e or 0.3)) end
local function bump(k, a, b) return math.sin(math.clamp((k - a) / (b - a), 0, 1) * math.pi) end
local TAU = math.pi * 2

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

-- move: hop / walk / waddle / scuttle / roll / slide / fly / hover / float / stomp
-- fx: particles for the signature move (from = Head / Body / Crest, at = front / top / back)
local KIND = {
	-- Meadow
	Puffbloom = {move = "hop", speed = 0.9, attack = 1.8,
		fx = {from = "Head", at = "front", color = Color3.fromRGB(250, 250, 240), texture = SMOKE, size = 0.35, grow = 1.6, speed = 12, spread = 25, life = 1.1, drag = 3, accel = Vector3.new(0, 1.5, 0)}},
	Bumblebun = {move = "fly", speed = 1.6, attack = 1.4,
		fx = {from = "Body", at = "back", color = Color3.fromRGB(255, 255, 255), texture = SMOKE, size = 0.5, grow = 1.4, speed = 2, spread = 20, life = 0.4}},
	Potsnail = {move = "slide", speed = 0.35, attack = 3.2},
	QueenBuzzbloom = {move = "hover", speed = 0.35, attack = 2.8,
		fx = {from = "Head", at = "top", color = Color3.fromRGB(255, 220, 90), size = 0.9, speed = 14, spread = 180, life = 1.4, drag = 2, light = 0.6}},
	-- Forest
	Mushling = {move = "hop", speed = 0.8, attack = 2.0,
		fx = {from = "Crest", at = "top", color = Color3.fromRGB(210, 235, 140), texture = SMOKE, size = 0.5, grow = 2, speed = 4, spread = 70, life = 1.6, drag = 2, accel = Vector3.new(0, 0.8, 0)}},
	AcornKnight = {move = "waddle", speed = 1.0, attack = 1.6,
		fx = {from = "Body", at = "front", color = Color3.fromRGB(255, 240, 180), size = 0.4, speed = 8, spread = 40, life = 0.5, light = 0.5}},
	Twiggle = {move = "walk", speed = 0.9, attack = 2.6,
		fx = {from = "Body", at = "top", color = Color3.fromRGB(150, 200, 90), size = 0.3, speed = 6, spread = 120, life = 0.8, accel = Vector3.new(0, -8, 0)}},
	BrambleBear = {move = "stomp", speed = 0.3, attack = 2.6,
		fx = {from = "Body", at = "front", color = Color3.fromRGB(140, 200, 90), size = 0.8, speed = 16, spread = 70, life = 1.2, drag = 2, accel = Vector3.new(0, -10, 0)}},
	-- Peaks
	Snowpuff = {move = "hop", speed = 1.0, attack = 1.8,
		fx = {from = "Body", at = "back", color = Color3.fromRGB(240, 248, 255), texture = SMOKE, size = 0.6, grow = 1.6, speed = 4, spread = 50, life = 0.8}},
	Pengling = {move = "waddle", speed = 0.8, attack = 2.2,
		fx = {from = "Body", at = "front", color = Color3.fromRGB(235, 245, 255), texture = SMOKE, size = 0.5, grow = 1.5, speed = 5, spread = 40, life = 0.7}},
	GaleSprite = {move = "float", speed = 1.3, attack = 1.8,
		fx = {from = "Body", at = "front", color = Color3.fromRGB(225, 240, 255), texture = SMOKE, size = 0.6, grow = 2.2, speed = 18, spread = 20, life = 0.9, drag = 1}},
	IceWyrm = {move = "hover", speed = 0.3, attack = 3.0,
		fx = {from = "Head", at = "front", color = Color3.fromRGB(200, 235, 255), texture = SMOKE, size = 1.1, grow = 2, speed = 22, spread = 18, life = 1.0, drag = 1.5, light = 0.4}},
	-- Caves
	GemshellCrab = {move = "scuttle", speed = 1.0, attack = 1.4,
		fx = {from = "Body", at = "top", color = Color3.fromRGB(210, 150, 255), size = 0.35, speed = 5, spread = 90, life = 0.7, light = 0.8}},
	Glowbat = {move = "fly", speed = 1.8, attack = 1.4, light = Color3.fromRGB(255, 220, 110),
		fx = {from = "Body", at = "back", color = Color3.fromRGB(255, 225, 120), size = 0.3, speed = 2, spread = 40, life = 0.8, light = 1}},
	Rockroll = {move = "roll", speed = 1.1, attack = 2.0,
		fx = {from = "Body", at = "back", color = Color3.fromRGB(170, 160, 150), texture = SMOKE, size = 0.6, grow = 1.5, speed = 3, spread = 40, life = 0.6}},
	GemGolem = {move = "stomp", speed = 0.28, attack = 2.6,
		fx = {from = "Body", at = "front", color = Color3.fromRGB(220, 160, 255), size = 0.8, speed = 16, spread = 80, life = 1.0, light = 0.9}},
	-- Volcano
	Cinderpup = {move = "hop", speed = 1.4, attack = 1.6,
		fx = {from = "Body", at = "top", color = Color3.fromRGB(255, 160, 60), texture = FIRE, size = 0.35, speed = 5, spread = 60, life = 0.6, light = 1, accel = Vector3.new(0, 4, 0)}},
	Emberbeetle = {move = "walk", speed = 0.7, attack = 1.8,
		fx = {from = "Body", at = "front", color = Color3.fromRGB(255, 140, 50), size = 0.35, speed = 9, spread = 35, life = 0.5, light = 1}},
	Smoglet = {move = "float", speed = 0.9, attack = 2.2,
		fx = {from = "Body", at = "front", color = Color3.fromRGB(110, 105, 105), texture = SMOKE, size = 0.7, grow = 2, speed = 7, spread = 35, life = 1.2, drag = 1.5, accel = Vector3.new(0, 1, 0)}},
	LavaTitan = {move = "stomp", speed = 0.28, attack = 2.6,
		fx = {from = "Body", at = "front", color = Color3.fromRGB(255, 130, 40), texture = FIRE, size = 0.9, speed = 18, spread = 80, life = 0.9, light = 1, accel = Vector3.new(0, -14, 0)}},
}

local function emitter(parent, o)
	local a = Instance.new("Attachment")
	a.CFrame = o.cf or CFrame.new()
	a.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.texture or SPARK
	e.Color = ColorSequence.new(o.color)
	e.LightEmission = o.light or 0.3
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, o.size), NumberSequenceKeypoint.new(1, o.size * (o.grow or 0.4))})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	e.Speed = NumberRange.new(o.speed * 0.6, o.speed)
	e.SpreadAngle = Vector2.new(o.spread or 30, o.spread or 30)
	e.Acceleration = o.accel or Vector3.zero
	e.Drag = o.drag or 1
	e.Lifetime = NumberRange.new(o.life * 0.7, o.life)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.EmissionDirection = Enum.NormalId.Front
	e.Rate = o.rate or 0
	e.Parent = a
	return e
end

-- ground height under a point (terrain only), or nil
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = {workspace.Terrain}
local function groundAt(p)
	local hit = workspace:Raycast(p + Vector3.new(0, 25, 0), Vector3.new(0, -80, 0), rayParams)
	return hit and hit.Position.Y
end

---------------------------------------------------------------- setup
local function setup(m)
	if rigs[m] then return end
	local body = m.PrimaryPart or m:WaitForChild("Body", 10)
	if not body or rigs[m] then return end
	task.wait(0.5) -- let the rest of the parts arrive
	if not m.Parent then return end
	local pivot = m:GetPivot()
	local look = pivot.LookVector
	local _, size = m:GetBoundingBox()
	local r = {
		m = m, body = body, home = pivot.Position, pos = pivot.Position, yaw = math.atan2(-look.X, -look.Z),
		bodyInPivot = pivot:ToObjectSpace(body.CFrame), limbs = {}, riders = {}, u = size.Y,
		seed = math.random() * 100, state = "idle", nextThink = os.clock() + 1 + math.random() * 2, stateAt = 0,
		eyesNow = 1, mouthNow = 0, blinkAt = os.clock() + 1 + math.random() * 2, step = 0, flapPh = 0, rollAng = 0,
		special = m:GetAttribute("Special"), boss = m:GetAttribute("Boss"),
		kind = (m:GetAttribute("MobKind") or m.Name):gsub("^Golden", ""),
	}
	r.info = KIND[r.kind] or {move = "hop", speed = 0.8, attack = 1.5}
	r.roam = m:GetAttribute("Roam") or (r.boss and 3 or 4)
	local herd = m:GetAttribute("Herd")
	if type(herd) == "string" and herd ~= "" then
		r.herd = herd
		herds[herd] = herds[herd] or {}
	end
	-- how high above the ground it floats (so it can follow hills while walking)
	local g = groundAt(r.home)
	r.lift = g and (r.home.Y - g) or nil
	r.groundY = r.home.Y
	local riderParts = {}
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanTouch = true, false, false
			if p ~= body and p:GetAttribute("Ride") then
				riderParts[#riderParts + 1] = p
			elseif p ~= body then
				local rest = body.CFrame:ToObjectSpace(p.CFrame)
				local joint = rest * ((p:GetAttribute("JointFrac") or Vector3.zero) * p.Size)
				r.limbs[p.Name] = {part = p, rest = rest, joint = joint, side = rest.Position.X < 0 and -1 or 1}
			end
		end
	end
	for _, p in riderParts do
		local parent = m:FindFirstChild(p:GetAttribute("Ride"))
		if parent then
			local depth, q = 0, p
			while q and q:GetAttribute("Ride") and depth < 6 do depth += 1 q = m:FindFirstChild(q:GetAttribute("Ride")) end
			table.insert(r.riders, {part = p, parent = parent, rel = parent.CFrame:ToObjectSpace(p.CFrame), size = p.Size, face = p:GetAttribute("Face"),
				t0 = p:GetAttribute("Alpha") or p.Transparency, depth = depth})
		end
	end
	table.sort(r.riders, function(a, b) return a.depth < b.depth end)
	-- signature-move particles
	local fx = r.info.fx
	if fx then
		local from = (r.limbs[fx.from] and r.limbs[fx.from].part) or (r.limbs.Head and r.limbs.Head.part) or body
		local s = from.Size
		local cf = fx.at == "top" and CFrame.new(0, s.Y * 0.4, 0) * CFrame.Angles(math.pi / 2, 0, 0)
			or fx.at == "back" and CFrame.new(0, 0, s.Z * 0.5) * CFrame.Angles(0, math.pi, 0)
			or CFrame.new(0, -s.Y * 0.1, -s.Z * 0.45)
		local o = table.clone(fx)
		o.cf = cf
		o.size = fx.size * r.u / 4.5
		if r.boss then o.size = fx.size end
		if r.special then o.color = m:GetAttribute("GlowColor") or Color3.fromRGB(255, 225, 110) end
		r.fx = emitter(from, o)
	end
	if r.info.light then
		local l = Instance.new("PointLight")
		l.Color = r.info.light
		l.Range = r.u * 3
		l.Brightness = 1.2
		l.Parent = body
	end
	if r.special then
		local c = m:GetAttribute("GlowColor") or Color3.fromRGB(255, 220, 120)
		emitter(body, {color = c, size = 0.45, speed = 1.5, spread = 180, life = 1.2, rate = 10, light = 1})
		local glow = Instance.new("PointLight")
		glow.Color = c
		glow.Range = r.u * 2.5
		glow.Brightness = 0.8
		glow.Parent = body
	end
	rigs[m] = r
end

---------------------------------------------------------------- posing
local function jointRel(r, name, rot, move)
	local L = r.limbs[name]
	if not L then return CFrame.identity end
	return CFrame.new(L.joint + (move or Vector3.zero)) * (rot or CFrame.identity) * CFrame.new(-L.joint)
end
local function place(r, root, name, rot, move)
	local L = r.limbs[name]
	if L then L.part.CFrame = root * jointRel(r, name, rot, move) * L.rest end
end

local function setT(p, t) if p.Transparency ~= t then p.Transparency = t end end
local function setSize(p, s) if (p.Size - s).Magnitude > 0.004 then p.Size = s end end

local function face(r, now, dt, eyesGoal, mouthGoal)
	local open = eyesGoal
	if now > r.blinkAt then
		if now > r.blinkAt + 0.12 then
			r.blinkAt = now + 1.8 + math.random() * 3.5
			if math.random() < 0.2 then r.blinkAt = now + 0.25 end
		else open = 0 end
	end
	r.eyesNow += (math.clamp(open, 0, 1) - r.eyesNow) * math.min(1, dt * 22)
	r.mouthNow += (mouthGoal - r.mouthNow) * math.min(1, dt * 12)
	local char = player.Character
	local hd = char and char:FindFirstChild("Head")
	local target = hd and (hd.Position - r.body.Position).Magnitude < 40 and hd.Position
	if now > (r.nextGlance or 0) then
		r.nextGlance = now + 0.6 + math.random() * 2
		r.glance = Vector2.new((math.random() - 0.5) * 1.4, (math.random() - 0.5) * 0.8)
	end
	local closed = 1 - r.eyesNow
	for _, e in r.riders do
		local p, pcf = e.part, e.parent.CFrame
		local cf = pcf * e.rel
		if e.face == "Lid" then
			if closed < 0.04 then setT(p, 1) else
				setT(p, e.t0)
				local h = math.max(0.03, closed)
				setSize(p, e.size * Vector3.new(1, h, 1))
				cf *= CFrame.new(0, e.size.Y * (1 - h) / 2, 0)
			end
		elseif e.face == "Glint" or e.face == "Pupil" then
			local d = r.glance or Vector2.zero
			if target then
				local dir = pcf:VectorToObjectSpace((target - pcf.Position).Unit)
				d = Vector2.new(dir.X, dir.Y)
			end
			if d.Magnitude > 1 then d = d.Unit end
			local k = e.face == "Pupil" and 0.2 or 0.1
			cf = pcf * CFrame.new(d.X * e.parent.Size.X * k, d.Y * e.parent.Size.Y * k, 0) * e.rel
			setT(p, closed > 0.55 and 1 or e.t0)
		elseif e.face == "Mouth" then
			local mo = r.mouthNow
			if mo < 0.05 then setT(p, 1) else
				setT(p, e.t0)
				setSize(p, e.size * Vector3.new(0.55 + 0.45 * mo, math.max(0.06, mo), 1))
			end
		end
		p.CFrame = cf
	end
end

---------------------------------------------------------------- herds
-- the leader of a herd (the first member still around); followers keep their spot next to it
local function herdLeader(r)
	local H = r.herd and herds[r.herd]
	if not H then return nil end
	local L = H.leader
	if not L or not L.m.Parent or not rigs[L.m] then
		H.leader = r
		L = r
	end
	if L ~= r and not r.herdOff then
		local off = r.home - L.home
		off = Vector3.new(off.X, 0, off.Z)
		if off.Magnitude > 7 then off = off.Unit * 7 end
		if off.Magnitude < 2 then off = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit * 3 end
		r.herdOff = off
	end
	return L ~= r and L or nil
end

---------------------------------------------------------------- brain + pose each frame
local function update(r, now, dt)
	local u, t, info = r.u, now + r.seed, r.info
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local near = hrp and (hrp.Position - r.pos).Magnitude < 30 and hrp.Position
	local m = r.m
	local sg = m:GetAttribute("Goal") -- the server (Combat) drives this mob: walk to Goal at Spd, attack on Act
	local leader = not sg and herdLeader(r)
	local speedMul = 1
	local dead = m:GetAttribute("Dead")
	if sg then
		local a = m:GetAttribute("Act")
		if a ~= r.act then
			if r.act ~= nil and not dead then
				r.state, r.stateAt, r.fired = "attack", now, false
				r.nextThink = now + info.attack
			end
			r.act = a
		end
		if r.state == "attack" and now > r.nextThink then r.state = "idle" end
		local d = Vector3.new(sg.X - r.pos.X, 0, sg.Z - r.pos.Z)
		-- (no snapping: a chase goal can be far away, e.g. when you zap it from range; it always walks there.
		--  It only hurries a bit when it fell behind, like after playing its attack move.)
		r.absSpeed = (m:GetAttribute("Spd") or info.speed * u) * (d.Magnitude > 14 and 1.25 or 1)
		if r.state ~= "attack" and not dead and d.Magnitude > 0.25 then
			r.state, r.goal = "walk", Vector3.new(sg.X, r.pos.Y, sg.Z)
		elseif r.state == "walk" then
			r.state = "idle"
		end
		-- angry: keep an eye on who it's after
		local tid = m:GetAttribute("Angry") and m:GetAttribute("TargetId")
		local tp = tid and Players:GetPlayerByUserId(tid)
		local th = tp and tp.Character and tp.Character:FindFirstChild("HumanoidRootPart")
		if th then near = th.Position end
	end

	-- decide: idle -> walk somewhere nearby / signature move -> idle ...
	if not sg and r.state ~= "walk" and now > r.nextThink then
		if r.state == "idle" then
			if math.random() < (near and 0.5 or (leader and 0.15 or 0.3)) then
				r.state, r.stateAt, r.fired = "attack", now, false
				r.nextThink = now + info.attack
			elseif not leader then
				local a, d = math.random() * TAU, (0.4 + math.random() * 0.6) * r.roam
				r.goal = r.home + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
				r.state = "walk"
			else
				r.nextThink = now + 1 + math.random() * 2
			end
		else
			r.state = "idle"
			r.nextThink = now + 2 + math.random() * 3
		end
	end
	-- followers: when the leader sets off, trot after it and keep your spot in the group
	if not sg and leader and r.state ~= "attack" then
		local spot = (leader.state == "walk" and leader.goal or leader.pos) + r.herdOff
		local far = Vector3.new(spot.X - r.pos.X, 0, spot.Z - r.pos.Z).Magnitude
		if leader.state == "walk" or far > 3 then
			r.goal = spot
			if far > 0.3 then r.state = "walk" end
			speedMul = 1.05 + math.clamp(far / 12, 0, 0.6)
		end
	end
	local walking = r.state == "walk"
	local goalYaw = r.yaw
	if walking then
		local d = r.goal - r.pos
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude < 0.15 then
			r.state, r.nextThink = "idle", now + 1.5 + math.random() * 2.5
		else
			r.pos += d.Unit * math.min(d.Magnitude, (sg and r.absSpeed or info.speed * u * speedMul) * dt)
			goalYaw = math.atan2(-d.X, -d.Z)
			if info.move == "scuttle" then goalYaw += math.pi / 2 end -- crabs walk sideways
			-- follow the ground
			if r.lift and now > (r.rayAt or 0) then
				r.rayAt = now + 0.12
				local g = groundAt(r.pos)
				if g then r.groundY = g + r.lift end
			end
		end
	elseif near then -- turn to watch you
		local d = near - r.pos
		goalYaw = math.atan2(-d.X, -d.Z)
	end
	if r.lift then r.pos = Vector3.new(r.pos.X, r.pos.Y + (r.groundY - r.pos.Y) * math.min(1, dt * 8), r.pos.Z) end
	local dy = (goalYaw - r.yaw + math.pi) % TAU - math.pi
	r.yaw += dy * math.min(1, dt * (walking and 6 or 2.5))
	local stepRate = ({slide = 3, stomp = 4, waddle = 11, scuttle = 16, walk = 8})[info.move] or 9
	if walking then r.step += dt * stepRate * speedMul end

	-- pose
	local y, z, pitch, roll, spin = math.sin(t * 2.2) * 0.012 * u, 0, 0, 0, 0
	local hy, hp, hr = math.noise(t * 0.3, r.seed) * 0.3, math.sin(t * 1.1) * 0.04, math.noise(t * 0.25, r.seed + 3) * 0.1
	local earOut, earTw = 0, 0
	local flapAmp, flapRate = 0.08, 2
	local armRot, legRot = 0, 0
	local eyes, mouth = 1, 0
	local stalk = 0 -- Potsnail: 1 = eye stalks pulled in
	local crestLift, tailWag, tailRate = 0, 0.15, 3
	local mv = info.move
	if mv == "fly" then y += (0.18 + math.sin(t * 3) * 0.04) * u flapAmp, flapRate = 0.6, 30 end
	if mv == "hover" then y += (0.06 + math.sin(t * 1.4) * 0.03) * u flapAmp, flapRate = 0.35, 6 end
	if mv == "float" then y += (0.12 + math.sin(t * 1.8) * 0.05) * u roll += math.sin(t * 1.3) * 0.06 armRot = math.sin(t * 2) * 0.2 end
	if walking then
		local s = math.sin(r.step)
		if mv == "hop" then
			y += math.abs(s) * 0.16 * u
			pitch -= 0.08
		elseif mv == "slide" then
			z += s * 0.02 * u -- slow stretch and pull
			pitch += s * 0.03
		elseif mv == "fly" then
			pitch -= 0.25
			flapRate = 38
		elseif mv == "hover" then
			pitch -= 0.08
			flapAmp, flapRate = 0.5, 9
		elseif mv == "float" then
			pitch -= 0.15
			roll += s * 0.05
		elseif mv == "waddle" then
			roll += s * 0.14
			y += math.abs(s) * 0.04 * u
		elseif mv == "scuttle" then
			y += math.abs(s) * 0.025 * u
			roll += s * 0.04
		elseif mv == "roll" then
			r.rollAng -= dt * info.speed * 2 * speedMul
		elseif mv == "stomp" then
			y += math.abs(s) * 0.03 * u
			roll += s * 0.05
			pitch -= 0.05
		else
			y += math.abs(s) * 0.05 * u
			pitch -= 0.06
		end
		legRot = s * 0.35
		armRot += s * 0.4
		hy *= 0.3
		tailWag, tailRate = 0.3, 8
	end
	if mv == "roll" then
		if not walking then -- settle back upright
			local target = math.floor(r.rollAng / TAU + 0.5) * TAU
			r.rollAng += (target - r.rollAng) * math.min(1, dt * 4)
		end
		pitch += r.rollAng
	end
	-- head turns toward you on top of the body
	if near and not walking then
		local rel = (CFrame.new(r.pos) * CFrame.Angles(0, r.yaw, 0)):PointToObjectSpace(near)
		hy = math.clamp(math.atan2(-rel.X, -rel.Z), -0.6, 0.6)
		tailWag, tailRate = 0.35, 10
	end
	if now - (r.twitchAt or 0) > 2 + (r.seed % 3) then r.twitchAt, r.twitchSide = now, math.random() < 0.5 and 1 or -1 end
	local tk = now - (r.twitchAt or 0)
	if tk < 0.4 then earTw = math.sin(tk / 0.4 * TAU) * 0.3 end

	-- signature moves
	if r.state == "attack" then
		local k, dur = now - r.stateAt, info.attack
		local w = env(k, dur, 0.25)
		local kind = r.kind
		local function fire(at, n) if k > at and not r.fired then r.fired = true if r.fx then r.fx:Emit(n) end end end
		if kind == "Puffbloom" then -- big breath in, then a seed-puff sneeze
			local wind = smooth(k / 0.9) * (1 - smooth((k - 0.9) / 0.15))
			local blow = smooth((k - 0.9) / 0.12) * (1 - smooth((k - 1.3) / 0.4))
			hp += 0.35 * wind - 0.45 * blow
			y += 0.05 * u * wind
			z -= 0.12 * u * blow
			eyes = 1 - 0.8 * wind - 0.9 * blow
			mouth = 0.5 * wind + blow
			armRot = -0.8 * wind
			fire(0.95, 30)
		elseif kind == "Bumblebun" then -- wind up, bonk dash forward, buzz back
			local back = smooth(k / 0.4) * (1 - smooth((k - 0.4) / 0.1))
			local dash = smooth((k - 0.45) / 0.15) * (1 - smooth((k - 0.8) / 0.5))
			z += 0.25 * u * back - 0.9 * u * dash
			pitch += 0.25 * back - 0.45 * dash
			flapRate = 45
			eyes = 1 - 0.5 * back
			mouth = dash
			fire(0.45, 12)
		elseif kind == "Potsnail" then -- pulls into its pot, wobbles, peeks out
			stalk = w
			y -= 0.08 * u * w
			roll += math.sin(k * 12) * 0.06 * w * (k > 0.8 and k < dur - 0.8 and 1 or 0)
			eyes = 1 - w
			mouth = 0
		elseif kind == "QueenBuzzbloom" then -- rises, raises the scepter, pollen burst
			local up = smooth(k / 0.8) * (1 - smooth((k - dur + 0.6) / 0.6))
			y += 0.12 * u * up
			armRot = -1.6 * up
			flapAmp, flapRate = 0.55, 10
			hp += 0.2 * up
			mouth = up
			fire(1.1, 45)
		elseif kind == "Mushling" then -- squats down, then pops up and puffs sleepy spores from its cap
			local squat = smooth(k / 0.6) * (1 - smooth((k - 0.7) / 0.15))
			local puff = smooth((k - 0.75) / 0.1) * (1 - smooth((k - 1.3) / 0.6))
			y += -0.06 * u * squat + 0.12 * u * puff
			crestLift = 0.08 * u * puff
			eyes = 0.55 - 0.45 * squat + 0.4 * puff
			mouth = puff
			armRot = -0.7 * puff
			fire(0.8, 25)
		elseif kind == "AcornKnight" then -- raises the twig sword, charges forward, trots back
			local raise = smooth(k / 0.4) * (1 - smooth((k - 0.5) / 0.15))
			local dash = bump(k, 0.5, 1.5)
			z -= 0.8 * u * dash
			pitch -= 0.25 * dash
			armRot = -1.5 * raise + 0.9 * dash
			mouth = dash
			fire(0.55, 10)
		elseif kind == "Twiggle" then -- freezes like a stick (eyes shut, arms up), then pops out with a hop
			local hide = smooth(k / 0.3) * (1 - smooth((k - dur + 0.7) / 0.2))
			local pop = bump(k, dur - 0.6, dur)
			eyes = 1 - hide
			armRot = -0.9 * hide
			hy, hr = 0, 0
			y += 0.35 * u * pop - 0.04 * u * hide
			mouth = pop
			legRot = 0
			fire(dur - 0.55, 14)
		elseif kind == "Snowpuff" then -- tucks in and rolls forward like a snowball, then back
			local go = bump(k, 0.2, dur - 0.1)
			z -= 0.9 * u * go
			pitch -= TAU * smooth((k - 0.25) / (dur - 0.5))
			eyes = 1 - go
			fire(0.25, 18)
		elseif kind == "Pengling" then -- flops on its belly and slides forward
			local flop = env(k, dur, 0.3)
			pitch -= 1.25 * flop
			y -= 0.12 * u * flop
			z -= 1.1 * u * bump(k, 0.25, dur - 0.2)
			armRot = 0.7 * flop + math.sin(k * 14) * 0.2 * flop
			mouth = flop
			if k > 0.3 and r.fx and now > (r.puffAt or 0) then r.puffAt = now + 0.25 r.fx:Emit(4) end
		elseif kind == "GaleSprite" then -- puffs its cheeks and blows a spinning gust
			local wind = smooth(k / 0.5) * (1 - smooth((k - 0.6) / 0.1))
			local blow = smooth((k - 0.6) / 0.1) * (1 - smooth((k - dur + 0.3) / 0.3))
			spin = TAU * smooth((k - 0.6) / (dur - 0.7))
			y += 0.1 * u * blow
			mouth = 0.4 * wind + blow
			eyes = 1 - 0.6 * blow
			armRot = -0.6 * wind + 0.5 * blow
			fire(0.62, 20)
		elseif kind == "IceWyrm" then -- rears its head back, then a long frosty breath
			local wind = smooth(k / 0.7) * (1 - smooth((k - 0.8) / 0.15))
			local blow = smooth((k - 0.8) / 0.15) * (1 - smooth((k - dur + 0.4) / 0.4))
			hp += 0.35 * wind - 0.3 * blow
			pitch += 0.1 * wind - 0.08 * blow
			mouth = 0.3 * wind + blow
			flapAmp, flapRate = 0.5, 8
			if blow > 0.3 and r.fx and now > (r.puffAt or 0) then r.puffAt = now + 0.08 r.fx:Emit(3) end
		elseif kind == "GemshellCrab" then -- raises both claws and snaps them
			local up = env(k, dur, 0.2)
			armRot = -0.9 * up + math.sin(k * 20) * 0.25 * up
			y += math.abs(math.sin(k * 10)) * 0.04 * u * up
			mouth = up * 0.6
			fire(0.3, 12)
		elseif kind == "Glowbat" then -- swoops down and back up
			local sw = bump(k, 0, dur)
			y -= 0.3 * u * sw
			z -= 0.7 * u * sw
			pitch -= 0.5 * sw
			flapRate = 50
			mouth = sw
			fire(0.2, 16)
		elseif kind == "Rockroll" then -- curls up and rolls at you, then rolls back
			local go = bump(k, 0.2, dur - 0.1)
			z -= 1.1 * u * go
			pitch -= 2 * TAU * smooth((k - 0.25) / (dur - 0.5))
			eyes = 1 - go
			if go > 0.2 and r.fx and now > (r.puffAt or 0) then r.puffAt = now + 0.15 r.fx:Emit(3) end
		elseif kind == "Cinderpup" then -- happy spinning hop with a pop of embers
			local hop = bump(k, 0.15, dur - 0.15)
			y += 0.45 * u * hop
			spin = TAU * smooth((k - 0.15) / (dur - 0.3))
			mouth = 1
			tailWag, tailRate = 0.6, 22
			fire(0.5, 20)
		elseif kind == "Emberbeetle" then -- backs up, lowers its horn and charges
			local back = smooth(k / 0.5) * (1 - smooth((k - 0.55) / 0.1))
			local dash = bump(k, 0.6, dur)
			z += 0.2 * u * back - 0.8 * u * dash
			pitch += 0.15 * back - 0.2 * dash
			mouth = dash
			fire(0.62, 12)
		elseif kind == "Smoglet" then -- three little ash coughs, then darts back
			local cough = 0
			for i = 0, 2 do cough = math.max(cough, bump(k, 0.2 + i * 0.4, 0.45 + i * 0.4)) end
			pitch += 0.25 * cough
			hp -= 0.2 * cough
			mouth = cough
			eyes = 1 - 0.7 * cough
			z += 0.7 * u * bump(k, 1.4, dur)
			if cough > 0.7 and r.fx and now > (r.puffAt or 0) then r.puffAt = now + 0.35 r.fx:Emit(8) end
		elseif kind == "BrambleBear" or kind == "GemGolem" or kind == "LavaTitan" then -- rears up, arms high, big ground slam
			local up = smooth(k / 1.0) * (1 - smooth((k - 1.2) / 0.2))
			local slam = smooth((k - 1.2) / 0.15) * (1 - smooth((k - 1.8) / 0.6))
			pitch += 0.25 * up - 0.18 * slam
			y += 0.06 * u * up - 0.03 * u * slam
			armRot = -2.0 * up + 0.6 * slam
			hp += 0.2 * up - 0.15 * slam
			mouth = up
			eyes = 1 - 0.6 * slam
			crestLift = 0.03 * u * slam
			fire(1.25, 40)
		else
			y += math.sin(k / dur * math.pi) * 0.3 * u
			mouth = w
		end
	end

	-- defeated: a happy dizzy spin up into sparkles (Combat removes it a moment later)
	if dead then
		r.deadAt = r.deadAt or now
		local k = now - r.deadAt
		spin += k * k * 30
		y += k * u * 0.9
		eyes, mouth = 0, 1
	end

	-- place everything
	local root = CFrame.new(r.pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, r.yaw + spin, 0) * CFrame.new(0, 0, z) * CFrame.Angles(pitch, 0, roll)
	local bodyCF = root * r.bodyInPivot
	r.body.CFrame = bodyCF
	local L = r.limbs
	local head = CFrame.Angles(0, hy, 0) * CFrame.Angles(hp, 0, hr)
	place(r, bodyCF, "Head", head)
	local headRoot = L.Head and bodyCF * jointRel(r, "Head", head) or bodyCF
	for _, n in {"EarL", "EarR"} do
		local E = L[n]
		if E then
			local s = E.side
			local tw = (s == r.twitchSide) and earTw or 0
			if r.kind == "Potsnail" then -- eye stalks: wobble, fold back and sink into the pot when hiding
				place(r, headRoot, n, CFrame.Angles(math.sin(t * 2 + s) * 0.12 - 1.3 * stalk, 0, s * (math.sin(t * 1.6) * 0.1 - tw)),
					Vector3.new(0, -E.part.Size.Y * 0.6 * stalk, 0))
			else
				place(r, headRoot, n, CFrame.Angles(math.sin(t * 2 + s) * 0.05, 0, s * (-earOut - tw)))
			end
		end
	end
	place(r, headRoot, "Crest", CFrame.Angles(math.sin(t * 2.3) * 0.1, 0, math.sin(t * 1.7) * 0.12), Vector3.new(0, crestLift, 0))
	r.flapPh += dt * flapRate
	local flap = math.sin(r.flapPh) * flapAmp
	for _, n in {"WingL", "WingR"} do
		local W = L[n]
		if W then place(r, bodyCF, n, CFrame.Angles(0, 0, W.side * (flap + 0.1))) end
	end
	for _, n in {"ArmL", "ArmR", "ArmR2", "ArmL2"} do
		local A = L[n]
		if A then
			local swing = (A.side < 0) and armRot or -armRot
			if r.state == "attack" then swing = armRot end
			place(r, bodyCF, n, CFrame.Angles(swing, 0, 0))
		end
	end
	place(r, bodyCF, "Tail", CFrame.Angles(0, math.sin(t * tailRate) * tailWag, 0))
	place(r, bodyCF, "Feet", CFrame.Angles(legRot * 0.4, 0, walking and math.sin(r.step) * 0.12 or 0))
	place(r, bodyCF, "LegsF", CFrame.Angles(legRot, 0, 0))
	place(r, bodyCF, "LegsB", CFrame.Angles(-legRot, 0, 0))
	for n, P in L do
		if not (n == "Head" or n == "Crest" or n == "Tail" or n:match("^Ear") or n:match("^Wing") or n:match("^Arm") or n == "Feet" or n:match("^Legs")) then
			place(r, bodyCF, n, (n == "Shell" or n == "Plants") and CFrame.Angles(0, 0, math.sin(t * 9) * 0.03 * stalk) or nil)
		end
	end
	face(r, now, dt, eyes, mouth)
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local cam = workspace.CurrentCamera
	local cp = cam and cam.CFrame.Position
	for m, r in rigs do
		if not m.Parent then
			rigs[m] = nil
		elseif cp and (r.pos - cp).Magnitude > 260 then
			-- too far away to see: skip it (big generated maps have lots of mobs)
		else
			local ok, err = pcall(update, r, now, math.min(dt, 0.1))
			if not ok then warn("MobAnimator:", m.Name, err) rigs[m] = nil end
		end
	end
end)

local function forget(m)
	local r = rigs[m]
	rigs[m] = nil
	if r and r.herd and herds[r.herd] and herds[r.herd].leader == r then herds[r.herd].leader = nil end
end
CollectionService:GetInstanceAddedSignal("MobRig"):Connect(function(m) task.defer(setup, m) end)
CollectionService:GetInstanceRemovedSignal("MobRig"):Connect(forget)
for _, m in CollectionService:GetTagged("MobRig") do task.spawn(setup, m) end
