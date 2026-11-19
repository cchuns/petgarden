-- Critter Acres: CritterWorld (StarterPlayerScripts LocalScript)
--   🎒 Bag: your resources and tool level
--   🔨 Workbench window (prompt on the plaza workbench): Tools, 🧍 Hero gear (HeroGear GearCraft), Gear (pet gear: craft + ⭐ upgrade), Farm (decorations + soil), Toys
--   🏡 Decorate mode on your own farm: pick a decoration, a see-through copy follows your mouse/finger,
--      ↻ rotate, tap to place, ✋ pick things up again
--   🏷️ Titles: wear the titles you earned
--   🫧 toys bar, 🌰 acorn tracker (found acorns disappear for you), 🛝 playground bounce, 🍀 lucky hour timer
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))
local Builds = require(ReplicatedStorage:WaitForChild("Builds"))
local actionFn = ReplicatedStorage:WaitForChild("CritterAction")
local revealEvent = ReplicatedStorage:WaitForChild("CritterReveal")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local root = workspace:WaitForChild("CritterAcres")

local gui = Instance.new("ScreenGui")
gui.Name = "CritterWorld"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.Parent = player:WaitForChild("PlayerGui")

local CREAM, BROWN = Color3.fromRGB(255, 250, 235), Color3.fromRGB(90, 60, 40)
local GREEN, WHITE = Color3.fromRGB(150, 230, 130), Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(215, 210, 205)

