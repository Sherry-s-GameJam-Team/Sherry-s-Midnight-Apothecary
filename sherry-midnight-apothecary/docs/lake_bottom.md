# Lake Bottom (阿里特之泪·湖床)

## Overview
`res://day/levels/lake_bottom/lake.tscn` is a daytime level representing the exposed lakebed of Arit's Tears (*阿里特之泪*).

## Architecture & Integration
- **LevelData**: `res://day/levels/lake_bottom/lake_bottom_level.tres` and `res://day/levels/lake_bottom/gate_chamber_level.tres` registered in `DayRuntime.LEVELS` with disaster name `涸泪之灾`.
- **Level Root**:
  - `LakeLevel` (`res://day/levels/lake_bottom/lake.tscn`) extending `DayLevelEnvironment`.
  - `GateChamberLevel` (`res://day/levels/lake_bottom/gate_chamber.tscn`) extending `DayLevelEnvironment`, representing the interior chamber of the old gate maintenance station (`arit_bg_gate_chamber_01.png`).
- **Player Character**: Standard `Player` (`CharacterBody2D`) equipped with `day_player_controller.gd`, `sherry_outdoor_collision.tscn`, `sherry_presentation.tscn`, and bounded `Camera2D`.
- **UI & Global Systems**:
  - `DeveloperConsole` for debug workflows.
  - `PauseMenuHost` handling `B` key (backpack) and `ESC` (pause/settings).
- Objective HUD for the three-lock gate puzzle.

## Mechanics & Gameplay Flow
1. **Ancient Three-Lock Puzzle**: The three ancient spring valves (`Valve01`–`Valve03`) are activated with `E`. Each activated valve visibly turns and lights up.
2. **Maintenance Portal**: `LakeLevel` counts the three activated valves. Activating the last valve emits `lake_gate_unlocked`, activates `MaintenancePortal` using `arit_gate_maintenance_station_ext_01.png`, and updates the objective HUD. The player can then press `E` to enter `gate_chamber.tscn` at `from_lake`; its central gate returns to `lake.tscn` at `maintenance`.
3. **Day-two Dashiyu task**: `Dashiyu` is present only on day 2 and only until the `lake_bottom_dashiyu_dialogue_completed` event flag is set. Pressing `E` plays `dashiyu.dialogue`; its two dialogue events shake the player camera. On completion, Dashiyu disappears, three `cyan_potion` attack potions are added and equipped, TopHintUI announces the reward, and `DayRuntime.transition_to_level_with_blackout()` moves the player to lake entry `tide_eye_arena`.
4. **Boss-only supports**: `lake.tscn` keeps the lowercase `boss` container hidden outside the `tide_eye_arena` entry. During that entry only, it shows the Dashiyu sprite and activates `BoxGenerator`. The generator creates up to four dynamic, player-pushable `RigidBody2D` boxes using `box.png`; leaving the boss phase hides the support nodes and clears spawned boxes.
5. **Terrain Route**: The lakebed's parallax background, cliffs, ruins, ground art, floor collision, and descent-step collision remain as the exploration route.
