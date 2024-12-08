-- factories/polymer-recycling/control.lua
return function(dependencies)
    local colors = dependencies.colors
    local utils = dependencies.utils
    local config = dependencies.config
    local DisplayConstructor = dependencies.display
    local Power = dependencies.power
    local Monitoring = dependencies.monitoring

    -- Create the Display class
    local Display = DisplayConstructor({ colors = colors, config = config })
    if not Display then
        error("Failed to create Display class")
    end

    -- Local variables for module state
    local dataCollectionActive = true
    local running = true
    local display, power, monitoring, modules, networkCard

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
        print("Cleaning up recycling control module...")
        -- Clear event listeners
        if networkCard then
            event.clear(networkCard)
        end
        -- Clean up power module
        if power then
            power:cleanup()
        end
        -- Clean up monitoring module
        if monitoring then
            monitoring:cleanup()
        end
        -- Clear all remaining events
        event.clear()
        running = false
    end

    -- Main control loop function
    controlModule.main = function()
        print("Initializing recycling modules...")

        -- Get both display panels
        local displayPanel1 = component.proxy(config.COMPONENT_IDS.DISPLAY_PANEL_1)
        local displayPanel2 = component.proxy(config.COMPONENT_IDS.DISPLAY_PANEL_2)
        if not displayPanel1 or not displayPanel2 then
            error("One or both display panels not found!")
        end

        -- Initialize displays
        print("Creating display instances...")
        local display1 = Display:new(displayPanel1)
        local display2 = Display:new(displayPanel2)
        if not display1 or not display2 then
            error("Failed to create display instances")
        end

        print("Initializing display modules...")
        local modules1 = display1:initialize("rubber")
        local modules2 = display2:initialize("plastic")
        if not modules1 or not modules2 then
            error("Failed to initialize display modules")
        end

        -- Combine modules
        modules = {
            rubber = modules1,
            plastic = modules2,
            power = modules1.power, -- Use power controls from first display
        }

        -- Get network card early
        networkCard = computer.getPCIDevices(classes.NetworkCard)[1]
        if not networkCard then
            error("Network card not found!")
        end

        -- Create power and monitoring instances
        power = Power:new(modules, dependencies)
        monitoring = Monitoring:new(modules, dependencies)

        print("Initializing components...")
        -- Clear any existing event listeners before initializing
        event.clear()

        power:initialize()
        monitoring:initialize()

        print("Network card found. Opening port 102...") -- Different port from heavy oil
        networkCard:open(102)
        event.listen(networkCard)

        print("Starting main recycling control loop...")
        while running do
            local success, e, s, sender, port, type, data = pcall(function()
                return event.pull(config.UPDATE_INTERVAL)
            end)

            if not success then
                print("Error during event pull: " .. tostring(e))
                print("Attempting to reinitialize power module...")
                pcall(function()
                    if power then
                        power:cleanup()
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
                if s == modules.rubber.emergency_stop or s == modules.plastic.emergency_stop then
                    print("Emergency stop triggered")
                    monitoring:handleEmergencyStop()
                else
                    monitoring:handleButtonPress(s)
                end
            elseif e == "NetworkMessage" then
                print("Processing NetworkMessage:", type)
                handleNetworkMessage(type, data)
            end

            -- Regular updates with error handling
            local updateSuccess, updateError = pcall(function()
                monitoring:updateProductivityHistory()
                power:updatePowerDisplays()
                power:updatePowerIndicators()

                if dataCollectionActive then
                    monitoring:broadcastRecyclingStatus()
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
