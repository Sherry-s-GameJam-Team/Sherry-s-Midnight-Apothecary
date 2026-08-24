# 维斯佩尔梦疗院院长 Boss 战规范 (Vespervale Director Boss)

## 概述
“维斯佩尔梦疗院院长”是维斯佩尔梦疗院的守关 Boss，位于深层病院花园 (`res://day/levels/Vespervale/vesper_boss.tscn`)。
Boss 主题为**错误的治疗、梦境扭曲、提灯巡房、镇静剂投掷、梦潮与幽眠攫手、月盾护体**。

---

## 一、关卡与场景结构

### 场景文件与资源
- **场景路径**：`res://day/levels/Vespervale/vesper_boss.tscn`
- **关卡定义**：`res://day/levels/Vespervale/vesper_boss_level.tres`
- **背景美术**：`res://day/levels/Vespervale/treegarden.png`（紫色梦幻巨木病院花园）
- **入口点**：`EntryPoints/from_hospital` (Vector2(240, 580)) 与 `EntryPoints/default`

### 节点层次架构
```
VesperBossArena (Node2D, vesper_boss_arena.gd)
├── Background (TreegardenBG)
├── WorldBounds (Ground, LeftBarrier, RightBarrier)
├── Platforms (Platform1, Platform2 - 花坛平台跳跃避险点)
├── BossRoot
│   └── VesperDirectorBoss (CharacterBody2D, vesper_director_boss.gd)
│       ├── AnimatedSprite2D (director_sprite_frames.tres)
│       ├── ShieldFX (月盾.png)
│       ├── CastPoint (Marker2D)
│       ├── Hurtbox (Area2D in group "potion_target")
│       └── LanternSweepArea (提灯横扫判定与预警)
├── BulletLayer (弹幕层)
├── HazardLayer (地面召唤阵与危险物)
├── FXLayer (DreamTideVignette 梦潮紫光环境遮罩)
├── World
│   └── Portals
│       └── ExitPortal (战后激活通往暮息庭院的传送门)
├── EntryPoints (from_hospital, default)
├── Player (DayPlayerController, Camera2D, PotionThrower)
└── UI
    ├── VesperBossHUD (vesper_boss_hud.tscn, 血条/硬直预告/梦潮状态)
    └── VictoryBanner (净化通关结算横幅)
```

---

## 二、战前剧情对话 (`vesper_boss_intro.dialogue`)

进入场景后自动触发雪莉与院长的对峙剧情对话（期间锁定玩家控制，Boss 保持待机状态）：

```dialogue
院长: 这里是疗养院，请保持安静。
雪莉: 你就是这里的院长？
院长: 曾经是。
雪莉: 那就让这里停下来。外面的人已经被困在梦里太久了。
院长: 他们只是终于不再痛苦。
雪莉: 一直睡着可不算治好。
院长: 醒来，才会重新受伤。
雪莉: 那我就先让你醒过来。
院长: ……拒绝治疗。
# [院长缓缓举起提灯。]
院长: 开始强制安眠。
```
对话结束后，自动恢复玩家操控权限、激活 Boss HUD 并正式开启战斗！

---

## 三、Boss 动画与体型规范 (`director_sprite_frames.tres`)

- **体型放大 2 倍**：Boss 整体尺寸调整为 2x（`scale = Vector2(0.48, 0.48)`，胶囊碰撞体高度提升至 340px，受击判定半径 120px）。
- **朝向修正**：校准贴图翻转逻辑（`anim_sprite.flip_h = dir > 0.0`），确保院长始终正面注视玩家。
- **智能追踪巡场机制**：
  - Boss 在待机（`IDLE`）与硬直恢复（`RECOVERY`）期间会自动追踪玩家 X 轴方位移动（保持约 280px 的作战距离，过近自动微退）。
  - **防卡死墙角限制**：移动范围严格限制在 `[min_patrol_x = 400.0, max_patrol_x = 1520.0]`，绝不跟入场景角落。
- **大号史诗 Boss 血条 (`vesper_boss_hud.tscn`)**：
  - 宽度扩展至 920px（840px 主血条，高度 32px），搭配黄白双层延迟下落 GhostBar。
  - 居中显示醒目的清晰数值血量文本（`HP %d / %d`），24px 华丽 Boss 称号，以及状态阶段动态提示。
- **大幅强化攻击伤害**：
  - Boss 基础生命值提升至 300 HP。
  - 全屏激光判定线：35.0 伤害；提灯近身横扫：35.0 伤害。
  - 幽眠鬼手：30.0~32.0 伤害；月牙剑气波：30.0 伤害；追踪灵火：25.0 伤害；月相魔弹：22.0 伤害；镇静剂迷雾：20.0 伤害。


