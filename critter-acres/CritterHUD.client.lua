-- Critter Acres: CritterHUD (StarterPlayerScripts)
-- Counters, seed picker, hint, weather banner, toast queue, and the
-- Book / Pets / Quests menus.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local actionFn = ReplicatedStorage:WaitForChild("CritterAction")
local stateEvent = ReplicatedStorage:WaitForChild("CritterState")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "CritterHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1 -- toasts and the pet profile sit above our window layer
gui.Parent = player:WaitForChild("PlayerGui")

local CREAM, BROWN = Color3.fromRGB(255, 250, 235), Color3.fromRGB(90, 60, 40)
local PICKED, GREEN = Color3.fromRGB(255, 225, 120), Color3.fromRGB(150, 230, 130)

local function style(t, props)
	t.BackgroundColor3 = CREAM
	if not t:IsA("Frame") then
		t.TextColor3 = BROWN
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
	end
	for k, v in props do t[k] = v end
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 12)
	local pad = Instance.new("UIPadding", t)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	local stroke = Instance.new("UIStroke", t)
	stroke.Color, stroke.Thickness = Color3.fromRGB(230, 190, 140), 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return t
end
local function label(parent, props)
	local t = style(Instance.new("TextLabel"), props)
	t.Parent = parent
	return t
end
local function label_(parent, props) -- plain text, no box
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextColor3 = BROWN
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.ZIndex = 12
	for k, v in props do t[k] = v end
	t.Parent = parent
	return t
end
local UI = require(ReplicatedStorage:WaitForChild("UIKit"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))
local function button(parent, props, onClick)
	local bg = props.BackgroundColor3
	props.BackgroundColor3 = nil
	props.AutoButtonColor = nil
	local b = UI.button(parent, props, onClick)
	if bg then
		b.BackgroundColor3 = bg
		b.UIStroke.Color = bg:Lerp(Color3.new(0, 0, 0), 0.15)
	end
	return b
end


---------------------------------------------------------------- toasts (queued)
-- quiet floating text in the upper middle of the screen: no box, soft outline, fades in and out
local TOAST_Y = 0.24
local toast = label_(gui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, TOAST_Y, 8),
	Size = UDim2.new(0.6, 0, 0, 34), TextColor3 = Color3.new(1, 1, 1), TextStrokeColor3 = Color3.fromRGB(40, 30, 25),
	TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 20, Text = ""})
Instance.new("UITextSizeConstraint", toast).MaxTextSize = 26
local queue, showing = {}, false
local function showNext()
	if showing or #queue == 0 then return end
	showing = true
	toast.Text = table.remove(queue, 1)
	toast.Position = UDim2.new(0.5, 0, TOAST_Y, 8)
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Position = UDim2.new(0.5, 0, TOAST_Y, 0),
		TextTransparency = 0.05, TextStrokeTransparency = 0.55}):Play()
	task.delay(#queue > 0 and 2.2 or 3.2, function()
		TweenService:Create(toast, TweenInfo.new(0.4), {TextTransparency = 1, TextStrokeTransparency = 1, Position = UDim2.new(0.5, 0, TOAST_Y, -6)}):Play()
		task.wait(0.45)
		showing = false
		showNext()
	end)
end
local function say(text)
	if type(text) ~= "string" or text == "" then return end
	table.insert(queue, text)
	if #queue > 4 then table.remove(queue, 1) end
	showNext()
end
ReplicatedStorage:WaitForChild("CritterNotify").OnClientEvent:Connect(say)

---------------------------------------------------------------- left column: counters + seed picker
local panel = Instance.new("Frame")
panel.BackgroundTransparency = 1
panel.Position = UDim2.fromOffset(12, 60)
panel.Size = UDim2.fromOffset(230, 520)
panel.Parent = gui
local list = Instance.new("UIListLayout", panel)
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder

-- farm level: ⭐ badge + XP bar
local farmRow = Instance.new("Frame")
farmRow.BackgroundTransparency = 1
farmRow.Size = UDim2.new(1, 0, 0, 44)
farmRow.LayoutOrder = 0
farmRow.Parent = panel
local farmBadge = label_(farmRow, {Size = UDim2.fromOffset(64, 44), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 190, 40),
	TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, ZIndex = 2})
Instance.new("UICorner", farmBadge).CornerRadius = UDim.new(0, 14)
local farmBarBg = Instance.new("Frame")
farmBarBg.Position = UDim2.new(0, 70, 0.2, 0)
farmBarBg.Size = UDim2.new(1, -70, 0.6, 0)
farmBarBg.BackgroundColor3 = Color3.fromRGB(230, 220, 205)
farmBarBg.Parent = farmRow
Instance.new("UICorner", farmBarBg).CornerRadius = UDim.new(1, 0)
local farmFill = Instance.new("Frame")
farmFill.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
farmFill.Size = UDim2.fromScale(0.05, 1)
farmFill.Parent = farmBarBg
Instance.new("UICorner", farmFill).CornerRadius = UDim.new(1, 0)
local farmText = label_(farmBarBg, {Size = UDim2.fromScale(1, 1), TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, ZIndex = 3})

local row = {Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Left}
local coinsLabel = label(panel, row)
coinsLabel.LayoutOrder = 1
local critterLabel = label(panel, row)
critterLabel.LayoutOrder = 2
-- berry bag: icon + count chips, 2 per row
local bag = Instance.new("Frame")
bag.BackgroundTransparency = 1
bag.Size = UDim2.new(1, 0, 0, 0)
bag.AutomaticSize = Enum.AutomaticSize.Y
bag.LayoutOrder = 3
bag.Parent = panel
local bagGrid = Instance.new("UIGridLayout", bag)
bagGrid.CellSize = UDim2.new(0.5, -3, 0, 40)
bagGrid.CellPadding = UDim2.fromOffset(6, 6)
local berryChips = {}
for _, crop in Data.Crops do
	berryChips[crop.Name] = label(bag, {TextXAlignment = Enum.TextXAlignment.Left})
end
-- special (mutated / big) berries: count and what they sell for
local specialChip = label(panel, {Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 4, TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundColor3 = Color3.fromRGB(240, 225, 255), Visible = false})
local function refreshSpecial()
	local n = player:GetAttribute("SpecialCount") or 0
	specialChip.Visible = n > 0
	specialChip.Text = ("🧬 %d   💰%d"):format(n, player:GetAttribute("SpecialValue") or 0)
end
player:GetAttributeChangedSignal("SpecialCount"):Connect(refreshSpecial)
player:GetAttributeChangedSignal("SpecialValue"):Connect(refreshSpecial)
refreshSpecial()

-- seed bag: one chip per seed you own (🍓 Puffberry is free forever). Tap to choose what you plant.
local seedRow = Instance.new("ScrollingFrame")
seedRow.BackgroundTransparency = 1
seedRow.BorderSizePixel = 0
seedRow.Size = UDim2.new(1, 0, 0, 66)
seedRow.LayoutOrder = 5
seedRow.ScrollingDirection = Enum.ScrollingDirection.X
seedRow.AutomaticCanvasSize = Enum.AutomaticSize.X
seedRow.CanvasSize = UDim2.new()
seedRow.ScrollBarThickness = 4
seedRow.Parent = panel
local seedList = Instance.new("UIListLayout", seedRow)
seedList.FillDirection = Enum.FillDirection.Horizontal
seedList.Padding = UDim.new(0, 5)
seedList.SortOrder = Enum.SortOrder.LayoutOrder
local seedChips = {}
for i, crop in Data.Crops do
	local b = button(seedRow, {Size = UDim2.fromOffset(52, 58), Text = "", LayoutOrder = i}, function()
		say(actionFn:InvokeServer("SelectSeed", crop.Name))
	end)
	b.UIPadding:Destroy()
	local icon = label_(b, {Size = UDim2.new(1, 0, 0.62, 0), ZIndex = 2})
	local count = label_(b, {Position = UDim2.fromScale(0, 0.6), Size = UDim2.new(1, 0, 0.38, 0), ZIndex = 2})
	seedChips[crop.Name] = {b = b, icon = icon, count = count}
end
local function refreshSeeds()
	local lv = player:GetAttribute("FarmLevel") or 1
	local chosen = player:GetAttribute("Seed") or Data.FarmCrop
	for _, crop in Data.Crops do
		local s = seedChips[crop.Name]
		local n = player:GetAttribute(Data.SeedAttr(crop.Name)) or 0
		local free = crop.Name == Data.FarmCrop
		s.b.Visible = free or n > 0 or chosen == crop.Name
		s.icon.Text = crop.Icon
		s.count.Text = free and "∞" or ("x" .. n)
		s.b.BackgroundColor3 = chosen == crop.Name and PICKED or CREAM
		s.b.UIStroke.Thickness = chosen == crop.Name and 4 or 2
		s.b.UIStroke.Color = chosen == crop.Name and Color3.fromRGB(255, 160, 40) or Data.Rarities[crop.Rarity].Color:Lerp(Color3.fromRGB(230, 190, 140), 0.4)
	end
	local need = player:GetAttribute("FarmXpNext")
	local have = player:GetAttribute("FarmXp") or 0
	farmBadge.Text = "⭐ " .. lv
	farmFill.Size = UDim2.fromScale(need and math.clamp(have / need, 0.04, 1) or 1, 1)
	farmText.Text = need and ("%d/%d"):format(have, need) or "MAX"
end
for _, a in {"FarmLevel", "FarmXp", "FarmXpNext", "Seed"} do
	player:GetAttributeChangedSignal(a):Connect(refreshSeeds)
end
for _, crop in Data.Crops do
	player:GetAttributeChangedSignal(Data.SeedAttr(crop.Name)):Connect(refreshSeeds)
end
refreshSeeds()
seedRow.LayoutOrder = 6

local hint = label(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(0.6, 0, 0, 34), BackgroundTransparency = 0.15})
Instance.new("UISizeConstraint", hint).MaxSize = Vector2.new(640, 34)
local weatherLabel = label(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50),
	Size = UDim2.fromOffset(300, 30), BackgroundColor3 = Color3.fromRGB(200, 230, 255), Visible = false})
