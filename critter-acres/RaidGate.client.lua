-- Critter Acres: RaidGate (StarterPlayerScripts)
-- Opens from the Raid Gate. 1) pick a raid, 2) pick 3-6 battle pets, 3) FIGHT!
-- The server runs the battle; this screen plays it back with animations.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))
local actionFn = ReplicatedStorage:WaitForChild("CritterAction")
local stateEvent = ReplicatedStorage:WaitForChild("CritterState")
local player = Players.LocalPlayer

local CREAM, BROWN = Color3.fromRGB(255, 250, 235), Color3.fromRGB(90, 60, 40)
local GREEN, GREY, RED = Color3.fromRGB(110, 210, 90), Color3.fromRGB(190, 190, 190), Color3.fromRGB(255, 110, 100)
local DARK, WHITE = Color3.fromRGB(45, 40, 70), Color3.new(1, 1, 1)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function round(o, r) new("UICorner", {CornerRadius = UDim.new(0, r or 14)}, o) return o end
local function stroke(o, color, th) return new("UIStroke", {Color = color, Thickness = th or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function text(props, parent)
	local t = new("TextLabel", {BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = BROWN}, parent)
	for k, v in props do t[k] = v end
	return t
end
local function btn(props, parent, onClick)
	local b = new("TextButton", {Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = BROWN, AutoButtonColor = true}, parent)
	for k, v in props do b[k] = v end
	round(b)
	if onClick then b.Activated:Connect(onClick) end
	return b
end
local function tween(o, t, goal, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad), goal)
	tw:Play()
	return tw
end
local function timeLeft(at)
	local s = math.max(0, at - os.time())
	if s >= 3600 then return ("%dh %dm"):format(s // 3600, (s % 3600) // 60) end
	if s >= 60 then return ("%dm %ds"):format(s // 60, s % 60) end
	return ("%ds"):format(s)
end
local function powerFace(ratio)
	if ratio >= 1.2 then return "😀", Color3.fromRGB(90, 200, 80) end
	if ratio >= 0.9 then return "🙂", Color3.fromRGB(230, 180, 40) end
	return "😬", Color3.fromRGB(240, 100, 80)
end

---------------------------------------------------------------- window
local gui = new("ScreenGui", {Name = "RaidGui", ResetOnSpawn = false, DisplayOrder = 6, Enabled = false}, player:WaitForChild("PlayerGui"))
new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Active = true}, gui)
local win = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.95, 0.9),
	BackgroundColor3 = CREAM, ClipsDescendants = true}, gui), 22)
stroke(win, RED, 5)
new("UISizeConstraint", {MaxSize = Vector2.new(980, 660)}, win)

text({Text = "⚔️ Raid Gate", Position = UDim2.new(0, 16, 0, 8), Size = UDim2.new(0.4, 0, 0, 50), TextXAlignment = Enum.TextXAlignment.Left}, win)
local closeBtn = btn({Text = "X", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(56, 56),
	BackgroundColor3 = RED, TextColor3 = WHITE}, win)

-- energy bar
local energyBox = round(new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -80, 0, 12), Size = UDim2.new(0.5, 0, 0, 50),
	BackgroundColor3 = DARK}, win))
local energyText = text({Position = UDim2.new(0, 10, 0, 2), Size = UDim2.new(0.42, 0, 1, -4), TextColor3 = Color3.fromRGB(255, 230, 90),
	TextXAlignment = Enum.TextXAlignment.Left}, energyBox)
local pipRow = new("Frame", {Position = UDim2.new(0.45, 0, 0.2, 0), Size = UDim2.new(0.53, 0, 0.6, 0), BackgroundTransparency = 1}, energyBox)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.01, 0)}, pipRow)
local pips = {}
for i = 1, Data.EnergyMax do
	pips[i] = round(new("Frame", {Size = UDim2.new(0.09, 0, 1, 0), BackgroundColor3 = GREY}, pipRow), 6)
