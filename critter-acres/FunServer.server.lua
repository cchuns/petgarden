-- Critter Acres: FunServer (ServerScriptService)
-- 🫧 Toys (bubble wand, confetti, fireworks) everyone around can see.
-- 🌰 Golden acorns hidden in the biomes (CritterAcres.Acorns, each with attribute Id). Find them all for prizes.
-- 🏷️ Titles shown over your head (Data.Titles). Earned from many places through API.giveTitle.
-- 🏆 Record board in the plaza: biggest berry, most shinies, most likes, top boss hitter, most acorns.
-- 🍀 Lucky hour: one hour a day with x2 shiny chances (workspace attribute LuckyUntil).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local Data = API.Data
local ACTIONS = API.ACTIONS
local root = API.root

local function hrpOf(p)
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

---------------------------------------------------------------- titles
local function titleGui(player)
	local prof = API.profiles[player]
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not prof or not head then return end
	local bb = head:FindFirstChild("TitleGui")
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "TitleGui"
		bb.Size = UDim2.fromOffset(220, 34)
		bb.StudsOffset = Vector3.new(0, 2.6, 0)
		bb.MaxDistance = 90
		local t = Instance.new("TextLabel")
		t.Name = "T"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 225, 110)
		t.TextStrokeTransparency = 0.2
		t.Parent = bb
		bb.Parent = head
	end
	local def = Data.TitleByName[prof.Title or ""]
	bb.T.Text = def and (def.Icon .. " " .. def.Name) or ""
end
local function titleAttr(player, prof)
	local list = {}
	for name in prof.Titles do table.insert(list, name) end
	player:SetAttribute("Titles", table.concat(list, ","))
	player:SetAttribute("Title", prof.Title)
end
function API.giveTitle(player, name)
	local prof = API.profiles[player]
	if not prof or not Data.TitleByName[name] or prof.Titles[name] then return end
	prof.Titles[name] = true
	titleAttr(player, prof)
	local def = Data.TitleByName[name]
	API.toast(player, ("🏷️ New title: %s %s! Wear it from the 🏷️ Titles menu."):format(def.Icon, def.Name))
	API.reveal(player, {Kind = "Title", Name = name})
end
function ACTIONS.SetTitle(player, prof, name)
	if not prof.Titles[name] then return "🔒" end
	prof.Title = name
	titleAttr(player, prof)
	titleGui(player)
	return nil
end

---------------------------------------------------------------- toys
local toyCool = {}
local function bubbles(hrp)
	for i = 1, 12 do
		local b = Instance.new("Part")
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.one * (0.6 + math.random() * 1.2)
		b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = true, false, false, false
		b.Material = Enum.Material.Glass
		b.Transparency = 0.45
		b.Color = Color3.fromHSV(math.random(), 0.3, 1)
		b.Position = hrp.Position + hrp.CFrame.LookVector * 2 + Vector3.new(math.random(-1, 1), 1, math.random(-1, 1))
		b.Parent = workspace
		local goal = b.Position + Vector3.new(math.random(-8, 8), 10 + math.random() * 8, math.random(-8, 8))
		TweenService:Create(b, TweenInfo.new(3 + math.random() * 2, Enum.EasingStyle.Sine), {Position = goal}):Play()
		task.delay(3.5 + math.random() * 1.5, function()
			TweenService:Create(b, TweenInfo.new(0.15), {Size = b.Size * 1.5, Transparency = 1}):Play()
			task.wait(0.2)
			b:Destroy()
		end)
		task.wait(0.06)
	end
end
local function burst(pos, colors, count, speed)
	local a = Instance.new("Part")
	a.Size = Vector3.one
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
	a.Transparency = 1
	a.Position = pos
	a.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(colors[1], colors[2] or colors[1])
	e.LightEmission = 1
	e.Size = NumberSequence.new(1.2, 0)
	e.Speed = NumberRange.new(speed * 0.6, speed)
	e.Lifetime = NumberRange.new(1, 1.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -8, 0)
	e.Rate = 0
	e.Parent = a
	e:Emit(count)
	task.delay(2.5, function() a:Destroy() end)
