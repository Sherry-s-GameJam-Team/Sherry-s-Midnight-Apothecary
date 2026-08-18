class_name AlkeonBossHealthBarUI
extends CanvasLayer

## Full HUD boss health bar with phase indicators, catchup ghost bar, and status labels.

@onready var boss_title_label: Label = %BossTitle
@onready var phase_badge_label: Label = %PhaseBadge
@onready var hp_bar_ghost: ProgressBar = %HpBarGhost
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var status_tip_label: Label = %StatusTip
@onready var root_container: Control = %RootContainer

var _boss: AlkeonBoss
var _ghost_tween: Tween
var _fade_tween: Tween


func _ready() -> void:
	layer = 15
	if root_container != null:
		root_container.modulate.a = 1.0


func setup_boss(boss_node: AlkeonBoss) -> void:
	_boss = boss_node
	if _boss == null:
		return

	if not _boss.health_changed.is_connected(_on_health_changed):
		_boss.health_changed.connect(_on_health_changed)
	if not _boss.phase_changed.is_connected(_on_phase_changed):
		_boss.phase_changed.connect(_on_phase_changed)
	if not _boss.head_bowed.is_connected(_on_head_bowed):
		_boss.head_bowed.connect(_on_head_bowed)
	if not _boss.head_raised.is_connected(_on_head_raised):
		_boss.head_raised.connect(_on_head_raised)
	if not _boss.boss_purified.is_connected(_on_boss_purified):
		_boss.boss_purified.connect(_on_boss_purified)

	_update_display(_boss.current_hp, _boss.max_hp)
	_update_phase_badge(_boss.current_phase)


func _on_health_changed(curr: float, max_v: float) -> void:
	_update_display(curr, max_v)


func _on_phase_changed(phase: int) -> void:
	_update_phase_badge(phase)


func _on_head_bowed(_duration: float) -> void:
	if status_tip_label != null:
		status_tip_label.text = "【猎王低头破绽·攻击弱点！】"
		status_tip_label.modulate = Color(1.0, 0.9, 0.3, 1.0)


func _on_head_raised() -> void:
	if status_tip_label != null and _boss != null and _boss.current_phase != AlkeonBoss.Phase.PURIFIED_RESTORED:
		status_tip_label.text = "【血叶屏障保护中·观察风铃避开血叶潮】"
		status_tip_label.modulate = Color(0.9, 0.7, 0.7, 0.8)


func _on_boss_purified() -> void:
	if phase_badge_label != null:
		phase_badge_label.text = "【净胜解脱】"
		phase_badge_label.modulate = Color(0.3, 1.0, 0.6, 1.0)
	if status_tip_label != null:
		status_tip_label.text = "【血叶已尽除·神鹿复苏】"
		status_tip_label.modulate = Color(0.4, 1.0, 0.7, 1.0)
	if hp_label != null:
		hp_label.text = "已净化 100%"

	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(root_container, "modulate:a", 0.0, 1.5)


func _update_display(curr: float, max_v: float) -> void:
	var ratio := clampf(curr / maxf(max_v, 1.0), 0.0, 1.0)
	var pct := roundi(ratio * 100.0)

	if hp_bar != null:
		hp_bar.value = pct

	if hp_label != null:
		hp_label.text = "%d / %d (%d%%)" % [roundi(curr), roundi(max_v), pct]

	# Smooth ghost bar animation
	if hp_bar_ghost != null:
		if _ghost_tween != null and _ghost_tween.is_valid():
			_ghost_tween.kill()
		_ghost_tween = create_tween()
		_ghost_tween.tween_interval(0.35)
		_ghost_tween.tween_property(hp_bar_ghost, "value", float(pct), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_phase_badge(phase: int) -> void:
	if phase_badge_label == null:
		return

	match phase:
		AlkeonBoss.Phase.PHASE1_RED_HORN:
			phase_badge_label.text = "【阶段一 · 赤角破阵】"
			phase_badge_label.modulate = Color(1.0, 0.6, 0.3, 1.0)
		AlkeonBoss.Phase.TRANSITION_1_TO_2, AlkeonBoss.Phase.PHASE2_WILD_HUNT:
			phase_badge_label.text = "【阶段二 · 狂猎再临】"
			phase_badge_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
		AlkeonBoss.Phase.TRANSITION_2_TO_3, AlkeonBoss.Phase.PHASE3_GREAT_HUNT, AlkeonBoss.Phase.FINAL_PURIFICATION:
			phase_badge_label.text = "【阶段三 · 万叶大猎】"
			phase_badge_label.modulate = Color(1.0, 0.2, 0.4, 1.0)
		AlkeonBoss.Phase.PURIFIED_RESTORED:
			phase_badge_label.text = "【已净化】"
			phase_badge_label.modulate = Color(0.3, 1.0, 0.6, 1.0)
