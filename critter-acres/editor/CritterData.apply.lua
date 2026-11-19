-- 🛠 Critter Editor (critter-acres/editor): the CritterSync plugin writes the editor's JSON into the child
-- ModuleScript CritterData.GameData. When it is there, it REPLACES weapons, pets, eggs (+ egg shop tiers),
-- capsules, the skill numbers/texts and decorations (cost, icon, effect) above. Everything is built first and only swapped in if it all worked,
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

	-- everything built: swap it in
	if new.Decor then Data.Decor, Data.DecorByName = new.Decor, new.DecorByName end
	if new.Weapons then Data.Weapons, Data.WeaponByName = new.Weapons, new.WeaponByName end
	if new.Species then Data.Species, Data.SpeciesByName = new.Species, new.SpeciesByName end
	if new.Eggs then
		Data.Eggs = new.Eggs
		if new.EggTiers then Data.EggShop.Tiers = new.EggTiers end
	end
	if new.Capsules then Data.Capsules = new.Capsules end
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
