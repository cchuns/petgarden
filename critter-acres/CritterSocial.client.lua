-- Critter Acres: CritterSocial (StarterPlayerScripts LocalScript)
--   🤝 Trade window (both pick pets → both Ready → both Confirm), 💌 send gifts to a friend's mailbox
--   🎣 fishing minigame at the pond
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))
local actionFn = ReplicatedStorage:WaitForChild("CritterAction")
local stateEvent = ReplicatedStorage:WaitForChild("CritterState")
local tradeEvent = ReplicatedStorage:WaitForChild("CritterTrade")
local player = Players.LocalPlayer
local root = workspace:WaitForChild("CritterAcres")

local gui = Instance.new("ScreenGui")
gui.Name = "CritterSocial"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local CREAM, BROWN = Color3.fromRGB(255, 250, 235), Color3.fromRGB(90, 60, 40)
local GREEN, WHITE = Color3.fromRGB(150, 230, 130), Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(215, 210, 205)
local function act(...) return actionFn:InvokeServer(...) end
local function round(o, r) Instance.new("UICorner", o).CornerRadius = UDim.new(0, r or 12) return o end
local function L(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = BROWN
	t.ZIndex = 41
	for k, v in props do t[k] = v end
	t.Parent = parent
	return t
end
local UI = require(ReplicatedStorage:WaitForChild("UIKit"))
local function B(parent, props, fn)
	local bg = props.BackgroundColor3
	props.BackgroundColor3 = nil
	props.AutoButtonColor = nil
	if props.ZIndex == nil then props.ZIndex = 42 end
	local b = UI.button(parent, props, fn)
	if bg then
		b.BackgroundColor3 = bg
		b.UIStroke.Color = bg:Lerp(Color3.new(0, 0, 0), 0.15)
	end
	return b
end
local CLOSE = UI.RED
-- windows live on their own Sibling layer (under the reveals, above the HUD)
local winGui = Instance.new("ScreenGui")
winGui.Name = "CritterSocialWindows"
winGui.ResetOnSpawn = false
winGui.DisplayOrder = 3
winGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
winGui.Parent = player:WaitForChild("PlayerGui")
local function panel(f) -- cream panel with the soft UIKit border
	f.BackgroundColor3 = UI.CREAM
	UI.stroke(f, Color3.fromRGB(230, 205, 165), 3)
	return f
end
local function F(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.ZIndex = 40
	for k, v in props do f[k] = v end
	f.Parent = parent
	return f
end
local function note(text)
	local t = L(gui, {Text = text, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 140), Size = UDim2.new(0.6, 0, 0, 44),
		BackgroundTransparency = 0.1, BackgroundColor3 = CREAM, ZIndex = 80})
	round(t, 14)
	task.delay(2.8, function() t:Destroy() end)
end
local function sfx(speed, vol)
	local s = Instance.new("Sound")
	s.SoundId, s.PlaybackSpeed, s.Volume = "rbxasset://sounds/electronicpingshort.wav", speed or 1, vol or 0.6
	SoundService:PlayLocalSound(s)
end
local state
stateEvent.OnClientEvent:Connect(function(st) state = st end)

-- a UIKit window (title, ❓, ✖, scrolling body)
local function makeWindow(w, h, icon, titleText)
	local win = UI.window(winGui, {Icon = icon, Title = titleText, Max = Vector2.new(w, h)})
	win.setTabs({})
	local title = setmetatable({}, {__newindex = function(_, k, v) -- title.Text = "💌 Send a gift" → icon + title
		if k == "Text" then
			local i, r = tostring(v):match("^(%S+)%s*(.*)$")
			win.setTitle(i or "", r or "")
		end
	end})
	return win.frame, title, win.body, function() win.clear() end, win
end
local function grid(parent, order, cell)
	local g = F(parent, {Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order})
	local gl = Instance.new("UIGridLayout", g)
	gl.CellSize = cell
	gl.CellPadding = UDim2.fromOffset(8, 8)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	return g
end
local function petTile(parent, p, order, z, onClick, picked)
	local rc = Data.Rarities[p.Rarity].Color
	local v = p.Variant and Data.VariantByName[p.Variant]
	local c = UI.card(parent, {Order = order, Name = (v and v.Icon or "") .. (p.Name or p.Species), Sub = ("Lv %d %s"):format(p.Level, p.Rarity),
		Color = picked and UI.GREEN or rc, CardFn = onClick,
		Art = function(pic)
			local vf = CritterUI.Portrait(pic, Data, p.Species, {Size = UDim2.fromScale(1, 1)}, {Variant = p.Variant, Outfit = p.Outfit})
			CritterUI.Animate(vf, "idle")
		end})
	if picked then
		c.BackgroundColor3 = Color3.fromRGB(228, 246, 218)
		UI.text(c, {Text = "✔", Position = UDim2.new(1, -32, 0, 4), Size = UDim2.fromOffset(28, 28), Max = 24})
	end
	return c
end

---------------------------------------------------------------- 🤝 trade + 💌 gift buttons (next to Bag / Decorate)
local pickWin, pickTitle, pickBody, pickClear, pickW = makeWindow(600, 520, "🤝", "Trade")
local function openPicker(mode)
	pickClear()
	pickW.open()
	pickTitle.Text = mode == "Trade" and "🤝 Trade" or "💌 Send a gift"
	pickW.setSub(mode == "Trade" and "Pick a player to trade pets with" or "Pick who gets your gift")
	pickW.setHelp(mode == "Trade" and {{"👤", "Pick a player on this server."}, {"🐾", "You both pick pets to swap."}, {"✅", "Both press Ready, then Confirm. Done!"}}
		or {{"👤", "Pick a player on this server."}, {"🎁", "Pick a gift from your own bag."}, {"📬", "It arrives in their mailbox!"}})
	local any = false
	for i, p in Players:GetPlayers() do
		if p ~= player then
			any = true
			UI.row(pickBody, {Order = i, Icon = "👤", Title = p.DisplayName, Button = {Text = mode == "Trade" and "🤝 Ask to trade" or "💌 Pick a gift", Kind = "go"},
				Fn = function()
				if mode == "Trade" then
					pickW.close()
					local msg = act("TradeRequest", p.UserId)
					if msg then note(msg) end
				else
					pickClear()
					pickTitle.Text = "💌 Pick a gift"
					pickW.setSub(("For %s · %d gifts a day, from your own bag"):format(p.DisplayName, Data.GiftsPerDay))
					local g = grid(pickBody, 1, UDim2.fromOffset(160, 200))
					for k, item in Data.GiftItems do
						local icon = item.Kind == "Coins" and "💰" or (Data.CropByName[item.Crop].Icon .. (item.Kind == "Seed" and "🌱" or ""))
						local text = item.Kind == "Coins" and ("%d coins"):format(item.Amount)
							or ("%d %s%s"):format(item.Amount, item.Crop, item.Kind == "Seed" and " seeds" or "")
						local function send()
							local msg = act("SendGift", p.UserId, k)
							if msg then note(msg) end
							pickW.close()
						end
						UI.card(g, {Order = k, Icon = icon, Name = text, Button = {Text = "💌 Send", Kind = "go"}, Fn = send, CardFn = send})
					end
				end
			end})
		end
	end
	if not any then UI.empty(pickBody, "👫", "Nobody else is here yet. Invite a friend!", nil, nil, 1) end
end
task.spawn(function()
	local bag
	for _ = 1, 40 do
		for _, d in player.PlayerGui:GetDescendants() do
			if d.Name == "BagButton" then bag = d end
		end
		if bag then break end
		task.wait(0.5)
	end
	local parent = bag and bag.Parent
	if not parent then
		parent = F(gui, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -160), Size = UDim2.fromOffset(180, 66), BackgroundTransparency = 1})
		local l = Instance.new("UIListLayout", parent)
		l.FillDirection = Enum.FillDirection.Horizontal
		l.Padding = UDim.new(0, 8)
	end
	for i, def in {{"TradeButton", "🤝", "Trade", Color3.fromRGB(200, 230, 255), "Trade"}, {"GiftButton", "💌", "Gift", Color3.fromRGB(255, 210, 230), "Gift"}} do
		local b = B(parent, {Name = def[1], Text = "", Size = UDim2.fromOffset(78, 64), LayoutOrder = 10 + i, BackgroundColor3 = def[4], ZIndex = 1}, function() openPicker(def[5]) end)
		L(b, {Name = "Icon", Text = def[2], Size = UDim2.fromScale(1, 0.64), ZIndex = 2})
		L(b, {Name = "Word", Text = def[3], Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.34), ZIndex = 2})
	end
