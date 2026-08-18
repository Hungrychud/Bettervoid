# BetterVoidGUI

Files:

- `main.lua` is the full in-game Drawing GUI and safer void loop.
- `loader.lua` is the pasteable loadstring template.

## Controls

- `V` toggles the void loop.
- `B` cycles depth: `-25000`, `-50000`, `-100000`.
- `N` cycles speed: `0.25`, `0.18`, `0.12` seconds.
- `X` unloads the script and removes the GUI.

## Loadstring

Upload `main.lua` to GitHub, then replace `YOUR_USERNAME/YOUR_REPOSITORY` in `loader.lua`.

Example:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/https://github.com/Hungrychud/Bettervoid/main/BetterVoidGUI/main.lua"))()
```

