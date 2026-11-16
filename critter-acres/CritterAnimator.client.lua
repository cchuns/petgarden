-- Critter Acres: CritterAnimator (StarterPlayerScripts LocalScript)
-- Brings "rigged" critters to life (models in ReplicatedStorage.PetModels with a Rig attribute and
-- separate limb parts). The server only moves an invisible Body (tag "RiggedCritter"); this script
-- shows a local copy of the full model on top of it and moves every limb around its joint.
--   Cat:    breathing, tail swish, walking paws, purring (kneads + hearts), paw licking, stretching, looking around
--   Dragon: wing flapping in flight, banking and pitching, tucked legs, landing, roaring and fire breath,
--           face: watches you, moving jaw (roar, snaps, yawn, breathing), blinking/squinting eyes,
--           curious head tilt, nostril snorts. Jaw/EyeL/EyeR are optional parts riding on the Head.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Fire colors (start -> middle -> end). Swap for orange fire: (255,240,120) -> (255,140,40) -> (80,40,30)
local FIRE_COLORS = {Color3.fromRGB(230, 255, 140), Color3.fromRGB(120, 255, 60), Color3.fromRGB(30, 70, 30)}

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))

-- One-piece pets: how each one moves (hop = bouncy, waddle = side to side, float = hovers, wobble = jelly)
local BLOB_STYLE = {
	Splashy = "wobble", Drizzle = "float", Hopsy = "hop", Sprig = "hop", Bloomby = "hop", Pockets = "waddle",
	Glimmer = "float", Prism = "float", Pebbleback = "waddle", Nibblet = "hop", Zippit = "hop", Thornox = "waddle",
	Emberclaw = "hop", Frostmaw = "waddle", Stormwing = "float",
}
local STEP_RATE = {hop = 9, waddle = 8, float = 3, wobble = 7}
-- tap / pet sounds (free Creator Store audio)
local PET_SOUND = {Blob = "rbxassetid://115624890613221", Cat = "rbxassetid://134699420140804", Dragon = "rbxassetid://104011232223797"}
local JOB_EMOTE = {Water = "💧", Harvest = "🍓", Plant = "🌱", Grow = "✨"}

local visuals = Instance.new("Folder")
visuals.Name = "CritterVisuals"
visuals.Parent = workspace

local rigs = {}
local float -- emoji bubble, defined in the effects section below

local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
-- 0 -> 1 -> 0 envelope over an action that lasts `dur` seconds, easing in and out
local function envelope(k, dur, ease) return smooth(math.min(k, dur - k) / (ease or 0.4)) end

