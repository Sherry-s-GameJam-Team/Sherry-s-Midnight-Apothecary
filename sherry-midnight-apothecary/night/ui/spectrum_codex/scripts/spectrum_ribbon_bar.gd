class_name SpectrumRibbonBar
extends Control

signal band_clicked(band: PotionSpectrumBand)
signal function_clicked(function: PotionFunctionDefinition)

var sorted_bands: Array[PotionSpectrumBand] = []
var band_anchors: Array[Dictionary] = [] # [{"band": PotionSpectrumBand, "top_y": float, "bottom_y": float, "center_y": float}]
var function_anchors: Array[Dictionary] = [] # [{"function": PotionFunctionDefinition, "band": PotionSpectrumBand, "center_y": float, "is_unlocked": bool}]
var selected_band_id: StringName = &""
var selected_function_id: StringName = &""

const RIBBON_WIDTH: float = 24.0
const RIBBON_MARGIN_X: float = 8.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(56, 120)


func setup_bands(bands: Array[PotionSpectrumBand]) -> void:
	sorted_bands = bands.duplicate()
	queue_redraw()


func set_band_anchors(b_anchors: Array[Dictionary], f_anchors: Array[Dictionary] = []) -> void:
	band_anchors = b_anchors
	function_anchors = f_anchors

	var total_h: float = 120.0
	if not band_anchors.is_empty():
		var last_anchor: Dictionary = band_anchors[-1]
		total_h = maxf(float(last_anchor.get("bottom_y", 120.0)), 120.0)
	custom_minimum_size.y = total_h
	queue_redraw()


func set_selected_band(band_id: StringName) -> void:
	selected_band_id = band_id
	selected_function_id = &""
	queue_redraw()


func set_selected_function(func_id: StringName, band_id: StringName = &"") -> void:
	selected_function_id = func_id
	if not band_id.is_empty():
		selected_band_id = band_id
	queue_redraw()


func _draw() -> void:
	var total_height: float = size.y
	if total_height <= 0:
		return

	var rect_x: float = RIBBON_MARGIN_X
	var rect_w: float = RIBBON_WIDTH

	# Draw background slot frame
	var track_rect := Rect2(rect_x - 3, 0, rect_w + 6, total_height)
	draw_rect(track_rect, Color(0.88, 0.82, 0.7, 0.95), true)
	draw_rect(track_rect, Color(0.48, 0.35, 0.22, 0.85), false, 1.5)

	if not band_anchors.is_empty():
		_draw_anchored_ribbon(rect_x, rect_w, total_height)
	elif not sorted_bands.is_empty():
		_draw_fallback_ribbon(rect_x, rect_w, total_height)