local WEATHER_TEXT = {Rain = "🌧️ 💧x2", StarNight = "🌠 ⭐x5", GoldenSun = "☀️ 💰x2  🌟x3", Snow = "❄️ ❄️x4", Storm = "⛈️ ⚡x8"}
local function refreshWeather()
	local w = workspace:GetAttribute("Weather")
	weatherLabel.Visible = w ~= nil
	weatherLabel.Text = WEATHER_TEXT[w] or ""
end
workspace:GetAttributeChangedSignal("Weather"):Connect(refreshWeather)
refreshWeather()

---------------------------------------------------------------- menu buttons (right side)
local state = nil
local menuBar = Instance.new("Frame")
menuBar.BackgroundTransparency = 1
menuBar.AnchorPoint = Vector2.new(1, 0.5)
menuBar.Position = UDim2.new(1, -12, 0.5, 0)
menuBar.Size = UDim2.fromOffset(120, 5 * 56)
menuBar.Parent = gui
local barList = Instance.new("UIListLayout", menuBar)
barList.Padding = UDim.new(0, 8)

local winGui = Instance.new("ScreenGui")
winGui.Name = "CritterHUDWindow"
winGui.ResetOnSpawn = false
winGui.DisplayOrder = 0
winGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
winGui.Parent = player:WaitForChild("PlayerGui")
local win = UI.window(winGui, {Icon = "📖", Title = "Critter book"})
win.setTabs({})
local window = win.frame
-- pages set title.Text = "📜 Daily Quests": split it into the icon + title
local title = setmetatable({}, {__newindex = function(_, k, v)
	if k == "Text" then
		local i, r = tostring(v):match("^(%S+)%s*(.*)$")
		win.setTitle(i or "", r or "")
	end
end})
local scroll = win.body

local openMenu = nil
win.onClose = function() openMenu = nil end
local gearFor = nil -- pet id while picking gear in the Pets menu
local render
local MENUS = {}

local function clear()
	for _, ch in scroll:GetChildren() do
		if ch:IsA("GuiObject") or ch:IsA("UIGridLayout") or ch:IsA("UIListLayout") then ch:Destroy() end
	end
end
local function vlist()
	local l = Instance.new("UIListLayout", scroll)
	l.Padding = UDim.new(0, 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
end
local function timeLeft(at)
	local s = math.max(0, at - os.time())
	if s >= 3600 then return ("%dh %dm"):format(s // 3600, (s % 3600) // 60) end
	if s >= 60 then return ("%dm %ds"):format(s // 60, s % 60) end
	return ("%ds"):format(s)
end
local function act(...)
	local msg = actionFn:InvokeServer(...)
	say(msg)
end

-- one row: text on the left, optional buttons on the right
local function rowFrame(order, text, buttons, color)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, -12, 0, 44)
	f.LayoutOrder = order
	f.ZIndex = 11
	f.Parent = scroll
	local bw = 0
	for _, b in buttons or {} do bw += (b.W or 70) + 6 end
	local l = label(f, {Size = UDim2.new(1, -bw, 1, 0), Text = text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12})
	if color then l.UIStroke.Color = color; l.UIStroke.Thickness = 3 end
	local x = 0
	for _, b in buttons or {} do
		local w = b.W or 70
		x += w + 6
		button(f, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -(x - w - 6), 0, 0), Size = UDim2.new(0, w, 1, 0),
			Text = b.Text, ZIndex = 12, BackgroundColor3 = b.Color or GREEN}, b.Click)
	end
	return f
end

MENUS.Book = function()
	local grid = Instance.new("UIGridLayout", scroll)
	grid.CellSize = UDim2.fromOffset(150, 190)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	local found = 0
	for i, s in Data.Species do
		local have = state and state.Found[s.Species]
		if have then found += 1 end
		local rarity = Data.Rarities[s.Rarity]
		local where = table.concat(Data.SpeciesBiomes[s.Species] or {}, "")
		local shiny = have and state.FoundShiny and state.FoundShiny[s.Species]
		local c = UI.card(scroll, {Order = rarity.Order * 1000 + i, Name = have and ((shiny and "✨ " or "") .. s.Species) or "❔ ???",
			Sub = ("%s · 🥚"):format(s.Rarity), Color = rarity.Color,
			Tip = have and s.Species or "Not found yet", TipText = have and "Found! It hatched from an egg"
				or ("Hatch it from an 🥚 egg for 💰%d. Eggs come from the shop and from mobs in the wild lands!"):format(Data.FindReward[s.Rarity]),
			Art = have and function(pic)
				CritterUI.Portrait(pic, Data, s.Species, {Size = UDim2.fromScale(1, 1)})
			end or function(pic)
				pic.BackgroundColor3 = Color3.fromRGB(80, 74, 96)
				UI.text(pic, {Text = "❔", Size = UDim2.fromScale(1, 1), Max = 54, TextColor3 = Color3.fromRGB(220, 215, 235)})
			end})
		if not have then c.BackgroundColor3 = Color3.fromRGB(240, 236, 228) end
	end
	title.Text = "📖 Critter book"
	win.setSub(("%d of %d found"):format(found, #Data.Species))
	win.setHelp({{"🔍", "Explore the wild to find new critters."}, {"📖", "Every new critter fills a page here."}, {"💰", "You get coins the first time you find each one!"}})
end

local PackOpen = require(ReplicatedStorage:WaitForChild("PackOpen"))
local bridge = ReplicatedStorage:WaitForChild("CritterUIBridge") -- the new menus (CritterMenus) open our screens through this
local bridgeProfile = false
local EGG_COLOR = {Mystery = Color3.fromRGB(235, 215, 180), Crystal = Color3.fromRGB(150, 110, 255), Lava = Color3.fromRGB(255, 110, 60),
	Star = Color3.fromRGB(255, 215, 80), Harvest = Color3.fromRGB(230, 150, 60), Friend = Color3.fromRGB(255, 140, 180),
	CommonEgg = Color3.fromRGB(225, 225, 225), UncommonEgg = Color3.fromRGB(120, 210, 100), RareEgg = Color3.fromRGB(90, 160, 255), UltraEgg = Color3.fromRGB(255, 195, 50)}
local JOB_ICON = {Water = "💧", Harvest = "🧺", Plant = "🌱", Grow = "✨"}
local profileFor = nil -- pet id while viewing its profile
local confirmLetGo = false

---------------------------------------------------------------- reveal shows (egg hatch, lucky spin, prizes, level up)
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local tickSound = Instance.new("Sound")
tickSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
tickSound.Volume = 0.25
tickSound.Parent = gui

local overlay = Instance.new("Frame")
overlay.Name = "Reveal"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
overlay.BackgroundTransparency = 0.25
overlay.Visible = false
overlay.Active = true
overlay.ZIndex = 60
overlay.Parent = gui

local showQueue, showing = {}, false
local function runShows()
	if showing then return end
	local fn = table.remove(showQueue, 1)
	if not fn then return end
	showing = true
	for _, ch in overlay:GetChildren() do ch:Destroy() end
	overlay.Visible = true
	local ok, err = pcall(fn)
	if not ok then warn("reveal:", err) end
	for _, ch in overlay:GetChildren() do ch:Destroy() end
	overlay.Visible = false
	showing = false
	if render then render() end
	runShows()
end
local function queueShow(fn)
	table.insert(showQueue, fn)
	task.spawn(runShows)
end

local function O(props) -- label on the overlay
	props.ZIndex = props.ZIndex or 62
	return label_(overlay, props)
end
local function tween(obj, secs, goal, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(secs, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local function flash(color)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color or Color3.new(1, 1, 1)
	f.ZIndex = 80
	f.Parent = overlay
	tween(f, 0.6, {BackgroundTransparency = 1})
	task.delay(0.65, function() f:Destroy() end)
end
-- spinning light rays behind a reveal
local function rays(color)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.45)
	holder.Size = UDim2.fromOffset(1, 1)
	holder.ZIndex = 61
	holder.Parent = overlay
	for i = 0, 5 do
		local r = Instance.new("Frame")
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Size = UDim2.fromOffset(46, 1100)
		r.Rotation = i * 30
		r.BackgroundColor3 = color
		r.BorderSizePixel = 0
		r.ZIndex = 61
		local g = Instance.new("UIGradient", r)
		g.Rotation = 90
		g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1)})
		r.Parent = holder
		TweenService:Create(r, TweenInfo.new(9, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {Rotation = i * 30 + 360}):Play()
	end
	return holder
end
local function waitForTap(btnText)
	local done = false
	local b = button(overlay, {Text = btnText or "✔", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(160, 64),
		BackgroundColor3 = GREEN, ZIndex = 70}, function() done = true end)
	b.Size = UDim2.fromOffset(0, 0)
	tween(b, 0.3, {Size = UDim2.fromOffset(160, 64)}, Enum.EasingStyle.Back)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 30 do task.wait() end
end

-- A strip of cards that zooms past a ▼ marker and slows down onto cells[resultIndex].
local function playReel(cells, resultIndex, makeCell)
	local CELL, GAP = 140, 10
	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.new(0.92, 0, 0, 190)
	box.BackgroundColor3 = Color3.fromRGB(40, 32, 60)
	box.ClipsDescendants = true
	box.ZIndex = 62
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 20)
	box.Parent = overlay
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(0, #cells * (CELL + GAP), 1, -24)
	strip.ZIndex = 62
	strip.Parent = box
	for i, d in cells do
		local cell = Instance.new("Frame")
		cell.Position = UDim2.fromOffset((i - 1) * (CELL + GAP), 0)
		cell.Size = UDim2.new(0, CELL, 1, 0)
		cell.ZIndex = 63
		Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 16)
		cell.Parent = strip
		makeCell(cell, d)
	end
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.fromScale(0.5, 0)
	line.Size = UDim2.new(0, 6, 1, 0)
	line.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
	line.ZIndex = 70
	line.Parent = box
	O({Text = "▼", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.5, -95), Size = UDim2.fromOffset(60, 50),
		TextColor3 = Color3.fromRGB(255, 220, 80), ZIndex = 70})
	task.wait()
	local w = box.AbsoluteSize.X
	local startX = w / 2 - CELL / 2
	local finalX = w / 2 - ((resultIndex - 1) * (CELL + GAP) + CELL / 2) + (math.random() - 0.5) * CELL * 0.6
	strip.Position = UDim2.new(0, startX, 0, 12)
	local tw = tween(strip, 4.6, {Position = UDim2.new(0, finalX, 0, 12)}, Enum.EasingStyle.Quint)
	local last = -1
	local conn = RunService.RenderStepped:Connect(function()
		local idx = math.floor((w / 2 - strip.Position.X.Offset) / (CELL + GAP))
		if idx ~= last then
			last = idx
			tickSound.PlaybackSpeed = 0.9 + math.random() * 0.3
			SoundService:PlayLocalSound(tickSound)
		end
	end)
	tw.Completed:Wait()
	conn:Disconnect()
	-- pulse the winning card
	local win = strip:GetChildren()[resultIndex]
	if win then
		local s = Instance.new("UIStroke", win)
		s.Color, s.Thickness = Color3.fromRGB(255, 240, 120), 6
	end
	task.wait(0.7)
	return box