end
local function fireworks(hrp)
	for k = 1, 3 do
		local start = hrp.Position + Vector3.new(math.random(-4, 4), 2, math.random(-4, 4))
		local rocket = Instance.new("Part")
		rocket.Size = Vector3.new(0.6, 1.6, 0.6)
		rocket.Anchored, rocket.CanCollide, rocket.CanQuery, rocket.CanTouch = true, false, false, false
		rocket.Material = Enum.Material.Neon
		rocket.Color = Color3.fromHSV(math.random(), 0.8, 1)
		rocket.Position = start
		rocket.Parent = workspace
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat = 3, 0
		fire.Parent = rocket
		local top = start + Vector3.new(math.random(-6, 6), 40 + math.random() * 15, math.random(-6, 6))
		TweenService:Create(rocket, TweenInfo.new(1, Enum.EasingStyle.Quad), {Position = top}):Play()
		task.delay(1, function()
			rocket:Destroy()
			local c1 = Color3.fromHSV(math.random(), 0.8, 1)
			burst(top, {c1, Color3.fromHSV(math.random(), 0.6, 1)}, 120, 30)
		end)
		task.wait(0.4)
	end
end
function ACTIONS.UseToy(player, prof, name)
	if not prof.Toys[name] then return "🔒" end
	local now = os.clock()
	if now - (toyCool[player] or 0) < 1.5 then return nil end
	toyCool[player] = now
	local hrp = hrpOf(player)
	if not hrp then return nil end
	if name == "Bubble Wand" then
		task.spawn(bubbles, hrp)
	elseif name == "Confetti" then
		burst(hrp.Position + Vector3.new(0, 3, 0), {Color3.fromRGB(255, 90, 140), Color3.fromRGB(90, 200, 255)}, 90, 22)
		API.pop(hrp, "🎉")
	elseif name == "Fireworks" then
		task.spawn(fireworks, hrp)
	end
	return nil
end

---------------------------------------------------------------- golden acorns
local acornFolder = root:FindFirstChild("Acorns")
local function acornAttrs(player, prof)
	local ids, n = {}, 0
	for id in prof.Acorns do
		table.insert(ids, id)
		n += 1
	end
	player:SetAttribute("AcornsFound", table.concat(ids, ","))
	player:SetAttribute("AcornCount", n)
	return n
end
if acornFolder then
	for _, acorn in acornFolder:GetChildren() do
		local id = tostring(acorn:GetAttribute("Id") or acorn.Name)
		local main = acorn:IsA("Model") and acorn.PrimaryPart or acorn
		if main then
			local prompt = API.makePrompt(main, "Pick up 🌰", "Golden Acorn")
			prompt.MaxActivationDistance = 9
			prompt.Triggered:Connect(function(player)
				local prof = API.profiles[player]
				if not prof or prof.Acorns[id] then return end
				prof.Acorns[id] = true
				local n = acornAttrs(player, prof)
				API.addCoins(player, Data.AcornCoins)
				API.toast(player, ("🌰 Golden acorn %d/%d!  💰+%d"):format(n, Data.AcornCount, Data.AcornCoins))
				API.questEvent(player, "Acorn", 1)
				local reward = Data.AcornRewards[n]
				if reward then API.reveal(player, {Kind = "Prize", Prize = API.grant(player, reward)}) end
				if n >= Data.AcornCount then API.giveTitle(player, "Acorn Master") end
				API.pushState(player)
			end)
		end
	end
end

---------------------------------------------------------------- explorer title + join setup
local function onProfile(player)
	local prof
	for _ = 1, 60 do
		prof = API.profiles[player]
		if prof then break end
		task.wait(0.5)
	end
	if not prof then return end
	prof.Titles = prof.Titles or {["Little Farmer"] = true}
	prof.Titles["Little Farmer"] = true
	prof.Title = prof.Title or "Little Farmer"
	prof.Toys = prof.Toys or {}
	prof.Toys["Bubble Wand"] = true
	prof.Acorns = prof.Acorns or {}
	prof.Visited = prof.Visited or {}
	titleAttr(player, prof)
	acornAttrs(player, prof)
	local toys = {}
	for k in prof.Toys do table.insert(toys, k) end
	player:SetAttribute("Toys", table.concat(toys, ","))
	player.CharacterAdded:Connect(function() task.wait(0.5) titleGui(player) end)
	if player.Character then titleGui(player) end
