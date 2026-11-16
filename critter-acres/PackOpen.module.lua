-- Critter Acres: PackOpen (ReplicatedStorage)
-- Card-pack style reveal used for seed packs, eggs, prize packs, mail and gifts.
--   1. The pack drops in, floats and shines. Better stuff inside = stronger glow leaking out.
--   2. One tap: a tear runs along the top, the flap flies off and light spills out.
--   3. The cards slide up out of the pack as a face-down stack (best card at the bottom).
--   4. Tap to reveal each card: rare cards glow and shake first, then flip with a flash.
--   5. Every card lands in a fan for a final look. ✔ to finish. ⏩ reveals the rest at once.
-- PackOpen.Play(parentFrame, opts) yields until the player is done.
--   opts = {Style = "Pack"|"Egg", Icon, Title, Color, Footer, Cards = {{Rarity, Color, Name, Sub, Odds, Badges, Art(frame, z)}}}
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local PackOpen = {}

local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(40, 32, 60)
local ORDER = {Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5}
local RARITY_COLOR = {Common = Color3.fromRGB(170, 170, 170), Rare = Color3.fromRGB(80, 160, 255), Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40), Mythic = Color3.fromRGB(255, 110, 200)}
local NAMES = {"Common", "Rare", "Epic", "Legendary", "Mythic"}

local TICK = "rbxasset://sounds/electronicpingshort.wav"
local POP = "rbxasset://sounds/snap.wav"
local function sound(id, speed, vol)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed or 1
	s.Volume = vol or 0.6
	SoundService:PlayLocalSound(s)
end

local function tween(obj, secs, goal, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(secs, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local function loop(obj, secs, goal, style)
	local tw = TweenService:Create(obj, TweenInfo.new(secs, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), goal)
	tw:Play()
	return tw
end
local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(0, 18)
	c.Parent = obj
	return c
end
local function label(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = WHITE
	t.TextStrokeTransparency = 0.4
	t.ZIndex = 70
	for k, v in props do t[k] = v end
	t.Parent = parent
	return t
end
local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.ZIndex = 70
	for k, v in props do f[k] = v end
	f.Parent = parent
	return f
end
local function gradient(obj, a, b, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rot or 90
	g.Parent = obj
	return g
end
local function flash(parent, color, strength)
	local f = frame(parent, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = color or WHITE, BackgroundTransparency = 1 - (strength or 0.8), ZIndex = 95})
	tween(f, 0.5, {BackgroundTransparency = 1})
	task.delay(0.55, function() f:Destroy() end)
end
local function rays(parent, pos, color, z, count)
	local holder = frame(parent, {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(1, 1), ZIndex = z})
	count = count or 6
	for i = 0, count - 1 do
		local r = frame(holder, {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(46, 1000), Rotation = i * (180 / count), BackgroundColor3 = color, ZIndex = z})
		local g = Instance.new("UIGradient", r)
		g.Rotation = 90
		g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1)})
		TweenService:Create(r, TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {Rotation = i * (180 / count) + 360}):Play()
	end
	return holder
end
local function sparks(parent, at, color, n, spread)
	for _ = 1, n or 18 do
		local s = frame(parent, {AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = UDim2.fromOffset(math.random(6, 12), math.random(6, 12)),
			BackgroundColor3 = math.random() < 0.6 and color or WHITE, Rotation = math.random(0, 90), ZIndex = 90})
		corner(s, UDim.new(1, 0))
		local dx, dy = math.random(-(spread or 300), spread or 300), math.random(-(spread or 300), (spread or 300) * 0.3)
		tween(s, 0.9 + math.random() * 0.4, {Position = at + UDim2.fromOffset(dx, dy), BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2)})
		task.delay(1.4, function() s:Destroy() end)
	end