end

local function rollRarity(weights)
	local total = 0
	for _, w in weights do total += w end
	local r = math.random() * total
	for k, w in weights do
		r -= w
		if r <= 0 then return k end
	end
	return "Common"
end
local function speciesOf(rarity)
	local options = {}
	for _, s in Data.Species do
		if s.Rarity == rarity then table.insert(options, s.Species) end
	end
	return options[math.random(#options)] or Data.Species[1].Species
end

-- 🥚 tap tap tap → crack! → flip the card → big reveal ("1 in X", shiny, new...)
local function revealHatch(res)
	local egg = Data.Eggs[res.Egg] or Data.Eggs.Mystery
	local v = res.Variant and Data.VariantByName[res.Variant]
	local sz = res.SizeName and Data.SizeByName[res.SizeName]
	local badges = {}
	if res.Secret then table.insert(badges, "🤫 SECRET PET!") end
	if v then table.insert(badges, v.Icon .. " " .. v.Name:upper()) end
	if sz then table.insert(badges, sz.Icon .. " " .. sz.Name:upper()) end
	if res.New then table.insert(badges, "📖 NEW") end
	if res.Lucky then table.insert(badges, "🍀 LUCKY METER!") end
	local footer
	if res.Stored then
		footer = "📦 Your farm is full, so it went to storage (Pets menu)"
	elseif res.Luck then
		footer = ("🍀 Luck meter %d/%d (full = Epic or better!)"):format(res.Luck, Data.LuckMax)
	end
	PackOpen.Play(overlay, {Style = "Egg", Icon = egg.Icon, Title = egg.Name, Color = EGG_COLOR[res.Egg], Footer = footer, Cards = {{
		Rarity = res.Rarity, Color = v and v.Color or nil, Name = res.Species, Sub = "🍼 Baby", Odds = res.Odds, Badges = badges,
		Art = function(f, z)
			local vf = CritterUI.Portrait(f, Data, res.Species, {Size = UDim2.fromScale(1, 1), ZIndex = z}, {Variant = res.Variant})
			CritterUI.Animate(vf, "show")
			vf:SetAttribute("Hop", os.clock())
		end}}})
end

-- picture for one prize: big icon (or the spinning hat for outfits) + amount
local function prizeArt(parent, p, z, big)
	if p.Type == "Outfit" and p.Name then
		local vf = CritterUI.ModelView(parent, CritterUI.BuildOutfit(p.Name), {Size = UDim2.fromScale(1, big and 0.8 or 0.7), ZIndex = z}, {Yaw = 0})
		CritterUI.Animate(vf, "spin")
	else
		label_(parent, {Text = Data.PrizeIcon(p), Size = UDim2.fromScale(1, big and 0.8 or 0.66), ZIndex = z})
	end
	local amount = p.Amount and ("x" .. p.Amount) or ""
	if p.Dup then amount = "🔁 💰" .. p.Dup end
	label_(parent, {Text = amount, Position = UDim2.fromScale(0, big and 0.78 or 0.66), Size = UDim2.fromScale(1, big and 0.2 or 0.3),
		TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, ZIndex = z})
end

-- 🎁 prize pack: tear it open, flip the card
local function revealSpin(res)
	local p = res.Prize
	PackOpen.Play(overlay, {Style = "Pack", Icon = "🎁", Title = "Prize Pack", Color = Color3.fromRGB(255, 150, 90),
		Cards = {PackOpen.PrizeCard(Data, CritterUI, p)}})
end

-- ⭐ farm level up card
local function revealLevel(info)
	flash(Color3.fromRGB(255, 220, 90))
	rays(Color3.fromRGB(255, 200, 60))
	local star = O({Text = "⭐", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(0, 0)})
	O({Text = tostring(info.Level), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.37), Size = UDim2.fromOffset(120, 90),
		TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, ZIndex = 63})
	tween(star, 0.5, {Size = UDim2.fromOffset(260, 260)}, Enum.EasingStyle.Back)
	local rewards = {"💰 " .. info.Coins, "🎁 +" .. (info.Spins or 1)}
	for _, name in info.Unlocked or {} do table.insert(rewards, 1, "🔓 " .. Data.CropByName[name].Icon) end
	for i, text in rewards do
		local chip = O({Text = text, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, (i - (#rewards + 1) / 2) * 170, 0.64, 0),
			Size = UDim2.fromOffset(160, 64), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 240, 190)})
		Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 16)
	end
	waitForTap()
end

-- small prize card that slides up for a moment (presents, pet gifts); doesn't block play
local function prizePopup(p)
	local rc = Data.Rarities[p.Rarity or "Common"].Color
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, 200)
	card.Size = UDim2.fromOffset(170, 170)
	card.BackgroundColor3 = rc:Lerp(Color3.fromRGB(40, 32, 60), 0.3)
	card.ZIndex = 55
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 22)
	card.Parent = gui
	if p.From then
		local vf = CritterUI.Portrait(card, Data, p.From, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 30, 0, -40), Size = UDim2.fromOffset(80, 80), ZIndex = 57})
		CritterUI.Animate(vf, "idle")
	end
	prizeArt(card, p, 56, true)
	CritterUI.Glow(card, p.Rarity, rc)
	tween(card, 0.35, {Position = UDim2.new(0.5, 0, 1, -90)}, Enum.EasingStyle.Back)
	task.delay(2.8, function()
		tween(card, 0.3, {Position = UDim2.new(0.5, 0, 1, 220)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.35)
		card:Destroy()
	end)
end

ReplicatedStorage:WaitForChild("CritterReveal").OnClientEvent:Connect(function(info)
	if info.Kind == "Prize" then
		prizePopup(info.Prize)
	elseif info.Kind == "Hatch" and info.Result then
		queueShow(function() revealHatch(info.Result) end)
	elseif info.Kind == "LevelUp" then
		queueShow(function() revealLevel(info) end)
	end
end)

local function doHatch(id)
	local res = actionFn:InvokeServer("Hatch", id)
	if type(res) == "table" then queueShow(function() revealHatch(res) end) else say(res) end
end
local function doSpin()
	if showing then return end
	local res = actionFn:InvokeServer("Spin")
	if type(res) == "table" and res.Prize then queueShow(function() revealSpin(res) end) else say("🎡 0") end
end

local function bar(parent, y, icon, frac, color, label)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Position = UDim2.new(0, 0, 0, y)
	f.Size = UDim2.new(1, 0, 0, 34)
	f.ZIndex = 12
	f.Parent = parent
	local ic = label_(f, {Text = icon, Size = UDim2.fromOffset(34, 34)})
	local bg = Instance.new("Frame")
	bg.Position = UDim2.new(0, 40, 0.15, 0)
	bg.Size = UDim2.new(1, -40, 0.7, 0)
	bg.BackgroundColor3 = Color3.fromRGB(230, 220, 205)
	bg.ZIndex = 12
	Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
	bg.Parent = f
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(frac, 0.03, 1), 1)
	fill.BackgroundColor3 = color
	fill.ZIndex = 13
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	fill.Parent = bg
	label_(bg, {Text = label, Size = UDim2.fromScale(1, 1), TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, ZIndex = 14})
	return f
end

-- big profile card for one pet
local lastFed = {} -- pet id -> time, so the new portrait can do a happy hop
local lastPetted = {} -- pet id -> time (petting cooldown)
local WHITE = Color3.new(1, 1, 1)

local function tile(parent, props)
	local f = Instance.new("Frame")
	f.ZIndex = 12
	for k, v in props do f[k] = v end
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 16)
	f.Parent = parent
	return f
end

-- Full-screen pet profile: glowing stage with the big animated pet on the left,
-- name/role/stars header, ◀ ▶ to flip through pets, icon tabs on the right.
local profileTab = "Stats"
local profileScreen = Instance.new("Frame")
profileScreen.Name = "PetProfile"
profileScreen.Size = UDim2.fromScale(1, 1)
profileScreen.BackgroundColor3 = WHITE
profileScreen.Visible = false
profileScreen.ZIndex = 30
profileScreen.Active = true
profileScreen.Parent = gui

local function petOrder()
	local list = {}
	for _, p in state and state.Pets or {} do
		if not p.Stored then table.insert(list, p) end
	end
	for _, p in state and state.Pets or {} do
		if p.Stored then table.insert(list, p) end
	end
	return list
end

local function closeProfile()
	profileFor = nil
	confirmLetGo = false
	profileScreen.Visible = false
	if bridgeProfile then -- opened from the new Pets window: go back there
		bridgeProfile = false
		openMenu = nil
		window.Visible = false
		bridge:Fire("Reopen", "Pets")
		return
	end
	window.Visible = openMenu ~= nil
	render()
end

