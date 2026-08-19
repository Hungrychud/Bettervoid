# BetterVoidGUI

Void-only Better Void using INS-ui.

## Features

- INS-ui menu.
- Void loop toggle.
- Map roam toggle with radius and speed.
- Presets: Above map, Wide roam, High sky, Fast circle.
- Save/load config.
- Panic stop.
- Return marker save/return.
- Small Drawing position/radar overlay.
- Anti-stick evade when another player gets too close.
- Aim stabilizer pauses roam/evade while shooting so shots drift less.

## Controls

- `P` opens and closes the INS-ui menu.
- `V` toggles the void loop.
- `R` toggles roam.
- `T` toggles aim stabilizer.
- `G` toggles anti-stick evade.
- `B` panic-stops active movement.
- `M` saves a return marker.
- `N` returns to the marker.
- `X` unloads the script.

## Matcha

Put `loader.lua` and `main.lua` in `C:\matcha\workspace\BetterVoid`, then run:

```lua
loadstring(readfile("BetterVoid/loader.lua"))()
```

Console controls:

```lua
_G.BetterVoid.setEnabled(true)
_G.BetterVoid.setRoam(true)
_G.BetterVoid.setAimStabilizer(true)
_G.BetterVoid.setAntiStick(true)
_G.BetterVoid.saveReturnMarker()
_G.BetterVoid.returnToMarker()
_G.BetterVoid.saveConfig()
_G.BetterVoid.loadConfig()
_G.BetterVoid.panic()
_G.BetterVoid.unload()
```

INS-ui source:

```lua
https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua
```