# Roblox Game workspace: notes for Claude

This folder holds CK's Roblox game, Critter Acres (cleaned up 2026-11-17: only this game's files are kept). Claude works on them through the **Roblox_Studio MCP server**. Studio must be open with the place loaded. Call `list_roblox_studios` for the current studio_id; it changes whenever Studio reopens.

- `critter-acres/`: **the main active project.** It's a cozy farm + pet-collecting game for kids aged 6 and up. **Read `critter-acres/RESUME.md` first.** It is the full handoff doc: what's built, where every script and model lives, how to sync, and any unfinished work at the bottom.
- The game lives only on Roblox: the **Pet & Garden** place (placeId 114697838270002). CK opens it from Roblox, not from a file; there is no local .rbxl copy (removed 2026-11-17 after CK published it there).
- Old backups and the one-time world builder scripts were deleted; they are still in git history (commit ec1e4e2).

## How CK wants Claude to work
- **No self-testing.** Don't start or stop playtests, take screenshots, or run verification scripts. Push the change (a compile check is fine), then end with a short **"what to check"** list for CK. Ask before stopping CK's playtest.
- Script edits and `generate_mesh` need Edit mode.
- **Studio is the source of truth.** Local `.lua` files are mirrors, and some have drifted (see RESUME.md). Sync carefully:
  - Use find/replace for small changes, or a full paste.
  - Always verify with a byte-length + checksum match and `loadstring(src) ~= nil`.
- After a big change, remind CK to save the place (File > Save to Roblox).
- Keep `critter-acres/RESUME.md` up to date at the end of every pass. Add CK's new ideas to `critter-acres/TO-DEVELOP.md`.

## Design rules for Critter Acres
- **Before building any part-built model (decorations, crops), read `critter-acres/ARTSTYLE.md`.** It covers the shapes, colors, sizes, the Builds helpers and how to find 🧱 placeholder decorations.
- **Players:** kids aged 6 and up.
  - Big, colorful, easy to tell apart.
  - Icons always come with **short words** (no icon-only UI, no long sentences).
  - Nothing scary; fainting is cute and costs nothing.
- **RNG:** no paid RNG. RNG paid with in-game coins is fine. Pets come only from eggs; land mobs are never tamable.
- **Originality:** original work only; never recreate an existing game.
- **Every GUI** uses the shared `ReplicatedStorage.UIKit` look: cream rounded windows, white cards, colored buttons, tooltips.
- **In-world signs** are TownChips chips: an invisible Part with `Icon` + `Label` attributes. No billboards or wooden boards.
- **Creature models:**
  - **Fully 3D:** depth should be at least about 70% of width; check the bounding box after generating.
  - **Movable parts** with animation and **facial animation** (eyes that blink and look around, a mouth that opens).
  - Generate with explicit segmentation. Run at most **2 `generate_mesh` jobs at once**, and keep prompts short to pass moderation.
- **Emoji:** use 💰 for coins; 🪙 doesn't render in Roblox.
- **Code layout:** put new server systems in their own scripts and share functions through `ServerScriptService.CritterAPI`; FarmServer is already about 100k characters. All tuning numbers go in `ReplicatedStorage.CritterData`.
- **Hotkeys in use:**
  - B Bag, P Pets, M World, G Gear (🛡️ Hero Gear window; ⚔️ Weapons opens from its Main hand slot), K Skill tree, V Buddy mode, Ctrl Mouse look.
  - In the wild lands: 1-5 use the ⚡ skill bar moves of the weapon in your hand (only there; Decorate mode uses 1-9 on the farm). Q and R are free in the lands again.
  - Decorate mode: 1-9, R, E, X, G, Q, N. While it is open the player attribute `Decorating` is set; other key handlers must ignore build keys then.
  - Pick a free key for anything new.
