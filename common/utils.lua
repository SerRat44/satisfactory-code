-- common/utils.lua

return function(dependencies)
    local Utils = {
        constants = dependencies.constants,
    }

    function Utils:setComponentColor(component, color, emit)
        if not component then error("Component is nil") end

        local r = tonumber(string.format("%.5f", color[1] / 255))
        local g = tonumber(string.format("%.5f", color[2] / 255))
        local b = tonumber(string.format("%.5f", color[3] / 255))

        component:setColor(r, g, b, emit)
    end

    function Utils:formatValveFlowDisplay(flow)
        return string.format("%.2f", flow) .. " m³/min"
    end

    function Utils:formatItemFlowDisplay(flow)
        return string.format("%.2f", flow) .. " i/min"
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
        if gauge.limit <= 0 then
            self:setComponentColor(gauge, self.constants.COLOR.RED, self.constants.EMIT.OFF)
        else
            local ratio = gauge.percent / gauge.limit
            if ratio >= 0.95 then
                self:setComponentColor(gauge, self.constants.COLOR.GREEN, self.constants.EMIT.OFF)
            elseif ratio >= 0.5 then
                self:setComponentColor(gauge, self.constants.COLOR.YELLOW, self.constants.EMIT.OFF)
            elseif ratio > 0 then
                self:setComponentColor(gauge, self.constants.COLOR.ORANGE, self.constants.EMIT.OFF)
            elseif ratio <= 0 then
                self:setComponentColor(gauge, self.constants.COLOR.RED, self.constants.EMIT.OFF)
            end
        end
    end

    return Utils
end
