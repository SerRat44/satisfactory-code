-- factories/heavy-oil/monitoring.lua

local Monitoring = {
    refineries = {},
    productivity_history = {},
    current_productivity = 0,
    emergency_state = false,
    display = nil,
    networkCard = nil,
    light_switch = nil -- Add light switch property
}

function Monitoring:new(display, dependencies)
    local instance = {}
    setmetatable(instance, { __index = self })
    instance.display = display
    instance.colors = dependencies.colors
    instance.utils = dependencies.utils
    instance.config = dependencies.config
    instance.productivity_history = {}

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

    -- Initialize refineries
    for i, id in ipairs(self.config.REFINERY_IDS) do
        self.refineries[i] = component.proxy(id)
    end

    event.listen(self.display.factory.emergency_stop)
    self.utils.setComponentColor(self.display.factory.emergency_stop, self.colors.STATUS.OFF, self.colors.EMIT.OFF)
end

function Monitoring:handleEmergencyStop()
    self.emergency_state = not self.emergency_state

    if self.emergency_state then
        for _, refinery in ipairs(self.refineries) do
            if refinery then
                refinery.standby = true
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
        for _, refinery in ipairs(self.refineries) do
            if refinery then
                refinery.standby = false
            end
        end
        self:updateProductivityIndicator()
    end

    self:updateAllButtons()
end

function Monitoring:updateProductivityHistory()
    local current_prod = self:getAvgProductivity()

    -- Update gauges and button colors together
    for i, refinery in ipairs(self.refineries) do
        -- Update gauge if it exists
        if self.display.factory.gauges[i] then
            if refinery and not refinery.standby then
                local prod = tonumber(refinery.productivity) or 0
                prod = math.min(prod, 100)
                self.display.factory.gauges[i].percent = prod
                self:updateGaugeColor(self.display.factory.gauges[i], prod)
            else
                self.display.factory.gauges[i].percent = 0
                self.utils.setComponentBackgroundColor(self.display.factory.gauges[i], self.colors.STATUS.OFF)
            end
        end

        -- Update button colors regardless of gauge existence
        self:updateButtonColor(i)
    end

    if #self.productivity_history > self.config.HISTORY_LENGTH then
        table.remove(self.productivity_history, 1)
    end

    self:updateProductivityIndicator()

    return current_prod
end

function Monitoring:getAvgProductivity()
    local total_productivity = 0
    local active_refineries = 0

    for _, refinery in ipairs(self.refineries) do
        if refinery and not refinery.standby then
            total_productivity = total_productivity + refinery.productivity
            active_refineries = active_refineries + 1
        end
    end

    local current_prod = active_refineries > 0 and (total_productivity / active_refineries) or 0
    table.insert(self.productivity_history, current_prod)
    self.current_productivity = current_prod

    return current_prod
end

function Monitoring:updateProductivityIndicator()
    if self.emergency_state then
        self.utils.setComponentColor(self.display.factory.health_indicator, self.colors.STATUS.OFF,
            self.colors.EMIT.INDICATOR)
    else
        if self.current_productivity >= 95 then
            self.utils.setComponentColor(self.display.factory.health_indicator, self.colors.STATUS.WORKING,
                self.colors.EMIT.INDICATOR)
        elseif self.current_productivity >= 50 then
            self.utils.setComponentColor(self.display.factory.health_indicator, self.colors.STATUS.WARNING,
                self.colors.EMIT.INDICATOR)
        else
            self.utils.setComponentColor(self.display.factory.health_indicator, self.colors.STATUS.IDLE,
                self.colors.EMIT.INDICATOR)
        end
    end
end

function Monitoring:handleButtonPress(button_id)
    local refinery = self.refineries[button_id]
    if refinery then
        refinery.standby = not refinery.standby
        self:updateButtonColor(button_id)
    end
end

function Monitoring:updateButtonColor(index)
    if self.display.factory.buttons[index] and self.refineries[index] then
        local refinery = self.refineries[index]

        -- First check if refinery exists and is not in standby
        if not refinery or refinery.standby then
            self.utils.setComponentColor(self.display.factory.buttons[index], self.colors.STATUS.OFF,
                self.colors.EMIT.BUTTON)
            return
        end

        -- Get productivity value
        local productivity = tonumber(refinery.productivity) or 0

        -- Set color based on productivity thresholds
        if productivity >= 95 then
            self.utils.setComponentColor(self.display.factory.buttons[index], self.colors.STATUS.WORKING,
                self.colors.EMIT.BUTTON)
        elseif productivity >= 75 then
            self.utils.setComponentColor(self.display.factory.buttons[index], self.colors.STATUS.WARNING,
                self.colors.EMIT.BUTTON)
        else
            self.utils.setComponentColor(self.display.factory.buttons[index], self.colors.STATUS.IDLE,
                self.colors.EMIT.BUTTON)
        end
    end
end

function Monitoring:updateGaugeColor(gauge, percent)
    if not gauge then return end

    if percent >= 95 then
        self.utils.setComponentBackgroundColor(gauge, self.colors.STATUS.WORKING)
    elseif percent >= 75 then
        self.utils.setComponentBackgroundColor(gauge, self.colors.STATUS.WARNING)
    else
        self.utils.setComponentBackgroundColor(gauge, self.colors.STATUS.IDLE)
    end
end

function Monitoring:updateAllButtons()
    for i = 1, #self.display.factory.buttons do
        self:updateButtonColor(i)
    end
end

function Monitoring:getRefineryStatus(refinery)
    if not refinery then return "OFF" end
    if refinery.standby then return "OFF" end

    local productivity = tonumber(refinery.productivity) or 0

    if productivity >= 95 then
        return "WORKING"
    elseif productivity >= 75 then
        return "WARNING"
    else
        return "IDLE"
    end
end

function Monitoring:broadcastRefineryStatus()
    for i, refinery in ipairs(self.refineries) do
        local status = self:getRefineryStatus(refinery)
        if self.networkCard then -- Use the instance network card
            self.networkCard:broadcast(100, "refinery_update", {
                "refinery_" .. i,
                status,
                refinery.productivity
            })
        end
    end
end

return Monitoring
