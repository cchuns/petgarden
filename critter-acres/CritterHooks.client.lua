-- Critter Acres: CritterHooks (StarterPlayerScripts LocalScript)
--   🧭 Starter journey card + a glowing arrow to where you need to go
--   🎁 playtime gift timer, 📅 calendar, 📬 mail chip, 🍀 luck meter, 👫 friend luck, 💪 Farm Power, ✨ rare fruit chip
--   🧑‍🌾 helper quest window (talk to Fern, Pip and Bun in the plaza)
--   🔓 buttons appear when your farm level unlocks them (with a NEW! pop)
--   💰 coins fly into your counter, reveals for journey steps, mail, grown-up pets, friend eggs and gates
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))
local PackOpen = require(ReplicatedStorage:WaitForChild("PackOpen"))
local actionFn = ReplicatedStorage:WaitForChild("CritterAction")
local revealEvent = ReplicatedStorage:WaitForChild("CritterReveal")
local stateEvent = ReplicatedStorage:WaitForChild("CritterState")
local player = Players.LocalPlayer
local root = workspace:WaitForChild("CritterAcres")

local gui = Instance.new("ScreenGui")
gui.Name = "CritterHooks"
gui.ResetOnSpawn = false
gui.DisplayOrder = 4
gui.Parent = player:WaitForChild("PlayerGui")

local CREAM, BROWN = Color3.fromRGB(255, 250, 235), Color3.fromRGB(90, 60, 40)
local GREEN, WHITE = Color3.fromRGB(150, 230, 130), Color3.new(1, 1, 1)
local function act(...) return actionFn:InvokeServer(...) end
local function round(o, r) Instance.new("UICorner", o).CornerRadius = UDim.new(0, r or 12) return o end
local function L(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = BROWN
	for k, v in props do t[k] = v end
	t.Parent = parent
	return t
end
local function B(parent, props, fn)
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = BROWN
	b.BackgroundColor3 = CREAM
	b.AutoButtonColor = true
	for k, v in props do b[k] = v end
	round(b, 14)
	local st = Instance.new("UIStroke", b)
	st.Color, st.Thickness = Color3.fromRGB(230, 200, 160), 2
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
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
local function timeText(secs)
	secs = math.max(0, math.floor(secs))
	if secs >= 3600 then return ("%d:%02d:%02d"):format(secs // 3600, secs % 3600 // 60, secs % 60) end
	return ("%d:%02d"):format(secs // 60, secs % 60)
end
local function toastLocal(text)
	local t = L(gui, {Text = text, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Size = UDim2.new(0.6, 0, 0, 44),
		BackgroundTransparency = 0.1, BackgroundColor3 = CREAM, ZIndex = 50})
	round(t, 14)
	task.delay(2.5, function() t:Destroy() end)
end

---------------------------------------------------------------- show queue (full-screen reveals)
local overlay = F(gui, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 15, 35), BackgroundTransparency = 0.25, Visible = false, ZIndex = 60, Active = true})
local queue, showing = {}, false
local function runShows()
	if showing then return end
	local fn = table.remove(queue, 1)
	if not fn then return end
	showing = true
	overlay.Visible = true
	local ok, err = pcall(fn)
	if not ok then warn("CritterHooks show:", err) end
	for _, ch in overlay:GetChildren() do ch:Destroy() end
	overlay.Visible = false
	showing = false
	runShows()
end
local function show(fn)
	table.insert(queue, fn)
	task.spawn(runShows)
end
local function popup(icon, title, sub, color, art)
	show(function()
		local card = F(overlay, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(0, 0), BackgroundColor3 = color or CREAM, ZIndex = 70})
		round(card, 28)
		if art then
			art(card)
		else
			L(card, {Text = icon, Size = UDim2.fromScale(1, 0.55), ZIndex = 71})
		end
		L(card, {Text = title, Position = UDim2.fromScale(0.05, 0.58), Size = UDim2.fromScale(0.9, 0.18), ZIndex = 71, TextColor3 = WHITE, TextStrokeTransparency = 0.3})
		if sub then L(card, {Text = sub, Position = UDim2.fromScale(0.05, 0.78), Size = UDim2.fromScale(0.9, 0.14), ZIndex = 71, TextColor3 = WHITE, TextStrokeTransparency = 0.4}) end
		TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(380, 380)}):Play()
		local done = false
		B(overlay, {Text = "✔ Yay!", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(180, 64), ZIndex = 72,
			BackgroundColor3 = GREEN}, function() done = true end)
		local t0 = os.clock()
		while not done and os.clock() - t0 < 20 do task.wait() end
	end)
