# Crownland Boss — 被黑魔法寄生的国王

**Location:** `res://day/levels/crownland/boss/`
**Arena scene:** `crownland_boss_arena.tscn`
**Playable level scene:** `res://day/levels/crownland/boss.tscn`

---

## Overview

Three-phase 2D side-scrolling boss battle. The King of Crownland has been parasitized by dark magic that channels its damage through four black magic pillars. Players must survive barrage attacks, destroy the pillars, and finally deal direct damage to the king.

---

## Phase Flow

```
INTRO ──► PHASE_1 ──► PHASE_1_TRANSITION ──► PHASE_2 ──► PHASE_2_TRANSITION
                                                               │
                                                          PHASE_3 ──► FINAL_PURIFICATION ──► DEFEATED
```

第二阶段的 `phase2_idle` 动画以 12 FPS 播放一次后停在最后一帧；Boss 的
`VisualRoot` 会在该定格画面上持续进行上下浮动。可在 Boss Inspector 调整
`phase2_float_amplitude` 与 `phase2_float_speed`。

| Phase | Enum int | Boss HP | Invulnerable | Goal |
|-------|----------|---------|--------------|------|
| INTRO | 0 | — | true | Loading / cutscene |
| PHASE_1 | 1 | locked (grey bar) | **true** | Survive 4 attack cycles |
| PHASE_1_TRANSITION | 2 | locked | true | Dialogue + stage change |
| PHASE_2 | 3 | locked | **true** | Destroy 4 pillars |
| PHASE_2_TRANSITION | 4 | locked | true | Pillar shatter cinematic |
| PHASE_3 | 5 | 100 HP (configurable) | **false** | Deal damage with color-resistance |
| FINAL_PURIFICATION | 6 | 0 | true | Throw holy water to finish |
| DEFEATED | 7 | 0 | true | Emit `boss_defeated` |

---

## Scripts and Responsibilities

| Script | `class_name` | Responsibility |
|--------|-------------|----------------|
| `crownland_boss_config.gd` | `CrownlandBossConfig` | All balance numbers (Resource) |
| `crownland_projectile_base.gd` | `CrownlandProjectileBase` | Shared lifecycle, off-screen cull, damage |
| `crownland_arrow_projectile.gd` | `CrownlandArrowProjectile` | Fan arrow |
| `crownland_tracking_orb.gd` | `CrownlandTrackingOrb` | Three-size track-lock-dash orb |
| `crownland_sword_projectile.gd` | `CrownlandSwordProjectile` | Horizontal sword + qi wave |
| `crownland_needle_drop.gd` | `CrownlandNeedleDrop` | Vertical needle with warning |
| `crownland_black_pillar_hazard.gd` | `CrownlandBlackPillarHazard` | Stage 1 rising pillar (one-shot) |
| `crownland_explosion_fx.gd` | `CrownlandExplosionFx` | 4-frame explosion visual |
| `crownland_magic_pillar.gd` | `CrownlandMagicPillar` | Stage 2 destructible pillar |
| `crownland_boss.gd` | `CrownlandBoss` | Phase state machine, HP, hurtbox, potion interface |
| `crownland_battle_director.gd` | `CrownlandBattleDirector` | Attack scheduling, cleanup, debug |
| `crownland_boss_arena.gd` | `CrownlandBossArena` | Arena sealing, damage relay, level bridge |
| `crownland_boss_hud.gd` | `CrownlandBossHUD` | Health bar + phase badge + hints |

---

## Attack Table

### Stage 1 Attacks

| ID | Pre-warn | Assets | Damage | Notes |
|----|----------|--------|--------|-------|
| `arrow_fan` | 0.8 s magic circle | `半扇展开箭矢.png` | 9 HP | 7–11 arrows; 2nd wave after cycle 2 |
| `ground_pillar` | 0.9–1.1 s `魔法阵.png` | `黑魔法柱子.png` | 12 HP | 3–5 pillars; tracks then predicts |
| `needle_drop` | 0.7 s top line | `竖向两面针*.png` | 9 HP | Always leaves safe zone ≥80px |
| `magic_sword` | 0.6 s hover | `魔剑右向.png` + `右向剑气.png` | 10+9 HP | qi follows 0.2s later; `flip_h` for left |
| `tracking_orb` | none | `左向弹幕小/中/1.png` | 8/10/12 HP | track→lock→dash only; no permanent tracking |

### Stage 2 Combos

| ID | Description |
|----|-------------|
| `combo_a` | Magic circle → pillar rise + arrow fan |
| `combo_b` | Needle drop forces movement → orbs lock position |
| `combo_c` | Sword from one side + pillar on other |

Between combos: 1.5–2 s pillar vulnerability window (pillars glow, highlighted).

### Stage 3 Attacks

| ID | Assets | Damage |
|----|--------|--------|
| `black_crown_fan` | `半扇展开箭矢.png` | 9 HP × 3 waves |
| `sword_cross` | `魔剑右向.png` | 10 HP × 3 passes with height variation |
| `tracking_orb_p3` | 3 orb textures | 8/10/12 HP, all spawned simultaneously |
| `needle_rain` | `竖向两面针*.png` | 9 HP × 3 waves; wave 3 targets gap player fled to |
| `pillar_combo` | `左向弹幕1.png` + explosion frames | 12 HP track + 15 HP blast |

---

## Color Resistance (Stage 3)

Consecutive hits with the same potion color family apply reduced damage:

| Hit # | Multiplier |
|--------|-----------|
| 1st | 100% |
| 2nd | 80% |
| 3rd | 60% |
| 4th+ | 40% |

Resistance resets after **5 seconds** without a hit of that color, or when switching to a different color (which starts fresh at 100%). Configured via `CrownlandBossConfig.resist_tier[]`.

