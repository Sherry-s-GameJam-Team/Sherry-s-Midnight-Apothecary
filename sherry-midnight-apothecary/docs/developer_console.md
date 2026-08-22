# Developer Console (开发控制台)

开发控制台可通过 `` ` ``（反引号 / 波浪号键）或 F1 键在日间探索和夜间工坊/炼药阶段随时唤出与关闭。

控制台可随任意单一日间场景直接运行；它通过运行时接口连接 `GameFlow`，避免在 `DayRuntime` 预加载关卡时形成脚本编译循环。

## 日间场景与子场景切换 (scene / level)

`scene` 命令支持动态解析已注册在 `DayRuntime.LEVELS` 中的所有场景及独立子场景，并在非运行时测试时自动回退加载目标场景。

### 使用方法

- `scene` 或 `scene list`：列出所有可用场景/子场景的序号对照表。
- `scene <序号>`：通过数字序号直接跳转（例如 `scene 1` 或 `scene 25`）。
- `scene <场景ID>`：通过英文 ID 跳转（例如 `scene vespervale_garden`、`scene vespervale_inner` 或 `scene aurem_clockyard_inside`）。
- `scene <别名/中文名>`：通过英文别名或中文名称/模糊关键词跳转（例如 `scene 暮息庭院`、`scene 钟塔内部`、`scene 水下暗道`、`scene 钟庭`、`scene 卧室`）。

### 全部场景与子场景序号对照表

| 序号 | 关卡 ID | 显示名称 | 常用别名 / 检索词 | 资源路径 / 说明 |
| :---: | :--- | :--- | :--- | :--- |
| **1** | `market` | 流明街 | `town`, 市集, 集市, 城镇 | `res://day/levels/market/town/town_level.tres` |
| **2** | `home` | 工坊 | `shop`, `apothecary`, 家, 药水铺 | `res://day/levels/home/home_level.tres` |
| **3** | `bedroom` | 卧室 | `bed`, `room`, 卧室, 二楼 | `res://day/levels/home/bedroom_level.tres` |
| **4** | `forest` | 常霁云林 | `raintree`, `tree`, 雨树林, 森林 | `res://day/levels/forest/forest_level.tres` |
| **5** | `forest_interior` | 云下树屋 | `interior`, `luca`, `treehouse`, 树屋, 卢卡工坊 | `res://day/levels/forest/interior/forest_interior_level.tres` |
| **6** | `forest_crown` | 树冠天台 | `crown`, `rooftop`, 树冠, 天台 | `res://day/levels/forest/crown/forest_crown_level.tres` |
| **7** | `lake` | 镜湖 | `mirror_lake`, `lake`, 镜湖, 湖 | `res://day/levels/lake/lake_level.tres` |
| **8** | `grassland` | 翡翠原 | `grass`, `emerald`, 草地, 平原 | `res://day/levels/grassland/grassland_level.tres` |
| **9** | `emerald_field` | 翡翠原野·瘴气 | `field`, `miasma`, 翡翠原野, 瘴气 | `res://day/levels/grassland/emerald_field_level.tres` |
| **10** | `golden_cliff` | 烁金横崖 | `cliff`, 横崖, 断崖, 烁金 | `res://day/levels/golden_cliff/golden_cliff_level.tres` |
| **11** | `golden_cliff_village` | 涟汀村 | `village`, 废村, 村庄 | `res://day/levels/golden_cliff/village/village_level.tres` |
| **12** | `lake_bottom` | 阿里特之泪·湖床 | `underwater`, `lakebed`, 湖床, 湖底, 沉没回廊 | `res://day/levels/lake_bottom/lake_bottom_level.tres` |
| **13** | `gate_chamber` | 旧旅门维护站 | `chamber`, `gate`, 维护站, 密室, 封印大门 | `res://day/levels/lake_bottom/gate_chamber_level.tres` |
| **14** | `crimson_vale` | 猩红谷地 | `crimson`, `vale`, 猩红 | `res://day/levels/Crimson Vale/crimson_vale_level.tres` |
| **15** | `crimson_vale_challenge` | 猩红谷地·挑战 | `challenge`, `vale_challenge`, 挑战关 | `res://day/levels/Crimson Vale/crimson_vale_challenge_level.tres` |
| **16** | `alkeon_boss` | 血叶猎王·阿尔凯昂 | `alkeon`, `boss 2`, 血叶猎王, 阿尔凯昂 | `res://day/levels/Crimson Vale/alkeon_boss_level.tres` |
| **17** | `aurem_clockyard` | 奥勒姆钟庭 | `clockyard`, `aurem`, `clock`, 钟庭 | `res://day/levels/Aurem Clockyard/aurem_clockyard_level.tres` |
| **18** | `aurem_clockyard_inside` | 奥勒姆巨钟塔·内部 | `inside`, `clockyard_inside`, 钟塔内部, 发条室, 齿轮井, 钟摆厅 | `res://day/levels/Aurem Clockyard/inside.tscn` |

Vespervale 的正式调试入口使用运行时注册表的末尾序号，当前为 `vespervale_garden`、`vespervale_inner`、`vespervale_runner`。序号可能随着新关卡注册变化，推荐使用 ID 或别名跳转。
| **19** | `lake_cliff_underwater` | 镜湖·水下暗道 | `underwater_tunnel`, `lake_underwater`, 水下暗道, 水下通道 | `res://day/levels/lake/lake_cliff_underwater.tscn` |
| **20** | `cliff` | 烁金断崖 | `shimmering_cliff`, `resonance_cliff`, 鸣晶断崖 | `res://day/levels/cliff/cliff.tscn` |
| **21** | `lakebed` | 湖床遗迹原型 | `lakebed_proto`, 湖床原型 | `res://day/levels/lakebed/lakebed.tscn` |
| **22** | `grassland_proto` | 翡翠原·原野原型 | `grass_proto`, `grassland_level`, 平原原型 | `res://day/levels/grassland/level.tscn` |
| **23** | `miasma_purifier` | 瘴气净化·小游戏 | `purifier_minigame`, `miasma_game`, 净化小游戏 | `res://day/minigames/miasma_purifier/miasma_purifier.tscn` |
| **24** | `control_system_demo` | 机关控制系统演示 | `mechanisms_demo`, `control_demo`, 机关演示 | `res://day/interactables/control_system/control_system_demo.tscn` |
| **25** | `vespervale_garden` | 暮息庭院 | `vespervale`, `garden`, 暮息谷, 暮息庭院, 花园, 庭院 | `res://day/levels/Vespervale/garden.tscn` |

## 其他常用控制台指令

- `boss 2`：直接进入【血叶猎王·阿尔凯昂】Boss 战竞技场，并自动装备无限药水。
- `title`：重新播放当前场景的标题动画（Title Card）。
- `to <normal|corrupted>`：将当前支持环境切换的场景切换为常态或异变态。
- `status`：显示当前运行状态（Day/Night 模式、天数、地点、生命值、金钱、负债、背包等）。
- `give <植物序号/ID> [数量]` / `take <植物序号/ID> [数量]`：增减背包植物材料。
- `potion <药水ID/序号> [数量] [品质]`：生成指定药水。
- `temp <数值>`：设置当前炼药温度（0-100）。
- `get <参数>` / `set <参数> <数值>` / `add <参数> <数值>`：查询或修改玩家数值（money, health, max_health, debt, inventory.ID）。
- `set day <0-30>`：设置当前天数，并重新加载当前的日间或夜间运行时；会保留当前日间地点，但会重新判定该天的剧情事件。
- `day` / `night`：在日夜模式之间切换。
- `clear`：清空控制台输出。
- `close`：关闭控制台。
