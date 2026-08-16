# Forest Interior / 阿尔维斯母树树干

## 设计目的

该场景是常霁云林林下四水车完成后的独立纵向关卡，不与树冠 Boss 共用一个 `.tscn`。玩法时间目标约 5 分钟。

## 节点合同

```text
ForestInterior
├─ EntryPoints
├─ Player
│  └─ Camera2D
├─ Luca
├─ RealityWorld
│  ├─ RootLiftA
│  ├─ LiftAConsoleReality
│  ├─ RotatingRoot
│  ├─ Mud...
│  ├─ SluiceGate
│  ├─ RootLiftB
│  └─ FinalGate
├─ LucaWorldOnly
│  ├─ LucaConsole...
│  ├─ SprayDevice
│  └─ UpperControlRoom/DirectLift
├─ RespawnPoints
├─ FallResetZone
├─ ExitToCrown
├─ UI
└─ ForestController
   ├─ LucaWorldController
   └─ PartyController
```

## 双角色

`ForestPartyController` 使用：

```text
sherry_path = ../../Player
luca_path = ../../Luca
camera_path = ../../Player/Camera2D
luca_world_controller_path = ../LucaWorldController
```

场景只保留一台 Camera2D。

## 水枪

`SprayDevice` 使用程序化水流：

- `Line2D`：主体水柱
- `CPUParticles2D`：喷口与命中飞溅
- `PhysicsRayQueryParameters2D`：命中判定
- 水压：100
- 消耗：24/s
- 恢复：20/s
- 归零冷却：1s
- 重新启动阈值：30
- W/S：-35° ~ +35°

水枪只查询 collision layer 2。污泥同时占 layer 1 + 2，因此既能挡玩家又能被水枪命中。

## 污泥

`CorruptedMud`：

- `Polygon2D + Shader` 产生暗红/紫黑流动
- 少量 `CPUParticles2D` 气泡
- `receive_potion_hit(hit)` 接收 `purification_potion`
- `receive_water_jet(delta)` 连续约 0.8 秒净化

## 控制台

`LucaConsole`（`luca_console.gd`）为 `Area2D`，对应操作角色站在范围内按 E 触发机关：

- `operator_name`（`StringName`，默认 `&"Luca"`）决定谁能操作：`&"Luca"` 需要 Luca 激活（`is_luca_active()`），`&"Player"` 需要雪莉激活（`not is_luca_active()`）。
- 默认**可多次使用**（`one_shot = false`）：每次按 E 都会重新触发 `activate_luca_console(action_id)`，提示始终可见、不会变灰。
- 保留 `one_shot` 开关：需要一次性机关时可在场景实例上设为 `true`（用后会变灰并隐藏提示）。
- 控制台实例：
  - `LucaWorldOnly/LiftAConsole`（`&"Luca"`，`root_lift_a`）
  - `RealityWorld/LiftAConsoleReality`（`&"Player"`，`root_lift_a`，位置 (700, 560)）——雪莉侧与 Luca 侧同能力的 RootLiftA 升降控制台
- 动作一览：
  - `root_lift_a` / `root_lift_b`：`toggle_state()` 反复升降（可来回切换）
  - `rotate_beam`：`set_horizontal()` 旋转根梁（重复触发为幂等）
  - `sluice`：`open_gate()` 开启闸门（重复触发为幂等）
  - `lift_root` / `lift_water` / `lift_crown`：记录动力并刷新直达梯（幂等）
  - `final_gate`：开启最终大门（幂等）

## Normal / Corrupted

Corrupted：红水、污泥、机关谜题。

Normal：清水、污泥移除、RootLift/RotatingRoot/Sluice/DirectLift/FinalGate 自动设为通行状态，回访不强制重新完成 5 分钟流程。

## 持久标记

使用现有 `PlayerData.tutorial_flags`：

- `forest_interior_completed`
- `forest_interior_direct_lift_unlocked`
- `forest_interior_final_gate_open`

不新增 SaveManager/EventBus。