---

## Pillar System (Stage 2)

Four pillars at X positions: ±480, ±160 (adjustable in scene).

| Potion type | Damage to pillar |
|-------------|-----------------|
| Normal | -1 HP |
| Blue/purification | -2 HP |

Pillar HP = 3. On destruction:
1. Show `res://day/levels/crownland/pillar.png` at 0.10 visual scale, then swap to `破碎的黑魔法柱子.png`
2. Spawn `CrownlandExplosionFx` (4-frame animation)
3. Emit `pillar_destroyed`
4. HUD shows shield status text

Each of the four pillars has an editor-visible `Hurtbox/CollisionShape2D` in
`crownland_boss_arena.tscn`. It uses physics layer 3 (bit value `4`), which is
queried directly by the standard potion projectile; the hitbox is enabled only
during the phase-two vulnerability window.

The red-black encounter health frame keeps both objectives together: its left
side shows `国王 current / max`, while its right side shows aggregate pillar HP
and the number of intact pillars as `黑柱 current / max ×N`.

All Crownland, Alkeon, and Helion boss bars use the scene-authored Alkeon
health-bar layout: top-center 680px frame, title/subtitle/phase header, red
fill with gold ghost bar, and a centered status tip.

The boss `Hurtbox/CollisionShape2D` is editor-visible and uses physics layer 3
(bit value `4`) for potion queries. It remains disabled behind the shield during
phases 1–2, then opens in phase 3 for direct attacks on the King.

When the King's HP reaches zero, the encounter enters final purification: the
Boss visual shakes violently and fades white while the Arena's `EndFlashLayer`
gradually turns the screen white. The standalone follow-up scene is
`res://day/levels/crownland/end.tscn`; scene progression remains intentionally
unwired until the later dialogue sequence is authored.

---

## Final Purification

When Boss HP reaches 0:
- `enter_final_purification()` called
- All projectiles cleared
- Boss hurtbox disabled
- HUD hint: "普通药剂无法彻底终结寄生。"
- **Only holy water** (`potion_id` containing "holy"/"sacred"/"圣水"/"purify"/"pure") completes the kill
- Other potions: show "需要圣水才能彻底终结寄生。"
- On holy water hit: `Engine.time_scale = 0.3` for ~1.5 s, then `enter_defeated()`
- `boss_defeated("crownland_king")` emitted — parent level handles cutscene/door

---

## Integration with Level

The arena emits:
```gdscript
signal boss_started
signal boss_defeated(boss_id: StringName)
```

The level scene should:
1. Instance `crownland_boss_arena.tscn`
2. Connect `boss_defeated` to run exit cutscene / open door / progress `DayRuntime`
3. Call `arena.trigger_boss_battle()` when the player enters the trigger zone

The arena does **not** call `change_scene_to_file()`.

`boss.tscn` is the standalone playable entry point. It instances the arena, uses
the standard daytime Sherry player/potion/camera setup, provides a permanent
floor plus left/right collision barriers, and starts the battle when the player
crosses the `BossTrigger` area. It also owns the level-status UI and relays
boss projectile damage into the normal day-health contract.

The standalone scene also includes the standard Developer Console (`~` or `F1`)
and the standard pause/backpack UI (`B` opens the backpack; `Esc` opens pause).
Every boss attack routed through `apply_player_damage` triggers Sherry's existing
`hit` animation and a short knockback away from the arena centre before applying
the normal day-health damage.

Both `boss.tscn` and `end.tscn` render their background through a negative-layer
`CanvasLayer` and a full-rect `TextureRect` using aspect-cover stretching. This
keeps the artwork filled to the camera's top and bottom edges at every viewport
size, independent of player camera movement.

## Art wiring

`crownland_boss_arena.tscn` includes `AssetLoader`, which automatically loads the attack PNGs from `res://day/levels/crownland/boss/art/` and the three boss-frame directories when the arena is run. It assigns them to the battle director, the four phase-two pillars, explosion effects, and the boss `AnimatedSprite2D`; no Inspector drag-and-drop is required.

Player death:
```gdscript
arena.on_player_died()  # stops director, resets boss, clears projectiles
```

---

## Inspector Parameters to Configure

After opening `crownland_boss_arena.tscn`:

1. **Boss → CrownlandBoss → config** — assigned to `crownland_boss_config.tres`.
2. **AssetLoader** — retain it as a child of the arena; it assigns all present boss art at runtime.
3. **BossArena/ArenaFloor…** — verify collision layer matches project physics layers.
4. **Boss/Hurtbox** — verify `collision_mask = 4` matches the project's potion hitbox layer.
5. **Boss/VisualRoot/AnimatedSprite2D** — frames are populated automatically at runtime from the numbered stage PNGs.

### Recommended collision layers (adjust to project):
| Layer | Usage |
|-------|-------|
| 1 | Player physics body |
| 2 | Player interaction |
| 4 | Potion projectile |

---

## Debug Shortcuts

Only active in `OS.is_debug_build()`:

| Key | Action |
|-----|--------|
| F6 | Jump to Phase 1 |
| F7 | Jump to Phase 2 |
| F8 | Jump to Phase 3 |
| F9 | Set Boss HP to 10% |

---

## TODO (post-integration)

- [x] Configure automatic PNG texture and animation-frame injection
- [ ] Connect `crownland_boss_arena.boss_defeated` in parent level scene
- [ ] Confirm collision layer numbers match project's `project.godot` configuration
- [ ] Add audio cues (currently silent-safe; no errors if audio absent)
- [ ] Run `godot --headless --path . --editor --quit` for parse check
- [ ] Run `godot --headless --path . --script res://tests/run_tests.gd` for regression
- [ ] Playtest all 20 acceptance criteria from design document
