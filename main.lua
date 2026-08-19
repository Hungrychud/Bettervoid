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

local function isMatchaRuntime()
    if type(Instance) == "nil" then
        return true
    end

    if identifyexecutor then
        local ok, name = pcall(function()
            return identifyexecutor()
        end)

        if ok and type(name) == "string" and string.find(string.lower(name), "matcha", 1, true) then
            return true
        end
    end

    return false
end

local MATCHA_RUNTIME = isMatchaRuntime()
local Lib

if not MATCHA_RUNTIME then
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua"))()
    end)

    if ok then
        Lib = result or INSUI or INSui
    else
        warn("Better Void: UI library failed to load; running headless")
    end
end

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
    noReload = true,
    aimCorrector = true,
    aimCorrectorFov = 8,
    targetPriority = 1,
    targetPartMode = 1,
    ignoreTeam = true,
    ignoreDead = true,
    ignoreKnockedAim = true,
    visibleCheck = true,
    showFov = true,
    knockedEsp = true,
    hasReturnMarker = false,
    returnX = 0,
    returnY = 0,
    returnZ = 0,
    instantShoot = false,
    instantShootDelay = 0.01,
    instantShootBurst = 6,
    lastInstantShotAt = 0,
    shootHoldTime = 0.65,
    stabilizeOnAim = true,
    shootAssistUntil = 0,
    shootLockCFrame = nil,
    shootLockX = nil,
    shootLockY = nil,
    shootLockZ = nil,
    autoStomp = false,
    stompTeleport = true,
    stompHoldUntil = 0,
    stompRange = 350,
    stompHeight = 3,
    stompDelay = 0.35,
    stompRepeats = 6,
    stompInterval = 0.08,
    lastStompAt = 0,
    lastStompStatus = "idle",
    anchorX = nil,
    anchorY = nil,
    anchorZ = nil,
    snapBurstUntil = 0,
    snapWindowUntil = 0,
    snapCount = 0,
    lastVoidAt = 0
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
    "noReload",
    "aimCorrector",
    "aimCorrectorFov",
    "targetPriority",
    "targetPartMode",
    "ignoreTeam",
    "ignoreDead",
    "ignoreKnockedAim",
    "visibleCheck",
    "showFov",
    "knockedEsp",
    "hasReturnMarker",
    "returnX",
    "returnY",
    "returnZ",
    "instantShoot",
    "instantShootDelay",
    "instantShootBurst",
    "shootHoldTime",
    "stabilizeOnAim",
    "autoStomp",
    "stompTeleport",
    "stompRange",
    "stompHeight",
    "stompDelay",
    "stompRepeats",
    "stompInterval"
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
    S.aimCorrectorFov = math.max(1, math.min(30, S.aimCorrectorFov))
    S.targetPriority = math.max(1, math.min(3, math.floor(S.targetPriority)))
    S.targetPartMode = math.max(1, math.min(3, math.floor(S.targetPartMode)))
    S.instantShootDelay = math.max(0.01, math.min(0.2, S.instantShootDelay))
    S.instantShootBurst = math.max(1, math.min(20, math.floor(S.instantShootBurst)))
    S.shootHoldTime = math.max(0.05, math.min(2, S.shootHoldTime))
    S.stompRange = math.max(10, math.min(10000, S.stompRange))
    S.stompHeight = math.max(0, math.min(8, S.stompHeight))
    S.stompDelay = math.max(0.1, math.min(2, S.stompDelay))
    S.stompRepeats = math.max(1, math.min(20, math.floor(S.stompRepeats)))
    S.stompInterval = math.max(0.03, math.min(0.5, S.stompInterval))

    return true
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SHOOTER_TABLE = {
    ["[Revolver]"] = {
        ShootingCooldown = 0,
    },
    ["[TacticalShotgun]"] = {
        ShootingCooldown = 0,
    },
    ["[Double-Barrel SG]"] = {
        ShootingCooldown = 0,
    },
}

local function applyShooterSettings(tool)
    if not tool or tool.ClassName ~= "Tool" then
        return
    end

    local settings = SHOOTER_TABLE[tool.Name]
    if not settings then
        return
    end

    local cooldown = tool:FindFirstChild("ShootingCooldown")
    if cooldown and settings.ShootingCooldown ~= nil then
        cooldown.Value = settings.ShootingCooldown
    end

end

local function applyShooterContainer(container)
    if not container then
        return
    end

    for _, child in ipairs(container:GetChildren()) do
        applyShooterSettings(child)
    end
end

local function applyLoadoutShooterSettings()
    local assets = ReplicatedStorage and ReplicatedStorage:FindFirstChild("Assets")
    local loadout = assets and assets:FindFirstChild("Loadout")
    if loadout then
        applyShooterContainer(loadout)
    end
