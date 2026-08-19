# Vespervale Dream Grasp Hands (幽眠攫手) Mechanic

## Overview

The **Dream Grasp Hands (幽眠攫手)** system is a core hazard and environmental adversary in the **Vespervale Inner Ward Corridor** (`res://day/levels/Vespervale/inner.tscn`).

The mechanic employs an unfairness-free, 5-state predictive hunting loop powered by 24 hand animation frames (`dream_grasp_00.png` to `dream_grasp_23.png`), bed safe zones with lunar ward auras, escalating threat tiers, dual-character switch baiting, and dynamic multi-floor platform raycasting.

---

## 1. 5-State Machine

```
[ LURK (潜伏) ] ── (outside bed / dream active) ──> [ TRACK (跟踪) ] (1.2~1.8s)
       ▲                                                    │
       │                                                    ▼
       │                                            [ LOCK (锁定) ] (0.45~0.6s)
       │                                                    │
       │ (in bed / reality)                                 ▼
[ RETRACT (回收) ] (0.6~0.8s) <── [ ERUPT (爆发) ] (0.35~0.5s)
```

1. **Lurk (潜伏)**:
   - When the active character is sheltered in a `DreamBedSafeZone` or during Reality Intrusion.
   - Hands remain hidden; tracking shadows dissolve.
2. **Track (跟踪)**:
   - Active character leaves bed sanctuary in Dream State.
   - A purple dream shadow (`TrackingShadow`) follows the player's ground position in real time for **1.2 ～ 1.8 seconds**.
3. **Lock (锁定)**:
   - The shadow **stops moving** and locks in place.
   - Clear audio-visual telegraph:
     - Expanding/contracting purple ground ripple ring.
     - Deep, ominous low bell chime from `DreamAudioSynth.play_lock_bell()`.
   - Lasts **0.45 ～ 0.6 seconds**. Player can react, jump, sprint, or switch characters to evade.
4. **Erupt (爆发)**:
   - 24-frame animation plays at 24 FPS:
     - Frames 0–7: Ground hint (HitBox disabled).
     - Frames 8–13: Lock-in (HitBox disabled).
     - Frames 14–17: Hands surge upward (HitBox y-position ascends).
     - Frames 18–22: Full grasp (HitBox active, delivers single-tick damage).
     - Frame 23: Clench pause.
   - Emits purple dream motes and dream mist.
5. **Retract (回收)**:
   - Lasts **0.6 ～ 0.8 seconds**. Hands fade and dissolve into purple mist, returning to Track or Lurk.

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

---

## 4. Multi-Layer & Dual-Character Integration

1. **Upper & Lower Platforms**:
   - `DreamGraspManager` raycasts downward (`RayCast2D`) to detect whether the character is on the lower floor (y ≈ 600) or upper observation corridor (y ≈ 320), spawning hands flush with the appropriate surface.
2. **Character Switching (C Key)**:
   - Tracks the active character (`InnerPartyController.active_body()`).
   - If switched during **Track**: tracking smoothly moves to the new character.
   - If switched during **Lock**: hands remain locked at the original position, enabling high-skill bait-and-switch evasions.
3. **Dream / Reality Shifts**:
   - Only active during **Dream State**.
   - During Reality Intrusion, all active hands and tracking shadows immediately dissipate.
