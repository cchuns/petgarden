-- Critter Acres: CritterWorld (StarterPlayerScripts LocalScript)
--   🎒 Bag: your resources and tool level
--   🔨 Workbench window (prompt on the plaza workbench): Tools, Gear (craft + ⭐ upgrade), Farm (decorations + soil), Toys
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
local renderBench
local openPowerUp -- the ⭐ power-up screen (below)
local SELECTED, SELECTED_LINE = Color3.fromRGB(255, 225, 130), Color3.fromRGB(230, 170, 50)
function renderBench()
	clear()
	win.setTitle("🔨", "Workbench")
	win.setSub("Make tools, pet gear and farm things")
	win.setTabs({{"Tools", "⛏️ Tools", "Better tools break harder trees and rocks"}, {"Gear", "🛡️ Pet gear", "Make gear for your pets and power it up"},
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
		for i, d in Data.Decor do
			local owned = (info.DecorInv or {})[d.Name] or 0
			local sub = Data.CostText(d.Cost) .. (owned > 0 and (" · have " .. owned) or "")
			if d.Effect then sub = (d.Effect == "Water" and "💦 waters · " or "🐝 faster · ") .. sub end
			card(g, i, d.Icon, d.Name, sub, "Buy", have(d.Cost, info), function() done(act("BuyDecor", d.Name), d.Icon .. " " .. d.Name .. " bought! Place it with 🏡 Decorate") end,
				need(d.Cost, info))
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

---------------------------------------------------------------- 🏡 decorate mode
-- build mode: Build (place), Move (E), Remove (X). Keys like popular building games:
--   1-9 pick an item · R rotate (Shift+R back) · E move · X / Delete remove · G grid size · Q cancel · N open / close (B is the bag)
local deco = {on = false, item = nil, ghost = nil, rot = 0, pick = false, remove = false, grid = 1, slots = {}}
local decoPanel = F(gui, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(0.86, 0, 0, 150),
	BackgroundColor3 = Color3.fromRGB(45, 35, 70), BackgroundTransparency = 0.1, Visible = false, ZIndex = 30})
round(decoPanel, 18)
Instance.new("UISizeConstraint", decoPanel).MaxSize = Vector2.new(900, 150)
local decoHint = L(decoPanel, {Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.5, -12, 0, 30), ZIndex = 31, TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left})
-- the key bar sits above the panel so you always see the shortcuts
local keyBar = F(gui, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -168), Size = UDim2.fromOffset(760, 40), BackgroundTransparency = 1, Visible = false, ZIndex = 30})
local kbl = Instance.new("UIListLayout", keyBar)
kbl.FillDirection = Enum.FillDirection.Horizontal
kbl.HorizontalAlignment = Enum.HorizontalAlignment.Center
kbl.Padding = UDim.new(0, 6)
local keyChips = {}
for i, k in {{"1-9", "Pick"}, {"R", "Rotate"}, {"E", "Move"}, {"X", "Remove"}, {"G", "Grid"}, {"Q", "Cancel"}, {"N", "Done"}} do
	local chip = F(keyBar, {Size = UDim2.fromOffset(i == 1 and 104 or 98, 38), BackgroundColor3 = Color3.fromRGB(45, 35, 70), BackgroundTransparency = 0.1, LayoutOrder = i, ZIndex = 30})
	round(chip, 10)
	local key = L(chip, {Text = k[1], Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(i == 1 and 42 or 30, 30), BackgroundTransparency = 0, BackgroundColor3 = WHITE, ZIndex = 31})
	round(key, 6)
	L(chip, {Text = k[2], Position = UDim2.fromOffset(i == 1 and 50 or 38, 4), Size = UDim2.new(1, i == 1 and -54 or -42, 0, 30), TextColor3 = WHITE, ZIndex = 31,
		TextXAlignment = Enum.TextXAlignment.Left})
	keyChips[k[2]] = chip