---------------------------------------------------------------- tiny UI kit
local function round(o, r) Instance.new("UICorner", o).CornerRadius = UDim.new(0, r or 12) return o end
local function L(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextColor3 = BROWN
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	for k, v in props do t[k] = v end
	t.Parent = parent
	return t
end
local function B(parent, props, fn)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = CREAM
	b.TextColor3 = BROWN
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	for k, v in props do b[k] = v end
	round(b, 12)
	local s = Instance.new("UIStroke", b)
	s.Color, s.Thickness, s.ApplyStrokeMode = Color3.fromRGB(230, 190, 140), 2, Enum.ApplyStrokeMode.Border
	b.Parent = parent
	if fn then b.Activated:Connect(fn) end
	return b
end
local function F(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do f[k] = v end
	f.Parent = parent
	return f
end
-- a button with a big icon and a small word under it
local function iconButton(parent, icon, word, props, fn)
	props.Text = ""
	local b = B(parent, props, fn)
	L(b, {Name = "Icon", Text = icon, Size = UDim2.fromScale(1, 0.64), ZIndex = (props.ZIndex or 1) + 1})
	L(b, {Name = "Word", Text = word, Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.34), ZIndex = (props.ZIndex or 1) + 1})
	return b
end
local function act(...) return actionFn:InvokeServer(...) end
local function note(text, good)
	local l = L(gui, {Text = text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.fromOffset(520, 50), ZIndex = 90,
		TextColor3 = good == false and Color3.fromRGB(255, 120, 120) or WHITE, TextStrokeTransparency = 0.2})
	TweenService:Create(l, TweenInfo.new(1.6), {Position = UDim2.fromScale(0.5, 0.28), TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	task.delay(1.7, function() l:Destroy() end)
end

---------------------------------------------------------------- bottom-left row 2: Bag, Decorate, Titles + toys
local bar = F(gui, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -86), Size = UDim2.fromOffset(500, 66), BackgroundTransparency = 1})
local bl = Instance.new("UIListLayout", bar)
bl.FillDirection = Enum.FillDirection.Horizontal
bl.Padding = UDim.new(0, 8)
bl.SortOrder = Enum.SortOrder.LayoutOrder

-- the window uses the shared UIKit look (same as the 🐾 / 🏡 / 🗺️ / 🛒 menus)
local UI = require(ReplicatedStorage:WaitForChild("UIKit"))
local winGui = Instance.new("ScreenGui") -- its own layer: Sibling draw order, under the toasts and the ⭐ power-up screen
winGui.Name = "CritterWorldWindow"
winGui.ResetOnSpawn = false
winGui.DisplayOrder = 2
winGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
winGui.Parent = player:WaitForChild("PlayerGui")
local win = UI.window(winGui, {Icon = "🔨", Title = "Workbench"})
local window = win.frame
local body = win.body
local openWin
local openWindow
win.onClose = function() openWin = nil end
local order = 0
local function nextOrder() order += 1 return order end
local function clear()
	win.clear()
	order = 0
end
local function header(text, sub) return UI.header(body, text, nextOrder(), sub) end
local function grid(cell) return UI.grid(body, cell, nextOrder()) end
local function have(cost, info)
	local coins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
	if (cost.Coins or 0) > (coins and coins.Value or 0) then return false end
	for _, r in Data.Resources do
		if (cost[r.Name] or 0) > ((info.Res or {})[r.Name] or 0) then return false end
	end
	return true
end
-- what you're missing for a cost, like "3 more 🪵 Wood" (nil when you have everything)
local function need(cost, info)
	local coins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
	local have = coins and coins.Value or 0
	if (cost.Coins or 0) > have then return ("%d more 💰 coins"):format(cost.Coins - have) end
	for _, r in Data.Resources do
		local n = (cost[r.Name] or 0) - ((info.Res or {})[r.Name] or 0)
		if n > 0 then return ("%d more %s %s"):format(n, r.Icon, r.Name) end
	end
	return nil
end
-- a card: icon, name, cost and a button (grey buttons say what's missing)
local function card(parent, o, icon, name, sub, btnText, can, fn, why, color)
	can = can and true or false
	if not can and why then btnText = "Need " .. why end
	return UI.card(parent, {Order = o, Icon = icon, Name = name, Sub = sub, Color = color,
		Button = btnText and {Text = btnText, Kind = can and "go" or "no"} or nil,
		Fn = function()
			if can then fn() elseif why then note(("You need %s. Gather it in the wild!"):format(why), false) end
		end})
end

---------------------------------------------------------------- 🎒 bag
local function renderBag()
	clear()
	win.setTitle("🎒", "Bag")
	win.setSub("What you gathered in the wild")
	win.setTabs({})
	win.setHelp({{"🪓", "Tap trees and rocks in the wild to gather."}, {"🎒", "Everything you gather lands here."}, {"🔨", "Use it at the Workbench to make tools and gear."}})
	local info = act("CraftInfo") or {Res = {}, Tool = 0}
	header("Resources", "Gather them in the wild")
	local g = grid(UDim2.fromOffset(130, 150))
	for i, r in Data.Resources do
		local n = info.Res[r.Name] or 0
		UI.card(g, {Order = i, Icon = r.Icon, Name = r.Name, Sub = "x" .. n, Color = n > 0 and r.Color or nil})
	end
	header("Your tool")
	local t = Data.Tools[info.Tool]
	local nextT = Data.Tools[info.Tool + 1]
	UI.row(body, {Order = nextOrder(), Icon = t.Icon, Title = ("%s · Lv %d"):format(t.Name, info.Tool),
		Sub = nextT and ("Next: %s %s · %s"):format(nextT.Icon, nextT.Name, Data.CostText(nextT.Cost)) or "Best tool!",
		Button = nextT and {Text = "🔨 Workbench", Kind = "plain"} or nil, Fn = function() openWindow("Bench") end})
	header("Where to find them")
	local where = {}
	for _, def in pairs(Data.Nodes) do
		where[def.Biome] = where[def.Biome] or {}
		table.insert(where[def.Biome], Data.ResByName[def.Res].Icon .. " " .. def.Res .. (def.Tool > 0 and (" (" .. Data.Tools[def.Tool].Icon .. "Lv" .. def.Tool .. ")") or ""))
	end
	for _, b in Data.Biomes do
		UI.row(body, {Order = nextOrder(), Icon = b.Icon, Title = b.Name, Sub = table.concat(where[b.Name] or {}, "   ")})
	end
end

---------------------------------------------------------------- 🔨 workbench
local benchTab = "Tools"
local gearTier = 1
local heroTier = "Leaf" -- 🧍 Hero gear tab: which material
local renderBench
local openPowerUp -- the ⭐ power-up screen (below)
local SELECTED, SELECTED_LINE = Color3.fromRGB(255, 225, 130), Color3.fromRGB(230, 170, 50)
function renderBench()
	clear()
	win.setTitle("🔨", "Workbench")
	win.setSub("Make tools, pet gear and farm things")
	win.setTabs({{"Tools", "⛏️ Tools", "Better tools break harder trees and rocks"}, {"Hero", "🧍 Hero gear", "Make gear to wear yourself"}, {"Gear", "🛡️ Pet gear", "Make gear for your pets and power it up"},
		{"Farm", "🏡 Farm", "Decorations and better soil"}, {"Toys", "🎈 Toys", "Toys to play with friends"}}, benchTab, function(t) benchTab = t renderBench() end)
	win.setHelp({{"🪵", "Gather wood, stone and more in the wild."}, {"🔨", "Make tools and gear here with what you gathered."},
		{"⭐", "Power up gear. It can fail, but a fail adds 🍀 luck!"}})
	local info = act("CraftInfo")
	if not info then UI.empty(body, "🔨", "The workbench is getting ready...", nil, nil, 1) return end
	local function done(res, okText)
		if type(res) == "table" and res.Ok then
			note(okText or "✅ Done!")
			renderBench()
		elseif type(res) == "table" then
			note(res.Error or "❌", false)
		end
	end
	if benchTab == "Tools" then
		header("Tools", "One tool chops and mines. Better tools break harder things.")
		local g = grid(UDim2.fromOffset(170, 220))
		for lv = 1, Data.ToolMax do
			local t = Data.Tools[lv]
			local owned = info.Tool >= lv
			local isNext = info.Tool + 1 == lv
			card(g, lv, t.Icon, t.Name, owned and "✅ You have it" or Data.CostText(t.Cost), (isNext and "Make it") or (owned and "Owned" or "🔒 Make the one before"),
				isNext and have(t.Cost, info), function() done(act("CraftTool"), ("%s %s made!"):format(t.Icon, t.Name)) end, isNext and need(t.Cost, info) or nil,
				owned and GREEN or nil)
		end
	elseif benchTab == "Hero" then -- 🧍 gear YOU wear (ServerScriptService.HeroGear); wear it from 🛡️ Gear (G)
		local gi = act("GearInfo") or {}
		local owned = {}
		for _, it in gi.Items or {} do owned[it.Name] = it end
		header("1. Pick a material", "🏆 Gold, Crystal and Magma gear only drop from bosses")
		local trow = UI.grid(body, UDim2.fromOffset(112, 52), nextOrder())
		local n = 0
		for _, tier in Data.HeroTierOrder do
			if Data.HeroGearCraft[tier] then
				n += 1
				local on = heroTier == tier
				local b = UI.button(trow, {Text = Data.HeroTierIcon[tier] .. " " .. tier, LayoutOrder = n, BackgroundColor3 = on and SELECTED or UI.CARD, Max = 20}, function()
					heroTier = tier
					renderBench()
				end)
				if on then b.UIStroke.Color, b.UIStroke.Thickness = SELECTED_LINE, 3 end
			end
		end
		header(("2. Make %s gear"):format(heroTier), "Wear it from 🛡️ Gear (G). Make one you have = +1 ⭐")
		local g = grid(UDim2.fromOffset(170, 220))
		local i = 0
		for _, def in Data.HeroGear do
			if def.Tier == heroTier and def.Craft then
				i += 1
				local cost = Data.HeroCraftCost(def)
				local mine = owned[def.Name]
				local maxed = mine and mine.Stars >= Data.HeroGearMaxStars
				local slot = Data.HeroSlotById[def.Slot]
				local r = Data.WeaponRarityByName[def.Rarity]
				card(g, i, slot.Icon, def.Display .. (mine and mine.Stars > 0 and (" " .. string.rep("⭐", mine.Stars)) or ""),
					Data.HeroGearText(Data.HeroGearStats({Name = def.Name, Stars = 0})) .. " · " .. Data.CostText(cost),
					maxed and "⭐ Max" or (mine and "⭐ +1 star" or "Make it"), not maxed and have(cost, info), function()
						local res = act("GearCraft", def.Name)
						if type(res) == "string" then note(res, false) return end
						local got = res and res.Result or {}
						note(got.Up and ("⭐ %s got a star!"):format(def.Display)
							or ("✨ You made: %s %s%s"):format(slot.Icon, def.Display, got.Equipped and " (you're wearing it!)" or ""))
						renderBench()
					end, not maxed and need(cost, info) or nil, r and r.Color)
			end
		end
	elseif benchTab == "Gear" then
		header("1. Pick a material", "Better materials make much stronger gear")
		local trow = UI.grid(body, UDim2.fromOffset(112, 52), nextOrder())
		for ti, tier in Data.GearTiers do
			local on = gearTier == ti
			local b = UI.button(trow, {Text = tier.Icon .. " " .. tier.Name, LayoutOrder = ti, BackgroundColor3 = on and SELECTED or UI.CARD, Max = 20,
				Tip = tier.Icon .. " " .. tier.Name, TipText = ("x%.1f power · costs %s"):format(tier.Mult, Data.CostText(tier.Cost))}, function()
				gearTier = ti
				renderBench()
			end)
			if on then b.UIStroke.Color, b.UIStroke.Thickness = SELECTED_LINE, 3 end
		end
		local tier = Data.GearTiers[gearTier]
		header(("2. Make %s gear"):format(tier.Name), ("Costs %s · the rarity is a surprise"):format(Data.CostText(tier.Cost)))
		local g = grid(UDim2.fromOffset(170, 220))
		for kind, def in Data.Gear do
			local sample = {Kind = kind, Tier = gearTier, Rarity = "Common", Level = 0}
			local _, amount = Data.GearBonus(sample)
			local stat = def.Stat == "SPD" and ("+%d%% speed"):format(amount * 100 + 0.5) or ("+%d %s"):format(amount, def.Stat)
			card(g, kind, tier.Icon .. def.Icon, Data.GearName(sample), stat .. " or more", "Make it", have(tier.Cost, info), function()
				local res = act("CraftGear", kind, gearTier)
				if type(res) == "table" and res.Ok then
					note(("✨ You made: %s"):format(res.Gear.Text))
					renderBench()
				else
					done(res)
				end
			end, need(tier.Cost, info), tier.Color)
		end
		header("3. ⭐ Power up", "It can fail. A fail adds 🍀 luck for next time.")
		if #info.Gear == 0 then UI.empty(body, "🛡️", "No gear yet. Make some above or win ⚔️ raids!", nil, nil, nextOrder()) end
		for _, gItem in info.Gear do
			local def, amount = Data.GearBonus(gItem)
			local stat = def.Stat == "SPD" and ("+%d%% speed"):format(amount * 100 + 0.5) or ("+%d %s"):format(amount, def.Stat)
			local lv = (gItem.Level or 0) > 0 and (" +" .. gItem.Level) or ""
			UI.row(body, {Order = nextOrder(), Icon = def.Icon, Title = Data.GearName(gItem) .. lv,
				Sub = ("%s · %s%s"):format(gItem.Rarity, stat, gItem.WornBy and (" · on " .. gItem.WornBy) or ""),
				Button = gItem.Odds and {Text = ("⭐ Power up %d%%"):format(gItem.Odds * 100 + 0.5), Kind = "special", Tip = "Power up",
					TipText = "Try to make it stronger. It can fail, but your gear stays safe."} or {Text = "⭐ Max", Kind = "no"},
				Fn = function() if gItem.Odds then openPowerUp(gItem.Id) else note("⭐ This gear is fully powered up!") end end})
		end
	elseif benchTab == "Farm" then
		header("Decorations", "Buy here, then place them with 🏡 Decorate")
		local g = grid(UDim2.fromOffset(160, 210))
		local function decorCard(gg, i, d)
			local owned = (info.DecorInv or {})[d.Name] or 0
			local sub = Data.CostText(d.Cost) .. (owned > 0 and (" · have " .. owned) or "")
			if d.Effect then sub = (d.Effect == "Water" and "💦 waters · " or "🐝 faster · ") .. sub end
			card(gg, i, d.Icon, d.Name, sub, "Buy", have(d.Cost, info), function() done(act("BuyDecor", d.Name), d.Icon .. " " .. d.Name .. " bought! Place it with 🏡 Decorate") end,
				need(d.Cost, info))
		end
		for i, d in Data.Decor do
			if not (Data.ScrollLandOf and Data.ScrollLandOf[d.Name]) then decorCard(g, i, d) end
		end
		-- 📜 the scroll album: dungeon-only decorations, unlocked by finding their scroll in that 🏰 dungeon
		if Data.ScrollLandOf and Data.Dungeon then
			local list, got = {}, 0
			for _, b in Data.Biomes do
				for _, name in Data.Dungeon.Scrolls[b.Name] or {} do
					local d = Data.DecorByName[name]
					if d then
						table.insert(list, {d = d, land = b.Name})
						if not Data.DecorLocked(name, info.Scrolls) then got += 1 end
					end
				end
			end
			if #list > 0 then
				header(("📜 Scroll album  %d/%d"):format(got, #list), "Dungeon decorations: find their scroll in a 🏰 dungeon to unlock")
				local ag = grid(UDim2.fromOffset(160, 210))
				for i, e in list do
					if Data.DecorLocked(e.d.Name, info.Scrolls) then
						local th = Data.Dungeon.Themes[e.land] or {}
						UI.card(ag, {Order = i, Icon = "📜", Name = e.d.Name, Sub = ("In %s %s"):format(th.Icon or "🏰", th.Name or e.land),
							Button = {Text = "🔒 Find scroll", Kind = "no"},
							Fn = function() note(("📜 Find the %s scroll in the %s %s dungeon!"):format(e.d.Name, th.Icon or "🏰", th.Name or e.land), false) end})
					else
						decorCard(ag, i, e.d)
					end
				end
			end
		end
		header("🌱 Soil", "Better soil grows faster and gets more mutations")
		local sg = grid(UDim2.fromOffset(140, 190))
		for i = 1, 15 do
			local locked = i > (info.PlotsOpen or Data.StartPlots)
			local lvl = (info.Soil or {})[tostring(i)] or 1
			local soil = Data.Soil[lvl]
			local nextSoil = Data.Soil[lvl + 1]
			if locked then
				UI.card(sg, {Order = i, Icon = "🔒", Name = "Plot " .. i, Sub = "Unlock it on your farm"})
			elseif nextSoil then
				card(sg, i, "🌱", "Plot " .. i, soil.Name .. " " .. string.rep("⭐", lvl - 1), "⬆ " .. Data.CostText(nextSoil.Cost), have(nextSoil.Cost, info),
					function() done(act("UpgradeSoil", i), "🌱 Soil upgraded!") end, need(nextSoil.Cost, info), soil.Color)
			else
				UI.card(sg, {Order = i, Icon = "🌱", Name = "Plot " .. i, Sub = soil.Name .. " · best soil!", Color = soil.Color})
			end
		end
	else -- Toys
		header("Toys", "Play with friends. Use them from the toy bar.")
		local g = grid(UDim2.fromOffset(170, 210))
		for i, t in Data.Toys do
			local owned = (info.Toys or {})[t.Name]
			card(g, i, t.Icon, t.Name, owned and "✅ You have it" or Data.CostText(t.Cost or {}), owned and "Owned" or "Buy", not owned and have(t.Cost or {}, info),
				function() done(act("BuyToy", t.Name), t.Icon .. " " .. t.Name .. " is yours!") end, not owned and need(t.Cost or {}, info) or nil)
		end
	end
end

---------------------------------------------------------------- 🏷️ titles
local function renderTitles()
	clear()
	win.setTitle("🏷️", "Titles")
	win.setSub("Pick the title over your head")
	win.setTabs({})
	win.setHelp({{"🏆", "Do fun things to earn titles."}, {"🏷️", "Tap Wear to show one over your head."}, {"👀", "Everyone on the server can see it!"}})
	local owned = {}
	for _, n in string.split(player:GetAttribute("Titles") or "", ",") do owned[n] = true end
	local current = player:GetAttribute("Title")
	for _, t in Data.Titles do
		local got = owned[t.Name]
		local wearing = current == t.Name
		UI.row(body, {Order = nextOrder(), Icon = t.Icon, Title = t.Name, Sub = got and "✅ Earned" or ("🔒 " .. t.How),
			Button = got and {Text = wearing and "✔ Wearing" or "Wear", Kind = wearing and "special" or "go"} or nil,
			Fn = function()
				act("SetTitle", t.Name)
				task.wait(0.2)
				renderTitles()
			end})
	end
end

function openWindow(name)
	if openWin == name and window.Visible then
		win.close()
		return
	end
	openWin = name
	win.open()
	body.CanvasPosition = Vector2.zero
	if name == "Bag" then renderBag() elseif name == "Bench" then renderBench() else renderTitles() end
end
-- the workbench prompt (local: it only opens your own window)
task.spawn(function()
	local wb = root:WaitForChild("Workbench", 30)
	local tbl = wb and wb:WaitForChild("Table", 10)
	if not tbl then return end
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Craft 🔨"
	p.ObjectText = "Workbench"
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = tbl
	p.Triggered:Connect(function() if openWin ~= "Bench" then openWindow("Bench") end end)
end)

---------------------------------------------------------------- 🏡 decorate mode (build menu, UIKit look)
-- build mode: Build (place), Move (E), Remove (X). Keys like popular building games:
--   1-9 pick an item · R rotate (Shift+R back) · E move · X / Delete remove · G grid size · Q cancel · N open / close (B is the bag)
-- Panel at the bottom middle: 🧱 Build / ✋ Move / 🗑️ Remove on the left, item cards in the middle (owned first, number = key),
-- ↻ Rotate / ▦ Grid / ✔ Done on the right. On PC a row of key chips sits above it.
local K = require(ReplicatedStorage:WaitForChild("UIKit"))
local deco = {on = false, item = nil, ghost = nil, rot = 0, pick = false, remove = false, grid = 1, slots = {}}
local PANEL_H, SIDE_W = 196, 150
local decoPanel = K.frame(gui, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(0.94, 0, 0, PANEL_H),
	BackgroundColor3 = K.CREAM, Visible = false, ZIndex = 30, Active = true})
K.round(decoPanel, 20)
K.stroke(decoPanel, K.LINE, 3)
local sizeCap = Instance.new("UISizeConstraint")
sizeCap.MaxSize = Vector2.new(1040, PANEL_H)
sizeCap.Parent = decoPanel
-- left: the 3 modes
local modeCol = K.frame(decoPanel, {Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(SIDE_W - 12, PANEL_H - 24), BackgroundTransparency = 1, ZIndex = 31})
K.list(modeCol, Enum.FillDirection.Vertical, 8)
-- right: rotate, grid, done
local toolCol = K.frame(decoPanel, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(SIDE_W - 12, PANEL_H - 24),
	BackgroundTransparency = 1, ZIndex = 31})
K.list(toolCol, Enum.FillDirection.Vertical, 8)
-- middle: what to do now + the item cards
local mid = K.frame(decoPanel, {Position = UDim2.fromOffset(SIDE_W + 6, 10), Size = UDim2.new(1, -2 * SIDE_W - 12, 1, -20), BackgroundTransparency = 1, ZIndex = 31})
local decoHint = K.text(mid, {Size = UDim2.new(1, 0, 0, 28), ZIndex = 32, Max = 20, TextXAlignment = Enum.TextXAlignment.Left})
local decoList = Instance.new("ScrollingFrame")
decoList.Position = UDim2.fromOffset(0, 34)
decoList.Size = UDim2.new(1, 0, 1, -34)
decoList.BackgroundTransparency = 1
decoList.BorderSizePixel = 0
decoList.ScrollingDirection = Enum.ScrollingDirection.X
decoList.AutomaticCanvasSize = Enum.AutomaticSize.X
decoList.CanvasSize = UDim2.new()
decoList.ScrollBarThickness = 6
decoList.ScrollBarImageColor3 = K.SOFT
decoList.ZIndex = 32
decoList.Parent = mid
local dl = K.list(decoList, Enum.FillDirection.Horizontal, 10)
dl.VerticalAlignment = Enum.VerticalAlignment.Top
local dpad = Instance.new("UIPadding")
dpad.PaddingLeft, dpad.PaddingTop, dpad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 4)
dpad.Parent = decoList
-- the key chips above the panel (PC only): flash when you press one
local keyBar = K.frame(gui, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -PANEL_H - 22), Size = UDim2.fromOffset(780, 40),
	BackgroundTransparency = 1, Visible = false, ZIndex = 30})