end

local function stepBubble(n, y)
	round(text({Text = tostring(n), Position = UDim2.new(0, 16, y, 0), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 0,
		BackgroundColor3 = RED, TextColor3 = WHITE}, win), 17)
end
stepBubble(1, 0.115)
local raidRow = new("Frame", {Position = UDim2.new(0, 58, 0.11, 0), Size = UDim2.new(1, -70, 0.36, 0), BackgroundTransparency = 1}, win)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.012, 0)}, raidRow)

stepBubble(2, 0.495)
local teamCount = text({Position = UDim2.new(0, 58, 0.49, 0), Size = UDim2.new(0.3, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Left}, win)
local petRow = new("ScrollingFrame", {Position = UDim2.new(0, 58, 0.49, 38), Size = UDim2.new(1, -70, 0.26, -38), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 8, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new()}, win)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10)}, petRow)
new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10)}, petRow)

stepBubble(3, 0.8)
local summary = text({Position = UDim2.new(0, 58, 0.78, 0), Size = UDim2.new(0.42, 0, 0.18, 0), TextXAlignment = Enum.TextXAlignment.Left}, win)
local fightBtn = btn({Text = "⚔️ FIGHT!  ⚡1", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0.78, 0), Size = UDim2.new(0.45, 0, 0.18, 0),
	BackgroundColor3 = GREY, TextColor3 = WHITE}, win)
stroke(fightBtn, WHITE, 3)

---------------------------------------------------------------- battle view
local battle = round(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Visible = false, ZIndex = 10, ClipsDescendants = true}, win), 22)
new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(110, 80, 170), Color3.fromRGB(50, 40, 90)), Rotation = 90}, battle)
local battleTitle = text({Position = UDim2.new(0, 16, 0, 8), Size = UDim2.new(0.5, 0, 0, 44), TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11}, battle)
local speedBtn = btn({Text = "▶ x1", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -110, 0, 12), Size = UDim2.fromOffset(90, 44),
	BackgroundColor3 = Color3.fromRGB(255, 220, 120), ZIndex = 11}, battle)
local skipBtn = btn({Text = "⏩", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(80, 44),
	BackgroundColor3 = Color3.fromRGB(200, 200, 255), ZIndex = 11}, battle)
local arena = new("Frame", {Position = UDim2.new(0, 0, 0, 64), Size = UDim2.new(1, 0, 1, -64), BackgroundTransparency = 1, ZIndex = 11}, battle)
local function column(x)
	local f = new("Frame", {Position = UDim2.new(x, 16, 0, 0), Size = UDim2.new(0.4, -16, 1, -12), BackgroundTransparency = 1, ZIndex = 11}, arena)
	new("UIListLayout", {Padding = UDim.new(0.015, 0), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, f)
	return f
end
local teamCol = column(0)
local enemyCol = column(0.6)
local vs = text({Text = "VS", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(110, 80),
	TextColor3 = Color3.fromRGB(255, 220, 90), ZIndex = 11}, arena)
local fx = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 25}, battle) -- effects layer
local flash = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 40}, battle)
local banner = text({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.8, 0.22),
	TextColor3 = Color3.fromRGB(255, 225, 90), TextStrokeTransparency = 0, Visible = false, ZIndex = 45}, battle)

local resultBox = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.66),
	BackgroundColor3 = Color3.fromRGB(255, 235, 150), Visible = false, ZIndex = 50}, battle), 20)
stroke(resultBox, Color3.fromRGB(255, 160, 60), 5)
local resultTitle = text({Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.9, 0.2), ZIndex = 51}, resultBox)
local lootRow = new("Frame", {Position = UDim2.fromScale(0.05, 0.28), Size = UDim2.fromScale(0.9, 0.44), BackgroundTransparency = 1, ZIndex = 51}, resultBox)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.03, 0)}, lootRow)
local doneBtn = btn({Text = "👍", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromScale(0.36, 0.18),
	BackgroundColor3 = GREEN, TextColor3 = WHITE, ZIndex = 51}, resultBox)

