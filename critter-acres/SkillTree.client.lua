-- Critter Acres: SkillTree (StarterPlayerScripts LocalScript)
-- 🌳 The skill tree window (key K, or the 🌳 Skills dock button through CritterUIBridge "Skills"):
--   three branches side by side (🗡️ Melee, 🏹 Range, 🔮 Mage), cards joined by lines. Click a card to see what it does
--   now and at the next level, then Learn / Upgrade (1 point). Free reset. Server: ServerScriptService.Skills.
-- ⚡ Skill bars: one per branch (🗡️ Melee / 🏹 Range / 🔮 Mage), 5 slots each. A new move goes in the first empty slot.
--   To move one: tap its card, then a slot number 1-5 in the info panel (✖ takes it out). The window shows the bar of
--   the picked card's branch.
-- ⚡ Hotbar (wild lands only, above the dock): the bar of the weapon in your hand (sword = Melee moves), keys 1-5,
--   a cooldown shade per move. Moves that land on a circle go where you aim (mouse / screen middle).
-- Draws everyone's skill moves (SkillFx) and 💫 / 🧊 over stunned mobs (mob attribute Stun).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local K = require(ReplicatedStorage:WaitForChild("UIKit"))
local actionFn = ReplicatedStorage:WaitForChild("CritterAction")
local remote = ReplicatedStorage:WaitForChild("Combat", 60)
local bridge = ReplicatedStorage:WaitForChild("CritterUIBridge")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local gui = Instance.new("ScreenGui")
gui.Name = "SkillTree"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 7
gui.Parent = player:WaitForChild("PlayerGui")

local function act(...) return actionFn:InvokeServer(...) end
local function toast(text, good) K.toast(gui, text, good) end
local function inRealm() return player:GetAttribute("Realm") ~= nil end
local function tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local DARK = Color3.fromRGB(60, 45, 35)

---------------------------------------------------------------- 🌳 the window
local win = K.window(gui, {Icon = "🌳", Title = "Skill tree", Max = Vector2.new(940, 640)})
local info -- {Skills, Lv, Points, Max}
local sel = "BigBonk"
local render

local function rankOf(id) return info and info.Skills[id] or 0 end
-- "ok" (can learn / upgrade), "max", "lvl" (Hero Level too low), "req" (learn the one above first)
local function stateOf(id)
	local s = Data.Skills[id]
	if rankOf(id) >= s.Max then return "max" end
	if (info and info.Lv or 1) < s.Lv then return "lvl" end
	if s.Req and rankOf(s.Req) < 1 then return "req" end
	return "ok"
end

local CARD_W, CARD_H, ROW_H, TOP = 0.42, 74, 92, 46
local function colX(col) return col == 1 and 0.05 or (col == 2 and 0.53 or 0.29) end
local function line(parent, x1, y1, x2, y2, color)
	-- an L-shaped joint: down, across, down (x in column scale, y in pixels)
	local my = math.floor((y1 + y2) / 2)
	K.frame(parent, {Position = UDim2.new(x1, -2, 0, y1), Size = UDim2.new(0, 4, 0, my - y1 + 2), BackgroundColor3 = color})
	local lo, hi = math.min(x1, x2), math.max(x1, x2)
	K.frame(parent, {Position = UDim2.new(lo, -2, 0, my - 2), Size = UDim2.new(hi - lo, 4, 0, 4), BackgroundColor3 = color})
	K.frame(parent, {Position = UDim2.new(x2, -2, 0, my), Size = UDim2.new(0, 4, 0, y2 - my), BackgroundColor3 = color})
end

---------------------------------------------------------------- ⚡ the skill bars (one per branch)
local function branchOf(name)
	for _, br in Data.SkillBranches do
		if br.Name == name then return br end
	end
end
local function barFor(branch) return info and info.Bars and info.Bars[branch] or {} end
local function slotOf(id) return table.find(barFor(Data.Skills[id].Branch), id) end
-- put a move in slot 1-5 of its bar (0 = take it out)
local function setSlot(id, slot)
	local res = act("SkillSlot", id, slot)
	if type(res) == "string" then toast(res, false) return end
	if type(res) == "table" then
		info = res
		local s = Data.Skills[id]
		toast(slot == 0 and ("%s %s is out of the bar"):format(s.Icon, s.Name) or ("%s %s is in slot %d"):format(s.Icon, s.Name, slot), true)
		render()
	end
