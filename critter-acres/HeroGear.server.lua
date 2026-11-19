-- Critter Acres: HeroGear (ServerScriptService)
-- 🛡️ What the PLAYER wears (pet gear is CraftServer / Data.Gear). Numbers + item list: Data.HeroSlots / HeroGear / HeroSets.
--   7 slots: Head, Body, Cape, Legs, Boots, MainHand (= your weapon, Combat keeps prof.WeaponOn), OffHand (shields).
--   prof.HeroGear = {{Id, Name, Stars}}, prof.HeroGearNext, prof.HeroGearOn = {[slot] = Id}
--   prof.Cosmetics = {[name] = true} (👗 looks you own), prof.CosmeticOn = {[slot] = name}
-- Every piece adds ⚡ power + its slot bonus. Combat reads the total through API.heroGearStats(player):
--   {Pwr = flat ⚡, PwrPct = set bonus %, HP = +% max HP, Def = % less hurt, Spd = % walk speed (lands), Glow = Color3 or nil}
-- 🔨 Leaf / Stone / Iron are crafted at the plaza Workbench (GearCraft, CritterWorld Workbench window, near the table only). Boss-tier pieces only come from bosses (API.heroGearDrop + Combat stars).
-- 🎨 What you wear SHOWS on your character: part-built pieces welded on (folder "HeroGearLook"). ⚔️ Your weapon hangs on
--   your back (folder "WeaponBack") whenever it's not in your hand. A 👗 look in a slot
--   beats the gear's own look (cosmetics). MainHand looks swap the weapon's model (API.weaponSkin, read by Combat).
-- Actions (CritterAction): GearInfo, GearEquip(id), GearOff(slot), GearCraft(name), LookWear(slot, name or "").
-- Client: StarterPlayerScripts.HeroGear (the 🛡️ Gear window, key G).
local Players = game:GetService("Players")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local Data, ACTIONS = API.Data, API.ACTIONS

