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

    local function handleNetworkMessage(type, data)
        if type == "collection" then
            dataCollectionActive = data
        else
            power:handleNetworkMessage(type, data)
        end
    end

    -- Cleanup function to handle proper shutdown
    local function cleanup()
        print("Cleaning up control module...")
        -- Clear event listeners
        if networkCard then
            event.clear(networkCard)
        end
        -- Clean up modules
        if power then
            power:cleanup()
        end
        if flowMonitoring then
            flowMonitoring:cleanup()
        end
        if productivityMonitoring then
            productivityMonitoring:cleanup()
        end
        -- Clear all remaining events
        event.clear()
        running = false
    end

    -- Main control loop function
    controlModule.main = function()
        print("Initializing modules...")

        -- Get the display panel first
        local displayPanel = component.proxy(config.COMPONENT_IDS.DISPLAY_PANEL)
        if not displayPanel then
            error("Display panel not found!")
        end

        -- Initialize display with the panel
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

        -- Get network card early
        networkCard = computer.getPCIDevices(classes.NetworkCard)[1]
        if not networkCard then
            error("Network card not found!")
        end

        local baseDependencies = {
            colors = colors,
        }

        -- Create module instances with correct dependencies
        local modulesDependencies = {
            colors = colors,
            utils = utils,
            config = config,
            display = modules -- Pass the initialized display modules
        }

        -- Create module instances
        productivityMonitoring = ProductivityMonitoring:new(modulesDependencies)
        flowMonitoring = FlowMonitoring:new(modulesDependencies)
        power = Power:new(modulesDependencies)

        print("Initializing components...")
        -- Clear any existing event listeners before initializing
        event.clear()

        -- Initialize all modules
        power:initialize()
        flowMonitoring:initialize()

        -- Initialize productivity monitoring with machine IDs
        local monitoringConfig = {
            COMPONENT_IDS = config.COMPONENT_IDS,
            MACHINE_IDS = config.REFINERY_IDS -- Use existing refinery IDs
        }
        productivityMonitoring:initialize(monitoringConfig)

        print("Network card found. Opening port 101...")
        networkCard:open(101)
        event.listen(networkCard)

        print("Starting main control loop...")
        while running do
            local e, s, sender, port, type, data = event.pull(config.UPDATE_INTERVAL)

            if e then
                if e == "NetworkMessage" then
                    print("Processing NetworkMessage:", type)
                    handleNetworkMessage(type, data)
                elseif e == "Trigger" then
                    print("Processing Trigger event from source:", s)
                    -- Handle button presses
                    if productivityMonitoring and s == modules.factory.emergency_stop then
                        print("Emergency stop triggered")
                        productivityMonitoring:handleEmergencyStop()
                    else
                        -- Check factory buttons
                        for i, button in ipairs(modules.factory.buttons) do
                            if s == button then
                                print("Factory button", i, "pressed")
                                productivityMonitoring:handleButtonPress(i)
                                break
                            end
                        end
                    end
                elseif e == "ChangeState" then
                    print("Processing ChangeState event from source:", s)
                    if power then
                        power:handleSwitchEvent(s)
                    end
                elseif e == "PowerFuseChanged" then
                    print("Processing PowerFuseChanged event from source:", s)
                    if power then
                        power:handlePowerFuseEvent(s)
                    end
                elseif e == "ComponentConnectionChanged" then
                    print("Component connection changed:", s)
                    -- Handle component disconnections/reconnections if needed
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

        -- Ensure cleanup runs when the loop exits
        cleanup()
    end

    return controlModule
end
