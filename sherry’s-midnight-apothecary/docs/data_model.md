# 数据模型

## 运行状态

`GameSession` 是跨模式运行数据的唯一容器，保存日期、阶段、金钱、债务、库存、药水、解锁关卡、传送门、区域、谜题、顾客关系、剧情标记、灾难状态与玩家升级。

- 容器之间传递 `Dictionary` 时使用深复制。
- 稳定 ID 使用 `StringName`。
- `to_save_data()` 只输出可序列化值；`from_save_data()` 用安全默认值恢复缺失字段。
- `current_day` 对外只读，生产代码只由 `GameFlow` 通过内部边界修改。

## 静态定义

定义类位于 `content/definitions/`，均继承 `Resource`，具有稳定 `id` 与 `display_name`。具体定义补充领域字段；例如：

- `DayDefinition`：当天关卡、灾难、剧情事件、顾客池以及敌人、采集、经济修正。
- `LevelDefinition`：区域、纯内容场景、入口、音乐、环境配置与原生材料。
- `IngredientDefinition`：颜色、基础浓度、品质、标签、价值与图标。
- `PotionDefinition`：颜色、浓度、品质、战斗效果、商店效果、售价与图标。

`DataRegistry` 在启动时接收明确的 Resource 列表并构建内存索引。它拒绝空 ID、重复 ID 和无效 `PackedScene`，查询时不扫描文件系统。

