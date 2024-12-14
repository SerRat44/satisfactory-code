-- turbofuel-plant/heavy-oil/power.lua

local Power = {
    power_switch = nil,
    battery_switch = nil,
    light_switch = nil,
    display = nil,
    networkCard = nil,
    remoteControl = false
}

function Power:new(dependencies)
    local instance = {}
    setmetatable(instance, { __index = self })
    instance.display = dependencies.display
    instance.colors = dependencies.colors
    instance.utils = dependencies.utils
    instance.config = dependencies.config

    -- Initialize network card
    instance.networkCard = computer.getPCIDevices(classes.NetworkCard)[1]
    if not instance.networkCard then
        error("Network card not found in Power module")
    end

    return instance
end

function Power:initialize()
    -- Initialize power switches
    self.power_switch = component.proxy(self.config.POWER.POWER_SWITCH)
    self.battery_switch = component.proxy(self.config.POWER.BATTERY_SWITCH)
    self.light_switch = component.proxy(self.config.POWER.LIGHT_SWITCH)

    if not self.power_switch or not self.battery_switch or not self.light_switch then
        error("Failed to initialize power switches")
    end

    -- Initialize IO switches
    local powerIO = self.display.power.switches.MAIN
    local batteryIO = self.display.power.switches.BATTERY
    local lightIO = self.display.power.switches.LIGHTS
    local remoteIO = self.display.power.switches.REMOTE_CONTROL

    if not powerIO or not batteryIO or not lightIO or not remoteIO then
        error("Failed to initialize power IO switches")
    end

    -- Get the connectors
    local mainGridConnector = self.power_switch:getPowerConnectors()[2]
    local factoryConnector = self.power_switch:getPowerConnectors()[1]
    local batteryConnector = self.battery_switch:getPowerConnectors()[1]

    if not mainGridConnector or not factoryConnector or not batteryConnector then
        error("Failed to initialize power connectors")
    end

    -- Set up event listening for power fuses
    event.listen(mainGridConnector)
    event.listen(factoryConnector)
    event.listen(batteryConnector)

    -- Set up event listening for IO switches
    event.listen(powerIO)
    event.listen(batteryIO)
    event.listen(lightIO)
    event.listen(remoteIO)

    self.power_switch:setIsSwitchOn(powerIO.state)
    self.battery_switch:setIsSwitchOn(batteryIO.state)
    self.light_switch.isLightEnabled = lightIO.state

    -- Update initial power indicators
    self:updatePowerIndicators()
end

function Power:handlePowerFuseEvent(source)
    print("Handling power fuse event from source:", source)

    if source == self.power_switch then
        -- Update main power indicators
        local main_circuit = self.power_switch:getPowerConnectors()[2]:getCircuit()
        local factory_circuit = self.power_switch:getPowerConnectors()[1]:getCircuit()

        -- Update main grid indicator
        self.utils:setComponentColor(self.display.power.indicators.MAIN,
            main_circuit.isFuesed and self.colors.COLOR.RED or self.colors.COLOR.GREEN,
            self.colors.EMIT.INDICATOR)

        -- Update factory indicator
        self.utils:setComponentColor(self.display.power.indicators.FACTORY,
            factory_circuit.isFuesed and self.colors.COLOR.RED or self.colors.COLOR.GREEN,
            self.colors.EMIT.INDICATOR)
    elseif source == self.battery_switch then
        -- Update battery indicators
        local battery_circuit = self.battery_switch:getPowerConnectors()[1]:getCircuit()

        self.utils:setComponentColor(self.display.power.indicators.BATTERY,
            battery_circuit.isFuesed and self.colors.COLOR.RED or self.colors.COLOR.GREEN,
            self.colors.EMIT.INDICATOR)
    end
end

function Power:handleIOSwitchEvent(source)
    local powerIO = self.display.power.switches.MAIN
    local batteryIO = self.display.power.switches.BATTERY
    local lightIO = self.display.power.switches.LIGHTS
    local remoteIO = self.display.power.switches.REMOTE_CONTROL

    print("Handling switch event from source:", source)

    -- Handle Main Power Switch
    if source == powerIO then
        print("Main power switch triggered, state:", source.state)
        self.power_switch:setIsSwitchOn(source.state)
        self:updatePowerIndicators()
    end

    -- Handle Battery Switch
    if source == batteryIO then
        print("Battery switch triggered, state:", source.state)
        self.battery_switch:setIsSwitchOn(source.state)
        self:updatePowerIndicators()
    end

    if source == lightIO then
        print("Light switch triggered, state:", source.state)
        self.light_switch.isLightEnabled = source.state
    end

    if source == remoteIO then
        print("Remote control switch triggered, state:", source.state)
        self.remoteControl = source.state
        self:updateIOColors()
        powerIO.enabled = not self.remoteControl
        batteryIO.enabled = not self.remoteControl
    end
