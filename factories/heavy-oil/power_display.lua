-- factories/heavy-oil/power_display.lua

local PowerDisplay = {
    gpu = nil,
    displayPanel = nil,
    power_switch = nil,
    connector = nil,
    dimensions = {
        width = 2300,
        height = 1550
    },
    colors = {
        consumption = { r = 1.0, g = 0.55, b = 0.2, a = 1.0 },  -- FICSIT_ORANGE
        capacity = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 },      -- GREY_0500
        production = { r = 0.75, g = 0.75, b = 0.75, a = 1.0 }, -- GREY_0750
        maxConsumption = { r = 0.05, g = 0.5, b = 0.7, a = 1.0 }
    }
}

function PowerDisplay:new(power_switch, dependencies)
    local instance = {}
    setmetatable(instance, { __index = self })

    instance.power_switch = power_switch
    instance.connector = power_switch:getPowerConnectors()[1]
    instance.displayPanel = component.proxy(dependencies.config.COMPONENT_IDS.POWER_DISPLAY)

    -- Get GPU T2
    instance.gpu = computer.getPCIDevices(classes.GPU_T2_C)[1]
    if not instance.gpu then
        error("No GPU T2 found")
    end

    -- Bind to screen
    if not instance.displayPanel then
        error("Power display screen not found")
    end
    instance.gpu:bindScreen(instance.displayPanel)

    return instance
end

function PowerDisplay:initialize()
    -- Get screen size
    local screenSize = self.gpu:getScreenSize()
    print('Power display resolution: ' .. screenSize.x .. 'x' .. screenSize.y)

    -- Set up background
    self:drawBackground()
end

function PowerDisplay:drawBackground()
    -- Clear screen
    self.gpu:drawRect(
        { x = 0, y = 0 },
        { x = self.dimensions.width, y = self.dimensions.height },
        { r = 0, g = 0, b = 0, a = 1.0 }
    )

    -- Draw dividing lines
    self.gpu:drawLines(
        {
            { x = 0,                     y = self.dimensions.height },
            { x = self.dimensions.width, y = self.dimensions.height }
        },
        5,
        { r = 0.5, g = 0.5, b = 0.5, a = 1.0 }
    )
end

function PowerDisplay:update()
    if not self.connector then return end

    local circuit = self.connector:getCircuit()
    if not circuit then return end

    -- Get power values
    local production = circuit.production or 0
    local capacity = circuit.capacity or 0
    local consumption = circuit.consumption or 0
    local maxConsumption = circuit.maxPowerConsumption or 0

    -- Clear previous frame
    self:drawBackground()

    -- Draw power values
    self:drawPowerData(production, capacity, consumption, maxConsumption)

    -- Draw production bar
    self:drawBar(production, capacity, self.colors.production, 0)

    -- Draw consumption bar
    self:drawBar(consumption, capacity, self.colors.consumption, 40)

    -- Flush changes to screen
    self.gpu:flush()
end

function PowerDisplay:drawPowerData(production, capacity, consumption, maxConsumption)
    local textSize = 40
    local textColor = { r = 1, g = 1, b = 1, a = 1.0 }

    -- Draw text values
    self.gpu:drawText(
        { x = 50, y = 50 },
        string.format("Production: %.1f MW", production / 1000000),
        textSize,
        textColor
    )

    self.gpu:drawText(
        { x = 50, y = 100 },
        string.format("Consumption: %.1f MW", consumption / 1000000),
        textSize,
        textColor
    )

    self.gpu:drawText(
        { x = 50, y = 150 },
        string.format("Capacity: %.1f MW", capacity / 1000000),
        textSize,
        textColor
    )
end

function PowerDisplay:drawBar(value, max, color, yOffset)
    local width = (value / max) * (self.dimensions.width - 100)

    self.gpu:drawRect(
        { x = 50, y = 200 + yOffset },
        { x = width, y = 30 },
        color
    )
end

return PowerDisplay
