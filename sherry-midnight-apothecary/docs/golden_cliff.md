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
- default entry: `EntryPoints/default`; extra entries: `from_home`, `from_south`, `from_village`, `from_lake`
- entrance portal: `Gameplay/EntrancePortal` via `DoorPortal` (`destination_level = &"home"`, `destination_entry_id = &"from_cliff"`, linked to Map Switch Anchor 3 / `golden_cliff`)
- exit portal: `Gameplay/ExitPortal` via `DoorPortal` (`destination_level = &"home"`, unlocked after 3 balance mechanisms are stabilized)
- map anchor linkage: `res://day/interactables/map_switch/data/map.tscn` Anchor03 (`destination_id = &"golden_cliff"`)
- content scene: `golden_cliff.tscn`, root script `day_level_environment.gd`

## Balance Mechanisms & Dual-Pan Weight System（衡石机关二次配置）

The balance stones operate as physical dual-pan weighing scales with beam tilt dynamics, visual stone stacking, indicator needle-to-notch alignment, and environmental linkages:

All six fixed sections under `Gameplay/StaticPlatforms` (`StartGround`, `GroundA`, `SlopeA`, `GroundB`, `GroundC`, and `EndGround`) also drift horizontally by 5px on staggered, low-speed sine waves. Their collision surfaces move with the visual floor; floating boulders and collapsible platforms retain their separate motion behavior.

`BreakA` retains its original `Body/CollisionShape2D` and `Sensor/CollisionShape2D` hierarchy, but has no behavior or position-driving script. It begins at `(4509, -500)`, above the camera's upper boundary. `BalanceC` has one slot on each pan (`max_weight = 1`) and resolves at left `1` / right `0`. While empty and unsolved, its beam is visually tilted +18° (left high, right low) to communicate the missing left weight; the visual tilt does not add a hidden weight. BalanceC's direct `weight_changed` connection reveals BreakA immediately when that `1:0` state is reached; its `stabilized` connection remains as an idempotent fallback. The entire node, including its collision boxes, moves to the editable `LevelController.break_a_resolved_position` target, currently `(4509, 743)`.

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
   - The scale starts at `left = 0`, `right = 2`, so its left side is raised by two weights. The player restores it by adding two weights to the left pan.
   - **Linkage**: Western floating boulders (`BoulderA`, `BoulderB`) follow the scale in real time. While the two pans differ, A rises 750px, B sinks 500px, and both use 2.4× motion amplitude/rotation. Equal but unresolved weights return them to their normal unstable height; the final `2:2` calibration changes both to `FloatState.STABLE` (amplitude 3px, rotation 0°, low speed), forming a stable crossing path.
   - **Approach linkage**: `StartGround` continuously follows the western balance's right-minus-left weight difference. The initial `0:2` state leaves the scale's left side high and right side low, so the platform starts at a clockwise +39°; it moves to +19.5° after the first left weight (`1:2`) and reaches 0° at `2:2`. Resetting or overshooting updates its signed incline in the same way, including its collision surface.
   - The beam, pan, hit-area, and procedural-weight anchors are corrected for the transparent margins in the source textures so the weights sit on the visible pan surfaces.
   - **HintUI guidance**: Entering a balance stone's reset area shows a persistent `TopHintUI` prompt with the remaining left/right weights and its target. The text refreshes after each bottle hit or reset, and hides on exit or stabilization.
2. **`middle_balance`** (`target_left_weight = 1`, `target_right_weight = 3`):
   - Asymmetrical balance puzzle (right pan naturally heavier, requiring pointer to match target notch).
   - **Linkage**: The tilted sandstone bridge (`SlopeA`) and GroundB's initial clockwise 30° incline both smoothly tween to horizontal level (0.0°), bridging the chasm.
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
  - `Mew`: `MewNPC` (`res://characters/mew/mew_npc.gd`) 钓鱼喵斯交互节点。具备正反循环往复循环播放（Ping-Pong Loop，帧数 0..39..0 无缝循环），并集成 `Area2D` 靠近感应与按 `E` 触发 `res://characters/mew/mew.dialogue` 对话功能。玩家进入感应范围时，提示文字通过共享 `TopHintUI`/HintUI 的 `show_interaction_hint()` 显示；离开范围、开始对话或卸载场景时使用同一 hint id 清除，不创建跟随世界坐标的独立 Label。对话流支持 4 项分支问询追踪（村长、村子、父亲失踪、涌水药水与纤绳机），全部问询完成后平滑进入常驻 `question_menu`。对话中喵斯/炉边烤鱼的少女固定使用左侧槽位，雪莉固定使用右侧槽位；喵斯会按台词在 `default`、`avert`、`dumb`、`wink` 与 `exp2_default` 差分之间切换。该角色和 `issues` 仅在第 2 天出现；6 个 `CS/rope/R1` 至 `R6` 可在靠近时高光并按 E 收集，每盘会持久计入 `village_rope_spool`。玩家从左向右穿过 `issues/down` 时，未完成订单优先显示“请先交付订单给顾客”；订单完成但少于 5 盘纤绳时显示“目前还差 N 盘纤绳”；满足两项前置后显示 `CS/saved/IdleLoop` 并由 `village_day_two_down` 事件进入该对话资源的 `question_menu`。

  - **第 3 天丹枫驿航程**：`issues` 与 `CS/rope` 会完全隐藏；旧喵斯节点会关闭感应、E 键输入和遗留 HintUI，故不会留下交谈提示或触发对话。`CS/saved` 的船保持显示。`day3/to Red` 是 E 键交互区；大司鱼询问是否前往绯红峡谷，选择“是”会切入独立的 `village_red_voyage.tscn`。该场景将可编辑的雪莉/大司鱼乘员与船只放在 `BoatGroup` 下，让村庄远景向左移动 5 秒，再渐隐转入 `crimson_vale/from_village`；丹枫驿到达对白随后播放一次。
  - `DebugUI`: Layer 200 `DeveloperConsole`.
  - `PauseMenuLayer`: Layer 200 `PauseMenu` with `pause_menu_host.gd`.
  - `WorldBounds` & `EntryPoints`: `default`, `from_cliff`, `from_lake`, and `ExitPortal` (`DoorPortal` to `golden_cliff` at `from_village`; fallback scene: `golden_cliff.tscn`). Its inactive visual uses `cliff_yellow_gate_wayportal_01.png`.
  - The left-side village exit and `Gameplay/VillagePortal` form a reciprocal route: the village portal arrives at `GoldenCliff/EntryPoints/from_village`, and the Golden Cliff portal returns to `Village/EntryPoints/from_cliff`. Both use `DoorPortal`, which calls `DayRuntime.transition_to_level_with_blackout()` for the close-range black fade transition.

## Validation

Run the dedicated smoke tests:

```powershell
godot --headless --path . --script res://day/levels/golden_cliff/golden_cliff_smoke_test.gd
godot --headless --path . --script res://tests/village_smoke_test.gd
```
