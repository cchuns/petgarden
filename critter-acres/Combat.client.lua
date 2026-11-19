-- Critter Acres: Combat (StarterPlayerScripts LocalScript)
-- The battle side you see and touch (server: ServerScriptService.Combat):
--   ⚔️ click / tap (or the big ⚔️ button) to use your weapon: magic weapons shoot a sparkly bolt at the closest mob,
--      melee weapons swing a bonk in front of you
--   ❤️ HP bar at the bottom middle while you're in a wild land (with ⚔️ Hero Lv, ⚡ PWR and 👥 Party PWR under it);
--      a hit pops a red "-18" over you, flashes the screen red and wobbles the camera
--   🏷️ mob name tags: "Lv 7 ⚔️ 18" (🏹 = shoots from afar), colored by danger: gray / green / orange / red
--   😵 faint screen -> you wake at the portal with full HP
--   ❗ a mob that notices you pops a big "!" and glows red (orange if it's after a friend). Right before it bonks,
--      the glow flashes bright: that's your cue to step back!
--   numbers fly off mobs you hit (💥 CRIT for big ones), HP bars, a boss bar, loot popping out, sparkle poofs
--   ⚔️ Weapons menu (dock button): your weapons (equip, ⭐ stars, ✨ shiny) and 🎁 capsules to open
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local K = require(ReplicatedStorage:WaitForChild("UIKit"))
local PackOpen = require(ReplicatedStorage:WaitForChild("PackOpen"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))
local actionFn = ReplicatedStorage:WaitForChild("CritterAction")
local remote = ReplicatedStorage:WaitForChild("Combat", 60)
local bridge = ReplicatedStorage:WaitForChild("CritterUIBridge")
local WEAPONS = ReplicatedStorage:WaitForChild("WeaponModels", 30)
local player = Players.LocalPlayer

-- the hotbar sits where our dock is; the weapon goes in your hand by itself in the wild lands
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then break end
		task.wait(0.5)
	end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "Combat"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local function act(...) return actionFn:InvokeServer(...) end
local function toast(text, good) K.toast(gui, text, good) end
local function inRealm() return player:GetAttribute("Realm") ~= nil end
local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local RARITY = {}
local STYLE_WORD = {Magic = "🪄 Magic", Melee = "🔨 Melee", Range = "🏹 Range"}
for _, r in Data.WeaponRarities do RARITY[r.Name] = r end

---------------------------------------------------------------- mobs you can see
local function aliveMobs()
	local list = {}
	for _, m in CollectionService:GetTagged("MobRig") do
		if m.Parent and m:GetAttribute("HP") and not m:GetAttribute("Dead") and m.PrimaryPart then table.insert(list, m) end
	end
	return list
end
local function mobCenter(m)
	local cf, size = m:GetBoundingBox()
	return cf.Position, size
end

-- pick a target for magic: what's under the mouse, else the closest mob in front of you, else the closest one
local camera = workspace.CurrentCamera
local function pickTarget(range)
	local root = hrp()
	if not root then return nil end
	local mobs = aliveMobs()
	if UserInputService.MouseEnabled then
		local mp = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mp.X, mp.Y)
		local best, bd = nil, math.huge
		for _, m in mobs do
			local c, size = mobCenter(m)
			local toC = c - ray.Origin
			local along = toC:Dot(ray.Direction)
			if along > 0 then
				local off = (toC - ray.Direction * along).Magnitude - size.Magnitude * 0.35
				if off < 2.5 and (flat(c) - flat(root.Position)).Magnitude <= range + 6 and off < bd then best, bd = m, off end
			end
		end
		if best then return best end
	end
	local look = flat(root.CFrame.LookVector).Unit
	local front, fd, any, ad = nil, math.huge, nil, math.huge
	for _, m in mobs do
		local c = mobCenter(m)
		local to = flat(c) - flat(root.Position)
		local d = to.Magnitude
		if d <= range then
			if d < ad then any, ad = m, d end
			if d > 0.1 and look:Dot(to.Unit) > 0.35 and d < fd then front, fd = m, d end
		end
	end
	return front or any
end

---------------------------------------------------------------- attacking
local lastAtk = 0
local hintAt = 0
local function equippedTool()
	local c = player.Character
	if not c then return nil end
	for _, t in c:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("Weapon") then return t end
	end
end
local function bagTool()
	local bp = player:FindFirstChildOfClass("Backpack")
	if not bp then return nil end
	for _, t in bp:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("Weapon") then return t end
	end
end

