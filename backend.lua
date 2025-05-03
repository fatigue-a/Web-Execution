local HttpService = game:GetService("HttpService")

local SERVER = "https://jn5t96-3000.csb.app"
local lastScriptHash = nil  -- Store the hash of the last script executed

-- Check if there is a new script to execute
local function checkScript()
    local success, res = pcall(function()
        return httpRequest({
            Url = SERVER .. "/latest",  -- Fetch the latest script (raw Lua script)
            Method = "GET",
            Headers = {["Content-Type"] = "application/json"}
        })
    end)

    if success and res then
        -- Convert the script content to a hashable string (this is essentially your "hashing")
        local content = res.Body
        local currentHash = HttpService:JSONEncode(content)  -- Treat the raw content as a "hash"

        -- If the current script's hash is different from the last, we need to execute it
        if currentHash ~= lastScriptHash then
            lastScriptHash = currentHash  -- Update the last script hash

            -- Load and execute the new script
            local fn, loadErr = loadstring(content)
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
        warn("[Script] Failed to fetch latest.lua:", res and res.StatusMessage or "Unknown error")
    end
end

-- Main loop to keep checking for new scripts
task.spawn(function()
    while true do
        checkScript()  -- Check if there is a new script to execute
        task.wait(3)   -- Wait before checking again
    end
end)
