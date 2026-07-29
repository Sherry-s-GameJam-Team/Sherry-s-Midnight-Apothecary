# 关卡契约

## 静态内容场景

`content/levels/<level>/gameplay/` 中的关卡场景只描述地形、碰撞、出生标记、交互物、采集点、谜题、敌人生成信息与传送门锚点。它不得包含：

- 玩家实例；
- 主摄像机；
- 正式 HUD；
- `AppRoot`、`GameFlow` 或全局服务副本；
- 直接进入商店或修改日期的逻辑。

## DayLevelRuntime

后续的 `DayLevelRuntime` 接收 `LevelDefinition`、进入点 ID 与必要的 `GameSession` 数据副本。它负责创建玩家、主摄像机、正式 HUD 和关卡内容实例，并在结束时只返回 `LevelResult`。

关卡内部使用稳定 ID 交流，不把场景节点引用写入结果。视觉场景位于 `content/levels/<level>/visual/`，可由室外场景负责人独立修改。

## 退出条件

成功、失败、主动撤退都必须形成一个 `LevelResult`。返回结果后由 `GameFlow` 决定下一阶段，关卡不得调用场景切换 API。

