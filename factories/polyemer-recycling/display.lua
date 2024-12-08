-- factories/polymer-recycling/display.lua
return function(dependencies)
    local colors = dependencies.colors
    local config = dependencies.config

    local Display = {
        panel = nil,
        modules = {
            rubber = {
                buttons = {},
                gauges = {},
                emergency_stop = nil,
                health_indicator = nil,
                productivity_display = nil,
                constructors = {
                    buttons = {},
                    gauges = {}
                }
            },
            plastic = {
                buttons = {},
                gauges = {},
                emergency_stop = nil,
                health_indicator = nil,
                productivity_display = nil,
                constructors = {
                    buttons = {},
                    gauges = {}
                }
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
                    water = {},
                    fuel = {}
                },
                displays = {
                    water = {},
                    fuel = {},
                    rubber = nil,
                    plastic = nil
                },
                knobs = {
                    water = {},
                    fuel = {}
                }
            }
        }
    }

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

    function Display:initialize(panel_type)
        print("Starting display initialization for " .. panel_type .. " panel...")
        -- Test panel at start of initialize
        local test = pcall(function()
            local module = self.panel:getModule(0, 0, 0)
            print("Initialize test module:", module ~= nil)
        end)
        print("Initialize panel test:", test)

        if panel_type == "rubber" then
            self:initializeRubberModules()
            self:initializeFlowModules("rubber")
            self:initializePowerModules()
        elseif panel_type == "plastic" then
            self:initializePlasticModules()
            self:initializeFlowModules("plastic")
        else
            error("Invalid panel type: " .. panel_type)
        end

        return self.modules[panel_type]
    end

    function Display:initializeRubberModules()
        -- Initialize rubber refinery buttons (2 rows of 10)
        local refinery_button_coords = {
            { 1, 2, 0 }, { 2, 2, 0 }, { 3, 2, 0 }, { 4, 2, 0 }, { 5, 2, 0 }, { 6, 2, 0 }, { 7, 2, 0 }, { 8, 2, 0 }, { 9, 2, 0 }, { 10, 2, 0 },
            { 1, 0, 0 }, { 2, 0, 0 }, { 3, 0, 0 }, { 4, 0, 0 }, { 5, 0, 0 }, { 6, 0, 0 }, { 7, 0, 0 }, { 8, 0, 0 }, { 9, 0, 0 }, { 10, 0, 0 }
        }

        -- Initialize rubber refinery gauges
        local refinery_gauge_coords = {
            { 1, 3, 0 }, { 2, 3, 0 }, { 3, 3, 0 }, { 4, 3, 0 }, { 5, 3, 0 }, { 6, 3, 0 }, { 7, 3, 0 }, { 8, 3, 0 }, { 9, 3, 0 }, { 10, 3, 0 },
            { 1, 1, 0 }, { 2, 1, 0 }, { 3, 1, 0 }, { 4, 1, 0 }, { 5, 1, 0 }, { 6, 1, 0 }, { 7, 1, 0 }, { 8, 1, 0 }, { 9, 1, 0 }, { 10, 1, 0 }
        }

        -- Initialize constructor buttons (2 rows of 6)
        local constructor_button_coords = {
            { 1, 7, 0 }, { 2, 7, 0 }, { 3, 7, 0 }, { 4, 7, 0 }, { 5, 7, 0 }, { 6, 7, 0 },
            { 1, 5, 0 }, { 2, 5, 0 }, { 3, 5, 0 }, { 4, 5, 0 }, { 5, 5, 0 }, { 6, 5, 0 }
        }

        -- Initialize constructor gauges
        local constructor_gauge_coords = {
            { 1, 8, 0 }, { 2, 8, 0 }, { 3, 8, 0 }, { 4, 8, 0 }, { 5, 8, 0 }, { 6, 8, 0 },
            { 1, 6, 0 }, { 2, 6, 0 }, { 3, 6, 0 }, { 4, 6, 0 }, { 5, 6, 0 }, { 6, 6, 0 }
        }

        -- Initialize refinery components
        for i, coords in ipairs(refinery_button_coords) do
            self.modules.rubber.buttons[i] = self.panel:getModule(table.unpack(coords))
        end

        for i, coords in ipairs(refinery_gauge_coords) do
            self.modules.rubber.gauges[i] = self.panel:getModule(table.unpack(coords))
            self.modules.rubber.gauges[i].limit = 100
        end

        -- Initialize constructor components
        for i, coords in ipairs(constructor_button_coords) do
            self.modules.rubber.constructors.buttons[i] = self.panel:getModule(table.unpack(coords))
        end

        for i, coords in ipairs(constructor_gauge_coords) do
            self.modules.rubber.constructors.gauges[i] = self.panel:getModule(table.unpack(coords))
            self.modules.rubber.constructors.gauges[i].limit = 100
        end

        -- Initialize other rubber modules
        self.modules.rubber.emergency_stop = self.panel:getModule(10, 10, 0)
        self.modules.rubber.health_indicator = self.panel:getModule(1, 10, 0)
        self.modules.rubber.productivity_display = self.panel:getModule(2, 9, 0)
    end

    function Display:initializePlasticModules()
        -- Initialize plastic refinery buttons (1 row of 12)
        local refinery_button_coords = {
            { 1, 2, 0 }, { 2, 2, 0 }, { 3, 2, 0 }, { 4, 2, 0 }, { 5, 2, 0 }, { 6, 2, 0 },
            { 7, 2, 0 }, { 8, 2, 0 }, { 9, 2, 0 }, { 10, 2, 0 }, { 11, 2, 0 }, { 12, 2, 0 }
        }

        -- Initialize plastic refinery gauges
        local refinery_gauge_coords = {
            { 1, 3, 0 }, { 2, 3, 0 }, { 3, 3, 0 }, { 4, 3, 0 }, { 5, 3, 0 }, { 6, 3, 0 },
            { 7, 3, 0 }, { 8, 3, 0 }, { 9, 3, 0 }, { 10, 3, 0 }, { 11, 3, 0 }, { 12, 3, 0 }
        }

        -- Initialize constructor buttons (2 rows of 12)
        local constructor_button_coords = {
            { 1, 7, 0 }, { 2, 7, 0 }, { 3, 7, 0 }, { 4, 7, 0 }, { 5, 7, 0 }, { 6, 7, 0 },
            { 7, 7, 0 }, { 8, 7, 0 }, { 9, 7, 0 }, { 10, 7, 0 }, { 11, 7, 0 }, { 12, 7, 0 },
            { 1, 5, 0 }, { 2, 5, 0 }, { 3, 5, 0 }, { 4, 5, 0 }, { 5, 5, 0 }, { 6, 5, 0 },
            { 7, 5, 0 }, { 8, 5, 0 }, { 9, 5, 0 }, { 10, 5, 0 }, { 11, 5, 0 }, { 12, 5, 0 }
        }

        -- Initialize constructor gauges
        local constructor_gauge_coords = {
            { 1, 8, 0 }, { 2, 8, 0 }, { 3, 8, 0 }, { 4, 8, 0 }, { 5, 8, 0 }, { 6, 8, 0 },
            { 7, 8, 0 }, { 8, 8, 0 }, { 9, 8, 0 }, { 10, 8, 0 }, { 11, 8, 0 }, { 12, 8, 0 },
            { 1, 6, 0 }, { 2, 6, 0 }, { 3, 6, 0 }, { 4, 6, 0 }, { 5, 6, 0 }, { 6, 6, 0 },
            { 7, 6, 0 }, { 8, 6, 0 }, { 9, 6, 0 }, { 10, 6, 0 }, { 11, 6, 0 }, { 12, 6, 0 }
        }

        -- Initialize refinery components
        for i, coords in ipairs(refinery_button_coords) do
            self.modules.plastic.buttons[i] = self.panel:getModule(table.unpack(coords))
        end

        for i, coords in ipairs(refinery_gauge_coords) do
            self.modules.plastic.gauges[i] = self.panel:getModule(table.unpack(coords))
            self.modules.plastic.gauges[i].limit = 100
        end

        -- Initialize constructor components
        for i, coords in ipairs(constructor_button_coords) do
            self.modules.plastic.constructors.buttons[i] = self.panel:getModule(table.unpack(coords))
        end

        for i, coords in ipairs(constructor_gauge_coords) do
            self.modules.plastic.constructors.gauges[i] = self.panel:getModule(table.unpack(coords))
            self.modules.plastic.constructors.gauges[i].limit = 100
        end

        -- Initialize other plastic modules
        self.modules.plastic.emergency_stop = self.panel:getModule(10, 10, 0)
        self.modules.plastic.health_indicator = self.panel:getModule(1, 10, 0)
        self.modules.plastic.productivity_display = self.panel:getModule(2, 9, 0)
    end

    function Display:initializeFlowModules(panel_type)
        if panel_type == "rubber" then
            -- Initialize flow gauges for rubber panel
            self.modules.flow.gauges.water[1] = self.panel:getModule(0, 5, 1)
            self.modules.flow.gauges.water[2] = self.panel:getModule(0, 2, 1)
            self.modules.flow.gauges.fuel[1] = self.panel:getModule(7, 5, 1)

            -- Initialize flow displays
            self.modules.flow.displays.water[1] = self.panel:getModule(2, 6, 1)
            self.modules.flow.displays.water[2] = self.panel:getModule(2, 3, 1)
            self.modules.flow.displays.fuel[1] = self.panel:getModule(9, 6, 1)

            -- Total in/out displays
            self.modules.flow.displays.total_water = self.panel:getModule(1, 0, 1)
            self.modules.flow.displays.canister = self.panel:getModule(5, 0, 1)
            self.modules.flow.displays.rubber = self.panel:getModule(8, 0, 1)
            self.modules.flow.displays.plastic = self.panel:getModule(8, 0, 1)

            -- Initialize flow knobs
            self.modules.flow.knobs.water[1] = self.panel:getModule(2, 5, 1)
            self.modules.flow.knobs.water[2] = self.panel:getModule(2, 2, 1)
            self.modules.flow.knobs.fuel[1] = self.panel:getModule(9, 5, 1)
        else
            -- Initialize flow displays for plastic panel
            self.modules.flow.displays.plastic = self.panel:getModule(5, 0, 1)
        end
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
