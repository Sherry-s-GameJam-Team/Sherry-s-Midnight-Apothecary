# 常霁云林 / Forest Level

## 接入原则

Forest 沿用 Grassland 参考包所展示的正式白天关卡结构：根场景继承 `DayLevelEnvironment`，通过 `LevelData` 接入既有白天关卡系统，Sherry 继续使用 `res://shared/player/day_player_controller.gd`、现有角色 Presentation/Collision 与 `PotionThrower`。本包不创建新的全局 PlayerData、SaveManager、InventoryManager、EventBus 或场景切换器。

主场景：`res://day/levels/forest/forest.tscn`

树冠区域作为 `res://day/levels/forest/crown.tscn` 的实例挂载在主场景的 `Crown` 节点下。树内（Interior）已拆分为独立白天关卡，不再内嵌在主场景中；详见 [FOREST_INTERIOR_LEVEL.md](FOREST_INTERIOR_LEVEL.md)。

LevelData：`res://day/levels/forest/forest_level.tres`

Forest 已在 `DayRuntime.LEVELS` 与 `DayRuntime.DAILY_LEVELS` 中显式注册此 LevelData，替代已移除的旧 `raintree` 资源。Interior 关卡 `forest_interior_level.tres` 仅注册在 `DayRuntime.LEVELS`（不进 DAILY_LEVELS），由树门完成后切换进入。

## 总流程

1. Exterior 横向林场探索。
2. 玩家可自由选择顺序踩下与四座水车空间对齐的莲花。
3. 莲花首次踩踏后永久进入放水状态；水流使用 `Area2D` 与 `ForestWaterReceiver` 的真实空间重叠判定，不在 Lotus 脚本里硬编码水车编号。
4. 四座水车全部启动后，阿尔维斯母树树心门进入可交互状态；玩家靠近门并按 E，才会播放 24 帧、6 FPS、约 4 秒的开门动画和同步音效。
5. 树心门开启后写入 `forest_tree_gate_opened`，并通过 `request_checkpoint(&"forest_tree_gate_opened")` 暴露关键点接口。
6. 树门开启后，玩家进入树门后的 `InteriorEntrance` 范围会看到“按[E]进入树内”提示；仅按 E 才调用 `enter_interior()`。`forest.gd` 随后通过 `DayRuntime.switch_to_level(&"forest_interior", &"from_forest")` 切换到独立 Interior 关卡（不再在外部场景内驱动旧的内嵌树内阶段）。
7. Interior 关卡内完成 Sherry / Luca 切换、控制室、水枪、升降根、闸门与直达梯流程，最后到达树冠出口。Interior 的玩法、节点契约与验收见 [FOREST_INTERIOR_LEVEL.md](FOREST_INTERIOR_LEVEL.md)。
8. 独立 `forest_crown` 关卡从 Interior 的 `from_interior` 入口接入树冠 Boss；Interior 的 `ExitToCrown` 通过 DayRuntime 黑屏转场切换到正式 Boss 场景。

树心门在 Forest 外部由交互状态而非实体墙限制流程：关门时仍不能触发 Interior 入口，但不使用随门整体缩放的旧 `Blocker` 碰撞，以免覆盖入口出生点并阻挡向右探索。

## Exterior

视差层包括：FarCanopy、MidHangingLotus、Gameplay Ground。上方雨幕与王莲冠层来自现有美术；外部水车动画只使用源 MOV 中的清水画面。红水没有部署到外部水车，红水视觉只在 Interior 关卡的中央 `BloodStream` 中出现。

### 第一天森林：恩佐救援线索

`issue_save_enzuo/HangingFrameNpc` 是 23 帧、6 FPS 的正倒循环角色动态精灵。第 1 天从下水道出口进入 `forest/from_sewer` 时，会播放一次森林开场对话与 Sherry 入场演出；此后它作为悬挂恩佐的环境节点显示。Boss 前不会播放恩佐收束对话，也不会在打开树心门时触发该对白。

