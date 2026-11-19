-- Critter Acres: UIKit (ReplicatedStorage)
-- One look for every menu: windows (icon + title + subtitle, tabs, ❓ and ✖), cards, rows, buttons,
-- progress bars and tooltips (hover on PC, press and hold on touch).
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local K = {}
K.FONT = Enum.Font.FredokaOne
K.CREAM = Color3.fromRGB(255, 250, 238)
K.CARD = Color3.fromRGB(255, 255, 255)
K.BROWN = Color3.fromRGB(85, 60, 40)
K.SOFT = Color3.fromRGB(140, 115, 90)
K.LINE = Color3.fromRGB(235, 220, 195)
K.GREEN = Color3.fromRGB(110, 200, 95)
K.YELLOW = Color3.fromRGB(255, 205, 80)
K.RED = Color3.fromRGB(240, 120, 110)
K.GREY = Color3.fromRGB(215, 210, 203)
K.BLUE = Color3.fromRGB(120, 175, 245)
K.WHITE = Color3.new(1, 1, 1)
K.KIND = {go = K.GREEN, special = K.YELLOW, careful = K.RED, no = K.GREY, plain = K.CARD}

local click = Instance.new("Sound")
click.SoundId = "rbxasset://sounds/electronicpingshort.wav"
click.Volume = 0.25
click.PlaybackSpeed = 1.6

function K.round(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 14)
	c.Parent = o
	return o
end
function K.stroke(o, color, t)
	local s = Instance.new("UIStroke")
	s.Color, s.Thickness = color or K.LINE, t or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
	return s
end
function K.frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = K.CARD
	for k, v in props or {} do f[k] = v end
	f.Parent = parent
	return f
end
function K.text(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = K.FONT
	t.TextScaled = true
	t.TextColor3 = K.BROWN
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize, c.MaxTextSize = 12, (props and props.Max) or 26
	if props then props.Max = nil end
	c.Parent = t
	for k, v in props or {} do t[k] = v end
	t.Parent = parent
	return t
end
function K.list(parent, dir, pad, align)
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, pad or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if align then l.HorizontalAlignment = align end
	l.Parent = parent
	return l
end
function K.grid(parent, cell, order)
	local g = K.frame(parent, {Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order or 0})
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = cell
	gl.CellPadding = UDim2.fromOffset(10, 10)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = g
	return g
end

---------------------------------------------------------------- tooltips
local tipGui, tipBox, tipTitle, tipBody
local function ensureTip()
	if tipGui then return end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	tipGui = Instance.new("ScreenGui")
	tipGui.Name = "CritterTooltip"
	tipGui.DisplayOrder = 50
	tipGui.ResetOnSpawn = false
	tipGui.IgnoreGuiInset = true
	tipGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	tipGui.Parent = pg
	tipBox = K.frame(tipGui, {Size = UDim2.fromOffset(240, 64), BackgroundColor3 = Color3.fromRGB(55, 42, 70), Visible = false, ZIndex = 100, Active = false})
	pcall(function() tipBox.Interactable = false end) -- a tooltip never catches clicks meant for the button under it
	K.round(tipBox, 12)
	tipTitle = K.text(tipBox, {Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 22), TextColor3 = K.WHITE, ZIndex = 101,
		TextXAlignment = Enum.TextXAlignment.Left, Max = 20})
	tipBody = K.text(tipBox, {Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 26), TextColor3 = Color3.fromRGB(230, 220, 245), ZIndex = 101,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Max = 16})
end
local tipOwner
local function showTip(gui, title, body)
	ensureTip()
	tipOwner = gui
	tipTitle.Text = title
	tipBody.Text = body or ""
	tipBody.Visible = body ~= nil and body ~= ""
	tipBox.Size = UDim2.fromOffset(250, (body and body ~= "") and 64 or 36)
	local cam = workspace.CurrentCamera.ViewportSize
	local p, s = gui.AbsolutePosition, gui.AbsoluteSize
	-- the tooltip layer ignores the top bar inset; add it only when the button's own ScreenGui doesn't ignore it
	local sg = gui:FindFirstAncestorOfClass("ScreenGui")
	local inset = (sg and not sg.IgnoreGuiInset) and game:GetService("GuiService"):GetGuiInset().Y or 0
	local x = math.clamp(p.X + s.X / 2 - 125, 8, cam.X - 258)
	local y = p.Y + inset - tipBox.Size.Y.Offset - 6 -- above the button, never on top of it
	if y < 8 then y = p.Y + inset + s.Y + 6 end -- (no room above: under it)
	tipBox.Position = UDim2.fromOffset(x, y)
	tipBox.Visible = true
