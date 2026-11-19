# 🎨 Critter Acres art style

Read this instead of re-reading `Builds` every time. It covers part-built models: decorations and crops (`ReplicatedStorage.Builds`, mirror `Builds.module.lua`).
Creatures and the UI have their own rules, summarized at the bottom.

## The feel
- A cozy toy farm for kids aged 6 and up: **chunky, round, bright, friendly**. It should read in one glance from far away.
- Few big shapes beat many small ones. Most decorations are **4–20 parts**.
- **Round things are good:** balls, eggs (sphere-mesh blocks) and discs. Use plain boxes for planks, posts and bases.
- Nothing scary, sharp or dark-themed. Even "Lava Lamp" is cute.
- Fully 3D: it should look good from every side (players turn decorations with R), not like a flat cutout.

## How a decoration is built (code)
- In `Builds`, add `function DECOR.<NameWithoutSpaces>(m)`. For example "Mushroom House" becomes `DECOR.MushroomHouse`.
  - `Builds.Decor(name)` makes the model and calls it.
  - A name with no function gets the 🧱 **placeholder gift box** (model attribute `Placeholder = true`).
- **Real size in studs**, sitting on **y = 0**, centered on x/z = 0. The invisible PrimaryPart `Base` is already at the bottom center.
- **Front = −Z.** The door of Mushroom House, the snowman's nose and the windmill hub all face −Z.
- Helpers, all anchored, non-colliding, massless and SmoothPlastic unless props say otherwise:
  - `p(m, props)`: a box
  - `ball(m, props)`: a sphere
  - `egg(m, props)`: an ellipsoid (a block with a sphere mesh, sized by `Size`)
  - `disc(m, cf, height, diameter, props)`: a cylinder **standing up**. To lay it on its side, add `* CFrame.Angles(0, 0, math.pi/2)`.
  - `leaves(m, y, n, size, color)`: a ring of leaf eggs
  - `stem(m, y, h, color)`: a thin brown stick
  - Shared colors: `wood` (190,140,90), `dark` (120,85,55), `GREEN` (80,170,70).
- **Collisions:** set `CanCollide = true` only on the main body (trunk, base, box), so players can bump into it. Leave the rest off.
- **Footprint:** 1–6.5 studs wide (Pond 6.5, Fountain 6, Bench/Fence/Flower Bed 4, Lamp 1.4).
  - Height goes from 0.6 (Pond) to about 9 (Windmill, Oak Tree).
  - A farm plot is about 8 studs, so keep things smaller than one plot.

## Colors and materials
- **Saturated, cheerful colors.** Use RGB values like (255,110,160) pink, (255,230,90) yellow, (170,120,255) purple, (90,180,255) water blue, (230,70,70) mushroom red and (255,200,50) gold.
  - Avoid grey-on-grey. Every decoration needs at least one bright accent.
- **Materials** (most parts stay SmoothPlastic, with a material only where it helps):
  - Wood / WoodPlanks: beds, benches, windmill
  - Grass: tree leaves
  - Marble: fountain, statue base
  - Slate / Basalt: stone rims, lamp bases
  - Metal: lamp post, sprinkler (Reflectance 0.3 for gold)
  - Snow: snowman
  - Fabric: hay
  - Glass with Transparency 0.2–0.25: water
- **Glow = `Neon` + a `PointLight`** (Range 12–16, warm or matching color): Lamp Post, Crystal Lamp, Lava Lamp.
- **Life:**
  - `ParticleEmitter`s for water, bees and sparkles. Keep the Rate low (4–40) and make the effect small.
  - Attribute `Spin = true` makes the server turn blades or heads (Windmill parts named `Blade`, Sprinkler `Head`).

## Checklist for a new decoration
1. Is it readable from far away? One big main shape with 1–2 accent colors.
2. Does it sit on y = 0, centered, at a size from the footprint table above?
3. Is `CanCollide` set only on the body?
4. Does it look right from all sides and face −Z?
5. Is it under about 25 parts?
6. Does its emoji `Icon` in the editor match it?
7. If it waters plants (Effect Water), give it a `Head` part and the Spray emitter like Sprinkler, so the server can spray from it.

## 🧱 Finding decorations that still use the placeholder
- The editor (🏡 tab) shows 🧱 on them, once the CritterSync plugin has reported to it.
- For Claude, there are two ways:
  - Compare the names in `editor/data/decor.json` (spaces removed) with `script_grep "function DECOR%."` on Studio's Builds. Any name with no function is a placeholder.
  - Or run Luau in Edit mode: `Builds.Decor(name):GetAttribute("Placeholder")` for each name in `Data.Decor`.
- Build them in one batch. The `Look` field in decor.json, if CK filled it, says what they want.

## Other art rules (details in CLAUDE.md / memory)
- **Creatures:**
  - Fully 3D: depth at least about 70% of width.
  - Movable parts with animation, plus a face that animates (eyes that blink and look around, a mouth that opens).
  - Generate them with `generate_mesh` (explicit segmentation, short prompts, at most 2 jobs at once).
  - See RESUME.md for the pet rig pipeline.
- **UI:**
  - Always the `UIKit` look: cream rounded windows, white cards, colored buttons, tooltips.
  - Icons always come with short words.
  - 💰 for coins (🪙 doesn't render).
- **In-world signs:** TownChips chips, which are an invisible Part with `Icon` + `Label` attributes. Never billboards or wooden boards.
