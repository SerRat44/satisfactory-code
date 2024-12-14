-- turbofuel-plant/common/productivity_monitoring.lua

local ProductivityMonitoring = {
    machines = {},
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
    instance.machines = {}

    -- Initialize network card
    instance.networkCard = computer.getPCIDevices(classes.NetworkCard)[1]
    if not instance.networkCard then
        error("Network card not found in Productivity Monitoring module")
    end

    return instance
end

function ProductivityMonitoring:initialize()
    -- Initialize light switch
    self.light_switch = component.proxy(self.config.POWER.LIGHT_SWITCH)
    if not self.light_switch then
        error("Light switch not found")
    end

    -- Initialize machines
    print("Initializing machines...")
    for i, id in ipairs(self.config.REFINERY_IDS) do
        local machine = component.proxy(id)
        if machine then
            self.machines[i] = machine
            print("Machine " .. i .. " initialized")
        else
            print("Warning: Failed to initialize machine " .. i)
        end
    end

    -- Listen to machine buttons
    if self.display and self.display.factory then
        for i, button in ipairs(self.display.factory.buttons) do
            if button then
                print("Setting up listener for button " .. i)
                event.listen(button)
            end
        end

        -- Initialize emergency stop
        if self.display.factory.emergency_stop then
            print("Setting up emergency stop listener")
            event.listen(self.display.factory.emergency_stop)
        end
    end

    self:updateAllDisplays()
end

function ProductivityMonitoring:handleEmergencyStop()
    print("Emergency stop triggered")
    self.emergency_state = not self.emergency_state

    for _, machine in ipairs(self.machines) do
        if machine then
            machine.standby = self.emergency_state
        end
    end

    self:updateProductivityIndicator()
    self:updateEmergencyButton()

    if self.emergency_state then
        self.light_switch.colorSlot = 1
    else
        self.light_switch.colorSlot = 6
    end

    self:updateAllDisplays()
end

function ProductivityMonitoring:handleButtonPress(button_id)
    print("Button press handled: " .. button_id)
    local machine = self.machines[button_id]
    if machine then
        machine.standby = not machine.standby
        self:updateButton(button_id)
        self:updateGauge(button_id)
        self:updateProdIndicator()
    end
end

function ProductivityMonitoring:avgProductivity()
    local total = 0
    local count = 0
    local avg_productivity

    for _, machine in ipairs(self.machines) do
        if machine then
            total = total + (machine.productivity or 0)
            count = count + 1
        end
    end

    avg_productivity = count > 0 and (total / count) or 0
    return avg_productivity
end

function ProductivityMonitoring:updateGauge(index)
    local gauge = self.display.factory.gauges[index]
    local machine = self.machines[index]

    if gauge then
        gauge.limit = 1

        if machine and not machine.standby then
            local prod = machine.productivity or 0
            gauge.percent = prod
            self.utils:updateGaugeColor(gauge)
        else
            gauge.percent = 0
            self.utils:setComponentColor(gauge, self.colors.COLOR.RED, self.colors.EMIT.OFF)
        end
    end
end

function ProductivityMonitoring:updateProdIndicator()
    if not self.display.factory.avg_productivity_indicator then return end

    if self.emergency_state then
        self.utils:setComponentColor(self.display.factory.health_indicator, self.colors.COLOR.RED,
            self.colors.EMIT.INDICATOR)
        return
    end

    local avgProductivity = self:avgProductivity()
    if avgProductivity >= 0.95 then
        self.utils:setComponentColor(self.display.factory.health_indicator, self.colors.COLOR.GREEN,
            self.colors.EMIT.INDICATOR)
    elseif avgProductivity >= 0.5 then
        self.utils:setComponentColor(self.display.factory.health_indicator, self.colors.COLOR.YELLOW,
            self.colors.EMIT.INDICATOR)
    elseif avgProductivity > 0 then
        self.utils:setComponentColor(self.display.factory.health_indicator, self.colors.COLOR.ORANGE,
            self.colors.EMIT.INDICATOR)
    else
        self.utils:setComponentColor(self.display.factory.health_indicator, self.colors.COLOR.RED,
            self.colors.EMIT.INDICATOR)
    end
end

function ProductivityMonitoring:updateButton(index)
    local button = self.display.factory.buttons[index]
    local machine = self.machines[index]

    if not button or not machine then return end

    if machine.standby then
        self.utils:setComponentColor(button, self.colors.COLOR.RED, self.colors.EMIT.BUTTON)
        return
    end

    local prod = machine.productivity or 0

    if prod >= 0.95 then
        self.utils:setComponentColor(button, self.colors.COLOR.GREEN, self.colors.EMIT.BUTTON)
    elseif prod >= 0.5 then
        self.utils:setComponentColor(button, self.colors.COLOR.YELLOW, self.colors.EMIT.BUTTON)
    else
        self.utils:setComponentColor(button, self.colors.COLOR.ORANGE, self.colors.EMIT.BUTTON)
    end
end

function ProductivityMonitoring:updateEmergencyButton()
    if self.emergency_state then
        self.utils:setComponentColor(self.display.factory.emergency_stop, self.colors.COLOR.RED, self.colors.EMIT.BUTTON)
    else
        self.utils:setComponentColor(self.display.factory.emergency_stop, self.colors.COLOR.RED, self.colors.EMIT.OFF)
    end
end

function ProductivityMonitoring:updateAllDisplays()
    for i = 1, #self.machines do
        self:updateButton(i)
        self:updateGauge(i)
    end
    self:updateProdIndicator()
end

function ProductivityMonitoring:broadcastMachineStatus()
    for i, machine in ipairs(self.machines) do
        if self.networkCard then
            self.networkCard:broadcast(100, "machine_update", {
                "machine_" .. i,
                machine.standby,
                machine.productivity
            })
        end
    end
end

function ProductivityMonitoring:handleIOTriggerEvent(source)
    -- Check emergency stop
    if source == self.display.factory.emergency_stop then
        print("Emergency stop triggered")
        self:handleEmergencyStop()
        return
    end

    -- Check factory buttons
    for i, button in ipairs(self.display.factory.buttons) do
        if source == button then
            print("Factory button pressed:", i)
            self:handleButtonPress(i)
            return
        end
    end
end

function ProductivityMonitoring:update()
    self:updateAllDisplays()
    self:broadcastMachineStatus()
end

return ProductivityMonitoring