end

revealEvent.OnClientEvent:Connect(function(info)
	if info.Kind == "Journey" then
		show(function()
			PackOpen.Play(overlay, {Style = "Pack", Icon = "🧭", Title = ("Journey step %d/%d done!"):format(info.Step, info.Total), Color = Color3.fromRGB(120, 200, 255),
				Cards = {PackOpen.PrizeCard(Data, CritterUI, info.Prize)},
				Footer = info.Step >= info.Total and "🎉 You finished the Starter Journey! You're a real farmer now!" or nil})
		end)
	elseif info.Kind == "Mail" then
		show(function()
			local cards = {}
			for _, p in info.Prizes or {} do table.insert(cards, PackOpen.PrizeCard(Data, CritterUI, p)) end
			PackOpen.Play(overlay, {Style = "Pack", Icon = "📬", Title = "Mail for you!", Color = Color3.fromRGB(90, 150, 240), Cards = cards})
		end)
	elseif info.Kind == "Grown" then
		local st
		for _, s in Data.Stages do
			if s.Name == info.Stage then st = s end
		end
		popup(st and st.Icon or "🌟", ("%s grew into a %s!"):format(info.Name or info.Species, info.Stage),
			info.Prize and ("All grown up! +10%% power  🎁 " .. PackOpen.PrizeName(Data, info.Prize)) or "Getting bigger!", Color3.fromRGB(255, 170, 90), function(card)
				local vf = CritterUI.Portrait(card, Data, info.Species, {Size = UDim2.fromScale(1, 0.58), ZIndex = 71}, {Variant = info.Variant, Outfit = info.Outfit})
				CritterUI.Animate(vf, "show")
				vf:SetAttribute("Hop", os.clock())
			end)
	elseif info.Kind == "NestEgg" then
		popup("💕🥚", "A Friend Egg!", ("%s + %s made an egg. It's in your incubator!"):format(info.A, info.B), Color3.fromRGB(255, 130, 175))
	elseif info.Kind == "Gate" then
		local b = Data.BiomeByName[info.Name]
		popup("🔓", ("The %s is open!"):format(info.Name), ("%s New critters and resources are waiting!"):format(b and b.Icon or ""), Color3.fromRGB(110, 90, 170))
	end
end)

---------------------------------------------------------------- the right side stack of chips
-- (left of the HUD's right-side menu buttons, under the acorn / lucky chips)
local stack = F(gui, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -144, 0, 152), Size = UDim2.fromOffset(230, 460), BackgroundTransparency = 1})
local sl = Instance.new("UIListLayout", stack)
sl.Padding = UDim.new(0, 6)
sl.SortOrder = Enum.SortOrder.LayoutOrder
sl.HorizontalAlignment = Enum.HorizontalAlignment.Right
local function chip(order, color, fn)
	local b = B(stack, {Text = "", LayoutOrder = order, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = color, Visible = false}, fn)
	return b
end

-- 🧭 journey card
local journey = chip(1, Color3.fromRGB(205, 235, 255), nil)
journey.Size = UDim2.new(1, 0, 0, 74)
journey.AutoButtonColor = false
local jTitle = L(journey, {Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 22), TextXAlignment = Enum.TextXAlignment.Left})
local jText = L(journey, {Position = UDim2.fromOffset(8, 26), Size = UDim2.new(1, -16, 0, 26), TextXAlignment = Enum.TextXAlignment.Left})
local jBar = F(journey, {Position = UDim2.new(0, 8, 1, -16), Size = UDim2.new(1, -16, 0, 10), BackgroundColor3 = Color3.fromRGB(170, 200, 230)})
round(jBar, 5)
local jFill = F(jBar, {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(80, 160, 255)})
round(jFill, 5)

