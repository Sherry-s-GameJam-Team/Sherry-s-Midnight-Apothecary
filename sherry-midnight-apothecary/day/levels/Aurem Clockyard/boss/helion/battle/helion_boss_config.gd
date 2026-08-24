class_name HelionBossConfig
extends Resource
## Data-driven boss configuration. Edit in the Inspector to rebalance
## without touching any GDScript logic.

# ─── Health ───
@export_group("Health")
@export var max_hp: int = 2000

# ─── Phase Thresholds (fraction of max_hp) ───
@export_group("Phase Thresholds")
@export_range(0.0, 1.0) var phase2_threshold: float = 0.70
@export_range(0.0, 1.0) var phase3_threshold: float = 0.35
@export_range(0.0, 1.0) var final_sequence_threshold: float = 0.15

# ─── Attack Timing ───
@export_group("Attack Timing")
@export var attack_interval_min: float = 2.5
@export var attack_interval_max: float = 4.5

# ─── Damage Values ───
@export_group("Damage")
@export var sweep_damage: int = 15
@export var clock_mark_damage: int = 12
@export var ring_damage: int = 20
@export var clock_projectile_damage: int = 8

# ─── Rewind ───
@export_group("Rewind")
@export var rewind_seconds: float = 2.0
@export var rewind_record_buffer: float = 2.5
@export var rewind_safety_time: float = 0.20

# ─── Damage Multipliers (applied when Boss receives hits) ───
@export_group("Resistance / Vulnerability")
@export var normal_damage_multiplier: float = 0.35
@export var exposed_damage_multiplier: float = 1.0
@export var explosive_multiplier: float = 1.35
@export var purify_multiplier: float = 1.0

# ─── Sector Floor ───
@export_group("Sector Floor")
@export var sector_warning_time: float = 1.2
@export var sector_retract_time: float = 1.4
@export var sector_restore_time: float = 0.6
@export var min_safe_sectors: int = 3

# ─── Hit Feedback ───
@export_group("Hit Feedback")
@export var hit_feedback_cooldown: float = 0.1
@export var hit_recoil_min_px: float = 8.0
@export var hit_recoil_max_px: float = 14.0
@export var hit_flash_duration: float = 0.08
@export var hit_recoil_return_time: float = 0.06

# ─── Purification ───
@export_group("Purification")
@export var final_purify_required: bool = false

# ─── Clock Birds ───
@export_group("Clock Birds")
@export var max_clock_birds: int = 2
@export var clock_bird_spawn_interval: float = 8.0

# ─── Final Twelve Tolls ───
@export_group("Final Sequence")
@export var final_toll_duration: float = 9.0
@export var toll_interval: float = 0.75