func _draw_anchored_ribbon(rect_x: float, rect_w: float, total_height: float) -> void:
	var num_anchors: int = band_anchors.size()

	# Draw gradient segments matched to each right-side band card
	for i in range(num_anchors):
		var anchor: Dictionary = band_anchors[i]
		var band: PotionSpectrumBand = anchor.get("band", null)
		if band == null:
			continue

		var seg_top: float = float(anchor.get("top_y", 0.0))
		var seg_bot: float = float(anchor.get("bottom_y", seg_top + 40.0))
		var seg_h: float = maxf(seg_bot - seg_top, 2.0)

		# Next band color for boundary interpolation
		var next_band: PotionSpectrumBand = band
		if i + 1 < num_anchors:
			next_band = band_anchors[i + 1].get("band", band)

		var steps: int = int(clampf(seg_h / 4.0, 6.0, 32.0))
		var step_h: float = seg_h / float(steps)

		for s in range(steps):
			var t0: float = float(s) / float(steps)
			var t1: float = float(s + 1) / float(steps)
			var c0: Color = band.color.lerp(next_band.color, t0 * 0.35)
			var c1: Color = band.color.lerp(next_band.color, t1 * 0.35)
			var c_avg: Color = c0.lerp(c1, 0.5)

			var slice_rect := Rect2(rect_x, seg_top + s * step_h, rect_w, step_h + 1.0)
			draw_rect(slice_rect, c_avg, true)

		# Divider notch between bands
		if i > 0:
			draw_line(Vector2(rect_x - 4, seg_top), Vector2(rect_x + rect_w + 4, seg_top), Color(0.42, 0.28, 0.15, 0.8), 1.5)

	# Inner glass tube highlight line
	draw_line(Vector2(rect_x + 3, 0), Vector2(rect_x + 3, total_height), Color(1, 1, 1, 0.35), 1.0)

	# Draw Level 1: Independent Band Indicators
	for i in range(num_anchors):
		var anchor: Dictionary = band_anchors[i]
		var band: PotionSpectrumBand = anchor.get("band", null)
		if band == null:
			continue

		var center_y: float = float(anchor.get("center_y", anchor.get("top_y", 0.0) + 18.0))
		var is_band_active: bool = (band.id == selected_band_id and selected_function_id.is_empty())

		# Left & right ticks
		draw_line(Vector2(rect_x - 5, center_y), Vector2(rect_x, center_y), Color(0.42, 0.28, 0.15, 0.9), 2.0)
		draw_line(Vector2(rect_x + rect_w, center_y), Vector2(rect_x + rect_w + 6, center_y), Color(0.42, 0.28, 0.15, 0.9), 2.0)

		# Pearl marker
		var marker_radius: float = 5.5 if is_band_active else 3.5
		var marker_color: Color = Color(0.98, 0.95, 0.88, 1.0) if is_band_active else band.color.lightened(0.25)
		draw_circle(Vector2(rect_x + rect_w * 0.5, center_y), marker_radius, marker_color)
		draw_arc(Vector2(rect_x + rect_w * 0.5, center_y), marker_radius, 0, TAU, 16, Color(0.4, 0.25, 0.12, 0.9), 1.0)

		if is_band_active:
			draw_circle(Vector2(rect_x + rect_w * 0.5, center_y), marker_radius + 4.0, Color(0.85, 0.65, 0.25, 0.5))
			draw_line(Vector2(rect_x + rect_w + 4, center_y), Vector2(size.x, center_y), Color(0.78, 0.22, 0.15, 0.95), 2.0)
			var arrow_p1 := Vector2(size.x - 2, center_y)
			var arrow_p2 := Vector2(size.x - 9, center_y - 5)
			var arrow_p3 := Vector2(size.x - 9, center_y + 5)
			draw_colored_polygon(PackedVector2Array([arrow_p1, arrow_p2, arrow_p3]), Color(0.78, 0.22, 0.15, 1.0))
		else:
			draw_line(Vector2(rect_x + rect_w + 6, center_y), Vector2(rect_x + rect_w + 14, center_y), Color(0.55, 0.4, 0.25, 0.6), 1.0)

	# Draw Level 2: Independent Function Indicators
	for f_anchor in function_anchors:
		var func_def: PotionFunctionDefinition = f_anchor.get("function", null)
		if func_def == null:
			continue

		var f_center_y: float = float(f_anchor.get("center_y", 0.0))
		var is_func_unlocked: bool = bool(f_anchor.get("is_unlocked", false))
		var is_func_active: bool = (func_def.id == selected_function_id)

		# Function Diamond Indicator Pip
		var pip_center := Vector2(rect_x + rect_w + 10, f_center_y)
		var pip_half: float = 4.0 if is_func_active else 2.5
		var d_top := pip_center + Vector2(0, -pip_half)
		var d_right := pip_center + Vector2(pip_half, 0)
		var d_bot := pip_center + Vector2(0, pip_half)
		var d_left := pip_center + Vector2(-pip_half, 0)

		# Branch connector tick from ribbon to diamond pip
		draw_line(Vector2(rect_x + rect_w, f_center_y), pip_center, Color(0.55, 0.4, 0.25, 0.75), 1.0)

		var pip_color: Color = Color(0.78, 0.22, 0.15, 1.0) if is_func_active else (Color(0.35, 0.6, 0.85, 0.9) if is_func_unlocked else Color(0.55, 0.45, 0.35, 0.7))
		draw_colored_polygon(PackedVector2Array([d_top, d_right, d_bot, d_left]), pip_color)

		if is_func_active:
			draw_line(Vector2(pip_center.x + pip_half, f_center_y), Vector2(size.x, f_center_y), Color(0.78, 0.22, 0.15, 0.95), 2.0)
			var arrow_p1 := Vector2(size.x - 2, f_center_y)
			var arrow_p2 := Vector2(size.x - 8, f_center_y - 4)
			var arrow_p3 := Vector2(size.x - 8, f_center_y + 4)
			draw_colored_polygon(PackedVector2Array([arrow_p1, arrow_p2, arrow_p3]), Color(0.78, 0.22, 0.15, 1.0))
		else:
			draw_line(Vector2(pip_center.x + pip_half, f_center_y), Vector2(size.x - 4, f_center_y), Color(0.65, 0.52, 0.38, 0.4), 1.0)