end

local function applyShooterPlayer(player)
    if not player then
        return
    end

    applyShooterContainer(player:FindFirstChild("Backpack"))
    applyShooterContainer(player.Character)
end

local function refillShooterContainer(container)
    if not container then
        return
    end

    for _, tool in ipairs(container:GetChildren()) do
        if tool.ClassName == "Tool" and SHOOTER_TABLE[tool.Name] then
            local ammo = tool:FindFirstChild("Ammo")
            local maxAmmo = tool:FindFirstChild("MaxAmmo")
            if ammo and maxAmmo and ammo.Value < maxAmmo.Value then
                ammo.Value = maxAmmo.Value
            end
        end
    end
end

local function applyNoReload()
    if not S.noReload then
        return
    end

    local char = lp and lp.Character
    local bodyEffects = char and char:FindFirstChild("BodyEffects")
    local reload = bodyEffects and bodyEffects:FindFirstChild("Reload")
    if reload and reload.Value ~= false then
        reload.Value = false
    end

    refillShooterContainer(lp and lp:FindFirstChild("Backpack"))
    refillShooterContainer(char)
end

task.spawn(function()
    while S.running do
        applyLoadoutShooterSettings()
        applyNoReload()

        for _, player in ipairs(Players:GetPlayers()) do
            applyShooterPlayer(player)
        end

        task.wait(0.5)
    end
end)


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
local autoStompToggle
local teleportStompToggle
local notify
local nativeNotify = getfenv and getfenv(1).notify or nil
local visualConn
local visuals = { fov = nil, status = nil, pool = {}, targets = {} }

local function getRoot()
    local char = lp and lp.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getEquippedShooter()
    local char = lp and lp.Character
    if not char then
        return nil
    end

    for _, child in ipairs(char:GetChildren()) do
        if child.ClassName == "Tool" and SHOOTER_TABLE[child.Name] then
            return child
        end
    end

    return nil
end

local function getShotOrigin(tool, handle)
    local origin = handle.Position
    local default = tool:FindFirstChild("Default")
    local mesh = default and default:FindFirstChild("Mesh")
    local muzzle = mesh and mesh:FindFirstChild("Muzzle")
    if muzzle and muzzle.WorldPosition then
        origin = muzzle.WorldPosition
    end
    return origin
end

local function getModeName(value, names)
    return names[value] or names[1]
end

local function getTargetPriorityName()
    return getModeName(S.targetPriority, { "Crosshair", "Distance", "Low health" })
end

local function getTargetPartName()
    return getModeName(S.targetPartMode, { "Head", "Root", "Smart" })
end

local function sameTeam(plr)
    if not S.ignoreTeam or not lp or not lp.Team or not plr or not plr.Team then
        return false
    end

    return lp.Team.Name == plr.Team.Name
end

local function isDeadCharacter(char, hum)
    local bodyEffects = char and char:FindFirstChild("BodyEffects")
    local dead = bodyEffects and bodyEffects:FindFirstChild("Dead")
    return (hum and hum.Health <= 0) or (dead and dead.Value == true)
end

local function isKnockedCharacter(char)
    local bodyEffects = char and char:FindFirstChild("BodyEffects")
    local ko = bodyEffects and bodyEffects:FindFirstChild("K.O")
    local dead = bodyEffects and bodyEffects:FindFirstChild("Dead")
    return ko and ko.Value == true and not (dead and dead.Value == true)
end

local function getAimTargetPosition(char, camPos, camLook)
    local head = char and char:FindFirstChild("Head")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if S.targetPartMode == 2 then
        return root and root.Position or (head and head.Position)
    end

    if S.targetPartMode == 3 then
        local bestPos
        local bestDot = -1
        for _, part in ipairs({ head, root }) do
            if part then
                local delta = part.Position - camPos
                if delta.Magnitude > 0 then
                    local dot = delta.Unit:Dot(camLook)
                    if dot > bestDot then
                        bestDot = dot
                        bestPos = part.Position
                    end
                end
            end
        end
        return bestPos
    end

    return head and head.Position or (root and root.Position)
end

local function passesTargetFilters(plr, char, hum, knockedOnly)
    if not plr or plr.UserId == lp.UserId or sameTeam(plr) then
        return false
    end

    if S.ignoreDead and isDeadCharacter(char, hum) then
        return false
    end

    local knocked = isKnockedCharacter(char)
    if knockedOnly then
        return knocked
    end

    if S.ignoreKnockedAim and knocked then
        return false
    end

    return true
end

