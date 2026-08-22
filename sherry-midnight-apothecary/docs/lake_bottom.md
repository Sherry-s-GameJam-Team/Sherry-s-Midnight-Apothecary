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
2. **Maintenance Portal and Anchor 04**: `LakeLevel` counts the three activated valves. Activating the last valve emits `lake_gate_unlocked`, activates `MaintenancePortal` using `arit_gate_maintenance_station_ext_01.png`, and updates the objective HUD. The story portal enters `gate_chamber.tscn` at `from_lake`. After the boss is completed, map Anchor 04 (`潜息门`) targets `gate_chamber/from_home`; its central gate always returns to `home`, so normal travel is 药典屋 → 潜息门 → 药典屋 rather than returning to the lakebed.
3. **Day-two Dashiyu task**: `Dashiyu` is present only on day 2 and only until the `lake_bottom_dashiyu_dialogue_completed` event flag is set. Pressing `E` plays `dashiyu.dialogue`; its two dialogue events shake the player camera. On completion, Dashiyu disappears, three `cyan_potion` attack potions are added and equipped, TopHintUI announces the reward, and `DayRuntime.transition_to_level_with_blackout()` moves the player to lake entry `tide_eye_arena`.
4. **噬潮眼 Boss 战**: `lake.tscn` keeps the lowercase `boss` container hidden outside the `tide_eye_arena` entry. `TideEye` has no texture, SpriteFrames, or Shader: its breathing black-hole body, rotating arcs, cyan turbulence, and exposed core are drawn in `tide_eye.gd` with `_draw()` as a vertically compressed ellipse at the potion's ground-impact position. A cyan potion must first strike upward-facing ground; it then waits a random 0.35–1.1 seconds, shakes the camera, and opens at that landed position. The 4.2-second window accepts exactly one damage from either a `box.png` push box or a purification potion. Three hits win. During an opening it pulls Sherry and boxes inward; reaching the mouth removes 10 HP, ejects Sherry to a safe position, and grants a short per-player cooldown.
5. **Boss-only supports and ending**: During `tide_eye_arena` only, the boss container shows Dashiyu and activates `BoxGenerator`. The generator immediately creates a dynamic, player-pushable `RigidBody2D` box, replenishes every five seconds to a maximum of four, and clears all generated boxes on phase exit or victory. The third hit persists `lake_bottom_tide_eye_defeated`, unlocks `gate_chamber` as a travel anchor, then runs the script-drawn rising-water/boat departure sequence and its short dialogue. A blackout transfers to `golden_cliff_village/from_lake`, the village's right-side dock entry.
6. **Terrain Route and camera alignment**: The maintenance-station art is permanently visible; only its portal interaction is hidden until the three valves are opened. Once all valves are active, their prompts and interaction collision are disabled. The Sky and FarBasin retain parallax, while the near `MidLakebed` layer is 1:1 with the camera and Lake's camera smoothing is disabled. Near ground art, collision, and editor placement therefore remain aligned in play mode.
