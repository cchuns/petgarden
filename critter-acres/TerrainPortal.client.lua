-- Critter Acres: TerrainPortal (StarterPlayerScripts LocalScript)
-- 🌀 The Terrain Portal screen (walk into the portal north of the park, or use its prompt):
--   1 pick a land (each opens at a farm level)   2 who's coming (solo, or invite people in the server)
--   3 bring one buddy pet along (it follows you and zaps mobs), or go alone   then 🌀 Explore!
-- Also: 💌 invite popups, the countdown + "building a new map" cover, the in-map bar (🚪 Leave) and a soft look per land
-- (colour tint + floating snow / embers / fireflies around the camera). Server side: ServerScriptService.Realms.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local K = require(ReplicatedStorage:WaitForChild("UIKit"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))
local actionFn = ReplicatedStorage:WaitForChild("CritterAction")
local remote = ReplicatedStorage:WaitForChild("RealmEvent", 60)
local player = Players.LocalPlayer
local root = workspace:WaitForChild("CritterAcres")

local gui = Instance.new("ScreenGui")
gui.Name = "TerrainPortal"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function act(...) return actionFn:InvokeServer(...) end
local function toast(text, good) K.toast(gui, text, good) end
local function commas(n) return tostring(math.floor(n or 0)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") end
local function done(res, okText)
	if type(res) == "string" then toast(res, res:find("💌") ~= nil) return false end
	if okText then toast(okText) end
	return true
end

local friends = {}
local function isFriend(userId)
	if friends[userId] == nil then
		friends[userId] = false
		task.spawn(function()
			local ok, yes = pcall(player.IsFriendsWith, player, userId)
			friends[userId] = ok and yes or false
		end)
	end
	return friends[userId]
end

---------------------------------------------------------------- the window
local win = K.window(gui, {Icon = "🌀", Title = "Terrain Portal", Max = Vector2.new(900, 600)})
local info -- last RealmInfo from the server
local render
local function refresh()
	info = act("RealmInfo")
	if win.frame.Visible then render() end
end

local function mobText(t)
	local names = {}
	for _, m in t.Mobs or {} do
		table.insert(names, (m.Boss and "👑 " or (m.Special and "✨ " or "")) .. m.Name)
	end
	return #names > 0 and ("Mobs here: " .. table.concat(names, ", ")) or "Mobs to battle, things to gather"
end

local function landCard(parent, t, order, picked, leader)
	local open = t.Open
	local btn, fn
	if picked then
		btn, fn = {Text = "✅ Picked", Kind = "special"}, function() end
	elseif not leader then
		btn, fn = {Text = "👑 Leader picks", Kind = "no"}, function() toast("👑 The party leader picks the land.", false) end
	elseif open then
		btn, fn = {Text = "Pick", Kind = "go"}, function() if done(act("RealmPick", t.Name)) then refresh() end end
	else
		btn, fn = {Text = "🔒 Lv " .. (t.Level or 1), Kind = "no"}, function() toast(("🔒 The %s opens at farm level %d. Keep farming!"):format(t.Name, t.Level or 1), false) end
	end
	local res = {}
	for _, r in t.Res do table.insert(res, (Data.ResByName[r] and Data.ResByName[r].Icon or "") .. r) end
	local card = K.card(parent, {Order = order, Name = t.Icon .. " " .. t.Name, Sub = table.concat(res, " "), Color = t.Color, Button = btn, Fn = fn,
		Art = function(pic)
			pic.BackgroundColor3 = t.Color:Lerp(Color3.new(1, 1, 1), open and 0.45 or 0.8)
			K.text(pic, {Text = open and t.Icon or "🔒", Size = UDim2.fromScale(1, 0.72), Max = 54})
			K.text(pic, {Text = open and ("⚔️ %d mobs"):format(#(t.Mobs or {})) or ("Farm Lv %d"):format(t.Level or 1), Position = UDim2.fromScale(0, 0.7),
				Size = UDim2.fromScale(1, 0.28), TextColor3 = K.SOFT, Max = 14})
		end,
		Tip = t.Icon .. " " .. t.Name, TipText = mobText(t)})
	if picked then
		card.UIStroke.Color, card.UIStroke.Thickness = Color3.fromRGB(230, 170, 50), 5
	end
	return card
end

-- a row with two buttons (Join / No)
local function inviteRow(body, order, inv)
	local def = Data.BiomeByName[inv.Terrain] or {Icon = "🌀"}
	local r = K.row(body, {Order = order, Icon = "💌", Title = ("%s invited you!"):format(inv.Name), Sub = ("Explore the %s %s together"):format(def.Icon, inv.Terrain),
		Button = {Text = "🎉 Join", Kind = "go"}, Fn = function()
			if done(act("PartyAccept", inv.FromId), "🎉 You joined the party!") then refresh() else refresh() end
		end})
	K.button(r, {Text = "No", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -172, 0.5, 0), Size = UDim2.fromOffset(70, 48), Kind = "careful", Max = 18},
		function() act("PartyDecline", inv.FromId) refresh() end)
	return r
end

function render()
	if not info then return end
	win.setTitle("🌀", "Terrain Portal")
	win.setTabs({})
	win.setHelp({{"🗺️", "Pick a wild land. Every trip makes a brand-new map!"}, {"🐾", "Go alone or bring a buddy pet. Invite friends too (up to 4)."},
		{"⚔️", "Battle mobs, gather, beat the boss and find the treasure at the end of the trail."}})
	win.clear()
	local body = win.body
	local party = info.Party
	local me = player.UserId
	local leader = not party or party.Leader == me
	local pick = party and party.Terrain or "Meadow"
	local def = Data.BiomeByName[pick] or Data.Biomes[1]
	local n = party and #party.Members or 1
	win.setSub(n > 1 and ("👫 Party of %d · %s %s"):format(n, def.Icon, pick) or ("🙂 Solo · %s %s"):format(def.Icon, pick))

	local buddyName
	for _, pet in info.Pets or {} do
		if pet.Id == info.Buddy then buddyName = pet.Name or pet.Species end
	end
	-- the go button first, so it's always easy to find
	local goBtn, goFn
	if info.Inside then
		goBtn, goFn = {Text = "🚪 Leave map", Kind = "careful"}, function() act("RealmLeave") win.close() end
	elseif party and party.Running then
		goBtn, goFn = {Text = "🌀 Join them!", Kind = "go"}, function() if done(act("RealmEnter")) then win.close() end end
	elseif leader then
		goBtn, goFn = {Text = "🌀 Explore!", Kind = "go"}, function() if done(act("RealmEnter")) then win.close() end end
	else
		goBtn, goFn = {Text = "⏳ Leader", Kind = "no"}, function() toast("👑 Wait for the party leader to press Explore.", false) end
	end
	K.row(body, {Order = 0, Icon = def.Icon, Title = party and party.Running and ("Your party is in the %s!"):format(party.Running) or ("Explore the %s"):format(pick),
		Sub = (n > 1 and ("👫 %d explorers"):format(n) or "🙂 Just you") .. (buddyName and (" + 🐾 " .. buddyName) or "") .. " · a brand-new map every trip", Button = goBtn, Fn = goFn})

	-- invites waiting for me
	for i, inv in info.Invites or {} do inviteRow(body, i, inv) end

	K.header(body, "1  Pick a land", 10)
	local g = K.grid(body, UDim2.fromOffset(156, 200), 11)
	for i, t in info.Terrains do landCard(g, t, i, t.Name == pick, leader and not (party and party.Running)) end

	K.header(body, ("2  Who's coming?  (%d/%d)"):format(n, info.Max or 4), 20)
	if party and n > 1 then
		for i, m in party.Members do
			local isMe = m.UserId == me
			local btn, fn
			if isMe then
				btn, fn = {Text = "👋 Leave", Kind = "careful"}, function() act("PartyLeave") refresh() end
			elseif leader then
				btn, fn = {Text = "Remove", Kind = "no"}, function() act("PartyKick", m.UserId) refresh() end
			end
			K.row(body, {Order = 20 + i, Icon = m.Leader and "👑" or "🙂", Title = m.Name .. (isMe and " (you)" or ""),
				Sub = m.Inside and "🌀 Exploring now" or (m.Leader and "Leader: picks the land" or "Ready to go"), Button = btn, Fn = fn})
		end
	else
		K.row(body, {Order = 21, Icon = "🙂", Title = "You (solo)", Sub = "Invite people below to make a party"})
	end

	-- 3: one buddy pet (or just you)
	K.header(body, "3  Bring a buddy?", 30, "It follows you and zaps mobs")
	local bg = K.grid(body, UDim2.fromOffset(140, 186), 31)
	local buddy = info.Buddy
	K.card(bg, {Order = 0, Name = "Just me", Sub = "No pet this time", Color = not buddy and Color3.fromRGB(230, 170, 50) or nil,
		Art = function(pic) K.text(pic, {Text = "🙂", Size = UDim2.fromScale(1, 1), Max = 54}) end,
		Button = not buddy and {Text = "✅ Picked", Kind = "special"} or {Text = "Pick", Kind = "go"},
		Fn = function() if buddy then act("RealmBuddy", nil) refresh() end end})
	for i, pet in info.Pets or {} do
		if i > 11 then break end
		local picked = buddy == pet.Id
		local rc = Data.Rarities[pet.Rarity] and Data.Rarities[pet.Rarity].Color
		local btn, fn
		if picked then
			btn, fn = {Text = "✅ Coming", Kind = "special"}, function() act("RealmBuddy", nil) refresh() end
		elseif pet.Tired then
			btn, fn = {Text = "😴 Napping", Kind = "no"}, function() toast("😴 That pet is napping. Pick another buddy!", false) end
		else
			btn, fn = {Text = "🐾 Bring", Kind = "go"}, function() if done(act("RealmBuddy", pet.Id), "🐾 " .. (pet.Name or pet.Species) .. " is coming along!") then refresh() end end
		end
		local card = K.card(bg, {Order = i, Name = pet.Name or pet.Species, Sub = ("%s · Lv %d"):format(pet.Rarity, pet.Level or 1), Color = picked and Color3.fromRGB(230, 170, 50) or rc,
			Art = function(pic)
				local ok = pcall(CritterUI.Portrait, pic, Data, pet.Species, {Size = UDim2.fromScale(1, 1), ZIndex = pic.ZIndex + 1}, {Variant = pet.Variant, Sleepy = pet.Tired})
				if not ok then K.text(pic, {Text = "🐾", Size = UDim2.fromScale(1, 1), Max = 54}) end
			end,
			Button = btn, Fn = fn})
		if picked then card.UIStroke.Thickness = 5 end
	end

	K.header(body, "💌 Invite", 40, "Friends have a ⭐")
	local others = info.Players or {}
	table.sort(others, function(a, b)
		local fa, fb = isFriend(a.UserId), isFriend(b.UserId)
		if fa ~= fb then return fa end
		return a.Name < b.Name
	end)
	local shown = 0
	for i, p in others do
		if not p.InMine then
			shown += 1
			local fr = isFriend(p.UserId)
			local btn, fn
			if not leader then
				btn, fn = {Text = "👑 Leader", Kind = "no"}, function() toast("👑 Only the party leader can invite.", false) end
			elseif n >= (info.Max or 4) then
				btn, fn = {Text = "Party full", Kind = "no"}, function() toast("👫 Your party is full.", false) end
			else
				btn, fn = {Text = "💌 Invite", Kind = "go"}, function() done(act("PartyInvite", p.UserId)) refresh() end
			end
			K.row(body, {Order = 40 + i, Icon = fr and "⭐" or "🙂", Title = p.Name, Sub = p.Busy and "🌀 Exploring right now" or (fr and "Your friend" or "In this server"),
				Button = btn, Fn = fn})
		end
	end
	if shown == 0 then K.empty(body, "👫", "Nobody else to invite here yet. Invite a friend to the game!", nil, nil, 90) end
end

local function openPortal()
	refresh()
	win.open()
	render()
end
win.onClose = function() end

---------------------------------------------------------------- 💌 invite popup (shows anywhere)
local popup
local function showInvite(msg)
	if popup then popup:Destroy() end
	local def = Data.BiomeByName[msg.Terrain] or {Icon = "🌀"}
	local f = K.frame(gui, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 120), Size = UDim2.fromOffset(330, 150), BackgroundColor3 = K.CREAM, ZIndex = 60})
	K.round(f, 18)
	K.stroke(f, Color3.fromRGB(230, 170, 50), 3)
	popup = f
	K.text(f, {Text = "💌", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(50, 50), ZIndex = 61, Max = 40})
	K.text(f, {Text = ("%s invited you!"):format(msg.Name), Position = UDim2.fromOffset(66, 10), Size = UDim2.new(1, -76, 0, 28), ZIndex = 61,
		TextXAlignment = Enum.TextXAlignment.Left, Max = 22})
	K.text(f, {Text = ("Explore the %s %s together"):format(def.Icon, msg.Terrain), Position = UDim2.fromOffset(66, 40), Size = UDim2.new(1, -76, 0, 22), ZIndex = 61,
		TextColor3 = K.SOFT, TextXAlignment = Enum.TextXAlignment.Left, Max = 17})
	local function close() if popup == f then popup = nil end f:Destroy() end
	K.button(f, {Text = "🎉 Join", Position = UDim2.new(0, 12, 1, -62), Size = UDim2.new(0.6, -18, 0, 50), Kind = "go", ZIndex = 61}, function()
		close()
		done(act("PartyAccept", msg.FromId), "🎉 You joined the party! The leader presses Explore.")
		if win.frame.Visible then refresh() end
	end)
	K.button(f, {Text = "No thanks", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 1, -62), Size = UDim2.new(0.4, -12, 0, 50), Kind = "plain", ZIndex = 61}, function()
		close()
		act("PartyDecline", msg.FromId)
	end)
	local bar = K.bar(f, 1, K.YELLOW, {Position = UDim2.new(0, 14, 1, -8), Size = UDim2.new(1, -28, 0, 5), ZIndex = 61})
	local fill = bar:FindFirstChildWhichIsA("Frame")
	if fill then fill.ZIndex = 62 TweenService:Create(fill, TweenInfo.new(msg.Secs or 45, Enum.EasingStyle.Linear), {Size = UDim2.fromScale(0, 1)}):Play() end
	task.delay(msg.Secs or 45, close)
