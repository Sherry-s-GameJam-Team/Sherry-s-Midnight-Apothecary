# Codex 迁移 Prompt

将下面整段交给 Codex。Codex 工作目录应位于需要接入功能的 Godot 4.6 正式工程根目录。

---

你正在修改一个现有 Godot 4.6 项目。请把我提供的 `Magic Map Switch` 原型迁入正式工程，形成可复用的“魔法地图切换装置”。

先完整阅读原型目录中的：
- README_ZH.md
- README.md

原型文件包括：
- assets/device/transsformer.png
- assets/device/wheel.png
- assets/device/switch.png
- scripts/map_switch_controller.gd
- scripts/map_canvas.gd
- scripts/lever_confirm.gd
- scripts/crosshair.gd
- scripts/magic_overlay.gd
- shaders/dial_to_map.gdshader

====================
一、最终交互目标
====================

仪器主体使用 `transsformer.png`。

仪器上方圆形区域是地图显示区：
1. 打开装置时，圆窗先显示 `wheel.png` 魔法轮盘。
2. 激活后，通过蓝紫色魔法溶解、发光边缘、旋转魔法环效果，将轮盘切换为实时地图。
3. 地图只能显示在圆形窗内，圆形外绝不能露出地图矩形边缘。
4. 玩家按住鼠标左键拖动的是“地图本身”，不是选择光标。
5. 选择光标必须始终固定在圆心。
6. 地图节点随地图一起移动。
7. 节点接近圆心时出现渐进式磁吸：距离越近，吸力越强；不要在进入范围的一瞬间直接传送到中心。
8. 玩家在吸附范围附近松开左键后，最近节点平滑吸附到圆心。
9. 成功锁定后，右侧显示该地点详细信息。
10. 成功锁定前，确认拉杆禁用。
11. 成功锁定后，玩家向下拖动 `switch.png` 拉杆；超过约 82% 行程后确认。

====================
二、本次绝对不要真正切场景
====================

本次确认后只允许发出：

signal travel_requested(destination_id: StringName, destination_data: Dictionary)

禁止在新功能中调用：
- get_tree().change_scene_to_file(...)
- change_scene_to_packed(...)
- reload_current_scene(...)
- 或任何等价的实际切换关卡代码

真实传送后续统一交给现有 GameFlow / SceneRouter。

迁移完成后，在正式工程中为该信号添加一个临时接收器，只执行：

print("[MapSwitch] travel requested: ", destination_id)

不能切场景。

====================
三、先检查现有工程
====================

修改前先扫描工程树，确定以下真实位置，不要凭空新增重复系统：
1. 当前 Town / RainTree / Lake 共用的角色控制器。
2. 当前用于暂停或锁定玩家移动/交互的机制。
3. 药水瞄准与投掷的输入入口。
4. GameFlow / SceneRouter / Runtime 切换负责人。
5. GlobalUI 或最适合作为模态交互 UI 父节点的位置。

如果已有 Input Lock、Modal Manager、Pause Layer、GameFlow，必须复用已有实现；不要再创建第二套全局管理器。

====================
四、推荐落盘目录
====================

优先创建：

res://day/interactables/map_switch/

建议拆分：

res://day/interactables/map_switch/
├─ map_switch_interaction.tscn
├─ scripts/
├─ shaders/
├─ assets/
├─ data/
└─ README.md

如果正式工程已有更明确的交互物目录规范，则服从现有规范。

====================
五、场景结构建议
====================

尽量将原型动态创建节点整理成显式的可编辑场景：

MapSwitchInteraction (Control)
├─ DimBackground
├─ DeviceStage
│  ├─ InstrumentSprite              # transsformer.png
│  ├─ CircularDisplay               # Sprite2D / SubViewportTexture + shader
│  ├─ MagicOverlay
│  └─ FixedSelectionCursor
├─ MapViewport (SubViewport 512x512)
│  └─ MagicMapCanvas
├─ DestinationPanel
├─ TravelConfirmLever               # switch.png
└─ CloseButton                      # 如果现有交互 UI 规范需要

但不要为了“显式节点”重写已经稳定的核心算法。优先保持功能正确。

====================
六、必须保留的显示方式
====================

继续使用：

SubViewport -> ViewportTexture -> CircularDisplay Shader

不要把地图提前裁剪成固定圆形 PNG。

原因：地图需要在圆窗后方持续移动，圆窗本身固定。

当前原型对齐参数：

DEVICE_DISPLAY_CENTER = Vector2(543, 337)
DEVICE_DISPLAY_DIAMETER = 424
MAP_VIEWPORT_SIZE = Vector2i(512, 512)

主仪器原图尺寸 1086×1448。

如果迁移后贴图未重新裁剪，应先沿用这些值；仅在编辑器中确认对齐偏差后微调。

====================
七、地图拖动与磁吸
====================

