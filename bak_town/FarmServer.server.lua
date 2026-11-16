-- Critter Acres: FarmServer (ServerScriptService)
-- Farm loop, seed tiers, wild critters with RNG catching, pet jobs and levels,
-- saving, offline earnings, expeditions, eggs, collection book, weather,
-- critter of the day, golden harvests, daily quests and login streaks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI")) -- hats for critters without a 3D model
local Builds = require(ReplicatedStorage:WaitForChild("Builds")) -- fruit shapes
local API = require(script.Parent:WaitForChild("CritterAPI")) -- shared with WorldEvents / ShopServer / CraftServer / FunServer
local CROPS, CROP = Data.Crops, Data.CropByName

local CONFIG = {
	StartCoins = 10,
	StandSellBonus = 1.5, -- sell multiplier for players who built the Fruit Stand
	BaseCritterCap = 3,
	HutBonus = 5,
	WildMax = 4,
	WildSpawnEvery = 10,
	WildStay = {Common = 180, Rare = 150, Epic = 110, Legendary = 70},
	JobPause = 1.2,
	BoostCooldown = 5,
	AutosaveEvery = 90,
	StoreName = "CritterAcres_v1",
	-- flying critters (Species with Flyer = true)
	FlyClimb = 11, -- studs per second going up
	FlySink = 7, -- studs per second coming down
	FlyTurnRate = 1.3, -- radians per second (smaller = wider curves)
	FlyBob = 3, -- studs it rises and dips while cruising
	FlySpeedMult = 1.8, -- faster in the air
	FlyHeight = {22, 36}, -- cruising height range
	FlyHops = {3, 5}, -- waypoints flown before landing
	LandStay = {15, 35}, -- seconds on the ground before taking off again
}
-- Set workspace attribute CritterTimeScale (e.g. 60) in Studio to speed up trips and eggs for testing.
local function timeScale() return workspace:GetAttribute("CritterTimeScale") or 1 end
local function today() return math.floor(os.time() / 86400) end

local root = workspace:WaitForChild("CritterAcres")
local padsFolder = root:WaitForChild("BuildPads")
local counter = root:WaitForChild("SellStand"):WaitForChild("Counter")
local meadow = root:WaitForChild("Meadow")
local GROUND_Y = root:GetAttribute("GroundY") or 0

local critterFolder = Instance.new("Folder")
critterFolder.Name = "Critters"
critterFolder.Parent = root

local function remote(class, name)
	local r = Instance.new(class)
	r.Name = name
	r.Parent = ReplicatedStorage
	return r
end
local notify = remote("RemoteEvent", "CritterNotify")
local stateEvent = remote("RemoteEvent", "CritterState")
local actionFn = remote("RemoteFunction", "CritterAction")
local revealEvent = remote("RemoteEvent", "CritterReveal") -- picture popups: prizes, level ups

local function toast(player, text)
	if player and player.Parent then notify:FireClient(player, text) end
end

local function stat(player, name)
	local ls = player and player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild(name)
end

local function basket(player, cropName)
	local b = player and player:FindFirstChild("Basket")
	return b and b:FindFirstChild(cropName)
end

local function addCoins(player, n)
	local c = stat(player, "Coins")
	if c then c.Value += n end
end

local function makePrompt(parent, action, object)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object or ""
	p.HoldDuration = 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function pop(adornee, text)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(50, 50)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = adornee
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.Text = text
	t.Parent = bb
	bb.Parent = adornee
	TweenService:Create(bb, TweenInfo.new(1), {StudsOffset = Vector3.new(0, 5, 0)}):Play()
	TweenService:Create(t, TweenInfo.new(1), {TextTransparency = 1}):Play()
	task.delay(1.1, function() bb:Destroy() end)
end

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end

---------------------------------------------------------------- daily helpers
local function critterOfDay()
	return Data.Species[today() % #Data.Species + 1]
end

local function makeQuests(day, userId)
	local rng = Random.new(day * 7919 + userId % 100000)
	local pool = table.clone(Data.QuestPool)
	local list = {}
	for _ = 1, 3 do
		local q = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, {Kind = q.Kind, Count = q.Count, Reward = q.Reward, Text = q.Text:format(q.Count), Progress = 0, Claimed = false})
	end
	return list
end

---------------------------------------------------------------- profiles (saving)
local store
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore(CONFIG.StoreName) end)
	store = ok and s or nil
end
local profiles = {} -- [player] = profile table
local canSave = {} -- [player] = true when loading worked

local function defaultProfile()
	local b = {}
	for _, c in CROPS do b[c.Name] = 0 end
	return {Coins = CONFIG.StartCoins, Basket = b, Seed = CROPS[1].Name, Pets = {}, Found = {}, Eggs = {}, Built = {},
		Streak = 0, LastDay = 0, Quests = nil, QuestDay = 0, LastOnline = 0, NextId = 1,
		Gear = {}, Energy = Data.EnergyMax, EnergyAt = 0,
		Outfits = {[Data.StarterOutfit] = true}, Spins = 1, FarmXp = 0, FollowId = nil, FoundShiny = {},
		Plots = {}, Special = {}, Likes = 0, LikedToday = {}, LikeDay = 0,
		Seeds = {}, Workers = {}, WorkSlots = Data.WorkSlots, FreePacks = 1, SeedBook = {}, SeedRows = {}, Bell = false,
		ShopEpoch = 0, ShopBought = {},
		Res = {}, Tool = 0, PlotsOpen = Data.StartPlots, Soil = {}, Decor = {}, DecorInv = {}, Toys = {["Bubble Wand"] = true},
		Titles = {["Little Farmer"] = true}, Title = "Little Farmer", Acorns = {}, Hatched = 0, Visited = {}, Best = {}}
end

local function loadProfile(player)
	local prof, data, ok = defaultProfile(), nil, false
	if store then
		for _ = 1, 3 do
			ok = pcall(function() data = store:GetAsync("p_" .. player.UserId) end)
			if ok then break end
			task.wait(1)
		end
	end
	if type(data) == "table" then
		for k, v in data do prof[k] = v end
		for _, c in CROPS do prof.Basket[c.Name] = prof.Basket[c.Name] or 0 end
	end
	return prof, ok
end

local beforeSave -- set in the farms section: copies the farm's plots into the profile
local function saveProfile(player)
	local prof = profiles[player]
	if not prof or not canSave[player] or not store then return end
	local coins = stat(player, "Coins")
	if coins then prof.Coins = coins.Value end
	for _, c in CROPS do
		local slot = basket(player, c.Name)
		if slot then prof.Basket[c.Name] = slot.Value end
	end
	prof.Seed = player:GetAttribute("Seed") or prof.Seed
	if beforeSave then beforeSave(player, prof) end
	prof.LastOnline = os.time()
	local ok, err = pcall(function() store:SetAsync("p_" .. player.UserId, prof) end)
	if not ok then warn("[CritterAcres] save failed for", player.Name, err) end
end

-- one pet family: every pet can work AND fight. You can own Data.PetCap pets; only FarmPetCap(level) are out on
-- your farm at once, the rest wait in 📦 storage (rec.Stored).
local function capFor(player, role)
	return Data.PetCap
end
local function countRole(prof, role)
	return #prof.Pets
end

local function petLevel(rec)
	return math.min(Data.MaxLevel, 1 + math.floor((rec.Xp or 0) / Data.XpPerLevel))
end

local function isResting(rec)
	return rec.RestUntil ~= nil and os.time() < rec.RestUntil
end

