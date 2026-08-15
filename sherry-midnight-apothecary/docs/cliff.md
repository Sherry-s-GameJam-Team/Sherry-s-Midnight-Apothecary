# 烁金断崖：鸣晶之灾

`res://day/levels/cliff/cliff.tscn` 是可独立运行的横向平台关卡。原有背景视差、平台、晶桥、三根共鸣晶柱、接收器、旅门数据、出生点、掉落重置和 `cliff_resonance_cleared` 完成标记保持不变。

## 灾害结构

```text
CliffLevel
├─ Mechanisms
│  ├─ Pillar01
│  ├─ Pillar02
│  ├─ Pillar03
│  └─ ResonanceReceiver
├─ Hazards
│  ├─ CliffHazardController
│  ├─ ResonanceWaves
│  ├─ Avalanches
│  │  ├─ AvalancheZone01
│  │  ├─ AvalancheZone02
│  │  └─ AvalancheZone03
│  └─ FallResetZone
├─ EntryPoints/default
└─ UI/FadeRect
```

每个 `AvalancheZone` 内部包含 `WarningVisual`、`SnowVisual`、`DangerArea/CollisionShape2D`、`SnowParticles`、`FrontPowder` 和空音频锚点。`zone_size` 同时设置三个矩形视觉和 `RectangleShape2D`，因此显示范围与伤害范围一致。

## 共鸣波

晶柱以 `warning_time = 0.7 s` 和 `charge_time = 0.5 s` 完成预警/蓄力。`pillar_charge.gdshader` 在原贴图上叠加蓝白亮度、纵向流光和快速脉冲，Tween 只晃动晶柱 Sprite，不移动平台。爆发时产生程序化扩散环，并向左右发射共鸣波。

共鸣波默认 `speed = 920 px/s`、碰撞尺寸 `120 × 48 px`、视觉尺寸 `220 × 84 px`，各柱最大距离由场景分别设置为 880、920、930 px。`resonance_wave.gdshader` 使用两层正弦曲线、核心高光、青蓝外圈和散点拖尾。低位碰撞允许玩家跳跃躲避，单个波只可命中一次。

## 雪崩区域配置

| 区域 | 中心位置 | 范围 | 触发 | 爆发/冷却 | 流向 |
|---|---:|---:|---|---|---:|
| AvalancheZone01 | (2320, 300) | 820 × 640 | AUTO，初次 5.0 s | 3.4 / 10.0 s | (-0.38, 1.0) |
| AvalancheZone02 | (4440, 290) | 900 × 660 | AUTO，初次 9.5 s | 4.0 / 11.0 s | (0.42, 1.0) |
| AvalancheZone03 | (6560, 280) | 920 × 680 | Pillar03 爆发后 0.65 s | 4.4 / 8.0 s | (-0.5, 1.0) |

三区 `warning_duration` 均为 2.0 秒。预警阶段 `DangerArea.monitoring = false`；Tween 完成后才开启检测。区域没有覆盖相邻晶体台和桥面，玩家可撤离到前后平台作为避难点，第三段的 0.65 秒触发延迟使共鸣波先抵达，再进入完整两秒雪崩预警。

雪崩主体由 `avalanche_snow.gdshader` 生成低/中/高频程序化噪声、斜向雪线、雪团、晶尘和底部雪雾；`GPUParticles2D` 只补充雪块。`avalanche_warning.gdshader` 生成细雪、下落细纹和地面脉冲，无新增 PNG 或逐帧资源。

## 受击与重生调用链

```text
ResonanceWave / AvalancheZone / FallResetZone
→ CliffHazardController
→ 锁定对话与药水动作输入
→ DayPlayerController.play_hazard_hit()（已有 hit 动画）
→ 灾害方向短击退 + Camera2D 轻震
→ 0.38 s 反馈
→ UI/FadeRect 淡黑
→ EntryPoints/default
→ DayPlayerController.reset_after_hazard()
→ 清空速度和临时动作状态
→ 淡入并恢复输入
→ 1.25 s cliff 环境伤害保护
```

掉落重置仍调用 `CliffResonanceLevel.request_respawn()`，但该入口现在委托给同一个 controller，不再维护第二套出生坐标或淡入淡出逻辑。

## Inspector 调节项

`AvalancheZone` 暴露范围、严格预警时间、持续/淡出/冷却、初次延时、方向、速度、密度、自动重复、AUTO/RESONANCE 模式、共鸣源、触发延迟和 debug 绘制。`CliffHazardController` 暴露受击反馈、淡入淡出和保护期。共鸣柱暴露预警、蓄力、周期、首发延时、波速与射程；共鸣波暴露速度、射程、方向和击退值。

正式版本的音频引用可以为空；只有设置 stream 后才播放。开发调用可通过 `CliffHazardController.trigger_avalanche(name)`、`trigger_all_avalanches()`、`trigger_resonance_pillar(id)` 和 `respawn_player()` 执行。

## 工程适配

- 实际出生节点为 `EntryPoints/default`，保留兼容用 `PlayerSpawn`，重生以 EntryPoint 为唯一位置来源。
- 现有玩家没有统一 hazard API，因此只在 `day_player_controller.gd` 增加 `play_hazard_hit()` 与 `reset_after_hazard()` 两个薄接口，复用已存在的 `hit` AnimationPlayer 动画。
- 工程没有通用 camera shake 服务，轻震局部实现于 cliff controller，始终恢复原始 `Camera2D.offset`。
- 原共鸣波位于 `effects/`，继续沿用该路径，避免无意义移动资源；新雪崩组件按项目结构放在 cliff 的 `hazards/` 和 `shaders/`。

## 验证

Godot 4.6.2 headless 已成功加载并实例化 `cliff.tscn`，也验证 Zone01 在触发后 1.9 秒仍无伤害、2.1 秒已开启伤害。项目级命令仍会报告仓库既有的缺失 `res://night/ui/developer_console/developer_console.tscn` 和部分重复 UID，与本关无关。