-- one fighter card; the visible part ("Inner") can move without breaking the list layout
local function unitCard(parent, name, maxHp, color, accent, boss, badge, order, side)
	local slot = new("Frame", {Size = UDim2.new(1, 0, boss and 0.26 or 0.155, 0), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 12}, parent)
	local inner = round(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = CREAM, ZIndex = 12}, slot))
	local st = stroke(inner, boss and Color3.fromRGB(255, 210, 60) or color, boss and 5 or 3)
	local picX = side == "T" and 0 or 0.74
	local picProps = {Position = UDim2.new(picX, 2, 0, 0), Size = UDim2.new(0.26, 0, 1, 0), ZIndex = 13}
	local vf
	if side == "T" then
		vf = CritterUI.Portrait(inner, Data, name, picProps)
	else
		local t = CritterUI.Template("EnemyModels", name)
		vf = t and CritterUI.ModelView(inner, t, picProps, {Yaw = math.pi * 0.85})
			or CritterUI.Creature(inner, color, accent, {Boss = boss}, picProps)
	end
	CritterUI.Animate(vf, "idle")
	local textX = side == "T" and 0.27 or 0.02
	text({Text = name .. (badge and ("  " .. badge) or ""), Position = UDim2.new(textX, 0, 0.06, 0), Size = UDim2.new(0.7, 0, 0.42, 0),
		TextXAlignment = side == "T" and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right, ZIndex = 13}, inner)
	local barBg = round(new("Frame", {Position = UDim2.new(textX, 0, 0.56, 0), Size = UDim2.new(0.7, 0, 0.32, 0), BackgroundColor3 = Color3.fromRGB(220, 210, 200), ZIndex = 13}, inner), 8)
	local bar = round(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN, ZIndex = 14}, barBg), 8)
	local hpText = text({Size = UDim2.fromScale(1, 1), Text = tostring(maxHp), TextColor3 = WHITE, TextStrokeTransparency = 0.4, ZIndex = 15}, barBg)
	local hurt = round(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 60, 60), BackgroundTransparency = 1, ZIndex = 16}, inner))
	return {Slot = slot, Inner = inner, Stroke = st, Bar = bar, HPText = hpText, Max = maxHp, Hurt = hurt, VF = vf, Side = side, Dead = false}
end

local speed, skipping = 1, false
speedBtn.Activated:Connect(function()
	speed = speed == 1 and 2 or (speed == 2 and 3 or 1)
	speedBtn.Text = ("▶ x%d"):format(speed)
end)
skipBtn.Activated:Connect(function() skipping = true end)

local function centerOf(gui)
	local p = gui.AbsolutePosition + gui.AbsoluteSize / 2 - battle.AbsolutePosition
	return UDim2.fromOffset(p.X, p.Y)
end

local ATTACK_ICON = {Tank = "👊", Striker = "💥", Speedy = "⚡"}
local function pose(card, name)
	card.VF:SetAttribute("PoseSpeed", speed)
	card.VF:SetAttribute("PoseAt", os.clock())
	card.VF:SetAttribute("Pose", name)
end

