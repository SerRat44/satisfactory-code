-- common/utils.lua

local Utils = {
    colors = nil
}

function Utils:new(dependencies)
    local instance = {}
    setmetatable(instance, { __index = self })
    instance.colors = dependencies.colors
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

function Utils:formatValveFlowDisplay(flow)
    if flow == 0 then return "0" end
    return tostring(math.floor(flow)) .. " m³/s"
end

function Utils:formatItemFlowDisplay(flow)
    if flow == 0 then return "0" end
    return tostring(math.floor(flow)) .. " m³/s"
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

function Utils:updateGaugeColor(gauge)
    local percent = gauge.percent / gauge.limit
    if percent >= 0.95 then
        self:setComponentColor(gauge, self.colors.COLOR.GREEN, self.colors.EMIT.OFF)
    elseif percent >= 0.5 then
        self:setComponentColor(gauge, self.colors.COLOR.YELLOW, self.colors.EMIT.OFF)
    elseif percent > 0 then
        self:setComponentColor(gauge, self.colors.COLOR.ORANGE, self.colors.EMIT.OFF)
    else
        self:setComponentColor(gauge, self.colors.COLOR.RED, self.colors.EMIT.OFF)
    end
end

return Utils
