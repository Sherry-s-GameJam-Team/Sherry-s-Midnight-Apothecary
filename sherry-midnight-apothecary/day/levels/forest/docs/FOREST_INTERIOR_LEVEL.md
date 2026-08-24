# Forest Interior / 阿尔维斯母树树干爬塔关卡

## 设计目的

该场景是常霁云林林下四水车完成后的独立纵向爬塔关卡，采用雪莉（Sherry）单主角操作，融合单向跳跃平台、药水净化与机关解谜，从母树底层一路攀登至树冠入口，直连树冠 Boss 场景（`res://day/levels/forest/crown/forest_crown.tscn`）。

**核心设计原则**：
- **单主角自主攀登与解谜**：删去角色切换与灵体专属平台，全流程由雪莉一人独立探索、操作各处古树机关、投掷药水与操纵水枪净水设施。
- **单向跳跃平台体系**：利用 `res://day/levels/forest/interior/art/` 的美术资源（木桩 `stump`、木梁 `beam`、升降板 `lift`、木桥 `bridge` 等）搭建单向通过平台（`collision_layer = 3`, `one_way_collision = true`），支持从下方跳起穿透与向下按 [S] 穿下。
- **严格适配雪莉物理参数**：平台垂直高度 $\Delta y \le 85\sim 95\text{ px}$，横向跨度 $\Delta x \le 160\text{ px}$，契合雪莉的跳跃高度（行走跳 159 px，奔跑跳 213 px）与碰撞箱尺寸（$56 \times 76$ px）。

## 角色跳跃物理与平台间距参数

| 参数项 | 雪莉 (Sherry) | 关卡平台设计标准 |
| :--- | :--- | :--- |
| **重力加速度 (Gravity)** | $900 \sim 950\text{ px/s}^2$ | — |
| **跳跃起跳初速度** | $-550 \sim -620\text{ px/s}$ | — |
| **最大垂直跳跃高度** | $\approx 159 \sim 213\text{ px}$ | **单阶最大台阶高度 $\Delta y \le 85\sim 95\text{ px}$** |
| **平地最大横向跨度** | $\approx 255 \sim 500+\text{ px}$ (奔跑跳) | **跳台横向跨度 $\Delta x \le 160\text{ px}$** |
| **穿板碰撞掩码** | Layer 1 (实体) + Layer 2 (单向板) | 单向板 `collision_layer = 3`, `one_way_collision = true` |

## 场景结构

```text
ForestInterior
├─ Background (Node2D, 全程单图覆盖式视差背景系统)
│  ├─ CorruptedBackground (Parallax2D, 单张连续未拼接图, 腐化暗调, scroll_scale=(0.2, 0.35))
│  ├─ NormalBackground (Parallax2D, 单张连续未拼接图, 纯净常调, scroll_scale=(0.2, 0.35))
│  └─ CentralStream (树干中央流层系统, 着色器流动特效, scroll_scale=(0.3, 0.45))
│     ├─ BloodStream (Parallax2D, 腐化血流层 forest_interior_blood_stream.png)
│     └─ ClearStream (Parallax2D, 净水流层 forest_interior_clear_stream.png)
├─ HomeDoor (DoorPortal, Day 1 树冠 Boss 净化后启动；按 E 返回药水铺 home.tscn)
├─ ForestReturnDoor (DoorPortal, 按 E 返回常霁云林 forest.tscn)
├─ EntryPoints (default, from_forest, from_home, from_crown)
├─ Player (Sherry, 初始位置 445, 618)
│  ├─ SherryCollision
│  ├─ SherryPresentation
│  ├─ Camera2D (limit_left=0, limit_top=-5450, limit_right=1800, limit_bottom=850)
│  └─ PotionThrower
├─ RealityWorld (现实世界平台与互动谜题)
│  ├─ StartGround (Y: 680)
│  ├─ LiftAConsole (Y: 578, 操作升降根 RootLiftA 升起)
│  ├─ RootLiftA (Y: 680 -> -280)
│  ├─ RotateConsole (Y: -420, 旋转根梁桥梁)
│  ├─ LeftB / RotatingRoot (回转根梁桥, Y: -580, 90° -> 0°) / RightB
│  ├─ StepB1..StepB4 (阶梯跳台)
│  ├─ MudShortcut (污泥捷径, 净化药水/水枪可溶解) / MudStageLeft & Right
│  ├─ StepB5..StepB9 -> MidLanding (中层平台, Y: -1480)
│  ├─ StepS1..StepS3 -> SprayLeft (Y: -1820)
│  ├─ SprayDevice (高压净水炮台, [E] 操作, [W]/[S] 瞄准)
│  ├─ SprayMudA / SprayMid / SprayStep1 / SprayMudB / SprayRight
│  ├─ StepT1..StepT5 -> ComboLeft (Y: -2580)
│  ├─ SluiceConsole (Y: -2600, 开启水闸)
│  ├─ SluiceGate (水闸门, Y: -2950)
│  ├─ LiftBConsole (Y: -3080, 开启二阶升降梯)
│  ├─ RootLiftB (二阶升降平台, Y: -3050 -> -3680)
│  ├─ StepC1..StepC12 -> ControlLanding (Y: -3680)
│  ├─ FinalGateConsole (Y: -3740, 开启最终根门)
│  ├─ FinalGate (最终根门, Y: -4250)
│  ├─ UpperControlRoom (动力回路与直达升降梯)
│  ├─ StepCrown1..StepCrown8 -> TopLanding (Y: -4650, 顶层平台)
│  └─ ExitToCrown (Area2D, Y: -4720, [E] 前往母树树冠 forest_crown.tscn)
├─ RespawnPoints (Bottom, TopArrival)
├─ FallResetZone (坠落保护)
├─ UI (HUD 提示条、水枪压力条、黑屏淡入淡出)
├─ DebugUI (DeveloperConsole)
└─ PauseMenuLayer (PauseMenu)
```

