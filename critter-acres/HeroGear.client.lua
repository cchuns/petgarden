-- Critter Acres: HeroGear (StarterPlayerScripts LocalScript)
-- 🛡️ The Gear window (key G, dock button). Design: critter-acres/GEAR-UI.md (server: ServerScriptService.HeroGear).
--   Window tab 🧍 Character (👗 Outfits comes later, same layout for cosmetics).
--   Left: your own avatar in 3D (drag to spin) with the 6 slots next to their body part:
--     Head / Body / Legs / Boots down the left, Weapon + Off hand at hand height on the right. Tap a slot = open its tab.
--   Right: your inventory with browser-style tabs (🪖 Head, 👕 Body, 👖 Legs, 👢 Boots, ⚔️ Weapon, 🛡️ Shield):
--     only what you own for that slot, strongest first, Wear / Wearing (tap Wearing to take it off).
--   Gear is crafted at the 🔨 Workbench (CritterWorld), not here. 🎁 Capsules: button in the Weapon tab
--   (opens the old Weapons window, StarterPlayerScripts.Combat, on its capsules tab).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local K = require(ReplicatedStorage:WaitForChild("UIKit"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))
local actionFn = ReplicatedStorage:WaitForChild("CritterAction")
local bridge = ReplicatedStorage:WaitForChild("CritterUIBridge")
local WEAPONS = ReplicatedStorage:WaitForChild("WeaponModels", 30)
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "HeroGear"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

local function act(...) return actionFn:InvokeServer(...) end
local function toast(text, good) K.toast(gui, text, good) end
local function pct(x) return math.floor((x or 0) * 100 + 0.5) end
local RARITY = Data.WeaponRarityByName
local function rarityColor(r) return RARITY[r] and RARITY[r].Color or K.LINE end

local PANEL = Color3.fromRGB(243, 234, 216) -- the soft beige behind your avatar
local TAB_OFF = Color3.fromRGB(239, 227, 204)
local TAB_LINE = Color3.fromRGB(230, 205, 165)
local PICKED = Color3.fromRGB(230, 170, 50)

-- the 6 slots: where the card sits on the left panel (scale x / y) and the inventory tab word
local SLOTS = {
	{Id = "Head", Icon = "🪖", Word = "Head", X = 0.03, Y = 0.03},
	{Id = "Body", Icon = "👕", Word = "Body", X = 0.03, Y = 0.27},
	{Id = "Legs", Icon = "👖", Word = "Legs", X = 0.03, Y = 0.52},
	{Id = "Boots", Icon = "👢", Word = "Boots", X = 0.03, Y = 0.77},
	{Id = "MainHand", Icon = "⚔️", Word = "Weapon", X = 0.97, Y = 0.30},
	{Id = "OffHand", Icon = "🛡️", Word = "Shield", X = 0.97, Y = 0.53},
}

local win = K.window(gui, {Icon = "🛡️", Title = "Gear", Max = Vector2.new(940, 620)})
local info -- GearInfo from the server
local pick = "Head" -- the open inventory tab
local ui = {} -- the built pieces (left panel, slots, right panel)

local function itemById(id)
	for _, it in info.Items or {} do
		if it.Id == id then return it end
	end
end
local function weaponOn()
	for _, w in info.Weapons or {} do
		if w.Id == info.WeaponOn then return w end
	end
end
local function setInfo(res)
	if type(res) == "string" then toast(res, false) return false end
	if type(res) == "table" then info = res.Info or res end
	return true
end
local function weaponArt(pic, name)
	local tpl = WEAPONS and WEAPONS:FindFirstChild(name)
	if tpl and tpl:IsA("Model") then
		local ok = pcall(CritterUI.ModelView, pic, tpl, {Size = UDim2.fromScale(1, 1), ZIndex = pic.ZIndex + 1}, {Yaw = math.rad(30)})
		if ok then return end
	end
	local def = Data.WeaponByName[name]
	K.text(pic, {Text = def and def.Icon or "⚔️", Size = UDim2.fromScale(1, 1), Max = 54})