K.list(keyBar, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
local keyChips = {}
for i, k in {{"1-9", "Pick"}, {"R", "Rotate"}, {"E", "Move"}, {"X", "Remove"}, {"G", "Grid"}, {"Q", "Cancel"}, {"N", "Done"}} do
	local wide = i == 1
	local chip = K.frame(keyBar, {Size = UDim2.fromOffset(wide and 108 or 102, 38), BackgroundColor3 = K.CARD, LayoutOrder = i, ZIndex = 30})
	K.round(chip, 12)
	K.stroke(chip, K.LINE, 2)
	local key = K.text(chip, {Text = k[1], Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(wide and 44 or 30, 30), BackgroundTransparency = 0,
		BackgroundColor3 = K.BROWN, TextColor3 = K.WHITE, ZIndex = 31, Max = 18})
	K.round(key, 8)
	K.text(chip, {Text = k[2], Position = UDim2.fromOffset(wide and 52 or 38, 4), Size = UDim2.new(1, wide and -56 or -42, 0, 30), ZIndex = 31, Max = 18,
		TextXAlignment = Enum.TextXAlignment.Left})
	keyChips[k[2]] = chip
end
local function flashKey(name)
	local chip = keyChips[name]
	if not chip then return end
	chip.BackgroundColor3 = K.YELLOW
	task.delay(0.2, function() chip.BackgroundColor3 = K.CARD end)
end
local function myFarm()
	local farms = root:FindFirstChild("Farms")
	for _, f in farms and farms:GetChildren() or {} do
		if f:GetAttribute("Owner") == player.UserId then return f end
	end
end
local function setGhost(name)
	if deco.ghost then deco.ghost:Destroy() deco.ghost = nil end
	deco.item = name
	if not name then return end
	local g = Builds.Decor(name)
	if not g then return end
	for _, p in g:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = math.max(p.Transparency, 0.45)
			p.CanQuery = false
		elseif p:IsA("ParticleEmitter") or p:IsA("Light") then
			p.Enabled = false
		end
	end
	local hl = Instance.new("Highlight")
	hl.Name = "Fit"
	hl.FillColor = Color3.fromRGB(110, 230, 110)
	hl.OutlineColor = Color3.new(1, 1, 1)
	hl.FillTransparency = 0.6
	hl.Parent = g
	g.Parent = workspace
	deco.ghost = g
end
-- the card picture: the real 3D decoration (built once per kind, then cloned into a ViewportFrame); the emoji if it can't be built
local decorTpl = {}
local function decorArt(pic, d)
	local tpl = decorTpl[d.Name]
	if tpl == nil then
		local ok, m = pcall(Builds.Decor, d.Name)
		tpl = ok and m or false
		decorTpl[d.Name] = tpl
	end
	if tpl then
		local ok = pcall(CritterUI.ModelView, pic, tpl, {Size = UDim2.fromScale(1, 1), ZIndex = 34}, {Yaw = math.rad(205)})
		if ok then return end
	end
	K.text(pic, {Text = d.Icon, Size = UDim2.fromScale(1, 1), ZIndex = 34, Max = 54})
end
local renderDeco
local modeButtons -- set below with the side buttons
function renderDeco()
	for _, ch in decoList:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local info = act("CraftInfo") or {DecorInv = {}, Res = {}}
	-- owned first, then everything else with its price (tap one to buy it right here)
	local list = {}
	for _, d in Data.Decor do
		if ((info.DecorInv or {})[d.Name] or 0) > 0 then table.insert(list, d) end
	end
	for _, d in Data.Decor do
		-- (📜 dungeon decorations show up once their scroll is found)
		if ((info.DecorInv or {})[d.Name] or 0) == 0 and not (Data.DecorLocked and Data.DecorLocked(d.Name, info.Scrolls)) then table.insert(list, d) end
	end
	deco.slots = {}
	for i, d in list do
		local n = (info.DecorInv or {})[d.Name] or 0
		if n > 0 and #deco.slots < 9 then table.insert(deco.slots, d.Name) end
		local slotNum = n > 0 and table.find(deco.slots, d.Name) or nil
		local on = deco.item == d.Name
		local can = n > 0 or have(d.Cost, info)
		local color = on and Color3.fromRGB(240, 170, 50) or (n > 0 and K.GREEN or (can and K.BLUE or K.GREY))
		local card = K.card(decoList, {Order = i, Icon = d.Icon, Name = d.Name, Color = color, Art = function(pic) decorArt(pic, d) end,
			Sub = n > 0 and ("x%d"):format(n) or ("🛒 " .. Data.CostText(d.Cost)),
			Tip = d.Icon .. " " .. d.Name,
			TipText = n > 0 and ("You have %d. Tap, then tap your farm to place it."):format(n)
				or (can and "Tap to buy it, then place it on your farm." or "You need more to buy this one."),
			CardFn = function()
				deco.pick, deco.remove = false, false
				if n == 0 then
					local res = act("BuyDecor", d.Name)
					if type(res) == "table" and res.Ok then
						K.toast(gui, ("%s %s bought! Tap your farm to place it."):format(d.Icon, d.Name), true)
						setGhost(d.Name)
					else
						K.toast(gui, type(res) == "table" and res.Error or "❌", false)
					end
					renderDeco()
					return
				end
				setGhost(deco.item ~= d.Name and d.Name or nil)
				renderDeco()
			end})
		card.Size = UDim2.fromOffset(112, 138)
		card.ZIndex = 33
		for _, ch in card:GetDescendants() do
			if ch:IsA("GuiObject") then ch.ZIndex = 34 end
		end
		if n == 0 and not can then card.BackgroundColor3 = Color3.fromRGB(245, 242, 236) end
		if slotNum then
			local num = K.text(card, {Text = tostring(slotNum), Position = UDim2.fromOffset(-4, -4), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0,
				BackgroundColor3 = K.BROWN, TextColor3 = K.WHITE, ZIndex = 36, Max = 15})
			K.round(num, 12)
		end
	end
	decoHint.Text = (deco.remove and "🗑️ Remove: tap a decoration to put it back in your bag")
		or (deco.pick and "✋ Move: tap a decoration to pick it up")
		or (deco.item and ("🧱 Build: tap your farm to place %s"):format(deco.item)) or "🧱 Build: pick a decoration (or press 1-9)"
	if modeButtons then modeButtons() end
end
local function setMode(m)
	deco.pick, deco.remove = m == "Move", m == "Remove"
	if m ~= "Build" then setGhost(nil) end
	renderDeco()
end
local function rotate(dir) deco.rot = (deco.rot + 45 * (dir or 1)) % 360 end
local function stopDecorate()
	deco.on, deco.pick, deco.remove = false, false, false
	player:SetAttribute("Decorating", nil)
	game:GetService("ProximityPromptService").Enabled = true
	setGhost(nil)
	decoPanel.Visible = false
	keyBar.Visible = false
end
local BTN_H = (PANEL_H - 24 - 16) / 3
local mb = {}
mb.Build = K.button(modeCol, {Text = "🧱 Build", Size = UDim2.new(1, 0, 0, BTN_H), LayoutOrder = 1, ZIndex = 32,
	Tip = "🧱 Build", TipText = "Pick a decoration and tap your farm to place it."}, function() setMode("Build") end)
mb.Move = K.button(modeCol, {Text = "✋ Move", Size = UDim2.new(1, 0, 0, BTN_H), LayoutOrder = 2, ZIndex = 32,
	Tip = "✋ Move (E)", TipText = "Tap a decoration to pick it up, then put it somewhere else."}, function() setMode(deco.pick and "Build" or "Move") end)
mb.Remove = K.button(modeCol, {Text = "🗑️ Remove", Size = UDim2.new(1, 0, 0, BTN_H), LayoutOrder = 3, ZIndex = 32,
	Tip = "🗑️ Remove (X)", TipText = "Tap a decoration to put it back in your bag."}, function() setMode(deco.remove and "Build" or "Remove") end)
K.button(toolCol, {Text = "↻ Rotate", Size = UDim2.new(1, 0, 0, BTN_H), LayoutOrder = 1, ZIndex = 32,
	Tip = "↻ Rotate (R)", TipText = "Turn it. Shift + R turns it back."}, function() rotate(1) end)
mb.Grid = K.button(toolCol, {Text = "▦ Grid 1", Size = UDim2.new(1, 0, 0, BTN_H), LayoutOrder = 2, ZIndex = 32,
	Tip = "▦ Grid (G)", TipText = "How far it jumps when you move it: 1, 2 or 4 studs."}, function()
	deco.grid = deco.grid == 1 and 2 or (deco.grid == 2 and 4 or 1)
	renderDeco()
end)
K.button(toolCol, {Text = "✔ Done", Size = UDim2.new(1, 0, 0, BTN_H), LayoutOrder = 3, ZIndex = 32, Kind = "go",
	Tip = "✔ Done (N)", TipText = "Close decorate mode."}, stopDecorate)
function modeButtons()
	local mode = deco.remove and "Remove" or (deco.pick and "Move" or "Build")
	for name, b in mb do
		if name ~= "Grid" then
			local here = name == mode
			b.BackgroundColor3 = here and K.YELLOW or K.CARD
			b.UIStroke.Color = here and K.YELLOW:Lerp(Color3.new(0, 0, 0), 0.15) or K.LINE
		end
	end
	mb.Grid.Text = ("▦ Grid %d"):format(deco.grid)
end
local function startDecorate()
	if not myFarm() then
		K.toast(gui, "You need a farm first!", false)
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local g = myFarm():FindFirstChild("Ground")
	if not hrp or not g or (hrp.Position - g.Position).Magnitude > 120 then
		K.toast(gui, "🏝️ Go to your island to decorate! Use a 🌀 portal.", false)
		return
	end
	deco.on = true
	player:SetAttribute("Decorating", true) -- the build keys belong to decorate mode now (Combat: G is not ⚔️ Weapons, SkillTree: no 1-5)
	game:GetService("ProximityPromptService").Enabled = false -- no "E" prompts while building, so E is always ✋ Move
	deco.pick, deco.remove = false, false
	decoPanel.Visible = true
	keyBar.Visible = UserInputService.KeyboardEnabled
	window.Visible = false
	renderDeco()
end
-- The ray under the mouse / finger. ONE way to work it out, used by the preview AND the click, so the item lands exactly where
-- the see-through copy was. (Before, the preview guessed a 36 px top bar and the click used another position, so with the
-- newer, taller top bar the placed item could jump one grid square.)
--   mouse: GetMouseLocation is in viewport space (top bar included) -> ViewportPointToRay
--   touch: input positions leave the top bar out -> ScreenPointToRay
local lastTouch = nil -- set while a finger is the pointer
local function pointerRay()
	if lastTouch then return camera:ScreenPointToRay(lastTouch.X, lastTouch.Y) end
	local mp = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(mp.X, mp.Y)
end
-- where the pointer is on your farm ground, snapped to the grid
local function pointOnFarm()
	local farm = myFarm()
	if not farm then return nil end
	local ray = pointerRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {farm.Ground}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if not hit then return nil end
	local rel = farm.Ground.CFrame:PointToObjectSpace(hit.Position)
	local g = deco.grid or 1
	local x, z = math.clamp(math.floor(rel.X / g + 0.5) * g, -23, 23), math.clamp(math.floor(rel.Z / g + 0.5) * g, -23, 23)
	return farm, x, z
end
RunService.RenderStepped:Connect(function()
	if not (deco.on and deco.ghost) then return end
	local farm, x, z = pointOnFarm()
	local hl = deco.ghost:FindFirstChild("Fit")
	if farm then
		deco.ghost:PivotTo(farm.Ground.CFrame * CFrame.new(x, farm.Ground.Size.Y / 2, z) * CFrame.Angles(0, math.rad(deco.rot), 0))
		if hl then hl.FillColor = Color3.fromRGB(110, 230, 110) end
	elseif hl then
		hl.FillColor = Color3.fromRGB(240, 90, 90)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		lastTouch = Vector2.new(input.Position.X, input.Position.Y)
	elseif input.UserInputType == Enum.UserInputType.MouseMovement then
		lastTouch = nil -- back on the mouse
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not deco.on or processed then return end
	if input.UserInputType == Enum.UserInputType.Touch then
		lastTouch = Vector2.new(input.Position.X, input.Position.Y)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		lastTouch = nil
	else
		return
	end
	if deco.pick or deco.remove then -- move: pick it up and carry it · remove: put it back in your bag
		local farm = myFarm()
		local folder = farm and farm:FindFirstChild("Decor")
		if not folder then return end
		local ray = pointerRay()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = {folder}
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		local m = hit and hit.Instance:FindFirstAncestorWhichIsA("Model")
		while m and not m:GetAttribute("DecorId") and m.Parent ~= folder do m = m.Parent:FindFirstAncestorWhichIsA("Model") end
		if m and m:GetAttribute("DecorId") then
			local res = act("PickupDecor", m:GetAttribute("DecorId"))
			if type(res) == "table" and res.Ok then
				if deco.remove then
					K.toast(gui, ("🗑️ %s is back in your bag"):format(res.Name or "It"), true)
				else
					deco.pick = false
					setGhost(res.Name) -- now it follows you so you can put it somewhere else
				end
				renderDeco()
			end
		end
		return
	end
	if deco.item then
		local farm, x, z = pointOnFarm() -- the same spot the preview shows
		if not farm then return end
		if deco.ghost then deco.ghost:PivotTo(farm.Ground.CFrame * CFrame.new(x, farm.Ground.Size.Y / 2, z) * CFrame.Angles(0, math.rad(deco.rot), 0)) end
		local res = act("PlaceDecor", deco.item, x, z, deco.rot)
		if type(res) == "table" and res.Ok then
			local left = (res.Info.DecorInv or {})[deco.item] or 0
			if left <= 0 then setGhost(nil) end
			renderDeco()
		elseif type(res) == "table" then
			K.toast(gui, res.Error, false)
		end
	end
end)

---------------------------------------------------------------- ⭐ power-up screen: ready → 🔨 3 hammer hits → ✨ success (ding!) or 💨 so close
local SoundService = game:GetService("SoundService")
local SND = {
	anvil = "rbxassetid://9113447467", -- blacksmith anvil hit (we play just the first clang)
	dingHi = "rbxassetid://72644163309528", -- glockenspiel C6
	dingLo = "rbxassetid://92005223886431", -- glockenspiel C5
	poof = "rbxassetid://9126014267", -- soft swish
}
local function sfx(id, speed, vol, cut)
	local snd = Instance.new("Sound")
	snd.SoundId, snd.PlaybackSpeed, snd.Volume = id, speed or 1, vol or 0.6
	snd.Parent = SoundService
	snd:Play()
	task.delay(cut or 4, function()
		if cut then TweenService:Create(snd, TweenInfo.new(0.12), {Volume = 0}):Play() task.wait(0.13) end
		snd:Destroy()
	end)
end
local NAVY, NAVY2, NAVY3 = Color3.fromRGB(29, 35, 51), Color3.fromRGB(43, 51, 73), Color3.fromRGB(58, 68, 96)
local GOLD, GOLDDK = Color3.fromRGB(239, 159, 39), Color3.fromRGB(65, 36, 2)
local LIME, FOREST, FOREST2 = Color3.fromRGB(151, 196, 89), Color3.fromRGB(23, 52, 4), Color3.fromRGB(39, 80, 10)
local PALE, MUTE = Color3.fromRGB(244, 241, 232), Color3.fromRGB(180, 178, 169)

local pu = F(gui, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 10, 20), BackgroundTransparency = 0.35, Visible = false, ZIndex = 60, Active = true})
local puBusy = false
local function pill(parent, text, bg, fg, props)
	local p = L(parent, {Text = text, BackgroundTransparency = 0, BackgroundColor3 = bg or NAVY2, TextColor3 = fg or PALE, ZIndex = 64})
	round(p, 999)
	Instance.new("UIPadding", p).PaddingTop = UDim.new(0, 4)
	for k, v in props or {} do p[k] = v end
	return p