-- a sparkly ball (magic) or an arrow / pebble (range) that flies into the mob
local function bolt(fromPos, model, color, big, style)
	local c = mobCenter(model)
	local p = Instance.new("Part")
	local arrow = style == "Range"
	if arrow then
		p.Size = Vector3.new(0.3, 0.3, big and 2.4 or 1.9)
	else
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * (big and 1.4 or 1)
	end
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CFrame = arrow and CFrame.lookAt(fromPos, c) or CFrame.new(fromPos)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.4, 0), Vector3.new(0, -0.4, 0)
	a0.Parent, a1.Parent = p, p
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	tr.Transparency = NumberSequence.new(0.2, 1)
	tr.Lifetime = 0.25
	tr.LightEmission = 1
	tr.Parent = p
	p.Parent = workspace
	local t = math.clamp((c - fromPos).Magnitude / (arrow and 190 or 140), 0.08, 0.35)
	tween(p, t, {CFrame = arrow and CFrame.lookAt(c, c + (c - fromPos).Unit) or CFrame.new(c)}, Enum.EasingStyle.Linear)
	task.delay(t, function()
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(color)
		pe.Size = NumberSequence.new(0.8, 0)
		pe.Speed = NumberRange.new(6, 12)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Lifetime = NumberRange.new(0.3, 0.5)
		pe.LightEmission = 1
		pe.Rate = 0
		pe.Parent = p
		pe:Emit(16)
		p.Transparency = 1
		Debris:AddItem(p, 0.6)
	end)
end

local function slash(root, color, range)
	local p = Instance.new("Part")
	p.Size = Vector3.new(range * 1.4, 0.2, range * 0.9)
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.35
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	local cf = root.CFrame * CFrame.new(0, 0.5, -range * 0.45)
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(-25)) * CFrame.Angles(0, math.rad(-40), 0)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = workspace
	tween(p, 0.22, {CFrame = cf * CFrame.Angles(0, 0, math.rad(-25)) * CFrame.Angles(0, math.rad(40), 0), Transparency = 1})
	Debris:AddItem(p, 0.3)
end

local function attack()
	local tool = equippedTool()
	if not tool then
		local b = bagTool()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if b and hum and inRealm() then hum:EquipTool(b) end
		return
	end
	local now = os.clock()
	local cd = tool:GetAttribute("Cd") or 0.6
	cd /= (player:GetAttribute("AtkSpeed") or 1) -- ⚡ Rapid Fire (any weapon)
	if now - lastAtk < cd then return end
	lastAtk = now
	local root = hrp()
	if not root then return end
	-- swing animation (the default Animate script plays it)
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	local color = tool:GetAttribute("Fx") or Color3.fromRGB(255, 230, 120)
	local style = tool:GetAttribute("Style")
	local range = tool:GetAttribute("Range") or 30
	if not inRealm() then
		local tip = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Tip")
		if tip then
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Color = ColorSequence.new(color)
			pe.Size = NumberSequence.new(0.5, 0)
			pe.Speed = NumberRange.new(3, 6)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Lifetime = NumberRange.new(0.3, 0.6)
			pe.Rate = 0
			pe.Parent = tip
			pe:Emit(10)
			Debris:AddItem(pe, 1)
		end
		if now - hintAt > 8 then
			hintAt = now
			toast("⚔️ Weapons work on mobs in the wild lands. Visit the 🌀 Explorer's Portal!")
		end
		return
	end
	if style == "Magic" or style == "Range" then
		if style == "Magic" then range *= player:GetAttribute("ReachMul") or 1 end -- 📏 Long Reach
		local target = pickTarget(range)
		local tip = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Tip")
		local from = tip and tip.WorldPosition or (root.Position + Vector3.new(0, 1.5, 0))
		if target then
			bolt(from, target, color, tool:GetAttribute("Shiny"), style)
			-- turn toward it
			local c = mobCenter(target)
			local to = flat(c - root.Position)
			if to.Magnitude > 0.5 then root.CFrame = CFrame.lookAt(root.Position, root.Position + to) end
		end
		remote:FireServer("Attack", target)
	else
		local target = pickTarget(range + 4)
		if target then
			local c = mobCenter(target)
			local to = flat(c - root.Position)
			if to.Magnitude > 0.5 and to.Magnitude < range + 4 then root.CFrame = CFrame.lookAt(root.Position, root.Position + to) end
		end
		slash(root, color, range)
		remote:FireServer("Attack", nil)
	end
end

local function hookTool(tool)
	if not tool:IsA("Tool") or not tool:GetAttribute("Weapon") or tool:GetAttribute("Hooked") then return end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(attack)
end
local function hookChar(char)
	for _, t in char:GetChildren() do hookTool(t) end
	char.ChildAdded:Connect(hookTool)
end
if player.Character then hookChar(player.Character) end
player.CharacterAdded:Connect(hookChar)

---------------------------------------------------------------- ❤️ HP bar + ⚡ PWR + attack button (wild lands only)
local hpCard = K.frame(gui, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(380, 52),
	BackgroundColor3 = K.CREAM, Visible = false})
