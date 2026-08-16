# 阿尔维斯母树 · 树干爬塔场景包

目标场景：`res://day/levels/forest/interior/forest_interior.tscn`

这是一个独立的约 5 分钟双角色解谜/爬塔关卡，按现有白天运行时接口搭建：

- 根节点：`DayLevelEnvironment`
- Sherry：复用 `res://shared/player/day_player_controller.gd`
- Luca：复用 `res://characters/luca/luca_player.tscn`
- 双角色：复用 `res://day/levels/forest/shared/forest_party_controller.gd`
- 唯一 Camera2D 随当前角色 reparent
- `C` 切换角色（场景会在 `_enter_tree()` 确保 `switch_character` 绑定 C，不覆盖已有绑定）
- Luca 机关：靠近后 `E`
- 水枪：`E` 进入控制，`W/S` 调整角度，自动喷水，`E` 退出
- 污泥：Godot `Polygon2D + Shader + CPUParticles2D`，支持 `purification_potion` 与水枪净化
- 水枪：Godot `Line2D + CPUParticles2D + physics ray query`，不依赖水流贴图
- 坠落伤害：通过 `DayRuntime.apply_player_damage()`
- 红水只存在树干中央水柱
- 无敌人

## 5分钟流程

1. 0:00–0:40：C 切换 + RootLift 教学。
2. 0:40–1:20：Luca 转动根梁，Sherry 横跨中央水柱。
3. 1:20–1:55：第一块污泥，可用净化药水走捷径，也可走侧路。
4. 1:55–3:00：水枪主谜题，W/S 调枪口，清理两处污泥并管理水压。
5. 3:00–4:00：闸门 + 第二升降根组合机关。
6. 4:00–4:35：恢复 Root / Water / Crown 三个动力节点，解锁 Luca 直达梯。
7. 4:35–5:20：Luca 到顶部开最终根门，Sherry 完成最后攀爬，抵达树冠出口。

为兼容当前 Luca 可能只提供水平移动的实现，场景在几个阶段边界使用 `StageSyncTrigger` 将落后过远的 Luca 移到本阶段的旧世界维护平台。它不会在按 C 时改变角色位置，仅在 Sherry 首次推进到新阶段时触发。

## 树冠出口

出口预留目标：

- Level ID：`forest_crown`
- Entry ID：`from_interior`

如果 `forest_crown` 尚未注册，抵达出口只打印 warning，不会直接 `change_scene_to_file()`。