end

local function skillBar(parent)
	local br = branchOf(Data.Skills[sel].Branch)
	local bar = barFor(br.Name)
	local wrap = K.frame(parent, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(Data.SkillSlots * 70 + 130, 76),
		BackgroundColor3 = br.Color:Lerp(K.WHITE, 0.7)})
	K.round(wrap, 16)
	K.stroke(wrap, br.Color, 2)
	K.text(wrap, {Text = ("%s %s bar"):format(br.Icon, br.Name), Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(114, 30), Max = 18})
	K.text(wrap, {Text = "keys 1-5", Position = UDim2.fromOffset(8, 38), Size = UDim2.fromOffset(114, 24), Max = 15, TextColor3 = K.SOFT})
	for i = 1, Data.SkillSlots do
		local id = bar[i] or ""
		local s = Data.Skills[id]
		local slot = K.button(wrap, {Text = "", Position = UDim2.fromOffset(126 + (i - 1) * 70, 6), Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = s and K.CARD or Color3.fromRGB(245, 238, 225), Tip = s and (s.Icon .. " " .. s.Name) or ("⚡ Slot " .. i),
			TipText = s and "Tap to pick it, then use the slot numbers below to move it." or ("Pick a ⚡ %s move, then press %d below."):format(br.Name, i)}, function()
			if s then
				sel = id
				render()
			else
				toast(("⚡ Tap a %s ⚡ move card, then press %d in the box below."):format(br.Name, i), false)
			end
		end)
		slot.UIPadding:Destroy()
		if s and sel == id then slot.UIStroke.Color, slot.UIStroke.Thickness = Color3.fromRGB(255, 190, 40), 4 end
		K.text(slot, {Text = s and s.Icon or "", Size = UDim2.fromScale(1, 1), Max = 38})
		local num = K.text(slot, {Text = tostring(i), Position = UDim2.fromOffset(-6, -6), Size = UDim2.fromOffset(22, 22), Max = 15, BackgroundTransparency = 0,
			BackgroundColor3 = K.BROWN, TextColor3 = K.WHITE, ZIndex = slot.ZIndex + 2})
		K.round(num, 11)
	end
	return wrap
end

-- ✨ learn / upgrade a skill by 1 point (the detail button, or double-click a card)
local lastClick = {id = nil, t = 0}
local function learn(id)
	local s = Data.Skills[id]
	local st = stateOf(id)
	sel = id
	if st ~= "ok" or info.Points <= 0 then
		toast(st == "lvl" and ("🔒 %s opens at ⚔️ Hero Lv %d. Beat mobs to level up!"):format(s.Name, s.Lv)
			or st == "req" and ("🔒 Learn %s first."):format(Data.Skills[s.Req].Name)
			or st == "max" and ("⭐ %s is maxed!"):format(s.Name) or "🌳 No skill points left. Beat mobs to level up!", false)
		render()
		return
	end
	local res = act("SkillLearn", id)
	if type(res) == "string" then toast(res, false) render() return end
	info = res
	toast(("%s %s is now level %d!"):format(s.Icon, s.Name, rankOf(id)), true)
	render()
end

