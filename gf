local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- // CONFIG
local WEBHOOK_URL = "https://discord.com/api/webhooks/1414550206531244133/CRQ7-hTnGaBnu-v-yAGxOQYg07hdOZ2d93xfv6-PBTsSU5g3iqoV7_mkZSzoYKdBn1F1"
local WEBHOOK_ID  = ""  -- for ping
local TARGET_CF   = CFrame.new(-31845.877, 16.2397251, -31417.5195, -0.283003271, 9.37665376e-08, -0.959118962, 4.05607068e-08, 1, 8.57951221e-08, 0.959118962, -1.4622243e-08, -0.283003271)
local TRACK_NAMES = { "Huge", "Titanic" }

-- // Anti AFK
repeat task.wait() until game:IsLoaded()
repeat task.wait() until not LocalPlayer.PlayerGui:FindFirstChild("__INTRO")
local Library = ReplicatedStorage.Library
local Network  = require(Library.Client.Network)
local SaveMod  = require(Library.Client.Save)
LocalPlayer.PlayerScripts.Scripts.Core["Idle Tracking"].Enabled = false
LocalPlayer.PlayerScripts.Scripts.Core["Server Closing"].Enabled = false
Network.Fire("Idle Tracking: Stop Timer")
for _, conn in ipairs(getconnections(LocalPlayer.Idled)) do conn:Disable() end
print("Anti-AFK enabled")

-- // Formatint
local function Formatint(int)
    local Suffix = {"","k","M","B","T","Qd","Qn","Sx","Sp","Oc","No","De"}
    local Index = 1
    if int < 999 then return int end
    while int >= 1000 and Index < #Suffix do int = int/1000; Index += 1 end
    return string.format("%.2f%s", int, Suffix[Index])
end

-- // Get thumbnail
local function GetAsset(Id, pt)
    local Asset = require(Library.Directory.Pets)[Id]
    return string.gsub(Asset and (pt == 1 and Asset.goldenThumbnail or Asset.thumbnail) or "14976456685", "rbxassetid://", "")
end

-- // Webhook
local function SendWebhook(Class, Id, pt, sh)
    local Version = pt == 1 and "Golden " or pt == 2 and "Rainbow " or ""
    local Shiny   = sh and "Shiny " or ""
    local Title   = string.format("%s just got **%s%s%s**", LocalPlayer.Name, Version, Shiny, Id)
    local Img     = string.format("https://biggamesapi.io/image/%s", GetAsset(Id, pt))

    local Rap, Exist = 0, 0
    pcall(function()
        local RapCmds  = require(Library.Client.RAPCmds)
        local ExistCmds = require(Library.Client.ExistCountCmds)
        Rap   = RapCmds.GetRap(Id, pt, sh) or 0
        Exist = ExistCmds.GetExistCount(Id, pt, sh) or 0
    end)

    local Body = HttpService:JSONEncode({
        content = string.format("<@%s>", WEBHOOK_ID),
        embeds = {{
            title = Title,
            color = 0xFF8C00,
            timestamp = DateTime.now():ToIsoDate(),
            thumbnail = { url = Img },
            fields = {{
                name = string.format("💎 RAP: `%s`  |  💫 Exist: `%s`", Formatint(Rap), Formatint(Exist)),
                value = ""
            }},
            footer = { text = "BoostHub Notifier" }
        }}
    })

    pcall(function()
        request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = Body
        })
    end)

    print(string.format("Webhook sent: %s%s%s", Version, Shiny, Id))
end

-- // Inventory watcher
local HugeCount = {}
task.spawn(function()
    while true do
        local Inventory = SaveMod.Get()['Inventory']
        local CurrentCount = {}

        for Class, Items in pairs(Inventory) do
            if Class == "Pet" or Class == "Card" then
                for _, v in pairs(Items) do
                    for _, name in ipairs(TRACK_NAMES) do
                        if string.find(v.id, name) then
                            local Key = Class .. "_" .. v.id
                            CurrentCount[Key] = (CurrentCount[Key] or 0) + 1
                            if (HugeCount[Key] or 0) < CurrentCount[Key] then
                                SendWebhook(Class, v.id, v.pt, v.sh)
                                HugeCount[Key] = CurrentCount[Key]
                            end
                        end
                    end
                end
            end
        end

        -- sync down if count dropped
        for key, count in pairs(HugeCount) do
            if (CurrentCount[key] or 0) < count then
                HugeCount[key] = CurrentCount[key] or 0
            end
        end

        task.wait(5)
    end
end)

-- // Event enter + TP
task.spawn(function()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart")

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
    print("Done - inside event")
end)
