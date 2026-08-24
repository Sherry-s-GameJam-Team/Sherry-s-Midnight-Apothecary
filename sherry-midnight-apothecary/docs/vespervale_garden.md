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
- **界门传送与晚间结算 (VespervaleNightPortal)**：
  - `EntrancePortal`：Boss 战前传送门贴图处于隐藏状态（普通返回雪莉药水铺）。Boss 战胜利净化后，激活并显示发光界门贴图（`cliff_yellow_gate_wayportal_02.png` 悬浮光效），按 `E` 键弹出“结束探索”确认框，确认后调用 `DayRuntime.finish_day()` 结算白天探索并平滑进入**晚间经营/夜晚状态 (Night Home)**。
  - `ChurchPortal`：通向梦疗院病栋回廊 (`inner.tscn`)。
- **NPC 交互与战后沉睡者苏醒**：
  - 战前：沉睡的旅人 (`SleepNpcs`) 倒在路旁，进入范围显示顶部交互提示 `按 E 观察沉睡的旅人`，按 `E` 触发关于疗养聚落起源的对话剧情 (`vespervale_sleep_npc.dialogue`)。
  - 战后：随着梦疗院核心被净化，所有沉睡 NPC 自动全部隐藏并解除碰撞检测（代表村民摆脱梦境困缚已苏醒离去）。
- **坠落保护**：底部部署 `AbyssHazard`，失足坠落后造成 1 点伤害并自动复位至最近检查点。
- **UI 与交互提示系统**：
  - **控制台 (`DebugUI`)**：内嵌 `DeveloperConsole`，支持按 `~` 键快速唤出进行场景跳转、物品与状态修改。
  - **提示系统 (`GlobalUI`)**：内嵌 `TopHintUI`，支持沉睡旅人 NPC 接近提示、传送门交互提示及全局状态通知。
  - **暂停菜单 (`PauseMenuLayer`)**：内嵌 `PauseMenu`，支持背包查看与系统设置。

### 4. Day 5 初入事件：未醒之谷

- 正常主线从 `aurem_vespervale_transition` 终点以故事跳夜进入：Day 4 直接推进到 Day 5，载入 `vespervale_garden/default`，不会启动当晚的 `NightRuntime`。过渡关只负责上游钟庭至眠谷的连续步行，本场景继续独立拥有下述开场剧情。
- 仅当 `DayRuntime.day == 5`、且 `vespervale_day_five_first_path_complete` 尚未记录时，从 `default` 或 `from_home` 入口启动。
- `IssueDay5` 先把雪莉放到 `walkstart`，锁定玩家输入并播放向 `walkend` 的自动步行动画；远方呼唤结束后，水平输入临时收窄为仅可向右。
- 接近桥前的塞蕾娜幻影后播放 `vespervale_day_five_intro.dialogue` 的 `bridge` 段。塞蕾娜的对话立绘使用 `res://characters/Serena/standee.png`；卢卡拉回雪莉、幻影重影与消散由对白事件驱动。
- 场景中的卢卡直接实例化 `characters/luca/luca_player.tscn`，使用 `luca_sprite_frames.tres` 的 idle/run 精灵帧。救援前隐藏，救援时出现；剧情完成后由 `VespervaleLucaFollow` 按 sewer 同款停止距离、启动距离与远距离加速规则跟随雪莉，完成后重进 Day 5 花园也会恢复跟随。
- 完成剧情会恢复双向移动与传送门，写入完成标记，并把 Day 5 当前任务设为 `vespervale_first_path`（“跟随卢卡寻找真实道路，调查维斯佩尔眠谷的异常。”）。

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
├─ IssueDay5 (Day 5 自动步行、单向探索与桥前幻觉剧情)
├─ Luca (精灵帧动画角色，剧情结束后跟随)
├─ LucaFollow (sewer 风格的距离防抖跟随控制器)
├─ DebugUI (CanvasLayer: DeveloperConsole)
├─ GlobalUI (CanvasLayer: TopHintUI)
└─ PauseMenuLayer (CanvasLayer: PauseMenu)
```
