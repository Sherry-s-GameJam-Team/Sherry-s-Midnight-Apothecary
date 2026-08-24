# 奥勒姆钟庭战后采集与维斯佩尔过渡

## 触发与采集

- 三个 `HerbSpawns` 只由赫利昂清除标记 `tutorial_flags["aurem_helion_cleared"]` 解锁；农场净化和钟塔同步不能提前生成。
- `HerbSpawnDirector` 公开采集信号、生成开关和当日采集点计数。剧情进度使用“日期 + 关卡 + 固定采集点”存档键，不读取背包数量。
- 返回外庭后，`TopHintUI` 显示机械大棚收集进度。旧存档若当天三个点均已采集，会直接进入一次性完成剧情，不重复发放材料。
- 赫利昂清除后，实体卢卡出现并使用场景本地跟随器跟随雪莉；对白期间跟随和玩家输入暂停。

## 钟声异象与路线

第三株收集后播放 `aurem_post_boss.dialogue`：正常钟声归于同步，三次低沉远钟引出右侧紫色路灯、夜空气氛和塞蕾娜幻影。完成标记为 `aurem_post_boss_harvest_complete`。

剧情完成后，钟庭的普通传送门关闭，右侧旧石道开放。玩家可以直接向右进入过渡关；若先向左移动约 500 像素，会触发一次紫色闪烁、传回路灯旁并播放补充对白，标记为 `aurem_clockyard_road_loop_seen`。

## 连续步行与故事跳夜

内部关卡 `aurem_vespervale_transition` 使用 `transBG.png` 的连续画面完成“橙色钟庭 → 暮色石桥 → 紫色眠谷”的色彩过渡，不显示标题卡。雪莉只能向右移动，步行和奔跑速度均为 50 px/s，全速通过约 39 秒；药水操作锁定，卢卡继续实体跟随。

终点通过 `DayRuntime.finish_day_skipping_night()` 进入 `GameFlow.complete_day_skipping_night()`：应用当前生命与剩余药水，写入 `night_skipped_by_story`，Day 4 推进至 Day 5，并直接重建 `DayRuntime` 载入 `vespervale_garden/default`。该路径不会实例化 `NightRuntime`。

## 主要资源

- `day/levels/Aurem Clockyard/aurem_post_boss_sequence.gd`
- `day/levels/Aurem Clockyard/aurem_post_boss.dialogue`
- `day/levels/Aurem Clockyard/aurem_vespervale_transition.tscn`
- `day/levels/Aurem Clockyard/aurem_vespervale_transition.gd`
- `day/levels/Aurem Clockyard/aurem_vespervale_transition_level.tres`
