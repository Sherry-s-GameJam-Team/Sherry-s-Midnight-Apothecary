# 天空主菜单系统

## 入口与运行流程

项目入口仍是 `res://app/app_root.tscn`。`AppRoot` 启动时创建共享的 `PlayerData`、`SaveService` 和 `GameFlow`，但不会立即创建 DayRuntime；它先显示 `res://menu/menu.tscn`。

- **开始游戏**：锁定菜单输入，播放天空下降演出；屋檐完全遮住 viewport 后重置玩家数据、创建 Day 1 存档并让 DayRuntime 从 `bedroom` 关卡开始。
- **继续游戏**：启动时通过 `SaveService.has_save()`/`load_game()`决定按钮状态。DAY 存档进入 Bedroom；NIGHT 存档保持 NightRuntime，不强制转换为白天；ENDING 保留 `GameFlow` 当前语义。
- **设置**：复用全局 `PauseMenu.Page.SETTINGS`，包括 Master 音量和全屏选项。
- **退出**：调用 `SceneTree.quit()`。

菜单状态由 `MenuController.MenuState` 管理。只有 `IDLE` 接受按钮输入，因此无法重复启动 Tween、换场或起床动画。

## Bedroom 与起床动画

Bedroom 仍是 `res://day/levels/home/bedroom.tscn`，起床动画仍是 `SleepToWake` 的 `AnimatedSprite2D`，动画名和帧没有被菜单代码复制。

菜单通过以下链路接入：

1. `GameFlow` 创建 DayRuntime，并传入初始关卡 `&"bedroom"`、延迟演示和延迟标题参数。
2. DayRuntime 在把 Bedroom 加入场景树前关闭该关卡 `AnimationPresentationExecutor.auto_start`。
3. 执行器的 `prepare()`只隐藏 `player_visual_path` 指向的角色表现节点，并禁用 Player 自身的物理与输入回调；Player 根节点及其 Camera2D 保持激活。屋檐完全遮挡时，MenuCamera 会主动释放 viewport，避免它继续拍摄菜单空坐标而出现灰屏。
4. Bedroom 创建完成后，`BedroomIntroBridge` 在屋檐揭开期间调用实际 `AnimationPresentationExecutor.start()`，让现有 `SleepToWake` 直接承担加载后的视觉衔接。
5. 菜单桥接使用强制重播参数，因此即使存档已有当天的 `sleep_to_wake` Flag，仍会播放本次 opening shot；普通世界内进入仍遵守 one-shot Flag。
6. 执行器监听真实 `AnimatedSprite2D.animation_finished`，完成后恢复 Player 并发出 `completed`。
7. Bridge 收到 `completed` 后恢复 DayRuntime 与全局游戏 UI。起床加载期间的“结束白天”等交互会被锁定。Home 和 Bedroom 的 `LevelData.show_title_card` 均为 `false`，左上角关卡标签和大标题卡都不会再显示。

不要用固定 Timer 猜测起床动画长度。若将来替换起床动画，只需继续让 Bedroom 的执行器指向正确的 `AnimatedSprite2D`、Player 和出生 Marker。

## SkyProfile

`MenuSkyProfile` 是独立 Resource。主要字段包含：日期阈值、三段天空颜色、环境色、两层云纹理/速度/透明度、月亮、星星、魔法粒子、前景色、阴影强度、噪声、可选覆盖纹理、附加 Shader 参数和音乐修饰。

菜单只调用：

```gdscript
var profile := sky_profile_resolver.get_profile_for_menu(has_save, saved_mode)
sky_controller.apply_profile(profile)
```

菜单正常启动不再按日期自动变成灾难天空：新游戏和 DAY 存档始终使用明亮的 `day_01_default.tres`；只有读取 `GameFlow.Mode.NIGHT` 存档时使用 `night_default.tres`。其余日期 Profile 保留给 Debug 预览和未来 WorldState。

日期里程碑调试映射：

