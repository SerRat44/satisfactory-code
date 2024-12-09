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
            local flow = self.utils.getValveFlow(valve)

            -- Update gauge if it exists
            if self.display.flow.gauges[type] and self.display.flow.gauges[type][i] then
                self.display.flow.gauges[type][i].percent = flow / 100
                self:updateFlowGaugeColor(self.display.flow.gauges[type][i], flow)
            end

            -- Update display if it exists
            if self.display.flow.displays[type] and self.display.flow.displays[type][i] then
                self.display.flow.displays[type][i]:setText(self.utils.formatFlowDisplay(flow))
            end
        end

        -- Update total flow display if it exists
        self:updateTotalFlow(type)
    end
end

function FlowMonitoring:updateFlowGaugeColor(gauge, flow)
    if not gauge then return end

    if flow >= 95 then
        self.utils.setComponentColor(gauge, self.colors.STATUS.WORKING, self.colors.EMIT.GAUGE)
    elseif flow >= 50 then
        self.utils.setComponentColor(gauge, self.colors.STATUS.IDLE, self.colors.EMIT.GAUGE)
    else
        self.utils.setComponentColor(gauge, self.colors.STATUS.WARNING, self.colors.EMIT.GAUGE)
    end
end

function FlowMonitoring:updateTotalFlow(type)
    local total = 0
    for _, valve in ipairs(self.valves[type]) do
        total = total + self.utils.getValveFlow(valve)
    end

    local displayKey = "total_" .. type .. "_" .. (type == "crude" and "in" or "out")
    if self.display.flow.displays[displayKey] then
        self.display.flow.displays[displayKey]:setText(self.utils.formatFlowDisplay(total))
    end
end

function FlowMonitoring:broadcastFlowStatus()
    local status = {}
    for type, valves in pairs(self.valves) do
        status[type] = {}
        for i, valve in ipairs(valves) do
            status[type][i] = self.utils.getValveFlow(valve)
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
