-- factories/heavy-oil/control.lua
return function(dependencies)
    local colors = dependencies.colors
    local utils = dependencies.utils
    local config = dependencies.config
    local DisplayConstructor = dependencies.display -- This is the constructor function
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

        power = Power:new(modules, dependencies)
        monitoring = Monitoring:new(modules, dependencies)

        print("Initializing components...")
        power:initialize()
        monitoring:initialize()

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
                    power:initialize()
                    print("Power module reinitialized")
                end)
                goto continue
            end

            -- Debug output for events
            if e then
                print("Event received:", e)
                if s then
                    print("Source:", s)
                    if s.Hash then
                        print("Source Hash:", s.Hash)
                    end
                end
            end

            if e == "ChangeState" then
                print("Processing ChangeState event...")
                if s and s.Hash then
                    print("Switch Hash:", s.Hash)
                    local powerAction = self.powerControls[s.Hash]
                    if powerAction then
                        print("Executing power action for switch...")
                        powerAction()
                        print("Power action completed")
                    else
                        print("WARNING: No power action found for Hash:", s.Hash)
                        print("Reinitializing power controls...")
                        self:setupPowerControls()
                    end
                else
                    print("WARNING: Invalid switch event - no Hash found")
                end
            elseif e == "Trigger" then
                print("Processing Trigger event...")
                if s == modules.factory.emergency_stop then
                    print("Emergency stop triggered")
                    monitoring:handleEmergencyStop()
                else
                    for i, button in ipairs(modules.factory.buttons) do
                        if s == button then
                            print("Factory button", i, "pressed")
                            monitoring:handleButtonPress(i)
                            break
                        end
                    end
                end
            elseif e == "NetworkMessage" then
                print("Processing NetworkMessage:", type)
                handleNetworkMessage(type, data)
            end

            -- Regular updates
            monitoring:updateProductivityHistory()
            power:updatePowerDisplays()
            power:updatePowerIndicators()

            if dataCollectionActive then
                monitoring:broadcastRefineryStatus()
                power:broadcastPowerStatus()
            end

            ::continue::
        end
    end

    return controlModule
end
