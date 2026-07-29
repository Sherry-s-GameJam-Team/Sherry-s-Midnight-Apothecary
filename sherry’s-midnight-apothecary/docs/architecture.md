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
