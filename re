--[[
  PS99 Stat Tracker - reporter script
  ------------------------------------
  Run this inside your Roblox executor on EACH account (main + every bot).
  It reads your gems and pet inventory and POSTs them to your dashboard
  every 30 seconds so the web tracker stays live.

  SETUP (do this for every account):
  1. Set ACCOUNT_NAME below to something unique per account, e.g. "MainAccount",
     "Bot1", "Bot2", etc. This is how the dashboard tells accounts apart.
  2. Set API_KEY to the shared key you configured as a secret on the server
     (ask the dashboard owner / check the Setup panel in the web app).
  3. Set API_URL to your dashboard's domain + "/api/accounts/report".
     - While testing in the Replit workspace, this is your dev domain, e.g.
       "https://<your-repl-domain>.replit.dev/api/accounts/report"
     - Once you publish the app, switch this to your production domain.
  4. Fill in the two TODO sections below with the real paths PS99 uses for
     gems and pet inventory in YOUR game version — these vary and cannot be
     guessed generically. Use your executor's console / a game explorer to
     find them (commonly under player.leaderstats, or a ReplicatedStorage /
     DataService remote you can invoke).
]]

local ACCOUNT_NAME = "MainAccount"
local API_KEY = "47162f38f956e2a5f055283ea96c99d029edd9d2ff6e308f"
local API_URL = "https://53adef1e-a9d6-4132-89e1-a6af476a600c-00-16vutta6b5wv5.pike.replit.dev/api/accounts/report"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local function getGems()
  local player = Players.LocalPlayer
  -- TODO: replace with PS99's actual gem leaderstat path, e.g.:
  -- return player.leaderstats.Gems.Value
  local leaderstats = player:FindFirstChild("leaderstats")
  local gemsStat = leaderstats and leaderstats:FindFirstChild("Gems")
  return gemsStat and gemsStat.Value or 0
end

local function getPets()
  local pets = {}
  -- TODO: replace with real iteration over the player's pet inventory.
  -- Each entry must look like this (rarity/variant must match one of the
  -- allowed values in the dashboard):
  --
  -- table.insert(pets, {
  --   petId = "123456",
  --   name = "Meteor",
  --   rarity = "Huge", -- Common | Uncommon | Rare | Epic | Legendary | Huge | Titanic
  --   level = 5,
  --   variant = "Golden", -- Normal | Golden | Rainbow | Diamond
  --   enchants = { "Bubbler" },
  --   quantity = 2,
  --   icon = nil, -- optional thumbnail URL
  -- })
  return pets
end

local function sendReport()
  local payload = HttpService:JSONEncode({
    accountName = ACCOUNT_NAME,
    gems = getGems(),
    pets = getPets(),
  })

  local httpRequest = (syn and syn.request) or (http and http.request) or request or http_request

  if not httpRequest then
    warn("[PS99 Tracker] No HTTP request function found for this executor.")
    return
  end

  local ok, response = pcall(function()
    return httpRequest({
      Url = API_URL,
      Method = "POST",
      Headers = {
        ["Content-Type"] = "application/json",
        ["X-API-Key"] = API_KEY,
      },
      Body = payload,
    })
  end)

  if not ok then
    warn("[PS99 Tracker] Report failed: " .. tostring(response))
  elseif response and response.StatusCode and response.StatusCode ~= 200 then
    warn("[PS99 Tracker] Server rejected report, status " .. tostring(response.StatusCode) .. ": " .. tostring(response.Body))
  else
    print("[PS99 Tracker] Report sent for " .. ACCOUNT_NAME)
  end
end

sendReport()
while true do
  task.wait(30)
  sendReport()
end