local function branchColumn(parent, b, i)
	local col = K.frame(parent, {Position = UDim2.new((i - 1) / 3, 4, 0, 0), Size = UDim2.new(1 / 3, -8, 1, 0), BackgroundColor3 = b.Color:Lerp(Color3.new(1, 1, 1), 0.72)})
	K.round(col, 16)
	K.stroke(col, b.Color, 2)
	local pts = 0
	for _, id in b.Order do pts += rankOf(id) end
	K.text(col, {Text = ("%s %s   %d pts"):format(b.Icon, b.Name, pts), Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 30), Max = 22,
		TextColor3 = DARK})
	-- joints first (under the cards)
	for _, id in b.Order do
		local s = Data.Skills[id]
		if s.Req then
			local p = Data.Skills[s.Req]
			local on = rankOf(s.Req) > 0
			line(col, colX(p.Col) + CARD_W / 2, TOP + (p.Row - 1) * ROW_H + CARD_H, colX(s.Col) + CARD_W / 2, TOP + (s.Row - 1) * ROW_H,
				on and b.Color:Lerp(Color3.new(0, 0, 0), 0.15) or Color3.fromRGB(200, 190, 175))
		end
	end
	for _, id in b.Order do
		local s = Data.Skills[id]
		local r, st = rankOf(id), stateOf(id)
		local locked = r == 0 and (st == "lvl" or st == "req")
		local card = K.button(col, {Text = "", Position = UDim2.new(colX(s.Col), 0, 0, TOP + (s.Row - 1) * ROW_H), Size = UDim2.new(CARD_W, 0, 0, CARD_H),
			BackgroundColor3 = r > 0 and b.Color or (locked and Color3.fromRGB(235, 230, 222) or K.CARD),
			Tip = s.Icon .. " " .. s.Name, TipText = s.Say(math.max(1, r)) .. "\n(double-click = learn / upgrade)"}, function()
			-- one click picks the card, a quick second click learns / upgrades it
			local now = os.clock()
			if lastClick.id == id and now - lastClick.t < 0.4 then
				lastClick.id = nil
				learn(id)
			else
				lastClick.id, lastClick.t = id, now
				sel = id
				render()
			end
		end)
		card.UIPadding:Destroy()
		if r == 0 and st == "ok" then card.UIStroke.Color, card.UIStroke.Thickness = b.Color:Lerp(Color3.new(0, 0, 0), 0.2), 3 end
		if sel == id then card.UIStroke.Color, card.UIStroke.Thickness = Color3.fromRGB(255, 190, 40), 4 end
		K.text(card, {Text = locked and "🔒" or s.Icon, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 30), Max = 28,
			TextTransparency = locked and 0.3 or 0})
		K.text(card, {Text = s.Name, Position = UDim2.fromOffset(4, 34), Size = UDim2.new(1, -8, 0, 18), Max = 15, TextColor3 = DARK})
		K.text(card, {Text = st == "lvl" and r == 0 and ("Lv " .. s.Lv) or (("%d/%d"):format(r, s.Max) .. (s.Kind == "Active" and "  ⚡" or "")),
			Position = UDim2.fromOffset(4, 53), Size = UDim2.new(1, -8, 0, 16), Max = 14, TextColor3 = r > 0 and DARK or K.SOFT})
		if r == 0 and st == "ok" and info.Points > 0 then K.badge(card, true) end
	end
	return col
end

