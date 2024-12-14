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
    local display, power, flowMonitoring, productivityMonitoring, modules, networkCard

    -- Create the control module table
    local controlModule = {}

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

        networkCard:open(101)
        event.listen(networkCard)

        print("Starting main control loop...")
        while true do
            if power then power:update() end
            if flowMonitoring then flowMonitoring:update() end
            if productivityMonitoring then productivityMonitoring:update() end
        end
    end

    return controlModule
end
