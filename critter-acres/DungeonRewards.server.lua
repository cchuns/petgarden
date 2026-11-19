-- Critter Acres: DungeonRewards (ServerScriptService)
-- 🏰 Dungeon stage 3 rewards. The map and its chests live in ServerScriptService.Dungeons, which calls these:
--   📜 API.dungeonScroll(player, land, sure, loot) -> toast text or nil
--        A furniture scroll unlocks a dungeon-only decoration (Data.Dungeon.Scrolls, saved in prof.Scrolls) so it can be
--        bought at the 🔨 Workbench. The 🎁 boss chest always has one you don't have yet (sure = true); silver / hidden /
--        runaway chests have Data.Dungeon.ScrollChance. All found in this dungeon: the boss chest gives coins instead.
--   ⭐ API.dungeonCleared(run, player, first) when the boss falls: 1-3 stars (cleared / beat Par time / found half the
--        chests), saved as prof.DungeonStars["<land><tier>"]; the boss chest coins get x Data.Dungeon.ScoreBonus[stars].
--        🎉 first = first clear of this dungeon at this ⭐ tier: bonus coins + a capsule.
--        The client (StarterPlayerScripts.DungeonScore) shows the score card from RemoteEvent ReplicatedStorage.DungeonEvent.
--   😵 faints inside a dungeon are counted (shown on the score card; they never cost anything).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local Data = API.Data
local D = Data.Dungeon

local event = ReplicatedStorage:FindFirstChild("DungeonEvent") or Instance.new("RemoteEvent")
event.Name = "DungeonEvent"
event.Parent = ReplicatedStorage

---------------------------------------------------------------- 📜 furniture scrolls
API.dungeonScroll = function(player, land, sure, loot)
	local prof = API.profiles[player]
	if not prof or not D.Scrolls[land] then return nil end
	if not sure and math.random() >= (D.ScrollChance or 0) then return nil end
	prof.Scrolls = prof.Scrolls or {}
	local missing = {}
	for _, name in D.Scrolls[land] do
		if not prof.Scrolls[name] then table.insert(missing, name) end
	end
	if #missing == 0 then
		if not sure then return nil end
		local coins = math.floor((D.ScrollDoneCoins or 150) * (loot or 1) + 0.5)
		API.addCoins(player, coins)
		return ("📜 You have every scroll from here! 💰 +%d"):format(coins)
	end
	local name = missing[math.random(#missing)]
	prof.Scrolls[name] = true
	local def = Data.DecorByName[name]
	local icon = def and def.Icon or "🏡"
	event:FireClient(player, {Kind = "Scroll", Name = name, Icon = icon})
	return ("📜 New scroll: %s %s! Buy it at the 🔨 Workbench."):format(icon, name)
end

---------------------------------------------------------------- ⭐ run score + 🎉 first-clear bonus
API.dungeonCleared = function(run, player, first)
	local prof = API.profiles[player]
	if not prof then return end
	local land, tierN = run.terrain, run.tier or 1
	local tier = D.Tiers[tierN] or D.Tiers[1]
	local th = D.Themes[land] or D.Themes.Meadow
	local secs = math.floor(os.clock() - (run.t0 or os.clock()))
	local found = run.found and run.found[player] or 0
	local total = run.chestTotal or 0
	local faints = run.faints and run.faints[player] or 0
	local fast = secs <= (tier.Par or 600)
	local hunter = total == 0 or found >= math.ceil(total / 2)
	local stars = 1 + (fast and 1 or 0) + (hunter and 1 or 0)
	run.scoreX = run.scoreX or {}
	run.scoreX[player] = D.ScoreBonus and D.ScoreBonus[stars] or 1
	prof.DungeonStars = prof.DungeonStars or {}
	local key = land .. tierN
	local best = prof.DungeonStars[key] or 0
	if stars > best then prof.DungeonStars[key] = stars end
	local bonus
	if first then
		local coins = math.floor((D.ChestCoins[land] or 40) * tier.Loot * D.BossChestX * (D.FirstClearX or 3) + 0.5)
		API.addCoins(player, coins)
		local cap = Data.Capsules[land]
		if API.giveCapsule then API.giveCapsule(player, land, 1) end
		bonus = {Coins = coins, Capsule = cap and (cap.Icon .. " " .. cap.Name) or nil}
	end
	event:FireClient(player, {Kind = "Score", Icon = th.Icon, Name = th.Name, Tier = tierN, Stars = stars, Best = math.max(best, stars),
		NewBest = stars > best and best > 0, Secs = secs, Par = tier.Par or 600, Found = found, Total = total, Faints = faints,
		Fast = fast, Hunter = hunter, X = run.scoreX[player], First = bonus})
end

---------------------------------------------------------------- 😵 faints (Combat asks Realms where you wake up: count it first)
task.spawn(function()
	local t0 = os.clock()
	while not API.realmSpawn and os.clock() - t0 < 30 do task.wait(0.2) end
	local spawnOf = API.realmSpawn
	if not spawnOf then warn("[DungeonRewards] no API.realmSpawn: faints are not counted") return end
	API.realmSpawn = function(player)
		local run = API.runOf and API.runOf[player]
		if run and run.dungeon then
			run.faints = run.faints or {}
			run.faints[player] = (run.faints[player] or 0) + 1
		end
		return spawnOf(player)
	end
end)

---------------------------------------------------------------- Studio dev menu
API.DEV_EXTRA = API.DEV_EXTRA or {}
API.DEV_EXTRA.Scrolls = function(player, prof) -- every 📜 scroll
	prof.Scrolls = prof.Scrolls or {}
	local n = 0
	for _, names in D.Scrolls do
		for _, name in names do prof.Scrolls[name] = true n += 1 end
	end
	return ("📜 All %d scrolls"):format(n)
end
API.DEV_EXTRA.ScrollsReset = function(player, prof)
	prof.Scrolls = {}
	return "📜 Scrolls cleared"
end

print("[DungeonRewards] ready")
