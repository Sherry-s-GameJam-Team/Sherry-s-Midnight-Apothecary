# Magic Map Switch — Godot 4.6.x

A self-contained prototype built from the three supplied textures:

- `assets/device/transsformer.png` — main Vialia instrument.
- `assets/device/wheel.png` — dormant rune-wheel shown inside the circular display.
- `assets/device/switch.png` — pull lever used to confirm the selected destination.

The project is intentionally **signal-only**: confirming a destination does **not** change scene. It emits `travel_requested(destination_id, destination_data)` so the real project can decide what travel means later.

## Run

1. Open this folder with Godot 4.6.x (4.6.3 is recommended within the 4.6 line).
2. Run `project.godot` / press F6 or F5.
3. Click **ACTIVATE DEVICE**.
4. The supplied rune-wheel dissolves into the map with a cyan/violet magical transition.
5. Hold left mouse inside the circular map and drag the chart. The selection cursor stays fixed at the circle center.
6. When a route node approaches the center, magnetic attraction increases. Release near the center to snap it exactly into place.
7. The right panel displays that destination's detailed information.
8. Drag the supplied lever downward. At >= 82% pull, the demo emits `travel_requested(...)` and prints the destination ID. No scene is changed.

## Main files

- `scenes/map_switch_demo.tscn` — minimal entry scene.
- `scripts/map_switch_controller.gd` — public API, UI assembly, input routing, selection and signal emission.
- `scripts/map_canvas.gd` — procedural map, routes, map nodes, panning and magnetic candidate calculation.
- `scripts/lever_confirm.gd` — pull-to-confirm interaction.
- `scripts/crosshair.gd` — fixed center cursor.
- `scripts/magic_overlay.gd` — temporary ring/spark effect during activation.
- `shaders/dial_to_map.gdshader` — circular mask + magical dissolve from rune wheel to live map.

## Integration API

The controller exposes these signals:

```gdscript
signal travel_requested(destination_id: StringName, destination_data: Dictionary)
signal destination_selected(destination_id: StringName, destination_data: Dictionary)
signal activation_finished
```

and these public methods:

```gdscript
activate()
reset_to_dial()
configure_destinations(new_destinations: Array)
```

### Current behavior: signal only

`_on_lever_committed()` in `scripts/map_switch_controller.gd` contains the final confirmation step:

```gdscript
travel_requested.emit(data.get("id", &"unknown"), data)
```

It deliberately contains **no** `change_scene_to_file()` call.

There is one demo receiver connection in `_ready()`:

```gdscript
travel_requested.connect(_demo_receive_travel_signal)
```

This only prints the emitted ID. Delete that connection after migration if your game owns the signal externally.

## How to add real travel later

Recommended architecture for the existing game:

```gdscript
# GameFlow / SceneRouter
func bind_map_switch(map_switch: Node) -> void:
    map_switch.travel_requested.connect(_on_map_travel_requested)

func _on_map_travel_requested(destination_id: StringName, data: Dictionary) -> void:
    # Future implementation only. Keep travel logic outside the device UI.
    # save_current_day_state()
    # transition_overlay.play_out()
    # get_tree().change_scene_to_file(data["scene_path"])
    pass
```

Add a `scene_path` (or your own route key) to each destination dictionary only when the real scene router is ready.

## Destination data format

Each destination currently uses a dictionary like:

```gdscript
{
    "id": &"raintree_forest",
    "name": "Rain Tree Forest",
    "subtitle": "Wet Alchemy Woods",
    "pos": Vector2(82, -142),
    "danger": "MEDIUM",
    "distance": "2 relays",
    "environment": "Forest / Rain",
    "description": "..."
}
```

`pos` is a map-space position around the center, not a screen position. For a larger project, move these dictionaries to a Resource, JSON, or your existing location database and call `configure_destinations(...)`.

## Magnetic selection tuning

In `map_switch_controller.gd`:

- `MAGNET_RADIUS = 94.0` — attraction begins inside this map-space radius.
- `SNAP_RADIUS = 108.0` — releasing inside this radius locks the destination.

In `map_canvas.gd`, the attraction factor is deliberately progressive rather than an instant teleport so the cursor feels physically "magnetic".

## Circular map mask

The live map is rendered into a `SubViewport` at 512×512. A `Sprite2D` displays its `ViewportTexture`. `dial_to_map.gdshader` masks pixels outside the circle and mixes the supplied `wheel.png` with the live viewport texture during activation.

This means the map itself can freely pan beyond the visible aperture while the instrument's round brass frame remains static.

## Display alignment

The supplied instrument texture is 1086×1448. These constants align the live display to its upper circular aperture:

```gdscript
const DEVICE_DISPLAY_CENTER := Vector2(543.0, 337.0)
const DEVICE_DISPLAY_DIAMETER := 424.0
```

If the instrument art is replaced or re-cropped, adjust only these two values. The map interaction, fixed cursor and shader display use the same coordinates.

## Migrating into Sherry's project

Recommended approach:

1. Copy the `assets/device`, `scripts`, and `shaders` folders into a dedicated folder such as `res://day/interactables/map_switch/`.
2. Change preload paths in `map_switch_controller.gd` after moving files.
3. Instantiate the controller as a modal interaction scene, or refactor the dynamic construction into your preferred authored `.tscn` UI.
4. Call `activate()` after the player's interaction prompt succeeds.
5. While the modal is open, disable player movement / potion throwing through your existing interaction lock.
6. Connect `travel_requested` to `GameFlow`, but keep the actual travel implementation there rather than inside this device.
7. When real travel is ready, resolve `destination_id` to your existing day scene / map scene registry.

## Input ownership

The map consumes left-mouse input only while dragging inside the active circular display. The lever consumes left-mouse input only while the lever is enabled. This keeps the component easy to place on top of an existing 2D game without globally rebinding the mouse.

## Asset note

The three PNG files are the user's supplied art and are included only as project assets for this prototype.