end
local function confetti(parent, color, n)
	for _ = 1, n or 40 do
		local c = frame(parent, {Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)), Position = UDim2.new(math.random(), 0, 0, -20),
			BackgroundColor3 = math.random() < 0.5 and color or Color3.fromHSV(math.random(), 0.6, 1), Rotation = math.random(0, 180), ZIndex = 92})
		local t = 1.6 + math.random() * 1.4
		tween(c, t, {Position = UDim2.new(math.random(), 0, 1.05, 0), Rotation = math.random(180, 720)}, Enum.EasingStyle.Linear)
		task.delay(t, function() c:Destroy() end)
	end
end

-- a bouncing finger that says "tap here" without words
local function tapHand(parent, pos)
	local hand = label(parent, {Text = "👆", AnchorPoint = Vector2.new(0.5, 0), Position = pos, Size = UDim2.fromOffset(64, 64), ZIndex = 96,
		TextStrokeTransparency = 1})
	loop(hand, 0.45, {Position = pos + UDim2.fromOffset(0, -16)})
	return hand
end

-- waits for a tap on `hit` (or the time limit). Returns true if tapped.
local function waitTap(hit, limit)
	local done = false
	local conn = hit.Activated:Connect(function() done = true end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < (limit or 8) do task.wait() end
	conn:Disconnect()
	return done
end

---------------------------------------------------------------- prize helpers (used by many screens)
function PackOpen.PrizeName(Data, p)
	if p.Type == "Coins" then return ("%d Coins"):format(p.Amount or 0) end
	if p.Type == "Berry" then return ("%d %s"):format(p.Amount or 1, p.Crop) end
	if p.Type == "Seed" then return ("%d %s seed%s"):format(p.Amount or 1, p.Crop, (p.Amount or 1) > 1 and "s" or "") end
	if p.Type == "Egg" then return (Data.Eggs[p.Kind] or Data.Eggs.Mystery).Name end
	if p.Type == "Res" then return ("%d %s"):format(p.Amount or 1, p.Res) end
	if p.Type == "Outfit" then return p.Name or "Hat" end
	if p.Type == "Spin" then return ("%d Prize pack%s"):format(p.Amount or 1, (p.Amount or 1) > 1 and "s" or "") end
	if p.Type == "Pet" then return p.Species or "Pet" end
	return "Prize"
end
function PackOpen.PrizeArt(Data, CritterUI, parent, p, z)
	if p.Type == "Pet" and p.Species then
		local vf = CritterUI.Portrait(parent, Data, p.Species, {Size = UDim2.fromScale(1, 0.85), ZIndex = z})
		CritterUI.Animate(vf, "show")
	elseif p.Type == "Outfit" and p.Name then
		local vf = CritterUI.ModelView(parent, CritterUI.BuildOutfit(p.Name), {Size = UDim2.fromScale(1, 0.85), ZIndex = z}, {Yaw = 0})
		CritterUI.Animate(vf, "spin")
	elseif p.Type == "Spin" then
		label(parent, {Text = "🎁", Size = UDim2.fromScale(1, 0.8), ZIndex = z, TextStrokeTransparency = 1})
	else
		label(parent, {Text = Data.PrizeIcon(p), Size = UDim2.fromScale(1, 0.8), ZIndex = z, TextStrokeTransparency = 1})
	end
	if p.Dup then
		local chip = label(parent, {Text = "🔁 💰" .. p.Dup, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.8, 0.18),
			BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 240, 190), TextColor3 = DARK, TextStrokeTransparency = 1, ZIndex = z + 1})
		corner(chip, UDim.new(0, 10))
	end
end
function PackOpen.PrizeCard(Data, CritterUI, p)
	return {Rarity = p.Rarity or "Common", Name = PackOpen.PrizeName(Data, p), Sub = p.From and ("from " .. p.From) or nil,
		Art = function(f, z) PackOpen.PrizeArt(Data, CritterUI, f, p, z) end}
end
function PackOpen.OddsText(n)
	n = math.floor(n + 0.5)
	local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "1 in " .. s
end

---------------------------------------------------------------- card faces
local CARD_W, CARD_H = 210, 294

