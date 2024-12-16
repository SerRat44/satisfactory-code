-- common/display_panel.lua

return function()
    local Display = {}

    -- Initializes a row of machine buttons and gauges. Outputs two arrays: one for buttons and one for gauges.
    function Display:initializeMachineRow(panel, startX, startY, panelNum, count)
        local buttons = {}
        local gauges = {}

        for i = 0, count - 1 do
            local buttonIndex = #buttons + 1
            local gaugeIndex = #gauges + 1
            local x = startX + i

            -- Initialize button
            local button = panel:getModule(x, startY, panelNum)
            if button then
                buttons[buttonIndex] = button

                -- Initialize corresponding gauge (one unit above button)
                local gauge = panel:getModule(x, startY + 1, panelNum)
                if gauge then
                    gauges[gaugeIndex] = gauge
                end
            end
        end

        return buttons, gauges
    end

    -- Initializes a flow block. Outputs three modules: the gauge, the top display, and the bottom display.
    function Display:initializeFlowBlock(panel, startX, startY, panelNum)
        local gauge = panel:getModule(startX, startY, panelNum)
        local topDisplay = panel:getModule(startX + 2, startY + 1, panelNum)
        local bottomDisplay2 = panel:getModule(startX + 2, startY, panelNum)

        return gauge, topDisplay, bottomDisplay2
    end

    return Display
end