end)

---------------------------------------------------------------- 🤝 trade window
local tradeWin = F(winGui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.96, 0, 0.88, 0), Visible = false, ZIndex = 50})
round(tradeWin, 22)
panel(tradeWin)
Instance.new("UISizeConstraint", tradeWin).MaxSize = Vector2.new(980, 620)
local myOffer = {}
local lastTrade
local function renderTrade(t)
	lastTrade = t
	for _, ch in tradeWin:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	tradeWin.Visible = true
	myOffer = {}
	for _, p in t.Mine do table.insert(myOffer, p.Id) end
	UI.text(tradeWin, {Text = "🤝", Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(44, 44), ZIndex = 51, Max = 36})
	UI.text(tradeWin, {Text = "Trading with " .. t.With, Position = UDim2.fromOffset(64, 8), Size = UDim2.new(1, -140, 0, 30), ZIndex = 51, TextXAlignment = Enum.TextXAlignment.Left, Max = 26})
	UI.text(tradeWin, {Text = "Both press 👍 Ready, then both press ✅ Confirm", Position = UDim2.fromOffset(64, 36), Size = UDim2.new(1, -140, 0, 18), ZIndex = 51,
		TextColor3 = UI.SOFT, TextXAlignment = Enum.TextXAlignment.Left, Max = 16})
	UI.button(tradeWin, {Text = "✖", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(46, 46), ZIndex = 52, Kind = "careful",
		Tip = "Stop trading", TipText = "Nothing gets swapped"}, function() act("TradeCancel") end)
	-- two sides
	local function side(x, titleText, color, pets, ready, confirm)
		local box = F(tradeWin, {Position = UDim2.new(x, 10, 0, 62), Size = UDim2.new(0.5, -15, 0, 210), BackgroundColor3 = UI.CARD, ZIndex = 51})
		round(box, 16)
		UI.stroke(box, color:Lerp(Color3.new(0, 0, 0), 0.12), 3)
		L(box, {Text = titleText .. (confirm and "  ✅ Confirmed" or (ready and "  👍 Ready" or "")), Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 34), ZIndex = 52})
		local g = F(box, {Position = UDim2.fromOffset(8, 42), Size = UDim2.new(1, -16, 1, -50), BackgroundTransparency = 1, ZIndex = 52})
		local gl = Instance.new("UIGridLayout", g)
		gl.CellSize = UDim2.fromOffset(110, 150)
		gl.CellPadding = UDim2.fromOffset(6, 6)
		for i, p in pets do petTile(g, p, i, 53) end
		if #pets == 0 then L(g, {Text = "(nothing yet)", ZIndex = 53}) end
	end
	side(0, "You give:", Color3.fromRGB(255, 230, 220), t.Mine, t.MeReady, t.MeConfirm)
	side(0.5, ("%s gives:"):format(t.With), Color3.fromRGB(220, 240, 255), t.Theirs, t.ThemReady, t.ThemConfirm)
	-- pick your pets
	L(tradeWin, {Text = ("Tap your pets to add them (up to %d):"):format(Data.TradeMax), Position = UDim2.fromOffset(16, 272), Size = UDim2.new(1, -32, 0, 30), ZIndex = 51,
		TextXAlignment = Enum.TextXAlignment.Left})
	local sc = Instance.new("ScrollingFrame")
	sc.Position = UDim2.fromOffset(12, 304)
	sc.Size = UDim2.new(1, -24, 1, -394)
	sc.BackgroundTransparency = 1
	sc.BorderSizePixel = 0
	sc.ScrollingDirection = Enum.ScrollingDirection.X
	sc.AutomaticCanvasSize = Enum.AutomaticSize.X
	sc.CanvasSize = UDim2.new()
	sc.ScrollBarThickness = 6
	sc.ZIndex = 51
	sc.Parent = tradeWin
	local sl = Instance.new("UIListLayout", sc)
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.Padding = UDim.new(0, 6)
	sl.SortOrder = Enum.SortOrder.LayoutOrder
	for i, p in state and state.Pets or {} do
		if not p.Trip and not p.Nest and not p.Riding then
			local picked = table.find(myOffer, p.Id) ~= nil
			local tileB = petTile(sc, p, i, 52, function()
				local idx = table.find(myOffer, p.Id)
				if idx then table.remove(myOffer, idx) elseif #myOffer < Data.TradeMax then table.insert(myOffer, p.Id) end
				act("TradeSet", myOffer)
			end, picked)
			tileB.Size = UDim2.fromOffset(110, 150)
		end
	end
	-- bottom: Ready / Confirm
	local msg
	if t.Stage == "Confirm" then
		msg = t.MeConfirm and "Waiting for them to confirm..." or "⚠️ Look carefully! Happy with this trade? Press ✅ Confirm"
		B(tradeWin, {Text = t.MeConfirm and "✅ Confirmed" or "✅ Confirm trade", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -14), Size = UDim2.fromOffset(240, 64),
			ZIndex = 52, BackgroundColor3 = t.MeConfirm and GREY or UI.GREEN}, function() if not t.MeConfirm then act("TradeConfirm") end end)
	else
		msg = "Both players press 👍 Ready. Then both press ✅ Confirm."
		B(tradeWin, {Text = t.MeReady and "👍 Ready! (tap to undo)" or "👍 Ready", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -14), Size = UDim2.fromOffset(260, 64),
			ZIndex = 52, BackgroundColor3 = t.MeReady and UI.GREEN or UI.YELLOW}, function() act("TradeReady", not t.MeReady) end)
	end
	L(tradeWin, {Text = msg, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -20), Size = UDim2.new(1, -310, 0, 48), ZIndex = 51, TextXAlignment = Enum.TextXAlignment.Left})