## 返回旅门与地图锚点

`HomeDoor` 与地图中的“阿尔维斯母树”锚点均以 `tutorial_flags["forest_completed"]` 为开启条件。第一天树冠 Boss 净化前，HomeDoor 保持可见但提示“旅门尚未启动”且不会传送；MapSwitch 不会解锁 `forest_interior`，因此对应地图目的地维持未启动状态。Boss 净化完成时，树冠控制器立即解锁 `forest_interior` 锚点，HomeDoor 也可正常返回药水铺。

## 五阶段攀登流程

1. **第一阶段：树心底层与初始升降梯（Y: 680 -> -280）**
   - 雪莉从底层 `StartGround` 出发，在 `LiftAConsole` 按 [E] 启动 `RootLiftA`，站在升降平台上平稳上升至 `LeftB` 平台。

2. **第二阶段：回转根梁与污泥障碍（Y: -280 -> -1480）**
   - 面对断崖，在 `RotateConsole` 按 [E] 将垂直生长的古树根梁 `RotatingRoot` 旋转至水平，形成通往右岸 `RightB` 的横向木桥。
   - 沿 `StepB1..StepB4` 阶梯向上，投掷净化药水溶解阻挡通道的 `MudShortcut` 污泥，沿 `StepB5..StepB9` 登临中层大平台 `MidLanding`。

3. **第三阶段：高压净水炮台与空中浮岛（Y: -1480 -> -2580）**
   - 沿 `StepS1..StepS3` 到达 `SprayLeft`，走近 `SprayDevice` 按 [E] 进入水枪操控视角。
   - 使用 [W] / [S] 调整水流仰角，射出高压水柱冲洗并净化远处的两处污泥堆（`SprayMudA` 与 `SprayMudB`）。
   - 污泥化解后，借助显露出的单向木板跨越浮岛，抵达第四阶段平台 `ComboLeft`。

4. **第四阶段：水闸水路与二阶升降机（Y: -2580 -> -3680）**
   - 在 `SluiceConsole` 按 [E] 升起重型木质水闸 `SluiceGate`。
   - 随后在 `LiftBConsole` 启动升降机 `RootLiftB`（或沿螺旋阶梯 `StepC1..StepC12` 向上跳跃），顺利登顶至 `ControlLanding` (Y: -3680)。

5. **第五阶段：树冠大门与树冠入口（Y: -3680 -> -4720）**
   - 在 `FinalGateConsole` 按 [E] 开启最终根门 `FinalGate`。
   - 沿树冠大阶梯 `StepCrown1..StepCrown8` 跃升至顶层大平台 `TopLanding` (Y: -4650)。
   - 在 `ExitToCrown` 处按 [E] 触发进入母树树冠场景（`forest_crown.tscn`），开启炽天使 Boss 战！