---------------------------------------------------------------- your gear in the profile
local function ensure(prof)
	prof.HeroGear = prof.HeroGear or {}
	prof.HeroGearNext = prof.HeroGearNext or (#prof.HeroGear + 1)
	prof.HeroGearOn = prof.HeroGearOn or {}
	prof.Cosmetics = prof.Cosmetics or {}
	prof.CosmeticOn = prof.CosmeticOn or {}
end
local function entry(prof, id)
	for _, g in prof.HeroGear do
		if g.Id == id then return g end
	end
end
local function wornIn(prof, slot) -- the piece in a slot (nil if empty or broken)
	local g = entry(prof, prof.HeroGearOn[slot])
	local def = g and Data.HeroGearByName[g.Name]
	if def and def.Slot == slot then return g, def end
	prof.HeroGearOn[slot] = nil
	return nil
end
local function lookIn(prof, slot) -- the 👗 look shown in a slot (nil = show the gear)
	local name = prof.CosmeticOn[slot]
	local c = name and Data.HeroCosmeticByName[name]
	if c and c.Slot == slot and prof.Cosmetics[name] then return c end
	prof.CosmeticOn[slot] = nil
	return nil
end

---------------------------------------------------------------- the numbers
local ZERO = {Pwr = 0, PwrPct = 0, HP = 0, Def = 0, Spd = 0}
local stats = {} -- player -> last totals
local function calc(prof)
	ensure(prof)
	local st = {Pwr = 0, PwrPct = 0, HP = 0, Def = 0, Spd = 0, Sets = {}}
	for _, s in Data.HeroSlots do
		if s.Id ~= "MainHand" then
			local g, def = wornIn(prof, s.Id)
			if g then
				local one = Data.HeroGearStats(g)
				st.Pwr += one.Pwr
				st.HP += one.HP
				st.Def += one.Def
				st.Spd += one.Spd
				if def.Set then st.Sets[def.Set] = (st.Sets[def.Set] or 0) + 1 end
			end
		end
	end
	-- 🏆 set bonuses: every named step you reach adds up. A Weapon step also needs the set's weapon in your hand.
	local held
	for _, w in prof.Weapons or {} do
		if w.Id == prof.WeaponOn then held = w.Name end
	end
	local heldSet = held and Data.HeroSetOfWeapon and Data.HeroSetOfWeapon(held)
	if heldSet then st.Sets[heldSet] = st.Sets[heldSet] or 0 end -- (a weapon step can need 0 armor pieces)
	st.Steps, st.HeldSet = {}, heldSet
	for set, n in st.Sets do
		local sd = Data.HeroSets[set]
		for _, step in sd and sd.Steps or {} do
			if n >= (step.Pieces or 0) and (not step.Weapon or heldSet == set) then
				st.PwrPct += step.Pwr or 0
				st.HP += step.HP or 0
				st.Def += step.Def or 0
				st.Spd += step.Spd or 0
				if step.Glow then st.Glow = sd.Glow end
				st.Steps[set .. "|" .. step.Name] = true
			end
		end
	end
	st.Def = math.min(Data.HeroDefCap, st.Def)
	return st
end
API.heroGearStats = function(player)
	local st = stats[player]
	if st then return st end
	local prof = API.profiles[player]
	if not prof then return ZERO end
	st = calc(prof)
	stats[player] = st
	return st
end

-- 🗡️ a main-hand look (weapon skin): the WeaponModels name to use instead of the weapon's own model
API.weaponSkin = function(player)
	local prof = API.profiles[player]
	if not prof then return nil end
	ensure(prof)
	local c = lookIn(prof, "MainHand")
	return c and c.Model or nil
end

---------------------------------------------------------------- 🎨 the pieces on your character
local function partOf(char, ...)
	for _, n in {...} do
		local p = char:FindFirstChild(n)
		if p and p:IsA("BasePart") then return p end
	end
end
local MAT = {}
for _, m in Enum.Material:GetEnumItems() do MAT[m.Name] = m end

-- one piece of armor stuck to a body part. kind = "Box" / "Egg" (stretched ball) / "Ball" / "Disc" (cylinder along X)
local function piece(folder, base, kind, size, offset, color, look, props)
	local p = Instance.new("Part")
	p.Name = "Piece"
	p.Size = size
	p.Color = color
	p.Material = MAT[look.Material or "SmoothPlastic"] or Enum.Material.SmoothPlastic
	p.Reflectance = look.Shine or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, false, true
	p.CastShadow = false
	if kind == "Egg" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif kind == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif kind == "Disc" then
		p.Shape = Enum.PartType.Cylinder
	end
	for k, v in props or {} do p[k] = v end
	if look.Material == "Glass" and not (props and props.Transparency) then p.Transparency = 0.15 end
	p.CFrame = base.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = base, p, offset
	w.Parent = p
	p.Parent = folder
	return p
end
-- the accent color part: glowing (Neon) for Crystal / Magma looks
local function accent(folder, base, kind, size, offset, look)
	local p = piece(folder, base, kind, size, offset, look.Accent, look, {Material = look.Glow and Enum.Material.Neon or (MAT[look.Material] or Enum.Material.SmoothPlastic), Transparency = 0})
	return p
end
local function embers(p, color)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.Size = NumberSequence.new(0.25, 0)
	pe.Rate, pe.Lifetime, pe.Speed = 6, NumberRange.new(0.5, 0.9), NumberRange.new(0.5, 1.2)
	pe.LightEmission = 1
	pe.Parent = p
end
local function leaf(folder, base, offset, s)
	piece(folder, base, "Egg", Vector3.new(0.12, 0.45, 0.3) * s, offset, Color3.fromRGB(90, 185, 70), {Material = "Grass"})
end

local BUILD = {}
function BUILD.Head(folder, char, look)
	local head = partOf(char, "Head")
	if not head then return end
	local h = math.max(1, head.Size.Y)
	-- a round dome over the top (pushed back a little so the face stays clear) and a band around it
	piece(folder, head, "Egg", Vector3.new(h * 1.2, h * 0.8, h * 1.2), CFrame.new(0, h * 0.38, h * 0.06), look.Color, look)
	accent(folder, head, "Disc", Vector3.new(h * 0.12, h * 1.16, h * 1.16), CFrame.new(0, h * 0.2, h * 0.04) * CFrame.Angles(0, 0, math.pi / 2), look)
	if look.Extra == "Leaf" then
		leaf(folder, head, CFrame.new(0, h * 0.85, 0) * CFrame.Angles(0, 0, math.rad(20)), h * 1.4)
	elseif look.Extra == "Gem" then
		accent(folder, head, "Ball", Vector3.one * h * 0.24, CFrame.new(0, h * 0.24, -h * 0.55), look)
	elseif look.Extra == "Ears" then
		for _, sx in {-1, 1} do
			piece(folder, head, "Egg", Vector3.new(h * 0.24, h * 0.75, h * 0.14), CFrame.new(sx * h * 0.24, h * 0.95, h * 0.05) * CFrame.Angles(0, 0, sx * math.rad(-12)), look.Color, look)
			piece(folder, head, "Egg", Vector3.new(h * 0.13, h * 0.55, h * 0.06), CFrame.new(sx * h * 0.24, h * 0.95, -h * 0.02) * CFrame.Angles(0, 0, sx * math.rad(-12)), look.Accent, look)
		end
	elseif look.Extra == "Flame" then
		local top = accent(folder, head, "Egg", Vector3.new(h * 0.3, h * 0.4, h * 0.3), CFrame.new(0, h * 0.82, 0), look)
		embers(top, look.Accent)
	end
end
function BUILD.Body(folder, char, look)
	local up = partOf(char, "UpperTorso", "Torso")
	if not up then return end
	local t = up.Size
	local tall = up.Name == "Torso" and 0.55 or 0.85 -- (R6 torso is one long part)
	piece(folder, up, "Box", Vector3.new(t.X * 1.08, t.Y * tall, t.Z * 1.25), CFrame.new(0, t.Y * (1 - tall) * 0.5, 0), look.Color, look)
	local em = accent(folder, up, "Egg", Vector3.new(t.X * 0.4, t.Y * 0.38, t.Z * 0.2), CFrame.new(0, t.Y * 0.1, -t.Z * 0.62), look)
	if look.Extra == "Leaf" then leaf(folder, up, CFrame.new(t.X * 0.25, t.Y * 0.3, -t.Z * 0.66) * CFrame.Angles(math.rad(-90), 0, math.rad(30)), t.Y * 0.8) end
	if look.Extra == "Flame" then embers(em, look.Accent) end
	-- round shoulder pads ride on the arms
	for _, n in {{"LeftUpperArm", "Left Arm"}, {"RightUpperArm", "Right Arm"}} do
		local arm = partOf(char, n[1], n[2])
		if arm then
			local a = arm.Size
			piece(folder, arm, "Egg", Vector3.new(a.X * 1.55, math.min(a.Y, 1.2) * 0.55, a.Z * 1.55), CFrame.new(0, a.Y * 0.38, 0), look.Color, look)
		end
	end
	local low = partOf(char, "LowerTorso")
	if low then
		local l = low.Size
		accent(folder, low, "Box", Vector3.new(l.X * 1.1, l.Y * 0.45, l.Z * 1.3), CFrame.new(0, l.Y * 0.15, 0), look)
	end
end
function BUILD.Legs(folder, char, look)
	for _, n in {{"LeftUpperLeg", "Left Leg"}, {"RightUpperLeg", "Right Leg"}} do
		local leg = partOf(char, n[1], n[2])
		if leg then
			local u = leg.Size
			local r6 = leg.Name:find(" ") ~= nil
			piece(folder, leg, "Box", Vector3.new(u.X * 1.18, u.Y * (r6 and 0.4 or 0.85), u.Z * 1.18), CFrame.new(0, r6 and u.Y * 0.28 or u.Y * 0.05, 0), look.Color, look)
			local lowName = n[1]:gsub("Upper", "Lower")
			local low = partOf(char, lowName)
			local base, s = low or leg, (low or leg).Size
			accent(folder, base, "Egg", Vector3.new(s.X * 0.75, s.X * 0.6, s.Z * 0.45), CFrame.new(0, low and s.Y * 0.32 or 0, -s.Z * 0.5), look)
		end
	end
end
function BUILD.Boots(folder, char, look)
	for _, side in {"Left", "Right"} do
		local foot = partOf(char, side .. "Foot")
		local low = partOf(char, side .. "LowerLeg")
		if foot and low then
			local f, l = foot.Size, low.Size
			piece(folder, foot, "Box", Vector3.new(f.X * 1.25, f.Y * 1.5, f.Z * 1.22), CFrame.new(0, f.Y * 0.2, -f.Z * 0.04), look.Color, look)
			local cuff = accent(folder, low, "Box", Vector3.new(l.X * 1.28, l.Y * 0.32, l.Z * 1.28), CFrame.new(0, -l.Y * 0.28, 0), look)
			if look.Extra == "Flame" then embers(cuff, look.Accent) end
		else -- (R6) one boot on the bottom of each leg
			local leg = partOf(char, side .. " Leg")
			if leg then
				local s = leg.Size
				piece(folder, leg, "Box", Vector3.new(s.X * 1.2, s.Y * 0.35, s.Z * 1.25), CFrame.new(0, -s.Y * 0.34, -s.Z * 0.05), look.Color, look)
			end
		end
	end
end
function BUILD.Cape(folder, char, look)
	local up = partOf(char, "UpperTorso", "Torso")
	if not up then return end
	local t = up.Size
	local r6 = up.Name == "Torso"
	local long = t.Y * (r6 and 1.45 or 1.95) -- down to about the knees
	local top = t.Y * (r6 and 0.42 or 0.4)
	local back = t.Z * 0.66 + 0.08 -- just behind the body armor (characters face -Z, so the back is +Z)
	-- the cape hangs from the shoulders and flares out a little at the bottom
	local hang = CFrame.new(0, top, back) * CFrame.Angles(math.rad(-9), 0, 0)
	piece(folder, up, "Box", Vector3.new(t.X * 1.05, long, 0.12), hang * CFrame.new(0, -long * 0.5, 0), look.Color, look)
	-- a hem stripe at the bottom (accent color)
	local hem = accent(folder, up, "Box", Vector3.new(t.X * 1.07, long * 0.08, 0.14), hang * CFrame.new(0, -long * 0.94, 0), look)
	-- a collar over the shoulders and a round clasp in front
	accent(folder, up, "Box", Vector3.new(t.X * 1.1, t.Y * 0.14, t.Z * 0.45), CFrame.new(0, top - t.Y * 0.02, t.Z * 0.42), look)
	accent(folder, up, "Ball", Vector3.one * t.X * 0.16, CFrame.new(0, top - t.Y * 0.1, -t.Z * 0.58), look)
	if look.Extra == "Leaf" then leaf(folder, up, hang * CFrame.new(t.X * 0.3, -long * 0.12, 0.08) * CFrame.Angles(math.rad(90), 0, math.rad(-25)), t.Y * 0.8) end
	if look.Extra == "Gem" then accent(folder, up, "Ball", Vector3.one * t.X * 0.2, hang * CFrame.new(0, -long * 0.35, 0.08), look) end
	if look.Extra == "Flame" then embers(hem, look.Accent) end
end
function BUILD.OffHand(folder, char, look)
	local arm = partOf(char, "LeftLowerArm", "Left Arm")
	if not arm then return end
	local a = arm.Size
	local d = math.clamp(a.Y * 2.2, 1.8, 2.6)
	local out = -(a.X * 0.5 + 0.12)
	-- a round shield on the outside of the left arm (its flat face points out to the side)
	piece(folder, arm, "Disc", Vector3.new(0.22, d, d), CFrame.new(out, -a.Y * 0.1, 0), look.Color, look)
	accent(folder, arm, "Disc", Vector3.new(0.18, d * 1.1, d * 1.1), CFrame.new(out + 0.05, -a.Y * 0.1, 0), look)
	local boss = accent(folder, arm, "Ball", Vector3.one * d * 0.3, CFrame.new(out - 0.12, -a.Y * 0.1, 0), look)
	if look.Extra == "Leaf" then leaf(folder, arm, CFrame.new(out - 0.14, -a.Y * 0.1 + d * 0.22, 0) * CFrame.Angles(0, 0, math.rad(90)), d * 0.8) end
	if look.Extra == "Flame" then embers(boss, look.Accent) end
	if look == Data.HeroLooks.Candy then -- 🍬 swirl stripes
		for i = -1, 1, 2 do
			piece(folder, arm, "Box", Vector3.new(0.05, d * 0.12, d * 0.8), CFrame.new(out - 0.12, -a.Y * 0.1 + i * d * 0.22, 0), Color3.new(1, 1, 1), look)
		end
	end
end

-- hats / hair tuck away under a helmet (and come back when it comes off)
local HAT_ATT = {HatAttachment = true, HairAttachment = true}
local function tuckHats(char, hide)
	for _, acc in char:GetChildren() do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle")
			local hat = acc.AccessoryType == Enum.AccessoryType.Hat or acc.AccessoryType == Enum.AccessoryType.Hair
			if not hat and handle then
				for _, att in handle:GetChildren() do
					if att:IsA("Attachment") and HAT_ATT[att.Name] then hat = true end
				end
			end
			if hat and handle and handle:IsA("BasePart") then
				if hide then
					if handle:GetAttribute("HGWas") == nil then handle:SetAttribute("HGWas", handle.Transparency) end
					handle.Transparency = 1
				elseif handle:GetAttribute("HGWas") ~= nil then
					handle.Transparency = handle:GetAttribute("HGWas")
					handle:SetAttribute("HGWas", nil)
				end
			end
		end
	end
end

local function undress(char)
	local f = char and char:FindFirstChild("HeroGearLook")
	if f then
		local ref = f:FindFirstChild("GlowRef")
		if ref and ref.Value then ref.Value:Destroy() end
		f:Destroy()
	end
end
local function dress(player)
	local prof = API.profiles[player]
	local char = player.Character
	if not prof or not char or not char:FindFirstChildOfClass("Humanoid") then return end
	ensure(prof)
	undress(char)
	local folder = Instance.new("Folder")
	folder.Name = "HeroGearLook"
	local headShown = false
	for slot, build in BUILD do
		local cos = lookIn(prof, slot)
		local _, def = wornIn(prof, slot)
		local look = Data.HeroLooks[(cos and cos.Look) or (def and def.Look) or ""]
		if look then
			local ok, err = pcall(build, folder, char, look)
			if not ok then warn("[HeroGear] " .. slot .. ": " .. tostring(err)) end
			if slot == "Head" then headShown = true end
		end
	end
	-- 🏆 a full set (4 pieces) makes you sparkle
	local st = API.heroGearStats(player)
	local up = partOf(char, "UpperTorso", "Torso")
	if st.Glow and up then
		local holder = Instance.new("Attachment")
		holder.Name = "SetGlow"
		holder.Parent = up
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(st.Glow)
		pe.Size = NumberSequence.new(0.4, 0)
		pe.Rate, pe.Lifetime, pe.Speed = 7, NumberRange.new(0.8, 1.2), NumberRange.new(0.4, 1)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.LightEmission = 1
		pe.Parent = holder
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = st.Glow, 8, 0.8
		light.Parent = holder
		local tag = Instance.new("ObjectValue") -- (so the next dress removes the glow too)
		tag.Name = "GlowRef"
		tag.Value = holder
		tag.Parent = folder
	end
	folder.Parent = char
	tuckHats(char, headShown)
end
local slingWeapon -- (below)
local function redress(player)
	local ok, err = pcall(dress, player)
	if not ok then warn("[HeroGear] dress: " .. tostring(err)) end
	if player.Character and slingWeapon then
		ok, err = pcall(slingWeapon, player, player.Character)
		if not ok then warn("[HeroGear] weapon on back: " .. tostring(err)) end
	end
end

-- numbers changed: PWR / HP / speed follow, and the character re-dresses
local function refresh(player)
	local prof = API.profiles[player]
	if not prof then return end
	stats[player] = calc(prof)
	if API.skillPush then pcall(API.skillPush, player) elseif API.combatRefreshPwr then pcall(API.combatRefreshPwr, player) end
	redress(player)
end

---------------------------------------------------------------- getting gear
-- add a piece: new, +1 ⭐, or coins when it's maxed. A new piece goes on if the slot is empty or it's stronger.
local function give(player, name)
	local prof = API.profiles[player]
	local def = Data.HeroGearByName[name or ""]
	if not prof or not def then return nil end
	ensure(prof)
	for _, g in prof.HeroGear do
		if g.Name == name then
			if (g.Stars or 0) < Data.HeroGearMaxStars then
				g.Stars = (g.Stars or 0) + 1
				if prof.HeroGearOn[def.Slot] == g.Id then refresh(player) end
				return {Id = g.Id, Name = name, Stars = g.Stars, Up = true}
			end
			local coins = Data.HeroGearMaxedCoins[def.Rarity] or 20
			API.addCoins(player, coins)
			return {Id = g.Id, Name = name, Stars = g.Stars, Coins = coins}
		end
	end
	local g = {Id = prof.HeroGearNext, Name = name, Stars = 0}
	prof.HeroGearNext += 1
	table.insert(prof.HeroGear, g)
	local cur = wornIn(prof, def.Slot)
	local res = {Id = g.Id, Name = name, Stars = 0, New = true}
	if not cur or Data.HeroGearStats(g).Pwr > Data.HeroGearStats(cur).Pwr then
		prof.HeroGearOn[def.Slot] = g.Id
		res.Equipped = true
		refresh(player)
	end
	return res
end
API.giveHeroGear = give
API.heroGearRefresh = refresh -- (Combat: the weapon in your hand changed, a set's weapon step may turn on / off)
-- 🏰 a dungeon boss may also drop its set's weapon (nil = not this time)
API.heroSetWeaponDrop = function(land)
	local set = Data.HeroGearDrop.DungeonSet and Data.HeroGearDrop.DungeonSet[land]
	local sd = set and Data.HeroSets[set]
	if not sd or not sd.Weapon or not Data.WeaponByName[sd.Weapon] then return nil end
	if math.random() >= (Data.HeroGearDrop.SetWeapon or 0) then return nil end
	return sd.Weapon
end

-- 🏆 a boss went down: maybe a boss-tier piece (nil = nothing this time)
API.heroGearDrop = function(land, dungeon)
	local chance = dungeon and Data.HeroGearDrop.Dungeon or Data.HeroGearDrop.Boss
	if math.random() >= chance then return nil end
	local src = dungeon and "Dungeons" or "Lands"
	-- 🧭 pieces ticked for there: a dungeon boss prefers its own set, a land boss the tiers of its land
	local want = {}
	if dungeon then
		local own = Data.HeroGearDrop.DungeonSet and Data.HeroGearDrop.DungeonSet[land]
		local pool = {}
		for _, def in Data.HeroGear do
			if def.Set == own and Data.FromHas(def, src) then table.insert(pool, def.Name) end
		end
		if #pool > 0 then return pool[math.random(#pool)] end
	else
		for _, t in Data.HeroGearDrop.Lands[land] or Data.HeroGearDrop.Lands.Meadow do want[t] = true end
		local pool = {}
		for _, def in Data.HeroGear do
			if want[def.Tier] and Data.FromHas(def, src) then table.insert(pool, def.Name) end
		end
		if #pool > 0 then return pool[math.random(#pool)] end
	end
	local pool = {} -- (nothing matched: any piece ticked for there)
	for _, def in Data.HeroGear do
		if Data.FromHas(def, src) then table.insert(pool, def.Name) end
	end
	return #pool > 0 and pool[math.random(#pool)] or nil
end

---------------------------------------------------------------- actions (the 🛡️ Gear window)
local function coinsOf(player)
	local c = API.coinsOf and API.coinsOf(player)
	return typeof(c) == "Instance" and c.Value or tonumber(c) or 0
end
local function info(player, prof)
	ensure(prof)
	local items = {}
	for _, g in prof.HeroGear do
		if Data.HeroGearByName[g.Name] then
			local st = Data.HeroGearStats(g)
			table.insert(items, {Id = g.Id, Name = g.Name, Stars = g.Stars or 0, Pwr = st.Pwr, Text = Data.HeroGearText(st)})
		end
	end
	local on = {}
	for _, s in Data.HeroSlots do
		local g = s.Id ~= "MainHand" and wornIn(prof, s.Id)
		if g then on[s.Id] = g.Id end
	end
	local looks = {}
	for name in prof.Cosmetics do
		if Data.HeroCosmeticByName[name] then table.insert(looks, name) end
	end
	local looksOn = {}
	for _, s in Data.HeroSlots do
		local c = lookIn(prof, s.Id)
		if c then looksOn[s.Id] = c.Name end
	end
	local st = API.heroGearStats(player)
	local sets = {}
	for set, n in st.Sets or {} do
		local sd = Data.HeroSets[set]
		local steps = {}
		for _, step in sd and sd.Steps or {} do
			table.insert(steps, {Name = step.Name, Pieces = step.Pieces or 0, Weapon = step.Weapon, Text = Data.HeroStepText(step),
				On = st.Steps and st.Steps[set .. "|" .. step.Name] or false})
		end
		table.insert(sets, {Set = set, N = n, Holding = st.HeldSet == set, Steps = steps})
	end
	local weapon, weapons = nil, {}
	for _, w in prof.Weapons or {} do
		local one = {Id = w.Id, Name = w.Name, Stars = w.Stars or 0, Shiny = w.Shiny, Power = Data.WeaponPower(w)}
		table.insert(weapons, one)
		if w.Id == prof.WeaponOn then weapon = one end
	end
	return {Items = items, On = on, Looks = looks, LooksOn = looksOn, Weapon = weapon, Weapons = weapons, WeaponOn = prof.WeaponOn, Res = prof.Res, Coins = coinsOf(player),
		Stats = {Pwr = st.Pwr, PwrPct = st.PwrPct, HP = st.HP, Def = st.Def, Spd = st.Spd}, Sets = sets, PWR = player:GetAttribute("PWR")}
end
function ACTIONS.GearInfo(player, prof)
	return info(player, prof)
end
function ACTIONS.GearEquip(player, prof, id)
	ensure(prof)
	local g = entry(prof, id)
	local def = g and Data.HeroGearByName[g.Name]
	if not def then return "❔" end
	prof.HeroGearOn[def.Slot] = g.Id
	refresh(player)
	return info(player, prof)
end
function ACTIONS.GearOff(player, prof, slot)
	ensure(prof)
	if type(slot) ~= "string" or not Data.HeroSlotById[slot] or slot == "MainHand" then return "❔" end
	prof.HeroGearOn[slot] = nil
	refresh(player)
	return info(player, prof)
end
function ACTIONS.GearCraft(player, prof, name)
	ensure(prof)
	local def = Data.HeroGearByName[name or ""]
	local cost = def and Data.HeroCraftCost(def)
	if not cost then return "🏆 This one only drops from bosses!" end
	-- 🔨 only at the Workbench in the plaza (never from the Gear window)
	local wb = API.root and API.root:FindFirstChild("Workbench")
	local tbl = wb and wb:FindFirstChild("Table")
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if tbl and tbl:IsA("BasePart") and (not hrp or (hrp.Position - tbl.Position).Magnitude > Data.HeroCraftReach) then
		return "🔨 Make gear at the Workbench in the plaza!"
	end
	for _, g in prof.HeroGear do
		if g.Name == name and (g.Stars or 0) >= Data.HeroGearMaxStars then return ("⭐ Your %s is already maxed!"):format(def.Display) end
	end
	local ok, missing = API.pay(player, prof, cost)
	if not ok then return "🔨 Need more " .. tostring(missing) end
	if API.questEvent then pcall(API.questEvent, player, "Craft", 1) end
	local res = give(player, name)
	return {Result = res, Info = info(player, prof)}
end
function ACTIONS.LookWear(player, prof, slot, name)
	ensure(prof)
	if type(slot) ~= "string" or not Data.HeroSlotById[slot] then return "❔" end
	if name == nil or name == "" then
		prof.CosmeticOn[slot] = nil
	else
		local c = Data.HeroCosmeticByName[name]
		if not c or c.Slot ~= slot or not prof.Cosmetics[name] then return "❔" end
		prof.CosmeticOn[slot] = name
	end
	redress(player)
	if slot == "MainHand" and API.combatGiveTool then pcall(API.combatGiveTool, player) end
	return info(player, prof)
end

---------------------------------------------------------------- players
local BODY = {Head = true, UpperTorso = true, LowerTorso = true, Torso = true, LeftUpperArm = true, RightUpperArm = true, LeftLowerArm = true,
	LeftUpperLeg = true, RightUpperLeg = true, LeftLowerLeg = true, RightLowerLeg = true, LeftFoot = true, RightFoot = true,
	["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true}
-- ⚔️ your weapon on your back whenever it's NOT in your hand (town, farm, or put away in the lands).
-- A copy of the weapon Tool's Handle (Combat makes it, so 👗 weapon looks and ✨ shiny show too), in folder "WeaponBack".
function slingWeapon(player, char)
	local old = char:FindFirstChild("WeaponBack")
	if old then old:Destroy() end
	for _, t in char:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("Weapon") then return end -- held: it's in your hand already
	end
	local bp = player:FindFirstChildOfClass("Backpack")
	local tool
	for _, t in bp and bp:GetChildren() or {} do
		if t:IsA("Tool") and t:GetAttribute("Weapon") then tool = t end
	end
	local handle = tool and tool:FindFirstChild("Handle")
	local up = partOf(char, "UpperTorso", "Torso")
	if not handle or not handle:IsA("BasePart") or not up then return end
	local p = handle:Clone()
	p.Name = "Weapon"
	for _, d in p:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Attachment") or d:IsA("TouchTransmitter") or d:IsA("BaseScript") then d:Destroy() end
	end
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, false, true
	p.CastShadow = false
	-- across the back on a slant, past a cape if you wear one (characters face -Z, so the back is +Z)
	local t = up.Size
	local prof = API.profiles[player]
	local cape = prof and (wornIn(prof, "Cape") or lookIn(prof, "Cape"))
	local behind = t.Z * 0.5 + p.Size.Z * 0.5 + 0.2 + (cape and 0.3 or 0)
	local offset = CFrame.new(0, t.Y * 0.05, behind) * CFrame.Angles(0, 0, math.rad(40))
	local folder = Instance.new("Folder")
	folder.Name = "WeaponBack"
	p.CFrame = up.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = up, p, offset
	w.Parent = p
	p.Parent = folder
	folder.Parent = char
end
local function hookChar(player, char)
	-- the avatar's body parts get swapped in while it loads: dress again once they settle
	local pending, slingPending = false, false
	local function soon()
		if pending then return end
		pending = true
		task.delay(0.6, function()
			pending = false
			if player.Character == char and char.Parent then redress(player) end
		end)
	end
	local function slingSoon() -- (a tool moving between hand and backpack fires a few events: wait for it to settle)
		if slingPending then return end
		slingPending = true
		task.delay(0.15, function()
			slingPending = false
			if player.Character == char and char.Parent then
				local ok, err = pcall(slingWeapon, player, char)
				if not ok then warn("[HeroGear] weapon on back: " .. tostring(err)) end
			end
		end)
	end
	local function isWeapon(c) return c:IsA("Tool") and c:GetAttribute("Weapon") ~= nil end
	char.ChildAdded:Connect(function(c)
		if (c:IsA("BasePart") and BODY[c.Name]) or c:IsA("Accessory") then soon() slingSoon() end
		if isWeapon(c) then slingSoon() end
	end)
	char.ChildRemoved:Connect(function(c)
		if isWeapon(c) then slingSoon() end
	end)
	task.spawn(function()
		local bp = player:WaitForChild("Backpack", 10)
		if not bp or player.Character ~= char then return end
		bp.ChildAdded:Connect(function(c) if isWeapon(c) then slingSoon() end end)
		bp.ChildRemoved:Connect(function(c) if isWeapon(c) then slingSoon() end end)
		slingSoon()
	end)
	soon()
end
local function onPlayer(player)
	task.spawn(function()
		for _ = 1, 120 do
			if API.profiles[player] then break end
			task.wait(0.5)
		end
		local prof = API.profiles[player]
		if not prof then return end
		ensure(prof)
		stats[player] = calc(prof)
		if API.skillPush then pcall(API.skillPush, player) end
		player.CharacterAdded:Connect(function(char) hookChar(player, char) end)
		if player.Character then hookChar(player, player.Character) end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end
Players.PlayerRemoving:Connect(function(player) stats[player] = nil end)

---------------------------------------------------------------- Studio dev menu
API.DEV_EXTRA = API.DEV_EXTRA or {}
API.DEV_EXTRA.HeroGearAll = function(player) -- one of every piece
	for _, def in Data.HeroGear do give(player, def.Name) end
	return ("🛡️ +%d gear pieces (open G)"):format(#Data.HeroGear)
end
API.DEV_EXTRA.HeroGearBoss = function(player, prof, tier) -- a full boss set (Gold if no tier given)
	tier = tier or "Gold"
	ensure(prof)
	for _, def in Data.HeroGear do
		if def.Tier == tier then
			local res = give(player, def.Name)
			if res then prof.HeroGearOn[def.Slot] = res.Id end
		end
	end
	refresh(player)
	return ("%s %s set on!"):format(Data.HeroTierIcon[tier] or "🛡️", tier)
end
API.DEV_EXTRA.HeroLooks = function(player, prof) -- every 👗 look
	ensure(prof)
	for _, c in Data.HeroCosmetics do prof.Cosmetics[c.Name] = true end
	return ("👗 +%d looks (G > Looks)"):format(#Data.HeroCosmetics)
end
API.DEV_EXTRA.HeroGearReset = function(player, prof) -- take it all away
	prof.HeroGear, prof.HeroGearOn, prof.HeroGearNext, prof.CosmeticOn = {}, {}, 1, {}
	refresh(player)
	return "🛡️ Hero gear cleared"
end
