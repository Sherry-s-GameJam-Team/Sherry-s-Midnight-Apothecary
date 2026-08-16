# 烁金横崖（golden_cliff）部署说明

本目录是 `DayRuntime` 架构下的独立白天关卡。资源与关卡脚本均局部放在本目录，不创建新的 `project.godot`、Autoload、全局事件总线或持久跨场景引用。

## 部署

本场景已部署到 `res://day/levels/golden_cliff/`，并已在 `res://day/day_runtime.gd` 的 `LEVELS` 中追加注册：

```gdscript
preload("res://day/levels/golden_cliff/golden_cliff_level.tres"),
```

本场景默认不加入 `DAILY_LEVELS`。如果后续需要进入每日轮换，再显式追加。

### 全局控制台（DeveloperConsole）与标题 UI（SceneTitleCard）

- 控制台：`golden_cliff.tscn` 内嵌 `DebugUI` CanvasLayer（`layer = 200`）+ `DeveloperConsole`
  实例（`res://night/ui/developer_console/developer_console.tscn`），与 lake/lakebed/raintree/town 的独立关卡模式一致；
  `day_level_environment.gd` 在 DayRuntime 下自动禁用内嵌控制台。
- 标题 UI：场景内**不**内嵌 `SceneTitleCard`；通过 `LEVELS` 注册 + `show_title_card = true`
  由 DayRuntime 用 `golden_cliff_level.tres` 的灾难名/描述呈现全局标题卡。

## 场景信息

- LevelData id：`golden_cliff`
- 显示名：`烁金横崖`
- 灾难：`断衡之灾`
- 默认状态：腐化 `start_corrupted = true`
- 默认入口：`EntryPoints/default`
- 额外入口：`from_south`、`from_lake`
- 终点旅门：默认返回 `home/default`

## 核心玩法

1. 横崖被黄色灵脉的“断衡”污染，岩石重量失常。
2. 关卡包含浮岩、坍塌平台和深渊坠落伤害。
3. 三座衡石机关均为 `StaticBody2D`，实现 `receive_potion_hit(hit)`；任意直接瓶击可进行一次校准，每座需要两次直接命中。
4. 三座衡石全部稳定后，根 `DayLevelEnvironment` 被切换为非腐化状态，终点旅门开放。
5. 旅门通过项目既有 `DoorPortal` 进入 `home/default`，不会绕过 `DayRuntime.switch_to_level()`。

## Godot 原生特效

本包没有额外序列帧特效图：

- 浮岩：`AnimatableBody2D` + 正弦运动。
- 坍塌：`Area2D` 预警 + Tween 抖动/下坠。
- 碎石/尘埃：运行时创建 `Polygon2D` 并用 Tween 扩散、淡出。
- 衡石命中：运行时 `Line2D` 环形冲击反馈。
- 旅门修复：运行时 `Line2D` 扩散环 + `Polygon2D` 火花。
- 背景：Godot `Parallax2D` 原生视差。

## 依赖的项目既有接口

- `res://day/systems/day_level_environment.gd`
- `res://day/systems/door_portal.gd`
- `res://shared/player/day_player_controller.gd`
- `res://shared/player/camera_bounds.gd`
- `res://characters/sherry/sherry_outdoor_collision.tscn`
- `res://characters/sherry/sherry_presentation.tscn`
- `res://day/potions/potion_player_system.tscn`
- `res://shared/definitions/level_data.gd`

## 验证

从项目根目录：

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/golden_cliff_smoke_test.gd
```

若你的 Godot 可执行文件不是环境变量中的 `godot`，替换为 Godot 4.6 console executable 的绝对路径。

注：`tests/golden_cliff_smoke_test.gd` 会实例化本场景，断言内嵌 DebugUI/DeveloperConsole
接线，并断言 `golden_cliff` 已注册进 `DayRuntime.LEVELS` 且标题卡数据齐备。全量
`res://tests/run_tests.gd` 当前因 `home_travel_routing_test.gd` 一处已提交的类型推断
解析错误（`var map_controller := load(...).new()`）在头部即中断，与本次部署无关。
