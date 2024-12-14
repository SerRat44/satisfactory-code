-- turbofuel-plant/heavy-oil/control.lua
return function(dependencies)
    local constants = dependencies.constants
    local utils = dependencies.utils
    local config = dependencies.config
    local display = dependencies.display
    local flowMonitoring = dependencies.flowMonitoring
    local machineControl = dependencies.machineControl
    local powerControl = dependencies.powerControl

    -- Local variables for module state
    local power, flowMonitoring, productivityMonitoring, modules, networkCard

    -- Create the control module table
    local controlModule = {}

    -- Table to store active programs and their event handlers
    local programs = {}

    -- Add a program to be managed
    local function addProgram(program)
        table.insert(programs, program)
    end

    -- Handle events centrally
    local function handleEvents()
        local eventData = { event.pull(0) }
        if #eventData == 0 then return end

        local eventType = eventData[1]
        local source = eventData[2]

        -- Pass event to each program's appropriate handler
        for _, program in ipairs(programs) do
            if eventType == "Trigger" and program.handleIOTriggerEvent then
                program:handleIOTriggerEvent(source)
            elseif eventType == "ChangeState" and program.handleIOSwitchEvent then
                program:handleIOSwitchEvent(source)
            elseif eventType == "PowerFuseChanged" and program.handlePowerFuseEvent then
                program:handlePowerFuseEvent(source)
            end
        end
    end

    function controlModule:start()
        print("Initializing modules...")

        -- Get display panel
        local displayPanel = component.proxy(config.COMPONENT_IDS.DISPLAY_PANEL)
        if not displayPanel then
            error("Display panel not found!")
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
            display = Display
        }


        -- Initialize components
        print("Initializing components...")
        power:initialize()
        flowMonitoring:initialize()
        productivityMonitoring:initialize()

        -- Add programs to be managed
        addProgram(power)
        addProgram(productivityMonitoring)
        addProgram(flowMonitoring)

        networkCard:open(101)
        event.listen(networkCard)

        print("Starting main control loop...")
        while true do
            handleEvents() -- Handle events first

            -- Update all programs
            for _, program in ipairs(programs) do
                if program.update then
                    program:update()
                end
            end
        end
    end

    return controlModule
end
