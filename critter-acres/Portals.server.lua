-- Critter Acres: Portals (ServerScriptService)
-- Every farm is its own sky island. To travel you walk into a 🌀 portal (one on each island, one in town,
-- one in the Meadow, one in each biome) and pick where to go. Travel actions only work next to a portal.
local API = require(script.Parent:WaitForChild("CritterAPI"))
while not API.Ready do task.wait(0.2) end
local t0 = os.clock()
while not API.TravelReady and os.clock() - t0 < 15 do task.wait(0.2) end -- let Adventure wrap Travel (gate locks) first
local ACTIONS = API.ACTIONS
local root = workspace:WaitForChild("CritterAcres")
local portals = root:WaitForChild("Portals", 30)

local MSG = "🌀 Walk into a portal to travel!"
local NEAR = 24

local function nearPortal(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not portals then return false end
	for _, m in portals:GetChildren() do
		local g = m:FindFirstChild("Gate")
		if g and (g.Position - hrp.Position).Magnitude <= NEAR then return true end
	end
	return false
end
API.nearPortal = nearPortal

-- the old "teleport from anywhere" actions now need a portal
local raw = {}
for _, name in {"Travel", "Visit", "GoHome", "TravelShop", "TravelEvent"} do
	raw[name] = ACTIONS[name]
	ACTIONS[name] = function(player, prof, ...)
		if not nearPortal(player) then return MSG end
		return raw[name](player, prof, ...)
	end
end

-- 🌀 the portal picker: kind = Home / Town / Place (biome name) / Visit (userId) / Event
function ACTIONS.PortalGo(player, prof, kind, arg)
	if not nearPortal(player) then return MSG end
	if player:GetAttribute("Carrying") then return "🥚 Bring the golden egg to the 🌀 Terrain Portal to win!" end
	if kind == "Home" then
		return raw.GoHome(player, prof)
	elseif kind == "Town" then
		return raw.Travel(player, prof, "Plaza")
	elseif kind == "Place" and type(arg) == "string" then
		if arg == "Plaza" then return raw.Travel(player, prof, "Plaza") end
		return raw.Travel(player, prof, arg)
	elseif kind == "Visit" and type(arg) == "number" then
		return raw.Visit(player, prof, arg)
	elseif kind == "Event" then
		local r = raw.TravelEvent(player, prof)
		if r == nil and not workspace:GetAttribute("Event") then return "🎉 No event right now." end
		return r
	elseif kind == "Shop" then
		return raw.TravelShop(player, prof)
	end
	return "🌀 ❔"
end

print("[Portals] ready")
