# 🛡️ Gear window: approved draft (CK, 2026-11-19)

This replaces the current tabbed Gear window (HeroGear.client.lua: 🧍 Wearing / 🎒 My gear / 🔨 Craft / 👗 Looks).
It's draft 4 from chat: the paper-doll on the left, the inventory with browser-style tabs on the right. Built 2026-11-19 (HeroGear.client).

## Layout (one UIKit window, key G / dock 🛡️ Gear)
```
┌─ 🛡️ Gear ───────────────────────────── [❤️ 815 HP] [🛡️ 12%] [⚡ 139 PWR] ─┐
│ ┌──── left: you ────────┐  ┌Head┐┌Body┐╔Legs╗┌Boots┐┌Weapon┐┌Shield┐      │
│ │[Head]  ·····  (head)  │  ╔══════╝    ╚══════════════════════════════╗  │
│ │[Body]  ·····  (chest) │  ║ Legs · 3 owned                           ║  │
│ │               [Weapon]│  ║ ┌────────┐ ┌────────┐ ┌────────┐         ║  │
│ │      3D avatar        │  ║ │ Iron   │ │ Stone  │ │ Leaf   │         ║  │
│ │[Legs]  ·····  (legs)  │  ║ │Leggings│ │Leggings│ │ Pants  │         ║  │
│ │             [Off hand]│  ║ │PWR+3   │ │PWR+2   │ │PWR+1   │         ║  │
│ │[Boots] ·····  (feet)  │  ║ │ [Wear] │ │ [Wear] │ │ [Wear] │         ║  │
│ │   ⟲ drag to spin      │  ║ └────────┘ └────────┘ └────────┘         ║  │
│ └───────────────────────┘  ╚══════════════════════════════════════════╝  │
└──────────────────────────────────────────────────────────────────────────┘
```

## Top bar
- Title "🛡️ Gear" on the left.
- Stat chips on the right: ❤️ HP (max), 🛡️ less hurt %, ⚡ PWR. They update live (attribute PWR / HPMax).
- No window tabs (the inventory has its own tabs).

## Left panel: you
- A ViewportFrame with a clone of the player's own avatar, wearing their gear (HeroGearLook) and looks. Drag to spin (⟲ hint at the bottom).
- Slot cards sit next to the body part they belong to, with a dotted line to it:
  - Left column, top to bottom: **Head** (by the head), **Body** (by the chest), **Legs** (by the legs), **Boots** (at the bottom, by the feet).
  - Right column at hand height: **Weapon** (main hand), **Off hand** (shield) just below it.
- Slot card: small dark label tag on top (Head, Body…), the item icon, the item name. The frame is the rarity color.
- Empty slot: dashed frame, ➕ icon, "Empty".
- Tapping a slot (empty or not) opens that slot's inventory tab and highlights the slot (yellow outline).

## Right panel: inventory
- **Browser-style tabs** sit on top of the panel: rounded top corners, an icon + short word each:
  🪖 Head · 👕 Body · 👖 Legs · 👢 Boots · ⚔️ Weapon · 🛡️ Shield
  - Unselected: beige, a bit shorter. Selected: white, taller, yellow border, joined to the white panel under it (no line between).
- Panel title: "<Slot> · N owned".
- A grid of item cards (3 across), strongest first, only items for that slot:
  - rarity-colored frame, icon, name, stats line ("PWR +3 · HP +9%", boots show speed, shields show less hurt), ⭐ stars
  - button: green **Wear**, or yellow **Wearing** on the one you have on (tapping Wearing takes it off, except Weapon)
- The Weapon tab lists your weapons (equipping = the old Weapons window's Equip).

## Still to decide (asked CK, no answer yet)
- 🔨 crafting gear: move to the plaza 🔨 Workbench?
- 👗 looks (cosmetics): a 7th tab?
- 🎁 capsules: a button in the Weapon tab?