local function attackAnim(atk, target, dmg, crit, icon)
	local dir = atk.Side == "T" and 1 or -1
	pose(atk, "attack")
	-- lunge toward the other side
	tween(atk.Inner, 0.09 / speed, {Position = UDim2.fromOffset(36 * dir, 0)}, Enum.EasingStyle.Back)
	task.delay(0.12 / speed, function() tween(atk.Inner, 0.15 / speed, {Position = UDim2.new()}) end)
	-- a flying icon
	local shot = text({Text = icon, AnchorPoint = Vector2.new(0.5, 0.5), Position = centerOf(atk.Inner), Size = UDim2.fromOffset(46, 46), ZIndex = 30}, fx)
	tween(shot, 0.22 / speed, {Position = centerOf(target.Inner), Rotation = 180 * dir})
	task.delay(0.22 / speed, function()
		shot:Destroy()
		if not target.Dead then pose(target, "hit") end
		-- hit: shake, red flash, number
		target.Hurt.BackgroundTransparency = 0.35
		tween(target.Hurt, 0.3, {BackgroundTransparency = 1})
		for i, x in {-8, 8, -5, 0} do
			task.delay(i * 0.04, function() target.Inner.Position = UDim2.fromOffset(x, 0) end)
		end
		local num = text({Text = (crit and "CRIT " or "-") .. dmg, AnchorPoint = Vector2.new(0.5, 0.5), Position = centerOf(target.Inner),
			Size = UDim2.fromOffset(crit and 150 or 90, crit and 54 or 40), TextColor3 = crit and Color3.fromRGB(255, 220, 40) or Color3.fromRGB(255, 90, 90),
			TextStrokeTransparency = 0, ZIndex = 32}, fx)
		local p = num.Position
		tween(num, 0.8, {Position = p + UDim2.fromOffset(0, -60), TextTransparency = 1, TextStrokeTransparency = 1})
		task.delay(0.85, function() num:Destroy() end)
		if crit then
			flash.BackgroundTransparency = 0.5
			tween(flash, 0.25, {BackgroundTransparency = 1})
		end
	end)
end

local function knockOut(card)
	card.Dead = true
	tween(card.Inner, 0.4, {BackgroundTransparency = 0.5, Rotation = card.Side == "T" and -6 or 6})
	task.delay(0.3 / speed, function() pose(card, "ko") end)
	text({Text = "💫", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(card.Side == "T" and 0.13 or 0.87, 0.3),
		Size = UDim2.fromOffset(40, 40), ZIndex = 17}, card.Inner)
end

local function showBanner(msg, hold)
	banner.Text = msg
	banner.Visible = true
	banner.Size = UDim2.fromScale(0.2, 0.06)
	tween(banner, 0.35, {Size = UDim2.fromScale(0.8, 0.22)}, Enum.EasingStyle.Back)
	task.wait(hold)
	banner.Visible = false
end

