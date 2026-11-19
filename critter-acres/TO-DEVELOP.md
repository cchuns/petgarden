# Critter Acres: to-develop list

Ideas to build next, roughly in priority order. Tick them off as they ship.

## Done
- [x] Farm loop: plant, water, grow, harvest, sell
- [x] Seed tiers: Puffberry, Sunberry, Moonplum, Rainbow Drop
- [x] Pet rarities (Common/Rare/Epic/Legendary) with an RNG catch chance
- [x] Pet jobs: water, harvest, plant, grow-boost
- [x] Buildings: Critter Hut, Fruit Stand (now owned per player and saved)

## Done in phase 1 (return hooks)
- [x] **Save progress** (DataStore): coins, berries, seed, pets, book, eggs, buildings, quests. Works once the game is published with Studio API access on.
- [x] **Offline progress**: pets at home earn coins while you're away (up to 8 hours)
- [x] **Critter collection book**: silhouettes until found, coin reward for each first find
- [x] **Pet levels**: pets gain XP from jobs and trips; each level makes them faster and stronger
- [x] **Pet expeditions**: 1, 4 or 8 hour trips that bring back coins, berries and maybe an egg
- [x] **Critter eggs**: Mystery Eggs hatch after 1 real hour into a random critter (better odds for rares)
- [x] **Let a pet go** to make room
- [x] **Weather events**: Rain, Shooting Star Night, Golden Sun
- [x] **Critter of the day**: one species shows up 3x more often
- [x] **Golden harvests**: 6% chance for x3 berries
- [x] **Daily quests** (3 per day) and a **login streak gift**
- [x] **"What's new" board** near spawn
- [x] **Expedition Booth** by the spawn: 5 places from easy to hard (Sunny Meadow, Mushroom Forest, Frosty Peaks, Crystal Caves, Lava Volcano) with 3D picture cards, success chance by pet rarity + level, and better eggs (Crystal, Lava) from harder places

## Done: raids and battle pets
- [x] Pet roles: Workers (farm jobs) and Battlers (7 battle species: Pebbleback, Nibblet, Zippit, Thornox, Emberclaw, Frostmaw, Stormwing); classes Tank / Striker / Speedy
- [x] Separate limits: 3 workers (+3 with Critter Hut), 6 battlers
- [x] Raid Gate by the spawn with 5 raids (Slime Swamp, Thorn Thicket, Frost Cavern, Crystal Depths, Magma Lair), teams of 3 to 6, auto battle you watch (speed x1/x2/x3, skip)
- [x] Equipment: 1 slot per battler, 5 gear types, Common to Legendary, dropped by raids
- [x] Energy: 1 per raid, 10 max, +1 per hour
- [x] 🛠 Dev menu (Studio only): coins, berries, energy, battlers, workers + buildings, gear set, +1 level, fill book, ready eggs, finish timers, fast timers, spawn by rarity, start any weather, reset save
- [x] 🛠 Dev menu v2: tabbed UIKit window; Hero Level up/set, full HP, no damage, Q/R ready, max skills, give any Melee / Range / Mage weapon

## Done: pet profiles and feeding
- [x] Seed buying removed: planting is free (plots grow Puffberries); fancier berries come from expeditions and Golden harvests
- [x] Feed berries to pets for XP (🍓1, 🍋3, 🍇8, 🌈20)
- [x] Risky expeditions that fail bring back nothing and the pet is exhausted (rests 2h, shown with 😴 and an energy bar)
- [x] Pets tab: picture grid, then a profile with level, energy, stats, gear slot and feed buttons
- [x] Raid animations: lunges, flying hits, shakes, crit flash, KOs, boss intro, confetti, loot cards
- [x] Fewer words, more icons in the HUD, booth and raid screens
- [x] Animated pet portraits in the Pets tab (bounce, turn, blink, happy hop when fed, sleepy sway) and a simpler, icon-only profile

