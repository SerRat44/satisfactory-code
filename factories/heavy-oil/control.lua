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

    function handleNetworkMessage(type, data)
        if type == "collection" then
            dataCollectionActive = data
        else
            power:handleNetworkMessage(type, data)
        end
    end

    -- Main control loop
    function main()
        while true do
            local e, s, sender, port, type, data = event.pull(config.UPDATE_INTERVAL)

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
    end

    main()
end