-- 🎁 playtime gift
local gift = chip(2, Color3.fromRGB(255, 225, 150), nil)
-- 📅 calendar
local cal = chip(3, Color3.fromRGB(255, 205, 225), nil)
-- 📬 mail
local mail = chip(4, Color3.fromRGB(190, 215, 255), function() toastLocal("📬 Go to the mailbox by your farm gate to open your mail!") end)
-- 🍀 luck meter
local luck = chip(5, Color3.fromRGB(205, 245, 195), function() toastLocal(("🍀 Every egg that isn't Epic fills the meter. Full = Epic or Legendary!")) end)
local luckBar = F(luck, {Position = UDim2.new(0, 8, 1, -12), Size = UDim2.new(1, -16, 0, 7), BackgroundColor3 = Color3.fromRGB(170, 210, 160)})
round(luckBar, 4)
local luckFill = F(luckBar, {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(70, 190, 80)})
round(luckFill, 4)
-- 👫 friends, 💪 power, ✨ fruit
local friends = chip(6, Color3.fromRGB(255, 235, 205), function() toastLocal("👫 Play with friends in the same server for more luck!") end)
local power = chip(7, Color3.fromRGB(235, 220, 255), function() toastLocal("💪 Farm Power grows with your pets, decorations, plots, soil, tools and gear!") end)
local fruit = chip(8, Color3.fromRGB(255, 245, 170), function() toastLocal("✨ A rare fruit is somewhere out there. First to grab it keeps it!") end)
for _, c in {gift, cal, mail, luck, friends, power, fruit} do c.TextXAlignment = Enum.TextXAlignment.Left end

local function commas(n)
	return tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- 🎁 playtime gift claim
local function nextGift()
	local got = {}
	for i in (player:GetAttribute("PlayGot") or ""):gmatch("%d+") do got[tonumber(i)] = true end
	for i, g in Data.PlayGifts do
		if not got[i] then return i, g end
	end
end
local function claimGift()
	local i, g = nextGift()
	local start = player:GetAttribute("PlayStart")
	if not i or not start then return end
	local scale = workspace:GetAttribute("CritterTimeScale") or 1
	if os.time() - start < g.Min * 60 / scale then
		toastLocal(("🎁 Keep playing! Your next gift opens in %s"):format(timeText(start + g.Min * 60 / scale - os.time())))
		return
	end
	local res = act("PlayGift", i)
	if type(res) == "table" and res.Prize then
		show(function()
			PackOpen.Play(overlay, {Style = "Pack", Icon = "🎁", Title = ("%d minute gift!"):format(g.Min), Color = Color3.fromRGB(255, 180, 80),
				Cards = {PackOpen.PrizeCard(Data, CritterUI, res.Prize)}})
		end)
	end
end
gift.Activated:Connect(claimGift)

