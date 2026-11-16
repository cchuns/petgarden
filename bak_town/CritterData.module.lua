-- Critter Acres: CritterData (ReplicatedStorage ModuleScript)
-- Shared tuning for seeds/berries and critters. Server and HUD both read this.
local Data = {}

-- Crops. Seeds are owned items (bought at the seed shop or found in seed packs); Puffberry seeds are free
-- and never run out. Yield = berries per harvest, Price = coins per berry, Grow/WetGrow = seconds.
--   Seed = shop price, Unlock = farm level needed to BUY it at the shop, PackOnly = only from seed packs
--   Tree = plant once, it keeps fruiting: after a harvest it regrows fruit in Regrow seconds (half if watered)
--   Giant = MEGA/XXL/XL chances x this     Glow = mutates much more during world events and Star Night/Storm
--   Rarity = for the Seed Book and seed pack colors
Data.Crops = {
	{Name = "Puffberry", Icon = "🍓", Xp = 1, Seed = 0, Unlock = 1, Yield = 1, Price = 5, Grow = 24, WetGrow = 10, Rarity = "Common",
		Color = Color3.fromRGB(255, 110, 170)},
	{Name = "Sunberry", Icon = "🍋", Xp = 3, Seed = 8, Unlock = 1, Yield = 2, Price = 9, Grow = 34, WetGrow = 14, Rarity = "Common",
		Color = Color3.fromRGB(255, 215, 70)},
	{Name = "Moonplum", Icon = "🍇", Xp = 8, Seed = 20, Unlock = 3, Yield = 3, Price = 16, Grow = 48, WetGrow = 20, Rarity = "Rare",
		Color = Color3.fromRGB(150, 110, 255)},
	{Name = "Rainbow Drop", Icon = "🌈", Xp = 20, Seed = 50, Unlock = 6, Yield = 3, Price = 40, Grow = 70, WetGrow = 30, Rarity = "Epic",
		Color = Color3.fromRGB(120, 230, 255), Neon = true},
	{Name = "Pumpkin", Icon = "🎃", Xp = 10, Seed = 30, Unlock = 2, Yield = 1, Price = 30, Grow = 60, WetGrow = 25, Rarity = "Rare", Giant = 4,
		Color = Color3.fromRGB(255, 140, 40)},
	{Name = "Apple Tree", Icon = "🍎", Xp = 6, Seed = 120, Unlock = 4, Yield = 3, Price = 12, Grow = 120, WetGrow = 60, Regrow = 45, Rarity = "Rare", Tree = true,
		Color = Color3.fromRGB(235, 50, 60)},
	{Name = "Cherry Tree", Icon = "🍒", Xp = 8, Seed = 0, Unlock = 1, Yield = 4, Price = 15, Grow = 150, WetGrow = 75, Regrow = 50, Rarity = "Rare", Tree = true,
		PackOnly = true, Color = Color3.fromRGB(200, 20, 60)},
	{Name = "Moonflower", Icon = "🌙", Xp = 15, Seed = 60, Unlock = 5, Yield = 2, Price = 35, Grow = 70, WetGrow = 30, Rarity = "Epic", Glow = true,
		Color = Color3.fromRGB(170, 190, 255), Neon = true},
	{Name = "Mango Tree", Icon = "🥭", Xp = 12, Seed = 0, Unlock = 1, Yield = 3, Price = 30, Grow = 200, WetGrow = 100, Regrow = 60, Rarity = "Epic", Tree = true,
		PackOnly = true, Color = Color3.fromRGB(255, 180, 40)},
	{Name = "Starfruit", Icon = "💫", Xp = 30, Seed = 250, Unlock = 8, Yield = 2, Price = 80, Grow = 110, WetGrow = 45, Rarity = "Legendary", Glow = true,
		Color = Color3.fromRGB(255, 245, 120), Neon = true},
	{Name = "Dragonfruit Tree", Icon = "🐉", Xp = 25, Seed = 0, Unlock = 1, Yield = 3, Price = 70, Grow = 300, WetGrow = 150, Regrow = 80, Rarity = "Legendary",
		Tree = true, PackOnly = true, Color = Color3.fromRGB(255, 60, 160), Neon = true},
}
Data.CropByName = {}
for i, c in Data.Crops do
	c.Tier = i
	Data.CropByName[c.Name] = c
end
Data.BaseBerries = 4 -- the first 4 crops are the "berries" used for catching critters

-- Fancier berries make wild critters more likely to say yes (by crop tier, base berries only).
Data.BerryCatchBonus = {1, 1.3, 1.6, 2}

Data.Rarities = {
	Common = {Order = 1, Weight = 60, Catch = 0.7, Color = Color3.fromRGB(240, 240, 240)},
	Rare = {Order = 2, Weight = 28, Catch = 0.4, Color = Color3.fromRGB(90, 170, 255)},
	Epic = {Order = 3, Weight = 10, Catch = 0.2, Color = Color3.fromRGB(205, 120, 255)},
	Legendary = {Order = 4, Weight = 2, Catch = 0.08, Color = Color3.fromRGB(255, 200, 60)},
}

