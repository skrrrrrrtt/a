-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local PlayerSave = require(ReplicatedStorage.Library.Client.Save)

-- // Cleanup
if CoreGui:FindFirstChild("BoostHub") then CoreGui:FindFirstChild("BoostHub"):Destroy() end

-- // Config
local Event = ReplicatedStorage.Network.Easter2026ChanceMachine_AddTime
local AMOUNT = 1000
local DELAY = 0.5
local CYCLE_HOURS = 6

local TOKEN_IDS = {
    "Spring Bluebell Token",
    "Spring Pink Rose Token",
    "Spring Yellow Sunflower Token",
    "Spring Red Tulip Token",
}
local TOKEN_SHORT = {
    ["Spring Bluebell Token"]         = "Bluebell",
    ["Spring Pink Rose Token"]        = "Rose",
    ["Spring Yellow Sunflower Token"] = "Sunflower",
    ["Spring Red Tulip Token"]        = "Tulip",
}

local TIERS = {
    { name = "Huge",       times = 2,  enabled = true },
    { name = "Titanic",    times = 5,  enabled = true },
    { name = "Gargantuan", times = 1,  enabled = true },
}

-- // State
local paused = false
local running = false
local nextCycleAt = 0
local logs = {}
local tierProgress = {}  -- { current, total }
local currentTier = ""

-- // Util
local function fmt(n)
    if n >= 1e6 then return ("%.1fM"):format(n/1e6):gsub("%.",",")
    elseif n >= 1e3 then return ("%.1fK"):format(n/1e3):gsub("%.",",")
    end
    return tostring(math.floor(n))
end

local function fmtTime(s)
    s = math.max(0, math.floor(s))
    return ("%02d:%02d:%02d"):format(math.floor(s/3600), math.floor(s%3600/60), s%60)
end

local function addLog(msg, color)
    table.insert(logs, { msg = ("[%s] %s"):format(os.date("%H:%M:%S"), msg), color = color or Color3.new(1,1,1) })
    if #logs > 50 then table.remove(logs, 1) end
end

-- // Inventory reader
local function getTokenCounts()
    local counts = {}
    local Save = PlayerSave.Get()
    if Save and Save.Inventory then
        for _, tokenID in ipairs(TOKEN_IDS) do
            local total = 0
            for _, items in pairs(Save.Inventory) do
                for _, data in pairs(items) do
                    if data.id == tokenID then total += (data._am or 1) end
                end
            end
            counts[tokenID] = total
        end
    end
    return counts
end

local function pickToken(counts)
    for _, tokenID in ipairs(TOKEN_IDS) do
        if (counts[tokenID] or 0) >= AMOUNT then return tokenID end
    end
    return nil
end

-- // GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BoostHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

-- Drag support
local function makeDraggable(frame, handle)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = i.Position
            startPos = frame.Position
        end
    end)
    handle.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

local function mkCorner(r, p) local c = Instance.new("UICorner", p); c.CornerRadius = UDim.new(0, r); return c end
local function mkStroke(c, t, p) local s = Instance.new("UIStroke", p); s.Color = c; s.Transparency = t or 0; return s end
local function mkLabel(props, parent)
    local l = Instance.new("TextLabel", parent)
    for k,v in pairs(props) do l[k] = v end
    l.BackgroundTransparency = 1
    return l
end
local function mkBtn(props, parent)
    local b = Instance.new("TextButton", parent)
    for k,v in pairs(props) do b[k] = v end
    return b
end

-- Main Window
local Win = Instance.new("Frame", ScreenGui)
Win.Size = UDim2.fromOffset(400, 520)
Win.Position = UDim2.fromOffset(60, 60)
Win.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
Win.BorderSizePixel = 0
mkCorner(12, Win)
mkStroke(Color3.fromRGB(255, 170, 0), 0.3, Win)

-- Title bar
local TitleBar = Instance.new("Frame", Win)
TitleBar.Size = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
TitleBar.BorderSizePixel = 0
mkCorner(12, TitleBar)
makeDraggable(Win, TitleBar)

