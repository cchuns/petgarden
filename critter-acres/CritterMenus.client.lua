-- Critter Acres: CritterMenus (StarterPlayerScripts LocalScript)
-- The clean, minimal player UI:
--   top left: ⚔️ player level + XP bar, 💰 coins, and under it a small 🏡 farm level chip      top right: 🔔 To do (count)
--   top right: dock 🐾 Pets · 🏡 Farm · 🗺️ World · 🛒 Shop · ⚔️ Weapons · 🌳 Skills · 🔔 To do (one row; 2 columns on small screens)
--   bottom right (on your farm only): the seed you're planting      bottom left: your buddy (tap for actions)
-- Every window has the same look (UIKit): icon, title, a one-line subtitle, tabs, ❓ help, ✖ close.
-- Grey buttons always say why. Hover (PC) or hold (touch) any button for a tooltip.
-- Detailed screens that already exist (pet profile, hatch, decorate mode, power-up, packs, nest, workbench, book)
-- are opened through the CritterUIBridge BindableEvent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Data = require(ReplicatedStorage:WaitForChild("CritterData"))
local CritterUI = require(ReplicatedStorage:WaitForChild("CritterUI"))
local PackOpen = require(ReplicatedStorage:WaitForChild("PackOpen"))
local K = require(ReplicatedStorage:WaitForChild("UIKit"))
local actionFn = ReplicatedStorage:WaitForChild("CritterAction")
local stateEvent = ReplicatedStorage:WaitForChild("CritterState")
local bridge = ReplicatedStorage:WaitForChild("CritterUIBridge")
local player = Players.LocalPlayer
local root = workspace:WaitForChild("CritterAcres")

local gui = Instance.new("ScreenGui")
gui.Name = "CritterMenus"
gui.ResetOnSpawn = false
gui.DisplayOrder = -1 -- under the reveal / profile screens of the other scripts
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- children always draw on top of their window
gui.Parent = player:WaitForChild("PlayerGui")

