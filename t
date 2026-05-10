-- // Treehouse Merchant Sniper - Advanced UI
-- // Executor: Delta | Game: PS99

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client = game.ReplicatedStorage.Library.Client
local SaveMod = require(Client.Save)
local Network = require(Client.Network)
local RNet = game:GetService("ReplicatedStorage"):WaitForChild("Network")
local lp = Players.LocalPlayer

-- // State
local STATE = {
    running = false,
    cycles = 0,
    totalRAP = 0,
    startTime = 0,
    lastItem = "—",
    lastRAP = 0,
    lastSlot = 0,
    status = "Idle",
    slots = {},
}

local rapTable = {}

-- // RAP Fetch
local function fetchRAP()
    local ok, res = pcall(request, { Url = "https://ps99.biggamesapi.io/api/rap", Method = "GET" })
    if ok and res and res.StatusCode == 200 then
        local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if ok2 and decoded and decoded.data then
            local t = {}
            for _, e in ipairs(decoded.data) do
                local cd = e.configData
                local id = cd and cd.id or e.id
                local key = tostring(id)
                if cd and cd.pt then key = key .. "|pt=" .. tostring(cd.pt) end
                if cd and cd.sh then key = key .. "|sh=true" end
                t[key] = e.value
                if not t[tostring(id)] then t[tostring(id)] = e.value end
            end
            rapTable = t
        end
    end
end

local function getRAP(id, pt, sh)
    local key = tostring(id)
    if pt then key = key .. "|pt=" .. tostring(pt) end
    if sh then key = key .. "|sh=true" end
    return rapTable[key] or rapTable[tostring(id)] or 0
end

task.spawn(fetchRAP)
task.spawn(function()
    while true do task.wait(180) fetchRAP() end
end)

-- // Format numbers
local function fmt(n)
    if n >= 1e9 then return string.format("%.2fB", n/1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    else return tostring(math.floor(n)) end
end

local function fmtTime(s)
    local h = math.floor(s/3600)
    local m = math.floor((s%3600)/60)
    local sec = math.floor(s%60)
    return string.format("%02d:%02d:%02d", h, m, sec)
end

-- // UI BUILD
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TreehouseSniperUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
screenGui.Parent = game:GetService("CoreGui")

-- // Main Frame
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 360, 0, 520)
main.Position = UDim2.new(0.5, -180, 0.5, -260)
main.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = screenGui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

-- Border glow
local border = Instance.new("UIStroke", main)
border.Color = Color3.fromRGB(60, 220, 120)
border.Thickness = 1.5
border.Transparency = 0.4

-- // Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
header.BorderSizePixel = 0
header.Parent = main

Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0.5, 0)
headerFix.Position = UDim2.new(0, 0, 0.5, 0)
headerFix.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
headerFix.BorderSizePixel = 0
headerFix.Parent = header

-- Accent bar left
local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(0, 3, 1, -16)
accentBar.Position = UDim2.new(0, 10, 0, 8)
accentBar.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
accentBar.BorderSizePixel = 0
accentBar.Parent = header
Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

local titleLabel = Instance.new("TextLabel")
titleLabel.Text = "TREEHOUSE SNIPER"
titleLabel.Size = UDim2.new(0, 220, 1, 0)
titleLabel.Position = UDim2.new(0, 22, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(230, 255, 240)
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local subLabel = Instance.new("TextLabel")
subLabel.Text = "Pet Simulator 99"
subLabel.Size = UDim2.new(0, 220, 0, 14)
subLabel.Position = UDim2.new(0, 22, 0, 28)
subLabel.BackgroundTransparency = 1
subLabel.TextColor3 = Color3.fromRGB(60, 220, 120)
subLabel.TextSize = 10
subLabel.Font = Enum.Font.Gotham
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.Parent = header

-- Toggle Button
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 72, 0, 28)
toggleBtn.Position = UDim2.new(1, -82, 0.5, -14)
toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
toggleBtn.BorderSizePixel = 0
toggleBtn.Text = "START"
toggleBtn.TextColor3 = Color3.fromRGB(60, 220, 120)
toggleBtn.TextSize = 11
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Parent = header
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", toggleBtn).Color = Color3.fromRGB(60, 220, 120)

