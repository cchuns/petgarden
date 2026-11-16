-- Critter Acres: WorldEvents (ServerScriptService)
-- Server-wide events on a timer, so "something is happening!" every few minutes:
--   🌠 Falling Star  - a star crashes somewhere (beam warns where). First to grab the big shard gets a Star Egg,
--                      small shards fly everywhere for everyone. Standing too close knocks you back.
--   🏃 Catch Race    - a guaranteed SHINY critter runs around the whole map and flees from players.
--                      Tag it (run into it) 3 times to win it. Every tag pays a few coins. It gets tired now and then.
--   👹 World Boss    - a giant boss appears in a biome. Click/tap it to hit it, everyone's battle pets run over and
--                      fight too. It stomps (red ring) and drops meteors (red circles) that knock you back: dodge!
--                      Rewards by how much damage you did.
--   🎁 Present Rush  - presents rain down on the plaza.
-- Clients read workspace attributes: EventNext/EventAt (countdown), Event/EventEnds/EventPos, EventBoard, BossHP/BossMaxHP.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local Data = API.Data
local GROUND_Y = API.GROUND_Y
local BOUNDS_MIN, BOUNDS_MAX = Vector2.new(-460, -510), Vector2.new(460, 130) -- where runners and stars stay

local stuff = Instance.new("Folder")
stuff.Name = "EventStuff"
stuff.Parent = workspace

local running = nil
local devRequest = nil
function API.StartEvent(name)
	if not Data.EventByName[name] then return "Unknown event" end
	if running then return "An event is already running" end
	devRequest = name
	return ("Starting %s..."):format(name)
end

---------------------------------------------------------------- helpers
local function hrpOf(p)
	local char = p.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function clampWorld(v)
	return Vector3.new(math.clamp(v.X, BOUNDS_MIN.X, BOUNDS_MAX.X), 0, math.clamp(v.Z, BOUNDS_MIN.Y, BOUNDS_MAX.Y))
