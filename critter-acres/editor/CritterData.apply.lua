-- 🛠 Critter Editor (critter-acres/editor): the CritterSync plugin writes the editor's JSON into the child
-- ModuleScript CritterData.GameData. When it is there, it REPLACES weapons, pets, eggs (+ egg shop tiers),
-- capsules, the skill numbers/texts, decorations (cost, icon, effect), 🛡️ hero gear (pieces, sets + named bonus steps, looks), ⚙️ gear numbers and 🏰 dungeon numbers. Everything is built first and only swapped in if it all worked,
-- so a bad file just leaves the Lua tables above in use (with a warning).
-- Deleted weapons/pets stay in WeaponByName/SpeciesByName (players may own them) but never drop/hatch again.
function Data.ApplyGameData(json)
	local G = game:GetService("HttpService"):JSONDecode(json)
	local function col(h) return type(h) == "string" and Color3.fromHex(h) or h end
	local new = {}

	if G.weapons then
		local list, by = {}, {}
		for name, w in Data.WeaponByName do by[name] = w end -- keep retired ones loadable
		for _, w in G.weapons do
			assert(type(w.Name) == "string" and w.Name ~= "", "weapon without Name")
			assert(Data.WeaponRarityByName[w.Rarity], "weapon " .. w.Name .. ": bad Rarity")
			w.Fx = col(w.Fx) or Color3.new(1, 1, 1)
			w.ModelFile = nil
			if type(w.From) ~= "table" then w.From = nil end -- (none = 🎁 capsules, Data.FixFrom)
			table.insert(list, w)
			by[w.Name] = w
		end
		new.Weapons, new.WeaponByName = list, by
	end

	if G.pets then
		local list, by = {}, {}
		for name, s in Data.SpeciesByName do
			local old = table.clone(s)
			old.Secret = true -- retired unless it is in the new list (still loads for owners, never hatches)
			by[name] = old
		end
		for i, s in G.pets do
			assert(type(s.Species) == "string" and s.Species ~= "", "pet without Species")
			assert(Data.Rarities[s.Rarity], "pet " .. s.Species .. ": bad Rarity")
			s.Color, s.Ear = col(s.Color) or Color3.new(1, 1, 1), col(s.Ear) or Color3.new(1, 1, 1)
			if type(s.Mutate) == "table" and s.Mutate.Name then s.Mutate = {s.Mutate.Name, s.Mutate.Chance or 0} else s.Mutate = nil end
			s.Index, s.Role = i, "Pet"
			s.Class = Data.Classes[s.Class] and s.Class or "Striker"
			s.ModelFile = nil
			table.insert(list, s)
			by[s.Species] = s
		end
		new.Species, new.SpeciesByName = list, by
	end

	if G.eggs then
		local eggs, tiers = {}, {}
		for id, e in Data.Eggs do eggs[id] = e end -- eggs other data points at never vanish
		for _, e in G.eggs do
			assert(type(e.Id) == "string" and e.Id ~= "", "egg without Id")
			local id, shop = e.Id, e.Shop
			e.Id, e.Shop = nil, nil
			e.Weights = e.Weights or {}
			eggs[id] = e
			if type(shop) == "table" and (shop.Chance or 0) > 0 then
				table.insert(tiers, {Egg = id, Chance = shop.Chance, Price = shop.Price or 0})
			end
		end
		new.Eggs, new.EggTiers = eggs, #tiers > 0 and tiers or nil
	end

	if G.capsules then
		local caps = table.clone(Data.Capsules)
		for _, c in G.capsules do
			assert(type(c.Id) == "string" and caps[c.Id], "unknown capsule " .. tostring(c.Id))
			local id = c.Id
			c.Id, c.Color = nil, col(c.Color)
			caps[id] = c
		end
		new.Capsules = caps
	end

	if G.skills then
		local skills = table.clone(Data.Skills)
		local function sayFn(s, tpl)
			return function(r)
				return (tpl:gsub("{(%a+)(%%?)([%+%-]?%d*%.?%d*)}", function(name, pc, add)
					local v
					if name == "r" then v = r
					elseif name == "Per" then v = (s.Per or 0) * r
					elseif type(s[name]) == "function" then v = s[name](r)
					else v = tonumber(s[name]) or 0 end
					local dec = 0
					local a, d = add:match("^([%+%-]?%d*)%.?(%d*)$")
					if pc == "%" then v = math.floor(v * 100 + 0.5) end
					if a and a ~= "" and a ~= "+" and a ~= "-" then v += tonumber(a) end
					if d and d ~= "" then dec = tonumber(d) end
					if dec > 0 then return ("%." .. dec .. "f"):format(v) end
					return tostring(math.floor(v + 0.5))
				end))
			end
		end
		for _, j in G.skills do
			local id = j.Id
			local s = skills[id] and table.clone(skills[id])
			assert(s, "unknown skill " .. tostring(id) .. " (new skills need code)")
			for k, v in j do
				if k ~= "Id" and k ~= "Scale" and k ~= "Say" then s[k] = v end
			end
			if j.Req == nil then s.Req = nil end
			for name, sc in j.Scale or {} do
				local b, p, rnd = sc.Base or 0, sc.Per or 0, sc.Round
				s[name] = function(r)
					local v = b + p * (r or 0)
					if rnd == "up" then return math.ceil(v - 1e-9) elseif rnd == "down" then return math.floor(v + 1e-9) end
					return v
				end
			end
			if type(j.Say) == "string" then s.Say = sayFn(s, j.Say) end
			skills[id] = s
		end
		new.Skills = skills
	end

	if G.decor then
		-- shapes live in Builds.Decor (new names get the placeholder box there); built-in ones the file misses stay at the end
		local list, by, seen = {}, {}, {}
		for _, d in G.decor do
			assert(type(d.Name) == "string" and d.Name:match("^%a[%w ']*$"), "bad decoration name " .. tostring(d.Name))
			assert(not seen[d.Name], "decoration " .. d.Name .. " twice")
			seen[d.Name] = true
			d.Cost = type(d.Cost) == "table" and d.Cost or {}
			table.insert(list, d)
			by[d.Name] = d
		end
		for _, d in Data.Decor do
			if not seen[d.Name] then table.insert(list, d) by[d.Name] = d end
		end
		new.Decor, new.DecorByName = list, by
	end

	-- 🛡️ Hero Gear (editor tabs Gear looks / Gear sets / Hero gear). Ones the files miss stay (players may own them).
	local MATS = {}
	for _, m in Enum.Material:GetEnumItems() do MATS[m.Name] = true end
	local looks, tierIcon = table.clone(Data.HeroLooks), table.clone(Data.HeroTierIcon)
	if G.herolooks then
		for _, l in G.herolooks do
			assert(type(l.Id) == "string" and l.Id:match("^%a%w*$"), "bad gear look id " .. tostring(l.Id))
			assert(MATS[l.Material or "SmoothPlastic"], "gear look " .. l.Id .. ": unknown material " .. tostring(l.Material))
			looks[l.Id] = {Color = col(l.Color) or Color3.new(1, 1, 1), Accent = col(l.Accent) or Color3.new(1, 1, 1), Material = l.Material or "SmoothPlastic",
				Shine = tonumber(l.Shine) or nil, Glow = l.Glow == true or nil, Extra = (l.Extra ~= "" and l.Extra) or nil}
			if type(l.Icon) == "string" and l.Icon ~= "" then tierIcon[l.Id] = l.Icon end
		end
		new.HeroLooks, new.HeroTierIcon = looks, tierIcon
	end
	local sets = table.clone(Data.HeroSets)
	if G.herosets then
		for _, j in G.herosets do
			assert(type(j.Id) == "string" and j.Id:match("^%a%w*$"), "bad gear set id " .. tostring(j.Id))
			local steps = {}
			for i, st in j.Steps or {} do
				assert(type(st.Name) == "string" and st.Name ~= "", "gear set " .. j.Id .. ": step " .. i .. " has no name")
				assert(type(st.Pieces) == "number" and st.Pieces >= 0, "gear set " .. j.Id .. ": step " .. st.Name .. " needs a piece count")
				table.insert(steps, {Name = st.Name, Pieces = st.Pieces, Weapon = st.Weapon == true or nil, Pwr = tonumber(st.Pwr), HP = tonumber(st.HP),
					Def = tonumber(st.Def), Spd = tonumber(st.Spd), Glow = st.Glow == true or nil})
			end
			local w = (type(j.Weapon) == "string" and j.Weapon ~= "") and j.Weapon or nil
			assert(not w or (new.WeaponByName or Data.WeaponByName)[w], "gear set " .. j.Id .. ": unknown weapon " .. tostring(w))
			sets[j.Id] = {Display = j.Display or j.Id, Icon = j.Icon or "🏆", Glow = col(j.Glow) or Color3.new(1, 1, 1), Weapon = w, Steps = steps}
		end
		new.HeroSets = sets
	end
	if G.herogear then
		local list, by = {}, {}
		for name, g in Data.HeroGearByName do by[name] = g end -- (retired pieces still load for owners)
		for _, g in G.herogear do
			assert(type(g.Name) == "string" and g.Name:match("^%a%w*$"), "bad gear name " .. tostring(g.Name))
			assert(Data.HeroSlotById[g.Slot] and g.Slot ~= "MainHand", "gear " .. g.Name .. ": bad slot " .. tostring(g.Slot))
			assert(Data.WeaponRarityByName[g.Rarity], "gear " .. g.Name .. ": bad rarity")
			assert(looks[g.Tier], "gear " .. g.Name .. ": unknown look / tier " .. tostring(g.Tier))
			if g.Set == "" then g.Set = nil end
			assert(not g.Set or sets[g.Set], "gear " .. g.Name .. ": unknown set " .. tostring(g.Set))
			if g.Icon == "" then g.Icon = nil end
			g.Icon = g.Icon or tierIcon[g.Tier] or "🛡️"
			g.Look = g.Tier
			if type(g.From) ~= "table" then g.From = nil end -- (Data.FixFrom fills it in; it also sets Craft from it)
			g.Craft = nil
			g.Display = g.Display or g.Name
			table.insert(list, g)
			by[g.Name] = g
		end
		new.HeroGear, new.HeroGearByName = list, by
	end

	-- ⚙️ Gear numbers (editor tab): slot bonuses, power by rarity, Workbench costs, which bosses drop what
	local function pos(v) v = tonumber(v) return (v and v > 0) and v or nil end
	if G.herotune then
		local t = {SlotBonus = {}, SlotCost = {}, Pwr = {}, Maxed = {}, Craft = {}, Lands = {}, DungeonSet = {}}
		local setsNow, looksNow = new.HeroSets or Data.HeroSets, new.HeroLooks or Data.HeroLooks
		for _, r in G.herotune do
			local id = r.Id
			if r.Group == "Slot" then
				assert(Data.HeroSlotById[id] and id ~= "MainHand", "gear numbers: bad slot " .. tostring(id))
				t.SlotBonus[id] = {HP = pos(r.HP), Def = pos(r.Def), Spd = pos(r.Spd)}
				t.SlotCost[id] = pos(r.CostX) or 1
			elseif r.Group == "Rarity" then
				assert(Data.WeaponRarityByName[id], "gear numbers: bad rarity " .. tostring(id))
				t.Pwr[id] = assert(tonumber(r.Pwr), "gear numbers: " .. id .. " needs a power number")
				t.Maxed[id] = tonumber(r.MaxedCoins) or 0
			elseif r.Group == "Craft" then
				assert(looksNow[id], "gear numbers: no gear look called " .. tostring(id))
				local cost = {}
				for res, n in type(r.Cost) == "table" and r.Cost or {} do
					if (tonumber(n) or 0) > 0 then cost[res] = math.floor(tonumber(n)) end
				end
				t.Craft[id] = cost
			elseif r.Group == "Land" then
				local tiers = {}
				for _, x in type(r.Tiers) == "table" and r.Tiers or {} do
					assert(looksNow[x], "gear numbers: " .. tostring(id) .. ": unknown look " .. tostring(x))
					table.insert(tiers, x)
				end
				t.Lands[id] = tiers
				local ds = (type(r.DungeonSet) == "string" and r.DungeonSet ~= "") and r.DungeonSet or nil
				assert(not ds or setsNow[ds], "gear numbers: " .. tostring(id) .. ": unknown set " .. tostring(ds))
				t.DungeonSet[id] = ds or false
			elseif r.Group == "Chance" then
				t.Chance = r
			elseif r.Group == "General" then
				t.General = r
			end
		end
		new.HeroTune = t
	end

	-- 🏰 Dungeon numbers (editor tab): ⭐ tiers, each dungeon's name / chest coins / furniture scrolls, rewards
	local TIER_KEYS = {"Size", "Loops", "Mobs", "Depth", "Chests", "Loot", "Zones", "Ledges", "Route", "Obby", "Pads", "Hidden", "Runaway", "Par"}
	local REWARD_KEYS = {"Energy", "BossChestX", "ChestCapsule", "SilverX", "SilverCapsule", "HiddenX", "HiddenCapsule", "RockHold",
		"RunawayX", "RunawayCapsule", "RunawayHops", "RunawayNear", "ScrollChance", "ScrollDoneCoins", "FirstClearX"}
	if G.dungeon and Data.Dungeon then
		local D, t = Data.Dungeon, {Tiers = {}, Lands = {}}
		for _, r in G.dungeon do
			if r.Group == "Tier" then
				local i = tonumber(tostring(r.Id):match("%d+"))
				assert(i and D.Tiers[i], "dungeon numbers: unknown tier " .. tostring(r.Id))
				local tier = table.clone(D.Tiers[i])
				for _, k in TIER_KEYS do
					if tonumber(r[k]) then tier[k] = tonumber(r[k]) end
				end
				for _, k in {"Size", "Depth", "Chests", "Zones", "Ledges", "Route", "Hidden", "Runaway"} do tier[k] = math.max(0, math.floor(tier[k] or 0)) end
				tier.Size, tier.Zones, tier.Route = math.clamp(tier.Size, 2, 8), math.clamp(tier.Zones, 1, 4), math.max(1, tier.Route)
				t.Tiers[i] = tier
			elseif r.Group == "Land" then
				assert(D.Themes[r.Id], "dungeon numbers: unknown dungeon " .. tostring(r.Id))
				local scrolls = {}
				for _, n in type(r.Scrolls) == "table" and r.Scrolls or {} do
					if type(n) == "string" and n ~= "" then table.insert(scrolls, n) end
				end
				t.Lands[r.Id] = {Name = (type(r.Name) == "string" and r.Name ~= "") and r.Name or nil, Icon = (type(r.Icon) == "string" and r.Icon ~= "") and r.Icon or nil,
					Coins = tonumber(r.ChestCoins), Scrolls = scrolls}
			elseif r.Group == "Reward" then
				t.Reward = r
			end
		end
		new.Dungeon = t
	end

	-- everything built: swap it in
	if new.Decor then Data.Decor, Data.DecorByName = new.Decor, new.DecorByName end
	if new.Weapons then Data.Weapons, Data.WeaponByName = new.Weapons, new.WeaponByName end
	if new.Species then Data.Species, Data.SpeciesByName = new.Species, new.SpeciesByName end
	if new.Eggs then
		Data.Eggs = new.Eggs
		if new.EggTiers then Data.EggShop.Tiers = new.EggTiers end
	end
	if new.Capsules then Data.Capsules = new.Capsules end
	if new.HeroLooks then Data.HeroLooks, Data.HeroTierIcon = new.HeroLooks, new.HeroTierIcon end
	if new.HeroSets then Data.HeroSets = new.HeroSets end
	if new.HeroGear then
		Data.HeroGear, Data.HeroGearByName = new.HeroGear, new.HeroGearByName
		for _, g in Data.HeroGear do
			if not table.find(Data.HeroTierOrder, g.Tier) then table.insert(Data.HeroTierOrder, g.Tier) end
		end
	end
	if new.HeroTune then
		-- (tables are changed in place: scripts may hold on to them)
		local t = new.HeroTune
		for id, b in t.SlotBonus do Data.HeroSlotBonus[id] = b end
		for id, m in t.SlotCost do Data.HeroSlotCostMult[id] = m end
		for id, v in t.Pwr do Data.HeroGearPwr[id] = v end
		for id, v in t.Maxed do Data.HeroGearMaxedCoins[id] = v end
		if next(t.Craft) then
			table.clear(Data.HeroGearCraft)
			for id, c in t.Craft do Data.HeroGearCraft[id] = c end
		end
		local drop = Data.HeroGearDrop
		for id, tiers in t.Lands do drop.Lands[id] = tiers end
		drop.DungeonSet = drop.DungeonSet or {}
		for id, ds in t.DungeonSet do drop.DungeonSet[id] = ds or nil end
		local c = t.Chance
		if c then
			drop.Boss = tonumber(c.Boss) or drop.Boss
			drop.Dungeon = tonumber(c.Dungeon) or drop.Dungeon
			drop.SetWeapon = tonumber(c.SetWeapon) or drop.SetWeapon
			Data.WeaponDrop = Data.WeaponDrop or {}
			Data.WeaponDrop.Lands = tonumber(c.WeaponLands) or Data.WeaponDrop.Lands
			Data.WeaponDrop.Dungeons = tonumber(c.WeaponDungeons) or Data.WeaponDrop.Dungeons
		end
		local g = t.General
		if g then
			Data.HeroDefCap = tonumber(g.DefCap) or Data.HeroDefCap
			Data.HeroGearMaxStars = tonumber(g.MaxStars) or Data.HeroGearMaxStars
			Data.HeroGearStarBonus = tonumber(g.StarBonus) or Data.HeroGearStarBonus
			Data.HeroCraftReach = tonumber(g.CraftReach) or Data.HeroCraftReach
		end
	end
	if new.Dungeon then
		local D, t = Data.Dungeon, new.Dungeon
		for i, tier in t.Tiers do D.Tiers[i] = tier end
		for id, l in t.Lands do
			local th = D.Themes[id]
			th.Name, th.Icon = l.Name or th.Name, l.Icon or th.Icon
			if l.Coins then D.ChestCoins[id] = l.Coins end
			D.Scrolls[id] = l.Scrolls
		end
		local r = t.Reward
		if r then
			for _, k in REWARD_KEYS do
				if tonumber(r[k]) then D[k] = tonumber(r[k]) end
			end
			D.ScoreBonus = {tonumber(r.Score1) or D.ScoreBonus[1], tonumber(r.Score2) or D.ScoreBonus[2], tonumber(r.Score3) or D.ScoreBonus[3]}
		end
		if Data.ScrollLandOf then
			table.clear(Data.ScrollLandOf)
			for land, names in D.Scrolls do
				for _, name in names do Data.ScrollLandOf[name] = land end
			end
		end
	end
	if Data.FixFrom then Data.FixFrom() end -- (🧭 From on every weapon / piece; Craft follows it)
	if new.Skills then
		Data.Skills = new.Skills
		for _, br in Data.SkillBranches do
			local ids = {}
			for id, s in Data.Skills do
				if s.Branch == br.Name then table.insert(ids, id) end
			end
			table.sort(ids, function(a, b)
				local A, B = Data.Skills[a], Data.Skills[b]
				if A.Row ~= B.Row then return A.Row < B.Row end
				return A.Col < B.Col
			end)
			br.Order = ids
		end
	end
	Data.GameDataOn = true
end
do
	local gd = script:FindFirstChild("GameData")
	if gd and gd:IsA("ModuleScript") then
		local ok, err = pcall(function() Data.ApplyGameData(require(gd)) end)
		if not ok then warn("[CritterData] editor GameData skipped, using built-in data: " .. tostring(err)) end
	end
end