-- // Status Bar
local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1, -20, 0, 32)
statusBar.Position = UDim2.new(0, 10, 0, 56)
statusBar.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
statusBar.BorderSizePixel = 0
statusBar.Parent = main
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 8)

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 12, 0.5, -4)
statusDot.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
statusDot.BorderSizePixel = 0
statusDot.Parent = statusBar
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

local statusText = Instance.new("TextLabel")
statusText.Text = "● Idle — waiting to start"
statusText.Size = UDim2.new(1, -20, 1, 0)
statusText.Position = UDim2.new(0, 28, 0, 0)
statusText.BackgroundTransparency = 1
statusText.TextColor3 = Color3.fromRGB(140, 140, 160)
statusText.TextSize = 11
statusText.Font = Enum.Font.Gotham
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.Parent = statusBar

-- // Stats Row
local function makeStat(parent, pos, label, valDefault)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 100, 0, 56)
    frame.Position = pos
    frame.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Text = label
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.Position = UDim2.new(0, 0, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(80, 80, 100)
    lbl.TextSize = 9
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.Parent = frame

    local val = Instance.new("TextLabel")
    val.Text = valDefault
    val.Size = UDim2.new(1, -8, 0, 24)
    val.Position = UDim2.new(0, 4, 0, 24)
    val.BackgroundTransparency = 1
    val.TextColor3 = Color3.fromRGB(220, 255, 235)
    val.TextSize = 16
    val.Font = Enum.Font.GothamBold
    val.TextXAlignment = Enum.TextXAlignment.Center
    val.Parent = frame

    return val
end

local statsRow = Instance.new("Frame")
statsRow.Size = UDim2.new(1, -20, 0, 56)
statsRow.Position = UDim2.new(0, 10, 0, 97)
statsRow.BackgroundTransparency = 1
statsRow.Parent = main

local cycleVal  = makeStat(statsRow, UDim2.new(0, 0, 0, 0),   "CYCLES", "0")
local rapVal    = makeStat(statsRow, UDim2.new(0, 107, 0, 0), "TOTAL RAP", "0")
local uptimeVal = makeStat(statsRow, UDim2.new(0, 214, 0, 0), "UPTIME", "00:00:00")

-- // Divider
local div = Instance.new("Frame")
div.Size = UDim2.new(1, -20, 0, 1)
div.Position = UDim2.new(0, 10, 0, 163)
div.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
div.BorderSizePixel = 0
div.Parent = main

-- // Item Slots Section
local slotsLabel = Instance.new("TextLabel")
slotsLabel.Text = "MERCHANT SLOTS"
slotsLabel.Size = UDim2.new(1, -20, 0, 20)
slotsLabel.Position = UDim2.new(0, 10, 0, 172)
slotsLabel.BackgroundTransparency = 1
slotsLabel.TextColor3 = Color3.fromRGB(60, 220, 120)
slotsLabel.TextSize = 10
slotsLabel.Font = Enum.Font.GothamBold
slotsLabel.TextXAlignment = Enum.TextXAlignment.Left
slotsLabel.Parent = main

-- 3 slot cards
local slotCards = {}
for i = 1, 3 do
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -20, 0, 64)
    card.Position = UDim2.new(0, 10, 0, 196 + (i-1) * 72)
    card.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    card.BorderSizePixel = 0
    card.Parent = main
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color = Color3.fromRGB(30, 30, 42)
    cardStroke.Thickness = 1

    -- Slot number badge
    local badge = Instance.new("Frame")
    badge.Size = UDim2.new(0, 28, 0, 28)
    badge.Position = UDim2.new(0, 12, 0.5, -14)
    badge.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    badge.BorderSizePixel = 0
    badge.Parent = card
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 6)

    local badgeNum = Instance.new("TextLabel")
    badgeNum.Text = tostring(i)
    badgeNum.Size = UDim2.new(1, 0, 1, 0)
    badgeNum.BackgroundTransparency = 1
    badgeNum.TextColor3 = Color3.fromRGB(80, 80, 110)
    badgeNum.TextSize = 13
    badgeNum.Font = Enum.Font.GothamBold
    badgeNum.Parent = badge

    local itemName = Instance.new("TextLabel")
    itemName.Name = "ItemName"
    itemName.Text = "Waiting..."
    itemName.Size = UDim2.new(1, -120, 0, 20)
    itemName.Position = UDim2.new(0, 50, 0, 12)
    itemName.BackgroundTransparency = 1
    itemName.TextColor3 = Color3.fromRGB(200, 200, 220)
    itemName.TextSize = 12
    itemName.Font = Enum.Font.GothamBold
    itemName.TextXAlignment = Enum.TextXAlignment.Left
    itemName.TextTruncate = Enum.TextTruncate.AtEnd
    itemName.Parent = card

    local itemSub = Instance.new("TextLabel")
    itemSub.Name = "ItemSub"
    itemSub.Text = "—"
    itemSub.Size = UDim2.new(1, -120, 0, 16)
    itemSub.Position = UDim2.new(0, 50, 0, 34)
    itemSub.BackgroundTransparency = 1
    itemSub.TextColor3 = Color3.fromRGB(70, 70, 90)
    itemSub.TextSize = 10
    itemSub.Font = Enum.Font.Gotham
    itemSub.TextXAlignment = Enum.TextXAlignment.Left
    itemSub.Parent = card

    local rapBadge = Instance.new("Frame")
    rapBadge.Size = UDim2.new(0, 90, 0, 28)
    rapBadge.Position = UDim2.new(1, -100, 0.5, -14)
    rapBadge.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    rapBadge.BorderSizePixel = 0
    rapBadge.Parent = card
    Instance.new("UICorner", rapBadge).CornerRadius = UDim.new(0, 6)

    local rapText = Instance.new("TextLabel")
    rapText.Name = "RapText"
    rapText.Text = "—"
    rapText.Size = UDim2.new(1, 0, 1, 0)
    rapText.BackgroundTransparency = 1
    rapText.TextColor3 = Color3.fromRGB(60, 220, 120)
    rapText.TextSize = 12
    rapText.Font = Enum.Font.GothamBold
    rapText.Parent = rapBadge

    slotCards[i] = { card = card, stroke = cardStroke, name = itemName, sub = itemSub, rap = rapText, badge = badge, badgeNum = badgeNum }
