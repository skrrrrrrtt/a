repeat task.wait() until game:IsLoaded()

-- // SERVICES
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerSave = require(ReplicatedStorage.Library.Client.Save)

-- // PREVENT DUPLICATES
pcall(function() CoreGui:FindFirstChild("ZapHubStats"):Destroy() end)

-- // CONFIGURATION
local TrackedItems = {
    {Name = "Diamonds", ID = "Diamonds", Category = "Currency"},
    {Name = "Spring Egg Token", ID = "Spring Egg Token", Category = "Item"},
    {Name = "Spring Bluebell Token", ID = "Spring Bluebell Token", Category = "Item"},
    {Name = "Spring Red Tulip Token", ID = "Spring Red Tulip Token", Category = "Item"},
    {Name = "Spring Pink Rose Token", ID = "Spring Pink Rose Token", Category = "Item"},
    {Name = "Spring Yellow Sunflower Token", ID = "Spring Yellow Sunflower Token", Category = "Item"},
    {Name = "Huge Dawn Phoenix", ID = "Huge Dawn Phoenix", Category = "Pet"},
    {Name = "Huge Diamond Chick", ID = "Huge Diamond Chick", Category = "Pet"},
    {Name = "Titanic Diamond Chick", ID = "Titanic Diamond Chick", Category = "Pet"}
}

-- // GUI CONSTRUCTION
local gui = Instance.new("ScreenGui")
gui.Name = "ZapHubStats"
gui.IgnoreGuiInset = true
gui.Parent = CoreGui

local bg = Instance.new("Frame", gui)
bg.AnchorPoint = Vector2.new(0.5, 0.5)
bg.Position = UDim2.fromScale(0.5, 0.5)
bg.Size = UDim2.fromScale(1.5, 1.5) -- Full screen coverage
bg.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
bg.BorderSizePixel = 0

local container = Instance.new("Frame", bg)
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.Position = UDim2.fromScale(0.5, 0.5)
container.Size = UDim2.fromOffset(500, 600)
container.BackgroundTransparency = 1

-- UI Helper: Create Row
local Labels = {}
local function createRow(name, index)
    local row = Instance.new("Frame", container)
    row.Size = UDim2.new(1, 0, 0, 45)
    row.Position = UDim2.fromOffset(0, 140 + (index * 50))
    row.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    row.BorderSizePixel = 0
    
    local stroke = Instance.new("UIStroke", row)
    stroke.Color = Color3.fromRGB(255, 170, 0)
    stroke.Transparency = 0.5
    
    local corner = Instance.new("UICorner", row)
    corner.CornerRadius = UDim.new(0, 6)
    
    local label = Instance.new("TextLabel", row)
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.fromOffset(15, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextSize = 18
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = name .. ": 0"
    
    return label
end

-- Header Titles
local mainTitle = Instance.new("TextLabel", container)
mainTitle.Text = "Easter 2026"
mainTitle.Font = Enum.Font.GothamBold
mainTitle.TextSize = 55
mainTitle.TextColor3 = Color3.new(1, 1, 1)
mainTitle.Size = UDim2.new(1, 0, 0, 60)
mainTitle.Position = UDim2.fromOffset(0, 30)
mainTitle.BackgroundTransparency = 1

local subTitle = Instance.new("TextLabel", mainTitle)
subTitle.Text = "Premium users only"
subTitle.Font = Enum.Font.SourceSansItalic
subTitle.TextSize = 20
subTitle.TextColor3 = Color3.fromRGB(255, 170, 0)
subTitle.Position = UDim2.new(0, 0, 1, -5)
subTitle.Size = UDim2.new(1, 0, 0, 20)
subTitle.BackgroundTransparency = 1

-- Initialize Rows
for i, item in ipairs(TrackedItems) do
    Labels[item.ID] = createRow(item.Name, i)
end

-- // HELPERS
local function fmt(n)
    if n >= 1e9 then return string.format("%.1fB", n/1e9):gsub("%.", ",")
    elseif n >= 1e6 then return string.format("%.1fM", n/1e6):gsub("%.", ",")
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3):gsub("%.", ",")
    end
    return tostring(math.floor(n))
end

-- // LIVE UPDATE LOOP
local startTime = os.clock()
local timerLabel = Instance.new("TextLabel", container)
timerLabel.Position = UDim2.new(1, -100, 0, 0)
timerLabel.Size = UDim2.new(0, 100, 0, 30)
timerLabel.TextColor3 = Color3.new(1,1,1)
timerLabel.Font = Enum.Font.Code
timerLabel.TextSize = 16
timerLabel.BackgroundTransparency = 1

RunService.RenderStepped:Connect(function()
    local save = PlayerSave.Get()
    if not save or not save.Inventory then return end
    
    -- Update Timer
    local t = os.clock() - startTime
    timerLabel.Text = string.format("%02d:%02d:%02d", math.floor(t/3600), math.floor(t%3600/60), math.floor(t%60))

    -- Update Items
    for _, itemInfo in pairs(TrackedItems) do
        local count = 0
        
        if itemInfo.ID == "Diamonds" then
            count = save.Diamonds or 0
        else
            -- Search Pet, Item, and Misc categories
            for category, items in pairs(save.Inventory) do
                for _, data in pairs(items) do
                    if data.id == itemInfo.ID then
                        count = count + (data._am or 1)
                    end
                end
            end
        end
        
        if Labels[itemInfo.ID] then
            Labels[itemInfo.ID].Text = itemInfo.Name .. ": " .. fmt(count)
        end
    end
end)

-- // OPEN/CLOSE BUTTONS
local closeBtn = Instance.new("TextButton", container)
closeBtn.Size = UDim2.fromOffset(120, 35)
closeBtn.Position = UDim2.new(0.5, -60, 1, 20)
closeBtn.Text = "CLOSE HUD"
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", closeBtn)

local openBtn = Instance.new("TextButton", gui)
openBtn.Size = UDim2.fromOffset(120, 35)
openBtn.Position = UDim2.new(0.5, -60, 0, 50)
openBtn.Text = "OPEN HUD"
openBtn.Visible = false
openBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
openBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", openBtn)

closeBtn.MouseButton1Click:Connect(function()
    bg.Visible = false
    openBtn.Visible = true
end)

openBtn.MouseButton1Click:Connect(function()
    bg.Visible = true
    openBtn.Visible = false
end)
