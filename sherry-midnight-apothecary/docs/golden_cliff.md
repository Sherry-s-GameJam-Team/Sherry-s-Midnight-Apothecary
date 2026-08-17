# Golden Cliff（烁金横崖）— standalone day level

`res://day/levels/golden_cliff/` is a standalone day level under the `DayRuntime`
architecture. The pack keeps its own scenes, scripts, and art inside the folder; it creates no nested Godot project, Autoload, event bus, or persistent cross-scene references.

## Deployment status

Registered in `DayRuntime.LEVELS` in `res://day/day_runtime.gd`. Deployment steps are documented in `day/levels/golden_cliff/README_DEPLOY.md`.

## Global console (DeveloperConsole)

The standalone DeveloperConsole is embedded directly in `golden_cliff.tscn`:

- `DebugUI` — `CanvasLayer`, `layer = 200` (above gameplay).
- `DebugUI/DeveloperConsole` — instanced from `res://night/ui/developer_console/developer_console.tscn`.

`day_level_environment.gd` (the scene root) keeps the embedded console active in standalone runs and disables it when the level runs under `DayRuntime` (which owns its own console layer).

## Title UI (SceneTitleCard)

`golden_cliff.tscn` registers `golden_cliff_level.tres` in `DayRuntime.LEVELS`; DayRuntime presents the global `SceneTitleCard` using that resource's `disaster_name` (`断衡之灾`) / `normal_description` (`重力失序的断崖恢复了稳定与宁静`).

## B-key backpack & ESC pause menu

The global `PauseMenu` (`res://night/ui/pause_menu/pause_menu.tscn`) is embedded in `golden_cliff.tscn` via `PauseMenuLayer` with `pause_menu_host.gd` for standalone runs.

## LevelData

`day/levels/golden_cliff/golden_cliff_level.tres`:

- id: `golden_cliff`, display name `烁金横崖`
- disaster: `断衡之灾` (corrupted by default, `start_corrupted = true`)
- default entry: `EntryPoints/default`; extra entries: `from_south`, `from_lake`
- exit portal: `home/default` via `DoorPortal` (goes through `DayRuntime.switch_to_level()`)
- content scene: `golden_cliff.tscn`, root script `day_level_environment.gd`

## Balance Mechanisms & Dual-Pan Weight System（衡石机关二次配置）

The balance stones operate as physical dual-pan weighing scales with beam tilt dynamics, visual stone stacking, indicator needle-to-notch alignment, and environmental linkages:

### Structure & Hit Detection
- `BalanceMechanism` (`balance_mechanism.gd`)
  - `Base`: Fixed sandstone pedestal.
  - `BeamPivot`: Central rotating fulcrum node.
    - `Beam`: Horizontal balance beam.
    - `LeftPan` (`left_hit_area` with `pan_hit_receiver.gd`, `side = &"left"`): Left weight container and hit area.
    - `RightPan` (`right_hit_area` with `pan_hit_receiver.gd`, `side = &"right"`): Right weight container and hit area.
  - `CenterIndicator`: Needle / pointer rotating with the beam pivot.
  - `TargetIndicator`: Target notch displaying the required tilt angle for resolution.
  - `ResetArea` & `ResetHint`: Base interaction area for resetting weights via `E` key or hit.

### Weight Calibration & Dynamics
- Direct potion hits on LeftPan add 1 weight to `left_weight` (capped at `max_weight = 4`).
- Direct potion hits on RightPan add 1 weight to `right_weight` (capped at `max_weight = 4`).
- Procedural sandstone blocks (`Polygon2D`/`Line2D`) dynamically render in each pan representing the current weight.
- Beam rotation smoothly tweens:
  $$\text{target\_rotation} = \frac{\text{right\_weight} - \text{left\_weight}}{\text{max\_weight}} \times \text{max\_tilt\_angle}$$
- When `left_weight == target_left_weight` and `right_weight == target_right_weight`, a 0.6-second stability delay occurs before calling `_stabilize()`.
- Mechanism completion produces a 0.15s gentle shake, elastic beam alignment, pointer/notch golden glow, expanding `Line2D` ripple wave, falling sandstone particles, and emits `stabilized(mechanism_id)`.
- Resetting: Approaching the central base and pressing `E` (or calling `reset_balance()`) restores initial weights and tweens the beam back to initial position without penalty.

