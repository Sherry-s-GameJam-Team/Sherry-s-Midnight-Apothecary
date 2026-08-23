class_name CrownlandBossHUD
extends CanvasLayer
## Crownland Boss HUD — health bar, phase badge, hint label.
## Mirrors HelionBossHUD. Connect via connect_boss(boss_node).

@export var boss_name: String = "被黑魔法寄生的国王"
@export var boss_subtitle: String = "阿里特王畿"

var _boss: CrownlandBoss = null
var _ghost_tween: Tween = null
var _is_visible: bool = false

# Phase color constants
const COLOR_PHASE1 := Color(0.45, 0.45, 0.55, 1.0)   # grey — shield active
const COLOR_PHASE2 := Color(0.2, 0.2, 0.7, 1.0)       # deep blue — pillars
const COLOR_PHASE3 := Color(0.7, 0.1, 0.1, 1.0)       # dark red — vulnerable
const COLOR_PURIFIED := Color(0.3, 0.9, 0.5, 1.0)     # emerald — defeated
const COLOR_BLOOD_RED := Color(0.72, 0.06, 0.08, 1.0)
const COLOR_DARK_RED := Color(0.16, 0.01, 0.02, 0.96)

# ─── UI Nodes (created programmatically if scene not available) ───
var _root_container: Control
var _boss_title: Label
var _subtitle_label: Label
var _phase_badge: Label
var _hp_bar_ghost: ProgressBar
var _hp_bar: ProgressBar
var _hp_label: Label
var _pillar_label: Label
var _hint_label: Label
var _hint_tween: Tween
var _pillar_health: Dictionary = {}
var _pillar_max_health: Dictionary = {}


func _ready() -> void:
	layer = 15
	_bind_deployed_nodes()
	if _root_container == null:
		_build_ui()
	if _root_container != null:
		_root_container.modulate.a = 0.0
		_root_container.visible = false


## The Crownland HUD is now scene-authored with the same structure as
## alkeon_boss_health_bar.tscn. The procedural path remains a fallback for
## isolated legacy loads only.
func _bind_deployed_nodes() -> void:
	_root_container = get_node_or_null("RootContainer") as Control
	_boss_title = get_node_or_null("RootContainer/HeaderBox/BossTitle") as Label
	_subtitle_label = get_node_or_null("RootContainer/HeaderBox/Subtitle") as Label
	_phase_badge = get_node_or_null("RootContainer/HeaderBox/PhaseBadge") as Label
	_hp_bar_ghost = get_node_or_null("RootContainer/BarContainer/HpBarGhost") as ProgressBar
	_hp_bar = get_node_or_null("RootContainer/BarContainer/HpBar") as ProgressBar
	_hp_label = get_node_or_null("RootContainer/BarContainer/HpLabel") as Label
	_pillar_label = get_node_or_null("RootContainer/BarContainer/PillarLabel") as Label
	_hint_label = get_node_or_null("RootContainer/StatusTip") as Label