---------------------------------------------------------------- setup
local function setup(model)
	if rigs[model] then return end
	local body = model.PrimaryPart or model:WaitForChild("Body", 5)
	local folder = ReplicatedStorage:FindFirstChild("PetModels")
	local template = folder and folder:FindFirstChild(model.Name)
	if not (body and template and model.Parent) then return end
	body.Transparency = 1 -- local only: the server's body just carries position, prompt and name tag
	local v = template:Clone()
	v:ScaleTo(model:GetScale())
	v:PivotTo(model:GetPivot())
	local vbody = v.PrimaryPart
	local limbs = {}
	local riderParts = {}
	for _, p in v:GetChildren() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			if p ~= vbody and p:GetAttribute("Ride") then
				riderParts[#riderParts + 1] = p -- face bits (eyes, lids, pupils, mouth) that ride on another part
			elseif p ~= vbody then
				local rest = vbody.CFrame:ToObjectSpace(p.CFrame)
				local joint = rest * ((p:GetAttribute("JointFrac") or Vector3.zero) * p.Size)
				limbs[p.Name] = {part = p, rest = rest, joint = joint, size = p.Size}
			end
		end
	end
	-- riders keep their rest offset from the part they ride; parents are placed before children
	local riders = {}
	for _, p in riderParts do
		local parent = v:FindFirstChild(p:GetAttribute("Ride"))
		if parent and parent:IsA("BasePart") then
			local depth, q = 0, p
			while q and q:GetAttribute("Ride") and depth < 6 do depth += 1 q = v:FindFirstChild(q:GetAttribute("Ride")) end
			riders[#riders + 1] = {part = p, parent = parent, rel = parent.CFrame:ToObjectSpace(p.CFrame), size = p.Size, face = p:GetAttribute("Face"),
				depth = depth, t0 = p:GetAttribute("Alpha") or p.Transparency} -- lids/mouth are stored hidden (icons), Alpha is how they look when shown
		end
	end
	table.sort(riders, function(a, b) return a.depth < b.depth end)
	local _, size = v:GetBoundingBox()
	v.Parent = visuals
	local now = os.clock()
	local T = Data.SpeciesByName[model.Name]
	local r
	r = {
		style = BLOB_STYLE[model.Name] or "hop",
		emote = T and (JOB_EMOTE[T.Job or ""] or (T.Role == "Battler" and "⚡")) or "✨",
		battler = T and T.Role == "Battler",
		size0 = vbody.Size, bodyInPivot = model:GetPivot():ToObjectSpace(body.CFrame), lookYaw2 = 0,
		model = model, body = body, v = v, vbody = vbody, limbs = limbs, kind = model:GetAttribute("Rig") or "Blob",
		u = size.Y, seed = math.random() * 100, nextAction = now + 1 + math.random() * 3,
		lastPos = body.Position, lastLook = body.CFrame.LookVector, vy = 0, yawRate = 0,
		fly = 0, pitch = 0, bank = 0, flap = 0, nextFloat = 0, nextAirFire = now + 6 + math.random() * 6,
		lookYaw = 0, lookPitch = 0, jaw = 0, nextBlink = now + 2, nextSnort = now + 4 + math.random() * 4,
		riders = riders, faceBlink = now + 1 + math.random() * 3, eyesNow = 1, mouthNow = 0,
	}
	rigs[model] = r
	-- where a hat sits: worked out once in the rest pose, relative to the head (rigs) or the body (one-piece)
	local spot, width = CritterUI.HatSpot(v)
	r.hatAnchor = limbs.Head and limbs.Head.part or vbody
	r.hatRel = r.hatAnchor.CFrame:ToObjectSpace(spot)
	r.hatWidth = math.max(0.3, width)
	model:GetAttributeChangedSignal("Work"):Connect(function() r.workAt = os.clock() end)
	model:GetAttributeChangedSignal("Outfit"):Connect(function() r.dress() end)
	model:GetAttributeChangedSignal("Variant"):Connect(function() r.shine() end)
	model:GetAttributeChangedSignal("PetAt"):Connect(function() r.petted() end)
	model:GetAttributeChangedSignal("TrickAt"):Connect(function()
		r.trick, r.trickAt = model:GetAttribute("Trick"), os.clock()
		r.sound()
		local icon
		for _, t in Data.Tricks do
			if t.Name == r.trick then icon = t.Icon end
		end
		if icon then float(r, icon) end
	end)

	function r.dress()
		if r.hat then r.hat:Destroy() r.hat = nil end
		local hat = CritterUI.BuildOutfit(model:GetAttribute("Outfit"))
		if not hat then return end
		hat:ScaleTo(r.hatWidth)
		hat.Parent = v
		r.hat = hat
	end
	function r.shine() -- shiny = golden glow, rainbow = color-cycling glow
		if r.hl then r.hl:Destroy() r.hl = nil end
		r.variant = model:GetAttribute("Variant")
		local info = r.variant and Data.VariantByName[r.variant]
		if not info then return end
		local hl = Instance.new("Highlight")
		hl.Adornee = v
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.FillColor = info.Color
		hl.FillTransparency = 0.6
		hl.OutlineColor = Color3.fromRGB(255, 245, 190)
		hl.OutlineTransparency = 0.15
		hl.Parent = v
		r.hl = hl
	end
	function r.petted() -- hearts, a happy sound, then a happy move
		local t0 = os.clock()
		r.petAt = t0
		r.sound()
		for i = 0, 2 do
			task.delay(i * 0.22, function() if rigs[model] then float(r, i == 1 and "💖" or "❤️") end end)
		end
		if model:GetAttribute("Moving") or model:GetAttribute("Flying") or model:GetAttribute("Napping") then return end
		if r.kind == "Cat" then
			r.action, r.actionStart, r.actionDur = "Purr", t0, 4
		elseif r.kind == "Dragon" then
			if r.action ~= "Roar" then r.action, r.actionStart, r.actionDur = "Curious", t0, 3.5 end
		else
			r.action, r.actionStart, r.actionDur, r.emoted = (math.random() < 0.5 and "Wiggle" or "Spin"), t0, 1.2, true
		end
	end
	function r.sound() -- squeak / meow / roar (bigger pets sound deeper)
		local s = Instance.new("Sound")
		s.SoundId = PET_SOUND[r.kind] or PET_SOUND.Blob
		s.Volume = 0.7
		s.RollOffMaxDistance = 70
		s.PlaybackSpeed = math.clamp(1.25 - r.u * 0.06, 0.7, 1.3) * (0.92 + math.random() * 0.16)
		s.Parent = r.vbody
		s:Play()
		task.delay(4, function() s:Destroy() end)
	end
	r.dress()
	r.shine()
end

-- Tricks (buddy bar): a whole-body move on top of the normal animation. Returns an offset CFrame
-- relative to the critter's pivot (or nil when no trick is playing).
local TRICK_TIME = {Spin = 0.9, Jump = 0.8, Dance = 2.2, Flip = 1.0, Roll = 1.1}
local function trickCF(r, now)
	if not r.trick or not r.trickAt then return nil end
	local dur = TRICK_TIME[r.trick] or 1
	local k = now - r.trickAt
	if k > dur then r.trick = nil return nil end
	local f = k / dur
	local u = r.u
	local arc = math.sin(f * math.pi)
	if r.trick == "Spin" then
		return CFrame.new(0, arc * 0.4 * u, 0) * CFrame.Angles(0, smooth(f) * math.pi * 2, 0)
	elseif r.trick == "Jump" then
		return CFrame.new(0, arc * 1.3 * u, 0) * CFrame.Angles(-arc * 0.25, 0, 0)
	elseif r.trick == "Dance" then
		return CFrame.new(math.sin(k * 7) * 0.15 * u, math.abs(math.sin(k * 7)) * 0.25 * u, 0)
			* CFrame.Angles(0, math.sin(k * 3.5) * 0.7, math.sin(k * 7) * 0.25)
	elseif r.trick == "Flip" then -- backflip around its middle (the pivot is the body's center)
		return CFrame.new(0, arc * 1.1 * u, 0) * CFrame.Angles(smooth(f) * math.pi * 2, 0, 0)
	elseif r.trick == "Roll" then -- barrel roll sideways
		return CFrame.new(arc * 0.6 * u, arc * 0.5 * u, 0) * CFrame.Angles(0, 0, smooth(f) * math.pi * 2)
	end
	return nil
end

-- Every frame after the pose: keep the hat on, make the glow shimmer, show mood bubbles.
local function updateExtras(r, now)
	if r.hat then
		local a, rel = r.hatAnchor, r.hatRel
		if a == r.vbody then rel = CFrame.new(rel.Position * (a.Size / r.size0)) * rel.Rotation end -- follow the squash
		r.hat:PivotTo(a.CFrame * rel)
	end
	if r.hl then
		if r.variant == "Rainbow" then
			r.hl.FillColor = Color3.fromHSV((now * 0.3) % 1, 0.75, 1)
			r.hl.OutlineColor = Color3.fromHSV((now * 0.3 + 0.5) % 1, 0.5, 1)
		else
			r.hl.FillTransparency = 0.62 + math.sin(now * 3) * 0.12
		end
	end
	local m = r.model
	if now > (r.nextMood or 0) then
		r.nextMood = now + 7 + math.random() * 7
		local mood = m:GetAttribute("Mood")
		if not (m:GetAttribute("Napping") or m:GetAttribute("Flying") or m:GetAttribute("Moving")) then
			if mood == "Sad" then float(r, "😢")
			elseif mood == "Happy" and math.random() < 0.5 then float(r, "💖") end
		end
	end
end

local function cleanup(model)
	local r = rigs[model]
	if not r then return end
	rigs[model] = nil
	r.v:Destroy()
end

---------------------------------------------------------------- effects
-- An emoji that floats up from the head and fades (hearts, notes, sparkles...)
function float(r, text)
	local head = r.limbs.Head and r.limbs.Head.part or r.vbody
	local a = Instance.new("Attachment")
	a.Position = Vector3.new((math.random() - 0.5) * head.Size.X * 0.7, head.Size.Y * 0.5, 0)
	a.Parent = head
	local bb = Instance.new("BillboardGui")
	local s = math.max(1, r.u * 0.3)
	bb.Size = UDim2.new(s, 0, s, 0)
	bb.LightInfluence = 0
	bb.Parent = a
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.Text = text
	t.Parent = bb
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(bb, info, {StudsOffset = Vector3.new((math.random() - 0.5) * 1.5, r.u * 0.6, 0)}):Play()
	TweenService:Create(t, info, {TextTransparency = 1, Rotation = (math.random() - 0.5) * 50}):Play()
	task.delay(1.7, function() a:Destroy() end)
end

-- Fire breath out of the dragon's mouth (an emitter + a flickering light on the head)
local function fireFor(r)
	if r.fire then return r.fire end
	local head = r.limbs.Head and r.limbs.Head.part
	if not head then return end
	local s = r.u / 10
	local fwd = head.CFrame:VectorToObjectSpace(r.vbody.CFrame.LookVector)
	local a = Instance.new("Attachment")
	local at = fwd * (math.abs(fwd.X) * head.Size.X + math.abs(fwd.Z) * head.Size.Z) * 0.48 - Vector3.new(0, head.Size.Y * 0.12, 0)
	a.CFrame = CFrame.lookAt(at, at + fwd) * CFrame.Angles(math.rad(-12), 0, 0) -- out of the mouth, aimed a little down
	a.Parent = head
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/fire_main.dds"
	pe.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, FIRE_COLORS[1]), ColorSequenceKeypoint.new(0.35, FIRE_COLORS[2]),
		ColorSequenceKeypoint.new(1, FIRE_COLORS[3])})
	pe.LightEmission = 0.9
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8 * s), NumberSequenceKeypoint.new(0.4, 3.5 * s), NumberSequenceKeypoint.new(1, 6 * s)})
	pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1)})
	pe.Lifetime = NumberRange.new(0.45, 0.7)
	pe.Speed = NumberRange.new(28 * s, 38 * s)
	pe.SpreadAngle = Vector2.new(10, 10)
	pe.Drag = 2
	pe.Acceleration = Vector3.new(0, 6 * s, 0)
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-180, 180)
	pe.EmissionDirection = Enum.NormalId.Front
	pe.Rate = 140
	pe.Enabled = false
	pe.Parent = a
	local light = Instance.new("PointLight")
	light.Color = FIRE_COLORS[2]
	light.Range = 18 * s
	light.Brightness = 0
	light.Parent = a
	r.fire = {emitter = pe, light = light}
	return r.fire
