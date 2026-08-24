class_name VesperBossHUD
extends CanvasLayer

## Boss HUD for Vespervale Director.
## Displays enlarged HP bar, ghost delayed damage bar, numerical health text, boss title, and status indicator.

@onready var boss_name_label: Label = $Root/BossNameLabel
@onready var status_label: Label = $Root/StatusLabel
@onready var health_bar: ProgressBar = $Root/HealthBar
@onready var ghost_bar: ProgressBar = $Root/HealthBar/GhostBar
@onready var health_label: Label = $Root/HealthBar/HealthLabel


func _ready() -> void:
	if health_bar != null:
		health_bar.value = 100.0
	if ghost_bar != null:
		ghost_bar.value = 100.0
	if status_label != null:
		status_label.text = "深层治疗阶段"


func setup(boss: VesperDirectorBoss) -> void:
	if boss == null:
		return
	boss.health_changed.connect(_on_health_changed)
	boss.phase_changed.connect(_on_phase_changed)
	boss.dream_tide_state_changed.connect(_on_tide_state_changed)
	boss.boss_defeated.connect(_on_boss_defeated)
	_on_health_changed(boss.current_hp, boss.max_hp)


func _on_health_changed(current_hp: float, max_hp: float) -> void:
	var safe_max := maxf(1.0, max_hp)
	var percent := (current_hp / safe_max) * 100.0
	if health_bar != null:
		health_bar.value = percent

	if ghost_bar != null:
		var tw := create_tween()
		tw.tween_interval(0.2)
		tw.tween_property(ghost_bar, "value", percent, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if health_label != null:
		health_label.text = "HP %d / %d" % [roundi(current_hp), roundi(max_hp)]


func _on_phase_changed(new_phase: int) -> void:
	if status_label == null:
		return
	match new_phase:
		2:
			status_label.text = "阶段 II：深层梦境折叠"
			status_label.modulate = Color(1.0, 0.6, 1.2, 1.0)
		3:
			status_label.text = "阶段 III：错误治疗终末爆发"
			status_label.modulate = Color(1.3, 0.3, 0.6, 1.0)


func _on_tide_state_changed(is_tide: bool) -> void:
	if status_label == null:
		return
	if is_tide:
		status_label.text = "✦ 梦潮涌动中（月盾防护） ✦"
		status_label.modulate = Color(0.85, 0.5, 1.4, 1.0)
	else:
		status_label.text = "✧ 清醒窗口（脆弱增伤） ✧"
		status_label.modulate = Color(0.4, 1.2, 0.8, 1.0)


func _on_boss_defeated() -> void:
	if status_label != null:
		status_label.text = "✓ 梦境恶兆已被净化"
		status_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property($Root, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
