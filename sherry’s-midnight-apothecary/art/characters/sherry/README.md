# Sherry 主角贴图与动作约定

## 测试场景

运行 `res://art/characters/sherry/sherry_test_scene.tscn` 可打开固定镜头的主角动作测试。使用 A/D 移动，按住 Shift + A/D 跑步，W 跳跃。舞台边界固定在画面内，便于直接检查角色的比例、脚底对齐和动作衔接。

右上角的“角色调试参数”面板会实时写入 `sherry_test_scene.gd` 的 `character_scale`、`walk_speed` 与 `run_speed` 导出参数。可直接输入或用箭头微调，改动立即生效；“恢复默认参数”会还原 0.4 / 50 / 200。测试精灵下挂一个随移动与缩放同步的 Area2D 碰撞盒，设计上覆盖躯干与腿部，不包含帽檐。

`sherry_test_scene.gd` 只处理移动、状态切换和边界；它不引用任何具体图片。所有帧范围、播放速度与循环规则统一维护在 `sherry_animation_library.gd` 的 `ACTIONS`。测试场景还可按 W 跳跃、Space 预览投掷、H 预览受击、F 预览倒地。跳跃流程依次为起跳、下落、落地，碰撞箱会随精灵一起升降。起跳会继承 A/D 的水平速度；Shift 跑步起跳相比步行起跳更高、更远，空中仍可用 A/D 微调方向。

## 当前动作表

| 动作名 | 贴图目录 | 循环 | 用途 |
| --- | --- | --- | --- |
| `idle` | `frames/01_idle/` | 是 | 默认待机，顺序循环 |
| `walk` | `frames/02_walk/` | 是 | 普通移动 |
| `run` | `frames/03_run/` | 是 | 跑步移动 |
| `throw` | `frames/04_throw/` | 否 | 投掷 |
| `hit` | `frames/05_hit/` | 否 | 受击（48 FPS，约 0.29 秒） |
| `fall` | `frames/06_fall/` | 否 | 倒地 |
| `jump_takeoff` | `frames/07_jump/` | 否 | 跳跃前 10 帧，起跳 |
| `jump_fall` | `frames/07_jump/` | 是 | 跳跃后 14 帧，下落 |
| `land` | `frames/08_land/` | 否 | 落地后播放，再回到待机 |

## 更换贴图

保持动作名和帧数量不变时，直接以同名 PNG 覆盖 `frames/` 下对应目录文件；重新运行场景即可。若帧数量变化，只需修改动画库中动作条目的 `first` 和 `last`。`idle` 从 `idle_001` 顺序播放至 `idle_024` 后循环。当前贴图为 480×432，并在测试场景以 0.62 倍缩放显示。

测试场景使用 `sherry_inset_outline.gdshader` 在角色轮廓内侧绘制深紫勾线，不改写贴图像素，也不会扩展角色外轮廓。可在 ShaderMaterial 中调整 `outline_color` 和 `outline_width`。

若新贴图的默认朝向与当前贴图不同，修改 `sherry_test_scene.gd` 顶部的 `FACE_RIGHT_REQUIRES_FLIP`；无需改动状态机。

## 增加新动作

1. 在 `frames/` 下创建动作目录，例如 `07_brew/`，并使用 `brew_000.png` 这类三位连续编号。
2. 在 `SherryAnimationLibrary.ACTIONS` 新增同名条目，填写目录、文件前缀、首尾编号、`fps` 与 `loop`。
3. 在 `sherry_test_scene.gd` 的状态机中定义进入条件；一次性动作设置 `_transition_target = "idle"` 后调用 `_play("brew")`，循环动作直接调用 `_play("brew")`。
4. 运行测试场景，确认首尾帧、脚底位置和结束后目标动作。

新增动作不必改动场景节点或重新配置 `AnimatedSprite2D`；动画库会在运行时把所有条目安装到精灵帧集合中。
