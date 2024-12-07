-- factories/heavy-oil/control.lua
return function(dependencies)
    local colors = dependencies.colors
    local utils = dependencies.utils
    local config = dependencies.config
    local DisplayConstructor = dependencies.display
    local Power = dependencies.power
    local Monitoring = dependencies.monitoring
    local PowerDisplay = dependencies.power_display -- Add power display module

    -- Create the Display class
    local Display = DisplayConstructor({ colors = colors, config = config })
    if not Display then
        error("Failed to create Display class")
    end

    -- Local variables for module state
    local dataCollectionActive = true
    local running = true
    local display, power, monitoring, power_display, modules, networkCard

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

        -- Initialize power display
        print("Creating power display instance...")
        power_display = PowerDisplay:new(power.power_switch, dependencies)

        print("Initializing components...")
        power:initialize()
        monitoring:initialize()
        power_display:initialize()

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
                -- Try to reinitialize power module on error
                if power then
                    print("Attempting to reinitialize power module...")
                    pcall(function() power:initialize() end)
                end
            else
                if e == "ChangeState" then
                    local powerAction = power.powerControls[s.Hash]
                    if powerAction then
                        powerAction()
                    end
                elseif e == "Trigger" then
                    if s == modules.factory.emergency_stop then
                        monitoring:handleEmergencyStop()
                    else
                        for i, button in ipairs(modules.factory.buttons) do
                            if s == button then
                                monitoring:handleButtonPress(i)
                                break
                            end
                        end
                    end
                elseif e == "NetworkMessage" then
                    handleNetworkMessage(type, data)
                elseif e == "powerFuseChanged" then
                    -- Handle fuse state changes
                    power:handleFuseEvent(s)
                end

                monitoring:updateProductivityHistory()
                power:updatePowerDisplays()
                power:updatePowerIndicators()
                power_display:update() -- Update power display

                if dataCollectionActive then
                    monitoring:broadcastRefineryStatus()
                    power:broadcastPowerStatus()
                end
            end
        end
    end

    return controlModule
end
