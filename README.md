# BetterVoidGUI

Files:

- `main.lua` is the INS-ui styled GUI and safer void loop.
- `loader.lua` is the pasteable loadstring template.

## Controls

- `P` opens and closes the INS-ui menu.
- `V` toggles the void loop.
- `X` unloads the script and removes the GUI.
- Use the GUI sliders to change depth, tick delay, and fall velocity.
- Start with the `Under map` preset. `Deep void` is more likely to trigger snapback.

## Void presets

- `Under map`: `-650`, safer against server snapback.
- `Low void`: `-2500`, stronger but may be corrected on some servers.
- `Deep void`: `-10000`, aggressive and most likely to be snapped back.
- `Anti snapback` briefly pulses faster if your character gets corrected near the surface.

## Loadstring

Upload `main.lua` to GitHub, then use this raw GitHub URL:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Hungrychud/Bettervoid/main/main.lua"))()
```

The UI library is loaded from:

```lua
https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua
```
