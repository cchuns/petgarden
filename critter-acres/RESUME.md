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
  - `Build*.lua`, `Dress*.lua`, `Builder.lua`, `FountainFX.lua` are one-time world builders run with execute_luau in Edit mode.
- **Key modules:**
  - CritterData: all tuning numbers.
  - UIKit: the shared GUI look; every window uses it.
  - CritterUI: 3D portraits.
  - PackOpen: tap-to-open reveals.
  - Builds: crop and decoration shapes.
  - CritterAPI: the shared server table (`API.*`), so new server systems live in their own scripts. FarmServer is about 100k characters; don't grow it.
- **Server scripts:** FarmServer, ShopServer, CraftServer, FunServer, PetLife, Hooks, Adventure, WorldEvents, Realms (the terrain-portal lands), Combat, Portals, BoutiqueServer.
- **Client scripts:** CritterHUD (old screens and the Dev menu), CritterMenus (the main minimal UI), CritterPlay, CritterWorld, CritterHooks, CritterSocial, CritterAnimator (pets), MobAnimator (land mobs), Combat, TerrainPortal, MouseLook, ExpeditionBooth, RaidGate.
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

## Camera, buddy modes, loot stars pass (2026-11-17), LOCAL ONLY, NOT YET IN STUDIO
CK's request:
- the camera follows the mouse
- mobs don't teleport when hit
- the buddy pet has a Passive/Aggressive toggle
- mob drops are glowing stars; you see what's inside only when you collect one
- pets auto-collect stars, upgradable later

All of this is coded in the local files but **not synced to Studio yet**. To sync it:
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