K.round(hpCard, 14)
K.stroke(hpCard, Color3.fromRGB(230, 170, 50), 2)
local hpBack = K.frame(hpCard, {Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 24), BackgroundColor3 = Color3.fromRGB(80, 60, 50)})
K.round(hpBack, 12)
local hpFill = K.frame(hpBack, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = K.GREEN})
K.round(hpFill, 12)
local hpText = K.text(hpBack, {Text = "", Size = UDim2.fromScale(1, 1), Max = 18, TextColor3 = K.WHITE, ZIndex = 3})
hpText.TextStrokeTransparency = 0.3
local infoText = K.text(hpCard, {Text = "", Position = UDim2.fromOffset(8, 31), Size = UDim2.new(1, -16, 0, 15), Max = 14, TextColor3 = K.SOFT})
local xpBack = K.frame(hpCard, {Position = UDim2.new(0, 16, 1, -5), Size = UDim2.new(1, -32, 0, 3), BackgroundColor3 = Color3.fromRGB(225, 210, 190)})
local xpFill = K.frame(xpBack, {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(150, 120, 255)})
local function drawHp()
	local max = player:GetAttribute("HPMax") or 100
	local hp = math.clamp(player:GetAttribute("HP") or max, 0, max)
	local k = hp / math.max(1, max)
	tween(hpFill, 0.2, {Size = UDim2.fromScale(k, 1)})
	hpFill.BackgroundColor3 = k > 0.5 and K.GREEN or (k > 0.25 and K.YELLOW or K.RED)
	hpText.Text = ("❤️ %d / %d"):format(hp, max)
	local lv = player:GetAttribute("HeroLv") or 1
	local pwr = player:GetAttribute("PWR") or Data.Pwr.Base
	local party = player:GetAttribute("PartyPWR")
	infoText.Text = ("⚔️ Hero Lv %d    ⚡ PWR %d%s"):format(lv, pwr, (party and party > pwr) and ("    👥 Party PWR %d"):format(party) or "")
	local need = Data.HeroNeed(lv)
	xpFill.Size = UDim2.fromScale(lv >= Data.HeroMax and 1 or math.clamp((player:GetAttribute("HeroXp") or 0) / need, 0, 1), 1)
end
for _, a in {"HP", "HPMax", "PWR", "PartyPWR", "HeroLv", "HeroXp"} do player:GetAttributeChangedSignal(a):Connect(drawHp) end

local atkBtn = K.button(gui, {Text = "⚔️", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -84), Size = UDim2.fromOffset(104, 104),
	Kind = "special", Max = 54, Visible = false}, attack)
K.round(atkBtn, 52)
K.text(atkBtn, {Text = "Attack", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 18), Size = UDim2.fromOffset(110, 24), Max = 18,
	TextStrokeTransparency = 0.4, TextColor3 = K.WHITE})

-- 🐾 buddy mode chip (above the hearts, only when a buddy pet came along): 🛡️ Passive <-> ⚔️ Aggressive, or press V
local MODE_LOOK = {
	Passive = {"🛡️ Buddy: Passive", Color3.fromRGB(150, 210, 255), "Helps only when a mob is after you, or when you attack."},
	Aggressive = {"⚔️ Buddy: Aggressive", Color3.fromRGB(255, 160, 140), "Attacks any mob that comes near you."},
}
local modeBtn
local function setMode(mode)
	local r = act("BuddyMode", mode)
	if type(r) == "string" then toast(r, false) return end
	toast(mode == "Aggressive" and "⚔️ Your buddy will attack any mob near you!" or "🛡️ Your buddy will only help when you need it.", true)
end
local function toggleMode()
	if not (inRealm() and player:GetAttribute("RealmBuddy")) then return end
	setMode(player:GetAttribute("BuddyMode") == "Aggressive" and "Passive" or "Aggressive")
end
modeBtn = K.button(gui, {Text = "", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 198, 1, -21), Size = UDim2.fromOffset(210, 42),
	Max = 20, Visible = false, Tip = "🐾 Buddy mode (V)", TipText = "Tap to switch. Passive: helps only when needed. Aggressive: attacks mobs near you."}, toggleMode)
local function drawMode()
	local look = MODE_LOOK[player:GetAttribute("BuddyMode") or "Passive"] or MODE_LOOK.Passive
	modeBtn.Text = look[1] .. "  (V)"
	modeBtn.BackgroundColor3 = look[2]
	modeBtn.Visible = inRealm() and player:GetAttribute("RealmBuddy") ~= nil
end
player:GetAttributeChangedSignal("BuddyMode"):Connect(drawMode)
player:GetAttributeChangedSignal("RealmBuddy"):Connect(drawMode)
UserInputService.InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.V then toggleMode() end
end)

local function realmChanged()
	local on = inRealm()
	hpCard.Visible = on
	atkBtn.Visible = on and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled -- phones / tablets only (PC: click to attack)
	if on then drawHp() end
	drawMode()
end
player:GetAttributeChangedSignal("Realm"):Connect(realmChanged)
realmChanged()

-- red flash + camera wobble when you get bonked
local flash = K.frame(gui, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 60, 60), BackgroundTransparency = 1, ZIndex = 50, Active = false})
local function shake(power, secs)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = os.clock() - t0
		if k > secs or not hum.Parent then
			hum.CameraOffset = Vector3.zero
			conn:Disconnect()
			return
		end
		local a = power * (1 - k / secs)
		hum.CameraOffset = Vector3.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
	end)
end

-- 😵 fainted
local faint = K.frame(gui, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 215, 235), BackgroundTransparency = 1, ZIndex = 60, Visible = false})
local faintIcon = K.text(faint, {Text = "😵‍💫", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(200, 140), ZIndex = 61, Max = 110})
K.text(faint, {Text = "Oops! You fainted!", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(600, 56), ZIndex = 61, Max = 44})
K.text(faint, {Text = "Waking up at the portal with full ❤️ HP...", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(600, 34),
	ZIndex = 61, Max = 24, TextColor3 = K.SOFT})

