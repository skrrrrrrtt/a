-- // Prevent multiple instances
if _G.ZapHubLoaded then return end
_G.ZapHubLoaded = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- // Variables
local LocalPlayer = Players.LocalPlayer
local Library = ReplicatedStorage:WaitForChild("Library")
local Client = Library:WaitForChild("Client")
local SaveMod = require(Client:WaitForChild("Save"))
local Directory = require(Library:WaitForChild("Directory"))

-- // Theme Configuration
local Theme = {
    Background = Color3.fromRGB(10, 10, 10),
    Accent = Color3.fromRGB(255, 170, 0), 
    CardBG = Color3.fromRGB(15, 15, 15),
    Text = Color3.fromRGB(255, 255, 255)
}

-- // Item Mapping
local TrackedItems = {
    {Name = "Diamonds", ID = "Diamonds", Type = "Currency"},
    {Name = "Spring Egg Token", ID = "Spring Egg Token", Type = "Item"},
    {Name = "Spring Bluebell Token", ID = "Spring Bluebell Token", Type = "Item"},
    {Name = "Spring Red Tulip Token", ID = "Spring Red Tulip Token", Type = "Item"},
    {Name = "Spring Pink Rose Token", ID = "Spring Pink Rose Token", Type = "Item"},
    {Name = "Spring Yellow Sunflower Token", ID = "Spring Yellow Sunflower Token", Type = "Item"},
    {Name = "Huge Dawn Phoenix", ID = "Huge Dawn Phoenix", Type = "Pet"},
    {Name = "Huge Diamond Chick", ID = "Huge Diamond Chick", Type = "Pet"},
    {Name = "Titanic Diamond Chick", ID = "Titanic Diamond Chick", Type = "Pet"}
}

-- // Helper: Format Numbers (2.5K style)
local function FormatInt(int)
    local Suffix = {"", "K", "M", "B", "T"}
    local Index = 1
    if int < 1000 then return tostring(int) end
    while int >= 1000 and Index < #Suffix do
        int = int / 1000
        Index = Index + 1
    end
    return string.format("%.1f%s", int, Suffix[Index]):gsub("%.", ",")
end

-- // Helper: Get Asset Image
local function GetIcon(Id)
    local petData = Directory.Pets[Id]
    if petData then
        local iconId = string.gsub(petData.thumbnail or "14976456685", "rbxassetid://", "")
        return "https://biggamesapi.io/image/" .. iconId
    end
    -- Default icons for specific currencies/items
    if Id == "Diamonds" then return "https://biggamesapi.io/image/14976456685" end
    return ""
end

-- // Create UI
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Name = "ZapHub_Easter"
ScreenGui.IgnoreGuiInset = true

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(1, 0, 1, 0)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BorderSizePixel = 0

-- UI Layout
local Title = Instance.new("TextLabel", MainFrame)
Title.Text = "ZapHub"
Title.TextColor3 = Theme.Accent
Title.Font = Enum.Font.GothamBold
Title.TextSize = 35
Title.Position = UDim2.new(0, 50, 0, 30)
Title.Size = UDim2.new(0, 200, 0, 50)
Title.BackgroundTransparency = 1

local EventTitle = Instance.new("TextLabel", MainFrame)
EventTitle.Text = "Easter 2026"
EventTitle.TextColor3 = Color3.new(1, 1, 1)
EventTitle.Font = Enum.Font.GothamBold
EventTitle.TextSize = 50
EventTitle.Position = UDim2.new(0.5, -200, 0, 80)
EventTitle.Size = UDim2.new(0, 400, 0, 60)
EventTitle.BackgroundTransparency = 1

local PremiumSub = Instance.new("TextLabel", EventTitle)
PremiumSub.Text = "Premium users only"
PremiumSub.TextColor3 = Theme.Accent
PremiumSub.Font = Enum.Font.SourceSansItalic -- FIXED: GothamItalic doesn't exist
PremiumSub.TextSize = 18
PremiumSub.Position = UDim2.new(0, 0, 0.8, 0)
PremiumSub.Size = UDim2.new(1, 0, 0, 20)
PremiumSub.BackgroundTransparency = 1

local Container = Instance.new("ScrollingFrame", MainFrame)
Container.Size = UDim2.new(0.6, 0, 0.65, 0)
Container.Position = UDim2.new(0.2, 0, 0.25, 0)
Container.BackgroundTransparency = 1
Container.ScrollBarThickness = 0

local UIList = Instance.new("UIListLayout", Container)
UIList.Padding = UDim.new(0, 10)
UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- // Generate Rows
local ItemLabels = {}

for _, item in pairs(TrackedItems) do
    local Row = Instance.new("Frame", Container)
    Row.Size = UDim2.new(1, 0, 0, 45)
    Row.BackgroundColor3 = Theme.CardBG
    
    local Corner = Instance.new("UICorner", Row)
    Corner.CornerRadius = UDim.new(0, 6)
    
    local Stroke = Instance.new("UIStroke", Row)
    Stroke.Color = Theme.Accent
    Stroke.Transparency = 0.6

    local Icon = Instance.new("ImageLabel", Row)
    Icon.Size = UDim2.new(0, 30, 0, 30)
    Icon.Position = UDim2.new(0, 10, 0.5, -15)
    Icon.BackgroundTransparency = 1
    Icon.Image = GetIcon(item.ID)

    local Text = Instance.new("TextLabel", Row)
    Text.Size = UDim2.new(1, -50, 1, 0)
    Text.Position = UDim2.new(0, 50, 0, 0)
    Text.TextColor3 = Theme.Text
    Text.Font = Enum.Font.GothamBold
    Text.TextSize = 16
    Text.TextXAlignment = Enum.TextXAlignment.Left
    Text.Text = item.Name .. ": 0"
    Text.BackgroundTransparency = 1
    
    ItemLabels[item.ID] = Text
end

-- // Live Monitor Logic
task.spawn(function()
    while true do
        local Save = SaveMod.Get()
        if Save and Save.Inventory then
            local Inv = Save.Inventory
            
            for _, info in pairs(TrackedItems) do
                local count = 0
                
                if info.ID == "Diamonds" then
                    count = Save.Diamonds or 0
                else
                    -- Check inside categories (Pet, Item, etc.)
                    for class, items in pairs(Inv) do
                        for _, v in pairs(items) do
                            if v.id == info.ID then
                                count = count + (v._am or 1)
                            end
                        end
                    end
                end
                
                if ItemLabels[info.ID] then
                    ItemLabels[info.ID].Text = info.Name .. ": " .. FormatInt(count)
                end
            end
        end
        task.wait(2)
    end
end)
