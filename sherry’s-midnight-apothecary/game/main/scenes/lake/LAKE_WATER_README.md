# Godot 4.x 像素湖面水波与倒影

本方案已经接入 `lake.tscn`。湖水贴图保持静止；6 帧灰度蒙版仅驱动低振幅横向反射扰动和短线高光。

## 节点结构

```text
LakeWater (Node2D, lake_water_effect.gd)
├── WaterBase (Sprite2D)                         # 静止湖面本体
├── ReflectionViewport (SubViewport)            # 低分辨率反射捕获
│   ├── ReflectionWorld (Node2D)
│   │   ├── FarCapture (Sprite2D)
│   │   ├── PortCapture (Sprite2D)
│   │   ├── PostsCapture (Sprite2D)
│   │   └── PlayerCapture (AnimatedSprite2D)
│   └── ReflectionCamera (Camera2D)
├── ReflectionDisplay (Sprite2D)                # reflection_water.gdshader
└── RippleHighlight (Sprite2D)                  # ripple_highlight.gdshader
```

`ReflectionViewport` 捕获水线上方一段场景，`ReflectionDisplay` 在 shader 内将其垂直翻转。也可以把一张“正立、未翻转”的单独反射贴图赋给 `reflection_texture`，此时 viewport 会自动停用。

## Inspector 参数

- `ripple_speed`：蒙版播放速度，单位为帧/秒。默认 `0.8`，完整 6 帧循环约 7.5 秒。
- `ripple_strength`：倒影的最大横向扰动，单位为逻辑像素。静湖建议 `0.4–1.0`。
- `reflection_strength`：倒影整体不透明度。静湖建议 `0.25–0.45`。
- `reflection_fade`：倒影从岸边向下衰减所占水深比例；越小越快消失。
- `highlight_strength`：水面短线高光强度。建议保持在 `0.06–0.14`。
- `pixel_size`：一个逻辑像素包含的采样像素数。默认 `1`；更粗的像素块可用 `2`。
- `reflection_resolution_width`：反射 viewport 宽度。默认 `960`，低配置可降到 `640`。
- `ripple_masks_directory`：6 帧蒙版目录，默认指向现有 `ripple_masks`。

## 蒙版加载与循环

`lake_water_effect.gd` 使用 `DirAccess.get_files_at()` 读取目录内全部 PNG，按零填充文件名排序，再由 `ResourceLoader.load()` 加载。当前文件顺序为：

```text
ripple_mask_01.png ... ripple_mask_06.png
```

脚本用 `ripple_speed` 推进当前帧，并把当前帧、下一帧和帧间混合值同时传给两个 shader。混合只发生在时间维度；所有纹理空间采样仍为最近邻，不会产生平滑模糊。

## 像素风约束

- `project.godot` 的 `textures/canvas_textures/default_texture_filter=0` 已启用全局最近邻。
- 两个 shader 的 sampler 均显式使用 `filter_nearest, repeat_disable`。
- 反射位移先按 `pixel_size` 对齐逻辑像素行，再以纹理 texel 计算 UV 位移。
- 反射只做横向、交替行的细碎扰动，不做垂直大浪和真实流体模拟。
- 高光只有两个离散亮度等级，保留有限色盘和横向短线语言。
- `water_region_mask` 使用 `WaterBase` 的 alpha 限制反射区域。
- 岸边有极窄的接缝门控，随后按 `reflection_fade` 向水深方向逐渐衰减。

## 迁移到其他场景

复制 `LakeWater` 子树和以下三个文件：

```text
lake_water_effect.gd
shaders/reflection_water.gdshader
shaders/ripple_highlight.gdshader
```

给 `WaterBase` 设置湖面贴图，并在 Inspector 中重新指定源精灵和捕获精灵的 NodePath。若使用单独反射贴图，只需赋值 `reflection_texture`，源/捕获节点路径可以留空。