end

---------------------------------------------------------------- countdown + building cover
local cover
local function countdown(msg)
	win.close()
	if cover then cover:Destroy() end
	local def = Data.BiomeByName[msg.Terrain] or {Icon = "🌀", Color = Color3.fromRGB(150, 110, 255)}
	local f = K.frame(gui, {Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, -60), BackgroundColor3 = def.Color:Lerp(Color3.fromRGB(40, 25, 70), 0.55),
		BackgroundTransparency = 1, ZIndex = 150})
	f.Size = UDim2.new(1, 0, 1, 120)
	cover = f
	local big = K.text(f, {Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.8, 0.12), TextColor3 = K.WHITE,
		ZIndex = 151, Max = 60})
	local small = K.text(f, {Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0.8, 0.06), TextColor3 = K.WHITE,
		ZIndex = 151, Max = 28})
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Color = 3, Color3.fromRGB(60, 30, 90)
	stroke.Parent = big
	TweenService:Create(f, TweenInfo.new(0.4), {BackgroundTransparency = 0.6}):Play()
	for s = msg.In or 4, 1, -1 do
		if cover ~= f then return end
		big.Text = ("%s Off to the %s in %d..."):format(def.Icon, msg.Terrain, s)
		small.Text = "🌀 Get ready, explorers!"
		task.wait(1)
	end
	TweenService:Create(f, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
	big.Text = "✨ Making a brand-new map..."
	small.Text = "Every trip is different!"
	local t = os.clock()
	while cover == f and not player:GetAttribute("Realm") and os.clock() - t < 45 do task.wait(0.1) end
	task.wait(0.5)
	if cover ~= f then return end
	TweenService:Create(f, TweenInfo.new(0.8), {BackgroundTransparency = 1}):Play()
	big.Text, small.Text = "", ""
	task.delay(0.85, function() if cover == f then cover = nil end f:Destroy() end)
end

remote.OnClientEvent:Connect(function(msg)
	if msg.Kind == "Party" then
		if info then info.Party = msg.Party end
		if win.frame.Visible then refresh() end
	elseif msg.Kind == "Invite" then
		showInvite(msg)
		if win.frame.Visible then refresh() end
	elseif msg.Kind == "Go" then
		task.spawn(countdown, msg)
	end
end)

---------------------------------------------------------------- walk into the portal (or use its prompt)
task.spawn(function()
	local tp = root:WaitForChild("TerrainPortal", 60)
	if not tp then return end
	local gate = tp:WaitForChild("Gate", 30)
	if not gate then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "🌀 Explore"
	prompt.ObjectText = "Terrain Portal"
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = gate
	prompt.Triggered:Connect(openPortal)
	local armed = true
	gate.Touched:Connect(function(hit)
		local char = player.Character
		if armed and char and hit:IsDescendantOf(char) then
			armed = false
			openPortal()
		end
	end)
	while true do
		task.wait(0.3)
		if not armed then
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not hrp or (hrp.Position - gate.Position).Magnitude > 16 then armed = true end
		end
	end
end)

---------------------------------------------------------------- in-map bar + the look of each land
local barF = K.frame(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(440, 56), BackgroundColor3 = K.CREAM,
	Visible = false, ZIndex = 30})