end

-- // Log Feed
local div2 = Instance.new("Frame")
div2.Size = UDim2.new(1, -20, 0, 1)
div2.Position = UDim2.new(0, 10, 0, 420)
div2.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
div2.BorderSizePixel = 0
div2.Parent = main

local logLabel = Instance.new("TextLabel")
logLabel.Text = "ACTIVITY LOG"
logLabel.Size = UDim2.new(1, -20, 0, 20)
logLabel.Position = UDim2.new(0, 10, 0, 428)
logLabel.BackgroundTransparency = 1
logLabel.TextColor3 = Color3.fromRGB(60, 220, 120)
logLabel.TextSize = 10
logLabel.Font = Enum.Font.GothamBold
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.Parent = main

local logText = Instance.new("TextLabel")
logText.Name = "Log"
logText.Text = "No activity yet."
logText.Size = UDim2.new(1, -20, 0, 52)
logText.Position = UDim2.new(0, 10, 0, 450)
logText.BackgroundTransparency = 1
logText.TextColor3 = Color3.fromRGB(80, 80, 100)
logText.TextSize = 10
logText.Font = Enum.Font.Gotham
logText.TextXAlignment = Enum.TextXAlignment.Left
logText.TextYAlignment = Enum.TextYAlignment.Top
logText.TextWrapped = true
logText.Parent = main

