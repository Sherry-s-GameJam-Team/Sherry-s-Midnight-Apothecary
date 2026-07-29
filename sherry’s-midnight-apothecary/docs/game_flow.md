# 游戏流程

正式阶段顺序：

```text
MAIN_MENU
→ DAY_INTRO
→ DAY_PREPARATION
→ DAY_LEVEL
→ DAY_RESULT
→ NIGHT_SHOP
→ NIGHT_RESULT
→ STORY_EVENT
→ 下一天 DAY_INTRO
```

第 30 天的 `STORY_EVENT` 结束后进入 `ENDING`。灾难由 `DayDefinition` 配置：从第 5 天开始按内容表每四天安排一次，不由 `GameFlow` 硬编码具体灾难。

## 交接规则

1. `DAY_LEVEL` 返回深复制的 `LevelResult`。
2. `GameFlow` 应用采集物、剩余药水、谜题、传送门与剧情标记。
3. 应用完成后才进入 `DAY_RESULT`。
4. `NIGHT_SHOP` 返回深复制的 `ShopResult`。
5. `GameFlow` 应用收入、消耗、产出、售出、顾客结果与剧情标记。
6. 应用完成后才进入 `NIGHT_RESULT`，随后发出每日存档请求。

重复进入当前阶段、跳过阶段和并发切换都会被拒绝。

