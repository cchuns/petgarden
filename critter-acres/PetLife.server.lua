-- Critter Acres: PetLife (ServerScriptService)
-- Everything about living with your pets:
--   📦 Storage   - only FarmPetCap(level) pets are out on your farm, the rest wait in storage (swap any time)
--   ✏️ Names     - name your pet (Roblox text filter)
--   💕 Best Friends Nest - two pets cuddle on your farm, then a Friend Egg pops out (both parents stay!).
--                  Anyone can tap 💕 Cheer to speed it up. The baby mixes its parents' colors; the right pair
--                  can make a SECRET pet.
--   🐎 Riding    - hop on your pet and ride it around (faster than walking)
--   🤝 Trading   - two-sided window: both pick pets, both press Ready, then both press Confirm
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local Data = API.Data
local ACTIONS = API.ACTIONS

local function ts() return workspace:GetAttribute("CritterTimeScale") or 1 end
local function farmCap(prof) return Data.FarmPetCap(Data.FarmLevel(prof.FarmXp or 0)) end
local function onFarmCount(prof)
	local n = 0
	for _, r in prof.Pets do
		if not r.Stored then n += 1 end
	end
	return n
end
local function nameOf(rec) return rec.Name or rec.Species end

local tradeEvent = ReplicatedStorage:FindFirstChild("CritterTrade") or Instance.new("RemoteEvent")
tradeEvent.Name = "CritterTrade"
tradeEvent.Parent = ReplicatedStorage

---------------------------------------------------------------- 🐎 riding
local riding = {} -- player -> {rec, c, hip, speed}
local function stopRide(player, onlyRec)
	local r = riding[player]
	if not r or (onlyRec and r.rec ~= onlyRec) then return end
	riding[player] = nil
	r.rec.Riding = nil
	if r.c then
		r.c.ride = nil
		r.c.rideMoving = nil
		r.c.model:SetAttribute("RiderId", nil)
		r.c.version += 1
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.HipHeight = r.hip
		hum.WalkSpeed = r.speed
	end
	API.fillSlots(player)
end
API.stopRide = stopRide

function ACTIONS.Ride(player, prof, id)
	local rec = API.findRec(prof, id)
	if not rec then return nil end
	if riding[player] then
		local same = riding[player].rec == rec
		stopRide(player)
		if same then return "🐎 Hopped off" end
	end
	if rec.Stored then return "That pet is in 📦 storage. Bring it to your farm first." end
	if rec.Trip or rec.NestUntil or API.isResting(rec) then return ("%s can't be ridden right now."):format(nameOf(rec)) end
	local c = API.critterFor(rec)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not c or not hum or hum.Health <= 0 then return nil end
	if c.fetch then return nil end
	if prof.FollowId == rec.Id then prof.FollowId = nil end
	riding[player] = {rec = rec, c = c, hip = hum.HipHeight, speed = hum.WalkSpeed}
	rec.Riding = true
	c.ride = player
	c.version += 1
	c.model:SetAttribute("RiderId", player.UserId) -- the client animator keeps it right under you
	hum.HipHeight = riding[player].hip + c.halfH * 1.6
	hum.WalkSpeed = Data.RideSpeed[c.type.Rarity] or 22
	API.fillSlots(player)
	API.questEvent(player, "Ride", 1)
	return ("🐎 Riding %s! Tap Ride again to hop off."):format(nameOf(rec))
end
Players.PlayerRemoving:Connect(function(p) stopRide(p) end)
Players.PlayerAdded:Connect(function(p)
	p.CharacterRemoving:Connect(function() stopRide(p) end)
end)
for _, p in Players:GetPlayers() do p.CharacterRemoving:Connect(function() stopRide(p) end) end

