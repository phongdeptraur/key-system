-- LocalScript
-- Seat / Dojo / Dragon Talon + Tabs (MAIN / FRUIT)
-- Updates per request:
-- 1) FRUIT tab: giữ nguyên Drop/Recieve + chỉ giữ TP Dojo & TP Dragon Talon (xóa TP Fruit Drop/Recieve)
-- 2) MAIN tab: đổi text:
--    "TP to Dojo" -> "Get quest Dojo"
--    "TP to Buy Dragon Talon" -> "Buy Dragon Talon"
-- (logic/nhấn vẫn giữ như cũ)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local plr = Players.LocalPlayer

-- ===== CONFIG =====
local TWEEN_SPEED = 350 -- studs/second

local TP_SEAT_GATE = Vector3.new(-12464.33, 374.95, -7553.44)
local TP_DOJO_GATE = Vector3.new(5659.49, 1014.12, -343.54)

-- FRUIT POS
local POS_FRUIT_DROP    = Vector3.new(5849.85, 1208.32, 876.21)
local POS_FRUIT_RECEIVE = Vector3.new(5845.76, 1208.32, 879.39)

local DESTINATIONS = {
	-- Seats
	{ label = "Seat 1", pos = Vector3.new(-12602.31, 337.59, -7544.76), type = "SEAT" },
	{ label = "Seat 2", pos = Vector3.new(-12591.06, 337.59, -7544.76), type = "SEAT" },
	{ label = "Seat 3", pos = Vector3.new(-12591.06, 337.59, -7556.76), type = "SEAT" },
	{ label = "Seat 4", pos = Vector3.new(-12602.31, 337.59, -7556.76), type = "SEAT" },
	{ label = "Seat 5", pos = Vector3.new(-12602.31, 337.59, -7568.76), type = "SEAT" },
	{ label = "Seat 6", pos = Vector3.new(-12591.06, 337.59, -7568.76), type = "SEAT" },

	-- Special (MAIN rename)
	{ label = "Get quest Dojo", pos = Vector3.new(5866.27, 1208.32, 870.26), type = "DOJO" },
	{ label = "Buy Dragon Talon", pos = Vector3.new(5659.94, 1211.32, 865.08), type = "DRAGON" },
}

-- ===== UNLOAD state =====
local alive = true
local conns = {}
local gui
local currentTween

local function addConn(c)
	table.insert(conns, c)
	return c
end
local function disconnectAll()
	for _, c in ipairs(conns) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(conns)
end

-- ===== Character refs =====
local character, humanoid, hrp
local function bindChar(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:WaitForChild("HumanoidRootPart")
end
bindChar(plr.Character or plr.CharacterAdded:Wait())
addConn(plr.CharacterAdded:Connect(bindChar))

-- ===== UI (tabs + pages) =====
local UI_NAME = "SeatTweenUI_V2"
local old = plr.PlayerGui:FindFirstChild(UI_NAME)
if old then old:Destroy() end

gui = Instance.new("ScreenGui")
gui.Name = UI_NAME
gui.ResetOnSpawn = false
gui.Parent = plr.PlayerGui

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 340, 0, 460)
main.Position = UDim2.new(0, 14, 0, 14)
main.BackgroundTransparency = 0.12
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", main)
stroke.Thickness = 1
stroke.Transparency = 0.6

local pad = Instance.new("UIPadding", main)
pad.PaddingTop = UDim.new(0, 12)
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)
pad.PaddingBottom = UDim.new(0, 12)

local topbar = Instance.new("Frame", main)
topbar.BackgroundTransparency = 1
topbar.Size = UDim2.new(1, 0, 0, 44)

local title = Instance.new("TextLabel", topbar)
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -120, 1, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Gay Draco Hub 🐉"

local btnUnload = Instance.new("TextButton", topbar)
btnUnload.Size = UDim2.new(0, 110, 0, 30)
btnUnload.Position = UDim2.new(1, 0, 0.5, 0)
btnUnload.AnchorPoint = Vector2.new(1, 0.5)
btnUnload.BackgroundTransparency = 0.05
btnUnload.Font = Enum.Font.GothamBold
btnUnload.TextSize = 13
btnUnload.Text = "UNLOAD"
Instance.new("UICorner", btnUnload).CornerRadius = UDim.new(0, 10)