end
local function subText()
	local st = info.Stats or {}
	win.setSub(("❤️ %d HP   🛡️ %d%% less hurt   ⚡ %d PWR"):format(player:GetAttribute("HPMax") or 0, pct(st.Def),
		player:GetAttribute("PWR") or info.PWR or 0))
end

---------------------------------------------------------------- 🧍 your avatar (left panel)
local doll = {yaw = 0}
local function poseDoll()
	if doll.model and doll.model.Parent then
		doll.model:PivotTo(CFrame.Angles(0, doll.yaw, 0))
	end
end
local function buildDoll()
	local vf = ui.vf
	if not vf then return end
	if doll.model then doll.model:Destroy() doll.model = nil end
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	char.Archivable = true
	local ok, clone = pcall(function() return char:Clone() end)
	char.Archivable = false
	if not ok or not clone then return end
	for _, d in clone:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ForceField") then d:Destroy()
		elseif d:IsA("BasePart") then d.Anchored = true end
	end
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	clone.PrimaryPart = clone:FindFirstChild("HumanoidRootPart")
	clone.Parent = vf
	doll.model = clone
	poseDoll()
	-- frame it: the camera looks at your front (characters face -Z)
	local cf, size = clone:GetBoundingBox()
	local cam = vf.CurrentCamera
	local h = math.max(size.Y, 4)
	cam.FieldOfView = 30
	local dist = (h * 1.2) / math.tan(math.rad(15)) -- 1.2 = roomy margin around you (bigger = smaller avatar)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, cf.Position.Y, -dist), Vector3.new(0, cf.Position.Y, 0))
end
-- a moment after a change the server re-dresses you: show the new look
local function dollSoon()
	task.delay(0.45, function()
		if win.frame.Visible then buildDoll() end
	end)
end

---------------------------------------------------------------- the slot cards
local function slotLook(s)
	if s.Id == "MainHand" then
		local w = weaponOn()
		local def = w and Data.WeaponByName[w.Name]
		if def then return def.Icon, (w.Shiny and "✨ " or "") .. def.Display, rarityColor(def.Rarity) end
		return nil
	end
	local it = info.On and info.On[s.Id] and itemById(info.On[s.Id])
	local def = it and Data.HeroGearByName[it.Name]
	if def then return def.Icon, def.Display, rarityColor(def.Rarity) end
	return nil
end
local refreshInv
local function refreshSlots()
	for _, s in SLOTS do
		local c = ui.slots and ui.slots[s.Id]
		if c then
			local icon, name, color = slotLook(s)
			c.icon.Text = icon or "➕"
			c.icon.TextTransparency = icon and 0 or 0.45
			c.name.Text = name or "Empty"
			c.name.TextColor3 = name and K.BROWN or K.SOFT
			c.stroke.Color = color or K.GREY
			c.stroke.Thickness = icon and 3 or 2
			c.btn.BackgroundColor3 = (pick == s.Id) and Color3.fromRGB(255, 246, 214) or K.WHITE
			c.ring.Enabled = pick == s.Id
		end
	end