---------------------------------------------------------------- over the mobs: ❗, glow, HP bar
local deco = {} -- model -> {bb, bang, bar, fill, hl, angry, act}
local function billboard(m, h, size)
	local bb = Instance.new("BillboardGui")
	bb.Size = size
	bb.StudsOffsetWorldSpace = Vector3.new(0, h, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	bb.LightInfluence = 0
	bb.Adornee = m.PrimaryPart
	bb.Parent = m.PrimaryPart
	return bb
end
local function decoFor(m)
	local d = deco[m]
	if d then return d end
	local _, size = mobCenter(m)
	local pivotToTop = size.Y / 2 + 0.6 + (m.PrimaryPart.Position.Y - mobCenter(m).Y) * -1
	d = {h = pivotToTop}
	-- HP bar
	local bb = billboard(m, pivotToTop + 1.2, UDim2.fromOffset(110, 22))
	bb.Enabled = false
	local back = K.frame(bb, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(60, 45, 40)})
	K.round(back, 11)
	K.stroke(back, K.WHITE, 2)
	local fill = K.frame(back, {Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundColor3 = K.GREEN})
	K.round(fill, 8)
	d.bb, d.fill = bb, fill
	-- 🏷️ "Lv 7 ⚔️ 18" (color = danger for you)
	local tag = billboard(m, pivotToTop + 2.7, UDim2.fromOffset(170, 26))
	tag.Enabled = false
	local tagText = K.text(tag, {Text = "", Size = UDim2.fromScale(1, 1), Max = 20, TextColor3 = K.WHITE})
	tagText.TextStrokeTransparency = 0.15
	tagText.TextStrokeColor3 = Color3.fromRGB(50, 35, 30)
	d.tag, d.tagText = tag, tagText
	-- ❗
	local bang = billboard(m, pivotToTop + (m:GetAttribute("Boss") and 5.8 or 4.6), UDim2.fromOffset(70, 70))
	bang.Enabled = false
	local t = K.text(bang, {Text = "❗", Size = UDim2.fromScale(1, 1), Max = 64})
	Instance.new("UIScale", t)
	d.bang, d.bangText = bang, t
	deco[m] = d
	return d
end
local function setAngryLook(m, d, angry, mine)
	d.angry = angry
	if angry then
		d.bang.Enabled = true
		d.bangText.Text = m:GetAttribute("Boss") and "‼️" or "❗"
		local s = d.bangText.UIScale
		s.Scale = 0
		tween(s, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
		if not d.hl then
			local hl = Instance.new("Highlight")
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.FillTransparency = 0.8
			hl.OutlineTransparency = 0
			hl.Parent = m
			d.hl = hl
		end
		d.hl.FillColor = mine and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(255, 160, 60)
		d.hl.OutlineColor = mine and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(255, 150, 40)
	else
		d.bang.Enabled = false
		if d.hl then d.hl:Destroy() d.hl = nil end
	end
end

RunService.Heartbeat:Connect(function()
	local root = hrp()
	local now = os.clock()
	for m, d in deco do
		if not m.Parent or not m.PrimaryPart then deco[m] = nil end
	end
	if not root then return end
	local shown = 0
	local myLv = math.floor(Data.LevelOfPwr(player:GetAttribute("PWR") or Data.Pwr.Base))
	for _, m in CollectionService:GetTagged("MobRig") do
		if m.Parent and m.PrimaryPart and m:GetAttribute("HP") then
			local near = (m.PrimaryPart.Position - root.Position).Magnitude < 110
			local d = deco[m]
			if near or d then
				d = d or decoFor(m)
				local angry = m:GetAttribute("Angry") == true and not m:GetAttribute("Dead")
				local mine = m:GetAttribute("TargetId") == player.UserId
				if angry and shown >= 24 then angry = false end -- (Highlight limit)
				if angry ~= (d.angry or false) or (angry and mine ~= d.mine) then
					d.mine = mine
					setAngryLook(m, d, angry, mine)
				end
				if angry then
					shown += 1
					-- gentle pulse, and a bright flash right before a bonk (step back!)
					local act = m:GetAttribute("Act") or 0
					if act ~= d.act then
						if d.act then d.flashAt = now end
						d.act = act
					end
					local f = d.flashAt and now - d.flashAt < 0.6
					d.hl.FillTransparency = f and (0.25 + 0.3 * math.abs(math.sin(now * 20))) or (0.7 + 0.12 * math.sin(now * 5))
					d.bangText.UIScale.Scale = f and 1.35 or 1
				end
				local lv = m:GetAttribute("Lv")
				if lv then
					local _, col = Data.MobDanger(lv, myLv)
					local txt = ("Lv %d   %s %d"):format(lv, m:GetAttribute("Role") == "Ranged" and "🏹" or "⚔️", m:GetAttribute("ATT") or 0)
					if d.tagText.Text ~= txt then d.tagText.Text = txt end
					if d.tagText.TextColor3 ~= col then d.tagText.TextColor3 = col end
				end
				d.tag.Enabled = lv ~= nil and near and not m:GetAttribute("Dead")
				local hp, max = m:GetAttribute("HP") or 1, m:GetAttribute("MaxHP") or 1
				d.bb.Enabled = hp < max and not m:GetAttribute("Dead") and near
				local k = math.clamp(hp / math.max(1, max), 0, 1)
				d.fill.Size = UDim2.new(k, -6 * k, 1, -6)
				d.fill.BackgroundColor3 = k > 0.5 and K.GREEN or (k > 0.25 and K.YELLOW or K.RED)
			end
		end
	end
end)

---------------------------------------------------------------- 👑 boss bar
local bossBar = K.frame(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 124), Size = UDim2.fromOffset(460, 62), BackgroundColor3 = K.CREAM, Visible = false})
-- under the land bar (TerrainPortal), which sits under the top-right dock; this gui ignores the top bar inset, so add it
local function placeBossBar()
	local y = player:GetAttribute("HudCompact") and 196 or 148
	bossBar.Position = UDim2.new(0.5, 0, 0, game:GetService("GuiService"):GetGuiInset().Y + y)