## Requested by CK, design agreed in chat (not built yet, CK still adding ideas)
- [ ] **Test mode for CK only**: lots of coins and every berry, all critters in the book plus one of each pet, no pet limit, both buildings, trips and eggs that finish in seconds, a dev panel (spawn any critter, start any weather, reset save)
- [ ] **Expedition eggs**: every successful trip returns an egg; each place has its own egg and exclusive species; odds Common 60 / Rare 28 / Epic 10 / Legendary 1.8 / Mythic 0.2 (harder places shift them up)
- [~] **Satisfying hatching** (done 2026-11-15: wobble/crack/reel/reveal, Shiny 1/50 + Rainbow 1/250, Tiny/Huge; still to do: lucky meter, duplicate treats, book page rewards): wobble, crack, rarity-colored burst; server announcement for Legendary/Mythic; Shiny variants (1 in 100); lucky meter that guarantees Epic+; duplicates become Critter Treats (pet XP); a book page per place with completion rewards
- [~] **Seed tiers by farm level** (done 2026-11-15: farm level 1-15, Sunberry 3 / Moonplum 6 / Rainbow 10, level-up reveal; still to do: the new seed types and area unlocks): Puffberry (Lv1), Sunberry (3), Moonplum (6), Frostmelon (10), Glowgrape (15), Rainbow Drop (20), Starbloom (30), Ember Dragonberry (40); each one also unlocks an area, building or more plots; farm XP from planting, harvesting and selling; big "NEW SEED!" reveal; locked seeds show "Unlocks at Level X"
- [ ] **Fun seed unlock extras** (pick later): seed packets from expeditions, critter gifts, crossbreeding recipes, weather-only seeds, seed quest chains, traveling seed merchant, seed shards
- [ ] **Show-off endgame**: best pet follows you, auras and titles, farm visits with likes, trophy hall, glowing crop variants, leaderboards, rebirth stars, Master Collector pet, Mythic quest chains, seasonal limited pets
- [ ] **Pet battles**: stats from rarity, level and Shiny; battle types from job and home area; teams of 3, turn-based, big buttons; friendly battles, Critter Tower, ranked seasons
- [ ] **Open world**: gather wood, stone and crystals; craft tools and buildings at a bench; place them freely on your own land; areas unlocked by crafted items (bridge, warm boots, lantern, heat charm); day and night; pets help gather. Phases: A) valley + Mushroom Forest + gathering + crafting, B) a plot for each player + free decorating, C) remaining areas + day/night, D) pet helpers + battles
- [ ] **Co-op dungeons** (1 to 4 players): one per area (Mushroom Burrow, Frozen Halls, Crystal Mines, Magma Core); 5 to 10 minute runs with rooms, puzzles, chests and a boss; players and pet teams fight together; Normal/Hard/Nightmare; no losing items; revive friends
- [ ] **World bosses**: hourly server event; everyone who helps gets a reward; clearly telegraphed attacks
- [x] **Numbers instead of hearts** (CK 2026-11-17): built (PWR pass)
- [x] **Level-scaled lands + party PWR + ranged mobs** (CK 2026-11-17): built (PWR pass)
- [x] **Skill tree** (CK 2026-11-17): built: 3 branches, 50 points, Q/R moves, Range weapons
- [ ] **Boss Eggs**: exclusive pets, most Mythics come from here, co-op luck bonus, boss lucky meter, first-clear trophies and titles
- [ ] If eggs are ever sold for Robux, show the odds (Roblox rule); prefer eggs earned by playing

## Next up (phase 2)
- [ ] Own farm plot per player on a shared map (needed before trading and visiting)
- [x] Pet happiness (petting and feeding) on top of levels (2026-11-15: mood bonus, pet gifts)
- [ ] Buy more land; more buildings (Greenhouse, Pond) and decorations
- [ ] Traveling merchant: a daily rotating shop with limited seeds and decorations
- [ ] Slow-growing special crops (e.g. a Starbloom that takes a few real hours)

## Long-term goals
- [ ] New areas with their own critters and seeds (Mushroom Forest, Snowy Peak)
- [ ] Pet fusion: 3 of a kind into a shiny version
- [ ] Seasonal events: limited-time critters, seeds and decorations

## Social
- [ ] Trading pets and seeds; visit friends' farms
- [ ] Friend bonus when playing together
- [ ] Leaderboards: richest farm, most critters found
- [ ] Weekly farm contest (leaderboard that resets weekly, with a badge)
- [ ] Community goal: everyone harvests toward a shared target

## Polish
- [ ] Sounds and music, catch jingle, confetti for rare catches
- [x] Call pets to follow you around (2026-11-15: 👣 on the profile)

## Added 2026-11-15 (hooks pass)
- [x] Pet outfits (8 hats, 👒 tab)
- [x] 🎡 Daily lucky spin + 🎁 mystery presents
- [ ] 🍀 Luck meter (guaranteed Epic+ after N hatches/spins)
- [ ] Critter Catch race (rare critter runs around, first to tag it 3 times wins)
- [ ] Berry raids on friends' farms (pets chase you off)
- [ ] Egg toss (carry a big egg home, others can bump it loose)
- [ ] Present rush every 15 min with a server countdown
- [ ] Rarest-pet board in the plaza

## Added 2026-11-15 (open world pass)
- [x] Personal farms (6 per server), farm visits, ❤️ likes + ranking, help-water
- [x] Biomes with their own critters (Forest, Peaks, Caves, Volcano + Meadow)
- [x] World events: falling star, catch race, world boss, present rush
- [x] Berry mutations (Juicy/Golden/Frosty/Starry/Zapped/Prismatic) + XL/XXL/MEGA sizes, Snow + Storm weather
- [x] Fusion 3 -> Shiny -> Rainbow (🧪 cauldron)
- [x] Buddy play: rub mini game, fetch, tricks
- [x] Working slots + energy + nap hut + dream gifts (2026-11-15)
- [ ] Berry sneaking on visits (guard pets chase you)
- [ ] Trading
- [x] Seed shop with timed restocks, seed packs, seed book, fruit trees (2026-11-15)
- [x] Incubator (3 eggs at once) + limited Harvest Egg
- [ ] Dig up / replace a fruit tree
- [ ] Next seasonal egg after 2026-12-01 (change Data.Seasonal)

