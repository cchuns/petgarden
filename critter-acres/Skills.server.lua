-- Critter Acres: Skills (ServerScriptService)
-- 🌳 The skill tree (Data.SkillBranches / Data.Skills). 1 skill point per ⚔️ Hero Level (Combat keeps HeroLv).
--   prof.Skills = {[skillId] = level}. A skill needs HeroLv >= Lv and its Req skill learned; each point learns or
--   levels up one skill (to Max). Free reset. Player attribute SkillPts = points left (for the 🌳 dock badge).
-- Passives are read by Combat through API.skillRank / API.skillBuff (damage, HP, guard, crit, reach, double shot,
--   bounce, heal, spin). Quick Feet sets walk speed while you're in a wild land.
-- ⚡ Actives (Kind = "Active") go in skill bars, ONE BAR PER BRANCH: prof.SkillBars = {Melee = {id or "" x5}, Range = ..., Mage = ...}.
--   Only that branch's moves fit in its bar, and the bar you use is the one of the weapon in your hand
--   (sword = Melee moves only). Learning a new move puts it in the first empty slot of its bar; players move it with the
--   slot number buttons in the tree window. Player attributes SkillBar_Melee / SkillBar_Range / SkillBar_Mage = "id,id,,,".
--   The client fires the Combat remote ("Skill", slot 1-5, aimPos). Cooldowns are per skill: attribute "Cd_<id>".
--   Everyone in the map sees the move (SkillFx message, drawn by StarterPlayerScripts.SkillTree).
-- Actions (CritterAction): SkillInfo, SkillLearn(id), SkillReset, SkillSlot(id, slot) (slot 0 = take it out of the bar).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
while not API.combatDamage do task.wait(0.2) end
local Data, ACTIONS = API.Data, API.ACTIONS
local remote = ReplicatedStorage:WaitForChild("Combat")

local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function hrpOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

---------------------------------------------------------------- points
local function skillsOf(prof)
	prof.Skills = prof.Skills or {}
	return prof.Skills
end
local function spent(prof)
	local n = 0
	for id, r in skillsOf(prof) do
		if Data.Skills[id] then n += r end
	end
	return n
end
local function heroLv(prof) return math.clamp(prof.HeroLv or 1, 1, Data.HeroMax) end
local function pointsLeft(prof) return math.max(0, heroLv(prof) - spent(prof)) end

local function rank(player, id)
	local prof = API.profiles[player]
	local s = prof and prof.Skills
	return s and s[id] or 0
end
API.skillRank = rank

-- why can't this skill go up one level? (nil = it can)
local function blocked(prof, id)
	local s = Data.Skills[id]
	if not s then return "❔" end
	local r = skillsOf(prof)[id] or 0
	if r >= s.Max then return ("⭐ %s is maxed!"):format(s.Name) end
	if heroLv(prof) < s.Lv then return ("🔒 %s opens at ⚔️ Hero Lv %d."):format(s.Name, s.Lv) end
	if s.Req and (skillsOf(prof)[s.Req] or 0) < 1 then return ("🔒 Learn %s first."):format(Data.Skills[s.Req].Name) end
	if pointsLeft(prof) <= 0 then return "🌳 No skill points left. Beat mobs to level up!" end
	return nil
end

---------------------------------------------------------------- ⚡ the skill bars (one per branch)
local function isActive(id) return Data.Skills[id] ~= nil and Data.Skills[id].Kind == "Active" end
local function barsOf(prof)
	local bars = prof.SkillBars
	if type(bars) ~= "table" then bars = {} prof.SkillBars = bars end
	prof.SkillBar = nil -- (the old single bar)
	for _, br in Data.SkillBranches do
		local bar = bars[br.Name]
		if type(bar) ~= "table" then
			-- first time: the moves of this branch you already know, in tree order
			bar = {}
			for i = 1, Data.SkillSlots do bar[i] = "" end
			local n = 0
			for _, id in br.Order do
				if isActive(id) and (skillsOf(prof)[id] or 0) > 0 and n < Data.SkillSlots then
					n += 1
					bar[n] = id
				end
			end
			bars[br.Name] = bar
		end
		for i = 1, Data.SkillSlots do
			local id = bar[i]
			if type(id) ~= "string" or (id ~= "" and (not isActive(id) or Data.Skills[id].Branch ~= br.Name or (skillsOf(prof)[id] or 0) <= 0)) then bar[i] = "" end
		end
	end
	return bars
end
local function barText(prof, branch) return table.concat(barsOf(prof)[branch], ",", 1, Data.SkillSlots) end

---------------------------------------------------------------- buffs (Giant Mode, Rapid Fire)
local buffs = {} -- player -> {Giant = {endAt, boost}, Rapid = {endAt, speed}}
local function buff(player, name)
	local b = buffs[player] and buffs[player][name]
	if b and os.clock() < b.endAt then return b end
	return nil
end
API.skillBuff = buff