end
placeBossBar()
player:GetAttributeChangedSignal("HudCompact"):Connect(placeBossBar)
K.round(bossBar, 16)
K.stroke(bossBar, Color3.fromRGB(230, 170, 50), 3)
local bossName = K.text(bossBar, {Text = "", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 26), Max = 22})
local bossBack = K.frame(bossBar, {Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 18), BackgroundColor3 = Color3.fromRGB(80, 60, 50)})
K.round(bossBack, 9)
local bossFill = K.frame(bossBack, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = K.RED})
K.round(bossFill, 9)
local bossFocus
task.spawn(function()
	while true do
		task.wait(0.15)
		local root = hrp()
		local found
		if root and inRealm() then
			for _, m in CollectionService:GetTagged("MobRig") do
				if m.Parent and m:GetAttribute("Boss") and m.PrimaryPart and not m:GetAttribute("Dead")
					and (m:GetAttribute("Angry") or (m:GetAttribute("HP") or 0) < (m:GetAttribute("MaxHP") or 0))
					and (m.PrimaryPart.Position - root.Position).Magnitude < 90 then
					found = m
					break
				end
			end
		end
		bossFocus = found
		bossBar.Visible = found ~= nil
		if found then
			bossName.Text = "👑 " .. found.Name:gsub("(%l)(%u)", "%1 %2") .. (found:GetAttribute("Lv") and ("   Lv " .. found:GetAttribute("Lv")) or "")
			local k = math.clamp((found:GetAttribute("HP") or 0) / math.max(1, found:GetAttribute("MaxHP") or 1), 0, 1)
			tween(bossFill, 0.15, {Size = UDim2.fromScale(k, 1)})
		end
	end
end)

---------------------------------------------------------------- floating numbers, loot, poofs
local function floatText(m, text, color, big, rise)
	if not m or not m.PrimaryPart then return end
	local c, size = mobCenter(m)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = true, false, false, false, 1
	a.Size = Vector3.one * 0.2
	a.Position = c + Vector3.new((math.random() - 0.5) * size.X * 0.6, size.Y * 0.35, 0)
	a.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(big and 170 or 120, big and 60 or 44)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = a
	local t = K.text(bb, {Text = text, Size = UDim2.fromScale(1, 1), TextColor3 = color, Max = big and 46 or 32, TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(70, 40, 40)})
	local s = Instance.new("UIScale")
	s.Scale = 0.3
	s.Parent = t
	tween(s, 0.2, {Scale = big and 1.25 or 1}, Enum.EasingStyle.Back)
	tween(a, 0.9, {Position = a.Position + Vector3.new(0, rise or 3.5, 0)})
	task.delay(0.55, function() tween(t, 0.35, {TextTransparency = 1, TextStrokeTransparency = 1}) end)
	Debris:AddItem(a, 1)
end

local function burst(pos, color, n, size)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = true, false, false, false, 1
	a.Size = Vector3.one * 0.2
	a.Position = pos
	a.Parent = workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.Size = NumberSequence.new(size or 1, 0)
	pe.Speed = NumberRange.new(8, 18)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.5, 0.9)
	pe.Drag = 3
	pe.LightEmission = 1
	pe.Rate = 0
	pe.Parent = a
	pe:Emit(n or 30)
	Debris:AddItem(a, 1.2)
end

local function bigBanner(text, color)
	local t = K.text(gui, {Text = text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(640, 90), Max = 60,
		TextColor3 = color or K.YELLOW, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(90, 50, 30), ZIndex = 55})
	local s = Instance.new("UIScale")
	s.Scale = 0.2
	s.Parent = t
	tween(s, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		tween(t, 0.4, {TextTransparency = 1, TextStrokeTransparency = 1})
		Debris:AddItem(t, 0.5)
	end)
end

---------------------------------------------------------------- ⭐ loot stars (only yours show up; a surprise until picked up)
local function floatAt(pos, text, color, big, rise)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = true, false, false, false, 1
	a.Size = Vector3.one * 0.2
	a.Position = pos
	a.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(big and 260 or 190, big and 66 or 48)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = a
	local t = K.text(bb, {Text = text, Size = UDim2.fromScale(1, 1), TextColor3 = color, Max = big and 44 or 30, TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(90, 60, 20)})
	local s = Instance.new("UIScale")
	s.Scale = 0.3
	s.Parent = t
	tween(s, 0.3, {Scale = big and 1.3 or 1}, Enum.EasingStyle.Back)
	tween(a, 1.6, {Position = pos + Vector3.new(0, rise or 4, 0)})
	task.delay(1.1, function() tween(t, 0.5, {TextTransparency = 1, TextStrokeTransparency = 1}) end)
	Debris:AddItem(a, 1.7)
