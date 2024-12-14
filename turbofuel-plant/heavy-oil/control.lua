-- turbofuel-plant/heavy-oil/control.lua
return function(dependencies)
    local colors = dependencies.colors
    local utils = dependencies.utils:new(colors)
    local config = dependencies.config
    local Display = dependencies.display
    local Power = dependencies.power
    local FlowMonitoring = dependencies.flowMonitoring
    local ProductivityMonitoring = dependencies.productivityMonitoring

    -- Create the Display class
    local Display = Display({ colors = colors, config = config })
    if not Display then
        error("Failed to create Display class")
    end

    -- Local variables for module state
    local dataCollectionActive = true
    local running = true
    local display, power, flowMonitoring, productivityMonitoring, modules, networkCard
    local updateTimer = 0

    -- Create the control module table
    local controlModule = {}

    local function processEvent(eventData)
        if not eventData[1] then return end

        local eventType = eventData[1]
        local source = eventData[2]

        print("Event received:", eventType, "from source:", source)

        if eventType == "NetworkMessage" then
            local _, _, _, _, msgType, msgData = table.unpack(eventData)
            if msgType == "collection" then
                dataCollectionActive = msgData
            elseif power then
                power:handleNetworkMessage(msgType, msgData)
            end
        elseif eventType == "Trigger" then
            -- Check emergency stop
            if source == modules.factory.emergency_stop then
                print("Emergency stop triggered")
                productivityMonitoring:handleEmergencyStop()
                return
            end

            -- Check factory buttons
            for i, button in ipairs(modules.factory.buttons) do
                if source == button then
                    print("Factory button pressed:", i)
                    productivityMonitoring:handleButtonPress(i)
                    return
                end
            end
        elseif eventType == "ChangeState" then
            if power then
                power:handleSwitchEvent(source)
            end
        elseif eventType == "PowerFuseChanged" then
            if power then
                power:handlePowerFuseEvent(source)
            end
        end
    end

    local function setupEventListeners()
        print("Setting up event listeners...")
        event.clear()

        -- Listen to network card
        if networkCard then
            networkCard:open(101)
            event.listen(networkCard)
        end

        -- Listen to emergency stop
        if modules.factory.emergency_stop then
            event.listen(modules.factory.emergency_stop)
            print("Emergency stop listener set up")
        end

        -- Listen to factory buttons
        for i, button in ipairs(modules.factory.buttons) do
            if button then
                event.listen(button)
                print("Button", i, "listener set up")
            end
        end

        -- Listen to power switches
        if modules.power and modules.power.switches then
            for name, switch in pairs(modules.power.switches) do
                if switch then
                    event.listen(switch)
                    print("Power switch", name, "listener set up")
                end
            end
        end
    end

    controlModule.main = function()
        print("Initializing modules...")

        -- Get display panel
        local displayPanel = component.proxy(config.COMPONENT_IDS.DISPLAY_PANEL)
        if not displayPanel then
            error("Display panel not found!")
        end

        -- Initialize display
        display = Display:new(displayPanel)
        if not display then
            error("Failed to create display instance")
        end

        print("Initializing display modules...")
        modules = display:initialize()
        if not modules then
            error("Failed to initialize display modules")
        end

        -- Get network card
        networkCard = computer.getPCIDevices(classes.NetworkCard)[1]
        if not networkCard then
            error("Network card not found!")
        end

        -- Create module instances
        local modulesDependencies = {
            colors = colors,
            utils = utils,
            config = config,
            display = modules
        }

        -- Initialize all modules
        power = Power:new(modulesDependencies)
        flowMonitoring = FlowMonitoring:new(modulesDependencies)
        productivityMonitoring = ProductivityMonitoring:new(modulesDependencies)

        -- Initialize components
        print("Initializing components...")
        power:initialize()
        flowMonitoring:initialize()
        productivityMonitoring:initialize()

        -- Set up event listeners
        setupEventListeners()

        print("Starting main control loop...")
        while running do
            -- Process any pending events
            local eventData = { event.pull(0.1) } -- Short timeout for responsive event handling
            if eventData[1] then
                processEvent(eventData)
            end

            -- Regular updates every second
            updateTimer = updateTimer + 0.1
            if updateTimer >= 1.0 then
                if power then power:update() end
                if flowMonitoring then flowMonitoring:update() end
                if productivityMonitoring then productivityMonitoring:update() end

                -- Broadcast status if data collection is active
                if dataCollectionActive then
                    if productivityMonitoring then productivityMonitoring:broadcastMachineStatus() end
                    if flowMonitoring then flowMonitoring:broadcastFlowStatus() end
                    if power then power:broadcastPowerStatus() end
                end

                updateTimer = 0
            end
        end

        -- Cleanup on exit
        if power then power:cleanup() end
        if flowMonitoring then flowMonitoring:cleanup() end
        if productivityMonitoring then productivityMonitoring:cleanup() end
        event.clear()
    end

    return controlModule
end