end
local function hideTip(gui)
	if tipBox and (gui == nil or tipOwner == gui) then tipBox.Visible = false end
end
-- Tooltip on any GuiObject: hover (mouse) or press and hold 0.4s (touch).
function K.tip(gui, title, body)
	gui.MouseEnter:Connect(function()
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then return end
		task.delay(0.25, function()
			if gui.Parent and gui:IsDescendantOf(game) then showTip(gui, title, body) end
		end)
	end)
	gui.MouseLeave:Connect(function() hideTip(gui) end)
	gui.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		local t0 = os.clock()
		local held = true
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then held = false hideTip(gui) conn:Disconnect() end
		end)
		task.delay(0.4, function()
			if held and os.clock() - t0 >= 0.39 then showTip(gui, title, body) end
		end)
	end)
	gui.AncestryChanged:Connect(function() if not gui:IsDescendantOf(game) then hideTip(gui) end end)
	return gui
end

---------------------------------------------------------------- buttons
-- kind: "go" (green), "special" (yellow), "careful" (red), "no" (grey, still tappable: fn can explain why), "plain"
function K.button(parent, props, fn)
	local kind = props.Kind or "plain"
	props.Kind = nil
	local tipT, tipB = props.Tip, props.TipText
	props.Tip, props.TipText = nil, nil
	local b = Instance.new("TextButton")
	b.Font = K.FONT
	b.TextScaled = true
	b.TextColor3 = kind == "no" and K.SOFT or K.BROWN
	b.BackgroundColor3 = K.KIND[kind] or K.CARD
	b.AutoButtonColor = false
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize, c.MaxTextSize = 12, props.Max or 22
	props.Max = nil
	c.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = b
	for k, v in props do b[k] = v end
	K.round(b, 12)
	K.stroke(b, kind == "plain" and K.LINE or (K.KIND[kind] or K.LINE):Lerp(Color3.new(0, 0, 0), 0.15), 2)
	b.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseButton1Down:Connect(function() TweenService:Create(scale, TweenInfo.new(0.08), {Scale = 0.93}):Play() end)
	b.MouseButton1Up:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), {Scale = 1}):Play() end)
	b.MouseLeave:Connect(function() scale.Scale = 1 end)
	if fn then
		b.Activated:Connect(function()
			SoundService:PlayLocalSound(click)
			hideTip()
			fn()
		end)
	end
	if tipT then K.tip(b, tipT, tipB) end
	return b
end
-- a big icon button with a word under it (dock style)
function K.iconButton(parent, icon, word, props, fn)
	props.Text = ""
	local b = K.button(parent, props, fn)
	b.UIPadding:Destroy()
	K.text(b, {Name = "Icon", Text = icon, Size = UDim2.fromScale(1, 0.62), ZIndex = b.ZIndex + 1, Max = 40})
	K.text(b, {Name = "Word", Text = word, Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.36), ZIndex = b.ZIndex + 1, Max = 18})
	return b
end
function K.badge(parent, n)
	local d = parent:FindFirstChild("Badge")
	if not d then
		d = K.text(parent, {Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(240, 70, 80), TextColor3 = K.WHITE, ZIndex = (parent.ZIndex or 1) + 5, Max = 16})
		K.round(d, 12)
	end
	d.Visible = n ~= nil and n ~= 0 and n ~= false
	d.Text = type(n) == "number" and tostring(n) or ""
	d.Size = type(n) == "number" and UDim2.fromOffset(24, 24) or UDim2.fromOffset(14, 14)
	return d