end
local function statText(g, lv)
	local def, amount = Data.GearBonus({Kind = g.Kind, Tier = g.Tier, Rarity = g.Rarity, Level = lv})
	if def.Stat == "SPD" then return ("%d%%"):format(amount * 100 + 0.5), "speed" end
	return tostring(math.floor(amount + 0.5)), def.Stat
end

function openPowerUp(gearId)
	window.Visible = false
	pu.Visible = true
	for _, ch in pu:GetChildren() do ch:Destroy() end
	local info = act("CraftInfo")
	local g
	for _, x in info and info.Gear or {} do
		if x.Id == gearId then g = x end
	end
	if not g then pu.Visible = false return end
	local tier = Data.GearTiers[g.Tier or 1]
	local def = Data.Gear[g.Kind]
	local Z = 62

	-- the card
	local card = F(pu, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 500), BackgroundColor3 = NAVY, ZIndex = Z})
	round(card, 26)
	local fit = Instance.new("UISizeConstraint", card)
	fit.MaxSize = Vector2.new(380, 500)
	local scale = Instance.new("UIScale", card)
	local function fitScreen()
		local vs = camera.ViewportSize
		scale.Scale = math.min(1, (vs.Y - 40) / 500, (vs.X - 32) / 380)
	end
	fitScreen()
	local home = card.Position
	local title = L(card, {Text = "Power up", Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 30), ZIndex = Z + 1, TextColor3 = PALE})
	local closeB = B(card, {Text = "✖", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(38, 38), ZIndex = Z + 2,
		BackgroundColor3 = NAVY2, TextColor3 = PALE}, function()
		if puBusy then return end
		pu.Visible = false
		openWin = nil
		openWindow("Bench")
	end)
	closeB:FindFirstChildOfClass("UIStroke"):Destroy()

	-- the gear in a glowing ring
	local slot = F(card, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 140), Size = UDim2.fromOffset(150, 150), BackgroundColor3 = NAVY2, ZIndex = Z + 1})
	round(slot, 999)
	local ring = Instance.new("UIStroke", slot)
	ring.Thickness, ring.Color = 6, NAVY3
	local icon
	local gt = CritterUI.Template("GearModels", def.Name)
	if gt then
		icon = CritterUI.ModelView(slot, gt, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.95, 0.95), ZIndex = Z + 2}, {Yaw = 0})
		CritterUI.Animate(icon, "spin")
	else
		icon = L(slot, {Text = def.Icon, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), ZIndex = Z + 2})
	end
	L(card, {Text = tier.Icon, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 58, 0, 82), Size = UDim2.fromOffset(40, 40), ZIndex = Z + 3})
	local nameL = L(card, {Text = Data.GearName(g), Position = UDim2.new(0.08, 0, 0, 228), Size = UDim2.new(0.84, 0, 0, 28), ZIndex = Z + 1, TextColor3 = PALE})

	-- info area (swapped for each stage)
	local area = F(card, {Position = UDim2.new(0, 24, 0, 266), Size = UDim2.new(1, -48, 1, -284), BackgroundTransparency = 1, ZIndex = Z + 1})
	local function clearArea() for _, ch in area:GetChildren() do ch:Destroy() end end
	local lv = g.Level or 0
	local nextLv = lv + 1
	local odds = g.Odds
	local cost = odds and Data.UpgradeCost({Tier = g.Tier, Kind = g.Kind}, nextLv)
	local can = cost and have(cost, info)

	-- level pills: +3 → +4, and the stat it changes
	local lvRow = F(area, {Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, ZIndex = Z + 1})
	local s0, statName = statText(g, lv)
	if odds then
		pill(lvRow, "+" .. lv, NAVY2, PALE, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.5, -26, 0, 0), Size = UDim2.fromOffset(70, 34)})
		L(lvRow, {Text = "→", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(40, 34), ZIndex = Z + 2, TextColor3 = LIME})
		pill(lvRow, "+" .. nextLv, FOREST2, LIME, {Position = UDim2.new(0.5, 26, 0, 0), Size = UDim2.fromOffset(70, 34)})
		local s1 = statText(g, nextLv)
		L(area, {Text = ("%s  %s → %s"):format(statName, s0, s1), Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 20), ZIndex = Z + 1, TextColor3 = MUTE})
	else
		pill(lvRow, "⭐ Max level +" .. lv, FOREST2, LIME, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(200, 34)})
		L(area, {Text = ("%s  %s"):format(statName, s0), Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 20), ZIndex = Z + 1, TextColor3 = MUTE})
	end

	-- chance bar + luck
	if odds then
		L(area, {Text = "Chance", Position = UDim2.fromOffset(0, 70), Size = UDim2.new(0.5, 0, 0, 20), ZIndex = Z + 1, TextColor3 = MUTE, TextXAlignment = Enum.TextXAlignment.Left})
		L(area, {Text = ("%d%%"):format(odds * 100 + 0.5), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 68), Size = UDim2.new(0.4, 0, 0, 24), ZIndex = Z + 1,
			TextColor3 = PALE, TextXAlignment = Enum.TextXAlignment.Right})
		local barBg = F(area, {Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = NAVY2, ZIndex = Z + 1})
		round(barBg, 999)
		local fill = F(barBg, {Size = UDim2.fromScale(0, 1), BackgroundColor3 = odds >= 0.5 and LIME or GOLD, ZIndex = Z + 2})
		round(fill, 999)
		TweenService:Create(fill, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {Size = UDim2.fromScale(math.clamp(odds, 0.03, 1), 1)}):Play()
		if g.Luck and g.Luck > 0 then
			L(area, {Text = ("🍀 Luck +%d%% (from tries that didn't stick)"):format(g.Luck * 100 + 0.5), Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 0, 18),
				ZIndex = Z + 1, TextColor3 = LIME})
		end
	end

	-- the big button
	local goText, goBg, goFg
	if not odds then
		goText, goBg, goFg = "⭐ All powered up", NAVY3, MUTE
	elseif can then
		goText, goBg, goFg = "🔨 Power up  ·  " .. Data.CostText(cost), GOLD, GOLDDK
	else
		goText, goBg, goFg = "Need " .. Data.CostText(cost), NAVY3, Color3.fromRGB(255, 160, 150)
	end
	local go = B(area, {Text = goText, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 54), ZIndex = Z + 2,
		BackgroundColor3 = goBg, TextColor3 = goFg})
	go:FindFirstChildOfClass("UIStroke"):Destroy()
	local gp = Instance.new("UIPadding", go)
	gp.PaddingTop, gp.PaddingBottom, gp.PaddingLeft, gp.PaddingRight = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 12)

	local function burst(text, n, colors, dist)
		for _ = 1, n do
			local a = math.random() * math.pi * 2
			local d = dist * (0.6 + math.random() * 0.5)
			local sp = L(card, {Text = text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 140), Size = UDim2.fromOffset(22, 22), ZIndex = Z + 6,
				TextColor3 = colors[math.random(#colors)]})
			TweenService:Create(sp, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, math.cos(a) * d, 0, 140 + math.sin(a) * d),
				TextTransparency = 1, Rotation = math.random(-90, 90)}):Play()
			task.delay(0.6, function() sp:Destroy() end)
		end
	end
	local function popText(text, color, y, size)
		local t = L(card, {Text = text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.fromOffset(0, 0), ZIndex = Z + 7, TextColor3 = color,
			TextStrokeTransparency = 0.3, TextStrokeColor3 = GOLDDK})
		TweenService:Create(t, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Size = size}):Play()
		return t
	end

	go.Activated:Connect(function()
		if puBusy then return end
		if not can then
			if odds then note("Get more stuff first: " .. Data.CostText(cost), false) end
			return
		end
		puBusy = true
		local res = act("UpgradeGear", gearId)
		if type(res) ~= "table" or not res.Ok then
			puBusy = false
			note(type(res) == "table" and res.Error or "❌", false)
			return
		end

		-- 🔨 FORGING: three hammer hits, each one louder and brighter
		clearArea()
		title.Text = "Forging…"
		closeB.Visible = false
		local skip = false
		local skipB = Instance.new("TextButton")
		skipB.Text, skipB.BackgroundTransparency, skipB.Size, skipB.ZIndex = "", 1, UDim2.fromScale(1, 1), Z + 9
		skipB.Parent = card
		skipB.Activated:Connect(function() skip = true end)
		local dots = {}
		for k = 1, 3 do
			local d = F(area, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, (k - 2) * 26, 0, 30), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = NAVY3, ZIndex = Z + 1})
			round(d, 999)
			dots[k] = d
		end
		L(area, {Text = "Tap to skip", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 18), ZIndex = Z + 1, TextColor3 = MUTE})
		local hammer = L(card, {Text = "🔨", AnchorPoint = Vector2.new(0.2, 0.8), Position = UDim2.new(0.5, 70, 0, 100), Size = UDim2.fromOffset(70, 70), ZIndex = Z + 5, Rotation = -50})
		TweenService:Create(slot, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(65, 36, 2)}):Play()
		local slotSize = slot.Size
		for k = 1, 3 do
			if not skip then
				TweenService:Create(hammer, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = -60}):Play()
				task.wait(0.24)
				TweenService:Create(hammer, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Rotation = 15}):Play()
				task.wait(0.09)
			end
			-- CLANG!
			sfx(SND.anvil, 0.9 + k * 0.1, 0.55 + k * 0.12, 0.35)
			dots[k].BackgroundColor3 = GOLD
			ring.Color = NAVY3:Lerp(GOLD, k / 3)
			slot.Size = slotSize + UDim2.fromOffset(-12, -12)
			TweenService:Create(slot, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Size = slotSize}):Play()
			burst(k == 3 and "✨" or "🔸", 6 + k * 3, {GOLD, Color3.fromRGB(250, 199, 117), PALE}, 70 + k * 15)
			local clang = popText(k == 3 and "CLANG!!" or "CLANG!", Color3.fromRGB(250, 199, 117), 54, UDim2.fromOffset(120 + k * 20, 34 + k * 4))
			task.delay(0.3, function()
				TweenService:Create(clang, TweenInfo.new(0.2), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
				task.delay(0.21, function() clang:Destroy() end)
			end)
			if not skip then
				for s = 1, 4 do -- shake
					card.Position = home + UDim2.fromOffset(math.random(-k * 3, k * 3), math.random(-k * 2, k * 2))
					task.wait(0.025)
				end
				card.Position = home
				task.wait(k == 3 and 0.45 or 0.22) -- a little pause before the result
			end
		end
		card.Position = home
		hammer:Destroy()
		skipB:Destroy()
		clearArea()

		local flash = F(card, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = res.Win and Color3.new(1, 1, 1) or NAVY3, BackgroundTransparency = 0.1, ZIndex = Z + 8})
		round(flash, 26)
		TweenService:Create(flash, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()
		task.delay(0.65, function() flash:Destroy() end)
		if res.Win then
			-- ✨ SUCCESS: ding!
			sfx(SND.dingHi, 1, 0.9)
			sfx(SND.dingLo, 1, 0.45)
			TweenService:Create(card, TweenInfo.new(0.35), {BackgroundColor3 = FOREST}):Play()
			TweenService:Create(slot, TweenInfo.new(0.35), {BackgroundColor3 = FOREST2}):Play()
			ring.Color = LIME
			title.Text = "✨ Success ✨"
			title.TextColor3 = Color3.fromRGB(192, 221, 151)
			burst("⭐", 14, {Color3.fromRGB(255, 225, 90), LIME, PALE}, 150)
			nameL.Text = Data.GearName(g)
			local big = pill(area, "+" .. (res.Level or nextLv), Color3.fromRGB(59, 109, 17), PALE, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromOffset(0, 0)})
			TweenService:Create(big, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(110, 46)}):Play()
			local s1, sn = statText(g, res.Level or nextLv)
			L(area, {Text = ("%s %s → %s"):format(sn, s0, s1), Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 22), ZIndex = Z + 1, TextColor3 = Color3.fromRGB(192, 221, 151)})
			local ok = B(area, {Text = "Yay!", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 54), ZIndex = Z + 2,
				BackgroundColor3 = LIME, TextColor3 = FOREST}, function()
				puBusy = false
				openPowerUp(gearId)
			end)
			ok:FindFirstChildOfClass("UIStroke"):Destroy()
		else
			-- 💨 didn't stick: soft, no harsh buzzer
			sfx(SND.poof, 0.7, 0.7)
			TweenService:Create(slot, TweenInfo.new(0.35), {BackgroundColor3 = NAVY2}):Play()
			ring.Color = NAVY3
			title.Text = "Oops, so close!"
			local cloud = L(card, {Text = "💨", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 50, 0, 180), Size = UDim2.fromOffset(40, 40), ZIndex = Z + 6})
			TweenService:Create(cloud, TweenInfo.new(0.9), {Position = UDim2.new(0.5, 80, 0, 120), Size = UDim2.fromOffset(80, 80), TextTransparency = 1}):Play()
			task.delay(0.95, function() cloud:Destroy() end)
			L(area, {Text = "Still +" .. lv .. " · your gear is safe", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 24), ZIndex = Z + 1, TextColor3 = PALE})
			pill(area, ("🍀 Luck +%d%% next try"):format((res.Luck or 0) * 100 + 0.5), FOREST2, Color3.fromRGB(192, 221, 151),
				{AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 36), Size = UDim2.fromOffset(230, 32)})
			local again = B(area, {Text = "🔨 Try again", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 54), ZIndex = Z + 2,
				BackgroundColor3 = GOLD, TextColor3 = GOLDDK}, function()
				puBusy = false
				openPowerUp(gearId)
			end)
			again:FindFirstChildOfClass("UIStroke"):Destroy()
		end
		puBusy = false
		closeB.Visible = true
	end)
