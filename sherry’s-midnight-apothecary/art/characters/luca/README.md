# 卢卡（Luca）Player

`luca_player.tscn` 是一个可直接实例化的 `CharacterBody2D` 玩家场景。

- A / D 或方向键左右移动。
- `idle` 使用 001–029，循环播放。
- 每段新移动开始时，`run_start` 使用 064–083，只播放一次。
- 若移动仍在继续，则自动进入 `run_loop`，使用 084–096 循环播放。
- 松开方向键会立刻回到 `idle`；再次移动会从 064 重新播放起跑段。
- 原画默认朝左，脚本会根据移动方向自动水平翻转。

若由剧情或 AI 控制，请把 `input_enabled` 设为 `false`，再调用：

```gdscript
luca.set_movement_direction(1.0) # 向右
luca.set_movement_direction(-1.0) # 向左
luca.stop_moving()
```