end
function K.bar(parent, frac, color, props)
	local bg = K.frame(parent, {BackgroundColor3 = Color3.fromRGB(235, 228, 215)})
	for k, v in props or {} do bg[k] = v end
	K.round(bg, 8)
	local fill = K.frame(bg, {Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1), BackgroundColor3 = color or K.GREEN, ZIndex = bg.ZIndex})
	K.round(fill, 8)
	return bg, fill
end

---------------------------------------------------------------- windows
-- K.window(gui, {Icon, Title, Max = Vector2}) -> win object {frame, setSub(text), setTabs(list, on, fn), body (scrolling), clear(), close()}
function K.window(gui, opts)
	local w = {}
	local f = K.frame(gui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.new(0.94, 0, 0.8, 0),
		BackgroundColor3 = K.CREAM, Visible = false, ZIndex = 20})
	K.round(f, 22)
	K.stroke(f, Color3.fromRGB(230, 205, 165), 3)
	local sc = Instance.new("UISizeConstraint")
	sc.MaxSize = opts.Max or Vector2.new(860, 580)
	sc.Parent = f
	local Z = 21
	local icon = K.text(f, {Text = opts.Icon or "", Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(52, 52), ZIndex = Z, Max = 40})
	local title = K.text(f, {Text = opts.Title or "", Position = UDim2.fromOffset(72, 8), Size = UDim2.new(1, -200, 0, 32), ZIndex = Z,
		TextXAlignment = Enum.TextXAlignment.Left, Max = 28})
	local sub = K.text(f, {Text = "", Position = UDim2.fromOffset(72, 40), Size = UDim2.new(1, -200, 0, 22), ZIndex = Z, TextColor3 = K.SOFT,
		TextXAlignment = Enum.TextXAlignment.Left, Max = 18})
	local closeB = K.button(f, {Text = "✖", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(46, 46), ZIndex = Z,
		Kind = "careful", Tip = "Close"}, function() w.close() end)
	local helpB = K.button(f, {Text = "❓", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -64, 0, 12), Size = UDim2.fromOffset(46, 46), ZIndex = Z,
		Tip = "How does this work?"}, function() if w.onHelp then w.onHelp() end end)
	local tabs = K.frame(f, {Position = UDim2.fromOffset(14, 70), Size = UDim2.new(1, -28, 0, 44), BackgroundTransparency = 1, ZIndex = Z})
	K.list(tabs, Enum.FillDirection.Horizontal, 8)
	local body = Instance.new("ScrollingFrame")
	body.Position = UDim2.fromOffset(14, 122)
	body.Size = UDim2.new(1, -28, 1, -134)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 8
	body.ScrollBarImageColor3 = Color3.fromRGB(200, 170, 130)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ZIndex = Z
	body.Parent = f
	-- help overlay: 3 picture steps
	local help = K.frame(f, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(55, 42, 70), BackgroundTransparency = 0.05, Visible = false, ZIndex = 40})
	K.round(help, 22)
	w.frame, w.body, w.Z = f, body, Z + 1
	function w.setTitle(icn, t) icon.Text, title.Text = icn, t end
	function w.setSub(t) sub.Text = t or "" end
	function w.clear()
		for _, ch in body:GetChildren() do ch:Destroy() end
		K.list(body, Enum.FillDirection.Vertical, 10)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingLeft, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 10)
		pad.Parent = body
	end
	-- list = {{key, "icon Word", tipText, badge}}
	function w.setTabs(list, on, fn)
		for _, ch in tabs:GetChildren() do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
		tabs.Visible = #list > 0
		body.Position = UDim2.fromOffset(14, #list > 0 and 122 or 72)
		body.Size = UDim2.new(1, -28, 1, #list > 0 and -134 or -84)
		-- natural widths from the real text size, shrunk evenly when the row would run past the window edge
		local TextService = game:GetService("TextService")
		local widths, total = {}, 0
		for i, t in list do
			local w = TextService:GetTextSize(t[2], 20, K.FONT, Vector2.new(1000, 42)).X + 34
			widths[i] = math.max(96, w)
			total += widths[i]
		end
		local avail = tabs.AbsoluteSize.X > 0 and tabs.AbsoluteSize.X or 800
		local gaps = 8 * math.max(0, #list - 1)
		local fit = total + gaps > avail and (avail - gaps) / total or 1
		for i, t in list do
			local sel = t[1] == on
			local b = K.button(tabs, {Text = t[2], LayoutOrder = i, Size = UDim2.fromOffset(math.floor(widths[i] * fit), 42), ZIndex = Z,
				BackgroundColor3 = sel and Color3.fromRGB(255, 225, 130) or K.CARD, Max = 20, Tip = t[3] and t[2] or nil, TipText = t[3]}, function() fn(t[1]) end)
			if sel then b.UIStroke.Color, b.UIStroke.Thickness = Color3.fromRGB(230, 170, 50), 3 end
			if t[4] then K.badge(b, t[4]) end
		end
	end
	-- steps = {{icon, text}, x3}
	function w.setHelp(steps)
		w.onHelp = function()
			for _, ch in help:GetChildren() do
				if ch:IsA("GuiObject") then ch:Destroy() end
			end
			help.Visible = true
			K.text(help, {Text = "How it works", Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 40), TextColor3 = K.WHITE, ZIndex = 41, Max = 30})
			for i, st in steps do
				local card = K.frame(help, {Position = UDim2.new((i - 1) / #steps, 12, 0, 70), Size = UDim2.new(1 / #steps, -24, 1, -160), BackgroundColor3 = K.CREAM, ZIndex = 41})
				K.round(card, 18)
				K.text(card, {Text = tostring(i), Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(34, 34), ZIndex = 42, BackgroundTransparency = 0,
					BackgroundColor3 = K.YELLOW, Max = 22})
				K.text(card, {Text = st[1], Position = UDim2.fromScale(0, 0.12), Size = UDim2.fromScale(1, 0.42), ZIndex = 42, Max = 70})
				K.text(card, {Text = st[2], Position = UDim2.fromScale(0.06, 0.58), Size = UDim2.fromScale(0.88, 0.36), ZIndex = 42, TextWrapped = true, Max = 20})
			end
			K.button(help, {Text = "✔ Got it", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(200, 56), ZIndex = 42,
				Kind = "go"}, function() help.Visible = false end)
		end
	end
	function w.open()
		help.Visible = false
		f.Visible = true
		local s = f:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", f)
		s.Scale = 0.9
		TweenService:Create(s, TweenInfo.new(0.18, Enum.EasingStyle.Back), {Scale = 1}):Play()
	end
	function w.close()
		f.Visible = false
		hideTip()
		if w.onClose then w.onClose() end
	end
	w.clear()
	return w
end

-- a section header inside a window body
function K.header(body, text, order, sub)
	local h = K.frame(body, {Size = UDim2.new(1, -8, 0, sub and 50 or 32), BackgroundTransparency = 1, LayoutOrder = order or 0})
	K.text(h, {Text = text, Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Max = 22})
	if sub then K.text(h, {Text = sub, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 20), TextColor3 = K.SOFT, TextXAlignment = Enum.TextXAlignment.Left, Max = 16}) end
	return h
end
-- a row: icon, title (+ small line), optional progress, a button on the right
-- opts = {Icon, Title, Sub, Progress = {cur, max}, Button = {Text, Kind, Tip}, Fn, Order}
function K.row(body, opts)
	local r = K.frame(body, {Size = UDim2.new(1, -8, 0, 64), LayoutOrder = opts.Order or 0})
	K.round(r, 14)
	K.stroke(r)
	K.text(r, {Text = opts.Icon or "", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(48, 48), Max = 34})
	local right = opts.Button and 170 or 12
	K.text(r, {Text = opts.Title or "", Position = UDim2.fromOffset(64, opts.Sub and 6 or 0), Size = UDim2.new(opts.Progress and 0.45 or 1, opts.Progress and -64 or -64 - right, opts.Sub and 0 or 1, opts.Sub and 28 or 0),
		TextXAlignment = Enum.TextXAlignment.Left, Max = 20})
	if opts.Sub then
		K.text(r, {Text = opts.Sub, Position = UDim2.fromOffset(64, 34), Size = UDim2.new(opts.Progress and 0.45 or 1, opts.Progress and -64 or -64 - right, 0, 22),
			TextColor3 = K.SOFT, TextXAlignment = Enum.TextXAlignment.Left, Max = 16})
	end
	if opts.Progress then
		local cur, max = opts.Progress[1], opts.Progress[2]
		K.bar(r, cur / math.max(1, max), opts.BarColor or K.GREEN, {Position = UDim2.new(0.45, 6, 0.5, -7), Size = UDim2.new(0.55, -right - 80, 0, 14)})
		K.text(r, {Text = ("%d/%d"):format(math.min(cur, max), max), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -right - 6, 0.5, 0), Size = UDim2.fromOffset(70, 24), Max = 18})
	end
	if opts.Button then
		K.button(r, {Text = opts.Button.Text, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(156, 48),
			Kind = opts.Button.Kind or "go", Tip = opts.Button.Tip, TipText = opts.Button.TipText, Max = 20}, opts.Fn)
	end
	return r
end
-- a card: picture area (fill with art(frame)), name, small line, a button
-- opts = {Art(frame) or Icon, Name, Sub, Color (rarity stroke), Button = {Text, Kind}, Fn, CardFn, Order, Tip, TipText}
function K.card(parent, opts)
	local c = Instance.new("TextButton")
	c.Text = ""
	c.AutoButtonColor = false
	c.BackgroundColor3 = K.CARD
	c.LayoutOrder = opts.Order or 0
	K.round(c, 16)
	K.stroke(c, opts.Color or K.LINE, opts.Color and 3 or 2)
	c.Parent = parent
	local pic = K.frame(c, {Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0.5, -6), BackgroundColor3 = (opts.Color or K.LINE):Lerp(K.WHITE, 0.75)})
	K.round(pic, 12)
	if opts.Art then opts.Art(pic) else K.text(pic, {Text = opts.Icon or "", Size = UDim2.fromScale(1, 1), Max = 54}) end
	K.text(c, {Text = opts.Name or "", Position = UDim2.new(0, 6, 0.5, 2), Size = UDim2.new(1, -12, 0.15, 0), Max = 20})
	K.text(c, {Text = opts.Sub or "", Position = UDim2.new(0, 6, 0.65, 0), Size = UDim2.new(1, -12, 0.12, 0), TextColor3 = K.SOFT, Max = 15})
	if opts.Button then
		K.button(c, {Text = opts.Button.Text, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -14, 0.18, 0),
			Kind = opts.Button.Kind or "go", Max = 18}, opts.Fn)
	end
	if opts.CardFn then c.Activated:Connect(function() SoundService:PlayLocalSound(click) opts.CardFn() end) end
	if opts.Tip then K.tip(c, opts.Tip, opts.TipText) end
	return c
end
-- empty state: an invitation with one button
function K.empty(body, icon, text, btnText, fn, order)
	local e = K.frame(body, {Size = UDim2.new(1, -8, 0, 150), BackgroundTransparency = 1, LayoutOrder = order or 0})
	K.text(e, {Text = icon, Size = UDim2.new(1, 0, 0, 60), Max = 50})
	K.text(e, {Text = text, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 30), TextColor3 = K.SOFT, Max = 20})
	if btnText then K.button(e, {Text = btnText, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 98), Size = UDim2.fromOffset(240, 48), Kind = "go"}, fn) end
	return e
end
function K.toast(gui, text, good)
	local t = K.text(gui, {Text = text, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.new(0.6, 0, 0, 46),
		BackgroundTransparency = 0, BackgroundColor3 = good == false and Color3.fromRGB(255, 220, 170) or Color3.fromRGB(215, 245, 200), ZIndex = 90, Max = 22})
	K.round(t, 14)
	K.stroke(t, good == false and Color3.fromRGB(240, 170, 80) or Color3.fromRGB(110, 200, 95), 2)
	task.delay(2.6, function() t:Destroy() end)
	return t
end

return K