func _build_ui() -> void:
	# Root container anchored to top-center
	_root_container = Control.new()
	_root_container.name = "RootContainer"
	_root_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_root_container.offset_top = 8.0
	_root_container.offset_bottom = 80.0
	add_child(_root_container)

	# Boss title
	_boss_title = Label.new()
	_boss_title.text = boss_name
	_boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_boss_title.offset_top = 0.0
	_boss_title.offset_bottom = 20.0
	_root_container.add_child(_boss_title)

	# Subtitle
	_subtitle_label = Label.new()
	_subtitle_label.text = boss_subtitle
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_subtitle_label.offset_top = 18.0
	_subtitle_label.offset_bottom = 36.0
	_subtitle_label.modulate.a = 0.7
	_root_container.add_child(_subtitle_label)

	# One red-black health frame contains the boss bar and pillar readout.
	var health_frame := Panel.new()
	health_frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	health_frame.offset_left = 40.0
	health_frame.offset_right = -40.0
	health_frame.offset_top = 34.0
	health_frame.offset_bottom = 74.0
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = COLOR_DARK_RED
	frame_style.border_color = Color(0.5, 0.04, 0.05, 1.0)
	frame_style.set_border_width_all(2)
	frame_style.corner_radius_top_left = 6
	frame_style.corner_radius_top_right = 6
	frame_style.corner_radius_bottom_left = 6
	frame_style.corner_radius_bottom_right = 6
	health_frame.add_theme_stylebox_override("panel", frame_style)
	_root_container.add_child(health_frame)

	# Ghost HP bar
	_hp_bar_ghost = ProgressBar.new()
	_hp_bar_ghost.max_value = 100
	_hp_bar_ghost.value = 100
	_hp_bar_ghost.show_percentage = false
	_hp_bar_ghost.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hp_bar_ghost.offset_left = 52.0
	_hp_bar_ghost.offset_right = -210.0
	_hp_bar_ghost.offset_top = 42.0
	_hp_bar_ghost.offset_bottom = 58.0
	_hp_bar_ghost.modulate = Color(1.0, 0.55, 0.55, 0.65)
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color(0.03, 0.0, 0.0, 1.0)
	var ghost_fill := StyleBoxFlat.new()
	ghost_fill.bg_color = Color(0.38, 0.03, 0.04, 1.0)
	_hp_bar_ghost.add_theme_stylebox_override("background", bar_background)
	_hp_bar_ghost.add_theme_stylebox_override("fill", ghost_fill)
	_root_container.add_child(_hp_bar_ghost)

	# HP bar
	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hp_bar.offset_left = 52.0
	_hp_bar.offset_right = -210.0
	_hp_bar.offset_top = 42.0
	_hp_bar.offset_bottom = 58.0
	var blood_fill := StyleBoxFlat.new()
	blood_fill.bg_color = COLOR_BLOOD_RED
	blood_fill.corner_radius_top_left = 3
	blood_fill.corner_radius_bottom_left = 3
	_hp_bar.add_theme_stylebox_override("background", bar_background)
	_hp_bar.add_theme_stylebox_override("fill", blood_fill)
	_root_container.add_child(_hp_bar)

	# HP label
	_hp_label = Label.new()
	_hp_label.text = "???"
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hp_label.offset_left = 52.0
	_hp_label.offset_right = -210.0
	_hp_label.offset_top = 58.0
	_hp_label.offset_bottom = 72.0
	_root_container.add_child(_hp_label)

	_pillar_label = Label.new()
	_pillar_label.text = "黑柱 --/-- ×0"
	_pillar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pillar_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_pillar_label.offset_left = -200.0
	_pillar_label.offset_right = -52.0
	_pillar_label.offset_top = 43.0
	_pillar_label.offset_bottom = 67.0
	_pillar_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.62, 1.0))
	_pillar_label.add_theme_font_size_override("font_size", 16)
	_root_container.add_child(_pillar_label)

	# Phase badge
	_phase_badge = Label.new()
	_phase_badge.text = "【王权屏障】"
	_phase_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_phase_badge.offset_top = 64.0
	_phase_badge.offset_bottom = 80.0
	_phase_badge.modulate = COLOR_PHASE1
	_root_container.add_child(_phase_badge)

	# Hint label (below HP bar area)
	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hint_label.offset_top = 82.0
	_hint_label.offset_bottom = 100.0
	_hint_label.modulate = Color(1.0, 0.9, 0.7, 0.0)
	add_child(_hint_label)   # sibling of root_container, always visible


func connect_boss(boss: CrownlandBoss) -> void:
	_boss = boss
	if _boss == null:
		return
	if not _boss.health_changed.is_connected(_on_health_changed):
		_boss.health_changed.connect(_on_health_changed)
	if not _boss.phase_changed.is_connected(_on_phase_changed):
		_boss.phase_changed.connect(_on_phase_changed)
	if not _boss.boss_defeated.is_connected(_on_boss_defeated):
		_boss.boss_defeated.connect(_on_boss_defeated)
	var max_hp := _boss._get_max_hp()
	var curr_hp := _boss.current_hp
	_update_display(float(curr_hp), float(max_hp))
	_update_phase_badge(int(_boss.current_phase))


func connect_pillars(pillars: Node) -> void:
	_pillar_health.clear()
	_pillar_max_health.clear()
	if pillars == null:
		_update_pillar_display()
		return
	for child: Node in pillars.get_children():
		if not child is CrownlandMagicPillar:
			continue
		var pillar := child as CrownlandMagicPillar
		_pillar_health[pillar.pillar_id] = pillar.pillar_hp
		_pillar_max_health[pillar.pillar_id] = pillar.pillar_hp
		if not pillar.pillar_hp_changed.is_connected(_on_pillar_hp_changed):
			pillar.pillar_hp_changed.connect(_on_pillar_hp_changed)
		if not pillar.pillar_destroyed.is_connected(_on_pillar_destroyed):
			pillar.pillar_destroyed.connect(_on_pillar_destroyed)
	_update_pillar_display()


func _on_pillar_hp_changed(pillar_id: StringName, remaining_hp: int) -> void:
	_pillar_health[pillar_id] = remaining_hp
	_update_pillar_display()


func _on_pillar_destroyed(pillar_id: StringName) -> void:
	_pillar_health[pillar_id] = 0
	_update_pillar_display()