local function detail(parent)
	local s = Data.Skills[sel]
	local b
	for _, bb in Data.SkillBranches do if bb.Name == s.Branch then b = bb end end
	local r, st = rankOf(sel), stateOf(sel)
	local active = s.Kind == "Active" and r > 0
	local box = K.frame(parent, {Size = UDim2.new(1, -8, 0, active and 164 or 120), LayoutOrder = 3})
	K.round(box, 16)
	K.stroke(box, b.Color, 2)
	local ic = K.text(box, {Text = s.Icon, Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(84, 84), Max = 56, BackgroundTransparency = 0,
		BackgroundColor3 = b.Color:Lerp(Color3.new(1, 1, 1), 0.6)})
	K.round(ic, 16)
	K.text(box, {Text = ("%s   level %d/%d"):format(s.Name, r, s.Max), Position = UDim2.fromOffset(108, 8), Size = UDim2.new(1, -330, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left, Max = 24})
	local req = ("Needs ⚔️ Hero Lv %d"):format(s.Lv) .. (s.Req and (" + " .. Data.Skills[s.Req].Name) or "")
	K.text(box, {Text = "Now: " .. (r > 0 and s.Say(r) or "not learned yet"), Position = UDim2.fromOffset(108, 40), Size = UDim2.new(1, -330, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left, Max = 17, TextColor3 = K.SOFT})
	K.text(box, {Text = r < s.Max and ("Next: " .. s.Say(r + 1)) or "⭐ Maxed out!", Position = UDim2.fromOffset(108, 64), Size = UDim2.new(1, -330, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left, Max = 17})
	K.text(box, {Text = req, Position = UDim2.fromOffset(108, 88), Size = UDim2.new(1, -330, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Max = 15,
		TextColor3 = (st == "lvl" or st == "req") and Color3.fromRGB(220, 80, 70) or K.SOFT})
	local can = st == "ok" and info.Points > 0
	local word = st == "max" and "⭐ Maxed" or (st == "lvl" and ("🔒 Lv " .. s.Lv)) or (st == "req" and "🔒 Learn above")
		or (info.Points <= 0 and "No points") or (r == 0 and "✨ Learn  ·  1 pt" or "⬆️ Upgrade  ·  1 pt")
	K.button(box, {Text = word, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(200, 64), Max = 22,
		Kind = can and "go" or "no"}, function() learn(sel) end)
	-- ⚡ which slot of its bar this move sits in
	if active then
		local at = slotOf(sel)
		local id = sel
		K.text(box, {Text = "⚡ In slot:", Position = UDim2.fromOffset(108, 118), Size = UDim2.fromOffset(110, 36), TextXAlignment = Enum.TextXAlignment.Left, Max = 18})
		for i = 1, Data.SkillSlots do
			local here = at == i
			K.button(box, {Text = tostring(i), Position = UDim2.fromOffset(220 + (i - 1) * 52, 116), Size = UDim2.fromOffset(44, 40), Max = 20,
				Kind = here and "special" or "plain", Tip = ("Slot %d"):format(i), TipText = here and "It's here now." or ("Put %s in slot %d (key %d)."):format(s.Name, i, i)},
				function() if not here then setSlot(id, i) end end)
		end
		K.button(box, {Text = "✖", Position = UDim2.fromOffset(220 + Data.SkillSlots * 52 + 8, 116), Size = UDim2.fromOffset(44, 40), Max = 18,
			Kind = at and "careful" or "no", Tip = "Take it out", TipText = "Take this move out of the bar."}, function()
			if at then setSlot(id, 0) else toast("It's not in the bar.", false) end
		end)
	end
end

function render()
	if not info then return end
	win.clear()
	local body = win.body
	win.setSub(("⚔️ Hero Lv %d / %d   ·   1 skill point per level   ·   double-click a card to upgrade"):format(info.Lv, info.Max or Data.HeroMax))
	-- top row: points + reset
	local top = K.frame(body, {Size = UDim2.new(1, -8, 0, 80), BackgroundTransparency = 1, LayoutOrder = 1})
	local pts = K.text(top, {Text = ("🌳 %d point%s"):format(info.Points, info.Points == 1 and "" or "s"), Position = UDim2.fromOffset(0, 14), Size = UDim2.new(0, 150, 0, 52),
		BackgroundTransparency = 0, BackgroundColor3 = info.Points > 0 and K.YELLOW or K.CARD, Max = 22})
	K.round(pts, 14)
	skillBar(top)
	K.button(top, {Text = "♻️ Free reset", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 14), Size = UDim2.fromOffset(150, 52), Kind = "careful", Max = 20,
		Tip = "♻️ Free reset", TipText = "Get all your points back to try another build. It's free!"}, function()
		local res = act("SkillReset")
		if type(res) == "table" then info = res toast("♻️ All points back. Try a new build!", true) render() end
	end)
	-- the tree
	local tree = K.frame(body, {Size = UDim2.new(1, -8, 0, TOP + 4 * ROW_H - 4), BackgroundTransparency = 1, LayoutOrder = 2})
	for i, b in Data.SkillBranches do branchColumn(tree, b, i) end
	detail(body)
end

local function openTree()
	info = act("SkillInfo")
	if type(info) ~= "table" then return end
	-- show the card that matches your weapon's branch first
	win.open()
	render()
end
bridge.Event:Connect(function(cmd)
	if cmd == "Skills" then openTree() end
end)
player:GetAttributeChangedSignal("SkillPts"):Connect(function()
	if win.frame.Visible then
		local res = act("SkillInfo")
		if type(res) == "table" then info = res render() end
	end
end)

---------------------------------------------------------------- ⚡ hotbar: 5 slots, keys 1-5 (wild lands only)
-- the branch of the weapon in your hand (sword = Melee, bow = Range, wand = Mage)
local function weaponBranch()
	local c = player.Character
	for _, holder in {c, player:FindFirstChildOfClass("Backpack")} do
		for _, t in holder and holder:GetChildren() or {} do
			if t:IsA("Tool") and t:GetAttribute("Weapon") then return Data.BranchOfStyle(t:GetAttribute("Style") or "Melee") end
		end
	end
	return "Melee"
end
local function barNow()
	local list = string.split(player:GetAttribute("SkillBar_" .. weaponBranch()) or "", ",")
	local out = {}
	for i = 1, Data.SkillSlots do out[i] = list[i] or "" end
	return out
end
local hot = K.frame(gui, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -82), Size = UDim2.fromOffset(Data.SkillSlots * 78 - 10, 70),
	BackgroundTransparency = 1, Visible = false})
local hotLabel = K.text(hot, {Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.fromOffset(220, 24), Max = 18,
	TextColor3 = K.WHITE, TextStrokeTransparency = 0.3})
local slots = {}
for i = 1, Data.SkillSlots do
	local b = K.button(hot, {Text = "", Position = UDim2.fromOffset((i - 1) * 78, 0), Size = UDim2.fromOffset(68, 68), Kind = "special"}, function() end)
	b.UIPadding:Destroy()
	K.round(b, 18)
	local icon = K.text(b, {Text = "", Size = UDim2.fromScale(1, 1), Max = 38})
	local key = K.text(b, {Text = tostring(i), Position = UDim2.fromOffset(-6, -6), Size = UDim2.fromOffset(24, 24), Max = 16, BackgroundTransparency = 0,
		BackgroundColor3 = K.BROWN, TextColor3 = K.WHITE, ZIndex = b.ZIndex + 3})
	K.round(key, 12)
	local shade = K.frame(b, {Size = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45, ZIndex = b.ZIndex + 1})
	K.round(shade, 18)
	local count = K.text(b, {Text = "", Size = UDim2.fromScale(1, 1), Max = 30, TextColor3 = K.WHITE, TextStrokeTransparency = 0.2, ZIndex = b.ZIndex + 2})
	slots[i] = {b = b, icon = icon, shade = shade, count = count}
end

-- where to drop a circle move: under the mouse (or the screen middle with mouse look), else 14 studs ahead
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Include
aimParams.FilterDescendantsInstances = {workspace.Terrain}
local function aimPoint()
	if not UserInputService.MouseEnabled then return nil end
	local mp = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter and (camera.ViewportSize / 2) or UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mp.X, mp.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, aimParams)
	return hit and hit.Position or nil
