-- factories/heavy-oil/control.lua
return function(dependencies)
    local colors = dependencies.colors
    local utils = dependencies.utils
    local config = dependencies.config
    local DisplayConstructor = dependencies.display
    local Power = dependencies.power
    local Monitoring = dependencies.monitoring

    if not DisplayConstructor then
        error("Display constructor not provided in dependencies")
    end

    -- Create the Display class with dependencies
    local Display = DisplayConstructor({ colors = colors, config = config })
    if not Display then
        error("Failed to create Display class")
    end

    -- Local variables for module state
    local dataCollectionActive = true
    local running = true
    local display, power, monitoring, modules, net

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

        -- Debug panel object
        print("Display panel type:", type(displayPanel))
        print("Display panel methods:")
        for k, v in pairs(displayPanel) do
            print("  -", k, type(v))
        end

        if not displayPanel.getModule then
            print("WARNING: getModule function not found on panel")
            print("Panel component class:", displayPanel.getClass and displayPanel:getClass() or "unknown")
        end

        -- Initialize display with the panel
        print("Creating display instance...")
        display = Display:new(displayPanel)
        if not display then
            error("Failed to create display instance!")
        end

        -- Debug display object
        print("Display object type:", type(display))
        print("Display methods:")
        for k, v in pairs(display) do
            print("  -", k, type(v))
        end

        print("Panel in display:", type(display.panel))
        if display.panel then
            print("Panel methods in display:")
            for k, v in pairs(display.panel) do
                print("  -", k, type(v))
            end
        end

        print("Initializing display modules...")
        modules = display:initialize()
        if not modules then
            error("Failed to initialize display modules!")
        end

        -- Rest of the code remains the same...
        power = Power:new(modules, dependencies)
        monitoring = Monitoring:new(modules, dependencies)

        print("Initializing components...")
        power:initialize()
        monitoring:initialize()

        net = computer.getPCIDevices(classes.NetworkCard)[1]
        if not net then
            error("Network card not found!")
        end
        print("Network card found. Opening port 101...")
        net:open(101)
        event.listen(net)

        print("Starting main control loop...")
        while running do
            local success, e, s, sender, port, type, data = pcall(function()
                return event.pull(config.UPDATE_INTERVAL)
            end)

            if not success then
                print("Error during event pull: " .. tostring(e))
                running = false
                break
            end

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
            end

            monitoring:updateProductivityHistory()
            power:updatePowerDisplays()
            power:updatePowerIndicators()

            if dataCollectionActive then
                monitoring:broadcastRefineryStatus()
                power:broadcastPowerStatus()
            end
        end
    end

    return controlModule
end
