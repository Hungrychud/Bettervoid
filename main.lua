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
    warn("Better Void: LocalPlayer not found after waiting")
    return
end

if _G.BetterVoid and _G.BetterVoid.unload then
    pcall(function()
        _G.BetterVoid.unload()
    end)
end

local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua"))()
Lib = Lib or INSUI or INSui

local S = {
    enabled = false,
    running = true,
    height = 650,
    rate = 0.08,
    velocity = 1200,
    antiSnap = true,
    roam = true,
    roamRadius = 900,
    roamSpeed = 8,
    returnHeight = 3,
    shootAssist = true,
    shootAssistHeight = 3,
    shootAssistUntil = 0,
    magDump = false,
    magDumpDelay = 0.001,
    magDumping = false,
    anchorX = nil,
    anchorY = nil,
    anchorZ = nil,
    snapBurstUntil = 0,
    snapWindowUntil = 0,
    snapCount = 0,
    lastVoidAt = 0,
    conns = {}
}

local CONFIG_FOLDER = "BetterVoid"
local CONFIG_SLOT = "Default"
local CONFIG_FILE = CONFIG_FOLDER .. "/bettervoid_default.cfg"
local CONFIG_KEYS = {
    "height",
    "rate",
    "velocity",
    "antiSnap",
    "roam",
    "roamRadius",
    "roamSpeed",
    "returnHeight",
    "shootAssist",
    "shootAssistHeight",
    "magDump",
    "magDumpDelay"
}

local function ensureConfigFolder()
    if isfolder and not isfolder(CONFIG_FOLDER) and makefolder then
        pcall(function()
            makefolder(CONFIG_FOLDER)
        end)
    end
end

local function setConfigSlot(name)
    CONFIG_SLOT = name or "Default"
    CONFIG_FILE = CONFIG_FOLDER .. "/bettervoid_" .. string.lower(CONFIG_SLOT) .. ".cfg"
end

local function saveConfig(slot)
    if not writefile then
        return false, "writefile missing"
    end

    if slot then
        setConfigSlot(slot)
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

local function loadConfig(slot)
    if slot then
        setConfigSlot(slot)
    end

    if not readfile or not isfile or not isfile(CONFIG_FILE) then
        return false
    end

    local ok, data = pcall(function()
        return readfile(CONFIG_FILE)
    end)

    if not ok or type(data) ~= "string" then
        return false, data
    end

    for line in string.gmatch(data, "[^\r\n]+") do
        local key, raw = string.match(line, "^([%w_]+)=(.+)$")
        if key and S[key] ~= nil then
            local currentType = type(S[key])
            if currentType == "boolean" then
                S[key] = raw == "true"
            elseif currentType == "number" then
                local value = tonumber(raw)
                if value then
                    S[key] = value
                end
            end
        end
    end

    S.height = math.max(100, math.min(10000, S.height))
    S.rate = math.max(0.03, math.min(0.5, S.rate))
    S.velocity = math.max(500, math.min(5000, S.velocity))
    S.roamRadius = math.max(100, math.min(5000, S.roamRadius))
    S.roamSpeed = math.max(1, math.min(40, S.roamSpeed))
    S.returnHeight = math.max(0, math.min(50, S.returnHeight))
    S.shootAssistHeight = math.max(0, math.min(50, S.shootAssistHeight))
    S.magDumpDelay = math.max(0.001, math.min(0.2, S.magDumpDelay))

    return true
end

local function deleteConfig(slot)
    if not delfile then
        return false, "delfile missing"
    end

    if slot then
        setConfigSlot(slot)
    end

    if not isfile or not isfile(CONFIG_FILE) then
        return false, "no config to delete"
    end

    local ok, err = pcall(function()
        delfile(CONFIG_FILE)
    end)

    return ok, err
end

local loadedConfig = loadConfig()

_G.BetterVoid = S

local toggle
local shootAssistToggle
local magDumpToggle

local function getRoot()
    local char = lp and lp.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getEquippedGun()
    local char = lp and lp.Character
    if not char then
        return nil
    end

    for _, item in ipairs(char:GetChildren()) do
        if item.ClassName == "Tool" and item:FindFirstChild("Ammo") and item:FindFirstChild("ShootingCooldown") then
            return item
        end
    end

    return nil
