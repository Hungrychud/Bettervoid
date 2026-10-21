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


    local S = {
        running          = true,
        killAllCooldown  = 0.35,
        lastKillAllAt    = 0,
        autoKillTarget   = false,
        stompInProgress  = false,
        tpToSpawn        = false,
        dumpOnClick      = false,
        dumpInProgress   = false,
        retaliate        = false,
        killTargetUserId = nil,
        killTargetName   = "none",
        killTargetInput  = "",
        killAllStatus    = "idle",
        killInProgress   = false,
        killInProgressAt = 0,


        killAura         = false,
        auraRadius       = 60,


        rampage          = false,
        rampageSky       = false,

        rampageStomp     = true,
        rampageWave      = 6,
        rampageHeight    = 300,



        autoBuyArmor     = false,
        armorThreshold   = 100,
        armorStatus      = "idle",
    }
    _G.BV = S


    local PELLETS_PER_TARGET = 10
    local SHOT_BURST         = 3



    local AUTO_MAX_TARGETS   = 6
    local SHOT_DELAY         = 0.065
    local EQUIP_DELAY        = 0.06

    local STOMP_MAX_ATTEMPTS = 1
    local STOMP_STICK_TIME   = 1.2
    local STOMP_STICK_STEP   = 0.05
    local SKY_HEIGHT         = 1500
    local SKY_HOLD           = 0.7

    local RETALIATE_RADIUS   = 22
    local RETALIATE_CD       = 0.5
    local LOADOUT            = { "[Double-Barrel SG]", "[Revolver]", "[TacticalShotgun]", "None" }
    local GUN_NAMES          = { ["[Double-Barrel SG]"] = true, ["[Revolver]"] = true, ["[TacticalShotgun]"] = true }

    local AURA_STEP          = 0.3


    local Lib, win
    local handles           = {}
    local finderButtons     = {}
    local autoKillToggle    = nil
    local dumpToggle        = nil


    local function notify(title, text, kind)
        if Lib and Lib.Notify then
            pcall(function() Lib:Notify(title, text, 2, kind or "info") end)
            return
        end
        print("[BV] " .. tostring(title) .. ": " .. tostring(text))
    end


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

    local function sameInstance(a, b)
        return a ~= nil and b ~= nil and instanceKey(a) == instanceKey(b)
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
                        if sameInstance(item.Parent, character) then equippedTools[item.Name] = true end
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
                if humanoid and type(humanoid.EquipTool) == "function" then equipped = pcall(function() humanoid:EquipTool(item) end) end
                if not equipped then pcall(function() item.Parent = character end) end
            end
        end

        refillActive = false
        S.killAllStatus = next(newestTools) and "ammo refilled" or "refill timeout"
        return newestTools[requestedName] or false
    end

    local function equipKillTool(tool, character, humanoid)
        if not tool or not character then return false end
        if sameInstance(tool.Parent, character) then return true end
        local equipped = false
        if humanoid and type(humanoid.EquipTool) == "function" then equipped = pcall(function() humanoid:EquipTool(tool) end) end
        if not equipped then equipped = pcall(function() tool.Parent = character end) end
        if equipped then task.wait(EQUIP_DELAY) end
        return sameInstance(tool.Parent, character)
    end







    local function buildKillHits(targetPlayers)
        local hits = {}
        for _, player in ipairs(targetPlayers or {}) do
            local targetCharacter, valid = getKillTarget(player)
            local head = targetCharacter and (targetCharacter:FindFirstChild("Head")
                       or targetCharacter:FindFirstChild("HumanoidRootPart"))
            if valid and head then
                hits[#hits + 1] = head
            end
        end
        return hits, #hits
    end




    local function muzzleWorldPos(tool, handle)
        local m = handle and handle:FindFirstChild("Muzzle")
        local pos = m and m.WorldPosition
        if pos then return pos end
        local mesh = tool:FindFirstChild("Default")
        mesh = mesh and mesh:FindFirstChild("Mesh")
        local dm = mesh and mesh:FindFirstChild("Muzzle")
        pos = dm and dm.WorldPosition
        if pos then return pos end
        if handle and tool.Name == "[TacticalShotgun]" then
            return (handle.CFrame * CFrame.new(0, 0.25, -2.5)).Position
        end
        return handle and handle.Position or Vector3.zero
    end

    local function runKillPlayers(targetPlayers, label, burst)
        local remote = resolveRemotes()
        local _, character = getGunContainers()
        local tool = character and getEquippedGun(character)
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not remote or not tool or not root then
            S.killAllStatus = "direct shot: remote or equipped gun missing"
            return false
        end
        local handle = tool:FindFirstChild("Handle")
        local rangeValue = tool:FindFirstChild("Range")
        local damageValue = tool:FindFirstChild("Damage")
        local range = rangeValue and tonumber(rangeValue.Value) or 95
        local damage = damageValue and tonumber(damageValue.Value) or 50
        if not handle then S.killAllStatus = "direct shot: handle missing"; return false end
        -- use the game's own GunHandler.Shoot so the hit payload is a real raycast the server accepts
        local GunHandler
        pcall(function() GunHandler = require(game:GetService("ReplicatedStorage").Modules.GunHandler) end)
        if not GunHandler or type(GunHandler.Shoot) ~= "function" then
            S.killAllStatus = "no GunHandler module"; return false
        end
        local BEAM = Color3.new(1, 0.94902, 0.352941)
        local origin = muzzleWorldPos(tool, handle)
        -- shotguns send a pellet array in arg4; single-shot guns send one hit in args 5/6/7 (arg4 nil)
        local isShotgun = tool:FindFirstChild("GunClientShotgun") ~= nil
        local pelletsPerShot = isShotgun and 5 or 1
        local sent, skipped = 0, 0
        local sendError
        for _, player in ipairs(targetPlayers or {}) do
            if not S.running then break end
            local target, valid = getKillTarget(player)
            local head = target and target:FindFirstChild("Head")
            if valid and head and (head.Position - root.Position).Magnitude <= range then
                local delta = head.Position - origin
                if delta.Magnitude > 0 then
                    local aim = origin + delta.Unit * range
                    local ok, err = pcall(function()
                        if isShotgun then
                            local packets = {}
                            for pellet = 1, pelletsPerShot do
                                local r1, r2, r3 = GunHandler.Shoot({
                                    Shooter = character, Handle = handle,
                                    ForcedOrigin = origin, AimPosition = aim,
                                    BeamColor = BEAM, Range = range,
                                })
                                packets[pellet] = { AimPosition = aim, Result1 = r1, Result2 = r2, Result3 = r3 }
                            end
                            remote:FireServer("ShootGun", handle, origin, packets, nil, nil, nil, range, damage)
                        else
                            local r1, r2, r3 = GunHandler.Shoot({
                                Shooter = character, Handle = handle,
                                ForcedOrigin = origin, AimPosition = aim,
                                BeamColor = BEAM, Range = range,
                            })
                            remote:FireServer("ShootGun", handle, origin, nil, r1, r2, r3, range, damage)
                        end
                    end)
                    if ok then sent = sent + 1 else sendError = tostring(err) end
                end
            else
                skipped = skipped + 1
            end
        end
        S.killAllStatus = (label and (label .. ": ") or "") .. "direct requests " .. sent .. "; skipped " .. skipped .. "; damage unconfirmed"
        if sendError then S.killAllStatus = S.killAllStatus .. "; " .. sendError end
        return sent > 0
    end
    local function killPlayers(targetPlayers, label, _isRetry, light)


        if not _isRetry then
            if S.killInProgress and (tick() - (S.killInProgressAt or 0)) < 2 then
                S.killAllStatus = "already firing"
                return false
            end
            S.killInProgress = true
            S.killInProgressAt = tick()
        end



        local burst = light and 1 or SHOT_BURST
        local ok, result = pcall(function() return runKillPlayers(targetPlayers, label, burst) end)
        if not _isRetry then S.killInProgress = false end
        if not ok then
            S.killAllStatus = "kill error: " .. tostring(result)
            warn("BetterVoid: " .. S.killAllStatus)
            return false
        end




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











    local HOTBAR_SLOTS = { 0x31, 0x32, 0x33 }
    local function realEquipGun()
        local _, character = getGunContainers()
        if not character then return nil end
        local existing = getEquippedGun(character)
        if existing then return existing end
        if type(keypress) ~= "function" then return nil end





        S._equipRotate = (S._equipRotate or 0) % #HOTBAR_SLOTS + 1
        local order = {}
        for i = 0, #HOTBAR_SLOTS - 1 do
            order[#order + 1] = HOTBAR_SLOTS[((S._equipRotate - 1 + i) % #HOTBAR_SLOTS) + 1]
        end




        for _ = 1, 3 do
            for _, code in ipairs(order) do
                pcall(function() keypress(code) end)
                task.wait(0.07)
                pcall(function() keyrelease(code) end)
                task.wait(0.07)
                local g = getEquippedGun(character)
                if g then S._equipSlot = code; return g end
            end
        end
        return nil
    end





    local function quickUnequip(slot, light)
        if type(keypress) ~= "function" or not slot then return end
        task.spawn(function()
            task.wait(light and 0.1 or 0.45)


            for _ = 1, 4 do
                local _, character = getGunContainers()
                if not (character and getEquippedGun(character)) then break end
                pcall(function() keypress(slot) end)
                task.wait(0.06)
                pcall(function() keyrelease(slot) end)
                task.wait(0.08)
            end
        end)
    end







    local function smartKill(victims, label, light, keepArmed)
        return killPlayers(victims, label, false, light)
    end
    local function killAll()
        return smartKill(capTargets(getKillCandidates()), "all")
    end

    local function killSelected()
        local p = getSelectedPlayer()
        if not p then S.killAllStatus = "target missing"; return false end
        return smartKill({ p }, p.Name)
    end


    S.killAll      = killAll
    S.smartKill    = smartKill
    S.killSelected = killSelected



    local function koState(char)
        local be = char and char:FindFirstChild("BodyEffects")
        local ko = be and be:FindFirstChild("K.O")
        return ko ~= nil and ko.Value == true
    end






    local function doStomp(targetPlayer, retreat)
        if S.stompInProgress then return end
        if not targetPlayer then return end

        S.stompInProgress = true
        local ok, err = pcall(function()
            local remote = resolveRemotes()












            local stickDeadline = tick() + STOMP_STICK_TIME
            local lastFire = 0
            while S.running and tick() < stickDeadline do
                local char       = targetPlayer.Character
                local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
                local myRoot     = getRoot()
                if not targetRoot or not myRoot then break end
                if not koState(char) then break end



                local tp = targetRoot.Position
                pcall(function()
                    myRoot.CFrame = CFrame.new(tp.X, tp.Y + 2, tp.Z)
                end)


                if remote and tick() - lastFire >= STOMP_STICK_STEP then
                    lastFire = tick()
                    pcall(function() remote:FireServer("Stomp") end)
                end

                task.wait(0.03)
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


    local function targetState(char)
        local hum = char and (char:FindFirstChild("Humanoid") or char:FindFirstChildOfClass("Humanoid"))
        local be  = char and char:FindFirstChild("BodyEffects")
        local ko  = be and be:FindFirstChild("K.O")
        local alive = hum ~= nil and (tonumber(hum.Health) or 0) > 0
        local koed  = ko ~= nil and ko.Value == true
        return alive, koed
    end





    task.spawn(function()
        local lastTgtKillAt = 0
        local lastStompAt   = 0
        local lastChar      = nil
        local stompedChar   = nil
        while S.running do
            local ok, err = pcall(function()
                if not S.autoKillTarget then return end
                local now = tick()
                local p = getSelectedPlayer()
                if not p then S.killAllStatus = "auto: no target"; return end
                local char = p.Character





                if char and char ~= lastChar then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        if S.tpToSpawn then
                            local myRoot = getRoot()
                            if myRoot then
                                pcall(function()
                                    myRoot.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 0))
                                end)
                            end
                        end
                        lastChar = char
                    end
                end

                local alive, koed = targetState(char)
                if koed then



                    if char ~= stompedChar and not S.stompInProgress and now - lastStompAt >= 0.6 then
                        lastStompAt = now
                        stompedChar = char


                        task.spawn(function() doStomp(p, not S.tpToSpawn) end)
                    end
                elseif alive then
                    stompedChar = nil
                    if now - lastTgtKillAt >= 0.35 then
                        lastTgtKillAt = now



                        smartKill({ p }, "auto", true, true)
                    end
                end
            end)
            if not ok then S.killAllStatus = "loop err: " .. tostring(err) end
            task.wait(0.1)
        end
    end)










    task.spawn(function()
        local lastHealth = nil
        local prevFiring = {}
        local prevShots  = {}
        local lastKillAt = {}
        while S.running do
            local ok, err = pcall(function()
                if not S.retaliate then lastHealth = nil; return end
                local char = lp.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if not hum then lastHealth = nil; return end


                local myParts = {}
                for _, n in ipairs({ "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" }) do
                    local part = char:FindFirstChild(n)
                    if part then myParts[#myParts + 1] = part.Position end
                end
                if #myParts == 0 then return end

                local hp = tonumber(hum.Health) or 0
                local tookDamage = (lastHealth ~= nil and hp < lastHealth - 0.5 and hp > 0)
                lastHealth = hp

                local now = tick()
                local dmgSuspect, dmgBest = nil, math.huge

                for _, p in ipairs(Players:GetPlayers()) do
                    if not samePlayer(p, lp) and not isFriendly(p) then
                        local c  = p.Character
                        local be = c and c:FindFirstChild("BodyEffects")
                        if be then
                            local mp  = be:FindFirstChild("MousePos")
                            local gf  = be:FindFirstChild("GunFiring")
                            local gsc = be:FindFirstChild("GunShotChanges")


                            local aimDist = math.huge
                            if mp then
                                local ap = mp.Value
                                for _, pos in ipairs(myParts) do
                                    local d = (ap - pos).Magnitude
                                    if d < aimDist then aimDist = d end
                                end
                            end

                            local uid    = tonumber(p.UserId)
                            local firing = gf and gf.Value == true
                            local shots  = gsc and (tonumber(gsc.Value) or 0) or 0
                            local firedEdge = (firing and not prevFiring[uid])
                                           or (prevShots[uid] ~= nil and shots > prevShots[uid])
                            prevFiring[uid] = firing
                            prevShots[uid]  = shots


                            if firedEdge and aimDist <= RETALIATE_RADIUS then
                                if now - (lastKillAt[uid] or 0) >= RETALIATE_CD then
                                    lastKillAt[uid] = now
                                    local victim = p
                                    S.killAllStatus = "retaliate: " .. p.Name
                                    task.spawn(function() smartKill({ victim }, "retaliate", true) end)
                                end
                            end


                            if aimDist < dmgBest then dmgBest = aimDist; dmgSuspect = p end
                        end
                    end
                end



                if tookDamage and dmgSuspect and dmgBest <= RETALIATE_RADIUS * 2 then
                    local uid = tonumber(dmgSuspect.UserId)
                    if now - (lastKillAt[uid] or 0) >= RETALIATE_CD then
                        lastKillAt[uid] = now
                        local victim = dmgSuspect
                        S.killAllStatus = "retaliate(dmg): " .. dmgSuspect.Name
                        task.spawn(function() smartKill({ victim }, "retaliate", true) end)
                    end
                end
            end)
            if not ok then S.killAllStatus = "retaliate err: " .. tostring(err) end
            task.wait(0.05)
        end
    end)





    task.spawn(function()
        while S.running do
            local ok, err = pcall(function()
                if not S.killAura then return end
                local root = getRoot()
                if not root then return end
                local list = {}
                for _, p in ipairs(getKillCandidates()) do
                    local char = p.Character
                    local r    = char and char:FindFirstChild("HumanoidRootPart")
                    local _, valid = getKillTarget(p)
                    if valid and r and (r.Position - root.Position).Magnitude <= S.auraRadius then
                        list[#list + 1] = p
                    end
                end
                if #list > 0 then smartKill(capTargets(list), "aura", true, true) end
            end)
            if not ok then S.killAllStatus = "aura err: " .. tostring(err) end
            task.wait(AURA_STEP)
        end
    end)













    local rampStompActive = false
    local function rampageStompSweep()
        if rampStompActive then return end
        rampStompActive = true
        pcall(function()
            local remote = resolveRemotes()
            if not remote then return end

            local myRoot = getRoot()
            local kod = {}
            for _, p in ipairs(getKillCandidates()) do
                local c = p.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if c and r and koState(c) then kod[#kod + 1] = p end
            end
            if myRoot then
                table.sort(kod, function(a, b)
                    local ra = a.Character and a.Character:FindFirstChild("HumanoidRootPart")
                    local rb = b.Character and b.Character:FindFirstChild("HumanoidRootPart")
                    if not ra then return false end
                    if not rb then return true end
                    return (ra.Position - myRoot.Position).Magnitude < (rb.Position - myRoot.Position).Magnitude
                end)
            end
            for _, p in ipairs(kod) do



                local deadline = tick() + 0.4
                while S.running and S.rampage and tick() < deadline do
                    local c = p.Character
                    local r = c and c:FindFirstChild("HumanoidRootPart")
                    if not r or not koState(c) then break end
                    local mr = getRoot()
                    if mr then
                        pcall(function() mr.CFrame = CFrame.new(r.Position.X, r.Position.Y + 2, r.Position.Z) end)
                    end
                    pcall(function() remote:FireServer("Stomp") end)
                    task.wait(0.06)
                end
            end
        end)
        rampStompActive = false
    end

    task.spawn(function()
        while S.running do
            local ok, err = pcall(function()
                if not S.rampage then return end
                local root = getRoot()
                if not root then return end





                if S.rampageSky and not rampStompActive then
                    pcall(function()
                        root.CFrame = CFrame.new(root.Position.X, S.rampageHeight, root.Position.Z)
                    end)
                end





                local living = {}
                for _, p in ipairs(getKillCandidates()) do
                    local _, valid = getKillTarget(p)
                    if valid then living[#living + 1] = p end
                end



                if #living > 0 then
                    local cap  = math.max(1, math.min(#living, tonumber(S.rampageWave) or 6))
                    local wave = {}
                    for i = 1, cap do wave[i] = living[i] end
                    smartKill(wave, "rampage", true, true)
                end



                if S.rampageStomp and not rampStompActive then
                    task.spawn(rampageStompSweep)
                end

                S.killAllStatus = "rampage: " .. #living .. " up"
            end)
            if not ok then S.killAllStatus = "rampage err: " .. tostring(err) end


            task.wait(S.killAllCooldown + 0.05 + math.random() * 0.08)
        end
    end)








    local ARMOR_PAD_NAME = "[Full Armor]"


    -- nearest Full Armor pad to the player; returns pad, ClickDetector, Head part
    local function getArmorPad()
        local root = getRoot()
        local shop
        pcall(function()
            local ignored = workspace:FindFirstChild("Ignored")
            shop = ignored and ignored:FindFirstChild("Shop")
        end)
        if not shop then return nil end
        local bestPad, bestCD, bestHead, bestD
        for _, m in ipairs(shop:GetChildren()) do
            if string.sub(m.Name, 1, #ARMOR_PAD_NAME) == ARMOR_PAD_NAME then
                local cd   = m:FindFirstChildOfClass("ClickDetector")
                local head = m:FindFirstChild("Head")
                if cd and head then
                    local d = root and (head.Position - root.Position).Magnitude or 0
                    if not bestD or d < bestD then
                        bestPad, bestCD, bestHead, bestD = m, cd, head, d
                    end
                end
            end
        end
        return bestPad, bestCD, bestHead
    end


    local function armorValues()
        local char = lp and lp.Character
        local be   = char and char:FindFirstChild("BodyEffects")
        local armor = be and be:FindFirstChild("Armor")
        local maxObj
        pcall(function() maxObj = game:GetService("ReplicatedStorage"):FindFirstChild("MaxArmor") end)
        local cur = armor and tonumber(armor.Value)
        local max = (maxObj and tonumber(maxObj.Value)) or 200
        return cur, max
    end

    local function getCurrency()
        local df = lp and lp:FindFirstChild("DataFolder")
        local c  = df and df:FindFirstChild("Currency")
        return c and tonumber(c.Value) or 0
    end

    local armorBuyBusy = false
    local function buyArmor(reason)
        if armorBuyBusy then return false end
        armorBuyBusy = true
        local ok = false
        pcall(function()
            local pad, cd, head = getArmorPad()
            if not cd or not head then S.armorStatus = "no armor pad"; return end
            if type(fireclickdetector) ~= "function" then S.armorStatus = "no fireclickdetector"; return end
            local priceObj = pad:FindFirstChild("Price")
            local price = (priceObj and tonumber(priceObj.Value)) or 3639
            if getCurrency() < price then S.armorStatus = "not enough $"; return end
            local root = getRoot()
            if not root then S.armorStatus = "no root"; return end

            -- server validates player proximity on MouseClick, so briefly TP onto the pad
            local before = select(1, armorValues()) or 0
            local saved  = root.CFrame
            local p = head.Position
            pcall(function() root.CFrame = CFrame.new(p.X, p.Y, p.Z + 5) end)
            task.wait(0.08)
            pcall(function() fireclickdetector(cd) end)
            task.wait(0.15)
            pcall(function() root.CFrame = saved end)

            local after = select(1, armorValues()) or before
            ok = after > before
            local tag = tostring(reason or "manual")
            S.armorStatus = ok and ("bought (" .. tag .. ")") or "click fired, no change"
        end)
        armorBuyBusy = false
        return ok
    end
    S.buyArmor = buyArmor



    task.spawn(function()
        while S.running do
            local ok, err = pcall(function()
                if not S.autoBuyArmor then return end
                local cur, max = armorValues()
                if not cur then S.armorStatus = "no armor value"; return end
                local thr = math.min(tonumber(S.armorThreshold) or 100, max)
                if cur < thr then
                    buyArmor("auto")
                    task.wait(0.2)
                end
            end)
            if not ok then S.armorStatus = "armor err: " .. tostring(err) end
            task.wait(0.35)
        end
    end)


    local UIS         = game:GetService("UserInputService")
    local RunService  = game:GetService("RunService")
    local scrollConn  = nil
    local hotkeyConn  = nil
    local moveConn    = nil
    local dumpConn    = nil
    local lastScrollAt = 0



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
                if iskeypressed(0x57) then dir = dir + look  end
                if iskeypressed(0x53) then dir = dir - look  end
                if iskeypressed(0x44) then dir = dir + right end
                if iskeypressed(0x41) then dir = dir - right end

                local ws = 16
                pcall(function() ws = tonumber(hum.WalkSpeed) or 16 end)
                local v  = hrp.AssemblyLinearVelocity
                local yv = v.Y
                if iskeypressed(0x20) and math.abs(yv) < 1 then yv = 50 end

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









    local AIM_MAX_PX = 350

    local function projectToScreen(cam, pos)
        -- Matcha's WorldToScreen only works in render callbacks. Aim selection
        -- also runs in tasks, so calculate camera projection in either context.
        local vp = cam.ViewportSize
        if not vp or vp.X == 0 then return nil end
        local cs    = cam.CFrame:PointToObjectSpace(pos)
        local depth = -cs.Z
        if depth <= 0 then return nil end
        local aspect  = vp.X / vp.Y
        local tanHalf = math.tan(math.rad(cam.FieldOfView) / 2)
        local sx = ((cs.X / depth) / (tanHalf * aspect) * 0.5 + 0.5) * vp.X
        local sy = (1 - ((cs.Y / depth) / tanHalf * 0.5 + 0.5)) * vp.Y
        return sx, sy, true
    end
    local function getAimPlayer()
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local mx, my
        pcall(function() local m = lp:GetMouse() mx, my = m.X, m.Y end)
        if not mx then
            local vp = cam.ViewportSize
            if not vp then return nil end
            mx, my = vp.X / 2, vp.Y / 2
        end
        local best, bestPlayer
        for _, q in ipairs(Players:GetPlayers()) do
            if not samePlayer(q, lp) and not isFriendly(q) then
                local char = q.Character
                local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
                local _, valid = getKillTarget(q)
                if head and valid then
                    pcall(function()
                        local sx, sy, onScreen = projectToScreen(cam, head.Position)
                        if sx and onScreen then
                            local d = math.sqrt((sx - mx) ^ 2 + (sy - my) ^ 2)
                            if d <= AIM_MAX_PX and (not best or d < best) then
                                best = d; bestPlayer = q
                            end
                        end
                    end)
                end
            end
        end
        return bestPlayer
    end




    local function clickKill()
        if S.dumpInProgress then return end
        S.dumpInProgress = true
        pcall(function()
            local p = getAimPlayer()
            if not p then S.killAllStatus = "aim: no player"; return end
            if isFriendly(p) then S.killAllStatus = "aim: friendly"; return end
            smartKill({ p }, p.Name)
        end)
        S.dumpInProgress = false
    end

    pcall(function()


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







    local hasClickPoll = type(ismouse1pressed) == "function" or type(iskeypressed) == "function"
    if hasClickPoll then
        local lmbDown = false
        dumpConn = RunService.Heartbeat:Connect(function()
            if not S.running then return end
            local pressed = false
            pcall(function()
                if type(ismouse1pressed) == "function" then
                    pressed = ismouse1pressed() == true
                else
                    pressed = iskeypressed(0x01) == true
                end
            end)
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
            subtitle          = "Combat Suite",
            size              = Vector2.new(660, 470),
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











            configFolder      = "BetterVoidConfigs",
            configName        = "default",
            startOpen         = true,
        })

        if win.AddSettingsTab then win:AddSettingsTab("cog") end


        local combatTab = win:Tab("Combat", "target")
        local targetSec = combatTab:Section("Target", "Left",  "pick who dies")
        local fireSec   = combatTab:Section("Fire",   "Left",  "pull the trigger")
        local statusSec = combatTab:Section("Status",  "Right", "live readout")



        local function playerNames()
            local names = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if not samePlayer(p, lp) then names[#names + 1] = p.Name end
            end
            table.sort(names)
            return names
        end
        local targetDrop = targetSec:Dropdown("Pick target", {}, playerNames, false, function(sel)
            local name = type(sel) == "table" and sel[1] or sel
            if not name then return end
            local p = findPlayerByName(name)
            if p then
                setKillTarget(p)
                notify("Target", S.killTargetName, "success")
            else
                S.killAllStatus = "not found: " .. tostring(name)
            end
        end, "Type to search, click a name to lock it", true)

        task.spawn(function()
            while S.running do
                pcall(function() if targetDrop and targetDrop.Refresh then targetDrop:Refresh() end end)
                task.wait(2)
            end
        end)

        handles.targetBox = targetSec:Textbox("Or type a name", S.killTargetInput or "", function(value)
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

        targetSec:Button("Nearest", function()
            local ok = selectNearest()
            notify("Target", ok and S.killTargetName or S.killAllStatus, ok and "success" or "warning")
        end, "Lock the closest living enemy")
        targetSec:Button("Previous", function()
            local ok = selectStep(-1)
            notify("Target", ok and S.killTargetName or S.killAllStatus, ok and "success" or "warning")
        end)
        targetSec:Button("Next", function()
            local ok = selectStep(1)
            notify("Target", ok and S.killTargetName or S.killAllStatus, ok and "success" or "warning")
        end)
        targetSec:Button("Clear", function()
            setKillTarget(nil)
            S.killAllStatus = "cleared"
            notify("Target", "cleared", "info")
        end)
        targetSec:Info("Mouse-wheel also cycles targets.")


        fireSec:Button("Kill selected", function()
            task.spawn(function()
                local ok = killSelected()
                notify("Kill", S.killAllStatus, ok and "success" or "warning")
            end)
        end, "hotkey: L"):SetRisk()
        fireSec:Button("Kill all", function()
            task.spawn(function()
                local ok = killAll()
                notify("Kill all", S.killAllStatus, ok and "success" or "warning")
            end)
        end, "hotkey: K"):SetRisk()
        fireSec:Divider("Safety")
        fireSec:Button("Panic — kill switch", function()
            S.autoKillTarget = false
            S.dumpOnClick    = false
            S.retaliate      = false
            S.killAura       = false
            S.rampage        = false
            S.autoBuyArmor   = false
            S.killAllStatus  = "PANIC: all auto off"
            notify("Panic", "every auto feature disabled", "warning")
        end, "Instantly turn OFF every automatic feature")


        statusSec:Label(function() return "Target   : " .. tostring(S.killTargetName or "none") end)
        statusSec:Label(function()
            local p = getSelectedPlayer()
            if not p then return "HP       : —" end
            local char = p.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if not hum then return "HP       : —" end
            return "HP       : " .. math.floor(tonumber(hum.Health) or 0) .. "/" .. math.floor(tonumber(hum.MaxHealth) or 100)
        end)
        statusSec:Label(function() return "Status   : " .. tostring(S.killAllStatus) end)
        statusSec:Divider("Feature state")
        statusSec:Label(function() return "Auto     : " .. (S.autoKillTarget and "ON" or "off") end)
        statusSec:Label(function() return "ClickKill: " .. (S.dumpOnClick and "ON" or "off") end)
        statusSec:Label(function() return "Retaliate: " .. (S.retaliate and "ON" or "off") end)
        statusSec:Label(function() return "Aura     : " .. (S.killAura and "ON" or "off") end)
        statusSec:Label(function() return "Rampage  : " .. (S.rampage and "ON" or "off") end)
        statusSec:Label(function() return "AutoArmor: " .. (S.autoBuyArmor and "ON" or "off") end)
        statusSec:Info("K = kill all  •  L = kill selected  •  scroll = cycle  •  P = menu")


        local autoTab = win:Tab("Automation", "eye")
        local autoSec = autoTab:Section("Auto Target", "Left",  "hands-off killing")
        local defSec  = autoTab:Section("Defense",     "Left",  "hit back")
        local auraSec = autoTab:Section("Kill Aura",   "Right", "auto-kill in radius")

        local autoRow = autoSec:Toggle("Auto kill + stomp selected", S.autoKillTarget, function(on)
            S.autoKillTarget = on and true or false
            S.killAllStatus = S.autoKillTarget and "auto on" or "auto off"
        end, "Kill the selected target on sight, stomp when KO'd, re-kill on respawn")
        autoKillToggle = autoRow
        autoSec:Toggle("TP to target on respawn", S.tpToSpawn, function(on)
            S.tpToSpawn = on and true or false
        end, "Drop onto the target the instant they respawn"):DependsOn(autoRow)
        dumpToggle = autoSec:Toggle("Click to kill (aim at player)", S.dumpOnClick, function(on)
            S.dumpOnClick = on and true or false
            S.killAllStatus = S.dumpOnClick and "click-kill on" or "click-kill off"
        end, "Left-click kills whoever is nearest your crosshair")

        defSec:Toggle("Auto retaliate", S.retaliate, function(on)
            S.retaliate = on and true or false
            S.killAllStatus = S.retaliate and "retaliate on" or "retaliate off"
        end, "Instantly kill anyone who shoots at you")

        local auraRow = auraSec:Toggle("Kill aura", S.killAura, function(on)
            S.killAura = on and true or false
            S.killAllStatus = S.killAura and "aura on" or "aura off"
        end, "Auto-kill every enemy inside the radius")
        auraSec:Slider("Aura radius", S.auraRadius, 5, 10, 250, " studs", function(v)
            S.auraRadius = tonumber(v) or S.auraRadius
        end):DependsOn(auraRow)


        local armorSec = autoTab:Section("Armor", "Right", "keep armor topped")
        local armorRow = armorSec:Toggle("Auto-buy armor", S.autoBuyArmor, function(on)
            S.autoBuyArmor = on and true or false
            S.armorStatus  = S.autoBuyArmor and "auto-buy on" or "auto-buy off"
        end, "Buy Full Armor from the shop whenever it drops below the threshold")
        armorSec:Slider("Buy below", S.armorThreshold, 5, 10, 200, " armor", function(v)
            S.armorThreshold = tonumber(v) or S.armorThreshold
        end):DependsOn(armorRow)
        armorSec:Button("Buy armor now", function()
            task.spawn(function()
                local ok = buyArmor("manual")
                notify("Armor", S.armorStatus, ok and "success" or "warning")
            end)
        end, "Buy one Full Armor immediately")
        armorSec:Label(function()
            local cur, max = armorValues()
            return "Armor  : " .. (cur and (math.floor(cur) .. "/" .. math.floor(max)) or "—")
        end)
        armorSec:Label(function() return "Status : " .. tostring(S.armorStatus) end)


        local rampTab = win:Tab("Rampage", "shield-check")
        local rampSec = rampTab:Section("Whole-server wipe", "Left",  "delete the lobby")
        local noteSec = rampTab:Section("How it works",      "Right", "read me")

        local rampRow = rampSec:Toggle("RAMPAGE (wipe server)", S.rampage, function(on)
            S.rampage = on and true or false
            S.killAllStatus = S.rampage and "RAMPAGE on" or "RAMPAGE off"
        end, "Continuously instakill the entire lobby, paced under the kick threshold")
        local skyRow = rampSec:Toggle("Sky perch (untouchable)", S.rampageSky, function(on)
            S.rampageSky = on and true or false
        end, "Float above gun range — you stay lethal, they can't reach you"):DependsOn(rampRow)
        rampSec:Slider("Perch height", S.rampageHeight, 25, 50, 1500, " studs", function(v)
            S.rampageHeight = tonumber(v) or S.rampageHeight
        end):DependsOn(skyRow)
        rampSec:Toggle("Auto-stomp KO'd", S.rampageStomp, function(on)
            S.rampageStomp = on and true or false
        end, "Chase + stomp every downed body server-wide (farms SavedStomps)"):DependsOn(rampRow)
        rampSec:Slider("Targets / wave", S.rampageWave, 1, 1, 20, " tgt", function(v)
            S.rampageWave = tonumber(v) or S.rampageWave
        end):DependsOn(rampRow)

        noteSec:Divider("Wave size")
        noteSec:Info("Enemies downed per packet. Higher = faster whole-server wipe, but the big damage burst is what trips the kick. 6 is safe; crank it only if the server doesn't punish it.")
        noteSec:Divider("Sky perch")
        noteSec:Info("Their guns are range-limited server-side; yours isn't. Perch above their range and you wipe from a spot nobody can shoot.")




        if win.SettingsSection then
            local bvSet = win:SettingsSection("BetterVoid", "Left", "quick fixes")
            bvSet:Button("Reset appearance", function()
                pcall(function()
                    Lib:SetMenuKey("p")
                    Lib:SetOpacity(0.95)
                    Lib:SetAccent(Color3.fromRGB(80, 170, 255), Color3.fromRGB(180, 120, 255))
                    Lib:SetKeybindOverlay(true)
                    Lib:SetRowLines(true)
                    Lib:SetCheckboxStyle(true)
                    Lib:SetPerformance(false)
                    Lib:SetLayout("side")
                    Lib:SetBackgroundEffect("Rain")
                    Lib:SetBackgroundEffectColor(Color3.fromRGB(80, 170, 255))
                    Lib:SetSize(660, 470)
                    Lib:Center()
                end)
                notify("Settings", "appearance reset — menu key = P", "success")
            end, "Restore the default look + P menu key if settings got messed up")
            bvSet:Info("Configs save to a fresh 'BetterVoid' folder. Use the Configs panel to Save/Load. Old configs from earlier versions won't load — the controls were renamed.")
        end

        notify("BetterVoid", "loaded — K=kill all  L=kill selected", "success")
    end


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

task.spawn(function()
    local ok, err = pcall(boot)
    if not ok then
        warn("BetterVoid: startup failed: " .. tostring(err))
        if _G.BV then _G.BV.killAllStatus = "startup error: " .. tostring(err) end
    end
end)
