# 常霁云林 / Forest Level

## 接入原则

Forest 沿用 Grassland 参考包所展示的正式白天关卡结构：根场景继承 `DayLevelEnvironment`，通过 `LevelData` 接入既有白天关卡系统，Sherry 继续使用 `res://shared/player/day_player_controller.gd`、现有角色 Presentation/Collision 与 `PotionThrower`。本包不创建新的全局 PlayerData、SaveManager、InventoryManager、EventBus 或场景切换器。

主场景：`res://day/levels/forest/forest.tscn`

树冠区域作为 `res://day/levels/forest/crown.tscn` 的实例挂载在主场景的 `Crown` 节点下。主场景在编辑时可暂时省略 `Interior`；运行时代码会保留外部区域和树冠的安全初始化，直到室内场景重新接入。

LevelData：`res://day/levels/forest/forest_level.tres`

Forest 已在 `DayRuntime.LEVELS` 与 `DayRuntime.DAILY_LEVELS` 中显式注册此 LevelData，替代已移除的旧 `raintree` 资源。

## 总流程

1. Exterior 横向林场探索。
2. 玩家可自由选择顺序踩下与四座水车空间对齐的莲花。
3. 莲花首次踩踏后永久进入放水状态；水流使用 `Area2D` 与 `ForestWaterReceiver` 的真实空间重叠判定，不在 Lotus 脚本里硬编码水车编号。
4. 四座水车全部启动后，阿尔维斯母树树心门进入可交互状态；玩家靠近门并按 E，才会播放 24 帧、6 FPS、约 4 秒的开门动画和同步音效。
5. 树心门开启后写入 `forest_tree_gate_opened`，并通过 `request_checkpoint(&"forest_tree_gate_opened")` 暴露关键点接口。
6. 进入 Interior，开启 Sherry / Luca 切换。
7. Luca 视角显示 `LucaWorldOnly` 和青白滤镜；Sherry 视角隐藏旧世界层。
8. Luca 的 Root Control / Water Pressure / Crown Gate 三个控制点分别影响现实中的 RootLift、SluiceGate、RotatingRoot。三点完成后解锁 Direct Lift。
9. Luca 可提前搭直达梯到 Crown，并操作 FinalSwitch 为 Sherry 移除最后通道阻挡。
10. Sherry 完成最后攀爬后进入 Crown，触发 BossInterface；本包不实现 Boss AI。
11. 未来 Boss 调用 `BossInterface.purify_boss()` 后，Forest 进入 normal/restored，血水柱切换为清水，污染污泥消失，Boss Trigger 停用并开放采集节点。

## Exterior

视差层包括：FarCanopy、MidHangingLotus、Gameplay Ground。上方雨幕与王莲冠层来自现有美术；外部水车动画只使用源 MOV 中的清水画面。红水没有部署到外部水车，红水视觉只在树干 Interior 的中央 `BloodStream` 中出现。

### Lotus

`lotus_platform.tscn` 为 `AnimatableBody2D`。首次踩踏或被任意药水直接命中都会下沉约 10 px 后回弹，并永久切换到带清水的莲花图；重复触发不会改变状态。水流 `WaterStreamArea` 向下延伸，与水车的 `WaterReceiver` 重叠后送水。

### Waterwheel

源素材 `forest_waterwheel_cutout_alpha.mov` 已按 6 FPS 抽为 24 张 RGBA PNG。`waterwheel.tscn` 使用 AnimatedSprite2D：`idle` → `activate` → `loop`。

### 单向平台示例

`Exterior/OneWayPlatformDemo` 位于入口右侧。它使用碰撞层 2 和 `one_way_collision`，可从下方跳上；站在其上时按 S 会下落。具体全局角色约定见 `res://characters/sherry/README.md`。

### Mud

`corrupted_mud.gd` 提供：

```gdscript
func receive_potion_hit(hit: Dictionary) -> void
```

当 `potion_id == &"purification_potion"` 时调用 `purify()`，淡出并禁用碰撞。本关不创建任何独立药水库存。

## Interior

