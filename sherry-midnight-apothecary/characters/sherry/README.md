# Sherry 角色动画

## 编辑逐帧动画

打开 `res://art/characters/sherry/sherry_test_scene.tscn`，在场景树中选择 `SherryAnimationPlayer`。底部的 **Animation** 面板会显示所有动作及其逐帧关键帧。

每个动作都有三条显式轨道：

- `SherryVisual:texture`：该帧显示的贴图；
- `SherryVisual:position`：该帧相对于角色根节点的局部位置；
- `SherryVisual:scale`：该帧的局部缩放。

在时间轴上选中任意关键帧后，可直接在 Inspector 或画布中调整 `SherryVisual` 的位置与缩放。角色根节点 `SherrySprite` 的位置由移动和跳跃算法控制，请不要用它来进行逐帧对位。

## 动作流程

- `idle`、`walk`、`run`：循环动作。
- 跳跃：`prejump → jump_takeoff → jump_fall`。
- 落地：`jump_fall → land → idle / walk / run`。非移动落地直接切到 idle，禁用 `land_to_idle` 的三帧过渡。
- `prejump` 的运动与跳跃物理同时进行，不会静止。
- `prejump` 为 12 FPS；`land_to_idle` 三帧仅保留为资源，不由测试状态机播放。

所有动画帧和关键帧均保存在 `sherry_animations.tres`，而非运行时脚本生成。

## 全局角色移动：单向平台

所有使用 `res://shared/player/day_player_controller.gd` 的白天可控角色都遵循同一单向平台约定：平台使用 **物理碰撞层 2**，其 `CollisionShape2D` 勾选 `one_way_collision`。角色可从下方跳上平台；站在该层平台时按 **S**（InputMap：`drop_through`）会在 0.18 秒内忽略该层并向下穿过。普通地面不在此层，因此按 S 不会让角色穿过地板。

森林场景 `res://day/levels/forest/forest.tscn` 的 `Exterior/OneWayPlatformDemo` 是该全局逻辑的可玩示例。

每个左向动作都有对应的 `*_right` 动画轨道。右向轨道复用相同的左向 PNG 与位置关键帧，只在 `SherryVisual:scale` 的逐帧关键帧中设置负 X 缩放；角色脚本仅选择显式动画名称，不会再镜像节点或贴图。
