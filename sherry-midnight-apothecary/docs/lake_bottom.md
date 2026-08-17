# Lake Bottom (阿里特之泪·湖床)

## Overview
`res://day/levels/lake_bottom/lake.tscn` is a daytime level representing the exposed lakebed of Arit's Tears (*阿里特之泪*).

## Architecture & Integration
- **LevelData**: `res://day/levels/lake_bottom/lake_bottom_level.tres` and `res://day/levels/lake_bottom/gate_chamber_level.tres` registered in `DayRuntime.LEVELS` with disaster name `涸泪之灾`.
- **Level Root**:
  - `LakeLevel` (`res://day/levels/lake_bottom/lake.tscn`) extending `DayLevelEnvironment`.
  - `GateChamberLevel` (`res://day/levels/lake_bottom/gate_chamber.tscn`) extending `DayLevelEnvironment`, representing the interior chamber of the old gate maintenance station (`arit_bg_gate_chamber_01.png`).
- **Player Character**: Standard `Player` (`CharacterBody2D`) equipped with `day_player_controller.gd`, `sherry_outdoor_collision.tscn`, `sherry_presentation.tscn`, `potion_player_system.tscn`, and bounded `Camera2D`.
- **UI & Global Systems**:
  - `DeveloperConsole` for debug workflows.
  - `PauseMenuHost` handling `B` key (backpack) and `ESC` (pause/settings).
  - Objective HUD and Springburst/Cyan potion charge indicator.

## Mechanics & Gameplay Flow
1. **Investigation & Potion Acquisition**:
   - Approaching `MaintenanceStation` on the lakebed displays an interaction prompt `按[E]进入旧旅门维护站` (`ChamberEntrance`), smoothly transitioning the player into the interior chamber scene (`gate_chamber.tscn`).
   - In the interior chamber, the central glowing portal (`CentralGateDoor`) links directly back to the lakebed's maintenance station marker (`maintenance`).
   - Discovering Dashiyu triggers `DashiyuFound`, granting cyan potions directly into the player's inventory/hotbar via `PlayerData`.
2. **Ancient Valve Puzzle**: Three ancient spring valves (`SpringValve`) must be activated via interact (`E`) to restore power to the Purification Lance.
3. **Player Potion Throwing (Baiting)**:
   - Instead of static `E`-key interaction prompts, the player directly aims and throws cyan/water potions using the core `PotionThrower` mechanism (left-click drag & release).
   - Direct projectile collisions and splash effects on `TideEye` or the bait target zones (`receive_potion_hit` / `apply_potion_effect`) trigger water splashing FX and lure `TideEye` out to expose its core.
4. **Purification Lance**: Player operates the powered lance turret (`E` to interact, `←`/`→` to aim, `E` to fire beam) to strike the exposed `TideEye` core.
5. **Restoration**: After 3 successful purification hits, `TideEye` is defeated, the sunken gate (`GateRestored`) is restored, and the level completes.