end
Players.PlayerAdded:Connect(onProfile)
for _, p in Players:GetPlayers() do task.spawn(onProfile, p) end

task.spawn(function() -- which biome are you standing in?
	while true do
		task.wait(3)
		for player, prof in API.profiles do
			local hrp = hrpOf(player)
			if hrp and prof.Visited then
				for name, part in API.biomeParts do
					local rel = part.CFrame:PointToObjectSpace(hrp.Position)
					if math.abs(rel.X) < part.Size.X / 2 and math.abs(rel.Z) < part.Size.Z / 2 and not prof.Visited[name] then
						prof.Visited[name] = true
						API.questEvent(player, "ExploreNew", 1)
						local b = Data.BiomeByName[name]
						API.toast(player, ("%s You found the %s!"):format(b and b.Icon or "🗺️", name))
						local all = true
						for n2 in API.biomeParts do
							if not prof.Visited[n2] then all = false end
						end
						if all then API.giveTitle(player, "Explorer") end
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------- 🏆 record board
local records = {Berry = {}, Boss = {}} -- kind -> {name, value} best today on this server
function API.record(kind, player, value)
	local r = records[kind]
	if r and (not r.value or value > r.value) then
		records[kind] = {name = player.DisplayName, value = value}
	end
end
local boardText
do
	local board = root:FindFirstChild("RecordBoard")
	local b = board and board:FindFirstChild("Board", true)
	local gui = b and b:FindFirstChildWhichIsA("SurfaceGui")
	boardText = gui and gui:FindFirstChild("List")
end
local function best(fn)
	local bestName, bestValue = nil, 0
	for player, prof in API.profiles do
		local v = fn(prof)
		if v > bestValue then bestName, bestValue = player.DisplayName, v end
	end
	return bestName, bestValue
end
task.spawn(function()
	while true do
		if boardText then
			local lines = {}
			local function line(icon, label, name, value)
				table.insert(lines, ("%s %s: %s"):format(icon, label, name and (name .. "  " .. value) or "—"))
			end
			line("🍓", "Biggest berry today", records.Berry.name, records.Berry.value and ("💰" .. records.Berry.value))
			line("👹", "Top boss hitter", records.Boss.name, records.Boss.value)
			local n, v = best(function(prof)
				local s = 0
				for _, r in prof.Pets do if r.Variant then s += 1 end end
				return s
			end)
			line("✨", "Most shinies", n, v)
			n, v = best(function(prof) return prof.Likes or 0 end)
			line("❤️", "Most farm likes", n, v)
			n, v = best(function(prof)
				local s = 0
				for _ in prof.Acorns or {} do s += 1 end
				return s
			end)
			line("🌰", "Most acorns", n, v)
			boardText.Text = table.concat(lines, "\n")
		end
		task.wait(10)
	end
end)

---------------------------------------------------------------- 🍀 lucky hour (one hour a day, the same for everyone)
local function luckyHourOf(day) return Random.new(day * 97 + 13):NextInteger(0, 23) end
task.spawn(function()
	local announced = nil
	while true do
		local now = os.time()
		local day = API.today()
		local hourStart = now - now % 3600
		local hour = math.floor((now % 86400) / 3600)
		if hour == luckyHourOf(day) then
			workspace:SetAttribute("LuckyUntil", hourStart + 3600)
			if announced ~= hourStart then
				announced = hourStart
				API.notifyAll("🍀 LUCKY HOUR! Shiny critters are 2x more likely for the next hour!")
			end
		elseif (workspace:GetAttribute("LuckyUntil") or 0) <= now then
			workspace:SetAttribute("LuckyUntil", nil)
		end
		-- when the next one starts (for the HUD)
		local nextStart = day * 86400 + luckyHourOf(day) * 3600
		if nextStart <= now then nextStart = (day + 1) * 86400 + luckyHourOf(day + 1) * 3600 end
		workspace:SetAttribute("LuckyNext", nextStart)
		task.wait(15)
	end
end)
function API.startLuckyHour() -- dev menu
	workspace:SetAttribute("LuckyUntil", os.time() + 600)
	API.notifyAll("🍀 LUCKY HOUR! Shiny critters are 2x more likely!")
end
