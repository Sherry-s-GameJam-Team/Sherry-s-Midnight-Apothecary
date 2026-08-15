# 烁金断崖 · 鸣晶之灾（Cliff）

面向当前 Godot 4.x 工程结构制作的可复制关卡包。结构参考现有 `res://day/levels/grassland/` 与 `emerald_field`：使用 `LevelData` 资源注册关卡、`DayLevelEnvironment` 作为环境根脚本、复用项目现有 Sherry 控制器 / 表现 / 碰撞 / 药水投掷系统。

## 1. 安装

把本压缩包中的 `cliff/` 整个目录复制到：

```text
res://day/levels/cliff/
```

Godot 会自动为 PNG、TSCN、GDScript 生成 `.import` / `.uid`。

主资源：

```text
res://day/levels/cliff/cliff_level.tres
```

主场景：

```text
res://day/levels/cliff/cliff.tscn
```

如果工程有显式 LevelData 注册表，把 `cliff_level.tres` 与现有 `grassland_level.tres` 一样加入注册列表即可。

## 2. 依赖路径

本包按参考草原关卡直接复用了这些现有项目资源：

```text
res://shared/definitions/level_data.gd
res://shared/player/day_player_controller.gd
res://day/potions/potion_player_system.tscn
res://characters/sherry/sherry_presentation.tscn
res://characters/sherry/sherry_outdoor_collision.tscn
```

并依赖当前工程中已有的全局类：

```text
DayLevelEnvironment
DayRuntime
PlayerData
```

如果你的主工程这些资源路径未改动，则无需调整。

## 3. LevelData

`cliff_level.tres` 当前配置：

```text
id              = cliff
display_name    = 烁金断崖
disaster_name   = 鸣晶之灾
default_entry   = default
content_scene   = res://day/levels/cliff/cliff.tscn
```

存档完成标记：

```text
player_data.tutorial_flags["cliff_resonance_cleared"]
```

## 4. 核心玩法

整关为约 9300 px 的横向卷轴。

流程：

```text
出生
→ 平台跳跃
→ Pillar01：跃过共鸣波并按 E 校准
→ Pillar02
→ Pillar03
→ 到达 ResonanceReceiver
→ 三柱全部稳定后按 E 稳定鸣晶核心
→ 写入 cliff_resonance_cleared
```

共鸣柱本身只使用一张静态美术。蓄力提示、闪烁、共鸣波、完成状态均由 Godot 节点与 Tween 实现，不需要额外动画贴图。

共鸣波为低位横向波，玩家可通过跳跃躲避；强化后的 Shader 波形和三段程序化雪崩统一通过 `CliffHazardController` 播放受击、镜头震动、淡出和回到 `EntryPoints/default`。完整参数与调用链见 `res://docs/cliff.md`。

## 5. 关键节点路径

```text
CliffLevel
├─ Parallax
│  ├─ Sky
│  ├─ FarCloud
│  ├─ FarCrystalSpire
│  ├─ FarMountain
│  ├─ MidCliff
│  └─ NearCrystal
├─ PlayerSpawn
├─ EntryPoints
│  ├─ default
│  └─ level_completed
├─ Player
│  ├─ SherryCollision
│  ├─ SherryPresentation
│  ├─ Camera2D
│  └─ PotionThrower
├─ WorldBounds
├─ Platforms
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
├─ FrontFog
├─ FrontOccluder
└─ UI
   ├─ Hint
   ├─ ProgressLabel
   ├─ CompleteLabel
   └─ FadeRect
```

`cliff_level.gd` 硬引用节点：

```text
$PlayerSpawn
$Player
$UI/FadeRect
$UI/ProgressLabel
$UI/CompleteLabel
$Mechanisms/ResonanceReceiver
```

不要在不修改脚本的情况下重命名以上节点。

## 6. 机关 Prefab

共鸣柱：

```text
res://day/levels/cliff/mechanisms/resonance_pillar.tscn
```

节点：

```text
ResonancePillar
├─ Sprite2D
├─ PulseOrigin
├─ InteractArea
│  └─ CollisionShape2D
└─ Label
```

可在 Inspector 调整：

```text
pillar_id
pulse_interval
first_pulse_delay
warning_time
wave_speed
wave_range
```

终点接收器：

```text
res://day/levels/cliff/mechanisms/resonance_receiver.tscn
```

共鸣波：

```text
res://day/levels/cliff/effects/resonance_wave.tscn
```

## 7. 背景视差

所有背景图均来自上传的鸣晶美术包，原始图直接使用，没有重新绘制。

| 节点 | 资源 | scroll_scale.x |
|---|---|---:|
| Sky | cliff_bg_sky_01 | 0.05 |
| FarCloud | cliff_bg_cloud_far_01 | 0.12 |
| FarCrystalSpire | cliff_bg_crystal_spire_far_01 | 0.22 |
| FarMountain | cliff_bg_mountain_far_01 | 0.34 |
| MidCliff | cliff_mg_cliff_wall_01 | 0.52 |
| NearCrystal | cliff_fg_crystal_pillar_01 | 0.74 |
| FrontFog | cliff_overlay_fog_front_01 | 1.05 |
| FrontOccluder | cliff_overlay_occluder_front_01 | 1.12 |

背景 2172×724 图统一按 1.25 倍显示，并用 `Parallax2D.repeat_size` 横向重复。

## 8. 平台资源

只使用三张静态平台图：

```text
art/platforms/cliff_plat_ground_flat_01.png
art/platforms/cliff_plat_crystal_01.png
art/platforms/cliff_plat_bridge_01.png
```

碰撞箱没有从贴图自动生成，而是与参考草原关卡一样，在 TSCN 中显式配置矩形碰撞，便于后续手调。

可查看：

```text
layout_preview.png
collision_debug_preview.png
```

## 9. 完成后的场景切换

默认情况下，稳定最终核心后：

1. 写入 `cliff_resonance_cleared`；
2. 显示“鸣晶之灾已平息”；
3. 发出 `CliffLevel.level_cleared` 信号；
4. 不自动切换场景。

如果希望完成后直接通过现有 `DayRuntime.transition_to_level_with_blackout()` 跳到其他 LevelData，在 `CliffLevel` Inspector 设置：

```text
completion_level_id = "你的目标 LevelData id"
completion_entry_id = "default"
```

若保持空字符串，则不会触发自动切换。

## 10. 输入

沿用现有角色控制器。

本关额外使用：

```text
interact
```

并保留与草原脚本一致的 `E` 键 fallback，因此即使 InputMap 的 `interact` 尚未配置，E 仍可校准晶柱。

## 11. 美术资源命名修正

上传包中两个带编号/空格前缀的文件已经在包内规范化：

```text
. cliff_bg_cloud_far_01.png
→ cliff_bg_cloud_far_01.png

3. cliff_bg_crystal_spire_far_01.png
→ cliff_bg_crystal_spire_far_01.png
```
