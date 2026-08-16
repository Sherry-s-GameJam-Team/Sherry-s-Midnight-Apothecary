# 卢卡（Luca）Player

`luca_player.tscn` 是一个可直接实例化的 `CharacterBody2D` 玩家场景。

## 控制与状态

- **左右移动**：A / D 或方向键左右移动。
- **跳跃**：W、方向键上、Z 键或 `jump` 动作触发跳跃。
- **单向平台下落**：S、方向键下或 `drop_through` 动作穿过单向平台（Collision Layer 2）。
- **动画状态机**：
  - `idle`：使用 001–029 循环播放。
  - `run_start`：每段新地面移动开始时使用 064–083，只播放一次。
  - `run_loop`：移动持续时自动进入 084–096 循环播放。
  - `jump` / `fall`：空中跳跃与下落动画，当前暂用行走/跑步循环帧（084–096）代替。
- **跳跃手感机制**：
  - **土狼时间（Coyote Time）**：离开平台边缘瞬间（默认 0.12s）仍可起跳。
  - **跳跃预输入（Jump Buffering）**：着地前预先按跳（默认 0.12s）会在着地后自动起跳。
  - **可变跳跃高度（Jump Cut）**：空中提前松开跳跃键会施加额外重力倍率（默认 2.8x）截断上升高度。
- **朝向翻转**：原画默认朝左，脚本根据移动/输入方向自动水平翻转。

## 信号

- `movement_started`：开始地面移动时触发。
- `movement_stopped`：停止地面移动时触发。
- `jumped`：起跳离开地面时触发。
- `landed`：空中落回地面时触发。

## 脚本与 AI 控制接口

若由剧情或 AI 控制，请把 `input_enabled` 设为 `false`，再调用：

```gdscript
luca.set_movement_direction(1.0) # 向右移动
luca.set_movement_direction(-1.0) # 向左移动
luca.stop_moving() # 停止移动
luca.request_jump() # 或 luca.jump() 触发跳跃
```

## 关卡角色切换接口

`LucaPlayer` 提供统一角色控制切换接口：

```gdscript
luca.set_control_enabled(enabled: bool)
```

启用时恢复玩家输入与物理处理；禁用时关闭输入并清除外部移动方向与水平速度。`DualProtagonistController` 与 Forest 的 `ForestPartyController` 均使用该接口在 Sherry 与 Luca 间切换控制权。
