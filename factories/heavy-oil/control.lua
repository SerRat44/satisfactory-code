return function(dependencies)
    local colors = dependencies.colors
    local utils = dependencies.utils
    local config = dependencies.config
    local Display = dependencies.display
    local Power = dependencies.power
    local Monitoring = dependencies.monitoring

    -- Initialize modules
    local display = Display:new(component.proxy(config.COMPONENT_IDS.DISPLAY_PANEL))
    local modules = display:initialize()

    local power = Power:new(modules, dependencies)
    local monitoring = Monitoring:new(modules, dependencies)

    -- Initialize components
    power:initialize()
    monitoring:initialize()

    -- Network setup
    local net = computer.getPCIDevices(classes.NetworkCard)[1]
    net:open(101)
    event.listen(net)

    local dataCollectionActive = true
    local running = true -- Add a flag to control the loop

    function handleNetworkMessage(type, data)
        if type == "collection" then
            dataCollectionActive = data
        else
            power:handleNetworkMessage(type, data)
        end
    end

    -- Main control loop
    function main()
        print("Starting main control loop...")
        while running do
            local success, e, s, sender, port, type, data = pcall(function()
                return event.pull(config.UPDATE_INTERVAL)
            end)

            if not success then
                print("Error in event processing: " .. tostring(e))
                running = false
                break
            end

            -- Wrap major operations in pcall for error logging
            local successMonitor, monitorError = pcall(function()
                monitoring:updateProductivityHistory()
                monitoring:broadcastRefineryStatus()
            end)
            if not successMonitor then
                print("Monitoring error: " .. tostring(monitorError))
                running = false
                break
            end

            local successPower, powerError = pcall(function()
                power:updatePowerDisplays()
                power:updatePowerIndicators()
                power:broadcastPowerStatus()
            end)
            if not successPower then
                print("Power error: " .. tostring(powerError))
                running = false
                break
            end
        end

        print("Exiting main control loop...")
    end

    main()
end
