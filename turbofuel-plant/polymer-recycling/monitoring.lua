-- factories/polymer-recycling/monitoring.lua

local Monitoring = {
    rubber_refineries = {},
    plastic_refineries = {},
    constructors = {},
    productivity_history = {
        rubber = {},
        plastic = {},
        constructors = {}
    },
    current_productivity = {
        rubber = 0,
        plastic = 0,
        constructors = 0
    },
    emergency_state = false,
    display = nil,
    networkCard = nil,
    light_switch = nil
}

function Monitoring:new(display, dependencies)
    local instance = {}
    setmetatable(instance, { __index = self })
    instance.display = display
    instance.colors = dependencies.colors
    instance.utils = dependencies.utils
    instance.config = dependencies.config
    instance.productivity_history = {
        rubber = {},
        plastic = {},
        constructors = {}
    }

    -- Initialize network card
    instance.networkCard = computer.getPCIDevices(classes.NetworkCard)[1]
    if not instance.networkCard then
        error("Network card not found in Monitoring module")
    end

    return instance
end

function Monitoring:initialize()
    -- Initialize light switch
    self.light_switch = component.proxy(self.config.COMPONENT_IDS.LIGHT_SWITCH)
    if not self.light_switch then
        error("Light switch not found")
    end

    -- Initialize rubber refineries
    for i, id in ipairs(self.config.RUBBER_REFINERY_IDS) do
        self.rubber_refineries[i] = component.proxy(id)
    end

    -- Initialize plastic refineries
    for i, id in ipairs(self.config.PLASTIC_REFINERY_IDS) do
        self.plastic_refineries[i] = component.proxy(id)
    end

    -- Initialize constructors
    for i, id in ipairs(self.config.CONSTRUCTOR_IDS) do
        self.constructors[i] = component.proxy(id)
    end

    -- Set up emergency stops
    if self.display.rubber and self.display.rubber.emergency_stop then
        event.listen(self.display.rubber.emergency_stop)
        self.utils.setComponentColor(self.display.rubber.emergency_stop, self.colors.STATUS.OFF, self.colors.EMIT.OFF)
    end
    if self.display.plastic and self.display.plastic.emergency_stop then
        event.listen(self.display.plastic.emergency_stop)
        self.utils.setComponentColor(self.display.plastic.emergency_stop, self.colors.STATUS.OFF, self.colors.EMIT.OFF)
    end
end

function Monitoring:cleanup()
    if self.display.rubber and self.display.rubber.emergency_stop then
        event.clear(self.display.rubber.emergency_stop)
    end
    if self.display.plastic and self.display.plastic.emergency_stop then
        event.clear(self.display.plastic.emergency_stop)
    end
end

function Monitoring:calculateTotalOutput()
    local RUBBER_PER_MINUTE = 30
    local PLASTIC_PER_MINUTE = 40
    local total_rubber = 0
    local total_plastic = 0

    -- Calculate rubber output
    for _, refinery in ipairs(self.rubber_refineries) do
        if refinery and not refinery.standby then
            local productivity = refinery.productivity
            local potential = refinery.potential
            local machine_output = RUBBER_PER_MINUTE * productivity * potential
            total_rubber = total_rubber + machine_output
        end
    end

    -- Calculate plastic output
    for _, refinery in ipairs(self.plastic_refineries) do
        if refinery and not refinery.standby then
            local productivity = refinery.productivity
            local potential = refinery.potential
            local machine_output = PLASTIC_PER_MINUTE * productivity * potential
            total_plastic = total_plastic + machine_output
        end
    end

    return total_rubber, total_plastic
end

