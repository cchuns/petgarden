-- Critter Acres: BossSkills (ServerScriptService)
-- 👑 Land bosses (Queen Buzzbloom, Bramble Bear, Ice Wyrm, Gem Golem, Lava Titan) use special attacks between bonks.
-- Every special is telegraphed first so kids can dodge:
--   ☄️ Rain   : red circles on the ground (one under each player + more around), then things fall from the sky
--   💫 Slam   : the boss crouches and jumps; a red circle around it shows where it lands. Some stun (dizzy / frozen / sticky)
--   🔥 Volley : red lanes show where glowing balls will fly, then the boss throws them (one by one, or a fan)
--   🐻 Line   : a red lane in front of the boss: Charge (it runs through the lane) or Breath (a long blast down the lane)
-- The skill list and all numbers are in ReplicatedStorage.CritterData (Data.BossSkill, Data.BossSkills).
-- Combat (ServerScriptService.Combat) calls API.bossThink(mob, now, player, hrp, dist) for bosses that are after someone;
--   returning true means "busy with a special, don't chase or bonk this tick".
-- Messages to clients go through the Combat remote: BossCast, BossZone, BossShot, BossShotEnd, Stun.
--   StarterPlayerScripts.BossFx draws them; MobAnimator plays the pose from the attributes Skill / SkillDur / SkillHit /
--   SkillGap / SkillShots / SkillDir / SkillN (bumped each cast).
local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
while not API.combatHurt do task.wait(0.2) end
local Data = API.Data
local CFG = Data.BossSkill
local SKILLS = Data.BossSkills

local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function hrpOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = {workspace.Terrain}
local function ground(p)
	local hit = workspace:Raycast(Vector3.new(p.X, p.Y + 60, p.Z), Vector3.new(0, -300, 0), groundParams)
	return hit and hit.Position.Y or p.Y
end

local hitAt = {} -- player -> last time a special hit them (overlapping meteors only hit once)
local shotId = 0

-- players in the boss's map that are close enough to be part of the fight
local function fighters(mob)
	local list = {}
	for p in mob.run.inside do
		local hrp = hrpOf(p)
		if hrp and (p:GetAttribute("HP") or 1) > 0 and (flat(hrp.Position) - flat(mob.pos)).Magnitude < CFG.Range then
			table.insert(list, {p = p, hrp = hrp})
		end
	end
	return list
end

-- a special hits this player: lose the boss's ATT x sk.Hurt (bumped away from `from`), maybe a stun
local function zap(mob, p, from, sk)
	local now = os.clock()
	if now - (hitAt[p] or 0) < CFG.HitGap then return end
	local ok = API.combatHurt(p, (mob.atk or 10) * (sk.Hurt or 1), {pos = from, boss = true, m = mob.m})
	if not ok then return end
	hitAt[p] = now
	if sk.Stun and (p:GetAttribute("HP") or 0) > 0 then
		API.combatSend(p, {Kind = "Stun", Secs = CFG.StunSecs, Look = sk.Stun})
	end
end

local function hitCircle(mob, center, r, sk)
	for p in mob.run.inside do
		local hrp = hrpOf(p)
		if hrp and (flat(hrp.Position) - flat(center)).Magnitude <= r + 1 then zap(mob, p, center, sk) end
	end
end

-- is the point inside the lane from `a` going `dir` for `len` studs, `w` wide?
local function inLane(pos, a, dir, len, w)
	local rel = flat(pos) - flat(a)
	local along = rel:Dot(dir)
	if along < -1 or along > len + 1 then return false end
	return (rel - dir * along).Magnitude <= w / 2 + 1
end

local function alive(mob) return mob.state ~= "dead" and mob.m.Parent ~= nil end

---------------------------------------------------------------- the specials
local CAST = {}

-- ☄️ things fall on red circles
function CAST.Rain(mob, sk, list)
	local spots = {}
	for _, f in list do table.insert(spots, flat(f.hrp.Position)) end
	local tries = 0
	while #spots < sk.N and tries < 60 do
		tries += 1
		local base = #list > 0 and flat(list[math.random(#list)].hrp.Position) or flat(mob.pos)
		local a, d = math.random() * math.pi * 2, 5 + math.random() * 13
		local s = base + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local okSpot = true
		for _, o in spots do
			if (o - s).Magnitude < sk.R * 1.3 then okSpot = false break end
		end
		if okSpot then table.insert(spots, s) end
	end
	local last = 0
	for i, s in spots do
		local pos = Vector3.new(s.X, ground(s + Vector3.new(0, mob.pos.Y, 0)), s.Z)
		local warn = sk.Warn + (i - 1) * 0.18
		last = math.max(last, warn)
		API.combatSendRun(mob.run, {Kind = "BossZone", Model = mob.m, Shape = "Circle", Pos = pos, R = sk.R, Warn = warn, Fall = sk.Look})
		task.delay(warn, function()
			if alive(mob) then hitCircle(mob, pos, sk.R, sk) end
		end)
	end
	return last + 0.5, sk.Warn
