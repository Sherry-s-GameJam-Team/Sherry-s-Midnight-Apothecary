@tool
class_name SpectrumAnalyzer
extends Control

@export var use_art_background := false
@export_node_path("Label") var title_label_path: NodePath
@export var show_detail_explanation := false:
	set(value):
		show_detail_explanation = value
		queue_redraw()

@export_group("Spectrum Alignment")
@export_range(0.0, 1.0, 0.001) var spectrum_left_ratio := 0.08:
	set(value):
		spectrum_left_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()
@export_range(0.0, 1.0, 0.001) var spectrum_right_ratio := 0.92:
	set(value):
		spectrum_right_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()
@export_range(0.0, 1.0, 0.001) var spectrum_top_ratio := 0.37:
	set(value):
		spectrum_top_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()
@export_range(0.0, 1.0, 0.001) var spectrum_bottom_ratio := 0.50:
	set(value):
		spectrum_bottom_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var show_alignment_guides := true:
	set(value):
		show_alignment_guides = value
		queue_redraw()

@export_group("Spectrum Pointer")
@export var pointer_texture: Texture2D
@export var pointer_size := Vector2(12.0, 64.0):
	set(value):
		pointer_size = value.max(Vector2.ONE)
		queue_redraw()
@export_range(0.1, 5.0, 0.05) var pointer_scale := 1.0:
	set(value):
		pointer_scale = clampf(value, 0.1, 5.0)
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var pointer_tip_ratio := 1.0:
	set(value):
		pointer_tip_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()

const DEFAULT_CATALOG_PATH := "res://night/ui/spectrum_codex/resources/default_potion_spectrum_catalog.tres"
const DEFAULT_UNLOCK_STATE_PATH := "res://night/ui/spectrum_codex/resources/default_potion_spectrum_unlock_state.tres"

@export var catalog: PotionSpectrumCatalog
@export var unlock_state: PotionSpectrumUnlockState

var prediction: Dictionary = {}
@onready var title_label: Label = get_node_or_null(title_label_path)


func _ready() -> void:
	custom_minimum_size = Vector2(480, 92)
	if catalog == null and ResourceLoader.exists(DEFAULT_CATALOG_PATH):
		catalog = load(DEFAULT_CATALOG_PATH) as PotionSpectrumCatalog
	if unlock_state == null and ResourceLoader.exists(DEFAULT_UNLOCK_STATE_PATH):
		unlock_state = load(DEFAULT_UNLOCK_STATE_PATH) as PotionSpectrumUnlockState
	if unlock_state != null and not Engine.is_editor_hint():
		if not unlock_state.state_changed.is_connected(_on_unlock_state_changed):
			unlock_state.state_changed.connect(_on_unlock_state_changed)
	if title_label != null:
		title_label.visible = true
	_update_title()
	queue_redraw()


func setup(cat: PotionSpectrumCatalog, state: PotionSpectrumUnlockState) -> void:
	if unlock_state != null and unlock_state.state_changed.is_connected(_on_unlock_state_changed):
		unlock_state.state_changed.disconnect(_on_unlock_state_changed)
	catalog = cat
	unlock_state = state
	if unlock_state != null and not Engine.is_editor_hint():
		if not unlock_state.state_changed.is_connected(_on_unlock_state_changed):
			unlock_state.state_changed.connect(_on_unlock_state_changed)
	_update_title()
	queue_redraw()


func _on_unlock_state_changed() -> void:
	_update_title()
	queue_redraw()


func set_prediction(value: Dictionary) -> void:
	prediction = value
	_update_title()
	queue_redraw()


func get_spectrum_band(mixed_x: float) -> PotionSpectrumBand:
	if catalog == null or catalog.bands.is_empty():
		return null
	for band in catalog.bands:
		if band != null and mixed_x >= band.spectrum_min and mixed_x <= band.spectrum_max:
			return band
	var min_dist := INF
	var nearest_band: PotionSpectrumBand = null
	for band in catalog.bands:
		if band != null:
			var dist := 0.0
			if mixed_x < band.spectrum_min:
				dist = band.spectrum_min - mixed_x
			elif mixed_x > band.spectrum_max:
				dist = mixed_x - band.spectrum_max
			if dist < min_dist:
				min_dist = dist
				nearest_band = band
	return nearest_band


func get_spectrum_function(mixed_x: float) -> PotionFunctionDefinition:
	var active_band := get_spectrum_band(mixed_x)
	if active_band == null or catalog == null:
		return null
	var closest_func: PotionFunctionDefinition = null
	var min_dist := INF
	for func_def in catalog.functions:
		if func_def != null and func_def.band_id == active_band.id:
			var dist := absf(mixed_x - func_def.spectrum_position)
			if dist < min_dist:
				min_dist = dist
				closest_func = func_def
	return closest_func


func is_function_unlocked(func_def: PotionFunctionDefinition) -> bool:
	if func_def == null or unlock_state == null:
		return false
	return unlock_state.is_function_unlocked(func_def.id)


