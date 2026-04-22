local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

repeat task.wait() until game:IsLoaded()
repeat task.wait() until not LocalPlayer.PlayerGui:FindFirstChild("__INTRO")

local Library = ReplicatedStorage.Library
local Network = require(Library.Client.Network)
local PetNetworking = require(Library.Client.PetNetworking)

local AllBreakables = {}  -- [u_number] = breakable data
local PetIDs = {}
local Euids = {}

-- // Pet tracking
local function updatePets()
    PetIDs = {}
    Euids = {}
    local equipped = PetNetworking.EquippedPets()
    if type(equipped) ~= "table" then return end
    for petID, petData in pairs(equipped) do
        Euids[petID] = petData
        table.insert(PetIDs, petID)
    end
    print("Pets loaded:", #PetIDs)
end
updatePets()

Network.Fired("Pets_LocalPetsUpdated"):Connect(function(pets)
    if type(pets) ~= "table" then return end
    for _, v in pairs(pets) do
        if v.ePet and v.ePet.euid and not Euids[v.ePet.euid] then
            Euids[v.ePet.euid] = v.ePet
            table.insert(PetIDs, v.ePet.euid)
        end
    end
end)

Network.Fired("Pets_LocalPetsUnequipped"):Connect(function(pets)
    if type(pets) ~= "table" then return end
    for _, petID in pairs(pets) do Euids[petID] = nil end
    local valid = {}
    for _, id in ipairs(PetIDs) do
        if Euids[id] then table.insert(valid, id) end
    end
    PetIDs = valid
end)

-- // Breakable tracking — key is raw u number
local function onCreated(data)
    for _, entry in pairs(data) do
        local b = entry[1]
        if not b or not b.u then continue end
        AllBreakables[b.u] = b
    end
    local count = 0
    for _ in pairs(AllBreakables) do count += 1 end
    print("Breakables now tracked:", count)
end

local function onDestroyed(data)
    if type(data) == "string" then
        AllBreakables[tonumber(data)] = nil
    elseif type(data) == "table" then
        for _, b in pairs(data) do
            local key = type(b) == "table" and b[1] or b
            AllBreakables[tonumber(tostring(key))] = nil
        end
    end
end

local function onCleanup(data)
    for _, entry in pairs(data) do
        AllBreakables[entry[1]] = nil
    end
end

Network.Fired("Breakables_Created"):Connect(onCreated)
Network.Fired("Breakables_Ping"):Connect(onCreated)
Network.Fired("Breakables_Destroyed"):Connect(onDestroyed)
Network.Fired("Breakables_DestroyDueToReplicationFail"):Connect(onDestroyed)
Network.Fired("Breakables_Cleanup"):Connect(onCleanup)

-- // Orb collect
Network.Fired("Orbs: Create"):Connect(function(Orbs)
    local Collect = {}
    for _, v in ipairs(Orbs) do
        local ID = tonumber(v.id)
        if ID then table.insert(Collect, ID) end
    end
    if #Collect > 0 then Network.Fire("Orbs: Collect", Collect) end
end)

print("Waiting for breakables...")

-- // Main loop
local offset = 0
while true do
    task.wait()

    local available = {}
    for u, info in pairs(AllBreakables) do
        table.insert(available, u)  -- raw number keys
    end

    if #available == 0 then continue end

    local bulkAssignments = {}
    for i, petID in ipairs(PetIDs) do
        if not Euids[petID] then continue end
        local chosen = available[((i - 1 + offset) % #available) + 1]
        bulkAssignments[petID] = chosen
    end

    if next(bulkAssignments) then
        print("Firing bulk with", #available, "breakables,", #PetIDs, "pets")
        Network.Fire("Breakables_JoinPetBulk", bulkAssignments)
    end

    offset += 1
end