end

---------------------------------------------------------------- the bar buttons
local bagBtn = iconButton(bar, "🎒", "Bag", {Size = UDim2.fromOffset(78, 64), LayoutOrder = 1, BackgroundColor3 = Color3.fromRGB(230, 210, 170)}, function() openWindow("Bag") end)
local decoBtn = iconButton(bar, "🏡", "Decorate", {Size = UDim2.fromOffset(78, 64), LayoutOrder = 2, BackgroundColor3 = Color3.fromRGB(190, 240, 170)}, function()
	if deco.on then stopDecorate() else startDecorate() end
end)
bagBtn.Name, decoBtn.Name = "BagButton", "DecorateButton" -- CritterHooks shows them when your farm level unlocks them
iconButton(bar, "🏷️", "Titles", {Size = UDim2.fromOffset(78, 64), LayoutOrder = 3, BackgroundColor3 = Color3.fromRGB(255, 225, 150)}, function() openWindow("Titles") end)
-- toys you own: tap to play
local toyButtons = {}
local function refreshToys()
	for _, b in toyButtons do b:Destroy() end
	table.clear(toyButtons)
	local owned = {}
	for _, n in string.split(player:GetAttribute("Toys") or "Bubble Wand", ",") do owned[n] = true end
	for i, t in Data.Toys do
		if owned[t.Name] then
			local b = iconButton(bar, t.Icon, t.Name:match("^(%S+)"), {Size = UDim2.fromOffset(72, 64), LayoutOrder = 10 + i, BackgroundColor3 = Color3.fromRGB(220, 235, 255)},
				function() act("UseToy", t.Name) end)
			table.insert(toyButtons, b)
		end
	end
