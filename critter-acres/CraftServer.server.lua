-- Critter Acres: CraftServer (ServerScriptService)
-- ⛏️ Gathering: resource nodes in the biomes (models with attribute Node = a key of Data.Nodes). Hit them to break
--    them and get resources; harder ones need a better tool. Your buddy pet helps (extra hit + bonus).
-- 🔨 Workbench (plaza): craft the next tool level, craft pet gear (random rarity), ⭐ upgrade gear,
--    upgrade plot soil, buy decorations and toys.
-- 🏡 Decorating: place / pick up decorations on your own farm (saved in prof.Decor). Sprinklers water nearby
--    plots, beehives make nearby plots grow faster, windmills spin.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local Data = API.Data
local ACTIONS = API.ACTIONS
local Builds = require(ReplicatedStorage:WaitForChild("Builds"))
local root = API.root

local function toolOf(prof) return prof.Tool or 0 end

---------------------------------------------------------------- gathering
local nodes = {} -- model -> {def, hp, down, prompt}
local lastHit = {} -- player -> os.clock()
local function nodeLabel(model, def)
	local main = model.PrimaryPart
	local bb = Instance.new("BillboardGui")
	bb.Name = "NodeGui"
	bb.Size = UDim2.fromOffset(150, 46)
	bb.StudsOffset = Vector3.new(0, main.Size.Y / 2 + 2, 0)
	bb.MaxDistance = 45
	local t = Instance.new("TextLabel")
	t.Name = "T"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	local res = Data.ResByName[def.Res]
	t.Text = ("%s %s%s"):format(res.Icon, def.Label, def.Tool > 0 and ("\n%s Lv%d"):format(Data.Tools[def.Tool].Icon, def.Tool) or "")
	t.Parent = bb
	bb.Parent = main
	return t
end
local function setDown(model, down)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("T0") == nil then d:SetAttribute("T0", d.Transparency) end
			d.Transparency = down and 1 or d:GetAttribute("T0")
			d.CanCollide = (not down) and d:GetAttribute("C0") ~= false
		elseif d:IsA("BillboardGui") then
			d.Enabled = not down
		end
	end
end
local function shake(model)
	local main = model.PrimaryPart
	local cf = model:GetPivot()
	task.spawn(function()
		for i = 1, 4 do
			model:PivotTo(cf * CFrame.new((i % 2 == 0 and 1 or -1) * 0.25, 0, 0))
			task.wait(0.04)
		end
		model:PivotTo(cf)
	end)
	return main
