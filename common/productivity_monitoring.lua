-- turbofuel-plant/common/productivity_monitoring.lua

local ProductivityMonitoring = {
    display = nil,
    machines = {},
    productivity_history = {},
    current_productivity = 0,
    emergency_state = false,
    networkCard = nil,
    light_switch = nil
}

function ProductivityMonitoring:new(dependencies)
    local instance = {}
    setmetatable(instance, { __index = self })
    instance.display = dependencies.display
    instance.colors = dependencies.colors
    instance.utils = dependencies.utils
    instance.config = dependencies.config
    instance.productivity_history = {}

    -- Initialize network card
    instance.networkCard = computer.getPCIDevices(classes.NetworkCard)[1]
    if not instance.networkCard then
        error("Network card not found in Productivity Monitoring module")
    end

    return instance
end

function ProductivityMonitoring:initialize(config)
    -- Initialize light switch
    self.light_switch = component.proxy(config.COMPONENT_IDS.LIGHT_SWITCH)
    if not self.light_switch then
        error("Light switch not found")
    end

    -- Initialize machines based on config
    for i, id in ipairs(config.MACHINE_IDS) do
        self.machines[i] = component.proxy(id)
    end

    -- Initialize emergency stop if it exists
    if self.display.factory and self.display.factory.emergency_stop then
        event.listen(self.display.factory.emergency_stop)
        self.utils.setComponentColor(self.display.factory.emergency_stop, self.colors.STATUS.OFF, self.colors.EMIT.OFF)
    end
end

function ProductivityMonitoring:handleEmergencyStop()
    self.emergency_state = not self.emergency_state

    if self.emergency_state then
        for _, machine in ipairs(self.machines) do
            if machine then
                machine.standby = true
            end
        end
        self.utils.setComponentColor(self.display.factory.emergency_stop, self.colors.STATUS.OFF, self.colors.EMIT
            .BUTTON)
        self.utils.setComponentColor(self.display.factory.health_indicator, self.colors.STATUS.OFF,
            self.colors.EMIT.INDICATOR)
        self.light_switch.colorSlot = 1
    else
        self.light_switch.colorSlot = 6
        self.utils.setComponentColor(self.display.factory.emergency_stop, self.colors.STATUS.OFF, self.colors.EMIT.OFF)
        for _, machine in ipairs(self.machines) do
            if machine then
                machine.standby = false
            end
        end
        self:updateProductivityIndicator()
    end

    self:updateAllButtons()
end

function ProductivityMonitoring:handleButtonPress(button_id)
    local machine = self.machines[button_id]
    if machine then
        machine.standby = not machine.standby
        self:updateButtonColor(button_id)
    end
end

function ProductivityMonitoring:updateProductivityDisplay()
    local current_prod = utils.getAvgProductivity()

    -- Update gauges and button colors
    for i, machine in ipairs(self.machines) do
        if self.display.factory.gauges[i] then
            if machine and not machine.standby then
                local prod = machine.productivity
                self.display.factory.gauges[i].limit = 1
                self.display.factory.gauges[i].percent = prod
                self:updateGaugeColor(self.display.factory.gauges[i], prod)
            else
                self.display.factory.gauges[i].percent = 0
                self.utils.setComponentColor(self.display.factory.gauges[i], self.colors.STATUS.OFF,
                    self.colors.EMIT.GAUGE)
            end
        end
        self:updateButtonColor(i)
    end

    if #self.productivity_history > self.config.HISTORY_LENGTH then
        table.remove(self.productivity_history, 1)
    end

    self:updateProductivityIndicator()
    return current_prod
end

function ProductivityMonitoring:updateProductivityIndicator()
    if self.emergency_state then
        self.utils.setComponentColor(self.display.factory.health_indicator, self.colors.STATUS.OFF,
            self.colors.EMIT.INDICATOR)
    else
        if self.current_productivity >= 0.95 then
            self.utils.setComponentColor(self.display.factory.health_indicator, self.colors.STATUS.WORKING,
                self.colors.EMIT.INDICATOR)
        elseif self.current_productivity >= 0.5 then
            self.utils.setComponentColor(self.display.factory.health_indicator, self.colors.STATUS.WARNING,
                self.colors.EMIT.INDICATOR)
        else
            self.utils.setComponentColor(self.display.factory.health_indicator, self.colors.STATUS.IDLE,
                self.colors.EMIT.INDICATOR)
        end
    end
end

function ProductivityMonitoring:updateButtonColor(index)
    if self.display.factory.buttons[index] and self.machines[index] then -- Changed from self.refineries
        local machine = self.machines[index]                             -- Changed from refinery

        -- First check if machine exists and is not in standby
        if not machine or machine.standby then
            self.utils.setComponentColor(self.display.factory.buttons[index], self.colors.STATUS.OFF,
                self.colors.EMIT.BUTTON)
            return
        end

        -- Get productivity value
        local productivity = machine.productivity

        -- Set color based on productivity thresholds
        if productivity >= 0.95 then
            self.utils.setComponentColor(self.display.factory.buttons[index], self.colors.STATUS.WORKING,
                self.colors.EMIT.BUTTON)
        elseif productivity >= 0.5 then
            self.utils.setComponentColor(self.display.factory.buttons[index], self.colors.STATUS.IDLE,
                self.colors.EMIT.BUTTON)
        else
            self.utils.setComponentColor(self.display.factory.buttons[index], self.colors.STATUS.WARNING,
                self.colors.EMIT.BUTTON)
        end
    end
end

function ProductivityMonitoring:updateGaugeColor(gauge, percent)
    if not gauge then return end

    if percent >= 0.95 then
        self.utils.setComponentColor(gauge, self.colors.STATUS.WORKING, self.colors.EMIT.GAUGE)
    elseif percent >= 0.5 then
        self.utils.setComponentColor(gauge, self.colors.STATUS.IDLE, self.colors.EMIT.GAUGE)
    else
        self.utils.setComponentColor(gauge, self.colors.STATUS.WARNING, self.colors.EMIT.GAUGE)
    end
end

function ProductivityMonitoring:updateAllButtons()
    for i = 1, #self.display.factory.buttons do
        self:updateButtonColor(i)
    end
end

function ProductivityMonitoring:getMachineStatus(machine)
    if not machine then return "OFF" end
    if machine.standby then return "OFF" end

    local productivity = tonumber(machine.productivity) or 0

    if productivity >= 0.95 then
        return "WORKING"
    elseif productivity >= 0.50 then
        return "WARNING"
    else
        return "IDLE"
    end
end

function ProductivityMonitoring:broadcastMachineStatus()
    for i, machine in ipairs(self.machines) do
        local status = self:getMachineStatus(machine)           -- Renamed from getRefineryStatus
        if self.networkCard then
            self.networkCard:broadcast(100, "machine_update", { -- Changed from refinery_update
                "machine_" .. i,                                -- Changed from refinery_
                status,
                machine.productivity
            })
        end
    end
end

function ProductivityMonitoring:cleanup()
    if self.display and self.display.factory and self.display.factory.emergency_stop then
        event.clear(self.display.factory.emergency_stop)
    end
end

return ProductivityMonitoring
