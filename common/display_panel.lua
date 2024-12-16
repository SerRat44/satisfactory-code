-- common/display_panel.lua

return function()
    local Display = {}

    -- Initializes a row of machine buttons and gauges. Outputs two tables: table 1 contains the buttons, table 2 contains the gauges.
    function Display:initializeMachineRow(panel, startX, startY, panelNum, count)
        local buttons = {}
        local gauges = {}

        for i = 0, count - 1 do
            local buttonIndex = #buttons + 1
            local gaugeIndex = #gauges + 1
            local x = startX + i

            -- Initialize button
            local button = panel:getModule(x, startY, panelNum)
            if button then
                buttons[buttonIndex] = button

                -- Initialize corresponding gauge (one unit above button)
                local gauge = panel:getModule(x, startY + 1, panelNum)
                if gauge then
                    gauges[gaugeIndex] = gauge
                end
            end
        end

        return buttons, gauges
    end

    function Display:initializeFlowBlock(panel, startX, startY, panelNum, type)
        -- Initialize gauge
        local gauge = self:getModuleIfExists(panel, startX, startY, panelNum)
        if gauge then
            self.modules.flow.gauges[type] = gauge
        end

        -- Initialize displays
        local display1 = self:getModuleIfExists(panel, startX + 2, startY + 1, panelNum)
        if display1 then
            self.modules.flow.displays[type] = display1
        end

        local display2 = self:getModuleIfExists(panel, startX + 2, startY, panelNum)
        if display2 then
            self.modules.flow.displays[type] = display2
        end
    end

    function Display:initializeFlowModules()
        self:initializeFlowBlock(0, 0, 1)
        self:initializeFlowBlock(7, 3, 1)
        self:initializeFlowBlock(7, 0, 1)
    end

    function Display:initializePowerModules()
        -- Create necessary tables
        self.modules.power.switches = self.modules.power.switches or {}
        self.modules.power.indicators = self.modules.power.indicators or {}
        self.modules.power.BATTERY = self.modules.power.BATTERY or {}
        self.modules.power.POWER_DISPLAYS = self.modules.power.POWER_DISPLAYS or {}

        -- Initialize power switches
        self.modules.power.switches.MAIN = self.panel:getModule(2, 0, 2)
        self.modules.power.switches.BATTERY = self.panel:getModule(6, 0, 2)
        self.modules.power.switches.LIGHTS = self.panel:getModule(10, 0, 2)

        -- Initialize power indicators
        self.modules.power.indicators.MAIN = self.panel:getModule(0, 1, 2)
        self.modules.power.indicators.MAIN_SWITCH = self.panel:getModule(2, 2, 2)
        self.modules.power.indicators.FACTORY = self.panel:getModule(4, 1, 2)
        self.modules.power.indicators.BATTERY_SWITCH = self.panel:getModule(6, 2, 2)
        self.modules.power.indicators.BATTERY = self.panel:getModule(8, 1, 2)

        -- Initialize battery displays
        self.modules.power.BATTERY.REMAINING_TIME = self.panel:getModule(9, 3, 2)
        self.modules.power.BATTERY.ON_BATTERIES = self.panel:getModule(9, 4, 2)
        self.modules.power.BATTERY.CHARGING = self.panel:getModule(9, 5, 2)
        self.modules.power.BATTERY.PERCENTAGE = self.panel:getModule(9, 6, 2)
        self.modules.power.BATTERY.MWH = self.panel:getModule(7, 6, 2)

        -- Initialize power displays
        self.modules.power.POWER_DISPLAYS.MAIN_USED = self.panel:getModule(0, 3, 2)
        self.modules.power.POWER_DISPLAYS.MAIN_PRODUCED = self.panel:getModule(1, 3, 2)
        self.modules.power.POWER_DISPLAYS.FACTORY_USED = self.panel:getModule(4, 3, 2)
    end

    return Display
end