end

local spinning = {} -- star part -> {base, seed}
local hinted = false
local function onStar(p)
	if not p:IsA("BasePart") then return end
	if p:GetAttribute("Owner") ~= player.UserId then
		p:Destroy() -- someone else's loot: hidden on your screen
		return
	end
	local base = p.CFrame
	local rec = {base = base, seed = math.random() * 10, born = os.clock(), from = p:GetAttribute("From")}
	spinning[p] = rec
	p.AncestryChanged:Connect(function() if not p.Parent then spinning[p] = nil end end)
	if not hinted and inRealm() then
		hinted = true
		toast("⭐ Walk over the stars to see what's inside!", true)
	end
end
CollectionService:GetInstanceAddedSignal("LootStar"):Connect(onStar)
for _, p in CollectionService:GetTagged("LootStar") do task.spawn(onStar, p) end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for p, r in spinning do
		local t = now + r.seed
		local spin = CFrame.Angles(0, t * 2.2, 0) * CFrame.Angles(0, 0, math.sin(t * 1.5) * 0.15)
		local k = (now - r.born) / 0.6
		if k < 1 and r.from then
			-- pops out of the mob in a little arc
			local a, b = r.from + Vector3.new(0, 1, 0), r.base.Position
			local pos = a:Lerp(b, k) + Vector3.new(0, math.sin(k * math.pi) * 5, 0)
			p.CFrame = CFrame.new(pos) * spin
		else
			p.CFrame = r.base * CFrame.new(0, math.sin(t * 2.5) * 0.35, 0) * spin
		end
	end
end)

local function starGot(msg)
	local gold = Color3.fromRGB(255, 225, 90)
	if msg.Pet and msg.Pet.Parent then
		-- your buddy fetches it: a little star zips over to the pet
		local s = Instance.new("Part")
		s.Shape = Enum.PartType.Ball
		s.Anchored, s.CanCollide, s.CanQuery, s.CanTouch = true, false, false, false
		s.Material = Enum.Material.Neon
		s.Color = gold
		s.Size = Vector3.one * 0.9
		s.Position = msg.Pos
		s.Parent = workspace
		local to = msg.Pet:GetPivot().Position + Vector3.new(0, 1.5, 0)
		tween(s, 0.35, {Position = to, Size = Vector3.one * 0.3})
		Debris:AddItem(s, 0.4)
		task.delay(0.35, function()
			burst(to, gold, msg.Big and 30 or 12, 0.6)
			floatAt(to + Vector3.new(0, 2, 0), "🐾 " .. msg.Text, msg.Big and K.YELLOW or Color3.fromRGB(255, 245, 200), msg.Big)
		end)
	else
		burst(msg.Pos, gold, msg.Big and 45 or 20, msg.Big and 1.2 or 0.8)
		floatAt(msg.Pos + Vector3.new(0, 1.5, 0), msg.Text, msg.Big and K.YELLOW or Color3.fromRGB(255, 245, 200), msg.Big)
	end
end

