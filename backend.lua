local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local SERVER = "https://jn5t96-3000.csb.app"
local knownInstances = {}
local lastProps = {}

local httpRequest = (syn and syn.request)
	or (http and http.request)
	or (fluxus and fluxus.request)
	or request
	or http_request

if not httpRequest then
	warn("❌ No supported HTTP request method found.")
	return
end

local mainServices = {
	"Workspace", "Players", "Lighting", "ReplicatedStorage", "ReplicatedFirst",
	"ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer",
	"SoundService", "Chat", "Teams", "LocalizationService", "TestService", "RunService",
	"ScriptContext", "HttpService"
}

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

local function getInstancePath(inst)
	local path = {}
	while inst and inst ~= game do
		table.insert(path, 1, inst.Name)
		inst = inst.Parent
	end
	return path
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

local function deepEqual(a, b)
	if typeof(a) ~= typeof(b) then return false end
	if typeof(a) ~= "table" then return a == b end
	for k, v in pairs(a) do
		if not deepEqual(v, b[k]) then return false end
	end
	for k in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end

local function watchInstance(inst)
	if not inst:IsDescendantOf(game) then return end
	if knownInstances[inst] then return end
	knownInstances[inst] = true
	lastProps[inst] = getProperties(inst)

	inst.AncestryChanged:Connect(function()
		if not inst:IsDescendantOf(game) then
			knownInstances[inst] = nil
			lastProps[inst] = nil
		end
	end)

	for _, child in ipairs(inst:GetChildren()) do
		watchInstance(child)
	end

	inst.ChildAdded:Connect(watchInstance)
end

local function scanServices()
	for _, name in ipairs(mainServices) do
		local ok, service = pcall(function()
			return game:GetService(name)
		end)
		if ok and service then
			watchInstance(service)
		end
	end
end

local function sendChanges()
	local changes = {}

	for inst, last in pairs(lastProps) do
		if inst and inst:IsDescendantOf(game) then
			local current = getProperties(inst)
			local diff = {}
			local changed = false
			for k, v in pairs(current) do
				if not deepEqual(v, last[k]) then
					diff[k] = v
					changed = true
				end
			end
			if changed then
				lastProps[inst] = current
				table.insert(changes, {
					path = getInstancePath(inst),
					properties = diff
				})
			end
		end
	end

	if #changes > 0 then
		pcall(function()
			httpRequest({
				Url = SERVER .. "/dex_changes",
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode(changes)
			})
		end)
	end
end

-- GUI to force refresh
local function createGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DexLiveGui"
	gui.ResetOnSpawn = false
	gui.Parent = CoreGui

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 160, 0, 40)
	btn.Position = UDim2.new(0, 20, 0, 100)
	btn.Text = "Dex Live ON"
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.BorderSizePixel = 0
	btn.Parent = gui
	btn.Active = true
	btn.Draggable = true

	btn.MouseButton1Click:Connect(function()
		scanServices()
	end)
end

-- Start everything
createGui()
scanServices()
task.spawn(function()
	while true do
		sendChanges()
		task.wait(2)
	end
end)
