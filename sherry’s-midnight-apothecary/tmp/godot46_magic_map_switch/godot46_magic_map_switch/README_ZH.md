# 魔法地图切换装置 — Godot 4.6.x

这是一个可独立运行的地图切换装置原型，直接使用用户提供的三张贴图：

- `assets/device/transsformer.png`：主仪器；
- `assets/device/wheel.png`：未启动时，圆形显示区内的魔法轮盘；
- `assets/device/switch.png`：目的地确认拉杆。

当前版本**不会真正切换场景**。拉杆确认后只发出：

```gdscript
travel_requested(destination_id: StringName, destination_data: Dictionary)
```

这样后续可以把真实传送逻辑接到 `GameFlow / SceneRouter`，不用改地图装置内部交互。

## 操作流程

1. 运行工程。
2. 点击 `ACTIVATE DEVICE`。
3. 圆形区域从 `wheel.png` 通过蓝紫魔法溶解效果切换为实时地图。
4. 鼠标左键按住圆形地图并拖动。
5. 中央选择光标固定不动，实际移动的是地图。
6. 地图节点靠近圆心后产生逐渐增强的磁吸。
7. 在吸附范围内松开左键，最近节点自动对齐圆心。
8. 右侧面板显示地图名称、风险、距离、环境、描述。
9. 节点锁定后，右侧拉杆解锁。
10. 向下拖动拉杆超过约 82% 后触发 `travel_requested(...)`。
11. Demo 只在控制台输出目的地 ID，不切场景。

## 核心结构

```text
MapSwitchDemo (Control)
├─ DeviceStage (Node2D)
│  ├─ InstrumentSprite
│  ├─ CircularDisplay              # 显示 SubViewportTexture
│  ├─ MagicOverlay                 # 启动魔法环/粒子
│  └─ FixedSelectionCursor         # 圆心固定光标
├─ MapViewport (SubViewport)
│  └─ MagicMapCanvas               # 地图、节点、路线、拖动与磁吸
├─ DestinationPanel
├─ TravelConfirmLever
├─ ActivateButton
└─ ResetButton
```

实际节点大部分由 `map_switch_controller.gd` 动态创建，方便把原型直接拷入其他工程。迁移时也可以根据项目规范把它们改成编辑器中显式的 `.tscn` 节点。

## 文件说明

- `scenes/map_switch_demo.tscn`：Demo 入口场景。
- `scripts/map_switch_controller.gd`：总控制器、输入、UI、激活、节点锁定、信号。
- `scripts/map_canvas.gd`：地图绘制、节点、拖动、磁吸、吸附。
- `scripts/lever_confirm.gd`：拉杆拖动与确认阈值。
- `scripts/crosshair.gd`：固定圆心选择光标。
- `scripts/magic_overlay.gd`：启动时旋转魔法环与火花。
- `shaders/dial_to_map.gdshader`：圆形遮罩与轮盘→地图魔法溶解。
- `CODEX_MIGRATION_PROMPT_ZH.md`：直接交给 Codex 的迁移任务说明。

## 后续接真实场景切换的位置

不要在地图装置内部直接写 `change_scene_to_file()`。

推荐由外部流程节点接收信号：

```gdscript
func bind_map_switch(map_switch: Node) -> void:
    map_switch.travel_requested.connect(_on_map_travel_requested)

func _on_map_travel_requested(destination_id: StringName, data: Dictionary) -> void:
    # FUTURE: REAL SCENE TRAVEL
    # 1. 保存当前玩家/日期数据
    # 2. 播放现有转场动画
    # 3. 由 GameFlow / SceneRouter 根据 destination_id 找到场景
    # 4. 执行真实切场景
    pass
```

当前 Demo 的 `_ready()` 中有：

```gdscript
travel_requested.connect(_demo_receive_travel_signal)
```

它只负责 `print()`。迁移到正式工程后，可以删除这条 Demo 连接，然后由正式的流程节点连接。

## 对外 API

### 信号

```gdscript
signal travel_requested(destination_id: StringName, destination_data: Dictionary)
signal destination_selected(destination_id: StringName, destination_data: Dictionary)
signal activation_finished
```

### 方法

```gdscript
activate()
reset_to_dial()
configure_destinations(new_destinations: Array)
```

世界交互触发后调用 `activate()` 即可。

## 目的地数据格式

```gdscript
{
    "id": &"raintree_forest",
    "name": "Rain Tree Forest",
    "subtitle": "Wet Alchemy Woods",
    "pos": Vector2(82, -142),
    "danger": "MEDIUM",
    "distance": "2 relays",
    "environment": "Forest / Rain",
    "description": "..."
}
```

其中 `pos` 是地图坐标，不是屏幕坐标。正式工程如果已经有 Location Registry / Resource / JSON 数据表，建议由外部转换成上述结构后调用：

```gdscript
map_switch.configure_destinations(my_destination_array)
```

## 主要调参

位于 `scripts/map_switch_controller.gd`：

```gdscript
const DEVICE_DISPLAY_CENTER := Vector2(543.0, 337.0)
const DEVICE_DISPLAY_DIAMETER := 424.0
const MAP_VIEWPORT_SIZE := Vector2i(512, 512)
const SNAP_RADIUS := 108.0
const MAGNET_RADIUS := 94.0
```

- `DEVICE_DISPLAY_CENTER`：主贴图中圆形显示区中心。
- `DEVICE_DISPLAY_DIAMETER`：圆形地图实际显示直径。
- `MAGNET_RADIUS`：节点开始产生磁吸的范围。
- `SNAP_RADIUS`：松手后允许自动锁定节点的范围。

拉杆参数位于 `lever_confirm.gd`：

```gdscript
var pull_distance := 78.0
var commit_threshold := 0.82
```

## 圆形地图是怎么实现的

地图不是提前裁剪成圆形图片。

`MagicMapCanvas` 在 `SubViewport 512×512` 中持续绘制完整地图；`CircularDisplay` 使用这个 SubViewport 的实时纹理。Shader 对显示纹理做圆形 Alpha 遮罩，因此地图可以在后方自由拖动，但只能从仪器圆窗中看到。

这使后续换成真实大地图纹理、TileMap 或地图节点系统时，无需重新做圆形素材。

## 启动动画

`dial_to_map.gdshader` 同时采样：

- `wheel.png`；
- 实时地图的 ViewportTexture。

`transition_progress` 从 `0 → 1` 时，通过动态噪声边缘完成溶解，并叠加蓝紫高亮。`magic_overlay.gd` 同时在外圈绘制短暂旋转环和火花。

启动持续时间当前约 1.35 秒，可在 `activate()` 的 Tween 中修改。

## 迁入正式工程时的建议

1. 将整个功能放入独立目录，例如：
   `res://day/interactables/map_switch/`
2. 修正 `preload()` 路径。
3. 世界中的仪器交互成功后打开该 UI 并调用 `activate()`。
4. 打开 UI 后使用项目已有机制锁定角色移动、药水投掷和普通世界交互。
5. UI 关闭时恢复输入。
6. 只把 `travel_requested` 接到 `GameFlow`，不要让装置自己切场景。
7. 后续真实传送完成时，在 GameFlow 中根据 `destination_id` 查找目标关卡。

## 美术对齐

主仪器原始尺寸为 1086×1448。若之后重新裁剪或替换主贴图，只需优先修改：

```gdscript
DEVICE_DISPLAY_CENTER
DEVICE_DISPLAY_DIAMETER
```

圆形显示、鼠标区域、固定光标会继续使用同一套参数。