end
local function buddyNear(player, pos)
	local prof = API.profiles[player]
	local rec = prof and prof.FollowId and API.findRec(prof, prof.FollowId)
	local c = rec and API.critterFor(rec)
	if c and (Vector3.new(c.pos.X, 0, c.pos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < 25 then return c end
end
local function setupNode(model)
	local def = Data.Nodes[model:GetAttribute("Node")]
	if not def or not model.PrimaryPart then return end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then d:SetAttribute("C0", d.CanCollide) end
	end
	local info = {def = def, hp = def.Hits, down = false}
	nodeLabel(model, def)
	local prompt = API.makePrompt(model.PrimaryPart, ("Gather %s"):format(Data.ResByName[def.Res].Icon), def.Label)
	prompt.MaxActivationDistance = 11
	info.prompt = prompt
	nodes[model] = info
	prompt.Triggered:Connect(function(player)
		local prof = API.profiles[player]
		if not prof or info.down then return end
		if toolOf(prof) < def.Tool then
			API.toast(player, ("You need the %s %s for this. Make it at the 🔨 Workbench!"):format(Data.Tools[def.Tool].Icon, Data.Tools[def.Tool].Name))
			return
		end
		local now = os.clock()
		if now - (lastHit[player] or 0) < 0.3 then return end
		lastHit[player] = now
		local power = Data.Tools[toolOf(prof)].Power
		local buddy = buddyNear(player, model.PrimaryPart.Position)
		if buddy then
			power += 1
			buddy.model:SetAttribute("Work", (buddy.model:GetAttribute("Work") or 0) + 1) -- helps with a hop
		end
		info.hp -= power
		local main = shake(model)
		API.pop(main, info.hp > 0 and "💥" or Data.ResByName[def.Res].Icon)
		if info.hp <= 0 then
			info.down = true
			prompt.Enabled = false
			local n = math.random(def.Amount[1], def.Amount[2]) + (buddy and 1 or 0)
			API.addRes(player, def.Res, n)
			API.toast(player, ("%s +%d %s%s"):format(Data.ResByName[def.Res].Icon, n, def.Res, buddy and "  (🐾 helped!)" or ""))
			API.questEvent(player, "Gather", n)
			setDown(model, true)
			task.delay(def.Respawn, function()
				info.down = false
				info.hp = def.Hits
				setDown(model, false)
				prompt.Enabled = true
			end)
		end
	end)
end
for _, d in root:GetDescendants() do
	if d:IsA("Model") and d:GetAttribute("Node") then setupNode(d) end
end
-- nodes in the generated maps (Realms) are set up when the map is built
API.setupNode = function(model)
	setupNode(model)
	model.Destroying:Connect(function() nodes[model] = nil end)
end

---------------------------------------------------------------- crafting info for the workbench window
local function craftInfo(player, prof)
	local gear = {}
	for _, g in prof.Gear do
		local wornBy
		for _, rec in prof.Pets do
			if rec.GearId == g.Id then wornBy = rec.Name or rec.Species end
		end
		table.insert(gear, {Id = g.Id, Kind = g.Kind, Tier = g.Tier or 1, Rarity = g.Rarity, Level = g.Level or 0, Luck = g.Luck,
			Odds = Data.UpgradeOdds(g), Text = Data.GearText(g), Name = Data.GearName(g), WornBy = wornBy})
	end
	return {Res = prof.Res, Tool = toolOf(prof), Gear = gear, DecorInv = prof.DecorInv, DecorCount = #prof.Decor, PlotsOpen = prof.PlotsOpen,
		Soil = prof.Soil, Toys = prof.Toys}
end
function ACTIONS.CraftInfo(player, prof) return craftInfo(player, prof) end

function ACTIONS.CraftTool(player, prof)
	local nextLevel = toolOf(prof) + 1
	local def = Data.Tools[nextLevel]
	if not def then return {Error = "MAX"} end
	local ok, missing = API.pay(player, prof, def.Cost)
	if not ok then return {Error = "Need more " .. missing} end
	prof.Tool = nextLevel
	player:SetAttribute("Tool", nextLevel)
	if nextLevel >= Data.ToolMax and API.giveTitle then API.giveTitle(player, "Master Crafter") end
	return {Ok = true, Made = def.Name, Icon = def.Icon, Info = craftInfo(player, prof)}
end

local function rollRarity()
	local total = 0
	for _, w in Data.CraftRarity do total += w end
	local r = math.random() * total
	for _, k in {"Legendary", "Epic", "Rare", "Common"} do
		r -= Data.CraftRarity[k]
		if r <= 0 then return k end
	end
	return "Common"
end
-- kind = which gear (1-5), tier = material tier (1 Leaf .. 6 Magma). Rarity is random.
function ACTIONS.CraftGear(player, prof, kind, tier)
	tier = tier or 1
	local def, t = Data.Gear[kind], Data.GearTiers[tier]
	if not def or not t then return {Error = "❌"} end
	local ok, missing = API.pay(player, prof, t.Cost)
	if not ok then return {Error = "Need more " .. missing} end
	local g = {Id = prof.NextId, Kind = kind, Tier = tier, Rarity = rollRarity(), Level = 0}
	prof.NextId += 1
	table.insert(prof.Gear, g)
	API.questEvent(player, "Craft", 1)
	return {Ok = true, Gear = {Kind = g.Kind, Tier = tier, Rarity = g.Rarity, Text = Data.GearText(g), Name = Data.GearName(g)},
		Info = craftInfo(player, prof)}
end
-- ⭐ power up: it can FAIL. A fail only uses the materials and adds luck for next time.
function ACTIONS.UpgradeGear(player, prof, id)
	local g
	for _, x in prof.Gear do
		if x.Id == id then g = x end
	end
	if not g then return {Error = "❌"} end
	local nextLevel = (g.Level or 0) + 1
	if nextLevel > Data.GearMaxLevel then return {Error = "MAX"} end
	local odds = Data.UpgradeOdds(g)
	local ok, missing = API.pay(player, prof, Data.UpgradeCost(g, nextLevel))
	if not ok then return {Error = "Need more " .. missing} end
	local before = Data.GearText(g)
	local win = math.random() < odds
	if win then
		g.Level = nextLevel
		g.Luck = nil
		if nextLevel >= Data.GearMaxLevel then API.notifyAll(("⭐ %s powered up a %s to +%d!"):format(player.DisplayName, Data.GearName(g), nextLevel)) end
	else
		g.Luck = (g.Luck or 0) + Data.UpgradeFailLuck
	end
	API.pushState(player)
	return {Ok = true, Win = win, Odds = odds, Level = g.Level or 0, Luck = g.Luck, Before = before, Text = Data.GearText(g),
		Name = Data.GearName(g), Kind = g.Kind, Tier = g.Tier or 1, Rarity = g.Rarity, Info = craftInfo(player, prof)}
end

---------------------------------------------------------------- farm: soil upgrades
function ACTIONS.UpgradeSoil(player, prof, i)
	local farm = API.farmOf[player]
	local plot = farm and farm.plots[i]
	if not plot or plot:GetAttribute("Locked") then return {Error = "🔒"} end
	local key = tostring(i)
	local lvl = prof.Soil[key] or 1
	local nextSoil = Data.Soil[lvl + 1]
	if not nextSoil then return {Error = "MAX"} end
	local ok, missing = API.pay(player, prof, nextSoil.Cost)
	if not ok then return {Error = "Need more " .. missing} end
	prof.Soil[key] = lvl + 1
	plot:SetAttribute("Soil", lvl + 1)
	API.refreshPlot(plot)
	API.pop(plot, "✨")
	return {Ok = true, Info = craftInfo(player, prof)}
end

---------------------------------------------------------------- decorations
local placed = {} -- farm -> {id -> model}
local function decorFolder(farm)
	local f = farm.model:FindFirstChild("Decor")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Decor"
		f.Parent = farm.model
	end
	return f
end
-- beehives: plots within range grow faster (Bee attribute read by FarmServer's growth loop)
local function refreshBees(farm, prof)
	for _, plot in farm.plots do
		local boost = 0
		for _, d in prof and prof.Decor or {} do
			local def = Data.DecorByName[d.Name]
			if def and def.Effect == "Grow" then
				local wpos = farm.ground.CFrame * Vector3.new(d.X, 0, d.Z)
				if (Vector3.new(wpos.X, 0, wpos.Z) - Vector3.new(plot.Position.X, 0, plot.Position.Z)).Magnitude <= def.Range then boost += def.Boost end
			end
		end
		plot:SetAttribute("Bee", boost > 0 and math.min(0.5, boost) or nil)
	end
end
local function buildDecor(farm, d)
	local m = Builds.Decor(d.Name)
	if not m then return nil end
	m:SetAttribute("DecorId", d.Id)
	local cf = farm.ground.CFrame * CFrame.new(d.X, farm.ground.Size.Y / 2, d.Z) * CFrame.Angles(0, math.rad(d.R or 0), 0)
	m:PivotTo(cf)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then p.CanQuery = true end -- so decorate mode can click it
	end
	m.Parent = decorFolder(farm)
	placed[farm] = placed[farm] or {}
	placed[farm][d.Id] = m
	return m
end
local function clearDecor(farm)
	local f = farm.model:FindFirstChild("Decor")
	if f then f:ClearAllChildren() end
	placed[farm] = {}
	for _, plot in farm.plots do plot:SetAttribute("Bee", nil) end
end
local function loadDecor(farm, player)
	clearDecor(farm)
	local prof = API.profiles[player]
	if not prof then return end
	for _, d in prof.Decor do buildDecor(farm, d) end
	refreshBees(farm, prof)
end
for _, farm in API.farms do -- build saved decorations when a farm gets its owner
	farm.model:GetAttributeChangedSignal("Owner"):Connect(function()
		task.wait(0.2)
		if farm.owner then loadDecor(farm, farm.owner) else clearDecor(farm) end
	end)
	if farm.owner then loadDecor(farm, farm.owner) end
end

function ACTIONS.BuyDecor(player, prof, name)
	local def = Data.DecorByName[name]
	if not def then return {Error = "❌"} end
	local ok, missing = API.pay(player, prof, def.Cost)
	if not ok then return {Error = "Need more " .. missing} end
	prof.DecorInv[name] = (prof.DecorInv[name] or 0) + 1
	return {Ok = true, Info = craftInfo(player, prof), Inv = prof.DecorInv[name]}
end
function ACTIONS.PlaceDecor(player, prof, name, x, z, r)
	local farm = API.farmOf[player]
	if not farm or not Data.DecorByName[name] then return {Error = "❌"} end
	if (prof.DecorInv[name] or 0) < 1 then return {Error = "0"} end
	if #prof.Decor >= Data.DecorMax then return {Error = ("Max %d decorations"):format(Data.DecorMax)} end
	x, z, r = tonumber(x), tonumber(z), tonumber(r) or 0
	if not x or not z or math.abs(x) > 23 or math.abs(z) > 23 then return {Error = "Put it inside your farm"} end
	local d = {Id = prof.NextId, Name = name, X = math.floor(x * 10) / 10, Z = math.floor(z * 10) / 10, R = math.floor(r) % 360}
	prof.NextId += 1
	prof.DecorInv[name] -= 1
	table.insert(prof.Decor, d)
	API.questEvent(player, "Decor", 1)
	local m = buildDecor(farm, d)
	if m and m.PrimaryPart then API.pop(m.PrimaryPart, "✨") end
	refreshBees(farm, prof)
	return {Ok = true, Id = d.Id, Info = craftInfo(player, prof)}
end
function ACTIONS.PickupDecor(player, prof, id)
	local farm = API.farmOf[player]
	if not farm then return {Error = "❌"} end
	for i, d in prof.Decor do
		if d.Id == id then
			table.remove(prof.Decor, i)
			prof.DecorInv[d.Name] = (prof.DecorInv[d.Name] or 0) + 1
			local m = placed[farm] and placed[farm][id]
			if m then m:Destroy() end
			if placed[farm] then placed[farm][id] = nil end
			refreshBees(farm, prof)
			return {Ok = true, Name = d.Name, Info = craftInfo(player, prof)}
		end
	end
	return {Error = "❌"}
end

-- windmill blades and sprinklers spin; sprinklers water plots near them every 15 seconds
task.spawn(function()
	local t = 0
	while true do
		local dt = task.wait(0.1)
		t += dt
		for _, list in placed do
			for _, m in list do
				if m.Parent and m:GetAttribute("Spin") then
					local hub, head = m:FindFirstChild("Hub"), m:FindFirstChild("Head")
					if hub then -- windmill: blades turn around the hub
						local h = hub.CFrame
						local turn = h * CFrame.Angles(0, 0, dt * 1.5) * h:Inverse()
						for _, p in m:GetChildren() do
							if p.Name == "Blade" then p.CFrame = turn * p.CFrame end
						end
					elseif head then -- sprinkler head spins
						local c = head.Position
						head.CFrame = CFrame.new(c) * CFrame.Angles(0, dt * 3, 0) * CFrame.new(-c) * head.CFrame
					end
				end
			end
		end
		if t >= 15 then
			t = 0
			for farm, list in placed do
				for _, m in list do
					if m.Parent and m.Name == "Sprinkler" and m.PrimaryPart then
						local head = m:FindFirstChild("Head")
						local spray = head and head:FindFirstChild("Spray")
						if spray then spray:Emit(60) end
						local range = Data.DecorByName.Sprinkler.Range
						for _, plot in farm.plots do
							if (plot.Position - m.PrimaryPart.Position).Magnitude <= range and not plot:GetAttribute("Locked") then
								API.water(plot, nil)
							end
						end
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------- toys (bought here, used in FunServer)
function ACTIONS.BuyToy(player, prof, name)
	local def = Data.ToyByName[name]
	if not def or not def.Cost then return {Error = "❌"} end
	if prof.Toys[name] then return {Error = "✔"} end
	local ok, missing = API.pay(player, prof, def.Cost)
	if not ok then return {Error = "Need more " .. missing} end
	prof.Toys[name] = true
	player:SetAttribute("Toys", (function()
		local t = {}
		for k in prof.Toys do table.insert(t, k) end
		return table.concat(t, ",")
	end)())
	return {Ok = true, Info = craftInfo(player, prof)}
end
