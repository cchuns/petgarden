-- CritterSync: Studio plugin for the Critter Editor (critter-acres/editor).
-- Installed copy: %LOCALAPPDATA%\Roblox\Plugins\CritterSync.lua (this file is the mirror).
-- ⬇ Pull reads the editor's data from the helper (http://localhost:34880, started by "Start Critter Editor.bat")
-- and writes it into ReplicatedStorage.CritterData.GameData. CritterData turns that JSON into the game tables.
-- It also puts imported 3D models into WeaponModels / PetModels ("Use selected").
local RunService = game:GetService("RunService")
if not RunService:IsEdit() then return end -- only in the editing window, not in playtests

local HttpService = game:GetService("HttpService")
local CHS = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local URL = "http://localhost:34880"
local POLL = 2

---------------------------------------------------------------- look (UIKit colors)
local CREAM, CARD, BROWN, SOFT, LINE = Color3.fromRGB(255, 250, 238), Color3.fromRGB(255, 255, 255), Color3.fromRGB(85, 60, 40),
	Color3.fromRGB(140, 115, 90), Color3.fromRGB(235, 220, 195)
local GREEN, YELLOW, RED, BLUE = Color3.fromRGB(110, 200, 95), Color3.fromRGB(255, 205, 80), Color3.fromRGB(240, 120, 110), Color3.fromRGB(120, 175, 245)

local toolbar = plugin:CreateToolbar("Critter Acres")
local button = toolbar:CreateButton("CritterSync", "Pull weapons, pets, eggs, capsules, skills and decorations from the Critter Editor", "rbxassetid://4458901886", "CritterSync")
button.ClickableWhenViewportHidden = true
local widget = plugin:CreateDockWidgetPluginGui("CritterSync",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 340, 520, 280, 300))
widget.Title = "🛠 CritterSync"
button.Click:Connect(function() widget.Enabled = not widget.Enabled end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function() button:SetActive(widget.Enabled) end)

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in props do i[k] = v end
	i.Parent = parent
	return i
end
local function corner(p, r) new("UICorner", {CornerRadius = UDim.new(0, r or 10)}, p) end
local function stroke(p, c, t) new("UIStroke", {Color = c or LINE, Thickness = t or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, p) end

local root = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = CREAM, BorderSizePixel = 0, ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, widget)
new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)}, root)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, root)

local order = 0
local function nextOrder() order += 1 return order end
local function label(parent, text, size, color, bold)
	return new("TextLabel", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = text,
		TextColor3 = color or BROWN, TextSize = size or 15, Font = bold and Enum.Font.FredokaOne or Enum.Font.GothamMedium,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, RichText = true, LayoutOrder = nextOrder()}, parent)
end
local function card(parent)
	local f = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = CARD, LayoutOrder = nextOrder()}, parent)
	corner(f, 12) stroke(f)
	new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}, f)
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, f)
	return f
end
local function btn(parent, text, color, fn, h)
	local b = new("TextButton", {Size = UDim2.new(1, 0, 0, h or 38), BackgroundColor3 = color or CARD, Text = text, TextColor3 = (color == GREEN or color == BLUE or color == RED) and CARD or BROWN,
		TextSize = 16, Font = Enum.Font.FredokaOne, AutoButtonColor = true, LayoutOrder = nextOrder()}, parent)
	corner(b, 10) stroke(b, Color3.new(0, 0, 0), 0)
	b.UIStroke.Transparency = 0.85
	b.MouseButton1Click:Connect(fn)
	return b
end

label(root, "🛠 Critter Editor sync", 20, BROWN, true)
local statusCard = card(root)
local helperLine = label(statusCard, "🔌 Helper: checking…")
local versionLine = label(statusCard, "")
local pullBtn
local autoOn = plugin:GetSetting("AutoPull") == true
local autoBtn

local changesCard = card(root)
label(changesCard, "📝 Last pull", 16, BROWN, true)
local changesText = label(changesCard, "Nothing pulled yet.", 14, SOFT)

local modelsCard = card(root)
label(modelsCard, "🧊 3D models", 16, BROWN, true)
label(modelsCard, "1. File → Import 3D, pick the file from critter-acres\\editor\\models.\n2. Select the imported model.\n3. Press “Use selected” on its row below.", 13, SOFT)
local modelList = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder()}, modelsCard)
new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, modelList)

---------------------------------------------------------------- helpers
local lastBundle -- decoded bundle from the helper
local helperVersion
local busy = false

local function http(method, path, body)
	local ok, res = pcall(function()
		return HttpService:RequestAsync({Url = URL .. path, Method = method, Body = body,
			Headers = body and {["Content-Type"] = "application/json"} or nil})
	end)
	if not ok then return nil, tostring(res) end
	if not res.Success then return nil, ("HTTP %d"):format(res.StatusCode) end
	return res.Body
