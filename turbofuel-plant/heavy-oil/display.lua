-- turbofuel-plant/heavy-oil/display.lua
return function(dependencies)
    local colors = dependencies.colors
    local config = dependencies.config

    local Display = {
        panel = nil,
        modules = {
            factory = {
                buttons = {},
                gauges = {},
                emergency_stop = nil,
                health_indicator = nil,
                productivity_display = nil
            },
            power = {
                switches = {
                    MAIN = nil,
                    BATTERY = nil
                },
                indicators = {
                    MAIN = nil,
                    MAIN_SWITCH = nil,
                    FACTORY = nil,
                    BATTERY_SWITCH = nil,
                    BATTERY = nil
                },
                BATTERY = {
                    REMAINING_TIME = nil,
                    ON_BATTERIES = nil,
                    CHARGING = nil,
                    PERCENTAGE = nil,
                    MWH = nil
                },
                POWER_DISPLAYS = {
                    MAIN_PRODUCED = nil,
                    MAIN_USED = nil,
                    FACTORY_USED = nil
                }
            },
            flow = {
                gauges = {
                    crude = {},
                    heavy = {}
                },
                displays = {
                    crude = {},
                    heavy = {},
                    polymer = nil,
                    total_crude_in = nil,
                    total_heavy_out = nil,
                    total_polymer = nil
                },
                knobs = {
                    crude = {},
                    heavy = {}
                }
            }
        }
    }

    -- Helper function to get module safely
    local function getModuleIfExists(panel, x, y, z)
        local success, module = pcall(function()
            return panel:getModule(x, y, z)
        end)
        return success and module or nil
    end

    function Display:initializeMachineRow(startX, startY, panelNum, count)
        for i = 0, count - 1 do
            local buttonIndex = #self.modules.factory.buttons + 1
            local x = startX + i

            -- Initialize button
            local button = getModuleIfExists(self.panel, x, startY, panelNum)
            if button then
                self.modules.factory.buttons[buttonIndex] = button

                -- Initialize corresponding gauge (one unit above button)
                local gauge = getModuleIfExists(self.panel, x, startY + 1, panelNum)
                if gauge then
                    self.modules.factory.gauges[buttonIndex] = gauge
                end
            end
        end
    end

    function Display:initializeValveFlowBlock(startX, startY, panelNum, type, count)
        -- Ensure arrays exist for this type
        self.modules.flow.gauges[type] = self.modules.flow.gauges[type] or {}
        self.modules.flow.displays[type] = self.modules.flow.displays[type] or {}
        self.modules.flow.knobs[type] = self.modules.flow.knobs[type] or {}

        local y = startY
        for i = 0, count do
            -- Initialize gauge
            local gauge = getModuleIfExists(self.panel, startX, y, panelNum)
            if gauge then
                gauge.limit = 1
                gauge.percent = 0
                self.modules.flow.gauges[type][i] = gauge
            end

            -- Initialize display
            local display = getModuleIfExists(self.panel, startX + 2, y + 1, panelNum)
            if display then
                display:setText("0.0 m³/s")
                self.modules.flow.displays[type][i] = display
            end

            y = y - 3
        end

        -- Initialize total display if needed
        if count > 1 then
            local totalDisplayX = startX + 1
            local totalDisplayY = y + 1

            local total_display = getModuleIfExists(self.panel, totalDisplayX, totalDisplayY, panelNum)
            if total_display then
                total_display:setText("0.0 m³/s")
                self.modules.flow.displays["total_" .. type] = total_display
            end
        end
    end

    function Display:initializeItemFlowBlock(startX, startY, panelNum, type)
        -- Initialize gauge
        local gauge = getModuleIfExists(self.panel, startX, startY, panelNum)
        if gauge then
            gauge.limit = 1
            self.modules.flow.gauges[type] = gauge
        end

        -- Initialize display
        local display = getModuleIfExists(self.panel, startX + 2, startY + 1, panelNum)
        if display then
            display:setText("0.0 items/s")
            self.modules.flow.displays["produced_" .. type] = display
        end
    end

    function Display:initializeFactoryModules()
        -- Initialize machine rows
        self:initializeMachineRow(1, 2, 0, 10)
        self:initializeMachineRow(1, 0, 0, 10)
        self:initializeMachineRow(1, 7, 0, 10)
        self:initializeMachineRow(1, 5, 0, 10)

        -- Initialize other factory modules
        self.modules.factory.emergency_stop = self.panel:getModule(10, 10, 0)
        self.modules.factory.health_indicator = self.panel:getModule(1, 10, 0)
        self.modules.factory.productivity_display = self.panel:getModule(2, 9, 0)
    end

    function Display:initializeFlowModules()
        -- Initialize solid flow displays (polymer)
        self:initializeItemFlowBlock(4, 2, 1, "polymer")

        -- Initialize liquid flow blocks
        self:initializeValveFlowBlock(0, 5, 1, "crude", 2) -- Crude oil
        self:initializeValveFlowBlock(7, 8, 1, "heavy", 3) -- Heavy oil
    end

    function Display:initializePowerModules()
        -- Initialize power switches
        self.modules.power.switches.MAIN = self.panel:getModule(2, 0, 2)
        self.modules.power.switches.BATTERY = self.panel:getModule(6, 0, 2)

        self.modules.power.switches.REMOTE_CONTROL = self.panel:getModule(9, 0, 2)
        self.modules.power.switches.Lights = self.panel:getModule(10, 0, 2)

        -- Initialize power indicators
        self.modules.power.indicators.MAIN = self.panel:getModule(0, 1, 2)
        self.modules.power.indicators.MAIN_SWITCH = self.panel:getModule(2, 1, 2)
        self.modules.power.indicators.FACTORY = self.panel:getModule(4, 1, 2)
        self.modules.power.indicators.BATTERY_SWITCH = self.panel:getModule(6, 1, 2)
        self.modules.power.indicators.BATTERY = self.panel:getModule(8, 1, 2)

        -- Initialize battery displays
        self.modules.power.BATTERY.REMAINING_TIME = self.panel:getModule(9, 3, 2)
        self.modules.power.BATTERY.ON_BATTERIES = self.panel:getModule(9, 4, 2)
        self.modules.power.BATTERY.CHARGING = self.panel:getModule(9, 5, 2)
        self.modules.power.BATTERY.PERCENTAGE = self.panel:getModule(9, 6, 2)
        self.modules.power.BATTERY.MWH = self.panel:getModule(7, 6, 2)

        -- Initialize power displays
        self.modules.power.POWER_DISPLAYS.MAIN_PRODUCED = self.panel:getModule(0, 3, 2)
        self.modules.power.POWER_DISPLAYS.MAIN_USED = self.panel:getModule(1, 3, 2)
        self.modules.power.POWER_DISPLAYS.FACTORY_USED = self.panel:getModule(4, 3, 2)
    end

    function Display:new(display_panel)
        print("Creating new display instance...")
        if not display_panel then
            error("Display panel is required")
        end

        -- Test the panel immediately
        print("Testing panel in new()...")
        local success = pcall(function()
            local test_module = display_panel:getModule(0, 0, 0)
            print("Test module retrieved:", test_module ~= nil)
        end)
        print("Panel test result:", success)

        if not success then
            error("Display panel does not support getModule method")
        end

        local instance = {}
        setmetatable(instance, { __index = self })
        instance.panel = display_panel

        return instance
    end

    function Display:initialize()
        print("Starting display initialization...")
        -- Test panel at start of initialize
        local test = pcall(function()
            local module = self.panel:getModule(0, 0, 0)
            print("Initialize test module:", module ~= nil)
        end)
        print("Initialize panel test:", test)

        -- Initialize all module types
        self:initializeFactoryModules()
        self:initializeFlowModules()
        self:initializePowerModules()

        return self.modules
    end

    return Display
end