local grayTipAt
remote.OnClientEvent:Connect(function(msg)
	local k = msg.Kind
	if k == "Dmg" then
		if msg.Crit then
			floatText(msg.Model, "💥 " .. msg.N .. "!", Color3.fromRGB(255, 220, 60), true)
		elseif msg.Pet then
			floatText(msg.Model, "🐾 " .. msg.N, Color3.fromRGB(150, 230, 255))
		else
			floatText(msg.Model, tostring(msg.N), msg.By == player.UserId and K.WHITE or Color3.fromRGB(230, 230, 230))
		end
		-- a little squish on hit
		local m = msg.Model
		if m and m.Parent and deco[m] and deco[m].hl then
			deco[m].hl.FillTransparency = 0.2
		end
	elseif k == "Defeat" then
		local m = msg.Model
		if m and m.Parent then
			local c = mobCenter(m)
			burst(c, Color3.fromRGB(255, 230, 140), msg.Boss and 80 or 30, msg.Boss and 2 or 1)
			floatText(m, msg.Boss and "🎉 DEFEATED!" or "✨ Poof!", Color3.fromRGB(255, 240, 160), msg.Boss, 5)
		end
		if msg.Boss then bigBanner("👑 " .. (msg.Name or "Boss") .. " defeated! 🎉") end
	elseif k == "Loot" then
		for i, text in msg.Items or {} do
			task.delay(0.25 + i * 0.22, function() floatText(msg.Model, text, Color3.fromRGB(255, 245, 200), false, 5) end)
		end
		if (msg.Stars or 0) > 0 then
			task.delay(0.5, function() floatText(msg.Model, ("⭐ x%d"):format(msg.Stars), K.YELLOW, false, 6) end)
		end
		-- gray mobs (far below your level) give only a little
		if msg.Gray and os.clock() - (grayTipAt or -99) > 45 then
			grayTipAt = os.clock()
			toast("⚪ Gray mobs are too easy for you: tiny rewards. Try a harder land!")
		end
	elseif k == "StarGot" then
		starGot(msg)
	elseif k == "Hurt" then
		flash.BackgroundTransparency = 0.55
		tween(flash, 0.45, {BackgroundTransparency = 1})
		shake(msg.Big and 1.4 or 0.8, 0.3)
		local r = hrp()
		if r then floatAt(r.Position + Vector3.new(0, 3.2, 0), "-" .. tostring(msg.N), Color3.fromRGB(255, 90, 90), msg.Big) end
		drawHp()
	elseif k == "HeroUp" then
		bigBanner(("⚔️ Hero Level %d!  🌳 +1 skill point (K)"):format(msg.Lv or 1))
	elseif k == "Faint" then
		faint.Visible = true
		faint.BackgroundTransparency = 1
		tween(faint, 0.4, {BackgroundTransparency = 0.05})
		local s = faintIcon:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", faintIcon)
		s.Scale = 0.3
		tween(s, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
	elseif k == "Wake" then
		tween(faint, 0.5, {BackgroundTransparency = 1})
		task.delay(0.5, function() faint.Visible = false end)
		toast("❤️ All better! Be careful out there.")
	elseif k == "PetZap" then
		local from = msg.From
		if from and from.Parent and msg.Model and msg.Model.Parent then
			local p = from:GetPivot().Position + Vector3.new(0, 1, 0)
			bolt(p, msg.Model, Color3.fromRGB(150, 230, 255))
		end
	elseif k == "Bolt" then
		local from = msg.From and msg.From.Character
		local h = from and from:FindFirstChild("HumanoidRootPart")
		if h and msg.Model and msg.Model.Parent then bolt(h.Position + Vector3.new(0, 1.5, 0), msg.Model, msg.Color or K.YELLOW, false, msg.Style) end
	elseif k == "Hops" then -- 🔀 bouncy bolts / ➰ double shots hop from mob to mob
		for i, hop in msg.List or {} do
			task.delay(0.12 * i, function()
				if hop.From and hop.From.Parent and hop.Model and hop.Model.Parent then
					bolt(mobCenter(hop.From), hop.Model, msg.Color or K.YELLOW, false, msg.Style)
				end
			end)
		end
	end
end)

---------------------------------------------------------------- ⚔️ Weapons menu
local win = K.window(gui, {Icon = "⚔️", Title = "Weapons", Max = Vector2.new(900, 600)})
local tab = "Mine"
local info
local render

local function weaponArt(pic, name, shiny)
	local tpl = WEAPONS and WEAPONS:FindFirstChild(name)
	if tpl and tpl:IsA("Model") then
		local ok, vf = pcall(CritterUI.ModelView, pic, tpl, {Size = UDim2.fromScale(1, 1), ZIndex = pic.ZIndex + 1}, {Yaw = math.rad(30)})
		if ok and vf then
			if shiny then vf.ImageColor3 = Color3.fromRGB(255, 235, 250) end
			return vf
		end
	end
	local def = Data.WeaponByName[name]
	K.text(pic, {Text = def and def.Icon or "⚔️", Size = UDim2.fromScale(1, 1), Max = 54})
end

local function oddsText(cap)
	local total = 0
	for _, w in cap.Weights do total += w end
	local parts = {}
	for _, r in Data.WeaponRarities do
		local w = cap.Weights[r.Name]
		if w and w > 0 then
			local pct = w / total * 100
			table.insert(parts, pct >= 1 and ("%s %d%%"):format(r.Name, math.floor(pct + 0.5)) or ("%s 1 in %d"):format(r.Name, math.floor(100 / pct + 0.5)))
		end
	end
	return table.concat(parts, " · ")
end

local overlay = K.frame(gui, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 70, Visible = false})
local function reveal(res)
	local def = Data.WeaponByName[res.Name]
	local cap = Data.Capsules[res.Capsule] or Data.Capsules.Basic
	local badges = {}
	if res.Shiny then table.insert(badges, "✨ Shiny") end
	if res.New then table.insert(badges, "🆕 New!") end
	if res.Up then table.insert(badges, "⭐ +1 star") end
	if res.Coins then table.insert(badges, "💰 +" .. res.Coins) end
	local footer = res.Equipped and ("⚔️ Equipped! It's stronger than your %s"):format(res.Was or "old weapon")
		or (res.Up and ("⭐ Your %s got a star! (%d/%d)"):format(def.Display, res.Stars, Data.WeaponMaxStars))
		or (res.Coins and "⭐ Already maxed, so you got coins!") or nil
	overlay.Visible = true
	win.frame.Visible = false
	PackOpen.Play(overlay, {Style = "Pack", Icon = cap.Icon, Title = cap.Name, Color = cap.Color, Footer = footer, Cards = {{
		Rarity = res.Rarity, Color = RARITY[res.Rarity] and RARITY[res.Rarity].Color, Name = (res.Shiny and "✨ " or "") .. def.Display,
		Sub = ("💥 %d-%d"):format(Data.WeaponRange({Name = res.Name, Stars = res.Stars or 0, Shiny = res.Shiny})) .. " · " .. (STYLE_WORD[def.Style] or "🔨 Melee"),
		Odds = res.Odds, Badges = badges,
		Art = function(f, z)
			local tpl = WEAPONS and WEAPONS:FindFirstChild(res.Name)
			if tpl and tpl:IsA("Model") then
				local vf = CritterUI.ModelView(f, tpl, {Size = UDim2.fromScale(1, 1), ZIndex = z}, {Yaw = math.rad(30)})
				pcall(CritterUI.Animate, vf, "spin")
			else
				K.text(f, {Text = def.Icon, Size = UDim2.fromScale(1, 1), ZIndex = z, Max = 80})
			end
		end}}})
	overlay.Visible = false
	win.open()
	info = act("WeaponInfo")
	render()
