-- loaders/loader.lua

local GITHUB_RAW_URL = "https://raw.githubusercontent.com/yourusername/satisfactory-networks/main"
local FACTORY_NAME = "heavy-oil"  -- Change this for different factories

local internet = computer.getPCIDevices(classes.InternetCard)[1]

function downloadFromGithub(path)
    local url = GITHUB_RAW_URL .. "/" .. path
    local response = internet:request(url)
    
    if response.status == 200 then
        return response.data
    else 
        error("Failed to download " .. path .. ": " .. response.status)
    end
end

function loadFiles()
    -- Load common files
    local colors = loadstring(downloadFromGithub("common/colors.lua"))()
    local utils = loadstring(downloadFromGithub("common/utils.lua"))()
    
    -- Load factory specific files
    local base_path = "factories/" .. FACTORY_NAME .. "/"
    local config = loadstring(downloadFromGithub(base_path .. "config.lua"))()
    local display = loadstring(downloadFromGithub(base_path .. "display.lua"))()
    local power = loadstring(downloadFromGithub(base_path .. "power.lua"))()
    local monitoring = loadstring(downloadFromGithub(base_path .. "monitoring.lua"))()
    local control = loadstring(downloadFromGithub(base_path .. "control.lua"))()
    
    -- Create environment with loaded modules
    local env = {
        colors = colors,
        utils = utils,
        config = config,
        display = display,
        power = power,
        monitoring = monitoring,
        computer = computer,
        component = component,
        event = event,
        error = error,
    }
    
    -- Set environment and run control
    setmetatable(env, {__index = _G})
    setfenv(control, env)
    control()
end

-- Run the loader
loadFiles()