end
local function randomWorldPoint()
	if math.random() < 0.2 then return API.randomIn(Vector3.new(0, 0, 0), 28, 28) end
	local b = Data.Biomes[math.random(#Data.Biomes)]
	return API.biomePoint(b.Name)
end
local function knock(player, from, power) -- the client flings its own character (it owns the physics)
	local hrp = hrpOf(player)
	if not hrp then return end
	local dir = flat(hrp.Position - from)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
	API.reveal(player, {Kind = "Knock", Dir = dir, Power = power})
end
local function popAt(pos, text, color, size)
	local a = API.part(stuff, {Size = Vector3.one * 0.2, Position = pos, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size or 70, size or 70)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 150
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.Text = text
	t.Parent = bb
	bb.Parent = a
	TweenService:Create(bb, TweenInfo.new(0.9), {StudsOffset = Vector3.new(math.random(-2, 2), 5, 0)}):Play()
	TweenService:Create(t, TweenInfo.new(0.9), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	task.delay(1, function() a:Destroy() end)
end
local function sparkles(parent, color, rate, size)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(size or 1, 0)
	e.Rate = rate or 10
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = parent
	return e
end
-- red warning circle on the ground that fades in; returns the part
local function warnCircle(pos, radius, secs, color)
	local c = API.part(stuff, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, radius * 2, radius * 2), CanCollide = false, CanQuery = false,
		CFrame = CFrame.new(flat(pos) + Vector3.new(0, GROUND_Y + 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color or Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon, Transparency = 0.85})
	TweenService:Create(c, TweenInfo.new(secs), {Transparency = 0.35}):Play()
	return c
end
local function shockwave(pos, radius, color)
	local w = API.part(stuff, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 2, 2), CanCollide = false, CanQuery = false,
		CFrame = CFrame.new(flat(pos) + Vector3.new(0, GROUND_Y + 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color or Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.2})
	TweenService:Create(w, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {Size = Vector3.new(0.6, radius * 2, radius * 2), Transparency = 1}):Play()
	task.delay(0.6, function() w:Destroy() end)
end
local function joined(e, player) -- first time a player takes part in this event: quest progress
	if e.joined[player] then return end
	e.joined[player] = true
	API.questEvent(player, "Event", 1)
end
local function setPos(pos) workspace:SetAttribute("EventPos", pos) end
local function timeLeft(e) return e.endsAt - os.clock() end

local EVENTS = {}
API.EVENTS = EVENTS -- other scripts add events (Adventure: EggSnatch, FashionShow)

---------------------------------------------------------------- 🌠 falling star
function EVENTS.FallingStar(e)
	local p = randomWorldPoint()
	local ground = Vector3.new(p.X, GROUND_Y, p.Z)
	setPos(ground)
	-- warning: pulsing ring + a tall beam you can see from anywhere
	local ring = warnCircle(ground, 12, 1, Color3.fromRGB(255, 220, 80))
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = Vector3.new(0.3, 30, 30)}):Play()
	local beam = API.part(stuff, {Size = Vector3.new(2, 400, 2), Position = ground + Vector3.new(0, 200, 0), CanCollide = false, CanQuery = false,
		Color = Color3.fromRGB(255, 230, 120), Material = Enum.Material.Neon, Transparency = 0.45})
	API.notifyAll("🌠 A star is falling! Follow the light!")
	task.wait(7)
	-- the star falls
	local from = ground + Vector3.new(90, 300, 50)
	local star = API.part(stuff, {Shape = Enum.PartType.Ball, Size = Vector3.one * 8, Position = from, CanCollide = false, CanQuery = false,
		Color = Color3.fromRGB(255, 240, 140), Material = Enum.Material.Neon})
	local fire = Instance.new("Fire")
	fire.Size = 14
	fire.Heat = 0
	fire.Color = Color3.fromRGB(255, 220, 90)
	fire.SecondaryColor = Color3.fromRGB(255, 120, 200)
	fire.Parent = star
	sparkles(star, Color3.fromRGB(255, 240, 160), 60, 2)
	local t0 = os.clock()
	while os.clock() - t0 < 2.2 do
		local f = (os.clock() - t0) / 2.2
		star.Position = from:Lerp(ground + Vector3.new(0, 3, 0), f * f)
		task.wait()
	end
	star:Destroy()
	ring:Destroy()
	beam:Destroy()
	-- boom
	shockwave(ground, 40, Color3.fromRGB(255, 230, 120))
	local boom = API.part(stuff, {Size = Vector3.one, Position = ground + Vector3.new(0, 2, 0), Transparency = 1, CanCollide = false, CanQuery = false})
	sparkles(boom, Color3.fromRGB(255, 200, 120), 0, 3):Emit(80)
	task.delay(2, function() boom:Destroy() end)
	for _, pl in Players:GetPlayers() do
		local hrp = hrpOf(pl)
		if hrp and flat(hrp.Position - ground).Magnitude < 22 then knock(pl, ground, 70) end
	end
	-- crater + shards
	API.part(stuff, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 18, 18), CanCollide = false, CanQuery = false,
		CFrame = CFrame.new(ground + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(60, 50, 40)})
	local left = 0
	local function shard(pos, big)
		left += 1
		local s = API.part(stuff, {Name = big and "BigShard" or "Shard", Size = big and Vector3.new(3, 5, 3) or Vector3.new(1.5, 2.6, 1.5),
			CFrame = CFrame.new(pos + Vector3.new(0, big and 3 or 1.6, 0)) * CFrame.Angles(0, math.random() * 3, math.pi / 4),
			Color = big and Color3.fromRGB(255, 225, 90) or Color3.fromRGB(200, 170, 255), Material = Enum.Material.Neon, CanCollide = false})
		sparkles(s, s.Color, big and 20 or 6, big and 1.4 or 0.7)
		local light = Instance.new("PointLight")
		light.Color = s.Color
		light.Range = big and 16 or 8
		light.Parent = s
		local prompt = API.makePrompt(s, big and "Grab ⭐" or "Grab ✨", "")
		prompt.HoldDuration = big and 1.2 or 0
		prompt.MaxActivationDistance = big and 10 or 8
		prompt.Triggered:Connect(function(player)
			if not s.Parent or not API.profiles[player] then return end
			s:Destroy()
			left -= 1
			joined(e, player)
			local got = API.grant(player, big and Data.StarBigPrize or API.rollWeighted(Data.StarShardPrizes))
			API.reveal(player, {Kind = "Prize", Prize = got})
			API.pushState(player)
			if big then API.notifyAll(("🌟 %s grabbed the big star shard!"):format(player.DisplayName)) end
		end)
	end
	shard(ground, true)
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + math.random()
		local r = 9 + math.random() * 18
		shard(clampWorld(ground + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)) + Vector3.new(0, GROUND_Y, 0), false)
	end
	while timeLeft(e) > 0 and left > 0 do task.wait(0.5) end
