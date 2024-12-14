-- turbofuel-plant/heavy-oil/control.lua
return function(dependencies)
    local colors = dependencies.colors
    local utils = dependencies.utils:new(colors)
    local config = dependencies.config
    local Display = dependencies.display
    local Power = dependencies.power
    local FlowMonitoring = dependencies.flowMonitoring
    local ProductivityMonitoring = dependencies.productivityMonitoring

    -- Create the Display class
    local Display = Display({ colors = colors, config = config })
    if not Display then
        error("Failed to create Display class")
    end

    -- Local variables for module state
    local dataCollectionActive = true
    local running = true
    local display, power, flowMonitoring, productivityMonitoring, modules, networkCard

    -- Create the control module table
    local controlModule = {}

    -- Event handler mapping
    local eventHandlers = {
        NetworkMessage = function(_, _, _, _, type, data)
            if type == "collection" then
                dataCollectionActive = data
            else
                power:handleNetworkMessage(type, data)
            end
        end,

        Trigger = function(_, source)
            -- Handle emergency stop
            if source == modules.factory.emergency_stop then
                productivityMonitoring:handleEmergencyStop()
                return
            end

            -- Handle factory buttons
            for i, button in ipairs(modules.factory.buttons) do
                if source == button then
                    productivityMonitoring:handleButtonPress(i)
                    return
                end
            end

            -- Handle flow control knobs
            if modules.flow and modules.flow.knobs then
                for type, knobs in pairs(modules.flow.knobs) do
                    for i, knob in ipairs(knobs) do
                        if source == knob then
                            flowMonitoring:handleKnobChange(type, i, knob.value)
                            return
                        end
                    end
                end
            end
        end,

        ChangeState = function(_, source)
            if power then
                power:handleSwitchEvent(source)
            end
        end,

        PowerFuseChanged = function(_, source)
            if power then
                power:handlePowerFuseEvent(source)
            end
        end,
    }

    -- Cleanup function
    local function cleanup()
        print("Cleaning up control module...")
        if networkCard then
            event.clear(networkCard)
        end
        if power then power:cleanup() end
        if flowMonitoring then flowMonitoring:cleanup() end
        if productivityMonitoring then productivityMonitoring:cleanup() end
        event.clear()
        running = false
    end

    -- Main control loop
    controlModule.main = function()
        print("Initializing modules...")

        -- Get the display panel
        local displayPanel = component.proxy(config.COMPONENT_IDS.DISPLAY_PANEL)
        if not displayPanel then
            error("Display panel not found!")
        end

        -- Initialize display
        print("Creating display instance...")
        display = Display:new(displayPanel)
        if not display then
            error("Failed to create display instance")
        end

        print("Initializing display modules...")
        modules = display:initialize()
        if not modules then
            error("Failed to initialize display modules")
        end

        -- Get network card
        networkCard = computer.getPCIDevices(classes.NetworkCard)[1]
        if not networkCard then
            error("Network card not found!")
        end

        -- Create module instances with dependencies
        local modulesDependencies = {
            colors = colors,
            utils = utils,
            config = config,
            display = modules
        }

        -- Initialize all modules
        productivityMonitoring = ProductivityMonitoring:new(modulesDependencies)
        flowMonitoring = FlowMonitoring:new(modulesDependencies)
        power = Power:new(modulesDependencies)

        print("Initializing components...")
        event.clear() -- Clear existing events before setting up new ones

        -- Initialize modules
        power:initialize()
        flowMonitoring:initialize()
        productivityMonitoring:initialize()

        -- Set up network listening
        print("Setting up network...")
        networkCard:open(101)
        event.listen(networkCard)

        print("Starting main control loop...")
        while running do
            -- Handle events
            local eventData = { event.pull(config.UPDATE_INTERVAL) }
            local eventType = eventData[1]

            if eventType then
                local handler = eventHandlers[eventType]
                if handler then
                    handler(table.unpack(eventData))
                end
            end

            -- Regular updates
            if power then power:update() end
            if flowMonitoring then flowMonitoring:update() end
            if productivityMonitoring then productivityMonitoring:update() end

            -- Broadcast status if data collection is active
            if dataCollectionActive then
                if productivityMonitoring then productivityMonitoring:broadcastMachineStatus() end
                if flowMonitoring then flowMonitoring:broadcastFlowStatus() end
                if power then power:broadcastPowerStatus() end
            end
        end

        cleanup()
    end

    return controlModule
end
