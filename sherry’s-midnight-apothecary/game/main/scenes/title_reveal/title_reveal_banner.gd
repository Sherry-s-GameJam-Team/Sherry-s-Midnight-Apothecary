extends Control
class_name TitleRevealBanner

signal reveal_finished

const DESIGN_SIZE := Vector2(960.0, 360.0)
const PANEL_FILL := Color(0.025, 0.075, 0.078, 0.96)
const PANEL_SHADOW := Color(0.005, 0.025, 0.026, 0.74)
const BORDER_LIGHT := Color(0.93, 0.84, 0.60, 1.0)
const BORDER_DARK := Color(0.35, 0.43, 0.34, 1.0)
const ORNAMENT_DIM := Color(0.55, 0.61, 0.45, 1.0)
const RED_ACCENT := Color(0.70, 0.12, 0.11, 1.0)

@export var day_text := "第一天":
	set(value):
		day_text = value
		_apply_exported_text()
@export var title_text := "避雨林区":
	set(value):
		title_text = value
		_apply_exported_text()
@export var subtitle_text := "血河":
	set(value):
		subtitle_text = value
		_apply_exported_text()

var plate_progress := 0.0:
	set(value):
		plate_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var border_progress := 0.0:
	set(value):
		border_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var ornament_progress := 0.0:
	set(value):
		ornament_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var divider_progress := 0.0:
	set(value):
		divider_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var sparkle_progress := 0.0:
	set(value):
		sparkle_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var texture_progress := 0.0:
	set(value):
		texture_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var texture_time := 0.0

var reveal_tween: Tween = null
var base_positions := {}

@onready var day_label: Label = $Content/DayLabel
@onready var title_label: Label = $Content/TitleLabel
@onready var subtitle_label: Label = $Content/SubtitleLabel


func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	pivot_offset = DESIGN_SIZE * 0.5
	_capture_label_positions()
	_apply_exported_text()
	reset_state()


func reset_state() -> void:
	plate_progress = 0.0
	border_progress = 0.0
	ornament_progress = 0.0
	divider_progress = 0.0
	sparkle_progress = 0.0
	texture_progress = 0.0
	texture_time = 0.0
	_reset_label(day_label, 12.0)
	_reset_label(title_label, 22.0)
	_reset_label(subtitle_label, -6.0)
	_set_title_visible_characters(0.0)
	visible = false


func hide_now() -> void:
	if reveal_tween != null:
		reveal_tween.kill()
	reset_state()