精准配置 `res://day/levels/Vespervale/boss/frames/` 下的 6 组 24fps 动作序列（共 121 帧，`boss_000.png` ~ `boss_120.png`）：
1. `idle_charge`：`111-120` 链接 `000-009` 正逆 ping-pong 循环（蓄力/待机循环）
2. `lantern_sweep`：`010-048`（提灯扇形横扫）
3. `tranquilizer_throw`：`048-064`（镇静剂连续抛掷）
4. `dream_hands_summon`：`064-084`（幽眠攫手召唤）
5. `deep_dream_burst`：`084-101`（深层梦境大招爆发）
6. `recovery_idle`：`101-111`（受击/清醒虚弱/战败恢复待机循环）


---

| 素材文件 / 机制 | 对应技能 | 技能机制表现 |
| :--- | :--- | :--- |
| **`鬼手召唤阵.png` / `dream_grasp_hand_unit`** | **幽眠自动寻敌鬼手** | 召唤源自深层走廊（inner）的幽眠攫手追踪器（`BossDreamGraspTracker`），平滑追踪主角地面投影；**主角跃上 Platform1 平台即可彻底躲避追踪** |
| **`BossBeamHazard`** | **全场景极光判定线** | 提灯横扫与大招爆发时释放贯穿整个场景的警戒红线（0.6s 预警），随后爆发全屏梦境光柱，考验跳跃避险走位 |
| **`ball.png`** | **月相魔弹全屏环射** | 多波次 360° 与扇形高密度扩散弹幕，覆盖全场地面与浮空平台 |
| **`剑气.png`** | **梦境三重月牙波** | 提灯挥斩释放上、中、下三重高速贯穿全场的月牙剑气波 |
| **`魂火.png`** | **高机动追踪灵火** | 释放 3~5 枚高速追踪灵火，持续紧咬主角方位 |
| **`药水投掷.png`** | **镇静剂药瓶** | 抛物线预判投掷，落地生成大范围镇静迷雾 |
| **`月盾.png`** | **月盾护体** | 梦潮期提供 70% 伤害减免；受到净化药水（`purify`）命中可瞬间击碎并强制进入清醒虚弱窗口 |
| **药水命中与伤害系统** | **药水战斗判定** | Boss 实体开启碰撞层并支持 `receive_potion_hit` 与 `apply_potion_effect`，直接命中与溅射均能造成真实伤害并触发受击受挫硬直闪烁 |


---

## 四、核心战斗机制：梦潮与清醒窗口循环

1. **梦潮期 (Dream Tide)**：
   - 每 6 秒触发一次，持续约 2.8 秒。
   - 全场微弱变暗并覆盖紫色梦境波纹，地面危险与召唤阵触发频率加快。
   - Boss 激活月盾（大幅减伤），压制普通攻击。
2. **清醒窗口 (Lucid Window)**：
   - 梦潮结束后进入持续 3.0 秒的清醒窗口。
   - 色调回正，月盾解除，Boss 受到伤害提升 30%，为玩家投掷爆发的最佳输出时机。

---

## 五、三阶段推进

- **Phase 1 (100% ~ 70%)**：
  - 节奏明朗的教学阶段。
  - 技能：提灯扫视 + 镇静剂抛投 + 单/双鬼手召唤阵。
- **Phase 2 (70% ~ 35%)**：
  - 引入月盾护体 + 5 发扇形月相魔弹 + 缓慢追踪魂火。
  - 考验走位与利用清醒窗口输出。
- **Phase 3 (35% ~ 0%)**：
  - 梦境完全暴走，追加月牙斩击波 + 三重鬼手突刺 + 360° 全方位深层梦境爆发（Deep Dream Burst）。

---

## 六、战后结算与关卡衔接

- Boss 血量归零后：
  1. 播放战败淡出动画，停止梦潮循环并即刻清除场地上的所有残留弹幕与召唤阵。
  2. 弹出“✦ 维斯佩尔梦疗院已被净化 ✦”通关金辉横幅。
  3. 解锁场景右侧的 `ExitPortal`，玩家可按 `E` 键随时返回暮息庭院。
- 从回廊 (`inner.tscn`) 进入方式：
  - 原无尽走廊回弹机制已取消，玩家沿长廊向右行进至最右侧边界即可直接无缝黑屏传送到深层花园 Boss 场景。
