# Furnace Fire Visual

The furnace is a self-contained Godot 4.6 scene using the supplied complete RGBA furnace art. Its assets are nine heat micro-states (`s00` to `s08`), with twelve 834×1112 PNG frames per state at 15 FPS.

Frames are located in `assets/microstates/states`; `state_manifest.json` defines their order. The controller blends adjacent heat states while preserving a shared animation phase. It retains only those two visible states in memory, so it does not load all 108 frames when the brewing scene opens.

Instance `res://game/apothecary/fire_visual/furnace_fire_controller.tscn`, then provide the existing heat model's temperature:

```gdscript
furnace_fire.set_temperature(heat_controller.temperature)
```

`set_temperature()` smooths toward a target. Use `snap_to_temperature()` only for initialization, loading, or debugging. Keep any future replacement frames at 834×1112 with the same origin and transparent background.
