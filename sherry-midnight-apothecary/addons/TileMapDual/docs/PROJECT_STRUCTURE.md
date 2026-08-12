# 项目结构与文件放置规范

> 本文描述当前仓库的真实结构及今后的指定路径。它是新增、移动文件时的首要目录依据；架构细节另见 `architecture.md`、`game_flow.md` 和 `ownership.md`。

## 1. 两层根目录

```text
Sherry-s-Midnight-Apothecary/          仓库 / Codex 工作区根目录
├── .git/
├── .gitattributes
├── AGENTS.md                           AI 工作规则（英文执行版）
├── AGENTS.zh-CN.md                     AI 工作规则（中文译本）
└── sherry’s-midnight-apothecary/       唯一正式 Godot 工程根目录
    ├── project.godot
    ├── export_presets.cfg
    └── ...
```

Godot 的 `res://` 指向内层 `sherry’s-midnight-apothecary/`，不是外层仓库根目录。所有游戏源码、场景、资源、测试、工具和项目文档默认都必须位于内层。不要在外层创建 `app/`、`assets/`、`scripts/`、`tmp/` 等平行目录。

## 2. 游戏定位与运行流程

《雪莉的午夜药水铺》是 Godot 4.6 项目，窗口基准为 1280×720。核心循环是白天探索与夜晚炼药/经营交替进行：

```text
AppRoot（全程常驻，持有唯一 PlayerData）
  └── GameFlow
      ├── DayRuntime   → DayResult
      ├── NightRuntime → NightResult → 存档 → 下一天
      └── 第 30 天夜晚结束 → Ending
```

入口场景为 `res://app/app_root.tscn`。全局自动加载目前包括 `DialogueManager` 与 `SoundManager`；启用的编辑器插件包括 Dialogue Manager 和 TileMapDual。

## 3. 正式目录地图

```text
res://
├── app/             应用入口、常驻根节点、昼夜流程
├── shared/          昼夜共享数据、定义、药水系统与通用 UI
├── day/             白天探索运行时
│   ├── player/      玩家控制
│   ├── camera/      白天相机
│   ├── combat/      战斗
│   ├── harvesting/  采集
│   ├── interactables/ 交互物
│   ├── puzzles/     谜题
│   ├── portals/     传送/关卡连接
│   ├── levels/      正式白天关卡
│   ├── systems/     白天领域系统
│   ├── ui/          白天 UI
│   └── art/         仅白天使用的美术
├── night/           夜间炼药与商店运行时
│   ├── alchemy/     炼药玩法
│   ├── customers/   顾客
│   ├── shop/        商店流程
│   ├── economy/     夜间经济
│   ├── dialogue/    对话内容与气泡场景
│   ├── levels/      夜间场景
│   ├── ui/          夜间 UI
│   └── art/         仅夜间使用的美术
├── menu/            主菜单、天空、转场和菜单 UI
├── minigames/       相对独立的小游戏模块
├── art/             跨模块复用的角色、环境、特效、道具与 UI 美术
├── audio/           BGM、音效及声音管理
├── tests/           自动化测试、测试运行器与 fixtures
├── docs/            维护中的架构、流程、数据模型及项目说明
└── addons/          第三方 / 编辑器插件
```

### 共享数据

`shared/definitions/` 放置 `IngredientData`、`RecipeData`、`PotionData`、`LevelData`、`StoryItemData` 等静态 Resource 类型。使用方应显式引用资源，不扫描目录自动注册。

## 4. 辅助、生成与历史目录

这些目录当前真实存在，但不应被当成新增正式功能的默认位置：

| 路径 | 当前用途 | 规则 |
|---|---|---|
| `tools/` | Python/PowerShell 资源处理脚本、隔离的白盒参考工程 | 工具代码放这里；不得让嵌套参考工程成为正式依赖 |
| `tmp/` | 截图脚本、资源处理预览、临时实验 | 可删除的工作文件；不得被正式场景依赖 |
| `outputs/` | 有意保留的处理结果、预览图/视频 | 只放明确交付物；不是源码目录 |
| `dist/` | 打包产物 | 不手工维护，不从这里加载游戏资源 |
| `examples/` | 插件或技术示例 | 仅参考；新玩法不要在此开发 |
| `game/` | 较早期/兼容期玩法与大量炼药素材 | 新功能默认不要继续扩展；修改前先检查 `res://game/` 引用 |
| `assets/` | 历史通用素材（shader、tileset 等） | 优先复用现有引用；新素材按归属放 `art/` 或具体功能目录 |
| `.godot/` | Godot 导入缓存 | 自动生成、已忽略，不编辑不提交 |

`game/`、`assets/` 目前仍可能被正式场景引用，因此本文只标记边界，不擅自迁移或删除。后续整理必须先统计引用，再分批移动并同步修复所有 `res://` 路径。

## 5. 新文件放置决策

```text
新增文件
├── 属于单一玩法/场景？ → 放到 day/、night/、menu/ 或 minigames/ 对应功能旁
├── 被昼夜共同复用？   → shared/
├── 跨模块美术或声音？ → art/ 或 audio/
├── 自动化验证？       → tests/
├── 开发/资源处理脚本？→ tools/（输出到 tmp/ 或 outputs/）
└── 维护性说明？       → docs/
```

不能归入以上类别时，先更新本文或与维护者确认，不要自行创建新的 `res://` 顶层目录。

## 6. 明确禁止

- 禁止在外层仓库根目录生成游戏代码或资源。
- 禁止再创建嵌套 `project.godot`；`tools/` 中已有的隔离参考工程除外，但不要复制扩散。
- 禁止把临时截图、AI 生成中间图、处理帧和调试脚本散落到正式功能目录。
- 禁止让正式场景依赖 `tmp/`、`outputs/`、`dist/`、`examples/` 或工具中的参考工程。
- 禁止未经引用审计就批量移动 `game/`、`assets/` 或 Godot 资源。
- 禁止引入新的全局事件总线、世界状态、自动资源注册中心或重复场景切换服务，除非架构变更已明确批准。
- 新增功能或改变功能行为、操作、数据流、架构时，必须同步更新 `docs/` 中对应的 Markdown；若需新建功能文档，还应登记到 `docs/FEATURES.md`。

## 7. 验证

在内层 Godot 工程根目录执行：

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
```

若移动了资源，还应使用 `rg 'res://旧路径'` 确认旧引用已经清零，并检查 Godot 导入/解析无错误。
