# 多日剧情事件

多日剧情事件由 `shared/events/` 的 Resource 模型驱动。事件定义位于
`shared/definitions/events/`，由 `AppRoot.story_event_catalog` 显式引用；它们不使用自动注册、全局事件总线或跨场景节点引用。

## 在编辑器中配置

1. 创建 `StoryEventDefinition` 资源，并给出稳定且不重复的 `id` 与优先级。
2. 创建 `StoryEventTriggerSpec`：选择日/夜运行时进入、关卡进入或交互；关卡与交互类型分别填写 `level_id` 或 `interaction_key`。日夜限制设在触发器上，天数范围设在条件中。夜间房间可使用 `home` 或 `bedroom` 作为关卡 ID。
3. 添加 `StoryEventCondition` 子资源。所有条件必须同时成立；可判定天数、事件标记、剧情物品、库存、解锁地点、金钱与声誉。
4. 可选地指定 Dialogue Manager 的对话资源和标题。对话关闭后，系统顺序执行 `StoryEventAction`：设置/清除事件标记、发放剧情物品或库存物品、解锁地点，或设置当天当前任务。
5. 将事件加入 `StoryEventCatalog.events`。同一入口同时命中时，优先级高者先播放；同分时按清单顺序播放。

场景交互在已有互动控制器下添加 `StoryEventTrigger` 节点，填写 `interaction_key`，并在互动成功时调用该节点的 `activate()`。它只向所属 Day/Night Runtime 转发请求，不持有状态或 UI。

## 完成与保存

每个事件在对话关闭、全部动作成功后写入 `story_event_completed:<id>` 标记；已经完成的事件不会再次运行。若条件未满足、没有 Dialogue Manager 或运行时在对话完成前被销毁，事件不会完成，后续相同入口会重试。

`PlayerData.event_flags` 独立于既有 `tutorial_flags`，并随存档保存。`example_market_arrival.tres` 演示了第 0 天进入 market、事件标记未设置、显示对话、设置标记和发放草药的完整配置。

`day_one_bedroom_luca_intro.tres` 定义第一日的 `day_one_blood_fountain` 事件：Town 的 `issueDay1` 表演节点在雪莉入场后显式派发 `issue_day_one_fountain`，播放血色泉流对话，并设置喷泉事件、旧检修井交互解锁标记和当天“调查喷泉后的旧检修井”任务。`PlayerData.get_active_daily_task(day)` 只会返回匹配该日期的任务，因此任务贴图不会出现在后续日期的当前任务中。

Town 的 `issueDay1` 在非剧情期不可见，且会在剧情完成后再次隐藏。它在镜头固定于 `People` 人群、雪莉从左侧屏外走到 `sherryposition`、Luca 位于 `lucaposition` 后才开始对话。Town 场景的 `CS/Fountain` 在第 1 天使用 `resources/blood_fountain/frames/` 中的血色喷泉；`Fountain.blood_fountain_enabled` 是保留在 Inspector 中的总开关，关闭它会维持普通喷泉且不清除事件或存档标记。

`day_one_bedroom_luca_urgent.tres` 是卧室内的第一日 Luca 事件。第 1 天进入 Bedroom 时，`DayOneLuca` 演出节点会取代 `SleepToWake`：黑屏渐显出完整卧室，Luca 从右侧走到床前，再自动派发 `day_one_luca_urgent` 并播放对话。此节点没有 E 键交互范围，也不会拦截卧室出口；对话完成后记录事件完成标记并设置当天“调查流明街广场的红色喷泉”任务。该天后续进入直接显示卧室；其余日期仍使用通常的起床演出。