function Monitoring:handleEmergencyStop()
    self.emergency_state = not self.emergency_state

    if self.emergency_state then
        -- Stop all machines
        for _, refinery in ipairs(self.rubber_refineries) do
            if refinery then refinery.standby = true end
        end
        for _, refinery in ipairs(self.plastic_refineries) do
            if refinery then refinery.standby = true end
        end
        for _, constructor in ipairs(self.constructors) do
            if constructor then constructor.standby = true end
        end

        -- Update displays
        if self.display.rubber then
            self.utils.setComponentColor(self.display.rubber.emergency_stop, self.colors.STATUS.OFF,
                self.colors.EMIT.BUTTON)
            self.utils.setComponentColor(self.display.rubber.health_indicator, self.colors.STATUS.OFF,
                self.colors.EMIT.INDICATOR)
        end
        if self.display.plastic then
            self.utils.setComponentColor(self.display.plastic.emergency_stop, self.colors.STATUS.OFF,
                self.colors.EMIT.BUTTON)
            self.utils.setComponentColor(self.display.plastic.health_indicator, self.colors.STATUS.OFF,
                self.colors.EMIT.INDICATOR)
        end
        self.light_switch.colorSlot = 1
    else
        -- Restart all machines
        self.light_switch.colorSlot = 6
        if self.display.rubber then
            self.utils.setComponentColor(self.display.rubber.emergency_stop, self.colors.STATUS.OFF, self.colors.EMIT
                .OFF)
        end
        if self.display.plastic then
            self.utils.setComponentColor(self.display.plastic.emergency_stop, self.colors.STATUS.OFF,
                self.colors.EMIT.OFF)
        end

        for _, refinery in ipairs(self.rubber_refineries) do
            if refinery then refinery.standby = false end
        end
        for _, refinery in ipairs(self.plastic_refineries) do
            if refinery then refinery.standby = false end
        end
        for _, constructor in ipairs(self.constructors) do
            if constructor then constructor.standby = false end
        end

        self:updateProductivityIndicators()
    end

    self:updateAllButtons()
end

function Monitoring:updateProductivityHistory()
    -- Update rubber refineries
    if self.display.rubber then
        for i, refinery in ipairs(self.rubber_refineries) do
            if self.display.rubber.gauges[i] then
                if refinery and not refinery.standby then
                    local prod = refinery.productivity
                    self.display.rubber.gauges[i].limit = 1
                    self.display.rubber.gauges[i].percent = prod
                    self:updateGaugeColor(self.display.rubber.gauges[i], prod)
                else
                    self.display.rubber.gauges[i].percent = 0
                    self.utils.setComponentColor(self.display.rubber.gauges[i], self.colors.STATUS.OFF,
                        self.colors.EMIT.GAUGE)
                end
            end
            self:updateButtonColor("rubber", i)
        end
    end

    -- Update plastic refineries
    if self.display.plastic then
        for i, refinery in ipairs(self.plastic_refineries) do
            if self.display.plastic.gauges[i] then
                if refinery and not refinery.standby then
                    local prod = refinery.productivity
                    self.display.plastic.gauges[i].limit = 1
                    self.display.plastic.gauges[i].percent = prod
                    self:updateGaugeColor(self.display.plastic.gauges[i], prod)
                else
                    self.display.plastic.gauges[i].percent = 0
                    self.utils.setComponentColor(self.display.plastic.gauges[i], self.colors.STATUS.OFF,
                        self.colors.EMIT.GAUGE)
                end
            end
            self:updateButtonColor("plastic", i)
        end
    end

    -- Update constructors
    self:updateConstructors()

    -- Calculate and update output displays
    local total_rubber, total_plastic = self:calculateTotalOutput()
    if self.display.rubber and self.display.rubber.flow.displays.rubber then
        self.display.rubber.flow.displays.rubber:setText(string.format("%.1f/min", total_rubber))
    end
    if self.display.plastic and self.display.plastic.flow.displays.plastic then
        self.display.plastic.flow.displays.plastic:setText(string.format("%.1f/min", total_plastic))
    end

    -- Update productivity histories
    self:updateProductivityIndicators()
end

function Monitoring:updateConstructors()
    local rubber_constructors = {}
    local plastic_constructors = {}

    -- Split constructors into rubber and plastic groups
    for i, constructor in ipairs(self.constructors) do
        if i <= 12 then
            rubber_constructors[i] = constructor
        else
            plastic_constructors[i - 12] = constructor
        end
    end

    -- Update rubber constructors
    if self.display.rubber then
        for i, constructor in ipairs(rubber_constructors) do
            if self.display.rubber.constructors.gauges[i] then
                if constructor and not constructor.standby then
                    local prod = constructor.productivity
                    self.display.rubber.constructors.gauges[i].limit = 1
                    self.display.rubber.constructors.gauges[i].percent = prod
                    self:updateGaugeColor(self.display.rubber.constructors.gauges[i], prod)
                else
                    self.display.rubber.constructors.gauges[i].percent = 0
                    self.utils.setComponentColor(self.display.rubber.constructors.gauges[i], self.colors.STATUS.OFF,
                        self.colors.EMIT.GAUGE)
                end
            end
            if self.display.rubber.constructors.buttons[i] then
                self:updateConstructorButtonColor(self.display.rubber.constructors.buttons[i], constructor)
            end
        end
    end

    -- Update plastic constructors
    if self.display.plastic then
        for i, constructor in ipairs(plastic_constructors) do
            if self.display.plastic.constructors.gauges[i] then
                if constructor and not constructor.standby then
                    local prod = constructor.productivity
                    self.display.plastic.constructors.gauges[i].limit = 1
                    self.display.plastic.constructors.gauges[i].percent = prod
                    self:updateGaugeColor(self.display.plastic.constructors.gauges[i], prod)
                else
                    self.display.plastic.constructors.gauges[i].percent = 0
                    self.utils.setComponentColor(self.display.plastic.constructors.gauges[i], self.colors.STATUS.OFF,
                        self.colors.EMIT.GAUGE)
                end
            end
            if self.display.plastic.constructors.buttons[i] then
                self:updateConstructorButtonColor(self.display.plastic.constructors.buttons[i], constructor)
            end
        end
    end
