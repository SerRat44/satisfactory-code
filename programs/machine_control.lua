-- programs/machine_control.lua

return function(dependencies)
    local constants = dependencies.constants
    local config = dependencies.config
    local displayPanel = dependencies.displayPanel
    local utils = dependencies.utils

    local ProductivityMonitoring = {
        machines = {},
        emergency_state = false,
        networkCard = nil,
        light_switch = nil
    }

    function ProductivityMonitoring:initialize()
        -- Initialize light switch
        self.light_switch = component.proxy(config.POWER.LIGHT_SWITCH)
        if not self.light_switch then
            error("Light switch not found")
        end

        -- Initialize machines
        print("Initializing machines...")
        for i, id in ipairs(config.REFINERY_IDS) do
            local machine = component.proxy(id)
            if machine then
                self.machines[i] = machine
            else
                print("Warning: Failed to initialize machine " .. i)
            end
        end

        -- Listen to machine buttons
        if displayPanel and displayPanel.prod then
            for i, button in ipairs(displayPanel.prod.buttons) do
                if button then
                    event.listen(button)
                else
                    print("Warning: Button " .. i .. " not found")
                end
            end

            -- Initialize emergency stop
            if displayPanel.prod.emergency_stop then
                event.listen(displayPanel.prod.emergency_stop)
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

        self:updateProdIndicator()
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
        local gauge = displayPanel.prod.gauges[index]
        local machine = self.machines[index]

        if gauge then
            gauge.limit = 1

            if machine and not machine.standby then
                local prod = machine.productivity or 0
                gauge.percent = prod
                utils:updateGaugeColor(gauge)
            else
                gauge.percent = 0
                utils:setComponentColor(gauge, self.colors.COLOR.RED, self.colors.EMIT.OFF)
            end
        end
    end

    function ProductivityMonitoring:updateProdIndicator()
        if not displayPanel.prod.indicatrors.avg_productivity then return end

        if self.emergency_state then
            utils:setComponentColor(displayPanel.prod.indicatrors.avg_productivity, self.colors.COLOR.RED,
                constants.EMIT.INDICATOR)
        else
            local avgProductivity = self:avgProductivity()
            if avgProductivity >= 0.9 then
                utils:setComponentColor(displayPanel.prod.indicatrors.avg_productivity, self.colors.COLOR.GREEN,
                    constants.EMIT.INDICATOR)
            elseif avgProductivity >= 0.5 then
                utils:setComponentColor(displayPanel.prod.indicatrors.avg_productivity, self.colors.COLOR.YELLOW,
                    constants.EMIT.INDICATOR)
            elseif avgProductivity > 0 then
                utils:setComponentColor(displayPanel.prod.indicatrors.avg_productivity, self.colors.COLOR.ORANGE,
                    constants.EMIT.INDICATOR)
            else
                utils:setComponentColor(displayPanel.prod.indicatrors.avg_productivity, self.colors.COLOR.RED,
                    constants.EMIT.INDICATOR)
            end
        end
    end

    function ProductivityMonitoring:updateButton(index)
        local button = displayPanel.prod.buttons[index]
        local machine = self.machines[index]

        if not button or not machine then return end

        if machine.standby then
            utils:setComponentColor(button, constants.COLOR.RED, constants.EMIT.BUTTON)
            return
        end

        local prod = machine.productivity or 0

        if prod >= 0.90 then
            utils:setComponentColor(button, constants.COLOR.GREEN, constants.EMIT.BUTTON)
        elseif prod >= 0.5 then
            utils:setComponentColor(button, constants.COLOR.YELLOW, constants.EMIT.BUTTON)
        else
            utils:setComponentColor(button, constants.COLOR.ORANGE, constants.EMIT.BUTTON)
        end
    end

    function ProductivityMonitoring:updateEmergencyButton()
        if self.emergency_state then
            utils:setComponentColor(displayPanel.prod.emergency_stop, constants.COLOR.RED, constants.EMIT
                .BUTTON)
        else
            utils:setComponentColor(displayPanel.prod.emergency_stop, constants.COLOR.RED, constants.EMIT.OFF)
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
        if source == displayPanel.prod.emergency_stop then
            print("Emergency stop triggered")
            self:handleEmergencyStop()
            return
        end

        -- Check factory buttons
        for i, button in ipairs(displayPanel.prod.buttons) do
            if source == button then
                print("machine button pressed:", i)
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
end
