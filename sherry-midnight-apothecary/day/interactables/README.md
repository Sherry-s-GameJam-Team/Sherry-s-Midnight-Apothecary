# Day interactables

可复用的白天场景交互组件。

## HintArea

`hint_area.tscn` / `hint_area.gd`

可挂载在任意节点下方的靠近提示区域。玩家进入配置的 `Area2D` 碰撞范围后，顶部 `TopHintUI` 会显示一段提示文本；玩家离开后自动隐藏。

- `hint_text`：显示的提示内容。
- `hint_id`：可选标识，为空时自动生成。
- `detection_layer`：Area2D 检测的物理层。

## Control system

参见 [`control_system/`](control_system/)。提供控制器/受控组件架构：

- `ControllerBase`：控制器基类（压力板、拉杆等）。
- `ControlledBase`：受控组件基类（门、桥等）。
- `ControlledTextHint`：受控文本提示，被控制器激活时向 `TopHintUI` 推送文本。
