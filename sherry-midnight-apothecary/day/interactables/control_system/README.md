# Control system

控制器/受控组件架构，用于白天场景中的开关、门、桥等机关。

## 基类

- `controller_base.gd` / `ControllerBase`：控制器基类。
  - 维护 `is_active` 布尔状态。
  - 通过 `controlled_nodes` 与受控节点配对。
  - 发出 `activated`、`deactivated`、`state_changed` 信号。

- `controlled_base.gd` / `ControlledBase`：受控组件基类。
  - 接收 `set_controlled_active(active)` 并处理 `invert`、`one_shot`。
  - 子类重写 `_on_state_changed(active)` 实现具体行为。

## 控制器

- `PressurePlateController`：压力板，足够数量的 `CharacterBody2D` 站在板上时保持激活。
- `LeverSwitchController`：拉杆开关，玩家进入范围后按交互键切换状态。
- `DualWorldPressurePlateController`：双世界压力板变体。

## 受控组件

- `ControlledDoor`：受控门，激活时滑开并禁用碰撞。
- `ControlledBridge`：受控桥/平台，激活时启用碰撞并恢复不透明度。
- `ControlledTextHint`：受控文本提示。
  - 继承 `ControlledBase`。
  - 激活时向顶部 `TopHintUI` 推送 `hint_text`。
  - 通过 `hint_id` 与 `auto_hide_seconds` 控制提示标识和自动隐藏时间。

- `ControlledMovingPlatform`：受控往复移动平台。
  - 继承 `ControlledBase`。
  - 激活时沿 `target_offset` 做往复运动（去程、停留、回程、停留）。
  - 未激活时立刻停在当前位置，再次激活后从当前位置继续循环。
  - 通过 `travel_time` 与 `pause_time` 控制单程耗时与端点停留时间。
  - 通过 `easing` 切换线性或 Smooth（端点减速、中段加速）运动。
  - 可在子节点添加 `Marker2D` 并命名为 `DestinationMarker` 来可视化标记终点；存在时会覆盖 `target_offset`。
