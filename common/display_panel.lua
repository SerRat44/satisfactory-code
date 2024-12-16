-- common/display_panel.lua

return function()
    local Display = {}

    -- Initializes a row of machine buttons and gauges. Outputs two arrays: one for buttons and one for gauges.
    function Display:initializeMachineRow(panel, config)
        local buttons = {}
        local gauges = {}

        -- Validate config
        if not config.startX or not config.startY or not config.panelNum or not config.count then
            error("Invalid machine row configuration")
        end

        for i = 0, config.count - 1 do
            local x = config.startX + i

            -- Initialize button
            local button = panel:getModule(x, config.startY, config.panelNum)
            if button then
                buttons[#buttons + 1] = button

                -- Initialize corresponding gauge (one unit above button)
                local gauge = panel:getModule(x, config.startY + 1, config.panelNum)
                if gauge then
                    gauges[#gauges + 1] = gauge
                end
            end
        end

        return buttons, gauges
    end

    -- Initializes a flow block. Outputs three modules: the gauge, the top display, and the bottom display.
    function Display:initializeFlowBlock(panel, startX, startY, panelNum)
        local gauge = panel:getModule(startX, startY, panelNum)
        local topDisplay = panel:getModule(startX + 2, startY + 1, panelNum)
        local bottomDisplay = panel:getModule(startX + 2, startY, panelNum)

        return gauge, topDisplay, bottomDisplay
    end

    return Display
end