end

-- 💫 jump and land: a big circle around the boss
function CAST.Slam(mob, sk)
	local r = mob.radius + sk.R
	local pos = Vector3.new(mob.pos.X, ground(mob.pos), mob.pos.Z)
	API.combatSendRun(mob.run, {Kind = "BossZone", Model = mob.m, Shape = "Circle", Pos = pos, R = r, Warn = sk.Warn, Slam = sk.Look})
	task.delay(sk.Warn, function()
		if alive(mob) then hitCircle(mob, pos, r, sk) end
	end)
	return sk.Warn + 0.9, sk.Warn
end

-- 🔥 glowing balls fly down red lanes
local function fireShot(mob, sk, from, dir, aim)
	shotId += 1
	local id = shotId
	local range = sk.Range or 60
	API.combatSendRun(mob.run, {Kind = "BossShot", Model = mob.m, Id = id, From = from, Dir = dir, Speed = sk.Speed, Range = range, R = sk.R, Aim = aim, Look = sk.Look})
	task.delay(aim, function()
		if not alive(mob) then return end
		local t0 = os.clock()
		local hit = {}
		while true do
			local k = os.clock() - t0
			local dist = k * sk.Speed
			if dist > range or not mob.run.folder or not mob.run.folder.Parent then break end
			local pos = from + dir * dist
			local stop = false
			for p in mob.run.inside do
				local hrp = hrpOf(p)
				if hrp and not hit[p] and (flat(hrp.Position) - flat(pos)).Magnitude <= sk.R + 1.2 then
					hit[p] = true
					zap(mob, p, pos - dir * 3, sk)
					stop = true
				end
			end
			if stop then
				API.combatSendRun(mob.run, {Kind = "BossShotEnd", Id = id, Pos = pos})
				break
			end
			task.wait(0.05)
		end
	end)
end

function CAST.Volley(mob, sk, list, target)
	local aim = sk.Aim or 0.9
	local function startFor(hrp, dir)
		local y = hrp and hrp.Position.Y or (mob.pos.Y + 2)
		local s = flat(mob.pos) + dir * (mob.radius + 1)
		return Vector3.new(s.X, y, s.Z)
	end
	if sk.Fan then
		-- all at once in a fan aimed at the target
		local thr = target.hrp
		local base = flat(thr.Position - mob.pos)
		base = base.Magnitude > 0.1 and base.Unit or Vector3.new(0, 0, -1)
		for i = 1, sk.N do
			local a = math.rad(-sk.Fan / 2 + sk.Fan * (i - 1) / math.max(1, sk.N - 1))
			local dir = flat(CFrame.Angles(0, a, 0):VectorToWorldSpace(base)).Unit
			fireShot(mob, sk, startFor(thr, dir), dir, aim)
		end
		mob.m:SetAttribute("SkillDir", base)
		return aim + 0.9, aim, 0, 1
	end
	-- one by one, each aimed at a random fighter (where they are when the lane appears)
	local gap = sk.Gap or 0.5
	for i = 1, sk.N do
		task.delay((i - 1) * gap, function()
			if not alive(mob) then return end
			local now = fighters(mob)
			local f = (#now > 0) and now[math.random(#now)] or target
			if not f.hrp.Parent then return end
			local dir = flat(f.hrp.Position - mob.pos)
			dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, -1)
			fireShot(mob, sk, startFor(f.hrp, dir), dir, aim)
		end)
	end
	return aim + (sk.N - 1) * gap + 0.6, aim, gap, sk.N
end

