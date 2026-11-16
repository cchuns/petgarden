-- Critter Acres: Combat (ServerScriptService)
-- ⚔️ Battling in the wild lands (the maps behind the 🌀 Terrain Portal, built by Realms):
--   * Mob brains live here: they wander, travel in herds, NOTICE you (they turn angry: ❗ + red glow on screen),
--     chase you, wind up (a big tell you can dodge) and bonk. They give up and go home if you run far away.
--   * You have ❤️ hearts (Data.Hearts). A bonk takes 1 (bosses 2). Hearts come back when you rest a moment.
--     At 0 you faint with a cute poof and wake at the map's portal with full hearts. Nothing is ever lost.
--   * Your weapon is a Tool. Magic weapons shoot sparkly bolts, Melee weapons bonk up close (stronger).
--     Everyone starts with a free 🪄 Twig Wand. More come from 🎁 capsules: buy the Basic one for coins,
--     land capsules drop from mobs, bosses and chests. Rarity is random (Common .. Mythic), 5% are ✨ shiny,
--     copies you already have add a ⭐ (max 5).
--   * Your buddy pet (picked at the portal) zaps mobs. 🛡️ Passive (default): only mobs after you or the one you
--     just hit. ⚔️ Aggressive: any mob near you too. Toggle in the land (chip above the hearts, or the V key).
--   * Defeated mobs give coins + farm XP right away. Items (resources, sometimes a capsule or an egg; eggs are the
--     only way to get new pets) drop as glowing ⭐ stars: a surprise until you walk over one. Your buddy grabs
--     stars too, one every Data.PetCollect.Secs[prof.PetCollectLv] seconds. Mobs come back after a while.
-- Mob models: tag MobRig, attributes HP/MaxHP, Angry, TargetId, Goal (where it walks to), Spd (studs/s),
--   Act (+1 = do the attack move now), Dead. MobAnimator (client) moves and animates them from these.
-- Client: StarterPlayerScripts.Combat (tool clicks, hearts, glow, numbers, weapons menu). Remote: ReplicatedStorage.Combat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local Data, ACTIONS = API.Data, API.ACTIONS

local remote = ReplicatedStorage:FindFirstChild("Combat")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "Combat"
	remote.Parent = ReplicatedStorage
end
local WEAPONS = ReplicatedStorage:WaitForChild("WeaponModels", 30)

-- how fast each kind moves (x its height per second) and how long its attack move lasts (matches MobAnimator)
local MOVE = {
	Puffbloom = {0.9, 1.8}, Bumblebun = {1.6, 1.4}, Potsnail = {0.35, 3.2}, QueenBuzzbloom = {0.35, 2.8},
	Mushling = {0.8, 2.0}, AcornKnight = {1.0, 1.6}, Twiggle = {0.9, 2.6}, BrambleBear = {0.3, 2.6},
	Snowpuff = {1.0, 1.8}, Pengling = {0.8, 2.2}, GaleSprite = {1.3, 1.8}, IceWyrm = {0.3, 3.0},
	GemshellCrab = {1.0, 1.4}, Glowbat = {1.8, 1.4}, Rockroll = {1.1, 2.0}, GemGolem = {0.28, 2.6},
	Cinderpup = {1.4, 1.6}, Emberbeetle = {0.7, 1.8}, Smoglet = {0.9, 2.2}, LavaTitan = {0.28, 2.6},
}
-- resources each land gives
local RES_OF = {}
for _, def in Data.Nodes do
	if def.Biome then
		RES_OF[def.Biome] = RES_OF[def.Biome] or {}
		if not table.find(RES_OF[def.Biome], def.Res) then table.insert(RES_OF[def.Biome], def.Res) end
	end
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function hrpOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end
local function send(player, msg) if player.Parent then remote:FireClient(player, msg) end end
local function sendRun(run, msg)
	for p in run.inside do send(p, msg) end
end

