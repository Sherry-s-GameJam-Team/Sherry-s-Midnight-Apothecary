# 奥伦钟庭 (Aurem Clockyard) 与巨钟塔爬塔关卡 (Inside)

## 概述
奥伦钟庭包含两个核心关卡场景：
1. **外庭探索关卡** (`res://day/levels/Aurem Clockyard/aurem_clockyard.tscn`)：展现融合齿轮工坊、金穗农庄与奥伦巨钟塔外观的精密机械庭院。
2. **巨钟塔内部爬塔关卡** (`res://day/levels/Aurem Clockyard/inside.tscn`)：约 6～8 分钟的四层纵向机械爬塔与塔顶收尾谜题，逐层修复三个校时节点并重同步主钟。

---

## 巨钟塔内部爬塔关卡 (inside.tscn)

### 关卡目标与故事背景
“机械之灾”导致中央巨钟塔失去统一时律：齿轮倒转、摆锤错拍、主发条能量过载、指针反噬。雪莉从塔底一路向上逐层修复三个校时节点，最终在塔顶三环校时台重新同步奥雷姆钟庭。

### 楼层流程与核心机制
| 楼层 | 区域 | 核心机制 | 修复节点 / 关卡目标 |
| :--- | :--- | :--- | :--- |
| **第一层** (Y: 0 ~ -800) | **发条与工坊层** (Clockwork Chamber) | 吊链与卷扬机跳跃解密：利用低矮跳石、悬挂长链平台、升降卷扬机吊台、阶梯式梯架平台与滑移吊车横跨深壑，在规避机械蒸汽的同时逐级向上攀登 | **校时节点Ⅰ：主发条限位器** (稳定下层管线并平复吊机) |
| **第二层** (Y: -900 ~ -2000) | **齿轮井** (Gear Well) | 齿轮相位：顺转、反转逆流、失速齿轮。拉动**校准杆**触发 6 秒齿轮同步对齐楼梯 | **校时节点Ⅱ：齿轮差速器** (统一齿轮转速) |
| **第三层** (Y: -2000 ~ -3200) | **钟摆厅** (Pendulum Hall) | 钟摆搭乘与节拍预兆：中央巨型摆锤扫过深壑，钟声提前 0.8s 预警。顶部**橙色节拍灯**预告跳拍异常（1闪正常，2闪异常） | **校时节点Ⅲ：擒纵机构** (恢复标准摆频) |
| **第四层** (Y: -3200 ~ -4200) | **指针层** (Clock Hands Floor) | 钟面平台与手轮校调：12 个时间刻度，转动手轮使分针指向 Ⅲ 开门拿隐藏药材，指向 Ⅻ 对齐通向塔顶之路。指针倒退前具有 1s 齿轮磨损震动预警 | **开启塔顶登顶通道** |
| **塔顶** (Y: -4200 ~ -5000) | **塔顶校时台** (Tower Top Synchronizer) | **三系统大校时谜题**：三组同心圆环（外环发条、中环齿轮、内环钟摆），操纵机台将三道刻度对齐 12 点钟，触发宏大铜钟轰鸣与全城时律复苏演出 | **钟庭全面恢复** (`aurem_clockyard_tower_synchronized`) |

### 辅助系统与药水交互
1. **纯粹纵向攀登体验**：
   - 关卡采用纯粹的经典物理坠落机制（无自动黑屏传送/FallReset），玩家失误掉落会直接坠至下方平台或底层，保留高空跃迁的紧张感与技巧成就感。
2. **雪莉药水能力交互 (`receive_potion_hit`)**：
   - **冰药水 (Blue/Ice)**：冻结暴走/失速齿轮与卷扬吊机 4 秒，提供安全立足点；直接冻结三环谜题至 12 点。
   - **爆炸药水 (Red/Bomb)**：破坏卡死锁具，击退失准齿轮灵与逆行钟鸟。
   - **活化药水 (Orange/Speed)**：为停转机关与卷扬机注入魔力，快速推进手轮与指针。
3. **钟庭机械敌人**：
   - **失准齿轮灵 (`GearSpirit`)**：在平台间巡逻滚动的齿轮生物。
   - **逆行钟鸟 (`RetroClockbird`)**：反向飞行并在上方投放黄铜螺栓的报时鸟造物。
4. **声音合成器 (`ClocktowerAudio`)**：
   - 程序化合成机械滴答声、蒸汽喷射声、齿轮卡合声、磨损预警声、钟鸣预警声及塔顶震撼的黄钟大吕回响 (`play_grand_synchronization_toll`)。

---

## 场景结构与美术资源映射
```text
Inside (AuremClocktowerInsideLevel)
├─ ClocktowerAudio (ClocktowerAudio 音频合成器)
├─ Background (深色钟塔砖墙与哥特背板)
├─ WorldBounds (左右屏障与上下世界边界)
├─ World
│  ├─ Floor1_SpringChamber (Clockwork Chamber)
│  │  ├─ PressureGauge (Sprite2D)
│  │  ├─ Platform1_LowStone + Platform2_Chain + Platform3_RightArch
│  │  ├─ Platform4_LadderGantry + Platform5_HighBridge + PlatformNode1
│  │  ├─ WinchLifts (WinchLift1, WinchLift2_Crane)
│  │  └─ CalibrationNode1 (CalibrationNode: 主发条限位器)
│  ├─ Floor2_GearWell
│  │  ├─ GearPlatform1~3 (GearPlatform: 正转/反转/失速)
│  │  ├─ StairGear1~3 (GearPlatform: 3 组错位阶梯齿轮)
│  │  ├─ CalibrationLever (CalibrationLever: 6s 齿轮同步拉杆)
│  │  ├─ GearSpiritEnemy (GearSpirit: 巡逻齿轮灵)
│  │  └─ CalibrationNode2 (CalibrationNode: 齿轮差速器)
│  ├─ Floor3_PendulumHall
│  │  ├─ TelegraphLight (BeatTelegraphLight: 节拍预兆灯)
│  │  ├─ SwingingPendulum (SwingingPendulum: 巨型搭乘摆锤)
│  │  ├─ ClockbirdEnemy (RetroClockbird: 逆行钟鸟)
│  │  └─ CalibrationNode3 (CalibrationNode: 擒纵机构)
│  ├─ Floor4_ClockHands (ClockHandsFloor)
│  │  ├─ ClockDialBg (Sprite2D) + ClockCenter
│  │  │  ├─ HourHand (AnimatableBody2D 时针跳台)
│  │  │  └─ MinuteHand (AnimatableBody2D 分针跳台)
│  │  └─ HandCrankArea (Area2D 手轮) + SecretGate3 (StaticBody2D Ⅲ号密室门)
│  ├─ TowerTop (TowerTopSynchronizer)
│  │  ├─ DialBase (三环大校时底盘)
│  │  │  ├─ OuterRing + MiddleRing + InnerRing
│  │  ├─ Consoles (OuterLockConsole, MiddleLockConsole, InnerLockConsole)
│  │  ├─ CelebrationGlow (Sprite2D 胜利金辉)
│  │  └─ ExitPortal (DoorPortal 离开界门)
│  └─ Portals (EntrancePortal 底部出口)
├─ EntryPoints (default, floor2, floor3, floor4, top)
├─ Player (DayPlayerController + SherryCollision + SherryPresentation + PotionThrower + Camera2D)
├─ DebugUI (DeveloperConsole)
└─ PauseMenuLayer (PauseMenu)
```

---

## 验证
运行独立自动化测试：
```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/run_aurem_inside_test.gd
```
