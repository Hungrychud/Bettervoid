-- Better Void INS-ui loader.
-- Matcha: loadstring(readfile("BetterVoid/loader.lua"))()

local function stripBom(source)
    if type(source) == "string" and source:byte(1) == 239 and source:byte(2) == 187 and source:byte(3) == 191 then
        return source:sub(4)
    end
    return source
end

local function run(source, label)
    source = stripBom(source)
    local chunk, err = loadstring(source)
    if not chunk then
        error("Better Void failed to compile " .. tostring(label) .. ": " .. tostring(err))
    end
    return chunk()
end

if readfile and isfile and isfile("BetterVoid/main.lua") then
    return run(readfile("BetterVoid/main.lua"), "BetterVoid/main.lua")
end

return run(game:HttpGet("https://raw.githubusercontent.com/Hungrychud/Bettervoid/main/main.lua"), "GitHub main.lua")