end

local function use(slot)
	if not inRealm() then return end
	local id = barNow()[slot]
	local s = Data.Skills[id]
	if not s then
		toast(("⚡ Slot %d of your %s bar is empty. Open the 🌳 skill tree (K) to fill it."):format(slot, weaponBranch()), false)
		return
	end
	local cd = (player:GetAttribute("Cd_" .. id) or 0) - workspace:GetServerTimeNow()
	if cd > 0 then return end
	remote:FireServer("Skill", slot, aimPoint())
	local sc = slots[slot].b:FindFirstChildOfClass("UIScale")
	if sc then sc.Scale = 0.85 tween(sc, 0.25, {Scale = 1}, Enum.EasingStyle.Back) end
end
for i, sl in slots do
	sl.b.Activated:Connect(function()
		if barNow()[i] == "" then openTree() else use(i) end
	end)
end

RunService.Heartbeat:Connect(function()
	local on = inRealm()
	hot.Visible = on
	if not on then return end
	local bar = barNow()
	local br = branchOf(weaponBranch())
	local lt = br and ("%s %s moves"):format(br.Icon, br.Name) or ""
	if hotLabel.Text ~= lt then hotLabel.Text = lt end
	for i, sl in slots do
		local s = Data.Skills[bar[i]]
		local txt = s and s.Icon or ""
		if sl.icon.Text ~= txt then sl.icon.Text = txt end
		sl.b.BackgroundColor3 = s and K.YELLOW or Color3.fromRGB(245, 238, 225)
		sl.b.BackgroundTransparency = s and 0 or 0.35
		local left = s and ((player:GetAttribute("Cd_" .. bar[i]) or 0) - workspace:GetServerTimeNow()) or 0
		if left > 0 then
			sl.shade.Size = UDim2.fromScale(1, math.clamp(left / s.Cd, 0, 1))
			sl.count.Text = tostring(math.ceil(left))
		else
			sl.shade.Size = UDim2.fromScale(1, 0)
			sl.count.Text = ""
		end
	end
end)

local KEYS = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five}
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.K then
		if win.frame.Visible then win.close() else openTree() end
	elseif inRealm() and not player:GetAttribute("Decorating") then -- (decorate mode uses 1-9)
		local n = table.find(KEYS, input.KeyCode)
		if n and n <= Data.SkillSlots then use(n) end
	end
end)

---------------------------------------------------------------- ✨ skill effects (everyone in the map sees them)
local folder = Instance.new("Folder")
folder.Name = "SkillFxLocal"
folder.Parent = workspace
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	for k, v in props do p[k] = v end
	p.Parent = folder
	return p
