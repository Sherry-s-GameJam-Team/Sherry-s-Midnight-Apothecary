class_name SpectrumAnalyzer
extends Control

@export var use_art_background := false

var prediction: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(480, 92)
	queue_redraw()


func set_prediction(value: Dictionary) -> void:
	prediction = value
	queue_redraw()


func _draw() -> void:
	var band := (
		Rect2(size.x * 0.08, size.y * 0.37, size.x * 0.84, size.y * 0.13)
		if use_art_background
		else Rect2(16, 12, maxf(size.x - 32.0, 1.0), 28)
	)
	var colors: Array[Color] = [
		Color("#c94b45"), Color("#db893e"), Color("#e8ce55"), Color("#78a45b"),
		Color("#5fb8b1"), Color("#597fc4"), Color("#8a5caf"),
	]
	var segment_width := band.size.x / float(colors.size())
	if not use_art_background:
		for index in colors.size():
			draw_rect(Rect2(band.position.x + segment_width * index, band.position.y, segment_width + 1.0, band.size.y), colors[index])
		draw_rect(band, Color("#5b3a23"), false, 2.0)
	var text_y := size.y * 0.82 if use_art_background else 70.0
	if prediction.is_empty():
		if not use_art_background:
			draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.08, text_y), "加入材料后显示预测结果", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#4a301c"))
		return
	var mixed_x := clampf(float(prediction.get("mixed_x", 0.0)), 0.0, 1.0)
	var marker_x := band.position.x + mixed_x * band.size.x
	draw_line(Vector2(marker_x, 7), Vector2(marker_x, 47), Color.WHITE, 3.0)
	var potion: PotionData = prediction.get("potion")
	if potion != null and not bool(prediction.get("failed", false)):
		var target_x := band.position.x + potion.spectrum_center_x * band.size.x
		draw_line(Vector2(target_x, 10), Vector2(target_x, 43), Color("#25190f"), 2.0)
	var main_text := "失败药水" if bool(prediction.get("failed", false)) else str(prediction.get("main_effect_id", ""))
	var secondary := str(prediction.get("secondary_effect_id", ""))
	var text := "色值 %.3f　主效：%s　副效：%s　品质 %.2f" % [
		mixed_x, main_text, secondary if not secondary.is_empty() else "无", float(prediction.get("quality", 0.0)),
	]
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.08, text_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#4a301c"))
