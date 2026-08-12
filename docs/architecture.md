# 简化架构

## 三个核心对象

- `AppRoot`：运行期持续存在，创建共享 `PlayerData`、`SaveService` 和 `GameFlow`。
- `GameFlow`：只管理当前天数、白天/夜晚/结局切换，以及应用昼夜结果。
- `PlayerData`：白天和夜晚共同持有的同一个主角数据实例。

`GameFlow` 直接把 `DayRuntime` 或 `NightRuntime` 实例化到 `AppRoot/CurrentRuntime`。因此不需要额外的 SceneFlow 服务。

## 明确不建立的系统

- 不建立全局世界状态或复杂 `GameSession`。
- 不建立事件总线。
- 不建立数据注册中心。
- 不保存跨场景世界节点引用。
- 不扫描文件系统自动发现 Resource。

五类静态数据放在 `shared/definitions/`，由使用它们的场景或脚本显式引用。

## 目录结构

```text
app/                        # AppRoot、GameFlow
characters/                 # 角色场景 + 精灵帧（sherry、luca、mew、npcs）
shared/
  core/                     # PlayerData、SaveService、DayResult、NightResult
  player/                   # day_player_controller、camera_bounds（全角色共用）
  definitions/              # 静态 Resource（ingredients、potions、heat_profiles…）
  potions/                  # 药水运行时、调参、UI
  shaders/                  # interaction_outline 等共用着色器
  ui/                       # task_complete 等共用 UI
day/
  day_runtime.*             # 白天运行时入口
  systems/                  # day_level_environment、door_portal、alchemy_station、dual_world
  levels/                   # home、grassland、forest、lake、lakebed、market
  interactables/            # herb、map_switch、control_system
  art/                      # 白天美术（lake、raintree、town）
night/
  night_runtime.*           # 夜晚运行时入口
  alchemy/                  # 炼金系统 + 美术
  dialogue/                 # 对话气泡 + 对话 UI 美术
  levels/                   # 夜晚关卡
  ui/                       # pause_menu、developer_console、top_hint
menu/                       # 主菜单（sky、shaders、transition、ui）
audio/                      # SoundManager、BGM、SFX
minigames/                  # crimson_aqueduct 等小游戏
assets/                     # 共享引擎资产（tileset、shader、title_border）
tests/                      # 全部测试脚本与测试场景
```
