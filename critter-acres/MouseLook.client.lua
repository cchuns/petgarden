-- Critter Acres: Mouse look (StarterPlayerScripts LocalScript)
-- On a computer the camera follows the mouse (no right-click needed), like shift lock: the mouse sits in the
-- middle as a little aim dot and your character faces where the camera looks.
--   * Ctrl (or the chip above the dock) turns it on/off.
--   * The mouse is set free by itself while a window is open, while typing, or in the Roblox menu,
--     so kids can always click buttons.
--   * Phones/tablets/gamepads are left alone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local K = require(ReplicatedStorage:WaitForChild("UIKit"))
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

if not (UserInputService.MouseEnabled and UserInputService.KeyboardEnabled) then return end

local gui = Instance.new("ScreenGui")
gui.Name = "MouseLook"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 4
gui.Parent = player:WaitForChild("PlayerGui")

-- the aim dot in the middle of the screen
local dot = K.frame(gui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 12),
	BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Active = false})
K.round(dot, 6)
K.stroke(dot, Color3.fromRGB(70, 50, 60), 2)

local on = true
local chip
local function drawChip()
	chip.Text = on and "🖱️ Mouse look: ON  (Ctrl)" or "🖱️ Mouse look: OFF  (Ctrl)"
	chip.BackgroundColor3 = on and Color3.fromRGB(190, 235, 160) or K.CARD
end
local function toggle()
	on = not on
	drawChip()
end
chip = K.button(gui, {Text = "", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -198, 1, -21), Size = UDim2.fromOffset(210, 42), Max = 20,
	Tip = "🖱️ Mouse look (Ctrl)", TipText = "ON: the camera turns when you move the mouse. Press Ctrl to show the mouse and click things."}, toggle)
drawChip()

UserInputService.InputBegan:Connect(function(input, gp)
	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then toggle() end
end)

-- is a big window (or full-screen overlay) open? Windows sit right under a ScreenGui, so only look 2 levels down.
local busy = false
local function bigVisible(o, vp)
	if not o:IsA("GuiObject") or not o.Visible then return false end
	local s = o.AbsoluteSize
	if s.X > vp.X * 0.4 and s.Y > vp.Y * 0.35 and (o.BackgroundTransparency < 0.6 or o:IsA("ScrollingFrame")) then return true end
	return false
end
local function scanBusy()
	local vp = camera.ViewportSize
	for _, sg in player.PlayerGui:GetChildren() do
		if sg:IsA("ScreenGui") and sg.Enabled and sg ~= gui then
			for _, a in sg:GetChildren() do
				if bigVisible(a, vp) then return true end
				if a:IsA("GuiObject") and a.Visible then
					for _, b in a:GetChildren() do
						if bigVisible(b, vp) then return true end
					end
				end
			end
		end
	end
	return false
end
task.spawn(function()
	while true do
		busy = scanBusy()
		task.wait(0.2)
	end
end)

local locked = false
local function release()
	if not locked then return end
	locked = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	dot.Visible = false
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
		hum.CameraOffset = Vector3.zero
	end
end

RunService:BindToRenderStep("CritterMouseLook", Enum.RenderPriority.Camera.Value + 1, function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local want = on and hum and root and hum.Health > 0 and not busy and not GuiService.MenuIsOpen
		and not UserInputService:GetFocusedTextBox() and UserInputService.MouseEnabled
	if not want then
		release()
		return
	end
	locked = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	dot.Visible = true
	-- face where the camera looks (not while sitting or riding a pet)
	if hum.Sit or hum.SeatPart or hum.PlatformStand then
		hum.AutoRotate = true
		hum.CameraOffset = Vector3.zero
		return
	end
	hum.AutoRotate = false
	hum.CameraOffset = Vector3.new(1.5, 0, 0)
	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook)
	end
end)

player.CharacterAdded:Connect(function() locked = true release() end)
