-- programs/flow_monitoring.lua

return function(dependencies)
    local FlowMonitoring = {
        valves = {},
        networkCard = nil,
        machines = {},
        constants = dependencies.constants,
        config = dependencies.config,
        displayPanel = dependencies.displayPanel,
        utils = dependencies.utils,
        panel = nil,
    }

    function FlowMonitoring:initialize()
        self.panel = component.proxy(self.config.PANEL_ID)
        if not self.panel then
            error("Failed to initialize panel")
        end

        self:initializeFlowBlock(self.panel, 0, 0, 1)
        self:initializeFlowBlock(self.panel, 7, 3, 1)
        self:initializeFlowBlock(self.panel, 7, 0, 1)

        debug("Initializing machines...")
        for i, id in ipairs(self.config.REFINERY_IDS) do
            local machine = component.proxy(id)
            if machine then
                self.machines[i] = machine
            else
                print("Warning: Failed to initialize machine " .. i)
            end
        end
    end

    function FlowMonitoring:getProductFlow(machine)
        local recipe = machine:getRecipe()
        local product = recipe:getProducts()[1][1]
        local runsPerMin = 60.0 / recipe.duration
        local potential = machine.potential * machine.productionBoost

        for _, prod in ipairs(recipe:getProducts()) do
            local itemsPerMin = prod[1].amount * runsPerMin

            if product.type.form == 2 or item.type.form == 3 then
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
        self:broadcastFlowStatus()
    end

    function FlowMonitoring:broadcastFlowStatus()
        local status = {}


        if self.networkCard then
            self.networkCard:broadcast(100, "flow_update", status)
        end
    end

    return FlowMonitoring
end