end

local function startMagDump()
    if S.magDumping then
        return
    end

    S.magDumping = true

    task.spawn(function()
        local tool = getEquippedGun()
        local ammo = tool and tool:FindFirstChild("Ammo")
        local cooldown = tool and tool:FindFirstChild("ShootingCooldown")
        local oldCooldown = cooldown and cooldown.Value

        if cooldown then
            pcall(function()
                cooldown.Value = 0
            end)
        end

        while S.running and S.enabled and S.magDump do
            tool = getEquippedGun()
            ammo = tool and tool:FindFirstChild("Ammo")

            if not tool or not ammo or ammo.Value <= 0 then
                break
            end

            if S.shootAssist then
                S.shootAssistUntil = tick() + 0.16
            end

            if mouse1click then
                mouse1click()
            elseif mouse1press and mouse1release then
                mouse1press()
                task.wait(0.01)
                mouse1release()
            else
                break
            end

            task.wait(math.max(0.001, S.magDumpDelay))
        end

        if cooldown and oldCooldown then
            pcall(function()
                cooldown.Value = oldCooldown
            end)
        end

        S.magDumping = false
    end)
end

local function notify(title, text, kind)
    if Lib and Lib.Notify then
        Lib:Notify(title, text, 2, kind or "info")
    end
end

local function setEnabled(on)
    S.enabled = on and true or false

    if S.enabled then
        local root = getRoot()
        if root then
            S.anchorX = root.Position.X
            S.anchorY = root.Position.Y
            S.anchorZ = root.Position.Z
        end
        S.snapBurstUntil = tick() + 1.25
        S.snapWindowUntil = 0
        S.snapCount = 0
        S.lastVoidAt = 0
    else
        local root = getRoot()
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
        S.snapBurstUntil = 0
        S.snapWindowUntil = 0
        S.snapCount = 0
        S.lastVoidAt = 0
    end

    notify("Better Void", S.enabled and "enabled" or "disabled", S.enabled and "success" or "warning")
end

local function stopVoid(reason)
    S.enabled = false
    S.anchorX = nil
    S.anchorY = nil
    S.anchorZ = nil
    S.snapBurstUntil = 0
    S.snapWindowUntil = 0
    S.snapCount = 0
    S.lastVoidAt = 0

    local root = getRoot()
    if root then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.CanCollide = true
        end)
    end

    if toggle and toggle.Set then
        pcall(function()
            toggle:Set(false)
        end)
    end

    notify("Better Void", reason or "disabled", "warning")
end

