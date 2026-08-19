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

    local S = {
        enabled = false,
        running = true,
        height = 650,
        rate = 0.08,
        velocity = 1200,
        returnHeight = 3,
        anchorX = nil,
        anchorY = nil,
        anchorZ = nil,
        lastMoveAt = 0
    }

    _G.BetterVoid = S

    local Lib
    local win
    local toggle
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

    local function getRoot()
        local char = lp and lp.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function setEnabled(on, syncUi)
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

        if syncUi ~= false and toggle and toggle.Set and not syncingToggle then
            syncingToggle = true
            pcall(function()
                toggle:Set(S.enabled)
            end)
            syncingToggle = false
        end
    end

    function S.setEnabled(on)
        setEnabled(on, true)
    end

    function S.toggle()
        setEnabled(not S.enabled, true)
    end

    function S.unload()
        setEnabled(false, false)
        S.running = false

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
            notifyUser("Better Void", "void-only loaded without UI. V toggles, X unloads.", "warning")
            return false
        end

        win = Lib:CreateWindow({
            title = "Better Void",
            subtitle = "Void only",
            size = Vector2.new(560, 360),
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
        local controls = tab:Section("Controls", "Left", "only the void loop")
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

        controls:Slider("Height", S.height, 25, 100, 10000, " studs", function(v)
            S.height = math.floor(v)
        end)

        controls:Slider("Tick delay", S.rate, 0.01, 0.03, 0.5, "s", function(v)
            S.rate = math.max(0.03, v)
        end)

        controls:Slider("Up velocity", S.velocity, 100, 500, 5000, "", function(v)
            S.velocity = math.floor(v)
        end)

        controls:Slider("Return height", S.returnHeight, 1, 0, 50, " studs", function(v)
            S.returnHeight = math.floor(v)
        end)

        controls:Button("Unload", function()
            S.unload()
        end):SetRisk()

        status:Label(function()
            return "Void: " .. (S.enabled and "ON" or "OFF")
        end)
        status:Label(function()
            return "Height: " .. tostring(S.height)
        end)
        status:Label(function()
            return "Delay: " .. tostring(S.rate) .. "s"
        end)
        status:Label(function()
            return "Velocity: " .. tostring(S.velocity)
        end)
        status:Label(function()
            local root = getRoot()
            return "Y position: " .. (root and tostring(math.floor(root.Position.Y)) or "none")
        end)
        status:Info("P opens menu. V toggles void. X unloads.")

        notifyUser("Better Void", "INS-ui loaded. P opens menu, V toggles.", "success")
        return true
    end

    local hasUi = createUi()

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

                    pcall(function()
                        root.CFrame = CFrame.new(S.anchorX, S.anchorY + S.height, S.anchorZ)
                        root.AssemblyLinearVelocity = Vector3.new(0, S.velocity, 0)
                        root.CanCollide = false
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
            if not hasUi and pressed(118) then
                setEnabled(not S.enabled, true)
            end
            if pressed(120) then
                S.unload()
                break
            end
            task.wait(0.03)
        end
    end)
end

task.spawn(boot)