# Critter Acres: UI plan (draft, not built)

Goal: a 6-year-old should know what every button does without guessing.
Rules: one place for each kind of thing, an icon always next to a word, the same look everywhere,
and every button explains itself when you hover or hold it.

## 1. What's wrong now
- Buttons in 6 different places: top-left panel, right menu, two bottom-left rows, bottom-right buddy bar,
  and two right-side chip stacks.
- Each script draws its own style of window, button and colours.
- Many buttons are icon-only or use short codes ("🎡 0", "⏸", "🔁").
- Locked or unaffordable buttons just look grey, with no reason given.
- New things (mail, gifts, quests) are scattered chips instead of one list.

## 2. New screen layout (4 zones)
```
┌──────────────────────────────────────────────────────────────┐
│ [⭐ Lv 4 ▓▓▓░░]  [💰 1,250]  [🐾 12]  [💪 3,400]    [🔔 3]  [⚙️] │  ← TOP BAR
│                                                              │
│  (event banner appears here when something is happening)     │
│                                                              │
│                                                              │
│                       GAME WORLD                    [🌱 seeds]│  ← SEED TRAY (right,
│                                                     [ chips  ]│     only on your farm)
│                                                              │
│ [buddy 🐶 Pet | Trick | Fetch | Ride]                         │  ← BUDDY (only when
│                                                              │     you have a buddy)
│  [🐾 Pets] [🏡 Farm] [🗺️ World] [🛒 Shop] [🎒 Bag]            │  ← BOTTOM DOCK
└──────────────────────────────────────────────────────────────┘
```
- **Top bar:** level with its XP bar, coins, pets, Farm Power. On the right are 🔔 Things to do (count badge) and ⚙️ (Titles, Dev in Studio).
- **Bottom dock:** 5 big buttons, always in the same place. Each one opens a window with tabs:

| Dock button | Tabs inside |
|---|---|
| 🐾 Pets | My Pets · Eggs · 💕 Nest · 📖 Book |
| 🏡 Farm | Decorate · Soil & plots · 🌙 Moon Pot info |
| 🗺️ World | Map & travel · Farms (visit / likes) · 🎣 Fish book · Events |
| 🛒 Shop | Seeds · Packs · Seed Book |
| 🎒 Bag | Resources · Gear · Toys · Fish |

- **🔔 Things to do** replaces all the right-side chips: journey step, gift ready, daily box, mail, quest rewards, eggs ready, helper rewards. Each row has one button ("Open", "Go there", "Claim").
- **Seed tray:** only shows while you're on your own farm.
- **Buddy bar:** only shows when you have a 👣 buddy.
- **Toys:** move into the Bag (Toys tab) plus one quick 🫧 button.
- **Trade / Gift:** become buttons on each player in World → Farms.

## 3. Tooltips (hover on PC, hold on phone/tablet)
- Every button, chip, seed, resource, gear and prize gets a small bubble:
  **Name** + one short line, e.g. "💕 Nest: two pets make a Friend Egg (they both stay!)".
- PC: shows after 0.3 s of hovering. Touch: press and hold 0.4 s (a short tap still works as a click).
- The bubble sits above the finger or mouse and never goes off screen.
- One shared Tooltip module, so every script uses the same one (`Tooltip.Add(button, title, text)`).

## 4. One look for everything (UIKit module)
- **Windows:** same frame, title + short subtitle, tabs under the title, ✖ in the same corner, ❓ help button.
- **Buttons:**
  - green = do it
  - yellow = special or free
  - red = careful (send to wild, cancel)
  - grey = can't yet
- **Can't yet = say why:** "🔒 Farm Lv 5" or "Need 3 more ⚙️ Iron", never just grey.
- **Words always:** icon + 1–3 words on every button. Numbers get a label ("x5 seeds", "⏱ 2:30 left").
- **Cards:** picture on top, name, a one-line effect and the main button at the bottom, in the same layout everywhere.
- **Rarity colours** (Common grey, Rare blue, Epic purple, Legendary gold) stay as they are, plus the word on the card.
- **Text:** bigger minimum text size (no tiny 12 px text), short sentences, no codes like ⏸ or 🔁 without words.

