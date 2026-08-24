# 梦疗院·病栋回廊 (Vespervale Inner Ward Corridor) 关卡设计规范

## 概述
梦疗院·病栋回廊 (`res://day/levels/Vespervale/inner.tscn`) 采用 **“上层卢卡窗帘潜行避医 + 下层雪莉梦境解密”** 的不对称双人机制。

### 从暮息庭院进入

`garden.tscn` 的 `ChurchPortal` 进入 `vespervale_inner`，并使用 `from_garden` 出生点。首次从该入口抵达时，`VespervaleInnerLevel` 自动播放 `vespervale_inner_entry.dialogue`：雪莉位于一楼、卢卡位于二楼，两人确认楼层上下对应但无法直接相通，并提示机关可能跨楼层联动、卢卡可利用床帘躲避巡房护士。

对话期间禁止 C/Tab 切换并锁定两名角色。正常结束后写入 `vespervale_inner_entry_dialogue_complete`，恢复雪莉为当前操控角色；之后从庭院往返不会重复播放。

---

## 核心机制：卢卡窗帘躲避与护士巡逻

### 1. 四大图案窗帘与药柜躲避隐蔽
- 上层走廊设有 4 个带独特图案的窗帘以及 1 个药柜作为藏身掩体：
  - **Curtain1 (x: 175)**：对应图案【眼】
  - **Curtain2 (x: 492)**：对应图案【钟】
  - **Cabinet2 (x: 750)**：上层药柜掩体，具备与窗帘完全一致的躲避效果
  - **Curtain3 (x: 1012)**：对应图案【羽毛】
  - **Curtain4 (x: 1372)**：对应图案【月亮】
- **自动隐蔽机制**：
  - 卢卡只要移动到任意窗帘或 **Cabinet2 药柜** 范围内（`hide_detection_radius = 48px`），即**自动进入隐蔽状态**。
  - 隐蔽时卢卡层级后置（位于 `z_index = 14` 的柜体/床帘后方）并伴随微弱半透明遮蔽反馈，提灯光芒扫过不会触发被抓。
  - 卢卡走出掩体范围后立即恢复暴露状态。

---

### 2. 护士巡查 AI 机制 (`nurse.tscn` / `nurse.gd`)
- **巡逻顺序**：
  - 护士从右方长廊走来（`spawn_x = 1800`）。
  - 严格按照 **Curtain 2 → Curtain 1 → Curtain 4 → Curtain 3** 的顺序分别移动并巡查。
  - 在每个窗帘前停留 **2.0 秒**，提灯光芒进行高亮探查。
  - 巡查完 3 号窗帘后，护士向右走出长廊屏幕（`exit_x = 1850`），并**立即重新开始**下一轮从右至左的巡逻循环。
- **24FPS 循环行走动画 (`nurse_sprite_frames.tres`)**：
  - 使用 `res://day/levels/Vespervale/src/all_frames_24fps/` 中的 97 帧行走动画（`walk_000.png` ~ `walk_096.png`）。
  - 护士巡逻行进时播放流畅的 24 FPS 循环行走动画；停顿探查时暂停在当前帧。
- **独立可调护士场景 (`nurse.tscn`)**：
  - 包含 `LanternPivot`（Marker2D 节点），方便开发者在编辑器中随意拖动微调提灯光线、碰撞检测区（`LanternSpotArea`）及点状光晕的相对位置。

---

### 3. 被抓判定与黑屏重置
- 若护士的点状光照射在**未隐蔽**的卢卡身上：
  - 触发全黑遮罩渐变淡出（Black Screen Fade Out）。
  - 将卢卡平滑重置传送至最左侧的 **Curtain 1（1号窗帘）** 下。
  - 护士的巡逻流程重置回右侧起点重新开始 2143 流程。
  - 屏幕黑屏淡入恢复控制。

---

### 4. 药柜信件展示系统 (`Cabinet1` & `letter_viewer_dialog.tscn`)
- 玩家靠近下层 `Cabinet1` 时出现 `按 E 查看信件` 交互提示。
- 按 `E` 键打开全屏半透明黑色背景信件检视器：
  - 展示 `res://day/levels/Vespervale/letter/` 中的 3 张信件（`letter1.png`, `letter2.png`, `letter3.png`）。
  - **移开并置底翻页特效**：点击下一张（或按 `D`/`→`/`Space`）时，当前顶层信件向右滑出、层级降低到底部、并平滑回缩垫入牌堆下方，下一张信件放大升至顶层；点击上一张（或按 `A`/`←`）逆向翻阅。
  - 右上角设有 `✕` 叉号关闭按钮（亦支持 `ESC` 键关闭），关闭后自动恢复玩家角色行动。

### 5. 暗门四位图案滚轮锁 (`wall1` & `dial_lock_puzzle_dialog.tscn`)
- 玩家靠近下层 `wall1` 柱体/暗门时出现 `按 E 解锁` 交互提示。
- 按 `E` 键打开半透明黑色遮罩的四位图案滚轮锁：
  - 锁具外壳使用 `res://day/levels/Vespervale/src/lock.png`。
  - 拥有 4 个纵向滚轮槽位，支持点击上下箭头（`▲`/`▼`）或滚动鼠标滚轮翻转切换图案。
  - 图案资源来源于 `res://day/levels/Vespervale/src/key/`：
    - `bell.png` (钟)
    - `eye.png` (眼)
    - `moon.png` (月)
    - `feather.png` (羽)
  - **正确密码组合**：**【钟、眼、月、羽】**。
  - 解锁成功后：
    - 滚轮锁具伴随金光与绿光成功提示并自动关闭。
    - **`wall1` 碰撞体即刻解除**（`CollisionPolygon2D.disabled = true`），玩家与角色可畅通无阻穿行。
    - **`wall1` 渲染层级提升至 `z_index = 20`**，使柱子变为前景遮罩，角色穿过时柱子自然遮挡角色身体。

---

### 6. 长廊边界与 Boss 战转场
- 原无尽折返机制已取消，玩家沿长廊向右行进越过最右端边界（`x ≈ 4600`）时，系统自动触发**黑屏淡出并无缝传送至深层病院花园 Boss 战场景** (`res://day/levels/Vespervale/vesper_boss.tscn`)。

### 7. `wall2` 现实状态虚化相位穿行 (`wall2_reality_phasing.gd`)
- 当切换至**现实状态（操作卢卡）**时：
  - `wall2` 柱体及其物理碰撞箱（`CollisionPolygon2D`）会**短暂消失虚化**（默认持续 3.5 秒，伴随半透明淡出效果），为角色穿行下层走廊创造时机窗口。
  - 虚化结束后，`wall2` 自动平滑恢复实体与碰撞判定。
- 当切回**梦境状态（操作雪莉）**时，`wall2` 立即恢复为实体阻挡。

---

### 8. 通关目标
- 卢卡利用护士巡查不同窗帘的位移间隙，逐次在窗帘之间穿梭前进。
- 越过 4 号窗帘后走到最右侧长廊尽头，直通决战场景迎战“维斯佩尔梦疗院院长”Boss。
