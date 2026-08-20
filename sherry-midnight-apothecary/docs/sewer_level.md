# 流明街旧引水渠

`res://day/levels/market/sewer/sewer.tscn` 是从血色喷泉通往常霁云林的横向过渡关卡。场景以旧维阿利亚引水渠为背景：拱形石墙、被树根撑裂的砖缝，以及会映出墙体的异常赤色水流。

- `Environment/Water` 使用 `shaders/sewer_water.gdshader`。水层保留原画中的倒影，再叠加时间驱动的双频波纹与破碎高光。
- 背景固定在正向绘制层：水层为 `Environment` 的 0 层，左右建筑遮罩依次为 1、2 层。这样关卡嵌入上层场景流时不会落到父级的背景之后。
- 角色活动在 `WorldBounds/Walkway` 的中间石质通路（y = 526）上；水层只作为通路前后的视觉危险，不承担移动碰撞。
- 场景配置 Sherry、随行的 Luca、进入/离开标记，以及 HP、任务和地点 UI，供剧情系统后续接入。
- `SewerLucaFollow` 通过 Luca 已有的外部移动接口驱动同伴跟随：相距 250px 后开始跟进、回到 140px 内才停留，间隔达到 620px 时提升至追赶速度。Luca 不接收玩家输入，也不与 Sherry 发生实体碰撞。
- `CharacterReflections` 负责 Sherry 的镜像表现。Luca 使用其场景实例下的 `LucaWaterReflection` 直接读取父节点当前动画帧并水线镜像，从而不依赖集中控制器的层级或可见性状态。Luca 倒影在镜像位置下移 10px，垂直高度为原先的 3 倍（压缩系数 0.6）；两者均使用相同的赤色波纹 shader 与 water alpha 蒙版，且不参与碰撞或输入。
