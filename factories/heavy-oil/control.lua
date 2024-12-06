-- factories/heavy-oil/control.lua
return function(dependencies)
    -- Print out what we received
    print("Dependencies received:")
    for k, v in pairs(dependencies) do
        print(k, type(v))
    end
    print("Display class:", dependencies.display)
    if dependencies.display then
        print("Display class type:", type(dependencies.display))
        for k, v in pairs(dependencies.display) do
            print("  -", k, type(v))
        end
    end
    local colors = dependencies.colors
    local utils = dependencies.utils
    local config = dependencies.config
    local Display = dependencies.display -- This is the Display class itself
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
        -- Get the display panel first
        local displayPanel = component.proxy(config.COMPONENT_IDS.DISPLAY_PANEL)
        if not displayPanel then
            error("Display panel not found!")
        end

        -- Initialize display with the panel
        print("Creating display instance...")
        display = setmetatable({}, { __index = Display })
        display.panel = displayPanel

        print("Initializing display modules...")
        modules = display:initialize()
        if not modules then
            error("Failed to initialize display modules!")
        end

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
            monitoring:updateProductivityHistory()
            power:updatePowerDisplays()
            power:updatePowerIndicators()

            -- Broadcast status
            if dataCollectionActive then
                monitoring:broadcastRefineryStatus()
                power:broadcastPowerStatus()
            end
        end

        print("Exiting main control loop...")
    end

    return controlModule
end