local function petProfile(p)
	window.Visible = false
	profileScreen.Visible = true
	for _, ch in profileScreen:GetChildren() do ch:Destroy() end
	local rarity = Data.Rarities[p.Rarity]
	local species = Data.SpeciesByName[p.Species]
	local Z = 31
	local function L(parent, props)
		props.ZIndex = props.ZIndex or Z + 2
		return label_(parent, props)
	end
	local function B(parent, props, fn)
		props.ZIndex = props.ZIndex or Z + 2
		return button(parent, props, fn)
	end

	-- background: rarity-tinted gradient, spotlight and a round stage
	local g = Instance.new("UIGradient", profileScreen)
	g.Color = ColorSequence.new(rarity.Color:Lerp(WHITE, 0.35), rarity.Color:Lerp(Color3.new(0.1, 0.08, 0.2), 0.55))
	g.Rotation = 100
	local glow = tile(profileScreen, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.3, 0.5), Size = UDim2.fromScale(0.42, 0.75),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.75, ZIndex = Z})
	glow.UICorner.CornerRadius = UDim.new(1, 0)
	local stage = tile(profileScreen, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.3, 0.84), Size = UDim2.fromScale(0.34, 0.09),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, ZIndex = Z})
	stage.UICorner.CornerRadius = UDim.new(1, 0)
	if rarity.Order >= 3 then -- sparkles drifting up for Epic and Legendary
		for _ = 1, 14 do
			local s = tile(profileScreen, {Size = UDim2.fromOffset(6, 6), Position = UDim2.fromScale(0.1 + math.random() * 0.4, 0.5 + math.random() * 0.4),
				BackgroundColor3 = WHITE, ZIndex = Z})
			s.UICorner.CornerRadius = UDim.new(1, 0)
			TweenService:Create(s, TweenInfo.new(2 + math.random() * 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{Position = s.Position - UDim2.fromScale(0, 0.15), BackgroundTransparency = 0.8}):Play()
		end
	end

	-- the pet, big and animated
	local vf = CritterUI.Portrait(profileScreen, Data, p.Species, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.3, 0.57),
		Size = UDim2.fromScale(0.46, 0.56), ZIndex = Z + 1}, {Sleepy = p.Rest ~= nil, Variant = p.Variant, Outfit = p.Outfit})
	if lastFed[p.Id] and os.clock() - lastFed[p.Id] < 1.5 then vf:SetAttribute("Hop", os.clock()) end
	CritterUI.Animate(vf, "show", p.Rest ~= nil)
	-- tap the pet to pet it: hearts float up, happiness goes up (🤚 hint pulses)
	if not p.Trip then
		local petBtn = Instance.new("TextButton")
		petBtn.Text = ""
		petBtn.BackgroundTransparency = 1
		petBtn.AnchorPoint = Vector2.new(0.5, 0.5)
		petBtn.Position = UDim2.fromScale(0.3, 0.57)
		petBtn.Size = UDim2.fromScale(0.36, 0.5)
		petBtn.ZIndex = Z + 2
		petBtn.Parent = profileScreen
		local hand = L(profileScreen, {Text = "🤚", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.46, 0.74), Size = UDim2.fromOffset(54, 54)})
		TweenService:Create(hand, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Rotation = 20, Size = UDim2.fromOffset(62, 62)}):Play()
		petBtn.Activated:Connect(function()
			if lastPetted[p.Id] and os.clock() - lastPetted[p.Id] < Data.PetCooldown then return end
			lastPetted[p.Id] = os.clock()
			lastFed[p.Id] = os.clock()
			vf:SetAttribute("Hop", os.clock())
			local center = vf.AbsolutePosition + vf.AbsoluteSize / 2
			for i = 1, 5 do
				local h = label_(gui, {Text = i == 3 and "💖" or "❤️", AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 50, Size = UDim2.fromOffset(46, 46),
					Position = UDim2.fromOffset(center.X + math.random(-90, 90), center.Y + math.random(-30, 40))})
				TweenService:Create(h, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Position = h.Position - UDim2.fromOffset(0, 160), TextTransparency = 1,
					Rotation = math.random(-30, 30)}):Play()
				task.delay(1.3, function() h:Destroy() end)
			end
			task.delay(0.6, function() actionFn:InvokeServer("Pet", p.Id) end) -- let the hop play before the screen refreshes
		end)
	end
	if p.Rest then L(profileScreen, {Text = "💤", Position = UDim2.fromScale(0.38, 0.2), Size = UDim2.fromOffset(70, 70)}) end
	if p.Trip then L(profileScreen, {Text = "🎒", Position = UDim2.fromScale(0.38, 0.2), Size = UDim2.fromOffset(70, 70)}) end

	-- top bar: back, name, role, stars
	B(profileScreen, {Text = "⬅ Back", Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(110, 52), BackgroundColor3 = UI.CARD, Tip = "Back",
		TipText = "Go back to your pets"}, closeProfile)
	local roleIcon = (JOB_ICON[species.Job] or "") .. " " .. Data.Classes[p.Class].Icon
	local vinfo = p.Variant and Data.VariantByName[p.Variant]
	local sinfo = p.SizeName and Data.SizeByName[p.SizeName]
	local stageInfo
	for _, st in Data.Stages do
		if st.Name == p.Stage then stageInfo = st end
	end
	L(profileScreen, {Text = (vinfo and vinfo.Icon .. " " or "") .. (p.Name or p.Species) .. (sinfo and " " .. sinfo.Icon or ""), AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.3, 0, 0, 14), Size = UDim2.new(0.4, 0, 0, 64), TextColor3 = vinfo and vinfo.Color or WHITE, TextStrokeTransparency = 0.2})
	L(profileScreen, {Text = ("%s%s %s   %s%s"):format(stageInfo and (stageInfo.Icon .. " " .. stageInfo.Name .. "  ") or "", p.Name and p.Species or "",
		roleIcon, string.rep("⭐", rarity.Order), p.Odds and p.Odds >= 100 and ("  🎲 " .. Data.OddsText(p.Odds)) or ""), AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.3, 0, 0, 80), Size = UDim2.new(0.5, 0, 0, 40), TextStrokeTransparency = 0.6})
	-- ✏️ name your pet
	B(profileScreen, {Text = "✏️ Name", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0.5, 4, 0, 22), Size = UDim2.fromOffset(110, 48),
		BackgroundColor3 = UI.CARD, Tip = "✏️ Name", TipText = "Give your pet a name"}, function()
		local box = tile(profileScreen, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(420, 200),
			BackgroundColor3 = UI.CREAM, ZIndex = Z + 20})
		UI.stroke(box, Color3.fromRGB(230, 205, 165), 3)
		L(box, {Text = "✏️ Name your pet", Size = UDim2.new(1, 0, 0, 50), ZIndex = Z + 21, TextColor3 = BROWN})
		local tb = Instance.new("TextBox")
		tb.PlaceholderText = p.Species
		tb.Text = p.Name or ""
		tb.ClearTextOnFocus = false
		tb.Font = Enum.Font.FredokaOne
		tb.TextScaled = true
		tb.Position = UDim2.fromOffset(20, 60)
		tb.Size = UDim2.new(1, -40, 0, 56)
		tb.BackgroundColor3 = Color3.fromRGB(245, 240, 230)
		tb.ZIndex = Z + 21
		Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 12)
		tb.Parent = box
		B(box, {Text = "✔ Save", Position = UDim2.new(0.5, 6, 1, -64), Size = UDim2.new(0.5, -26, 0, 52), BackgroundColor3 = GREEN, ZIndex = Z + 21}, function()
			local text = tb.Text
			box:Destroy()
			act("NamePet", p.Id, text)
		end)
		B(box, {Text = "✖ Cancel", Position = UDim2.new(0, 20, 1, -64), Size = UDim2.new(0.5, -26, 0, 52), BackgroundColor3 = Color3.fromRGB(240, 235, 225),
			ZIndex = Z + 21}, function() box:Destroy() end)
	end)
	local lv = L(profileScreen, {Text = tostring(p.Level), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.3, 0, 0, 126), Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 190, 40), TextColor3 = WHITE, TextStrokeTransparency = 0.3})
	Instance.new("UICorner", lv).CornerRadius = UDim.new(1, 0)

	-- ◀ ▶ flip through pets
	local list = petOrder()
	local idx = 1
	for i, q in list do
		if q.Id == p.Id then idx = i end
	end
	local function flip(d)
		local q = list[(idx - 1 + d) % #list + 1]
		profileFor = q.Id
		confirmLetGo = false
		render()
	end
	if #list > 1 then
		B(profileScreen, {Text = "◀", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.03, 0, 0.5, 0), Size = UDim2.fromOffset(64, 84),
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.2}, function() flip(-1) end)
		B(profileScreen, {Text = "▶", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.57, 0, 0.5, 0), Size = UDim2.fromOffset(64, 84),
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.2}, function() flip(1) end)
		L(profileScreen, {Text = ("%d / %d"):format(idx, #list), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.3, 0, 1, -16),
			Size = UDim2.fromOffset(120, 34), TextColor3 = WHITE, TextStrokeTransparency = 0.4})
	end

	-- right panel with icon tabs
	local panel = tile(profileScreen, {Position = UDim2.new(0.6, 0, 0, 90), Size = UDim2.new(0.38, 0, 1, -110), BackgroundColor3 = UI.CREAM,
		BackgroundTransparency = 0.04, ZIndex = Z + 1})
	panel.UICorner.CornerRadius = UDim.new(0, 22)
	UI.stroke(panel, Color3.fromRGB(230, 205, 165), 3)
	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.new(0.6, 0, 0, 24)
	tabs.Size = UDim2.new(0.38, 0, 0, 58)
	tabs.ZIndex = Z + 1
	tabs.Parent = profileScreen
	local tl = Instance.new("UIListLayout", tabs)
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0.03, 0)
	local tabList = {{"Stats", "📊 Stats"}, {"Feed", "🍓 Feed"}, {"Outfit", "👒 Hats"}}
	table.insert(tabList, 2, {"Gear", "🎒 Gear"})
	local tabW = (1 - 0.03 * (#tabList - 1)) / #tabList
	local valid = false
	for _, t in tabList do
		if t[1] == profileTab then valid = true end
	end
	if not valid then profileTab = "Stats" end
	for _, t in tabList do
		local on = profileTab == t[1]
		local tb = B(tabs, {Text = t[2], Size = UDim2.new(tabW, 0, 1, 0), BackgroundColor3 = on and Color3.fromRGB(255, 225, 130) or UI.CARD}, function()
			profileTab = t[1]
			render()
		end)
		if on then tb.UIStroke.Color = Color3.fromRGB(230, 170, 50); tb.UIStroke.Thickness = 3 end
	end

	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(18, 18)
	inner.Size = UDim2.new(1, -36, 1, -36)
	inner.ZIndex = Z + 2
	inner.Parent = panel
	local function row(y, icon, frac, color, text)
		local r = bar(inner, y, icon, frac, color, text)
		for _, d in r:GetDescendants() do
			if d:IsA("GuiObject") then d.ZIndex += Z end
		end
		r.ZIndex += Z
		r.Size = UDim2.new(1, 0, 0, 44)
		return r
	end

	if profileTab == "Stats" then
		local sf = Instance.new("ScrollingFrame")
		sf.BackgroundTransparency = 1
		sf.BorderSizePixel = 0
		sf.Size = UDim2.fromScale(1, 1)
		sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
		sf.CanvasSize = UDim2.new()
		sf.ScrollBarThickness = 6
		sf.ZIndex = Z + 2
		sf.Parent = inner
		inner = sf
		local y = 0
		local happy = p.Happy or Data.HappyStart
		row(y, happy >= Data.HappyHigh and "💖" or (happy < Data.HappyLow and "😢" or "🙂"), happy / 100,
			happy < Data.HappyLow and Color3.fromRGB(150, 150, 190) or Color3.fromRGB(255, 110, 170), "Happy " .. happy); y += 56
		do -- work energy (naps in the hut when empty)
			local e = p.Nap and 0 or (p.Energy or 100)
			row(y, p.Nap and "💤" or "⚡", e / 100, e > 35 and Color3.fromRGB(110, 210, 90) or Color3.fromRGB(255, 150, 60),
				p.Nap and ("Napping ⏱ " .. timeLeft(p.Nap)) or ("Energy " .. e)); y += 56
		end
		local maxed = p.Level >= Data.MaxLevel
		row(y, "⭐", maxed and 1 or (p.Xp % Data.XpPerLevel) / Data.XpPerLevel, Color3.fromRGB(255, 190, 40),
			maxed and "MAX level" or ("XP %d/%d"):format(p.Xp % Data.XpPerLevel, Data.XpPerLevel)); y += 56
		local energy = 1
		if p.Rest then energy = math.clamp((os.time() - p.Rest.From) / math.max(1, p.Rest.Until - p.Rest.From), 0, 1) end
		row(y, "🔋", energy, energy >= 1 and Color3.fromRGB(110, 210, 90) or Color3.fromRGB(255, 120, 90),
			p.Rest and ("⏱ " .. timeLeft(p.Rest.Until)) or ""); y += 56
		if p.Trip then
			row(y, "🎒", 0.5, Color3.fromRGB(120, 200, 255), "⏱ " .. timeLeft(p.Trip.ReturnAt)); y += 56
		end
		-- 🍓 favorite food, job
		local fav = p.Fav and Data.CropByName[p.Fav]
		local info = tile(inner, {Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, -10, 0, 84), BackgroundColor3 = Color3.fromRGB(255, 245, 225), ZIndex = Z + 2})
		L(info, {Text = fav and ("😍 Loves %s %s"):format(fav.Icon, fav.Name) or "😍 Favorite food: ❔ (feed it to find out!)", Position = UDim2.fromScale(0.03, 0.05),
			Size = UDim2.fromScale(0.94, 0.45), ZIndex = Z + 3, TextColor3 = BROWN, TextStrokeTransparency = 1})
		L(info, {Text = ("%s %s"):format(JOB_ICON[species.Job] or "", species.JobText), Position = UDim2.fromScale(0.03, 0.52), Size = UDim2.fromScale(0.94, 0.42),
			ZIndex = Z + 3, TextColor3 = BROWN, TextStrokeTransparency = 1})
		y += 96
		if p.Stats then
			local s = p.Stats
			row(y, "❤️", math.min(1, s.HP / 600), Color3.fromRGB(240, 90, 110), tostring(s.HP)); y += 56
			row(y, "⚔️", math.min(1, s.ATK / 90), Color3.fromRGB(255, 150, 60), tostring(s.ATK)); y += 56
			row(y, "⚡", math.min(1, (1 / s.Interval) / 2.5), Color3.fromRGB(90, 170, 255), ""); y += 56
			row(y, "💪", math.min(1, p.Power / 500), Color3.fromRGB(200, 120, 255), tostring(p.Power)); y += 56
		else
			local job = tile(inner, {Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = Color3.fromRGB(240, 250, 230),
				ZIndex = Z + 2})
			L(job, {Text = JOB_ICON[species.Job], Size = UDim2.fromScale(1, 1), ZIndex = Z + 3})
		end
	elseif profileTab == "Gear" then
		local worn
		for _, gg in state.Gear or {} do
			if gg.Id == p.GearId then worn = gg end
		end
		local slot = B(inner, {Size = UDim2.new(1, 0, 0, 96), Text = worn and "" or "➕",
			BackgroundColor3 = worn and Data.Rarities[worn.Rarity].Color:Lerp(WHITE, 0.4) or Color3.fromRGB(235, 230, 220)},
			function() if worn then act("Equip", p.Id, nil) end end)
		slot.UIStroke.Color = worn and Data.Rarities[worn.Rarity].Color or Color3.fromRGB(200, 190, 175)
		slot.UIStroke.Thickness = 5
		if worn then
			local def, amount = Data.GearBonus(worn)
			local gt = CritterUI.Template("GearModels", def.Name)
			if gt then
				CritterUI.Animate(CritterUI.ModelView(slot, gt, {Size = UDim2.new(0.4, 0, 1, 0), ZIndex = Z + 3}, {Yaw = 0}), "spin")
			else
				L(slot, {Text = def.Icon, Size = UDim2.new(0.4, 0, 1, 0), ZIndex = Z + 3})
			end
			local statIcon = def.Stat == "HP" and "❤️" or (def.Stat == "ATK" and "⚔️" or "⚡")
			L(slot, {Text = ("+%s%s"):format(def.Stat == "SPD" and math.floor(amount * 100 + 0.5) .. "%" or tostring(math.floor(amount)), statIcon),
				Position = UDim2.fromScale(0.42, 0.15), Size = UDim2.fromScale(0.45, 0.7), ZIndex = Z + 3})
			L(slot, {Text = "✖", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(24, 24), ZIndex = Z + 4})
			CritterUI.Glow(slot, worn.Rarity, Data.Rarities[worn.Rarity].Color)
		end
		local grid = Instance.new("ScrollingFrame")
		grid.BackgroundTransparency = 1
		grid.BorderSizePixel = 0
		grid.Position = UDim2.fromOffset(0, 110)
		grid.Size = UDim2.new(1, 0, 1, -110)
		grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
		grid.CanvasSize = UDim2.new()
		grid.ScrollBarThickness = 6
		grid.ZIndex = Z + 2
		grid.Parent = inner
		local gl = Instance.new("UIGridLayout", grid)
		gl.CellSize = UDim2.fromOffset(84, 84)
		gl.CellPadding = UDim2.fromOffset(8, 8)
		for _, gg in state.Gear or {} do
			if gg.Id ~= p.GearId then
				local _, amount = Data.GearBonus(gg)
				local def = Data.Gear[gg.Kind]
				local chip = B(grid, {Text = "", BackgroundColor3 = Data.Rarities[gg.Rarity].Color:Lerp(WHITE, 0.5), ZIndex = Z + 3},
					function() act("Equip", p.Id, gg.Id) end)
				chip.UIStroke.Color = Data.Rarities[gg.Rarity].Color
				chip.UIStroke.Thickness = 3
				local gt = CritterUI.Template("GearModels", def.Name)
				if gt then
					CritterUI.ModelView(chip, gt, {Size = UDim2.fromScale(1, 0.62), ZIndex = Z + 4}, {Yaw = 0.4})
				else
					L(chip, {Text = def.Icon, Size = UDim2.fromScale(1, 0.6), ZIndex = Z + 4})
				end
				CritterUI.Glow(chip, gg.Rarity, Data.Rarities[gg.Rarity].Color)
				local statIcon = def.Stat == "HP" and "❤️" or (def.Stat == "ATK" and "⚔️" or "⚡")
				L(chip, {Text = ("+%s%s"):format(def.Stat == "SPD" and math.floor(amount * 100 + 0.5) .. "%" or tostring(math.floor(amount)), statIcon),
					Position = UDim2.fromScale(0, 0.58), Size = UDim2.fromScale(1, 0.38), ZIndex = Z + 4})
				if gg.WornBy then L(chip, {Text = "🔁", Position = UDim2.new(1, -26, 0, 0), Size = UDim2.fromOffset(24, 24), ZIndex = Z + 5}) end
			end
		end
	elseif profileTab == "Outfit" then
		-- every hat: owned ones show the hat (tap to wear / tap again to take off), locked ones are ❔
		local og = Instance.new("ScrollingFrame")
		og.BackgroundTransparency = 1
		og.BorderSizePixel = 0
		og.Size = UDim2.fromScale(1, 1)
		og.AutomaticCanvasSize = Enum.AutomaticSize.Y
		og.CanvasSize = UDim2.new()
		og.ScrollBarThickness = 6
		og.ZIndex = Z + 2
		og.Parent = inner
		local gl = Instance.new("UIGridLayout", og)
		gl.CellSize = UDim2.new(0.31, 0, 0, 110)
		gl.CellPadding = UDim2.new(0.035, 0, 0, 10)
		local owned = state.Outfits or {}
		for _, o in Data.Outfits do
			local rc = Data.Rarities[o.Rarity].Color
			local have = owned[o.Name]
			local on = p.Outfit == o.Name
			local chip = B(og, {Text = have and "" or "❔", BackgroundColor3 = have and rc:Lerp(WHITE, 0.5) or Color3.fromRGB(70, 65, 85),
				TextColor3 = WHITE}, function()
				if have then act("Wear", p.Id, (not on) and o.Name or nil) end
			end)
			chip.UIStroke.Color = on and WHITE or rc
			chip.UIStroke.Thickness = on and 6 or 3
			if have then
				local hv = CritterUI.ModelView(chip, CritterUI.BuildOutfit(o.Name), {Size = UDim2.fromScale(1, 1), ZIndex = Z + 3}, {Yaw = 0.3})
				if on then CritterUI.Animate(hv, "spin") end
				if on then L(chip, {Text = "✔", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(28, 28), ZIndex = Z + 4}) end
				CritterUI.Glow(chip, o.Rarity, rc)
			end
		end
	else -- Feed
		local fg = Instance.new("Frame")
		fg.BackgroundTransparency = 1
		fg.Size = UDim2.new(1, 0, 0, 300)
		fg.ZIndex = Z + 2
		fg.Parent = inner
		local gl = Instance.new("UIGridLayout", fg)
		gl.CellSize = UDim2.new(0.48, 0, 0, 136)
		gl.CellPadding = UDim2.new(0.04, 0, 0, 14)
		for _, crop in Data.Crops do
			local slot = player:FindFirstChild("Basket") and player.Basket:FindFirstChild(crop.Name)
			local have = slot and slot.Value or 0
			if crop.Tier > Data.BaseBerries and have == 0 then continue end -- only show fancy fruit you have
			local b = B(fg, {Text = "", BackgroundColor3 = have > 0 and crop.Color:Lerp(WHITE, 0.5) or Color3.fromRGB(200, 200, 200)}, function()
				if have > 0 then
					lastFed[p.Id] = os.clock()
					act("Feed", p.Id, crop.Name)
				end
			end)
			L(b, {Text = crop.Icon, Size = UDim2.fromScale(1, 0.6), TextTransparency = have > 0 and 0 or 0.5, ZIndex = Z + 3})
			L(b, {Text = "x" .. have, Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.32), ZIndex = Z + 3})
			L(b, {Text = "+" .. crop.Xp .. "⭐", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(62, 26),
				BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 190, 40), TextColor3 = WHITE, ZIndex = Z + 4})
		end
	end

	-- 👣 follow me (one pet at a time), next to the let-go button
	if not p.Trip then
		local fb = B(profileScreen, {Text = p.Follow and "👣 Following" or "👣 Follow", AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 16 + (confirmLetGo and 120 or 70) + 10, 1, -16), Size = UDim2.fromOffset(100, 56),
			BackgroundColor3 = p.Follow and GREEN or UI.CARD, Tip = "👣 Follow", TipText = "Your pet walks with you. One pet at a time."}, function() act("Follow", p.Id) end)
		if p.Follow then CritterUI.Glow(fb, "Rare", Color3.fromRGB(90, 200, 90)) end
		if not p.Stored then -- 🧺 working / 🪑 bench
			B(profileScreen, {Text = p.Working and "🧺 Working" or "🪑 Resting", AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 16 + (confirmLetGo and 120 or 70) + 120, 1, -16), Size = UDim2.fromOffset(100, 56),
				BackgroundColor3 = p.Working and Color3.fromRGB(200, 240, 180) or UI.CARD, Tip = p.Working and "🧺 Working" or "🪑 Resting",
				TipText = "Tap to switch. Working pets help on your farm."}, function() act("SetWorker", p.Id, not p.Working) end)
		end
		-- second row: 🐎 ride, 📦 storage
		if not p.Stored then
			B(profileScreen, {Text = p.Riding and "🐎 Hop off" or "🐎 Ride", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -82),
				Size = UDim2.fromOffset(130, 52), BackgroundColor3 = p.Riding and GREEN or UI.CARD, Tip = "🐎 Ride", TipText = "Hop on and ride your pet around!"}, function()
				act("Ride", p.Id)
				closeProfile()
				if openMenu then window.Visible = false openMenu = nil end
			end)
		end
		B(profileScreen, {Text = p.Stored and "🏡 Bring to farm" or "📦 Storage", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 156, 1, -82),
			Size = UDim2.fromOffset(170, 52), BackgroundColor3 = p.Stored and Color3.fromRGB(200, 240, 180) or UI.CARD,
			Tip = p.Stored and "🏡 Bring to farm" or "📦 Storage", TipText = "Your farm has room for a few pets. The rest wait safely in storage."}, function()
			act("StorePet", p.Id, not p.Stored)
		end)
		if p.Nest then
			L(profileScreen, {Text = "💕 In the nest", Position = UDim2.new(0, 336, 1, -134), Size = UDim2.fromOffset(170, 52)})
		end
	end
	-- let go (two taps), bottom left
	if not p.Trip then
		B(profileScreen, {Text = confirmLetGo and "🌿 Sure?" or "🌿 Wild", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16),
			Size = UDim2.fromOffset(confirmLetGo and 120 or 70, 56), BackgroundColor3 = UI.RED, Tip = "🌿 Send to the wild",
			TipText = "Say goodbye and get a little gift. Tap twice to be sure."}, function()
			if confirmLetGo then
				local id = p.Id
				closeProfile()
				act("Release", id)
			else
				confirmLetGo = true
				render()
			end
		end)
	end
