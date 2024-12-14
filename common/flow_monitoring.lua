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

function FlowMonitoring:updateValveFlowDisplays()
    -- Track totals during the main loop
    local totals = {}

    for type, valves in pairs(self.valves) do
        totals[type] = 0

        for i, valve in ipairs(valves) do
            local displayIndex = i - 1
            totals[type] = totals[type] + (valve.flow or 0)

            -- Update gauge and display if they exist
            if self.display.flow.gauges[type] and self.display.flow.gauges[type][displayIndex] then
                local gauge = self.display.flow.gauges[type][displayIndex]
                gauge.limit = valve.userFlowLimit
                gauge.percent = valve.flow / valve.userFlowLimit
                self.utils:updateGaugeColor(gauge)
            end

            if self.display.flow.displays[type] and self.display.flow.displays[type][displayIndex] then
                self.display.flow.displays[type][displayIndex]:setText(self.utils:formatFlowDisplay(valve.flow))
            end
        end

        -- Update total display
        if self.display.flow.displays["total_" .. type:lower()] then
            self.display.flow.displays["total_" .. type:lower()]:setText(self.utils:formatFlowDisplay(totals[type]))
        end
    end
end

function FlowMonitoring:updateItemFlowDisplays()

end

function FlowMonitoring:update()
    self:updateValveFlowDisplays()
    self:updateItemFlowDisplays()
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

return FlowMonitoring
