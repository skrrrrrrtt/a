local hrp = game.Players.LocalPlayer.Character.HumanoidRootPart
local RunService = game:GetService("RunService")
local char = game.Players.LocalPlayer.Character
local hum = char:FindFirstChildOfClass("Humanoid")

-- noclip
local noclip = RunService.Stepped:Connect(function()
    for _, p in pairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end)

hum.PlatformStand = true

-- get current pos as center, sweep 1000 studs around you
local center = hrp.Position
local range = 1000
local stepSize = 80
local flyY = center.Y + 10 -- stay at same Y as backrooms floor

local waypoints = {}
local row = 0
local z = center.Z - range
while z <= center.Z + range do
    local xStart = (row % 2 == 0) and center.X - range or center.X + range
    local xEnd = (row % 2 == 0) and center.X + range or center.X - range
    local xStep = (row % 2 == 0) and stepSize or -stepSize
    local x = xStart
    while (xStep > 0 and x <= xEnd) or (xStep < 0 and x >= xEnd) do
        table.insert(waypoints, Vector3.new(x, flyY, z))
        x = x + xStep
    end
    z = z + stepSize
    row = row + 1
end

print("waypoints: " .. #waypoints .. " | enter backrooms then this will sweep")

for i, wp in pairs(waypoints) do
    hrp.CFrame = CFrame.new(wp)
    task.wait(0.05) -- fast enough to cover ground, slow enough to render
    if i % 50 == 0 then
        print("progress: " .. math.floor(i/#waypoints*100) .. "%")
    end
end

noclip:Disconnect()
hum.PlatformStand = false
print("sweep done!")

-- scan
local RS = game:GetService("ReplicatedStorage")
local eggsFolder = RS.__DIRECTORY.Eggs["Backrooms Update 2"]
local backrooms = workspace.__THINGS.__INSTANCE_CONTAINER.Active.Backrooms.GeneratedBackrooms

local multiToEgg = {}
for _, egg in pairs(eggsFolder:GetChildren()) do
    local multi = egg.Name:match("(%d+)x")
    local eggType = egg.Name:match("| (.+) %d+x")
    if multi and eggType then
        multiToEgg[tonumber(multi)] = eggType
    end
end

local found = {}
for _, room in pairs(backrooms:GetChildren()) do
    local roomID = room:GetAttribute("RoomID")
    if roomID and roomID:lower():find("egg") then
        local multi = room:GetAttribute("EggMultiplier")
        local eggModel = room:FindFirstChild("EggModel", true)
        local part = eggModel and eggModel:FindFirstChildWhichIsA("BasePart")
        if part then
            local eggName = multiToEgg[multi] or ("Unknown " .. tostring(multi) .. "x")
            table.insert(found, {name = eggName, multi = multi or 0, part = part})
            print("EGG: " .. eggName .. " [" .. tostring(multi) .. "x]")
        end
    end
end

print("=== TOTAL: " .. #found .. " eggs ===")
