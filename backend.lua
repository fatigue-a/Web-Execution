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

-- Try each method for making an HTTP request
local httpRequest = (syn and syn.request)
    or (http and http.request)
    or (fluxus and fluxus.request)
    or request
    or http_request

if not httpRequest then
    warn("❌ No supported HTTP request method found.")
    return
end

-- Send the regular instances (e.g., game, Workspace) to the server
local function sendInitialInstanceData()
    local initialInstances = {
        "game", "game.Workspace", "game.Players", "game.Lighting", "game.ReplicatedFirst",
        "game.ReplicatedStorage", "game.StarterGui", "game.StarterPack", "game.StarterPlayer",
        "game.SoundService", "game.Chat", "game.HttpService", "game.UserInputService", 
        "game.TweenService", "game.GuiService", "game.CoreGui"
    }  -- List the initial instances you want to send
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
            Url = SERVER .. "/dex_children",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json
        })
    end)
end

-- Get visible paths
local function getVisiblePaths()
    local res, err = pcall(function()
        return httpRequest({
            Url = SERVER .. "/visible_paths",
            Method = "GET",
            Headers = {["Content-Type"] = "application/json"}
        })
    end)
    
    if res and err and err.Body then
        return HttpService:JSONDecode(err.Body)
    else
        warn("[Error] Failed to get visible paths:", err)
        return {}
    end
end

-- Push property updates
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
        httpRequest({
            Url = SERVER .. "/dex_changes",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json
        })
    end)
end

-- Check for new script
local function checkScript()
    local res, err = pcall(function()
        return httpRequest({
            Url = SERVER .. "/latest",
            Method = "GET",
            Headers = {["Content-Type"] = "application/json"}
        })
    end)

    if res and err then
        local content = err.Body
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
        warn("[Script] Failed to fetch latest.lua:", err)
    end
end

-- Handle children request polling from browser
local lastPollTime = 0
local pollInterval = 5  -- Adjust this for a reasonable delay in polling (in seconds)

local function listenForChildRequests()
    RunService.RenderStepped:Connect(function()
        local currentTime = tick()
        if currentTime - lastPollTime >= pollInterval then  -- Only poll at set intervals
            local res, err = pcall(function()
                return httpRequest({
                    Url = SERVER .. "/dex_children_poll",
                    Method = "GET",
                    Headers = {["Content-Type"] = "application/json"}
                })
            end)

            if res then
                -- Check if the response body is not empty
                if err and err.Body and err.Body ~= "" then
                    local decoded, decodeErr = pcall(function() return HttpService:JSONDecode(err.Body) end)
                    if decoded then
                        if type(decoded) == "string" then
                            local path = decoded
                            local instance = game:FindFirstChild(path:sub(6), true)
                            if instance then
                                local children = serializeChildren(instance)
                                pcall(function()
                                    httpRequest({
                                        Url = SERVER .. "/dex_children",
                                        Method = "POST",
                                        Headers = {["Content-Type"] = "application/json"},
                                        Body = HttpService:JSONEncode({
                                            path = path,
                                            children = children
                                        })
                                    })
                                end)
                            end
                        else
                            warn("[Error] Unexpected response format from /dex_children_poll:", err.Body)
                        end
                    else
                        warn("[Error] Failed to decode JSON response:", decodeErr)
                    end
                else
                    warn("[Error] Empty or invalid response body:", err.Body)
                end
            else
                warn("[Error] Failed to poll for children:", err)
            end
            lastPollTime = currentTime
        end
    end)
end

-- Main loop: sync props + script updates
task.spawn(function()
    while true do
        checkScript()
        syncVisibleProperties()
        task.wait(3)
    end
end)

-- Start lazy loading system
listenForChildRequests()

-- Send initial instance data (regular instances) when script starts
sendInitialInstanceData()
