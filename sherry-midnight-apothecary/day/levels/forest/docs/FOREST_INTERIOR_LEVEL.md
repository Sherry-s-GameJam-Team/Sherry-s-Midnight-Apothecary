# Forest Interior / 阿尔维斯母树树干爬塔关卡

## 设计目的

该场景是常霁云林林下四水车完成后的独立纵向爬塔关卡，采用双主角（雪莉 Sherry 与卢卡 Luca）实时切换与物理协同机关解谜，从母树底层一路攀登至树冠入口，直连树冠 Boss 场景（`res://day/levels/forest/crown/forest_crown.tscn`）。

**核心设计原则**：
- **无自动化存档点/传送同步机制**：取消阶段自动传送拉人机制，全流程依赖双主角真实的互助合作、机关配合与平台跳跃共同登顶。
- **右侧卢卡专属台阶天梯**：右侧设计一条直通塔顶（`TopLanding`）的连续灵体台阶（`LucaStep1` ~ `LucaStep67`，属于 `LucaWorldOnly` 碰撞层），每个关键操作节点分布着卢卡拉杆/控制台。卢卡沿右路攀登并在各节点操作机关，协助雪莉在现实世界（左/中路）向上攀爬，最终两人在顶部汇合。
- **差异化跳跃物理与间距适配**：根据雪莉与卢卡不同的跳跃高度与跨度精心设计阶梯式平台间距，保证两名角色均可顺畅通过。

## 角色跳跃物理与平台间距参数

| 参数项 | 雪莉 (Sherry) | 卢卡 (Luca) | 关卡平台设计标准 |
| :--- | :--- | :--- | :--- |
| **重力加速度 (Gravity)** | $900 \sim 950\text{ px/s}^2$ | $1400\text{ px/s}^2$（较沉重） | — |
| **跳跃起跳初速度** | $-550 \sim -620\text{ px/s}$ | $-550\text{ px/s}$ | — |
| **最大垂直跳跃高度** | $\approx 159 \sim 213\text{ px}$ | $\approx 108\text{ px}$ | **单阶最大台阶高度 $\Delta y \le 80\sim 85\text{ px}$** |
| **平地最大横向跨度** | $\approx 255 \sim 500+\text{ px}$ (奔跑跳) | $\approx 220\text{ px}$ | **跳台横向跨度 $\Delta x \le 140\sim 160\text{ px}$** |

## 碰撞层级与双世界交互规则

| 空间划分 | 碰撞层 (Collision Layer) | 可交互主角 | 行为表现 |
| :--- | :--- | :--- | :--- |
| **现实世界 (RealityWorld)** | **Layer 1 (实体) / Layer 2 (单向板)**（Mask: `1 \| 2 = 3`） | **雪莉 (Sherry) & 卢卡 (Luca)** | 基础地面、升降梯、旋转桥、水闸、大门等实体机关，两名主角均可正常站立、踩踏与碰撞。 |
| **卢卡世界 (LucaWorldOnly)** | **Layer 3 (灵体/机械层)**（Mask: `1 << 2 = 4`） | **仅限卢卡 (Luca Only)** | 右侧直通塔顶的灵体台阶（`LucaStep1` ~ `LucaStep67`）、灵体控制室浮空平台、树顶灵体桥（`LucaTopWalk`）与机械控制台，仅卢卡具备 Layer 3 碰撞遮罩（`collision_mask = 7`），雪莉（`collision_mask = 3`）直接穿透无视。 |