-- 📅 calendar window (shared UIKit look, on its own Sibling layer under the reveals)
local UI = require(ReplicatedStorage:WaitForChild("UIKit"))
local winGui = Instance.new("ScreenGui")
winGui.Name = "CritterHooksWindows"
winGui.ResetOnSpawn = false
winGui.DisplayOrder = 3
winGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
winGui.Parent = player:WaitForChild("PlayerGui")
local calW = UI.window(winGui, {Icon = "📅", Title = "7-day gifts", Max = Vector2.new(820, 400)})
calW.setTabs({})
calW.setHelp({{"📅", "Play any day to open that day's box."}, {"🎁", "Each day has a better prize than the last."}, {"⭐", "Day 7 is the best one. Then it starts again!"}})
local calWin = calW.frame
local function renderCal()
	calW.clear()
	local got = player:GetAttribute("CalGot") or 0
	local ready = player:GetAttribute("CalReady")
	calW.setSub(ready and "🎁 Today's box is ready. Tap it!" or "✅ See you tomorrow for the next box")
	local week = got % #Data.Calendar
	local g = UI.grid(calW.body, UDim2.fromOffset(104, 210), 1)
	for i, p in Data.Calendar do
		local claimed = i <= week
		local isToday = i == week + 1
		local rc = Data.Rarities[p.Rarity or "Common"].Color
		local icon = claimed and "✅" or (p.Type == "Egg" and Data.Eggs[p.Kind].Icon or (p.Type == "Spin" and "🎁" or Data.PrizeIcon(p)))
		local open = isToday and ready
		local function tap()
			if not open then
				toastLocal(claimed and "✅ Already opened!" or (isToday and "Come back tomorrow for this one!" or "This box opens on a later day!"))
				return
			end
			local res = act("CalendarClaim")
			if type(res) == "table" and res.Prize then
				calW.close()
				show(function()
					PackOpen.Play(overlay, {Style = "Pack", Icon = "📅", Title = ("Day %d gift!"):format(res.Index), Color = Color3.fromRGB(255, 140, 190),
						Cards = {PackOpen.PrizeCard(Data, CritterUI, res.Prize)}})
				end)
			end
		end
		local c = UI.card(g, {Order = i, Icon = icon, Name = "Day " .. i, Sub = PackOpen.PrizeName(Data, p), Color = open and UI.YELLOW or (claimed and nil or rc),
			Button = open and {Text = "Open!", Kind = "special"} or nil, Fn = tap, CardFn = tap,
			Tip = "Day " .. i, TipText = claimed and "Already opened" or PackOpen.PrizeName(Data, p)})
		if claimed then c.BackgroundColor3 = UI.GREY end
	end
end
cal.Activated:Connect(function()
	if calWin.Visible then calW.close() else calW.open() renderCal() end
end)

---------------------------------------------------------------- 🧭 journey arrow (a beam from you to the target + a bouncing arrow over it)
local function myFarm()
	local farms = root:FindFirstChild("Farms")
	for _, f in farms and farms:GetChildren() or {} do
		if f:GetAttribute("Owner") == player.UserId then return f end
	end
end
local function journeyTarget(kind)
	local farm = myFarm()
	if kind == "Plant" or kind == "Water" or kind == "Harvest" then
		local plots = farm and farm:FindFirstChild("Plots")
		local p = plots and plots:FindFirstChild("Plot5")
		return p and p.Position
	elseif kind == "Sell" then
		local s = root:FindFirstChild("SellStand")
		local c = s and s:FindFirstChild("Counter")
		local bin = farm and farm:FindFirstChild("SellBin", true)
		if bin and bin:IsA("BasePart") then return bin.Position end
		return c and c.Position
	elseif kind == "Befriend" or kind == "Explore" then
		if player:GetAttribute("Realm") then return nil end -- already out in a wild land
		local tp = root:FindFirstChild("TerrainPortal")
		return tp and tp:GetPivot().Position or Vector3.new(4, 0, -72)
	elseif kind == "Hatch" then
		local n = farm and farm:FindFirstChild("Nest")
		return n and n:GetPivot().Position
	end
	return nil
