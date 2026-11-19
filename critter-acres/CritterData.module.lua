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

-- Tiers, low to high, one color each (pets, weapons, packs):
--   ⚪ Common · 🟢 Uncommon · 🔵 Rare · 🟣 Epic · 🟡 Legendary · 🔴 Mythic
-- Order feeds the balance math (energy, naps, power), so Uncommon sits between Common and Rare at 1.5.
-- No pets are Uncommon or Mythic yet (Mythic is used by weapons).
Data.RarityOrder = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"}
Data.Rarities = {
	Common = {Order = 1, Weight = 60, Catch = 0.7, Color = Color3.fromRGB(240, 240, 240)},
	Uncommon = {Order = 1.5, Weight = 40, Catch = 0.55, Color = Color3.fromRGB(110, 205, 95)},
	Rare = {Order = 2, Weight = 28, Catch = 0.4, Color = Color3.fromRGB(90, 170, 255)},
	Epic = {Order = 3, Weight = 10, Catch = 0.2, Color = Color3.fromRGB(205, 120, 255)},
	Legendary = {Order = 4, Weight = 2, Catch = 0.08, Color = Color3.fromRGB(255, 200, 60)},
	Mythic = {Order = 5, Weight = 0.5, Catch = 0.03, Color = Color3.fromRGB(255, 80, 80)},
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
-- Since 2026-11-17 the lands are generated fresh for every trip through the 🌀 Explorer's Portal (ServerScriptService.Realms).
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
	-- 📜 dungeon decorations: locked until you find their scroll in that dungeon (Data.Dungeon.Scrolls), then bought like the rest
	{Name = "Slime Lamp", Icon = "🟢", Cost = {Fiber = 8, Stone = 6, Coins = 120}},
	{Name = "Bubble Chair", Icon = "🫧", Cost = {Fiber = 10, Coins = 150}},
	{Name = "Glow Shroom", Icon = "🍄", Cost = {Fiber = 6, Stone = 8, Coins = 100}},
	{Name = "Root Arch", Icon = "🌳", Cost = {Wood = 16, Coins = 160}},
	{Name = "Firefly Jar", Icon = "✨", Cost = {Wood = 6, Mushroom = 6, Coins = 140}},
	{Name = "Acorn Seat", Icon = "🌰", Cost = {Wood = 12, Mushroom = 4, Coins = 140}},
	{Name = "Ice Sculpture", Icon = "🧊", Cost = {Ice = 14, Coins = 200}},
	{Name = "Snow Globe", Icon = "❄️", Cost = {Ice = 8, Iron = 4, Coins = 220}},
	{Name = "Frost Lantern", Icon = "🏮", Cost = {Iron = 6, Ice = 6, Coins = 220}},
	{Name = "Geode", Icon = "💎", Cost = {Gem = 5, Coins = 300}},
	{Name = "Mine Cart", Icon = "🛒", Cost = {Gold = 4, Gem = 2, Coins = 320}},
	{Name = "Gem Tree", Icon = "💠", Cost = {Gem = 6, Gold = 3, Coins = 400}},
	{Name = "Ember Brazier", Icon = "🔥", Cost = {Magma = 4, Obsidian = 2, Coins = 400}},
	{Name = "Dragon Statue", Icon = "🐉", Cost = {Obsidian = 5, Magma = 3, Coins = 600}},
	{Name = "Magma Throne", Icon = "👑", Cost = {Obsidian = 4, Magma = 4, Coins = 500}},
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
-- 🚧 land gates: pay once to open a land forever (Meadow is always open). Opened on the 🌀 Explorer's Portal screen.
Data.Gates = { -- lands open by farm level only (no coins)
	Forest = {Level = 2},
	Peaks = {Level = 4},
	Caves = {Level = 6},
	Volcano = {Level = 8},
}
Data.GateBounds = {} -- the lands are generated maps behind the 🌀 Explorer's Portal now (Realms); old bounds kept below
Data.OldGateBounds = { -- x1, z1, x2, z2 (matched BuildWorld biome sizes)
	Forest = {-470, -180, -190, 140}, Peaks = {190, -180, 470, 140},
	Caves = {-400, -520, -100, -260}, Volcano = {100, -520, 400, -260},
}
-- 🧑‍🌾 friendly helpers in the plaza with little quest stories
Data.NPCs = {
	{Name = "Farmer Fern", Model = "NpcFern", Icon = "🌻", Color = Color3.fromRGB(120, 200, 90), Pos = Vector3.new(-20, 2.6, 22), Face = Vector3.new(4, 2.6, 13), Chain = {
		{Kind = "Plant", Count = 10, Text = "Plant 10 seeds for my garden club!", Prize = {Type = "Coins", Amount = 60, Rarity = "Common"}},
		{Kind = "Harvest", Count = 30, Text = "Harvest 30 berries.", Prize = {Type = "Seed", Crop = "Moonplum", Amount = 4, Rarity = "Rare"}},
		{Kind = "Golden", Count = 1, Text = "Find a Golden harvest!", Prize = {Type = "Spin", Amount = 2, Rarity = "Rare"}},
		{Kind = "Mutation", Count = 3, Text = "Grow 3 magic (mutated) berries.", Prize = {Type = "Seed", Crop = "Moonflower", Amount = 2, Rarity = "Epic"}},
		{Kind = "Sell", Count = 2000, Text = "Earn 2000 coins at the stall.", Prize = {Type = "Seed", Crop = "Mango Tree", Amount = 1, Rarity = "Legendary"}},
	}},
	{Name = "Explorer Pip", Model = "NpcPip", Icon = "🧭", Color = Color3.fromRGB(255, 170, 70), Pos = Vector3.new(-8, 2.6, -42), Face = Vector3.new(-8, 2.6, 0), Chain = { -- by the adventure gate
		{Kind = "Gather", Count = 15, Text = "Gather 15 things in the wild.", Prize = {Type = "Coins", Amount = 60, Rarity = "Common"}},
		{Kind = "ExploreNew", Count = 2, Text = "Discover 2 new places.", Prize = {Type = "Res", Res = "Iron", Amount = 4, Rarity = "Rare"}},
		{Kind = "Acorn", Count = 5, Text = "Find 5 golden acorns.", Prize = {Type = "Spin", Amount = 2, Rarity = "Rare"}},
		{Kind = "Fish", Count = 5, Text = "Catch 5 fish at the pond.", Prize = {Type = "Res", Res = "Gold", Amount = 4, Rarity = "Epic"}},
		{Kind = "Event", Count = 3, Text = "Join 3 world events.", Prize = {Type = "Egg", Kind = "Crystal", Rarity = "Legendary"}},
	}},
	{Name = "Baker Bun", Model = "NpcBun", Icon = "🧁", Color = Color3.fromRGB(255, 150, 190), Pos = Vector3.new(-128, 2.6, -21), Face = Vector3.new(-128, 2.6, 20), Chain = { -- inside the bakery
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
Data.StagePos = Vector3.new(115, 2.84, 70) -- 🎡 Festival Green (east side of town)
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


---------------------------------------------------------------- ⚔️ adventure combat (wild lands only)
-- Mobs in the lands are for battling, never for taming. New pets only come from eggs (mobs sometimes drop one!).
-- At 0 HP you faint (a cute poof) and wake up at the map's portal with full HP. You never lose anything.
-- ⚡ PWR (power) and levels
--   Your PWR = (weapon power + half your buddy pet's ATK) x Hero bonus (+4% for every ⚔️ Hero Level after 1).
--   Every level is worth x1.15 PWR: Lv 1 = PWR 10, Lv 6 ~ 20, Lv 11 ~ 40, Lv 16 ~ 81, Lv 21 ~ 164, Lv 25 ~ 287.
--   👥 Party PWR = everyone in the map added up. Mobs take their LEVEL from the party PWR (more friends = higher
--   level mobs: more HP, better rewards) but hit as hard as the AVERAGE explorer, so bringing a friend never makes
--   the hits scarier. Each land keeps its mobs inside its level range, and mobs deeper in the map (toward the
--   boss den) are up to +2 levels. Your ❤️ HP is 10 x your PWR, so a better weapon or Hero Level makes you tougher too.
Data.Pwr = {Base = 10, Step = 1.15, BuddyShare = 0.5, HeroBonus = 0.04}
function Data.PwrOfLevel(lv) return Data.Pwr.Base * Data.Pwr.Step ^ (lv - 1) end
function Data.LevelOfPwr(pwr) -- (a decimal; floor it to show)
	return math.max(1, 1 + math.log(math.max(pwr, 1) / Data.Pwr.Base) / math.log(Data.Pwr.Step))
end
Data.LandLevels = {Meadow = {1, 5}, Forest = {5, 10}, Peaks = {10, 15}, Caves = {15, 20}, Volcano = {20, 25}}
Data.HpPerPwr = 10
Data.HpRegenDelay = 4 -- seconds without a hit before HP starts coming back
Data.HpRegenPct = 0.06 -- of your max HP every second
Data.SafeSecs = 3 -- can't be hit right after waking up
-- ⚔️ Hero Level: earned by beating mobs (Hero XP). Each level adds Data.Pwr.HeroBonus to your PWR.
Data.HeroMax = 50 -- (= 50 skill points, see Data.Skills)
function Data.HeroNeed(lv) return math.floor(20 * lv ^ 1.6) end -- Hero XP to go from lv to lv + 1

-- mob numbers at level L (x the Special / Boss multipliers below):
--   HP = 30 x 1.18^(L-1)   ATT = 8 x 1.15^(L-1)  (a same-level mob takes ~12 hits to make you faint)
--   coins = 3 x 1.14^(L-1), farm XP = 1 x 1.1^(L-1), Hero XP = 3 x 1.17^(L-1)
Data.MobScale = {HP = 30, HPStep = 1.18, ATT = 8, ATTStep = 1.15, Coins = 3, CoinStep = 1.14, Xp = 1, XpStep = 1.1,
	Hero = 3, HeroStep = 1.17, DepthMax = 2}
Data.MobSpecial = {HP = 2.5, ATT = 1.3, Coins = 5, Xp = 4, Hero = 4, Capsule = 0.2, Egg = 0.1}
Data.MobBoss = {HP = 10, ATT = 1.5, Coins = 25, Xp = 20, Hero = 20, Capsule = 1, Egg = 0.35, Lv = 2} -- Lv = levels above the mobs
Data.MobNormal = {Capsule = 0.025, Egg = 0.012, Res = 0.3}
Data.MobGray = {Below = 6, Reward = 0.25} -- a mob 6+ levels under YOUR level gives only 25% rewards
-- 🏹 ranged mobs: about 1 in 3 in a group stay back and shoot a slow ball down a red lane instead of bonking
Data.MobRanged = {Chance = 0.35, Reach = 20, ATT = 0.8, Speed = 26, R = 1.4, Range = 32, Aim = 0.8, Cd = {2.6, 3.4},
	Look = {Meadow = "Pollen", Forest = "Thorn", Peaks = "Snow", Caves = "Gem", Volcano = "Lava"}}
-- name tag color: how a mob's level compares to yours
function Data.MobDanger(mobLv, myLv)
	local d = mobLv - myLv
	if d <= -Data.MobGray.Below then return "Gray", Color3.fromRGB(190, 190, 190) end
	if d <= 1 then return "Green", Color3.fromRGB(130, 230, 110) end
	if d <= 4 then return "Orange", Color3.fromRGB(255, 170, 60) end
	return "Red", Color3.fromRGB(255, 80, 80)
end
Data.MobNotice = 16 -- studs: a mob notices you this close (bosses a bit further)
Data.MobLeash = 50 -- a mob gives up and goes home this far from its spot (and heals up)
Data.MobRespawn = {Normal = 40, Boss = 150} -- seconds until a defeated mob comes back
Data.MobEgg = {Meadow = "Mystery", Forest = "Mystery", Peaks = "Crystal", Caves = "Crystal", Volcano = "Lava"} -- bosses: Star egg sometimes
-- 👑 Boss special attacks (ServerScriptService.BossSkills runs them, StarterPlayerScripts.BossFx draws them).
-- Every special shows a warning first (red circles / red lanes on the ground, a big name over the boss),
-- so kids can always see it coming and walk out of the way.
--   Rain   = things fall from the sky on red circles (one right where each player stands, more around)
--   Slam   = the boss jumps and lands: a big red circle around it. Stun = you get dizzy / frozen / sticky for a moment
--   Volley = the boss throws glowing balls. Red lanes show where they fly (Fan = all at once in a fan)
--   Line   = a red lane in front of the boss: Charge (it runs through) or Breath (a long blast)
-- Warn = seconds of warning, R = circle radius (studs), N = how many, Hurt = x the boss's ATT (default 1).
Data.BossSkill = {First = 3, Gap = {6, 9}, StunSecs = 1.2, HitGap = 0.7, Range = 70}
Data.BossSkills = {
	QueenBuzzbloom = {
		{Type = "Rain", Name = "Pollen Rain", Icon = "🌼", N = 3, R = 6, Warn = 2.0, Look = "Pollen"},
		{Type = "Volley", Name = "Honey Shots", Icon = "🍯", N = 3, Speed = 24, R = 2, Aim = 0.9, Gap = 0.6, Look = "Honey", Stun = "Honey"},
		{Type = "Slam", Name = "Buzz Burst", Icon = "💥", R = 10, Warn = 1.8, Look = "Pollen"},
	},
	BrambleBear = {
		{Type = "Rain", Name = "Acorn Drop", Icon = "🌰", N = 4, R = 6, Warn = 1.9, Look = "Acorn"},
		{Type = "Volley", Name = "Thorn Fan", Icon = "🌿", N = 5, Fan = 60, Speed = 28, R = 1.8, Aim = 1.0, Look = "Thorn"},
		{Type = "Slam", Name = "Big Stomp", Icon = "💫", R = 12, Warn = 1.6, Look = "Dirt", Stun = "Dizzy"},
		{Type = "Line", Mode = "Charge", Name = "Bear Charge", Icon = "🐻", L = 30, W = 8, Warn = 1.4, Look = "Dirt"},
	},
	IceWyrm = {
		{Type = "Rain", Name = "Icicle Rain", Icon = "🧊", N = 5, R = 5.5, Warn = 1.8, Look = "Ice"},
		{Type = "Line", Mode = "Breath", Name = "Frost Breath", Icon = "❄️", L = 26, W = 9, Warn = 1.4, Hold = 1.2, Look = "Ice", Stun = "Ice"},
		{Type = "Volley", Name = "Snowballs", Icon = "⛄", N = 4, Speed = 30, R = 2, Aim = 0.8, Gap = 0.5, Look = "Snow"},
	},
	GemGolem = {
		{Type = "Rain", Name = "Crystal Rain", Icon = "💎", N = 6, R = 5.5, Warn = 1.8, Look = "Gem"},
		{Type = "Volley", Name = "Gem Shards", Icon = "🔮", N = 7, Fan = 80, Speed = 28, R = 1.8, Aim = 1.0, Look = "Gem"},
		{Type = "Slam", Name = "Quake Slam", Icon = "💫", R = 14, Warn = 1.6, Look = "Gem", Stun = "Dizzy"},
	},
	LavaTitan = {
		{Type = "Rain", Name = "Meteor Shower", Icon = "☄️", N = 7, R = 6, Warn = 1.7, Look = "Lava"},
		{Type = "Volley", Name = "Fireballs", Icon = "🔥", N = 5, Speed = 32, R = 2, Aim = 0.8, Gap = 0.45, Look = "Lava"},
		{Type = "Line", Mode = "Breath", Name = "Fire Breath", Icon = "🔥", L = 28, W = 9, Warn = 1.4, Hold = 1.2, Look = "Lava"},
		{Type = "Slam", Name = "Eruption Slam", Icon = "💫", R = 15, Warn = 1.6, Look = "Lava", Stun = "Dizzy"},
	},
}

-- weapons: Style Magic = sparkly bolts from afar, Melee = bonk up close (stronger), Range = pebbles/arrows from furthest. Cd = seconds between attacks.
Data.WeaponRarities = {
	{Name = "Common", Color = Color3.fromRGB(240, 240, 240)},
	{Name = "Uncommon", Color = Color3.fromRGB(110, 205, 95)},
	{Name = "Rare", Color = Color3.fromRGB(90, 170, 255)},
	{Name = "Epic", Color = Color3.fromRGB(205, 120, 255)},
	{Name = "Legendary", Color = Color3.fromRGB(255, 200, 60)},
	{Name = "Mythic", Color = Color3.fromRGB(255, 80, 80)},
}
Data.WeaponRarityByName = {}
for i, r in Data.WeaponRarities do r.Order = i Data.WeaponRarityByName[r.Name] = r end
Data.Weapons = {
	{Name = "TwigWand", Display = "Twig Wand", Icon = "🪄", Rarity = "Common", Style = "Magic", Dmg = 10, Cd = 0.6, Range = 34, Fx = Color3.fromRGB(255, 235, 120)},
	{Name = "CarrotSword", Display = "Carrot Sword", Icon = "🥕", Rarity = "Common", Style = "Melee", Dmg = 15, Cd = 0.5, Range = 9, Fx = Color3.fromRGB(255, 160, 70)},
	{Name = "BubbleWand", Display = "Bubble Wand", Icon = "🫧", Rarity = "Common", Style = "Magic", Dmg = 12, Cd = 0.55, Range = 34, Fx = Color3.fromRGB(160, 220, 255)},
	{Name = "CandyHammer", Display = "Candy Hammer", Icon = "🍬", Rarity = "Rare", Style = "Melee", Dmg = 32, Cd = 0.7, Range = 10, Fx = Color3.fromRGB(255, 130, 190)},
	{Name = "StarWand", Display = "Star Wand", Icon = "⭐", Rarity = "Rare", Style = "Magic", Dmg = 24, Cd = 0.55, Range = 38, Fx = Color3.fromRGB(255, 225, 80)},
	{Name = "FishySword", Display = "Fishy Sword", Icon = "🐟", Rarity = "Rare", Style = "Melee", Dmg = 27, Cd = 0.5, Range = 9, Fx = Color3.fromRGB(110, 200, 255)},
	{Name = "CrystalStaff", Display = "Crystal Staff", Icon = "💎", Rarity = "Epic", Style = "Magic", Dmg = 55, Cd = 0.55, Range = 40, Fx = Color3.fromRGB(190, 130, 255)},
	{Name = "CupcakeMallet", Display = "Cupcake Mallet", Icon = "🧁", Rarity = "Epic", Style = "Melee", Dmg = 72, Cd = 0.75, Range = 10, Fx = Color3.fromRGB(255, 170, 210)},
	{Name = "RainbowUmbrella", Display = "Rainbow Umbrella", Icon = "☂️", Rarity = "Epic", Style = "Melee", Dmg = 62, Cd = 0.5, Range = 10, Fx = Color3.fromRGB(255, 200, 120)},
	{Name = "SunStaff", Display = "Sun Staff", Icon = "☀️", Rarity = "Legendary", Style = "Magic", Dmg = 120, Cd = 0.5, Range = 44, Fx = Color3.fromRGB(255, 200, 60)},
	{Name = "LollipopBlade", Display = "Lollipop Blade", Icon = "🍭", Rarity = "Legendary", Style = "Melee", Dmg = 145, Cd = 0.5, Range = 11, Fx = Color3.fromRGB(255, 120, 170)},
	{Name = "MoonWand", Display = "Moon Wand", Icon = "🌙", Rarity = "Mythic", Style = "Magic", Dmg = 260, Cd = 0.45, Range = 46, Fx = Color3.fromRGB(200, 190, 255)},
	{Name = "UnicornBlade", Display = "Unicorn Blade", Icon = "🦄", Rarity = "Mythic", Style = "Melee", Dmg = 300, Cd = 0.45, Range = 11, Fx = Color3.fromRGB(255, 160, 230)},
	-- 🏹 Range: pebbles, peas and arrows that fly further than magic (weaker than melee up close)
	{Name = "PebbleSling", Display = "Pebble Slingshot", Icon = "🎯", Rarity = "Common", Style = "Range", Dmg = 11, Cd = 0.55, Range = 42, Fx = Color3.fromRGB(200, 170, 130)},
	{Name = "PeaShooter", Display = "Pea Shooter", Icon = "🌱", Rarity = "Rare", Style = "Range", Dmg = 25, Cd = 0.5, Range = 44, Fx = Color3.fromRGB(130, 220, 90)},
	{Name = "ToyBow", Display = "Toy Bow", Icon = "🏹", Rarity = "Epic", Style = "Range", Dmg = 58, Cd = 0.55, Range = 46, Fx = Color3.fromRGB(255, 150, 190)},
	{Name = "SunBow", Display = "Sun Bow", Icon = "🌅", Rarity = "Legendary", Style = "Range", Dmg = 128, Cd = 0.5, Range = 48, Fx = Color3.fromRGB(255, 200, 70)},
	{Name = "RainbowBow", Display = "Rainbow Bow", Icon = "🌈", Rarity = "Mythic", Style = "Range", Dmg = 275, Cd = 0.45, Range = 50, Fx = Color3.fromRGB(150, 210, 255)},
}
Data.WeaponByName = {}
for _, w in Data.Weapons do Data.WeaponByName[w.Name] = w end
Data.StarterWeapon = "TwigWand" -- free for everyone
Data.WeaponMaxStars = 5 -- a copy you already have adds a ⭐ (+10% power each)
Data.WeaponStarBonus = 0.1
Data.WeaponShinyChance = 0.05 -- ✨ shiny: sparkles and +50% power
Data.WeaponShinyMult = 1.5
Data.WeaponMaxedCoins = {Common = 20, Rare = 60, Epic = 200, Legendary = 600, Mythic = 2000}
Data.CritChance, Data.CritMult = 0.12, 2
-- 🐾 buddy pet in the wild lands: Passive = only helps when you're attacked or you attack; Aggressive = attacks any mob near you
Data.BuddyModes = {"Passive", "Aggressive"}
Data.BuddyAggroRadius = 22
-- ⭐ loot stars: items from defeated mobs drop as glowing stars; you only see what it is when you pick it up.
-- Your buddy pet grabs one star every Secs[level] seconds (level = prof.PetCollectLv, to upgrade later).
Data.StarLife = 120 -- seconds before an untouched star fades away
Data.StarPickup = 5 -- walk this close to grab it
Data.PetCollect = {Radius = 35, Secs = {4, 3, 2.2, 1.5, 1}}
-- 🌳 Skill tree (ServerScriptService.Skills keeps it, StarterPlayerScripts.SkillTree shows it, key K).
-- You get 1 skill point for every ⚔️ Hero Level (max Data.HeroMax = 50, so 50 points in all).
-- A skill needs your Hero Level >= Lv and the skill above it (Req) learned. Each point either learns a new skill or
-- levels one up (to Max). One branch maxed = 28 points, so builds differ. Free reset anytime.
-- Damage skills power up the weapon style of their branch (Melee / Range / Magic). The Q and R moves use the active
-- skill of the branch that matches the weapon in your hand. Row / Col = where the card sits in the tree (Col 1.5 = middle).
Data.SkillBranches = {
	{Name = "Melee", Icon = "🗡️", Style = "Melee", Color = Color3.fromRGB(240, 140, 110),
		Order = {"BigBonk", "ToughHide", "SpinSwing", "ShieldUp", "GroundPound", "GiantMode"}},
	{Name = "Range", Icon = "🏹", Style = "Range", Color = Color3.fromRGB(90, 200, 160),
		Order = {"SharpShot", "QuickFeet", "DoubleShot", "EagleEye", "ArrowRain", "RapidFire"}},
	{Name = "Mage", Icon = "🔮", Style = "Magic", Color = Color3.fromRGB(165, 145, 240),
		Order = {"SparkPower", "LongReach", "BouncyBolt", "HealingSparkle", "MiniMeteor", "FreezeRing"}},
}
local function pct(x) return math.floor(x * 100 + 0.5) end
Data.Skills = {
	-- 🗡️ Melee
	BigBonk = {Branch = "Melee", Name = "Big Bonk", Icon = "🔨", Lv = 1, Max = 5, Row = 1, Col = 1.5, Kind = "Dmg", Per = 0.08,
		Say = function(r) return ("+%d%% melee damage"):format(pct(0.08 * r)) end},
	ToughHide = {Branch = "Melee", Name = "Tough Hide", Icon = "🛡️", Lv = 5, Max = 5, Req = "BigBonk", Row = 2, Col = 1, Kind = "HP", Per = 0.06,
		Say = function(r) return ("+%d%% max HP"):format(pct(0.06 * r)) end},
	SpinSwing = {Branch = "Melee", Name = "Spin Swing", Icon = "🌀", Lv = 10, Max = 5, Req = "BigBonk", Row = 2, Col = 2, Kind = "Spin", Per = 0.2,
		Say = function(r) return ("Every 3rd swing hits all around you, %d%% damage"):format(100 + pct(0.2 * r)) end},
	ShieldUp = {Branch = "Melee", Name = "Shield Up", Icon = "🧱", Lv = 18, Max = 5, Req = "ToughHide", Row = 3, Col = 1, Kind = "Guard", Per = 0.04,
		Say = function(r) return ("-%d%% damage taken"):format(pct(0.04 * r)) end},
	GroundPound = {Branch = "Melee", Name = "Ground Pound", Icon = "💥", Lv = 25, Max = 5, Req = "SpinSwing", Row = 3, Col = 2, Kind = "Active", Cd = 12, R = 12,
		Dmg = function(r) return 1.5 + 0.3 * r end, Stun = function(r) return 0.8 + 0.2 * r end,
		Say = function(r) return ("Stomp! Circle around you, %d%% damage, %.1fs dizzy"):format(pct(1.5 + 0.3 * r), 0.8 + 0.2 * r) end},
	GiantMode = {Branch = "Melee", Name = "Giant Mode", Icon = "🦖", Lv = 40, Max = 3, Req = "GroundPound", Row = 4, Col = 1.5, Kind = "Active", Big = true, Cd = 40,
		Secs = function(r) return 4 + 2 * r end, Boost = function(r) return 0.2 * r end,
		Say = function(r) return ("Grow big for %ds, +%d%% damage"):format(4 + 2 * r, pct(0.2 * r)) end},
	-- 🏹 Range
	SharpShot = {Branch = "Range", Name = "Sharp Shot", Icon = "🎯", Lv = 1, Max = 5, Row = 1, Col = 1.5, Kind = "Dmg", Per = 0.08,
		Say = function(r) return ("+%d%% range damage"):format(pct(0.08 * r)) end},
	QuickFeet = {Branch = "Range", Name = "Quick Feet", Icon = "👟", Lv = 5, Max = 5, Req = "SharpShot", Row = 2, Col = 1, Kind = "Speed", Per = 0.04,
		Say = function(r) return ("+%d%% walk speed in the lands"):format(pct(0.04 * r)) end},
	DoubleShot = {Branch = "Range", Name = "Double Shot", Icon = "➰", Lv = 10, Max = 5, Req = "SharpShot", Row = 2, Col = 2, Kind = "Double", Per = 0.1,
		Say = function(r) return ("%d%% chance to hit a 2nd mob too"):format(pct(0.1 * r)) end},
	EagleEye = {Branch = "Range", Name = "Eagle Eye", Icon = "🦅", Lv = 18, Max = 5, Req = "QuickFeet", Row = 3, Col = 1, Kind = "Crit", Per = 0.03,
		Say = function(r) return ("+%d%% crit chance"):format(pct(0.03 * r)) end},
	ArrowRain = {Branch = "Range", Name = "Arrow Rain", Icon = "🌧️", Lv = 25, Max = 5, Req = "DoubleShot", Row = 3, Col = 2, Kind = "Active", Cd = 12, R = 10,
		Dmg = function(r) return 1.2 + 0.3 * r end,
		Say = function(r) return ("Arrows rain on a circle, %d%% damage"):format(pct(1.2 + 0.3 * r)) end},
	RapidFire = {Branch = "Range", Name = "Rapid Fire", Icon = "⚡", Lv = 40, Max = 3, Req = "ArrowRain", Row = 4, Col = 1.5, Kind = "Active", Big = true, Cd = 40,
		Secs = function() return 6 end, Speed = function(r) return 2 + r end,
		Say = function(r) return ("Attack %dx faster for 6s"):format(2 + r) end},
	-- 🔮 Mage
	SparkPower = {Branch = "Mage", Name = "Spark Power", Icon = "✨", Lv = 1, Max = 5, Row = 1, Col = 1.5, Kind = "Dmg", Per = 0.08,
		Say = function(r) return ("+%d%% magic damage"):format(pct(0.08 * r)) end},
	LongReach = {Branch = "Mage", Name = "Long Reach", Icon = "📏", Lv = 5, Max = 5, Req = "SparkPower", Row = 2, Col = 1, Kind = "Reach", Per = 0.06,
		Say = function(r) return ("+%d%% magic range"):format(pct(0.06 * r)) end},
	BouncyBolt = {Branch = "Mage", Name = "Bouncy Bolt", Icon = "🔀", Lv = 10, Max = 5, Req = "SparkPower", Row = 2, Col = 2, Kind = "Bounce",
		Hops = function(r) return math.ceil(r / 2) end, Part = function(r) return 0.4 + 0.1 * r end,
		Say = function(r) return ("Bolts bounce to %d more mob%s, %d%% damage"):format(math.ceil(r / 2), r > 2 and "s" or "", pct(0.4 + 0.1 * r)) end},
	HealingSparkle = {Branch = "Mage", Name = "Healing Sparkle", Icon = "💖", Lv = 18, Max = 5, Req = "LongReach", Row = 3, Col = 1, Kind = "Heal", Per = 0.01,
		Say = function(r) return ("Magic hits heal you %d%% of max HP"):format(r) end},
	MiniMeteor = {Branch = "Mage", Name = "Mini Meteor", Icon = "☄️", Lv = 25, Max = 5, Req = "BouncyBolt", Row = 3, Col = 2, Kind = "Active", Cd = 14, R = 10,
		Dmg = function(r) return 2 + 0.4 * r end,
		Say = function(r) return ("A meteor lands on a circle, %d%% damage"):format(pct(2 + 0.4 * r)) end},
	FreezeRing = {Branch = "Mage", Name = "Freeze Ring", Icon = "❄️", Lv = 40, Max = 3, Req = "MiniMeteor", Row = 4, Col = 1.5, Kind = "Active", Big = true, Cd = 40, R = 16,
		Stun = function(r) return 1 + r end,
		Say = function(r) return ("Freeze mobs near you for %ds"):format(1 + r) end},
}
Data.SkillAim = 40 -- moves that land on a circle (Arrow Rain, Mini Meteor) reach this far
-- ⚡ Kind = "Active" skills go in their branch's 5-slot skill bar (keys 1-5 in the lands); only a weapon of that branch uses them. Big = a big move.
Data.SkillSlots = 5
-- a branch's skill of a kind ("Dmg", "Q", "R" ...)
function Data.SkillOf(branch, kind)
	for id, s in Data.Skills do
		if s.Branch == branch and s.Kind == kind then return id, s end
	end
end
function Data.BranchOfStyle(style)
	for _, b in Data.SkillBranches do
		if b.Style == style then return b.Name end
	end
	return "Melee"
end

-- 🎁 weapon capsules: Weights = chance of each rarity. Basic is sold in the ⚔️ Weapons menu for coins,
-- the land capsules drop from mobs, bosses and treasure chests in that land.
Data.Capsules = {
	Basic = {Name = "Basic Capsule", Icon = "🎁", Color = Color3.fromRGB(240, 200, 120), Price = 300,
		Weights = {Common = 75, Rare = 22, Epic = 2.7, Legendary = 0.3}},
	Meadow = {Name = "Meadow Capsule", Icon = "🌼", Color = Color3.fromRGB(150, 220, 110), Weights = {Common = 68, Rare = 27, Epic = 4.5, Legendary = 0.5}},
	Forest = {Name = "Forest Capsule", Icon = "🍄", Color = Color3.fromRGB(170, 100, 210), Weights = {Common = 48, Rare = 38, Epic = 12, Legendary = 2}},
	Peaks = {Name = "Peaks Capsule", Icon = "❄️", Color = Color3.fromRGB(130, 200, 255), Weights = {Common = 28, Rare = 45, Epic = 21, Legendary = 5.5, Mythic = 0.5}},
	Caves = {Name = "Caves Capsule", Icon = "💎", Color = Color3.fromRGB(150, 110, 255), Weights = {Common = 12, Rare = 40, Epic = 35, Legendary = 11, Mythic = 2}},
	Volcano = {Name = "Volcano Capsule", Icon = "🌋", Color = Color3.fromRGB(255, 110, 60), Weights = {Rare = 34, Epic = 45, Legendary = 17, Mythic = 4}},
}
Data.CapsuleOrder = {"Basic", "Meadow", "Forest", "Peaks", "Caves", "Volcano"}
-- how strong a weapon copy is: {Name, Stars, Shiny}
function Data.WeaponPower(w)
	local def = Data.WeaponByName[w.Name]
	if not def then return 0 end
	return math.floor(def.Dmg * (1 + (w.Stars or 0) * Data.WeaponStarBonus) * (w.Shiny and Data.WeaponShinyMult or 1) + 0.5)
end
-- 💥 damage range shown on a weapon (power 72 = "66-78"): every hit rolls a number in it.
-- Each ⭐ star (and ✨ shiny) raises the whole range, because it raises the power. Skills and Giant Mode hit even harder.
Data.WeaponSpread = 0.08 -- the range goes this far below and above the power
function Data.WeaponRange(w)
	local p = Data.WeaponPower(w)
	return math.max(1, math.floor(p * (1 - Data.WeaponSpread) + 0.5)), math.max(1, math.floor(p * (1 + Data.WeaponSpread) + 0.5))
end

-- player attribute that holds how many seeds of a crop you own (attribute names can't have spaces)
function Data.SeedAttr(name) return "Seed_" .. (name:gsub("[^%w]", "")) end

return Data
