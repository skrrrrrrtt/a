-- Crypto Price Monitor | Street Life Remastered

local LP = game:GetService("Players").LocalPlayer

local function getPrice()
    -- try to find the price in PhoneUI
    local ok, result = pcall(function()
        local phoneUI = LP.PlayerGui:WaitForChild("PhoneUI", 5)
        if not phoneUI then return nil end
        
        -- search for any TextLabel containing a number (the price)
        for _, v in ipairs(phoneUI:GetDescendants()) do
            if v:IsA("TextLabel") or v:IsA("TextButton") then
                local num = v.Text:match("%$?(%d[%d,]+)")
                if num then
                    return tonumber(num:gsub(",", ""))
                end
            end
        end
    end)
    return ok and result or nil
end

-- print price every 30s and also detect when it changes
task.spawn(function()
    local lastPrice = nil
    while true do
        local price = getPrice()
        if price then
            if price ~= lastPrice then
                print(string.format("[Crypto] Price CHANGED: $%d", price))
                lastPrice = price
            else
                print(string.format("[Crypto] Current price: $%d", price))
            end
        else
            print("[Crypto] Couldn't read price yet — open the phone in-game first")
        end
        task.wait(30)
    end
end)

-- also hook the remote to catch price in real time when phone fires
local remote = game:GetService("ReplicatedStorage").Remotes.Phone
local mt = getrawmetatable(game)
local oldIndex = mt.__index
local oldNamecall = mt.__namecall
setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    if method == "FireServer" and self == remote then
        local action = args[1]
        local subAction = args[2]
        local amount = args[3]
        if action == "Crypto" then
            print(string.format("[Crypto] FireServer detected | Action: %s | Amount: $%d", tostring(subAction), tonumber(amount) or 0))
        end
    end
    return oldNamecall(self, ...)
end)
setreadonly(mt, true)

print("[Crypto] Monitoring started — will print price every 30s and on every phone fire")
