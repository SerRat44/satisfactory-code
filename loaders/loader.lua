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

    -- Load and compile common utilities first
    local commonModules = {
        colors = downloadFromGithub("common/colors.lua"),
        utils = downloadFromGithub("common/utils.lua"),
        flowMonitoring = downloadFromGithub("common/flow_monitoring.lua"),
        productivityMonitoring = downloadFromGithub("common/productivity_monitoring.lua")
    }

    -- Compile common modules
    local compiledCommon = {}
    for name, code in pairs(commonModules) do
        print("Compiling " .. name .. ".lua...")
        local fn, err = load(code)
        if not fn then error("Failed to compile " .. name .. ".lua: " .. err) end
        compiledCommon[name] = fn()
        print(name .. " loaded successfully")
    end

    -- Load factory-specific files
    local base_path = "turbofuel-plant/" .. FACTORY_NAME .. "/"

    -- Load and compile config
    print("Loading config.lua...")
    local configData = downloadFromGithub(base_path .. "config.lua")
    print("Compiling config.lua...")
    local configFn, err = load(configData)
    if not configFn then error("Failed to compile config.lua: " .. err) end
    local config = configFn()
    print("Config loaded successfully")

    -- Load and compile factory-specific modules
    local factoryModules = {
        display = downloadFromGithub(base_path .. "display.lua"),
        power = downloadFromGithub(base_path .. "power.lua"),
        control = downloadFromGithub(base_path .. "control.lua")
    }

    -- Create base dependencies object
    local dependencies = {
        colors = compiledCommon.colors,
        utils = compiledCommon.utils,
        config = config
    }

    -- Compile and initialize factory modules
    print("Compiling display.lua...")
    local displayFn, err = load(factoryModules.display)
    if not displayFn then error("Failed to compile display.lua: " .. err) end
    local Display = displayFn(dependencies)
    if not Display then error("Failed to create Display class") end
    print("Display loaded successfully")

    print("Compiling power.lua...")
    local powerFn, err = load(factoryModules.power)
    if not powerFn then error("Failed to compile power.lua: " .. err) end
    local power = powerFn(dependencies)
    print("Power loaded successfully")

    -- Initialize monitoring modules
    local flowMonitoring = compiledCommon.flowMonitoring
    local productivityMonitoring = compiledCommon.productivityMonitoring

    -- Create complete dependencies object for control module
    dependencies.display = Display
    dependencies.power = power
    dependencies.flowMonitoring = flowMonitoring
    dependencies.productivityMonitoring = productivityMonitoring

    -- Load and initialize control module
    print("Compiling control.lua...")
    local controlFn, err = load(factoryModules.control)
    if not controlFn then error("Failed to compile control.lua: " .. err) end

    print("Creating control module...")
    local controlModuleFactory = controlFn()
    if type(controlModuleFactory) ~= "function" then
        error("Control module must return a factory function, got " .. type(controlModuleFactory))
    end

    -- Execute the factory function with all dependencies
    local controlModule = controlModuleFactory(dependencies)

    -- Verify the control module
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