end
local targetPart = Instance.new("Part")
targetPart.Anchored, targetPart.CanCollide, targetPart.CanQuery, targetPart.Transparency = true, false, false, 1
targetPart.Size = Vector3.one
targetPart.Parent = workspace
local tAtt = Instance.new("Attachment", targetPart)
local arrowGui = Instance.new("BillboardGui")
arrowGui.Size = UDim2.fromOffset(90, 90)
arrowGui.StudsOffset = Vector3.new(0, 7, 0)
arrowGui.AlwaysOnTop = true
arrowGui.Parent = targetPart
local arrowL = L(arrowGui, {Text = "⬇️", Size = UDim2.fromScale(1, 1)})
local beam = Instance.new("Beam")
beam.Attachment1 = tAtt
beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90))
beam.Width0, beam.Width1 = 0.6, 0.6
beam.LightEmission = 1
beam.FaceCamera = true
beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
beam.TextureMode = Enum.TextureMode.Static
beam.TextureLength = 3
beam.TextureSpeed = 2
beam.Transparency = NumberSequence.new(0.3)
beam.Parent = targetPart
local function refreshJourney()
	local step = player:GetAttribute("JourneyStep")
	journey.Visible = step ~= nil
	if not step then
		beam.Enabled, arrowGui.Enabled = false, false
		return
	end
	local prog, count = player:GetAttribute("JourneyProg") or 0, player:GetAttribute("JourneyCount") or 1
	jTitle.Text = ("🧭 Journey %d/%d"):format(step, #Data.Journey)
	jText.Text = player:GetAttribute("JourneyText") or ""
	jFill.Size = UDim2.fromScale(math.clamp(prog / count, 0, 1), 1)
end
RunService.Heartbeat:Connect(function()
	local step = player:GetAttribute("JourneyStep")
	local kind = player:GetAttribute("JourneyKind")
	local pos = step and journeyTarget(kind)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if pos and hrp and (hrp.Position - pos).Magnitude > 400 then -- another island / town: go to a 🌀 portal first
		local best, bd = nil, math.huge
		local folder = root:FindFirstChild("Portals")
		for _, m in folder and folder:GetChildren() or {} do
			local g = m:FindFirstChild("Gate")
			if g then
				local d = (g.Position - hrp.Position).Magnitude
				if d < bd then best, bd = g.Position, d end
			end
		end
		pos = best or pos
	end
	if pos and hrp then
		targetPart.Position = pos
		local a0 = hrp:FindFirstChild("JourneyAtt") or Instance.new("Attachment")
		a0.Name = "JourneyAtt"
		a0.Parent = hrp
		beam.Attachment0 = a0
		local near = (hrp.Position - pos).Magnitude < 14
		beam.Enabled = not near
		arrowGui.Enabled = true
		arrowGui.StudsOffset = Vector3.new(0, 6 + math.abs(math.sin(os.clock() * 4)) * 1.5, 0)
	else
		beam.Enabled, arrowGui.Enabled = false, false
	end
end)
for _, a in {"JourneyStep", "JourneyProg", "JourneyText"} do player:GetAttributeChangedSignal(a):Connect(refreshJourney) end
refreshJourney()

---------------------------------------------------------------- chips refresh (every half second)
local lastState
stateEvent.OnClientEvent:Connect(function(st) lastState = st end)
task.spawn(function()
	while true do
		-- gift
		local i, g = nextGift()
		local start = player:GetAttribute("PlayStart")
		if i and start then
			local scale = workspace:GetAttribute("CritterTimeScale") or 1
			local left = start + g.Min * 60 / scale - os.time()
			gift.Visible = true
			gift.Text = left <= 0 and "  🎁 Gift ready! Tap to open" or ("  🎁 Next gift in " .. timeText(left))
			gift.BackgroundColor3 = left <= 0 and Color3.fromRGB(255, 205, 90) or Color3.fromRGB(255, 235, 185)
			if left <= 0 then gift.Rotation = math.sin(os.clock() * 10) * 3 else gift.Rotation = 0 end
		else
			gift.Visible = false
		end
		-- calendar
		local ready = player:GetAttribute("CalReady")
		cal.Visible = player:GetAttribute("CalGot") ~= nil
		cal.Text = ready and "  📅 Daily box ready! Tap" or ("  📅 Daily gifts: day %d"):format((player:GetAttribute("CalGot") or 0) % 7 + 1)
		-- mail
		local m = player:GetAttribute("MailCount") or 0
		mail.Visible = m > 0
		mail.Text = ("  📬 %d gift%s in your mailbox!"):format(m, m == 1 and "" or "s")
		-- luck meter
		local lk = player:GetAttribute("Luck") or 0
		luck.Visible = true
		luck.Text = lk >= Data.LuckMax and "  🍀 Luck FULL! Next egg is Epic+" or ("  🍀 Luck meter %d/%d"):format(lk, Data.LuckMax)
		luckFill.Size = UDim2.fromScale(math.clamp(lk / Data.LuckMax, 0, 1), 1)
		-- friends
		local fl = player:GetAttribute("FriendLuck") or 0
		friends.Visible = fl > 0
		friends.Text = ("  👫 Friends here: +%d%% luck"):format(fl)
		-- power
		local pw = player:GetAttribute("FarmPower")
		power.Visible = pw ~= nil
		power.Text = ("  💪 Farm Power %s"):format(commas(pw or 0))
		-- rare fruit
		local where = workspace:GetAttribute("FruitWhere")
		fruit.Visible = where ~= nil
		fruit.Text = ("  ✨ Rare fruit in %s!"):format(where or "")
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- 🔓 buttons unlock with farm level
local NAMES = {Decorate = "DecorateButton", Bag = "BagButton", Nest = "NestButton", Trade = "TradeButton", Gift = "GiftButton"}
local unlockedSeen = {}
local function findButton(name)
	for _, d in player.PlayerGui:GetDescendants() do
		if d.Name == name and d:IsA("GuiButton") then return d end
	end
end
local function newPop(btn)
	local tag = L(btn, {Text = "NEW!", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(0, 0), ZIndex = (btn.ZIndex or 1) + 5,
		BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 80, 90), TextColor3 = WHITE, Rotation = 12})
	round(tag, 8)
	TweenService:Create(tag, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(52, 24)}):Play()
	for _ = 1, 3 do
		TweenService:Create(btn, TweenInfo.new(0.15), {Rotation = 8}):Play()
		task.wait(0.15)
		TweenService:Create(btn, TweenInfo.new(0.15), {Rotation = -8}):Play()
		task.wait(0.15)
	end
	btn.Rotation = 0
	task.delay(12, function() tag:Destroy() end)
