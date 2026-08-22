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
        lastKillAllAt    = 0,
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
    local killRemote, loadoutRemote
    local refillActive = false

    local function isRemote(o) return o and o.ClassName == "RemoteEvent" end

    local function findKillRemote()
        local rs = game:GetService("ReplicatedStorage")
        local gr = rs:FindFirstChild("GameRemotes")
        local mr = rs:FindFirstChild("MainRemotes")
        local exact = (gr and gr:FindFirstChild("MainGameEvent")) or (mr and mr:FindFirstChild("MainRemoteEvent"))
        if isRemote(exact) then return exact end
        local ok, desc = pcall(function() return rs:GetDescendants() end)
        if not ok then return nil end
        local fallback
        for _, o in ipairs(desc) do
            if isRemote(o) then
                fallback = fallback or o
                local n = string.lower(o.Name)
                if string.find(n, "main", 1, true) or string.find(n, "game", 1, true) then return o end
            end
        end
        return fallback
    end

    local function findLoadoutRemote()
        local rs = game:GetService("ReplicatedStorage")
        local exact = rs:FindFirstChild("Loadout")
        if isRemote(exact) then return exact end
        local rem = rs:FindFirstChild("Remotes")
        exact = rem and rem:FindFirstChild("Loadout")
        if isRemote(exact) then return exact end
        local ok, desc = pcall(function() return rs:GetDescendants() end)
        if not ok then return nil end
        for _, o in ipairs(desc) do
            if isRemote(o) and string.find(string.lower(o.Name), "loadout", 1, true) then return o end
        end
        return nil
    end

    local function resolveRemotes()
        if not isRemote(killRemote)    then killRemote    = findKillRemote()    end
        if not isRemote(loadoutRemote) then loadoutRemote = findLoadoutRemote() end
        return killRemote, loadoutRemote
    end

    local function instanceKey(o)
        if not o then return "nil" end
        local ok, v = pcall(function() return o.Address end)
        if ok and v then return tostring(v) end
        local ok2, v2 = pcall(function() return o:GetFullName() end)
        return ok2 and v2 or tostring(o)
    end

    local function requestLoadout()
        local _, remote = resolveRemotes()
        if not remote then return false end
        return pcall(function() remote:FireServer(LOADOUT) end)
    end

    local function getTacticalShotgun(char, bp)
        return (bp and bp:FindFirstChild("[TacticalShotgun]")) or (char and char:FindFirstChild("[TacticalShotgun]"))
    end

    local function requestAmmoRefill(tool, ammo)
        local _, remote = resolveRemotes()
        if not remote or refillActive or not tool or not ammo then return false end
        local bp, char = getGunContainers()
        if not bp then return false end

        refillActive = true
        local reqName    = tool.Name
        local oldTools   = {}
        local equippedTools = {}
        for _, c in ipairs({ bp, char }) do
            if c then
                for _, item in ipairs(c:GetChildren()) do
                    if item.ClassName == "Tool" and GUN_NAMES[item.Name] then
                        oldTools[instanceKey(item)] = item
                        if item.Parent == char then equippedTools[item.Name] = true end
                    end
                end
            end
        end

        pcall(function() remote:FireServer(LOADOUT) end)

        local newest  = {}
        local deadline = tick() + 2
        while S.running and tick() < deadline do
            for _, c in ipairs({ bp, char }) do
                if c then
                    for _, item in ipairs(c:GetChildren()) do
                        if item.ClassName == "Tool" and GUN_NAMES[item.Name] and not oldTools[instanceKey(item)] then
                            newest[item.Name] = item
                        end
                    end
                end
            end
            if next(newest) then break end
            task.wait(0.05)
        end

        local hum = getHumanoid()
        for name, item in pairs(newest) do
            if equippedTools[name] and char and item.Parent then
                local ok = hum and pcall(function() hum:EquipTool(item) end)
                if not ok then pcall(function() item.Parent = char end) end
            end
        end

        refillActive = false
        return newest[reqName] or false
    end

    -- ─── Kill core ────────────────────────────────────────────────────────────
    local function buildPellets(targetPlayers)
        local pellets, count = {}, 0
        for _, p in ipairs(targetPlayers or {}) do
            local char, valid = getKillTarget(p)
            local head = char and char:FindFirstChild("Head")
            if valid and head then
                count = count + 1
                local pos = head.Position
                for _ = 1, PELLETS_PER_TARGET do
                    local j = Vector3.new((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.5)
                    local jp = pos + j
                    pellets[#pellets + 1] = { AimPosition = jp, Result1 = jp, Result2 = head, Result3 = Vector3.yAxis }
                end
            end
        end
        return pellets, count
    end

    local function runKill(targetPlayers, label)
        local now = tick()
        if now - S.lastKillAllAt < S.killAllCooldown then
            S.killAllStatus = "cooldown"
            return false
        end
        S.lastKillAllAt = now

        local remote = resolveRemotes()
        local bp, char = getGunContainers()
        if not remote  then S.killAllStatus = "remote missing"    return false end
        if not char or not bp then S.killAllStatus = "character missing" return false end

        local tool = getTacticalShotgun(char, bp)
        if not tool then
            requestLoadout()
            S.killAllStatus = "loadout requested"
            return false
        end

        local handle = tool:FindFirstChild("Handle")
        local ammo   = tool:FindFirstChild("Ammo")
        if ammo and (tonumber(ammo.Value) or 0) <= 0 then
            local refilled = requestAmmoRefill(tool, ammo)
            if refilled then
                tool   = refilled
                handle = tool:FindFirstChild("Handle")
                ammo   = tool:FindFirstChild("Ammo")
            end
        end

        if not handle then S.killAllStatus = "handle missing" return false end
        if ammo and (tonumber(ammo.Value) or 0) <= 0 then S.killAllStatus = "no ammo" return false end

        local rangeObj = tool:FindFirstChild("Range")
        local dmgObj   = tool:FindFirstChild("Damage")
        local range    = rangeObj and (tonumber(rangeObj.Value) or 200) or 200
        local damage   = dmgObj   and (tonumber(dmgObj.Value)   or 50)  or 50

        local wasEquipped = tool.Parent == char
        local prevTool
        if not wasEquipped then
            for _, item in ipairs(char:GetChildren()) do
                if item.ClassName == "Tool" then prevTool = item break end
            end
        end

        local hum = getHumanoid()
        if not wasEquipped then
            local ok = hum and pcall(function() hum:EquipTool(tool) end)
            if not ok then pcall(function() tool.Parent = char end) end
            task.wait(EQUIP_DELAY)
        end

        handle = tool:FindFirstChild("Handle")
        if not handle then S.killAllStatus = "handle lost" return false end

        local pellets, targetCount = buildPellets(targetPlayers)
        if #pellets == 0 then
            S.killAllStatus = (label or "") .. ": no targets"
            return false
        end

        local fired = 0
        for shot = 1, SHOT_BURST do
            handle = tool:FindFirstChild("Handle")
            if not handle then break end
            local shotPellets = shot == 1 and pellets or buildPellets(targetPlayers)
            if #shotPellets == 0 then break end
            local ok = pcall(function()
                remote:FireServer("ShootGun", handle, handle.Position, shotPellets, nil, nil, nil, range, damage)
            end)
            if ok then fired = fired + 1 end
            if shot < SHOT_BURST then task.wait(SHOT_DELAY) end
        end

        if not wasEquipped then
            if prevTool and prevTool.Parent == bp and hum then
                pcall(function() hum:EquipTool(prevTool) end)
                task.wait(0.05)
            elseif hum then
                pcall(function() hum:UnequipTools() end)
                task.wait(0.03)
            end
            if tool.Parent == char then pcall(function() tool.Parent = bp end) end
        end

        S.killAllStatus = (label and label .. ": " or "") .. "fired " .. fired .. "x / " .. targetCount .. " target(s)"
        return fired > 0
    end

    local function killPlayers(targetPlayers, label, _retry)
        if S.killInProgress and not _retry then
            S.killAllStatus = "already firing"
            return false
        end
        if not _retry then S.killInProgress = true end
        local ok, result = pcall(function() return runKill(targetPlayers, label) end)
        if not _retry then S.killInProgress = false end
        if not ok then S.killAllStatus = "kill error" return false end

        if result and not _retry then
            local rt, rl = targetPlayers, label
            task.spawn(function()
                task.wait(0.35)
                if S.killInProgress then return end
                local survivors = {}
                for _, p in ipairs(rt or {}) do
                    local _, valid = getKillTarget(p)
                    if valid then survivors[#survivors + 1] = p end
                end
                if #survivors > 0 then
                    S.lastKillAllAt  = 0
                    S.killInProgress = true
                    pcall(function() runKill(survivors, rl and (rl .. "-r") or "retry") end)
                    S.killInProgress = false
                end
            end)
        end
        return result
    end

    local function killAll()
        return killPlayers(Players:GetPlayers(), "all")
    end

    local function killSelected()
        local p = getSelectedPlayer()
        if not p then S.killAllStatus = "target missing" return false end
        return killPlayers({ p }, p.Name)
    end

    local function killAllExcept()
        local uid = tonumber(S.killTargetUserId)
        local targets = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if not samePlayer(p, lp) and not isFriendly(p) then
                if not uid or tonumber(p.UserId) ~= uid then
                    targets[#targets + 1] = p
                end
            end
        end
        if #targets == 0 then S.killAllStatus = "no targets" return false end
        return killPlayers(targets, "except")
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
            for _, p in ipairs(Players:GetPlayers()) do
                if not samePlayer(p, lp) then
                    local uid = tonumber(p.UserId)
                    if uid and not koConns[uid] then
                        local pchar = p.Character
                        local be    = pchar and pchar:FindFirstChild("BodyEffects")
                        local ko    = be and be:FindFirstChild("K.O")
                        if ko then
                            koConns[uid] = ko.Changed:Connect(function(val)
                                if not val then return end
                                if not S.autoStomp or S.stompInProgress then return end
                                local isTarget = (S.autoKillTarget and tonumber(S.killTargetUserId) == uid)
                                              or S.autoKillAll
                                              or S.killOnSight
                                if isTarget then
                                    task.spawn(function() doStomp(p) end)
                                end
                            end)
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
            task.wait(2)
        end
    end)

    -- ─── Auto kill loop ───────────────────────────────────────────────────────
    task.spawn(function()
        local lastAutoAt = 0
        while S.running do
            local now = tick()
            if (S.killOnSight or S.autoKillAll or S.autoKillTarget) and now - lastAutoAt >= S.autoKillInterval then
                lastAutoAt   = now
                S.lastKillAllAt = 0

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
                        if #inRange > 0 then killPlayers(inRange, "sight") end
                    end
                elseif S.autoKillAll then
                    killPlayers(Players:GetPlayers(), "auto-all")
                elseif S.autoKillTarget then
                    if S.autoRetarget then autoRetargetIfDead() end
                    local p = getSelectedPlayer()
                    if p then
                        local _, valid = getKillTarget(p)
                        if valid then killPlayers({ p }, "auto") end
                    end
                end
            end
            task.wait(0.1)
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

    pcall(function()
        hotkeyConn = UIS.InputBegan:Connect(function(input, gp)
            if not S.running or gp then return end
            local focused = false
            pcall(function() focused = UIS:GetFocusedTextBox() ~= nil end)
            if focused then return end
            pcall(function()
                if input.KeyCode == Enum.KeyCode.K then
                    task.spawn(killAll)
                elseif input.KeyCode == Enum.KeyCode.L then
                    task.spawn(killSelected)
                end
            end)
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
        handles.cooldownSlider = killControls:Slider("Cooldown", S.killAllCooldown, 0.1, 0.3, 10, "s", function(v)
            S.killAllCooldown = math.max(0.3, math.min(10, v))
        end)
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
