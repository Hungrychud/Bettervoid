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
        killAllCooldown  = 0.35,
        lastKillAllAt    = 0,
        autoKillTarget   = false,   -- single auto mode: kill + stomp the selected target
        stompInProgress  = false,
        dumpOnClick      = false,   -- toggle: left-click empties the whole mag at the crosshair
        dumpInProgress   = false,
        killTargetUserId = nil,
        killTargetName   = "none",
        killTargetInput  = "",
        killAllStatus    = "idle",
        killInProgress   = false,
        killInProgressAt = 0,
    }
    _G.BV = S

    -- ─── Kill constants ───────────────────────────────────────────────────────
    local PELLETS_PER_TARGET = 10
    local SHOT_BURST         = 3
    -- Kill-all hits at most this many (nearest) targets per press. One FireServer
    -- against the whole server at once is an obvious mass-damage signature that
    -- gets the client kicked (looks like a crash). 0 = no cap.
    local AUTO_MAX_TARGETS   = 6
    local SHOT_DELAY         = 0.065
    local EQUIP_DELAY        = 0.06
    -- Stomp / retreat tuning
    local STOMP_MAX_ATTEMPTS = 4      -- re-fire Stomp until the body actually goes down
    local SKY_HEIGHT         = 1500   -- studs straight up = out of every gun's range
    local SKY_HOLD           = 0.7    -- seconds pinned in the sky (nobody can shoot you)
    local LOADOUT            = { "[Double-Barrel SG]", "[Revolver]", "[TacticalShotgun]", "None" }
    local GUN_NAMES          = { ["[Double-Barrel SG]"] = true, ["[Revolver]"] = true, ["[TacticalShotgun]"] = true }

    -- ─── UI handles ──────────────────────────────────────────────────────────
    local Lib, win
    local handles           = {}
    local finderButtons     = {}
    local autoKillToggle    = nil
    local dumpToggle        = nil

    -- ─── Notify ──────────────────────────────────────────────────────────────
    local function notify(title, text, kind)
        if Lib and Lib.Notify then
            pcall(function() Lib:Notify(title, text, 2, kind or "info") end)
            return
        end
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

    -- After an instakill the game can leave the local gun in a "reloading" /
    -- cooldown state, which makes your own gun refuse to shoot. Clear the client
    -- gates (BodyEffects.Reload / GunFiring, ShotgunDebounce, tool Cooldown,
    -- Ammo==0) locally so manual shooting works again.
    local function clearGunState(tool)
        local wchar
        pcall(function()
            local wp = workspace:FindFirstChild("Players")
            wchar = wp and lp and wp:FindFirstChild(lp.Name)
        end)
        if wchar then
            local be = wchar:FindFirstChild("BodyEffects")
            if be then
                local rl = be:FindFirstChild("Reload")
                if rl then pcall(function() rl.Value = false end) end
                local gf = be:FindFirstChild("GunFiring")
                if gf then pcall(function() gf.Value = false end) end
            end
            pcall(function() wchar:SetAttribute("ShotgunDebounce", nil) end)
        end
        if tool then
            pcall(function() tool:SetAttribute("Cooldown", nil) end)
            local ammo = tool:FindFirstChild("Ammo")
            local maxAmmo = tool:FindFirstChild("MaxAmmo")
            if ammo and maxAmmo then pcall(function() ammo.Value = maxAmmo.Value end) end
        end
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

    -- ─── Remotes ──────────────────────────────────────────────────────────────
    local killAllRemote = nil
    local loadoutRemote = nil
    local refillActive  = false

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

    local function resolveRemotes()
        if not isRemote(killAllRemote) then killAllRemote = findKillRemote() end
        if not isRemote(loadoutRemote) then loadoutRemote = findLoadoutRemote() end
        return killAllRemote, loadoutRemote
    end

    -- ─── Kill core ─────────────────────────────────────────────────────────────
    -- Any gun works. Prefer the one already in hand (no swap = consistent);
    -- Tactical is the best multi-target so it wins as a backpack pick.
    local GUN_PRIORITY = { "[TacticalShotgun]", "[Double-Barrel SG]", "[Revolver]" }

    local function isUsableGun(item)
        return item and item.ClassName == "Tool" and GUN_NAMES[item.Name]
           and item:FindFirstChild("Handle") and item:FindFirstChild("Ammo")
    end

    local function getEquippedGun(character)
        if not character then return nil end
        for _, item in ipairs(character:GetChildren()) do
            if isUsableGun(item) then return item end
        end
        return nil
    end

    -- Returns tool, wasEquipped
    local function getBestGun(character, backpack)
        local eq = getEquippedGun(character)
        if eq then return eq, true end
        for _, name in ipairs(GUN_PRIORITY) do
            local t = backpack and backpack:FindFirstChild(name)
            if isUsableGun(t) then return t, false end
        end
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if isUsableGun(item) then return item, false end
            end
        end
        return nil, false
    end

    local function requestLoadout()
        local _, remote = resolveRemotes()
        if not remote then S.killAllStatus = "loadout remote missing"; return false end
        local ok = pcall(function() remote:FireServer(LOADOUT) end)
        S.killAllStatus = ok and "loadout requested" or "loadout failed"
        return ok
    end

    local function requestAmmoRefill(tool, ammo)
        local _, remote = resolveRemotes()
        if not remote or refillActive or not tool or not ammo then return false end
        local backpack, character = getGunContainers()
        if not backpack then S.killAllStatus = "backpack missing"; return false end

        refillActive = true
        local requestedName = tool.Name
        local oldTools, equippedTools = {}, {}
        for _, container in ipairs({ backpack, character }) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    if item.ClassName == "Tool" and GUN_NAMES[item.Name] then
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
                        if item.ClassName == "Tool" and GUN_NAMES[item.Name] and not oldTools[instanceKey(item)] then
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

    local function equipKillTool(tool, character, humanoid)
        if not tool or not character then return false end
        if tool.Parent == character then return true end
        local equipped = false
        if humanoid then equipped = pcall(function() humanoid:EquipTool(tool) end) end
        if not equipped then equipped = pcall(function() tool.Parent = character end) end
        if equipped then task.wait(EQUIP_DELAY) end
        return tool.Parent == character
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

        local remote = resolveRemotes()
        local backpack, character = getGunContainers()
        if not remote then S.killAllStatus = "kill remote missing"; return false end
        if not character or not backpack then S.killAllStatus = "character missing"; return false end

        local tool, wasEquipped = getBestGun(character, backpack)
        if not tool then
            requestLoadout()
            S.killAllStatus = "no gun (loadout requested)"
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
        local humanoid = getHumanoid()

        -- Equip only if empty-handed, then LEAVE it equipped afterwards. No
        -- unequip / loadout-swap, which is what glitched the player's own gun.
        if not wasEquipped then
            if not equipKillTool(tool, character, humanoid) then
                S.killAllStatus = "equip failed"
                return false
            end
        end

        local handle = tool:FindFirstChild("Handle")
        if not handle then S.killAllStatus = "handle missing"; return false end

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

        -- Keep the player's own gun ready to shoot.
        clearGunState(tool)

        S.killAllStatus = (label and (label .. ": ") or "") .. "fired " .. tostring(fired) .. "x / " .. tostring(targetCount) .. " target(s)"
        return fired > 0
    end

    local function killPlayers(targetPlayers, label, _isRetry, light)
        -- Timestamp-based lock that auto-expires, so a leaked flag can never
        -- permanently wedge kill (this was the "kill all works once" bug).
        if not _isRetry then
            if S.killInProgress and (tick() - (S.killInProgressAt or 0)) < 2 then
                S.killAllStatus = "already firing"
                return false
            end
            S.killInProgress = true
            S.killInProgressAt = tick()
        end
        -- Auto (looping) mode fires a single burst and skips the retry pass; the
        -- loop itself retries next cycle. This avoids the mass-damage remote spam
        -- that trips anticheat / kicks the client when auto-killing.
        local burst = light and 1 or SHOT_BURST
        local ok, result = pcall(function() return runKillPlayers(targetPlayers, label, burst) end)
        if not _isRetry then S.killInProgress = false end
        if not ok then S.killAllStatus = "kill error"; return false end

        -- Retry pass fires directly; runKillPlayers' own cooldown guard prevents
        -- overlap, so it must NOT touch the shared killInProgress flag (that was
        -- how the flag leaked true and blocked all later kills).
        if result and not _isRetry and not light then
            local retryTargets = targetPlayers
            local retryLabel = label
            task.spawn(function()
                task.wait(0.35)
                local survivors = {}
                for _, player in ipairs(retryTargets or {}) do
                    local _, valid = getKillTarget(player)
                    if valid then survivors[#survivors + 1] = player end
                end
                if #survivors > 0 then
                    S.lastKillAllAt = 0
                    pcall(function()
                        runKillPlayers(survivors, retryLabel and (retryLabel .. "-r") or "retry")
                    end)
                end
            end)
        end
        return result
    end

    local function capTargets(list)
        if AUTO_MAX_TARGETS <= 0 or #list <= AUTO_MAX_TARGETS then return list end
        local out = {}
        for i = 1, AUTO_MAX_TARGETS do out[i] = list[i] end
        return out
    end

    local function killAll()
        return killPlayers(capTargets(getKillCandidates()), "all")
    end

    local function killSelected()
        local p = getSelectedPlayer()
        if not p then S.killAllStatus = "target missing"; return false end
        return killPlayers({ p }, p.Name)
    end

    -- Expose for keybinds / external calls / debugging.
    S.killAll      = killAll
    S.killSelected = killSelected

    -- ─── Stomp ──────────────────────────────────────────────────────────────
    -- Is this character currently KO'd (down, stompable)?
    local function koState(char)
        local be = char and char:FindFirstChild("BodyEffects")
        local ko = be and be:FindFirstChild("K.O")
        return ko ~= nil and ko.Value == true
    end

    -- Teleport onto a KO'd body and stomp until it goes down, then rocket
    -- straight up out of gun range and hold so nobody can shoot you during the
    -- exposed stomp moment. Whole body pcall-wrapped with a GUARANTEED reset of
    -- stompInProgress — a leaked flag permanently blocked every future stomp
    -- (that was the "stomp stopped working" bug). One stomp at a time.
    local function doStomp(targetPlayer, retreat)
        if S.stompInProgress then return end
        if not targetPlayer then return end

        S.stompInProgress = true
        local ok, err = pcall(function()
            local remote = resolveRemotes()

            for _ = 1, STOMP_MAX_ATTEMPTS do
                if not S.running then break end
                local char       = targetPlayer.Character
                local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
                local myRoot     = getRoot()
                if not targetRoot or not myRoot then break end
                if not koState(char) then break end -- done (dead / respawned / up)

                local tp = targetRoot.Position
                pcall(function()
                    myRoot.CFrame = CFrame.new(tp.X, tp.Y + 3, tp.Z)
                end)
                task.wait(0.18) -- give the server time to receive the new position

                if remote then pcall(function() remote:FireServer("Stomp") end) end

                task.wait(0.5)  -- let the stomp register
                if not koState(targetPlayer.Character) then break end
            end

            if retreat then
                local myRoot = getRoot()
                if myRoot then
                    local safe = CFrame.new(myRoot.Position + Vector3.new(0, SKY_HEIGHT, 0))
                    local deadline = tick() + SKY_HOLD
                    while S.running and tick() < deadline do
                        local r = getRoot()
                        if not r then break end
                        pcall(function() r.CFrame = safe end)
                        task.wait(0.06)
                    end
                end
            end
        end)

        S.stompInProgress = false
        if not ok then S.killAllStatus = "stomp err: " .. tostring(err) end
    end

    -- State of the selected target: is the character alive / KO'd right now?
    local function targetState(char)
        local hum = char and (char:FindFirstChild("Humanoid") or char:FindFirstChildOfClass("Humanoid"))
        local be  = char and char:FindFirstChild("BodyEffects")
        local ko  = be and be:FindFirstChild("K.O")
        local alive = hum ~= nil and (tonumber(hum.Health) or 0) > 0
        local koed  = ko ~= nil and ko.Value == true
        return alive, koed
    end

    -- ─── Auto kill + stomp loop (selected target only) ─────────────────────────
    -- One target, one job: kill it while it's up, stomp it while it's KO'd,
    -- re-kill the instant it respawns. Never hops to another player. Whole body
    -- pcall'd so a transient error can never freeze or stop the loop.
    task.spawn(function()
        local lastTgtKillAt = 0
        local lastStompAt   = 0
        while S.running do
            local ok, err = pcall(function()
                if not S.autoKillTarget then return end
                local now = tick()
                local p = getSelectedPlayer()
                if not p then S.killAllStatus = "auto: no target"; return end
                local alive, koed = targetState(p.Character)
                if koed then
                    if not S.stompInProgress and now - lastStompAt >= 0.6 then
                        lastStompAt = now
                        task.spawn(function() doStomp(p, true) end) -- retreat to sky after
                    end
                elseif alive then
                    if now - lastTgtKillAt >= 0.35 then
                        lastTgtKillAt = now
                        killPlayers({ p }, "auto", false, false) -- full burst = faster KO
                    end
                end
            end)
            if not ok then S.killAllStatus = "loop err: " .. tostring(err) end
            task.wait(0.1)
        end
    end)

    -- ─── Input ────────────────────────────────────────────────────────────────
    local UIS         = game:GetService("UserInputService")
    local RunService  = game:GetService("RunService")
    local scrollConn  = nil
    local hotkeyConn  = nil
    local moveConn    = nil
    local dumpConn    = nil
    local lastScrollAt = 0
    -- The UI lib grabs ALL input while the window is open (free cursor so you can
    -- click), which kills WASD movement. We track that "captured" state and drive
    -- movement ourselves so you can walk AND click at the same time.
    local gameInputCaptured = false

    pcall(function()
        local realSet = setrobloxinput
        if type(realSet) == "function" then
            S._realSetInput = realSet
            setrobloxinput = function(toGame)
                gameInputCaptured = (toGame == false)
                return realSet(toGame)
            end
        end
    end)

    -- Manual movement driver (Matcha: Humanoid:Move is unbound, so we set
    -- AssemblyLinearVelocity directly). Only runs while the menu has input.
    if type(iskeypressed) == "function" then
        moveConn = RunService.Heartbeat:Connect(function()
            if not S.running or not gameInputCaptured then return end
            pcall(function()
                local ch  = lp.Character
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                local cam = workspace.CurrentCamera
                if not hum or not hrp or not cam then return end
                if (tonumber(hum.Health) or 0) <= 0 then return end

                local look  = cam.CFrame.LookVector
                local right = cam.CFrame.RightVector
                look  = Vector3.new(look.X, 0, look.Z)
                right = Vector3.new(right.X, 0, right.Z)

                local dir = Vector3.new(0, 0, 0)
                if iskeypressed(0x57) then dir = dir + look  end -- W
                if iskeypressed(0x53) then dir = dir - look  end -- S
                if iskeypressed(0x44) then dir = dir + right end -- D
                if iskeypressed(0x41) then dir = dir - right end -- A

                local ws = 16
                pcall(function() ws = tonumber(hum.WalkSpeed) or 16 end)
                local v  = hrp.AssemblyLinearVelocity
                local yv = v.Y
                if iskeypressed(0x20) and math.abs(yv) < 1 then yv = 50 end -- Space = jump

                if dir.Magnitude > 0.05 then
                    dir = dir.Unit
                    hrp.AssemblyLinearVelocity = Vector3.new(dir.X * ws, yv, dir.Z * ws)
                else
                    hrp.AssemblyLinearVelocity = Vector3.new(0, yv, 0)
                end
            end)
        end)
    end

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

    -- ─── Click-to-kill (aim at a player, click, head-snap burst) ───────────────
    -- Same head-snap kill as "kill selected", but the target is whoever is under
    -- your crosshair when you click. Matcha lacks GetMouseLocation / mouse.Hit
    -- AND GetPlayerFromCharacter, so we raycast forward from the camera (that IS
    -- the crosshair) and resolve the player by walking the hit part's ancestors
    -- and matching against the player list (by identity or character name).
    local function getAimPlayer()
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local res
        pcall(function()
            local params = RaycastParams.new()
            pcall(function() params.FilterType = Enum.RaycastFilterType.Exclude end)
            pcall(function() params.FilterDescendantsInstances = { lp.Character } end)
            res = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 5000, params)
        end)
        if not res or not res.Instance then return nil end
        local inst = res.Instance
        for _ = 1, 8 do
            if not inst then break end
            for _, pl in ipairs(Players:GetPlayers()) do
                if not samePlayer(pl, lp) then
                    if pl.Character == inst or inst.Name == pl.Name then return pl end
                end
            end
            inst = inst.Parent
        end
        return nil
    end

    -- On click: kill the player under the crosshair with the full head-snap burst
    -- + retry (identical to "kill selected"). dumpInProgress serializes rapid
    -- clicks so bursts can't stack.
    local function clickKill()
        if S.dumpInProgress then return end
        S.dumpInProgress = true
        pcall(function()
            local p = getAimPlayer()
            if not p then S.killAllStatus = "aim: no player"; return end
            if isFriendly(p) then S.killAllStatus = "aim: friendly"; return end
            killPlayers({ p }, p.Name)
        end)
        S.dumpInProgress = false
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
                task.spawn(killAll)          -- K = instant kill all
            elseif keyMatches(input, "L", 108) then
                task.spawn(killSelected)     -- L = kill selected target only
            end
        end)
    end)

    -- Left-click detection via iskeypressed(0x01) (VK_LBUTTON). Matcha's
    -- UIS.InputBegan does NOT report mouse buttons reliably, so we poll the
    -- physical button and fire on the press edge. Skipped while the menu holds
    -- the cursor so clicking UI buttons doesn't dump your mag.
    if type(iskeypressed) == "function" then
        local lmbDown = false
        dumpConn = RunService.Heartbeat:Connect(function()
            if not S.running then return end
            local pressed = false
            pcall(function() pressed = iskeypressed(0x01) == true end)
            if pressed and not lmbDown then
                lmbDown = true
                if S.dumpOnClick and not gameInputCaptured and not S.dumpInProgress then
                    task.spawn(clickKill)
                end
            elseif not pressed then
                lmbDown = false
            end
        end)
    end

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
            gameInput         = false, -- menu captures input (free cursor = UI
                                        -- clickable); our own driver handles WASD
                                        -- so you can still walk while it's open
            startOpen         = true,
        })

        if win.AddSettingsTab then win:AddSettingsTab("cog") end

        local killTab = win:Tab("Instant Kill", "target")

        local killControls = killTab:Section("Controls", "Left",  "target and fire")
        local killStatus   = killTab:Section("Status",   "Right", "live state")
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

        -- AUTO
        killControls:Divider("Auto")
        autoKillToggle = killControls:Toggle("Auto kill + stomp selected", S.autoKillTarget, function(on)
            S.autoKillTarget = on and true or false
            S.killAllStatus = S.autoKillTarget and "auto on" or "auto off"
        end)
        dumpToggle = killControls:Toggle("Click to kill (aim at player)", S.dumpOnClick, function(on)
            S.dumpOnClick = on and true or false
            S.killAllStatus = S.dumpOnClick and "click-kill on" or "click-kill off"
        end)

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
        killStatus:Label(function() return "Auto:     " .. (S.autoKillTarget and "on" or "off") end)
        killStatus:Label(function() return "ClickKill:" .. (S.dumpOnClick and " on" or " off") end)
        killStatus:Info("K = kill all  |  L = kill selected  |  scroll = cycle targets  |  P = menu")

        notify("BetterVoid", "loaded — K=kill all  L=kill selected", "success")
    end

    -- ─── Unload ───────────────────────────────────────────────────────────────
    S.unload = function()
        S.running = false
        clearFinder()
        if scrollConn then pcall(function() scrollConn:Disconnect() end) scrollConn = nil end
        if hotkeyConn then pcall(function() hotkeyConn:Disconnect() end) hotkeyConn = nil end
        if moveConn   then pcall(function() moveConn:Disconnect()   end) moveConn   = nil end
        if dumpConn   then pcall(function() dumpConn:Disconnect()   end) dumpConn   = nil end
        if S._realSetInput then pcall(function() setrobloxinput = S._realSetInput end) pcall(S._realSetInput, true) end
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