local function confetti()
	local colors = {Color3.fromRGB(255, 110, 120), Color3.fromRGB(255, 220, 80), Color3.fromRGB(120, 210, 255), Color3.fromRGB(150, 230, 120), Color3.fromRGB(210, 140, 255)}
	for _ = 1, 60 do
		local c = new("Frame", {Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)), Position = UDim2.new(math.random(), 0, 0, -20),
			BackgroundColor3 = colors[math.random(#colors)], Rotation = math.random(0, 180), ZIndex = 48}, fx)
		local t = 1.6 + math.random() * 1.4
		tween(c, t, {Position = UDim2.new(math.random(), 0, 1.05, 0), Rotation = math.random(180, 720)}, Enum.EasingStyle.Linear)
		task.delay(t, function() c:Destroy() end)
	end
end

local STAT_ICON = {HP = "❤️", ATK = "⚔️", SPD = "⚡"}
local function lootCard(loot, i)
	local rarityColor = loot.Rarity and Data.Rarities[loot.Rarity].Color or Color3.fromRGB(255, 220, 120)
	local card = round(new("Frame", {Size = UDim2.new(0, 0, 0.95, 0), BackgroundColor3 = rarityColor:Lerp(WHITE, 0.45), ZIndex = 52}, lootRow), 16)
	stroke(card, rarityColor, 4)
	if loot.Type == "Gear" then
		local def, amount = Data.GearBonus(loot)
		local t = CritterUI.Template("GearModels", def.Name)
		if t then
			local vf = CritterUI.ModelView(card, t, {Size = UDim2.fromScale(1, 0.62), ZIndex = 53}, {Yaw = 0})
			CritterUI.Animate(vf, "spin")
		else
			text({Text = def.Icon, Size = UDim2.fromScale(1, 0.6), ZIndex = 53}, card)
		end
		local bonus = def.Stat == "SPD" and (math.floor(amount * 100 + 0.5) .. "%") or tostring(math.floor(amount))
		text({Text = "+" .. bonus .. STAT_ICON[def.Stat], Position = UDim2.fromScale(0.05, 0.62), Size = UDim2.fromScale(0.9, 0.34), ZIndex = 53}, card)
		CritterUI.Glow(card, loot.Rarity, rarityColor)
	else
		text({Text = "💰", Size = UDim2.fromScale(1, 0.6), ZIndex = 53}, card)
		text({Text = tostring(loot.Amount), Position = UDim2.fromScale(0.05, 0.62), Size = UDim2.fromScale(0.9, 0.34), ZIndex = 53}, card)
	end
	task.wait(0.25 * (i - 1))
	tween(card, 0.35, {Size = UDim2.new(0.3, 0, 0.95, 0)}, Enum.EasingStyle.Back)
end

local function playBattle(res)
	local raid = Data.Raids[res.Raid]
	battleTitle.Text = ("⚔️ %s"):format(raid.Name)
	for _, col in {teamCol, enemyCol, fx, lootRow} do
		for _, ch in col:GetChildren() do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
	end
	resultBox.Visible = false
	battle.Visible = true
	skipping = false
	local cards = {T = {}, E = {}}
	local classOf = {}
	for i, u in res.Start.Team do
		local s = Data.SpeciesByName[u.Species]
		cards.T[i] = unitCard(teamCol, u.Name, u.HP, s.Color, s.Ear, false, ("Lv%d %s"):format(u.Level, Data.Classes[u.Class].Icon), i, "T")
		classOf[i] = u.Class
	end
	for i, e in res.Start.Enemies do
		cards.E[i] = unitCard(enemyCol, e.Name, e.HP, e.Color, e.Color:Lerp(Color3.new(0, 0, 0), 0.3), e.Boss, e.Boss and "👑" or nil, i, "E")
	end
	-- intro
	vs.Size = UDim2.fromOffset(20, 15)
	tween(vs, 0.4, {Size = UDim2.fromOffset(110, 80)}, Enum.EasingStyle.Back)
	if not skipping then showBanner(("👑 %s"):format(raid.Boss), 1.1) end
	if not skipping then showBanner("FIGHT!", 0.6) end
	local last = 0
	for _, ev in res.Log do
		local t, side, ai, ti, dmg, crit, hpLeft = ev[1], ev[2], ev[3], ev[4], ev[5], ev[6], ev[7]
		if not skipping then task.wait(math.max(0, (t - last) / speed)) end
		last = t
		local atk = cards[side][ai]
		local target = cards[side == "T" and "E" or "T"][ti]
		if not skipping then
			attackAnim(atk, target, dmg, crit, side == "T" and ATTACK_ICON[classOf[ai]] or "💢")
			task.wait(0.22 / speed)
		end
		local frac = hpLeft / target.Max
		tween(target.Bar, skipping and 0 or 0.25, {Size = UDim2.fromScale(frac, 1),
			BackgroundColor3 = frac > 0.5 and GREEN or (frac > 0.25 and Color3.fromRGB(255, 200, 60) or RED)})
		target.HPText.Text = tostring(hpLeft)
		if hpLeft <= 0 and not target.Dead then knockOut(target) end
	end
	task.wait(0.7)
	resultTitle.Text = res.Win and "🎉 VICTORY! 🎉" or "💪 So close!"
	resultBox.Visible = true
	resultBox.Size = UDim2.fromScale(0.4, 0.4)
	tween(resultBox, 0.35, {Size = UDim2.fromScale(0.62, 0.66)}, Enum.EasingStyle.Back)
	if res.Win then confetti() end
	task.wait(0.35)
	for i, line in res.Loot do task.spawn(lootCard, line, i) end
end
doneBtn.Activated:Connect(function()
	battle.Visible = false
	stateEvent:FireServer()
end)

---------------------------------------------------------------- picking
local state = nil
local pickedRaid = 1
local team = {} -- ordered list of pet ids
local raidCards = {}
local render

for i, raid in Data.Raids do
	local card = btn({Text = "", Size = UDim2.new(0.188, 0, 1, 0), BackgroundColor3 = raid.Color:Lerp(WHITE, 0.55), AutoButtonColor = false}, raidRow)
	local st = stroke(card, raid.Color, 4)
	local bossInfo = raid.Enemies[#raid.Enemies]
	local pic = round(new("Frame", {Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(1, -12, 0.56, -6), BackgroundColor3 = DARK}, card))
	local bossT = CritterUI.Template("EnemyModels", bossInfo.Name)
	local bossVf = bossT and CritterUI.ModelView(pic, bossT, {Size = UDim2.fromScale(1, 1)}, {Yaw = math.pi * 0.85})
		or CritterUI.Creature(pic, bossInfo.Color, bossInfo.Color:Lerp(Color3.new(0, 0, 0), 0.3), {Boss = true}, {Size = UDim2.fromScale(1, 1)})
	CritterUI.Animate(bossVf, "idle")
	text({Text = raid.Boss, Position = UDim2.new(0, 6, 0.58, 0), Size = UDim2.new(1, -12, 0.14, 0)}, card)
	text({Text = string.rep("⭐", raid.Stars), Position = UDim2.new(0, 6, 0.72, 0), Size = UDim2.new(1, -12, 0.12, 0)}, card)
	text({Text = ("💪%d  🎁x%d"):format(raid.Recommended, raid.GearDrops), Position = UDim2.new(0, 6, 0.85, 0), Size = UDim2.new(1, -12, 0.13, 0)}, card)
	local check = round(text({Text = "✔", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(36, 36),
		BackgroundTransparency = 0, BackgroundColor3 = GREEN, TextColor3 = WHITE, Visible = false, ZIndex = 5}, card), 18)
	raidCards[i] = {Stroke = st, Check = check}
	card.Activated:Connect(function()
		pickedRaid = i
		render()
	end)
end

local function battlers()
	local list = {}
	for _, p in state and state.Pets or {} do
		if not p.Trip and not p.Nest then table.insert(list, p) end
	end
	table.sort(list, function(a, b) return (a.Power or 0) > (b.Power or 0) end)
	return list
end
local function gearIcon(id)
	for _, g in state and state.Gear or {} do
		if g.Id == id then return Data.Gear[g.Kind].Icon end
	end
	return ""
end

function render()
	if not gui.Enabled or not state then return end
	local e = state.Energy or 0
	for i, pip in pips do pip.BackgroundColor3 = i <= e and Color3.fromRGB(255, 220, 60) or Color3.fromRGB(90, 85, 110) end
	energyText.Text = ("⚡ %d/%d"):format(e, Data.EnergyMax) .. (state.EnergyNextAt and ("  +1 " .. timeLeft(state.EnergyNextAt)) or "")
	for i, rc in raidCards do
		local on = pickedRaid == i
		rc.Check.Visible = on
		rc.Stroke.Thickness = on and 7 or 4
		rc.Stroke.Color = on and WHITE or Data.Raids[i].Color
	end
	for _, ch in petRow:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local list = battlers()
	local valid = {}
	for _, p in list do
		if not p.Rest then valid[p.Id] = p end
	end
	for i = #team, 1, -1 do
		if not valid[team[i]] then table.remove(team, i) end
	end
	if #list == 0 then
		text({Text = "⚔️ 🛡️ ⚡  → 🐾 ?", Size = UDim2.new(0, 400, 1, 0), TextXAlignment = Enum.TextXAlignment.Left}, petRow)
	end
	for _, p in list do
		local picked = table.find(team, p.Id)
		local rarity = Data.Rarities[p.Rarity]
		local resting = p.Rest ~= nil
		local b = btn({Text = "", Size = UDim2.new(0, 120, 1, 0), AutoButtonColor = not resting,
			BackgroundColor3 = picked and Color3.fromRGB(255, 225, 120) or (resting and Color3.fromRGB(215, 215, 215) or WHITE)}, petRow,
			function()
				if resting then return end
				local at = table.find(team, p.Id)
				if at then
					table.remove(team, at)
				elseif #team < Data.RaidTeamMax then
					table.insert(team, p.Id)
				end
				render()
			end)
		stroke(b, rarity.Color, picked and 6 or 4)
		CritterUI.Portrait(b, Data, p.Species, {Size = UDim2.new(1, 0, 0.62, 0)}, {Sleepy = resting})
		text({Text = ("Lv%d %s %s"):format(p.Level, Data.Classes[p.Class].Icon, gearIcon(p.GearId)), Position = UDim2.new(0, 4, 0.6, 0),
			Size = UDim2.new(1, -8, 0.2, 0)}, b)
		text({Text = resting and "😴" or ("💪%d"):format(p.Power), Position = UDim2.new(0, 4, 0.8, 0), Size = UDim2.new(1, -8, 0.18, 0)}, b)
		if picked then
			round(text({Text = "✔", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(28, 28),
				BackgroundTransparency = 0, BackgroundColor3 = GREEN, TextColor3 = WHITE}, b), 14)
		end
	end
	teamCount.Text = ("🐾 %d/%d"):format(#team, Data.RaidTeamMax)
	local power = 0
	for _, id in team do power += valid[id].Power end
	local raid = Data.Raids[pickedRaid]
	local ready = #team >= Data.RaidTeamMin and e >= 1
	if #team < Data.RaidTeamMin then
		summary.Text = ("👆 %d+ 🐾"):format(Data.RaidTeamMin)
		summary.TextColor3 = BROWN
	elseif e < 1 then
		summary.Text = "⚡ 0  😴"
		summary.TextColor3 = BROWN
	else
		local face, color = powerFace(power / raid.Recommended)
		summary.Text = ("💪%d  vs  💪%d  %s"):format(power, raid.Recommended, face)
		summary.TextColor3 = color
	end
	fightBtn.BackgroundColor3 = ready and RED or GREY
end

local busy = false
fightBtn.Activated:Connect(function()
	if busy or #team < Data.RaidTeamMin or not state or (state.Energy or 0) < 1 then return end
	busy = true
	local res = actionFn:InvokeServer("Raid", pickedRaid, team)
	busy = false
	if type(res) ~= "table" then return end
	if res.Error then
		summary.Text = res.Error
		return
	end
	playBattle(res)
end)

stateEvent.OnClientEvent:Connect(function(s)
	state = s
	if not battle.Visible then render() end
end)

local function open()
	gui.Enabled = true
	battle.Visible = false
	stateEvent:FireServer()
	render()
end
closeBtn.Activated:Connect(function()
	if not battle.Visible then gui.Enabled = false end
end)

local gate = workspace:WaitForChild("CritterAcres"):WaitForChild("RaidGate")
gate:WaitForChild("Pedestal"):WaitForChild("RaidPrompt").Triggered:Connect(open)

task.spawn(function() -- energy timer
	while true do
		task.wait(1)
		if gui.Enabled and state and not battle.Visible then
			energyText.Text = ("⚡ %d/%d"):format(state.Energy or 0, Data.EnergyMax)
				.. (state.EnergyNextAt and ("  +1 " .. timeLeft(state.EnergyNextAt)) or "")
			if state.EnergyNextAt and os.time() >= state.EnergyNextAt then stateEvent:FireServer() end
		end
	end
end)
