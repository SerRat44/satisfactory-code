-- factories/heavy-oil/control.lua
return function(dependencies)
    -- Previous initialization code remains the same...

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
                -- Try to reinitialize power module on error
                if power then
                    print("Attempting to reinitialize power module...")
                    pcall(function() power:initialize() end)
                end
            else
                if e == "ChangeState" and s and s.Hash then
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