func play_show() -> void:
	if reveal_tween != null:
		reveal_tween.kill()

	reset_state()
	visible = true
	reveal_tween = create_tween()
	reveal_tween.set_parallel(true)

	reveal_tween.tween_property(self, "plate_progress", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(self, "border_progress", 1.0, 0.28).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(self, "divider_progress", 1.0, 0.22).set_delay(0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(self, "ornament_progress", 1.0, 0.42).set_delay(0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(self, "texture_progress", 1.0, 0.58).set_delay(0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(self, "sparkle_progress", 1.0, 0.34).set_delay(0.54).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_animate_label(reveal_tween, day_label, 0.42, 0.18, 12.0)
	_animate_title_typewriter(reveal_tween, 0.58, _title_typewriter_duration(), 22.0)
	_animate_label(reveal_tween, subtitle_label, 0.96, 0.22, -6.0)
	reveal_tween.finished.connect(_on_reveal_tween_finished)


func _process(delta: float) -> void:
	if not visible:
		return
	if texture_progress <= 0.01 and sparkle_progress <= 0.01:
		return
	texture_time += delta
	queue_redraw()


func _draw() -> void:
	_draw_plate()
	_draw_border()
	_draw_dividers()
	_draw_ornaments()


func _draw_plate() -> void:
	if plate_progress <= 0.001:
		return

	var eased := _ease_out_back_light(plate_progress)
	var center := DESIGN_SIZE * 0.5
	draw_set_transform(center, 0.0, Vector2(maxf(0.01, eased), 0.88 + 0.12 * eased))
	var points := PackedVector2Array([
		Vector2(-380.0, -140.0), Vector2(380.0, -140.0), Vector2(412.0, -108.0),
		Vector2(412.0, -50.0), Vector2(460.0, 0.0), Vector2(412.0, 50.0),
		Vector2(412.0, 108.0), Vector2(380.0, 140.0), Vector2(-380.0, 140.0),
		Vector2(-412.0, 108.0), Vector2(-412.0, 50.0), Vector2(-460.0, 0.0),
		Vector2(-412.0, -50.0), Vector2(-412.0, -108.0),
	])
	draw_colored_polygon(points, _with_alpha(PANEL_SHADOW, 0.78))
	var inner_points := PackedVector2Array([
		Vector2(-372.0, -132.0), Vector2(372.0, -132.0), Vector2(404.0, -100.0),
		Vector2(404.0, -46.0), Vector2(448.0, 0.0), Vector2(404.0, 46.0),
		Vector2(404.0, 100.0), Vector2(372.0, 132.0), Vector2(-372.0, 132.0),
		Vector2(-404.0, 100.0), Vector2(-404.0, 46.0), Vector2(-448.0, 0.0),
		Vector2(-404.0, -46.0), Vector2(-404.0, -100.0),
	])
	draw_colored_polygon(inner_points, _with_alpha(PANEL_FILL, plate_progress))
	draw_rect(Rect2(Vector2(-332.0, -110.0), Vector2(664.0, 220.0)), _with_alpha(Color(0.02, 0.04, 0.045, 0.20), plate_progress), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_border() -> void:
	if border_progress <= 0.001:
		return

	var light := _with_alpha(BORDER_LIGHT, border_progress)
	var dark := _with_alpha(BORDER_DARK, border_progress)
	var outer := [
		Vector2(100.0, 40.0), Vector2(860.0, 40.0), Vector2(892.0, 72.0),
		Vector2(892.0, 130.0), Vector2(940.0, 180.0), Vector2(892.0, 230.0),
		Vector2(892.0, 288.0), Vector2(860.0, 320.0), Vector2(100.0, 320.0),
		Vector2(68.0, 288.0), Vector2(68.0, 230.0), Vector2(20.0, 180.0),
		Vector2(68.0, 130.0), Vector2(68.0, 72.0), Vector2(100.0, 40.0),
	]
	var mid := [
		Vector2(108.0, 52.0), Vector2(852.0, 52.0), Vector2(880.0, 80.0),
		Vector2(880.0, 136.0), Vector2(920.0, 180.0), Vector2(880.0, 224.0),
		Vector2(880.0, 280.0), Vector2(852.0, 308.0), Vector2(108.0, 308.0),
		Vector2(80.0, 280.0), Vector2(80.0, 224.0), Vector2(40.0, 180.0),
		Vector2(80.0, 136.0), Vector2(80.0, 80.0), Vector2(108.0, 52.0),
	]
	var inner := [
		Vector2(124.0, 64.0), Vector2(836.0, 64.0), Vector2(866.0, 94.0),
		Vector2(866.0, 146.0), Vector2(902.0, 180.0), Vector2(866.0, 214.0),
		Vector2(866.0, 266.0), Vector2(836.0, 296.0), Vector2(124.0, 296.0),
		Vector2(94.0, 266.0), Vector2(94.0, 214.0), Vector2(58.0, 180.0),
		Vector2(94.0, 146.0), Vector2(94.0, 94.0), Vector2(124.0, 64.0),
	]
	_draw_pixel_polyline(outer, light, 6.0)
	_draw_pixel_polyline(mid, PANEL_FILL.darkened(0.22), 8.0)
	_draw_pixel_polyline(inner, dark, 3.0)
	_draw_corner_ticks(light, dark)
	_draw_center_crest(Vector2(480.0, 40.0), true, light, dark)
	_draw_center_crest(Vector2(480.0, 320.0), false, light, dark)


func _draw_corner_ticks(light: Color, dark: Color) -> void:
	for side_value in [-1, 1]:
		var side := float(side_value)
		var x: float = 480.0 + side * 330.0
		_draw_px_rect(Vector2(x - 50.0, 56.0), Vector2(100.0, 4.0), dark)
		_draw_px_rect(Vector2(x - 50.0, 300.0), Vector2(100.0, 4.0), dark)


func _draw_center_crest(center: Vector2, top: bool, light: Color, dark: Color) -> void:
	var direction: float = -1.0 if top else 1.0
	_draw_diamond(center + Vector2(0.0, direction * 3.0), 35.0, 26.0, light, 5.0)
	_draw_diamond(center + Vector2(0.0, direction * 3.0), 18.0, 14.0, PANEL_FILL, 8.0)
	_draw_diamond(center + Vector2(0.0, direction * 3.0), 9.0, 9.0, light, 4.0)
	_draw_px_rect(center + Vector2(-8.0, direction * 32.0), Vector2(16.0, 7.0), dark)
	_draw_px_rect(center + Vector2(-3.0, direction * 42.0), Vector2(6.0, 6.0), light)


func _draw_dividers() -> void:
	if divider_progress <= 0.001:
		return

	var alpha := divider_progress
	var line_color := _with_alpha(ORNAMENT_DIM, alpha)
	var warm := _with_alpha(BORDER_LIGHT, alpha)
	_draw_split_label_lines(112.0, 132.0, 108.0, line_color, warm)
	_draw_centered_line(Vector2(480.0, 232.0), 236.0, 36.0, line_color, warm)
	_draw_split_label_lines(268.0, 126.0, 68.0, _with_alpha(RED_ACCENT, alpha), _with_alpha(RED_ACCENT, alpha))


func _draw_centered_line(center: Vector2, half_width: float, gap: float, line_color: Color, bead_color: Color) -> void:
	_draw_px_rect(center + Vector2(-half_width, -2.0), Vector2(half_width - gap, 4.0), line_color)
	_draw_px_rect(center + Vector2(gap, -2.0), Vector2(half_width - gap, 4.0), line_color)
	_draw_diamond(center, 9.0, 9.0, bead_color, 4.0)
	_draw_px_rect(center + Vector2(-18.0, -1.0), Vector2(8.0, 2.0), bead_color)
	_draw_px_rect(center + Vector2(10.0, -1.0), Vector2(8.0, 2.0), bead_color)


func _draw_split_label_lines(y: float, inner_gap: float, line_width: float, line_color: Color, bead_color: Color) -> void:
	var center_x := DESIGN_SIZE.x * 0.5
	var left_end := center_x - inner_gap * 0.5
	var right_start := center_x + inner_gap * 0.5
	_draw_px_rect(Vector2(left_end - line_width, y - 2.0), Vector2(line_width, 4.0), line_color)
	_draw_px_rect(Vector2(right_start, y - 2.0), Vector2(line_width, 4.0), line_color)
	_draw_diamond(Vector2(left_end - 16.0, y), 7.0, 7.0, bead_color, 4.0)
	_draw_diamond(Vector2(right_start + 16.0, y), 7.0, 7.0, bead_color, 4.0)


func _draw_ornaments() -> void:
	if ornament_progress <= 0.001:
		return

	var vine_alpha := ornament_progress
	_draw_hanging_vines(152.0, 74.0, 292.0, false, vine_alpha)
	_draw_hanging_vines(808.0, 74.0, 292.0, true, vine_alpha)
	_draw_side_star(Vector2(82.0, 180.0), _with_alpha(BORDER_LIGHT, sparkle_progress))
	_draw_side_star(Vector2(878.0, 180.0), _with_alpha(BORDER_LIGHT, sparkle_progress))


func _draw_hanging_vines(x: float, y_top: float, y_bottom: float, mirrored: bool, alpha: float) -> void:
	var direction := -1.0 if mirrored else 1.0
	var color := _with_alpha(ORNAMENT_DIM, alpha * _texture_flicker(0.0, 0.10))
	var dim := _with_alpha(ORNAMENT_DIM.darkened(0.25), alpha * 0.74)
	var height := (y_bottom - y_top) * clampf(alpha, 0.0, 1.0)
	var end_y := y_top + height
	var tick_index := 0

	for y in range(int(y_top), int(end_y), 18):
		_draw_texture_tick(Vector2(x, float(y)), Vector2(4.0, 10.0), dim, tick_index, 23)
		tick_index += 1
	for y in range(int(y_top + 12.0), int(end_y), 24):
		_draw_texture_tick(Vector2(x + direction * 24.0, float(y)), Vector2(4.0, 12.0), dim, tick_index, 23)
		tick_index += 1
	for y in range(int(y_top + 4.0), int(end_y), 33):
		_draw_texture_tick(Vector2(x - direction * 28.0, float(y)), Vector2(4.0, 8.0), dim, tick_index, 23)
		tick_index += 1

	_draw_reveal_vertical(Vector2(x - 2.0, y_top + 8.0), 116.0, end_y - y_top - 8.0, color, 0.00)
	_draw_reveal_vertical(Vector2(x + direction * 24.0, y_top + 2.0), 96.0, end_y - y_top - 2.0, dim, 0.08)
	_draw_reveal_vertical(Vector2(x - direction * 27.0, y_top + 20.0), 82.0, end_y - y_top - 20.0, dim, 0.16)

	_draw_texture_diamond(Vector2(x - direction * 27.0, 181.0), 20.0, 20.0, color, 3.0, 0.30)
	_draw_texture_diamond(Vector2(x + direction * 22.0, 235.0), 13.0, 13.0, dim, 3.0, 0.48)
	_draw_texture_diamond(Vector2(x, 129.0), 9.0, 9.0, color, 3.0, 0.62)
	_draw_texture_tick(Vector2(x - direction * 45.0, 78.0), Vector2(4.0, 17.0), dim, 18, 23)
	_draw_texture_tick(Vector2(x - direction * 51.0, 89.0), Vector2(4.0, 8.0), dim, 20, 23)


func _draw_side_star(center: Vector2, color: Color) -> void:
	if color.a <= 0.001:
		return
	_draw_px_rect(center + Vector2(-28.0, -3.0), Vector2(56.0, 6.0), color)
	_draw_px_rect(center + Vector2(-3.0, -28.0), Vector2(6.0, 56.0), color)
	_draw_pixel_line(center + Vector2(-22.0, -22.0), center + Vector2(22.0, 22.0), color, 4.0)
	_draw_pixel_line(center + Vector2(22.0, -22.0), center + Vector2(-22.0, 22.0), color, 4.0)
	_draw_diamond(center, 10.0, 10.0, PANEL_FILL, 5.0)


func _capture_label_positions() -> void:
	base_positions[day_label] = day_label.position
	base_positions[title_label] = title_label.position
	base_positions[subtitle_label] = subtitle_label.position
	for label in [day_label, title_label, subtitle_label]:
		label.pivot_offset = label.size * 0.5


func _apply_exported_text() -> void:
	if not is_node_ready():
		return
	day_label.text = day_text
	title_label.text = title_text
	subtitle_label.text = subtitle_text


func _reset_label(label: Label, offset_y: float) -> void:
	if label == null or not base_positions.has(label):
		return
	label.position = base_positions[label] + Vector2(0.0, offset_y)
	label.scale = Vector2(0.96, 0.96)
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _animate_label(tween: Tween, label: Label, delay: float, duration: float, offset_y: float) -> void:
	if label == null or not base_positions.has(label):
		return
	var base_position: Vector2 = base_positions[label]
	label.position = base_position + Vector2(0.0, offset_y)
	label.scale = Vector2(0.96, 0.96)
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	tween.tween_property(label, "position", base_position, duration).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color.WHITE, duration * 0.78).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _animate_title_typewriter(tween: Tween, delay: float, duration: float, offset_y: float) -> void:
	if title_label == null or not base_positions.has(title_label):
		return
	var base_position: Vector2 = base_positions[title_label]
	title_label.position = base_position + Vector2(0.0, offset_y)
	title_label.scale = Vector2(0.97, 0.97)
	title_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_set_title_visible_characters(0.0)
	tween.tween_property(title_label, "position", base_position, 0.18).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_label, "scale", Vector2.ONE, 0.18).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_label, "modulate", Color.WHITE, 0.12).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_title_visible_characters, 0.0, float(title_label.text.length()), duration).set_delay(delay + 0.10).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(_finish_title_typewriter).set_delay(delay + duration + 0.12)


func _set_title_visible_characters(value: float) -> void:
	if title_label == null:
		return
	title_label.visible_characters = int(round(value))


func _finish_title_typewriter() -> void:
	if title_label != null:
		title_label.visible_characters = -1


func _on_reveal_tween_finished() -> void:
	reveal_finished.emit()


func _title_typewriter_duration() -> float:
	return clampf(float(title_label.text.length()) * 0.085, 0.32, 0.72)


func _draw_pixel_polyline(points: Array, color: Color, width: float) -> void:
	for index in points.size() - 1:
		_draw_pixel_line(points[index], points[index + 1], color, width)


func _draw_pixel_line(from_point: Vector2, to_point: Vector2, color: Color, width: float) -> void:
	draw_line(from_point.round(), to_point.round(), color, width, false)


func _draw_diamond(center: Vector2, half_width: float, half_height: float, color: Color, width: float) -> void:
	var points := [
		center + Vector2(0.0, -half_height),
		center + Vector2(half_width, 0.0),
		center + Vector2(0.0, half_height),
		center + Vector2(-half_width, 0.0),
		center + Vector2(0.0, -half_height),
	]
	_draw_pixel_polyline(points, color, width)


func _draw_px_rect(position: Vector2, rect_size: Vector2, color: Color) -> void:
	draw_rect(Rect2(position.round(), rect_size.round()), color, true)


func _draw_texture_tick(position: Vector2, rect_size: Vector2, color: Color, index: int, total: int) -> void:
	var alpha := _texture_step_alpha(index, total)
	if alpha <= 0.001:
		return
	draw_rect(Rect2(position.round(), rect_size.round()), _with_alpha(color, alpha * _texture_flicker(float(index), 0.16)), true)


func _draw_reveal_vertical(position: Vector2, max_height: float, raw_height: float, color: Color, delay: float) -> void:
	var progress := clampf((texture_progress - delay) / 0.54, 0.0, 1.0)
	var height := minf(max_height, maxf(0.0, raw_height)) * progress
	if height <= 0.5:
		return
	_draw_px_rect(position, Vector2(4.0, height), _with_alpha(color, _texture_flicker(delay * 31.0, 0.10)))


func _draw_texture_diamond(center: Vector2, half_width: float, half_height: float, color: Color, width: float, delay: float) -> void:
	var alpha := clampf((texture_progress - delay) / 0.24, 0.0, 1.0)
	if alpha <= 0.001:
		return
	_draw_diamond(center, half_width, half_height, _with_alpha(color, alpha * _texture_flicker(delay * 19.0, 0.12)), width)


func _texture_step_alpha(index: int, total: int) -> float:
	var step_start := float(index) / maxf(float(total), 1.0) * 0.54
	return clampf((texture_progress - step_start) / 0.18, 0.0, 1.0)


func _texture_flicker(seed: float, amount: float) -> float:
	if texture_progress < 0.98:
		return 1.0
	var wave := sin(texture_time * 5.5 + seed * 1.37)
	return 1.0 - amount * 0.5 + amount * 0.5 * wave


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clampf(alpha, 0.0, 1.0))


func _ease_out_back_light(value: float) -> float:
	var t := clampf(value, 0.0, 1.0) - 1.0
	return 1.0 + 1.35 * t * t * t + 0.35 * t * t
