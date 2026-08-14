# Grassland

The daytime Grassland level is configured by `day/levels/grassland/grass.tscn` and exposed through `day/levels/grassland/grassland_level.tres`.

Its purification completion presentation uses the shared `res://shared/ui/task_complete/task_complete_ui.tscn` scene. The corruption state applies the corrupted texture to every `Sprite2D` named `GrassLoop*`, including future loop sprites added to the scene.

When run as an individual scene, Grassland dynamically attaches `res://night/ui/developer_console/developer_console.tscn` below `DebugUI`; when loaded by `DayRuntime`, it uses the global day console instead. This avoids making `grassland_level.tres` preload the console scene.

Luca's follow-up dialogue receives the current `PlayerData` as the explicit `player_data` dialogue state. Its first interaction uses the `first` title and records `luca_after_purification_seen`; later interactions begin at the short `repeat` title.
