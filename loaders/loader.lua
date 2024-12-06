local GITHUB_URL = "https://raw.githubusercontent.com/SerRat44/satisfactory-code/main"
local FACTORY_NAME = "heavy-oil"
local internet = computer.getPCIDevices(classes.Build_InternetCard_C)[1]

function downloadFromGithub(path)
    local url = GITHUB_URL .. "/" .. path
    print("Trying to download: " .. url)

    local request = internet:request(url, "GET", "")
    print("Request sent, awaiting response...")

    local result, data, headers = request:await()

    if result == 200 then
        print("Downloaded successfully: " .. path)
        return data
    else
        error("Download failed for " .. path .. ": " .. (result or "unknown error"))
    end
end

function loadFiles()
    print("Starting file downloads...")

    -- Load and compile common files first
    print("Loading colors.lua...")
    local colorData = downloadFromGithub("common/colors.lua")
    print("Compiling colors.lua...")
    local colorFn, err = load(colorData)
    if not colorFn then error("Failed to compile colors.lua: " .. err) end
    local colors = colorFn()
    print("Colors loaded successfully")

    print("Loading utils.lua...")
    local utilsData = downloadFromGithub("common/utils.lua")
    print("Compiling utils.lua...")
    local utilsFn, err = load(utilsData)
    if not utilsFn then error("Failed to compile utils.lua: " .. err) end
    local utils = utilsFn()
    print("Utils loaded successfully")

    -- Load factory specific files
    local base_path = "factories/" .. FACTORY_NAME .. "/"

    print("Loading config.lua...")
    local configData = downloadFromGithub(base_path .. "config.lua")
    print("Compiling config.lua...")
    local configFn, err = load(configData)
    if not configFn then error("Failed to compile config.lua: " .. err) end
    local config = configFn()
    print("Config loaded successfully")

    -- Load and compile modules with dependencies
    print("Loading display.lua...")
    local displayData = downloadFromGithub(base_path .. "display.lua")
    print("Compiling display.lua...")
    local displayFn, err = load(displayData)
    if not displayFn then error("Failed to compile display.lua: " .. err) end
    local display = displayFn({ colors = colors, config = config })
    print("Display loaded successfully")

    print("Loading power.lua...")
    local powerData = downloadFromGithub(base_path .. "power.lua")
    print("Compiling power.lua...")
    local powerFn, err = load(powerData)
    if not powerFn then error("Failed to compile power.lua: " .. err) end
    local power = powerFn({ colors = colors, utils = utils, config = config })
    print("Power loaded successfully")

    print("Loading monitoring.lua...")
    local monitoringData = downloadFromGithub(base_path .. "monitoring.lua")
    print("Compiling monitoring.lua...")
    local monitoringFn, err = load(monitoringData)
    if not monitoringFn then error("Failed to compile monitoring.lua: " .. err) end
    local monitoring = monitoringFn({ colors = colors, utils = utils, config = config })
    print("Monitoring loaded successfully")

    print("Loading control.lua...")
    local controlData = downloadFromGithub(base_path .. "control.lua")
    print("Compiling control.lua...")
    local controlFn, err = load(controlData)
    if not controlFn then error("Failed to compile control.lua: " .. err) end

    -- Create environment with all loaded modules
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
        print = print,
        string = string,
        math = math,
        table = table,
        pairs = pairs,
        ipairs = ipairs,
        type = type,
        tostring = tostring,
        tonumber = tonumber,
    }

    -- Run control with the local environment
    print("Setting up environment...")
    local success, err = pcall(function()
        local _ENV = env
        controlFn()
    end)

    if not success then
        error("Control execution failed: " .. tostring(err))
    end
end

-- Start the loader with error handling
print("Starting loader...")
local success, err = pcall(loadFiles)
if not success then
    error("Loader failed: " .. tostring(err))
end