end

-- small picture card in the pets grid
local function petCard(parent, p, order)
	local rarity = Data.Rarities[p.Rarity]
	local species = Data.SpeciesByName[p.Species]
	local b = button(parent, {Text = "", LayoutOrder = order, ZIndex = 12, BackgroundColor3 = species.Color:Lerp(WHITE, 0.6)},
		function() profileFor = p.Id; confirmLetGo = false; render() end)
	b.UIStroke.Color = rarity.Color
	b.UIStroke.Thickness = 4
	local vf = CritterUI.Portrait(b, Data, p.Species, {Size = UDim2.new(1, 0, 0.8, 0), ZIndex = 13},
		{Sleepy = p.Rest ~= nil, Variant = p.Variant, Outfit = p.Outfit})
	CritterUI.Animate(vf, "idle", p.Rest ~= nil)
	-- badges: ✨/🌈 variant, 🐘/🐭 size, 👣 follower, mood
	local stageIcon = ""
	for _, st in Data.Stages do
		if st.Name == p.Stage and st.Name ~= "Adult" then stageIcon = st.Icon end
	end
	local tags = (p.Variant and Data.VariantByName[p.Variant].Icon or "") .. (p.SizeName and Data.SizeByName[p.SizeName].Icon or "")
		.. stageIcon .. (p.Follow and "👣" or "") .. (p.Riding and "🐎" or "")
	if tags ~= "" then label_(b, {Text = tags, Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(70, 28), ZIndex = 14,
		TextXAlignment = Enum.TextXAlignment.Left}) end
	local happy = p.Happy or Data.HappyStart
	local mood = happy >= Data.HappyHigh and "💖" or (happy < Data.HappyLow and "😢" or nil)
	if mood then label_(b, {Text = mood, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, -4), Size = UDim2.fromOffset(28, 28), ZIndex = 14}) end
	local lv = label_(b, {Text = tostring(p.Level), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(40, 28),
		BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 190, 40), TextColor3 = WHITE, TextStrokeTransparency = 0.4, ZIndex = 14})
	Instance.new("UICorner", lv).CornerRadius = UDim.new(1, 0)
	local status = p.Trip and (os.time() >= p.Trip.ReturnAt and "🎁" or "🎒") or (p.Nest and "💕") or (p.Stored and "📦") or ((p.Rest or p.Nap) and "💤" or "")
	if p.Name then
		label_(b, {Text = p.Name, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.new(1, -8, 0, 22), ZIndex = 14,
			TextColor3 = BROWN})
	end
	if not p.Trip and not p.Stored then
		if status == "" then status = p.Working and "🧺" or "🪑" end
		local eb = Instance.new("Frame") -- energy
		eb.AnchorPoint = Vector2.new(0.5, 1)
		eb.Position = UDim2.new(0.5, 0, 1, -36)
		eb.Size = UDim2.new(0.8, 0, 0, 8)
		eb.BackgroundColor3 = Color3.fromRGB(220, 215, 205)
		eb.ZIndex = 14
		Instance.new("UICorner", eb).CornerRadius = UDim.new(1, 0)
		eb.Parent = b
		local ef = Instance.new("Frame")
		local e = p.Nap and 0 or (p.Energy or 100)
		ef.Size = UDim2.fromScale(math.clamp(e / 100, 0.04, 1), 1)
		ef.BackgroundColor3 = e > 35 and Color3.fromRGB(110, 210, 90) or Color3.fromRGB(255, 150, 60)
		ef.ZIndex = 15
		Instance.new("UICorner", ef).CornerRadius = UDim.new(1, 0)
		ef.Parent = eb
	end
	if status ~= "" then
		label_(b, {Text = status, Position = UDim2.new(1, -36, 0, 2), Size = UDim2.fromOffset(34, 34), ZIndex = 14})
	end
