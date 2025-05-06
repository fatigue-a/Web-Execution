local HttpService = game:GetService("HttpService")

local webhookURL = "https://discord.com/api/webhooks/1368740509186527323/M1FD3uiD0S7lYr_XP_h7flGHZfdi8b_gYgveK9p904iO1q380Dxd53nY7CucVdUzclpv"

local HttpRequestMethods = {
    syn = syn and syn.request,
    http = http and http.request,
    fluxus = fluxus and fluxus.request,
    krnl = request,
    default = http_request
}

local httpRequest = HttpRequestMethods[
    syn and "syn"
    or http and "http"
    or fluxus and "fluxus"
    or request and "krnl"
    or "default"
]

if not httpRequest then
    warn("[❌ WebHookSpy] Your executor is not supported :(.")
    return
end

local sentCache = {} -- prevent ratelimit by Caching the remote

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
    return "game." .. remote:GetFullName() .. ":" .. method .. "(" .. table.concat(serializeArgs(args), ", ") .. ")"
end

local function makeKey(remote, method, args)
    return remote:GetFullName() .. method .. HttpService:JSONEncode(serializeArgs(args))
end

local hook
hook = hookmetamethod(game, "__namecall", newcclosure(function(Self, ...)
    local Args = {...}
    if not checkcaller() then
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer") and typeof(Self) == "Instance" then
            local key = makeKey(Self, method, Args)
            if sentCache[key] then return hook(Self, ...) end
            sentCache[key] = true

            local codeSnippet = buildCodeSnippet(Self, method, Args)

            local payload = {
                username = "Remote Spy",
                embeds = {{
                    title = "📡 Remote Call Detected",
                    color = 0x00bfff,
                    fields = {
                        {name = "🔁 Remote", value = "`" .. Self:GetFullName() .. "`", inline = false},
                        {name = "📦 Method", value = "`" .. method .. "`", inline = true},
                        {name = "📨 Arguments", value = "```lua\n" .. table.concat(serializeArgs(Args), ",\n") .. "\n```", inline = false},
                        {name = "📋 Re-fire Code", value = "```lua\n" .. codeSnippet .. "\n```", inline = false}
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }}
            }

            httpRequest({
                Url = webhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(payload)
            })
        end
    end
    return hook(Self, ...)
end))

print("[✅ Webhook Spy Enabled]")