保持以下规则：
- 鼠标按下必须发生在有效圆形显示区内才开始拖地图。
- 光标不动；地图 pan_offset 随鼠标 delta 改变。
- 将屏幕/仪器坐标正确换算到 512×512 MapViewport 坐标。
- 最近节点进入 MAGNET_RADIUS 后开始产生渐进吸力。
- 松开时最近节点在 SNAP_RADIUS 内才允许锁定。
- 锁定时 Tween 平滑把地图移动到：selected_node_position + pan_offset == Vector2.ZERO。

推荐初始值：
MAGNET_RADIUS ≈ 94
SNAP_RADIUS ≈ 108
吸附 Tween ≈ 0.24 s

如果正式分辨率/设备缩放不同，保持逻辑半径在 map viewport 坐标系内，不要直接改成屏幕像素。

====================
八、地点详细信息
====================

渲染与数据分离。

如果工程已有地点数据库/Resource/JSON，适配现有数据；否则新增轻量 typed Resource。

至少包含：
- id: StringName
- display_name
- subtitle
- map_pos: Vector2
- danger
- distance_text
- environment
- description

本次不强制增加 scene_path。

如果工程已有统一 Scene Registry，可以保存 route key；但确认拉杆仍然只能发 signal，不能直接使用 route key 切场景。

====================
九、输入锁定
====================

MapSwitchInteraction 打开期间：
- 禁用玩家左右移动；
- 禁用跳跃/冲刺等世界移动输入；
- 禁用药水瞄准与投掷；
- 禁用普通世界交互；
- 鼠标只允许该模态 UI 使用；
- 关闭后恢复打开前的输入状态。

必须复用正式工程已有输入锁机制。

不要直接永久设置 player.process_mode = disabled，除非正式项目现有交互系统就是这样实现的。

====================
十、拉杆确认
====================

`switch.png` 用于最终确认。

规则：
- 无地点锁定：禁用并灰化。
- 地点锁定：恢复正常亮度。
- LMB 向下拖动。
- 约 82% 行程触发一次 committed。
- 一次完整拉动只能发一次 travel_requested。
- 松手后拉杆弹回原位。
- 若没达到阈值，只弹回，不发信号。

推荐：
pull_distance ≈ 78
commit_threshold ≈ 0.82
spring back ≈ 0.22 s

====================
十一、启动效果
====================

保持轮盘 -> 地图过渡：
- shader 同时采样 wheel.png 和实时 ViewportTexture；
- transition_progress: 0 -> 1；
- 动态噪声作为 dissolve 边缘；
- 边缘蓝紫色发光；
- 外圈短暂旋转魔法环和火花；
- 总时长约 1.35 s；
- 启动期间禁止拖地图和拉杆。

====================
十二、对外接口
====================

至少保留：

signal travel_requested(destination_id: StringName, destination_data: Dictionary)
signal destination_selected(destination_id: StringName, destination_data: Dictionary)
signal activation_finished

func activate() -> void
func reset_to_dial() -> void
func configure_destinations(new_destinations: Array) -> void

如果正式工程已有统一 open()/close() 接口，可以在外层包装，但不要删除上述核心能力。

====================
十三、与现有 GameFlow 的关系
====================

MapSwitchInteraction 只负责：
- 展示；
- 地图拖动；
- 地点选择；
- 拉杆确认；
- 发出 destination_id。

GameFlow 负责：
- 保存状态；
- 播放正式转场；
- 根据 destination_id 决定目标关卡；
- 将来执行真实切场景。

本次只建立临时连接并打印 ID。

在 README 中明确写出：

## FUTURE: REAL SCENE TRAVEL

并指出将来真实切场景只能在哪里接入。

====================
十四、验收标准
====================

必须逐项检查：

1. Godot 4.6 打开无 parser error。
2. 新增场景可单独打开测试。
3. transsformer.png 正确显示。
4. 初始圆窗显示 wheel.png。
5. 激活有魔法溶解效果。
6. 地图矩形四角永远不会穿出圆形窗。
7. 左键拖动时地图移动，中心光标不移动。
8. 节点全部跟地图移动。
9. 节点接近中心时有明显但不突兀的磁吸。
10. 松开后能正确 snap 到圆心。
11. 只有 snap 成功后右侧详情才切换到具体地点。
12. 只有 snap 成功后拉杆可用。
13. 拉杆不到阈值不触发。
14. 达到阈值仅触发一次 travel_requested。
15. 收到 signal 后仅打印 ID，不切场景。
16. 打开装置期间角色不会移动或投掷药水。
17. 关闭装置后角色输入恢复。
18. 原 Town/RainTree/Lake 行为没有回归问题。

最后对新增和修改文件执行全文搜索，确认本功能没有加入：
- change_scene_to_file
- change_scene_to_packed
- reload_current_scene

====================
十五、最终汇报
====================

完成后只汇报：
1. 新增文件；
2. 修改文件；
3. 复用了哪一个现有输入锁机制；
4. travel_requested 接到了哪个节点/脚本；
5. README 中 FUTURE: REAL SCENE TRAVEL 的具体位置；
6. 编辑器中还需要人工确认的美术对齐参数；
7. 是否搜索确认没有任何真实 scene-change 调用。

不要自行扩大重构范围，不要修改无关 UI，不要重做现有 GameFlow，不要新增事件总线。

---
