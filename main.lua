local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local mouse = lp and lp:GetMouse()

if _G.BetterVoidGUI and _G.BetterVoidGUI.unload then
    pcall(function()
        _G.BetterVoidGUI.unload()
    end)
end

local S = {
    enabled = false,
    autoArmor = false,
    buyingArmor = false,
    running = true,
    depthIndex = 1,
    rateIndex = 1,
    lastArmorBuyAt = 0,
    armorText = "",
    drawings = {},
    conns = {}
}

_G.BetterVoidGUI = S

local depths = { -25000, -50000, -100000 }
local rates = { 0.25, 0.18, 0.12 }
local armorCooldown = 8
local armorRestoreDelay = 0.35
local armorTriggerRatio = 0.95

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

local bg = rect(20, 190, 270, 204, Color3.fromRGB(15, 16, 20))
local accent = rect(20, 190, 270, 3, Color3.fromRGB(80, 170, 255))
local title = label(34, 204, 17, "Better Void", Color3.fromRGB(255, 255, 255))
local status = label(34, 230, 14, "", Color3.fromRGB(160, 220, 255))
local detail = label(34, 251, 13, "", Color3.fromRGB(220, 220, 220))
local armorStatus = label(34, 370, 12, "", Color3.fromRGB(180, 235, 190))

local btnToggle = rect(34, 281, 100, 30, Color3.fromRGB(120, 55, 55))
local txtToggle = label(55, 288, 13, "TOGGLE", Color3.fromRGB(255, 255, 255))

local btnDepth = rect(144, 281, 62, 30, Color3.fromRGB(60, 70, 115))
local txtDepth = label(157, 288, 13, "DEPTH", Color3.fromRGB(255, 255, 255))

local btnSpeed = rect(216, 281, 60, 30, Color3.fromRGB(95, 65, 115))
local txtSpeed = label(228, 288, 13, "SPEED", Color3.fromRGB(255, 255, 255))

local btnArmor = rect(34, 322, 100, 30, Color3.fromRGB(90, 70, 45))
local txtArmor = label(58, 329, 13, "ARMOR", Color3.fromRGB(255, 255, 255))

local hotkeys = label(34, 357, 12, "V void | M armor | B/N cfg | X unload", Color3.fromRGB(200, 200, 200))

local function refresh()
    if not S.running then
        return
    end

    status.Text = "Status: " .. (S.enabled and "ON" or "OFF")
    detail.Text = "Depth: " .. tostring(depths[S.depthIndex]) .. " | Tick: " .. tostring(rates[S.rateIndex]) .. "s"
    armorStatus.Text = "Armor: " .. (S.autoArmor and "AUTO" or "MANUAL") .. (S.armorText ~= "" and (" | " .. S.armorText) or "")
    btnToggle.Color = S.enabled and Color3.fromRGB(45, 150, 90) or Color3.fromRGB(120, 55, 55)
    btnArmor.Color = S.autoArmor and Color3.fromRGB(45, 150, 90) or Color3.fromRGB(90, 70, 45)
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

local function toggleArmor()
    S.autoArmor = not S.autoArmor
    S.armorText = S.autoArmor and "waiting" or ""
    refresh()
end

local function inside(x, y, bx, by, bw, bh)
    return x >= bx and x <= bx + bw and y >= by and y <= by + bh
end

local function getRoot()
    local char = lp and lp.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getArmor()
    local char = lp and lp.Character
    local effects = char and char:FindFirstChild("BodyEffects")
    local armor = effects and effects:FindFirstChild("Armor")
    local maxArmor = ReplicatedStorage and ReplicatedStorage:FindFirstChild("MaxArmor")

    if armor and maxArmor then
        return armor.Value or 0, maxArmor.Value or 0
    end

    return nil, nil
end

local function needsArmor()
    local armor, maxArmor = getArmor()

    if not armor or not maxArmor or maxArmor <= 0 then
        S.armorText = "no armor stat"
        refresh()
        return false
    end

    if armor >= maxArmor * armorTriggerRatio then
        S.armorText = tostring(math.floor(armor)) .. "/" .. tostring(math.floor(maxArmor))
        refresh()
        return false
    end

    return true
end

