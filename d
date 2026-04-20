repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

repeat task.wait() until not LocalPlayer.PlayerGui:FindFirstChild("__INTRO")

-- =========================
-- ANTI AFK
-- =========================
local Network = require(game.ReplicatedStorage.Library.Client.Network)

pcall(function()
    LocalPlayer.PlayerScripts.Scripts.Core["Idle Tracking"].Enabled = false
    LocalPlayer.PlayerScripts.Scripts.Core["Server Closing"].Enabled = false
end)

Network.Fire("Idle Tracking: Stop Timer")

for _, v in ipairs(getconnections(LocalPlayer.Idled)) do
    v:Disable()
end

-- =========================
-- ENTER EVENT + TP
-- =========================
task.spawn(function()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    local enterPart = game.Workspace.__THINGS.Instances.EasterHatchEvent.Teleports.Enter

    -- touch teleport
    firetouchinterest(hrp, enterPart, 0)
    firetouchinterest(hrp, enterPart, 1)

    -- wait a bit for teleport
    task.wait(2)

    -- TP to your CFrame
    hrp.CFrame = CFrame.new(-18505.498047, 16.239481, -29109.037109) * CFrame.Angles(0, -1.589029, 0)
end)

-- =========================
-- WEBHOOK SETUP
-- =========================
if _G.WEBHOOKS then return end
_G.WEBHOOKS = true

getgenv().Webhook = {
    ['ID'] = "",
    ['Id Names'] = {"Huge", "Titanic"},
    ['URL'] = "https://discord.com/api/webhooks/1414550206531244133/CRQ7-hTnGaBnu-v-yAGxOQYg07hdOZ2d93xfv6-PBTsSU5g3iqoV7_mkZSzoYKdBn1F1",
}

local Library = game.ReplicatedStorage.Library
local Client = Library.Client

local SaveMod = require(Client.Save)

-- =========================
-- FORMAT FUNCTION
-- =========================
local function Formatint(int)
    local suffix = {"","k","M","B","T"}
    local i = 1
    while int >= 1000 and i < #suffix do
        int /= 1000
        i += 1
    end
    return string.format("%.2f%s", int, suffix[i])
end

-- =========================
-- WEBHOOK SEND
-- =========================
local function SendWebhook(name)
    local body = game:GetService("HttpService"):JSONEncode({
        content = "",
        embeds = {{
            title = LocalPlayer.Name .. " got " .. name,
            color = 0x00ff00,
            timestamp = DateTime.now():ToIsoDate()
        }}
    })

    request({
        Url = Webhook.URL,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = body
    })
end

-- =========================
-- HUGE LOGGER
-- =========================
local last = {}

task.spawn(function()
    while true do
        local inv = SaveMod.Get().Inventory

        for class, items in pairs(inv) do
            if class == "Pet" or class == "Card" then
                for _, v in pairs(items) do
                    for _, key in ipairs(Webhook['Id Names']) do
                        if string.find(v.id, key) then
                            if not last[v.id] then
                                last[v.id] = true
                                SendWebhook(v.id)
                            end
                        end
                    end
                end
            end
        end

        task.wait(5)
    end
end)
