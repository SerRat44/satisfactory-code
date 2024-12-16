-- programs/flow_monitoring.lua

return function(dependencies)
    local FlowMonitoring = {
        valves = {},
        networkCard = nil,
        machines = {},
        flow_block = {},
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

        for i, block in ipairs(self.config.DISPLAY_LAYOUT.FLOW_BLOCKS) do
            local gauge, topDisplay, bottomDisplay = self.displayPanel:initializeFlowBlock(self.panel, block.x, block.y,
                block.z)
            self.display.flow_block[i] = { gauge = gauge, topDisplay = topDisplay, bottomDisplay = bottomDisplay }
        end

        debug("Initializing machines...")
        for i, id in ipairs(self.config.REFINERY_IDS) do
            local machine = component.proxy(id)
            if machine then
                self.machines[i] = machine
            else
                debug("Warning: Failed to initialize machine " .. i)
            end
        end
    end

    function FlowMonitoring:getMaxProductFlow(machine)
        local recipe = machine:getRecipe()
        local product = recipe:getProducts()[1][1]
        local runsPerMin = 60.0 / recipe.duration
        local potential = machine.potential * machine.productionBoost

        for _, prod in ipairs(recipe:getProducts()) do
            local itemsPerMin = prod[1].amount * runsPerMin

            if product.type.form == 2 or product.type.form == 3 then
                itemsPerMin = itemsPerMin / 1000
            end

            itemsPerMin = itemsPerMin * potential

            print(prod.type.name, itemsPerMin, " / min")
            return product.name, itemsPerMin
        end
    end

    function FlowMonitoring:updateItemFlowDisplays()
        for i, block in pairs(self.flow_block) do
            local item, maxFlow = self:getMaxProductFlow(self.machines[i])

            local maxFlow = maxFlow
            local currentFlow = maxFlow * self.machine[i].productivity

            block.gauge.limit = maxFlow
            block.gauge.percent = currentFlow
            self.utils:updateGaugeColor(gauge)

            self.flow_block.topDisplay:setText(string.format("%.2f", currentFlow))
            self.flow_block.bottomDisplay:setText(item)
        end
    end

    function FlowMonitoring:update()
        self:updateItemFlowDisplays()
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
