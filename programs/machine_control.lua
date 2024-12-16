-- programs/machine_control.lua

return function(dependencies)
    local ProductivityMonitoring = {
        machines = {},
        emergency_state = false,
        networkCard = nil,
        light_switch = nil,
        panel = nil,
        prod_buttons = {},
        prod_gauges = {},
        emergency_stop = nil,
        avg_prod_indicator = nil,
        constants = dependencies.constants,
        config = dependencies.config,
        display_panel = dependencies.displayPanel,
        utils = dependencies.utils

    }

    function ProductivityMonitoring:initialize()
        debug("===Initializing Program - Machine Control===")

        self.panel = component.proxy(config.PANEL_ID)
        if not self.panel then
            error("Failed to initialize panel")
        end

        for i, row in ipairs(config.DISPLAY_LAYOUT.MACHINE_ROWS) do
            local modules = self.display_panel:initializeMachineRow(self.panel, table.unpack(row))
            local buttons = modules[1]
            local gauges = modules[2]

            table.insert(self.prod_buttons, table.unpack(buttons))
            table.insert(self.prod_gauges, table.unpack(gauges))
        end

        self.emergency_stop = self.panel:getModule(table.unpack(self.config.DISPLAY_LAYOUT.EMERGENCY_STOP))
        self.avg_prod_indicator = self.panel:getModule(table.unpack(self.config.DISPLAY_LAYOUT.AVG_PROD_INDICATOR))

        self.light_switch = component.proxy(config.POWER.LIGHT_SWITCH)

        print("Initializing machines...")
        for i, id in ipairs(self.config.REFINERY_IDS) do
            local machine = component.proxy(id)
            if machine then
                self.machines[i] = machine
            else
                debug("Warning: Failed to initialize machine " .. i)
            end
        end


        for i, button in ipairs(self.prod_buttons) do
            if button then
                event.listen(button)
            else
                debug("Warning: Button " .. i .. " not found")
            end
        end

        event.listen(self.emergency_stop)

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
        local gauge = self.prod_gauges[index]
        local machine = self.machines[index]

        if gauge then
            gauge.limit = 1

            if machine and not machine.standby then
                local prod = machine.productivity or 0
                gauge.percent = prod
                self.utils:updateGaugeColor(gauge)
            else
                gauge.percent = 0
                self.utils:setComponentColor(gauge, self.constants.COLOR.RED, self.constants.EMIT.OFF)
            end
        end
    end

    function ProductivityMonitoring:updateProdIndicator()
        if self.emergency_state then
            self.utils:setComponentColor(self.avg_prod_indicator, self.constants.COLOR.RED,
                self.constants.EMIT.INDICATOR)
        else
            local avgProductivity = self:avgProductivity()
            if avgProductivity >= 0.9 then
                self.utils:setComponentColor(self.avg_prod_indicator, self.constants.COLOR.GREEN,
                    self.constants.EMIT.INDICATOR)
            elseif avgProductivity >= 0.5 then
                self.utils:setComponentColor(self.avg_prod_indicator, self.constants.COLOR.YELLOW,
                    self.constants.EMIT.INDICATOR)
            elseif avgProductivity > 0 then
                self.utils:setComponentColor(self.avg_prod_indicator, self.constants.COLOR.ORANGE,
                    self.constants.EMIT.INDICATOR)
            else
                self.utils:setComponentColor(self.avg_prod_indicator, self.constants.COLOR.RED,
                    self.constants.EMIT.INDICATOR)
            end
        end
    end

    function ProductivityMonitoring:updateButton(index)
        local button = self.prod_buttons[index]
        local machine = self.machines[index]

        if machine.standby then
            self.utils:setComponentColor(button, self.constants.COLOR.RED, self.constants.EMIT.BUTTON)
            return
        end

        local prod = machine.productivity or 0

        if prod >= 0.90 then
            self.utils:setComponentColor(button, self.constants.COLOR.GREEN, self.constants.EMIT.BUTTON)
        elseif prod >= 0.5 then
            self.utils:setComponentColor(button, self.constants.COLOR.YELLOW, self.constants.EMIT.BUTTON)
        else
            self.utils:setComponentColor(button, self.constants.COLOR.ORANGE, self.constants.EMIT.BUTTON)
        end
    end

    function ProductivityMonitoring:updateEmergencyButton()
        if self.emergency_state then
            self.utils:setComponentColor(self.emergency_stop, self.constants.COLOR.RED, self.constants.EMIT
                .BUTTON)
        else
            self.utils:setComponentColor(self.emergency_stop, self.constants.COLOR.RED, self.constants.EMIT.OFF)
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
        if source == self.emergency_stop then
            print("Emergency stop triggered")
            self:handleEmergencyStop()
            return
        end

        -- Check factory buttons
        for i, button in ipairs(self.prod_buttons) do
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