local function hasLineOfSight(origin, targetPos, char)
    if not S.visibleCheck then
        return true
    end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { lp.Character }
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    local los = workspace:Raycast(origin, targetPos - origin, params)
    return not los or (los.Instance and los.Instance:IsDescendantOf(char))
end

local function getTargetScore(priority, dot, dist, hum)
    if priority == 2 then
        return -dist
    end

    if priority == 3 then
        return -(hum and hum.Health or 100)
    end

    return dot
end

local function getAimCorrectedPosition(origin, rangeValue)
    if not S.aimCorrector then
        return nil
    end

    local camera = workspace.CurrentCamera
    if not camera then
        return nil
    end

    local camPos = camera.CFrame.Position
    local camLook = camera.CFrame.LookVector
    local minDot = math.cos(math.rad(S.aimCorrectorFov or 8))
    local bestScore = -math.huge
    local bestPos

    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        local hum = char and char:FindFirstChild("Humanoid")

        if passesTargetFilters(plr, char, hum, false) then
            local targetPos = getAimTargetPosition(char, camPos, camLook)
            if targetPos then
                local fromOrigin = targetPos - origin
                local fromCamera = targetPos - camPos

                if fromOrigin.Magnitude <= rangeValue and fromCamera.Magnitude > 0 then
                    local dot = fromCamera.Unit:Dot(camLook)
                    if dot >= minDot and hasLineOfSight(origin, targetPos, char) then
                        local score = getTargetScore(S.targetPriority, dot, fromOrigin.Magnitude, hum)
                        if score > bestScore then
                            bestScore = score
                            bestPos = targetPos
                        end
                    end
                end
            end
        end
    end

    return bestPos
end

local function traceInstantShot(origin, rangeValue, spread)
    local camera = workspace.CurrentCamera
    local correctedPos = getAimCorrectedPosition(origin, rangeValue)
    local direction

    if correctedPos then
        direction = (correctedPos - origin).Unit
    else
        direction = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
    end

    if spread and spread > 0 then
        local spreadScale = correctedPos and (spread * 0.25) or spread
        direction = (direction + Vector3.new(
            (math.random() - 0.5) * spreadScale,
            (math.random() - 0.5) * spreadScale,
            (math.random() - 0.5) * spreadScale
        )).Unit
    end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { lp.Character }
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    local hit = workspace:Raycast(origin, direction * rangeValue, params)
    if hit then
        return hit.Instance, hit.Position, hit.Normal, origin + direction * rangeValue
    end

    return nil, origin + direction * rangeValue, nil, origin + direction * rangeValue
end

local function fireInstantShot(tool)
    if not tool then
        return false
    end

    local ammo = tool:FindFirstChild("Ammo")
    local maxAmmo = tool:FindFirstChild("MaxAmmo")
    local handle = tool:FindFirstChild("Handle")
    local range = tool:FindFirstChild("Range")
    local damage = tool:FindFirstChild("Damage")
    local remotes = ReplicatedStorage and ReplicatedStorage:FindFirstChild("GameRemotes")
    local mainRemote = remotes and remotes:FindFirstChild("MainGameEvent")

    if not ammo or not handle or not range or not damage or not mainRemote then
        return false
    end

    if maxAmmo and ammo.Value < maxAmmo.Value then
        ammo.Value = maxAmmo.Value
    elseif ammo.Value < 1 then
        ammo.Value = 1
    end

    local origin = getShotOrigin(tool, handle)
    local rangeValue = range.Value

    if tool.Name == "[Double-Barrel SG]" or tool.Name == "[TacticalShotgun]" then
        local shots = {}
        for _ = 1, 5 do
            local hit, pos, normal, aimPosition = traceInstantShot(origin, rangeValue, 0.1)
            shots[#shots + 1] = {
                AimPosition = aimPosition,
                Result1 = hit,
                Result2 = pos,
                Result3 = normal
            }
        end
        mainRemote:FireServer("ShootGun", handle, origin, shots, nil, nil, nil, rangeValue, damage.Value)
    else
        local hit, pos, normal = traceInstantShot(origin, rangeValue, 0)
        mainRemote:FireServer("ShootGun", handle, origin, nil, hit, pos, normal, rangeValue, damage.Value)
    end

    return true
end