local logLines = {}
local function pushLog(msg)
    table.insert(logLines, 1, msg)
    if #logLines > 4 then table.remove(logLines) end
    logText.Text = table.concat(logLines, "\n")
end

-- // Draggable
local dragging, dragStart, startPos = false, nil, nil
header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = i.Position
        startPos = main.Position
    end
end)
header.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = i.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- // UI Update helpers
local function setStatus(msg, color)
    statusText.Text = msg
    statusText.TextColor3 = color or Color3.fromRGB(140, 140, 160)
    statusDot.BackgroundColor3 = color or Color3.fromRGB(80, 80, 100)
end

local function highlightSlot(winIdx)
    for i, c in ipairs(slotCards) do
        local isWinner = i == winIdx
        TweenService:Create(c.stroke, TweenInfo.new(0.2), {
            Color = isWinner and Color3.fromRGB(60, 220, 120) or Color3.fromRGB(30, 30, 42),
            Thickness = isWinner and 1.5 or 1,
        }):Play()
        TweenService:Create(c.card, TweenInfo.new(0.2), {
            BackgroundColor3 = isWinner and Color3.fromRGB(16, 24, 18) or Color3.fromRGB(14, 14, 20),
        }):Play()
        c.badgeNum.TextColor3 = isWinner and Color3.fromRGB(60, 220, 120) or Color3.fromRGB(80, 80, 110)
    end
end

local function resetSlots()
    for i, c in ipairs(slotCards) do
        c.name.Text = "Scanning..."
        c.sub.Text = "—"
        c.rap.Text = "—"
        c.rap.TextColor3 = Color3.fromRGB(60, 220, 120)
        TweenService:Create(c.stroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(30, 30, 42) }):Play()
        TweenService:Create(c.card, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(14, 14, 20) }):Play()
        c.badgeNum.TextColor3 = Color3.fromRGB(80, 80, 110)
    end
end

local function updateSlotCard(i, id, pt, sh, amount, rap)
    local c = slotCards[i]
    if not c then return end
    local shinyTag = sh and " ✦" or ""
    local ptTag = pt and (" P"..tostring(pt)) or ""
    c.name.Text = tostring(id) .. shinyTag
    c.sub.Text = string.format("x%d%s | RAP ea: %s", amount, ptTag, fmt(rap))
    c.rap.Text = fmt(rap * amount)
    c.rap.TextColor3 = rap > 0 and Color3.fromRGB(60, 220, 120) or Color3.fromRGB(100, 60, 60)
end

-- // Core logic
local function getBestSlot(room)
    local best, bestIdx = -math.huge, nil
    resetSlots()
    task.wait(0.05)

    for i = 1, 3 do
        local v = room[i]
        if v then
            local d = v.data
            local rap = getRAP(d.id, d.pt, d.sh)
            local amount = d.amount or 1
            local total = rap * amount
            updateSlotCard(i, d.id, d.pt, d.sh, amount, rap)
            if total > best then best, bestIdx = total, i end
        end
    end
    return bestIdx, best
end

local loopThread = nil