func _draw_fallback_ribbon(rect_x: float, rect_w: float, total_height: float) -> void:
	var num_bands: int = sorted_bands.size()
	var num_steps: int = 100
	var step_h: float = total_height / float(num_steps)

	for i in range(num_steps):
		var t0: float = float(i) / float(num_steps)
		var t1: float = float(i + 1) / float(num_steps)
		var c0: Color = _sample_spectrum_color(t0)
		var c1: Color = _sample_spectrum_color(t1)
		var c_avg: Color = c0.lerp(c1, 0.5)
		draw_rect(Rect2(rect_x, i * step_h, rect_w, step_h + 1.0), c_avg, true)

	draw_line(Vector2(rect_x + 3, 0), Vector2(rect_x + 3, total_height), Color(1, 1, 1, 0.35), 1.0)

	for i in range(num_bands):
		var band: PotionSpectrumBand = sorted_bands[i]
		var band_y: float = (float(i) + 0.5) / float(num_bands) * total_height
		var marker_radius: float = 4.0
		draw_circle(Vector2(rect_x + rect_w * 0.5, band_y), marker_radius, band.color.lightened(0.2))


func _sample_spectrum_color(t: float) -> Color:
	if sorted_bands.is_empty():
		return Color.WHITE
	if sorted_bands.size() == 1:
		return sorted_bands[0].color

	var num_segments: float = float(sorted_bands.size() - 1)
	var scaled_t: float = clampf(t * num_segments, 0.0, num_segments)
	var idx: int = int(floor(scaled_t))
	var frac: float = scaled_t - float(idx)

	if idx >= sorted_bands.size() - 1:
		return sorted_bands[-1].color

	var c_start: Color = sorted_bands[idx].color
	var c_end: Color = sorted_bands[idx + 1].color
	return c_start.lerp(c_end, frac)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.is_pressed():
			var clicked_func := _get_function_at_y(mb.position.y)
			if clicked_func != null:
				set_selected_function(clicked_func.id)
				function_clicked.emit(clicked_func)
				accept_event()
				return

			var clicked_band := _get_band_at_y(mb.position.y)
			if clicked_band != null:
				set_selected_band(clicked_band.id)
				band_clicked.emit(clicked_band)
				accept_event()


func _get_function_at_y(y_pos: float) -> PotionFunctionDefinition:
	for f_anchor in function_anchors:
		var f_center_y: float = float(f_anchor.get("center_y", 0.0))
		if absf(y_pos - f_center_y) <= 12.0:
			return f_anchor.get("function", null)
	return null


func _get_band_at_y(y_pos: float) -> PotionSpectrumBand:
	if not band_anchors.is_empty():
		for anchor in band_anchors:
			var top_y: float = float(anchor.get("top_y", 0.0))
			var bot_y: float = float(anchor.get("bottom_y", 0.0))
			if y_pos >= top_y and y_pos <= bot_y:
				return anchor.get("band", null)
		if y_pos < float(band_anchors[0].get("top_y", 0.0)):
			return band_anchors[0].get("band", null)
		return band_anchors[-1].get("band", null)

	if sorted_bands.is_empty() or size.y <= 0:
		return null
	var t: float = clampf(y_pos / size.y, 0.0, 1.0)
	var idx: int = int(clampf(t * float(sorted_bands.size()), 0, sorted_bands.size() - 1))
	return sorted_bands[idx]
