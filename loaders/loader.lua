local GITHUB_URL = "https://raw.githubusercontent.com/SerRat44/satisfactory-code/main"
local FACTORY_NAME = "heavy-oil" -- Change this for different factories
local internet = computer.getPCIDevices(classes.Build_InternetCard_C)[1]

function downloadFromGithub(path)
    local url = GITHUB_URL .. "/" .. path
    local future = internet:request(url, "GET", "")

    -- Wait for the response
    while not future.isDone do
        event.pull(0.1)
    end

    local response = future.data
    if response then
        return response
    else
        error("Failed to download " .. path)
    end
end

function loadFiles()
    print("Loading files...")
    -- Load common files
    local colors = load(downloadFromGithub("common/colors.lua"))()
    print("Loaded colors")
    local utils = load(downloadFromGithub("common/utils.lua"))()
    print("Loaded utils")

    -- Load factory specific files
    local base_path = "factories/" .. FACTORY_NAME .. "/"
    local config = load(downloadFromGithub(base_path .. "config.lua"))()
    print("Loaded config")
    local display = load(downloadFromGithub(base_path .. "display.lua"))()
    local power = load(downloadFromGithub(base_path .. "power.lua"))()
    local monitoring = load(downloadFromGithub(base_path .. "monitoring.lua"))()
    local control = load(downloadFromGithub(base_path .. "control.lua"))()

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
    setmetatable(env, { __index = _G })
    setfenv(control, env)
    control()
end

-- Run the loader
loadFiles()
