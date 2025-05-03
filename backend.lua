local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local SERVER = "https://jn5t96-3000.csb.app"
local lastScriptHash = nil

-- Utility: Serialize instance properties
local function serializeProperties(inst)
	local props = {}
	for _, prop in ipairs({
		"Name", "ClassName", "Parent", "Archivable",
		"Anchored", "CanCollide", "Transparency",
		"Position", "Size"
	}) do
		local ok, val = pcall(function() return inst[prop] end)
		if ok then
			props[prop] = tostring(val)
		end
	end
	return props
end

-- Utility: Serialize children
local function serializeChildren(inst)
	local children = {}
	for _, child in ipairs(inst:GetChildren()) do
		table.insert(children, {
			Name = child.Name,
			ClassName = child.ClassName,
			_properties = serializeProperties(child)
		})
	end
	return children
end

-- Get visible paths
local function getVisiblePaths()
	local success, res = pcall(function()
		return request({
			Url = SERVER .. "/visible_paths",
			Method = "GET"
		})
	end)

	if success and res.Success then
		return HttpService:JSONDecode(res.Body)
	end
	return {}
end

-- Push property updates
local function syncVisibleProperties()
	local paths = getVisiblePaths()
	local updates = {}

	for _, path in ipairs(paths) do
		local success, inst = pcall(function()
			return game:FindFirstChild(path:sub(6), true)
		end)

		if success and inst then
			updates[path] = serializeProperties(inst)
		end
	end

	local json = HttpService:JSONEncode(updates)
	pcall(function()
		request({
			Url = SERVER .. "/dex_changes",
			Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = json
		})
	end)
end

-- Check for new script
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

-- Handle children request polling from browser
local function listenForChildRequests()
	RunService.RenderStepped:Connect(function()
		local success, res = pcall(function()
			return request({
				Url = SERVER .. "/dex_children_poll",
				Method = "GET"
			})
		end)

		if success and res.Success and res.Body and res.Body ~= "" then
			local decoded = HttpService:JSONDecode(res.Body)
			if type(decoded) == "string" then
				local path = decoded
				local instance = game:FindFirstChild(path:sub(6), true)
				if instance then
					local children = serializeChildren(instance)
					pcall(function()
						request({
							Url = SERVER .. "/dex_children",
							Method = "POST",
							Headers = {["Content-Type"] = "application/json"},
							Body = HttpService:JSONEncode({
								path = path,
								children = children
							})
						})
					end)
				end
			end
		end
	end)
end

-- Main loop: sync props + script updates
task.spawn(function()
	while true do
		checkScript()
		syncVisibleProperties()
		task.wait(3)
	end
end)

-- Start lazy loading system
listenForChildRequests()