end

MENUS.Pets = function()
	local pets = state and state.Pets or {}
	local LETGO = Color3.fromRGB(255, 190, 180)
	local order = 0
	local function add(...)
		order += 1
		return rowFrame(order, ...)
	end

	-- one pet's profile
	if profileFor and not gearFor then
		for _, p in pets do
			if p.Id == profileFor then
				petProfile(p)
				return
			end
		end
		profileFor = nil
	end

	vlist()
	-- gear picker for one battler
	if gearFor then
		local pet
		for _, p in pets do
			if p.Id == gearFor then pet = p end
		end
		if pet then
			title.Text = ("🎒 %s"):format(pet.Species)
			add("⬅", {{Text = "⬅", W = 90, Click = function() gearFor = nil; render() end}})
			if pet.GearId then
				add("❌ Remove gear", {{Text = "❌", W = 90, Color = LETGO, Click = function() act("Equip", pet.Id, nil) end}})
			end
			if #(state.Gear or {}) == 0 then add("🎒 Empty! Win ⚔️ raids for gear.") end
			for _, g in state.Gear or {} do
				if g.Id == pet.GearId then
					add("✅ " .. g.Text, nil, Data.Rarities[g.Rarity].Color)
				else
					add(g.Text .. (g.WornBy and ("  🔁 %s"):format(g.WornBy) or ""),
						{{Text = "✔", W = 90, Click = function() gearFor = nil; act("Equip", pet.Id, g.Id) end}}, Data.Rarities[g.Rarity].Color)
				end
			end
			return
		end
		gearFor = nil
	end

	-- picture grid: workers, battlers, eggs
	local workers, fighters = {}, {} -- workers = out on the farm, fighters = in storage
	for _, p in pets do table.insert(p.Stored and fighters or workers, p) end
	title.Text = "🐾 My Pets"
	local function section(header, color, items, makeCard)
		order += 1
		local h = label_(scroll, {Text = header, LayoutOrder = order, Size = UDim2.new(1, -12, 0, 36), BackgroundTransparency = 0,
			BackgroundColor3 = color, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.5, ZIndex = 12})
		Instance.new("UICorner", h).CornerRadius = UDim.new(0, 12)
		order += 1
		local grid = Instance.new("Frame")
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, -12, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.LayoutOrder = order
		grid.ZIndex = 11
		grid.Parent = scroll
		local gl = Instance.new("UIGridLayout", grid)
		gl.CellSize = UDim2.fromOffset(118, 150)
		gl.CellPadding = UDim2.fromOffset(10, 10)
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		for i, item in items do makeCard(grid, item, i) end
		if #items == 0 then label_(grid, {Text = "—", ZIndex = 12}) end
	end
	local active = 0
	for _, p in workers do if p.Working then active += 1 end end
	local slots = state and state.WorkSlots or Data.WorkSlots
	section(("🏡 On my farm %d/%d    🧺 %d/%d working"):format(#workers, state and state.FarmCap or 5, active, slots), Color3.fromRGB(120, 200, 90), workers, petCard)
	local cost = Data.SlotCosts[slots + 1]
	if cost then
		order += 1
		local up = button(scroll, {Text = ("➕ Work slot  (Farm Lv%d, 💰%d)"):format(cost.Level, cost.Coins), LayoutOrder = order, Size = UDim2.new(0, 260, 0, 44), ZIndex = 12,
			BackgroundColor3 = Color3.fromRGB(200, 240, 180)}, function() act("BuySlot") end)
	end
	order += 1
	label_(scroll, {Text = "Every pet can work AND fight. Tap a pet, then 📦 / 🏡 to swap. Farm levels give more room!", LayoutOrder = order,
		Size = UDim2.new(1, -12, 0, 30), ZIndex = 12, TextColor3 = BROWN})
	section(("📦 Storage %d     (all pets %d/%d)"):format(#fighters, #pets, state and state.PetCap or 60), Color3.fromRGB(150, 130, 200), fighters, petCard)
	local eggs = state and state.Eggs or {}
	if #eggs > 0 then
		section(("🥚 Eggs (%d hatch at a time, ⏸ = waiting)"):format(Data.IncubatorSlots), Color3.fromRGB(200, 160, 110), eggs, function(grid, egg, i)
			local info = Data.Eggs[egg.Kind or "Mystery"] or Data.Eggs.Mystery
			local ready = egg.HatchAt ~= nil and os.time() >= egg.HatchAt
			local b = button(grid, {LayoutOrder = i, ZIndex = 12, Text = ready and (info.Icon .. "\n🐣 Hatch!")
				or (egg.HatchAt and (info.Icon .. "\n⏱ " .. timeLeft(egg.HatchAt)) or (info.Icon .. "\n⏸")),
				BackgroundColor3 = ready and Color3.fromRGB(255, 225, 120) or Color3.fromRGB(240, 235, 225)},
				function() if ready then doHatch(egg.Id) end end)
			if not ready then b.AutoButtonColor = false end
		end)
	end
end

-- Studio-only test tools (the server also refuses these outside Studio).
local DEV_BUTTONS = {
	{"💰 +10,000 coins", "Coins"}, {"🍓 +50 every berry", "Berries"}, {"⚡ Full energy", "Energy"},
	{"⚔️ All battlers", "Battlers"}, {"🧺 Workers + buildings", "Workers"}, {"🎒 Gear set", "Gear"},
	{"⬆️ All pets +1 level", "LevelUp"}, {"📖 Fill the book", "Book"}, {"🥚 3 ready eggs", "Eggs"},
	{"⏩ Finish trips + eggs", "FinishTimers"}, {"⏱ Fast timers on/off", "FastTime"},
	{"Spawn Common", "Spawn", "Common"}, {"Spawn Rare", "Spawn", "Rare"}, {"Spawn Epic", "Spawn", "Epic"},
	{"Spawn Legendary", "Spawn", "Legendary"}, {"🌧️ Rain", "Weather", "Rain"}, {"🌠 Star Night", "Weather", "StarNight"},
	{"☀️ Golden Sun", "Weather", "GoldenSun"}, {"✨ Shiny spawn", "ShinySpawn"}, {"🎡 +5 spins", "Spins"},
	{"👒 All outfits", "Outfits"}, {"⭐ Farm +1 level", "FarmLevel"}, {"🎁 Present here", "Present"}, {"😢 Make pets sad", "Sad"},
	{"🌠 Falling star", "Event", "FallingStar"}, {"🏃 Catch race", "Event", "CatchRace"}, {"👹 World boss", "Event", "WorldBoss"},
	{"🎁 Present rush", "Event", "PresentRush"}, {"❄️ Snow", "Weather", "Snow"}, {"⛈️ Storm", "Weather", "Storm"},
	{"🧬 Mutate my crops", "MutateCrops"}, {"⏩ Grow my crops", "GrowCrops"},
	{"🪵 +30 resources", "Resources"}, {"⛏️ Tool +1", "ToolUp"}, {"🍀 Lucky hour", "Lucky"}, {"🛒 Restock now", "Restock"}, {"🌱 All seeds x5", "AllSeeds"}, {"😴 Tire my workers", "TireWorkers"}, {"🍂 Harvest egg", "SeasonalEgg"},
	{"🥚 Egg snatch", "Event", "EggSnatch"}, {"🎁 +3 capsules", "Capsules"}, {"🧭 Restart journey", "Journey"},
	{"🎁 Playtime gifts ready", "PlayGifts"}, {"📅 Calendar box ready", "Calendar"}, {"📬 Add mail", "Mail"}, {"🧺 Piles", "Pile"},
	{"🌈 Farm visitor", "Visitor"}, {"⭐ Golden dash", "Dash"}, {"🌙 Moon pot ready", "MoonPot"}, {"🦝 Raccoon", "Raccoon"},
	{"✨ Rare fruit", "Fruit"}, {"🔓 Open all gates", "Gates"},
	{"♻️ Reset my save", "Reset"},
}
MENUS.Dev = function()
	vlist()
	title.Text = "🛠 Dev Menu (Studio only)"
	local function gridFrame(order, cell)
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, -12, 0, 0)
		f.AutomaticSize = Enum.AutomaticSize.Y
		f.LayoutOrder = order
		f.ZIndex = 11
		f.Parent = scroll
		local g = Instance.new("UIGridLayout", f)
		g.CellSize = cell
		g.CellPadding = UDim2.fromOffset(8, 8)
		g.SortOrder = Enum.SortOrder.LayoutOrder
		return f
	end
	local tools = gridFrame(1, UDim2.fromOffset(176, 50))
	for i, d in DEV_BUTTONS do
		local color = d[2] == "Reset" and Color3.fromRGB(255, 170, 160) or (d[2] == "Spawn" and Data.Rarities[d[3]].Color or Color3.fromRGB(255, 235, 170))
		button(tools, {Text = d[1], LayoutOrder = i, ZIndex = 12, BackgroundColor3 = color}, function() act("Dev", d[2], d[3]) end)
	end
	-- pet picker: every species, 🌿 = spawn it wild next to you, 🏠 = make it your pet
	label_(scroll, {Text = "🐾  🌿 / 🏠", Size = UDim2.new(1, -12, 0, 36), LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left})
	local pets = gridFrame(3, UDim2.fromOffset(118, 150))
	for i, T in Data.Species do
		local rarity = Data.Rarities[T.Rarity]
		local card = button(pets, {Text = "", LayoutOrder = rarity.Order * 100 + i, ZIndex = 12, BackgroundColor3 = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.55)})
		card.AutoButtonColor = false
		local vf = CritterUI.Portrait(card, Data, T.Species, {Size = UDim2.new(1, 0, 1, -44), ZIndex = 13})
		CritterUI.Animate(vf, "idle")
		for k, d in {{"🌿", "SpawnSpecies", Color3.fromRGB(170, 230, 140)}, {"🏠", "GivePet", Color3.fromRGB(255, 205, 120)}} do
			button(card, {Text = d[1], AnchorPoint = Vector2.new(k == 1 and 0 or 1, 1), Position = UDim2.new(k == 1 and 0 or 1, k == 1 and 4 or -4, 1, -4),
				Size = UDim2.new(0.5, -6, 0, 36), ZIndex = 14, BackgroundColor3 = d[3]}, function() act("Dev", d[2], T.Species) end)
		end
	end
end

-- Quests: a streak strip, then one expanding drawer per quest (icon + progress; open to see rewards and claim)
local QUEST_ICON = {Harvest = "🧺", Plant = "🌱", Water = "💧", Sell = "💰", Befriend = "🐾", Feed = "🍓", Golden = "🌟", Pet = "🤚", Present = "🎁",
	Fetch = "🎾", Mutation = "🧬", Event = "🌠"}
local openDrawer = nil
MENUS.Quests = function()
	vlist()
	title.Text = "📜 Daily Quests"
	local order = 0
	local function nextOrder() order += 1 return order end

	-- streak: 7 day bubbles, today glowing, gift amounts underneath
	local streak = state and state.Streak or 0
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(1, -12, 0, 74)
	strip.LayoutOrder = nextOrder()
	strip.ZIndex = 11
	strip.Parent = scroll
	local sl = Instance.new("UIListLayout", strip)
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.Padding = UDim.new(0.012, 0)
	for d = 1, 7 do
		local got = d <= math.min(streak, 7)
		local day = label_(strip, {Size = UDim2.new(0.13, 0, 1, 0), BackgroundTransparency = 0, Text = got and "🔥" or "🎁",
			BackgroundColor3 = got and Color3.fromRGB(255, 200, 90) or Color3.fromRGB(235, 230, 220), ZIndex = 12})
		Instance.new("UICorner", day).CornerRadius = UDim.new(0, 12)
		label_(day, {Text = "💰" .. d * Data.StreakGift, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2),
			Size = UDim2.new(1, -6, 0.32, 0), ZIndex = 13})
		if d == math.min(streak, 7) then CritterUI.Glow(day, "Epic", Color3.fromRGB(255, 160, 40)) end
	end

	for i, q in state and state.Quests or {} do
		local done = q.Progress >= q.Count
		local isOpen = openDrawer == i
		local drawer = Instance.new("Frame")
		drawer.Size = UDim2.new(1, -12, 0, isOpen and 150 or 70)
		drawer.BackgroundColor3 = q.Claimed and Color3.fromRGB(225, 240, 220) or (done and Color3.fromRGB(255, 235, 160) or CREAM)
		drawer.LayoutOrder = nextOrder()
		drawer.ZIndex = 11
		drawer.ClipsDescendants = true
		Instance.new("UICorner", drawer).CornerRadius = UDim.new(0, 16)
		local ds = Instance.new("UIStroke", drawer)
		ds.Color, ds.Thickness = done and Color3.fromRGB(255, 180, 40) or Color3.fromRGB(230, 200, 160), 3
		drawer.Parent = scroll
		-- header (tap to open/close)
		local head = Instance.new("TextButton")
		head.Text = ""
		head.BackgroundTransparency = 1
		head.Size = UDim2.new(1, 0, 0, 70)
		head.ZIndex = 12
		head.Parent = drawer
		head.Activated:Connect(function()
			openDrawer = isOpen and nil or i
			render()
		end)
		label_(head, {Text = QUEST_ICON[q.Kind] or "📜", Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(58, 58), ZIndex = 13})
		local bg = Instance.new("Frame")
		bg.Position = UDim2.new(0, 76, 0.3, 0)
		bg.Size = UDim2.new(1, -150, 0.4, 0)
		bg.BackgroundColor3 = Color3.fromRGB(230, 220, 205)
		bg.ZIndex = 13
		Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
		bg.Parent = head
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp(q.Progress / q.Count, 0.03, 1), 1)
		fill.BackgroundColor3 = done and Color3.fromRGB(110, 210, 90) or Color3.fromRGB(255, 190, 40)
		fill.ZIndex = 14
		Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
		fill.Parent = bg
		label_(bg, {Text = ("%s  %d/%d"):format(q.Text, q.Progress, q.Count), Size = UDim2.fromScale(1, 1), TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.3, ZIndex = 15})
		label_(head, {Text = q.Claimed and "✅" or (isOpen and "▲" or (done and "🎁" or "▼")), AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(52, 52), ZIndex = 13})
		-- inside the drawer: reward chip + claim button
		if isOpen then
			local reward = label_(drawer, {Text = "💰 " .. q.Reward, Position = UDim2.fromOffset(76, 82), Size = UDim2.new(0.4, 0, 0, 56),
				BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 240, 180), ZIndex = 12})
			Instance.new("UICorner", reward).CornerRadius = UDim.new(0, 14)
			if done and not q.Claimed then
				CritterUI.Glow(reward, "Legendary", Color3.fromRGB(255, 200, 60))
				button(drawer, {Text = "🎁", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 82), Size = UDim2.new(0.3, 0, 0, 56),
					BackgroundColor3 = Color3.fromRGB(110, 210, 90), ZIndex = 12}, function()
					openDrawer = nil
					act("ClaimQuest", i)
				end)
			end
		end
	end

	-- critter of the day: its picture with a x3 badge
	if state then
		local cod = Instance.new("Frame")
		cod.Size = UDim2.new(1, -12, 0, 110)
		cod.BackgroundColor3 = Color3.fromRGB(240, 230, 255)
		cod.LayoutOrder = nextOrder()
		cod.ZIndex = 11
		Instance.new("UICorner", cod).CornerRadius = UDim.new(0, 16)
		cod.Parent = scroll
		label_(cod, {Text = "⭐", Position = UDim2.fromOffset(8, 20), Size = UDim2.fromOffset(70, 70), ZIndex = 12})
		local vf = CritterUI.Portrait(cod, Data, state.CritterOfDay, {Position = UDim2.fromOffset(84, 0), Size = UDim2.fromOffset(120, 110), ZIndex = 12})
		CritterUI.Animate(vf, "show")
		label_(cod, {Text = "x3", Position = UDim2.fromOffset(212, 25), Size = UDim2.fromOffset(90, 60), ZIndex = 12})
	end
