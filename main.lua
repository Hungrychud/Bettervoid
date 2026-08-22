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
        "showOverlay",
        "autoArmor",
        "armorCooldown",
        "armorTriggerRatio",
        "killAllCooldown",
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
        showOverlay = true,
        autoArmor = false,
        armorBuying = false,
        armorCooldown = 8,
        armorTriggerRatio = 0.95,
        armorStatus = "idle",
        armorSafeMode = true,
        killAllCooldown = 1.5,
        killAllStatus = "idle",
        killInProgress = false,
        lastKillAllAt = 0,
        killTargetUserId = nil,
        killTargetName = "none",
        killTargetInput = "",
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
    local handles = {}
    local overlay = { items = {} }
    local syncingToggle = false
    local scrollConnection = nil
    local hotkeyConnection = nil
    local peopleFinderButtons = {}
    local openPeopleFinder
    local destroyPeopleFinder

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
        S.armorCooldown = math.max(2, math.min(60, tonumber(S.armorCooldown) or 8))
        S.armorTriggerRatio = math.max(0.1, math.min(1, tonumber(S.armorTriggerRatio) or 0.95))
        S.killAllCooldown = math.max(0.5, math.min(10, tonumber(S.killAllCooldown) or 1.5))
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

    local KILL_ALL_LOADOUT = {
        "[Double-Barrel SG]",
        "[Revolver]",
        "[TacticalShotgun]",
        "None"
    }

    local KILL_ALL_GUNS = {
        ["[Double-Barrel SG]"] = true,
        ["[Revolver]"] = true,
        ["[TacticalShotgun]"] = true
    }

    local KILL_PELLETS_PER_TARGET = 6
    local KILL_SHOT_BURST = 2
    local KILL_SHOT_DELAY = 0.08
    local KILL_EQUIP_DELAY = 0.08
    local KEY_KILL_ALL = 107
    local KEY_KILL_SELECTED = 108
    local SCROLL_TARGET_DELAY = 0.12

    local killAllRemote = nil
    local loadoutRemote = nil
    local refillActive = false
    local lastTargetScrollAt = 0

    local function isRemoteEvent(object)
        return object and object.ClassName == "RemoteEvent"
    end

    local function instanceKey(object)
        if not object then
            return "nil"
        end

        local ok, address = pcall(function()
            return object.Address
        end)
        if ok and address then
            return tostring(address)
        end

        local okName, fullName = pcall(function()
            return object:GetFullName()
        end)
        return okName and fullName or tostring(object)
    end

    local function findKillRemote()
        local storage = game:GetService("ReplicatedStorage")
        local gameRemotes = storage and storage:FindFirstChild("GameRemotes")
        local mainRemotes = storage and storage:FindFirstChild("MainRemotes")
        local exact = (gameRemotes and gameRemotes:FindFirstChild("MainGameEvent")) or (mainRemotes and mainRemotes:FindFirstChild("MainRemoteEvent"))

        if isRemoteEvent(exact) then
            return exact
        end

        local fallback = nil
        local ok, descendants = pcall(function()
            return storage:GetDescendants()
        end)
        if not ok or not descendants then
            return nil
        end

        for _, object in ipairs(descendants) do
            if isRemoteEvent(object) then
                fallback = fallback or object
                local name = string.lower(object.Name or "")
                if string.find(name, "main", 1, true) or string.find(name, "game", 1, true) or string.find(name, "settings", 1, true) then
                    return object
                end
            end
        end

        return fallback
    end

    local function findLoadoutRemote()
        local storage = game:GetService("ReplicatedStorage")
        local exact = storage and storage:FindFirstChild("Loadout")
        if isRemoteEvent(exact) then
            return exact
        end

        local remotes = storage and storage:FindFirstChild("Remotes")
        exact = remotes and remotes:FindFirstChild("Loadout")
        if isRemoteEvent(exact) then
            return exact
        end

        local ok, descendants = pcall(function()
            return storage:GetDescendants()
        end)
        if not ok or not descendants then
            return nil
        end

        for _, object in ipairs(descendants) do
            if isRemoteEvent(object) and string.find(string.lower(object.Name or ""), "loadout", 1, true) then
                return object
            end
        end

        return nil
    end

    local function resolveKillAllRemotes()
        if not isRemoteEvent(killAllRemote) then
            killAllRemote = findKillRemote()
        end
        if not isRemoteEvent(loadoutRemote) then
            loadoutRemote = findLoadoutRemote()
        end
        return killAllRemote, loadoutRemote
    end

    local function isFriendlyWhitelisted(player)
        local environment = (getgenv and getgenv()) or _G
        local loadedLibrary = environment and (environment.Library or _G.Library)

        if loadedLibrary == nil or type(loadedLibrary.get_priority) ~= "function" then
            return false
        end

        local success, priority = pcall(function()
            return loadedLibrary.get_priority(player)
        end)

        return success and tostring(priority or ""):lower() == "friendly"
    end

    local function getGunContainers()
        return lp and lp:FindFirstChild("Backpack"), lp and lp.Character
    end

    local function getTacticalShotgun(character, backpack)
        return (backpack and backpack:FindFirstChild("[TacticalShotgun]")) or (character and character:FindFirstChild("[TacticalShotgun]"))
    end

    local function requestLoadout()
        local _, remote = resolveKillAllRemotes()
        if not remote then
            S.killAllStatus = "loadout remote missing"
            return false
        end

        local ok = pcall(function()
            remote:FireServer(KILL_ALL_LOADOUT)
        end)
        S.killAllStatus = ok and "loadout requested" or "loadout failed"
        return ok
    end

    local function requestAmmoRefill(tool, ammo)
        local _, remote = resolveKillAllRemotes()
        if not remote or refillActive or not tool or not ammo then
            return false
        end

        local backpack, character = getGunContainers()
        if not backpack then
            S.killAllStatus = "backpack missing"
            return false
        end

        pcall(function()
            ammo:SetAttribute("ZeeKillRefillRequested", true)
        end)

        refillActive = true
        local requestedName = tool.Name
        local oldTools = {}
        local equippedTools = {}

        for _, container in ipairs({ backpack, character }) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    if item.ClassName == "Tool" and KILL_ALL_GUNS[item.Name] then
                        oldTools[instanceKey(item)] = item
                        if item.Parent == character then
                            equippedTools[item.Name] = true
                        end
                    end
                end
            end
        end

        local ok = pcall(function()
            remote:FireServer(KILL_ALL_LOADOUT)
        end)
        if not ok then
            refillActive = false
            S.killAllStatus = "refill failed"
            return false
        end

        local newestTools = {}
        local deadline = tick() + 2
        while S.running and tick() < deadline do
            for _, container in ipairs({ backpack, character }) do
                if container then
                    for _, item in ipairs(container:GetChildren()) do
                        if item.ClassName == "Tool" and KILL_ALL_GUNS[item.Name] and not oldTools[instanceKey(item)] then
                            newestTools[item.Name] = item
                        end
                    end
                end
            end

            if next(newestTools) then
                break
            end

            task.wait(0.05)
        end

        local humanoid = getHumanoid()
        for name, item in pairs(newestTools) do
            if equippedTools[name] and character and item.Parent then
                local equipped = false
                if humanoid then
                    equipped = pcall(function()
                        humanoid:EquipTool(item)
                    end)
                end
                if not equipped then
                    pcall(function()
                        item.Parent = character
                    end)
                end
            end
        end

        if not newestTools[requestedName] then
            pcall(function()
                ammo:SetAttribute("ZeeKillRefillRequested", nil)
            end)
        end

        refillActive = false
        S.killAllStatus = next(newestTools) and "ammo refilled" or "refill timeout"
        return newestTools[requestedName] or false
    end

    local function usableAmmo(tool, ammo)
        if not ammo then
            return false
        end

        local value = tonumber(ammo.Value) or 0
        if value <= 0 then
            return requestAmmoRefill(tool, ammo) ~= false
        end

        return true
    end

    local function samePlayer(a, b)
        return a and b and tonumber(a.UserId) and tonumber(b.UserId) and tonumber(a.UserId) == tonumber(b.UserId)
    end

    local function getKillTarget(player)
        if not player or samePlayer(player, lp) or isFriendlyWhitelisted(player) then
            return nil, false
        end

        local character = player.Character
        local humanoid = character and (character:FindFirstChild("Humanoid") or character:FindFirstChildOfClass("Humanoid"))
        local bodyEffects = character and character:FindFirstChild("BodyEffects")
        local knocked = bodyEffects and bodyEffects:FindFirstChild("K.O")
        local valid = humanoid and tonumber(humanoid.Health) and humanoid.Health > 0 and not (knocked and knocked.Value)

        return character, valid == true
    end

    local function getKillTargetName(player)
        return player and tostring(player.Name or ("#" .. tostring(player.UserId))) or "none"
    end

    local function setKillTargetInputValue(value)
        S.killTargetInput = tostring(value or "")
        if handles.killTargetName then
            pcall(function()
                handles.killTargetName.Value = S.killTargetInput
            end)
        end
    end

    local function setKillTarget(player)
        if player and not samePlayer(player, lp) then
            S.killTargetUserId = tonumber(player.UserId)
            S.killTargetName = getKillTargetName(player)
            setKillTargetInputValue(S.killTargetName)
            S.killAllStatus = "target " .. tostring(S.killTargetName)
            return true
        end

        S.killTargetUserId = nil
        S.killTargetName = "none"
        setKillTargetInputValue("")
        return false
    end

    local function clearKillTarget()
        S.killTargetUserId = nil
        S.killTargetName = "none"
        setKillTargetInputValue("")
        S.killAllStatus = "target cleared"
        return true
    end

    local function findKillPlayerByName(query)
        if not Players then
            return nil
        end

        query = string.lower(tostring(query or ""):match("^%s*(.-)%s*$"))
        if query == "" or query == "none" then
            return nil
        end

        local partial
        for _, player in ipairs(Players:GetPlayers()) do
            if not samePlayer(player, lp) then
                local name = string.lower(tostring(player.Name or ""))
                if name == query then
                    return player
                end
                if not partial and string.find(name, query, 1, true) then
                    partial = player
                end
            end
        end

        return partial
    end

    local function getSelectedKillPlayer()
        if not Players then
            return nil
        end

        local selectedUserId = tonumber(S.killTargetUserId)
        local selectedName = tostring((S.killTargetInput and S.killTargetInput ~= "" and S.killTargetInput) or S.killTargetName or "")
        for _, player in ipairs(Players:GetPlayers()) do
            if not samePlayer(player, lp) then
                if selectedUserId and tonumber(player.UserId) == selectedUserId then
                    return player
                end
                if selectedName ~= "" and selectedName ~= "none" and string.lower(tostring(player.Name or "")) == string.lower(selectedName) then
                    return player
                end
            end
        end

        return findKillPlayerByName(selectedName)
    end

    local function getKillCandidates()
        if not Players then
            return nil
        end

        local candidates = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if not samePlayer(player, lp) and not isFriendlyWhitelisted(player) then
                candidates[#candidates + 1] = player
            end
        end

        return candidates
    end

    local function selectKillTargetStep(step)
        local candidates = getKillCandidates()
        if not candidates then
            S.killAllStatus = "players missing"
            return false
        end

        if #candidates == 0 then
            clearKillTarget()
            S.killAllStatus = "no targets"
            return false
        end

        local selectedUserId = tonumber(S.killTargetUserId)
        local index = 1
        if selectedUserId then
            for i, player in ipairs(candidates) do
                if tonumber(player.UserId) == selectedUserId then
                    index = i + (tonumber(step) or 1)
                    break
                end
            end
        end

        while index > #candidates do
            index = index - #candidates
        end
        while index < 1 do
            index = index + #candidates
        end

        return setKillTarget(candidates[index])
    end

    local function selectNextKillTarget()
        return selectKillTargetStep(1)
    end

    local function selectPreviousKillTarget()
        return selectKillTargetStep(-1)
    end

    local function scrollKillTarget(direction)
        if tick() - lastTargetScrollAt < SCROLL_TARGET_DELAY then
            return false
        end

        lastTargetScrollAt = tick()
        if tonumber(direction) and tonumber(direction) < 0 then
            return selectPreviousKillTarget()
        end

        return selectNextKillTarget()
    end

    local function getEquippedTool(character)
        if not character then
            return nil
        end

        for _, item in ipairs(character:GetChildren()) do
            if item.ClassName == "Tool" then
                return item
            end
        end

        return nil
    end

    local function equipKillTool(tool, character, humanoid)
        if not tool or not character then
            return false
        end
        if tool.Parent == character then
            return true
        end

        local equipped = false
        if humanoid then
            equipped = pcall(function()
                humanoid:EquipTool(tool)
            end)
        end
        if not equipped then
            equipped = pcall(function()
                tool.Parent = character
            end)
        end

        if equipped then
            task.wait(KILL_EQUIP_DELAY)
        end

        return tool.Parent == character
    end

    local function restoreKillTool(tool, previousTool, character, backpack, wasEquipped)
        if wasEquipped then
            return
        end

        local humanoid = getHumanoid()
        if previousTool and previousTool.Parent == character then
            return
        end
        if previousTool and previousTool.Parent == backpack and humanoid then
            local restored = pcall(function()
                humanoid:EquipTool(previousTool)
            end)
            if restored then
                task.wait(0.05)
                return
            end
        end

        if humanoid then
            pcall(function()
                humanoid:UnequipTools()
            end)
            task.wait(0.03)
        end

        if tool and backpack and tool.Parent == character then
            pcall(function()
                tool.Parent = backpack
            end)
        end
    end

    local function buildKillPellets(targetPlayers)
        local pellets = {}
        local targetCount = 0

        for _, player in ipairs(targetPlayers or {}) do
            local targetCharacter, valid = getKillTarget(player)
            local head = targetCharacter and targetCharacter:FindFirstChild("Head")
            if valid and head then
                targetCount = targetCount + 1
                local position = head.Position
                for _ = 1, KILL_PELLETS_PER_TARGET do
                    pellets[#pellets + 1] = {
                        AimPosition = position,
                        Result1 = position,
                        Result2 = head,
                        Result3 = Vector3.yAxis
                    }
                end
            end
        end

        return pellets, targetCount
    end

    local function runKillPlayers(targetPlayers, label)
        local now = tick()
        if now - (S.lastKillAllAt or 0) < S.killAllCooldown then
            S.killAllStatus = "cooldown"
            return false
        end

        S.lastKillAllAt = now
        local remote = resolveKillAllRemotes()
        local backpack, character = getGunContainers()

        if not remote then
            S.killAllStatus = "kill remote missing"
            return false
        end

        if not character or not backpack then
            S.killAllStatus = "character missing"
            return false
        end

        local tool = getTacticalShotgun(character, backpack)
        if not tool then
            requestLoadout()
            S.killAllStatus = "tactical requested"
            return false
        end

        local handle = tool:FindFirstChild("Handle")
        local ammo = tool:FindFirstChild("Ammo")
        if ammo and (tonumber(ammo.Value) or 0) <= 0 then
            local refilledTool = requestAmmoRefill(tool, ammo)
            if refilledTool then
                tool = refilledTool
                handle = tool:FindFirstChild("Handle")
                ammo = tool:FindFirstChild("Ammo")
            end
        end

        if not handle or not usableAmmo(tool, ammo) then
            S.killAllStatus = not handle and "handle missing" or "ammo refill requested"
            return false
        end

        local pellets, targetCount = buildKillPellets(targetPlayers)

        if #pellets == 0 then
            S.killAllStatus = label and (label .. ": no targets") or "no targets"
            return false
        end

        local rangeObject = tool:FindFirstChild("Range")
        local damageObject = tool:FindFirstChild("Damage")
        local range = rangeObject and (tonumber(rangeObject.Value) or 200) or 200
        local damage = damageObject and (tonumber(damageObject.Value) or 50) or 50
        local wasEquipped = tool.Parent == character
        local previousTool = wasEquipped and nil or getEquippedTool(character)
        local humanoid = getHumanoid()

        if not equipKillTool(tool, character, humanoid) then
            S.killAllStatus = "equip failed"
            return false
        end

        handle = tool:FindFirstChild("Handle")
        if not handle then
            restoreKillTool(tool, previousTool, character, backpack, wasEquipped)
            S.killAllStatus = "handle missing"
            return false
        end

        local fired = 0
        for shot = 1, KILL_SHOT_BURST do
            handle = tool:FindFirstChild("Handle")
            if not handle then
                break
            end
            local okFire = pcall(function()
                remote:FireServer("ShootGun", handle, handle.Position, pellets, nil, nil, nil, range, damage)
            end)
            if okFire then
                fired = fired + 1
            end
            if shot < KILL_SHOT_BURST then
                task.wait(KILL_SHOT_DELAY)
            end
        end

        restoreKillTool(tool, previousTool, character, backpack, wasEquipped)

        S.killAllStatus = (label and (label .. ": ") or "") .. "fired " .. tostring(fired) .. "x / " .. tostring(targetCount) .. " target(s)"
        return fired > 0
    end

    local function killPlayers(targetPlayers, label)
        if S.killInProgress then
            S.killAllStatus = "already firing"
            return false
        end

        S.killInProgress = true
        local ok, result = pcall(function()
            return runKillPlayers(targetPlayers, label)
        end)
        S.killInProgress = false

        if not ok then
            S.killAllStatus = "kill error"
            return false
        end

        return result
    end

    local function killAll()
        return killPlayers(Players and Players:GetPlayers() or {}, "all")
    end

    local function killSelectedTarget()
        local player = getSelectedKillPlayer()
        if not player then
            S.killAllStatus = "target missing"
            return false
        end

        return killPlayers({ player }, getKillTargetName(player))
    end

    local function killNamedTarget(name)
        local player = type(name) == "string" and findKillPlayerByName(name) or name
        if not player then
            S.killAllStatus = "target missing"
            return false
        end

        setKillTarget(player)
        return killPlayers({ player }, getKillTargetName(player))
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
    local function syncUi()
        if handles.height and handles.height.Set then pcall(function() handles.height:Set(S.height) end) end
        if handles.rate and handles.rate.Set then pcall(function() handles.rate:Set(S.rate) end) end
        if handles.velocity and handles.velocity.Set then pcall(function() handles.velocity:Set(S.velocity) end) end
        if handles.returnHeight and handles.returnHeight.Set then pcall(function() handles.returnHeight:Set(S.returnHeight) end) end
        if handles.roamRadius and handles.roamRadius.Set then pcall(function() handles.roamRadius:Set(S.roamRadius) end) end
        if handles.roamSpeed and handles.roamSpeed.Set then pcall(function() handles.roamSpeed:Set(S.roamSpeed) end) end
        if handles.aimHoldTime and handles.aimHoldTime.Set then pcall(function() handles.aimHoldTime:Set(S.aimHoldTime) end) end
        if handles.armorCooldown and handles.armorCooldown.Set then pcall(function() handles.armorCooldown:Set(S.armorCooldown) end) end
        if handles.armorTriggerRatio and handles.armorTriggerRatio.Set then pcall(function() handles.armorTriggerRatio:Set(S.armorTriggerRatio) end) end
        if handles.killAllCooldown and handles.killAllCooldown.Set then pcall(function() handles.killAllCooldown:Set(S.killAllCooldown) end) end
        if handles.killTargetName then pcall(function() handles.killTargetName.Value = S.killTargetInput or "" end) end

        if roamToggle and roamToggle.Set then pcall(function() roamToggle:Set(S.roam) end) end
        if overlayToggle and overlayToggle.Set then pcall(function() overlayToggle:Set(S.showOverlay) end) end
        if autoArmorToggle and autoArmorToggle.Set then pcall(function() autoArmorToggle:Set(S.autoArmor) end) end
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
        ["Above map"] = { height = 100000, rate = 0.08, velocity = 1200, roam = false, roamRadius = 900, roamSpeed = 100000, aimStabilizer = true, aimHoldTime = 0.75 },
        ["Wide roam"] = { height = 100000, rate = 0.08, velocity = 1350, roam = true, roamRadius = 1400, roamSpeed = 100000, aimStabilizer = true, aimHoldTime = 0.75 },
        ["High sky"] = { height = 100000, rate = 0.06, velocity = 1800, roam = true, roamRadius = 1800, roamSpeed = 100000, aimStabilizer = true, aimHoldTime = 0.75 },
        ["Fast circle"] = { height = 100000, rate = 0.05, velocity = 1600, roam = true, roamRadius = 800, roamSpeed = 100000, aimStabilizer = true, aimHoldTime = 0.75 }
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
    function S.setAutoArmor(on)
        S.autoArmor = on and true or false
        S.armorStatus = S.autoArmor and "watching" or "idle"
        notifyUser("Armor assist", S.autoArmor and "enabled" or "disabled", S.autoArmor and "success" or "warning")
    end
    function S.toggleAutoArmor()
        S.setAutoArmor(not S.autoArmor)
        if autoArmorToggle and autoArmorToggle.Set then pcall(function() autoArmorToggle:Set(S.autoArmor) end) end
    end
    function S.killAll() return killAll() end
    function S.nextKillTarget() return selectNextKillTarget() end
    function S.previousKillTarget() return selectPreviousKillTarget() end
    function S.openPeopleFinder() return openPeopleFinder() end
    function S.clearKillTarget() return clearKillTarget() end
    function S.setKillTarget(target)
        if type(target) == "string" then
            return setKillTarget(findKillPlayerByName(target))
        end
        return setKillTarget(target)
    end
    function S.killSelectedTarget() return killSelectedTarget() end
    function S.killTarget(target) return killNamedTarget(target) end
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
                        text.Text = "Better Void\nVoid: " .. (S.enabled and "ON" or "OFF") .. "  Roam: " .. (S.roam and "ON" or "OFF") .. "\nKill: " .. tostring(S.killAllStatus) .. "\nXYZ: " .. x .. ", " .. y .. ", " .. z .. "\nMarker: " .. (S.hasReturnMarker and "saved" or "none")

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

        if scrollConnection then
            pcall(function()
                scrollConnection:Disconnect()
            end)
            scrollConnection = nil
        end
        if hotkeyConnection then
            pcall(function()
                hotkeyConnection:Disconnect()
            end)
            hotkeyConnection = nil
        end
        destroyPeopleFinder()

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

    local function setupKillTargetScroll()
        if scrollConnection then
            return true
        end

        local okService, userInput = pcall(function()
            return game:GetService("UserInputService")
        end)
        if not okService or not userInput then
            return false
        end

        local inputChanged
        local okSignal = pcall(function()
            inputChanged = userInput.InputChanged
        end)
        if not okSignal or not inputChanged or not inputChanged.Connect then
            return false
        end

        local okConnect = pcall(function()
            scrollConnection = inputChanged:Connect(function(input)
                if not S.running then
                    return
                end

                local isWheel = false
                pcall(function()
                    isWheel = Enum and Enum.UserInputType and input.UserInputType == Enum.UserInputType.MouseWheel
                end)
                if not isWheel then
                    return
                end

                local wheel = 0
                pcall(function()
                    wheel = input.Position.Z
                end)
                if wheel == 0 then
                    return
                end

                local okSelect = scrollKillTarget(wheel)
                if okSelect then
                    notifyUser("Kill target", tostring(S.killTargetName), "info")
                end
            end)
        end)

        if not okConnect then
            scrollConnection = nil
            return false
        end

        return true
    end

    local function keyMatches(input, keyName, fallbackCode)
        if not input then
            return false
        end

        local keyCode = nil
        pcall(function()
            keyCode = input.KeyCode
        end)
        if not keyCode then
            return false
        end

        local enumKey = nil
        pcall(function()
            enumKey = Enum and Enum.KeyCode and Enum.KeyCode[keyName]
        end)
        if enumKey and keyCode == enumKey then
            return true
        end

        local numeric = tonumber(keyCode)
        if numeric and numeric == fallbackCode then
            return true
        end

        local value = nil
        pcall(function()
            value = keyCode.Value
        end)
        if tonumber(value) == fallbackCode then
            return true
        end

        local text = string.lower(tostring(keyCode))
        local wanted = string.lower(tostring(keyName))
        return text == wanted or string.sub(text, -#wanted) == wanted
    end

    local function textBoxFocused(userInput)
        local focused = nil
        pcall(function()
            if userInput and userInput.GetFocusedTextBox then
                focused = userInput:GetFocusedTextBox()
            end
        end)
        return focused ~= nil
    end

    local function setupHotkeys()
        if hotkeyConnection then
            return true
        end

        local okService, userInput = pcall(function()
            return game:GetService("UserInputService")
        end)
        if not okService or not userInput then
            return false
        end

        local inputBegan
        local okSignal = pcall(function()
            inputBegan = userInput.InputBegan
        end)
        if not okSignal or not inputBegan or not inputBegan.Connect then
            return false
        end

        local okConnect = pcall(function()
            hotkeyConnection = inputBegan:Connect(function(input)
                if not S.running or textBoxFocused(userInput) then
                    return
                end

                if keyMatches(input, "V", 118) then
                    setEnabled(not S.enabled, true)
                elseif keyMatches(input, "K", KEY_KILL_ALL) then
                    task.spawn(function() S.killAll() end)
                elseif keyMatches(input, "L", KEY_KILL_SELECTED) then
                    task.spawn(function() S.killSelectedTarget() end)
                end
            end)
        end)

        if not okConnect then
            hotkeyConnection = nil
            return false
        end

        return true
    end

    function destroyPeopleFinder()
        for _, button in ipairs(peopleFinderButtons) do
            pcall(function()
                if button.Destroy then
                    button:Destroy()
                elseif button.Remove then
                    button:Remove()
                elseif button.Unload then
                    button:Unload()
                end
            end)
        end
        peopleFinderButtons = {}
    end

    function openPeopleFinder()
        if not handles.peopleFinderSection or not handles.peopleFinderSection.Button then
            S.killAllStatus = "finder section missing"
            notifyUser("Find people", "open the Instant Kill tab first", "warning")
            return false
        end

        if not Players then
            S.killAllStatus = "players missing"
            notifyUser("Find people", "players missing", "warning")
            return false
        end

        destroyPeopleFinder()

        local query = string.lower(tostring(S.killTargetInput or ""):match("^%s*(.-)%s*$"))
        local shown = 0
        for _, player in ipairs(Players:GetPlayers()) do
            if shown >= 32 then
                break
            end
            if not samePlayer(player, lp) then
                local displayName = ""
                pcall(function()
                    displayName = tostring(player.DisplayName or "")
                end)
                local name = tostring(player.Name or "")
                local label = name
                if displayName ~= "" and displayName ~= name then
                    label = name .. " (" .. displayName .. ")"
                end

                local haystack = string.lower(label)
                if query == "" or string.find(haystack, query, 1, true) then
                    local targetPlayer = player
                    local okButton, button = pcall(function()
                        return handles.peopleFinderSection:Button(label, function()
                            setKillTarget(targetPlayer)
                            notifyUser("Kill target", tostring(S.killTargetName), "success")
                        end)
                    end)
                    if okButton and button then
                        peopleFinderButtons[#peopleFinderButtons + 1] = button
                    end
                    shown = shown + 1
                end
            end
        end

        S.killAllStatus = shown > 0 and ("finder listed " .. tostring(shown)) or "finder no matches"
        notifyUser("Find people", tostring(S.killAllStatus), shown > 0 and "success" or "warning")
        return shown > 0
    end

    local function createUi()
        Lib = loadInsUi()
        if not Lib or not Lib.CreateWindow then
            notifyUser("Better Void", "loaded without UI. V toggles void.", "warning")
            return false
        end

        win = Lib:CreateWindow({
            title = "Better Void",
            subtitle = "Void + instant kill",
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
        local killTab = win:Tab("Instant Kill", "target")
        local controls = tab:Section("Controls", "Left", "void movement")
        local utilities = tab:Section("Utilities", "Left", "presets, marker, config")
        local status = tab:Section("Status", "Right", "live values")
        local killControls = killTab:Section("Controls", "Left", "target controls")
        local killStatus = killTab:Section("Status", "Right", "instant kill status")
        handles.peopleFinderSection = killTab:Section("People Finder", "Right", "player list")

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
        killControls:Divider("Target")
        handles.killTargetName = killControls:Textbox("Target name", S.killTargetInput or "", function(value)
            local text = tostring(value or ""):match("^%s*(.-)%s*$")
            setKillTargetInputValue(text)
            if text == "" then
                S.killTargetUserId = nil
                S.killTargetName = "none"
                S.killAllStatus = "target cleared"
                return
            end

            local player = findKillPlayerByName(text)
            if player then
                S.killTargetUserId = tonumber(player.UserId)
                S.killTargetName = getKillTargetName(player)
                S.killAllStatus = "target " .. tostring(S.killTargetName)
            else
                S.killTargetUserId = nil
                S.killTargetName = text
                S.killAllStatus = "target typed"
            end
        end, "Exact or partial player name")
        killControls:Button("Find people", function()
            openPeopleFinder()
        end)
        handles.peopleFinderSection:Button("Refresh people list", function()
            openPeopleFinder()
        end)
        handles.peopleFinderSection:Info("Type in Target name to filter, then refresh. Click a player name to select them.")
        killControls:Button("Kill selected target [L]", function()
            task.spawn(function()
                local ok = killSelectedTarget()
                notifyUser("Kill target", tostring(S.killAllStatus), ok and "success" or "warning")
            end)
        end):SetRisk()
        killControls:Button("Previous kill target", function()
            local ok = selectPreviousKillTarget()
            notifyUser("Kill target", ok and tostring(S.killTargetName) or tostring(S.killAllStatus), ok and "success" or "warning")
        end)
        killControls:Button("Next kill target", function()
            local ok = selectNextKillTarget()
            notifyUser("Kill target", ok and tostring(S.killTargetName) or tostring(S.killAllStatus), ok and "success" or "warning")
        end)
        killControls:Button("Clear kill target", function()
            clearKillTarget()
            notifyUser("Kill target", "cleared", "info")
        end)

        killControls:Divider("All players")
        handles.killAllCooldown = killControls:Slider("Kill cooldown", S.killAllCooldown, 0.5, 0.5, 10, "s", function(v)
            S.killAllCooldown = math.max(0.5, math.min(10, v))
        end)
        killControls:Button("Kill all now [K]", function()
            task.spawn(function()
                local ok = killAll()
                notifyUser("Kill all", tostring(S.killAllStatus), ok and "success" or "warning")
            end)
        end):SetRisk()
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
        status:Label(function() return "Kill all: " .. tostring(S.killAllStatus) end)
        status:Label(function() return "Kill target: " .. tostring(S.killTargetName or "none") end)
        status:Label(function() return "Armor assist: " .. (S.autoArmor and "ON" or "OFF") end)
        status:Label(function()
            local armor, maxArmor = getArmorState()
            return "Armor: " .. (armor and (tostring(math.floor(armor)) .. "/" .. tostring(math.floor(maxArmor or 0))) or tostring(S.armorStatus))
        end)
        status:Label(function()
            local root = getRoot()
            return "Y position: " .. (root and tostring(math.floor(root.Position.Y)) or "none")
        end)
        status:Label(function() return "Marker: " .. (S.hasReturnMarker and "saved" or "none") end)
        status:Info("P menu, V void, K kill all, L selected kill, mouse wheel target.")
        killStatus:Label(function() return "Target: " .. tostring(S.killTargetName or "none") end)
        killStatus:Label(function() return "Typed name: " .. tostring(S.killTargetInput or "") end)
        killStatus:Label(function() return "Status: " .. tostring(S.killAllStatus) end)
        killStatus:Info("Mouse wheel cycles targets. K kills all; L kills the selected target.")

        syncUi()
        notifyUser("Better Void", "INS-ui loaded. P opens menu, V toggles.", "success")
        return true
    end

    clampSettings()
    setupOverlay()
    createUi()
    setupKillTargetScroll()
    local hasInputHotkeys = setupHotkeys()

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

                    if holdingAim then
                        S.lastThreatName = "aim hold"
                        S.lastThreatDistance = 0
                    else
                        if S.roam then
                            local phase = tick() * S.roamSpeed
                            offsetX = (math.cos(phase) * S.roamRadius) + (math.sin(phase * 1.7) * S.roamRadius * 0.35)
                            offsetZ = (math.sin(phase) * S.roamRadius) + (math.cos(phase * 1.3) * S.roamRadius * 0.35)
                        end
                    end

                    pcall(function()
                        local targetX = holdingAim and S.aimLockX or (S.anchorX + offsetX)
                        local targetY = holdingAim and S.aimLockY or (S.anchorY + S.height)
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
        local keyState = {}
        local function pressed(code)
            local down = iskeypressed and iskeypressed(code)
            local once = down and not keyState[code]
            keyState[code] = down
            return once
        end

        while S.running do
            if not hasInputHotkeys then
                if pressed(118) then setEnabled(not S.enabled, true) end
                if pressed(KEY_KILL_ALL) then task.spawn(function() S.killAll() end) end
                if pressed(KEY_KILL_SELECTED) then task.spawn(function() S.killSelectedTarget() end) end
            end
            task.wait(0.03)
        end
    end)
end

task.spawn(boot)
