local function boot()
    local Players
    local lp
    local startedAt = tick()

    repeat
        local loaded = false
        if game then
            local ok, result = pcall(function()
                return game:IsLoaded()
            end)
            loaded = ok and result
        end

        if loaded then
            local ok, service = pcall(function()
                return game:GetService("Players")
            end)
            Players = ok and service or nil
            if not Players then
                Players = game:FindFirstChild("Players")
            end
            lp = Players and Players.LocalPlayer
        end

        if not lp then
            task.wait(0.1)
        end
    until lp or tick() - startedAt > 10

    if not lp then
        warn("Better Void: LocalPlayer not found")
        return
    end

    if _G.BetterVoid and _G.BetterVoid.unload then
        pcall(function()
            _G.BetterVoid.unload()
        end)
    end

    local CONFIG_FOLDER = "BetterVoid"
    local CONFIG_FILE = CONFIG_FOLDER .. "/void_config.cfg"
    local CONFIG_KEYS = {
        "height",
        "rate",
        "velocity",
        "returnHeight",
        "roam",
        "roamRadius",
        "roamSpeed",
        "showOverlay",
        "hasReturnMarker",
        "returnX",
        "returnY",
        "returnZ"
    }

    local S = {
        enabled = false,
        running = true,
        height = 650,
        rate = 0.08,
        velocity = 1200,
        returnHeight = 3,
        roam = false,
        roamRadius = 900,
        roamSpeed = 0.8,
        showOverlay = true,
        hasReturnMarker = false,
        returnX = 0,
        returnY = 0,
        returnZ = 0,
        anchorX = nil,
        anchorY = nil,
        anchorZ = nil,
        currentX = 0,
        currentY = 0,
        currentZ = 0,
        lastMoveAt = 0
    }

    _G.BetterVoid = S

    local Lib
    local win
    local toggle
    local roamToggle
    local overlayToggle
    local handles = {}
    local overlay = { items = {} }
    local syncingToggle = false

    local function notifyUser(title, text, kind)
        if Lib and Lib.Notify then
            local ok = pcall(function()
                Lib:Notify(title, text, 2, kind or "info")
            end)
            if ok then
                return
            end
        end

        if notify then
            local ok = pcall(function()
                notify(title, text, 2)
            end)
            if ok then
                return
            end
        end

        print("[Better Void] " .. tostring(title) .. ": " .. tostring(text))
    end

    local function ensureConfigFolder()
        if isfolder and makefolder and not isfolder(CONFIG_FOLDER) then
            pcall(function()
                makefolder(CONFIG_FOLDER)
            end)
        end
    end

    local function clampSettings()
        S.height = math.max(100, math.min(10000, tonumber(S.height) or 650))
        S.rate = math.max(0.03, math.min(0.5, tonumber(S.rate) or 0.08))
        S.velocity = math.max(500, math.min(5000, tonumber(S.velocity) or 1200))
        S.returnHeight = math.max(0, math.min(50, tonumber(S.returnHeight) or 3))
        S.roamRadius = math.max(100, math.min(5000, tonumber(S.roamRadius) or 900))
        S.roamSpeed = math.max(0.1, math.min(5, tonumber(S.roamSpeed) or 0.8))
        S.returnX = tonumber(S.returnX) or 0
        S.returnY = tonumber(S.returnY) or 0
        S.returnZ = tonumber(S.returnZ) or 0
    end

    local function saveConfig()
        if not writefile then
            return false, "writefile missing"
        end

        ensureConfigFolder()
        local lines = {}
        for _, key in ipairs(CONFIG_KEYS) do
            lines[#lines + 1] = key .. "=" .. tostring(S[key])
        end

        local ok, err = pcall(function()
            writefile(CONFIG_FILE, table.concat(lines, "\n"))
        end)
        return ok, err
    end

    local function loadConfig()
        if not readfile or not isfile or not isfile(CONFIG_FILE) then
            return false, "config missing"
        end

        local ok, data = pcall(function()
            return readfile(CONFIG_FILE)
        end)
        if not ok or type(data) ~= "string" then
            return false, data
        end

        for line in string.gmatch(data, "[^\r\n]+") do
            local key, raw = string.match(line, "^([%w_]+)=(.*)$")
            if key and S[key] ~= nil then
                local kind = type(S[key])
                if kind == "boolean" then
                    S[key] = raw == "true"
                elseif kind == "number" then
                    local value = tonumber(raw)
                    if value then
                        S[key] = value
                    end
                end
            end
        end

        clampSettings()
        return true
    end

    local function getRoot()
        local char = lp and lp.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function syncUi()
        if handles.height and handles.height.Set then pcall(function() handles.height:Set(S.height) end) end
        if handles.rate and handles.rate.Set then pcall(function() handles.rate:Set(S.rate) end) end
        if handles.velocity and handles.velocity.Set then pcall(function() handles.velocity:Set(S.velocity) end) end
        if handles.returnHeight and handles.returnHeight.Set then pcall(function() handles.returnHeight:Set(S.returnHeight) end) end
        if handles.roamRadius and handles.roamRadius.Set then pcall(function() handles.roamRadius:Set(S.roamRadius) end) end
        if handles.roamSpeed and handles.roamSpeed.Set then pcall(function() handles.roamSpeed:Set(S.roamSpeed) end) end

        if roamToggle and roamToggle.Set then pcall(function() roamToggle:Set(S.roam) end) end
        if overlayToggle and overlayToggle.Set then pcall(function() overlayToggle:Set(S.showOverlay) end) end
    end

    local function setEnabled(on, syncToggle)
        local wanted = on and true or false
        if S.enabled == wanted then
            return
        end

        S.enabled = wanted
        local root = getRoot()

        if S.enabled then
            if root then
                S.anchorX = root.Position.X
                S.anchorY = root.Position.Y
                S.anchorZ = root.Position.Z
            end
            notifyUser("Better Void", "enabled", "success")
        else
            if root then
                pcall(function()
                    if S.anchorX and S.anchorY and S.anchorZ then
                        root.CFrame = CFrame.new(S.anchorX, S.anchorY + S.returnHeight, S.anchorZ)
                    end
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    root.CanCollide = true
                end)
            end

            S.anchorX = nil
            S.anchorY = nil
            S.anchorZ = nil
            notifyUser("Better Void", "disabled", "warning")
        end

        if syncToggle ~= false and toggle and toggle.Set and not syncingToggle then
            syncingToggle = true
            pcall(function()
                toggle:Set(S.enabled)
            end)
            syncingToggle = false
        end
    end

    local function panic()
        setEnabled(false, true)
        S.roam = false
        if roamToggle and roamToggle.Set then pcall(function() roamToggle:Set(false) end) end

        local root = getRoot()
        if root then
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.CanCollide = true
            end)
        end

        notifyUser("Better Void", "panic stopped", "warning")
    end

    local function saveReturnMarker()
        local root = getRoot()
        if not root then
            notifyUser("Return marker", "character root missing", "error")
            return false
        end

        S.returnX = root.Position.X
        S.returnY = root.Position.Y
        S.returnZ = root.Position.Z
        S.hasReturnMarker = true
        saveConfig()
        notifyUser("Return marker", "saved", "success")
        return true
    end

    local function returnToMarker()
        if not S.hasReturnMarker then
            notifyUser("Return marker", "no marker saved", "warning")
            return false
        end

        local root = getRoot()
        if not root then
            notifyUser("Return marker", "character root missing", "error")
            return false
        end

        setEnabled(false, true)
        pcall(function()
            root.CFrame = CFrame.new(S.returnX, S.returnY + S.returnHeight, S.returnZ)
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.CanCollide = true
        end)
        notifyUser("Return marker", "returned", "success")
        return true
    end

    local PRESETS = {
        ["Above map"] = { height = 650, rate = 0.08, velocity = 1200, roam = false, roamRadius = 900, roamSpeed = 0.8 },
        ["Wide roam"] = { height = 900, rate = 0.08, velocity = 1350, roam = true, roamRadius = 1400, roamSpeed = 0.65 },
        ["High sky"] = { height = 2500, rate = 0.06, velocity = 1800, roam = true, roamRadius = 1800, roamSpeed = 0.55 },
        ["Fast circle"] = { height = 700, rate = 0.05, velocity = 1600, roam = true, roamRadius = 800, roamSpeed = 1.6 }
    }

    local function applyPreset(name)
        local preset = PRESETS[name]
        if not preset then
            return false
        end

        for key, value in pairs(preset) do
            S[key] = value
        end
        clampSettings()
        syncUi()
        notifyUser("Preset", name, "success")
        return true
    end

    function S.setEnabled(on) setEnabled(on, true) end
    function S.toggle() setEnabled(not S.enabled, true) end
    function S.setRoam(on)
        S.roam = on and true or false
        notifyUser("Better Void", S.roam and "roam enabled" or "roam disabled", S.roam and "success" or "warning")
    end
    function S.toggleRoam() S.setRoam(not S.roam) end
    function S.panic() panic() end
    function S.saveReturnMarker() return saveReturnMarker() end
    function S.returnToMarker() return returnToMarker() end
    function S.saveConfig()
        local ok, err = saveConfig()
        notifyUser("Config", ok and "saved" or ("save failed: " .. tostring(err)), ok and "success" or "error")
        return ok, err
    end
    function S.loadConfig()
        local ok, err = loadConfig()
        if ok then syncUi() end
        notifyUser("Config", ok and "loaded" or ("load failed: " .. tostring(err)), ok and "success" or "error")
        return ok, err
    end
    function S.applyPreset(name) return applyPreset(name) end

    local loadedConfig = loadConfig()

    local function removeOverlay()
        for _, item in pairs(overlay.items) do
            pcall(function()
                item:Remove()
            end)
        end
        overlay.items = {}
    end

    local function setupOverlay()
        if not Drawing then
            return
        end

        local ok = pcall(function()
            local bg = Drawing.new("Square")
            bg.Filled = true
            bg.Color = Color3.fromRGB(10, 10, 10)
            bg.Transparency = 0.72
            bg.Position = Vector2.new(12, 120)
            bg.Size = Vector2.new(230, 108)
            bg.Visible = false

            local text = Drawing.new("Text")
            text.Size = 13
            text.Center = false
            text.Outline = true
            text.Color = Color3.fromRGB(235, 240, 255)
            text.Position = Vector2.new(20, 128)
            text.Visible = false

            local radar = Drawing.new("Circle")
            radar.Filled = false
            radar.Thickness = 1
            radar.NumSides = 64
            radar.Color = Color3.fromRGB(80, 170, 255)
            radar.Transparency = 0.6
            radar.Position = Vector2.new(196, 174)
            radar.Radius = 36
            radar.Visible = false

            local dot = Drawing.new("Circle")
            dot.Filled = true
            dot.NumSides = 16
            dot.Color = Color3.fromRGB(120, 255, 170)
            dot.Position = Vector2.new(196, 174)
            dot.Radius = 4
            dot.Visible = false

            overlay.items.bg = bg
            overlay.items.text = text
            overlay.items.radar = radar
            overlay.items.dot = dot
        end)

        if not ok then
            removeOverlay()
            return
        end

        task.spawn(function()
            while S.running do
                local shown = S.showOverlay == true
                local root = getRoot()
                local bg = overlay.items.bg
                local text = overlay.items.text
                local radar = overlay.items.radar
                local dot = overlay.items.dot

                if bg and text and radar and dot then
                    bg.Visible = shown
                    text.Visible = shown
                    radar.Visible = shown
                    dot.Visible = shown

                    if shown then
                        local pos = root and root.Position
                        local x = pos and math.floor(pos.X) or 0
                        local y = pos and math.floor(pos.Y) or 0
                        local z = pos and math.floor(pos.Z) or 0
                        text.Text = "Better Void\nVoid: " .. (S.enabled and "ON" or "OFF") .. "  Roam: " .. (S.roam and "ON" or "OFF") .. "\nXYZ: " .. x .. ", " .. y .. ", " .. z .. "\nMarker: " .. (S.hasReturnMarker and "saved" or "none")

                        local dx = 0
                        local dz = 0
                        if root and S.anchorX and S.anchorZ then
                            dx = root.Position.X - S.anchorX
                            dz = root.Position.Z - S.anchorZ
                        end

                        local scale = math.max(100, S.roamRadius) / 32
                        local px = math.max(-32, math.min(32, dx / scale))
                        local pz = math.max(-32, math.min(32, dz / scale))
                        dot.Position = Vector2.new(196 + px, 174 + pz)
                    end
                end

                task.wait(0.1)
            end
        end)
    end

    function S.unload()
        setEnabled(false, false)
        S.running = false
        removeOverlay()

        if win then
            pcall(function()
                if win.Destroy then
                    win:Destroy()
                elseif win.Unload then
                    win:Unload()
                end
            end)
            win = nil
        end

        pcall(function()
            if Lib and Lib.Destroy then
                Lib:Destroy()
            end
        end)

        _G.BetterVoid = nil
    end

    local function loadInsUi()
        local ok, result = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua"))()
        end)

        if ok then
            return result or INSUI or INSui
        end

        warn("Better Void: INS-ui failed to load: " .. tostring(result))
        return nil
    end

    local function createUi()
        Lib = loadInsUi()
        if not Lib or not Lib.CreateWindow then
            notifyUser("Better Void", "loaded without UI. V toggles, X unloads.", "warning")
            return false
        end

        win = Lib:CreateWindow({
            title = "Better Void",
            subtitle = "Void only",
            size = Vector2.new(620, 430),
            position = Vector2.new(48, 48),
            menuKey = "p",
            theme = { accent = Color3.fromRGB(80, 170, 255) },
            accentA = Color3.fromRGB(80, 170, 255),
            accentB = Color3.fromRGB(180, 120, 255),
            font = "Proxima",
            opacity = 0.95,
            rounding = 1,
            rowLines = true,
            checkboxStyle = true,
            keybindOverlay = true,
            backgroundEffect = "Rain",
            backgroundEffectColor = Color3.fromRGB(80, 170, 255),
            autoSave = false,
            smartFps = true,
            gameInput = false,
            startOpen = true
        })

        if win.AddSettingsTab then
            win:AddSettingsTab("cog")
        end

        local tab = win:Tab("Void", "shield")
        local controls = tab:Section("Controls", "Left", "void movement")
        local utilities = tab:Section("Utilities", "Left", "presets, marker, config")
        local status = tab:Section("Status", "Right", "live values")

        toggle = controls:Toggle("Better Void", false, function(on)
            if syncingToggle then
                return
            end
            setEnabled(on, false)
        end)
        if toggle and toggle.AddKeybind then
            toggle:AddKeybind("v", "Toggle")
        end

        handles.height = controls:Slider("Height", S.height, 25, 100, 10000, " studs", function(v)
            S.height = math.floor(v)
        end)
        handles.rate = controls:Slider("Tick delay", S.rate, 0.01, 0.03, 0.5, "s", function(v)
            S.rate = math.max(0.03, v)
        end)
        handles.velocity = controls:Slider("Up velocity", S.velocity, 100, 500, 5000, "", function(v)
            S.velocity = math.floor(v)
        end)
        handles.returnHeight = controls:Slider("Return height", S.returnHeight, 1, 0, 50, " studs", function(v)
            S.returnHeight = math.floor(v)
        end)

        roamToggle = controls:Toggle("Map roam", S.roam, function(on)
            S.roam = on and true or false
        end)
        handles.roamRadius = controls:Slider("Roam radius", S.roamRadius, 50, 100, 5000, " studs", function(v)
            S.roamRadius = math.floor(v)
        end)
        handles.roamSpeed = controls:Slider("Roam speed", S.roamSpeed, 0.1, 0.1, 5, "", function(v)
            S.roamSpeed = math.max(0.1, v)
        end)
        overlayToggle = controls:Toggle("Position overlay", S.showOverlay, function(on)
            S.showOverlay = on and true or false
        end)

        utilities:Divider("Presets")
        utilities:Button("Above map", function() applyPreset("Above map") end)
        utilities:Button("Wide roam", function() applyPreset("Wide roam") end)
        utilities:Button("High sky", function() applyPreset("High sky") end)
        utilities:Button("Fast circle", function() applyPreset("Fast circle") end)

        utilities:Divider("Return marker")
        utilities:Button("Save marker", function() saveReturnMarker() end)
        utilities:Button("Return to marker", function() returnToMarker() end)

        utilities:Divider("Config")
        utilities:Button("Save config", function()
            local ok, err = saveConfig()
            notifyUser("Config", ok and "saved" or ("save failed: " .. tostring(err)), ok and "success" or "error")
        end)
        utilities:Button("Load config", function()
            local ok, err = loadConfig()
            if ok then syncUi() end
            notifyUser("Config", ok and "loaded" or ("load failed: " .. tostring(err)), ok and "success" or "error")
        end)
        utilities:Button("Panic stop", function() panic() end):SetRisk()
        utilities:Button("Unload", function() S.unload() end):SetRisk()

        status:Label(function() return "Void: " .. (S.enabled and "ON" or "OFF") end)
        status:Label(function() return "Roam: " .. (S.roam and "ON" or "OFF") end)
        status:Label(function() return "Height: " .. tostring(S.height) end)
        status:Label(function() return "Delay: " .. tostring(S.rate) .. "s" end)
        status:Label(function() return "Velocity: " .. tostring(S.velocity) end)
        status:Label(function() return "Roam radius: " .. tostring(S.roamRadius) end)
        status:Label(function()
            local root = getRoot()
            return "Y position: " .. (root and tostring(math.floor(root.Position.Y)) or "none")
        end)
        status:Label(function() return "Marker: " .. (S.hasReturnMarker and "saved" or "none") end)
        status:Info("P menu, V void, R roam, B panic, M/N marker, X unload.")

        syncUi()
        notifyUser("Better Void", "INS-ui loaded. P opens menu, V toggles.", "success")
        return true
    end

    clampSettings()
    setupOverlay()
    local hasUi = createUi()

    if loadedConfig then
        notifyUser("Config", "loaded", "success")
    end

    task.spawn(function()
        while S.running do
            if S.enabled then
                local root = getRoot()
                if root then
                    if not S.anchorX or not S.anchorY or not S.anchorZ then
                        S.anchorX = root.Position.X
                        S.anchorY = root.Position.Y
                        S.anchorZ = root.Position.Z
                    end

                    local offsetX = 0
                    local offsetZ = 0
                    if S.roam then
                        local phase = tick() * S.roamSpeed
                        offsetX = (math.cos(phase) * S.roamRadius) + (math.sin(phase * 1.7) * S.roamRadius * 0.35)
                        offsetZ = (math.sin(phase) * S.roamRadius) + (math.cos(phase * 1.3) * S.roamRadius * 0.35)
                    end

                    pcall(function()
                        local targetX = S.anchorX + offsetX
                        local targetY = S.anchorY + S.height
                        local targetZ = S.anchorZ + offsetZ
                        root.CFrame = CFrame.new(targetX, targetY, targetZ)
                        root.AssemblyLinearVelocity = Vector3.new(0, S.velocity, 0)
                        root.CanCollide = false
                        S.currentX = targetX
                        S.currentY = targetY
                        S.currentZ = targetZ
                    end)
                    S.lastMoveAt = tick()
                    task.wait(S.rate)
                else
                    task.wait(0.15)
                end
            else
                task.wait(0.15)
            end
        end
    end)

    task.spawn(function()
        local keyState = {}
        local function pressed(code)
            local down = iskeypressed and iskeypressed(code)
            local once = down and not keyState[code]
            keyState[code] = down
            return once
        end

        while S.running do
            if (not hasUi) and pressed(118) then setEnabled(not S.enabled, true) end
            if pressed(114) then S.toggleRoam() end
            if pressed(98) then panic() end
            if pressed(109) then saveReturnMarker() end
            if pressed(110) then returnToMarker() end
            if pressed(120) then
                S.unload()
                break
            end
            task.wait(0.03)
        end
    end)
end

task.spawn(boot)