end

local function gameData()
	local cd = ReplicatedStorage:FindFirstChild("CritterData")
	return cd, cd and cd:FindFirstChild("GameData")
end
local function syncedVersion()
	local _, gd = gameData()
	return gd and gd:GetAttribute("Version")
end

local function modelReport()
	local weapons, pets = {}, {}
	local wf, pf = ReplicatedStorage:FindFirstChild("WeaponModels"), ReplicatedStorage:FindFirstChild("PetModels")
	for _, m in wf and wf:GetChildren() or {} do table.insert(weapons, m.Name) end
	for _, m in pf and pf:GetChildren() or {} do pets[m.Name] = m:GetAttribute("Rig") or "Blob" end
	-- decorations with a real shape = a "function DECOR.<Name without spaces>" in Builds (the rest get the placeholder box)
	local decor = {}
	local b = ReplicatedStorage:FindFirstChild("Builds")
	if b and b:IsA("ModuleScript") then
		for name in b.Source:gmatch("function DECOR%.([%w_]+)%(") do table.insert(decor, name) end
	end
	return weapons, pets, decor
end

local function report()
	local weapons, pets, decor = modelReport()
	local _, gd = gameData()
	local body = HttpService:JSONEncode({synced = syncedVersion(), at = gd and gd:GetAttribute("PulledAt"), auto = autoOn,
		place = game.Name, models = {weapons = weapons, pets = pets, decor = decor}})
	http("POST", "/api/studio", body)
end

-- short list of what changed between two decoded bundles
local CATS = {
	{"weapons", "⚔️", "Name"}, {"pets", "🐾", "Species"}, {"eggs", "🥚", "Id"}, {"capsules", "🎁", "Id"}, {"skills", "🌳", "Id"}, {"decor", "🏡", "Name"},
	{"herogear", "🛡️", "Name"}, {"herosets", "✨", "Id"}, {"herolooks", "🎨", "Id"},
}
local function same(a, b) return HttpService:JSONEncode(a) == HttpService:JSONEncode(b) end
local function short(v)
	if type(v) == "table" then return "…" end
	local s = tostring(v)
	return #s > 18 and s:sub(1, 16) .. "…" or s
end
local function diff(old, new)
	local lines = {}
	for _, c in CATS do
		local key, icon, idKey = c[1], c[2], c[3]
		local o, n = {}, {}
		for _, it in (old and old[key]) or {} do o[it[idKey]] = it end
		for _, it in new[key] or {} do n[it[idKey]] = it end
		for id, it in n do
			if not o[id] then
				table.insert(lines, ("%s ＋ %s"):format(icon, id))
			elseif not same(o[id], it) then
				local bits = {}
				for k, v in it do
					if not same(o[id][k], v) then table.insert(bits, ("%s %s→%s"):format(k, short(o[id][k]), short(v))) end
				end
				for k in o[id] do if it[k] == nil then table.insert(bits, k .. " removed") end end
				table.insert(lines, ("%s ✏️ %s: %s"):format(icon, id, table.concat(bits, ", ")))
			end
		end
		for id in o do if not n[id] then table.insert(lines, ("%s 🗑 %s"):format(icon, id)) end end
	end
	return lines
end

---------------------------------------------------------------- pull
local function setStatus()
	local sv = syncedVersion()
	if helperVersion then
		helperLine.Text = "🔌 Helper: <font color=\"#4a9c3c\">connected</font> · editor v" .. helperVersion
	else
		helperLine.Text = "🔌 Helper: <font color=\"#d0584e\">not running</font>\nDouble-click “Start Critter Editor.bat” in critter-acres\\editor."
	end
	versionLine.Text = ("🎮 This place has v%s%s"):format(tostring(sv or "–"),
		helperVersion and sv and sv >= helperVersion and "  ✅ up to date" or (helperVersion and "  → press ⬇ Pull" or ""))
	if pullBtn then pullBtn.Text = busy and "⏳ Pulling…" or "⬇ Pull from editor" end
	if autoBtn then
		autoBtn.Text = autoOn and "🔁 Auto-pull: ON" or "🔁 Auto-pull: OFF"
		autoBtn.BackgroundColor3 = autoOn and YELLOW or CARD
	end
end

