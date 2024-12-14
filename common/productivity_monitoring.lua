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
            self.utils:setComponentColor(self.display.factory.emergency_stop, self.colors.COLOR.RED, self.colors.EMIT
                .OFF)
        end
    end

    self:updateDisplays()
end

function ProductivityMonitoring:handleEmergencyStop()
    print("Emergency stop triggered")
    self.emergency_state = not self.emergency_state

    if self.emergency_state then
        for _, machine in ipairs(self.machines) do
            if machine then
                machine.standby = true
            end
        end
        self.utils:setComponentColor(self.display.factory.emergency_stop, self.colors.COLOR.RED, self.colors.EMIT.BUTTON)
        self.utils:setComponentColor(self.display.factory.health_indicator, self.colors.COLOR.RED,
            self.colors.EMIT.INDICATOR)
        if self.light_switch then
            self.light_switch.colorSlot = 1
        end
    else
        if self.light_switch then
            self.light_switch.colorSlot = 6
        end
        self.utils:setComponentColor(self.display.factory.emergency_stop, self.colors.COLOR.RED, self.colors.EMIT.OFF)
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
    print("Button press handled: " .. button_id)
    local machine = self.machines[button_id]
    if machine then
        machine.standby = not machine.standby
        self:updateButtonColor(button_id)
        self:updateDisplays()
    end
end

function ProductivityMonitoring:calculateProductivity()
    local total = 0
    local count = 0

    for _, machine in ipairs(self.machines) do
        if machine and not machine.standby then
            total = total + (machine.productivity or 0)
            count = count + 1
        end
    end

    self.current_productivity = count > 0 and (total / count) or 0
    return self.current_productivity
end

function ProductivityMonitoring:updateDisplays()
    -- Update individual machine gauges
    for i, machine in ipairs(self.machines) do
        local gauge = self.display.factory.gauges[i]
        if gauge then
            gauge.limit = 1

            if machine and not machine.standby then
                local prod = machine.productivity or 0
                gauge.percent = prod

                if prod >= 0.95 then
                    self.utils:setComponentColor(gauge, self.colors.COLOR.GREEN, self.colors.EMIT.OFF)
                elseif prod >= 0.5 then
                    self.utils:setComponentColor(gauge, self.colors.COLOR.YELLOW, self.colors.EMIT.OFF)
                else
                    self.utils:setComponentColor(gauge, self.colors.COLOR.ORANGE, self.colors.EMIT.OFF)
                end
            else
                gauge.percent = 0
                self.utils:setComponentColor(gauge, self.colors.COLOR.RED, self.colors.EMIT.OFF)
            end
        end

        self:updateButtonColor(i)
    end

    -- Update overall productivity
    self:calculateProductivity()
    if self.display.factory.productivity_display then
        self.display.factory.productivity_display:setText(string.format("%.1f%%", self.current_productivity * 100))
    end

    self:updateProductivityIndicator()
end

function ProductivityMonitoring:updateProductivityIndicator()
    if not self.display.factory.health_indicator then return end

    if self.emergency_state then
        self.utils:setComponentColor(self.display.factory.health_indicator, self.colors.COLOR.RED,
            self.colors.EMIT.INDICATOR)
        return
    end

    local productivity = self.current_productivity
    if productivity >= 0.95 then
        self.utils:setComponentColor(self.display.factory.health_indicator, self.colors.COLOR.GREEN,
            self.colors.EMIT.INDICATOR)
    elseif productivity >= 0.5 then
        self.utils:setComponentColor(self.display.factory.health_indicator, self.colors.COLOR.YELLOW,
            self.colors.EMIT.INDICATOR)
    else
        self.utils:setComponentColor(self.display.factory.health_indicator, self.colors.COLOR.ORANGE,
            self.colors.EMIT.INDICATOR)
    end
end

function ProductivityMonitoring:updateButtonColor(index)
    local button = self.display.factory.buttons[index]
    local machine = self.machines[index]

    if not button or not machine then return end

    if machine.standby then
        self.utils:setComponentColor(button, self.colors.COLOR.RED, self.colors.EMIT.BUTTON)
        return
    end

    local productivity = machine.productivity or 0

    if productivity >= 0.95 then
        self.utils:setComponentColor(button, self.colors.COLOR.GREEN, self.colors.EMIT.BUTTON)
    elseif productivity >= 0.5 then
        self.utils:setComponentColor(button, self.colors.COLOR.YELLOW, self.colors.EMIT.BUTTON)
    else
        self.utils:setComponentColor(button, self.colors.COLOR.ORANGE, self.colors.EMIT.BUTTON)
    end
end

function ProductivityMonitoring:updateAllButtons()
    for i = 1, #self.machines do
        self:updateButtonColor(i)
    end
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

function ProductivityMonitoring:processEvents()
    local eventData = { event.pull() }
    local eventType = eventData[1]
    local source = eventData[2]

    if eventType == "Trigger" then
        -- Check emergency stop
        if source == modules.factory.emergency_stop then
            print("Emergency stop triggered")
            productivityMonitoring:handleEmergencyStop()
            return
        end

        -- Check factory buttons
        for i, button in ipairs(modules.factory.buttons) do
            if source == button then
                print("Factory button pressed:", i)
                productivityMonitoring:handleButtonPress(i)
                return
            end
        end
    end
end

function ProductivityMonitoring:update()
    self:updateDisplays()
    self:processEvents()
end

return ProductivityMonitoring
