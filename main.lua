local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local mouse = lp:GetMouse()

if _G.BetterVoidGUI and _G.BetterVoidGUI.unload then
    _G.BetterVoidGUI.unload()
end

local S = {
    enabled = false,
    running = true,
    depthIndex = 1,
    rateIndex = 1,
    drawings = {},
    conns = {}
}

_G.BetterVoidGUI = S

local depths = { -25000, -50000, -100000 }
local rates = { 0.25, 0.18, 0.12 }
local KEY_B = 98
local KEY_N = 110
local KEY_V = 118
local KEY_X = 120

local function add(obj)
    S.drawings[#S.drawings + 1] = obj
    return obj
end

local function rect(x, y, w, h, color)
    local d = add(Drawing.new("Square"))
    d.Position = Vector2.new(x, y)
    d.Size = Vector2.new(w, h)
    d.Color = color
    d.Filled = true
    d.Transparency = 0.08
    d.Visible = true
    return d
end

local function label(x, y, size, value, color)
    local d = add(Drawing.new("Text"))
    d.Position = Vector2.new(x, y)
    d.Size = size
    d.Text = value
    d.Color = color
    d.Outline = true
    d.Visible = true
    return d
end

local bg = rect(20, 190, 270, 164, Color3.fromRGB(15, 16, 20))
local accent = rect(20, 190, 270, 3, Color3.fromRGB(80, 170, 255))
local title = label(34, 204, 17, "Better Void", Color3.fromRGB(255, 255, 255))
local status = label(34, 230, 14, "", Color3.fromRGB(160, 220, 255))
local detail = label(34, 251, 13, "", Color3.fromRGB(220, 220, 220))

local btnToggle = rect(34, 281, 100, 30, Color3.fromRGB(120, 55, 55))
local txtToggle = label(55, 288, 13, "TOGGLE", Color3.fromRGB(255, 255, 255))

local btnDepth = rect(144, 281, 62, 30, Color3.fromRGB(60, 70, 115))
local txtDepth = label(157, 288, 13, "DEPTH", Color3.fromRGB(255, 255, 255))

local btnSpeed = rect(216, 281, 60, 30, Color3.fromRGB(95, 65, 115))
local txtSpeed = label(228, 288, 13, "SPEED", Color3.fromRGB(255, 255, 255))

local hotkeys = label(34, 327, 12, "V toggle | B depth | N speed | X unload", Color3.fromRGB(200, 200, 200))

local function refresh()
    status.Text = "Status: " .. (S.enabled and "ON" or "OFF")
    detail.Text = "Depth: " .. tostring(depths[S.depthIndex]) .. " | Tick: " .. tostring(rates[S.rateIndex]) .. "s"
    btnToggle.Color = S.enabled and Color3.fromRGB(45, 150, 90) or Color3.fromRGB(120, 55, 55)
end

local function cycleDepth()
    S.depthIndex = S.depthIndex + 1
    if S.depthIndex > #depths then
        S.depthIndex = 1
    end
    refresh()
end

local function cycleSpeed()
    S.rateIndex = S.rateIndex + 1
    if S.rateIndex > #rates then
        S.rateIndex = 1
    end
    refresh()
end

local function inside(x, y, bx, by, bw, bh)
    return x >= bx and x <= bx + bw and y >= by and y <= by + bh
end

function S.unload()
    S.enabled = false
    S.running = false

    for _, c in ipairs(S.conns) do
        c:Disconnect()
    end

    for _, d in ipairs(S.drawings) do
        d:Remove()
    end

    _G.BetterVoidGUI = nil
end

refresh()

S.conns[#S.conns + 1] = UIS.InputBegan:Connect(function(input)
    local key = input.KeyCode

    if key == KEY_V then
        S.enabled = not S.enabled
        refresh()
    elseif key == KEY_B then
        cycleDepth()
    elseif key == KEY_N then
        cycleSpeed()
    elseif key == KEY_X then
        S.unload()
    end
end)

task.spawn(function()
    local lastB = false
    local lastN = false
    local lastV = false
    local lastX = false

    while S.running do
        local b = iskeypressed(KEY_B)
        local n = iskeypressed(KEY_N)
        local v = iskeypressed(KEY_V)
        local x = iskeypressed(KEY_X)

        if v and not lastV then
            S.enabled = not S.enabled
            refresh()
        end

        if b and not lastB then
            cycleDepth()
        end

        if n and not lastN then
            cycleSpeed()
        end

        if x and not lastX then
            S.unload()
            break
        end

        lastB = b
        lastN = n
        lastV = v
        lastX = x

        task.wait(0.04)
    end
end)

task.spawn(function()
    local wasDown = false

    while S.running do
        local down = ismouse1pressed()

        if down and not wasDown then
            local x, y = mouse.X, mouse.Y

            if inside(x, y, 34, 281, 100, 30) then
                S.enabled = not S.enabled
                refresh()
            elseif inside(x, y, 144, 281, 62, 30) then
                cycleDepth()
            elseif inside(x, y, 216, 281, 60, 30) then
                cycleSpeed()
            end
        end

        wasDown = down
        task.wait(0.04)
    end
end)

task.spawn(function()
    while S.running do
        if S.enabled then
            local char = lp.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")

            if root then
                root.CFrame = CFrame.new(0, depths[S.depthIndex], 0)
                root.AssemblyLinearVelocity = Vector3.new(0, -2000, 0)
                root.CanCollide = false
            end

            task.wait(rates[S.rateIndex])
        else
            task.wait(0.15)
        end
    end
end)
