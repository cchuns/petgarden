-- Critter Acres: BoutiqueServer (ServerScriptService)
-- 👗 Bow & Bell Boutique on market street: clothes for your character (Data.Wearables: hats, glasses, back items)
-- and hats for your pets (Data.Outfits, Data.OutfitPrice). Always in stock: buy once with coins, keep forever.
-- Your clothes are built from parts (CritterUI.PutOn) and welded on, so everyone sees them.
-- Registers its actions on FarmServer's ACTIONS table through CritterAPI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local Data = API.Data
local ACTIONS = API.ACTIONS
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))

local function closet(prof)
	prof.Wardrobe = prof.Wardrobe or {} -- [name] = true
	prof.Wearing = prof.Wearing or {} -- [slot] = name
	return prof.Wardrobe, prof.Wearing
end

local function dress(player)
	local prof = API.profiles[player]
	local char = player.Character
	if not prof or not char then return end
	local own, wearing = closet(prof)
	for _, slot in Data.WearSlots do
		local name = wearing[slot]
		if name and not (Data.WearByName[name] and own[name]) then name = nil end
		pcall(CritterUI.PutOn, char, slot, name)
	end
end

local function info(prof)
	local own, wearing = closet(prof)
	return {Own = own, Wearing = wearing, Outfits = prof.Outfits}
end

function ACTIONS.BoutiqueInfo(player, prof)
	return info(prof)
end

function ACTIONS.BuyWear(player, prof, name)
	local w = Data.WearByName[name]
	if not w then return {Error = "❌ That's not in the boutique."} end
	local own, wearing = closet(prof)
	if own[name] then return {Error = "You already have it!"} end
	local coins = API.coinsOf(player)
	if coins.Value < w.Price then return {Error = ("You need 💰%d for this."):format(w.Price)} end
	coins.Value -= w.Price
	own[name] = true
	wearing[w.Slot] = name -- put it on right away
	dress(player)
	return {Ok = true, Info = info(prof)}
end

-- tap once to wear, again to take it off
function ACTIONS.WearItem(player, prof, name)
	local w = Data.WearByName[name]
	local own, wearing = closet(prof)
	if not w or not own[name] then return {Error = "🔒 Buy it first!"} end
	wearing[w.Slot] = wearing[w.Slot] ~= name and name or nil
	dress(player)
	return {Ok = true, Info = info(prof)}
end

function ACTIONS.BuyOutfit(player, prof, name)
	local o = Data.OutfitByName[name]
	if not o or o.Limited then return {Error = "That one isn't for sale."} end
	prof.Outfits = prof.Outfits or {}
	if prof.Outfits[name] then return {Error = "You already have it!"} end
	local price = Data.OutfitPrice[o.Rarity]
	local coins = API.coinsOf(player)
	if coins.Value < price then return {Error = ("You need 💰%d for this."):format(price)} end
	coins.Value -= price
	prof.Outfits[name] = true
	API.pushState(player)
	return {Ok = true, Info = info(prof)}
end

-- put your clothes back on every time you spawn
local function hook(player)
	local function onChar(char)
		char:WaitForChild("Head", 10)
		for _ = 1, 100 do
			if API.profiles[player] then break end
			task.wait(0.2)
		end
		task.wait(0.5)
		if player.Character == char then dress(player) end
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then task.spawn(onChar, player.Character) end
end
Players.PlayerAdded:Connect(hook)
for _, p in Players:GetPlayers() do task.spawn(hook, p) end