local function cardBack(card, packColor)
	card.BackgroundColor3 = packColor
	gradient(card, packColor:Lerp(WHITE, 0.25), packColor:Lerp(DARK, 0.45), 120)
	-- diagonal stripes + center emblem
	local pattern = frame(card, {Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = card.ZIndex + 1})
	corner(pattern)
	for i = -3, 6 do
		frame(pattern, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(i * 0.18, 0.5), Size = UDim2.new(0.05, 0, 1.6, 0), Rotation = 30,
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, ZIndex = card.ZIndex + 1})
	end
	local ring = frame(pattern, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.44),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.82, ZIndex = card.ZIndex + 2})
	corner(ring, UDim.new(1, 0))
	label(ring, {Text = "🐾", Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 1, ZIndex = card.ZIndex + 3})
	local inner = Instance.new("UIStroke")
	inner.Color, inner.Thickness, inner.Transparency = WHITE, 3, 0.4
	inner.Parent = pattern
	return pattern
end

local function cardFront(card, c, color, z)
	for _, ch in card:GetChildren() do
		if ch:IsA("UIGradient") or ch.Name == "Back" then ch:Destroy() end
	end
	card.BackgroundColor3 = WHITE
	gradient(card, color:Lerp(WHITE, 0.78), color:Lerp(WHITE, 0.35), 90)
	local tier = ORDER[c.Rarity] or 1
	-- art window
	local window = frame(card, {Position = UDim2.fromScale(0.06, 0.05), Size = UDim2.fromScale(0.88, 0.58), BackgroundColor3 = color:Lerp(DARK, 0.15),
		ClipsDescendants = true, ZIndex = z})
	corner(window, UDim.new(0, 14))
	gradient(window, color:Lerp(WHITE, 0.2), color:Lerp(DARK, 0.5), 90)
	if tier >= 3 then -- holo shimmer sweeping over the art
		local holo = frame(window, {Size = UDim2.new(0.35, 0, 1.6, 0), Position = UDim2.fromScale(-0.5, -0.3), Rotation = 25, BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.7, ZIndex = z + 3})
		local hg = Instance.new("UIGradient", holo)
		hg.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 220)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 230, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 150))})
		TweenService:Create(holo, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0.4), {Position = UDim2.fromScale(1.2, -0.3)}):Play()
	end
	local art = frame(window, {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 1})
	if c.Art then pcall(c.Art, art, z + 2) end
	-- name ribbon
	local ribbon = frame(card, {Position = UDim2.fromScale(0.04, 0.65), Size = UDim2.fromScale(0.92, 0.13), BackgroundColor3 = color, ZIndex = z})
	corner(ribbon, UDim.new(0, 10))
	label(ribbon, {Text = c.Name or "", Position = UDim2.fromScale(0.04, 0.08), Size = UDim2.fromScale(0.92, 0.84), ZIndex = z + 1, TextStrokeTransparency = 0.5})
	-- stars + rarity word
	label(card, {Text = string.rep("⭐", tier) .. "  " .. (c.Rarity or ""), Position = UDim2.fromScale(0.05, 0.8), Size = UDim2.fromScale(0.9, 0.08),
		ZIndex = z, TextColor3 = color:Lerp(DARK, 0.45), TextStrokeTransparency = 1})
	local sub = c.Sub or ""
	if c.Odds and c.Odds >= 10 then sub = (sub ~= "" and (sub .. "  ") or "") .. "🎲 " .. PackOpen.OddsText(c.Odds) end
	if sub ~= "" then
		label(card, {Text = sub, Position = UDim2.fromScale(0.05, 0.89), Size = UDim2.fromScale(0.9, 0.07), ZIndex = z, TextColor3 = DARK, TextStrokeTransparency = 1})
	end
	-- badges as little tags on the top corner
	for k, b in c.Badges or {} do
		local tag = label(card, {Text = b, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 8, 0, -10 + (k - 1) * 30), Size = UDim2.new(0.8, 0, 0, 28),
			BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 90, 110), TextStrokeTransparency = 0.6, ZIndex = z + 5, Rotation = 6})
		corner(tag, UDim.new(0, 10))
	end
	local st = card:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = color
		st.Thickness = tier >= 3 and 6 or 4
		if tier >= 3 then loop(st, 0.5, {Thickness = 10}) end
	end
