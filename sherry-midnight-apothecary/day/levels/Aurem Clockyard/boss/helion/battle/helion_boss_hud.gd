class_name HelionBossHUD
extends CanvasLayer
## Boss health bar UI with clock-themed decorations.
## Phase transitions shown via color shifts and chime sounds,
## never with modern "PHASE 2" text overlays.

@export var boss_name: String = "十二刻守望者·赫利昂"
@export var boss_subtitle: String = "奥雷姆中央守时圣像"

var _boss: Node2D = null
var _max_hp: int = 2000
var _current_hp: int = 2000
var _displayed_hp: float = 2000.0
var _current_phase_color: Color = Color(0.8, 0.5, 0.2, 1.0)  # Phase 1: copper

# Phase decoration colors
const PHASE_COLORS: Dictionary = {
	1: Color(0.8, 0.5, 0.2, 1.0),   # Phase 1: copper
	2: Color(0.3, 0.5, 0.9, 1.0),   # Phase 2: blue
	3: Color(1.0, 0.85, 0.3, 1.0),  # Phase 3: gold
}

# UI Node references
var _name_label: Label = null
var _subtitle_label: Label = null
var _health_bar: ProgressBar = null
var _bar_container: Control = null
var _bg_panel: PanelContainer = null


func _ready() -> void:
	layer = 100
	_build_ui()


func _build_ui() -> void:
	# Root container at screen bottom-top area
	_bar_container = Control.new()
	_bar_container.name = "BarContainer"
	_bar_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_container.offset_top = -120.0
	_bar_container.offset_bottom = -20.0
	_bar_container.offset_left = 100.0
	_bar_container.offset_right = -100.0
	add_child(_bar_container)

	# Background panel
	_bg_panel = PanelContainer.new()
	_bg_panel.name = "BgPanel"
	_bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_panel.modulate = Color(0.1, 0.08, 0.06, 0.85)
	_bar_container.add_child(_bg_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	_bar_container.add_child(vbox)

	# Boss name
	_name_label = Label.new()
	_name_label.name = "BossName"
	_name_label.text = boss_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", _current_phase_color)
	vbox.add_child(_name_label)

	# Subtitle
	_subtitle_label = Label.new()
	_subtitle_label.name = "Subtitle"
	_subtitle_label.text = boss_subtitle
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 12)
	_subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55, 0.8))
	vbox.add_child(_subtitle_label)

	# Health bar
	_health_bar = ProgressBar.new()
	_health_bar.name = "HealthBar"
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(0, 20)

	# Style the health bar
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = _current_phase_color
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	_health_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.12, 0.1, 0.9)
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	bg_style.border_color = _current_phase_color * 0.6
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	_health_bar.add_theme_stylebox_override("background", bg_style)

	vbox.add_child(_health_bar)

	# Start hidden, show when boss connected
	_bar_container.modulate.a = 0.0


func connect_boss(boss: Node2D) -> void:
	_boss = boss
	if _boss == null:
		return

	if _boss.has_signal("health_changed"):
		_boss.connect("health_changed", _on_health_changed)
	if _boss.has_signal("phase_changed"):
		_boss.connect("phase_changed", _on_phase_changed)
	if _boss.has_signal("boss_defeated"):
		_boss.connect("boss_defeated", _on_boss_defeated)

	var cfg: Resource = _boss.get("config") as Resource
	if cfg != null:
		_max_hp = cfg.get("max_hp") if cfg.get("max_hp") != null else 2000
	_current_hp = _max_hp
	_displayed_hp = float(_max_hp)

	# Fade in
	if _bar_container != null:
		var tween := create_tween()
		if tween != null:
			tween.tween_property(_bar_container, "modulate:a", 1.0, 0.8)


func _on_health_changed(current: int, max_hp: int) -> void:
	_current_hp = current
	_max_hp = max_hp


func _on_phase_changed(new_phase: int) -> void:
	var color: Color = PHASE_COLORS.get(new_phase, _current_phase_color)
	_transition_phase_color(color)


func _transition_phase_color(new_color: Color) -> void:
	_current_phase_color = new_color
	var tween := create_tween()
	if tween == null:
		return

	# Animate name label color
	if _name_label != null:
		tween.tween_method(func(c: Color) -> void:
			_name_label.add_theme_color_override("font_color", c)
		, _name_label.get_theme_color("font_color"), new_color, 0.5)

	# Animate health bar fill color
	if _health_bar != null:
		var fill: StyleBoxFlat = _health_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill != null:
			tween.parallel().tween_property(fill, "bg_color", new_color, 0.5)
		var bg: StyleBoxFlat = _health_bar.get_theme_stylebox("background") as StyleBoxFlat
		if bg != null:
			tween.parallel().tween_property(bg, "border_color", new_color * 0.6, 0.5)


func _on_boss_defeated(_boss_id: StringName) -> void:
	# Fade out the HUD
	if _bar_container != null:
		var tween := create_tween()
		if tween != null:
			tween.tween_property(_bar_container, "modulate:a", 0.0, 2.0)


func _process(delta: float) -> void:
	if _health_bar == null or _max_hp <= 0:
		return

	# Smooth HP display
	var target: float = float(_current_hp)
	_displayed_hp = move_toward(_displayed_hp, target, float(_max_hp) * 0.5 * delta)
	_health_bar.value = (_displayed_hp / float(_max_hp)) * 100.0