-- Happiness drops slowly over time (also while you're away); petting and feeding fill it up.
local function happiness(rec)
	local h = (rec.Happy or Data.HappyStart) - (os.time() - (rec.HappyAt or os.time())) / Data.HappyDecaySecs
	return math.clamp(h, 0, 100)
end
local function setHappy(rec, value)
	rec.Happy = math.clamp(value, 0, 100)
	rec.HappyAt = os.time()
end
local function moodOf(rec)
	local h = happiness(rec)
	return h >= Data.HappyHigh and "Happy" or (h < Data.HappyLow and "Sad" or nil)
end
local function variantMult(rec)
	local v = rec and rec.Variant and Data.VariantByName[rec.Variant]
	return v and v.Mult or 1
end

local function findGear(prof, id)
	if not id then return nil end
	for i, g in prof.Gear do
		if g.Id == id then return g, i end
	end
end

local function petStats(prof, rec)
	local T = Data.SpeciesByName[rec.Species]
	local s = Data.BattleStats(T, petLevel(rec), findGear(prof, rec.GearId))
	local mult = variantMult(rec) * (moodOf(rec) == "Happy" and 1.1 or 1) * (rec.Grown and Data.GrownBonus or 1) -- shiny, happy, raised
	s.HP, s.ATK = math.floor(s.HP * mult), math.floor(s.ATK * mult)
	return s
end

-- Energy refills 1 per EnergyRegenSecs (sped up by CritterTimeScale in Studio tests).
local function updateEnergy(prof)
	local step = Data.EnergyRegenSecs / timeScale()
	local now = os.time()
	if prof.Energy >= Data.EnergyMax then
		prof.EnergyAt = now
		return
	end
	local gained = math.floor((now - prof.EnergyAt) / step)
	if gained > 0 then
		prof.Energy = math.min(Data.EnergyMax, prof.Energy + gained)
		prof.EnergyAt = prof.Energy >= Data.EnergyMax and now or prof.EnergyAt + gained * step
	end
end

local afterPush -- set by the incubator section: refreshes the eggs on your farm's nest
local growCheck -- set by the growing-up section
local function pushState(player)
	local prof = profiles[player]
	if not prof then return end
	updateEnergy(prof)
	local pets = {}
	local lv = Data.FarmLevel(prof.FarmXp or 0)
	for _, rec in prof.Pets do
		local T = Data.SpeciesByName[rec.Species]
		if growCheck then growCheck(player, prof, rec) end
		local stats = petStats(prof, rec)
		local stage = Data.StageOf(rec, petLevel(rec))
		table.insert(pets, {Id = rec.Id, Species = rec.Species, Rarity = T.Rarity, JobText = T.JobText, Level = petLevel(rec),
			Role = T.Role, Class = T.Class, GearId = rec.GearId, Stats = stats, Power = stats and Data.Power(stats) or nil,
			Xp = rec.Xp or 0, Rest = isResting(rec) and {From = rec.RestFrom, Until = rec.RestUntil} or nil,
			Happy = math.floor(happiness(rec)), Variant = rec.Variant, SizeName = rec.SizeName, Outfit = rec.Outfit,
			Follow = prof.FollowId == rec.Id or nil, Name = rec.Name, Stored = rec.Stored, Stage = stage and stage.Name or nil,
			Grown = rec.Grown, Fav = rec.FavKnown and Data.FavFood(rec) or nil, Odds = rec.Odds, Nest = rec.NestUntil, NestRest = rec.NestRest,
			Riding = rec.Riding, Tint = rec.Tint, Job = T.Job,
			Energy = math.floor(rec.Energy or 100), Working = table.find(prof.Workers or {}, rec.Id) ~= nil, Nap = rec.NapUntil, Bench = rec.Bench,
			Trip = rec.Trip and {Index = rec.Trip.Index, Name = Data.Expeditions[rec.Trip.Index].Name, ReturnAt = rec.Trip.ReturnAt} or nil})
	end
	local gear = {}
	for _, g in prof.Gear do
		local wornBy
		for _, rec in prof.Pets do
			if rec.GearId == g.Id then wornBy = rec.Species end
		end
		table.insert(gear, {Id = g.Id, Kind = g.Kind, Tier = g.Tier or 1, Level = g.Level or 0, Luck = g.Luck, Rarity = g.Rarity,
			Text = Data.GearText(g), WornBy = wornBy})
	end
	local step = Data.EnergyRegenSecs / timeScale()
	local onFarm = 0
	for _, rec in prof.Pets do
		if not rec.Stored then onFarm += 1 end
	end
	local st = {
		Pets = pets, Eggs = prof.Eggs, Found = prof.Found, Quests = prof.Quests, Streak = prof.Streak,
		Built = prof.Built, WorkerCap = capFor(player, "Worker"), BattlerCap = capFor(player, "Battler"),
		CritterOfDay = critterOfDay().Species, Now = os.time(), Gear = gear,
		Energy = prof.Energy, EnergyNextAt = prof.Energy < Data.EnergyMax and math.ceil(prof.EnergyAt + step) or nil,
		Outfits = prof.Outfits, FoundShiny = prof.FoundShiny, WorkSlots = prof.WorkSlots, FreePacks = prof.FreePacks,
		PetCap = Data.PetCap, FarmCap = Data.FarmPetCap(lv), OnFarm = onFarm, Luck = prof.Luck or 0,
	}
	for _, fn in API.stateHooks or {} do pcall(fn, player, prof, st) end
	stateEvent:FireClient(player, st)
	player:SetAttribute("Luck", prof.Luck or 0)
	if afterPush then afterPush(player, prof) end
	player:SetAttribute("Spins", prof.Spins)
	player:SetAttribute("CritterCap", capFor(player, "Worker"))
	player:SetAttribute("WorkerCount", countRole(prof, "Worker"))
	player:SetAttribute("BattlerCount", countRole(prof, "Battler"))
	local count = stat(player, "Critters")
	if count then count.Value = #prof.Pets end
end

local function questEvent(player, kind, n)
	local prof = profiles[player]
	if not prof then return end
	for _, fn in API.questHooks or {} do task.spawn(fn, player, prof, kind, n) end
	if not prof.Quests then return end
	local changed = false
	for _, q in prof.Quests do
		if q.Kind == kind and not q.Claimed and q.Progress < q.Count then
			q.Progress = math.min(q.Count, q.Progress + n)
			changed = true
			if q.Progress >= q.Count then toast(player, ("Quest done: %s! Claim it in Quests."):format(q.Text)) end
		end
	end
	if changed then pushState(player) end
end

---------------------------------------------------------------- farm level
-- Level, XP and next-level XP live in player attributes so the HUD bar updates without a full state push.
local function farmAttrs(player, prof)
	local lv, cur, nxt = Data.FarmLevel(prof.FarmXp)
	player:SetAttribute("FarmLevel", lv)
	player:SetAttribute("FarmXp", prof.FarmXp - cur)
	player:SetAttribute("FarmXpNext", nxt and nxt - cur or nil)
	return lv
end
local function farmLevelOf(player)
	local prof = profiles[player]
	return prof and Data.FarmLevel(prof.FarmXp) or 1
end
local function addFarmXp(player, n)
	local prof = player and profiles[player]
	if not prof or n <= 0 then return end
	local before = Data.FarmLevel(prof.FarmXp)
	prof.FarmXp += n
	local after = farmAttrs(player, prof)
	if after > before then
		local unlocked = {}
		for lv = before + 1, after do
			for _, c in CROPS do
				if c.Unlock == lv then table.insert(unlocked, c.Name) end
			end
		end
		local coins = Data.FarmLevelCoins * after
		addCoins(player, coins)
		prof.Spins += after - before
		revealEvent:FireClient(player, {Kind = "LevelUp", Level = after, Coins = coins, Unlocked = unlocked, Spins = after - before})
		pushState(player)
	end
end

---------------------------------------------------------------- seeds you own (player attributes Seed_<name> for the HUD)
local function setSeedAttr(player, prof, name)
	player:SetAttribute(Data.SeedAttr(name), prof.Seeds[name] or 0)
end
local function addSeeds(player, name, n)
	local prof = profiles[player]
	if not prof or not CROP[name] then return end
	prof.Seeds[name] = math.max(0, (prof.Seeds[name] or 0) + n)
	setSeedAttr(player, prof, name)
end

---------------------------------------------------------------- resources (player attributes Res_<name> for the HUD)
local function setResAttr(player, prof, name)
	player:SetAttribute("Res_" .. name, prof.Res[name] or 0)
end
local function addRes(player, name, n)
	local prof = profiles[player]
	if not prof or not Data.ResByName[name] then return end
	prof.Res[name] = math.max(0, (prof.Res[name] or 0) + n)
	setResAttr(player, prof, name)
end
-- cost = {Coins = 60, Wood = 8, ...}
local function canPay(player, prof, cost)
	local coins = stat(player, "Coins")
	if (cost.Coins or 0) > (coins and coins.Value or 0) then return false, "💰" end
	for _, r in Data.Resources do
		if (cost[r.Name] or 0) > (prof.Res[r.Name] or 0) then return false, r.Icon end
	end
	return true
end
local function pay(player, prof, cost)
	local ok, missing = canPay(player, prof, cost)
	if not ok then return false, missing end
	if cost.Coins then stat(player, "Coins").Value -= cost.Coins end
	for _, r in Data.Resources do
		if cost[r.Name] then addRes(player, r.Name, -cost[r.Name]) end
	end
	return true
end
local function giveTitle(player, name)
	if API.giveTitle then API.giveTitle(player, name) end
end

---------------------------------------------------------------- eggs: only IncubatorSlots hatch at once, the rest wait
local function startEggs(prof)
	local busy = 0
	for _, e in prof.Eggs do
		if e.HatchAt then busy += 1 end
	end
	for _, e in prof.Eggs do
		if busy >= Data.IncubatorSlots then break end
		if not e.HatchAt then
			e.HatchAt = os.time() + math.ceil((e.Secs or Data.EggHatchSecs) / timeScale())
			busy += 1
		end
	end
end
local function addEgg(prof, kind, extra)
	local e = {Id = prof.NextId, Kind = kind}
	for k, v in extra or {} do e[k] = v end
	table.insert(prof.Eggs, e)
	prof.NextId += 1
	startEggs(prof)
end

---------------------------------------------------------------- prizes (spins, presents, pet gifts)
local function rollWeighted(list)
	local total = 0
	for _, p in list do total += p.Weight end
	local r = math.random() * total
	for i, p in list do
		r -= p.Weight
		if r <= 0 then return p, i end
	end
	return list[1], 1
end

local function rollOutfit()
	local rarity
	do
		local total = 0
		for _, w in Data.OutfitWeights do total += w end
		local r = math.random() * total
		for k, w in Data.OutfitWeights do
			r -= w
			if r <= 0 then rarity = k break end
		end
	end
	local options = {}
	for _, o in Data.Outfits do
		if o.Rarity == rarity and not o.Limited then table.insert(options, o) end
	end
	if #options == 0 then options = {Data.Outfits[1]} end
	return options[math.random(#options)]
end

-- Gives a prize and returns a picture-friendly copy of what was actually won.
local function grant(player, prize)
	local prof = profiles[player]
	local got = table.clone(prize)
	got.Weight = nil
	if prize.Type == "Coins" then
		addCoins(player, prize.Amount)
	elseif prize.Type == "Berry" then
		local slot = basket(player, prize.Crop)
		if slot then slot.Value += prize.Amount end
	elseif prize.Type == "Egg" then
		local kind = prize.Kind
		if Data.Eggs[kind] and Data.Eggs[kind].Limited and not Data.SeasonalOn() then kind = "Mystery" end
		got.Kind = kind
		addEgg(prof, kind)
	elseif prize.Type == "Seed" then
		addSeeds(player, prize.Crop, prize.Amount or 1)
	elseif prize.Type == "Res" then
		addRes(player, prize.Res, prize.Amount or 1)
	elseif prize.Type == "Outfit" then
		local o = prize.Name and Data.OutfitByName[prize.Name] or rollOutfit()
		got.Name, got.Rarity = o.Name, o.Rarity
		if prof.Outfits[o.Name] then -- already have it: coins instead
			got.Dup = Data.OutfitDupCoins[o.Rarity]
			addCoins(player, got.Dup)
		else
			prof.Outfits[o.Name] = true
		end
	elseif prize.Type == "Spin" then
		prof.Spins += prize.Amount
	end
	return got
end

---------------------------------------------------------------- weather state
local weather = nil -- current weather name or nil
local devWeather = nil -- set by the Studio dev menu to start a weather event now

---------------------------------------------------------------- buildings (owned per player, shown if anyone here owns it)
local BUILDERS = {}
function BUILDERS.CritterHut(pad, model) -- a round mushroom hut
	local base = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
	part(model, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 9, 9), CFrame = CFrame.new(base + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(250, 235, 205)})
	local cap = part(model, {Size = Vector3.new(13, 5, 13), Position = base + Vector3.new(0, 7, 0), Color = Color3.fromRGB(235, 80, 80)})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = cap
	for i = 0, 5 do
		local a = i * math.pi / 3
		part(model, {Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CanCollide = false,
			Position = base + Vector3.new(math.cos(a) * 4.3, 8.2, math.sin(a) * 4.3), Color = Color3.new(1, 1, 1)})
	end
	part(model, {Size = Vector3.new(2.6, 4, 0.4), Position = base + Vector3.new(0, 2, 4.4), Color = Color3.fromRGB(140, 90, 60)})
end
function BUILDERS.FruitStand(pad, model) -- striped fruit stand
	local base = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
	part(model, {Size = Vector3.new(10, 3, 4), Position = base + Vector3.new(0, 1.5, 0), Color = Color3.fromRGB(200, 140, 90), Material = Enum.Material.Wood})
	for _, x in {-4.6, 4.6} do
		part(model, {Size = Vector3.new(0.5, 7, 0.5), Position = base + Vector3.new(x, 3.5, -1.6), Color = Color3.new(1, 1, 1)})
	end
	for i = 0, 4 do
		part(model, {Size = Vector3.new(2.2, 0.5, 5), Position = base + Vector3.new(-4.4 + i * 2.2, 7.2, 0),
			Color = i % 2 == 0 and Color3.fromRGB(120, 200, 255) or Color3.new(1, 1, 1)})
	end
	for i = -3, 3 do
		part(model, {Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, CanCollide = false, Position = base + Vector3.new(i * 1.3, 3.5, 0),
			Color = CROPS[(i + 3) % #CROPS + 1].Color})
	end
end

local padByKind = {}
local function showBuilding(kind)
	local pad = padByKind[kind]
	if not pad or root:FindFirstChild(kind) then return end
	local s = pad:FindFirstChild("Sign")
	if s then s:Destroy() end
	local model = Instance.new("Model")
	model.Name = kind
	BUILDERS[kind](pad, model)
	model.Parent = root
end

for _, pad in padsFolder:GetChildren() do
	local kind, cost, label, perk = pad:GetAttribute("Building"), pad:GetAttribute("Cost"), pad:GetAttribute("Label"), pad:GetAttribute("Perk")
	padByKind[kind] = pad
	local prompt = makePrompt(pad, ("Build %s (%d coins)"):format(label, cost), perk)
	prompt.MaxActivationDistance = 12
	prompt.Triggered:Connect(function(player)
		local prof = profiles[player]
		if not prof then return end
		if prof.Built[kind] then
			toast(player, ("You already own the %s. %s!"):format(label, perk))
			return
		end
		local coins = stat(player, "Coins")
		if coins.Value < cost then
			toast(player, ("You need %d coins to build the %s."):format(cost, label))
			return
		end
		coins.Value -= cost
		prof.Built[kind] = true
		showBuilding(kind)
		pushState(player)
		notify:FireAllClients(("%s built the %s! %s."):format(player.DisplayName, label, perk))
	end)
end

---------------------------------------------------------------- personal farms
-- Each player gets one of the farms around the plaza (CritterAcres.Farms, built by BuildWorld.lua):
-- 9 plots, a sign with their name, a ❤️ like heart, a sell bin. Crops are saved and keep growing offline.
local DRY, WET = Color3.fromRGB(150, 100, 62), Color3.fromRGB(96, 62, 40)
local SPROUT = Color3.fromRGB(110, 200, 90)
local farmsFolder = root:WaitForChild("Farms")
local farms = {} -- {model, ground, home, plots = {part...}, sign, owner}
local farmOf = {} -- player -> farm
local plotFarm = {} -- plot part -> farm
local plots = {} -- every plot of every farm

local function getMuts(plot)
	local s = plot:GetAttribute("Muts")
	if not s or s == "" then return {} end
	return string.split(s, ",")
end
local function hasMut(plot, name)
	return table.find(getMuts(plot), name) ~= nil
end
local function addMut(plot, name)
	if not Data.MutationByName[name] or hasMut(plot, name) then return false end
	local list = getMuts(plot)
	table.insert(list, name)
	plot:SetAttribute("Muts", table.concat(list, ","))
	return true
end

-- crop look: grows from a sprout, mutations change its color/material and add glitter, size scales it up
local MUT_FX = {
	Juicy = {Material = Enum.Material.Glass, Tint = Color3.fromRGB(110, 190, 255)},
	Golden = {Material = Enum.Material.SmoothPlastic, Tint = Color3.fromRGB(255, 205, 50), Reflectance = 0.35},
	Frosty = {Material = Enum.Material.Ice, Tint = Color3.fromRGB(200, 240, 255)},
	Starry = {Material = Enum.Material.Neon, Tint = Color3.fromRGB(190, 160, 255)},
	Zapped = {Material = Enum.Material.Neon, Tint = Color3.fromRGB(255, 250, 130)},
	Prismatic = {Material = Enum.Material.Neon, Tint = Color3.fromRGB(255, 140, 230)},
}
-- Fruit trees: a trunk and a leafy top that grow, then fruit that ripens again and again.
local function updateTree(plot, info, state)
	local tree = plot:FindFirstChild("Tree")
	if not tree then
		tree = Instance.new("Model")
		tree.Name = "Tree"
		part(tree, {Name = "Trunk", Size = Vector3.new(1, 1, 1), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood, CanCollide = false, CanQuery = false})
		part(tree, {Name = "Top", Shape = Enum.PartType.Ball, Size = Vector3.one, Color = Color3.fromRGB(70, 160, 70), Material = Enum.Material.Grass,
			CanCollide = false, CanQuery = false})
		tree.Parent = plot
	end
	local mature = plot:GetAttribute("Mature")
	local prog = plot:GetAttribute("Progress") or 0
	local grow = mature and 1 or (state == "Ready" and 1 or 0.25 + 0.75 * prog)
	local h = 7 * grow
	local base = plot.Position + Vector3.new(0, plot.Size.Y / 2, 0)
	tree.Trunk.Size = Vector3.new(0.9 * grow + 0.2, h, 0.9 * grow + 0.2)
	tree.Trunk.Position = base + Vector3.new(0, h / 2, 0)
	local topSize = 6 * grow
	tree.Top.Size = Vector3.one * topSize
	tree.Top.Position = base + Vector3.new(0, h + topSize * 0.25, 0)
	-- fruit: tiny while growing back, full (and maybe XL/MEGA) when ready
	local ready = state == "Ready"
	local sizeInfo = ready and Data.CropSizeByName[plot:GetAttribute("Size") or ""]
	local fruitSize = (mature or ready) and (ready and 1.3 * (sizeInfo and math.sqrt(sizeInfo.Scale) or 1) or 0.3 + 0.8 * prog) or 0
	for i = 1, 4 do -- the fruit hanging on the tree are little copies of the real fruit model
		local f = tree:FindFirstChild("Fruit" .. i)
		if fruitSize <= 0 then
			if f then f:Destroy() end
		else
			if not f then
				f = Builds.Crop(info.Name)
				f.Name = "Fruit" .. i
				f.Parent = tree
			end
			if math.abs(f:GetScale() - fruitSize) > 0.02 then f:ScaleTo(fruitSize) end
			local a = i * math.pi / 2 + 0.4
			f:PivotTo(CFrame.new(tree.Top.Position + Vector3.new(math.cos(a) * topSize * 0.42, -topSize * 0.2 + (i % 2) * 0.8, math.sin(a) * topSize * 0.42)))
		end
	end
	return tree
end

local function updateCrop(plot)
	local state = plot:GetAttribute("State")
	local crop = plot:FindFirstChild("Crop")
	if state == "Empty" then
		if crop then crop:Destroy() end
		local tree = plot:FindFirstChild("Tree")
		if tree then tree:Destroy() end
		local look = plot:FindFirstChild("Look")
		if look then look:Destroy() end
		return
	end
	local info = CROP[plot:GetAttribute("Crop")]
	if info.Tree then
		local tree = updateTree(plot, info, state)
		-- an invisible marker carries the glitter and badge, so mutations work the same as other crops
		if not crop then
			crop = part(plot, {Name = "Crop", Size = Vector3.one, Transparency = 1, CanCollide = false, CanQuery = false})
		end
		crop.Position = tree.Top.Position
		local muts = getMuts(plot)
		local fx = MUT_FX[muts[#muts]]
		for i = 1, 4 do -- mutation tint on the hanging fruit
			local f = tree:FindFirstChild("Fruit" .. i)
			if f then
				for _, d in f:GetChildren() do
					if d.Name == "Fruit" then
						if not d:GetAttribute("C0") then
							d:SetAttribute("C0", d.Color)
							d:SetAttribute("M0", d.Material.Name)
						end
						d.Color = fx and fx.Tint:Lerp(d:GetAttribute("C0"), 0.3) or d:GetAttribute("C0")
						d.Material = fx and fx.Material or Enum.Material[d:GetAttribute("M0")]
					end
				end
			end
		end
		local sizeInfo = state == "Ready" and Data.CropSizeByName[plot:GetAttribute("Size") or ""]
		local special = #muts > 0 or sizeInfo
		local glitter = crop:FindFirstChild("Glitter")
		if special and not glitter then
			glitter = Instance.new("ParticleEmitter")
			glitter.Name = "Glitter"
			glitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			glitter.LightEmission = 1
			glitter.Size = NumberSequence.new(0.6, 0)
			glitter.Lifetime = NumberRange.new(0.8, 1.2)
			glitter.Speed = NumberRange.new(1, 2)
			glitter.SpreadAngle = Vector2.new(180, 180)
			glitter.Parent = crop
		end
		if glitter then
			glitter.Enabled = special and true or false
			glitter.Rate = 4 + #muts * 6
			if fx then glitter.Color = ColorSequence.new(fx.Tint) end
		end
		local badge = crop:FindFirstChild("Badge")
		if special then
			if not badge then
				badge = Instance.new("BillboardGui")
				badge.Name = "Badge"
				badge.Size = UDim2.fromOffset(120, 34)
				badge.MaxDistance = 90
				badge.AlwaysOnTop = true
				local t = Instance.new("TextLabel")
				t.Name = "T"
				t.BackgroundTransparency = 1
				t.Size = UDim2.fromScale(1, 1)
				t.Font = Enum.Font.FredokaOne
				t.TextScaled = true
				t.TextColor3 = Color3.new(1, 1, 1)
				t.TextStrokeTransparency = 0.2
				t.Parent = badge
				badge.Parent = crop
			end
			local icons = {}
			for _, n in muts do table.insert(icons, Data.MutationByName[n].Icon) end
			badge.T.Text = table.concat(icons, "") .. (sizeInfo and (" " .. sizeInfo.Icon) or "")
			badge.StudsOffset = Vector3.new(0, tree.Top.Size.Y / 2 + 1, 0)
		elseif badge then
			badge:Destroy()
		end
		return
	end
	-- the crop looks like its fruit (Builds.Crop): a seedling first, then the fruit growing bigger
	if not crop then -- invisible marker that carries the glitter and the badge
		crop = part(plot, {Name = "Crop", Size = Vector3.one * 0.2, Transparency = 1, CanCollide = false, CanQuery = false})
	end
	local prog = plot:GetAttribute("Progress")
	local ready = state == "Ready"
	local sizeInfo = ready and Data.CropSizeByName[plot:GetAttribute("Size") or ""]
	local muts = getMuts(plot)
	local fx = MUT_FX[muts[#muts]]
	local stage = (ready or prog >= 0.35) and "Fruit" or "Sprout"
	local look = plot:FindFirstChild("Look")
	if not look or look:GetAttribute("Stage") ~= stage then
		if look then look:Destroy() end
		look = stage == "Fruit" and Builds.Crop(info.Name) or Builds.Sprout()
		look.Name = "Look"
		look:SetAttribute("Stage", stage)
		look.Parent = plot
	end
	local scale = ready and 2.3 * (sizeInfo and sizeInfo.Scale or 1) or (stage == "Sprout" and 1.2 + 2.5 * prog or 0.6 + 1.5 * prog)
	if math.abs(look:GetScale() - scale) > 0.02 then look:ScaleTo(scale) end
	local top = plot.Position + Vector3.new(0, plot.Size.Y / 2, 0)
	look:PivotTo(CFrame.new(top) * CFrame.Angles(0, (plot.Position.X * 7 + plot.Position.Z) % 6.28, 0))
	local tintKey = (muts[#muts] or "") .. (stage == "Fruit" and "F" or "S")
	if look:GetAttribute("Tint") ~= tintKey then -- mutations recolor the fruit parts
		look:SetAttribute("Tint", tintKey)
		for _, d in look:GetChildren() do
			if d.Name == "Fruit" then
				if not d:GetAttribute("C0") then
					d:SetAttribute("C0", d.Color)
					d:SetAttribute("M0", d.Material.Name)
				end
				d.Color = fx and fx.Tint:Lerp(d:GetAttribute("C0"), 0.3) or d:GetAttribute("C0")
				d.Material = fx and fx.Material or Enum.Material[d:GetAttribute("M0")]
				d.Reflectance = fx and fx.Reflectance or 0
			end
		end
	end
	local size = scale * 1.1
	crop.Position = top + Vector3.new(0, size * 0.5, 0)
	-- glitter + a little badge (icons + size) floating over mutated or big berries
	local special = #muts > 0 or sizeInfo
	local glitter = crop:FindFirstChild("Glitter")
	if special and not glitter then
		glitter = Instance.new("ParticleEmitter")
		glitter.Name = "Glitter"
		glitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		glitter.LightEmission = 1
		glitter.Size = NumberSequence.new(0.5, 0)
		glitter.Rate = 6
		glitter.Lifetime = NumberRange.new(0.8, 1.2)
		glitter.Speed = NumberRange.new(1, 2)
		glitter.SpreadAngle = Vector2.new(180, 180)
		glitter.Parent = crop
	end
	if glitter then
		glitter.Enabled = special and true or false
		if fx then glitter.Color = ColorSequence.new(fx.Tint) end
		glitter.Rate = 4 + #muts * 6
	end
	local badge = crop:FindFirstChild("Badge")
	if special then
		if not badge then
			badge = Instance.new("BillboardGui")
			badge.Name = "Badge"
			badge.Size = UDim2.fromOffset(120, 34)
			badge.MaxDistance = 90
			badge.AlwaysOnTop = true
			local t = Instance.new("TextLabel")
			t.Name = "T"
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextColor3 = Color3.new(1, 1, 1)
			t.TextStrokeTransparency = 0.2
			t.Parent = badge
			badge.Parent = crop
		end
		local icons = {}
		for _, n in muts do table.insert(icons, Data.MutationByName[n].Icon) end
		badge.T.Text = table.concat(icons, "") .. (sizeInfo and (" " .. sizeInfo.Icon) or "")
		badge.StudsOffset = Vector3.new(0, size / 2 + 1, 0)
	elseif badge then
		badge:Destroy()
	end
end

local function lockLabel(plot, text)
	local bb = plot:FindFirstChild("LockGui")
	if not text then
		if bb then bb:Destroy() end
		return
	end
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "LockGui"
		bb.Size = UDim2.fromOffset(150, 60)
		bb.StudsOffset = Vector3.new(0, 2.5, 0)
		bb.MaxDistance = 70
		local t = Instance.new("TextLabel")
		t.Name = "T"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.2
		t.Parent = bb
		bb.Parent = plot
	end
	bb.T.Text = text
end

local function refreshPlot(plot)
	local state, watered = plot:GetAttribute("State"), plot:GetAttribute("Watered")
	local prompt = plot.PlotPrompt
	local soil = Data.Soil[plot:GetAttribute("Soil") or 1] or Data.Soil[1]
	plot.Color = watered and soil.Color:Lerp(Color3.new(0, 0, 0), 0.35) or soil.Color
	plot.Material = (plot:GetAttribute("Soil") or 1) >= 3 and Enum.Material.Neon or Enum.Material.Ground
	local farm = plotFarm[plot]
	prompt.Enabled = farm ~= nil and farm.owner ~= nil
	local locked = plot:GetAttribute("Locked")
	plot.Transparency = locked and 0.55 or 0
	if locked then -- bonus plots: unlock in order with coins + resources
		local idx = table.find(farm and farm.plots or {}, plot)
		local prof = farm and farm.owner and profiles[farm.owner]
		local nextIdx = prof and (prof.PlotsOpen or Data.StartPlots) + 1
		local cost = Data.PlotUnlocks[idx or 0]
		prompt.ActionText = idx == nextIdx and "Unlock plot 🔓" or "Locked 🔒"
		prompt.ObjectText = (idx == nextIdx and cost) and Data.CostText(cost) or ""
		lockLabel(plot, idx == nextIdx and cost and ("🔓 " .. Data.CostText(cost)) or "🔒")
		updateCrop(plot)
		return
	end
	lockLabel(plot, nil)
	if state == "Empty" then
		prompt.ActionText = "Plant 🌱"
		prompt.ObjectText = ""
	elseif state == "Growing" then
		prompt.ActionText = "Water 💧"
		prompt.ObjectText = plot:GetAttribute("Crop")
		if watered then prompt.Enabled = false end
	else
		prompt.ActionText = "Harvest 🧺"
		prompt.ObjectText = plot:GetAttribute("Crop")
	end
	updateCrop(plot)
end

local function reset(plot, state, cropName)
	plot:SetAttribute("State", state)
	plot:SetAttribute("Crop", cropName or "")
	plot:SetAttribute("Progress", 0)
	plot:SetAttribute("Watered", false)
	plot:SetAttribute("Muts", nil)
	plot:SetAttribute("Size", nil)
	plot:SetAttribute("Mature", nil)
	refreshPlot(plot)
end

-- Plants one of the player's chosen seed (player attribute "Seed") from their seed bag.
-- Out of that seed? It plants a free Puffberry instead. Returns ok, message.
local function plant(plot, player)
	if plot:GetAttribute("State") ~= "Empty" then return false end
	local prof = profiles[player]
	local crop = CROP[player and player:GetAttribute("Seed") or ""] or CROP[Data.FarmCrop]
	local msg
	if crop.Name ~= Data.FarmCrop then
		if prof and (prof.Seeds[crop.Name] or 0) > 0 then
			addSeeds(player, crop.Name, -1)
		else
			msg = ("%s 0 → %s"):format(crop.Icon, CROP[Data.FarmCrop].Icon)
			crop = CROP[Data.FarmCrop]
		end
	end
	reset(plot, "Growing", crop.Name)
	questEvent(player, "Plant", 1)
	addFarmXp(player, 1)
	return true, msg
end

local function water(plot, player)
	if plot:GetAttribute("State") ~= "Growing" or plot:GetAttribute("Watered") then return false end
	plot:SetAttribute("Watered", true)
	refreshPlot(plot)
	if player then
		questEvent(player, "Water", 1)
		addFarmXp(player, 1)
	end
	return true
end

-- special (mutated or big) berries: a list in the profile, sold for their value at the stall or a sell bin
local function setSpecialAttrs(player, prof)
	local value = 0
	for _, s in prof.Special do value += s.Value end
	player:SetAttribute("SpecialCount", #prof.Special)
	player:SetAttribute("SpecialValue", value)
end

local function harvest(plot, player, bonus)
	if plot:GetAttribute("State") ~= "Ready" then return false end
	local info = CROP[plot:GetAttribute("Crop")]
	local slot = basket(player, info.Name)
	local prof = profiles[player]
	if not slot or not prof then return false end
	local n = info.Yield + (bonus or 0)
	local muts, sizeName = getMuts(plot), plot:GetAttribute("Size")
	local special = #muts > 0 or sizeName ~= nil
	if info.Tree then -- trees stay planted and grow new fruit
		plot:SetAttribute("State", "Growing")
		plot:SetAttribute("Progress", 0)
		plot:SetAttribute("Watered", false)
		plot:SetAttribute("Muts", nil)
		plot:SetAttribute("Size", nil)
		plot:SetAttribute("Mature", true)
		refreshPlot(plot)
	else
		reset(plot, "Empty")
	end
	if not prof.SeedBook[info.Name] then -- new in the Seed Book
		prof.SeedBook[info.Name] = true
		toast(player, ("📗 %s"):format(info.Icon))
	end
	questEvent(player, "Harvest", n)
	addFarmXp(player, n * info.Tier)
	if info.Tier >= 2 then questEvent(player, "Fancy", n) end
	if special then
		local value = Data.SpecialValue(info, n, muts, sizeName)
		local item = {Crop = info.Name, Muts = muts, Size = sizeName, Value = value}
		if #prof.Special < Data.SpecialMax then
			table.insert(prof.Special, item)
		else
			addCoins(player, value) -- bag full: sold on the spot
		end
		setSpecialAttrs(player, prof)
		if #muts > 0 then questEvent(player, "Mutation", 1) end
		for _, m in muts do
			if m == "Golden" then questEvent(player, "Golden", 1) end
		end
		revealEvent:FireClient(player, {Kind = "Harvest", Crop = info.Name, Muts = muts, Size = sizeName, Value = value})
		if sizeName == "MEGA" then giveTitle(player, "Pumpkin King") end
		if API.record then API.record("Berry", player, value) end
		if value >= 400 then
			notify:FireAllClients(("🤩 %s harvested a %s%s %s worth 💰%d!"):format(player.DisplayName,
				table.concat((function() local t = {} for _, m in muts do table.insert(t, Data.MutationByName[m].Icon) end return t end)(), ""),
				sizeName and (" " .. sizeName) or "", info.Name, value))
		end
	else
		slot.Value += n
	end
	return true, info, special
end

local function rollMutation(plot, name, chance)
	if math.random() < chance and addMut(plot, name) then
		updateCrop(plot)
		pop(plot, Data.MutationByName[name].Icon)
		return true
	end
	return false
end

local function boost(plot, amount)
	if plot:GetAttribute("State") ~= "Growing" then return false end
	plot:SetAttribute("Progress", math.min(0.999, plot:GetAttribute("Progress") + amount))
	plot:SetAttribute("BoostedAt", os.clock())
	updateCrop(plot)
	return true
end

local function rollCropSize(info)
	for _, s in Data.CropSizes do -- rarest first (giant crops like pumpkins roll x Giant)
		if math.random() < s.Chance * (info and info.Giant or 1) then return s.Name end
	end
	return nil
end

local function ripen(plot)
	plot:SetAttribute("State", "Ready")
	local luck = (Data.Soil[plot:GetAttribute("Soil") or 1] or Data.Soil[1]).Luck
	for _, m in Data.Mutations do
		if m.Ripen and math.random() < m.Ripen * luck then addMut(plot, m.Name) end
	end
	plot:SetAttribute("Size", rollCropSize(CROP[plot:GetAttribute("Crop")]))
	refreshPlot(plot)
end

local function farmSignText(farm)
	local owner = farm.owner
	local prof = owner and profiles[owner]
	if not prof then return "🏡 ❔" end
	return ("🏡 %s\n⭐ %d   ❤️ %d"):format(owner.DisplayName, Data.FarmLevel(prof.FarmXp), prof.Likes or 0)
end
local function refreshFarmSign(farm)
	if farm and farm.sign then farm.sign.Text = farmSignText(farm) end
end

-- random spot inside a farm (for pets wandering around)
local function farmSpot(farm)
	local cf = farm.ground.CFrame
	local p = cf * Vector3.new((math.random() * 2 - 1) * 19, 0, (math.random() * 2 - 1) * 19)
	return Vector3.new(p.X, 0, p.Z)
end

-- save / load the 9 plots into the profile
local function snapshotFarm(farm, prof)
	local list = {}
	for i, plot in farm.plots do
		list[i] = {S = plot:GetAttribute("State"), C = plot:GetAttribute("Crop"), P = plot:GetAttribute("Progress"),
			W = plot:GetAttribute("Watered"), M = plot:GetAttribute("Muts"), Z = plot:GetAttribute("Size"), T = plot:GetAttribute("Mature")}
	end
	prof.Plots = list
end
local function loadFarm(farm, prof, awaySecs)
	for i, plot in farm.plots do
		local s = prof.Plots and prof.Plots[i]
		if s and s.S and s.S ~= "Empty" and CROP[s.C or ""] then
			plot:SetAttribute("State", s.S)
			plot:SetAttribute("Crop", s.C)
			plot:SetAttribute("Watered", s.W and true or false)
			plot:SetAttribute("Muts", s.M)
			plot:SetAttribute("Size", s.Z)
			plot:SetAttribute("Mature", s.T)
			local info = CROP[s.C]
			local p = s.P or 0
			if s.S == "Growing" then -- kept growing while you were away
				local t = s.T and info.Regrow and (s.W and info.Regrow * 0.5 or info.Regrow) or (s.W and info.WetGrow or info.Grow)
				p = math.min(1, p + (awaySecs or 0) / t)
			end
			plot:SetAttribute("Progress", p)
			if s.S == "Growing" and p >= 1 then ripen(plot) else refreshPlot(plot) end
		else
			reset(plot, "Empty")
		end
	end
end

local function assignFarm(player, prof, awaySecs)
	for _, farm in farms do
		if not farm.owner then
			farm.owner = player
			farmOf[player] = farm
			farm.model:SetAttribute("Owner", player.UserId)
			for i, plot in farm.plots do
				plot:SetAttribute("Locked", i > (prof.PlotsOpen or Data.StartPlots) or nil)
				plot:SetAttribute("Soil", prof.Soil and prof.Soil[tostring(i)] or 1)
			end
			loadFarm(farm, prof, awaySecs)
			refreshFarmSign(farm)
			return farm
		end
	end
	return nil
end
local function releaseFarm(player)
	local farm = farmOf[player]
	if not farm then return end
	farmOf[player] = nil
	farm.owner = nil
	farm.model:SetAttribute("Owner", nil)
	for i, plot in farm.plots do
		plot:SetAttribute("Locked", i > Data.StartPlots or nil)
		plot:SetAttribute("Soil", 1)
		plot:SetAttribute("Bee", nil)
		reset(plot, "Empty")
	end
	refreshFarmSign(farm)
end

local function teleportTo(player, pos)
	pcall(player.RequestStreamAroundAsync, player, pos, 3) -- islands are far apart: load the spot first
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then char:PivotTo(CFrame.new(pos + Vector3.new(0, 4, 0)) * hrp.CFrame.Rotation) end
end

---------------------------------------------------------------- selling (market stall + every farm's sell bin)
local function sellAll(player, where)
	local prof = profiles[player]
	local coins = stat(player, "Coins")
	if not prof or not coins then return end
	local mult = (prof.Built.FruitStand and CONFIG.StandSellBonus or 1) * (weather == "GoldenSun" and 2 or 1)
	local count, earned = 0, 0
	for _, c in CROPS do
		local slot = basket(player, c.Name)
		if slot and slot.Value > 0 then
			count += slot.Value
			earned += math.floor(slot.Value * c.Price * mult)
			slot.Value = 0
		end
	end
	for _, s in prof.Special do
		count += 1
		earned += math.floor(s.Value * mult)
	end
	table.clear(prof.Special)
	setSpecialAttrs(player, prof)
	if count == 0 then
		toast(player, "🧺 0")
		return
	end
	coins.Value += earned
	toast(player, ("💰 +%d"):format(earned))
	pop(where, "💰")
	questEvent(player, "Sell", earned)
end
makePrompt(counter, "Sell all 💰", "Market Stall").Triggered:Connect(function(player) sellAll(player, counter) end)

-- likes: once per farm per day, the liker gets a few coins as thanks
local likeBoardText = root:FindFirstChild("LikeBoard") and root.LikeBoard:FindFirstChild("Board", true)
likeBoardText = likeBoardText and likeBoardText:FindFirstChild("Gui") and likeBoardText.Gui:FindFirstChild("List")
local function refreshLikeBoard()
	if not likeBoardText then return end
	local list = {}
	for p, prof in profiles do table.insert(list, {p.DisplayName, prof.Likes or 0}) end
	table.sort(list, function(a, b) return a[2] > b[2] end)
	local medals = {"🥇", "🥈", "🥉"}
	local lines = {"❤️ 🏡"}
	for i = 1, math.min(6, #list) do
		table.insert(lines, ("%s %s  ❤️ %d"):format(medals[i] or ("%d."):format(i), list[i][1], list[i][2]))
	end
	likeBoardText.Text = table.concat(lines, "\n")
end
local function likeFarm(player, farm)
	local owner = farm.owner
	local prof, oprof = profiles[player], owner and profiles[owner]
	if not prof or not oprof then return end
	if owner == player then
		toast(player, ("❤️ %d"):format(oprof.Likes or 0))
		return
	end
	if prof.LikeDay ~= today() then
		prof.LikeDay = today()
		prof.LikedToday = {}
	end
	local key = tostring(owner.UserId)
	if prof.LikedToday[key] then
		toast(player, "❤️ ✔")
		return
	end
	prof.LikedToday[key] = true
	oprof.Likes = (oprof.Likes or 0) + 1
	if oprof.Likes >= 10 then giveTitle(owner, "Popular") end
	owner:SetAttribute("Likes", oprof.Likes)
	addCoins(player, Data.LikeCoins)
	toast(player, ("❤️ %s  💰+%d"):format(owner.DisplayName, Data.LikeCoins))
	toast(owner, ("❤️ %s liked your farm!"):format(player.DisplayName))
	local tip = farm.heart
	if tip then
		pop(tip, "❤️")
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		burst.Color = ColorSequence.new(Color3.fromRGB(255, 90, 130), Color3.fromRGB(255, 200, 220))
		burst.LightEmission = 1
		burst.Size = NumberSequence.new(1, 0)
		burst.Speed = NumberRange.new(6, 12)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Rate = 0
		burst.Parent = tip
		burst:Emit(30)
		task.delay(2, function() burst:Destroy() end)
	end
	refreshFarmSign(farm)
	refreshLikeBoard()
end
task.spawn(function()
	while true do
		task.wait(10)
		refreshLikeBoard()
		for _, farm in farms do refreshFarmSign(farm) end
	end
end)

-- set up every farm in the world
for _, model in farmsFolder:GetChildren() do
	if model:IsA("Model") and model:FindFirstChild("Plots") then
		local farm = {model = model, ground = model:FindFirstChild("Ground"), home = model:FindFirstChild("Home"), plots = {}}
		local list = model.Plots:GetChildren()
		table.sort(list, function(a, b) return (tonumber(a.Name:match("%d+")) or 0) < (tonumber(b.Name:match("%d+")) or 0) end)
		for _, plot in list do
			table.insert(farm.plots, plot)
			table.insert(plots, plot)
			plotFarm[plot] = farm
			local prompt = makePrompt(plot, "", "")
			prompt.Name = "PlotPrompt"
			prompt.Triggered:Connect(function(player)
				local s = plot:GetAttribute("State")
				if plot:GetAttribute("Locked") then
					local prof = profiles[player]
					if farm.owner ~= player or not prof then toast(player, "🔒 🏡") return end
					local idx = table.find(farm.plots, plot)
					local nextIdx = (prof.PlotsOpen or Data.StartPlots) + 1
					if idx ~= nextIdx then toast(player, "🔒 Unlock the plot with the 🔓 sign first") return end
					local ok, missing = pay(player, prof, Data.PlotUnlocks[idx])
					if not ok then toast(player, ("Need more %s to unlock this plot"):format(missing)) return end
					prof.PlotsOpen = idx
					plot:SetAttribute("Locked", nil)
					pop(plot, "🔓")
					toast(player, "🔓 New plot unlocked!")
					for _, p2 in farm.plots do refreshPlot(p2) end
					return
				end
				if farm.owner ~= player then -- visiting: help water a friend's crop
					if s == "Growing" and water(plot, nil) then
						pop(plot, "💧")
						addCoins(player, Data.FarmHelpCoins)
						questEvent(player, "Water", 1)
						if farm.owner then toast(farm.owner, ("💧 %s helped water your farm!"):format(player.DisplayName)) end
					else
						toast(player, "🔒 🏡")
					end
					return
				end
				if s == "Empty" then
					local _, msg = plant(plot, player)
					if msg then toast(player, msg) end
				elseif s == "Growing" then
					if water(plot, player) then pop(plot, "💧") end
				else
					local ok, info, special = harvest(plot, player)
					if ok then pop(plot, special and "✨" or info.Icon) end
				end
			end)
			reset(plot, "Empty")
		end
		local signPart = model:FindFirstChild("OwnerSign")
		farm.sign = signPart and signPart:FindFirstChild("Text", true)
		local heart = model:FindFirstChild("LikeHeart")
		farm.heart = heart and heart.PrimaryPart
		if farm.heart then
			local p = makePrompt(farm.heart, "Like ❤️", "")
			p.MaxActivationDistance = 12
			p.Triggered:Connect(function(player) likeFarm(player, farm) end)
		end
		local bin = model:FindFirstChild("SellBin")
		if bin then
			makePrompt(bin, "Sell all 💰", "").Triggered:Connect(function(player) sellAll(player, bin) end)
		end
		table.insert(farms, farm)
		refreshFarmSign(farm)
	end
end
table.sort(farms, function(a, b) return (a.model:GetAttribute("Slot") or 0) < (b.model:GetAttribute("Slot") or 0) end)
function beforeSave(player, prof)
	local farm = farmOf[player]
	if farm then snapshotFarm(farm, prof) end
end

-- crops grow; weather and luck mutate them
task.spawn(function()
	while true do
		local dt = task.wait(0.25)
		for _, plot in plots do
			if plot:GetAttribute("State") == "Growing" and plotFarm[plot].owner and not plot:GetAttribute("Locked") then
				local info = CROP[plot:GetAttribute("Crop")]
				local wet = plot:GetAttribute("Watered")
				local t
				if plot:GetAttribute("Mature") then t = wet and info.Regrow * 0.5 or info.Regrow
				else t = wet and info.WetGrow or info.Grow end
				local soil = Data.Soil[plot:GetAttribute("Soil") or 1] or Data.Soil[1]
				local p = math.min(1, plot:GetAttribute("Progress") + dt / t * soil.Grow * (1 + (plot:GetAttribute("Bee") or 0)))
				plot:SetAttribute("Progress", p)
				-- glowing crops love world events and magic weather; better soil is luckier
				local glow = (info.Glow and (workspace:GetAttribute("Event") or weather == "StarNight" or weather == "Storm") and 3 or 1) * soil.Luck
				for _, m in Data.Mutations do
					if m.Weather and m.Weather == weather then rollMutation(plot, m.Name, m.Rate * dt * glow) end
				end
				if info.Glow and workspace:GetAttribute("Event") then rollMutation(plot, "Starry", 0.006 * dt) end
				if p >= 1 then ripen(plot) else updateCrop(plot) end
			end
		end
	end
end)
-- prismatic berries cycle through the colors
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for _, plot in plots do
		local look = plot:FindFirstChild("Look")
		if look and look:GetAttribute("Tint") == "PrismaticF" then
			local c = Color3.fromHSV((t * 0.3 + plot.Position.X * 0.01) % 1, 0.5, 1)
			for _, d in look:GetChildren() do
				if d.Name == "Fruit" then d.Color = c end
			end
		end
	end
end)

---------------------------------------------------------------- critters
local critters = {}
local claimed = {}

local function randomIn(center, halfX, halfZ)
	return Vector3.new(center.X + (math.random() * 2 - 1) * halfX, 0, center.Z + (math.random() * 2 - 1) * halfZ)
end
-- biome ground parts (Meadow + the built biomes)
local biomeParts = {}
for _, b in Data.Biomes do
	local p = b.Name == "Meadow" and meadow or (root:FindFirstChild("Biome_" .. b.Name) and root["Biome_" .. b.Name]:FindFirstChild("Ground"))
	if p then biomeParts[b.Name] = p end
end
local function biomePoint(name)
	local p = biomeParts[name] or meadow
	return randomIn(p.Position, p.Size.X / 2 - 8, p.Size.Z / 2 - 8)
end
local function meadowPoint() return biomePoint("Meadow") end
-- the real ground height under a spot (farms, plaza, biomes and paths sit a little above y = 0)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function refreshGroundList()
	local list = {meadow}
	for _, name in {"FarmGround", "Paths"} do
		local g = root:FindFirstChild(name)
		if g then table.insert(list, g) end
	end
	local bp = workspace:FindFirstChild("Baseplate")
	if bp then table.insert(list, bp) end
	for _, farm in farms do
		if farm.ground then table.insert(list, farm.ground) end
	end
	for _, p in biomeParts do table.insert(list, p) end
	groundParams.FilterDescendantsInstances = list
end
refreshGroundList()
local function groundAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), groundParams)
	return hit and hit.Position.Y or GROUND_Y
end
-- where a critter hangs out: its owner's farm, or its home biome when wild
local function farmPoint(c)
	local farm = c and c.owner and farmOf[c.owner]
	if farm then return farmSpot(farm) end
	return biomePoint(c and c.biome or "Meadow")
end

local function speciesWeight(s)
	local w = Data.Rarities[s.Rarity].Weight
	if s == critterOfDay() then w *= 3 end
	if weather == "StarNight" and s.Rarity == "Common" then w *= 0.1 end
	return w
end

local function rollSpecies()
	local total = 0
	for _, s in Data.Species do total += speciesWeight(s) end
	local r = math.random() * total
	for _, s in Data.Species do
		r -= speciesWeight(s)
		if r <= 0 then return s end
	end
	return Data.Species[1]
end

local function rollFromWeights(weights)
	local total = 0
	for _, w in weights do total += w end
	local r = math.random() * total
	for k, w in weights do
		r -= w
		if r <= 0 then return k end
	end
	return next(weights)
end

local function rollVariant(luck)
	if (workspace:GetAttribute("LuckyUntil") or 0) > os.time() then luck = (luck or 1) * Data.LuckyHourMult end -- 🍀 lucky hour
	for i = #Data.Variants, 1, -1 do -- rarest first
		local v = Data.Variants[i]
		if math.random() < v.Chance * (luck or 1) then return v.Name end
	end
end
local function rollSize()
	for _, s in Data.Sizes do
		if math.random() < s.Chance then return s.Name end
	end
end

local function buildCritterModel(T, sizeName, variant, stageScale, tint)
	local rarity = Data.Rarities[T.Rarity]
	local sizeInfo = sizeName and Data.SizeByName[sizeName]
	local scale = (1 + (rarity.Order - 1) * 0.12) * (sizeInfo and sizeInfo.Scale or 1) * (stageScale or 1)
	if tint then -- nest babies mix their parents' colors
		T = setmetatable({Color = Color3.fromRGB(tint[1], tint[2], tint[3]), Ear = tint[4] and Color3.fromRGB(tint[4], tint[5], tint[6]) or T.Ear},
			{__index = T})
	end
	local m, body
	local folder = ReplicatedStorage:FindFirstChild("PetModels")
	local template = folder and folder:FindFirstChild(T.Species)
	if template then -- generated 3D model
		m = template:Clone()
		m.Name = T.Species
		m:ScaleTo(m:GetScale() * scale)
		body = m.PrimaryPart
		body.Name = "Body"
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.Massless = true, false, true
				d.CanQuery = d == body
			end
		end
	else -- simple built-in look
		m = Instance.new("Model")
		m.Name = T.Species
		body = part(m, {Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.6 * scale, Color = T.Color,
			CanCollide = false, Position = Vector3.zero})
		local function bit(props)
			props.CanCollide = false
			props.CanQuery = false
			props.Massless = true
			props.Size *= scale
			props.Position *= scale
			return part(m, props)
		end
		bit({Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, Color = Color3.fromRGB(255, 250, 240), Position = Vector3.new(0, -0.35, -0.55)})
		for _, x in {-0.5, 0.5} do
			bit({Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = Color3.fromRGB(30, 30, 40), Position = Vector3.new(x, 0.4, -1.12)})
			bit({Size = Vector3.new(0.45, 1.3, 0.3), Color = T.Ear, Position = Vector3.new(x * 1.5, 1.55, 0), Orientation = Vector3.new(0, 0, -x * 30)})
			bit({Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, Color = T.Ear, Position = Vector3.new(x * 1.6, -1.1, -0.3)})
		end
	end
	local _, bbSize = m:GetBoundingBox()
	if template and template:GetAttribute("Rig") then
		-- Rigged critter: the server only keeps (and moves) the Body. Each client shows the full model
		-- and animates its limbs (StarterPlayerScripts.CritterAnimator).
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and p ~= body then p:Destroy() end
		end
		CollectionService:AddTag(m, "RiggedCritter")
	elseif template then
		-- One-piece generated model: the client animates the whole body (squash, stretch, hops, tricks)
		CollectionService:AddTag(m, "BlobCritter")
	end
	if rarity.Order >= 3 then -- Epic and Legendary critters sparkle
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(rarity.Color)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.35, 0)
		sparkle.Lifetime = NumberRange.new(0.8, 1.2)
		sparkle.Rate = rarity.Order == 4 and 14 or 6
		sparkle.Speed = NumberRange.new(1, 2)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = body
	end
	local vinfo = variant and Data.VariantByName[variant]
	if vinfo then -- shiny / rainbow: glitter (each client adds the glow to its local model)
		m:SetAttribute("Variant", variant)
		local glitter = Instance.new("ParticleEmitter")
		glitter.Name = "Glitter"
		glitter.Color = variant == "Rainbow" and ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 90)), ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 110, 255))}) or ColorSequence.new(vinfo.Color)
		glitter.LightEmission = 1
		glitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		glitter.Size = NumberSequence.new(0.6, 0)
		glitter.Lifetime = NumberRange.new(0.8, 1.4)
		glitter.Rate = 18
		glitter.Speed = NumberRange.new(1.5, 3)
		glitter.SpreadAngle = Vector2.new(180, 180)
		glitter.Parent = body
		if not template then -- the simple look has no client copy, so glow it here
			local hl = Instance.new("Highlight")
			hl.FillColor = vinfo.Color
			hl.FillTransparency = 0.55
			hl.OutlineColor = Color3.fromRGB(255, 245, 190)
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Parent = m
		end
	end
	m.PrimaryPart = body
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 60)
	bb.StudsOffset = Vector3.new(0, bbSize.Y / 2 + 1.8, 0)
	bb.MaxDistance = 80
	local tag = Instance.new("TextLabel")
	tag.Name = "Tag"
	tag.Size = UDim2.new(1, 0, 0, 40)
	-- ⚡ energy bar (workers only, filled in by updateEnergyBar)
	local ebar = Instance.new("Frame")
	ebar.Name = "Energy"
	ebar.AnchorPoint = Vector2.new(0.5, 0)
	ebar.Position = UDim2.new(0.5, 0, 0, 42)
	ebar.Size = UDim2.new(0.62, 0, 0, 16)
	ebar.BackgroundColor3 = Color3.fromRGB(40, 35, 55)
	ebar.Visible = false
	Instance.new("UICorner", ebar).CornerRadius = UDim.new(1, 0)
	local efill = Instance.new("Frame")
	efill.Name = "Fill"
	efill.Size = UDim2.fromScale(1, 1)
	efill.BackgroundColor3 = Color3.fromRGB(110, 210, 90)
	Instance.new("UICorner", efill).CornerRadius = UDim.new(1, 0)
	efill.Parent = ebar
	local etext = Instance.new("TextLabel")
	etext.Name = "T"
	etext.BackgroundTransparency = 1
	etext.Size = UDim2.fromScale(1, 1)
	etext.Font = Enum.Font.FredokaOne
	etext.TextScaled = true
	etext.TextColor3 = Color3.new(1, 1, 1)
	etext.TextStrokeTransparency = 0.3
	etext.ZIndex = 2
	etext.Parent = ebar
	ebar.Parent = bb
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.FredokaOne
	tag.TextScaled = true
	tag.TextStrokeTransparency = 0.3
	tag.TextColor3 = rarity.Color
	tag.Parent = bb
	bb.Parent = body
	return m, body, tag, bbSize.Y / 2
end

local MOOD_ICON = {Happy = " 💖", Sad = " 😢"}
-- ⚡ energy bar over working pets (💤 nap countdown while they rest in the hut)
local function updateEnergyBar(c)
	local bar = c.tag and c.tag.Parent and c.tag.Parent:FindFirstChild("Energy")
	if not bar then return end
	local rec = c.record
	local show = rec ~= nil
	bar.Visible = show
	if not show then return end
	local fill, text, color
	if rec.NapUntil then
		local total = math.max(1, Data.NapTime(c.type.Rarity) / timeScale())
		local left = math.max(0, rec.NapUntil - os.time())
		fill, color = 1 - left / total, Color3.fromRGB(120, 150, 255)
		text = ("💤 Napping %d:%02d"):format(left // 60, left % 60)
	else
		local e = math.clamp(math.floor(rec.Energy or 100), 0, 100)
		local prof = c.owner and profiles[c.owner]
		local working = prof and table.find(prof.Workers or {}, rec.Id)
		fill, color = e / 100, e > 35 and Color3.fromRGB(110, 210, 90) or Color3.fromRGB(255, 150, 60)
		text = (working and "⚡ " or "🪑 Resting ⚡") .. e
	end
	bar.Fill.Size = UDim2.fromScale(math.clamp(fill, 0.04, 1), 1)
	bar.Fill.BackgroundColor3 = color
	bar.T.Text = text
end
local function refreshTag(c)
	local T = c.type
	local icon = Data.Classes[T.Class].Icon
	if c.record and isResting(c.record) then icon = "😴 " .. icon end
	if c.record and c.record.NapUntil then icon = "💤 " .. icon end
	local v = c.variant and Data.VariantByName[c.variant]
	local s = c.sizeName and Data.SizeByName[c.sizeName]
	local pre = (v and v.Icon .. " " or "") .. (s and s.Icon .. " " or "")
	local mood = c.record and moodOf(c.record)
	if c.owner then
		local rec = c.record
		local stage = Data.StageOf(rec, petLevel(rec))
		local name = rec.Name and ('"' .. rec.Name .. '"') or (c.owner.DisplayName .. "'s " .. T.Species)
		local odds = rec.Odds and rec.Odds >= 100 and ("  " .. Data.OddsText(rec.Odds)) or ""
		c.tag.Text = ("%s%s  Lv %d\n%s%s %s%s%s"):format(pre, name, petLevel(rec), stage and (stage.Icon .. stage.Name .. " ") or "",
			icon, T.Rarity, odds, MOOD_ICON[mood] or "")
	else
		c.tag.Text = ("%sWild %s\n%s %s"):format(pre, T.Species, icon, T.Rarity)
	end
	c.tag.TextColor3 = v and v.Color or Data.Rarities[T.Rarity].Color
	updateEnergyBar(c)
	local m = c.model
	m:SetAttribute("Napping", c.napping and true or nil) -- the client animator lies it down for a nap
	m:SetAttribute("Mood", mood)
	local outfit = c.record and c.record.Outfit or nil
	if m:GetAttribute("Outfit") ~= outfit then
		m:SetAttribute("Outfit", outfit) -- the client animator puts the hat on
		if not c.rigged then CritterUI.Dress(m, outfit) end -- simple look: hat on the server model
	end
end

local function setOwner(c, player, rec)
	local T = c.type
	c.owner = player
	c.record = rec
	c.version += 1
	c.target = nil
	if player then
		c.prompt.ActionText = "Pet ❤️"
		c.prompt.ObjectText = ("%s %s, %s"):format(T.Rarity, T.Species, T.JobText)
	else
		c.leaveAt = os.clock() + CONFIG.WildStay[T.Rarity]
		c.prompt.ActionText = ("Offer a berry (%d%% base)"):format(Data.Rarities[T.Rarity].Catch * 100)
		c.prompt.ObjectText = ("%s %s, %s"):format(T.Rarity, T.Species, T.JobText)
	end
	refreshTag(c)
end

-- Job speed/power: level, shiny bonus and mood (happy pets work faster, sad ones slower).
local function levelMult(c)
	local rec = c.record
	if not rec then return 1 end
	local mood = moodOf(rec)
	local m = mood == "Happy" and Data.HappyMult or (mood == "Sad" and Data.SadMult or 1)
	return (1 + Data.LevelBonus * (petLevel(rec) - 1)) * variantMult(rec) * m * (rec.Grown and Data.GrownBonus or 1)
end

local function walkTo(c, pos, timeout)
	local v = c.version
	c.target = pos
	local start = os.clock()
	while c.alive and c.version == v and os.clock() - start < (timeout or 20) do
		if Vector3.new(pos.X - c.pos.X, 0, pos.Z - c.pos.Z).Magnitude <= 0.4 then return true end
		task.wait(0.1)
	end
	return false
end

local function needsWork(c, plot)
	local s, job = plot:GetAttribute("State"), c.type.Job
	if job == "Water" then
		return s == "Growing" and not plot:GetAttribute("Watered")
	elseif job == "Harvest" then
		return s == "Ready"
	elseif job == "Grow" then
		return s == "Growing" and os.clock() - (plot:GetAttribute("BoostedAt") or 0) > CONFIG.BoostCooldown
	else
		return s == "Empty"
	end
end

local function findWork(c)
	local farm = c.owner and farmOf[c.owner]
	if not farm then return nil end
	local best, bestD
	for _, plot in farm.plots do -- pets only work on their owner's farm
		if not claimed[plot] and not plot:GetAttribute("Locked") and needsWork(c, plot) then
			local d = (plot.Position - c.pos).Magnitude
			if not bestD or d < bestD then best, bestD = plot, d end
		end
	end
	return best
end

---------------------------------------------------------------- working slots, energy, naps and dream gifts
-- prof.Workers = ids of the worker pets on duty (up to prof.WorkSlots). The rest sit on the bench.
-- Each job uses energy; at 0 the pet naps in the farm hut, then wakes with a random dream gift and goes
-- back to the bench while a rested bench pet takes its slot (automatic, so the farm never stops).
local function recById(prof, id)
	for _, rec in prof.Pets do
		if rec.Id == id then return rec end
	end
end
local function isWorking(c)
	local prof = c.owner and profiles[c.owner]
	return prof ~= nil and c.record ~= nil and table.find(prof.Workers, c.record.Id) ~= nil
end
local function canWork(rec)
	return not rec.Trip and not rec.Stored and not rec.NapUntil and not rec.NestUntil and not rec.Riding and not isResting(rec)
end
local function fillSlots(player)
	local prof = profiles[player]
	if not prof then return end
	for i = #prof.Workers, 1, -1 do
		local rec = recById(prof, prof.Workers[i])
		if not rec or not canWork(rec) then table.remove(prof.Workers, i) end
	end
	local bench = {}
	for _, rec in prof.Pets do
		if canWork(rec) and not rec.Bench and not table.find(prof.Workers, rec.Id) then table.insert(bench, rec) end
	end
	table.sort(bench, function(a, b)
		local ea, eb = a.Energy or 100, b.Energy or 100
		if math.abs(ea - eb) > 1 then return ea > eb end
		return Data.Rarities[Data.SpeciesByName[a.Species].Rarity].Order > Data.Rarities[Data.SpeciesByName[b.Species].Rarity].Order
	end)
	while #prof.Workers < prof.WorkSlots and #bench > 0 do
		table.insert(prof.Workers, table.remove(bench, 1).Id)
	end
	player:SetAttribute("WorkerActive", #prof.Workers)
	player:SetAttribute("WorkSlots", prof.WorkSlots)
end
local function farmCorner(c, name, x, z)
	local farm = c.owner and farmOf[c.owner]
	if not farm then return farmPoint(c) end
	local marker = farm.model:FindFirstChild(name)
	local p = marker and marker.Position or (farm.ground.CFrame * Vector3.new(x, 0, z))
	return Vector3.new(p.X + math.random(-3, 3), 0, p.Z + math.random(-3, 3))
end
local function hutSpot(c) return farmCorner(c, "NapSpot", -16, 17) end
local function benchSpot(c) return farmCorner(c, "BenchSpot", 16, 17) end

local function startNap(c)
	local rec, player = c.record, c.owner
	rec.Energy = 0
	rec.NapUntil = os.time() + math.ceil(Data.NapTime(c.type.Rarity) / timeScale())
	c.version += 1
	pop(c.body, "😴")
	fillSlots(player)
	refreshTag(c)
	pushState(player)
end
local function wakeUp(c)
	local rec, player = c.record, c.owner
	rec.NapUntil = nil
	rec.Energy = 100
	c.napping = false
	-- dream gift: rarer and happier pets dream luckier
	local luck = (1 + 0.5 * (Data.Rarities[c.type.Rarity].Order - 1)) * (moodOf(rec) == "Happy" and 1.5 or 1)
	local list = {}
	for _, g in Data.DreamGifts do
		local copy = table.clone(g)
		if g.Rarity == "Epic" or g.Rarity == "Legendary" then copy.Weight *= luck end
		table.insert(list, copy)
	end
	local got = grant(player, rollWeighted(list))
	got.From, got.Dream = rec.Species, true
	revealEvent:FireClient(player, {Kind = "Prize", Prize = got})
	pop(c.body, "💭")
	fillSlots(player)
	refreshTag(c)
	pushState(player)
end

local ICONS = {Water = "💧", Harvest = "🧺", Plant = "🌱", Grow = "✨"}
local function doJob(c, plot)
	local T, ok = c.type, false
	if T.Job == "Water" then
		ok = water(plot, c.owner)
	elseif T.Job == "Harvest" then
		ok = harvest(plot, c.owner, T.Bonus)
	elseif T.Job == "Grow" then
		if T.Waters then water(plot, c.owner) end
		ok = boost(plot, T.Boost * levelMult(c))
	else
		ok = plant(plot, c.owner)
	end
	if not ok then return end
	if T.Mutate and plot:GetAttribute("State") == "Growing" then rollMutation(plot, T.Mutate[1], T.Mutate[2]) end -- some pets bring luck
	pop(c.body, ICONS[T.Job])
	c.model:SetAttribute("Work", (c.model:GetAttribute("Work") or 0) + 1) -- the client plays a little "job done" move
	local rec = c.record
	local before = petLevel(rec)
	rec.Xp = (rec.Xp or 0) + 1
	if petLevel(rec) > before then
		refreshTag(c)
		toast(c.owner, ("%s reached level %d and works faster!"):format(T.Species, petLevel(rec)))
		pushState(c.owner)
	end
	rec.Energy = (rec.Energy or 100) - Data.EnergyCost(T.Rarity, petLevel(rec))
	c.model:SetAttribute("Energy", math.max(0, math.floor(rec.Energy)))
	updateEnergyBar(c)
	if rec.Energy <= 0 then startNap(c) end
end

local function removeCritter(c)
	c.alive = false
	critters[c] = nil
	c.model:Destroy()
end

-- Follow-me pet: the one pet whose Id is the owner's FollowId trots along behind them.
local function isFollowing(c)
	local prof = c.owner and profiles[c.owner]
	return prof ~= nil and c.record ~= nil and prof.FollowId == c.record.Id
end
local function ownerSpot(c)
	local char = c.owner and c.owner.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local cf = hrp.CFrame
	local back = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	back = back.Magnitude > 0.01 and back.Unit or Vector3.new(0, 0, -1)
	local side = Vector3.new(-back.Z, 0, back.X)
	return hrp.Position - back * (4 + c.halfH) + side * 3, hrp.Position
end
-- One step of following (call every ~0.15s). Returns the flat distance to the owner.
local function followStep(c)
	local spot, at = ownerSpot(c)
	if not spot then
		c.target = nil
		return 0
	end
	local d = Vector3.new(at.X - c.pos.X, 0, at.Z - c.pos.Z).Magnitude
	if d > 140 then -- way too far (teleported?): pop over
		c.pos = Vector3.new(spot.X, 0, spot.Z)
	end
	if (Vector3.new(spot.X, 0, spot.Z) - Vector3.new(c.pos.X, 0, c.pos.Z)).Magnitude > 2.5 then
		c.target = Vector3.new(spot.X, 0, spot.Z)
		c.speedBoost = math.clamp(d / 7, 1, 2.6) -- catch up when you run off
	else
		c.target = nil
		c.speedBoost = nil
	end
	return d
end

-- Pet play and world events can take over a critter for a while:
--   c.controlled = true  -> WorldEvents moves it (the catch race critter)
--   c.rally = Vector3    -> battle pets run to the world boss and fight it
--   c.fetch = {...}      -> the buddy is fetching a ball you threw
local onFetchDone -- set in the pet play section
local function endFetch(c, ok)
	local f = c.fetch
	if not f then return end
	c.fetch = nil
	c.speedBoost = nil
	if f.ball then f.ball:Destroy() end
	if ok and onFetchDone then onFetchDone(c) end
end
local function fetchStep(c)
	local f = c.fetch
	if os.clock() - f.started > 16 or not (f.ball and f.ball.Parent) then
		endFetch(c, false)
		return
	end
	if not f.landed then c.target = nil return end
	if f.stage == "run" then
		local b = f.ball.Position
		c.target = Vector3.new(b.X, 0, b.Z)
		c.speedBoost = 1.8
		if Vector3.new(b.X - c.pos.X, 0, b.Z - c.pos.Z).Magnitude < 2.5 then
			f.stage = "back"
			pop(c.body, "🎾")
		end
	else
		local spot, at = ownerSpot(c)
		if not spot then endFetch(c, false) return end
		c.target = Vector3.new(at.X, 0, at.Z)
		c.speedBoost = 1.8
		if Vector3.new(at.X - c.pos.X, 0, at.Z - c.pos.Z).Magnitude < 5.5 then
			c.target = nil
			endFetch(c, true)
		end
	end
end

local function brain(c)
	while c.alive do
		if c.controlled then
			task.wait(0.2)
		elseif c.fetch then
			fetchStep(c)
			task.wait(0.1)
		elseif c.rally then -- world boss: go fight
			if c.napping then c.napping = false; refreshTag(c) end
			c.speedBoost = 1.6
			walkTo(c, c.rally, 6)
			c.speedBoost = nil
			task.wait(0.3)
		elseif c.owner and c.record and isResting(c.record) then -- exhausted: nap in place
			c.target = nil
			c.napping = true
			refreshTag(c)
			task.wait(3)
		elseif isFollowing(c) then
			if c.napping then c.napping = false; refreshTag(c) end
			followStep(c)
			task.wait(0.15)
		elseif c.ride then -- 🐎 someone is riding it: stay under them
			if c.napping then c.napping = false; refreshTag(c) end
			c.target = nil
			local hrp = c.ride.Character and c.ride.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
				local moving = hrp.AssemblyLinearVelocity.Magnitude > 2
				c.pos = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
				if look.Magnitude > 0.1 then c.dir = look.Unit end
				c.groundY = nil
				c.rideMoving = moving
			end
			task.wait()
		elseif c.owner and c.record and c.record.NestUntil then -- 💕 cuddling in the Best Friends Nest
			if c.napping then c.napping = false; refreshTag(c) end
			if API.nestSpot then
				local spot = API.nestSpot(c)
				if spot and (c.pos - spot).Magnitude > 2 then walkTo(c, spot, 10) end
			end
			task.wait(1)
		elseif c.owner and c.record and c.record.NapUntil then -- tired: nap at the hut, wake up with a dream gift
			if os.time() >= c.record.NapUntil then
				wakeUp(c)
			else
				if not c.napping then
					walkTo(c, hutSpot(c), 15)
					c.napping = true
					refreshTag(c)
				end
				task.wait(1)
			end
		elseif c.owner and not isWorking(c) then -- on the bench: hang out by the bench
			if c.napping then c.napping = false; refreshTag(c) end
			walkTo(c, benchSpot(c), 8)
			task.wait(2 + math.random() * 3)
		elseif c.owner then
			if c.napping then c.napping = false; refreshTag(c) end
			local plot = findWork(c)
			if plot then
				claimed[plot] = c
				local arrived = walkTo(c, plot.Position + Vector3.new(0, 0, 3.4))
				if arrived and c.owner and needsWork(c, plot) then doJob(c, plot) end
				claimed[plot] = nil
				task.wait(CONFIG.JobPause)
			else
				walkTo(c, farmPoint(c), 8)
				task.wait(1 + math.random() * 2)
			end
		elseif os.clock() > c.leaveAt then
			removeCritter(c)
		else
			walkTo(c, farmPoint(c), 15)
			task.wait(1 + math.random() * 3)
		end
	end
end

-- Flying critters: take off, fly a few laps around the map (or the farm, once tamed), land,
-- hang around for a while, then take off again. Wild ones can only be befriended while landed.
local function skyPoint(c)
	local farm = c.owner and farmOf[c.owner]
	if farm then return randomIn(farm.ground.Position, 60, 60) end -- laps around its owner's farm
	local p = biomeParts[c.biome or "Meadow"] or meadow -- wild: laps over its home biome
	return randomIn(p.Position, p.Size.X / 2 + 30, p.Size.Z / 2 + 30)
end

local function setFlying(c, on)
	c.targetAlt = on and math.random(CONFIG.FlyHeight[1], CONFIG.FlyHeight[2]) or 0
	if on then
		c.model:SetAttribute("Flying", true)
		c.prompt.Enabled = false
	end
end

local function flyerBrain(c)
	local function landed() return (c.alt or 0) < 0.05 end
	local firstLanding = true -- start on the ground so players get a look first
	local function followFly() -- walk next to you, take off to catch up when you get far away
		while c.alive and isFollowing(c) and not isResting(c.record) and not c.fetch and not c.rally and not c.controlled do
			local d = followStep(c)
			if d > 30 and (c.targetAlt or 0) == 0 then
				setFlying(c, true)
				c.targetAlt = 12
			elseif d < 14 and (c.targetAlt or 0) > 0 then
				c.targetAlt = 0
			end
			if (c.targetAlt or 0) == 0 and landed() and c.model:GetAttribute("Flying") then
				c.model:SetAttribute("Flying", false)
				c.prompt.Enabled = true
			end
			task.wait(0.15)
		end
		c.speedBoost = nil
		c.targetAlt = 0
		while c.alive and not landed() do task.wait(0.1) end
		c.model:SetAttribute("Flying", false)
		c.prompt.Enabled = true
	end
	local function busyFly() -- fetching, or flying to the world boss: fly there low, then walk/land
		while c.alive and (c.fetch or c.rally) do
			local goal = c.fetch and c.fetch.ball and c.fetch.ball.Position or c.rally
			local d = goal and Vector3.new(goal.X - c.pos.X, 0, goal.Z - c.pos.Z).Magnitude or 0
			if d > 30 and (c.targetAlt or 0) == 0 then
				setFlying(c, true)
				c.targetAlt = 14
			elseif d < 14 and (c.targetAlt or 0) > 0 then
				c.targetAlt = 0
			end
			if (c.targetAlt or 0) == 0 and landed() and c.model:GetAttribute("Flying") then
				c.model:SetAttribute("Flying", false)
				c.prompt.Enabled = true
			end
			if c.fetch then
				fetchStep(c)
			elseif c.rally then
				c.target = Vector3.new(c.rally.X, 0, c.rally.Z)
				if d < 3 then c.target = nil end
			end
			task.wait(0.1)
		end
		c.targetAlt = 0
		while c.alive and not landed() do task.wait(0.1) end
		c.model:SetAttribute("Flying", false)
		c.prompt.Enabled = true
	end
	while c.alive do
		while c.controlled and c.alive do task.wait(0.2) end
		if c.fetch or c.rally then
			busyFly()
			firstLanding = false
		end
		if isFollowing(c) and not isResting(c.record) then
			followFly()
			firstLanding = false
		end
		if not c.owner and os.clock() > c.leaveAt then -- fly up and away
			setFlying(c, true)
			c.targetAlt = 90
			walkTo(c, skyPoint(c), 12)
			removeCritter(c)
			return
		end
		local tired = c.owner and c.record and isResting(c.record)
		if not tired and not firstLanding then
			-- take off and fly around
			setFlying(c, true)
			for _ = 1, math.random(CONFIG.FlyHops[1], CONFIG.FlyHops[2]) do
				if not c.alive then return end
				if isFollowing(c) or c.rally or c.fetch or c.controlled then break end
				walkTo(c, skyPoint(c), 25)
			end
			-- come down somewhere nice
			if isFollowing(c) or c.rally or c.fetch or c.controlled then continue end -- followFly takes it from here (still in the air)
			walkTo(c, farmPoint(c), 25)
			c.targetAlt = 0
			while c.alive and not landed() do task.wait(0.1) end
			if not c.alive then return end
		end
		firstLanding = false
		c.model:SetAttribute("Flying", false)
		c.prompt.Enabled = true
		c.napping = tired or nil
		refreshTag(c)
		-- stay a while, wandering a little
		local stayUntil = os.clock() + math.random(CONFIG.LandStay[1], CONFIG.LandStay[2])
		while c.alive and os.clock() < stayUntil do
			task.wait(3 + math.random() * 4)
			if c.alive and math.random() < 0.4 then
				walkTo(c, c.pos + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)), 4)
			end
			if not c.owner and os.clock() > c.leaveAt then break end
			if isFollowing(c) or c.rally or c.fetch or c.controlled then break end
		end
	end
end

local function bestBerry(player) -- only the 4 base berries are offered to wild critters
	for i = Data.BaseBerries, 1, -1 do
		local slot = basket(player, CROPS[i].Name)
		if slot and slot.Value > 0 then return CROPS[i], slot end
	end
end

-- Adds a pet to a player's saved collection (and the book). Returns the record.
-- extra: {Variant, SizeName} rolled when it appeared or hatched.
local function addPet(player, T, extra)
	local prof = profiles[player]
	extra = extra or {}
	local rec = {Id = prof.NextId, Species = T.Species, Xp = 0, Variant = extra.Variant, SizeName = extra.SizeName,
		Happy = Data.HappyStart, HappyAt = os.time()}
	prof.NextId += 1
	local onFarm = 0
	for _, r in prof.Pets do
		if not r.Stored then onFarm += 1 end
	end
	if onFarm >= Data.FarmPetCap(Data.FarmLevel(prof.FarmXp or 0)) then rec.Stored = true end
	table.insert(prof.Pets, rec)
	if API.onNewPet then task.spawn(API.onNewPet, player, prof, rec, T) end
	if not prof.Found[T.Species] then
		prof.Found[T.Species] = true
		local reward = Data.FindReward[T.Rarity]
		addCoins(player, reward)
		toast(player, ("📖 New critter in your book: %s! +%d coins"):format(T.Species, reward))
	end
	if rec.Variant then
		local shinies = 0
		for _, r in prof.Pets do
			if r.Variant then shinies += 1 end
		end
		if shinies >= 3 then giveTitle(player, "Shiny Hunter") end
		prof.FoundShiny[T.Species] = true
		notify:FireAllClients(("%s %s got a %s %s!"):format(Data.VariantByName[rec.Variant].Icon, player.DisplayName, rec.Variant:upper(), T.Species))
	end
	addFarmXp(player, 10)
	fillSlots(player)
	return rec
end

-- Petting: fills happiness, hearts on the critter, and sometimes the pet finds you a little gift.
local petCooldown = setmetatable({}, {__mode = "k"}) -- rec -> os.clock() of the last pet
local function petPet(player, rec, c)
	local now = os.clock()
	if petCooldown[rec] and now - petCooldown[rec] < Data.PetCooldown then return nil end
	petCooldown[rec] = now
	setHappy(rec, happiness(rec) + Data.PetHappy)
	if c then
		c.model:SetAttribute("PetAt", now) -- the client plays hearts and a happy move
		refreshTag(c)
	end
	local owner = c and c.owner or player
	if owner ~= player then return nil end -- petting a friend's pet makes it happy, gifts go to owners
	questEvent(player, "Pet", 1)
	if math.random() < Data.PetGiftChance then
		local got = grant(player, rollWeighted(Data.PetGifts))
		got.From = rec.Species
		revealEvent:FireClient(player, {Kind = "Prize", Prize = got})
		if c then pop(c.body, "🎁") end
		return got
	end
	return nil
end

local spawnCritter
local function tryBefriend(c, player)
	local T = c.type
	local prof = profiles[player]
	if not prof then return end
	if #prof.Pets >= Data.PetCap then
		toast(player, ("You have %d pets (the most)! Send one to the wild in the Pets menu."):format(Data.PetCap))
		return
	end
	if c.visitor and c.visitor ~= player then
		toast(player, ("This %s came to visit %s's farm."):format(T.Species, c.visitor.DisplayName))
		return
	end
	if c.visitor == player then -- 🌈 a visitor on your farm: free friend, no berry needed
		local rec = addPet(player, T, {Variant = c.variant, SizeName = c.sizeName})
		c.visitor, c.controlled = nil, nil
		setOwner(c, player, rec)
		pop(c.body, "💖")
		toast(player, ("🌈 %s %s decided to live on your farm!"):format(T.Rarity, T.Species))
		questEvent(player, "Befriend", 1)
		if rec.Stored then removeCritter(c) end
		pushState(player)
		return
	end
	local berry, slot = bestBerry(player)
	if not berry then
		toast(player, "Wild critters love berries! Harvest one first.")
		return
	end
	slot.Value -= 1
	local chance = math.min(0.95, Data.Rarities[T.Rarity].Catch * Data.BerryCatchBonus[berry.Tier] * (1 + (API.friendLuck and API.friendLuck(player) or 0)))
	if math.random() < chance then
		local rec = addPet(player, T, {Variant = c.variant, SizeName = c.sizeName})
		setOwner(c, player, rec)
		pop(c.body, "❤️")
		toast(player, ("%s loved your %s! Your %s %s %s.%s"):format(T.Species, berry.Name, T.Rarity, T.Species, T.JobText,
			rec.Stored and " (Your farm is full, so it went to 📦 storage.)" or ""))
		questEvent(player, "Befriend", 1)
		if rec.Stored then removeCritter(c) end
		pushState(player)
	else
		pop(c.body, "💨")
		toast(player, ("%s nibbled your %s but isn't sure yet (%d%% chance). Try again!"):format(T.Species, berry.Name, math.floor(chance * 100)))
	end
end

-- opts (wild only): {Variant, SizeName, Biome, Quiet}. Variant/size are rolled unless given (luckier on Star Nights).
function spawnCritter(T, owner, rec, opts)
	if rec and (rec.Stored or rec.Trip) then return nil end
	opts = opts or {}
	local variant, sizeName
	if rec then
		variant, sizeName = rec.Variant, rec.SizeName
	elseif opts.Variant or opts.SizeName then
		variant, sizeName = opts.Variant, opts.SizeName
	else
		variant, sizeName = rollVariant(weather == "StarNight" and Data.StarNightLuck or 1), rollSize()
	end
	local biome = opts.Biome or (Data.SpeciesBiomes[T.Species] and (function()
		for _, b in Data.Biomes do
			if table.find(b.Species, T.Species) then return b.Name end
		end
	end)()) or "Meadow"
	local stage = rec and Data.StageOf(rec, petLevel(rec))
	local model, body, tag, halfH = buildCritterModel(T, sizeName, variant, stage and stage.Scale, rec and rec.Tint)
	if T.Rarity == "Legendary" or variant == "Rainbow" then -- ✨ rare pets glow so everyone can see them
		local att = Instance.new("Attachment")
		att.Parent = body
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "Aura"
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.Color = ColorSequence.new(variant == "Rainbow" and Color3.fromRGB(255, 150, 255) or Color3.fromRGB(255, 225, 90))
		aura.LightEmission = 1
		aura.Rate = 6
		aura.Lifetime = NumberRange.new(1, 1.6)
		aura.Speed = NumberRange.new(1, 2)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Size = NumberSequence.new(0.5, 0)
		aura.Parent = att
		local light = Instance.new("PointLight")
		light.Color = aura.Color.Keypoints[1].Value
		light.Range = 10
		light.Brightness = 1.2
		light.Parent = body
	end
	local farm = owner and farmOf[owner]
	local start = farm and farmSpot(farm) or biomePoint(biome)
	local c = {type = T, model = model, body = body, tag = tag, pos = start, dir = Vector3.new(0, 0, -1),
		seed = math.random() * 10, version = 0, alive = true, halfH = halfH, isMesh = body:IsA("MeshPart"),
		variant = variant, sizeName = sizeName, biome = biome,
		rigged = CollectionService:HasTag(model, "RiggedCritter") or CollectionService:HasTag(model, "BlobCritter")}
	c.prompt = makePrompt(body, "", "")
	c.prompt.MaxActivationDistance = math.max(12, halfH * 2.5) -- big critters can be reached from further away
	setOwner(c, owner, rec)
	c.prompt.Triggered:Connect(function(player)
		if c.owner and c.record then
			petPet(player, c.record, c)
		elseif not c.owner then
			tryBefriend(c, player)
		end
	end)
	model:PivotTo(CFrame.new(start.X, GROUND_Y + halfH, start.Z))
	model.Parent = critterFolder
	critters[c] = true
	local where = Data.BiomeByName[biome] and Data.BiomeByName[biome].Icon or "🌼"
	if opts.Quiet then
		-- the world event announces it
	elseif not owner and variant then
		notify:FireAllClients(("%s A %s %s appeared! %s"):format(Data.VariantByName[variant].Icon, variant:upper(), T.Species, where))
	elseif not owner and (T.Rarity == "Legendary" or T.Rarity == "Epic") then
		notify:FireAllClients(("Wow! %s %s %s wandered in! %s"):format(T.Rarity == "Epic" and "An" or "A", T.Rarity, T.Species, where))
	end
	task.spawn(T.Flyer and flyerBrain or brain, c)
	return c
end

local function critterFor(rec)
	for c in critters do
		if c.record == rec then return c end
	end
end

function growCheck(player, prof, rec)
	if not rec.Raised then return end
	local stage, i = Data.StageOf(rec, petLevel(rec))
	if rec.StageI == i then return end
	local first = rec.StageI == nil
	rec.StageI = i
	if first then return end
	task.defer(function()
		local c = critterFor(rec)
		if c and not c.fetch and not c.ride then
			removeCritter(c)
			local nc = spawnCritter(Data.SpeciesByName[rec.Species], player, rec)
			if nc then nc.model:SetAttribute("PetAt", os.clock()) end
		end
		local name = rec.Name or rec.Species
		if stage.Name == "Adult" and not rec.Grown then
			rec.Grown = true
			local got = grant(player, Data.GrownGift)
			revealEvent:FireClient(player, {Kind = "Grown", Species = rec.Species, Name = name, Variant = rec.Variant, Outfit = rec.Outfit,
				Stage = stage.Name, Prize = got})
			if API.badge then API.badge(player, "GrownUp") end
		else
			revealEvent:FireClient(player, {Kind = "Grown", Species = rec.Species, Name = name, Variant = rec.Variant, Outfit = rec.Outfit,
				Stage = stage.Name})
		end
		toast(player, ("%s %s grew into a %s!"):format(stage.Icon, name, stage.Name))
	end)
end

RunService.Heartbeat:Connect(function(dt)
	local t = os.clock()
	for c in critters do
		local moving = false
		local alt = c.alt or 0
		if c.type.Flyer then -- climb or sink toward the target height, gently rising and dipping while cruising
			local goal = c.targetAlt or 0
			if goal > 0 and alt > 6 then goal += math.sin(t * 0.45 + c.seed) * CONFIG.FlyBob end
			local diff = goal - alt
			local rate = diff > 0 and CONFIG.FlyClimb or CONFIG.FlySink
			if alt < 4 and diff < 0 then rate *= 0.45 end -- slow down for a soft touchdown
			alt += math.clamp(diff, -rate * dt, rate * dt)
			c.alt = alt
		end
		if c.target then
			local flat = Vector3.new(c.target.X - c.pos.X, 0, c.target.Z - c.pos.Z)
			if flat.Magnitude > 0.3 then
				local want = flat.Unit
				local speed = c.type.Speed * levelMult(c) * (alt > 2 and CONFIG.FlySpeedMult or 1) * (c.speedBoost or 1)
				if alt > 2 and flat.Magnitude > 14 then
					-- in the air: turn gradually so flight paths curve (the client banks into the turn)
					local ang = math.atan2(c.dir:Cross(want).Y, c.dir:Dot(want))
					local maxTurn = CONFIG.FlyTurnRate * dt
					c.dir = (CFrame.Angles(0, math.clamp(ang, -maxTurn, maxTurn), 0) * c.dir).Unit
					c.pos += c.dir * speed * dt
				else
					c.dir = want
					c.pos += c.dir * math.min(flat.Magnitude, speed * dt)
				end
				moving = true
			end
		end
		if c.ride then moving = c.rideMoving or false end
		if moving ~= c.wasMoving then
			c.wasMoving = moving
			c.model:SetAttribute("Moving", moving)
		end
		local hop = moving and math.abs(math.sin(t * 9 + c.seed)) * 0.8 or math.abs(math.sin(t * 2 + c.seed)) * 0.1
		if c.rigged then hop = 0 end -- rigged critters walk with their legs instead of hopping
		if moving or not c.groundY then c.groundY = groundAt(c.pos.X, c.pos.Z) end -- stand on the real ground
		local p = Vector3.new(c.pos.X, c.groundY + c.halfH + hop + alt, c.pos.Z)
		c.model:PivotTo(CFrame.lookAt(p, p + c.dir))
		if c.type.Rainbow and not c.isMesh then c.body.Color = Color3.fromHSV((t * 0.15 + c.seed) % 1, 0.35, 1) end
		local f = c.fetch
		if f and f.stage == "back" and f.ball then -- carrying the ball home in its mouth
			f.ball.CFrame = CFrame.new(p + c.dir * (c.halfH * 0.6) + Vector3.new(0, c.halfH * 0.4, 0))
		end
	end
end)

local function wildCount(biome)
	local n = 0
	for c in critters do
		if not c.owner and not c.controlled and (not biome or c.biome == biome) then n += 1 end
	end
	return n
end
-- a wild critter for one biome (rarity weights, critter of the day x3)
local function rollBiomeSpecies(biome)
	local b = Data.BiomeByName[biome]
	local list = {}
	local total = 0
	for _, name in b.Species do
		local s = Data.SpeciesByName[name]
		if s then
			local w = speciesWeight(s)
			total += w
			table.insert(list, {s, w})
		end
	end
	local r = math.random() * total
	for _, e in list do
		r -= e[2]
		if r <= 0 then return e[1] end
	end
	return list[1][1]
end

---------------------------------------------------------------- menu actions (Pets, Book, Quests)
local function findRec(prof, id)
	for i, rec in prof.Pets do
		if rec.Id == id then return rec, i end
	end
end

local ACTIONS = {}
function ACTIONS.SelectSeed(player, prof, name)
	local crop = typeof(name) == "string" and CROP[name]
	if not crop then return nil end
	player:SetAttribute("Seed", name) -- planting uses your seed bag (Puffberry is free)
	return nil
end
-- Pet from the profile screen (same as the world prompt).
function ACTIONS.Pet(player, prof, id)
	local rec = findRec(prof, id)
	if not rec or rec.Trip then return nil end
	return petPet(player, rec, critterFor(rec))
end
-- Pick (or stop) the pet that follows you around.
function ACTIONS.Follow(player, prof, id)
	local rec = findRec(prof, id)
	if not rec or rec.Trip then return nil end
	local old = prof.FollowId and findRec(prof, prof.FollowId)
	prof.FollowId = prof.FollowId ~= id and id or nil
	for _, r in {old, rec} do -- interrupt whatever they were walking to
		local c = r and critterFor(r)
		if c then c.version += 1; c.speedBoost = nil end
	end
	return prof.FollowId and ("👣 " .. rec.Species) or nil
end
-- Put an unlocked outfit on a pet (nil takes it off).
function ACTIONS.Wear(player, prof, id, outfit)
	local rec = findRec(prof, id)
	if not rec then return nil end
	if outfit ~= nil and not (Data.OutfitByName[outfit] and prof.Outfits[outfit]) then return "🔒" end
	rec.Outfit = outfit
	local c = critterFor(rec)
	if c then refreshTag(c) end
	return nil
end
---------------------------------------------------------------- travel and farm visits
function ACTIONS.GoHome(player, prof)
	local farm = farmOf[player]
	if farm and farm.home then teleportTo(player, farm.home.Position) end
end
function ACTIONS.Visit(player, prof, userId)
	for _, farm in farms do
		if farm.owner and farm.owner.UserId == userId and farm.home then
			teleportTo(player, farm.home.Position + farm.home.CFrame.LookVector * -6)
			return nil
		end
	end
	return "🏡 ❔"
end
function ACTIONS.Travel(player, prof, where)
	if where == "Plaza" then
		local spawn = root:FindFirstChild("Spawn")
		teleportTo(player, spawn and spawn.Position or Vector3.new(0, 0, 20))
	elseif biomeParts[where] then
		local p = biomeParts[where].Position
		teleportTo(player, Vector3.new(p.X, GROUND_Y, p.Z))
	end
end
-- 🚀 on the event banner: jump close to the event (not on top of it)
function ACTIONS.TravelEvent(player, prof)
	local pos = workspace:GetAttribute("EventPos")
	if typeof(pos) ~= "Vector3" or workspace:GetAttribute("Event") == "CatchRace" then return nil end
	local a = math.random() * math.pi * 2
	teleportTo(player, Vector3.new(pos.X + math.cos(a) * 32, GROUND_Y, pos.Z + math.sin(a) * 32))
end
-- every farm with an owner: for the 🗺️ menu (sorted by likes there)
function ACTIONS.Farms(player, prof)
	local list = {}
	for _, farm in farms do
		local o = farm.owner
		local op = o and profiles[o]
		if op then
			table.insert(list, {UserId = o.UserId, Name = o.DisplayName, Likes = op.Likes or 0, Level = Data.FarmLevel(op.FarmXp),
				Mine = o == player, Liked = prof.LikeDay == today() and prof.LikedToday[tostring(o.UserId)] or false})
		end
	end
	return list
end

---------------------------------------------------------------- fusion: 3 of a kind -> the next variant
function ACTIONS.Fuse(player, prof, ids)
	if type(ids) ~= "table" or #ids ~= Data.FuseCount then return {Error = "🧪 3"} end
	local recs, species, variant = {}, nil, nil
	for _, id in ids do
		local rec = findRec(prof, id)
		if not rec or rec.Trip or table.find(recs, rec) then return {Error = "🧪 ❌"} end
		if species and (rec.Species ~= species or (rec.Variant or "") ~= variant) then return {Error = "🧪 ❌"} end
		species, variant = rec.Species, rec.Variant or ""
		table.insert(recs, rec)
	end
	local nextVariant = Data.FuseNext[variant]
	if not nextVariant then return {Error = "🌈 MAX"} end
	local xp, outfit, size, follow, gear = 0, nil, nil, false, nil
	for _, rec in recs do
		xp = math.max(xp, rec.Xp or 0)
		outfit = outfit or rec.Outfit
		size = size or rec.SizeName
		gear = gear or rec.GearId
		if prof.FollowId == rec.Id then follow = true end
		local c = critterFor(rec)
		if c then removeCritter(c) end
		local _, i = findRec(prof, rec.Id)
		table.remove(prof.Pets, i)
	end
	local T = Data.SpeciesByName[species]
	local rec = addPet(player, T, {Variant = nextVariant, SizeName = size})
	rec.Xp, rec.Outfit, rec.GearId = xp, outfit, gear
	setHappy(rec, 100)
	if follow then prof.FollowId = rec.Id end
	spawnCritter(T, player, rec)
	return {Species = species, Variant = nextVariant, SizeName = size, Outfit = outfit}
end

---------------------------------------------------------------- pet play: tricks, fetch, rubs (for your buddy)
local playState = setmetatable({}, {__mode = "k"}) -- player -> {fetchCombo, trickAt, rubAt}
local function play(player)
	playState[player] = playState[player] or {fetchCombo = 0, trickAt = 0, rubAt = 0}
	return playState[player]
end
local function buddy(player, prof)
	local rec = prof.FollowId and findRec(prof, prof.FollowId)
	return rec, rec and critterFor(rec)
end
function ACTIONS.Trick(player, prof, name)
	local rec, c = buddy(player, prof)
	if not c then return "👣 ❔" end
	local trick
	for _, t in Data.Tricks do
		if t.Name == name then trick = t end
	end
	if not trick then return nil end
	if petLevel(rec) < trick.Level then return ("🔒 Lv %d"):format(trick.Level) end
	local st = play(player)
	if os.clock() - st.trickAt < 1.2 then return nil end
	st.trickAt = os.clock()
	c.model:SetAttribute("Trick", trick.Name)
	c.model:SetAttribute("TrickAt", os.clock()) -- the client animator plays it
	setHappy(rec, happiness(rec) + Data.TrickHappy)
	refreshTag(c)
	return nil
end
-- throw a ball (dir = where you're looking); your buddy runs to get it and brings it back
function ACTIONS.Throw(player, prof, dir)
	local rec, c = buddy(player, prof)
	if not c then return "👣 ❔" end
	if c.fetch then return nil end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or typeof(dir) ~= "Vector3" then return nil end
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = dir.Magnitude > 0.01 and dir.Unit or hrp.CFrame.LookVector
	local from = hrp.Position + Vector3.new(0, 2, 0)
	local to = Vector3.new(hrp.Position.X, GROUND_Y + 0.8, hrp.Position.Z) + dir * (22 + math.random() * 10)
	local ball = part(workspace, {Name = "FetchBall", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CanCollide = false, CanQuery = false,
		Color = Color3.fromRGB(200, 255, 80), Material = Enum.Material.SmoothPlastic, Position = from})
	c.fetch = {ball = ball, stage = "run", started = os.clock(), landed = false}
	c.version += 1 -- stop whatever it was walking to
	task.spawn(function() -- arc through the air, then a little bounce
		local t0 = os.clock()
		while os.clock() - t0 < 0.9 and ball.Parent do
			local f = (os.clock() - t0) / 0.9
			ball.Position = from:Lerp(to, f) + Vector3.new(0, math.sin(f * math.pi) * 10, 0)
			task.wait()
		end
		if c.fetch and c.fetch.ball == ball then c.fetch.landed = true end
		local t1 = os.clock()
		while os.clock() - t1 < 0.4 and ball.Parent and c.fetch and c.fetch.stage == "run" do
			ball.Position = to + Vector3.new(0, math.abs(math.sin((os.clock() - t1) / 0.4 * math.pi)) * 1.5, 0)
			task.wait()
		end
	end)
	return nil
end
function onFetchDone(c)
	local player, rec = c.owner, c.record
	if not player or not rec then return end
	setHappy(rec, happiness(rec) + Data.FetchHappy)
	rec.Xp = (rec.Xp or 0) + 1
	c.model:SetAttribute("PetAt", os.clock())
	refreshTag(c)
	questEvent(player, "Fetch", 1)
	local st = play(player)
	st.fetchCombo += 1
	revealEvent:FireClient(player, {Kind = "Fetch", Combo = st.fetchCombo})
	if st.fetchCombo % Data.FetchGiftEvery == 0 then
		local got = grant(player, rollWeighted(Data.PetGifts))
		got.From = rec.Species
		revealEvent:FireClient(player, {Kind = "Prize", Prize = got})
		pop(c.body, "🎁")
	end
end
-- finished the rub mini game in the buddy panel
function ACTIONS.Rub(player, prof, id)
	local rec = findRec(prof, id)
	if not rec then return nil end
	local st = play(player)
	if os.clock() - st.rubAt < Data.RubCooldown then return nil end
	st.rubAt = os.clock()
	setHappy(rec, happiness(rec) + Data.RubHappy)
	local c = critterFor(rec)
	if c then
		c.model:SetAttribute("PetAt", os.clock())
		refreshTag(c)
	end
	questEvent(player, "Pet", 3)
	if math.random() < Data.PetGiftChance * 3 then
		local got = grant(player, rollWeighted(Data.PetGifts))
		got.From = rec.Species
		revealEvent:FireClient(player, {Kind = "Prize", Prize = got})
	end
	return nil
end

-- Lucky spin: returns the slot index (for the reel) and what you got.
function ACTIONS.Spin(player, prof)
	if (prof.Spins or 0) < 1 then return {Error = "🎡 0"} end
	prof.Spins -= 1
	local prize, index = rollWeighted(Data.SpinPrizes)
	return {Index = index, Prize = grant(player, prize)}
end
function ACTIONS.Trip(player, prof, id, index)
	local rec = findRec(prof, id)
	local dest = Data.Expeditions[index]
	if not rec or not dest or rec.Trip then return "That critter can't go right now." end
	if isResting(rec) then return ("😴 %s is resting."):format(rec.Species) end
	rec.Trip = {Index = index, ReturnAt = os.time() + math.ceil(dest.Secs / timeScale())}
	local c = critterFor(rec)
	if c then removeCritter(c) end
	fillSlots(player)
	return ("%s set off for %s! 🎒"):format(rec.Species, dest.Name)
end
function ACTIONS.TripClaim(player, prof, id)
	local rec = findRec(prof, id)
	if not rec or not rec.Trip or os.time() < rec.Trip.ReturnAt then return "Not back yet!" end
	local T = Data.SpeciesByName[rec.Species]
	local dest = Data.Expeditions[rec.Trip.Index] or Data.Expeditions[1]
	local chance = Data.TripChance(Data.PetPower(T.Rarity, petLevel(rec)), dest.Need)
	-- result is a table so the booth can show it as pictures
	local result = {Species = rec.Species, Place = rec.Trip.Index}
	if math.random() < chance then
		addCoins(player, dest.Coins)
		local slot = basket(player, dest.Berry)
		if slot then slot.Value += dest.Berries end
		result.Outcome, result.Coins, result.Berry, result.Count = "Great", dest.Coins, dest.Berry, dest.Berries
		if dest.Res then -- bench pets bring back the resources of the place they explored
			local found = {}
			for _, r in dest.Res do
				local n = math.random(math.ceil(dest.ResAmount / 2), dest.ResAmount)
				addRes(player, r, n)
				table.insert(found, Data.ResByName[r].Icon .. " +" .. n)
			end
			toast(player, ("🎒 %s brought back %s"):format(rec.Species, table.concat(found, "  ")))
		end
		if math.random() < dest.EggChance then
			addEgg(prof, dest.Egg)
			result.Egg = dest.Egg
		end
		if Data.SeasonalOn() and math.random() < Data.Seasonal.Chance then -- limited egg of the season
			addEgg(prof, Data.Seasonal.Egg)
			result.Egg = Data.Seasonal.Egg
		end
		rec.Xp = (rec.Xp or 0) + 2 + dest.Stars
	elseif chance < Data.RiskyChance then -- risky trip failed: nothing, and the pet is worn out
		rec.RestFrom = os.time()
		rec.RestUntil = os.time() + math.ceil(Data.PetRestSecs / timeScale())
		result.Outcome = "Exhausted"
	else
		local gift = math.max(5, math.floor(dest.Coins * 0.25))
		addCoins(player, gift)
		result.Outcome, result.Coins = "Lost", gift
		rec.Xp = (rec.Xp or 0) + 1
	end
	rec.Trip = nil
	addFarmXp(player, 5)
	spawnCritter(T, player, rec)
	fillSlots(player)
	return result
end
-- Feed one berry to a pet for XP (fancier berries give more).
function ACTIONS.Feed(player, prof, id, cropName)
	local rec = findRec(prof, id)
	local crop = CROP[cropName]
	if not rec or not crop then return nil end
	if petLevel(rec) >= Data.MaxLevel then return ("⭐ %s is max level!"):format(rec.Species) end
	local slot = basket(player, crop.Name)
	if not slot or slot.Value < 1 then return ("No %s %s"):format(crop.Icon, crop.Name) end
	slot.Value -= 1
	local before = petLevel(rec)
	local fav = Data.FavFood(rec) == crop.Name
	rec.Xp = (rec.Xp or 0) + crop.Xp * (fav and Data.FavXpMult or 1)
	setHappy(rec, fav and 100 or happiness(rec) + Data.FeedHappy * math.min(crop.Tier, 4))
	questEvent(player, "Feed", 1)
	local c = critterFor(rec)
	if c then
		pop(c.body, fav and "😍" or crop.Icon)
		if fav then c.model:SetAttribute("PetAt", os.clock()) end
		refreshTag(c)
	end
	local msg
	if fav then
		local first = not rec.FavKnown
		rec.FavKnown = true
		msg = first and ("😍 %s LOVES %s %s! (its favorite food: x%d XP)"):format(rec.Name or rec.Species, crop.Icon, crop.Name, Data.FavXpMult)
			or ("😍 %s's favorite! x%d XP"):format(rec.Name or rec.Species, Data.FavXpMult)
	end
	if petLevel(rec) > before then return ("⬆️ %s Lv %d!%s"):format(rec.Name or rec.Species, petLevel(rec), msg and ("  " .. msg) or "") end
	return msg
end

function ACTIONS.Release(player, prof, id)
	local rec, i = findRec(prof, id)
	if not rec or rec.Trip or rec.NestUntil then return "You can't let that critter go right now." end
	if #prof.Pets <= 1 then return "Keep at least one pet!" end
	if API.stopRide then API.stopRide(player, rec) end
	table.remove(prof.Pets, i)
	if prof.FollowId == id then prof.FollowId = nil end
	fillSlots(player)
	local T0 = Data.SpeciesByName[rec.Species]
	local gift = math.floor((Data.ReleaseGift[T0.Rarity] or 10) * (1 + 0.1 * (petLevel(rec) - 1)) * variantMult(rec))
	addCoins(player, gift)
	if Data.Rarities[T0.Rarity].Order >= 3 then prof.Spins = (prof.Spins or 0) + 1 end
	local c = critterFor(rec)
	if c then
		setOwner(c, nil, nil)
		c.biome = (Data.SpeciesBiomes[rec.Species] and c.biome) or "Meadow"
		c.pos = farmPoint(c)
	end
	return ("🌿 %s hopped back to the wild. Thank-you gift: 💰 %d%s"):format(rec.Name or rec.Species, gift,
		Data.Rarities[T0.Rarity].Order >= 3 and " + 🎁 1 prize pack" or "")
end
function ACTIONS.Hatch(player, prof, id)
	for i, egg in prof.Eggs do
		if egg.Id == id then
			if not egg.HatchAt or os.time() < egg.HatchAt then return "⏱" end
			if #prof.Pets >= Data.PetCap then return ("You have %d pets (the most). Send one to the wild first."):format(Data.PetCap) end
			local weights = (Data.Eggs[egg.Kind] or Data.Eggs.Mystery).Weights
			local lucky = false
			prof.Luck = prof.Luck or 0
			if prof.Luck >= Data.LuckMax then -- 🍀 luck meter full: guaranteed Epic or better
				weights, lucky = Data.LuckPrize, true
			end
			local rarity = rollFromWeights(weights)
			local total = 0
			for _, w in weights do total += w end
			local options = {}
			if egg.Kind == "Friend" and egg.A then -- a nest baby: one of its two parents, or rarely a secret mix
				local child
				for _, mix in Data.NestMixes do
					if (mix.A == egg.A and mix.B == egg.B) or (mix.A == egg.B and mix.B == egg.A) then
						if math.random() < Data.MixChance then child = mix.Child end
					end
				end
				if not child and math.random() < Data.AnyMixChance then child = Data.NestMixes[math.random(#Data.NestMixes)].Child end
				if child then
					options = {Data.SpeciesByName[child]}
				else
					options = {Data.SpeciesByName[egg.A], Data.SpeciesByName[egg.B]}
				end
				rarity = options[1].Rarity
			else
				for _, s in Data.Species do
					if s.Rarity == rarity and not s.Secret then table.insert(options, s) end
				end
			end
			if #options == 0 then return "Egg not ready." end
			if Data.Rarities[rarity].Order >= 3 then prof.Luck = 0 else prof.Luck = math.min(Data.LuckMax, prof.Luck + 1) end
			table.remove(prof.Eggs, i)
			startEggs(prof)
			prof.Hatched = (prof.Hatched or 0) + 1
			if prof.Hatched >= 10 then giveTitle(player, "Egg Hatcher") end
			local T = options[math.random(#options)]
			local isNew = not prof.Found[T.Species]
			local luck = (Data.EggLuck[egg.Kind] or 1) * (1 + (API.friendLuck and API.friendLuck(player) or 0)) * (egg.Shiny and Data.FriendShinyBoost or 1)
			local variant = rollVariant(luck)
			local rec = addPet(player, T, {Variant = variant, SizeName = rollSize()})
			rec.Raised = true -- hatched babies grow up
			if egg.Tint then rec.Tint = egg.Tint end
			-- "1 in X": how lucky this exact pet was
			local p = (weights[rarity] or 1) / math.max(1, total) / #options
			if variant then p *= Data.VariantByName[variant].Chance * luck end
			rec.Odds = math.floor(1 / math.max(p, 1e-7))
			if T.Rarity == "Legendary" or variant == "Rainbow" or T.Secret then
				notify:FireAllClients(("🎉 %s hatched a %s%s %s! (%s)"):format(player.DisplayName, variant and (variant:upper() .. " ") or "",
					T.Secret and "SECRET" or T.Rarity:upper(), T.Species, Data.OddsText(rec.Odds)))
			end
			local eggInfo = Data.Eggs[egg.Kind]
			if eggInfo and eggInfo.Outfit then -- limited eggs come with a limited hat
				rec.Outfit = eggInfo.Outfit
				prof.Outfits[eggInfo.Outfit] = true
			end
			spawnCritter(T, player, rec)
			questEvent(player, "Befriend", 1)
			questEvent(player, "Hatch", 1)
			if API.onHatch then task.spawn(API.onHatch, player, prof, rec, T) end
			pushState(player)
			-- a table: the HUD plays the tap-to-crack card reveal
			return {Species = T.Species, Rarity = T.Rarity, Variant = rec.Variant, SizeName = rec.SizeName, Egg = egg.Kind, New = isNew,
				Odds = rec.Odds, Lucky = lucky, Luck = prof.Luck, Secret = T.Secret, Tint = rec.Tint, Stored = rec.Stored}
		end
	end
	return "Egg not found."
end
function ACTIONS.ClaimQuest(player, prof, index)
	local q = prof.Quests and prof.Quests[index]
	if not q or q.Claimed or q.Progress < q.Count then return "Not finished yet." end
	q.Claimed = true
	addCoins(player, q.Reward)
	return ("Quest reward: +%d coins!"):format(q.Reward)
end
function ACTIONS.Equip(player, prof, petId, gearId)
	local rec = findRec(prof, petId)
	if not rec then return "Pet not found." end
	if gearId == nil then
		rec.GearId = nil
		return ("%s took off its gear."):format(rec.Species)
	end
	local g = findGear(prof, gearId)
	if not g then return "Gear not found." end
	for _, other in prof.Pets do
		if other.GearId == gearId then other.GearId = nil end
	end
	rec.GearId = gearId
	return ("%s is now wearing %s!"):format(rec.Species, Data.GearText(g))
end

-- Server-run auto battle. Returns win, log of hits, and the starting units.
local function simulate(team, enemies)
	local units = {}
	local function add(side, i, name, stats, extra)
		local u = {Side = side, Idx = i, Name = name, HP = stats.HP, MaxHP = stats.HP, ATK = stats.ATK, Interval = stats.Interval,
			Next = stats.Interval * (0.3 + math.random() * 0.7), Tank = extra.Tank, Color = extra.Color, Boss = extra.Boss}
		table.insert(units, u)
		return u
	end
	local start = {Team = {}, Enemies = {}}
	for i, p in team do
		add("T", i, p.Name, p.Stats, {Tank = p.Class == "Tank"})
		table.insert(start.Team, {Name = p.Name, Species = p.Name, HP = p.Stats.HP, Rarity = p.Rarity, Class = p.Class, Level = p.Level})
	end
	for i, e in enemies do
		add("E", i, e.Name, e, {Color = e.Color, Boss = e.Boss})
		table.insert(start.Enemies, {Name = e.Name, HP = e.HP, Color = e.Color, Boss = e.Boss})
	end
	local log, t = {}, 0
	local function alive(side)
		local list = {}
		for _, u in units do
			if u.Side == side and u.HP > 0 then table.insert(list, u) end
		end
		return list
	end
	while t < 90 do
		local u
		for _, x in units do
			if x.HP > 0 and (not u or x.Next < u.Next) then u = x end
		end
		t = u.Next
		local foes = alive(u.Side == "T" and "E" or "T")
		if #foes == 0 then break end
		local target
		if u.Side == "E" then -- enemies like to hit tanks
			local total = 0
			for _, f in foes do total += f.Tank and 3 or 1 end
			local r = math.random() * total
			for _, f in foes do
				r -= f.Tank and 3 or 1
				if r <= 0 then target = f break end
			end
			target = target or foes[1]
		else
			target = foes[math.random(#foes)]
		end
		local crit = math.random() < 0.1
		local dmg = math.max(1, math.floor(u.ATK * (0.85 + math.random() * 0.3) * (crit and 1.6 or 1)))
		target.HP = math.max(0, target.HP - dmg)
		table.insert(log, {math.floor(t * 100) / 100, u.Side, u.Idx, target.Idx, dmg, crit, target.HP})
		u.Next = t + u.Interval
		if #alive("E") == 0 or #alive("T") == 0 then break end
	end
	return #alive("E") == 0, log, start
end

function ACTIONS.Raid(player, prof, raidIndex, petIds)
	local raid = Data.Raids[raidIndex]
	if not raid or type(petIds) ~= "table" then return {Error = "Pick a raid and a team first."} end
	if #petIds < Data.RaidTeamMin or #petIds > Data.RaidTeamMax then
		return {Error = ("Pick %d to %d battle pets."):format(Data.RaidTeamMin, Data.RaidTeamMax)}
	end
	updateEnergy(prof)
	if prof.Energy < 1 then return {Error = "Out of energy! It refills 1 every hour."} end
	local team, recs, seen = {}, {}, {}
	for _, id in petIds do
		local rec = findRec(prof, id)
		if not rec or seen[id] or rec.Trip or isResting(rec) or rec.NestUntil then
			return {Error = "Only pets that are at home can join a raid."}
		end
		seen[id] = true
		local T = Data.SpeciesByName[rec.Species]
		table.insert(recs, rec)
		table.insert(team, {Name = rec.Species, Stats = petStats(prof, rec), Class = T.Class, Rarity = T.Rarity, Level = petLevel(rec)})
	end
	if prof.Energy >= Data.EnergyMax then prof.EnergyAt = os.time() end
	prof.Energy -= 1
	local win, log, start = simulate(team, raid.Enemies)
	local loot = {}
	if win then
		addCoins(player, raid.Coins)
		table.insert(loot, {Type = "Coins", Amount = raid.Coins})
		for _ = 1, raid.GearDrops do
			local g = {Id = prof.NextId, Kind = math.random(#Data.Gear), Tier = math.min(#Data.GearTiers, raidIndex), Rarity = rollFromWeights(raid.Gear)}
			prof.NextId += 1
			table.insert(prof.Gear, g)
			table.insert(loot, {Type = "Gear", Kind = g.Kind, Rarity = g.Rarity})
		end
		for _, rec in recs do rec.Xp = (rec.Xp or 0) + 2 + raid.Stars end
	else
		local consolation = math.floor(raid.Coins * 0.2)
		addCoins(player, consolation)
		table.insert(loot, {Type = "Coins", Amount = consolation})
		for _, rec in recs do rec.Xp = (rec.Xp or 0) + 1 end
	end
	return {Win = win, Log = log, Start = start, Loot = loot, Raid = raidIndex}
end

-- Studio-only dev menu. Does nothing in a live game.
local DEV = {}
function DEV.Coins(player) addCoins(player, 10000) return "+10,000 coins" end
function DEV.Berries(player)
	for _, c in CROPS do basket(player, c.Name).Value += 50 end
	return "+50 of every berry"
end
function DEV.Energy(player, prof) prof.Energy = Data.EnergyMax return "Energy full" end
function DEV.Battlers(player, prof)
	for _, T in Data.Species do
		if T.Role == "Battler" and countRole(prof, "Battler") < Data.BattlerCap then
			spawnCritter(T, player, addPet(player, T))
		end
	end
	return "Battlers added (up to 6)"
end
function DEV.Workers(player, prof)
	prof.Built.CritterHut, prof.Built.FruitStand = true, true
	showBuilding("CritterHut")
	showBuilding("FruitStand")
	for _, T in Data.Species do
		if T.Role == "Worker" and countRole(prof, "Worker") < capFor(player, "Worker") then
			spawnCritter(T, player, addPet(player, T))
		end
	end
	return "Both buildings built and workers added"
end
function DEV.Gear(player, prof)
	for k = 1, #Data.Gear do
		for _, r in {"Rare", "Epic", "Legendary"} do
			table.insert(prof.Gear, {Id = prof.NextId, Kind = k, Rarity = r})
			prof.NextId += 1
		end
	end
	return "Gear added"
end
function DEV.LevelUp(player, prof)
	for _, rec in prof.Pets do rec.Xp = (rec.Xp or 0) + Data.XpPerLevel end
	for c in critters do
		if c.owner == player then refreshTag(c) end
	end
	return "All pets +1 level"
end
function DEV.Book(player, prof)
	for _, T in Data.Species do prof.Found[T.Species] = true end
	return "Critter Book filled"
end
function DEV.FinishTimers(player, prof)
	for _, rec in prof.Pets do
		if rec.Trip then rec.Trip.ReturnAt = os.time() end
		rec.RestUntil = nil
		if rec.NapUntil then rec.NapUntil = os.time() end
	end
	for _, egg in prof.Eggs do egg.HatchAt = os.time() end
	return "Trips back and eggs ready"
end
function DEV.Eggs(player, prof)
	for _, kind in {"Mystery", "Crystal", "Lava"} do
		table.insert(prof.Eggs, {Id = prof.NextId, Kind = kind, HatchAt = os.time()})
		prof.NextId += 1
	end
	return "3 eggs added (ready to hatch)"
end
function DEV.FastTime()
	local fast = (workspace:GetAttribute("CritterTimeScale") or 1) == 1
	workspace:SetAttribute("CritterTimeScale", fast and 600 or nil)
	return fast and "Fast timers ON (1 hour = 6 seconds)" or "Fast timers OFF"
end
function DEV.Spawn(player, prof, rarity)
	local options = {}
	for _, s in Data.Species do
		if s.Rarity == rarity then table.insert(options, s) end
	end
	if #options == 0 then return "Unknown rarity" end
	local c = spawnCritter(options[math.random(#options)])
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then c.pos = Vector3.new(root.Position.X + 6, 0, root.Position.Z) end
	return ("Spawned a wild %s next to you"):format(c.type.Species)
end
-- Dev pet picker: spawn one species wild next to you, or add it straight to your pets
local function nextToPlayer(player, c)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then c.pos = Vector3.new(hrp.Position.X + 6 + c.halfH, 0, hrp.Position.Z) end
end
function DEV.SpawnSpecies(player, prof, name)
	local T = Data.SpeciesByName[name]
	if not T then return "Unknown critter" end
	nextToPlayer(player, spawnCritter(T))
	return ("Spawned a wild %s next to you"):format(name)
end
function DEV.GivePet(player, prof, name)
	local T = Data.SpeciesByName[name]
	if not T then return "Unknown critter" end
	local c = spawnCritter(T, player, addPet(player, T)) -- dev tool: ignores the pet caps
	nextToPlayer(player, c)
	return ("%s is now your pet!"):format(name)
end
function DEV.ShinySpawn(player, prof)
	local T = Data.Species[math.random(#Data.Species)]
	local variant = math.random() < 0.5 and "Shiny" or "Rainbow"
	nextToPlayer(player, spawnCritter(T, nil, nil, {Variant = variant, SizeName = Data.Sizes[math.random(#Data.Sizes)].Name}))
	return ("Spawned a wild %s %s"):format(variant, T.Species)
end
function DEV.Spins(player, prof) prof.Spins += 5 return "+5 spins" end
function DEV.Outfits(player, prof)
	for _, o in Data.Outfits do prof.Outfits[o.Name] = true end
	return "All outfits unlocked"
end
function DEV.FarmLevel(player, prof)
	local lv = Data.FarmLevel(prof.FarmXp)
	local nxt = Data.FarmLevelXp[lv + 1]
	if not nxt then return "Farm is max level" end
	addFarmXp(player, nxt - prof.FarmXp)
	return nil
end
local spawnPresent -- set in the presents section below
function DEV.Present(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	spawnPresent(hrp and Vector3.new(hrp.Position.X + 6, 0, hrp.Position.Z) or nil)
	return "🎁"
end
function DEV.Sad(player, prof)
	for _, rec in prof.Pets do setHappy(rec, 10) end
	for c in critters do
		if c.owner == player then refreshTag(c) end
	end
	return "All pets are sad now (pet them!)"
end
function DEV.Weather(player, prof, name)
	if weather then return "A weather event is already running" end
	devWeather = name
	return ("Starting %s..."):format(name)
end
function DEV.Reset(player, prof)
	for c in critters do
		if c.owner == player then removeCritter(c) end
	end
	local fresh = defaultProfile()
	for k in prof do prof[k] = nil end
	for k, v in fresh do prof[k] = v end
	prof.LastDay, prof.QuestDay = today(), today()
	prof.Quests = makeQuests(today(), player.UserId)
	stat(player, "Coins").Value = CONFIG.StartCoins
	for _, c in CROPS do basket(player, c.Name).Value = 0 end
	farmAttrs(player, prof)
	player:SetAttribute("Seed", Data.FarmCrop)
	return "Your save was reset (buildings stay until the server restarts)"
end

function ACTIONS.Dev(player, prof, cmd, arg)
	if not RunService:IsStudio() then return "Dev tools only work in Studio." end
	local fn = DEV[cmd] or (API.DEV_EXTRA and API.DEV_EXTRA[cmd])
	return fn and fn(player, prof, arg) or "Unknown dev command"
end

function ACTIONS.Refresh() end

actionFn.OnServerInvoke = function(player, action, ...)
	local prof = profiles[player]
	local fn = ACTIONS[action]
	if not prof or not fn then return nil end
	local ok, msg = pcall(fn, player, prof, ...)
	pushState(player)
	if not ok then
		warn("[CritterAcres] action failed", action, msg)
		return nil
	end
	return msg
end

---------------------------------------------------------------- join / leave
local function onJoin(player)
	local prof, loaded = loadProfile(player)
	if not player.Parent then return end
	profiles[player] = prof
	canSave[player] = loaded
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, s in {{"Coins", prof.Coins}, {"Critters", #prof.Pets}} do
		local v = Instance.new("IntValue")
		v.Name, v.Value = s[1], s[2]
		v.Parent = ls
	end
	ls.Parent = player
	local b = Instance.new("Folder")
	b.Name = "Basket"
	for _, c in CROPS do
		local v = Instance.new("IntValue")
		v.Name, v.Value = c.Name, prof.Basket[c.Name] or 0
		v.Parent = b
	end
	b.Parent = player
	player:SetAttribute("Seed", CROP[prof.Seed] and prof.Seed or CROPS[1].Name)
	prof.Outfits = prof.Outfits or {}
	prof.Outfits[Data.StarterOutfit] = true
	prof.FoundShiny = prof.FoundShiny or {}
	farmAttrs(player, prof)

	local messages = {}
	if not loaded then
		table.insert(messages, "Saving is off right now (publish the game and allow API access to save).")
	end
	-- daily streak gift and fresh quests
	local day = today()
	if prof.LastDay ~= day then
		prof.Streak = (prof.LastDay == day - 1) and prof.Streak + 1 or 1
		prof.LastDay = day
		local gift = math.min(prof.Streak, 7) * Data.StreakGift
		addCoins(player, gift)
		prof.Spins = (prof.Spins or 0) + Data.DailySpins
		prof.FreePacks = (prof.FreePacks or 0) + Data.DailyFreePacks
		table.insert(messages, ("🎁 Day %d login streak! +%d coins  🎡 +%d"):format(prof.Streak, gift, Data.DailySpins))
	end
	if prof.QuestDay ~= day or not prof.Quests then
		prof.Quests = makeQuests(day, player.UserId)
		prof.QuestDay = day
		table.insert(messages, "📜 New daily quests are ready!")
	end
	-- offline earnings from pets that stayed home
	if prof.LastOnline > 0 then
		local away = math.min(os.time() - prof.LastOnline, Data.OfflineCapHours * 3600)
		if away >= 120 then
			local rate = 0
			for _, rec in prof.Pets do
				local T = Data.SpeciesByName[rec.Species]
				if not rec.Trip and not rec.Stored then
					rate += Data.OfflineRate[T.Rarity] * (1 + Data.LevelBonus * (petLevel(rec) - 1))
				end
			end
			local earned = math.floor(rate * away / 60)
			if earned > 0 then
				prof.Pile = (prof.Pile or 0) + earned -- the hooks script turns this into piles on your farm
				table.insert(messages, "🧺 Welcome back! Your critters left piles of goodies on your farm. Scoop them up!")
			end
		end
	end
	for kind in prof.Built do showBuilding(kind) end
	-- your own farm (crops kept growing while you were away)
	local farm = assignFarm(player, prof, prof.LastOnline > 0 and math.min(os.time() - prof.LastOnline, 24 * 3600) or 0)
	if not farm then table.insert(messages, "All farms are taken on this server!") end
	prof.Special = prof.Special or {}
	setSpecialAttrs(player, prof)
	player:SetAttribute("Likes", prof.Likes or 0)
	local function goHome(char)
		local f = farmOf[player]
		if f and f.home then
			pcall(player.RequestStreamAroundAsync, player, f.home.Position, 3)
			char:WaitForChild("HumanoidRootPart", 5)
			task.wait(0.2)
			if char.Parent then char:PivotTo(CFrame.new(f.home.Position + Vector3.new(0, 4, 0)) * f.home.CFrame.Rotation * CFrame.Angles(0, math.pi, 0)) end
		end
	end
	player.CharacterAdded:Connect(goHome)
	if player.Character then task.spawn(goHome, player.Character) end
	do
		local cap, onFarm = Data.FarmPetCap(Data.FarmLevel(prof.FarmXp or 0)), 0
		for _, rec in prof.Pets do
			rec.Riding, rec.NestUntil = nil, rec.NestUntil -- riding never survives a rejoin
			if not rec.Stored then
				onFarm += 1
				if onFarm > cap then rec.Stored = true end
			end
		end
	end
	for _, rec in prof.Pets do
		local T = Data.SpeciesByName[rec.Species]
		if T and not rec.Trip then spawnCritter(T, player, rec) end
	end
	-- seeds, working slots and the incubator
	prof.Seeds = prof.Seeds or {}
	for _, c in CROPS do setSeedAttr(player, prof, c.Name) end
	prof.Res = prof.Res or {}
	for _, r in Data.Resources do setResAttr(player, prof, r.Name) end
	player:SetAttribute("Tool", prof.Tool or 0)
	prof.Workers = prof.Workers or {}
	prof.WorkSlots = prof.WorkSlots or Data.WorkSlots
	fillSlots(player)
	startEggs(prof)
	pushState(player)
	task.delay(3, function()
		for _, m in messages do toast(player, m) end
		local cod = critterOfDay()
		toast(player, ("Critter of the day: %s (%s) shows up 3x more often!"):format(cod.Species, cod.Rarity))
	end)
end

Players.PlayerAdded:Connect(onJoin)
for _, p in Players:GetPlayers() do task.spawn(onJoin, p) end

Players.PlayerRemoving:Connect(function(player)
	saveProfile(player)
	releaseFarm(player)
	for c in critters do
		if c.owner == player then removeCritter(c) end
	end
	profiles[player] = nil
	canSave[player] = nil
end)

game:BindToClose(function()
	for _, p in Players:GetPlayers() do saveProfile(p) end
end)

task.spawn(function()
	while true do
		task.wait(CONFIG.AutosaveEvery)
		for _, p in Players:GetPlayers() do task.spawn(saveProfile, p) end
	end
end)

-- Clients ask for a refresh when their menus open (also keeps countdowns honest).
stateEvent.OnServerEvent:Connect(function(player) pushState(player) end)

---------------------------------------------------------------- weather events
local rainPart = part(root, {Name = "RainCloud", Size = Vector3.new(80, 1, 80), Position = Vector3.new(0, 45, 0),
	Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
local rain = Instance.new("ParticleEmitter")
rain.EmissionDirection = Enum.NormalId.Bottom
rain.Color = ColorSequence.new(Color3.fromRGB(150, 200, 255))
rain.Size = NumberSequence.new(0.2)
rain.Speed = NumberRange.new(45, 55)
rain.Lifetime = NumberRange.new(1, 1.1)
rain.Rate = 400
rain.Enabled = false
rain.Parent = rainPart

local calm = {ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, ColorShift_Top = Lighting.ColorShift_Top,
	OutdoorAmbient = Lighting.OutdoorAmbient}
local LOOKS = {
	Rain = {ClockTime = 14, Brightness = 1, ColorShift_Top = Color3.new(0, 0, 0), OutdoorAmbient = Color3.fromRGB(110, 120, 140)},
	StarNight = {ClockTime = 0, Brightness = 1, ColorShift_Top = Color3.new(0, 0, 0), OutdoorAmbient = Color3.fromRGB(150, 150, 210)},
	GoldenSun = {ClockTime = 16.5, Brightness = 3, ColorShift_Top = Color3.fromRGB(255, 200, 80), OutdoorAmbient = Color3.fromRGB(200, 170, 110)},
	Snow = {ClockTime = 13, Brightness = 2, ColorShift_Top = Color3.fromRGB(200, 230, 255), OutdoorAmbient = Color3.fromRGB(180, 200, 230)},
	Storm = {ClockTime = 18.5, Brightness = 0.6, ColorShift_Top = Color3.new(0, 0, 0), OutdoorAmbient = Color3.fromRGB(90, 90, 120)},
}
local function setLook(goal)
	TweenService:Create(Lighting, TweenInfo.new(3), goal):Play()
end

task.spawn(function()
	while true do
		local waitUntil = os.clock() + math.random(Data.WeatherGap[1], Data.WeatherGap[2])
		while os.clock() < waitUntil and not devWeather do task.wait(1) end
		local w
		for _, x in Data.Weather do
			if x.Name == devWeather then w = x end
		end
		devWeather = nil
		w = w or Data.Weather[math.random(#Data.Weather)]
		weather = w.Name
		workspace:SetAttribute("Weather", w.Name)
		notify:FireAllClients(w.Text)
		setLook(LOOKS[w.Name])
		rain.Enabled = false -- clients draw rain/snow/lightning around their own camera
		local endAt = os.clock() + w.Secs
		while os.clock() < endAt do
			if weather == "Rain" then
				for _, plot in plots do water(plot) end
			elseif weather == "StarNight" then
				local b = Data.Biomes[math.random(#Data.Biomes)]
				if wildCount(b.Name) < b.WildMax + 2 then spawnCritter(rollBiomeSpecies(b.Name), nil, nil, {Biome = b.Name}) end
			end
			task.wait(4)
		end
		weather = nil
		workspace:SetAttribute("Weather", nil)
		rain.Enabled = false
		setLook(calm)
		notify:FireAllClients("The weather is calm again.")
	end
end)

---------------------------------------------------------------- mystery presents
-- Gift boxes pop up around the farm and meadow. First one to open it gets a random prize.
local presents = {} -- model -> {base = Vector3, born = os.clock(), seed}
local PRESENT_COLORS = {Color3.fromRGB(255, 90, 120), Color3.fromRGB(90, 170, 255), Color3.fromRGB(150, 220, 90),
	Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 190, 60)}
function spawnPresent(at)
	local pos = at or (math.random() < 0.5 and randomIn(Vector3.new(0, 0, 0), 28, 28) or biomePoint(Data.Biomes[math.random(#Data.Biomes)].Name))
	local m = Instance.new("Model")
	m.Name = "Present"
	local color = PRESENT_COLORS[math.random(#PRESENT_COLORS)]
	local ribbon = Color3.fromRGB(255, 245, 200)
	local box = part(m, {Name = "Box", Size = Vector3.new(2.4, 2.2, 2.4), Color = color, CanCollide = false, Position = Vector3.zero})
	part(m, {Size = Vector3.new(2.5, 2.25, 0.45), Color = ribbon, CanCollide = false, CanQuery = false, Position = Vector3.zero})
	part(m, {Size = Vector3.new(0.45, 2.25, 2.5), Color = ribbon, CanCollide = false, CanQuery = false, Position = Vector3.zero})
	part(m, {Size = Vector3.new(2.6, 0.5, 2.6), Color = color:Lerp(Color3.new(0, 0, 0), 0.15), CanCollide = false, CanQuery = false,
		Position = Vector3.new(0, 1.15, 0)}) -- lid
	for _, x in {-1, 1} do
		part(m, {Size = Vector3.new(0.8, 0.6, 0.3), Color = ribbon, CanCollide = false, CanQuery = false,
			CFrame = CFrame.new(x * 0.4, 1.7, 0) * CFrame.Angles(0, 0, x * 0.5)})
	end
	m.PrimaryPart = box
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.LightEmission = 1
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160))
	sparkle.Size = NumberSequence.new(0.7, 0)
	sparkle.Rate = 8
	sparkle.Lifetime = NumberRange.new(1, 1.5)
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = box
	local prompt = makePrompt(box, "Open 🎁", "")
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	local base = Vector3.new(pos.X, GROUND_Y + 1.3, pos.Z)
	m:PivotTo(CFrame.new(base))
	m.Parent = root
	presents[m] = {base = base, born = os.clock(), seed = math.random() * 10}
	prompt.Triggered:Connect(function(player)
		if not presents[m] or not profiles[player] then return end
		presents[m] = nil
		local got = grant(player, rollWeighted(Data.PresentPrizes))
		revealEvent:FireClient(player, {Kind = "Prize", Prize = got})
		questEvent(player, "Present", 1)
		addFarmXp(player, 3)
		pop(box, "🎉")
		pushState(player)
		local burst = sparkle:Clone()
		burst.Color = ColorSequence.new(Color3.fromRGB(255, 120, 160), Color3.fromRGB(120, 220, 255))
		burst.Speed = NumberRange.new(8, 14)
		burst.Parent = box
		burst:Emit(40)
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") then p.Transparency = 1 end
		end
		prompt.Enabled = false
		task.delay(1.5, function() m:Destroy() end)
	end)
	return m
end

RunService.Heartbeat:Connect(function() -- presents bob and turn, and vanish after a while
	local t = os.clock()
	for m, info in presents do
		if t - info.born > Data.PresentStay then
			presents[m] = nil
			m:Destroy()
		else
			m:PivotTo(CFrame.new(info.base + Vector3.new(0, math.abs(math.sin(t * 2 + info.seed)) * 0.6, 0)) * CFrame.Angles(0, t * 0.8 + info.seed, 0))
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(math.random(Data.PresentGap[1], Data.PresentGap[2]))
		local n = 0
		for _ in presents do n += 1 end
		if n < Data.PresentMax then spawnPresent() end
	end
end)

-- nap countdowns on the energy bars
task.spawn(function()
	while true do
		task.wait(2)
		for c in critters do
			if c.record and c.record.NapUntil then updateEnergyBar(c) end
		end
	end
end)
-- Happiness drifts down over time: refresh moods and tags now and then.
task.spawn(function()
	while true do
		task.wait(20)
		for c in critters do
			if c.owner and c.record then refreshTag(c) end
		end
	end
end)

---------------------------------------------------------------- working slots (Pets menu / profile)
-- on = true puts the pet to work (swapping out the most tired worker if the slots are full), false benches it
function ACTIONS.SetWorker(player, prof, id, on)
	local rec = findRec(prof, id)
	if not rec or Data.SpeciesByName[rec.Species].Role ~= "Worker" then return nil end
	local function nudge(r)
		local c = r and critterFor(r)
		if c then c.version += 1 end
	end
	if on then
		if not canWork(rec) then return rec.NapUntil and "💤" or "🎒" end
		rec.Bench = nil
		if not table.find(prof.Workers, rec.Id) then
			if #prof.Workers >= prof.WorkSlots then
				local worst, wi
				for i, wid in prof.Workers do
					local w = findRec(prof, wid)
					if w and (not worst or (w.Energy or 100) < (worst.Energy or 100)) then worst, wi = w, i end
				end
				if wi then
					table.remove(prof.Workers, wi)
					worst.Bench = true
					nudge(worst)
				end
			end
			table.insert(prof.Workers, rec.Id)
		end
	else
		rec.Bench = true
		local i = table.find(prof.Workers, rec.Id)
		if i then table.remove(prof.Workers, i) end
	end
	nudge(rec)
	fillSlots(player)
	return nil
end
function ACTIONS.BuySlot(player, prof)
	local nextSlot = prof.WorkSlots + 1
	local cost = Data.SlotCosts[nextSlot]
	if not cost then return "🧺 MAX" end
	if Data.FarmLevel(prof.FarmXp) < cost.Level then return ("🔒 ⭐%d"):format(cost.Level) end
	local coins = stat(player, "Coins")
	if not coins or coins.Value < cost.Coins then return ("💰 %d"):format(cost.Coins) end
	coins.Value -= cost.Coins
	prof.WorkSlots = nextSlot
	fillSlots(player)
	return ("🧺 %d!"):format(nextSlot)
end

---------------------------------------------------------------- incubator nest on every farm
-- Up to 3 eggs sit on your nest while they hatch; ready ones wobble and sparkle. Walk up to hatch them.
local EGG_COLOR = {Mystery = Color3.fromRGB(245, 235, 210), Crystal = Color3.fromRGB(150, 210, 255), Lava = Color3.fromRGB(255, 110, 50),
	Star = Color3.fromRGB(255, 230, 110), Harvest = Color3.fromRGB(230, 130, 50)}
local nests = {} -- farm -> {eggs = {part...}, base = CFrames, ready = {bool}}
local function refreshNest(player, prof)
	local farm = farmOf[player]
	local nest = farm and nests[farm]
	if not nest then return end
	local list = {}
	for _, e in prof.Eggs do
		if e.HatchAt then table.insert(list, e) end
	end
	for i, egg in nest.eggs do
		local e = list[i]
		egg.Transparency = e and 0 or 1
		local ready = e ~= nil and os.time() >= e.HatchAt
		nest.ready[i] = ready
		if e then
			egg.Color = EGG_COLOR[e.Kind] or Color3.new(1, 1, 1)
			egg.Material = (e.Kind == "Star" or e.Kind == "Crystal") and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
		local glitter = egg:FindFirstChild("Glitter")
		if glitter then glitter.Enabled = ready end
	end
	local waiting = #prof.Eggs - #list
	if nest.label then nest.label.Text = waiting > 0 and ("🥚 +%d"):format(waiting) or "" end
end
function afterPush(player, prof) refreshNest(player, prof) end
local function releaseNest(farm)
	local nest = nests[farm]
	if not nest then return end
	for i, egg in nest.eggs do
		egg.Transparency = 1
		nest.ready[i] = false
		local glitter = egg:FindFirstChild("Glitter")
		if glitter then glitter.Enabled = false end
	end
	if nest.label then nest.label.Text = "" end
end
for _, farm in farms do
	local model = farm.model:FindFirstChild("Nest")
	if model then
		local nest = {eggs = {}, base = {}, ready = {}}
		for i = 1, Data.IncubatorSlots do
			local egg = model:FindFirstChild("Egg" .. i)
			if egg then
				table.insert(nest.eggs, egg)
				nest.base[#nest.eggs] = egg.CFrame
				local g = Instance.new("ParticleEmitter")
				g.Name = "Glitter"
				g.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				g.LightEmission = 1
				g.Size = NumberSequence.new(0.5, 0)
				g.Rate = 10
				g.Speed = NumberRange.new(1, 2)
				g.SpreadAngle = Vector2.new(180, 180)
				g.Enabled = false
				g.Parent = egg
			end
		end
		local labelPart = model:FindFirstChild("Base")
		if labelPart then
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(90, 40)
			bb.StudsOffset = Vector3.new(0, 4.5, 0)
			bb.MaxDistance = 60
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextColor3 = Color3.new(1, 1, 1)
			t.TextStrokeTransparency = 0.3
			t.Text = ""
			t.Parent = bb
			bb.Parent = labelPart
			nest.label = t
			local prompt = makePrompt(labelPart, "Hatch 🐣", "")
			prompt.MaxActivationDistance = 10
			prompt.Triggered:Connect(function(player)
				local prof = profiles[player]
				if farm.owner ~= player or not prof then
					toast(player, "🔒 🏡")
					return
				end
				local soonest
				for _, e in prof.Eggs do
					if e.HatchAt and os.time() >= e.HatchAt then
						local res = ACTIONS.Hatch(player, prof, e.Id)
						pushState(player)
						if type(res) == "table" then revealEvent:FireClient(player, {Kind = "Hatch", Result = res}) else toast(player, res) end
						return
					end
					if e.HatchAt and (not soonest or e.HatchAt < soonest) then soonest = e.HatchAt end
				end
				if soonest then
					local s = soonest - os.time()
					toast(player, ("⏱ %d:%02d"):format(s // 60, s % 60))
				else
					toast(player, "🥚 0  🎒→🥚")
				end
			end)
		end
		nests[farm] = nest
	end
end
RunService.Heartbeat:Connect(function() -- ready eggs wobble
	local t = os.clock()
	for _, nest in nests do
		for i, egg in nest.eggs do
			if nest.ready[i] then
				egg.CFrame = nest.base[i] * CFrame.Angles(0, 0, math.sin(t * 9 + i) * 0.25)
			end
		end
	end
end)
task.spawn(function() -- eggs become ready while you watch
	while true do
		task.wait(5)
		for player, prof in profiles do
			if farmOf[player] then refreshNest(player, prof) end
		end
	end
end)
Players.PlayerRemoving:Connect(function(player) -- the farm is released in the leave handler; clear its nest too
	for farm, _ in nests do
		if farm.owner == nil or farm.owner == player then releaseNest(farm) end
	end
end)

---------------------------------------------------------------- shared API for the other server scripts (ServerScriptService.CritterAPI)
API.ACTIONS = ACTIONS
API.addSeeds = addSeeds
API.setSeedAttr = setSeedAttr
API.coinsOf = function(player) return stat(player, "Coins") end
API.today = today
API.addEgg = addEgg
API.farmSpot = farmSpot
API.teleportTo = teleportTo
API.addRes = addRes
API.canPay = canPay
API.pay = pay
API.water = water
API.refreshPlot = refreshPlot
API.groundAt = groundAt
API.refreshGroundList = refreshGroundList
API.critterFor = critterFor
API.findRec = findRec
API.giveTitleHook = giveTitle
API.Data = Data
API.root = root
API.GROUND_Y = GROUND_Y
API.profiles = profiles
API.critters = critters
API.farms = farms
API.farmOf = farmOf
API.biomeParts = biomeParts
API.toast = toast
API.notifyAll = function(text) notify:FireAllClients(text) end
API.reveal = function(player, info) revealEvent:FireClient(player, info) end
API.grant = grant
API.rollWeighted = rollWeighted
API.addCoins = addCoins
API.addFarmXp = addFarmXp
API.questEvent = questEvent
API.pop = pop
API.part = part
API.makePrompt = makePrompt
API.biomePoint = biomePoint
API.randomIn = randomIn
API.spawnCritter = spawnCritter
API.removeCritter = removeCritter
API.spawnPresent = spawnPresent
API.refreshTag = refreshTag
API.pushState = pushState
API.farmLevelOf = farmLevelOf
API.countRole = countRole
API.petLevel = petLevel
API.happiness = happiness
API.setHappy = setHappy
API.isResting = isResting
API.rollVariant = rollVariant
API.rollSize = rollSize
API.rollFromWeights = rollFromWeights
API.fillSlots = fillSlots
API.setOwner = setOwner
API.petStats = petStats
API.variantMult = variantMult
API.basket = basket
API.critterFolder = critterFolder
API.revealEvent = revealEvent
API.CROP = CROP
API.questHooks = API.questHooks or {}
API.stateHooks = API.stateHooks or {}
API.capFor = capFor
API.petPower = function(c) -- battle power of an owned battle pet (for the world boss)
	local prof = c.owner and profiles[c.owner]
	local s = prof and c.record and petStats(prof, c.record)
	return s and Data.Power(s) or 0
end
API.addPet = addPet
API.Ready = true

-- dev tools that live in WorldEvents
function DEV.Event(player, prof, name)
	if API.StartEvent then return API.StartEvent(name) end
	return "WorldEvents isn't running"
end
function DEV.MutateCrops(player, prof)
	local farm = farmOf[player]
	if not farm then return "No farm" end
	for _, plot in farm.plots do
		if plot:GetAttribute("State") ~= "Empty" then
			local m = Data.Mutations[math.random(#Data.Mutations)]
			addMut(plot, m.Name)
			if plot:GetAttribute("State") == "Ready" then plot:SetAttribute("Size", Data.CropSizes[math.random(#Data.CropSizes)].Name) end
			updateCrop(plot)
		end
	end
	return "Random mutations added to your crops"
end
function DEV.Restock(player, prof)
	if API.Restock then API.Restock() return "🛒 Restocked" end
	return "ShopServer isn't running"
end
function DEV.AllSeeds(player, prof)
	for _, c in CROPS do
		if c.Name ~= Data.FarmCrop then addSeeds(player, c.Name, 5) end
	end
	prof.FreePacks += 3
	return "+5 of every seed, +3 free packs"
end
function DEV.Resources(player, prof)
	for _, r in Data.Resources do addRes(player, r.Name, 30) end
	return "+30 of every resource"
end
function DEV.ToolUp(player, prof)
	prof.Tool = math.min(Data.ToolMax, (prof.Tool or 0) + 1)
	player:SetAttribute("Tool", prof.Tool)
	return "Tool level " .. prof.Tool
end
function DEV.Lucky(player, prof)
	if API.startLuckyHour then API.startLuckyHour() return "🍀 Lucky hour for 10 minutes" end
	return "FunServer isn't running"
end
function DEV.TireWorkers(player, prof)
	for c in critters do
		if c.owner == player and c.record and isWorking(c) then
			c.record.Energy = 4
			c.model:SetAttribute("Energy", 4)
		end
	end
	return "Workers are almost out of energy (one more job each)"
end
function DEV.SeasonalEgg(player, prof)
	addEgg(prof, Data.Seasonal.Egg)
	for _, e in prof.Eggs do
		if e.Kind == Data.Seasonal.Egg then e.HatchAt = os.time() end
	end
	return "🍂 Harvest Egg added (ready)"
end
function DEV.GrowCrops(player, prof)
	local farm = farmOf[player]
	if not farm then return "No farm" end
	for _, plot in farm.plots do
		if plot:GetAttribute("State") == "Empty" then plant(plot, player) end
		if plot:GetAttribute("State") == "Growing" then
			plot:SetAttribute("Progress", 1)
			ripen(plot)
		end
	end
	return "Your crops are ready"
end

---------------------------------------------------------------- wild critters wander in (each biome has its own)
for _, b in Data.Biomes do
	for _ = 1, 2 do spawnCritter(rollBiomeSpecies(b.Name), nil, nil, {Biome = b.Name}) end
end
while true do
	task.wait(CONFIG.WildSpawnEvery)
	for _, b in Data.Biomes do
		if wildCount(b.Name) < b.WildMax and math.random() < 0.5 then
			spawnCritter(rollBiomeSpecies(b.Name), nil, nil, {Biome = b.Name})
		end
	end
end
