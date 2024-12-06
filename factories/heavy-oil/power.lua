local colors = require('common.colors')
local utils = require('common.utils')
local config = require('config')

local Power = {
    power_switch = nil,
    battery_switch = nil,
    light_switch = nil,
    display = nil,
    powerControls = {}
}

function Power:new(display)
    local instance = {}
    setmetatable(instance, { __index = self })
    instance.display = display
    return instance
end

function Power:initialize()
    self.power_switch = component.proxy(config.COMPONENT_IDS.POWER_SWITCH)
    self.battery_switch = component.proxy(config.COMPONENT_IDS.BATTERY_SWITCH)
    self.light_switch = component.proxy(config.COMPONENT_IDS.LIGHT_SWITCH)
    
    self:setupPowerControls()
    event.listen(self.display.power.switches.MAIN)
    event.listen(self.display.power.switches.BATTERY)
end

function Power:setupPowerControls()
    local main_power_connectors = self.power_switch:getPowerConnectors()
    
    function handleMainPowerSwitch()
        local state = self.display.power.switches.MAIN.state
        self.power_switch:setIsSwitchOn(state)
        self:updatePowerIndicators()
    end

    function handleBatteryPowerSwitch()
        local state = self.display.power.switches.BATTERY.state
        self.battery_switch:setIsSwitchOn(state)
        self:updatePowerIndicators()
    end

    self.powerControls = {
        [self.display.power.switches.MAIN.Hash] = handleMainPowerSwitch,
        [self.display.power.switches.BATTERY.Hash] = handleBatteryPowerSwitch
    }

    return self.powerControls
end

function Power:updatePowerIndicators()
    local main_power_on = self.power_switch.isSwitchOn
    local main_circuit = self.power_switch:getPowerConnectors()[2]:getCircuit()
    local factory_circuit = self.power_switch:getPowerConnectors()[1]:getCircuit()
    
    if main_circuit.isFuesed then
        utils.setComponentColor(self.display.power.indicators.MAIN, colors.STATUS.OFF, colors.EMIT.INDICATOR)
    else
        utils.setComponentColor(self.display.power.indicators.MAIN, colors.STATUS.WORKING, colors.EMIT.INDICATOR)
    end
    
    self.display.power.switches.MAIN.state = main_power_on
    utils.setComponentColor(self.display.power.indicators.MAIN_SWITCH, main_power_on and colors.STATUS.WORKING or colors.STATUS.OFF, colors.EMIT.INDICATOR)
    
    if factory_circuit.isFuesed then
        utils.setComponentColor(self.display.power.indicators.FACTORY, colors.STATUS.OFF, colors.EMIT.INDICATOR)
    else
        utils.setComponentColor(self.display.power.indicators.FACTORY, colors.STATUS.WORKING, colors.EMIT.INDICATOR)
    end
    
    local battery_power_on = self.battery_switch.isSwitchOn
    local battery_circuit = self.battery_switch:getPowerConnectors()[1]:getCircuit()
    
    self.display.power.switches.BATTERY.state = battery_power_on
    utils.setComponentColor(self.display.power.indicators.BATTERY_SWITCH, battery_power_on and colors.STATUS.WORKING or colors.STATUS.OFF, colors.EMIT.INDICATOR)
    
    if battery_circuit.isFuesed then
        utils.setComponentColor(self.display.power.indicators.BATTERY, colors.STATUS.OFF, colors.EMIT.INDICATOR)
    else
        utils.setComponentColor(self.display.power.indicators.BATTERY, colors.STATUS.WORKING, colors.EMIT.INDICATOR)
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
            utils.setComponentColor(self.display.power.BATTERY.PERCENTAGE, colors.STATUS.WORKING, colors.EMIT.GAUGE)
        elseif batteryPercent >= 25 then
            utils.setComponentColor(self.display.power.BATTERY.PERCENTAGE, colors.STATUS.WARNING, colors.EMIT.GAUGE)
        else
            utils.setComponentColor(self.display.power.BATTERY.PERCENTAGE, colors.STATUS.OFF, colors.EMIT.GAUGE)
        end
    else
        self.display.power.BATTERY.PERCENTAGE.limit = 1.0
        local batteryPercent = battery_circuit.batteryStorePercent
        self.display.power.BATTERY.PERCENTAGE.percent = batteryPercent / 100
        
        if batteryPercent >= 75 then
            utils.setComponentColor(self.display.power.BATTERY.PERCENTAGE, colors.STATUS.WORKING, colors.EMIT.GAUGE)
        elseif batteryPercent >= 25 then
            utils.setComponentColor(self.display.power.BATTERY.PERCENTAGE, colors.STATUS.WARNING, colors.EMIT.GAUGE)
        else
            utils.setComponentColor(self.display.power.BATTERY.PERCENTAGE, colors.STATUS.OFF, colors.EMIT.GAUGE)
        end
    end
    
    if battery_circuit.batteryTimeUntilFull > 0 then
        utils.setComponentColor(self.display.power.BATTERY.CHARGING, colors.STATUS.WORKING, colors.EMIT.INDICATOR)
    else
        utils.setComponentColor(self.display.power.BATTERY.CHARGING, colors.STATUS.WORKING, colors.EMIT.OFF)
    end
    
    if battery_circuit.batteryTimeUntilEmpty > 0 then
        utils.setComponentColor(self.display.power.BATTERY.ON_BATTERIES, colors.STATUS.WORKING, colors.EMIT.INDICATOR)
    else
        utils.setComponentColor(self.display.power.BATTERY.ON_BATTERIES, colors.STATUS.WORKING, colors.EMIT.OFF)
    end
end

function Power:broadcastPowerStatus()
    local main_circuit = self.power_switch:getPowerConnectors()[2]:getCircuit()
    local factory_circuit = self.power_switch:getPowerConnectors()[1]:getCircuit()
    local battery_circuit = self.battery_switch:getPowerConnectors()[1]:getCircuit()
    
    net:broadcast(100, "power_update", {
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