K.round(barF, 16)
local barStroke = K.stroke(barF, K.LINE, 3)
local barText = K.text(barF, {Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -150, 0, 28), ZIndex = 31, TextXAlignment = Enum.TextXAlignment.Left, Max = 22})
local barSub = K.text(barF, {Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -150, 0, 20), ZIndex = 31, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = K.SOFT, Max = 16, Text = "🎁 Find the treasure at the end of the trail!"})
K.button(barF, {Text = "🚪 Leave", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(124, 44), Kind = "careful", ZIndex = 31,
	Tip = "Leave", TipText = "Go back to town. You can also walk into the portal where you arrived."}, function()
	act("RealmLeave")
end)

local LOOK = {
	Meadow = {Tint = Color3.fromRGB(255, 252, 235), Bright = 0.02, Sat = 0.12, Fx = "Pollen"},
	Forest = {Tint = Color3.fromRGB(225, 255, 225), Bright = -0.04, Sat = 0.1, Fx = "Fireflies"},
	Peaks = {Tint = Color3.fromRGB(225, 240, 255), Bright = 0.04, Sat = -0.05, Fx = "Snow"},
	Caves = {Tint = Color3.fromRGB(205, 195, 255), Bright = -0.14, Sat = 0.15, Contrast = 0.12, Fx = "Motes"},
	Volcano = {Tint = Color3.fromRGB(255, 220, 195), Bright = -0.03, Sat = 0.1, Contrast = 0.08, Fx = "Embers"},
}
local FX = {
	Pollen = {Color = Color3.fromRGB(255, 245, 170), Size = 0.25, Rate = 20, Speed = 1, Drop = -0.2, Light = 0.6, Life = 6},
	Fireflies = {Color = Color3.fromRGB(220, 255, 120), Size = 0.3, Rate = 14, Speed = 1.5, Drop = 0, Light = 1, Life = 5},
	Snow = {Color = Color3.fromRGB(255, 255, 255), Size = 0.35, Rate = 70, Speed = 2, Drop = -6, Light = 0.3, Life = 7},
	Motes = {Color = Color3.fromRGB(190, 150, 255), Size = 0.25, Rate = 22, Speed = 0.8, Drop = 0.3, Light = 1, Life = 6},
	Embers = {Color = Color3.fromRGB(255, 140, 50), Size = 0.3, Rate = 35, Speed = 2, Drop = 4, Light = 1, Life = 4},
}
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "RealmLook"
cc.Enabled = false
local fxPart = Instance.new("Part")
fxPart.Name = "RealmFx"
fxPart.Anchored, fxPart.CanCollide, fxPart.CanQuery, fxPart.CanTouch, fxPart.Transparency = true, false, false, false, 1
fxPart.Size = Vector3.new(70, 1, 70)
local fx = Instance.new("ParticleEmitter")
fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
fx.Enabled = false
fx.SpreadAngle = Vector2.new(180, 180)
fx.Shape = Enum.ParticleEmitterShape.Box
fx.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
fx.Parent = fxPart

