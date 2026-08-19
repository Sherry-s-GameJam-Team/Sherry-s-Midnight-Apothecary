# 赫利昂 Boss 动画部署包

本包由即梦生成的 15 秒赫利昂连续动画整理而来，已完成：

- 深灰背景自动抠除，输出 RGBA 透明 PNG 序列；
- 从原约 24.04 FPS 降采样为 **12 FPS**，用于 Godot 实时动画；
- 统一输出为 **640×480**，不裁切画面坐标，避免不同动作之间锚点漂移；
- 根据**实际生成视频**而不是原 Prompt 重新标注动画范围；
- 提供 Godot 4.6 `SpriteFrames` 与 `AnimatedSprite2D` 场景；
- 提供 JSON 清单、时间轴图片和棋盘格检查视频。

## 推荐部署路径

将 ZIP 中的 `day/` 目录直接复制到 Godot 项目根目录，使最终路径保持：

`res://day/levels/Aurem Clockyard/boss/helion/`

随后可直接实例化：

`res://day/levels/Aurem Clockyard/boss/helion/godot/helion_animated_sprite.tscn`

或给现有 `AnimatedSprite2D` 指定：

`res://day/levels/Aurem Clockyard/boss/helion/godot/helion_spriteframes.tres`

## 动画范围

> 这些范围来自对实际生成视频的逐段检查。即梦没有完全按照原 Prompt 的预定秒数执行，因此这里不要再使用原来的 0–2 / 2–4.2 等时间划分。

| AnimationName | 含义 | 原视频范围 | 12FPS帧范围 | 类型 | 备注 |
|---|---|---:|---:|---|---|
| `idle_intro` | 初始待机/前摇 | 0.00–0.58s | 0–6 | 循环 | 可作为第一阶段短待机；片段较短，建议游戏内配合轻微 Tween 延长。 |
| `minute_sweep` | 分针横扫 | 0.58–2.25s | 6–26 | 单次 | 明显橙色环状/钟针横扫动作。 |
| `rewind_cast` | 逆刻回拨 | 2.25–5.50s | 27–65 | 单次 | 包含时间残影、核心蓄力与逆时波纹，适合作为第二阶段技能。 |
| `phase3_transform` | 零时失序/展开 | 5.50–7.58s | 66–90 | 单次 | 双臂展开、十二刻进入强化状态。 |
| `time_ring_burst` | 时间环爆发/十二刻钟鸣视觉段 | 7.58–8.83s | 90–105 | 单次 | 8秒附近出现最强圆环爆发，可作为第三阶段大招释放段。 |
| `phase3_hold` | 第三阶段悬停 | 8.83–10.75s | 105–128 | 循环 | 强化姿态保持，可作为第三阶段待机的基础。 |
| `recovery` | 收势/恢复 | 10.75–12.67s | 129–152 | 单次 | 动作逐渐收回；生成视频没有形成清晰独立的受击硬直。 |
| `purified_idle` | 净化后待机 | 12.67–15.00s | 152–179 | 循环 | 光效趋于平静，可用于Boss净化后的状态。 |

## Boss 战建议映射

第一阶段：

- 常驻：`idle_intro`
- 分针攻击：`minute_sweep`

第二阶段：

- 二秒逆刻施法：`rewind_cast`

第三阶段：

- 阶段切换：`phase3_transform`
- 大招释放：`time_ring_burst`
- 第三阶段悬停：`phase3_hold`

战斗结束：

- 收势：`recovery`
- 净化后：`purified_idle`

## 关于受击动画

原 AI Prompt 设计了独立的“受击破防”，但**实际生成视频没有出现足够清晰、可独立切出的受击动作**，因此本包没有强行把普通收势段标成 `hit`。

建议在 Godot 中使用程序化反馈：

1. Boss 向受击方向位移 8–16 px；
2. 0.08–0.12 秒快速回弹；
3. Shader/Material 闪白约 0.08 秒；
4. 核心增加一次橙色闪烁；
5. 回到当前阶段的 idle。

这样比强行使用错误视频片段更稳定。

## 背景抠除说明

当前原片并不是绿幕，而是带光照变化的深蓝灰背景，因此本包使用针对该视频调过的 HSV 色相/饱和度/亮度键控，并主动保留橙金色魔法特效与高亮石材。

已知限制：**部分灰白布料的深色阴影与背景色非常接近**，自动抠图在少量帧里可能出现轻微半透明或小缺口。请先查看：

- `preview/helion_checkerboard_preview.mp4`
- `preview/*_checker.png`

如果最终 Boss 场景背景较暗，这些边缘通常不明显；如果要做宣传级素材，建议对关键帧再进行人工蒙版修整。

## 文件结构

```text
helion/
├─ README.md
├─ animation_manifest.json
├─ frames/                     # 12 FPS / 640×480 / RGBA PNG
├─ godot/
│  ├─ helion_spriteframes.tres
│  ├─ helion_animated_sprite.tscn
│  └─ helion_animation_map.gd
├─ preview/
│  ├─ animation_timeline.png
│  ├─ helion_checkerboard_preview.mp4
│  └─ *_checker.png
├─ source/
│  └─ helion_source_15s.mp4
└─ tools/
   └─ extract_rgba.py
```

## `animation_manifest.json`

后续如果需要用脚本自动生成 AnimationPlayer、状态机或重新切片，请优先读取 `animation_manifest.json`，不要把时间范围再次硬编码到 Boss 脚本里。

## 后续接口建议

Boss 行为脚本只依赖动画名称：

```gdscript
$AnimatedSprite2D.play(&"minute_sweep")
$AnimatedSprite2D.play(&"rewind_cast")
$AnimatedSprite2D.play(&"phase3_transform")
```

不要在 Boss 战斗逻辑中直接依赖具体帧编号。以后替换 AI 动画时，只更新 `SpriteFrames` 和 `animation_manifest.json` 即可，战斗代码无需修改。
