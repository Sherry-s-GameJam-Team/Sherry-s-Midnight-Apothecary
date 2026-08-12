# Sherry’s Midnight Apothecary / 雪莉的午夜药水铺

<!-- PROJECT_ARCHITECTURE_START -->
## 项目结构

项目采用直接的“白天 / 夜晚”双运行时结构：

```text
res://
├── app/       AppRoot 与最小 GameFlow
├── shared/    共享主角数据、昼夜结果、存档和五类静态数据
├── day/       白天探索运行时及关卡功能
├── night/     夜间炼药与商店运行时
├── art/
├── audio/
├── tests/
└── docs/
```

`AppRoot` 在游戏运行期间持续存在，并创建唯一的 `PlayerData`。`GameFlow` 将同一个 `PlayerData` 实例依次传给 `DayRuntime` 和 `NightRuntime`：

```text
PlayerData
   ├── DayRuntime → DayResult
   └── NightRuntime → NightResult
```

白天结束后应用 `DayResult` 并进入夜晚；夜晚结束后应用 `NightResult`、请求存档并进入下一天。第 30 天夜晚结束后进入 `ENDING`。

本项目刻意不建立复杂世界状态、事件总线、数据注册中心或额外场景切换服务。静态内容直接使用 `shared/definitions/` 中的 Resource，由需要它的场景显式引用。

### 验证

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
```
<!-- PROJECT_ARCHITECTURE_END -->