end
local function slotCard(parent, s)
	local right = s.X > 0.5
	local b = Instance.new("TextButton")
	b.Text, b.AutoButtonColor = "", false
	b.AnchorPoint = Vector2.new(right and 1 or 0, 0)
	b.Position = UDim2.fromScale(s.X, s.Y)
	b.Size = UDim2.fromOffset(88, 96)
	b.BackgroundColor3 = K.WHITE
	b.ZIndex = 4
	b.Parent = parent
	K.round(b, 12)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	-- the yellow ring around the slot whose tab is open (a second frame, so the rarity color stays)
	local ringF = K.frame(b, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 10, 1, 10), BackgroundTransparency = 1, ZIndex = 3})
	K.round(ringF, 15)
	local ring = Instance.new("UIStroke")
	ring.Color, ring.Thickness = PICKED, 3
	ring.Parent = ringF
	local tag = K.text(b, {Text = s.Word, Position = UDim2.fromOffset(6, -9), Size = UDim2.fromOffset(62, 18), BackgroundTransparency = 0,
		BackgroundColor3 = K.BROWN, TextColor3 = K.CREAM, ZIndex = 6, Max = 13})
	K.round(tag, 8)
	local icon = K.text(b, {Text = "", Position = UDim2.fromOffset(4, 10), Size = UDim2.new(1, -8, 0, 44), ZIndex = 5, Max = 36})
	local name = K.text(b, {Text = "", Position = UDim2.new(0, 4, 0, 56), Size = UDim2.new(1, -8, 0, 36), TextWrapped = true, ZIndex = 5, Max = 14})
	b.Activated:Connect(function()
		pick = s.Id
		refreshSlots()
		refreshInv()
	end)
	K.tip(b, s.Icon .. " " .. (s.Id == "OffHand" and "Off hand" or s.Word), "Tap to see what you have for this slot")
	-- a little dotted line toward the body part
	for i = 1, 4 do
		K.frame(parent, {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = Color3.fromRGB(210, 190, 156), ZIndex = 2,
			Position = UDim2.new(s.X, right and (-88 - 8 * i) or (88 + 8 * i), s.Y, 48)})
	end
	return {btn = b, stroke = stroke, ring = ring, icon = icon, name = name}
end

---------------------------------------------------------------- 🎒 inventory (right panel)
local function rebuildTabs()
	for _, t in ui.tabs or {} do t:Destroy() end
	ui.tabs = {}
	local n = #SLOTS
	for i, s in SLOTS do
		local on = pick == s.Id
		local t = Instance.new("TextButton")
		t.AutoButtonColor = false
		t.Font = K.FONT
		t.TextScaled = true
		t.Text = s.Icon .. " " .. s.Word
		t.TextColor3 = on and K.BROWN or K.SOFT
		t.BackgroundColor3 = on and K.WHITE or TAB_OFF
		t.Position = UDim2.new((i - 1) / n, 2, 0, on and 0 or 6)
		t.Size = UDim2.new(1 / n, -4, 0, on and 52 or 46)
		t.ZIndex = on and 4 or 2 -- unselected tabs tuck under the panel; the picked one sits on top of it
		t.Parent = ui.right
		K.round(t, 12)
		local st = Instance.new("UIStroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Color, st.Thickness = on and PICKED or TAB_LINE, 2
		st.Parent = t
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize, c.MinTextSize = 18, 10
		c.Parent = t
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, on and 14 or 12)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
		pad.Parent = t
		if on then -- white strip over its bottom edge: the tab and the panel join with no line between
			K.frame(t, {Position = UDim2.new(0, -2, 1, -12), Size = UDim2.new(1, 4, 0, 14), BackgroundColor3 = K.WHITE, ZIndex = 5})
		end
		t.Activated:Connect(function()
			pick = s.Id
			refreshSlots()
			refreshInv()
		end)
		table.insert(ui.tabs, t)
	end
end

