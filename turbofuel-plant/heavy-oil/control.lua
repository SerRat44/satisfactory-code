-- turbofuel-plant/heavy-oil/control.lua
return function(dependencies)
    local constants = dependencies.constants
    local utils = dependencies.utils
    local config = dependencies.config
    local displayPanel = dependencies.displayPanel
    local flowMonitoring = dependencies.flowMonitoring
    local machineControl = dependencies.machineControl
    local powerControl = dependencies.powerControl

    local Control = {
        programs = {}
    }

    -- Add a program to be managed
    function Control:addProgram(program)
        table.insert(self.programs, program)
    end

    -- Handle events centrally
    function Control:handleEvents()
        local eventData = { event.pull() }
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

    function Control:start()
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
        debug("Initializing programs...")
        powerControl:initialize()
        flowMonitoring:initialize()
        machineControl:initialize()

        -- Add programs to be managed
        Control:addProgram(machineControl)
        Control:addProgram(flowMonitoring)
        Control:addProgram(powerControl)

        networkCard:open(101)
        event.listen(networkCard)

        print("Starting main control loop...")
        while true do
            Control:handleEvents() -- Handle events first

            -- Update all programs
            for _, program in ipairs(programs) do
                if program.update then
                    program:update()
                end
            end
        end
    end

    return Control
end
