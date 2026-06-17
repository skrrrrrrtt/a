local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local folder = RS.__DIRECTORY.Eggs["Backrooms Update 2"]

-- get eggs grouped by type
local eggs = {}
for _, egg in pairs(folder:GetChildren()) do
    local multiplier = egg.Name:match("(%d+)x")
    local eggType = egg.Name:match("Backrooms (.+) Egg")
    if eggType and multiplier then
        if not eggs[eggType] then eggs[eggType] = {} end
        table.insert(eggs[eggType], {name = egg.Name, obj = egg, multi = tonumber(multiplier)})
    end
end

-- sort each type by multiplier
for _, t in pairs(eggs) do
    table.sort(t, function(a, b) return a.multi < b.multi end)
end

-- UI
local sg = Instance.new("ScreenGui")
sg.Name = "BackroomEggTP"
sg.ResetOnSpawn = false
sg.Parent = game:GetService("CoreGui") -- use CoreGui instead

local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 300, 0, 400)
main.Position = UDim2.new(0.5, -150, 0.5, -200)
main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true

-- title
local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
title.TextColor3 = Color3.fromRGB(255, 200, 0)
title.Text = "Backrooms Update 2 Eggs"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.BorderSizePixel = 0

-- close btn
local close = Instance.new("TextButton", main)
close.Size = UDim2.new(0, 30, 0, 30)
close.Position = UDim2.new(1, -35, 0, 2)
close.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
close.TextColor3 = Color3.new(1,1,1)
close.Text = "X"
close.Font = Enum.Font.GothamBold
close.TextSize = 14
close.BorderSizePixel = 0
close.MouseButton1Click:Connect(function() sg:Destroy() end)

-- scroll
local scroll = Instance.new("ScrollingFrame", main)
scroll.Size = UDim2.new(1, -10, 1, -45)
scroll.Position = UDim2.new(0, 5, 0, 40)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 4
scroll.BorderSizePixel = 0
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0,0,0,0)

local layout = Instance.new("UIListLayout", scroll)
layout.Padding = UDim.new(0, 4)

local function makeBtn(egg)
    local btn = Instance.new("TextButton", scroll)
    btn.Size = UDim2.new(1, -8, 0, 38)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Text = egg.name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.TextXAlignment = Enum.TextXAlignment.Left

    local pad = Instance.new("UIPadding", btn)
    pad.PaddingLeft = UDim.new(0, 8)

    -- color by multiplier
    local col
    if egg.multi >= 50 then
        col = Color3.fromRGB(255, 100, 100) -- red = high multi
    elseif egg.multi >= 10 then
        col = Color3.fromRGB(255, 200, 50) -- yellow = mid
    else
        col = Color3.fromRGB(100, 200, 100) -- green = low
    end

    local accent = Instance.new("Frame", btn)
    accent.Size = UDim2.new(0, 4, 1, 0)
    accent.BackgroundColor3 = col
    accent.BorderSizePixel = 0

    btn.MouseButton1Click:Connect(function()
        local char = lp.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end

        local eggObj = egg.obj
        if not eggObj or not eggObj.Parent then
            btn.Text = "[GONE] " .. egg.name
            btn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
            return
        end

        -- try to find a part to tp to
        local target
        if eggObj:IsA("BasePart") then
            target = eggObj
        else
            target = eggObj:FindFirstChildWhichIsA("BasePart", true)
        end

        if target then
            char.HumanoidRootPart.CFrame = target.CFrame + Vector3.new(0, 5, 0)
            btn.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
            task.delay(1, function()
                btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            end)
        else
            warn("no part found for " .. egg.name)
        end
    end)

    return btn
end

-- build buttons grouped by type
for eggType, list in pairs(eggs) do
    -- section header
    local header = Instance.new("TextLabel", scroll)
    header.Size = UDim2.new(1, -8, 0, 24)
    header.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    header.TextColor3 = Color3.fromRGB(255, 200, 0)
    header.Text = "[ " .. eggType .. " ]"
    header.Font = Enum.Font.GothamBold
    header.TextSize = 12
    header.BorderSizePixel = 0

    for _, egg in pairs(list) do
        makeBtn(egg)
    end
end

print("Backroom Egg TP UI loaded — " .. #folder:GetChildren() .. " eggs found")
