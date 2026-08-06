class_name SceneTitleCard
extends CanvasLayer

const BASE_SIZE := Vector2(1080.0, 680.0)
const ANIMATION_NAME := &"reveal"

@export_range(0.0, 10.0, 0.1) var hold_seconds := 1.5
@export_range(0.05, 2.0, 0.05) var fade_duration := 0.25
@export_range(0.1, 1.0, 0.05) var display_scale := 0.5
@export_range(0.0, 240.0, 1.0) var top_margin := 24.0

@onready var screen_root: Control = %ScreenRoot
@onready var title_root: Control = %TitleRoot
@onready var border_animation: AnimatedSprite2D = %BorderAnimation
@onready var day_label: Label = %DayLabel
@onready var location_label: Label = %LocationLabel
@onready var subtitle_label: Label = %SubtitleLabel

var _hide_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_update_layout)
	border_animation.animation_finished.connect(_on_border_animation_finished)
	_update_layout()
	_hide_immediately()


func show_title(day: int, location: String, disaster: String, description: String) -> void:
	if _hide_tween != null:
		_hide_tween.kill()
	day_label.text = "第 %d 天" % maxi(day, 1)
	location_label.text = location if not location.is_empty() else "未知地点"
	var resolved_disaster := disaster if not disaster.is_empty() else "灾难未定"
	var resolved_description := description if not description.is_empty() else "场景描述待补充"
	subtitle_label.text = "%s · %s" % [resolved_disaster, resolved_description]
	_fit_label(location_label, 96, 44)
	_fit_label(subtitle_label, 34, 20)

	screen_root.visible = true
	screen_root.modulate = Color.WHITE
	for label in [day_label, location_label, subtitle_label]:
		label.modulate.a = 0.0
	border_animation.visible = true
	border_animation.stop()
	border_animation.animation = ANIMATION_NAME
	border_animation.frame = 0
	border_animation.play(ANIMATION_NAME)

	var text_tween := create_tween()
	text_tween.tween_interval(2.35)
	text_tween.tween_property(day_label, "modulate:a", 1.0, 0.25)
	text_tween.tween_interval(0.12)
	text_tween.tween_property(location_label, "modulate:a", 1.0, 0.30)
	text_tween.tween_interval(0.12)
	text_tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.25)


func _on_border_animation_finished() -> void:
	if border_animation.animation != ANIMATION_NAME:
		return
	border_animation.frame = border_animation.sprite_frames.get_frame_count(ANIMATION_NAME) - 1
	_hide_tween = create_tween()
	_hide_tween.tween_interval(hold_seconds)
	_hide_tween.tween_property(screen_root, "modulate:a", 0.0, fade_duration)
	_hide_tween.tween_callback(_hide_immediately)


func _hide_immediately() -> void:
	border_animation.stop()
	border_animation.visible = false
	screen_root.visible = false
	screen_root.modulate = Color.WHITE


func _update_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var viewport_fit := minf(1.0, minf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y))
	var resolved_scale := maxf(display_scale * viewport_fit, 0.01)
	var displayed_size := BASE_SIZE * resolved_scale
	title_root.scale = Vector2.ONE * resolved_scale
	title_root.position = Vector2(
		(viewport_size.x - displayed_size.x) * 0.5,
		minf(top_margin, maxf(viewport_size.y - displayed_size.y, 0.0))
	)


func _fit_label(label: Label, maximum_size: int, minimum_size: int) -> void:
	var font := label.get_theme_font("font")
	if font == null:
		return
	var selected_size := maximum_size
	while selected_size > minimum_size:
		if font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, selected_size).x <= label.size.x - 24.0:
			break
		selected_size -= 2
	label.add_theme_font_size_override("font_size", selected_size)
