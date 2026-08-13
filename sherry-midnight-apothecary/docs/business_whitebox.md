# 商店白模部署说明

商店白模部署在 `night/shop/business_placeholder.tscn`，由 `night/night_runtime.tscn` 的 `CustomerSlot` 以 CanvasLayer 打开。白模来自 `Downloads/sherry_business_whitebox_godot4.6`，只迁移其三栏 UI 与交互结构；运行时仍使用本项目的 `PlayerData`、`NightResult` 和药水字典库存。

## 页面布局

- 左栏：顾客请求卡，显示身份、文本、需求药水和价格修正。
- 中栏：顾客头像，使用 `characters/npcs/*/frontal_bust.png` 的现有头像资源；这是当前页面的主视觉，并显示当前顾客耐心。
- 右栏：独立场景 `night/shop/ui/potion_shelf_panel.tscn`。可售药水按实例显示为独立展示格 `potion_shelf_item.tscn`，包含药水图标（无图标时显示配色块）、名称、品质、剩余量进度条与曜报价；可直接在 Godot 编辑器中调整展示格布局、尺寸与样式。
- 顶栏：夜晚进度、待结算收入、持有曜、债务曜。
- 底栏：婉拒、交付药水、退回室内；退回室内保留 `NightResult`，睡觉时再由 `GameFlow` 结算。

## 数据边界

营业页只读取 `PlayerData.potions`，并将成交实例 UID 与收入写入共享 `NightResult.sold_potions` / `earned_money`。同一实例在同一夜不能重复出售。成交时会按药水的「品质 × 剩余剂量」计算该顾客满意度（限制在 50%–150%），并写入对应的声誉增量：50% 为 +1，100% 为 +3，150% 为 +5，中间线性取整；顾客耐心耗尽离开时则向 `NightResult.reputation_delta` 写入 -10。入睡后统一结算到 `PlayerData.store_reputation`。当前版本债务显式显示为 `30000曜`；`PlayerData` 存档版本升级到 7，旧版本债务值迁移为 30000，声誉默认为 100。

## 运行流程

夜间房间的桌子触发 `NightRuntime.open_business()`，页面显示并暂停店内角色移动。玩家选择符合顾客需求的药水后交付，成交反馈会显示本次满意度和声誉增量；或婉拒当前顾客，婉拒会使该顾客耐心减少 25 点并回到当晚队列末尾，耐心耗尽时顾客离开并降低 10 点店铺声誉。下一个夜晚，声誉 70 以下的初始顾客数降至 2 且不再出现优质顾客；声誉 40 以下只会有 1 位低质顾客，报价也会继续降低。点击“退回室内”立即返回店内，已完成交易仍保留在 `NightResult`。若夜间炼制后再次进入营业页，`refresh_from_runtime()` 会重新读取当前共享库存。

本页是玩法白模，正式头像框、动效和经济平衡可在此结构上继续迭代。

## 炼制后装瓶

炼制完成后会进入装瓶步骤，成品在确认装瓶前不会写入 `NightResult`。玩家可从 `health`、`heart`、`ice`、`moon`、`sleep` 五种瓶身中自由选择，为该瓶填写最多 12 字的可选名称，并查看品质评级、主作用与副作用。瓶身和对应 `_cover` 资源位于 `shared/potions/art/`：cover 黑色区域承载按药水颜色渲染的半透明液体，品质越高液体越清透。确认后会保存 `bottle_style_id` 与 `custom_name`；货架优先显示自定义名称并使用该瓶子的视觉效果。

炼制失败生成的黑药水使用 `shared/potions/art/black.png`，跳过装瓶步骤并直接写入当夜库存。
