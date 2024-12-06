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
                    polymer = nil
                },
                knobs = {
                    crude = {},
                    heavy = {}
                }
            }
        }
    }

    function Display:new(display_panel)
        local instance = {}
        setmetatable(instance, { __index = self })
        instance.panel = display_panel
        return instance
    end

    function Display:initialize()
        -- Factory panel initialization
        self:initializeFactoryModules()
        self:initializeFlowModules()
        self:initializePowerModules()
        return self.modules
    end

    function Display:initializeFactoryModules()
        -- Initialize refinery buttons
        local button_coords = {
            { 1, 2, 0 }, { 2, 2, 0 }, { 3, 2, 0 }, { 4, 2, 0 }, { 5, 2, 0 }, { 6, 2, 0 }, { 7, 2, 0 }, { 8, 2, 0 }, { 9, 2, 0 }, { 10, 2, 0 },
            { 1, 0, 0 }, { 2, 0, 0 }, { 3, 0, 0 }, { 4, 0, 0 }, { 5, 0, 0 }, { 6, 0, 0 }, { 7, 0, 0 }, { 8, 0, 0 }, { 9, 0, 0 }, { 10, 0, 0 },
            { 1, 7, 0 }, { 2, 7, 0 }, { 3, 7, 0 }, { 4, 7, 0 }, { 5, 7, 0 }, { 6, 7, 0 }, { 7, 7, 0 }, { 8, 7, 0 }, { 9, 7, 0 }, { 10, 7, 0 },
            { 1, 5, 0 }, { 2, 5, 0 }, { 3, 5, 0 }, { 4, 5, 0 }, { 5, 5, 0 }, { 6, 5, 0 }, { 7, 5, 0 }, { 8, 5, 0 }, { 9, 5, 0 }, { 10, 5, 0 }
        }

        -- Initialize refinery gauges
        local gauge_coords = {
            { 1, 3, 0 }, { 2, 3, 0 }, { 3, 3, 0 }, { 4, 3, 0 }, { 5, 3, 0 }, { 6, 3, 0 }, { 7, 3, 0 }, { 8, 3, 0 }, { 9, 3, 0 }, { 10, 3, 0 },
            { 1, 1, 0 }, { 2, 1, 0 }, { 3, 1, 0 }, { 4, 1, 0 }, { 5, 1, 0 }, { 6, 1, 0 }, { 7, 1, 0 }, { 8, 1, 0 }, { 9, 1, 0 }, { 10, 1, 0 },
            { 1, 8, 0 }, { 2, 8, 0 }, { 3, 8, 0 }, { 4, 8, 0 }, { 5, 8, 0 }, { 6, 8, 0 }, { 7, 8, 0 }, { 8, 8, 0 }, { 9, 8, 0 }, { 10, 8, 0 },
            { 1, 6, 0 }, { 2, 6, 0 }, { 3, 6, 0 }, { 4, 6, 0 }, { 5, 6, 0 }, { 6, 6, 0 }, { 7, 6, 0 }, { 8, 6, 0 }, { 9, 6, 0 }, { 10, 6, 0 }
        }

        for i, coords in ipairs(button_coords) do
            self.modules.factory.buttons[i] = self.panel:getModule(table.unpack(coords))
        end

        for i, coords in ipairs(gauge_coords) do
            self.modules.factory.gauges[i] = self.panel:getModule(table.unpack(coords))
            self.modules.factory.gauges[i].limit = 100
        end

        -- Initialize other factory modules
        self.modules.factory.emergency_stop = self.panel:getModule(10, 10, 0)
        self.modules.factory.health_indicator = self.panel:getModule(1, 10, 0)
        self.modules.factory.productivity_display = self.panel:getModule(2, 9, 0)
    end

    function Display:initializeFlowModules()
        -- Initialize flow gauges
        self.modules.flow.gauges.crude[1] = self.panel:getModule(0, 3, 1)
        self.modules.flow.gauges.crude[2] = self.panel:getModule(0, 0, 1)
        self.modules.flow.gauges.heavy[1] = self.panel:getModule(7, 6, 1)
        self.modules.flow.gauges.heavy[2] = self.panel:getModule(7, 3, 1)
        self.modules.flow.gauges.heavy[3] = self.panel:getModule(7, 0, 1)

        -- Initialize flow knobs
        self.modules.flow.knobs.crude[1] = self.panel:getModule(2, 3, 1)
        self.modules.flow.knobs.crude[2] = self.panel:getModule(2, 0, 1)
        self.modules.flow.knobs.heavy[1] = self.panel:getModule(9, 6, 1)
        self.modules.flow.knobs.heavy[2] = self.panel:getModule(9, 3, 1)
        self.modules.flow.knobs.heavy[3] = self.panel:getModule(9, 0, 1)

        -- Initialize flow displays
        self.modules.flow.displays.crude[1] = self.panel:getModule(2, 4, 1)
        self.modules.flow.displays.crude[2] = self.panel:getModule(2, 1, 1)
        self.modules.flow.displays.heavy[1] = self.panel:getModule(9, 7, 1)
        self.modules.flow.displays.heavy[2] = self.panel:getModule(9, 4, 1)
        self.modules.flow.displays.heavy[3] = self.panel:getModule(9, 1, 1)
        self.modules.flow.displays.polymer = self.panel:getModule(5, 1, 1)
    end

    function Display:initializePowerModules()
        -- Initialize power switches
        self.modules.power.switches.MAIN = self.panel:getModule(3, 0, 2)
        self.modules.power.switches.BATTERY = self.panel:getModule(7, 0, 2)

        -- Initialize power indicators
        self.modules.power.indicators.MAIN = self.panel:getModule(1, 1, 2)
        self.modules.power.indicators.MAIN_SWITCH = self.panel:getModule(3, 1, 2)
        self.modules.power.indicators.FACTORY = self.panel:getModule(5, 1, 2)
        self.modules.power.indicators.BATTERY_SWITCH = self.panel:getModule(7, 1, 2)
        self.modules.power.indicators.BATTERY = self.panel:getModule(9, 1, 2)

        -- Initialize battery displays
        self.modules.power.BATTERY.REMAINING_TIME = self.panel:getModule(9, 3, 2)
        self.modules.power.BATTERY.ON_BATTERIES = self.panel:getModule(9, 4, 2)
        self.modules.power.BATTERY.CHARGING = self.panel:getModule(9, 5, 2)
        self.modules.power.BATTERY.PERCENTAGE = self.panel:getModule(9, 6, 2)
        self.modules.power.BATTERY.MWH = self.panel:getModule(7, 6, 2)

        -- Initialize power displays
        self.modules.power.POWER_DISPLAYS.MAIN_PRODUCED = self.panel:getModule(1, 3, 2)
        self.modules.power.POWER_DISPLAYS.MAIN_USED = self.panel:getModule(2, 3, 2)
        self.modules.power.POWER_DISPLAYS.FACTORY_USED = self.panel:getModule(5, 3, 2)
    end

    return Display
end
