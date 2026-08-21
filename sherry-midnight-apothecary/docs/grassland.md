# Grassland

The daytime Grassland level is configured by `day/levels/grassland/grass.tscn` and exposed through `day/levels/grassland/grassland_level.tres`.

Grassland opens as the day-zero corruption scene (`start_corrupted = true`). Its purification completion presentation uses the shared `res://shared/ui/task_complete/task_complete_ui.tscn` scene. The corruption state applies the corrupted texture to every `Sprite2D` named `GrassLoop*`, including future loop sprites added to the scene. It also reveals the fixed `CorruptedHorizon` parallax layer, `Foreground/HoleLeft` / `HoleRight`, and the `Trapezoid`; all stay hidden in the normal state.

When run as an individual scene, Grassland dynamically attaches `res://night/ui/developer_console/developer_console.tscn` below `DebugUI`; when loaded by `DayRuntime`, it uses the global day console instead. This avoids making `grassland_level.tres` preload the console scene.

Only on day 0, after Luca's purification tutorial records `sleeping_hound_purification_complete`, the Grassland HomeDoor presents the confirmation warning — “进入药水铺将开启晚间营业，请确保资源收集完毕” — and confirmation emits a completed `DayResult` through `DayRuntime`, which moves `GameFlow` into `NightRuntime`. On every later day the same door uses the ordinary daytime Home destination, regardless of the persisted Luca-task flag. Before the day-zero Luca-task flag is set, including after the Emerald Field miasma purification alone, the door also keeps its ordinary daytime Home destination. Cancelling the day-zero confirmation keeps the player in Grassland to continue collecting resources.

Luca's follow-up dialogue receives the current `PlayerData` as the explicit `player_data` dialogue state. Its first interaction uses the `first` title and records `luca_after_purification_seen`; later interactions begin at the short `repeat` title.

`SleepingHoundNPC` is present only on day 0. On that day, `HomeDoor` is locked until the player has finished the hound's first dialogue; completion stores `grassland_hound_dialogue_seen` in `PlayerData.tutorial_flags`, so returning to the scene does not re-lock the door. On later days the hound is hidden and the door has no hound-dialogue prerequisite.

The `issues/dialog1` marker is backed by `issues/Dialog1Trigger`, a one-time 256×192 crossing area that plays `dialog1.dialogue` and records `grassland_dialog1_seen` in `PlayerData.tutorial_flags`. Its `grassland_dialog1_board` event locks input, walks Sherry onto `Trapezoid`, then shakes and briefly suspends the platform while her “？！” line is on screen. `grassland_dialog1_launch` then carries her above the frozen camera frame and enters the `emerald_field` level.

## Emerald Field platform level

`res://day/levels/grassland/level.tscn` is the separately deployable Emerald Field traversal level, exposed to `DayRuntime` as `emerald_field` by `emerald_field_level.tres`. Its packaged source art and hazard scripts live under `res://day/levels/grassland/emerald_field/`; the original PNG files are preserved without replacing the existing Grassland art.

The scene contains the package's 18 static, moving, and collapsing platforms, two poison-gas regions, the fall reset zone, and the old-travel-gate goal. The standalone `DemoPlayer` was removed. `Player` uses the production `res://shared/player/day_player_controller.gd`, Sherry outdoor collision and presentation scenes, potion player system, and a level-limited `Camera2D`. `EntryPoints/default` and `PlayerSpawn` share the same position so DayRuntime entry and hazard respawn agree.

Run the level directly with:

```powershell
godot --path . res://day/levels/grassland/level.tscn
```

Use A/D or the arrow keys to move, W/Z/Up to jump, and Shift to run. Falling below the route or remaining in poison gas too long fades out, resets the packaged hazards, and returns Sherry to `PlayerSpawn` using the production controller's existing input-lock interfaces.

## Miasma purifier finale

At the Emerald Field `Goal`, press `E` to open `res://minigames/minigames/miasma_purifier/scenes/miasma_purifier_osu_minigame.tscn`. The player remains at the interaction point while the purifier takes control of the camera and input. Click each shrinking purification anchor at the correct moment; 20 consecutive hits complete the cleansing, while misses reset the combo.

On success, `emerald_field_miasma_cleared` is saved in `PlayerData.tutorial_flags`, the minigame closes at the original Goal position, and the camera shakes. `DayRuntime` then holds a full-screen black transition across the level switch and spawns Sherry at Grassland `EntryPoints/level_completed`. That completion entry is a one-time pending return and is cleared immediately after use; later travel uses its ordinary `default` entry. The Grassland environment reads the persistent cleared flag at startup and enters its normal state. The transition releases the modal input lock only after the new level is in place. A saved cleared flag disables the Goal on later Emerald Field loads.

Deployment checks can be run independently with:

```powershell
godot --headless --path . --script res://tests/run_emerald_field_test.gd
```
