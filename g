local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- // CONFIG
getgenv().Webhook = {
    url = "https://discord.com/api/webhooks/1414550206531244133/CRQ7-hTnGaBnu-v-yAGxOQYg07hdOZ2d93xfv6-PBTsSU5g3iqoV7_mkZSzoYKdBn1F1",
    ["Discord Id to ping"] = "",
}

local TARGET_CF = CFrame.new(-31845.877, 16.2397251, -31417.5195, -0.283003271, 9.37665376e-08, -0.959118962, 4.05607068e-08, 1, 8.57951221e-08, 0.959118962, -1.4622243e-08, -0.283003271)

-- // Anti AFK
repeat task.wait() until game:IsLoaded()
repeat task.wait() until not LocalPlayer.PlayerGui:FindFirstChild("__INTRO")
local Network = require(ReplicatedStorage.Library.Client.Network)
local Save = require(ReplicatedStorage.Library.Client.Save)
LocalPlayer.PlayerScripts.Scripts.Core["Idle Tracking"].Enabled = false
LocalPlayer.PlayerScripts.Scripts.Core["Server Closing"].Enabled = false
Network.Fire("Idle Tracking: Stop Timer")
for _, conn in ipairs(getconnections(LocalPlayer.Idled)) do conn:Disable() end
print("Anti-AFK enabled")

-- // Webhook watcher
task.spawn(function()
    local Data = Save.Get()
    local StartEggs = Data.EggsHatched
    local discovered_Huge_titan = {}

    local function getPetLabel(data)
        local prefix = ""
        if data.sh then prefix = "Shiny " end
        if data.pt == 1 then prefix = prefix .. "Golden "
        elseif data.pt == 2 then prefix = prefix .. "Rainbow " end
        return prefix .. data.id
    end

    local function sendWebhook(data)
        if not Webhook then return end
        if not string.find(Webhook.url or "", "https://discord.com/api/webhooks") then return end
        local isTitanic = string.find(data.id, "Titanic")
        local color
        if data.pt == 2 then color = 11141375
        elseif data.pt == 1 then color = 16766720
        elseif data.sh then color = 4031935
        elseif isTitanic then color = 16711680
        else color = 16776960 end
        local pingText = ""
        if Webhook["Discord Id to ping"] then
            local ids = Webhook["Discord Id to ping"]
            if type(ids) == "table" then
                for _, id in ipairs(ids) do pingText = pingText .. "<@" .. tostring(id) .. "> " end
            else
                pingText = "<@" .. tostring(ids) .. ">"
            end
        end
        local label = getPetLabel(data)
        local description = "**" .. LocalPlayer.Name .. "** hatched a **" .. label .. "**"
        local bodyTable = {
            content = pingText ~= "" and pingText or nil,
            embeds = {{
                title = isTitanic and "✨ Titanic Hatched!" or "🎉 Huge Hatched!",
                description = description,
                color = color,
                footer = { text = "Eggs hatched: " .. tostring(Data.EggsHatched - StartEggs) }
            }}
        }
        local ok, body = pcall(function() return game:GetService("HttpService"):JSONEncode(bodyTable) end)
        if not ok then return end
        pcall(function()
            request({ Url = Webhook.url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
    end

    while true do
        local Inventory = Save.Get()['Inventory']
        for Class, Items in pairs(Inventory) do
            if Class == "Pet" or Class == "Card" then
                for uid, v in pairs(Items) do
                    if string.find(v.id, "Huge") or string.find(v.id, "Titanic") then
                        if not discovered_Huge_titan[uid] then
                            discovered_Huge_titan[uid] = true
                            sendWebhook(v)
                        end
                    end
                end
            end
        end
        task.wait(5)
    end
end)

-- // Event enter + TP
task.spawn(function()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    local enterPart = workspace.__THINGS.Instances.EasterHatchEvent.Teleports.Enter
    firetouchinterest(hrp, enterPart, 0)
    firetouchinterest(hrp, enterPart, 1)

    local function IsInInstance()
        local inst = workspace:FindFirstChild("__THINGS")
            and workspace.__THINGS:FindFirstChild("__INSTANCE_CONTAINER")
            and workspace.__THINGS.__INSTANCE_CONTAINER:FindFirstChild("Active")
        return inst and inst:FindFirstChild("EasterHatchEvent")
    end

    local t = 0
    repeat task.wait(0.5); t += 0.5 until IsInInstance() or t >= 10

    if not IsInInstance() then warn("Failed to enter instance"); return end

    task.wait(0.5)
    ReplicatedStorage.Network.Instancing_FireCustomFromClient:FireServer("EasterHatchEvent", "ZonePortal", 2)
    task.wait(1)
    hrp.CFrame = TARGET_CF
    print("Done")
end)
