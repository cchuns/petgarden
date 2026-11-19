-- Critter Acres: DungeonScore (StarterPlayerScripts LocalScript)
-- 🏆 The ⭐ run score card when a dungeon boss falls (ServerScriptService.DungeonRewards sends it on
-- RemoteEvent ReplicatedStorage.DungeonEvent, Kind "Score"). ⭐ cleared, ⭐ fast (beat the time goal), ⭐ found half the
-- chests. More stars = more coins in the 🎁 boss chest. 🎉 first clears show their bonus here too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local K = require(ReplicatedStorage:WaitForChild("UIKit"))
local event = ReplicatedStorage:WaitForChild("DungeonEvent", 60)
if not event then return end
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "DungeonScore"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 8
gui.Parent = player:WaitForChild("PlayerGui")

local win = K.window(gui, {Icon = "🏆", Title = "Dungeon cleared!", Max = Vector2.new(560, 560)})

local function clock(secs)
	return ("%d:%02d"):format(secs // 60, secs % 60)
end

local function show(msg)
	win.clear()
	win.setTabs({})
	win.setSub(("%s %s ⭐%d"):format(msg.Icon or "🏰", msg.Name or "Dungeon", msg.Tier or 1))
	win.setHelp({{"✅", "Beat the boss: 1 star."}, {"⏱️", "Beat the time goal: 1 more star."},
		{"🧺", "Find half of the chests (secret ones count!): 1 more star. Stars give more boss chest coins."}})
	local body = win.body
	local stars = msg.Stars or 1
	K.header(body, string.rep("⭐", stars) .. ("  %d star%s!"):format(stars, stars == 1 and "" or "s"), 1,
		msg.NewBest and "🎉 Your best score here!" or ("Best here: " .. string.rep("⭐", msg.Best or stars)))
	K.row(body, {Order = 2, Icon = "✅", Title = "Boss beaten", Sub = "⭐ +1"})
	K.row(body, {Order = 3, Icon = "⏱️", Title = ("Time %s"):format(clock(msg.Secs or 0)),
		Sub = msg.Fast and ("⭐ +1 · goal %s"):format(clock(msg.Par or 0)) or ("Goal %s · faster next time!"):format(clock(msg.Par or 0))})
	K.row(body, {Order = 4, Icon = "🧺", Title = ("Chests %d/%d"):format(msg.Found or 0, msg.Total or 0),
		Sub = msg.Hunter and "⭐ +1 · treasure hunter!" or "Find half for a ⭐ (look for secret ones!)"})
	K.row(body, {Order = 5, Icon = "😵", Title = ("Faints %d"):format(msg.Faints or 0), Sub = "Fainting is free, it never costs anything"})
	K.row(body, {Order = 6, Icon = "🎁", Title = ("Boss chest coins x%s"):format(tostring(msg.X or 1)), Sub = "Open the 🎁 boss chest!"})
	if msg.First then
		K.row(body, {Order = 7, Icon = "🎉", Title = "First clear bonus!",
			Sub = ("💰 +%d%s"):format(msg.First.Coins or 0, msg.First.Capsule and ("  ·  " .. msg.First.Capsule) or "")})
	end
	K.button(body, {Text = "✔ Nice!", Size = UDim2.fromOffset(200, 54), LayoutOrder = 9, Kind = "go", Max = 22}, function() win.close() end)
	win.open()
end

event.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" then return end
	if msg.Kind == "Score" then show(msg) end
end)
