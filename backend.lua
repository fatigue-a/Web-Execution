local HttpService = game:GetService("HttpService")

local SERVER = "https://jn5t96-3000.csb.app"
local lastExecutedScript = nil  -- Keep track of the last executed script content

-- Check for new script by fetching the latest content
local function checkScript()
    local success, res = pcall(function()
        return httpRequest({
            Url = SERVER .. "/latest",  -- Fetch the latest script (raw Lua code)
            Method = "GET",
            Headers = {["Content-Type"] = "application/json"}
        })
    end)

    if success and res then
        local currentScriptContent = res.Body  -- This is the raw script content from the server

        -- Check if the current script content is different from the last executed one
        if currentScriptContent ~= lastExecutedScript then
            lastExecutedScript = currentScriptContent  -- Update the last executed script

            -- Attempt to load and execute the new script
            local fn, loadErr = loadstring(currentScriptContent)
            if fn then
                local ok, execErr = pcall(fn)
                if not ok then
                    warn("[Script] Runtime error:", execErr)
                end
            else
                warn("[Script] Load error:", loadErr)
            end
        else
            print("No new script to execute.")
        end
    else
        warn("[Script] Failed to fetch latest.lua:", res and res.StatusMessage or "unknown error")
    end
end

-- Start the polling loop
task.spawn(function()
    while true do
        checkScript()  -- Check for new script
        task.wait(3)   -- Adjust the polling interval as needed
    end
end)
