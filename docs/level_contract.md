# 白天关卡契约

白天关卡位于：

```text
day/levels/home/
day/levels/grassland/
day/levels/forest/
day/levels/lake/
day/levels/lakebed/
day/levels/market/
```

共用关卡基础设施位于 `day/systems/`（`day_level_environment`、`door_portal`、`alchemy_station`、`dual_world`）。

`DayRuntime` 负责组合当前关卡、玩家、摄像机和白天 UI。关卡通过 `LevelData` 获得内容场景、默认入口和原生材料列表。

关卡结束时生成 `DayResult`，不得自行创建夜间场景或推进日期。`GameFlow` 接收结果后统一进入 `NightRuntime`。
