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

    -- Load factory-specific files
    local base_path = "factories/" .. FACTORY_NAME .. "/"

    print("Loading config.lua...")
    local configData = downloadFromGithub(base_path .. "config.lua")
    print("Compiling config.lua...")
    local configFn, err = load(configData)
    if not configFn then error("Failed to compile config.lua: " .. err) end
    local config = configFn()
    print("Config loaded successfully")

    print(config.COMPONENT_IDS.DISPLAY_PANEL)

    -- Load and compile modules with dependencies
    print("Loading display.lua...")
    local displayData = downloadFromGithub(base_path .. "display.lua")
    print("Compiling display.lua...")
    local displayFn, err = load(displayData)
    if not displayFn then error("Failed to compile display.lua: " .. err) end
    local Display = displayFn({ colors = colors, config = config }) -- Execute with dependencies
    if not Display then error("Failed to create Display class") end
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

    -- Create and execute the control module factory function
    print("Creating control module...")
    local controlModuleFactory = controlFn()
    if type(controlModuleFactory) ~= "function" then
        error("Control module must return a factory function, got " .. type(controlModuleFactory))
    end

    -- Execute the factory function with dependencies to get the actual module
    local controlModule = controlModuleFactory({
        colors = colors,
        utils = utils,
        config = config,
        display = Display, -- Pass the actual Display class
        power = power,
        monitoring = monitoring
    })

    -- Verify the control module has the required structure
    if type(controlModule) ~= "table" then
        error("Control module must return a table, got " .. type(controlModule))
    end
    if type(controlModule.main) ~= "function" then
        error("Control module must have a 'main' function")
    end

    -- Start the main control loop
    print("Starting control main loop...")
    controlModule.main()
end

-- Start the loader with error handling
print("Starting loader...")
local success, err = pcall(loadFiles)
if not success then
    error("Loader failed: " .. tostring(err))
end
