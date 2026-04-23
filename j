local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

repeat task.wait() until game:IsLoaded()
repeat task.wait() until not LocalPlayer.PlayerGui:FindFirstChild("__INTRO")

local Library = ReplicatedStorage.Library
local Network = require(Library.Client.Network)
local PetNetworking = require(Library.Client.PetNetworking)

-- // State
local AllBreakables = {}   -- [tostring(u)] = breakable data
local Euids = {}           -- [petID] = petData
local PetIDs = {}          -- ordered list
local LastUseEuids = {}    -- [petID] = { time, breakableKey }
local breakableOffset = 0

-- // Pets
local function rebuildPets()
    PetIDs = {}
    Euids = {}
    local equipped = PetNetworking.EquippedPets()
    if type(equipped) ~= "table" then return end
    for petID, petData in pairs(equipped) do
        Euids[petID] = petData
        table.insert(PetIDs, petID)
    end
    print("Pets:", #PetIDs)
end
rebuildPets()

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

-- // Breakables — key MUST be tostring(u) to match server
local function onCreated(data)
    for _, entry in pairs(data) do
        local b = entry[1]
        if not b or not b.u then continue end
        local key = tostring(b.u)
        if not AllBreakables[key] then
            AllBreakables[key] = b
        end
    end
end

local function onDestroyed(data)
    if type(data) == "string" then
        AllBreakables[data] = nil
    elseif type(data) == "table" then
        for _, b in pairs(data) do
            if type(b) == "table" then
                AllBreakables[tostring(b[1])] = nil
            else
                AllBreakables[tostring(b)] = nil
            end
        end
    end
end

local function onCleanup(data)
    for _, entry in pairs(data) do
        AllBreakables[tostring(entry[1])] = nil
    end
end

Network.Fired("Breakables_Created"):Connect(onCreated)
Network.Fired("Breakables_Ping"):Connect(onCreated)
Network.Fired("Breakables_Destroyed"):Connect(onDestroyed)
Network.Fired("Breakables_DestroyDueToReplicationFail"):Connect(onDestroyed)
Network.Fired("Breakables_Cleanup"):Connect(onCleanup)

-- // Orbs
Network.Fired("Orbs: Create"):Connect(function(Orbs)
    local Collect = {}
    for _, v in ipairs(Orbs) do
        local ID = tonumber(v.id)
        if ID then table.insert(Collect, ID) end
    end
    if #Collect > 0 then Network.Fire("Orbs: Collect", Collect) end
end)

print("Breakable farmer running...")

-- // Main loop — exact logic from Hasty
while true do
    task.wait()

    local availableBreakables = {}
    for key in pairs(AllBreakables) do
        table.insert(availableBreakables, key)
    end

    local numBreakables = #availableBreakables
    if numBreakables == 0 then continue end

    local now = os.clock()
    local bulkAssignments = {}

    for i, petID in ipairs(PetIDs) do
        if not Euids[petID] then continue end

        local lastData = LastUseEuids[petID]
        local blockedKey = (lastData and (now - lastData.time < 1)) and lastData.breakableKey or nil

        -- filter out recently used breakable for this pet
        local filtered = {}
        for _, key in ipairs(availableBreakables) do
            if key ~= blockedKey then
                table.insert(filtered, key)
            end
        end

        local pool
        if #filtered == 0 then
            -- all blocked, find the least recently used breakable
            local oldestKey = nil
            local oldestTime = math.huge
            for _, key in ipairs(availableBreakables) do
                local lastUsed = -math.huge
                for _, data in pairs(LastUseEuids) do
                    if data.breakableKey == key and data.time > lastUsed then
                        lastUsed = data.time
                    end
                end
                if lastUsed < oldestTime then
                    oldestTime = lastUsed
                    oldestKey = key
                end
            end
            pool = { oldestKey or availableBreakables[1] }
        else
            pool = filtered
        end

        local chosen = pool[((i - 1 + breakableOffset) % #pool) + 1]
        bulkAssignments[petID] = chosen
        LastUseEuids[petID] = { time = now, breakableKey = chosen }
    end

    if next(bulkAssignments) then
        task.spawn(function()
            Network.Fire("Breakables_JoinPetBulk", bulkAssignments)
        end)
        task.wait(0.2)
    end

    breakableOffset += 1
end
