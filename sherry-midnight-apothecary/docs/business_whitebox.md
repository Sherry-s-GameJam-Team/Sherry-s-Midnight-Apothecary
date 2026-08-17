# 商店白模部署说明

商店白模部署在 `night/shop/business_placeholder.tscn`，由 `night/night_runtime.tscn` 的 `CustomerSlot` 以 CanvasLayer 打开。白模来自 `Downloads/sherry_business_whitebox_godot4.6`，只迁移其三栏 UI 与交互结构；运行时仍使用本项目的 `PlayerData`、`NightResult` 和药水字典库存。

## 页面布局

- 左栏：顾客请求卡，显示身份、文本、需求药水和价格修正。
- 中栏：顾客头像，使用 `characters/npcs/*/frontal_bust.png` 的现有头像资源；这是当前页面的主视觉，并显示当前顾客耐心。
- 右栏：独立场景 `night/shop/ui/potion_shelf_panel.tscn`。可售药水按实例显示为独立展示格 `potion_shelf_item.tscn`，包含药水图标（无图标时显示配色块）、名称、品质、剩余量进度条与曜报价；可直接在 Godot 编辑器中调整展示格布局、尺寸与样式。
- 顶栏：夜晚进度、待结算收入、持有曜、债务曜。
- 底栏：婉拒、交付药水、退回室内；退回室内保留 `NightResult`，睡觉时再由 `GameFlow` 结算。

## 数据边界

营业页读取 `PlayerData.potions`，将成交实例 UID 与收入写入共享 `NightResult.sold_potions` / `earned_money`，并由 `PotionMatchService` 将现有药水战斗效果映射为七类治疗功效。顾客事件定义于 `night/shop/customer_event_catalog.gd`，按照表格的主/副需求、Trait、禁忌、强度与特殊药水分析，不再按 `potion_id` 判定。`CustomerFeedbackResolver` 保证每次交付都显示顾客对白，同时把声誉变化写入 `NightResult`；关系、最近治疗、累计拒绝次数和回访日写入 `PlayerData.customer_states` 随存档保存。拒绝造成的声誉变化写入本夜 `NightResult.reputation_delta`，入睡后与收入统一结算。

## 运行流程

夜间房间的桌子触发 `NightRuntime.open_business()`，页面显示并暂停店内角色移动。玩家选择符合顾客需求的药水后交付，成交反馈会显示本次满意度和声誉增量；或婉拒当前顾客。婉拒会让该顾客立即离开本夜队列、耐心永久减少 25 点，并按该顾客累计拒绝次数 `n` 扣除 `2^n` 店铺声誉；耐心降至 0 前会二次确认，确认后顾客标记为永久流失，不再进入后续队列。声誉不低于 70 时初始队列最多 8 人；声誉 40–69 时最多 2 人且不再出现优质顾客；声誉低于 40 时最多 1 位低质顾客，报价也会继续降低。点击“退回室内”立即返回店内，已完成交易仍保留在 `NightResult`。若夜间炼制后再次进入营业页，`refresh_from_runtime()` 会重新读取当前共享库存。

旧测试曾按“固定 3 人队列、拒绝后回到队尾、耐心耗尽固定扣 10 声誉”断言，这些期望已废弃；自动化测试现在直接覆盖上述现行队列分级、立即离场和指数声誉惩罚规则。商店脚本使用 `REFUSAL_PATIENCE_LOSS` 与局部计算的指数惩罚，不依赖已移除的 `WALKOUT_REPUTATION_LOSS` 常量。

本页是玩法白模，正式头像框、动效和经济平衡可在此结构上继续迭代。

## 炼制后装瓶

炼制完成后会进入装瓶步骤，成品在确认装瓶前不会写入 `NightResult`。玩家可从 `health`、`heart`、`ice`、`moon`、`sleep` 五种瓶身中自由选择，为该瓶填写最多 12 字的可选名称，并查看品质评级、主作用与副作用。瓶身和对应 `_cover` 资源位于 `shared/potions/art/`：cover 黑色区域承载按药水颜色渲染的半透明液体，品质越高液体越清透。确认后会保存 `bottle_style_id` 与 `custom_name`；货架优先显示自定义名称并使用该瓶子的视觉效果。

炼制失败生成的黑药水使用 `shared/potions/art/black.png`，跳过装瓶步骤并直接写入当夜库存；这里同时包括温控烧焦和光谱落入无效区间两种失败。普通成功药水只有在确认瓶型后才提交原料消耗和成品，自动化测试也按这一提交边界验证，不再把“蒸馏完成”误当成“已经装瓶入库”。

炼制面板左上角提供“退出炼制”，会退回夜间室内；装瓶面板是唯一的炼制结果界面，旧的结果弹窗不再显示。黑药水在同一装瓶面板中显示自动入库结果。

在营业页和炼制页按 Esc 与点击退出行为一致：营业页立即退回室内；炼制页在没有进行炼制或待装瓶成品时退回室内。Esc 事件会在子界面中处理，不会打开全局暂停菜单。