end
local requestCard
tradeEvent.OnClientEvent:Connect(function(info)
	if info.Kind == "Request" then
		if requestCard then requestCard:Destroy() end
		local card = F(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(440, 150), ZIndex = 70})
		round(card, 20)
		panel(card)
		requestCard = card
		L(card, {Text = ("🤝 %s wants to trade pets!"):format(info.From), Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 50), ZIndex = 71})
		B(card, {Text = "✔ Let's trade", Position = UDim2.new(0.5, 6, 1, -70), Size = UDim2.new(0.5, -18, 0, 58), BackgroundColor3 = UI.GREEN, ZIndex = 71}, function()
			card:Destroy()
			local msg = act("TradeAccept", info.FromId)
			if msg then note(msg) end
		end)
		B(card, {Text = "✖ No thanks", Position = UDim2.new(0, 12, 1, -70), Size = UDim2.new(0.5, -18, 0, 58), BackgroundColor3 = UI.GREY, ZIndex = 71}, function()
			card:Destroy()
			act("TradeDecline")
		end)
		task.delay(35, function() if card.Parent then card:Destroy() end end)
	elseif info.Kind == "Update" then
		renderTrade(info)
	elseif info.Kind == "Close" then
		tradeWin.Visible = false
		lastTrade = nil
		if info.Why then note(info.Why) end
	end
