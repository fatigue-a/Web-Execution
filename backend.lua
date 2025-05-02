local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local SERVER = "https://jn5t96-3000.csb.app"
local lastScriptHash = nil
local lastProperties = {}
local uploadCooldown = 3

-- Services to include
local mainServices = {
	"Workspace", "Players", "Lighting", "ReplicatedStorage", "ReplicatedFirst",
	"ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer",
	"SoundService", "Chat", "Teams", "LocalizationService", "TestService", "RunService",
	"ScriptContext", "HttpService"
}

-- Watched properties
local propertyNames = {
	"Name", "ClassName", "Position", "Orientation", "Rotation", "CFrame",
	"Size", "Anchored", "CanCollide", "Transparency", "BrickColor", "Material",
	"Color", "Reflectance", "TopSurface", "BottomSurface", "SurfaceType",
	"Text", "TextColor3", "TextSize", "Font", "Visible", "ZIndex",
	"Image", "ImageTransparency", "ImageColor3",
	"SoundId", "PlaybackSpeed", "Looped", "Playing", "Volume",
	"Health", "MaxHealth", "Team", "TeamColor",
	"CameraSubject", "CameraType", "FieldOfView",
	"BackgroundColor3", "BorderSizePixel", "BorderColor3", "TextStrokeColor3",
	"TextScaled", "TextWrapped", "TextXAlignment", "TextYAlignment",
	"AnchorPoint", "SizeConstraint", "LayoutOrder",
}

local function formatValue(val)
	local t = typeof(val)
	if t == "Color3" then
		return { r = val.R, g = val.G, b = val.B }
	elseif t == "Vector3" then
		return { x = val.X, y = val.Y, z = val.Z }
	elseif t == "CFrame" then
		return { x = val.X, y = val.Y, z = val.Z }
	elseif t == "UDim2" then
		return {
			xScale = val.X.Scale, xOffset = val.X.Offset,
			yScale = val.Y.Scale, yOffset = val.Y.Offset
		}
	elseif t == "BrickColor" or t == "EnumItem" then
		return tostring(val)
	elseif t == "boolean" or t == "number" or t == "string" then
		return val
	end
	return nil
end

local function getProperties(inst)
	local props = {}
	for _, prop in ipairs(propertyNames) do
		local ok, val = pcall(function() return inst[prop] end)
		if ok and val ~= nil then
			local safe = formatValue(val)
			if safe ~= nil then
				props[prop] = safe
			end
		end
	end
	return props
end

local function getPath(instance)
	local path = {}
	while instance and instance ~= game do
		table.insert(path, 1, instance.Name)
		instance = instance.Parent
	end
	return "game." .. table.concat(path, ".")
end

-- Live change detection
local function trackChanges()
	local changes = {}
	for _, serviceName in ipairs(mainServices) do
		local ok, service = pcall(game.GetService, game, serviceName)
		if ok and service then
			for _, descendant in ipairs(service:GetDescendants()) do
				local path = getPath(descendant)
				local props = getProperties(descendant)
				local last = lastProperties[path]
				local modified = {}

				if not last then
					lastProperties[path] = props
					modified = props
				else
					for k, v in pairs(props) do
						if HttpService:JSONEncode(v) ~= HttpService:JSONEncode(last[k]) then
							modified[k] = v
						end
					end
					if next(modified) then
						lastProperties[path] = props
					end
				end

				if next(modified) then
					table.insert(changes, {
						path = path,
						class = descendant.ClassName,
						properties = modified
					})
				end
			end
		end
	end

	if #changes > 0 then
		local success, res = pcall(function()
			return request({
				Url = SERVER .. "/dex_changes",
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode(changes)
			})
		end)
		if not success or not res.Success then
			warn("[Dex] Change upload failed")
		end
	end
end

-- Script polling
local function checkScript()
	local success, res = pcall(function()
		return request({
			Url = SERVER .. "/get_latest_script",
			Method = "GET"
		})
	end)

	if success and res.Success then
		local content = res.Body
		local currentHash = HttpService:JSONEncode(content)
		if currentHash ~= lastScriptHash and content ~= "" then
			lastScriptHash = currentHash
			local fn, err = loadstring(content)
			if fn then
				local ok, runtimeErr = pcall(fn)
				if not ok then
					warn("[Script Error]:", runtimeErr)
				end
			else
				warn("[Load Error]:", err)
			end
		end
	end
end

-- Manual Dex snapshot
local function sendDex()
	local tree = {
		Name = "game",
		ClassName = "DataModel",
		Children = {},
	}
	local queue = {}

	for _, serviceName in ipairs(mainServices) do
		local ok, service = pcall(game.GetService, game, serviceName)
		if ok and service then
			local node = {
				Name = service.Name,
				ClassName = service.ClassName,
				Children = {},
			}
			table.insert(tree.Children, node)
			table.insert(queue, { inst = service, node = node })
		end
	end

	coroutine.wrap(function()
		while #queue > 0 do
			for _ = 1, 10 do
				local nextItem = table.remove(queue, 1)
				if not nextItem then break end

				local inst, node = nextItem.inst, nextItem.node
				local ok, children = pcall(inst.GetChildren, inst)
				if ok then
					for _, child in ipairs(children) do
						local childNode = {
							Name = child.Name,
							ClassName = child.ClassName,
							Children = {},
						}
						table.insert(node.Children, childNode)
						table.insert(queue, { inst = child, node = childNode })
					end
				end
			end
			task.wait()
		end

		-- Send finished tree
		local success, res = pcall(function()
			return request({
				Url = SERVER .. "/dex",
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode(tree)
			})
		end)
		if not success or not res.Success then
			warn("[Dex Upload] Failed")
		end
	end)()
end

-- UI
local function createGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DexSendGui"
	gui.ResetOnSpawn = false
	gui.Parent = CoreGui

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 180, 0, 40)
	btn.Position = UDim2.new(0, 20, 0, 100)
	btn.Text = "Send Game Snapshot"
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.BorderSizePixel = 0
	btn.Parent = gui
	btn.Active = true
	btn.Draggable = true
	btn.MouseButton1Click:Connect(sendDex)
end

-- Start everything
createGui()
task.spawn(function()
	while true do
		checkScript()
		task.wait(3)
	end
end)

task.spawn(function()
	while true do
		trackChanges()
		task.wait(uploadCooldown)
	end
end)
