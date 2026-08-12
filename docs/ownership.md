# 三人代码所有权

## 白天玩法负责人

```text
day/levels/           # 关卡场景、脚本与美术
day/interactables/    # herb、map_switch、control_system
day/systems/          # day_level_environment、door_portal、alchemy_station、dual_world
day/art/              # 白天共用美术（lake、raintree、town）
day/ui/               # scene_title_card
```

## 夜间玩法负责人

```text
night/alchemy/        # 炼金系统 + 美术
night/dialogue/       # 对话气泡 + 对话 UI 美术
night/levels/         # 夜晚关卡
night/shop/           # 商店
night/ui/             # pause_menu、developer_console、top_hint
night/art/            # 夜晚共用美术（herbs、paint、ui）
```

## 整合与资源负责人

```text
app/                  # AppRoot、GameFlow
shared/core/          # PlayerData、SaveService、DayResult、NightResult
shared/player/        # day_player_controller、camera_bounds
shared/definitions/   # 静态 Resource 定义
shared/potions/       # 药水系统
characters/           # 角色场景与精灵帧
menu/                 # 主菜单
audio/                # SoundManager、BGM、SFX
minigames/            # 小游戏
tests/                # 全部测试
docs/                 # 文档
```

`PlayerData`、昼夜结果、`GameFlow` 和 `project.godot` 属于共享接口，修改时通过 Pull Request 审核。