Boss 完成后，`issue_save_enzuo` 自动隐藏，并激活 `issue_saved/Enzuofall`；其他日期或 `save_enzuo_solved` 为真时，两个节点都隐藏。

初见对话结束后不再有药水投掷或副藤切割环节，玩家立即恢复操作并直接开始四座水车的主线解密。恩佐会一直被母树藤蔓保护，直到树冠 Boss 被净化。

Boss 完成后返回森林，`issue_saved` 自动派发 `day_one_forest_enzuo_saved` 对话事件。对话完成设置 `save_enzuo_solved`，快速黑场并调用 `DayRuntime.finish_day()`，进入夜晚经营场景；不改变水车或树门进度。

### Lotus

`lotus_platform.tscn` 为 `AnimatableBody2D`。首次踩踏或被任意药水直接命中都会下沉约 10 px 后回弹，并永久切换到带清水的莲花图；重复触发不会改变状态。水流 `WaterStreamArea` 向下延伸，与水车的 `WaterReceiver` 重叠后送水。

### Waterwheel

源素材 `forest_waterwheel_cutout_alpha.mov` 已按 6 FPS 抽为 24 张 RGBA PNG。`waterwheel.tscn` 使用 AnimatedSprite2D：`idle` → `activate` → `loop`。

### 单向平台示例

`Exterior/OneWayPlatformDemo` 位于入口右侧。它使用碰撞层 2 和 `one_way_collision`，可从下方跳上；站在其上时按 S 会下落。具体全局角色约定见 `res://characters/sherry/README.md`。

### Mud

`exterior/corrupted_mud.gd` 提供：

```gdscript
func receive_potion_hit(hit: Dictionary) -> void
```

当 `potion_id == &"purification_potion"` 时调用 `purify()`，淡出并禁用碰撞。本关不创建任何独立药水库存。

## Interior（独立关卡）

Interior 是独立白天关卡：`res://day/levels/forest/interior/forest_interior.tscn` + `forest_interior_level.tres`（id `&"forest_interior"`，默认入口 `&"from_forest"`，不显示标题卡）。它使用与 Forest 外部相同的角色/药水/环境基座（DayLevelEnvironment、ForestPartyController、luca_player、PotionThrower、CameraBounds），并从 `forest.gd` 的树门入口交接进入。玩法细节、节点契约、静态验证与烟雾测试见 [FOREST_INTERIOR_LEVEL.md](FOREST_INTERIOR_LEVEL.md)。

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

树冠 Boss 已作为独立 `forest_crown` 关卡运行，包含炽天使 Boss AI、伤害、净化流程、失败复位和完成后的返回森林路线。外部 `forest.tscn` 中保留的 `Crown` 节点只服务森林外部的历史视觉与入口兼容，不承担正式 Boss 流程。

## Normal revisit / gathering

`forest_level.tres` 暂时配置四个已在 Grassland 参考 LevelData 中出现的测试 native ingredient ID，并沿用项目 `HerbSpawnDirector`。四个采集 Marker 集中放在 `Exterior/HerbSpawns`，方便之后替换为 Forest 正式植物配置。采集系统仍由项目既有 Herb/Inventory 体系处理。

## Tests

- 外部场景烟雾测试：`day/levels/forest/tests/forest/forest_smoke_test.gd`（验证 Exterior 节点、莲花/水车/污泥机制、角色切换与树门交接；输出 `FOREST_SMOKE_TEST: PASS`）。
- Interior 关卡烟雾测试：`tests/forest_interior_smoke_test.gd`（来自 Interior 关卡包，输出 `FOREST_INTERIOR_SMOKE_TEST: PASS`）。
- 恩佐救援规则测试：`tests/forest_enzuo_rescue_test.gd`（验证仅在第一天、初见完成且 Boss 净化后触发收束，并保证完成后不重播）。
