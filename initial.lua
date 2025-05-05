local HttpService = game:GetService("HttpService")
local webhookURL = "https://discord.com/api/webhooks/1368740509186527323/M1FD3uiD0S7lYr_XP_h7flGHZfdi8b_gYgveK9p904iO1q380Dxd53nY7CucVdUzclpv"

local function universalRequest(options)
    local funcs = {syn and syn.request, http_request, request}
    for _, f in ipairs(funcs) do
        if type(f) == "function" then
            return f(options)
        end
    end
end

local function safeSerialize(v)
    local success, result = pcall(function()
        return HttpService:JSONEncode(v)
    end)
    return success and result or "\"[unserializable: " .. typeof(v) .. "]\""
end

local function serializeArgs(args)
    local out = {}
    for _, arg in ipairs(args) do
        if typeof(arg) == "Instance" then
            table.insert(out, `game.{arg:GetFullName()}`)
        else
            table.insert(out, safeSerialize(arg))
        end
    end
    return out
end

local function sendToDiscord(remote, method, args)
    local fields = {
        {name = "🔁 Remote", value = "`" .. remote:GetFullName() .. "`", inline = false},
        {name = "📦 Method", value = "`" .. method .. "`", inline = true},
        {name = "📨 Arguments", value = "```lua\n" .. table.concat(serializeArgs(args), ",\n") .. "\n```", inline = false},
        {name = "📋 Code", value = "```lua\ngame." .. remote:GetFullName() .. ":" .. method .. "(" .. table.concat(serializeArgs(args), ", ") .. ")```", inline = false}
    }

    local payload = {
        username = "Remote Spy",
        embeds = {{
            title = "📡 Remote Call",
            color = 0x00bfff,
            fields = fields,
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

-- __namecall hook
local old
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    if not checkcaller() then
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" then
            local args = {...}
            task.spawn(function()
                pcall(function()
                    sendToDiscord(self, method, args)
                end)
            end)
        end
    end
    return old(self, ...)
end))

print("[✅ WebHook Spy Enabled]")
