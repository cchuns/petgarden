# Critter Acres: resume notes

Paste or attach this file in a new chat to pick up where we left off.

## What the game is
A cozy, kid-friendly Roblox farming + critter-collecting game (original, not a copy of an existing game). Players farm berries, befriend critters, send them on expeditions, fight raids, and collect gear.

**Design rules from CK:**
- Kids audience: big, colorful and easy to tell apart.
- UI should have **no sentences**: icons, pictures, numbers, bars and color coding instead of words.
- Prefer 3D pictures (ViewportFrames) and animations over text.

## Where things are
- **Studio place:** a separate place (not the TestConnector/obby place). Its studio_id changes whenever Studio reopens, so call `list_roblox_studios` first. CK saves it themself (File > Save to Roblox); remind them after big changes. Saving data (DataStore) only works after publishing and turning on Game Settings > Security > "Studio Access to API Services".
- **Studio is the source of truth.** The `.lua` files in this folder are mirrors. Known drift:
  - Studio's CritterData differs a little from the local file, so patch it with find/replace and never paste the whole file over it.
  - The local CritterHUD.client.lua and PackOpen.module.lua are older than Studio's copies.
- **Script map** (file name suffix → where it goes):
  - `*.module.lua` → ReplicatedStorage. Exceptions: CritterAPI, RigTools and MobRigBuild go in ServerScriptService or ServerStorage.
  - `*.server.lua` → ServerScriptService.
  - `*.client.lua` → StarterPlayerScripts (LocalScripts).
  - The one-time world builders (`Build*.lua`, `Dress*.lua`, `Builder.lua`, `FountainFX.lua`) were deleted on 2026-11-17; get them back from git commit ec1e4e2 if a rebuild is ever needed. (`Builds.module.lua` is a game module and stays.)
- **Key modules:**
  - CritterData: all tuning numbers.
  - UIKit: the shared GUI look; every window uses it.
  - CritterUI: 3D portraits.
  - PackOpen: tap-to-open reveals.
  - Builds: crop and decoration shapes.
  - CritterAPI: the shared server table (`API.*`), so new server systems live in their own scripts. FarmServer is about 100k characters; don't grow it.
- **Server scripts:** FarmServer, ShopServer, CraftServer, FunServer, PetLife, Hooks, Adventure, WorldEvents, Realms (the terrain-portal lands), Combat, Portals, BoutiqueServer.
- **Client scripts:** CritterHUD (old screens), DevMenu (Studio-only 🛠 test tools), CritterMenus (the main minimal UI), CritterPlay, CritterWorld, CritterHooks, CritterSocial, CritterAnimator (pets), MobAnimator (land mobs), Combat, TerrainPortal, MouseLook, ExpeditionBooth, RaidGate.
- **Remotes:**
  - CritterAction: RemoteFunction for `ACTIONS.X(player, prof, ...)`; returns an error string, or nil when OK.
  - CritterState, CritterNotify, CritterReveal.
  - Combat.
  - CritterUIBridge: a BindableEvent between client scripts.
- **Models (Studio only):**
  - ReplicatedStorage: PetModels (part rigs), EnemyModels (raids), GearModels, WeaponModels, LootStar.
  - ServerStorage: MobModels.<Land>, RealmProps.
  - Backups in ServerStorage: OldPetModels, OldTerrains, SharedPlotsBackup, HeadWhole.
- `TO-DEVELOP.md`: CK's ideas list. `UI-PLAN.md`: the UI layout plan (mostly built as CritterMenus).

## Rules from CK (always follow)
- **No self-testing:** don't playtest, take screenshots or run checks in Studio. Push the change (a compile check is fine), then give CK a short "what to check" list. Ask before stopping CK's playtest. generate_mesh and script edits need Edit mode.
- **Audience:** kids aged 6 and up.
  - Big, colorful and easy to tell apart.
  - Icons always come with short words.
  - Nothing scary.
- **No paid RNG:** RNG paid with in-game coins is fine.
- **Original work:** don't recreate existing games.
- **GUIs** all use UIKit (cream rounded windows, white cards, colored buttons, tooltips).
- **In-world signs** are TownChips chips: an invisible Part with the attributes Icon and Label. No billboards or boards.
- **Models:**
  - Fully 3D: depth should be at least about 70% of width.
  - Movable parts, animation and facial animation (eyes that blink and look around, a mouth).
  - Generated with explicit segmentation, at most 2 generate_mesh jobs at a time.
- **Emoji:** use 💰 for coins; the 🪙 emoji doesn't render.
- **Hotkeys in use** (check before adding one):
  - B Bag, P Pets, M World: CritterMenus.
  - G Weapons: Combat.client.
  - V Buddy mode: Combat.client.
  - Ctrl Mouse look: MouseLook.
  - Decorate mode: 1-9, R, E, X/Delete, G, Q, B.

## Syncing scripts into Studio (what works)
- **Small change:** in execute_luau, read `.Source`, do a plain find/replace (`string.find(src, old, 1, true)` + sub), and write it back.
- **Full paste:** `s.Source = [==[ ... ]==]`. Write a Python helper with the Write tool and run it with `PYTHONIOENCODING=utf-8 py`, because Bash heredocs mangle backslashes.
- **Always verify:**
  - Byte length + checksum (sum of bytes mod 1000003), computed in both Python and Luau.
  - `local f, err = loadstring(src)` and require `f ~= nil`. A plain `pcall(loadstring)` is not a real check.
- **Alternative:** `serve-for-studio.ps1` (see below).

