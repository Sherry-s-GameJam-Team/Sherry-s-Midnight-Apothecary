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

自动切分与识别 `res://day/levels/Vespervale/boss/segments/` 下的 6 组 24fps 动作序列：
1. `idle_charge`：蓄力/待机循环
2. `lantern_sweep`：提灯扇形横扫
3. `tranquilizer_throw`：镇静剂连续抛掷
4. `dream_hands_summon`：幽眠攫手召唤
5. `deep_dream_burst`：深层梦境大招爆发
6. `recovery_idle`：受击/清醒虚弱/战败恢复

---

## 三、弹幕与技能映射

| 素材文件 | 对应技能 | 技能机制表现 |
| :--- | :--- | :--- |
| **`药水投掷.png`** | **镇静剂药瓶** | 抛物线投掷，落地后生成紫色镇静迷雾（持续 2.8 秒），触碰造成减速与持续伤害 |
| **`鬼手召唤阵.png`** | **幽眠攫手** | 目标地面出现预警法阵（持续 0.85 秒），随后幽暗鬼手向上破土突刺并造成爆发伤害 |
| **`ball.png`** | **月相魔弹** | 阶段 II 起使用，5 发 / 7 发扇形散射紫光弹幕 |
| **`魂火.png`** | **追踪灵火** | 阶段 II 起召唤 2~3 枚慢速追踪玩家的幽火，持续 3~4 秒后自然消散 |
| **`剑气.png`** | **梦境月牙波** | 阶段 III 提灯横扫后追加高速水平切入的月牙斩击 |
| **`月盾.png`** | **月盾护体** | 梦潮期为 Boss 提供 70% 伤害减免；受到净化药水（`purify`）命中可瞬间击碎并强制破防 |

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
