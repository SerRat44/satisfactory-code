-- programs/flow_monitoring.lua
return function(dependencies)
    local FlowMonitoring = {
        valves = {},
        networkCard = nil,
        machines = {},
        flow_blocks = {},
        constants = dependencies.constants,
        config = dependencies.config,
        displayPanel = dependencies.displayPanel,
        utils = dependencies.utils,
        panel = nil,
    }

    function FlowMonitoring:initialize()
        debug("===Initializing Program - Flow Monitoring===")

        self.panel = component.proxy(self.config.PANEL_ID)
        if not self.panel then
            error("Failed to initialize panel")
        end

        for i, block in ipairs(self.config.DISPLAY_LAYOUT.FLOW_BLOCKS) do
            local gauge, topDisplay, bottomDisplay = self.displayPanel:initializeFlowBlock(self.panel, block.x, block.y,
                block.z)
            self.flow_blocks[i] = { gauge = gauge, topDisplay = topDisplay, bottomDisplay = bottomDisplay }
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
        if not machine then
            return nil, nil
        end

        local recipe = machine:getRecipe()
        if not recipe then
            return nil, nil
        end

        local runsPerMin = 60.0 / recipe.duration
        local potential = machine.potential * machine.productionBoost
        local productFlows = {}

        local products = recipe:getProducts()
        if not products then
            return nil, nil
        end

        for i = 1, #products do
            local prod = products[i]
            local itemsPerMin = prod.amount * runsPerMin

            -- Convert liquid/gas to m³
            if prod.type.form == 2 or prod.type.form == 3 then
                itemsPerMin = itemsPerMin / 1000
            end

            itemsPerMin = itemsPerMin * potential

            table.insert(productFlows, {
                item = prod.type.name,
                maxFlow = itemsPerMin
            })
        end

        return productFlows
    end

    function FlowMonitoring:updateItemFlowDisplays()
        for i, block in pairs(self.flow_blocks) do
            local machine = self.machines[i]
            if not machine then
                goto continue
            end

            local productFlows = self:getMaxProductFlow(machine)
            if not productFlows then
                goto continue
            end

            -- For now, we'll just display the first product's flow
            local firstProduct = productFlows[1]
            if not firstProduct then
                goto continue
            end

            local maxFlow = firstProduct.maxFlow
            local currentFlow = maxFlow * (machine.productivity or 0)

            if block.gauge then
                block.gauge.limit = maxFlow
                block.gauge.percent = currentFlow
                self.utils:updateGaugeColor(block.gauge)
            end

            if block.topDisplay then
                block.topDisplay:setText(string.format("%.2f", currentFlow))
            end

            if block.bottomDisplay then
                block.bottomDisplay:setText(firstProduct.item .. "/min")
            end

            ::continue::
        end
    end

    function FlowMonitoring:update()
        self:updateItemFlowDisplays()
        self:broadcastFlowStatus()
    end

    function FlowMonitoring:broadcastFlowStatus()
        if not self.networkCard then
            return
        end

        local status = {}
        for i, machine in ipairs(self.machines) do
            if machine then
                local flows = self:getMaxProductFlow(machine)
                if flows then
                    status[i] = flows
                end
            end
        end

        self.networkCard:broadcast(100, "flow_update", status)
    end

    return FlowMonitoring
end
