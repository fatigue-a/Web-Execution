local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local SERVER = "https://jn5t96-3000.csb.app"
local lastScriptHash = nil

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

-- Get visible paths from server
local function getVisiblePaths()
    local success, res = pcall(function()
        return HttpService:GetAsync(SERVER .. "/visible_paths")
    end)

    if success then
        return HttpService:JSONDecode(res)
    else
        return {}
    end
end

-- Push property updates to server
local function syncVisibleProperties()
    local paths = getVisiblePaths()
    local updates = {}

    for _, path in ipairs(paths) do
        local success, inst = pcall(function()
            return game:FindFirstChild(path:sub(6), true)
        end)

        if success and inst then
            updates[path] = serializeProperties(inst)
        end
    end

    local json = HttpService:JSONEncode(updates)
    pcall(function()
        HttpService:PostAsync(SERVER .. "/dex_changes", json, Enum.HttpContentType.ApplicationJson)
    end)
end

-- Check for new script on server
local function checkScript()
    local success, res = pcall(function()
        return HttpService:GetAsync(SERVER .. "/latest")
    end)

    if success then
        local content = res
        local currentHash = HttpService:JSONEncode(content)

        if currentHash ~= lastScriptHash then
            lastScriptHash = currentHash
            local fn, err = loadstring(content)
            if fn then
                local ok, execErr = pcall(fn)
                if not ok then
                    warn("[Script] Runtime error:", execErr)
                end
            else
                warn("[Script] Load error:", err)
            end
        end
    else
        warn("[Script] Failed to fetch latest.lua:", res)
    end
end

-- Handle children request polling from browser
local function listenForChildRequests()
    RunService.RenderStepped:Connect(function()
        local success, res = pcall(function()
            return HttpService:GetAsync(SERVER .. "/dex_children_poll")
        end)

        if success and res ~= "" then
            local decoded = HttpService:JSONDecode(res)
            if typeof(decoded) == "string" then
                local path = decoded
                local instance = game:FindFirstChild(path:sub(6), true)
                if instance then
                    local children = serializeChildren(instance)
                    pcall(function()
                        HttpService:PostAsync(SERVER .. "/dex_children", HttpService:JSONEncode({
                            path = path,
                            children = children
                        }), Enum.HttpContentType.ApplicationJson)
                    end)
                end
            end
        end
    end)
end

-- Main loop: sync properties and script updates
task.spawn(function()
    while true do
        checkScript()
        syncVisibleProperties()
        task.wait(3)
    end
end)

-- Start lazy loading system
listenForChildRequests()
