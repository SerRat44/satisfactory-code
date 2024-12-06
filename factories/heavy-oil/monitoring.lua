-- factories/heavy-oil/monitoring.lua

local colors = require('common.colors')
local utils = require('common.utils')
local config = require('config')

local Monitoring = {
    refineries = {},
    productivity_history = {},
    current_productivity = 0,
    emergency_state = false,
    display = nil
}

function Monitoring:new(display)
    local instance = {}
    setmetatable(instance, { __index = self })
    instance.display = display
    instance.productivity_history = {}
    return instance
end

function Monitoring:initialize()
    for i, id in ipairs(config.REFINERY_IDS) do
        self.refineries[i] = component.proxy(id)
    end

    event.listen(self.display.factory.emergency_stop)
    utils.setComponentColor(self.display.factory.emergency_stop, colors.STATUS.OFF, colors.EMIT.OFF)
end

function Monitoring:handleEmergencyStop()
    self.emergency_state = not self.emergency_state

    if self.emergency_state then
        for _, refinery in ipairs(self.refineries) do
            if refinery then
                refinery.standby = true
            end
        end
        utils.setComponentColor(self.display.factory.emergency_stop, colors.STATUS.OFF, colors.EMIT.BUTTON)
        utils.setComponentColor(self.display.factory.health_indicator, colors.STATUS.OFF, colors.EMIT.INDICATOR)
        self.light_switch.colorSlot = 1
    else
        self.light_switch.colorSlot = 6
        utils.setComponentColor(self.display.factory.emergency_stop, colors.STATUS.OFF, colors.EMIT.OFF)
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

    for i, refinery in ipairs(self.refineries) do
        if self.display.factory.gauges[i] then
            if refinery and not refinery.standby then
                local prod = tonumber(refinery.productivity) or 0
                prod = math.min(prod, 100)
                self.display.factory.gauges[i].percent = prod
                self:updateGaugeColor(self.display.factory.gauges[i], prod)
            else
                self.display.factory.gauges[i].percent = 0
                utils.setComponentColor(self.display.factory.gauges[i], colors.STATUS.OFF, colors.EMIT.GAUGE)
            end
        end
    end

    if #self.productivity_history > config.HISTORY_LENGTH then
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
        utils.setComponentColor(self.display.factory.health_indicator, colors.STATUS.OFF, colors.EMIT.INDICATOR)
    else
        if self.current_productivity >= 95 then
            utils.setComponentColor(self.display.factory.health_indicator, colors.STATUS.WORKING, colors.EMIT.INDICATOR)
        elseif self.current_productivity >= 50 then
            utils.setComponentColor(self.display.factory.health_indicator, colors.STATUS.WARNING, colors.EMIT.INDICATOR)
        else
            utils.setComponentColor(self.display.factory.health_indicator, colors.STATUS.IDLE, colors.EMIT.INDICATOR)
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
        local status = self:getRefineryStatus(self.refineries[index])
        if status == "OFF" then
            utils.setComponentColor(self.display.factory.buttons[index], colors.STATUS.OFF, colors.EMIT.BUTTON)
        elseif status == "IDLE" then
            utils.setComponentColor(self.display.factory.buttons[index], colors.STATUS.WARNING, colors.EMIT.BUTTON)
        elseif status == "WARNING" then
            utils.setComponentColor(self.display.factory.buttons[index], colors.STATUS.WARNING, colors.EMIT.BUTTON)
        else
            utils.setComponentColor(self.display.factory.buttons[index], colors.STATUS.WORKING, colors.EMIT.BUTTON)
        end
    end
end

function Monitoring:updateGaugeColor(gauge, percent)
    if not gauge then return end

    if percent >= 95 then
        utils.setComponentColor(gauge, colors.STATUS.WORKING, colors.EMIT.GAUGE)
    elseif percent >= 50 then
        utils.setComponentColor(gauge, colors.STATUS.WARNING, colors.EMIT.GAUGE)
    else
        utils.setComponentColor(gauge, colors.STATUS.IDLE, colors.EMIT.GAUGE)
    end
end

function Monitoring:updateAllButtons()
    for i = 1, #self.display.factory.buttons do
        self:updateButtonColor(i)
    end
end

function Monitoring:getRefineryStatus(refinery)
    if not refinery then return "OFF" end

    if refinery.standby then
        return "OFF"
    elseif refinery.productivity >= 95 then
        return "WORKING"
    elseif refinery.productivity >= 50 then
        return "WARNING"
    else
        return "IDLE"
    end
end

function Monitoring:broadcastRefineryStatus()
    for i, refinery in ipairs(self.refineries) do
        local status = self:getRefineryStatus(refinery)
        net:broadcast(100, "refinery_update", {
            "refinery_" .. i,
            status,
            refinery.productivity
        })
    end
end

return Monitoring