-- 🐻 / ❄️ a red lane in front: Charge runs through it, Breath blasts down it
function CAST.Line(mob, sk, list, target)
	local dir = flat(target.hrp.Position - mob.pos)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, -1)
	local a = flat(mob.pos) + Vector3.new(0, ground(mob.pos), 0)
	mob.m:SetAttribute("SkillDir", dir)
	API.combatSendRun(mob.run, {Kind = "BossZone", Model = mob.m, Shape = "Lane", Pos = a, Dir = dir, L = sk.L, W = sk.W, Warn = sk.Warn,
		Breath = sk.Mode == "Breath" and sk.Look or nil, Hold = sk.Hold})
	if sk.Mode == "Charge" then
		local dashT = 0.6
		task.delay(sk.Warn, function()
			if not alive(mob) then return end
			local stopAt = math.max(0, sk.L - mob.radius)
			local goal = a + dir * stopAt
			API.combatSetGoal(mob, Vector3.new(goal.X, mob.home.Y, goal.Z), stopAt / dashT)
			local t0 = os.clock()
			while os.clock() - t0 < dashT + 0.2 do
				for p in mob.run.inside do
					local hrp = hrpOf(p)
					if hrp and (flat(hrp.Position) - flat(mob.pos)).Magnitude <= mob.radius + sk.W / 2 then zap(mob, p, mob.pos, sk) end
				end
				task.wait(0.05)
			end
			if alive(mob) then API.combatSetGoal(mob, mob.pos, mob.speed) end
		end)
		return sk.Warn + dashT + 0.7, sk.Warn
	end
	-- Breath
	task.delay(sk.Warn, function()
		local t0 = os.clock()
		while alive(mob) and os.clock() - t0 < (sk.Hold or 1) do
			for p in mob.run.inside do
				local hrp = hrpOf(p)
				if hrp and inLane(hrp.Position, a, dir, sk.L, sk.W) then zap(mob, p, a, sk) end
			end
			task.wait(0.1)
		end
	end)
	return sk.Warn + (sk.Hold or 1) + 0.4, sk.Warn
end

---------------------------------------------------------------- picking a special
local ANIM = {Rain = "Summon", Slam = "Slam", Volley = "Throw"}

local function pick(mob, list, dist)
	local all = SKILLS[mob.kind]
	if not all then return nil end
	local choices = {}
	for i, sk in all do
		local fine = i ~= mob.lastSkill
		if sk.Type == "Slam" and dist > mob.radius + sk.R * 1.2 then fine = false end -- nobody close: no point jumping
		if sk.Type == "Line" and dist > sk.L + 4 then fine = false end
		if fine then table.insert(choices, i) end
	end
	if #choices == 0 then return nil end
	local i = choices[math.random(#choices)]
	mob.lastSkill = i
	return all[i]
end

local function cast(mob, sk, target, now)
	local list = fighters(mob)
	if #list == 0 then return end
	local m = mob.m
	m:SetAttribute("SkillDir", nil)
	API.combatSetGoal(mob, mob.pos, mob.speed) -- stand still and do it
	local busy, hit, gap, shots = CAST[sk.Type](mob, sk, list, target)
	mob.casting = now + busy
	mob.atkAt = math.max(mob.atkAt or 0, now + busy + 0.8)
	m:SetAttribute("Skill", sk.Type == "Line" and sk.Mode or ANIM[sk.Type])
	m:SetAttribute("SkillDur", busy)
	m:SetAttribute("SkillHit", hit or busy * 0.5)
	m:SetAttribute("SkillGap", gap or 0)
	m:SetAttribute("SkillShots", shots or 1)
	m:SetAttribute("SkillN", (m:GetAttribute("SkillN") or 0) + 1)
	API.combatSendRun(mob.run, {Kind = "BossCast", Model = m, Name = sk.Name, Icon = sk.Icon, Type = sk.Type, Mode = sk.Mode})
end

-- called by Combat 5 times a second for a boss that is after `player`
API.bossThink = function(mob, now, player, hrp, dist)
	if not SKILLS[mob.kind] then return false end
	if mob.casting and now < mob.casting then return true end
	mob.casting = nil
	if not mob.skillAt then
		mob.skillAt = now + CFG.First
		return false
	end
	if now < mob.skillAt or dist > CFG.Range then return false end
	local sk = pick(mob, nil, dist)
	if not sk then return false end
	mob.skillAt = now + CFG.Gap[1] + math.random() * (CFG.Gap[2] - CFG.Gap[1])
	local ok, err = pcall(cast, mob, sk, {p = player, hrp = hrp}, now)
	if not ok then
		warn("[BossSkills]", mob.kind, sk.Name, err)
		mob.casting = nil
		return false
	end
	mob.skillAt += mob.casting and (mob.casting - now) or 0
	return mob.casting ~= nil
end

game:GetService("Players").PlayerRemoving:Connect(function(p) hitAt[p] = nil end)