---------------------------------------------------------------- weapons in your profile
-- prof.Weapons = {{Id, Name, Stars, Shiny}}, prof.WeaponOn = Id, prof.Capsules = {[kind] = n}
local function ensure(prof)
	if not prof.Weapons then
		prof.Weapons = {}
		prof.NextWeaponId = 1
	end
	prof.NextWeaponId = prof.NextWeaponId or (#prof.Weapons + 1)
	prof.Capsules = prof.Capsules or {}
	if #prof.Weapons == 0 then
		table.insert(prof.Weapons, {Id = prof.NextWeaponId, Name = Data.StarterWeapon, Stars = 0})
		prof.WeaponOn = prof.NextWeaponId
		prof.NextWeaponId += 1
	end
end
local function weaponEntry(prof, id)
	for _, w in prof.Weapons do
		if w.Id == id then return w end
	end
end
local function equipped(prof)
	ensure(prof)
	local w = weaponEntry(prof, prof.WeaponOn) or prof.Weapons[1]
	prof.WeaponOn = w.Id
	return w, Data.WeaponByName[w.Name]
end
local function capsuleCount(prof)
	local n = 0
	for _, v in prof.Capsules or {} do n += v end
	return n
end

-- the Tool in your hand
local TOOL_NAME = "AdventureWeapon"
local function giveTool(player)
	local prof = API.profiles[player]
	if not prof then return end
	local w, def = equipped(prof)
	local char = player.Character
	local bp = player:FindFirstChildOfClass("Backpack")
	if not bp then return end
	for _, holder in {bp, char} do
		for _, t in holder and holder:GetChildren() or {} do
			if t:IsA("Tool") and t:GetAttribute("Weapon") then t:Destroy() end
		end
	end
	local tool = Instance.new("Tool")
	tool.Name = def.Display
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = ("%s %s"):format(def.Icon, def.Display)
	tool:SetAttribute("Weapon", def.Name)
	tool:SetAttribute("Style", def.Style)
	tool:SetAttribute("Range", def.Range)
	tool:SetAttribute("Cd", def.Cd)
	tool:SetAttribute("Fx", def.Fx)
	tool:SetAttribute("Shiny", w.Shiny or nil)
	local tpl = WEAPONS and WEAPONS:FindFirstChild(def.Name)
	local src = tpl and (tpl:IsA("BasePart") and tpl or tpl:FindFirstChildWhichIsA("BasePart", true))
	local handle
	if src then
		handle = src:Clone()
	else -- (model missing) a little glowing stick
		handle = Instance.new("Part")
		handle.Size = Vector3.new(0.4, 3, 0.4)
		handle.Color = def.Fx
		handle.Material = Enum.Material.Neon
	end
	handle.Name = "Handle"
	handle.Anchored, handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, false, true
	for _, c in handle:GetChildren() do
		if c:IsA("JointInstance") or c:IsA("WeldConstraint") then c:Destroy() end
	end
	handle.Parent = tool
	-- hold it near the bottom, standing up out of the hand
	tool.Grip = CFrame.new(0, -(handle.Size.Y / 2 - math.min(0.6, handle.Size.Y * 0.18)), 0)
	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, handle.Size.Y / 2, 0)
	tip.Parent = handle
	if w.Shiny then
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 160, 220), Color3.fromRGB(160, 220, 255))
		pe.Size = NumberSequence.new(0.35, 0)
		pe.Rate, pe.Lifetime, pe.Speed = 8, NumberRange.new(0.6, 1), NumberRange.new(0.5, 1.5)
		pe.LightEmission = 1
		pe.Parent = handle
	end
	tool.Parent = bp
	-- in a wild land it goes straight into your hand
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and player:GetAttribute("Realm") then hum:EquipTool(tool) end
	return tool
end

