local Players = game:GetService("Players")
local lp = Players.LocalPlayer

if _G.BetterVoid and _G.BetterVoid.unload then
    _G.BetterVoid.unload()
end

local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua"))()
Lib = Lib or INSUI or INSui

local S = {
    enabled = false,
    running = true,
    depth = -25000,
    rate = 0.25,
    velocity = -2000,
    conns = {}
}

_G.BetterVoid = S

local function notify(title, text, kind)
    if Lib and Lib.Notify then
        Lib:Notify(title, text, 2, kind or "info")
    end
end

local function setEnabled(on)
    S.enabled = on and true or false
    notify("Better Void", S.enabled and "enabled" or "disabled", S.enabled and "success" or "warning")
end

local function getRoot()
    local char = lp.Character
    return char and char:FindFirstChild("HumanoidRootPart")
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
    configName = "bettervoid",
    configFolder = "BetterVoid",
    autoSave = true,
    smartFps = true,
    gameInput = false,
    startOpen = true
})

if win.AddSettingsTab then
    win:AddSettingsTab("cog")
end

local voidTab = win:Tab("Void", "shield")
local controls = voidTab:Section("Controls", "Left", "stable void loop")

local toggle = controls:Toggle("Better Void", false, function(on)
    setEnabled(on)
end)

if toggle and toggle.AddKeybind then
    toggle:AddKeybind("v", "Toggle")
end

controls:Slider("Depth", 25000, 1000, 10000, 100000, "", function(v)
    S.depth = -math.floor(v)
end)

controls:Slider("Tick delay", 0.25, 0.01, 0.12, 0.5, "s", function(v)
    S.rate = math.max(0.12, v)
end)

controls:Slider("Fall velocity", 2000, 100, 500, 5000, "", function(v)
    S.velocity = -math.floor(v)
end)

controls:Button("Return to origin", function()
    local root = getRoot()
    if root then
        root.CFrame = CFrame.new(0, 25, 0)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end
end)

local info = voidTab:Section("Status", "Right", "live values")
info:Label(function()
    return "Status: " .. (S.enabled and "ON" or "OFF")
end)
info:Label(function()
    return "Depth: " .. tostring(S.depth)
end)
info:Label(function()
    return "Tick: " .. tostring(S.rate) .. "s"
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
        c:Disconnect()
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

    while S.running do
        local v = iskeypressed(118)
        local x = iskeypressed(120)

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

        lastV = v
        lastX = x
        task.wait(0.04)
    end
end)

task.spawn(function()
    while S.running do
        if S.enabled then
            local root = getRoot()

            if root then
                root.CFrame = CFrame.new(0, S.depth, 0)
                root.AssemblyLinearVelocity = Vector3.new(0, S.velocity, 0)
                root.CanCollide = false
            end

            task.wait(S.rate)
        else
            task.wait(0.15)
        end
    end
end)

notify("Better Void", "loaded. Press P to toggle the menu.", "success")

