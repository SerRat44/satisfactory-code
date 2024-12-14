-- turbofuel-plant/common/flow_monitoring.lua

local FlowMonitoring = {
    valves = {},
    networkCard = nil,
    machines = {}
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
    print("Initializing machines...")
    for i, id in ipairs(self.config.REFINERY_IDS) do
        local machine = component.proxy(id)
        if machine then
            self.machines[i] = machine
        else
            print("Warning: Failed to initialize machine " .. i)
        end
    end
end

function FlowMonitoring:updateValveFlowDisplays()
    local totals = {}

    for type, valves in pairs(self.valves) do
        totals[type] = 0

        for i, valve in ipairs(valves) do
            -- Change this line from i - 1 to just i
            local displayIndex = i
            totals[type] = totals[type] + (valve.flow or 0)

            if self.display.flow.liquids.gauges[type] and self.display.flow.liquids.gauges[type][displayIndex] then
                local gauge = self.display.flow.liquids.gauges[type][displayIndex]
                gauge.limit = valve.userFlowLimit
                gauge.percent = valve.flow / valve.userFlowLimit
                self.utils:updateGaugeColor(gauge)
            end

            if self.display.flow.liquids.displays[type] and self.display.flow.liquids.displays[type][displayIndex] then
                self.display.flow.liquids.displays[type][displayIndex]:setText(self.utils:formatValveFlowDisplay(valve
                    .flow))
            end
        end

        if self.display.flow.liquids.displays["total_" .. type] then
            self.display.flow.liquids.displays["total_" .. type]:setText(self.utils:formatValveFlowDisplay(totals[type]))
        end
    end
end

function FlowMonitoring:getProductFlow(machine)
    local recipe = machine:getRecipe()
    local product = recipe:getProducts()[1][1]
    local runsPerMin = 60.0 / recipe.duration
    local potential = machine.potential * machine.productionBoost * machine.productivity

    for _, prod in ipairs(recipe:getProducts()) do
        local itemsPerMin = prod[1].amount * runsPerMin

        if item.type.form == 2 or item.type.form == 3 then
            itemsPerMin = itemsPerMin / 1000
        end

        itemsPerMin = itemsPerMin * potential

        print(prod.type.name, itemsPerMin, " / min")
    end
end

function FlowMonitoring:updateItemFlowDisplays()
    for type, gauge in pairs(self.display.flow.items.gauges) do
        for i = 1, #self.machines do
            self:getProductFlow(self.machines[i])
        end



        local maxFlow = 780
        local currentFlow = 0

        gauge.limit = maxFlow
        gauge.percent = currentFlow / maxFlow
        self.utils:updateGaugeColor(gauge)

        -- Update corresponding display if it exists
        if self.display.flow.items.displays[type] then
            self.display.flow.items.displays[type]:setText(self.utils:formatItemFlowDisplay(currentFlow))
        end
    end
end

function FlowMonitoring:update()
    self:updateValveFlowDisplays()
    --self:updateItemFlowDisplays()
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

return FlowMonitoring