end
keyBar.Visible = false
local decoList = Instance.new("ScrollingFrame")
decoList.Position = UDim2.fromOffset(10, 38)
decoList.Size = UDim2.new(1, -250, 0, 104)
decoList.BackgroundTransparency = 1
decoList.BorderSizePixel = 0
decoList.ScrollingDirection = Enum.ScrollingDirection.X
decoList.AutomaticCanvasSize = Enum.AutomaticSize.X
decoList.CanvasSize = UDim2.new()
decoList.ScrollBarThickness = 4
decoList.ZIndex = 31
decoList.Parent = decoPanel
local dl = Instance.new("UIListLayout", decoList)
dl.FillDirection = Enum.FillDirection.Horizontal
dl.Padding = UDim.new(0, 8)
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
local renderDeco
local modeButtons -- set below with the side buttons
function renderDeco()
	for _, ch in decoList:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local info = act("CraftInfo") or {DecorInv = {}, Res = {}}
	-- owned first, then everything else with its price (tap a price to buy it right here)
	local list = {}
	for _, d in Data.Decor do
		if ((info.DecorInv or {})[d.Name] or 0) > 0 then table.insert(list, d) end
	end
	for _, d in Data.Decor do
		if ((info.DecorInv or {})[d.Name] or 0) == 0 then table.insert(list, d) end
	end
	deco.slots = {}
	for _, d in list do
		local n = (info.DecorInv or {})[d.Name] or 0
		if n > 0 and #deco.slots < 9 then table.insert(deco.slots, d.Name) end
		local slotNum = n > 0 and table.find(deco.slots, d.Name) or nil
		local on = deco.item == d.Name
		local can = n > 0 or have(d.Cost, info)
		local b = iconButton(decoList, d.Icon, n > 0 and ("%s x%d"):format(d.Name, n) or ("🛒 " .. Data.CostText(d.Cost)), {Size = UDim2.fromOffset(120, 98), ZIndex = 32,
			BackgroundColor3 = on and Color3.fromRGB(255, 225, 120) or (n > 0 and CREAM or (can and Color3.fromRGB(215, 245, 205) or GREY))}, function()
			deco.pick = false
			if n == 0 then
				local res = act("BuyDecor", d.Name)
				if type(res) == "table" and res.Ok then
					note(("%s %s bought! Tap your farm to place it."):format(d.Icon, d.Name))
					setGhost(d.Name)
				else
					note(type(res) == "table" and res.Error or "❌", false)
				end
				renderDeco()
				return
			end
			setGhost(deco.item ~= d.Name and d.Name or nil)
			renderDeco()
		end)
		if on then b.UIStroke.Thickness = 4 end
		if slotNum then
			local num = L(b, {Text = tostring(slotNum), Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0,
				BackgroundColor3 = Color3.fromRGB(45, 35, 70), TextColor3 = WHITE, ZIndex = 34})
			round(num, 6)
		end
	end
	decoHint.Text = (deco.remove and "🗑️ REMOVE: tap a decoration to put it back in your bag")
		or (deco.pick and "✋ MOVE: tap a decoration to pick it up")
		or (deco.item and ("🧱 BUILD: tap your farm to place %s"):format(deco.item)) or "🧱 BUILD: pick a decoration below (or press 1-9)"
	if modeButtons then modeButtons() end
end
decoList.Size = UDim2.new(1, -384, 0, 104)
local side = F(decoPanel, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 38), Size = UDim2.fromOffset(364, 104), BackgroundTransparency = 1, ZIndex = 31})
local sgl = Instance.new("UIGridLayout", side)
sgl.CellSize = UDim2.fromOffset(116, 48)
sgl.CellPadding = UDim2.fromOffset(8, 8)
sgl.SortOrder = Enum.SortOrder.LayoutOrder
local function setMode(m)
	deco.pick, deco.remove = m == "Move", m == "Remove"
	if m ~= "Build" then setGhost(nil) end
	renderDeco()
end
local function rotate(dir) deco.rot = (deco.rot + 45 * (dir or 1)) % 360 end
local function stopDecorate()
	deco.on, deco.pick, deco.remove = false, false, false
	setGhost(nil)
	decoPanel.Visible = false
	keyBar.Visible = false
