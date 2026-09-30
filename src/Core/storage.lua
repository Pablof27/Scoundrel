--[[
    Storage
    Persists flat key/value tables (booleans, numbers, strings) in the LÖVE save directory.
    Values are parsed, never executed, and only keys present in the defaults are accepted.
]]

local Storage = {}

local function serialize(values)
    local lines = {}
    for key, value in pairs(values) do
        local kind = type(value)
        if kind == "boolean" or kind == "number" or kind == "string" then
            table.insert(lines, key .. "=" .. kind:sub(1, 1) .. ":" .. tostring(value))
        end
    end
    table.sort(lines)
    return table.concat(lines, "\n")
end

local function deserialize(contents)
    local values = {}
    for line in contents:gmatch("[^\r\n]+") do
        local key, kind, raw = line:match("^([%w_]+)=(%a):(.*)$")
        if kind == "b" then
            values[key] = raw == "true"
        elseif kind == "n" then
            values[key] = tonumber(raw)
        elseif kind == "s" then
            values[key] = raw
        end
    end
    return values
end

function Storage.load(filename, defaults)
    local values = {}
    for key, value in pairs(defaults) do
        values[key] = value
    end
    if not love.filesystem.getInfo(filename) then
        return values
    end
    local contents = love.filesystem.read(filename)
    if not contents then
        return values
    end
    for key, value in pairs(deserialize(contents)) do
        if defaults[key] ~= nil and type(defaults[key]) == type(value) then
            values[key] = value
        end
    end
    return values
end

function Storage.save(filename, values)
    local ok, err = love.filesystem.write(filename, serialize(values))
    if not ok then
        print("Could not save " .. filename .. ": " .. tostring(err))
    end
end

return Storage