local function act(...) return actionFn:InvokeServer(...) end
local function toast(text, good) K.toast(gui, text, good) end
local function commas(n) return tostring(math.floor(n or 0)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") end
local function timeText(secs)
	secs = math.max(0, math.floor(secs))
	if secs >= 3600 then return ("%dh %dm"):format(secs // 3600, secs % 3600 // 60) end
	return ("%d:%02d"):format(secs // 60, secs % 60)
end
local function farmLevel() return player:GetAttribute("FarmLevel") or 1 end
local function scale() return workspace:GetAttribute("CritterTimeScale") or 1 end

local state
local stateAt = 0
local helperInfo, helperAt = {}, 0 -- helpers tab: last NPC info and when we got it
stateEvent.OnClientEvent:Connect(function(st) state = st stateAt = os.clock() helperAt = 0 end)
task.defer(function() stateEvent:FireServer() end)

---------------------------------------------------------------- top bar
local top = K.frame(gui, {Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(440, 52), BackgroundTransparency = 1})
K.list(top, Enum.FillDirection.Horizontal, 14)
-- ⚔️ player (Hero) level: big pill with its XP bar
local function heroLevel() return player:GetAttribute("HeroLv") or 1 end
local heroPill = K.button(top, {Text = "", Size = UDim2.fromOffset(210, 50), LayoutOrder = 1, Tip = "⚔️ Player level",
	TipText = "Beat mobs in the wild lands to level up. Every level = +1 skill point (K)."}, function()
	local lv = heroLevel()
	if lv >= Data.HeroMax then toast(("⚔️ Level %d: max level!"):format(lv)) return end
	toast(("⚔️ Level %d: %s XP to the next level  ·  🌳 skills: K"):format(lv, commas(Data.HeroNeed(lv) - (player:GetAttribute("HeroXp") or 0))))
end)
local heroText = K.text(heroPill, {Text = "⚔️ Lv 1", Size = UDim2.new(0.48, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Max = 22})
local _, heroFill = K.bar(heroPill, 0, Color3.fromRGB(240, 140, 110), {Position = UDim2.new(0.48, 4, 0.5, -7), Size = UDim2.new(0.52, -6, 0, 14)})
-- 🏡 farm level: a smaller chip under it
local lvPill = K.button(gui, {Text = "", Position = UDim2.fromOffset(16, 78), Size = UDim2.fromOffset(210, 32), Max = 16, Tip = "🏡 Farm level",
	TipText = "Plant, harvest, catch and hatch to level up. Levels unlock seeds and more."}, function()
	toast(("🏡 Farm level %d: %s XP to the next level"):format(farmLevel(), commas((player:GetAttribute("FarmXpNext") or 0) - (player:GetAttribute("FarmXp") or 0))))
end)
lvPill.UIPadding.PaddingTop, lvPill.UIPadding.PaddingBottom = UDim.new(0, 2), UDim.new(0, 2)
local lvText = K.text(lvPill, {Text = "🏡 Farm Lv 1", Size = UDim2.new(0.55, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Max = 16})
local _, lvFill = K.bar(lvPill, 0, K.YELLOW, {Position = UDim2.new(0.55, 4, 0.5, -4), Size = UDim2.new(0.45, -6, 0, 8)})
local coinPill = K.button(top, {Text = "💰 0", Size = UDim2.fromOffset(150, 50), LayoutOrder = 2, Max = 24, Tip = "💰 Coins",
	TipText = "Sell berries at the stall. Spend coins in the Shop."}, nil)
local function refreshTop()
	local hl = heroLevel()
	heroText.Text = ("⚔️ Lv %d"):format(hl)
	heroFill.Size = UDim2.fromScale(hl >= Data.HeroMax and 1 or math.clamp((player:GetAttribute("HeroXp") or 0) / Data.HeroNeed(hl), 0, 1), 1)
	lvText.Text = ("🏡 Farm Lv %d"):format(farmLevel())
	local cur, nxt = player:GetAttribute("FarmXp") or 0, player:GetAttribute("FarmXpNext")
	lvFill.Size = UDim2.fromScale(nxt and math.clamp(cur / nxt, 0, 1) or 1, 1)
	local ls = player:FindFirstChild("leaderstats")
	local c = ls and ls:FindFirstChild("Coins")
	coinPill.Text = "💰 " .. commas(c and c.Value or 0)
end
for _, a in {"FarmLevel", "FarmXp", "FarmXpNext", "HeroLv", "HeroXp"} do player:GetAttributeChangedSignal(a):Connect(refreshTop) end
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	ls:WaitForChild("Coins").Changed:Connect(refreshTop)
	refreshTop()
end)

-- 🛠 Dev menu: its own button, Studio only (temporary test tools)
if RunService:IsStudio() then
	K.button(gui, {Text = "🛠 Dev", Position = UDim2.fromOffset(16, 124), Size = UDim2.fromOffset(110, 44), Kind = "special", Tip = "🛠 Dev menu",
		TipText = "Test tools (only in Studio)"}, function() bridge:Fire("Dev") end)
end

---------------------------------------------------------------- the one window
local win = K.window(gui, {})
local current, currentTab = nil, {}
local render -- render(name)
local renderGen = 0 -- bumps on every render, so a slow (waiting) render can tell it is out of date
local function openWin(name, tab)
	if current == name and win.frame.Visible and not tab then
		win.close()
		return
	end
	current = name
	if tab then currentTab[name] = tab end
	if os.clock() - stateAt > 4 then stateEvent:FireServer() end -- only ask for a fresh state when ours is old (a full refresh is heavy)
	win.open()
	render(name)
end
win.onClose = function() current = nil end
local function setTab(name, t)
	currentTab[name] = t
	render(name)
end
local function viaBridge(cmd, arg)
	win.close()
	bridge:Fire(cmd, arg)
end

-- 🌀 every trip goes through a portal (the server says so if you're not standing at one)
local function travel(kind, arg)
	local res = act("PortalGo", kind, arg)
	if type(res) == "string" then toast(res, false) return end
	win.close()
	local fl = K.frame(gui, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 180, 255), ZIndex = 200})
	game:GetService("TweenService"):Create(fl, TweenInfo.new(0.7), {BackgroundTransparency = 1}):Play()
	task.delay(0.75, function() fl:Destroy() end)
end

---------------------------------------------------------------- "ready now" items (used by 🔔 and its badge)
local function eggsReady()
	local list = {}
	for _, e in state and state.Eggs or {} do
		if e.HatchAt and os.time() >= e.HatchAt then table.insert(list, e) end
	end
	return list
end
local function nextGift()
	local got = {}
	for i in (player:GetAttribute("PlayGot") or ""):gmatch("%d+") do got[tonumber(i)] = true end
	for i, g in Data.PlayGifts do
		if not got[i] then return i, g end
	end
end
local function readyItems()
	local items = {}
	local function add(t) table.insert(items, t) end
	local step = player:GetAttribute("JourneyStep")
	if step then
		add({Icon = "🧭", Title = ("Journey %d/%d: %s"):format(step, #Data.Journey, player:GetAttribute("JourneyText") or ""),
			Sub = "Follow the glowing arrow", Button = {Text = "Show me", Kind = "special"}, Fn = function() win.close() end})
	end
	local i, g = nextGift()
	local start = player:GetAttribute("PlayStart")
	if i and start then
		local left = start + g.Min * 60 / scale() - os.time()
		if left <= 0 then
			add({Icon = "🎁", Title = ("%d minute gift"):format(g.Min), Sub = "Thanks for playing!", Button = {Text = "Open", Kind = "go"}, Count = true,
				Fn = function() viaBridge("PlayGift") end})
		else
			add({Icon = "🎁", Title = ("Next gift in %s"):format(timeText(left)), Sub = "Keep playing to open it", Button = {Text = "⏱ " .. timeText(left), Kind = "no"},
				Fn = function() toast(("🎁 Your gift opens in %s"):format(timeText(left)), false) end})
		end
	end
	if player:GetAttribute("CalReady") then
		add({Icon = "📅", Title = "Daily box is ready", Sub = ("Day %d of 7"):format((player:GetAttribute("CalGot") or 0) % 7 + 1), Button = {Text = "Open"}, Count = true,
			Fn = function() viaBridge("Calendar") end})
	end
	local spins = player:GetAttribute("Spins") or 0
	if spins > 0 then
		add({Icon = "🎁", Title = ("%d prize pack%s"):format(spins, spins > 1 and "s" or ""), Sub = "Tear it open!", Button = {Text = "Open"}, Count = true,
			Fn = function() viaBridge("Spin") end})
	end
	for _, e in eggsReady() do
		local info = Data.Eggs[e.Kind] or Data.Eggs.Mystery
		add({Icon = info.Icon, Title = info.Name .. " is ready", Sub = "Tap to hatch it", Button = {Text = "Hatch"}, Count = true,
			Fn = function() viaBridge("Hatch", e.Id) end})
	end
	local mail = player:GetAttribute("MailCount") or 0
	if mail > 0 then
		add({Icon = "📬", Title = ("%d gift%s in your mailbox"):format(mail, mail > 1 and "s" or ""), Sub = "The mailbox is by your farm gate",
			Button = {Text = "Go there", Kind = "special"}, Count = true, Fn = function() travel("Home") end})
	end
	for qi, q in state and state.Quests or {} do
		if not q.Claimed and q.Progress >= q.Count then
			add({Icon = "📜", Title = "Quest done: " .. q.Text:format(q.Count), Sub = "Daily quest", Button = {Text = "Claim 💰" .. q.Reward}, Count = true,
				Fn = function() act("ClaimQuest", qi) toast("📜 +" .. q.Reward .. " coins!") stateEvent:FireServer() task.wait(0.2) render(current) end})
		end
	end
	for ni, q in state and state.NPC or {} do
		if q.Ready then
			local npc = Data.NPCs[ni]
			add({Icon = npc.Icon, Title = npc.Name .. " has a reward", Sub = "You finished the quest", Button = {Text = "Claim"}, Count = true,
				Fn = function() viaBridge("NPCClaim", ni) end})
		end
	end
	if (workspace:GetAttribute("LuckyUntil") or 0) > os.time() then
		add({Icon = "🍀", Title = "Lucky hour!", Sub = ("Double shiny chances for %s"):format(timeText(workspace:GetAttribute("LuckyUntil") - os.time()))})
	end
	local fruitWhere = workspace:GetAttribute("FruitWhere")
	if fruitWhere then
		local place = fruitWhere:match("%s(%a+)$")
		add({Icon = "✨", Title = "Rare fruit in " .. fruitWhere, Sub = "First one to grab it keeps it", Button = {Text = "Go", Kind = "special"},
			Fn = function() travel("Place", place) end})
	end
	local ev = workspace:GetAttribute("Event")
	if ev then
		add({Icon = (Data.EventByName[ev] or {}).Icon or "🎉", Title = "Event on now: " .. ev:gsub("(%l)(%u)", "%1 %2"), Sub = "Join in for prizes",
			Button = {Text = "🚀 Go", Kind = "special"}, Fn = function() travel("Event") end})
	end
	return items
end

---------------------------------------------------------------- 🔔 To do (quests live here)
local RENDER = {}
RENDER.Todo = function()
	win.setTitle("🔔", "To do")
	win.setSub("Rewards waiting and today's quests")
	local ready = 0
	for _, it in readyItems() do if it.Count then ready += 1 end end
	local questsDone = 0
	for _, q in state and state.Quests or {} do if not q.Claimed and q.Progress >= q.Count then questsDone += 1 end end
	local tab = currentTab.Todo or "Ready"
	win.setTabs({{"Ready", "✨ Ready now", "Gifts, eggs and rewards you can get now", ready > 0 and ready or nil},
		{"Daily", "📜 Daily quests", "3 new quests every day", questsDone > 0 and questsDone or nil},
		{"Helpers", "🧑‍🌾 Helpers", "Quest stories from Fern, Pip and Bun"},
		{"Journey", "🧭 Journey", "Your first steps on the farm"},
		{"More", "⚙️ More", "Titles and settings"}}, tab, function(t) setTab("Todo", t) end)
	win.setHelp({{"✨", "Rewards you can get right now show up here."}, {"📜", "Do daily quests for coins. New ones come every day."},
		{"🧑‍🌾", "Helpers in the plaza give quest stories with big prizes."}})
	win.clear()
	local body = win.body
	if tab == "Ready" then
		local items = readyItems()
		for i, it in items do
			it.Order = i
			K.row(body, it)
		end
		if #items == 0 then K.empty(body, "🌈", "All caught up! Go farm or explore.", "🏡 Go to my farm", function() travel("Home") end) end
	elseif tab == "Daily" then
		local now = os.time()
		local nextDay = (math.floor(now / 86400) + 1) * 86400
		K.header(body, "📜 Daily quests", 0, ("New quests in %s   🔥 Streak: day %d"):format(timeText(nextDay - now), state and state.Streak or 1))
		for qi, q in state and state.Quests or {} do
			local done = q.Progress >= q.Count
			local btn = q.Claimed and {Text = "✔ Claimed", Kind = "no"} or (done and {Text = "Claim 💰" .. q.Reward, Kind = "go"} or {Text = "💰" .. q.Reward, Kind = "no",
				Tip = "Reward", TipText = "Finish the quest to claim it"})
			K.row(body, {Order = qi, Icon = q.Claimed and "✅" or "📜", Title = q.Text:format(q.Count), Progress = {q.Progress, q.Count}, Button = btn,
				Fn = function()
					if q.Claimed then return end
					if not done then toast(("Keep going! %d more to go."):format(q.Count - q.Progress), false) return end
					act("ClaimQuest", qi)
					toast("📜 +" .. q.Reward .. " coins!")
					stateEvent:FireServer()
					task.wait(0.25)
					render("Todo")
				end})
		end
	elseif tab == "Helpers" then
		K.header(body, "🧑‍🌾 Helpers in the plaza", 0, "Finish their quests one by one for bigger and bigger prizes")
		local myGen = renderGen
		local infos = helperInfo
		if os.clock() - helperAt > 5 then -- ask the server again only when our copy is old
			local fresh, waiting = {}, #Data.NPCs
			for i in Data.NPCs do
				task.spawn(function() fresh[i] = act("NPCInfo", i) waiting -= 1 end) -- all three at once, not one after another
			end
			local t0 = os.clock()
			while waiting > 0 and os.clock() - t0 < 3 do task.wait() end
			helperInfo, helperAt, infos = fresh, os.clock(), fresh
		end
		-- another render started while we waited (state updates re-render the window): that one draws the list, not us
		if myGen ~= renderGen or current ~= "Todo" or currentTab.Todo ~= "Helpers" then return end
		for i, npc in Data.NPCs do
			local info = infos[i]
			if info and info.Done then
				K.row(body, {Order = i, Icon = npc.Icon, Title = npc.Name, Sub = "🎉 All quests done. Thank you!"})
			elseif info then
				local ready = info.Prog >= info.Count
				K.row(body, {Order = i, Icon = npc.Icon, Title = ("%s · %d/%d"):format(npc.Name, info.Step, info.Total), Sub = info.Text,
					Button = ready and {Text = "Claim"} or {Text = "🎁 " .. PackOpen.PrizeName(Data, info.Prize), Kind = "no", Tip = "Reward", TipText = ("%d/%d done"):format(info.Prog, info.Count)},
					Fn = function()
						if ready then viaBridge("NPCClaim", i) else toast(("%s: %d/%d done. Keep going!"):format(npc.Name, info.Prog, info.Count), false) end
					end})
			end
		end
	elseif tab == "Journey" then
		local step = player:GetAttribute("JourneyStep") or (#Data.Journey + 1)
		K.header(body, "🧭 Starter Journey", 0, step > #Data.Journey and "🎉 You finished it!" or "Follow the glowing arrow in the world")
		for i, st in Data.Journey do
			local done, now = i < step, i == step
			K.row(body, {Order = i, Icon = done and "✅" or (now and "👉" or "⬜"), Title = st.Text,
				Sub = "Prize: " .. (st.Prize.Type == "Pet" and "a Rare pet!" or PackOpen.PrizeName(Data, st.Prize)),
				Progress = now and {player:GetAttribute("JourneyProg") or 0, st.Count} or nil})
		end
	else
		K.row(body, {Order = 1, Icon = "🏷️", Title = "Titles", Sub = "Pick the title over your head", Button = {Text = "Open"}, Fn = function() viaBridge("Titles") end})
		K.row(body, {Order = 2, Icon = "📅", Title = "7-day gifts", Sub = "One box every day you play", Button = {Text = "Open"}, Fn = function() viaBridge("Calendar") end})
	end
end

---------------------------------------------------------------- 🐾 Pets
local petFilter, petSort = "Farm", "Best"
local function rarityOrder(p) return Data.Rarities[p.Rarity].Order end
local STATUS = function(p)
	if p.Trip then return "🎒 exploring" end
	if p.Nest then return "💕 in the nest" end
	if p.Riding then return "🐎 riding" end
	if p.Nap then return "💤 napping" end
	if p.Follow then return "👣 buddy" end
	if p.Stored then return "📦 storage" end
	if p.Working then return "🧺 working" end
	return "🪑 resting"
end
RENDER.Pets = function()
	local pets = state and state.Pets or {}
	local onFarm = 0
	for _, p in pets do if not p.Stored then onFarm += 1 end end
	win.setTitle("🐾", "Pets")
	win.setSub(("%d pets · %d/%d on your farm · 💪 Power %s"):format(#pets, onFarm, state and state.FarmCap or 5, commas(player:GetAttribute("FarmPower"))))
	local tab = currentTab.Pets or "Mine"
	local eggsN = #eggsReady()
	win.setTabs({{"Mine", "🐾 My pets", "All your pets. Tap one to see it."}, {"Eggs", "🥚 Eggs", "Eggs hatch over time", eggsN > 0 and eggsN or nil},
		{"Nest", "💕 Nest", "Two pets make a Friend Egg"}, {"Gear", "🛡️ Gear", "Make pets stronger"}, {"Book", "📖 Book", "Every critter you found"}},
		tab, function(t) setTab("Pets", t) end)
	win.setHelp({{"🐾", "Catch critters in the wild lands (🌀 Explorer's Portal) with berries, or hatch eggs."}, {"🏡", "Pets on your farm work for you. The rest wait in storage."},
		{"⭐", "Feed and pet them to level up. Babies grow into adults!"}})
	win.clear()
	local body = win.body
	if tab == "Mine" then
		local bar = K.frame(body, {Size = UDim2.new(1, -8, 0, 46), BackgroundTransparency = 1, LayoutOrder = 0})
		K.list(bar, Enum.FillDirection.Horizontal, 8)
		for i, f in {{"Farm", ("🏡 On farm %d"):format(onFarm)}, {"Storage", ("📦 Storage %d"):format(#pets - onFarm)}, {"All", "🐾 All"}} do
			local b = K.button(bar, {Text = f[2], LayoutOrder = i, Size = UDim2.fromOffset(150, 44), BackgroundColor3 = petFilter == f[1] and Color3.fromRGB(255, 225, 130) or K.CARD},
				function() petFilter = f[1] render("Pets") end)
		end
		K.button(bar, {Text = petSort == "Best" and "⬇ Best first" or "⬇ Highest level", LayoutOrder = 9, Size = UDim2.fromOffset(170, 44), Tip = "Sort",
			TipText = "Tap to change the order"}, function() petSort = petSort == "Best" and "Level" or "Best" render("Pets") end)
		local list = {}
		for _, p in pets do
			if petFilter == "All" or (petFilter == "Farm") == (not p.Stored) then table.insert(list, p) end
		end
		table.sort(list, function(a, b)
			if petSort == "Best" and rarityOrder(a) ~= rarityOrder(b) then return rarityOrder(a) > rarityOrder(b) end
			if a.Level ~= b.Level then return a.Level > b.Level end
			return a.Id < b.Id
		end)
		local g = K.grid(body, UDim2.fromOffset(150, 190), 1)
		for i, p in list do
			local rc = Data.Rarities[p.Rarity].Color
			local v = p.Variant and Data.VariantByName[p.Variant]
			K.card(g, {Order = i, Color = rc, Name = (v and v.Icon or "") .. (p.Name or p.Species), Sub = ("Lv %d · %s"):format(p.Level, STATUS(p)),
				Art = function(pic)
					local vf = CritterUI.Portrait(pic, Data, p.Species, {Size = UDim2.fromScale(1, 1), ZIndex = pic.ZIndex + 1}, {Variant = p.Variant, Outfit = p.Outfit})
					CritterUI.Animate(vf, "idle")
				end,
				Button = {Text = "See pet", Kind = "plain"}, Fn = function() viaBridge("PetProfile", p.Id) end,
				CardFn = function() viaBridge("PetProfile", p.Id) end,
				Tip = p.Name or p.Species, TipText = ("%s %s · %s"):format(p.Rarity, p.Species, Data.SpeciesByName[p.Species].JobText)})
		end
		K.card(g, {Order = 9999, Icon = "➕", Name = "Get more pets", Sub = "Wild lands or eggs", Button = {Text = "How?", Kind = "special"},
			Fn = function() toast("🍓 Go through the 🌀 Explorer's Portal and offer berries to wild critters, or hatch eggs!") end})
	elseif tab == "Eggs" then
		local luck = player:GetAttribute("Luck") or 0
		local r = K.row(body, {Order = 0, Icon = "🍀", Title = luck >= Data.LuckMax and "Luck meter FULL!" or ("Luck meter %d/%d"):format(luck, Data.LuckMax),
			Sub = "Full = your next egg is Epic or better", Progress = {luck, Data.LuckMax}})
		local eggs = state and state.Eggs or {}
		for i, e in eggs do
			local info = Data.Eggs[e.Kind] or Data.Eggs.Mystery
			local ready = e.HatchAt and os.time() >= e.HatchAt
			K.row(body, {Order = i, Icon = info.Icon, Title = info.Name .. (e.From and (" (" .. e.From .. ")") or ""),
				Sub = ready and "Ready to hatch!" or (e.HatchAt and ("Hatches in " .. timeText(e.HatchAt - os.time())) or "Waiting for a free nest spot"),
				Button = ready and {Text = "🐣 Hatch"} or {Text = e.HatchAt and ("⏱ " .. timeText(e.HatchAt - os.time())) or "⏸ Waiting", Kind = "no"},
				Fn = function()
					if ready then viaBridge("Hatch", e.Id) else toast(("Only %d eggs warm up at once. This one is waiting its turn."):format(Data.IncubatorSlots), false) end
				end})
		end
		if #eggs == 0 then K.empty(body, "🥚", "No eggs yet. Expeditions, events and gifts bring eggs!", nil, nil, 1) end
	elseif tab == "Nest" then
		if farmLevel() < Data.ButtonUnlocks.Nest then
			K.empty(body, "🔒", ("The Best Friends Nest opens at farm level %d"):format(Data.ButtonUnlocks.Nest))
		else
			local pair = {}
			for _, p in pets do if p.Nest then table.insert(pair, p) end end
			if #pair >= 2 then
				K.row(body, {Order = 1, Icon = "💕", Title = ("%s + %s are cuddling"):format(pair[1].Name or pair[1].Species, pair[2].Name or pair[2].Species),
					Sub = "Friend Egg in " .. timeText((pair[1].Nest or 0) - os.time()) .. " · cheer at the nest to speed it up", Button = {Text = "Open nest"},
					Fn = function() viaBridge("Nest") end})
			else
				K.empty(body, "💕", "Pick 2 pets. They cuddle and make a Friend Egg (both stay!)", "💕 Pick 2 pets", function() viaBridge("Nest") end)
			end
		end
	elseif tab == "Gear" then
		K.row(body, {Order = 0, Icon = "🔨", Title = "Make new gear", Sub = "At the workbench, with resources from the wild", Button = {Text = "Make gear", Kind = "special"},
			Fn = function() viaBridge("Bench", "Gear") end})
		for i, gItem in state and state.Gear or {} do
			local def = Data.Gear[gItem.Kind]
			K.row(body, {Order = i, Icon = def.Icon, Title = gItem.Text, Sub = gItem.WornBy and ("Worn by " .. gItem.WornBy) or "Not worn: equip it from a pet's Gear tab",
				Button = (gItem.Level or 0) < Data.GearMaxLevel and {Text = "⭐ Power up", Kind = "go", Tip = "Power up", TipText = "Make it stronger. It can fail!"}
					or {Text = "⭐ MAX", Kind = "no"},
				Fn = function() if (gItem.Level or 0) < Data.GearMaxLevel then viaBridge("PowerUp", gItem.Id) end end})
		end
		if #(state and state.Gear or {}) == 0 then K.empty(body, "🛡️", "No gear yet. Make some, or win ⚔️ raids!", nil, nil, 1) end
	else
		local found, total = 0, 0
		for _, s in Data.Species do
			total += 1
			if state and state.Found and state.Found[s.Species] then found += 1 end
		end
		K.row(body, {Order = 0, Icon = "📖", Title = ("You found %d of %d critters"):format(found, total), Progress = {found, total}})
		K.empty(body, "📖", "See every critter, and the ones still hiding.", "📖 Open the book", function() viaBridge("Book") end, 1)
	end
end

---------------------------------------------------------------- 🏡 Farm
local craftInfo
RENDER.Farm = function()
	win.setTitle("🏡", "Farm")
	win.setSub("Make your farm yours")
	local tab = currentTab.Farm or "Decor"
	win.setTabs({{"Decor", "🌷 Decorate", "Buy and place decorations"}, {"Plots", "🌱 Plots and soil", "More plots and better soil"},
		{"Bag", "🎒 Bag", "Your resources and berries"}, {"Toys", "🫧 Toys", "Fun things to play with"}}, tab, function(t) setTab("Farm", t) end)
	win.setHelp({{"🌷", "Buy decorations, then place them anywhere on your farm."}, {"💦", "Sprinklers water plants. Beehives make them grow faster."},
		{"🌱", "Unlock more plots and upgrade the soil for faster, luckier crops."}})
	win.clear()
	local body = win.body
	craftInfo = act("CraftInfo") or {Res = {}, DecorInv = {}, Tool = 0, Toys = {}}
	local function have(cost)
		local ls = player:FindFirstChild("leaderstats")
		local coins = ls and ls:FindFirstChild("Coins")
		if (cost.Coins or 0) > (coins and coins.Value or 0) then return false, ("%d more coins"):format((cost.Coins or 0) - (coins and coins.Value or 0)) end
		for _, r in Data.Resources do
			local need = (cost[r.Name] or 0) - ((craftInfo.Res or {})[r.Name] or 0)
			if need > 0 then return false, ("%d more %s %s"):format(need, r.Icon, r.Name) end
		end
		return true
	end
	if tab == "Decor" then
		if farmLevel() < Data.ButtonUnlocks.Decorate and player:GetAttribute("JourneyKind") ~= "Decor" then
			K.empty(body, "🔒", ("Decorating opens at farm level %d"):format(Data.ButtonUnlocks.Decorate))
			return
		end
		K.row(body, {Order = 0, Icon = "✋", Title = "Move or pick up decorations", Sub = "Opens decorate mode on your farm", Button = {Text = "Decorate", Kind = "special"},
			Fn = function() viaBridge("Decorate") end})
		local g = K.grid(body, UDim2.fromOffset(150, 200), 1)
		for i, d in Data.Decor do
			if Data.DecorLocked and Data.DecorLocked(d.Name, craftInfo.Scrolls) and ((craftInfo.DecorInv or {})[d.Name] or 0) == 0 then continue end -- (📜 not found yet)
			local n = (craftInfo.DecorInv or {})[d.Name] or 0
			local can, why = have(d.Cost)
			local btn, fn
			if n > 0 then
				btn, fn = {Text = ("Place (x%d)"):format(n), Kind = "go"}, function() viaBridge("Decorate", d.Name) end
			elseif can then
				btn, fn = {Text = "Buy " .. Data.CostText(d.Cost), Kind = "go"}, function()
					local res = act("BuyDecor", d.Name)
					if type(res) == "table" and res.Ok then toast(("%s %s bought! Tap Place to put it down."):format(d.Icon, d.Name)) else toast(type(res) == "table" and res.Error or "❌", false) end
					render("Farm")
				end
			else
				btn, fn = {Text = "Need " .. why, Kind = "no"}, function() toast(("%s %s costs %s. You need %s."):format(d.Icon, d.Name, Data.CostText(d.Cost), why), false) end
			end
			K.card(g, {Order = i, Icon = d.Icon, Name = d.Name, Sub = d.Effect == "Water" and "Waters plots nearby" or (d.Effect == "Grow" and "Plots nearby grow faster"
				or (n > 0 and ("You have %d"):format(n) or Data.CostText(d.Cost))), Button = btn, Fn = fn, Tip = d.Name, TipText = Data.CostText(d.Cost)})
		end
	elseif tab == "Plots" then
		K.row(body, {Order = 1, Icon = "🌱", Title = ("Plots open: %d of 15"):format(craftInfo.PlotsOpen or Data.StartPlots), Sub = "Tap a 🔓 sign on your farm to open the next one",
			Progress = {craftInfo.PlotsOpen or Data.StartPlots, 15}})
		K.row(body, {Order = 2, Icon = "🟫", Title = "Soil upgrades", Sub = "Dirt → Rich → Magic → Star Soil: faster and luckier crops", Button = {Text = "Upgrade soil"},
			Fn = function() viaBridge("Bench", "Farm") end})
	elseif tab == "Bag" then
		local tool = Data.Tools[craftInfo.Tool or 0]
		K.row(body, {Order = 0, Icon = tool.Icon, Title = "Tool: " .. tool.Name, Sub = "Better tools break harder rocks and ores", Button = {Text = "Make tools", Kind = "special"},
			Fn = function() viaBridge("Bench", "Tools") end})
		K.header(body, "Resources", 1, "Gather them in the wild places")
		local g = K.grid(body, UDim2.fromOffset(120, 120), 2)
		for i, r in Data.Resources do
			local n = (craftInfo.Res or {})[r.Name] or 0
			local c = K.card(g, {Order = i, Icon = r.Icon, Name = r.Name, Sub = "x" .. n, Tip = r.Name, TipText = ("You have %d"):format(n)})
		end
		K.header(body, "Berries", 3, "Sell them, feed pets or use them to make friends")
		local g2 = K.grid(body, UDim2.fromOffset(120, 120), 4)
		local basket = player:FindFirstChild("Basket")
		for i, crop in Data.Crops do
			local v = basket and basket:FindFirstChild(crop.Name)
			if v and (v.Value > 0 or i <= Data.BaseBerries) then K.card(g2, {Order = i, Icon = crop.Icon, Name = crop.Name, Sub = "x" .. v.Value}) end
		end
	else
		for i, t in Data.Toys do
			local owned = (craftInfo.Toys or {})[t.Name] or not t.Cost
			K.row(body, {Order = i, Icon = t.Icon, Title = t.Name, Sub = owned and "Yours! Tap Use to play" or Data.CostText(t.Cost),
				Button = owned and {Text = "Use"} or {Text = "Buy " .. Data.CostText(t.Cost), Kind = have(t.Cost) and "go" or "no"},
				Fn = function()
					if owned then
						win.close()
						act("UseToy", t.Name)
					else
						local res = act("BuyToy", t.Name)
						if type(res) == "table" and res.Ok then toast(t.Icon .. " " .. t.Name .. " is yours!") else toast(type(res) == "table" and res.Error or ("Need " .. Data.CostText(t.Cost)), false) end
						render("Farm")
					end
				end})
		end
	end
end

---------------------------------------------------------------- 🗺️ World
local PLACES = {
	{Name = "My island", Icon = "🏡", Info = "Your plots, pets and mailbox", Home = true},
	{Name = "Plaza", Icon = "⛲", Info = "Market street, boutique, festival green and craft corner"},
	{Name = "TerrainPortal", Title = "Explorer's Portal", Icon = "🌀", Info = "Explore wild lands, solo or with friends"},
	{Name = "DungeonPortal", Title = "Dungeon Portal", Icon = "🏰", Info = "Team up (1-4) and beat a dungeon boss"},
	{Name = "Pond", Title = "Fishing pond", Icon = "🎣", Info = "Next to the Explorer's Portal"},
}
local EVENT_INFO = {
	FallingStar = "A star crashes down. Grab the big shard first!", CatchRace = "Tag the shiny runner 3 times to win it.",
	WorldBoss = "Tap the giant boss with everyone. Dodge the red circles!", PresentRush = "Presents rain on the plaza.",
	EggSnatch = "Carry the golden egg to the 🌀 Explorer's Portal. Others can tag you!",
}
RENDER.World = function()
	win.setTitle("🗺️", "World")
	win.setSub("Go places, visit friends, join events")
	local tab = currentTab.World or "Places"
	win.setTabs({{"Places", "📍 Places", "Travel around the world"}, {"Farms", "🏡 Farms", "Visit, trade and send gifts"},
		{"Fish", "🎣 Fish book", "Every fish you caught"}, {"Events", "🎉 Events", "Fun things that happen for everyone"}}, tab, function(t) setTab("World", t) end)
	win.setHelp({{"🌀", "Walk into a portal, then pick where to go. Wild lands are behind the 🌀 Explorer's Portal."}, {"🌰", "30 golden acorns are hidden around the world."},
		{"🎉", "Events happen every few minutes. Join for prizes!"}})
	win.clear()
	local body = win.body
	if tab == "Places" then
		K.row(body, {Order = 0, Icon = "🌰", Title = ("Golden acorns %d/%d"):format(player:GetAttribute("AcornCount") or 0, Data.AcornCount),
			Sub = "Hidden on rocks, mushrooms and in corners", Progress = {player:GetAttribute("AcornCount") or 0, Data.AcornCount}})
		local open = {}
		for n in (player:GetAttribute("Gates") or ""):gmatch("[^,]+") do open[n] = true end
		for i, pl in PLACES do
			local g = pl.Gate and Data.Gates[pl.Name]
			local btn, fn
			if pl.Home then
				btn, fn = {Text = "🏡 Go home"}, function() travel("Home") end
			elseif not g or open[pl.Name] then
				btn, fn = {Text = "Go"}, function() travel("Place", pl.Name) end
			elseif farmLevel() < g.Level then
				btn, fn = {Text = "🔒 Lv " .. g.Level, Kind = "no"}, function() toast(("🔒 The %s opens at farm level %d."):format(pl.Name, g.Level), false) end
			else
				btn, fn = {Text = "🌀 Portal", Kind = "special"}, function()
					toast(("The %s is open! Go through the 🌀 Explorer's Portal."):format(pl.Name))
				end
			end
			K.row(body, {Order = i, Icon = pl.Icon, Title = pl.Title or pl.Name, Sub = pl.Info, Button = btn, Fn = fn})
		end
	elseif tab == "Farms" then
		local fl = player:GetAttribute("FriendLuck") or 0
		if fl > 0 then K.row(body, {Order = 0, Icon = "👫", Title = ("Friends here: +%d%% luck"):format(fl), Sub = "Shinies, catching and fishing"}) end
		local list = act("Farms") or {}
		table.sort(list, function(a, b) return a.Likes > b.Likes end)
		for i, f in list do
			local r = K.row(body, {Order = i, Icon = f.Mine and "⭐" or "🏡", Title = f.Mine and "My farm" or (f.Name .. "'s farm"),
				Sub = ("Lv %d · ❤️ %d likes%s"):format(f.Level, f.Likes, f.Liked and " · you liked it" or ""),
				Button = f.Mine and {Text = "🏡 Go home"} or {Text = "Visit"},
				Fn = function() if f.Mine then travel("Home") else travel("Visit", f.UserId) end end})
			if not f.Mine then
				K.button(r, {Text = "🤝", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -172, 0.5, 0), Size = UDim2.fromOffset(48, 48), Tip = "Trade",
					TipText = "Ask to trade pets"}, function() local m = act("TradeRequest", f.UserId) if m then toast(m) end end)
				K.button(r, {Text = "💌", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -226, 0.5, 0), Size = UDim2.fromOffset(48, 48), Tip = "Send a gift",
					TipText = "It arrives in their mailbox"}, function() viaBridge("Gift") end)
			end
		end
		if #list <= 1 then K.empty(body, "👫", "Invite friends! Friends in the same server give you more luck.", nil, nil, 99) end
	elseif tab == "Fish" then
		local book = act("FishBook") or {}
		local caught = 0
		for _ in book do caught += 1 end
		K.row(body, {Order = 0, Icon = "🎣", Title = ("Fish found %d of %d"):format(caught, #Data.Fish), Sub = "Fish at the pond by the Explorer's Portal", Progress = {caught, #Data.Fish},
			Button = {Text = "Go fishing", Kind = "special"}, Fn = function() travel("Place", "Pond") end})
		local g = K.grid(body, UDim2.fromOffset(130, 150), 1)
		for i, f in Data.Fish do
			local n = book[f.Name]
			K.card(g, {Order = i, Icon = n and f.Icon or "❔", Name = n and f.Name or "???", Sub = n and ("x%d · %s"):format(n, f.Rarity) or f.Rarity,
				Color = Data.Rarities[f.Rarity].Color})
		end
	else
		local ev = workspace:GetAttribute("Event")
		local nextEv, at = workspace:GetAttribute("EventNext"), workspace:GetAttribute("EventAt")
		if ev then
			K.row(body, {Order = 0, Icon = (Data.EventByName[ev] or {}).Icon or "🎉", Title = "On now: " .. ev:gsub("(%l)(%u)", "%1 %2"), Sub = EVENT_INFO[ev] or "",
				Button = {Text = "🚀 Go", Kind = "special"}, Fn = function() travel("Event") end})
		elseif nextEv and at then
			K.row(body, {Order = 0, Icon = (Data.EventByName[nextEv] or {}).Icon or "🎉", Title = "Starting soon: " .. nextEv:gsub("(%l)(%u)", "%1 %2"),
				Sub = "in " .. timeText(at - os.time())})
		else
			K.row(body, {Order = 0, Icon = "⏱", Title = "The next event is coming", Sub = "Events happen every few minutes"})
		end
		K.header(body, "All events", 1)
		for i, e in Data.Events do
			K.row(body, {Order = 1 + i, Icon = e.Icon, Title = e.Name:gsub("(%l)(%u)", "%1 %2"), Sub = EVENT_INFO[e.Name] or ""})
		end
	end
end

---------------------------------------------------------------- 🛒 Shop
local shopInfo
RENDER.Shop = function()
	win.setTitle("🛒", "Shop")
	local tab = currentTab.Shop or "Seeds"
	shopInfo = act("ShopInfo") or shopInfo
	local info = shopInfo
	local left = math.max(0, (workspace:GetAttribute("ShopRestockAt") or os.time()) - os.time())
	win.setSub(("New seeds in %s"):format(timeText(left)))
	win.setTabs({{"Seeds", "🌱 Seeds", "Seeds restock every few minutes"},
		{"Eggs", "🥚 Eggs", "New eggs every hour. Rare ones are, well, rare!"},
		{"Packs", info and info.FreePacks > 0 and "🎁 Packs (free!)" or "🎁 Packs", "Random seeds, some only come from packs", info and info.FreePacks > 0 and info.FreePacks or nil},
		{"Book", "📗 Seed book", "Collect every seed for prizes"}}, tab, function(t) setTab("Shop", t) end)
	win.setHelp({{"🌱", "Buy seeds, then pick them with the seed button on your farm."}, {"🥚", "New eggs every hour. Most are Common, Ultra Rare is super rare!"},
		{"🎁", "Packs give random seeds, even ones the shop never sells."}})
	win.clear()
	local body = win.body
	if not info then K.empty(body, "🛒", "The shop is opening...") return end
	if tab == "Seeds" then
		local g = K.grid(body, UDim2.fromOffset(150, 200), 1)
		for i, it in info.Items do
			local crop = Data.CropByName[it.Crop]
			local locked = info.Level < it.Unlock
			local soldOut = it.Left <= 0
			local btn = locked and {Text = "🔒 Lv " .. it.Unlock, Kind = "no"} or (soldOut and {Text = "Sold out", Kind = "no"} or {Text = "Buy 💰" .. it.Price, Kind = "go"})
			local c
			c = K.card(g, {Order = i, Icon = crop.Icon, Name = it.Crop, Color = Data.Rarities[crop.Rarity].Color,
				Sub = soldOut and "Come back later" or ((crop.Tree and "🌳 Tree · " or "") .. it.Left .. " left"), Button = btn,
				Tip = it.Crop, TipText = ("%s · sells for 💰%d each"):format(crop.Rarity, crop.Price),
				Fn = function()
					if locked then toast(("🔒 %s unlocks at farm level %d."):format(it.Crop, it.Unlock), false) return end
					if soldOut then toast("Sold out! New seeds come soon.", false) return end
					local res = act("BuySeed", it.Crop, 1)
					if type(res) == "table" and res.Ok then
						shopInfo = res.Info
						toast(crop.Icon .. " +1 " .. it.Crop .. " seed")
						render("Shop")
					else
						toast(type(res) == "table" and res.Error or "❌", false)
					end
				end})
		end
			if not info.Bell then
				K.card(g, {Order = 999, Icon = "🔔", Name = "Rare bell", Sub = "Rings when rare seeds arrive", Color = K.YELLOW,
					Button = {Text = "Buy 💰" .. Data.BellCost, Kind = "special"}, Tip = "🔔 Rare bell", TipText = "A big popup tells you when rare seeds are in the shop",
					Fn = function()
						local res = act("BuyBell")
						if type(res) == "table" and res.Ok then
							shopInfo = res.Info
							toast("🔔 You'll hear when rare seeds arrive!")
							render("Shop")
						else
							toast(type(res) == "table" and res.Error or "❌", false)
						end
					end})
			end
	elseif tab == "Eggs" then
		local eleft = math.max(0, (info.EggRestockAt or os.time()) - os.time())
		K.row(body, {Order = 0, Icon = "⏱", Title = "New eggs in " .. timeText(eleft), Sub = "Each egg can be bought once. It goes to your nest to hatch."})
		local g = K.grid(body, UDim2.fromOffset(150, 210), 1)
		local tierColor = {CommonEgg = Color3.fromRGB(200, 200, 200), UncommonEgg = Color3.fromRGB(110, 200, 95), RareEgg = Color3.fromRGB(90, 160, 255),
			UltraEgg = Color3.fromRGB(255, 190, 40)}
		local tierChance = {}
		for _, t in Data.EggShop.Tiers do tierChance[t.Egg] = t.Chance end
		for i, s in info.Eggs or {} do
			local e = Data.Eggs[s.Egg]
			local w = e.Weights
			local hatch = ("Hatches: Common %s%% · Rare %s%% · Epic %s%% · Legendary %s%%"):format(w.Common, w.Rare, w.Epic, w.Legendary)
			local coins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
			local can = not s.Bought and coins and coins.Value >= s.Price
			local btn = s.Bought and {Text = "✅ Bought", Kind = "no"} or (can and {Text = "Buy 💰" .. commas(s.Price), Kind = s.Price >= 5000 and "special" or "go"}
				or {Text = "Need 💰" .. commas(s.Price), Kind = "no"})
			K.card(g, {Order = i, Icon = e.Icon, Name = e.Name, Sub = ("%s%% in stock"):format(tierChance[s.Egg] * 100), Color = tierColor[s.Egg], Button = btn,
				Tip = e.Name, TipText = hatch,
				Fn = function()
					if s.Bought then toast("You already bought this one. New eggs every hour!", false) return end
					local res = act("BuyEgg", i)
					if type(res) == "table" and res.Ok then
						shopInfo = res.Info
						toast(e.Icon .. " " .. e.Name .. " is in your nest!")
						render("Shop")
					else
						toast(type(res) == "table" and res.Error or "❌", false)
					end
				end})
		end
		if #(info.Eggs or {}) == 0 then K.empty(body, "🥚", "The egg delivery is on its way...", nil, nil, 2) end
	elseif tab == "Packs" then
		local g = K.grid(body, UDim2.fromOffset(200, 230), 1)
		for i, pack in Data.SeedPacks do
			local free = pack.Name == "Basic" and info.FreePacks > 0
			local inside = {}
			for k, it in pack.Items do if k <= 3 then table.insert(inside, Data.CropByName[it.Crop].Icon) end end
			K.card(g, {Order = i, Icon = pack.Icon, Name = pack.Name .. " pack", Sub = table.concat(inside, " ") .. " and more", Color = pack.Color,
				Button = {Text = free and "Open free!" or ("Buy 💰" .. pack.Price), Kind = free and "special" or "go"},
				Fn = function()
					local res = act("BuyPack", pack.Name)
					if type(res) == "table" and res.Item then
						shopInfo = res.Info
						viaBridge("PackShow", res)
					else
						toast(type(res) == "table" and res.Error or "❌", false)
					end
				end})
		end
	else -- 📗 seed book: fill a row, get a prize
		for i, rowDef in Data.SeedBookRows do
			local st = info.Rows[i]
			local done = st.Have >= st.Need
			local row = K.frame(body, {Size = UDim2.new(1, -8, 0, 96), LayoutOrder = i, BackgroundColor3 = st.Claimed and Color3.fromRGB(230, 248, 220) or K.CARD})
			K.round(row, 16)
			K.stroke(row, done and not st.Claimed and K.YELLOW or K.LINE, done and not st.Claimed and 3 or 2)
			K.text(row, {Text = rowDef.Icon, Position = UDim2.fromOffset(8, 18), Size = UDim2.fromOffset(60, 60), Max = 44})
			local tiles = K.frame(row, {Position = UDim2.fromOffset(72, 12), Size = UDim2.new(1, -250, 0, 72), BackgroundTransparency = 1})
			K.list(tiles, Enum.FillDirection.Horizontal, 6)
			for k, cropName in rowDef.Crops do
				local crop = Data.CropByName[cropName]
				local got = info.SeedBook and info.SeedBook[cropName]
				local tile = K.text(tiles, {Text = got and crop.Icon or "❔", LayoutOrder = k, Size = UDim2.fromOffset(66, 66), BackgroundTransparency = 0, Max = 40,
					BackgroundColor3 = got and Data.Rarities[crop.Rarity].Color:Lerp(K.WHITE, 0.6) or Color3.fromRGB(235, 228, 215)})
				K.round(tile, 14)
				K.tip(tile, got and cropName or "❔ Not found yet", got and crop.Rarity or "Plant it once to fill this spot")
			end
			local reward = rowDef.Reward
			K.button(row, {Text = st.Claimed and "✅ Got it" or (done and ("🎁 Claim " .. Data.PrizeIcon(reward)) or ("%d/%d  %s"):format(st.Have, st.Need, Data.PrizeIcon(reward))),
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(160, 56),
				Kind = st.Claimed and "plain" or (done and "special" or "no"), Tip = "Row prize", TipText = "Plant every seed in this row to win it"}, function()
				if done and not st.Claimed then
					local res = act("ClaimSeedRow", i)
					if type(res) == "table" and res.Ok then shopInfo = res.Info render("Shop") end
				elseif not done then
					toast(("Plant %d more kinds of seed in this row."):format(st.Need - st.Have), false)
				end
			end)
		end
	end
end

---------------------------------------------------------------- 👗 Bow & Bell Boutique (clothes for you, hats for pets)
local boutiqueInfo
local function wearArt(name, slot)
	return function(pic)
		local m = CritterUI.BuildWear(name)
		if not m then return end
		local vf = Instance.new("ViewportFrame")
		vf.BackgroundTransparency = 1
		vf.Size = UDim2.fromScale(1, 1)
		vf.Ambient = Color3.fromRGB(200, 200, 200)
		vf.LightDirection = Vector3.new(-1, -1, -1)
		local cf, size = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() - cf.Position) -- center it
		m.Parent = vf
		local d = math.max(size.X, size.Y, size.Z) * 1.9 + 0.2
		local side = slot == "Back" and 1 or -1 -- back items face away from you
		local cam = Instance.new("Camera")
		cam.FieldOfView = 40
		cam.CFrame = CFrame.lookAt(Vector3.new(d * 0.35, d * 0.3, d * side), Vector3.zero)
		cam.Parent = vf
		vf.CurrentCamera = cam
		vf.Parent = pic
	end
end
RENDER.Boutique = function()
	win.setTitle("👗", "Bow & Bell Boutique")
	win.setSub("Clothes for you and your pets. Buy once, keep forever!")
	local tab = currentTab.Boutique or "Hat"
	win.setTabs({{"Hat", "🧢 Hats", "Hats, ears and crowns for you"}, {"Face", "👓 Glasses", "Fun glasses for you"},
		{"Back", "🎒 Backs", "Backpacks, capes and wings for you"}, {"Pets", "🐾 Pet hats", "Hats your pets can wear"}}, tab, function(t) setTab("Boutique", t) end)
	win.setHelp({{"🧢", "Buy clothes with coins. They're yours forever."}, {"👕", "Tap Wear to put it on. Tap again to take it off."},
		{"🐾", "Pet hats go on in 🐾 Pets: pick a pet, then its outfit."}})
	win.clear()
	local body = win.body
	boutiqueInfo = act("BoutiqueInfo") or boutiqueInfo
	local info = boutiqueInfo
	if type(info) ~= "table" then K.empty(body, "👗", "The boutique is opening...") return end
	local ls = player:FindFirstChild("leaderstats")
	local c = ls and ls:FindFirstChild("Coins")
	local have = c and c.Value or 0
	local g = K.grid(body, UDim2.fromOffset(150, 210), 1)
	local function done(res, msg)
		if type(res) == "table" and res.Ok then
			boutiqueInfo = res.Info
			if msg then toast(msg) end
			render("Boutique")
		else
			toast(type(res) == "table" and res.Error or "❌", false)
		end
	end
	local function buyBtn(price)
		if have >= price then return {Text = "Buy 💰" .. commas(price), Kind = price >= 5000 and "special" or "go"} end
		return {Text = "Need 💰" .. commas(price), Kind = "no"}
	end
	if tab == "Pets" then
		local list = {}
		for _, o in Data.Outfits do if not o.Limited then table.insert(list, o) end end
		table.sort(list, function(a, b)
			local pa, pb = Data.OutfitPrice[a.Rarity], Data.OutfitPrice[b.Rarity]
			if pa ~= pb then return pa < pb end
			return a.Name < b.Name
		end)
		for i, o in list do
			local price = Data.OutfitPrice[o.Rarity]
			local own = info.Outfits and info.Outfits[o.Name]
			K.card(g, {Order = i, Name = o.Name, Sub = own and "Yours!" or o.Rarity .. " pet hat", Color = Data.Rarities[o.Rarity].Color,
				Button = own and {Text = "✅ Yours", Kind = "plain"} or buyBtn(price), Art = wearArt(o.Name, "Hat"),
				Tip = o.Icon .. " " .. o.Name, TipText = "Any of your pets can wear it. Put it on in 🐾 Pets.",
				Fn = function()
					if own then toast("Put it on a pet in 🐾 Pets!") return end
					if have < price then toast(("You need 💰%s for this."):format(commas(price)), false) return end
					done(act("BuyOutfit", o.Name), o.Icon .. " " .. o.Name .. " is yours! Put it on a pet in 🐾 Pets.")
				end})
		end
		return
	end
	local n = 0
	for _, w in Data.Wearables do
		if w.Slot == tab then
			n += 1
			local own = info.Own and info.Own[w.Name]
			local on = info.Wearing and info.Wearing[w.Slot] == w.Name
			local btn = on and {Text = "✅ Wearing", Kind = "special"} or (own and {Text = "👕 Wear", Kind = "go"} or buyBtn(w.Price))
			K.card(g, {Order = n, Name = w.Name, Sub = on and "Tap to take off" or (own and "Yours!" or w.Rarity), Color = Data.Rarities[w.Rarity].Color,
				Button = btn, Art = wearArt(w.Name, w.Slot),
				Tip = w.Icon .. " " .. w.Name, TipText = own and "Yours! Tap to wear it or take it off." or "Buy it once, keep it forever.",
				Fn = function()
					if own then
						done(act("WearItem", w.Name), on and "Taken off." or (w.Icon .. " Looking good!"))
					elseif have < w.Price then
						toast(("You need 💰%s for this."):format(commas(w.Price)), false)
					else
						done(act("BuyWear", w.Name), w.Icon .. " New look! You're wearing the " .. w.Name .. ".")
					end
				end})
		end
	end
end

---------------------------------------------------------------- 🌀 portal picker (opens when you walk into a portal)
RENDER.Portal = function()
	win.setTitle("🌀", "Portal")
	win.setSub("Where do you want to go?")
	win.setTabs({})
	win.setHelp({{"🌀", "Walk into a portal to travel."}, {"🏡", "Go home, to town, out to the wild or to a friend's island."},
		{"❤️", "Visit friends and like their farms!"}})
	win.clear()
	local body = win.body
	K.header(body, "Places", 1)
	local open = {}
	for n in (player:GetAttribute("Gates") or ""):gmatch("[^,]+") do open[n] = true end
	for i, pl in PLACES do
		local g = pl.Gate and Data.Gates[pl.Name]
		local btn, fn
		if pl.Home then
			btn, fn = {Text = "🏡 Go home", Kind = "special"}, function() travel("Home") end
		elseif not g or open[pl.Name] then
			btn, fn = {Text = "🌀 Go"}, function() travel(pl.Name == "Plaza" and "Town" or "Place", pl.Name) end
		elseif farmLevel() < g.Level then
			btn, fn = {Text = "🔒 Lv " .. g.Level, Kind = "no"}, function() toast(("🔒 The %s opens at farm level %d."):format(pl.Name, g.Level), false) end
		else
			btn, fn = {Text = "🌀 Portal", Kind = "special"}, function()
				toast(("The %s is open! Go through the 🌀 Explorer's Portal."):format(pl.Name))
			end
		end
		K.row(body, {Order = 1 + i, Icon = pl.Icon, Title = pl.Name == "Plaza" and "Town" or pl.Title or pl.Name, Sub = pl.Info, Button = btn, Fn = fn})
	end
	local ev = workspace:GetAttribute("Event")
	if ev then
		K.row(body, {Order = 30, Icon = (Data.EventByName[ev] or {}).Icon or "🎉", Title = "Event: " .. ev:gsub("(%l)(%u)", "%1 %2"), Sub = EVENT_INFO[ev] or "Join in for prizes",
			Button = {Text = "🚀 Go", Kind = "special"}, Fn = function() travel("Event") end})
	end
	K.header(body, "Friends' islands", 40)
	local list = act("Farms") or {}
	table.sort(list, function(a, b) return a.Likes > b.Likes end)
	local n = 0
	for i, f in list do
		if not f.Mine then
			n += 1
			K.row(body, {Order = 40 + i, Icon = "🏝️", Title = f.Name .. "'s island", Sub = ("Lv %d · ❤️ %d likes"):format(f.Level, f.Likes),
				Button = {Text = "Visit"}, Fn = function() travel("Visit", f.UserId) end})
		end
	end
	if n == 0 then K.empty(body, "👫", "Nobody else is here yet. Invite a friend!", nil, nil, 99) end
end
do -- walk into a portal: open the picker (once per visit, it re-arms when you step away)
	local armed, lastGate = true, nil
	task.spawn(function()
		local folder = workspace:WaitForChild("CritterAcres"):WaitForChild("Portals", 60)
		if not folder then return end
		local function hook(g)
			if not g:IsA("BasePart") or g.Name ~= "Gate" then return end
			g.Touched:Connect(function(hit)
				local char = player.Character
				if not armed or not char or not hit:IsDescendantOf(char) then return end
				armed, lastGate = false, g
				openWin("Portal")
			end)
		end
		for _, d in folder:GetDescendants() do hook(d) end
		folder.DescendantAdded:Connect(hook)
		while true do
			task.wait(0.3)
			if not armed then
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not hrp or not lastGate or not lastGate.Parent or (hrp.Position - lastGate.Position).Magnitude > 14 then armed = true end
			end
		end
	end)
end

function render(name)
	if not name or not RENDER[name] or not win.frame.Visible then return end
	local y = win.body.CanvasPosition
	renderGen += 1
	local ok, err = pcall(RENDER[name])
	if not ok then warn("CritterMenus", name, err) end
	win.body.CanvasPosition = y
end
stateEvent.OnClientEvent:Connect(function()
	if current and win.frame.Visible and (current == "Pets" or current == "Todo") then task.defer(render, current) end
end)

---------------------------------------------------------------- dock (top right, ends with 🔔 To do)
-- One row on wide screens. On small screens (player attribute HudCompact) it becomes 2 columns so it never runs into the
-- level pills on the left; TerrainPortal / Combat / BossFx move their top bars down to match.
local dock = K.frame(gui, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), BackgroundTransparency = 1})
local dockGrid = Instance.new("UIGridLayout")
dockGrid.SortOrder = Enum.SortOrder.LayoutOrder
dockGrid.Parent = dock
local DOCK_N = 7
local function layoutDock()
	local w = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X) or 1280
	local compact = w < 1060
	local cw, ch, pad = compact and 62 or 76, compact and 58 or 68, compact and 4 or 6
	local cols = compact and 2 or DOCK_N
	local rows = math.ceil(DOCK_N / cols)
	dockGrid.CellSize = UDim2.fromOffset(cw, ch)
	dockGrid.CellPadding = UDim2.fromOffset(pad, pad)
	dock.Size = UDim2.fromOffset(cols * cw + (cols - 1) * pad, rows * ch + (rows - 1) * pad)
	if player:GetAttribute("HudCompact") ~= compact then player:SetAttribute("HudCompact", compact) end
end
layoutDock()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutDock)
local dockButtons = {}
for i, d in {{"Pets", "🐾", "Pets", "Your pets, eggs, nest and gear  ·  key P"}, {"Farm", "🏡", "Farm", "Decorate, plots, bag and toys  ·  bag: key B"},
	{"World", "🗺️", "World", "Travel, friends' farms, fish and events  ·  map: key M"}, {"Shop", "🛒", "Shop", "Seeds and seed packs"},
	{"Weapons", "🛡️", "Gear", "Your gear, weapons and 🎁 capsules  ·  key G"}, {"Skills", "🌳", "Skills", "Your skill tree: 1 point per ⚔️ Hero Level  ·  key K"}} do
	dockButtons[d[1]] = K.iconButton(dock, d[2], d[3], {Size = UDim2.fromOffset(84, 74), LayoutOrder = i, Tip = d[2] .. " " .. d[3], TipText = d[4]},
		function()
			if d[1] == "Weapons" then bridge:Fire("Gear") return end -- (StarterPlayerScripts.HeroGear)
			if d[1] == "Skills" then bridge:Fire("Skills") return end -- (StarterPlayerScripts.SkillTree)
			openWin(d[1])
		end)
end
-- 🌳 badge: skill points waiting
local function skillBadge()
	local n = player:GetAttribute("SkillPts") or 0
	K.badge(dockButtons.Skills, n > 0 and n or nil)
end
player:GetAttributeChangedSignal("SkillPts"):Connect(skillBadge)
skillBadge()
local bell = K.iconButton(dock, "🔔", "To do", {Size = UDim2.fromOffset(76, 68), LayoutOrder = 7,
	Tip = "🔔 To do", TipText = "Rewards waiting, daily quests and helpers"}, function() openWin("Todo") end)

---------------------------------------------------------------- 🌱 seed button (only on your farm)
local function myFarm()
	local farms = root:FindFirstChild("Farms")
	for _, f in farms and farms:GetChildren() or {} do
		if f:GetAttribute("Owner") == player.UserId then return f end
	end
end
local seedBtn = K.button(gui, {Text = "", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(190, 60), Visible = false,
	Tip = "🌱 Your seed", TipText = "This is what you plant. Tap to pick another seed."}, nil)
local seedIcon = K.text(seedBtn, {Size = UDim2.new(0, 46, 1, 0), Max = 36})
local seedName = K.text(seedBtn, {Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -78, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Max = 20})
K.text(seedBtn, {Text = "▲", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 24, 1, 0), TextColor3 = K.SOFT, Max = 16})
local seedPick = K.frame(gui, {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -80), Size = UDim2.fromOffset(330, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = K.CREAM, Visible = false})
K.round(seedPick, 16)
K.stroke(seedPick, Color3.fromRGB(230, 205, 165), 2)
local function seedCount(name)
	if name == Data.FarmCrop then return nil end -- free, endless
	return player:GetAttribute(Data.SeedAttr(name)) or 0
end
local function refreshSeed()
	local name = player:GetAttribute("Seed") or Data.FarmCrop
	local crop = Data.CropByName[name] or Data.Crops[1]
	local n = seedCount(crop.Name)
	seedIcon.Text = crop.Icon
	seedName.Text = crop.Name .. (n and (" x" .. n) or " (free)")
end
local function renderSeedPick()
	for _, ch in seedPick:GetChildren() do
		if ch:IsA("GuiObject") or ch:IsA("UIGridLayout") or ch:IsA("UIPadding") then ch:Destroy() end
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = seedPick
	local gl = Instance.new("UIGridLayout", seedPick)
	gl.CellSize = UDim2.fromOffset(96, 86)
	gl.CellPadding = UDim2.fromOffset(8, 8)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	local chosen = player:GetAttribute("Seed") or Data.FarmCrop
	local any = 0
	for i, crop in Data.Crops do
		local n = seedCount(crop.Name)
		if n == nil or n > 0 then
			any += 1
			local b = K.iconButton(seedPick, crop.Icon, n and (crop.Name .. " x" .. n) or (crop.Name .. " free"), {Size = UDim2.fromOffset(96, 86), LayoutOrder = i,
				BackgroundColor3 = crop.Name == chosen and Color3.fromRGB(255, 225, 130) or K.CARD, Tip = crop.Name, TipText = ("%s · grows in %ds"):format(crop.Rarity, crop.Grow)},
				function()
					act("SelectSeed", crop.Name)
					seedPick.Visible = false
				end)
		end
	end
	K.button(seedPick, {Text = "🛒 More seeds", Size = UDim2.fromOffset(96, 86), LayoutOrder = 999, Kind = "special"}, function()
		seedPick.Visible = false
		openWin("Shop", "Seeds")
	end)
end
seedBtn.Activated:Connect(function()
	seedPick.Visible = not seedPick.Visible
	if seedPick.Visible then renderSeedPick() end
end)
player:GetAttributeChangedSignal("Seed"):Connect(refreshSeed)
for _, c in Data.Crops do player:GetAttributeChangedSignal(Data.SeedAttr(c.Name)):Connect(refreshSeed) end
refreshSeed()

---------------------------------------------------------------- 🐾 buddy button (tap to show the buddy's actions)
local buddyBtn = K.button(gui, {Text = "", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(76, 76), Visible = false,
	Tip = "👣 Your buddy", TipText = "Tap for Pet, Fetch and tricks"}, nil)
local buddyShown = false
local buddyKey
buddyBtn.Activated:Connect(function()
	buddyShown = not buddyShown
	bridge:Fire("Buddy", buddyShown)
end)
local function refreshBuddy()
	local p
	for _, q in state and state.Pets or {} do
		if q.Follow and not q.Trip then p = q end
	end
	buddyBtn.Visible = p ~= nil
	if not p then
		if buddyShown then buddyShown = false bridge:Fire("Buddy", false) end
		buddyKey = nil
		return
	end
	local key = p.Species .. (p.Variant or "") .. (p.Outfit or "")
	if key == buddyKey then return end
	buddyKey = key
	for _, ch in buddyBtn:GetChildren() do
		if ch:IsA("ViewportFrame") then ch:Destroy() end
	end
	local vf = CritterUI.Portrait(buddyBtn, Data, p.Species, {Size = UDim2.fromScale(1, 1), ZIndex = buddyBtn.ZIndex + 1}, {Variant = p.Variant, Outfit = p.Outfit})
	CritterUI.Animate(vf, "idle")
end
stateEvent.OnClientEvent:Connect(refreshBuddy)

---------------------------------------------------------------- live bits: badges, seed button on the farm, shop timer
task.spawn(function()
	while true do
		local n = 0
		for _, it in readyItems() do if it.Count then n += 1 end end
		K.badge(bell, n > 0 and n or nil)
		K.badge(dockButtons.Pets, #eggsReady() > 0 and #eggsReady() or nil)
		-- seed button only while you stand on your own farm
		local farm = myFarm()
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local onFarm = false
		if farm and hrp and farm:FindFirstChild("Ground") then
			local rel = farm.Ground.CFrame:PointToObjectSpace(hrp.Position)
			onFarm = math.abs(rel.X) < 27 and math.abs(rel.Z) < 27
		end
		seedBtn.Visible = onFarm
		if not onFarm then seedPick.Visible = false end
		if current == "Shop" and win.frame.Visible then
			local left = math.max(0, (workspace:GetAttribute("ShopRestockAt") or os.time()) - os.time())
			win.setSub(("New seeds in %s"):format(timeText(left)))
		end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- keyboard shortcuts: B bag · P pets · M map
local UserInputService = game:GetService("UserInputService")
local KEYS = {[Enum.KeyCode.B] = {"Farm", "Bag"}, [Enum.KeyCode.P] = {"Pets", "Mine"}, [Enum.KeyCode.M] = {"World", "Places"}}
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local k = KEYS[input.KeyCode]
	if not k then return end
	if current == k[1] and currentTab[k[1]] == k[2] and win.frame.Visible then
		win.close()
	else
		openWin(k[1], k[2])
	end
end)

---------------------------------------------------------------- town prompts: 👗 boutique counter and 🔨 gear forge (local: they only open your own window)
task.spawn(function()
	local function hook(modelName, partName, text, obj, fn)
		local m = root:WaitForChild(modelName, 60)
		local p = m and m:WaitForChild(partName, 10)
		if not p then return end
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText, pr.ObjectText = text, obj
		pr.HoldDuration = 0
		pr.MaxActivationDistance = 14
		pr.RequiresLineOfSight = false
		pr.Parent = p
		pr.Triggered:Connect(fn)
	end
	task.spawn(hook, "Boutique", "Counter", "Shop 👗", "Bow & Bell Boutique", function()
		if current ~= "Boutique" or not win.frame.Visible then openWin("Boutique") end
	end)
	task.spawn(hook, "GearForge", "Anvil", "Power up 🔨", "Gear Forge", function() win.close() bridge:Fire("Bench", "Gear") end)
end)

---------------------------------------------------------------- the other scripts can open our windows
bridge.Event:Connect(function(cmd, arg, arg2)
	if cmd == "Toast" then
		toast(arg, false)
	elseif cmd == "Open" then
		openWin(arg, arg2)
	elseif cmd == "Reopen" then
		if not win.frame.Visible then openWin(arg) end
	end
end)
-- hide the old buttons (they're replaced by this UI)
task.spawn(function()
	for _ = 1, 20 do
		bridge:Fire("HideOld")
		task.wait(1)
	end
end)
