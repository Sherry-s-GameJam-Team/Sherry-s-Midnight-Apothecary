# 暮息庭院 (Vespervale Garden) 关卡

## 概述
暮息庭院 (`res://day/levels/Vespervale/garden.tscn`) 是 Vespervale（暮息谷）区域的核心白天探索关卡。
关卡包含暮光小镇前庭、常青树庭院、暮息花园（现实/梦境双重态）与静语礼堂前庭。

---

## 关卡特性与设计规范

### 1. 非重复背景部署 (Non-Repeating Static & Parallax Background)
- 遵循不使用重复滚轴（无 Parallax2D `repeat_size` / `repeat_times` 循环滚动）的设计规范。
- 采用多层精确定位的视觉结构：
  - **远景层 (FS / Sky, z_index: -30)**：`FS.png` 作为单张全程覆盖式视差背景 (`Parallax2D`，`scroll_scale: Vector2(0.12, 0.05)`)，随玩家移动平滑视差推移，无缝覆盖全关卡全程。
  - **中景层 (Mid, z_index: -20)**：`village.png` 暮光小镇建筑与 `treegarden.png` 林木中景。
  - **庭院氛围层 (Garden Atmosphere, z_index: -10)**：`real_garden.png` (现实常态) 与 `dream_garden.png` (梦境侵蚀态) 动态切换。
  - **前景建筑与地形层 (World Scenery, z_index: 0)**：`bridge_village.png` 桥梁小镇、`garden.png` 庭院花架、`church.png` 静语礼堂与 `sleep_npcs.png` 沉睡旅人。

### 2. 双重状态切换 (Normal / Corrupted State)
- 继承 `DayLevelEnvironment` 统一关卡状态契约：
  - **侵蚀态 (Corrupted / Dream)**：展示 `dream_garden.png`，表现弥漫梦魇毒雾的梦息花园。
  - **净化态 (Cleansed / Real)**：展示 `real_garden.png`，展现恢复生机的晚霞常态庭院。

### 3. 标准关卡交互与系统集成
- **角色控制**：内置 `Player` (雪莉白天控制器 `DayPlayerController`、碰撞箱 `SherryCollision`、外表表现 `SherryPresentation` 与药水投掷系统 `PotionThrower`)。
- **相机边界**：`Camera2D` 搭载 `CameraBounds`，平滑绑定左右世界边界 (`LeftBarrier`, `RightBarrier`)。
- **界门传送 (DoorPortal)**：
  - `EntrancePortal`：通向药水铺工坊 (`home`)。
  - `ChurchPortal`：通向静语礼堂。
- **NPC 交互**：沉睡的旅人 (`SleepNpcs`)，进入范围显示顶部交互提示 `按 E 观察沉睡的旅人`。
- **坠落保护**：底部部署 `AbyssHazard`，失足坠落后造成 1 点伤害并自动复位至最近检查点。
- **UI 与交互提示系统**：
  - **控制台 (`DebugUI`)**：内嵌 `DeveloperConsole`，支持按 `~` 键快速唤出进行场景跳转、物品与状态修改。
  - **提示系统 (`GlobalUI`)**：内嵌 `TopHintUI`，支持沉睡旅人 NPC 接近提示、传送门交互提示及全局状态通知。
  - **暂停菜单 (`PauseMenuLayer`)**：内嵌 `PauseMenu`，支持背包查看与系统设置。

---

## 场景层级结构
```text
Garden (VespervaleGardenLevel: DayLevelEnvironment)
├─ Background (非重复背景容器)
│  ├─ FS (Parallax2D 全程覆盖式视差远景)
│  │  └─ FSBackground (FS.png)
│  ├─ Mid (中景)
│  │  ├─ VillageBG (village.png)
│  │  └─ TreeGardenBG (treegarden.png)
│  └─ GardenAtmosphere (庭院环境双态)
│     ├─ RealGarden (real_garden.png, 净化常态)
│     └─ DreamGarden (dream_garden.png, 梦境侵蚀态)
├─ WorldBounds (世界边界与碰撞)
│  ├─ Ground (地面碰撞 StaticBody2D)
│  ├─ LeftBarrier (左边界)
│  └─ RightBarrier (右边界)
├─ World (游戏实体)
│  ├─ Scenery (前景美术：BridgeVillage, GardenForeground, Church)
│  ├─ Platforms (单向跳跃平台 Platform1~3)
│  ├─ Portals (EntrancePortal, ChurchPortal)
│  ├─ NPCs (SleepNpcs)
│  └─ AbyssHazard (坠落深渊检测区)
├─ EntryPoints (default, from_home, garden, church)
├─ Player (雪莉玩家角色)
├─ DebugUI (CanvasLayer: DeveloperConsole)
├─ GlobalUI (CanvasLayer: TopHintUI)
└─ PauseMenuLayer (CanvasLayer: PauseMenu)
```
