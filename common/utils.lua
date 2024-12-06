-- common/utils.lua

return {
    setComponentColor = function(component, color, emit)
        if component then
            local r = color[1] / 255
            local g = color[2] / 255
            local b = color[3] / 255
            component:setColor(r, g, b, emit)
        end
    end,
    
    formatFlowDisplay = function(flow)
        if flow == 0 then return "0" end
        return tostring(math.floor(flow))
    end,
    
    getValveFlow = function(valve)
        if not valve then return 0 end
        return valve.flow or 0
    end
}