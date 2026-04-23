-- ╔══════════════════════════════════════════════════════════════╗
-- ║     UNIVERSAL GAME SCANNER - WORKS ON ANY ROBLOX GAME        ║
-- ║           Scans EVERYTHING in the entire game                ║
-- ╚══════════════════════════════════════════════════════════════╝

print("╔════════════════════════════════════════════════════════════╗")
print("║   UNIVERSAL SCANNER V1.0 - INITIALIZING...                ║")
print("╚════════════════════════════════════════════════════════════╝")

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                    SERVICES                                  ║
-- ╚══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local StarterPack = game:GetService("StarterPack")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                    CONFIGURATION                             ║
-- ╚══════════════════════════════════════════════════════════════╝

local Config = {
    -- Scan Depth
    MaxDepth = 100,
    MaxObjectsPerContainer = 10000,
    
    -- Performance
    YieldEvery = 100,
    YieldTime = 0.05,
    
    -- Output
    SaveToFile = true,
    PrintResults = true,
    DetailedOutput = true,
    
    -- What to Scan
    ScanWorkspace = true,
    ScanReplicatedStorage = true,
    ScanPlayers = true,
    ScanLighting = true,
    ScanStarterGui = true,
    ScanStarterPack = true,
    ScanSoundService = true,
    ScanNilInstances = true,
    ScanCollectionTags = true,
}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                    SCAN RESULTS                              ║
-- ╚══════════════════════════════════════════════════════════════╝

local ScanResults = {
    -- Game Info
    GameInfo = {
        Name = "",
        PlaceId = 0,
        JobId = "",
        CreatorName = "",
        Players = 0,
    },
    
    -- Parts & Models
    Parts = {},
    Models = {},
    MeshParts = {},
    UnionOperations = {},
    
    -- Scripts
    LocalScripts = {},
    Scripts = {},
    ModuleScripts = {},
    
    -- Remotes
    RemoteEvents = {},
    RemoteFunctions = {},
    BindableEvents = {},
    BindableFunctions = {},
    
    -- Values
    StringValues = {},
    IntValues = {},
    NumberValues = {},
    BoolValues = {},
    ObjectValues = {},
    Vector3Values = {},
    CFrameValues = {},
    
    -- UI
    ScreenGuis = {},
    BillboardGuis = {},
    SurfaceGuis = {},
    
    -- Tools & Accessories
    Tools = {},
    Accessories = {},
    
    -- Sounds & Animations
    Sounds = {},
    Animations = {},
    
    -- Folders & Containers
    Folders = {},
    Configurations = {},
    
    -- Special Objects
    Attachments = {},
    Beams = {},
    ParticleEmitters = {},
    Lights = {},
    
    -- Collection Tags
    Tags = {},
    
    -- Nil Instances
    NilInstances = {},
    
    -- Attributes
    ObjectsWithAttributes = {},
    
    -- Stats
    TotalObjects = 0,
    TotalScanned = 0,
    ScanTime = 0,
    Errors = 0,
}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                    UTILITY FUNCTIONS                         ║
-- ╚══════════════════════════════════════════════════════════════╝

local function formatNumber(num)
    if num >= 1000000 then
        return string.format("%.2fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.2fK", num / 1000)
    end
    
    local formatted = tostring(math.floor(num))
    local result = ""
    local count = 0
    for i = #formatted, 1, -1 do
        result = formatted:sub(i, i) .. result
        count = count + 1
        if count % 3 == 0 and i > 1 then
            result = "," .. result
        end
    end
    return result
end

local function getFullPath(obj)
    local path = obj.Name
    local current = obj.Parent
    local depth = 0
    
    while current and current ~= game and depth < 50 do
        path = current.Name .. "." .. path
        current = current.Parent
        depth = depth + 1
    end
    
    if current == game then
        return "game." .. path
    end
    
    return path
end

