local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local SERVER = "https://jn5t96-3000.csb.app"
local lastScriptHash = nil

local function getVisualPaths()
	local success, res = pcall(function()
		return request({
			Url = SERVER .. "/visual_paths",
			Method = "GET"
		})
	end)

	if success and res.Success then
		return HttpService:JSONDecode(res.Body)
	end
	return {}
end

local function serializeProperties(inst)
	local props = {}
	for _, prop in ipairs({"Name", "ClassName", "Parent", "Archivable", "Anchored", "CanCollide", "Transparency", "Position", "Size"}) do
		local ok, val = pcall(function() return inst[prop] end)
		if ok then props[prop] = tostring(val) end
	end
	return props
end

local function syncVisibleProperties()
	local paths = getVisualPaths()
	local updates = {}

	for _, path in ipairs(paths) do
		local success, instance = pcall(function() return game:FindFirstChild(path:sub(6), true) end)
		if success and instance then
			updates[path] = serializeProperties(instance)
		end
	end

	local json = HttpService:JSONEncode(updates)
	request({
		Url = SERVER .. "/dex_changes",
		Method = "POST",
		Headers = {["Content-Type"] = "application/json"},
		Body = json
	})
end

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
		warn("[Script] Failed to fetch latest.lua:", res.StatusMessage)
	end
end

task.spawn(function()
	while true do
		checkScript()
		syncVisibleProperties()
		task.wait(3)
	end
end)
