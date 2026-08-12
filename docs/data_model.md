# 共享主角数据

`PlayerData` 只保存白天和夜晚都需要的主角数据：

- 生命值；
- 金钱和债务；
- 材料库存；
- 已有药水；
- 主角升级；
- 已解锁关卡。

日期和当前昼夜模式属于 `GameFlow`，存档时与 `PlayerData` 一起写入。

## 结果对象

`DayResult` 保存白天带回的材料、剩余药水、生命值和新解锁关卡。`NightResult` 保存夜间收入、材料消耗、制作和售出的药水。

`GameFlow` 先把结果应用到同一个 `PlayerData`，再切换运行时。结果对象不保存 Node 或场景实例。

## 静态数据

`IngredientData`、`PotionData`、`RecipeData`、`CustomerData` 和 `LevelData` 都是普通 Resource。它们使用稳定 ID，但不经过全局注册中心。

## 文件位置

```text
shared/core/player_data.gd          # PlayerData
shared/core/day_result.gd           # DayResult
shared/core/night_result.gd         # NightResult
shared/core/save_service.gd         # SaveService
shared/core/potion_instance_data.gd # PotionInstanceData
shared/definitions/                 # IngredientData、PotionData、RecipeData、CustomerData、LevelData
shared/definitions/data/            # 静态 .tres 实例（ingredients、potions、heat_profiles）
```
