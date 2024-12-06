-- factories/heavy-oil/control.lua
return function(dependencies)
    local colors = dependencies.colors
    local utils = dependencies.utils
    local config = dependencies.config
    local Display = dependencies.display
    local Power = dependencies.power
    local Monitoring = dependencies.monitoring

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
        -- Initialize modules
        display = Display:new(component.proxy(config.COMPONENT_IDS.DISPLAY_PANEL))
        modules = display:initialize()

        power = Power:new(modules, dependencies)
        monitoring = Monitoring:new(modules, dependencies)

        print("Initializing components...")
        -- Initialize components
        power:initialize()
        monitoring:initialize()

        -- Network setup
        net = computer.getPCIDevices(classes.NetworkCard)[1]
        if not net then
            error("Network card not found!")
        end
        print("Network card found. Opening port 101...")
        net:open(101)
        event.listen(net)

        print("Starting main control loop...")
        while running do
            print("Waiting for event...")
            local success, e, s, sender, port, type, data = pcall(function()
                return event.pull(config.UPDATE_INTERVAL)
            end)

            if not success then
                print("Error during event pull: " .. tostring(e))
                running = false -- Exit on error
                break
            end

            print("Event received: " .. tostring(e))

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

            -- Update displays
            print("Updating displays...")
            monitoring:updateProductivityHistory()
            power:updatePowerDisplays()
            power:updatePowerIndicators()

            -- Broadcast status
            if dataCollectionActive then
                print("Broadcasting status...")
                monitoring:broadcastRefineryStatus()
                power:broadcastPowerStatus()
            end
        end

        print("Exiting main control loop...")
    end

    return controlModule
end
