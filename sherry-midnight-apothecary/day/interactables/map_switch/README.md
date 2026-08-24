# Magic Map Switch

Reusable day-mode modal interaction. It renders `MagicMapCanvas` to a 512x512 `SubViewport`; `CircularDisplay` samples that live texture and uses `dial_to_map.gdshader` for the circular mask and dial-to-map dissolve.

The authored scene exposes `DimBackground`, `DeviceStage` (`InstrumentSprite`, `CircularDisplay`, `MagicOverlay`, `FixedSelectionCursor`), `MapViewport/MagicMapCanvas`, `DestinationPanel`, and `TravelConfirmLever` directly in the editor. Adjust layout and presentation there; the controller no longer creates these nodes at runtime.

The live map is the authored `data/map.tscn` scene. Its ten zero-based `Map/AnchorPoints/Anchor00` through `Anchor09` nodes are `MapSwitchAnchor` nodes: drag them in the 2D editor to position destinations, then edit each node's `destination_id`, `display_name`, subtitle, danger, distance (shown to players as **盛产作物**), environment, description, `unlock_day`, and optional completion flag in the Inspector. Crop text mirrors the destination LevelData/scene's authored harvestables; scenes without harvest points show **无可采作物**.

The authored activation schedule is Day 0 流明街/翡翠原, Day 1 阿尔维斯母树, Day 2 归潮门 plus the post-Tide-Eye 潜息门, Day 3 post-Alkeon 丹心门, Day 4 morning 钟塔门, Day 5 post-Director 眠村, and Day 6 王畿/王座之间. A scheduled anchor becomes confirmable only when the current internal day and its optional `event_flags`/`tutorial_flags` requirement both pass. Confirming it records the destination in `PlayerData.unlocked_levels` before the existing Home route-lock signal is emitted.

The authored map starts at 2x zoom. Once activated, use the mouse wheel inside the circular display to zoom (0.5x–4x) and WASD to pan the map; these controls affect only the modal map.

On the first Home use of the Transformer, activating the live map shows a persistent TopHint that teaches mouse dragging and WASD map movement. The hint remains until a route anchor is snapped to the fixed center cursor, then stores `home_transformer_map_alignment_completed` in `PlayerData.tutorial_flags`; completed saves never show it again.

The purple circular **Activate** control lives at the bottom of `DestinationPanel`. While dormant, the panel shows only **设备未激活** and this control. It fades out as the device powers up; destination details return after activation, and the control is restored whenever the interaction returns to its dormant dial state.

`Bg` is part of the activation composition: it scales by the same ratio as `DeviceStage` during the dial-to-map transition, then returns to its authored scale when reset.

Before a route is locked, the destination panel shows only the two-line **未锚定节点** mouse/WASD alignment instruction, rendered in centered Microsoft YaHei at half the authored title size. Locking a route restores the destination details and its authored font configuration.

## Home travel routing

`Anchor00` is the Town destination (`market`); `Anchor01` is Grassland (`grassland`). Confirming an available anchor emits `destination_locked`, writes `PlayerData.active_home_destination_id`, and closes the Transformer—it does not change levels immediately. The Home exterior door calls `DayRuntime.travel_from_home()`, which enters the locked level at `EntryPoints/from_home`.

Grassland's `HomeDoor` wraps the existing `Door` sprite and returns through Home's `EntryPoints/from_grass` marker.

`PlayerData.unlocked_levels` remains the persistent route list; Town and Grassland are unlocked by default. Authored map anchors additionally enforce their day/completion schedule and persist themselves when first confirmed. Other objective-driven routes can still call `DayRuntime.activate_travel_anchor(level_id)` (or set `DayResult.unlocked_level_id` before `finish_day`). Inactive anchors still show their details, but the **确认锁定** button is disabled and grey.

Open `res://day/interactables/map_switch/map_switch_demo.tscn` by itself for visual interaction testing. In normal play, call `AppRoot/GlobalUI/MapSwitchInteraction.open()` from the future world-device interaction.

`map_switch_interaction.tscn` is also directly runnable for layout preview. It remains hidden only on the `AppRoot/GlobalUI` instance, so normal gameplay still requires `open()`.

`MapSwitchInteraction` exposes:

```gdscript
signal destination_locked(destination_id: StringName, destination_data: Dictionary)
signal destination_selected(destination_id: StringName, destination_data: Dictionary)
signal activation_finished

func activate() -> void
func reset_to_dial() -> void
func configure_destinations(new_destinations: Array) -> void
func open() -> void
func close() -> void
```

It is mounted under `AppRoot/GlobalUI`, matching the existing alchemy modal location. `open()` uses the existing per-player physics lock convention and `set_potion_action_locked()`; it also sets the lightweight `day_modal_input_locked` tree metadata that existing day interaction entry points respect.

## Home door integration

`AppRoot._on_map_switch_destination_locked()` validates and persists the selected route. The Home door is the only component that calls `DayRuntime.travel_from_home()`. Do not put direct scene switching in this interaction or its lever callback.

### Art alignment to verify in the editor

The source instrument is 1086x1448. The initial alignment constants remain `DEVICE_DISPLAY_CENTER = Vector2(543, 337)`, `DEVICE_DISPLAY_DIAMETER = 424`, and `MAP_VIEWPORT_SIZE = Vector2i(512, 512)`. The modal scales the whole device to `0.42` for the project 1280x720 viewport; only adjust that scale and the first two constants after visual review.
