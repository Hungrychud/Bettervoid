# BetterVoidGUI

Files:

- `main.lua` is the INS-ui styled GUI and client-side movement helper.
- `loader.lua` is the pasteable GitHub raw loader.

## Controls

- `P` opens and closes the INS-ui menu.
- `V` toggles the void loop.
- `Z` toggles Auto stomp by default; change it from the keybind control in the GUI.
- `C` toggles Teleport stomp by default; change it from the keybind control in the GUI.
- `J` manually stomps the best knocked target once.
- `B` panic-disables active features.
- `M` saves a return marker; `N` returns to it.
- `1`, `2`, `3` load Slot1/Slot2/Slot3; `4`, `5`, `6` save Slot1/Slot2/Slot3.
- `X` unloads the script and removes the GUI.
- Use the GUI sliders and toggles to change height, tick delay, velocity, roam, target filters, aim correction, visuals, no reload, and stomp settings.

## Notes

- This is a client-side script. Server-authoritative systems, such as damage validation, may ignore client-only rapid-fire attempts.
- `No reload` keeps local supported weapon ammo topped up and clears the local reload flag. Server-side ammo validation may still apply.
- `Aim corrector` improves the client-side rapid-fire ray by selecting a visible target inside the Aim FOV cone.
- `FOV circle` and `Knocked ESP` use Drawing overlays and are removed on unload.
- `Visual rapid fire` is off by default because it can show extra local shots without server damage registration.
- `Auto stomp` uses the existing `MainGameEvent` stomp action and depends on what the live server accepts.

## Presets

- `Above map`: moderate height and safer default movement.
- `High sky`: stronger vertical offset.
- `Very high`: aggressive and more likely to trigger server correction.
- `Anti snapback` briefly pulses faster if your character gets corrected near the surface, then stops the void loop if the server keeps snapping you back.

## Loadstring

`loader.lua` always loads the GitHub raw copy below. Local edits to `main.lua` will not run through the loader until you update that GitHub file.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Hungrychud/Bettervoid/main/main.lua"))()
```

The UI library is loaded from:

```lua
https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua
```
