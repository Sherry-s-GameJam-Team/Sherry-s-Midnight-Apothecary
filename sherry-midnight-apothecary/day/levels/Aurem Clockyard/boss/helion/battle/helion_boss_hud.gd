class_name HelionBossHUD
extends CanvasLayer
## Boss health bar UI positioned at the top of the screen (referencing AlkeonBossHealthBar).
## Only displayed after the trigger gear is activated.
## Smooth HP bar, ghost damage bar, phase badges and status tips.

@export var boss_name: String = "十二刻守望者 · 赫利昂"
@export var boss_subtitle: String = "奥雷姆中央守时圣像"

var _boss: Node2D = null
var _ghost_tween: Tween = null
var _is_visible: bool = false

@onready var root_container: Control = get_node_or_null("%RootContainer")
@onready var boss_title_label: Label = get_node_or_null("%BossTitle")
@onready var subtitle_label: Label = get_node_or_null("%Subtitle")
@onready var phase_badge_label: Label = get_node_or_null("%PhaseBadge")
@onready var bar_bg: Panel = get_node_or_null("%BarBg")
@onready var hp_bar_ghost: ProgressBar = get_node_or_null("%HpBarGhost")
@onready var hp_bar: ProgressBar = get_node_or_null("%HpBar")
@onready var hp_label: Label = get_node_or_null("%HpLabel")
@onready var status_tip_label: Label = get_node_or_null("%StatusTip")

# Colors for phase transitions
const COLOR_PHASE_1 := Color(0.85, 0.45, 0.15, 1.0)   # Copper / Bronze
const COLOR_PHASE_2 := Color(0.25, 0.6, 0.95, 1.0)    # Blue
const COLOR_PHASE_3 := Color(1.0, 0.85, 0.25, 1.0)    # Gold
const COLOR_PURIFIED := Color(0.3, 1.0, 0.6, 1.0)     # Emerald


func _ready() -> void:
	layer = 20
	if root_container != null:
		root_container.modulate.a = 0.0
		root_container.visible = false


func connect_boss(boss: Node2D) -> void:
	_boss = boss
	if _boss == null:
		return

	if _boss.has_signal("health_changed") and not _boss.health_changed.is_connected(_on_health_changed):
		_boss.health_changed.connect(_on_health_changed)
	if _boss.has_signal("phase_changed") and not _boss.phase_changed.is_connected(_on_phase_changed):
		_boss.phase_changed.connect(_on_phase_changed)
	if _boss.has_signal("boss_defeated") and not _boss.boss_defeated.is_connected(_on_boss_defeated):
		_boss.boss_defeated.connect(_on_boss_defeated)

	var max_hp: int = 2000
	var curr_hp: int = 2000
	if _boss.get("config") != null:
		max_hp = _boss.get("config").get("max_hp")
	if _boss.get("current_hp") != null:
		curr_hp = int(_boss.get("current_hp"))

	_update_display(float(curr_hp), float(max_hp))
	_update_phase_badge(int(_boss.get("current_phase") if _boss.get("current_phase") != null else 1))


func show_hud() -> void:
	if _is_visible:
		return
	_is_visible = true

	if root_container != null:
		root_container.visible = true
		var tween := create_tween()
		if tween != null:
			tween.tween_property(root_container, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func hide_hud(delay: float = 0.0, fade_duration: float = 1.5) -> void:
	_is_visible = false
	if root_container != null:
		var tween := create_tween()
		if tween != null:
			if delay > 0.0:
				tween.tween_interval(delay)
			tween.tween_property(root_container, "modulate:a", 0.0, fade_duration)
			tween.finished.connect(func() -> void:
				if root_container != null:
					root_container.visible = false
			)


func _on_health_changed(curr: int, max_v: int) -> void:
	if not _is_visible:
		show_hud()
	_update_display(float(curr), float(max_v))


func _on_phase_changed(phase: int) -> void:
	if not _is_visible:
		show_hud()
	_update_phase_badge(phase)


func _on_boss_defeated(_boss_id: StringName) -> void:
	if phase_badge_label != null:
		phase_badge_label.text = "【已净化 · 守时圣像】"
		phase_badge_label.modulate = COLOR_PURIFIED
	if status_tip_label != null:
		status_tip_label.text = "【时律平息 · 守时圣像已复苏】"
		status_tip_label.modulate = COLOR_PURIFIED
	if hp_label != null:
		hp_label.text = "已净化 100%"
	if hp_bar != null:
		_set_bar_color(COLOR_PURIFIED)

	hide_hud(3.5, 1.5)


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
		if _ghost_tween != null:
			_ghost_tween.tween_interval(0.3)
			_ghost_tween.tween_property(hp_bar_ghost, "value", float(pct), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_phase_badge(phase: int) -> void:
	if phase_badge_label == null:
		return

	# HelionBoss.Phase: 0: INTRO, 1: PHASE_1, 2: PHASE_2, 3: PHASE_3_TRANSITION, 4: PHASE_3, 5: PURIFICATION_REQUIRED, 6: DEFEATED
	match phase:
		0, 1:
			phase_badge_label.text = "【阶段一 · 分针横扫】"
			phase_badge_label.modulate = COLOR_PHASE_1
			if status_tip_label != null:
				status_tip_label.text = "【守时装甲保护中 · 留意分针横扫预警】"
				status_tip_label.modulate = Color(0.9, 0.75, 0.65, 0.85)
			_set_bar_color(COLOR_PHASE_1)
		2:
			phase_badge_label.text = "【阶段二 · 逆刻回拨】"
			phase_badge_label.modulate = COLOR_PHASE_2
			if status_tip_label != null:
				status_tip_label.text = "【二秒逆刻运转中 · 留意时间残影位置】"
				status_tip_label.modulate = Color(0.7, 0.85, 1.0, 0.85)
			_set_bar_color(COLOR_PHASE_2)
		3, 4:
			phase_badge_label.text = "【阶段三 · 零时失序】"
			phase_badge_label.modulate = COLOR_PHASE_3
			if status_tip_label != null:
				status_tip_label.text = "【十二刻地板交替失序 · 起跳跃过时间环】"
				status_tip_label.modulate = Color(1.0, 0.9, 0.6, 0.9)
			_set_bar_color(COLOR_PHASE_3)
		5:
			phase_badge_label.text = "【核心破防 · 需投掷净化药水】"
			phase_badge_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
			if status_tip_label != null:
				status_tip_label.text = "【圣像过载濒危 · 投掷净化药水完成复苏！】"
				status_tip_label.modulate = Color(1.0, 0.4, 0.4, 1.0)
		6:
			phase_badge_label.text = "【已净化 · 守时圣像】"
			phase_badge_label.modulate = COLOR_PURIFIED
			if status_tip_label != null:
				status_tip_label.text = "【时律平息 · 守时圣像已复苏】"
				status_tip_label.modulate = COLOR_PURIFIED
			_set_bar_color(COLOR_PURIFIED)


func _set_bar_color(color: Color) -> void:
	if hp_bar == null:
		return
	var fill := hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		var tween := create_tween()
		if tween != null:
			tween.tween_property(fill, "bg_color", color, 0.4)