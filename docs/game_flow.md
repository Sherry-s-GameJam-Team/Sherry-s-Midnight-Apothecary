# 昼夜流程

```text
第 1 天 DAY
→ 应用 DayResult
→ 第 1 天 NIGHT
→ 应用 NightResult
→ 保存
→ 第 2 天 DAY
```

循环持续到第 30 天；第 30 天夜晚结束后进入 `ENDING`。

`DayRuntime` 与 `NightRuntime` 获得完全相同的 `PlayerData` 对象引用。日期只由 `GameFlow` 在夜晚结算后推进。重复完成错误模式或切换中的请求会被拒绝。