### Three Distinct Balance Configurations & Terrain Linkages
1. **`west_balance`** (`target_left_weight = 2`, `target_right_weight = 2`):
   - Educational symmetry puzzle (both sides equal weight).
   - **Linkage**: Western floating boulders (`BoulderA`, `BoulderB`) transition from `FloatState.UNSTABLE` (amplitude 18px, wobble rotation ±2°, high speed) to `FloatState.STABLE` (amplitude 3px, rotation 0°, low speed), forming a stable crossing path.
2. **`middle_balance`** (`target_left_weight = 1`, `target_right_weight = 3`):
   - Asymmetrical balance puzzle (right pan naturally heavier, requiring pointer to match target notch).
   - **Linkage**: A tilted sandstone bridge (`SlopeA`) smoothly tweens its rotation to horizontal level (0.0°), bridging the chasm.
3. **`east_balance`** (`target_left_weight = 3`, `target_right_weight = 2`):
   - Complex asymmetrical calibration puzzle (left pan heavier).
   - **Linkage**: Eastern floating boulders (`BoulderC`, `BoulderD`, `ExitPlatform`) transition to stable state and lower to reachable jumping height before the exit portal.

### Portal Restoration
- `GoldenCliffController` (`golden_cliff_controller.gd`) tracks all three mechanism states.
- The exit portal remains inactive and disabled until all 3 mechanisms are stabilized.
- Upon completing all three puzzles, a 2.5s restoration sequence plays:
  1. Door vibration
  2. Three golden light orbs converge to the socket
  3. Rotating `Line2D` energy rings
  4. Yellow energy fill inside the portal
  5. Upward drifting golden sparks
  6. Portal collision, visual, and interaction unlock.

## Village Scene（涟汀村 / 倒悬码头）

`res://day/levels/golden_cliff/village/village.tscn`（关卡定义：`res://day/levels/golden_cliff/village/village_level.tres`，`id = &"golden_cliff_village"`，展示名“涟汀村”，常设 Normal 避风村落模式）：

- **3-Layer Parallax Architecture**:
  - **FS (`z_index = -30`, `scroll_scale = (0.05, 0.03)`)**: `background.png` 缩放至 `scale = 1.75` + 镜像对称无缝循环（Normal + Mirrored，单循环单元宽 `13258px`，`repeat_size = (13258, 0)`，保持沉稳低视差倍率）。
  - **MS (`z_index = -15`, `scroll_scale = (0.55, 0.55)`)**: `倒悬船坞.png` (中景倒悬船坞构装) + `空崖码头.png` (中景码头栈桥).
  - **CS (`z_index = -5`, `scroll_scale = (0.9, 0.9)`)**: `涟汀村近景.png` (近景前景村落平台与民居) + `湖祭石阶.png` (近景石阶台阶) + `大司鱼观潮台.png` (近景巨型观潮台构筑) + `WorldBounds` 物理碰撞体（`Ground` 实地位于 Collision Layer 1，`OneWayPlatforms` 单向平台位于 Collision Layer 2，支持 S 键下穿）。
- **Core Integration**:
  - `Player`: `DayPlayerController` + `SherryCollision` + `SherryPresentation` + `PotionThrower` + `Camera2D` (跟踪界限设置为 `limit_left = -1118`, `limit_top = -1389`, `limit_right = 8550`, `limit_bottom = 803`，完整覆盖所有 Ground 碰撞多边形范围)。
  - `DebugUI`: Layer 200 `DeveloperConsole`.
  - `PauseMenuLayer`: Layer 200 `PauseMenu` with `pause_menu_host.gd`.
  - `WorldBounds` & `EntryPoints`: `default`, `from_cliff`, `from_lake`, and `ExitPortal` (`DoorPortal` to `home`)。

## Validation

Run the dedicated smoke tests:

```powershell
godot --headless --path . --script res://day/levels/golden_cliff/golden_cliff_smoke_test.gd
godot --headless --path . --script res://tests/village_smoke_test.gd
```

