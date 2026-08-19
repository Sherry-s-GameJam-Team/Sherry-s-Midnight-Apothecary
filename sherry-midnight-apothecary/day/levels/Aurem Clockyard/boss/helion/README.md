# 十二刻守望者·赫利昂 / Helion, Warden of the Twelve

奥雷姆钟庭塔顶守望者（Floor 6 Pinnacle Boss）完整战斗与动画规范文档。

---

## 一、Boss 三阶段规则与 HP 阈值

| 阶段 | HP 阈值 | 主题 | 核心机制 | 核心动画 |
|---|---|---|---|---|
| **Phase 1** | 100% → 70% | **现在** | **分针横扫 (Minute Sweep)** + 刻度坠落 + 逆行钟鸟骚扰 | `idle_intro`, `minute_sweep` |
| **Phase 2** | 70% → 35% | **过去** | **二秒逆刻 (Two-Second Rewind)** + 攻击后核心暴露易伤 | `rewind_cast`, `minute_sweep` |
| **Phase 3** | 35% → 0% (HP=1) | **未来 / 零时失序** | **十二刻地板交替缩回 + 时间环冲击波** | `phase3_transform` (一次性) → `time_ring_burst` → `phase3_hold` |
| **终结序列** | HP ≤ 15% | **十二声钟鸣** | 十二刻依次点亮封锁，安全区迁移，终局大招 | `run_final_twelve_tolls` → `time_ring_burst` |
| **最终净化** | HP = 1 | **守时圣像复苏** | 进入 `PURIFICATION_REQUIRED`，需使用净化药水命中核心 | `recovery` → `purified_idle` |

> **注意**：普通伤害无法击杀赫利昂（最低保留 1 点生命）。净化成功后赫利昂不爆炸死亡，而是播放 `recovery` 并永久保持 `purified_idle` 恢复为守时圣像。

---

## 二、动画与 Local Frame Cue 规范

> **严禁在战斗脚本中使用 0–179 全局源帧编号！**
> 正式 Boss 脚本仅通过 `animation_name + local_frame` 与 `HelionAnimationCues` 资源驱动。

### Cue 映射配置 (`helion_animation_cues.tres`)

| Animation | Local Frame | 源帧对应 | Cue ID | 功能说明 |
|---|---|---|---|---|
| `minute_sweep` | 3 | F009 | `sweep_warning` | 出现橙色钟针预警线 |
| `minute_sweep` | 4 | F010 | `sweep_hitbox_on` | 激活横扫伤害碰撞体 |
| `minute_sweep` | 14 | F020 | `sweep_hitbox_off` | 关闭伤害判定（单次攻击最多命中1次） |
| `minute_sweep` | 16 | F022 | `core_expose` | 核心暴露，进入破绽易伤窗口 |
| `minute_sweep` | 20 | F026 | `core_close` | 关闭核心，攻击动作完成 |
| `rewind_cast` | 9 | F036 | `rewind_fx_begin` | 出现时间扭曲波纹 |
| `rewind_cast` | 12 | F039 | `rewind_target_show` | 显示玩家 2.0 秒前的半透明蓝色残影 |
| `rewind_cast` | 28 | F055 | `rewind_commit` | 执行 2 秒回拨（瞬间移动玩家 + 清零速度 + 0.2s无敌） |
| `rewind_cast` | 29 | F056 | `core_expose` | 核心暴露，受击倍率提升为 1.0 |
| `rewind_cast` | 35 | F062 | `core_close` | 核心关闭 |
| `rewind_cast` | 38 | F065 | `rewind_end` | 逆刻技能结束 |
| `phase3_transform` | 7 | F073 | `clock_seals_begin` | 十二刻钟印点亮 |
| `phase3_transform` | 20 | F086 | `phase3_arena_enable` | 启用十二扇区地板模式 |
| `phase3_transform` | 24 | F090 | `phase3_ready` | 变身完成，进入 Phase 3 循环 |
| `time_ring_burst` | 2 | F092 | `ring_warning` | 时间环前摇预警 |
| `time_ring_burst` | 4 | F094 | `ring_spawn` | 生成环形冲击波（外扩半径） |
| `time_ring_burst` | 10 | F100 | `ring_peak` | 冲击波达到峰值，屏幕轻微震动 + 钟鸣 |
| `time_ring_burst` | 11 | F101 | `ring_damage_end` | 关闭冲击波伤害判定 |
| `time_ring_burst` | 15 | F105 | `ring_finished` | 大招结束，开放短核心破绽 |

---

## 三、二秒逆刻机制 (`HelionRewindRecorder`)

1. **记录机制**：挂载于 Arena 根节点，在 `_physics_process` 中持续将玩家的位置与速度存入 2.5 秒环形缓冲区。
2. **回拨执行**：`rewind_commit` 触发时，查询 `now - 2.0s` 时的玩家快照。
3. **安全边界检查**：
   - 检查目标位置是否在 Arena 内且不在墙体内；
   - 若目标位置非法，以 0.1s 步长向前搜索（2.0s → 1.9s → 1.8s ...）；
   - 若仍无合法位置，使用 `LastSafeMarker` 标记点位置；
   - 杜绝回拨穿墙或即死情况。
4. **属性守恒**：仅回退玩家**物理坐标**与**速度**，不回滚 HP、药水库存、Buff 或世界状态。

---

## 四、十二扇区地板系统 (`HelionClockFloorController`)

- 塔顶地板拆分为 12 块独立扇区（`Sector01` ~ `Sector12`）。
- 每块具备 `NORMAL`（正常）、`WARNING`（预警闪烁 1.2s）、`RETRACTED`（下移缩回 1.4s + 禁用碰撞）、`RESTORING`（复位恢复）四种状态。
- **安全保证**：算法始终保证至少保留 **3 块连续可站立** 扇区，杜绝无解地形杀。
- 战斗胜利后调用 `restore_all()` 恢复全部地板。

---

## 五、药水与伤害接口 (`receive_potion_hit`)

- Boss 接受标准药水击中载荷：
  ```gdscript
  func receive_potion_hit(hit: Dictionary) -> void
  ```
- **倍率配置** (`HelionBossConfig.tres`)：
  - 正常状态受击倍率：`0.35`
  - 核心暴露受击倍率：`1.00`
  - 爆炸药水额外倍率：`1.35`
  - 净化药水最终处决：在 `PURIFICATION_REQUIRED` 阶段或 `HP <= 1` 时直接触发胜利。
- **防软锁保障**：若玩家缺少净化药水，Arena 左侧在濒死阶段激活应急补给点 (`PurifySupplyPoint`)。

---

## 六、战斗完成与后续流程

1. Boss 接收净化药水后发出 `boss_defeated(&"helion")` 信号。
2. 关卡 `inside.gd` 接收信号后：
   - 记录教程/主线成就：`tutorial_flags["aurem_helion_cleared"] = true`；
   - 解除钟塔灾难：`tutorial_flags["aurem_clockyard_tower_synchronized"] = true`；
   - 开放塔顶返回外庭界门：`World/Top/ExitPortal.visible = true`。
3. Boss 不删除自身，保持 `purified_idle` 作为正常守时圣像留驻塔顶。

---

## 七、替换美术资产流程

若后续需要更新赫利昂动画或替换素材：
1. 将新帧放入 `frames/` 并更新 `godot/helion_spriteframes.tres`；
2. 在 `battle/helion_animation_cues.tres` 中调整各动画片段的 `local_frame` 触发点；
3. **无需修改任何 GDScript 业务代码**。