local function gearCards(list)
	for i, it in list do
		local def = Data.HeroGearByName[it.Name]
		local on = info.On[def.Slot] == it.Id
		K.card(ui.grid, {Order = i, Name = def.Display, Color = rarityColor(def.Rarity),
			Sub = it.Text .. (it.Stars > 0 and (" " .. string.rep("⭐", it.Stars)) or ""),
			Art = function(pic)
				K.text(pic, {Text = def.Icon, Size = UDim2.fromScale(1, 0.78), Max = 46})
				K.text(pic, {Text = def.Rarity, Position = UDim2.fromScale(0, 0.74), Size = UDim2.fromScale(1, 0.24), TextColor3 = K.SOFT, Max = 13})
			end,
			Button = on and {Text = "✅ Wearing", Kind = "special"} or {Text = "Wear", Kind = "go"},
			Fn = function()
				local res = on and act("GearOff", def.Slot) or act("GearEquip", it.Id)
				if setInfo(res) then
					toast(on and ("%s %s off"):format(def.Icon, def.Display) or ("%s %s on!"):format(def.Icon, def.Display))
					refreshSlots()
					refreshInv()
					subText()
					dollSoon()
				end
			end,
			Tip = def.Icon .. " " .. def.Display,
			TipText = on and "Tap Wearing to take it off" or (def.Set and (def.Rarity .. " · part of the " .. Data.HeroSets[def.Set].Display) or def.Rarity)})
	end
end
local function weaponCards()
	local list = table.clone(info.Weapons or {})
	table.sort(list, function(a, b) return a.Power > b.Power end)
	for i, w in list do
		local def = Data.WeaponByName[w.Name]
		if def then
			local on = w.Id == info.WeaponOn
			local lo, hi = Data.WeaponRange(w)
			K.card(ui.grid, {Order = i, Name = (w.Shiny and "✨ " or "") .. def.Display, Color = rarityColor(def.Rarity),
				Sub = ("💥 %d-%d %s"):format(lo, hi, (w.Stars or 0) > 0 and string.rep("⭐", w.Stars) or ""),
				Art = function(pic) weaponArt(pic, w.Name) end,
				Button = on and {Text = "✅ Holding", Kind = "special"} or {Text = "Equip", Kind = "go"},
				Fn = function()
					if on then return end
					local res = act("WeaponEquip", w.Id)
					if type(res) == "string" then toast(res, false) return end
					toast(("⚔️ %s %s in hand!"):format(def.Icon, def.Display))
					setInfo(act("GearInfo"))
					refreshSlots()
					refreshInv()
					subText()
					dollSoon()
				end,
				Tip = def.Icon .. " " .. def.Display, TipText = def.Rarity})
		end
	end
	return #list
end
function refreshInv()
	if not ui.panel then return end
	rebuildTabs()
	for _, ch in ui.grid:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	if ui.caps then ui.caps.Visible = pick == "MainHand" end
	local s
	for _, x in SLOTS do if x.Id == pick then s = x end end
	local n
	if pick == "MainHand" then
		n = weaponCards()
	else
		local list = {}
		for _, it in info.Items or {} do
			local def = Data.HeroGearByName[it.Name]
			if def and def.Slot == pick then table.insert(list, it) end
		end
		table.sort(list, function(a, b) return a.Pwr > b.Pwr end)
		gearCards(list)
		n = #list
	end
	ui.title.Text = ("%s %s  ·  %d owned"):format(s.Icon, s.Id == "OffHand" and "Off hand" or s.Word, n)
	ui.empty.Visible = n == 0
	ui.grid.CanvasPosition = Vector2.zero
end