local tabbar = Instance.new("Frame", main)
tabbar.BackgroundTransparency = 1
tabbar.Size = UDim2.new(1, 0, 0, 36)
tabbar.Position = UDim2.new(0, 0, 0, 46)

local function mkTabBtn(text, x)
	local b = Instance.new("TextButton", tabbar)
	b.Size = UDim2.new(0, 100, 0, 30)
	b.Position = UDim2.new(0, x, 0, 3)
	b.BackgroundTransparency = 0.08
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 12
	b.Text = text
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	local s = Instance.new("UIStroke", b)
	s.Thickness = 1
	s.Transparency = 0.75
	return b
end

local tabMainBtn = mkTabBtn("MAIN", 0)
local tabFruitBtn = mkTabBtn("FRUIT", 110)

local statusBar = Instance.new("Frame", main)
statusBar.Size = UDim2.new(1, 0, 0, 44)
statusBar.Position = UDim2.new(0, 0, 0, 84)
statusBar.BackgroundTransparency = 0.25
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 10)

local status = Instance.new("TextLabel", statusBar)
status.BackgroundTransparency = 1
status.Size = UDim2.new(1, -12, 1, 0)
status.Position = UDim2.new(0, 6, 0, 0)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "Ready."

local pages = Instance.new("Frame", main)
pages.BackgroundTransparency = 1
pages.Size = UDim2.new(1, 0, 1, -140)
pages.Position = UDim2.new(0, 0, 0, 132)

local function log(msg)
	print("[SeatTween]", msg)
	if status then status.Text = msg end
end

-- ===== Movement helpers =====
local function stopTween()
	if currentTween then
		pcall(function() currentTween:Cancel() end)
		currentTween = nil
	end
end

local function hardTeleport(pos)
	if not hrp then return end
	stopTween()
	hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	task.wait(0.15)
end

local function tweenTo(pos, labelText)
	if not (humanoid and hrp) then return end
	stopTween()

	pos = pos + Vector3.new(0, 2.5, 0)

	local oldWalkSpeed = humanoid.WalkSpeed
	local oldJumpPower = humanoid.JumpPower

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	local dist = (pos - hrp.Position).Magnitude
	local t = math.max(dist / TWEEN_SPEED, 0.05)

	log(("Tween → %s | t=%.2fs"):format(labelText, t))

	currentTween = TweenService:Create(
		hrp,
		TweenInfo.new(t, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(pos) }
	)

	currentTween:Play()
	currentTween.Completed:Wait()

	humanoid.WalkSpeed = oldWalkSpeed or 16
	humanoid.JumpPower = oldJumpPower or 50
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

	log("Arrived: " .. labelText)
end

local function tpGateThenTween(gatePos, destPos, labelText)
	if not (alive and hrp) then return end

	hardTeleport(gatePos)
	task.wait(0.5)

	local gateOff = (hrp.Position - gatePos).Magnitude
	if gateOff > 10 then
		log(("Lag-back detected (%.1f) -> wait 1.5s -> TP gate again"):format(gateOff))
		task.wait(1.5)
		hardTeleport(gatePos)
		task.wait(0.5)
	end

	tweenTo(destPos, labelText)
end

local function moveDojoStyle(destPos, labelText, gatePos)
	if not (alive and hrp) then return end
	gatePos = gatePos or TP_DOJO_GATE

	local dist = (destPos - hrp.Position).Magnitude
	local t = dist / TWEEN_SPEED

	if t < 5 then
		log(("%s gần (t=%.2f) -> TP THẲNG"):format(labelText, t))
		hardTeleport(destPos)
		log("Arrived: " .. labelText)
	else
		log(("%s xa (t=%.2f) -> TP gate + tween"):format(labelText, t))
		tpGateThenTween(gatePos, destPos, labelText)
	end
end

-- ===== Click / UI automation (giữ nguyên) =====
local function clickScreen()
	local vp = workspace.CurrentCamera.ViewportSize
	local x, y = vp.X/2, vp.Y/2
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
	task.wait()
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function findClickableForText(targetLower)
	for _, obj in ipairs(plr.PlayerGui:GetDescendants()) do
		if obj:IsA("TextButton") and obj.Visible then
			if string.lower(obj.Text or "") == targetLower then
				return obj
			end
		end
	end
	for _, obj in ipairs(plr.PlayerGui:GetDescendants()) do
		if obj:IsA("TextLabel") and obj.Visible then
			if string.lower(obj.Text or "") == targetLower then
				local p = obj.Parent
				while p and not (p:IsA("TextButton") or p:IsA("ImageButton")) do
					p = p.Parent
				end
				if p and p.Visible then
					return p
				end
			end
		end
	end
	return nil
