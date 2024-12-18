-- programs/powerControl.lua

return function(dependencies)
    local PowerControl = {
        networkCard = nil,
        main_circuit = nil,
        factory_circuit = nil,
        battery_circuit = nil,
        constants = dependencies.constants,
        config = dependencies.config,
        display_panel = dependencies.displayPanel,
        utils = dependencies.utils,
        switches = {},
        io_switches = {},
        indicators = {},
        battery = {},
        power_displays = {},
        panel = nil,
    }

    function PowerControl:initialize()
        debug("===Initializing Program - Power Control===")

        self.switches.power = component.proxy(self.config.POWER.POWER_SWITCH)
        self.switches.battery = component.proxy(self.config.POWER.BATTERY_SWITCH)
        self.switches.lights = component.proxy(self.config.POWER.LIGHT_SWITCH)

        self.panel = component.proxy(self.config.PANEL_ID)
        if not self.panel then
            error("Failed to initialize panel")
        end

        self.io_switches.factory = self.panel:getModule(2, 0, 2)
        self.io_switches.battery = self.panel:getModule(6, 0, 2)
        self.io_switches.lights = self.panel:getModule(10, 0, 2)

        -- Initialize power indicators
        self.indicators.main = self.panel:getModule(0, 1, 2)
        self.indicators.factory_switch = self.panel:getModule(2, 2, 2)
        self.indicators.factory = self.panel:getModule(4, 1, 2)
        self.indicators.battery_switch = self.panel:getModule(6, 2, 2)
        self.indicators.battery = self.panel:getModule(8, 1, 2)

        -- Initialize battery displays
        self.battery.remaining_time = self.panel:getModule(9, 3, 2)
        self.battery.on_batteries = self.panel:getModule(9, 4, 2)
        self.battery.charging = self.panel:getModule(9, 5, 2)
        self.battery.percentage = self.panel:getModule(9, 6, 2)
        self.battery.mwh = self.panel:getModule(7, 6, 2)

        -- Initialize power displays
        self.power_displays.main_used = self.panel:getModule(0, 3, 2)
        self.power_displays.main_produced = self.panel:getModule(1, 3, 2)
        self.power_displays.factory_used = self.panel:getModule(4, 3, 2)

        -- Get the connectors
        self.main_circuit = self.switches.power:getPowerConnectors()[1]:getCircuit()
        self.factory_circuit = self.switches.power:getPowerConnectors()[2]:getCircuit()
        self.battery_circuit = self.switches.battery:getPowerConnectors()[2]:getCircuit()

        -- Set up event listening for power fuses
        event.listen(self.main_circuit)
        event.listen(self.factory_circuit)
        event.listen(self.battery_circuit)

        -- Set up event listening for IO switches
        event.listen(self.io_switches.factory)
        event.listen(self.io_switches.battery)
        event.listen(self.io_switches.lights)

        self.io_switches.factory.state = self.switches.power.isSwitchOn
        self.io_switches.battery.state = self.switches.battery.isSwitchOn
        self.io_switches.lights.state = self.switches.lights.isLightEnabled

        -- Update initial power indicators
        self:updatePowerIndicators()
    end

    function PowerControl:handlePowerFuseEvent(source)
        print("Handling power fuse event from source:", source)

        if source == self.switches.power then
            -- Update main grid indicator
            self.utils:setComponentColor(self.indicators.MAIN,
                self.main_circuit.isFuesed and self.constants.COLOR.RED or self.constants.COLOR.GREEN,
                self.constants.EMIT.INDICATOR)

            -- Update factory indicator
            self.utils:setComponentColor(self.indicators.FACTORY,
                self.factory_circuit.isFuesed and self.colors.constants.RED or self.colors.constants.GREEN,
                self.constants.EMIT.INDICATOR)
        elseif source == self.switches.battery then
            -- Update battery indicator
            self.utils:setComponentColor(self.indicators.BATTERY,
                self.battery_circuit.isFuesed and self.colors.COLOR.RED or self.colors.COLOR.GREEN,
                self.colors.EMIT.INDICATOR)
        end
    end

    function PowerControl:handleIOSwitchEvent(source)
        debug("Handling switch event from source:", source)

        if source == self.io_switches.factory then
            debug("Main power switch triggered, state:", source.state)
            self.switches.power:setIsSwitchOn(source.state)
            self:updatePowerIndicators()
        elseif source == self.io_switches.battery then
            debug("Battery switch triggered, state:", source.state)
            self.switches.battery:setIsSwitchOn(source.state)
            self:updatePowerIndicators()
        elseif source == self.io_switches.lights then
            debug("Light switch triggered, state:", source.state)
            self.switches.lights.isLightEnabled = source.state
        end
    end

    function PowerControl:updatePowerIndicators()
        self.utils:setComponentColor(self.indicators.main,
            self.main_circuit.isFuesed and self.constants.COLOR.RED or self.constants.COLOR.GREEN,
            self.constants.EMIT.INDICATOR)

        self.io_switches.factory.state = self.switches.power.isSwitchOn
        self.utils:setComponentColor(self.indicators.factory_switch,
            self.switches.power.isSwitchOn and self.constants.COLOR.GREEN or self.constants.COLOR.RED,
            self.constants.EMIT.INDICATOR)
        self.utils:setComponentColor(self.indicators.factory,
            self.factory_circuit.isFuesed and self.constants.COLOR.RED or self.constants.COLOR.GREEN,
            self.constants.EMIT.INDICATOR)

        self.io_switches.battery.state = self.switches.battery.isSwitchOn
        self.utils:setComponentColor(self.indicators.battery_switch,
            self.switches.battery.isSwitchOn and self.constants.COLOR.GREEN or self.constants.COLOR.RED,
            self.constants.EMIT.INDICATOR)
        self.utils:setComponentColor(self.indicators.battery,
            self.battery_circuit.isFuesed and self.constants.COLOR.RED or self.constants.COLOR.GREEN,
            self.constants.EMIT.INDICATOR)

        self.io_switches.lights.state = self.switches.lights.isLightEnabled
    end

    function PowerControl:updatePowerDisplays()
        self.power_displays.main_produced:setText(string.format("%.1f", self.main_circuit.production / 1000))
        self.power_displays.main_used:setText(string.format("%.1f", self.main_circuit.consumption / 1000))
        self.power_displays.factory_used:setText(string.format("%.1f", self.factory_circuit.consumption / 1000))

        self.battery.mwh:setText(string.format("%.0f MW/h", self.battery_circuit.batteryStore))

        local time = self.battery_circuit.batteryTimeUntilEmpty
        if time == 0 then
            time = self.battery_circuit.batteryTimeUntilFull
            if time == 0 then
                self.battery.remaining_time:setText("-")
            else
                local min = string.format("%.0f", time / 60)
                local seconds = string.format("%02d", math.floor(math.fmod(time, 60)))
                self.battery.remaining_time:setText(min .. ":" .. seconds)
            end
        else
            local min = string.format("%.0f", time / 60)
            local seconds = string.format("%02d", math.floor(math.fmod(time, 60)))
            self.battery.remaining_time:setText(min .. ":" .. seconds)
        end

        self.battery.percentage.limit = 1.0
        local batteryPercent = self.battery_circuit.batteryStorePercent
        self.battery.percentage.percent = batteryPercent

        if batteryPercent >= 0.75 then
            self.utils:setComponentColor(self.battery.percentage, self.constants.COLOR.GREEN,
                self.constants.EMIT.OFF)
        elseif batteryPercent >= 0.5 then
            self.utils:setComponentColor(self.battery.percentage, self.constants.COLOR.YELLOW,
                self.constants.EMIT.OFF)
        elseif batteryPercent >= 0.25 then
            self.utils:setComponentColor(self.battery.percentage, self.constants.COLOR.ORANGE,
                self.constants.EMIT.OFF)
        else
            self.utils:setComponentColor(self.battery.percentage, self.constants.COLOR.RED,
                self.constants.EMIT.OFF)
        end

        self.utils:setComponentColor(self.battery.charging, self.constants.COLOR.GREEN,
            self.battery_circuit.batteryTimeUntilFull > 0 and self.constants.EMIT.INDICATOR or self.constants.EMIT.OFF)

        self.utils:setComponentColor(self.battery.on_batteries, self.constants.COLOR.GREEN,
            self.battery_circuit.batteryTimeUntilEmpty > 0 and self.constants.EMIT.INDICATOR, self.constants.EMIT.OFF)
    end

    function PowerControl:broadcastPowerStatus()
        if self.networkCard then
            self.networkCard:broadcast(100, "power_update", {
                grid = {
                    production = self.main_circuit.production,
                    consumption = self.main_circuit.consumption,
                    isFused = self.main_circuit.isFuesed,
                    isOn = self.power_switch.isSwitchOn
                },
                factory = {
                    consumption = self.factory_circuit.consumption,
                    isFused = self.factory_circuit.isFuesed
                },
                battery = {
                    storePercent = self.battery_circuit.batteryStorePercent,
                    timeUntilEmpty = self.battery_circuit.batteryTimeUntilEmpty,
                    timeUntilFull = self.battery_circuit.batteryTimeUntilFull,
                    isOn = self.switches.battery.isSwitchOn,
                    isFused = self.battery_circuit.isFuesed
                }
            })
        end
    end

    function PowerControl:update()
        self:updatePowerDisplays()
        self:broadcastPowerStatus()
    end

    function PowerControl:handleNetworkMessage(type, data)
        if type == "grid" then
            if data then
                self.switches.power:setIsSwitchOn(true)
            else
                self.switches.power:setIsSwitchOn(false)
            end
            self:updatePowerIndicators()
        end
    end

    return PowerControl
end
