local HttpService = game:GetService("HttpService")
local httpRequest = (syn and syn.request)
    or (http and http.request)
    or (fluxus and fluxus.request)
    or request
    or http_request

if not httpRequest then
    warn("❌ No supported HTTP request method found.")
    return
end

-- Utility: Serialize instance properties
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

-- Utility: Serialize children
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

-- Send the regular instances (e.g., Workspace, Players) to the server
local function sendInitialInstanceData()
    local initialInstances = {
        "Workspace", "Players", "Lighting", "ReplicatedFirst",
        "ReplicatedStorage", "StarterGui", "StarterPack", "StarterPlayer",
        "SoundService", "Chat", "HttpService", "UserInputService", 
        "TweenService", "GuiService", "CoreGui"
    }
    local updates = {}

    for _, path in ipairs(initialInstances) do
        local instance = game:FindFirstChild(path)
        if instance then
            updates[path] = serializeChildren(instance)
        end
    end

    -- Send initial instance data
    local json = HttpService:JSONEncode(updates)
    pcall(function()
        httpRequest({
            Url = "https://jn5t96-3000.csb.app/dex_children",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json
        })
    end)
end

-- Call the function to populate the initial data
sendInitialInstanceData()