end

function Power:updateIOColors()
    local powerIO = self.display.power.switches.MAIN
    local batteryIO = self.display.power.switches.BATTERY

    if self.remoteControl then
        self.utils:setComponentColor(powerIO, self.colors.COLOR.RED, self.colors.EMIT.BUTTON)
        self.utils:setComponentColor(batteryIO, self.colors.COLOR.RED, self.colors.EMIT.BUTTON)
    else
        self.utils:setComponentColor(powerIO, self.colors.COLOR.GREEN, self.colors.EMIT.BUTTON)
        self.utils:setComponentColor(batteryIO, self.colors.COLOR.GREEN, self.colors.EMIT.BUTTON)
    end
end

function Power:updatePowerIndicators()
    local main_power_on = self.power_switch.isSwitchOn
    local main_circuit = self.power_switch:getPowerConnectors()[2]:getCircuit()
    local factory_circuit = self.power_switch:getPowerConnectors()[1]:getCircuit()

    if main_circuit.isFuesed then
        self.utils:setComponentColor(self.display.power.indicators.MAIN, self.colors.COLOR.RED,
            self.colors.EMIT.INDICATOR)
    else
        self.utils:setComponentColor(self.display.power.indicators.MAIN, self.colors.COLOR.GREEN,
            self.colors.EMIT.INDICATOR)
    end

    self.display.power.switches.MAIN.state = main_power_on
    self.utils:setComponentColor(self.display.power.indicators.MAIN_SWITCH,
        main_power_on and self.colors.COLOR.GREEN or self.colors.COLOR.RED, self.colors.EMIT.INDICATOR)

    if factory_circuit.isFuesed then
        self.utils:setComponentColor(self.display.power.indicators.FACTORY, self.colors.COLOR.RED,
            self.colors.EMIT.INDICATOR)
    else
        self.utils:setComponentColor(self.display.power.indicators.FACTORY, self.colors.COLOR.GREEN,
            self.colors.EMIT.INDICATOR)
    end

    local battery_power_on = self.battery_switch.isSwitchOn
    local battery_circuit = self.battery_switch:getPowerConnectors()[1]:getCircuit()

    self.display.power.switches.BATTERY.state = battery_power_on
    self.utils:setComponentColor(self.display.power.indicators.BATTERY_SWITCH,
        battery_power_on and self.colors.COLOR.GREEN or self.colors.COLOR.RED, self.colors.EMIT.INDICATOR)

    if battery_circuit.isFuesed then
        self.utils:setComponentColor(self.display.power.indicators.BATTERY, self.colors.COLOR.RED,
            self.colors.EMIT.INDICATOR)
    else
        self.utils:setComponentColor(self.display.power.indicators.BATTERY, self.colors.COLOR.GREEN,
            self.colors.EMIT.INDICATOR)
    end
end

