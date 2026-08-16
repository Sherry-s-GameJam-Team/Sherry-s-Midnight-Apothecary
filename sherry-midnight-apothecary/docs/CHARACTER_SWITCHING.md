# 白天双角色切换搭建说明

本文是远程场景搭建的交接规范。当前正式实现位于：

- `res://day/levels/forest/shared/forest_party_controller.gd`
- `res://characters/luca/luca_player.tscn`
- `res://shared/player/day_player_controller.gd`

## 目标

白天场景同时保留 Sherry 和 Luca。任意时刻只有当前角色接收移动输入；切换时，唯一的 `Camera2D` 会移动到当前角色下，未激活角色保留位置和碰撞，但不会移动。

## 必需节点结构

以 Forest 为例，根场景应具有以下结构和名称：

```text
Forest
├─ Player                         # Sherry，CharacterBody2D
│  └─ Camera2D                    # 唯一的主摄像机
├─ Luca                           # `luca_player.tscn` 实例，CharacterBody2D
└─ ForestController
   ├─ LucaWorldController         # 可选：控制 Luca 专属层
   └─ PartyController             # 挂 ForestPartyController
```

不要将对话 NPC、装饰性 Luca 立绘或 `Area2D` 命名为 `Luca`；顶层 `Luca` 是角色切换与关卡流程的集成契约。对话 NPC 应使用独立名称，例如 `LucaDialogueNpc`。

## Luca 场景与控制接口

顶层 `Luca` 应实例化：

```text
res://characters/luca/luca_player.tscn
```

角色必须支持以下接口，供 PartyController 调用：

```gdscript
func set_control_enabled(enabled: bool) -> void
```

`LucaPlayer` 已实现该接口：

- `true`：读取左右移动输入；
- `false`：关闭输入并停止水平移动；
- 场景脚本不得在未激活时继续向 Luca 注入移动方向。

如果其他关卡使用不同的角色场景，请在该角色根节点上实现同名接口，不要修改 PartyController 的调用方式。

## PartyController 配置

在 `ForestController/PartyController` 的 Inspector 中配置：

| 属性 | Forest 值 | 用途 |
| --- | --- | --- |
| `sherry_path` | `../../Player` | Sherry 根节点 |
| `luca_path` | `../../Luca` | Luca 根节点 |
| `camera_path` | `../../Player/Camera2D` | 初始挂在 Sherry 下的唯一摄像机 |
| `luca_world_controller_path` | `../LucaWorldController` | Luca 专属世界层控制器 |

节点改名或重排后，必须同步更新以上 `NodePath`。路径为空时，场景会在 `_ready()` 阶段报 `Node not found: ""`。

## 启用与输入

`PartyController` 初始固定 Sherry 为当前角色。仅当关卡流程调用：

```gdscript
party.enable_switching(true)
```

时才允许切换。

输入优先读取 InputMap 中可选的 `switch_character` 动作；若未配置，则使用 **Tab** 作为后备按键。建议远程场景搭建时在项目 InputMap 新增：

```text
switch_character = Tab
```

切换流程由 `set_active_character()` 统一完成：停用旧角色、启用新角色、将 `Camera2D` reparent 到新角色，并发出 `active_character_changed` 信号。不要在场景中额外创建第二台当前摄像机。

## 可选 Luca 专属层

若场景有仅 Luca 可见或可操作的节点，创建 `LucaWorldController` 并在其 Inspector 中设置：

| 属性 | 示例值 |
| --- | --- |
| `luca_world_path` | `../../Interior/LucaWorldOnly` |
| `overlay_path` | `../../UI/LucaOverlay` |

`ForestPartyController` 会在切换时调用 `set_luca_view(bool)`。不存在专属层时，路径可留空；控制器会安全跳过缺失节点。

## 远程验收清单

1. 场景加载时没有 `Node not found` 或空 `NodePath` 报错。
2. Sherry 初始可移动，Luca 初始不可移动。
3. 流程解锁后按 Tab（或 `switch_character`）可来回切换。
4. 每次切换后镜头跟随当前角色，且场景中没有第二台启用的主摄像机。
5. 未激活角色不响应玩家输入、不滑动，位置与碰撞保留。
6. 若启用了 Luca 专属层，切到 Luca 时显示，切回 Sherry 时隐藏。

## Forest 参考

Forest 的实际引用位于 `res://day/levels/forest/forest.tscn`。顶层 `Luca` 为 `luca_player.tscn` 实例；流程进入 Interior 后由 `ForestEnvironment.enter_interior()` 调用 `party.enable_switching(true)`。