end
player:GetAttributeChangedSignal("Toys"):Connect(refreshToys)
refreshToys()

---------------------------------------------------------------- 🌰 acorn tracker + hide the ones you found
local acornChip = L(gui, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 60), Size = UDim2.fromOffset(170, 40), BackgroundTransparency = 0,
	BackgroundColor3 = Color3.fromRGB(255, 235, 170), Text = "🌰 0/30"})
round(acornChip, 12)
local luckyChip = L(gui, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 106), Size = UDim2.fromOffset(250, 40), BackgroundTransparency = 0,
	BackgroundColor3 = Color3.fromRGB(200, 255, 190), Text = "🍀"})
round(luckyChip, 12)
local function refreshAcorns()
	acornChip.Text = ("🌰 Acorns %d/%d"):format(player:GetAttribute("AcornCount") or 0, Data.AcornCount)
	local found = {}
	for _, id in string.split(player:GetAttribute("AcornsFound") or "", ",") do found[id] = true end
	local folder = root:FindFirstChild("Acorns")
	for _, a in folder and folder:GetChildren() or {} do
		local got = found[tostring(a:GetAttribute("Id"))]
		for _, d in a:GetDescendants() do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = got and 1 or 0 end
			if d:IsA("ProximityPrompt") then d.Enabled = not got end
			if d:IsA("ParticleEmitter") then d.Enabled = not got end
		end
	end