end

function render()
	if not info then return end
	win.clear()
	local body = win.body
	local nCaps = 0
	for _, v in info.Capsules or {} do nCaps += v end
	win.setTabs({{"Mine", "⚔️ My weapons"}, {"Caps", "🎁 Capsules", nil, nCaps > 0 and nCaps or nil}}, tab, function(t) tab = t render() end)
	win.setHelp({{"⚔️", "Tap or click to attack mobs in the wild lands. Magic shoots, melee bonks up close!"},
		{"🎁", "Open capsules for new weapons. Mobs, bosses and chests drop them. Rarer = stronger!"},
		{"💥", "Each hit does damage in the weapon's range, like 66-78."},
		{"⭐", "Got one you have? It gains a star: the 💥 range goes up 10%. ✨ Shiny ones are +50%!"}})
	if tab == "Mine" then
		local list = info.Weapons or {}
		table.sort(list, function(a, b) return a.Power > b.Power end)
		local on
		for _, w in list do if w.Id == info.On then on = w end end
		if on then
			local def = Data.WeaponByName[on.Name]
			local lo, hi = Data.WeaponRange(on)
			win.setSub(("In your hand: %s %s · 💥 %d-%d"):format(def.Icon, def.Display, lo, hi))
		end
		local g = K.grid(body, UDim2.fromOffset(160, 210), 1)
		for i, w in list do
			local def = Data.WeaponByName[w.Name]
			if def then
				local r = RARITY[def.Rarity]
				local isOn = w.Id == info.On
				local lo, hi = Data.WeaponRange(w)
				K.card(g, {Order = i, Name = (w.Shiny and "✨ " or "") .. def.Display, Color = r.Color,
					Sub = ("%s · 💥 %d-%d %s"):format(def.Rarity, lo, hi, (w.Stars or 0) > 0 and string.rep("⭐", w.Stars) or ""),
					Art = function(pic) weaponArt(pic, w.Name, w.Shiny) end,
					Button = isOn and {Text = "✅ Holding", Kind = "special"} or {Text = "Equip", Kind = "go"},
					Fn = function()
						if isOn then return end
						local res = act("WeaponEquip", w.Id)
						if type(res) == "string" then toast(res, false) return end
						toast(("⚔️ %s %s in hand!"):format(def.Icon, def.Display))
						info = act("WeaponInfo")
						render()
					end,
					Tip = def.Icon .. " " .. def.Display, TipText = ("%s weapon · %s · attack every %.2fs"):format(STYLE_WORD[def.Style] or "🔨 Melee",
						def.Style ~= "Melee" and ("reaches %d studs"):format(def.Range) or "hits up to 3 mobs in front", def.Cd)})
			end
		end
	else
		win.setSub("Open capsules for a surprise weapon!")
		for i, kind in Data.CapsuleOrder do
			local cap = Data.Capsules[kind]
			local n = info.Capsules and info.Capsules[kind] or 0
			local btn, fn
			if n > 0 then
				btn, fn = {Text = ("🎁 Open (x%d)"):format(n), Kind = "go"}, function()
					local res = act("CapsuleOpen", kind)
					if type(res) == "string" then toast(res, false) return end
					reveal(res.Result)
				end
			elseif cap.Price then
				btn, fn = {Text = "💰 " .. cap.Price, Kind = "special"}, function()
					local res = act("CapsuleBuy")
					if type(res) == "string" then toast(res, false) return end
					reveal(res.Result)
				end
			else
				btn, fn = {Text = "🔎 Find it", Kind = "no"}, function()
					toast(("%s Beat mobs and bosses or open chests in the %s to find these!"):format(cap.Icon, kind), false)
				end
			end
			K.row(body, {Order = i, Icon = cap.Icon, Title = cap.Name .. (n > 0 and ("  ×%d"):format(n) or ""), Sub = oddsText(cap), Button = btn, Fn = fn})
		end
	end
end

local function openWeapons()
	info = act("WeaponInfo")
	if type(info) ~= "table" then return end
	win.open()
	render()
end
-- (key G and the dock open the 🛡️ Gear window, StarterPlayerScripts.HeroGear; its ⚔️ Main hand slot opens this one)
bridge.Event:Connect(function(cmd)
	if cmd == "Weapons" then openWeapons()
	elseif cmd == "Capsules" then tab = "Caps" openWeapons() -- (the 🎁 button in the Gear window Weapon tab)
	elseif cmd == "WeaponsClose" and win.frame.Visible then win.close() end
end)