-- Jobs: Water, Harvest, Plant, Grow (adds Boost of a crop's growth per visit).
-- Mutate = {mutation, chance}: each time it works a plot it may give the berry that mutation.
Data.Species = {
	{Species = "Splashy", Rarity = "Common", Job = "Water", Mutate = {"Juicy", 0.02}, JobText = "waters crops", Speed = 9,
		Color = Color3.fromRGB(110, 190, 255), Ear = Color3.fromRGB(70, 140, 230)},
	{Species = "Hopsy", Rarity = "Common", Job = "Harvest", JobText = "harvests crops", Speed = 9,
		Color = Color3.fromRGB(255, 205, 130), Ear = Color3.fromRGB(240, 150, 90)},
	{Species = "Sprig", Rarity = "Common", Job = "Plant", JobText = "plants your chosen seed", Speed = 9,
		Color = Color3.fromRGB(170, 230, 140), Ear = Color3.fromRGB(110, 180, 90)},
	{Species = "Drizzle", Rarity = "Rare", Job = "Water", Mutate = {"Juicy", 0.05}, JobText = "waters crops super fast", Speed = 15,
		Color = Color3.fromRGB(80, 220, 220), Ear = Color3.fromRGB(40, 160, 170)},
	{Species = "Bloomby", Rarity = "Rare", Job = "Grow", Mutate = {"Golden", 0.03}, Boost = 0.15, JobText = "makes crops grow faster", Speed = 10,
		Color = Color3.fromRGB(255, 170, 205), Ear = Color3.fromRGB(255, 100, 160)},
	{Species = "Pockets", Rarity = "Epic", Job = "Harvest", Bonus = 1, JobText = "harvests with +1 bonus berry", Speed = 12,
		Color = Color3.fromRGB(205, 155, 105), Ear = Color3.fromRGB(150, 100, 70)},
	{Species = "Glimmer", Rarity = "Epic", Job = "Grow", Mutate = {"Starry", 0.03}, Boost = 0.3, JobText = "makes crops grow much faster", Speed = 12,
		Color = Color3.fromRGB(255, 240, 150), Ear = Color3.fromRGB(255, 200, 80)},
	{Species = "Prism", Rarity = "Legendary", Job = "Grow", Mutate = {"Prismatic", 0.01}, Boost = 0.5, Waters = true, Rainbow = true,
		JobText = "waters and super-grows crops", Speed = 14,
		Color = Color3.fromRGB(255, 255, 255), Ear = Color3.fromRGB(255, 150, 220)},
	-- rigged (animated limbs): purrs, licks its paw, stretches
	{Species = "Purrkin", Rarity = "Rare", Job = "Harvest", JobText = "harvests crops (and purrs)", Speed = 11,
		Color = Color3.fromRGB(255, 225, 170), Ear = Color3.fromRGB(240, 160, 90)},
}
-- Battlers don't farm; they fight in raids. Class shapes their stats (see Data.Classes).
for _, b in {
	{Species = "Pebbleback", Rarity = "Common", Class = "Tank", JobText = "a tough Tank fighter", Speed = 8,
		Color = Color3.fromRGB(160, 150, 135), Ear = Color3.fromRGB(110, 100, 90)},
	{Species = "Nibblet", Rarity = "Common", Class = "Striker", JobText = "a bitey Striker fighter", Speed = 10,
		Color = Color3.fromRGB(255, 160, 90), Ear = Color3.fromRGB(220, 110, 60)},
	{Species = "Zippit", Rarity = "Rare", Class = "Speedy", JobText = "a super fast Speedy fighter", Speed = 15,
		Color = Color3.fromRGB(255, 235, 90), Ear = Color3.fromRGB(240, 180, 40)},
	{Species = "Thornox", Rarity = "Rare", Class = "Tank", JobText = "a spiky Tank fighter", Speed = 9,
		Color = Color3.fromRGB(90, 160, 90), Ear = Color3.fromRGB(50, 110, 60)},
	{Species = "Emberclaw", Rarity = "Epic", Class = "Striker", JobText = "a fiery Striker fighter", Speed = 12,
		Color = Color3.fromRGB(255, 100, 70), Ear = Color3.fromRGB(200, 50, 40)},
	{Species = "Frostmaw", Rarity = "Epic", Class = "Tank", JobText = "an icy Tank fighter", Speed = 10,
		Color = Color3.fromRGB(170, 220, 255), Ear = Color3.fromRGB(110, 170, 230)},
	{Species = "Stormwing", Rarity = "Legendary", Class = "Speedy", JobText = "a lightning-fast Speedy fighter", Speed = 16, Rainbow = false,
		Color = Color3.fromRGB(150, 110, 255), Ear = Color3.fromRGB(255, 240, 120)},
	-- rigged dragon: flies around the map, lands for a while, flaps, roars and breathes fire
	{Species = "Viridrake", Rarity = "Legendary", Class = "Striker", JobText = "a fire-breathing dragon Striker", Speed = 14, Flyer = true,
		Color = Color3.fromRGB(60, 65, 75), Ear = Color3.fromRGB(130, 255, 60)},
} do
	b.Role = "Battler"
	table.insert(Data.Species, b)
end

-- Secret pets: only from the 💕 Best Friends Nest (a lucky mix of two parents). Never wild, never in eggs.
for _, b in {
	{Species = "Bubbloom", Rarity = "Legendary", Job = "Grow", Boost = 0.4, Waters = true, Class = "Speedy", Secret = true, Speed = 13,
		JobText = "waters and grows crops", Color = Color3.fromRGB(140, 220, 255), Ear = Color3.fromRGB(255, 150, 210)},
	{Species = "Emberfrost", Rarity = "Legendary", Job = "Water", Mutate = {"Frosty", 0.04}, Class = "Striker", Secret = true, Speed = 13,
		JobText = "waters crops (they may turn Frosty)", Color = Color3.fromRGB(255, 140, 120), Ear = Color3.fromRGB(150, 210, 255)},
	{Species = "Glitterpaw", Rarity = "Legendary", Job = "Harvest", Bonus = 2, Class = "Speedy", Secret = true, Speed = 14,
		JobText = "harvests with +2 bonus berries", Color = Color3.fromRGB(255, 240, 190), Ear = Color3.fromRGB(255, 200, 90)},
} do
	table.insert(Data.Species, b)
end

-- ONE pet family: every pet works on your farm AND fights in raids. Former battlers get a farm job,
-- former workers get a fighting class.
local EXTRA_JOB = {
	Pebbleback = {Job = "Plant", JobText = "plants your chosen seed"}, Nibblet = {Job = "Harvest", JobText = "harvests crops"},
	Zippit = {Job = "Water", JobText = "waters crops super fast"}, Thornox = {Job = "Plant", JobText = "plants seeds"},
	Emberclaw = {Job = "Harvest", Bonus = 1, JobText = "harvests with +1 bonus berry"},
	Frostmaw = {Job = "Water", Mutate = {"Frosty", 0.02}, JobText = "waters crops (they may turn Frosty)"},
	Stormwing = {Job = "Water", Mutate = {"Zapped", 0.01}, JobText = "waters crops (they may get Zapped)"},
	Viridrake = {Job = "Grow", Boost = 0.45, JobText = "makes crops grow super fast"},
}
local EXTRA_CLASS = {Splashy = "Speedy", Hopsy = "Striker", Sprig = "Tank", Drizzle = "Speedy", Bloomby = "Tank", Pockets = "Striker",
	Glimmer = "Speedy", Prism = "Striker", Purrkin = "Striker"}
Data.SpeciesByName = {}
for i, s in Data.Species do
	s.Index = i
	local extra = EXTRA_JOB[s.Species]
	if extra then
		for k, v in extra do s[k] = v end
	end
	s.Class = s.Class or EXTRA_CLASS[s.Species] or "Striker"
	s.Role = "Pet"
	Data.SpeciesByName[s.Species] = s
end

-- How many pets of each role you can keep.
Data.WorkerCap = 10 -- +5 with the Critter Hut (only WorkSlots of them work at a time, the rest sit on the bench)
Data.BattlerCap = 6

---------------------------------------------------------------- working slots, energy, naps
Data.WorkSlots = 3 -- pets working on your farm at once
Data.WorkSlotsMax = 6
Data.SlotCosts = {[4] = {Coins = 300, Level = 3}, [5] = {Coins = 900, Level = 6}, [6] = {Coins = 2200, Level = 9}}
Data.EnergyPerJob = 5 -- energy a Common Lv1 pet uses per job (rarer and higher level pets use less)
Data.NapSecs = 150 -- a tired pet naps this long in the hut (rarer pets nap shorter)
function Data.EnergyCost(rarity, level)
	return Data.EnergyPerJob / (1 + 0.3 * (Data.Rarities[rarity].Order - 1)) / (1 + 0.04 * (level - 1))
end
function Data.NapTime(rarity)
	return math.floor(Data.NapSecs / (1 + 0.15 * (Data.Rarities[rarity].Order - 1)))
end
-- What a pet brings back from its nap. Rarer and happier pets dream luckier (Epic/Legendary weights go up).
Data.DreamGifts = {
	{Type = "Coins", Amount = 20, Weight = 40, Rarity = "Common"},
	{Type = "Seed", Crop = "Sunberry", Amount = 2, Weight = 22, Rarity = "Common"},
	{Type = "Seed", Crop = "Pumpkin", Amount = 1, Weight = 12, Rarity = "Rare"},
	{Type = "Coins", Amount = 60, Weight = 10, Rarity = "Rare"},
	{Type = "Seed", Crop = "Moonflower", Amount = 1, Weight = 5, Rarity = "Epic"},
	{Type = "Egg", Kind = "Mystery", Weight = 5, Rarity = "Epic"},
	{Type = "Outfit", Weight = 3, Rarity = "Epic"},
	{Type = "Seed", Crop = "Cherry Tree", Amount = 1, Weight = 2, Rarity = "Legendary"},
	{Type = "Egg", Kind = "Crystal", Weight = 1, Rarity = "Legendary"},
}

---------------------------------------------------------------- incubator
Data.IncubatorSlots = 3 -- eggs hatching at once; more eggs wait their turn

---------------------------------------------------------------- battle stats
Data.BattleBase = {Common = {HP = 100, ATK = 10}, Rare = {HP = 150, ATK = 15}, Epic = {HP = 220, ATK = 22}, Legendary = {HP = 320, ATK = 32}}
Data.Classes = {
	Tank = {HP = 1.6, ATK = 0.7, Interval = 1.3, Icon = "🛡️"},
	Striker = {HP = 0.9, ATK = 1.4, Interval = 1.2, Icon = "⚔️"},
	Speedy = {HP = 0.8, ATK = 0.9, Interval = 0.75, Icon = "⚡"},
}
Data.BattleLevelBonus = 0.1 -- +10% HP and ATK per level

-- Equipment: 1 slot per pet. Stat bonus = Base x rarity multiplier.
Data.Gear = {
	{Name = "Leaf Helmet", Icon = "🍃", Stat = "HP", Base = 30},
	{Name = "Thorn Claws", Icon = "🗡️", Stat = "ATK", Base = 4},
	{Name = "Feather Boots", Icon = "👟", Stat = "SPD", Base = 0.06}, -- attacks 6% faster
	{Name = "Shell Shield", Icon = "🛡️", Stat = "HP", Base = 45},
	{Name = "Ember Charm", Icon = "🔥", Stat = "ATK", Base = 6},
}
Data.GearRarityMult = {Common = 1, Rare = 2, Epic = 3.5, Legendary = 6}

Data.GearLevelBonus = 0.25 -- each ⭐ upgrade at the workbench adds +25%
-- Gear tiers: better materials (from harder biomes) make much stronger gear.
Data.GearTiers = {
	{Name = "Leaf", Icon = "🌿", Mult = 1, Res = "Fiber", Color = Color3.fromRGB(120, 200, 90), Cost = {Fiber = 8, Wood = 4}},
	{Name = "Stone", Icon = "🪨", Mult = 1.6, Res = "Stone", Color = Color3.fromRGB(160, 160, 170), Cost = {Stone = 10, Wood = 6}},
	{Name = "Iron", Icon = "⚙️", Mult = 2.5, Res = "Iron", Color = Color3.fromRGB(190, 195, 215), Cost = {Iron = 6, Stone = 6, Coins = 60}},
	{Name = "Gold", Icon = "🟡", Mult = 3.8, Res = "Gold", Color = Color3.fromRGB(255, 205, 60), Cost = {Gold = 5, Iron = 4, Coins = 150}},
	{Name = "Crystal", Icon = "💎", Mult = 5.5, Res = "Gem", Color = Color3.fromRGB(160, 110, 255), Cost = {Gem = 5, Gold = 3, Coins = 300}},
	{Name = "Magma", Icon = "🔥", Mult = 8, Res = "Magma", Color = Color3.fromRGB(255, 110, 40), Cost = {Magma = 5, Obsidian = 3, Coins = 600}},
}
Data.GearMaxLevel = 10
-- upgrade chance by the level you try to reach. A fail only uses the materials (the gear never breaks)
-- and adds +10% luck to the next try on that gear.
Data.UpgradeChance = {0.95, 0.9, 0.8, 0.7, 0.6, 0.5, 0.42, 0.34, 0.27, 0.2}
Data.UpgradeFailLuck = 0.1
function Data.UpgradeCost(gear, toLevel)
	local tier = Data.GearTiers[gear.Tier or 1]
	return {[tier.Res] = 2 + toLevel, Coins = 15 * toLevel * (gear.Tier or 1)}
end
function Data.UpgradeOdds(gear)
	local base = Data.UpgradeChance[(gear.Level or 0) + 1]
	return base and math.min(1, base + (gear.Luck or 0)) or nil
end
function Data.GearBonus(gear) -- gear = {Kind = index, Tier = index, Rarity = name, Level = upgrades}
	local g = Data.Gear[gear.Kind]
	local tier = Data.GearTiers[gear.Tier or 1]
	return g, g.Base * tier.Mult * Data.GearRarityMult[gear.Rarity] * (1 + Data.GearLevelBonus * (gear.Level or 0))
end
function Data.GearName(gear)
	return Data.GearTiers[gear.Tier or 1].Name .. " " .. Data.Gear[gear.Kind].Name
end
function Data.GearText(gear)
	local g, amount = Data.GearBonus(gear)
	local bonus = g.Stat == "SPD" and ("+%d%% speed"):format(amount * 100 + 0.5) or ("+%d %s"):format(amount, g.Stat)
	local lv = (gear.Level or 0) > 0 and (" +" .. gear.Level) or ""
	return ("%s %s %s%s (%s)"):format(g.Icon, gear.Rarity, Data.GearName(gear), lv, bonus)
end

-- Stats for one battler. gear may be nil.
function Data.BattleStats(species, level, gear)
	local base = Data.BattleBase[species.Rarity]
	local class = Data.Classes[species.Class]
	local lv = 1 + Data.BattleLevelBonus * (level - 1)
	local hp = base.HP * class.HP * lv
	local atk = base.ATK * class.ATK * lv
	local interval = class.Interval
	if gear then
		local g, amount = Data.GearBonus(gear)
		if g.Stat == "HP" then hp += amount
		elseif g.Stat == "ATK" then atk += amount
		else interval = math.max(0.4, interval * (1 - amount)) end
	end
	return {HP = math.floor(hp), ATK = math.floor(atk), Interval = interval}
end

function Data.Power(stats)
	return math.floor(stats.HP / 5 + stats.ATK * 3 / stats.Interval)
end

---------------------------------------------------------------- raids
Data.EnergyMax = 10
Data.EnergyRegenSecs = 3600 -- 1 energy per hour
Data.RaidTeamMin, Data.RaidTeamMax = 3, 6

-- Enemies: {Name, HP, ATK, Interval, Color, Boss}. Gear = rarity weights for the drop.
Data.Raids = {
	{Name = "Slime Swamp", Boss = "Goo King", Stars = 1, Coins = 30, GearDrops = 1, Color = Color3.fromRGB(120, 220, 120),
		Gear = {Common = 80, Rare = 20},
		Enemies = {
			{Name = "Slime", HP = 80, ATK = 5, Interval = 1.4, Color = Color3.fromRGB(140, 230, 120)},
			{Name = "Slime", HP = 80, ATK = 5, Interval = 1.4, Color = Color3.fromRGB(140, 230, 120)},
			{Name = "Goo King", HP = 300, ATK = 8, Interval = 1.6, Color = Color3.fromRGB(90, 200, 90), Boss = true},
		}},
	{Name = "Thorn Thicket", Boss = "Bramble Bear", Stars = 2, Coins = 70, GearDrops = 1, Color = Color3.fromRGB(150, 190, 90),
		Gear = {Common = 55, Rare = 38, Epic = 7},
		Enemies = {
			{Name = "Thorn Imp", HP = 170, ATK = 10, Interval = 1.3, Color = Color3.fromRGB(120, 160, 70)},
			{Name = "Thorn Imp", HP = 170, ATK = 10, Interval = 1.3, Color = Color3.fromRGB(120, 160, 70)},
			{Name = "Bramble Bear", HP = 650, ATK = 17, Interval = 1.6, Color = Color3.fromRGB(140, 100, 70), Boss = true},
		}},
	{Name = "Frost Cavern", Boss = "Ice Wyrm", Stars = 3, Coins = 140, GearDrops = 1, Color = Color3.fromRGB(130, 200, 255),
		Gear = {Common = 30, Rare = 45, Epic = 22, Legendary = 3},
		Enemies = {
			{Name = "Ice Bat", HP = 240, ATK = 15, Interval = 1.0, Color = Color3.fromRGB(180, 220, 255)},
			{Name = "Ice Bat", HP = 240, ATK = 15, Interval = 1.0, Color = Color3.fromRGB(180, 220, 255)},
			{Name = "Ice Bat", HP = 240, ATK = 15, Interval = 1.0, Color = Color3.fromRGB(180, 220, 255)},
			{Name = "Ice Wyrm", HP = 1400, ATK = 30, Interval = 1.7, Color = Color3.fromRGB(100, 160, 240), Boss = true},
		}},
	{Name = "Crystal Depths", Boss = "Gem Golem", Stars = 4, Coins = 260, GearDrops = 2, Color = Color3.fromRGB(170, 120, 255),
		Gear = {Common = 10, Rare = 45, Epic = 37, Legendary = 8},
		Enemies = {
			{Name = "Gem Mite", HP = 420, ATK = 24, Interval = 1.1, Color = Color3.fromRGB(200, 150, 255)},
			{Name = "Gem Mite", HP = 420, ATK = 24, Interval = 1.1, Color = Color3.fromRGB(200, 150, 255)},
			{Name = "Gem Mite", HP = 420, ATK = 24, Interval = 1.1, Color = Color3.fromRGB(200, 150, 255)},
			{Name = "Gem Golem", HP = 3000, ATK = 45, Interval = 2.0, Color = Color3.fromRGB(140, 90, 230), Boss = true},
		}},
	{Name = "Magma Lair", Boss = "Lava Titan", Stars = 5, Coins = 500, GearDrops = 2, Color = Color3.fromRGB(255, 110, 60),
		Gear = {Rare = 35, Epic = 45, Legendary = 20},
		Enemies = {
			{Name = "Fire Imp", HP = 650, ATK = 36, Interval = 1.1, Color = Color3.fromRGB(255, 150, 70)},
			{Name = "Fire Imp", HP = 650, ATK = 36, Interval = 1.1, Color = Color3.fromRGB(255, 150, 70)},
			{Name = "Fire Imp", HP = 650, ATK = 36, Interval = 1.1, Color = Color3.fromRGB(255, 150, 70)},
			{Name = "Fire Imp", HP = 650, ATK = 36, Interval = 1.1, Color = Color3.fromRGB(255, 150, 70)},
			{Name = "Lava Titan", HP = 6500, ATK = 75, Interval = 2.0, Color = Color3.fromRGB(230, 70, 40), Boss = true},
		}},
}
for _, r in Data.Raids do
	local p = 0
	for _, e in r.Enemies do p += Data.Power(e) end
	r.Recommended = p
end

-- Coins per minute each pet earns while you're offline (by rarity), capped at OfflineCapHours.
Data.OfflineRate = {Common = 0.5, Rare = 1, Epic = 2, Legendary = 4}
Data.OfflineCapHours = 8

-- First time you befriend a species (collection book reward).
Data.FindReward = {Common = 10, Rare = 30, Epic = 80, Legendary = 200}

-- Pet levels: XP comes from doing jobs. Each level adds LevelBonus to speed and job power.
Data.XpPerLevel = 10
Data.MaxLevel = 10
Data.LevelBonus = 0.05

-- Expeditions (sent from the Expedition Booth), easiest first. Secs are real seconds.
-- Need = pet power for a great chance. Berry = crop name brought back. Egg = which egg it can find.
Data.Expeditions = {
	{Name = "Sunny Meadow", Scene = "Meadow", Res = {"Fiber", "Stone"}, ResAmount = 6, Stars = 1, Secs = 30 * 60, Need = 1, Coins = 20, Berries = 3, Berry = "Puffberry",
		EggChance = 0.05, Egg = "Mystery", Color = Color3.fromRGB(120, 210, 90)},
	{Name = "Mushroom Forest", Scene = "Forest", Res = {"Wood", "Mushroom"}, ResAmount = 7, Stars = 2, Secs = 3600, Need = 3, Coins = 45, Berries = 5, Berry = "Sunberry",
		EggChance = 0.12, Egg = "Mystery", Color = Color3.fromRGB(200, 120, 230)},
	{Name = "Frosty Peaks", Scene = "Peaks", Res = {"Ice", "Iron"}, ResAmount = 7, Stars = 3, Secs = 2 * 3600, Need = 5, Coins = 90, Berries = 8, Berry = "Moonplum",
		EggChance = 0.25, Egg = "Mystery", Color = Color3.fromRGB(120, 200, 255)},
	{Name = "Crystal Caves", Scene = "Caves", Res = {"Gold", "Gem"}, ResAmount = 6, Stars = 4, Secs = 4 * 3600, Need = 8, Coins = 160, Berries = 12, Berry = "Moonplum",
		EggChance = 0.4, Egg = "Crystal", Color = Color3.fromRGB(150, 110, 255)},
	{Name = "Lava Volcano", Scene = "Volcano", Res = {"Magma", "Obsidian"}, ResAmount = 5, Stars = 5, Secs = 8 * 3600, Need = 12, Coins = 320, Berries = 18, Berry = "Rainbow Drop",
		EggChance = 0.7, Egg = "Lava", Color = Color3.fromRGB(255, 110, 60)},
}
-- Pet power = rarity power + PowerPerLevel per level above 1.
Data.RarityPower = {Common = 1, Rare = 3, Epic = 6, Legendary = 10}
Data.PowerPerLevel = 0.5
-- Chance the trip goes great. If not, the pet comes home early with a small gift.
function Data.TripChance(power, need)
	return math.clamp(0.25 + 0.7 * power / need, 0.25, 0.95)
end
function Data.PetPower(rarity, level)
	return Data.RarityPower[rarity] + Data.PowerPerLevel * (level - 1)
end

-- Eggs hatch after EggHatchSecs into a random critter. Harder places find better eggs.
Data.EggHatchSecs = 3600
Data.Eggs = {
	Mystery = {Name = "Mystery Egg", Icon = "🥚", Weights = {Common = 30, Rare = 40, Epic = 22, Legendary = 8}},
	Crystal = {Name = "Crystal Egg", Icon = "💎", Weights = {Common = 10, Rare = 40, Epic = 35, Legendary = 15}},
	Lava = {Name = "Lava Egg", Icon = "🔥", Weights = {Common = 0, Rare = 25, Epic = 50, Legendary = 25}},
	Star = {Name = "Star Egg", Icon = "🌟", Weights = {Common = 0, Rare = 20, Epic = 45, Legendary = 35}}, -- from falling stars and bosses
	-- limited: only drops while Data.Seasonal is on; every pet from it wears the limited Leaf Crown
	Harvest = {Name = "Harvest Egg", Icon = "🍂", Weights = {Common = 0, Rare = 35, Epic = 45, Legendary = 20}, Limited = true, Outfit = "Leaf Crown"},
	-- from the 💕 Best Friends Nest: the baby is one of its two parents (or, rarely, a secret mix)
	Friend = {Name = "Friend Egg", Icon = "💕", Weights = {Common = 25, Rare = 40, Epic = 25, Legendary = 10}, NoDrop = true},
}
-- 🥚 eggs sold in the town shop. The stock rolls every hour: each slot is a tier picked by Chance.
-- Weights = what the egg hatches into (pet rarity). NoDrop: only the shop sells them.
Data.Eggs.CommonEgg = {Name = "Common Egg", Icon = "🥚", Weights = {Common = 70, Rare = 25, Epic = 4.5, Legendary = 0.5}, NoDrop = true}
Data.Eggs.UncommonEgg = {Name = "Uncommon Egg", Icon = "🍀", Weights = {Common = 40, Rare = 45, Epic = 13, Legendary = 2}, NoDrop = true}
Data.Eggs.RareEgg = {Name = "Rare Egg", Icon = "💠", Weights = {Common = 10, Rare = 45, Epic = 37, Legendary = 8}, NoDrop = true}
Data.Eggs.UltraEgg = {Name = "Ultra Rare Egg", Icon = "👑", Weights = {Common = 0, Rare = 15, Epic = 50, Legendary = 35}, NoDrop = true}
Data.EggShop = {
	RestockSecs = 3600, -- new eggs every hour
	Slots = 6, -- eggs in stock each hour (each one can be bought once per player)
	Tiers = {
		{Egg = "CommonEgg", Chance = 0.80, Price = 500},
		{Egg = "UncommonEgg", Chance = 0.15, Price = 1500},
		{Egg = "RareEgg", Chance = 0.045, Price = 5000},
		{Egg = "UltraEgg", Chance = 0.005, Price = 50000},
	},
}

-- The limited egg of the season: drops from expeditions (Chance) and world events until Ends.
Data.Seasonal = {Egg = "Harvest", Chance = 0.12, Ends = os.time({year = 2026, month = 12, day = 1, hour = 0})}
function Data.SeasonalOn() return os.time() < Data.Seasonal.Ends end

Data.GoldenChance = 0.06 -- chance a harvest is Golden (x3 berries)

-- Plots grow this when you can't plant your chosen seed (locked or not enough coins).
Data.FarmCrop = "Puffberry"

---------------------------------------------------------------- farm level
-- Total farm XP needed for each level (index = level). XP: plant/water +1, harvest +1 per berry x tier,
-- befriend/hatch +10, present +3, expedition +5. Pets doing jobs earn XP for their owner too.
Data.FarmLevelXp = {0, 25, 60, 110, 180, 270, 380, 520, 700, 920, 1200, 1550, 2000, 2550, 3200}
Data.FarmLevelCoins = 20 -- coins x new level on level up (plus 1 free spin)
function Data.FarmLevel(xp)
	local lv = 1
	for i, need in Data.FarmLevelXp do
		if xp >= need then lv = i end
	end
	return lv, Data.FarmLevelXp[lv], Data.FarmLevelXp[lv + 1] -- next is nil at max level
end

---------------------------------------------------------------- variants (RNG)
-- Rolled when a wild critter appears or an egg hatches. Mult = job speed and battle stats.
Data.Variants = {
	{Name = "Shiny", Icon = "✨", Chance = 1 / 50, Mult = 1.15, Color = Color3.fromRGB(255, 215, 90)},
	{Name = "Rainbow", Icon = "🌈", Chance = 1 / 250, Mult = 1.3, Color = Color3.fromRGB(255, 120, 220)},
}
Data.VariantByName = {}
for _, v in Data.Variants do Data.VariantByName[v.Name] = v end
Data.Sizes = {
	{Name = "Tiny", Icon = "🐭", Chance = 1 / 15, Scale = 0.7},
	{Name = "Huge", Icon = "🐘", Chance = 1 / 20, Scale = 1.6},
}
Data.SizeByName = {}
for _, s in Data.Sizes do Data.SizeByName[s.Name] = s end
Data.StarNightLuck = 3 -- variant chances x3 during a Shooting Star Night
Data.EggLuck = {Mystery = 1.5, Crystal = 2, Lava = 3, Star = 5, Harvest = 3} -- variant chances when hatching

---------------------------------------------------------------- happiness
Data.HappyStart = 70
Data.HappyDecaySecs = 150 -- loses 1 happiness every this many seconds (100 -> 0 in about 4 hours)
Data.PetHappy = 12 -- per pet (each pet can be petted every PetCooldown seconds)
Data.PetCooldown = 3
Data.FeedHappy = 5 -- x berry tier
Data.HappyHigh, Data.HappyLow = 80, 25
Data.HappyMult = 1.2 -- very happy: works 20% faster, +10% battle stats
Data.SadMult = 0.8 -- sad: works 20% slower
Data.PetGiftChance = 0.08 -- chance a petted pet finds you a little gift

---------------------------------------------------------------- outfits
-- Hats built from parts (CritterUI.BuildOutfit). Unlocked once, any pet can wear them.
Data.Outfits = {
	{Name = "Flower", Icon = "🌼", Rarity = "Common"},
	{Name = "Bow", Icon = "🎀", Rarity = "Common"},
	{Name = "Party Hat", Icon = "🥳", Rarity = "Common"},
	{Name = "Beanie", Icon = "🧶", Rarity = "Rare"},
	{Name = "Top Hat", Icon = "🎩", Rarity = "Rare"},
	{Name = "Wizard Hat", Icon = "🧙", Rarity = "Epic"},
	{Name = "Halo", Icon = "😇", Rarity = "Epic"},
	{Name = "Crown", Icon = "👑", Rarity = "Legendary"},
	{Name = "Bunny Ears", Icon = "🐰", Rarity = "Common"},
	{Name = "Cat Ears", Icon = "🐱", Rarity = "Common"},
	{Name = "Flower Crown", Icon = "🌸", Rarity = "Rare"},
	{Name = "Straw Hat", Icon = "👒", Rarity = "Rare"},
	{Name = "Leaf Crown", Icon = "🍂", Rarity = "Legendary", Limited = true}, -- only from the Harvest Egg
}
Data.OutfitByName = {}
for _, o in Data.Outfits do Data.OutfitByName[o.Name] = o end
Data.OutfitWeights = {Common = 55, Rare = 30, Epic = 12, Legendary = 3}
Data.OutfitDupCoins = {Common = 15, Rare = 40, Epic = 100, Legendary = 300} -- already have it? coins instead
Data.StarterOutfit = "Bow"
-- 👗 Bow & Bell Boutique (town): pet hats cost this many coins (Limited ones are never sold)
Data.OutfitPrice = {Common = 400, Rare = 1500, Epic = 5000, Legendary = 20000}
-- clothes for YOUR character, built from parts (CritterUI.BuildWear). One of each Slot at a time.
-- Always in stock: buy once with coins, keep forever.
Data.WearSlots = {"Hat", "Face", "Back"}
Data.Wearables = {
	{Name = "Flower Crown", Icon = "🌸", Slot = "Hat", Price = 300, Rarity = "Common"},
	{Name = "Bunny Ears", Icon = "🐰", Slot = "Hat", Price = 600, Rarity = "Common"},
	{Name = "Cat Ears", Icon = "🐱", Slot = "Hat", Price = 600, Rarity = "Common"},
	{Name = "Party Hat", Icon = "🥳", Slot = "Hat", Price = 800, Rarity = "Common"},
	{Name = "Straw Hat", Icon = "👒", Slot = "Hat", Price = 900, Rarity = "Common"},
	{Name = "Beanie", Icon = "🧶", Slot = "Hat", Price = 1200, Rarity = "Rare"},
	{Name = "Top Hat", Icon = "🎩", Slot = "Hat", Price = 2500, Rarity = "Rare"},
	{Name = "Wizard Hat", Icon = "🧙", Slot = "Hat", Price = 6000, Rarity = "Epic"},
	{Name = "Crown", Icon = "👑", Slot = "Hat", Price = 25000, Rarity = "Legendary"},
	{Name = "Round Glasses", Icon = "👓", Slot = "Face", Price = 500, Rarity = "Common"},
	{Name = "Heart Shades", Icon = "💖", Slot = "Face", Price = 1500, Rarity = "Rare"},
	{Name = "Star Shades", Icon = "⭐", Slot = "Face", Price = 4000, Rarity = "Epic"},
	{Name = "Critter Backpack", Icon = "🎒", Slot = "Back", Price = 1000, Rarity = "Common"},
	{Name = "Hero Cape", Icon = "🦸", Slot = "Back", Price = 2500, Rarity = "Rare"},
	{Name = "Butterfly Wings", Icon = "🦋", Slot = "Back", Price = 8000, Rarity = "Epic"},
	{Name = "Angel Wings", Icon = "🪽", Slot = "Back", Price = 20000, Rarity = "Legendary"},
}
Data.WearByName = {}
for _, w in Data.Wearables do Data.WearByName[w.Name] = w end

---------------------------------------------------------------- prizes (RNG)
-- Type = Coins | Berry | Egg | Outfit (random by OutfitWeights) | Spin. Weight = how often.
Data.SpinPrizes = {
	{Type = "Coins", Amount = 25, Weight = 26, Rarity = "Common"},
	{Type = "Berry", Crop = "Sunberry", Amount = 5, Weight = 18, Rarity = "Common"},
	{Type = "Coins", Amount = 75, Weight = 14, Rarity = "Rare"},
	{Type = "Berry", Crop = "Moonplum", Amount = 4, Weight = 10, Rarity = "Rare"},
	{Type = "Outfit", Weight = 10, Rarity = "Epic"},
	{Type = "Egg", Kind = "Mystery", Weight = 8, Rarity = "Rare"},
	{Type = "Berry", Crop = "Rainbow Drop", Amount = 3, Weight = 5, Rarity = "Epic"},
	{Type = "Egg", Kind = "Crystal", Weight = 3, Rarity = "Epic"},
	{Type = "Spin", Amount = 2, Weight = 3, Rarity = "Epic"},
	{Type = "Seed", Crop = "Cherry Tree", Amount = 1, Weight = 4, Rarity = "Epic"},
	{Type = "Coins", Amount = 500, Weight = 1.5, Rarity = "Legendary"},
	{Type = "Egg", Kind = "Lava", Weight = 1, Rarity = "Legendary"},
}
-- Mystery presents that pop up around the farm and meadow (first one to open it wins).
Data.PresentPrizes = {
	{Type = "Coins", Amount = 15, Weight = 35, Rarity = "Common"},
	{Type = "Berry", Crop = "Puffberry", Amount = 5, Weight = 20, Rarity = "Common"},
	{Type = "Berry", Crop = "Sunberry", Amount = 3, Weight = 15, Rarity = "Rare"},
	{Type = "Coins", Amount = 50, Weight = 10, Rarity = "Rare"},
	{Type = "Outfit", Weight = 7, Rarity = "Epic"},
	{Type = "Spin", Amount = 1, Weight = 6, Rarity = "Epic"},
	{Type = "Egg", Kind = "Mystery", Weight = 5, Rarity = "Epic"},
	{Type = "Seed", Crop = "Pumpkin", Amount = 1, Weight = 8, Rarity = "Rare"},
	{Type = "Coins", Amount = 250, Weight = 1, Rarity = "Legendary"},
}
Data.PresentGap = {35, 70} -- seconds between presents
Data.PresentMax = 3
Data.PresentStay = 90
-- Little gifts a petted pet sometimes finds.
Data.PetGifts = {
	{Type = "Coins", Amount = 10, Weight = 50, Rarity = "Common"},
	{Type = "Berry", Crop = "Sunberry", Amount = 2, Weight = 30, Rarity = "Rare"},
	{Type = "Spin", Amount = 1, Weight = 8, Rarity = "Epic"},
	{Type = "Outfit", Weight = 4, Rarity = "Epic"},
}
Data.DailySpins = 1 -- free spins each new day

---------------------------------------------------------------- open world: biomes
-- Each biome has its own wild critters (some only live in one place). Part = ground part in the world:
-- Meadow uses CritterAcres.Meadow, the rest CritterAcres.Biome_<Name>.Ground (built by BuildWorld.lua).
Data.Biomes = {
	{Name = "Meadow", Icon = "🌼", WildMax = 4, Color = Color3.fromRGB(150, 220, 110),
		Species = {"Hopsy", "Sprig", "Splashy", "Nibblet", "Bloomby", "Purrkin"}},
	{Name = "Forest", Icon = "🍄", WildMax = 3, Color = Color3.fromRGB(170, 100, 210),
		Species = {"Pebbleback", "Sprig", "Thornox", "Pockets", "Glimmer"}},
	{Name = "Peaks", Icon = "❄️", WildMax = 3, Color = Color3.fromRGB(130, 200, 255),
		Species = {"Splashy", "Drizzle", "Zippit", "Frostmaw", "Stormwing"}},
	{Name = "Caves", Icon = "💎", WildMax = 3, Color = Color3.fromRGB(150, 110, 255),
		Species = {"Pebbleback", "Zippit", "Glimmer", "Prism"}},
	{Name = "Volcano", Icon = "🌋", WildMax = 3, Color = Color3.fromRGB(255, 110, 60),
		Species = {"Nibblet", "Emberclaw", "Thornox", "Viridrake"}},
}
Data.BiomeByName = {}
Data.SpeciesBiomes = {} -- species name -> list of biome icons (for the Book)
for _, b in Data.Biomes do
	Data.BiomeByName[b.Name] = b
	for _, s in b.Species do
		Data.SpeciesBiomes[s] = Data.SpeciesBiomes[s] or {}
		table.insert(Data.SpeciesBiomes[s], b.Icon)
	end
end

---------------------------------------------------------------- personal farms
Data.FarmHelpCoins = 2 -- coins for watering a friend's crop
Data.LikeCoins = 5 -- coins for liking someone's farm (once per farm per day)

---------------------------------------------------------------- berry mutations and sizes
-- Rate = chance per second while that weather is on (growing crops only). Ripen = chance when it ripens.
-- Several mutations multiply together. Pets with Mutate = {name, chance} add a roll each time they work a plot.
Data.Mutations = {
	{Name = "Juicy", Icon = "💧", Mult = 2, Weather = "Rain", Rate = 0.012, Color = Color3.fromRGB(90, 180, 255)},
	{Name = "Golden", Icon = "🌟", Mult = 3, Weather = "GoldenSun", Rate = 0.008, Ripen = 0.05, Color = Color3.fromRGB(255, 210, 60)},
	{Name = "Frosty", Icon = "❄️", Mult = 4, Weather = "Snow", Rate = 0.008, Color = Color3.fromRGB(190, 235, 255)},
	{Name = "Starry", Icon = "⭐", Mult = 5, Weather = "StarNight", Rate = 0.006, Color = Color3.fromRGB(200, 170, 255)},
	{Name = "Zapped", Icon = "⚡", Mult = 8, Weather = "Storm", Rate = 0.005, Color = Color3.fromRGB(255, 255, 120)},
	{Name = "Prismatic", Icon = "🌈", Mult = 20, Ripen = 0.004, Color = Color3.fromRGB(255, 130, 230)},
}
Data.MutationByName = {}
for _, m in Data.Mutations do Data.MutationByName[m.Name] = m end
-- Size rolled when a berry ripens (rarest first). Value = sell multiplier.
Data.CropSizes = {
	{Name = "MEGA", Icon = "MEGA", Chance = 0.006, Scale = 3.4, Value = 8},
	{Name = "Huge", Icon = "XXL", Chance = 0.04, Scale = 2.2, Value = 3},
	{Name = "Big", Icon = "XL", Chance = 0.14, Scale = 1.5, Value = 1.5},
}
Data.CropSizeByName = {}
for _, s in Data.CropSizes do Data.CropSizeByName[s.Name] = s end
Data.SpecialMax = 40 -- special (mutated/big) berries you can carry; more sell straight away
-- Value of one special harvest
function Data.SpecialValue(crop, count, muts, sizeName)
	local mult = 1
	for _, n in muts or {} do
		local m = Data.MutationByName[n]
		if m then mult *= m.Mult end
	end
	local s = sizeName and Data.CropSizeByName[sizeName]
	return math.floor(crop.Price * count * mult * (s and s.Value or 1))
end

---------------------------------------------------------------- fusion
-- 3 of the same species (same variant) -> 1 of the next variant.
Data.FuseNext = {[""] = "Shiny", Shiny = "Rainbow"}
Data.FuseCount = 3

---------------------------------------------------------------- pet play (buddy = the pet that follows you)
Data.Tricks = {
	{Name = "Spin", Icon = "🔄", Level = 1},
	{Name = "Jump", Icon = "🦘", Level = 2},
	{Name = "Dance", Icon = "💃", Level = 4},
	{Name = "Flip", Icon = "🤸", Level = 6},
	{Name = "Roll", Icon = "🌀", Level = 8},
}
Data.TrickHappy = 3
Data.FetchHappy = 8
Data.FetchGiftEvery = 5 -- every 5 fetches in a row: a gift roll
Data.RubHappy = 25 -- finishing the rub mini game
Data.RubCooldown = 8

---------------------------------------------------------------- world events (server-wide, on a timer)
Data.EventGap = {150, 230} -- seconds between events
Data.EventWarn = 15 -- countdown before an event starts
Data.Events = {
	{Name = "FallingStar", Icon = "🌠", Weight = 3, Secs = 60},
	{Name = "CatchRace", Icon = "🏃", Weight = 3, Secs = 90},
	{Name = "WorldBoss", Icon = "👹", Weight = 2, Secs = 150},
	{Name = "PresentRush", Icon = "🎁", Weight = 2, Secs = 45},
	{Name = "EggSnatch", Icon = "🥚", Weight = 2, Secs = 90},
	{Name = "FashionShow", Icon = "🎀", Weight = 2, Secs = 75},
}
Data.EventByName = {}
for _, e in Data.Events do Data.EventByName[e.Name] = e end
Data.RaceTags = 3 -- tags needed to win the catch race
Data.RaceTagCoins = 10
Data.StarBigPrize = {Type = "Egg", Kind = "Star", Weight = 1, Rarity = "Legendary"}
Data.StarShardPrizes = {
	{Type = "Coins", Amount = 30, Weight = 40, Rarity = "Common"},
	{Type = "Berry", Crop = "Moonplum", Amount = 2, Weight = 25, Rarity = "Rare"},
	{Type = "Spin", Amount = 1, Weight = 20, Rarity = "Epic"},
	{Type = "Outfit", Weight = 10, Rarity = "Epic"},
	{Type = "Egg", Kind = "Mystery", Weight = 5, Rarity = "Epic"},
}
Data.BossPrizes = {
	{Type = "Coins", Amount = 120, Weight = 30, Rarity = "Rare"},
	{Type = "Berry", Crop = "Rainbow Drop", Amount = 3, Weight = 20, Rarity = "Epic"},
	{Type = "Egg", Kind = "Crystal", Weight = 18, Rarity = "Epic"},
	{Type = "Spin", Amount = 2, Weight = 15, Rarity = "Epic"},
	{Type = "Outfit", Weight = 10, Rarity = "Epic"},
	{Type = "Egg", Kind = "Star", Weight = 4, Rarity = "Legendary"},
	{Type = "Egg", Kind = "Lava", Weight = 3, Rarity = "Legendary"},
}
Data.BossHP = 1500 -- + BossHPPerPlayer for each player in the server
Data.BossHPPerPlayer = 1500
Data.BossClickDamage = 12 -- + 2 per farm level
Data.BossPetDps = 0.12 -- x pet power per second while fighting next to the boss

---------------------------------------------------------------- seed shop, seed packs, seed book
Data.ShopRestockSecs = 300 -- everyone's stock refreshes every 5 minutes
-- Each restock: a seed shows up if math.random() < Chance, with a random Amount. Rare ones get a server shout.
Data.ShopSeeds = {
	{Crop = "Sunberry", Chance = 1, Amount = {3, 6}},
	{Crop = "Pumpkin", Chance = 0.45, Amount = {1, 3}},
	{Crop = "Moonplum", Chance = 0.3, Amount = {1, 3}},
	{Crop = "Apple Tree", Chance = 0.2, Amount = {1, 1}},
	{Crop = "Moonflower", Chance = 0.12, Amount = {1, 2}},
	{Crop = "Rainbow Drop", Chance = 0.08, Amount = {1, 2}},
	{Crop = "Starfruit", Chance = 0.02, Amount = {1, 1}},
}
Data.ShopShoutChance = 0.12 -- seeds this rare or rarer get announced
Data.BellCost = 200 -- 🔔 restock bell for your farm: a big popup when rare seeds arrive
Data.SeedPacks = {
	{Name = "Basic", Icon = "📦", Price = 60, Color = Color3.fromRGB(150, 210, 120), Items = {
		{Crop = "Sunberry", Amount = 3, Weight = 40}, {Crop = "Pumpkin", Amount = 2, Weight = 25}, {Crop = "Moonplum", Amount = 2, Weight = 15},
		{Crop = "Cherry Tree", Amount = 1, Weight = 10}, {Crop = "Moonflower", Amount = 1, Weight = 7}, {Crop = "Mango Tree", Amount = 1, Weight = 3}}},
	{Name = "Rare", Icon = "🎁", Price = 250, Color = Color3.fromRGB(110, 170, 255), Items = {
		{Crop = "Moonplum", Amount = 3, Weight = 28}, {Crop = "Rainbow Drop", Amount = 2, Weight = 20}, {Crop = "Cherry Tree", Amount = 1, Weight = 18},
		{Crop = "Mango Tree", Amount = 1, Weight = 14}, {Crop = "Moonflower", Amount = 2, Weight = 12}, {Crop = "Starfruit", Amount = 1, Weight = 6},
		{Crop = "Dragonfruit Tree", Amount = 1, Weight = 2}}},
	{Name = "Mythic", Icon = "💎", Price = 900, Color = Color3.fromRGB(210, 120, 255), Items = {
		{Crop = "Mango Tree", Amount = 2, Weight = 25}, {Crop = "Starfruit", Amount = 2, Weight = 25}, {Crop = "Rainbow Drop", Amount = 4, Weight = 20},
		{Crop = "Dragonfruit Tree", Amount = 1, Weight = 15}, {Crop = "Moonflower", Amount = 3, Weight = 15}}},
}
Data.SeedPackByName = {}
for _, p in Data.SeedPacks do
	Data.SeedPackByName[p.Name] = p
	for _, it in p.Items do it.Rarity = Data.CropByName[it.Crop].Rarity end
end
Data.DailyFreePacks = 1 -- a free Basic pack every day
-- Seed Book: grow every crop in a row for the reward.
Data.SeedBookRows = {
	{Icon = "🍓", Crops = {"Puffberry", "Sunberry", "Moonplum", "Rainbow Drop"}, Reward = {Type = "Coins", Amount = 200, Rarity = "Rare"}},
	{Icon = "🌳", Crops = {"Apple Tree", "Cherry Tree", "Mango Tree", "Dragonfruit Tree"}, Reward = {Type = "Egg", Kind = "Star", Rarity = "Legendary"}},
	{Icon = "✨", Crops = {"Pumpkin", "Moonflower", "Starfruit"}, Reward = {Type = "Spin", Amount = 5, Rarity = "Epic"}},
}

---------------------------------------------------------------- resources (gathered in the biomes)
-- Each biome has its own resources. Better tools unlock the harder ones (progression Meadow -> Volcano).
Data.Resources = {
	{Name = "Fiber", Icon = "🌾", Color = Color3.fromRGB(180, 220, 110)},
	{Name = "Stone", Icon = "🪨", Color = Color3.fromRGB(160, 160, 170)},
	{Name = "Wood", Icon = "🪵", Color = Color3.fromRGB(160, 110, 70)},
	{Name = "Mushroom", Icon = "🍄", Color = Color3.fromRGB(235, 80, 80)},
	{Name = "Ice", Icon = "🧊", Color = Color3.fromRGB(170, 225, 255)},
	{Name = "Iron", Icon = "⚙️", Color = Color3.fromRGB(190, 190, 205)},
	{Name = "Gold", Icon = "🟡", Color = Color3.fromRGB(255, 205, 60)},
	{Name = "Gem", Icon = "💎", Color = Color3.fromRGB(160, 110, 255)},
	{Name = "Magma", Icon = "🔥", Color = Color3.fromRGB(255, 110, 40)},
	{Name = "Obsidian", Icon = "⬛", Color = Color3.fromRGB(60, 40, 80)},
}
Data.ResByName = {}
for i, r in Data.Resources do
	r.Order = i
	Data.ResByName[r.Name] = r
end
-- Things you can gather. Tool = tool level needed, Hits = hits to break (better tools hit harder), Respawn = seconds.
Data.Nodes = {
	Bush = {Res = "Fiber", Amount = {2, 3}, Tool = 0, Hits = 2, Respawn = 25, Biome = "Meadow", Label = "Grass"},
	Pebble = {Res = "Stone", Amount = {2, 3}, Tool = 1, Hits = 3, Respawn = 30, Biome = "Meadow", Label = "Rock"},
	Log = {Res = "Wood", Amount = {2, 4}, Tool = 0, Hits = 3, Respawn = 30, Biome = "Forest", Label = "Log"},
	Shroom = {Res = "Mushroom", Amount = {1, 2}, Tool = 0, Hits = 2, Respawn = 40, Biome = "Forest", Label = "Mushroom"},
	IceRock = {Res = "Ice", Amount = {2, 3}, Tool = 1, Hits = 3, Respawn = 35, Biome = "Peaks", Label = "Ice"},
	IronOre = {Res = "Iron", Amount = {1, 3}, Tool = 2, Hits = 4, Respawn = 45, Biome = "Peaks", Label = "Iron Ore"},
	GoldOre = {Res = "Gold", Amount = {1, 2}, Tool = 3, Hits = 4, Respawn = 50, Biome = "Caves", Label = "Gold Ore"},
	GemRock = {Res = "Gem", Amount = {1, 2}, Tool = 3, Hits = 5, Respawn = 60, Biome = "Caves", Label = "Gems"},
	MagmaRock = {Res = "Magma", Amount = {1, 2}, Tool = 4, Hits = 5, Respawn = 60, Biome = "Volcano", Label = "Magma"},
	ObsidianRock = {Res = "Obsidian", Amount = {1, 2}, Tool = 4, Hits = 6, Respawn = 75, Biome = "Volcano", Label = "Obsidian"},
}
-- Tool levels (one tool that chops and mines). Power = hit strength.
Data.Tools = {
	[0] = {Name = "Hands", Icon = "✋", Power = 1},
	[1] = {Name = "Wood Tool", Icon = "🪓", Power = 1, Cost = {Wood = 6, Fiber = 4}},
	[2] = {Name = "Stone Tool", Icon = "⛏️", Power = 2, Cost = {Stone = 10, Wood = 6}},
	[3] = {Name = "Iron Tool", Icon = "⚒️", Power = 2, Cost = {Iron = 8, Wood = 8, Coins = 150}},
	[4] = {Name = "Gold Tool", Icon = "🔱", Power = 3, Cost = {Gold = 6, Gem = 4, Coins = 400}},
	[5] = {Name = "Magma Tool", Icon = "🌋", Power = 4, Cost = {Magma = 6, Obsidian = 4, Coins = 900}},
}
Data.ToolMax = 5

---------------------------------------------------------------- crafting at the workbench (plaza)
-- Pet gear: crafted gear rolls a random rarity (Common 60, Rare 30, Epic 9, Legendary 1).
Data.GearRecipes = {
	{Kind = 1, Cost = {Fiber = 8, Wood = 4}}, -- Leaf Helmet
	{Kind = 2, Cost = {Wood = 6, Iron = 3}}, -- Thorn Claws
	{Kind = 3, Cost = {Fiber = 6, Ice = 4}}, -- Feather Boots
	{Kind = 4, Cost = {Stone = 10, Iron = 4}}, -- Shell Shield
	{Kind = 5, Cost = {Magma = 3, Gem = 2}}, -- Ember Charm
}
Data.CraftRarity = {Common = 60, Rare = 30, Epic = 9, Legendary = 1}
-- ⭐ gear upgrades (index = the level you upgrade TO)
Data.GearUpgrades = {
	{Iron = 3, Coins = 50},
	{Iron = 4, Gold = 2, Coins = 100},
	{Gold = 3, Gem = 3, Coins = 200},
	{Gem = 4, Magma = 3, Coins = 400},
	{Magma = 4, Obsidian = 4, Coins = 800},
}

---------------------------------------------------------------- farm upgrades
Data.StartPlots = 9 -- plots 10-15 are locked at first
Data.PlotUnlocks = { -- index = plot number
	[10] = {Coins = 150, Wood = 8}, [11] = {Coins = 250, Wood = 12, Stone = 6}, [12] = {Coins = 400, Stone = 12, Iron = 3},
	[13] = {Coins = 600, Iron = 6, Ice = 4}, [14] = {Coins = 900, Gold = 3, Gem = 2}, [15] = {Coins = 1400, Magma = 3, Obsidian = 2},
}
-- Soil level per plot: faster growing (Grow) and luckier mutations (Luck).
Data.Soil = {
	{Name = "Dirt", Grow = 1, Luck = 1, Color = Color3.fromRGB(150, 100, 62)},
	{Name = "Rich Soil", Grow = 1.2, Luck = 1.2, Color = Color3.fromRGB(110, 75, 50), Cost = {Stone = 6, Coins = 60}},
	{Name = "Magic Soil", Grow = 1.45, Luck = 1.6, Color = Color3.fromRGB(110, 70, 140), Cost = {Iron = 4, Gold = 2, Coins = 200}},
	{Name = "Star Soil", Grow = 1.8, Luck = 2.2, Color = Color3.fromRGB(60, 60, 110), Cost = {Gem = 3, Magma = 2, Coins = 500}},
}
-- Decorations: placed anywhere on your farm. Some do things (Effect): Sprinkler waters plots near it,
-- Beehive makes plots near it grow faster. Cost can be coins and/or resources.
Data.Decor = {
	{Name = "Flower Bed", Icon = "🌷", Cost = {Coins = 30}},
	{Name = "White Fence", Icon = "🤍", Cost = {Coins = 10}},
	{Name = "Hay Bale", Icon = "🌾", Cost = {Fiber = 6}},
	{Name = "Oak Tree", Icon = "🌳", Cost = {Wood = 10, Coins = 40}},
	{Name = "Bench", Icon = "🪑", Cost = {Wood = 8}},
	{Name = "Lamp Post", Icon = "💡", Cost = {Iron = 2, Coins = 60}},
	{Name = "Mushroom House", Icon = "🍄", Cost = {Mushroom = 6, Wood = 6}},
	{Name = "Snowman", Icon = "⛄", Cost = {Ice = 8}},
	{Name = "Pond", Icon = "💧", Cost = {Stone = 10, Coins = 80}},
	{Name = "Fountain", Icon = "⛲", Cost = {Stone = 16, Coins = 150}},
	{Name = "Windmill", Icon = "🌀", Cost = {Wood = 20, Stone = 10, Coins = 120}},
	{Name = "Crystal Lamp", Icon = "🔮", Cost = {Gem = 3, Coins = 100}},
	{Name = "Gold Statue", Icon = "🗿", Cost = {Stone = 20, Gold = 4, Coins = 300}},
	{Name = "Lava Lamp", Icon = "🌋", Cost = {Magma = 3, Obsidian = 1}},
	{Name = "Sprinkler", Icon = "💦", Cost = {Iron = 4, Stone = 6, Coins = 100}, Effect = "Water", Range = 14},
	{Name = "Beehive", Icon = "🐝", Cost = {Wood = 8, Mushroom = 4, Coins = 80}, Effect = "Grow", Range = 14, Boost = 0.25},
}
Data.DecorByName = {}
for _, d in Data.Decor do Data.DecorByName[d.Name] = d end
Data.DecorMax = 40 -- decorations per farm

---------------------------------------------------------------- toys, titles, acorns, lucky hour
Data.Toys = {
	{Name = "Bubble Wand", Icon = "🫧", Cost = nil}, -- everyone has it
	{Name = "Confetti", Icon = "🎊", Cost = {Coins = 120}},
	{Name = "Fireworks", Icon = "🎆", Cost = {Magma = 2, Gem = 1, Coins = 200}},
}
Data.ToyByName = {}
for _, t in Data.Toys do Data.ToyByName[t.Name] = t end
Data.Titles = {
	{Name = "Little Farmer", Icon = "🌱", How = "Start playing"},
	{Name = "Shiny Hunter", Icon = "🌟", How = "Own 3 shiny pets"},
	{Name = "Pumpkin King", Icon = "🎃", How = "Grow a MEGA berry"},
	{Name = "Boss Slayer", Icon = "👹", How = "Hit a World Boss the most"},
	{Name = "Speedy Catcher", Icon = "🏃", How = "Win a Catch Race"},
	{Name = "Acorn Master", Icon = "🌰", How = "Find all golden acorns"},
	{Name = "Master Crafter", Icon = "🔨", How = "Make the Magma Tool"},
	{Name = "Popular", Icon = "❤️", How = "Get 10 farm likes"},
	{Name = "Egg Hatcher", Icon = "🐣", How = "Hatch 10 eggs"},
	{Name = "Explorer", Icon = "🗺️", How = "Visit every biome"},
}
Data.TitleByName = {}
for _, t in Data.Titles do Data.TitleByName[t.Name] = t end
Data.AcornCount = 30
Data.AcornCoins = 25
Data.AcornRewards = { -- at this many acorns found
	[10] = {Type = "Spin", Amount = 3, Rarity = "Epic"},
	[20] = {Type = "Egg", Kind = "Star", Rarity = "Legendary"},
	[30] = {Type = "Outfit", Name = "Crown", Rarity = "Legendary"},
}
Data.LuckyHourMult = 2 -- shiny chances during the daily lucky hour

function Data.CostText(cost) -- e.g. "💰60 🪵8"
	local parts = {}
	if cost.Coins then table.insert(parts, "💰" .. cost.Coins) end
	for _, r in Data.Resources do
		if cost[r.Name] then table.insert(parts, r.Icon .. cost[r.Name]) end
	end
	return table.concat(parts, " ")
end

function Data.PrizeIcon(p)
	if p.Type == "Coins" then return "💰" end
	if p.Type == "Res" then return Data.ResByName[p.Res].Icon end
	if p.Type == "Seed" then return Data.CropByName[p.Crop].Icon end
	if p.Type == "Berry" then return Data.CropByName[p.Crop].Icon end
	if p.Type == "Egg" then return Data.Eggs[p.Kind].Icon end
	if p.Type == "Outfit" then return p.Name and Data.OutfitByName[p.Name].Icon or "👒" end
	return "🎡"
end
-- Risky expeditions (chance below this) bring back nothing when they fail, and the pet is exhausted.
Data.RiskyChance = 0.5
Data.PetRestSecs = 2 * 3600 -- an exhausted pet's energy refills over this long

-- Daily quests: 3 are picked each day. Count = how many; Reward = coins.
Data.QuestPool = {
	{Kind = "Harvest", Count = 15, Reward = 30, Text = "Harvest %d berries"},
	{Kind = "Plant", Count = 10, Reward = 25, Text = "Plant %d seeds"},
	{Kind = "Water", Count = 8, Reward = 20, Text = "Water %d crops"},
	{Kind = "Sell", Count = 150, Reward = 40, Text = "Earn %d coins at the stall"},
	{Kind = "Befriend", Count = 1, Reward = 40, Text = "Befriend %d critter"},
	{Kind = "Feed", Count = 10, Reward = 40, Text = "Feed pets %d berries"},
	{Kind = "Golden", Count = 1, Reward = 60, Text = "Get %d Golden harvest"},
	{Kind = "Pet", Count = 10, Reward = 25, Text = "Pet your critters %d times"},
	{Kind = "Present", Count = 2, Reward = 40, Text = "Open %d presents"},
	{Kind = "Fetch", Count = 5, Reward = 30, Text = "Play fetch %d times"},
	{Kind = "Mutation", Count = 1, Reward = 50, Text = "Harvest %d mutated berry"},
	{Kind = "Event", Count = 1, Reward = 40, Text = "Join %d world event"},
}
Data.StreakGift = 15 -- coins per streak day, up to 7 days

Data.Weather = {
	{Name = "Rain", Text = "It's raining! All crops are watered.", Secs = 60},
	{Name = "StarNight", Text = "Shooting Star Night! Rare critters are wandering in.", Secs = 75},
	{Name = "GoldenSun", Text = "Golden Sun! Berries sell for double.", Secs = 60},
	{Name = "Snow", Text = "❄️ Snow! Berries may turn Frosty (x4).", Secs = 60},
	{Name = "Storm", Text = "⚡ Thunderstorm! Berries may get Zapped (x8).", Secs = 50},
}
Data.WeatherGap = {150, 240} -- seconds between weather events

---------------------------------------------------------------- pets: farm space, storage, growing up, nest
Data.PetCap = 60 -- pets you can own in total (farm + 📦 storage)
function Data.FarmPetCap(level) return math.min(16, 4 + level) end -- pets out on your farm; the rest wait in storage
-- Hatched and nest babies grow up as they level: Baby → Kid → Adult (bigger each time). Grown-up pets get a gift
-- and +10% power ("raised with love").
Data.Stages = {
	{Name = "Baby", Icon = "🍼", Scale = 0.62, Until = 4},
	{Name = "Kid", Icon = "🌱", Scale = 0.8, Until = 8},
	{Name = "Adult", Icon = "🌟", Scale = 1},
}
function Data.StageOf(rec, level)
	if not rec.Raised then return nil end
	for i, st in Data.Stages do
		if not st.Until or level < st.Until then return st, i end
	end
end
Data.GrownBonus = 1.1
Data.GrownGift = {Type = "Coins", Amount = 200, Rarity = "Epic"}
Data.NameMax = 14
-- each pet secretly loves one crop: feeding it fills happiness, gives x3 XP and shows its heart
function Data.FavFood(rec)
	local list = {}
	for _, c in Data.Crops do
		if not c.PackOnly then table.insert(list, c.Name) end
	end
	local sp = Data.SpeciesByName[rec.Species]
	return list[((rec.Id or 1) * 7 + (sp and sp.Index or 1) * 3) % #list + 1]
end
Data.FavXpMult = 3
-- "Send to the wild for a prize" (instead of just letting a pet go)
Data.ReleaseGift = {Common = 15, Rare = 40, Epic = 120, Legendary = 300}
-- 💕 Best Friends Nest: two pets cuddle for NestSecs, then a Friend Egg pops out (both parents stay).
Data.NestSecs = 15 * 60
Data.NestCheer = 25 -- seconds each 💕 cheer takes off
Data.NestRest = 30 * 60 -- a parent rests this long before it can go in again
Data.FriendEgg = {Name = "Friend Egg", Icon = "💕", HatchSecs = 10 * 60}
Data.FriendShinyBoost = 3 -- shiny chance x3 if a parent is shiny
Data.NestMixes = { -- the right two friends can make a secret pet (MixChance), any pair has a tiny chance (AnyMixChance)
	{A = "Splashy", B = "Bloomby", Child = "Bubbloom"},
	{A = "Emberclaw", B = "Frostmaw", Child = "Emberfrost"},
	{A = "Purrkin", B = "Glimmer", Child = "Glitterpaw"},
}
Data.MixChance, Data.AnyMixChance = 0.08, 0.005

-- 🍀 luck meter: every hatch that isn't Epic or better fills it; when full the next egg is Epic or Legendary.
Data.LuckMax = 8
Data.LuckPrize = {Epic = 75, Legendary = 25}
function Data.OddsText(n)
	n = math.floor(n + 0.5)
	local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "1 in " .. s
end

---------------------------------------------------------------- daily + session hooks
-- 🎁 playtime gifts: open after this many minutes in one play session
Data.PlayGifts = {
	{Min = 5, Prize = {Type = "Coins", Amount = 60, Rarity = "Common"}},
	{Min = 10, Prize = {Type = "Seed", Crop = "Sunberry", Amount = 4, Rarity = "Common"}},
	{Min = 15, Prize = {Type = "Spin", Amount = 1, Rarity = "Rare"}},
	{Min = 25, Prize = {Type = "Seed", Crop = "Pumpkin", Amount = 2, Rarity = "Rare"}},
	{Min = 35, Prize = {Type = "Coins", Amount = 250, Rarity = "Rare"}},
	{Min = 45, Prize = {Type = "Egg", Kind = "Mystery", Rarity = "Epic"}},
	{Min = 60, Prize = {Type = "Egg", Kind = "Crystal", Rarity = "Legendary"}},
}
-- 📅 7-day calendar: one box per day you play (missing a day just waits, it never resets)
Data.Calendar = {
	{Type = "Coins", Amount = 100, Rarity = "Common"},
	{Type = "Seed", Crop = "Moonplum", Amount = 3, Rarity = "Rare"},
	{Type = "Spin", Amount = 2, Rarity = "Rare"},
	{Type = "Coins", Amount = 300, Rarity = "Rare"},
	{Type = "Outfit", Rarity = "Epic"},
	{Type = "Seed", Crop = "Moonflower", Amount = 2, Rarity = "Epic"},
	{Type = "Egg", Kind = "Crystal", Rarity = "Legendary"},
}
-- 📬 mailbox: a gift is waiting when you come back after MailAwaySecs (and friends can send you things)
Data.MailAwaySecs = 3600
Data.MailGifts = {
	{Type = "Coins", Amount = 80, Weight = 40, Rarity = "Common"},
	{Type = "Seed", Crop = "Sunberry", Amount = 5, Weight = 25, Rarity = "Common"},
	{Type = "Spin", Amount = 1, Weight = 18, Rarity = "Rare"},
	{Type = "Seed", Crop = "Pumpkin", Amount = 2, Weight = 10, Rarity = "Rare"},
	{Type = "Egg", Kind = "Mystery", Weight = 7, Rarity = "Epic"},
}
Data.GiftsPerDay = 10 -- gifts you can send friends each day
Data.GiftItems = { -- what you can send (taken from your own bag)
	{Kind = "Berry", Crop = "Puffberry", Amount = 5}, {Kind = "Berry", Crop = "Sunberry", Amount = 5},
	{Kind = "Seed", Crop = "Sunberry", Amount = 3}, {Kind = "Seed", Crop = "Moonplum", Amount = 2}, {Kind = "Coins", Amount = 50},
}
-- 👫 friends in the same server: +luck each (shinies, catching, fishing)
Data.FriendLuck, Data.FriendLuckMax = 0.1, 0.5
-- 🏅 Roblox badges: create them on the Creator Dashboard, then paste each badge id here (0 = off)
Data.Badges = {Welcome = 0, FirstShiny = 0, FirstHatch = 0, Legendary = 0, GrownUp = 0, AllAcorns = 0, BossSlayer = 0, Journey = 0,
	SecretPet = 0, Fisher = 0}
-- ⭐ golden critter dash: a sparkly critter zooms past you now and then. Tap it!
Data.DashGap = {80, 160}
Data.DashPrizes = {
	{Type = "Coins", Amount = 40, Weight = 45, Rarity = "Common"},
	{Type = "Seed", Crop = "Moonplum", Amount = 2, Weight = 25, Rarity = "Rare"},
	{Type = "Spin", Amount = 1, Weight = 18, Rarity = "Rare"},
	{Type = "Coins", Amount = 150, Weight = 9, Rarity = "Epic"},
	{Type = "Egg", Kind = "Mystery", Weight = 3, Rarity = "Legendary"},
}
-- 🌈 random farm visitor: when you come back, a Rare+ wild critter may be waiting on your farm (free friend)
Data.VisitorChance = 0.4
Data.VisitorAwaySecs = 1800
-- 🌙 Moon Pot: one giant crop that grows for 8 hours (offline too). Harvest for a big prize.
Data.MoonPotSecs = 8 * 3600
Data.MoonPotPrizes = {
	{Type = "Coins", Amount = 800, Weight = 35, Rarity = "Rare"},
	{Type = "Coins", Amount = 2000, Weight = 15, Rarity = "Epic"},
	{Type = "Seed", Crop = "Starfruit", Amount = 2, Weight = 20, Rarity = "Epic"},
	{Type = "Seed", Crop = "Dragonfruit Tree", Amount = 1, Weight = 12, Rarity = "Legendary"},
	{Type = "Egg", Kind = "Star", Weight = 18, Rarity = "Legendary"},
}
-- 🧺 pile-up: pets that stayed home leave piles on your farm to scoop up (instead of a number)
Data.PileMax = 8

-- 🧭 starter journey (8 steps). Kind = what counts, the last step gives a Rare pet.
Data.Journey = {
	{Kind = "Plant", Count = 1, Text = "Plant a seed on your farm", Prize = {Type = "Coins", Amount = 20, Rarity = "Common"}},
	{Kind = "Water", Count = 1, Text = "Water your plant", Prize = {Type = "Seed", Crop = "Sunberry", Amount = 3, Rarity = "Common"}},
	{Kind = "Harvest", Count = 1, Text = "Pick your berries", Prize = {Type = "Coins", Amount = 30, Rarity = "Common"}},
	{Kind = "Sell", Count = 1, Text = "Sell berries at the stall", Prize = {Type = "Spin", Amount = 1, Rarity = "Rare"}},
	{Kind = "Befriend", Count = 1, Text = "Make a critter friend in the Meadow", Prize = {Type = "Coins", Amount = 50, Rarity = "Rare"}},
	{Kind = "Hatch", Count = 1, Text = "Hatch the egg on your farm", Prize = {Type = "Coins", Amount = 60, Rarity = "Rare"}},
	{Kind = "Explore", Count = 1, Text = "Explore a new place", Prize = {Type = "Seed", Crop = "Moonplum", Amount = 3, Rarity = "Rare"}},
	{Kind = "Decor", Count = 1, Text = "Decorate your farm", Prize = {Type = "Pet", Rarity = "Rare"}},
}
Data.JourneyEgg = 30 -- the journey's free egg hatches in 30 seconds
-- buttons appear when your farm reaches this level (they pop in with NEW!)
Data.ButtonUnlocks = {Decorate = 2, Bag = 2, Nest = 3, Raid = 5, Trade = 4, Gift = 2}

---------------------------------------------------------------- world: gates, NPC quests, fishing, show, raccoons
-- 🚧 biome gates: pay once to open a biome forever (Meadow is always open)
Data.Gates = {
	Forest = {Coins = 100, Level = 2, At = Vector3.new(-192, 0, -10)},
	Peaks = {Coins = 400, Level = 4, At = Vector3.new(192, 0, -10)},
	Caves = {Coins = 1000, Level = 6, At = Vector3.new(-170, 0, -262)},
	Volcano = {Coins = 2500, Level = 8, At = Vector3.new(170, 0, -262)},
}
Data.GateBounds = { -- x1, z1, x2, z2 (matches BuildWorld biome sizes)
	Forest = {-470, -180, -190, 140}, Peaks = {190, -180, 470, 140},
	Caves = {-400, -520, -100, -260}, Volcano = {100, -520, 400, -260},
}
-- 🧑‍🌾 friendly helpers in the plaza with little quest stories
Data.NPCs = {
	{Name = "Farmer Fern", Icon = "🌻", Color = Color3.fromRGB(120, 200, 90), Pos = Vector3.new(-20, 2.6, 12), Chain = {
		{Kind = "Plant", Count = 10, Text = "Plant 10 seeds for my garden club!", Prize = {Type = "Coins", Amount = 60, Rarity = "Common"}},
		{Kind = "Harvest", Count = 30, Text = "Harvest 30 berries.", Prize = {Type = "Seed", Crop = "Moonplum", Amount = 4, Rarity = "Rare"}},
		{Kind = "Golden", Count = 1, Text = "Find a Golden harvest!", Prize = {Type = "Spin", Amount = 2, Rarity = "Rare"}},
		{Kind = "Mutation", Count = 3, Text = "Grow 3 magic (mutated) berries.", Prize = {Type = "Seed", Crop = "Moonflower", Amount = 2, Rarity = "Epic"}},
		{Kind = "Sell", Count = 2000, Text = "Earn 2000 coins at the stall.", Prize = {Type = "Seed", Crop = "Mango Tree", Amount = 1, Rarity = "Legendary"}},
	}},
	{Name = "Explorer Pip", Icon = "🧭", Color = Color3.fromRGB(255, 170, 70), Pos = Vector3.new(-6, 2.6, -22), Face = Vector3.new(-6, 2.6, 0), Chain = { -- by the adventure gate
		{Kind = "Gather", Count = 15, Text = "Gather 15 things in the wild.", Prize = {Type = "Coins", Amount = 60, Rarity = "Common"}},
		{Kind = "ExploreNew", Count = 2, Text = "Discover 2 new places.", Prize = {Type = "Res", Res = "Iron", Amount = 4, Rarity = "Rare"}},
		{Kind = "Acorn", Count = 5, Text = "Find 5 golden acorns.", Prize = {Type = "Spin", Amount = 2, Rarity = "Rare"}},
		{Kind = "Fish", Count = 5, Text = "Catch 5 fish at the pond.", Prize = {Type = "Res", Res = "Gold", Amount = 4, Rarity = "Epic"}},
		{Kind = "Event", Count = 3, Text = "Join 3 world events.", Prize = {Type = "Egg", Kind = "Crystal", Rarity = "Legendary"}},
	}},
	{Name = "Baker Bun", Icon = "🧁", Color = Color3.fromRGB(255, 150, 190), Pos = Vector3.new(-77, 2.6, -1), Face = Vector3.new(-77, 2.6, 12), Chain = { -- outside the bakery
		{Kind = "Pet", Count = 10, Text = "Pet your critters 10 times.", Prize = {Type = "Coins", Amount = 60, Rarity = "Common"}},
		{Kind = "Feed", Count = 10, Text = "Feed your pets 10 berries.", Prize = {Type = "Outfit", Rarity = "Rare"}},
		{Kind = "Befriend", Count = 3, Text = "Make 3 new critter friends.", Prize = {Type = "Spin", Amount = 2, Rarity = "Rare"}},
		{Kind = "Hatch", Count = 2, Text = "Hatch 2 eggs.", Prize = {Type = "Seed", Crop = "Cherry Tree", Amount = 1, Rarity = "Epic"}},
		{Kind = "Nest", Count = 1, Text = "Get an egg from the Best Friends Nest.", Prize = {Type = "Egg", Kind = "Star", Rarity = "Legendary"}},
	}},
}
-- 🎣 fishing pond (meadow, near the plaza): wait for the bobber to dip, then tap fast!
Data.PondPos = Vector3.new(-40, 0, -62)
Data.FishWait = {2, 6}
Data.FishWindow = 1.4 -- seconds to tap after the bite (plus a little for lag)
Data.Fish = {
	{Name = "Old Boot", Icon = "👢", Weight = 14, Coins = 3, Rarity = "Common"},
	{Name = "Minnow", Icon = "🐟", Weight = 34, Coins = 10, Rarity = "Common"},
	{Name = "Bubble Fish", Icon = "🐡", Weight = 22, Coins = 20, Rarity = "Common"},
	{Name = "Rainbow Trout", Icon = "🌈", Weight = 12, Coins = 45, Rarity = "Rare"},
	{Name = "Moon Jelly", Icon = "🪼", Weight = 8, Coins = 70, Rarity = "Rare"},
	{Name = "Golden Koi", Icon = "🐠", Weight = 5, Coins = 150, Rarity = "Epic"},
	{Name = "Star Fish", Icon = "⭐", Weight = 3, Coins = 250, Rarity = "Epic"},
	{Name = "Treasure Chest", Icon = "🧰", Weight = 1.5, Coins = 400, Rarity = "Legendary", Egg = "Mystery"},
	{Name = "Pond King", Icon = "🐋", Weight = 0.5, Coins = 1000, Rarity = "Legendary"},
}
-- 🎀 fashion show (a world event): enter your buddy pet, everyone votes, the winner gets the crown title
Data.StagePos = Vector3.new(82, 2.84, 58) -- 🎡 Festival Green (east side of town)
Data.ShowEnterSecs, Data.ShowVoteSecs = 35, 25
Data.ShowWinPrize = {Type = "Coins", Amount = 300, Rarity = "Epic"}
Data.ShowEnterPrize = {Type = "Coins", Amount = 40, Rarity = "Common"}
-- 🥚 egg snatch (a world event): carry the golden egg to the 🌀 Meadow portal, others can tag you to grab it
Data.SnatchPrize = {Type = "Egg", Kind = "Star", Rarity = "Legendary"}
-- 🦝 sneaky raccoons try to grab ripe berries from your farm: tap them before they run off!
Data.RaccoonGap = {100, 200}
Data.RaccoonPrizes = {
	{Type = "Coins", Amount = 30, Weight = 50, Rarity = "Common"},
	{Type = "Seed", Crop = "Pumpkin", Amount = 1, Weight = 25, Rarity = "Rare"},
	{Type = "Spin", Amount = 1, Weight = 15, Rarity = "Rare"},
	{Type = "Seed", Crop = "Starfruit", Amount = 1, Weight = 10, Rarity = "Epic"},
}
-- ✨ rare fruit drops somewhere in the world now and then: first one to grab it keeps it
Data.FruitGap = {70, 140}
Data.FruitDrops = {
	{Type = "Seed", Crop = "Cherry Tree", Amount = 1, Weight = 30, Rarity = "Epic"},
	{Type = "Seed", Crop = "Mango Tree", Amount = 1, Weight = 22, Rarity = "Epic"},
	{Type = "Seed", Crop = "Starfruit", Amount = 2, Weight = 25, Rarity = "Epic"},
	{Type = "Seed", Crop = "Dragonfruit Tree", Amount = 1, Weight = 10, Rarity = "Legendary"},
	{Type = "Coins", Amount = 300, Weight = 13, Rarity = "Rare"},
}
-- 🐎 riding: walk speed while riding (by pet rarity)
Data.RideSpeed = {Common = 22, Rare = 26, Epic = 30, Legendary = 36}
-- 🤝 trading: up to this many pets each side, both must press Ready then Confirm
Data.TradeMax = 4
-- 💪 Farm Power: one big number that grows with everything you own
function Data.FarmPower(p) -- p = {Pets = {{Rarity, Level, Variant}}, Decor, Plots, Soil, Tool, Gear}
	local n = 0
	for _, pet in p.Pets do
		n += Data.PetPower(pet.Rarity, pet.Level) * 10 * (pet.Variant == "Rainbow" and 2 or (pet.Variant and 1.5 or 1))
	end
	return math.floor(n + p.Decor * 5 + p.Plots * 15 + p.Soil * 8 + p.Tool * 25 + p.Gear * 4)
end

-- player attribute that holds how many seeds of a crop you own (attribute names can't have spaces)
function Data.SeedAttr(name) return "Seed_" .. (name:gsub("[^%w]", "")) end

return Data