local win = Lib:CreateWindow({
    title = "Better Void",
    subtitle = "INS UI",
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

local voidTab = win:Tab("Void", "shield")
local shootingTab = win:Tab("Shooting", "crosshair")
local settingsTab = win:Tab("Settings", "cog")
local controls = voidTab:Section("Controls", "Left", "stable void loop")
local shootingControls = shootingTab:Section("Controls", "Left", "shooting while roaming")

toggle = controls:Toggle("Better Void", false, function(on)
    setEnabled(on)
end)

if toggle and toggle.AddKeybind then
    toggle:AddKeybind("v", "Toggle")
end

controls:Slider("Up height", S.height, 25, 100, 10000, "", function(v)
    S.height = math.floor(v)
    saveConfig()
end)

controls:Slider("Tick delay", S.rate, 0.01, 0.03, 0.5, "s", function(v)
    S.rate = math.max(0.03, v)
    saveConfig()
end)

controls:Slider("Up velocity", S.velocity, 100, 500, 5000, "", function(v)
    S.velocity = math.floor(v)
    saveConfig()
end)

controls:Toggle("Anti snapback", S.antiSnap, function(on)
    S.antiSnap = on and true or false
    saveConfig()
end)

controls:Toggle("Map roam", S.roam, function(on)
    S.roam = on and true or false
    saveConfig()
end)

controls:Slider("Roam radius", S.roamRadius, 50, 100, 5000, "", function(v)
    S.roamRadius = math.floor(v)
    saveConfig()
end)

controls:Slider("Roam speed", S.roamSpeed, 1, 1, 40, "", function(v)
    S.roamSpeed = math.floor(v)
    saveConfig()
end)

controls:Slider("Return height", S.returnHeight, 1, 0, 50, " studs", function(v)
    S.returnHeight = math.floor(v)
    saveConfig()
end)

shootAssistToggle = shootingControls:Toggle("Shoot assist", S.shootAssist, function(on)
    S.shootAssist = on and true or false
    saveConfig()
end)

shootingControls:Slider("Shoot height", S.shootAssistHeight, 1, 0, 50, " studs", function(v)
    S.shootAssistHeight = math.floor(v)
    saveConfig()
end)

magDumpToggle = shootingControls:Toggle("Mag dump", S.magDump, function(on)
    S.magDump = on and true or false
    saveConfig()
end)

shootingControls:Slider("Dump delay", S.magDumpDelay, 0.001, 0.001, 0.2, "s", function(v)
    S.magDumpDelay = math.max(0.001, v)
    saveConfig()
end)

controls:Divider("Presets")

controls:Button("Above map", function()
    S.height = 650
    S.rate = 0.08
    S.velocity = 1200
    S.roamRadius = 900
    S.roamSpeed = 8
    saveConfig()
    notify("Preset", "above map selected", "success")
end)

controls:Button("High sky", function()
    S.height = 2500
    S.rate = 0.06
    S.velocity = 1800
    S.roamRadius = 1400
    S.roamSpeed = 11
    saveConfig()
    notify("Preset", "high sky selected", "info")
end)

controls:Button("Very high", function()
    S.height = 10000
    S.rate = 0.05
    S.velocity = 2500
    S.roamRadius = 2200
    S.roamSpeed = 15
    saveConfig()
    notify("Preset", "very high selected", "warning")
end)

shootingControls:Button("Dump now", function()
    if not S.enabled then
        notify("Mag dump", "turn Better Void on first", "warning")
        return
    end

    if not S.magDump then
        S.magDump = true
        if magDumpToggle and magDumpToggle.Set then
            pcall(function()
                magDumpToggle:Set(true)
            end)
        end
        saveConfig()
    end

    startMagDump()
end)

controls:Button("Return to origin", function()
    S.enabled = false
    local root = getRoot()
    if root then
        root.CFrame = CFrame.new(0, 25, 0)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.CanCollide = true
    end
    if toggle and toggle.Set then
        pcall(function()
            toggle:Set(false)
        end)
    end
end)

local configSection = settingsTab:Section("Config slots", "Left", "save, load, delete")

local function addConfigSlot(slotName)
    configSection:Divider(slotName)

    configSection:Button("Save " .. slotName, function()
        local ok, err = saveConfig(slotName)
        if ok then
            notify("Config", slotName .. " saved", "success")
        else
            notify("Config", "save failed: " .. tostring(err), "error")
        end
    end)

    configSection:Button("Load " .. slotName, function()
        local ok, err = loadConfig(slotName)
        if ok then
            notify("Config", slotName .. " loaded. Reopen GUI to refresh slider positions.", "success")
        else
            notify("Config", "load failed: " .. tostring(err or "file missing"), "error")
        end
    end)

    local deleteButton = configSection:Button("Delete " .. slotName, function()
        local ok, err = deleteConfig(slotName)
        if ok then
            notify("Config", slotName .. " deleted", "warning")
        else
            notify("Config", "delete failed: " .. tostring(err), "error")
        end
    end)

    if deleteButton and deleteButton.SetRisk then
        deleteButton:SetRisk()
    end
end

addConfigSlot("Slot1")
addConfigSlot("Slot2")
addConfigSlot("Slot3")

local settingsInfo = settingsTab:Section("Status", "Right", "active config")
settingsInfo:Label(function()
    return "Active slot: " .. tostring(CONFIG_SLOT)
end)
settingsInfo:Label(function()
    return "File: " .. tostring(CONFIG_FILE)
end)

local info = voidTab:Section("Status", "Right", "live values")
info:Label(function()
    return "Status: " .. (S.enabled and "ON" or "OFF")
end)
info:Label(function()
    return "Up height: " .. tostring(S.height)
end)
info:Label(function()
    return "Tick: " .. tostring(S.rate) .. "s"
end)
info:Label(function()
    return "Anti snap: " .. (S.antiSnap and "ON" or "OFF")
end)
info:Label(function()
    return "Roam: " .. (S.roam and "ON" or "OFF")
end)
info:Label(function()
    return "Radius: " .. tostring(S.roamRadius)
end)
info:Label(function()
    return "Shoot assist: " .. (S.shootAssist and "ON" or "OFF")
end)
info:Label(function()
    return "Shoot height: " .. tostring(S.shootAssistHeight)
end)
info:Label(function()
    return "Mag dump: " .. (S.magDump and "ON" or "OFF")
end)
info:Label(function()
    return "Dump delay: " .. tostring(S.magDumpDelay) .. "s"
end)
info:Label(function()
    local root = getRoot()
    return "Y position: " .. (root and tostring(math.floor(root.Position.Y)) or "none")
end)
info:Info("Press P to open/close the menu. V toggles Better Void. X unloads everything.")
info:Button("Unload", function()
    S.unload()
end):SetRisk()

function S.unload()
    S.enabled = false
    S.running = false

    for _, c in ipairs(S.conns) do
        if c and c.Disconnect then
            pcall(function()
                c:Disconnect()
            end)
        end
    end

    if win then
        pcall(function()
            if win.Destroy then
                win:Destroy()
            elseif win.Unload then
                win:Unload()
            end
        end)
    end

    pcall(function()
        if Lib and Lib.Destroy then
            Lib:Destroy()
        end
    end)

    _G.BetterVoid = nil
end

task.spawn(function()
    local lastV = false
    local lastX = false
    local lastMouse1 = false

    while S.running do
        local v = iskeypressed(118)
        local x = iskeypressed(120)
        local mouse1 = ismouse1pressed and ismouse1pressed()

        if v and not lastV then
            setEnabled(not S.enabled)
            if toggle and toggle.Set then
                pcall(function()
                    toggle:Set(S.enabled)
                end)
            end
        end

        if x and not lastX then
            S.unload()
            break
        end

        if S.enabled and S.magDump and mouse1 and not lastMouse1 then
            startMagDump()
        elseif S.enabled and S.shootAssist and mouse1 then
            S.shootAssistUntil = tick() + 0.16
            if not lastMouse1 then
                S.snapBurstUntil = tick() + 0.25
            end
        end

        lastV = v
        lastX = x
        lastMouse1 = mouse1
        task.wait(0.02)
    end
end)

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

                local t = tick()
                if S.antiSnap and S.lastVoidAt > 0 and root.Position.Y > -50 then
                    if t > S.snapWindowUntil then
                        S.snapWindowUntil = t + 4
                        S.snapCount = 0
                    end

                    S.snapCount = S.snapCount + 1

                    if S.snapCount >= 3 then
                        stopVoid("server snapback detected; void stopped")
                        task.wait(0.35)
                        continue
                    end

                    S.snapBurstUntil = t + 0.45
                end

                local shooting = S.shootAssist and t < S.shootAssistUntil
                local burst = S.antiSnap and t < S.snapBurstUntil
                local offsetX = 0
                local offsetZ = 0

                if S.roam and not shooting then
                    local phase = t * S.roamSpeed
                    offsetX = (math.cos(phase) * S.roamRadius) + (math.sin(phase * 1.7) * S.roamRadius * 0.35)
                    offsetZ = (math.sin(phase) * S.roamRadius) + (math.cos(phase * 1.3) * S.roamRadius * 0.35)
                end

                pcall(function()
                    if shooting then
                        root.CFrame = CFrame.new(S.anchorX, S.anchorY + S.shootAssistHeight, S.anchorZ)
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.CanCollide = true
                    else
                        root.CFrame = CFrame.new(S.anchorX + offsetX, S.anchorY + S.height, S.anchorZ + offsetZ)
                        root.AssemblyLinearVelocity = Vector3.new(0, S.velocity, 0)
                        root.CanCollide = false
                    end
                end)
                S.lastVoidAt = t

                if shooting then
                    task.wait(0.02)
                elseif burst then
                    task.wait(0.045)
                else
                    task.wait(S.rate)
                end
            else
                task.wait(0.15)
            end
        else
            S.anchorX = nil
            S.anchorY = nil
            S.anchorZ = nil
            task.wait(0.15)
        end
    end
end)

if loadedConfig then
    notify("Config", "loaded", "success")
end

notify("Better Void", "loaded. Press P to toggle the menu.", "success")
end

task.spawn(boot)
