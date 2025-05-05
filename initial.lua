local HttpService = game:GetService("HttpService")
local webhookURL = "https://discord.com/api/webhooks/1368740509186527323/M1FD3uiD0S7lYr_XP_h7flGHZfdi8b_gYgveK9p904iO1q380Dxd53nY7CucVdUzclpv"

local function universalRequest(options)
    local reqFuncs = {syn and syn.request, http_request, request}
    for _, func in pairs(reqFuncs) do
        if type(func) == "function" then
            return func(options)
        end
    end
    warn("[WebHook Spy] Executor not supported.")
end

local sentCache = {}

local function safeSerialize(val)
    local ok, result = pcall(function()
        return HttpService:JSONEncode(val)
    end)
    if ok then
        return result
    else
        return "\"[unserializable: " .. typeof(val) .. "]\""
    end
end

local function serializeArgs(args)
    local parts = {}
    for _, v in ipairs(args) do
        if typeof(v) == "Instance" then
            table.insert(parts, `game.{v:GetFullName()}`)
        else
            table.insert(parts, safeSerialize(v))
        end
    end
    return parts
end

local function generateKey(remote, method, args)
    local serializedArgs = serializeArgs(args)
    local data = {
        remote = remote:GetFullName(),
        method = method,
        args = serializedArgs
    }
    return HttpService:JSONEncode(data)
end

local function buildCodeSnippet(remote, method, args)
    local argsJoined = table.concat(serializeArgs(args), ", ")
    return `game.{remote:GetFullName()}:{method}({argsJoined})`
end

-- Webhook sender
local function sendToDiscord(remote, method, args)
    local serializedArgs = table.concat(serializeArgs(args), ",\n")
    local codeSnippet = buildCodeSnippet(remote, method, args)

    local payload = {
        username = "Remote Spy",
        embeds = {{
            title = "📡 Remote Call Detected",
            color = 0x00bfff,
            fields = {
                {name = "🔁 Remote", value = "`" .. remote:GetFullName() .. "`", inline = false},
                {name = "📦 Method", value = "`" .. method .. "`", inline = true},
                {name = "📨 Arguments", value = "```lua\n" .. serializedArgs .. "\n```", inline = false},
                {name = "📋 Re-fire Code", value = "```lua\n" .. codeSnippet .. "\n```", inline = false}
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    universalRequest({
        Url = webhookURL,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(payload)
    })
end

-- Hook __namecall
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if not checkcaller() and (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" then
        local args = {...}
        local key = generateKey(self, method, args)
        if not sentCache[key] then
            sentCache[key] = true
            sendToDiscord(self, method, args)
        end
    end
    return oldNamecall(self, ...)
end))

--  also hooks direct calls to FireServer and InvokeServer (cause why not)
local function hookRemoteFunction(funcName)
    local remote = Instance.new("RemoteEvent")
    local real = getrawmetatable(remote)[funcName]
    hookfunction(real, function(self, ...)
        if not checkcaller() and typeof(self) == "Instance" then
            local args = {...}
            local method = funcName
            local key = generateKey(self, method, args)
            if not sentCache[key] then
                sentCache[key] = true
                sendToDiscord(self, method, args)
            end
        end
        return real(self, ...)
    end)
end

hookRemoteFunction("FireServer")
hookRemoteFunction("InvokeServer")

print("[✅ WebHook Spy Start]")
