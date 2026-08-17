# 《雪莉的午夜药水铺》— AI Agent 工作规则（中文译本）

> 本文是根目录 `AGENTS.md` 的中文翻译，方便团队阅读。执行规则以 `AGENTS.md` 为准；修改规则时必须同步更新中英文两份文档。

## 规范工程根目录

本仓库包含一个外层工作区目录，以及一个嵌套的 Godot 工程。

- 仓库／工作区根目录：包含本文件、`AGENTS.md` 和 `.git/` 的目录。
- **唯一正式 Godot 工程根目录：**`sherry-midnight-apothecary/`。
- `project.godot`、`README.md`、游戏源码、资源、测试、工具和项目文档都应位于正式 Godot 工程根目录之下。
- 除非任务明确针对仓库级元数据，**禁止在 `AGENTS.md` 同级位置创建游戏文件、笔记、生成资源、脚本或临时文件**。
- Godot 命令应从 `sherry-midnight-apothecary/` 中运行，或者通过 `--path` 指向该目录。

新增文件前，必须先阅读 `sherry-midnight-apothecary/docs/PROJECT_STRUCTURE.md`，并根据文档选择目标目录。若没有合适位置，应先询问，不得擅自创建新的顶层目录。

## 架构边界

- `app/` 负责常驻的 `AppRoot` 和最小化的昼夜流程 `GameFlow`。
- `shared/` 负责跨运行时共享的数据与可复用系统；共享接口应保持精简、明确。
- `day/` 负责白天探索；`night/` 负责夜间炼药与商店玩法。
- `menu/` 负责标题与菜单表现；`minigames/` 负责彼此隔离的小游戏模块。
- 静态定义使用 `shared/definitions/` 中的 Godot Resource，并由使用方显式引用。
- 未经明确批准，不得引入事件总线、全局世界状态、自动 Resource 注册中心、重复的场景流程服务或跨场景长期持有的节点引用。
- `AppRoot`、`GameFlow`、`PlayerData`、`DayResult`、`NightResult` 和 `project.godot` 都是共享整合契约，修改时必须谨慎。

## 文件放置规则

- 在可行的情况下，一个功能的 `.gd`、`.tscn`、`.tres`、着色器和功能专用美术应放在该功能附近。
- 跨模块复用的原始／表现美术放在 `art/`，共享音频放在 `audio/`，共享玩法或 UI 代码放在 `shared/`。
- 自动化测试与测试夹具放在 `tests/`；不得把测试场景放进正式功能目录。
- 开发工具脚本放在 `tools/`；工具的临时输出必须写入 `tmp/`，明确需要保留的交付物或预览写入 `outputs/`。
- `docs/` 用于维护中的项目文档。除非 Markdown 专门说明其所在目录，否则不要把规划文档散落在源码目录中。
- `addons/` 是第三方或编辑器插件代码；除非任务明确针对插件，否则不要修改。
- `.godot/`、`tmp/`、`outputs/`、`dist/`、`__pycache__/` 以及生成／导入产物都不是正式源码目录。
- 禁止再创建嵌套的 Godot 工程，也禁止把完整原型复制进正式源码路径。原型或参考工程只能隔离放在 `tools/` 中。
- `game/`、`assets/` 和 `examples/` 属于历史／兼容区域：修改前应检查现有引用，新功能默认不得放入这些目录。

## 编辑与验证

- 保留用户已有修改，避免无关清理或大规模文件移动。
- 使用以 `sherry-midnight-apothecary/` 为根的 `res://` 路径；禁止在 Godot Resource 中写入本机绝对路径。
- Godot 已生成 `.gd.uid` 时，应保持它与对应脚本配对；不得手工创建导入缓存文件。
- 移动 Godot Resource 时，必须在同一次修改中更新所有 `res://` 引用并验证解析。
- 每次新增功能，或者改变功能的玩家可见行为、操作方式、数据流或架构时，必须在同一次修改中同步更新 `sherry-midnight-apothecary/docs/` 下对应的 Markdown 功能文档。若没有合适文档，应在该目录新建，并登记到 `docs/FEATURES.md`；功能文档仍然过期时，不得视为功能已完成。
- 最低验证要求是在 Godot 工程根目录运行：

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
```

开发过程中优先运行范围最小的相关测试；若修改影响共享契约或项目结构，则最终必须执行以上两条命令。如果环境中没有 `godot`，应明确说明未能进行验证。

