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
        "aimStabilizer",
        "aimHoldTime",
        "antiStick",
        "avoidRadius",
        "avoidShift",
        "avoidHeightBoost",
        "showOverlay",
        "autoArmor",
        "armorCooldown",
        "armorTriggerRatio",
        "invincible",
        "invincibleHealRatio",
        "invincibleInterval",
        "unshootable",
        "unshootableHitboxSize",
        "unshootableInterval",
        "hasReturnMarker",
        "returnX",
        "returnY",
        "returnZ"
    }

    local S = {
        enabled = false,
        running = true,
        height = 100000,
        rate = 0.08,
        velocity = 1200,
        returnHeight = 3,
        roam = false,
        roamRadius = 900,
        roamSpeed = 100000,
        aimStabilizer = true,
        aimHoldTime = 0.75,
        aimHoldUntil = 0,
        aimLockX = nil,
        aimLockY = nil,
        aimLockZ = nil,
        antiStick = true,
        avoidRadius = 180,
        avoidShift = 2500,
        avoidHeightBoost = 3500,
        showOverlay = true,
        autoArmor = false,
        armorBuying = false,
        armorCooldown = 8,
        armorTriggerRatio = 0.95,
        armorStatus = "idle",
        armorSafeMode = true,
        invincible = false,
        invincibleHealRatio = 0.85,
        invincibleInterval = 0.08,
        invincibleStatus = "idle",
        unshootable = false,
        unshootableHitboxSize = 0.01,
        unshootableInterval = 0.25,
        unshootableStatus = "idle",
        unshootableOriginal = {},
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
        lastThreatName = "none",
        lastThreatDistance = 0,
        lastMoveAt = 0
    }

    _G.BetterVoid = S

    local Lib
    local win
    local toggle
    local roamToggle
    local overlayToggle
    local autoArmorToggle
    local invincibleToggle
    local unshootableToggle
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
        S.height = math.max(100, math.min(100000, tonumber(S.height) or 100000))
        S.rate = math.max(0.03, math.min(0.5, tonumber(S.rate) or 0.08))
        S.velocity = math.max(500, math.min(5000, tonumber(S.velocity) or 1200))
        S.returnHeight = math.max(0, math.min(50, tonumber(S.returnHeight) or 3))
        S.roamRadius = math.max(100, math.min(5000, tonumber(S.roamRadius) or 900))
        S.roamSpeed = math.max(0.1, math.min(100000, tonumber(S.roamSpeed) or 100000))
        S.aimHoldTime = math.max(0.05, math.min(3, tonumber(S.aimHoldTime) or 0.75))
        S.avoidRadius = math.max(25, math.min(2000, tonumber(S.avoidRadius) or 180))
        S.avoidShift = math.max(100, math.min(10000, tonumber(S.avoidShift) or 2500))
        S.avoidHeightBoost = math.max(0, math.min(100000, tonumber(S.avoidHeightBoost) or 3500))
        S.armorCooldown = math.max(2, math.min(60, tonumber(S.armorCooldown) or 8))
        S.armorTriggerRatio = math.max(0.1, math.min(1, tonumber(S.armorTriggerRatio) or 0.95))
        S.invincibleHealRatio = math.max(0.1, math.min(1, tonumber(S.invincibleHealRatio) or 0.85))
        S.invincibleInterval = math.max(0.03, math.min(0.5, tonumber(S.invincibleInterval) or 0.08))
        S.unshootableHitboxSize = math.max(0.01, math.min(0.5, tonumber(S.unshootableHitboxSize) or 0.01))
        S.unshootableInterval = math.max(0.1, math.min(2, tonumber(S.unshootableInterval) or 0.25))
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

    local function getHumanoid()
        local char = lp and lp.Character
        if not char then
            return nil
        end

        local hum = nil
        pcall(function()
            hum = char:FindFirstChildOfClass("Humanoid")
        end)
        return hum or char:FindFirstChild("Humanoid")
    end

    local function setValueObject(parent, name, value)
        local item = parent and parent:FindFirstChild(name)
        if item then
            pcall(function()
                item.Value = value
            end)
        end
    end

    local function applyInvinciblePulse()
        local char = lp and lp.Character
        local hum = getHumanoid()
        if not char or not hum then
            S.invincibleStatus = "character missing"
            return false
        end

        local maxHealth = tonumber(hum.MaxHealth) or 100
        if maxHealth < 100 then
            pcall(function()
                hum.MaxHealth = 100
            end)
            maxHealth = 100
        end

        local health = tonumber(hum.Health) or 0
        if health <= 0 or health < maxHealth * S.invincibleHealRatio then
            pcall(function()
                hum.Health = maxHealth
            end)
        end

        pcall(function()
            hum.BreakJointsOnDeath = false
        end)
        pcall(function()
            if Enum and Enum.HumanoidStateType and hum.SetStateEnabled then
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            end
        end)
        pcall(function()
            if Enum and Enum.HumanoidStateType and hum.ChangeState then
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)

        local effects = char:FindFirstChild("BodyEffects")
        if effects then
            local maxArmor = game:GetService("ReplicatedStorage"):FindFirstChild("MaxArmor")
            setValueObject(effects, "Defense", 100)
            setValueObject(effects, "Armor", maxArmor and (tonumber(maxArmor.Value) or 200) or 200)
            setValueObject(effects, "FireArmor", 100)
            setValueObject(effects, "K.O", false)
            setValueObject(effects, "KO", false)
            setValueObject(effects, "Dead", false)
            setValueObject(effects, "Grabbed", false)
            setValueObject(effects, "Ragdolled", false)
        end

        S.invincibleStatus = tostring(math.floor(math.max(health, maxHealth))) .. "/" .. tostring(math.floor(maxHealth))
        return true
    end

    local function isCachedForCharacter(char)
        local first = S.unshootableOriginal and S.unshootableOriginal[1]
        if not first or not first.part or not char then
            return false
        end

        local ok, result = pcall(function()
            return first.part:IsDescendantOf(char)
        end)
        return ok and result == true
    end

    local function cacheUnshootableParts(char, special)
        S.unshootableOriginal = {}
        if not char or not special then
            return
        end

        for _, part in ipairs(special:GetChildren()) do
            if part and (part.ClassName == "Part" or part.ClassName == "MeshPart") then
                local ok, size, position, canCollide = pcall(function()
                    return part.Size, part.Position, part.CanCollide
                end)
                if ok then
                    S.unshootableOriginal[#S.unshootableOriginal + 1] = {
                        part = part,
                        size = size,
                        position = position,
                        canCollide = canCollide
                    }
                end
            end
        end
    end

    local function restoreUnshootableParts()
        for _, saved in ipairs(S.unshootableOriginal or {}) do
            local part = saved.part
            if part then
                pcall(function()
                    part.Size = saved.size
                    part.Position = saved.position
                    part.CanCollide = saved.canCollide
                end)
            end
        end
        S.unshootableOriginal = {}
        S.unshootableStatus = "idle"
    end

    local function applyUnshootablePulse()
        local char = lp and lp.Character
        local effects = char and char:FindFirstChild("BodyEffects")
        local special = effects and effects:FindFirstChild("SpecialParts")
        if not char or not special then
            S.unshootableStatus = "hitboxes missing"
            return false
        end

        if not isCachedForCharacter(char) then
            cacheUnshootableParts(char, special)
        end

        local shrunk = 0
        local hitboxSize = math.max(0.01, math.min(0.5, tonumber(S.unshootableHitboxSize) or 0.01))
        for _, part in ipairs(special:GetChildren()) do
            if part and (part.ClassName == "Part" or part.ClassName == "MeshPart") then
                shrunk = shrunk + 1
                pcall(function()
                    part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                    part.CanCollide = false
                end)
            end
        end

        if effects then
            local maxArmor = game:GetService("ReplicatedStorage"):FindFirstChild("MaxArmor")
            setValueObject(effects, "Defense", 100)
            setValueObject(effects, "Armor", maxArmor and (tonumber(maxArmor.Value) or 200) or 200)
            setValueObject(effects, "FireArmor", 100)
            setValueObject(effects, "K.O", false)
            setValueObject(effects, "KO", false)
            setValueObject(effects, "Dead", false)
        end

        if S.invincible then
            applyInvinciblePulse()
        end

        S.unshootableStatus = shrunk > 0 and ("shrunk " .. tostring(shrunk) .. " hitboxes") or "no hitboxes"
        return shrunk > 0
    end

    local function getArmorState()
        local char = lp and lp.Character
        local effects = char and char:FindFirstChild("BodyEffects")
        local armor = effects and effects:FindFirstChild("Armor")
        local maxArmor = game:GetService("ReplicatedStorage"):FindFirstChild("MaxArmor")

        if armor and maxArmor then
            return tonumber(armor.Value) or 0, tonumber(maxArmor.Value) or 0
        end

        return nil, nil
    end

    local ARMOR_FALLBACK_POSITIONS = {
        Vector3.new(528, 50, -637)
    }

    local function useNearestPosition(root, currentItem, currentPosition, candidateItem, candidatePosition)
        if not root or not candidatePosition then
            return currentItem, currentPosition
        end

        if not currentPosition or (candidatePosition - root.Position).Magnitude < (currentPosition - root.Position).Magnitude then
            return candidateItem, candidatePosition
        end

        return currentItem, currentPosition
    end

    local function findNearestArmorStand(root)
        if not root then
            return nil
        end

        local bestItem, bestPosition
        local ignored = workspace and workspace:FindFirstChild("Ignored")
        local shop = ignored and ignored:FindFirstChild("Shop")
        if shop then
            for _, item in ipairs(shop:GetChildren()) do
                if item.Name and string.find(string.lower(item.Name), "full armor", 1, true) then
                    local head = item:FindFirstChild("Head")
                    local price = item:FindFirstChild("Price")
                    local target = head or price
                    if target then
                        bestItem, bestPosition = useNearestPosition(root, bestItem, bestPosition, item, target.Position)
                    end
                end
            end
        end

        for _, position in ipairs(ARMOR_FALLBACK_POSITIONS) do
            bestItem, bestPosition = useNearestPosition(root, bestItem, bestPosition, "known armor stand", position)
        end

        return bestItem, bestPosition
    end

    local function buyArmor(force)
        if S.armorBuying or (not force and not S.autoArmor) or not S.running then
            return false
        end

        local armor, maxArmor = getArmorState()
        if not armor or not maxArmor or maxArmor <= 0 then
            S.armorStatus = "armor stat missing"
            return false
        end

        if not force and armor >= maxArmor * S.armorTriggerRatio then
            S.armorStatus = tostring(math.floor(armor)) .. "/" .. tostring(math.floor(maxArmor))
            return false
        end

        if not force and tick() - (S.lastArmorBuyAt or 0) < S.armorCooldown then
            return false
        end

        local root = getRoot()
        if not root then
            S.armorStatus = "root missing"
            return false
        end

        local item, armorPosition = findNearestArmorStand(root)
        if not item or not armorPosition then
            S.armorStatus = "armor stand missing"
            return false
        end

        S.armorBuying = true
        S.lastArmorBuyAt = tick()
        S.armorStatus = "click armor now"

        local beforeArmor = armor
        local oldCFrame = root.CFrame
        local oldVelocity = root.AssemblyLinearVelocity
        local oldCanCollide = root.CanCollide
        local camera = workspace.CurrentCamera
        local oldCamera = camera and camera.CFrame

        local offset = root.Position - armorPosition
        local flat = Vector3.new(offset.X, 0, offset.Z)
        if flat.Magnitude < 1 then
            flat = Vector3.new(0, 0, 1)
        end
        local side = flat.Unit * 5
        local standPos = Vector3.new(armorPosition.X + side.X, armorPosition.Y, armorPosition.Z + side.Z)

        pcall(function()
            local moved = pcall(function()
                root.CFrame = CFrame.lookAt(standPos, armorPosition)
            end)
            if not moved then
                root.Position = standPos
            end
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.CanCollide = true
            if camera then
                camera.CFrame = CFrame.lookAt(armorPosition + flat.Unit * 9 + Vector3.new(0, 2, 0), armorPosition)
            end
        end)

        local bought = false
        local deadline = tick() + 7
        while S.running and (force or S.autoArmor) and tick() < deadline do
            local afterArmor = getArmorState()
            if afterArmor and beforeArmor and afterArmor > beforeArmor then
                bought = true
                S.armorStatus = tostring(math.floor(afterArmor)) .. "/" .. tostring(math.floor(maxArmor))
                break
            end
            task.wait(0.15)
        end

        root = getRoot()
        if root then
            pcall(function()
                root.CFrame = oldCFrame
                root.AssemblyLinearVelocity = oldVelocity
                root.CanCollide = oldCanCollide
            end)
        end
        if camera and oldCamera then
            pcall(function()
                camera.CFrame = oldCamera
            end)
        end

        if not bought then
            S.armorStatus = "manual click timeout"
        end

        S.armorBuying = false
        return bought
    end
    local function getCharacterRoot(char)
        return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
    end

    local function getEvadeOffset(root)
        if not S.antiStick or not root or not Players then
            S.lastThreatName = "none"
            S.lastThreatDistance = 0
            return 0, 0, 0
        end

        local rootPos = root.Position
        local bestName = nil
        local bestDist = math.huge
        local bestDx = 0
        local bestDz = 0

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr and plr.UserId ~= lp.UserId then
                local targetRoot = getCharacterRoot(plr.Character)
                if targetRoot then
                    local pos = targetRoot.Position
                    local dx = rootPos.X - pos.X
                    local dz = rootPos.Z - pos.Z
                    local dist = math.sqrt(dx * dx + dz * dz)
                    if dist < bestDist then
                        bestName = plr.Name
                        bestDist = dist
                        bestDx = dx
                        bestDz = dz
                    end
                end
            end
        end

        if not bestName or bestDist > S.avoidRadius then
            S.lastThreatName = "none"
            S.lastThreatDistance = bestDist == math.huge and 0 or bestDist
            return 0, 0, 0
        end

        local mag = math.sqrt(bestDx * bestDx + bestDz * bestDz)
        if mag < 1 then
            local phase = tick() * 19.7
            bestDx = math.cos(phase)
            bestDz = math.sin(phase)
            mag = 1
        end

        local jitter = tick() * 11.3
        local sideX = math.cos(jitter) * S.avoidShift * 0.25
        local sideZ = math.sin(jitter) * S.avoidShift * 0.25

        S.lastThreatName = bestName
        S.lastThreatDistance = bestDist
        return (bestDx / mag) * S.avoidShift + sideX, (bestDz / mag) * S.avoidShift + sideZ, S.avoidHeightBoost
    end

    local function syncUi()
        if handles.height and handles.height.Set then pcall(function() handles.height:Set(S.height) end) end
        if handles.rate and handles.rate.Set then pcall(function() handles.rate:Set(S.rate) end) end
        if handles.velocity and handles.velocity.Set then pcall(function() handles.velocity:Set(S.velocity) end) end
        if handles.returnHeight and handles.returnHeight.Set then pcall(function() handles.returnHeight:Set(S.returnHeight) end) end
        if handles.roamRadius and handles.roamRadius.Set then pcall(function() handles.roamRadius:Set(S.roamRadius) end) end
        if handles.roamSpeed and handles.roamSpeed.Set then pcall(function() handles.roamSpeed:Set(S.roamSpeed) end) end
        if handles.aimHoldTime and handles.aimHoldTime.Set then pcall(function() handles.aimHoldTime:Set(S.aimHoldTime) end) end
        if handles.avoidRadius and handles.avoidRadius.Set then pcall(function() handles.avoidRadius:Set(S.avoidRadius) end) end
        if handles.avoidShift and handles.avoidShift.Set then pcall(function() handles.avoidShift:Set(S.avoidShift) end) end
        if handles.avoidHeightBoost and handles.avoidHeightBoost.Set then pcall(function() handles.avoidHeightBoost:Set(S.avoidHeightBoost) end) end
        if handles.armorCooldown and handles.armorCooldown.Set then pcall(function() handles.armorCooldown:Set(S.armorCooldown) end) end
        if handles.armorTriggerRatio and handles.armorTriggerRatio.Set then pcall(function() handles.armorTriggerRatio:Set(S.armorTriggerRatio) end) end
        if handles.invincibleHealRatio and handles.invincibleHealRatio.Set then pcall(function() handles.invincibleHealRatio:Set(S.invincibleHealRatio) end) end
        if handles.invincibleInterval and handles.invincibleInterval.Set then pcall(function() handles.invincibleInterval:Set(S.invincibleInterval) end) end
        if handles.unshootableHitboxSize and handles.unshootableHitboxSize.Set then pcall(function() handles.unshootableHitboxSize:Set(S.unshootableHitboxSize) end) end
        if handles.unshootableInterval and handles.unshootableInterval.Set then pcall(function() handles.unshootableInterval:Set(S.unshootableInterval) end) end

        if roamToggle and roamToggle.Set then pcall(function() roamToggle:Set(S.roam) end) end
        if overlayToggle and overlayToggle.Set then pcall(function() overlayToggle:Set(S.showOverlay) end) end
        if autoArmorToggle and autoArmorToggle.Set then pcall(function() autoArmorToggle:Set(S.autoArmor) end) end
        if invincibleToggle and invincibleToggle.Set then pcall(function() invincibleToggle:Set(S.invincible) end) end
        if unshootableToggle and unshootableToggle.Set then pcall(function() unshootableToggle:Set(S.unshootable) end) end
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
        S.invincible = false
        S.unshootable = false
        restoreUnshootableParts()
        if roamToggle and roamToggle.Set then pcall(function() roamToggle:Set(false) end) end
        if invincibleToggle and invincibleToggle.Set then pcall(function() invincibleToggle:Set(false) end) end
        if unshootableToggle and unshootableToggle.Set then pcall(function() unshootableToggle:Set(false) end) end

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
        ["Above map"] = { height = 100000, rate = 0.08, velocity = 1200, roam = false, roamRadius = 900, roamSpeed = 100000, aimStabilizer = true, aimHoldTime = 0.75, antiStick = true, avoidRadius = 180, avoidShift = 2500, avoidHeightBoost = 3500 },
        ["Wide roam"] = { height = 100000, rate = 0.08, velocity = 1350, roam = true, roamRadius = 1400, roamSpeed = 100000, aimStabilizer = true, aimHoldTime = 0.75, antiStick = true, avoidRadius = 220, avoidShift = 3500, avoidHeightBoost = 5000 },
        ["High sky"] = { height = 100000, rate = 0.06, velocity = 1800, roam = true, roamRadius = 1800, roamSpeed = 100000, aimStabilizer = true, aimHoldTime = 0.75, antiStick = true, avoidRadius = 260, avoidShift = 4500, avoidHeightBoost = 7500 },
        ["Fast circle"] = { height = 100000, rate = 0.05, velocity = 1600, roam = true, roamRadius = 800, roamSpeed = 100000, aimStabilizer = true, aimHoldTime = 0.75, antiStick = true, avoidRadius = 200, avoidShift = 3000, avoidHeightBoost = 4000 }
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
    function S.setAimStabilizer(on)
        S.aimStabilizer = on and true or false
        notifyUser("Better Void", S.aimStabilizer and "aim stabilizer enabled" or "aim stabilizer disabled", S.aimStabilizer and "success" or "warning")
    end
    function S.toggleAimStabilizer() S.setAimStabilizer(not S.aimStabilizer) end
    function S.setAntiStick(on)
        S.antiStick = on and true or false
        notifyUser("Better Void", S.antiStick and "anti stick enabled" or "anti stick disabled", S.antiStick and "success" or "warning")
    end
    function S.toggleAntiStick() S.setAntiStick(not S.antiStick) end
    function S.setAutoArmor(on)
        S.autoArmor = on and true or false
        S.armorStatus = S.autoArmor and "watching" or "idle"
        notifyUser("Armor assist", S.autoArmor and "enabled" or "disabled", S.autoArmor and "success" or "warning")
    end
    function S.toggleAutoArmor()
        S.setAutoArmor(not S.autoArmor)
        if autoArmorToggle and autoArmorToggle.Set then pcall(function() autoArmorToggle:Set(S.autoArmor) end) end
    end
    function S.setInvincible(on)
        S.invincible = on and true or false
        S.invincibleStatus = S.invincible and "guarding" or "idle"
        notifyUser("Invincible", S.invincible and "enabled" or "disabled", S.invincible and "success" or "warning")
    end
    function S.toggleInvincible()
        S.setInvincible(not S.invincible)
        if invincibleToggle and invincibleToggle.Set then pcall(function() invincibleToggle:Set(S.invincible) end) end
    end
    function S.setUnshootable(on)
        S.unshootable = on and true or false
        if S.unshootable then
            S.unshootableOriginal = {}
            S.unshootableStatus = "arming"
            applyUnshootablePulse()
        else
            restoreUnshootableParts()
        end
        notifyUser("Unshootable", S.unshootable and "enabled" or "disabled", S.unshootable and "success" or "warning")
    end
    function S.toggleUnshootable()
        S.setUnshootable(not S.unshootable)
        if unshootableToggle and unshootableToggle.Set then pcall(function() unshootableToggle:Set(S.unshootable) end) end
    end
    function S.buyArmor() return buyArmor(true) end
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
            bg.Size = Vector2.new(260, 126)
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
                        text.Text = "Better Void\nVoid: " .. (S.enabled and "ON" or "OFF") .. "  Roam: " .. (S.roam and "ON" or "OFF") .. "\nUnshootable: " .. (S.unshootable and "ON" or "OFF") .. "  Invincible: " .. (S.invincible and "ON" or "OFF") .. "\nAnti stick: " .. (S.antiStick and "ON" or "OFF") .. "  Threat: " .. tostring(S.lastThreatName) .. "\nXYZ: " .. x .. ", " .. y .. ", " .. z .. "\nMarker: " .. (S.hasReturnMarker and "saved" or "none")

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
        restoreUnshootableParts()
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

        handles.height = controls:Slider("Height", S.height, 1000, 100, 100000, " studs", function(v)
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
        handles.roamSpeed = controls:Slider("Roam speed", S.roamSpeed, 1000, 0.1, 100000, "", function(v)
            S.roamSpeed = math.max(0.1, math.min(100000, v))
        end)

        controls:Divider("Shooting support")
        controls:Toggle("Aim stabilizer", S.aimStabilizer, function(on)
            S.aimStabilizer = on and true or false
        end)
        handles.aimHoldTime = controls:Slider("Aim hold time", S.aimHoldTime, 0.05, 0.05, 3, "s", function(v)
            S.aimHoldTime = math.max(0.05, math.min(3, v))
        end)

        overlayToggle = controls:Toggle("Position overlay", S.showOverlay, function(on)
            S.showOverlay = on and true or false
        end)

        controls:Divider("Armor")
        autoArmorToggle = controls:Toggle("Auto armor assist", S.autoArmor, function(on)
            S.setAutoArmor(on)
        end)
        handles.armorCooldown = controls:Slider("Armor cooldown", S.armorCooldown, 1, 2, 60, "s", function(v)
            S.armorCooldown = math.floor(v)
        end)
        handles.armorTriggerRatio = controls:Slider("Buy below armor", S.armorTriggerRatio, 0.05, 0.1, 1, "", function(v)
            S.armorTriggerRatio = math.max(0.1, math.min(1, v))
        end)
        controls:Button("Armor assist now", function()
            task.spawn(function()
                local wasAuto = S.autoArmor
                S.autoArmor = true
                local ok = buyArmor(true)
                S.autoArmor = wasAuto
                notifyUser("Armor assist", ok and "armor bought" or tostring(S.armorStatus), ok and "success" or "warning")
            end)
        end)

        controls:Divider("Invincible")
        invincibleToggle = controls:Toggle("Invincible", S.invincible, function(on)
            S.setInvincible(on)
        end)
        if invincibleToggle and invincibleToggle.AddKeybind then
            invincibleToggle:AddKeybind("h", "Toggle")
        end
        handles.invincibleHealRatio = controls:Slider("Heal below health", S.invincibleHealRatio, 0.05, 0.1, 1, "", function(v)
            S.invincibleHealRatio = math.max(0.1, math.min(1, v))
        end)
        handles.invincibleInterval = controls:Slider("Guard tick delay", S.invincibleInterval, 0.01, 0.03, 0.5, "s", function(v)
            S.invincibleInterval = math.max(0.03, math.min(0.5, v))
        end)

        controls:Divider("Unshootable")
        unshootableToggle = controls:Toggle("Unshootable", S.unshootable, function(on)
            S.setUnshootable(on)
        end)
        if unshootableToggle and unshootableToggle.AddKeybind then
            unshootableToggle:AddKeybind("j", "Toggle")
        end
        handles.unshootableHitboxSize = controls:Slider("Hitbox size", S.unshootableHitboxSize, 0.01, 0.01, 0.5, "", function(v)
            S.unshootableHitboxSize = math.max(0.01, math.min(0.5, v))
        end)
        handles.unshootableInterval = controls:Slider("Hitbox tick delay", S.unshootableInterval, 0.05, 0.1, 2, "s", function(v)
            S.unshootableInterval = math.max(0.1, math.min(2, v))
        end)

        controls:Divider("Anti stick")
        controls:Toggle("Anti stick", S.antiStick, function(on)
            S.antiStick = on and true or false
        end)
        handles.avoidRadius = controls:Slider("Avoid radius", S.avoidRadius, 25, 25, 2000, " studs", function(v)
            S.avoidRadius = math.floor(v)
        end)
        handles.avoidShift = controls:Slider("Avoid shift", S.avoidShift, 100, 100, 10000, " studs", function(v)
            S.avoidShift = math.floor(v)
        end)
        handles.avoidHeightBoost = controls:Slider("Avoid height boost", S.avoidHeightBoost, 100, 0, 100000, " studs", function(v)
            S.avoidHeightBoost = math.floor(v)
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
        status:Label(function() return "Aim stabilizer: " .. (S.aimStabilizer and "ON" or "OFF") end)
        status:Label(function() return "Unshootable: " .. (S.unshootable and "ON" or "OFF") .. " / " .. tostring(S.unshootableStatus) end)
        status:Label(function() return "Invincible: " .. (S.invincible and "ON" or "OFF") .. " / " .. tostring(S.invincibleStatus) end)
        status:Label(function() return "Anti stick: " .. (S.antiStick and "ON" or "OFF") end)
        status:Label(function() return "Armor assist: " .. (S.autoArmor and "ON" or "OFF") end)
        status:Label(function()
            local armor, maxArmor = getArmorState()
            return "Armor: " .. (armor and (tostring(math.floor(armor)) .. "/" .. tostring(math.floor(maxArmor or 0))) or tostring(S.armorStatus))
        end)
        status:Label(function() return "Threat: " .. tostring(S.lastThreatName) .. " / " .. tostring(math.floor(S.lastThreatDistance or 0)) end)
        status:Label(function()
            local root = getRoot()
            return "Y position: " .. (root and tostring(math.floor(root.Position.Y)) or "none")
        end)
        status:Label(function() return "Marker: " .. (S.hasReturnMarker and "saved" or "none") end)
        status:Info("P menu, V void, J unshootable, H invincible, Y armor assist, R roam, T aim, G anti stick, B panic, M/N marker, X unload.")

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
            if S.enabled and not S.armorBuying then
                local root = getRoot()
                if root then
                    if not S.anchorX or not S.anchorY or not S.anchorZ then
                        S.anchorX = root.Position.X
                        S.anchorY = root.Position.Y
                        S.anchorZ = root.Position.Z
                    end

                    local aiming = S.aimStabilizer and ((ismouse1pressed and ismouse1pressed()) or (ismouse2pressed and ismouse2pressed()))
                    if aiming then
                        S.aimHoldUntil = tick() + S.aimHoldTime
                        if not S.aimLockX or not S.aimLockY or not S.aimLockZ then
                            S.aimLockX = root.Position.X
                            S.aimLockY = root.Position.Y
                            S.aimLockZ = root.Position.Z
                        end
                    elseif tick() >= S.aimHoldUntil then
                        S.aimLockX = nil
                        S.aimLockY = nil
                        S.aimLockZ = nil
                    end

                    local holdingAim = S.aimStabilizer and tick() < S.aimHoldUntil and S.aimLockX ~= nil and S.aimLockY ~= nil and S.aimLockZ ~= nil
                    local offsetX = 0
                    local offsetZ = 0
                    local evadeY = 0

                    if holdingAim then
                        S.lastThreatName = "aim hold"
                        S.lastThreatDistance = 0
                    else
                        if S.roam then
                            local phase = tick() * S.roamSpeed
                            offsetX = (math.cos(phase) * S.roamRadius) + (math.sin(phase * 1.7) * S.roamRadius * 0.35)
                            offsetZ = (math.sin(phase) * S.roamRadius) + (math.cos(phase * 1.3) * S.roamRadius * 0.35)
                        end

                        local evadeX, evadeZ, boostY = getEvadeOffset(root)
                        offsetX = offsetX + evadeX
                        offsetZ = offsetZ + evadeZ
                        evadeY = boostY
                    end

                    pcall(function()
                        local targetX = holdingAim and S.aimLockX or (S.anchorX + offsetX)
                        local targetY = holdingAim and S.aimLockY or (S.anchorY + S.height + evadeY)
                        local targetZ = holdingAim and S.aimLockZ or (S.anchorZ + offsetZ)
                        root.CFrame = CFrame.new(targetX, targetY, targetZ)
                        root.AssemblyLinearVelocity = holdingAim and Vector3.new(0, 0, 0) or Vector3.new(0, S.velocity, 0)
                        root.CanCollide = holdingAim or false
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
        while S.running do
            if S.autoArmor then
                buyArmor()
                task.wait(math.max(3, S.armorCooldown or 8))
            else
                task.wait(0.25)
            end
        end
    end)

    task.spawn(function()
        while S.running do
            if S.invincible then
                applyInvinciblePulse()
                task.wait(S.invincibleInterval)
            else
                task.wait(0.25)
            end
        end
    end)

    task.spawn(function()
        while S.running do
            if S.unshootable then
                applyUnshootablePulse()
                task.wait(S.unshootableInterval)
            else
                task.wait(0.25)
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
            if pressed(116) then S.toggleAimStabilizer() end
            if pressed(103) then S.toggleAntiStick() end
            if pressed(121) then S.toggleAutoArmor() end
            if pressed(104) then S.toggleInvincible() end
            if pressed(106) then S.toggleUnshootable() end
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