---------------------------------------------------------------- 📦 storage
function ACTIONS.StorePet(player, prof, id, store)
	local rec = API.findRec(prof, id)
	if not rec then return nil end
	if store then
		if rec.Stored then return nil end
		if rec.NestUntil then return ("%s is in the nest right now."):format(nameOf(rec)) end
		stopRide(player, rec)
		if prof.FollowId == rec.Id then prof.FollowId = nil end
		rec.Stored = true
		local c = API.critterFor(rec)
		if c then API.removeCritter(c) end
		API.fillSlots(player)
		API.pushState(player)
		return ("📦 %s is resting in storage."):format(nameOf(rec))
	else
		if not rec.Stored then return nil end
		if onFarmCount(prof) >= farmCap(prof) then
			return ("🏡 Your farm is full (%d pets). Put one in storage first, or level up your farm for more room!"):format(farmCap(prof))
		end
		rec.Stored = nil
		local c = API.spawnCritter(Data.SpeciesByName[rec.Species], player, rec)
		if c then c.model:SetAttribute("PetAt", os.clock()) end
		API.fillSlots(player)
		API.pushState(player)
		return ("🏡 %s came out to your farm!"):format(nameOf(rec))
	end
end

---------------------------------------------------------------- ✏️ names
function ACTIONS.NamePet(player, prof, id, text)
	local rec = API.findRec(prof, id)
	if not rec or type(text) ~= "string" then return nil end
	text = text:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	text = text:sub(1, Data.NameMax * 2)
	if utf8.len(text) and utf8.len(text) > Data.NameMax then text = text:sub(1, utf8.offset(text, Data.NameMax + 1) - 1) end
	if text == "" then
		rec.Name = nil
	else
		local ok, result = pcall(function()
			return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
		end)
		if not ok then return "Names can't be checked right now. Try again soon!" end
		if result:find("#") then return "That name isn't allowed. Try another one!" end
		rec.Name = result
	end
	local c = API.critterFor(rec)
	if c then
		API.refreshTag(c)
		c.model:SetAttribute("PetAt", os.clock())
	end
	API.pushState(player)
	return rec.Name and ("✏️ Say hi to %s!"):format(rec.Name) or "✏️ Name removed"
end

---------------------------------------------------------------- 💕 Best Friends Nest (one on every farm)
local root = workspace:WaitForChild("CritterAcres")
local nests = {} -- farm -> {model, heart, label, prompt, hearts}
local function buildNest(farm)
	local base = farm.ground.CFrame * CFrame.new(19, 0, -18)
	local m = Instance.new("Model")
	m.Name = "FriendNest"
	local function p(props)
		local x = Instance.new("Part")
		x.Anchored, x.TopSurface, x.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		for k, v in props do x[k] = v end
		x.Parent = m
		return x
	end
	p({Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 7, 7), CFrame = base * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 190, 215), Material = Enum.Material.Fabric})
	p({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 7.8, 7.8), CFrame = base * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 140, 180), Material = Enum.Material.Fabric, CanCollide = false})
	-- heart sign on a post
	p({Size = Vector3.new(0.5, 5, 0.5), CFrame = base * CFrame.new(0, 2.5, 4.2), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood})
	local heart = p({Name = "Heart", Size = Vector3.new(2.6, 2.6, 0.6), CFrame = base * CFrame.new(0, 5.6, 4.2) * CFrame.Angles(0, 0, math.pi / 4),
		Color = Color3.fromRGB(255, 90, 140), Material = Enum.Material.Neon})
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 70)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.MaxDistance = 90
	bb.Parent = heart
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(255, 120, 170)
	t.BackgroundTransparency = 0.1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4
	t.Text = "💕 Best Friends Nest"
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 14)
	t.Parent = bb
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 2, -4.2)
	att.Parent = heart
	local hearts = Instance.new("ParticleEmitter")
	hearts.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	hearts.Color = ColorSequence.new(Color3.fromRGB(255, 120, 170))
	hearts.LightEmission = 0.6
	hearts.Rate = 0
	hearts.Lifetime = NumberRange.new(1.2, 2)
	hearts.Speed = NumberRange.new(2, 4)
	hearts.SpreadAngle = Vector2.new(40, 40)
	hearts.Size = NumberSequence.new(0.8, 0)
	hearts.Parent = att
	local prompt = API.makePrompt(m.Base, "💕 Cheer", "Best Friends Nest")
	prompt.Enabled = false
	m.Parent = farm.model
	nests[farm] = {model = m, center = base.Position, label = t, prompt = prompt, hearts = hearts, cheerAt = {}}
	prompt.Triggered:Connect(function(player)
		local owner = farm.owner
		local prof = owner and API.profiles[owner]
		if not prof then return end
		local n = nests[farm]
		if n.cheerAt[player] and os.clock() - n.cheerAt[player] < 4 then return end
		n.cheerAt[player] = os.clock()
		for _, rec in prof.Pets do
			if rec.NestUntil then rec.NestUntil -= math.ceil(Data.NestCheer / ts()) end
		end
		hearts:Emit(12)
		API.pop(m.Base, "💕")
		if player ~= owner then API.toast(owner, ("💕 %s cheered for your nest!"):format(player.DisplayName)) end
	end)
