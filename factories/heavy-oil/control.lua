-- factories/heavy-oil/control.lua
return function(dependencies)
    local colors = dependencies.colors
    local utils = dependencies.utils
    local config = dependencies.config
    local DisplayConstructor = dependencies.display
    local Power = dependencies.power
    local Monitoring = dependencies.monitoring

    -- Create the Display class with dependencies
    local Display = DisplayConstructor({ colors = colors, config = config })

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

        -- Get the display panel
        print("Looking for panel with ID:", config.COMPONENT_IDS.DISPLAY_PANEL)
        local displayPanel = component.proxy(config.COMPONENT_IDS.DISPLAY_PANEL)
        if not displayPanel then
            error("Display panel not found!")
        end

        print("Panel found:", displayPanel ~= nil)

        -- Try a direct test of the panel
        local test_success, test_result = pcall(function()
            return displayPanel:getModule(0, 0, 0)
        end)
        print("Direct panel test:", test_success)

        -- Create display instance
        print("Creating display instance...")
        local success, result = pcall(function()
            display = Display:new(displayPanel)
            return display
        end)

        if not success then
            error("Failed to create display instance: " .. tostring(result))
        end

        print("Initializing display modules...")
        success, result = pcall(function()
            modules = display:initialize()
            return modules
        end)

        if not success then
            error("Failed to initialize display modules: " .. tostring(result))
        end

        power = Power:new(modules, dependencies)
        monitoring = Monitoring:new(modules, dependencies)

        print("Initializing components...")
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
