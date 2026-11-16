-- Critter Acres: ShopServer (ServerScriptService)
-- 🛒 Seed shop in the plaza: restocks every 5 minutes (Data.ShopSeeds). Everyone sees the same seeds, but each
-- player has their own amounts, so nobody misses out. Rare seeds get a server shout, and players with a 🔔
-- bell get a big popup. A delivery balloon floats down with every restock.
-- 🎁 Seed packs (Data.SeedPacks): random seeds, some only found in packs, one free Basic pack a day.
-- 📗 Seed Book (Data.SeedBookRows): grow every crop in a row for a reward.
-- Registers its actions on FarmServer's ACTIONS table through CritterAPI.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local Data = API.Data
local ACTIONS = API.ACTIONS
local root = API.root

---------------------------------------------------------------- the stock
local current = {epoch = -1, items = {}} -- items = {{Crop, Amount, Price}}
local function epochNow() return math.floor(os.time() / Data.ShopRestockSecs) end
local devOffset = 0 -- the dev "restock now" button bumps this

local function stockFor(prof)
	if prof.ShopEpoch ~= current.epoch then
		prof.ShopEpoch = current.epoch
		prof.ShopBought = {}
	end
	return prof.ShopBought
end

-- delivery balloon: floats down to the shop, waits, floats away
local shopModel = root:FindFirstChild("SeedShop")
local function balloonShow()
	if not shopModel then return end
	local dock = shopModel:FindFirstChild("Dock")
	if not dock then return end
	local m = Instance.new("Model")
	m.Name = "Balloon"
	local function p(props)
		props.Anchored, props.CanCollide, props.CanQuery = true, false, false
		return API.part(m, props)
	end
	local colors = {Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 80), Color3.fromRGB(90, 200, 255)}
	local ball = p({Shape = Enum.PartType.Ball, Size = Vector3.one * 9, Position = Vector3.new(0, 10, 0), Color = colors[math.random(#colors)]})
	p({Size = Vector3.new(4, 2.5, 4), Position = Vector3.zero, Color = Color3.fromRGB(170, 120, 70), Material = Enum.Material.WoodPlanks})
	for _, x in {-1.6, 1.6} do
		for _, z in {-1.6, 1.6} do p({Size = Vector3.new(0.15, 6, 0.15), Position = Vector3.new(x, 4, z), Color = Color3.fromRGB(90, 70, 50)}) end
	end
	for i = 1, 3 do -- seed sacks in the basket
		p({Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, Position = Vector3.new(-1 + i * 0.6, 1.6, 0), Color = Color3.fromRGB(230, 200, 150)})
	end
	local glow = Instance.new("ParticleEmitter")
	glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glow.LightEmission = 1
	glow.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160))
	glow.Size = NumberSequence.new(0.8, 0)
	glow.Rate = 15
	glow.Parent = ball
	m.PrimaryPart = ball
	local down = dock.Position + Vector3.new(0, 1.5, 0)
	local up = down + Vector3.new(30, 90, 20)
	m:PivotTo(CFrame.new(up + Vector3.new(0, 10, 0)))
	m.Parent = workspace
	local function fly(from, to, secs)
		local t0 = os.clock()
		while os.clock() - t0 < secs do
			local f = (os.clock() - t0) / secs
			f = f * f * (3 - 2 * f)
			m:PivotTo(CFrame.new(from:Lerp(to, f) + Vector3.new(0, 10 + math.sin(os.clock() * 2) * 0.5, 0)) * CFrame.Angles(0, os.clock() * 0.3, 0))
			task.wait()
		end
	end
	task.spawn(function()
		fly(up, down, 4)
		API.pop(ball, "🌱")
		task.wait(6)
		fly(down, up + Vector3.new(-60, 40, 0), 5)
		m:Destroy()
	end)
end

local function restock()
	current.epoch = epochNow() + devOffset
	current.items = {}
	local rare = {}
	for _, s in Data.ShopSeeds do
		if math.random() < s.Chance then
			local crop = Data.CropByName[s.Crop]
			table.insert(current.items, {Crop = s.Crop, Amount = math.random(s.Amount[1], s.Amount[2]), Price = crop.Seed, Unlock = crop.Unlock})
			if s.Chance <= Data.ShopShoutChance then table.insert(rare, s.Crop) end
		end
	end
	workspace:SetAttribute("ShopRestockAt", (epochNow() + 1) * Data.ShopRestockSecs)
	workspace:SetAttribute("ShopRare", #rare > 0 and table.concat(rare, ",") or nil)
	balloonShow()
	if #rare > 0 then
		local icons = {}
		for _, name in rare do table.insert(icons, Data.CropByName[name].Icon .. " " .. name:upper()) end
		API.notifyAll(("🛒 RARE SEEDS IN STOCK: %s!"):format(table.concat(icons, ", ")))
		for player, prof in API.profiles do
			if prof.Bell then API.reveal(player, {Kind = "Bell", Crops = rare}) end
		end
	end
end
function API.Restock()
	devOffset += 1
	restock()
end

-- the big board over the shop: what's in stock + countdown
local boardText
do
	local board = shopModel and shopModel:FindFirstChild("Board")
	local gui = board and board:FindFirstChild("Gui")
	boardText = gui and gui:FindFirstChild("Text")
end
task.spawn(function()
	restock()
	while true do
		task.wait(1)
		if epochNow() + devOffset ~= current.epoch then restock() end -- a new 5-minute window started
		if boardText then
			local left = math.max(0, (workspace:GetAttribute("ShopRestockAt") or os.time()) - os.time())
			local icons = {}
			for _, it in current.items do table.insert(icons, Data.CropByName[it.Crop].Icon) end
			boardText.Text = ("🛒 %s\n⏱ %d:%02d"):format(table.concat(icons, " "), left // 60, left % 60)
		end
	end
end)

---------------------------------------------------------------- 🥚 egg stock: rolls every hour, each slot can be bought once per player
local eggStock = {epoch = -1, slots = {}}
local eggDev = 0 -- the dev "restock now" button bumps this too
local function eggEpoch() return math.floor(os.time() / Data.EggShop.RestockSecs) end
local function rollEggTier()
	local r = math.random()
	for _, t in Data.EggShop.Tiers do
		r -= t.Chance
		if r <= 0 then return t end
	end
	return Data.EggShop.Tiers[1]
end
local function eggRestock()
	eggStock.epoch = eggEpoch() + eggDev
	eggStock.slots = {}
	local best
	for i = 1, Data.EggShop.Slots do
		local t = rollEggTier()
		eggStock.slots[i] = {Egg = t.Egg, Price = t.Price}
		if t.Price >= 5000 and (not best or t.Price > best.Price) then best = t end
	end
	workspace:SetAttribute("EggRestockAt", (eggEpoch() + 1) * Data.EggShop.RestockSecs)
	if best then
		local e = Data.Eggs[best.Egg]
		API.notifyAll(("%s %s IN THE TOWN SHOP! Hurry, new eggs every hour!"):format(e.Icon, e.Name:upper()))
	end
end
local function eggBought(prof)
	if prof.EggShopEpoch ~= eggStock.epoch then
		prof.EggShopEpoch = eggStock.epoch
		prof.EggShopBought = {}
	end
	return prof.EggShopBought
end
task.spawn(function()
	eggRestock()
	while true do
		task.wait(1)
		if eggEpoch() + eggDev ~= eggStock.epoch then eggRestock() end
	end
end)
local oldRestock = API.Restock
function API.Restock()
	oldRestock()
	eggDev += 1
	eggRestock()
end

---------------------------------------------------------------- actions (the shop window in CritterPlay calls these)
local function shopInfo(player, prof)
	local bought = stockFor(prof)
	local items = {}
	for _, it in current.items do
		table.insert(items, {Crop = it.Crop, Price = it.Price, Unlock = it.Unlock, Left = math.max(0, it.Amount - (bought[it.Crop] or 0))})
	end
	local rows = {}
	for i, row in Data.SeedBookRows do
		local have = 0
		for _, c in row.Crops do
			if prof.SeedBook[c] then have += 1 end
		end
		rows[i] = {Have = have, Need = #row.Crops, Claimed = prof.SeedRows[i] == true}
	end
	local eggs = {}
	local gotEggs = eggBought(prof)
	for i, s in eggStock.slots do
		table.insert(eggs, {Egg = s.Egg, Price = s.Price, Bought = gotEggs[tostring(i)] == true})
	end
	return {Items = items, RestockAt = workspace:GetAttribute("ShopRestockAt"), Bell = prof.Bell, FreePacks = prof.FreePacks or 0,
		Level = Data.FarmLevel(prof.FarmXp), SeedBook = prof.SeedBook, Rows = rows, Eggs = eggs, EggRestockAt = workspace:GetAttribute("EggRestockAt")}
end
function ACTIONS.TravelShop(player, prof) -- 🛒 chip on the HUD: hop over to the shop
	local counter = shopModel and shopModel:FindFirstChild("Counter")
	if counter then API.teleportTo(player, counter.Position + Vector3.new(0, 0, 9)) end
end
function ACTIONS.ShopInfo(player, prof)
	return shopInfo(player, prof)
end
function ACTIONS.BuySeed(player, prof, cropName, count)
	count = math.clamp(tonumber(count) or 1, 1, 50)
	local item
	for _, it in current.items do
		if it.Crop == cropName then item = it end
	end
	if not item then return {Error = "❌"} end
	if Data.FarmLevel(prof.FarmXp) < item.Unlock then return {Error = ("🔒 ⭐%d"):format(item.Unlock)} end
	local bought = stockFor(prof)
	local left = item.Amount - (bought[cropName] or 0)
	count = math.min(count, left)
	if count <= 0 then return {Error = "0"} end
	local coins = API.coinsOf(player)
	count = math.min(count, math.floor(coins.Value / math.max(1, item.Price)))
	if count <= 0 then return {Error = ("💰 %d"):format(item.Price)} end
	coins.Value -= item.Price * count
	bought[cropName] = (bought[cropName] or 0) + count
	API.addSeeds(player, cropName, count)
	return {Ok = true, Count = count, Info = shopInfo(player, prof)}
end
function ACTIONS.BuyEgg(player, prof, slot)
	slot = tonumber(slot)
	local s = slot and eggStock.slots[slot]
	if not s then return {Error = "🥚 That egg is gone. New eggs every hour!"} end
	local bought = eggBought(prof)
	if bought[tostring(slot)] then return {Error = "You already bought this one. New eggs every hour!"} end
	local coins = API.coinsOf(player)
	if coins.Value < s.Price then return {Error = ("You need 💰%d for this egg."):format(s.Price)} end
	coins.Value -= s.Price
	bought[tostring(slot)] = true
	API.addEgg(prof, s.Egg)
	API.pushState(player)
	local e = Data.Eggs[s.Egg]
	if s.Price >= 50000 then API.notifyAll(("%s %s bought an %s!"):format(e.Icon, player.DisplayName, e.Name:upper())) end
	return {Ok = true, Egg = s.Egg, Info = shopInfo(player, prof)}
end
function ACTIONS.BuyBell(player, prof)
	if prof.Bell then return {Error = "🔔 ✔"} end
	local coins = API.coinsOf(player)
	if coins.Value < Data.BellCost then return {Error = ("💰 %d"):format(Data.BellCost)} end
	coins.Value -= Data.BellCost
	prof.Bell = true
	return {Ok = true, Info = shopInfo(player, prof)}
end
-- open a seed pack: returns the slot index (for the reel) and what was inside
function ACTIONS.BuyPack(player, prof, packName)
	local pack = Data.SeedPackByName[packName]
	if not pack then return {Error = "❌"} end
	if pack.Name == "Basic" and (prof.FreePacks or 0) > 0 then
		prof.FreePacks -= 1
	else
		local coins = API.coinsOf(player)
		if coins.Value < pack.Price then return {Error = ("💰 %d"):format(pack.Price)} end
		coins.Value -= pack.Price
	end
	local item, index = API.rollWeighted(pack.Items)
	API.addSeeds(player, item.Crop, item.Amount)
	local crop = Data.CropByName[item.Crop]
	if crop.Rarity == "Legendary" then
		API.notifyAll(("%s %s pulled a %s from a %s pack!"):format(crop.Icon, player.DisplayName, item.Crop:upper(), pack.Name))
	end
	return {Index = index, Item = {Crop = item.Crop, Amount = item.Amount, Rarity = crop.Rarity}, Pack = pack.Name, Info = shopInfo(player, prof)}
end
function ACTIONS.ClaimSeedRow(player, prof, i)
	local row = Data.SeedBookRows[i]
	if not row or prof.SeedRows[i] then return {Error = "❌"} end
	for _, c in row.Crops do
		if not prof.SeedBook[c] then return {Error = "📗"} end
	end
	prof.SeedRows[i] = true
	local got = API.grant(player, row.Reward)
	API.reveal(player, {Kind = "Prize", Prize = got})
	return {Ok = true, Info = shopInfo(player, prof)}
end
