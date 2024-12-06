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
        print("Initializing display modules...")
        modules = display:initialize()

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