local function getCharacterRoot(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
end

local function getHumanoidRootPart(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function isKnocked(char)
    local bodyEffects = char and char:FindFirstChild("BodyEffects")
    local ko = bodyEffects and bodyEffects:FindFirstChild("K.O")
    local dead = bodyEffects and bodyEffects:FindFirstChild("Dead")

    return ko and ko.Value == true and not (dead and dead.Value == true)
end

local function getNearestKnockedTarget(maxRange)
    local localRoot = getRoot()
    if not localRoot then
        return nil
    end

    local camera = workspace.CurrentCamera
    local camPos = camera and camera.CFrame.Position or localRoot.Position
    local camLook = camera and camera.CFrame.LookVector or localRoot.CFrame.LookVector
    local bestChar
    local bestRoot
    local bestDist
    local bestScore = -math.huge
    local localPos = localRoot.Position
    local range = maxRange or 85

    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local root = getCharacterRoot(char)

        if root and passesTargetFilters(plr, char, hum, true) then
            local delta = root.Position - localPos
            local dist = S.enabled and Vector3.new(delta.X, 0, delta.Z).Magnitude or delta.Magnitude

            if dist <= range then
                local camDelta = root.Position - camPos
                local dot = camDelta.Magnitude > 0 and camDelta.Unit:Dot(camLook) or 0
                local score = getTargetScore(S.targetPriority, dot, dist, hum)

                if score > bestScore then
                    bestChar = char
                    bestRoot = root
                    bestDist = dist
                    bestScore = score
                end
            end
        end
    end

    return bestChar, bestRoot, bestDist
end

local function stompTarget(targetRoot)
    local root = getRoot()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = ReplicatedStorage and ReplicatedStorage:FindFirstChild("GameRemotes")
    local mainRemote = remotes and remotes:FindFirstChild("MainGameEvent")

    if not root or not targetRoot or not mainRemote then
        S.lastStompStatus = "missing root/target/remote"
        return false
    end

    if S.stompTeleport then
        local stompPos = targetRoot.Position + Vector3.new(0, S.stompHeight, 0)
        local stompCf = CFrame.new(stompPos.X, stompPos.Y, stompPos.Z)
        S.stompHoldUntil = tick() + 0.25
        S.shootLockCFrame = stompCf
        S.shootLockX = stompPos.X
        S.shootLockY = stompPos.Y
        S.shootLockZ = stompPos.Z

        pcall(function()
            root.CFrame = stompCf
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.CanCollide = true
        end)
    end

    mainRemote:FireServer("Stomp")
    S.lastStompStatus = S.stompTeleport and "stomp fired" or "stomp fired without teleport"

    return true
end

notify = function(title, text, kind)
    if Lib and Lib.Notify then
        local ok = pcall(function()
            Lib:Notify(title, text, 2, kind or "info")
        end)
        if ok then
            return
        end
    end

    if nativeNotify then
        local ok = pcall(function()
            nativeNotify(title, text, 2)
        end)
        if ok then
            return
        end
    end

    print("[Better Void] " .. tostring(title) .. ": " .. tostring(text))
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
        S.shootLockCFrame = nil
        S.shootLockX = nil
        S.shootLockY = nil
        S.shootLockZ = nil
        S.stompHoldUntil = 0
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
    S.shootLockCFrame = nil
    S.shootLockX = nil
    S.shootLockY = nil
    S.shootLockZ = nil
    S.stompHoldUntil = 0
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

local function saveReturnMarker()
    local root = getRoot()
    if not root then
        notify("Return marker", "character root missing", "error")
        return false
    end

    S.returnX = root.Position.X
    S.returnY = root.Position.Y
    S.returnZ = root.Position.Z
    S.hasReturnMarker = true
    saveConfig()
    notify("Return marker", "saved", "success")
    return true
end

local function returnToMarker()
    if not S.hasReturnMarker then
        notify("Return marker", "no marker saved", "warning")
        return false
    end

    local root = getRoot()
    if not root then
        notify("Return marker", "character root missing", "error")
        return false
    end

    pcall(function()
        root.CFrame = CFrame.new(S.returnX, S.returnY + S.returnHeight, S.returnZ)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.CanCollide = true
    end)
    notify("Return marker", "returned", "success")
    return true
end

local function panicAll()
    S.enabled = false
    S.autoStomp = false
    S.instantShoot = false
    S.noReload = false
    S.shootAssistUntil = 0
    S.stompHoldUntil = 0
    stopVoid("panic disabled active features")

    if toggle and toggle.Set then
        pcall(function()
            toggle:Set(false)
        end)
    end
    if autoStompToggle and autoStompToggle.Set then
        pcall(function()
            autoStompToggle:Set(false)
        end)
    end
end

local function manualStompOnce()
    local _, targetRoot = getNearestKnockedTarget(S.stompRange)
    if targetRoot and stompTarget(targetRoot) then
        S.lastStompAt = tick()
        notify("Manual stomp", "stomp fired", "success")
        return true
    end

    S.lastStompStatus = "manual: no knocked target"
    notify("Manual stomp", "no knocked target", "warning")
    return false
end

S.setEnabled = setEnabled
S.stopVoid = stopVoid
S.panic = panicAll
S.stompOnce = manualStompOnce
S.saveReturnMarker = saveReturnMarker
S.returnToMarker = returnToMarker
S.saveConfig = saveConfig
S.loadConfig = loadConfig

local win

if Lib and Lib.CreateWindow then
win = Lib:CreateWindow({
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
local visualControls = shootingTab:Section("Visuals", "Right", "aim + target display")

toggle = controls:Toggle("Better Void", false, function(on)
    setEnabled(on)
end)

if toggle and toggle.AddKeybind then
    toggle:AddKeybind("v", "Toggle")
end

controls:Slider("Up height", S.height, 25, 100, 100000, "", function(v)
    S.height = math.floor(v)
    saveConfig()
end)

controls:Slider("Tick delay", S.rate, 0.01, 0.03, 0.5, "s", function(v)
    S.rate = math.max(0.03, v)
    saveConfig()
end)

controls:Slider("Up velocity", S.velocity, 100, 500, 50000, "", function(v)
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

controls:Slider("Roam radius", S.roamRadius, 50, 100, 1000, "", function(v)
    S.roamRadius = math.floor(v)
    saveConfig()
end)

controls:Slider("Roam speed", S.roamSpeed, 1, 1, 100000, "", function(v)
    S.roamSpeed = math.floor(v)
    saveConfig()
end)

controls:Slider("Return height", S.returnHeight, 1, 0, 50, " studs", function(v)
    S.returnHeight = math.floor(v)
    saveConfig()
end)

shootAssistToggle = shootingControls:Toggle("Aim stabilizer", S.shootAssist, function(on)
    S.shootAssist = on and true or false
    saveConfig()
end)

shootingControls:Toggle("No reload", S.noReload, function(on)
    S.noReload = on and true or false
    saveConfig()
end)

shootingControls:Toggle("Aim corrector", S.aimCorrector, function(on)
    S.aimCorrector = on and true or false
    saveConfig()
end)

shootingControls:Slider("Aim FOV", S.aimCorrectorFov, 1, 1, 30, " deg", function(v)
    S.aimCorrectorFov = math.max(1, v)
    saveConfig()
end)

shootingControls:Button("Cycle target priority", function()
    S.targetPriority = (S.targetPriority % 3) + 1
    saveConfig()
    notify("Target priority", getTargetPriorityName(), "info")
end)

shootingControls:Button("Cycle target part", function()
    S.targetPartMode = (S.targetPartMode % 3) + 1
    saveConfig()
    notify("Target part", getTargetPartName(), "info")
end)

shootingControls:Toggle("Ignore team", S.ignoreTeam, function(on)
    S.ignoreTeam = on and true or false
    saveConfig()
end)

shootingControls:Toggle("Ignore dead", S.ignoreDead, function(on)
    S.ignoreDead = on and true or false
    saveConfig()
end)

shootingControls:Toggle("Ignore knocked aim", S.ignoreKnockedAim, function(on)
    S.ignoreKnockedAim = on and true or false
    saveConfig()
end)

shootingControls:Toggle("Visible check", S.visibleCheck, function(on)
    S.visibleCheck = on and true or false
    saveConfig()
end)

visualControls:Toggle("FOV circle", S.showFov, function(on)
    S.showFov = on and true or false
    saveConfig()
end)

visualControls:Toggle("Knocked ESP", S.knockedEsp, function(on)
    S.knockedEsp = on and true or false
    saveConfig()
end)

visualControls:Button("Save return marker", function()
    saveReturnMarker()
end)

visualControls:Button("Return to marker", function()
    returnToMarker()
end)

visualControls:Button("Manual stomp once", function()
    manualStompOnce()
end)

visualControls:Button("Panic disable", function()
    panicAll()
end):SetRisk()

shootingControls:Toggle("Visual rapid fire", S.instantShoot, function(on)
    S.instantShoot = on and true or false
    saveConfig()
end)

shootingControls:Slider("Visual fire delay", S.instantShootDelay, 0.005, 0.01, 0.2, "s", function(v)
    S.instantShootDelay = math.max(0.01, v)
    saveConfig()
end)

shootingControls:Slider("Visual fire burst", S.instantShootBurst, 1, 1, 20, "", function(v)
    S.instantShootBurst = math.max(1, math.floor(v))
    saveConfig()
end)

shootingControls:Toggle("Stabilize on aim", S.stabilizeOnAim, function(on)
    S.stabilizeOnAim = on and true or false
    saveConfig()
end)

shootingControls:Slider("Hold time", S.shootHoldTime, 0.01, 0.05, 2, "s", function(v)
    S.shootHoldTime = math.max(0.05, v)
    saveConfig()
end)

autoStompToggle = shootingControls:Toggle("Auto stomp", S.autoStomp, function(on)
    S.autoStomp = on and true or false
    saveConfig()
end)

if autoStompToggle and autoStompToggle.AddKeybind then
    autoStompToggle:AddKeybind("z", "Toggle")
end

teleportStompToggle = shootingControls:Toggle("Teleport stomp", S.stompTeleport, function(on)
    S.stompTeleport = on and true or false
    saveConfig()
end)

if teleportStompToggle and teleportStompToggle.AddKeybind then
    teleportStompToggle:AddKeybind("c", "Toggle")
end

shootingControls:Slider("Stomp range", S.stompRange, 5, 10, 10000, " studs", function(v)
    S.stompRange = math.floor(v)
    saveConfig()
end)

shootingControls:Slider("Stomp height", S.stompHeight, 0.5, 0, 8, " studs", function(v)
    S.stompHeight = math.max(0, v)
    saveConfig()
end)

shootingControls:Slider("Stomp delay", S.stompDelay, 0.05, 0.1, 2, "s", function(v)
    S.stompDelay = math.max(0.1, v)
    saveConfig()
end)

shootingControls:Slider("Stomp repeats", S.stompRepeats, 1, 1, 20, "", function(v)
    S.stompRepeats = math.max(1, math.floor(v))
    saveConfig()
end)

shootingControls:Slider("Repeat interval", S.stompInterval, 0.01, 0.03, 0.5, "s", function(v)
    S.stompInterval = math.max(0.03, v)
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
    return "Aim stabilizer: " .. (S.shootAssist and "ON" or "OFF")
end)
info:Label(function()
    return "No reload: " .. (S.noReload and "ON" or "OFF")
end)
info:Label(function()
    return "Aim corrector: " .. (S.aimCorrector and "ON" or "OFF")
end)
info:Label(function()
    return "Aim FOV: " .. tostring(S.aimCorrectorFov) .. " deg"
end)
info:Label(function()
    return "Target priority: " .. getTargetPriorityName()
end)
info:Label(function()
    return "Target part: " .. getTargetPartName()
end)
info:Label(function()
    return "Filters: " .. (S.ignoreTeam and "team " or "") .. (S.visibleCheck and "visible" or "")
end)
info:Label(function()
    return "Return marker: " .. (S.hasReturnMarker and "saved" or "none")
end)
info:Label(function()
    return "Visual rapid fire: " .. (S.instantShoot and "ON" or "OFF")
end)
info:Label(function()
    return "Visual fire delay: " .. tostring(S.instantShootDelay) .. "s"
end)
info:Label(function()
    return "Visual fire burst: " .. tostring(S.instantShootBurst)
end)
info:Label(function()
    return "Stabilize on aim: " .. (S.stabilizeOnAim and "ON" or "OFF")
end)
info:Label(function()
    return "Hold time: " .. tostring(S.shootHoldTime) .. "s"
end)
info:Label(function()
    return "Auto stomp: " .. (S.autoStomp and "ON" or "OFF")
end)
info:Label(function()
    return "Teleport stomp: " .. (S.stompTeleport and "ON" or "OFF")
end)
info:Label(function()
    return "Stomp range: " .. tostring(S.stompRange)
end)
info:Label(function()
    return "Stomp height: " .. tostring(S.stompHeight)
end)
info:Label(function()
    return "Stomp repeats: " .. tostring(S.stompRepeats)
end)
info:Label(function()
    return "Stomp status: " .. tostring(S.lastStompStatus)
end)
info:Label(function()
    local root = getRoot()
    return "Y position: " .. (root and tostring(math.floor(root.Position.Y)) or "none")
end)
info:Info("Keys: V void, Z auto stomp, C teleport stomp, J stomp once, B panic, M/N marker, 1-3 load, 4-6 save.")
info:Button("Unload", function()
    S.unload()
end):SetRisk()
else
    notify("Better Void", "Matcha/headless mode. Keys: V void, Z auto stomp, C teleport stomp, J stomp once, B panic, X unload.", "info")
end

function S.unload()
    S.enabled = false
    S.running = false

    local env = getgenv and getgenv() or _G
    env.BETTERVOID_LOADER_LOADED = nil
    env.BETTERVOID_LOADED = nil

    if visualConn then
        pcall(function()
            visualConn:Disconnect()
        end)
        visualConn = nil
    end

    if visuals.fov then
        pcall(function()
            visuals.fov:Remove()
        end)
        visuals.fov = nil
    end

    if visuals.status then
        pcall(function()
            visuals.status:Remove()
        end)
        visuals.status = nil
    end

    for _, item in ipairs(visuals.pool) do
        pcall(function()
            if item.tag then item.tag:Remove() end
            if item.line then item.line:Remove() end
        end)
    end
    visuals.pool = {}
    visuals.targets = {}

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

local function setupVisuals()
    if not Drawing or not RunService then
        return
    end

    local ok = pcall(function()
        visuals.fov = Drawing.new("Circle")
        visuals.fov.Color = Color3.fromRGB(80, 170, 255)
        visuals.fov.Thickness = 1
        visuals.fov.NumSides = 96
        visuals.fov.Filled = false
        visuals.fov.Transparency = 0.2
        visuals.fov.Visible = false

        if MATCHA_RUNTIME then
            visuals.status = Drawing.new("Text")
            visuals.status.Size = 14
            visuals.status.Center = false
            visuals.status.Outline = true
            visuals.status.Color = Color3.fromRGB(80, 170, 255)
            visuals.status.Position = Vector2.new(12, 120)
            visuals.status.Text = "Better Void loaded | V toggle | X unload"
            visuals.status.Visible = true
        end

        for i = 1, 16 do
            local tag = Drawing.new("Text")
            tag.Size = 13
            tag.Center = true
            tag.Outline = true
            tag.Color = Color3.fromRGB(255, 110, 110)
            tag.Visible = false

            local line = Drawing.new("Line")
            line.Thickness = 1
            line.Color = Color3.fromRGB(255, 110, 110)
            line.Transparency = 0.35
            line.Visible = false

            visuals.pool[i] = { tag = tag, line = line }
        end
    end)

    if not ok then
        visuals.fov = nil
        visuals.pool = {}
        return
    end

    task.spawn(function()
        while S.running do
            local out = {}
            if S.knockedEsp then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr.UserId ~= lp.UserId then
                        local char = plr.Character
                        local hum = char and char:FindFirstChild("Humanoid")
                        local root = getCharacterRoot(char)
                        if root and passesTargetFilters(plr, char, hum, true) then
                            out[#out + 1] = { name = plr.Name, root = root }
                            if #out >= #visuals.pool then
                                break
                            end
                        end
                    end
                end
            end
            visuals.targets = out
            task.wait(0.4)
        end
    end)

    visualConn = RunService.RenderStepped:Connect(function()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize
        local center = viewport and Vector2.new(viewport.X * 0.5, viewport.Y * 0.5) or Vector2.new(0, 0)

        if visuals.status then
            visuals.status.Position = Vector2.new(12, 120)
            visuals.status.Text = "Better Void | Void: " .. (S.enabled and "ON" or "OFF") .. " | Auto stomp: " .. (S.autoStomp and "ON" or "OFF") .. " | V/Z/C/J/B/X"
            visuals.status.Visible = true
        end

        if visuals.fov then
            if S.showFov and S.aimCorrector and viewport and camera then
                local fov = math.max(1, S.aimCorrectorFov or 8)
                local radius = math.tan(math.rad(fov)) / math.tan(math.rad(camera.FieldOfView * 0.5)) * viewport.Y * 0.5
                visuals.fov.Position = center
                visuals.fov.Radius = math.max(4, radius)
                visuals.fov.Visible = true
            else
                visuals.fov.Visible = false
            end
        end

        local used = 0
        if S.knockedEsp and viewport then
            for i = 1, #visuals.targets do
                if used >= #visuals.pool then break end
                local target = visuals.targets[i]
                local pos, visible = WorldToScreen(target.root.Position + Vector3.new(0, 2.5, 0))
                local foot, footVisible = WorldToScreen(target.root.Position - Vector3.new(0, 2.5, 0))
                if visible and footVisible then
                    used = used + 1
                    local item = visuals.pool[used]
                    item.tag.Text = target.name .. " K.O"
                    item.tag.Position = Vector2.new(pos.X, pos.Y - 14)
                    item.tag.Visible = true
                    item.line.From = Vector2.new(center.X, viewport.Y - 8)
                    item.line.To = Vector2.new(foot.X, foot.Y)
                    item.line.Visible = true
                end
            end
        end

        for i = used + 1, #visuals.pool do
            local item = visuals.pool[i]
            item.tag.Visible = false
            item.line.Visible = false
        end
    end)
end

setupVisuals()

task.spawn(function()
    while S.running do
        applyNoReload()
        task.wait(0.08)
    end
end)
task.spawn(function()
    local keyState = {}
    local lastAim = false

    local function pressed(code)
        local down = iskeypressed and iskeypressed(code)
        local once = down and not keyState[code]
        keyState[code] = down
        return once
    end

    local function loadSlot(slot)
        local ok, err = loadConfig(slot)
        notify("Config", ok and (slot .. " loaded") or ("load failed: " .. tostring(err or "file missing")), ok and "success" or "error")
    end

    local function saveSlot(slot)
        local ok, err = saveConfig(slot)
        notify("Config", ok and (slot .. " saved") or ("save failed: " .. tostring(err)), ok and "success" or "error")
    end

    while S.running do
        local mouse1 = ismouse1pressed and ismouse1pressed()
        local mouse2 = ismouse2pressed and ismouse2pressed()
        local aiming = mouse1 or (S.stabilizeOnAim and mouse2)

        if pressed(118) then
            setEnabled(not S.enabled)
            if toggle and toggle.Set then
                pcall(function()
                    toggle:Set(S.enabled)
                end)
            end
        end

        if pressed(120) then
            S.unload()
            break
        end

        if pressed(106) then
            manualStompOnce()
        end
        if pressed(98) then
            panicAll()
        end
        if pressed(109) then
            saveReturnMarker()
        end
        if pressed(110) then
            returnToMarker()
        end
        if pressed(49) then loadSlot("Slot1") end
        if pressed(50) then loadSlot("Slot2") end
        if pressed(51) then loadSlot("Slot3") end
        if pressed(52) then saveSlot("Slot1") end
        if pressed(53) then saveSlot("Slot2") end
        if pressed(54) then saveSlot("Slot3") end

        if S.instantShoot and mouse1 then
            local now = tick()
            if now - S.lastInstantShotAt >= S.instantShootDelay then
                local tool = getEquippedShooter()
                local fired = false
                if tool then
                    for _ = 1, S.instantShootBurst do
                        fired = fireInstantShot(tool) or fired
                    end
                end
                if fired then
                    S.lastInstantShotAt = now
                end
            end
        end

        if S.enabled and S.shootAssist and aiming then
            local root = getRoot()
            if root and not lastAim then
                S.shootLockCFrame = root.CFrame
                S.shootLockX = root.Position.X
                S.shootLockY = root.Position.Y
                S.shootLockZ = root.Position.Z
            end
            S.shootAssistUntil = tick() + S.shootHoldTime
            if not lastAim then
                S.snapBurstUntil = tick() + 0.25
            end
        end
        lastAim = aiming
        task.wait(0.02)
    end
end)

task.spawn(function()
    while S.running do
        if S.autoStomp then
            local now = tick()
            if now - S.lastStompAt >= S.stompDelay then
                local targetChar, targetRoot = getNearestKnockedTarget(S.stompRange)
                if targetRoot and stompTarget(targetRoot) then
                    S.lastStompAt = now
                elseif not targetRoot then
                    S.lastStompStatus = "no knocked target in range"
                else
                    S.lastStompStatus = "stomp prep failed"
                end
            end
            task.wait(0.08)
        else
            task.wait(0.25)
        end
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
                local stomping = t < S.stompHoldUntil
                local holding = shooting or stomping
                local burst = S.antiSnap and t < S.snapBurstUntil
                local offsetX = 0
                local offsetZ = 0

                if S.roam and not holding then
                    local phase = t * S.roamSpeed
                    offsetX = (math.cos(phase) * S.roamRadius) + (math.sin(phase * 1.7) * S.roamRadius * 0.35)
                    offsetZ = (math.sin(phase) * S.roamRadius) + (math.cos(phase * 1.3) * S.roamRadius * 0.35)
                end

                pcall(function()
                    if holding then
                        if not S.shootLockCFrame then
                            S.shootLockCFrame = root.CFrame
                        end
                        if not S.shootLockX or not S.shootLockY or not S.shootLockZ then
                            S.shootLockX = root.Position.X
                            S.shootLockY = root.Position.Y
                            S.shootLockZ = root.Position.Z
                        end
                        root.CFrame = S.shootLockCFrame
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.CanCollide = true
                    else
                        S.shootLockCFrame = nil
                        S.shootLockX = nil
                        S.shootLockY = nil
                        S.shootLockZ = nil
                        root.CFrame = CFrame.new(S.anchorX + offsetX, S.anchorY + S.height, S.anchorZ + offsetZ)
                        root.AssemblyLinearVelocity = Vector3.new(0, S.velocity, 0)
                        root.CanCollide = false
                    end
                end)
                S.lastVoidAt = t

                if holding then
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
            S.shootLockCFrame = nil
            S.shootLockX = nil
            S.shootLockY = nil
            S.shootLockZ = nil
            S.stompHoldUntil = 0
            task.wait(0.15)
        end
    end
end)

if loadedConfig then
    notify("Config", "loaded", "success")
end

if Lib and Lib.CreateWindow then
    notify("Better Void", "loaded. Press P to toggle the menu.", "success")
else
    notify("Better Void", "loaded in Matcha/headless mode. Use V/Z/C/J/B/M/N/1-6/X hotkeys.", "success")
end
end

task.spawn(boot)
