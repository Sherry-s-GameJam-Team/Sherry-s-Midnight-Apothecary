# 赤染溪谷 (Crimson Vale)

## 概述
`res://day/levels/Crimson Vale/crimson_vale.tscn` 是日间探索关卡场景，展现了被赤红枫林环绕的溪谷村落。

## 架构与接入
- **LevelData 资源**: `res://day/levels/Crimson Vale/crimson_vale_level.tres`
  - `id`: `&"crimson_vale"`
  - `display_name`: "赤染溪谷"
  - `disaster_name`: "赤染之灾"
  - 已注册至 `DayRuntime.LEVELS` 列表。
- **环境根脚本**: `CrimsonValeLevel` (`res://day/levels/Crimson Vale/crimson_vale.gd`) 继承自 `DayLevelEnvironment`。
- **玩家系统**: 标准 `Player` (`CharacterBody2D`)，挂载：
  - `day_player_controller.gd`
  - `sherry_outdoor_collision.tscn`
  - `sherry_presentation.tscn`
  - `potion_player_system.tscn`
  - `Camera2D` (带边界限制)
- **调试与通用 UI**:
  - `DebugUI/DeveloperConsole` (可在独立运行或日间控制台中唤出)
  - `PauseMenuLayer/PauseMenu` (ESC/暂停菜单支持)

## 场景结构与美术资源映射
```text
CrimsonVale (CrimsonValeLevel)
├─ Background
│  ├─ FS (Parallax2D, scale: (0.1, 0.05), FS.png)
│  ├─ MS (Parallax2D, scale: (0.4, 0.2), MS.png, MS_2.png)
│  └─ CS (Parallax2D, scale: (0.75, 0.4), CS.png, CS_village.png)
├─ World
│  ├─ Ground (StaticBody2D: ground.png, ground_2.png, broken_ground.png)
│  ├─ Village
│  │  ├─ House (Sprite2D: house.png)
│  │  ├─ Shop (Sprite2D: shop.png)
│  │  ├─ MapleRack (Area2D: 晒枫脂架.png)
│  │  └─ WindChime (Area2D: 风铃.png, 附微风摆动 Tween)
│  ├─ DanxinGate
│  │  ├─ GateBroken (Sprite2D: 丹心门_破损态.png)
│  │  ├─ GateRestored (Sprite2D: 丹心门_修复态.png)
│  │  └─ GatePortal (DoorPortal 传送门)
│  └─ LeftBarrier / RightBarrier
├─ EntryPoints
│  ├─ default
│  ├─ from_home
│  ├─ from_village
│  └─ gate
├─ ExitPortal (DoorPortal 返回药水铺)
├─ Player
├─ DebugUI
└─ PauseMenuLayer
```

## 关卡机制
1. **状态切换**:
   - 侵蚀状态 (`set_corrupted(true)`): 丹心门显示破损态 (`GateBroken`)，界门传送未激活。
   - 修复净化状态 (`set_gate_repaired(true)`): 丹心门切换为修复态 (`GateRestored`)，激活界门传送门，写入存档标记 `crimson_vale_gate_restored`。
2. **村落互动**:
   - 走近风铃 (`WindChime`) 会触发轻柔摆动动画。
   - 晒枫脂架 (`MapleRack`) 位于村落中心供交互与草药/枫脂采集。

## 验证
运行独立测试：
```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/run_crimson_vale_test.gd
```