end
for _, farm in API.farms do
	if farm.ground then buildNest(farm) end
end

function API.nestSpot(c)
	local farm = c.owner and API.farmOf[c.owner]
	local n = farm and nests[farm]
	if not n then return nil end
	local side = (c.record and c.record.NestMain) and -1.4 or 1.4
	local right = farm.ground.CFrame.RightVector
	return Vector3.new(n.center.X, 0, n.center.Z) + right * side
end

local function pairOf(prof)
	local a, b
	for _, rec in prof.Pets do
		if rec.NestUntil then
			if rec.NestMain then a = rec else b = rec end
		end
	end
	return a, b
end

function ACTIONS.NestStart(player, prof, idA, idB)
	if pairOf(prof) then return "💕 Your nest already has two friends cuddling." end
	if idA == idB then return "Pick two different pets." end
	local a, b = API.findRec(prof, idA), API.findRec(prof, idB)
	if not a or not b then return nil end
	for _, r in {a, b} do
		if r.Trip then return ("%s is on an expedition."):format(nameOf(r)) end
		if r.Stored then return ("%s is in 📦 storage. Bring it to your farm first."):format(nameOf(r)) end
		if r.NestRest and os.time() < r.NestRest then
			local left = r.NestRest - os.time()
			return ("%s needs a rest first (%d:%02d)."):format(nameOf(r), left // 60, left % 60)
		end
		stopRide(player, r)
		if prof.FollowId == r.Id then prof.FollowId = nil end
	end
	local secs = math.ceil(Data.NestSecs / ts())
	a.NestUntil, b.NestUntil = os.time() + secs, os.time() + secs
	a.NestMain, b.NestMain = true, nil
	for _, r in {a, b} do
		local c = API.critterFor(r)
		if c then c.version += 1 end
	end
	API.fillSlots(player)
	API.pushState(player)
	return ("💕 %s and %s are cuddling in the nest! Tap 💕 Cheer on the nest to speed it up."):format(nameOf(a), nameOf(b))
end
function ACTIONS.NestCancel(player, prof)
	local a, b = pairOf(prof)
	if not a then return nil end
	for _, r in {a, b} do
		if r then r.NestUntil, r.NestMain = nil, nil end
	end
	API.fillSlots(player)
	API.pushState(player)
	return "💕 The friends went back to the farm."
end

local function mixColor(c1, c2)
	local t = 0.3 + math.random() * 0.4
	local c = c1:Lerp(c2, t)
	return math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)