end
local function disc(pos, r, color, transp)
	return part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, r * 2, r * 2), Color = color, Material = Enum.Material.Neon,
		Transparency = transp, CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)})
end
local function ring(pos, r, color, secs)
	local d = disc(pos + Vector3.new(0, 0.25, 0), 1, color, 0.25)
	tween(d, secs or 0.45, {Size = Vector3.new(0.15, r * 2, r * 2), Transparency = 1})
	Debris:AddItem(d, (secs or 0.45) + 0.05)
end
local function burst(pos, color, n, size, tex, speed)
	local holder = part({Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(pos)})
	local e = Instance.new("ParticleEmitter")
	e.Texture = tex or SPARK
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.7
	e.Size = NumberSequence.new(size or 1, 0)
	e.Speed = NumberRange.new((speed or 14) * 0.5, speed or 14)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Drag = 2
	e.Rate = 0
	e.Parent = holder
	e:Emit(n or 24)
	Debris:AddItem(holder, 1)
end
local function shakeNear(pos, range)
	local c = player.Character
	local h = c and c:FindFirstChild("HumanoidRootPart")
	if not h or (h.Position - pos).Magnitude > range then return end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = os.clock() - t0
		if k > 0.3 then conn:Disconnect() return end
		local a = 0.6 * (1 - k / 0.3)
		camera.CFrame += Vector3.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
	end)
end
-- a friendly (blue / purple) circle that fills up where your move will land
local function aimCircle(pos, r, color, secs)
	local edge = disc(pos + Vector3.new(0, 0.15, 0), r, color, 0.6)
	local fill = disc(pos + Vector3.new(0, 0.18, 0), 0.2, color, 0.4)
	tween(fill, secs, {Size = Vector3.new(0.15, r * 2, r * 2)}, Enum.EasingStyle.Linear)
	Debris:AddItem(edge, secs)
	Debris:AddItem(fill, secs)
end
local function charOf(userId)
	local p = Players:GetPlayerByUserId(userId or 0)
	return p and p.Character
end

local FX = {}
function FX.SpinSwing(msg)
	ring(msg.Pos - Vector3.new(0, 2.5, 0), msg.R or 10, Color3.fromRGB(255, 240, 200), 0.3)
end
function FX.GroundPound(msg)
	local c = charOf(msg.By)
	local h = c and c:FindFirstChild("HumanoidRootPart")
	if h then -- a little hop before the stomp
		burst(h.Position, Color3.fromRGB(255, 220, 150), 10, 0.8)
	end
	task.delay(0.45, function()
		ring(msg.Pos, msg.R, Color3.fromRGB(240, 170, 90), 0.5)
		ring(msg.Pos, msg.R * 0.7, Color3.fromRGB(255, 220, 160), 0.35)
		burst(msg.Pos + Vector3.new(0, 1, 0), Color3.fromRGB(200, 170, 130), 26, 2.2, SMOKE, 10)
		shakeNear(msg.Pos, msg.R + 20)
	end)
end
function FX.ArrowRain(msg)
	local color = Color3.fromRGB(90, 210, 170)
	aimCircle(msg.Pos, msg.R, color, msg.Delay)
	for i = 1, 14 do
		task.delay(msg.Delay * (i / 16), function()
			local a, d = math.random() * math.pi * 2, math.random() * msg.R
			local land = msg.Pos + Vector3.new(math.cos(a) * d, 0.5, math.sin(a) * d)
			local from = land + Vector3.new(3, 26, 2)
			local arrow = part({Size = Vector3.new(0.3, 0.3, 2.2), Color = color, Material = Enum.Material.Neon, CFrame = CFrame.lookAt(from, land)})
			local left = msg.Delay * (1 - i / 16) + 0.05
			tween(arrow, left, {CFrame = CFrame.lookAt(land, land + (land - from).Unit)}, Enum.EasingStyle.Linear)
			Debris:AddItem(arrow, left + 0.3)
		end)
	end
	task.delay(msg.Delay, function()
		burst(msg.Pos + Vector3.new(0, 1, 0), color, 30, 1.2)
		ring(msg.Pos, msg.R, color, 0.35)
	end)