end

function Monitoring:handleButtonPress(button)
    -- Check rubber refineries
    for i, refinery in ipairs(self.rubber_refineries) do
        if self.display.rubber and button == self.display.rubber.buttons[i] then
            refinery.standby = not refinery.standby
            self:updateButtonColor("rubber", i)
            return
        end
    end

    -- Check plastic refineries
    for i, refinery in ipairs(self.plastic_refineries) do
        if self.display.plastic and button == self.display.plastic.buttons[i] then
            refinery.standby = not refinery.standby
            self:updateButtonColor("plastic", i)
            return
        end
    end

    -- Check constructors
    for i, constructor in ipairs(self.constructors) do
        if i <= 12 and self.display.rubber and button == self.display.rubber.constructors.buttons[i] then
            constructor.standby = not constructor.standby
            self:updateConstructorButtonColor(button, constructor)
            return
        elseif i > 12 and self.display.plastic and button == self.display.plastic.constructors.buttons[i - 12] then
            constructor.standby = not constructor.standby
            self:updateConstructorButtonColor(button, constructor)
            return
        end
    end
end

function Monitoring:updateButtonColor(type, index)
    local display = self.display[type]
    local refineries = type == "rubber" and self.rubber_refineries or self.plastic_refineries

    if display and display.buttons[index] and refineries[index] then
        local refinery = refineries[index]

        if not refinery or refinery.standby then
            self.utils.setComponentColor(display.buttons[index], self.colors.STATUS.OFF, self.colors.EMIT.BUTTON)
            return
        end

        local productivity = refinery.productivity

        if productivity >= 0.95 then
            self.utils.setComponentColor(display.buttons[index], self.colors.STATUS.WORKING, self.colors.EMIT.BUTTON)
        elseif productivity >= 0.5 then
            self.utils.setComponentColor(display.buttons[index], self.colors.STATUS.IDLE, self.colors.EMIT.BUTTON)
        else
            self.utils.setComponentColor(display.buttons[index], self.colors.STATUS.WARNING, self.colors.EMIT.BUTTON)
        end
    end
end

function Monitoring:updateConstructorButtonColor(button, constructor)
    if not button then return end

    if not constructor or constructor.standby then
        self.utils.setComponentColor(button, self.colors.STATUS.OFF, self.colors.EMIT.BUTTON)
        return
    end

    local productivity = constructor.productivity

    if productivity >= 0.95 then
        self.utils.setComponentColor(button, self.colors.STATUS.WORKING, self.colors.EMIT.BUTTON)
    elseif productivity >= 0.5 then
        self.utils.setComponentColor(button, self.colors.STATUS.IDLE, self.colors.EMIT.BUTTON)
    else
        self.utils.setComponentColor(button, self.colors.STATUS.WARNING, self.colors.EMIT.BUTTON)
    end
end

function Monitoring:updateGaugeColor(gauge, percent)
    if not gauge then return end

    if percent >= 0.95 then
        self.utils.setComponentColor(gauge, self.colors.STATUS.WORKING, self.colors.EMIT.GAUGE)
    elseif percent >= 0.5 then
        self.utils.setComponentColor(gauge, self.colors.STATUS.IDLE, self.colors.EMIT.GAUGE)
    else
        self.utils.setComponentColor(gauge, self.colors.STATUS.WARNING, self.colors.EMIT.GAUGE)
    end
end

function Monitoring:updateAllButtons()
    -- Update rubber refineries
    if self.display.rubber then
        for i = 1, #self.rubber_refineries do
            self:updateButtonColor("rubber", i)
        end
    end

    -- Update plastic refineries
    if self.display.plastic then
        for i = 1, #self.plastic_refineries do
            self:updateButtonColor("plastic", i)
        end
    end

    -- Update constructors
    self:updateConstructors()