local function safeGetCFrame(obj)
    local success, result = pcall(function()
        if obj:IsA("Model") then
            return obj:GetPivot()
        elseif obj:IsA("BasePart") then
            return obj.CFrame
        elseif obj:FindFirstChild("Position") then
            return CFrame.new(obj.Position)
        end
        return nil
    end)
    
    return success and result or nil
end

local function safeGetPosition(obj)
    local cf = safeGetCFrame(obj)
    if cf then
        return cf.Position
    end
    return nil
end

local function getDistance(obj)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local pos = safeGetPosition(obj)
        if pos then
            return (LocalPlayer.Character.HumanoidRootPart.Position - pos).Magnitude
        end
    end
    return nil
end

local function getAllAttributes(obj)
    local attrs = {}
    local success, result = pcall(function()
        return obj:GetAttributes()
    end)
    
    if success and result then
        for name, value in pairs(result) do
            attrs[name] = tostring(value)
        end
    end
    
    return attrs
end

local function createObjectData(obj)
    local data = {
        Name = obj.Name,
        ClassName = obj.ClassName,
        Path = getFullPath(obj),
    }
    
    -- Position data
    local pos = safeGetPosition(obj)
    if pos then
        data.Position = string.format("%.2f, %.2f, %.2f", pos.X, pos.Y, pos.Z)
        data.Distance = getDistance(obj)
    end
    
    -- CFrame data
    local cf = safeGetCFrame(obj)
    if cf then
        data.CFrame = string.format(
            "CFrame.new(%.2f, %.2f, %.2f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f)",
            cf.X, cf.Y, cf.Z,
            cf:GetComponents()
        )
    end
    
    -- Attributes
    local attrs = getAllAttributes(obj)
    if next(attrs) then
        data.Attributes = attrs
    end
    
    -- Special properties based on type
    pcall(function()
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            data.Type = "Remote"
        elseif obj:IsA("ModuleScript") then
            data.Type = "Module"
        elseif obj:IsA("Tool") then
            data.RequiresHandle = obj.RequiresHandle
        elseif obj:IsA("Sound") then
            data.SoundId = obj.SoundId
            data.Volume = obj.Volume
        elseif obj:IsA("Animation") then
            data.AnimationId = obj.AnimationId
        end
    end)
    
    return data
end

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                    SCANNING ENGINE                           ║
-- ╚══════════════════════════════════════════════════════════════╝

local objectCounter = 0

local function shouldYield()
    objectCounter = objectCounter + 1
    if objectCounter % Config.YieldEvery == 0 then
        task.wait(Config.YieldTime)
        return true
    end
    return false
end

