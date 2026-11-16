-- Critter Acres: Hooks (ServerScriptService)
-- Small "come back!" and "one more minute!" systems:
--   🧭 Starter journey   - 8 steps with a glowing arrow (client), a prize each step, a Rare pet at the end
--   🎁 Playtime gifts    - open after 5 / 10 / 15 ... 60 minutes in one session
--   📅 7-day calendar    - one box per day you play; missing a day never resets it
--   📬 Mailbox           - a gift waits when you come back, friends can send you gifts (flag goes up)
--   🧺 Pile-up           - pets that stayed home leave piles on your farm to scoop up
--   🌈 Farm visitor      - sometimes a rare critter waits on your farm when you come back (free friend)
--   🐾 Greeting          - your pets jump for joy when you come back
--   🌙 Moon Pot          - one giant crop that takes 8 hours (offline too), big prize
--   ⭐ Golden dash       - a sparkly critter zooms past you now and then: tap it!
--   🧑‍🌾 Helper quests    - Farmer Fern, Explorer Pip, Baker Bun give little quest stories
--   👫 Friend luck, 🏅 badges, 💪 Farm Power
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local Data = API.Data
local ACTIONS = API.ACTIONS
local Builds = require(ReplicatedStorage:WaitForChild("Builds"))

local function ts() return workspace:GetAttribute("CritterTimeScale") or 1 end
local function today() return math.floor(os.time() / 86400) end
local function P(parent, props)
	local x = Instance.new("Part")
	x.Anchored, x.TopSurface, x.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do x[k] = v end
	x.Parent = parent
	return x
end
local function billboard(parent, size, offset, maxDist)
	local bb = Instance.new("BillboardGui")
	bb.Size = size
	bb.StudsOffset = offset
	bb.MaxDistance = maxDist or 100
	bb.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
	t.BackgroundTransparency = 0.1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(90, 60, 40)
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 14)
	t.Parent = bb
	return t, bb
end
local function sparkles(parent, color, rate)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rate = rate or 8
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.6, 0)
	e.Parent = parent
	return e
