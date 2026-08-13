# 商店白模部署说明

商店白模部署在 `night/shop/business_placeholder.tscn`，由 `night/night_runtime.tscn` 的 `CustomerSlot` 以 CanvasLayer 打开。白模来自 `Downloads/sherry_business_whitebox_godot4.6`，只迁移其三栏 UI 与交互结构；运行时仍使用本项目的 `PlayerData`、`NightResult` 和药水字典库存。

## 页面布局

- 左栏：顾客请求卡，显示身份、文本、需求药水和价格修正。
- 中栏：顾客头像，使用 `characters/npcs/*/frontal_bust.png` 的现有头像资源；这是当前页面的主视觉。
- 右栏：可售药水货架，按实例显示品质、剩余剂量与曜报价。
- 顶栏：夜晚进度、待结算收入、持有曜、债务曜。
- 底栏：婉拒、交付药水、退回室内；退回室内保留 `NightResult`，睡觉时再由 `GameFlow` 结算。

## 数据边界

营业页只读取 `PlayerData.potions`，并将成交实例 UID 与收入写入共享 `NightResult.sold_potions` / `earned_money`。同一实例在同一夜不能重复出售。当前版本债务显式显示为 `30000曜`；`PlayerData` 存档版本升级到 6，旧版本债务值迁移为 30000。

## 运行流程

夜间房间的桌子触发 `NightRuntime.open_business()`，页面显示并暂停店内角色移动。玩家选择符合顾客需求的药水后交付，或婉拒当前顾客；点击“退回室内”立即返回店内，已完成交易仍保留在 `NightResult`。若夜间炼制后再次进入营业页，`refresh_from_runtime()` 会重新读取当前共享库存。

本页是玩法白模，正式头像框、动效和经济平衡可在此结构上继续迭代。
