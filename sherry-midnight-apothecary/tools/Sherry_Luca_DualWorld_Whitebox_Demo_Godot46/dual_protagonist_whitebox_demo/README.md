# Dual Protagonist Whitebox Demo — Godot 4.6

这是一个给《雪莉的午夜药水铺》双主角机制准备的**独立白盒 Demo**。不使用 TileMap；所有可见地形都是 PNG + `Sprite2D`，所有碰撞都是 `StaticBody2D + CollisionShape2D`。

## Demo 验证的机制

1. **雪莉 / 异变世界** 与 **Luca / 未异变世界** 使用同一套世界坐标。
2. Q / Tab 切换主角，同时切换世界贴图和对应碰撞。
3. 两个角色实例始终保留自己的位置；非当前角色只停用控制与碰撞，不会被删除。
4. Luca 世界有完整桥；雪莉世界初始道路断裂并被异变阻挡。
5. Luca 跨桥触发 Anchor 后，状态跨世界保留：雪莉世界的阻挡消失并生成稳定平台。
6. 雪莉到达 Seal 后，打开两个世界共享的终点 Gate。
7. 提供 `ghost_reference.gd`，可在编辑器里把另一场景作为半透明幽灵参照进行纯贴图对齐。

## 操作

- `← / →` 或 `A / D`：移动
- `Space`：跳跃
- `Q` 或 `Tab`：切换主角 / 世界
- `R`：重置 Demo

## 推荐游玩顺序

1. 开局为雪莉，异变墙与断裂路线阻止继续前进。
2. Q 切到 Luca。
3. Luca 通过未异变世界的完整桥，到右侧触碰黄色 `Luca Anchor`。
4. Q 切回雪莉。
5. 雪莉世界的障碍消失，新的稳定平台出现；跨过后触碰 `Sherry Seal`。
6. 最终 Gate 消失，继续向右进入绿色 Goal。

## 主角占位接口

`demo_level.gd` 暴露：

```gdscript
@export var sherry_scene: PackedScene
@export var luca_scene: PackedScene
```

独立运行时如果为空，会自动使用 `placeholder_actor.tscn`。

迁移到现有工程时，Codex 应优先找到项目里当前实际使用的 Sherry 与 Luca 场景并替换两个占位引用，而不是修改你已有角色场景的核心结构。若实际角色没有 `set_control_enabled(bool)`，在 Demo 外围加 Adapter，或将 `_set_actor_control()` 映射到现有控制接口。

## 纯贴图双世界规范

- 两个世界共用绝对坐标原点 `(0, 0)`。
- 相互对应的完整场景贴图推荐保持相同画布尺寸、pivot、scale。
- 只改变视觉不改变几何：共用一份碰撞。
- 改变平台几何：两个世界各自维护碰撞。
- 共享机关状态放在 Level/Manager，不放到单个世界节点中。
- 世界切换视觉过渡可以渐变，但碰撞在切换点一次性切换，避免双重碰撞。

## 半透明对齐

`scripts/ghost_reference.gd` 是 `@tool` 编辑器辅助脚本。把它挂在一个 Node2D 上，然后将另一世界 `.tscn` 填进 `reference_scene`，即可在编辑器中以 `preview_alpha` 半透明显示参照。它不会把参照场景保存成正式关卡子节点。

## 文件说明

- `scenes/main.tscn` — 白盒 Demo 入口
- `scenes/placeholder_actor.tscn` — 主角占位
- `scripts/demo_level.gd` — 双世界、谜题、相机、切换逻辑
- `scripts/placeholder_actor.gd` — Demo 测试移动，仅用于独立运行
- `scripts/ghost_reference.gd` — 双场景半透明编辑器对齐工具
- `docs/CODEX_MIGRATION_PROMPT.md` — 直接交给 Codex 的迁移 Prompt

> Demo 是系统样例，不要求把其白盒美术带入正式项目。正式关卡应直接替换 `assets/` 下 PNG，同时维持节点坐标与碰撞逻辑。
