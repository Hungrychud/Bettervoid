-- BetterVoid loader
-- Executor: loadstring(readfile("BetterVoid/loader.lua"))()

local function stripBom(s)
    if type(s) == "string" and s:byte(1) == 239 and s:byte(2) == 187 and s:byte(3) == 191 then
        return s:sub(4)
    end
    return s
end

local function run(src, label)
    src = stripBom(src)
    local chunk, err = loadstring(src)
    if not chunk then
        error("BetterVoid: failed to compile " .. tostring(label) .. ": " .. tostring(err))
    end
    return chunk()
end

if readfile and isfile and isfile("BetterVoid/main.lua") then
    return run(readfile("BetterVoid/main.lua"), "BetterVoid/main.lua")
end

return run(game:HttpGet("https://raw.githubusercontent.com/Hungrychud/Bettervoid/main/main.lua"), "GitHub")
