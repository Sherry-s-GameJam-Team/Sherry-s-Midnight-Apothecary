# 第六日开场：空与流光之馆

第六日开场由两个连续演出节点组成。卧室场景中的 `DaySixOpening` 播放药典屋玻璃共鸣、七色旅门苏醒、强制传送以及王畿旧门遗址的卫兵迎接；该阶段使用全屏背景、光效和 Dialogue Manager 人物气泡，不在场景中实例化雪莉、恩佐、卢卡或卫兵贴图。王畿遗址画面来自可独立复用的 `res://day/levels/crownland/home.tscn`。

遗址对话结束后，流程设置 `day_six_crownland_escort_pending` 并切换到 `crownland` 的 `from_home` 入口。`DaySixCrownlandEscort` 接管输入，在 `crownland.tscn` 中显示真实的雪莉 Player、恩佐 `AnimatedSprite2D` 与 Luca 场景实例，并让三人一边行进一边自动对话。镜头由受控的雪莉节点推进至用户设置的 `EntryPoints/cathedral` 标记；即使玩家快速推进对话，大教堂事件也会将三人准确吸附到该标记并切换待机动画。

大教堂定格后以遮罩和回忆卡表现国王腐化、地下黑柱及塞蕾娜的药香。卢卡在排水口事件中淡出离队；演出结束后恢复雪莉控制，恩佐留在场景，任务更新为调查王宫和黑柱仪式。完成状态分别由 `day_six_apothecary_gate_complete` 与 `day_six_crownland_escort_complete` 持久化，避免返回卧室或王畿时重复播放。