---------------------------------------------------------------- 👟 walk speed in the lands (Quick Feet)
local BASE_SPEED = 16
local sped = {} -- player -> true while we changed their speed
local function applySpeed(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.SeatPart then return end
	local r = rank(player, "QuickFeet")
	local gs = API.heroGearStats and API.heroGearStats(player) -- 👟 Hero Gear boots
	local mult = (1 + Data.Skills.QuickFeet.Per * r) * (1 + (gs and gs.Spd or 0))
	if player:GetAttribute("Realm") and mult > 1.001 then
		hum.WalkSpeed = BASE_SPEED * mult
		sped[player] = true
	elseif sped[player] then
		hum.WalkSpeed = BASE_SPEED
		sped[player] = nil
	end
end

local function push(player)
	local prof = API.profiles[player]
	if not prof then return end
	player:SetAttribute("SkillPts", pointsLeft(prof))
	for _, br in Data.SkillBranches do player:SetAttribute("SkillBar_" .. br.Name, barText(prof, br.Name)) end
	player:SetAttribute("ReachMul", 1 + Data.Skills.LongReach.Per * rank(player, "LongReach")) -- (client aims a bit further)
	pcall(applySpeed, player)
	if API.combatRefreshPwr then pcall(API.combatRefreshPwr, player) end
end
API.skillPush = push

---------------------------------------------------------------- actions
local function info(player, prof)
	return {Skills = table.clone(skillsOf(prof)), Lv = heroLv(prof), Points = pointsLeft(prof), Max = Data.HeroMax, Bars = table.clone(barsOf(prof))}
end
function ACTIONS.SkillInfo(player, prof)
	return info(player, prof)
end
function ACTIONS.SkillLearn(player, prof, id)
	if type(id) ~= "string" then return "❔" end
	local why = blocked(prof, id)
	if why then return why end
	local s = skillsOf(prof)
	s[id] = (s[id] or 0) + 1
	if s[id] == 1 and isActive(id) then -- a new move goes in the first empty slot of its branch's bar
		local bar = barsOf(prof)[Data.Skills[id].Branch]
		for i = 1, Data.SkillSlots do
			if bar[i] == "" then bar[i] = id break end
		end
	end
	push(player)
	return info(player, prof)
end
function ACTIONS.SkillReset(player, prof)
	prof.Skills = {}
	prof.SkillBars = nil
	push(player)
	return info(player, prof)
end
-- put a move in slot 1-5 of its branch's bar (0 = take it out). If another move was there, they swap places.
function ACTIONS.SkillSlot(player, prof, id, slot)
	slot = tonumber(slot)
	if type(id) ~= "string" or not slot or slot < 0 or slot > Data.SkillSlots or slot % 1 ~= 0 then return "❔" end
	if not isActive(id) then return "⚡ Only ⚡ moves go in the bar." end
	if (skillsOf(prof)[id] or 0) <= 0 then return ("🔒 Learn %s first."):format(Data.Skills[id].Name) end
	local bar = barsOf(prof)[Data.Skills[id].Branch]
	local was = table.find(bar, id)
	if slot == 0 then
		if was then bar[was] = "" end
	else
		if was then bar[was] = bar[slot] end
		bar[slot] = id
	end
	push(player)
	return info(player, prof)
end

---------------------------------------------------------------- ⚡ using a move (keys 1-5)
local cdUntil = {} -- player -> {[skillId] = os.clock() it is ready}
local function cast(player, slot, aim)
	local run = API.runOf and API.runOf[player]
	local hrp = hrpOf(player)
	local prof = API.profiles[player]
	if not run or not hrp or not prof or (player:GetAttribute("HP") or 1) <= 0 then return end
	slot = tonumber(slot)
	if not slot or slot < 1 or slot > Data.SkillSlots then return end
	-- the bar of the weapon in your hand: a sword only does 🗡️ Melee moves
	local def = API.combatWeapon(player)
	local branch = Data.BranchOfStyle(def and def.Style or "Melee")
	local id = barsOf(prof)[branch][math.floor(slot)]
	local s = Data.Skills[id or ""]
	if not s then
		API.toast(player, ("⚡ Slot %d of your %s bar is empty. Put a move in it in the 🌳 skill tree (K)."):format(slot, branch))
		return
	end
	local r = rank(player, id)
	if r <= 0 then return end
	cdUntil[player] = cdUntil[player] or {}
	local now = os.clock()
	if now < (cdUntil[player][id] or 0) then return end
	cdUntil[player][id] = now + s.Cd
	player:SetAttribute("Cd_" .. id, workspace:GetServerTimeNow() + s.Cd)
	local power = API.attackPower(player)
	local me = flat(hrp.Position) + Vector3.new(0, hrp.Position.Y - 3, 0)
	local fx = {Kind = "SkillFx", Skill = id, By = player.UserId, Rank = r}
	if id == "GroundPound" then
		fx.Pos, fx.R = me, s.R
		API.combatSendRun(run, fx)
		task.delay(0.45, function()
			for _, e in API.combatMobsNear(run, hrp.Position, s.R) do
				API.combatDamage(e[1], math.floor(power * s.Dmg(r) + 0.5), player, false)
				API.combatStun(e[1], s.Stun(r), "Dizzy")
			end
		end)
	elseif id == "ArrowRain" or id == "MiniMeteor" then
		-- lands on a circle where you aim (not too far)
		local spot = typeof(aim) == "Vector3" and aim or (hrp.Position + hrp.CFrame.LookVector * 14)
		local off = flat(spot - hrp.Position)
		if off.Magnitude > Data.SkillAim then off = off.Unit * Data.SkillAim end
		local pos = hrp.Position + off
		pos = Vector3.new(pos.X, (typeof(aim) == "Vector3" and aim.Y or hrp.Position.Y - 3), pos.Z)
		-- 🧱 dungeon walls: an aimed skill can't land on the other side of a wall (pull it back toward you)
		if run.blocked then
			local p0 = hrp.Position
			for _ = 1, 10 do
				if not run.blocked(p0, pos) then break end
				pos = Vector3.new(p0.X + (pos.X - p0.X) * 0.7, pos.Y, p0.Z + (pos.Z - p0.Z) * 0.7)
			end
		end
		local delay = id == "MiniMeteor" and 0.9 or 0.7
		fx.Pos, fx.R, fx.Delay = pos, s.R, delay
		API.combatSendRun(run, fx)
		task.delay(delay, function()
			for _, e in API.combatMobsNear(run, pos, s.R) do
				API.combatDamage(e[1], math.floor(power * s.Dmg(r) + 0.5), player, false)
			end
		end)
	elseif id == "FreezeRing" then
		fx.Pos, fx.R, fx.Secs = me, s.R, s.Stun(r)
		API.combatSendRun(run, fx)
		for _, e in API.combatMobsNear(run, hrp.Position, s.R) do
			API.combatDamage(e[1], math.floor(power + 0.5), player, false)
			API.combatStun(e[1], s.Stun(r), "Ice")
		end
	elseif id == "GiantMode" then
		local secs = s.Secs(r)
		buffs[player] = buffs[player] or {}
		buffs[player].Giant = {endAt = now + secs, boost = s.Boost(r)}
		fx.Secs = secs
		API.combatSendRun(run, fx)
		local char = player.Character
		if char then pcall(char.ScaleTo, char, 1.5) end
		task.delay(secs, function()
			local c = player.Character
			if c and c == char then pcall(c.ScaleTo, c, 1) end
		end)
	elseif id == "RapidFire" then
		local secs = s.Secs(r)
		buffs[player] = buffs[player] or {}
		buffs[player].Rapid = {endAt = now + secs, speed = s.Speed(r)}
		player:SetAttribute("AtkSpeed", s.Speed(r))
		fx.Secs = secs
		API.combatSendRun(run, fx)
		task.delay(secs, function()
			if not buff(player, "Rapid") then player:SetAttribute("AtkSpeed", nil) end
		end)
	end
end

remote.OnServerEvent:Connect(function(player, kind, slot, aim)
	if kind ~= "Skill" or type(slot) ~= "number" then return end
	local ok, err = pcall(cast, player, slot, aim)
	if not ok then warn("[Skills]", err) end
end)

---------------------------------------------------------------- Studio dev menu
API.DEV_EXTRA = API.DEV_EXTRA or {}
API.DEV_EXTRA.SkillCd = function(player)
	cdUntil[player] = nil
	for id in Data.Skills do player:SetAttribute("Cd_" .. id, nil) end
	return "⚡ All moves ready"
end
API.DEV_EXTRA.SkillsMax = function(player, prof) -- Hero Lv 50 and every skill maxed
	prof.HeroLv = Data.HeroMax
	player:SetAttribute("HeroLv", prof.HeroLv)
	local s = skillsOf(prof)
	for id, def in Data.Skills do s[id] = def.Max end
	prof.SkillBars = nil -- refill the bars with the moves
	push(player)
	return "🌳 Every skill maxed (Hero Lv 50)"
end

---------------------------------------------------------------- players
local function onPlayer(player)
	task.spawn(function()
		for _ = 1, 120 do
			if API.profiles[player] then break end
			task.wait(0.5)
		end
		if not API.profiles[player] then return end
		push(player)
		player:GetAttributeChangedSignal("HeroLv"):Connect(function() push(player) end)
		player:GetAttributeChangedSignal("Realm"):Connect(function()
			pcall(applySpeed, player)
			-- leaving a land ends Giant Mode / Rapid Fire
			if not player:GetAttribute("Realm") and buffs[player] then
				buffs[player] = nil
				player:SetAttribute("AtkSpeed", nil)
				local c = player.Character
				if c then pcall(c.ScaleTo, c, 1) end
			end
		end)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			pcall(applySpeed, player)
		end)
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end
Players.PlayerRemoving:Connect(function(p) buffs[p], cdUntil[p], sped[p] = nil, nil, nil end)