mkLabel({
    Text = "⚡ BoostHub",
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = Color3.fromRGB(255, 170, 0),
    Size = UDim2.new(1, -90, 1, 0),
    Position = UDim2.fromOffset(14, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
}, TitleBar)

-- Minimize
local MinBtn = mkBtn({
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -68, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Color3.fromRGB(30, 30, 40),
    Text = "—",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BorderSizePixel = 0,
}, TitleBar)
mkCorner(6, MinBtn)

local CloseBtn = mkBtn({
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -36, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Color3.fromRGB(180, 40, 40),
    Text = "✕",
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BorderSizePixel = 0,
}, TitleBar)
mkCorner(6, CloseBtn)

CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Content (hidden on minimize)
local Content = Instance.new("Frame", Win)
Content.Size = UDim2.new(1, -20, 1, -54)
Content.Position = UDim2.fromOffset(10, 50)
Content.BackgroundTransparency = 1

MinBtn.MouseButton1Click:Connect(function()
    Content.Visible = not Content.Visible
    Win.Size = Content.Visible and UDim2.fromOffset(400, 520) or UDim2.fromOffset(400, 44)
end)

-- Status strip
local StatusRow = Instance.new("Frame", Content)
StatusRow.Size = UDim2.new(1, 0, 0, 34)
StatusRow.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
StatusRow.BorderSizePixel = 0
mkCorner(8, StatusRow)

local StatusDot = mkLabel({
    Text = "●",
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(80, 80, 80),
    Size = UDim2.fromOffset(20, 34),
    Position = UDim2.fromOffset(10, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
}, StatusRow)

local StatusLbl = mkLabel({
    Text = "Idle",
    TextSize = 13,
    Font = Enum.Font.Gotham,
    TextColor3 = Color3.fromRGB(180, 180, 180),
    Size = UDim2.new(1, -90, 1, 0),
    Position = UDim2.fromOffset(28, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
}, StatusRow)

local CycleTimerLbl = mkLabel({
    Text = "--:--:--",
    TextSize = 13,
    Font = Enum.Font.Code,
    TextColor3 = Color3.fromRGB(255, 170, 0),
    Size = UDim2.fromOffset(70, 34),
    Position = UDim2.new(1, -74, 0, 0),
    TextXAlignment = Enum.TextXAlignment.Right,
}, StatusRow)

-- Token counts section
local TokenTitle = mkLabel({
    Text = "TOKENS",
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(255, 170, 0),
    Size = UDim2.new(1, 0, 0, 18),
    Position = UDim2.fromOffset(0, 42),
    TextXAlignment = Enum.TextXAlignment.Left,
}, Content)

local TokenGrid = Instance.new("Frame", Content)
TokenGrid.Size = UDim2.new(1, 0, 0, 54)
TokenGrid.Position = UDim2.fromOffset(0, 62)
TokenGrid.BackgroundTransparency = 1
local TGLayout = Instance.new("UIListLayout", TokenGrid)
TGLayout.FillDirection = Enum.FillDirection.Horizontal
TGLayout.Padding = UDim.new(0, 6)

local tokenLabels = {}
for _, tokenID in ipairs(TOKEN_IDS) do
    local card = Instance.new("Frame", TokenGrid)
    card.Size = UDim2.new(0.25, -5, 1, 0)
    card.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    card.BorderSizePixel = 0
    mkCorner(8, card)
    mkStroke(Color3.fromRGB(255, 170, 0), 0.7, card)

    local countL = mkLabel({
        Text = "0",
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.new(1,1,1),
        Size = UDim2.new(1, 0, 0.55, 0),
        Position = UDim2.fromOffset(0, 4),
        TextXAlignment = Enum.TextXAlignment.Center,
    }, card)
    mkLabel({
        Text = TOKEN_SHORT[tokenID],
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(140, 140, 140),
        Size = UDim2.new(1, 0, 0.4, 0),
        Position = UDim2.new(0, 0, 0.6, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
    }, card)

    tokenLabels[tokenID] = countL
end

-- Tier section
local TierTitle = mkLabel({
    Text = "TIERS",
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(255, 170, 0),
    Size = UDim2.new(1, 0, 0, 18),
    Position = UDim2.fromOffset(0, 124),
    TextXAlignment = Enum.TextXAlignment.Left,
}, Content)

local TierList = Instance.new("Frame", Content)
TierList.Size = UDim2.new(1, 0, 0, 116)
TierList.Position = UDim2.fromOffset(0, 144)
TierList.BackgroundTransparency = 1
local TLLayout = Instance.new("UIListLayout", TierList)
TLLayout.Padding = UDim.new(0, 6)

local tierRows = {}
for i, tier in ipairs(TIERS) do
    local row = Instance.new("Frame", TierList)
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    row.BorderSizePixel = 0
    mkCorner(8, row)

    local stroke = mkStroke(Color3.fromRGB(255, 170, 0), 0.7, row)

    -- Toggle
    local tog = mkBtn({
        Size = UDim2.fromOffset(44, 22),
        Position = UDim2.new(0, 8, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = tier.enabled and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(60, 60, 60),
        Text = tier.enabled and "ON" or "OFF",
        TextColor3 = Color3.new(1,1,1),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        BorderSizePixel = 0,
    }, row)
    mkCorner(11, tog)

    mkLabel({
        Text = tier.name,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.new(1,1,1),
        Size = UDim2.fromOffset(100, 32),
        Position = UDim2.fromOffset(60, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local progressLbl = mkLabel({
        Text = ("0/%d boosts"):format(tier.times),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(140, 140, 140),
        Size = UDim2.fromOffset(120, 32),
        Position = UDim2.new(1, -130, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)

    tierRows[i] = { toggle = tog, progress = progressLbl, stroke = stroke }
    tierProgress[i] = { current = 0, total = tier.times }

    tog.MouseButton1Click:Connect(function()
        TIERS[i].enabled = not TIERS[i].enabled
        tog.Text = TIERS[i].enabled and "ON" or "OFF"
        tog.BackgroundColor3 = TIERS[i].enabled and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(60, 60, 60)
        stroke.Transparency = TIERS[i].enabled and 0.7 or 0.9
    end)
end

-- Log section
local LogTitle = mkLabel({
    Text = "LOG",
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(255, 170, 0),
    Size = UDim2.new(1, 0, 0, 18),
    Position = UDim2.fromOffset(0, 268),
    TextXAlignment = Enum.TextXAlignment.Left,
}, Content)

local LogBox = Instance.new("ScrollingFrame", Content)
LogBox.Size = UDim2.new(1, 0, 0, 120)
LogBox.Position = UDim2.fromOffset(0, 288)
LogBox.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
LogBox.BorderSizePixel = 0
LogBox.ScrollBarThickness = 3
LogBox.ScrollBarImageColor3 = Color3.fromRGB(255, 170, 0)
LogBox.CanvasSize = UDim2.new(0, 0, 0, 0)
LogBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
mkCorner(8, LogBox)

local LogLayout = Instance.new("UIListLayout", LogBox)
LogLayout.Padding = UDim.new(0, 2)
local LogPad = Instance.new("UIPadding", LogBox)
LogPad.PaddingLeft = UDim.new(0, 6)
LogPad.PaddingTop = UDim.new(0, 4)

local logLinePool = {}
local function pushLog(msg, color)
    addLog(msg, color)
    local lbl = Instance.new("TextLabel", LogBox)
    lbl.Size = UDim2.new(1, -12, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 11
    lbl.TextColor3 = color or Color3.new(1,1,1)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = ("[%s] %s"):format(os.date("%H:%M:%S"), msg)
    table.insert(logLinePool, lbl)
    if #logLinePool > 50 then
        logLinePool[1]:Destroy()
        table.remove(logLinePool, 1)
    end
    task.defer(function()
        LogBox.CanvasPosition = Vector2.new(0, 1e6)
    end)
end

-- Control buttons
local BtnRow = Instance.new("Frame", Content)
BtnRow.Size = UDim2.new(1, 0, 0, 36)
BtnRow.Position = UDim2.fromOffset(0, 416)
BtnRow.BackgroundTransparency = 1
local BtnLayout = Instance.new("UIListLayout", BtnRow)
BtnLayout.FillDirection = Enum.FillDirection.Horizontal
BtnLayout.Padding = UDim.new(0, 8)

local StartBtn = mkBtn({
    Size = UDim2.new(0.5, -4, 1, 0),
    BackgroundColor3 = Color3.fromRGB(255, 170, 0),
    Text = "▶  START",
    TextColor3 = Color3.fromRGB(0, 0, 0),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BorderSizePixel = 0,
}, BtnRow)
mkCorner(8, StartBtn)

local PauseBtn = mkBtn({
    Size = UDim2.new(0.5, -4, 1, 0),
    BackgroundColor3 = Color3.fromRGB(30, 30, 40),
    Text = "⏸  PAUSE",
    TextColor3 = Color3.fromRGB(180, 180, 180),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BorderSizePixel = 0,
}, BtnRow)
mkCorner(8, PauseBtn)
mkStroke(Color3.fromRGB(255, 170, 0), 0.6, PauseBtn)

-- // Boost Engine
local function setStatus(msg, color, dotColor)
    StatusLbl.Text = msg
    StatusLbl.TextColor3 = color or Color3.fromRGB(180, 180, 180)
    StatusDot.TextColor3 = dotColor or Color3.fromRGB(80, 80, 80)
end

local function waitForUnpause()
    while paused do task.wait(0.5) end
end

local function runCycle()
    for i, tier in ipairs(TIERS) do
        if not tier.enabled then
            pushLog(tier.name .. " skipped (disabled)", Color3.fromRGB(120, 120, 120))
            continue
        end

        tierProgress[i] = { current = 0, total = tier.times }
        tierRows[i].stroke.Color = Color3.fromRGB(255, 170, 0)
        tierRows[i].stroke.Transparency = 0.3

        local done = 0
        while done < tier.times do
            waitForUnpause()
            if not running then return end

            local counts = getTokenCounts()
            local token = pickToken(counts)

            if not token then
                pushLog(("No tokens left for %s, skipping"):format(tier.name), Color3.fromRGB(255, 80, 80))
                setStatus("Out of tokens!", Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 80, 80))
                break
            end

            setStatus(("%s — Boost %d/%d [%s]"):format(tier.name, done+1, tier.times, TOKEN_SHORT[token]),
                Color3.fromRGB(255, 210, 80), Color3.fromRGB(255, 170, 0))

            local ok, err = pcall(function()
                Event:InvokeServer(tier.name, token, AMOUNT)
            end)

            if ok then
                done += 1
                tierProgress[i].current = done
                tierRows[i].progress.Text = ("%d/%d boosts"):format(done, tier.times)
                pushLog(("✓ %s boost %d/%d via %s"):format(tier.name, done, tier.times, TOKEN_SHORT[token]),
                    Color3.fromRGB(80, 220, 80))
            else
                pushLog(("✗ Error: %s"):format(tostring(err)), Color3.fromRGB(255, 80, 80))
                task.wait(3)
            end

            task.wait(DELAY)
        end

        -- flash done
        tierRows[i].stroke.Color = Color3.fromRGB(80, 220, 80)
        tierRows[i].stroke.Transparency = 0.3
    end
end

local function startLoop()
    running = true
    StartBtn.Text = "RUNNING"
    StartBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    StartBtn.TextColor3 = Color3.fromRGB(140, 140, 140)

    task.spawn(function()
        while running do
            -- reset tier strokes
            for i in ipairs(TIERS) do
                tierRows[i].stroke.Color = Color3.fromRGB(255, 170, 0)
                tierRows[i].stroke.Transparency = 0.7
                tierRows[i].progress.Text = ("0/%d boosts"):format(TIERS[i].times)
            end

            setStatus("Running cycle...", Color3.fromRGB(255, 210, 80), Color3.fromRGB(255, 170, 0))
            pushLog("=== Cycle started ===", Color3.fromRGB(255, 170, 0))
            runCycle()

            if not running then break end

            nextCycleAt = os.time() + CYCLE_HOURS * 3600
            pushLog(("=== Cycle done. Next in %dh ==="):format(CYCLE_HOURS), Color3.fromRGB(255, 170, 0))
            setStatus("Waiting for next cycle", Color3.fromRGB(140, 140, 140), Color3.fromRGB(80, 180, 80))

            while os.time() < nextCycleAt and running do
                waitForUnpause()
                task.wait(1)
            end
        end
    end)
end

StartBtn.MouseButton1Click:Connect(function()
    if not running then
        startLoop()
    end
end)

PauseBtn.MouseButton1Click:Connect(function()
    if not running then return end
    paused = not paused
    if paused then
        PauseBtn.Text = "▶  RESUME"
        PauseBtn.TextColor3 = Color3.fromRGB(255, 210, 80)
        setStatus("Paused", Color3.fromRGB(255, 130, 30), Color3.fromRGB(255, 130, 30))
        pushLog("Paused", Color3.fromRGB(255, 130, 30))
    else
        PauseBtn.Text = "⏸  PAUSE"
        PauseBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        pushLog("Resumed", Color3.fromRGB(80, 220, 80))
    end
end)

-- // Update loop (UI only)
RunService.Heartbeat:Connect(function()
    -- token counts
    local counts = getTokenCounts()
    for tokenID, lbl in pairs(tokenLabels) do
        local c = counts[tokenID] or 0
        lbl.Text = fmt(c)
        lbl.TextColor3 = c >= 1000 and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(180, 80, 80)
    end

    -- countdown
    if nextCycleAt > 0 and running and not paused then
        local remaining = nextCycleAt - os.time()
        CycleTimerLbl.Text = remaining > 0 and fmtTime(remaining) or "Soon..."
    elseif not running then
        CycleTimerLbl.Text = "--:--:--"
    end
end)

pushLog("BoostHub loaded. Press START.", Color3.fromRGB(255, 170, 0))