end

---------------------------------------------------------------- 🏃 catch race
function EVENTS.CatchRace(e)
	local weights = {Rare = 50, Epic = 35, Legendary = 15}
	local total = 0
	for _, w in weights do total += w end
	local r, rarity = math.random() * total, "Rare"
	for k, w in weights do
		r -= w
		if r <= 0 then rarity = k break end
	end
	local options = {}
	for _, s in Data.Species do
		if s.Rarity == rarity and not s.Flyer then table.insert(options, s) end
	end
	local T = options[math.random(#options)]
	local biome = Data.Biomes[math.random(#Data.Biomes)].Name
	local c = API.spawnCritter(T, nil, nil, {Variant = "Shiny", Biome = biome, Quiet = true})
	c.controlled = true
	c.leaveAt = math.huge
	c.prompt.Enabled = false
	c.tag.Text = ("🏃 CATCH ME!\n✨ %s"):format(T.Species)
	local marker = Instance.new("BillboardGui") -- seen through walls from anywhere
	marker.Size = UDim2.fromOffset(70, 70)
	marker.StudsOffset = Vector3.new(0, c.halfH * 2 + 4, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 2000
	local ml = Instance.new("TextLabel")
	ml.BackgroundTransparency = 1
	ml.Size = UDim2.fromScale(1, 1)
	ml.TextScaled = true
	ml.Text = "🏃💨"
	ml.Parent = marker
	marker.Parent = c.body
	API.notifyAll(("🏃 CATCH RACE! A SHINY %s is running wild! Tag it %d times!"):format(T.Species, Data.RaceTags))

	local tags, lastTag = {}, {}
	local dashUntil, tiredUntil, nextTired = 0, 0, os.clock() + 6 + math.random() * 3
	local winner
	local function board()
		local list = {}
		for p, n in tags do table.insert(list, {p.DisplayName, n}) end
		table.sort(list, function(a, b) return a[2] > b[2] end)
		local out = {}
		for i = 1, math.min(3, #list) do table.insert(out, list[i]) end
		workspace:SetAttribute("EventBoard", HttpService:JSONEncode(out))
	end
	board()
	while timeLeft(e) > 0 and c.alive and not winner do
		local now = os.clock()
		setPos(c.pos)
		-- tags: run into it
		local nearestD, nearestPos = math.huge, nil
		for _, pl in Players:GetPlayers() do
			local hrp = hrpOf(pl)
			if hrp then
				local d = flat(hrp.Position - c.pos).Magnitude
				if d < nearestD then nearestD, nearestPos = d, hrp.Position end
				if d < 6 + c.halfH * 0.5 and now - (lastTag[pl] or 0) > 1.2 then
					lastTag[pl] = now
					tags[pl] = (tags[pl] or 0) + 1
					joined(e, pl)
					API.addCoins(pl, Data.RaceTagCoins)
					API.pop(c.body, ("⭐ %d/%d"):format(tags[pl], Data.RaceTags))
					c.model:SetAttribute("PetAt", now) -- squeaks (hearts + wiggle)
					dashUntil, tiredUntil = now + 1.3, 0
					board()
					if tags[pl] >= Data.RaceTags then winner = pl end
				end
			end
		end
		if winner then break end
		-- getting tired now and then gives everyone a chance
		if now > nextTired and tiredUntil == 0 then
			tiredUntil = now + 1.8
			nextTired = now + 6 + math.random() * 4
			API.pop(c.body, "😵")
		end
		if tiredUntil > 0 and now < tiredUntil then
			c.target = nil
		else
			tiredUntil = 0
			if nearestPos and nearestD < 32 then -- run away (with a wobble so it zig-zags)
				local away = flat(c.pos - nearestPos)
				away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
				away = (CFrame.Angles(0, (math.random() - 0.5) * 1.4, 0) * away)
				local goal = clampWorld(c.pos + away * 14)
				if (goal - c.pos).Magnitude < 4 then goal = clampWorld(c.pos + (Vector3.new(0, 0, -60) - c.pos).Unit * 14) end -- cornered: dart to the middle
				c.target = goal
				c.speedBoost = (now < dashUntil and 27 or 17) / T.Speed
			elseif not c.target or flat(c.target - c.pos).Magnitude < 2 then
				c.target = clampWorld(c.pos + Vector3.new(math.random(-40, 40), 0, math.random(-40, 40)))
				c.speedBoost = 9 / T.Speed
			end
		end
		task.wait(0.1)
	end
	workspace:SetAttribute("EventBoard", nil)
	if winner then
		local prof = API.profiles[winner]
		if prof and API.countRole(prof, T.Role) < API.capFor(winner, T.Role) then
			local rec = API.addPet(winner, T, {Variant = "Shiny", SizeName = c.sizeName})
			API.removeCritter(c)
			API.spawnCritter(T, winner, rec)
		else -- no room: a Star Egg instead
			API.removeCritter(c)
			API.reveal(winner, {Kind = "Prize", Prize = API.grant(winner, Data.StarBigPrize)})
		end
		API.notifyAll(("🏆 %s caught the SHINY %s!"):format(winner.DisplayName, T.Species))
		if API.giveTitle then API.giveTitle(winner, "Speedy Catcher") end
		API.reveal(winner, {Kind = "RaceWin", Species = T.Species, Variant = "Shiny"})
		API.pushState(winner)
	else
		API.notifyAll(("💨 The %s got away!"):format(T.Species))
		if c.alive then API.removeCritter(c) end
	end
end

---------------------------------------------------------------- 👹 world boss
local function bossTemplate()
	local folder = ReplicatedStorage:FindFirstChild("EnemyModels")
	local names = {}
	for _, raid in Data.Raids do
		if folder and folder:FindFirstChild(raid.Boss) then table.insert(names, raid.Boss) end
	end
	if #names == 0 then return nil end
	return folder[names[math.random(#names)]]
end

function EVENTS.WorldBoss(e)
	-- the wild lands are generated maps behind the Terrain Portal now, so the boss lands on the green next to it
	local green = API.root:FindFirstChild("NorthGreen")
	local center = green and flat(green.Position) or Vector3.new(4, 0, -62)
	setPos(center + Vector3.new(0, GROUND_Y, 0))
	-- the boss: a raid boss model, made giant
	local template = bossTemplate()
	local boss
	if template then
		boss = template:Clone()
		local _, size = boss:GetBoundingBox()
		boss:ScaleTo(boss:GetScale() * 24 / math.max(size.Y, 1))
	else
		boss = Instance.new("Model")
		local b = API.part(boss, {Shape = Enum.PartType.Ball, Size = Vector3.one * 22, Position = Vector3.zero, Color = Color3.fromRGB(120, 220, 120)})
		boss.PrimaryPart = b
	end
	boss.Name = "WorldBoss"
	for _, d in boss:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery = true, false, true end
	end
	local _, size = boss:GetBoundingBox()
	local radius = math.max(size.X, size.Z) / 2
	local baseCF = CFrame.new(center + Vector3.new(0, GROUND_Y + size.Y / 2, 0))
	boss:PivotTo(baseCF * CFrame.new(0, -size.Y, 0)) -- rises out of the ground
	boss.Parent = stuff
	local players = #Players:GetPlayers()
	local maxHP = Data.BossHP + Data.BossHPPerPlayer * players
	local hp = maxHP
	workspace:SetAttribute("BossMaxHP", maxHP)
	workspace:SetAttribute("BossHP", hp)
	-- health bar over its head
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(300, 40)
	bb.StudsOffset = Vector3.new(0, size.Y / 2 + 4, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 400
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(40, 30, 50)
	Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
	bg.Parent = bb
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 70, 90)
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	fill.Parent = bg
	bb.Parent = boss.PrimaryPart or boss:FindFirstChildWhichIsA("BasePart")
	API.notifyAll("👹 A WORLD BOSS appeared by the 🌀 Terrain Portal! Tap it to fight, your battle pets will help!")

	local damage = {}
	local dead = false
	local function hit(player, amount, at)
		if dead or amount <= 0 then return end
		amount = math.floor(amount)
		hp = math.max(0, hp - amount)
		damage[player] = (damage[player] or 0) + amount
		workspace:SetAttribute("BossHP", hp)
		fill.Size = UDim2.fromScale(hp / maxHP, 1)
		joined(e, player)
		if at then popAt(at, "-" .. amount, Color3.fromRGB(255, 230, 120), 50) end
		if hp <= 0 then dead = true end
	end
	-- click / tap to hit
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 80
	click.Parent = boss
	local clickTimes = {}
	click.MouseClick:Connect(function(player)
		local now = os.clock()
		local list = clickTimes[player] or {}
		clickTimes[player] = list
		while list[1] and now - list[1] > 1 do table.remove(list, 1) end
		if #list >= 7 then return end -- 7 hits a second at most
		table.insert(list, now)
		local dmg = Data.BossClickDamage + 2 * API.farmLevelOf(player)
		local top = boss:GetPivot().Position + Vector3.new(math.random(-4, 4), size.Y * 0.2 + math.random() * 4, math.random(-4, 4))
		hit(player, dmg, top)
	end)
	-- rise up
	local t0 = os.clock()
	while os.clock() - t0 < 1.5 do
		local f = (os.clock() - t0) / 1.5
		boss:PivotTo(baseCF * CFrame.new(0, -size.Y * (1 - f) ^ 2, 0))
		task.wait()
	end
	shockwave(center, radius + 20, Color3.fromRGB(255, 120, 120))

	-- battle pets of everyone rally around it
	local rallied = {}
	local function rally()
		local i = 0
		for c in API.critters do
			if c.owner and c.record and not c.record.Stored and not c.ride and not c.controlled and not c.rally then
				i += 1
				local a = i * 0.9
				c.rally = center + Vector3.new(math.cos(a), 0, math.sin(a)) * (radius + 5 + (i % 3) * 3)
				c.version += 1
				table.insert(rallied, c)
			end
		end
	end
	rally()

	-- the boss moves: bobs, turns to the nearest player, and attacks every few seconds
	local turn = 0
	local hop = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		if dead then return end
		local nearest, nd = nil, math.huge
		for _, pl in Players:GetPlayers() do
			local h = hrpOf(pl)
			if h then
				local d = flat(h.Position - center).Magnitude
				if d < nd then nearest, nd = h, d end
			end
		end
		if nearest and nd < 120 then
			local want = math.atan2(-(nearest.Position.X - center.X), -(nearest.Position.Z - center.Z))
			local diff = (want - turn + math.pi) % (2 * math.pi) - math.pi
			turn += math.clamp(diff, -dt * 1.5, dt * 1.5)
		end
		local bob = math.sin(os.clock() * 2) * 0.6
		boss:PivotTo(baseCF * CFrame.new(0, bob + hop, 0) * CFrame.Angles(0, turn, 0))
	end)
	local nextAttack = os.clock() + 4
	local nextPetTick = os.clock()
	local petAnim = {}
	while timeLeft(e) > 0 and not dead do
		local now = os.clock()
		-- pets fight
		if now >= nextPetTick then
			nextPetTick = now + 0.5
			rally() -- pets that just got home/befriended join in
			for _, c in rallied do
				if c.alive and c.owner and flat(c.pos - center).Magnitude < radius + 16 then
					local dps = API.petPower(c) * Data.BossPetDps
					hit(c.owner, dps * 0.5, nil)
					if now - (petAnim[c] or 0) > 1.4 then
						petAnim[c] = now
						c.model:SetAttribute("Work", (c.model:GetAttribute("Work") or 0) + 1) -- hop-spin attack
						popAt(c.body.Position + Vector3.new(0, c.halfH + 2, 0), "⚔️" .. math.floor(dps * 1.4), Color3.fromRGB(255, 200, 120), 44)
					end
				end
			end
		end
		-- boss attacks
		if now >= nextAttack then
			nextAttack = now + 5 + math.random() * 2.5
			if math.random() < 0.5 then -- STOMP: red ring around it, then a jump and a shockwave
				local R = radius + 16
				local ring = warnCircle(center, R, 1.6)
				task.wait(1.6)
				ring:Destroy()
				local h0 = os.clock()
				while os.clock() - h0 < 0.35 do
					hop = math.sin((os.clock() - h0) / 0.35 * math.pi) * 6
					task.wait()
				end
				hop = 0
				shockwave(center, R, Color3.fromRGB(255, 90, 90))
				for _, pl in Players:GetPlayers() do
					local h = hrpOf(pl)
					if h and flat(h.Position - center).Magnitude < R then
						knock(pl, center, 80)
						API.pop(h, "💫")
					end
				end
			else -- METEORS: red circles under players nearby, then rocks fall on them
				local spots = {}
				for _, pl in Players:GetPlayers() do
					local h = hrpOf(pl)
					if h and flat(h.Position - center).Magnitude < 90 and #spots < 5 then
						table.insert(spots, flat(h.Position) + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
					end
				end
				if #spots == 0 then table.insert(spots, center + Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))) end
				local rings = {}
				for _, s in spots do table.insert(rings, warnCircle(s, 8, 1.4)) end
				task.wait(1.4)
				for i, s in spots do
					rings[i]:Destroy()
					local rock = API.part(stuff, {Shape = Enum.PartType.Ball, Size = Vector3.one * 5, Position = s + Vector3.new(0, 60, 0), CanCollide = false,
						CanQuery = false, Color = Color3.fromRGB(255, 120, 60), Material = Enum.Material.Neon})
					TweenService:Create(rock, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = s + Vector3.new(0, GROUND_Y + 2, 0)}):Play()
					task.delay(0.45, function()
						rock:Destroy()
						shockwave(s, 10, Color3.fromRGB(255, 150, 80))
						for _, pl in Players:GetPlayers() do
							local h = hrpOf(pl)
							if h and flat(h.Position - s).Magnitude < 9 then knock(pl, s, 60) end
						end
					end)
				end
			end
		end
		task.wait(0.1)
	end
	conn:Disconnect()
	for _, c in rallied do
		c.rally = nil
		if c.alive then c.version += 1 end
	end
	workspace:SetAttribute("BossHP", nil)
	workspace:SetAttribute("BossMaxHP", nil)
	if dead then
		-- defeated: burst, sink, rewards by damage share
		shockwave(center, radius + 30, Color3.fromRGB(255, 230, 120))
		local burst = API.part(stuff, {Size = Vector3.one, Position = center + Vector3.new(0, size.Y / 2, 0), Transparency = 1, CanCollide = false, CanQuery = false})
		sparkles(burst, Color3.fromRGB(255, 220, 120), 0, 4):Emit(120)
		task.delay(3, function() burst:Destroy() end)
		API.notifyAll("🏆 The World Boss was defeated! Rewards for everyone who helped!")
		local total, list = 0, {}
		for p, d in damage do
			total += d
			table.insert(list, {p, d})
		end
		table.sort(list, function(a, b) return a[2] > b[2] end)
		for rank, entry in list do
			local p, d = entry[1], entry[2]
			if p.Parent and API.profiles[p] then
				local share = d / math.max(1, total)
				if API.record then API.record("Boss", p, d) end
				if rank == 1 and API.giveTitle then API.giveTitle(p, "Boss Slayer") end
				local coins = 40 + math.floor(share * 400)
				API.addCoins(p, coins)
				local rolls = 1 + (share >= 0.25 and 1 or 0) + (rank == 1 and 1 or 0)
				task.spawn(function()
					API.reveal(p, {Kind = "Prize", Prize = {Type = "Coins", Amount = coins, Rarity = "Rare"}})
					for _ = 1, rolls do
						task.wait(1.2)
						API.reveal(p, {Kind = "Prize", Prize = API.grant(p, API.rollWeighted(Data.BossPrizes))})
					end
					API.pushState(p)
				end)
			end
		end
	else
		API.notifyAll("👹 The World Boss stomped away... next time!")
		for p in damage do
			if p.Parent then API.addCoins(p, 20) end
		end
	end
	local s0 = os.clock()
	while os.clock() - s0 < 1.5 do
		boss:PivotTo(baseCF * CFrame.new(0, -size.Y * ((os.clock() - s0) / 1.5) ^ 2, 0) * CFrame.Angles(0, turn, 0))
		task.wait()
	end
	boss:Destroy()
end

---------------------------------------------------------------- 🎁 present rush
function EVENTS.PresentRush(e)
	setPos(Vector3.new(0, GROUND_Y, 0))
	API.notifyAll("🎁 PRESENT RUSH in the plaza!")
	for _ = 1, 16 do
		if timeLeft(e) <= 0 then break end
		API.spawnPresent(API.randomIn(Vector3.new(0, 0, 0), 30, 30))
		task.wait(0.5)
	end
	while timeLeft(e) > 0 do task.wait(1) end
end

---------------------------------------------------------------- the timer
while true do
	local waitUntil = os.clock() + math.random(Data.EventGap[1], Data.EventGap[2])
	while os.clock() < waitUntil and not devRequest do task.wait(1) end
	local def = devRequest and Data.EventByName[devRequest] or API.rollWeighted(Data.Events)
	local warnSecs = devRequest and 5 or Data.EventWarn
	devRequest = nil
	-- countdown everyone can see
	workspace:SetAttribute("EventNext", def.Name)
	workspace:SetAttribute("EventAt", os.time() + warnSecs)
	API.notifyAll(("%s in %d!"):format(def.Icon, warnSecs))
	task.wait(warnSecs)
	workspace:SetAttribute("EventNext", nil)
	workspace:SetAttribute("EventAt", nil)
	local e = {def = def, endsAt = os.clock() + def.Secs, joined = {}}
	running = def.Name
	workspace:SetAttribute("Event", def.Name)
	workspace:SetAttribute("EventEnds", os.time() + def.Secs)
	local ok, err = pcall(EVENTS[def.Name], e)
	if not ok then warn("[WorldEvents]", def.Name, err) end
	running = nil
	workspace:SetAttribute("Event", nil)
	workspace:SetAttribute("EventEnds", nil)
	workspace:SetAttribute("EventPos", nil)
	workspace:SetAttribute("EventBoard", nil)
	for _, ch in stuff:GetChildren() do
		if ch.Name ~= "Crater" then ch:Destroy() end
	end
end
