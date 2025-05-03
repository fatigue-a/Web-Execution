local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Server = "https://jn5t96-3000.csb.app" 

-- Utility function to serialize instance properties
local function serializeProperties(inst)
    local props = {}
    local properties = {
        "Name", "ClassName", "Parent", "Archivable", "Anchored", "CanCollide", "Transparency",
        "Position", "Size", "Rotation", "Velocity", "Color", "Material", "CFrame", "PrimaryPart", 
        "Orientation", "Health", "WalkSpeed", "JumpHeight", "BrickColor"
    }

    for _, prop in ipairs(properties) do
        local success, val = pcall(function() return inst[prop] end)
        if success then
            -- Serialize complex types like Color3, Vector3, and CFrame
            if typeof(val) == "Color3" then
                props[prop] = tostring(val)
            elseif typeof(val) == "Vector3" then
                props[prop] = tostring(val)
            elseif typeof(val) == "CFrame" then
                props[prop] = tostring(val)
            elseif typeof(val) == "BrickColor" then
                props[prop] = tostring(val)
            else
                props[prop] = val
            end
        end
    end
    return props
end

-- Utility function to serialize children of an instance
local function serializeChildren(inst)
    local children = {}
    for _, child in ipairs(inst:GetChildren()) do
        table.insert(children, {
            Name = child.Name,
            ClassName = child.ClassName,
            _properties = serializeProperties(child)
        })
    end
    return children
end

-- List of common instances in all Roblox games
local initialInstances = {
    "game", "game.Workspace", "game.Players", "game.Lighting", "game.ReplicatedFirst",
    "game.ReplicatedStorage", "game.StarterGui", "game.StarterPack", "game.StarterPlayer",
    "game.SoundService", "game.Chat", "game.HttpService", "game.UserInputService", 
    "game.TweenService", "game.GuiService", "game.CoreGui"
}

-- Function to send initial instance data to the server
local function sendInitialInstanceData()
    local updates = {}

    -- Collect instance data for each of the initial instances
    for _, path in ipairs(initialInstances) do
        local instance = game:FindFirstChild(path)
        if instance then
            updates[path] = serializeChildren(instance)
        else
            warn("Instance not found: " .. path)
        end
    end

    -- Ensure that there is data to send
    if next(updates) == nil then
        warn("No data to send. Updates table is empty.")
        return
    end

    -- Send the data to the server
    local json = HttpService:JSONEncode(updates)
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = Server .. "/dex_children",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json
        })
    end)

    if success then
        print("Data sent successfully!")
    else
        warn("Failed to send data:", response)
    end
end

-- Function to save the visible paths to the server
local function sendVisiblePaths()
    local paths = {}
    for _, path in ipairs(initialInstances) do
        table.insert(paths, path)
    end

    local json = HttpService:JSONEncode(paths)
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = Server .. "/visible_paths",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json
        })
    end)

    if success then
        print("Visible paths sent successfully!")
    else
        warn("Failed to send visible paths:", response)
    end
end

-- Main execution: Send the initial instance data and visible paths
sendInitialInstanceData()
sendVisiblePaths()
