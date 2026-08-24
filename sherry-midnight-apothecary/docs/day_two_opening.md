# 第二日开场动画

`day/levels/home/bedroom.tscn` 在内部 `DayRuntime.day == 2` 且
`day_two_opening_complete` 尚未写入时播放一次第二日清晨开场。

`DayTwoOpening` 使用全局 Dialogue Manager 气泡承载台词，并通过
`emit_dialogue_event()` 将剧本注释映射为画面分镜：

- 黑屏晨景、抓门痕迹、床铺震动与更衣短转场；
- 卧室门口场景与喵斯来信特写；雪莉、卢卡和恩佐仅使用对话框立绘，背景层不重复显示角色贴图；
- 药典屋一楼炼药区、恩佐验药、微型门路与远程补给预告卡；
- 绿色/蓝色药液汇聚为青色、涌水药水水纹和配方解锁卡；
- 投掷药水区域效果说明、装箱、开门晨光及无文字的纯白转场。

动画期间设置 `day_modal_input_locked` 并隐藏玩家角色。完成后会设置
`day_two_opening_complete`、`enzo_remote_supply_unlocked`、
`cyan_surge_potion_unlocked`，登记
“将涌水药水送往涟汀村”日任务，
解锁并切换到 `golden_cliff`。烁金横崖的普通场景标题会被标记为已展示，
保证纯白转场结束后直接进入关卡画面，不再插入任务或场景标题卡。

离场时画面淡入纯白并短暂停留，不显示日期、任务说明或路线文字，也不再叠加
黑色场景转场；纯白层随卧室场景切换一并移除，直接显露烁金横崖。

装箱分镜会向剧情道具栏加入 4 瓶 `springburst_potion_commission`，显示名为
“涌水药水（委托品）”。在噬潮眼被平息前，它们不会进入药水分页、快捷栏或
投掷系统；Boss 胜利后才转换成显示名为“涌水药水”的 `cyan_potion`。
远程补给从开场结束、进入 `golden_cliff` 时开始生效；返回药典屋或此前区域时
补给计时停止。从 `golden_cliff` 起按 `DayRuntime.LEVELS` 顺序登记的后续关卡
会继续使用该机制。
旧存档若已经具有 `day_two_opening_complete`、但缺少补给标记，`DayRuntime`
会在载入时自动补写 `enzo_remote_supply_unlocked`。

除第二日剧情开场外，卧室继续使用原有 `SleepToWakeExecutor`。运行时会
显式启动该演出，因此夜间入睡进入新一天时不会等待一个尚未启动的动画。
从标题菜单继续尚未播放过开场的第二日存档时，`BedroomIntroBridge` 会优先
等待第二日剧情开场，不会并行播放普通起床帧动画。
