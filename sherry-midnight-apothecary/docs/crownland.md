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

第六日经药典屋旧旅门抵达时，先由 `home.tscn` 呈现“空与流光之馆原址”，该段不部署场景角色。随后 `crownland.tscn` 的 `DaySixCrownlandEscort` 显示雪莉、恩佐与卢卡实例并锁定玩家输入，三人随对话从最左侧自动行至 `EntryPoints/cathedral`。圣堂事件定格镜头、播放恩佐的黑柱回忆并让卢卡从排水口离队；结束后雪莉恢复控制，恩佐保留在队伍画面中。