end

local function fireButton(btn)
	if not (btn and btn.Visible) then return false end
	pcall(function() btn:Activate() end)
	pcall(function()
		if getconnections then
			for _, c in ipairs(getconnections(btn.Activated)) do pcall(function() c:Fire() end) end
			if btn:IsA("TextButton") then
				for _, c in ipairs(getconnections(btn.MouseButton1Click)) do pcall(function() c:Fire() end) end
			end
		end
	end)
	return true
end

local function spamUntilGone(text, maxWaitAppear, maxSpamTime)
	local targetLower = string.lower(text)
	maxWaitAppear = maxWaitAppear or 3.0
	maxSpamTime = maxSpamTime or 6.0

	log(("Waiting '%s'..."):format(text))

	local t0 = os.clock()
	local btn
	while alive and (os.clock() - t0) < maxWaitAppear do
		btn = findClickableForText(targetLower)
		if btn then break end
		task.wait(0.05)
	end

	if not btn then
		log(("No '%s' found."):format(text))
		return false
	end

	log(("Spamming '%s'..."):format(text))

	local spamStart = os.clock()
	local clicked = 0
	local lastSeen = os.clock()

	while alive and (os.clock() - spamStart) < maxSpamTime do
		btn = findClickableForText(targetLower)
		if btn then
			lastSeen = os.clock()
			fireButton(btn)
			clicked += 1
		else
			if (os.clock() - lastSeen) > 0.2 then break end
		end
		task.wait(0.03)
	end

	log(("Done '%s' (clicked ~%d)"):format(text, clicked))
	return true
end

-- ===== MAIN actions =====
local function goTo(dest)
	if not (alive and hrp) then return end

	local dist = (dest.pos - hrp.Position).Magnitude
	local t = dist / TWEEN_SPEED

	if dest.type == "SEAT" then
		if t > 1 then
			log(("Seat xa (t=%.2f) -> TP THẲNG seat"):format(t))
			hardTeleport(dest.pos)
			log("Arrived: " .. dest.label)
		else
			tweenTo(dest.pos, dest.label)
		end

	elseif dest.type == "DOJO" or dest.type == "DRAGON" then
		moveDojoStyle(dest.pos, dest.label, TP_DOJO_GATE)
	end

	if dest.type == "DOJO" then
		task.wait(0.25)
		log("DOJO: Interact #1")
		clickScreen()

		task.wait(0.25)
		spamUntilGone("Black Belt", 4.0, 10.0)

		task.wait(0.25)
		log("DOJO: Interact #2")
		clickScreen()

	elseif dest.type == "DRAGON" then
		task.wait(0.25)
		log("DRAGON: Interact #1")
		clickScreen()

		task.wait(0.25)
		spamUntilGone("Style", 4.0, 10.0)

		task.wait(0.15)
		spamUntilGone("Learn", 4.0, 10.0)

		task.wait(0.25)
		log("DRAGON: Interact #2")
		clickScreen()
	end
end

-- ===== FRUIT actions =====
local function faceOnce(targetPos)
	if not hrp then return end
	hrp.CFrame = CFrame.new(hrp.Position, targetPos)
end

local function findFruitTool()
	local backpack = plr:FindFirstChildOfClass("Backpack")
	if not backpack then return nil end
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and tool:FindFirstChild("Handle") then
			return tool
		end
	end
	return nil
end

local function dropFruit()
	local tool = findFruitTool()
	if tool then tool.Parent = workspace end
end

local function doFruitDrop()
	if not alive then return end
	moveDojoStyle(POS_FRUIT_DROP, "FRUIT DROP", TP_DOJO_GATE)
	task.wait(0.5)
	faceOnce(POS_FRUIT_RECEIVE)
	task.wait(0.5)
	dropFruit()
	log("FRUIT: Dropped (if tool exists).")
end

local function doFruitReceive()
	if not alive then return end
	moveDojoStyle(POS_FRUIT_RECEIVE, "FRUIT RECEIVE", TP_DOJO_GATE)
	task.wait(0.5)
	faceOnce(POS_FRUIT_DROP)
	log("FRUIT: Ready.")
end

