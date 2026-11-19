-- Critter Acres: DevMenu (StarterPlayerScripts LocalScript) -- Studio only
-- 🛠 The test tools in one UIKit window with tabs (opened by the 🛠 Dev button through CritterUIBridge "Dev").
--   ⚔️ Hero: Hero Level up/down/set, XP, full HP, no damage, Q/R ready, max skills, jump into a land.
--   🗡️ Weapons: every weapon by branch (🗡️ Melee / 🏹 Range / 🔮 Mage) -> put it in your hand, or give a whole branch.
--   💰 Stuff, 🌱 Farm, 🐾 Pets, 🌠 Events, ♻️ Save: the older dev buttons, sorted.
-- Every button calls the CritterAction "Dev" action (FarmServer DEV + API.DEV_EXTRA); the server refuses outside Studio.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local K = require(ReplicatedStorage:WaitForChild("UIKit"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))
local actionFn = ReplicatedStorage:WaitForChild("CritterAction")
local bridge = ReplicatedStorage:WaitForChild("CritterUIBridge")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "DevMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 9
gui.Parent = player:WaitForChild("PlayerGui")

local win = K.window(gui, {Icon = "🛠", Title = "Dev menu", Max = Vector2.new(940, 640)})
win.setSub("Test tools · Studio only")
local tab = "Hero"
local render

local function dev(cmd, arg)
	task.spawn(function()
		local ok, msg = pcall(function() return actionFn:InvokeServer("Dev", cmd, arg) end)
		if ok and type(msg) == "string" then K.toast(gui, msg) end
		if not ok then K.toast(gui, "⚠️ " .. tostring(msg), false) end
	end)
end

---------------------------------------------------------------- building blocks
local order = 0
local function nextOrder() order += 1 return order end
-- a titled group of buttons: btns = {{text, cmd, arg, kind, tip}}
local function group(title, sub, btns, cell)
	K.header(win.body, title, nextOrder(), sub)
	local g = K.grid(win.body, cell or UDim2.fromOffset(196, 50), nextOrder())
	for i, b in btns do
		K.button(g, {Text = b[1], LayoutOrder = i, Kind = b[4] or "plain", Max = 19, Tip = b[5] and b[1] or nil, TipText = b[5]},
			function() dev(b[2], b[3]) end)
	end
	return g
end
local function stat(parent, icon, word, value, color)
	local f = K.frame(parent, {BackgroundColor3 = color:Lerp(K.WHITE, 0.7)})
	K.round(f, 14)
	K.stroke(f, color, 2)
	K.text(f, {Text = icon .. " " .. word, Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0.4, 0), TextColor3 = K.SOFT, Max = 16})
	K.text(f, {Text = value, Position = UDim2.new(0, 6, 0.42, 0), Size = UDim2.new(1, -12, 0.55, -4), Max = 28})
	return f
end

---------------------------------------------------------------- tabs
local TABS = {
	{"Hero", "⚔️ Hero"}, {"Weapons", "🗡️ Weapons"}, {"Stuff", "💰 Stuff"}, {"Farm", "🌱 Farm"},
	{"Pets", "🐾 Pets"}, {"Events", "🌠 Events"}, {"Save", "♻️ Save"},
}
local PAGES = {}