end

function Monitoring:updateProductivityIndicators()
    if self.emergency_state then
        if self.display.rubber then
            self.utils.setComponentColor(self.display.rubber.health_indicator, self.colors.STATUS.OFF,
                self.colors.EMIT.INDICATOR)
        end
        if self.display.plastic then
            self.utils.setComponentColor(self.display.plastic.health_indicator, self.colors.STATUS.OFF,
                self.colors.EMIT.INDICATOR)
        end
        return
    end

    -- Update rubber productivity indicator
    if self.display.rubber then
        local rubber_prod = self:getAvgProductivity("rubber")
        if rubber_prod >= 0.95 then
            self.utils.setComponentColor(self.display.rubber.health_indicator, self.colors.STATUS.WORKING,
                self.colors.EMIT.INDICATOR)
        elseif rubber_prod >= 0.5 then
            self.utils.setComponentColor(self.display.rubber.health_indicator, self.colors.STATUS.WARNING,
                self.colors.EMIT.INDICATOR)
        else
            self.utils.setComponentColor(self.display.rubber.health_indicator, self.colors.STATUS.IDLE,
                self.colors.EMIT.INDICATOR)
        end
    end

    -- Update plastic productivity indicator
    if self.display.plastic then
        local plastic_prod = self:getAvgProductivity("plastic")
        if plastic_prod >= 0.95 then
            self.utils.setComponentColor(self.display.plastic.health_indicator, self.colors.STATUS.WORKING,
                self.colors.EMIT.INDICATOR)
        elseif plastic_prod >= 0.5 then
            self.utils.setComponentColor(self.display.plastic.health_indicator, self.colors.STATUS.WARNING,
                self.colors.EMIT.INDICATOR)
        else
            self.utils.setComponentColor(self.display.plastic.health_indicator, self.colors.STATUS.IDLE,
                self.colors.EMIT.INDICATOR)
        end
    end
end

function Monitoring:getAvgProductivity(type)
    local total_productivity = 0
    local active_machines = 0
    local machines

    if type == "rubber" then
        machines = self.rubber_refineries
    elseif type == "plastic" then
        machines = self.plastic_refineries
    else
        return 0
    end

    for _, machine in ipairs(machines) do
        if machine and not machine.standby then
            total_productivity = total_productivity + machine.productivity
            active_machines = active_machines + 1
        end
    end

    local current_prod = active_machines > 0 and (total_productivity / active_machines) or 0
    table.insert(self.productivity_history[type], current_prod)

    if #self.productivity_history[type] > self.config.HISTORY_LENGTH then
        table.remove(self.productivity_history[type], 1)
    end

    self.current_productivity[type] = current_prod
    return current_prod
end

function Monitoring:getMachineStatus(machine)
    if not machine then return "OFF" end
    if machine.standby then return "OFF" end

    local productivity = tonumber(machine.productivity) or 0

    if productivity >= 0.95 then
        return "WORKING"
    elseif productivity >= 0.5 then
        return "IDLE"
    elseif productivity >= 0 then
        return "WARNING"
    else
        return "OFF"
    end
end

function Monitoring:broadcastRecyclingStatus()
    -- Broadcast rubber refinery status
    for i, refinery in ipairs(self.rubber_refineries) do
        local status = self:getMachineStatus(refinery)
        if self.networkCard then
            self.networkCard:broadcast(100, "rubber_refinery_update", {
                "rubber_refinery_" .. i,
                status,
                refinery.productivity
            })
        end
    end

    -- Broadcast plastic refinery status
    for i, refinery in ipairs(self.plastic_refineries) do
        local status = self:getMachineStatus(refinery)
        if self.networkCard then
            self.networkCard:broadcast(100, "plastic_refinery_update", {
                "plastic_refinery_" .. i,
                status,
                refinery.productivity
            })
        end
    end

    -- Broadcast constructor status
    for i, constructor in ipairs(self.constructors) do
        local status = self:getMachineStatus(constructor)
        if self.networkCard then
            self.networkCard:broadcast(100, "constructor_update", {
                "constructor_" .. i,
                status,
                constructor.productivity
            })
        end
    end

    -- Broadcast total production rates
    local total_rubber, total_plastic = self:calculateTotalOutput()
    if self.networkCard then
        self.networkCard:broadcast(100, "production_update", {
            rubber_output = total_rubber,
            plastic_output = total_plastic
        })
    end
end

return Monitoring
