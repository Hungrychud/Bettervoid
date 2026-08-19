-- Better Void INS-ui loader.
-- Matcha: loadstring(readfile("BetterVoid/loader.lua"))()

local function run(source, label)
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