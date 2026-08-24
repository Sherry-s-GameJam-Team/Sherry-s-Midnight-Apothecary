# Vespervale Dream Grasp Hands (幽邃敛手) Mechanic

## Overview

The **Dream Grasp Hands (幽邃敛手)** system is a core hazard and environmental adversary in the **Vespervale Inner Ward Corridor** (`res://day/levels/Vespervale/inner.tscn`).

The mechanic employs an unfairness-free, 5-state predictive hunting loop powered by 24 hand animation frames (`dream_grasp_00.png` to `dream_grasp_23.png`), bed safe zones with lunar ward auras, **sofa safe zone cancellation**, **wall1~wall2 corridor activity bounding**, escalating threat tiers, dual-character switch baiting, **1st floor Y-axis locking**, **eerie breathing visual presence**, and **smooth lerp gliding movement**.

---

## 1. 5-State Machine & Movement

```
[ LURK (潜伏) ] ── (outside bed & sofa / dream active / within wall1~wall2) ──> [ TRACK (追踪) ] (1.2~1.8s)
       ▲                                                                            │
       │                                                                            ▼
       │                                                                    [ LOCK (锁定) ] (0.45~0.6s)
       │                                                                            │
       │(in bed / in sofa / out of bounds / reality)                                ▼
[ RETRACT (回收) ] (0.6~0.8s) <────────────────────────────────────────────── [ ERUPT (爆发) ] (0.35~0.5s)
```

1. **Activity Bounding (wall1 与 wall2 之间活动限制)**:
   - 紫手的追踪阴影与爆发爪群被严格限制在 `wall1` 与 `wall2` 之间的走廊区域（`min_x_bound ~ max_x_bound`）。
   - 当玩家处于 `wall1` 左侧或 `wall2` 右侧的边界外区域时，紫手立即取消追踪（若在 TRACK/LOCK 状态则回退到 LURK 状态），并重置危险累积计时。
2. **Sofa1 庇护所 (靠近沙发取消跟随)**:
   - 当玩家进入 `Sofa1`（沙发）的判定范围（`dx <= 140px, dy <= 120px`）时，系统视同进入庇护区。
   - 紫手立即取消跟随与锁定，回到 `LURK` 低透明度待机状态，并重置猎杀计时与危险阶层。
3. **Floor Locking (第一层地板 Y 轴锁定)**:
   - 爪群与阴影的 Y 坐标严格锁定在第一层地面（`ground_floor_y = 600.0`）。
   - 无论玩家跳跃还是在上方观察走廊，紫手均贴地游弋。
4. **Smooth Gliding Movement (平滑跟随)**:
   - 采用平滑插值追踪（`smooth_follow_speed = 3.6`），并在左右墙体边界内 Clamp。
5. **Breathing Visual Presence (呼吸式显现)**:
   - Lurk 模式下呈低透明度淡紫阴影，Track 模式下透明度上升并扩大，Lock 模式下定格并发出铃鸣警兆。
6. **Lock (锁定)** & **Erupt (爆发)** & **Retract (回收)**:
   - 锁定后定点播放警示环，随后播放 24 帧爆发动画并在判定帧产生单次伤害，回收后溶解消失。

---

## 2. Safe Zones (庇护区机制)

- **Hospital Beds (`DreamBedSafeZone`)**: 带有月辉护盾特效的病床庇护所。
- **Sofa (`Sofa1`)**: 位于走廊中的沙发休憩点，玩家靠近时自动屏蔽紫手跟随与锁定。
- **Boundary Immunity**: 离开 `wall1`~`wall2` 区域同样享有免疫脱战效果。