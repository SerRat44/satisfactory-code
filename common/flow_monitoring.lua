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

function FlowMonitoring:initialize()
    -- Initialize valves based on config
    self.valves = {}
    for type, valveIds in pairs(self.config.VALVES) do
        self.valves[type] = {}
        for i, id in ipairs(valveIds) do
            local valve = component.proxy(id)
            if not valve then
                error(string.format("Valve not found: %s - ID: %s", type, id))
            end
            self.valves[type][i] = valve
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
    end
    self:updateTotalFlow()
end

function FlowMonitoring:updateTotalFlow()
    -- Update totals for all types
    for type, valves in pairs(self.valves) do
        local total = 0
        for _, valve in ipairs(valves) do
            total = total + (valve.flow or 0)
        end

        -- Update the total display if it exists
        if self.display.flow.displays["total_" .. type:lower()] then
            self.display.flow.displays["total_" .. type:lower()]:setText(string.format("%.2f m³/s", total))
        end
    end
end

function FlowMonitoring:update()
    self:updateFlowDisplays()
    self:broadcastFlowStatus()
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