end
local firstPass = true
local function refreshUnlocks()
	local lv = player:GetAttribute("FarmLevel") or 1
	local journeyKind = player:GetAttribute("JourneyKind")
	for key, need in Data.ButtonUnlocks do
		local name = NAMES[key]
		local btn = name and findButton(name)
		if btn then
			local open = lv >= need or (key == "Decorate" and journeyKind == "Decor")
			btn.Visible = open
			if open and not unlockedSeen[key] then
				unlockedSeen[key] = true
				if not firstPass then
					task.spawn(newPop, btn)
					toastLocal(("🔓 NEW: %s unlocked!"):format(btn:FindFirstChild("Word") and btn.Word.Text or key))
				end
			end
		end
	end
	-- the raid gate opens at its level too (its prompt is local to each player)
	local gate = root:FindFirstChild("RaidGate")
	local prompt = gate and gate:FindFirstChild("RaidPrompt", true)
	if prompt then
		prompt.Enabled = lv >= Data.ButtonUnlocks.Raid
		if lv >= Data.ButtonUnlocks.Raid and not unlockedSeen.Raid then
			unlockedSeen.Raid = true
			if not firstPass then toastLocal("🔓 NEW: the ⚔️ Raid Gate is open!") end
		end
	end
	firstPass = false
end
player:GetAttributeChangedSignal("FarmLevel"):Connect(refreshUnlocks)
player:GetAttributeChangedSignal("JourneyKind"):Connect(refreshUnlocks)
task.spawn(function()
	task.wait(3) -- let the other scripts make their buttons
	firstPass = true
	refreshUnlocks()
	while true do
		task.wait(5)
		local lv = player:GetAttribute("FarmLevel") or 1
		for key, need in Data.ButtonUnlocks do -- buttons made later stay hidden until unlocked
			local btn = NAMES[key] and findButton(NAMES[key])
			if btn and lv < need and not (key == "Decorate" and player:GetAttribute("JourneyKind") == "Decor") then btn.Visible = false end
		end
	end
end)