end
local function finishNest(player, prof, a, b)
	local TA, TB = Data.SpeciesByName[a.Species], Data.SpeciesByName[b.Species]
	local r1, g1, b1 = mixColor(TA.Color, TB.Color)
	local r2, g2, b2 = mixColor(TA.Ear, TB.Ear)
	API.addEgg(prof, "Friend", {A = a.Species, B = b.Species, Tint = {r1, g1, b1, r2, g2, b2}, Shiny = (a.Variant or b.Variant) and true or nil,
		Secs = Data.FriendEgg.HatchSecs, From = nameOf(a) .. " + " .. nameOf(b)})
	for _, r in {a, b} do
		r.NestUntil, r.NestMain = nil, nil
		r.NestRest = os.time() + math.ceil(Data.NestRest / ts())
		API.setHappy(r, 100)
		local c = API.critterFor(r)
		if c then c.model:SetAttribute("PetAt", os.clock()) end
	end
	local farm = API.farmOf[player]
	if farm and nests[farm] then nests[farm].hearts:Emit(40) end
	API.reveal(player, {Kind = "NestEgg", A = a.Species, B = b.Species, Tint = {r1, g1, b1}})
	API.toast(player, ("💕 %s and %s made a Friend Egg! It's in your incubator."):format(nameOf(a), nameOf(b)))
	API.questEvent(player, "Nest", 1)
	API.fillSlots(player)
	API.pushState(player)
end

