# 安装

1. 将 ZIP 内容直接解压到 Godot 工程根目录，即 `project.godot` 所在目录。
2. 不要创建第二个 `project.godot`。
3. 确认工程已有以下正式接口文件：
   - `res://day/systems/day_level_environment.gd`
   - `res://shared/player/day_player_controller.gd`
   - `res://shared/player/camera_bounds.gd`
   - `res://characters/sherry/sherry_outdoor_collision.tscn`
   - `res://characters/sherry/sherry_presentation.tscn`
   - `res://day/potions/potion_player_system.tscn`
   - `res://characters/luca/luca_player.tscn`
   - `res://day/levels/forest/shared/forest_party_controller.gd`
   - `res://shared/definitions/level_data.gd`
4. 在 `res://day/day_runtime.gd` 的 `LEVELS` 中显式注册 `forest_interior_level.tres`。不要加入 `DAILY_LEVELS`。

推荐写法按你当前 `DayRuntime` 的既有风格合并：

```gdscript
const FOREST_INTERIOR_LEVEL := preload("res://day/levels/forest/interior/forest_interior_level.tres")

# 在现有 LEVELS 字典中加入：
&"forest_interior": FOREST_INTERIOR_LEVEL,
```

Forest 外部树门完成后：

```gdscript
day_runtime.switch_to_level(&"forest_interior", &"from_forest")
```

后续树冠 Boss 场景应注册：

```text
level_id = forest_crown
entry_id = from_interior
```

## 测试

在完整项目根目录运行：

```powershell
& 'C:\Users\jisub\Downloads\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --path . --editor --quit
& 'C:\Users\jisub\Downloads\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe' --headless --path . --script res://tests/forest_interior_smoke_test.gd
```

也可以在编辑器内直接 F6 运行：

`res://day/levels/forest/interior/forest_interior.tscn`

F6 模式下树冠出口只作为结束占位，不会强行切换未安装的 Boss 场景。