function Power:updatePowerDisplays()
    local main_circuit = self.power_switch:getPowerConnectors()[1]:getCircuit()
    local factory_circuit = self.power_switch:getPowerConnectors()[2]:getCircuit()
    local battery_circuit = self.battery_switch:getPowerConnectors()[2]:getCircuit()

    self.display.power.POWER_DISPLAYS.MAIN_PRODUCED:setText(string.format("%.1f", main_circuit.production / 1000))
    self.display.power.POWER_DISPLAYS.MAIN_USED:setText(string.format("%.1f", main_circuit.consumption / 1000))
    self.display.power.POWER_DISPLAYS.FACTORY_USED:setText(string.format("%.1f", factory_circuit.consumption / 1000))

    self.display.power.BATTERY.MWH:setText(string.format("%.0f MW/h", battery_circuit.batteryStore))

    local time = battery_circuit.batteryTimeUntilEmpty
    if time == 0 then
        time = battery_circuit.batteryTimeUntilFull
        if time == 0 then
            self.display.power.BATTERY.REMAINING_TIME:setText("-")
        else
            local min = string.format("%.0f", time / 60)
            local seconds = string.format("%02d", math.floor(math.fmod(time, 60)))
            self.display.power.BATTERY.REMAINING_TIME:setText(min .. ":" .. seconds)
        end
    else
        local min = string.format("%.0f", time / 60)
        local seconds = string.format("%02d", math.floor(math.fmod(time, 60)))
        self.display.power.BATTERY.REMAINING_TIME:setText(min .. ":" .. seconds)
    end

    local maxCapacity = battery_circuit.batteryCapacity
    if maxCapacity and maxCapacity > 0 then
        self.display.power.BATTERY.PERCENTAGE.limit = maxCapacity
        local batteryPercent = (battery_circuit.batteryStore / maxCapacity) * 100
        self.display.power.BATTERY.PERCENTAGE.percent = battery_circuit.batteryStore / maxCapacity

        if batteryPercent >= 75 then
            self.utils:setComponentColor(self.display.power.BATTERY.PERCENTAGE, self.colors.COLOR.GREEN,
                self.colors.EMIT.GAUGE)
        elseif batteryPercent >= 25 then
            self.utils:setComponentColor(self.display.power.BATTERY.PERCENTAGE, self.colors.COLOR.YELLOW,
                self.colors.EMIT.GAUGE)
        else
            self.utils:setComponentColor(self.display.power.BATTERY.PERCENTAGE, self.colors.COLOR.RED,
                self.colors.EMIT.GAUGE)
        end
    else
        self.display.power.BATTERY.PERCENTAGE.limit = 1.0
        local batteryPercent = battery_circuit.batteryStorePercent
        self.display.power.BATTERY.PERCENTAGE.percent = batteryPercent / 100

        if batteryPercent >= 75 then
            self.utils:setComponentColor(self.display.power.BATTERY.PERCENTAGE, self.colors.COLOR.GREEN,
                self.colors.EMIT.GAUGE)
        elseif batteryPercent >= 25 then
            self.utils:setComponentColor(self.display.power.BATTERY.PERCENTAGE, self.colors.COLOR.YELLOW,
                self.colors.EMIT.GAUGE)
        else
            self.utils:setComponentColor(self.display.power.BATTERY.PERCENTAGE, self.colors.COLOR.RED,
                self.colors.EMIT.GAUGE)
        end
    end

    if battery_circuit.batteryTimeUntilFull > 0 then
        self.utils:setComponentColor(self.display.power.BATTERY.CHARGING, self.colors.COLOR.GREEN,
            self.colors.EMIT.INDICATOR)
    else
        self.utils:setComponentColor(self.display.power.BATTERY.CHARGING, self.colors.COLOR.GREEN,
            self.colors.EMIT.OFF)
    end

    if battery_circuit.batteryTimeUntilEmpty > 0 then
        self.utils:setComponentColor(self.display.power.BATTERY.ON_BATTERIES, self.colors.COLOR.GREEN,
            self.colors.EMIT.INDICATOR)
    else
        self.utils:setComponentColor(self.display.power.BATTERY.ON_BATTERIES, self.colors.COLOR.GREEN,
            self.colors.EMIT.OFF)
    end
end

function Power:broadcastPowerStatus()
    local main_circuit = self.power_switch:getPowerConnectors()[2]:getCircuit()
    local factory_circuit = self.power_switch:getPowerConnectors()[1]:getCircuit()
    local battery_circuit = self.battery_switch:getPowerConnectors()[1]:getCircuit()

    if self.networkCard then
        self.networkCard:broadcast(100, "power_update", {
            grid = {
                production = main_circuit.production,
                consumption = main_circuit.consumption,
                isFused = main_circuit.isFuesed,
                isOn = self.power_switch.isSwitchOn
            },
            factory = {
                consumption = factory_circuit.consumption,
                isFused = factory_circuit.isFuesed
            },
            battery = {
                storePercent = battery_circuit.batteryStorePercent,
                timeUntilEmpty = battery_circuit.batteryTimeUntilEmpty,
                timeUntilFull = battery_circuit.batteryTimeUntilFull,
                isOn = self.battery_switch.isSwitchOn,
                isFused = battery_circuit.isFuesed
            }
        })
    end
end

function Power:update()
    self:updatePowerDisplays()
    self:updateIOColors()
    self:broadcastPowerStatus()
end

function Power:handleNetworkMessage(type, data)
    if type == "grid" then
        if data then
            self.power_switch:setIsSwitchOn(true)
        else
            self.power_switch:setIsSwitchOn(false)
        end
        self:updatePowerIndicators()
    end
end

return Power