task.spawn(function()
	while true do
		task.wait(1)
		for farm, n in nests do
			local owner = farm.owner
			local prof = owner and API.profiles[owner]
			local a, b = nil, nil
			if prof then a, b = pairOf(prof) end
			if a and b then
				local left = math.max(0, a.NestUntil - os.time())
				if left <= 0 then
					finishNest(owner, prof, a, b)
				else
					n.label.Text = ("💕 %s + %s\n🥚 %d:%02d"):format(nameOf(a), nameOf(b), left // 60, left % 60)
					n.hearts.Rate = 3
					n.prompt.Enabled = true
				end
			elseif a and not b then -- partner left (traded/released): cancel
				a.NestUntil, a.NestMain = nil, nil
			else
				n.label.Text = owner and "💕 Best Friends Nest\n(open 💕 Nest)" or "💕 Best Friends Nest"
				n.hearts.Rate = 0
				n.prompt.Enabled = false
			end
		end
	end
end)

---------------------------------------------------------------- 🤝 trading
local trades = {} -- player -> trade
local requests = {} -- target -> {from = player, at = os.clock()}
local function petInfo(rec)
	local T = Data.SpeciesByName[rec.Species]
	return {Id = rec.Id, Species = rec.Species, Rarity = T.Rarity, Level = API.petLevel(rec), Variant = rec.Variant, Name = rec.Name,
		Outfit = rec.Outfit, Odds = rec.Odds, SizeName = rec.SizeName}
end
local function other(t, p) return t.a == p and t.b or t.a end
local function send(t)
	for _, p in {t.a, t.b} do
		local o = other(t, p)
		local mine, theirs = {}, {}
		for _, rec in t.offer[p] do table.insert(mine, petInfo(rec)) end
		for _, rec in t.offer[o] do table.insert(theirs, petInfo(rec)) end
		tradeEvent:FireClient(p, {Kind = "Update", With = o.DisplayName, Mine = mine, Theirs = theirs, Stage = t.stage,
			MeReady = t.ready[p] or false, ThemReady = t.ready[o] or false, MeConfirm = t.confirm[p] or false, ThemConfirm = t.confirm[o] or false})
	end
end
local function closeTrade(t, why)
	for _, p in {t.a, t.b} do
		trades[p] = nil
		if p.Parent then tradeEvent:FireClient(p, {Kind = "Close", Why = why}) end
	end
end
local function tradable(prof, rec)
	return rec and not rec.Trip and not rec.NestUntil and not rec.Riding
end

function ACTIONS.TradeRequest(player, prof, userId)
	local target = Players:GetPlayerByUserId(tonumber(userId) or 0)
	if not target or target == player then return "That player isn't here." end
	if trades[player] or trades[target] then return "Someone is already trading." end
	requests[target] = {from = player, at = os.clock()}
	tradeEvent:FireClient(target, {Kind = "Request", From = player.DisplayName, FromId = player.UserId})
	return ("🤝 Trade request sent to %s!"):format(target.DisplayName)
end
function ACTIONS.TradeAccept(player, prof, fromId)
	local req = requests[player]
	requests[player] = nil
	if not req or req.from.UserId ~= fromId or os.clock() - req.at > 40 or not req.from.Parent then return "That request ran out." end
	if trades[player] or trades[req.from] then return "Someone is already trading." end
	local t = {a = req.from, b = player, offer = {[req.from] = {}, [player] = {}}, ready = {}, confirm = {}, stage = "Pick"}
	trades[req.from], trades[player] = t, t
	send(t)
	return nil
end
function ACTIONS.TradeDecline(player, prof)
	local req = requests[player]
	requests[player] = nil
	if req and req.from.Parent then API.toast(req.from, ("%s said no thanks to the trade."):format(player.DisplayName)) end
	return nil
end
function ACTIONS.TradeSet(player, prof, ids)
	local t = trades[player]
	if not t or type(ids) ~= "table" or #ids > Data.TradeMax then return nil end
	local list, seen = {}, {}
	for _, id in ids do
		local rec = API.findRec(prof, id)
		if tradable(prof, rec) and not seen[id] then
			seen[id] = true
			table.insert(list, rec)
		end
	end
	if #list >= #prof.Pets then return "Keep at least one pet for yourself!" end
	t.offer[player] = list
	t.ready, t.confirm, t.stage = {}, {}, "Pick" -- any change: both sides must look again
	send(t)
	return nil
end
function ACTIONS.TradeReady(player, prof, on)
	local t = trades[player]
	if not t then return nil end
	t.ready[player] = on and true or nil
	t.confirm = {}
	t.stage = (t.ready[t.a] and t.ready[t.b]) and "Confirm" or "Pick"
	send(t)
	return nil
end
function ACTIONS.TradeConfirm(player, prof)
	local t = trades[player]
	if not t or t.stage ~= "Confirm" then return nil end
	t.confirm[player] = true
	send(t)
	if not (t.confirm[t.a] and t.confirm[t.b]) then return nil end
	-- both said yes: check everything again, then swap
	local pa, pb = API.profiles[t.a], API.profiles[t.b]
	if not pa or not pb then closeTrade(t, "Trade cancelled.") return nil end
	for _, side in {{t.a, pa}, {t.b, pb}} do
		for _, rec in t.offer[side[1]] do
			local found = API.findRec(side[2], rec.Id)
			if found ~= rec or not tradable(side[2], rec) then closeTrade(t, "Something changed, trade cancelled.") return nil end
		end
	end
	if #pa.Pets - #t.offer[t.a] + #t.offer[t.b] > Data.PetCap or #pb.Pets - #t.offer[t.b] + #t.offer[t.a] > Data.PetCap then
		closeTrade(t, "Not enough room for the pets.")
		return nil
	end
	local function move(fromP, fromProf, toP, toProf, rec)
		local c = API.critterFor(rec)
		if c then API.removeCritter(c) end
		local _, i = API.findRec(fromProf, rec.Id)
		table.remove(fromProf.Pets, i)
		if fromProf.FollowId == rec.Id then fromProf.FollowId = nil end
		rec.Id = toProf.NextId
		toProf.NextId += 1
		rec.GearId, rec.NestRest, rec.Riding = nil, nil, nil
		rec.Stored = onFarmCount(toProf) >= farmCap(toProf) or nil
		table.insert(toProf.Pets, rec)
		toProf.Found[rec.Species] = true
		API.spawnCritter(Data.SpeciesByName[rec.Species], toP, rec)
	end
	local giveA, giveB = t.offer[t.a], t.offer[t.b]
	for _, rec in giveA do move(t.a, pa, t.b, pb, rec) end
	for _, rec in giveB do move(t.b, pb, t.a, pa, rec) end
	for _, p in {t.a, t.b} do
		API.fillSlots(p)
		API.pushState(p)
	end
	closeTrade(t, "🤝 Trade done! Say thank you!")
	return nil
end
function ACTIONS.TradeCancel(player, prof)
	local t = trades[player]
	if t then closeTrade(t, ("%s closed the trade."):format(player.DisplayName)) end
	return nil
end
Players.PlayerRemoving:Connect(function(p)
	requests[p] = nil
	local t = trades[p]
	if t then closeTrade(t, "The other player left.") end
end)

print("[PetLife] ready")