PAGES.Hero = function()
	-- live numbers at the top
	local strip = K.grid(win.body, UDim2.fromOffset(160, 74), nextOrder())
	local a = function(n, d) return player:GetAttribute(n) or d end
	stat(strip, "⚔️", "Hero Lv", ("%d / %d"):format(a("HeroLv", 1), Data.HeroMax), Color3.fromRGB(240, 140, 110)).LayoutOrder = 1
	stat(strip, "⚡", "PWR", tostring(a("PWR", 0)), Color3.fromRGB(255, 190, 60)).LayoutOrder = 2
	stat(strip, "❤️", "HP", ("%d / %d"):format(a("HP", 0), a("HPMax", 0)), Color3.fromRGB(240, 110, 120)).LayoutOrder = 3
	stat(strip, "🌳", "Skill pts", tostring(a("SkillPts", 0)), Color3.fromRGB(110, 200, 95)).LayoutOrder = 4
	stat(strip, "🛡️", "No damage", a("DevGod", false) and "ON" or "off", Color3.fromRGB(120, 175, 245)).LayoutOrder = 5

	group("⚔️ Hero Level", "Each level = +1 skill point", {
		{"➖ Lv -1", "Hero", "-1", "careful"}, {"➕ Lv +1", "Hero", "+1", "go"}, {"⏫ Lv +5", "Hero", "+5", "go"},
		{"⏫ Lv +10", "Hero", "+10", "go"}, {"Lv 1", "Hero", 1}, {"Lv 10", "Hero", 10}, {"Lv 25 · ⚡ moves", "Hero", 25, "special", "The first ⚡ moves open at Lv 25"},
		{"Lv 40 · big moves", "Hero", 40, "special", "Big moves open at Lv 40"}, {"⭐ Lv 50 (max)", "Hero", Data.HeroMax, "special"},
		{"📈 XP almost full", "HeroXp", nil, nil, "Beat one mob to see the level-up banner"},
	})
	group("🌳 Skills", nil, {
		{"🌳 Max every skill", "SkillsMax", nil, "special", "Hero Lv 50 + every skill maxed"},
		{"⚡ Moves ready now", "SkillCd", nil, "go", "Clears every move cooldown"},
	})
	K.button(win.body, {Text = "♻️ Reset skills (free)", Size = UDim2.fromOffset(196, 50),
		LayoutOrder = nextOrder(), Kind = "careful", Max = 19}, function()
		task.spawn(function()
			actionFn:InvokeServer("SkillReset")
			K.toast(gui, "🌳 Skill points back")
		end)
	end)
	group("❤️ Fighting", nil, {
		{"❤️ Full HP", "FullHp", nil, "go"}, {"🛡️ No damage on/off", "God", nil, "special", "Mobs can't hurt you"},
		{"🎁 +3 every capsule", "Capsules"},
	})
	local lands = {}
	for _, b in Data.Biomes do
		local lv = Data.LandLevels[b.Name]
		table.insert(lands, {("%s %s  Lv %d-%d"):format(b.Icon, b.Name, lv and lv[1] or 1, lv and lv[2] or 1), "Realm", b.Name, nil, "Jump straight into a fresh map"})
	end
	table.insert(lands, {"🔓 Open all gates", "Gates"})
	group("🌀 Go to a land", nil, lands, UDim2.fromOffset(240, 50))
	-- 🏰 dungeons: jump in (no energy), or open them all
	local dun = {
		{"🔓 Open all dungeons", "DungeonsAll", nil, "special", "Every dungeon at every ⭐, no farm level needed, full ⚡"},
		{"🔒 Reset dungeon stars", "DungeonsReset", nil, "careful", "Back to a new player's dungeons"},
		{"📜 All scrolls", "Scrolls", nil, "go", "Unlock every dungeon decoration"},
		{"📜 Clear scrolls", "ScrollsReset", nil, "careful"},
		{"🟢 Slime set on", "HeroGearBoss", "Slime"}, {"🐉 Dragon set on", "HeroGearBoss", "Dragon", "special"},
	}
	for _, b in Data.Biomes do
		local th = Data.Dungeon and Data.Dungeon.Themes[b.Name]
		if th then
			for tier = 1, #Data.Dungeon.Tiers do
				table.insert(dun, {("%s %s ⭐%d"):format(th.Icon, th.Name, tier), "Dungeon", b.Name .. ":" .. tier, nil, "Jump straight into a fresh dungeon (no ⚡)"})
			end
		end
	end
	group("🏰 Dungeons", nil, dun, UDim2.fromOffset(240, 50))
end