func _update_title() -> void:
	if title_label == null:
		return
	if prediction.is_empty():
		title_label.text = "药谱分析仪 · 加入材料以分析药水功效"
		return
	if bool(prediction.get("failed", false)):
		title_label.text = "药谱分析仪 · 配方失衡，可能生成失败药水"
		return
	var mixed_x := clampf(float(prediction.get("mixed_x", 0.0)), 0.0, 1.0)
	var func_def := get_spectrum_function(mixed_x)
	if func_def != null:
		if is_function_unlocked(func_def):
			title_label.text = "药谱分析仪 · 主功能：%s　副功能：%s" % [func_def.primary_tag, func_def.secondary_tag]
		else:
			title_label.text = "药谱分析仪 · 装瓶后显示"
	else:
		var effect_id := StringName(str(prediction.get("main_effect_id", "")))
		title_label.text = "药谱分析仪 · %s" % _effect_explanation(effect_id)


func _effect_explanation(effect_id: StringName) -> String:
	return PotionEffectText.describe(effect_id)


func _spectrum_band() -> Rect2:
	if not use_art_background:
		return Rect2(16, 12, maxf(size.x - 32.0, 1.0), 28)
	var left := minf(spectrum_left_ratio, spectrum_right_ratio)
	var right := maxf(spectrum_left_ratio, spectrum_right_ratio)
	var top := minf(spectrum_top_ratio, spectrum_bottom_ratio)
	var bottom := maxf(spectrum_top_ratio, spectrum_bottom_ratio)
	return Rect2(
		Vector2(size.x * left, size.y * top),
		Vector2(maxf(size.x * (right - left), 1.0), maxf(size.y * (bottom - top), 1.0)),
	)


func _draw() -> void:
	var band := _spectrum_band()
	var colors: Array[Color] = [
		Color("#c94b45"), Color("#db893e"), Color("#e8ce55"), Color("#78a45b"),
		Color("#5fb8b1"), Color("#597fc4"), Color("#8a5caf"),
	]
	var segment_width := band.size.x / float(colors.size())
	if not use_art_background:
		for index in colors.size():
			draw_rect(Rect2(band.position.x + segment_width * index, band.position.y, segment_width + 1.0, band.size.y), colors[index])
		draw_rect(band, Color("#5b3a23"), false, 2.0)
	elif show_alignment_guides:
		_draw_alignment_guides(band)

	if prediction.is_empty():
		if not use_art_background and show_detail_explanation:
			var text_y := 70.0
			draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.08, text_y), "加入材料后显示预测结果", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#4a301c"))
		return

	var mixed_x := clampf(float(prediction.get("mixed_x", 0.0)), 0.0, 1.0)
	var marker_x := band.position.x + mixed_x * band.size.x
	draw_line(
		Vector2(marker_x, band.position.y),
		Vector2(marker_x, band.end.y),
		Color("#25190f"),
		2.0,
	)
	_draw_pointer(Vector2(marker_x, band.get_center().y))

	if show_detail_explanation:
		var text_y := size.y * 0.82 if use_art_background else 70.0
		if bool(prediction.get("failed", false)):
			var text := "色值 %.3f　失败药水　品质 %.2f" % [mixed_x, float(prediction.get("quality", 0.0))]
			draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.08, text_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#4a301c"))
		else:
			var func_def := get_spectrum_function(mixed_x)
			var text := ""
			if func_def != null:
				if is_function_unlocked(func_def):
					text = "色值 %.3f　主功能：%s　副功能：%s　品质 %.2f" % [
						mixed_x, func_def.primary_tag, func_def.secondary_tag, float(prediction.get("quality", 0.0)),
					]
				else:
					text = "色值 %.3f　主副功能：装瓶后显示　品质 %.2f" % [
						mixed_x, float(prediction.get("quality", 0.0)),
					]
			else:
				var main_text := str(prediction.get("main_effect_id", ""))
				var secondary := str(prediction.get("secondary_effect_id", ""))
				text = "色值 %.3f　主效：%s　副效：%s　品质 %.2f" % [
					mixed_x, main_text, secondary if not secondary.is_empty() else "无", float(prediction.get("quality", 0.0)),
				]
			draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.08, text_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#4a301c"))


func _draw_alignment_guides(band: Rect2) -> void:
	var red := Color("#d84a43")
	var purple := Color("#8b55b5")
	draw_rect(band, Color(0.86, 0.69, 0.35, 0.8), false, 1.0)
	draw_line(Vector2(band.position.x, band.position.y - 4.0), Vector2(band.position.x, band.end.y + 4.0), red, 2.0)
	draw_line(Vector2(band.end.x, band.position.y - 4.0), Vector2(band.end.x, band.end.y + 4.0), purple, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(band.position.x, band.end.y + 14.0), "", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, red)
	draw_string(ThemeDB.fallback_font, Vector2(band.end.x - 34.0, band.end.y + 14.0), "", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, purple)


func _draw_pointer(tip_position: Vector2) -> void:
	if pointer_texture == null:
		draw_line(Vector2(tip_position.x, 7.0), Vector2(tip_position.x, 47.0), Color.WHITE, 3.0)
		return
	var display_size := pointer_size * pointer_scale
	var pointer_rect := Rect2(
		Vector2(tip_position.x - display_size.x * 0.5, tip_position.y - display_size.y * pointer_tip_ratio),
		display_size,
	)
	draw_texture_rect(pointer_texture, pointer_rect, false)