end

-- A puff of smoke out of the nostrils (snorts, after breathing fire)
local function snortPuff(r, count)
	local head = r.limbs.Head and r.limbs.Head.part
	if not head then return end
	if not r.smoke then
		local s = r.u / 10
		local fwd = head.CFrame:VectorToObjectSpace(r.vbody.CFrame.LookVector)
		local a = Instance.new("Attachment")
		local at = fwd * (math.abs(fwd.X) * head.Size.X + math.abs(fwd.Z) * head.Size.Z) * 0.46 + Vector3.new(0, head.Size.Y * 0.18, 0)
		a.CFrame = CFrame.lookAt(at, at + fwd) * CFrame.Angles(math.rad(20), 0, 0) -- puffs go forward and up out of the nostrils
		a.Parent = head
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(190, 220, 170), Color3.fromRGB(120, 130, 120))
		pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4 * s), NumberSequenceKeypoint.new(1, 2.2 * s)})
		pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
		pe.Lifetime = NumberRange.new(0.6, 1)
		pe.Speed = NumberRange.new(4 * s, 7 * s)
		pe.SpreadAngle = Vector2.new(25, 25)
		pe.Drag = 3
		pe.Acceleration = Vector3.new(0, 3 * s, 0)
		pe.EmissionDirection = Enum.NormalId.Front
		pe.Rate = 0
		pe.Parent = a
		r.smoke = pe
	end
	r.smoke:Emit(count or 8)
end

local function setFire(r, on)
	local f = fireFor(r)
	if not f then return end
	local was = f.emitter.Enabled
	f.emitter.Enabled = on
	f.light.Brightness = on and (3 + math.random() * 2) or 0
	if was and not on then task.delay(0.3, snortPuff, r, 12) end -- smoky aftermath
end

---------------------------------------------------------------- posing helpers
-- Body-space transform that rotates limb `name` by `rot` around its joint and shifts it by `move`.
local function jointRel(r, name, rot, move)
	local L = r.limbs[name]
	if not L then return CFrame.identity end
	local j = L.joint
	return CFrame.new(j + (move or Vector3.zero)) * (rot or CFrame.identity) * CFrame.new(-j)
