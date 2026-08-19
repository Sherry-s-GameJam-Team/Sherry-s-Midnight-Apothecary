# Vespervale Dream Grasp Hands (幽眠攫手) Mechanic

## Overview

The **Dream Grasp Hands (幽眠攫手)** system is a core hazard and environmental adversary in the **Vespervale Inner Ward Corridor** (`res://day/levels/Vespervale/inner.tscn`).

The mechanic employs an unfairness-free, 5-state predictive hunting loop powered by 24 hand animation frames (`dream_grasp_00.png` to `dream_grasp_23.png`), bed safe zones with lunar ward auras, escalating threat tiers, dual-character switch baiting, **1st floor Y-axis locking**, **eerie breathing visual presence**, and **smooth lerp gliding movement**.

---

## 1. 5-State Machine & Movement

```
[ LURK (潜伏) ] ── (outside bed / dream active) ──> [ TRACK (跟踪) ] (1.2~1.8s)
       ▲                                                    │
       │                                                    ▼
       │                                            [ LOCK (锁定) ] (0.45~0.6s)
       │                                                    │
       │ (in bed / reality)                                 ▼
[ RETRACT (回收) ] (0.6~0.8s) <── [ ERUPT (爆发) ] (0.35~0.5s)
```

1. **Floor Locking (第一层地板 Y 轴锁定)**:
   - Enemy Y position is permanently locked to the 1st floor ground surface (`ground_floor_y = 600.0`).
   - Even when players jump or Luca moves along the upper corridor, the shadow and hands glide along and erupt strictly from the main lower floorboards.
2. **Smooth Gliding Movement (平滑移动)**:
   - Rather than instantly snapping to the player's X coordinate, the shadow smoothly interpolates towards the target with smooth lerp tracking (`smooth_follow_speed = 3.6`).
3. **Breathing Visual Presence (呼吸式经常显示)**:
   - A multi-layered visual pool (outer shadow, glowing inner core, translucent finger hints) continuously breathes with a smooth sinusoidal rhythm (`sin(phase)`).
   - In **Lurk**, it breathes gently at low opacity (`alpha: 0.20 ~ 0.45`), keeping the ominous entity present.
   - In **Track**, the breathing intensifies (`alpha: 0.55 ~ 0.90`, scaling dynamically).
4. **Lock (锁定)**:
   - The shadow **freezes completely** at its current ground position.
   - Distinct audio-visual telegraph:
     - Expanding/contracting purple ground ripple ring.
     - Deep, ominous low bell chime from `DreamAudioSynth.play_lock_bell()`.
   - Lasts **0.45 ～ 0.6 seconds**, granting the player a clear window to dodge.
5. **Erupt (爆发)**:
   - 24-frame animation plays at 24 FPS:
     - Frames 0–13: Ground telegraph (HitBox disabled).
     - Frames 14–17: Hands surge upward (HitBox y-position ascends).
     - Frames 18–22: Full grasp (HitBox active, delivers single-tick damage).
     - Frame 23: Clench pause.
6. **Retract (回收)**:
   - Lasts **0.6 ～ 0.8 seconds**. Hands dissolve into purple mist, smoothly returning to Track or Lurk.

---

## 2. Bed Safe Zone (`DreamBedSafeZone`)

- Placed around each dream hospital bed (`DreamThornBed`).
- Extends 40-50px wider than the bed and 1.5 character heights upwards.
- Emits a soft lunar-white/light-purple elliptical ward aura (`SafeZoneAura`).
- **Rules**:
  - Entering a safe zone immediately cancels ongoing tracking and resets the hunting tier.
  - Attacks already in the "Locked" state outside the bed continue their burst but cannot harm players inside the bed sanctuary.
  - Beds provide permanent shelter, but progressing through the level requires venturing out to activate switches, trigger dream bridges, and shatter light targets.

---

## 3. Threat Tiers (Hunting Escalation)

Continuously staying outside any bed safe zone escalates the hunting tier:

| Tier | Continuous Time Away from Bed | Mechanics |
| :--- | :--- | :--- |
| **Tier 1 (一级梦猎)** | 0 ～ 8 秒 | Single hand grasp point at locked position. |
| **Tier 2 (二级梦猎)** | 8 ～ 16 秒 | Triple cluster: Center locked point + Left (-75px) + Right (+75px) secondary grasps. |
| **Tier 3 (三级梦猎)** | > 16 秒 | Double-wave assault: First wave erupts, followed 0.55s later by a second rapid lock/burst at player's new position. |

*Entering any bed safe zone instantly resets the timer to 0 and tier to 1.*