local function startLoop()
    STATE.running = true
    STATE.startTime = tick()
    toggleBtn.Text = "STOP"
    toggleBtn.TextColor3 = Color3.fromRGB(220, 80, 80)
    border.Color = Color3.fromRGB(60, 220, 120)

    loopThread = task.spawn(function()
        while STATE.running do
            setStatus("🔓 Unlocking room...", Color3.fromRGB(60, 180, 220))

            local t = tick() + 5
            while tick() < t do
                local s = SaveMod.Get()
                if s["SecretRooms"] and s["SecretRooms"]["Treehouse Merchant"] then break end
                task.spawn(function() Network.Invoke("SecretRoom_Unlock", "Treehouse Merchant") end)
                task.spawn(function() pcall(function() RNet.SecretRoom_Unlock:InvokeServer("Treehouse Merchant") end) end)
                task.wait(0.1)
            end

            setStatus("🚪 Entering instance...", Color3.fromRGB(220, 180, 60))
            task.spawn(function() Network.Invoke("Instancing_PlayerEnterInstance", "TreehouseMerchant") end)
            task.spawn(function() pcall(function() RNet.Instancing_PlayerEnterInstance:InvokeServer("TreehouseMerchant") end) end)
            task.spawn(function() pcall(function() RNet["Instances: Mark Entered"]:FireServer("TreehouseMerchant") end) end)
            task.spawn(function() pcall(function() RNet["Machines: Mark Approached"]:FireServer("TreehouseMerchant") end) end)
            task.wait(0.3)

            local save = SaveMod.Get()
            local room = save["SecretRooms"] and save["SecretRooms"]["Treehouse Merchant"]

            if type(room) == "table" then
                setStatus("📦 Reading slots...", Color3.fromRGB(180, 120, 255))
                local idx, totalRAP = getBestSlot(room)

                if idx and totalRAP > 0 then
                    highlightSlot(idx)
                    local chosen = room[idx]
                    local chosenName = chosen and chosen.data and chosen.data.id or "Unknown"
                    setStatus("✅ Buying slot " .. idx .. " — " .. chosenName, Color3.fromRGB(60, 220, 120))
                    pushLog(string.format("[%s] Slot %d → %s (%s RAP)", os.date("%H:%M:%S"), idx, chosenName, fmt(totalRAP)))

                    Network.Invoke("TreehouseMerchant_Purchase", idx)
                    task.wait(0.1)
                    Network.Invoke("TreehouseMerchant_Purchase", idx)

                    STATE.cycles += 1
                    STATE.totalRAP += totalRAP
                    STATE.lastItem = chosenName
                    STATE.lastRAP = totalRAP
                    STATE.lastSlot = idx

                    cycleVal.Text = tostring(STATE.cycles)
                    rapVal.Text = fmt(STATE.totalRAP)
                else
                    setStatus("⚠ No RAP data, skipping", Color3.fromRGB(220, 140, 40))
                    pushLog(string.format("[%s] Skipped — no RAP match", os.date("%H:%M:%S")))
                end
            else
                setStatus("❌ Room data missing", Color3.fromRGB(220, 60, 60))
                pushLog(string.format("[%s] Room data invalid", os.date("%H:%M:%S")))
            end

            task.wait(1.5)
        end
    end)
end

local function stopLoop()
    STATE.running = false
    if loopThread then task.cancel(loopThread) loopThread = nil end
    toggleBtn.Text = "START"
    toggleBtn.TextColor3 = Color3.fromRGB(60, 220, 120)
    setStatus("⏹ Stopped", Color3.fromRGB(100, 100, 120))
    border.Color = Color3.fromRGB(40, 40, 60)
    resetSlots()
end

-- Toggle button
toggleBtn.MouseButton1Click:Connect(function()
    if STATE.running then stopLoop() else startLoop() end
end)

-- RightShift hotkey
UserInputService.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.RightShift then
        if STATE.running then stopLoop() else startLoop() end
    end
end)

-- Uptime ticker
RunService.Heartbeat:Connect(function()
    if STATE.running and STATE.startTime > 0 then
        uptimeVal.Text = fmtTime(tick() - STATE.startTime)
    end
end)

-- Toggle UI visibility with RightControl
UserInputService.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.RightControl then
        main.Visible = not main.Visible
    end
end)

print("[TreehouseSniper] Loaded | RightShift = toggle | RightCtrl = hide UI")
