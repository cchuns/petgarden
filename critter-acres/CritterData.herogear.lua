----------------------------------------------------------------
-- 🛡️ HERO GEAR: what the PLAYER wears (not pet gear, that's Data.Gear). Server: ServerScriptService.HeroGear.
-- 7 slots. Main hand = your weapon (prof.WeaponOn, Combat). The other 6 hold Hero Gear pieces (Off hand = shields).
-- Every piece adds ⚡ power (to PWR and to every hit) plus a slot bonus (❤️ HP, 🛡️ less hurt, 👟 speed in the lands).
-- 🔨 Leaf / Stone / Iron pieces are crafted from resources (at the plaza 🔨 Workbench). 🟡 Gold / 💎 Crystal / 🔥 Magma
--   pieces ONLY drop from bosses. A copy you already have adds a ⭐ (max 5, +10% each); maxed copies give coins.
-- 👗 Looks (cosmetics) change how a slot LOOKS without changing its numbers. A look beats the gear's own look.
Data.HeroSlots = {
	{Id = "Head", Icon = "🪖", Word = "Head"},
	{Id = "Body", Icon = "👕", Word = "Body"},
	{Id = "Cape", Icon = "🦸", Word = "Cape"},
	{Id = "Legs", Icon = "👖", Word = "Legs"},
	{Id = "Boots", Icon = "👢", Word = "Boots"},
	{Id = "MainHand", Icon = "⚔️", Word = "Main hand"},
	{Id = "OffHand", Icon = "🤚", Word = "Off hand"},
}
Data.HeroSlotById = {}
for i, s in Data.HeroSlots do s.Order = i Data.HeroSlotById[s.Id] = s end
-- ⚡ power each piece adds, by rarity
Data.HeroGearPwr = {Common = 1, Uncommon = 2, Rare = 3, Epic = 7, Legendary = 15, Mythic = 32}
-- slot bonuses PER RARITY STEP (Common = 1 step .. Mythic = 6). HP = +max HP, Def = less hurt, Spd = walk speed (lands only)
Data.HeroSlotBonus = {
	Head = {HP = 0.03},
	Body = {HP = 0.05, Def = 0.01},
	Legs = {HP = 0.03},
	Boots = {HP = 0.01, Spd = 0.02},
	Cape = {HP = 0.02, Spd = 0.01},
	OffHand = {Def = 0.03},
}
Data.HeroDefCap = 0.4 -- 🛡️ never more than 40% less hurt
Data.HeroGearMaxStars = 5
Data.HeroGearStarBonus = 0.1 -- each ⭐ = +10% to everything the piece gives
Data.HeroGearMaxedCoins = {Common = 20, Uncommon = 40, Rare = 60, Epic = 200, Legendary = 600, Mythic = 2000}
-- 🔨 crafting cost per tier (x the slot's size below). Only these tiers can be crafted.
Data.HeroGearCraft = {
	Leaf = {Fiber = 6, Wood = 3},
	Stone = {Stone = 8, Wood = 4, Coins = 40},
	Iron = {Iron = 5, Stone = 5, Coins = 120},
}
Data.HeroCraftReach = 24 -- 🔨 you must stand this close to the plaza Workbench to make gear
Data.HeroSlotCostMult = {Head = 1, Body = 1.5, Legs = 1.25, Boots = 1, Cape = 1.25, OffHand = 1.25}
function Data.HeroCraftCost(def)
	local base = Data.HeroGearCraft[def.Tier]
	if not base or not def.Craft then return nil end
	local m, cost = Data.HeroSlotCostMult[def.Slot] or 1, {}
	for k, v in base do cost[k] = math.ceil(v * m) end
	return cost
end
-- 🏆 boss drops: chance a boss drops a piece, and which tiers each land's bosses drop
Data.HeroGearDrop = {
	Boss = 0.25, -- land bosses (Explorer's Portal)
	Dungeon = 1, -- dungeon bosses always drop one
	Lands = {Meadow = {"Gold"}, Forest = {"Gold"}, Peaks = {"Gold", "Crystal"}, Caves = {"Crystal"}, Volcano = {"Crystal", "Magma"}},
}
-- 🎨 looks: colors / material for the part-built pieces on your character (HeroGear.server builds them)
--   Extra = a little touch: "Leaf" (leaf on top), "Gem" (a shiny gem), "Ears" (bunny ears), "Flame" (glowy embers)
Data.HeroLooks = {
	Leaf = {Color = Color3.fromRGB(110, 195, 85), Accent = Color3.fromRGB(190, 140, 90), Material = "Grass", Extra = "Leaf"},
	Stone = {Color = Color3.fromRGB(165, 165, 175), Accent = Color3.fromRGB(120, 200, 255), Material = "Slate"},
	Iron = {Color = Color3.fromRGB(195, 200, 220), Accent = Color3.fromRGB(240, 90, 90), Material = "Metal"},
	Gold = {Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(255, 110, 160), Material = "Metal", Shine = 0.3, Extra = "Gem"},
	Crystal = {Color = Color3.fromRGB(170, 130, 255), Accent = Color3.fromRGB(140, 240, 255), Material = "Glass", Glow = true, Extra = "Gem"},
	Magma = {Color = Color3.fromRGB(95, 75, 85), Accent = Color3.fromRGB(255, 120, 40), Material = "Basalt", Glow = true, Extra = "Flame"},
	Bunny = {Color = Color3.fromRGB(255, 175, 210), Accent = Color3.fromRGB(255, 255, 255), Material = "Fabric", Extra = "Ears"},
	Candy = {Color = Color3.fromRGB(255, 130, 180), Accent = Color3.fromRGB(150, 240, 200), Material = "SmoothPlastic"},
}
-- the pieces. Tier = look + where it comes from; Craft = true: made at the gear window; Set = a boss set (bonus below)
Data.HeroGear = {
	{Name = "LeafCap", Display = "Leaf Cap", Slot = "Head", Tier = "Leaf", Rarity = "Common", Craft = true},
	{Name = "LeafVest", Display = "Leaf Vest", Slot = "Body", Tier = "Leaf", Rarity = "Common", Craft = true},
	{Name = "LeafPants", Display = "Leaf Pants", Slot = "Legs", Tier = "Leaf", Rarity = "Common", Craft = true},
	{Name = "LeafSandals", Display = "Leaf Sandals", Slot = "Boots", Tier = "Leaf", Rarity = "Common", Craft = true},
	{Name = "LeafCape", Display = "Leaf Cape", Slot = "Cape", Tier = "Leaf", Rarity = "Common", Craft = true},
	{Name = "LeafBuckler", Display = "Leaf Buckler", Slot = "OffHand", Tier = "Leaf", Rarity = "Common", Craft = true},
	{Name = "StoneHelm", Display = "Stone Helm", Slot = "Head", Tier = "Stone", Rarity = "Uncommon", Craft = true},
	{Name = "StonePlate", Display = "Stone Plate", Slot = "Body", Tier = "Stone", Rarity = "Uncommon", Craft = true},
	{Name = "StoneLeggings", Display = "Stone Leggings", Slot = "Legs", Tier = "Stone", Rarity = "Uncommon", Craft = true},
	{Name = "StoneBoots", Display = "Stone Boots", Slot = "Boots", Tier = "Stone", Rarity = "Uncommon", Craft = true},
	{Name = "StoneCape", Display = "Stone Cape", Slot = "Cape", Tier = "Stone", Rarity = "Uncommon", Craft = true},
	{Name = "StoneShield", Display = "Stone Shield", Slot = "OffHand", Tier = "Stone", Rarity = "Uncommon", Craft = true},
	{Name = "IronHelm", Display = "Iron Helm", Slot = "Head", Tier = "Iron", Rarity = "Rare", Craft = true},
	{Name = "IronArmor", Display = "Iron Armor", Slot = "Body", Tier = "Iron", Rarity = "Rare", Craft = true},
	{Name = "IronLeggings", Display = "Iron Leggings", Slot = "Legs", Tier = "Iron", Rarity = "Rare", Craft = true},
	{Name = "IronBoots", Display = "Iron Boots", Slot = "Boots", Tier = "Iron", Rarity = "Rare", Craft = true},
	{Name = "IronCape", Display = "Iron Cape", Slot = "Cape", Tier = "Iron", Rarity = "Rare", Craft = true},
	{Name = "IronShield", Display = "Iron Shield", Slot = "OffHand", Tier = "Iron", Rarity = "Rare", Craft = true},
	{Name = "GoldenHelm", Display = "Golden Helm", Slot = "Head", Tier = "Gold", Rarity = "Epic", Set = "Gold"},
	{Name = "GoldenArmor", Display = "Golden Armor", Slot = "Body", Tier = "Gold", Rarity = "Epic", Set = "Gold"},
	{Name = "GoldenLeggings", Display = "Golden Leggings", Slot = "Legs", Tier = "Gold", Rarity = "Epic", Set = "Gold"},
	{Name = "GoldenBoots", Display = "Golden Boots", Slot = "Boots", Tier = "Gold", Rarity = "Epic", Set = "Gold"},
	{Name = "GoldenCape", Display = "Golden Cape", Slot = "Cape", Tier = "Gold", Rarity = "Epic", Set = "Gold"},
	{Name = "GoldenShield", Display = "Golden Shield", Slot = "OffHand", Tier = "Gold", Rarity = "Epic", Set = "Gold"},
	{Name = "CrystalHelm", Display = "Crystal Helm", Slot = "Head", Tier = "Crystal", Rarity = "Legendary", Set = "Crystal"},
	{Name = "CrystalArmor", Display = "Crystal Armor", Slot = "Body", Tier = "Crystal", Rarity = "Legendary", Set = "Crystal"},
	{Name = "CrystalLeggings", Display = "Crystal Leggings", Slot = "Legs", Tier = "Crystal", Rarity = "Legendary", Set = "Crystal"},
	{Name = "CrystalBoots", Display = "Crystal Boots", Slot = "Boots", Tier = "Crystal", Rarity = "Legendary", Set = "Crystal"},
	{Name = "CrystalCape", Display = "Crystal Cape", Slot = "Cape", Tier = "Crystal", Rarity = "Legendary", Set = "Crystal"},
	{Name = "CrystalShield", Display = "Crystal Shield", Slot = "OffHand", Tier = "Crystal", Rarity = "Legendary", Set = "Crystal"},
	{Name = "MagmaHelm", Display = "Magma Helm", Slot = "Head", Tier = "Magma", Rarity = "Mythic", Set = "Magma"},
	{Name = "MagmaArmor", Display = "Magma Armor", Slot = "Body", Tier = "Magma", Rarity = "Mythic", Set = "Magma"},
	{Name = "MagmaLeggings", Display = "Magma Leggings", Slot = "Legs", Tier = "Magma", Rarity = "Mythic", Set = "Magma"},
	{Name = "MagmaBoots", Display = "Magma Boots", Slot = "Boots", Tier = "Magma", Rarity = "Mythic", Set = "Magma"},
	{Name = "MagmaCape", Display = "Magma Cape", Slot = "Cape", Tier = "Magma", Rarity = "Mythic", Set = "Magma"},
	{Name = "MagmaShield", Display = "Magma Shield", Slot = "OffHand", Tier = "Magma", Rarity = "Mythic", Set = "Magma"},
}
Data.HeroTierIcon = {Leaf = "🌿", Stone = "🪨", Iron = "⚙️", Gold = "🟡", Crystal = "💎", Magma = "🔥"}
Data.HeroTierOrder = {"Leaf", "Stone", "Iron", "Gold", "Crystal", "Magma"}
Data.HeroGearByName = {}
for _, g in Data.HeroGear do
	g.Icon = g.Icon or Data.HeroTierIcon[g.Tier] or "🛡️"
	g.Look = g.Look or g.Tier
	Data.HeroGearByName[g.Name] = g
end
-- 🏆 boss sets: wear 2 / 4 pieces of one set for a bonus. Pwr = +% power, HP = +% max HP. 4 pieces = a glow too.
Data.HeroSets = {
	Gold = {Display = "Golden Set", Icon = "🟡", Glow = Color3.fromRGB(255, 215, 90), [2] = {Pwr = 0.05}, [4] = {Pwr = 0.1, HP = 0.1}},
	Crystal = {Display = "Crystal Set", Icon = "💎", Glow = Color3.fromRGB(170, 140, 255), [2] = {Pwr = 0.08}, [4] = {Pwr = 0.15, HP = 0.15}},
	Magma = {Display = "Magma Set", Icon = "🔥", Glow = Color3.fromRGB(255, 130, 50), [2] = {Pwr = 0.1}, [4] = {Pwr = 0.2, HP = 0.2}},
}
-- what one piece gives: {Pwr = flat ⚡, HP = %, Def = %, Spd = %}
function Data.HeroGearStats(g)
	local def = g and Data.HeroGearByName[g.Name]
	if not def then return {Pwr = 0, HP = 0, Def = 0, Spd = 0} end
	local rr = Data.WeaponRarityByName[def.Rarity]
	local step = rr and rr.Order or 1
	local mult = 1 + (g.Stars or 0) * Data.HeroGearStarBonus
	local b = Data.HeroSlotBonus[def.Slot] or {}
	return {Pwr = math.floor((Data.HeroGearPwr[def.Rarity] or 1) * mult + 0.5), HP = (b.HP or 0) * step * mult,
		Def = (b.Def or 0) * step * mult, Spd = (b.Spd or 0) * step * mult}
end
-- short text for a card: "⚡+3 ❤️+9%"
function Data.HeroGearText(st)
	local t = {"⚡+" .. st.Pwr}
	if st.HP > 0 then table.insert(t, ("❤️+%d%%"):format(math.floor(st.HP * 100 + 0.5))) end
	if st.Def > 0 then table.insert(t, ("🛡️+%d%%"):format(math.floor(st.Def * 100 + 0.5))) end
	if st.Spd > 0 then table.insert(t, ("👟+%d%%"):format(math.floor(st.Spd * 100 + 0.5))) end
	return table.concat(t, " ")
end
-- 👗 looks (cosmetics): sold later. Look = a Data.HeroLooks key; for MainHand, Model = a WeaponModels name.
Data.HeroCosmetics = {
	{Name = "BunnyHood", Display = "Bunny Hood", Icon = "🐰", Slot = "Head", Look = "Bunny"},
	{Name = "CandyShield", Display = "Candy Shield", Icon = "🍬", Slot = "OffHand", Look = "Candy"},
}
Data.HeroCosmeticByName = {}
for _, c in Data.HeroCosmetics do Data.HeroCosmeticByName[c.Name] = c end