end

function render()
	if not openMenu then return end
	local y = scroll.CanvasPosition
	clear()
	MENUS[openMenu]()
	scroll.CanvasPosition = y
end

local menuButtons = {}
local function open(name)
	profileScreen.Visible = false
	if openMenu == name then
		openMenu = nil
		window.Visible = false
		return
	end
	openMenu = name
	gearFor = nil
	profileFor = nil
	win.setSub("")
	win.onHelp = nil
	win.open()
	scroll.CanvasPosition = Vector2.zero
	stateEvent:FireServer()
	render()
end
bridge.Event:Connect(function(cmd, arg)
	if cmd == "PetProfile" then
		openMenu, gearFor, profileFor, bridgeProfile = "Pets", nil, arg, true
		render()
	elseif cmd == "Book" or cmd == "Dev" then
		if openMenu ~= cmd then open(cmd) end
	elseif cmd == "Hatch" then
		doHatch(arg)
	elseif cmd == "Spin" then
		doSpin()
	elseif cmd == "HideOld" then
		panel.Visible = false
		menuBar.Visible = false
	end
end)
local menuList = {{"Book", "📖 Book"}, {"Pets", "🐾 Pets"}, {"Quests", "📜 Quests"}}
if game:GetService("RunService"):IsStudio() then table.insert(menuList, {"Dev", "🛠 Dev"}) end
for _, m in menuList do
	local b = button(menuBar, {Size = UDim2.new(1, 0, 0, 48), Text = m[2]}, function() open(m[1]) end)
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.fromOffset(16, 16)
	dot.Position = UDim2.new(1, -8, 0, -6)
	dot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	dot.Visible = false
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	dot.Parent = b
	menuButtons[m[1]] = b
