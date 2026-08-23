# Dialogue Character Portrait System（对话系统角色立绘）

`res://night/dialogue/` 下的全局对话系统（`ApothecaryDialogueBalloon`）装载了多机位角色立绘系统，支持在 `.dialogue` 语法层直接配置左中右三个插槽的位置、表情切分与动效。

## 核心机位布局与插槽

| 插槽代号 | 位置 | 默认角色偏好 | 典型用法 |
|---|---|---|---|
| `left`（左侧） | X: 4% ~ 42% | NPC / 访客 | 剧情对话中的对话对象或发起者 |
| `center`（居中） | X: 31% ~ 69% | 特写 / 单人 | 关键发言、特写汇报、独白 |
| `right`（右侧） | X: 58% ~ 96% | 主角 Sherry（雪莉） | 玩家角色自身发言或互动响应 |

- **焦点高亮（Focus Dimming）**：当前发言角色的立绘保持清晰全亮（1.0 亮度），非发言角色的立绘自动微暗（0.62 亮度）并轻微缩放，形成自然的视觉景深与对话焦点。

## 语法层编写规范

在任何 `.dialogue` 文件中，可以通过以下三种方式控制立绘：

### 1. 行标签语法（推荐）
直接在说话角色后添加 `#portrait(...)` 标签：
```dialogue
年轻村民 #portrait(slot=left, expr=happy, anim=bounce): 早上好，雪莉！
雪莉 #portrait(slot=right, expr=thinking, anim=nod): 早上好！今天的药草采摘顺利吗？
```
- **快捷槽位写法**：
  ```dialogue
  年轻村民 #left(happy, bounce): 看到我弹跳了一下吗？
  雪莉 #right(thinking, nod): 收到！
  ```
- **退出与清理**：
  ```dialogue
  年轻村民 #portrait(hide=left): 那我先去干活啦。
  雪莉 #portrait(clear): （整理桌面）
  ```

### 2. 对话指令语法（Command Syntax）
适合在对话分支前、转场时进行精确控制：
```dialogue
do show_portrait("01_young_villager", "default", "left", "slide_in")
do show_portrait("女学者", "happy", "center", "fade_in")
do hide_portrait("left", "slide_out")
do clear_portraits()
```

### 3. 行内 BBCode 语法
```dialogue
[portrait=年轻村民:happy:left:slide_in]这是通过内联标签触发的立绘显示。
```

## 动画效果类型

| 动画标识 | 效果说明 | 适用场景 |
|---|---|---|
| `slide_in` / `slide_out` | 平滑位移 + 透明度淡入/退场（默认） | 角色进场与离场 |
| `fade_in` / `fade_out` | 原地透明度渐变 | 突然出现、幽灵或安静转场 |
| `bounce` / `pop` | 弹性缩放弹跳 | 惊喜、激动、打招呼 |
| `shake` | 水平轻微震颤 | 惊吓、受挫、慌张、寒冷 |
| `nod` | 垂直轻微点动 | 同意、致意、思索后确认 |

## 表情切分与注册表（Portrait Database）

- **中央注册表**：`res://night/dialogue/portrait_database.gd`（`DialoguePortraitDatabase`）。
- **内置 NPC 映射**：已完整覆盖 `01_young_villager` 至 `18_hooded_stranger` 共 18 位村民/NPC 的正面半身立绘，支持直接使用中文身份名称（如 `年轻村民`、`采药妇`、`铁匠`、`女学者`、`修女` 等）或英文文件夹名索引。
- **平滑表情切换（Cross-Fade）**：同一插槽切换不同表情时，插槽内部的双缓冲渲染机制会自动执行 0.2s 交叉淡入淡出，彻底消除切图瞬间的闪烁感。
- **喵斯差分**：`喵斯`、`喵呜`、`卡琳娜·喵斯` 与 `炉边烤鱼的少女` 均使用 `res://characters/mew/exp/` 中的五张差分：`default`、`avert`、`dumb`、`wink`、`exp2_default`。对话中的 `happy` 与 `thinking` 分别是 `wink` 与 `avert` 的可读别名。
- **雪莉立绘**：`雪莉`/`Sherry` 的对话立绘使用 `res://characters/sherry/stand.png`；仅在该资源不可用时回退至旧立绘和待机帧。
- **卢卡立绘**：`卢卡`/`Luca` 的所有对话 UI 使用 `res://characters/luca/stand.png`，包括夜间家中对话、卧室开场、集市喷泉事件与净化睡犬后的长对话；表情参数仍兼容但统一回落到这张立绘。
- **槽位布局保障**：`PortraitLayer` 完成 UI 布局后，会按自身实际像素尺寸计算左（4%–42%）、中（31%–69%）、右（58%–96%）三个槽位的矩形；窗口或 UI 尺寸变化时会重新计算。双缓冲贴图填满各自槽位，因此布局刷新不会把所有立绘压到左侧。
- **主角位置兜底**：当 Dialogue Manager 传入的行未保留旧式 `#left/#right` 标记时，喵斯系列名称仍会回到左槽位，雪莉仍会回到右槽位；有效的标准 `portrait` 标签仍可控制其他角色和中间槽位。

## 对话交互与控制功能

| 控制键 / 按钮 | 快捷键 | 功能说明 |
|---|---|---|
| **快进（Fast）** | 按住 `Ctrl` 或 点击按钮 | 开启 0.2 秒/页高速快进模式，立即显示完整文字并自动推进，遇选项分支自动暂停；在当前页的 0.2 秒等待中关闭快进时，会恢复为正常的点击推进，不会卡住。 |
| **自动（Auto）** | 点击按钮 | 切换自动播放模式（每句约 0.75s 停留）。 |
| **回退（Back）** | 点击按钮 | **返回上一句话**：弹出历史快照堆栈，还原上一句角色、台词、立绘插槽与选项状态，不打开历史窗口。 |
| **回溯（History）** | 点击按钮 / `ESC` 关闭 | **打开对话回溯窗口**：采用黑曜石药剂琉璃风格设计的精致模态弹窗，清晰展示带金边角色前缀的全部历史发言。 |
| **设置（Settings）** | 点击按钮 | 打开暂停菜单设置页。 |
| **读档（Load）** | 点击按钮 | 请求游戏存档读取。 |