## Added 2026-11-15 (world + crafting pass)
- [x] Bigger biomes + resource gathering + tool levels
- [x] Workbench: tools, gear crafting, gear upgrades
- [x] Farm upgrades (bonus plots, soil) + decorating with functional sprinkler/beehive
- [x] Golden acorns, playground, toys, titles, record board, lucky hour, pet sounds
- [x] Real fruit shapes, energy bar over pets, pets on the ground, words in the UI
- [ ] Day/night with fireflies
- [ ] Crop pests to bonk
- [ ] Rideable Huge pets / dragon
- [ ] Rain totem + community tree

## Pass 7 shipped (2026-11-15, not playtested yet)
- [x] RNG gear upgrades (can fail), gear tiers, power-up screen
- [x] Buy decorations from the farm, one pet family + farm space/storage, tear-open reveals
- [x] Journey, playtime gifts, calendar, luck meter, naming, favorite food, friend luck, gifting, badges (ids needed), golden dash, mailbox, greeting, juicy coin fly, farm visitor
- [x] Moon Pot, piles, legendary shout + aura, raccoons, egg snatch, growing up, silhouettes (book already shows ❔), trading, gates, NPC quests, "1 in X", Farm Power, Best Friends Nest + secret pets, fishing, fashion show, rare fruit, riding
- [ ] Friend's pet in your nest, badge ids, new seasonal egg after 2026-12-01
- [x] ⚡ Skill bar: 5 slots, drag moves in from the tree, keys 1-5 in the lands (2026-11-17)
- [ ] 🌳 More skills for the tree (CK plans to expand it: just add Kind "Active" entries + cast effect + FX)

## 🏰 Dungeon Portal (CK, 2026-11-19): all ideas approved, built in stages (see RESUME "Dungeon Portal" / "Dungeons v3")
- [x] Stage 1+2: a new 🏰 Dungeon Portal in town, 5 dungeons (one per land), ⭐1–3 tiers, ⚡ raid energy, 1–4 players, campfires, key + boss gate, boss arena, dead-end chests
- [x] v2 (CK): stairs / ledges with one-way ✨ silver chests, obby jump pads, zones with their own look + signs + landmarks; attacks / mobs / shots blocked by walls
- [x] v3 (CK: "not square rooms, a proper map"): natural terrain. Clearings + winding trails, cliffs with bushes / trees as walls, cave ceilings on Slime Cave / Crystal Mines / Lava Keep, open sky on Root Tunnels / Ice Halls, rock-pillar ledges + rope bridges
- [ ] **Playtest v3 first** (map building is brand new and has never run)
- [x] Stage 3 built 2026-11-19 (see RESUME "Dungeon stage 3"); still to do: real shapes for the 15 🧱 scroll decorations, best ⭐ in the portal picker
- [x] ~~Stage 3:~~ ⚔️ boss gear sets (2-piece bonus + glow), 📜 furniture scrolls → dungeon-only decorations (🧱 placeholders, then shapes) + a scroll album + a guaranteed drop, 🙈 hidden chests (push-through bushes, breakable cracked rock), 🏃 runaway chest, ⭐ run score, 🎉 first-clear bonus
- [ ] Stage 4: easy puzzles (torches, colour tiles, push block), levers / secret spots, a 🐾 buddy pet that sniffs out chests, a 🗺️ minimap that fills in + a glowing trail home, cute traps (slime puddles, bounce pads, snowballs), the boss calls helpers halfway
- [x] Dev menu: jump into dungeon X ⭐N + 🔓 open all dungeons; 🏰 Dungeon Portal stop in the portal picker
- [ ] Small: check the CritterSync plugin shows after a Studio restart; build real shapes for any 🧱 placeholder decorations CK adds

## 🛡️ Hero Gear (CK, 2026-11-19): player slots built first, dungeon paused
- [x] 6 slots: head, body, legs, boots, main hand (weapon), off hand. Crafted low tiers, boss-only high tiers. Gear shows on the character; a cosmetic look overrides it.
- [ ] CK playtests: crafting, wearing, the look on the avatar, PWR/HP changes, boss drops
- [ ] 👗 Cosmetics shop (sell looks later; only 2 sample looks now, given by the dev menu)
- [x] Critter Editor tabs for Hero Gear: pieces, looks, sets with named bonus steps + set weapon, 🧭 where-from checklist (2026-11-19)
- [x] Editor: slot bonus numbers, craft costs, drop chances, dungeon numbers + scroll lists (⚙️ Gear numbers + 🏰 Dungeons tabs, 2026-11-19)
- [ ] 3D models for the 5 set weapons (Slime Sword, Root Staff, Frost Bow, Amethyst Wand, Dragon Blade)
- [x] Dungeon stage 3: each dungeon boss gets its OWN set (Slime / Root / Frost / Amethyst / Dragon)
- [ ] Maybe: off-hand variety (orbs / books for mages), a "hide helmet" toggle, 3D previews on the gear cards
