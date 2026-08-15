# Forest Level Pack 安装

将 ZIP 解压到 Godot 项目根目录，使 ZIP 内的 `day/`、`art/`、`tests/`、`docs/` 与项目现有 `res://` 根目录对应。

## 新增主文件

- `res://day/levels/forest/forest.tscn`
- `res://day/levels/forest/forest.gd`
- `res://day/levels/forest/forest_level.tres`
- `res://day/levels/forest/boss/forest_boss_interface.gd`
- `res://tests/forest/forest_smoke_test.tscn`

## 依赖的现有工程资源

这些路径来自 grassland 架构参考包，本 ZIP 不覆盖它们：

- `res://shared/definitions/level_data.gd`
- `res://shared/player/day_player_controller.gd`
- `res://day/potions/potion_player_system.tscn`
- `res://characters/sherry/sherry_presentation.tscn`
- `res://characters/sherry/sherry_outdoor_collision.tscn`
- `res://day/interactables/herb/herb_spawn_director.gd`

如果完整工程实际路径已经调整，以工程当前路径为准修改 Forest 的对应 ext_resource；不要复制第二套 Player 或 Potion 系统。

## Level ID / 入口

- Level ID：`forest`
- 默认入口：`default`
- 额外入口：`from_home`、`restored_return`

`forest_level.tres` 已按 Grassland 的 LevelData 字段创建。由于本次提供的是美术包 + grassland 参考包，而不是完整项目，无法确认项目的 Level Registry 是自动扫描还是手工数组。若工程自动扫描 `day/levels/**/_level.tres`，无需额外操作；若工程使用显式注册表，请把 `res://day/levels/forest/forest_level.tres` 加入现有注册表，禁止新建 Forest 注册器。

## Input

- 角色切换：优先使用 `switch_character`；若项目尚未配置，Forest fallback 接受 `Tab`。
- 交互：优先使用 `interact`；fallback 接受 `E`。
- Luca 移动：优先 `move_left` / `move_right` / `jump`，否则使用 `ui_left` / `ui_right` / `ui_accept`。

建议在项目现有 InputMap 中正式加入 `switch_character = Tab`，但本包没有直接覆盖 `project.godot`，避免误删你工程中的其它 Input Action。

## 测试

完整工程中执行：

```bash
godot --headless --editor --path <project_root> --quit
```

然后：

```bash
godot --headless --path <project_root> res://tests/forest/forest_smoke_test.tscn
```

Godot 4.6.x 首次导入大量 PNG 后，建议先完成一次 editor/headless import，再跑 smoke test。

## Boss placeholder

Boss 只有 Trigger + Interface + corrupted/normal 视觉。未来正式 Boss 脚本调用：

```gdscript
$BossInterface.begin_boss()
$BossInterface.purify_boss()
```

`purify_boss()` 会完成 Forest 恢复，不会击杀熾天使。

## Checkpoint

树门开启后写 `PlayerData.tutorial_flags["forest_tree_gate_opened"] = true`，并调用 `request_checkpoint(&"forest_tree_gate_opened")`。如果现有 DayRuntime 已提供同名 checkpoint 方法会自动转发，否则通过 Forest 的 `checkpoint_requested` signal 暴露。

## Luca

参考包未包含完整工程中的正式可操控 Luca 场景，所以本包带一个 Forest-local fallback controller 以保证节点与流程完整。接入完整项目后，优先复用项目已有 Luca Presentation/控制器并保留 `set_control_enabled(bool)` 兼容入口。
