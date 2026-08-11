# Codex 迁移任务：将双主角双世界白盒 Demo 接入《雪莉的午夜药水铺》当前 Godot 4.6 工程

你正在编辑用户当前的《雪莉的午夜药水铺》Godot 4.6 项目。附件/临时目录中有一个 `dual_protagonist_whitebox_demo` 独立样例工程。

## 目标

把 Demo 中的“双主角 + 双世界纯贴图横板解谜机制”迁移为当前项目可复用的系统，但**不要覆盖现有 Player、相机、输入、关卡基类和美术资源**。

核心设计：

- Sherry 激活时显示 `CORRUPTED` 异变世界。
- Luca 激活时显示 `ORIGINAL` 未异变世界。
- 不使用 TileMap。
- 两个世界全部采用 `Sprite2D / AnimatedSprite2D / Polygon2D` 等纯场景贴图节点搭建。
- 碰撞采用 `StaticBody2D + CollisionShape2D/CollisionPolygon2D`。
- 两套世界共用一个世界坐标系 `(0,0)`。
- 两个主角实例常驻，切换时保留各自坐标；只切换输入控制、相机目标、可见世界和对应碰撞。
- 机关状态独立于世界视觉状态，允许 Luca 操作后改变 Sherry 世界的地形，反之亦然。

## 第一步：先自行检查当前项目

1. 搜索当前实际运行的 Sherry 玩家场景、控制脚本、动画、碰撞配置。
2. 搜索 Luca 狗当前已有的场景与控制/跟随逻辑。如果 Luca 目前只有 NPC/跟随状态，不要破坏它；新增“可操作状态”Adapter。
3. 找到当前横板关卡共用的 Camera2D / 相机脚本。
4. 找到当前 InputMap 与角色输入开关方式。
5. 找到现有场景切换、暂停、全局 UI 与保存结构。
6. 阅读这些文件后再决定接入点；不要根据文件名猜路径。

## 第二步：抽离 Demo 系统，不复制 Demo 的白盒玩家实现

从 Demo 的 `scripts/demo_level.gd` 提取这些职责并拆分：

### `DualWorldManager`
负责：
- `CORRUPTED / ORIGINAL` 状态。
- 切换 `CorruptedWorld` 与 `OriginalWorld` 的视觉。
- 精确启停两边碰撞。
- 世界切换的中点回调。
- 广播 `world_changed(world_state)` 信号。

### `DualProtagonistController`
负责：
- `SHERRY / LUCA` 当前主角。
- 调用当前项目已有角色控制接口启停输入。
- 切换当前项目已有 Camera2D 的跟随目标。
- Sherry -> `CORRUPTED`，Luca -> `ORIGINAL`。
- 两个角色实例常驻，不 queue_free，不把另一个角色瞬移到当前角色位置。

### `DualWorldState`
负责：
- 关卡内共享机关状态，例如 `luca_anchor_01 = true`。
- 一个角色改变状态后，另一个世界的对应地形可以刷新。
- 当前只做关卡内状态；除非现有项目已经有统一存档接口，否则不要自行新造复杂全局存档系统。

## 第三步：建立通用纯贴图双世界关卡结构

推荐结构：

```text
DualWorldLevel
├── SharedWorld
│   ├── Background
│   ├── SharedVisual
│   ├── SharedCollision
│   └── SharedInteractables
├── CorruptedWorld
│   ├── Visual
│   ├── Collision
│   └── WorldObjects
├── OriginalWorld
│   ├── Visual
│   ├── Collision
│   └── WorldObjects
├── Actors
│   ├── Sherry
│   └── Luca
└── Systems
    ├── DualWorldManager
    ├── DualProtagonistController
    └── DualWorldState
```

不要使用 TileMap/TileMapLayer。

## 第四步：主角适配

Demo 中的 `placeholder_actor.tscn` 只用于独立验证，正式迁移必须删除依赖。

根据当前项目实际角色 API 做 Adapter：

```gdscript
func set_actor_control(actor: Node, enabled: bool) -> void:
    # 映射到当前项目真实接口
```

要求：
- 不修改现有 Sherry 移动手感。
- Luca 可操作时使用同一套项目输入规范。
- 非当前角色不响应玩家输入。
- 非当前角色应避免参与当前世界的地形碰撞；优先复用项目已有的 disable/input/physics 状态，而不是删除角色。

## 第五步：加入世界切换安全检查

切换到目标角色/目标世界前，检查目标角色当前保存位置在目标世界是否与新的实体碰撞重叠。

若重叠：
- 阻止本次切换。
- 在调试版给出明确警告。
- 不要自动把角色大幅传送到另一个位置。

## 第六步：加入编辑器半透明对齐能力

参考 Demo 的 `scripts/ghost_reference.gd`：

- 使用 `@tool`。
- 编辑 Corrupted 场景时可以把 Original 场景以 0.2–0.35 Alpha 显示。
- 编辑 Original 时反之。
- Ghost 只用于编辑器，不参与运行时碰撞/逻辑，也不要作为正式子场景被保存。
- 两套关卡必须共享 `(0,0)` 与关键 Marker2D 锚点。

建议每个双世界关卡至少放：

```text
Origin
LevelStart
GroundBase
PuzzleAnchor01
PuzzleAnchor02
LevelEnd
```

## 第七步：复制 Demo 的谜题作为项目内测试关，但保留白盒

创建一个不会影响主线的测试场景，例如：

```text
res://day/levels/_tests/dual_world_puzzle_demo.tscn
```

实际路径应按当前项目结构调整。

白盒谜题：
1. Sherry 世界路线断裂。
2. Luca 世界存在完整桥。
3. Luca 跨桥触发 Anchor。
4. Anchor 改变共享 puzzle state。
5. Sherry 世界出现新的可行走平台/阻挡消失。
6. Sherry 触发 Seal。
7. Seal 打开共享终点门。

用当前项目真实 Sherry 和 Luca 场景测试。

## 验收条件

- Godot 4.6 打开工程无解析错误。
- 不出现新的 cyclic dependency。
- 现有普通关卡不受影响。
- 测试关可以从头到尾完成。
- Q/项目约定按键切换角色时，相机正确切换。
- 两世界视觉与碰撞严格同步。
- 任意时刻只有当前世界专属碰撞生效。
- 两个角色位置独立保留。
- Luca 的操作可以改变雪莉世界路线。
- 雪莉的操作可以改变共享状态。
- Ghost alignment 在编辑器可用，运行游戏时不存在。
- README 写清楚新增文件、接入点、如何制作新的双世界关卡。

最后输出：
1. 修改文件清单。
2. 系统架构说明。
3. 测试方式。
4. 若现有角色结构迫使你偏离本 Prompt，说明偏离原因和实际采用的 Adapter 方式。