local function findNearestArmor(root)
    local ignored = workspace and workspace:FindFirstChild("Ignored")
    local shop = ignored and ignored:FindFirstChild("Shop")

    if not shop then
        return nil
    end

    local bestItem
    local bestHead
    local bestDetector
    local bestDistance

    for _, item in ipairs(shop:GetChildren()) do
        if item.Name and string.find(string.lower(item.Name), "full armor", 1, true) then
            local head = item:FindFirstChild("Head")
            local detector = item:FindFirstChildOfClass("ClickDetector")

            if head and detector then
                local distance = (head.Position - root.Position).Magnitude
                if not bestDistance or distance < bestDistance then
                    bestItem = item
                    bestHead = head
                    bestDetector = detector
                    bestDistance = distance
                end
            end
        end
    end

    return bestItem, bestHead, bestDetector
end

local function buyArmor()
    if S.buyingArmor or not S.running then
        return
    end

    if tick() - S.lastArmorBuyAt < armorCooldown then
        return
    end

    if not needsArmor() then
        return
    end

    local root = getRoot()
    if not root then
        S.armorText = "no root"
        refresh()
        return
    end

    local item, head, detector = findNearestArmor(root)
    if not item or not head or not detector then
        S.armorText = "no shop"
        refresh()
        return
    end

    S.buyingArmor = true
    S.lastArmorBuyAt = tick()
    S.armorText = "buying"
    refresh()

    local oldCFrame = root.CFrame
    local oldVelocity = root.AssemblyLinearVelocity

    pcall(function()
        root.CFrame = CFrame.new(head.Position + Vector3.new(0, 3, 0))
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end)

    task.wait(0.2)

    pcall(function()
        detector:FireServer()
    end)

    task.wait(armorRestoreDelay)

    pcall(function()
        root.CFrame = oldCFrame
        root.AssemblyLinearVelocity = oldVelocity
    end)

    S.armorText = item.Name
    S.buyingArmor = false
    refresh()
end

function S.unload()
    S.enabled = false
    S.autoArmor = false
    S.running = false

    for _, c in ipairs(S.conns) do
        if c and c.Disconnect then
            pcall(function()
                c:Disconnect()
            end)
        end
    end

    for _, d in ipairs(S.drawings) do
        if d and d.Remove then
            pcall(function()
                d:Remove()
            end)
        end
    end

    _G.BetterVoidGUI = nil
end

refresh()

S.conns[#S.conns + 1] = UIS.InputBegan:Connect(function(input)
    local key = input and input.KeyCode

    if key == 86 then
        S.enabled = not S.enabled
        refresh()
    elseif key == 66 then
        cycleDepth()
    elseif key == 78 then
        cycleSpeed()
    elseif key == 77 then
        toggleArmor()
    elseif key == 88 then
        S.unload()
    end
end)

task.spawn(function()
    local wasDown = false

    while S.running do
        local down = ismouse1pressed()

        if down and not wasDown then
            local x = mouse and mouse.X
            local y = mouse and mouse.Y

            if type(x) == "number" and type(y) == "number" then
                if inside(x, y, 34, 281, 100, 30) then
                    S.enabled = not S.enabled
                    refresh()
                elseif inside(x, y, 144, 281, 62, 30) then
                    cycleDepth()
                elseif inside(x, y, 216, 281, 60, 30) then
                    cycleSpeed()
                elseif inside(x, y, 34, 322, 100, 30) then
                    toggleArmor()
                end
            end
        end

        wasDown = down
        task.wait(0.04)
    end
end)

task.spawn(function()
    local lastRoot

    while S.running do
        if S.enabled and not S.buyingArmor then
            local char = lp and lp.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")

            if root then
                if root ~= lastRoot then
                    lastRoot = root
                    pcall(function()
                        root.CanCollide = false
                    end)
                end

                pcall(function()
                    root.CFrame = CFrame.new(0, depths[S.depthIndex], 0)
                    root.AssemblyLinearVelocity = Vector3.new(0, -2000, 0)
                end)
            end

            task.wait(rates[S.rateIndex])
        else
            task.wait(0.15)
        end
    end
end)

task.spawn(function()
    while S.running do
        if S.autoArmor then
            buyArmor()
            task.wait(1)
        else
            task.wait(0.25)
        end
    end
end)
