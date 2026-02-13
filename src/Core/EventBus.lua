--[[
    EventBus
    Lightweight publish/subscribe system for decoupling MVC layers.
    Views publish user-intent events, the Controller subscribes to them.
]]

local EventBus = {}
EventBus.__index = EventBus

function EventBus:new()
    local o = setmetatable({}, self)
    o.listeners = {}
    return o
end

function EventBus:subscribe(event, callback)
    if not self.listeners[event] then
        self.listeners[event] = {}
    end
    table.insert(self.listeners[event], callback)
end

function EventBus:publish(event, ...)
    if not self.listeners[event] then
        return
    end
    for _, callback in ipairs(self.listeners[event]) do
        callback(...)
    end
end

return EventBus