PAGES.Weapons = function()
	group("🎁 Quick give", nil, {
		{"🗡️ All Melee", "WeaponsOf", "Melee"}, {"🏹 All Range", "WeaponsOf", "Range"}, {"🔮 All Mage", "WeaponsOf", "Magic"},
		{"✨ Every weapon", "WeaponsOf", nil, "special"}, {"⭐ Max stars in hand", "WeaponStars", nil, "special"},
		{"🎁 +3 every capsule", "Capsules"},
		{"🛡️ All hero gear", "HeroGearAll", nil, "go"}, {"🟡 Gold set on", "HeroGearBoss", "Gold", "special"}, {"🔥 Magma set on", "HeroGearBoss", "Magma", "special"},
		{"👗 All looks", "HeroLooks"}, {"🧹 Clear hero gear", "HeroGearReset", nil, "careful"},
	})
	local models = ReplicatedStorage:FindFirstChild("WeaponModels")
	for _, br in Data.SkillBranches do
		local list = {}
		for _, def in Data.Weapons do
			if def.Style == br.Style then table.insert(list, def) end
		end
		table.sort(list, function(x, y) return Data.WeaponRarityByName[x.Rarity].Order < Data.WeaponRarityByName[y.Rarity].Order end)
		K.header(win.body, ("%s %s"):format(br.Icon, br.Name), nextOrder(), "Tap ✋ to hold it (again = +1 ⭐)")
		local g = K.grid(win.body, UDim2.fromOffset(150, 196), nextOrder())
		for i, def in list do
			local rc = Data.WeaponRarityByName[def.Rarity].Color
			local lo, hi = Data.WeaponRange({Name = def.Name})
			K.card(g, {Order = i, Name = def.Display, Sub = ("%s · 💥 %d-%d"):format(def.Rarity, lo, hi), Color = rc,
				Art = function(pic)
					local m = models and models:FindFirstChild(def.Name)
					local ok = m and pcall(CritterUI.ModelView, pic, m, {Size = UDim2.fromScale(1, 1), ZIndex = pic.ZIndex + 1}, {Yaw = math.pi / 2})
					if not ok then K.text(pic, {Text = def.Icon, Size = UDim2.fromScale(1, 1), Max = 54}) end
				end,
				Button = {Text = "✋ Hold", Kind = "go"}, Fn = function() dev("Weapon", def.Name) end})
		end
	end
end

PAGES.Stuff = function()
	group("💰 Money & items", nil, {
		{"💰 +10,000 coins", "Coins", nil, "special"}, {"🍓 +50 every berry", "Berries"}, {"⚡ Full energy", "Energy"},
		{"🪵 +30 resources", "Resources"}, {"⛏️ Tool +1", "ToolUp"}, {"🌱 All seeds x5", "AllSeeds"},
		{"🎒 Gear set", "Gear"}, {"👒 All outfits", "Outfits"}, {"🎡 +5 spins", "Spins"}, {"🎁 +3 capsules", "Capsules"},
	})
	group("🎁 Gifts ready now", nil, {
		{"🎁 Playtime gifts", "PlayGifts"}, {"📅 Calendar box", "Calendar"}, {"📬 Add mail", "Mail"},
		{"🌙 Moon pot", "MoonPot"}, {"🛒 Restock shop", "Restock"}, {"🍀 Lucky hour", "Lucky"},
	})
end

PAGES.Farm = function()
	group("🌱 Crops", nil, {
		{"⏩ Grow my crops", "GrowCrops", nil, "go"}, {"🧬 Mutate my crops", "MutateCrops"}, {"⏱ Fast timers on/off", "FastTime", nil, "special"},
		{"⏩ Finish trips + eggs", "FinishTimers"},
	})
	group("🏡 Farm", nil, {
		{"⭐ Farm +1 level", "FarmLevel", nil, "go"}, {"🧺 Workers + buildings", "Workers"}, {"😴 Tire my workers", "TireWorkers"},
		{"🧺 Piles", "Pile"}, {"🌈 Farm visitor", "Visitor"}, {"🦝 Raccoon", "Raccoon"}, {"✨ Rare fruit", "Fruit"},
		{"⭐ Golden dash", "Dash"}, {"🧭 Restart journey", "Journey"},
	})
end

