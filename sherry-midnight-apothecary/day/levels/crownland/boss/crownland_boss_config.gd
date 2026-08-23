class_name CrownlandBossConfig
extends Resource
## 阿里特王畿 Boss 数据配置 / Crownland King — balance configuration.
## All numeric parameters live here. Adjust in the Inspector to rebalance
## without touching any GDScript logic.

# ─── Health ───
@export_group("Health")
@export var max_hp: int = 100
## HP displayed during Stage 1 / 2 (locked, greyed out). Actual damage begins Stage 3.
@export var phase3_start_hp: int = 100

# ─── Phase Thresholds ───
@export_group("Phase Thresholds")
## Number of complete attack cycles needed before Phase 1 → Phase 2 transition.
@export var phase1_required_cycles: int = 4
## All 4 pillars must be destroyed to enter Phase 3 (pillar count enforced in code).

# ─── Attack Timing ───
@export_group("Attack Timing")
@export var attack_interval_min: float = 1.8
@export var attack_interval_max: float = 2.8
## Recovery window between attacks (seconds).
@export var recovery_window_min: float = 0.8
@export var recovery_window_max: float = 1.2
## Pillar vulnerability window after Boss finishes an attack cycle (Stage 2).
@export var pillar_window_duration: float = 1.8

# ─── Attack Damage ───
@export_group("Damage — Boss Attacks")
@export var arrow_damage: int = 9
@export var pillar_hazard_damage: int = 12
@export var needle_damage: int = 9
@export var sword_damage: int = 10
@export var sword_qi_damage: int = 9
@export var small_orb_damage: int = 8
@export var medium_orb_damage: int = 10
@export var large_orb_damage: int = 12
@export var explosion_damage: int = 15

# ─── Attack Timing / Warning ───
@export_group("Timing — Pre-warn Durations")
@export var arrow_warn_time: float = 0.8
@export var pillar_warn_time: float = 1.0
@export var needle_warn_time: float = 0.7
@export var sword_hover_time: float = 0.6
@export var orb_tracking_small: float = 0.0   # no tracking
@export var orb_tracking_medium: float = 0.8
@export var orb_tracking_large: float = 1.2
@export var orb_dash_delay: float = 0.15      # stop-then-dash gap
@export var explosion_blast_radius: float = 90.0

# ─── Stage 1 Arrow Fan ───
@export_group("Attack A — Arrow Fan")
@export var arrow_count_min: int = 7
@export var arrow_count_max: int = 11
@export var arrow_speed: float = 280.0
@export var arrow_second_wave_rotation: float = 12.0  # degrees

# ─── Stage 1 Ground Pillar ───
@export_group("Attack B — Ground Pillar")
@export var pillar_count_min: int = 3
@export var pillar_count_max: int = 5
@export var pillar_rise_time: float = 0.18
@export var pillar_linger_time: float = 0.4

# ─── Stage 1 Needle ───
@export_group("Attack C — Needle Drop")
@export var needle_count_min: int = 3
@export var needle_count_max: int = 5
@export var needle_speed: float = 900.0
@export var needle_linger_time: float = 0.25

# ─── Stage 1 Sword ───
@export_group("Attack D — Magic Sword")
@export var sword_speed: float = 700.0
@export var sword_qi_delay: float = 0.20
@export var sword_qi_speed: float = 420.0

# ─── Stage 1 Orbs ───
@export_group("Attack E — Tracking Orbs")
@export var small_orb_speed: float = 380.0
@export var medium_orb_speed_track: float = 160.0
@export var medium_orb_speed_dash: float = 340.0
@export var large_orb_speed_track: float = 90.0
@export var large_orb_speed_dash: float = 260.0

# ─── Stage 2 Pillars ───
@export_group("Stage 2 Pillars")
@export var pillar_hp: int = 3
## Blue/purification potions deal 2 hits instead of 1.
@export var pillar_purify_bonus: int = 1  # added to base 1

# ─── Stage 3 Color Resistance ───
@export_group("Stage 3 Color Resistance")
@export var resist_tier: Array[float] = [1.0, 0.80, 0.60, 0.40]
## Seconds of gap needed to reset color resistance.
@export var resist_reset_time: float = 5.0

# ─── Hit Feedback ───
@export_group("Hit Feedback")
@export var hit_recoil_min_px: float = 6.0
@export var hit_recoil_max_px: float = 12.0
@export var hit_flash_duration: float = 0.08
@export var hit_recoil_return_time: float = 0.06
@export var shield_ripple_duration: float = 0.4

# ─── Purification Final ───
@export_group("Final Purification")
## potion_id substrings that count as holy water.
@export var holy_water_tags: Array[String] = ["holy", "sacred", "圣水", "purify", "pure"]
@export var bullet_time_scale: float = 0.3
@export var bullet_time_duration: float = 1.5

