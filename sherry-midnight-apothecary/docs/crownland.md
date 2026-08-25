# 王畿

王畿是独立的白天探索关卡，场景资源位于 `res://day/levels/crownland/`，通过 `crownland_level.tres` 注册为 `LevelData`（ID：`crownland`）。王座之间的可玩首领场景另由 `crownland_boss_level.tres` 注册（ID：`crownland_boss`），供 Day 6 的家中地图锚点直接进入。

## 场景部署

- `FS`：正常与腐化天空按环境状态切换，并横向铺设以覆盖整段关卡。
- `MS`：王城远景使用独立视差层，形成城市纵深。
- `CS`：依次部署城镇、加冕广场、圣堂与王宫内殿；腐化时替换为被侵蚀的花园前景。
- `WorldBounds`：提供地面和左右边界；`Player` 使用通用 Sherry 表现、碰撞、药水投掷与边界驱动相机。
- `EntryPoints`：提供 `default`、`from_home`、`from_town`、`square`、`cathedral` 和 `palace`，供关卡切换与调试定位使用。`boss.tscn` 也提供 `from_home`，作为“王庭·王座之间”锚点落点。

## 环境状态

`CrownlandLevel` 继承 `DayLevelEnvironment`。调用 `set_corrupted(true)` 会显示腐化天空和花园；恢复为 `false` 后会重新显示王都、广场、圣堂及王宫前景。

## Day 6 入场演出

第六日经药典屋旧旅门抵达时，先由 `home.tscn` 呈现“空与流光之馆原址”，该段不部署场景角色。随后 `crownland.tscn` 的 `DaySixCrownlandEscort` 显示雪莉、恩佐与卢卡实例并锁定玩家输入。三者根据各自脚底偏移对齐 `WorldBounds/Ground` 顶面，行进补间只改变 X 坐标，从最左侧水平移动至 `EntryPoints/cathedral`。圣堂事件定格镜头、播放恩佐的黑柱回忆并让卢卡从排水口离队；结束后雪莉恢复控制，恩佐保留在队伍画面中。

## 后庭花园剧情演出（`garden.tscn`）

在进入王座之间 Boss 战前，`garden.tscn` 承接王宫后庭散步剧情：
- **对话资源**：`res://day/levels/crownland/garden.dialogue`（起点标签：`king_garden_start`），使用 `ApothecaryDialogueBalloon` 呈现。
- **立绘注册**：国王立绘映射至 `res://characters/king/stand.png`，雪莉位于右侧，恩佐居中，国王位于左侧。
- **视觉层级**：初始呈现洁白未受污染的王畿后庭（`garden_normal.png` + `skybox_normal.png`）与黑色大理石柱（`pillar.png`）。
- **分支选择**：
  - 选项 A：*“我不会用别人的生命炼药。”*
  - 选项 B：*“如果这真能救人……为什么要用黑魔法？”*
  - 选项分支仅影响雪莉的陈词细节，随后合流进入国王吸收花园生命力的演示。
- **环境腐化与幻象破灭**：
  - 事件 `drain_garden_life` 触发石柱暗红脉络脉冲与画面震颤。
  - 事件 `corrupt_garden_transform` 平滑淡入被腐化的枯萎花园（`garden_corrupted.png`）。
  - 事件 `break_illusion_shatter` 触发屏幕碎裂闪光，切换为腐化天空盒（`skybox_corrupted.png`）与真实荒芜景象。
- **封路与前往王座之间**：
  - 国王封锁后路，发布主线任务 `最后的邀请`（“跟随国王前往王座之间”）。
  - 事件 `corridor_heartbeat` 带来低频震动与心跳氛围。
  - 最终事件 `trigger_boss_battle` 淡出并平滑衔接至 `res://day/levels/crownland/boss.tscn` 展开首领战。