---------------------------------------------------------------- 💰 coins fly into the counter
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	local coins = ls:WaitForChild("Coins")
	local last = coins.Value
	local lastFly = 0
	coins.Changed:Connect(function(v)
		local diff = v - last
		last = v
		if diff < 5 or os.clock() - lastFly < 0.4 then return end
		lastFly = os.clock()
		local vp = workspace.CurrentCamera.ViewportSize
		local plus = L(gui, {Text = "+" .. commas(diff) .. " 💰", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(vp.X / 2, vp.Y * 0.6),
			Size = UDim2.fromOffset(200, 50), TextColor3 = Color3.fromRGB(255, 210, 60), TextStrokeTransparency = 0.2, ZIndex = 55})
		TweenService:Create(plus, TweenInfo.new(1.2), {Position = UDim2.fromOffset(vp.X / 2, vp.Y * 0.45), TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		task.delay(1.25, function() plus:Destroy() end)
		for k = 1, math.clamp(math.floor(diff / 20) + 2, 2, 10) do
			local c = L(gui, {Text = "💰", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(vp.X / 2 + math.random(-60, 60), vp.Y * 0.6 + math.random(-30, 30)),
				Size = UDim2.fromOffset(34, 34), ZIndex = 55})
			task.delay(k * 0.05, function()
				local tw = TweenService:Create(c, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.fromOffset(90, 40), Size = UDim2.fromOffset(22, 22)})
				tw:Play()
				tw.Completed:Wait()
				c:Destroy()
			end)
		end
	end)
end)

---------------------------------------------------------------- 🧑‍🌾 helper quests (Talk prompts in the plaza)
local npcW = UI.window(winGui, {Icon = "🧑‍🌾", Title = "Helper", Max = Vector2.new(600, 430)})
npcW.setTabs({})
npcW.setHelp({{"💬", "Helpers in the plaza ask for small jobs."}, {"✅", "Do the job. The bar fills up as you go."}, {"🎁", "Come back and get your reward!"}})
local npcWin = npcW.frame
local function renderNPC(i, info)
	local npc = Data.NPCs[i]
	npcW.clear()
	npcW.setTitle(npc.Icon, npc.Name)
	npcW.open()
	local body = npcW.body
	if not info or info.Done then
		npcW.setSub("All quests done")
		UI.empty(body, "🎉", "You helped me with everything! Thank you, friend!", nil, nil, 1)
		return
	end
	npcW.setSub(("Quest %d of %d"):format(info.Step, info.Total))
	local bubble = UI.frame(body, {Size = UDim2.new(1, -8, 0, 80), LayoutOrder = 1})
	UI.round(bubble, 16)
	UI.stroke(bubble, npc.Color, 3)
	UI.text(bubble, {Text = "💬 " .. info.Text, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -16), TextWrapped = true, Max = 22})
	local ready = info.Prog >= info.Count
	UI.row(body, {Order = 2, Icon = ready and "✅" or "📋", Title = ready and "Done!" or "Your job", Progress = {info.Prog, info.Count}, BarColor = npc.Color})
	UI.row(body, {Order = 3, Icon = "🎁", Title = "Reward", Sub = PackOpen.PrizeName(Data, info.Prize)})
	UI.button(body, {Text = ready and "🎁 Get my reward" or "👍 I'm on it", LayoutOrder = 4, Size = UDim2.new(1, -8, 0, 56), Kind = ready and "special" or "go"}, function()
		if not ready then npcW.close() return end
		local res = act("NPCClaim", i)
		if type(res) == "table" and res.Prize then
			npcW.close()
			show(function()
				PackOpen.Play(overlay, {Style = "Pack", Icon = npc.Icon, Title = npc.Name .. " says thank you!", Color = npc.Color,
					Cards = {PackOpen.PrizeCard(Data, CritterUI, res.Prize)}})
			end)
		end
	end)
end
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player or prompt.Name ~= "TalkPrompt" then return end
	local model = prompt:FindFirstAncestorWhichIsA("Model")
	local i = model and model:GetAttribute("NPC")
	if not i then return end
	renderNPC(i, act("NPCInfo", i))