end

-- 🎡 lucky spin button (free spin each day + one per farm level)
local spinBtn = button(menuBar, {Size = UDim2.new(1, 0, 0, 48), Text = "🎡", BackgroundColor3 = Color3.fromRGB(255, 225, 120)}, doSpin)
local function refreshSpin()
	local n = player:GetAttribute("Spins") or 0
	spinBtn.Text = ("🎁 Prize pack x%d"):format(n)
	spinBtn.BackgroundColor3 = n > 0 and Color3.fromRGB(255, 225, 120) or Color3.fromRGB(225, 220, 210)
end
player:GetAttributeChangedSignal("Spins"):Connect(refreshSpin)
refreshSpin()
task.spawn(function() -- wiggle the button while you have spins
	while true do
		task.wait(2.5)
		if (player:GetAttribute("Spins") or 0) > 0 and not showing then
			for _, a in {12, -12, 8, -8, 0} do
				spinBtn.Rotation = a
				task.wait(0.06)
			end
		end
	end
end)

local function refreshDots()
	if not state then return end
	local petsReady = false
	for _, p in state.Pets do
		if p.Trip and os.time() >= p.Trip.ReturnAt then petsReady = true end
	end
	for _, e in state.Eggs do
		if e.HatchAt and os.time() >= e.HatchAt then petsReady = true end
	end
	local questReady = false
	for _, q in state.Quests or {} do
		if not q.Claimed and q.Progress >= q.Count then questReady = true end
	end
	menuButtons.Pets.Dot.Visible = petsReady
	menuButtons.Quests.Dot.Visible = questReady
end

stateEvent.OnClientEvent:Connect(function(s)
	state = s
	refreshDots()
	render()
end)

task.spawn(function() -- tick countdowns
	while true do
		task.wait(1)
		refreshDots()
		if openMenu == "Pets" and not profileFor and not gearFor and #(state and state.Eggs or {}) > 0 then render() end
	end
end)

---------------------------------------------------------------- counters
local ls = player:WaitForChild("leaderstats")
local coins, crits = ls:WaitForChild("Coins"), ls:WaitForChild("Critters")
local basketFolder = player:WaitForChild("Basket")
local slots = {}
for _, crop in Data.Crops do slots[crop.Name] = basketFolder:WaitForChild(crop.Name) end

local lastCoins = coins.Value
local function refresh()
	coinsLabel.Text = ("💰 %d"):format(coins.Value)
	critterLabel.Text = ("🐾 %d pets   🧺 %d/%d working"):format(crits.Value, player:GetAttribute("WorkerActive") or 0,
		player:GetAttribute("WorkSlots") or Data.WorkSlots)
	local berries = 0
	for _, crop in Data.Crops do
		local n = slots[crop.Name].Value
		berries += n
		berryChips[crop.Name].Text = ("%s %d"):format(crop.Icon, n)
		berryChips[crop.Name].Visible = crop.Tier <= Data.BaseBerries or n > 0
	end
	if crits.Value == 0 and berries == 0 then
		hint.Text = "🌱 Plant  →  💧 Water  →  🍓 Harvest"
	elseif crits.Value == 0 then
		hint.Text = "🍓 → 🐾  Offer a berry to a wild critter!"
	else
		hint.Text = "🐾 Feed pets berries to level up!"
	end
	if coins.Value > lastCoins then
		coinsLabel.BackgroundColor3 = Color3.fromRGB(190, 255, 170)
		TweenService:Create(coinsLabel, TweenInfo.new(0.6), {BackgroundColor3 = CREAM}):Play()
	end
	lastCoins = coins.Value
end
coins.Changed:Connect(refresh)
crits.Changed:Connect(refresh)
for _, v in slots do v.Changed:Connect(refresh) end
player:GetAttributeChangedSignal("CritterCap"):Connect(refresh)
player:GetAttributeChangedSignal("WorkerCount"):Connect(refresh)
player:GetAttributeChangedSignal("BattlerCount"):Connect(refresh)
player:GetAttributeChangedSignal("WorkerActive"):Connect(refresh)
player:GetAttributeChangedSignal("WorkSlots"):Connect(refresh)
refresh()
stateEvent:FireServer()
