---------------------------------------------------------------- 🏰 dungeons (Dungeon Portal, ServerScriptService.Dungeons)
-- (mirror of the block in Studio's CritterData; the local CritterData.module.lua is drifted)
-- A natural terrain map, fresh every run: clearings joined by winding trails, steep cliffs with bushes / trees as walls.
-- Each land has its own dungeon (same mob levels as the land). Cave = true: a rock ceiling; else open sky.
-- ⭐ tiers: clear one to open the next (prof.DungeonTier[land] = best cleared). Every explorer pays ⚡ Energy (raid energy).
Data.Dungeon = {
	Energy = 1, -- ⚡ raid energy each explorer pays to go in (the same energy as the Raid Gate)
	Gap = 64, -- studs between clearing spots (before they get nudged around)
	ClearR = {13, 21}, -- clearing radius range (studs)
	TrailW = {6, 9}, -- trail half-width range (a trail is twice this wide)
	ArenaR = 30, -- the boss arena's radius
	Floor = 10, -- ground height of the walkable parts
	WallH = 30, -- how tall the cliffs rise above the ground
	LidH = 21, -- invisible ceiling over the whole map (nobody climbs over the cliffs); must be below CaveH
	CaveH = 24, -- cave dungeons: where the rock ceiling starts
	LedgeH = 10, -- 🪜 secret ledges / bridges height (too high to jump up to: you take the route)
	Trees = 260, -- 🌲 trees on the cliff tops (open-sky dungeons)
	Campfires = 2, -- 🔥 extra campfires along the way (plus one at the start)
	Landmarks = 4, -- 🗿 most big landmarks per dungeon (in clearings where 3+ trails meet)
	ChestCoins = {Meadow = 40, Forest = 80, Peaks = 150, Caves = 260, Volcano = 420}, -- 🧺 coins in a chest (x Tier.Loot)
	BossChestX = 5, -- the 🎁 boss chest has this many times more coins
	ChestCapsule = 0.2, -- chance a 🧺 chest also has a capsule (the boss chest always does)
	SilverX = 2.5, SilverCapsule = 0.5, -- ✨ a ledge's silver chest: coins x this, chance of a capsule
	-- 🙈 hidden chests sit in a little nook in the cliff behind a bush you can walk through or a cracked rock you break
	HiddenX = 2, HiddenCapsule = 0.4, -- coins x this, chance of a capsule
	RockHold = 1.2, -- ⛏️ seconds to hold the button to break a cracked rock
	-- 🏃 the runaway chest hops away when someone comes close, then gets tired and can be opened
	RunawayX = 3, RunawayCapsule = 0.6, RunawayHops = 3, RunawayNear = 16,
	-- 📜 furniture scrolls: the 🎁 boss chest always has one you don't have yet; hidden / silver / runaway chests sometimes
	ScrollChance = 0.15, ScrollDoneCoins = 150, -- (all found: coins instead, x the tier's Loot)
	Scrolls = {
		Meadow = {"Slime Lamp", "Bubble Chair", "Glow Shroom"},
		Forest = {"Root Arch", "Firefly Jar", "Acorn Seat"},
		Peaks = {"Ice Sculpture", "Snow Globe", "Frost Lantern"},
		Caves = {"Geode", "Mine Cart", "Gem Tree"},
		Volcano = {"Ember Brazier", "Dragon Statue", "Magma Throne"},
	},
	-- ⭐ run score (when the boss falls): ⭐ cleared, ⭐ beat the Par time (seconds, per tier), ⭐ found half the chests
	ScoreBonus = {1, 1.25, 1.5}, -- 🎁 boss chest coins x this for 1 / 2 / 3 stars
	FirstClearX = 3, -- 🎉 first time you clear a dungeon at a ⭐ tier: bonus coins = boss chest coins x this, plus a capsule
	-- Size = clearings per side, Loops = extra trails (more ways through), Mobs = chance a clearing has mobs,
	-- Depth = extra mob levels (0-2), Chests = 🧺 chests, Loot = chest coin multiplier,
	-- Zones = how many 🎨 areas, Ledges = 🪜 ledge routes, Route = clearings between the way up and the ledge,
	-- Obby = chance the way up is 🦘 jump pads (else stone steps), Pads = chance a crossing is jump pads (else a bridge)
	-- Hidden = 🙈 hidden chests, Runaway = 🏃 runaway chests, Par = ⭐ time goal in seconds
	Tiers = {
		{Size = 4, Loops = 0.12, Mobs = 0.5, Depth = 0, Chests = 3, Loot = 1, Zones = 3, Ledges = 1, Route = 1, Obby = 0.4, Pads = 0.3, Hidden = 1, Runaway = 1, Par = 420},
		{Size = 5, Loops = 0.15, Mobs = 0.6, Depth = 1, Chests = 4, Loot = 1.6, Zones = 3, Ledges = 2, Route = 2, Obby = 0.5, Pads = 0.4, Hidden = 2, Runaway = 1, Par = 600},
		{Size = 6, Loops = 0.18, Mobs = 0.7, Depth = 2, Chests = 5, Loot = 2.4, Zones = 4, Ledges = 3, Route = 2, Obby = 0.6, Pads = 0.5, Hidden = 2, Runaway = 1, Par = 840},
	},
	-- terrain: Ground / Path / Cliff / Top (cliff tops) / Ceil (cave ceiling) materials; Edge = props along the edges
	-- (bushes, rocks, crystals: names from ServerStorage.RealmProps / IslandProps), Trees = props on the cliff tops,
	-- Gate = the boss gate (the key makes it shrink away)
	Themes = {
		Meadow = {Name = "Slime Cave", Icon = "🟢", Cave = true, Accent = Color3.fromRGB(120, 235, 110), Light = Color3.fromRGB(170, 255, 140),
			Ground = Enum.Material.LeafyGrass, Path = Enum.Material.Mud, Cliff = Enum.Material.Slate, Top = Enum.Material.Slate, Ceil = Enum.Material.Slate,
			PillarMat = Enum.Material.Slate, PillarColor = Color3.fromRGB(120, 150, 125),
			Edge = {"Bush", "MossyRock", "Fern", "GiantShroom", "Bush"}, Trees = {},
			Gate = {Color = Color3.fromRGB(110, 230, 100), Mat = Enum.Material.Glass},
			Deco = {Color3.fromRGB(120, 230, 90), Color3.fromRGB(90, 200, 160), Color3.fromRGB(190, 240, 90)}},
		Forest = {Name = "Root Tunnels", Icon = "🌲", Cave = false, Accent = Color3.fromRGB(255, 200, 90), Light = Color3.fromRGB(255, 220, 140),
			Ground = Enum.Material.LeafyGrass, Path = Enum.Material.Ground, Cliff = Enum.Material.Rock, Top = Enum.Material.Grass, Ceil = Enum.Material.Rock,
			PillarMat = Enum.Material.Rock, PillarColor = Color3.fromRGB(140, 120, 100),
			Edge = {"Bush", "Fern", "MossyRock", "Bush", "FlowerBush"}, Trees = {"Pine", "Maple", "Birch", "Cypress", "Willow"},
			Gate = {Color = Color3.fromRGB(70, 140, 60), Mat = Enum.Material.Grass},
			Deco = {Color3.fromRGB(80, 160, 70), Color3.fromRGB(230, 90, 90), Color3.fromRGB(110, 75, 50)}},
		Peaks = {Name = "Ice Halls", Icon = "❄️", Cave = false, Accent = Color3.fromRGB(120, 210, 255), Light = Color3.fromRGB(190, 230, 255),
			Ground = Enum.Material.Snow, Path = Enum.Material.Glacier, Cliff = Enum.Material.Rock, Top = Enum.Material.Snow, Ceil = Enum.Material.Glacier,
			PillarMat = Enum.Material.Glacier, PillarColor = Color3.fromRGB(190, 220, 245),
			Edge = {"IceCrystal", "Rocks", "IceCrystal"}, Trees = {"SnowPine", "SnowPine", "Pine"},
			Gate = {Color = Color3.fromRGB(170, 225, 255), Mat = Enum.Material.Ice},
			Deco = {Color3.fromRGB(150, 220, 255), Color3.fromRGB(220, 240, 255), Color3.fromRGB(170, 180, 255)}},
		Caves = {Name = "Crystal Mines", Icon = "💎", Cave = true, Accent = Color3.fromRGB(200, 120, 255), Light = Color3.fromRGB(210, 160, 255),
			Ground = Enum.Material.Slate, Path = Enum.Material.Cobblestone, Cliff = Enum.Material.Basalt, Top = Enum.Material.Basalt, Ceil = Enum.Material.Basalt,
			PillarMat = Enum.Material.Basalt, PillarColor = Color3.fromRGB(95, 85, 115),
			Edge = {"CaveCrystal", "GlowShroom", "MossyRock", "Rocks"}, Trees = {},
			Gate = {Color = Color3.fromRGB(190, 110, 255), Mat = Enum.Material.Neon},
			Deco = {Color3.fromRGB(190, 110, 255), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 120, 220)}},
		Volcano = {Name = "Lava Keep", Icon = "🌋", Cave = true, Accent = Color3.fromRGB(255, 120, 40), Light = Color3.fromRGB(255, 160, 80),
			Ground = Enum.Material.Basalt, Path = Enum.Material.Slate, Cliff = Enum.Material.Rock, Top = Enum.Material.Rock, Ceil = Enum.Material.Basalt,
			PillarMat = Enum.Material.Basalt, PillarColor = Color3.fromRGB(80, 65, 70),
			Edge = {"LavaRock", "Rocks", "LavaRock"}, Trees = {},
			Gate = {Color = Color3.fromRGB(255, 110, 40), Mat = Enum.Material.Neon},
			Deco = {Color3.fromRGB(255, 110, 40), Color3.fromRGB(255, 190, 60), Color3.fromRGB(60, 45, 55)}},
	},
	-- 🎨 the areas of each dungeon: Ground material, lantern / decoration colour (Color), small decorations (Deco: Mushroom,
	-- Crystal, Blob, Flower, Rock) and the big landmark where trails meet (Mark: BigMushroom, BigCrystal, Fountain, Pool, BigTree)
	Zones = {
		Meadow = {
			{Name = "Mushroom Path", Icon = "🍄", Color = Color3.fromRGB(235, 90, 90), Ground = Enum.Material.LeafyGrass, Deco = "Mushroom", Mark = "BigMushroom"},
			{Name = "Drippy Tunnels", Icon = "💧", Color = Color3.fromRGB(90, 170, 255), Ground = Enum.Material.Mud, Deco = "Blob", Mark = "Fountain"},
			{Name = "Flower Hollow", Icon = "🌸", Color = Color3.fromRGB(255, 140, 200), Ground = Enum.Material.Grass, Deco = "Flower", Mark = "BigTree"},
			{Name = "Bubble Halls", Icon = "🫧", Color = Color3.fromRGB(120, 230, 110), Ground = Enum.Material.Sand, Deco = "Blob", Mark = "Pool"},
		},
		Forest = {
			{Name = "Mushroom Grove", Icon = "🍄", Color = Color3.fromRGB(230, 100, 80), Ground = Enum.Material.LeafyGrass, Deco = "Mushroom", Mark = "BigMushroom"},
			{Name = "Root Maze", Icon = "🌳", Color = Color3.fromRGB(110, 190, 80), Ground = Enum.Material.Mud, Deco = "Rock", Mark = "BigTree"},
			{Name = "Firefly Path", Icon = "✨", Color = Color3.fromRGB(255, 225, 90), Ground = Enum.Material.Grass, Deco = "Flower", Mark = "Fountain"},
			{Name = "Mossy Halls", Icon = "🌿", Color = Color3.fromRGB(80, 200, 150), Ground = Enum.Material.Ground, Deco = "Blob", Mark = "Pool"},
		},
		Peaks = {
			{Name = "Frost Path", Icon = "❄️", Color = Color3.fromRGB(150, 220, 255), Ground = Enum.Material.Snow, Deco = "Crystal", Mark = "BigCrystal"},
			{Name = "Snowy Hall", Icon = "⛄", Color = Color3.fromRGB(235, 245, 255), Ground = Enum.Material.Snow, Deco = "Blob", Mark = "BigTree"},
			{Name = "Icicle Way", Icon = "🧊", Color = Color3.fromRGB(120, 180, 255), Ground = Enum.Material.Glacier, Deco = "Crystal", Mark = "Pool"},
			{Name = "Aurora Hall", Icon = "🌈", Color = Color3.fromRGB(190, 140, 255), Ground = Enum.Material.Salt, Deco = "Flower", Mark = "Fountain"},
		},
		Caves = {
			{Name = "Gem Path", Icon = "💎", Color = Color3.fromRGB(90, 200, 255), Ground = Enum.Material.Slate, Deco = "Crystal", Mark = "BigCrystal"},
			{Name = "Glow Mushrooms", Icon = "🍄", Color = Color3.fromRGB(120, 255, 200), Ground = Enum.Material.Mud, Deco = "Mushroom", Mark = "BigMushroom"},
			{Name = "Echo Hall", Icon = "🔔", Color = Color3.fromRGB(255, 200, 110), Ground = Enum.Material.Rock, Deco = "Rock", Mark = "Fountain"},
			{Name = "Amethyst Way", Icon = "🟣", Color = Color3.fromRGB(190, 110, 255), Ground = Enum.Material.Basalt, Deco = "Crystal", Mark = "Pool"},
		},
		Volcano = {
			{Name = "Ember Path", Icon = "🔥", Color = Color3.fromRGB(255, 130, 50), Ground = Enum.Material.Basalt, Deco = "Crystal", Mark = "BigCrystal"},
			{Name = "Ash Hall", Icon = "🌫️", Color = Color3.fromRGB(180, 170, 175), Ground = Enum.Material.Asphalt, Deco = "Rock", Mark = "Pool"},
			{Name = "Magma Falls", Icon = "🌋", Color = Color3.fromRGB(255, 90, 40), Ground = Enum.Material.CrackedLava, Deco = "Blob", Mark = "Fountain"},
			{Name = "Gold Cave", Icon = "🟡", Color = Color3.fromRGB(255, 205, 70), Ground = Enum.Material.Sandstone, Deco = "Crystal", Mark = "BigCrystal"},
		},
	},
}
-- 📜 which dungeon (land) a decoration's scroll comes from; nil = a normal decoration
Data.ScrollLandOf = {}
for land, names in Data.Dungeon.Scrolls do
	for _, name in names do Data.ScrollLandOf[name] = land end
end
-- is this decoration still locked for someone with these scrolls ({[name] = true})?
function Data.DecorLocked(name, scrolls)
	return Data.ScrollLandOf[name] ~= nil and not (scrolls and scrolls[name])
end

