# 流明街旧引水渠

`res://day/levels/market/sewer/sewer.tscn` 是从血色喷泉通往常霁云林的横向过渡关卡。场景以旧维阿利亚引水渠为背景：拱形石墙、被树根撑裂的砖缝，以及会映出墙体的异常赤色水流。

- `Environment/Water` 使用 `shaders/sewer_water.gdshader`。水层保留原画中的倒影，再叠加时间驱动的双频波纹与破碎高光。
- 背景固定在正向绘制层：水层为 `Environment` 的 0 层，左右建筑遮罩依次为 1、2 层。这样关卡嵌入上层场景流时不会落到父级的背景之后。
- 角色活动在 `WorldBounds/Walkway` 的中间石质通路（y = 526）上；水层只作为通路前后的视觉危险，不承担移动碰撞。
- 场景配置 Sherry、随行的 Luca、进入/离开标记，以及 HP、任务和地点 UI，供剧情系统后续接入。
- `SewerLucaFollow` 通过 Luca 已有的外部移动接口驱动同伴跟随：相距 250px 后开始跟进、回到 140px 内才停留，间隔达到 620px 时提升至追赶速度。Luca 不接收玩家输入，也不与 Sherry 发生实体碰撞。
- `CharacterReflections` 在 y = 516 的主角地平线下镜像 Sherry 与 Luca 的独立表现节点，并同步两人的当前动画。镜像 shader 以两张 water 铺图的 alpha 通道作联合蒙版，因此水贴图外（包括透明通路）绝不显示倒影；它不参与碰撞或输入。
