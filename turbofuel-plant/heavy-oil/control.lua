-- turbofuel-plant/heavy-oil/control.lua
return function(dependencies)
    local colors = dependencies.colors
    local utils = dependencies.utils
    local config = dependencies.config
    local DisplayConstructor = dependencies.display
    local Power = dependencies.power
    local FlowMonitoring = dependencies.flowMonitoring
    local ProductivityMonitoring = dependencies.productivityMonitoring

    -- Create the Display class
    local Display = DisplayConstructor({ colors = colors, config = config })
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

        -- Create module instances
        power = Power:new(modules, dependencies)
        flowMonitoring = FlowMonitoring:new(modules, dependencies)
        productivityMonitoring = ProductivityMonitoring:new(modules, dependencies)

        print("Initializing components...")
        -- Clear any existing event listeners before initializing
        event.clear()

        -- Initialize all modules
        power:initialize()
        flowMonitoring:initialize(config.VALVE_CONFIG)
        productivityMonitoring:initialize(config)

        print("Network card found. Opening port 101...")
        networkCard:open(101)
        event.listen(networkCard)

        print("Starting main control loop...")
        while running do
            local success, e, s, sender, port, type, data = pcall(function()
                return event.pull(config.UPDATE_INTERVAL)
            end)

            if not success then
                print("Error during event pull: " .. tostring(e))
                print("Attempting to reinitialize power module...")
                pcall(function()
                    if power then
                        power:cleanup() -- Clean up before reinitializing
                        power:initialize()
                        print("Power module reinitialized")
                    end
                end)
                goto continue
            end

            -- Process events
            if e == "ChangeState" then
                print("Processing ChangeState event...")
                if s then
                    print("Source:", s)
                    local handled = power:handleSwitchEvent(s)
                    if not handled then
                        print("WARNING: Unhandled switch event")
                    end
                else
                    print("WARNING: Invalid switch event - no source")
                end
            elseif e == "PowerFuseChanged" then
                print("Processing PowerFuseChanged event...")
                if s then
                    power:handlePowerFuseEvent(s)
                end
            elseif e == "Trigger" then
                print("Processing Trigger event...")
                if s == modules.factory.emergency_stop then
                    print("Emergency stop triggered")
                    productivityMonitoring:handleEmergencyStop()
                else
                    for i, button in ipairs(modules.factory.buttons) do
                        if s == button then
                            print("Factory button", i, "pressed")
                            productivityMonitoring:handleButtonPress(i)
                            break
                        end
                    end
                end
            elseif e == "NetworkMessage" then
                print("Processing NetworkMessage:", type)
                handleNetworkMessage(type, data)
            end

            -- Regular updates with error handling
            local updateSuccess, updateError = pcall(function()
                -- Update all monitoring systems
                productivityMonitoring:updateProductivityHistory()
                flowMonitoring:updateFlowDisplays()
                power:updatePowerDisplays()
                power:updatePowerIndicators()

                -- Broadcast status if data collection is active
                if dataCollectionActive then
                    productivityMonitoring:broadcastMachineStatus()
                    flowMonitoring:broadcastFlowStatus()
                    power:broadcastPowerStatus()
                end
            end)

            if not updateSuccess then
                print("Error during updates: " .. tostring(updateError))
            end

            ::continue::
        end

        -- Ensure cleanup runs when the loop exits
        cleanup()
    end

    return controlModule
end