end
local mb = {}
mb.Build = B(side, {Text = "🧱 Build", ZIndex = 32, LayoutOrder = 1}, function() setMode("Build") end)
mb.Move = B(side, {Text = "✋ Move (E)", ZIndex = 32, LayoutOrder = 2}, function() setMode(deco.pick and "Build" or "Move") end)
mb.Remove = B(side, {Text = "🗑️ Remove (X)", ZIndex = 32, LayoutOrder = 3}, function() setMode(deco.remove and "Build" or "Remove") end)
B(side, {Text = "↻ Rotate (R)", ZIndex = 32, LayoutOrder = 4}, function() rotate(1) end)
mb.Grid = B(side, {Text = "▦ Grid 1 (G)", ZIndex = 32, LayoutOrder = 5}, function()
	deco.grid = deco.grid == 1 and 2 or (deco.grid == 2 and 4 or 1)
	renderDeco()
end)
B(side, {Text = "✔ Done (N)", ZIndex = 32, LayoutOrder = 6, BackgroundColor3 = GREEN}, stopDecorate)
function modeButtons()
	local mode = deco.remove and "Remove" or (deco.pick and "Move" or "Build")
	for name, b in mb do
		if name ~= "Grid" then b.BackgroundColor3 = name == mode and Color3.fromRGB(255, 225, 120) or CREAM end
	end
	mb.Grid.Text = ("▦ Grid %d (G)"):format(deco.grid)
end
local function startDecorate()
	if not myFarm() then
		note("You need a farm first!", false)
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local g = myFarm():FindFirstChild("Ground")
	if not hrp or not g or (hrp.Position - g.Position).Magnitude > 120 then
		note("🏝️ Go to your island to decorate! Use a 🌀 portal.", false)
		return
	end
	deco.on = true
	deco.pick, deco.remove = false, false
	decoPanel.Visible = true
	keyBar.Visible = not UserInputService.TouchEnabled or UserInputService.KeyboardEnabled
	window.Visible = false
	renderDeco()
end
-- where the mouse / finger points on your farm ground
local function pointOnFarm(screenPos)
	local farm = myFarm()
	if not farm then return nil end
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
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
local lastPointer = Vector2.new(0, 0)
RunService.RenderStepped:Connect(function()
	if not (deco.on and deco.ghost) then return end
	local mp = UserInputService:GetMouseLocation()
	local pos = UserInputService.TouchEnabled and lastPointer or Vector2.new(mp.X, mp.Y - 36)
	local farm, x, z = pointOnFarm(pos)
	local hl = deco.ghost:FindFirstChild("Fit")
	if farm then
		deco.ghost:PivotTo(farm.Ground.CFrame * CFrame.new(x, farm.Ground.Size.Y / 2, z) * CFrame.Angles(0, math.rad(deco.rot), 0))
		if hl then hl.FillColor = Color3.fromRGB(110, 230, 110) end
	elseif hl then
		hl.FillColor = Color3.fromRGB(240, 90, 90)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then lastPointer = Vector2.new(input.Position.X, input.Position.Y) end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not deco.on or processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	lastPointer = pos
	if deco.pick or deco.remove then -- move: pick it up and carry it · remove: put it back in your bag
		local farm = myFarm()
		local folder = farm and farm:FindFirstChild("Decor")
		if not folder then return end
		local ray = camera:ViewportPointToRay(pos.X, pos.Y)
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
					note(("🗑️ %s is back in your bag"):format(res.Name or "It"))
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
		local farm, x, z = pointOnFarm(pos)
		if not farm then return end
		local res = act("PlaceDecor", deco.item, x, z, deco.rot)
		if type(res) == "table" and res.Ok then
			local left = (res.Info.DecorInv or {})[deco.item] or 0
			if left <= 0 then setGhost(nil) end
			renderDeco()
		elseif type(res) == "table" then
			note(res.Error, false)
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
	if deco.on then
		deco.on = false
		setGhost(nil)
		decoPanel.Visible = false
	else
		startDecorate()
	end
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
		note(("▦ Grid: %d stud%s"):format(deco.grid, deco.grid > 1 and "s" or ""))
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
	local chip = flash and keyChips[flash]
	if chip then
		chip.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
		task.delay(0.2, function() chip.BackgroundColor3 = Color3.fromRGB(45, 35, 70) end)
	end
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
