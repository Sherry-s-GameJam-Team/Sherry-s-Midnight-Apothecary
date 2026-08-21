# 流明街旧引水渠

`res://day/levels/market/sewer/sewer.tscn` 是从血色喷泉通往常霁云林的横向过渡关卡。场景以旧维阿利亚引水渠为背景：拱形石墙、被树根撑裂的砖缝，以及会映出墙体的异常赤色水流。

- `Environment/Water` 使用 `shaders/sewer_water.gdshader`。水层保留原画中的倒影，再叠加时间驱动的双频波纹与破碎高光。
- 背景固定在正向绘制层：水层为 `Environment` 的 0 层，左右建筑遮罩依次为 1、2 层。这样关卡嵌入上层场景流时不会落到父级的背景之后。
- 角色活动在 `WorldBounds/Walkway` 的中间石质通路（y = 526）上；水层只作为通路前后的视觉危险，不承担移动碰撞。
- 场景配置 Sherry、随行的 Luca、进入/离开标记，以及 HP、任务和地点 UI，供剧情系统后续接入。
- `SewerLucaFollow` 通过 Luca 已有的外部移动接口驱动同伴跟随：相距 250px 后开始跟进、回到 140px 内才停留，间隔达到 620px 时提升至追赶速度。Luca 不接收玩家输入，也不与 Sherry 发生实体碰撞。
- `CharacterReflections` 负责 Sherry 的镜像表现。Luca 使用其场景实例下的 `LucaWaterReflection` 直接读取父节点当前动画帧并水线镜像，从而不依赖集中控制器的层级或可见性状态。Luca 倒影在镜像位置下移 10px，垂直高度为原先的 3 倍（压缩系数 0.6）；两者均使用相同的赤色波纹 shader 与 water alpha 蒙版，且不参与碰撞或输入。
- `HydraulicGatePuzzle` 是关卡内局部的液压主闸谜题，位于通路后段。红、蓝、黄手轮、绿色换向阀精灵与中央压力表精灵各自绑定 `SewerHydraulicInteractable`，靠近后按 `E` 操作；因此位置、缩放、贴图和文本均可直接在编辑器中调整。红阀标注“注水”并 `+4`、蓝阀标注“蒸汽”并 `+3`、黄阀标注“回流”并 `-1`。压力从 0 巴开始；高于 8 巴会触发蒸汽泄压、造成 1 点伤害并重置。蓝阀必须在红阀之后，黄阀必须在蓝阀之后；不再提供手动重置按钮。
- 红、蓝、黄副阀分别由 `valve.png` 搭配同目录的 `red_wheel.png`、`blue_wheel.png`、`yellow_wheel.png` 呈现。绿色换向阀根据状态切换 `up.png` / `down.png`；中央压力表使用 `CENTRAL PRESSURE GAUGE& INDICATOR MODULE.png`，其子精灵使用 `pointer.png`，读数和导流状态由可编辑的 `Label` 节点显示。控制器不再绘制圆圈、白模或文字。
- 阀门操作、顺序错误、超压、解锁和开门的状态文本不再放置在关卡底部；`HydraulicGatePuzzle` 会使用全局 `TopHintUI` 的 `push_text()` 在顶部播报，并在 3 秒后自动淡出。
- Hint UI 不显示具体“巴”数值；压力数值仅保留在仪表盘内。播报内容为液压流程状态、顺序错误、安全边缘警告、超压泄压和解锁结果。
- 每个可交互精灵的 `SewerHydraulicInteractable` 读取其子节点 `InteractionArea`（`Area2D + CollisionShape2D`）的实体检测结果：玩家进入对应阀体或绿阀的可编辑判定箱才显示关联的 `PanelContainer` 文字框，也只有此时 `E` 有效。红、蓝、黄手轮成功操作后各自播放 0.42 秒的一整圈转动；绿阀不旋转，以保留其上下状态表现。
- `CentralPressureGauge` 的 `0`、`2`、`4`、`6`、`8`、`10` 个 `Marker2D` 节点是指针刻度锚点。压力指针按相邻锚点分段插值，确保 0、4、6、8 巴分别指向对应刻度；`pointer_art_angle` 可在 `HydraulicGatePuzzle` Inspector 微调源图初始朝向。
- 正解依次为红、蓝、黄、黄、蓝、黄，使压力稳定在 7 巴；再把绿阀拨到“下 / 顺流”。中央指示灯转绿且卡榫解除后，`WhiteboxMainGate` 自动从 `gate.png` 切换为 `gate_open.png` 并向上移动 250px；其 `StaticBody2D` 碰撞体随之移开，开放通往森林出口的通路。场景还直接标出锈蚀守则、检修涂鸦与积水刻痕三条环境线索。
- 最终判定以实际状态为准：压力为 7 巴、绿阀为顺流、红阀恰好 1 次、蓝阀恰好 2 次、黄阀恰好 3 次。红阀在蓝阀之前、蓝阀在黄阀之前的前置限制和超过安全上限的自动重置仍然有效；不再因为交互帧中的冗余历史记录阻断正确完成。
- `WorldBounds/ForestExitPortal` 是右边界前的可编辑接触判定箱。主闸打开后，Sherry 接触该区域会经 `DayRuntime` 进入 `res://day/levels/forest/forest.tscn` 的 `from_sewer` 入口；第 1 天且恩佐尚未获救时，森林场景会自动启动 `forest_day_one_enzuo_intro` 剧情事件。