## Fast way to push script changes into Studio
1. Run `serve-for-studio.ps1` in the background (serves this folder on http://localhost:34872).
2. In Studio (Edit mode) run Luau, e.g.
   `game.ServerScriptService.FarmServer.Source = game:GetService("HttpService"):GetAsync("http://localhost:34872/FarmServer.server.lua")`
3. Stop the server afterwards. Edit mode is needed, so stop any playtest first.

## Systems built so far
- **Farm:** 12 plots; planting is free and grows Puffberries. Water speeds growth, 6% Golden harvest (x3). Sell at the Market Stall.
- **Berries:** Puffberry 🍓, Sunberry 🍋, Moonplum 🍇, Rainbow Drop 🌈. They're fed to pets for XP (+1/3/8/20) and offered when befriending.
- **Critters:** 15 species. Workers (farm jobs: water, harvest, plant, grow-boost) and Battlers (Tank/Striker/Speedy). Rarities Common/Rare/Epic/Legendary. Befriending has an RNG catch chance (better berry = better odds). Caps: 3 workers (+3 with Critter Hut), 6 battlers.
- **Pets:** levels from XP (max 10), let go, rest/exhaustion after failed risky trips (2h).
- **Expedition Booth:** 5 places (Sunny Meadow → Lava Volcano). Success chance comes from pet power. Risky fails bring back nothing and exhaust the pet. Eggs found: Mystery, Crystal, Lava.
- **Eggs:** hatch after 1h into a random critter, with odds set by egg type.
- **Raid Gate:** 5 raids (Slime Swamp → Magma Lair) with teams of 3–6 battlers. The server simulates the battle and the client plays it back with animations. Costs 1 energy (10 max, +1/hour) and drops gear (5 types, Common–Legendary, 1 slot per battler).
- **Saving:** DataStore profile (coins, berries, pets, gear, eggs, book, quests, energy). Also: offline earnings, daily quests, login streak, Critter Book with first-find rewards, weather events (Rain, Star Night, Golden Sun), critter of the day.
- **Buildings:** Critter Hut, Fruit Stand, owned per player.
- **UI:** HUD counters, Book/Pets/Quests menus, full-screen pet profile (big animated pet, ◀ ▶, tabs 📊 🎒 🍓), Dev menu (Studio only: coins, berries, pets, gear, eggs, fast timers, spawn, weather, reset).

## Generated models (only in the Studio place)
- ReplicatedStorage.PetModels: 14 of 15 species (Bloomby failed 3 times with "failed to fetch image"; it uses the old look)
- ReplicatedStorage.EnemyModels: 5 bosses (Goo King, Bramble Bear, Ice Wyrm, Gem Golem, Lava Titan) + 5 minions (Slime, Thorn Imp, Ice Bat, Gem Mite, Fire Imp)
- ReplicatedStorage.GearModels: Leaf Helmet, Thorn Claws, Feather Boots, Shell Shield, Ember Charm
- CritterUI: Template/ModelView/Portrait (3D views), Animate(vf, "idle"|"show"|"spin") with battle poses via attributes Pose = attack|hit|ko, Glow(frame, rarity) for shine + sparkles

## Done on 2026-11-15 (late)
- Raid screen uses boss/minion models; battle portraits lunge, recoil and tip over; loot shows spinning gear models with rarity glow
- Pet profile Gear tab shows gear models with glow
- Expedition booth redesign (no words): big orbiting place picture + round thumbnails on the left; drop tiles with rates, sort (💪 ⭐ 💎) and filter (🐾 🧺 ⚔️) icons, pet grid with odds, away strip, picture-only result popup on the right
- Quests: streak strip, expanding drawers (icon + progress; open for 💰 reward and 🎁 claim), critter of the day picture
- Server: trip results and raid loot are now tables (for picture UIs)

## Animated (rigged) critters — 2026-11-15
- New species: **Purrkin** (Rare cat worker, Harvest) and **Viridrake** (Legendary dragon battler, Striker, `Flyer = true`).
- Their templates in ReplicatedStorage.PetModels have separate limb MeshParts (Rig attribute "Cat"/"Dragon", each limb has a `JointFrac` attribute = hinge point as a fraction of its size).
- The server keeps only the Body (tag `RiggedCritter`); `CritterAnimator.client.lua` → StarterPlayerScripts.CritterAnimator shows the full model locally and animates it:
  - Cat: breathing, tail swish, walking paws, purr (kneads, 💗🎵, more often when you're close), paw licking, stretch, look around
  - Dragon: wing flaps, banks and pitches in flight, tucks its legs, roars and breathes fire (`FIRE_COLORS` at the top), flies laps around the map, lands for 15–35 s, takes off again. Wild ones can only be befriended while landed.
- segment_mesh outputs its pieces turned 180° from the source part: flip them back with `CFrame.Angles(0, math.pi, 0)` when putting them in place.
- Viridrake face: its Head was split (segment_mesh) into Head (skull) + Jaw (`Limb = "Jaw"`, riding on the head). The original whole head is backed up in ServerStorage.HeadWhole. The animator also supports optional EyeL/EyeR parts (blinks by squashing them), but none exist yet: the eye segmentation failed.
- One-piece pets (all other generated models) get the tag `BlobCritter` and are animated by the same script with whole-body squash and stretch. Each pet's style (hop / waddle / float / wobble) is set in `BLOB_STYLE` at the top of CritterAnimator. They also have idle tricks, look at you, do a hop-spin when a job is done (model attribute `Work` counter) and take naps (model attribute `Napping`, set in refreshTag). The cat has a nap pose too.
- Flight tuning: `CONFIG.FlyClimb/FlySpeedMult/FlyHeight/FlyHops/LandStay` in FarmServer.
- New rigged pets: generate a mesh with `segmentation = explicit` and named parts, then flatten it into a Model with the same attributes.
- Dev menu: pet picker grid (🌿 spawns that species wild next to you, 🏠 adds it as your pet).
- Fresh generations: some part textures fail at first ("No asset content representation") and show grey for a few minutes, until Roblox finishes processing them. Wait and recheck (or restart the playtest) before regenerating. Both models now load fully.

## Hooks pass — 2026-11-15 (tuning all in CritterData)
- **Shiny / Rainbow variants** (`Data.Variants`, 1/50 and 1/250; x3 on Star Night, better from eggs via `Data.EggLuck`) and **Tiny / Huge sizes** (`Data.Sizes`). Saved on the pet (`rec.Variant`, `rec.SizeName`). Shiny pets work faster and fight better (Mult). World: glitter on the server body, and the client animator adds a glowing Highlight. Portraits shimmer through `vf:SetAttribute("Variant")`. Book marks ✨ species (`prof.FoundShiny`).
- **Happiness**: `rec.Happy` + `HappyAt`, drops over time. Pet (world prompt or tap the big portrait) +12, feed +5 x tier. Happy (≥80) = faster jobs and +10% battle stats, sad (<25) = slower. Shows as model attribute `Mood` (💖 / 😢 bubbles, droopy pose). An 8% chance a petted pet finds a gift (`Data.PetGifts`). Model attribute `PetAt` makes the client play hearts and a happy move.
- **Farm level**: `prof.FarmXp`, `Data.FarmLevelXp`. Player attributes FarmLevel/FarmXp/FarmXpNext drive the HUD bar. Seeds unlock at levels 3/6/10 (`Crop.Unlock`) and cost `Crop.Seed` coins; the HUD seed picker sets player attribute `Seed`. Each level up gives coins and a spin, plus a level-up show.
- **Follow-me pet**: `prof.FollowId`, with the 👣 button on the profile. `followStep` in FarmServer handles walkers; the dragon flies to catch up.
- **Egg hatch show**: Hatch returns a table, and the HUD plays wobble → 💥 → critter reel → reveal with badges.
- **Outfits**: 8 hats built from parts in `CritterUI.BuildOutfit` (`Data.Outfits`). They're unlocked once and any pet can wear them (`rec.Outfit`, model attribute `Outfit`). Use the 👒 profile tab. Duplicates turn into coins.
- **More RNG**: 🎡 lucky spin (1 free per day + 1 per farm level, `Data.SpinPrizes`, reel show) and 🎁 mystery presents around the map (`Data.PresentPrizes`, first to open wins). New quests: Pet and Present.
- New remote: ReplicatedStorage.CritterReveal (server → client prize and level-up popups).
- Dev menu: shiny spawn, +5 spins, all outfits, farm +1 level, present here, make pets sad.

## Open world pass — 2026-11-15
- **World layout** (built by `BuildWorld.lua`, run step by step in Edit mode):
  - The old fenced farm is now the Town Plaza: sell stand, booth, raid gate, ❤️ LikeBoard, 🧪 Cauldron. Its fence is opened west, east and south.
  - The old shared plots were moved to ServerStorage.SharedPlotsBackup.
  - Six personal farms (CritterAcres.Farms.Farm1–6) ring the plaza. Each has 9 plots, an OwnerSign, a LikeHeart, a SellBin, a Home spawn marker and a fence with a gate.
  - Biomes: Meadow (old), plus Biome_Forest (west), Biome_Peaks (east), Biome_Caves and Biome_Volcano (north), joined by Paths. Each biome keeps a clearing in the middle for the world boss.
- **Personal farms**: assigned on join and freed on leave (6 players max per server, so set Max Players to 6). Plots are saved in `prof.Plots` and keep growing offline (up to 24h). Pets only work on their owner's farm.
  - Visitors can water a friend's crops (+2 coins). Each farm can be liked once a day (`prof.Likes`, liker +5 coins).
  - The likes ranking shows on the plaza board and in the 🗺️ menu.
- **Mutations and sizes** (`Data.Mutations`, `Data.CropSizes`):
  - Weather mutates growing berries: Rain → Juicy x2, Golden Sun → Golden x3, new Snow weather → Frosty x4, Star Night → Starry x5, new Storm weather → Zapped x8. Prismatic x20 can roll when a berry ripens.
  - Pets with `Mutate` (Splashy, Drizzle, Bloomby, Glimmer, Prism) add a roll each time they work a plot.
  - Sizes XL / XXL / MEGA. Special berries go to `prof.Special` and are sold for their value. Big ones get a jackpot popup and a server announcement.
- **Biomes**: `Data.Biomes` lists each biome's critters and limit. Wild critters spawn per biome, and the Book shows where each one lives.
- **Fusion**: 3 of the same species and variant → the next variant (normal → Shiny → Rainbow). Open it from the 🧪 button or the Cauldron. ACTIONS.Fuse.
- **Pet play** (for the pet that follows you): the buddy bar has 🤚 rub mini game (drag to fill hearts, tap ✨), 🎾 fetch (combo, a gift every 5) and tricks unlocked by level (`Data.Tricks`). Tricks play through model attributes `Trick` / `TrickAt`.
- **World events** (`WorldEvents.server.lua`, `Data.Events`, every 150–230 s with a 15 s countdown): 🌠 Falling Star, 🏃 Catch Race (shiny, tag 3 times), 👹 World Boss (tap to hit, pets rally, stomp/meteor knockbacks), 🎁 Present Rush.
  - FarmServer shares its functions through ServerScriptService.CritterAPI (a ModuleScript table, `API.Ready`).
- **New client script** CritterPlay.client.lua: event banner with compass and 🚀, weather particles around the camera, knockback, 🗺️ map/travel/farm visits, 🧪 fusion, buddy bar, harvest popups.
- Dev menu: start each event, Snow, Storm, mutate my crops, grow my crops.

## Economy loop pass — 2026-11-15
- **Seeds are owned items now**: `prof.Seeds`, mirrored to player attributes `Seed_<name>`. You plant your chosen seed from the bag, and Puffberry is free forever. The HUD seed bag shows counts.
- **11 crops** (`Data.Crops`):
  - The 4 berries
  - 🎃 Pumpkin (Giant x4 size chances)
  - Fruit trees: 🍎 Apple, 🍒 Cherry, 🥭 Mango, 🐉 Dragonfruit. Plant once; after a harvest the fruit regrows in `Regrow` seconds (`Mature` plot attribute).
  - 🌙 Moonflower and 💫 Starfruit (Glow: x3 mutations during events / Star Night / Storm).
  - PackOnly crops only come from seed packs. Only the 4 base berries are used for catching.
- **ShopServer.server.lua**:
  - The seed shop (CritterAcres.SeedShop: counter, shopkeeper, board, balloon Dock) restocks every 5 min from `Data.ShopSeeds`. Stock is shared, but each player has their own amounts (`prof.ShopEpoch/ShopBought`).
  - Rare seeds get a server shout. 🔔 Bell owners (`prof.Bell`) get a popup.
  - 🎁 Seed packs (`Data.SeedPacks`, a reel show) with a free Basic pack each day (`prof.FreePacks`).
  - 📗 Seed Book rows (`Data.SeedBookRows`, `prof.SeedBook/SeedRows`).
  - Its actions are registered on FarmServer's ACTIONS through `API.ACTIONS`. The 🛒 HUD button shows the countdown and takes you to the shop.
- **Working slots**:
  - `prof.Workers` (ids on duty) and `prof.WorkSlots` (3 → 6 via `Data.SlotCosts`, ➕ in the Pets menu).
  - Jobs use energy (`Data.EnergyCost`). At 0 the pet naps at the farm hut (`rec.NapUntil`, `Data.NapTime`), then wakes with a dream gift (`Data.DreamGifts`, luckier for rare/happy pets).
  - `fillSlots` auto-swaps in bench pets. 🧺/🪑 in the profile picks manually (`rec.Bench`).
  - Worker cap is now 10 (+5 with the Critter Hut).
- **Incubator**:
  - Only 3 eggs hatch at a time (`startEggs`/`addEgg`); the rest wait (⏸). Eggs show on each farm's Nest and wobble when ready. Walk up to hatch, which plays the hatch show.
  - Limited 🍂 Harvest Egg (`Data.Seasonal`, until 2026-12-01) drops from expeditions. Its pets wear the limited Leaf Crown.
- Farm extras (from BuildWorld step `farmExtras`): Hut + NapSpot, Bench + BenchSpot, Nest (Base, Egg1–3).
- Dev menu: restock now, all seeds x5, tire my workers, Harvest egg.

## World + crafting pass — 2026-11-15
- **UI rule changed:** short words next to icons everywhere (CK found icon-only UI unclear).
- **Fixes**:
  - Pets now stand on the real ground. FarmServer raycasts `groundAt` against the farm, plaza, biome, meadow and path grounds; GROUND_Y was below the surfaces.
  - Workers show a ⚡ energy bar (or a 💤 nap countdown) under their name tag (`updateEnergyBar`).
  - Crops look like their fruit. `Builds.module.lua` (ReplicatedStorage) builds every crop shape plus a seedling; plots show them as the "Look" model, and tree fruit uses the same models.
- **Bigger world** (BuildWorld steps `meadow`, `Forest`, `Peaks`, `Caves`, `Volcano`, `paths`):
  - Meadow 220x160; Forest/Peaks 280x320 at x ±330; Caves/Volcano 300x260 at z -390.
  - 110 resource nodes (models with attribute `Node`) in folders called "Nodes".
- **Resources and crafting** (`CraftServer.server.lua`, `Data.Resources/Nodes/Tools/GearRecipes/GearUpgrades`):
  - Gather 10 resources; better tools are needed for later biomes (Tool Lv 0–5, `prof.Tool`). The buddy pet helps (+1 hit, +1 resource).
  - Expeditions bring back their biome's resources.
  - The 🔨 Workbench in the plaza makes tools, crafts gear (random rarity), adds ⭐ gear upgrades (+25% each), upgrades soil, sells decorations and toys.
  - Resources are in `prof.Res` and player attributes `Res_<name>`.
- **Farm upgrades**:
  - 6 bonus plots per farm (BuildWorld `farmPlots`, 15 plots total). They unlock in order (`Data.PlotUnlocks`, `prof.PlotsOpen`) at the 🔓 plot.
  - Soil levels per plot (`Data.Soil`, `prof.Soil["1".."15"]`, plot attribute `Soil`) make crops grow faster and mutate more.
- **Decorating**:
  - 16 decorations (`Data.Decor`, `Builds.Decor`), bought at the Workbench and placed with 🏡 Decorate. There's a see-through preview, ↻ to turn, and ✋ pick up. Saved in `prof.Decor` as farm-local x/z/r.
  - Sprinklers water plots within 14 studs every 15 s. Beehives give the plot attribute `Bee` (+25% growth). Windmills spin.
- **FunServer.server.lua**:
  - Toys: 🫧 bubble wand (free), 🎊 confetti, 🎆 fireworks.
  - 30 🌰 golden acorns (BuildWorld `acorns`, `prof.Acorns`, rewards at 10/20/30). Found acorns are hidden locally.
  - 🏷️ Titles over your head (`Data.Titles`, `API.giveTitle`, `prof.Titles/Title`).
  - 🏆 Record board in the plaza.
  - 🍀 Lucky hour: one UTC hour per day, x2 shiny chance (`LuckyUntil`).
- Pet sounds: squeak / meow / roar on pet and tricks. These are free Creator Store audio ids in `PET_SOUND` (CritterAnimator) and may need swapping if moderated.
- **New client script** CritterWorld.client.lua: 🎒 Bag, 🔨 Workbench window, 🏡 Decorate mode, 🏷️ Titles, toy bar, acorn tracker, lucky hour chip, playground bounce.
- Plaza extras (BuildWorld `plazaExtras`): Workbench, RecordBoard, Playground south of the plaza (trampolines and bounce pads named "Bounce" with a Power attribute, plus a slide).
- Dev menu (FarmServer DEV): Resources, ToolUp, Lucky. These have no HUD buttons yet; call them with `act("Dev", "Resources")`.

## Next
- [ ] Visually check the new booth, quests and raid screens (screenshots failed: Studio wasn't rendering, probably minimized)
- [ ] Bloomby model (try a new prompt)
- [ ] Playtest the generated models on the farm (size, ground height)
- [ ] Bigger roadmap in TO-DEVELOP.md (seed tiers by farm level, open world, co-op dungeons, battles, trading…)

## Pass 7 (2026-11-15): hooks, one pet family, gear tiers
- **One pet family**: every species has Job + Class (Data EXTRA_JOB/EXTRA_CLASS), Role = "Pet". Own Data.PetCap (60); only Data.FarmPetCap(level) are on the farm, rest `rec.Stored` (📦). Secret nest-only species: Bubbloom, Emberfrost, Glitterpaw (`Secret = true`, skipped in eggs/wild).
- **Gear**: Data.GearTiers (Leaf→Magma, `g.Tier`), upgrades to +10 with Data.UpgradeChance; fail = `g.Luck += 0.1`. CraftServer CraftGear(kind, tier); CritterWorld power-up screen (`openPowerUp`). Decorations buyable from the 🏡 Decorate bar.
- **PackOpen** module (ReplicatedStorage): tap-to-open pack/egg + card flip. Used by hatch, prize pack (old spin), seed packs, mail, journey, calendar, gifts.
- **New server scripts** (all use CritterAPI): PetLife (storage, NamePet, Ride, Best Friends Nest, trading via CritterTrade remote), Hooks (journey, playtime gifts, calendar, mailbox + SendGift, piles, visitor, greeting, Moon Pot, golden dash, NPC helpers, badges `API.badge`, friend luck, Farm Power), Adventure (biome gates `prof.Gates`, fishing, raccoons, rare fruit, EggSnatch + FashionShow events registered on `API.EVENTS`).
- **New clients**: CritterHooks (chip stack, journey arrow, calendar, NPC window, unlock NEW! pops by Data.ButtonUnlocks, coin fly, reveals), CritterSocial (trade/gift buttons next to Bag, trade window, fishing minigame, show voting).
- FarmServer hooks: `API.questHooks`, `API.stateHooks`, `API.onNewPet`, `API.onHatch`, `API.DEV_EXTRA` (dev commands from other scripts), growCheck (Baby/Kid/Adult respawn), luck meter in Hatch (`prof.Luck`), `rec.Odds`, Legendary aura, offline coins → `prof.Pile`.
- Badges: fill Data.Badges ids (0 = off). Friend-pet-in-your-nest not built.

## UI revamp (2026-11-15)
- Minimal player UI in StarterPlayerScripts.CritterMenus (uses ReplicatedStorage.UIKit for windows, rows, cards, buttons, tooltips):
  top-left level + coins, top-right 🔔 To do (Ready now / Daily quests / Helpers / Journey / More), dock Pets · Farm · World · Shop,
  seed button only on your farm, buddy button bottom-left (toggles CritterPlay's buddy bar).
- Old buttons are hidden through ReplicatedStorage.CritterUIBridge (BindableEvent, "HideOld"). The detailed old screens are opened through it:
  HUD (PetProfile, Book, Dev, Hatch, Spin), CritterPlay (Nest, Shop tab, PackShow, Buddy), CritterWorld (Decorate, Bench, PowerUp, Titles),
  CritterHooks (PlayGift, Calendar, NPC, NPCClaim), CritterSocial (Gift, Trade). HUD fires "Reopen","Pets" after a bridged pet profile.
- Decorate (build) mode keys: 1-9 pick, R rotate (Shift+R back), E move, X/Delete remove, G grid 1/2/4, Q cancel, B open/close. Key bar above the panel,
  ghost glows green (fits) / red (off the farm).
- The world floors were lowered to sit on the baseplate (all floor tops at y 0.3). The "My seeds" label was removed (it was also duplicating).

## Terrain Portal pass (2026-11-17)
- **The wild lands are no longer joined to town.** Old biomes (Forest/Peaks/Caves/Volcano/MeadowExtras), their roads, the 5 biome portals with their nooks and chips, and far Meadow decor were moved to **ServerStorage.OldTerrains** (backup, nothing deleted). The Meadow ground shrank to **CritterAcres.NorthGreen** (raid gate, fishing pond, portal). Baseplate is grass now, and a tree belt (TownDressing.Border, 411 trees) hides the empty land. The 30 golden acorns were re-hidden by trees/rocks/planters around town.
- **🌀 Terrain Portal** (CritterAcres.TerrainPortal at (4, -72), generated arch + 5 land gems; Gate = walk-in trigger, Out = where you come back). Builder: `BuildTerrainPortal.lua` (steps props, clear, portal, acorns, border).
- **Realms.server.lua** (ServerScriptService): parties (max 4, invites expire in 45 s, leader picks the land and presses Explore, 4 s countdown), land gates open from the portal screen (`RealmOpenGate`, same Data.Gates prices). Each trip builds a **new map from a random seed** in a free slot (8 slots at x/z 9000+, 700 apart): 400x400 terrain (WriteVoxels), winding trail spawn → glades → treasure grove, 2-4 side pockets (one is a pond: water / ice / lava that knocks you back), border mountains + invisible walls, props per land (ServerStorage.RealmProps: SnowPine, IceCrystal, CaveCrystal, GlowShroom, LavaRock, DeadTree, GiantShroom + IslandProps trees), gather nodes (RealmProps.Nodes, `API.setupNode`), wild critters (spawnCritter with Biome = "Realm<slot>", `API.pointPickers`), a 🎁 treasure chest (coins + land resources, once per explorer per map) and a "Boss den coming soon" sign. Exit portal at spawn or 🚪 Leave. Empty maps are wiped after 20 s. Dying/resetting puts you back in town.
- **TerrainPortal.client.lua**: UIKit portal window (land cards, party list, invite list with ⭐ friends, Explore), 💌 invite popup anywhere, countdown + "making a brand-new map" cover, in-map top bar (land, Map #seed, 🚪 Leave), per-land tint + floating pollen/fireflies/snow/motes/embers.
- Patched: FarmServer (meadow fallback = NorthGreen, biomePoint uses `API.pointPickers`, Travel to `API.travelSpots` TerrainPortal/Pond, wild spawning only for biomes with ground parts, exports wildCount/rollBiomeSpecies), CraftServer (`API.setupNode`), Adventure (no world gate models, egg snatch goal = Terrain Portal), CritterData (Gates without At, GateBounds = {}), CritterMenus (places list, fishing, texts), CritterPlay map tile, CritterHooks journey arrow.
- Dev: `API.DEV_EXTRA.Realm(player, prof, "Forest")` jumps straight into a fresh map.
- Next: mobs + combat and the boss mini-dungeon at the end of each map (the sign marks the spot).
- 2026-11-17 later: land picking fixed (`API.coinsOf` returns the leaderstats IntValue, compare `.Value`; same fix in Hooks shop). World Boss now lands on NorthGreen. Maps are 1000x1000 (CFG.Half = 500, slots 1200 apart): 9-12 point main trail + 9-13 side trails (Pond / Rich / Pocket), ~5x trees/props, nodes in every clearing + along trails (Rich pockets 10-14), 🧺 supply stashes, mobs from ServerStorage.MobModels.<Land> (groups of 2-4, 7% special, boss at the den). Only Meadow has mob models so far. MobAnimator skips rigs over 260 studs from the camera. Signs are TownChips chips (Icon/Label).
- 2026-11-17 mobs for every land: ServerStorage.MobModels now has 5 per land (3 normal, 1 Special with MobKind + GlowColor, 1 Boss). Forest: Mushling (herd), Acorn Knight, Twiggle, Glowcap Mushling*, Bramble Bear (boss). Peaks: Snowpuff (herd), Pengling (herd), Gale Sprite, Aurora Snowpuff*, Ice Wyrm (boss). Caves: Gemshell Crab, Glowbat (herd), Rockroll, Prism Crab*, Gem Golem (boss). Volcano: Cinderpup (herd), Emberbeetle, Smoglet, Bluefire Cinderpup*, Lava Titan (boss). Meadow Puffbloom is also a herd kind. The four bosses share names with the old raid enemies (EnemyModels are unchanged; raids still use them). Workspace.MobPreview was removed from town.
  - Rig tool: ServerStorage.MobRigBuild (mirrored in MobRigBuild.module.lua): build(job) renames generated parts to the rig layout, mirrors a bad eye, adds glints/lids/mouth on the eye's front surface, scales, stores in MobModels.<Land>; reface(m) redoes a face.
  - Herds: template attribute HerdKind -> Realms spawns 3-5 of that kind with Herd = id (75% of the time) and a bigger Roam; MobAnimator makes the first one the leader and the rest follow in formation. Mobs now follow terrain height while walking.
  - MobAnimator KIND table: move style (hop/walk/waddle/scuttle/roll/slide/fly/hover/float/stomp), speed, signature move + particles per kind.
- 2026-11-17 combat pass:
  - Mobs are battle-only: Realms no longer spawns wild critters in the lands; new pets only come from eggs (mobs can drop one).
  - Lands open by farm level only (Data.Gates = {Level}); Realms syncGates keeps prof.Gates / "Gates" attr in step. Fashion show removed (Adventure, Data.Events, HUD dev, CritterSocial voting).
  - Sinking fix: Realms world() raycasts the real terrain surface (voxel surface differs from the height formula).
  - ServerScriptService.Combat (Combat.server.lua): mob brains (notice 16 studs, herds share targets, chase, wind-up tell, bonk, leash 50 + heal, respawn), hearts (Data.Hearts=5, regen, faint -> wake at map portal, nothing lost), weapons (prof.Weapons/WeaponOn/Capsules, Tool built from ReplicatedStorage.WeaponModels, Magic/Melee, crits, stars, shiny), capsules (Basic 💰300 + land capsules from mobs/bosses/chests), drops (coins, farm XP, res, capsule, egg via API.grant), buddy pet zaps. Remote ReplicatedStorage.Combat. API.combatAddMob / combatRunGone / combatLeft / giveCapsule / realmSpawn.
  - StarterPlayerScripts.Combat (Combat.client.lua): attack (tool click, ⚔️ button, G = weapons menu), ❗ + red Highlight on angry mobs (flash before a bonk), HP bars, boss bar, damage numbers, loot, hearts row, red flash, faint screen, Weapons window + PackOpen capsule reveal. Backpack hotbar hidden.
  - MobAnimator follows server attrs Goal/Spd/Act/Angry/TargetId/Dead. Portal screen: level-only cards with mob list, "3 Bring a buddy?" picker (ACTIONS.RealmBuddy). Dock has a ⚔️ Weapons button.
  - Local copies of CritterHUD.client.lua and PackOpen.module.lua were already older than Studio before this pass (edits went into Studio's versions); re-export them from Studio before trusting the local files.

## Camera, buddy modes, loot stars pass (2026-11-17), SYNCED TO STUDIO
CK's request:
- the camera follows the mouse
- mobs don't teleport when hit
- the buddy pet has a Passive/Aggressive toggle
- mob drops are glowing stars; you see what's inside only when you collect one
- pets auto-collect stars, upgradable later

**Sync status (2026-11-17):** DONE in Studio, each verified by length + checksum + compile:
- ReplicatedStorage.LootStar: the generated star MeshPart, depth stretched to 55% of its width so it reads as 3D.
- The CritterData block.
- StarterPlayerScripts.MouseLook (new).
- MobAnimator (find/replace).
- ServerScriptService.Combat (full paste).

- StarterPlayerScripts.Combat (full paste).
Everything is synced. CK still needs to playtest and save the place.

Original sync list:
- Combat.server.lua and Combat.client.lua: full paste.
- MobAnimator.client.lua: full paste.
- MouseLook.client.lua: a NEW LocalScript in StarterPlayerScripts named MouseLook.
- CritterData: find/replace the new block in after the `Data.CritChance, Data.CritMult = 0.12, 2` line.
- The star mesh: an async generate_mesh job (`e692bf26-8085-42e5-9119-fb00d6158be5`) was started. Store the result as ReplicatedStorage.LootStar. If it's missing, the code uses a neon gold ball instead.
- Then give CK a what-to-check list.

### New CritterData values
- `Data.BuddyModes = {"Passive","Aggressive"}`
- `Data.BuddyAggroRadius = 22`
- `Data.StarLife = 120` (seconds before a star fades)
- `Data.StarPickup = 5` (walk-over radius)
- `Data.PetCollect = {Radius = 35, Secs = {4, 3, 2.2, 1.5, 1}}`: the pet-collect interval by `prof.PetCollectLv` (1-5). No upgrade shop exists yet; adding one only means raising PetCollectLv.

### Mouse look (MouseLook.client.lua)
- Works on keyboard and mouse only.
- Shift-lock style: the mouse is locked to the center with a white aim dot, the character faces the camera direction, and CameraOffset is (1.5, 0, 0).
- Ctrl or the chip above the hearts (at x −140) turns it on or off.
- The mouse frees itself automatically while:
  - a big window is open (a visible GuiObject bigger than 40%×35% of the screen, up to 2 levels under a ScreenGui)
  - the Roblox menu is open
  - a text box has focus
  - the player is dead
- No rotation while sitting or riding.

### Mob teleport fix (MobAnimator)
- The server-mode rule "snap to Goal if more than 30 studs away" was removed. A ranged magic hit put the chase goal far away, and the client snapped the mob onto the player.
- Mobs now always walk, 25% faster when more than 14 studs behind.

### Buddy modes (Combat)
- The setting is `prof.BuddyMode`, mirrored to the player attribute BuddyMode. It's set by `ACTIONS.BuddyMode(mode)`.
- On the client there's a chip at x +120 above the hearts ("🛡️ Buddy: Passive" or "⚔️ Buddy: Aggressive"), plus the **V** key. It only shows in a land when you brought a RealmBuddy.
- **Passive:** the buddy attacks only mobs targeting the player, or the mob the player hit in the last 8 s (`lastHitBy`).
- **Aggressive:** also attacks any mob within `BuddyAggroRadius` of the player.
- Either way the pet must be within 30 studs of the mob. The attacker or the just-hit mob gets top priority.

### ⭐ Loot stars (Combat)
- `reward()` gives coins and XP right away and shows "💰+N ⭐ xK".
- Everything else drops as stars:
  - resources: 3 from a boss, 1 from a special, a chance from normal mobs
  - a capsule (chance)
  - an egg (boss eggs are Star 30% of the time)
  - a boss also drops a Coins star
- **Star placement:** `dropStar` puts the star 2.5–6 studs from the mob on the terrain (raycast), 1.8 studs up.
  - Template: ReplicatedStorage.LootStar.
  - The star has a PointLight and sparkles, is anchored and has no collision.
  - Attributes Owner (UserId) and From (mob position); tag "LootStar"; parented to run.folder.
- **Pickup:**
  - The owner walks within StarPickup, or the pet collects it (`collectStar(p, petModel)`).
  - The server grants the gift and sends `{Kind = "StarGot", Pos, Text, Big, Pet}`.
- **Client:**
  - Other players' stars are destroyed locally.
  - Stars pop out of the mob in an arc, then bob and spin.
  - First-star toast.
  - On pickup: a burst plus floating text. A pet pickup shows a ball zipping to the pet and "🐾 item".
- **Pet auto-collect:** a loop every 0.25 s; the pet grabs the nearest owned star within Radius every `Secs[PetCollectLv]` seconds.

## 👑 Boss special attacks pass (2026-11-17), SYNCED TO STUDIO
CK's request: boss attack animations; several special attacks with warnings for the big ones (meteors with circles on the floor, stuns, projectiles, AOE indicators).

**Sync status:** DONE, each verified by length + checksum + compile:
- ServerScriptService.BossSkills (new Script, BossSkills.server.lua)
- StarterPlayerScripts.BossFx (new LocalScript, BossFx.client.lua)
- Combat.server (find/replace)
- MobAnimator (find/replace)
- CritterData (the block inserted after `Data.MobEgg`)

CK still needs to playtest and save the place.

### How it works
- **Data:** `Data.BossSkill` holds First (3 s), Gap ({6, 9} s between specials), StunSecs 1.2, HitGap 0.7 (one heart max per 0.7 s from specials) and Range 70. `Data.BossSkills[kind]` is the list of specials per boss.
- **Special types:**
  - Rain: red circles that fill up (one under each player plus more around them), then something falls from the sky.
  - Slam: a red circle around the boss; it crouches, jumps and lands. It can stun.
  - Volley: red lanes, then glowing balls fly down them. Either one at a time, each aimed at a random fighter, or `Fan` = all at once in a fan.
  - Line: a red lane in front. `Mode` Charge makes the boss dash through it; Breath is a long blast (`Hold` s) and can stun.
- **Specials per boss:**
  - Queen Buzzbloom: Pollen Rain, Honey Shots (sticky stun), Buzz Burst
  - Bramble Bear: Acorn Drop, Thorn Fan, Big Stomp (dizzy), Bear Charge
  - Ice Wyrm: Icicle Rain, Frost Breath (frozen), Snowballs
  - Gem Golem: Crystal Rain, Gem Shards fan, Quake Slam (dizzy)
  - Lava Titan: Meteor Shower, Fireballs, Fire Breath, Eruption Slam (dizzy)
- **Combat changes:**
  - `hurt()` returns true when it lands.
  - New exports: API.combatHurt / combatSend / combatSendRun / combatSetGoal.
  - `calm()` resets mob.skillAt and mob.casting.
  - In think(), a boss calls `API.bossThink(mob, now, p, hrp, d)` before chasing or bonking; true means it's busy casting.
- **BossSkills:**
  - pick() never repeats the last special, skips Slam when nobody is close and skips Line when the target is beyond L+4.
  - cast() stands the boss still and sets the model attributes Skill (Summon/Slam/Throw/Breath/Charge), SkillDur, SkillHit, SkillGap, SkillShots and SkillDir, then bumps SkillN.
  - It sends BossCast / BossZone / BossShot / BossShotEnd to everyone in the run, and Stun {Secs, Look = Dizzy/Ice/Honey} to the player who was hit.
  - Hits are server-side, using flat distance.
- **BossFx (client):**
  - The special's name pops over the boss, plus a hint chip at the top ("⚠️ Get out of the red circles!").
  - Red neon discs and lanes fill up over the warning time.
  - Falling icicles, gems, lava rocks and balls, with trails.
  - Impact bursts and dust shockwaves.
  - A breath particle stream.
  - Camera shake is a position-only offset at RenderPriority.Camera+2, so it works with MouseLook.
  - Stun sets WalkSpeed/Jump to 0 and shows a 💫/🧊/🍯 label over your head, with an ice block, honey puddle or orbiting stars.
  - Zones clear on boss Defeat or when the Realm attribute changes.
- **MobAnimator:** a new "skill" state with poses:
  - Summon: rear up, arms high, roar and shake, then point down.
  - Slam: crouch, leap 0.75×height, squash.
  - Throw: alternate arms per shot; both arms for a fan.
  - Breath: head back, then a blast.
  - Charge: head down, paw the ground, then dash. Position still slides to Goal, so the Charge dash moves the boss.
  - The boss faces SkillDir when it's set.
- **Not done:** the World Boss in WorldEvents (town NorthGreen) still uses its old stomp/meteor knockbacks and doesn't use this system yet.

## ⚡ PWR, HP numbers, level-scaled lands, ranged mobs (2026-11-17), SYNCED TO STUDIO
CK asked for:
- HP/ATT as numbers
- mobs and rewards that scale with level
- a party PWR stat (more members = higher total, and mobs scale to it)
- groups that mix melee and ranged mobs

**Sync status:** DONE, each verified:
- Combat.server, Combat.client, BossSkills, Realms and TerrainPortal by find/replace plus a full length + checksum match against local.
- CritterData: the hearts/MobStats block swapped for the PWR block. Studio drifts, so this was checked by compile + run + field check.

CK still needs to playtest and save.

### Data (CritterData)
- `Data.Pwr` {Base 10, Step 1.15, BuddyShare 0.5, HeroBonus 0.04}, with `Data.PwrOfLevel(lv)` and `Data.LevelOfPwr(pwr)`; Lv 1 = PWR 10, ×1.15 per level.
- `Data.LandLevels`: Meadow 1-5, Forest 5-10, Peaks 10-15, Caves 15-20, Volcano 20-25.
- `Data.HpPerPwr` = 10, `HpRegenDelay` = 4, `HpRegenPct` = 0.06/s, `SafeSecs` = 3.
- `Data.HeroMax` = 30, `Data.HeroNeed(lv) = floor(20 × lv^1.6)`.
- `Data.MobScale`: HP 30×1.18^(L−1), ATT 8×1.15^(L−1), coins 3×1.14^(L−1), farm XP 1×1.1^(L−1), Hero XP 3×1.17^(L−1), DepthMax 2.
- `MobSpecial` / `MobBoss` now carry ATT and Hero multipliers; the boss is +2 levels (`MobBoss.Lv`).
- `Data.MobGray` {Below 6, Reward 0.25}.
- `Data.MobRanged` {Chance 0.35, Reach 20, ATT 0.8, Speed 26, R 1.4, Range 32, Aim 0.8, Cd, Look per land}.
- `Data.MobDanger(mobLv, myLv)` returns Gray / Green / Orange / Red plus a color.
- Removed: Data.Hearts, HeartRegen*, MobStats.

### Server (Combat)
- **PWR:** `pwrOf(player)` = (WeaponPower(equipped) + petStats(FollowId pet).ATK × 0.5) × (1 + 0.04 × (HeroLv − 1)). Exported as `API.pwrOf`.
  - Player attributes: PWR, HP, HPMax (= 10 × PWR), HeroLv, HeroXp, PartyPWR (set only while in a land).
  - `refreshPwr` runs every 2 s and keeps the HP share when max HP changes.
- **Damage:** `hurt(player, damage, src)` applies ±10%, returns true if it landed, and sends Hurt {N, Big, HP}.
  - Melee bonk = mob.atk. Boss specials = boss atk × sk.Hurt.
- **Hero XP** from `reward()`; a level-up sends HeroUp {Lv, PWR}.
- **Mob level** (`setLevel`):
  - level = clamp(floor(LevelOfPwr(party PWR sum)), band) + Depth (0-2, or +2 for the boss).
  - ATT level uses the party average instead of the sum.
  - Mob attributes: Lv, ATT, HP, MaxHP.
- **Party PWR** (`runPwr(run)`): the sum and average over run.inside, or over the party members before anyone arrives.
  - A loop every 2 s re-levels mobs that aren't fighting; mobs also re-level when they give up and go home.
- **Rewards** scale with mob level. Gray mobs (6+ levels under you) give 25% (coins, XP, drop chances) and send Loot.Gray.
- **Ranged mobs** (`mob.ranged`, model attribute Role = "Ranged"):
  - They keep about 20 studs away and step back when you're within 7.
  - Every 2.6-3.4 s they bump Act and call `shoot()`, which sends BossShot/BossShotEnd with negative ids; BossFx draws the red lane and the ball.

### Realms
- Each mob gets a Depth attribute: 0-2 by distance from the spawn, toward the treasure/den.
- About 35% of group members are Role = "Ranged"; never the first one or the boss.

### Clients
- **Combat.client:**
  - HP card: ❤️ hp / max bar, plus a "⚔️ Hero Lv · ⚡ PWR · 👥 Party PWR" line and an XP bar.
  - A red "-N" floats over you when you're hit, and the Hero level-up shows a banner.
  - Mob tag billboard "Lv N ⚔️/🏹 ATT", colored by MobDanger.
  - The boss bar shows Lv, and there's a tip toast when you fight gray mobs.
- **TerrainPortal:**
  - Land cards show "Lv a-b ⚡rec+", in red if your PWR is lower; the tooltip explains it.
  - Party rows show ⚡ PWR, and the header shows 👥 Party PWR.
- Lands still open by farm level (Data.Gates); PWR is only a recommendation.

## 🌳 Skill tree + 🏹 Range weapons (2026-11-17), SYNCED TO STUDIO
CK asked for a skill tree grouped into Melee / Range / Mage, with levels:
- player max level 50, so 50 points
- skills upgradable up to 5 times
- each point either upgrades a skill or unlocks the next one, if your level allows it

CK approved the clickable preview, with all branches open to everyone.

**Sync status:** DONE.
- Verified by checksum: Skills (new server Script), SkillTree (new StarterPlayerScripts LocalScript), Combat.server, Combat.client, CritterMenus.
- CritterData: compile + run + field check (Studio drifts).
- 5 generated weapon models are in ReplicatedStorage.WeaponModels: PebbleSling, PeaShooter, ToyBow, SunBow, RainbowBow. Each is one MeshPart, long side up.

CK still needs to playtest and save.

### Data
- `Data.HeroMax` = 50 (1 skill point per Hero Level).
- `Data.SkillBranches`: Melee / Range / Mage, each with Style, Color and an Order list.
- `Data.Skills[id]` = {Branch, Name, Icon, Lv, Max, Req, Row, Col, Kind, Per / Dmg() / Stun() / Secs() ..., Say(rank)}.
- **The tree in each branch:**
  - Lv 1 starter (Dmg +8% per level for that branch's weapon style)
  - Lv 5 passive and Lv 10 passive, both requiring the starter
  - Lv 18 passive, requiring the Lv 5 one
  - Lv 25 Q active, requiring the Lv 10 one
  - Lv 40 R ultimate (max 3), requiring the Q
- **Skills per branch:**
  - Melee: BigBonk, ToughHide (+6% HP), SpinSwing (every 3rd swing hits all around, up to 6), ShieldUp (−4% damage taken), GroundPound (Q: stun circle 12), GiantMode (R: ScaleTo 1.5 plus a damage boost).
  - Range: SharpShot, QuickFeet (+4% WalkSpeed in lands), DoubleShot (10% per level), EagleEye (+3% crit), ArrowRain (Q: aimed circle 10), RapidFire (R: AtkSpeed attribute).
  - Mage: SparkPower, LongReach (+6% range; ReachMul attribute), BouncyBolt (hops), HealingSparkle (1% max HP per hit per level), MiniMeteor (Q: aimed circle), FreezeRing (R: Ice stun, radius 16).
- `Data.SkillOf(branch, kind)`, `Data.BranchOfStyle(style)`, `Data.SkillAim` = 40.
- 5 new Range weapons: Style "Range", Common to Mythic, Dmg 11 / 25 / 58 / 128 / 275, Range 42-50. They're in every capsule pool by rarity.

### Server
- **Skills.server.lua:**
  - Storage: prof.Skills = {id = rank}.
  - Actions: SkillInfo, SkillLearn(id) (checks HeroLv, Req, points, Max), SkillReset (free).
  - Attributes: SkillPts, ReachMul.
  - Exports: API.skillRank, API.skillBuff(player, "Giant"/"Rapid"), API.skillPush.
  - (Replaced by the skill bar pass below: moves are cast by slot 1-5, cooldowns are per skill.)
  - Sends SkillFx to everyone in the run.
- **Combat:**
  - PWR multiplies weapon power by the branch damage skill. Max HP includes ToughHide; hurt applies ShieldUp.
  - Stunned mobs (mob.stunUntil, attribute Stun) stand still. Bosses get half the stun time.
  - The attack handler covers the Range style (targets like Magic, plus DoubleShot), Spin Swing, EagleEye crit, Healing Sparkle, Bouncy Bolt hops ("Hops" message) and Rapid Fire cooldown.
  - New exports: combatWeapon, attackPower, combatMobsNear, combatDamage, combatStun, combatRefreshPwr.

### Clients
- **SkillTree.client.lua:**
  - UIKit window (K or the 🌳 Skills dock button): 3 colored columns with L-shaped joints between cards, a detail panel (Now / Next / requirement, Learn / Upgrade button) and Free reset.
  - (Q/R buttons replaced by the 5-slot hotbar, see the skill bar pass.)
  - Aim: mouse, or screen center under mouse look.
  - FX for every skill.
  - 💫 / 🧊 labels over stunned mobs.
- **Combat.client:**
  - Arrows for Range bolts; "Hops" bolts.
  - Rapid Fire / Long Reach applied on the client.
  - 🏹 Range labels in the weapons menu.
  - The level-up banner says "+1 skill point (K)".
- **CritterMenus dock:** 6 buttons; 🌳 Skills fires bridge "Skills", with a red badge showing SkillPts.
- **Hotkeys:** K (skill tree). 1-5 (skill bar moves) only work inside a land.

## 🛠 Dev menu pass (2026-11-17)
- **DevMenu.client.lua** (new LocalScript in StarterPlayerScripts, Studio only, 11697 / 972769):
  - A UIKit window opened by the 🛠 Dev button (bridge "Dev").
  - Tabs: ⚔️ Hero / 🗡️ Weapons / 💰 Stuff / 🌱 Farm / 🐾 Pets / 🌠 Events / ♻️ Save.
  - The Hero tab shows live Lv / PWR / HP / skill points / no-damage.
  - The Weapons tab has a card per weapon, grouped by branch, with a 3D model and a ✋ Hold button.
  - Every button calls `act("Dev", cmd, arg)`.
- **The old flat dev grid** (DEV_BUTTONS + MENUS.Dev) is removed from CritterHUD. Studio is now 73356 / 897449; the local copy is still older (drifted).
- **New DEV_EXTRA commands:**
  - Combat (49508 / 41388):
    - Hero(arg): "+n"/"-n" adds levels, a number sets the level. It also fills HP and pushes skill points.
    - HeroXp, FullHp
    - God: toggles the DevGod attribute; hurt() ignores players that have it.
    - Weapon(name): adds the weapon and equips it.
    - WeaponsOf(style or nil), WeaponStars
  - Skills (9743 / 801187):
    - SkillCd (clears the Q/R cooldowns)
    - SkillsMax (Hero Lv 50 + all skills maxed)
    - pointsLeft is now clamped at 0.
- **To add a new dev tool:** put it in API.DEV_EXTRA (any server script) and add a button to a page in DevMenu.PAGES.

## ⚡ Skill bar pass (2026-11-17)
- **5 slots.** Players drag their move skills into the slots and press 1-5 in the lands to use them. Q/R are gone.
- **Data:**
  - Move skills now have `Kind = "Active"` (`Big = true` for the Lv 40 ones), and their Say text no longer starts with "Q:" / "R:".
  - `Data.SkillSlots = 5`.
  - **Adding more skills later:** add an entry to Data.Skills and its branch Order, give it Kind "Active", Cd, Row and Col, then add its effect in the Skills `cast()` and an FX entry in SkillTree. It can then be dragged into the bar automatically.
- **Skills.server** (12005 / 987505):
  - `prof.SkillBar` holds 5 ids, with "" for an empty slot.
  - The first time a profile loads, the bar fills with the moves you already know. A newly learned move goes into the first empty slot.
  - Reset clears the bar.
  - New action `SkillSlot(slot, id or "")`: moves a skill into a slot, swapping it out of any other slot, or clears the slot.
  - The `SkillBar` attribute holds "id,id,,," for the hotbar.
  - The cast remote is now ("Skill", slot number, aim). Cooldowns are per skill: attribute `Cd_<id>`.
  - Any weapon can use any move. Rapid Fire now speeds up every weapon (Combat.server 49513 / 42137, Combat.client 38479 / 108242).
- **SkillTree.client** (26711 / 138811):
  - The top row is: points, the ⚡ skill bar with 5 numbered slots, and Free reset.
  - Drag a learned ⚡ card onto a slot. Drag one slot onto another to swap them, or drag a slot off the bar (or press its ✖) to clear it.
  - Tap-to-place also works: pick a card, then tap a slot.
  - In the lands there is a hotbar of 5 slots above the dock, with key numbers and a cooldown shade. Tapping an empty slot opens the tree.
- **CritterData:** Studio copy is 84742 bytes (drifted; patched by find/replace). The local copy is 84596.
- **DevMenu:** Lv 25 / Lv 40 labels updated. SkillCd clears every `Cd_` attribute.

## Re-sync into Pet & Garden + double-click upgrade (2026-11-17)
- **Lost changes, restored:** CK published critteracres.rbxl into Pet & Garden, but the cloud place came back without the Dev menu v2 and skill bar passes. I re-synced them from the local copies.
- **Checksums in Pet & Garden now:**
  - Combat.server 49513/42137
  - Combat.client 38479/108242
  - Skills 12005/987505
  - SkillTree 27294/186399
  - DevMenu 11715/975512
  - CritterHUD 73356/897449
  - CritterData 84742 bytes
- **Double-click:** a quick second click (within 0.4 s) on a skill card learns or upgrades it, the same as the Learn/Upgrade button (the shared `learn(id)` in SkillTree). The subtitle and tooltips mention it.
- **Sync note:** HttpService:GetAsync to localhost:34872 is now refused ("not in the Assistant HTTP allowlist"). serve-for-studio.ps1 can't be used unless CK allows that domain, so use find/replace patches or pasted long strings instead.

## Top-left levels (2026-11-17)
- **CritterMenus** (60175 / 890184): the top-left now has three parts.
  - **⚔️ Lv N:** the player (Hero) level, with an orange XP bar (HeroXp / Data.HeroNeed). Tap it for the XP left.
  - **💰 Coins:** next to the level pill.
  - **🏡 Farm Lv N:** a smaller chip under them (12, 62; 210×30) with a thin XP bar. Tap it for the farm XP left.
- The Studio-only 🛠 Dev button moved down to y = 100.

## Drag fix + level spacing (2026-11-17)
- **SkillTree** (28392 / 278708): dragging didn't work for CK. It is rebuilt:
  - The pointer comes from `UserInputService:GetMouseLocation()` every frame (RenderStepped), and the drag ends when `IsMouseButtonPressed(MouseButton1)` goes false, so it doesn't depend on InputEnded reaching us.
  - Touch uses InputChanged/InputEnded (Position + GuiInset).
  - Slots get 6 px of slack, and the hovered slot glows green.
- **CritterMenus** (60177 / 890303): the top bar is at (16, 14) with a 14 px gap between ⚔️ Lv and 💰. The 🏡 Farm chip is at (16, 78), 210×32. The 🛠 Dev button is at (16, 124).
- **DevMenu** (11745 / 978482): the Weapons tab crashed on Mythic, so it now uses Data.WeaponRarityByName instead of Data.Rarities.
- **Known, not fixed:** `ServerScriptService.Adventure:543: attempt to index nil with Instance` appears in the log, on the PlayerRemoving line in the local copy.

## Skill bars per weapon type, no dragging (2026-11-17)
- **CK's rule:** moves only work with their own weapon type. A sword can only use 🗡️ Melee moves, and so on. Dragging moves into the bar never worked for CK, so it was removed.
- **Skills.server** (12765 / 52368):
  - `prof.SkillBars = {Melee = {5}, Range = {5}, Mage = {5}}`, replacing the old `prof.SkillBar`, which is dropped. Each bar only accepts its own branch's learned moves.
  - On the first load, each bar fills with the moves you already know.
  - The `SkillBar_<Branch>` attributes hold each bar's contents.
  - New `SkillSlot(id, slot)` signature: slot 1-5 places the move (swapping it with whatever was there), and 0 takes it out.
  - `cast()` uses the bar of the weapon in your hand (`API.combatWeapon` → `BranchOfStyle`).
- **SkillTree** (27309 / 179157):
  - The window's bar shows the branch of the picked card ("🗡️ Melee bar").
  - The info panel of a learned move has **"⚡ In slot: [1] … [5] [✖]"**.
  - The hotbar shows the equipped weapon's bar, with a label like "🗡️ Melee moves" above it.
- **CritterData:** comment updated (Studio 84768).

## HUD layout pass (2026-11-18)
- **Why:** the skill hotbar sat on top of the HP card. CK asked for the dock at the top right, the HP in the middle and the skill bar just above it, with nothing overlapping.
- **Top right:** the CritterMenus dock (61190 / 980604) is a UIGridLayout anchored at (1, -12, 0, 8) holding 7 buttons: Pets, Farm, World, Shop, Weapons, Skills and 🔔 To do (the bell is now the 7th dock button).
  - Under 1060 px wide, it switches to 2 columns × 4 rows of 62×58 buttons and sets the player attribute **HudCompact**.
- **Bottom middle:**
  - HP card (Combat): bottom −16.
  - Skill hotbar (SkillTree): bottom −82, with its label above it.
  - 🖱️ Mouse look chip (MouseLook): right edge at center −198.
  - 🐾 Buddy mode chip (Combat): left edge at center +198.
  - Both chips are 210×42 at bottom −21, on the same row as the HP card.
- **Right:** ⚔️ Attack (Combat) is at (1, −24, 1, −84).
- **Top-center bars, which follow HudCompact:**
  - TerrainPortal land bar: y 84 (132 when compact). The invite pop-up is at y 160 (290 when compact).
  - Combat boss bar: GuiInset + 148 (196 when compact).
  - BossFx boss name hint: y 222 (270 when compact).
- **CritterPlay buddy actions bar:** now opens bottom-left, above the buddy button, at (0, 12, 1, −196).
- **Checksums:**
  - Combat 38873/142595
  - MouseLook 4696/401721
  - SkillTree 27308/179118
  - TerrainPortal 21773/766909
  - CritterPlay 49422/978070
  - BossFx 20872/660668
- **Not moved:** UIKit toasts (top center, y 70, about 2.6 s) can still briefly cover the pills or the dock.

## Tooltip fix + buddy chip (2026-11-18)
- **UIKit tooltips** (19419/540081):
  - The tooltip now sits above its button, or below it if there's no room. It adds the top-bar inset only when the button's ScreenGui doesn't ignore it.
  - The tooltip never catches clicks (Active = false, Interactable = false).
  - It used to cover the small 1-5 slot buttons in the skill tree and swallow the click.
- **Buddy mode chip** (🛡️ Passive / ⚔️ Aggressive, Combat client): it shows only while RealmBuddy is set.
  - Combat.server (49867/72102): the buddy loop (every 1.4 s) now clears RealmBuddy when the buddy pet is gone. That covers a pet that is missing, stored, on a trip, resting/fainted, or no longer FollowId.
  - Effect: no pet with you = no chip.
- **⚔️ Attack button** (Combat client, 38995/153766): it shows in lands only on touch devices with no keyboard (phones and tablets). On PC it's hidden, and you click with the weapon to attack.

## 🌀 Explorer's Portal rename (2026-11-18)
- The 🌀 Terrain Portal is now called **🌀 Explorer's Portal** in all player-facing text: 39 mentions in 11 scripts, the ServerStorage BuildTerrainPortalA/B builders, and the two TownChips Labels ("Explorer's Portal", "To the Explorer's Portal").
- Code names are unchanged: Workspace TerrainPortal model, TerrainPortal.client, Travel "TerrainPortal", Realms.

## Rarity tiers (2026-11-18)
- Six tiers, low to high, one color each: ⚪ Common, 🟢 Uncommon, 🔵 Rare, 🟣 Epic, 🟡 Legendary, 🔴 Mythic (CK picked set A).
- **CritterData** (Studio 85421/636499; local is still drifted):
  - Adds `Data.RarityOrder`.
  - `Data.Rarities` gets Uncommon (Order 1.5, so existing balance math is unchanged) and Mythic (Order 5).
  - `WeaponRarities` gets Uncommon. Mythic is now red (255, 80, 80); Common is (240, 240, 240).
- **PackOpen** (Studio 39305/87362):
  - Uncommon is added to ORDER at 1, the same effects as Common.
  - New colors: Common light grey-white, Uncommon green, Mythic red.
  - **The local PackOpen.module.lua is an OLD copy** (25593 bytes vs Studio 39k), so it didn't get this change. Pull it from Studio before editing locally.
- **Not done yet:**
  - No pets or weapons are Uncommon, and no pets are Mythic.
  - Egg and capsule odds have no Uncommon weights.
  - Tables keyed by rarity have no Uncommon or Mythic entries: BattleBase, GearRarityMult, OfflineRate, FindReward, RarityPower, OutfitWeights/Price, ReleaseGift, RideSpeed. Fill them in before giving any pet one of these tiers.

## 💥 Weapon damage ranges (2026-11-18), synced to Studio
- **CritterData:**
  - `Data.WeaponSpread = 0.08`.
  - `Data.WeaponRange(w)` returns lo, hi = WeaponPower × 0.92 / 1.08, so power 72 gives "66-78".
  - Each ⭐ (+10%) and ✨ shiny raise the whole range.
- **Combat.server:** a weapon hit rolls in power × (0.92-1.08); it was 0.9-1.1.
- **Combat.client:** the weapons window card, the "In your hand" line and the capsule reveal card show "💥 lo-hi"; the help panel has a 💥 line.
- **DevMenu:** weapon cards show "💥 lo-hi" (0 stars).
- **Studio checksums:**

  | Script | Base | Result |
  |---|---|---|
  | CritterData | 85421/636499 | 85908/677874 |
  | Combat.server | 49870/72380 | 49927/77718 |
  | Combat.client | 38998/154044 | 39254/174540 |
  | DevMenu | 11745/978482 | 11802/983266 |

  The local files match the results, except CritterData, which is drifted locally (local 85762/664065).

## 🏡 Build menu redo + placement fix (2026-11-18)
- **CritterWorld** (Studio = local 59126/739222): the decorate-mode section was rewritten on UIKit (`local K` is required there now).
  - **Panel:** a cream panel at the bottom middle, 94% wide (max 1040 × 196).
  - **Left:** 🧱 Build / ✋ Move / 🗑️ Remove. The active one is yellow.
  - **Middle:** a hint line plus a scrolling row of K.card item cards. Card outlines: green = owned (xN), blue = can buy (🛒 cost), grey = can't afford, orange = picked. A brown number badge marks the 1-9 key.
  - **Right:** ↻ Rotate, ▦ Grid N, ✔ Done (green).
  - **Key chips:** white UIKit chips above the panel (keyboard only) that flash yellow via `flashKey`. All buttons have tooltips; messages use K.toast.
- **Placement fix:** the preview and the click now share `pointerRay()` + `pointOnFarm()`.
  - Mouse: GetMouseLocation → ViewportPointToRay. Touch: lastTouch → ScreenPointToRay.
  - The old preview subtracted a hard-coded 36 px top bar, while the click used `input.Position` with ViewportPointToRay. With the taller top bar the two disagreed, so items landed about 1 grid square off.
  - The pick-up / remove raycast uses the same ray.
- **3D card pictures** (CritterWorld 59749/790213): `decorArt` builds each decoration once with Builds.Decor (cached in `decorTpl`) and shows it with CritterUI.ModelView (Yaw 205°). It falls back to the emoji. All 16 decorations build.
- **Hotkey clashes:** decorate mode sets the local player attribute `Decorating` while it's open.
  - Combat.client (39342/182354) skips G (⚔️ Weapons) while it's set.
  - SkillTree (27378/185168) skips 1-5 while it's set.
  - CritterWorld is 59929/806428.
  - Only G and 1-5 clashed with the build keys (1-9 R E X G Q N Del Backspace). B/P/M/K/V/Ctrl still work while building.
  - Any new hotkey should check `Decorating` if it uses a build key.
- **E prompts:** decorate mode sets `ProximityPromptService.Enabled = false` while it's open and back to true on close (local only). Before this, a nearby "E" prompt took the key and ✋ Move never toggled. CritterWorld is 60104/822233.

## 🪧 Island signs → chips (2026-11-18)
- **The chip system is extended** (CritterWorld, Studio = local 62006/976486).
  - Chips now also come from any part with the CollectionService tag **"Chip"**, not just the TownChips folder.
  - Attributes: Icon, Label, Alert (yellow, always open), Open (always open), Hidden, ChipY (studs above the part's middle; tagged parts only).
  - All attributes update live. Tagged chips are seen up to 160 studs away (town chips 360).
- **Server helper `chipSign(part, y, alert)`** (a copy in FarmServer, Hooks and PetLife):
  - It removes the part's old BillboardGuis, tags it and returns a stand-in whose `.Text = "📬 2 gifts!"` sets Icon + Label. A new line becomes " · ", and "" hides the chip.
  - So the old `label.Text = ...` update code still works untouched.
- **What is a chip now:**
  - 🏡 owner sign (Open: "Name · ⭐ lv · ❤️ likes", or "Empty farm").
  - 💰 Sell bin and 💤 Nap hut (these were icon-only).
  - 📬/📪 mailbox (yellow when gifts wait).
  - 🌙 Moon Pot (yellow when you can plant or harvest).
  - 💕 Best Friends Nest.
  - 🥚 incubator nest (yellow on "Tap").
  - Locked plots: 🔓 "Unlock · cost" (yellow) on the next plot, 🔒 "Locked" on the rest.
- **Not changed (status pop-ups, not signs):** crop mutation badges, pet name tags, `pop()` effects, gathering node labels, town NPC name tags.
- **Studio checksums:** FarmServer 144211/902270, Hooks 33850/754274, PetLife 19567/621020.
  - **The local FarmServer / Hooks / PetLife mirrors are OLD (drifted) and don't have this change.** Pull them from Studio before editing locally.

## 🛠 Critter Editor (2026-11-18), hook SYNCED TO STUDIO (CritterData 91333/104708, hook block = local apply file)
CK edits weapons / pets / eggs / capsules / skills in a local web page and pulls them into Studio with a plugin (no Claude tokens per sync).
- **Files** (`critter-acres/editor/`):
  - `Start Critter Editor.bat` → `CritterEditor.ps1`: a helper on http://localhost:34880 (PowerShell HttpListener). It serves `index.html` and the data, keeps 40 backups per file in `data/history/` and saves uploaded 3D files to `models/weapons|pets/`. `-NoBrowser` skips opening the page.
  - `index.html`: the editor (UIKit colors). It has tabs, add / copy / delete, checks (red ones block Save), the say-text preview, 3D file upload and Studio status.
  - `data/*.json`: the source of truth for those 5 tables; `version.txt` goes up on every save. They were exported from Studio on 2026-11-18. The Lua tables in CritterData are now only the fallback.
  - `CritterSync.plugin.lua`: the mirror of the installed plugin `%LOCALAPPDATA%\Roblox\Plugins\CritterSync.lua`.
  - `CritterData.apply.lua`: the block that goes into CritterData just before `return Data`.
- **How a pull works:** the plugin (Plugins tab → CritterSync) does GET /api/data, then test-requires a clone of CritterData with the new data. Only if that works does it write `ReplicatedStorage.CritterData.GameData`, a ModuleScript `return [=[json]=]` with attributes Version and PulledAt, as an undoable change. It then POSTs the models it found to /api/studio so the editor can show ✅ / ❌. Auto-pull polls /api/version every 2 s.
- **Data.ApplyGameData(json)** in CritterData builds everything first and only swaps it in when it all worked; on an error it warns and keeps the Lua data.
  - Deleted weapons and pets stay in WeaponByName / SpeciesByName so owners keep them (old pets are marked Secret). They're left out of Data.Weapons / Data.Species, so they never drop or hatch.
  - Eggs merge over the Lua ones. EggShop.Tiers is rebuilt from `Shop {Chance, Price}` on each egg.
  - Capsules can only be edited.
  - Skills can only be edited, because code reads `Data.Skills.<Id>` directly. `Scale {Name = {Base, Per, Round}}` becomes the rank functions (Dmg / Stun / Secs ...). `Say` is a template: `{Per%}`, `{Dmg%}`, `{Stun.1}`, `{Per%+100}`, `{r}`. SkillBranches Order is re-sorted by Row and Col.
  - A dry run against live data (2026-11-18) matched exactly. The only change: the Bouncy Bolt text says "mob(s)".
- **Models:** after File → Import 3D, "Use selected" in the plugin does this:
  - Weapons: one MeshPart becomes Model `<Name>` / `Handle`, with the long side scaled to 4 studs. It warns if Y isn't the long side.
  - Pets: the parts are flattened into Model `<Species>` (biggest part = Body), scaled to 3 studs, with no Rig, so it's a BlobCritter. Face rigging is still Claude's job (RigTools).
  - Old models go to ServerStorage.OldWeaponModels / OldPetModels.
  - SunBow and RainbowBow have no WeaponModels yet (they use the stick fallback).
- **Status:** the hook is in Studio's CritterData before `return Data` (verified by checksum, compile and require). Until CK's first pull there is no GameData child, so the game still uses the Lua tables. The local CritterData.module.lua is still drifted and doesn't have the hook.
- **🏷️ Tags (weapons + pets):**
  - CK makes the tags; they're stored in `data/tags.json` as `{"weapons": ["Dagger", ...], "pets": [...]}`.
  - Each item has a `Tags` array. The list has a tag filter row: an item must have every picked tag to show.
  - The 🏷️ Edit tags window adds, renames, reorders and deletes tags, and renames or removes them on every item too.
  - Tags reach the game as `def.Tags`, but nothing in the game reads them yet. They're only for sorting in the editor.
- **↕️ List sorting:** the `SORTS` table in index.html sets the sort options for each tab: tier (rarity order), damage, damage per second, attack speed, reach, name, price and others. The ⬆/⬇ button flips the order. Sorting only changes what you see; the saved file order stays the same. Each tab's choice is kept in the browser's localStorage. Skill branch headings show only in tree order.
- **🏡 Decorations tab (2026-11-19):**
  - Data is in `data/decor.json`: Name (= ID, may have spaces), Icon, Cost {resource: n}, Effect "Water"|"Grow" with Range, and Boost (Grow only).
  - CK can add or delete decorations. The 16 built-in ones (`builtIn` in index.html) can't be deleted. The optional `Look` field is CK's idea for the shape.
  - Each shape is code: `DECOR.<NameWithoutSpaces>` in Builds. A name without one gets the 🧱 placeholder gift box (attribute `Placeholder`); see ARTSTYLE.md for how to find and build them.
  - The plugin reports the `DECOR.*` names it finds in Builds.Source as `models.decor`, so the editor can show ✅ or 🧱.
  - ApplyGameData `G.decor` takes any valid name. Built-in decorations missing from the file stay at the end of the list.
  - **In Studio since 2026-11-19:** the `G.decor` block in the CritterData hook and the Builds placeholder are both there. CraftServer reads `Head`/`Spray` safely, so a placeholder with an Effect is fine.
- **Adding a new editable table later:** export it to `data/<name>.json`, add the name to `$names` in CritterEditor.ps1, a TABS entry in index.html, a block in ApplyGameData and a CATS row in the plugin.

## 🏰 Dungeon Portal: stage 1 (2026-11-19, in Studio, not playtested yet)
CK's choices: it's a new portal called "Dungeon Portal", separate from the old Raid Gate. Build every idea, for 1–4 players, paid with ⚡ raid energy (`prof.Energy`, shared with the Raid Gate).
- **How it fits in:**
  - It reuses the Realms party, invite and buddy system. A party has `mode` "Realm"|"Dungeon" and a `tier`.
  - `ACTIONS.DungeonPick(land, tier)` picks a dungeon. `RealmEnter(mode)` checks that you're near the right portal (`DungeonPortal` or `TerrainPortal`).
  - `newRun` calls `API.buildDungeon(run)` instead of `buildMap` when the party is in dungeon mode.
  - `payEnergy` takes `Data.Dungeon.Energy` from each explorer once per run.
  - `API.realmSpawn` now returns `run.checkpoint[player]`, so fainting wakes you at your last 🔥 campfire.
  - `API.realmHooks` shares P/chip/exitPortal/treasure/runOf/bottomOffset/resOf with Dungeons.
- **Dungeons.server.lua (new):**
  - The maze is a DFS spanning tree plus `Loops` extra doorways.
  - The start is an edge room with the exit portal and a campfire.
  - The boss room is the edge room farthest from the start. The arena sits outside it, behind the 🔒 ForceField door.
  - The 🗝️ key is in the farthest room off the main path, guarded by a special mob. Taking it opens the door for the whole party.
  - 🔥 `Campfires` sit along the main path. 🧺 chests are in dead ends.
  - The boss's `Dead` attribute triggers the 🎁 boss chest and an exit portal, and sets `prof.DungeonTier[land]` (⭐ unlocks).
  - `run.noRespawn` keeps cleared rooms cleared (Combat check).
- **Data.Dungeon** lives in Studio CritterData, just before the editor hook block. The local CritterData.module.lua is drifted and has neither.
- **Synced to Studio on 2026-11-19.** Every script compiles, and these match local byte for byte (length/checksum):
  - Realms 53158/328842
  - TerrainPortal 26348/153632
  - Builds 19773/468161
  - Combat 49976/82163
  - Dungeons 24923/979303
  - CritterData is 95715/443312 (Data.Dungeon + the decor hook) and still loads.
  - FarmServer got a one-line edit (`API.updateEnergy`) and is 144296/910095; the local copy is drifted.
- **The town model:** `CritterAcres.DungeonPortal` is at (−35, 2.84, −76), facing +Z, between the Explorer's Portal and the Raid Gate. It's a stone gate with two towers, flags and a purple/gold swirl, with `Gate` (walk-in trigger) and `Out` 12 studs in front. It has a TownChips chip 🏰 "Dungeon Portal". Three flower clumps were moved off its pad.
- **Still to do:** a Dev menu button (`API.DEV_EXTRA.Dungeon(player, prof, land, tier)` already exists).
- **Later stages:**
  - 3: hidden chests behind breakable walls, a runaway chest, unique boss gear sets (2-piece bonus + glow), 📜 furniture scrolls (unlock dungeon-only decorations, scroll album, guaranteed drop), ⭐ run score, first-clear bonus.
  - 4: puzzles (torches, colour tiles, push block), levers that open secret rooms, a buddy pet that sniffs out treasure, a minimap that fills in as you explore (fog) with a glowing trail back, cute traps (slime puddles, bounce pads, snowballs), the boss's halfway trick (calls helpers).

## 🏰 Dungeons v2: zones, ledges, obby, walls block (2026-11-19, in Studio, not playtested)
- **🎨 Zones** (`Data.Dungeon.Zones[land]`, 4 per land, `Tier.Zones` used):
  - Seeds are placed by farthest-point sampling over walking distance, and each room joins its nearest seed.
  - Each zone has a floor tint `Tile`, a torch colour, small `DECO` decorations (Mushroom/Crystal/Blob/Flower/Rock) and a `MARK` landmark (BigMushroom/BigCrystal/Fountain/Pool/BigTree) in rooms with 3+ doorways (at most `D.Landmarks`).
  - A TownChips sign chip sits over the doorway into each zone's room closest to the start.
- **🪜 Ledge routes** (`Tier.Ledges`, `Tier.Route`; `D.LedgeH` = 12):
  - A route is S → … → T through linked rooms, avoiding busy rooms (start, boss, key, campfires).
  - In S the way up is either stairs (10 steps against a wall with no doorway) or 4 🦘 obby pads circling up (`Tier.Obby` chance; stairs fall back to pads if no wall is free).
  - Crossings are a plank bridge with rails, or jump pads (`Tier.Pads`).
  - T has a 12×12 ledge with a ✨ Silver chest (`D.SilverX` coins, `D.SilverCapsule`, prompt range 8 so it can't be opened from below). The only way down is to jump.
  - No mobs spawn in S (`climbRoom`).
- **Raised corner platforms** (`Tier.Daises`) with 2 steps and a decoration on top. A floor chest that would land on one goes on top.
- **🧱 Walls block:**
  - Walls, pillars and the shut boss door are in `run.folder.Walls`. `run.blocked(a, b)` is a flat raycast at floor + 3.
  - Combat checks it in `mobsNear` (every player attack and skill), in mob noticing, and in the target branch (a mob walks toward you but doesn't bonk, shoot or use specials through a wall).
  - `run.clampGoal` keeps every mob inside its own room (or the arena), and Combat's `setGoal` applies it.
  - Opening the boss door moves it out of `Walls`.
- **Checksums:** Combat 50597/136569 and Dungeons 43385/404685 match local. CritterData is 99157/708386.
- **Note:** the 🪜 emoji got mistyped as 🪷 once while pasting; it was caught by the checksum and fixed.
- **Attack-through-walls fixes, round 2 (in Studio 2026-11-19: Combat 50811/156165, Skills 13086/76758, both match local):**
  - Combat `remote.OnServerEvent` "Attack": a wand/bow shot at the clicked target (`mobs[target]`) skipped `run.blocked`. Fixed.
  - Combat buddy zap: now checks `run.blocked(cp, mob.pos)`.
  - Skills aimed AoE (MiniMeteor etc.): the impact point gets pulled back toward the player until no wall is between them.
- **Next (CK approved the idea):** rebuild dungeons as natural terrain.
  - Keep the maze graph (zones, key, boss, ledge routes, campfires), but draw rooms as irregular clearings, doorways as winding trails, and walls as steep terrain cliffs plus tree/bush lines (Realms props).
  - Ledges become plateaus with a ramp, log steps or a stepping-stone obby; the boss arena is a round clearing behind a vine/ice/crystal gate.
  - Build at ground level in the slot (Realms' wipe clears the terrain). LOS uses terrain + props; mobs are fenced to their clearing (circle).
  - CK: "some maps can have cave ceilings and some can be open sky" (per-theme flag).

## 🏰 Dungeons v3: natural terrain maps (2026-11-19, in Studio, not playtested)
CK said the square rooms looked bland, so the maps are now real terrain. **This replaces the v2 room / wall / dais geometry** (the zones, ledge routes, key, boss, campfires and chest logic are kept).
- **Layout:** the same hidden maze graph. Each cell becomes a clearing:
  - Position: grid spot (`Gap` 64) + random nudge (±17%). Radius comes from `ClearR`; start, busy and route clearings are bigger.
  - Each link is a quadratic-bezier trail sampled as 8 segments, half-width from `TrailW` (it wobbles along the way).
  - The arena is a clearing of `ArenaR` beyond the boss cell, joined by a straight-ish trail.
- **Terrain:** written in 16-column strips (VOX 4, only nearby nodes and segments are checked).
  - The distance d to open ground sets the floor (`Floor` + ±1 noise), or a cliff of `WallH` over 5 studs plus bumps.
  - Materials: path / zone `Ground` / `Cliff` / `Top`.
  - Cave themes (`Theme.Cave`: Slime Cave, Crystal Mines, Lava Keep) get a `Ceil` rock ceiling from `CaveH` up wherever d < 12.
  - An invisible `Lid` part at `Floor + LidH` (21) stops anyone climbing over the cliffs (CaveH must stay above it).
- **Placing things:** `ground(p)` raycasts the terrain from `Floor + CaveH - 2`.
  - Barricades are `Theme.Edge` props (RealmProps via `R.placeProp`) around each clearing's rim and along trail sides.
  - Open-sky maps get `Theme.Trees` on the cliff tops (`D.Trees` count).
  - Lanterns sit at clearing edges (3 in caves), in the zone colour.
- **Ledges:**
  - S has a rock pillar (`PillarMat`) to height `LedgeH` (10), reached by 11 spiral stone steps or 4 obby pads.
  - Plank-and-rope bridges or pads follow the trail curve at ledge height; middle clearings get small pillars.
  - T has a 6.5-radius pillar with the ✨ Silver chest (prompt range 7).
- **Boss gate:** a `Theme.Gate` part across the arena trail (in `run.folder.Blockers`). The key tweens it into the ground and removes it.
- **Combat hooks:**
  - `run.blocked` raycasts Terrain + Blockers at `Floor + 3.5`.
  - `run.clampGoal` keeps each mob within its nearest clearing's circle.
  - Combat `dropStar` raycasts from just above the mob in dungeons, so cave ceilings don't catch stars.
- **Realms hooks** now also share `placeProp`, `template` and `glowColors`.
- **Data.Dungeon** (CritterData 101541/910601) has new fields: Gap, ClearR, TrailW, ArenaR, Floor, WallH, LidH, CaveH, LedgeH, Trees, plus per-theme terrain materials, Edge/Trees/Gate/Pillar and per-zone Ground. The old Cell/Wall/Door/Y/Arena W×D fields are gone. A local mirror of the block is in `CritterData.dungeon.lua`.
- **Checksums:** Dungeons 48964/824562, Realms 53222/334400 and Combat 50937/167427 all match local.

## 🛡️ Hero Gear: player gear slots (2026-11-19)
CK paused the dungeon work to add player gear first (stage 3 boss sets need it).
- **6 slots:** Head, Body, Legs, Boots, MainHand (= the weapon, still `prof.WeaponOn` in Combat), OffHand (shields).
- **Data** (`CritterData.herogear.lua`, inserted into CritterData just before the GameData hook block):
  - `Data.HeroSlots` / `HeroSlotById`, `HeroGear` (30 pieces: Leaf/Stone/Iron crafted, Gold/Crystal/Magma boss-only with `Set`), `HeroGearByName`
  - `HeroGearPwr` (⚡ per rarity), `HeroSlotBonus` (HP / Def / Spd per rarity step), `HeroDefCap` 0.4, stars (max 5, +10%), `HeroGearMaxedCoins`
  - `HeroGearCraft` + `HeroSlotCostMult` → `Data.HeroCraftCost(def)`; `HeroGearDrop` (Boss 0.25, Dungeon 1, tiers per land)
  - `HeroSets` (2 / 4 piece bonus Pwr% / HP%, Glow color at 4), `HeroLooks` (colors/material/Extra per look), `HeroCosmetics` (Bunny Hood, Candy Shield samples)
  - `Data.HeroGearStats(g)` → {Pwr, HP, Def, Spd}; `Data.HeroGearText(st)`
- **Server** `ServerScriptService.HeroGear` (HeroGear.server.lua):
  - prof.HeroGear {{Id, Name, Stars}}, HeroGearNext, HeroGearOn {[slot]=Id}, Cosmetics {[name]=true}, CosmeticOn {[slot]=name}
  - `API.heroGearStats(player)` (cached totals: Pwr, PwrPct, HP, Def, Spd, Sets, Glow), `API.giveHeroGear`, `API.heroGearDrop(land, dungeon)`, `API.weaponSkin`
  - Actions GearInfo, GearEquip(id), GearOff(slot), GearCraft(name), LookWear(slot, name|"")
  - Part-built pieces welded to the R15 body (folder `HeroGearLook` in the character; rough R6 fallback). A 👗 look beats the gear's own look. Helmets hide hat/hair accessories. A full 4-piece set adds sparkles + light (`SetGlow` attachment on UpperTorso).
  - Re-dresses when body parts / accessories get added (avatar loading).
  - Dev extras: HeroGearAll, HeroGearBoss(tier), HeroLooks, HeroGearReset.
- **Combat.server:** `gearOf(player)`; pwrOf adds gear Pwr then × (1 + PwrPct); maxHpOf adds gear HP; hurt × (1 − Def); attackPower adds gear Pwr; giveTool uses `API.weaponSkin`; bosses drop `{Type = "Gear"}` stars (collectStar gives it + notifyAll when new); exports `API.combatGiveTool`.
- **Skills.server:** applySpeed multiplies Quick Feet by (1 + gear Spd) in the lands.
- **Client** `StarterPlayerScripts.HeroGear` (HeroGear.client.lua): 🛡️ Gear window on **G**, tabs 🧍 Wearing / 🎒 My gear / 🔨 Craft / 👗 Looks. The Main hand card opens the ⚔️ Weapons window (bridge "Weapons"); opening Gear fires "WeaponsClose".
- **Combat.client:** its G key handler was removed (G = Gear now); bridge "WeaponsClose" closes the weapons window.
- **CritterMenus:** the dock "Weapons" button is now 🛡️ Gear and fires bridge "Gear" (key stays "Weapons" in dockButtons).
- **DevMenu:** Weapons tab has 🛡️ All gear / 🟡 Gold set / 🔥 Magma set / 👗 All looks / 🧹 Clear gear.

## ▶ Where we left off (2026-11-19)
- **In Studio and checked by checksum + compile; CK still has to playtest:**
  - Dungeons v3 (natural terrain)
  - attack-through-walls fixes (clicked wand/bow target, buddy zaps, aimed skills)
  - the 🏰 Dungeon Portal model in town
  - Critter Editor 🏡 Decorations tab + 🧱 placeholder box
- **CK still needs to:**
  - save the place (File > Save to Roblox)
  - restart Studio once (the CritterSync plugin changed)
  - playtest a cave dungeon (🟢 Slime Cave) and an open-sky one (🌲 Root Tunnels)
- **🛡️ Hero Gear** (section above) is the current work. CK approved a NEW Gear window design (paper-doll + browser-tab inventory): **GEAR-UI.md**. Built and in Studio (see "Gear window rebuild" below); waiting for CK to playtest.
- **After that:** Dungeon stage 3, starting with ⚔️ boss gear sets + 📜 furniture scrolls. Full list in TO-DEVELOP.md "🏰 Dungeon Portal".
- **Editor helper:** `CritterEditor.ps1` serves `$names` weapons, pets, eggs, capsules, skills, decor, tags. After changing `$names`, the running helper window must be restarted (an old one answers "not found").
- **Docs:** ARTSTYLE.md holds the part-built art rules (read it before building decorations); CLAUDE.md points to it.

## ✅ Gear window rebuild (2026-11-19): IN STUDIO (pushed 2026-11-19, each verified by length + checksum + compile)
CK's decisions: crafting only at the 🔨 Workbench; the G window has one tab "🧍 Character" (an "👗 Outfits" tab with the same layout comes later); 🎁 Capsules stay in the old Weapons window, reached by a button in the Weapon tab.
Pushed by line splice (Studio's old copies differed from local only by these changes). Studio = local for all five:
- HeroGear.client.lua 18662/513799 (avatar framing 0.85 -> 1.2 for a roomier margin): full rewrite to the GEAR-UI.md layout (avatar ViewportFrame + body-aligned slots, browser tabs, Weapon tab equips weapons via WeaponEquip)
- HeroGear.server.lua 23061/866571: GearInfo adds Weapons + WeaponOn; GearCraft refuses farther than Data.HeroCraftReach from root.Workbench.Table
- CritterData.herogear.lua 10104/805752: adds `Data.HeroCraftReach = 24`. In Studio the hero gear block matches this file (whole CritterData now 112425/785800)
- Combat.client.lua 39365/185350: bridge "Capsules" opens the weapons window on the Caps tab
- CritterWorld.client.lua 64247/155808: Workbench gets a "🧍 Hero gear" tab (Leaf/Stone/Iron, GearCraft)
