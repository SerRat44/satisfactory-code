-- common/utils.lua

local Utils = {
    machines = nil
}

function Utils:new()
    local instance = {}
    setmetatable(instance, { __index = self })
    return instance
end

function Utils:setComponentColor(component, color, emit)
    if component then
        local r = color[1] / 255
        local g = color[2] / 255
        local b = color[3] / 255
        component:setColor(r, g, b, emit)
    end
end

function Utils:formatFlowDisplay(flow)
    if flow == 0 then return "0" end
    return tostring(math.floor(flow))
end

function Utils:getValveFlow(valve)
    if not valve then return 0 end
    return valve.flow or 0
end

function Utils:getAvgProductivity(machines)
    local total_productivity = 0
    local active_machines = 0

    for _, machine in ipairs(machines) do
        if machine and not machine.standby then
            total_productivity = total_productivity + machine.productivity
            active_machines = active_machines + 1
        end
    end

    local current_prod = active_machines > 0 and (total_productivity / active_machines) or 0
    return current_prod
end

return Utils