end)
-- ❗ over helpers who have a reward ready for you
local marks = {}
task.spawn(function()
	local folder = root:WaitForChild("Helpers", 30)
	if not folder then return end
	while true do
		for _, m in folder:GetChildren() do
			local i = m:GetAttribute("NPC")
			local head = m:FindFirstChild("Head")
			if i and head then
				local bb = marks[i]
				if not bb then
					-- a clean round badge: white disc, coloured ring, a bold "!" (or a check when the reward is ready), soft shadow
					bb = Instance.new("BillboardGui")
					bb.Size = UDim2.fromOffset(46, 54)
					bb.StudsOffset = Vector3.new(0, 4.2, 0)
					bb.AlwaysOnTop = true
					bb.LightInfluence = 0
					bb.MaxDistance = 140
					bb.Parent = head
					local shadow = Instance.new("Frame")
					shadow.Name = "Shadow"
					shadow.AnchorPoint = Vector2.new(0.5, 0)
					shadow.Position = UDim2.new(0.5, 0, 0, 44)
					shadow.Size = UDim2.fromOffset(22, 6)
					shadow.BackgroundColor3 = Color3.new(0, 0, 0)
					shadow.BackgroundTransparency = 0.75
					Instance.new("UICorner", shadow).CornerRadius = UDim.new(1, 0)
					shadow.Parent = bb
					local disc = Instance.new("Frame")
					disc.Name = "Disc"
					disc.Size = UDim2.fromOffset(40, 40)
					disc.Position = UDim2.fromOffset(3, 0)
					disc.BackgroundColor3 = Color3.new(1, 1, 1)
					Instance.new("UICorner", disc).CornerRadius = UDim.new(1, 0)
					local ring = Instance.new("UIStroke")
					ring.Name = "Ring"
					ring.Thickness = 3.5
					ring.Color = Color3.fromRGB(255, 176, 46)
					ring.Parent = disc
					local t = Instance.new("TextLabel")
					t.Name = "T"
					t.BackgroundTransparency = 1
					t.Size = UDim2.fromScale(1, 1)
					t.Font = Enum.Font.BuilderSansExtraBold
					t.TextSize = 28
					t.TextColor3 = Color3.fromRGB(255, 160, 30)
					t.Text = "!"
					t.Parent = disc
					disc.Parent = bb
					marks[i] = bb
				end
				local q = lastState and lastState.NPC and lastState.NPC[i]
				bb.Enabled = q ~= nil and not q.Done
				local ready = q and q.Ready
				local col = ready and Color3.fromRGB(80, 190, 110) or Color3.fromRGB(255, 166, 40)
				bb.Disc.T.Text = ready and "✓" or "!"
				bb.Disc.T.TextColor3 = col
				bb.Disc.Ring.Color = col
				local bob = math.sin(os.clock() * 2.4)
				bb.StudsOffset = Vector3.new(0, 4.2 + bob * 0.25, 0)
				bb.Shadow.BackgroundTransparency = 0.72 + bob * 0.08
			end
		end
		task.wait(0.1)
	end
end)

---------------------------------------------------------------- the new menus (CritterMenus) open our screens
local bridge = ReplicatedStorage:WaitForChild("CritterUIBridge")
bridge.Event:Connect(function(cmd, arg)
	if cmd == "PlayGift" then
		claimGift()
	elseif cmd == "Calendar" then
		calW.open()
		renderCal()
	elseif cmd == "NPC" then
		renderNPC(arg, act("NPCInfo", arg))
	elseif cmd == "NPCClaim" then
		local npc = Data.NPCs[arg]
		local res = act("NPCClaim", arg)
		if npc and type(res) == "table" and res.Prize then
			show(function()
				PackOpen.Play(overlay, {Style = "Pack", Icon = npc.Icon, Title = npc.Name .. " says thank you!", Color = npc.Color,
					Cards = {PackOpen.PrizeCard(Data, CritterUI, res.Prize)}})
			end)
		end
	elseif cmd == "HideOld" then
		stack.Visible = false
	end
end)
