local function boot()
    local Players = game:GetService("Players")
    local lp

    local t0 = tick()
    repeat
        lp = Players.LocalPlayer
        if not lp then task.wait(0.1) end
    until lp or tick() - t0 > 10
    if not lp then warn("BetterVoid: LocalPlayer not found") return end

    if _G.BV and _G.BV.unload then pcall(_G.BV.unload) end

    -- ─── State ───────────────────────────────────────────────────────────────
    local S = {
        running          = true,
        killAllCooldown  = 0.8,
        lastKillAllAt    = 0,
        autoKillInterval = 2.0,
        killOnSightRange = 500,
        autoKillTarget   = false,
        autoKillAll      = false,
        killOnSight      = false,
        autoRetarget     = false,
        autoStomp        = false,
        stompInProgress  = false,
        killTargetUserId = nil,
        killTargetName   = "none",
        killTargetInput  = "",
        killAllStatus    = "idle",
        killInProgress   = false,
    }
    _G.BV = S

    -- ─── Kill constants ───────────────────────────────────────────────────────
    local PELLETS_PER_TARGET = 10
    local SHOT_BURST         = 3
    local SHOT_DELAY         = 0.065
    local EQUIP_DELAY        = 0.06
    local LOADOUT            = { "[Double-Barrel SG]", "[Revolver]", "[TacticalShotgun]", "None" }
    local GUN_NAMES          = { ["[Double-Barrel SG]"] = true, ["[Revolver]"] = true, ["[TacticalShotgun]"] = true }

    -- ─── UI handles ──────────────────────────────────────────────────────────
    local Lib, win
    local handles              = {}
    local finderButtons        = {}
    local autoKillTargetToggle = nil
    local autoKillAllToggle    = nil
    local killOnSightToggle    = nil
    local autoRetargetToggle   = nil

    -- ─── Notify ──────────────────────────────────────────────────────────────
    local function notify(title, text, kind)
        if Lib and Lib.Notify then
            pcall(function() Lib:Notify(title, text, 2, kind or "info") end)
            return
        end
        if notify then pcall(function() notify(title, text, 2) end) return end
        print("[BV] " .. tostring(title) .. ": " .. tostring(text))
    end

    -- ─── Character helpers ────────────────────────────────────────────────────
    local function getRoot()
        local char = lp and lp.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function getHumanoid()
        local char = lp and lp.Character
        if not char then return nil end
        local h
        pcall(function() h = char:FindFirstChildOfClass("Humanoid") end)
        return h or char:FindFirstChild("Humanoid")
    end

    local function getGunContainers()
        return lp and lp:FindFirstChild("Backpack"), lp and lp.Character
    end

    -- ─── Player helpers ───────────────────────────────────────────────────────
    local function samePlayer(a, b)
        return a and b and tonumber(a.UserId) ~= nil and tonumber(a.UserId) == tonumber(b.UserId)
    end

    local function isFriendly(player)
        local env = (getgenv and getgenv()) or _G
        local lib = env and (env.Library or _G.Library)
        if not lib or type(lib.get_priority) ~= "function" then return false end
        local ok, p = pcall(lib.get_priority, lib, player)
        return ok and tostring(p or ""):lower() == "friendly"
    end

    local function getKillTarget(player)
        if not player or samePlayer(player, lp) or isFriendly(player) then return nil, false end
        local char = player.Character
        local hum  = char and (char:FindFirstChild("Humanoid") or char:FindFirstChildOfClass("Humanoid"))
        local be   = char and char:FindFirstChild("BodyEffects")
        local ko   = be and be:FindFirstChild("K.O")
        local valid = hum and tonumber(hum.Health) and hum.Health > 0 and not (ko and ko.Value)
        return char, valid == true
    end

    local function getKillCandidates()
        local root   = getRoot()
        local result = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if not samePlayer(p, lp) and not isFriendly(p) then
                result[#result + 1] = p
            end
        end
        if root and #result > 1 then
            table.sort(result, function(a, b)
                local ca, cb = a.Character, b.Character
                local ra = ca and ca:FindFirstChild("HumanoidRootPart")
                local rb = cb and cb:FindFirstChild("HumanoidRootPart")
                if not ra then return false end
                if not rb then return true end
                return (ra.Position - root.Position).Magnitude < (rb.Position - root.Position).Magnitude
            end)
        end
        return result
    end

    local function findPlayerByName(query)
        query = string.lower(tostring(query or ""):match("^%s*(.-)%s*$"))
        if query == "" or query == "none" then return nil end
        local partial
        for _, p in ipairs(Players:GetPlayers()) do
            if not samePlayer(p, lp) then
                local n = string.lower(p.Name)
                if n == query then return p end
                if not partial and string.find(n, query, 1, true) then partial = p end
            end
        end
        return partial
    end

    local function getSelectedPlayer()
        local uid  = tonumber(S.killTargetUserId)
        local name = string.lower(tostring(S.killTargetInput ~= "" and S.killTargetInput or S.killTargetName or ""))
        for _, p in ipairs(Players:GetPlayers()) do
            if not samePlayer(p, lp) then
                if uid and tonumber(p.UserId) == uid then return p end
                if name ~= "" and name ~= "none" and string.lower(p.Name) == name then return p end
            end
        end
        return findPlayerByName(S.killTargetInput ~= "" and S.killTargetInput or S.killTargetName)
    end

    local function setKillTarget(player)
        if player and not samePlayer(player, lp) then
            S.killTargetUserId = tonumber(player.UserId)
            S.killTargetName   = tostring(player.Name)
            S.killTargetInput  = tostring(player.Name)
            S.killAllStatus    = "target " .. player.Name
            if handles.targetBox then pcall(function() handles.targetBox.Value = player.Name end) end
            return true
        end
        S.killTargetUserId = nil
        S.killTargetName   = "none"
        S.killTargetInput  = ""
        if handles.targetBox then pcall(function() handles.targetBox.Value = "" end) end
        return false
    end

    local function selectNearest()
        for _, p in ipairs(getKillCandidates()) do
            local _, valid = getKillTarget(p)
            if valid then return setKillTarget(p) end
        end
        S.killAllStatus = "no living targets"
        return false
    end

    local function selectStep(step)
        local candidates = getKillCandidates()
        if #candidates == 0 then S.killAllStatus = "no targets" return false end
        local uid = tonumber(S.killTargetUserId)
        local idx = 1
        if uid then
            for i, p in ipairs(candidates) do
                if tonumber(p.UserId) == uid then idx = i + step break end
            end
        end
        while idx > #candidates do idx = idx - #candidates end
        while idx < 1 do idx = idx + #candidates end
        return setKillTarget(candidates[idx])
    end

    local function autoRetargetIfDead()
        if not S.killTargetUserId then return end
        local p = getSelectedPlayer()
        local _, valid = getKillTarget(p)
        if not valid then
            local changed = selectNearest()
            if changed then notify("Auto re-target", S.killTargetName, "info") end
        end
    end

    -- ─── Remotes ──────────────────────────────────────────────────────────────
    -- Ported verbatim from the working backup instakill (maintt.lua).
    local killAllRemote = nil
    local loadoutRemote = nil
    local refillActive  = false
    local GUN_SET       = GUN_NAMES

    local function isRemote(o) return o and o.ClassName == "RemoteEvent" end

    local function instanceKey(object)
        if not object then return "nil" end
        local ok, address = pcall(function() return object.Address end)
        if ok and address then return tostring(address) end
        local okName, fullName = pcall(function() return object:GetFullName() end)
        return okName and fullName or tostring(object)
    end

    local function findKillRemote()
        local storage = game:GetService("ReplicatedStorage")
        local gameRemotes = storage and storage:FindFirstChild("GameRemotes")
        local mainRemotes = storage and storage:FindFirstChild("MainRemotes")
        local exact = (gameRemotes and gameRemotes:FindFirstChild("MainGameEvent"))
                   or (mainRemotes and mainRemotes:FindFirstChild("MainRemoteEvent"))
        if isRemote(exact) then return exact end
        local fallback
        local ok, descendants = pcall(function() return storage:GetDescendants() end)
        if not ok or not descendants then return nil end
        for _, object in ipairs(descendants) do
            if isRemote(object) then
                fallback = fallback or object
                local name = string.lower(object.Name or "")
                if string.find(name, "main", 1, true) or string.find(name, "game", 1, true) then
                    return object
                end
            end
        end
        return fallback
    end

    local function findLoadoutRemote()
        local storage = game:GetService("ReplicatedStorage")
        local exact = storage and storage:FindFirstChild("Loadout")
        if isRemote(exact) then return exact end
        local remotes = storage and storage:FindFirstChild("Remotes")
        exact = remotes and remotes:FindFirstChild("Loadout")
        if isRemote(exact) then return exact end
        local ok, descendants = pcall(function() return storage:GetDescendants() end)
        if not ok or not descendants then return nil end
        for _, object in ipairs(descendants) do
            if isRemote(object) and string.find(string.lower(object.Name or ""), "loadout", 1, true) then
                return object
            end
        end
        return nil
    end

    local function resolveKillAllRemotes()
        if not isRemote(killAllRemote) then killAllRemote = findKillRemote() end
        if not isRemote(loadoutRemote) then loadoutRemote = findLoadoutRemote() end
        return killAllRemote, loadoutRemote
    end
    local resolveRemotes = resolveKillAllRemotes -- alias used by auto-stomp

    -- ─── Kill core (backup port) ───────────────────────────────────────────────
    local function getTacticalShotgun(character, backpack)
        return (backpack and backpack:FindFirstChild("[TacticalShotgun]"))
            or (character and character:FindFirstChild("[TacticalShotgun]"))
    end

    local function requestLoadout()
        local _, remote = resolveKillAllRemotes()
        if not remote then S.killAllStatus = "loadout remote missing"; return false end
        local ok = pcall(function() remote:FireServer(LOADOUT) end)
        S.killAllStatus = ok and "loadout requested" or "loadout failed"
        return ok
    end

    local function requestAmmoRefill(tool, ammo)
        local _, remote = resolveKillAllRemotes()
        if not remote or refillActive or not tool or not ammo then return false end
        local backpack, character = getGunContainers()
        if not backpack then S.killAllStatus = "backpack missing"; return false end

        refillActive = true
        local requestedName = tool.Name
        local oldTools, equippedTools = {}, {}
        for _, container in ipairs({ backpack, character }) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    if item.ClassName == "Tool" and GUN_SET[item.Name] then
                        oldTools[instanceKey(item)] = item
                        if item.Parent == character then equippedTools[item.Name] = true end
                    end
                end
            end
        end

        local ok = pcall(function() remote:FireServer(LOADOUT) end)
        if not ok then refillActive = false; S.killAllStatus = "refill failed"; return false end

        local newestTools = {}
        local deadline = tick() + 2
        while S.running and tick() < deadline do
            for _, container in ipairs({ backpack, character }) do
                if container then
                    for _, item in ipairs(container:GetChildren()) do
                        if item.ClassName == "Tool" and GUN_SET[item.Name] and not oldTools[instanceKey(item)] then
                            newestTools[item.Name] = item
                        end
                    end
                end
            end
            if next(newestTools) then break end
            task.wait(0.05)
        end

        local humanoid = getHumanoid()
        for name, item in pairs(newestTools) do
            if equippedTools[name] and character and item.Parent then
                local equipped = false
                if humanoid then equipped = pcall(function() humanoid:EquipTool(item) end) end
                if not equipped then pcall(function() item.Parent = character end) end
            end
        end

        refillActive = false
        S.killAllStatus = next(newestTools) and "ammo refilled" or "refill timeout"
        return newestTools[requestedName] or false
    end

    local function usableAmmo(tool, ammo)
        if not ammo then return false end
        local value = tonumber(ammo.Value) or 0
        if value <= 0 then return requestAmmoRefill(tool, ammo) ~= false end
        return true
    end

    local function getEquippedTool(character)
        if not character then return nil end
        for _, item in ipairs(character:GetChildren()) do
            if item.ClassName == "Tool" then return item end
        end
        return nil
    end

    local function equipKillTool(tool, character, humanoid)
        if not tool or not character then return false end
        if tool.Parent == character then return true end
        local equipped = false
        if humanoid then equipped = pcall(function() humanoid:EquipTool(tool) end) end
        if not equipped then equipped = pcall(function() tool.Parent = character end) end
        if equipped then task.wait(EQUIP_DELAY) end
        return tool.Parent == character
    end

    local function restoreKillTool(tool, previousTool, character, backpack, wasEquipped)
        if wasEquipped then return end
        local humanoid = getHumanoid()
        if previousTool and previousTool.Parent == character then return end
        if previousTool and previousTool.Parent == backpack and humanoid then
            local restored = pcall(function() humanoid:EquipTool(previousTool) end)
            if restored then task.wait(0.05); return end
        end
        if humanoid then
            pcall(function() humanoid:UnequipTools() end)
            task.wait(0.03)
        end
        if tool and backpack and tool.Parent == character then
            pcall(function() tool.Parent = backpack end)
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
                for _ = 1, PELLETS_PER_TARGET do
                    local jx = (math.random() - 0.5) * 0.5
                    local jy = (math.random() - 0.5) * 0.5
                    local jz = (math.random() - 0.5) * 0.5
                    local jittered = position + Vector3.new(jx, jy, jz)
                    pellets[#pellets + 1] = {
                        AimPosition = jittered,
                        Result1 = jittered,
                        Result2 = head,
                        Result3 = Vector3.yAxis
                    }
                end
            end
        end
        return pellets, targetCount
    end

    local function runKillPlayers(targetPlayers, label, burst)
        burst = burst or SHOT_BURST
        local now = tick()
        if now - (S.lastKillAllAt or 0) < S.killAllCooldown then
            S.killAllStatus = "cooldown"
            return false
        end
        S.lastKillAllAt = now

        local remote = resolveKillAllRemotes()
        local backpack, character = getGunContainers()
        if not remote then S.killAllStatus = "kill remote missing"; return false end
        if not character or not backpack then S.killAllStatus = "character missing"; return false end

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
        for shot = 1, burst do
            handle = tool:FindFirstChild("Handle")
            if not handle then break end
            local shotPellets = shot == 1 and pellets or buildKillPellets(targetPlayers)
            if #shotPellets == 0 then break end
            local okFire = pcall(function()
                remote:FireServer("ShootGun", handle, handle.Position, shotPellets, nil, nil, nil, range, damage)
            end)
            if okFire then fired = fired + 1 end
            if shot < burst then task.wait(SHOT_DELAY) end
        end

        restoreKillTool(tool, previousTool, character, backpack, wasEquipped)

        S.killAllStatus = (label and (label .. ": ") or "") .. "fired " .. tostring(fired) .. "x / " .. tostring(targetCount) .. " target(s)"
        return fired > 0
    end

    local function killPlayers(targetPlayers, label, _isRetry, light)
        if S.killInProgress and not _isRetry then
            S.killAllStatus = "already firing"
            return false
        end
        if not _isRetry then S.killInProgress = true end
        -- Auto (looping) modes fire a single burst and skip the retry pass; the
        -- loop itself retries next cycle. This avoids the mass-damage remote
        -- spam that trips anticheat / kicks the client when auto-killing.
        local burst = light and 1 or SHOT_BURST
        local ok, result = pcall(function() return runKillPlayers(targetPlayers, label, burst) end)
        if not _isRetry then S.killInProgress = false end
        if not ok then S.killAllStatus = "kill error"; return false end

        if result and not _isRetry and not light then
            local retryTargets = targetPlayers
            local retryLabel = label
            task.spawn(function()
                task.wait(0.35)
                if S.killInProgress then return end
                local survivors = {}
                for _, player in ipairs(retryTargets or {}) do
                    local _, valid = getKillTarget(player)
                    if valid then survivors[#survivors + 1] = player end
                end
                if #survivors > 0 then
                    S.lastKillAllAt = 0
                    S.killInProgress = true
                    pcall(function()
                        runKillPlayers(survivors, retryLabel and (retryLabel .. "-r") or "retry")
                    end)
                    S.killInProgress = false
                end
            end)
        end
        return result
    end

    local function killAll()
        return killPlayers(Players and Players:GetPlayers() or {}, "all")
    end

    local function killSelected()
        local p = getSelectedPlayer()
        if not p then S.killAllStatus = "target missing"; return false end
        return killPlayers({ p }, p.Name)
    end

    local function killAllExcept()
        local uid     = tonumber(S.killTargetUserId)
        local targets = {}
        for _, p in ipairs(Players and Players:GetPlayers() or {}) do
            if not samePlayer(p, lp) and not isFriendly(p) then
                if not uid or tonumber(p.UserId) ~= uid then
                    targets[#targets+1] = p
                end
            end
        end
        if #targets == 0 then S.killAllStatus = "no targets"; return false end
        return killPlayers(targets, "all-except")
    end

    -- ─── Auto stomp ──────────────────────────────────────────────────────────
    local koConns = {}

    local function doStomp(targetPlayer)
        if S.stompInProgress then return end
        local char       = targetPlayer and targetPlayer.Character
        local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end
        local myRoot = getRoot()
        if not myRoot then return end

        S.stompInProgress = true

        -- Teleport directly above the KO'd body (server raycasts downward)
        local tp = targetRoot.Position
        pcall(function()
            myRoot.CFrame = CFrame.new(tp.X, tp.Y + 3, tp.Z)
        end)

        task.wait(0.18) -- give server time to receive updated position

        local remote = resolveRemotes()
        if remote then
            pcall(function() remote:FireServer("Stomp") end)
        end

        task.wait(0.9)
        S.stompInProgress = false
    end

    -- Watch for KO changes on all enemy players
    task.spawn(function()
        while S.running do
          pcall(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if not samePlayer(p, lp) then
                    local uid = tonumber(p.UserId)
                    if uid and not koConns[uid] then
                        local pchar = p.Character
                        local be    = pchar and pchar:FindFirstChild("BodyEffects")
                        local ko    = be and be:FindFirstChild("K.O")
                        if ko then
                            local handler = function()
                                if not ko.Value then return end
                                if not S.autoStomp or S.stompInProgress then return end
                                local isTarget = (S.autoKillTarget and tonumber(S.killTargetUserId) == uid)
                                              or S.autoKillAll
                                              or S.killOnSight
                                if isTarget then
                                    task.spawn(function() doStomp(p) end)
                                end
                            end
                            local okc, conn = pcall(function()
                                return ko:GetPropertyChangedSignal("Value"):Connect(handler)
                            end)
                            if not okc then
                                okc, conn = pcall(function() return ko.Changed:Connect(handler) end)
                            end
                            if okc and conn then koConns[uid] = conn else koConns[uid] = true end
                        end
                    end
                end
            end
            -- Cleanup players who left
            for uid in pairs(koConns) do
                local found = false
                for _, p in ipairs(Players:GetPlayers()) do
                    if tonumber(p.UserId) == uid then found = true; break end
                end
                if not found then
                    pcall(function() koConns[uid]:Disconnect() end)
                    koConns[uid] = nil
                end
            end
          end)
            task.wait(2)
        end
    end)

    -- ─── Auto kill loop ───────────────────────────────────────────────────────
    -- Whole body wrapped in pcall so a transient error can never freeze or stop
    -- the loop (a stuck loop with no yield is what crashes the client).
    task.spawn(function()
        local lastAutoAt = 0
        while S.running do
            local ok, err = pcall(function()
                local now = tick()
                if (S.killOnSight or S.autoKillAll or S.autoKillTarget) and now - lastAutoAt >= S.autoKillInterval then
                    lastAutoAt = now

                    if S.killOnSight then
                        local root = getRoot()
                        if root then
                            local inRange = {}
                            for _, p in ipairs(Players:GetPlayers()) do
                                if not samePlayer(p, lp) and not isFriendly(p) then
                                    local pchar = p.Character
                                    local pr    = pchar and pchar:FindFirstChild("HumanoidRootPart")
                                    if pr and (pr.Position - root.Position).Magnitude <= S.killOnSightRange then
                                        local _, valid = getKillTarget(p)
                                        if valid then inRange[#inRange + 1] = p end
                                    end
                                end
                            end
                            if #inRange > 0 then killPlayers(inRange, "sight", false, true) end
                        end
                    elseif S.autoKillAll then
                        killPlayers(getKillCandidates(), "auto-all", false, true)
                    elseif S.autoKillTarget then
                        if S.autoRetarget then autoRetargetIfDead() end
                        local p = getSelectedPlayer()
                        if p then
                            local _, valid = getKillTarget(p)
                            if valid then killPlayers({ p }, "auto", false, true) end
                        end
                    end
                end
            end)
            if not ok then S.killAllStatus = "loop err: " .. tostring(err) end
            task.wait(0.15)
        end
    end)

    -- ─── Input ────────────────────────────────────────────────────────────────
    local UIS         = game:GetService("UserInputService")
    local scrollConn  = nil
    local hotkeyConn  = nil
    local lastScrollAt = 0

    pcall(function()
        scrollConn = UIS.InputChanged:Connect(function(input)
            if not S.running then return end
            local wheel = 0
            pcall(function()
                if input.UserInputType == Enum.UserInputType.MouseWheel then
                    wheel = input.Position.Z
                end
            end)
            if wheel == 0 then return end
            if tick() - lastScrollAt < 0.12 then return end
            lastScrollAt = tick()
            local ok = selectStep(wheel < 0 and -1 or 1)
            if ok then notify("Target", S.killTargetName, "info") end
        end)
    end)

    -- Robust key match: Matcha's `input.KeyCode == Enum.KeyCode.K` can fail
    -- (Enum comparison unsupported), so fall back to numeric/.Value/string match.
    local function keyMatches(input, keyName, fallbackCode)
        if not input then return false end
        local keyCode = nil
        pcall(function() keyCode = input.KeyCode end)
        if not keyCode then return false end
        local enumKey = nil
        pcall(function() enumKey = Enum and Enum.KeyCode and Enum.KeyCode[keyName] end)
        if enumKey and keyCode == enumKey then return true end
        local numeric = tonumber(keyCode)
        if numeric and numeric == fallbackCode then return true end
        local value = nil
        pcall(function() value = keyCode.Value end)
        if tonumber(value) == fallbackCode then return true end
        local text   = string.lower(tostring(keyCode))
        local wanted = string.lower(tostring(keyName))
        return text == wanted or string.sub(text, -#wanted) == wanted
    end

    pcall(function()
        -- No gameProcessedEvent gate: in Matcha `gp` is often truthy for every
        -- key, which silently swallowed every hotkey.
        hotkeyConn = UIS.InputBegan:Connect(function(input)
            if not S.running then return end
            local focused = false
            pcall(function() focused = UIS:GetFocusedTextBox() ~= nil end)
            if focused then return end
            if keyMatches(input, "K", 107) then
                task.spawn(killAll)
            elseif keyMatches(input, "L", 108) then
                task.spawn(killSelected)
            end
        end)
    end)

    -- ─── People finder ────────────────────────────────────────────────────────
    local function clearFinder()
        for _, b in ipairs(finderButtons) do
            pcall(function()
                if b.Destroy then b:Destroy()
                elseif b.Remove then b:Remove()
                elseif b.Unload then b:Unload() end
            end)
        end
        finderButtons = {}
    end

    local function openFinder()
        if not handles.finderSection then return end
        clearFinder()
        local query = string.lower(tostring(S.killTargetInput or ""):match("^%s*(.-)%s*$"))
        local shown = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if shown >= 30 then break end
            if not samePlayer(p, lp) then
                local name = p.Name
                local display = ""
                pcall(function() display = tostring(p.DisplayName or "") end)
                local label = (display ~= "" and display ~= name) and (name .. " (" .. display .. ")") or name
                if query == "" or string.find(string.lower(label), query, 1, true) then
                    local tp = p
                    local ok, btn = pcall(function()
                        return handles.finderSection:Button(label, function()
                            setKillTarget(tp)
                            notify("Target", S.killTargetName, "success")
                        end)
                    end)
                    if ok and btn then finderButtons[#finderButtons + 1] = btn end
                    shown = shown + 1
                end
            end
        end
        notify("People finder", shown > 0 and (shown .. " players") or "no matches", shown > 0 and "success" or "warning")
    end

    -- ─── UI ───────────────────────────────────────────────────────────────────
    local function loadLib()
        local ok, result = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua"))()
        end)
        if ok then return result or INSUI or INSui end
        warn("BetterVoid: UI lib failed: " .. tostring(result))
        return nil
    end

    Lib = loadLib()

    if not Lib or not Lib.CreateWindow then
        notify("BetterVoid", "UI failed — K=kill all  L=kill selected", "warning")
    else
        win = Lib:CreateWindow({
            title             = "Better Void",
            subtitle          = "Instant Kill",
            size              = Vector2.new(620, 430),
            position          = Vector2.new(48, 48),
            menuKey           = "p",
            theme             = { accent = Color3.fromRGB(80, 170, 255) },
            accentA           = Color3.fromRGB(80, 170, 255),
            accentB           = Color3.fromRGB(180, 120, 255),
            font              = "Proxima",
            opacity           = 0.95,
            rounding          = 1,
            rowLines          = true,
            checkboxStyle     = true,
            keybindOverlay    = true,
            backgroundEffect  = "Rain",
            backgroundEffectColor = Color3.fromRGB(80, 170, 255),
            autoSave          = false,
            smartFps          = true,
            gameInput         = false,
            startOpen         = true,
        })

        if win.AddSettingsTab then win:AddSettingsTab("cog") end

        local killTab = win:Tab("Instant Kill", "target")

        local killControls = killTab:Section("Controls",      "Left",  "target and fire")
        local killAuto     = killTab:Section("Auto Kill",     "Left",  "automated killing")
        local killStatus   = killTab:Section("Status",        "Right", "live state")
        handles.finderSection = killTab:Section("People Finder", "Right", "player list")

        -- TARGET
        killControls:Divider("Target")
        handles.targetBox = killControls:Textbox("Target name", S.killTargetInput or "", function(value)
            local text = tostring(value or ""):match("^%s*(.-)%s*$")
            S.killTargetInput = text
            if text == "" then
                S.killTargetUserId = nil
                S.killTargetName   = "none"
                S.killAllStatus    = "target cleared"
                return
            end
            local p = findPlayerByName(text)
            if p then
                S.killTargetUserId = tonumber(p.UserId)
                S.killTargetName   = p.Name
                S.killAllStatus    = "target " .. p.Name
            else
                S.killTargetUserId = nil
                S.killTargetName   = text
                S.killAllStatus    = "target typed"
            end
        end, "Exact or partial name")

        killControls:Button("Select nearest", function()
            local ok = selectNearest()
            notify("Target", ok and S.killTargetName or S.killAllStatus, ok and "success" or "warning")
        end)
        killControls:Button("Previous target", function()
            local ok = selectStep(-1)
            notify("Target", ok and S.killTargetName or S.killAllStatus, ok and "success" or "warning")
        end)
        killControls:Button("Next target", function()
            local ok = selectStep(1)
            notify("Target", ok and S.killTargetName or S.killAllStatus, ok and "success" or "warning")
        end)
        killControls:Button("Clear target", function()
            setKillTarget(nil)
            S.killAllStatus = "cleared"
            notify("Target", "cleared", "info")
        end)
        killControls:Button("Open people finder", function()
            openFinder()
        end)
        handles.finderSection:Button("Refresh list", function()
            openFinder()
        end)
        handles.finderSection:Info("Type name above to filter. Click player to select.")

        -- FIRE
        killControls:Divider("Fire")
        killControls:Button("Kill selected [L]", function()
            task.spawn(function()
                local ok = killSelected()
                notify("Kill", S.killAllStatus, ok and "success" or "warning")
            end)
        end):SetRisk()
        killControls:Button("Kill all [K]", function()
            task.spawn(function()
                local ok = killAll()
                notify("Kill all", S.killAllStatus, ok and "success" or "warning")
            end)
        end):SetRisk()
        killControls:Button("Kill all except selected", function()
            task.spawn(function()
                local ok = killAllExcept()
                notify("Kill except", S.killAllStatus, ok and "success" or "warning")
            end)
        end):SetRisk()

        -- AUTO KILL
        killAuto:Divider("Auto kill mode")
        autoKillTargetToggle = killAuto:Toggle("Auto kill selected", S.autoKillTarget, function(on)
            S.autoKillTarget = on and true or false
            if on then S.autoKillAll = false; S.killOnSight = false end
            if autoKillAllToggle   and autoKillAllToggle.Set   then pcall(function() autoKillAllToggle:Set(false) end) end
            if killOnSightToggle   and killOnSightToggle.Set   then pcall(function() killOnSightToggle:Set(false) end) end
        end)
        autoKillAllToggle = killAuto:Toggle("Auto kill all", S.autoKillAll, function(on)
            S.autoKillAll = on and true or false
            if on then S.autoKillTarget = false; S.killOnSight = false end
            if autoKillTargetToggle and autoKillTargetToggle.Set then pcall(function() autoKillTargetToggle:Set(false) end) end
            if killOnSightToggle    and killOnSightToggle.Set    then pcall(function() killOnSightToggle:Set(false) end) end
        end)
        killOnSightToggle = killAuto:Toggle("Kill on sight", S.killOnSight, function(on)
            S.killOnSight = on and true or false
            if on then S.autoKillTarget = false; S.autoKillAll = false end
            if autoKillTargetToggle and autoKillTargetToggle.Set then pcall(function() autoKillTargetToggle:Set(false) end) end
            if autoKillAllToggle    and autoKillAllToggle.Set    then pcall(function() autoKillAllToggle:Set(false) end) end
        end)
        autoRetargetToggle = killAuto:Toggle("Auto re-target on death", S.autoRetarget, function(on)
            S.autoRetarget = on and true or false
        end)
        killAuto:Toggle("Auto stomp KO'd targets", S.autoStomp, function(on)
            S.autoStomp = on and true or false
        end)
        killAuto:Slider("Kill interval", S.autoKillInterval, 0.5, 0.5, 30, "s", function(v)
            S.autoKillInterval = math.max(0.5, math.min(30, v))
        end)
        killAuto:Slider("Sight range", S.killOnSightRange, 50, 50, 5000, " studs", function(v)
            S.killOnSightRange = math.floor(v)
        end)

        -- STATUS
        killStatus:Label(function() return "Target:   " .. tostring(S.killTargetName or "none") end)
        killStatus:Label(function() return "Status:   " .. tostring(S.killAllStatus) end)
        killStatus:Label(function()
            local p = getSelectedPlayer()
            if not p then return "HP:       —" end
            local char = p.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if not hum then return "HP:       —" end
            return "HP:       " .. math.floor(tonumber(hum.Health) or 0) .. "/" .. math.floor(tonumber(hum.MaxHealth) or 100)
        end)
        killStatus:Label(function()
            local mode = S.killOnSight and "sight" or S.autoKillAll and "all" or S.autoKillTarget and "target" or "off"
            return "Auto:     " .. mode
        end)
        killStatus:Label(function() return "Interval: " .. tostring(S.autoKillInterval) .. "s" end)
        killStatus:Label(function() return "Range:    " .. tostring(S.killOnSightRange) .. " studs" end)
        killStatus:Label(function() return "Stomp:    " .. (S.autoStomp and "active" or "off") end)
        killStatus:Info("K = kill all  |  L = kill selected  |  scroll = cycle targets  |  P = menu")

        notify("BetterVoid", "loaded — K=kill all  L=kill selected", "success")
    end

    -- ─── Unload ───────────────────────────────────────────────────────────────
    S.unload = function()
        S.running = false
        clearFinder()
        for uid, conn in pairs(koConns) do
            pcall(function() conn:Disconnect() end)
            koConns[uid] = nil
        end
        if scrollConn then pcall(function() scrollConn:Disconnect() end) scrollConn = nil end
        if hotkeyConn then pcall(function() hotkeyConn:Disconnect() end) hotkeyConn = nil end
        if win then
            pcall(function()
                if win.Destroy then win:Destroy()
                elseif win.Unload then win:Unload() end
            end)
            win = nil
        end
        _G.BV = nil
    end
end

task.spawn(boot)
