# BetterVoidGUI

Void-only Better Void using INS-ui.

## Files

- `main.lua` contains only the void loop plus INS-ui controls.
- `loader.lua` loads `BetterVoid/main.lua` in Matcha, otherwise falls back to the GitHub raw `main.lua` URL.

## Controls

- `P` opens and closes the INS-ui menu.
- `V` toggles the void loop.
- `X` unloads the script.

## Matcha

Put `loader.lua` and `main.lua` in `C:\matcha\workspace\BetterVoid`, then run:

```lua
loadstring(readfile("BetterVoid/loader.lua"))()
```

Console controls:

```lua
_G.BetterVoid.setEnabled(true)
_G.BetterVoid.setEnabled(false)
_G.BetterVoid.unload()
```

INS-ui source:

```lua
https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua
```