## 5. Explain-as-you-go
- **❓ on every window:** opens 3 picture steps on how it works (e.g. Nest: pick 2 pets → wait or cheer → hatch the egg).
- **First-time pointer:** the first time you open a window, a bouncing 👆 points at its main button once.
- **Red dot** on a dock button or tab when something new is inside (new hat, egg ready, reward to claim).
- **Empty states tell you what to do:** "No gear yet → make some in Bag → Gear, or win ⚔️ raids".

## 6. Feedback (every tap does something visible)
- Buttons squish when pressed and play a soft click.
- Success shows a green toast with a ✔; problems show an orange toast that says what to do next.
- Rewards fly into the top bar (coins already do this; add pets, eggs and seeds).

## 7. Phone and tablet
- Dock buttons at least 64 px, tap targets at least 48 px.
- Windows fill the screen on phones, centred cards on PC.
- No hover-only information: everything in a tooltip also shows when you hold the button.

## 8. Build order
1. UIKit + Tooltip modules (shared look, tooltips everywhere).
2. Top bar + bottom dock + 🔔 Things to do (move the existing buttons, remove the chip stacks).
3. Restyle the windows onto UIKit with subtitles, ❓ help and "why it's locked" buttons.
4. First-time pointers, red dots, empty states.
5. Phone check (layout at 375 px wide).

## 9. Not changing
- The tap-to-open card reveal, the power-up screen layout and the 3D pet portraits.
- How things are earned (only where buttons live and how they explain themselves).

## 10. Minimal version (CK wants minimal clutter) - this replaces the zones in section 2
Only 5 things on screen:
1. Top left: ⭐ level + XP bar, 💰 coins.
2. Top right: 🔔 To do (count badge). It opens the list (journey, gifts, daily box, mail, eggs, rewards).
3. Bottom: 4-button dock: 🐾 Pets · 🏡 Farm · 🗺️ World · 🛒 Shop.
4. Bottom right, only on your farm: one seed button showing the seed you're planting (tap to pick another).
5. Your buddy pet: tap it in the world for Pet / Fetch / Ride (no buddy bar).
Moved off the screen:
- Pet count, Farm Power → Pets window header.
- Bag (resources, gear, toys, fish) → Farm and Pets tabs; toys → Farm → Toys.
- Map, travel, farms, trade, gift, fishing book, events → World.
- Titles, dev menu → ⚙️ inside the To do panel.
- Right-side chips (luck, friends, rare fruit, acorns, lucky hour) → the To do list or a short toast when they change.
- The event banner shows only while an event is on.

## 11. Revamped menus (all use the same window)
Every window: icon + title + one-line subtitle, tabs, ❓ help and ✖ in the top right. One list or grid per tab.
Buttons: green = do it, grey = can't yet, and the grey button says why ("Need 4 more wood", "Locked: Lv 8", "Sold out").
- **🔔 To do** (also the new quest menu): Ready now (gifts, eggs, mail, rewards, each with Open / Hatch / Go there) ·
  Daily quests (progress bar + count, the reward shown on the button, then "Claim" when done, refresh timer + streak) ·
  Helpers (Fern, Pip, Bun quest chains) · Journey. ⚙️ inside holds Titles and Dev.
- **🐾 Pets**: header shows pets, farm space, Power. Tabs: My pets (On farm / Storage filter, sort) · Eggs · Nest · Gear · Book.
  Pet cards: picture, name, level, rarity colour, one status word (working, napping, in nest). The last card is "Get more".
- **🏡 Farm**: Decorate (owned = Place, else Buy price, or why you can't) · Plots and soil · Bag (resources) · Toys.
- **🗺️ World**: Places (what you find there + Go / Open gate / Locked) · Farms (visit, like, trade, gift) · Fish book · Events.
- **🛒 Shop**: restock timer in the subtitle. Seeds (stock left, grow time, Buy price) · Packs · Seed book.