end

---------------------------------------------------------------- the show
function PackOpen.Play(parent, opts)
	-- best card last, like opening a real pack
	local cards = table.clone(opts.Cards or {})
	table.sort(cards, function(a, b) return (ORDER[a.Rarity] or 1) < (ORDER[b.Rarity] or 1) end)
	local best = 1
	for _, c in cards do best = math.max(best, ORDER[c.Rarity] or 1) end
	local bestColor = RARITY_COLOR[NAMES[best]]
	local color = opts.Color or Color3.fromRGB(255, 170, 90)
	local isEgg = opts.Style == "Egg"

	local root = frame(parent, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(15, 10, 30), BackgroundTransparency = 1, ZIndex = 70})
	tween(root, 0.3, {BackgroundTransparency = 0.25})
	local spot = frame(root, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 700),
		BackgroundColor3 = color, BackgroundTransparency = 0.75, ZIndex = 70})
	corner(spot, UDim.new(1, 0))
	local sg = Instance.new("UIGradient", spot)
	sg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
	local hit = Instance.new("TextButton")
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 71
	hit.Parent = root
	local title = label(root, {Text = (opts.Icon or "🎁") .. " " .. (opts.Title or ""), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.new(0.6, 0, 0, 50), ZIndex = 80})
	local skipping = false
	local skip = Instance.new("TextButton")
	skip.Text = "⏩"
	skip.Font = Enum.Font.FredokaOne
	skip.TextScaled = true
	skip.TextColor3 = WHITE
	skip.BackgroundColor3 = Color3.fromRGB(90, 80, 130)
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.new(1, -18, 0, 18)
	skip.Size = UDim2.fromOffset(70, 54)
	skip.ZIndex = 96
	corner(skip, UDim.new(0, 14))
	skip.Parent = root
	skip.Activated:Connect(function() skipping = true end)

	---------------------------------------------------------------- 1. the pack (or egg) drops in
	local packSize = isEgg and UDim2.fromOffset(250, 300) or UDim2.fromOffset(240, 340)
	local pack = frame(root, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, -0.5), Size = packSize,
		BackgroundColor3 = color, BackgroundTransparency = isEgg and 1 or 0, ZIndex = 76})
	local glow = frame(root, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 400),
		BackgroundColor3 = bestColor, BackgroundTransparency = 1, ZIndex = 74})
	corner(glow, UDim.new(0.5, 0))
	local flap
	if isEgg then
		label(pack, {Text = opts.Icon or "🥚", Size = UDim2.fromScale(1, 1), ZIndex = 77, TextStrokeTransparency = 1})
	else
		corner(pack, UDim.new(0, 16))
		gradient(pack, color:Lerp(WHITE, 0.4), color:Lerp(DARK, 0.35), 75)
		pack.ClipsDescendants = true
		local foil = frame(pack, {Size = UDim2.new(0.22, 0, 1.4, 0), Position = UDim2.fromScale(-0.4, -0.2), Rotation = 22, BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.55, ZIndex = 77})
		TweenService:Create(foil, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0.5), {Position = UDim2.fromScale(1.3, -0.2)}):Play()
		local emblem = frame(pack, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(150, 150),
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.75, ZIndex = 77})
		corner(emblem, UDim.new(1, 0))
		label(emblem, {Text = opts.Icon or "🎁", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 78, TextStrokeTransparency = 1})
		label(pack, {Text = "x" .. #cards, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(90, 36), ZIndex = 78,
			BackgroundTransparency = 0, BackgroundColor3 = DARK}).Parent = pack
		-- the flap that tears off (with a zigzag edge)
		flap = frame(root, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, -0.5), Size = UDim2.fromOffset(240, 58),
			BackgroundColor3 = color:Lerp(WHITE, 0.3), ZIndex = 79})
		corner(flap, UDim.new(0, 14))
		gradient(flap, color:Lerp(WHITE, 0.55), color:Lerp(WHITE, 0.15), 90)
		for i = 0, 11 do
			frame(flap, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(i / 11, 0, 1, 0), Size = UDim2.fromOffset(16, 16), Rotation = 45,
				BackgroundColor3 = color:Lerp(WHITE, 0.15), ZIndex = 79})
		end
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = bestColor
	stroke.Thickness = isEgg and 0 or (best >= 3 and 5 or 3)
	stroke.Transparency = isEgg and 1 or 0
	stroke.Parent = pack

	tween(pack, 0.6, {Position = UDim2.fromScale(0.5, 0.52)}, Enum.EasingStyle.Back)
	if flap then tween(flap, 0.6, {Position = UDim2.new(0.5, 0, 0.52, -170)}, Enum.EasingStyle.Back) end
	-- (quiet entrance)
	task.wait(0.6)
	-- the glow behind the pack hints at what's inside
	if best >= 2 then
		glow.BackgroundTransparency = 0.85
		loop(glow, best >= 4 and 0.35 or 0.7, {BackgroundTransparency = best >= 3 and 0.45 or 0.65, Size = UDim2.fromOffset(340, 450)})
	end
	-- idle float + wobble until tapped
	local idle = true
	task.spawn(function()
		local t = 0
		while idle and pack.Parent do
			t += RunService.RenderStepped:Wait()
			local shake = best >= 3 and math.sin(t * 22) * (best - 2) * 1.5 or 0
			pack.Position = UDim2.new(0.5, shake, 0.52, math.sin(t * 2) * 8)
			pack.Rotation = math.sin(t * 1.6) * 3
			if flap then
				flap.Position = UDim2.new(0.5, shake, 0.52, -170 + math.sin(t * 2) * 8)
				flap.Rotation = pack.Rotation
			end
		end
	end)
	local hand = tapHand(root, UDim2.new(0.5, 70, 0.52, 120))
	if not skipping then waitTap(hit, 12) end
	idle = false
	hand:Destroy()

	---------------------------------------------------------------- 2. tear it open
	if isEgg then
		for k = 1, 3 do -- three quick cracks
			if k == 1 then sound(POP, 0.7, 0.18) end -- one soft crack
			label(pack, {Text = "⚡", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.3 + math.random() * 0.4, 0.3 + math.random() * 0.4),
				Size = UDim2.fromOffset(60 + k * 12, 60 + k * 12), Rotation = math.random(-40, 40), ZIndex = 78, TextColor3 = Color3.fromRGB(90, 70, 50),
				TextStrokeTransparency = 1})
			for _, a in {1, -1, 1, -1, 0} do
				pack.Rotation = a * (5 + k * 4)
				task.wait(skipping and 0 or 0.035)
			end
			task.wait(skipping and 0 or 0.12)
		end
	else
		-- a bright tear line races along the top
		local line = frame(root, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, -120, 0.52, -112), Size = UDim2.fromOffset(0, 8),
			BackgroundColor3 = bestColor:Lerp(WHITE, 0.4), ZIndex = 80})
		corner(line, UDim.new(1, 0))
		local steps = 8
		for i = 1, steps do
			line.Size = UDim2.fromOffset(240 * i / steps, 8)
			if i == 1 then sound(POP, 0.55, 0.18) end -- one short soft tear
			sparks(root, UDim2.new(0.5, -120 + 240 * i / steps, 0.52, -112), bestColor, 3, 60)
			task.wait(skipping and 0 or 0.045)
		end
		line:Destroy()
		tween(flap, 0.5, {Position = UDim2.new(0.75, 0, -0.1, 0), Rotation = 50}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	sound(POP, 0.9, 0.2)
	flash(root, bestColor, 0.6)
	local burst = rays(root, UDim2.fromScale(0.5, 0.45), bestColor, 73, 4 + best * 2)
	sparks(root, UDim2.fromScale(0.5, 0.4), bestColor, 20 + best * 8)
	task.wait(skipping and 0 or 0.2)
	if flap then flap:Destroy() end

	---------------------------------------------------------------- 3. cards rise out of the pack as a stack
	local stack = {}
	for i, c in cards do
		local rc = c.Color or RARITY_COLOR[c.Rarity] or RARITY_COLOR.Common
		local card = Instance.new("TextButton")
		card.Text = ""
		card.AutoButtonColor = false
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.58)
		card.Size = UDim2.fromOffset(CARD_W * 0.92, CARD_H * 0.92)
		card.ZIndex = 75 + (#cards - i) * 0 -- stacking handled by order below
		corner(card, UDim.new(0, 16))
		local st = Instance.new("UIStroke")
		st.Color, st.Thickness, st.ApplyStrokeMode = WHITE, 4, Enum.ApplyStrokeMode.Border
		st.Parent = card
		card.ZIndex = 82
		cardBack(card, color)
		card.Parent = root
		stack[i] = {card = card, data = c, color = rc}
	end
	-- the last card (best) sits at the bottom of the pile: draw earlier cards on top
	for i, v in stack do
		local z = 82 + (#stack - i) * 3
		v.card.ZIndex = z
		for _, d in v.card:GetDescendants() do
			if d:IsA("GuiObject") then d.ZIndex = z + 1 end
		end
	end
	tween(pack, 0.5, {Position = UDim2.fromScale(0.5, 1.3), Rotation = -8}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for i, v in stack do
		local off = (i - 1) * 3
		tween(v.card, 0.55, {Position = UDim2.new(0.5, off, 0.48, -off), Size = UDim2.fromOffset(CARD_W, CARD_H), Rotation = (i - 1) * 1.5}, Enum.EasingStyle.Back)
	end
	task.wait(0.55)
	pack:Destroy()
	glow:Destroy()

	---------------------------------------------------------------- 4. reveal one by one
	local n = #stack
	local vp = root.AbsoluteSize
	local fanW = math.min(CARD_W * 0.7, (vp.X - 80) / math.max(1, n) - 10)
	local fanScale = fanW / CARD_W
	local function fanPos(i)
		local mid = (n + 1) / 2
		return UDim2.new(0.5, (i - mid) * (fanW + 10), 0.5, math.abs(i - mid) * 10 + 20), (i - mid) * 4
	end
	local revealed = {}
	for i, v in stack do
		local c, card = v.data, v.card
		local tier = ORDER[c.Rarity] or 1
		local h2
		if not skipping then
			h2 = tapHand(root, UDim2.new(0.5, CARD_W / 2 - 20, 0.48, CARD_H / 2 - 30))
			-- the top card lifts a bit so you know it's next
			tween(card, 0.2, {Position = UDim2.fromScale(0.5, 0.47), Rotation = 0}, Enum.EasingStyle.Back)
			waitTap(hit, 7)
			h2:Destroy()
		end
		-- build-up for rare cards: colored glow and shaking
		if tier >= 2 and not skipping then
			local aura = frame(root, {AnchorPoint = Vector2.new(0.5, 0.5), Position = card.Position, Size = UDim2.fromOffset(CARD_W + 40, CARD_H + 40),
				BackgroundColor3 = v.color, BackgroundTransparency = 0.6, ZIndex = card.ZIndex - 1})
			corner(aura, UDim.new(0, 30))
			local steps = tier >= 4 and 16 or (tier >= 3 and 11 or 5)
			for k = 1, steps do
				card.Rotation = (k % 2 == 0 and 1 or -1) * (1 + k * 0.35)
				aura.Size = UDim2.fromOffset(CARD_W + 40 + k * 6, CARD_H + 40 + k * 6)
				-- (no ticking while it shakes)
				task.wait(0.09 - k * 0.003)
			end
			card.Rotation = 0
			aura:Destroy()
		end
		-- flip: squash to a sliver, swap faces, pop back
		local size = UDim2.fromOffset(CARD_W, CARD_H)
		tween(card, skipping and 0.05 or 0.13, {Size = UDim2.fromOffset(0, CARD_H * 1.04)}).Completed:Wait()
		cardFront(card, c, v.color, card.ZIndex + 1)
		tween(card, skipping and 0.08 or 0.22, {Size = size}, Enum.EasingStyle.Back)
		sound(POP, 1.3, 0.15) -- gentle flip
		if tier >= 2 then sound(TICK, 0.85, tier >= 4 and 0.3 or 0.22) end -- one soft chime for Rare and better
		local cardRays
		if tier >= 2 then
			flash(root, v.color, tier >= 3 and 0.7 or 0.4)
			sparks(root, card.Position, v.color, 14 + tier * 6)
			if tier >= 3 then
				cardRays = rays(root, card.Position, v.color, card.ZIndex - 1, 8)
				tween(card, 0.3, {Size = UDim2.fromOffset(CARD_W * 1.12, CARD_H * 1.12)}, Enum.EasingStyle.Back)
			end
			if tier >= 4 then confetti(root, v.color, 50) end
		end
		task.wait(skipping and 0 or (tier >= 3 and 1.2 or 0.55))
		if cardRays then cardRays:Destroy() end
		-- slide down into the fan
		local pos, rot = fanPos(i)
		tween(card, skipping and 0.15 or 0.35, {Position = pos, Rotation = rot, Size = UDim2.fromOffset(CARD_W * fanScale, CARD_H * fanScale)})
		table.insert(revealed, {card = card, tier = tier, color = v.color})
		task.wait(skipping and 0 or 0.15)
	end
	burst:Destroy()

	---------------------------------------------------------------- 5. the fan + finish
	task.wait(0.35)
	title.Text = (opts.Icon or "🎁") .. " " .. string.rep("⭐", best)
	local top = revealed[#revealed]
	if top and top.tier >= 3 then
		local r = rays(root, top.card.Position, top.color, top.card.ZIndex - 1, 8)
		task.delay(30, function() r:Destroy() end)
		loop(top.card, 0.6, {Rotation = top.card.Rotation + 3})
	end
	if opts.Footer then
		local f = label(root, {Text = opts.Footer, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -112), Size = UDim2.new(0.8, 0, 0, 38), ZIndex = 86})
		f.TextStrokeTransparency = 0.2
	end
	skip.Visible = false
	local done = false
	local ok = Instance.new("TextButton")
	ok.Text = "✔ Nice!"
	ok.Font = Enum.Font.FredokaOne
	ok.TextScaled = true
	ok.TextColor3 = WHITE
	ok.TextStrokeTransparency = 0.4
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.new(0.5, 0, 1, -30)
	ok.Size = UDim2.fromOffset(0, 0)
	ok.BackgroundColor3 = Color3.fromRGB(90, 200, 90)
	ok.ZIndex = 96
	corner(ok, UDim.new(0, 18))
	ok.Parent = root
	tween(ok, 0.3, {Size = UDim2.fromOffset(200, 70)}, Enum.EasingStyle.Back)
	ok.Activated:Connect(function() done = true end)
	local t1 = os.clock()
	while not done and os.clock() - t1 < 30 do task.wait() end
	-- cards fly away
	for k, v in revealed do
		tween(v.card, 0.3, {Position = v.card.Position + UDim2.fromOffset(0, 600), Rotation = v.card.Rotation + (k % 2 == 0 and 20 or -20)},
			Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	tween(root, 0.3, {BackgroundTransparency = 1})
	task.wait(0.3)
	root:Destroy()
end

return PackOpen