PAGES.Pets = function()
	group("🐾 Pets", nil, {
		{"⚔️ All battlers", "Battlers"}, {"⬆️ All pets +1 level", "LevelUp", nil, "go"}, {"📖 Fill the book", "Book"},
		{"🥚 3 ready eggs", "Eggs"}, {"🍂 Harvest egg", "SeasonalEgg"}, {"😢 Make pets sad", "Sad", nil, "careful"},
		{"✨ Shiny spawn", "ShinySpawn", nil, "special"},
	})
	local spawn = {}
	for _, r in {"Common", "Rare", "Epic", "Legendary"} do table.insert(spawn, {"🌿 Spawn " .. r, "Spawn", r}) end
	group("🌿 Wild spawn by rarity", nil, spawn)
	K.header(win.body, "🐾 Every pet", nextOrder(), "🌿 = spawn it wild here · 🏠 = make it your pet")
	local g = K.grid(win.body, UDim2.fromOffset(124, 156), nextOrder())
	for i, T in Data.Species do
		local rarity = Data.Rarities[T.Rarity]
		local card = K.frame(g, {LayoutOrder = rarity.Order * 100 + i, BackgroundColor3 = rarity.Color:Lerp(K.WHITE, 0.6)})
		K.round(card, 14)
		K.stroke(card, rarity.Color, 2)
		pcall(function()
			local vf = CritterUI.Portrait(card, Data, T.Species, {Size = UDim2.new(1, 0, 1, -66), ZIndex = card.ZIndex + 1})
			CritterUI.Animate(vf, "idle")
		end)
		K.text(card, {Text = T.Species, Position = UDim2.new(0, 4, 1, -66), Size = UDim2.new(1, -8, 0, 20), Max = 15})
		K.button(card, {Text = "🌿", Position = UDim2.new(0, 4, 1, -42), Size = UDim2.new(0.5, -6, 0, 38), Kind = "go", Tip = "Spawn wild"},
			function() dev("SpawnSpecies", T.Species) end)
		K.button(card, {Text = "🏠", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 1, -42), Size = UDim2.new(0.5, -6, 0, 38), Kind = "special",
			Tip = "Make it my pet"}, function() dev("GivePet", T.Species) end)
	end
end

PAGES.Events = function()
	group("🌠 World events", nil, {
		{"🌠 Falling star", "Event", "FallingStar"}, {"🏃 Catch race", "Event", "CatchRace"}, {"👹 World boss", "Event", "WorldBoss"},
		{"🎁 Present rush", "Event", "PresentRush"}, {"🥚 Egg snatch", "Event", "EggSnatch"}, {"🎁 Present here", "Present"},
	})
	group("🌦️ Weather", nil, {
		{"🌧️ Rain", "Weather", "Rain"}, {"🌠 Star night", "Weather", "StarNight"}, {"☀️ Golden sun", "Weather", "GoldenSun"},
		{"❄️ Snow", "Weather", "Snow"}, {"⛈️ Storm", "Weather", "Storm"},
	})
end

PAGES.Save = function()
	K.empty(win.body, "♻️", "Start over from a fresh save (buildings stay until the server restarts)", nil, nil, nextOrder())
	K.button(win.body, {Text = "♻️ Reset my save", Size = UDim2.fromOffset(260, 56), LayoutOrder = nextOrder(), Kind = "careful"}, function()
		dev("Reset")
	end)
end

function render()
	local y = win.body.CanvasPosition
	win.clear()
	order = 0
	win.setTabs(TABS, tab, function(t)
		tab = t
		render()
		win.body.CanvasPosition = Vector2.zero
	end)
	local ok, err = pcall(PAGES[tab])
	if not ok then warn("[DevMenu]", err) end
	win.body.CanvasPosition = y
end

-- the ⚔️ Hero numbers stay live while that tab is open
local pending = false
for _, n in {"HeroLv", "PWR", "HP", "HPMax", "SkillPts", "DevGod"} do
	player:GetAttributeChangedSignal(n):Connect(function()
		if not win.frame.Visible or tab ~= "Hero" or pending then return end
		pending = true
		task.delay(0.3, function()
			pending = false
			if win.frame.Visible and tab == "Hero" then render() end
		end)
	end)
end

bridge.Event:Connect(function(cmd)
	if cmd ~= "Dev" then return end
	if win.frame.Visible then
		win.close()
	else
		win.open()
		render()
	end
end)
