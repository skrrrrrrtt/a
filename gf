-- Clean Farm | Street Life Remastered
-- Extracted logic from BypassHub luac

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local VIM          = game:GetService("VirtualInputManager")

local LP           = Players.LocalPlayer
local char         = LP.Character or LP.CharacterAdded:Wait()
local hrp          = char:WaitForChild("HumanoidRootPart")
local hum          = char:WaitForChild("Humanoid")

-- ===================== CONFIG =====================
local CLEAN_POS    = Vector3.new(0, 0, 0)   -- <-- set your clean spot CFrame pos
local HOLD_TIME    = 3.5                     -- seconds to hold E
local WAIT_BETWEEN = 1.5                     -- seconds between each cycle
local USE_TWEEN    = true                    -- true = smooth walk, false = teleport
local TWEEN_SPEED  = 0.08                    -- lower = faster tween
-- ==================================================

local running = false
local tween   = nil

local function tweenTo(pos)
    local dist = (hrp.Position - pos).Magnitude
    local info = TweenInfo.new(dist * TWEEN_SPEED, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    tween = TweenService:Create(hrp, info, { CFrame = CFrame.new(pos) })
    tween:Play()
    tween.Completed:Wait()
end

local function holdE(duration)
    VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
    task.wait(duration)
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function equipFist()
    -- unequip any tool so interact prompt triggers properly
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        hum:UnequipTools()
        task.wait(0.1)
    end
end

local function farmLoop()
    while running do
        char = LP.Character
        if not char then task.wait(1) continue end

        hrp = char:FindFirstChild("HumanoidRootPart")
        hum = char:FindFirstChild("Humanoid")

        if not hrp or not hum then task.wait(1) continue end
        if hum.Health <= 0 then task.wait(3) continue end

        equipFist()

        if USE_TWEEN then
            tweenTo(CLEAN_POS)
        else
            hrp.CFrame = CFrame.new(CLEAN_POS)
        end

        holdE(HOLD_TIME)
        task.wait(WAIT_BETWEEN)
    end
end

-- ============ KEYBIND: P to toggle ============
local UIS = game:GetService("UserInputService")

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.P then
        running = not running
        if running then
            print("[CleanFarm] Started")
            task.spawn(farmLoop)
        else
            running = false
            if tween then tween:Cancel() end
            print("[CleanFarm] Stopped")
        end
    end
end)

print("[CleanFarm] Loaded — Press P to toggle")