-- roll a capsule: rarity from its weights, then one weapon of that rarity, 5% shiny
local function rollCapsule(kind)
	local cap = Data.Capsules[kind]
	local total = 0
	for _, w in cap.Weights do total += w end
	local r, rarity = math.random() * total, "Common"
	for _, rr in Data.WeaponRarities do
		local w = cap.Weights[rr.Name] or 0
		if w > 0 then
			r -= w
			rarity = rr.Name
			if r <= 0 then break end
		end
	end
	local pool = {}
	for _, def in Data.Weapons do
		if def.Rarity == rarity then table.insert(pool, def) end
	end
	local def = pool[math.random(#pool)]
	local odds = math.floor(total / (cap.Weights[rarity] or 1) * #pool + 0.5)
	return def, math.random() < Data.WeaponShinyChance, odds
end

-- put a weapon in your collection: new, +1 ⭐, or coins when it's maxed
local function addWeapon(player, prof, name, shiny)
	ensure(prof)
	local def = Data.WeaponByName[name]
	for _, w in prof.Weapons do
		if w.Name == name and (w.Shiny or false) == (shiny or false) then
			if (w.Stars or 0) < Data.WeaponMaxStars then
				w.Stars = (w.Stars or 0) + 1
				return {Id = w.Id, Stars = w.Stars, Up = true}
			end
			local coins = Data.WeaponMaxedCoins[def.Rarity] or 20
			API.addCoins(player, coins)
			return {Id = w.Id, Stars = w.Stars, Coins = coins}
		end
	end
	local w = {Id = prof.NextWeaponId, Name = name, Stars = 0, Shiny = shiny or nil}
	prof.NextWeaponId += 1
	table.insert(prof.Weapons, w)
	-- a stronger weapon goes straight into your hand
	local _, nowDef = equipped(prof)
	local cur = weaponEntry(prof, prof.WeaponOn)
	if Data.WeaponPower(w) > Data.WeaponPower(cur) then
		prof.WeaponOn = w.Id
		task.defer(giveTool, player)
		return {Id = w.Id, Stars = 0, New = true, Equipped = true, Was = nowDef and nowDef.Display}
	end
	return {Id = w.Id, Stars = 0, New = true}
end

local function giveCapsule(player, kind, n)
	local prof = API.profiles[player]
	if not prof or not Data.Capsules[kind] then return end
	ensure(prof)
	prof.Capsules[kind] = (prof.Capsules[kind] or 0) + (n or 1)
	player:SetAttribute("Capsules", capsuleCount(prof))
end
API.giveCapsule = giveCapsule

---------------------------------------------------------------- hearts
local life = {} -- player -> {hearts, lastHit, safeUntil, fainted, lastAtk}
local function lifeOf(player)
	local l = life[player]
	if not l then
		l = {hearts = Data.Hearts, lastHit = 0, safeUntil = 0, lastAtk = 0}
		life[player] = l
		player:SetAttribute("Hearts", l.hearts)
		player:SetAttribute("HeartsMax", Data.Hearts)
	end
	return l
end

local mobs = {} -- model -> mob record
local herds = {} -- herd id -> {mob records}

local function calm(mob)
	mob.target = nil
	mob.m:SetAttribute("Angry", nil)
	mob.m:SetAttribute("TargetId", nil)
end
local function forgetPlayer(player)
	for _, mob in mobs do
		if mob.target == player then
			calm(mob)
			mob.state = "home"
		end
	end
end

local function hurt(player, n, mob)
	local l = lifeOf(player)
	local now = os.clock()
	if l.fainted or now < l.safeUntil then return end
	l.hearts = math.max(0, l.hearts - n)
	l.lastHit = now
	player:SetAttribute("Hearts", l.hearts)
	local hrp = hrpOf(player)
	if hrp then
		local dir = flat(hrp.Position - mob.pos)
		dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
		API.reveal(player, {Kind = "Knock", Dir = dir, Power = mob.boss and 30 or 20}) -- a little bump, not a launch
	end
	send(player, {Kind = "Hurt", N = n, From = mob.m, Hearts = l.hearts})
	if l.hearts <= 0 then
		l.fainted = true
		send(player, {Kind = "Faint"})
		forgetPlayer(player)
		task.delay(1.8, function()
			if not player.Parent then return end
			local spot = API.realmSpawn and API.realmSpawn(player)
			if spot then API.teleportTo(player, spot) end
			l.hearts = Data.Hearts
			l.fainted = nil
			l.safeUntil = os.clock() + Data.SafeSecs
			player:SetAttribute("Hearts", l.hearts)
			send(player, {Kind = "Wake"})
		end)
	end
end

-- hearts come back after a short rest
task.spawn(function()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for player, l in life do
			if not player.Parent then
				life[player] = nil
			elseif not l.fainted and l.hearts < Data.Hearts and now - l.lastHit > Data.HeartRegenDelay and now - (l.regenAt or 0) > Data.HeartRegenSecs then
				l.regenAt = now
				l.hearts += 1
				player:SetAttribute("Hearts", l.hearts)
			end
		end
	end
end)

---------------------------------------------------------------- mobs
local function heightOf(m)
	local _, size = m:GetBoundingBox()
	return size.Y, math.max(size.X, size.Z) / 2
end

local function setGoal(mob, goal, spd)
	mob.goal = goal
	mob.spd = spd
	local g = Vector3.new(goal.X, mob.home.Y, goal.Z)
	local last = mob.sentGoal
	if not last or (last - g).Magnitude > 0.6 or mob.sentSpd ~= spd then
		mob.sentGoal, mob.sentSpd = g, spd
		mob.m:SetAttribute("Goal", g)
		mob.m:SetAttribute("Spd", math.floor(spd * 10 + 0.5) / 10)
	end
end

local addMob -- (forward)
function addMob(run, m, t)
	if not m.Parent then return end
	local land = run.terrain
	local st = Data.MobStats[land] or Data.MobStats.Meadow
	local boss, special = t:GetAttribute("Boss") == true, t:GetAttribute("Special") == true
	local kind = (t:GetAttribute("MobKind") or t.Name):gsub("^Golden", "")
	local u, radius = heightOf(m)
	local mv = MOVE[kind] or {0.8, 1.6}
	local hp = math.floor(st.HP * (boss and Data.MobBoss.HP or (special and Data.MobSpecial.HP or 1)))
	local pv = m:GetPivot()
	local mob = {
		m = m, t = t, run = run, land = land, kind = kind, boss = boss, special = special,
		home = pv.Position, homeCF = pv, pos = pv.Position, u = u, radius = radius,
		speed = mv[1] * u, atkSecs = mv[2], hp = hp, max = hp, state = "idle",
		nextThink = os.clock() + 1 + math.random() * 3, atkAt = 0, hitBy = {},
		roam = m:GetAttribute("Roam") or (boss and 3 or 6), herd = m:GetAttribute("Herd"),
		reach = radius + (boss and 4 or 2.5),
	}
	m:SetAttribute("HP", hp)
	m:SetAttribute("MaxHP", hp)
	m:SetAttribute("Dead", nil)
	setGoal(mob, mob.pos, mob.speed)
	if type(mob.herd) == "string" then
		herds[mob.herd] = herds[mob.herd] or {}
		table.insert(herds[mob.herd], mob)
	end
	mobs[m] = mob
	return mob
end
API.combatAddMob = function(run, m, t) return addMob(run, m, t) end

local function dropMob(mob)
	mobs[mob.m] = nil
	local h = mob.herd and herds[mob.herd]
	if h then
		local i = table.find(h, mob)
		if i then table.remove(h, i) end
		if #h == 0 then herds[mob.herd] = nil end
	end
end
API.combatRunGone = function(run)
	for _, mob in mobs do
		if mob.run == run then dropMob(mob) end
	end
end
API.combatLeft = function(player)
	forgetPlayer(player)
	local l = lifeOf(player)
	l.hearts, l.fainted = Data.Hearts, nil
	player:SetAttribute("Hearts", l.hearts)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum:UnequipTools() end
end

-- the herd shares one target: anger one, they all come
local function anger(mob, player)
	local group = mob.herd and herds[mob.herd] or {mob}
	for _, mm in group do
		if mm.state ~= "dead" and mm.target ~= player then
			mm.target = player
			mm.state = "chase"
			mm.m:SetAttribute("Angry", true)
			mm.m:SetAttribute("TargetId", player.UserId)
		end
	end
end

---------------------------------------------------------------- ⭐ loot stars
-- Items drop as glowing stars on the ground (only the owner sees theirs). What's inside is a surprise until you
-- walk over it, or your buddy pet grabs it for you.
local STAR_TPL = ReplicatedStorage:FindFirstChild("LootStar") -- generated star mesh (falls back to a glowing ball)
local stars = {} -- part -> {owner, run, gift, at}
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = {workspace.Terrain}

local function makeStar()
	local p
	local src = STAR_TPL and (STAR_TPL:IsA("BasePart") and STAR_TPL or STAR_TPL:FindFirstChildWhichIsA("BasePart", true))
	if src then
		p = src:Clone()
		for _, c in p:GetChildren() do
			if c:IsA("JointInstance") or c:IsA("WeldConstraint") then c:Destroy() end
		end
		local s = 2.2 / math.max(p.Size.X, p.Size.Y, p.Size.Z)
		p.Size *= s
	else
		p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * 1.6
		p.Color = Color3.fromRGB(255, 215, 80)
		p.Material = Enum.Material.Neon
	end
	p.Name = "LootStar"
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 220, 120), 12, 2
	light.Parent = p
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.new(1, 1, 1))
	pe.Size = NumberSequence.new(0.5, 0)
	pe.Rate, pe.Lifetime, pe.Speed = 6, NumberRange.new(0.6, 1.2), NumberRange.new(0.5, 2)
	pe.LightEmission = 1
	pe.Parent = p
	return p
end

local function dropStar(player, run, from, gift)
	if not run.folder or not run.folder.Parent then return end
	local a, d = math.random() * math.pi * 2, 2.5 + math.random() * 3.5
	local spot = flat(from) + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
	local hit = workspace:Raycast(spot + Vector3.new(0, from.Y + 60, 0), Vector3.new(0, -400, 0), groundParams)
	local y = hit and hit.Position.Y or (from.Y - 1)
	local p = makeStar()
	p.CFrame = CFrame.new(spot.X, y + 1.8, spot.Z)
	p:SetAttribute("Owner", player.UserId)
	p:SetAttribute("From", from) -- the client pops it out of the mob and arcs it to the ground
	CollectionService:AddTag(p, "LootStar")
	p.Parent = run.folder
	stars[p] = {owner = player, run = run, gift = gift, at = os.clock()}
end

-- open the surprise: give it and say what it was
local function collectStar(p, by)
	local s = stars[p]
	if not s then return end
	stars[p] = nil
	local player, g = s.owner, s.gift
	local text, big = "✨", false
	if g.Type == "Res" then
		API.addRes(player, g.Name, g.N or 1)
		local def = Data.ResByName[g.Name]
		text = ("%s +%d %s"):format(def and def.Icon or "📦", g.N or 1, def and def.Display or g.Name)
	elseif g.Type == "Capsule" then
		giveCapsule(player, g.Land, 1)
		local cap = Data.Capsules[g.Land]
		text, big = ("%s %s!"):format(cap.Icon, cap.Name), true
	elseif g.Type == "Egg" then
		local ok, got = pcall(API.grant, player, {Type = "Egg", Kind = g.Kind, Rarity = g.Rarity})
		if ok and got then API.reveal(player, {Kind = "Prize", Prize = got}) end
		text, big = "🥚 An egg!", true
	elseif g.Type == "Coins" then
		API.addCoins(player, g.N)
		text = "💰 +" .. g.N
	end
	send(player, {Kind = "StarGot", Pos = p.Position, Text = text, Big = big or nil, Pet = by})
	p:Destroy()
end

-- walk over a star to grab it; stars fade after a while
task.spawn(function()
	while true do
		task.wait(0.15)
		local now = os.clock()
		for p, s in stars do
			if not p.Parent then
				stars[p] = nil
			elseif now - s.at > Data.StarLife then
				stars[p] = nil
				p:Destroy()
			else
				local hrp = s.owner.Parent and s.run.inside[s.owner] and hrpOf(s.owner)
				if hrp and (hrp.Position - p.Position).Magnitude < Data.StarPickup then collectStar(p, nil) end
			end
		end
	end
end)

-- prizes for everyone who helped: coins + XP right away, items as ⭐ mystery stars
local function reward(mob, player)
	local st = Data.MobStats[mob.land] or Data.MobStats.Meadow
	local mult = mob.boss and Data.MobBoss or (mob.special and Data.MobSpecial or {Coins = 1, Xp = 1})
	local coins = math.floor(st.Coins * mult.Coins)
	API.addCoins(player, coins)
	API.addFarmXp(player, math.floor(st.Xp * mult.Xp))
	local gifts = {}
	local res = RES_OF[mob.land]
	if res and #res > 0 then
		local n = mob.boss and 3 or (mob.special and 1 or (math.random() < Data.MobNormal.Res and 1 or 0))
		for _ = 1, n do table.insert(gifts, {Type = "Res", Name = res[math.random(#res)], N = 1}) end
	end
	local capChance = mob.boss and Data.MobBoss.Capsule or (mob.special and Data.MobSpecial.Capsule or Data.MobNormal.Capsule)
	if math.random() < capChance then table.insert(gifts, {Type = "Capsule", Land = mob.land}) end
	local eggChance = mob.boss and Data.MobBoss.Egg or (mob.special and Data.MobSpecial.Egg or Data.MobNormal.Egg)
	if math.random() < eggChance then
		local kind = (mob.boss and math.random() < 0.3) and "Star" or Data.MobEgg[mob.land] or "Mystery"
		table.insert(gifts, {Type = "Egg", Kind = kind, Rarity = mob.boss and "Legendary" or "Epic"})
	end
	-- bosses also drop a bonus coin star
	if mob.boss then table.insert(gifts, {Type = "Coins", N = coins}) end
	for _, g in gifts do dropStar(player, mob.run, mob.pos, g) end
	send(player, {Kind = "Loot", Model = mob.m, Items = {"💰+" .. coins}, Stars = #gifts, Boss = mob.boss})
end

local function defeat(mob, by)
	if mob.state == "dead" then return end
	mob.state = "dead"
	calm(mob)
	mob.m:SetAttribute("Dead", true)
	local run = mob.run
	sendRun(run, {Kind = "Defeat", Model = mob.m, Boss = mob.boss, Name = (mob.t.Name:gsub("(%l)(%u)", "%1 %2"))})
	for p in mob.hitBy do
		if p.Parent and run.inside[p] then pcall(reward, mob, p) end
	end
	if mob.boss then
		for p in run.inside do
			API.toast(p, ("🎉 %s was defeated! Great teamwork!"):format((mob.t.Name:gsub("(%l)(%u)", "%1 %2"))))
		end
	end
	dropMob(mob)
	local m, t = mob.m, mob.t
	task.delay(1.1, function() if m.Parent then m:Destroy() end end)
	-- it comes back after a while (if the map is still there)
	task.delay(mob.boss and Data.MobRespawn.Boss or Data.MobRespawn.Normal, function()
		if not run.folder or not run.folder.Parent then return end
		local n = t:Clone()
		n:PivotTo(mob.homeCF)
		n:SetAttribute("Roam", mob.roam)
		if mob.herd then n:SetAttribute("Herd", mob.herd) end
		n.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		for _, d in n:GetDescendants() do
			if d:IsA("BasePart") then d.Anchored = true end
		end
		CollectionService:AddTag(n, "MobRig")
		n.Parent = run.folder
		addMob(run, n, t)
	end)
end

local lastHitBy = {} -- player -> {mob, at}: a Passive buddy helps with the mob you just hit
local function damage(mob, n, player, crit, fromPet)
	if mob.state == "dead" then return end
	mob.hp -= n
	mob.hitBy[player] = true
	if not fromPet then lastHitBy[player] = {mob = mob, at = os.clock()} end
	mob.m:SetAttribute("HP", math.max(0, mob.hp))
	sendRun(mob.run, {Kind = "Dmg", Model = mob.m, N = n, Crit = crit or nil, Pet = fromPet or nil, By = player.UserId})
	if mob.hp <= 0 then
		defeat(mob, player)
	elseif not mob.target then
		anger(mob, player)
	end
end

---------------------------------------------------------------- the brains (5 times a second)
local TICK = 0.2
local function think(mob, now)
	local run = mob.run
	-- is anyone close enough to care?
	local nearest, nd = nil, math.huge
	for p in run.inside do
		local hrp = hrpOf(p)
		if hrp then
			local d = (flat(hrp.Position) - flat(mob.pos)).Magnitude
			if d < nd then nearest, nd = p, d end
		end
	end
	if nd > 170 then return end -- asleep: nobody around
	local fromHome = (flat(mob.pos) - flat(mob.home)).Magnitude
	-- notice someone
	if not mob.target and mob.state ~= "home" then
		local range = Data.MobNotice * (mob.boss and 1.5 or 1)
		for p in run.inside do
			local hrp = hrpOf(p)
			local l = lifeOf(p)
			if hrp and not l.fainted and now > l.safeUntil and (flat(hrp.Position) - flat(mob.pos)).Magnitude < range then
				anger(mob, p)
				break
			end
		end
	end
	if mob.target then
		local p = mob.target
		local hrp = p.Parent and run.inside[p] and hrpOf(p)
		local l = life[p]
		if not hrp or (l and l.fainted) or fromHome > Data.MobLeash or (flat(hrp.Position) - flat(mob.home)).Magnitude > Data.MobLeash + 10 then
			-- give up, walk home and heal
			calm(mob)
			mob.state = "home"
			mob.hp = mob.max
			mob.m:SetAttribute("HP", mob.hp)
			mob.hitBy = {}
		else
			local to = flat(hrp.Position) - flat(mob.pos)
			local d = to.Magnitude
			if d > mob.reach then
				local dir = to.Unit
				setGoal(mob, flat(hrp.Position) - dir * mob.reach * 0.7 + Vector3.new(0, mob.home.Y, 0), mob.speed * 1.45 + 2)
			else
				setGoal(mob, mob.pos, mob.speed)
				if now >= mob.atkAt then
					-- wind up (the client plays the attack move and flashes the glow), then the bonk lands
					mob.atkAt = now + (mob.boss and 2.8 or 2.3) + math.random() * 0.6
					mob.m:SetAttribute("Act", (mob.m:GetAttribute("Act") or 0) + 1)
					task.delay(mob.boss and 0.85 or 0.6, function()
						if mob.state == "dead" or mob.target ~= p then return end
						local h = hrpOf(p)
						if h and (flat(h.Position) - flat(mob.pos)).Magnitude <= mob.reach + 2.5 then
							hurt(p, mob.boss and 2 or 1, mob)
						end
					end)
				end
			end
		end
		return
	end
	if mob.state == "home" then
		if fromHome < 1.5 then
			mob.state = "idle"
			mob.nextThink = now + 2
		else
			setGoal(mob, mob.home, mob.speed * 1.2)
		end
		return
	end
	-- calm: wander around home; herd followers keep their spot next to the leader
	local group = mob.herd and herds[mob.herd]
	local leader = group and group[1]
	if leader and leader ~= mob and leader.state ~= "dead" then
		mob.off = mob.off or (flat(mob.home) - flat(leader.home))
		if mob.off.Magnitude > 7 then mob.off = mob.off.Unit * 7 end
		local spot = flat(leader.goal) + mob.off + Vector3.new(0, mob.home.Y, 0)
		if (flat(spot) - flat(mob.pos)).Magnitude > 1 then
			setGoal(mob, spot, leader.spd * 1.15 + 0.5)
		end
		return
	end
	if now > mob.nextThink and (flat(mob.goal) - flat(mob.pos)).Magnitude < 0.3 then
		mob.nextThink = now + 3 + math.random() * 4
		if math.random() < 0.7 then
			local a, d = math.random() * math.pi * 2, (0.4 + math.random() * 0.6) * mob.roam
			setGoal(mob, mob.home + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), mob.speed)
		end
	end
end

task.spawn(function()
	while true do
		local now = os.clock()
		for _, mob in mobs do
			if mob.state ~= "dead" then
				if not mob.m.Parent then
					dropMob(mob)
				else
					local ok, err = pcall(think, mob, now)
					if not ok then warn("[Combat] mob brain", mob.m.Name, err) end
					-- walk toward the goal (the client does the same smoothly)
					local to = flat(mob.goal) - flat(mob.pos)
					if to.Magnitude > 0.05 then
						local step = math.min(to.Magnitude, mob.spd * TICK)
						mob.pos += to.Unit * step
					end
				end
			end
		end
		task.wait(TICK)
	end
end)

---------------------------------------------------------------- your attacks
local function mobsNear(run, pos, range)
	local list = {}
	for _, mob in mobs do
		if mob.run == run and mob.state ~= "dead" then
			local d = (flat(mob.pos) - flat(pos)).Magnitude - mob.radius
			if d <= range then table.insert(list, {mob, d}) end
		end
	end
	table.sort(list, function(a, b) return a[2] < b[2] end)
	return list
end

remote.OnServerEvent:Connect(function(player, kind, target)
	if kind ~= "Attack" then return end
	local run = API.runOf and API.runOf[player]
	local prof = API.profiles[player]
	local hrp = hrpOf(player)
	if not run or not prof or not hrp then return end
	local l = lifeOf(player)
	if l.fainted then return end
	local w, def = equipped(prof)
	local now = os.clock()
	if now - l.lastAtk < def.Cd * 0.8 then return end
	l.lastAtk = now
	local power = Data.WeaponPower(w)
	local hits = {}
	if def.Style == "Magic" then
		local mob = typeof(target) == "Instance" and mobs[target]
		if mob and mob.run == run and mob.state ~= "dead" and (flat(mob.pos) - flat(hrp.Position)).Magnitude - mob.radius <= def.Range + 6 then
			table.insert(hits, mob)
		else
			local near = mobsNear(run, hrp.Position, def.Range)
			if near[1] then table.insert(hits, near[1][1]) end
		end
	else -- melee: everything in a wide arc in front of you (up to 3)
		local look = flat(hrp.CFrame.LookVector)
		look = look.Magnitude > 0 and look.Unit or Vector3.new(0, 0, -1)
		for _, e in mobsNear(run, hrp.Position, def.Range + 1.5) do
			local to = flat(e[1].pos) - flat(hrp.Position)
			if to.Magnitude < 3 or look:Dot(to.Unit) > -0.25 then
				table.insert(hits, e[1])
				if #hits >= 3 then break end
			end
		end
	end
	for _, mob in hits do
		local crit = math.random() < Data.CritChance
		local n = math.floor(power * (crit and Data.CritMult or 1) * (0.9 + math.random() * 0.2) + 0.5)
		damage(mob, n, player, crit)
	end
	-- friends see your sparkly bolts too
	if def.Style == "Magic" and hits[1] then
		for p in run.inside do
			if p ~= player then send(p, {Kind = "Bolt", From = player, Model = hits[1].m, Color = def.Fx}) end
		end
	end
end)

---------------------------------------------------------------- 🐾 your buddy pet helps out
task.spawn(function()
	while true do
		task.wait(1.4)
		for player, prof in API.profiles do
			local run = API.runOf and API.runOf[player]
			local id = player:GetAttribute("RealmBuddy")
			if run and id and player.Parent then
				local rec = API.findRec(prof, id)
				local c = rec and API.critterFor(rec)
				if c and c.alive and c.model and c.model.Parent then
					local cp = c.model:GetPivot().Position
					local hrp = hrpOf(player)
					local aggressive = prof.BuddyMode == "Aggressive"
					local best, bd = nil, math.huge
					local lh = lastHitBy[player]
					local justHit = lh and os.clock() - lh.at < 8 and lh.mob.state ~= "dead" and lh.mob.run == run and lh.mob
					for _, mob in mobs do
						if mob.run == run and mob.state ~= "dead" then
							local d = (flat(mob.pos) - flat(cp)).Magnitude - mob.radius
							local fromMe = hrp and (flat(mob.pos) - flat(hrp.Position)).Magnitude - mob.radius or math.huge
							-- 🛡️ Passive: only mobs that are after you, or the one you just hit
							-- ⚔️ Aggressive: also any mob near you
							local ok = mob.target == player or mob == justHit or (aggressive and fromMe < Data.BuddyAggroRadius)
							if ok and d < 30 then
								-- the mob after you / you just hit comes first
								local score = d - ((mob.target == player or mob == justHit) and 100 or 0)
								if score < bd then best, bd = mob, score end
							end
						end
					end
					if best then
						local ok, s = pcall(API.petStats, prof, rec)
						local atk = ok and s and s.ATK or 10
						local n = math.max(5, math.floor(atk * 0.8 + 0.5))
						sendRun(run, {Kind = "PetZap", From = c.model, Model = best.m})
						damage(best, n, player, false, true)
					end
				end
			end
		end
	end
end)

-- ⭐ your buddy also grabs your loot stars (one every PetCollect.Secs[level] seconds; level upgrades come later)
local nextGrab = {}
task.spawn(function()
	while true do
		task.wait(0.25)
		local now = os.clock()
		for player, prof in API.profiles do
			local run = API.runOf and API.runOf[player]
			local id = player:GetAttribute("RealmBuddy")
			if run and id and player.Parent and now >= (nextGrab[player] or 0) then
				local rec = API.findRec(prof, id)
				local c = rec and API.critterFor(rec)
				if c and c.alive and c.model and c.model.Parent then
					local cp = c.model:GetPivot().Position
					local best, bd = nil, Data.PetCollect.Radius
					for p, s in stars do
						if s.owner == player and p.Parent then
							local d = (p.Position - cp).Magnitude
							if d < bd then best, bd = p, d end
						end
					end
					if best then
						local lv = math.clamp(prof.PetCollectLv or 1, 1, #Data.PetCollect.Secs)
						nextGrab[player] = now + Data.PetCollect.Secs[lv]
						collectStar(best, c.model)
					end
				end
			end
		end
	end
end)

function ACTIONS.BuddyMode(player, prof, mode)
	if not table.find(Data.BuddyModes, mode) then return "❔" end
	prof.BuddyMode = mode
	player:SetAttribute("BuddyMode", mode)
	return nil
end

---------------------------------------------------------------- weapons menu actions
local function weaponView(prof)
	local list = {}
	for _, w in prof.Weapons do
		table.insert(list, {Id = w.Id, Name = w.Name, Stars = w.Stars or 0, Shiny = w.Shiny or nil, Power = Data.WeaponPower(w)})
	end
	return list
end
function ACTIONS.WeaponInfo(player, prof)
	ensure(prof)
	return {Weapons = weaponView(prof), On = prof.WeaponOn, Capsules = prof.Capsules}
end
function ACTIONS.WeaponEquip(player, prof, id)
	ensure(prof)
	if not weaponEntry(prof, id) then return "❔" end
	prof.WeaponOn = id
	giveTool(player)
	return nil
end
local function openOne(player, prof, kind)
	local def, shiny, odds = rollCapsule(kind)
	local res = addWeapon(player, prof, def.Name, shiny)
	res.Name, res.Rarity, res.Shiny, res.Odds, res.Capsule = def.Name, def.Rarity, shiny or nil, odds, kind
	if def.Rarity == "Legendary" or def.Rarity == "Mythic" or shiny then
		API.notifyAll(("%s %s got a %s%s %s!"):format(def.Icon, player.DisplayName, shiny and "✨Shiny " or "", def.Rarity, def.Display))
	end
	return res
end
function ACTIONS.CapsuleOpen(player, prof, kind)
	ensure(prof)
	if type(kind) ~= "string" or not Data.Capsules[kind] then return "❔" end
	if (prof.Capsules[kind] or 0) <= 0 then return "🎁 You don't have that capsule yet." end
	prof.Capsules[kind] -= 1
	player:SetAttribute("Capsules", capsuleCount(prof))
	return {Result = openOne(player, prof, kind)}
end
function ACTIONS.CapsuleBuy(player, prof)
	ensure(prof)
	local cap = Data.Capsules.Basic
	local coins = API.coinsOf(player)
	coins = typeof(coins) == "Instance" and coins.Value or tonumber(coins) or 0
	if coins < cap.Price then return ("💰 A %s costs 💰%d."):format(cap.Name, cap.Price) end
	API.addCoins(player, -cap.Price)
	return {Result = openOne(player, prof, "Basic")}
end

---------------------------------------------------------------- players
local function onPlayer(player)
	task.spawn(function()
		for _ = 1, 120 do
			if API.profiles[player] then break end
			task.wait(0.5)
		end
		local prof = API.profiles[player]
		if not prof then return end
		ensure(prof)
		lifeOf(player)
		player:SetAttribute("Capsules", capsuleCount(prof))
		player:SetAttribute("BuddyMode", prof.BuddyMode or "Passive")
		if player.Character then giveTool(player) end
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			giveTool(player)
		end)
		player:GetAttributeChangedSignal("Realm"):Connect(function()
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum then return end
			if player:GetAttribute("Realm") then
				local bp = player:FindFirstChildOfClass("Backpack")
				local tool = bp and bp:FindFirstChild((select(2, equipped(prof))).Display)
				if not tool or not tool:GetAttribute("Weapon") then tool = giveTool(player) end
				if tool and tool.Parent ~= char then hum:EquipTool(tool) end
				local l = lifeOf(player)
				l.hearts = Data.Hearts
				player:SetAttribute("Hearts", l.hearts)
			else
				hum:UnequipTools()
			end
		end)
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end
Players.PlayerRemoving:Connect(function(player)
	forgetPlayer(player)
	life[player] = nil
	lastHitBy[player], nextGrab[player] = nil, nil
end)

API.DEV_EXTRA = API.DEV_EXTRA or {}
API.DEV_EXTRA.Capsules = function(player) -- Studio dev menu: 3 of every capsule
	for _, k in Data.CapsuleOrder do giveCapsule(player, k, 3) end
	return "🎁 +3 of every capsule"
end

print("[Combat] ready")