local function applyLook()
	local land = player:GetAttribute("Realm")
	local def = land and Data.BiomeByName[land]
	barF.Visible = def ~= nil
	local cam = workspace.CurrentCamera
	cc.Parent = cam
	if not def then
		cc.Enabled = false
		fx.Enabled = false
		fxPart.Parent = nil
		return
	end
	barText.Text = ("%s %s  ·  Map #%s"):format(def.Icon, land, tostring(player:GetAttribute("RealmSeed") or "?"))
	barStroke.Color = def.Color
	local L = LOOK[land] or LOOK.Meadow
	cc.Enabled = true
	cc.TintColor, cc.Brightness, cc.Saturation, cc.Contrast = L.Tint, L.Bright or 0, L.Sat or 0, L.Contrast or 0
	local f = FX[L.Fx]
	fx.Color = ColorSequence.new(f.Color)
	fx.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.15, f.Size), NumberSequenceKeypoint.new(0.85, f.Size), NumberSequenceKeypoint.new(1, 0)})
	fx.Rate = f.Rate
	fx.Speed = NumberRange.new(f.Speed * 0.5, f.Speed)
	fx.Acceleration = Vector3.new(0, f.Drop, 0)
	fx.LightEmission = f.Light
	fx.Lifetime = NumberRange.new(f.Life * 0.7, f.Life)
	fx.Enabled = true
	fxPart.Parent = cam
end
player:GetAttributeChangedSignal("Realm"):Connect(applyLook)
player:GetAttributeChangedSignal("RealmSeed"):Connect(applyLook)
applyLook()
RunService.RenderStepped:Connect(function()
	if fx.Enabled then
		local cam = workspace.CurrentCamera
		fxPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 14, 0))
	end
end)

print("[TerrainPortal] ready")