local function scanObject(obj, category)
    if not obj or not obj.Parent and category ~= "NilInstances" then
        return
    end
    
    local success, err = pcall(function()
        local data = createObjectData(obj)
        
        -- Categorize by class
        local className = obj.ClassName
        
        -- Parts & Models
        if className == "Part" or className == "WedgePart" or className == "CornerWedgePart" then
            table.insert(ScanResults.Parts, data)
        elseif className == "Model" then
            table.insert(ScanResults.Models, data)
        elseif className == "MeshPart" then
            table.insert(ScanResults.MeshParts, data)
        elseif className == "UnionOperation" then
            table.insert(ScanResults.UnionOperations, data)
        
        -- Scripts
        elseif className == "LocalScript" then
            table.insert(ScanResults.LocalScripts, data)
        elseif className == "Script" then
            table.insert(ScanResults.Scripts, data)
        elseif className == "ModuleScript" then
            table.insert(ScanResults.ModuleScripts, data)
        
        -- Remotes
        elseif className == "RemoteEvent" then
            table.insert(ScanResults.RemoteEvents, data)
        elseif className == "RemoteFunction" then
            table.insert(ScanResults.RemoteFunctions, data)
        elseif className == "BindableEvent" then
            table.insert(ScanResults.BindableEvents, data)
        elseif className == "BindableFunction" then
            table.insert(ScanResults.BindableFunctions, data)
        
        -- Values
        elseif className == "StringValue" then
            data.Value = obj.Value
            table.insert(ScanResults.StringValues, data)
        elseif className == "IntValue" then
            data.Value = obj.Value
            table.insert(ScanResults.IntValues, data)
        elseif className == "NumberValue" then
            data.Value = obj.Value
            table.insert(ScanResults.NumberValues, data)
        elseif className == "BoolValue" then
            data.Value = tostring(obj.Value)
            table.insert(ScanResults.BoolValues, data)
        elseif className == "ObjectValue" then
            data.Value = obj.Value and obj.Value.Name or "nil"
            table.insert(ScanResults.ObjectValues, data)
        elseif className == "Vector3Value" then
            data.Value = tostring(obj.Value)
            table.insert(ScanResults.Vector3Values, data)
        elseif className == "CFrameValue" then
            data.Value = tostring(obj.Value)
            table.insert(ScanResults.CFrameValues, data)
        
        -- UI
        elseif className == "ScreenGui" then
            table.insert(ScanResults.ScreenGuis, data)
        elseif className == "BillboardGui" then
            table.insert(ScanResults.BillboardGuis, data)
        elseif className == "SurfaceGui" then
            table.insert(ScanResults.SurfaceGuis, data)
        
        -- Tools & Accessories
        elseif className == "Tool" then
            table.insert(ScanResults.Tools, data)
        elseif className == "Accessory" then
            table.insert(ScanResults.Accessories, data)
        
        -- Sounds & Animations
        elseif className == "Sound" then
            table.insert(ScanResults.Sounds, data)
        elseif className == "Animation" then
            table.insert(ScanResults.Animations, data)
        
        -- Folders
        elseif className == "Folder" then
            table.insert(ScanResults.Folders, data)
        elseif className == "Configuration" then
            table.insert(ScanResults.Configurations, data)
        
        -- Special Objects
        elseif className == "Attachment" then
            table.insert(ScanResults.Attachments, data)
        elseif className == "Beam" then
            table.insert(ScanResults.Beams, data)
        elseif className == "ParticleEmitter" then
            table.insert(ScanResults.ParticleEmitters, data)
        elseif className:find("Light") then
            table.insert(ScanResults.Lights, data)
        end
        
        -- Check for attributes
        local attrs = getAllAttributes(obj)
        if next(attrs) then
            table.insert(ScanResults.ObjectsWithAttributes, data)
        end
        
        ScanResults.TotalScanned = ScanResults.TotalScanned + 1
    end)
    
    if not success then
        ScanResults.Errors = ScanResults.Errors + 1
    end
    
    shouldYield()
end

local function recursiveScan(container, depth)
    if depth > Config.MaxDepth then
        return
    end
    
    local success, children = pcall(function()
        return container:GetChildren()
    end)
    
    if not success then
        return
    end
    
    for _, child in pairs(children) do
        scanObject(child)
        
        -- Recursively scan children
        if child:IsA("Folder") or child:IsA("Model") or child:IsA("Configuration") then
            recursiveScan(child, depth + 1)
        end
    end
end

local function scanContainer(container, name)
    if not Config["Scan" .. name] then
        return
    end
    
    print(string.format("[Scanner] Scanning %s...", name))
    
    local startCount = ScanResults.TotalScanned
    recursiveScan(container, 0)
    local endCount = ScanResults.TotalScanned
    
    print(string.format("[Scanner] ✓ %s complete - Found %s objects", 
        name, formatNumber(endCount - startCount)))
end

local function scanNilInstances()
    if not Config.ScanNilInstances then
        return
    end
    
    print("[Scanner] Scanning Nil Instances...")
    
    local startCount = ScanResults.TotalScanned
    local nilObjs = {}
    
    pcall(function()
        for _, obj in pairs(getnilinstances()) do
            table.insert(nilObjs, obj)
        end
    end)
    
    for _, obj in pairs(nilObjs) do
        local data = createObjectData(obj)
        data.IsNil = true
        table.insert(ScanResults.NilInstances, data)
        ScanResults.TotalScanned = ScanResults.TotalScanned + 1
        shouldYield()
    end
    
    local endCount = ScanResults.TotalScanned
    print(string.format("[Scanner] ✓ Nil Instances complete - Found %s objects", 
        formatNumber(endCount - startCount)))
