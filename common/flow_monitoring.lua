-- turbofuel-plant/common/flow_monitoring.lua

local FlowMonitoring = {
    display = nil,
    valves = {},
    networkCard = nil
}

function FlowMonitoring:new(dependencies)
    local instance = {}
    setmetatable(instance, { __index = self })
    instance.display = dependencies.display
    instance.utils = dependencies.utils
    instance.colors = dependencies.colors
    instance.config = dependencies.config

    -- Initialize network card
    instance.networkCard = computer.getPCIDevices(classes.NetworkCard)[1]
    if not instance.networkCard then
        error("Network card not found in Flow Monitoring module")
    end

    return instance
end

function FlowMonitoring:initialize(valveConfig)
    -- Initialize valves based on config
    for type, valveIds in pairs(valveConfig) do
        self.valves[type] = {}
        for i, id in ipairs(valveIds) do
            self.valves[type][i] = component.proxy(id)
            if not self.valves[type][i] then
                error(string.format("Valve not found: %s_%d", type, i))
            end
        end
    end
end

function FlowMonitoring:updateFlowDisplays()
    -- Update flow gauges and displays for each type
    for type, valves in pairs(self.valves) do
        for i, valve in ipairs(valves) do
            -- Update gauge if it exists
            if self.display.flow.gauges[type] and self.display.flow.gauges[type][i] then
                self.display.flow.gauges[type][i].limit = valve.userFlowLimit
                self.display.flow.gauges[type][i].percent = valve.flow
                self.utils:updateGaugeColor(self.display.flow.gauges[type][i])
            end

            -- Update display if it exists
            if self.display.flow.displays[type] and self.display.flow.displays[type][i] then
                self.display.flow.displays[type][i]:setText(self.utils:formatFlowDisplay(valve.flow))
            end
        end

        -- Update total flow display if it exists
        self:updateTotalFlow(type)
    end
end

function FlowMonitoring:updateTotalFlow()
    -- Update totals for all types
    for type, valves in pairs(self.valves) do
        local total = 0
        for _, valve in ipairs(valves) do
            total = total + (valve.flow or 0)
        end

        -- Find any display key that starts with "total_" and contains our type
        for displayKey, display in pairs(self.display.flow.displays) do
            if displayKey:match(type[1] .. "_" .. type[2]) then
                if type[1] == "produced" then
                    display:setText(string.format("%.1f/min", total))
                elseif type[1] == "total" then
                    display:setText(string.format("%.1f m³/s", total))
                end
            end
        end
    end
end

function FlowMonitoring:broadcastFlowStatus()
    local status = {}
    for type, valves in pairs(self.valves) do
        status[type] = {}
        for i, valve in ipairs(valves) do
            status[type][i] = valve.flow
        end
    end

    if self.networkCard then
        self.networkCard:broadcast(100, "flow_update", status)
    end
end

function FlowMonitoring:cleanup()
    -- Cleanup code if needed
end

return FlowMonitoring
