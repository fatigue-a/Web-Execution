local HttpService = game:GetService("HttpService")

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

-- Gather services and their properties
local function gatherServiceData()
    local servicesData = {}

    for _, serviceName in ipairs(mainServices) do
        local service = game:GetService(serviceName)
        if service then
            local serviceData = {}
            serviceData.Name = service.Name
            serviceData.ClassName = service.ClassName
            serviceData.Properties = getProperties(service)
            servicesData[serviceName] = serviceData
        end
    end

    return servicesData
end

-- Send the data to the server
local function sendServiceData()
    local servicesData = gatherServiceData()

    local success, res = pcall(function()
        return request({
            Url = SERVER .. "/instance_data",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(servicesData)
        })
    end)

    if not success or not res.Success then
        warn("[Service Data] Upload failed:", res and res.StatusMessage or "unknown")
    end
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

-- Start polling script and sending data
task.spawn(function()
    while true do
        checkScript()
        sendServiceData()  -- Send service data every loop
        task.wait(3)  -- Poll every 3 seconds
    end
end)
