# Magic Map Switch

Reusable day-mode modal interaction. It renders `MagicMapCanvas` to a 512x512 `SubViewport`; `CircularDisplay` samples that live texture and uses `dial_to_map.gdshader` for the circular mask and dial-to-map dissolve.

The authored scene exposes `DimBackground`, `DeviceStage` (`InstrumentSprite`, `CircularDisplay`, `MagicOverlay`, `FixedSelectionCursor`), `MapViewport/MagicMapCanvas`, `DestinationPanel`, and `TravelConfirmLever` directly in the editor. Adjust layout and presentation there; the controller no longer creates these nodes at runtime.

Open `res://day/interactables/map_switch/map_switch_demo.tscn` by itself for visual interaction testing. In normal play, call `AppRoot/GlobalUI/MapSwitchInteraction.open()` from the future world-device interaction.

`MapSwitchInteraction` exposes:

```gdscript
signal travel_requested(destination_id: StringName, destination_data: Dictionary)
signal destination_selected(destination_id: StringName, destination_data: Dictionary)
signal activation_finished

func activate() -> void
func reset_to_dial() -> void
func configure_destinations(new_destinations: Array) -> void
func open() -> void
func close() -> void
```

It is mounted under `AppRoot/GlobalUI`, matching the existing alchemy modal location. `open()` uses the existing per-player physics lock convention and `set_potion_action_locked()`; it also sets the lightweight `day_modal_input_locked` tree metadata that existing day interaction entry points respect.

## FUTURE: REAL SCENE TRAVEL

The only future travel integration point is `AppRoot._on_map_switch_travel_requested()`. Resolve `destination_id` through `GameFlow` / the day runtime there, after saving state and playing the project transition. Do not put scene changing code in this interaction or its lever callback.

### Art alignment to verify in the editor

The source instrument is 1086x1448. The initial alignment constants remain `DEVICE_DISPLAY_CENTER = Vector2(543, 337)`, `DEVICE_DISPLAY_DIAMETER = 424`, and `MAP_VIEWPORT_SIZE = Vector2i(512, 512)`. The modal scales the whole device to `0.42` for the project 1280x720 viewport; only adjust that scale and the first two constants after visual review.