end
function FX.MiniMeteor(msg)
	local color = Color3.fromRGB(170, 140, 255)
	aimCircle(msg.Pos, msg.R, color, msg.Delay)
	local from = msg.Pos + Vector3.new(12, 70, 8)
	local rock = part({Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Color = color, Material = Enum.Material.Neon, CFrame = CFrame.new(from)})
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 18, 2
	light.Parent = rock
	tween(rock, msg.Delay, {CFrame = CFrame.new(msg.Pos + Vector3.new(0, 1.5, 0))}, Enum.EasingStyle.Quad)
	Debris:AddItem(rock, msg.Delay)
	task.delay(msg.Delay, function()
		burst(msg.Pos + Vector3.new(0, 1.5, 0), color, 40, 2)
		burst(msg.Pos + Vector3.new(0, 1, 0), Color3.fromRGB(220, 210, 255), 16, 2.6, SMOKE, 9)
		ring(msg.Pos, msg.R * 1.1, color, 0.5)
		shakeNear(msg.Pos, msg.R + 25)
	end)
end
function FX.FreezeRing(msg)
	local color = Color3.fromRGB(170, 225, 255)
	ring(msg.Pos, msg.R, color, 0.6)
	burst(msg.Pos + Vector3.new(0, 2, 0), color, 40, 1.4, SPARK, 22)
	local frost = disc(msg.Pos + Vector3.new(0, 0.12, 0), msg.R, color, 0.55)
	frost.Material = Enum.Material.Ice
	tween(frost, msg.Secs or 2, {Transparency = 1}, Enum.EasingStyle.Linear)
	Debris:AddItem(frost, (msg.Secs or 2) + 0.1)
end
function FX.GiantMode(msg)
	local c = charOf(msg.By)
	local h = c and c:FindFirstChild("HumanoidRootPart")
	if h then
		burst(h.Position, Color3.fromRGB(255, 200, 120), 40, 2, SMOKE, 12)
		burst(h.Position + Vector3.new(0, 3, 0), Color3.fromRGB(255, 240, 160), 30, 1)
	end
	if msg.By == player.UserId then toast(("🦖 Giant Mode for %ds!"):format(msg.Secs or 6), true) end
end
function FX.RapidFire(msg)
	local c = charOf(msg.By)
	local h = c and c:FindFirstChild("HumanoidRootPart")
	if h then
		local holder = Instance.new("Attachment")
		holder.Parent = h
		local e = Instance.new("ParticleEmitter")
		e.Texture = SPARK
		e.Color = ColorSequence.new(Color3.fromRGB(120, 230, 190))
		e.Size = NumberSequence.new(0.6, 0)
		e.Speed = NumberRange.new(2, 5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Lifetime = NumberRange.new(0.4, 0.7)
		e.LightEmission = 1
		e.Rate = 25
		e.Parent = holder
		Debris:AddItem(holder, msg.Secs or 6)
	end
	if msg.By == player.UserId then toast(("⚡ Rapid Fire for %ds!"):format(msg.Secs or 6), true) end
end

remote.OnClientEvent:Connect(function(msg)
	if msg.Kind == "SkillFx" and FX[msg.Skill] then
		local ok, err = pcall(FX[msg.Skill], msg)
		if not ok then warn("[SkillTree] fx", msg.Skill, err) end
	end
end)

---------------------------------------------------------------- 💫 / 🧊 over stunned mobs
local stunTags = {}
task.spawn(function()
	while true do
		task.wait(0.15)
		for _, m in CollectionService:GetTagged("MobRig") do
			local look = m.Parent and m.PrimaryPart and m:GetAttribute("Stun")
			local t = stunTags[m]
			if look and not t then
				local _, size = m:GetBoundingBox()
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromOffset(110, 40)
				bb.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.5 + 1.5, 0)
				bb.AlwaysOnTop = true
				bb.LightInfluence = 0
				bb.MaxDistance = 120
				bb.Adornee = m.PrimaryPart
				bb.Parent = gui
				local label = K.text(bb, {Text = look == "Ice" and "🧊 Frozen" or "💫 Dizzy", Size = UDim2.fromScale(1, 1), Max = 24,
					TextColor3 = look == "Ice" and Color3.fromRGB(170, 225, 255) or Color3.fromRGB(255, 230, 120), TextStrokeTransparency = 0.2})
				stunTags[m] = {bb = bb, label = label}
			elseif not look and t then
				t.bb:Destroy()
				stunTags[m] = nil
			end
		end
		for m, t in stunTags do
			if not m.Parent then
				t.bb:Destroy()
				stunTags[m] = nil
			else
				t.label.Rotation = math.sin(os.clock() * 8) * 8
			end
		end
	end
end)