end
player:GetAttributeChangedSignal("AcornsFound"):Connect(refreshAcorns)
player:GetAttributeChangedSignal("AcornCount"):Connect(refreshAcorns)
task.delay(3, refreshAcorns)
task.spawn(function() -- prompts are added by the server a moment later
	while true do
		task.wait(10)
		refreshAcorns()
	end
end)
task.spawn(function()
	while true do
		local now = os.time()
		local untilT = workspace:GetAttribute("LuckyUntil") or 0
		if untilT > now then
			local s = untilT - now
			luckyChip.Text = ("🍀 LUCKY HOUR! 2x Shiny  %d:%02d"):format(s // 60, s % 60)
			luckyChip.BackgroundColor3 = (now % 2 == 0) and Color3.fromRGB(200, 255, 190) or Color3.fromRGB(255, 240, 150)
		else
			local s = math.max(0, (workspace:GetAttribute("LuckyNext") or now) - now)
			luckyChip.Text = ("🍀 Lucky hour in %dh %02dm"):format(s // 3600, (s % 3600) // 60)
			luckyChip.BackgroundColor3 = Color3.fromRGB(225, 240, 220)
		end
		task.wait(1)
	end
end)

---------------------------------------------------------------- 🎡 town life: the carousel turns, balloons bob (only on your screen, so it's smooth)
task.spawn(function()
	local td = root:WaitForChild("TownDressing", 60)
	if not td then return end
	task.wait(2)
	local spin, bob = {}, {}
	for _, m in td:GetChildren() do
		local p = m:IsA("Model") and (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true))
		if p and m.Name == "Carousel" then table.insert(spin, {p = p, cf = p.CFrame}) end
		if p and m.Name == "Balloons" then table.insert(bob, {p = p, cf = p.CFrame, t = math.random() * 6}) end
	end
	if #spin == 0 and #bob == 0 then return end
	local t0 = os.clock()
	game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - t0
		for _, s in spin do s.p.CFrame = s.cf * CFrame.Angles(0, t * 0.35, 0) end
		for _, b in bob do b.p.CFrame = b.cf * CFrame.new(0, math.sin(t * 1.3 + b.t) * 0.35, 0) * CFrame.Angles(0, 0, math.sin(t * 0.9 + b.t) * 0.05) end
	end)
end)

---------------------------------------------------------------- 🐟 koi swimming around the gazebo in the park pond (only on your screen, so it's smooth)
task.spawn(function()
	local td = root:WaitForChild("TownDressing", 60)
	local park = td and td:WaitForChild("Park", 30)
	local folder = park and park:WaitForChild("PondFish", 30)
	if not folder then return end
	task.wait(1)
	local fish = {}
	for _, m in folder:GetChildren() do
		local p = m:IsA("Model") and (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true))
		if p then
			table.insert(fish, {p = p, cx = m:GetAttribute("CX") or 0, cz = m:GetAttribute("CZ") or 0, r = m:GetAttribute("R") or 10,
				speed = m:GetAttribute("Speed") or 0.25, phase = m:GetAttribute("Phase") or 0, y = m:GetAttribute("Y") or 1.4})
		end
	end
	local t0 = os.clock()
	game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - t0
		for _, f in fish do
			local a = f.phase + t * f.speed
			local r = f.r + math.sin(t * 0.7 + f.phase) * 0.8
			local pos = Vector3.new(f.cx + math.cos(a) * r, f.y + math.sin(t * 1.6 + f.phase) * 0.12, f.cz + math.sin(a) * r)
			local dir = Vector3.new(-math.sin(a), 0, math.cos(a)) * (f.speed >= 0 and 1 or -1)
			f.p.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.sin(t * 6 + f.phase) * 0.12, 0)
		end
	end)
end)

