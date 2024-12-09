-- common/utils.lua

return function()
    local utils = {}

    function utils:setComponentColor(component, color, emit)
        if component then
            local r = color[1] / 255
            local g = color[2] / 255
            local b = color[3] / 255
            component:setColor(r, g, b, emit)
        end
    end

    function utils:formatFlowDisplay(flow)
        if flow == 0 then return "0" end
        return tostring(math.floor(flow))
    end

    function utils:getValveFlow(valve)
        if not valve then return 0 end
        return valve.flow or 0
    end

    function utils:getAvgProductivity()
        local total_productivity = 0
        local active_machines = 0

        for _, machine in ipairs(self.machines) do -- Changed from self.refineries
            if machine and not machine.standby then
                total_productivity = total_productivity + machine.productivity
                active_machines = active_machines + 1
            end
        end

        local current_prod = active_machines > 0 and (total_productivity / active_machines) or 0
        return current_prod
    end

    return utils
end
