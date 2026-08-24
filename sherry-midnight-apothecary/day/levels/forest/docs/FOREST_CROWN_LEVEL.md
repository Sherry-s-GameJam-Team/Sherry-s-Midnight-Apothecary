# Forest Crown / 阿尔维斯母树树冠·炽天使 Boss 战

## 设计目的

该场景是阿尔维斯母树树干爬塔完成后的独立 Boss 关卡（`res://day/levels/forest/crown/forest_crown.tscn`）。
核心体验聚焦于**在暴雨与黑魔法干扰中寻找净化窗口**，全流程使用雪莉现有的**药水投掷系统（`purification_potion`）**，不另做攻击键。战斗时长约 3～4 分钟，分为三阶段战斗与最终净化。

## 场景路径与结构

```text
res://day/levels/forest/crown/
├── forest_crown.tscn
├── forest_crown.gd
├── forest_crown_level.tres
├── seraph_boss.gd
├── seraph_weakpoint.gd
├── blood_rain_controller.gd
├── corruption_ring.gd
└── crown_vfx_controller.gd
```

### 节点合同

```text
ForestCrown
├─ Background
│  ├─ CrownBackground
│  ├─ GloomyOverlay (暗调暴雨迷雾滤镜 Shader)
│  ├─ RainLayerFar (远景雨幕粒子，z_index = -28)
│  ├─ RainLayerMid (中景斜雨粒子，z_index = -5)
│  └─ LightningOverlay (远雷与雨夜电光)
├─ Arena
│  ├─ MainPlatform (中央王莲)
│  ├─ LeftPlatform (左高台) / RightPlatform (右高台)
│  ├─ LeftStep / RightStep
│  ├─ PlatformSplashes (平台地表溅水反弹粒子)
│  ├─ ArenaBounds
│  └─ FallZone (掉落重置)
├─ Boss (SeraphBoss)
│  ├─ SeraphSprite (侵蚀形态)
│  ├─ SeraphNormalSprite (恢复形态)
│  ├─ BossBody (碰撞与药水命中响应)
│  ├─ HaloOuter (外光环)
│  ├─ HaloInner (内光环)
│  ├─ CorruptionCore (污染核心 + 弱点)
│  └─ AttackOrigins
├─ Hazards
│  ├─ BloodRain (血雨落柱)
│  ├─ FeatherStorm (黑羽弹幕)
│  └─ CorruptionWaves (地面冲击波)
├─ Player (DayPlayerController + PotionThrower + Camera2D)
├─ RainLayerForeground (近景快速雨丝，z_index = 25)
├─ EntryPoints
│  ├─ default
│  └─ from_interior
├─ ExitPortal (通往森林出口)
├─ UI
│  ├─ PurificationGauge (污染程度 100% -> 0%)
│  ├─ BossHint
│  ├─ ShockwaveRect (净化冲击波 Shader)
│  └─ FadeRect
├─ DebugUI (DeveloperConsole, layer = 200)
├─ PauseMenuLayer (PauseMenu, layer = 200)
└─ CrownVFX (CrownVFXController)
```

## Boss 机制与三阶段流转

使用 `corruption = 100`（污染程度百分比），不使用普通 HP。

### 第一阶段：血雨（100% → 70%）
- **Boss 状态**：六翼蜷缩，悬浮中央。
- **环境威胁**：`BloodRainController` 周期性随机生成 3～4 个预警点（1.2 秒地表红圈 + 红色警戒线），随后落下 0.7 秒血雨柱（碰撞造成 10 点伤害）。
- **弱点机制**：Boss 周围有一圈 `HaloOuter`。向光环弱点投掷 3 次 `purification_potion` 击破光环。
- **净化窗口**：光环破裂后进入 5 秒虚弱窗口，投掷 1 瓶净化药水使污染度降至 70%，强制进入第二阶段。

### 第二阶段：羽翼暴走（70% → 35%）
- **Boss 状态**：展开六翼，生成双重旋转黑魔法光环（外环顺时针、内环逆时针）。
- **攻击模式**：
  - Pattern A（扇形）：向下发射 5 枚羽片。
  - Pattern B（左右交错）：交替扫过平台。
  - Pattern C（慢速追踪）：2 枚黑羽短暂停留后锁定投掷。
  - 羽毛可用 `purification_potion` 直接打消。
- **弱点机制**：双光环共有 4 个发光净化弱点（`SeraphWeakpoint`），利用抛物线与子弹时间瞄准投掷，击破全部 4 个弱点后 Boss 倒地 6 秒。
- **净化窗口**：向 Boss 连续投掷 2 瓶净化药水，污染度降至 35%，进入第三阶段。

### 第三阶段：血泪核心（35% → 1%）
- **Boss 状态**：炽天使痛苦蜷缩，头顶浮现巨大黑紫色 `CorruptionCore`（污染核心）。
- **环境威胁**：核心周期性向地表释放巨大圆形冲击波（跳跃或站上左/右高台可避开）。
- **弱点机制**：核心拥有 3 层污染膜，向核心投掷 3 瓶净化药水逐层剥离并摧毁核心，Boss 污染降至 1%，进入最终净化。

### 最终净化与恢复演出（1% → 0%）
- 暴雨停歇，雷鸣平息，屏幕提示：`“净化她。”`
- 玩家投出最后一瓶 `purification_potion` 命中 Boss。
- **演出效果**：
  - 全屏径向净化冲击波扩散（`ShaderMaterial` 从中心蔓延至全屏）。
  - 黑色颗粒从炽天使身上剥落并消散。
  - `SeraphSprite`（侵蚀）平滑淡出，`SeraphNormal`（圣洁）平滑淡入。
  - 天空背景转为晴朗金绿，雨滴停止。
  - 中央主平台生成 `ExitPortal`（直达升降梯 `DirectLift`，贴图 `forest_direct_lift.png`），按 [E] 触发黑色渐隐平滑切换至外部森林的 `forest/from_crown`。该入口会触发第一日恩佐救援收束对话。
  - 自动设置教程与探索完成标记：`forest_completed = true`、`forest_crown_completed = true`。
  - 演出结束后先显示“常霁云林·血泉异变”任务完成 UI；玩家关闭该 UI 后，播放炽天使苏醒对白 `forest_crown_purification.dialogue` 的 `start` 段。
  - 对白中的镜头/环境叙述使用注释；任务更新、快速旅行解锁等系统通知通过 `TopHintUI` 的 `show_hint(...)` 指令显示。

## 数据与全局集成

- `DayRuntime.LEVELS` 注册 `forest_crown_level.tres`。
- `ForestInterior` 顶层出口 `ExitToCrown` 直连 `forest_crown`（入口 `from_interior`）。
- 自动化测试用例位于 `tests/forest_crown_smoke_test.gd`。