Interior 使用纵向 Camera Bounds。中央 `stream.png` 同时构建 BloodStream 和 ClearStream；corrupted 状态对同一清水纹理使用红色 modulate，normal 状态恢复青白透明水流。血水仅为视觉，不设置伤害碰撞。

缺失专门树根平台图时，平台采用 Polygon2D/Line2D 的棕色树根主体与绿色苔藓边缘，不使用白色 Debug Rectangle。

### Sherry / Luca

`ForestPartyController` 默认优先控制 Sherry。进入树内后允许 Tab 切换；如果工程已配置 `switch_character` Input Action，则优先使用该 Action。非当前角色不接受移动输入，保留坐标与碰撞。Camera2D 在两角色之间 reparent，不创建第二台永久主摄像机。

本包没有拿到完整工程中的正式可操控 Luca 场景，因此附带 `ForestLucaController` + 简单程序化占位 Presentation 保证场景本身有可执行 fallback。集成到完整工程时，应优先把 `Luca/FallbackPresentation` 换成项目正式 Luca Presentation；无需改 PartyController 接口，只要正式 Luca 支持 `set_control_enabled(bool)`，或在现有角色切换层做适配。

场景中的 `LucaDialogueNpc` 是独立的对话 NPC，不替代可切换的 `Luca` 角色。其 `DialogueTrigger` 使用碰撞掩码 1 检测 Player，进入范围后通过全局 `TopHintUI` 显示“按[E]与卢卡交谈”；按 E（InputMap 的 `interact`）后，`area_2d.gd` 会根据 `ArvisTreeGate.is_open` 选择对话：开门前为 `res://day/levels/forest/dialog/before_stream.dialogue`，开门后为 `res://day/levels/forest/dialog/after_stream.dialogue`。每个阶段在单次场景运行中各播放一次。

### Luca old world

`LucaWorldOnly` 仅在 Luca 视角显示，内含控制室、控制开关、喷水装置与直达梯。旧世界开关直接调用现实世界 RootLift / RotatingRoot / SluiceGate，所以操作结果会保留在现实层。

### Spray pressure

默认：

- max_pressure = 100
- shot_cost = 35
- regen_per_second = 15
- cooldown = 1.2 s

喷水使用 RayCast2D 命中带 `purify()` 的污泥，不消耗 purification_potion。

## Checkpoint / persistence

本包遵循 Grassland 已使用的 `PlayerData.tutorial_flags` 方式保存兼容状态：

- `forest_tree_gate_opened`
- `forest_completed`
- `forest_direct_lift_unlocked`
- `forest_root_control`
- `forest_water_pressure_control`
- `forest_crown_gate_control`

树门开启时还会调用 Forest 自身 `request_checkpoint()`。若实际工程中的 DayRuntime 已有 `request_checkpoint`，会直接转发；如果尚未实现正式 checkpoint API，事件仍会通过 `checkpoint_requested` signal 暴露，后续可无痛接入，不创建第二套 SaveManager。

## Boss interface

路径：`res://day/levels/forest/boss/forest_boss_interface.gd`

接口：

```gdscript
signal boss_started
signal boss_purified
func begin_boss()
func purify_boss()
```

本阶段只保留接口、触发区、corrupted/normal 熾天使视觉和净化后环境恢复逻辑，不制作 Boss AI、伤害或击杀流程。

## Normal revisit / gathering

`forest_level.tres` 暂时配置四个已在 Grassland 参考 LevelData 中出现的测试 native ingredient ID，并沿用项目 `HerbSpawnDirector`。四个采集 Marker 集中放在 `Exterior/HerbSpawns`，方便之后替换为 Forest 正式植物配置。采集系统仍由项目既有 Herb/Inventory 体系处理。

## Tests

`res://tests/forest/forest_smoke_test.tscn` 检查：

- Forest 主场景实例化与 Required Nodes；
- Lotus 激活；
- Waterwheel 激活；
- purification_potion 净化 Mud；
- Spray 压力门槛；
- Luca World 显隐；
- RootLift / RotatingRoot / Sluice；
- Boss begin / purify；
- Forest normal 切换。