- Day 1–6：`day_01_default.tres`
- Day 7–13：`day_07_warning.tres`
- Day 14–20：`day_14_anomaly.tres`
- Day 21–29：`day_21_disaster.tres`
- Day 30+：`day_30_finale.tres`

Resolver 选择 `start_day <= 当前 day` 的最近 Profile。`world_state.sky_profile_id` 可以覆盖日期结果，为未来七大灾难、天气或剧情 Flag 提供接口。

### 新增 Day 8 特殊天空

1. 复制 `res://menu/sky/profiles/day_07_warning.tres` 为新的 `.tres`。
2. 修改 `profile_id`、`display_name`、`start_day = 8` 和视觉参数。
3. 在 `res://menu/menu.tscn` 的 `SkyProfileResolver.profiles` 数组中加入该 Resource。

不需要修改 Menu Camera、Transition、SkyController 或 Bedroom 代码。Day 8 会选择新 Profile；Day 9 之后继续使用它，直到遇到下一个更大的 `start_day`。

## 正式素材替换

当前云层在 `cloud_texture` 为空时使用低成本程序占位轮廓；月亮、森林、树冠、药典屋和屋顶也都是独立节点。替换方式：

- 云：为 Profile 的 `cloud_texture` 指定正式透明 Texture2D；Far/Near 层会使用同一纹理与不同速度、透明度。
- 月亮：为 Profile 的 `moon_texture` 指定正式透明 Texture2D；为空时 `%Moon` 使用可替换的程序月牙占位。
- 森林、树冠、药典屋、屋顶：分别替换 `DistantForest`、`TreeCanopyForeground`、`ApothecaryHill`、`RoofForeground` 的视觉节点，保留节点名和层级即可。
- Profile 中不要保存脚本硬编码路径；资源全部从 Inspector 或 `.tres` 引用。

## Shader 与 Camera 参数

`res://menu/shaders/menu_shadow.gdshader` 暴露：

- `progress`：遮罩覆盖进度。
- `softness`：纵向软边宽度。
- `noise_strength`：手绘雾/墨迹扰动，建议保持低于 `0.06`。
- `shadow_color`：默认深蓝紫而非纯黑。

天空 Shader 的 `top_color`、`horizon_color` 和 `bottom_color` 完全由 Profile 设置。此前逐像素变化的哈希噪声已经移除；`noise_strength` 暂时保留只为兼容旧 Profile，不再影响天空画面。如需纸张纹理，应通过可控的正式 overlay texture 添加。

运镜 Marker 位于 `menu.tscn/World`：`MenuCameraStart`、`CloudPassPoint`、`ForestPassPoint`、`RoofTransitionPoint`。调整 Marker 的 Y 改变经过位置；调整 `MenuCameraDirector.play_descent()`三段 Tween 时长可改变总下降速度。当前约为 4.4 秒运镜加 0.34 秒屋檐覆盖。

视差系数在 `MenuCameraDirector.parallax_factors`，当前为 1.0、1.15、1.4、1.7。场景遵循项目现有 1280×720 和 `canvas_items` stretch，不应改成 3D 或 Perspective Camera。

## 音频与原生 fallback

Menu 预留 `MenuBGM`、`WindAmbience`、`BirdAmbience`、`TransitionWhoosh`、`LeavesAmbience` 五个 AudioStreamPlayer。没有正式音频时 stream 为空且不会报错；获得素材后直接在 Inspector 指定。

项目没有 SceneManager、TransitionManager 或 AudioManager，因此场景装载、Tween、Shader、Camera2D、粒子和 AudioStreamPlayer 均使用 Godot 4.6 原生实现。现有 Dialogue Manager 和 TileMapDual 插件没有被菜单流程依赖；即使插件不可用，核心菜单和换场逻辑仍是纯 Godot fallback。

Debug Build 会在菜单底部显示 Profile 上一项/下一项按钮；Release Build 自动隐藏。也可在 `SkyController.preview_profile` 中直接指定任意 `.tres` 进行 Inspector 预览。