local function pull()
	if busy then return end
	busy = true
	setStatus()
	local text, err = http("GET", "/api/data")
	if not text then
		busy = false
		changesText.Text = "❌ Can't reach the helper (" .. tostring(err) .. ")."
		setStatus()
		return
	end
	local okDecode, bundle = pcall(HttpService.JSONDecode, HttpService, text)
	if not okDecode then
		busy = false
		changesText.Text = "❌ The editor's data isn't valid JSON."
		setStatus()
		return
	end
	local cd, gd = gameData()
	if not cd then
		busy = false
		changesText.Text = "❌ ReplicatedStorage.CritterData is missing."
		setStatus()
		return
	end
	if not cd.Source:find("ApplyGameData", 1, true) then
		busy = false
		changesText.Text = "❌ CritterData has no editor hook yet (ask Claude to add it)."
		setStatus()
		return
	end
	-- what changed (for the list)
	local oldBundle
	if gd then
		local _, oldText = gd.Source:match("return %[(=*)%[(.*)%]%1%]")
		if oldText then pcall(function() oldBundle = HttpService:JSONDecode(oldText) end) end
	end
	local lines = oldBundle and diff(oldBundle, bundle) or {"First pull: the editor's data is now the game's data."}
	-- wrap the JSON in a long string that it can't close by accident
	local eq = "="
	while text:find("]" .. eq .. "]", 1, true) do eq ..= "=" end
	local src = "-- Written by the CritterSync plugin from the Critter Editor (critter-acres/editor). Don't edit by hand.\nreturn [" .. eq .. "[" .. text .. "]" .. eq .. "]"
	-- test it on a copy of CritterData first
	local test = cd:Clone()
	local tgd = test:FindFirstChild("GameData") or new("ModuleScript", {Name = "GameData"}, test)
	tgd.Source = src
	local okReq, D = pcall(require, test)
	local problem
	if not okReq then
		problem = "CritterData crashed: " .. tostring(D)
	elseif not D.GameDataOn then
		local _, e = pcall(D.ApplyGameData, text)
		problem = tostring(e)
	end
	test:Destroy()
	if problem then
		busy = false
		changesText.Text = "❌ Not pulled, the game would reject it:\n" .. problem
		changesText.TextColor3 = RED
		setStatus()
		return
	end
	local rec = CHS:TryBeginRecording("Critter Editor pull")
	if not gd then gd = new("ModuleScript", {Name = "GameData"}, cd) end
	gd.Source = src
	gd:SetAttribute("Version", bundle.version)
	gd:SetAttribute("PulledAt", os.time())
	if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
	lastBundle = bundle
	busy = false
	changesText.TextColor3 = SOFT
	changesText.Text = ("✅ v%s pulled at %s\n"):format(tostring(bundle.version), os.date("%H:%M:%S")) ..
		(#lines > 0 and table.concat(lines, "\n", 1, math.min(#lines, 25)) .. (#lines > 25 and ("\n…and %d more"):format(#lines - 25) or "") or "No changes in the data.") ..
		"\n\nPlaytest, then File → Save to Roblox."
	print(("[CritterSync] pulled editor v%s (%d changes)"):format(tostring(bundle.version), #lines))
	setStatus()
	report()
end

---------------------------------------------------------------- models
local function backup(folderName, inst)
	local b = ServerStorage:FindFirstChild(folderName) or new("Folder", {Name = folderName}, ServerStorage)
	inst.Name = inst.Name .. "_" .. os.date("%m%d%H%M")
	inst.Parent = b
end
local function partsOf(sel)
	local parts = {}
	if sel:IsA("BasePart") then table.insert(parts, sel) end
	for _, d in sel:GetDescendants() do if d:IsA("BasePart") then table.insert(parts, d) end end
	return parts
end

local function useForWeapon(id)
	local sel = Selection:Get()[1]
	if not sel then return "Select the imported model first." end
	local parts = partsOf(sel)
	if #parts == 0 then return "That has no parts." end
	if #parts > 1 then return "A weapon must be ONE mesh piece (this has " .. #parts .. "). Join it in Blender first." end
	local rec = CHS:TryBeginRecording("Critter weapon model")
	local p = parts[1]:Clone()
	for _, c in p:GetChildren() do if c:IsA("JointInstance") or c:IsA("WeldConstraint") then c:Destroy() end end
	p.Name = "Handle"
	p.Anchored, p.CanCollide = true, false
	local s = p.Size
	local long = math.max(s.X, s.Y, s.Z)
	p.Size = s * (4 / long) -- about as long as the other weapons
	p.CFrame = CFrame.new()
	local m = new("Model", {Name = id}, nil)
	p.Parent = m
	m.PrimaryPart = p
	local folder = ReplicatedStorage:FindFirstChild("WeaponModels") or new("Folder", {Name = "WeaponModels"}, ReplicatedStorage)
	local old = folder:FindFirstChild(id)
	if old then backup("OldWeaponModels", old) end
	m.Parent = folder
	Selection:Set({m})
	if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
	report()
	if long ~= s.Y then return "✅ Done, but its long side isn't up (Y). It may look sideways in the hand: re-export standing up." end
	return "✅ " .. id .. " model is in WeaponModels."
end

local function useForPet(id)
	local sel = Selection:Get()[1]
	if not sel then return "Select the imported model first." end
	local parts = partsOf(sel)
	if #parts == 0 then return "That has no parts." end
	local rec = CHS:TryBeginRecording("Critter pet model")
	local m = new("Model", {Name = id}, nil)
	local biggest, bv = nil, -1
	for _, src in parts do
		local p = src:Clone()
		for _, c in p:GetChildren() do if c:IsA("JointInstance") or c:IsA("WeldConstraint") or c:IsA("BasePart") then c:Destroy() end end
		p.Anchored, p.CanCollide, p.CFrame = true, false, src.CFrame
		p.Parent = m
		local v = p.Size.X * p.Size.Y * p.Size.Z
		if v > bv then biggest, bv = p, v end
	end
	biggest.Name = "Body"
	m.PrimaryPart = biggest
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * (3 / math.max(size.X, size.Y, size.Z))) -- same size as the other pets
	m:PivotTo(CFrame.new(0, 0, 0))
	local folder = ReplicatedStorage:FindFirstChild("PetModels") or new("Folder", {Name = "PetModels"}, ReplicatedStorage)
	local old = folder:FindFirstChild(id)
	if old then backup("OldPetModels", old) end
	m.Parent = folder
	Selection:Set({m})
	if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
	report()
	local _, s2 = m:GetBoundingBox()
	local flat = math.min(s2.X, s2.Z) < 0.7 * math.max(s2.X, s2.Z)
	return "✅ " .. id .. " is in PetModels (one-piece bouncy look)." ..
		(flat and "\n⚠️ It looks flat (depth < 70% of width)." or "") .. "\nAsk Claude to add the face rig (blinking eyes + mouth)."
end

local function renderModels()
	for _, c in modelList:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	if not lastBundle then
		label(modelList, "Pull once to see which items need a model.", 13, SOFT)
		return
	end
	local weapons, pets = modelReport()
	local have = {}
	for _, n in weapons do have["w:" .. n] = true end
	for n in pets do have["p:" .. n] = true end
	local rows = 0
	local function row(kind, icon, id, file)
		rows += 1
		local f = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = CREAM, LayoutOrder = rows}, modelList)
		corner(f, 8)
		new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, f)
		new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, f)
		label(f, ("%s <b>%s</b>  %s"):format(icon, id, file and ("📦 " .. file) or "no file yet"), 14)
		local msg
		btn(f, "Use selected", BLUE, function()
			local ok, res = pcall(kind == "w" and useForWeapon or useForPet, id)
			res = ok and res or ("❌ " .. tostring(res))
			if msg then msg.Text = res else msg = label(f, res, 13, SOFT) end
			if ok and tostring(res):sub(1, 3) == "✅" then task.delay(2.5, renderModels) end
		end, 30)
	end
	for _, w in lastBundle.weapons or {} do if not have["w:" .. w.Name] then row("w", "⚔️", w.Name, w.ModelFile) end end
	for _, p in lastBundle.pets or {} do if not have["p:" .. p.Species] then row("p", "🐾", p.Species, p.ModelFile) end end
	if rows == 0 then label(modelList, "✅ Every weapon and pet has a model.", 13, SOFT) end
end

---------------------------------------------------------------- buttons + polling
pullBtn = btn(statusCard, "⬇ Pull from editor", GREEN, function() pull() renderModels() end)
autoBtn = btn(statusCard, "", CARD, function()
	autoOn = not autoOn
	plugin:SetSetting("AutoPull", autoOn)
	setStatus()
	report()
end, 32)
btn(modelsCard, "🔄 Refresh list", CARD, function()
	if not lastBundle then
		local text = http("GET", "/api/data")
		if text then pcall(function() lastBundle = HttpService:JSONDecode(text) end) end
	end
	renderModels()
	report()
end, 30)
setStatus()
renderModels()

local alive = true
plugin.Unloading:Connect(function() alive = false end)
task.spawn(function()
	local reported = false
	while alive do
		if widget.Enabled or autoOn then
			local body = http("GET", "/api/version")
			local v
			if body then pcall(function() v = HttpService:JSONDecode(body).version end) end
			local was = helperVersion
			helperVersion = v
			if v and not reported then reported = true report() end
			if not v then reported = false end
			if v and autoOn and not busy and (syncedVersion() or 0) < v then
				pull()
				renderModels()
			elseif was ~= v then
				setStatus()
			end
		end
		task.wait(POLL)
	end
end)
