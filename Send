local HttpService = game:GetService("HttpService")

local SERVER = "https://jn5t96-3000.csb.app"
local lastScriptHash = nil

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

task.spawn(function()
    while true do
        checkScript()
        task.wait(3) -- Repeat every 3 seconds
    end
end)