end
-- Place limb `name`. Pass root * (parent's jointRel) as `root` for parts that ride on another (jaw/eyes on the head).
local function place(r, root, name, rot, move)
	local L = r.limbs[name]
	if not L then return end
	L.part.CFrame = root * jointRel(r, name, rot, move) * L.rest
end
-- Squash a part around its center (used for blinking eyes); only touches Size when it changes.
local function squash(r, name, y)
	local L = r.limbs[name]
	if not L or math.abs((L.squash or 1) - y) < 0.02 then return end
	L.squash = y
	L.part.Size = L.size * Vector3.new(1, math.max(0.05, y), 1)
end

local function pickAction(r, now, choices)
	local total = 0
	for _, c in choices do total += c[2] end
	local roll = math.random() * total
	for _, c in choices do
		roll -= c[2]
		if roll <= 0 then
			r.action, r.actionStart, r.actionDur = c[1], now, c[3]
			return
		end
	end
end

local function playerNear(r, dist)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hrp and (hrp.Position - r.body.Position).Magnitude < dist
end

---------------------------------------------------------------- cat
local CAT_ACTIONS = { -- name, weight, seconds
	{"Purr", 3, 5}, {"Groom", 3, 5.5}, {"Stretch", 1, 2.6}, {"Look", 2, 3.2},
}
local function animateCat(r, now, dt, root)
	local u, t = r.u, now + r.seed
	local moving = r.model:GetAttribute("Moving")
	local L = r.limbs
	local rootOff = CFrame.new(0, math.sin(t * 2.2) * 0.012 * u, 0) -- breathing
	local head = CFrame.Angles(0, math.sin(t * 0.5) * 0.15, 0)
	local tail = CFrame.Angles(math.sin(t * 0.9) * 0.1, math.sin(t * 1.6) * 0.45, 0)
	local paws = {PawFL = {}, PawFR = {}, PawBL = {}, PawBR = {}}

	if moving then
		r.action = nil
		local step = t * 13
		for name, phase in {PawFL = 0, PawBR = 0, PawFR = math.pi, PawBL = math.pi} do
			local s = math.sin(step + phase)
			paws[name].move = Vector3.new(0, math.max(0, s) * 0.1 * u, -math.cos(step + phase) * 0.07 * u)
			paws[name].rot = CFrame.Angles(math.cos(step + phase) * 0.4, 0, 0)
		end
		head *= CFrame.Angles(math.sin(step * 2) * 0.05, 0, 0)
		tail = CFrame.Angles(0.35, math.sin(t * 4) * 0.25, 0) -- tail up while trotting
		rootOff *= CFrame.new(0, math.abs(math.sin(step)) * 0.03 * u, 0)
	elseif r.model:GetAttribute("Napping") then
		-- curled up asleep: head down on its paws, tail wrapped round, slow breathing, 💤
		r.action = nil
		rootOff = CFrame.new(0, -0.08 * u + math.sin(t * 1.2) * 0.015 * u, 0) * CFrame.Angles(-0.1, 0, 0.12)
		head = CFrame.Angles(-0.45, 0.25, -0.25)
		tail = CFrame.Angles(-0.2, 0.9, 0)
		paws.PawFL.move = Vector3.new(0, 0, -0.06 * u)
		paws.PawFR.move = Vector3.new(0, 0, -0.06 * u)
		if now > r.nextFloat then
			r.nextFloat = now + 2.4
			float(r, "💤")
		end
	else
		if not r.action and now > r.nextAction then
			if playerNear(r, 10) then -- purrs a lot when you're close
				pickAction(r, now, {{"Purr", 6, 5}, {"Groom", 2, 5.5}, {"Look", 1, 3.2}})
			else
				pickAction(r, now, CAT_ACTIONS)
			end
		end
		if r.action then
			local k = now - r.actionStart
			local w = envelope(k, r.actionDur)
			if r.action == "Purr" then
				-- eyes-closed happy sway, a tiny rumble, kneading front paws, hearts and notes
				rootOff *= CFrame.new(math.noise(t * 40, 1) * 0.008 * u * w, math.noise(t * 40, 2) * 0.008 * u * w, 0)
				head *= CFrame.Angles(0.08 * w, 0, math.sin(t * 1.4) * 0.22 * w)
				tail = CFrame.Angles(0.1 * w, math.sin(t * 0.8) * 0.3, 0)
				paws.PawFL.move = Vector3.new(0, math.max(0, math.sin(t * 5)) * 0.06 * u * w, 0)
				paws.PawFR.move = Vector3.new(0, math.max(0, -math.sin(t * 5)) * 0.06 * u * w, 0)
				if w > 0.5 and now > r.nextFloat then
					r.nextFloat = now + 0.7 + math.random() * 0.5
					float(r, math.random() < 0.65 and "💗" or "🎵")
				end
			elseif r.action == "Groom" then
				-- lift the right front paw up to the mouth and lick it, head tilted down onto it
				local paw, hd = L.PawFR, L.Head
				if paw and hd then
					local mouth = hd.rest * Vector3.new(hd.size.X * 0.12, -hd.size.Y * 0.28, -hd.size.Z * 0.42)
					local lick = math.sin(t * 9)
					paws.PawFR.move = (mouth - paw.rest.Position) * 0.85 * w + Vector3.new(0, lick * 0.03 * u * w, 0)
					paws.PawFR.rot = CFrame.Angles(-1.2 * w, 0, 0.3 * w)
					head *= CFrame.Angles((-0.28 + lick * 0.07) * w, 0.15 * w, -0.2 * w)
					rootOff *= CFrame.Angles(0, 0, -0.04 * w)
					if k > 1 and k < r.actionDur - 1 and now > r.nextFloat and math.random() < 0.02 then
						r.nextFloat = now + 1.2
						float(r, "✨")
					end
				end
			elseif r.action == "Stretch" then
				-- front paws reach forward, chest dips, tail goes straight up
				paws.PawFL.move = Vector3.new(0, 0, -0.18 * u * w)
				paws.PawFR.move = Vector3.new(0, 0, -0.18 * u * w)
				rootOff *= CFrame.Angles(-0.12 * w, 0, 0)
				head *= CFrame.Angles(0.25 * w, 0, 0)
				tail = tail:Lerp(CFrame.Angles(0.6, 0, 0), w)
			elseif r.action == "Look" then
				head *= CFrame.Angles(0.05 * w, math.sin(k * 1.8) * 0.65 * w, math.sin(k * 0.9) * 0.15 * w)
			end
			if k >= r.actionDur then
				r.action = nil
				r.nextAction = now + 1.5 + math.random() * 3.5
			end
		end
	end

	r.eyesGoal = r.model:GetAttribute("Napping") and 0 or (r.action == "Purr" and 0.3 or 1)
	r.mouthGoal = (r.action == "Groom" and 0.6) or (r.action == "Stretch" and 1) or 0
	root *= rootOff
	r.vbody.CFrame = root
	place(r, root, "Head", head)
	place(r, root, "Tail", tail)
	for name, p in paws do place(r, root, name, p.rot, p.move) end
end

---------------------------------------------------------------- dragon
local function animateDragon(r, now, dt, root)
	local u, t = r.u, now + r.seed
	local flying = r.model:GetAttribute("Flying")
	local moving = r.model:GetAttribute("Moving")
	r.fly += ((flying and 1 or 0) - r.fly) * math.min(1, dt * 2.5)
	local fly = r.fly

	-- climb/dive pitch and turn banking from how the body moved since last frame
	local pos, look = r.body.Position, r.body.CFrame.LookVector
	if dt > 0 then
		r.vy += ((pos.Y - r.lastPos.Y) / dt - r.vy) * math.min(1, dt * 4)
		local turn = math.atan2(r.lastLook:Cross(look).Y, r.lastLook:Dot(look)) / dt
		r.yawRate += (turn - r.yawRate) * math.min(1, dt * 4)
	end
	r.lastPos, r.lastLook = pos, look

	-- height above the ground, for take-off and landing poses
	local h = 99
	if fly > 0.01 then
		if not r.rayParams then
			r.rayParams = RaycastParams.new()
			r.rayParams.FilterType = Enum.RaycastFilterType.Exclude
			r.rayParams.FilterDescendantsInstances = {visuals, r.model.Parent}
		end
		local hit = workspace:Raycast(pos, Vector3.new(0, -300, 0), r.rayParams)
		h = hit and (pos.Y - hit.Position.Y) - u * 0.45 or 99
	end
	-- flight phases (0..1 each): take-off, landing flare, dive, glide
	local takeoff = fly > 0.3 and r.vy > 2 and smooth(1 - h / 10) or 0
	local landing = fly > 0.3 and r.vy < -1 and smooth(1 - h / 9) or 0
	local dive = fly > 0.5 and h > 12 and smooth((-r.vy - 5) / 4) or 0
	local wantGlide = (r.vy < -1.5 or (math.abs(r.vy) < 1.5 and math.noise(t * 0.12, r.seed) > 0.1)) and takeoff + landing < 0.1
	r.glide = (r.glide or 0) + ((wantGlide and 1 or 0) - (r.glide or 0)) * math.min(1, dt * 1.5)
	local glide = r.glide * fly

	-- body: climb/dive pitch, nose up to take off and flare to land, bank into turns
	local pitchGoal = (math.clamp(r.vy / 25, -0.45, 0.45) + 0.25 * takeoff + 0.45 * landing) * fly
	r.pitch += (pitchGoal - r.pitch) * math.min(1, dt * 3)
	r.bank += (math.clamp(r.yawRate * 0.6, -0.7, 0.7) * fly - r.bank) * math.min(1, dt * 2.5)

	-- wings: quick powerful downstroke and slower upstroke, wings sweeping back and forth;
	-- harder and faster to take off or brake for landing, spread out to glide, tucked to dive
	local climb = math.clamp(r.vy / 10, 0, 1)
	local amp = (0.75 + climb * 0.2 + takeoff * 0.25 + landing * 0.2) * (1 - glide * 0.85) * (1 - dive)
	r.flap += dt * (6 + climb * 3 + takeoff * 4 + landing * 5) * fly * (1 - glide * 0.6)
	local ph = r.flap + 0.45 * math.sin(r.flap)
	local airWing = 0.18 + math.sin(ph) * amp + glide * math.sin(t * 3) * 0.04
	airWing = airWing * (1 - dive) + 0.4 * dive
	local sweep = (-math.cos(ph) * 0.2 * amp + dive * 0.75 - landing * 0.35) * fly
	local groundWing = math.sin(t * 1.3) * 0.05 - 0.05
	local wing = airWing * fly + groundWing * (1 - fly)

	local rootOff = CFrame.new(0, (-math.cos(ph) * 0.045 * amp * fly + math.sin(t * 1.5) * 0.008) * u, 0)
		* CFrame.Angles(r.pitch, 0, r.bank)
	-- tail trails through turns and ripples with the wingbeat
	local tailYaw = math.sin(t * 1.3) * 0.25 * (1 - fly * 0.6) + math.clamp(r.yawRate * 0.35, -0.5, 0.5) * fly
	local tail = CFrame.Angles(math.sin(t * 2) * 0.08 * (1 - fly) + (0.1 + math.sin(ph - 1.2) * 0.1 * amp - 0.25 * landing) * fly, tailYaw, 0)
	-- legs tucked back in flight, dangling at take-off, reaching down to land
	local tuck = fly * math.clamp(1 - takeoff * 0.7 - landing * 1.2, 0, 1)
	local sway = math.sin(t * 2.2) * 0.05 * fly
	local legF = CFrame.Angles(-0.8 * tuck + 0.35 * landing + sway, 0, 0)
	local legB = CFrame.Angles(-1.0 * tuck + 0.25 * landing - sway, 0, 0)
	local breathing = false

	-- face: head pitch/yaw/roll + push, jaw opening (radians) and eye openness (1 = open, 0 = shut)
	local hPitch = -r.pitch * 0.6 + math.noise(t * 0.35, r.seed) * 0.12
	local hYaw = math.noise(t * 0.25, r.seed + 5) * 0.35 * (1 - fly)
	local hRoll = math.noise(t * 0.3, r.seed + 9) * 0.06
	local hMove = Vector3.zero
	local jaw = 0.05 + math.sin(t * 1.5) * 0.03 -- slow breathing through the mouth
	local eyes = 1
	local lookWeight = 0 -- how much the head turns to watch you

	if fly < 0.5 then
		if moving then
			r.action = nil
			local step = t * 7
			legF *= CFrame.Angles(math.sin(step) * 0.35, 0, 0)
			legB *= CFrame.Angles(-math.sin(step) * 0.35, 0, 0)
			hPitch += math.sin(step * 2) * 0.04
			rootOff *= CFrame.new(0, math.abs(math.sin(step)) * 0.02 * u, 0)
			lookWeight = 0.4
		else
			lookWeight = 1
			if not r.action and now > r.nextAction then
				if playerNear(r, 30) then -- more face reactions when you're close
					pickAction(r, now, {{"Roar", 2, 4.2}, {"Curious", 3, 3.5}, {"Snap", 2, 1.8}, {"Snort", 2, 1.6}, {"Yawn", 1, 3.6}})
				else
					pickAction(r, now, {{"Roar", 3, 4.2}, {"Wings", 2, 3}, {"Look", 2, 3.5}, {"Snort", 2, 1.6}, {"Yawn", 2, 3.6}})
				end
			end
			if r.action then
				local k = now - r.actionStart
				local w = envelope(k, r.actionDur, 0.35)
				if r.action == "Roar" then
					-- rear back with jaws wide and eyes narrowed, then lunge forward and breathe fire
					local wind = smooth(k / 0.8) - smooth((k - 0.8) / 0.4)
					hPitch += (0.45 * wind - 0.22 * smooth((k - 0.9) / 0.3)) * w
					rootOff *= CFrame.Angles(0.06 * wind * w, 0, 0)
					wing += 0.35 * w
					breathing = k > 1 and k < r.actionDur - 0.6
					jaw = jaw + (0.7 * wind + (breathing and 0.5 + math.noise(t * 12) * 0.08 or 0)) * w
					eyes = 1 - 0.45 * w
					hRoll += math.noise(t * 14, 3) * 0.05 * w -- shakes with effort
				elseif r.action == "Wings" then
					-- stretch and give two big flaps
					wing += (math.sin(k / r.actionDur * math.pi * 4) * 0.5 + 0.4) * w
					rootOff *= CFrame.new(0, math.max(0, math.sin(k / r.actionDur * math.pi * 4)) * 0.02 * u * w, 0)
				elseif r.action == "Look" then
					hYaw += math.sin(k * 1.5) * 0.5 * w
					lookWeight = 0
				elseif r.action == "Curious" then
					-- tilts its head at you with wide eyes, then a little chuff
					hRoll += 0.32 * w * math.sin(math.min(k, 1.2) / 1.2 * math.pi / 2)
					hMove = Vector3.new(0, 0, -0.04 * u * w)
					eyes = 1 + 0.15 * w
					jaw = jaw * (1 - w)
					if k > 2.4 and not r.chuffed then r.chuffed = true snortPuff(r, 4) end
				elseif r.action == "Snap" then
					-- three quick chomps with a forward lunge
					local chomp = math.abs(math.sin(k / r.actionDur * math.pi * 3))
					jaw = 0.02 + chomp * 0.5 * w
					hMove = Vector3.new(0, 0, -0.05 * u * chomp * w)
					hPitch -= 0.08 * chomp * w
					eyes = 1 - 0.3 * w
				elseif r.action == "Snort" then
					-- quick head toss with a puff of smoke from the nostrils
					local toss = math.sin(math.clamp(k / 0.35, 0, 1) * math.pi)
					hPitch += 0.18 * toss * w
					jaw = jaw * (1 - w)
					eyes = 1 - 0.5 * toss
					if k > 0.15 and not r.snorted then r.snorted = true snortPuff(r, 10) end
				elseif r.action == "Yawn" then
					-- slow huge yawn: head up, jaws wide, eyes squeezed shut, a little shake at the end
					local open = smooth(k / 1.3) - smooth((k - 2.4) / 0.8)
					hPitch += 0.35 * open * w
					jaw = jaw + 0.85 * open * w
					eyes = 1 - 0.95 * open
					hRoll += math.sin(k * 18) * 0.04 * smooth((k - 2.6) / 0.3) * (1 - smooth((k - 3.2) / 0.3))
					lookWeight = 1 - open
				end
				if k >= r.actionDur then
					r.action, r.chuffed, r.snorted = nil, nil, nil
					r.nextAction = now + 2 + math.random() * 5
				end
			elseif now > r.nextSnort then -- the odd little snort between actions
				r.nextSnort = now + 5 + math.random() * 8
				snortPuff(r, 4)
			end
		end
	else
		r.action = nil
		-- look where it's turning, and the odd fire blast while flying
		hYaw += math.clamp(r.yawRate * 0.3, -0.4, 0.4)
		hRoll -= r.bank * 0.75 -- keeps its head level while the body banks
		hPitch -= r.pitch * 0.3
		jaw = 0.12 + math.sin(t * 3) * 0.04
		if now > r.nextAirFire then
			r.airFireUntil = now + 1.4
			r.nextAirFire = now + 8 + math.random() * 8
		end
		breathing = r.airFireUntil and now < r.airFireUntil
		if breathing then
			hPitch -= 0.15
			jaw = 0.55 + math.noise(t * 12) * 0.08
			eyes = 0.6
		end
	end

	-- watch the local player (head turns toward you when it's close and on the ground)
	local goalYaw, goalPitch = 0, 0
	local char = player.Character
	local headPart = char and char:FindFirstChild("Head")
	if headPart and lookWeight > 0 and r.limbs.Head then
		local rel = r.body.CFrame:PointToObjectSpace(headPart.Position) - r.limbs.Head.joint
		local flat = Vector2.new(rel.X, rel.Z).Magnitude
		if flat < 45 then
			goalYaw = math.clamp(math.atan2(-rel.X, -rel.Z), -0.8, 0.8) * lookWeight
			goalPitch = math.clamp(math.atan2(rel.Y, flat), -0.4, 0.35) * lookWeight
		end
	end
	local ease = math.min(1, dt * 3)
	r.lookYaw += (goalYaw - r.lookYaw) * ease
	r.lookPitch += (goalPitch - r.lookPitch) * ease

	-- blinking
	if now > r.nextBlink then
		if now > r.nextBlink + 0.13 then
			r.nextBlink = now + 1.5 + math.random() * 3.5
			if math.random() < 0.2 then r.nextBlink = now + 0.25 end -- sometimes a double blink
		else
			eyes = 0
		end
	end

	if breathing ~= r.breathing then
		r.breathing = breathing
		setFire(r, breathing)
	elseif breathing and r.fire then
		r.fire.light.Brightness = 3 + math.random() * 2
	end
	r.jaw += (jaw - r.jaw) * math.min(1, dt * 14)

	root *= rootOff
	r.vbody.CFrame = root
	local head = CFrame.Angles(0, hYaw + r.lookYaw, 0) * CFrame.Angles(hPitch + r.lookPitch, 0, hRoll)
	local headRoot = root * jointRel(r, "Head", head, hMove)
	place(r, root, "Head", head, hMove)
	place(r, headRoot, "Jaw", CFrame.Angles(-math.max(0, r.jaw), 0, 0))
	place(r, headRoot, "EyeL")
	place(r, headRoot, "EyeR")
	squash(r, "EyeL", eyes)
	squash(r, "EyeR", eyes)
	r.eyesGoal = eyes
	place(r, root, "Tail", tail)
	place(r, root, "WingL", CFrame.Angles(0, sweep, -wing))
	place(r, root, "WingR", CFrame.Angles(0, -sweep, wing))
	place(r, root, "LegsF", legF)
	place(r, root, "LegsB", legB)
end

---------------------------------------------------------------- one-piece pets
-- The whole body squashes, stretches, hops, rocks and spins (rotations pivot at its feet).
local function blobActions(r, near)
	local cheer = r.model:GetAttribute("Mood") == "Happy" and 2 or 0
	local list = {{"Look", 2, 3}, {"Happy", (near and 4 or 1.5) + cheer, 1.6}, {"Spin", 1 + cheer / 2, 1.1}, {"Wiggle", 1.5, 1.2}, {"Sniff", 1.5, 2}, {"Stretch", 1, 2}}
	if r.battler then table.insert(list, {"Flex", 2.5, 1.2}) end
	if r.style == "float" then table.insert(list, {"Twirl", 2, 2.6}) end
	return list
end

local function animateBlob(r, now, dt)
	local u, t = r.u, now + r.seed
	local style = r.style
	local y, z, yaw, pitch, roll = 0, 0, 0, 0, 0
	local sy = 1 + math.sin(t * 2.2) * 0.025 -- breathing
	local wob = 0
	local lookWeight = 0
	if style == "float" then
		y += (0.12 + math.sin(t * 1.6) * 0.08) * u
		roll += math.sin(t * 1.1) * 0.05
	end
	if r.model:GetAttribute("Mood") == "Sad" then -- droopy: a bit flatter, head down
		sy *= 0.95
		pitch -= 0.08
	end

	if r.model:GetAttribute("Napping") then
		-- curled up asleep: low and slow breathing, tipped over a little, 💤
		r.action = nil
		sy = 0.84 + math.sin(t * 1.2) * 0.035
		roll += 0.3
		pitch -= 0.08
		y *= 0.3
		if now > r.nextFloat then
			r.nextFloat = now + 2.2
			float(r, "💤")
		end
	elseif r.model:GetAttribute("Moving") then
		r.action = nil
		r.walk = (r.walk or 0) + dt * STEP_RATE[style]
		local p = r.walk
		if style == "hop" then -- squash on landing, stretch in the air, lean forward
			local s = math.abs(math.sin(p))
			y += s * 0.3 * u
			sy *= s < 0.25 and (0.82 + s * 0.72) or (1 + (s - 0.25) * 0.16)
			pitch -= 0.12
		elseif style == "waddle" then -- rock side to side
			roll += math.sin(p) * 0.18
			yaw += math.sin(p) * 0.08
			y += math.abs(math.cos(p)) * 0.04 * u
		elseif style == "float" then -- glide along leaning forward
			pitch -= 0.22
			y += math.sin(p * 0.5) * 0.05 * u
		else -- wobble: jelly squish
			wob = math.sin(p * 2) * 0.08
			sy *= 1 + math.sin(p * 2 + 1) * 0.06
			y += math.abs(math.sin(p)) * 0.08 * u
			roll += math.sin(p) * 0.06
		end
	else
		lookWeight = 1
		local near = playerNear(r, 12)
		if not r.action and now > r.nextAction then pickAction(r, now, blobActions(r, near)) end
		if r.action then
			local k = now - r.actionStart
			local dur = r.actionDur
			local f = math.clamp(k / dur, 0, 1)
			local w = envelope(k, dur, 0.25)
			if r.action == "Look" then
				yaw += math.sin(k * 1.6) * 0.7 * w
				lookWeight = 0
			elseif r.action == "Happy" then -- two bouncy hops and a heart
				local s = math.abs(math.sin(f * math.pi * 2))
				y += s * 0.35 * u
				sy *= s < 0.2 and 0.85 or 1 + s * 0.1
				if not r.emoted then r.emoted = true float(r, near and "💛" or r.emote) end
			elseif r.action == "Spin" then -- hop and spin all the way round
				yaw += smooth(f) * math.pi * 2
				y += math.sin(f * math.pi) * 0.4 * u
				sy *= 1 + math.sin(f * math.pi) * 0.12
				lookWeight = 0
			elseif r.action == "Wiggle" then -- happy shake
				roll += math.sin(k * 25) * 0.12 * w
				sy *= 1 - 0.06 * w + math.sin(k * 25) * 0.03 * w
			elseif r.action == "Sniff" then -- nose to the ground, little sniffs
				pitch -= (0.2 + math.sin(k * 14) * 0.05) * w
				yaw += math.sin(k * 2) * 0.2 * w
			elseif r.action == "Stretch" then -- stretch up tall, then settle
				sy *= 1 + 0.18 * math.sin(f * math.pi)
				pitch += 0.1 * math.sin(f * math.pi)
			elseif r.action == "Flex" then -- fighters: wind up, lunge forward, stomp
				local lunge = f < 0.35 and -smooth(f / 0.35) * 0.3 or math.sin((f - 0.35) / 0.65 * math.pi)
				z -= lunge * 0.3 * u
				pitch -= lunge * 0.2
				sy *= 1 - math.max(0, lunge) * 0.12
				if f > 0.4 and not r.emoted then r.emoted = true float(r, "💢") end
			elseif r.action == "Twirl" then -- floaters: slow twirl with sparkles
				yaw += smooth(f) * math.pi * 2
				y += math.sin(f * math.pi) * 0.25 * u
				if not r.emoted then r.emoted = true float(r, "✨") end
			end
			if k >= dur then
				r.action, r.emoted = nil, nil
				r.nextAction = now + 1.5 + math.random() * 4
			end
		end
	end

	-- quick hop-spin after finishing a farm job
	if r.workAt and now - r.workAt < 0.7 then
		local f = (now - r.workAt) / 0.7
		y += math.sin(f * math.pi) * 0.4 * u
		yaw += smooth(f) * math.pi * 2
		sy *= 1 + math.sin(f * math.pi) * 0.12
		lookWeight = 0
	end

	-- turn to look at you when you're close
	local goal = 0
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and lookWeight > 0 then
		local rel = r.model:GetPivot():PointToObjectSpace(hrp.Position)
		if Vector2.new(rel.X, rel.Z).Magnitude < 14 then goal = math.clamp(math.atan2(-rel.X, -rel.Z), -1, 1) * 0.8 end
	end
	r.lookYaw2 += (goal - r.lookYaw2) * math.min(1, dt * 3)

	sy = math.clamp(sy, 0.6, 1.4)
	local sxz = 1 / math.sqrt(sy) -- keep the volume about the same when squashing
	local size = r.size0 * Vector3.new(sxz * (1 + wob), sy, sxz * (1 - wob))
	if r.kind ~= "Critter" and (size - r.vbody.Size).Magnitude > 0.002 then r.vbody.Size = size end
	local anim = CFrame.new(0, y - (1 - sy) * u / 2, z) * CFrame.Angles(0, yaw + r.lookYaw2, 0)
		* CFrame.new(0, -u / 2, 0) * CFrame.Angles(pitch, 0, roll) * CFrame.new(0, u / 2, 0)
	r.vbody.CFrame = r.model:GetPivot() * (r.trickCF or CFrame.identity) * anim * r.bodyInPivot
end

---------------------------------------------------------------- face (any rig with face riders)
-- Eyelids close for blinks / sleep / happy squints, pupils and shines follow you (or glance around),
-- the mouth opens. Rigs set r.eyesGoal (1 open, 0 shut) and r.mouthGoal (0..1).
local function setSize(p, s) if (p.Size - s).Magnitude > 0.004 then p.Size = s end end
local function setT(p, t) if p.Transparency ~= t then p.Transparency = t end end
local function updateFace(r, now, dt)
	local list = r.riders
	if not list or #list == 0 then return end
	local open = math.clamp(r.eyesGoal or 1, 0, 1)
	if r.kind ~= "Dragon" and now > r.faceBlink then -- the dragon blinks by itself
		if now > r.faceBlink + 0.12 then
			r.faceBlink = now + 1.8 + math.random() * 3.5
			if math.random() < 0.2 then r.faceBlink = now + 0.25 end -- sometimes a double blink
		else
			open = 0
		end
	end
	r.eyesNow += (open - r.eyesNow) * math.min(1, dt * 22)
	r.mouthNow += ((r.mouthGoal or 0) - r.mouthNow) * math.min(1, dt * 12)
	local target
	local char = player.Character
	local hd = char and char:FindFirstChild("Head")
	if hd and (hd.Position - r.vbody.Position).Magnitude < 40 then target = hd.Position end
	if now > (r.nextGlance or 0) then -- little glances around when nobody is close
		r.nextGlance = now + 0.6 + math.random() * 2.2
		r.glance = Vector2.new((math.random() - 0.5) * 1.4, (math.random() - 0.5) * 0.8)
	end
	local closed = 1 - math.clamp(r.eyesNow, 0, 1)
	for _, e in list do
		local p, pcf = e.part, e.parent.CFrame
		local cf = pcf * e.rel
		if e.face == "Lid" then -- slides down from the top of the eye
			if closed < 0.04 then
				setT(p, 1)
			else
				setT(p, e.t0)
				local h = math.max(0.03, closed)
				setSize(p, e.size * Vector3.new(1, h, 1))
				cf *= CFrame.new(0, e.size.Y * (1 - h) / 2, 0)
			end
		elseif e.face == "Pupil" or e.face == "Glint" then
			local d = r.glance or Vector2.zero
			if target then
				local dir = pcf:VectorToObjectSpace((target - pcf.Position).Unit)
				d = Vector2.new(dir.X, dir.Y)
			end
			if d.Magnitude > 1 then d = d.Unit end
			local k = e.face == "Pupil" and 0.2 or 0.07
			cf = pcf * CFrame.new(d.X * e.parent.Size.X * k, d.Y * e.parent.Size.Y * k, 0) * e.rel
			setT(p, closed > 0.55 and 1 or e.t0)
		elseif e.face == "Mouth" then -- grows from a little line into an open "o"
			local m = r.mouthNow
			if m < 0.05 then
				setT(p, 1)
			else
				setT(p, e.t0)
				setSize(p, e.size * Vector3.new(0.55 + 0.45 * m, math.max(0.06, m), 1))
			end
		end
		p.CFrame = cf
	end
end

---------------------------------------------------------------- critters with parts
-- Whole-body moves come from the one-piece animation (hops, waddles, spins, turning to you); on top of
-- that the head looks around, ears twitch, the tail wags, wings flap, feet step, and the face reacts.
local CRITTER_LIMBS = {Head = true, EarL = true, EarR = true, Leaf = true, Crest = true, Tail = true, WingL = true, WingR = true,
	LegsF = true, LegsB = true, FootL = true, FootR = true, Feet = true}
local function animateCritter(r, now, dt)
	animateBlob(r, now, dt)
	local root = r.vbody.CFrame
	local L = r.limbs
	local u, t = r.u, now + r.seed
	local m = r.model
	local moving, napping = m:GetAttribute("Moving"), m:GetAttribute("Napping")
	local sad = m:GetAttribute("Mood") == "Sad"
	local act = r.action
	local happy = act == "Happy" or act == "Wiggle" or act == "Spin" or act == "Twirl" or (r.petAt and now - r.petAt < 2.5)
		or (r.workAt and now - r.workAt < 1) or (r.trick ~= nil)
	-- head: slow look-around, sniffing nods, curious tilts, happy bobs, droops when sad or asleep
	local hy = math.noise(t * 0.3, r.seed) * 0.35
	local hp = math.sin(t * 1.1) * 0.04
	local hr = math.noise(t * 0.25, r.seed + 3) * 0.12
	if act == "Sniff" then hp -= 0.22 + math.sin(t * 14) * 0.06 end
	if act == "Look" then hr += math.sin((now - r.actionStart) * 2) * 0.25 end
	if happy then hr += math.sin(t * 8) * 0.12 hp += 0.08 end
	if sad then hp -= 0.18 end
	if moving then hp += math.sin(t * 16) * 0.05 hy *= 0.3 end
	if napping then hp, hy, hr = -0.3, 0.2, -0.2 end
	local head = CFrame.Angles(0, hy, 0) * CFrame.Angles(hp, 0, hr)
	place(r, root, "Head", head)
	local headRoot = L.Head and root * jointRel(r, "Head", head) or root
	-- ears (and head leaves / crests) ride on the head
	if now > (r.nextTwitch or 0) then
		r.nextTwitch = now + 1.2 + math.random() * 4
		r.twitchAt, r.twitchSide = now, math.random() < 0.5 and 1 or -1
	end
	for _, name in {"EarL", "EarR"} do
		local E = L[name]
		if E then
			local side = E.rest.Position.X < 0 and -1 or 1
			local k = r.twitchAt and now - r.twitchAt or 9
			local tw = (k < 0.4 and side == r.twitchSide) and math.sin(k / 0.4 * math.pi * 2) * 0.3 or 0
			local out = (sad and 0.45 or 0) + (napping and 0.55 or 0) - (happy and 0.12 or 0) + (moving and math.sin(t * 16) * 0.12 or 0)
			place(r, headRoot, name, CFrame.Angles((happy and -0.2 or 0) + math.sin(t * 2 + side) * 0.05, 0, side * (-out - tw)))
		end
	end
	for _, name in {"Leaf", "Crest"} do
		if L[name] then
			place(r, headRoot, name, CFrame.Angles(math.sin(t * 2.3) * 0.12, 0, math.sin(t * 1.7) * 0.15 + (happy and math.sin(t * 12) * 0.2 or 0)))
		end
	end
	-- tail: lazy sway, fast happy wag, low when sad
	local wag = (happy and 0.6 or (moving and 0.35 or 0.22)) * (napping and 0.2 or 1)
	local speed = happy and 14 or (moving and 9 or 3)
	place(r, root, "Tail", CFrame.Angles(math.sin(t * speed * 0.5) * 0.08 + (sad and -0.25 or 0), math.sin(t * speed) * wag, 0))
	-- wings: flap to fly or when happy, a slow flutter at rest
	local flying = r.style == "float" or moving
	local amp = flying and 0.55 or (happy and 0.5 or 0.08)
	local flap = math.sin(t * (flying and 14 or (happy and 16 or 2))) * amp
	for _, name in {"WingL", "WingR"} do
		local W = L[name]
		if W then
			local side = W.rest.Position.X < 0 and -1 or 1
			place(r, root, name, CFrame.Angles(0, 0, side * (flap + 0.1)))
		end
	end
	-- legs / feet step while walking
	local step = (r.walk or 0) * 1.6
	for name, ph in {LegsF = 0, LegsB = math.pi, FootL = 0, FootR = math.pi} do
		if L[name] then
			local s = moving and math.sin(step + ph) or 0
			place(r, root, name, CFrame.Angles(s * 0.45, 0, 0), Vector3.new(0, math.max(0, s) * 0.05 * u, 0))
		end
	end
	-- one-piece feet: rock side to side while walking
	if L.Feet then
		place(r, root, "Feet", CFrame.Angles(0, 0, moving and math.sin(step) * 0.18 or 0), Vector3.new(0, moving and math.abs(math.sin(step)) * 0.03 * u or 0, 0))
	end
	-- any other part just follows (the head if it is marked OnHead, else the body), so nothing is left behind
	for name, P in L do
		if not CRITTER_LIMBS[name] then place(r, P.part:GetAttribute("OnHead") and headRoot or root, name) end
	end
	-- face: shut when asleep, happy squint, little "o" mouth when happy / sniffing / stretching
	r.eyesGoal = napping and 0 or (happy and 0.35 or (sad and 0.7 or 1))
	r.mouthGoal = happy and 1 or (act == "Sniff" and 0.35) or (act == "Stretch" and 0.8) or (act == "Flex" and 0.9) or 0
end

---------------------------------------------------------------- loop
local ANIMATE = {Cat = animateCat, Dragon = animateDragon, Blob = animateBlob, Critter = animateCritter}

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for model, r in rigs do
		if not model.Parent or not r.body.Parent then
			cleanup(model)
		else
			local fn = ANIMATE[r.kind]
			if model:GetAttribute("RiderId") == player.UserId then -- 🐎 my ride: keep it right under me (no lag)
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hrp and hum then
					r.extY = r.extY or model:GetExtentsSize().Y
					local feetY = hrp.Position.Y - hum.HipHeight - hrp.Size.Y / 2
					local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
					local p = Vector3.new(hrp.Position.X, feetY - r.extY * 0.3, hrp.Position.Z)
					if look.Magnitude > 0.1 then model:PivotTo(CFrame.lookAt(p, p + look)) end
				end
			end
			local ok, err = pcall(function()
				if fn then
					local tcf = trickCF(r, now)
					r.trickCF = tcf
					if tcf and r.kind ~= "Blob" then
						-- rigs pose around the body; turn the pivot-space trick into body space
						local pivot = r.model:GetPivot()
						fn(r, now, dt, pivot * tcf * pivot:ToObjectSpace(r.body.CFrame))
					else
						fn(r, now, dt, r.body.CFrame)
					end
					updateFace(r, now, dt)
					updateExtras(r, now)
				else
					r.v:PivotTo(r.model:GetPivot())
				end
			end)
			if not ok then
				warn("CritterAnimator:", err)
				r.kind = nil -- fall back to a still model
			end
		end
	end
end)

for _, tag in {"RiggedCritter", "BlobCritter"} do
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(m) task.spawn(setup, m) end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(cleanup)
	for _, m in CollectionService:GetTagged(tag) do task.spawn(setup, m) end
end