---------------------------------------------------------------- 🪧 sign chips: a small white icon above each shop/portal/island spot; it opens to show the name when
-- you walk near and fades away when you're right at the door (made on your screen only).
-- Chips come from parts in Workspace.CritterAcres.TownChips AND any part with the CollectionService tag "Chip" (island signs).
-- Attributes on the part (all can change any time):
--   Icon, Label · Alert = true: yellow and always open (something is ready / waiting for you) · Open = true: always open
--   Hidden = true: no chip right now · ChipY = studs above the part's middle (tagged parts; default just above the top)
task.spawn(function()
	local folder = root:WaitForChild("TownChips", 60)
	local TS = game:GetService("TweenService")
	local TextService = game:GetService("TextService")
	local CollectionService = game:GetService("CollectionService")
	local WHITE_BG, WHITE_LINE = Color3.new(1, 1, 1), Color3.fromRGB(225, 215, 200)
	local ALERT_BG, ALERT_LINE = Color3.fromRGB(255, 225, 120), Color3.fromRGB(230, 170, 50)
	local chips = {} -- part -> chip
	local function fit(c)
		local p = c.p
		local label = p:GetAttribute("Label") or ""
		c.icon.Text = p:GetAttribute("Icon") or ""
		c.name.Text = label
		c.w = math.min(46 + TextService:GetTextSize(label, 20, Enum.Font.BuilderSansBold, Vector2.new(1000, 46)).X + 16, 376)
		if c.tagged then
			c.bb.StudsOffset = Vector3.new(0, p:GetAttribute("ChipY") or (p.Size.Y / 2 + 1.5), 0)
		end
		local alert = p:GetAttribute("Alert") == true
		c.pill.BackgroundColor3 = alert and ALERT_BG or WHITE_BG
		c.stroke.Color = alert and ALERT_LINE or WHITE_LINE
		c.bb.Enabled = p:GetAttribute("Hidden") ~= true and label .. c.icon.Text ~= ""
		c.state = nil -- redo the open / closed look on the next tick
	end
	local function make(p, tagged)
		if not p:IsA("BasePart") or chips[p] then return end
		local bb = Instance.new("BillboardGui")
		bb.Name = "Chip"
		bb.Adornee = p
		bb.Size = UDim2.fromOffset(380, 52)
		bb.MaxDistance = tagged and 160 or 360
		bb.LightInfluence = 0
		local pill = Instance.new("Frame")
		pill.AnchorPoint = Vector2.new(0.5, 0.5)
		pill.Position = UDim2.fromScale(0.5, 0.5)
		pill.Size = UDim2.fromOffset(46, 46)
		pill.BackgroundColor3 = WHITE_BG
		pill.BackgroundTransparency = 0.05
		pill.ClipsDescendants = true
		Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
		local st = Instance.new("UIStroke")
		st.Color = WHITE_LINE
		st.Thickness = 1.5
		st.Parent = pill
		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(46, 46)
		icon.TextSize = 24
		icon.Font = Enum.Font.BuilderSans
		icon.Parent = pill
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(42, 0)
		name.Size = UDim2.new(1, -50, 1, 0)
		name.TextSize = 20
		name.Font = Enum.Font.BuilderSansBold
		name.TextColor3 = Color3.fromRGB(60, 50, 45)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTransparency = 1
		name.Parent = pill
		pill.Parent = bb
		bb.Parent = p
		local c = {p = p, bb = bb, pill = pill, icon = icon, name = name, stroke = st, w = 46, tagged = tagged}
		chips[p] = c
		fit(c)
		for _, a in {"Icon", "Label", "Alert", "Hidden", "ChipY", "Open"} do
			p:GetAttributeChangedSignal(a):Connect(function() if chips[p] then fit(c) end end)
		end
	end
	if folder then
		for _, c in folder:GetChildren() do make(c, false) end
		folder.ChildAdded:Connect(function(c) make(c, false) end)
	end
	for _, p in CollectionService:GetTagged("Chip") do make(p, true) end
	CollectionService:GetInstanceAddedSignal("Chip"):Connect(function(p) make(p, true) end)
	CollectionService:GetInstanceRemovedSignal("Chip"):Connect(function(p)
		local c = chips[p]
		if c then c.bb:Destroy() chips[p] = nil end
	end)
	local ti = TweenInfo.new(0.3, Enum.EasingStyle.Quad)
	while true do
		task.wait(0.2)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			for p, c in chips do
				if not p:IsDescendantOf(workspace) then
					c.bb:Destroy()
					chips[p] = nil
				elseif c.bb.Enabled then
					local d = Vector3.new(p.Position.X - hrp.Position.X, 0, p.Position.Z - hrp.Position.Z).Magnitude
					local open = p:GetAttribute("Alert") == true or p:GetAttribute("Open") == true
					local state = d < 11 and "hide" or ((d < 36 or open) and "near" or "far")
					if state ~= c.state then
						c.state = state
						local gone = state == "hide" and 1 or 0
						TS:Create(c.pill, ti, {Size = UDim2.fromOffset(state == "near" and c.w or 46, 46), BackgroundTransparency = state == "hide" and 1 or 0.05}):Play()
						TS:Create(c.icon, ti, {TextTransparency = gone}):Play()
						TS:Create(c.name, ti, {TextTransparency = state == "near" and 0 or 1}):Play()
						TS:Create(c.stroke, ti, {Transparency = gone}):Play()
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------- 🛝 playground: trampolines and bounce pads
task.spawn(function()
	local pg = root:WaitForChild("Playground", 30)
	if not pg then return end
	local last = 0
	for _, p in pg:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "Bounce" then
			p.Touched:Connect(function(hit)
				local char = player.Character
				if not char or not hit:IsDescendantOf(char) or os.clock() - last < 0.4 then return end
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum then return end
				last = os.clock()
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
				local v = hrp.AssemblyLinearVelocity
				hrp.AssemblyLinearVelocity = Vector3.new(v.X, p:GetAttribute("Power") or 70, v.Z)
				TweenService:Create(p, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {Size = p.Size * Vector3.new(1, 0.5, 1)}):Play()
			end)
		end
	end
end)

---------------------------------------------------------------- new title popup
revealEvent.OnClientEvent:Connect(function(info)
	if info.Kind ~= "Title" then return end
	local def = Data.TitleByName[info.Name]
	if not def then return end
	local c = F(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -160), Size = UDim2.fromOffset(420, 130), BackgroundColor3 = Color3.fromRGB(255, 240, 190), ZIndex = 60})
	round(c, 22)
	L(c, {Text = "🏷️ New title!", Size = UDim2.new(1, 0, 0.4, 0), ZIndex = 61})
	L(c, {Text = def.Icon .. " " .. def.Name, Position = UDim2.fromScale(0, 0.42), Size = UDim2.new(1, 0, 0.5, 0), ZIndex = 61, TextColor3 = Color3.fromRGB(200, 120, 20)})
	CritterUI.Glow(c, "Legendary", Color3.fromRGB(255, 200, 60))
	TweenService:Create(c, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0, 170)}):Play()
	task.delay(4, function()
		TweenService:Create(c, TweenInfo.new(0.3), {Position = UDim2.new(0.5, 0, 0, -160)}):Play()
		task.wait(0.35)
		c:Destroy()
	end)
end)

---------------------------------------------------------------- build mode keys (like popular building games)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local key = input.KeyCode
	if key == Enum.KeyCode.N then
		if deco.on then stopDecorate() elseif (player:GetAttribute("FarmLevel") or 1) >= (Data.ButtonUnlocks.Decorate or 1) or player:GetAttribute("JourneyKind") == "Decor" then startDecorate() end
		return
	end
	if not deco.on then return end
	local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	local flash = nil
	if key == Enum.KeyCode.R then
		rotate(shift and -1 or 1)
		flash = "Rotate"
	elseif key == Enum.KeyCode.E then
		setMode(deco.pick and "Build" or "Move")
		flash = "Move"
	elseif key == Enum.KeyCode.X or key == Enum.KeyCode.Delete or key == Enum.KeyCode.Backspace then
		setMode(deco.remove and "Build" or "Remove")
		flash = "Remove"
	elseif key == Enum.KeyCode.G then
		deco.grid = deco.grid == 1 and 2 or (deco.grid == 2 and 4 or 1)
		renderDeco()
		K.toast(gui, ("▦ Grid: %d stud%s"):format(deco.grid, deco.grid > 1 and "s" or ""), true)
		flash = "Grid"
	elseif key == Enum.KeyCode.Q then
		deco.pick, deco.remove = false, false
		setGhost(nil)
		renderDeco()
		flash = "Cancel"
	else
		local n = key.Value - Enum.KeyCode.One.Value + 1
		if n >= 1 and n <= 9 and deco.slots[n] then
			deco.pick, deco.remove = false, false
			setGhost(deco.slots[n])
			renderDeco()
			flash = "Pick"
		end
	end
	if flash then flashKey(flash) end
end)

---------------------------------------------------------------- the new menus (CritterMenus) open our screens
local bridge = ReplicatedStorage:WaitForChild("CritterUIBridge")
bridge.Event:Connect(function(cmd, arg)
	if cmd == "Decorate" then
		if not deco.on then startDecorate() end
		if arg then
			deco.pick, deco.remove = false, false
			setGhost(arg)
			renderDeco()
		end
	elseif cmd == "Bench" then
		benchTab = arg or "Tools"
		openWin = nil
		openWindow("Bench")
	elseif cmd == "PowerUp" then
		openPowerUp(arg)
	elseif cmd == "Titles" then
		openWin = nil
		openWindow("Titles")
	elseif cmd == "HideOld" then
		bar.Visible = false
		acornChip.Visible = false
		luckyChip.Visible = false
	end
end)