end

local function scanCollectionTags()
    if not Config.ScanCollectionTags then
        return
    end
    
    print("[Scanner] Scanning Collection Tags...")
    
    local tags = CollectionService:GetAllTags()
    
    for _, tag in pairs(tags) do
        local tagged = CollectionService:GetTagged(tag)
        
        if #tagged > 0 then
            local tagData = {
                TagName = tag,
                Count = #tagged,
                Objects = {}
            }
            
            for _, obj in pairs(tagged) do
                local data = createObjectData(obj)
                table.insert(tagData.Objects, data)
                shouldYield()
            end
            
            table.insert(ScanResults.Tags, tagData)
        end
    end
    
    print(string.format("[Scanner] ✓ Collection Tags complete - Found %d tags", #tags))
end

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                    GAME INFO SCANNER                         ║
-- ╚══════════════════════════════════════════════════════════════╝

local function scanGameInfo()
    print("[Scanner] Gathering game information...")
    
    -- Basic Info
    ScanResults.GameInfo.PlaceId = game.PlaceId
    ScanResults.GameInfo.JobId = game.JobId
    ScanResults.GameInfo.Players = #Players:GetPlayers()
    
    -- Get game name
    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    
    if success and info then
        ScanResults.GameInfo.Name = info.Name
        ScanResults.GameInfo.Description = info.Description
        ScanResults.GameInfo.CreatorName = info.Creator.Name
    end
    
    print(string.format("[Scanner] ✓ Game: %s (PlaceId: %d)", 
        ScanResults.GameInfo.Name, ScanResults.GameInfo.PlaceId))
end

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                    OUTPUT FUNCTIONS                          ║
-- ╚══════════════════════════════════════════════════════════════╝

local function generateReport()
    local report = {
        "═══════════════════════════════════════════════════════════",
        "              UNIVERSAL SCANNER - SCAN RESULTS              ",
        "═══════════════════════════════════════════════════════════",
        "",
        string.format("Game: %s", ScanResults.GameInfo.Name),
        string.format("Place ID: %d", ScanResults.GameInfo.PlaceId),
        string.format("Creator: %s", ScanResults.GameInfo.CreatorName or "Unknown"),
        string.format("Players: %d", ScanResults.GameInfo.Players),
        "",
        "═══════════════════════════════════════════════════════════",
        "                      SCAN STATISTICS                       ",
        "═══════════════════════════════════════════════════════════",
        "",
        string.format("Total Objects Scanned: %s", formatNumber(ScanResults.TotalScanned)),
        string.format("Scan Time: %.2f seconds", ScanResults.ScanTime),
        string.format("Errors: %d", ScanResults.Errors),
        "",
        "═══════════════════════════════════════════════════════════",
        "                     OBJECT BREAKDOWN                       ",
        "═══════════════════════════════════════════════════════════",
        "",
        "📦 PARTS & MODELS:",
        string.format("  Parts: %s", formatNumber(#ScanResults.Parts)),
        string.format("  Models: %s", formatNumber(#ScanResults.Models)),
        string.format("  MeshParts: %s", formatNumber(#ScanResults.MeshParts)),
        string.format("  UnionOperations: %s", formatNumber(#ScanResults.UnionOperations)),
        "",
        "📜 SCRIPTS:",
        string.format("  LocalScripts: %s", formatNumber(#ScanResults.LocalScripts)),
        string.format("  Scripts: %s", formatNumber(#ScanResults.Scripts)),
        string.format("  ModuleScripts: %s", formatNumber(#ScanResults.ModuleScripts)),
        "",
        "📡 REMOTES:",
        string.format("  RemoteEvents: %s", formatNumber(#ScanResults.RemoteEvents)),
        string.format("  RemoteFunctions: %s", formatNumber(#ScanResults.RemoteFunctions)),
        string.format("  BindableEvents: %s", formatNumber(#ScanResults.BindableEvents)),
        string.format("  BindableFunctions: %s", formatNumber(#ScanResults.BindableFunctions)),
        "",
        "💾 VALUES:",
        string.format("  StringValues: %s", formatNumber(#ScanResults.StringValues)),
        string.format("  IntValues: %s", formatNumber(#ScanResults.IntValues)),
        string.format("  NumberValues: %s", formatNumber(#ScanResults.NumberValues)),
        string.format("  BoolValues: %s", formatNumber(#ScanResults.BoolValues)),
        string.format("  ObjectValues: %s", formatNumber(#ScanResults.ObjectValues)),
        "",
        "🖥️ UI ELEMENTS:",
        string.format("  ScreenGuis: %s", formatNumber(#ScanResults.ScreenGuis)),
        string.format("  BillboardGuis: %s", formatNumber(#ScanResults.BillboardGuis)),
        string.format("  SurfaceGuis: %s", formatNumber(#ScanResults.SurfaceGuis)),
        "",
        "🔧 TOOLS & ACCESSORIES:",
        string.format("  Tools: %s", formatNumber(#ScanResults.Tools)),
        string.format("  Accessories: %s", formatNumber(#ScanResults.Accessories)),
        "",
        "🔊 AUDIO & ANIMATIONS:",
        string.format("  Sounds: %s", formatNumber(#ScanResults.Sounds)),
        string.format("  Animations: %s", formatNumber(#ScanResults.Animations)),
        "",
        "📁 CONTAINERS:",
        string.format("  Folders: %s", formatNumber(#ScanResults.Folders)),
        string.format("  Configurations: %s", formatNumber(#ScanResults.Configurations)),
        "",
        "✨ SPECIAL OBJECTS:",
        string.format("  Attachments: %s", formatNumber(#ScanResults.Attachments)),
        string.format("  Beams: %s", formatNumber(#ScanResults.Beams)),
        string.format("  ParticleEmitters: %s", formatNumber(#ScanResults.ParticleEmitters)),
        string.format("  Lights: %s", formatNumber(#ScanResults.Lights)),
        "",
        "🏷️ COLLECTION TAGS:",
        string.format("  Total Tags: %s", formatNumber(#ScanResults.Tags)),
        "",
        "👻 NIL INSTANCES:",
        string.format("  Total: %s", formatNumber(#ScanResults.NilInstances)),
        "",
        "🔖 OBJECTS WITH ATTRIBUTES:",
        string.format("  Total: %s", formatNumber(#ScanResults.ObjectsWithAttributes)),
        "",
        "═══════════════════════════════════════════════════════════",
    }
    
    return table.concat(report, "\n")
end

local function saveToFile()
    if not Config.SaveToFile then
        return
    end
    
    print("[Scanner] Saving results to file...")
    
    local timestamp = os.time()
    local filename = string.format("UniversalScan_%d_%d.json", game.PlaceId, timestamp)
    
    local success, result = pcall(function()
        local json = HttpService:JSONEncode(ScanResults)
        writefile(filename, json)
        return filename
    end)
    
    if success then
        print(string.format("[Scanner] ✓ Saved to: %s", result))
    else
        warn("[Scanner] ✗ Failed to save file:", result)
    end
    
    -- Also save a readable text report
    local reportFilename = string.format("UniversalScan_%d_%d.txt", game.PlaceId, timestamp)
    
    success, result = pcall(function()
        local report = generateReport()
        
        -- Add detailed listings
        report = report .. "\n\n" .. "═══════════════════════════════════════════════════════════\n"
        report = report .. "                    DETAILED LISTINGS                       \n"
        report = report .. "═══════════════════════════════════════════════════════════\n\n"
        
        -- Remote Events
        if #ScanResults.RemoteEvents > 0 then
            report = report .. "📡 REMOTE EVENTS:\n"
            for i, remote in ipairs(ScanResults.RemoteEvents) do
                report = report .. string.format("  %d. %s\n     Path: %s\n", i, remote.Name, remote.Path)
            end
            report = report .. "\n"
        end
        
        -- Remote Functions
        if #ScanResults.RemoteFunctions > 0 then
            report = report .. "📡 REMOTE FUNCTIONS:\n"
            for i, remote in ipairs(ScanResults.RemoteFunctions) do
                report = report .. string.format("  %d. %s\n     Path: %s\n", i, remote.Name, remote.Path)
            end
            report = report .. "\n"
        end
        
        -- Collection Tags
        if #ScanResults.Tags > 0 then
            report = report .. "🏷️ COLLECTION TAGS:\n"
            for i, tag in ipairs(ScanResults.Tags) do
                report = report .. string.format("  %d. %s (Count: %d)\n", i, tag.TagName, tag.Count)
                for j, obj in ipairs(tag.Objects) do
                    if j <= 10 then -- Limit to 10 per tag
                        report = report .. string.format("     - %s (%s)\n", obj.Name, obj.ClassName)
                    end
                end
                if #tag.Objects > 10 then
                    report = report .. string.format("     ... and %d more\n", #tag.Objects - 10)
                end
            end
            report = report .. "\n"
        end
        
        -- Objects with Attributes
        if #ScanResults.ObjectsWithAttributes > 0 then
            report = report .. "🔖 OBJECTS WITH ATTRIBUTES (First 50):\n"
            for i, obj in ipairs(ScanResults.ObjectsWithAttributes) do
                if i <= 50 then
                    report = report .. string.format("  %d. %s (%s)\n", i, obj.Name, obj.ClassName)
                    report = report .. string.format("     Path: %s\n", obj.Path)
                    if obj.Attributes then
                        for attr, value in pairs(obj.Attributes) do
                            report = report .. string.format("     %s = %s\n", attr, value)
                        end
                    end
                end
            end
            report = report .. "\n"
        end
        
        writefile(reportFilename, report)
        return reportFilename
    end)
    
    if success then
        print(string.format("[Scanner] ✓ Report saved to: %s", result))
    else
        warn("[Scanner] ✗ Failed to save report:", result)
    end
end

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                    MAIN SCAN FUNCTION                        ║
-- ╚══════════════════════════════════════════════════════════════╝

local function startScan()
    local startTime = tick()
    
    print("╔════════════════════════════════════════════════════════════╗")
    print("║              STARTING UNIVERSAL SCAN...                   ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print()
    
    -- Scan game info
    scanGameInfo()
    print()
    
    -- Scan containers
    scanContainer(Workspace, "Workspace")
    scanContainer(ReplicatedStorage, "ReplicatedStorage")
    scanContainer(Players, "Players")
    scanContainer(Lighting, "Lighting")
    scanContainer(StarterGui, "StarterGui")
    scanContainer(StarterPack, "StarterPack")
    scanContainer(SoundService, "SoundService")
    
    print()
    
    -- Scan special
    scanNilInstances()
    scanCollectionTags()
    
    -- Calculate stats
    ScanResults.ScanTime = tick() - startTime
    ScanResults.TotalObjects = ScanResults.TotalScanned
    
    print()
    print("╔════════════════════════════════════════════════════════════╗")
    print("║                  SCAN COMPLETE!                           ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print()
    
    -- Print results
    if Config.PrintResults then
        print(generateReport())
    end
    
    -- Save to file
    saveToFile()
    
    print()
    print("╔════════════════════════════════════════════════════════════╗")
    print("║              SCAN FINISHED SUCCESSFULLY                   ║")
    print(string.format("║  Total Objects: %-42s ║", formatNumber(ScanResults.TotalScanned)))
    print(string.format("║  Scan Time: %-46s ║", string.format("%.2f seconds", ScanResults.ScanTime)))
    print("╚════════════════════════════════════════════════════════════╝")
end

-- ╔══════════════════════════════════════════════════════════════╗
-- ║                    START SCANNING                            ║
-- ╚══════════════════════════════════════════════════════════════╝

startScan()