---------------------------------------------------------------- the window
local function build()
	win.clear()
	ui = {}
	win.setTabs({{"Character", "🧍 Character", "Your gear and weapon"}}, "Character", function() end)
	win.setHelp({{"🧍", "Tap a slot on you to see the gear you have for it."}, {"🔨", "Make Leaf, Stone and Iron gear at the Workbench."},
		{"🏆", "Gold, Crystal and Magma gear only drop from bosses. Wear 4 of a set to sparkle!"}})
	subText()
	local body = win.body
	local sc = win.frame:FindFirstChildOfClass("UIScale")
	local h = math.max(420, body.AbsoluteSize.Y / (sc and sc.Scale or 1) - 16)
	local main = K.frame(body, {Size = UDim2.new(1, -8, 0, h), BackgroundTransparency = 1, LayoutOrder = 1})
	-- left: you
	local left = K.frame(main, {Size = UDim2.new(0.4, -6, 1, 0), BackgroundColor3 = PANEL, ClipsDescendants = true})
	K.round(left, 16)
	local vf = Instance.new("ViewportFrame")
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(200, 195, 185)
	vf.LightColor = Color3.fromRGB(255, 250, 240)
	vf.LightDirection = Vector3.new(-0.4, -1, 0.6)
	vf.ZIndex = 1
	vf.Parent = left
	local cam = Instance.new("Camera")
	cam.Parent = vf
	vf.CurrentCamera = cam
	ui.vf = vf
	K.text(left, {Text = "⟲ drag to spin", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(140, 18),
		TextColor3 = K.SOFT, ZIndex = 2, Max = 13})
	-- drag to spin
	local dragging, lastX = false, 0
	vf.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, lastX = true, input.Position.X
		end
	end)
	vf.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	ui.dragConn = UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			doll.yaw += (input.Position.X - lastX) * 0.012
			lastX = input.Position.X
			poseDoll()
		end
	end)
	ui.slots = {}
	for _, s in SLOTS do ui.slots[s.Id] = slotCard(left, s) end
	-- right: inventory with browser tabs on top
	local right = K.frame(main, {Position = UDim2.new(0.4, 6, 0, 0), Size = UDim2.new(0.6, -6, 1, 0), BackgroundTransparency = 1})
	ui.right = right
	local panel = K.frame(right, {Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), BackgroundColor3 = K.WHITE, ZIndex = 3})
	K.round(panel, 14)
	local ps = Instance.new("UIStroke")
	ps.Color, ps.Thickness = PICKED, 2
	ps.Parent = panel
	ui.panel = panel
	ui.title = K.text(panel, {Text = "", Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -190, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Max = 20})
	ui.caps = K.button(panel, {Text = "🎁 Capsules", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(150, 34), ZIndex = 4,
		Kind = "special", Max = 17, Tip = "🎁 Capsules", TipText = "Open capsules for new weapons"}, function()
		win.close()
		bridge:Fire("Capsules") -- (StarterPlayerScripts.Combat)
	end)
	K.badge(ui.caps, player:GetAttribute("Capsules") or 0)
	local grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(10, 52)
	grid.Size = UDim2.new(1, -20, 1, -62)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = Color3.fromRGB(200, 170, 130)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ZIndex = 4
	grid.Parent = panel
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(132, 188)
	gl.CellPadding = UDim2.fromOffset(10, 10)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingLeft = UDim.new(0, 6), UDim.new(0, 4)
	pad.Parent = grid
	ui.grid = grid
	ui.empty = K.text(panel, {Text = "Nothing here yet!\n🔨 Make gear at the Workbench, or beat bosses 🏆", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 0, 70), TextWrapped = true, TextColor3 = K.SOFT, ZIndex = 4, Max = 20, Visible = false})
	refreshSlots()
	refreshInv()
	buildDoll()
end

local function openGear(slot)
	local res = act("GearInfo")
	if type(res) ~= "table" then return end
	info = res
	if slot then pick = slot end
	bridge:Fire("WeaponsClose")
	win.open()
	task.wait() -- (the window needs a frame to get its size)
	build()
end
win.onClose = function()
	if ui.dragConn then ui.dragConn:Disconnect() ui.dragConn = nil end
	if doll.model then doll.model:Destroy() doll.model = nil end
end
bridge.Event:Connect(function(cmd)
	if cmd == "Gear" then openGear() end
end)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.G then
		if player:GetAttribute("Decorating") then return end -- in decorate mode G = ▦ grid
		if win.frame.Visible then win.close() else openGear() end
	end
end)
-- PWR / HP move a moment after a change: keep the numbers fresh
for _, a in {"PWR", "HPMax"} do
	player:GetAttributeChangedSignal(a):Connect(function()
		if win.frame.Visible and info then subText() end
	end)
end