-- FRUIT tab extra: chỉ giữ TP Dojo & TP Dragon Talon
local function tpToDojo()
	if not alive then return end
	moveDojoStyle(DESTINATIONS[#DESTINATIONS-1].pos, "DOJO", TP_DOJO_GATE)
end

local function tpToDragon()
	if not alive then return end
	moveDojoStyle(DESTINATIONS[#DESTINATIONS].pos, "DRAGON TALON", TP_DOJO_GATE)
end

-- ===== Pages builder =====
local function newScrollPage(parent)
	local listFrame = Instance.new("Frame", parent)
	listFrame.BackgroundTransparency = 1
	listFrame.Size = UDim2.new(1, 0, 1, 0)

	local scroll = Instance.new("ScrollingFrame", listFrame)
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ScrollBarThickness = 6
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local layout = Instance.new("UIListLayout", scroll)
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local function makeHeader(text, order)
		local h = Instance.new("TextLabel", scroll)
		h.LayoutOrder = order
		h.BackgroundTransparency = 1
		h.Size = UDim2.new(1, 0, 0, 18)
		h.Font = Enum.Font.GothamBold
		h.TextSize = 12
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.TextTransparency = 0.15
		h.Text = text
		return h
	end

	local function makeBtn(text, order)
		local b = Instance.new("TextButton", scroll)
		b.LayoutOrder = order
		b.Size = UDim2.new(1, 0, 0, 34)
		b.BackgroundTransparency = 0.06
		b.Font = Enum.Font.GothamSemibold
		b.TextSize = 13
		b.Text = text
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
		local s = Instance.new("UIStroke", b)
		s.Thickness = 1
		s.Transparency = 0.75
		return b
	end

	return listFrame, makeHeader, makeBtn
end

local pageMain, makeHeaderMain, makeBtnMain = newScrollPage(pages)
local pageFruit, makeHeaderFruit, makeBtnFruit = newScrollPage(pages)

pageMain.Visible = true
pageFruit.Visible = false

local function setTab(which)
	if which == "MAIN" then
		pageMain.Visible = true
		pageFruit.Visible = false
		log("Tab: MAIN")
	else
		pageMain.Visible = false
		pageFruit.Visible = true
		log("Tab: FRUIT")
	end
end

addConn(tabMainBtn.MouseButton1Click:Connect(function() setTab("MAIN") end))
addConn(tabFruitBtn.MouseButton1Click:Connect(function() setTab("FRUIT") end))

-- ===== Build MAIN content =====
makeHeaderMain("SEATS", 1)
local order = 2
for _, d in ipairs(DESTINATIONS) do
	if d.type == "SEAT" then
		local b = makeBtnMain(d.label, order)
		order += 1
		addConn(b.MouseButton1Click:Connect(function() task.spawn(function() goTo(d) end) end))
	end
end

makeHeaderMain("SPECIAL", order); order += 1
for _, d in ipairs(DESTINATIONS) do
	if d.type ~= "SEAT" then
		local b = makeBtnMain(d.label, order)
		order += 1
		addConn(b.MouseButton1Click:Connect(function() task.spawn(function() goTo(d) end) end))
	end
end

-- ===== Build FRUIT content =====
makeHeaderFruit("FRUIT", 1)
local bDrop = makeBtnFruit("Drop Fruit", 2)
local bRecv = makeBtnFruit("Recieve Fruit", 3)

makeHeaderFruit("TP", 4)
local bTPDojo   = makeBtnFruit("TP Dojo", 5)
local bTPDragon = makeBtnFruit("TP Dragon Talon", 6)

addConn(bDrop.MouseButton1Click:Connect(function() task.spawn(doFruitDrop) end))
addConn(bRecv.MouseButton1Click:Connect(function() task.spawn(doFruitReceive) end))
addConn(bTPDojo.MouseButton1Click:Connect(function() task.spawn(tpToDojo) end))
addConn(bTPDragon.MouseButton1Click:Connect(function() task.spawn(tpToDragon) end))

-- ===== UNLOAD =====
local function Unload()
	alive = false
	stopTween()
	disconnectAll()
	if gui then pcall(function() gui:Destroy() end) end
	print("[SeatTween] UNLOADED")
end
getgenv().SeatTween_Unload = Unload

addConn(btnUnload.MouseButton1Click:Connect(Unload))

log("Ready. Chọn tab MAIN / FRUIT.")