end)
stateEvent.OnClientEvent:Connect(function()
	if lastTrade and tradeWin.Visible then task.defer(renderTrade, lastTrade) end
end)

---------------------------------------------------------------- 🎣 fishing minigame
local fishWin = F(gui, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(460, 330), Visible = false, ZIndex = 45})
round(fishWin, 22)
panel(fishWin)
local fishing = false
local function fishRound()
	for _, ch in fishWin:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	fishWin.Visible = true
	local Z = 46
	L(fishWin, {Text = "🎣 Fishing", Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -80, 0, 40), ZIndex = Z, TextXAlignment = Enum.TextXAlignment.Left})
	B(fishWin, {Text = "✖", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(40, 40), ZIndex = Z + 1,
		BackgroundColor3 = CLOSE}, function() fishWin.Visible = false fishing = false end)
	local water = F(fishWin, {Position = UDim2.fromOffset(20, 52), Size = UDim2.new(1, -40, 0, 150), BackgroundColor3 = Color3.fromRGB(70, 160, 230), ZIndex = Z})
	round(water, 18)
	local bob = L(water, {Text = "🔴", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46), ZIndex = Z + 1})
	local status = L(fishWin, {Text = "🎣 Casting...", Position = UDim2.fromOffset(20, 208), Size = UDim2.new(1, -40, 0, 36), ZIndex = Z})
	local res = act("FishCast")
	if type(res) ~= "table" or not res.Token then
		status.Text = type(res) == "table" and res.Error or "❌"
		return
	end
	local tapped, bit = false, false
	local reelBtn = B(fishWin, {Text = "🎣 Reel in!", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(260, 64), ZIndex = Z + 1,
		BackgroundColor3 = UI.YELLOW})
	local result
	reelBtn.Activated:Connect(function()
		if tapped then return end
		tapped = true
		result = act("FishReel", res.Token)
	end)
	status.Text = "🤫 Shh... wait for a bite, then tap fast!"
	local t0 = os.clock()
	while not tapped and os.clock() - t0 < res.Wait do -- the bobber floats
		bob.Position = UDim2.new(0.5, 0, 0.5, math.sin(os.clock() * 3) * 4)
		task.wait()
	end
	if not tapped then -- BITE!
		bit = true
		sfx(1.4, 0.8)
		status.Text = "❗❗ A BITE! TAP NOW! ❗❗"
		reelBtn.BackgroundColor3 = UI.RED
		reelBtn.Text = "❗ TAP NOW!"
		local t1 = os.clock()
		while not tapped and os.clock() - t1 < Data.FishWindow + 0.5 do
			bob.Position = UDim2.new(0.5, math.random(-6, 6), 0.65, math.random(-4, 4))
			bob.Text = "💦"
			task.wait()
		end
		if not tapped then
			tapped = true
			result = act("FishReel", res.Token)
		end
	end
	while tapped and not result do task.wait() end
	reelBtn:Destroy()
	if type(result) == "table" and result.Fish then
		local rc = Data.Rarities[result.Rarity].Color
		water.BackgroundColor3 = rc:Lerp(WHITE, 0.4)
		bob.Text = result.Icon
		bob.Size = UDim2.fromOffset(0, 0)
		TweenService:Create(bob, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(110, 110), Position = UDim2.fromScale(0.5, 0.5)}):Play()
		sfx(result.Rarity == "Legendary" and 0.8 or 1.2, 1)
		status.Text = ("%s %s!  💰+%d%s%s"):format(result.Rarity, result.Fish, result.Coins, result.New and "  📖 NEW!" or "", result.Egg and "  🥚 an egg inside!" or "")
		status.TextColor3 = rc:Lerp(BROWN, 0.3)
	else
		bob.Text = "🐟💨"
		status.Text = type(result) == "table" and (result.Miss or result.Error) or "The fish got away!"
	end
	B(fishWin, {Text = "🎣 Again!", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -14), Size = UDim2.fromOffset(200, 60), ZIndex = Z + 1, BackgroundColor3 = GREEN},
		function() task.spawn(fishRound) end)
	B(fishWin, {Text = "📖 Fish book", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -14), Size = UDim2.fromOffset(200, 60), ZIndex = Z + 1}, function()
		local book = act("FishBook") or {}
		for _, ch in fishWin:GetChildren() do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
		L(fishWin, {Text = "📖 Fish book", Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -80, 0, 40), ZIndex = Z, TextXAlignment = Enum.TextXAlignment.Left})
		B(fishWin, {Text = "✖", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(40, 40), ZIndex = Z + 1,
			BackgroundColor3 = CLOSE}, function() fishWin.Visible = false end)
		local g = F(fishWin, {Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 1, -130), BackgroundTransparency = 1, ZIndex = Z})
		local gl = Instance.new("UIGridLayout", g)
		gl.CellSize = UDim2.fromOffset(136, 52)
		gl.CellPadding = UDim2.fromOffset(6, 6)
		for _, f in Data.Fish do
			local n = book[f.Name]
			local cell = L(g, {Text = n and ("%s %s x%d"):format(f.Icon, f.Name, n) or "❔ ???", ZIndex = Z + 1, BackgroundTransparency = 0,
				BackgroundColor3 = n and Data.Rarities[f.Rarity].Color:Lerp(WHITE, 0.7) or UI.GREY})
			round(cell, 12)
			UI.stroke(cell, n and Data.Rarities[f.Rarity].Color or UI.LINE, 2)
			local pad = Instance.new("UIPadding", cell)
			pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6)
		end
		B(fishWin, {Text = "🎣 Fish again", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(220, 60), ZIndex = Z + 1,
			BackgroundColor3 = GREEN}, function() task.spawn(fishRound) end)
	end)
end
task.spawn(function()
	local pond = root:WaitForChild("FishingPond", 60)
	local dock = pond and pond:WaitForChild("Dock", 10)
	if not dock then return end
	local prompt = Instance.new("ProximityPrompt") -- local: only opens your own minigame
	prompt.ActionText = "🎣 Fish"
	prompt.ObjectText = "Fishing Pond"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = dock
	prompt.Triggered:Connect(function()
		if fishWin.Visible then return end
		task.spawn(fishRound)
	end)
end)

---------------------------------------------------------------- the new menus (CritterMenus) open our screens
local bridge = ReplicatedStorage:WaitForChild("CritterUIBridge")
bridge.Event:Connect(function(cmd)
	if cmd == "Gift" then openPicker("Gift") elseif cmd == "Trade" then openPicker("Trade") end
end)