end
local function hrpOf(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end

---------------------------------------------------------------- 🏅 badges
local badgeCache = {}
function API.badge(player, key)
	local id = Data.Badges[key]
	if not id or id == 0 then return end
	badgeCache[player] = badgeCache[player] or {}
	if badgeCache[player][key] then return end
	badgeCache[player][key] = true
	task.spawn(function()
		pcall(function()
			if not BadgeService:UserHasBadgeAsync(player.UserId, id) then BadgeService:AwardBadge(player.UserId, id) end
		end)
	end)
end
task.spawn(function() -- FunServer adds API.giveTitle; wrap it so some titles also give badges
	for _ = 1, 40 do
		if API.giveTitle then break end
		task.wait(0.5)
	end
	local oldGiveTitle = API.giveTitle
	if not oldGiveTitle then return end
	API.giveTitle = function(player, name, ...)
		if name == "Boss Slayer" then API.badge(player, "BossSlayer") end
		if name == "Acorn Master" then API.badge(player, "AllAcorns") end
		return oldGiveTitle(player, name, ...)
	end
end)
function API.onNewPet(player, prof, rec, T)
	if rec.Variant then API.badge(player, "FirstShiny") end
	if T.Rarity == "Legendary" then API.badge(player, "Legendary") end
end
function API.onHatch(player, prof, rec, T)
	API.badge(player, "FirstHatch")
	if T.Secret then API.badge(player, "SecretPet") end
end

---------------------------------------------------------------- 👫 friend luck
local friendCount = {}
local function refreshFriends()
	for _, p in Players:GetPlayers() do
		local n = 0
		for _, o in Players:GetPlayers() do
			if o ~= p then
				local ok, isFriend = pcall(function() return p:IsFriendsWith(o.UserId) end)
				if ok and isFriend then n += 1 end
			end
		end
		friendCount[p] = n
		p:SetAttribute("FriendLuck", math.floor(math.min(Data.FriendLuckMax, n * Data.FriendLuck) * 100 + 0.5))
	end
end
function API.friendLuck(player)
	return math.min(Data.FriendLuckMax, (friendCount[player] or 0) * Data.FriendLuck)
end
Players.PlayerAdded:Connect(function() task.delay(3, refreshFriends) end)
Players.PlayerRemoving:Connect(function(p)
	friendCount[p] = nil
	badgeCache[p] = nil
	task.delay(1, refreshFriends)
end)

---------------------------------------------------------------- prizes ("Pet" = a random pet of that rarity)
local function givePrize(player, prize)
	if prize.Type == "Pet" then
		local options = {}
		for _, s in Data.Species do
			if s.Rarity == prize.Rarity and not s.Secret then table.insert(options, s) end
		end
		local T = options[math.random(#options)]
		local rec = API.addPet(player, T)
		API.spawnCritter(T, player, rec)
		API.pushState(player)
		return {Type = "Pet", Species = T.Species, Rarity = T.Rarity}
	end
	return API.grant(player, prize)
end
API.givePrize = givePrize

---------------------------------------------------------------- 🧭 journey + 🧑‍🌾 helper quests
local function journeyAttrs(player, prof)
	local j = prof.Journey
	local step = Data.Journey[j.Step]
	player:SetAttribute("JourneyStep", step and j.Step or nil)
	player:SetAttribute("JourneyKind", step and step.Kind or nil)
	player:SetAttribute("JourneyText", step and step.Text or nil)
	player:SetAttribute("JourneyProg", step and j.Prog or nil)
	player:SetAttribute("JourneyCount", step and step.Count or nil)
end
local function journeyAdvance(player, prof)
	local j = prof.Journey
	local step = Data.Journey[j.Step]
	if not step or j.Prog < step.Count then return end
	local got = givePrize(player, step.Prize)
	API.reveal(player, {Kind = "Journey", Step = j.Step, Total = #Data.Journey, Text = step.Text, Prize = got})
	j.Step += 1
	j.Prog = 0
	local nextStep = Data.Journey[j.Step]
	if nextStep and nextStep.Kind == "Hatch" then -- the journey gives you an egg that hatches fast
		API.addEgg(prof, "Mystery", {Secs = Data.JourneyEgg})
		API.toast(player, "🥚 A surprise egg is in the nest on your farm! Tap it when it's ready.")
		API.pushState(player)
	end
	if not nextStep then
		API.notifyAll(("🧭 %s finished the Starter Journey!"):format(player.DisplayName))
		API.badge(player, "Journey")
	end
	journeyAttrs(player, prof)
end
table.insert(API.questHooks, function(player, prof, kind, n)
	local j = prof.Journey
	local step = j and Data.Journey[j.Step]
	if step and step.Kind == kind then
		j.Prog = math.min(step.Count, j.Prog + n)
		journeyAttrs(player, prof)
		journeyAdvance(player, prof)
	end
	if prof.NPCQ then
		for i, npc in Data.NPCs do
			local q = prof.NPCQ[i]
			local st = q and npc.Chain[q.Step]
			if st and st.Kind == kind and q.Prog < st.Count then
				q.Prog = math.min(st.Count, q.Prog + n)
				if q.Prog >= st.Count then API.toast(player, ("%s %s: you did it! Come see me for your prize!"):format(npc.Icon, npc.Name)) end
				player:SetAttribute("NPCReady", true)
			end
		end
	end
end)

function ACTIONS.NPCInfo(player, prof, i)
	local npc = Data.NPCs[i]
	if not npc or not prof.NPCQ then return nil end
	local q = prof.NPCQ[i]
	local st = npc.Chain[q.Step]
	if not st then return {Name = npc.Name, Icon = npc.Icon, Done = true, Total = #npc.Chain} end
	return {Name = npc.Name, Icon = npc.Icon, Step = q.Step, Total = #npc.Chain, Text = st.Text, Prog = q.Prog, Count = st.Count, Prize = st.Prize}
end
function ACTIONS.NPCClaim(player, prof, i)
	local npc = Data.NPCs[i]
	local q = npc and prof.NPCQ and prof.NPCQ[i]
	local st = q and npc.Chain[q.Step]
	if not st or q.Prog < st.Count then return nil end
	local got = givePrize(player, st.Prize)
	q.Step += 1
	q.Prog = 0
	API.pushState(player)
	return {Prize = got, Info = ACTIONS.NPCInfo(player, prof, i)}
end

---------------------------------------------------------------- 🎁 playtime gifts + 📅 calendar
local sessionStart = {}
local playGot = {}
local function playAttrs(player)
	local got = {}
	for i in playGot[player] or {} do table.insert(got, i) end
	player:SetAttribute("PlayStart", sessionStart[player])
	player:SetAttribute("PlayGot", table.concat(got, ","))
end
function ACTIONS.PlayGift(player, prof, i)
	local g = Data.PlayGifts[i]
	if not g or not sessionStart[player] or playGot[player][i] then return nil end
	if os.time() - sessionStart[player] < g.Min * 60 / ts() then return {Error = "⏱"} end
	playGot[player][i] = true
	playAttrs(player)
	return {Prize = givePrize(player, g.Prize)}
end
local function calAttrs(player, prof)
	player:SetAttribute("CalGot", prof.Cal.Got)
	player:SetAttribute("CalReady", prof.Cal.Day ~= today())
end
function ACTIONS.CalendarClaim(player, prof)
	if prof.Cal.Day == today() then return {Error = "Come back tomorrow!"} end
	local idx = prof.Cal.Got % #Data.Calendar + 1
	prof.Cal.Got += 1
	prof.Cal.Day = today()
	calAttrs(player, prof)
	return {Index = idx, Prize = givePrize(player, Data.Calendar[idx])}
end

---------------------------------------------------------------- per-farm things: 📬 mailbox, 🌙 moon pot
local farmBits = {} -- farm -> {flag, mailLabel, potLabel, plantHolder, potPrompt}
local function mailAttrs(player, prof)
	player:SetAttribute("MailCount", #prof.Mail)
	local farm = API.farmOf[player]
	local b = farm and farmBits[farm]
	if b then
		b.flag.Color = #prof.Mail > 0 and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(150, 150, 150)
		b.flagHinge.CFrame = b.flagBase * CFrame.Angles(0, 0, #prof.Mail > 0 and 0 or -math.pi / 2)
		b.flag.CFrame = b.flagHinge.CFrame * CFrame.new(0, 0.9, 0)
		b.mailLabel.Text = #prof.Mail > 0 and ("📬 %d gift%s!"):format(#prof.Mail, #prof.Mail > 1 and "s" or "") or "📪 Mailbox"
		b.mailLabel.BackgroundColor3 = #prof.Mail > 0 and Color3.fromRGB(255, 225, 120) or Color3.fromRGB(255, 250, 235)
	end
end
local function openMail(player, prof)
	if #prof.Mail == 0 then return {Error = "📪 No mail right now. Friends can send you gifts!"} end
	local list = {}
	for _, m in prof.Mail do
		local got = givePrize(player, m.Prize)
		got.From = m.From
		table.insert(list, got)
	end
	prof.Mail = {}
	mailAttrs(player, prof)
	API.reveal(player, {Kind = "Mail", Prizes = list})
	return {Ok = true}
end
function ACTIONS.OpenMail(player, prof) return openMail(player, prof) end

local function potState(prof)
	if not prof.MoonPot then return "Empty", 0, 0 end
	local total = Data.MoonPotSecs / ts()
	local p = math.clamp((os.time() - prof.MoonPot) / total, 0, 1)
	return p >= 1 and "Ready" or "Growing", p, math.max(0, math.ceil(prof.MoonPot + total - os.time()))
end
local function refreshPot(farm)
	local b = farmBits[farm]
	if not b then return end
	local prof = farm.owner and API.profiles[farm.owner]
	local state, p, left = "None", 0, 0
	if prof then state, p, left = potState(prof) end
	if b.state ~= state or (state == "Growing" and math.abs((b.p or 0) - p) > 0.02) then
		b.state, b.p = state, p
		b.plantHolder:ClearAllChildren()
		if state == "Growing" or state == "Ready" then
			local crop = Builds.Crop(p < 0.25 and "Puffberry" or "Moonflower")
			crop:ScaleTo(0.6 + p * 2.4)
			crop:PivotTo(CFrame.new(b.potTop))
			for _, d in crop:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored, d.CanCollide = true, false
				end
			end
			crop.Parent = b.plantHolder
		end
		b.glitter.Enabled = state == "Ready"
	end
	if state == "None" then
		b.potLabel.Text = "🌙 Moon Pot"
		b.prompt.Enabled = false
	elseif state == "Empty" then
		b.potLabel.Text = "🌙 Moon Pot\nPlant (free)!"
		b.prompt.ActionText, b.prompt.Enabled = "Plant 🌙", true
	elseif state == "Growing" then
		b.potLabel.Text = ("🌙 Giant crop growing\n⏱ %d:%02d:%02d"):format(left // 3600, left % 3600 // 60, left % 60)
		b.prompt.Enabled = false
	else
		b.potLabel.Text = "🌙 READY! ✨\nHarvest it!"
		b.prompt.ActionText, b.prompt.Enabled = "Harvest 🌙", true
	end
end
local function buildFarmBits(farm)
	local g = farm.ground.CFrame
	local m = Instance.new("Model")
	m.Name = "HookBits"
	-- 📬 mailbox by the gate
	local mb = g * CFrame.new(8.5, 0, -22)
	local post = P(m, {Size = Vector3.new(0.5, 3.4, 0.5), CFrame = mb * CFrame.new(0, 1.9, 0), Color = Color3.fromRGB(140, 100, 60), Material = Enum.Material.Wood})
	local box = P(m, {Name = "Box", Size = Vector3.new(1.8, 1.6, 2.6), CFrame = mb * CFrame.new(0, 4.3, 0), Color = Color3.fromRGB(80, 140, 230)})
	local lid = P(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 1.8, 1.8), CFrame = mb * CFrame.new(0, 5.1, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Color3.fromRGB(80, 140, 230)})
	-- the cozy mailbox model (ServerStorage.IslandProps) replaces the blocks; the box stays as the invisible prompt
	local props = game:GetService("ServerStorage"):FindFirstChild("IslandProps")
	local tpl = props and props:FindFirstChild("Mailbox")
	if tpl then
		local nice = tpl:Clone()
		local mp = nice.PrimaryPart or nice:FindFirstChildWhichIsA("BasePart", true)
		mp.Size = Vector3.new(2, 5.4, 3)
		mp.Anchored, mp.CanCollide = true, false
		mp.CFrame = mb * CFrame.new(0, 0.3 + 2.7, 0)
		nice.Parent = m
		post.Transparency, box.Transparency, lid.Transparency = 1, 1, 1
	end
	local flagBase = mb * CFrame.new(1.05, 4.4, 0.6)
	local hinge = P(m, {Size = Vector3.new(0.2, 0.2, 0.2), CFrame = flagBase, Transparency = 1, CanCollide = false})
	local flag = P(m, {Size = Vector3.new(0.15, 1.8, 0.7), CFrame = flagBase * CFrame.new(0, 0.9, 0), Color = Color3.fromRGB(255, 60, 60), CanCollide = false})
	local mailLabel = billboard(box, UDim2.fromOffset(170, 46), Vector3.new(0, 3, 0), 80)
	local mp = API.makePrompt(box, "📬 Open mail", "Mailbox")
	mp.Triggered:Connect(function(player)
		if farm.owner ~= player then return end
		local prof = API.profiles[player]
		if prof then
			local r = openMail(player, prof)
			if r.Error then API.toast(player, r.Error) end
		end
	end)
	-- 🌙 moon pot
	local pc = g * CFrame.new(-6, 0, -20)
	local pot = P(m, {Name = "Pot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 4.4, 4.4), CFrame = pc * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(70, 60, 140), Material = Enum.Material.SmoothPlastic})
	P(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 4.9, 4.9), CFrame = pc * CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 220, 100), Material = Enum.Material.Neon, CanCollide = false})
	P(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.9, 3.9), CFrame = pc * CFrame.new(0, 2.75, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(90, 60, 45), Material = Enum.Material.Ground, CanCollide = false})
	local holder = Instance.new("Model")
	holder.Name = "Plant"
	holder.Parent = m
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(2, 0, 0)
	att.Parent = pot
	local glitter = sparkles(att, Color3.fromRGB(200, 170, 255), 12)
	glitter.Enabled = false
	local potLabel = billboard(pot, UDim2.fromOffset(200, 60), Vector3.new(0, 5, 0), 90)
	potLabel.BackgroundColor3 = Color3.fromRGB(70, 60, 140)
	potLabel.TextColor3 = Color3.new(1, 1, 1)
	local prompt = API.makePrompt(pot, "Plant 🌙", "Moon Pot")
	prompt.Enabled = false
	prompt.Triggered:Connect(function(player)
		if farm.owner ~= player then return end
		local prof = API.profiles[player]
		if not prof then return end
		local state = potState(prof)
		if state == "Empty" then
			prof.MoonPot = os.time()
			API.toast(player, "🌙 Planted! The giant crop grows for 8 hours (even when you're away). Come back to see it!")
		elseif state == "Ready" then
			prof.MoonPot = nil
			local got = givePrize(player, API.rollWeighted(Data.MoonPotPrizes))
			API.reveal(player, {Kind = "Prize", Prize = got})
			API.notifyAll(("🌙 %s harvested a GIANT Moon Pot crop!"):format(player.DisplayName))
		end
		refreshPot(farm)
	end)
	m.Parent = farm.model
	farmBits[farm] = {flag = flag, flagHinge = hinge, flagBase = flagBase, mailLabel = mailLabel, potLabel = potLabel, plantHolder = holder, prompt = prompt,
		potTop = (pc * CFrame.new(0, 2.9, 0)).Position, glitter = glitter}
end
for _, farm in API.farms do
	if farm.ground then buildFarmBits(farm) end
end
task.spawn(function()
	while true do
		for farm in farmBits do pcall(refreshPot, farm) end
		task.wait(1)
	end
end)

---------------------------------------------------------------- ✉️ send a gift to a friend's mailbox
function ACTIONS.SendGift(player, prof, userId, itemIndex)
	local target = Players:GetPlayerByUserId(tonumber(userId) or 0)
	local item = Data.GiftItems[itemIndex]
	local tprof = target and API.profiles[target]
	if not tprof or target == player or not item then return "That player isn't here." end
	if prof.GiftDay ~= today() then prof.GiftDay, prof.GiftsSent = today(), 0 end
	if prof.GiftsSent >= Data.GiftsPerDay then return ("You sent %d gifts today. More tomorrow!"):format(Data.GiftsPerDay) end
	local prize
	if item.Kind == "Berry" then
		local slot = API.basket(player, item.Crop)
		if not slot or slot.Value < item.Amount then return ("You need %d %s."):format(item.Amount, item.Crop) end
		slot.Value -= item.Amount
		prize = {Type = "Berry", Crop = item.Crop, Amount = item.Amount, Rarity = "Common"}
	elseif item.Kind == "Seed" then
		if (prof.Seeds[item.Crop] or 0) < item.Amount then return ("You need %d %s seeds."):format(item.Amount, item.Crop) end
		API.addSeeds(player, item.Crop, -item.Amount)
		prize = {Type = "Seed", Crop = item.Crop, Amount = item.Amount, Rarity = "Common"}
	else
		local cv = API.coinsOf(player)
		if (cv and cv.Value or 0) < item.Amount then return ("You need %d coins."):format(item.Amount) end
		API.addCoins(player, -item.Amount)
		prize = {Type = "Coins", Amount = item.Amount, Rarity = "Common"}
	end
	prof.GiftsSent += 1
	table.insert(tprof.Mail, {Prize = prize, From = player.DisplayName})
	mailAttrs(target, tprof)
	API.toast(target, ("📬 %s sent you a gift! Check the mailbox on your farm."):format(player.DisplayName))
	return ("💌 Gift sent to %s!"):format(target.DisplayName)
end

---------------------------------------------------------------- 🧺 piles, 🌈 visitor, 🐾 greeting (when you come back)
local function spawnPiles(player, prof)
	local farm = API.farmOf[player]
	if not farm or (prof.Pile or 0) <= 0 then return end
	local n = math.clamp(math.ceil(prof.Pile / 40), 1, Data.PileMax)
	local each = math.floor(prof.Pile / n)
	local folder = Instance.new("Folder")
	folder.Name = "Piles"
	folder.Parent = farm.model
	for i = 1, n do
		local x, z = math.random(-9, 9), math.random(-21, -15)
		local cf = farm.ground.CFrame * CFrame.new(x, 0, z)
		local m = Instance.new("Model")
		local basket = P(m, {Name = "Basket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 2.6, 2.6),
			CFrame = cf * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(190, 140, 80), Material = Enum.Material.Fabric})
		for k = 1, 5 do
			local isCoin = k % 2 == 0
			P(m, {Shape = isCoin and Enum.PartType.Cylinder or Enum.PartType.Ball, Size = isCoin and Vector3.new(0.25, 0.9, 0.9) or Vector3.one * 0.9,
				CFrame = cf * CFrame.new(math.random(-6, 6) / 10, 2 + k * 0.25, math.random(-6, 6) / 10) * CFrame.Angles(math.random(), 0, math.random()),
				Color = isCoin and Color3.fromRGB(255, 210, 60) or Color3.fromRGB(255, 90, 110), Material = isCoin and Enum.Material.Neon or Enum.Material.SmoothPlastic,
				CanCollide = false})
		end
		sparkles(basket, Color3.fromRGB(255, 230, 120), 3)
		local prompt = API.makePrompt(basket, "🧺 Scoop!", "Goodies")
		prompt.Triggered:Connect(function(who)
			if who ~= player or not m.Parent then return end
			m:Destroy()
			prof.Pile = math.max(0, (prof.Pile or 0) - each)
			API.addCoins(player, each)
			local berry = API.basket(player, "Puffberry")
			if berry then berry.Value += 2 end
			API.toast(player, ("🧺 +%d coins  🍓 +2"):format(each))
			if #folder:GetChildren() == 0 then
				prof.Pile = 0
				folder:Destroy()
			end
		end)
		m.Parent = folder
	end
end
local function spawnVisitor(player)
	local farm = API.farmOf[player]
	if not farm then return end
	local list = {}
	for _, s in Data.Species do
		if not s.Secret and Data.Rarities[s.Rarity].Order >= 2 then
			table.insert(list, {T = s, Weight = ({Rare = 70, Epic = 25, Legendary = 5})[s.Rarity] or 1})
		end
	end
	local pick = API.rollWeighted(list)
	local c = API.spawnCritter(pick.T, nil, nil, {Quiet = true})
	if not c then return end
	c.visitor = player
	c.controlled = true
	c.leaveAt = os.clock() + 99999
	c.pos = API.farmSpot(farm)
	c.prompt.ActionText = "💖 Befriend (free!)"
	c.prompt.ObjectText = ("%s %s is visiting"):format(pick.T.Rarity, pick.T.Species)
	API.toast(player, ("🌈 A %s %s is visiting your farm! Go say hi, it wants to be your friend."):format(pick.T.Rarity, pick.T.Species))
	task.delay(600, function()
		if c.alive and c.visitor == player then API.removeCritter(c) end
	end)
end
local function greet(player)
	local n = 0
	for c in API.critters do
		if c.owner == player and c.model.Parent then
			n += 1
			task.delay(n * 0.25, function()
				if c.alive then
					c.model:SetAttribute("Trick", n % 2 == 0 and "Jump" or "Spin")
					c.model:SetAttribute("TrickAt", os.clock())
					c.model:SetAttribute("PetAt", os.clock())
				end
			end)
		end
	end
	if n > 0 then API.toast(player, "🐾 Your pets missed you! They're so happy you're back!") end
end

---------------------------------------------------------------- ⭐ golden critter dash
local function goldenDash(player)
	local hrp = hrpOf(player)
	if not hrp then return end
	local side = hrp.CFrame.RightVector * (math.random() < 0.5 and 1 or -1)
	local fwd = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	if fwd.Magnitude < 0.1 then fwd = Vector3.new(0, 0, -1) end
	fwd = fwd.Unit
	local from = hrp.Position + fwd * 10 + side * 30
	local to = hrp.Position + fwd * 10 - side * 30
	local m = Instance.new("Model")
	m.Name = "GoldenDash"
	local body = P(m, {Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, Color = Color3.fromRGB(255, 210, 60), Material = Enum.Material.Neon,
		CanCollide = false})
	for _, x in {-0.6, 0.6} do
		local ear = P(m, {Size = Vector3.new(0.4, 1.2, 0.3), Color = Color3.fromRGB(255, 240, 150), Material = Enum.Material.Neon, CanCollide = false})
		local w = Instance.new("WeldConstraint")
		ear.CFrame = body.CFrame * CFrame.new(x, 1.3, 0)
		w.Part0, w.Part1 = body, ear
		w.Parent = ear
		ear.Anchored = false
	end
	sparkles(body, Color3.fromRGB(255, 240, 150), 25)
	local prompt = API.makePrompt(body, "⭐ Catch it!", "Golden Critter")
	prompt.MaxActivationDistance = 14
	m.PrimaryPart = body
	m.Parent = workspace
	local caught = false
	prompt.Triggered:Connect(function(who)
		if caught then return end
		caught = true
		local got = givePrize(who, API.rollWeighted(Data.DashPrizes))
		API.reveal(who, {Kind = "Prize", Prize = got})
		API.toast(who, "⭐ You caught the Golden Critter!")
		m:Destroy()
	end)
	local t0, dur = os.clock(), 8
	while m.Parent and os.clock() - t0 < dur do
		local f = (os.clock() - t0) / dur
		local p = from:Lerp(to, f)
		local y = API.groundAt(p.X, p.Z) + 1.4 + math.abs(math.sin(f * 40)) * 1.2
		body.CFrame = CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(to.X, y, to.Z))
		task.wait()
	end
	if m.Parent then m:Destroy() end
end

---------------------------------------------------------------- 🧑‍🌾 helper NPCs in the plaza
local root = workspace:WaitForChild("CritterAcres")
local npcFolder = root:FindFirstChild("Helpers")
if npcFolder then npcFolder:Destroy() end
npcFolder = Instance.new("Folder")
npcFolder.Name = "Helpers"
npcFolder.Parent = root
for i, npc in Data.NPCs do
	local m = Instance.new("Model")
	m.Name = npc.Name
	m:SetAttribute("NPC", i)
	local c = CFrame.lookAt(npc.Pos, npc.Face or Vector3.new(0.01, npc.Pos.Y, 0))
	local function at(x, y, z) return c * CFrame.new(x, y, z) end
	local body
	local props = game:GetService("ServerStorage"):FindFirstChild("IslandProps")
	local tpl = npc.Model and props and props:FindFirstChild(npc.Model)
	if tpl then
		-- 🧸 the generated character model (hedgehog Fern, fox Pip, bunny Bun); invisible Body/Head keep the prompt, name tag and quest marker
		local look = tpl:Clone()
		look.Name = "Look"
		local mp = look.PrimaryPart or look:FindFirstChildWhichIsA("BasePart", true)
		for _, d in look:GetDescendants() do
			if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery = true, false, false end
		end
		local _, size = look:GetBoundingBox()
		look:ScaleTo(look:GetScale() * 6.5 / math.max(0.1, size.Y))
		look:PivotTo(c)
		local cfb, bs = look:GetBoundingBox()
		look:PivotTo(look:GetPivot() + Vector3.new(0, (npc.Pos.Y + 0.2) - (cfb.Y - bs.Y / 2), 0))
		look.Parent = m
		body = P(m, {Name = "Body", Size = Vector3.new(2.6, 5, 2.6), CFrame = at(0, 2.7, 0), Transparency = 1})
		P(m, {Name = "Head", Size = Vector3.one * 1, CFrame = at(0, 5.6, 0), Transparency = 1, CanCollide = false})
		if mp then mp.CanQuery = false end
	else
		body = P(m, {Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 2.6, 2.6), CFrame = at(0, 1.9, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = npc.Color})
		P(m, {Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = at(0, 4.6, 0), Color = Color3.fromRGB(255, 220, 185)})
		for _, x in {-0.4, 0.4} do
			P(m, {Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, CFrame = at(x, 4.8, -1.0), Color = Color3.fromRGB(40, 30, 30)})
		end
		P(m, {Size = Vector3.new(0.6, 0.15, 0.1), CFrame = at(0, 4.25, -1.05), Color = Color3.fromRGB(200, 90, 90)})
		P(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.2, 3.2), CFrame = at(0, 5.6, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = npc.Color:Lerp(Color3.new(0, 0, 0), 0.25)})
		P(m, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 1.9, 1.9), CFrame = at(0, 6.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = npc.Color:Lerp(Color3.new(0, 0, 0), 0.25)})
	end
	local label = billboard(m.Head, UDim2.fromOffset(200, 50), Vector3.new(0, 3.6, 0), 120)
	label.Text = npc.Icon .. " " .. npc.Name
	label.BackgroundColor3 = npc.Color
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	local prompt = API.makePrompt(body, "💬 Talk", npc.Name)
	prompt.Name = "TalkPrompt" -- the client opens the quest window from it
	m.PrimaryPart = body
	m.Parent = npcFolder
end

---------------------------------------------------------------- 💪 Farm Power + state for the client
local function farmPower(prof)
	local pets = {}
	for _, rec in prof.Pets do
		table.insert(pets, {Rarity = Data.SpeciesByName[rec.Species].Rarity, Level = API.petLevel(rec), Variant = rec.Variant})
	end
	local soil = 0
	for _, lv in prof.Soil or {} do soil += (tonumber(lv) or 1) - 1 end
	local gear = 0
	for _, g in prof.Gear or {} do gear += (g.Tier or 1) * (1 + (g.Level or 0)) end
	return Data.FarmPower({Pets = pets, Decor = #(prof.Decor or {}), Plots = prof.PlotsOpen or Data.StartPlots, Soil = soil, Tool = prof.Tool or 0, Gear = gear})
end
table.insert(API.stateHooks, function(player, prof, st)
	if prof.NPCQ then
		local list = {}
		for i, npc in Data.NPCs do
			local q = prof.NPCQ[i]
			local s = npc.Chain[q.Step]
			list[i] = {Step = q.Step, Ready = s ~= nil and q.Prog >= s.Count, Done = s == nil}
		end
		st.NPC = list
	end
end)

---------------------------------------------------------------- joining
local function onProfile(player)
	local prof
	for _ = 1, 60 do
		prof = API.profiles[player]
		if prof then break end
		task.wait(0.5)
	end
	if not prof or not player.Parent then return end
	local away = (prof.LastOnline or 0) > 0 and os.time() - prof.LastOnline or 0
	-- defaults (older saves)
	if not prof.Journey then
		local veteran = #prof.Pets >= 3 or (prof.FarmXp or 0) >= 150
		prof.Journey = {Step = veteran and #Data.Journey + 1 or 1, Prog = 0}
	end
	prof.Cal = prof.Cal or {Got = 0, Day = -1}
	prof.Mail = prof.Mail or {}
	prof.NPCQ = prof.NPCQ or {}
	for i in Data.NPCs do prof.NPCQ[i] = prof.NPCQ[i] or {Step = 1, Prog = 0} end
	prof.GiftsSent = prof.GiftsSent or 0
	sessionStart[player] = os.time()
	playGot[player] = {}
	playAttrs(player)
	journeyAttrs(player, prof)
	calAttrs(player, prof)
	API.badge(player, "Welcome")
	-- 📬 a gift when you come back after a while
	if away >= Data.MailAwaySecs then
		table.insert(prof.Mail, {Prize = API.rollWeighted(Data.MailGifts), From = "Critter Post"})
	end
	-- 💪 power on the player list
	local ls = player:WaitForChild("leaderstats", 10)
	local pow
	if ls then
		pow = Instance.new("IntValue")
		pow.Name = "💪 Power"
		pow.Parent = ls
	end
	task.wait(2.5) -- let the farm and pets appear first
	if not player.Parent then return end
	mailAttrs(player, prof)
	spawnPiles(player, prof)
	if away >= 120 then greet(player) end
	if away >= Data.VisitorAwaySecs and math.random() < Data.VisitorChance then spawnVisitor(player) end
	refreshFriends()
	-- per-player loops: power, golden dash, explore detection
	task.spawn(function()
		local nextDash = os.clock() + math.random(Data.DashGap[1], Data.DashGap[2])
		local lastBiome
		while player.Parent do
			local power = farmPower(prof)
			player:SetAttribute("FarmPower", power)
			if pow then pow.Value = power end
			if os.clock() > nextDash then
				nextDash = os.clock() + math.random(Data.DashGap[1], Data.DashGap[2])
				if not workspace:GetAttribute("Event") then task.spawn(goldenDash, player) end
			end
			local hrp = hrpOf(player)
			if hrp then
				local biome
				local x, z = hrp.Position.X, hrp.Position.Z
				for name, b in Data.GateBounds do
					if x > b[1] and x < b[3] and z > b[2] and z < b[4] then biome = name end
				end
				if not biome and z < -45 and z > -205 and math.abs(x) < 110 then biome = "Meadow" end
				if biome and biome ~= lastBiome then API.questEvent(player, "Explore", 1) end
				lastBiome = biome or (lastBiome and nil)
			end
			task.wait(2)
		end
	end)
	-- the pile and moon pot follow your farm (if you got a farm late)
	refreshPot(API.farmOf[player] or {})
end
Players.PlayerAdded:Connect(onProfile)
for _, p in Players:GetPlayers() do task.spawn(onProfile, p) end
Players.PlayerRemoving:Connect(function(p)
	sessionStart[p] = nil
	playGot[p] = nil
	local farm = API.farmOf[p]
	if farm and farm.model:FindFirstChild("Piles") then farm.model.Piles:Destroy() end
end)

---------------------------------------------------------------- dev helpers
local DEV_EXTRA = {
	Journey = function(player, prof)
		prof.Journey = {Step = 1, Prog = 0}
		journeyAttrs(player, prof)
		return "Journey restarted"
	end,
	PlayGifts = function(player, prof)
		sessionStart[player] = os.time() - 3700
		playAttrs(player)
		return "All playtime gifts are ready"
	end,
	Calendar = function(player, prof)
		prof.Cal.Day = -1
		calAttrs(player, prof)
		return "Calendar box ready"
	end,
	Mail = function(player, prof)
		table.insert(prof.Mail, {Prize = API.rollWeighted(Data.MailGifts), From = "Critter Post"})
		mailAttrs(player, prof)
		return "📬 Mail added"
	end,
	Pile = function(player, prof)
		prof.Pile = 300
		spawnPiles(player, prof)
		return "🧺 Piles on your farm"
	end,
	Visitor = function(player) spawnVisitor(player) return "🌈 Visitor on your farm" end,
	Dash = function(player) task.spawn(goldenDash, player) return "⭐ Golden dash" end,
	MoonPot = function(player, prof)
		prof.MoonPot = os.time() - Data.MoonPotSecs
		return "🌙 Moon Pot ready"
	end,
}
API.DEV_EXTRA = API.DEV_EXTRA or {}
for k, fn in DEV_EXTRA do API.DEV_EXTRA[k] = fn end

print("[Hooks] ready")
