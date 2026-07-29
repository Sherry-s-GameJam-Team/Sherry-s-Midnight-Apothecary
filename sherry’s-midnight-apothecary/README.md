# Sherry’s Midnight Apothecary / 雪莉的午夜药水铺

<!-- PROJECT_ARCHITECTURE_START -->
## 正式项目架构

本仓库是 Godot 4.6、GDScript、2D Forward Plus 项目，基准分辨率为 1280×720，使用 `canvas_items` 拉伸与 nearest 纹理过滤。

游戏是 30 天制的 2D 横板探索、炼药与商店经营游戏：白天探索和采集，夜间炼药与经营；区域通过修复传送门解锁。灾难从第 5 天起由每日内容定义按每四天节奏配置，第 30 天进入最终流程。

### 核心边界

- `AppRoot` 在运行期持续存在并持有全局组合关系。
- `GameSession` 是唯一运行状态容器。
- `GameFlow` 是唯一推进日期、应用 `LevelResult`/`ShopResult` 并决定下一阶段的模块。
- `SceneFlow` 只负责把模式场景装入 `CurrentModeSlot`，不包含游戏规则。
- 静态内容使用 `Resource` 与稳定 ID，并由 `DataRegistry` 在启动时显式注册。
- 关卡内容不包含玩家、主摄像机或正式 HUD；这些由后续的 `DayLevelRuntime` 创建。
- 业务脚本禁止直接调用 Godot 的全局场景切换 API。

### 目录

```text
app/                  持久组合根与启动
core/                 流程、状态、存档、场景装卸、注册表与公共服务
features/             按领域拆分的运行功能
content/definitions/  Resource 静态定义
content/levels/       关卡 visual/gameplay 内容
art/ audio/ ui/       资产
tests/                无第三方插件的架构测试
docs/                 契约、所有权与迁移说明
```

### 本地验证

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
```

详细说明见 `docs/architecture.md`、`docs/data_model.md`、`docs/game_flow.md`、`docs/level_contract.md`、`docs/ownership.md` 与 `docs/migration_plan.md`。
<!-- PROJECT_ARCHITECTURE_END -->