```text
ForestInterior
├─ EntryPoints
│  ├─ default (Marker2D, 320, 610)
│  ├─ from_forest (Marker2D, 320, 610)
│  └─ from_crown (Marker2D, 900, -4720)
├─ Player (Sherry)
│  ├─ SherryCollision
│  ├─ SherryPresentation
│  ├─ Camera2D (CameraBounds, limit_left=0, limit_top=-5450, limit_right=1800, limit_bottom=850)
│  └─ PotionThrower
├─ Luca (LucaPlayer runtime)
├─ RealityWorld (雪莉主升路线与现实世界实体)
│  ├─ StartGround (Y: 680)
│  ├─ RootLiftA (Y: 680 -> -280)
│  ├─ LiftAConsoleReality (Sherry 侧升降控制)
│  ├─ LeftB / RotatingRoot (回转根梁桥, Y: -580, 90° -> 0°) / RightB
│  ├─ StepB1..StepB4 (每阶 dy=85)
│  ├─ MudShortcut (污泥捷径, 净化药水可溶解) / MudStageLeft & Right
│  ├─ StepB5..StepB9 (每阶 dy=85 -> 75)
│  ├─ MidLanding (中层平台, Y: -1480)
│  ├─ StepS1..StepS3 (每阶 dy=85) -> SprayLeft (Y: -1820)
│  ├─ SprayMudA / SprayMid / SprayStep1 / SprayMudB / SprayRight
│  ├─ StepT1..StepT5 (每阶 dy=85) -> ComboLeft (Y: -2580)
│  ├─ SluiceGate (水闸门, Y: -2950) / RootLiftB (Y: -3050 -> -3680)
│  ├─ StepC1..StepC12 (阶段 4 螺旋台阶，每阶 dy=85) -> ControlLanding (Y: -3680)
│  ├─ StepCrown1..StepCrown8 (阶段 5 树冠大阶梯，每阶 dy=85)
│  ├─ FinalGate (最终根门, Y: -4250)
│  └─ TopLanding (Y: -4650, 双方终点汇合平台)
├─ LucaWorldOnly (卢卡专属右侧天梯与机械控制台，Layer 3)
│  ├─ LucaStep1..LucaStep67 (右侧直通塔顶的连续灵体台阶，每阶 dy=80, dx=140)
│  ├─ LiftAConsole (Y: 600, 卢卡操作底层升降机送雪莉上升)
│  ├─ RotateConsole (Y: -440, 卢卡旋转根梁桥梁助雪莉渡过断崖)
│  ├─ SprayDevice (Y: -1880, 卢卡操作高压水炮冲洗净化中层污泥)
│  ├─ SluiceConsole (Y: -2600, 卢卡操作开启水闸)
│  ├─ LiftBConsole (Y: -3080, 卢卡操作二阶升降机)
│  ├─ FinalGateConsole (Y: -3740, 卢卡操作开启最终大门)
│  ├─ UpperControlRoom (树冠动力控制室)
│  │  ├─ LiftRootPower / LiftWaterPower / LiftCrownPower (三路动力回路)
│  │  └─ DirectLift (直达树冠升降机 Area2D)
│  └─ LucaTopWalk (Y: -4650, 卢卡天梯终点连接 TopLanding)
├─ RespawnPoints (Bottom, LucaTopArrival)
├─ FallResetZone (坠落捕获，重置至底层起点)
├─ ExitToCrown (Area2D, Y: -4720, 交互直连 res://day/levels/forest/crown/forest_crown.tscn)
├─ UI (HUD 提示条、水枪压力面板、阶段转场淡入淡出、Luca 灵体视野滤镜)
├─ DebugUI (DeveloperConsole, layer = 200)
├─ PauseMenuLayer (PauseMenu, layer = 200)
└─ ForestController
   ├─ LucaWorldController
   └─ PartyController
```

## 五阶段双人协同攀登流程

1. **第一阶段：树心底层与初始升降梯（Y: 680 -> -280）**
   - 卢卡沿右侧专属台阶天梯起跳，到达 `LucaStep1` (Y: 600) 处的 `LiftAConsole`，按 E 启动 `RootLiftA` 升起雪莉；
   - 卢卡继续沿右侧天梯 `LucaStep2..13` 向上跳跃；雪莉在上层抵达 `LeftB` 平台。

2. **第二阶段：回转根梁与污泥障碍（Y: -280 -> -1480）**
   - 悬崖裂隙间古树根梁 `RotatingRoot` 默认垂直立起；卢卡跳至右侧 `LucaStep14` (Y: -440) 处的 `RotateConsole` 按 E 旋转根梁至水平，形成让雪莉通行的桥梁。
   - 雪莉通过桥梁后沿左/中路阶梯向上，投掷净化药水溶解阻挡主路的 `MudShortcut` 污泥，抵达中层 `MidLanding`；卢卡沿右侧天梯 `LucaStep15..31` 同步攀登。

3. **第三阶段：高压净水炮台与污泥清障（Y: -1480 -> -2580）**
   - 上方浮岛被重度污染泥沼（`SprayMudA`、`SprayMudB`）封锁。
   - 卢卡登上 `LucaStep32` (Y: -1880) 处的高压水枪炮台 `SprayDevice`（`W`/`S` 键调整仰角）喷射高压水流冲洗并彻底净化污泥，显露木质踏板。
   - 净化后，雪莉沿中路木板连续跳跃通过，抵达第四阶段平台 `ComboLeft`；卢卡沿右侧天梯 `LucaStep33..41` 继续向上。

4. **第四阶段：水闸水路与二阶升降机（Y: -2580 -> -3680）**
   - 升降机通路被重型根系水闸 `SluiceGate` 阻隔。
   - 卢卡在 `LucaStep41` (Y: -2600) 操作 `SluiceConsole` 开启水闸，在 `LucaStep47` (Y: -3080) 操作 `LiftBConsole` 升降平台，协助雪莉升至 `ControlLanding` (Y: -3680)。

5. **第五阶段：树冠动力控制室与终点汇合（Y: -3680 -> -4720）**
   - 卢卡在 `ControlDeck` 操作 `FinalGateConsole` 打开最终根门 `FinalGate`，并可激活三处动力回路解锁 `DirectLift`。
   - 雪莉沿树冠大阶梯 `StepCrown1..8` 向上跳跃；卢卡沿右侧天梯终段 `LucaStep55..67` 向上跳跃，最终双方在顶层大平台 `TopLanding` (Y: -4650) 胜利汇合！
   - 靠近 `ExitToCrown` 按 E，进入母树树冠 `forest_crown.tscn` 展开炽天使 Boss 战。
