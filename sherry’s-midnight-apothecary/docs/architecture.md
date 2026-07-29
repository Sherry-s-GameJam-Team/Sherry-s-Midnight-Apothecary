# 项目架构

本项目以 `AppRoot` 作为整个运行期持续存在的组合根。它持有单一 `GameSession`，托管 `GameFlow`、`SceneFlow`、当前模式插槽、全局 UI、转场、音频与调试层，但不包含具体关卡或商店内容。

## 依赖方向

```text
AppRoot
├── GameSession（唯一运行状态）
├── DataRegistry（静态数据索引）
├── GameFlow（规则与阶段决策）
│   └── 接收 LevelResult / ShopResult
└── SceneFlow（仅负责模式场景装卸）
    └── CurrentModeSlot
```

- 业务功能读取 `GameSession` 的快照或必要字段，但不长期保存跨场景 `Node` 引用。
- 关卡与商店生成结果对象；它们不直接修改 `GameSession`。
- `GameFlow` 先应用结果，再改变阶段；它是生产代码中唯一推进日期和决定下一模式的模块。
- `SceneFlow` 只装卸当前模式，不修改日期、库存或剧情状态。
- 所有静态内容通过 `Resource` 与稳定 `StringName` ID 定义，并在启动阶段显式注册。

## 场景职责

`DayLevelRuntime`（后续实现）负责根据 `LevelDefinition` 创建玩家、主摄像机与正式 HUD，再将纯内容关卡挂入运行时。关卡内容场景不得包含玩家、主摄像机或正式 HUD。

`NightShopRuntime`（后续实现）只生成 `ShopResult`。白天关卡不得直接进入夜间商店，夜间商店也不得修改日期；两者都必须把控制权交还给 `GameFlow`。

## 禁止事项

- 业务脚本不得调用 `change_scene_to_file` 或 `change_scene_to_packed`。
- 不得在运行状态中保存 `Node`、`NodePath`、`Callable`、信号或场景实例。
- 不得把颜色体系当作战斗行为体系；六种颜色与十六套战斗效果使用不同稳定 ID。
- 不提前迁移旧 `GameRoot`、完整旧关卡或旧关卡中的玩家和主摄像机。