func _update_pillar_display() -> void:
	if _pillar_label == null:
		return
	var current_total := 0
	var max_total := 0
	var remaining_count := 0
	for pillar_id: Variant in _pillar_max_health:
		var current := int(_pillar_health.get(pillar_id, 0))
		current_total += current
		max_total += int(_pillar_max_health[pillar_id])
		if current > 0:
			remaining_count += 1
	_pillar_label.text = "黑柱 %d/%d ×%d" % [current_total, max_total, remaining_count]


func show_hud() -> void:
	if _is_visible:
		return
	_is_visible = true
	if _root_container != null:
		_root_container.visible = true
		var tween := create_tween()
		if tween != null:
			tween.tween_property(_root_container, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func hide_hud(delay: float = 0.0, fade: float = 1.5) -> void:
	_is_visible = false
	if _root_container != null:
		var tween := create_tween()
		if tween != null:
			if delay > 0.0:
				tween.tween_interval(delay)
			tween.tween_property(_root_container, "modulate:a", 0.0, fade)
			tween.finished.connect(func() -> void:
				if _root_container != null:
					_root_container.visible = false
			)


func show_hint(text: String) -> void:
	if _hint_label == null:
		return
	_hint_label.text = text
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween()
	if _hint_tween != null:
		_hint_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.3)
		if text.is_empty():
			_hint_tween.tween_property(_hint_label, "modulate:a", 0.0, 0.5)
		else:
			_hint_tween.tween_interval(3.0)
			_hint_tween.tween_property(_hint_label, "modulate:a", 0.0, 0.5)


func _on_health_changed(curr: int, max_v: int) -> void:
	if not _is_visible:
		show_hud()
	_update_display(float(curr), float(max_v))


func _on_phase_changed(phase: int) -> void:
	if not _is_visible:
		show_hud()
	_update_phase_badge(phase)
	on_phase_changed(phase)


func on_phase_changed(phase: int) -> void:
	_update_phase_badge(phase)


func _on_boss_defeated(_id: StringName) -> void:
	if _phase_badge != null:
		_phase_badge.text = "【王权净化 · 寄生已解除】"
		_phase_badge.modulate = COLOR_PURIFIED
	if _hp_label != null:
		_hp_label.text = "净化完成"
	show_hint("【黑魔法已消散 · 国王获救】")
	hide_hud(4.0, 1.5)


func _update_display(curr: float, max_v: float) -> void:
	var ratio := clampf(curr / maxf(max_v, 1.0), 0.0, 1.0)
	var pct := roundi(ratio * 100.0)
	if _hp_bar != null:
		_hp_bar.value = pct
	if _hp_label != null:
		_hp_label.text = "国王 %d / %d" % [roundi(curr), roundi(max_v)]
	# Ghost bar smooth
	if _hp_bar_ghost != null:
		if _ghost_tween != null and _ghost_tween.is_valid():
			_ghost_tween.kill()
		_ghost_tween = create_tween()
		if _ghost_tween != null:
			_ghost_tween.tween_interval(0.3)
			_ghost_tween.tween_property(_hp_bar_ghost, "value", float(pct), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_phase_badge(phase: int) -> void:
	if _phase_badge == null:
		return
	# CrownlandBoss.Phase: 0=INTRO, 1=PHASE_1, 2=PHASE_1_TRANSITION,
	# 3=PHASE_2, 4=PHASE_2_TRANSITION, 5=PHASE_3, 6=FINAL_PURIFICATION, 7=DEFEATED
	match phase:
		0, 1, 2:
			_phase_badge.text = "【第一阶段 · 王权屏障】"
			_phase_badge.modulate = COLOR_PHASE1
			if _hp_bar != null:
				_set_bar_color(COLOR_PHASE1)
		3, 4:
			_phase_badge.text = "【第二阶段 · 破坏黑魔法柱】"
			_phase_badge.modulate = COLOR_PHASE2
			if _hp_bar != null:
				_set_bar_color(COLOR_PHASE2)
		5:
			_phase_badge.text = "【第三阶段 · 正面攻击国王】"
			_phase_badge.modulate = COLOR_PHASE3
			if _hp_bar != null:
				_set_bar_color(COLOR_PHASE3)
		6:
			_phase_badge.text = "【圣水终结 · 投掷圣水】"
			_phase_badge.modulate = Color(1.0, 0.4, 0.1, 1.0)
		7:
			_phase_badge.text = "【已净化】"
			_phase_badge.modulate = COLOR_PURIFIED
			_set_bar_color(COLOR_PURIFIED)


func _set_bar_color(_color: Color) -> void:
	# The health frame remains red-black across phases; phase identity is
	# communicated by the badge instead of recoloring health information.
	if _hp_bar != null:
		_hp_bar.modulate = Color.WHITE
