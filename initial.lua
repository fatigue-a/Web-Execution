local HttpService = game:GetService("HttpService")
local webhookURL = "https://discord.com/api/webhooks/your_webhook_url"

local function universalRequest(options)
    local funcs = {syn and syn.request, http_request, request}
    for _, f in ipairs(funcs) do
        if type(f) == "function" then
            return f(options)
        end
    end
    warn("[WebHook Spy] Executor not supported.")
end

local function safeSerialize(val)
    local ok, result = pcall(function()
        return HttpService:JSONEncode(val)
    end)
    return ok and result or "\"[unserializable: " .. typeof(val) .. "]\""
end

local function serializeArgs(args)
    local parts = {}
    for _, v in ipairs(args) do
        if typeof(v) == "Instance" then
            table.insert(parts, "game." .. v:GetFullName())
        else
            table.insert(parts, safeSerialize(v))
        end
    end
    return parts
end

local function buildCodeSnippet(remote, method, args)
    local argsJoined = table.concat(serializeArgs(args), ", ")
    return "game." .. remote:GetFullName() .. ":" .. method .. "(" .. argsJoined .. ")"
end

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

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if not checkcaller() and (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" then
        local args = {...}
        task.spawn(function()
            pcall(function()
                sendToDiscord(self, method, args)
            end)
        end)
    end
    return oldNamecall(self, ...)
end))

print("[✅ WebHook Spy Started]")
